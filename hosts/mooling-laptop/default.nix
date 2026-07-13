{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./gpu.nix
    # ./streaming.nix
    ../../modules/system/config.nix
    ../../modules/system/i18n.nix
    ../../modules/system/desktop.nix
    ../../modules/system/fonts.nix
    ../../modules/system/networking.nix
    ../../modules/system/nix.nix
    ../../modules/system/packages.nix
    ../../modules/system/services.nix
    ../../modules/system/users.nix
    ../../modules/system/virtualisation.nix
  ];

  boot.loader = {
    efi.canTouchEfiVariables = true;
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 10;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.resumeDevice = "/dev/disk/by-uuid/c531a6ba-9945-42f0-821b-9a0553fe100d";

  networking.hostName = config.my.hostname;

  services.howdy.settings.video.device_path =
    "/dev/v4l/by-id/usb-Sonix_Technology_Co.__Ltd._BisonCam_NB_Pro-video-index0";

  system.stateVersion = "25.11";
}
