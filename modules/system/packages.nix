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
  ];

  environment.variables.EDITOR = "nvim";
}
