{ config, lib, pkgs, ... }:

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
# GTK glass: noctalia-glass-gtk3.css and noctalia-glass-gtk4.css give GTK
# applications a translucent window background. niri's `background-effect`
# blurs what is behind a window, so a window that paints an opaque background
# shows nothing, and no outside process can change how an application paints
# itself. Doing it in the toolkit also keeps text and icons fully opaque,
# which niri's `opacity` cannot: that fades the whole window.
#
# The rules live in their own files because the gtk3/gtk4 templates rewrite
# noctalia.css on every theme and wallpaper change. They are imported from
# gtk.css instead, which the templates leave alone once it mentions
# noctalia.css, and which therefore has to stay a plain writable file. That is
# also why gtk.css is not managed here: apply.sh replaces a read-only store
# symlink with a local copy, so a declarative gtk.css would be undone on the
# next theme change. The activation below only appends the import.
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

  # Copy the glass stylesheets into ~/.config and make sure gtk.css imports
  # them. Both files are written as plain files rather than through
  # xdg.configFile: a store symlink would be a read-only target, and the
  # templates' apply.sh removes such a symlink and replaces it with a local
  # copy, so the declarative version would silently disappear.
  #
  # The import is only added when missing, so a gtk.css the user has edited
  # keeps its own ordering. The glass stylesheet imports noctalia.css itself,
  # so the palette variables are defined whichever import comes first.
  #
  # tee rather than shell redirection: a redirection would already truncate the
  # file during a --dry-run activation, where only the command itself is
  # skipped.
  home.activation.installGtkGlass = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    glass_home="${config.xdg.configHome}"
    for version in 3.0 4.0; do
      case "$version" in
        3.0) glass_source=${./noctalia-glass-gtk3.css} ;;
        4.0) glass_source=${./noctalia-glass-gtk4.css} ;;
      esac
      theme_dir="$glass_home/gtk-$version"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$theme_dir"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0644 "$glass_source" \
        "$theme_dir/noctalia-glass.css.tmp"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv -f \
        "$theme_dir/noctalia-glass.css.tmp" "$theme_dir/noctalia-glass.css"

      gtk_css="$theme_dir/gtk.css"
      if [ -L "$gtk_css" ]; then
        # apply.sh converts a read-only symlink into a local file; do the same
        # here instead of writing through it, which would fail in the store.
        if [ -w "$gtk_css" ]; then
          gtk_css=$(${pkgs.coreutils}/bin/readlink -f "$gtk_css")
        else
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "$gtk_css"
        fi
      fi
      if [ -e "$gtk_css" ]; then
        if ! ${pkgs.gnugrep}/bin/grep -q 'noctalia-glass\.css' "$gtk_css"; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/chmod u+w "$gtk_css"
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/tee -a "$gtk_css" <<'GLASS_IMPORT'

@import url("noctalia-glass.css");
GLASS_IMPORT
        fi
      else
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/tee "$gtk_css" <<'GLASS_IMPORT'
@import url("noctalia.css");
@import url("noctalia-glass.css");
GLASS_IMPORT
      fi
    done
  '';

  systemd.user.sessionVariables = {
    QT_QPA_PLATFORMTHEME = "qt5ct";
    QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
    QT_WAYLAND_DECORATION = "ssd";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
  };
}
