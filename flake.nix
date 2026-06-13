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
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvcfg = {
      url = "github:Mooling0602/NvCfg";
      flake = false;
    };
    nix4nvchad = {
      url = "github:nix-community/nix4nvchad";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nvchad-starter.follows = "nvcfg";
    };
    apollo-flake = {
      url = "github:nil-andreas/apollo-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-packages = {
      url = "github:Mooling0602/nix-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dw-proton = {
      url = "github:imaviso/dwproton-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      apollo-flake,
      dw-proton,
      ...
    }:
    let
      username = "mooling"; # ← 改这里即可替换用户名
      hostname = "mooling-laptop";
    in
    {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/${hostname}
          home-manager.nixosModules.home-manager
          apollo-flake.nixosModules.x86_64-linux.default
          (
            { ... }:
            {
              services.apollo.package = apollo-flake.packages.x86_64-linux.default;
            }
          )
          {
            programs.steam.extraCompatPackages = [
              dw-proton.packages.x86_64-linux.dw-proton
            ];
          }
          {
            my = { inherit username hostname; };
            nixpkgs.overlays = [
              (final: prev: {
                xwayland-satellite = inputs.niri.packages.${final.system}.xwayland-satellite-unstable;
              })
              (final: prev: {
                reasonix = inputs.llm-agents.packages.${final.system}.reasonix;
                reasonix-desktop = inputs.nix-packages.packages.${final.system}.reasonix-desktop;
                qoder = inputs.nix-packages.packages.${final.system}.qoder;
                zen-browser = inputs.zen-browser.packages.${final.system}.default;
              })
            ];
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.${username} =
              { ... }:
              {
                imports = [
                  ./modules/home
                  ./hosts/${hostname}/streaming-display.nix
                  inputs.dms.homeModules.dank-material-shell
                  inputs.nix4nvchad.homeManagerModule
                ];
              };
            home-manager.extraSpecialArgs = inputs // {
              inherit username hostname;
            };
          }
        ];
      };
    };
}
