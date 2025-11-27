{
  description = "ChromeOS Kernel Builder Environment (Baguette/Crostini)";

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

          # Packages required to build the kernel
          nativeBuildInputs = with pkgs; [
            git
            gnumake
            ncurses          # Needed for 'menuconfig' interface
            bison
            flex
            openssl
            bc
            elfutils         # Provides 'libelf'
            pahole           # Required for BTF generation in newer kernels
            
            # Google uses LLVM/Clang for ChromeOS kernels
            llvmPackages_18.clang
            llvmPackages_18.lld
            llvmPackages_18.llvm
            pkg-config

           shellcheck      # Lints your build.sh
           shfmt           # Formats your build.sh
           nixfmt-rfc-style # Formats flake.nix
          ];

          shellHook = ''
            echo "------------------------------------------------------"
            echo "🥖 Baguette Kernel Builder Environment"
            echo "   Run './build.sh' to clone and build."
            echo "------------------------------------------------------"
          '';
        };
      }
    );
}
