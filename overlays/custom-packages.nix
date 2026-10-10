{ inputs }:

final: prev:

{
  codex = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.codex-bin;
  pi = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.pi;
  reasonix = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.reasonix;
  # The package is named deepseek-harness in Mooling0602/nix-packages;
  # the binary it produces is dsh.
  dsh = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.deepseek-harness-git;
  dsh-desktop = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.deepseek-harness-desktop;
  reasonix-desktop = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.reasonix-desktop;
  qoder = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.qoder;
  qoder-ide = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.qoder-ide;
  clawd-on-desk = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.clawd-on-desk;
  axolotl-launcher-bin = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.axolotl-launcher-bin;
  pebble-mail = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.pebble-mail;
  openfic = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.openfic;
  niri-input-portal = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.niri-input-portal;
  startlive = inputs.nix-packages.packages.${final.stdenv.hostPlatform.system}.startlive;
  zen-browser = inputs.zen-browser.packages.${final.stdenv.hostPlatform.system}.default;
  # QQ Wayland fix launcher, installed into the user environment
  # by modules/home/mooling/packages.nix. Upstream's nixosModules
  # is not imported: it would also add the package and pkgs.qq to
  # environment.systemPackages. qqPackage pins the launcher to the
  # same pkgs.qq so its --doctor check works.
  linuxqq-wayland-fix = inputs.linuxqq-wayland-fix.packages.${final.stdenv.hostPlatform.system}.default.override {
    qqPackage = final.qq;
  };
}
