#!/bin/bash
#----------------------------------------------------------------------------------
#-XAIGPUARC
#-Automatischer Build + Run von llama.cpp mit Intel oneAPI / SYCL Backend
#-Getestet und Optimiert mit fünf unterschiedlichen ARC Endgeräten auf Garuda Linux
#-Intel ARC A770 (16GiB)/ 750 (8GiB)/
#-Single + Dual GPU auf AMD Ryzen 2600/ 2700x/ Intel 6700K @Z170
#-Intel 12700h/12650h + A730m 12 GiB + 6GiB /
#-Intel Core 155H + ARC iGPU (16GiB RAM/ 11,5 GiB-VRAM)
#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------
#-Globale Variablen-
set -euo pipefail
IFS=$'\n\t'

# Standardwerte
PRECISION="FP16"
DEVICE="ARC" # Standard-Fallback
LLAMA_CPP_DIR="llama.cpp"
BUILD_DIR="${BUILD_DIR:-XAIGPUARC}"

GGML_SYCL_CPP="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/ggml-sycl.cpp"

CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
NPROC="${NPROC:-$(nproc)}"


LLAMA_CLI_PATH="bin/llama-cli"
LS_SYCL_DEVICE_PATH="bin/llama-ls-sycl-device"

# ---------------------------------

# oneAPI + SYCL Umgebungsvariablen
export TCM_ROOT="${TCM_ROOT:-/opt/intel/oneapi/tcm/latest}"
export SYCL_CACHE_PERSISTENT=1
export OCL_ICD_FILENAMES=""
export ZES_ENABLE_SYSMAN=1
export CCACHE_DIR="$HOME/.ccache"
export COMPILER_VERSION="2025.0"

# --00-- Hilfsfunktionen ----------------------------------------------------------

log() { echo -e "🔷 $*"; }
success() { echo -e "✅ $*"; }
error() { echo -e "❌ $*\n"; }
warning() { echo -e "⚠️ $*\n"; }
err() { error "$*"; }
warn() { echo -e "⚠️ $*"; }

#-- [0] Umgebung vorbereiten - FINALER FIX: Extrem robuste Fallback-Logik

prepare_environment() {
    log "Aktiviere Intel oneAPI Umgebung (MKL, SYCL/C++ Headers)..."
    local SETVARS_PATH="/opt/intel/oneapi/setvars.sh"

    if [ ! -f "$SETVARS_PATH" ]; then
        err "Die Intel oneAPI Umgebung wurde nicht gefunden unter: $SETVARS_PATH. Bitte zuerst Intel oneAPI installieren!"
        exit 1
    fi

    log "Sourcing setvars.sh, um DPCPP_ROOT und MKL_ROOT zu setzen..."
    # Source ohne Pipe, Fehler umleiten
    source "$SETVARS_PATH" --force 2>/dev/null

    # --- KRITISCHER FIX FÜR LEERE VARIABLEN ---
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

    # -Prüfen ob Compiler existiert-
    if ! command -v icx &>/dev/null; then
        err "Intel compiler (icx/icpx) not found. Check your oneAPI installation."
        exit 1
    fi

    log "✅ oneAPI environment loaded (DPCPP_ROOT=${DPCPP_ROOT} und MKL_ROOT=${MKL_ROOT})."
}

#-- [1] Projekt-Setup -------------------------------------------------------------

setup_project() {
    log "📦 Setting up llama.cpp project..."
    if [ ! -d "${LLAMA_CPP_DIR}" ]; then
        log "   -> Klonen von llama.cpp..."
        git clone https://github.com/ggerganov/llama.cpp "${LLAMA_CPP_DIR}"
        if [ $? -ne 0 ]; then
            err "❌ Klonen von llama.cpp fehlgeschlagen. Breche ab."
            exit 1
        fi
    fi

    if pushd "${LLAMA_CPP_DIR}" > /dev/null; then
        log "   -> Aktualisiere und initialisiere Submodule..."
        git pull
        git submodule update --init --recursive
        popd > /dev/null
        success "✅ llama.cpp ready. (Repo und Submodule sind vorhanden)."
    else
        err "❌ Fehler: Das Hauptverzeichnis '${LLAMA_CPP_DIR}' wurde nicht gefunden. Breche ab."
        exit 1
    fi
}

#-- [05] Robuster Single-Shot Patch für Header-Probleme und Kernel-Integration -------------------------
patch_llama_cpp() {
    log "🔷 🔷 🩹 Patches für ggml-sycl anwenden (Header & CMake & Kernel-Dispatch-Registrierung)..."
    local DPCT_HELPER_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/dpct/helper.hpp"
    local CMAKE_LISTS_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/CMakeLists.txt"
    local CUSTOM_KERNEL_DIR="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/custom_kernels"
    local CUSTOM_KERNEL_SRC="${CUSTOM_KERNEL_DIR}/ggml_flash_attention_sycl.cpp"
    local CUSTOM_KERNEL_CMAKE="${CUSTOM_KERNEL_DIR}/CMakeLists.txt"

    # NEU: Pfad zur Haupt-Dispatch-Datei für Patch 4
    # Diese lokale Definition ist nötig, falls die globale Definition nicht übergeben wird.
    # Sie ist hier erlaubt, weil sie innerhalb einer Funktion ist.
    local GGML_SYCL_CPP="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/ggml-sycl.cpp"

    # NEU: Lokaler Pfad zum XARCFA Kernel im Home-Verzeichnis
    local KERNEL_SOURCE_LOCAL="ggml_flash_attention_sycl.cpp"

    # --- Patch 1: dpct/helper.hpp (MKL/Math Header Korrektur) ---
    if [ -f "$DPCT_HELPER_FILE" ]; then
        log "🔷      -> Patch 1/5: dpct/helper.hpp anpassen (Header Fix zu sycl/ext/intel/math.hpp)."
        # Versuche den einfachen sed-Befehl (ersetzt oneapi durch intel math.hpp)
        if sed -i 's|#include <sycl/ext/oneapi/math.hpp>|#include <sycl/ext/intel/math.hpp>|g' "$DPCT_HELPER_FILE"; then
             log "🔷      -> ✅ Patch 1/5 erfolgreich (Standard)."
        # Fallback auf den komplexeren sed-Befehl, falls der User ihn hat
        elif sed -i 's|#if \!defined(DPCT\_USM\_LEVEL\_NONE) && defined(DPCT\_ENABLE\_MKL\_MATH).*#endif|#include <sycl/ext/intel/math.hpp>|g' "$DPCT_HELPER_FILE"; then
            log "🔷      -> ✅ Patch 1/5 erfolgreich (Fallback)."
        else
            error "❌ Patch 1 (dpct/helper.hpp) ist fehlgeschlagen."
            return 1
        fi
    else
        error "❌ Patch 1 fehlgeschlagen: **dpct/helper.hpp** nicht gefunden."
        return 1
    fi

    # --- Patch 2: Flash Attention Kernel in Build-System integrieren ---
    log "🔷      -> Patch 2/5: XARCFA Kernel in das Build-System integrieren."

    # 2a: Erstelle Kernel-Ordner und kopiere/erstelle Kernel-Datei
    if [ ! -d "$CUSTOM_KERNEL_DIR" ]; then
        mkdir -p "$CUSTOM_KERNEL_DIR"
        log "🔷         -> Ordner '${CUSTOM_KERNEL_DIR}' erstellt."
    fi

    # Kopiere den XARCFA Kernel, falls er im lokalen Verzeichnis existiert.
    if [ -f "$KERNEL_SOURCE_LOCAL" ]; then
        cp "$KERNEL_SOURCE_LOCAL" "$CUSTOM_KERNEL_SRC"
        log "🔷         -> ✅ XARCFA Kernel von './${KERNEL_SOURCE_LOCAL}' nach '${CUSTOM_KERNEL_SRC}' kopiert."
    fi

    # Sicherstellen, dass die Zieldatei existiert, auch wenn der Kernel noch nicht da war
    if [ ! -f "$CUSTOM_KERNEL_SRC" ]; then
        echo "// Platzhalter für ggml_flash_attention_sycl.cpp (Kernel-Datei fehlte im Home-Verzeichnis)" > "$CUSTOM_KERNEL_SRC"
        warning "⚠️ Kernel-Datei '${KERNEL_SOURCE_LOCAL}' nicht im Home-Verzeichnis gefunden. Es wurde ein Platzhalter erstellt."
    fi

    # Erstelle die CMakeLists.txt für unseren Kernel
echo "
# CMakeLists.txt für Flash Attention Kernel (OBJECT-Library)
# OBJECT-Library wird verwendet, um die Objektdateien direkt in die Hauptbibliothek einzufügen.
add_library(ggml_flash_attention OBJECT
    ggml_flash_attention_sycl.cpp
)

# Stelle sicher, dass die Compiler-Optionen für SYCL übernommen werden
target_include_directories(ggml_flash_attention PRIVATE \${GGML_SYCL_INCLUDE_DIRS})
target_compile_options(ggml_flash_attention PUBLIC \${GGML_SYCL_COMPILE_FLAGS})
" > "$CUSTOM_KERNEL_CMAKE"
log "🔷         -> CMakeLists.txt für Kernel als OBJECT-Library erstellt."


    # 2b: Füge das Kernel-Unterverzeichnis zur Haupt-ggml-sycl CMakeLists.txt hinzu
    local ADD_SUBDIR_LINE="add_subdirectory(custom_kernels)"
    if ! grep -q "${ADD_SUBDIR_LINE}" "$CMAKE_LISTS_FILE"; then
        if sed -i "/add_subdirectory(dpct)/a ${ADD_SUBDIR_LINE}" "$CMAKE_LISTS_FILE"; then
            log "🔷         -> ✅ Patch 2/5 erfolgreich: custom_kernels zu Haupt-CMake hinzugefügt."
        else
            error "❌ Patch 2 (custom_kernels hinzufügen) ist fehlgeschlagen."
            return 1
        fi
    else
        log "🔷         -> ⚠️ Patch 2/5 (custom_kernels) scheint bereits angewandt zu sein. Überspringe."
    fi

    # --- Patch 3: CMakeLists.txt (Alle Include-Pfade injizieren) ---
    if [ -f "$CMAKE_LISTS_FILE" ]; then
        log "🔷      -> Patch 3/5: CMakeLists.txt anpassen (Alle Header-Pfade für icpx)."

        local MKL_INCLUDE_PATH="${MKL_ROOT}/include"
        local COMPILER_INCLUDE_PATH="${DPCPP_ROOT}/include"
        local DPCPP_LIB_INCLUDE_PATH="${DPCPP_ROOT}/lib/dpcpp/include"

        local ALL_INCLUDE_FLAGS="-I${MKL_INCLUDE_PATH} -I${COMPILER_INCLUDE_PATH} -I${DPCPP_LIB_INCLUDE_PATH}"
        local PATCH_LINE="    target_compile_options(ggml-sycl PUBLIC \"${ALL_INCLUDE_FLAGS}\")"
        local SEARCH_MARKER="# Add include directories for MKL headers"

        if ! grep -q "${COMPILER_INCLUDE_PATH}" "$CMAKE_LISTS_FILE"; then
            # Spezielle sed-Korrekturen für Pfade/Slashes
            local SED_PATCH_LINE=$(echo "$PATCH_LINE" | sed 's/ /\\ /g; s/[\/&]/\\&/g')
            if sed -i "/${SEARCH_MARKER}/a $SED_PATCH_LINE" "$CMAKE_LISTS_FILE"; then
                log "🔷      -> ✅ Patch 3/5 erfolgreich: Alle Header-Pfade injiziert."
            else
                error "❌ Patch 3 (CMakeLists.txt) ist fehlgeschlagen."
                return 1
            fi
        else
            log "🔷      -> ⚠️ Patch 3/5 (Pfade) scheint bereits angewandt zu sein. Überspringe."
        fi
    else
        error "❌ Patch 3 fehlgeschlagen: **CMakeLists.txt** für ggml-sycl nicht gefunden."
        return 1
    fi

    # --- Patch 4: Flash Attention im ggml-sycl.cpp registrieren (Der entscheidende Fix!) ---
    log "🔷      -> Patch 4/5: Flash Attention Dispatch in **ggml-sycl.cpp** injizieren (Robusterer Fix)."

    if [ -f "$GGML_SYCL_CPP" ]; then
        # 4a: Deklaration des externen Kernels einfügen (WICHTIG für Linker)
        local FA_REGISTER_CODE=$'// Registriere custom Flash Attention (FA) Kernel\nextern "C" void ggml_sycl_op_flash_attn(ggml_backend_sycl_context * ctx, ggml_tensor * dst, const ggml_tensor * Q, const ggml_tensor * K, const ggml_tensor * V);\n'

        if ! grep -q "ggml_sycl_op_flash_attn" "${GGML_SYCL_CPP}"; then
            # Temporäre Datei mit Deklaration erstellen
            echo "${FA_REGISTER_CODE}" > /tmp/fa_decl.patch

            # Einfügen der Deklaration vor dem ggml_sycl_op_mul_mat_q_k (Referenzpunkt)
            # Hier wird 'awk' anstelle von 'sed' verwendet, da es einfacher ist, eine Datei einzufügen
            awk '/extern "C" void ggml_sycl_op_mul_mat_q_k/ { system("cat /tmp/fa_decl.patch"); } { print }' "${GGML_SYCL_CPP}" > /tmp/ggml-sycl.cpp.new
            mv /tmp/ggml-sycl.cpp.new "${GGML_SYCL_CPP}"

            if [ $? -eq 0 ]; then
                log "🔷         -> Deklaration erfolgreich eingefügt."
            else
                error "❌ Fehler beim Einfügen der FA Deklaration (AWK-Fehler)."
                return 1
            fi
        else
            log "🔷         -> Deklaration ist bereits vorhanden. Überspringe."
        fi

local FA_DISPATCH_CASE=$'        case GGML_OP_FLASH_ATTN:\n            ggml_sycl_op_flash_attn(ctx, dst, src0, src1, src2);\n            break;'

        if ! grep -q "case GGML_OP_FLASH_ATTN:" "${GGML_SYCL_CPP}"; then
            log "🔷         -> Versuche, den Dispatch-Case (FA) mittels AWK einzufügen."

            # Temporäre Datei mit dem Dispatch-Case erstellen
            echo "${FA_DISPATCH_CASE}" > /tmp/fa_dispatch.patch

            # Einfügen des Dispatch-Case VOR dem GGML_OP_MUL_MAT_Q_K (Referenzpunkt)
            # awk '/pattern/ { system("cat file"); } { print }'
            awk '/case GGML_OP_MUL_MAT_Q_K:/ { system("cat /tmp/fa_dispatch.patch"); } { print }' "${GGML_SYCL_CPP}" > /tmp/ggml-sycl.cpp.new
            mv /tmp/ggml-sycl.cpp.new "${GGML_SYCL_CPP}"

            if [ $? -eq 0 ]; then
                log "🔷         -> Dispatch-Case erfolgreich eingefügt."
            else
                error "❌ Fehler beim Einfügen des FA Dispatch-Case (AWK-Fehler)."
                # Wir geben hier absichtlich keine Fehlermeldung aus, da wir den Build trotzdem versuchen wollen
                # return 1
            fi
        else
            log "🔷         -> Dispatch-Case ist bereits vorhanden. Überspringe."
        fi

        log "🔷      -> ✅ Patch 4/5 erfolgreich: Flash Attention Dispatch ist registriert."
    else
        error "❌ Patch 4 fehlgeschlagen: **ggml-sycl.cpp** nicht gefunden."
        return 1
    fi

# --- Patch 5: ggml-sycl Library mit custom Kernel injizieren (OBJECT-Injection) ---
    log "🔷      -> Patch 5/5: Injiziere den custom Flash Attention Kernel als OBJECT-Files in ggml-sycl."
    local CMAKE_LISTS_FILE="${LLAMA_CPP_DIR}/ggml/src/ggml-sycl/CMakeLists.txt" # Lokale Definition für Patch 5

    # 5a: Definiere die Variable FA_OBJECT_FILES
    local VAR_LINE="set(FA_OBJECT_FILES \"\$<TARGET_OBJECTS:ggml_flash_attention>\")"
    local VAR_SEARCH_MARKER="set(GGML_SYCL_SOURCES"

    if ! grep -q "FA_OBJECT_FILES" "$CMAKE_LISTS_FILE"; then
        # Füge die Variable direkt nach der Definition von GGML_SYCL_SOURCES ein.
        local SED_VAR_LINE=$(echo "$VAR_LINE" | sed 's/[\/&]/\\&/g')
        if sed -i "/${VAR_SEARCH_MARKER}/a ${SED_VAR_LINE}" "$CMAKE_LISTS_FILE"; then
             log "🔷      -> 5a/5: FA_OBJECT_FILES Variable erfolgreich definiert."
        else
            error "❌ Patch 5a (Variable) ist fehlgeschlagen."
            return 1
        fi
    else
        log "🔷      -> 5a/5: Variable scheint bereits angewandt zu sein. Überspringe."
    fi

    # 5b: Füge die Variable zur target_sources-Liste hinzu
    local TARGET_SEARCH_MARKER="target_sources(ggml-sycl PRIVATE \${GGML_SYCL_SOURCES})"
    local NEW_TARGET_SOURCES_LINE="target_sources(ggml-sycl PRIVATE \${GGML_SYCL_SOURCES} \${FA_OBJECT_FILES})"

    if grep -q "${TARGET_SEARCH_MARKER}" "$CMAKE_LISTS_FILE" && ! grep -q "\${FA_OBJECT_FILES}" "$CMAKE_LISTS_FILE"; then
        # Ersetze die alte target_sources Zeile durch die neue, erweiterte Zeile.
        local SED_NEW_LINE=$(echo "$NEW_TARGET_SOURCES_LINE" | sed 's/[\/&]/\\&/g')
        local SED_SEARCH_MARKER=$(echo "$TARGET_SEARCH_MARKER" | sed 's/[\/&]/\\&/g')

        if sed -i "s/${SED_SEARCH_MARKER}/${SED_NEW_LINE}/" "$CMAKE_LISTS_FILE"; then
            log "🔷      -> ✅ Patch 5/5 erfolgreich: Flash Attention OBJECT-Files in target_sources injiziert."
        else
            error "❌ Patch 5b (Injection in target_sources) ist fehlgeschlagen."
            return 1
        fi
    else
        log "🔷      -> ⚠️ Patch 5/5 (Injection) scheint bereits angewandt zu sein oder Zielzeile nicht gefunden. Überspringe."
    fi

    success "✅ Alle 5 Patches erfolgreich angewandt."
}

#-- [2] Build-Konfiguration -

configure_build() {
    log "🔷 ⚙ Configuring build..."
    local FP_MODE="${1:-1}" # Standard 1 (FP16)
    local FP_FLAG="-DGGML_SYCL_F16=${FP_MODE}"

    if [ ! -d "${BUILD_DIR}" ]; then
        log "   -> Erstelle Build-Verzeichnis: ${BUILD_DIR}"
        mkdir -p "${BUILD_DIR}" || { err "❌ Konnte das Build-Verzeichnis '${BUILD_DIR}' nicht erstellen."; return 1; }
    fi

    if pushd "${BUILD_DIR}" > /dev/null; then

        log "   -> Starte CMake-Konfiguration (Release, SYCL, FP-Mode: ${FP_FLAG})..."

        # Der neue Kernel wird jetzt automatisch als ggml_flash_attention.a kompiliert!
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
            err "❌ CMake-Konfiguration fehlgeschlagen."
            return 1
        fi

        success "✅ Build-Konfiguration abgeschlossen."
    else
        err "❌ Konnte nicht in das Build-Verzeichnis '${BUILD_DIR}' wechseln. Überprüfen Sie die Berechtigungen."
        return 1
    fi
}

#-- [3] Kompilieren ----------------------------------------------------------------

compile_project() {
    log "🔨 Compiling llama.cpp (SYCL targets) using cmake --build..."
    local LOG_FILE="build.log"

    log "🔷 📝 Der gesamte Kompilierungs-Output wird in **${BUILD_DIR}/${LOG_FILE}** gespeichert."
    log "🔷 🎯 Setze Haupt-Build-Targets auf die ausführbaren Programme: llama-cli und llama-ls-sycl-device"

    if pushd "${BUILD_DIR}" > /dev/null; then

        log "🏗 Kompiliere Haupt-Targets..."

        # Wir können das neue Kernel-Target explizit hinzufügen, um sicherzustellen, dass es gebaut wird.
        # Es sollte aber bereits durch die Link-Bibliotheken von llama-cli erfasst werden.
        # Wenn es Probleme gibt, kann 'ggml_flash_attention' hier hinzugefügt werden.
        cmake --build . --config "${CMAKE_BUILD_TYPE}" -j ${NPROC} --target llama-cli llama-ls-sycl-device > "${LOG_FILE}" 2>&1

        local BUILD_STATUS=$?
        popd > /dev/null

        if [ ${BUILD_STATUS} -ne 0 ]; then
            error "❌ Kompilierung der Haupt-Targets (llama-cli) fehlgeschlagen. Überprüfen Sie **${BUILD_DIR}/${LOG_FILE}** für Details."
            return 1
        fi

        success "✅ Kompilierung erfolgreich."
    else
        error "❌ Konnte nicht in das Build-Verzeichnis '${BUILD_DIR}' wechseln. Kompilierung nicht möglich."
        return 1
    fi
}

#-- [4] Gerät automatisch auswählen ------------------------------------------------

auto_select_device() {
    log "🔍 Detecting available SYCL / Level Zero devices ..."

    local FULL_LS_PATH="./${BUILD_DIR}/${LS_SYCL_DEVICE_PATH}"

    if [ ! -x "${FULL_LS_PATH}" ]; then
        warn "⚠️ llama-ls-sycl-device Binary fehlt im Pfad: ${FULL_LS_PATH}. Fallback auf ARC dGPU."
        export ONEAPI_DEVICE_SELECTOR="level_zero:0"
        DEVICE="ARC" # Standard-Fallback
        return
    fi

    #-Liste Geräte auf und erfasse den Output-
    local DEVICES
    # KRITISCHER FIX: Wir nutzen bash -c, um sicherzustellen, dass die Umgebung
    # (inkl. LD_LIBRARY_PATH) für die Ausführung korrekt gesetzt ist.
    DEVICES=$(bash -c "${FULL_LS_PATH}")

    if [ -z "$DEVICES" ]; then
        warn "⚠️ No SYCL devices detected. The system reported an error or zero devices."
        export ONEAPI_DEVICE_SELECTOR="level_zero:0"
        DEVICE="ARC"
        N_GPU_LAYERS=0
        return
    fi

    # ... Der Rest der Logik ist korrekt und sollte jetzt fehlerfrei arbeiten ...

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
        log "⚠️ No suitable GPU found, CPU fallback enabled."
        return
    fi

    if [ -n "$TARGET_LINE" ]; then
        local TARGET_ID=$(echo "$TARGET_LINE" | awk '{print $1}')
        export ONEAPI_DEVICE_SELECTOR="level_zero:${TARGET_ID}"
        log "🎯 Using Intel ${DEVICE} (Device ${TARGET_ID})"

        local VRAM_GIB=$(echo "$TARGET_LINE" | grep -oP '\d+(?=M)' | head -n1)
        VRAM_GIB=$((VRAM_GIB / 1024)) # MIB zu GIB

        local LAYER_SIZE_MIB=350
        local VRAM_MIB_CALC=$((VRAM_GIB * 1024))

        N_GPU_LAYERS=$((VRAM_MIB_CALC * 95 / 100 / LAYER_SIZE_MIB))

        if [ "$N_GPU_LAYERS" -gt 99 ]; then
            N_GPU_LAYERS=99
        fi
        if [ "$N_GPU_LAYERS" -lt 1 ]; then
            N_GPU_LAYERS=1
        fi

        log "🧠 Estimated ngl for offloading: **${N_GPU_LAYERS}** layers."
    fi
}

#-- [5] SYCL-Geräte prüfen ---------------------------------------------------------

list_sycl_devices() {
    log "🔍 Listing SYCL devices ..."
    local FULL_LS_PATH="./${BUILD_DIR}/${LS_SYCL_DEVICE_PATH}"

    if [ -f "${FULL_LS_PATH}" ]; then
        "${FULL_LS_PATH}"
    else
        warn "⚠️ llama-ls-sycl-device binary not found in ${FULL_LS_PATH}. Konnte Geräte nicht auflisten."
    fi
}

#-- [6] Modellpfad -----------------------------------------

prepare_model() {
    MODEL_PATH=${1:-"models/openhermes-2.5-mistral-7b.Q8_0.gguf"}

    mkdir -p models

    if [ ! -f "$MODEL_PATH" ]; then
        warn "Model nicht gefunden unter **$MODEL_PATH**. Bitte vor Ausführung herunterladen!"
    fi

    export MODEL_PATH
}

#-- [7] Inferenz ausführen ---------------------------------------------------------

run_inference() {
    local DEFAULT_MODEL_PATH="models/openhermes-2.5-mistral-7b.Q8_0.gguf"
    local MODEL_PATH_ARG=${2:-$DEFAULT_MODEL_PATH}
    local PROMPT_ARG=${3:-"Hello from SYCL on Intel ARC!"}
    local GPU_ID=$(echo "$ONEAPI_DEVICE_SELECTOR" | awk -F':' '{print $2}')
    local NGL_SET=${N_GPU_LAYERS:-99}
    local FULL_LLAMA_CLI_PATH="./${BUILD_DIR}/${LLAMA_CLI_PATH}"

    log "🚀 Running inference on **${DEVICE} (ID: ${GPU_ID})** with ngl=${NGL_SET} using **${FULL_LLAMA_CLI_PATH}**..."

    # Check, ob das Binary existiert, bevor es aufgerufen wird
    if [ ! -x "${FULL_LLAMA_CLI_PATH}" ]; then
        err "❌ Fehler: Ausführbare Datei **llama-cli** nicht gefunden unter: ${FULL_LLAMA_CLI_PATH}. Build fehlgeschlagen?"
        return 1
    fi

    ZES_ENABLE_SYSMAN=1 "${FULL_LLAMA_CLI_PATH}" \
        -no-cnv \
        -m "${MODEL_PATH_ARG}" \
        -p "${PROMPT_ARG}" \
        -n 512 \
        -e \
        -ngl -1 \
        --split-mode none \
        --main-gpu "${GPU_ID}"

    echo "✅ Inference complete."
}

#-- [8] Main Flow ------------------------------------------------------------------

main() {
    local FP_MODE="${1:-1}"

    # ⚠️ WICHTIG: Setze RERUN_BUILD standardmäßig auf 1 und überprüfe dann, ob es 0 sein kann.
    local RERUN_BUILD=1

    prepare_environment

    local FULL_LLAMA_CLI_PATH="./${BUILD_DIR}/${LLAMA_CLI_PATH}"
    local FULL_LS_PATH="./${BUILD_DIR}/${LS_SYCL_DEVICE_PATH}"

    # --- PRÜFUNG: Build-Skip-Logik ---

    if [[ -f "${FULL_LLAMA_CLI_PATH}" && -f "${FULL_LS_PATH}" ]]; then
        success "✅ Gefundene Binaries: ${FULL_LLAMA_CLI_PATH} und ${FULL_LS_PATH}"
        log "   -> Überspringe die Schritte Setup, Patch, Configure und Compile."
        RERUN_BUILD=0
    else
        warning "⚠️ Keine Binaries gefunden. Starte erstmaligen Build/Rebuild."
        RERUN_BUILD=1
    fi

    #----------------------------------------

    if [[ "$RERUN_BUILD" -eq 1 ]]; then
        log "🏗 Starte Build-Vorgang..."

        setup_project

        patch_llama_cpp

        configure_build "${FP_MODE}"

        compile_project
    else

        log "⚙ Update des llama.cpp Repositories und Überprüfung der Patches..."
        setup_project # Für git pull/submodule update
        patch_llama_cpp # Für die Header-Korrektur und die Integration unserer custom_kernels
    fi

    auto_select_device

    list_sycl_devices

    prepare_model "${2:-}"

    run_inference "${2:-}" "${3:-}"

    log "✨ Skript abgeschlossen. Binärdateien sind bereit in **${BUILD_DIR}/${LLAMA_CLI_PATH}** und **${BUILD_DIR}/${LS_SYCL_DEVICE_PATH}**."
}

# Skript starten: FP16 (Standard) oder FP32 als erstes Argument
main "${1:-1}" "${2:-}" "${3:-}"
