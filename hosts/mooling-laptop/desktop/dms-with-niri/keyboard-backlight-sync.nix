{ config, pkgs, ... }:

# system module for host mooling-laptop
#
# Firebat T5K 的 DMS 键盘 RGB 同步。
#
# DMS 在 ~/.local/share/color-schemes/DankMatugen.colors 写入动态调色板；这里监听
# 该文件，把 Colors:Selection/BackgroundNormal 写进内核 LED 接口
# rgb:kbd_backlight/multi_intensity。只更新 RGB，不碰亮度（用户的键盘背光档位是
# 独立的），也不依赖 TUXEDO Control Center。
#
# 硬件相关：依赖 tuxedo-drivers 暴露的 Clevo 键盘协议与 tuxedo_keyboard/clevo_acpi
# 内核模块，两者在 hosts/<host>/default.nix 中启用。详见 MAINTENANCE.md
# 「Firebat T5K 的 DMS 键盘 RGB 同步」。

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
