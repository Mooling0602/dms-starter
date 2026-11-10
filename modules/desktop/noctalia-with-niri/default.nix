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
    ./theme-auto.nix
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
      # picker offers the light/dark pair. The dark one is only the seed applied
      # at shell start; theme-auto.nix then syncs the image with the resolved
      # mode, which matters because a mode change does not re-apply a wallpaper
      # on its own.
      wallpaper = {
        enabled = true;
        directory = "~/.local/share/wallpapers";
        default.path = "~/.local/share/wallpapers/wallpaper-dark.png";
      };

      # Renders a blurred, tinted copy of the current wallpaper as a layer-shell
      # backdrop, which niri draws behind its overview. Disabled upstream by
      # default. niri only treats the surface as that backdrop when the matching
      # layer-rule in niri-config.kdl sets place-within-backdrop, so the two have
      # to be declared together: enabling this alone leaves an ordinary
      # full-screen layer surface, and the rule alone matches no surface at all.
      #
      # The keys use underscores. The docs render them hyphenated, but Noctalia's
      # validator only warns about an unknown setting and still exits 0, so a
      # hyphenated key would silently do nothing while the build stayed green.
      # The values are the documented defaults: 0.0 is no blur or no tint, 1.0 is
      # maximum blur or a fully opaque tint. The tint colour is the palette's
      # surface colour and is not configurable.
      backdrop = {
        enabled = true;
        blur_intensity = 0.5;
        tint_intensity = 0.3;
      };

      theme = {
        # Follow sunrise and sunset at the coordinates declared in
        # theme-auto.nix. shell_mode defaults to "follow", so the bar and every
        # template below flip together with the palette. The settings menu stays
        # in charge: it writes settings.toml, which is read after this file.
        mode = "auto";

        # Derive the palette from the wallpaper, like the matugen theming of the
        # DMS session did. Use source = "builtin" plus builtin = "<name>" for a
        # fixed palette such as Noctalia or Catppuccin instead.
        source = "wallpaper";
        wallpaper_scheme = "m3-content";

        # App theming. alacritty, kitty and ghostty match the includes declared
        # in terminal.nix, whose apply hooks leave an existing include alone.
        # gtk3/gtk4 write gtk-{3,4}.0/noctalia.css and import it from gtk.css,
        # qt writes the two qt{5,6}ct color schemes, kcolorscheme the KDE one.
        # btop and starship were added in the settings GUI and are seeded here
        # as well. The built-in niri template stays out on purpose, see below.
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
            "btop"
            "ghostty"
            "gtk3"
            "gtk4"
            "kcolorscheme"
            "kitty"
            "qt"
            "starship"
          ];

          # Community templates are not shipped with the package: the settings
          # menu downloads them into ~/.local/state/noctalia/community-templates
          # once per device, and community_ids only picks which cached ones get
          # rendered. Declaring them keeps a new host on the same set after it
          # has fetched them, but the fetch itself cannot be declared, see
          # MAINTENANCE.md.
          community_ids = [
            "claude-code"
            "codex"
            "opencode"
            "pi-agent"
            "zen-browser"
            "discord"
            "telegram"
            "libreoffice"
            "neovim"
            "vscode"
            "zed"
            "heroiclauncher"
            "prismlauncher"
            "steam"
            "fastfetch"
            "obs"
            "zellij"
            "herdr"
            "konsole"
            "lazygit"
            "tmux"
            "yazi"
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

      # The tray widget hides StatusNotifierItems whose status is Passive by
      # default. KDE Connect's indicator always reports Passive, so with the
      # default its icon never appears and launching the indicator looks like
      # nothing happened. Show passive items as well.
      widget.tray.hide_passive = false;

      # The privacy widget shows one icon each for microphone, camera and
      # screen sharing, switching to an active glyph while PipeWire reports a
      # capture stream of that kind; hovering it lists the applications. It
      # matches stream links, not device use, so an idle device stays dark and
      # only a portal-issued screen cast is seen. hide_inactive (upstream
      # default false) drops idle icons and the whole widget, so it takes bar
      # space only while something is actually capturing. The filters under
      # shell.privacy ignore matching applications and are left at their empty
      # defaults. Note the underscore, same trap as the backdrop keys above.
      widget.privacy.hide_inactive = true;

      # Everything below was picked in the settings GUI and is seeded here so a
      # fresh host starts from the same look. It is deliberately not a mirror of
      # the GUI: runtime state stays out, namely which wallpaper is up
      # (theme-auto.nix owns that), the lockscreen widget geometry of one
      # monitor, and the community template cache. See MAINTENANCE.md for the
      # community templates and for how this list is maintained.
      bar.default = {
        # A square, fully transparent bar flush with the screen edges.
        background_opacity = 0.0;
        margin_ends = 0;
        radius = 0;
        contact_shadow = true;

        # The media widget moved out of the end section into the middle.
        center = [
          "clock"
          "media"
          "privacy"
        ];

        end = [
          "tray"
          "notifications"
          "clipboard"
          "network"
          "bluetooth"
          "volume"
          "brightness"
          "battery"
          "control-center"
          "session"
        ];
      };

      dock = {
        enabled = true;
        auto_hide = true;
        active_monitor_only = true;
        reserve_space = false;
        show_dots = true;
      };

      hot_corners = {
        enabled = true;
        top_left.action = "window_switcher";
      };

      lockscreen.blurred_desktop = true;

      shell = {
        # Sarasa UI SC, installed by modules/system/fonts.nix. The GUI writes
        # the localized family name, which fontconfig resolves to the same font.
        font_family = "Sarasa UI SC";

        # Seconds in the bar clock and in the clock widget.
        time_format = "{:%H:%M:%S}";

        panel.transparency_mode = "glass";

        # Upstream default is false; the settings GUI switched it on.
        telemetry_enabled = true;
      };

      widget = {
        battery.hide_when_plugged = true;
        clock.format = "{:%H:%M:%S}";
        media.hide_when_no_media = true;
        network = {
          show_label = false;
          show_vpn_label = true;
          vpn_status = "both";
        };
      };
    };
  };

  # Read-only: only the template engine reads it. Noctalia watches that
  # directory for *.toml changes, so a .kdl file there causes no restarts.
  xdg.configFile."noctalia/niri-palette.kdl".source = ./niri-palette.kdl;
}
