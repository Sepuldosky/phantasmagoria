#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Reconvierte a 44100 Hz los .ogg del arbol de sonido de Phantasmagoria cuyo sample
rate Source rechaza ( solo acepta 44100, 22050 y 11025 ).

    python -u dev/resample_44100.py

YA CORRIO UNA VEZ, el 2026-08-09, y por eso existe este archivo. De los 826 .ogg
del arbol habia 270 invalidos ( 264 a 48000 y 6 a 32000 ) y el banco de VOZ del
fantasma estaba roto ENTERO: 39 de 39 clips, las dos voces. Los 270 quedaron en
44100, 0 rechazados, y la re-medicion del arbol entero dio 0 invalidos.

Se versiona porque HIZO UN CAMBIO IRREVERSIBLE SOBRE ASSETS QUE NO ESTAN EN GIT
( `sound/` esta gitignoreado ). Sin el script en el repo, la unica forma de
auditar que se hizo seria creerle al changelog. *Un cambio destructivo cuyo
instrumento no queda versionado es un cambio que nadie puede revisar.*

Correrlo de nuevo es seguro: si no hay invalidos, no toca nada y lo dice.

TRES REGLAS, y las tres son por lecciones ya pagadas en este taller:

  1. NADA se pisa sin backup VERIFICADO. `sound/` esta gitignoreado, asi que git
     NO es la red de contencion. Se copia primero y se comprueba el sha256 de la
     copia contra el original -- *una copia que nadie midio no es una red de
     contencion*.

  2. NADA se pisa sin que el reemplazo se haya MEDIDO antes. Se convierte a un
     archivo temporal, se le mide el sample rate y la duracion, y recien si los
     dos pasan se reemplaza. Un ffmpeg que falla a la mitad no puede dejar un
     .ogg truncado en el arbol.

  3. El bitrate de salida NO baja del de entrada. Resamplear obliga a reencodear
     ( no se puede cambiar el sample rate de un stream Vorbis sin decodificarlo ),
     asi que la generacion se pierde si o si; lo que se elige es no perder ademas
     bitrate. La calidad se elige POR ARCHIVO contra el bitrate medido.
"""

import csv
import hashlib
import json
import os
import shutil
import subprocess
import sys

# Las rutas salen de donde vive ESTE archivo ( phantasmagoria/dev/ ), no de una
# constante con la ruta de una maquina. El backup va AL LADO del checkout y no
# adentro: `sound/` esta gitignoreado, asi que una copia adentro del repo no la
# protege nadie, y ademas se subiria al Workshop.
AQUI   = os.path.dirname(os.path.abspath(__file__))
RAIZ   = os.path.dirname(AQUI)                       # .../phantasmagoria
SOUND  = os.path.join(RAIZ, "sound")
BACKUP = os.path.join(
    os.path.dirname(RAIZ),                           # la carpeta que contiene el repo
    "dev", "other", "OLD",
    "phantasmagoria_sound (BACKUP BEFORE RESAMPLE 44100)",
)
MANIFIESTO = os.path.join(AQUI, "resample_44100_manifiesto.csv")

VALIDOS = (44100, 22050, 11025)

# Bitrate nominal aproximado de libvorbis por -q:a, en bits/s. Se usa para
# elegir la calidad mas baja cuyo nominal NO baje del bitrate de origen.
QTABLA = [
    (0, 64000), (1, 80000), (2, 96000), (3, 112000), (4, 128000),
    (5, 160000), (6, 192000), (7, 224000), (8, 256000), (9, 320000),
    (10, 500000),
]


def sha256(ruta):
    h = hashlib.sha256()
    with open(ruta, "rb") as fh:
        for bloque in iter(lambda: fh.read(1 << 20), b""):
            h.update(bloque)
    return h.hexdigest()


def sondear(ruta):
    """sample_rate, canales, bitrate y duracion. None si no se pudo medir."""
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "a:0",
         "-show_entries", "stream=sample_rate,channels:format=bit_rate,duration",
         "-of", "json", ruta],
        capture_output=True, text=True,
    )
    if out.returncode != 0:
        return None
    try:
        d = json.loads(out.stdout)
        st = (d.get("streams") or [{}])[0]
        fm = d.get("format") or {}
        return {
            "sr": int(st.get("sample_rate") or 0),
            "ch": int(st.get("channels") or 0),
            "br": int(fm["bit_rate"]) if fm.get("bit_rate") else None,
            "dur": float(fm["duration"]) if fm.get("duration") else None,
        }
    except (ValueError, KeyError, IndexError):
        return None


def calidad_para(bitrate):
    if not bitrate:
        return 5
    for q, nominal in QTABLA:
        if nominal >= bitrate:
            return q
    return 10


def main():
    if not os.path.isdir(SOUND):
        sys.exit("no existe " + SOUND)

    todos = [os.path.join(dp, f)
             for dp, _, fs in os.walk(SOUND)
             for f in fs if f.lower().endswith(".ogg")]
    todos.sort()
    print("[censo] .ogg en el arbol: %d" % len(todos), flush=True)

    sujetos, nomedidos = [], []
    for ruta in todos:
        info = sondear(ruta)
        if info is None or info["sr"] == 0:
            nomedidos.append(ruta)
            continue
        if info["sr"] not in VALIDOS:
            sujetos.append((ruta, info))

    print("[censo] no medidos: %d" % len(nomedidos), flush=True)
    print("[censo] sujetos ( sample rate que Source rechaza ): %d" % len(sujetos), flush=True)
    for ruta in nomedidos:
        print("   NO MEDIDO: %s" % ruta, flush=True)

    if not sujetos:
        print("nada que hacer.")
        return

    # ---------------------------------------------------------------- backup
    print("[backup] destino: %s" % BACKUP, flush=True)
    copiados, fallo_backup = 0, []
    for ruta, _ in sujetos:
        rel = os.path.relpath(ruta, SOUND)
        dest = os.path.join(BACKUP, rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(ruta, dest)
        if sha256(dest) != sha256(ruta):
            fallo_backup.append(rel)
        else:
            copiados += 1

    print("[backup] verificados por sha256: %d de %d" % (copiados, len(sujetos)), flush=True)
    if fallo_backup:
        for rel in fallo_backup:
            print("   !! BACKUP NO VERIFICADO: %s" % rel, flush=True)
        sys.exit("ABORTADO: el backup no se pudo verificar. No se toco ningun original.")

    # ------------------------------------------------------------ conversion
    filas, ok, rechazados = [], 0, []
    for i, (ruta, info) in enumerate(sujetos, 1):
        rel = os.path.relpath(ruta, SOUND)
        q = calidad_para(info["br"])
        tmp = ruta + ".tmp44100.ogg"

        r = subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
             "-i", ruta, "-vn", "-map_metadata", "0",
             "-c:a", "libvorbis", "-q:a", str(q), "-ar", "44100", tmp],
            capture_output=True, text=True,
        )

        motivo = None
        if r.returncode != 0:
            motivo = "ffmpeg salio %d: %s" % (r.returncode, (r.stderr or "").strip()[:200])
        else:
            nuevo = sondear(tmp)
            if nuevo is None:
                motivo = "el resultado no se pudo sondear"
            elif nuevo["sr"] != 44100:
                motivo = "el resultado quedo en %d Hz" % nuevo["sr"]
            elif nuevo["ch"] != info["ch"]:
                motivo = "cambio la cantidad de canales: %d -> %d" % (info["ch"], nuevo["ch"])
            elif info["dur"] and nuevo["dur"] and abs(nuevo["dur"] - info["dur"]) > 0.05:
                motivo = "la duracion cambio %.3f s ( %.3f -> %.3f )" % (
                    nuevo["dur"] - info["dur"], info["dur"], nuevo["dur"])
            elif os.path.getsize(tmp) <= 0:
                motivo = "el resultado quedo vacio"

        if motivo:
            rechazados.append((rel, motivo))
            if os.path.exists(tmp):
                os.remove(tmp)
            print("   !! RECHAZADO %s -- %s  ( el original NO se toco )" % (rel, motivo), flush=True)
            filas.append([rel, info["sr"], "", info["br"] or "", q, "RECHAZADO", motivo])
            continue

        nuevo = sondear(tmp)
        antes = os.path.getsize(ruta)
        os.replace(tmp, ruta)
        ok += 1
        filas.append([rel, info["sr"], 44100, info["br"] or "", q, "OK",
                      "%d -> %d bytes" % (antes, os.path.getsize(ruta))])

        if i % 25 == 0 or i == len(sujetos):
            print("[convertir] %d / %d" % (i, len(sujetos)), flush=True)

    with open(MANIFIESTO, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["archivo", "sr_antes", "sr_despues", "bitrate_antes", "q_usada", "estado", "detalle"])
        w.writerows(filas)

    # ----------------------------------------------------------- re-medicion
    print("[verificar] re-midiendo el arbol ENTERO, no solo lo que toque", flush=True)
    quedan = []
    for ruta in todos:
        info = sondear(ruta)
        if info is None or info["sr"] not in VALIDOS:
            quedan.append((os.path.relpath(ruta, SOUND), info["sr"] if info else "no medido"))

    print("", flush=True)
    print("===== RESULTADO =====", flush=True)
    print("  sujetos            %d" % len(sujetos), flush=True)
    print("  convertidos OK     %d" % ok, flush=True)
    print("  rechazados         %d  ( original intacto )" % len(rechazados), flush=True)
    print("  backup verificado  %d de %d en %s" % (copiados, len(sujetos), BACKUP), flush=True)
    print("  QUEDAN INVALIDOS   %d  <- tiene que ser 0" % len(quedan), flush=True)
    for rel, sr in quedan:
        print("     %s  ( %s )" % (rel, sr), flush=True)
    print("  manifiesto         %s" % MANIFIESTO, flush=True)


if __name__ == "__main__":
    main()
