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
    # ltrace 0.7.91 的 demangle 测试在 GCC 16 下触发 -Wvolatile，而测试框架
    # 把任何编译器输出都当作编译失败；见 MAINTENANCE.md。
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
