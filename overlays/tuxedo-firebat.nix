final: prev:

{
  # Firebat T5K uses the Clevo keyboard protocol, but upstream's
  # DMI compatibility gate does not know this rebranded model.
  linuxPackages_latest = prev.linuxPackages_latest.extend (
    kernel-final: kernel-prev:
    let
      patched = kernel-prev.tuxedo-drivers.overrideAttrs (oldAttrs: {
        # Linux 7.3 removed struct acpi_driver and module_acpi_driver() in
        # 541b293ab186 ("ACPI: bus: Eliminate struct acpi_driver"). Upstream
        # moved clevo_acpi, tuxi_acpi and gxtp7380 to platform_driver with an
        # ACPI match table in 4.24.0, which is newer than the 4.20.1 that
        # nixpkgs still pins, so build the driver from the newest tagged
        # release instead of carrying the API rewrite as a local patch.
        version = "4.25.0";
        src = final.fetchFromGitLab {
          group = "tuxedocomputers";
          owner = "development/packages";
          repo = "tuxedo-drivers";
          rev = "v4.25.0";
          hash = "sha256-AER+JPl3lem1OFV51VdOZAnr3Uy1BFSpEJNrE+shYis=";
        };

        # Upstream moved the udev rules from usr/ to files/usr/ together with
        # that refactor. nixpkgs' postInstall rewrites and installs them from
        # the source tree, so point it at the new location and fail loudly if
        # upstream moves them again: an empty rules directory would otherwise
        # pass udevCheckHook without installing anything.
        postInstall =
          builtins.replaceStrings [ "usr/lib/udev/rules.d" ] [ "files/usr/lib/udev/rules.d" ] (
            oldAttrs.postInstall or ""
          )
          + ''
            if [ -z "$(find "$out/etc/udev/rules.d" -name '*.rules' -print -quit 2>/dev/null)" ]; then
              echo "tuxedo-drivers: no udev rules installed, check the source layout" >&2
              exit 1
            fi
          '';

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
