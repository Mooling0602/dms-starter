{ username, hostname, ... }:

let
  optionalImports = import ../../utils/optional_import.nix;
in
{
  # Desktop-specific modules are not imported here: the active desktop layer
  # pulls in its Home Manager implementation via home-manager.sharedModules
  # (see modules/desktop/<name>/system.nix). Only desktop-independent
  # configuration lives here.
  imports = optionalImports [
    ./defaults/packages.nix
    ./defaults/theme.nix
    ./defaults/ssh.nix
    ./defaults/nvchad.nix
    ./defaults/wine.nix
    ./defaults/terminal.nix
    ./defaults/file-manager.nix
    ./${username}/default.nix
    ./${username}/git.nix
    ./${username}/packages.nix
    ./${username}/avatar.nix
    ../../hosts/${hostname}/users/${username}.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.11";
}
