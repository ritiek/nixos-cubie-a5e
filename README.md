# NixOS support for Radxa Cubie A5E (Allwinner A527)

NixOS modules for the Radxa Cubie A5E board:

- **AIC8800 SDIO WiFi/Bluetooth** driver + firmware (out-of-tree, patched for kernel 7.0)
- **Bluetooth HCI** over UART1 with automatic `hciattach`
- **Device Tree overlay** enabling mmc1 (SDIO) for WiFi and UART1 for Bluetooth
- **Disko** SD card image with U-Boot, GPT, btrfs + LVM
- **Watchdog reboot workaround** for WIP TF-A without PSCI SYSTEM_RESET
- **Systemd hardware watchdog** configuration

## Quick start (pre-built image)

Download the latest `main.raw.zst` from [Releases](https://github.com/patryk4815/nixos-cubie-a5e/releases) and flash to SD card:

```bash
zstdcat main.raw.zst | sudo dd of=/dev/sdX bs=4M status=progress
sync
```

Default login: `root` / `nixos`

The image is only 6 GB. After first boot, resize the partition to use the full SD card:

```bash
nix-shell -p parted
parted /dev/mmcblk0
(parted) p
(parted) resizepart 2 100%
(parted) quit
reboot
```

After reboot, extend LVM and btrfs:

```bash
pvresize /dev/mmcblk0p2
lvextend -l +100%FREE /dev/root_vg/root
btrfs filesystem resize max /
```

## Usage

Add to your `flake.nix` inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
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

Build SD card image (pre-configured example with root/nixos login):

```bash
nix build '.#nixosConfigurations.cubie-a5e.config.system.build.diskoImagesScript' -L
./result
```

This produces `main.raw` in the current directory. Flash to SD card:

```bash
sudo dd if=main.raw of=/dev/sdX bs=4M status=progress
```

### Individual modules

```nix
# WiFi/Bluetooth only (without disko or board workarounds)
cubie-a5e.nixosModules.aic8800
{
  hardware.aic8800.enable = true;
}

# Board workarounds only (watchdog reboot, systemd watchdog)
cubie-a5e.nixosModules.cubie-a5e
{
  hardware.cubie-a5e.enable = true;
}

# Disko only (disk layout + U-Boot)
cubie-a5e.nixosModules.disko
```

## Disk layout

Only **SD card** (`/dev/mmcblk0`) boot is supported. The image uses GPT partitioning:

| Offset | Content |
|--------|---------|
| 128 KB (sector 256) | U-Boot boot0 (SPL) |
| 12 MB (sector 24576) | U-Boot boot_package (U-Boot + ATF) |
| 16 MB (sector 32768) | First GPT partition |

Partitions:

- `/boot` - 2 GB ext4 (extlinux boot)
- `root` - remaining space, LVM physical volume

LVM volume group `root_vg` with single logical volume `root` formatted as **btrfs** with subvolumes:

- `/root` -> mounted at `/`
- `/nix` -> mounted at `/nix` (noatime)

## U-Boot

Default is **vendor** U-Boot from Radxa (`u-boot-aw2501` package).

> **Note:** `hardware.cubie-a5e.uboot = "mainline"` is available but **does not boot** currently.
> Mainline U-Boot builds with WIP TF-A from [jernejsk/arm-trusted-firmware](https://github.com/jernejsk/arm-trusted-firmware) (branch `a523`),
> but fails to start. Root cause is under investigation.

## Hardware support status

| Feature | Status | Notes |
|---------|--------|-------|
| WiFi 6 (AIC8800D80 SDIO) | ✅ Working | 2.4 GHz only, out-of-tree driver |
| Bluetooth 5.4 (AIC8800D80 UART) | ✅ Working | HCI over UART1, out-of-tree driver, hciattach service |
| Ethernet (RJ45 x2) | ✅ Working | Both GbE ports |
| SD card | ✅ Working | Boot + rootfs |
| USB 2.0 | ✅ Working | |
| USB 3.0 | ❌ Not working | Missing combo PHY + xHCI DT nodes in mainline, port falls back to USB 2.0 speed |
| M.2 slot (PCIe) | ❌ Not working | Shares lane with USB 3.0 via combo PHY, not yet in mainline DT |
| HDMI | ❌ Not working | Requires display engine drivers not yet in mainline |
| MIPI DSI | ❌ Not working | Missing mainline support/drivers |
| MIPI CSI | ❌ Not working | Missing mainline support/drivers |
| GPU (Mali G57 MC1) | ❌ Not working | Panfrost support WIP, no display output in mainline yet |
| Video HW decode/encode | ❌ Not working | Cedrus driver does not support sun55i/A527 yet |
| NPU | ➖ N/A | Only available on T527 (industrial variant), A527 does not have NPU |
| GPIO | 🔘 Not tested | Likely works |
| eMMC | 🔘 Not tested | Likely works |


## Known issues

- **Mainline U-Boot does not boot** - use vendor U-Boot (default)
- **PSCI SYSTEM_RESET not implemented** in vendor TF-A - `watchdog-reboot-helper` service crashes kernel on shutdown so hardware watchdog triggers reboot
- **Only SD card boot** - eMMC/USB boot not tested

## Tested on

- NixOS 25.11 + kernel 7.0
- Radxa Cubie A5E with AIC8800D80 WiFi/BT chip
