{ config, pkgs, ... }:

{
  # 排除 GNOME 文件管理器，使用 KDE/Dolphin
  environment.gnome.excludePackages = with pkgs; [
    nautilus
  ];

  fonts.packages = with pkgs; [
    sarasa-gothic
    noto-fonts-cjk-serif
    maple-mono.NF-CN
  ];

  # 让 fontconfig 对系统级字体生效
  fonts.fontconfig.enable = true;
}
