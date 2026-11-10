let
  optionalImports = import ../../../utils/optional_import.nix;
in
{
  imports = optionalImports [
    ../../optional/screen-recorder.nix
    ../../optional/kde-connect.nix
    ../../optional/xembed-sni-proxy.nix
    ../../optional/wps-update-dialog.nix
  ];
}
