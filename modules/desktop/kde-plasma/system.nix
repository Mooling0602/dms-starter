{ config, ... }:

# system module for the setup of desktop module kde-plasma

let
  optionalImports = import ../../../utils/optional_import.nix;

  # 本实现的桌面名，从本文件实际所在的目录名推导（modules/desktop/<name>/）。
  # 不手写字符串，因此目录被重命名时断言会自动跟着变，不会和目录名漂移。
  # 用裸 baseNameOf：它在 Nix prelude 中（与 builtins.baseNameOf 等价）。
  desktopName = baseNameOf ./.;
in
{
  imports = optionalImports [
    ./keyring.nix
  ];

  # 供 modules/system/config.nix 的兜底断言使用：只有本模块存在时才会置位。
  # 「桌面层导入了、imports 里却漏掉实现」时它保持 false，由那边报错。
  my.desktopImplementationLoaded = true;

  # 本模块直接断言自己就是 my.desktop 声明的那个桌面。对比的两侧来自独立
  # 来源——my.desktop 是 hosts/<host>/default.nix 顶部手写的 let 绑定，
  # desktopName 是本文件实际所在的目录名——所以「声明了 A、实际加载了 B」
  # 这种半对半错会在求值阶段被捕获（曾经在 kde-plasma 上发生过）。
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
