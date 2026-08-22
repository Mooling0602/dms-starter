{ pkgs, ... }:

{
  # OBS 按 NixOS Wiki 推荐的 programs.obs-studio 模块管理：
  # https://wiki.nixos.org/wiki/OBS_Studio
  #
  # package 未显式指定：HM 的 useGlobalPkgs 使其直接使用 flake.nix
  # overlay 后的 obs-studio（NVENC 探测 RUNPATH + ONEVPL_SEARCH_PATH，
  # 见 MAINTENANCE.md「obs-studio 的 NVENC/QSV 硬件编码修复」）。
  # 不引入 obs-vaapi：该插件面向 AMD/旧驱动，Intel 核显用 OBS 内置
  # VAAPI 编码器即可。
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      # wlr-screencopy 屏幕采集源。niri 原生实现该协议，
      # 作为 xdg-desktop-portal 路径之外的备选采集方式。
      wlrobs
      # 应用级音频捕获（按 PipeWire 节点选源），录制单个应用的声音。
      obs-pipewire-audio-capture
      # 为场景中的单个源单独录制文件（例如只录某个窗口/画面）。
      obs-source-record
      # Vulkan/OpenGL 游戏捕获：游戏需以 vkcapture/vkcapture-wayland
      # 包装启动，画面经共享纹理直通 OBS，绕过桌面合成器。
      obs-vkcapture
    ];
  };
}
