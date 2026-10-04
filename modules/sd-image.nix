# SD card image via nixpkgs' installer/sd-card/sd-image-aarch64.nix.
# Builds natively with no VM, so it works on hosts without /dev/kvm or
# device-mapper (which the previous disko-based image builder required).
{
  lib,
  config,
  pkgs,
  modulesPath,
  ...
}:
let
  uboot = import ./uboot.nix { inherit pkgs; };
  ubootBlob = {
    vendor = uboot.vendor;
    mainline-1gb = uboot.mainline-1gb;
    "mainline-2gb+" = uboot.mainline-2gb;
  };
in
{
  imports = [ "${modulesPath}/installer/sd-card/sd-image-aarch64.nix" ];

  options.hardware.cubie-a5e.uboot = lib.mkOption {
    type = lib.types.enum [ "none" "vendor" "mainline-1gb" "mainline-2gb+" ];
    default = "vendor";
    description = "U-Boot variant: 'none' (SPI NOR boot), 'vendor' (Radxa/Allwinner), 'mainline-1gb' (1GB LPDDR4), or 'mainline-2gb+' (2GB/4GB LPDDR4x)";
  };

  config = {
    # Allwinner U-Boot with extlinux
    boot.loader.grub.enable = false;
    boot.loader.generic-extlinux-compatible.enable = true;
    boot.loader.generic-extlinux-compatible.configurationLimit = 4;

    # The installer profile pulled in by sd-image-aarch64.nix enables ZFS,
    # which has no build for kernel 7.1.
    boot.supportedFilesystems.zfs = lib.mkForce false;

    sdImage = {
      compressImage = false;

      # Only emit the default extlinux entry (-g 0): the populate script
      # otherwise scrapes the build host's /nix/var/nix/profiles generations
      # into the image.
      populateRootCommands = lib.mkForce ''
        mkdir -p ./files/boot
        ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
          -c ${config.system.build.toplevel} -d ./files/boot -g 0
      '';

      # The BROM reads U-Boot from raw byte offsets (128KiB SPL, up to ~12MiB
      # for U-Boot+ATF), outside any partition. Keep the first 16MiB free for
      # it unless U-Boot lives in SPI NOR.
      firmwarePartitionOffset = if config.hardware.cubie-a5e.uboot == "none" then 8 else 16; # MiB

      postBuildCommands = lib.mkIf (config.hardware.cubie-a5e.uboot != "none") ''
        dd if=${ubootBlob.${config.hardware.cubie-a5e.uboot}}/u-boot-sunxi-with-spl.bin of=$img bs=1k seek=128 conv=notrunc
      '';
    };

    fileSystems."/" = lib.mkDefault {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };
}
