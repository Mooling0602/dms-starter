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
    ./fcitx-theme-sync.nix
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

      # Noctalia registers its polkit authentication agent only when this key is
      # set; upstream default is false, and nothing else answers privileged
      # prompts on this host. niri-flake's Home Manager module (which would
      # start niri-flake-polkit) is not imported by this layer, and this nixpkgs
      # makes the setuid pkexec wrapper opt in via
      # security.polkit.enablePkexecWrapper, which defaults to false. The
      # settings menu stays in charge: it writes settings.toml, and that file is
      # read last, so its value wins over this one.
      shell.polkit_agent = true;

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
        # The built-in niri template is deliberately not enabled: besides
        # rendering the palette it appends `include "noctalia.kdl"` to
        # ~/.config/niri/config.kdl, which belongs to dms-with-niri, and it can
        # only write to that same directory. "niri-colors" below is the
        # equivalent user template with both paths redirected into this
        # desktop's own config directory.
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

          # niri-palette.kdl is the payload of the built-in niri template minus
          # the hook that writes into the other desktop's config. A relative
          # input resolves against the directory of the config file itself, so
          # the file is installed next to config.toml by the xdg.configFile
          # entry below; the output is the file that niri-config.kdl includes
          # optionally. No hooks, so nothing outside this desktop's own
          # directories is touched.
          user.niri-colors = {
            input_path = "niri-palette.kdl";
            output_path = "$XDG_CONFIG_HOME/niri-noctalia/noctalia.kdl";
          };
        };
      };
    };
  };

  # Read-only: only the template engine reads it. Noctalia watches that
  # directory for *.toml changes, so a .kdl file there causes no restarts.
  xdg.configFile."noctalia/niri-palette.kdl".source = ./niri-palette.kdl;
}
