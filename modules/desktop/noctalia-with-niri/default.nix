{ ... }:

# Home-manager module, can be imported in user space.
# Home-manager layer of the desktop module noctalia-with-niri.

let
  optionalImports = import ../../../utils/optional_import.nix;
in
{
  imports = optionalImports [
    ./niri.nix
    ./terminal.nix
    ./ui.nix
    ./xdg-portals.nix
    ./packages.nix
  ];

  # Noctalia reads every ~/.config/noctalia/*.toml first and settings.toml last,
  # and the settings menu writes to settings.toml. Declaring config.toml here
  # therefore seeds the desktop look without ever blocking the UI: runtime
  # changes land in settings.toml and win over these values.
  #
  # systemd.enable supervises the shell in the session: the unit follows
  # config.wayland.systemd.target, which is graphical-session.target under niri
  # (home-manager's default, and the target niri's session brings up), and
  # restarts on failure. No niri `spawn-at-startup` line is needed for this.
  programs.noctalia = {
    enable = true;
    systemd.enable = true;

    settings = {
      # The avatar installed by modules/home/mooling/avatar.nix. Noctalia also
      # publishes it through AccountsService, so noctalia-greeter picks it up.
      shell.avatar_path = "~/.face";

      # Both wallpapers from modules/home/defaults/theme.nix live here, so the
      # picker offers the light/dark pair; the dark one is the default because
      # the theme below is pinned to dark.
      wallpaper = {
        enabled = true;
        directory = "~/.local/share/wallpapers";
        default.path = "~/.local/share/wallpapers/wallpaper-dark.png";
      };

      theme = {
        mode = "dark";

        # Derive the palette from the wallpaper, like the matugen theming of the
        # DMS session did. Use source = "builtin" plus builtin = "<name>" for a
        # fixed palette such as Noctalia or Catppuccin instead.
        source = "wallpaper";
        wallpaper_scheme = "m3-content";

        # App theming. alacritty, kitty and ghostty match the includes declared
        # in terminal.nix, whose apply hooks leave an existing include alone.
        # gtk3/gtk4 write gtk-{3,4}.0/noctalia.css and import it from gtk.css,
        # qt writes the two qt{5,6}ct color schemes, kcolorscheme the KDE one.
        #
        # The niri template is deliberately not enabled: besides rendering
        # noctalia.kdl it appends an include to the dms-with-niri owned
        # ~/.config/niri/config.kdl. This desktop already includes the rendered
        # file by absolute path, so only niri's own focus-ring and border colors
        # stay at their defaults.
        templates = {
          enable_builtin_templates = true;
          builtin_ids = [
            "alacritty"
            "kitty"
            "ghostty"
            "gtk3"
            "gtk4"
            "qt"
            "kcolorscheme"
          ];
        };
      };
    };
  };
}
