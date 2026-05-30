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

  environment.variables.EDITOR = "nvim";
}
