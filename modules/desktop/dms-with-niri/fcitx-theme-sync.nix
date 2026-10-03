{ pkgs, ... }:

# Home-manager module, has been imported in dms-with-niri.
#
# Fcitx5 Plasma 候选窗的 DMS 深浅色同步。
#
# Fcitx5 的实验性 `plasma` Classic UI 主题跟随 Plasma Shell 的 SVG 主题，不读取
# DMS 发布的门户深浅色，因此在 niri 会话里会回退到白色 breeze-light 和固定蓝色
# 高亮。这里改成从 DMS 自己写的 DankMatugen.colors 推导主题。
#
# 同步 service 不直接挂在 graphical-session.target 上，只由 path unit 在 DMS 写入
# 色表后触发；否则与 `After = dms.service` 会形成排序循环，systemd 会丢弃 DMS 的
# 启动任务。详见 MAINTENANCE.md「Fcitx5 Plasma 候选窗的 DMS 深浅色同步」。
#
# 桌面无关的 Fcitx 配置（输入法、waylandFrontend 等）不在这里。

let
  fcitxDmsThemeSync = pkgs.writeShellScript "fcitx5-dms-theme-sync" ''
    set -eu

    rgb_to_hex() {
      local red green blue
      IFS=, read -r red green blue <<< "$1"
      printf '#%02x%02x%02x' "$red" "$green" "$blue"
    }

    rgb_luminance() {
      local red green blue
      IFS=, read -r red green blue <<< "$1"
      printf '%d' "$(( (2126 * red + 7152 * green + 722 * blue) / 10000 ))"
    }

    dms_colors="$HOME/.local/share/color-schemes/DankMatugen.colors"
    window_background_rgb="$(
      ${pkgs.kdePackages.kconfig}/bin/kreadconfig6 \
        --file "$dms_colors" \
        --group 'Colors:Window' \
        --key BackgroundNormal
    )"
    if [ "$(rgb_luminance "$window_background_rgb")" -lt 128 ]; then
      theme_mode="dark"
    else
      theme_mode="light"
    fi

    # breeze-{light,dark} only overrides colors. Give the generator a complete
    # private image set so it does not need a running Plasma Shell for fallback
    # SVG resources.
    plasma_theme="dms-fcitx-$theme_mode"
    for plasma_theme_dir in \
      "$HOME/.local/share/plasma/desktoptheme/$plasma_theme" \
      "$HOME/.local/share/fcitx5-plasma-theme-generator/svgtheme/$plasma_theme"; do
      ${pkgs.coreutils}/bin/mkdir -p "$plasma_theme_dir"
      ${pkgs.coreutils}/bin/chmod -R u+w "$plasma_theme_dir"
      ${pkgs.coreutils}/bin/cp -R --no-preserve=mode,ownership \
        ${pkgs.kdePackages.libplasma}/share/plasma/desktoptheme/default/. \
        "$plasma_theme_dir/"
      ${pkgs.coreutils}/bin/cp \
        ${pkgs.kdePackages.libplasma}/share/plasma/desktoptheme/breeze-"$theme_mode"/colors \
        "$plasma_theme_dir/colors"
      ${pkgs.gnused}/bin/sed -i \
        "s/\"Id\": \"default\"/\"Id\": \"$plasma_theme\"/" \
        "$plasma_theme_dir/metadata.json"
    done

    ${pkgs.qt6Packages.fcitx5-with-addons}/bin/fcitx5-plasma-theme-generator \
      --theme "$plasma_theme" \
      --output "$HOME/.local/share/fcitx5/themes/dms-plasma"

    dms_theme="$HOME/.local/share/fcitx5/themes/dms-plasma"
    selection_background_rgb="$(
      ${pkgs.kdePackages.kconfig}/bin/kreadconfig6 \
        --file "$dms_colors" \
        --group 'Colors:Selection' \
        --key BackgroundNormal
    )"
    selection_foreground_rgb="$(
      ${pkgs.kdePackages.kconfig}/bin/kreadconfig6 \
        --file "$dms_colors" \
        --group 'Colors:Selection' \
        --key ForegroundNormal
    )"
    selection_background="$(rgb_to_hex "$selection_background_rgb")"
    selection_foreground="$(rgb_to_hex "$selection_foreground_rgb")"

    ${pkgs.gnused}/bin/sed -i \
      -e "s/^HighlightCandidateColor=.*/HighlightCandidateColor=$selection_foreground/" \
      -e "s/^HighlightColor=.*/HighlightColor=$selection_foreground/" \
      -e "s/^HighlightBackgroundColor=.*/HighlightBackgroundColor=$selection_background/" \
      "$dms_theme/theme.conf"
    # fcitx5 5.1.23 起支持高分辨率资源：生成器按 SupportedScale 额外写出
    # highlight@2x.png 等 @Nx 变体，classicui 再按实际缩放取用
    # （findScaledImage 用 ceil(显示缩放)，本机 1.5 → 取 @2x）。
    # 必须逐个变体重着色，否则高分屏下会回落到生成器原始的 breeze 蓝。
    for highlight_image in "$dms_theme"/highlight*.png; do
      [ -e "$highlight_image" ] || continue
      ${pkgs.imagemagick}/bin/mogrify \
        -fill "$selection_background" \
        -colorize 100 \
        "$highlight_image"
    done

    if ${pkgs.qt6Packages.fcitx5-with-addons}/bin/fcitx5-remote --check; then
      # Classic UI caches NormalColor across a config reload. This is the same
      # restart path exposed by Fcitx's system tray, so its addon environment
      # and configured input methods are retained.
      ${pkgs.systemd}/bin/busctl --user call \
        org.fcitx.Fcitx5 \
        /controller \
        org.fcitx.Fcitx.Controller1 \
        Restart
    fi
  '';
in
{
  systemd.user.services.fcitx5-dms-theme-sync = {
    Unit = {
      Description = "Synchronize Fcitx5 Plasma candidate theme with DMS";
      After = [ "dms.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = fcitxDmsThemeSync;
    };
  };

  systemd.user.paths.fcitx5-dms-theme-sync = {
    Unit = {
      Description = "Watch DMS color scheme for Fcitx5";
    };
    Path = {
      PathChanged = "%h/.local/share/color-schemes/DankMatugen.colors";
      Unit = "fcitx5-dms-theme-sync.service";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
