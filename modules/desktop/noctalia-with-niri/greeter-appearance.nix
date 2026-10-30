{ config, pkgs, lib, ... }:

# System module, imported by system.nix next to greeter.nix: what the login
# screen looks like, and which of the two modes it opens in.
#
# Two gaps this closes, both consequences of dms-greeter reading a snapshot of
# state that only the logged-in desktop ever updates:
#
# 1. No palette. dms-greeter reads /var/lib/dms-greeter/colors.json and resolves
#    colors[isLightMode ? "light" : "dark"]; nothing in this configuration
#    produced that file, so the login screen fell back to its hardcoded blue.
#
# 2. Wrong mode. isLightMode and wallpaperPath come from session.json, which
#    Noctalia writes while the user is logged in. The greeter runs before that,
#    so after a shutdown and a boot at another time of day it still shows the
#    last session: log in during the day, shut down, boot at night, and the login
#    screen comes back in its light appearance. The greeter has no clock-based
#    fallback of its own; it reads isLightMode verbatim.
#
# The palette is derived from the two wallpapers with matugen. Both wallpapers
# are declared in modules/home/defaults/theme.nix from this repository's own
# assets, so the result is a pure function of files Nix already has: it is built
# as a store path, which means it cannot be stale. A single matugen pass cannot
# produce both halves, because the light and dark wallpapers are different
# pictures, so the palette is derived twice.
#
# The mode depends on the clock, so it cannot be built; a oneshot service runs
# before greetd and rewrites the fields the greeter reads. It edits the *source*
# session.json, not /var/lib/dms-greeter/session.json: greetd's preStart copies
# the home file over the greeter one on every boot, so an edit there would only
# survive until the next start.

let
  user = config.my.username;

  # The wallpapers are installed into the home directory by
  # modules/home/defaults/theme.nix from these same asset files.
  lightWallpaper = ../../../assets/wallpaper-light-kokomi.png;
  darkWallpaper = ../../../assets/wallpaper-dark-cyrene.png;

  # dms-greeter calls getMatugenColor() for exactly these roles. Anything absent
  # falls back to the greeter's hardcoded blue, so the list is kept exact.
  roles = [
    "background"
    "on_background"
    "primary"
    "on_primary"
    "primary_container"
    "secondary"
    "surface"
    "surface_variant"
    "on_surface_variant"
    "surface_container"
    "surface_container_high"
    "surface_tint"
    "outline"
  ];

  # One half of colors.json. `mode` becomes the outer key the greeter indexes by.
  # Written with writeText rather than substituted into the build script:
  # substitute() would treat the {{ }} matugen placeholders as shell variables.
  paletteTemplate = mode:
    pkgs.writeText "dms-greeter-colors-template-${mode}.json" ''
      {
        "colors": {
          "${mode}": {
      ${lib.concatStringsSep ",\n" (
        map (role: ''        "${role}": "{{ colors.${role}.default.hex }}"'') roles
      )}
          }
        }
      }
    '';

  # matugen derives a Material 3 scheme from an image; -m selects which half of
  # the scheme to emit, and each pass is fed the wallpaper that mode displays.
  palette = pkgs.runCommand "dms-greeter-colors.json" { nativeBuildInputs = [ pkgs.matugen pkgs.jq ]; } ''
    mkdir -p work
    # matugen writes its cache under $HOME, which is /homeless-shelter in the
    # sandbox and therefore unwritable.
    export HOME=$PWD

    run() {
      mode=$1
      image=$2
      tpl=$3
      cat > "work/config-$mode.toml" <<EOF
    [config]
    version_check = false
    caching = false

    [templates.greeter]
    input_path = "$tpl"
    output_path = "$PWD/work/$mode.json"
    EOF
      ${lib.getExe pkgs.matugen} image "$image" -m "$mode" \
        -c "work/config-$mode.toml" \
        --prefer closest-to-fallback --fallback-color "#ffbf9b"
    }

    run light ${lightWallpaper} ${paletteTemplate "light"}
    run dark ${darkWallpaper} ${paletteTemplate "dark"}

    jq -s '.[0] * .[1]' work/light.json work/dark.json > $out
  '';

  # Stamped with the shared coordinates so the login screen and Noctalia's own
  # auto schedule cross sunrise and sunset at the same moment. sed rather than
  # substitute(): the command-line form of that helper only accepts the
  # --replace-* flags, not --subst-var-by.
  solarMode = pkgs.runCommand "greeter-solar-mode" { } ''
    sed -e 's|@LAT@|${toString config.my.solarLocation.latitude}|' \
        -e 's|@LON@|${toString config.my.solarLocation.longitude}|' \
      ${./solarmode.py.in} > solarmode.py
    # Fails the build rather than shipping a script that cannot start.
    ${lib.getExe pkgs.python3} -c 'import ast, sys; ast.parse(open("solarmode.py").read())'
    install -m 0755 solarmode.py $out
  '';

  syncMode = pkgs.writeShellApplication {
    name = "greeter-sync-mode";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      set -eu

      session="''${HOME:-/home/${user}}/.local/state/DankMaterialShell/session.json"
      # Noctalia writes this file; before its first run there is nothing to fix
      # and the greeter keeps its own defaults.
      [ -f "$session" ] || exit 0

      case "$(${solarMode})" in
        light)
          light=true
          wallpaper="''${HOME:-/home/${user}}/.local/share/wallpapers/wallpaper-light.png"
          ;;
        dark)
          light=false
          wallpaper="''${HOME:-/home/${user}}/.local/share/wallpapers/wallpaper-dark.png"
          ;;
      esac
      [ -f "$wallpaper" ] || exit 0

      # wallpaperPath is the only field the greeter reads for the background: it
      # ignores wallpaperPathLight and wallpaperPathDark when choosing what to
      # show. Both are rewritten anyway so the file cannot end up describing a
      # light palette over a dark wallpaper if anything later reads them.
      updated=$(jq --arg wp "$wallpaper" --argjson light "$light" \
        '.isLightMode = $light | .wallpaperPath = $wp' "$session")

      if [ "$updated" != "$(cat "$session")" ]; then
        printf '%s\n' "$updated" > "$session.tmp"
        mv "$session.tmp" "$session"
      fi
    '';
  };
in
{
  # greetd's preStart copies ~/.cache/DankMaterialShell/dms-colors.json into its
  # own directory and renames it to colors.json, so the file has to exist in the
  # home directory. Linking it at the store path keeps a single source of truth
  # and never needs a sync step of its own.
  systemd.tmpfiles.rules = [
    "d /home/${user}/.cache/DankMaterialShell 0755 ${user} users -"
    "L+ /home/${user}/.cache/DankMaterialShell/dms-colors.json - - - - ${palette}"
  ];

  # Ordered before greetd so the corrected session.json is the one preStart
  # copies: the mode is then right on the first login screen of the boot, not one
  # login behind.
  systemd.services.greetd-sync-mode = {
    description = "Set the greeter's light or dark appearance from the current sun position";
    wantedBy = [ "greetd.service" ];
    before = [ "greetd.service" ];
    # The file being rewritten lives in the desktop user's home, so this runs as
    # that user; greetd's preStart runs as root and only reads it.
    serviceConfig = {
      Type = "oneshot";
      User = user;
      ExecStart = "${syncMode}/bin/greeter-sync-mode";
    };
  };
}
