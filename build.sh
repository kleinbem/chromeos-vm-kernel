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
MAKE_FLAGS="LLVM=1 LLVM_IAS=1 WERROR=0"
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
    # This is handled by Justfile now, but we keep this as a fallback/helper
    echo ">>> ⚙️  Config should be run via 'just config'"
}

task_build() {
    echo ">>> 🔨 [Build] Compiling Kernel (bzImage)..."
    cd "$KERNEL_DIR"

    # -------------------------------------------------------------------------
    # CRITICAL PATCH: Real Mode Makefile (Fixes 'header.o' / nostdlibinc crash)
    # -------------------------------------------------------------------------
    REALMODE_MK="arch/x86/realmode/rm/Makefile"
    if [ -f "$REALMODE_MK" ]; then
        echo "       🩹 Patching Real Mode Makefile ($REALMODE_MK)..."
        # Remove any existing -Werror
        sed -i 's/-Werror//g' "$REALMODE_MK"
        
        # Force append the ignore flag for BOTH C and Assembly (AFLAGS)
        # We check if we already added it to avoid duplication
        if ! grep -q "unused-command-line-argument" "$REALMODE_MK"; then
             echo "KBUILD_CFLAGS += -Wno-error=unused-command-line-argument" >> "$REALMODE_MK"
             echo "KBUILD_AFLAGS += -Wno-error=unused-command-line-argument" >> "$REALMODE_MK"
        fi
    fi

    # -------------------------------------------------------------------------
    # GLOBAL FLAGS: Disable strictness
    # -------------------------------------------------------------------------
    IGNORE_FLAGS="-Wno-error=unused-command-line-argument -Wno-error=address-of-packed-member -Wno-error=unused-but-set-variable -Wno-error=unused-const-variable"

    echo "       🚀 Starting make..."
    time make -j"$(nproc)" \
        $MAKE_FLAGS \
        KCFLAGS="$IGNORE_FLAGS" \
        KAFLAGS="$IGNORE_FLAGS" \
        CPPFLAGS="$IGNORE_FLAGS" \
        KCPPFLAGS="$IGNORE_FLAGS" \
        bzImage
    
    if [ -f arch/x86/boot/bzImage ]; then
        echo ">>> 📦 [Artifact] Copying to output..."
        cp arch/x86/boot/bzImage "$OUTPUT_DIR/bzImage"
        echo "       Location: $OUTPUT_DIR/bzImage"
        echo "       ✅ BUILD SUCCESSFUL"
    else
        echo "       ❌ Error: bzImage not found at expected location."
        exit 1
    fi
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
    build)      task_setup; task_build ;; # Skipped config here as it's done in Justfile
    clean)      task_clean ;;
    menuconfig) task_setup; task_menuconfig ;;
    all)        task_setup; task_config; task_build ;;
    *)          echo "Usage: $0 {setup|config|build|clean|menuconfig|all}"; exit 1 ;;
esac
