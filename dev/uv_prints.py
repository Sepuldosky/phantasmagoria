#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Genera las texturas de la evidencia Ultraviolet a partir de los decals de
sangre de `[gm] paranormal events`.

POR QUE EXISTE ESTE SCRIPT
--------------------------
gmpa trae cuatro decals en materials/effects/gmpa/decals/ que su Lua nunca
cablea (en 1056 lineas la palabra "decal" aparece una sola vez, en un
comentario). Son buenos y estan sin usar, asi que se reciclan.

PERO NO SON HUELLAS DE UV. Se miraron uno por uno antes de tocarlos:

    hand_l1  palma completa, mano IZQUIERDA, rojo oscuro sobre blanco
    hand_r1  palma completa, mano DERECHA
    hand_l2  NO es una huella: es un ARRASTRE de cuatro dedos
    hand_r2  idem, el otro lado

Su VMT es "DecalModulate" con $decalfadeduration 60 -- multiplica el fondo
para dejar una mancha de sangre. Que 60 s coincida con la duracion de las
huellas en Phasmophobia es casualidad: es un valor comun de decal de gore.

LA DERIVACION
-------------
Lo que sirve de esas texturas es la FORMA, y la forma vive en dos canales a
la vez: el alfa recorta la silueta y el RGB lleva el detalle interno (el
centro de la palma es mas oscuro que los bordes). Aplanar a blanco tiraria
ese detalle; usar solo el RGB traeria el fondo blanco.

    tinta  = invertir( luminancia(RGB) )   -- lo oscuro del original es tinta
    mascara = alfa * tinta                 -- recortada por la silueta real
    salida  = RGB blanco + A = mascara

Asi la textura queda como una MASCARA teñible: el color lo pone
surface.SetDrawColor en el cliente, que es lo que permite el azul-UV sin
generar una textura por color. Ver EQUIPAMIENTO.md seccion 8.

Los nombres de salida dicen lo que la cosa ES, no lo que decia el archivo
de origen: dos huellas y dos arrastres.

USO
    python dev/uv_prints.py            # escribe materials/phantasmagoria/uv/
    python dev/uv_prints.py --size 256 # upscale (el nativo es 128)
"""

import os
import re
import sys

try:
    from PIL import Image, ImageChops
except ImportError:
    sys.exit("Falta Pillow: pip install pillow")

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# El addon de origen vive FUERA del repo (dev/other/ esta gitignoreado).
SRC_DIR = os.path.normpath(os.path.join(
    ROOT, "..", "dev", "other", "phantom", "dev2",
    "[gm] paranormal events", "materials", "effects", "gmpa", "decals"))

DST_DIR = os.path.join(ROOT, "materials", "phantasmagoria", "uv")

# origen -> nombre honesto. El namespace es NUESTRO (phantasmagoria/uv/), no
# el de ellos: dos addons montando la misma ruta es la colision que
# lua/autorun/phantasmagoria_assetcheck.lua existe para detectar.
MAPPING = [
    ("hand_l1", "hand_left",   "palma completa, mano izquierda"),
    ("hand_r1", "hand_right",  "palma completa, mano derecha"),
    ("hand_l2", "smear_left",  "arrastre de dedos, no es una huella"),
    ("hand_r2", "smear_right", "arrastre de dedos, no es una huella"),
]


def load_vtf_reader():
    """Reusa read_vtf() de vtf2png.py sin ejecutar su main()."""
    path = os.path.join(HERE, "vtf2png.py")
    src = re.sub(r"(?m)^main\(\)\s*$", "", open(path, encoding="utf-8").read())
    ns = {"__name__": "vtf2png_lib", "__file__": path}
    exec(compile(src, "vtf2png.py", "exec"), ns)
    return ns["read_vtf"]


def derive(rgba):
    """RGBA de sangre -> mascara teñible (RGB blanco, A = alfa x tinta)."""
    r, g, b, a = rgba.split()
    tinta = ImageChops.invert(Image.merge("RGB", (r, g, b)).convert("L"))
    mask = ImageChops.multiply(a, tinta)
    white = Image.new("RGB", rgba.size, (255, 255, 255))
    out = white.convert("RGBA")
    out.putalpha(mask)
    return out


def main():
    size = 128
    if "--size" in sys.argv:
        size = int(sys.argv[sys.argv.index("--size") + 1])

    if not os.path.isdir(SRC_DIR):
        sys.exit("No esta el addon de origen:\n  %s\n"
                 "Se necesita [gm] paranormal events montado en dev/other/." % SRC_DIR)

    read_vtf = load_vtf_reader()
    os.makedirs(DST_DIR, exist_ok=True)

    hecho = 0
    for src_name, dst_name, que_es in MAPPING:
        src = os.path.join(SRC_DIR, src_name + ".vtf")
        if not os.path.isfile(src):
            print("  FALTA %s" % src)
            continue

        img, info = read_vtf(src, size)
        if img is None:
            print("  FALLO %s: %s" % (src_name, info))
            continue

        rgba = img.convert("RGBA")
        if rgba.size != (size, size):
            rgba = rgba.resize((size, size), Image.LANCZOS)

        out = derive(rgba)
        dst = os.path.join(DST_DIR, dst_name + ".png")
        out.save(dst)
        hecho += 1

        # cuantos pixeles quedan visibles: si esto da ~0 la derivacion fallo
        px = size * size - out.split()[3].histogram()[0]
        print("  %-9s -> %-12s %4d px con tinta   (%s)" % (
            src_name, dst_name + ".png", px, que_es))

    print("\n%d/%d escritas en %s" % (hecho, len(MAPPING),
                                      os.path.relpath(DST_DIR, ROOT)))
    print("Credito obligatorio: docs/CREDITOS.md -- son derivadas, no nuestras.")


main()
