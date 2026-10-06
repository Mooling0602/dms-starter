{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    sarasa-gothic
    noto-fonts-cjk-serif
    maple-mono.NF-CN
  ];

  # Make fontconfig use the system-level fonts
  fonts.fontconfig.enable = true;
}
