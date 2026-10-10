{ inputs }:

final: prev:

{
  # Newer than the nixpkgs build; tracks the revision pinned by niri.
  xwayland-satellite = inputs.niri.packages.${final.stdenv.hostPlatform.system}.xwayland-satellite-unstable;
}
