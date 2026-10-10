{
  description = "NixOS configuration for DankMaterialShell desktop";

  inputs = {
    # Use zstd tarball, see more in NixOS/nixpkgs#535272
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dgop = {
      url = "github:AvengeMedia/dgop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvcfg = {
      url = "github:Mooling0602/NvCfg";
      flake = false;
    };
    nix4nvchad = {
      url = "github:nix-community/nix4nvchad";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nvchad-starter.follows = "nvcfg";
    };
    nix-packages = {
      url = "github:Mooling0602/nix-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
    };
    dw-proton = {
      url = "github:imaviso/dwproton-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    danksearch = {
      url = "github:AvengeMedia/danksearch";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dankcalendar = {
      url = "github:AvengeMedia/dankcalendar";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ChatGPT Community (codex-desktop): community repack of the official
    # Linux .deb, integrated through homeManagerModules.
    codex-desktop = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # QQ Wayland fixes: screen sharing, screenshots and clipboard.
    linuxqq-wayland-fix = {
      url = "github:SHORiN-KiWATA/linuxqq-wayland-fix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      ...
    }:
    let
      # Enumerate only directories under hosts/: the directory name is the
      # hostname, and device identity lives in each hosts/<host>/default.nix.
      # Adding a device means adding a directory, not editing this file.
      entries = builtins.readDir ./hosts;
      hostNames = builtins.filter (
        name: entries.${name} == "directory" && builtins.pathExists ./hosts/${name}/default.nix
      ) (builtins.attrNames entries);
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs hostNames (hostname: nixpkgs.lib.nixosSystem {
        # Inject the directory name; hosts/<host>/default.nix uses it as
        # my.hostname. inputs is injected too, so system modules and
        # modules/core.nix can reach any input without extra wiring here.
        specialArgs = { inherit hostname inputs; };
        modules = [
          ./hosts/${hostname}
          home-manager.nixosModules.home-manager
          # Shared wiring (overlays + Home Manager bridge).
          ./modules/core.nix
        ];
      });
    };
}
