#!/bin/bash
#=============================================================================
# PREXAIGPUARC_ubuntu.sh - Optimiert für Ubuntu / Debian / Mint
#=============================================================================

set -euo pipefail

log() { echo -e "🔷 $*"; }
success() { echo -e "✅ $*"; }
error() { echo -e "❌ $*"; }
warning() { echo -e "⚠️ $*"; }

install_intel_repo() {
    log "Richte Intel Repository für Ubuntu ein (GPG & Sources)..."
    
    # 1. GPG Schlüssel sicher herunterladen
    wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | \
      sudo gpg --dearmor --yes -o /usr/share/keyrings/intel-graphics.gpg

    # 2. Repository zur Liste hinzufügen
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/graphics/ubuntu $(lsb_release -cs) main" | \
      sudo tee /etc/apt/sources.list.d/intel-graphics.list

    sudo apt-get update
}

install_dependencies() {
    log "Installiere Basis-Abhängigkeiten und Intel Compute-Stack via APT..."

    # Installation der Pakete, die libze_intel_gpu.so und MKL liefern
    # intel-level-zero-gpu ist der entscheidende Baustein für ze_intel
    sudo apt-get install -y \
        git cmake ccache build-essential \
        intel-level-zero-gpu level-zero \
        intel-opencl-icd \
        libigdgmm12

    # Benutzerrechte für GPU-Zugriff
    log "Setze Benutzerrechte (video/render)..."
    sudo usermod -aG video,render "$USER"
    
    success "Abhängigkeiten und Treiber sind bereit."
}

check_oneapi() {
    log "Prüfe auf Intel oneAPI Installation..."
    local SETVARS_PATH="/opt/intel/oneapi/setvars.sh"

    if [ ! -f "$SETVARS_PATH" ]; then
        warning "OneAPI nicht unter $SETVARS_PATH gefunden."
        log "Installiere das notwendige OneAPI Base-Toolkit..."
        
        # Repository für OneAPI (falls noch nicht da)
        wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-GRAPHICS | sudo gpg --dearmor -o /usr/share/keyrings/oneapi-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
        
        sudo apt-get update
        sudo apt-get install -y intel-basekit
    fi
}

main_flow() {
    log "=== STARTE: XAIGPUARC Ubuntu Vorbereitung ==="

    install_intel_repo
    install_dependencies
    check_oneapi

    if [ -f "./XAIGPUARC.sh" ]; then
        chmod +x ./XAIGPUARC.sh
        log "🚀 Starte XAIGPUARC.sh..."
        ./XAIGPUARC.sh "$@"
    else
        warning "XAIGPUARC.sh nicht gefunden. Bitte lade es in diesen Ordner."
    fi

    log "=== ENDE: Vorbereitung ==="
}

main_flow "$@"
