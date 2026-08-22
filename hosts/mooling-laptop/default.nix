{ config, pkgs, ... }:

let
  dmsKeyboardBacklightSync = pkgs.writeShellScript "dms-keyboard-backlight-sync" ''
    set -eu

    dms_colors="/home/${config.my.username}/.local/share/color-schemes/DankMatugen.colors"
    led_rgb="/sys/class/leds/rgb:kbd_backlight/multi_intensity"

    if [ ! -r "$dms_colors" ] || [ ! -e "$led_rgb" ]; then
      exit 0
    fi

    rgb="$(
      ${pkgs.kdePackages.kconfig}/bin/kreadconfig6 \
        --file "$dms_colors" \
        --group 'Colors:Selection' \
        --key BackgroundNormal
    )"
    if [[ ! "$rgb" =~ ^([0-9]{1,3}),([0-9]{1,3}),([0-9]{1,3})$ ]]; then
      echo "DMS accent color is not an RGB triplet: $rgb" >&2
      exit 1
    fi

    red="''${BASH_REMATCH[1]}"
    green="''${BASH_REMATCH[2]}"
    blue="''${BASH_REMATCH[3]}"
    if (( red > 255 || green > 255 || blue > 255 )); then
      echo "DMS accent color is outside the RGB range: $rgb" >&2
      exit 1
    fi

    # Do not write brightness: the user's keyboard backlight level is separate.
    printf '%s %s %s\n' "$red" "$green" "$blue" > "$led_rgb"
  '';
in

{
  imports = [
    ./hardware-configuration.nix
    ./gpu.nix
    # ./streaming.nix
    ../../modules/system/config.nix
    ../../modules/system/i18n.nix
    ../../modules/system/desktop.nix
    ../../modules/system/fonts.nix
    ../../modules/system/networking.nix
    ../../modules/system/nix.nix
    ../../modules/system/packages.nix
    ../../modules/system/services.nix
    ../../modules/system/users.nix
    ../../modules/system/virtualisation.nix
    ../../modules/system/obs.nix
  ];

  boot.loader = {
    efi.canTouchEfiVariables = true;
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 10;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Firebat T5K uses the Clevo keyboard protocol supported by tuxedo-drivers.
  hardware.tuxedo-drivers.enable = true;
  boot.kernelModules = [ "tuxedo_keyboard" "clevo_acpi" ];

  # Keep the RGB keyboard color in step with DMS's dynamically generated accent
  # color. The service writes the kernel LED interface directly.
  systemd.services.dms-keyboard-backlight-sync = {
    description = "Synchronize keyboard backlight with DMS accent color";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = dmsKeyboardBacklightSync;
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.paths.dms-keyboard-backlight-sync = {
    description = "Watch DMS color scheme for keyboard backlight";
    pathConfig = {
      PathChanged = "/home/${config.my.username}/.local/share/color-schemes/DankMatugen.colors";
      Unit = "dms-keyboard-backlight-sync.service";
    };
    wantedBy = [ "multi-user.target" ];
  };

  boot.resumeDevice = "/dev/disk/by-uuid/c531a6ba-9945-42f0-821b-9a0553fe100d";

  networking.hostName = config.my.hostname;

  services.howdy.settings.video.device_path =
    "/dev/v4l/by-id/usb-Sonix_Technology_Co.__Ltd._BisonCam_NB_Pro-video-index0";

  system.stateVersion = "25.11";
}
