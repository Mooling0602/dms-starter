{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    wineWow64Packages.full
    winetricks
    # wine64 -> wine link (winetricks need wine64 executable in WoW64 mode)
    (pkgs.runCommand "wine64-symlink" { } ''
      mkdir -p $out/bin
      ln -s ${wineWow64Packages.full}/bin/wine $out/bin/wine64
    '')

  ];

  environment.variables = {
    WINEDLLOVERRIDES = "winealsa.drv=d";
    EDITOR = "nvim";
    QT_PLUGIN_PATH = [
      "${pkgs.qt6Packages.qt6ct}/${pkgs.qt6.qtbase.qtPluginPrefix}"
      "${pkgs.libsForQt5.qt5ct}/${pkgs.libsForQt5.qtbase.qtPluginPrefix}"
      "${pkgs.kdePackages.breeze}/${pkgs.qt6.qtbase.qtPluginPrefix}"
    ];
  };

}
