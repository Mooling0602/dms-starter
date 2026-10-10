final: prev:

{
  qt6Packages = prev.qt6Packages // {
    # DMS generates KDE .colors files for qt6ct. Upstream qt6ct
    # cannot read them without the qt6ct-kde compatibility patch.
    qt6ct = prev.qt6Packages.qt6ct.overrideAttrs (previousAttrs: {
      buildInputs = (previousAttrs.buildInputs or [ ]) ++ [
        final.kdePackages.kconfig
        final.kdePackages.kcolorscheme
        final.kdePackages.kiconthemes
      ];
      patches = (previousAttrs.patches or [ ]) ++ [
        (final.fetchpatch {
          url = "https://aur.archlinux.org/cgit/aur.git/plain/qt6ct-shenanigans.patch?h=qt6ct-kde&id=8c1003e13b7e7545e717273e0716f095f195bd13";
          hash = "sha256-Q8QOMDy84z6FD0OkSLylEwB+/Zs50jcUgR+4J6Lmwmk=";
        })
      ];
    });
  };
}
