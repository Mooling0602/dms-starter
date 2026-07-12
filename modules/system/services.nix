{ ... }:

{
  services.flatpak.enable = true;
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  services.thermald.enable = true;
  services.accounts-daemon.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.printing.enable = true;

  services.openssh.enable = true;

  services.howdy = {
    enable = true;
    control = "sufficient";
    settings = {
      core = {
        abort_if_ssh = false;
        detection_notice = true;
      };
      video.device_path = "/dev/v4l/by-id/usb-Sonix_Technology_Co.__Ltd._BisonCam_NB_Pro-video-index0";
    };
  };

  # services.envfs = {
  #   enable = true;
  #   extraFallbackPathCommands = ''
  #     ln -s ${pkgs.coreutils}/bin/true $out/true
  #   '';
  # };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

}
