{ pkgs, ... }:

# Home-manager module, has been imported in noctalia-with-niri.
#
# Toolkit level pieces that Noctalia's own templates expect to find. The
# templates render the palette into application files at runtime, so only what
# they cannot provide themselves is declared here.
#
# GTK: the gtk3/gtk4 templates write ~/.config/gtk-3.0/noctalia.css and
# ~/.config/gtk-4.0/noctalia.css, then import them from the matching gtk.css and
# select the adw-gtk3 theme, which therefore has to exist. Home Manager's copy
# in the Nix store suffices: the template's own theme lookup walks
# XDG_DATA_DIRS, which includes /etc/profiles/per-user/<user>/share on NixOS.
# Unlike DMS, Noctalia does not patch adw-gtk3 stylesheets in place, so the
# writable copy under ~/.local/share/themes that
# modules/desktop/dms-with-niri/ui.nix creates is not needed here.
#
# Qt: the qt template only writes color schemes to
# ~/.config/qt5ct/colors/noctalia.conf and ~/.config/qt6ct/colors/noctalia.conf.
# The scheme still has to be selected in qt5ct/qt6ct, so qt.enable is
# deliberately left off: it would replace ~/.config/qt6ct/qt6ct.conf with a
# read-only store symlink and that selection could no longer be saved.
#
# The Qt variables below are the ones the DMS layer sets for the same niri
# session. They configure the session rather than a file, so they do not block
# Noctalia from writing its own colors. Fonts, cursors, the icon theme and the
# wallpaper files remain in modules/home/defaults/theme.nix.

{
  home.packages = with pkgs; [ adw-gtk3 ];

  systemd.user.sessionVariables = {
    QT_QPA_PLATFORMTHEME = "qt5ct";
    QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
    QT_WAYLAND_DECORATION = "ssd";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
  };
}
