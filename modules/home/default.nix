{ username, ... }:

{
  imports = [
    ./defaults/packages.nix
    ./defaults/theme.nix
    ./defaults/desktop.nix
    ./defaults/obs.nix
    ./defaults/ssh.nix
    ./defaults/nvchad.nix
    ./defaults/wine.nix
    ./${username}/git.nix
    ./${username}/packages.nix
    ./${username}/avatar.nix
    ./${username}/utils.nix
    ./backup.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.11";
}
