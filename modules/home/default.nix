{ username, hostname, ... }:

let
  optionalImports = import ../../utils/optional_import.nix;
in
{
  imports = optionalImports [
    ../desktop/dms-with-niri/default.nix
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
    ./backup.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.11";
}
