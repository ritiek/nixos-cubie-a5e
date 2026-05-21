# NixOS support for Radxa Cubie A5E (Allwinner A527)

NixOS modules for the Radxa Cubie A5E board:

- **AIC8800 SDIO WiFi/Bluetooth** driver + firmware (out-of-tree, patched for kernel 7.0)
- **Bluetooth HCI** over UART1 with automatic `hciattach`
- **Device Tree overlay** enabling mmc1 (SDIO) for WiFi and UART1 for Bluetooth
- **Watchdog reboot workaround** for WIP TF-A without PSCI SYSTEM_RESET
- **Systemd hardware watchdog** configuration

## Usage

Add to your `flake.nix` inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cubie-a5e.url = "github:patryk4815/cubie-a5e";
  };

  outputs = { nixpkgs, cubie-a5e, ... }: {
    nixosConfigurations.my-cubie = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        cubie-a5e.nixosModules.default
        {
          hardware.cubie-a5e.enable = true;
          # hardware.cubie-a5e.watchdog-reboot = false;  # disable if your TF-A supports PSCI reboot
        }
      ];
    };
  };
}
```

Or import individual modules:

```nix
# WiFi/Bluetooth only (without board workarounds)
cubie-a5e.nixosModules.aic8800
{
  hardware.aic8800.enable = true;
}

# Board workarounds only (without WiFi/Bluetooth)
cubie-a5e.nixosModules.cubie-a5e
{
  hardware.cubie-a5e.enable = true;
}
```

## Tested on

- NixOS unstable (kernel 7.0)
- Radxa Cubie A5E with AIC8800D80 WiFi/BT chip
