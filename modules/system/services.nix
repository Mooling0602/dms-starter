{ config, pkgs, ... }:

{
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.printing.enable = true;

  services.openssh.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.sunshine = {
    enable = true;
    autoStart = true;
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
