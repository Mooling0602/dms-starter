{ ... }:

{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    extra-substituters = [
      "https://cache.numtide.com"
      "https://ezkea.cachix.org"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI="
    ];
    trusted-users = [ "root" "mooling" ];
    builders-use-substitutes = true;
  };

  nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      hostName = "127.0.0.1:31022";
      protocol = "ssh-ng";
      system = "aarch64-linux";
      sshUser = "builder";
      sshKey = "/home/mooling/.ssh/id_ed25519";
      maxJobs = 4;
      speedFactor = 2;
      supportedFeatures = [ "big-parallel" ];
      publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUpCV2N4Yi9CbGFxdDFhdU90RStGOFFVV3JVb3RpQzVxQkorVXVFV2RWQ2Igcm9vdEBuaXhvcwo=";
    }
  ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 1d";
  };

  programs.nix-ld.enable = true;
}
