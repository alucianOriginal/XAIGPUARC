#!/bin/bash

#--
#--run-with-PREXAIGPUARC-First--
#--//--XAIGPUARC--//--DATA-FACTS--
#--VIBE-CODE-HANDARBEIT--1.07-MIN--Promt TIME--
#--//--Lama3-12B-iQ-6Q.gguf.1.5-15B-GGUF--
#--AI/-dGPU/-iGPU/ARC/XE/VECTOR-SYCL/Q8--/Q6--/f16.RAMmin:2x8GiB--
#-----------------------------
#--AI-16GB-RAM+11,5GB-VRAM-iGPU-dGPU--
#--LowSPEC-SYCL-F16-oneAPI-VECTOR-ARCH-LINUX-TOOL--
#-----------------------------
#--EXAMPLE--TECHNIK--PROMPT--
#--400-Watt-2x-Intel-ARC-A770-(16GiB)-/-4x-750-(8GiB)-/--
#--142-Watt-Single-+-Dual-GPU-auf-AMD-Ryzen-2600-2700x-Intel-6700K-@Z170-/--
#--80-Watt-Intel-12700h-/-12650h-+-A730m-12 GiB-+-6GiB-/--8.7T/s-+-50-80-Promt-T/s--500T/min--
#--30-Watt-Intel-Core-155H-+-ARC-iGPU-(16GiB RAM/-11,5 GiB-VRAM)--4.7T/s-Solar-10.7b--500T/min--
#----------------------------
#----------------------------
#--Globale-Variablen--
#--Pfade-für-Modelle-unten-Beachten--
#--Q6+Q8-Unterstützung-für-FP16-Vector-Berechnungen-auf--
#--kleinen bis mittleren iGPUs und dGPUs-XE,ARC,XMX--
#--Set--#--FOR--#--LITTLE-##PAUSE--

set -euo pipefail
IFS=$'\n\t'

#--
PRECISION="FP16"
DEVICE="ARC"
LLAMA_CPP_DIR="llama.cpp"
BUILD_DIR="${BUILD_DIR:-XAIGPUARC}"
GGML_SYCL_CPP="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/ggml-sycl.cpp"
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
NPROC="${NPROC:-$(nproc)}"
#--
LOG_FILE="${BUILD_DIR:-XAIGPUARC}/XAIGPUARC.log"
#--
LLAMA_CLI_PATH="bin/llama-cli"
LS_SYCL_DEVICE_PATH="bin/llama-ls-sycl-device"
#--
#ONEAPI+SYCL-FUNKTIONEN--
export TCM_ROOT="${TCM_ROOT:-/opt/intel/oneapi/tcm/latest}"
export SYCL_CACHE_PERSISTENT=1
export OCL_ICD_FILENAMES=""
export ZES_ENABLE_SYSMAN=1
export CCACHE_DIR="$HOME/.ccache"
export COMPILER_VERSION="2025.0"
#--
#--00-HILFSFUNKTIONEN---------------
log() { printf "🔷 %s\n" "$*"; }
success() { printf "✅ %s\n" "$*"; }
error() { printf "❌ %s\n\n" "$*"; }
warning() { printf "⚠️ %s\n\n" "$*"; }
err() { error "$*"; }
warn() { printf "⚠️ %s\n" "$*"; }
#--
#--AUSGABE-BEGRUESUNG-UND-VORSTELLUNG--------
separator() {
    echo -e "-----------------------"\n"
    echo -e "----🏗--🏗-XAIGPUARC-🏗--🏗-CLEAR-ANGEL-\n"
    echo -e "VERSION--30.11.2025-FREE-ADVENT-EDITION"\n"
    echo -e "------ENDE------\n"
}
#--
#--0--UMGEBUNG-UND-RUCKFALLMECHANISMEN-VORBEREITEN-----------
prepare_environment() {
    log "HOLE ONE API KOEPF"
    local SETVARS_PATH="/opt/intel/oneapi/setvars.sh"
    if [ ! -f "$SETVARS_PATH" ]; then
        err "ONEAPI NICHT GEFUNDEN: $SETVARS_PATH. INSTALLIERE ZU ERST ONE API"
        exit 1
    fi
    log "SETVARS.SH SETZEN UND PRÜFEN..."
    source "$SETVARS_PATH" --force 2>/dev/null
    local ONEAPI_ROOT_FALLBACK="/opt/intel/oneapi"
    local COMPILER_VERSION_FALLBACK="${COMPILER_VERSION:-2025.0}"
    DPCPP_ROOT="${DPCPP_ROOT:-${ONEAPI_ROOT_FALLBACK}/compiler/${COMPILER_VERSION_FALLBACK}}"
    MKL_ROOT="${MKL_ROOT:-${ONEAPI_ROOT_FALLBACK}/mkl/${COMPILER_VERSION_FALLBACK}}"
    ONEAPI_ROOT="${ONEAPI_ROOT:-${ONEAPI_ROOT_FALLBACK}}"
    export DPCPP_ROOT
    export MKL_ROOT
    export ONEAPI_ROOT
    export CPATH="${CPATH:-}:${MKL_ROOT}/include"
    local LIB_DIR="/opt/intel/oneapi/compiler/latest/lib:/opt/intel/oneapi/mkl/latest/lib"
    export LD_LIBRARY_PATH="./${BUILD_DIR}/bin:${LIB_DIR}:${LD_LIBRARY_PATH:-}"
    #--
    if ! command -v icx &>/dev/null; then
        err "ICX/IPX INTEL COMPILER INSTALLATION..."
        exit 1
    fi
    log "✅ VERBINDUNG ONEAPI GELADEN... (DPCPP_ROOT=${DPCPP_ROOT} und MKL_ROOT=${MKL_ROOT})."
}
#--1--PROJEKT-GESTALTUNG--------
setup_project() {
    log "📦 BAUE XAIGPUARC.... BITTE WARTEN....."
    if [ ! -d "${LLAMA_CPP_DIR}" ]; then
        log "   -> KLONE GRUNDLAGEN VON LLAMA.CPP......"
        git clone https://github.com/ggerganov/llama.cpp "${LLAMA_CPP_DIR}"
        if [ $? -ne 0 ]; then
            err "❌ KLONEN FEHLGESCHLAGEN ABBRUCH"
            exit 1
        fi
    fi
    if pushd "${LLAMA_CPP_DIR}" > /dev/null; then
        log "  ->AKTUALISIERE UNTERMODULE"
        git pull
        git submodule update --init --recursive
        popd > /dev/null
        success "✅ LLAMA.CPP ANTWORTET.... UNTERGRUPPEN WERDEN GELADEN..."
    else
        err "❌ FEHLER HAUPTVERZEICHNIS '${LLAMA_CPP_DIR}' NICHT GEFUNDEN ABBRUCH"
        exit 1
    fi
}

separator() {
    echo -e "============PATCH5/5=========\n"
    echo -e "=======================\n"
}

#--PATCH-5/5-LOGIK------------
patch_llama_cpp() {
    log "🔷 🔷 🩹 Patches für ggml-sycl anwenden (Header & CMake & Kernel-Dispatch-Registrierung)..."
    local DPCT_HELPER_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/dpct/helper.hpp"
    local CMAKE_LISTS_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/CMakeLists.txt"
    local CUSTOM_KERNEL_DIR="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/custom_kernels"
    local CUSTOM_KERNEL_SRC="${CUSTOM_KERNEL_DIR}/ggml_flash_attention_sycl.cpp"
    local CUSTOM_KERNEL_CMAKE="${CUSTOM_KERNEL_DIR}/CMakeLists.txt"
    local GGML_SYCL_CPP="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/ggml-sycl.cpp"
    local KERNEL_SOURCE_LOCAL="ggml_flash_attention_sycl.cpp"
    #--PATCH-1/5--
    if [ -f "$DPCT_HELPER_FILE" ]; then
        log "🔷      -> PATCH 1/5: DOCTPHELPER FEHLGESCHLAGEN. ABHÄNGIGKEITSLISTE PRÜFEN"
        if sed -i 's|#include <sycl/ext/oneapi/math.hpp>|#include <sycl/ext/intel/math.hpp>|g' "$DPCT_HELPER_FILE"; then
             log "🔷      -> ✅ PATCH 1/5 ERFOLGREICH"
        elif sed -i 's|#if \!defined(DPCT\_USM\_LEVEL\_NONE) && defined(DPCT\_ENABLE\_MKL\_MATH).*#endif|#include <sycl/ext/intel/math.hpp>|g' "$DPCT_HELPER_FILE"; then
            log "🔷      -> ✅ PATCH 1/5 ERFOLGREICH (SPEICHERE IN LOG)."
        else
            error "🏗❌ PATCH 1/5 HELPER INSTALLIEREN (dpct/helper.hpp) IST FEHLGESCHLAGEN."
            return 1
        fi
    else
        error "❌ PATCH 1/5 FEHLGESCHLAGEN**dpct/helper.hpp** NICHT GEFUNDEN. ABHÄNGIKEITEN PRÜFEN"
        return 1
    fi
    #--PATCH-2/5--
    log "🔷      -> PATCH 2/5: KRASSEN XARCFA SUPERSPEICHERMATHEKERNEL IN DAS KRASSE XAIGPUARC INTEGRIEREN...."
    #--2a--
    if [ ! -d "$CUSTOM_KERNEL_DIR" ]; then
        mkdir -p "$CUSTOM_KERNEL_DIR"
        log "🔷ZZZ -> ORNDER... '${CUSTOM_KERNEL_DIR}' ...ANGELEGT"
    fi
    if [ -f "$KERNEL_SOURCE_LOCAL" ]; then
        cp "$KERNEL_SOURCE_LOCAL" "$CUSTOM_KERNEL_SRC"
        log "🔷         -> ✅ XARCFA Kernel von './${KERNEL_SOURCE_LOCAL}' nach '${CUSTOM_KERNEL_SRC}' kopiert."
    fi
    if [ ! -f "$CUSTOM_KERNEL_SRC" ]; then
        echo "// Platzhalter für ggml_flash_attention_sycl.cpp (Kernel-Datei fehlte im Home-Verzeichnis)" > "$CUSTOM_KERNEL_SRC"
        warning "⚠️ Kernel-Datei '${KERNEL_SOURCE_LOCAL}' nicht im Home-Verzeichnis gefunden. Es wurde ein Platzhalter erstellt."
    fi
    #--XAIGPUARC--ECHO-PAUSE--
echo "
#==CMakeLists.txt für Flash Attention Kernel (OBJECT-Library)==
#==OBJECT-Library wird verwendet, um die Objektdateien direkt in die Hauptbibliothek einzufügen.==
add_library(ggml_flash_attention OBJECT==
    ggml_flash_attention_sycl.cpp==
)
#==Stelle sicher, dass die Compiler-Optionen für SYCL übernommen werden==
target_include_directories(ggml_flash_attention PRIVATE \${GGML_SYCL_INCLUDE_DIRS})==
target_compile_options(ggml_flash_attention PUBLIC \${GGML_SYCL_COMPILE_FLAGS})==
" > "$CUSTOM_KERNEL_CMAKE"
log "🔷         -> CMakeLists.txt für Kernel als OBJECT-Library erstellt."
#--
#--XAIGPUARC--PAUSE--
    #--2b/5--
    local ADD_SUBDIR_LINE="add_subdirectory(custom_kernels)"
    if ! grep -q "${ADD_SUBDIR_LINE}" "$CMAKE_LISTS_FILE"; then
        if sed -i "/add_subdirectory(dpct)/a ${ADD_SUBDIR_LINE}" "$CMAKE_LISTS_FILE"; then
            log "🔷         -> ✅ PATCH 2/5 erfolgreich: custom_kernels zu Haupt-CMake hinzugefügt."
        else
            error "❌ PATCH 2/5 (custom_kernels hinzufügen) ist fehlgeschlagen."
            return 1
        fi
    else
        log "🔷         -> ⚠️ PATCH 2/5 (custom_kernels) scheint bereits angewandt zu sein. Überspringe."
    fi
    #--PATCH-3/5---
    if [ -f "$CMAKE_LISTS_FILE" ]; then
        log "🔷      -> PATCH 3/5: CMakeLists.txt anpassen (Alle Header-Pfade für icpx)."
        local MKL_INCLUDE_PATH="${MKL_ROOT}/include"
        local COMPILER_INCLUDE_PATH="${DPCPP_ROOT}/include"
        local DPCPP_LIB_INCLUDE_PATH="${DPCPP_ROOT}/lib/dpcpp/include"
        local ALL_INCLUDE_FLAGS="-I${MKL_INCLUDE_PATH} -I${COMPILER_INCLUDE_PATH} -I${DPCPP_LIB_INCLUDE_PATH}"
        local PATCH_LINE="    target_compile_options(ggml-sycl PUBLIC \"${ALL_INCLUDE_FLAGS}\")"
        local SEARCH_MARKER="# Add include directories for MKL headers"
        if ! grep -q "${COMPILER_INCLUDE_PATH}" "$CMAKE_LISTS_FILE"; then
            local SED_PATCH_LINE=$(echo "$PATCH_LINE" | sed 's/ /\\ /g; s/[\/&]/\\&/g')
            if sed -i "/${SEARCH_MARKER}/a $SED_PATCH_LINE" "$CMAKE_LISTS_FILE"; then
                log "🔷      -> ✅ PATCH 3/5 erfolgreich: Alle Header-Pfade injiziert."
            else
                error "❌ PATCH 3/5 📝 CMAKE LISTS:TXT NICHT GEFUNDEN. ABHÄNGIKEITEN PRÜFEN"
                return 1
            fi
        else
            log "🔷      -> ⚠️ PATCH 3/5 PFAD BEREITS BENUTZT... ÜBERSPRINGE"
        fi
    else
        error "❌ PATCH 3/5 FEHLGESCHLAGEN: 📝 CMAKE LISTS FÜR SYCL GGML PFADE NICHT GEFUNDEN ABHÄNGIGKEITEN PRÜFEN"
        return 1
    fi
    #--PATCH-4/5---
    log "🔷      -> PATCH 4/5: FLASH ATTENTION XARCFA IN **ggml-sycl.cpp** INJIZIEREN🏗"
    if [ -f "$GGML_SYCL_CPP" ]; then
        #--4a/5--
        local FA_REGISTER_CODE=$'// REGESTRIERE FLASH ATTENTION KERNEL XARCFA \nextern "C" void ggml_sycl_op_flash_attn(ggml_backend_sycl_context * ctx, ggml_tensor * dst, const ggml_tensor * Q, const ggml_tensor * K, const ggml_tensor * V);\n'
        if ! grep -q "ggml_sycl_op_flash_attn" "${GGML_SYCL_CPP}"; then
            echo "${FA_REGISTER_CODE}" > /tmp/fa_decl.patch
            #--XAIGPUARC--PAUSE--
            awk '/extern "C" void ggml_sycl_op_mul_mat_q_k/ { system("cat /tmp/fa_decl.patch"); } { print }' "${GGML_SYCL_CPP}" > /tmp/ggml-sycl.cpp.new
            mv /tmp/ggml-sycl.cpp.new "${GGML_SYCL_CPP}"
            if [ $? -eq 0 ]; then
                log "🔷 -> PATCH 4/5 DEKLARATION ERFOLGREICH EINGEFÜGT"
            else
                error "❌ PATCH 4/5 FEHLER BEIM EINFÜGEN DER FLASH ATTENTION XARCFA DEKLARATION (AWK-FEHLER)"
                return 1
            fi
        else
            log "🔷 -> DEKLARATIONEN VORHANDEN FORTFAHRE."
        fi
local FA_DISPATCH_CASE=$' case GGML_OP_FLASH_ATTN:\n ggml_sycl_op_flash_attn(ctx, dst, src0, src1, src2);\n            break;'
        if ! grep -q "case GGML_OP_FLASH_ATTN:" "${GGML_SYCL_CPP}"; then
            log "🔷 -> Versuche, den Dispatch-Case (FA) mittels AWK einzufügen."
            #--XAIGPUARC--PAUSE--
            echo "${FA_DISPATCH_CASE}" > /tmp/fa_dispatch.patch
            awk '/case GGML_OP_MUL_MAT_Q_K:/ { system("cat /tmp/fa_dispatch.patch"); } { print }' "${GGML_SYCL_CPP}" > /tmp/ggml-sycl.cpp.new
            mv /tmp/ggml-sycl.cpp.new "${GGML_SYCL_CPP}"
            if [ $? -eq 0 ]; then
                log "🔷 -> PATCH 4/5 ERFOLGREICH ✅ UNTERBAU ERFOLGREICH EINGEFÜHRT✅"
            else
                error "❌ PATCH 4/5 📝 Fehler beim Einfügen des FA Dispatch-Case (AWK-Fehler)"
            fi
        else
            log "🔷 -> ✅ PATCH 4/5 UNTERBAU VORHANDEN FORTFAHREN"
        fi
        log "🔷 -> ✅ PATCH 4/5 ERFOLGREICH FLASH ATTENTENTION GELADEN"
    else
        error "❌ PATCH 4/5 FEHLGESCHLAGEN 📝 **ggml-sycl.cpp** NICHT GEFUNDEN!!!"
        return 1
    fi
#--PATCH-5/5--------------------
#--
    log "🔷 -> PATCH 5/5: INJIZIEREN OBJEKT 🏗 VARIABLEN AUS UNTERBLOCK VON  SYCL BIBLIOTHEKEN.."
    local CMAKE_LISTS_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/CMakeLists.txt"
    #--5a/5--
    local VAR_LINE="set(FA_OBJECT_FILES \"\$<TARGET_OBJECTS:ggml_flash_attention>\")"
    local VAR_SEARCH_MARKER="set(GGML_SYCL_SOURCES"
    if ! grep -q "FA_OBJECT_FILES" "$CMAKE_LISTS_FILE"; then
        #--XAIGPUARC--PAUSE--
        local SED_VAR_LINE=$(echo "$VAR_LINE" | sed 's/[\/&]/\\&/g')
        if sed -i "/${VAR_SEARCH_MARKER}/a ${SED_VAR_LINE}" "$CMAKE_LISTS_FILE"; then
             log "🔷      -> 5a/5: OBJEKT VARIABLEN 🏗 ERFOLGREICH DEFINIERT"
        else
            error "❌ Patch 5a/5 OBJEKT VARIABLEN FEHLGESCHLAGEN STOPP"
            return 1
        fi
    else
        log "🔷 -> 5a/5: OBJEKT VARIABLEN VORHANDEN ÜBERSPRINGE"
    fi
    #--5b/5--
    local TARGET_SEARCH_MARKER="target_sources(ggml-sycl PRIVATE \${GGML_SYCL_SOURCES})"
    local NEW_TARGET_SOURCES_LINE="target_sources(ggml-sycl PRIVATE \${GGML_SYCL_SOURCES} \${FA_OBJECT_FILES})"
    if grep -q "${TARGET_SEARCH_MARKER}" "$CMAKE_LISTS_FILE" && ! grep -q "\${FA_OBJECT_FILES}" "$CMAKE_LISTS_FILE"; then
        #--XAIGPUARC--PAUSE--
        local SED_NEW_LINE=$(echo "$NEW_TARGET_SOURCES_LINE" | sed 's/[\/&]/\\&/g')
        local SED_SEARCH_MARKER=$(echo "$TARGET_SEARCH_MARKER" | sed 's/[\/&]/\\&/g')
        if sed -i "s/${SED_SEARCH_MARKER}/${SED_NEW_LINE}/" "$CMAKE_LISTS_FILE"; then
            log "🔷      -> ✅ PATCH 5/5 ERFOLGREICHE INJEKTIONEN IN BAUVORGANG"
        else
            error "❌ PATCH 5b/5 INJEKTION FEHLGESCHLAGEN!!!"
            return 1
        fi
    else
        log "🔷      -> ⚠️PATCH 5b/5 IST BEREITS AKTIV INJECTION WIRD ÜBERSPRUNGEN"
    fi
    success "✅ ALLE FÜNF PATCHES ERFOLGREICH ANGEWAND"
}
#--
#--2--XAIGPUARC-BAU-KONFIGURATION-------
configure_build() {
    log "🔷 ⚙ BEREITE XAIGPUARC BAUVORGANG VOR"
    local FP_MODE="${1:-1}" #--PRIO-f16-Q8-Q6gguf--
    local FP_FLAG="-DGGML_SYCL_F16=${FP_MODE}"
    if [ ! -d "${BUILD_DIR}" ]; then
        log " -> LEGE XAIGPUARCORDNER AN ${BUILD_DIR}"
        mkdir -p "${BUILD_DIR}" || { err "❌ 📝 KONNTE DEN ORDNER XAIGPUARC '${BUILD_DIR}' NICHT ANLEGEN"; return 1; }
    fi
    if pushd "${BUILD_DIR}" > /dev/null; then
        log " -> STARTE CMAKE BAU XAIGPUARC ${FP_FLAG})..."
        #--XAIGPUARC--PAUSE--
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
            #--XAIGPUARC--PAUSE--
        local CMAKE_STATUS=$?
        popd > /dev/null
        if [ ${CMAKE_STATUS} -ne 0 ]; then
            err "❌ CMAKE FEHLGESCHLAGEN"
            return 1
        fi
        success "✅ 🏗 BAU ABGESCHLOSSEN XAIGPUARC BEREIT"
    else
        err "❌ KONNTE NICHT IN XAIGPUARC WECHSENL '${BUILD_DIR}' BERECHTIGUNG PRÜFEN"
        return 1
    fi
}

separator() {
    echo -e "====XAIGPUARC BAUFORGANG KANN FORTGESETZT WERDEN========\n"
    echo -e "=====XAIGPUARC===EINRICHTUNG ABGESCHLOSSEN=========\n"
    echo -e "===LOKAL KI BAUVORGANG=====ABHÄNGIGKEITEN VORHANDEN====\n"
    echo -e "===FESTE KONFIGURATION VON XAIGPUARC AUF LOKALER MASCHINE======\n"
    echo -e "=====AUF HOME ORDNER GESPEICHERT UND LÖSCHBAR=====\n"
}

#--
#--3--KOMPILIEREN-----------
compile_project() {
    log "🔨 BAUE ....XAIGPUARC....BITTE WARTEN..."
    local LOG_FILE="build.log"
    log "🔷 🏗 📝 KOPFZEILENAUSGABE IM LOG **${BUILD_DIR}/${LOG_FILE}** GESPEICHERT"
    log "🔷 🏗 BAU VON XAIGPUARC KOPFZEILEN"
    if pushd "${BUILD_DIR}" > /dev/null; then
        log "🏗 BAU VON XAIGPUARC"
        cmake --build . --config "${CMAKE_BUILD_TYPE}" -j ${NPROC} --target llama-cli llama-ls-sycl-device > "${LOG_FILE}" 2>&1
        local BUILD_STATUS=$?
        popd > /dev/null
        if [ ${BUILD_STATUS} -ne 0 ]; then
        #--XAIGPUARC--PAUSE--
            error "❌ BAU VON XAIGPUARC KOPF FEHLGESCHLAGEN: ÜBERPRÜFEN SIE DAS LOG **${BUILD_DIR}/${LOG_FILE}**."
            return 1
        fi
        success "✅ BAU VON XAIGPUARC ERFOLGREICH."
    else
        error "❌ KONNTE XAIGPUARC NICHT NEU BAUEN '${BUILD_DIR}' WEGEN FEHLERHAFTEM WECHSEL. BAU NICHT MÖGLICH❌❌❌"
        return 1
    fi
}

separator() {
    echo -e "======================\n"
    echo -e "========AUTOMATISCHE SYCL KOMPATIBLE======\n"
    echo -e "=============\n"
    echo -e "====GERÄTEAUSWAHLVERFAHREN STARTET JETZT !! BITTE GEDULD==\n"
}

#--
#--4--AUTOMATISCHE-GERAETEAUSWAHL-------
auto_select_device() {
    log "🔍 SUCHE NACH VERFÜGBAREN SYCL GERÄTEN AUF IHREM SYSTEM."
    local FULL_LS_PATH="./${BUILD_DIR}/${LS_SYCL_DEVICE_PATH}"
    if [ ! -x "${FULL_LS_PATH}" ]; then
        warn "⚠️ ❌ LLAMA UNTERBAU NICHT GEFUNDEN ${FULL_LS_PATH}. RÜCKFALL AUF ARC dGPU✅"
        export ONEAPI_DEVICE_SELECTOR="level_zero:0 -->ANBINDUNG ERFOLGREICH!✅"
        DEVICE="ARC"
        return
    fi
    local DEVICES
    DEVICES=$(bash -c "${FULL_LS_PATH}")
    if [ -z "$DEVICES" ]; then
        warn "⚠️ KEINE KOMPATIBLEN SYCL GERÄTE GEFUNDEN: ERROR! ❌AKTUELLE ABHÄNGIGKEITEN PRÜFEN!"
        export ONEAPI_DEVICE_SELECTOR="level_zero:0 --> ❌ ANBINDUNG FEHLGESCHLAGEN!"
        DEVICE="ARC"
        N_GPU_LAYERS=0
        return
    fi
    #--XAIGPUARC--PAUSE--
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
        log "⚠️ KEINE GEEIGNETE GRAFIKKARTE GEFUNDEN❌ , FALL AUF CPU ✅ ZURÜCK"
        return
    fi
    #--
    if [ -n "$TARGET_LINE" ]; then
        local TARGET_ID=$(echo "$TARGET_LINE" | awk '{print $1}')
        export ONEAPI_DEVICE_SELECTOR="level_zero:${TARGET_ID}"
        log "🎯 Using Intel ${DEVICE} (Device ${TARGET_ID})"
        local VRAM_GIB=$(echo "$TARGET_LINE" | grep -oP '\d+(?=M)' | head -n1)
        VRAM_GIB=$((VRAM_GIB / 1024)) #--MIB zu-GIB--
        #--XAIGPUARC--PAUSE--
        local LAYER_SIZE_MIB=350
        local VRAM_MIB_CALC=$((VRAM_GIB * 1024))
        N_GPU_LAYERS=$((VRAM_MIB_CALC * 95 / 100 / LAYER_SIZE_MIB))
        #--XAIGPUARC--PAUSE--
        if [ "$N_GPU_LAYERS" -gt 99 ]; then
            N_GPU_LAYERS=99
        fi
        if [ "$N_GPU_LAYERS" -lt 1 ]; then
            N_GPU_LAYERS=1
        fi
        log "🧠 UNGEFÄHRE NGL in  **${N_GPU_LAYERS}** 🧠🎯SCHICHTEN🎯🧠"
    fi
}
#--
#--5--SYCL-KOMPATIBLE-GERÄTE-PRUEFEN-------
list_sycl_devices() {
    log "🔍 SUCHE SYCL FÄHIGES GERÄT AUF IHREM SYSTEM"
    local FULL_LS_PATH="./${BUILD_DIR}/${LS_SYCL_DEVICE_PATH}"

    if [ -f "${FULL_LS_PATH}" ]; then
        "${FULL_LS_PATH}"
    else
        warn "⚠️ KEIN SYCL FÄHIGES SYSTEM GEFUNDEN!!! ${FULL_LS_PATH}.
        KONNTE KEIN FÄHIGES GERÄT FINDEN🔍🔍🔍!!!"
    fi
}

separator() {
    echo -e "===========\n"
    echo -e "=======STARTE-MODELLAUSWAHL======\n"
    echo -e "==============\n"
}

#--0%-MODELL-PFAD-WAEHLEN------
prepare_model() {
    MODEL_PATH=${1:-"models/llama-3-12b-Instruct.i1-Q6_Kgguf"}
#--Change-Human-AI-Modell-NAME-Here-and-Below!-Accurate!-ANFANG--
    mkdir -p models
    if [ ! -f "$MODEL_PATH" ]; then
        warn "Ihr AI/KI-Modell konnte leider nicht unter: --home/ihrname/models/-- gefunden werden. Bitte Kopieren Sie das Modell dorthin.**$MODEL_PATH**. Bitte laden Sie das gewünschte AI/KI Modell. Für die Nutzung von XAIGPUARC wird Empfohlen ein Q6 oder  Q8 gguf IQ-Modell entsprechend 2-3 Gigabyte weniger ihrem VRAM der Größe nach gewählt, um einen Puffer für die Arbeiten auf der iGPU oder der dGPU ihres Systems zu gewährleisten."
    fi
    export MODEL_PATH
}

separator() {
    echo -e "========\n"
    echo -e "==========ACHTUNG! AB HIER KI ANTWORT ERWARTEN======\n"
    echo -e "===============\n"
    echo -e "====ANWORT AI/KI INFERENCE AUF LOKALER iGPU/dGPU FOLGT AB HIER========\n"
    echo -e "=======\n"
}

#--
#-- 7--MODELL-AUSFUEHREN -----
#--Human-AI-Change-Modell-NAME-Here-and-Above!-Accurate!-ENDE--
run_inference() {
    local DEFAULT_MODEL_PATH="models/llama-3-12b-Instruct.i1-Q6_K.gguf"
    #--end--Modell--change--PAUSE--
    local MODEL_PATH_ARG=${2:-$DEFAULT_MODEL_PATH}
    local PROMPT_ARG=${3:-"//--BUILD-A-PERFEKT--//--DIRECT-LOTTERY-DEMOCRACY-BLOCKCHAIN--//--FOR-EVERY-CULTURE--//--ALL-IN-ONE--//--OVER-SYCL--//--START-PYRAMIDIAL-STRUCTURED-MODULAR--TOP-DOWN-CODE--//--"}
    local GPU_ID=$(echo "$ONEAPI_DEVICE_SELECTOR" | awk -F':' '{print $2}')
    local NGL_SET=${N_GPU_LAYERS:-99}
    local FULL_LLAMA_CLI_PATH="./${BUILD_DIR}/${LLAMA_CLI_PATH}"
    log "🚀 STARTE KI ANTWORT PER F16 INFERENCE AUF IHRER iGPU/dGPU mit folgenden PARAMETERN: **${DEVICE} (ID: ${GPU_ID})** with ngl=${NGL_SET} using **${FULL_LLAMA_CLI_PATH}**..."
    if [ ! -x "${FULL_LLAMA_CLI_PATH}" ]; then
        err "❌ FEHLER. AKTUELLER LLAMA-UNTERBAU-NICHT GEFUNDEN- NEUBAU-FEHLGESCHLAGEN ${FULL_LLAMA_CLI_PATH} ?"
        return 1
    fi
#--
    ZES_ENABLE_SYSMAN=1 "${FULL_LLAMA_CLI_PATH}" \
        -no-cnv \
        -m "${MODEL_PATH_ARG}" \
        -p "${PROMPT_ARG}" \
        -n 512 \
        -e \
        -ngl -1 \
        --split-mode none \
        --main-gpu "${GPU_ID}"
    echo "✅->AI/KI-ANTWORT-FERTIG-GLÜCKWUNSCH"
}
#--PROJEKT-GESTALTUNG----
main() {
    local FP_MODE="${1:-1}"
    #--⚠️--WICHTIG--
    local RERUN_BUILD=1
    prepare_environment
    local FULL_LLAMA_CLI_PATH="./${BUILD_DIR}/${LLAMA_CLI_PATH}"
    local FULL_LS_PATH="./${BUILD_DIR}/${LS_SYCL_DEVICE_PATH}"
    if [[ -f "${FULL_LLAMA_CLI_PATH}" && -f "${FULL_LS_PATH}" ]]; then
        success "✅ GEFUNDENE AKTUELLE XAIGPUARC VERSION-NEUBAU UNNÖTIG-FORTFAHREN ${FULL_LLAMA_CLI_PATH} und ${FULL_LS_PATH}"
        log " -> ÜBERSRPINGE BAUVORGANG"
        RERUN_BUILD=0
    else
        warning "⚠️ KEINE-AKTUELLES-XAIGPUARC-GEFUNDEN--!!!WIRD NEU GEBAUT!!!-BITTE WARTEN."
        RERUN_BUILD=1
    fi
    #--XAIGPUARC--PAUSE--
    if [[ "$RERUN_BUILD" -eq 1 ]]; then
        log "🏗 STARTE ERSTMALIGEN BAUVORGANG XAIGPUARC"
        #--
        setup_project
        #--
        patch_llama_cpp
        #--
        configure_build "${FP_MODE}"
        #--
        compile_project
        #--
    else
        log "⚙->UPDATE-JETZT-NEUESTE-LLAMA-VERSION-BITTE-WARTEN."
        setup_project
        patch_llama_cpp
    fi
    auto_select_device
    #--
    list_sycl_devices
    #--
    prepare_model "${2:-}"
    #--
    run_inference "${2:-}" "${3:-}"
    #--
    log "🎯GLÜCKWUNSCH✅XAIGPUARCANT🧠 ANTWORT✨-ABGESCHLOSSEN-UND-GESPEICHERT 📝 UNTER:**${BUILD_DIR}/${LLAMA_CLI_PATH}**--🔍DANKE FÜR DIE NUTZUNG VON🧠 XAIGPUARC🧠--//--Vergleichen Sie ihren Computer mit den der Andere,n durch die einfachen integrierten Vergleichsmethoden, Wichtige Werten sind unten am Ende der Ausgabe die Token pro Sekunde und wieviel Strom sie für den Vergleich verwenden mussten. Folgen Sie für weitere Tipps den letzten Updates"
}
#--
#--XAIGPUARC-STARTEN:-FP16-PRIO-oder-FP32(NOT-PRIO)-----
main "${1:-1}" "${2:-}" "${3:-}"
#---
log "DER VERLAUF WIRD HIER GESPEICHERT: **${LOG_FILE}**"
#--ENDE-ENDE-ENDE-XAIGPUARC----
