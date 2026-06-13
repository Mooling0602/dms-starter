{
  pkgs,
  dms,
  ...
}:

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
}
