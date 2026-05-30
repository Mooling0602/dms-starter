{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

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
