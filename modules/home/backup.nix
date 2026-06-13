{ lib, pkgs, username, ... }:

let
  sourceRoot = ../..;
in
{
  home.activation.restoreDesktopConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    expected_user=${lib.escapeShellArg username}
    current_user="$(${pkgs.coreutils}/bin/id -un)"

    if [ "$current_user" != "$expected_user" ]; then
      echo "Skipping desktop config restore for $expected_user: running as $current_user"
    else
      export PATH="${lib.makeBinPath [
        pkgs.bash
        pkgs.coreutils
        pkgs.findutils
      ]}:$PATH"

      backup_script=${lib.escapeShellArg "${sourceRoot}/scripts/backup.sh"}
      profile_dir=${lib.escapeShellArg "${sourceRoot}/user_profiles/${username}/desktop-config"}
      config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
      dms_config="$config_home/DankMaterialShell/settings.json"
      niri_config="$config_home/niri/config.kdl"

      if [ ! -x "$backup_script" ] || [ ! -d "$profile_dir" ]; then
        echo "No desktop config snapshot found for $expected_user; skipping restore"
      elif [ ! -e "$dms_config" ] || [ ! -e "$niri_config" ]; then
        echo "Desktop config is missing for $expected_user; restoring snapshot"
        ${pkgs.bash}/bin/bash "$backup_script" apply-missing "$expected_user"
      fi
    fi
  '';
}
