{ pkgs, ... }:

# Home-manager module, has been imported in dms-with-niri.
#
# DMS light/dark sync for the Fcitx5 Plasma candidate window.
#
# Fcitx5's experimental `plasma` Classic UI theme follows the Plasma Shell SVG
# theme and ignores the DMS-published portal colors, so in a niri session it
# falls back to white breeze-light with a fixed blue highlight. Derive the theme
# from DankMatugen.colors, which DMS writes itself.
#
# The sync service is not attached to graphical-session.target; only a path unit
# triggers it after DMS writes the color scheme. Attaching it, together with
# `After = dms.service`, would form an ordering cycle and make systemd drop DMS
# startup. See MAINTENANCE.md.
#
# Desktop-independent Fcitx config (input methods, waylandFrontend, ...) is not
# here.

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
    # Since fcitx5 5.1.23 the generator also writes high-resolution resources:
    # @Nx variants such as highlight@2x.png per SupportedScale, and classicui
    # picks one by actual scale (findScaledImage uses ceil(display scale); 1.5
    # here -> @2x). Each variant must be recolored individually, otherwise
    # HiDPI falls back to the generator's original breeze blue.
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
