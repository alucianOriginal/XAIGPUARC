#!/bin/bash

# ----------------------------------------------------------------------------------
# XAIGPUARC
# Automatischer Build + Run von llama.cpp mit Intel oneAPI / SYCL Backend
# Getestet und Optimiert mit fünf unterschiedlichen ARC Endgeräten auf Garuda Linux
# Intel ARC A770 (16GiB)/ 750 (8GiB)/
# Single + Dual GPU auf AMD Ryzen 2600/ 2700x/ Intel 6700K @Z170
# Intel 12700h/12650h + A730m 12 GiB + 6GiB /
# Intel Core 155H + ARC iGPU (16GiB RAM/ 11,5 GiB-VRAM)
# ----------------------------------------------------------------------------------
# ----------------------------------------------------------------------------------
#-Globale Variablen für Build-Verzeichnis (werden in auto_select_device gesetzt)-
DEVICE="Unknown"
PRECISION="FP16"

# -- [0] Umgebung vorbereiten ------------------------------------------------------
prepare_environment() {
    echo "🧩 Preparing environment..."

    # -oneAPI Umgebung laden-
    source /opt/intel/oneapi/setvars.sh

    # -Prüfen ob Compiler existiert-
    if ! command -v icx &>/dev/null; then
        which icx || echo "icx nicht gefunden"
        echo "❌ Intel compiler (icx/icpx) not found. Check your oneAPI installation."
        exit 1
    fi
    echo "✅ oneAPI environment loaded."
}

# -- [1] Projekt-Setup -------------------------------------------------------------
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


# -- [2] Build-Konfiguration -------------------------------------------------------

configure_build() {
    echo "⚙️ Configuring build..."

    local USE_FP16=${1:-0}

    #-Cache leeren für sauberen Rebuild-
    rm -rf CMakeCache.txt CMakeFiles

    if [ "$USE_FP16" -eq 1 ]; then
        echo " Building with FP16 (GGML_SYCL_F16=ON)"
        cmake .. \
          -DGGML_SYCL=ON \
          -DGGML_SYCL_F16=ON \
          -DGGML_SYCL_BACKEND=INTEL \
          -DCMAKE_C_COMPILER=icx \
          -DCMAKE_CXX_COMPILER=icpx \
          -DCMAKE_BUILD_TYPE=Release

    # Wenn FP16 nicht verfügbar nutze FP32
    else
        echo " Building with FP32"
        cmake .. \
          -DGGML_SYCL=ON \
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



# -- [3] Kompilieren ----------------------------------------------------------------
compile_project() {
    echo "🔨 Compiling llama.cpp for ARC ${DEVICE} ..."
    cmake --build . \
          --config Release \
          -- -j"$(nproc)" -v || {
        echo "❌ Build failed."
        exit 1
    }
    echo "✅ Compilation done."
}

# -- [4] Gerät automatisch auswählen-------------------------------------------------
auto_select_device() {

    echo "🔍 Detecting available SYCL / Level Zero devices ...${GPU_ID}"

    # -Liste Geräte-
    if [ ! -x "./bin/llama-ls-sycl-device" ]; then
        echo "⚙️ Building llama-ls-sycl-device for device detection ..."
        export ONEAPI_DEVICE_SELECTOR="level_zero:0"
        DEVICE="ARC" # Standard-Fallback
        echo "⚠️ llama-ls-sycl-device Binary fehlt. Fallback auf ARC dGPU (Device 0)"
        return
    fi

    #-Liste Geräte auf-
    local DEVICES
    DEVICES=$(./bin/llama-ls-sycl-device 2>/dev/null)

    if [ -z "$DEVICES" ]; then
        echo "⚠️ No SYCL devices detected, using CPU fallback."
        export ONEAPI_DEVICE_SELECTOR="opencl:cpu"
        DEVICE="CPU"
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
        export ONEAPI_DEVICE_SELECTOR="level_zero:${ARC_ID}"
        DEVICE="ARC"
        echo "🎯 Using Intel ARC dGPU (Device ${ARC_ID})"
    elif [ -n "$IGPU_ID" ]; then
        export ONEAPI_DEVICE_SELECTOR="level_zero:${IGPU_ID}"
        DEVICE="iGPU"
        echo "🎯 Using Intel Integrated GPU (Device ${IGPU_ID})"
    else
        export ONEAPI_DEVICE_SELECTOR="opencl:cpu"
        DEVICE="CPU"
        echo "⚠️ No suitable GPU found, CPU fallback enabled."
    fi
}

# -- [5] SYCL-Geräte prüfen ---------------------------------------------------------
list_sycl_devices() {
    echo "🔍 Listing SYCL devices ..."
    if [ -f "./bin/llama-ls-sycl-device" ]; then
        ./bin/llama-ls-sycl-device
    else
        echo "⚠️ llama-ls-sycl-device binary not found. Konnte Geräte nicht auflisten."
    fi
}

# -- [6] Modellpfad + Tokenizer vorbereiten -----------------------------------------
prepare_model() {
    MODEL_PATH=${1:-"models/gemma-3-27b-it-abliterated.q4_k_m.gguf"}
    TOKENIZER_PATH="models/tokenizer.model"

    mkdir -p models

    if [ ! -f "$MODEL_PATH" ]; then
        echo "📥 Model nicht gefunden unter **$MODEL_PATH**. Bitte vor Ausführung herunterladen!"
    fi

    if [ ! -f "$TOKENIZER_PATH" ]; then
        echo "📥 Tokenizer nicht gefunden unter **$TOKENIZER_PATH**. Bitte vor Ausführung herunterladen!"
    fi

    export MODEL_PATH
    export TOKENIZER_PATH
}

# -- [7] Inferenz ausführen ---------------------------------------------------------
run_inference() {
    local DEFAULT_MODEL_PATH="models/gemma-3-27b-it-abliterated.q4_k_m.gguf"
    local MODEL_PATH_ARG=${1:-$DEFAULT_MODEL_PATH}
    local PROMPT_ARG=${2:-"Hello from SYCL on Intel ARC!"}

    #-Extrahieren der automatisch ausgewählten GPU ID-
    local GPU_ID=$(echo "$ONEAPI_DEVICE_SELECTOR" | awk -F':' '{print $2}')

    echo "🚀 Running inference on **${DEVICE} (ID: ${GPU_ID})**..."
    ZES_ENABLE_SYSMAN=1 ./bin/llama-cli \
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

# -- [8] Main Flow ------------------------------------------------------------------
main() {

    # 0. Umgebung vorbereiten
    prepare_environment

    # 1. Projekt-Setup (llama.cpp klonen/wechseln)
    setup_project

    # 2. Build konfigurieren (FP16 oder FP32)
    # Nutzen Sie `main 0` für FP16 (Standart), `main 1` für FP32
    configure_build "$@"

    # 3. Kompilieren
    compile_project

    # 4. Gerät automatisch auswählen und ONEAPI_DEVICE_SELECTOR setzen
    auto_select_device # Nutzt das gerade kompilierte Binary

    # 5. SYCL Geräte auflisten
    list_sycl_devices

    # 6. Modelldateien vorbereiten (Pfade setzen)
    prepare_model

    # 7. Inferenz ausführen
    # Optional: Geben Sie einen anderen Modellpfad und Prompt ein:
    # run_inference "models/meine_q4_k_m.gguf" "Was ist der Sinn deines Lebens?"
    run_inference "${MODEL_PATH}" "Welche sind die wichtigsten Vorteile bei der Nutzung von SYCL auf Intel ARC für KI Inferenzen?"
}

# Skript starten: FP16 (Standart) oder FP32
main ${1:-0}
