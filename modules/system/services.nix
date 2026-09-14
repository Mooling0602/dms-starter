{ ... }:

{
  services.flatpak.enable = true;
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  services.thermald.enable = true;
  services.accounts-daemon.enable = true;

  # Dolphin/Solid uses UDisks2 to discover, mount, and safely eject removable
  # storage devices such as USB drives.
  services.udisks2.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.printing.enable = true;

  services.openssh.enable = true;
  
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
