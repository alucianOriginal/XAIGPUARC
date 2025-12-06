#!/bin/bash


#🔍LOW-SPEC-GERMAN-AI-AUTOMAT
#INTEL-MKL-ICX-IQ-DynamicGate-F16C-Bit-ICX-HQ-IQ-F16-BF16
#Low-V/RAMSSDUSAGE
#Mobile iGPU+dGPU
#SYCL/F16/IQ-DG/XTC/MEMSC/ADD/APP/APU/XMX/NPU/ICX/MKL/N
#Math Tutor 7B F16 for 16GB 770LE
set -euo pipefail
IFS=$'\n\t'
PRECISION="FP16"
DEVICE="ARC"
LLAMA_CPP_DIR="llama.cpp"
BUILD_DIR="${BUILD_DIR:-XAIGPUARC}"
#XAIGPUARC
GGML_SYCL_CPP="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/ggml-sycl.cpp"
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
NPROC="${NPROC:-$(nproc)}"
LOG_FILE="${BUILD_DIR:-XAIGPUARC}/XAIGPUARC.log"
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
warning() { printf "⚠️ %s\n\n" "$*"; }
err() { error "$*"; }
warn() { printf "⚠️ %s\n" "$*"; }
#AUSGABEVORSTELLUNG
separator() {
echo -e "--🏗-XAIGPUARC-🏗-Clear-DARK-Angel-Vanilla-MATRIX-🔍AI--\n"
}
#XAIUMGEBUNGUNDRUCKFALLMECHANISMENVORBEREITEN
prepare_environment() {
log "HOLE ONE API KOEPF"
local SETVARS_PATH="/opt/intel/oneapi/setvars.sh"
if [ ! -f "$SETVARS_PATH" ]; then
err "ONEAPI NICHT GEFUNDEN: $SETVARS_PATH. INSTALLIERE ZU ERST ONE API"
exit 1
fi
log "SETVARS.SH SETZEN UND🔍"
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
err "ICX/IPX INTEL COMPILER INSTALLATION..."
exit 1
fi
log "✅ VERBINDUNG ONEAPI GELADEN... (DPCPP_ROOT=${DPCPP_ROOT} und MKL_ROOT=${MKL_ROOT})"
}
#1PROJEKT-VORBAU
setup_project() {
log "📦 BAUE-XAIGPUARC-BITTE WARTEN"
if [ ! -d "${LLAMA_CPP_DIR}" ]; then
log "📦->KLONE GRUNDLAGEN VON LLAMA.CPP"
git clone https://github.com/ggerganov/llama.cpp "${LLAMA_CPP_DIR}"
if [ $? -ne 0 ]; then
err "❌ KLONEN FEHLGESCHLAGEN ABBRUCH"
exit 1
fi
fi
if pushd "${LLAMA_CPP_DIR}" > /dev/null; then
log "🔍->AKTUALISIERE UNTERMODULE"
git pull
git submodule update --init --recursive
popd > /dev/null
success "✅ LLAMA.CPP ANTWORTET..UNTERGRUPPEN WERDEN GELADEN"
else
err "❌FEHLER HAUPTVERZEICHNIS'${LLAMA_CPP_DIR}'NICHT GEFUNDEN ABBRUCH"
exit 1
fi
}
#00PATCH6/6
patch_llama_cpp() {
log "🔷 🏗 🩹 Patches für ggml-sycl anwenden (Header & CMake & Kernel-Dispatch-Registrierung)"
local DPCT_HELPER_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/dpct/helper.hpp"
local CMAKE_LISTS_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/CMakeLists.txt"
local CUSTOM_KERNEL_DIR="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/custom_kernels"
local CUSTOM_KERNEL_SRC="${CUSTOM_KERNEL_DIR}/ggml_flash_attention_sycl.cpp"
local CUSTOM_KERNEL_CMAKE="${CUSTOM_KERNEL_DIR}/CMakeLists.txt"
local GGML_SYCL_CPP="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/ggml-sycl.cpp"
local KERNEL_SOURCE_LOCAL="ggml_flash_attention_sycl.cpp"
#PATCH1/6
if [ -f "$DPCT_HELPER_FILE" ]; then
log "🔷->PATCH 1/6: DOCTPHELPER FEHLGESCHLAGEN. ABHÄNGIGKEITSLISTE PRÜFEN"
if sed -i 's|#include <sycl/ext/oneapi/math.hpp>|#include <sycl/ext/intel/math.hpp>|g' "$DPCT_HELPER_FILE"; then
log "🔷-> ✅ PATCH 1/6 ERFOLGREICH"
elif sed -i 's|#if !defined(DPCT_USM_LEVEL_NONE) && defined(DPCT_ENABLE_MKL_MATH).#endif|#include <sycl/ext/intel/math.hpp>|g' "$DPCT_HELPER_FILE"; then
log "🔷->✅ PATCH 1/6 ERFOLGREICH (SPEICHERE IN LOG"
else
error "🔷->❌ PATCH 1/6 HELPER INSTALLIEREN (dpct/helper.hpp) IST FEHLGESCHLAGEN"
return 1
fi
else
error "🔷->❌ PATCH 1/6 FEHLGESCHLAGENdpct/helper.hpp* NICHT GEFUNDEN. ABHÄNGIKEITEN PRÜFEN"
return 1
fi
#PATCH2/6
log "🔷->PATCH 2/6: ggml_flash_attention_sycl"
#2a
if [ ! -d "$CUSTOM_KERNEL_DIR" ]; then
mkdir -p "$CUSTOM_KERNEL_DIR"
log "🔷ORNDER '${CUSTOM_KERNEL_DIR}'ANGELEGT"
fi
if [ -f "$KERNEL_SOURCE_LOCAL" ]; then
cp "$KERNEL_SOURCE_LOCAL" "$CUSTOM_KERNEL_SRC"
log "🔷->✅XARCFA KERNEL './${KERNEL_SOURCE_LOCAL}' nach '${CUSTOM_KERNEL_SRC}' kopiert"
fi
if [ ! -f "$CUSTOM_KERNEL_SRC" ]; then
echo "//Platzhalter für ggml_flash_attention_sycl.cpp KERNELHOME" > "$CUSTOM_KERNEL_SRC"
warning "⚠️KERNELDATEI '${KERNEL_SOURCE_LOCAL}'HOMEPLATZHALTER"
fi
echo "
add_library(ggml_flash_attention_sycl OBJECT
    ggml_flash_attention_sycl.cpp
)
target_include_directories(ggml_flash_attention_sycl PRIVATE \${GGML_SYCL_INCLUDE_DIRS})
target_compile_options(ggml_flash_attention_sycl PUBLIC \${GGML_SYCL_COMPILE_FLAGS})
" > "$CUSTOM_KERNEL_CMAKE"
log "🔷-> CMakeLists.txt für Kernel als OBJECT-Library erstellt"
#2b/6-b
local ADD_SUBDIR_LINE="add_subdirectory(ggml_flash_attention_sycl)"
if ! grep -q "${ADD_SUBDIR_LINE}" "$CMAKE_LISTS_FILE"; then
if sed -i "/add_subdirectory(dpct)/a ${ADD_SUBDIR_LINE}" "$CMAKE_LISTS_FILE"; then
log "🔷->✅🏗PATCH 2/6 ERFOLGREICH ggml_flash_attention_sycl zu Haupt-CMake hinzugefügt"
else
error "❌PATCH 2/6 ggml_flash_attention_sycl hinzufügen ist FEHLGESCHLAGEN"
return 1
fi
else
log "🔷->⚠️PATCH 2/6 ggml_flash_attention_sycl bereits angewandt zu sein. UEBVERSPRINGE"
fi
#PATCH3/6-a
if [ -f "$CMAKE_LISTS_FILE" ]; then
log "🔷-> PATCH 3/6: CMakeLists.txt anpassen (Alle Header-Pfade für icpx)."
local MKL_INCLUDE_PATH="${MKL_ROOT}/include"
local COMPILER_INCLUDE_PATH="${DPCPP_ROOT}/include"
local DPCPP_LIB_INCLUDE_PATH="${DPCPP_ROOT}/lib/dpcpp/include"
local ALL_INCLUDE_FLAGS="-I${MKL_INCLUDE_PATH} -I${COMPILER_INCLUDE_PATH} -I${DPCPP_LIB_INCLUDE_PATH}"
local PATCH_LINE=" target_compile_options(ggml-sycl PUBLIC "${ALL_INCLUDE_FLAGS}")"
local SEARCH_MARKER="# Add include directories for MKL headers"
if ! grep -q "${COMPILER_INCLUDE_PATH}" "$CMAKE_LISTS_FILE"; then
local SED_PATCH_LINE=$(echo "$PATCH_LINE" | sed 's/ /\ /g; s/[/&]/\&/g')
if sed -i "/${SEARCH_MARKER}/a $SED_PATCH_LINE" "$CMAKE_LISTS_FILE"; then
log "🔷->✅🏗PATCH 3/6 erfolgreich: Alle Header-Pfade injiziert."
else
error "❌PATCH 3/6📝CMAKE LISTSTXT NICHT GEFUNDEN ABHÄNGIKEITEN PRÜFEN"
return 1
fi
else
log "🔷->⚠️PATCH 3/6📝PFAD BEREITS BENUTZT... ÜBERSPRINGE"
fi
else
error "❌PATCH 3/6 FEHLGESCHLAGEN:📝CMAKE LISTS FÜR SYCL GGML PFADE NICHT GEFUNDEN ABHÄNGIGKEITEN PRÜFEN"
return 1
fi
#PATCH4/6-a
log "🔷->🏗PATCH 4/6: ggml_flash_attention_sycl.cpp INJIZIEREN🏗"
if [ -f "$GGML_SYCL_CPP" ]; then
#4a/6
local FA_REGISTER_CODE=$'//REGESTRIERE ggml_flash_attention_sycl.cpp \nextern "C" void ggml_flash_attention_sycl(ggml_flash_attention_sycl * ctx, ggml_tensor * dst, const ggml_tensor * Q, const ggml_tensor * K, const ggml_tensor * V);\n'
if ! grep -q "ggml_flash_attention_sycl" "${GGML_SYCL_CPP}"; then
echo "${FA_REGISTER_CODE}" > /tmp/fa_decl.patch
awk '/extern "C" void ggml_flash_attention_sycl/ { system("cat /tmp/fa_decl.patch"); } { print }' "${GGML_SYCL_CPP}" > /tmp/ggml-sycl.cpp.new
mv /tmp/ggml-sycl.cpp.new "${GGML_SYCL_CPP}"
if [ $? -eq 0 ]; then
log "🔷->PATCH 4/6 DEKLARATION ERFOLGREICH EINGEFÜGT"
else
error "❌PATCH 4/6 FEHLER BEIM EINFÜGEN DER ggml_flash_attention_sycl.cpp DEKLARATION (AWK-FEHLER)"
return 1
fi
else
log "🔷->DEKLARATIONEN VORHANDEN FORTFAHREN"
fi
local FA_DISPATCH_CASE=$' case GGML_OP_FLASH_ATTN:\n ggml_flash_attention_sycl(ctx, dst, src0, src1, src2);\n break;'
if ! grep -q "case GGML_OP_FLASH_ATTN:" "${GGML_SYCL_CPP}"; then
log "🔷->Versuche, den Dispatch-Case (FA) mittels AWK einzufügen."
echo "${FA_DISPATCH_CASE}" > /tmp/fa_dispatch.patch
awk '/case GGML_OP_MUL_MAT_Q_K:/ { system("cat /tmp/fa_dispatch.patch"); } { print }' "${GGML_SYCL_CPP}" > /tmp/ggml-sycl.cpp.new
mv /tmp/ggml-sycl.cpp.new "${GGML_SYCL_CPP}"
if [ $? -eq 0 ]; then
log "🔷->PATCH 4/6 ERFOLGREICH✅UNTERBAU ERFOLGREICH EINGEFÜHRT✅"
else
error "🔷->❌PATCH 4/6FEHLER BEIM EINFUEGEN AKW PATCH"
fi
else
log "🔷->✅PATCH 4/6 UNTERBAU🔷VORHANDEN FORTFAHREN"
fi
log "🔷->✅PATCH 4/6 ERFOLGREICH-FLASHATTENTENTION-GELADEN"
else
error "❌PATCH 4/6 FEHLGESCHLAGEN📝❌FLASHATTENTION KERN NICHT GEFUNDEN🔍"
return 1
fi
#PATCH5/6-a
log "🔷->PATCH 5/6: INJIZIEREN OBJEKT🏗VARIABLEN AUS UNTERBLOCK VON  SYCL BIBLIOTHEKEN.."
local CMAKE_LISTS_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/CMakeLists.txt"
#5a/6
local VAR_LINE="set(FA_OBJECT_FILES \"\$<TARGET_OBJECTS:ggml_flash_attention_sycl>\")"
local VAR_SEARCH_MARKER="set(GGML_SYCL_SOURCES"
if ! grep -q "FA_OBJECT_FILES" "$CMAKE_LISTS_FILE"; then
local SED_VAR_LINE=$(echo "$VAR_LINE" | sed 's/[\/&]/\\&/g')
if sed -i "/${VAR_SEARCH_MARKER}/a ${SED_VAR_LINE}" "$CMAKE_LISTS_FILE"; then
log "🔷->5a/6: OBJEKT VARIABLEN 🏗 ERFOLGREICH DEFINIERT"
else
error "❌Patch 5a/6 OBJEKT VARIABLEN🔷FEHLGESCHLAGEN STOPP"
return 1
fi
else
log "🔷->5a/6: OBJEKT VARIABLEN VORHANDEN🔍ÜBERSPRINGE"
fi
#5b/6
local TARGET_SEARCH_MARKER="target_sources(ggml-sycl PRIVATE \${GGML_SYCL_SOURCES})"
local NEW_TARGET_SOURCES_LINE="target_sources(ggml-sycl PRIVATE \${GGML_SYCL_SOURCES} \${FA_OBJECT_FILES})"
if grep -q "${TARGET_SEARCH_MARKER}" "$CMAKE_LISTS_FILE" && ! grep -q "\${FA_OBJECT_FILES}" "$CMAKE_LISTS_FILE"; then
local SED_NEW_LINE=$(echo "$NEW_TARGET_SOURCES_LINE" | sed 's/[\/&]/\\&/g')
local SED_SEARCH_MARKER=$(echo "$TARGET_SEARCH_MARKER" | sed 's/[\/&]/\\&/g')
if sed -i "s/${SED_SEARCH_MARKER}/${SED_NEW_LINE}/" "$CMAKE_LISTS_FILE"; then
log "🔷->✅PATCH 5/6 ERFOLGREICHE INJEKTIONEN IN BAUVORGANG"
else
error "❌PATCH 5b/6 INJEKTION FEHLGESCHLAGEN"
return 1
fi
else
log "🔷->⚠️PATCH 5b/6 IST BEREITS AKTIV INJECTION WIRD ÜBERSPRUNGEN"
fi
#PATCH6/6
log "🔷->PATCH 6/6: ssm_conv.cpp WARNUNG beheben VORZEICHENVERGLEICH"
local SSM_CONV_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/ssm_conv.cpp"
local SEARCH_LINE='GGML_ASSERT(src0->nb[1] == src0->ne[0] * static_cast(sizeof(float)));'
local REPLACE_LINE='GGML_ASSERT(src0->nb[1] == (size_t)(src0->ne[0] * sizeof(float)));' 
if grep -q "${SEARCH_LINE}" "$SSM_CONV_FILE"; then
if sed -i "s/${SEARCH_LINE}/${REPLACE_LINE}/g" "$SSM_CONV_FILE"; then
log "🔷->✅PATCH 6/6ssm_conv.cppERFOLGREICH"
else
error "❌PATCH 6/6ssm_conv.cppFEHLGESCHLAGEN"
return 1
fi
else
log "🔷->⚠️PATCH 6/6ssm_conv.cppZEILE-NICHT-GEFUNDEN-UEBERSPRINGE"
fi
}
success "✅ALLE PATCHES ERFOLGREICH ANGEWAND"
#2XAIGPUARCBAUKONFIGURATION
configure_build() {
log "🔷⚙BEREITE🏗XAIGPUARCBAUVORGANG"
local FP_MODE="${1:-1}"
local FP_FLAG="-DGGML_SYCL_F16=${FP_MODE}"
if [ ! -d "${BUILD_DIR}" ]; then
log "🔷->LEGE-XAIGPUARCORDNER${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" || { err "❌📝KONNTE DEN ORDNER XAIGPUARC '${BUILD_DIR}' NICHT ANLEGEN"; return 1; }
fi
if pushd "${BUILD_DIR}" > /dev/null; then
log "🔷->STARTE-CMAKE-BAU-XAIGPUARC ${FP_FLAG})..."
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
err "❌CMAKE-FEHLGESCHLAGEN"
return 1
fi
success "✅🏗BAU-ABGESCHLOSSEN-XAIGPUARC-BEREIT"
else
err "❌KONNTE NICHT IN-XAIGPUARC-WECHSENL '${BUILD_DIR}'COMPUTER-NUTZER-BERECHTIGUNG-PRÜFEN"
return 1
fi
}
separator() {
echo -e "--XAIGPUARC-BAUFORGANG KANN FORTGESETZT WERDEN❌--\n"
}
#3KOMPILIEREN
compile_project() {
log "🔨✅BAUE-XAIGPUARC-BITTE WARTEN..."
local LOG_FILE="build.log"
log "🔷🏗📝✅KOPFZEILENAUSGABE**${BUILD_DIR}/${LOG_FILE}**GESPEICHERT"
log "🏗✅BAU-XAIGPUARC-KOPFZEILEN"
if pushd "${BUILD_DIR}" > /dev/null; then
log "🏗✅BAU VON XAIGPUARC"
cmake --build . --config "${CMAKE_BUILD_TYPE}" -j ${NPROC} --target llama-cli llama-ls-sycl-device > "${LOG_FILE}" 2>&1
local BUILD_STATUS=$?
popd > /dev/null
if [ ${BUILD_STATUS} -ne 0 ]; then
error "❌BAU VON XAIGPUARC KOPF FEHLGESCHLAGEN: ÜBERPRÜFEN SIE DAS LOG**${BUILD_DIR}/${LOG_FILE}**."
return 1
fi
success "✅BAU VON XAIGPUARC ERFOLGREICH"
else
error "❌KONNTE XAIGPUARC NICHT NEU BAUEN '${BUILD_DIR}' WEGEN FEHLERHAFTEM WECHSEL BAU NICHT MÖGLICH"
return 1
fi
}
#4AUTOMATISCHEGERAETEAUSWAHL
auto_select_device() {
log "🔍SUCHE NACH VERFÜGBAREN SYCL GERÄTEN AUF IHREM SYSTEM."
local FULL_LS_PATH="./${BUILD_DIR}/${LS_SYCL_DEVICE_PATH}"
if [ ! -x "${FULL_LS_PATH}" ]; then
warn "⚠️❌LLAMA UNTERBAU NICHT GEFUNDEN ${FULL_LS_PATH}RÜCKFALL AUF ARC dGPU✅"
export ONEAPI_DEVICE_SELECTOR="level_zero:0->ANBINDUNG ERFOLGREICH✅"
DEVICE="ARC"
return
fi
local DEVICES
DEVICES=$(bash -c "${FULL_LS_PATH}")
if [ -z "$DEVICES" ]; then
warn "⚠️KEINE KOMPATIBLEN SYCL GERÄTE GEFUNDEN: ERROR❌AKTUELLE ABHÄNGIGKEITEN PRÜFEN"
export ONEAPI_DEVICE_SELECTOR="level_zero:0->❌ANBINDUNG FEHLGESCHLAGEN"
DEVICE="ARC"
N_GPU_LAYERS=0
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
N_GPU_LAYERS=0
log "⚠️KEINE GEEIGNETE GRAFIKKARTE GEFUNDEN❌ ,FALL AUF CPU✅ZURÜCK"
return
fi
if [ -n "$TARGET_LINE" ]; then
local TARGET_ID=$(echo "$TARGET_LINE" | awk '{print $1}')
export ONEAPI_DEVICE_SELECTOR="level_zero:${TARGET_ID}"
log "🎯Using Intel ${DEVICE} (Device ${TARGET_ID})"
local VRAM_GIB=$(echo "$TARGET_LINE" | grep -oP '\d+(?=M)' | head -n1)
VRAM_GIB=$((VRAM_GIB / 1024)) #MIB-zu-GIB-
local LAYER_SIZE_MIB=128
local VRAM_MIB_CALC=$((VRAM_GIB * 1024))
N_GPU_LAYERS=$((VRAM_MIB_CALC * 95 / 100 / LAYER_SIZE_MIB))
if [ "$N_GPU_LAYERS" -gt 99 ]; then
N_GPU_LAYERS=99
fi
if [ "$N_GPU_LAYERS" -lt 1 ]; then
N_GPU_LAYERS=1
fi
log "UNGEFÄHRE🔍NGL-1-in  **${N_GPU_LAYERS}**SCHICHTEN🧠"
fi
}
#5SYCLKOMPATIBLEGERÄTEPRUEFEN
list_sycl_devices() {
log "🔍SUCHE SYCL FÄHIGES GERÄT 🏗 AUF IHREM SYSTEM"
local FULL_LS_PATH="./${BUILD_DIR}/${LS_SYCL_DEVICE_PATH}"
if [ -f "${FULL_LS_PATH}" ]; then
"${FULL_LS_PATH}"
else
warn "⚠️KEIN SYCL FÄHIGES SYSTEM GEFUNDEN!!! ${FULL_LS_PATH}.
KONNTE KEIN FÄHIGES GERÄT FINDEN🔍"
fi
}
#6MODELLPFADWAEHLEN
prepare_model() {
MODEL_PATH=${1:-"models/velara-11b-v2.Q8_0CODE.gguf"}
mkdir -p models
if [ ! -f "$MODEL_PATH" ]; then
warn "Ihr AI/KI-Modell konnte leider nicht unter:home/ihrname/models/-gefunden werden.Bitte Kopieren Sie das gewünschte Modell dorthin**$MODEL_PATH**"
fi
export MODEL_PATH
}
separator() {
echo -e "--ANWORT AI/KI INFERENCE AUF LOKALER iGPU/dGPU FOLGT AB HIER--\n"
}
#7MODELLAUSFUEHREN
run_inference() {
local DEFAULT_MODEL_PATH="models/velara-11b-v2.Q8_0CODE.gguf"
local MODEL_PATH_ARG=${2:-$DEFAULT_MODEL_PATH}
local PROMPT_ARG=${3:-"
medi8tor rebuild on linux arch code"}
local GPU_ID=$(echo "$ONEAPI_DEVICE_SELECTOR" | awk -F':' '{print $2}')
local NGL_SET=${N_GPU_LAYERS:-99}
local FULL_LLAMA_CLI_PATH="./${BUILD_DIR}/${LLAMA_CLI_PATH}"
log "🚀STARTE KI ANTWORT PER F16 INFERENCE AUF IHRER iGPU/dGPU MIT FOLGENDEN PARAMETERN**${DEVICE} (ID: ${GPU_ID})** with ngl=${NGL_SET} using **${FULL_LLAMA_CLI_PATH}**..."
if [ ! -x "${FULL_LLAMA_CLI_PATH}" ]; then
err "❌FEHLER. AKTUELLER LLAMA-UNTERBAU-NICHT GEFUNDEN- NEUBAU-FEHLGESCHLAGEN${FULL_LLAMA_CLI_PATH} ?"
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
echo "✅->AI/KI-ANTWORT-FERTIG-GLÜCKWUNSCH"
}
#00DEFINITIONHAUPTMAINFUNKTION
main() {
local FP_MODE="${1:-1}"
local RERUN_BUILD=1
prepare_environment
local FULL_LLAMA_CLI_PATH="./${BUILD_DIR}/${LLAMA_CLI_PATH}"
local FULL_LS_PATH="./${BUILD_DIR}/${LS_SYCL_DEVICE_PATH}"
if [[ -f "${FULL_LLAMA_CLI_PATH}" ]] && [[ -f "${FULL_LS_PATH}" ]]; then
success "✅GEFUNDENE-AKTUELLE XAIGPUARC VERSION-NEUBAU-UNNÖTIG-FORTFAHREN**${FULL_LLAMA_CLI_PATH}** und **${FULL_LS_PATH}**"
log "✅->ÜBERSPRINGE-BAUVORGANG"
RERUN_BUILD=0
else
warning "⚠️KEINE-AKTUELLES-XAIGPUARC-GEFUNDEN-GEBAUT-BITTE WARTEN"
RERUN_BUILD=1
fi
if [[ "$RERUN_BUILD" -eq 1 ]]; then
log "🏗STARTE-ERSTMALIGEN-BAUVORGANG-XAIGPUARC"
setup_project
patch_llama_cpp
configure_build "${FP_MODE}"
compile_project
else
log "⚙->UPDATE-JETZT-NEUESTE-LLAMA-VERSION-BITTE-WARTEN"
setup_project
patch_llama_cpp
fi
auto_select_device
list_sycl_devices
prepare_model "${2:-}"
run_inference "${2:-}" "${3:-}"
log "🎯GLÜCKWUNSCH✅XAIGPUARC🧠ANTWORT✨ABGESCHLOSSEN📝UNTER**${BUILD_DIR}/${LLAMA_CLI_PATH}**"
}
#HAUPTSCHLEIFE
main "${1:-1}" "${2:-}" "${3:-}"
#42
log "DER🏗BAUVERLAUF📝VON-XAIGPUARC-WIRD HIER GESPEICHERT**${LOG_FILE}**"
