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

#-Globale Variablen für Build-Verzeichnis (werden in auto_select_device gesetzt)-
set -euo pipefail
IFS=$'\n\t'

PRECISION="FP16"

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
echo "🧩 Preparing environment..."

# -oneAPI Umgebung laden-
source /opt/intel/oneapi/setvars.sh --force

# -Prüfen ob Compiler existiert-
if ! command -v icx &>/dev/null; then
    which icx || echo "icx nicht gefunden"
    echo "❌ Intel compiler (icx/icpx) not found. Check your oneAPI installation."
    exit 1
fi
echo "✅ oneAPI environment loaded."

}
#-- [1] Projekt-Setup -------------------------------------------------------------

setup_project() {
echo "📦 Setting up llama.cpp project..."

    # Vorbeugung für ungebundene variable Fehler
    DEVICE="${DEVICE:-ARC}"

if [ ! -d "llama.cpp" ]; then
    echo "📦 Cloning llama.cpp ..."
    git clone https://github.com/ggerganov/llama.cpp.git || exit 1
fi

cd llama.cpp || exit 1

# -Build-Verzeichnis erstellen (Gerät/Präzision-spezifisch)-
mkdir -p "build_${DEVICE}_${PRECISION}"
cd "build_${DEVICE}_${PRECISION}"

echo "✅ llama.cpp ready."

}
#-- [2] Build-Konfiguration -------------------------------------------------------

configure_build() {
echo "⚙️ Configuring build..."

local USE_FP16=${1:-1}

#-Cache leeren für sauberen Rebuild-
rm -rf CMakeCache.txt CMakeFiles

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
          -DCMAKE_BUILD_TYPE=Release

# Wenn FP16 nicht verfügbar nutze FP32
     else
        echo " Building with FP32"
        cmake .. \
          -DGGML_SYCL=ON \
          -DGGML_SYCL_USE_LEVEL_ZERO=ON \
          -DGGML_SYCL_USE_OPENCL=OFF \
          -DGGML_SYCL_BACKEND=INTEL \
          -DCMAKE_C_COMPILER=icx \
          -DCMAKE_CXX_COMPILER=icpx \
          -DCMAKE_BUILD_TYPE=Release
    fi

if [ $? -ne 0 ]; then
    echo "❌ CMake configuration failed."
    exit 1
fi

}
#-- [3] Kompilieren ----------------------------------------------------------------

compile_project() {
    echo "🔨 Compiling llama.cpp (SYCL targets)..."

    # llama-ls-sycl-device
    cmake --build . --target llama-ls-sycl-device --config Release -- -j"$(nproc)"
    if [ ! -f ./bin/llama-ls-sycl-device ]; then
        echo "❌ llama-ls-sycl-device konnte nicht gebaut werden."
        exit 1
    fi

    # llama-sycl
    cmake --build . --target llama-sycl --config Release -- -j"$(nproc)"
    if [ ! -f ./bin/llama-sycl ]; then
        echo "❌ llama-sycl wurde nicht gebaut."
        exit 1
    fi

    echo "✅ SYCL Binaries erfolgreich gebaut."
}

#-- [4] Gerät automatisch auswählen-------------------------------------------------

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
    GPU_VRAM_GB=0
    N_GPU_LAYERS=0
    return
fi

#-Suche nach ARC dGPU-
local ARC_ID
ARC_ID=$(echo "$DEVICES" | grep -i "Intel(R) Arc" | head -n1 | awk '{print $1}')

#-Suche nach iGPU (Iris/Xe/Graphics/ARC-XE-LPG-iGPU)-
#-Sie benötigen Dual Channel RAM Unterstützung für die Aktivierung von ARC-XE-LPG+iGPUs!-

local IGPU_ID
IGPU_ID=$(echo "$DEVICES" | grep -Ei "Iris|Xe|Graphics" | head -n1 | awk '{print $1}')

if [ -n "$ARC_ID" ]; then
    TARGET_LINE=$(echo "$DEVICES" | grep -i "Intel(R) Arc" | head -n1)
    export ONEAPI_DEVICE_SELECTOR="level_zero:${ARC_ID}"
    DEVICE="ARC"
    echo "🎯 Using Intel ARC dGPU (Device ${ARC_ID})"

elif [ -n "$IGPU_ID" ]; then
    TARGET_LINE=$(echo "$DEVICES" | grep -Ei "Iris|Xe|Graphics" | head -n1)
    export ONEAPI_DEVICE_SELECTOR="level_zero:${IGPU_ID}"
    DEVICE="iGPU"
    echo "🎯 Using Intel Integrated GPU (Device ${IGPU_ID})"

else
    export ONEAPI_DEVICE_SELECTOR="opencl:cpu"
    DEVICE="CPU"
    echo "⚠️ No suitable GPU found, CPU fallback enabled."
fi

if [ -n "$TARGET_LINE" ]; then
        # Extrahiere Device ID und VRAM
        local TARGET_ID=$(echo "$TARGET_LINE" | awk '{print $1}')
        # Versuche VRAM (Gedeutete MiB oder GiB) zu extrahieren.
        local VRAM_MIB=$(echo "$TARGET_LINE" | grep -oP '\d+\.\d+(?=\s*MiB)' | head -n1 | cut -d'.' -f1)
        local VRAM_GIB=$(echo "$TARGET_LINE" | grep -oP '\d+\.\d+(?=\s*GiB)' | head -n1 | cut -d'.' -f1)

        # Verwende GiB, wenn vorhanden, sonst MiB/1024
        if [ -n "$VRAM_GIB" ]; then
            GPU_VRAM_GB=$VRAM_GIB
        elif [ -n "$VRAM_MIB" ]; then
            GPU_VRAM_GB=$((VRAM_MIB / 1024))
        else
            warn "Konnte VRAM nicht automatisch ermitteln. Setze auf 16 GiB."
            GPU_VRAM_GB=16
        fi

        export ONEAPI_DEVICE_SELECTOR="level_zero:${TARGET_ID}"

        # ----------------------------------------------------------------------
        # FEHLERBEHEBUNG: Automatischer ngl Teiler Einbau
        # ngl-Faustregel: VRAM (GiB) * 1000 / (Blockgröße * Gewicht_pro_Layer)
        # Für Q4_K_M (ca. 4.5 GB pro 7B Modell)
        # ca. 300 MiB pro 7B Layer. Grob: VRAM (GiB) * 100 / 3
        # VRAM (GiB) * Faktor, z.B. 1.8 für etwas Puffer.
        # (Beispiel: 8 GiB * 1.8 = 14 Layer Puffer)
        # Da ngl = 99 in Deinem Run-Script benutzt wird, nehmen wir mal 95% des VRAM an
        # ----------------------------------------------------------------------

        # Ein Layer braucht grob 300-350 MiB (q4_k_m)
        local LAYER_SIZE_MIB=350
        local VRAM_MIB_CALC=$((GPU_VRAM_GB * 1024))

        # 95% des VRAM für Layer nutzen, Rest für Betriebssystem/Puffer
        N_GPU_LAYERS=$((VRAM_MIB_CALC * 95 / 100 / LAYER_SIZE_MIB))

        if [ "$N_GPU_LAYERS" -gt 99 ]; then
            N_GPU_LAYERS=99 # Max. ngl für viele Modelle
        fi
        if [ "$N_GPU_LAYERS" -lt 1 ]; then
            N_GPU_LAYERS=1 # Mindestens 1 Layer
        fi

        log "🧠 Estimated ngl for offloading: **${N_GPU_LAYERS}** layers."

    else
        export ONEAPI_DEVICE_SELECTOR="opencl:cpu"
        DEVICE="CPU"
        N_GPU_LAYERS=0
        log "⚠️ No suitable GPU found, CPU fallback enabled."
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
    echo "📥 Model nicht gefunden unter **$MODEL_PATH**. Bitte vor Ausführung herunterladen!"
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

echo "🚀 Running inference on **${DEVICE} (ID: ${GPU_ID})**..."
ZES_ENABLE_SYSMAN=1 ./bin/llama-sycl \
    -no-cnv \
    -m "${MODEL_PATH_ARG}" \
    -p "${PROMPT_ARG}" \
    -n 512 \
    -e \
    -ngl 99 \
    --split-mode none \
    --main-gpu "${GPU_ID}"

echo "✅ Inference complete."

}
#-- [8] Main Flow ------------------------------------------------------------------

main() {

prepare_environment

setup_project

configure_build "$@"

compile_project

auto_select_device

list_sycl_devices

prepare_model

run_inference

}

#--Skript starten: FP16 (Standart) oder FP32

main "${1:-1}" "${2:-}" "${3:-}"
