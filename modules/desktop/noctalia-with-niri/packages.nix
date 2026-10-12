{ pkgs, ... }:

# Home-manager module, has been imported in noctalia-with-niri.

{
  home.packages = with pkgs; [ xwayland-satellite ];
}
