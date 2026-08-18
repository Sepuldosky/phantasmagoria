# -*- coding: utf-8 -*-
"""Toda ruta de sonido CITADA en el Lua tiene que existir en `sound/`.

POR QUE EXISTE
--------------
GMod **no tira error por un sonido que falta: no suena nada**. Mover o renombrar
un `.ogg` deja la cita colgada y el sintoma es *silencio*, que es exactamente lo
mismo que se oye cuando el evento no dispara, cuando el sorteo lo saltea o cuando
la convar esta en 0. Un defecto que se disfraza de los otros tres se paga tarde.

Este numero -- *"N rutas de sonido citadas, 0 faltantes en disco"* -- se cita en
cuatro entradas del CHANGELOG y hasta hoy se rederivaba **a mano en cada ronda**.
Un numero que sobrevive a su instrumento es una frase que nadie puede refutar; y
al reves, el instrumento versionado es lo que vuelve comparable la ronda que
viene con la de hoy.

EL DENOMINADOR VA IMPRESO, Y SON DOS
------------------------------------
  · cuantos `.lua` se leyeron -- un cero de un lector que no leyo nada se
    imprime igual que un cero bueno;
  · cuantas rutas distintas se encontraron.
Sin los dos, *"0 faltantes"* lo cumple igual un barrido que no miro ningun
archivo.

EL AUTO-CONTROL
---------------
Antes de publicar el veredicto, el script se pregunta a si mismo por una ruta
**que sabe que no existe**. Si no la reporta como faltante, no discrimina, y
entonces su `0 faltantes` no significa nada: aborta sin publicar.

USO
    python dev/rutas_de_sonido.py
"""
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(AQUI)
LUA_DIR = os.path.join(ADDON, "lua")
SOUND = os.path.join(ADDON, "sound")

# Cualquier literal que parezca una ruta de sonido del arbol propio. Se acepta
# `.ogg`, `.wav` y `.mp3` aunque hoy el arbol sea todo `.ogg`: el dia que entre
# un `.wav` no hay que acordarse de tocar el regex.
RUTA = re.compile(r'"(phantasmagoria/[^"\n]+\.(?:ogg|wav|mp3))"', re.IGNORECASE)

# La ruta del auto-control. No existe y no tiene que existir nunca; si alguien la
# crea, el control deja de discriminar y el script lo dice.
CEBO = "phantasmagoria/__no_existe__/control_negativo.ogg"


def lua_files():
    fuera = []
    for raiz, _dirs, archivos in os.walk(LUA_DIR):
        for a in archivos:
            if a.lower().endswith(".lua"):
                fuera.append(os.path.join(raiz, a))
    return sorted(fuera)


def citas(archivos):
    """{ ruta: [ (archivo_relativo, nro_linea) ] } -- con QUIEN la cita.

    Una ruta faltante sin su citador manda a buscarla con grep; con el citador,
    el rojo trae su propia direccion.
    """
    fuera = {}
    for full in archivos:
        rel = os.path.relpath(full, ADDON).replace(os.sep, "/")
        with open(full, encoding="utf-8", errors="replace") as f:
            for n, linea in enumerate(f, 1):
                for r in RUTA.findall(linea):
                    fuera.setdefault(r, []).append((rel, n))
    return fuera


def faltantes(rutas):
    """Las que NO resuelven en disco. Es la funcion que audita el auto-control."""
    fuera = []
    for r in sorted(rutas):
        if not os.path.isfile(os.path.join(SOUND, r.replace("/", os.sep))):
            fuera.append(r)
    return fuera


def main():
    archivos = lua_files()

    if not archivos:
        print("!! 0 archivos .lua bajo %s -- un cero SIN LEER no es una medicion." % LUA_DIR)
        return 2

    encontradas = citas(archivos)

    print("DENOMINADORES ( los dos, porque uno solo no alcanza ):")
    print("  archivos .lua leidos   %d" % len(archivos))
    print("  rutas distintas citadas %d" % len(encontradas))
    print("  citas totales           %d" % sum(len(v) for v in encontradas.values()))
    print("")

    # ---------------------------------------------------------- el auto-control
    # Se le pregunta por el cebo ANTES de creerle el veredicto. Y se comprueba
    # tambien que el cebo no exista de verdad: un control cuyo sujeto aparecio en
    # disco dejo de ser un control y pasa a ser un falso rojo.
    if os.path.isfile(os.path.join(SOUND, CEBO.replace("/", os.sep))):
        print("!! el cebo del auto-control EXISTE en disco (%s)." % CEBO)
        print("   dejo de discriminar: hay que elegir otro. SE ABORTA.")
        return 2

    if faltantes([CEBO]) != [CEBO]:
        print("!! el auto-control NO discrimina: preguntado por una ruta inventada,")
        print("   el barrido no la reporta como faltante. Su '0 faltantes' no")
        print("   significaria nada. SE ABORTA sin publicar el veredicto.")
        return 2

    print("AUTO-CONTROL: una ruta inventada SI se reporta como faltante -> el barrido discrimina.")
    print("")

    # ------------------------------------------------------------- el veredicto
    faltan = faltantes(encontradas.keys())

    if faltan:
        print("!! %d ruta(s) CITADAS Y SIN ARCHIVO ( enmudecen sin error ):" % len(faltan))
        for r in faltan:
            print("   %s" % r)
            for arch, n in encontradas[r]:
                print("      citada en %s:%d" % (arch, n))
        return 1

    print("%d rutas de sonido citadas, 0 faltantes en disco." % len(encontradas))
    return 0


if __name__ == "__main__":
    sys.exit(main())
