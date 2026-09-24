{ config, pkgs, ... }:

{
  hardware.uinput.enable = true;

  systemd.services."user-runtime-dir@".serviceConfig.ExecStartPost = [
    "-${pkgs.acl}/bin/setfacl -m u:${config.my.username}:x /run/user/%i"
  ];

  users.users.${config.my.username} = {
    isNormalUser = true;
    description = config.my.username;
    extraGroups = [
      "networkmanager"
      "wheel"
      "input"
      "video"
      "render"
      "dms-greeter"
      "uinput"
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
            # options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
