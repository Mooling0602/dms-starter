{ pkgs, ... }:

{
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
