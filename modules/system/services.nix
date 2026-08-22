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
    };
  };

  # greetd delegates authentication to the login PAM stack. Face authentication
  # cannot provide the password needed to unlock GNOME Keyring.
  security.pam.services.greetd.howdy.enable = false;
  security.pam.services.login.howdy.enable = false;

  # DMS uses a dedicated PAM service for the lock screen.
  security.pam.services.dankshell.howdy.enable = true;

  # polkit-1（图形授权弹窗）禁用人脸认证：pam_howdy 在摄像头不可用
  # （被视频通话占用、光线过暗等）时以 "conversation failed" 退出，
  # 会污染整个 PAM 会话，导致随后 pam_unix 的密码认证也一并失败
  # （表现为弹窗输正确密码仍被拒）。图形弹窗场景摄像头恰好多半被占，
  # 直接走密码认证最稳。sudo（终端）栈的人脸认证不受影响。
  security.pam.services.polkit-1.howdy.enable = false;

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
