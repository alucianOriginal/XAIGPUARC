#!/bin/bash
# Verhindert den Abbruch bei Fehlern, außer wir wollen es
set -e

echo "--- XAIGPUARC: openSUSE Ultra-Fix für Intel ARC & iGPU ---"

# 1. System-Check
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

# 2. Intel Repo & Key-Management
echo "🔗 Richte Intel Repository ein..."
sudo zypper rr intel-graphics 2>/dev/null || true
sudo zypper ar -f "https://repositories.intel.com/graphics/rpm/opensuse/$REPO_PATH/" intel-graphics

# Falls der automatische Import scheitert, erzwingen wir es hier mit User-Agent
echo "🔑 Importiere GPG-Key (Gatekeeper-Bypass)..."
curl -H "User-Agent: Mozilla/5.0" -L "https://repositories.intel.com/intel-graphics-keys/GPG-PUB-KEY-INTEL-GRAPHICS" -o /tmp/intel-key.pub || echo "⚠️ Download fehlgeschlagen, versuche Zypper-Standard..."
sudo rpm --import /tmp/intel-key.pub 2>/dev/null || true

# Jetzt alles aktualisieren
sudo zypper --gpg-auto-import-keys ref

# 3. Installation
echo "📦 Installiere Treiber und KI-Komponenten..."
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

# 4. Gruppenrechte
echo "👥 Setze Berechtigungen für $USER..."
sudo usermod -aG video $USER
sudo usermod -aG render $USER

# 5. OneAPI Integration
SETVARS_PATH="/opt/intel/oneapi/setvars.sh"
# Wir warten kurz, falls das Dateisystem langsam ist
sleep 2 
if [ -f "$SETVARS_PATH" ]; then
    if ! grep -q "oneapi/setvars.sh" ~/.bashrc; then
      echo "📝 Trage OneAPI Pfade in ~/.bashrc ein..."
      echo "source $SETVARS_PATH > /dev/null 2>&1" >> ~/.bashrc
    fi
else
    echo "⚠️ Hinweis: $SETVARS_PATH wird erst nach einem Neustart oder Source-Befehl voll aktiv."
fi

echo ""
echo "--- ✅ VORBEREITUNG ABGESCHLOSSEN ---"
echo "🌟 System bereit für XAIGPUARC."
echo "🔄 BITTE JETZT DEN COMPUTER NEUSTARTEN."
