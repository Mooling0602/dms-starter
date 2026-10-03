let
  optionalImports = import ../../../../utils/optional_import.nix;
in
{
  imports = optionalImports [
    ../../../../modules/desktop/kde-plasma/system.nix
  ];
}
