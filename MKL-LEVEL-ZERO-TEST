#!/bin/bash
#=============================================================================
# XAIGPUARC_Universal_Check_v2.1.sh - "Der gnädige Vibe-Check"
#=============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' 

echo -e "${BLUE}=== XAIGPUARC Hardware-Check v2.1 (Freundes-Edition) ===${NC}\n"

# 1. OneAPI Check
echo -e "${YELLOW}[1/3] Initialisiere OneAPI...${NC}"
if [ -f "/opt/intel/oneapi/setvars.sh" ]; then
    # Wir nutzen '.' statt 'source' und laden alles
    . /opt/intel/oneapi/setvars.sh --force > /dev/null 2>&1
    echo -e "${GREEN}✅ OneAPI Umgebung geladen.${NC}"
else
    echo -e "${RED}❌ OneAPI Pfad fehlt.${NC}"
fi

# 2. Hardware Scan (Der einzig wahre Beweis)
echo -e "\n${YELLOW}[2/3] Suche Intel GPU (SYCL-Scan)...${NC}"
if command -v sycl-ls &> /dev/null; then
    SCAN=$(sycl-ls)
    if echo "$SCAN" | grep -q "gpu"; then
        echo -e "${GREEN}✅ GPU GEFUNDEN UND AKTIV!${NC}"
        echo "$SCAN" | grep "gpu" | sed 's/^/   /'
    else
        echo -e "${RED}❌ Keine GPU gefunden. Nur CPU vorhanden.${NC}"
    fi
else
    echo -e "${RED}❌ 'sycl-ls' nicht gefunden. Treiber-Installation prüfen.${NC}"
fi

# 3. Mathe-Check (MKL)
echo -e "\n${YELLOW}[3/3] Prüfe Mathe-Bibliotheken...${NC}"
# Wir schauen einfach, ob das Verzeichnis da ist, egal ob die Variable gerade "lebt"
if [ -d "/opt/intel/oneapi/mkl" ]; then
    echo -e "${GREEN}✅ MKL-Pralinen im Schrank gefunden!${NC}"
else
    echo -e "${RED}❌ MKL-Verzeichnis fehlt.${NC}"
fi

echo -e "\n${BLUE}=== Check beendet - Wenn GPU oben steht, kann es losgehen! ===${NC}"
