{ ... }:

# system module for the setup of desktop module kde-plasma

let
  optionalImports = import ../../../utils/optional_import.nix;
in
{
  imports = optionalImports [
    ./keyring.nix
  ];

  # 本模块自报家门，供 modules/system/config.nix 的断言与 my.desktop 对比。
  # 与 dms-with-niri/system.nix 里的同名赋值一起，构成“实际加载了哪个桌面”。
  my.desktopLayer = "kde-plasma";

  services.desktopManager.plasma6.enable = true;

  services.displayManager.plasma-login-manager = {
    enable = true;
  };

  # Use password in login screen to auto unlock keyring.
  security.pam.services.plasmalogin.howdy.enable = false;
}
