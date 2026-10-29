"""Send one CNN1 image packet to the EG4D20 slave and wait for its ACK.

Matches the receiver in cnn_udp_image_rx.v:

    header 12 B : "CNN1" | version=1 | flags=0 | frame_id(2) | packet_index(2) | payload_len(2)
    payload     : payload_len bytes
    trailer 4 B : CRC-32 (reflected, init 0xFFFFFFFF, final xor), big endian

The board expects the packets to come from UDP port 6001 (HOST_PORT) and
answers to 192.168.50.1:6001 with a 10-byte ACK: "ACK1" + frame_id +
packet_index + status.

PC side: set the wired NIC to 192.168.50.1/24 (the board is 192.168.50.2).

Usage:
    python tools/cnn1_sender.py                 # one packet, wait for ACK
    python tools/cnn1_sender.py --count 40      # a whole frame, chunk by chunk
    python tools/cnn1_sender.py --packet 0 --frame 1
"""
from __future__ import annotations

import argparse
import socket
import struct
import time
import zlib

BOARD_IP = "192.168.50.2"
BOARD_PORT = 6002
HOST_PORT = 6001
CHUNK = 1456
TOTAL_BYTES = 320 * 180          # 57600
PACKETS = (TOTAL_BYTES + CHUNK - 1) // CHUNK   # 40
LAST = TOTAL_BYTES - (PACKETS - 1) * CHUNK    # 816


def build_packet(frame_id: int, index: int, payload: bytes) -> bytes:
    header = (b"CNN1" + bytes([1, 0]) +
              struct.pack(">HHH", frame_id, index, len(payload)))
    crc = zlib.crc32(header + payload) & 0xFFFFFFFF
    return header + payload + struct.pack(">I", crc)


def make_payload(index: int) -> bytes:
    size = LAST if index == PACKETS - 1 else CHUNK
    # simple deterministic pattern so the board can be checked in a dump
    return bytes(((index * 7 + i) & 0xFF) for i in range(size))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ip", default=BOARD_IP)
    ap.add_argument("--frame", type=int, default=1)
    ap.add_argument("--packet", type=int, default=0)
    ap.add_argument("--count", type=int, default=1, help="number of chunks to send")
    ap.add_argument("--timeout", type=float, default=2.0)
    a = ap.parse_args()

    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", HOST_PORT))
    s.settimeout(a.timeout)

    ok = 0
    for n in range(a.count):
        idx = a.packet + n
        if idx >= PACKETS:
            break
        pkt = build_packet(a.frame, idx, make_payload(idx))
        s.sendto(pkt, (a.ip, BOARD_PORT))
        print(f"sent frame={a.frame} packet={idx} len={len(pkt)} to {a.ip}:{BOARD_PORT}")
        try:
            data, addr = s.recvfrom(64)
        except socket.timeout:
            print(f"  no ACK within {a.timeout:.1f}s")
            continue
        print(f"  ACK from {addr[0]}:{addr[1]} len={len(data)} {data.hex()}"
              f" ascii={data[:4]!r}")
        if len(data) == 10 and data[:4] == b"ACK1":
            fid, pid, status, _reserved = struct.unpack(">HHBB", data[4:10])
            print(f"  -> frame={fid} packet={pid} status={status}")
            ok += 1
    print(f"ACKs: {ok}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
