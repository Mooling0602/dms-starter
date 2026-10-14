{ config, hostname, ... }:

let
  # Desktop module in use, matching ./desktop/<desktop>/.
  # Must be a let binding: imports evaluate before config, so referring to
  # config.my.desktop here would recurse infinitely.
  desktop = "dms-with-niri";
  # desktop = "kde-plasma";
in

{
  # Device identity, the only part that differs per host. flake.nix enumerates
  # host directories and injects the directory name; username and hostname are
  # declared here so other devices never conflict with this one.
  my.username = "mooling";
  my.hostname = hostname;
  my.desktop = desktop;

  imports = [
    ./hardware-configuration.nix
    ./clash-verge-fix.nix
    ../../modules/system/config.nix
    ../../modules/system/i18n.nix
    ../../modules/system/fonts.nix
    ../../modules/system/networking.nix
    ../../modules/system/keyring.nix
    ../../modules/system/nix.nix
    ../../modules/system/packages.nix
    ../../modules/system/services.nix
    ../../modules/system/users.nix
    ../../modules/system/virtualisation.nix
    ../../modules/system/obs.nix
    ./desktop/${desktop}/default.nix
    # Switching desktop: change the let binding above and prepare
    # <host>/desktop/<new desktop>/.
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = config.my.hostname;

  system.stateVersion = "26.11";
}
