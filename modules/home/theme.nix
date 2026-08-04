{ pkgs, ... }:

{
  xresources.properties = {
    "Xcursor.size" = 24;
    "Xft.dpi" = 168;
  };

  qt = {
    enable = true;
    platformTheme.name = "qt6ct";
  };

  systemd.user.sessionVariables = {
    QT_QPA_PLATFORMTHEME = "qt6ct";
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

    # Qt theming
    # qt6ct with KColorScheme support (AUR qt6ct-kde shenanigans patch)
    (qt6Packages.qt6ct.overrideAttrs (finalAttrs: previousAttrs: {
      buildInputs = (previousAttrs.buildInputs or []) ++ [
        kdePackages.kconfig
        kdePackages.kcolorscheme
        kdePackages.kiconthemes
      ];
      patches = (previousAttrs.patches or []) ++ [
        (fetchpatch {
          url = "https://aur.archlinux.org/cgit/aur.git/plain/qt6ct-shenanigans.patch?h=qt6ct-kde";
          hash = "sha256-CAFsup46roQUqOzJ9Xl1x2oC2YD7QtrX/vD2k1CsCR8=";
        })
      ];
    }))
    libsForQt5.qt5ct
    kdePackages.breeze
    kdePackages.plasma-integration
    kdePackages.qqc2-desktop-style
    kdePackages.kservice
  ];

}
