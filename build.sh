#!/usr/bin/env bash
set -e

# ==============================================================================
# CONFIGURATION
# ==============================================================================
# The exact commit hash from your current kernel version (6.6.99-08726-g28eab9a1f61e)
# This ensures we are building the exact same source code version you are running.
COMMIT_HASH="28eab9a1f61e"
BRANCH="chromeos-6.6"
REPO_URL="https://chromium.googlesource.com/chromiumos/third_party/kernel"

# Build flags for LLVM (Standard for ChromeOS)
MAKE_FLAGS="LLVM=1 LLVM_IAS=1"

echo ">>> Setting up build directory..."
mkdir -p kernel
cd kernel

# 1. Clone Source (Only if missing)
if [ ! -d ".git" ]; then
    echo ">>> Cloning ChromeOS Kernel ($BRANCH)..."
    echo "    (This is large ~2GB, please wait)"
    git clone --branch $BRANCH --depth 1 $REPO_URL .
    # Unshallow to get specific commit history if needed, but depth 1 usually works 
    # if the branch head is close to your commit. If checkout fails, we fetch more.
    if ! git cat-file -t $COMMIT_HASH > /dev/null 2>&1; then
         echo ">>> Fetching full history to find specific commit..."
         git fetch --unshallow || git fetch --all
    fi
fi

# 2. Checkout Exact Commit
echo ">>> Checking out commit: $COMMIT_HASH"
git checkout $COMMIT_HASH

# 3. Configuration Strategy
echo ">>> preparing configuration..."

if [ -f /proc/config.gz ]; then
    echo "✅ DETECTED RUNNING KERNEL CONFIG!"
    echo "    Extracting /proc/config.gz to match your current system exactly."
    zcat /proc/config.gz > .config
else
    echo "⚠️  LIVE CONFIG NOT FOUND (Are you building on another machine?)"
    echo "    Falling back to standard 'container-vm' config."
    CHROMEOS_KERNEL_FAMILY=termina ./chromeos/scripts/prepareconfig container-vm-x86_64
fi

# 4. Clean & Prepare
echo ">>> Cleaning..."
make clean
# Updates .config to ensure it works with our current compiler version
make $MAKE_FLAGS olddefconfig

# 5. Interactive Menu (The Important Part!)
echo ""
echo "=================================================================="
echo " STOP! NOW WE ENABLE WAYDROID."
echo "=================================================================="
echo "I will launch the menu. You must enable these options:"
echo " 1. Device Drivers -> Android -> Android Drivers [*]"
echo " 2. Device Drivers -> Android -> Android Binder IPC Driver [*] (Built-in)"
echo " 3. Device Drivers -> Android -> Android BinderFS filesystem [*] (Built-in)"
echo "=================================================================="
read -p "Press Enter to launch menuconfig..."
make $MAKE_FLAGS menuconfig

# 6. Build
echo ">>> Building Kernel (bzImage)..."
make -j$(nproc) $MAKE_FLAGS bzImage

echo "=================================================================="
echo "SUCCESS!"
echo "Kernel location: $(pwd)/arch/x86/boot/bzImage"
echo "=================================================================="
