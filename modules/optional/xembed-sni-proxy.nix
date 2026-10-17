{ pkgs, ... }:

# Home-manager module, should be imported in user space
#
# Bridges legacy XEmbed tray icons into the StatusNotifierItem tray of the
# running shell. X11 applications, notably Wine programs that call
# Shell_NotifyIcon, can only place a tray icon into an XEmbed system tray, and
# niri provides none: with no tray manager owning the _NET_SYSTEM_TRAY_S0
# selection on the X server, the icon window stays a standalone Xwayland
# window that floats in the layout. xembedsniproxy claims that selection,
# lets those applications embed their icons into it, and re-exports every
# icon as a StatusNotifierItem, which the Noctalia bar (or the DMS bar) shows
# like any native tray item.
#
# The binary comes from plasma-workspace, where Plasma ships the very same
# bridge. nixpkgs has no standalone xembed-sni-proxy package, and its
# snixembed bridges the other direction (StatusNotifierItem to XEmbed, for
# X11 window managers). Only this one executable runs here, and the rest of
# the plasma-workspace closure is already in the system closure anyway.
#
# Known limits: an XEmbed icon is a small pixmap, so it keeps its original
# 22 to 24 pixel size and looks soft on a HiDPI output, and the application's
# tray menu is still an Xwayland window, which niri shows as a regular window
# near the pointer instead of a popover. Applications that were already
# running when the proxy came up need a restart before their icon moves into
# the tray.

let
  xembedsniproxy = "${pkgs.kdePackages.plasma-workspace}/bin/xembedsniproxy";
in
{
  systemd.user.services.xembed-sni-proxy = {
    Unit = {
      Description = "XEmbed to StatusNotifierItem tray proxy";
      # Same session binding as the other display clients: the proxy needs
      # DISPLAY, and Xwayland (spawned by niri through xwayland-satellite)
      # may not be up yet when the session target is reached, so a failed
      # start is retried instead of being fatal.
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = xembedsniproxy;
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
