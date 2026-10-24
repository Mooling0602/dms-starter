{ lib, ... }:

# Home-manager module, reached through home-manager.sharedModules in
# ./default.nix: host desktop directories are imported as system modules, so
# they cannot set Home Manager options directly.
#
# Replaces the desktop layer's empty niri-noctalia/host.kdl, which is included
# at the end of the shared niri config.

{
  xdg.configFile."niri-noctalia/host.kdl".source = lib.mkForce ./niri-host.kdl;
}
