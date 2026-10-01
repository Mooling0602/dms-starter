{ lib, ... }:

{
  # 设备身份由各主机的 hosts/<host>/default.nix 赋值；这里不给 default，
  # 漏赋值时求值会直接报 "accessed but has no value defined"，而不是静默
  # 变成名为 user 的用户。
  options.my.username = lib.mkOption {
    type = lib.types.str;
    description = "Primary username of this host. Set in hosts/<host>/default.nix.";
  };

  options.my.hostname = lib.mkOption {
    type = lib.types.str;
    description = "Hostname of this host, used for machine-specific guards.";
  };
}
