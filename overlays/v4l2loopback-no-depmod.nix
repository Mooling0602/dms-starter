final: prev:

let
  # nixpkgs keeps System.map in the kernel dev output since 48c35672, so
  # the kernel's modules_install now runs depmod for external modules and
  # writes modules.alias & friends into this package's own output root.
  # aggregateModules then sees both the package and the real kernel module
  # tree providing lib/modules/<ver>/modules.alias and fails with a
  # "conflicting subpath" error. depmod is a no-op here anyway: the
  # aggregator regenerates the maps for the merged tree.
  # Upstream fix: NixOS/nixpkgs#575861.
  withoutDepmod =
    kernelPackages:
    kernelPackages.extend (
      _kernelFinal: kernelPrev:
      {
        v4l2loopback = kernelPrev.v4l2loopback.overrideAttrs (oldAttrs: {
          installFlags = (oldAttrs.installFlags or [ ]) ++ [ "DEPMOD=true" ];
        });
      }
    );
in
{
  linuxPackages = withoutDepmod prev.linuxPackages;
  linuxPackages_latest = withoutDepmod prev.linuxPackages_latest;
}
