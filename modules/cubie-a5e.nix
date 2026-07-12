{ pkgs, lib, config, ... }:
let
  cfg = config.hardware.cubie-a5e;
in
{
  options.hardware.cubie-a5e = {
    enable = lib.mkEnableOption "Radxa Cubie A5E board support";

    watchdog-reboot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable watchdog-based reboot workaround for WIP TF-A (no PSCI SYSTEM_RESET)";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.aic8800.enable = true;

    # A523/A527's actual THS0/THS1 temperature-sensor hardware blocks are not
    # yet supported by nixpkgs' shipped sun8i_thermal driver, which causes
    # /sys/class/thermal readings to get stuck at a static boot-time value
    # instead of updating. Backported from the still-unmerged (as of
    # 2026-07-11) upstream series:
    # https://patchew.org/linux/20260704171411.1413349-1-iuncuim@gmail.com/
    # "[PATCH v5 0/5] Allwinner: A523: add support for A523 THS0/1 controllers"
    # Can be dropped once upstream merges and nixpkgs bumps the kernel past it.
    boot.kernelPatches = [
      { name = "sun55i-a523-thermal-1-dt-bindings"; patch = ./patches/0001-dt-bindings-thermal-sun8i-add-a523-ths.patch; }
      { name = "sun55i-a523-thermal-2-reset-control-shared"; patch = ./patches/0002-thermal-sun8i-reset-control-shared-deasserted.patch; }
      { name = "sun55i-a523-thermal-3-two-nvmem-cells"; patch = ./patches/0003-thermal-sun8i-calibration-two-nvmem-cells.patch; }
      { name = "sun55i-a523-thermal-4-ths0-ths1-driver"; patch = ./patches/0004-thermal-sun8i-add-a523-ths0-ths1-support.patch; }
      { name = "sun55i-a523-thermal-5-dts-sensors-zones"; patch = ./patches/0005-arm64-dts-allwinner-sun55i-add-thermal-sensors.patch; }
    ];

    # Hardware watchdog for reliable reboot/shutdown detection
    systemd.settings.Manager = {
      RuntimeWatchdogSec = "15s";
      RebootWatchdogSec = "15s";
    };

    # Workaround: WIP TF-A doesn't support PSCI SYSTEM_RESET
    # Crash kernel on shutdown so hardware watchdog triggers reboot
    systemd.services.watchdog-reboot-helper = lib.mkIf cfg.watchdog-reboot {
      description = "Crash kernel for reboot";
      wantedBy = [ "multi-user.target" ];
      before = [ "shutdown.target" ];
      conflicts = [ "shutdown.target" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
        ExecStop = "${pkgs.bash}/bin/bash -c 'echo c > /proc/sysrq-trigger'";
      };
    };
  };
}
