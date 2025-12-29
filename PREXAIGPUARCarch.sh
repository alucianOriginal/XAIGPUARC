#!/bin/bash
# XAIGPUARC: Arch Linux Setup für Intel ARC & iGPU
# Fokus: Pacman-Integrität, AUR-Handling und saubere Shell-Integration

set -e

echo "--- XAIGPUARC: Arch Linux Ultra-Fix für Intel ARC & iGPU ---"

# 1. System-Check
if [ ! -f /etc/arch-release ]; then
  echo "❌ Dieses Skript ist nur für Arch Linux oder darauf basierende Distros gedacht."
  exit 1
fi

echo "🚀 Erkannt: Arch Linux System"

# ------------------------------------------------------------
# 2. Intel GPU & Compute Stack (Offizielle Repos)
# ------------------------------------------------------------
echo "📦 Installiere Intel-Compute-Runtime und GPU-Treiber via Pacman..."

# Wir konzentrieren uns auf die Pakete in den offiziellen Arch-Repositories
# level-zero-intel-gpu ist das Äquivalent zu intel-level-zero-gpu
sudo pacman -Syu --needed --noconfirm \
    intel-compute-runtime \
    level-zero-intel-gpu \
    intel-graphics-compiler \
    libigdgmm \
    onednn \
    cmake \
    ccache \
    base-devel \
    git

# ------------------------------------------------------------
# 3. Intel oneAPI Check (AUR-Support)
# ------------------------------------------------------------
SETVARS_PATH="/opt/intel/oneapi/setvars.sh"

echo "ℹ️ Prüfe Intel oneAPI Base-Toolkit..."

if [ ! -f "$SETVARS_PATH" ]; then
    echo "⚠️ oneAPI Base-Toolkit wurde nicht unter $SETVARS_PATH gefunden."
    echo "💡 Bei Arch erfolgt dies meist über das AUR."
    echo "👉 Bitte installiere es manuell mit: yay -S intel-oneapi-base-toolkit"
    echo ""
    read -p "Hast du das Toolkit bereits installiert und es liegt an einem anderen Ort? (j/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Jj]$ ]]; then
        echo "❌ Abbruch. Bitte installiere das Base-Toolkit und starte das Skript erneut."
        exit 1
    fi
else
    echo "✅ oneAPI Base-Toolkit gefunden."
fi

# ------------------------------------------------------------
# 4. Berechtigungen & User-Gruppen
# ------------------------------------------------------------
echo "👥 Prüfe Benutzerrechte für $USER..."
# In Arch sind video und render oft essentiell für direkten Hardwarezugriff
sudo usermod -aG video,render "$USER" 2>/dev/null || true

# ------------------------------------------------------------
# 5. Shell-Integration (~/.bashrc)
# ------------------------------------------------------------
if [ -f "$SETVARS_PATH" ]; then
    if ! grep -q "oneapi/setvars.sh" ~/.bashrc; then
        echo "📝 Trage OneAPI Pfade in ~/.bashrc ein..."
        # Wir unterdrücken die Meldungen von setvars.sh für eine saubere Shell
        echo "source $SETVARS_PATH > /dev/null 2>&1" >> ~/.bashrc
    fi
fi

# ------------------------------------------------------------
# 6. Finaler Start des Hauptprogramms
# ------------------------------------------------------------
if [ -f "./XAIGPUARC.sh" ]; then
    chmod +x ./XAIGPUARC.sh
    echo "🚀 Starte Hauptskript XAIGPUARC.sh..."
    # Mit exec übergeben wir die Kontrolle vollständig an das Hauptskript
    ./XAIGPUARC.sh "$@"
else
    echo "⚠️ Vorbereitung abgeschlossen, aber XAIGPUARC.sh wurde nicht gefunden."
    echo "💡 Stelle sicher, dass XAIGPUARC.sh im selben Ordner liegt."
fi

echo ""
echo "--- ✅ SETUP ABGESCHLOSSEN ---"
echo "🌟 Dein Arch-System ist nun für Intel ARC vorbereitet."
echo "🔄 BITTE JETZT EINMAL AUS- UND EINLOGGEN (oder Neustart)."
