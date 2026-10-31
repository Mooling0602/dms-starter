{ pkgs, ... }:

# Home-manager module, should be imported in user space
# Not needed under KDE Plasma, which integrates KDE Connect already.

{
  home.packages = with pkgs; [
    # KDE connect
    kdePackages.kdeconnect-kde
  ];

  # The daemon is a Qt application and needs the session display environment.
  # Started from default.target it comes up before that environment exists,
  # falls back to the xcb platform plugin and aborts with "could not connect
  # to display" on every login (five restarts, then start-limit-hit), which
  # leaves the unit dead until something activates org.kde.kdeconnect over
  # D-Bus. Binding it to the graphical session is what gives it
  # WAYLAND_DISPLAY and DISPLAY, the same way noctalia.service gets them.
  systemd.user.services.kdeconnectd = {
    Unit = {
      Description = "KDE Connect daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "exec";
      ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnectd";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
