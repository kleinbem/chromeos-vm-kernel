set shell := ["bash", "-c"]

# ==============================================================================
# ⚙️ CONFIGURATION
# ==============================================================================

# Repo Settings
branch := env_var_or_default("KERNEL_BRANCH", "chromeos-6.6")
repo_url := env_var_or_default("KERNEL_REPO", "https://chromium.googlesource.com/chromiumos/third_party/kernel")

# Modular Features
# Default features. Can be overridden: just features="waydroid debug" build
features := "security kvm-guest waydroid gpu optimization"

# Compiler Flags
ignore_flags := "-Wno-error=unused-command-line-argument -Wno-error=address-of-packed-member -Wno-error=unused-but-set-variable -Wno-error=unused-const-variable"

# ==============================================================================
# 🚀 MAIN TASKS
# ==============================================================================

default:
    @just --list

build: preflight setup config compile artifacts
    @echo "=================================================================="
    @echo "☕ DONE. Kernel is ready."
    @echo "=================================================================="

# ==============================================================================
# 🛠️ STEPS
# ==============================================================================

preflight:
    @echo ">>> 🔍 Checking environment..."
    @which git > /dev/null || (echo "❌ Git missing"; exit 1)
    @which clang > /dev/null || (echo "❌ Clang missing"; exit 1)
    @[ -n "$CLANG_UNWRAPPED" ] || (echo "❌ CLANG_UNWRAPPED not set. Please run 'nix develop' first."; exit 1)

setup:
    @mkdir -p kernel
    @if [ ! -d "kernel/.git" ]; then \
        echo ">>> 📦 Cloning kernel source ({{branch}})..."; \
        git clone --branch {{branch}} --depth 1 {{repo_url}} kernel; \
    else \
        echo ">>> 🔄 Updating kernel source..."; \
        cd kernel && git fetch --depth 1 origin {{branch}} && git checkout FETCH_HEAD; \
    fi

config:
    #!/usr/bin/env bash
    set -euo pipefail
    
    KERNEL_ROOT="kernel"

    echo ">>> ⚙️  Preparing configuration..."
    if [ -f /proc/config.gz ]; then
        zcat /proc/config.gz > $KERNEL_ROOT/.config
    else
        make defconfig -C $KERNEL_ROOT
    fi
    
    # ---------------------------------------------------------
    # ⚠️ CONFLICT CHECK (Remains the same)
    # ---------------------------------------------------------
    if [[ "{{features}}" == *"optimization"* ]] && [[ "{{features}}" == *"debug"* ]]; then
        echo " "
        echo "🛑 CONFLICT DETECTED: You have requested both 'optimization' and 'debug'."
        echo "   - 'optimization' disables symbols (fast, small)."
        echo "   - 'debug' enables symbols (slow, huge)."
        echo "   -> The last one in the list will win, but this is likely a mistake."
        echo " "
        read -p "Press [Enter] to continue anyway, or [Ctrl+C] to abort..." wait_for_user
    fi


    echo ">>> 🧩 Applying Features: {{features}}..."
    for feature in {{features}}; do
        frag="features/${feature}.config" # Path is correct from project root
        if [ -f "$frag" ]; then
            echo "    + Merging $frag"
            # Command run from root, targets files relative to root
            ./kernel/scripts/kconfig/merge_config.sh -m -O $KERNEL_ROOT $KERNEL_ROOT/.config "$frag"
        else
            echo "    ⚠️ Warning: Feature config '$frag' not found!"
        fi
    done
    
# Define the compiler wrapper
# If ccache is installed, use it. Otherwise, just use the raw compiler.
cc_wrapper := shell("command -v ccache >/dev/null && echo 'ccache ' || echo ''")

compile:
    @echo ">>> 🔨 Patching & Compiling..."
    @./scripts/fix_realmode.sh
    # We explicitly set CCACHE_DIR to a local folder so GitHub can cache it easily
    @export CCACHE_DIR=$(pwd)/.ccache && \
     cd kernel && time make -j$(nproc) \
        LLVM=1 \
        LLVM_IAS=1 \
        CC="{{cc_wrapper}}$CLANG_UNWRAPPED" \
        HOSTCC="{{cc_wrapper}}clang" \
        LD=ld.lld \
        KCFLAGS={{ignore_flags}} \
        KAFLAGS={{ignore_flags}} \
        bzImage modules

artifacts:
    @if [ -f kernel/arch/x86/boot/bzImage ]; then \
        mkdir -p out; \
        cp kernel/arch/x86/boot/bzImage out/bzImage; \
        echo "   ✅ Success! File available at: out/bzImage"; \
    else \
        echo "   ❌ Error: bzImage was not created."; \
        exit 1; \
    fi

clean:
    cd kernel && make clean

menuconfig:
    cd kernel && make LLVM=1 LLVM_IAS=1 menuconfig
