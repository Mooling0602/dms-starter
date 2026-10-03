{
  description = "NixOS configuration for DankMaterialShell desktop";

  inputs = {
    # Use zstd tarball, see more in NixOS/nixpkgs#535272
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # 钉住 rev，不跟随 master：DMS 默认分支是 master（未发布变更），
    # 而 AvengeMedia/DankMaterialShell 的 release tag 与 master 是分叉关系。
    # 固定 rev 同时锁死它自己的传递输入 dank-qml-common（该 rev 的 flake.lock
    # 是确定内容），避免 QML 组件与 shell 版本错配导致的界面异常。
    # 升级方法见 MAINTENANCE.md。
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/a8623e3ccb8a09bfcd5f793f23687282f5c6dd64";
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
    # ChatGPT Community（codex-desktop）：OpenAI 官方 Linux ChatGPT 桌面应用的
    # 社区重打包（签名校验后的官方 .deb），经 homeManagerModules 集成。
    codex-desktop = {
      url = "github:ilysenko/codex-desktop-linux";
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
      # 只枚举 hosts/ 下的主机目录：目录名即主机名，设备身份由各主机自己的
      # hosts/<host>/default.nix 提供。新增设备只需新建目录，不必改本文件。
      entries = builtins.readDir ./hosts;
      hostNames = builtins.filter (
        name: entries.${name} == "directory" && builtins.pathExists ./hosts/${name}/default.nix
      ) (builtins.attrNames entries);
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs hostNames (hostname: nixpkgs.lib.nixosSystem {
        # 注入目录名，hosts/<host>/default.nix 直接用它填 my.hostname。
        # inputs 一并注入：桌面实现层（modules/desktop/<name>/system.nix）需要它
        # 把自己专属的 Home Manager 模块挂进用户环境，这样 flake.nix 里就不必
        # 出现任何按桌面名判断的分支。
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
            # my.username / my.hostname 由 ./hosts/${hostname}/default.nix 提供。
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
                # 跟随 niri 输入锁定的 unstable 构建，比 nixpkgs 收录的版本更新。
                xwayland-satellite = inputs.niri.packages.${final.stdenv.hostPlatform.system}.xwayland-satellite-unstable;
              })
              (final: prev: {
                pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
                  (python-final: python-prev: {
                    click-threading = python-prev.click-threading.overridePythonAttrs (oldAttrs: {
                      disabledTestPaths = (oldAttrs.disabledTestPaths or [ ]) ++ [ "docs/conf.py" ];
                    });
                    # dlib 20.0.1 有两处回归，均在此覆盖，上游适配后移除（见 MAINTENANCE.md）：
                    #  1) num_available_cpu_cores() 移到模块顶层，nixpkgs 自带 build-cores.patch
                    #     按旧位置书写导致 Hunk 失配 -- 用匹配新源码的补丁替换。
                    #  2) CMakeBuild 不再注册 --set 为 distutils option，nixpkgs 默认 preConfigure
                    #     用 "--set" 传 CMake flags 会报 "option --set not recognized"；
                    #     dlib 20.0.1 改为读取 DLIB_* 环境变量，故据其重写 preConfigure。
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
                            key=''${key%:*}   # 去掉 CMake 类型后缀（-DVAR:TYPE=VALUE -> VAR）
                            # dlib 20.0.1 仅从以 DLIB_ 开头的环境变量读取 CMake 选项，
                            # 且把变量名原样作为 CMake 变量（不剥前缀）。只导出本就
                            # 以 DLIB_ 开头的 flag（如 DLIB_USE_CUDA）；BUILD_SHARED_LIBS、
                            # USE_SSE/AVX 等其余项由 dlib 默认决定。
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
                # Mooling0602/nix-packages 中 dsh 的包名是 deepseek-harness（产出的二进制为 dsh）。
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
                # 这里只放桌面无关的模块。DMS 生态的 Home Manager 模块
                # （dank-material-shell / dsearch / dank-calendar）由当前桌面层
                # 自己导入，见 modules/desktop/dms-with-niri/default.nix——
                # 否则切到 KDE 后 dms-shell、dsearch、dankcalendar 乃至
                # fcitx5-dms-theme-sync 仍会进入用户环境。
                imports = [
                  ./modules/home
                  inputs.nix4nvchad.homeManagerModules.default
                  inputs.codex-desktop.homeManagerModules.default
                ];
                # api-key-model-visibility：在模型选择器中显示 API-key 提供商
                # （见 ~/.codex/config.toml 的 model_providers，如 B.AI 的 GLM）返回的模型
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
