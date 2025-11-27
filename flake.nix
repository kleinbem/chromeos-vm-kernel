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
            # The Task Runner
            just

            # Build Tools
            git
            gnumake
            ncurses          # For menuconfig
            bison
            flex
            openssl
            bc
            elfutils         # libelf
            pahole           # BTF generation
            pkg-config

            # ChromeOS Toolchain (Clang/LLVM)
            llvmPackages_18.clang
            llvmPackages_18.lld
            llvmPackages_18.llvm
            
            # Linters & Formatters
            shellcheck
            shfmt
            nixfmt-rfc-style
          ];

          shellHook = ''
            echo "------------------------------------------------------"
            echo "🥖 ChromeOS Kernel Builder (Justfile Mode)"
            echo "   Run 'just' to see available commands."
            echo "------------------------------------------------------"
          '';
        };
      }
    );
}
