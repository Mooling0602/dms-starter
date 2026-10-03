{
  dmsPackage,
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
  ];

  programs.dank-material-shell = {
    enable = true;
    package = dmsPackage;
    enableDynamicTheming = true;
    enableSystemMonitoring = true;
    systemd.enable = true;
  };

  programs.dank-calendar = {
    enable = true;
    systemd.enable = true;
  };
}
