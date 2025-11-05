{
  description = "AWCC - Unofficial Alienware Command Centre alternative for Dell G series";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    pkgsFor = forAllSystems (system:
      import nixpkgs {
        inherit system;
      });
  in {
    packages = forAllSystems (system: rec {
      awcc = pkgsFor.${system}.stdenv.mkDerivation rec {
        pname = "awcc";
        version = "1.12.0";

        src = self;

        nativeBuildInputs = with pkgsFor.${system}; [
          cmake
          pkg-config
        ];

        buildInputs = with pkgsFor.${system}; [
          libusb1
          glfw
          xorg.libX11
          libGL
          libevdev
          systemd
          # Optional: CMake will fetch these from GitHub if not found
          loguru
          nlohmann_json
        ];

        cmakeFlags = [
          "-DCMAKE_BUILD_TYPE=Release"
        ];

        installPhase = ''
          runHook preInstall

          # Install binary
          install -Dm755 ./awcc $out/bin/awcc

          # Install desktop file
          if [ -f ${src}/app/*.desktop ]; then
            install -Dm644 ${src}/app/*.desktop $out/share/applications/
          fi

          # Install icons
          for icon in ${src}/app/*.png; do
            if [ -f "$icon" ]; then
              install -Dm644 "$icon" $out/share/icons/hicolor/256x256/apps/$(basename "$icon")
            fi
          done

          # Install udev rules
          install -Dm644 ${src}/app/70-awcc.rules $out/lib/udev/rules.d/70-awcc.rules

          # Install systemd service
          install -Dm644 ${src}/app/awccd.service $out/lib/systemd/system/awccd.service

          # Install database
          install -Dm644 ${src}/database.json $out/share/awcc/database.json

          runHook postInstall
        '';

        meta = with pkgsFor.${system}.lib; {
          description = "An unofficial alternative to Alienware Command Centre for Dell G series on Linux";
          longDescription = ''
            AWCC is an unofficial alternative to Alienware Command Centre for Dell G series 
            and Alienware laptops on Linux. It supports custom fan controls, light effects, 
            g-mode, and autoboost.
          '';
          homepage = "https://github.com/tr1xem/AWCC";
          license = licenses.mit;
          platforms = platforms.linux;
          maintainers = [];
        };
      };

      default = awcc;
    });

    # Development shell
    devShells = forAllSystems (system: {
      default = pkgsFor.${system}.mkShell {
        buildInputs = with pkgsFor.${system}; [
          cmake
          pkg-config
          libusb1
          glfw
          xorg.libX11
          libGL
          libevdev
          systemd
          loguru
          nlohmann_json
          clang-tools
          gdb
        ];

        shellHook = ''
          echo "🚀 AWCC development environment"
          echo "Build: mkdir -p build && cd build && cmake .. && make"
          echo "Run: ./build/awcc"
        '';
      };
    });

    # Application entry point
    apps = forAllSystems (system: {
      default = {
        type = "app";
        program = "${self.packages.${system}.awcc}/bin/awcc";
      };
    });

    # NixOS module
    nixosModules.default = {
      config,
      lib,
      pkgs,
      ...
    }:
      with lib; let
        cfg = config.services.awcc;
      in {
        options.services.awcc = {
          enable = mkEnableOption "AWCC daemon for Alienware/Dell G series laptops";

          package = mkOption {
            type = types.package;
            default = self.packages.${pkgs.system}.awcc;
            defaultText = literalExpression "pkgs.awcc";
            description = "The AWCC package to use";
          };
        };

        config = mkIf cfg.enable {
          # Install package
          environment.systemPackages = [cfg.package];

          # Configure udev rules (NixOS declarative way)
          services.udev.extraRules = ''
            # Alienware USB devices for lighting control
            SUBSYSTEM=="usb", ATTRS{idVendor}=="187c", ATTRS{idProduct}=="0551", MODE="0660", TAG+="uaccess"
            SUBSYSTEM=="usb", ATTRS{idVendor}=="187c", ATTRS{idProduct}=="0550", MODE="0660", TAG+="uaccess"
          '';

          # Enable systemd service
          systemd.services.awccd = {
            description = "AWCC Daemon for Alienware/Dell G series";
            wantedBy = ["multi-user.target"];
            after = ["systemd-udev-settle.service"];
            
            serviceConfig = {
              Type = "simple";
              ExecStart = "${cfg.package}/bin/awcc --daemon";
              Restart = "on-failure";
              RestartSec = "5s";
            };
          };

          # Load acpi_call kernel module
          boot.extraModulePackages = with config.boot.kernelPackages; [acpi_call];
          boot.kernelModules = ["acpi_call"];
        };
      };
  };
}
