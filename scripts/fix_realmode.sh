#!/usr/bin/env bash
set -euo pipefail

# This script patches the Real Mode Makefile in the kernel source.
# The path must now include the 'kernel/' prefix!

REALMODE_MK="kernel/arch/x86/realmode/rm/Makefile" 

if [ -f "$REALMODE_MK" ]; then
    echo "   🩹 Patching Real Mode Makefile ($REALMODE_MK)..."
    
    # 1. Remove existing -Werror to prevent build stoppage on warnings
    sed -i 's/-Werror//g' "$REALMODE_MK"
    
    # 2. Force append the ignore flag for BOTH C (CFLAGS) and Assembly (AFLAGS).
    #    We check if it's already there to allow repeated runs without bloating the file.
    if ! grep -q "unused-command-line-argument" "$REALMODE_MK"; then
         echo "KBUILD_CFLAGS += -Wno-error=unused-command-line-argument" >> "$REALMODE_MK"
         echo "KBUILD_AFLAGS += -Wno-error=unused-command-line-argument" >> "$REALMODE_MK"
    fi
else
    echo "   ⚠️ Warning: Real Mode Makefile not found. Skipping patch."
fi
