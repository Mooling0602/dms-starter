{
  config,
  ...
}:

# system module for the setup of desktop module noctalia-with-niri

let
  # This implementation's desktop name, derived from this file's own directory
  # (modules/desktop/<name>/). Not hardcoded, so the assertion follows a rename
  # instead of drifting from the directory name. Bare baseNameOf is used because
  # it is in the Nix prelude (equivalent to builtins.baseNameOf).
  desktopName = baseNameOf ./.;
in
{
  imports = [
    # Login screen: wlroots compositor workarounds for this GPU plus the escape
    # hatch. See the file header and MAINTENANCE.md.
    ./greeter.nix
  ];

  # Used by the fallback assertion in modules/system/config.nix: only set when
  # this module is present. Stays false when the desktop layer is imported but
  # the implementation is missing from `imports`, and that side reports it.
  my.desktopImplementationLoaded = true;

  # This module asserts that it is the desktop declared by my.desktop. Placing
  # it in the implementation rather than in hosts/<host>/desktop/<name>/ means
  # only the implementation knows generically which desktop is actually loaded,
  # so the half-wrong case (declared A but imported B) is caught on any host,
  # not just the missing-import case.
  assertions = [
    {
      assertion = config.my.desktop == desktopName;
      message = ''
        桌面模块不一致：my.desktop 声明的是 "${config.my.desktop}"，
        但实际加载的桌面实现是 "${desktopName}"。

        当前加载的是 modules/desktop/${desktopName}/system.nix。
        通常意味着 hosts/<host>/default.nix 顶部的 `desktop` let 绑定与
        hosts/<host>/desktop/${config.my.desktop}/default.nix 里 import 的实现
        不是同一个：前者决定 my.desktop，后者决定实际加载哪个实现。
      '';
    }
  ];

  # This desktop's own Home Manager modules are mounted here, so the shell and
  # its session wiring enter the user environment only when noctalia-with-niri
  # is selected. Desktop-independent HM config stays in modules/home/ and is
  # imported unconditionally by modules/core.nix.
  home-manager.sharedModules = [ ./default.nix ];

  programs.niri.enable = true;

  # niri accepts -c/--config and the NIRI_CONFIG variable, so this desktop reads
  # its own declarative config instead of the default ~/.config/niri/config.kdl
  # that dms-with-niri owns and rewrites at runtime. Neither desktop can read or
  # overwrite the other's niri config, and the shared runtime directory keeps
  # working for the shell that owns it. The unit itself ships with the niri
  # package; this only adds a drop-in. Runs without the variable (niri validate,
  # a nested compositor) keep using the default path, so pass -c there.
  systemd.user.services.niri.environment.NIRI_CONFIG =
    "/home/${config.my.username}/.config/niri-noctalia/config.kdl";

  # Noctalia plays freedesktop notification sounds through the sound theme.
  # Upstream's NixOS module (programs.noctalia) sets this as well, but the shell
  # itself is installed and supervised by the Home Manager layer instead of by
  # both modules at once: enabling both would put the package in
  # home.packages and environment.systemPackages and declare noctalia.service
  # twice (once in ~/.config/systemd/user, once in /etc/systemd/user).
  xdg.sounds.enable = true;

  # Noctalia unlocks through the PAM service "login" (upstream FAQ: "Why can't I
  # unlock my lock screen?"), which every NixOS host already provides, so unlike
  # DMS (security.pam.services.dankshell) there is no dedicated service to
  # declare here. That also means the lock screen cannot be configured
  # separately from login itself: modules/optional/howdy.nix disables Howdy on
  # login because greetd delegates to the same stack, so on hosts that import
  # it the noctalia lock screen always asks for a password. Enabling Howdy
  # there again would hand the greeter face authentication as well, which
  # cannot unlock the GNOME keyring.
  #
  # Noctalia ships its own polkit authentication agent. niri-flake additionally
  # starts polkit-kde-agent (systemd.user.services.niri-flake-polkit), and only
  # one process can own org.freedesktop.PolicyKit1.AuthenticationAgent. Check
  # which one holds the name after switching, then disable the redundant unit
  # here if the KDE agent only restarts.
}
