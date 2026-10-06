{ config, pkgs, ... }:

# system module for host mooling-laptop
#
# DMS keyboard RGB sync for the Firebat T5K.
#
# DMS writes a dynamic palette to
# ~/.local/share/color-schemes/DankMatugen.colors. This watches that file and
# writes Colors:Selection/BackgroundNormal into the kernel LED interface at
# rgb:kbd_backlight/multi_intensity. It updates RGB only, leaving brightness
# alone because the keyboard backlight level is a separate user setting, and it
# does not depend on TUXEDO Control Center.
#
# Hardware specific: relies on the Clevo keyboard protocol exposed by
# tuxedo-drivers and the tuxedo_keyboard/clevo_acpi kernel modules, both enabled
# in hosts/<host>/default.nix. See MAINTENANCE.md.

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
}
