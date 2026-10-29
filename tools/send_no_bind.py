"""Send one CNN1 320x180 gray frame to the EG4D20 slave without binding port 6001.

The PC currently cannot own UDP 6001 (a background service holds it), so this
variant sends from an ephemeral source port.  The slave still receives and
decodes the frame; its ACKs go to the fixed peer port and are simply not seen
here.  Use it to check the slave UART, not the ACK path.
"""
import argparse
import socket
import struct
import time
import zlib

from PIL import Image, ImageDraw, ImageFont

BOARD_IP = "192.168.50.2"
BOARD_PORT = 6002
W, H = 320, 180
TOTAL = W * H
CHUNK = 1456
PACKETS = (TOTAL + CHUNK - 1) // CHUNK
LAST = TOTAL - (PACKETS - 1) * CHUNK


def build_image(pattern: str) -> bytes:
    img = Image.new("L", (W, H), 255)
    font = None
    for name in ("arialbd.ttf", "Arial Bold.ttf", "DejaVuSans-Bold.ttf"):
        try:
            font = ImageFont.truetype(name, 150)
            break
        except OSError:
            continue
    draw = ImageDraw.Draw(img)
    box = draw.textbbox((0, 0), pattern, font=font)
    draw.text(((W - (box[2] - box[0])) / 2 - box[0],
               (H - (box[3] - box[1])) / 2 - box[1]),
              pattern, fill=0, font=font)
    return img.resize((W, H), Image.BILINEAR).tobytes()


def build_packet(frame: int, index: int, payload: bytes) -> bytes:
    header = b"CNN1" + bytes([1, 0]) + struct.pack(">HHH", frame, index, len(payload))
    crc = zlib.crc32(header + payload) & 0xFFFFFFFF
    return header + payload + struct.pack(">I", crc)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pattern", default="8")
    ap.add_argument("--frame", type=int, default=1)
    ap.add_argument("--ip", default=BOARD_IP)
    ap.add_argument("--gap", type=float, default=0.004)
    a = ap.parse_args()

    data = build_image(a.pattern)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(0.2)
    print(f"target {a.ip}:{BOARD_PORT}")
    for idx in range(PACKETS):
        start = idx * CHUNK
        size = LAST if idx == PACKETS - 1 else CHUNK
        pkt = build_packet(a.frame, idx, data[start:start + size])
        s.sendto(pkt, (a.ip, BOARD_PORT))
        if a.gap:
            time.sleep(a.gap)
    print(f"sent {PACKETS} chunks, frame={a.frame}, {TOTAL} bytes")
    got = 0
    try:
        while True:
            d, addr = s.recvfrom(2048)
            got += 1
            if got <= 3:
                print(f"reply from {addr}: {d[:10].hex()}")
    except socket.timeout:
        pass
    print(f"replies received on ephemeral port: {got}")
    s.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
