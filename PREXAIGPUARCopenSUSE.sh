#!/bin/bash
# XAIGPUARC: openSUSE Setup für Intel ARC & iGPU
# Fokus: Ausfallsicherheit, Vendor-Transparenz und saubere Repo-Verwaltung

set -e

echo "--- XAIGPUARC: openSUSE Ultra-Fix für Intel ARC & iGPU ---"

# 1. System-Check
. /etc/os-release
if [[ "$ID" != "opensuse-leap" && "$ID" != "opensuse-tumbleweed" ]]; then
  echo "❌ Dieses Skript ist nur für openSUSE gedacht."
  exit 1
fi

IS_TW=false
REPO_PATH="leap/15.6"
if [[ "$ID" == "opensuse-tumbleweed" ]]; then
  IS_TW=true
  REPO_PATH="tumbleweed"
  echo "🚀 Erkannt: openSUSE Tumbleweed"
else
  echo "🌲 Erkannt: openSUSE Leap"
fi

# ------------------------------------------------------------
# 2. Repo-Cleanup (Für "vermurkste" Systeme)
# ------------------------------------------------------------
echo "🧹 Bereinige alte Repository-Einträge..."
# Sucht nach "intel" (case-insensitive) in der Liste und entfernt das spezifische Repo
sudo zypper lr | grep -qi intel && sudo zypper rr intel-graphics 2>/dev/null || true

# ------------------------------------------------------------
# 3. Intel Repo Logik mit Deep-Check
# ------------------------------------------------------------
INTEL_REPO_BASE="https://repositories.intel.com/graphics/rpm/opensuse/$REPO_PATH/"
INTEL_REPO_TEST="${INTEL_REPO_BASE}repodata/repomd.xml"
INTEL_KEY_URL="https://repositories.intel.com/intel-graphics-keys/GPG-PUB-KEY-INTEL-GRAPHICS"

echo "ℹ️ Prüfe Intel Graphics Repo Integrität..."
# Wir prüfen direkt auf die repomd.xml und speichern den HTTP Status
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "User-Agent: Mozilla/5.0" "$INTEL_REPO_TEST")

if [[ "$HTTP_CODE" == "200" ]]; then
  echo "✅ Intel Repo (HTTP 200) ist online und valide – aktiviere es."
  sudo zypper ar -f "$INTEL_REPO_BASE" intel-graphics
else
  echo "⚠️ Intel Repo Test fehlgeschlagen (Status: $HTTP_CODE)."
  echo "➡️ Nutze Fallback auf openSUSE Standard-Graphics-Quellen."
fi

# ------------------------------------------------------------
# 4. GPG-Key & Refresh
# ------------------------------------------------------------
echo "🔑 Importiere GPG-Keys (Gatekeeper-Bypass)..."
curl -H "User-Agent: Mozilla/5.0" -L "$INTEL_KEY_URL" -o /tmp/intel-key.pub 2>/dev/null || true
if [ -f /tmp/intel-key.pub ]; then
  sudo rpm --import /tmp/intel-key.pub 2>/dev/null || true
fi

sudo zypper --gpg-auto-import-keys ref

# ------------------------------------------------------------
# 5. Installation mit Vendor-Log
# ------------------------------------------------------------
echo "ℹ️ Erlaube Vendor-Wechsel zwischen openSUSE und Intel Repos (gewollt)."
echo "📦 Installiere Treiber und Compute-Komponenten..."

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

# ------------------------------------------------------------
# 6. Berechtigungen & Shell-Integration
# ------------------------------------------------------------
echo "👥 Setze Berechtigungen für $USER..."
sudo usermod -aG video $USER 2>/dev/null || true
sudo usermod -aG render $USER 2>/dev/null || true

SETVARS_PATH="/opt/intel/oneapi/setvars.sh"
if [ -f "$SETVARS_PATH" ]; then
    if ! grep -q "oneapi/setvars.sh" ~/.bashrc; then
      echo "📝 Trage OneAPI Pfade in ~/.bashrc ein..."
      echo "source $SETVARS_PATH > /dev/null 2>&1" >> ~/.bashrc
    fi
fi

echo ""
echo "--- ✅ SETUP ABGESCHLOSSEN ---"
echo "🌟 Das System wurde erfolgreich konfiguriert."
echo "🔄 BITTE JETZT DEN COMPUTER NEUSTARTEN."
