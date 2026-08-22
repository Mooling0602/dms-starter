{ pkgs, ... }:

{
  networking.firewall.enable = false;

  networking.networkmanager.enable = true;

  networking.hosts = {
    "0.0.0.0" = [
      # Honkai Impact 3rd / Honkai Star Rail analytics (global)
      "log-upload-os.hoyoverse.com"
      "sg-public-data-api.hoyoverse.com"
      "dump.gamesafe.qq.com"
      # Honkai Impact 3rd / Honkai Star Rail analytics (CN)
      "log-upload.mihoyo.com"
      "public-data-api.mihoyo.com"
      # NOTE: globaldp-prod-os01.* are NOT analytics - they are the game data /
      # anti-cheat (HoYoProtect) channel. Blocking them breaks game launch with
      # a misleading "ZwLoadDriver failed HoYoProtect" / "initDriver Failed
      # [4,643,0]" crash (see yaagl/yet-another-anime-game-launcher#697).
    ];
  };

  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
  };

  # Bypass Mihomo TUN for local subnet and SSDP multicast (required for UPnP)
  systemd.services.clash-verge-upnp-bypass = {
    description = "Add routing rules to bypass Mihomo TUN for UPnP/SSDP";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.runtimeShell} -c \"${pkgs.iproute2}/bin/ip rule add from 192.168.6.236 to 192.168.6.0/24 lookup main priority 8997 || true ; ${pkgs.iproute2}/bin/ip rule add to 239.255.255.250/32 lookup main priority 8998 || true\"";
      ExecStop = "${pkgs.runtimeShell} -c \"${pkgs.iproute2}/bin/ip rule del priority 8997 || true ; ${pkgs.iproute2}/bin/ip rule del priority 8998 || true\"";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
