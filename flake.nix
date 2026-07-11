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
    danksearch = {
      url = "github:AvengeMedia/danksearch";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    xwayland-satellite = {
      url = "git+https://github.com/Mooling0602/xwayland-satellite";
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
          (
            { pkgs, ... }:
            {
              environment.systemPackages = [
                (pkgs.writeShellScriptBin "dw-proton" ''
                  set -eu

                  if [ "$#" -lt 1 ]; then
                    echo "Usage: dw-proton <program.exe> [arguments...]" >&2
                    exit 64
                  fi

                  export STEAM_COMPAT_CLIENT_INSTALL_PATH="''${STEAM_COMPAT_CLIENT_INSTALL_PATH:-$HOME/.steam/steam}"
                  export STEAM_COMPAT_DATA_PATH="''${STEAM_COMPAT_DATA_PATH:-''${WINEPREFIX:-$PWD}}"
                  export WINEPREFIX="$STEAM_COMPAT_DATA_PATH/pfx"
                  export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.vulkan-loader ]}:''${LD_LIBRARY_PATH:-}"

                  mkdir -p "$STEAM_COMPAT_DATA_PATH"
                  exec ${dw-proton.packages.x86_64-linux.dw-proton.steamcompattool}/proton run "$@"
                '')
              ];

              programs.steam.extraCompatPackages = [
                dw-proton.packages.x86_64-linux.dw-proton
              ];
            }
          )
          {
            my = { inherit username hostname; };
            nixpkgs.overlays = [
              (final: prev: {
                xwayland-satellite = inputs.xwayland-satellite.packages.${final.system}.xwayland-satellite;
              })
              (final: prev: {
                codex = inputs.nix-packages.packages.${final.system}.codex-bin;
                reasonix = inputs.llm-agents.packages.${final.system}.reasonix;
                reasonix-desktop = inputs.nix-packages.packages.${final.system}.reasonix-desktop;
                qoder = inputs.nix-packages.packages.${final.system}.qoder;
                clawd-on-desk = inputs.nix-packages.packages.${final.system}.clawd-on-desk;
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
                  inputs.danksearch.homeModules.dsearch
                  inputs.nix4nvchad.homeManagerModule
                ];
                programs.dsearch.enable = true;
              };
            home-manager.extraSpecialArgs = inputs // {
              inherit username hostname;
            };
          }
        ];
      };
    };
}
