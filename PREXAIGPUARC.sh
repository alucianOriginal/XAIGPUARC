#!/bin/fish

#=============================================================================

#XAIGPUARC_PREP.FISH

#Dieses Fish-Shell-Skript bereitet die notwendige Umgebung (Abhängigkeiten,

#OneAPI-Toolkit) unter Garuda Linux (Arch-basiert mit pacman) vor.

#FÜR DIE AUSFÜHRUNG: Speichern Sie dieses Skript und führen Sie es im Terminal aus:


#=============================================================================


function install_dependencies
echo "🔷 Installiere Basis-Abhängigkeiten (git, cmake, ccache, base-devel) via pacman..."

# Stelle sicher, dass Sie sudo-Rechte haben
if not command -v sudo > /dev/null
    echo "❌ 'sudo' Befehl nicht gefunden. Bitte stellen Sie sicher, dass Sie als Benutzer mit Admin-Rechten arbeiten."
    return 1
end

# Installiere die erforderlichen Pakete (Best-Practice für Arch/Garuda)
sudo pacman -Syu --needed git cmake ccache base-devel onednn
if test $status -ne 0
    echo "❌ Fehler beim Installieren der Pakete mit pacman. Überprüfen Sie Ihre Internetverbindung und Berechtigungen."
    return 1
end

echo "✅ Basis-Abhängigkeiten installiert (git, cmake, ccache, base-devel, onednn)."


end

function install_intel_oneapi_toolkit
echo "🔷 Überprüfung der Intel oneAPI Toolkit Installation..."

# Wir prüfen hier nur, ob der notwendige setvars.sh existiert.
set -l ONEAPI_INSTALL_DIR "/opt/intel/oneapi"
set -l SETVARS_SCRIPT "$ONEAPI_INSTALL_DIR/setvars.sh"

if not test -f "$SETVARS_SCRIPT"
    echo "⚠️  WARNUNG: Das Intel oneAPI Toolkit scheint NICHT unter $ONEAPI_INSTALL_DIR installiert zu sein."
    echo "   BITTE BEACHTEN SIE: Für den SYCL-Build benötigen Sie den **Intel oneAPI Base Toolkit**."
    echo "   Das Skript kann ohne $SETVARS_SCRIPT nicht fortfahren."
    return 1
end

echo "✅ Intel oneAPI Installation unter $ONEAPI_INSTALL_DIR gefunden."


end

function configure_fish_environment
echo "🔷 Konfiguriere Fish-Shell Umgebung für oneAPI (für alle zukünftigen Sessions)..."
set -l FISH_CONFIG "$HOME/.config/fish/config.fish"
set -l ONEAPI_SOURCE_LINE 'source /opt/intel/oneapi/setvars.sh'

# Prüfen, ob die Zeile bereits existiert, um Duplikate zu vermeiden
if not grep -q "$ONEAPI_SOURCE_LINE" "$FISH_CONFIG"
    echo "" >> "$FISH_CONFIG"
    echo "# >> START XAIGPUARC/oneAPI Konfiguration (Automatisch hinzugefügt)" >> "$FISH_CONFIG"
    echo "# Quelle das oneAPI Environment, um Compiler (icx/icpx) und MKL-Pfade zu setzen" >> "$FISH_CONFIG"
    echo "$ONEAPI_SOURCE_LINE --force 2> /dev/null" >> "$FISH_CONFIG"
    echo "# Setze SYCL/LevelZero Umgebungsvariablen für ARC (wie in XAIGPUARC.sh)" >> "$FISH_CONFIG"
    echo "set -gx SYCL_CACHE_PERSISTENT 1" >> "$FISH_CONFIG"
    echo "set -gx ZES_ENABLE_SYSMAN 1" >> "$FISH_CONFIG"
    echo "# << END XAIGPUARC/oneAPI Konfiguration" >> "$FISH_CONFIG"
    echo "" >> "$FISH_CONFIG"
    echo "✅ oneAPI Source-Befehl und SYCL-Variablen zur config.fish hinzugefügt."
    echo "   (Wird in neuen Shell-Sessions aktiv. Für diese Session manuell sourcen!)"
else
    echo "✅ oneAPI Source-Befehl bereits in config.fish gefunden. Keine Änderung."
end

# Führe den Source-Befehl sofort für die aktuelle Session aus (Fish-Syntax)
if test -f "/opt/intel/oneapi/setvars.sh"
    echo "🔷 Lade oneAPI-Umgebung in die aktuelle Shell..."
    source "/opt/intel/oneapi/setvars.sh" --force 2> /dev/null

    # Manuelle Fish-Setzung der oneAPI Variablen nach dem Bash-Source
    set -gx SYCL_CACHE_PERSISTENT 1
    set -gx ZES_ENABLE_SYSMAN 1

    # Test, ob es funktioniert hat
    if command -v icx > /dev/null
        echo "✅ oneAPI Umgebung erfolgreich geladen. Compiler (icx) gefunden."
    else
        echo "❌ Wichtig: Compiler (icx/icpx) nicht gefunden, obwohl setvars gesourced wurde. Überprüfen Sie Ihre oneAPI Installation!"
        return 1
    end
end


end

#=============================================================================

# HAUPTABLAUF

#=============================================================================

function main_flow
echo "=== START: XAIGPUARC Build-Vorbereitung für Garuda/Fish ==="

if install_dependencies
    if install_intel_oneapi_toolkit
        if configure_fish_environment
            echo ""
            echo "✨ VORBEREITUNG ABGESCHLOSSEN! ✨"
            echo "Der Intel Compiler (icx/icpx) und die SYCL-Variablen sind nun in dieser und allen zukünftigen Fish-Shells aktiv."
            echo ""
            echo "--- NÄCHSTER SCHRITT ---"
            echo "1. Stellen Sie sicher, dass Ihr XAIGPUARC.sh Skript ausführbar ist:"
            echo "   chmod +x XAIGPUARC.sh"
            echo "2. Führen Sie es direkt in dieser Shell aus, da die Umgebung nun korrekt ist:"
            echo "   ./XAIGPUARC.sh"
        else
            echo "🔴 Kritischer Fehler bei der Konfiguration der Fish-Umgebung."
        end
    else
        echo "🔴 Kritischer Fehler bei der oneAPI-Überprüfung. Bitte installieren Sie Intel oneAPI."
    end
else
    echo "🔴 Kritischer Fehler bei der Installation der Abhängigkeiten."
end

echo "=== ENDE: XAIGPUARC Build-Vorbereitung ==="


end

# Starte den Hauptablauf

main_flow
