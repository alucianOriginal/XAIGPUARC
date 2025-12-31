No Support unti l 2025 30.12.2025 /// SORRY
#!/bin/bash
# XAIGPUARC v1.1 | 2025-12-29
# Fokus: openSUSE Tumbleweed/Leap Intel Compute Setup
# Änderungen: Paketnamen-Mapping für openSUSE korrigiert, GPG-Handling verbessert.

set -e

echo "--- XAIGPUARC v1.1: openSUSE Ultra-Fix [Intel ARC & iGPU] ---"
echo "Datum: 29.12.2025 | Version: 1.1 (Tumbleweed-Optimiert)"

# 1. System-Check
. /etc/os-release
if [[ "$ID" != "opensuse-leap" && "$ID" != "opensuse-tumbleweed" ]]; then
  echo "❌ Dieses Skript ist nur für openSUSE gedacht."
  exit 1
fi

# ------------------------------------------------------------
# 2. Repo-Logik & Intel-Fix
# ------------------------------------------------------------
echo "🧹 Bereinige alte Intel-Reste..."
sudo zypper rr intel-graphics 2>/dev/null || true

# Bestimme Pfad (Leap vs Tumbleweed)
REPO_PATH="leap/15.6"
[[ "$ID" == "opensuse-tumbleweed" ]] && REPO_PATH="tumbleweed"

INTEL_REPO_BASE="https://repositories.intel.com/graphics/rpm/opensuse/$REPO_PATH/"
INTEL_KEY_URL="https://repositories.intel.com/intel-graphics-keys/GPG-PUB-KEY-INTEL-GRAPHICS"

# Versuch das Repo einzubinden, aber mit Ignorieren von Fehlern falls 403
echo "ℹ️ Versuche Intel Repo einzubinden..."
sudo zypper ar -f "$INTEL_REPO_BASE" intel-graphics 2>/dev/null || echo "⚠️ Direktes Intel-Repo nicht erreichbar (403), nutze Standard-Quellen."

# GPG-Key Import
curl -sL "$INTEL_KEY_URL" | sudo rpm --import - 2>/dev/null || true
sudo zypper --gpg-auto-import-keys ref

# ------------------------------------------------------------
# 3. Installation mit korrigierten Paketnamen (openSUSE Style)
# ------------------------------------------------------------
echo "📦 Installiere Compute-Stack (openSUSE Namensschema)..."

# Wir nutzen hier die Namen, die openSUSE tatsächlich in den OSS/Update Repos führt
sudo zypper --non-interactive install -y --no-recommends --allow-vendor-change \
  intel-opencl \
  level-zero-gpu \
  libigdgmm12 \
  gmmlib-devel \
  intel-oneapi-runtime-dpcpp-cpp \
  intel-oneapi-compiler-dpcpp-cpp \
  intel-oneapi-runtime-mkl \
  intel-oneapi-mkl-devel

# ------------------------------------------------------------
# 4. Finalisierung & Gruppen
# ------------------------------------------------------------
echo "👥 Berechtigungen verifizieren..."
sudo usermod -aG video $USER
sudo usermod -aG render $USER

echo ""
echo "--- ✅ SETUP V1.1 ABGESCHLOSSEN ---"
echo "Versionshinweis: Falls 'intel-opencl' und 'level-zero-gpu' bereits installiert sind,"
echo "und clinfo/sycl-ls die Karte trotzdem nicht sehen, prüfen Sie das Kernel-Modul 'i915' oder 'xe'."
echo "🔄 BITTE SYSTEM NEUSTARTEN."

FA

// ============================================================================
// SYCL Flash Attention Kernel für llama.cpp
// Optimierte Implementation mit Tiling-Strategie und Vektorisierung
// ============================================================================

#include <sycl/sycl.hpp>
#include <sycl/ext/intel/math.hpp>
#include <cmath>
#include <limits>
#include "ggml-sycl.h"
#include "ggml-impl.h"

using namespace sycl;

// Kernel-Parameter (optimiert für Intel Arc GPUs)
constexpr int BLOCK_M = 64;     // Queries pro Block
constexpr int BLOCK_N = 128;    // Keys pro Block (Tiling-Größe)
constexpr int D_MAX = 128;      // Maximale Head-Dimension
constexpr int VEC_SIZE = 8;     // Vektorgröße für Intel Arc (8 für optimalen SIMD)

// ============================================================================
// Vektorisierte Hilfsfunktionen
// ============================================================================

/**
 * @brief Vektorisiertes Dot-Produkt zwischen Q[i] und K[j]
 * @tparam scalar_t Datentyp (sycl::half oder float)
 * @param Q_row_float Query-Zeile als float[]
 * @param K_ptr Key-Pointer
 * @param d_k Head-Dimension
 * @return Dot-Product als float
 */
template <typename scalar_t>
float dot_product_vec(const float* Q_row_float, const scalar_t* K_ptr, int d_k) {
    if constexpr (std::is_same_v<scalar_t, sycl::half>) {
        if (d_k % VEC_SIZE != 0) {
            // Fallback für nicht-vektorisierte Dimensionen
            float score = 0.0f;
            for (int di = 0; di < d_k; ++di) {
                score += Q_row_float[di] * static_cast<float>(K_ptr[di]);
            }
            return score;
        }

        constexpr int vec_elements = VEC_SIZE;
        using vec_half = sycl::vec<sycl::half, vec_elements>;
        using vec_float = sycl::vec<float, vec_elements>;
        
        float final_score = 0.0f;
        int vec_iters = d_k / vec_elements;
        
        for (int v = 0; v < vec_iters; ++v) {
            // Lade K-Vektor (half)
            vec_half k_half_vec;
            k_half_vec.load(v * vec_elements, K_ptr);
            
            // Konvertiere zu float
            vec_float k_float_vec = k_half_vec.template convert<float>();
            
            // Lade Q-Vektor (float)
            vec_float q_float_vec;
            q_float_vec.load(v * vec_elements, Q_row_float);
            
            // Vektorisiertes Dot-Product
            final_score += sycl::dot(q_float_vec, k_float_vec);
        }
        return final_score;
    } else {
        // Fallback für float
        float score = 0.0f;
        for (int di = 0; di < d_k; ++di) {
            score += Q_row_float[di] * K_ptr[di];
        }
        return score;
    }
}

// ============================================================================
// Haupt-Flash-Attention Kernel
// ============================================================================

/**
 * @brief Flash Attention Kernel (Tiling-Strategie mit Score-Caching)
 * @tparam scalar_t Datentyp (sycl::half)
 */
template <typename scalar_t>
void flash_attention_kernel_impl(
    const scalar_t* Q_ptr,
    const scalar_t* K_ptr,
    const scalar_t* V_ptr,
    scalar_t* Out_ptr,
    int num_q,
    int num_k,
    int d_k,
    int d_v,
    int q_stride,
    int k_stride,
    int v_stride,
    int out_stride,
    sycl::nd_item<1> item
) {
    const int head_row = item.get_global_id(0);
    if (head_row >= num_q) return;

    // Lokale Register/Akkumulatoren
    float accum_den = 0.0f;                     // Denominator (Z)
    float running_max = -INFINITY;              // Globaler Max-Score (m)
    
    // Temporärer Speicher für Scores (in Registern/private memory)
    float S_scores[BLOCK_N];
    float accum_num[D_MAX] = {0.0f};           // Numerator (P*V Summe)

    // Lade gesamte Q-Zeile in Float-Register
    const scalar_t* Q_row_ptr = Q_ptr + head_row * q_stride;
    float Q_row_float[D_MAX];
    
    for (int di = 0; di < d_k; ++di) {
        Q_row_float[di] = static_cast<float>(Q_row_ptr[di]);
    }
    
    const float scale_factor = 1.0f / sycl::sqrt(static_cast<float>(d_k));

    // ========================================================================
    // Tiling-Strategie: Iteration über K/V-Blöcke
    // ========================================================================
    for (int k_start = 0; k_start < num_k; k_start += BLOCK_N) {
        const int k_block_size = sycl::min(BLOCK_N, num_k - k_start);
        float block_max = running_max;

        // --------------------------------------------------------------------
        // Phase 1: Scores berechnen und Max-Score finden
        // --------------------------------------------------------------------
        for (int kk = 0; kk < k_block_size; ++kk) {
            const int k_idx = k_start + kk;
            const scalar_t* K_block_ptr = K_ptr + k_idx * k_stride;
            
            // Dot-Product berechnen
            float score = dot_product_vec(Q_row_float, K_block_ptr, d_k);
            score *= scale_factor;
            
            S_scores[kk] = score;  // Score-Caching
            
            // Update Maximum
            block_max = sycl::fmax(block_max, score);
        }

        // --------------------------------------------------------------------
        // Phase 2: Log-Sum-Exp Trick mit Reskalierung
        // --------------------------------------------------------------------
        if (running_max != block_max) {
            const float scale = sycl::exp(running_max - block_max);
            accum_den *= scale;
            
            for (int vi = 0; vi < d_v; ++vi) {
                accum_num[vi] *= scale;
            }
            running_max = block_max;
        }

        // --------------------------------------------------------------------
        // Phase 3: Akkumulation von P*V
        // --------------------------------------------------------------------
        for (int kk = 0; kk < k_block_size; ++kk) {
            const int k_idx = k_start + kk;
            const float score = S_scores[kk];
            
            // Exponentiiertes und skaliertes Gewicht
            const float exp_val = sycl::exp(score - running_max);
            accum_den += exp_val;
            
            // Akkumuliere V * exp_val
            const scalar_t* V_block_ptr = V_ptr + k_idx * v_stride;
            
            // Vektorisierte Akkumulation für d_v
            if (d_v % VEC_SIZE == 0) {
                constexpr int vec_elements = VEC_SIZE;
                using vec_half = sycl::vec<sycl::half, vec_elements>;
                using vec_float = sycl::vec<float, vec_elements>;
                
                int vec_iters = d_v / vec_elements;
                float* accum_num_ptr = accum_num;
                
                for (int v = 0; v < vec_iters; ++v) {
                    // Lade V-Vektor
                    vec_half v_half_vec;
                    v_half_vec.load(v * vec_elements, V_block_ptr);
                    
                    // Konvertiere und multipliziere
                    vec_float v_float_vec = v_half_vec.template convert<float>();
                    v_float_vec *= exp_val;
                    
                    // Akkumuliere
                    vec_float acc_vec;
                    acc_vec.load(v * vec_elements, accum_num_ptr);
                    acc_vec += v_float_vec;
                    acc_vec.store(v * vec_elements, accum_num_ptr);
                }
            } else {
                // Skalar-Fallback
                for (int vi = 0; vi < d_v; ++vi) {
                    accum_num[vi] += exp_val * static_cast<float>(V_block_ptr[vi]);
                }
            }
        }
    }

    // ========================================================================
    // Phase 4: Finalisierung (Out = Accum_Num / Accum_Den)
    // ========================================================================
    scalar_t* Out_row_ptr = Out_ptr + head_row * out_stride;
    
    if (accum_den == 0.0f) {
        // Division durch Null verhindern
        for (int vi = 0; vi < d_v; ++vi) {
            Out_row_ptr[vi] = scalar_t(0.0f);
        }
        return;
    }
    
    const float inv_den = 1.0f / accum_den;
    
    // Vektorisierter Store
    if (d_v % VEC_SIZE == 0) {
        constexpr int vec_elements = VEC_SIZE;
        using vec_half = sycl::vec<sycl::half, vec_elements>;
        using vec_float = sycl::vec<float, vec_elements>;
        
        int vec_iters = d_v / vec_elements;
        
        for (int v = 0; v < vec_iters; ++v) {
            // Lade akkumulierte Werte
            vec_float acc_vec;
            acc_vec.load(v * vec_elements, accum_num);
            
            // Skaliere und konvertiere
            acc_vec *= inv_den;
            vec_half out_vec = acc_vec.template convert<sycl::half>();
            
            // Speichere Ergebnis
            out_vec.store(v * vec_elements, Out_row_ptr);
        }
    } else {
        // Skalar-Fallback
        for (int vi = 0; vi < d_v; ++vi) {
            Out_row_ptr[vi] = static_cast<sycl::half>(accum_num[vi] * inv_den);
        }
    }
}

// ============================================================================
// Kernel-Wrapper-Funktion
// ============================================================================

/**
 * @brief SYCL Flash Attention Wrapper für ggml
 */
extern "C" void ggml_sycl_op_flash_attn(
    ggml_backend_sycl_context* ctx,
    ggml_tensor* dst,
    const ggml_tensor* Q,
    const ggml_tensor* K,
    const ggml_tensor* V
) {
    // Nur FP16 wird unterstützt
    if (Q->type != GGML_TYPE_F16 || K->type != GGML_TYPE_F16 || V->type != GGML_TYPE_F16) {
        GGML_ABORT("ggml_sycl_op_flash_attn: Nur GGML_TYPE_F16 wird unterstützt!");
        return;
    }

    // SYCL Queue holen
    sycl::queue& q = ggml_backend_sycl_get_queue(Q->backend);

    // Tensor-Dimensionen extrahieren
    const int num_q = Q->ne[1];      // Query-Sequenzlänge
    const int num_k = K->ne[1];      // Key/Value-Sequenzlänge
    const int d_k = Q->ne[0];        // Head-Dimension (d_k)
    const int d_v = V->ne[0];        // Head-Dimension (d_v)

    // Dimensionen validieren
    if (d_k > D_MAX || d_v > D_MAX) {
        GGML_ABORT("ggml_sycl_op_flash_attn: Dimension d_k=%d oder d_v=%d überschreitet D_MAX=%d",
                   d_k, d_v, D_MAX);
        return;
    }

    if (d_k % VEC_SIZE != 0 || d_v % VEC_SIZE != 0) {
        GGML_WARN("ggml_sycl_op_flash_attn: Dimensionen nicht vielfach von VEC_SIZE=%d, Performance reduziert", VEC_SIZE);
    }

    // Strides berechnen (in Elementen, nicht Bytes)
    const int q_stride = Q->nb[1] / sizeof(sycl::half);
    const int k_stride = K->nb[1] / sizeof(sycl::half);
    const int v_stride = V->nb[1] / sizeof(sycl::half);
    const int out_stride = dst->nb[1] / sizeof(sycl::half);

    // Pointer zu den Daten
    sycl::half* Q_data = reinterpret_cast<sycl::half*>(Q->data);
    sycl::half* K_data = reinterpret_cast<sycl::half*>(K->data);
    sycl::half* V_data = reinterpret_cast<sycl::half*>(V->data);
    sycl::half* Out_data = reinterpret_cast<sycl::half*>(dst->data);

    // Globaler Arbeitsbereich: Ein Work-Item pro Query-Zeile
    const sycl::range<1> global_size(num_q);

    // Kernel ausführen
    q.submit([&](sycl::handler& h) {
        h.parallel_for<class flash_attention_kernel>(global_size, [=](sycl::nd_item<1> item) {
            flash_attention_kernel_impl<sycl::half>(
                Q_data, K_data, V_data, Out_data,
                num_q, num_k, d_k, d_v,
                q_stride, k_stride, v_stride, out_stride,
                item
            );
        });
    });
}

