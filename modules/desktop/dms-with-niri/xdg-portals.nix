{ pkgs, ... }:

# Home-manager module, has been imported in dms-with-niri.

{
  xdg.portal = {
    enable = true;
    config = {
      common = {
        default = [
          "kde"
          "gtk"
        ];
        "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
        "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
        # ScreenCast/Screenshot/RemoteDesktop 必须走 gnome 后端：
        # kde 后端依赖 KWin DBus 接口，niri 会话下不存在；
        # niri 实现 org.gnome.Mutter.ScreenCast，与 gnome portal 配套（niri NixOS 模块已自动安装）。
        "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
        "org.freedesktop.impl.portal.RemoteDesktop" = [ "gnome" ];
        # 键鼠共享（Deskflow / Synergy 3 / Input Leap 作为 server）需要 InputCapture
        # 后端，niri 自身未实现（niri#823 仍 open），由 nix-packages 的
        # niri-input-portal 提供。Clipboard 必须一并路由：剪贴板门户会挂到
        # InputCapture 建立的会话上，落到别的后端会让客户端陷入 create/destroy
        # 死循环（详见 MAINTENANCE.md）。
        "org.freedesktop.impl.portal.InputCapture" = [ "niri-input" ];
        "org.freedesktop.impl.portal.Clipboard" = [ "niri-input" ];
      };
      niri = {
        default = [
          "kde"
          "gtk"
        ];
        "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
        "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
        "org.freedesktop.impl.portal.RemoteDesktop" = [ "gnome" ];
        "org.freedesktop.impl.portal.InputCapture" = [ "niri-input" ];
        "org.freedesktop.impl.portal.Clipboard" = [ "niri-input" ];
      };
    };
    extraPortals = [
      pkgs.kdePackages.xdg-desktop-portal-kde
      pkgs.niri-input-portal
      pkgs.xdg-desktop-portal-gnome
    ];
  };

  # InputCapture 后端的 D-Bus 激活单元。包内的 service 文件引用了
  # SystemdService=niri-input-portal.service，因此必须有同名单元存在；这里显式
  # 声明以去掉上游的 ConditionEnvironment=WAYLAND_DISPLAY（条件不成立时 systemd
  # 会静默跳过该单元，D-Bus 只报服务名不可激活）。单元由 D-Bus 按需启动，因此
  # 不 enable，也不挂到任何 target 上。
  systemd.user.services.niri-input-portal = {
    Unit = {
      Description = "InputCapture portal backend for niri";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "dbus";
      BusName = "org.freedesktop.impl.portal.desktop.niri-input";
      ExecStart = "${pkgs.niri-input-portal}/bin/niri-input-portal";
      Restart = "on-failure";
      RestartSec = 1;
      Slice = "session.slice";
    };
  };

  # xdg-desktop-portal 1.22 may load every Settings provider referenced by
  # portal preferences. Keep GTK as the only provider until upstream fixes it.
  xdg.dataFile = {
    "xdg-desktop-portal/portals/gnome.portal".text = builtins.replaceStrings
      [ "org.freedesktop.impl.portal.Settings;" ]
      [ "" ]
      (builtins.readFile "${pkgs.xdg-desktop-portal-gnome}/share/xdg-desktop-portal/portals/gnome.portal");
    "xdg-desktop-portal/portals/kde.portal".text = builtins.replaceStrings
      [ "org.freedesktop.impl.portal.Settings;" ]
      [ "" ]
      (builtins.readFile "${pkgs.kdePackages.xdg-desktop-portal-kde}/share/xdg-desktop-portal/portals/kde.portal");
  };
}
