{ lib, ... }:

{
  options.my.username = lib.mkOption {
    type = lib.types.str;
    default = "user";
    description = "Primary username. Override in flake.nix to change.";
  };

  options.my.hostname = lib.mkOption {
    type = lib.types.str;
    default = "nixos";
    description = "Hostname for machine-specific config guards.";
  };
}
