"""Act as the EG4D20 slave: receive CNN1 image packets and answer with ACK1.

Run on the PC with the wired NIC at 192.168.50.2/24 and the master board
(192.168.50.1) connected directly.

    python tools/cnn1_slave_emu.py --seconds 30

For every well-formed CNN1 packet it prints the header fields and answers
to 192.168.50.1:6001 with the same 10-byte ACK the real slave sends:

    "ACK1" | frame_id(2) | packet_index(2) | status(1) | 0x00

That lets the master's own LEDs (ACK activity) and counters prove whether
its transmit path, ARP/MAC learning and ACK reception all work.
"""
from __future__ import annotations

import argparse
import socket
import struct
import time
import zlib

MASTER_IP = "192.168.50.1"
MASTER_PORT = 6001
LISTEN_PORT = 6002
CHUNK = 1456


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seconds", type=float, default=30.0)
    ap.add_argument("--chunks", type=int, default=0, help="stop after N packets")
    a = ap.parse_args()

    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", LISTEN_PORT))
    s.settimeout(0.5)

    t0 = time.time()
    n = 0
    bad = 0
    last = None
    print(f"listening {LISTEN_PORT}, answering to {MASTER_IP}:{MASTER_PORT}")

    while time.time() - t0 < a.seconds:
        try:
            data, addr = s.recvfrom(4096)
        except socket.timeout:
            continue
        n += 1
        if len(data) < 16 or data[:4] != b"CNN1":
            print(f"[{time.time()-t0:5.1f}s] from {addr[0]}:{addr[1]} len={len(data)} "
                  f"NOT CNN1 ({data[:4]!r})")
            continue
        ver, flags, frame, index, plen = struct.unpack(">BBHHH", data[4:12])
        payload = data[12:12 + plen]
        crc_rx = struct.unpack(">I", data[12 + plen:16 + plen])[0] if len(data) >= 16 + plen else 0
        crc_calc = zlib.crc32(data[:12 + plen]) & 0xFFFFFFFF
        ok = (len(data) == 16 + plen) and (crc_rx == crc_calc)
        if not ok:
            bad += 1
        print(f"[{time.time()-t0:5.1f}s] from {addr[0]}:{addr[1]} len={len(data)} "
              f"ver={ver} flags={flags} frame={frame} pkt={index} plen={plen} "
              f"crc={'ok' if ok else f'BAD rx={crc_rx:08x} calc={crc_calc:08x}'}")
        ack = b"ACK1" + struct.pack(">HHB", frame, index, 0 if ok else 1) + b"\x00"
        s.sendto(ack, (MASTER_IP, MASTER_PORT))
        last = (frame, index)
        if a.chunks and n >= a.chunks:
            break

    print(f"packets={n} bad={bad} last={last}")
    return 0 if n else 1


if __name__ == "__main__":
    raise SystemExit(main())
