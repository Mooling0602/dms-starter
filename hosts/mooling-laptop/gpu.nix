{ config, lib, pkgs, ... }:

let
  virtualDisplayEDID = pkgs.runCommand "virtual-display-edid.bin" {
    nativeBuildInputs = [ pkgs.python3 ];
  } ''
    python3 -c '
import struct, sys

def checksum(data):
    return (256 - sum(data) % 256) % 256

edid = bytearray(128)

# Header
edid[0:8] = b"\x00\xff\xff\xff\xff\xff\xff\x00"

# Manufacturer: NIX
edid[8] = 0x06
edid[9] = 0x10
# Product code
edid[10:12] = struct.pack("<H", 0xd49c)
# Serial
edid[12:16] = struct.pack("<I", 0)

# Manufacture date
edid[16] = 0  # week
edid[17] = 0x1b  # year (2021 - 1990 = 27 = 0x1b)

# EDID version 1.4
edid[18] = 1
edid[19] = 4

# Digital input
edid[20] = 0x80

# Screen size (52cm x 29cm ~ 23.6 inch)
edid[21] = 52  # horizontal cm
edid[22] = 29  # vertical cm

# Gamma
edid[23] = 0x78  # 2.2

# Features (DPMS standby, suspend, active-off; sRGB; preferred timing)
edid[24] = 0xea

# Chromaticity
edid[25:35] = bytes([0x25, 0xa9, 0x55, 0x4f, 0xa1, 0x26, 0x0c, 0x50, 0x54, 0x00])

# Established timings (none)
edid[35:38] = b"\x00\x00\x00"

# Standard timings (none)
edid[38:54] = b"\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01"

# Detailed timing descriptor 1: 1920x1080@60Hz
# Pixel clock = 148.5 MHz = 148500000 / 10000 = 14850 (0x3a02)
pixel_clock = 14850
edid[54:56] = struct.pack("<H", pixel_clock)

h_active = 1920
h_blank = 280
h_sync = 44
h_front = 88
h_total = h_active + h_blank

v_active = 1080
v_blank = 45
v_sync = 5
v_front = 4
v_total = v_active + v_blank

edid[56] = h_active & 0xff           # h_active low
edid[57] = h_blank & 0xff            # h_blank low
edid[58] = ((h_active >> 4) & 0xf0) | ((h_blank >> 8) & 0x0f)

edid[59] = v_active & 0xff           # v_active low
edid[60] = v_blank & 0xff            # v_blank low
edid[61] = ((v_active >> 4) & 0xf0) | ((v_blank >> 8) & 0x0f)

edid[62] = h_sync & 0xff             # h_sync low
edid[63] = h_front & 0xff            # h_front low
edid[64] = ((v_sync & 0x0f) << 4) | (v_front & 0x0f)

edid[65] = (h_sync >> 4) & 0xf0      # h_sync high
edid[66] = v_sync & 0xff             # v_sync low
edid[67] = ((h_sync >> 8) & 0x0f) | ((v_sync >> 4) & 0xf0)
edid[68] = v_front & 0xff            # v_front low
edid[69] = v_sync >> 8               # v_sync high

# Horizontal image size 52cm, vertical 29cm (same as screen size)
edid[70] = 52
edid[71] = 29

edid[72] = 0  # no border
edid[73] = 0  # no border

# Flags: digital, not interlaced
edid[74] = 0x18  # stereo=0, digital sync, vsync+, hsync+, not stereo, not interlaced

# Descriptor 2: Dummy
edid[75:93] = bytes(18)

# Descriptor 3: Monitor name "VIRTUAL"
name = "VIRTUAL\x0a\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20"
edid[93] = 0x00
edid[94] = 0x00
edid[95] = 0x00
edid[96] = 0xfc
edid[97] = 0x00
edid[98:111] = name.encode("ascii")

# Descriptor 4: Monitor range limits
edid[111] = 0x00
edid[112] = 0x00
edid[113] = 0x00
edid[114] = 0xfd
edid[115] = 0x00
edid[116] = 30   # min vert rate
edid[117] = 75   # max vert rate
edid[118] = 30   # min horiz rate
edid[119] = 83   # max horiz rate
edid[120] = 150  # max pixel clock in 10MHz
edid[121:126] = bytes(5)  # padding

# No extension blocks
edid[126] = 0

# Checksum
edid[127] = checksum(edid[0:127])

sys.stdout.buffer.write(bytes(edid))
' > $out
  '';
in
{
  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
  ];

  hardware.firmware = [ virtualDisplayEDID ];

  boot.kernelParams = [
    "video=HDMI-A-1:e"
    "drm.edid_firmware=HDMI-A-1:edid/${virtualDisplayEDID.name}"
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
