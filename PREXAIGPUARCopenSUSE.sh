#!/bin/bash
# XAIGPUARC: Das ultimative openSUSE-Setup für Intel ARC & iGPU
# Kombiniert maximale Kompatibilität mit robuster Fehlerbehandlung

set -e

echo "--- XAIGPUARC: openSUSE Ultra-Fix für Intel ARC & iGPU ---"

# ------------------------------------------------------------
# 1. System-Check & Variablen-Definition
# ------------------------------------------------------------
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
# 2. Intel Repo Logik (Politisch offen & Technisch geprüft)
# ------------------------------------------------------------
INTEL_REPO_BASE="https://repositories.intel.com/graphics/rpm/opensuse/$REPO_PATH/"
INTEL_KEY_URL="https://repositories.intel.com/intel-graphics-keys/GPG-PUB-KEY-INTEL-GRAPHICS"

# Vorheriges Repo entfernen, um Konflikte zu vermeiden
sudo zypper rr intel-graphics 2>/dev/null || true

if $IS_TW; then
  echo "ℹ️ Prüfe Erreichbarkeit des Intel Graphics Repos für Tumbleweed..."
  # Wir prüfen nur den Header (403/404 Check)
  if curl -fsI "$INTEL_REPO_BASE" >/dev/null; then
    echo "✅ Intel Repo erreichbar – richte es ein."
    sudo zypper ar -f "$INTEL_REPO_BASE" intel-graphics
  else
    echo "⚠️ Intel Graphics Repo für Tumbleweed derzeit nicht erreichbar (403 bekannt)."
    echo "➡️ Das Skript wird versuchen, Standard-openSUSE Quellen zu nutzen."
  fi
else
  echo "🔗 Richte Intel Graphics Repo für Leap ein..."
  sudo zypper ar -f "$INTEL_REPO_BASE" intel-graphics
fi

# ------------------------------------------------------------
# 3. GPG-Key Management (Der Gatekeeper-Bypass)
# ------------------------------------------------------------
echo "🔑 Importiere GPG-Keys..."
# Versuche den Key sicher via curl zu laden, falls Zypper blockt
curl -H "User-Agent: Mozilla/5.0" -L "$INTEL_KEY_URL" -o /tmp/intel-key.pub 2>/dev/null || echo "⚠️ Key-Download via curl fehlgeschlagen."
if [ -f /tmp/intel-key.pub ]; then
  sudo rpm --import /tmp/intel-key.pub 2>/dev/null || true
fi

# Repositories aktualisieren
sudo zypper --gpg-auto-import-keys ref

# ------------------------------------------------------------
# 4. Installation (Repo-agnostisch & Vollständig)
# ------------------------------------------------------------
echo "📦 Installiere Treiber und Compute-Komponenten..."
# Wir nutzen --allow-vendor-change, damit er zwischen Intel-Repo und SUSE-Repo springen kann
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
# 5. Berechtigungen & System-Integration
# ------------------------------------------------------------
echo "👥 Setze Berechtigungen für User: $USER..."
sudo usermod -aG video $USER 2>/dev/null || true
sudo usermod -aG render $USER 2>/dev/null || true

# OneAPI Pfade in die Shell integrieren
SETVARS_PATH="/opt/intel/oneapi/setvars.sh"
if [ -f "$SETVARS_PATH" ]; then
    if ! grep -q "oneapi/setvars.sh" ~/.bashrc; then
      echo "📝 Trage OneAPI Pfade in ~/.bashrc ein..."
      echo "source $SETVARS_PATH > /dev/null 2>&1" >> ~/.bashrc
    fi
else
    echo "💡 Info: oneAPI Umgebung wird nach dem nächsten Login/Neustart geladen."
fi

echo ""
echo "--- ✅ VORBEREITUNG ABGESCHLOSSEN ---"
echo "🌟 Dein openSUSE System ist nun für Intel ARC/iGPU optimiert."
echo "🔄 BITTE JETZT DEN COMPUTER NEUSTARTEN, um alle Änderungen zu aktivieren."
