# Justfile
set shell := ["bash", "-c"]

# Export variables to sub-shells (and build.sh)
export BRANCH := "chromeos-6.6"
export MAKE_FLAGS := "LLVM=1 LLVM_IAS=1"

# ------------------------------------------------------------------------------
# DEFAULT
# ------------------------------------------------------------------------------
# List available commands
default:
    @just --list

# ------------------------------------------------------------------------------
# BUILD TASKS
# ------------------------------------------------------------------------------

# 🚀 The main command: Fully automated build (Setup -> Config -> Compile)
build:
    @./build.sh all

# 🔧 Prepare the configuration only (useful to check flags before building)
config:
    @./build.sh config

# 🎨 Open the interactive MenuConfig (for manual debugging)
menuconfig:
    @./build.sh menuconfig

# ------------------------------------------------------------------------------
# MAINTENANCE
# ------------------------------------------------------------------------------

# 🧹 Clean compiled objects (Leaves .config and source) - Safe for incremental
clean:
    @./build.sh clean

# ☢️  Deep Clean: Removes the entire kernel directory to start fresh
nuke:
    @echo ">>> ☢️  NUKING KERNEL DIRECTORY..."
    rm -rf kernel out
    @echo "Done."

# 🔄 Update the Nix Environment (flake.lock)
update-deps:
    nix flake update
