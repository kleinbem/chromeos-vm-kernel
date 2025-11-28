set shell := ["bash", "-c"]

# Configuration
commit_hash := "28eab9a1f61e"
branch := "chromeos-6.6"
repo_url := "https://chromium.googlesource.com/chromiumos/third_party/kernel"

# SPLIT TOOLCHAIN FLAGS:
# HOSTCC = System Clang (finds headers like sys/types.h)
# CC     = Unwrapped Clang (compiles kernel code without strict wrapper flags)
# We still keep the 'nuclear' ignore flags just in case the kernel source itself is strict.
ignore_flags := "-Wno-error=unused-command-line-argument -Wno-error=address-of-packed-member -Wno-error=unused-but-set-variable -Wno-error=unused-const-variable"

# Default recipe
default:
    @just --list

# ==============================================================================
# 🚀 START AND FORGET
# ==============================================================================

lazy-build:
    @echo ">>> 📝 Logging output to 'build.log'..."
    @just _build-internal 2>&1 | tee build.log

_build-internal: setup config build
    @echo "=================================================================="
    @echo "☕ DONE. Kernel is ready at: kernel/arch/x86/boot/bzImage"
    @echo "=================================================================="

# ==============================================================================
# 🛠️ BUILD STEPS
# ==============================================================================

setup:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p kernel
    if [ ! -d "kernel/.git" ]; then
        echo ">>> 📦 Cloning kernel source..."
        git clone --branch {{branch}} --depth 500 {{repo_url}} kernel
    fi
    cd kernel
    echo ">>> 🔄 Checking out target commit {{commit_hash}}..."
    git cat-file -t {{commit_hash}} > /dev/null 2>&1 || git fetch --depth=2000 origin {{branch}}
    git checkout {{commit_hash}}

config:
    #!/usr/bin/env bash
    set -euo pipefail
    cd kernel
    
    echo ">>> ⚙️  Preparing configuration..."
    if [ -f /proc/config.gz ]; then
        zcat /proc/config.gz > .config
    else
        CHROMEOS_KERNEL_FAMILY=termina ./chromeos/scripts/prepareconfig container-vm-x86_64
    fi

    echo ">>> 🛠️  Applying Patches..."
    # Fix TPM variable
    if grep -q "int mapping_size;" include/linux/tpm_eventlog.h; then
        sed -i 's/int[[:space:]]*mapping_size;/int mapping_size __maybe_unused;/' include/linux/tpm_eventlog.h
    fi
    # Fix Kconfig newline
    sed -i -e '$a\' drivers/media/platform/mediatek/vcodec/Kconfig || true

    echo ">>> 🤖 Creating Waydroid Config Fragment..."
    cat <<EOF > waydroid.frag
    CONFIG_STAGING=y
    CONFIG_ANDROID=y
    CONFIG_ANDROID_BINDER_IPC=y
    CONFIG_ANDROID_BINDERFS=y
    CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"
    CONFIG_PSI=y
    CONFIG_DRM_I915=m
    CONFIG_DRM_AMDGPU=m
    # Memory / Linker Fixes
    CONFIG_DEBUG_INFO=n
    CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT=n
    CONFIG_DEBUG_INFO_BTF=n
    CONFIG_WERROR=n
    EOF

    echo ">>> 🧬 Merging configuration..."
    ./scripts/kconfig/merge_config.sh -m .config waydroid.frag
    
    # Use wrapped clang for config steps to ensure scripts compile
    make LLVM=1 LLVM_IAS=1 olddefconfig > /dev/null

build:
    #!/usr/bin/env bash
    set -euo pipefail
    cd kernel
    
    echo ">>> 🔨 Starting Compilation..."
    echo "    * Host Compiler   : Clang (Wrapped)"
    echo "    * Kernel Compiler : Clang (Unwrapped)"
    
    # THE MAGIC COMMAND
    # We use the environment variable CLANG_UNWRAPPED from flake.nix
    # This splits the toolchain so everyone is happy.
    time make -j$(nproc) \
        LLVM=1 \
        LLVM_IAS=1 \
        CC="$CLANG_UNWRAPPED" \
        HOSTCC=clang \
        LD=ld.lld \
        WERROR=0 \
        KCFLAGS={{ignore_flags}} \
        KAFLAGS={{ignore_flags}} \
        bzImage

    echo ">>> 📦 Artifact check..."
    if [ -f arch/x86/boot/bzImage ]; then
        mkdir -p ../out
        cp arch/x86/boot/bzImage ../out/bzImage
        echo "   ✅ Success! File: out/bzImage"
    else
        echo "   ❌ Error: bzImage was not created."
        exit 1
    fi

serve:
    python3 -m http.server 8000

clean:
    cd kernel && make clean

check-update:
    @git ls-remote {{repo_url}} refs/heads/{{branch}} | awk '{print $1}'
