{ lib, pkgs, ... }:

{
  xresources.properties = {
    "Xcursor.size" = 24;
    "Xft.dpi" = 168;
  };

  qt = {
    enable = true;
    platformTheme.name = "qt6ct";
  };

  # Keep GTK2/3/4 in step with niri. For GTK Wayland's first cursor, the dconf
  # value below is authoritative because settings.ini loads too late.
  gtk = {
    enable = true;
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

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      cursor-theme = "breeze_cursors";
      cursor-size = 24;
    };
  };

  systemd.user.sessionVariables = {
    QT_QPA_PLATFORMTHEME = lib.mkForce "qt5ct";
    QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
    QT_WAYLAND_DECORATION = "ssd";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    SSH_ASKPASS = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
  };

  xdg.portal = {
    enable = true;
    config = {
      common = {
        default = [
          "kde"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
      };
      niri = {
        default = [
          "kde"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
      };
    };
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
  };

  # xdg-desktop-portal 1.22 may load every Settings provider referenced by
  # portal preferences. Keep GTK as the only provider until upstream fixes it.
  xdg.dataFile = {
    "xdg-desktop-portal/portals/gnome.portal".text = builtins.replaceStrings
      [ "org.freedesktop.impl.portal.Settings;" ]
      [ "" ]
      (builtins.readFile "${pkgs.xdg-desktop-portal-gnome}/share/xdg-desktop-portal/portals/gnome.portal");
    "xdg-desktop-portal/portals/kde.portal".text = builtins.replaceStrings
      [ "org.freedesktop.impl.portal.Settings;" ]
      [ "" ]
      (builtins.readFile "${pkgs.kdePackages.xdg-desktop-portal-kde}/share/xdg-desktop-portal/portals/kde.portal");
  };

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      sansSerif = [ "Sarasa UI SC" ];
      serif = [ "Sarasa UI SC" ];
      monospace = [ "Maple Mono NF CN" ];
    };
  };

  home.packages = with pkgs; [
    # Fonts
    sarasa-gothic
    noto-fonts-cjk-serif
    maple-mono.NF-CN

    # Icon theme
    tela-icon-theme

    # GTK theme (DMS 动态主题依赖)
    adw-gtk3

    # Qt theming; qt6ct is patched globally in flake.nix.
    qt6Packages.qt6ct
    libsForQt5.qt5ct
    kdePackages.breeze
    kdePackages.plasma-integration
    kdePackages.qqc2-desktop-style
    kdePackages.kservice
  ];

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

}
