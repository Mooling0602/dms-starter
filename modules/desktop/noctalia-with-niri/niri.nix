{ config, lib, pkgs, ... }:

# Home-manager module, has been imported in noctalia-with-niri.
#
# Declarative niri session config for this desktop. The isolation strategy is
# described in AGENTS.md, section "noctalia-with-niri 桌面层": this desktop reads
# its own config file, while dms-with-niri keeps owning the default
# ~/.config/niri/config.kdl.

let
  # The look declared by this desktop (see default.nix). Read back through
  # config so the palette check below follows the settings instead of repeating
  # them, and so a wallpaper or scheme change re-runs the check.
  settings = config.programs.noctalia.settings;

  # niri-config.kdl is real KDL, validated below; the placeholders keep user or
  # store paths out of the file itself.
  substituted = builtins.replaceStrings
    [ "@REGION_RECORD@" "@NIRI_INPUT_PORTAL@" ]
    [
      "${config.home.homeDirectory}/.local/bin/region-record"
      "${pkgs.niri-input-portal}/bin/niri-input-portal"
    ]
    (builtins.readFile ./niri-config.kdl);

  generated = pkgs.writeText "niri-noctalia-config.kdl" substituted;

  # The palette payload is a Noctalia template: it only becomes valid KDL once
  # the placeholder colors are substituted. Render it here the way the shell
  # does, from the wallpaper declared in the settings, so what gets validated is
  # a real rendering rather than the raw template. The colors are only a stand-in
  # for the ones the session finally picks: the point of the check is that every
  # placeholder resolves and the result parses as KDL. If one does not, the
  # engine writes nothing at all and the session silently keeps the stock
  # colors, with no error anywhere the user would look.
  palette = pkgs.runCommand "niri-noctalia-palette.kdl" {
    nativeBuildInputs = [ pkgs.noctalia ];
  } ''
    noctalia theme ${../../../assets/wallpaper-dark-cyrene.png} \
      --scheme ${settings.theme.wallpaper_scheme} \
      ${if settings.theme.mode == "light" then "--light" else "--dark"} \
      -r ${./niri-palette.kdl}:$out
  '';

  # Catch syntax errors at build time instead of at the next login. Everything is
  # staged in one scratch directory: a relative include resolves against the
  # directory of the path niri was handed (proven with symlink probes), which is
  # where both files sit at runtime, so the check exercises the real include
  # lines instead of a rewritten copy. A palette that fails to parse, or any
  # other KDL error, makes niri exit nonzero and fails the build.
  #
  # The staged noctalia.kdl is the rendered palette above, and its name has to
  # stay in sync with the output_path declared in default.nix. A missing optional
  # include only warns and still exits 0, so the warning is asserted away: with
  # both files staged, any "optional include not found" means the two names
  # drifted apart, and at runtime that would silently leave niri on stock colors.
  checked = pkgs.runCommand "niri-noctalia-config.kdl" { nativeBuildInputs = [ pkgs.niri ]; } ''
    mkdir check
    cp ${generated} check/config.kdl
    cp ${palette} check/noctalia.kdl
    touch check/host.kdl
    if ! niri validate -c "$(pwd)/check/config.kdl" > validate.log 2>&1; then
      cat validate.log >&2
      exit 1
    fi
    if grep -q "optional include not found" validate.log; then
      echo "error: an include stayed unresolved although every file was staged" >&2
      cat validate.log >&2
      exit 1
    fi
    cp ${generated} $out
  '';
in
{
  xdg.configFile = {
    "niri-noctalia/config.kdl".source = checked;

    # Included at the end of config.kdl, so hosts/<host>/desktop/<name>/ can
    # override the shared defaults. Hosts override `source` with lib.mkForce.
    "niri-noctalia/host.kdl".source = ./niri-host-default.kdl;
  };
}
