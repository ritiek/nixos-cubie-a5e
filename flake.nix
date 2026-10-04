{
  description = "NixOS support for Radxa Cubie A5E (Allwinner A527) - WiFi, Bluetooth, board workarounds";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs, ... }: let
    pkgs = nixpkgs.legacyPackages.aarch64-linux;
    nixpkgs-unstable = builtins.getFlake "github:NixOS/nixpkgs/104240a772428cc2e20d8fd86c9ddbb886bbaff2?narHash=sha256-D740uKsMbgsfK2oaDenJLLPIZfq7W0/g4KN/Fls8eKs%3D"; # 2026-08-03
  in {
    nixosModules = {
      aic8800 = ./modules/aic8800-sdio.nix;
      cubie-a5e = ./modules/cubie-a5e.nix;
      sd-image = ./modules/sd-image.nix;

      default = { ... }: {
        imports = [
          self.nixosModules.aic8800
          self.nixosModules.cubie-a5e
          self.nixosModules.sd-image
        ];
      };
    };

    packages = let
      uboot = import ./modules/uboot.nix { inherit pkgs; };
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    in forAllSystems (system: {
      sunxi-fel = nixpkgs-unstable.legacyPackages.${system}.sunxi-tools.overrideAttrs (old: {
        meta = old.meta // { mainProgram = "sunxi-fel"; platforms = old.meta.platforms ++ [ system ]; };
      });
    }) // {
      aarch64-linux = {
        sunxi-fel = nixpkgs-unstable.legacyPackages.aarch64-linux.sunxi-tools.overrideAttrs (old: {
          meta = old.meta // { mainProgram = "sunxi-fel"; platforms = old.meta.platforms ++ [ "aarch64-linux" ]; };
        });
        uboot-vendor = uboot.vendor;
        uboot-1gb = uboot.mainline-1gb;
        uboot-2gb = uboot.mainline-2gb;
        spinor-vendor = uboot.spinor-vendor;
        spinor-1gb = uboot.spinor-1gb;
        spinor-2gb = uboot.spinor-2gb;
      };
    };

    nixosConfigurations = let
      mkCubieA5E = { uboot ? "none", combophy ? "pcie" }: nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          self.nixosModules.default
          ({ pkgs, lib, ... }: {
            hardware.cubie-a5e.enable = true;
            hardware.cubie-a5e.uboot = uboot;
            hardware.cubie-a5e.combophy = combophy;
            boot.kernelPackages = pkgs.linuxPackages_7_1;

            # Serial console. sd-image-aarch64.nix already sets
            # console=ttyS0,115200n8; earlycon (UART0, 8250 at 0x02500000)
            # covers the window before the real driver probes.
            boot.kernelParams = [ "earlycon=uart8250,mmio32,0x02500000" ];
            boot.consoleLogLevel = 7;

            # Explicit DHCP on all interfaces instead of relying on module
            # defaults, so first-boot SSH always has a way to get an address.
            networking.useDHCP = lib.mkDefault true;

            users.users.root.initialPassword = "nixos";
            services.openssh = {
              enable = true;
              settings.PermitRootLogin = "yes";
            };
            services.getty.autologinUser = "root";

            environment.systemPackages = with pkgs; [ wpa_supplicant htop iproute2 nettools parted pciutils usbutils vim smartmontools mtdutils ];

            system.stateVersion = "26.05";
          })
        ];
      };
    in {
      cubie-a5e-sd-vendor = mkCubieA5E { uboot = "vendor"; };
      cubie-a5e-sd-mainline-1gb = mkCubieA5E { uboot = "mainline-1gb"; };
      cubie-a5e-sd-mainline-1gb-usb3 = mkCubieA5E { uboot = "mainline-1gb"; combophy = "usb3"; };
      cubie-a5e-sd-mainline-2gb = mkCubieA5E { uboot = "mainline-2gb+"; };
      cubie-a5e-spi = mkCubieA5E { uboot = "none"; };
    };
  };
}
