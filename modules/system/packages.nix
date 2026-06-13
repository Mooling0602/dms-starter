{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    protontricks.enable = true;
  };
  nixpkgs.config.allowUnfree = true;

  # 排除 GNOME 文件管理器，使用 KDE/Dolphin
  environment.gnome.excludePackages = with pkgs; [
    nautilus
  ];

  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    wget
    nil
    nixd
    clash-verge-rev

    # KDE file chooser portal
    kdePackages.xdg-desktop-portal-kde

    accountsservice

    wineWow64Packages.full

    # Wine 音频支持：pulseaudio 客户端库（配合 pipewire-pulse）
    # winealsa.drv 在 pipewire 下枚举设备可能卡死，用 pulse 后端
    pulseaudio

    winetricks

    # wine64 → wine 软链接（winetricks 在 WoW64 模式下需要 wine64）
    (pkgs.runCommand "wine64-symlink" { } ''
      mkdir -p $out/bin
      ln -s ${wineWow64Packages.full}/bin/wine $out/bin/wine64
    '')
  ];

  # 修复 Dolphin 右键「打开方式」看不到应用的问题
  environment.etc."xdg/menus/applications.menu".source =
    "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  environment.variables = {
    WINEDLLOVERRIDES = "winealsa.drv=d";
    EDITOR = "nvim";
    QT_PLUGIN_PATH = [
      "${pkgs.qt6Packages.qt6ct}/${pkgs.qt6.qtbase.qtPluginPrefix}"
      "${pkgs.kdePackages.breeze}/${pkgs.qt6.qtbase.qtPluginPrefix}"
    ];
  };
}
