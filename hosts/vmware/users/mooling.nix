{ lib, ... }:

{
  programs.git.settings.user = {
    name = lib.mkForce "MoolingBot";
    email = lib.mkForce "agent@staringplanet.top";
    signingkey = "~/.ssh/id_ed25519.pub";
  };
}
