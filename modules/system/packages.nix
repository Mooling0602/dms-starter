{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  # 排除 GNOME 文件管理器，使用 KDE/Dolphin
  environment.gnome.excludePackages = with pkgs; [
    nautilus
  ];

  environment.systemPackages = with pkgs; [
    git
    vim
    neovim
    curl
    wget
    clash-verge-rev

    # KDE file chooser portal
    kdePackages.xdg-desktop-portal-kde
  ];

  environment.variables = {
    EDITOR = "nvim";
    QT_PLUGIN_PATH = [
      "${pkgs.qt6Packages.qt6ct}/${pkgs.qt6.qtbase.qtPluginPrefix}"
      "${pkgs.kdePackages.breeze}/${pkgs.qt6.qtbase.qtPluginPrefix}"
    ];
  };
}
