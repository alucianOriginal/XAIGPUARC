#!/bin/bash
# XAIGPUARC: Ubuntu/Debian/Mint Setup für Intel ARC & iGPU
# Fokus: Ausfallsicherheit, HTTP-Integritätscheck und saubere Pfadverwaltung

set -e

echo "--- XAIGPUARC: Ubuntu/Debian/Mint Ultra-Fix für Intel ARC & iGPU ---"

# 1. System-Check
if [ ! -f /etc/debian_version ]; then
  echo "❌ Dieses Skript ist nur für Ubuntu, Debian oder Mint gedacht."
  exit 1
fi

ID_LIKE=$(grep "ID_LIKE=" /etc/os-release | cut -d= -f2 | tr -d '"')
OS_ID=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
CODENAME=$(lsb_release -cs)

echo "🚀 Erkannt: $OS_ID ($CODENAME)"

# ------------------------------------------------------------
# 2. Repo-Cleanup (Sorgt für einen sauberen Start)
# ------------------------------------------------------------
echo "🧹 Bereinige alte Repository-Einträge..."
sudo rm -f /etc/apt/sources.list.d/intel-graphics.list
sudo rm -f /etc/apt/sources.list.d/oneAPI.list

# ------------------------------------------------------------
# 3. Intel Graphics Repo Logik mit Deep-Check
# ------------------------------------------------------------
# Ubuntu nutzt oft spezifische Repos für die Versionen (jammy, noble, etc.)
INTEL_REPO_URL="https://repositories.intel.com/graphics/ubuntu"
INTEL_REPO_TEST="${INTEL_REPO_URL}/dists/${CODENAME}/InRelease"
INTEL_KEY_URL="https://repositories.intel.com/graphics/intel-graphics.key"

echo "ℹ️ Prüfe Intel Graphics Repo Integrität für $CODENAME..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L "$INTEL_REPO_TEST")

if [[ "$HTTP_CODE" == "200" ]]; then
    echo "✅ Intel Repo ist online – richte GPG und Sources ein."
    wget -qO - "$INTEL_KEY_URL" | sudo gpg --dearmor --yes -o /usr/share/keyrings/intel-graphics.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] $INTEL_REPO_URL $CODENAME main" | sudo tee /etc/apt/sources.list.d/intel-graphics.list
else
    echo "⚠️ Intel Repo Test fehlgeschlagen (Status: $HTTP_CODE)."
    echo "➡️ Nutze Standard-Ubuntu-Quellen (falls verfügbar)."
fi

# ------------------------------------------------------------
# 4. oneAPI Repository (Wichtig für MKL & Compiler)
# ------------------------------------------------------------
ONEAPI_KEY_URL="https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-GRAPHICS"
echo "🔑 Richte oneAPI Repository ein..."
wget -qO - "$ONEAPI_KEY_URL" | sudo gpg --dearmor --yes -o /usr/share/keyrings/oneapi-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list

sudo apt-get update

# ------------------------------------------------------------
# 5. Installation der Compute-Stack & Development Tools
# ------------------------------------------------------------
echo "📦 Installiere Treiber, Compute-Komponenten und oneAPI-Basekit..."

# Wir installieren gezielt die Kernkomponenten für GPU-Beschleunigung
sudo apt-get install -y \
    intel-level-zero-gpu level-zero \
    intel-opencl-icd \
    libigdgmm12 \
    intel-basekit \
    build-essential cmake git

# ------------------------------------------------------------
# 6. Berechtigungen & Shell-Integration
# ------------------------------------------------------------
echo "👥 Setze Berechtigungen für $USER (video/render)..."
sudo usermod -aG video "$USER" 2>/dev/null || true
sudo usermod -aG render "$USER" 2>/dev/null || true

SETVARS_PATH="/opt/intel/oneapi/setvars.sh"
if [ -f "$SETVARS_PATH" ]; then
    if ! grep -q "oneapi/setvars.sh" ~/.bashrc; then
        echo "📝 Trage OneAPI Pfade in ~/.bashrc ein..."
        echo "source $SETVARS_PATH > /dev/null 2>&1" >> ~/.bashrc
    fi
fi

# ------------------------------------------------------------
# 7. Übergabe an Hauptskript
# ------------------------------------------------------------
if [ -f "./XAIGPUARC.sh" ]; then
    chmod +x ./XAIGPUARC.sh
    echo "🚀 Starte Hauptskript XAIGPUARC.sh..."
    ./XAIGPUARC.sh "$@"
else
    echo "💡 Vorbereitung beendet. XAIGPUARC.sh wurde nicht im Ordner gefunden."
fi

echo ""
echo "--- ✅ SETUP ABGESCHLOSSEN ---"
echo "🌟 Ubuntu/Mint/Debian ist bereit für Intel ARC."
echo "🔄 BITTE JETZT DEN COMPUTER NEUSTARTEN, damit alle Rechte greifen."
