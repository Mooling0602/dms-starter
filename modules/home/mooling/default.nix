let
  optionalImports = import ../../../utils/optional_import.nix;
in
{
  imports = optionalImports [
    ../../optional/screen-recorder.nix
    ../../optional/kde-connect.nix
  ];
}
