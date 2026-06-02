{ pkgs, ... }:

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

    # networking tools
    mtr
    iperf3
    dnsutils
    ldns
    aria2
    socat
    nmap
    ipcalc

    # dev tools
    gcc

    # KDE Connect
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
    sysstat
    lm_sensors
    ethtool
    pciutils
    usbutils

    xwayland-satellite

    # common apps
    kdePackages.dolphin
    kdePackages.dolphin-plugins
    kdePackages.kate
    qq
    wechat
    telegram-desktop
    element-desktop
    google-chrome
    bilibili
    claude-code
    opencode
    zed-editor
    reasonix
    reasonix-go
  ];
}
