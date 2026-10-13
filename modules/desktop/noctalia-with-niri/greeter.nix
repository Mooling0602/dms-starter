{ config, lib, pkgs, ... }:

# System module, imported by system.nix: login screen wiring for this desktop.
#
# noctalia-greeter starts its own wlroots compositor
# (noctalia-greeter-compositor). On VMware's vmwgfx that compositor cannot keep
# the greeter's buffers alive: importing the client dmabuf buffer hits
#   [backend/drm/fb.c:107] drmCloseBufferHandle failed: Invalid argument
#   [types/wlr_linux_dmabuf_v1.c:223] Failed to close buffer handle for plane 0
# (wlroots closes a GEM handle that GBM already closed, so vmwgfx answers
# EINVAL), the compositor then drops the client connection and the greeter exits
# with "Wayland dispatch_pending failed (Connection reset by peer)". greetd
# reports "greeter exited without creating a session" and never retries, which
# is the black screen. The session is unaffected because niri is built on
# smithay instead of wlroots. Evidence: MAINTENANCE.md.
#
# A first attempt with WLR_SCENE_DISABLE_DIRECT_SCANOUT, WLR_DRM_NO_MODIFIERS
# and WLR_NO_HARDWARE_CURSORS (each verified to exist in libwlroots 0.20.2) did
# not help: none of them stops the client dmabuf import. What is left is to take
# dmabuf out of the picture on both sides:
#   WLR_RENDERER=pixman      the compositor renders and scans out from dumb
#                            buffers, so there are no GBM buffer objects and no
#                            dmabuf advertisement
#   LIBGL_ALWAYS_SOFTWARE=1  the greeter client renders with llvmpipe and hands
#                            over shared memory buffers instead of dmabuf ones
# A login screen needs no GPU rendering, so the CPU cost is irrelevant here.
#
# If it still fails, the machine is not a dead end: tty2 gets a real getty below
# (Ctrl+Alt+F2, log in, then `niri-session` starts the desktop without any
# greeter), and SSH stays available.

{
  # The noctalia-greeter module sets this command with mkDefault, so overriding
  # keeps its package, cursor theme, greetd and AccountsService wiring.
  services.greetd.settings.default_session.command = lib.mkForce (
    toString (
      pkgs.writeShellScript "noctalia-greeter-vmwgfx" ''
        export WLR_RENDERER=pixman
        export LIBGL_ALWAYS_SOFTWARE=1
        export WLR_LOG=info

        exec ${lib.getExe' config.services.displayManager.noctalia-greeter.package "noctalia-greeter-session"}
      ''
    )
  );

  # getty instances are not started by `enable` alone: the generated unit has no
  # [Install] section, so it must also be wanted by getty.target. Without this a
  # dead greeter leaves no console to log in on (tty1 belongs to greetd).
  systemd.services."getty@tty2" = {
    enable = true;
    wantedBy = [ "getty.target" ];
  };
}
