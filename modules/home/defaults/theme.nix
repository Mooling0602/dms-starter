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
      # On Wayland, Chrome/GTK4 read this via xdg-desktop-portal
      # (Settings -> gtk).
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

    # system-ui is the most common first family on modern websites, but
    # fontconfig does not know it and fuzzy-matches the bitmap "System"
    # (cvgasys.fon) under ~/.local/share/fonts/win-fonts, wrecking system-ui
    # fonts in Chrome. Alias it to the generic sans-serif family so the
    # defaultFonts Sarasa stack takes over. Priority 51 loads it before
    # 52-hm-default-fonts.conf.
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
