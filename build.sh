#!/usr/bin/env bash
# Best Practice Flags:
# -e: Exit on error
# -u: Exit on undefined variables
# -o pipefail: Exit if any command in a pipe fails
set -euo pipefail

# ==============================================================================
# CONFIGURATION (Overridable by Justfile)
# ==============================================================================
BRANCH="${BRANCH:-chromeos-6.6}"
REPO_URL="${REPO_URL:-https://chromium.googlesource.com/chromiumos/third_party/kernel}"
MAKE_FLAGS="${MAKE_FLAGS:-LLVM=1 LLVM_IAS=1}"
OUTPUT_DIR="$(pwd)/out"
KERNEL_DIR="$(pwd)/kernel"

# ==============================================================================
# TASKS
# ==============================================================================

task_setup() {
    echo ">>> 📦 [Setup] Checking Source Code..."
    mkdir -p "$KERNEL_DIR"
    mkdir -p "$OUTPUT_DIR"
    cd "$KERNEL_DIR"

    if [ ! -d ".git" ]; then
        echo "       Cloning ChromeOS Kernel ($BRANCH)..."
        git clone --branch "$BRANCH" --depth 1 "$REPO_URL" .
    else
        echo "       Repo exists. Fetching updates..."
        git fetch --depth 1 origin "$BRANCH"
        git checkout FETCH_HEAD
    fi
}

task_config() {
    echo ">>> ⚙️  [Config] Preparing Configuration..."
    cd "$KERNEL_DIR"
    
    # 1. Base Config
    if [ -f /proc/config.gz ]; then
        echo "       ✅ Detected running /proc/config.gz"
        zcat /proc/config.gz > .config
    else
        echo "       ⚠️  Live config not found. Using fallback 'container-vm'."
        if [ -f ../chromeos/scripts/prepareconfig ]; then
            CHROMEOS_KERNEL_FAMILY=termina ../chromeos/scripts/prepareconfig container-vm-x86_64
        else
            echo "       ❌ Error: prepareconfig script not found."
            exit 1
        fi
    fi

    # 2. Sync Old Config
    make $MAKE_FLAGS olddefconfig > /dev/null

    # 3. Apply Waydroid Patches
    echo "       🤖 Enabling Waydroid Flags..."
    ./scripts/config --enable CONFIG_ANDROID
    ./scripts/config --enable CONFIG_ANDROID_BINDER_IPC
    ./scripts/config --enable CONFIG_ANDROID_BINDERFS
    ./scripts/config --enable CONFIG_ASHMEM 

    # 4. Final Sync
    make $MAKE_FLAGS olddefconfig > /dev/null
    
    # 5. Verify
    if grep -q "CONFIG_ANDROID=y" .config; then
        echo "       [OK] CONFIG_ANDROID is enabled."
    else
        echo "       [!!] WARNING: Waydroid flags might be missing."
    fi
}

task_build() {
    echo ">>> 🔨 [Build] Compiling Kernel (bzImage)..."
    cd "$KERNEL_DIR"
    # We use 'time' to show duration.
    time make -j"$(nproc)" $MAKE_FLAGS bzImage
    
    echo ">>> 📦 [Artifact] Copying to output..."
    cp arch/x86/boot/bzImage "$OUTPUT_DIR/bzImage"
    echo "       Location: $OUTPUT_DIR/bzImage"
}

task_clean() {
    echo ">>> 🧹 [Clean] Cleaning build artifacts..."
    cd "$KERNEL_DIR" || exit 0
    make clean
}

task_menuconfig() {
    echo ">>> 🎨 [Menu] Launching Interactive Config..."
    cd "$KERNEL_DIR"
    make $MAKE_FLAGS menuconfig
}

# ==============================================================================
# DISPATCHER
# ==============================================================================
COMMAND="${1:-all}"

case "$COMMAND" in
    setup)      task_setup ;;
    config)     task_setup; task_config ;;
    build)      task_setup; task_config; task_build ;;
    clean)      task_clean ;;
    menuconfig) task_setup; task_menuconfig ;;
    all)        task_setup; task_config; task_build ;;
    *)          echo "Usage: $0 {setup|config|build|clean|menuconfig|all}"; exit 1 ;;
esac