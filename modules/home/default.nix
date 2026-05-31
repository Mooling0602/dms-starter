{ config, lib, pkgs, ... }:

{
  imports = [
    ./packages.nix
    ./theme.nix
    ./desktop.nix
    ./git.nix
  ];

  home.username = "mooling";
  home.homeDirectory = "/home/mooling";
  home.stateVersion = "25.11";
}
