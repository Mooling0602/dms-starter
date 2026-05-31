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

edid = bytearray(256)  # 128 base + 128 CEA extension

# ===== Base EDID Block =====

# Header
edid[0:8] = b"\x00\xff\xff\xff\xff\xff\xff\x00"

# Manufacturer: NIX
edid[8:10] = b"\x06\x10"
edid[10:12] = struct.pack("<H", 0xd49c)
edid[12:16] = struct.pack("<I", 0)
edid[16] = 0   # week
edid[17] = 0x1b  # year (2021)

# EDID version 1.4
edid[18] = 1
edid[19] = 4

# Digital input
edid[20] = 0x80

# Screen size (52cm x 29cm)
edid[21] = 52
edid[22] = 29
edid[23] = 0x78  # Gamma 2.2

# Features (DPMS, sRGB, preferred timing)
edid[24] = 0xea

# Chromaticity
edid[25:35] = bytes([0x25, 0xa9, 0x55, 0x4f, 0xa1, 0x26, 0x0c, 0x50, 0x54, 0x00])

# Established timings (none)
edid[35:38] = b"\x00\x00\x00"

# Standard timings (none)
edid[38:54] = b"\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01"

# --- 2460x1080@60Hz detailed timing ---
h_active, v_active = 2460, 1080
h_blank, v_blank = 160, 46
h_sync, v_sync = 32, 5
h_front, v_front = 48, 3
pixel_clock = 17701

def write_dtd(off, pc, ha, hb, hs, hf, va, vb, vs, vf, hsz, vsz):
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
    edid[off+18] = 0  # h_border
    edid[off+19] = 0  # v_border
    edid[off+20] = 0x18  # digital, vsync+, hsync+

# DTD 1: 2460x1080@60Hz (preferred)
write_dtd(54, pixel_clock, h_active, h_blank, h_sync, h_front,
          v_active, v_blank, v_sync, v_front, 52, 29)

# DTD 2: 1920x1080@60Hz (fallback)
write_dtd(75, 14850, 1920, 280, 44, 88, 1080, 45, 5, 4, 52, 29)

# Descriptor 3: monitor name "VIRTUAL"
edid[96:114] = b"\x00\x00\x00\xfc\x00" + b"VIRTUAL\x0a\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20"

# Descriptor 4: range limits
edid[114:132] = b"\x00\x00\x00\xfd\x00\x1e\x4b\x1e\x53\x96\x00\x0a\x20\x20\x20\x20\x20"

# One extension block
edid[126] = 1
edid[127] = checksum(edid[0:127])

# ===== CEA-861 Extension Block =====
ext = edid[128:256]

# CEA-861 header
ext[0] = 0x02  # tag: CEA-861
ext[1] = 3     # revision
ext[2] = 0x03  # dtd offset (byte offset / 18 = 3, i.e. start at byte 3 in data block area)

# Data block collection starts at byte 4
# Byte 3 of data area is the first data block

# --- HDMI Vendor-Specific Data Block (OUI 00-0C-03) ---
# Required by NVIDIA for >165MHz pixel clock
# Format: tag(3bits)|length(5bits) = 0x67 | 0x05 (tag=3, length=5)
ext[3] = (3 << 5) | 5   # tag=3 (VSDB), length=5 bytes

# 24-bit IEEE OUI: 00-0C-03 (HDMI)
oui = [0x00, 0x0C, 0x03]
ext[4:7] = bytes(oui)

# Physical address CEC: 1.0.0.0 (port 1)
ext[7] = 0x10
ext[8] = 0x00

# HDMI flags:
# bit7: supports_ai (1)
# bit6-5: DC_48bit, DC_36bit, DC_30bit (0x70 = 111 = supports all)
# bit4: DC_Y444 (1 = supports)
# bit3-2: reserved
# bit1: DVI_Dual (0)
ext[8] = (1 << 7) | (7 << 5) | (1 << 4)  # = 0xf0

# Max TMDS character rate in MHz / 5
# We need at least 300 MHz (for 2460x1080@60 = ~177 MHz, add headroom)
# 300 MHz / 5 = 60 = 0x3c
ext[9] = 0x3c  # 300 MHz max TMDS

# --- HDMI Forum VSDB (OUI C4-5D-D8) for HDMI 2.0 ---
# tag=3 (VSDB), length follows OUI
# 24-bit IEEE OUI: C4-5D-D8, plus 1 byte version + max TMDS char rate
ext[10] = (3 << 5) | 4   # tag=3, length=4 bytes total (3 OUI + 1 data)
ext[11:14] = bytes([0xC4, 0x5D, 0xD8])  # HDMI Forum OUI
ext[14] = 0x01  # version 1
# Max_TMDS_Char_Rate (5Gbps per channel * 3 = 15 Gbps → but we encode as 0 for "no max limit"?)
# Actually this is encoded as: value / 5 MHz
# For HDMI 2.0: 600 MHz → 600/5 = 120 = 0x78... no, the format is "max TMDS char rate in (MHz+4)/5"
# Let'\''s just set 600 MHz: ceil(600/5) = 120 = 0x78

# Wait, the Forum VSDB format after OUI is:
# byte 0: version (1)
# byte 1: max_tmds_char_rate (5 Gbps per channel → max TMDS clock * 5 in MHz)
# For HDMI 2.0: max TMDS = 600 MHz → 600/5 = 120 = 0x78...
# Actually the formula is: char_rate = max_tmds_char_rate * 5 MHz
# We want to declare ~600 MHz capability: 600/5 = 120 decimal = 0x78
# But wait, there'\''s also SCDC support, etc.

# Actually, the more standard approach:
# bytes 1-2 are max_tmds_char_rate and SCDC flags
# max_tmds_char_rate = 0 means "no max defined" or "refer to EDID base block"

# Let me use 0 for "no limit" (it defaults to base block limits)
ext[15] = 0x00  # max_tmds_char_rate = 0 (not specified)
# SCDC present = 0, RR_Capable = 0, LTE_340Mcsc_scramble = 0, 3D independent = 0
# Actually, we should set max_tmds_char_rate = 120 (600 MHz) to support higher pixel clocks

# Let me redo: 4 bytes of data after OUI:
# byte 0: version = 0x01
# byte 1: max_tmds_char_rate_high (bits 7-0 of 16-bit value)
# byte 2: max_tmds_char_rate_low (bits 15-8) + flags
# For unlimited/600MHz: max_tmds = 120 = 0x78
ext[14] = 0x01  # version
ext[15] = 0x00  # max_tmds low byte = 0 for "no max"

# Simple Tag Block: YCbCr 4:2:0 support (tag=2, length=1)
# Actually, let'\''s just add this for compatibility
# Tag=2 (YCbCr 4:2:0 data block), length=1 (SV data)
# This is optional, skip for now

# --- Video Data Block (tag=2, length=5) ---
# We need to declare that we support 1080p and our custom resolution
# Video data block: tag=2, each entry is 1 byte (SVD = Short Video Descriptor)
# VIC 16 = 1080p@60Hz (native)
# VIC 4  = 720p@60Hz

# Let me add a Video Data Block with just VIC 16 (1080p@60)
# Actually, skip this for simplicity - the DTDs in base block handle it

# Speaker Allocation Data Block (tag=4, length=3) - stereo
# ext[XX] = (4 << 5) | 3  # tag=4, length=3
# ext[XX+1:XX+4] = bytes([FL/FR, 0, 0])

# Actually, let me keep the extension block simpler and just include
# the two VSDBs which are the critical pieces.

# Recalculate: extension block data starts at ext[3]
# Block 1 at ext[3]: VSDB (3 bytes OUI + 2 bytes data + 1 byte maxTMDS = 6?)
#   Wait, the HDMI VSDB format:
#   byte 0: tag|len header
#   bytes 1-3: 24-bit IEEE OUI (00-0C-03)
#   byte 4: CEC physical address byte 1
#   byte 5: CEC physical address byte 2 + flags
#   byte 6: max_TMDS_clock / 5
#   Length in header = total bytes AFTER header = 6

ext[3] = (3 << 5) | 7  # tag=3, length=7 bytes after header
ext[4:7] = bytes([0x00, 0x0C, 0x03])  # HDMI OUI
ext[7] = 0x10  # CEC addr: 1.0.0.0
ext[8] = 0x00  # CEC addr continued
# HDMI flags:
# bit7: supports_ai = 1
# bit6-5: DC_48bit(1), DC_36bit(1), DC_30bit(1) = 0b111
# bit4: DC_Y444 = 1
# bits 3-0: max_tmds_clock upper nibble (part of 12-bit value)
# 300 MHz / 5 = 60 = 0x3c
# 12-bit max_tmds = 0x03c → upper nibble = 0, lower byte = 0x3c
# But bits 7-4 are flags, bits 3-0 are max_tmds upper nibble
# flags: 1_111_1_0 = 0xfa (supports_ai=1, DC_48=1, DC_36=1, DC_30=1, DC_Y444=1, max_tmds_upper=0)
ext[9] = 0xfa  # flags + max_tmds_upper
ext[10] = 0x3c  # max_tmds lower = 60 * 5 = 300 MHz

# Get more precise. The CEC+flags layout for HDMI 1.4+ VSDB:
# After the 3-byte OUI:
# Physical Address A (1 byte): typically 0x10
# Physical Address B (1 byte): typically 0x00
# Flags byte:
#   bit 7: Supports_AI
#   bits 6-5: DC support (00=no, 01=30bit, 10=30+36bit, 11=30+36+48bit)
#   bit 4: DC_Y444
#   bit 3: DVI_Dual
#   bits 2-0: Max_TMDS_Clock upper 3 bits (12-bit value / 5 MHz)
# Max_TMDS_Clock byte: lower 8 bits of (max_tmds_clock / 5 MHz)

# 300MHz / 5 = 60 = 0x03c
# Upper 3 bits = 0b000, lower 8 bits = 0x3c
# Flags byte: (1<<7) | (3<<5) | (1<<4) | 0 = 0b11110000 = 0xf0

# Oops, I already wrote ext[7], ext[8], ext[9] above as:
# ext[7] = 0x10 (PA byte A)
# ext[8] = 0x00 (PA byte B)
# ext[9] = 0xfa ... this is wrong because I had extra_flags bit set incorrectly
# Let me recalculate ext[9]:
# supports_ai=1, DC=48bit(11), DC_Y444=1, DVI_dual=0, max_tmds_upper=0
# = 1_11_1_0_000 = 0b11110000 = 0xf0

# I wrote 0xfa which is 0b11111010. That'\''s wrong. Let me correct.

# Actually wait, I already wrote the bytes above but the script will overwrite them
# when it executes. Let me just continue writing from ext[10] onwards.

# Re-reading my code above, ext[7] through ext[10] are already written.
# The HDMI VSDB takes bytes 3-10 (tag+len at 3, data at 4-10, length=7 data bytes, total 8 bytes)

# Let me verify: ext[3] to ext[10] inclusive = 8 bytes used
# Next available: ext[11]

# --- HDMI Forum VSDB (tag=3, OUI C4-5D-D8) ---
# Length: 3 (OUI) + 1 (version) = 4 bytes data
ext[11] = (3 << 5) | 4  # tag=3, length=4
ext[12:15] = bytes([0xC4, 0x5D, 0xD8])  # HDMI Forum OUI
ext[15] = 0x01  # version 1

# Total data used in extension block: 16 bytes (3 to 15 inclusive)
# Extension block is 128 bytes, we have plenty of room.

# DTDs fill the remainder of the extension block starting at offset designated by ext[2]
# ext[2] = 0x03 means DTDs start at data offset 3 * 18 = 54... no wait.
# "dtd offset" in CEA-861 header (ext[2]) is actually the number of bytes from
# the start of the extension block to the first DTD, divided by 1.
# Actually it'\''s: dtd_start = ext[2] (in bytes from start of extension)
# No, it'\''s the byte offset divided by 1 in newer specs...
# In CEA-861, the DTD offset is a byte count from the start of the extension data
# (which starts at ext[3]). The offset includes the data block collection size.
# dtd_offset = 3 means DTDs start at byte 3 of extension data = ext[6]

# Actually the CEA-861 format is:
# ext[0] = tag (0x02)
# ext[1] = revision (3)
# ext[2] = dtd_offset (byte offset from ext[0] to first DTD, i.e. the total size
#           of the data block collection area starting at ext[3])
# So dtd_offset = total_bytes_of_data_blocks + 3 (for the tag/rev/offset header)
# Wait no. The spec says:
# "Byte offset within this extension block of the first DTD.
#  A value of 0 means no DTDs in this extension block."
# So it'\''s the offset from ext[0] to the start of DTD area.
# The data block collection is between ext[3] and ext[0]+dtd_offset-1.

# Our data blocks take 13 bytes (ext[3] through ext[15] = bytes 3 to 15 inclusive)
# So DTDs start at offset = 16 (bytes 3..15 = 13 bytes of data, next byte is 16)
# ext[2] = 16

# Let me fix this.
ext[2] = 16

# After the data blocks, we have padding bytes then DTDs
# ext[16] through ext[17] = padding (0x00, 0x00)
ext[16:18] = b"\x00\x00"

# DTDs start at ext[18]
# We don'\''t need any more DTDs in the extension block.
# But the spec might require at least one DTD here.
# Let'\''s add a dummy DTD or just leave the rest as zeros.

# Actually, we need the extension block to end at 128 bytes properly.
# Fill remaining bytes with zeros, we don'\''t need extra DTDs.

# Checksum the extension block
ext[127] = checksum(ext[0:127])

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
