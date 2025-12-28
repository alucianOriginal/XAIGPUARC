#!/bin/bash
#=============================================================================
# PREXAIGPUARC_arch.sh - Optimiert für Arch / Garuda Linux
#=============================================================================

set -euo pipefail
IFS=$'\n\t'

log() { echo -e "🔷 $*"; }
success() { echo -e "✅ $*"; }
error() { echo -e "❌ $*"; }
warning() { echo -e "⚠️ $*"; }

install_dependencies() {
    log "Installiere Basis-Abhängigkeiten und Intel-Compute-Stack..."

    # Ergänzung um die kritischen Compute-Treiber für Arch
    # level-zero-intel-gpu ist das Pendant zu ze_intel auf SUSE
    local PACKAGES=(
        git cmake ccache base-devel onednn 
        intel-compute-runtime level-zero-intel-gpu 
        intel-graphics-compiler libigdgmm
    )

    sudo pacman -Syu --needed --noconfirm "${PACKAGES[@]}"
    
    # Gruppenrechte setzen
    log "Setze Benutzerrechte (video/render)..."
    sudo usermod -aG video,render "$USER"
    
    success "Basis-Abhängigkeiten und GPU-Treiber installiert."
}

install_intel_oneapi_toolkit() {
    log "Überprüfung der Intel oneAPI Umgebung..."
    local SETVARS_PATH="/opt/intel/oneapi/setvars.sh"

    if [ ! -f "$SETVARS_PATH" ]; then
        warning "Intel oneAPI nicht unter $SETVARS_PATH gefunden."
        log "Versuche alternative Arch-Installation zu finden..."
        
        # Arch-Spezifisch: Manchmal liegen die Symlinks anders
        if command -v icx &> /dev/null; then
            success "Intel Compiler (icx) bereits im Pfad gefunden!"
            return 0
        fi

        error "Bitte installiere 'intel-oneapi-base-toolkit' (z.B. via AUR/yay)."
        log "Tipp: yay -S intel-oneapi-base-toolkit"
        return 1
    fi

    success "Intel oneAPI Toolkit gefunden ($SETVARS_PATH)."
}

main_flow() {
    log "=== STARTE: XAIGPUARC Arch/Garuda Vorbereitung ==="

    install_dependencies

    if install_intel_oneapi_toolkit; then
        # Berechtigung für das Hauptskript sicherstellen
        if [ -f "./XAIGPUARC.sh" ]; then
            chmod +x ./XAIGPUARC.sh
            log "🚀 STARTE XAIGPUARC.sh..."
            # Wir nutzen 'exec', um den Prozess sauber zu übergeben
            ./XAIGPUARC.sh "$@"
        else
            warning "XAIGPUARC.sh nicht im aktuellen Verzeichnis gefunden."
        fi
    fi

    log "=== ENDE: Vorbereitung ==="
}

main_flow "$@"
