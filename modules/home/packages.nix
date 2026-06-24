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
    jdk25
    gcc
    nodejs

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

    # common apps
    kdePackages.dolphin
    kdePackages.dolphin-plugins
    kdePackages.kate
    kdePackages.discover
    kdePackages.systemsettings
    kdePackages.ark
    qq
    wechat
    telegram-desktop
    element-desktop
    google-chrome
    bilibili
    claude-code
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
    flclash
  ];
}
