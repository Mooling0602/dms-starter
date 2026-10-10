final: prev:

{
  # Firebat T5K uses the Clevo keyboard protocol, but upstream's
  # DMI compatibility gate does not know this rebranded model.
  linuxPackages_latest = prev.linuxPackages_latest.extend (
    kernel-final: kernel-prev:
    let
      patched = kernel-prev.tuxedo-drivers.overrideAttrs (oldAttrs: {
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
