{ config, pkgs, ... }:

# system module for host mooling-laptop
#
# Noctalia keyboard RGB sync for the Firebat T5K.
#
# Noctalia renders its palette into ~/.local/share/color-schemes/noctalia.colors
# through the kcolorscheme template. This watches that file and writes
# Colors:Selection/BackgroundNormal into the kernel LED interface at
# rgb:kbd_backlight/multi_intensity. It updates RGB only, leaving brightness
# alone because the keyboard backlight level is a separate user setting, and it
# does not depend on TUXEDO Control Center.
#
# Runs as a system unit rather than a user unit: the sysfs attribute is owned by
# root with mode 0644, so an unprivileged process cannot write it. brightnessctl
# reaches the same LED through logind's Session.SetBrightness, which only covers
# the brightness attribute and carries no color, so the color write stays
# privileged. See MAINTENANCE.md.
#
# Hardware specific: relies on the Clevo keyboard protocol exposed by
# tuxedo-drivers and the tuxedo_keyboard/clevo_acpi kernel modules, both enabled
# in hosts/<host>/default.nix.

let
  noctaliaKeyboardBacklightSync = pkgs.writeShellScript "noctalia-keyboard-backlight-sync" ''
    set -eu

    noctalia_colors="/home/${config.my.username}/.local/share/color-schemes/noctalia.colors"
    led_rgb="/sys/class/leds/rgb:kbd_backlight/multi_intensity"

    if [ ! -r "$noctalia_colors" ] || [ ! -w "$led_rgb" ]; then
      exit 0
    fi

    rgb="$(
      ${pkgs.kdePackages.kconfig}/bin/kreadconfig6 \
        --file "$noctalia_colors" \
        --group 'Colors:Selection' \
        --key BackgroundNormal
    )"
    if [[ ! "$rgb" =~ ^([0-9]{1,3}),([0-9]{1,3}),([0-9]{1,3})$ ]]; then
      echo "Noctalia accent color is not an RGB triplet: $rgb" >&2
      exit 1
    fi

    red="''${BASH_REMATCH[1]}"
    green="''${BASH_REMATCH[2]}"
    blue="''${BASH_REMATCH[3]}"
    if (( red > 255 || green > 255 || blue > 255 )); then
      echo "Noctalia accent color is outside the RGB range: $rgb" >&2
      exit 1
    fi

    # Do not write brightness: the user's keyboard backlight level is separate.
    printf '%s %s %s\n' "$red" "$green" "$blue" > "$led_rgb"
  '';
in

{
  # Keep the RGB keyboard color in step with the accent color Noctalia derives
  # from the wallpaper. The service writes the kernel LED interface directly.
  systemd.services.noctalia-keyboard-backlight-sync = {
    description = "Synchronize keyboard backlight with Noctalia accent color";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = noctaliaKeyboardBacklightSync;
    };
    wantedBy = [ "multi-user.target" ];
  };

  # The palette is rewritten on every wallpaper or light/dark switch, and the
  # template renders it atomically, so PathChanged catches both a plain write
  # and a rename onto the path.
  systemd.paths.noctalia-keyboard-backlight-sync = {
    description = "Watch Noctalia color scheme for keyboard backlight";
    pathConfig = {
      PathChanged = "/home/${config.my.username}/.local/share/color-schemes/noctalia.colors";
      Unit = "noctalia-keyboard-backlight-sync.service";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
