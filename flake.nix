{
  description = "NixOS support for Radxa Cubie A5E (Allwinner A527) - WiFi, Bluetooth, board workarounds";

  outputs = { self, ... }: {
    nixosModules = {
      aic8800 = ./modules/aic8800-sdio.nix;
      cubie-a5e = ./modules/cubie-a5e.nix;

      default = { ... }: {
        imports = [
          self.nixosModules.aic8800
          self.nixosModules.cubie-a5e
        ];
      };
    };
  };
}
