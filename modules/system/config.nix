{ config, lib, ... }:

{
  options.my.username = lib.mkOption {
    type = lib.types.str;
    default = "mooling";
    description = "Primary username. Override in flake.nix to change.";
  };

  options.my.hostname = lib.mkOption {
    type = lib.types.str;
    default = "mooling-laptop";
    description = "Hostname for machine-specific config guards.";
  };
}
