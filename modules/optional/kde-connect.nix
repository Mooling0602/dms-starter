{ pkgs, ... }:

# Home-manager module, should be imported in user space
# If using KDE Plasma, this module is not needed and not recommended, as KDE Connect is already integrated into Plasma.

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
