{ pkgs, ... }:

# Home-manager module, has been imported by default.

{
  services.ssh-agent.enable = true;

  systemd.user.sessionVariables = {
    SSH_ASKPASS = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";

    # qtkeychain 与 Chromium 用的是同一套桌面环境探测（源码注释写明 derived
    # from chromium, base/nix/xdg_util.cc）：KDE 下自动选 KWallet，niri 不匹配
    # 任何枚举、落进 DesktopEnv_Other 而选 libsecret。ksshaskpass 存口令用的是
    # org.qt.keychain 这个 schema，条目落在 gnome-keyring 里；切到 KDE 后
    # qtkeychain 改去 KWallet 找，找不到就只能弹框，自动解锁随之失效。
    # 钉死 libsecret 后两个桌面共用同一份。见 MAINTENANCE.md。
    QTKEYCHAIN_BACKEND = "libsecret";
  };
}
