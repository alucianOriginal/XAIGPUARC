// SYCL Vektor-Flash Attention Kernel: ggml_flash_attention_sycl.cpp
// Implementiert den Flash Attention Kernel (Tiling-Strategie) mit Vektorisierung (4-er Vektoren).
// Dieser Code ist als Ergänzung zu ggml-sycl.cpp im llama.cpp Projektbaum gedacht.

#include <sycl/sycl.hpp>
#include <cmath>
#include <limits>
#include "ggml-sycl.h" // Muss hinzugefügt werden, um ggml_tensor und ggml_context verwenden zu können.
#include "ggml-impl.h" // Für ggml_backend_sycl_get_queue

using namespace sycl;

// Kernel Parameter (Könnten für eine erweiterte Version als Template-Argumente übergeben werden)
#define BLOCK_M 64    // Queries pro Block (tune)
#define BLOCK_N 128   // Keys pro Block (tune)
#define D_MAX 128     // Maximale Kopf-/Wert-Dimension (DK/DV)
#define VEC_SIZE 4    // Vektorgröße (optimal für viele GPU-Architekturen)

/**
 * @brief Implementiert den Flash Attention Kernel (Tiling-Strategie) in SYCL C++.
 * Die Query-Zeile Q wird in Registern gehalten. K und V werden blockweise iteriert.
 * @tparam scalar_t Der Datentyp der Eingabematrizen (z.B. sycl::half, float).
 * ...
 */
template <typename scalar_t>
void flash_attention_kernel(
    const sycl::accessor<scalar_t, 1, sycl::access::mode::read> Q_acc,
    const sycl::accessor<scalar_t, 1, sycl::access::mode::read> K_acc,
    const sycl::accessor<scalar_t, 1, sycl::access::mode::read> V_acc,
    sycl::accessor<scalar_t, 1, sycl::access::mode::write> Out_acc,
    int num_q, int num_k, int d_k, int d_v, int head_stride, int q_stride, int k_stride, int v_stride, int out_stride,
    sycl::nd_item<1> item
) {
    // Annahme: Diese Funktion enthält die gesamte Kernel-Logik, wie sie von Ihnen entworfen wurde.

    const int head_row = item.get_global_id(0);
    if (head_row >= num_q) return;

    // Lokaler Speicher für Akkumulatoren
    float accum_den = 0.0f;
    float accum_num[D_MAX] = {0.0f}; // Annahme: D_MAX ist groß genug (128)
    float running_max = -std::numeric_limits<float>::infinity();

    // Q_ptr zeigt auf den Anfang der aktuellen Q-Zeile im globalen Speicher.
    // Wir verwenden hier float als Zwischenspeicher, da der Kernel in float rechnen muss (für exp und log).
    const sycl::half * Q_ptr_half = Q_acc.get_pointer() + head_row * q_stride;
    float Q_row_float[D_MAX];
    for (int di = 0; di < d_k; ++di) {
        Q_row_float[di] = (float)Q_ptr_half[di];
    }


    // Iteration über K/V-Blöcke
    for (int k_start = 0; k_start < num_k; k_start += BLOCK_N) {
        int k_end = sycl::min(k_start + BLOCK_N, num_k);
        float new_max = running_max;

        // 1. Erster Pass: Max-Score im aktuellen Block finden und neuen globalen Max-Score berechnen
        for (int kk = 0; kk < k_end - k_start; ++kk) {
            float score = 0.0f;
            // Dot-Produkt S_ij = Q_i . K_j / sqrt(d_k)
            for (int di = 0; di < d_k; ++di) {
                score += Q_row_float[di] * (float)K_acc[(k_start + kk) * k_stride + di];
            }
            score /= sycl::sqrt((float)d_k);
            new_max = sycl::max(new_max, score);
        }

        // Skaliere Akkumulatoren, falls sich der globale Max-Wert geändert hat
        float exp_diff = sycl::exp(running_max - new_max);
        if (exp_diff != 1.0f) {
            accum_den *= exp_diff;
            for (int vi = 0; vi < d_v; ++vi) {
                accum_num[vi] *= exp_diff;
            }
        }
        running_max = new_max;


        // 2. Zweiter Pass: Akkumuliere P * V
        for (int kk = 0; kk < k_end - k_start; ++kk) {
            float score = 0.0f;
            // Erneute Berechnung des Scores für den aktuellen K/V-Block
            for (int di = 0; di < d_k; ++di) {
                score += Q_row_float[di] * (float)K_acc[(k_start + kk) * k_stride + di];
            }
            score /= sycl::sqrt((float)d_k);

            // Exponentiiertes und skaliertes Gewicht e = exp(S_ij - m_new)
            float e = sycl::exp(score - running_max);

            accum_den += e;

            // Akkumuliere V * e (Vektorisierung beibehalten)
            if (d_v % VEC_SIZE == 0) {
                using acc_vec_t = sycl::vec<float, VEC_SIZE>;
                // Pointer in float Vektoren umwandeln
                const auto* v_ptr = reinterpret_cast<const acc_vec_t*>(V_acc.get_pointer() + (k_start + kk) * v_stride);
                auto* acc_ptr = reinterpret_cast<acc_vec_t*>(accum_num);

                for (int v = 0; v < d_v / VEC_SIZE; ++v) {
                    acc_ptr[v] += e * v_ptr[v];
                }
            } else {
                for (int vi = 0; vi < d_v; ++vi) {
                    accum_num[vi] += e * (float)V_acc[(k_start + kk) * v_stride + vi];
                }
            }
        }
    }

    // 3. Finalisiere die Ausgabe (Out = Accum_Num / Accum_Den)
    // ANPASSUNG: Vektorisiertes Speichern
    sycl::half * Out_ptr_half = Out_acc.get_pointer() + head_row * out_stride;
    if (d_v % VEC_SIZE == 0) {
        using out_vec_t = sycl::vec<sycl::half, VEC_SIZE>;
        const auto* acc_ptr = reinterpret_cast<const sycl::vec<float, VEC_SIZE>*>(accum_num);
        auto* out_ptr = reinterpret_cast<out_vec_t*>(Out_ptr_half);

        for (int v = 0; v < d_v / VEC_SIZE; ++v) {
            // Skaliere und konvertiere float Vektor zu sycl::half Vektor
            sycl::vec<float, VEC_SIZE> final_float_vec = acc_ptr[v] / accum_den;
            out_ptr[v] = (out_vec_t)final_float_vec;
        }
    } else {
        for (int vi = 0; vi < d_v; ++vi) {
            Out_ptr_half[vi] = (sycl::half)(accum_num[vi] / accum_den);
        }
    }
}


// Externe Wrapper-Funktion, die von ggml-sycl.cpp aufgerufen wird
// Diese Funktion kapselt die Kernel-Argumente und den Launch-Vorgang.
extern "C" void ggml_sycl_op_flash_attn(ggml_backend_sycl_context * ctx, ggml_tensor * dst, const ggml_tensor * Q, const ggml_tensor * K, const ggml_tensor * V) {
    if (Q->type != GGML_TYPE_F16) {
        // Nur FP16 wird derzeit unterstützt (ABORT-Nachricht angepasst)
        GGML_ABORT("ggml_sycl_op_flash_attn: Nur GGML_TYPE_F16 unterstützt!");
        return;
    }

    // Holen Sie die SYCL-Queue
    sycl::queue & q = ggml_backend_sycl_get_queue(Q->backend);

    // Abmessungen des innersten Tensors
    const int num_q = Q->ne[1]; // T (Query Sequence Length)
    const int num_k = K->ne[1]; // N (Key/Value Sequence Length: T + n_past)
    const int d_k = Q->ne[0]; // dk (Head Dimension)
    const int d_v = V->ne[0]; // dv (Head Dimension)

    // Überprüfung der Dimensionen für den Kernel
    // D_MAX ist 128 (aus den Definitionen oben)
    #define D_MAX 128
    if (d_k > D_MAX || d_v > D_MAX) {
        // ABORT-Nachricht angepasst
        GGML_ABORT("ggml_sycl_op_flash_attn: Dimension DK/DV zu groß für Kernel-Konstante D_MAX!");
        return;
    }

    // Strides (in Anzahl von Elementen, nicht Bytes)
    const int q_stride = Q->nb[1] / ggml_type_size(Q->type); // Q-Zeilen-Stride
    const int k_stride = K->nb[1] / ggml_type_size(K->type); // K-Zeilen-Stride
    const int v_stride = V->nb[1] / ggml_type_size(V->type); // V-Zeilen-Stride
    const int out_stride = dst->nb[1] / ggml_type_size(dst->type); // **WICHTIG: out_stride verwendet dst**

    // Globaler Arbeitsbereich: Eine Zeile pro Q-Zeile
    sycl::range<1> global_size(num_q);

    // Die Kernel-Ausführung
    q.submit([&](sycl::handler &h) {
        // Accessoren für Q, K, V sind korrekt
        sycl::accessor<sycl::half, 1, sycl::access::mode::read> Q_acc(
            (sycl::half *)Q->data, {Q->ne[0] * Q->ne[1]}, h);
        sycl::accessor<sycl::half, 1, sycl::access::mode::read> K_acc(
            (sycl::half *)K->data, {K->ne[0] * K->ne[1]}, h);
        sycl::accessor<sycl::half, 1, sycl::access::mode::read> V_acc(
            (sycl::half *)V->data, {V->ne[0] * V->ne[1]}, h);

        // **WICHTIG: Output-Accessor verwendet jetzt dst**
        sycl::accessor<sycl::half, 1, sycl::access::mode::write> Out_acc(
            (sycl::half *)dst->data, {dst->ne[0] * dst->ne[1]}, h);

        h.parallel_for(global_size, [=](sycl::nd_item<1> item) {
            flash_attention_kernel<sycl::half>(
                Q_acc, K_acc, V_acc, Out_acc,
                num_q, num_k, d_k, d_v, 0, q_stride, k_stride, v_stride, out_stride, // head_stride wird im innersten Kernel nicht benötigt
                item
            );
        });
    });

    // Optional: q.wait_and_throw() kann hier weggelassen werden, da der Llama-Graph
    // die Synchronisation später übernimmt, aber zum Debuggen ist es oft hilfreich.
}
