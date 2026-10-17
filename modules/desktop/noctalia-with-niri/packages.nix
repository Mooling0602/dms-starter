{ config, pkgs, ... }:

# Home-manager module, has been imported in noctalia-with-niri.

let
  # NiriMod is the only graphical editor for niri configuration; Noctalia has
  # no window rule editor of its own (upstream rejected one, see
  # MAINTENANCE.md). Point the nirimod command at the writable overlay described
  # in niri.nix, so the GUI never targets the declarative config.kdl, which is a
  # read-only store symlink. The desktop entry calls nirimod by name, so it picks
  # up the same wrapper.
  #
  # The injected --config is passed before the user's own arguments, and GLib
  # keeps the last value of a repeated option, so an explicit
  # `nirimod -c other.kdl` still wins. Pass the flag as one bare string: the
  # wrapper hands each --add-flags value over verbatim, and quoting it with
  # lib.escapeShellArg would deliver literal quote characters, which GLib reads
  # as a positional argument and ignores.
  nirimodCustom = pkgs.nirimod.overrideAttrs (old: {
    makeWrapperArgs =
      (old.makeWrapperArgs or [ ])
      ++ [ "--add-flags" "--config=${config.xdg.configHome}/niri-noctalia/custom.kdl" ];
  });
in
{
  home.packages = with pkgs; [
    xwayland-satellite
    nirimodCustom
  ];
}
