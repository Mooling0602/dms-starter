{ ... }:

{
  # 主机专属：smartd 依赖物理磁盘的 SMART 能力，虚拟机等设备不应默认启用。
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

  # `wall` 不能关：NixOS smartd 模块只有在 mail/wall/x11 至少启用其一，才会
  # 生成 `-m <nomailer> -M exec`，关闭全部会连带丢掉 systembus-notify。
  systemd.services.smartd.serviceConfig.StateDirectory = "smartmontools";
  services.smartd.extraOptions = [
    "--savestates=/var/lib/smartmontools/smartd."
  ];
}
