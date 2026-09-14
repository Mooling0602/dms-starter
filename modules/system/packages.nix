{ lib, pkgs, ... }:

{
  programs.dconf.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
  };

  # 排除 GNOME 文件管理器，使用 KDE/Dolphin
  environment.gnome.excludePackages = with pkgs; [
    nautilus
  ];

  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    wget
    brightnessctl
    pulseaudio
    nil
    nixd
    gnumake
    gcc
    python3

    clash-verge-rev

    # Provide org.gnome.desktop.interface for GTK's GSettings lookup.
    gsettings-desktop-schemas
    glib

    # KDE file chooser portal
    kdePackages.xdg-desktop-portal-kde

    accountsservice
    mission-center
  ];
  
  # Fix dolphin application menu
  environment.etc."xdg/menus/applications.menu".source =
    "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";


  # Keep the schemas required by both GTK's own settings and GNOME desktop
  # settings. Overriding this with only gsettings-desktop-schemas hides
  # org.gtk.Settings.FileChooser from GTK applications.
  environment.sessionVariables.GSETTINGS_SCHEMA_DIR = lib.concatStringsSep ":" [
    "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}/glib-2.0/schemas"
    "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas"
  ];
}
