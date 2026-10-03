{ pkgs, ... }:

# Home-manager module, has been imported by default.

{
  xresources.properties = {
    "Xcursor.size" = 24;
    "Xft.dpi" = 144;
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      cursor-theme = "breeze_cursors";
      cursor-size = 24;
      # Wayland 下 Chrome/GTK4 经 xdg-desktop-portal(Settings→gtk) 读此值
      font-name = "Sarasa UI SC 11";
    };
  };

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      sansSerif = [ "Sarasa UI SC" ];
      serif = [ "Sarasa UI SC" ];
      monospace = [ "Maple Mono NF CN" ];
    };

    # system-ui 是现代网站最常用的首选 family，fontconfig 不认识它，
    # 会泛匹配到 ~/.local/share/fonts/win-fonts 里的位图 "System" (cvgasys.fon)，
    # 导致 Chrome 中 system-ui 页面字体失控。将其别名到 sans-serif 通用族，
    # 交由 defaultFonts 的更纱黑体接管。priority 51 确保先于
    # 52-hm-default-fonts.conf 加载。
    configFile.system-ui-alias = {
      enable = true;
      priority = 51;
      text = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        <fontconfig>
          <description>Map system-ui to the sans-serif stack</description>
          <alias binding="same">
            <family>system-ui</family>
            <prefer><family>sans-serif</family></prefer>
          </alias>
        </fontconfig>
      '';
    };
  };

  # Pretty beautiful wallpapers from the Internet (in assets/ resource folder)
  home.file.".local/share/wallpapers/wallpaper-light.png".source =
    ../../../assets/wallpaper-light-kokomi.png;
  home.file.".local/share/wallpapers/wallpaper-dark.png".source =
    ../../../assets/wallpaper-dark-cyrene.png;

  home.packages = with pkgs; [
    # Fonts
    sarasa-gothic
    noto-fonts-cjk-serif
    maple-mono.NF-CN

    # Icon theme
    tela-icon-theme

    # Qt theming and some kde utils; qt6ct is patched globally in flake.nix.
    qt6Packages.qt6ct
    libsForQt5.qt5ct
    kdePackages.breeze
    kdePackages.plasma-integration
    kdePackages.qqc2-desktop-style
    kdePackages.kservice
  ];
}
