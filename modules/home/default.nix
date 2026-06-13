{ username, ... }:

{
  imports = [
    ./packages.nix
    ./theme.nix
    ./desktop.nix
    ./git.nix
    ./ssh.nix
    ./nvchad.nix
    ./backup.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.11";

  home.sessionVariables = {
    WINEDLLOVERRIDES = "winealsa.drv=d";
  };
}
