{ username, hostname, ... }:

let
  optionalImports = import ../../utils/optional_import.nix;
in
{
  imports = optionalImports [
    ./defaults/packages.nix
    ./defaults/theme.nix
    ./defaults/desktop.nix
    ./defaults/ssh.nix
    ./defaults/nvchad.nix
    ./defaults/wine.nix
    ./${username}/git.nix
    ./${username}/packages.nix
    ./${username}/avatar.nix
    ./${username}/utils.nix
    ../../hosts/${hostname}/users/${username}.nix
    ./backup.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.11";
}
