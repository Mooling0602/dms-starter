{ config, ... }:

{
  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = "/home/${config.my.username}";
  };

  programs.niri.enable = true;

  programs.firefox.enable = true;
}
