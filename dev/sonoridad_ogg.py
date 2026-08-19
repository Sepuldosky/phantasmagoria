# -*- coding: utf-8 -*-
"""Sonoridad EBU R128 de los `.ogg`, para poder contestar *"se oye mas bajito"*.

POR QUE EXISTE
--------------
El autor, corriendo la r1 de la caceria en juego: *"ese loop se siente mas bajito
que las canciones tarareadas ... el loop_01 es como un gorgoteo grave femenino,
le hacemos una ecualizacion?"*.

**"Se siente mas bajito" y "esta mas bajo" no son la misma afirmacion** -- es la
misma leccion que la ronda 7 del lote de equipamiento, donde *"se ve chico"* y
*"esta mal escalado"* resultaron ser cosas distintas y el que estaba mal era el
pack de referencia. Antes de tocar un asset hay que saber cual de las dos es.

Y el instrumento tiene que ser el correcto, no cualquiera:

  · un **pico** ( `max`, `true peak` ) no mide sonoridad: un clip con un golpe
    fuerte y todo lo demas bajo da el mismo pico que uno parejo y fuerte;
  · un **RMS plano** tampoco: el oido no es plano, y este caso es justamente un
    grave contra un agudo, o sea el caso donde un RMS plano se equivoca;
  · **LUFS ( EBU R128 )** lleva la ponderacion K, que modela esa sensibilidad por
    frecuencia, con gate de silencio. Es la medida que usan los juegos y el
    broadcast para decidir esto mismo.

Por eso este script mide LUFS integrado, y de yapa el true peak -- que es el que
dice cuanto margen hay para SUBIR un clip sin clipear.

!! LA CONCLUSION QUE HABILITA ES UNA SOLA. Si dos clips difieren en LUFS, falta
**ganancia**. Si sonaran igual de fuerte en LUFS y aun asi uno se percibiera
distinto, ahi si el problema seria de espectro y se hablaria de ecualizar. El
numero decide cual de las dos, y son arreglos distintos: la ganancia no toca el
timbre y la ecualizacion si.

EL DENOMINADOR VA IMPRESO
-------------------------
Cuantos archivos se leyeron y cuantos se pudieron medir. Un "0 problemas" de un
barrido que no midio nada se imprime igual que uno bueno.

EL AUTO-CONTROL
---------------
Antes de publicar, el script se mide a si mismo: genera con ffmpeg un tono de 1
kHz y **el mismo tono atenuado 6 dB**, y exige que la diferencia medida sea 6,0
+-0,3 LU. Si no reproduce una atenuacion que el mismo produjo, sus numeros sobre
los clips reales no significan nada y **aborta sin publicar**.

USO
    python dev/sonoridad_ogg.py sound/phantasmagoria/ghost/hunt
    python dev/sonoridad_ogg.py sound/phantasmagoria/ghost/hunt/voice_1_loop_01.ogg
    python dev/sonoridad_ogg.py <carpeta> --objetivo -24
"""
import os
import re
import subprocess
import sys
import tempfile
import pathlib

RE_I = re.compile(r"^\s*I:\s*(-?[\d.]+)\s*LUFS", re.M)
RE_PEAK = re.compile(r"True peak:\s*\n\s*Peak:\s*(-?[\d.]+)\s*dBFS", re.M)


def ffmpeg_ok():
    try:
        subprocess.run(["ffmpeg", "-version"], capture_output=True, check=True)
        return True
    except Exception:
        return False


def medir(ruta):
    """(LUFS integrado, true peak dBFS) o (None, motivo)."""
    try:
        p = subprocess.run(
            ["ffmpeg", "-hide_banner", "-nostats", "-i", str(ruta),
             "-af", "ebur128=peak=true", "-f", "null", "-"],
            capture_output=True, text=True, errors="replace")
    except Exception as e:
        return None, "no se pudo correr ffmpeg: %s" % e

    txt = p.stderr or ""
    mi = RE_I.findall(txt)
    mp = RE_PEAK.findall(txt)

    if not mi:
        return None, "ffmpeg no imprimio loudness integrado"

    # El ultimo `I:` es el del resumen final; los anteriores son del stream.
    return float(mi[-1]), (float(mp[-1]) if mp else None)


def autocontrol():
    """Genera un tono y el mismo tono -6 dB. La diferencia medida tiene que ser 6."""
    d = tempfile.mkdtemp(prefix="sonoridad_")
    a = os.path.join(d, "tono.ogg")
    b = os.path.join(d, "tono_6db.ogg")

    base = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-f", "lavfi", "-i", "sine=frequency=1000:duration=6"]

    try:
        subprocess.run(base + ["-c:a", "libvorbis", a], check=True, capture_output=True)
        subprocess.run(base + ["-af", "volume=-6dB", "-c:a", "libvorbis", b],
                       check=True, capture_output=True)
    except Exception as e:
        return None, "no se pudo generar el par de control: %s" % e

    la, _ = medir(pathlib.Path(a))
    lb, _ = medir(pathlib.Path(b))

    if la is None or lb is None:
        return None, "el par de control no se pudo medir"

    return (la - lb), None


def main():
    argv = sys.argv[1:]

    if not argv:
        print(__doc__)
        return 2

    objetivo = None
    if "--objetivo" in argv:
        i = argv.index("--objetivo")
        objetivo = float(argv[i + 1])
        del argv[i:i + 2]

    if not ffmpeg_ok():
        print("!! falta ffmpeg en el PATH. Sin el no hay medicion, y NO hay veredicto:")
        print("   un 'no se detectaron diferencias' de un lector ausente es un falso verde.")
        return 2

    objetivo_pth = pathlib.Path(argv[0])

    if objetivo_pth.is_dir():
        archivos = sorted(objetivo_pth.glob("*.ogg"))
    elif objetivo_pth.is_file():
        archivos = [objetivo_pth]
    else:
        print("!! no existe: %s" % objetivo_pth)
        return 2

    if not archivos:
        print("!! 0 archivos .ogg en %s -- un cero SIN LEER no es una medicion" % objetivo_pth)
        return 2

    # --- el auto-control, ANTES de publicar nada ---------------------------
    delta, err = autocontrol()

    if err:
        print("!! AUTO-CONTROL: %s" % err)
        print("   Sin control, los numeros de abajo no se publican.")
        return 2

    if abs(delta - 6.0) > 0.3:
        print("!! AUTO-CONTROL FALLA: una atenuacion de 6,0 dB que el script mismo produjo")
        print("   se midio como %.2f LU. El lector no reproduce una diferencia conocida," % delta)
        print("   asi que sus numeros sobre los clips reales no significan nada. ABORTA.")
        return 1

    print("AUTO-CONTROL: una atenuacion conocida de 6,0 dB se mide %.2f LU -> el lector reproduce.\n" % delta)
    print("DENOMINADOR: %d archivo(s) .ogg en %s\n" % (len(archivos), objetivo_pth))

    print("%-46s %10s %10s  %s" % ("archivo", "LUFS", "truepeak", "nota"))
    print("-" * 92)

    medidos = []
    fallas = 0

    for f in archivos:
        lufs, peak = medir(f)

        if lufs is None:
            print("! %-44s %10s %10s  NO SE PUDO MEDIR: %s" % (f.name, "--", "--", peak))
            fallas += 1
            continue

        medidos.append((f.name, lufs, peak))
        nota = ""

        if objetivo is not None:
            db = objetivo - lufs
            if db < 0:
                nota = "bajar %.1f dB  ( volume %.2f )" % (-db, 10 ** (db / 20.0))
            else:
                nota = "ya esta %.1f dB POR DEBAJO del objetivo: desde el Lua NO se puede subir" % db

        print("  %-44s %10.1f %10s  %s"
              % (f.name, lufs, ("%.1f" % peak) if peak is not None else "--", nota))

    print("-" * 92)

    if not medidos:
        print("!! 0 archivos medidos sobre %d leidos." % len(archivos))
        return 1

    lo = min(m[1] for m in medidos)
    hi = max(m[1] for m in medidos)
    nlo = [m[0] for m in medidos if m[1] == lo][0]
    nhi = [m[0] for m in medidos if m[1] == hi][0]

    print("%d de %d medidos.  el mas flojo %s ( %.1f )  ·  el mas fuerte %s ( %.1f )"
          % (len(medidos), len(archivos), nlo, lo, nhi, hi))
    print("DISPERSION: %.1f LU." % (hi - lo))

    # 10 LU ~ el doble de sonoridad percibida; es la regla de oro de R128.
    if hi - lo >= 6:
        print("   !! %.1f LU se oyen como clips distintos, no como el mismo banco"
              " ( ~10 LU = el doble de sonoridad )." % (hi - lo))
        print("   Es GANANCIA y no espectro: LUFS ya lleva la ponderacion del oido.")

    return 1 if fallas else 0


if __name__ == "__main__":
    sys.exit(main())
