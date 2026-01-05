#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print banner
echo -e "${CYAN}"
echo "========================================"
echo "  Infinity-X Build Script"
echo "  SukiSU Ultra + SUSFS + Auto Build"
echo "========================================"
echo -e "${NC}"

# Configuration variables
DEVICE="ingres"
ROM_DIR=$(pwd)
KERNEL_DIR="${ROM_DIR}/kernel/xiaomi/sm8450"
SUSFS_REPO="https://gitlab.com/simonpunk/susfs4ksu"
SUSFS_BRANCH="gki-android13-5.10"
SUSFS_DIR="/tmp/susfs4ksu"
KERNEL_CONFIG="arch/arm64/configs/vendor/ingres_GKI.config"

echo -e "${BLUE}[INFO]${NC} ROM Directory: ${YELLOW}${ROM_DIR}${NC}"
echo -e "${BLUE}[INFO]${NC} Kernel Directory: ${YELLOW}${KERNEL_DIR}${NC}"
echo -e "${BLUE}[INFO]${NC} Device: ${YELLOW}${DEVICE}${NC}\n"

# ============================================
# Step 1: Clone SUSFS Repository
# ============================================
echo -e "${CYAN}[1/7] Cloning SUSFS repository...${NC}"

if [ -d "$SUSFS_DIR" ]; then
    echo -e "${YELLOW}[WARN]${NC} SUSFS directory exists, removing old version..."
    rm -rf "$SUSFS_DIR"
fi

git clone "$SUSFS_REPO" -b "$SUSFS_BRANCH" "$SUSFS_DIR"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[✓]${NC} SUSFS repository cloned successfully\n"
else
    echo -e "${RED}[✗]${NC} Failed to clone SUSFS repository"
    exit 1
fi

export SUS="${SUSFS_DIR}/kernel_patches"
echo -e "${BLUE}[INFO]${NC} SUSFS patches path: ${YELLOW}${SUS}${NC}\n"

# ============================================
# Step 2: Navigate to Kernel Directory
# ============================================
echo -e "${CYAN}[2/7] Checking kernel directory...${NC}"

if [ ! -d "$KERNEL_DIR" ]; then
    echo -e "${RED}[✗]${NC} Kernel directory not found: ${KERNEL_DIR}"
    exit 1
fi

cd "$KERNEL_DIR"
echo -e "${GREEN}[✓]${NC} Kernel directory found\n"

# ============================================
# Step 3: Install SukiSU Ultra (builtin)
# ============================================
echo -e "${CYAN}[3/7] Installing SukiSU Ultra (builtin mode)...${NC}"

curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s builtin

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[✓]${NC} SukiSU Ultra installed successfully\n"
else
    echo -e "${RED}[✗]${NC} SukiSU installation failed"
    exit 1
fi

# ============================================
# Step 4: Apply SUSFS Kernel Patches
# ============================================
echo -e "${CYAN}[4/7] Applying SUSFS kernel patches...${NC}"

PATCH_FILE="$SUS/50_add_susfs_in_gki-android13-5.10.patch"

if [ ! -f "$PATCH_FILE" ]; then
    echo -e "${RED}[✗]${NC} SUSFS patch not found: ${PATCH_FILE}"
    exit 1
fi

patch -p1 < "$PATCH_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[✓]${NC} SUSFS patches applied successfully\n"
else
    echo -e "${RED}[✗]${NC} Failed to apply SUSFS patches"
    exit 1
fi

# ============================================
# Step 5: Copy SUSFS Files to Kernel
# ============================================
echo -e "${CYAN}[5/7] Copying SUSFS files to kernel...${NC}"

# Check if SUSFS source directories exist
if [ ! -d "$SUS/fs" ]; then
    echo -e "${RED}[✗]${NC} SUSFS fs directory not found: ${SUS}/fs"
    exit 1
fi

if [ ! -d "$SUS/include/linux" ]; then
    echo -e "${RED}[✗]${NC} SUSFS include directory not found: ${SUS}/include/linux"
    exit 1
fi

# Copy SUSFS filesystem files
cp "$SUS/fs/sus"* fs/
echo -e "${GREEN}[✓]${NC} Copied SUSFS fs files"

# Copy SUSFS header files
cp "$SUS/include/linux/sus"* include/linux/
echo -e "${GREEN}[✓]${NC} Copied SUSFS include files\n"

# ============================================
# Step 6: Enable KSU + SUSFS in Kernel Config
# ============================================
echo -e "${CYAN}[6/7] Configuring kernel config...${NC}"

if [ ! -f "$KERNEL_CONFIG" ]; then
    echo -e "${RED}[✗]${NC} Kernel config not found: ${KERNEL_CONFIG}"
    exit 1
fi

# Check if KSU + SUSFS already configured
if grep -q "CONFIG_KSU=y" "$KERNEL_CONFIG" && grep -q "CONFIG_KSU_SUSFS=y" "$KERNEL_CONFIG"; then
    echo -e "${YELLOW}[WARN]${NC} KSU + SUSFS already enabled in config"
else
    # Add KSU + SUSFS configuration
    echo "" >> "$KERNEL_CONFIG"
    echo "# KernelSU + SUSFS Configuration" >> "$KERNEL_CONFIG"
    echo "CONFIG_KSU=y" >> "$KERNEL_CONFIG"
    echo "CONFIG_KSU_SUSFS=y" >> "$KERNEL_CONFIG"
    echo -e "${GREEN}[✓]${NC} KSU + SUSFS enabled in kernel config"
fi

# Display configuration
echo -e "\n${BLUE}[INFO]${NC} Kernel configuration (last 10 lines):"
echo -e "${YELLOW}----------------------------------------${NC}"
tail -10 "$KERNEL_CONFIG"
echo -e "${YELLOW}----------------------------------------${NC}\n"

# Return to ROM directory
cd "$ROM_DIR"

echo -e "${GREEN}"
echo "========================================"
echo "  ✓ Kernel Setup Complete!"
echo "========================================"
echo -e "${NC}\n"

# ============================================
# Step 7: Setup Build Environment & Build
# ============================================
echo -e "${CYAN}[7/7] Starting ROM build...${NC}\n"

# Source build environment
echo -e "${BLUE}[INFO]${NC} Sourcing build environment..."
source build/envsetup.sh

# Setup signing keys (if available)
if [ -d "vendor/signing-keys" ]; then
    echo -e "${GREEN}[✓]${NC} Signing keys found, enabling release-keys build"
    export PRODUCT_DEFAULT_DEV_CERTIFICATE=vendor/signing-keys/releasekey
else
    echo -e "${YELLOW}[WARN]${NC} No signing keys found, building with test-keys"
fi

# Lunch target
echo -e "${BLUE}[INFO]${NC} Launching build target for ${YELLOW}${DEVICE}${NC}..."
lunch infinity_${DEVICE}-userdebug

# Start compilation
echo -e "\n${GREEN}"
echo "========================================"
echo "  Starting Full ROM Compilation"
echo "========================================"
echo -e "${NC}\n"

mka bacon

# Check build result
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}"
    echo "========================================"
    echo "  ✓ BUILD SUCCESS!"
    echo "========================================"
    echo -e "${NC}"
    echo -e "${GREEN}[SUCCESS]${NC} ROM compiled successfully for ${CYAN}${DEVICE}${NC}"
    echo -e "${BLUE}[INFO]${NC} Output files located in: ${YELLOW}out/target/product/${DEVICE}/${NC}\n"
    
    # Display build info
    echo -e "${CYAN}Build Configuration:${NC}"
    echo -e "  • Device: ${YELLOW}${DEVICE}${NC}"
    echo -e "  • KernelSU: ${GREEN}Enabled (builtin)${NC}"
    echo -e "  • SUSFS: ${GREEN}Enabled${NC}"
    if [ -d "vendor/signing-keys" ]; then
        echo -e "  • Signing: ${GREEN}release-keys${NC}"
    else
        echo -e "  • Signing: ${YELLOW}test-keys${NC}"
    fi
    echo ""
else
    echo -e "\n${RED}"
    echo "========================================"
    echo "  ✗ BUILD FAILED!"
    echo "========================================"
    echo -e "${NC}"
    echo -e "${RED}[ERROR]${NC} ROM compilation failed"
    exit 1
fi
