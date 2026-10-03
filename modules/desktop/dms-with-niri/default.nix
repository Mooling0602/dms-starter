{
  dms,
  pkgs,
  ...
}:

# Home-manager module, can be imported in user space.

let
  optionalImports = import ../../../utils/optional_import.nix;
in
{
  imports = optionalImports [
    ./terminal.nix
    ./ui.nix
    ./xdg-portals.nix
    ./packages.nix
    ./fcitx-theme-sync.nix
    ./backup.nix
  ];

  programs.dank-material-shell = {
    enable = true;
    # 直接用本桌面自己的 flake input，flake.nix 不再需要 dmsPackage overlay，
    # 也不必把它经 extraSpecialArgs 透传到所有用户的 Home Manager 模块。
    package = dms.packages.${pkgs.stdenv.hostPlatform.system}.default;
    enableDynamicTheming = true;
    enableSystemMonitoring = true;
    systemd.enable = true;
  };

  programs.dank-calendar = {
    enable = true;
    systemd.enable = true;
  };

  # 原先写死在 flake.nix 的 home-manager.users.<name> 里；随 dsearch 的 HM 模块
  # 一起下沉到本层，这样未选中本桌面时不会启用。
  programs.dsearch.enable = true;
}
