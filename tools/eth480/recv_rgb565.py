"""接收 480x270 RGB565 的 CNN1 帧（A 板 -> 电脑），存成 PNG 并回 ACK1。

协议（与 320x180 灰度版相同，只是内容与块数不同）：
    头 12B: "CNN1" + ver=1 + flags=0 + frame_id(2) + packet_index(2) + payload_len(2)
    数据  : 480*270*2 = 259200 字节，RGB565 大端（高字节先）
    尾 4B : CRC32（反射 0xEDB88320，初值 0xFFFFFFFF，末尾取反，大端）
    分块  : 178 x 1456B + 末块 32B = 179 块
    ACK1  : "ACK1" + frame_id(2) + packet_index(2) + status(1) + 0x00

用法:
    python recv_rgb565.py --port 6002 --seconds 0
"""
from __future__ import annotations

import argparse
import socket
import struct
import time
import zlib
from pathlib import Path

import numpy as np
from PIL import Image

W, H = 480, 270
FRAME_BYTES = W * H * 2          # 259200
CHUNK_COUNT = 179
CHUNK_BYTES = 1456
LAST_CHUNK_BYTES = FRAME_BYTES - CHUNK_BYTES * (CHUNK_COUNT - 1)   # 32
HEADER_BYTES = 12
CRC_BYTES = 4


def parse_packet(pkt: bytes):
    if len(pkt) < HEADER_BYTES + CRC_BYTES or pkt[:4] != b"CNN1":
        return None
    version, flags = pkt[4], pkt[5]
    frame_id, chunk, plen = struct.unpack(">HHH", pkt[6:12])
    expect = LAST_CHUNK_BYTES if chunk == CHUNK_COUNT - 1 else CHUNK_BYTES
    if version != 1 or flags != 0 or chunk >= CHUNK_COUNT or plen != expect:
        return None
    if len(pkt) != HEADER_BYTES + plen + CRC_BYTES:
        return None
    if zlib.crc32(pkt[:-CRC_BYTES]) & 0xFFFFFFFF != struct.unpack(">I", pkt[-CRC_BYTES:])[0]:
        return None
    return frame_id, chunk, pkt[HEADER_BYTES:-CRC_BYTES]


def make_ack(frame_id: int, chunk: int) -> bytes:
    status = 1 if chunk == CHUNK_COUNT - 1 else 0
    return b"ACK1" + struct.pack(">HHBB", frame_id, chunk, status, 0)


def rgb565_to_rgb(raw: bytes) -> Image.Image:
    a = np.frombuffer(raw, dtype=">u2").astype(np.uint16)
    r = (a >> 11) & 0x1F
    g = (a >> 5) & 0x3F
    b = a & 0x1F
    r8 = (r << 3) | (r >> 2)
    g8 = (g << 2) | (g >> 4)
    b8 = (b << 3) | (b >> 2)
    rgb = np.stack([r8, g8, b8], axis=1).astype(np.uint8).reshape(H, W, 3)
    return Image.fromarray(rgb, "RGB")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=6002)
    ap.add_argument("--seconds", type=float, default=0.0, help="0 = 一直收")
    ap.add_argument("--out", default="rgb565_frame", help="PNG 前缀")
    ap.add_argument("--save-every", type=int, default=10, help="每 N 帧存一张")
    a = ap.parse_args()

    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", a.port))
    s.settimeout(0.5)

    started = time.monotonic()
    cur_id = None
    chunks: dict[int, bytes] = {}
    frames = bad = pkts = 0
    last_t = time.monotonic()
    t0 = last_t
    print(f"监听 UDP :{a.port}  期望 480x270 RGB565（{CHUNK_COUNT} 块 / {FRAME_BYTES} 字节）")

    try:
        while True:
            if a.seconds and time.monotonic() - started > a.seconds:
                break
            try:
                pkt, addr = s.recvfrom(2048)
            except socket.timeout:
                continue
            pkts += 1
            r = parse_packet(pkt)
            if r is None:
                bad += 1
                continue
            fid, chunk, payload = r
            if fid != cur_id:
                cur_id = fid
                chunks = {}
            chunks[chunk] = payload
            s.sendto(make_ack(fid, chunk), addr)

            if chunk == CHUNK_COUNT - 1 and len(chunks) == CHUNK_COUNT:
                raw = b"".join(chunks[i] for i in range(CHUNK_COUNT))
                if len(raw) == FRAME_BYTES:
                    frames += 1
                    if frames % a.save_every == 0 or frames == 1:
                        img = rgb565_to_rgb(raw)
                        path = Path(f"{a.out}_{fid:05d}.png")
                        img.save(path)
                        now = time.monotonic()
                        fps = frames / max(1e-6, now - t0)
                        print(f"帧 {fid}: OK  {path.name}   {fps:5.1f} fps")
                chunks = {}
    except KeyboardInterrupt:
        pass
    finally:
        s.close()

    dt = time.monotonic() - t0
    print(f"包 {pkts}  完整帧 {frames}  坏包 {bad}  用时 {dt:.1f}s  ≈ {frames/max(dt,1e-6):.1f} fps")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
