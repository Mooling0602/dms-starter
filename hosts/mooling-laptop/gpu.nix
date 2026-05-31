{ config, lib, pkgs, ... }:

let
  virtualDisplayEDID = pkgs.runCommand "virtual-display-edid" {
    nativeBuildInputs = [ pkgs.python3 ];
  } ''
    mkdir -p $out/lib/firmware/edid
    python3 -c '
import struct, sys

def checksum(data):
    return (256 - sum(data) % 256) % 256

edid = bytearray(128)

# Header
edid[0:8] = b"\x00\xff\xff\xff\xff\xff\xff\x00"

# Manufacturer: NIX
edid[8:10] = b"\x06\x10"
# Product code
edid[10:12] = struct.pack("<H", 0xd49c)
# Serial
edid[12:16] = struct.pack("<I", 0)

# Manufacture date
edid[16] = 0  # week
edid[17] = 0x1b  # year

# EDID version 1.4
edid[18] = 1
edid[19] = 4

# Digital input
edid[20] = 0x80

# Screen size (52cm x 29cm)
edid[21] = 52
edid[22] = 29

# Gamma 2.2
edid[23] = 0x78

# Features
edid[24] = 0xea

# Chromaticity
edid[25:35] = bytes([0x25, 0xa9, 0x55, 0x4f, 0xa1, 0x26, 0x0c, 0x50, 0x54, 0x00])

# Established timings (none)
edid[35:38] = b"\x00\x00\x00"

# Standard timings (none)
edid[38:54] = b"\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01"

# --- 2460x1080@60Hz (Redmi Note 11T Pro) detailed timing ---
h_active, v_active = 2460, 1080
h_blank, v_blank = 160, 46
h_sync, v_sync = 32, 5
h_front, v_front = 48, 3
pixel_clock = 17701  # 177.01 MHz in 10kHz units

edid[54:56] = struct.pack("<H", pixel_clock)
edid[56] = h_active & 0xff
edid[57] = h_blank & 0xff
edid[58] = ((h_active >> 4) & 0xf0) | ((h_blank >> 8) & 0x0f)
edid[59] = v_active & 0xff
edid[60] = v_blank & 0xff
edid[61] = ((v_active >> 4) & 0xf0) | ((v_blank >> 8) & 0x0f)
edid[62] = h_sync & 0xff
edid[63] = h_front & 0xff
edid[64] = ((v_sync & 0x0f) << 4) | (v_front & 0x0f)
edid[65] = (h_sync >> 4) & 0xf0
edid[66] = v_sync & 0xff
edid[67] = ((h_sync >> 8) & 0x0f) | ((v_sync >> 4) & 0xf0)
edid[68] = v_front & 0xff
edid[69] = v_sync >> 8

edid[70] = 52  # h_size_mm
edid[71] = 29  # v_size_mm
edid[72] = 0   # h_border
edid[73] = 0   # v_border

edid[74] = 0x18  # digital, vsync+, hsync+

# Descriptor 2: dummy
edid[75:93] = bytes(18)

# Descriptor 3: monitor name "VIRTUAL"
edid[93:111] = b"\x00\x00\x00\xfc\x00" + b"VIRTUAL\x0a\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20"

# Descriptor 4: range limits (30-75 Hz vertical, 30-83 kHz horizontal, 150 MHz max)
edid[111:128] = b"\x00\x00\x00\xfd\x00\x1e\x4b\x1e\x53\x96\x00\x0a\x20\x20\x20\x20\x20"

# No extensions
edid[126] = 0
edid[127] = checksum(edid[0:127])

sys.stdout.buffer.write(bytes(edid))
' > $out/lib/firmware/edid/virtual-display.bin
  '';
in
{
  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
  ];

  hardware.firmware = [ virtualDisplayEDID ];

  # Symlink EDID firmware to kernel firmware path (required by drm.edid_firmware)
  systemd.tmpfiles.rules = [
    "L+ /lib/firmware/edid/virtual-display.bin - - - - ${virtualDisplayEDID}/lib/firmware/edid/virtual-display.bin"
  ];

  boot.kernelParams = [
    "video=HDMI-A-1:e"
    "drm.edid_firmware=HDMI-A-1:edid/virtual-display.bin"
  ];

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = true;
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
