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
                xwayland-satellite = inputs.xwayland-satellite.packages.${final.system}.xwayland-satellite;
              })
              (final: prev: {
                pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
                  (python-final: python-prev: {
                    click-threading = python-prev.click-threading.overridePythonAttrs (oldAttrs: {
                      disabledTestPaths = (oldAttrs.disabledTestPaths or [ ]) ++ [ "docs/conf.py" ];
                    });
                    face-recognition-models = python-prev.face-recognition-models.overridePythonAttrs (oldAttrs: {
                      postPatch = (oldAttrs.postPatch or "") + ''
                        substituteInPlace face_recognition_models/__init__.py \
                          --replace-fail 'from pkg_resources import resource_filename' 'from importlib.resources import files' \
                          --replace-fail 'return resource_filename(__name__, "models/shape_predictor_68_face_landmarks.dat")' 'return str(files(__name__).joinpath("models/shape_predictor_68_face_landmarks.dat"))' \
                          --replace-fail 'return resource_filename(__name__, "models/shape_predictor_5_face_landmarks.dat")' 'return str(files(__name__).joinpath("models/shape_predictor_5_face_landmarks.dat"))' \
                          --replace-fail 'return resource_filename(__name__, "models/dlib_face_recognition_resnet_model_v1.dat")' 'return str(files(__name__).joinpath("models/dlib_face_recognition_resnet_model_v1.dat"))' \
                          --replace-fail 'return resource_filename(__name__, "models/mmod_human_face_detector.dat")' 'return str(files(__name__).joinpath("models/mmod_human_face_detector.dat"))'
                      '';
                    });
                  })
                ];
                gdal = prev.gdal.overrideAttrs (oldAttrs: {
                  disabledTests = oldAttrs.disabledTests ++ final.lib.optional (
                    oldAttrs.pname == "gdal-minimal"
                  ) "test_zarr_read_simple_sharding";
                });
                vtk = prev.vtk.overrideAttrs (oldAttrs: {
                  postPatch = (oldAttrs.postPatch or "") + ''
                    substituteInPlace Geovis/GDAL/vtkGDALRasterConverter.cxx \
                      --replace-fail '      char** categoryNames = band->GetCategoryNames();' '
#if (GDAL_VERSION_MAJOR > 3) || (GDAL_VERSION_MAJOR == 3 && GDAL_VERSION_MINOR >= 13)
      const char* const* categoryNames = band->GetCategoryNames();
#else
      char** categoryNames = band->GetCategoryNames();
#endif'

                    substituteInPlace IO/GDAL/vtkGDALRasterReader.cxx \
                      --replace-fail '    char** papszMetaData = GDALGetMetadata(this->GDALData, nullptr);' '
#if (GDAL_VERSION_MAJOR > 3) || (GDAL_VERSION_MAJOR == 3 && GDAL_VERSION_MINOR >= 13)
    const char* const* papszMetaData = GDALGetMetadata(this->GDALData, nullptr);
#else
    char** papszMetaData = GDALGetMetadata(this->GDALData, nullptr);
#endif' \
                      --replace-fail '  char** categoryNames = rasterBand->GetCategoryNames();' '
#if (GDAL_VERSION_MAJOR > 3) || (GDAL_VERSION_MAJOR == 3 && GDAL_VERSION_MINOR >= 13)
  const char* const* categoryNames = rasterBand->GetCategoryNames();
#else
  char** categoryNames = rasterBand->GetCategoryNames();
#endif' \
                      --replace-fail '  char** papszMetadata = GDALGetMetadata(this->Impl->GDALData, domain.c_str());' '
#if (GDAL_VERSION_MAJOR > 3) || (GDAL_VERSION_MAJOR == 3 && GDAL_VERSION_MINOR >= 13)
  const char* const* papszMetadata = GDALGetMetadata(this->Impl->GDALData, domain.c_str());
#else
  char** papszMetadata = GDALGetMetadata(this->Impl->GDALData, domain.c_str());
#endif'
                  '';
                });
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
