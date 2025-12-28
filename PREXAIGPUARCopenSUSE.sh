#!/bin/bash
set -e

echo "--- XAIGPUARC: openSUSE Ultra-Fix für Intel ARC & iGPU ---"

# 1. System-Check (Leap oder Tumbleweed)
. /etc/os-release
if [[ "$ID" != "opensuse-leap" && "$ID" != "opensuse-tumbleweed" ]]; then
  echo "❌ Dieses Skript ist nur für openSUSE gedacht."
  exit 1
fi

if [[ "$ID" == "opensuse-tumbleweed" ]]; then
  REPO_PATH="tumbleweed"
  echo "🚀 Erkannt: openSUSE Tumbleweed"
else
  REPO_PATH="leap/15.6"
  echo "🌲 Erkannt: openSUSE Leap"
fi

# 2. Intel Repo sauber einrichten
echo "🔗 Richte Intel Repository ein..."
sudo rpm --import https://repositories.intel.com/intel-graphics-keys/GPG-PUB-KEY-INTEL-GRAPHICS
sudo zypper rr intel-graphics 2>/dev/null || true
sudo zypper ar -f "https://repositories.intel.com/graphics/rpm/opensuse/$REPO_PATH/" intel-graphics
sudo zypper --gpg-auto-import-keys ref

# 3. Installation mit "Dampfwalzen-Modus"
# --allow-vendor-change ist kritisch, damit er nicht nach Bestätigung fragt!
echo "📦 Installiere Treiber und KI-Komponenten (bitte warten)..."
sudo zypper --non-interactive install -y --no-recommends --allow-vendor-change \
  intel-level-zero-gpu \
  intel-compute-runtime \
  intel-opencl \
  intel-oneapi-compiler-dpcpp-cpp \
  intel-oneapi-mkl-devel \
  intel-oneapi-runtime-mkl \
  intel-oneapi-runtime-dpcpp-cpp \
  gmmlib-devel \
  libigdgmm12

# 4. Gruppenrechte (Video & Render)
echo "👥 Setze Berechtigungen für $USER..."
sudo usermod -aG video $USER
sudo usermod -aG render $USER

# 5. OneAPI Integration in die Bash (dein Programm braucht das!)
# Wir prüfen, ob der Pfad existiert, bevor wir ihn eintragen
SETVARS_PATH="/opt/intel/oneapi/setvars.sh"
if [ -f "$SETVARS_PATH" ]; then
    if ! grep -q "oneapi/setvars.sh" ~/.bashrc; then
      echo "📝 Trage OneAPI Pfade in ~/.bashrc ein..."
      echo "source $SETVARS_PATH > /dev/null 2>&1" >> ~/.bashrc
    fi
else
    echo "⚠️ Warnung: $SETVARS_PATH wurde nicht gefunden. Bitte Installation prüfen."
fi

echo ""
echo "--- ✅ VORBEREITUNG ABGESCHLOSSEN ---"
echo "🌟 Dein System ist nun bereit für XAIGPUARC."
echo "🔄 BITTE JETZT DEN COMPUTER NEUSTARTEN."
echo "🚀 Danach einfach ./XAIGPUARC.sh starten."
