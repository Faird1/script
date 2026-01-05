#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "================================================"
echo "  Infinity-X Full Build Script"
echo "  Cleanup → Sync → SukiSU+SUSFS → Build"
echo "================================================"
echo -e "${NC}\n"

# Configuration
DEVICE="ingres"
ROM_DIR=$(pwd)
KERNEL_DIR="${ROM_DIR}/kernel/xiaomi/sm8450"
SUSFS_REPO="https://gitlab.com/simonpunk/susfs4ksu"
SUSFS_BRANCH="gki-android13-5.10"
SUSFS_DIR="/tmp/susfs4ksu"
KERNEL_CONFIG="arch/arm64/configs/vendor/ingres_GKI.config"

echo -e "${BLUE}[INFO]${NC} Working directory: ${YELLOW}${ROM_DIR}${NC}"
echo -e "${BLUE}[INFO]${NC} Device: ${YELLOW}${DEVICE}${NC}\n"

# ============================================
# Step 1: Cleanup Old Directories
# ============================================
echo -e "${CYAN}[1/8] Cleaning up old directories...${NC}"

# Remove old local manifests
if [ -d ".repo/local_manifests" ]; then
    echo -e "${YELLOW}[CLEAN]${NC} Removing old local manifests..."
    rm -rf .repo/local_manifests
fi

# Remove old device tree
if [ -d "device/xiaomi/ingres" ]; then
    echo -e "${YELLOW}[CLEAN]${NC} Removing old device tree..."
    rm -rf device/xiaomi/ingres
    rm -rf device/xiaomi/sm8450-common
fi

# Remove old kernel
if [ -d "kernel/xiaomi/sm8450" ]; then
    echo -e "${YELLOW}[CLEAN]${NC} Removing old kernel..."
    rm -rf kernel/xiaomi/sm8450
    rm -rf kernel/xiaomi/sm8450-modules
    rm -rf kernel/xiaomi/sm8450-devicetrees
fi

# Remove old vendor
if [ -d "vendor/xiaomi/ingres" ]; then
    echo -e "${YELLOW}[CLEAN]${NC} Removing old vendor files..."
    rm -rf vendor/xiaomi/ingres
    rm -rf vendor/xiaomi/sm8450-common
fi

# Remove old SUSFS
if [ -d "$SUSFS_DIR" ]; then
    echo -e "${YELLOW}[CLEAN]${NC} Removing old SUSFS..."
    rm -rf "$SUSFS_DIR"
fi

# Clean out directory (optional)
if [ -d "out" ]; then
    echo -e "${YELLOW}[CLEAN]${NC} Cleaning out directory..."
    rm -rf out
fi

echo -e "${GREEN}[✓]${NC} Cleanup completed\n"

# ============================================
# Step 2: Sync Repository
# ============================================
echo -e "${CYAN}[2/8] Syncing repository...${NC}"

echo -e "${BLUE}[INFO]${NC} Initializing Infinity-X repo"
repo init -u https://github.com/ProjectInfinity-X/manifest -b 16 --git-lfs

# Clone local manifests
echo -e "${BLUE}[INFO]${NC} Cloning local manifests..."
git clone https://github.com/Faird1/infinityx-local-manifest.git --depth 1 .repo/local_manifests

# Repo sync
echo -e "${BLUE}[INFO]${NC} Running repo sync..."
/opt/crave/resync.sh

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[✓]${NC} Repository synced successfully\n"
else
    echo -e "${RED}[✗]${NC} Repo sync failed"
    exit 1
fi

# ============================================
# Step 3: Clone SUSFS Repository
# ============================================
echo -e "${CYAN}[3/8] Cloning SUSFS repository...${NC}"

git clone "$SUSFS_REPO" -b "$SUSFS_BRANCH" "$SUSFS_DIR"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[✓]${NC} SUSFS cloned successfully\n"
else
    echo -e "${RED}[✗]${NC} SUSFS clone failed"
    exit 1
fi

export SUS="${SUSFS_DIR}/kernel_patches"

# ============================================
# Step 4: Navigate to Kernel Directory
# ============================================
echo -e "${CYAN}[4/8] Checking kernel directory...${NC}"

if [ ! -d "$KERNEL_DIR" ]; then
    echo -e "${RED}[✗]${NC} Kernel directory not found: ${KERNEL_DIR}"
    exit 1
fi

cd "$KERNEL_DIR"
echo -e "${GREEN}[✓]${NC} Kernel directory found\n"

# ============================================
# Step 5: Install SukiSU Ultra
# ============================================
echo -e "${CYAN}[5/8] Installing SukiSU Ultra (builtin)...${NC}"

curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s builtin

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[✓]${NC} SukiSU Ultra installed\n"
else
    echo -e "${RED}[✗]${NC} SukiSU installation failed"
    exit 1
fi

# ============================================
# Step 6: Apply SUSFS Patches
# ============================================
echo -e "${CYAN}[6/8] Applying SUSFS patches...${NC}"

PATCH_FILE="$SUS/50_add_susfs_in_gki-android13-5.10.patch"

if [ ! -f "$PATCH_FILE" ]; then
    echo -e "${RED}[✗]${NC} SUSFS patch not found"
    exit 1
fi

patch -p1 < "$PATCH_FILE"
cp "$SUS/fs/sus"* fs/
cp "$SUS/include/linux/sus"* include/linux/

# Enable KSU + SUSFS in config
if ! grep -q "CONFIG_KSU=y" "$KERNEL_CONFIG"; then
    echo "" >> "$KERNEL_CONFIG"
    echo "# KernelSU + SUSFS" >> "$KERNEL_CONFIG"
    echo "CONFIG_KSU=y" >> "$KERNEL_CONFIG"
    echo "CONFIG_KSU_SUSFS=y" >> "$KERNEL_CONFIG"
fi

echo -e "${GREEN}[✓]${NC} SUSFS configured\n"
echo -e "${BLUE}[INFO]${NC} Config preview:"
tail -5 "$KERNEL_CONFIG"
echo ""

cd "$ROM_DIR"

# ============================================
# Step 7: Setup Build Environment
# ============================================
echo -e "${CYAN}[7/8] Setting up build environment...${NC}"

export BUILD_USERNAME=Faird1
export BUILD_HOSTNAME=crave

source build/envsetup.sh

# Check for signing keys
if [ -d "vendor/signing-keys" ]; then
    echo -e "${GREEN}[✓]${NC} Signing keys found"
    export PRODUCT_DEFAULT_DEV_CERTIFICATE=vendor/signing-keys/releasekey
else
    echo -e "${YELLOW}[WARN]${NC} No signing keys (test-keys will be used)"
fi

# Lunch target
lunch infinity_${DEVICE}-userdebug

echo -e "${GREEN}[✓]${NC} Build environment ready\n"

# ============================================
# Step 8: Start Compilation
# ============================================
echo -e "${CYAN}[8/8] Starting ROM compilation...${NC}\n"
echo -e "${GREEN}"
echo "================================================"
echo "  BUILDING ROM - THIS WILL TAKE A WHILE"
echo "================================================"
echo -e "${NC}\n"

mka bacon

# Check result
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}"
    echo "================================================"
    echo "  ✓✓✓ BUILD SUCCESSFUL ✓✓✓"
    echo "================================================"
    echo -e "${NC}\n"
    
    echo -e "${GREEN}[SUCCESS]${NC} ROM built successfully!"
    echo -e "${BLUE}[INFO]${NC} Output: ${YELLOW}out/target/product/${DEVICE}/${NC}\n"
    
    # Show ROM info
    echo -e "${CYAN}Build Summary:${NC}"
    echo -e "  Device: ${YELLOW}${DEVICE}${NC}"
    echo -e "  KernelSU: ${GREEN}Enabled (builtin)${NC}"
    echo -e "  SUSFS: ${GREEN}Enabled${NC}"
    if [ -d "vendor/signing-keys" ]; then
        echo -e "  Signing: ${GREEN}release-keys${NC}"
    else
        echo -e "  Signing: ${YELLOW}test-keys${NC}"
    fi
    
    # List output files
    echo -e "\n${CYAN}Output files:${NC}"
    ls -lh out/target/product/${DEVICE}/*.zip 2>/dev/null || echo "  (No ZIP files found)"
    echo ""
    
else
    echo -e "\n${RED}"
    echo "================================================"
    echo "  ✗✗✗ BUILD FAILED ✗✗✗"
    echo "================================================"
    echo -e "${NC}\n"
    echo -e "${RED}[ERROR]${NC} Build failed! Check logs above."
    exit 1
fi
