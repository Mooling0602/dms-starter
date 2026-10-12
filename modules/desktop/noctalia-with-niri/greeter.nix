{ config, lib, pkgs, ... }:

# System module, imported by system.nix: login screen wiring for this desktop.
#
# noctalia-greeter starts its own wlroots compositor
# (noctalia-greeter-compositor). On VMware's vmwgfx that compositor dies right
# after the first frame: it logs
#   [backend/drm/fb.c:107] drmCloseBufferHandle failed: Invalid argument
#   [types/wlr_linux_dmabuf_v1.c:223] Failed to close buffer handle for plane 0
# then its Wayland socket goes away, and the greeter aborts by design
# ("holding process so greetd does not respawn"). The visible result is a black
# screen after the boot log. The session itself is unaffected: niri is built on
# smithay rather than wlroots, which is why the same GPU works fine once logged
# in. Full evidence and the removal condition are in MAINTENANCE.md.
#
# The exports below keep wlroots off the three paths involved in that failure:
# direct scanout to plane 0, dmabuf modifiers, and the hardware cursor plane.
# Every name is read by libwlroots 0.20.2 (verified against the library, not
# guessed); WLR_LOG raises the compositor log level so a repeat failure is
# diagnosable from the journal.
#
# If the graphical greeter ever fails again, the machine must not be a dead end.
# A text console is therefore kept on tty2 (getty is only started on tty1 by
# default, and tty1 belongs to greetd): Ctrl+Alt+F2, log in, then run
# `niri-session` to start the desktop without any greeter. SSH stays available
# as well.

{
  # The noctalia-greeter module sets this command with mkDefault, so overriding
  # keeps its package, cursor theme, greetd and AccountsService wiring.
  services.greetd.settings.default_session.command = lib.mkForce (
    toString (
      pkgs.writeShellScript "noctalia-greeter-vmwgfx" ''
        export WLR_SCENE_DISABLE_DIRECT_SCANOUT=1
        export WLR_DRM_NO_MODIFIERS=1
        export WLR_NO_HARDWARE_CURSORS=1
        export WLR_LOG=info

        exec ${lib.getExe' config.services.displayManager.noctalia-greeter.package "noctalia-greeter-session"}
      ''
    )
  );

  systemd.services."getty@tty2".enable = true;
}
