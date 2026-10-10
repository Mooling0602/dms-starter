{ pkgs, inputs, ... }:

# Require a x86_64 host machine, better with a dedicated graphics card
# system module, can be imported in host/<hostname>

{
  programs.steam = {
    enable = true;
    # extest.enable = true;
    protontricks.enable = true;
    # Scoped to this module: only hosts importing gaming.nix get dw-proton,
    # unlike the former global wiring in flake.nix.
    extraCompatPackages = [
      inputs.dw-proton.packages.x86_64-linux.dw-proton
    ];
  };

  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    gamemode
    mangohud
    gamescope
    umu-launcher
  ];
}
