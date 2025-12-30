No Support unti l 2025 30.12.2025 /// SORRY
#!/bin/bash
# XAIGPUARC v1.1 | 2025-12-29
# Fokus: openSUSE Tumbleweed/Leap Intel Compute Setup
# Änderungen: Paketnamen-Mapping für openSUSE korrigiert, GPG-Handling verbessert.

set -e

echo "--- XAIGPUARC v1.1: openSUSE Ultra-Fix [Intel ARC & iGPU] ---"
echo "Datum: 29.12.2025 | Version: 1.1 (Tumbleweed-Optimiert)"

# 1. System-Check
. /etc/os-release
if [[ "$ID" != "opensuse-leap" && "$ID" != "opensuse-tumbleweed" ]]; then
  echo "❌ Dieses Skript ist nur für openSUSE gedacht."
  exit 1
fi

# ------------------------------------------------------------
# 2. Repo-Logik & Intel-Fix
# ------------------------------------------------------------
echo "🧹 Bereinige alte Intel-Reste..."
sudo zypper rr intel-graphics 2>/dev/null || true

# Bestimme Pfad (Leap vs Tumbleweed)
REPO_PATH="leap/15.6"
[[ "$ID" == "opensuse-tumbleweed" ]] && REPO_PATH="tumbleweed"

INTEL_REPO_BASE="https://repositories.intel.com/graphics/rpm/opensuse/$REPO_PATH/"
INTEL_KEY_URL="https://repositories.intel.com/intel-graphics-keys/GPG-PUB-KEY-INTEL-GRAPHICS"

# Versuch das Repo einzubinden, aber mit Ignorieren von Fehlern falls 403
echo "ℹ️ Versuche Intel Repo einzubinden..."
sudo zypper ar -f "$INTEL_REPO_BASE" intel-graphics 2>/dev/null || echo "⚠️ Direktes Intel-Repo nicht erreichbar (403), nutze Standard-Quellen."

# GPG-Key Import
curl -sL "$INTEL_KEY_URL" | sudo rpm --import - 2>/dev/null || true
sudo zypper --gpg-auto-import-keys ref

# ------------------------------------------------------------
# 3. Installation mit korrigierten Paketnamen (openSUSE Style)
# ------------------------------------------------------------
echo "📦 Installiere Compute-Stack (openSUSE Namensschema)..."

# Wir nutzen hier die Namen, die openSUSE tatsächlich in den OSS/Update Repos führt
sudo zypper --non-interactive install -y --no-recommends --allow-vendor-change \
  intel-opencl \
  level-zero-gpu \
  libigdgmm12 \
  gmmlib-devel \
  intel-oneapi-runtime-dpcpp-cpp \
  intel-oneapi-compiler-dpcpp-cpp \
  intel-oneapi-runtime-mkl \
  intel-oneapi-mkl-devel

# ------------------------------------------------------------
# 4. Finalisierung & Gruppen
# ------------------------------------------------------------
echo "👥 Berechtigungen verifizieren..."
sudo usermod -aG video $USER
sudo usermod -aG render $USER

echo ""
echo "--- ✅ SETUP V1.1 ABGESCHLOSSEN ---"
echo "Versionshinweis: Falls 'intel-opencl' und 'level-zero-gpu' bereits installiert sind,"
echo "und clinfo/sycl-ls die Karte trotzdem nicht sehen, prüfen Sie das Kernel-Modul 'i915' oder 'xe'."
echo "🔄 BITTE SYSTEM NEUSTARTEN."
