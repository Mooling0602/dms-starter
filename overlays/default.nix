# All nixpkgs overlays, aggregated in one list. The order matches the
# original flake.nix wiring; keep it stable when adding entries. Files
# needing flake inputs take the { inputs }: final: prev: signature, the
# rest are plain final: prev: functions.

{ inputs }: [
  # Anime game launcher ecosystem (aagl).
  inputs.aagl.overlays.default
  (import ./qt6ct-kde.nix)
  (import ./xwayland-satellite.nix { inherit inputs; })
  (import ./python-fixes.nix)
  (import ./custom-packages.nix { inherit inputs; })
  (import ./tuxedo-firebat.nix)
  (import ./obs-nvenc-qsv.nix)
]
