# -*- coding: utf-8 -*-
"""El banco de la caceria contra el disco: rutas, canales, largos y sonoridad.

POR QUE EXISTE
--------------
La voz de la caceria loopea clips de 21 a 65 s, y para saber cuando empieza la
vuelta siguiente **tiene el largo escrito a mano en el Lua** -- `SoundDuration`
no es confiable sobre `.ogg` del lado del servidor, y eso ya esta medido y
escrito en `server_events.lua` desde antes de este bloque. Desde la r2 tiene
escrito tambien el **LUFS**, que es lo que decide la nivelacion de volumen.

Un largo escrito a mano es un dato que se DESINCRONIZA EN SILENCIO. Si alguien
reemplaza un `.ogg` por otra toma, o lo recodifica, el numero del Lua sigue ahi y
sigue pareciendo medido. El sintoma no es un error: es un hueco de silencio (si
el numero quedo corto, no -- si quedo LARGO) o un solape de la voz consigo misma
(si quedo corto), o sea *"a veces suena raro"*, que nadie va a poder atribuir.

⚠ Y EL ERROR SE ACUMULA. Cada vuelta agenda la siguiente, asi que un desfasaje de
medio segundo por clip son treinta segundos despues de una hora de hunt. Un
defecto que empeora con el tiempo no se ve en una prueba corta: se ve en la
partida del autor, que es el peor lugar donde encontrarlo.

`dev/rutas_de_sonido.py` ya cubre *"la ruta existe"*. Lo que no cubre nadie es
*"el numero de al lado sigue siendo el del archivo"*, y esa es la unica razon por
la que este script existe aparte.

QUE COMPRUEBA -- CINCO COSAS, Y LAS CINCO CON DENOMINADOR IMPRESO
------------------------------------------------------------------
  1. cada ruta del banco existe en `sound/`;
  2. el largo escrito coincide con el medido, con tolerancia de 0,05 s;
  3. el **LUFS** escrito coincide con el medido, con tolerancia de 0,6 LU. Es el
     numero del que sale el `volume` de la nivelacion: un LUFS que se quedo viejo
     baja el clip equivocado, y el sintoma es *"algunos se oyen raro"*. ⚠ Esta
     comprobacion NECESITA ffmpeg, y si no esta **lo dice** en vez de saltearse;
  4. los clips por voz son **mono** -- Source no espacializa un estereo, y la
     caceria es justo el sonido que tiene que dejarte ubicar al fantasma. El
     banco NEUTRO queda EXCEPTUADO a proposito: se sabe que `breath_1.ogg` es
     estereo, esta escrito en el Lua, y el dia que deje de serlo esta linea lo
     dice en vez de callarse;
  5. las dos voces que `phantom_EventVoice()` puede devolver ( 1 y 2 ) tienen
     banco y no esta vacio.

EL LECTOR NO ES NUEVO: es `medir()` de `dev/duracion_ogg.py`, o sea el mismo que
produjo los numeros que estan escritos en el Lua. Eso es a proposito -- un
segundo lector podria discrepar con el primero y el arnes no sabria a cual
creerle.

EL CONTROL DEL PROPIO ARNES ( --romper )
----------------------------------------
`--romper largo|falta|mono|vacio|lufs|todos` le mete el defecto al banco YA LEIDO
y el script tiene que ponerse rojo, cada uno en SU comprobacion. Sin esta perilla
un verde de aca no prueba que pueda haber un rojo -- *y una perilla que nadie
puede mover no es un control*.

⚠ Y `todos` exige el numero EXACTO de rojos ( ver `ESPERADAS` ), no "al menos
uno": ya paso una vez que un defecto inyectado pisara a otro y el modo ejercitara
menos de lo que promete, poniendose verde igual porque se ponia rojo por los
demas.

USO
    python dev/caceria_bancos.py
    python dev/caceria_bancos.py --romper todos
"""
import io
import os
import re
import sys
import importlib.util
import pathlib

AQUI = pathlib.Path(os.path.abspath(__file__)).parent
ADDON = AQUI.parent
LUA = ADDON / "lua" / "entities" / "terminator_nextbot_phantom" / "server_events.lua"
SOUND = ADDON / "sound"

TOLERANCIA = 0.05  # s

# ⚠ CUANTAS FALLAS TIENE QUE DAR CADA MODO DEL CONTROL, y no solo "al menos una".
# Un `--romper todos` que metiera cuatro defectos y se pusiera rojo por tres se
# lee exactamente igual que uno que los agarro a los cuatro, y este numero es lo
# unico que separa las dos lecturas. Ya paso al escribir este archivo: `falta`
# escribia sobre el mismo banco que `vacio` despues vaciaba, asi que `todos`
# ejercitaba TRES defectos afirmando cuatro -- y se ponia verde igual, porque se
# ponia rojo por los otros. *Un control que cuenta "al menos uno" se acredita
# solo el trabajo que no hizo.*
ESPERADAS = {"largo": 1, "falta": 1, "mono": 1, "vacio": 1, "lufs": 1, "todos": 5}


TOL_LUFS = 0.6  # LU -- ffmpeg redondea a un decimal y el Lua tambien


def cargar_lufs():
    """`medir()` de sonoridad_ogg.py, o None si no hay ffmpeg.

    ⚠ DEVUELVE None Y NO UNA FUNCION QUE MIENTE. Sin ffmpeg no hay medicion de
    sonoridad, y una que devolviera el valor escrito ( o un cero ) haria que la
    comprobacion se aprobara a si misma. El que llama tiene que poder DECIR que
    no se comprobo, que es lo que hace el barrido.
    """
    import subprocess

    try:
        subprocess.run(["ffmpeg", "-version"], capture_output=True, check=True)
    except Exception:
        return None

    spec = importlib.util.spec_from_file_location("sonoridad_ogg", AQUI / "sonoridad_ogg.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    def leer(ruta):
        lufs, _peak = mod.medir(ruta)
        return lufs

    return leer


def cargar_medir():
    """`medir()` de duracion_ogg.py, el MISMO lector que produjo los numeros."""
    spec = importlib.util.spec_from_file_location("duracion_ogg", AQUI / "duracion_ogg.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.medir


# --------------------------------------------------------------------------
# Leer el banco DEL ARCHIVO REAL, por anclas de texto. No se reescribe la tabla
# aca: una copia en Python mediria mi maqueta y no el addon -- que es la leccion
# que `voz_y_modelo.py` tiene escrita en su cabecera.
# --------------------------------------------------------------------------
FILA = re.compile(r'\{\s*"([^"]+\.ogg)"\s*,\s*([0-9]+\.[0-9]+)\s*,\s*(-?[0-9]+\.[0-9]+)\s*\}')


def leer_bancos():
    """{ '1': [(ruta, largo)], '2': [...], 'NEUTRA': [...] } leido del Lua."""
    txt = io.open(LUA, encoding="utf-8").read()

    ini = txt.find("local HUNT = {")
    if ini < 0:
        raise SystemExit("!! no se encontro `local HUNT = {` en " + str(LUA))

    fin = txt.find("local HUNT_NEUTRA = {", ini)
    if fin < 0:
        raise SystemExit("!! no se encontro `local HUNT_NEUTRA = {` en " + str(LUA))

    cuerpo_hunt = txt[ini:fin]
    finN = txt.find("\n}", fin)
    cuerpo_neu = txt[fin:finN]

    bancos = {}

    for voz in ("1", "2"):
        m = re.search(r"\[\s*" + voz + r"\s*\]\s*=\s*\{(.*?)\n    \}", cuerpo_hunt, re.S)
        bancos[voz] = FILA.findall(m.group(1)) if m else []

    bancos["NEUTRA"] = FILA.findall(cuerpo_neu)
    return bancos


def romper(bancos, que):
    """Le vuelve a meter el defecto al banco leido. El arnes TIENE que verlo."""
    todos = que == "todos"

    if que == "largo" or todos:
        r, d, l = bancos["1"][0]
        bancos["1"][0] = (r, "%.2f" % (float(d) + 3.0), l)

    # ⚠ SOBRE EL SEGUNDO Y NO SOBRE EL PRIMERO, por lo mismo que `falta`: el
    # primero ya lo toca `largo`, y dos defectos sobre la MISMA fila producen una
    # sola linea roja -- el arnes contaria 1 donde `todos` promete 2.
    if que == "lufs" or todos:
        r, d, l = bancos["1"][1]
        bancos["1"][1] = (r, d, "%.1f" % (float(l) + 5.0))

    # ⚠ VA AL BANCO DE LA VOZ 1 Y NO AL DE LA 2, Y NO ES INDISTINTO: `vacio`
    # corre despues y deja `bancos["2"] = []`, o sea que se llevaba puesta la
    # ruta inexistente. Ver el comentario de `ESPERADAS`.
    if que == "falta" or todos:
        bancos["1"].append(("phantasmagoria/ghost/hunt/voice_1_loop_99.ogg", "10.00", "-24.0"))

    if que == "mono" or todos:
        # breath_1 es el estereo conocido; metido en el banco de una VOZ tiene
        # que dar rojo, que es justo lo que el Lua explica que no hay que hacer.
        bancos["1"].append(("phantasmagoria/ghost/hunt/breath_1.ogg", "2.60", "-21.1"))

    if que == "vacio" or todos:
        bancos["2"] = []


def main():
    argv = sys.argv[1:]
    quebrar = None

    if "--romper" in argv:
        i = argv.index("--romper")
        quebrar = argv[i + 1] if i + 1 < len(argv) else "todos"

        if quebrar not in ESPERADAS:
            print("!! --romper acepta: " + " | ".join(sorted(ESPERADAS)))
            return 2

    medir = cargar_medir()
    medir_lufs = cargar_lufs()
    bancos = leer_bancos()

    if quebrar:
        romper(bancos, quebrar)
        print("*** CONTROL: se rompio `%s` a proposito. El arnes TIENE que ponerse rojo.\n" % quebrar)

    total = sum(len(v) for v in bancos.values())
    print("DENOMINADORES ( sin ellos un cero de fallas no significa nada ):")
    print("  archivo leido            %s" % LUA.relative_to(ADDON))
    print("  clips en el banco        voz 1 = %d - voz 2 = %d - NEUTRA = %d - total %d"
          % (len(bancos["1"]), len(bancos["2"]), len(bancos["NEUTRA"]), total))
    print("")

    if total == 0:
        print("!! CERO clips leidos: el lector no leyo nada, no es que el banco este bien.")
        return 1

    fallas = 0
    print("%-40s %8s %8s %8s %8s %4s  %s"
          % ("clip", "s escr", "s real", "LUFS es", "LUFS re", "ch", "veredicto"))
    print("-" * 118)

    for voz in ("1", "2", "NEUTRA"):
        for ruta, escrito, lufs_esc in bancos[voz]:
            disco = SOUND / pathlib.Path(ruta)
            nombre = ruta.split("/")[-1]
            escrito_f = float(escrito)
            lufs_f = float(lufs_esc)

            if not disco.is_file():
                print("! %-38s %8.2f %8s %8.1f %8s %4s  NO EXISTE EN DISCO"
                      % (nombre, escrito_f, "--", lufs_f, "--", "--"))
                fallas += 1
                continue

            dur, rate, canales, _ = medir(disco)

            if dur is None:
                print("! %-38s %8.2f %8s %8.1f %8s %4s  NO SE PUDO LEER: %s"
                      % (nombre, escrito_f, "--", lufs_f, "--", "--", rate))
                fallas += 1
                continue

            problemas = []
            delta = abs(dur - escrito_f)

            if delta > TOLERANCIA:
                problemas.append("LARGO NO COINCIDE ( delta %.2f s )" % delta)

            # El banco NEUTRA esta exceptuado del mono: ver la cabecera.
            if voz != "NEUTRA" and canales != 1:
                problemas.append("%d CANALES: Source no espacializa estereo" % canales)

            # ⚠ EL LUFS SE COMPRUEBA SOLO SI HAY ffmpeg, Y SU AUSENCIA SE
            # IMPRIME. Un chequeo que se saltea callado se lee como un chequeo
            # que paso, y este audita el numero del que depende la nivelacion.
            lufs_real = medir_lufs(disco) if medir_lufs else None

            if lufs_real is not None and abs(lufs_real - lufs_f) > TOL_LUFS:
                problemas.append("LUFS NO COINCIDE ( delta %.1f LU )" % abs(lufs_real - lufs_f))

            if problemas:
                fallas += 1

            print("%s %-38s %8.2f %8.2f %8.1f %8s %4d  %s"
                  % ("!" if problemas else " ", nombre, escrito_f, dur, lufs_f,
                     ("%.1f" % lufs_real) if lufs_real is not None else "sin ff",
                     canales, " - ".join(problemas) if problemas else "OK"))

    print("-" * 118)

    if not medir_lufs:
        print("!! SIN ffmpeg: la columna LUFS NO se comprobo. Los numeros de sonoridad del Lua")
        print("   quedan SIN AUDITAR en esta corrida -- no es que esten bien.")

    # La cuarta comprobacion: las dos voces que el resolvedor puede devolver
    # tienen banco. Un banco vacio manda al NEUTRO, que es estereo -- o sea que
    # esto no es una formalidad: es la unica puerta al clip que no se espacializa.
    for voz in ("1", "2"):
        if len(bancos[voz]) == 0:
            print("!! LA VOZ %s NO TIENE BANCO. `phantom_EventVoice()` puede devolverla "
                  "( es una de las dos del sorteo ), asi que esto NO es hipotetico: "
                  "esos fantasmas caen al banco NEUTRO, que es estereo." % voz)
            fallas += 1

    if quebrar:
        esperadas = ESPERADAS[quebrar]

        if fallas == esperadas:
            print("\nEL CONTROL SE PASA: con `%s` roto el arnes se puso ROJO en las %d "
                  "comprobacion(es) que ese modo rompe, y en ninguna otra. O sea que un "
                  "verde suyo puede ser un rojo." % (quebrar, fallas))
            return 0

        if fallas == 0:
            print("\n!! EL CONTROL FALLA: se rompio `%s` y el arnes siguio VERDE. "
                  "No discrimina, asi que sus verdes no valen." % quebrar)
            return 1

        print("\n!! EL CONTROL NO CUADRA: `%s` mete %d defecto(s) y el arnes reporto %d. "
              "Rojo por el numero equivocado de motivos es un arnes que agarra otra cosa, "
              "o que se pierde uno de los inyectados." % (quebrar, esperadas, fallas))
        return 1

    if fallas:
        print("\n%d falla(s) sobre %d clip(s)." % (fallas, total))
        return 1

    print("\n%d clips del banco de caceria: rutas en disco, largos que coinciden con el "
          "archivo ( tolerancia %.2f s ) y los de voz en mono." % (total, TOLERANCIA))
    print("Correr `python dev/caceria_bancos.py --romper todos` para ver que puede dar rojo.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
