{
  description = "NixOS support for Radxa Cubie A5E (Allwinner A527) - WiFi, Bluetooth, board workarounds";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko.url = "github:nix-community/disko";
  };

  outputs = { self, nixpkgs, disko, ... }: {
    nixosModules = {
      aic8800 = ./modules/aic8800-sdio.nix;
      cubie-a5e = ./modules/cubie-a5e.nix;

      disko = { ... }: {
        imports = [
          disko.nixosModules.default
          ./modules/disko.nix
        ];
      };

      default = { ... }: {
        imports = [
          self.nixosModules.aic8800
          self.nixosModules.cubie-a5e
          self.nixosModules.disko
        ];
      };
    };

    nixosConfigurations.cubie-a5e = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        self.nixosModules.default
        ({ pkgs, ... }: {
          hardware.cubie-a5e.enable = true;
          boot.kernelPackages = pkgs.linuxPackages_7_0;

          users.users.root.initialPassword = "nixos";
          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
          };
          services.getty.autologinUser = "root";

          system.stateVersion = "25.11";
        })
      ];
    };
  };
}
