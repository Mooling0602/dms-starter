{ ... }:

{
  # Host specific: smartd needs real SMART capable disks, so virtual machines
  # and other incompatible devices should not enable it by default.
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

  # `wall` must stay enabled: the NixOS smartd module emits the
  # `-m <nomailer> -M exec` hook only when mail, wall or x11 is enabled, so
  # disabling all three would silently drop systembus-notify too.
  systemd.services.smartd.serviceConfig.StateDirectory = "smartmontools";
  services.smartd.extraOptions = [
    "--savestates=/var/lib/smartmontools/smartd."
  ];
}
