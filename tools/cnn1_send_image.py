"""Send one 320x180 8-bit grayscale image to the EG4D20 slave over UDP.

Protocol (matches cnn_udp_image_rx.v / preview_sender.v):

    40 chunks, 1456 payload bytes each, last chunk 816 (total 57600 = 320*180)
    header 12 B : "CNN1" | version=1 | flags=0 | frame_id(2) | packet_index(2) | payload_len(2)
    trailer 4 B : CRC-32 over header+payload (reflected, init 0xFFFFFFFF, final xor), big endian
    source port 6001, destination 192.168.50.2:6002
    ACK expected within --timeout seconds: "ACK1" | frame(2) | packet(2) | status(1) | 0

The PC must sit at 192.168.50.1/24 and the slave at 192.168.50.2.
Note: the slave answers to whoever sent the packet, so no MAC tricks are needed.

Usage:
    python tools/cnn1_send_image.py --image tests/cap_1537_s14.png
    python tools/cnn1_send_image.py --pattern 8      # synthetic digit
"""
from __future__ import annotations

import argparse
import socket
import struct
import sys
import time
import zlib

from PIL import Image, ImageDraw, ImageFont

BOARD_IP = "192.168.50.2"
BOARD_PORT = 6002
HOST_PORT = 6001
W, H = 320, 180
TOTAL = W * H
CHUNK = 1456
PACKETS = (TOTAL + CHUNK - 1) // CHUNK          # 40
LAST = TOTAL - (PACKETS - 1) * CHUNK            # 816


def load_image(path: str | None, pattern: str | None) -> bytes:
    if path:
        img = Image.open(path).convert("L")
    else:
        img = Image.new("L", (W, H), 255)
        font = None
        for name in ("arialbd.ttf", "Arial Bold.ttf", "DejaVuSans-Bold.ttf"):
            try:
                font = ImageFont.truetype(name, 150)
                break
            except OSError:
                continue
        draw = ImageDraw.Draw(img)
        text = pattern or "8"
        box = draw.textbbox((0, 0), text, font=font)
        draw.text(((W - (box[2] - box[0])) / 2 - box[0],
                   (H - (box[3] - box[1])) / 2 - box[1]),
                  text, fill=0, font=font)
    img = img.resize((W, H), Image.BILINEAR)
    return img.tobytes()


def chunk_payload(data: bytes, index: int) -> bytes:
    start = index * CHUNK
    size = LAST if index == PACKETS - 1 else CHUNK
    return data[start:start + size]


def build_packet(frame: int, index: int, payload: bytes) -> bytes:
    header = (b"CNN1" + bytes([1, 0]) +
              struct.pack(">HHH", frame, index, len(payload)))
    crc = zlib.crc32(header + payload) & 0xFFFFFFFF
    return header + payload + struct.pack(">I", crc)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--image", default=None)
    ap.add_argument("--pattern", default=None, help="draw this text instead of a photo")
    ap.add_argument("--frame", type=int, default=1)
    ap.add_argument("--timeout", type=float, default=1.5)
    ap.add_argument("--retries", type=int, default=3)
    ap.add_argument("--ip", default=BOARD_IP)
    ap.add_argument("--save-gray", default=None, help="write the 320x180 gray frame here")
    a = ap.parse_args()

    data = load_image(a.image, a.pattern)
    assert len(data) == TOTAL, len(data)
    if a.save_gray:
        Image.frombytes("L", (W, H), data).save(a.save_gray)
        print(f"gray frame saved to {a.save_gray}")

    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", HOST_PORT))
    s.settimeout(a.timeout)

    t0 = time.time()
    acked = 0
    for idx in range(PACKETS):
        payload = chunk_payload(data, idx)
        pkt = build_packet(a.frame, idx, payload)
        ok = False
        for attempt in range(a.retries):
            s.sendto(pkt, (a.ip, BOARD_PORT))
            try:
                reply, addr = s.recvfrom(64)
            except socket.timeout:
                continue
            except ConnectionResetError:
                # ICMP port-unreachable while the peer is not answering
                continue
            if len(reply) == 10 and reply[:4] == b"ACK1":
                fid, pid, status, _ = struct.unpack(">HHBB", reply[4:10])
                if fid == a.frame and pid == idx:
                    # status 0 = chunk stored, 1 = last chunk / frame accepted,
                    # 2 = rejected (see cnn_udp_image_rx.v)
                    want = 1 if idx == PACKETS - 1 else 0
                    if status == want:
                        ok = True
                        break
                    print(f"  chunk {idx}: status={status} (expected {want})")
                    break
        if ok:
            acked += 1
        else:
            print(f"  chunk {idx}: NO ACK after {a.retries} tries")
        if idx % 8 == 7 or idx == PACKETS - 1:
            print(f"  {idx + 1}/{PACKETS} chunks done, acked={acked}, "
                  f"{time.time() - t0:.1f}s")
    dt = time.time() - t0
    print(f"frame {a.frame}: {acked}/{PACKETS} chunks ACKed in {dt:.2f}s "
          f"({TOTAL / max(dt, 1e-6) / 1024:.1f} KiB/s)")
    return 0 if acked == PACKETS else 1


if __name__ == "__main__":
    sys.exit(main())
