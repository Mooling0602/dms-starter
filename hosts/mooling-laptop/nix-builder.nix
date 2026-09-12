{ ... }:

{
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
}
