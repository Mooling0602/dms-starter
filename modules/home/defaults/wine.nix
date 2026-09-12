# Fix wine audio driver error.

{
  home.sessionVariables.WINEDLLOVERRIDES = "winealsa.drv=d";

  xdg.configFile."fish/conf.d/wine.fish".text = ''
    set -gx WINEDLLOVERRIDES "winealsa.drv=d"
  '';
}
