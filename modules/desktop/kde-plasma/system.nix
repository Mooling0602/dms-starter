{ config, ... }:

# system module for the setup of desktop module kde-plasma

let
  optionalImports = import ../../../utils/optional_import.nix;

  # This implementation's desktop name, derived from this file's own directory
  # (modules/desktop/<name>/). Not hardcoded, so the assertion follows a rename
  # instead of drifting from the directory name. Bare baseNameOf is used because
  # it is in the Nix prelude (equivalent to builtins.baseNameOf).
  desktopName = baseNameOf ./.;
in
{
  imports = optionalImports [
    ./keyring.nix
  ];

  # Used by the fallback assertion in modules/system/config.nix: only set when
  # this module is present. Stays false when the desktop layer is imported but
  # the implementation is missing from `imports`, and that side reports it.
  my.desktopImplementationLoaded = true;

  # This module asserts that it is the desktop declared by my.desktop. The two
  # sides come from independent sources: my.desktop is the let binding written
  # by hand at the top of hosts/<host>/default.nix, desktopName is this file's
  # own directory name. The half-wrong case (declared A, loaded B) is therefore
  # caught at evaluation time (this did happen on kde-plasma).
  assertions = [
    {
      assertion = config.my.desktop == desktopName;
      message = ''
        桌面模块不一致：my.desktop 声明的是 "${config.my.desktop}"，
        但实际加载的桌面实现是 "${desktopName}"。

        当前加载的是 modules/desktop/${desktopName}/system.nix。
        通常意味着 hosts/<host>/default.nix 顶部的 `desktop` let 绑定与
        hosts/<host>/desktop/${config.my.desktop}/default.nix 里 import 的实现
        不是同一个：前者决定 my.desktop，后者决定实际加载哪个实现。
      '';
    }
  ];

  services.desktopManager.plasma6.enable = true;

  services.displayManager.plasma-login-manager = {
    enable = true;
  };

  # Use password in login screen to auto unlock keyring.
  security.pam.services.plasmalogin.howdy.enable = false;
}
