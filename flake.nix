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
    };
    dw-proton = {
      url = "github:imaviso/dwproton-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    danksearch = {
      url = "github:AvengeMedia/danksearch";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dankcalendar = {
      url = "github:AvengeMedia/dankcalendar";
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
            { ... }:
            {
              programs.steam.extraCompatPackages = [
                dw-proton.packages.x86_64-linux.dw-proton
              ];
            }
          )
          {
            my = { inherit username hostname; };
            nixpkgs.overlays = [
              (final: prev: {
                qt6Packages = prev.qt6Packages // {
                  # DMS generates KDE .colors files for qt6ct. Upstream qt6ct
                  # cannot read them without the qt6ct-kde compatibility patch.
                  qt6ct = prev.qt6Packages.qt6ct.overrideAttrs (previousAttrs: {
                    buildInputs = (previousAttrs.buildInputs or [ ]) ++ [
                      final.kdePackages.kconfig
                      final.kdePackages.kcolorscheme
                      final.kdePackages.kiconthemes
                    ];
                    patches = (previousAttrs.patches or [ ]) ++ [
                      (final.fetchpatch {
                        url = "https://aur.archlinux.org/cgit/aur.git/plain/qt6ct-shenanigans.patch?h=qt6ct-kde&id=8c1003e13b7e7545e717273e0716f095f195bd13";
                        hash = "sha256-Q8QOMDy84z6FD0OkSLylEwB+/Zs50jcUgR+4J6Lmwmk=";
                      })
                    ];
                  });
                };
              })
              (final: prev: {
                xwayland-satellite = inputs.xwayland-satellite.packages.${final.stdenv.hostPlatform.system}.xwayland-satellite;
              })
              (final: prev: {
                pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
                  (python-final: python-prev: {
                    click-threading = python-prev.click-threading.overridePythonAttrs (oldAttrs: {
                      disabledTestPaths = (oldAttrs.disabledTestPaths or [ ]) ++ [ "docs/conf.py" ];
                    });
                  })
                ];
              })
              (final: prev: {
                codex = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.codex-bin;
                pi = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.pi;
                reasonix = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.reasonix;
                dsh = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.dsh;
                reasonix-desktop = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.reasonix-desktop;
                qoder = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.qoder;
                clawd-on-desk = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.clawd-on-desk;
                axolotl-launcher-bin = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.axolotl-launcher-bin;
                zen-browser = inputs.zen-browser.packages.${final.stdenv.hostPlatform.system}.default;
              })
              (final: prev: {
                # Firebat T5K uses the Clevo keyboard protocol, but upstream's
                # DMI compatibility gate does not know this rebranded model.
                linuxPackages_latest = prev.linuxPackages_latest.extend (
                  kernel-final: kernel-prev:
                  let
                    patched = kernel-prev.tuxedo-drivers.overrideAttrs (oldAttrs: {
                      patches = (oldAttrs.patches or [ ]) ++ [
                        (builtins.toFile "firebat-t5k-tuxedo-compat.patch" ''
                          --- a/src/tuxedo_compatibility_check/tuxedo_compatibility_check.c
                          +++ b/src/tuxedo_compatibility_check/tuxedo_compatibility_check.c
                          @@ -208,0 +209,6 @@
                          +	{
                          +		.matches = {
                          +			DMI_MATCH(DMI_SYS_VENDOR, "Firebat Computer"),
                          +			DMI_MATCH(DMI_PRODUCT_NAME, "T5K Series"),
                          +		},
                          +	},
                        '')
                      ];
                    });
                  in
                  {
                    tuxedo-drivers = patched;
                    tuxedo-keyboard = patched;
                  }
                );
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
                  inputs.dankcalendar.homeModules.dank-calendar
                  inputs.nix4nvchad.homeManagerModules.default
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
