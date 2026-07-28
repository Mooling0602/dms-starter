{ config, pkgs, ... }:

{
  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = "/home/${config.my.username}";
  };

  programs.niri = {
    enable = true;
    package = pkgs.niri.override { libdisplay-info = pkgs.libdisplay-info_0_2; };
  };

  programs.firefox.enable = true;
}
