# Host specific configuration for this machine. The niri settings live in
# niri-host.nix, which is reached through home-manager.sharedModules because this
# file is imported as a system module.

{
  imports = [
    ../../../../modules/desktop/noctalia-with-niri/system.nix
    ./keyboard-backlight-sync.nix
  ];

  home-manager.sharedModules = [ ./niri-host.nix ];
}
