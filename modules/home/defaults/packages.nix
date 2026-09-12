{ lib, pkgs, ... }:

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

    # KDE connect
    kdePackages.kdeconnect-kde

    # virtual display mode utility
    wlr-randr

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
    ltrace
    lsof

    # system tools
    pulseaudio
    sysstat
    lm_sensors
    ethtool
    pciutils
    usbutils

    xwayland-satellite
    xrdb

    gpu-screen-recorder
    wl-clipboard
    grim
    slurp
    satty
  ];

  home.file.".local/share/jdks/jdk8".source = pkgs.jdk8;
}
