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

  # gpu-screen-recorder 的 KMS 捕获经 pkexec 提权（org.freedesktop.policykit.exec），
  # 默认每次录屏都弹密码。放行 wheel 组本地会话成员对该程序的免密执行：
  # program 匹配 nix store 路径片段 "-gpu-screen-recorder-"，规避版本号漂移。
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.policykit.exec" &&
            subject.isInGroup("wheel") && subject.local) {
            var program = action.lookup("program");
            if (program && program.indexOf("-gpu-screen-recorder-") !== -1) {
                return polkit.Result.YES;
            }
        }
    });
  '';
}
