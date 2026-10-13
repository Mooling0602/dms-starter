{ pkgs, ... }:

# Home-manager module, has been imported in noctalia-with-niri.
#
# Noctalia light/dark sync for the Fcitx5 Plasma candidate window.
#
# Fcitx5's experimental `plasma` Classic UI theme follows the Plasma Shell SVG
# theme and ignores the palette Noctalia publishes over the portal, so in a niri
# session it falls back to white breeze-light with a fixed blue highlight.
# Noctalia has no Fcitx5 template of its own (its built-in catalog covers
# terminals, editors, compositors, GTK/Qt and KColorScheme), so the theme is
# derived from the KColorScheme template output at
# ~/.local/share/color-schemes/noctalia.colors, the closest thing to a palette
# for KDE-styled components. That file is rendered by the shell whenever the
# palette changes, which is what the path unit below watches.
#
# The generated theme deliberately keeps the directory name the DMS layer uses:
# ~/.config/fcitx5/conf/classicui.conf is a runtime file (Fcitx writes it from
# its own settings dialog) that pins Theme and DarkTheme to "dms-plasma".
# Reusing the name means switching desktops stays a one-line `let` change
# instead of another manual edit of that file. Only the private Plasma SVG theme
# the generator reads is namespaced per desktop (noctalia-fcitx-<mode>).
#
# The sync service is not attached to graphical-session.target; only the path
# unit triggers it, which keeps it out of the session startup ordering. The
# Fcitx config that is desktop independent (input methods, waylandFrontend, the
# addons) lives in modules/system/i18n.nix and modules/home/defaults instead.

let
  fcitxThemeSync = pkgs.writeShellScript "fcitx5-noctalia-theme-sync" ''
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

    noctalia_colors="$HOME/.local/share/color-schemes/noctalia.colors"
    window_background_rgb="$(
      ${pkgs.kdePackages.kconfig}/bin/kreadconfig6 \
        --file "$noctalia_colors" \
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
    plasma_theme="noctalia-fcitx-$theme_mode"
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

    fcitx_theme="$HOME/.local/share/fcitx5/themes/dms-plasma"
    ${pkgs.qt6Packages.fcitx5-with-addons}/bin/fcitx5-plasma-theme-generator \
      --theme "$plasma_theme" \
      --output "$fcitx_theme"

    selection_background_rgb="$(
      ${pkgs.kdePackages.kconfig}/bin/kreadconfig6 \
        --file "$noctalia_colors" \
        --group 'Colors:Selection' \
        --key BackgroundNormal
    )"
    selection_foreground_rgb="$(
      ${pkgs.kdePackages.kconfig}/bin/kreadconfig6 \
        --file "$noctalia_colors" \
        --group 'Colors:Selection' \
        --key ForegroundNormal
    )"
    selection_background="$(rgb_to_hex "$selection_background_rgb")"
    selection_foreground="$(rgb_to_hex "$selection_foreground_rgb")"

    # The selected candidate repeats the color the generator already picked for
    # NormalColor, which is what unselected candidates use, so the two never
    # disagree: dark themes get light text, light themes dark text. The block
    # behind a selected candidate is a 30% alpha image composited over the
    # panel, not the opaque HighlightBackgroundColor, so the darker selection
    # foreground would only reach about 1.9:1 against it. HighlightColor is the
    # preedit highlight instead, whose background really is the opaque
    # HighlightBackgroundColor, so it keeps the selection foreground.
    # kreadconfig6 exits 0 even when the group or key is missing and then
    # prints nothing, so the emptiness check is the actual fallback.
    normal_color="$(
      ${pkgs.kdePackages.kconfig}/bin/kreadconfig6 \
        --file "$fcitx_theme/theme.conf" \
        --group 'InputPanel' \
        --key NormalColor
    )"
    [ -n "$normal_color" ] || normal_color="$selection_foreground"

    ${pkgs.gnused}/bin/sed -i \
      -e "s/^HighlightCandidateColor=.*/HighlightCandidateColor=$normal_color/" \
      -e "s/^HighlightColor=.*/HighlightColor=$selection_foreground/" \
      -e "s/^HighlightBackgroundColor=.*/HighlightBackgroundColor=$selection_background/" \
      "$fcitx_theme/theme.conf"
    # Since fcitx5 5.1.23 the generator also writes high-resolution resources:
    # @Nx variants such as highlight@2x.png per SupportedScale, and classicui
    # picks one by actual scale (findScaledImage uses ceil(display scale); 1.5
    # here -> @2x). Each variant must be recolored individually, otherwise
    # HiDPI falls back to the generator's original breeze blue.
    for highlight_image in "$fcitx_theme"/highlight*.png; do
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
  systemd.user.services.fcitx5-noctalia-theme-sync = {
    Unit = {
      Description = "Synchronize Fcitx5 Plasma candidate theme with Noctalia";
      # Ordering only: the palette is written once the shell renders its
      # templates, which happens after the unit is up. No cycle is possible
      # here because this service is not a member of graphical-session.target.
      After = [ "noctalia.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = fcitxThemeSync;
    };
  };

  systemd.user.paths.fcitx5-noctalia-theme-sync = {
    Unit = {
      Description = "Watch the Noctalia color scheme for Fcitx5";
    };
    Path = {
      PathChanged = "%h/.local/share/color-schemes/noctalia.colors";
      Unit = "fcitx5-noctalia-theme-sync.service";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
