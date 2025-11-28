{
  description = "Nix development environment for building ChromeOS kernels";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "chromeos-kernel-builder";

          nativeBuildInputs = with pkgs; [
            just
            git
            gnumake
            ncurses
            bison
            flex
            openssl
            bc
            elfutils
            pahole
            pkg-config
            python3
            perl
            cpio
            
            # We need the standard clang for the environment
            llvmPackages_18.clang
            llvmPackages_18.lld
            llvmPackages_18.llvm
            
            shellcheck
           ];

          # HERE IS THE TRICK: We export the path to the RAW compiler
          shellHook = ''
            export CLANG_UNWRAPPED="${pkgs.llvmPackages_18.clang-unwrapped}/bin/clang"
            export LD_UNWRAPPED="${pkgs.llvmPackages_18.lld}/bin/ld.lld"
            
            echo "------------------------------------------------------"
            echo "🥖 ChromeOS Kernel Builder (Split-Toolchain)"
            echo "   * HOSTCC  : System Clang (Wrapped)"
            echo "   * CC      : ${pkgs.llvmPackages_18.clang-unwrapped.name} (Unwrapped)"
            echo "------------------------------------------------------"
          '';
        };
      }
    );
}
