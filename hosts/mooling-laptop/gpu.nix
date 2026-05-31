{ config, lib, pkgs, ... }:

let
  edidPy = pkgs.writeText "gen-edid.py" ''
import struct, sys

def checksum(data):
    return (256 - sum(data) % 256) % 256

def write_dtd(edid, off, pc, ha, hb, hs, hf, va, vb, vs, vf, hsz, vsz):
    edid[off:off+2] = struct.pack("<H", pc)
    edid[off+2] = ha & 0xff
    edid[off+3] = hb & 0xff
    edid[off+4] = ((ha >> 4) & 0xf0) | ((hb >> 8) & 0x0f)
    edid[off+5] = va & 0xff
    edid[off+6] = vb & 0xff
    edid[off+7] = ((va >> 4) & 0xf0) | ((vb >> 8) & 0x0f)
    edid[off+8] = hs & 0xff
    edid[off+9] = hf & 0xff
    edid[off+10] = ((vs & 0x0f) << 4) | (vf & 0x0f)
    edid[off+11] = (hs >> 4) & 0xf0
    edid[off+12] = vs & 0xff
    edid[off+13] = ((hs >> 8) & 0x0f) | ((vs >> 4) & 0xf0)
    edid[off+14] = vf & 0xff
    edid[off+15] = vs >> 8
    edid[off+16] = hsz & 0xff
    edid[off+17] = vsz & 0xff
    edid[off+18] = 0
    edid[off+19] = 0
    edid[off+20] = 0x18

edid = bytearray(256)

# --- Base EDID Block (128 bytes) ---

# Header
edid[0:8] = b"\x00\xff\xff\xff\xff\xff\xff\x00"

# Manufacturer: NIX
edid[8] = 0x06
edid[9] = 0x10
edid[10:12] = struct.pack("<H", 0xd49c)
edid[12:16] = struct.pack("<I", 0)
edid[16] = 0
edid[17] = 0x1b

edid[18] = 1
edid[19] = 4
edid[20] = 0x80
edid[21] = 52
edid[22] = 29
edid[23] = 0x78
edid[24] = 0xea
edid[25:35] = bytes([0x25, 0xa9, 0x55, 0x4f, 0xa1, 0x26, 0x0c, 0x50, 0x54, 0x00])
edid[35:38] = b"\x00\x00\x00"
edid[38:54] = b"\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01"

# DTD 1: 2460x1080@60Hz (preferred)
write_dtd(edid, 54, 17701, 2460, 160, 32, 48, 1080, 46, 5, 3, 52, 29)

# DTD 2: 1920x1080@60Hz (fallback)
write_dtd(edid, 75, 14850, 1920, 280, 44, 88, 1080, 45, 5, 4, 52, 29)

# Descriptor 3: monitor name "VIRTUAL"
edid[96:114] = b"\x00\x00\x00\xfc\x00" + b"VIRTUAL\x0a\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20"

# Descriptor 4: range limits
edid[114:132] = b"\x00\x00\x00\xfd\x00\x1e\x4b\x1e\x53\x96\x00\x0a\x20\x20\x20\x20\x20"

edid[126] = 1  # one extension block
edid[127] = checksum(edid[0:127])

# --- CEA-861 Extension Block (128 bytes) ---
ext = edid[128:256]

ext[0] = 0x02  # CEA-861 tag
ext[1] = 3     # revision

# HDMI VSDB (OUI 00-0C-03) - required by NVIDIA for modes >1080p
ext[3] = (3 << 5) | 7   # tag=3 (VSDB), length=7
ext[4:7] = bytes([0x00, 0x0C, 0x03])  # HDMI 1.4 OUI
ext[7] = 0x10  # CEC physical address: 1.0.0.0
ext[8] = 0x00
# Flags: supports_ai=1, deep_color=48bit, DC_Y444=1, max_tmds_upper=0
# 300 MHz / 5 = 60 = 0x3c -> upper 3 bits = 0, lower 8 bits = 0x3c
ext[9] = 0xf0
ext[10] = 0x3c  # max TMDS = 300 MHz

# HDMI Forum VSDB (OUI C4-5D-D8) - HDMI 2.0 support
ext[11] = (3 << 5) | 4   # tag=3, length=4
ext[12:15] = bytes([0xC4, 0x5D, 0xD8])  # HDMI Forum OUI
ext[15] = 0x01  # version 1

ext[2] = 18  # DTD offset (2 padding + 16 data bytes = 18)
ext[16:18] = b"\x00\x00"  # padding

# No additional DTDs needed in extension block
ext[127] = checksum(ext[0:127])

sys.stdout.buffer.write(bytes(edid))
'';

  virtualDisplayEDID = pkgs.runCommand "virtual-display-edid" {
    nativeBuildInputs = [ pkgs.python3 ];
  } ''
    mkdir -p $out/lib/firmware/edid
    python3 ${edidPy} > $out/lib/firmware/edid/virtual-display.bin
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
    "drm.edid_firmware=HDMI-A-1:edid/virtual-display.bin"
  ];

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };

    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
}
