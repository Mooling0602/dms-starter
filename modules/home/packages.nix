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
    kdePackages.plasma-browser-integration

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
    lazygit
    gh
    seahorse

    btop
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

    # common apps
    kdePackages.dolphin
    kdePackages.dolphin-plugins
    kdePackages.kate
    kdePackages.discover
    kdePackages.systemsettings
    kdePackages.ark
    kdePackages.ksshaskpass
    grim
    slurp
    satty
    wl-clipboard
    qq
    wechat
    telegram-desktop
    discord
    element-desktop
    google-chrome
    bilibili
    haruna
    obs-studio
    axolotl-launcher-bin
    pebble-mail
    openfic
    claude-code
    codex
    pi
    dsh
    opencode
    opencode-desktop
    zed-editor
    reasonix
    reasonix-desktop
    qoder
    clawd-on-desk
    prismlauncher
    rclone
    zen-browser
  ];

  home.file.".local/share/jdks/jdk8".source = pkgs.jdk8;
}
