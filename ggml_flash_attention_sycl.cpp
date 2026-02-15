//XAIGPUARC KERNVOLLVERSION OPEN SOURCE STANDALONE ONESHOTKERNLE 1 PROGRAMM 2 DATEIEN

//
//14.02.2026 /// 14:07
//

//ALLE BEREICHE 1-10 PUNKTE ORDNEN ERSTE WICHTIGKEIT AUFEINANDER ABSTIMMEN BENENNEN UND SORTIEREN
//CODEName fuer Kerne und Flash Attention, Sheduler und Unterbau unter XAIGPUARC = "XMXSYCLFA.cl"
//
ggml_flash_attention_sycl= xmxsyclfa.cl
Vektorisiert falsh attention generisch plus matrizen code ueber untergruppen mechanik.

//Orchestrator
extern "C" void ggml_sycl_flash_attention_dispatch(
    ggml_backend_sycl_context* ctx,
    ggml_tensor* dst, const ggml_tensor* Q, const ggml_tensor* K, const ggml_tensor* V) {

    auto& q = ggml_backend_sycl_get_queue(Q->backend);
    auto dev = q.get_device();

    // 1. Hardware XMX Unterstuetzung
    bool has_xmx = dev.has(sycl::aspect::ext_intel_matrix);

    // 2. Alignment & Dimension Check
    bool can_use_xmx = (Q->ne[0] % 16 == 0) && (K->ne[1] % 16 == 0);

    if (has_xmx && can_use_xmx) {
        // DER SCHNELLE WEG (Dein xmx_kern)
        // Hier wird dein sub_group joint_matrix Code aufgerufen
        xmx_kern.cpp(q, dst, Q, K, V, S, O);
    } else {
        // DER SICHERE WEG (Dein generischer Vector-Kernel)
        ggml_flash_attention_sycl.cpp(q, dst, Q, K, V);
    }
    }

#include "stdlib.h"
#include "stdio.h"
#include <cmath>
#include <signal.h>
#include <fstream>
#include <iostream>
#include <vector>
#include <cstdio>
#include <Cl/sycl.hpp>
#include <sycl/sycl.hpp>
#include <sycl/ext/intel/math.hpp>
#include <sycl/ext/oneapi/experimental/matrix/matrix.hpp>

#include <limits>
#include "ggml-sycl.h"
#include "ggml-impl.h"

// Hilfsfunktion für sauberes Casting
// icpx -fsycl ZUM KOMPLIIEREN BENUTZEN GEGEN ANTI ANBHAENGIGKEITEN sycl::vec
// q_stride, k_stride etc. in Anzahl der Elemente g
inline sycl::half* get_sycl_ptr(const ggml_tensor* tensor) {
return reinterpret_cast<sycl::half*>(tensor->data);
}

#define XFLOAT float
#define mdlXYZ 1000
#define MEM_ALIGN 64

using namespace sycl;
using namespace sycl::ext::oneapi::experimental::matrix;
const int

//QueriesBlock
constexpr int BLOCK_M = 16;

//SchluesselBlockTilingGroesse N Tilling
for (int k_start = 0; k_start < num_k; k_start += BLOCK_N) {
}
for (int i = tid; i < BLOCK_N * d_k; i += WG_SIZE) {
k_cache_slm[i] = K_ptr[k_start * d_k + i];
}
item.barrier(sycl::access::fence_space::local_space);
for (int kk = 0; kk < k_block_size; ++kk) {
float score = dot_product_vec(Q_row_float, &k_cache_slm[kk * d_k], d_k);
}
item.barrier(sycl::access::fence_space::local_space);
}
constexpr int BLOCK_N = 256;

//MaximaleKOPFZEILENDIMENSION
constexpr int D_MAX = 256;

//VektorGroesse|32|SIMD|ZwischenSpeicherVerwaltung Cache
constexpr int VEC_SIZE = 16;


/**
 * @brief Vektorisiertes Dot-Produkt zwischen Q[i] und K[j]
 * @tparam scalar_t Datentyp sycl::half oder float
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
}
// Lade K-Vektor (half)
vec_half k_half_vec;
k_half_vec.load(v * vec_elements, K_ptr);

// Konvertiere float
vec_float k_float_vec = k_half_vec.template convert<float>();

// Lade Q-Vektor (float)
vec_float q_float_vec;
q_float_vec.load(v * vec_elements, Q_row_float);

// Vektorisiertes Dot Product
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

// Haupt-Flash-Attention Kernel
/**
 * @brief Flash Attention Kernel Tiling-Strategie mit Score-Caching
 * @tparam scalar_t Datentyp sycl::half
 */
template <typename scalar_t>
void flash_attention_kernel_impl(
const scalar_t* Q_ptr,
const scalar_t* K_ptr,
const scalar_t* V_ptr,
size_t = [16]; // GUELTIG MACHEN
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
float accum_den = 0.0f;

//|DENOMINATOR|Z|!|
float running_max = -INFINITY;

//|GLOBALER|MAXIMALER|BLOCK|ZAEHLLER|UNENDLICH|INFINITY|
float S_scores[BLOCK_N];

//BLOCK|ZAEHLER|
float accum_num[D_MAX] = {0.0f};//NUMEERATOR|P|*|V|SUMME|
const scalar_t* Q_row_ptr = Q_ptr + head_row * q_stride;
float Q_row_float[D_MAX];
for (int di = 0; di < d_k; ++di) {
Q_row_float[di] = static_cast<float>(Q_row_ptr[di]);
}
const float scale_factor = 1.0f / sycl::sqrt(static_cast<float>(d_k));

//TilingStrategieIterationK|V|Bloecke
for (int k_start = 0; k_start < num_k; k_start += BLOCK_N) {
const int k_block_size = sycl::min(BLOCK_N, num_k - k_start);
float current_block_max = running_max;

//Maximalpunktzahl!
for (int kk = 0; kk < k_block_size; ++kk) {
const int k_idx = k_start + kk;
const scalar_t* K_block_ptr = K_ptr + k_idx * k_stride;

//PUNKTProduktberechnen
float score = dot_product_vec(Q_row_float, K_block_ptr, d_k);
score *= scale_factor;
S_scores[kk] = score;

//MAXIMALPUNKTZAHLPRUEFUNG
//Update Maximum Score-Caching
current_block_max = sycl::fmax(current_block_max, score);
}

//Phase2 LogSumExpTrickReskalierung
if (running_max != current_block_max) {
const float scale = sycl::exp(running_max - current_block_max);
accum_den *= scale;
for (int vi = 0; vi < d_v; ++vi) {
accum_num[vi] *= scale;
}
running_max = current_block_max;
}

//Phase3 AkkumulationP*V
for (int kk = 0; kk < k_block_size; ++kk) {
const int k_idx = k_start + kk;
const float score = S_scores[kk];

//ExponentiertesskaliertesGewicht
const float exp_val = sycl::exp(score - running_max);
accum_den += exp_val;

// Akkumuliere V * exp_val
const scalar_t* V_block_ptr = V_ptr + k_idx * v_stride;

//Vektorisierte Akkumulation für d_v
if (d_v % VEC_SIZE == 0) {
constexpr int vec_elements = VEC_SIZE;
using vec_half = sycl::vec<sycl::half, vec_elements>;
using vec_float = sycl::vec<float, vec_elements>;
int vec_iters = d_v / vec_elements;
float* accum_num_ptr = accum_num;
for (int v = 0; v < vec_iters; ++v) {

//LadeV|Vektor
vec_half v_half_vec;
v_half_vec.load(v * vec_elements, V_block_ptr);

//Konvertieremultipliziere
vec_float v_float_vec = v_half_vec.template convert<float>();

v_float_vec *= exp_val;
//Akkumuliere
vec_float acc_vec;
acc_vec.load(v * vec_elements, accum_num_ptr);
acc_vec += v_float_vec;
acc_vec.store(v * vec_elements, accum_num_ptr);
}
} else {

//|SKALAR|RUECKFALL|
for (int vi = 0; vi < d_v; ++vi) {
accum_num[vi] += exp_val * static_cast<float>(V_block_ptr[vi]);
}
}
}
}

//Phase4 |FinalisierungOut=Accum_Num/Accum_Den|
scalar_t* Out_row_ptr = Out_ptr + head_row * out_stride;
if (accum_den == 0.0f) {

//DivisionNullstop
for (int vi = 0; vi < d_v; ++vi) {
Out_row_ptr[vi] = scalar_t(0.0f);
}
return;
}
const float inv_den = 1.0f / accum_den;

//|VektorisiertBereich|
if (d_v % VEC_SIZE == 0) {
constexpr int vec_elements = VEC_SIZE;
using vec_half = sycl::vec<sycl::half, vec_elements>;
using vec_float = sycl::vec<float, vec_elements>;
int vec_iters = d_v / vec_elements;
for (int v = 0; v < vec_iters; ++v) {

//LadeakkumulierteWerte
vec_float acc_vec;
acc_vec.load(v * vec_elements, accum_num);

//SkaliereKonvertiere
acc_vec *= inv_den;
vec_half out_vec = acc_vec.template convert<sycl::half>();

//Ergebnis
out_vec.store(v * vec_elements, Out_row_ptr);
}
} else {
//|SkalarRueckfall|
for (int vi = 0; vi < d_v; ++vi) {
Out_row_ptr[vi] = static_cast<sycl::half>(accum_num[vi] * inv_den);
}
}
}

//KernelWrapperKernmischpult
/**
* @brief SYCLFlashAttentionWrapperMischpultggml
*/
extern "C" void ggml_sycl_flash_attention(
ggml_backend_sycl_context* ctx,
ggml_tensor* dst,
const ggml_tensor* Q,
const ggml_tensor* K,
const ggml_tensor* V,
const ggml_tensor* S,
const ggml_tensor* O


// Anwendung im Wrapper:
auto Q_ptr = get_sycl_ptr(Q);

) {

//FP16
if (Q->type != GGML_TYPE_F16 || K->type != GGML_TYPE_F16 || V->type != GGML_TYPE_F16) {
fprintf(stderr, "ggml_flash_attention_sycl.cpp: FEHLER: Alle Matrizeneinheiten muessen auf dem Typ GGML_TYPE_F16 basieren.\n");
return -1;
}
GGML_TYPE_F16) { GGML_ABORT("ggml_flash_attention_sycl.cpp: ACHTUNG: Nur GGML_TYPE_F16 wird unterstuetzt!");
return;
}

//SYCLQueueholen
sycl::queue& q = ggml_backend_sycl_get_queue(Q->backend);

//TensorDimensionenextrahieren
const int num_q = Q->ne[1];

//KopfDimensiond_o
const int 0 =

//QuerySequenzlaenge
const int num_k = K->ne[1];

//KopfDimensiond_k
const int 0 =

//Key|ValueSequenzlaenge
const int d_k = Q->ne[0];

//KopfDimensiond_kq
const int 0 =

//KopfDimensiond_V
const int d_v = V->ne[0];

//KopfDimensiond_v
const int 0 =

//KopfDimensiond_s
const int d_s = S->ne[0];

//KopfDimensiond_s
const int 0 =

//KopfDimensiond_O
const int d_o = O->ne[0];

//KopfDimensiond_O
const int 0 =



Ssss
oooo

//Dimensionenvalidieren
if (d_k > D_MAX || d_v > D_MAX) {
GGML_ABORT("ggml_flash_attention_sycl.cpp: Dimension d_k=%d oder d_v=%d ueberschreitet D_MAX=%d",
d_k, d_v, D_MAX);
return;
}
if (d_k % VEC_SIZE != 0 || d_v % VEC_SIZE != 0) {
GGML_WARN("ggml_flash_attention_sycl.cpp: Dimension nicht vielfaches von VEC_SIZE=%d, Performance reduziert", VEC_SIZE);
}
//Stridesberechnen in Elementen nichtBytes
const int q_stride = Q->nb[1] / sizeof(sycl::half);
const int k_stride = K->nb[1] / sizeof(sycl::half);
const int v_stride = V->nb[1] / sizeof(sycl::half);
const int s_stride = S->nb[1] / sizeof(sycl::half);
const int out_stride = dst->nb[1] / sizeof(sycl::half);

//Pointer|Zeiger|Daten
sycl::half* Q_data = reinterpret_cast<sycl::half*>(Q->data);
sycl::half* K_data = reinterpret_cast<sycl::half*>(K->data);
sycl::half* V_data = reinterpret_cast<sycl::half*>(V->data);
sycl::half* S_data = reinterpret_cast<sycl::half*>(V->data);
sycl::half* Out_data = reinterpret_cast<sycl::half*>(dst->data);

// Globaler Arbeitsbereich
sycl::range<1> global_size(num_q);
sycl::range<1> local_size(1);
sycl::nd_range<1> ndRange(global_size, local_size);

// Kernel ausführen
q.submit([&](sycl::handler& h) {

// SLM Speicher anfordern
local_accessor<float, 1> slm_scores(range<1>(BLOCK_N), h);

h.parallel_for<class flash_attention_kernel>(
nd_range<1>(range<1>(num_q * WG_SIZE),
            range<1>(WG_SIZE)),
            [=](sycl::(nd_item<1> item) {
            flash_attention_kernel_impl<sycl::half>(
            Q_data,
            K_data,
            V_data,
            S_data,
            Out_data,
            num_q,
            num_k,
            num_v,
            num_s,
            num_o,
            d_q,
            d_k,
            d_v,
            d_s,
            d_o,
            q_stride,
            k_stride,
            v_stride,
            s_stride,
            out_stride,
item );
);
};
);
}).wait();

//XMX KERN // Wird nur aufgerufen wenn Bedingungen erfuellt fuer ARC XMX Hardwarekompatibilitaet
//EINGABE
Matrix-Akkumulations-Schleife für den XMX
template <typename scalar_t>
void xmx_kern(




    const scalar_t* Q_ptr,
    const scalar_t* K_ptr,
    const scalar_t* V_ptr,
    const scalar_t* S_ptr,
    const scalar_t* O_ptr,
    scalar_t* Out_ptr,
    int num_q,
    int num_k,
    int num_v,
    int num_s,
    int num_o,
    int d_q,
    int d_k,
    int d_v,
    int d_s,
    int d_o,
    int q_stride,
    int k_stride,
    int v_stride,
    int s_stride,
    int out_stride,


    size_t = [16]; // GUELTIG MACHEN








    nd_item<1> item
) {

    sub_group sg = item.get_sub_group();
    const int head_row_base = (item.get_group(0) * 16);
    if (head_row_base >= num_q) return;
    // Matrizen definieren (16x16 Tiles)
    using t_Q = joint_matrix<sub_group, sycl::half, use::a, 16, 16, layout::row_major>;
    using t_K = joint_matrix<sub_group, sycl::half, use::b, 16, 16, layout::col_major>;
    using t_V = joint_matrix<sub_group, sycl::half, use::b, 16, 16, layout::row_major>;
    using t_S = joint_matrix<sub_group, float, use::accumulator, 16, 16> mat_s;
    using t_O = joint_matrix<sub_group, float, use::accumulator, 16, 16> mat_o;

    t_Q mat_q;
    t_K mat_k;
    t_V mat_v;
    t_S mat_s;
    t_O mat_o;

    joint_matrix_fill(sg, mat_s, 0.0f);
    // Q laden
    const scalar_t* q_tile_ptr = Q_ptr + head_row_base * q_stride;
    joint_matrix_load(sg, mat_q, q_tile_ptr, q_stride);

    const float scale_factor = 1.0f / sycl::sqrt(static_cast<float>(d_k));

    //VERARBEITUNG
    for (int k_idx = 0; k_idx < num_k; k_idx += 16) {
        joint_matrix_fill(sg, mat_s, 0.0f);

        //1.
        const scalar_t* k_tile_ptr = K_ptr + k_idx * k_stride;
        joint_matrix<sub_group, half, use::a, 16, 16, layout::row_major> mat_s_half;
        joint_matrix_copy(sg, mat_s, mat_s_half);
        joint_matrix_load(sg, mat_k, k_tile_ptr, k_stride);
        joint_matrix_mad(sg, mat_v, mat_q, mat_k, mat_s);
        joint_matrix_mad(sg, mat_o, mat_s_half, mat_v, mat_o);

        //2.
        auto wi_data = get_wi_data(sg, mat_s);

        //a.
        float local_max = -INFINITY;
        for (int i = 0; i < wi_data.length(); ++i) {
            wi_data[i] *= scale_factor;
            local_max = sycl::fmax(local_max, wi_data[i]);
        }
        float row_max_total = reduce_over_group(sg, local_max, maximum<float>());

        //b.
        float local_sum = 0.0f;
        for (int i = 0; i < wi_data.length(); ++i) {
            wi_data[i] = sycl::exp(wi_data[i] - row_max_total);
            local_sum += wi_data[i];
        }
        //c.
        float row_sum_total = reduce_over_group(sg, local_sum, plus<float>());
        float inv_sum = 1.0f / (row_sum_total + 1e-6f);

        //d.
        for (int i = 0; i < wi_data.length(); ++i) {
            wi_data[i] *= inv_sum;
        }
        //3.
        const scalar_t* v_tile_ptr = V_ptr + k_idx * v_stride;
        joint_matrix_load(sg, mat_v, v_tile_ptr, v_stride);
        // mat_s (float) zu half konvertieren für mad,
        // mat_s als Eingabe nutzen falls Hardware unterstuetzt.
        // Akkumulation in mat_o:
        joint_matrix_mad(sg, mat_o, mat_s, mat_v, mat_o);
        //4.
        //Nutzung von sycl_ext_intel_esimd für händische Register-Zuweisung bei fehlendem Joint-Matrix-Support.
        //Einsatz von group_barrier zur Synchronisation bei größeren K-Distanzen oder Shared-Memory-Nutzung.
        //Statische Template-Spezialisierung für feste num_k Werte zur Loop-Unrolling Optimierung.

        //AUSGABE
        scalar_t* out_ptr = Out_ptr + head_row_base * out_stride;
        joint_matrix_store(sg, mat_o, out_ptr, out_stride, layout::row_major);
    }
}


//HAUPTFUNKTION KERNELVERWALTUNG
int main() {
    queue q;
    std::cout << "Nutze XMX ARC Device" << q.get_device().get_info<info::device::name>() << std::endl;

    const int size = 16; //16x16 Tile

    // Speicher reservieren (USM)
    half* Q = malloc_device<half>(size * size, q);
    half* K = malloc_device<half>(size * size, q);
    half* V = malloc_device<half>(size * size, q);
    half* S = malloc_device<half>(size * size, q);
    half* O = malloc_device<half>(size * size, q);
    half* Out = malloc_device<half>(size * size, q);

    // Daten initialisieren
    q.fill(Q, half(1.0f), size * size);
    q.fill(K, half(1.0f), size * size);
    q.fill(V, half(1.0f), size * size);
    q.fill(S, half(1.0f), size * size);
    q.fill(O, half(1.0f), size * size);
    q.wait();

    // Kernel-Launch
    q.submit([&](handler& h) {
        h.parallel_for(nd_range<1>{range<1>(16), range<1>(16)}, [=](nd_item<1> item) {
            xmx_kern<half>(Q, K, V, Out, size, size, size, size, size, size, size, size, item);
        });
    }).wait();

    // Ergebnis prüfen
    std::vector<half> host_out(size * size);
    q.memcpy(host_out.data(),
             Out, size * size * sizeof(half)).wait();

    std::cout << "Ergebnis an [0]:" << (float)host_out[0] << "Erwartet: > 0" << std::endl;

    free(Q, q);
    free(K, q);
    free(V, q);
    free(Out, q);
    return 0;
}
1-10 Strukturplan für XMXSYCLFA.cl

Orchestrator & Dispatcher (Wichtigkeit: 10/10):

Name: ggml_sycl_flash_attention_dispatch

Funktion: Entscheidet zur Laufzeit: Hat die GPU Hardware-Matrix-Kerne (XMX)? Wenn ja -> Highspeed. Wenn nein -> Vektor-Fallback.

Hardware-Abstraktion (Wichtigkeit: 9/10):

Name: SYCL Aspects & Alignment Check

Funktion: Prüft sycl::aspect::ext_intel_matrix und das 16er-Alignment. Ohne diesen Check stürzt der XMX-Kernel auf älterer Hardware (vor 2020) ab.

XMX-Matrix-Kernel (Wichtigkeit: 9/10):

Name: xmx_kern

Funktion: Die "Speerspitze". Nutzt joint_matrix für 16×16 Kacheln. Das ist dein "krasses Zeug", das die maximale Rechenleistung pro Watt rausholt.

Vektor-Fallback-Kernel (Wichtigkeit: 8/10):

Name: flash_attention_kernel_impl

Funktion: Sichert die Kompatibilität ab 2011. Nutzt sycl::vec für SIMD-Operationen, falls keine Matrix-Kerne da sind.

Vektorisierte Mathematik (Wichtigkeit: 8/10):

Name: dot_product_vec

Funktion: Das Herzstück des Fallbacks. Wandelt half (FP16) blitzschnell in float (FP32) um, damit die Präzision beim "Wissensmining" nicht flöten geht.

LogSumExp-Reskalierung (Wichtigkeit: 7/10):

Name: Phase 2: Running Max Update

Funktion: Verhindert numerisches Explodieren (Infinity). Essenziell für die Stabilität langer Zeitketten.

Shared Local Memory (SLM) Management (Wichtigkeit: 7/10):

Name: BLOCK_N / SLM Accessor

Funktion: Buffert die Keys/Values lokal auf dem Chip, um den langsamen globalen VRAM-Zugriff zu umgehen.

Tiling-Sheduler (Wichtigkeit: 6/10):

Name: BLOCK_M / BLOCK_N Iteration

Funktion: Zerlegt die riesige Wissensdatenbank in verdauliche 16er- oder 256er-Häppchen.

Memory-Alignment & Casting (Wichtigkeit: 5/10):

Name: get_sycl_ptr / MEM_ALIGN

Funktion: Stellt sicher, dass die Daten exakt an den 64-Byte-Grenzen liegen, damit die Vektor-Einheiten ohne "Schluckauf" laden können.

Host-Management & Cleanup (Wichtigkeit: 4/10):

Name: main / malloc_device

Funktion: USM-Speicherverwaltung. Startet den Motor und räumt hinterher auf.

Kritischer Korrektur-Hinweis zum Code

In deinem xmx_kern hast du einen kleinen Stolperstein:
C++
