#include <sycl/sycl.hpp>
#include <sycl/ext/intel/math.hpp>
#include <cmath>
#include <limits>
#include "ggml-sycl.h"
#include "ggml-impl.h"

using namespace sycl;
sycl::range
constexpr int BLOCK_M = 64;
//Queries|Block
constexpr int BLOCK_N = 128;
//Schluessel||Block|TilingGroesse|
constexpr int D_MAX = 128;
//Maximale|KOPFZEILENDIMENSION|
constexpr int VEC_SIZE = 32;
//VektorGroesse|32|SIMD|ZwischenSpeicherVerwaltung|
//Ein 32-Elemente-Vektor von half (FP16) entspricht exakt 512 Bit

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
extern "C" void ggml_sycl_op_flash_attn(
ggml_backend_sycl_context* ctx,
ggml_tensor* dst,
const ggml_tensor* Q,
const ggml_tensor* K,
const ggml_tensor* V
) {
//FP16
if (Q->type != GGML_TYPE_F16 || K->type != GGML_TYPE_F16 || V->type !=
GGML_TYPE_F16) { GGML_ABORT("ggml_sycl_op_flash_attn: Nur GGML_TYPE_F16 wird unterstuetzt!");
return;
}
//SYCLQueueholen
sycl::queue& q = ggml_backend_sycl_get_queue(Q->backend);
//TensorDimensionenextrahieren
const int num_q = Q->ne[1];
//QuerySequenzlaenge
const int num_k = K->ne[1];
//Key|ValueSequenzlaenge
const int d_k = Q->ne[0];
//KopfDimensiond_k
const int d_v = V->ne[0];
//KopfDimensiond_v

//Dimensionenvalidieren
if (d_k > D_MAX || d_v > D_MAX) {
GGML_ABORT("ggml_sycl_op_flash_attn: Dimension d_k=%d oder d_v=%d ueberschreitet D_MAX=%d",
d_k, d_v, D_MAX);
return;
}
if (d_k % VEC_SIZE != 0 || d_v % VEC_SIZE != 0) {
GGML_WARN("ggml_sycl_op_flash_attn: Dimension nicht vielfaches von VEC_SIZE=%d, Performance reduziert", VEC_SIZE);
}
//Stridesberechnen in Elementen nichtBytes
const int q_stride = Q->nb[1] / sizeof(sycl::half);
const int k_stride = K->nb[1] / sizeof(sycl::half);
const int v_stride = V->nb[1] / sizeof(sycl::half);
const int out_stride = dst->nb[1] / sizeof(sycl::half);
//Pointer|Zeiger|Daten
sycl::half* Q_data = reinterpret_cast<sycl::half*>(Q->data);
sycl::half* K_data = reinterpret_cast<sycl::half*>(K->data);
sycl::half* V_data = reinterpret_cast<sycl::half*>(V->data);
sycl::half* Out_data = reinterpret_cast<sycl::half*>(dst->data);
// Globaler Arbeitsbereich
sycl::range<1> global_size(num_q); sycl::range<1> local_size(1);
sycl::nd_range<1> ndRange(global_size, local_size);
// Kernel ausführen
q.submit([&](sycl::handler& h)
{ h.parallel_for<class flash_attention_kernel>( ndRange,
[=](sycl::nd_item<1> item)
{ flash_attention_kernel_impl<sycl::half>( Q_data, K_data, V_data, Out_data, num_q, num_k, d_k, d_v, q_stride, k_stride, v_stride, out_stride, item );
            );
        });
    }).wait();
}
