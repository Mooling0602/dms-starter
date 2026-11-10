{ pkgs, ... }:

# Home-manager module, should be imported in user space
#
# WPS Office shows its "new version available" prompt as a frameless modal X11
# dialog. Under xwayland-satellite (the X server niri spawns) that window ends
# up below the application's main window in the X11 stacking order, and the
# compositor never routes pointer input to it: clicks land on the modal-blocked
# main window instead, so the prompt can be neither clicked nor closed and the
# whole application stays unusable until it disappears.
#
# Restacking is out of reach: xwayland-satellite owns the stacking order and
# ignores client restack requests, so XRaiseWindow, XLowerWindow and
# XConfigureWindow with stack_mode=Above all leave the order unchanged. The
# standard WM_DELETE_WINDOW client message, however, is handled by WPS itself
# and does close the dialog. This unit runs a small guard that watches the X
# server and closes such dialogs as soon as they appear.
#
# See MAINTENANCE.md for the analysis and the removal conditions.

let
  guard = pkgs.writeShellApplication {
    name = "wps-update-dialog-guard";
    runtimeInputs = [ (pkgs.python3.withPackages (ps: [ ps.xlib ])) ];
    text = ''
      exec python3 ${./wps-update-dialog-guard.py}
    '';
  };
in
{
  systemd.user.services.wps-update-dialog-guard = {
    Unit = {
      Description = "Close WPS Office update dialogs that cannot take input";
      # Same session binding as the other display clients: the guard needs
      # DISPLAY, and Xwayland (spawned by niri through xwayland-satellite) may
      # not be up yet when the session target is reached, so a failed start is
      # retried instead of being fatal.
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${guard}/bin/wps-update-dialog-guard";
      Restart = "always";
      RestartSec = 3;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
