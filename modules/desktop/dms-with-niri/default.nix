{
  dms,
  pkgs,
  ...
}:

# Home-manager module, can be imported in user space.

let
  optionalImports = import ../../../utils/optional_import.nix;
in
{
  imports = optionalImports [
    ./terminal.nix
    ./ui.nix
    ./xdg-portals.nix
    ./packages.nix
    ./fcitx-theme-sync.nix
    ./backup.nix
  ];

  programs.dank-material-shell = {
    enable = true;
    # Use this desktop's own flake input; flake.nix no longer needs a dmsPackage
    # overlay or to thread it through extraSpecialArgs to every user's
    # Home Manager modules.
    package = dms.packages.${pkgs.stdenv.hostPlatform.system}.default;
    enableDynamicTheming = true;
    enableSystemMonitoring = true;
    systemd.enable = true;
  };

  programs.dank-calendar = {
    enable = true;
    systemd.enable = true;
  };

  # Moved down from the hardcoded home-manager.users.<name> in flake.nix so it
  # stays inactive when this desktop is not selected.
  programs.dsearch.enable = true;
}
