"""
Duracion REAL de un .ogg Vorbis, leida del archivo y no del nombre.

POR QUE EXISTE
--------------
`SoundDuration` no es confiable sobre .ogg del lado del servidor de GMod, y la
vida de un emisor de prop horneado tiene que cubrir el clip COMPLETO: si el
emisor se va antes, borrarlo ES el corte -- MEDIDO el 2026-08-18 sobre el
`info_target` que crea el addon --, o sea que el clip queda decapitado por otra
puerta.

⚠ Y solo sobre ESE emisor: la misma pasada midio que romper o borrar un
`prop_physics` que suena NO corta su sonido. Lo que sigue vale para el emisor
nuestro, que es de lo que este script calcula la vida.

COMO MIDE
---------
Dos lecturas del binario, ninguna estimada:

  · la tasa de muestreo sale del header de identificacion de Vorbis (paquete
    tipo 1, "\\x01vorbis"), que es el PRIMER paquete del PRIMER page;
  · las muestras totales salen del `granule position` del ULTIMO page con la
    bandera EOS (0x04), que en Vorbis cuenta muestras PCM del canal.

  duracion = granule_final / samplerate

⚠ EL AUTO-CONTROL, Y ES LO QUE VUELVE CITABLE A ESTE ARCHIVO. Cuatro clips de
`prop/radio/` ya estaban medidos con otro instrumento (2026-08-17, en el prompt
del bloque del +USE). Este script los vuelve a medir y COMPARA: si alguno se
aparta mas de 0,02 s, el script sale con codigo 1 y no publica ningun numero
nuevo. Sin ese control, un lector recien escrito imprime numeros plausibles
sobre cualquier cosa -- que es exactamente como se perdio el censo de props
horneados viejo.

⚠ TAMBIEN CUENTA LOS CANALES. Source NO espacializa un sonido estereo: lo tira
en 2D. Un clip estereo en una familia con sujeto rompe EN SILENCIO la promesa
"suena DESDE el objeto" -- este taller ya pago ese defecto en 15 archivos.

USO
    python dev/duracion_ogg.py sound/phantasmagoria/prop/radio
    python dev/duracion_ogg.py sound/phantasmagoria/prop/radio/creepy_music.ogg
"""
import struct
import sys
import pathlib

# Los cuatro ya medidos con otro instrumento. Son el CONTROL, no el resultado.
CONTROL = {
    "creepy_montage.ogg": 41.41,
    "creepy_music.ogg": 33.71,
    "creepy_music_old.ogg": 26.78,
    "creepy_music_slowdown.ogg": 42.23,
}
TOLERANCIA = 0.02  # s


def paginas(data):
    """Todos los pages OggS: (offset, granule, flags)."""
    fuera = []
    i = 0
    n = len(data)
    while True:
        i = data.find(b"OggS", i)
        if i < 0 or i + 27 > n:
            break
        flags = data[i + 5]
        granule = struct.unpack_from("<q", data, i + 6)[0]
        segs = data[i + 26]
        cab = 27 + segs
        if i + cab > n:
            break
        cuerpo = sum(data[i + 27:i + 27 + segs])
        fuera.append((i, granule, flags, i + cab, cuerpo))
        i += cab + cuerpo
    return fuera


def medir(ruta):
    """(duracion_s, samplerate, canales, n_pages) o (None, motivo, ...)."""
    data = ruta.read_bytes()
    if not data.startswith(b"OggS"):
        return None, "no arranca con OggS", None, None

    pgs = paginas(data)
    if not pgs:
        return None, "sin pages OggS", None, None

    # Header de identificacion: primer paquete del primer page.
    _, _, _, ini, _ = pgs[0]
    cab = data[ini:ini + 30]
    if not cab.startswith(b"\x01vorbis"):
        return None, "el primer paquete no es un header Vorbis", None, None

    canales = cab[11]
    rate = struct.unpack_from("<I", cab, 12)[0]
    if rate <= 0:
        return None, "samplerate 0 en el header", None, None

    # El ultimo page con EOS. Si ninguno lo trae (archivo truncado), se usa el
    # ultimo page y SE DICE, porque un truncado y un archivo sano miden igual.
    eos = [p for p in pgs if p[2] & 0x04]
    trunco = not eos
    granule = (eos[-1] if eos else pgs[-1])[1]
    if granule < 0:
        return None, "granule negativo en el ultimo page", None, None

    dur = granule / rate
    return (dur, rate, canales, len(pgs)) if not trunco else (dur, rate, canales, -len(pgs))


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2

    objetivo = pathlib.Path(sys.argv[1])
    if objetivo.is_dir():
        archivos = sorted(objetivo.glob("*.ogg"))
    elif objetivo.is_file():
        archivos = [objetivo]
    else:
        print(f"!! no existe: {objetivo}")
        return 2

    if not archivos:
        print(f"!! 0 archivos .ogg en {objetivo} -- un cero SIN LEER no es una medicion")
        return 2

    print(f"DENOMINADOR: {len(archivos)} archivo(s) .ogg en {objetivo}\n")
    print(f"{'archivo':<46} {'dur (s)':>9} {'rate':>7} {'ch':>3}  control")
    print("-" * 92)

    vistos = {}
    fallas = 0
    for f in archivos:
        dur, rate, canales, pgs = medir(f)
        if dur is None:
            print(f"! {f.name:<44} {'--':>9} {'--':>7} {'--':>3}  NO SE PUDO LEER: {rate}")
            fallas += 1
            continue

        marca = ""
        esperado = CONTROL.get(f.name)
        if esperado is not None:
            d = abs(dur - esperado)
            if d <= TOLERANCIA:
                marca = f"OK  ({esperado:.2f} esperado, delta {d:.3f})"
            else:
                marca = f"!! NO REPRODUCE ({esperado:.2f} esperado, delta {d:.3f})"
                fallas += 1

        aviso = ""
        if canales != 1:
            aviso += f"  !! {canales} CANALES: Source no espacializa estereo"
        if pgs is not None and pgs < 0:
            aviso += "  !! sin page EOS: el archivo puede estar truncado"

        print(f"  {f.name:<44} {dur:>9.2f} {rate:>7} {canales:>3}  {marca}{aviso}")
        vistos.setdefault(round(dur, 2), []).append((f.name, f.stat().st_size))

    # Dos sujetos distintos no dan el mismo numero a la centesima; si lo dan, el
    # instrumento leyo el mismo origen dos veces. Es una senal de DETECCION y no
    # un veredicto, y por eso lleva al lado el discriminante: si los dos archivos
    # pesan distinto son dos audios que coinciden por casualidad (pasa seguido
    # entre clips de menos de un segundo); si pesan IGUAL, es el mismo binario
    # con dos nombres o el lector leyendo dos veces el mismo origen.
    for d, filas in sorted(vistos.items()):
        if len(filas) > 1:
            iguales = len({t for _, t in filas}) == 1
            detalle = ", ".join(f"{n} ({t} bytes)" for n, t in filas)
            print(f"\n  !! MISMA DURACION A LA CENTESIMA ({d:.2f} s): {detalle}")
            print("     " + ("MISMO TAMANO: sospechar del lector o de un duplicado."
                             if iguales else
                             "tamanos distintos: son dos audios, la coincidencia es del redondeo."))

    tocados = [f.name for f in archivos if f.name in CONTROL]
    print("-" * 92)
    print(f"CONTROL: {len(tocados)} de {len(CONTROL)} clips con valor previo entraron en esta corrida")
    if fallas:
        print(f"!! {fallas} fila(s) con problema. NO se publican los numeros nuevos de esta corrida.")
        return 1

    # ⚠ Una corrida sin ningun clip de control NO puede decir "OK": no midio si el
    # lector sigue leyendo bien. Es la nº 14 del catalogo -- los ausentes contados
    # como aprobados --, y aca costaria publicar numeros de un lector sin calibrar.
    if not tocados:
        print("PARCIAL: ningun clip de control entro en esta corrida, asi que el lector NO quedo")
        print("         calibrado aca. Los numeros valen si en la MISMA sesion corrio")
        print("         `python dev/duracion_ogg.py sound/phantasmagoria/prop/radio` y dio OK.")
        return 3

    print("OK: el instrumento reproduce los valores previos; los numeros nuevos de esta corrida valen.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
