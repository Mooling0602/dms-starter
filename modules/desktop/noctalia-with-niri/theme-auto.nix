{
  pkgs,
  ...
}:

# Home-manager module, can be imported in user space.
# Time based light/dark switching for the noctalia-with-niri layer.
#
# [theme] mode = "auto" is declared in ./default.nix; this module supplies what
# the auto schedule needs and keeps the wallpaper in step with it.

let
  # Noctalia resolves "auto" from [location]: auto_locate (IP geolocation) wins,
  # then a non-empty address (geocoded), then manual latitude/longitude. The VM's
  # IP would geolocate to the provider's datacenter, so the coordinates are
  # pinned instead: Fuzhou, Jiangxi, which needs no network round trip and cannot
  # drift. custom_schedule stays off, because enabling it requires both sunset
  # and sunrise as HH:MM and would otherwise be a config error; the real
  # sunrise/sunset for these coordinates come from the local solar calculation.
  #
  # The coordinates also feed the weather and night light services, but both keep
  # their own defaults here (weather was already enabled, night light stays off),
  # so nothing beyond the schedule is switched on by this table.
  location = {
    auto_locate = false;
    address = "";
    custom_schedule = false;
    latitude = 27.9494;
    longitude = 116.3582;
  };

  # Noctalia flips its own palette when the schedule crosses sunrise/sunset, but
  # the wallpaper image is a separate decision: wallpaper.cpp picks a path only
  # in the picker, in switchWallpaperTo() and in the optional rotation
  # automation, and wallpaper.directory_light / directory_dark merely choose
  # which directory those pick from. Nothing re-applies an image on a mode
  # change, so the light/dark pair installed by modules/home/defaults/theme.nix
  # is selected here instead.
  #
  # Two hooks share one script:
  #   theme_mode_changed  carries NOCTALIA_THEME_MODE in the environment. Hooks
  #                       run through /bin/sh -lc, and the manager forks the
  #                       command before it unsets the variables it exported for
  #                       the hook, so the value is readable.
  #   started             fires once per shell start and exports nothing, so the
  #                       script asks the running shell instead. The first
  #                       resolution of a session cannot fire theme_mode_changed:
  #                       that hook is guarded by "the previous mode is known", so
  #                       without this hook a login in light mode would keep the
  #                       dark image from the config seed until the next sunset.
  #
  # noctalia is called by absolute path: a hook inherits the session PATH only
  # because niri started it, and a store path cannot go stale or be shadowed.
  themeWallpaperHook = pkgs.writeShellScript "noctalia-theme-wallpaper" ''
    set -eu

    noctalia="${pkgs.noctalia}/bin/noctalia"
    wallpaperDir="$HOME/.local/share/wallpapers"

    # theme-mode-get prints the resolved mode (light or dark), never the
    # configured one, so it answers correctly for an auto schedule too.
    attempt=0
    while :; do
      mode="''${NOCTALIA_THEME_MODE:-}"
      [ -n "$mode" ] || mode="$("$noctalia" msg theme-mode-get 2>/dev/null || true)"
      [ -n "$mode" ] && break
      attempt=$((attempt + 1))
      [ "$attempt" -lt 10 ] || exit 0
      sleep 1
    done

    case "$mode" in
      light) wallpaper="$wallpaperDir/wallpaper-light.png" ;;
      dark) wallpaper="$wallpaperDir/wallpaper-dark.png" ;;
      *) exit 0 ;;
    esac

    [ -f "$wallpaper" ] || exit 0

    # wallpaper-set returns early when the path is unchanged, so this is only
    # about skipping the round trip and leaving settings.toml untouched.
    if [ "$("$noctalia" msg wallpaper-get 2>/dev/null || true)" = "$wallpaper" ]; then
      exit 0
    fi

    # started runs immediately after the IPC server comes up, while the wallpaper
    # service may still be settling, so retry briefly rather than lose the sync
    # until the next mode flip. Hooks run asynchronously, so sleeping here does
    # not hold up the shell.
    attempt=0
    while ! "$noctalia" msg wallpaper-set "$wallpaper" >/dev/null 2>&1; do
      attempt=$((attempt + 1))
      [ "$attempt" -lt 10 ] || exit 0
      sleep 1
    done
  '';
in
{
  programs.noctalia.settings = {
    inherit location;

    hooks = {
      started = "${themeWallpaperHook}";
      theme_mode_changed = "${themeWallpaperHook}";
    };
  };
}
