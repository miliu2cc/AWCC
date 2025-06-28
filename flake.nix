{
  description = "AWCC - Alienware Command Center tool for Linux (Nix Flake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        awccPackage = pkgs.stdenv.mkDerivation {
          pname = "awcc";
          version = "unstable";

          src = self;

          buildInputs = [ pkgs.gcc pkgs.make ];

          buildPhase = ''
            make
          '';

          installPhase = ''
            mkdir -p $out/bin
            make install PREFIX=$out
          '';

          meta = with pkgs.lib; {
            description = "Alienware Command Center (Linux)";
            homepage = "https://github.com/miliu2cc/AWCC";
            license = licenses.gpl3Plus;
            platforms = platforms.linux;
          };
        };

      in {
        packages.awcc = awccPackage;
        defaultPackage = awccPackage;

        overlays.awcc = final: prev: {
          awcc = awccPackage;
        };

        nixosModules.awcc = { config, pkgs, lib, ... }: {
          config.environment.systemPackages = [ awccPackage ];
        };

        homeManagerModules.awcc = { config, pkgs, lib, ... }: {
          config.home.packages = [ awccPackage ];
        };
      });
}
