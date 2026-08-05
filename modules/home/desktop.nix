{
  pkgs,
  dms,
  ...
}:

let
  fcitxDmsThemeSync = pkgs.writeShellScript "fcitx5-dms-theme-sync" ''
    set -eu

    rgb_to_hex() {
      local red green blue
      IFS=, read -r red green blue <<< "$1"
      printf '#%02x%02x%02x' "$red" "$green" "$blue"
    }

    rgb_luminance() {
      local red green blue
      IFS=, read -r red green blue <<< "$1"
      printf '%d' "$(( (2126 * red + 7152 * green + 722 * blue) / 10000 ))"
    }

    dms_colors="$HOME/.local/share/color-schemes/DankMatugen.colors"
    window_background_rgb="$(
      ${pkgs.kdePackages.kconfig}/bin/kreadconfig6 \
        --file "$dms_colors" \
        --group 'Colors:Window' \
        --key BackgroundNormal
    )"
    if [ "$(rgb_luminance "$window_background_rgb")" -lt 128 ]; then
      theme_mode="dark"
    else
      theme_mode="light"
    fi

    # breeze-{light,dark} only overrides colors. Give the generator a complete
    # private image set so it does not need a running Plasma Shell for fallback
    # SVG resources.
    plasma_theme="dms-fcitx-$theme_mode"
    for plasma_theme_dir in \
      "$HOME/.local/share/plasma/desktoptheme/$plasma_theme" \
      "$HOME/.local/share/fcitx5-plasma-theme-generator/svgtheme/$plasma_theme"; do
      ${pkgs.coreutils}/bin/mkdir -p "$plasma_theme_dir"
      ${pkgs.coreutils}/bin/chmod -R u+w "$plasma_theme_dir"
      ${pkgs.coreutils}/bin/cp -R --no-preserve=mode,ownership \
        ${pkgs.kdePackages.libplasma}/share/plasma/desktoptheme/default/. \
        "$plasma_theme_dir/"
      ${pkgs.coreutils}/bin/cp \
        ${pkgs.kdePackages.libplasma}/share/plasma/desktoptheme/breeze-"$theme_mode"/colors \
        "$plasma_theme_dir/colors"
      ${pkgs.gnused}/bin/sed -i \
        "s/\"Id\": \"default\"/\"Id\": \"$plasma_theme\"/" \
        "$plasma_theme_dir/metadata.json"
    done

    ${pkgs.qt6Packages.fcitx5-with-addons}/bin/fcitx5-plasma-theme-generator \
      --theme "$plasma_theme" \
      --output "$HOME/.local/share/fcitx5/themes/dms-plasma"

    dms_theme="$HOME/.local/share/fcitx5/themes/dms-plasma"
    selection_background_rgb="$(
      ${pkgs.kdePackages.kconfig}/bin/kreadconfig6 \
        --file "$dms_colors" \
        --group 'Colors:Selection' \
        --key BackgroundNormal
    )"
    selection_foreground_rgb="$(
      ${pkgs.kdePackages.kconfig}/bin/kreadconfig6 \
        --file "$dms_colors" \
        --group 'Colors:Selection' \
        --key ForegroundNormal
    )"
    selection_background="$(rgb_to_hex "$selection_background_rgb")"
    selection_foreground="$(rgb_to_hex "$selection_foreground_rgb")"

    ${pkgs.gnused}/bin/sed -i \
      -e "s/^HighlightCandidateColor=.*/HighlightCandidateColor=$selection_foreground/" \
      -e "s/^HighlightColor=.*/HighlightColor=$selection_foreground/" \
      -e "s/^HighlightBackgroundColor=.*/HighlightBackgroundColor=$selection_background/" \
      "$dms_theme/theme.conf"
    ${pkgs.imagemagick}/bin/mogrify \
      -fill "$selection_background" \
      -colorize 100 \
      "$dms_theme/highlight.png"

    if ${pkgs.qt6Packages.fcitx5-with-addons}/bin/fcitx5-remote --check; then
      # Classic UI caches NormalColor across a config reload. This is the same
      # restart path exposed by Fcitx's system tray, so its addon environment
      # and configured input methods are retained.
      ${pkgs.systemd}/bin/busctl --user call \
        org.fcitx.Fcitx5 \
        /controller \
        org.fcitx.Fcitx.Controller1 \
        Restart
    fi
  '';
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      general = {
        import = [ "~/.config/alacritty/dank-theme.toml" ];
      };
      window = {
        decorations = "None";
        opacity = 0.6;
        padding = {
          x = 8;
          y = 4;
        };
      };
    };
  };

  programs.kitty = {
    enable = true;
    font = {
      name = "Maple Mono NF CN";
      size = 12;
    };
    settings = {
      background_opacity = 0.6;
      background_blur = 64;
      hide_window_decorations = "yes";
      confirm_os_window_close = 0;
    };
    extraConfig = ''
      include dank-theme.conf
      include dank-tabs.conf
    '';
  };

  programs.ghostty = {
    enable = true;
    settings = {
      theme = "dankcolors";
      "font-family" = "Maple Mono NF CN";
      "font-size" = 12;
      "window-decoration" = false;
      "window-padding-x" = 12;
      "window-padding-y" = 12;
      "background-opacity" = 0.6;
      "background-blur-radius" = 32;
      "cursor-style" = "block";
      "cursor-style-blink" = true;
      "scrollback-limit" = 3023;
      "mouse-hide-while-typing" = true;
      "copy-on-select" = false;
      "confirm-close-surface" = false;
      "app-notifications" = "no-clipboard-copy,no-config-reload";
      "unfocused-split-opacity" = 0.7;
      "unfocused-split-fill" = "#44464f";
      "gtk-titlebar" = false;
      "gtk-single-instance" = true;
      "shell-integration" = "detect";
      "shell-integration-features" = "cursor,sudo,title,no-cursor";
      keybind = [
        "ctrl+shift+n=new_window"
        "ctrl+t=new_tab"
        "ctrl+plus=increase_font_size:1"
        "ctrl+minus=decrease_font_size:1"
        "ctrl+zero=reset_font_size"
        "shift+enter=text:\\n"
      ];
    };
  };

  home.file.".face".source = ../../assets/avatar.jpg;
  home.file.".face.icon".source = ../../assets/avatar.jpg;

  home.file.".local/share/wallpapers/wallpaper-light.png".source =
    ../../assets/wallpaper-light-kokomi.png;
  home.file.".local/share/wallpapers/wallpaper-dark.png".source =
    ../../assets/wallpaper-dark-cyrene.png;

  programs.dank-material-shell = {
    enable = true;
    enableDynamicTheming = true;
    enableSystemMonitoring = true;
    systemd.enable = true;
  };

  programs.dank-calendar = {
    enable = true;
    systemd.enable = true;
  };

  systemd.user.services.kdeconnectd = {
    Unit = {
      Description = "KDE Connect daemon";
    };
    Service = {
      Type = "exec";
      ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnectd";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.dms-set-avatar = {
    Unit = {
      Description = "Set DMS profile avatar after DMS starts";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "dms-set-avatar" ''
        for i in $(seq 1 30); do
          if ${
            dms.packages.${pkgs.stdenv.hostPlatform.system}.default
          }/bin/dms ipc profile setImage $HOME/nixos-config/assets/avatar.jpg 2>&1 | grep -q SUCCESS; then
            exit 0
          fi
          sleep 1
        done
        exit 1
      ''}";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Fcitx's Plasma generator follows Plasma Shell, not the XDG portal DMS
  # updates. Derive a private light/dark theme from the DMS color scheme itself.
  systemd.user.services.fcitx5-dms-theme-sync = {
    Unit = {
      Description = "Synchronize Fcitx5 Plasma candidate theme with DMS";
      After = [ "dms.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = fcitxDmsThemeSync;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.paths.fcitx5-dms-theme-sync = {
    Unit = {
      Description = "Watch DMS color scheme for Fcitx5";
    };
    Path = {
      PathChanged = "%h/.local/share/color-schemes/DankMatugen.colors";
      Unit = "fcitx5-dms-theme-sync.service";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
