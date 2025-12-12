#!/bin/bash

#9.) How to START your XAIGPUARC ONEKLICK AI-MACHINE?!

#0.) FIRST INTEL_ONE_API_BASEKIT MUST BE INSTALLED ON YOUR PC/LAPTOP/SYSTEM

#0.) Second is using ARCH Garuda LINUX By The Way!?! Also Good for GAMING and WINDOWS Ex Power Use!

#1.) Kopie XAIGPUARC.sh in your Home/PCNAME/ Folder!

#2.) Between XAIGPUARC Full INSTALLATION Download a gguf AI fit in your

#a.) V/RAM to /models/HereAINAME also in your Home/PCNAME/models/HereAINAME Folder!

#3.) Change your Modell here in the Textfile twice below!

#b.) Open Console and Type: chmod +x ./XAIGPUARC.sh Enter...

#4.) START with type in Console ./XAIGPUARC.sh Enter...

#-XAIGPUARC Hardware used to Build and Test
#-6x Intel ARC 2xA770LE 16GB + 4x750LE 8GB 
#-90-142 Watt each Card at different LLMs
#-Example: GPT-OSS-20B-F16 does it very nice at low Wattage
#-but needs longer than full working MathTutor F16 with 142 Watt
#-I just use both/multible Models for a better Workflow
#-3x Single and Dual dGPUs on AMD Ryzen 2600 2700x Intel i7 6700K on Z170 RAM 16 till 128GB
#-2x Intel iGPU XE Alder Lake Gen + CPU 12700H + 12650H + A730m 12 GB + 6GiB DDR4/5 32GB RAM
#-1x Intel Core Ultra 7 155H + Meteor Lake 7/8 Core LPG 128EU ARC 16GiB
#-Quad Channel High Bandwith RAM (GEAR2 with 718GB/s)
#-11,5 GiB VRAM shared from this RAM
#-On 155H i7 GPT-OSS-20B-F16.gguf runs well but slow at 30 Watt allinone with mods

#Qwen2.5-VL-3B-Instruct-f16-q4_k.gguf            2.1     GB
#Qwen2.5-VL-3B-Instruct-f16.gguf                 5.8     GB
#Qwen2.5-7B-Instruct-f16-q4_k.ggufVery Nice      5.7     GB
#Qwen3-Embedding-4B-f16.gguf                     7.5     GB
#Qwen3-4B-f16.gguf                               7.5     GB

#DiffuCoder-7B-cpGRPO-f16_q8_0.gguf              10.5    GB

#ggml-model-f16.gguf                             12.6    GB
#gpt-oss-20b-F16.gguf                            12.8    GB
#Mistral-7B-Instruct-v0.3.fp16.gguf              13.5    GB
#Nemotron-Mini-4B-Instruct-f16.gguf              7.8     GB
#Minitron-4B-Base.FP16-.gguf                     7.8     GB
#Nemotron-Orchestrator-8B-f16_q8_0.gguf          11.4    GB

#NVIDIA-Nemotron-Nano-12B-v2-F16.gguf            22.9    GB
#llama3bthinkingonly5B.f16.gguf                  6.0     GB

#MathTutor-7B-H_v0.0.1.f16.ggufUSETHAT           14.2    GB

#NOT F16! MODE but also well Tested
#Qwen3-16B-A3B-IQ4_NL.gguf                       8.5     GB
#Qwen3-30B-A3B-UD-IQ2_XXS.gguf                   9.7     GB
#gpt-oss-20b-claude-4-distill.MXFP4_MOE.gguf     11.3    GB
#gpt-oss-20b-mxfp4.gguf                          11.3    GB
#NVIDIA-Nemotron-Nano-12B-v2-IQ4_NL.gguf         6.6     GB

set -euo pipefail
IFS=$'\n\t'

PRECISION="FP16"
DEVICE="ARC"

LLAMA_CPP_DIR="llama.cpp"
BUILD_DIR="${BUILD_DIR:-XAIGPUARC}"
BUILD_DIR="${BUILD_DIR%/}"

#XAIGPUARC
GGML_SYCL_CPP="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/ggml-sycl.cpp"
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
NPROC="${NPROC:-$(nproc)}"
LOG_FILE="${BUILD_DIR}/XAIGPUARC.log"
LLAMA_CLI_PATH="bin/llama-cli"
LS_SYCL_DEVICE_PATH="bin/llama-ls-sycl-device"

#ONEAPIFUNKTIONEN
export TCM_ROOT="${TCM_ROOT:-/opt/intel/oneapi/tcm/latest}"
export SYCL_CACHE_PERSISTENT=1
export OCL_ICD_FILENAMES=""
export ZES_ENABLE_SYSMAN=1
export OverrideDefaultFP64Settings=1
export CCACHE_DIR="$HOME/.ccache"
export COMPILER_VERSION="2025.0"
export SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1
export SYCL_PI_LEVEL_ZERO_BATCH_SIZE=128

#HILFSFUNKTIONEN
log() { printf "🔷 %s\n" "$*"; }
success() { printf "✅ %s\n" "$*"; }
error() { printf "❌ %s\n\n" "$*"; }
warn() { printf "⚠️ %s\n" "$*"; }

#INTERNETPRUEFUNG
check_internet() {
log "🔷PRUEFE INTERNETVERBINDUNG"
if timeout 5 bash -c "</dev/tcp/8.8.8.8/53" 2>/dev/null; then
success "✅INTERNETVERBINDUNG VORHANDEN"
return 0
else
warn "⚠️KEINE INTERNETVERBINDUNG GEFUNDEN BEI ERSTINSTALLATION FUR DAS LADEN VON ABHAENGIGKEITEN NOTWENDIG BITTE ANSCHLUSS PRUEFEN"
return 1
fi
}

#UMGEBUNGRUECKFALLMECHANISMENVORBEREITEN
prepare_environment() {
log "🔷HOLE ONE API KOPFZEILENUEBERSCHRIFTEN FUER XAIGPUARC BCXAI ALUCIAN BLOCKWORKORANGE ORIGINAL ULTRA MADNESS EDITION"
local SETVARS_PATH="/opt/intel/oneapi/setvars.sh"
if [ ! -f "$SETVARS_PATH" ]; then
error "❌ONEAPI KOEPFE NICHT GEFUNDEN $SETVARS_PATH INSTALLIERE ZU ERST ONE API BIBLIOTHEKEN"
exit 1
fi
log "SETVARSSH SETZEN UND SUCHEN"
source "$SETVARS_PATH" --force 2>/dev/null
local ONEAPI_ROOT_FALLBACK="/opt/intel/oneapi"
local COMPILER_VERSION_FALLBACK="${COMPILER_VERSION:-2025.0}"
DPCPP_ROOT="${DPCPP_ROOT:-${ONEAPI_ROOT_FALLBACK}/compiler/${COMPILER_VERSION_FALLBACK}}"
MKL_ROOT="${MKL_ROOT:-${ONEAPI_ROOT_FALLBACK}/mkl/${COMPILER_VERSION_FALLBACK}}"
ONEAPI_ROOT="${ONEAPI_ROOT:-${ONEAPI_ROOT_FALLBACK}}"
export CC=icx
export CXX=icpx
export FC=ifx
export DPCPP_ROOT
export MKL_ROOT
export ONEAPI_ROOT
export CPATH="${CPATH:-}:${MKL_ROOT}/include"
local LIB_DIR="/opt/intel/oneapi/compiler/latest/lib:/opt/intel/oneapi/mkl/latest/lib"
export LD_LIBRARY_PATH="./${BUILD_DIR}/bin:${LIB_DIR}:${LD_LIBRARY_PATH:-}"
if ! command -v icx &>/dev/null; then
error "❌ICX/IPX ONEAPI INTEL XAIGPUARC BAUUNTERMODUL INSTALLATION FEHLGESCHLAGEN"
exit 1
fi
log "🔷VERBINDUNG ONEAPI GELADEN DPCPP_ROOT=${DPCPP_ROOT} UND MKL_ROOT=${MKL_ROOT}"
}

#1PROJEKTVORBAU
setup_project() {
log "🔷BAUE VORBAU XAIGPUARC BITTE WARTEN"
if [ ! -d "${LLAMA_CPP_DIR}" ]; then
log "🔷KLONE GRUNDLAGEN VON LLAMACPP"
git clone https://github.com/ggerganov/llama.cpp "${LLAMA_CPP_DIR}"
if [ $? -ne 0 ]; then
error "❌KLONEN VON LAMACPP FEHLGESCHLAGEN ABBRUCH"
exit 1
fi
fi
if pushd "${LLAMA_CPP_DIR}" > /dev/null; then
log "🔷AKTUALISIERE UNTERMODULE"
git pull
git submodule update --init --recursive
popd > /dev/null
success "✅LLAMACPP ANTWORTET UNTERGRUPPENMODULE WERDEN GELADEN"
else
error "❌FEHLER HAUPTVERZEICHNIS'${LLAMA_CPP_DIR}'NICHT GEFUNDEN ABBRUCH"
exit 1
fi
}

#2PATCH LOGIK 6/6
patch_llama_cpp() {
log "🔷PATCH FUER GGML SYCL ANLEGEN KOPFZEILENREGESTRIERUNG"
local DPCT_HELPER_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/dpct/helper.hpp"
local CMAKE_LISTS_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/CMakeLists.txt"
local CUSTOM_KERNEL_DIR="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/custom_kernels"
local CUSTOM_KERNEL_SRC="${CUSTOM_KERNEL_DIR}/ggml_flash_attention_sycl.cpp"
local CUSTOM_KERNEL_CMAKE="${CUSTOM_KERNEL_DIR}/CMakeLists.txt"
local GGML_SYCL_CPP="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/ggml-sycl.cpp"
local KERNEL_SOURCE_LOCAL="ggml_flash_attention_sycl.cpp"

#1/6
if [ -f "$DPCT_HELPER_FILE" ]; then
log "🔷PATCH 1/6 DOCTPHELPER FEHLGESCHLAGEN ABHAENGIGKEITSLISTE PRUEFEN"
if sed -i 's|#include <sycl/ext/oneapi/math.hpp>|#include <sycl/ext/intel/math.hpp>|g' "$DPCT_HELPER_FILE"; then
log "🔷PATCH 1/6 ERFOLGREICH"
elif sed -i 's|#if !defined(DPCT_USM_LEVEL_NONE) && defined(DPCT_ENABLE_MKL_MATH).#endif|#include <sycl/ext/intel/math.hpp>|g' "$DPCT_HELPER_FILE"; then
log "🔷PATCH 1/6 ERFOLGREICH SPEICHERE IN AUSGABE"
else
error "❌PATCH 1/6 HELPER INSTALLIEREN IST FEHLGESCHLAGEN"
return 1
fi
else
error "❌PATCH 1/6 FEHLGESCHLAGEN NICHT GEFUNDEN ABHAENIGKEITEN PRUEFEN"
return 1
fi

#2/6
log "🔷PATCH 2/6 BAUE ggml_flash_attention_sycl KERN"

#2a/6
if [ ! -d "$CUSTOM_KERNEL_DIR" ]; then
mkdir -p "$CUSTOM_KERNEL_DIR"
log "🔷ORNDER '${CUSTOM_KERNEL_DIR}'ANGELEGT"
fi
if [ -f "$KERNEL_SOURCE_LOCAL" ]; then
cp "$KERNEL_SOURCE_LOCAL" "$CUSTOM_KERNEL_SRC"
log "🔷PATCH 2/6 ggml_flash_attention_sycl.cpp KERNEL './${KERNEL_SOURCE_LOCAL}' NACH '${CUSTOM_KERNEL_SRC}' KOPIERT"
fi
if [ ! -f "$CUSTOM_KERNEL_SRC" ]; then
echo "PLATZHALTER ggml_flash_attention_sycl.cpp KERNELVERZEICHNIS" > "$CUSTOM_KERNEL_SRC"
warn "⚠️PATCH 2/6 LADEN DER KERNELDATEI '${KERNEL_SOURCE_LOCAL} FEHLGESCHLAGEN"
fi
echo "
add_library(ggml_flash_attention_sycl OBJECT
    ggml_flash_attention_sycl.cpp
)
target_include_directories(ggml_flash_attention_sycl PRIVATE \${GGML_SYCL_INCLUDE_DIRS})
target_compile_options(ggml_flash_attention_sycl PUBLIC \${GGML_SYCL_COMPILE_FLAGS})
" > "$CUSTOM_KERNEL_CMAKE"
log "🔷PATCH 2a/6 CMAKE LISTEN FUER OBJEKTE ALS KERN EINGEFUEGT"

#2b/6
local ADD_SUBDIR_LINE="add_subdirectory(ggml_flash_attention_sycl)"
if ! grep -Fq "${ADD_SUBDIR_LINE}" "$CMAKE_LISTS_FILE"; then
if sed -i "/add_subdirectory(dpct)/a ${ADD_SUBDIR_LINE}" "$CMAKE_LISTS_FILE"; then
log "🔷PATCH 2b/6 ERFOLGREICH ggml_flash_attention_sycl ZU KOPFZEILEN AN CMAKE GESCHRIEBEN"
else
error "❌PATCH 2b/6 ggml_flash_attention_sycl EINGLIEDERUNG DER KOPFZEILEN AN CMAKE FEHLGESCHLAGEN"
return 1
fi
else
log "🔷PATCH 2b/6 ggml_flash_attention_sycl BEREITS AKTIV UEBERSPRINGE"
fi

#3/6
if [ -f "$CMAKE_LISTS_FILE" ]; then
log "🔷PATCH 3/6: CMAKE LISTEN FUER KOPZEILEN ZUR ICPX IMPLEMENTIERUNG VORBEREITEN"
local MKL_INCLUDE_PATH="${MKL_ROOT}/include"
local COMPILER_INCLUDE_PATH="${DPCPP_ROOT}/include"
local DPCPP_LIB_INCLUDE_PATH="${DPCPP_ROOT}/lib/dpcpp/include"
local ALL_INCLUDE_FLAGS="-I${MKL_INCLUDE_PATH} -I${COMPILER_INCLUDE_PATH} -I${DPCPP_LIB_INCLUDE_PATH}"
local PATCH_LINE="target_compile_options(ggml-sycl PUBLIC "${ALL_INCLUDE_FLAGS}")"
local SEARCH_MARKER="#Add include directories for MKL headers"
if ! grep -Fq "${COMPILER_INCLUDE_PATH}" "$CMAKE_LISTS_FILE"; then
local SED_PATCH_LINE=$(echo "$PATCH_LINE" | sed 's/ /\ /g; s/[/&]/\&/g')
if sed -i "/${SEARCH_MARKER}/a $SED_PATCH_LINE" "$CMAKE_LISTS_FILE"; then
log "🔷PATCH 3/6 ERFOLGREICH ALLE ICPX KOPFZEILEN EINGEFUEGT"
else
error "❌PATCH 3/6 ICPX CMAKE LISTSTXT NICHT GEFUNDEN ABHAENGIKEITEN PRUEFEN"
return 1
fi
else
log "🔷PATCH 3a/6 CMAKE LISTSTXT PFAD FUER SYCL GGML BEREITS BENUTZT UEBERSPRINGE"
fi
else
error "❌PATCH 3a/6 FEHLGESCHLAGEN CMAKE LISTSTXT FUER SYCL GGML PFADE NICHT GEFUNDEN BITTE ABHAENGIGKEITEN PRUEFEN"
return 1
fi

#4/6
log "🔷PATCH 4/6 KERN ggml_flash_attention_sycl.cpp INJIZIEREN"
if [ -f "$GGML_SYCL_CPP" ]; then

#4a/6
local FA_REGISTER_CODE=$'//REGESTRIERE ggml_flash_attention_sycl.cpp \nextern "C"
void ggml_flash_attention_sycl(ggml_flash_attention_sycl * ctx, ggml_tensor *
dst, const ggml_tensor * Q, const ggml_tensor * K, const ggml_tensor * V);\n'
if ! grep -Fq "ggml_flash_attention_sycl" "${GGML_SYCL_CPP}"; then
echo "${FA_REGISTER_CODE}" > /tmp/fa_decl.patch
awk '/extern "C" void ggml_flash_attention_sycl/ { system("cat /tmp/fa_decl.patch"); } { print }' "${GGML_SYCL_CPP}" > /tmp/ggml-sycl.cpp.new
mv /tmp/ggml-sycl.cpp.new "${GGML_SYCL_CPP}"
if [ $? -eq 0 ]; then
log "🔷PATCH 4a/6 DEKLARATION ERFOLGREICH EINGEFUEGT"
else
error "❌PATCH 4a/6 FEHLER BEIM EINFUEGEN DER ggml_flash_attention_sycl.cpp DEKLARATION AWK FEHLER"
return 1
fi
else
log "🔷PATCH 4a/6 DEKLARATIONEN VORHANDEN FORTFAHREN"
fi
local FA_DISPATCH_CASE=$' case GGML_OP_FLASH_ATTN:\n ggml_flash_attention_sycl(ctx, dst, src0, src1, src2);\n break;'
if ! grep -Fq "case GGML_OP_FLASH_ATTN:" "${GGML_SYCL_CPP}"; then
log "🔷PATCH 4a/6 FUEGE DEN ZWISCHENSPEICHER PER AWK KOPFZEILE EIN"
echo "${FA_DISPATCH_CASE}" > /tmp/fa_dispatch.patch
awk '/case GGML_OP_MUL_MAT_Q_K:/ { system("cat /tmp/fa_dispatch.patch"); } { print }' "${GGML_SYCL_CPP}" > /tmp/ggml-sycl.cpp.new
mv /tmp/ggml-sycl.cpp.new "${GGML_SYCL_CPP}"
if [ $? -eq 0 ]; then
log "🔷PATCH 4a/6 AKW UNTERBAU EINGEFUEHRT"
else
error "❌PATCH 4a/6 FEHLER BEIM EINFUEGEN AKW KOPFZEILEN"
fi
else
log "🔷PATCH 4a/6 AKW UNTERBAU VORHANDEN FORTFAHREN"
fi
log "🔷PATCH 4b/6 ERFOLGREICH FLASHATTENTION GELADEN"
else
error "❌PATCH 4b/6 FEHLGESCHLAGEN FLASHATTENTION KERN NICHT GEFUNDEN"
return 1
fi

#5/6
log "🔷PATCH 5/6 INJIZIEREN OBJEKT VARIABLEN AUS UNTERBLOCK VON SYCL BIBLIOTHEKEN"
local CMAKE_LISTS_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/CMakeLists.txt"

#5a/6
local VAR_LINE="set(FA_OBJECT_FILES \"\$<TARGET_OBJECTS:ggml_flash_attention_sycl>\")"
local VAR_SEARCH_MARKER="set(GGML_SYCL_SOURCES"
if ! grep -Fq "FA_OBJECT_FILES" "$CMAKE_LISTS_FILE"; then
local SED_VAR_LINE=$(echo "$VAR_LINE" | sed 's/[\/&]/\\&/g')
if sed -i "/${VAR_SEARCH_MARKER}/a ${SED_VAR_LINE}" "$CMAKE_LISTS_FILE"; then
log "🔷PATCH 5a/6 OBJEKT VARIABLEN ERFOLGREICH DEFINIERT WEITER"
else
error "❌PATCH 5a/6 OBJEKT VARIABLEN BAU FEHLGESCHLAGEN STOPP"
return 1
fi
else
log "🔷PATCH 5a/6 OBJEKT VARIABLEN VORHANDEN UEBERSPRINGE"
fi

#5b/6
local TARGET_SEARCH_MARKER="target_sources(ggml-sycl PRIVATE \${GGML_SYCL_SOURCES})"
local NEW_TARGET_SOURCES_LINE="target_sources(ggml-sycl PRIVATE \${GGML_SYCL_SOURCES} \${FA_OBJECT_FILES})"
if grep -Fq "${TARGET_SEARCH_MARKER}" "$CMAKE_LISTS_FILE" && ! grep -Fq "\${FA_OBJECT_FILES}" "$CMAKE_LISTS_FILE"; then
local SED_NEW_LINE=$(echo "$NEW_TARGET_SOURCES_LINE" | sed 's/[\/&]/\\&/g')
local SED_SEARCH_MARKER=$(echo "$TARGET_SEARCH_MARKER" | sed 's/[\/&]/\\&/g')
if sed -i "s/${SED_SEARCH_MARKER}/${SED_NEW_LINE}/" "$CMAKE_LISTS_FILE"; then
log "🔷PATCH 5b/6 ERFOLGREICHE INJEKTIONEN IN BAUVORGANG"
else
error "❌PATCH 5b/6 INJEKTION FEHLGESCHLAGEN"
return 1
fi
else
log "🔷PATCH 5b/6 IST BEREITS AKTIV INJECTION WIRD UEBERSPRUNGEN"
fi

#6/6
log "🔷PATCH 6/6: SSMCONVPP WARNUNG BEHEBEN VORZEICHENVERGLEICH"
local SSM_CONV_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/ssm_conv.cpp"
local SEARCH_LINE='GGML_ASSERT(src0->nb[1] == src0->ne[0] * static_cast<int>(sizeof(float)));'
local REPLACE_LINE='GGML_ASSERT(src0->nb[1] == (size_t)(src0->ne[0] * sizeof(float)));'
if grep -Fq "${SEARCH_LINE}" "$SSM_CONV_FILE"; then
if sed -i "s/${SEARCH_LINE}/${REPLACE_LINE}/g" "$SSM_CONV_FILE"; then
log "🔷PATCH 6/6 SSMCONVCPP ERFOLGREICH"
else
error "❌PATCH 6/6 SSMCONVCPP FEHLGESCHLAGEN"
return 1
fi
else
log "🔷PATCH 6/6 SSMCONVCPP ZEILE NICHT GEFUNDEN UEBERSPRINGE"
fi
success "✅ALLE EINGLIEDERUNGEN FUER DAS INTEL ARC GPU BASIERTE XAIGPUARC SPRACHMODELL ERFOLGREICH ANGEWAND"
}

#3XAIGPUARCBAUKONFIGURATION
configure_build() {
log "🔷BEREITE XAIGPUARC KOPFZEILENBAUVORGANG VOR"
local FP_MODE="${1:-1}"
local FP_FLAG="-DGGML_SYCL_F16=${FP_MODE}"
if [ ! -d "${BUILD_DIR}" ]; then
log "🔷LEGE XAIGPUARC ORDNER IM HOME VERZEICHNIS IHRES COMPUTERS AN ${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" || { err "❌FEHLER KONNTE DEN ORDNER XAIGPUARC '${BUILD_DIR}' NICHT ANLEGEN"; return 1; }
fi
if pushd "${BUILD_DIR}" > /dev/null; then
log "🔷STARTE CMAKE BAU VON XAIGPUARC ${FP_FLAG})..."
cmake "../${LLAMA_CPP_DIR}" \
    -G "Unix Makefiles" \
    -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" \
    -DGGML_SYCL=ON \
    -DGGML_SYCL_CCACHE=ON \
    -DGGML_SYCL_F16=${FP_MODE} \
    -DGGML_SYCL_FLASH_ATTN=ON \
    -DGGML_SYCL_MKL_SYCL_BATCH_GEMM=1 \
    -DCMAKE_C_COMPILER=icx \
    -DCMAKE_CXX_COMPILER=icpx \
    -DCMAKE_CXX_STANDARD=17
local CMAKE_STATUS=$?
popd > /dev/null
if [ ${CMAKE_STATUS} -ne 0 ]; then
error "❌CMAKE FEHLGESCHLAGEN"
return 1
fi
success "✅BAU ABGESCHLOSSEN XAIGPUARC BEREIT"
else
error "❌KONNTE NICHT IN XAIGPUARC WECHSELN '${BUILD_DIR}'COMPUTER NUTZER BERECHTIGUNG PRUEFEN"
return 1
fi
}

#4KOMPILIEREN
compile_project() {
log "🔷BAUE XAIGPUARC GRUNDGERUEST-STRUKTUR"
local LOG_FILE="build.log"
log "🔷KOPFZEILEN AUSGABE IN UNTERORNDER GESPEICHERT"
log "🔷BAUVORGANG LAEUFT XAIGPUARC KOPFZEILEN ERFOLGREICH ABGESCHLOSSEN"
if pushd "${BUILD_DIR}" > /dev/null; then
log "🔷INSTALLATION VON XAIGPUARC KOMPLETTSYSTEM AUF LOKALEM COMPUTER
IM HOME VERZEICHNIS MOEGLICH
KOMPLETTBAU VON SYCL XAIGPUARC
ZERO NULL 0 WIRD JETZT FERTIGGESTELLT
DIE INSTALLATION KANN
JE NACH LEISTUNG IHRES SYSTEMS
EIN PAAR MINUTEN ANDAUERN
---
BITTE HABEN SIE ETWAS GEDULD
DANKE FUR DIE NUTZUNG VON XAIGPUARC
SIE HABEN DEN GROSSTEIL GLEICH GESCHAFFT
DIE KI INFERENZ BEGINNT IN KUERZE
NACH DIESEM VORGANG IST EINE ZWEITE INFERENZ WESENTLICH SCHNELLER
VERSUCHEN SIE UNTERSCHIEDLICHE STARTVORGAENGE MIT EIGENEN PROMTS UND MODELLEN"
cmake --build . --config "${CMAKE_BUILD_TYPE}" -j ${NPROC} --target llama-cli llama-ls-sycl-device > "${LOG_FILE}" 2>&1
local BUILD_STATUS=$?
popd > /dev/null
if [ ${BUILD_STATUS} -ne 0 ]; then
error "❌BAU VON XAIGPUARC KOPF FEHLGESCHLAGEN UEBERPRUEFEN SIE DIE NIEDERSCHRIFT**${BUILD_DIR}/${LOG_FILE}**"
return 1
fi
success "✅BAU VON XAIGPUARC ERFOLGREICH"
else
error "❌KONNTE XAIGPUARC NICHT NEU BAUEN '${BUILD_DIR}' WEGEN FEHLERHAFTEM WECHSEL BAU NICHT MOEGLICH"
return 1
fi
}

#5AUTOMATISCHEGERAETEAUSWAHL
auto_select_device() {
log "🔷NACH VERFUEGBAREN SYCL GERAETEN AUF IHREM SYSTEM"
local FULL_LS_PATH="./${BUILD_DIR}/${LS_SYCL_DEVICE_PATH}"
if [ ! -x "${FULL_LS_PATH}" ]; then
warn "⚠️LLAMA UNTERBAU NICHT GEFUNDEN ${FULL_LS_PATH}RUECKFALL AUF ARC dGPU"
export ONEAPI_DEVICE_SELECTOR="level_zero ERFOLGREICH"
DEVICE="ARC"
return
fi
local DEVICES
DEVICES=$(bash -c "${FULL_LS_PATH}")
if [ -z "$DEVICES" ]; then
warn "⚠️KEINE KOMPATIBLEN SYCL GERAETE GEFUNDEN ERRORAKTUELLE ABHAENGIGKEITEN PRUEFEN"
export ONEAPI_DEVICE_SELECTOR="level_zero:0->❌ANBINDUNG FEHLGESCHLAGEN"
DEVICE="ARC"
N_GPU_LAYERS=99
return
fi
local ARC_ID
ARC_ID=$(echo "$DEVICES" | grep -i "Intel Arc" | head -n1 | awk '{print $1}')
local IGPU_ID
IGPU_ID=$(echo "$DEVICES" | grep -Ei "Iris|Xe|Graphics" | head -n1 | awk '{print $1}')
local TARGET_LINE=""
if [ -n "$ARC_ID" ]; then
TARGET_LINE=$(echo "$DEVICES" | grep -i "Intel Arc" | head -n1)
DEVICE="ARC"
elif [ -n "$IGPU_ID" ]; then
TARGET_LINE=$(echo "$DEVICES" | grep -Ei "Iris|Xe|Graphics" | head -n1)
DEVICE="iGPU"
else
export ONEAPI_DEVICE_SELECTOR="opencl:cpu"
DEVICE="CPU"
N_GPU_LAYERS=99
error "❌KEINE GEEIGNETE GRAFIKKARTE GEFUNDEN FALLE AUF CPU ZURUECK"
return
fi
if [ -n "$TARGET_LINE" ]; then
local TARGET_ID=$(echo "$TARGET_LINE" | awk '{print $1}')
export ONEAPI_DEVICE_SELECTOR="level_zero:${TARGET_ID}"
log "🔷NUTZE INTEL GRAFIKKARTE ${DEVICE} (Device ${TARGET_ID})"
local VRAM_GIB_RAW=$(echo "$TARGET_LINE" | grep -oP '\d+(?=M)' | head -n1)
VRAM_GIB=$((VRAM_GIB_RAW / 1024)) #MIB-zu-GIB-
if [ -z "${VRAM_GIB_RAW}" ]; then
VRAM_GIB_RAW=1024
fi
local LAYER_SIZE_MIB=256 #Magic Key
local VRAM_MIB_CALC=$((VRAM_GIB * 1024))
if [ "${VRAM_GIB}" -lt 1 ]; then
VRAM_GIB=1
fi
N_GPU_LAYERS=$((VRAM_MIB_CALC * 99 / 100 / LAYER_SIZE_MIB))
if [ "$N_GPU_LAYERS" -gt 99 ]; then
N_GPU_LAYERS=99
fi
if [ "$N_GPU_LAYERS" -lt 1 ]; then
N_GPU_LAYERS=1
fi
log "🔷AUTOMATISCHE NGL BERECHNUNG IN **${N_GPU_LAYERS}**SCHICHTEN JE NACH MODELL AUF CPU UND GPU AUTOMATISCH VERTEILT"
fi
}

#6SYCLKOMPATIBLEGERAETEPRUEFEN
list_sycl_devices() {
log "🔷SUCHE SYCL FAEHIGES GERAET AUF IHREM SYSTEM"
local FULL_LS_PATH="./${BUILD_DIR}/${LS_SYCL_DEVICE_PATH}"
if [ -f "${FULL_LS_PATH}" ]; then
"${FULL_LS_PATH}"
else
warn "⚠️KEIN SYCL FAEHIGES SYSTEM GEFUNDEN!!! ${FULL_LS_PATH}.
KONNTE KEIN FAEHIGES GERAET FINDEN"
fi
}

#7MODELLPFADWAEHLEN
prepare_model() {
MODEL_PATH=${1:-"models/gpt-oss-20B-F16.gguf"}
mkdir -p models
if [ ! -f "$MODEL_PATH" ]; then
warn "⚠️IHR KI MODELL KONNTE NICHT UNTER HOME/IHRNAME/MODELS GEFUNDEN WERDEN. BITTE DORTHIN KOPIEREN **$MODEL_PATH**"
fi
export MODEL_PATH
}

#8MODELLAUSFUEHREN
run_inference() {
local DEFAULT_MODEL_PATH="models/gpt-oss-20B-F16.gguf"

#Change Modells above twice like List Support with FP16 Only.
#Small Qwen2.5-7B-Instruct-f16-q4_k
#gpt-oss-20b-F16 runs on iGPU XE-LPG 16GB
#ON A770LE above max and best is MathTutor-7B-H_v0.0.1.f16
local MODEL_PATH_ARG=${2:-$DEFAULT_MODEL_PATH}
local PROMPT_ARG=${3:-"Let us build a Blake2b Zhash_144_5 Kernel for Blockchain and Network on Open Source Basic written full in C++ and
its newer Versions optimized for Vector based Calculations like that example but full running code now like nothing comes more tomorrow
#define INPUT_SIZE 512
#define HASH_SIZE 32
#define WORK_ITEMS 131072
#define BUCKET_COUNT 32
__constant uint IV[8] =
0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
inline uint rotr32(uint x, uint n)
return (x >> n) | (x << (32 - n));
Eine Hashrunde mit veraenderbarem Startwert
inline void hash_core(uint m, uint round_offset, __global uchar* hash_out, int offset)
uint a = IV[0] ^ m;
uint b = IV[1] ^ (m << 1);
uint c = IV[2] ^ (m >> 1);
uint d = IV[3] ^ (~m);
for (int i = 0; i < 91; ++i)
a += b ^ (m ^ (i + round_offset)); a = rotr32(a, 16);
b += c ^ a; b = rotr32(b, 12);
c += d ^ b; c = rotr32(c, 8);
d += a ^ c; d = rotr32(d, 7);
hash_out[offset +  0] = a & 0xFF;
hash_out[offset +  1] = (a >> 8) & 0xFF;
hash_out[offset +  2] = (a >> 16) & 0xFF;
hash_out[offset +  3] = (a >> 24) & 0xFF;
hash_out[offset +  4] = b & 0xFF;
hash_out[offset +  5] = (b >> 8) & 0xFF;
hash_out[offset +  6] = (b >> 16) & 0xFF;
hash_out[offset +  7] = (b >> 24) & 0xFF;
hash_out[offset +  8] = c & 0xFF;
hash_out[offset +  9] = (c >> 8) & 0xFF;
hash_out[offset + 10] = (c >> 16) & 0xFF;
hash_out[offset + 11] = (c >> 24) & 0xFF;
hash_out[offset + 12] = d & 0xFF;
hash_out[offset + 13] = (d >> 8) & 0xFF;
hash_out[offset + 14] = (d >> 16) & 0xFF;
hash_out[offset + 15] = (d >> 24) & 0xFF;
Hauptfunktion: erzeugt zwei 16-Byte-Runden fuer zusammen 32 Byte
inline void hash_rounds(__global const uchar* input, uint gid, __global uchar* hash_out)
uint m = 0;
for (int i = 0; i < 4; ++i)
m |= ((uint)input[gid * INPUT_SIZE + i]) << (i * 8);
Erste Haelfte: direkt aus m
hash_core(m, 0, hash_out, gid * HASH_SIZE);
Zweite Haelfte: aus m XOR 0xa5a5a5a5 (Variation)
hash_core(m ^ 0xa5a5a5a5, 91, hash_out, gid * HASH_SIZE + 16);
Kernel
__kernel void zhash_144_5(
__global const uchar* input,
__global uchar* output,
__global uint* solution_indexes
int gid = get_global_id(0);
hash_rounds(input, gid, output);
__global uchar* my_hash = &output[gid * HASH_SIZE];
uint bucket = my_hash[0] >> 3;
for (int i = 0; i < gid; ++i)
__global uchar* other = &output[i * HASH_SIZE];
uint other_bucket = other[0] >> 3;
if (bucket == other_bucket)
solution_indexes[gid * 2] = i;
solution_indexes[gid * 2 + 1] = gid;
break STOP build that code up and better with all the rules"}
local GPU_ID=$(echo "$ONEAPI_DEVICE_SELECTOR" | awk -F':' '{print $2}')
local NGL_SET=${N_GPU_LAYERS:-99}
local FULL_LLAMA_CLI_PATH="./${BUILD_DIR}/${LLAMA_CLI_PATH}"
local CONTEXT_SIZE=8192 #NEUEN WERTE SETZEN 2048 4096 8192 16384
local PREDICT_TOKENS=8192
log "🔷STARTE KI ANTWORT AUF IHRER iGPU/dGPU UND CPU MIT FOLGENDEN PARAMETERN**${DEVICE} (ID: ${GPU_ID})** MIT NGL WERT IST GLEICH ${NGL_SET} AUF DIESEM **${FULL_LLAMA_CLI_PATH}**"
if [ ! -x "${FULL_LLAMA_CLI_PATH}" ]; then
error "❌FEHLER AKTUELLER LLAMA UNTERBAU NICHT GEFUNDEN NEUBAU FEHLGESCHLAGEN${FULL_LLAMA_CLI_PATH}"
return 1
fi
ZES_ENABLE_SYSMAN=1 "${FULL_LLAMA_CLI_PATH}" \
    -no-cnv \
    -m "${MODEL_PATH_ARG}" \
    -p "${PROMPT_ARG}" \
    -n ${PREDICT_TOKENS} \
    -c ${CONTEXT_SIZE} \
    -ngl ${N_GPU_LAYERS} \
    --split-mode none \
    --main-gpu ${GPU_ID}
echo "KI ANTWORT FERTIG GLUECKWUNSCH"
}

#DEFINITIONHAUPTFUNKTION
main() {

local FP_MODE="${1:-1}"
local RERUN_BUILD=1

prepare_environment
#0
local FULL_LLAMA_CLI_PATH="./${BUILD_DIR}/${LLAMA_CLI_PATH}"
local FULL_LS_PATH="./${BUILD_DIR}/${LS_SYCL_DEVICE_PATH}"

if [[ -f "${FULL_LLAMA_CLI_PATH}" ]] && [[ -f "${FULL_LS_PATH}" ]]; then

success "✅GEFUNDENE AKTUELLE XAIGPUARC VERSION NEUBAU UNNOETIG FORTFAHREN**${FULL_LLAMA_CLI_PATH}** UND **${FULL_LS_PATH}** LADEN"

log "🔷UEBERSPRINGE BAUVORGANG"

RERUN_BUILD=0
else
warn "⚠️KEINE AKTUELLES XAIGPUARC GEFUNDEN GEBAUT BITTE WARTEN"
RERUN_BUILD=1

fi
if [[ "$RERUN_BUILD" -eq 1 ]]; then

log "🔷STARTE ERSTMALIGEN BAUVORGANG VON XAIGPUARC"
if check_internet; then

log "🔷LADE JETZT AKTUELLE LLAMA VERSION BITTE WARTEN"

setup_project
#1
patch_llama_cpp
#2
else
warn "⚠️INTERNET NICHT VERFUEGBAR UEBERSPRINGE UPDATE VON LLAMACPP NUTZE LOKALE VERSION"
fi
fi

configure_build "${FP_MODE}"
#3
compile_project
#4
auto_select_device
#5
list_sycl_devices
#6
prepare_model "${2:-}"
#7
run_inference "${2:-}" "${3:-}"
#8
log "🔷XAIGPUARC ANTWORT ABGESCHLOSSEN**${BUILD_DIR}/${LLAMA_CLI_PATH}**"
}

#HAUPTSCHLEIFE
main "${1:-1}" "${2:-}" "${3:-}"
#42
log "🔷KOMPLETTBAUVORGANG WIRD HIER GESPEICHERT**${LOG_FILE}**"
