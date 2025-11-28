#!/usr/bin/env bash
# Best Practice Flags:
# -e: Exit on error
# -u: Exit on undefined variables
# -o pipefail: Exit if any command in a pipe fails
set -euo pipefail

# ==============================================================================
# AUTOMATED KERNEL BUILDER (WAYDROID SUPPORT)
# ==============================================================================
BRANCH="chromeos-6.6"
REPO_URL="https://chromium.googlesource.com/chromiumos/third_party/kernel"
MAKE_FLAGS="LLVM=1 LLVM_IAS=1"
OUTPUT_DIR="$(pwd)/out"

echo ">>> 🚀 Starting Automated Build..."
mkdir -p kernel
mkdir -p "$OUTPUT_DIR"
cd kernel

# 1. Source Management (Smart Update)
if [ ! -d ".git" ]; then
    echo ">>> 📦 Cloning ChromeOS Kernel (Latest $BRANCH)..."
    git clone --branch "$BRANCH" --depth 1 "$REPO_URL" .
else
    echo ">>> 🔄 Repo exists. Updating to latest version..."
    # We use fetch + checkout to avoid 'reset --hard' destroying local work 
    # unless absolutely necessary.
    git fetch --depth 1 origin "$BRANCH"
    git checkout FETCH_HEAD
fi

# 2. Configuration Strategy
echo ">>> ⚙️  Preparing configuration..."
if [ -f /proc/config.gz ]; then
    echo "✅ DETECTED RUNNING KERNEL CONFIG!"
    zcat /proc/config.gz > .config
else
    echo "⚠️  LIVE CONFIG NOT FOUND"
    echo "   Falling back to standard 'container-vm' config."
    # Ensure script exists before running
    if [ -f ./chromeos/scripts/prepareconfig ]; then
        CHROMEOS_KERNEL_FAMILY=termina ./chromeos/scripts/prepareconfig container-vm-x86_64
    else
        echo "❌ Error: prepareconfig script not found. Is the clone complete?"
        exit 1
    fi
fi

# 3. Update Config (Incremental Build Friendly)
# We run olddefconfig to align the .config with the current source
make $MAKE_FLAGS olddefconfig

# 4. Automate Waydroid Flags
echo ">>> 🤖 Enabling Waydroid Flags..."
./scripts/config --enable CONFIG_ANDROID
./scripts/config --enable CONFIG_ANDROID_BINDER_IPC
./scripts/config --enable CONFIG_ANDROID_BINDERFS
./scripts/config --enable CONFIG_ASHMEM 

# Refresh config
make $MAKE_FLAGS olddefconfig

# 5. Verification
echo ">>> 🔍 Verifying Config..."
# We allow this to pass (|| true) but we log it clearly
if grep -q "CONFIG_ANDROID=y" .config; then
    echo "   [OK] CONFIG_ANDROID enabled"
else
    echo "   [!!] WARNING: CONFIG_ANDROID not set correctly"
fi

# 6. Build
echo ">>> 🔨 Starting Compilation..."
echo "    (Using $(nproc) cores)"
time make -j"$(nproc)" $MAKE_FLAGS bzImage

# 7. Artifact Management
echo ">>> 📦 Copying kernel to output..."
cp arch/x86/boot/bzImage "$OUTPUT_DIR/bzImage"

echo "=================================================================="
echo "BUILD SUCCESSFUL!"
echo "Kernel available at: $OUTPUT_DIR/bzImage"
echo "=================================================================="