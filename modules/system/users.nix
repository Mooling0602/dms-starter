{ config, pkgs, ... }:

{
  users.users.mooling = {
    isNormalUser = true;
    description = "mooling";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
    packages = with pkgs; [
    ];
  };

  programs.fish.enable = true;

  security.sudo = {
    enable = true;
    extraRules = [
      {
        users = [ "mooling" ];
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
