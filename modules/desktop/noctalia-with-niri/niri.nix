{ config, lib, pkgs, ... }:

# Home-manager module, has been imported in noctalia-with-niri.
#
# Declarative niri session config for this desktop, plus the bootstrap that lets
# niri start with it. The isolation strategy is described in AGENTS.md, section
# "noctalia-with-niri 桌面层": this desktop reads its own config file, while
# dms-with-niri keeps owning the default ~/.config/niri/config.kdl.

let
  # niri-config.kdl is real KDL, validated below; the placeholders keep user or
  # store paths out of the file itself.
  substituted = builtins.replaceStrings
    [ "@REGION_RECORD@" "@NIRI_INPUT_PORTAL@" ]
    [
      "${config.home.homeDirectory}/.local/bin/region-record"
      "${pkgs.niri-input-portal}/bin/niri-input-portal"
    ]
    (builtins.readFile ./niri-config.kdl);

  generated = pkgs.writeText "niri-noctalia-config.kdl" substituted;

  # Catch syntax errors at build time instead of at the next login. Include
  # lines are commented out in a throwaway copy first: they point at runtime
  # files (~/.config/niri/noctalia.kdl and niri-noctalia/host.kdl) that do not
  # exist in the build sandbox, and niri treats an unreadable include as fatal.
  # The installed file itself keeps the includes intact.
  checked = pkgs.runCommand "niri-noctalia-config.kdl" { nativeBuildInputs = [ pkgs.niri ]; } ''
    sed -E 's|^([[:space:]]*)include[[:space:]]|\1// include |' ${generated} > check.kdl
    niri validate -c check.kdl
    cp ${generated} $out
  '';
in
{
  xdg.configFile = {
    "niri-noctalia/config.kdl".source = checked;

    # Included at the end of config.kdl, so hosts/<host>/desktop/<name>/ can
    # override the shared defaults. Hosts override `source` with lib.mkForce.
    "niri-noctalia/host.kdl".source = ./niri-host-default.kdl;
  };

  # niri reads the Noctalia palette include at startup, and a missing include is
  # a fatal error, so leave an empty placeholder until Noctalia's built-in niri
  # template renders it. An existing file is never touched: Noctalia owns it.
  home.activation.noctaliaNiriThemeStub = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    noctalia_theme_file="$HOME/.config/niri/noctalia.kdl"
    if [ ! -e "$noctalia_theme_file" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$(dirname "$noctalia_theme_file")"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/printf '%s\n' '// Rendered by Noctalia (built-in template "niri").' > "$noctalia_theme_file"
    fi
  '';
}
