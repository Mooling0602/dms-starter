{ config, lib, pkgs, ... }:

# Home-manager module, has been imported in noctalia-with-niri.
#
# Terminal theming for the Noctalia/niri desktop session only.
#
# Noctalia's built-in templates render the current palette into a per-terminal
# theme file and then try to add the include to the terminal's own config:
#   ~/.config/alacritty/themes/noctalia.toml  ([general] import)
#   ~/.config/kitty/themes/noctalia.conf      (include themes/noctalia.conf)
#   ~/.config/ghostty/themes/noctalia         (theme = noctalia)
# The shipped apply.sh scripts skip that step and print a warning when another
# config would be hidden or cannot be edited, and upstream documents that the
# application config has to stay writable. Home Manager installs these configs
# as read-only store symlinks, so the three settings below declare the same
# include from the declarative side instead.
#
# Every file referenced here is generated at runtime by the shell (template IDs
# alacritty, kitty and ghostty), so the paths cannot be resolved or checked by
# Nix. All three terminals tolerate a missing theme file at run time, but
# ghostty is the exception during activation: home-manager's onFilesChange hook
# runs `ghostty +validate-config` whenever .config/ghostty/config changes, and
# that command exits nonzero while the theme file is absent. The activation
# script runs under `set -e`, so the whole activation stops there and every
# later entry is skipped, including reloadSystemd and the seedNiriCustomConfig
# step in niri.nix. The theme is therefore seeded below, once and only while
# absent, and ordered before onFilesChange; the shell overwrites the
# placeholder with the rendered palette when the session starts.
#
# The terminals themselves, their fonts and every desktop-independent
# preference live in modules/home/defaults/terminal.nix. Home Manager merges
# both sides, so the settings below are added to those rather than replacing
# them.

let
  # The contents do not matter until the shell replaces them, but the file has
  # to exist and parse: a theme file is ghostty config syntax, where only "#"
  # starts a comment ("//" is rejected as an unknown field).
  noctaliaThemePlaceholder = pkgs.writeText "ghostty-noctalia-theme" ''
    # Placeholder written by Home Manager. Noctalia replaces this file with
    # the rendered palette when the shell starts.
  '';
in
{
  programs.alacritty.settings.general.import = [ "~/.config/alacritty/themes/noctalia.toml" ];

  programs.kitty.extraConfig = ''
    include themes/noctalia.conf
  '';

  programs.ghostty.settings.theme = "noctalia";

  # entryBefore rather than entryAfter writeBoundary: the ghostty validation
  # hook lives inside the standard onFilesChange entry, and two entries that
  # both only declare entryAfter writeBoundary have no guaranteed order
  # between them, so the placeholder might arrive too late.
  home.activation.seedGhosttyNoctaliaTheme = lib.hm.dag.entryBefore [ "onFilesChange" ] ''
    theme_file=${lib.escapeShellArg "${config.xdg.configHome}/ghostty/themes/noctalia"}

    if [ ! -e "$theme_file" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p \
        ${lib.escapeShellArg "${config.xdg.configHome}/ghostty/themes"}
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp \
        ${noctaliaThemePlaceholder} \
        "$theme_file"
    fi
  '';
}
