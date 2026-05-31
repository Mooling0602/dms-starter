{ config, lib, pkgs, ... }:

{
  programs.git = {
    enable = true;
    settings.user.name = "Mooling0602";
    settings.user.email = "clemooling@outlook.com";
  };
}
