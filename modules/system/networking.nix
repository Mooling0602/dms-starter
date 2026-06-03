{ ... }:

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
      # Honkai Star Rail analytics (CN)
      "globaldp-prod-os01.starrails.com"
    ];
  };

  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
  };
}
