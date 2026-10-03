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

  # Disk health monitoring. smartd polls SMART data, logs warnings to the
  # journal, and raises a desktop notification when a drive reports failing
  # health, a new error-log entry, or an out-of-range temperature.
  #
  # systembus-notify forwards warnings to the session's D-Bus notification
  # daemon (DMS), which is the only channel visible inside a Niri/Wayland
  # session - `wall` and X11 messages have nowhere to land. `wall` is
  # nonetheless left on deliberately: the NixOS smartd module only emits the
  # `-m <nomailer> -M exec` hook that runs the notification script when mail,
  # wall or x11 is enabled, so disabling all three would silently drop
  # systembus-notify as well. It is harmless on this single-user machine.
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications = {
      systembus-notify.enable = true;
      x11.enable = false;
    };
    # -a          monitor health, attributes, and the error/self-test logs
    # -s ...      short self-test daily at 02:xx; extended test on Sunday 04:xx
    #             (NVMe uses 'S' = short, 'L' = extended; see smartd.conf(5))
    # -W 2,65,75  report 2 °C swings, log at 65 °C, warn at 75 °C. The NVMe
    #             composite sensor idles around 57 °C on this laptop, so a 60 °C
    #             INFO threshold would log on ordinary load spikes.
    defaults.monitored = "-a -s (S/../.././02|L/../../7/04) -W 2,65,75";
  };

  # Persist smartd state (last self-test time, min/max temperatures, sent-warning
  # bookkeeping) across restarts and reboots.
  systemd.services.smartd.serviceConfig.StateDirectory = "smartmontools";
  services.smartd.extraOptions = [
    "--savestates=/var/lib/smartmontools/smartd."
  ];

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
