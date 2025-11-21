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

# -oneAPI Umgebung laden-
# Wir unterdrücken die "read-only variable" Meldung
source /opt/intel/oneapi/setvars.sh --force 2>&1 | grep -v 'set: Tried to change the read-only variable'

# Zusätzliche Robustheit: Fügt den MKL Include Pfad zum CPATH hinzu
export CPATH="${CPATH:-}:${ONEAPI_ROOT:-/opt/intel/oneapi/mkl/2025.0}/include"

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

#-- [1b] MKL Include Patch anwenden (Fix für 'oneapi/mkl.hpp' not found) ----------

patch_llama_cpp() {
local DPCT_HELPER_FILE="ggml/src/ggml-sycl/dpct/helper.hpp"

log "🩹 Applying MKL include patch to ${DPCT_HELPER_FILE}..."

if [ -f "$DPCT_HELPER_FILE" ]; then
    # Ändere die spitzen Klammern (<>) zu Anführungszeichen ("").
    # Dies zwingt den Compiler, im lokalen Include-Pfad (der durch CPATH gesetzt ist) zu suchen,
    # anstatt nur in den System-Standardpfaden.
    sed -i 's/#include <oneapi\/mkl\.hpp>/#include \"oneapi\/mkl\.hpp\"/g' "$DPCT_HELPER_FILE"
    echo "✅ Patch applied: Changed <oneapi/mkl.hpp> to \"oneapi/mkl.hpp\" in dpct/helper.hpp."
else
    warn "MKL include file (${DPCT_HELPER_FILE}) not found. Skipping patch."
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

# Da der Patch das Problem behebt, reichen die minimalen, sauberen CXX-Flags
local MKL_INCLUDE_PATH="${ONEAPI_ROOT:-/opt/intel/oneapi}/mkl/2025.0/include"
local EXTRA_CXX_FLAGS="-I${MKL_INCLUDE_PATH}"
echo " Injecting CXX Flags: ${EXTRA_CXX_FLAGS}"


    if [ "$USE_FP16" -eq 1 ]; then
        echo " Building with FP16 "
        cmake .. \
          -DGGML_SYCL=ON \
          -DGGML_SYCL_F16=ON \
          -DGGML_SYCL_USE_LEVEL_ZERO=ON \
          -DGGML_SYCL_USE_OPENCL=OFF \
          -DGGML_SYCL_BACKEND=INTEL \
          -DCMAKE_C_COMPILER=icx \
          -DCMAKE_CXX_COMPILER=icpx \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_CXX_FLAGS="${EXTRA_CXX_FLAGS}"
    else
        echo " Building with FP32"
        cmake .. \
          -DGGML_SYCL=ON \
          -DGGML_SYCL_F16=OFF \
          -DGGML_SYCL_USE_LEVEL_ZERO=ON \
          -DGGML_SYCL_USE_OPENCL=OFF \
          -DGGML_SYCL_BACKEND=INTEL \
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
    echo "🔨 Compiling llama.cpp (SYCL targets)..."

    cmake --build . -- -j"${NPROC}" || \
    cmake --build . --target all -- -j"${NPROC}"

    if [ $? -ne 0 ]; then
        err "Kompilierung fehlgeschlagen. Bitte prüfen Sie die obige Fehlermeldung."
    fi

    if [ ! -f ./bin/llama-sycl ]; then
        err "llama-sycl wurde nicht gebaut."
    fi
    if [ ! -f ./bin/llama-ls-sycl-device ]; then
        err "llama-ls-sycl-device konnte nicht gebaut werden."
    fi

    echo "✅ SYCL Binaries erfolgreich gebaut."
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


