final: prev:

{
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      click-threading = python-prev.click-threading.overridePythonAttrs (oldAttrs: {
        disabledTestPaths = (oldAttrs.disabledTestPaths or [ ]) ++ [ "docs/conf.py" ];
      });
      # dlib 20.0.1 has two regressions, both overridden here.
      # Remove once upstream catches up (see MAINTENANCE.md):
      #  1) num_available_cpu_cores() moved to module scope, so
      #     nixpkgs' build-cores.patch no longer applies; replaced
      #     with a patch matching the new layout.
      #  2) CMakeBuild no longer accepts --set as a distutils
      #     option, so nixpkgs' default preConfigure fails with
      #     "option --set not recognized". dlib 20.0.1 reads
      #     DLIB_* environment variables instead, hence the
      #     preConfigure rewrite below.
      dlib = python-prev.dlib.overrideAttrs (oldAttrs: {
        patches = [
          ../patches/dlib-build-cores.patch
        ];
        preConfigure = ''
          for flag in $cmakeFlags; do
            if [[ "$flag" == -D* ]]; then
              keyval=''${flag#-D}
              key=''${keyval%%=*}
              val=''${keyval#*=}
              # Strip the CMake type suffix: -DVAR:TYPE=VALUE yields VAR.
              key=''${key%:*}
              # dlib 20.0.1 reads CMake options only from variables
              # prefixed DLIB_, using the name verbatim. Export just
              # those flags (e.g. DLIB_USE_CUDA); BUILD_SHARED_LIBS
              # and USE_SSE/AVX keep dlib's own defaults.
              if [[ "$key" == DLIB_* ]]; then
                export "$key=$val"
              fi
            fi
          done
        '';
      });
    })
  ];
}
