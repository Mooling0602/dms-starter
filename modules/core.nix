# Global wiring shared by every host, injected by flake.nix alongside
# ./hosts/<hostname>: the nixpkgs overlay set and the Home Manager bridge.
# Device identity stays in hosts/<host>/default.nix; anything desktop
# specific belongs in modules/desktop/<name>/ instead.

{ config, inputs, hostname, ... }:

{
  nixpkgs.overlays = import ../overlays { inherit inputs; };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";

  # my.username comes from ./hosts/<hostname>/default.nix.
  home-manager.users.${config.my.username} = {
    # Only desktop-independent modules belong here. DMS Home Manager
    # modules (dank-material-shell / dsearch / dank-calendar) are imported
    # by the active desktop layer, see modules/desktop/dms-with-niri;
    # importing them here would leave dms-shell, dsearch, dankcalendar and
    # fcitx5-dms-theme-sync active under KDE too.
    # Flake HM modules are referenced by this wiring module (which has
    # access to inputs via specialArgs) instead of inside ./home, so HM
    # modules never need an inputs argument; same pattern as the desktop
    # layer's system.nix.
    imports = [
      ./home
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
}
