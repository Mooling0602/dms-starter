{ pkgs, ... }:

# Home-manager module, has been imported by default.

{
  services.ssh-agent.enable = true;

  systemd.user.sessionVariables = {
    SSH_ASKPASS = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
  };
}
