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

CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
NPROC="${NPROC:-$(nproc)}"

# oneAPI + SYCL Umgebungsvariablen
export TCM_ROOT="${TCM_ROOT:-/opt/intel/oneapi/tcm/latest}"
export SYCL_CACHE_PERSISTENT=1
export OCL_ICD_FILENAMES=""
export ZES_ENABLE_SYSMAN=1
export CCACHE_DIR="$HOME/.ccache"

# --00-- Hilfsfunktionen ----------------------------------------------------------

log() { echo -e "🔷 $*"; }
warn() { echo -e "⚠️  $*" >&2; }
err() { echo -e "❌ $*" >&2; exit 1; }

#-- [0] Umgebung vorbereiten ------------------------------------------------------

prepare_environment() {
log "Aktiviere Intel oneAPI Umgebung (MKL, SYCL/C++ Headers)..."
local SETVARS_PATH="/opt/intel/oneapi/setvars.sh"

if [ ! -f "$SETVARS_PATH" ]; then
    err "Die Intel oneAPI Umgebung wurde nicht gefunden unter: $SETVARS_PATH. Bitte zuerst Intel oneAPI installieren!"
fi

# -oneAPI Umgebung laden-
source "$SETVARS_PATH" --force 2>&1 | grep -v 'set: Tried to change the read-only variable'

# Zusätzliche Robustheit: Fügt den MKL Include Pfad zum CPATH hinzu
export CPATH="${CPATH:-}:${MKL_ROOT:-/opt/intel/oneapi/mkl/latest}/include"

# -Prüfen ob Compiler existiert-
if ! command -v icx &>/dev/null; then
    err "Intel compiler (icx/icpx) not found. Check your oneAPI installation."
fi
echo "✅ oneAPI environment loaded."
}

#-- [1] Projekt-Setup -------------------------------------------------------------

setup_project() {
echo "📦 Setting up llama.cpp project..."

if [ ! -d "${LLAMA_CPP_DIR}" ]; then
    echo "📦 Cloning llama.cpp ..."
    git clone https://github.com/ggerganov/llama.cpp.git || exit 1
fi

cd "${LLAMA_CPP_DIR}" || exit 1

# Bestimme das Build-Verzeichnis nach den Globalen
BUILD_DIR="build_${DEVICE}_${PRECISION}"
mkdir -p "${BUILD_DIR}"

echo "✅ llama.cpp ready."
}

#-- [1b] Robuster Single-Shot Patch für Header-Probleme (Unverändert, aber wichtig) ---------------------------

patch_llama_cpp() {
    local DPCT_HELPER_FILE="ggml/src/ggml-sycl/dpct/helper.hpp"
    local CMAKE_LISTS_FILE="ggml/src/ggml-sycl/CMakeLists.txt"
    local MKL_INCLUDE_PATH="${ONEAPI_ROOT:-/opt/intel/oneapi}/mkl/2025.0/include"

    log "🔷 🩹 Applying Robuster Single-Shot Patch in ${DPCT_HELPER_FILE} (MKL/Math-Probleme)..."

    if [ -f "$DPCT_HELPER_FILE" ]; then

        log "   -> Patch 1/1: Ersetze den gesamten MKL/Math Header Block durch eine einfache oneapi/math.hpp Inclusion."

        # Verwende Perl für eine robuste Multi-Linien-Ersetzung, die sowohl das Original-Code-Muster als auch
        # das Muster des zuvor teil-gepatchten Codes erkennen und ersetzen kann.
        # Ziel: Entferne `#ifdef GGML_SYCL_USE_INTEL_ONEMKL` bis zum entsprechenden `#endif` und ersetze es durch den reinen `#include`.

        # 1. Ersetze das Muster des Original-Codes
        perl -i -0777 -pe '
            s{
                \#ifdef\s+GGML_SYCL_USE_INTEL_ONEMKL\n
                \#include\s+"oneapi/mkl\.hpp"\n
                //\s+Allow\s+to\s+use\s+the\s+same\s+namespace\s+for\s+Intel\s+oneMKL\s+and\s+oneMath\n
                namespace\s+oneapi\s+\{\n
                \s+namespace\s+math\s+=\s+mkl;\n
                \}\n
                \#else\n
                \#include\s+<oneapi/math\.hpp>\n
                \#endif
            }{
                // ---- START XAIGPUARC Patch: Simplified SYCL Math Header ----
                #include <oneapi/math.hpp>
                // ---- END XAIGPUARC Patch ----
            }xmsg' "$DPCT_HELPER_FILE"

        # 2. Ersetze das Muster des zuvor angewandten 3-Schritte-Patches (falls es noch da ist)
        perl -i -0777 -pe '
            s{
                \#ifdef\s+GGML_SYCL_USE_INTEL_ONEMKL\n
                \#if\s+0\n
                \#include\s+"oneapi/mkl\.hpp"\n
                \#endif\s+//\s+Patch\s+1:\s+MKL\s+header\s+temporarily\s+disabled\n
                \#include\s+<oneapi/math\.hpp>\s+//\s+Patch\s+2:\s+Explicitly\s+added\s+required\s+oneapi/math\s+header\.\n
                //\s+Allow\s+to\s+use\s+the\s+same\s+namespace\s+for\s+Intel\s+oneMKL\s+and\s+oneMath\n
                namespace\s+oneapi\s+\{\n
                \s+//\s+namespace\s+math\s+=\s+mkl;\s+//\s+Patch\s+3:\s+Alias\s+disabled\s+due\s+to\s+missing\s+MKL\s+header\n
                \}\n
                \#else\n
                \#include\s+<oneapi/math\.hpp>\n
                \#endif
            }{
                // ---- START XAIGPUARC Patch: Simplified SYCL Math Header ----
                #include <oneapi/math.hpp>
                // ---- END XAIGPUARC Patch ----
            }xmsg' "$DPCT_HELPER_FILE"


        if grep -q "XAIGPUARC Patch" "$DPCT_HELPER_FILE"; then
            log "   -> ✅ Patch 1/1 angewandt: MKL/Math Header Block erfolgreich vereinfacht."
        else
            warn "   -> ⚠️ Patch 1/1 konnte den MKL/Math Header Block nicht ersetzen. Versuche es mit einer finalen, breit gefassten Ersetzung."

            # 3. Finaler Versuch: Ersetze nur den Anfang, der immer gleich ist.
            sed -i '/\#ifdef GGML_SYCL_USE_INTEL_ONEMKL/,/\#endif/c\/\/ ---- START XAIGPUARC Patch: Simplified SYCL Math Header ----\n\#include <oneapi\/math\.hpp>\n\/\/ ---- END XAIGPUARC Patch ----' "$DPCT_HELPER_FILE"

            if grep -q "XAIGPUARC Patch" "$DPCT_HELPER_FILE"; then
                 log "   -> ✅ Patch 1/1 (Finaler sed) angewandt: MKL/Math Header Block erfolgreich vereinfacht."
            else
                 err "   -> ❌ Kritischer Fehler: Konnte den MKL/Math Header Block nicht patchen. Build wird fehlschlagen."
            fi
        fi

    else
        warn "MKL include file (${DPCT_HELPER_FILE}) not gefunden. Überspringe Patches."
    fi

    # Patch 4 (Beibehalten): Füge den MKL-Include-Pfad explizit als Compile Option ein
    log "🔷 🩹 Applying CMakeLists.txt hard-patch (compile options) to include MKL header path..."

    if [ -f "$CMAKE_LISTS_FILE" ]; then
        local INCLUDE_FLAG="-I${MKL_INCLUDE_PATH}"
        local PATCH_LINE="\ \ \ \ target_compile_options(ggml-sycl PUBLIC ${INCLUDE_FLAG})"

        # Die Überprüfung ist wichtig, um keine doppelten Einträge zu erhalten
        if ! grep -q "target_compile_options(ggml-sycl PUBLIC ${INCLUDE_FLAG})" "$CMAKE_LISTS_FILE"; then
            sed -i "/# Add include directories for MKL headers/a ${PATCH_LINE}" "$CMAKE_LISTS_FILE"
            log "✅ Patch 4 applied: Added explicit **-I** MKL compile option to ggml-sycl target."
        else
            log "⚠️ Patch 4 (compile options) scheint bereits angewandt zu sein. Wird übersprungen."
        fi
    else
        warn "CMakeLists file (${CMAKE_LISTS_FILE}) not found. Skipping patch 4."
    fi
}

#-- [2] Build-Konfiguration -------------------------------------------------------

configure_build() {
echo "⚙️ Configuring build..."

local USE_FP16=${1:-1}

# Wechseln in das Build-Verzeichnis
cd "${BUILD_DIR}"

# EXTREM WICHTIG: Kompletten Build-Ordner löschen
echo "🚨 Full clean of build directory **$(pwd)**..."
rm -rf *

# Hinzufügen des MKL Include Pfades UND des Compiler Include Pfades, da oneapi/math.hpp dort liegt.
local MKL_INCLUDE_PATH="${ONEAPI_ROOT:-/opt/intel/oneapi}/mkl/2025.0/include"
# Die Compiler-Version ist 2025.0, basierend auf der setvars Ausgabe
local COMPILER_INCLUDE_PATH="/opt/intel/oneapi/compiler/2025.0/include"

# WICHTIG: Füge beide Pfade zu den CXX-Flags hinzu.
local EXTRA_CXX_FLAGS="-I${MKL_INCLUDE_PATH} -I${COMPILER_INCLUDE_PATH}"
echo " Injecting CXX Flags: ${EXTRA_CXX_FLAGS}"


    if [ "$USE_FP16" -eq 1 ]; then
        echo " Building with FP16 "
        cmake .. \
          -DGGML_SYCL=ON \
          -DGGML_SYCL_F16=ON \
          -DGGML_SYCL_MKL=OFF \
          -DGGML_SYCL_USE_LEVEL_ZERO=ON \
          -DGGML_SYCL_USE_OPENCL=OFF \
          -DGGML_SYCL_BACKEND=INTEL \
          -DLLAMA_BUILD_MAIN=OFF \
          -DCMAKE_C_COMPILER=icx \
          -DCMAKE_CXX_COMPILER=icpx \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_CXX_FLAGS="${EXTRA_CXX_FLAGS}"
    else
        echo " Building with FP32"
        cmake .. \
          -DGGML_SYCL=ON \
          -DGGML_SYCL_F16=OFF \
          -DGGML_SYCL_MKL=OFF \
          -DGGML_SYCL_USE_LEVEL_ZERO=ON \
          -DGGML_SYCL_USE_OPENCL=OFF \
          -DGGML_SYCL_BACKEND=INTEL \
          -DLLAMA_BUILD_MAIN=OFF \
          -DCMAKE_C_COMPILER=icx \
          -DCMAKE_CXX_COMPILER=icpx \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_CXX_FLAGS="${EXTRA_CXX_FLAGS}"
    fi

if [ $? -ne 0 ]; then
    err "CMake configuration failed."
fi
}

#-- [3] Kompilieren ----------------------------------------------------------------

compile_project() {
    echo "🔨 Compiling llama.cpp (SYCL targets) using cmake --build..."

    # Gehe zurück zum llama.cpp-Stammverzeichnis für den cmake --build Aufruf
    local CURRENT_DIR=$(pwd)
    cd .. # Wechselt in llama.cpp/

    # Definiere den Log-Pfad
    local LOG_FILE="${BUILD_DIR}/build.log"
    log "📝 Der gesamte Kompilierungs-Output wird in **${LLAMA_CPP_DIR}/${LOG_FILE}** gespeichert."

    # Ziel auf 'llama' setzen, da 'llama-sycl' in dieser llama.cpp-Version fehlt.
    local TARGET="llama"
    log "🎯 Setze Haupt-Build-Target auf den vorhandenen Namen: **${TARGET}**"

    # Kompiliere das Haupt-Target (llama) und das Device-Listing-Tool
    echo "🏗️ Kompiliere Haupt-Target: $TARGET (Output wird umgeleitet)"
    # Umleitung von stdout und stderr in die Log-Datei (überschreibt alte Log-Datei)
    cmake --build "${BUILD_DIR}" --target "$TARGET" -j "${NPROC}" &> "${LOG_FILE}"

    # Führe die Fehlerprüfung *nach* dem ersten Kompilierungsbefehl durch
    if [ $? -ne 0 ]; then
        # Zeige die letzten Zeilen des Logs für eine schnelle Ansicht
        log "🔎 Letzten 30 Zeilen des Logs (möglicherweise die Fehlermeldung):"
        tail -n 30 "${LOG_FILE}"
        err "Kompilierung von '$TARGET' fehlgeschlagen. Bitte prüfen Sie die Logdatei: ${LLAMA_CPP_DIR}/${LOG_FILE}"
    fi

    echo "🏗️ Kompiliere Device-Listing Tool: llama-ls-sycl-device (Output wird angehängt)"
    # Umleitung von stdout und stderr in die Log-Datei (wird angehängt)
    cmake --build "${BUILD_DIR}" --target all -- -j "${NPROC}" &>> "${LOG_FILE}"

    # Führe die Fehlerprüfung *nach* dem zweiten Kompilierungsbefehl durch
    if [ $? -ne 0 ]; then
        err "Kompilierung von 'llama-ls-sycl-device' fehlgeschlagen. Bitte prüfen Sie die Logdatei: ${LLAMA_CPP_DIR}/${LOG_FILE}"
    fi

    # Gehe zurück zum Build-Verzeichnis für die Prüfung
    cd "${CURRENT_DIR}"

    # WICHTIG: Die run_inference-Funktion erwartet ./bin/llama-sycl.
    local EXPECTED_SYCL_BINARY="./bin/llama-sycl"
    local BUILT_BINARY="./bin/${TARGET}"

    # 1. Prüfe, ob die erwartete llama-sycl existiert (durch einige CMake-Versionen)
    if [ ! -f "${EXPECTED_SYCL_BINARY}" ]; then
        # 2. Prüfe, ob die Binärdatei unter dem Target-Namen existiert (wahrscheinlich)
        if [ -f "${BUILT_BINARY}" ]; then
            log "⚠️ Binärdatei als **${BUILT_BINARY}** gefunden, benenne sie in **${EXPECTED_SYCL_BINARY}** um, damit der Inferenz-Schritt funktioniert."
            mv "${BUILT_BINARY}" "${EXPECTED_SYCL_BINARY}"
        else
            err "Kompilierung fehlgeschlagen: Weder ${EXPECTED_SYCL_BINARY} noch ${BUILT_BINARY} im ./bin-Ordner gefunden."
        fi
    fi

    if [ ! -f ./bin/llama-ls-sycl-device ]; then
        err "llama-ls-sycl-device konnte nicht gebaut werden."
    fi

    log "🔎 Die letzten 30 Zeilen des Logs:"
    tail -n 30 "${LOG_FILE}"

    echo "✅ SYCL Binaries erfolgreich gebaut. Voller Output in ${LLAMA_CPP_DIR}/${LOG_FILE}"
}

#-- [4] Gerät automatisch auswählen (Beibehalten für Vollständigkeit) ----------------

auto_select_device() {

echo "🔍 Detecting available SYCL / Level Zero devices ..."

# -Liste Geräte-
if [ ! -x "./bin/llama-ls-sycl-device" ]; then
    echo "⚙️ Building llama-ls-sycl-device for device detection ..."
    export ONEAPI_DEVICE_SELECTOR="level_zero:0"
    DEVICE="ARC" # Standard-Fallback
    echo "⚠️ llama-ls-sycl-device Binary fehlt. Fallback auf ARC dGPU"
    return
fi

#-Liste Geräte auf-
local DEVICES
DEVICES=$(./bin/llama-ls-sycl-device 2>/dev/null)

if [ -z "$DEVICES" ]; then
    echo "⚠️ No SYCL devices detected, using CPU fallback."
    export ONEAPI_DEVICE_SELECTOR="opencl:cpu"
    DEVICE="CPU"
    N_GPU_LAYERS=0
    return
fi

#-Suche nach ARC dGPU-
local ARC_ID
ARC_ID=$(echo "$DEVICES" | grep -i "Intel(R) Arc" | head -n1 | awk '{print $1}')

#-Suche nach iGPU (Iris/Xe/Graphics/ARC-XE-LPG-iGPU)-
local IGPU_ID
IGPU_ID=$(echo "$DEVICES" | grep -Ei "Iris|Xe|Graphics" | head -n1 | awk '{print $1}')

local TARGET_LINE=""

if [ -n "$ARC_ID" ]; then
    TARGET_LINE=$(echo "$DEVICES" | grep -i "Intel(R) Arc" | head -n1)
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

        # VRAM-Berechnung beibehalten (vereinfacht)
        local VRAM_GIB=$(echo "$TARGET_LINE" | grep -oP '\d+\.\d+(?=\s*GiB)' | head -n1 | cut -d'.' -f1 || echo 16)

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
echo "🔍 Listing SYCL devices ..."
if [ -f "./bin/llama-ls-sycl-device" ]; then
./bin/llama-ls-sycl-device
else
echo "⚠️ llama-ls-sycl-device binary not found. Konnte Geräte nicht auflisten."
fi
}

#-- [6] Modellpfad -----------------------------------------

prepare_model() {
MODEL_PATH=${1:-"models/gemma-3-27b-it-abliterated.q4_k_m.gguf"}

mkdir -p models

if [ ! -f "$MODEL_PATH" ]; then
    warn "Model nicht gefunden unter **$MODEL_PATH**. Bitte vor Ausführung herunterladen!"
fi

export MODEL_PATH
}

#-- [7] Inferenz ausführen ---------------------------------------------------------

run_inference() {
local DEFAULT_MODEL_PATH="models/gemma-3-27b-it-abliterated.q4_k_m.gguf"
local MODEL_PATH_ARG=${2:-$DEFAULT_MODEL_PATH}
local PROMPT_ARG=${3:-"Hello from SYCL on Intel ARC!"}

#-Extrahieren der automatisch ausgewählten GPU ID-
local GPU_ID=$(echo "$ONEAPI_DEVICE_SELECTOR" | awk -F':' '{print $2}')
local NGL_SET=${N_GPU_LAYERS:-99}

log "🚀 Running inference on **${DEVICE} (ID: ${GPU_ID})** with ngl=${NGL_SET}..."

# ZES_ENABLE_SYSMAN=1 für Monitoring.
ZES_ENABLE_SYSMAN=1 ./bin/llama-sycl \
    -no-cnv \
    -m "${MODEL_PATH_ARG}" \
    -p "${PROMPT_ARG}" \
    -n 512 \
    -e \
    -ngl "${NGL_SET}" \
    --split-mode none \
    --main-gpu "${GPU_ID}"

echo "✅ Inference complete."
}

#-- [8] Main Flow ------------------------------------------------------------------

main() {
    # Setze FP-Präzision basierend auf dem ersten Argument (1=FP16, 0=FP32)
    local FP_MODE="${1:-1}"

    prepare_environment

    setup_project

    # Der integrierte Fix
    patch_llama_cpp

    # Konfiguration und Kompilierung
    configure_build "${FP_MODE}"

    compile_project

    # Post-Kompilierung Schritte (Geräteerkennung und Run)
    auto_select_device

    list_sycl_devices

    prepare_model "${2:-}"

    run_inference "${2:-}" "${3:-}"

    log "✨ Skript abgeschlossen. Binärdateien sind bereit in ${LLAMA_CPP_DIR}/${BUILD_DIR}/bin."
}

# Skript starten: FP16 (Standard) oder FP32 als erstes Argument
main "${1:-1}" "${2:-}" "${3:-}"
