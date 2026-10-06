{ lib, pkgs, ... }:

# Home-manager module, has been imported by default.

{
  home.packages = with pkgs; [
    python3

    zellij
    fastfetch
    yazi

    # archives
    zip
    xz
    unzip
    p7zip

    # utils
    ripgrep
    jq
    yq-go
    fzf
    ty
    ruff

    # networking tools
    mtr
    iperf3
    dnsutils
    ldns
    aria2
    socat
    nmap
    miniupnpc
    ipcalc

    # dev tools
    android-tools
    (lib.lowPrio jdk8)
    jdk25
    gcc
    nodejs
    bun
    pnpm

    # misc
    file
    which
    tree
    gnutar
    zstd

    nix-output-monitor
    (writeShellApplication {
      name = "nixos-rebuild-nom";
      runtimeInputs = [ nix-output-monitor ];
      text = ''
        sudo nixos-rebuild "$@" |& nom
      '';
    })

    # productivity
    hugo
    glow
    seahorse

    iotop
    iftop

    # system call monitoring
    strace
    # ltrace 0.7.91's demangle test trips -Wvolatile under GCC 16, and the test
    # framework treats any compiler output as a build failure; see
    # MAINTENANCE.md.
    (ltrace.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        sed -i 's/^volatile int Fv_Vi/int Fv_Vi/' testsuite/ltrace.minor/demangle-lib.cpp
        sed -i 's/^extern volatile int Fv_Vi/extern int Fv_Vi/' testsuite/ltrace.minor/demangle.cpp
      '';
    }))
    lsof

    # system tools
    pulseaudio
    sysstat
    lm_sensors
    ethtool
    pciutils
    usbutils
    libinput
    xrdb

    gpu-screen-recorder
    wl-clipboard
  ];

  home.file.".local/share/jdks/jdk8".source = pkgs.jdk8;
}
