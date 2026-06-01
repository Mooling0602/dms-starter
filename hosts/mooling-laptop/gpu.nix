{ config, lib, pkgs, ... }:

let
  # 生成自定义 EDID（256 字节），支持高分辨率/刷新率
  # 关键：必须有 HDMI VSDB（OUI 00-0C-03）才能突破 165MHz 像素时钟限制
  edidBin = pkgs.runCommand "virtual-display-edid" {
    nativeBuildInputs = [ pkgs.python3 ];
  } ''
    mkdir -p $out/lib/firmware/edid
    python3 -c '
import struct, sys

def checksum(data):
    return (256 - sum(data) % 256) % 256

# Build EDID byte by byte (256 = 128 base + 128 CEA ext)
edid = bytearray(256)

# --- Header (8 bytes) ---
edid[0:8]  = bytes([0x00,0xff,0xff,0xff,0xff,0xff,0xff,0x00])

# --- Manufacturer ID "NIX" (2 bytes) ---
edid[8]  = 0x06
edid[9]  = 0x10

# --- Product code + serial (6 bytes) ---
struct.pack_into("<H", edid, 10, 0xd49c)
struct.pack_into("<I", edid, 12, 0x00000000)

# --- Manufacture date (2 bytes) ---
edid[16] = 0     # week
edid[17] = 0x1b  # year = 2021

# --- EDID version 1.4 (2 bytes) ---
edid[18] = 1
edid[19] = 4

# --- Basic display params (5 bytes) ---
edid[20] = 0x80  # digital input
edid[21] = 52    # width cm
edid[22] = 33    # height cm
edid[23] = 0x78  # gamma 2.2
edid[24] = 0xea  # DPMS standby/suspend, sRGB, preferred timing

# --- Chromaticity (10 bytes) ---
edid[25:35] = bytes([0x25,0xa9,0x55,0x4f,0xa1,0x26,0x0c,0x50,0x54,0x00])

# --- Established timings (3 bytes) ---
edid[35:38] = bytes([0x00,0x00,0x00])

# --- Standard timings (16 bytes, all unused) ---
for i in range(38, 54):
    edid[i] = 0x01

# --- DTD helper: write 18-byte detailed timing descriptor ---
def dtd(off, pc, ha, hb, hs, hf, va, vb, vs, vf, hsz, vsz):
    struct.pack_into("<H", edid, off, pc)
    edid[off+2]  = ha & 0xff
    edid[off+3]  = hb & 0xff
    edid[off+4]  = ((ha >> 4) & 0xf0) | ((hb >> 8) & 0x0f)
    edid[off+5]  = va & 0xff
    edid[off+6]  = vb & 0xff
    edid[off+7]  = ((va >> 4) & 0xf0) | ((vb >> 8) & 0x0f)
    edid[off+8]  = hf & 0xff
    edid[off+9]  = hs & 0xff
    edid[off+10] = ((vf & 0x0f) << 4) | (vs & 0x0f)
    edid[off+11] = ((hf >> 4) & 0xf0) | ((hs >> 8) & 0x0f)
    edid[off+12] = vf & 0xff
    edid[off+13] = ((hf >> 8) & 0x0f) | ((vf >> 4) & 0xf0)
    edid[off+14] = vs & 0xff
    edid[off+15] = vf >> 8
    edid[off+16] = hsz
    edid[off+17] = vsz

# DTD 1: 2560x1600@120Hz (at offset 54)
dtd(54, 55240, 2560, 160, 32, 48, 1600, 45, 6, 3, 52, 33)
# DTD 2: 2460x1080@60Hz (at offset 72)
dtd(72, 17701, 2460, 160, 32, 48, 1080, 46, 5, 3, 52, 33)

# --- Descriptor 3: Monitor name "VIRTUAL" (18 bytes at offset 90) ---
edid[90]  = 0x00
edid[91]  = 0x00
edid[92]  = 0x00
edid[93]  = 0xfc # monitor name tag
edid[94]  = 0x00
name = "VIRTUAL\x0a"
for j, ch in enumerate(name.encode()):
    edid[95+j] = ch
for j in range(len(name), 13):
    edid[95+j] = 0x20

# --- Descriptor 4: Range limits (18 bytes at offset 108) ---
edid[108] = 0x00
edid[109] = 0x00
edid[110] = 0x00
edid[111] = 0xfd # range limits tag
edid[112] = 0x00
edid[113] = 0x1e # min vertical 30 Hz
edid[114] = 0x8f # max vertical 143 Hz
edid[115] = 0x1e # min horizontal 30 kHz
edid[116] = 0xff # max horizontal 255 kHz
edid[117] = 0x96 # max pixel clock = 1500 MHz
edid[118] = 0x00
edid[119] = 0x0a
for i in range(120, 126):
    edid[i] = 0x20

# --- Extension count + checksum ---
edid[126] = 1  # one extension block
edid[127] = checksum(edid[0:127])

# ========== CEA-861 Extension Block (bytes 128-255) ==========

ext = 128  # start offset
edid[ext+0] = 0x02  # CEA-861 tag
edid[ext+1] = 0x03  # revision 3
edid[ext+2] = 0x14  # DTD offset (= total data block bytes, here 20)

# --- HDMI VSDB (OUI 00-0C-03): 8 bytes ---
edid[ext+3]  = (3 << 5) | 7  # tag=3(VSDB), length=7
edid[ext+4]  = 0x00  # OUI byte 0
edid[ext+5]  = 0x0C  # OUI byte 1
edid[ext+6]  = 0x03  # OUI byte 2
edid[ext+7]  = 0x10  # CEC physical address 1.0.0.0
edid[ext+8]  = 0x00  # CEC address continued
edid[ext+9]  = 0xf0  # flags: AI=1, DC_48bit, DC_Y444=1
edid[ext+10] = 0x78  # max TMDS = 120*5 = 600 MHz

# --- HDMI Forum VSDB (OUI C4-5D-D8): 9 bytes ---
edid[ext+11] = (3 << 5) | 6  # tag=3, length=6
edid[ext+12] = 0xC4
edid[ext+13] = 0x5D
edid[ext+14] = 0xD8
edid[ext+15] = 0x01  # version 1
edid[ext+16] = 0x00  # max TMDS char rate (0=unspecified)
edid[ext+17] = 0x00  # SCDC=0, RR=0, LTE_340=0

# --- Padding to DTD offset (2 bytes) ---
edid[ext+18] = 0x00
edid[ext+19] = 0x00

# DTD: 2460x1080@144Hz at offset 20 in ext
dtd(ext+20, 51490, 2460, 160, 32, 48, 1080, 46, 6, 3, 52, 33)
# DTD: 1920x1080@60Hz at offset 38 in ext
dtd(ext+38, 14850, 1920, 280, 44, 88, 1080, 45, 5, 4, 52, 33)

# --- Pad + checksum ---
for i in range(62, 127):
    edid[ext+i] = 0
edid[ext+127] = checksum(edid[ext:ext+127])

# --- Verify and output ---
assert len(edid) == 256, f"Expected 256, got {len(edid)}"
sys.stdout.buffer.write(bytes(edid))
' > $out/lib/firmware/edid/virtual-display.bin
    test $(wc -c < $out/lib/firmware/edid/virtual-display.bin) -eq 256 || { echo "EDID wrong size: $(wc -c < $out)"; exit 1; }
  '';
in
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
    ];
  };

  boot.kernelParams = [
    "video=HDMI-A-1:2560x1600MR@120e"
    "drm.edid_firmware=HDMI-A-1:edid/virtual-display.bin"
  ];

  hardware.firmware = [ edidBin ];

  # Symlink EDID firmware to kernel firmware path (required by drm.edid_firmware)
  systemd.tmpfiles.rules = [
    "L+ /lib/firmware/edid/virtual-display.bin - - - - ${edidBin}/lib/firmware/edid/virtual-display.bin"
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
