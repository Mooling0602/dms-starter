{ lib, ... }:

{
  networking.firewall.enable = false; # For normal users, firewall is not so useful and causes many errors

  networking.networkmanager.enable = true; # You need Internet!

  networking.hosts = {
    # Add your hosts config here
  };

  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
  }; # Magical cat that can bypass GFW~

  systemd.services.clash-verge = {
    environment.XDG_STATE_HOME = "/run"; # -> /run/clash-verge-service/desired-state.json
    serviceConfig = {
      RuntimeDirectory = lib.mkForce [
        "clash-verge-rev"
        "clash-verge-service"
      ];
      RuntimeDirectoryPreserve = "restart";
    };
  };

  systemd.tmpfiles.rules = [
    "r /var/lib/clash-verge-service/desired-state.json"
  ];
}
