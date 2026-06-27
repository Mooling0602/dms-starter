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

  networking.hostName = config.my.hostname;

  system.stateVersion = "25.11";
}
