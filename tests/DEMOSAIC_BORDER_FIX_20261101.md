# 1080p demosaic border repair

Base: A `42c320a` on `jop9.0`; implementation branch `fix/demosaic-top-border`.
B baseline `c56c4d3` is unchanged. No board programming was performed.

## Implementation

`raw_matrix_3x3_buffer.v` now builds windows about the output row. Row zero
waits for row one, uses reflected vertical neighbors, and has even BGGR phase.
The final row drains through the existing two line RAMs using 480 internal
groups; dummy data never enters an output window. Horizontal reflection uses
x=-1 -> 1 and x=W -> W-2. The output remains 480 groups per line, 1080 lines,
with SOF/EOL/VALID and Bayer phase aligned to the four-pixel window.

The valid-driven lookahead no longer needs `zhenghe`'s previous-frame line-time
estimate or its extra repacking RAM. Its source stays in the project but that
instance is removed. `line_buffer_demosaic.v` only marks a row readable on its
last **valid write**, handles adjacent rows without repeating word zero, and
ties off the unused RAM write port explicitly.

`video_frame_drain` in `video_integrity.v` holds the RAW EOF verdict until the
packed ISP frame has drained, bounded by a 608-cycle timeout. The top level
connects this completion to the existing capture writer. Without this change,
CSI EOF can close capture before the reflected last row reaches DDR.

## Verification

ModelSim SE-64 2020.4. Boundary tests load TD's actual PH1P_LOGIC_ERAM model,
PH1P_PHY_GSR, and generated line-memory wrappers. Vendor model warnings about
ECC-injection widths and INIT_FILE part-selects remain; no simulation errors
occur in the passing runs. The full CSI/capture test uses its existing
latency-matched memory models and models no PHY/DDR electrical behavior.

Passed:

- 1920x1080, two full frames (uniform per-channel values and coordinate-varying
  values), every pixel compared with an independent bilinear reference.
- 1920x1080 with valid gaps; same complete pixel and SOF/EOL comparisons.
- Small frames with no horizontal gap, verifying adjacent-row transitions.
- Six small frames with valid gaps after reset during a partial frame: uniform
  color, coordinate pattern, black, pure R, pure G, pure B.
- Full 1080p CSI -> RAW -> ISP -> capture: two complete frames publish, early
  EOF drains correctly, missing FE uses next FS, a truncated final row rejects.
- EOF helper unit test: early completion prevented, RAW error retained, partial
  frame timeout bounded.

The old whole-video fixture used 2592x1944 and assumptions about invisible
cropped tail rows. It is updated for the current direct 1920x1080 configuration;
a truncated final row is now inside the visible image and must reject.

## Reproduction

Run from the repository root; choose output directories outside tracked source.

```powershell
python tests/run_demosaic_boundary.py --out <scratch>/boundary --full
python tests/run_demosaic_boundary.py --out <scratch>/gaps --full --gaps
python tests/run_demosaic_boundary.py --out <scratch>/adjacent --no-line-gap
python tests/run_demosaic_boundary.py --out <scratch>/reset --gaps --reset-partial
python tests/run_video_safe.py --modelsim D:/modelsim/win64 --out <scratch>/video --tops tb_video_full_pipeline tb_video_frame_drain
```

Boundary runner defaults: ModelSim `D:/modelsim/win64`, TD `D:/TD`; both accept
overrides. `--baseline` is only for running an old implementation and expects
reference mismatches; do not use it to accept a repaired implementation.

Build script: `tests/build_a_demosaic_border_20261101.tcl`. Set `DEMO_BUILD_OUT`
to an independent output directory, then pass the script to
`D:/TD/bin/td_commands_prompt.exe` using a forward-slash absolute path.
The script refuses bit generation unless final setup and hold both pass.

## Hardware boundary and acceptance

The camera input cannot be backpressured. This implementation requires at least
one line of vertical blanking (480 group-clock cycles plus pipeline margin).
The tests provide that interval; the deployed B-to-A frame interval has not
been measured on a logic analyzer. A simulation assertion detects RAW arrival
during tail drain. This is a deployment condition, not a measured board result.

Before accepting hardware: RAM-load only the new A image, preserve the known
working B image and A rollback image, and check top/bottom/side borders, exposure
controls, frame dimensions, frame rate and capture/FIFO diagnostics. Confirm
that normal-light red lines disappear and that cover/uncover recovery works.
Final post-route results and artifact hashes are recorded in the accompanying
delivery report after the build finishes.
