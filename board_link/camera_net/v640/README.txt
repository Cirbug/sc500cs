640x360 RGB565 two-board image recognition

PH1P35 samples the 1920x1080 source once, every third pixel/line. Each
640x360 frame contains 230400 pixels / 460800 image bytes. Pixel bytes
are sent RGB565 high byte first. Version 3 uses 960 chunks, each carrying
240 pixels / 480 bytes plus a 16-byte header. The slave returns 48-byte
ACK/status packets, including 24-byte recognition results; it does not
return an image. No JPEG/H.264/RLE transport compression is implemented.

EG4D20 processes every received pixel at 40 MHz. There is no secondary
spatial downsampling. Five 3-bit pixel classes are packed into each
16-bit word. Sixteen BRAM32K blocks hold the first 163840 pixel classes;
ordinary BRAM holds the rest. The flood-fill queue stores 18-bit linear
addresses. Clearing one visited pixel preserves adjacent packed pixels.
Component areas and coordinates are widened for the full frame.

The HDMI result bridge maps coordinates by three, with the displayed box
covering each source sample's 3x3 cell. Target minimum areas/dimensions
and association distances are scaled to preserve prior screen coverage.
The RGB565 classifier uses R5/G6/B5 bin midpoints. More colour precision
does not itself prove that red/skin discrimination is fixed.

Current build projects: ../../../../td_project/camera_to_dsi_display.al (PH1P35)
and ../eg_image_sink640.al (EG4D20). The older camera_network*.al and
eg_image_sink*.al project files were removed; use build_main640.tcl and
build_eg640.tcl only.
Build scripts: build_main640.tcl / build_eg640.tcl in parent.
Test runner: v640/tests/run640.py. Additional native EG_PHY_BRAM32K tests
are tb_packed_ram640.sv and tb_guard640.sv; compile the vendor primitive
and eg_phy_glbl.v without MODEL_SIM, then simulate with work.glbl.
The transport pair uses a changing neutral-colour pattern to isolate
packet recovery. Separate receiver tests check full-range RGB565 values,
packed addresses, malformed packets, ordering and duplicate rejection.

Publish through finalize640.py only after simulation and routed setup/
hold timing pass. Output640 contains the matched pair and evidence.
Download scripts program volatile SRAM only. Main FPGA download must be
followed by reloading FDwork/anlu_app/build/anlu_app.elf into the MCU.
Do not change the firmware or pin constraints just to switch resolution.

The last-chunk ACK still waits for recognition. Frame rate depends on
scene complexity and is measured after programming, not inferred from
Ethernet clock speed. Auto tracking remains disabled in MCU RAM during
visual verification. Old output320 and output320_perf40 remain available.
