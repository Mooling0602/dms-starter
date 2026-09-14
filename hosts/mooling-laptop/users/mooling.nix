{ hostname, ... }:

{
  programs.git.settings.user.signingkey = "~/.ssh/key-${hostname}.pub";
}
