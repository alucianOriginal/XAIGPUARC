#!/bin/bash
#=============================================================================
# PREXAIGPUARC.SH - Version 2.0 (Distro-Agnostisch)
#
# Dieses Skript erkennt automatisch den Paketmanager (Arch/Debian/RedHat/SUSE)
# und installiert die notwendigen Build-Abhängigkeiten, einschließlich
# der Curl-Entwickler-Dateien.
#=============================================================================

# Exit bei Fehlern, Pipe-Fehler abfangen, IFS setzen
set -euo pipefail
IFS=$'\n\t'

# --- Hilfsfunktionen für Konsistente Ausgabe ---

log() { echo -e "🔷 $*"; }
success() { echo -e "✅ $*"; }
error() { echo -e "❌ $*"; exit 1; }
warning() { echo -e "⚠️ $*"; }

# --- NEUE FUNKTION: Paketmanager erkennen und Abhängigkeiten installieren ---

install_dependencies() {
    log "🔍 Starte die automatische Erkennung des Paketmanagers..."

    if ! command -v sudo &> /dev/null; then
        error "'sudo' Befehl nicht gefunden. Stellen Sie sicher, dass Sie als Benutzer mit Admin-Rechten arbeiten."
    fi

    local PKG_MANAGER=""
    local INSTALL_CMD=() # WICHTIG: Befehls-Array-Deklaration
    local PACKAGES_TO_INSTALL=() # WICHTIG: Paket-Array-Deklaration

    # --- 2. Distributionserkennung und Paketzuteilung (mit Arrays) ---

    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt (Debian/Ubuntu-Familie)"
        # Installation und Update werden getrennt behandelt, um '&&' in einem Array zu vermeiden
        INSTALL_CMD=("sudo" "apt" "install" "-y" "--no-install-recommends")
        PACKAGES_TO_INSTALL=("git" "cmake" "ccache" "build-essential" "libcurl4-openssl-dev" "libonednn-dev")

        log "   -> Führe 'sudo apt update' aus..."
        sudo apt update || warning "⚠️ Apt update fehlgeschlagen. Installation wird versucht, aber könnte fehlschlagen."


    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf (Red Hat/Fedora-Familie)"
        INSTALL_CMD=("sudo" "dnf" "install" "-y")
        PACKAGES_TO_INSTALL=("git" "cmake" "ccache" "@development-tools" "curl-devel" "onednn-devel")

    elif command -v zypper &> /dev/null; then
        PKG_MANAGER="zypper (SUSE-Familie)"
        INSTALL_CMD=("sudo" "zypper" "install" "-y")
        PACKAGES_TO_INSTALL=("git" "cmake" "ccache" "patterns-devel_basis" "libcurl-devel" "libonednn-devel")

    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman (Arch/Garuda-Familie)"
        INSTALL_CMD=("sudo" "pacman" "-Syu" "--needed")
        PACKAGES_TO_INSTALL=("git" "cmake" "ccache" "base-devel" "onednn")

    else
        error "Kein unterstützter Paketmanager (apt, dnf, zypper, pacman) gefunden."
    fi

    log "Verwende ${PKG_MANAGER} zur Installation der Abhängigkeiten."
    log "Die zu installierenden Pakete sind: ${PACKAGES_TO_INSTALL[*]}"

    # --- 3. Installation ausführen (mit korrekter Array-Expansion) ---
    log "Starte Installation..."
    # Wichtig: Die Arrays MÜSSEN mit "${ARRAY[@]}" expandiert werden, um die Elemente
    # korrekt als einzelne Argumente an das Installationsprogramm zu übergeben.

    if "${INSTALL_CMD[@]}" "${PACKAGES_TO_INSTALL[@]}"; then
        success "✅ Alle Basis-Abhängigkeiten und Curl-Entwickler-Dateien erfolgreich installiert."
        return 0
    else
        error "❌ Fehler beim Installieren der Pakete mit ${PKG_MANAGER}. Bitte überprüfen Sie Ihre Repository-Zugriff."
    fi
}

# --- Funktionen (Rest wie gehabt) ---

install_intel_oneapi_toolkit() {
    log "Überprüfung der Intel oneAPI Toolkit Installation..."

    # Pfad zum setvars.sh Skript (Standardpfad)
    local SETVARS_PATH="/opt/intel/oneapi/setvars.sh"

    # Prüft, ob die Datei existiert
    if [ ! -f "$SETVARS_PATH" ]; then
        warning "Die Intel oneAPI Installation ('$SETVARS_PATH') wurde NICHT gefunden."
        log "Bitte installieren Sie das Intel oneAPI Base Toolkit und HPC Toolkit."
        return 1
    fi

    success "Intel oneAPI Toolkit gefunden ($SETVARS_PATH)."
}

# --- Hauptablauf ---

main_flow() {
    log "=== STARTE: XAIGPUARC Build-Vorbereitung (Bash, Distro-Agnostisch) ==="

    # [1] Abhängigkeiten installieren (Jetzt Distro-Agnostisch)
    install_dependencies # Exit bei Fehler durch 'set -e' in der Skript-Kopfzeile

    # [2] OneAPI Installation prüfen
    if install_intel_oneapi_toolkit; then

        echo ""
        echo "✨ VORBEREITUNG ABGESCHLOSSEN! Abhängigkeiten und oneAPI sind vorhanden. ✨"
        echo ""
        echo "--- NÄCHSTER SCHRITT ---"

        # [3] Prüfe und starte das Haupt-Build-Skript (XAIGPUARC.sh)
        if [ -f "./XAIGPUARC.sh" ]; then
            log "🚀 STARTE XAIGPUARC.sh (Das Haupt-Build-Skript) direkt..."

            # Führe XAIGPUARC.sh mit allen Argumenten der PREP-Datei aus
            bash "./XAIGPUARC.sh" "$@"

            if [ $? -ne 0 ]; then
                error "Das Haupt-Build-Skript (XAIGPUARC.sh) ist mit einem Fehler beendet."
            else
                success "XAIGPUARC.sh wurde erfolgreich ausgeführt."
            fi
        else
            warning "KONVENTION: Bitte speichern Sie das Haupt-Build-Skript als **XAIGPUARC.sh**"
            warning "   und starten Sie es manuell: bash ./XAIGPUARC.sh [args]"
        fi
    else
        error "Kritischer Fehler bei der oneAPI-Überprüfung."
    fi

    log "=== ENDE: XAIGPUARC Build-Vorbereitung ==="
}

# Starte den Hauptablauf mit allen übergebenen Argumenten
main_flow "$@"
