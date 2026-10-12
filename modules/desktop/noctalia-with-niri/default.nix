{ ... }:

# Home-manager module, can be imported in user space.
# Home-manager layer of the desktop module noctalia-with-niri.

let
  optionalImports = import ../../../utils/optional_import.nix;
in
{
  imports = optionalImports [
    ./terminal.nix
    ./ui.nix
    ./xdg-portals.nix
    ./packages.nix
  ];

  # Noctalia owns its configuration: programs.noctalia.settings is deliberately
  # left at its empty default, so no read-only store symlink is placed at
  # ~/.config/noctalia/config.toml and the shell's settings menu can keep saving
  # there. This mirrors AGENTS.md key design decision 1, where DMS and niri own
  # their runtime configuration instead of Home Manager.
  #
  # systemd.enable supervises the shell in the session: the unit follows
  # config.wayland.systemd.target, which is graphical-session.target under niri
  # (home-manager's default, and the target niri's session brings up), and
  # restarts on failure. No niri `spawn-at-startup` line is needed for this.
  programs.noctalia = {
    enable = true;
    systemd.enable = true;
  };
}
