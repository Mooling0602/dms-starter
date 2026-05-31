{ config, lib, pkgs, dms, ... }:

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
        padding = { x = 8; y = 4; };
      };
    };
  };

  home.file.".face".source = ../../assets/avatar.jpg;
  home.file.".face.icon".source = ../../assets/avatar.jpg;

  home.file.".local/share/wallpapers/wallpaper-light.png".source = ../../assets/wallpaper-light-kokomi.png;
  home.file.".local/share/wallpapers/wallpaper-dark.png".source = ../../assets/wallpaper-dark-cyrene.png;

  programs.dank-material-shell = {
    enable = true;
    enableDynamicTheming = true;
    enableSystemMonitoring = true;
    systemd.enable = true;

    session = {
      # WALLPAPER
      wallpaperPath = "${config.home.homeDirectory}/.local/share/wallpapers/wallpaper-dark.png";
      wallpaperPathLight = "${config.home.homeDirectory}/.local/share/wallpapers/wallpaper-light.png";
      wallpaperPathDark = "${config.home.homeDirectory}/.local/share/wallpapers/wallpaper-dark.png";
      perModeWallpaper = true;
      perMonitorWallpaper = false;
      wallpaperTransition = "fade";
      wallpaperCyclingEnabled = false;

      # LOCATION
      latitude = 25.839;
      longitude = 114.913;

      # NIGHT MODE
      nightModeEnabled = false;
      nightModeTemperature = 4500;
      nightModeAutoEnabled = true;
      nightModeAutoMode = "location";
      nightModeStartHour = 18;
      nightModeEndHour = 6;
      nightModeUseIPLocation = false;

      # AUTO THEME
      themeModeAutoEnabled = true;
      themeModeAutoMode = "location";
      themeModeStartHour = 18;
      themeModeEndHour = 6;
      themeModeShareGammaSettings = true;

      # WEATHER
      weatherLocation = "Ganzhou";
      weatherCoordinates = "25.839,114.913";
      weatherHourlyDetailed = true;

      # MISC
      showThirdPartyPlugins = false;
      searchAppActions = true;
      configVersion = 3;
    };
  };

  xdg.configFile = let niriDir = "${config.home.homeDirectory}/nixos-config/niri"; in {
    "niri/config.kdl".source = config.lib.file.mkOutOfStoreSymlink "${niriDir}/config.kdl";
    "niri/dms/alttab.kdl".source = config.lib.file.mkOutOfStoreSymlink "${niriDir}/dms/alttab.kdl";
    "niri/dms/binds.kdl".source = config.lib.file.mkOutOfStoreSymlink "${niriDir}/dms/binds.kdl";
    "niri/dms/colors.kdl".source = config.lib.file.mkOutOfStoreSymlink "${niriDir}/dms/colors.kdl";
    "niri/dms/cursor.kdl".source = config.lib.file.mkOutOfStoreSymlink "${niriDir}/dms/cursor.kdl";
    "niri/dms/layout.kdl".source = config.lib.file.mkOutOfStoreSymlink "${niriDir}/dms/layout.kdl";
    "niri/dms/outputs.kdl".source = config.lib.file.mkOutOfStoreSymlink "${niriDir}/dms/outputs.kdl";
    "niri/dms/windowrules.kdl".source = config.lib.file.mkOutOfStoreSymlink "${niriDir}/dms/windowrules.kdl";
    "niri/dms/wpblur.kdl".source = config.lib.file.mkOutOfStoreSymlink "${niriDir}/dms/wpblur.kdl";
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
          if ${dms.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/dms ipc profile setImage $HOME/nixos-config/assets/avatar.jpg 2>&1 | grep -q SUCCESS; then
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
