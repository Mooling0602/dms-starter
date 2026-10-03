# User profile in specific host machine

These `${username}.nix` modules are imported by [home-manager](../../../modules/home/default.nix#L20) as `hosts/${hostname}/users/${username}.nix`.

`${username}` and `${hostname}` come from this host's identity: `hostname` is the `hosts/` directory name injected by `flake.nix`, and `username` is `my.username` set in [default.nix](../default.nix). When both match this file's name, the configuration is actually applied; otherwise the import is skipped with a warning.

Note that `${username}` and `${hostname}` here are the module arguments - not variables defined in `flake.nix`, which no longer carries any device identity.
