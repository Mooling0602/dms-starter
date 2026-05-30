{ config, pkgs, ... }:

{
  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = "/home/mooling";
  };

  programs.niri.enable = true;

  programs.firefox.enable = true;
}
