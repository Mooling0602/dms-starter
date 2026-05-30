{ config, pkgs, ... }:

{
  services.displayManager.dms-greeter.enable = true;
  services.displayManager.dms-greeter.compositor.name = "niri";

  programs.niri.enable = true;

  programs.firefox.enable = true;
}
