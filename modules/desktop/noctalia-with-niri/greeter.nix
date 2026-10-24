{ config, ... }:

# System module, imported by system.nix: login screen wiring for this desktop.
#
# This desktop uses dms-greeter, not noctalia-greeter. noctalia-greeter brings
# its own wlroots compositor, which cannot survive VMware's vmwgfx: importing
# the greeter's dmabuf buffer makes wlroots close a GEM handle that GBM already
# closed (EINVAL), the compositor then posts a protocol error to the client, and
# the greeter exits before creating a session while greetd never retries. Two
# workarounds failed (direct scanout/modifier/cursor switches, then pixman plus
# software GL); MAINTENANCE.md keeps the evidence.
#
# dms-greeter runs inside niri instead. niri is built on smithay rather than
# wlroots and works on this GPU, and dms-greeter reads the existing
# ~/.config/DankMaterialShell appearance through configHome, so the login screen
# keeps the look this machine already had.
#
# getty@tty2 stays as the escape hatch while the login screen is the fragile
# part: tty1 belongs to greetd, and a getty instance only starts when it is
# wanted by getty.target (enable alone leaves the generated template unit
# without an [Install] section).
{
  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = "/home/${config.my.username}";
  };

  # The module creates the dms-greeter user and group; membership lets this user
  # reach the greeter cache, same as the dms-with-niri layer.
  users.users.${config.my.username}.extraGroups = [ "dms-greeter" ];

  systemd.services."getty@tty2" = {
    enable = true;
    wantedBy = [ "getty.target" ];
  };
}
