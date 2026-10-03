{ config, lib, ... }:

{
  options = {
    # 设备身份由各主机的 hosts/<host>/default.nix 赋值；这里不给 default，
    # 漏赋值时求值会直接报 "accessed but has no value defined"，而不是静默
    # 变成名为 user 的用户。
    my.username = lib.mkOption {
      type = lib.types.str;
      description = "Primary username of this host. Set in hosts/<host>/default.nix.";
    };

    my.hostname = lib.mkOption {
      type = lib.types.str;
      description = "Hostname of this host, used for machine-specific guards.";
    };

    # 本机“声明”要用的桌面模块名，对应 hosts/<host>/desktop/<name>/。
    # 仅供其他模块做条件判断（如 mkIf config.my.desktop == "kde-plasma"）。
    # 桌面模块本身仍由 hosts/<host>/default.nix 的 imports 选择：imports 的
    # 求值早于 config，无法用这个选项驱动导入，那边用的是同名的 let 绑定。
    # 它是否与实际导入的层一致，由下面的 assertions 校验。
    my.desktop = lib.mkOption {
      type = lib.types.str;
      description = "Active desktop module name for this host, set in hosts/<host>/default.nix.";
    };

    # 实际被导入的桌面实现“自报”的名字，由 modules/desktop/<name>/system.nix
    # 赋值。它和 my.desktop 分开记录的理由：两者来自两处独立文本，只有分开
    # 才能对比出「声明了 A、实际加载了 B」这种半对半错的配置。
    #
    # 默认值是空串而非留空，是为了让「一个桌面层都没导入」也走同一条断言，
    # 而不是变成难以定位的 "option accessed but has no value defined"。
    my.desktopLayer = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Name self-reported by the imported modules/desktop/<name>/ implementation.";
    };
  };

  config.assertions = [
    {
      assertion = config.my.desktopLayer == config.my.desktop;
      message =
        ''
          桌面模块不一致：my.desktop 声明的是 "${config.my.desktop}"，
          但实际加载的桌面实现自报为 "${config.my.desktopLayer}"。
        ''
        + lib.optionalString (config.my.desktopLayer == "") ''
          没有任何实现报告 my.desktopLayer - 通常意味着
          hosts/<host>/desktop/${config.my.desktop}/default.nix 的 imports 里
          漏掉了 ../../../../modules/desktop/${config.my.desktop}/system.nix。
        ''
        + ''
          这两处由 hosts/<host>/default.nix 顶部的 `desktop` let 绑定统一驱动：
          它同时决定 my.desktop 的值与 import 的路径，被导入的实现再把自己的
          名字写成 my.desktopLayer。出现本提示通常意味着只改了其中一处。
        '';
    }
  ];
}
