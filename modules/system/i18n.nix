{ pkgs, ... }:

let
  locale = "zh_CN.UTF-8";  # Change this to set your language environment
in
{
  time.timeZone = "Asia/Shanghai";  # Change this to set your local timezone

  i18n.defaultLocale = locale;

  i18n.extraLocaleSettings = {
    LC_ADDRESS = locale;
    LC_IDENTIFICATION = locale;
    LC_MEASUREMENT = locale;
    LC_MONETARY = locale;
    LC_NAME = locale;
    LC_NUMERIC = locale;
    LC_PAPER = locale;
    LC_TELEPHONE = locale;
    LC_TIME = locale;
  };

  i18n.supportedLocales = [
    "zh_CN.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
  ];

  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      qt6Packages.fcitx5-chinese-addons
      fcitx5-gtk
    ];
  };

  services.xserver.xkb = {
    layout = "cn";
    variant = "";
  };
}
