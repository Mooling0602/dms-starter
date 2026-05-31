{ config, lib, pkgs, username, ... }:

{
  imports = [
    ./packages.nix
    ./theme.nix
    ./desktop.nix
    ./git.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.11";
}
