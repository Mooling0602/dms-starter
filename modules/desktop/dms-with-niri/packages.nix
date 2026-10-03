{ pkgs, ... }:

# Home-manager module, has been imported in dms-with-niri.

{
  home.packages = with pkgs; [ xwayland-satellite ];
}
