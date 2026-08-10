#!/usr/bin/env python3
"""Pasa a MONO los clips que el motor emite DESDE un objeto identificable.

POR QUE
-------
Source **no espacializa un sonido estereo**: lo reproduce en 2D, sin posicion.
La promesa entera de la r3 de Diseno 21 es *"el telefono suena DESDE el
telefono"* -- y medido con ffprobe, **14 de los 21 clips de `PROP_CONSUJETO`
eran estereo**, o sea que dos tercios de las familias nuevas incumplian esa
promesa en silencio: se oian, y se oian igual desde cualquier lado.

ALCANCE, Y ESTA ACOTADO A PROPOSITO
-----------------------------------
Se tocan **solo** los clips de `PROP_CONSUJETO`, que son los que esta ronda
promete posicionales sobre un objeto NOMBRADO. NO se tocan los otros 30 estereo
del motor -- `event/creak` ( 10 ), `event/impact` ( 9 ), `ghost/breathing` ( 8 )
y `ghost/humming` ( 2 ) -- por dos motivos:

  · suenan en un PUNTO cerca del fantasma o sobre el fantasma, no sobre un
    objeto que el jugador esta mirando, asi que la perdida es de matiz y no de
    mecanica;
  · el autor ya los escucho en la r1 y en la r2 y los dio por buenos
    ( *"Suenan bien"*, fila 11 de la r2 ). **Cambiar un asset que el autor ya
    aprobo, sin preguntarle, es de las cosas que este taller no hace.**

Los 30 quedan MEDIDOS y anotados en la planilla de la r3. Si la fila que lo mide
sale roja, este script corre sobre ellos cambiando una lista.

LA RED DE CONTENCION
--------------------
`sound/` esta **gitignoreado**: git no es la red aca -- esa leccion la pago la
reparacion de los 270 `.ogg` a 44100 en la r2. El backup va a
`dev/other/OLD/`, se verifica por sha256 ANTES de tocar nada, y al final se
re-lee cada archivo del disco para comprobar que quedo en 1 canal y con la
misma duracion.

  python dev/mono_posicionales.py            ( muestra que haria, no toca nada )
  python dev/mono_posicionales.py --aplicar
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(AQUI)
SOUND = os.path.join(ADDON, "sound")
BACKUP = os.path.join(os.path.dirname(ADDON), "dev", "other", "OLD",
                      "phantasmagoria_sound (BACKUP BEFORE MONO POSICIONALES)")

# Las rutas se sacan del Lua y NO se escriben a mano: si manana entra una familia
# nueva, este script la ve sola. *Una lista copiada a mano es una medicion vieja
# el dia que alguien edita el otro archivo.*
LUA = os.path.join(ADDON, "lua", "entities", "terminator_nextbot_phantom", "server_events.lua")


def rutas_de_consujeto():
    import re
    src = open(LUA, encoding="utf-8").read()
    i = src.index("local PROP_CONSUJETO = {")
    j = src.index("-- ⚠ LA MITAD DE LA PREGUNTA", i)
    return re.findall(r'"(phantasmagoria/[^"]+\.ogg)"', src[i:j])


def probe(full):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "a:0",
         "-show_entries", "stream=channels", "-show_entries", "format=duration",
         "-of", "json", full],
        capture_output=True, text=True)
    d = json.loads(out.stdout)
    return int(d["streams"][0]["channels"]), float(d["format"]["duration"])


def sha256(full):
    h = hashlib.sha256()
    with open(full, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--aplicar", action="store_true",
                    help="sin esto, solo se lista lo que haria")
    args = ap.parse_args()

    rutas = rutas_de_consujeto()
    print("PROP_CONSUJETO cita %d ruta(s) de sonido." % len(rutas))

    pendientes, ya_mono, faltan = [], [], []

    for r in rutas:
        full = os.path.join(SOUND, r.replace("/", os.sep))
        if not os.path.isfile(full):
            faltan.append(r)
            continue
        ch, dur = probe(full)
        (pendientes if ch > 1 else ya_mono).append((r, full, ch, dur))

    print("  ya mono   %d" % len(ya_mono))
    print("  estereo   %d   <- los que se convierten" % len(pendientes))
    if faltan:
        print("  ⚠ NO EXISTEN EN DISCO: %d  %s" % (len(faltan), faltan))
        print("  se aborta: una lista con huecos no es una medicion.")
        return 1

    for r, _full, ch, dur in pendientes:
        print("    %5.2f s  %dch  %s" % (dur, ch, r))

    if not args.aplicar:
        print("")
        print("MODO SECO. Para aplicar:  python dev/mono_posicionales.py --aplicar")
        return 0

    if not pendientes:
        print("nada que hacer.")
        return 0

    os.makedirs(BACKUP, exist_ok=True)
    print("")
    print("backup en: %s" % BACKUP)

    # ( 1 ) BACKUP Y VERIFICACION **ANTES** DE TOCAR NADA. Un backup que nadie
    # midio no es una red de contencion.
    antes = {}

    for r, full, ch, dur in pendientes:
        dest = os.path.join(BACKUP, r.replace("/", os.sep))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(full, dest)

        h_src, h_dst = sha256(full), sha256(dest)
        if h_src != h_dst:
            print("  !! el backup de %s NO coincide por sha256. SE ABORTA." % r)
            return 1

        antes[r] = (h_src, dur, ch)

    print("  %d archivo(s) respaldados y verificados por sha256." % len(antes))

    # ( 2 ) LA CONVERSION. `-ac 1` mezcla los dos canales; se mantiene el sample
    # rate ( ya son 44100 desde la reparacion de la r2 ) y la calidad q4, que es
    # la del arbol entero.
    ok, mal = 0, []

    for r, full, ch, dur in pendientes:
        tmp = full + ".mono.ogg"
        res = subprocess.run(
            ["ffmpeg", "-y", "-v", "error", "-i", full,
             "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", tmp],
            capture_output=True, text=True)

        if res.returncode != 0 or not os.path.isfile(tmp):
            mal.append((r, "ffmpeg fallo: " + res.stderr.strip()[:120]))
            continue

        os.replace(tmp, full)
        ok += 1

    # ( 3 ) SE RELEE DEL DISCO. No alcanza con que el archivo cambie: hay que
    # comprobar que cambio A LO QUE LE TOCABA. Es la regla 4 del catalogo de
    # controles de este taller.
    print("")
    print("re-lectura del disco ( el control, no el resultado de ffmpeg ):")

    for r, full, _ch, dur in pendientes:
        ch2, dur2 = probe(full)
        delta = abs(dur2 - dur)
        estado = "OK" if (ch2 == 1 and delta < 0.05) else "!! REVISAR"

        if estado != "OK":
            mal.append((r, "quedo en %dch y delta %.3f s" % (ch2, delta)))

        print("  %-9s %dch  delta %.3f s   %s" % (estado, ch2, delta, r))

    print("")
    print("convertidos %d de %d" % (ok, len(pendientes)))

    if mal:
        print("FALLARON %d:" % len(mal))
        for r, why in mal:
            print("  !! %s -- %s" % (r, why))
        return 1

    print("los %d quedaron en 1 canal con la misma duracion." % len(pendientes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
