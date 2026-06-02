{ pkgs, ... }:

{
  programs.steam.enable = true;
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
  ];

  # 修复 Dolphin 右键「打开方式」看不到应用的问题
  environment.etc."xdg/menus/applications.menu".source =
    "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  environment.variables = {
    EDITOR = "nvim";
    QT_PLUGIN_PATH = [
      "${pkgs.qt6Packages.qt6ct}/${pkgs.qt6.qtbase.qtPluginPrefix}"
      "${pkgs.kdePackages.breeze}/${pkgs.qt6.qtbase.qtPluginPrefix}"
    ];
  };
}
