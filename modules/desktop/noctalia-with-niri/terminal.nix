{ ... }:

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
# Nix. All three terminals tolerate the theme file being absent (they log and
# ignore), so this module is safe to drop when switching to another desktop.
#
# The terminals themselves, their fonts and every desktop-independent
# preference live in modules/home/defaults/terminal.nix. Home Manager merges
# both sides, so the settings below are added to those rather than replacing
# them.

{
  programs.alacritty.settings.general.import = [ "~/.config/alacritty/themes/noctalia.toml" ];

  programs.kitty.extraConfig = ''
    include themes/noctalia.conf
  '';

  programs.ghostty.settings.theme = "noctalia";
}
