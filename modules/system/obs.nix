{ config, ... }:

{
  # OBS virtual camera (v4l2loopback): lets video-conferencing apps use the
  # OBS output as a camera device. Configured manually with the kernel options
  # recommended by the NixOS Wiki:
  # https://wiki.nixos.org/wiki/OBS_Studio#Using_the_Virtual_Camera
  #
  # Home Manager's programs.obs-studio has no enableVirtualCamera (kernel
  # modules belong to the system layer), so it is declared here.
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];
  # Not added to boot.kernelModules: NixOS would assert that keeping
  # v4l2loopback permanently loaded breaks Howdy face authentication (which
  # sudo relies on here). The module loads on demand instead: when OBS starts
  # the virtual camera, polkit authorizes modprobe v4l2loopback.
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
  '';

  # Accessing the v4l2loopback device requires polkit authorization.
  security.polkit.enable = true;
}
