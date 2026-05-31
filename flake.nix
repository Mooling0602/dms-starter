{
  description = "NixOS configuration for mooling-laptop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dgop = {
      url = "github:AvengeMedia/dgop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
    let
      username = "mooling";  # ← 改这里即可替换用户名
    in
    {
      nixosConfigurations.mooling-laptop = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/mooling-laptop
          home-manager.nixosModules.home-manager
          {
            my.username = username;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.${username} = { config, pkgs, ... }: {
              imports = [
                ./modules/home
                inputs.dms.homeModules.dank-material-shell
              ];
            };
            home-manager.extraSpecialArgs = inputs // { inherit username; };
          }
        ];
      };
    };
}
