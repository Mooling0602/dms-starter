{ config, ... }:

{
  # OBS 虚拟摄像头（v4l2loopback）：让视频会议软件把 OBS 输出
  # 当作摄像头设备使用。按 NixOS Wiki 推荐的内核选项手动配置：
  # https://wiki.nixos.org/wiki/OBS_Studio#Using_the_Virtual_Camera
  #
  # Home Manager 的 programs.obs-studio 无 enableVirtualCamera
  # （内核模块属系统层），故在此单独声明。
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];
  # 不加入 boot.kernelModules：NixOS 断言 v4l2loopback 常驻加载会破坏
  # Howdy 人脸认证（本机 sudo 依赖它）。模块按需加载——OBS 启动
  # 虚拟摄像头时经 polkit 授权 modprobe v4l2loopback。
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
  '';

  # v4l2loopback 设备访问需要 polkit 授权。
  security.polkit.enable = true;
}
