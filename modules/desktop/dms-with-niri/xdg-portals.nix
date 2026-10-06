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
        # ScreenCast/Screenshot/RemoteDesktop must use the gnome backend: the
        # kde backend needs KWin DBus interfaces, which do not exist in a niri
        # session. niri implements org.gnome.Mutter.ScreenCast, matching the
        # gnome portal (installed automatically by the niri NixOS module).
        "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
        "org.freedesktop.impl.portal.RemoteDesktop" = [ "gnome" ];
        # Keyboard/mouse sharing (Deskflow / Synergy 3 / Input Leap as the
        # server) needs an InputCapture backend, which niri itself does not
        # implement (niri#823 is still open); nix-packages' niri-input-portal
        # provides it. Clipboard must be routed along: the clipboard portal
        # attaches to the session created by InputCapture, and another backend
        # would trap clients in a create/destroy loop (see MAINTENANCE.md).
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

  # D-Bus activation unit for the InputCapture backend. The service file in the
  # package references SystemdService=niri-input-portal.service, so a unit of
  # that name must exist; it is declared explicitly here to drop the upstream
  # ConditionEnvironment=WAYLAND_DISPLAY (when the condition is false systemd
  # silently skips the unit and D-Bus only reports the name as not activatable).
  # D-Bus starts the unit on demand, so it is not enabled and not attached to
  # any target.
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
