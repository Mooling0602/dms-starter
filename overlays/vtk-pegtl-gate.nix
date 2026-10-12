final: prev:

{
  # Temporary bypass for the VTK pegtl rename gate in the pinned nixpkgs, see
  # MAINTENANCE.md. nixpkgs' generic.nix renames the VTK::pegtl module when
  # `versionOlder version "9.6"` holds, while the matching external lookup flag
  # is named with `versionAtLeast version "9.6"`. On 9.5.x the module therefore
  # becomes VTK::vtkpegtl but the flag still reads
  # VTK_MODULE_USE_EXTERNAL_VTK_pegtl, so the external lookup misses and
  # configure aborts with "Could not find the PEGTL external dependency".
  # This restores upstream commit 00718d4899, which inverts the gate.
  vtk_9_5 = prev.vtk_9_5.overrideAttrs (oldAttrs: {
    postPatch = prev.lib.optionalString (prev.lib.versionAtLeast oldAttrs.version "9.6") ''
      substituteInPlace ThirdParty/pegtl/vtk.module Common/DataModel/vtk.module IO/MotionFX/vtk.module \
        --replace-fail \
          "VTK::pegtl" \
          "VTK::vtkpegtl"
      substituteInPlace ThirdParty/pegtl/vtkpegtl/CMakeLists.txt \
        --replace-fail \
          "target_compile_features(pegtl" \
          "target_compile_features(vtkpegtl"
    '';
  });
}
