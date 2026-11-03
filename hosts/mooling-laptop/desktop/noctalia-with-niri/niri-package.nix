{ pkgs, ... }:

let
  revision = "a8562a1126922ed4c1c94d34c1dbb26633491d05";
  src = pkgs.fetchFromGitHub {
    owner = "niri-wm";
    repo = "niri";
    rev = revision;
    hash = "sha256-AtuZOzsb9p+TTzkgaPjvl+5YRsgKc+RlIQMyozOmY5A=";
  };
in
{
  # Test the newer Smithay multi-GPU rendering path. See MAINTENANCE.md.
  programs.niri.package = pkgs.niri.overrideAttrs (_: {
    version = "26.04-unstable-2026-10-31";
    inherit src;
    cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
      inherit src;
      hash = "sha256-4VQqTrVB6p8M3U7xqF+K6vSKrQcqhW+OnZyAp6j/fGA=";
    };
    doInstallCheck = false;
  });
}
