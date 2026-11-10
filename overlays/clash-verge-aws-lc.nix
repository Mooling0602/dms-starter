final: prev: {
  # The Rust build hook requires system AWS-LC, but the package omits it.
  clash-verge-rev = prev.clash-verge-rev.override {
    callPackage = path: args:
      let
        package = prev.callPackage path args;
      in
      if builtins.baseNameOf path == "unwrapped.nix" then
        package.overrideAttrs (old: {
          buildInputs = old.buildInputs ++ [ final.aws-lc ];
        })
      else
        package;
  };
}
