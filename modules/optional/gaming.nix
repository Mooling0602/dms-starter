{ pkgs, ... }:

# Require a x86_64 host machine, better with a dedicated graphics card
# system module, can be imported in host/<hostname>

{
  programs.steam = {
    enable = true;
    # extest.enable = true;
    protontricks.enable = true;
  };

  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    gamemode
    mangohud
    gamescope
    umu-launcher
  ];
}
