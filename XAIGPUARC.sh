#!/bin/bash

#1.) Kopie XAIGPUARC.sh in your HOME FOLDER
#2.) Download a gguf AI fit in your
#a.) V/Ram to /models/ also in your Home Folder!
#3.) Open Console and Type: chmod +x ./XAIGPUARC.sh
#4.) START with type again in new Console ./XAIGPUARC.sh press Enter 

#Tested on mulitble Devices with
#16GB 12GB 11.5GB 8GB 6GB
#XE/ARC/Alchemist/Battlemage/iGPU/dGPU/Dual+GPU Systems
#Qwen2.5-VL-3B-Instruct-f16-q4_k.gguf 2.1GB
#Qwen2.5-VL-3B-Instruct-f16.gguf 5.8GB
#Qwen2.5-7B-Instruct-f16-q4_k.gguf 5.7GB
#Qwen3-Embedding-4B-f16.gguf 7.5GB
#Qwen3-4B-f16.gguf 7.5GB
#DiffuCoder-7B-cpGRPO-f16_q8_0.gguf 10.5GB
#gemma-3n-E4B-it-F16.gguf 12.8GB
#ggml-model-f16.gguf 12.6GB
#gpt-oss-20b-F16.gguf 12.8GB
#Mistral-7B-Instruct-v0.3.fp16.gguf 13.5GB
#Nemotron-Mini-4B-Instruct-f16.gguf 7.8GB
#Minitron-4B-Base.FP16-.gguf 7.8GB
#Nemotron-Orchestrator-8B-f16_q8_0.gguf 11.4GB
#NVIDIA-Nemotron-Nano-12B-v2-F16.gguf 22.9GB
#llama3bthinkingonly5B.f16.gguf 6.0GB
#MAXIMAL 16GB A770LE MODELL
#MathTutor-7B-H_v0.0.1.f16.gguf 14.2GB
#NOT F16 MODE But maybe nice too Test for You
#Qwen3-16B-A3B-IQ4_NL.gguf 8.5GB
#Qwen3-30B-A3B-UD-IQ2_XXS.gguf 9.7GB
#gpt-oss-20b-claude-4-distill.MXFP4_MOE.gguf 11.3GB
#gpt-oss-20b-mxfp4.gguf 11.3GB
#NVIDIA-Nemotron-Nano-12B-v2-IQ4_NL.gguf 6.6GB
#Testmodell BF16 against F16 VERSION ABOVE NOT RECOMMEND!
#Minitron-4B-Base.BF16.gguf 7.8GB 

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

#ONEAPISYCLFUNKTIONEN
export TCM_ROOT="${TCM_ROOT:-/opt/intel/oneapi/tcm/latest}"
export SYCL_CACHE_PERSISTENT=1
export OCL_ICD_FILENAMES=""
export ZES_ENABLE_SYSMAN=1
export OverrideDefaultFP64Settings=1
export CCACHE_DIR="$HOME/.ccache"
export COMPILER_VERSION="2025.0"
export SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1
export SYCL_PI_LEVEL_ZERO_BATCH_SIZE=100

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
warn "⚠️KEINE INTERNETVERBINDUNG GEFUNDEN"
return 1
fi
}

#XAIUMGEBUNGUNDRUCKFALLMECHANISMENVORBEREITEN
prepare_environment() {
log "🔷HOLE ONE API KOEPFE FUER XAIGPUARC BCXAI ALUCIANŚ EDITION"
local SETVARS_PATH="/opt/intel/oneapi/setvars.sh"
if [ ! -f "$SETVARS_PATH" ]; then
error "❌ONEAPI KOEPFE NICHT GEFUNDEN $SETVARS_PATH INSTALLIERE ZU ERST ONE API BIBLIOTHEKEN"
exit 1
fi
log "SETVARS.SH SETZEN UND SUCHEN"
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

#PROJEKTVORBAU
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
#PATCH6/6
patch_llama_cpp() {
log "🔷PATCH FUER GGML SYCL ANLEGEN KOPFZEILENREGESTRIERUNG"
local DPCT_HELPER_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/dpct/helper.hpp"
local CMAKE_LISTS_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/CMakeLists.txt"
local CUSTOM_KERNEL_DIR="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/custom_kernels"
local CUSTOM_KERNEL_SRC="${CUSTOM_KERNEL_DIR}/ggml_flash_attention_sycl.cpp"
local CUSTOM_KERNEL_CMAKE="${CUSTOM_KERNEL_DIR}/CMakeLists.txt"
local GGML_SYCL_CPP="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/ggml-sycl.cpp"
local KERNEL_SOURCE_LOCAL="ggml_flash_attention_sycl.cpp"
#PATCH1/6
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
#PATCH2/6
log "🔷PATCH 2/6 BAUE ggml_flash_attention_sycl KERN"
#2a
if [ ! -d "$CUSTOM_KERNEL_DIR" ]; then
mkdir -p "$CUSTOM_KERNEL_DIR"
log "🔷ORNDER '${CUSTOM_KERNEL_DIR}'ANGELEGT"
fi
if [ -f "$KERNEL_SOURCE_LOCAL" ]; then
cp "$KERNEL_SOURCE_LOCAL" "$CUSTOM_KERNEL_SRC"
log "🔷ggml_flash_attention_sycl.cpp KERNEL './${KERNEL_SOURCE_LOCAL}' NACH '${CUSTOM_KERNEL_SRC}' KOPIERT"
fi
if [ ! -f "$CUSTOM_KERNEL_SRC" ]; then
echo "//PLATZHALTER FUER ggml_flash_attention_sycl.cpp KERNELHOME" > "$CUSTOM_KERNEL_SRC"
warn "⚠️KERNELDATEI '${KERNEL_SOURCE_LOCAL}"
fi
echo "
add_library(ggml_flash_attention_sycl OBJECT
    ggml_flash_attention_sycl.cpp
)
target_include_directories(ggml_flash_attention_sycl PRIVATE \${GGML_SYCL_INCLUDE_DIRS})
target_compile_options(ggml_flash_attention_sycl PUBLIC \${GGML_SYCL_COMPILE_FLAGS})
" > "$CUSTOM_KERNEL_CMAKE"
log "🔷CMAKE LISTEN FÜR OBJEKTE ALS KERN EINGEFUEGT"
#2b/6-b
local ADD_SUBDIR_LINE="add_subdirectory(ggml_flash_attention_sycl)"
if ! grep -Fq "${ADD_SUBDIR_LINE}" "$CMAKE_LISTS_FILE"; then
if sed -i "/add_subdirectory(dpct)/a ${ADD_SUBDIR_LINE}" "$CMAKE_LISTS_FILE"; then
log "🔷PATCH 2/6 ERFOLGREICH ggml_flash_attention_sycl ZU KOPFZEILEN AN CMAKE GESCHRIEBEN"
else
error "❌PATCH 2/6 ggml_flash_attention_sycl EINGLIEDERUNG FEHLGESCHLAGEN"
return 1
fi
else
log "🔷PATCH 2/6 ggml_flash_attention_sycl BEREITS AKTIV UEBERSPRINGE"
fi
#PATCH3/6a
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
log "🔷PATCH 3/6 ERFOLGREICH ALLE KOPFZEILEN EINGEFUEGT"
else
error "❌PATCH 3/6 CMAKE LISTSTXT NICHT GEFUNDEN ABHAENGIKEITEN PRUEFEN"
return 1
fi
else
log "🔷PATCH 3/6 PFAD BEREITS BENUTZT UEBERSPRINGE"
fi
else
error "❌PATCH 3/6 FEHLGESCHLAGEN CMAKE LISTS FÜR SYCL GGML PFADE NICHT GEFUNDEN ABHAENGIGKEITEN PRUEFEN"
return 1
fi
#PATCH4/6a
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
log "🔷PATCH 4/6 DEKLARATION ERFOLGREICH EINGEFUEGT"
else
error "❌PATCH 4/6 FEHLER BEIM EINFUEGEN DER ggml_flash_attention_sycl.cpp DEKLARATION AWK FEHLER"
return 1
fi
else
log "🔷PATCH 4/6 DEKLARATIONEN VORHANDEN FORTFAHREN"
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
#PATCH5/6a
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
#PATCH6/6
log "🔷PATCH 6/6: ssm_conv.cpp WARNUNG BEHEBEN VORZEICHENVERGLEICH"
local SSM_CONV_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/ssm_conv.cpp"
local SEARCH_LINE='GGML_ASSERT(src0->nb[1] == src0->ne[0] * static_cast(sizeof(float)));'
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

#XAIGPUARCBAUKONFIGURATION
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
#KOMPILIEREN
compile_project() {
log "🔷BAUE XAIGPUARC GRUNDGERUESTSTRUKTUR"
local LOG_FILE="build.log"
log "🔷KOPFZEILENAUSGABE IN UNTERORNDER GESPEICHERT"
log "🔷BAU XAIGPUARC KOPFZEILEN ERFOLGREICH ABGESCHLOSSEN"
if pushd "${BUILD_DIR}" > /dev/null; then
log "🔷INSTALLATION VON XAIGPUARC KOMPLETTSYSTEM AUF LOKALEM COMPUTER IM HOME VERZEICHNIS MOEGLICH
KOMPLETTBAU VON SYCL XAIGPUARC
ZERO NULL 0 WIRD JETZT FERTIGGESTELLT
DIE INSTALLATION KANN JE NACH LEISTUNG IHRES SYSTEMS
EIN PAAR MINUTEN ANDAUERN
BITTE HABEN SIE ETWAS GEDULD
DANKE FUR DIE NUTZUNG VON XAIGPUARC"
cmake --build . --config "${CMAKE_BUILD_TYPE}" -j ${NPROC} --target llama-cli llama-ls-sycl-device > "${LOG_FILE}" 2>&1
local BUILD_STATUS=$?
popd > /dev/null
if [ ${BUILD_STATUS} -ne 0 ]; then
error "❌BAU VON XAIGPUARC KOPF FEHLGESCHLAGEN ÜBERPRÜFEN SIE DAS LOG**${BUILD_DIR}/${LOG_FILE}**"
return 1
fi
success "✅BAU VON XAIGPUARC ERFOLGREICH"
else
error "❌KONNTE XAIGPUARC NICHT NEU BAUEN '${BUILD_DIR}' WEGEN FEHLERHAFTEM WECHSEL BAU NICHT MOEGLICH"
return 1
fi
}
#AUTOMATISCHEGERAETEAUSWAHL
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
local LAYER_SIZE_MIB=128
local VRAM_MIB_CALC=$((VRAM_GIB * 1024))
if [ "${VRAM_GIB}" -lt 1 ]; then
VRAM_GIB=1
fi
N_GPU_LAYERS=$((VRAM_MIB_CALC * 99 / 100 / LAYER_SIZE_MIB))
if [ "$N_GPU_LAYERS" -gt 99 ]; then
N_GPU_LAYERS=99
fi
if [ "$N_GPU_LAYERS" -lt 1 ]; then
N_GPU_LAYERS=99
fi
log "🔷AUTOMATISCHE NGL BERECHNUNG IN **${N_GPU_LAYERS}**SCHICHTEN JE NACH MODELL AUF CPU UND GPU AUTOMATISCH VERTEILT"
fi
}
#5SYCLKOMPATIBLEGERÄTEPRUEFEN
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
#6MODELLPFADWAEHLEN
prepare_model() {
MODEL_PATH=${1:-"models/gpt-oss-20b-claude-4-distill.MXFP4_MOE.gguf"}
mkdir -p models
if [ ! -f "$MODEL_PATH" ]; then
warn "⚠️IHR KI MODELL KONNTE NICHT UNTER HOME/IHRNAME/MODELS GEFUNDEN WERDEN. BITTE DORTHIN KOPIEREN **$MODEL_PATH**"
fi
export MODEL_PATH
}
#7MODELLAUSFUEHREN
run_inference() {
local DEFAULT_MODEL_PATH="models/gpt-oss-20b-claude-4-distill.MXFP4_MOE.gguf"
#Change Modells above twice like List Support with FP16 Only.
local MODEL_PATH_ARG=${2:-$DEFAULT_MODEL_PATH}
local PROMPT_ARG=${3:-"medi8tor create a simple open source design tool that lets a user build small interactive programs
and tiny games by using point desktop only written in c++"}
local GPU_ID=$(echo "$ONEAPI_DEVICE_SELECTOR" | awk -F':' '{print $2}')
local NGL_SET=${N_GPU_LAYERS:-99}
local FULL_LLAMA_CLI_PATH="./${BUILD_DIR}/${LLAMA_CLI_PATH}"
log "🔷STARTE KI ANTWORT AUF IHRER iGPU/dGPU UND CPU MIT FOLGENDEN PARAMETERN**${DEVICE} (ID: ${GPU_ID})** MIT ngl=${NGL_SET} AUF DIESEM **${FULL_LLAMA_CLI_PATH}**"
if [ ! -x "${FULL_LLAMA_CLI_PATH}" ]; then
error "❌FEHLER AKTUELLER LLAMA UNTERBAU NICHT GEFUNDEN NEUBAU FEHLGESCHLAGEN${FULL_LLAMA_CLI_PATH}"
return 1
fi
ZES_ENABLE_SYSMAN=1 "${FULL_LLAMA_CLI_PATH}" \
    -no-cnv \
    -m "${MODEL_PATH_ARG}" \
    -p "${PROMPT_ARG}" \
    -n 512 \
    -ngl -1 \
    --split-mode layer \
    --main-gpu ${GPU_ID}
echo "KI ANTWORT FERTIG GLUECKWUNSCH"
}
#00DEFINITIONHAUPTMAINFUNKTION
main() {
local FP_MODE="${1:-1}"
local RERUN_BUILD=1
prepare_environment
local FULL_LLAMA_CLI_PATH="./${BUILD_DIR}/${LLAMA_CLI_PATH}"
local FULL_LS_PATH="./${BUILD_DIR}/${LS_SYCL_DEVICE_PATH}"
if [[ -f "${FULL_LLAMA_CLI_PATH}" ]] && [[ -f "${FULL_LS_PATH}" ]]; then
success "✅GEFUNDENE AKTUELLE XAIGPUARC VERSION NEUBAU UNNOETIG FORTFAHREN**${FULL_LLAMA_CLI_PATH}** UND **${FULL_LS_PATH}**"
log "🔷UEBERSPRINGE BAUVORGANG"
RERUN_BUILD=0
else
warn "⚠️KEINE AKTUELLES XAIGPUARC GEFUNDEN GEBAUT BITTE WARTEN"
RERUN_BUILD=1
fi
if [[ "$RERUN_BUILD" -eq 1 ]]; then
log "🔷STARTE ERSTMALIGEN BAUVORGANG XAIGPUARC"
if check_internet; then
log "🔷LADE JETZT NEUESTE LLAMA VERSION BITTE WARTEN"
setup_project
patch_llama_cpp
else
warn "⚠️INTERNET NICHT VERFÜGBAR UEBERSPRINGE UPDATE VON LLAMACPP NUTZE LOKALE VERSION"
fi
fi
configure_build "${FP_MODE}"
compile_project
auto_select_device
list_sycl_devices
prepare_model "${2:-}"
run_inference "${2:-}" "${3:-}"
log "🔷XAIGPUARC ANTWORT ABGESCHLOSSEN**${BUILD_DIR}/${LLAMA_CLI_PATH}**"
}
#HAUPTSCHLEIFE
main "${1:-1}" "${2:-}" "${3:-}"
#42
log "🔷KOMPLETTBAUVORGANG WIRD HIER GESPEICHERT**${LOG_FILE}**"
