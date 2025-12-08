#!/bin/bash

# ================================
# 1. Clean old manifests
# ================================
echo '>>> Cleaning old data'
rm -rf .repo/local_manifests
rm -rf .repo/manifests .repo/manifest.xml
rm -rf device/xiaomi/ingres 
rm -rf device/xiaomi/sm8450-common
rm -rf kernel/xiaomi/sm8450
rm -rf vendor/xiaomi/ingres 
rm -rf vendor/xiaomi/sm8450-common
rm -rf out/target/product/ingres
rm -rf kernel/xiaomi/sm8450-modules
rm -rf kernel/xiaomi/sm8450-devicetrees
rm -rf packages/apps/GameKeys
rm -rf device/lineage/sepolicy
rm -rf external/libevdev
rm -rf external/rust/android-crates-io/crates/evdev-rs
rm -rf external/rust/android-crates-io/crates/evdev-sys
rm -rf hardware/xiaomi
rm -rf hardware/lineage/interfaces

# ================================
# 2. Initialize Repo (Infinity-X Android 16)
# ================================
echo '>>> Initializing Infinity-X repo'
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault

# ================================
# 3. Clone local manifests
# ================================
echo '>>> Cloning local manifests'
git clone https://github.com/Faird1/infinityx-local-manifest.git --depth 1 .repo/local_manifests

# ================================
# 4. Sync sources
# ================================
echo '>>> Syncing sources'
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --prune --optimized-fetch

# Если /opt/crave/resync.sh существует, запустить его тоже
if [ -f /opt/crave/resync.sh ]; then
    echo '>>> Running crave resync script'
    /opt/crave/resync.sh
fi

# ================================
# 5. Verify device tree
# ================================
echo '>>> Verifying device tree'
if [ ! -f "device/xiaomi/ingres/AndroidProducts.mk" ]; then
    echo "ERROR: AndroidProducts.mk not found!"
    exit 1
fi

if [ ! -f "device/xiaomi/ingres/infinity_ingres.mk" ]; then
    echo "ERROR: infinity_ingres.mk not found!"
    exit 1
fi

# ================================
# 6. Setup build environment
# ================================
echo '>>> Setting up build environment'
. build/envsetup.sh

export BUILD_USERNAME=faridd
export BUILD_HOSTNAME=crave
export TZ=Europe/Oslo
export USE_CCACHE=1
export CCACHE_EXEC=$(which ccache)

# ================================
# 7. Build
# ================================
echo '>>> Starting build: infinity_ingres-userdebug'

lunch infinity_ingres-userdebug || {
    echo "ERROR: lunch failed!"
    echo "Available products:"
    lunch
    exit 1
}

echo '>>> Cleaning previous build artifacts'
make installclean

echo '>>> Building ROM...'
mka bacon# ================================
# 4. Sync sources
# ================================
echo '>>> Syncing sources via /opt/crave/resync.sh'
/opt/crave/resync.sh

# ================================
# 5. Setup build environment
# ================================
echo '>>> Setting up build environment'
. build/envsetup.sh

export BUILD_USERNAME=faridd
export BUILD_HOSTNAME=crave
export TZ=Europe/Oslo
export USE_CCACHE=1

# ================================
# 6. Build
# ================================
echo '>>> Starting build: infinity_ingres-userdebug'

lunch infinity_ingres-userdebug

echo '>>> Cleaning previous build artifacts'
make installclean

echo '>>> Building ROM...'
mka bacon
