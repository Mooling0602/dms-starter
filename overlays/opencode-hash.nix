# opencode 2.2.5 pins a stale fixed-output hash for its bun
# node_modules derivation. The pinned nixpkgs rev still carries
# sha256-xfOVcw1+..., but the resolved dependency tree hashes to
# sha256-prx9dX7k..., so the whole system closure fails to build.
# Upstream fixed it in c399e1b7fb ("opencode: fix hash"), which only
# touches this attribute; the value below is copied from that commit.

final: prev:

let
  inherit (prev.stdenv) hostPlatform;
in
{
  opencode = prev.opencode.overrideAttrs (old: {
    node_modules = old.node_modules.overrideAttrs (_: {
      outputHash =
        if hostPlatform.isLinux then
          "sha256-prx9dX7kUvs/E3zopkaPk5LXh3xJAy5sZeum/W8L7cA="
        else if hostPlatform.isDarwin then
          "sha256-dIveiaiPFGSItwLyeMuPDxTE9gpvvnlTCB/+nG24qCc="
        else
          throw "opencode: unsupported platform for node_modules hash";
    });
  });
}
