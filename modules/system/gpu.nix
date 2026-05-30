{ config, lib, pkgs, ... }:

{
  hardware.graphics.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # 使用闭源驱动（非开源内核模块）
    open = false;
    modesetting.enable = true;
    powerManagement.enable = true;

    # Prime offload (Intel + NVIDIA 双显卡)
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };

    # 使用 latest 驱动
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
}
