{ config, pkgs, lib, ... }:

lib.mkIf (config.my.hostname == "mooling-laptop") {
  services.apollo = {
    enable = true;
    capSysAdmin = true;
    openFirewall = true;
    settings = {
      adapter_name = "/dev/dri/renderD128";
      capture = "kms";
      locale = "zh_CN";
      upnp = "enabled";
      native_pen_touch = "enabled";
      output_name = "1";
    };
  };
}
