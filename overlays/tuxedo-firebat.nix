final: prev:

{
  # Firebat T5K uses the Clevo keyboard protocol, but upstream's
  # DMI compatibility gate does not know this rebranded model.
  linuxPackages_latest = prev.linuxPackages_latest.extend (
    kernel-final: kernel-prev:
    let
      patched = kernel-prev.tuxedo-drivers.overrideAttrs (oldAttrs: {
        # Upstream's Makefile re-passes $(MAKEFLAGS) to its recursive make
        # calls, but nixpkgs >= c736bb8b passes `cmd_sign=...$(space)$@`
        # through makeFlags. Those references are escaped for the outer
        # make, so the child shell receives a literal `$(space)` and dies
        # with a syntax error. The child make inherits makeFlags from the
        # environment anyway, so the explicit pass-through is redundant.
        postPatch = (oldAttrs.postPatch or "") + ''
          substituteInPlace Makefile \
            --replace-fail 'M=$(PWD) $(MAKEFLAGS) modules_install' 'M=$(PWD) modules_install' \
            --replace-fail 'M=$(PWD) $(MAKEFLAGS) clean' 'M=$(PWD) clean' \
            --replace-fail 'M=$(PWD) $(MAKEFLAGS) modules' 'M=$(PWD) modules'
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
