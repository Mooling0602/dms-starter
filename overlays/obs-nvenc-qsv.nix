final: prev:

{
  # OBS 31+ spawns bin/obs-nvenc-test to probe NVENC capability,
  # but nixpkgs only runs addDriverRunpath on lib/*.so, so the
  # probe cannot dlopen libnvidia-encode and all NVENC encoders
  # disappear from the UI (nixpkgs#382666). QSV fails with
  # MFX_ERR_NOT_FOUND because the oneVPL GPU runtime is not on
  # the dispatcher search path. See MAINTENANCE.md before
  # removing this overlay.
  obs-studio = prev.obs-studio.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      addDriverRunpath $out/bin/.obs-nvenc-test-wrapped
      wrapProgram $out/bin/obs \
        --set-default ONEVPL_SEARCH_PATH "${final.vpl-gpu-rt}/lib"
    '';
  });
}
