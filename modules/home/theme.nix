{ pkgs, ... }:

{
  xresources.properties = {
    "Xcursor.size" = 32;
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
      };
    };
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
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
    qt6Packages.qt6ct
    libsForQt5.qt5ct
    kdePackages.breeze
    kdePackages.plasma-integration
    kdePackages.qqc2-desktop-style
    kdePackages.kservice
  ];
}
