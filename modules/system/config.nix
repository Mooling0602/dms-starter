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
    # 它是否与实际导入的实现一致，由各实现模块自己的断言校验。
    my.desktop = lib.mkOption {
      type = lib.types.str;
      description = "Active desktop module name for this host, set in hosts/<host>/default.nix.";
    };

    # 任一桌面实现被加载时，由它自己置为 true。
    #
    # 身份校验的主体在各实现模块内部（它们直接断言自己就是 my.desktop 声明的
    # 那个桌面，名字从自身目录名推导）。但「桌面层导入了、imports 里却漏掉
    # 实现」这种情况下没有任何实现模块存在，它的断言自然也不存在，只能由这里
    # 兜底，否则会静默地不加载任何桌面。
    my.desktopImplementationLoaded = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether any modules/desktop/<name>/system.nix implementation was imported.";
    };
  };

  config.assertions = [
    {
      assertion = config.my.desktopImplementationLoaded;
      message = ''
        没有任何桌面实现被加载：my.desktop 声明的是 "${config.my.desktop}"，
        但没有任何 modules/desktop/<name>/system.nix 被导入。

        通常意味着 hosts/<host>/desktop/${config.my.desktop}/default.nix 的
        imports 里漏掉了
          ../../../../modules/desktop/${config.my.desktop}/system.nix
        或者路径写错后被执行期求值的 optionalImports 静默跳过（会伴随一条
        求值警告）。桌面实现的名字由它自己的目录名推导，无需手工维护。
      '';
    }
  ];
}
