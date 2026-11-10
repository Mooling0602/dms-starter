final: prev:

{
  # Firebat T5K uses the Clevo keyboard protocol, but upstream's
  # DMI compatibility gate does not know this rebranded model.
  linuxPackages_latest = prev.linuxPackages_latest.extend (
    kernel-final: kernel-prev:
    let
      patched = kernel-prev.tuxedo-drivers.overrideAttrs (oldAttrs: {
        # Fail if a future source layout change leaves the rules directory empty.
        postInstall = (oldAttrs.postInstall or "") + ''
            if [ -z "$(find "$out/etc/udev/rules.d" -name '*.rules' -print -quit 2>/dev/null)" ]; then
              echo "tuxedo-drivers: no udev rules installed, check the source layout" >&2
              exit 1
            fi
          '';

        # nixpkgs keeps System.map in the kernel dev output since 48c35672,
        # so the kernel's modules_install now runs depmod for external
        # modules and writes modules.alias & friends into this package's
        # own output root, which then collides with the real kernel module
        # tree during aggregateModules. depmod is a no-op here anyway: the
        # aggregator regenerates the maps for the merged tree.
        installFlags = (oldAttrs.installFlags or [ ]) ++ [ "DEPMOD=true" ];

        patches = (oldAttrs.patches or [ ]) ++ [
          (builtins.toFile "firebat-t5k-tuxedo-compat.patch" ''
            --- a/src/tuxedo_compatibility_check/tuxedo_compatibility_check.c
            +++ b/src/tuxedo_compatibility_check/tuxedo_compatibility_check.c
            @@ -208,0 +209,6 @@
            +	{
            +		.matches = {
            +			DMI_MATCH(DMI_SYS_VENDOR, "Firebat Computer"),
            +			DMI_MATCH(DMI_PRODUCT_NAME, "T5K Series"),
            +		},
            +	},
          '')
        ];
      });
    in
    {
      tuxedo-drivers = patched;
      tuxedo-keyboard = patched;
    }
  );
}
