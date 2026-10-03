{ ... }:

# Home-manager module, has been imported in dms-with-niri.
#
# Terminal theming for the DMS/niri desktop session only.
#
# Every file referenced here is generated at runtime by DMS matugen from the
# current wallpaper, so the paths cannot be resolved or checked by Nix:
#   ~/.config/alacritty/dank-theme.toml
#   ~/.config/kitty/dank-theme.conf, ~/.config/kitty/dank-tabs.conf
#   ~/.config/ghostty/themes/dankcolors
# All three terminals tolerate the files being absent (they log and ignore),
# so this module is safe to drop when switching to another desktop.
#
# The terminals themselves, their fonts and every desktop-independent
# preference live in modules/home/defaults/terminal.nix. Home Manager merges
# both sides, so the settings below are added to those rather than replacing
# them.

{
  programs.alacritty.settings.general.import = [ "~/.config/alacritty/dank-theme.toml" ];

  programs.kitty.extraConfig = ''
    include dank-theme.conf
    include dank-tabs.conf
  '';

  programs.ghostty.settings.theme = "dankcolors";
}
