# -*- coding: utf-8 -*-
"""VTF -> PNG, para mirar las texturas sin abrir el juego ni instalar nada.

Decodifica DXT1 / DXT3 / DXT5 / BGRA8888 / BGR888. Por defecto extrae un
mipmap chico (no el 2048 completo), que es lo que hace falta para saber que
es cada archivo y va cien veces mas rapido.

Uso:
    python dev/vtf2png.py                      # todo materials/ -> dev/preview/
    python dev/vtf2png.py --size 1024          # mipmap mas grande
    python dev/vtf2png.py --sheet              # ademas, una hoja de contactos
"""
import os, sys, struct, io, math
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "materials")
DST = os.path.join(ROOT, "dev", "preview")

FMT = {0: "RGBA8888", 1: "ABGR8888", 2: "RGB888", 3: "BGR888", 4: "RGB565",
       5: "I8", 6: "IA88", 7: "P8", 8: "A8", 12: "BGRA8888", 13: "DXT1",
       14: "DXT3", 15: "DXT5", 16: "BGRX8888", 24: "RGBA16161616F"}

BPP = {"BGRA8888": 4, "RGBA8888": 4, "ABGR8888": 4, "BGRX8888": 4,
       "RGB888": 3, "BGR888": 3, "RGB565": 2, "IA88": 2, "I8": 1, "A8": 1}


def mip_size(fmt, w, h):
    w, h = max(w, 1), max(h, 1)
    if fmt == "DXT1":
        return max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * 8
    if fmt in ("DXT3", "DXT5"):
        return max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * 16
    return w * h * BPP.get(fmt, 4)


def unpack565(c):
    r = ((c >> 11) & 0x1F) * 255 // 31
    g = ((c >> 5) & 0x3F) * 255 // 63
    b = (c & 0x1F) * 255 // 31
    return r, g, b


def decode_dxt(data, w, h, fmt):
    """DXT1/3/5 -> array RGBA (h, w, 4). Implementacion directa, sin libs."""
    bw, bh = max(1, (w + 3) // 4), max(1, (h + 3) // 4)
    out = np.zeros((bh * 4, bw * 4, 4), dtype=np.uint8)
    out[:, :, 3] = 255
    stride = 8 if fmt == "DXT1" else 16
    off = 0
    for by in range(bh):
        for bx in range(bw):
            if off + stride > len(data):
                break
            blk = data[off:off + stride]
            alpha = None
            if fmt == "DXT5":
                a0, a1 = blk[0], blk[1]
                bits = int.from_bytes(blk[2:8], "little")
                at = [a0, a1]
                if a0 > a1:
                    at += [((7 - i) * a0 + i * a1) // 7 for i in range(1, 7)]
                else:
                    at += [((5 - i) * a0 + i * a1) // 5 for i in range(1, 5)] + [0, 255]
                alpha = [at[(bits >> (3 * i)) & 7] for i in range(16)]
                cblk = blk[8:]
            elif fmt == "DXT3":
                a = int.from_bytes(blk[0:8], "little")
                alpha = [((a >> (4 * i)) & 0xF) * 17 for i in range(16)]
                cblk = blk[8:]
            else:
                cblk = blk

            c0, c1 = struct.unpack_from("<HH", cblk, 0)
            idx = struct.unpack_from("<I", cblk, 4)[0]
            r0, g0, b0 = unpack565(c0)
            r1, g1, b1 = unpack565(c1)
            pal = [(r0, g0, b0), (r1, g1, b1)]
            if c0 > c1 or fmt != "DXT1":
                pal.append(((2 * r0 + r1) // 3, (2 * g0 + g1) // 3, (2 * b0 + b1) // 3))
                pal.append(((r0 + 2 * r1) // 3, (g0 + 2 * g1) // 3, (b0 + 2 * b1) // 3))
            else:
                pal.append(((r0 + r1) // 2, (g0 + g1) // 2, (b0 + b1) // 2))
                pal.append((0, 0, 0))

            for py in range(4):
                for px in range(4):
                    i = py * 4 + px
                    col = pal[(idx >> (2 * i)) & 3]
                    y, x = by * 4 + py, bx * 4 + px
                    out[y, x, 0:3] = col
                    if alpha is not None:
                        out[y, x, 3] = alpha[i]
                    elif fmt == "DXT1" and c0 <= c1 and ((idx >> (2 * i)) & 3) == 3:
                        out[y, x, 3] = 0
            off += stride
    return out[:h, :w]


def decode_plain(data, w, h, fmt):
    n = BPP.get(fmt, 4)
    a = np.frombuffer(data[:w * h * n], dtype=np.uint8)
    if a.size < w * h * n:
        return None
    a = a.reshape(h, w, n)
    if fmt in ("BGRA8888", "BGRX8888"):
        out = a[:, :, [2, 1, 0, 3]].copy()
        if fmt == "BGRX8888":
            out[:, :, 3] = 255
        return out
    if fmt == "BGR888":
        return np.dstack([a[:, :, [2, 1, 0]], np.full((h, w), 255, np.uint8)])
    if fmt == "RGB888":
        return np.dstack([a, np.full((h, w), 255, np.uint8)])
    if fmt == "RGBA8888":
        return a
    return None


def read_vtf(path, target=256):
    d = open(path, "rb").read()
    if d[:4] != b"VTF\0":
        return None, "no es VTF"
    hdr_size = struct.unpack_from("<I", d, 12)[0]
    w, h = struct.unpack_from("<HH", d, 16)
    frames = struct.unpack_from("<H", d, 24)[0]
    hi_fmt = FMT.get(struct.unpack_from("<I", d, 52)[0], None)
    nmip = d[56]
    lo_fmt = FMT.get(struct.unpack_from("<I", d, 57)[0], None)
    lo_w, lo_h = d[61], d[62]

    if hi_fmt is None:
        return None, "formato %d no soportado" % struct.unpack_from("<I", d, 52)[0]

    off = hdr_size
    if lo_fmt and lo_w and lo_h:
        off += mip_size(lo_fmt, lo_w, lo_h)

    # los mipmaps se guardan del MAS CHICO al MAS GRANDE
    # mip level i (0 = el mas grande) mide w >> i
    want = 0
    for i in range(nmip):
        if max(w >> i, 1) <= target:
            want = i
            break
    else:
        want = 0

    for level in range(nmip - 1, -1, -1):
        mw, mh = max(w >> level, 1), max(h >> level, 1)
        sz = mip_size(hi_fmt, mw, mh) * max(frames, 1)
        if level == want:
            chunk = d[off:off + mip_size(hi_fmt, mw, mh)]
            if hi_fmt.startswith("DXT"):
                px = decode_dxt(chunk, mw, mh, hi_fmt)
            else:
                px = decode_plain(chunk, mw, mh, hi_fmt)
            if px is None:
                return None, "no pude decodificar %s" % hi_fmt
            return Image.fromarray(px, "RGBA"), "%dx%d %s (mip %d de %d)" % (w, h, hi_fmt, level, nmip)
        off += sz
    return None, "no encontre el mipmap"


def main():
    target = 256
    sheet = "--sheet" in sys.argv
    if "--size" in sys.argv:
        target = int(sys.argv[sys.argv.index("--size") + 1])

    os.makedirs(DST, exist_ok=True)
    made, failed = [], []
    for r, _, fs in os.walk(SRC):
        for f in sorted(fs):
            if not f.lower().endswith(".vtf"):
                continue
            src = os.path.join(r, f)
            rel = os.path.relpath(src, SRC).replace(os.sep, "__")[:-4]
            img, info = read_vtf(src, target)
            if img is None:
                failed.append((rel, info))
                continue
            out = os.path.join(DST, rel + ".png")
            img.convert("RGB").save(out)
            made.append((rel, info, img))
            print("  %-52s %s" % (rel, info))

    print("\nconvertidos: %d | fallidos: %d" % (len(made), len(failed)))
    for r, why in failed:
        print("   FALLO %s: %s" % (r, why))

    if sheet and made:
        cols = 8
        cell = 160
        rows = math.ceil(len(made) / cols)
        sh = Image.new("RGB", (cols * cell, rows * cell), (24, 24, 28))
        for i, (rel, info, img) in enumerate(made):
            th = img.convert("RGB").resize((cell - 8, cell - 8))
            sh.paste(th, ((i % cols) * cell + 4, (i // cols) * cell + 4))
        p = os.path.join(DST, "_hoja_de_contactos.png")
        sh.save(p)
        print("hoja de contactos: %s" % p)


main()
