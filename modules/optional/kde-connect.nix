{ pkgs, ... }:

# Home-manager module, should be imported in user space
# Not needed under KDE Plasma, which integrates KDE Connect already.

{
  home.packages = with pkgs; [
    # KDE connect
    kdePackages.kdeconnect-kde
  ];

  systemd.user.services.kdeconnectd = {
    Unit = {
      Description = "KDE Connect daemon";
    };
    Service = {
      Type = "exec";
      ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnectd";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
