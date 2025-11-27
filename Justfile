set shell := ["bash", "-c"]

# Configuration
commit_hash := "28eab9a1f61e"
branch := "chromeos-6.6"
repo_url := "https://chromium.googlesource.com/chromiumos/third_party/kernel"
make_flags := "LLVM=1 LLVM_IAS=1"

# Default: List available recipes
default:
    @just --list

# 1. Setup: Clone repo and checkout the exact commit
setup:
    mkdir -p kernel
    if [ ! -d "kernel/.git" ]; then \
        echo ">>> Cloning kernel source..."; \
        git clone --branch {{branch}} --depth 1 {{repo_url}} kernel; \
    fi
    cd kernel && echo ">>> Checking out commit {{commit_hash}}..."
    # Fetch specific commit if depth=1 missed it
    cd kernel && (git cat-file -t {{commit_hash}} > /dev/null 2>&1 || git fetch --depth=100 origin {{commit_hash}} || git fetch --unshallow)
    cd kernel && git checkout {{commit_hash}}

# 2. Config: Extract LIVE config from running system (or fallback to default)
config:
    cd kernel && if [ -f /proc/config.gz ]; then \
        echo "✅ FOUND LIVE CONFIG! Extracting to .config..."; \
        zcat /proc/config.gz > .config; \
    else \
        echo "⚠️  Live config not found. Using default container-vm config..."; \
        CHROMEOS_KERNEL_FAMILY=termina ./chromeos/scripts/prepareconfig container-vm-x86_64; \
    fi
    # Update config for current compiler version
    cd kernel && make {{make_flags}} olddefconfig

# 3. Interactive: Open the menu to enable Waydroid/Binder
menuconfig:
    @echo ">>> Opening Menu. Go to: Device Drivers -> Android -> Enable Binder IPC & BinderFS (Built-in)"
    cd kernel && make {{make_flags}} menuconfig

# 4. Build: Compile the kernel image
build:
    echo ">>> Building bzImage (this will take time)..."
    cd kernel && make -j$(nproc) {{make_flags}} bzImage
    @echo "✅ Build Complete!"
    @echo "Kernel location: kernel/arch/x86/boot/bzImage"

# 5. Serve: Host the file for download (run inside Baguette)
serve:
    @echo "Hosting file server on Port 8000..."
    @echo "Download URL: http://<YOUR-VM-IP>:8000/kernel/arch/x86/boot/bzImage"
    python3 -m http.server 8000

# 6. Checks: Run lints and validations
check:
    @echo ">>> Checking Flake..."
    nix flake check
    @echo ">>> Linting build.sh..."
    shellcheck build.sh
    @echo ">>> Formatting Check..."
    nixfmt --check flake.nix

# Helper: Format code automatically
fmt:
    nixfmt flake.nix
    shfmt -w build.sh

# Helper: Run the full pipeline (Setup -> Config -> Build)
all: setup config build
