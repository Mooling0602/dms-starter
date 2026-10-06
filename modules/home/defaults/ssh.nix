{ pkgs, ... }:

# Home-manager module, has been imported by default.

{
  services.ssh-agent.enable = true;

  systemd.user.sessionVariables = {
    SSH_ASKPASS = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";

    # qtkeychain reuses Chromium's desktop-environment detection (its source
    # says "derived from chromium, base/nix/xdg_util.cc"): KDE picks KWallet,
    # while niri matches no enum, falls into DesktopEnv_Other and picks
    # libsecret. ksshaskpass stores passwords under the org.qt.keychain schema,
    # landing in gnome-keyring; after switching to KDE, qtkeychain looks in
    # KWallet instead, finds nothing and can only prompt, so auto-unlock breaks.
    # Pinning libsecret makes both desktops share one store. See MAINTENANCE.md.
    QTKEYCHAIN_BACKEND = "libsecret";
  };
}
