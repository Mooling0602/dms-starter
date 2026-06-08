{ config, pkgs, ... }:

{
  users.users.${config.my.username} = {
    isNormalUser = true;
    description = config.my.username;
    extraGroups = [
      "networkmanager"
      "wheel"
      "input"
      "video"
      "render"
    ];
    shell = pkgs.fish;
  };

  programs.fish.enable = true;

  security.sudo = {
    enable = true;
    extraRules = [
      {
        users = [ config.my.username ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
