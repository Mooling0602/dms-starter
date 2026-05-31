{ config, pkgs, ... }:

{
  fonts.packages = with pkgs; [
    sarasa-gothic
    noto-fonts-cjk-serif
    maple-mono.NF-CN
  ];

  # 让 fontconfig 对系统级字体生效
  fonts.fontconfig.enable = true;
}
