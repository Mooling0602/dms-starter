{ config, lib, ... }:

{
  options = {
    # Device identity is assigned by each host's hosts/<host>/default.nix; no
    # default is set here, so a missing assignment fails evaluation with
    # "accessed but has no value defined" instead of silently becoming a user
    # named "user".
    my.username = lib.mkOption {
      type = lib.types.str;
      description = "Primary username of this host. Set in hosts/<host>/default.nix.";
    };

    my.hostname = lib.mkOption {
      type = lib.types.str;
      description = "Hostname of this host, used for machine-specific guards.";
    };

    # Desktop module this host declares, corresponding to
    # hosts/<host>/desktop/<name>/. Used only by other modules for conditions
    # such as mkIf config.my.desktop == "kde-plasma". The module itself is
    # still selected by imports in hosts/<host>/default.nix: imports are
    # evaluated before config, so a same-named let binding drives them there.
    # Consistency with the imported implementation is asserted by each
    # implementation module.
    my.desktop = lib.mkOption {
      type = lib.types.str;
      description = "Active desktop module name for this host, set in hosts/<host>/default.nix.";
    };

    # Set to true by whichever desktop implementation is loaded.
    #
    # Identity validation lives inside each implementation module (it asserts
    # it is the desktop declared by my.desktop, taking the name from its own
    # directory). But when the desktop layer is imported while the
    # implementation is missing from imports, no implementation module exists
    # and its assertion never runs, so this fallback is the only guard against
    # silently loading no desktop at all.
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
