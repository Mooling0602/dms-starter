{ pkgs, ... }:

# Require a x86_64 host machine, better with a dedicated graphics card

{
  programs.steam = {
    enable = true;
    protontricks.enable = true;
  };

  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    gamemode
    mangohud
    umu-launcher
  ];
}
