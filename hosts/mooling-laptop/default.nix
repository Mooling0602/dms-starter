{ config, pkgs, hostname, ... }:

let
  # 本机使用的桌面模块名，对应 ./desktop/<desktop>/。
  # 必须是 let 绑定：imports 求值早于 config，写成 config.my.desktop 会无限递归。
  desktop = "dms-with-niri";
in

{
  # ── 设备身份（本机唯一改动点）────────────────────────────────
  # flake.nix 只枚举主机目录并注入目录名；用户名与主机名在这里声明，
  # 其他设备改自己的 hosts/<host>/default.nix，不会再和本机冲突。
  my.username = "mooling";
  my.hostname = hostname;
  my.desktop = desktop;
  # ───────────────────────────────────────────────────────────

  imports = [
    ./hardware-configuration.nix
    ./gpu.nix
    # ./nix-builder.nix
    ./clash-verge-fix.nix
    ../../modules/optional/howdy.nix
    ../../modules/optional/obs.nix
    ../../modules/optional/gaming.nix
    ../../modules/optional/wine.nix
    ../../modules/system/config.nix
    ../../modules/system/i18n.nix
    ../../modules/system/fonts.nix
    ../../modules/system/networking.nix
    ../../modules/system/keyring.nix
    ../../modules/system/nix.nix
    ../../modules/system/packages.nix
    ../../modules/system/services.nix
    ../../modules/system/users.nix
    ../../modules/system/virtualisation.nix
    ../../modules/system/obs.nix
    ./desktop/${desktop}/default.nix
    # 切换桌面：只改上面 let 里的 desktop，同时把 <host>/desktop/<新桌面>/ 准备好。
  ];

  boot.loader = {
    efi.canTouchEfiVariables = true;
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 10;
  };

  # Emulate aarch64 via qemu-user + binfmt so Nix can build with
  # buildPlatform = aarch64 (native hash) and pull prebuilt aarch64
  # binaries from cache.nixos.org instead of locally cross-compiling.
  boot.binfmt = {
    emulatedSystems = [ "aarch64-linux" ];
    # Keep binfmt available for executing foreign binaries, while directing
    # aarch64 derivations to the native remote builder.
    addEmulatedSystemsToNixSandbox = false;
  };

  # Route nix derivation build temp dirs to /data (root / has limited space;
  # the sandbox /build is backed by build-dir on the host, which replaces
  # setting TMPDIR in the nix-daemon systemd unit). It must not sit under a
  # world-writable path, so /data is 755 and build dir is /data/nixbuild.
  nix.settings.build-dir = "/data/nixbuild";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Firebat T5K uses the Clevo keyboard protocol supported by tuxedo-drivers.
  hardware.tuxedo-drivers.enable = true;
  boot.kernelModules = [ "tuxedo_keyboard" "clevo_acpi" ];

  boot.resumeDevice = "/dev/disk/by-uuid/c531a6ba-9945-42f0-821b-9a0553fe100d";

  networking.hostName = config.my.hostname;

  services.howdy.settings.video.device_path =
    "/dev/v4l/by-id/usb-Sonix_Technology_Co.__Ltd._BisonCam_NB_Pro-video-index0";

  system.stateVersion = "25.11";
}
