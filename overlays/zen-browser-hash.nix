{ inputs }:

final: prev:

let
  system = final.stdenv.hostPlatform.system;
  upstream = inputs.zen-browser.packages.${system};

  # Zen 1.23.3b release assets were re-uploaded upstream after
  # zen-browser-flake's auto-update had already recorded the old hashes. Its
  # update script compares the release tag against sources.json and therefore
  # never refreshes them for an unchanged tag. Both hashes were recomputed
  # from the URLs listed in that sources.json. See MAINTENANCE.md.
  hashes = {
    x86_64-linux = "sha256-uyBF0+IWVNQP6EElAJLurf0sH8gx7vtQkiJ3PIvcoUk=";
    aarch64-linux = "sha256-EQDLPoVyVO26gzopPrUAEN5moWZGXt/NzIU23ecy36c=";
  };
in
{
  zen-browser = upstream.default.override {
    zen-browser-unwrapped = upstream.zen-browser-unwrapped.override {
      hash = hashes.${system};
    };
  };
}
