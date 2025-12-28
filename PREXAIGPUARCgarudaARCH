#!/bin/bash
#=============================================================================
# PREXAIGPUARC.SH
#
# Dieses Bash-Shell-Skript bereitet die notwendige Umgebung (Abhängigkeiten,
# OneAPI-Toolkit) unter Arch/Garuda Linux vor und startet den Build-Prozess.
#
# FÜR DIE AUSFÜHRUNG: Speichern Sie dieses Skript als PREXAIGPUARC.sh
# und führen Sie es im Terminal aus:
# bash PREXAIGPUARC.sh [Optionale Argumente für XAIGPUARC.sh]
#=============================================================================

# Exit bei Fehlern, Pipe-Fehler abfangen, IFS setzen
set -euo pipefail
IFS=$'\n\t'

# --- Hilfsfunktionen für Konsistente Ausgabe ---

log() { echo -e "🔷 $*"; }
success() { echo -e "✅ $*"; }
error() { echo -e "❌ $*"; }
warning() { echo -e "⚠️ $*"; }

# --- Funktionen ---

install_dependencies() {
    log "Installiere Basis-Abhängigkeiten (git, cmake, ccache, base-devel, onednn) via pacman..."

    # 'command -v' prüft, ob der Befehl existiert.
    if ! command -v sudo &> /dev/null; then
        error "'sudo' Befehl nicht gefunden. Stellen Sie sicher, dass Sie mit Admin-Rechten arbeiten."
        return 1
    fi

    # Installiere die erforderlichen Pakete (Best-Practice für Arch/Garuda)
    # '-Syu' aktualisiert zuerst, '--needed' vermeidet Neuinstallationen
    sudo pacman -Syu --needed git cmake ccache base-devel onednn

    # Prüft den Exit-Code des letzten Befehls
    if [ $? -ne 0 ]; then
        error "Fehler beim Installieren der Pakete mit pacman."
        return 1
    fi

    success "Basis-Abhängigkeiten installiert."
}

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
    log "=== STARTE: XAIGPUARC Build-Vorbereitung (Bash) ==="

    # [1] Abhängigkeiten installieren
    if install_dependencies; then

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
                # Das Hauptskript lädt die oneAPI-Umgebung (setvars.sh) selbst.
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
    else
        error "Kritischer Fehler bei der Installation der Abhängigkeiten."
    fi

    log "=== ENDE: XAIGPUARC Build-Vorbereitung ==="
}

# Starte den Hauptablauf mit allen übergebenen Argumenten
main_flow "$@"
