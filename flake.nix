{
  description = "NixOS configuration for DankMaterialShell desktop";

  inputs = {
    # Use zstd tarball, see more in NixOS/nixpkgs#535272
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
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
    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
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
    # ChatGPT Community (codex-desktop): community repack of the official
    # Linux .deb, integrated through homeManagerModules.
    codex-desktop = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # QQ Wayland fixes: screen sharing, screenshots and clipboard.
    linuxqq-wayland-fix = {
      url = "github:SHORiN-KiWATA/linuxqq-wayland-fix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      dw-proton,
      ...
    }:
    let
      # Enumerate only directories under hosts/: the directory name is the
      # hostname, and device identity lives in each hosts/<host>/default.nix.
      # Adding a device means adding a directory, not editing this file.
      entries = builtins.readDir ./hosts;
      hostNames = builtins.filter (
        name: entries.${name} == "directory" && builtins.pathExists ./hosts/${name}/default.nix
      ) (builtins.attrNames entries);
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs hostNames (hostname: nixpkgs.lib.nixosSystem {
        # Inject the directory name; hosts/<host>/default.nix uses it as
        # my.hostname. inputs is injected too, so desktop implementations
        # (modules/desktop/<name>/system.nix) can mount their own Home Manager
        # modules without any desktop-specific branch in this file.
        specialArgs = { inherit hostname inputs; };
        modules = [
          ./hosts/${hostname}
          home-manager.nixosModules.home-manager
          (
            { ... }:
            {
              programs.steam.extraCompatPackages = [
                dw-proton.packages.x86_64-linux.dw-proton
              ];
            }
          )
          ({ config, ... }:
          {
            # my.username / my.hostname come from ./hosts/${hostname}/default.nix.
            nixpkgs.overlays = [
              inputs.aagl.overlays.default
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
                # Newer than the nixpkgs build; tracks the revision pinned by niri.
                xwayland-satellite = inputs.niri.packages.${final.stdenv.hostPlatform.system}.xwayland-satellite-unstable;
              })
              (final: prev: {
                pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
                  (python-final: python-prev: {
                    click-threading = python-prev.click-threading.overridePythonAttrs (oldAttrs: {
                      disabledTestPaths = (oldAttrs.disabledTestPaths or [ ]) ++ [ "docs/conf.py" ];
                    });
                    # dlib 20.0.1 has two regressions, both overridden here.
                    # Remove once upstream catches up (see MAINTENANCE.md):
                    #  1) num_available_cpu_cores() moved to module scope, so
                    #     nixpkgs' build-cores.patch no longer applies; replaced
                    #     with a patch matching the new layout.
                    #  2) CMakeBuild no longer accepts --set as a distutils
                    #     option, so nixpkgs' default preConfigure fails with
                    #     "option --set not recognized". dlib 20.0.1 reads
                    #     DLIB_* environment variables instead, hence the
                    #     preConfigure rewrite below.
                    dlib = python-prev.dlib.overrideAttrs (oldAttrs: {
                      patches = [
                        ./patches/dlib-build-cores.patch
                      ];
                      preConfigure = ''
                        for flag in $cmakeFlags; do
                          if [[ "$flag" == -D* ]]; then
                            keyval=''${flag#-D}
                            key=''${keyval%%=*}
                            val=''${keyval#*=}
                            # Strip the CMake type suffix: -DVAR:TYPE=VALUE yields VAR.
                            key=''${key%:*}
                            # dlib 20.0.1 reads CMake options only from variables
                            # prefixed DLIB_, using the name verbatim. Export just
                            # those flags (e.g. DLIB_USE_CUDA); BUILD_SHARED_LIBS
                            # and USE_SSE/AVX keep dlib's own defaults.
                            if [[ "$key" == DLIB_* ]]; then
                              export "$key=$val"
                            fi
                          fi
                        done
                      '';
                    });
                  })
                ];
              })
              (final: prev: {
                codex = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.codex-bin;
                pi = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.pi;
                reasonix = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.reasonix;
                # The package is named deepseek-harness in Mooling0602/nix-packages;
                # the binary it produces is dsh.
                dsh = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.deepseek-harness-git;
                dsh-desktop = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.deepseek-harness-desktop;
                reasonix-desktop = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.reasonix-desktop;
                qoder = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.qoder;
                qoder-ide = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.qoder-ide;
                clawd-on-desk = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.clawd-on-desk;
                axolotl-launcher-bin = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.axolotl-launcher-bin;
                pebble-mail = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.pebble-mail;
                openfic = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.openfic;
                niri-input-portal = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.niri-input-portal;
                startlive = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.startlive;
                zen-browser = inputs.zen-browser.packages.${final.stdenv.hostPlatform.system}.default;
                # QQ Wayland fix launcher, installed into the user environment
                # by modules/home/mooling/packages.nix. Upstream's nixosModules
                # is not imported: it would also add the package and pkgs.qq to
                # environment.systemPackages. qqPackage pins the launcher to the
                # same pkgs.qq so its --doctor check works.
                linuxqq-wayland-fix = inputs.linuxqq-wayland-fix.packages.${final.stdenv.hostPlatform.system}.default.override {
                  qqPackage = final.qq;
                };
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
              (final: prev: {
                # OBS 31+ spawns bin/obs-nvenc-test to probe NVENC capability,
                # but nixpkgs only runs addDriverRunpath on lib/*.so, so the
                # probe cannot dlopen libnvidia-encode and all NVENC encoders
                # disappear from the UI (nixpkgs#382666). QSV fails with
                # MFX_ERR_NOT_FOUND because the oneVPL GPU runtime is not on
                # the dispatcher search path. See MAINTENANCE.md before
                # removing this overlay.
                obs-studio = prev.obs-studio.overrideAttrs (old: {
                  postFixup = (old.postFixup or "") + ''
                    addDriverRunpath $out/bin/.obs-nvenc-test-wrapped
                    wrapProgram $out/bin/obs \
                      --set-default ONEVPL_SEARCH_PATH "${final.vpl-gpu-rt}/lib"
                  '';
                });
              })
            ];
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.${config.my.username} =
              { ... }:
              {
                # Only desktop-independent modules belong here. DMS Home Manager
                # modules (dank-material-shell / dsearch / dank-calendar) are
                # imported by the active desktop layer, see
                # modules/desktop/dms-with-niri/default.nix; importing them here
                # would leave dms-shell, dsearch, dankcalendar and
                # fcitx5-dms-theme-sync active under KDE too.
                imports = [
                  ./modules/home
                  inputs.nix4nvchad.homeManagerModules.default
                  inputs.codex-desktop.homeManagerModules.default
                ];
                # api-key-model-visibility lists models from API key providers
                # in the model picker (see model_providers in ~/.codex/config.toml).
                programs.codexDesktopLinux = {
                  enable = true;
                  linuxFeatures = [ "api-key-model-visibility" ];
                };
              };
            home-manager.extraSpecialArgs = inputs // {
              inherit hostname;
              username = config.my.username;
            };
          })
        ];
      });
    };
}
