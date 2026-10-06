{ pkgs, lib, ... }:

# Home-manager module, has been imported in dms-with-niri.

{
  home.packages = with pkgs; [
    # GTK theme (DMS dynamic theme dependencies)
    adw-gtk3
  ];

  home.overwriteBackup = true;

  # DMS updates adw-gtk3's stylesheets in place when applying its Matugen
  # palette. A package installed through Home Manager is immutable in the Nix
  # store, while DMS only discovers mutable copies below ~/.local/share/themes.
  # Do not use home.file here: it would create another read-only store symlink.
  home.activation.installDmsAdwGtk3 = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dms_gtk_theme_source="${pkgs.adw-gtk3}/share/themes"
    dms_gtk_theme_target="$HOME/.local/share/themes"

    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$dms_gtk_theme_target"
    for dms_gtk_theme in adw-gtk3 adw-gtk3-dark; do
      dms_gtk_theme_path="$dms_gtk_theme_target/$dms_gtk_theme"
      if [ ! -e "$dms_gtk_theme_path" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp -a \
          "$dms_gtk_theme_source/$dms_gtk_theme" \
          "$dms_gtk_theme_target/"
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/chmod -R u+w "$dms_gtk_theme_path"
      fi
    done
  '';

  qt = {
    enable = true;
    platformTheme.name = "qt6ct";
  };

  # Keep GTK2/3/4 in step with niri. For GTK Wayland's first cursor, the dconf
  # value below is authoritative because settings.ini loads too late.
  gtk = {
    enable = true;
    # Chrome/Electron read font-name through GTK/portal. Without this setting
    # the default "Adwaita Sans" makes fontconfig's generic match land on
    # Noto Sans CJK KR.
    font = {
      package = pkgs.sarasa-gothic;
      name = "Sarasa UI SC";
      size = 11;
    };
    cursorTheme = {
      package = pkgs.kdePackages.breeze;
      name = "breeze_cursors";
      size = 24;
    };
    gtk3 = {
      extraConfig = {
        gtk-icon-theme-name = "Tela-light";
      };
    };
  };

  systemd.user.sessionVariables = {
    QT_QPA_PLATFORMTHEME = lib.mkForce "qt5ct";
    QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
    QT_WAYLAND_DECORATION = "ssd";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
  };
}
