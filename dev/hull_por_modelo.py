#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
hull_por_modelo.py -- ejecuta EL BLOQUE REAL que decide el hull del fantasma y
dice que caja le sale a cada modelo.

Corre dos pedazos, extraidos de sus archivos y sin reescribirlos:
`hullDelModelo()` de terminator_nextbot_phantom/server.lua, y el registro
lua/phantasmagoria/ghost_models.lua entero, que es de donde sale la `altura`.

POR QUE ESTE ARNES Y NO EL DE SIEMPRE
-------------------------------------
`dev/phastools/luaharness.py` NO puede construir este sujeto: se queda antes de
terminar de cargar `terminator_nextbot_phantom/server.lua` ( handoff §R5.3 ). O
sea que no da cobertura y no se le acredita ninguna. Lo que si se puede hacer
--y es lo que hizo la r5-- es extraer el bloque REAL por rango, sin reescribirlo,
y ejercitarlo. Si alguien edita esas lineas, esto corre lo editado.

QUE DEFECTO VIGILA
------------------
El 2026-08-17, en juego, una OldCrone de 68,98 u de alto spawneo con
`hull 20x20x45` y la linea de diagnostico dijo `malla 44.94 de alto`: los dos
numeros son de la NENA. Vivian en dos `local` --`HULL_ALTO`/`HULL_ANCHO` y
`MALLA_ALTO`-- que se leian para los tres modelos, mientras el registro de al
lado ya tenia los tres altos medidos.

⚠ EL CRITERIO MAS IMPORTANTE NO ES QUE LOS ADULTOS CAMBIEN: ES QUE LA NENA NO.
Es el unico de los tres con una pasada en juego cerrada ( 22 rondas ), asi que
el camino por defecto tiene que salir IDENTICO a lo que ya estaba: 20x20x45.
Un cambio que arregla a dos y mueve al tercero en silencio no es un arreglo.

EL CONTROL DEL PROPIO ARNES ( --romper )
----------------------------------------
Con `--romper` se le vuelve a meter el defecto al bloque extraido ( se sustituye
`ficha.altura` por la constante `44.94` de la nena ) y el arnes TIENE que ponerse
rojo: la nena en verde y los dos adultos en rojo. Sin esa perilla, un verde de
aca no prueba que pueda haber un rojo -- y una perilla que nadie puede mover no
es un control.

⚠ LO QUE ESTE ARNES NO MIDE. Que el hull LLEGUE a la entidad lo decide
`AdditionalInitialize`, que necesita el motor. Aca se mide la funcion que
produce los numeros, no que alguien la llame. La fila de la pasada en juego
sigue haciendo falta y esta en la planilla.
"""

import argparse
import os
import sys

import lupa

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SERVER = os.path.join(RAIZ, "lua", "entities", "terminator_nextbot_phantom", "server.lua")
REGISTRO = os.path.join(RAIZ, "lua", "phantasmagoria", "ghost_models.lua")

# Se buscan POR TEXTO y no por numero de linea: un rango clavado
# se desfasa con la primera linea que alguien agregue arriba, y ese desfase es
# silencioso -- extraeria un pedazo cualquiera.
BLOQUES = [
    (SERVER, "local BASE_ALTO, BASE_ANCHO = 72, 16",
     "---------------------------------------------------------------------------"),
    (REGISTRO, "PHANTASMAGORIA = PHANTASMAGORIA or {}", None),
]

# ( ruta, alto, ancho ) esperados. nil = este modelo NO lleva hull nuestro.
#
# La nena es EL CONTROL: 45 y 10 son los numeros que ya estaban clavados en el
# archivo antes de este cambio, o sea los que corrieron las 22 rondas.
ESPERADO = [
    ("models/phantasmagoria/ghost_girl.mdl",      45, 10, "EL CONTROL: identico a lo que ya corria"),
    ("models/phantasmagoria/ghost_male.mdl",      72, 16, "coincide con el hull de la base, como predijo el comentario"),
    ("models/phantasmagoria/ghost_oldcrone.mdl",  69, 15, "nuevo: antes le tocaba la caja de 45 de la nena"),
    ("models/player/corpse1.mdl",               None, None, "ajeno: sin hull nuestro"),
    ("models/dejtriyev/scaryblackman.mdl",      None, None, "ajeno: sin hull nuestro"),
    ("models/player/group01/male_04.mdl",       None, None, "ajeno: sin hull nuestro"),
]

# El caso degenerado va DE FABRICA y no como test que alguien tiene que
# acordarse de escribir ( catalogo nº 15 ). `nil` y `""` son lo que devuelve
# `GetModel()` de una entidad sin modelo, que no es lo mismo que un modelo ajeno.
DEGENERADOS = [
    (None, "GetModel() nil"),
    ("", "GetModel() vacio"),
    ("models/phantasmagoria/no_existe.mdl", "modelo del taller que no esta en la lista"),
]

BOOT = r"""
-- Stubs FIELES. `math.Round` es la de GMod al pie de la letra: si el stub
-- redondeara distinto, este arnes mediria otra cosa y su verde no valdria.
math.Round = function( num, idp )
    local mult = 10 ^ ( idp or 0 )
    return math.floor( num * mult + 0.5 ) / mult
end
isnumber   = function( v ) return type( v ) == "number" end
isstring   = function( v ) return type( v ) == "string" end
isfunction = function( v ) return type( v ) == "function" end
"""


def par(res):
    """`return nil` de Lua llega como None y no como una tupla de dos. Se
    normaliza aca en vez de en cada sitio: desempaquetarlo suelto tira un
    TypeError que se lee como un defecto del sujeto y es del arnes."""
    if res is None:
        return (None, None)
    if isinstance(res, tuple):
        return res
    return (res, None)


def extraer(texto, desde, hasta):
    i = texto.find(desde)
    if i < 0:
        raise SystemExit("!! no aparece el ancla de inicio: %r" % desde)
    if hasta is None:
        return texto[i:]
    j = texto.find(hasta, i + len(desde))
    if j < 0:
        raise SystemExit("!! no aparece el ancla de fin: %r" % hasta)
    return texto[i:j]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--romper", action="store_true",
                    help="reinyecta el defecto ( la constante de la nena para todos ) "
                         "y exige que el arnes se ponga rojo")
    args = ap.parse_args()

    trozos = [extraer(open(f, encoding="utf-8").read(), a, b) for f, a, b in BLOQUES]
    codigo = "\n".join(trozos)

    if args.romper:
        if "ficha.altura" not in codigo:
            raise SystemExit("!! --romper no encontro `ficha.altura`: el defecto que "
                             "reinyecta ya no existe con esa forma. Revisar el arnes.")
        codigo = codigo.replace("ficha.altura", "44.94")

    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute(BOOT)
    L.execute(codigo + """
    _G.__hull  = hullDelModelo
    _G.__lista = PHANTASMAGORIA.GhostModels
    """)

    hull = L.globals()["__hull"]
    lista = L.globals()["__lista"]

    print("hull_por_modelo -- bloque REAL de %s" % os.path.relpath(SERVER, RAIZ))
    if args.romper:
        print("!! MODO --romper: el defecto esta reinyectado. Esto TIENE que dar FALLA.\n")
    else:
        print()

    print("  %-46s %-12s %s" % ("modelo", "hull", "que dice"))

    fallas, medidos = 0, 0
    for ruta, ealto, eancho, nota in ESPERADO:
        alto, ancho = par(hull(ruta))
        medidos += 1
        ok = (alto == ealto and ancho == eancho)
        if not ok:
            fallas += 1

        if alto is None:
            visto = "sin hull"
        else:
            visto = "%dx%dx%d" % (ancho * 2, ancho * 2, alto)

        esp = "sin hull" if ealto is None else "%dx%dx%d" % (eancho * 2, eancho * 2, ealto)
        print("  %-46s %-12s %s  %s" % (os.path.basename(ruta), visto,
                                        "OK  " if ok else "FALLA",
                                        nota if ok else ("esperaba " + esp)))

    print("\n  casos degenerados ( van de fabrica: un `nil` no es un modelo ajeno )")
    for ruta, nota in DEGENERADOS:
        try:
            alto, ancho = par(hull(ruta))
        except Exception as e:                                   # noqa: BLE001
            fallas += 1
            medidos += 1
            print("  %-46s TIRO: %s" % (nota, e))
            continue
        medidos += 1
        ok = alto is None and ancho is None
        if not ok:
            fallas += 1
        print("  %-46s %-12s %s" % (nota, "sin hull" if alto is None else "%s" % alto,
                                    "OK" if ok else "FALLA: devolvio un hull"))

    # Una ficha del registro SIN `altura`: no se le inventa un numero.
    L.execute('''
        PHANTASMAGORIA.GhostModelPorRuta[ "models/phantasmagoria/sin_altura.mdl" ] =
            { mdl = "models/phantasmagoria/sin_altura.mdl", nombre = "sin altura" }
    ''')
    alto, ancho = par(hull("models/phantasmagoria/sin_altura.mdl"))
    medidos += 1
    ok = alto is None and ancho is None
    if not ok:
        fallas += 1
    print("  %-46s %-12s %s" % ("ficha del registro SIN `altura` medida",
                                "sin hull" if alto is None else str(alto),
                                "OK" if ok else "FALLA: le invento un hull"))

    # ⚠ EL REGISTRO AUSENTE, que es el riesgo que introdujo leerlo de otro
    # archivo. La funcion tiene que devolver nil y NO tirar: un error de Lua
    # adentro de AdditionalInitialize se lleva puesto el resto del spawn, y eso
    # ya paso una vez en este addon ( catalogo nº 26 ).
    L.execute("_G.__phanta = PHANTASMAGORIA; PHANTASMAGORIA = nil")
    try:
        alto, ancho = par(hull("models/phantasmagoria/ghost_girl.mdl"))
        ok = alto is None and ancho is None
        detalle = "OK" if ok else "FALLA: devolvio un hull sin registro"
    except Exception as e:                                       # noqa: BLE001
        ok, detalle = False, "FALLA: TIRO -- %s" % e
    L.execute("PHANTASMAGORIA = _G.__phanta")
    medidos += 1
    if not ok:
        fallas += 1
    print("  %-46s %-12s %s" % ("ghost_models.lua NO cargado", "sin hull", detalle))

    # ⚠ Denominador y cobertura de la LISTA, no de mi tabla: si alguien agrega un
    # modelo y no lo agrega aca, el 0 fallas de arriba habla de menos modelos que
    # los que existen -- y eso se lee igual que un verde.
    n_lista = len(list(lista.values()))
    faltan = [c["mdl"] for c in lista.values()
              if c["mdl"] not in [r for r, _, _, _ in ESPERADO]]
    n_ajenos = len([1 for _, a, _, _ in ESPERADO if a is None])

    print("\n  %d comprobaciones, %d falla(s)." % (medidos, fallas))
    print("  ghost_models.lua declara %d modelos portados; esta tabla los cubre a los %d"
          % (n_lista, n_lista - len(faltan)))
    print("  y ademas %d modelos AJENOS, que son los que tienen que salir SIN hull."
          % n_ajenos)
    if faltan:
        fallas += 1
        print("  >> SIN CUBRIR: %s -- agregarlos a ESPERADO." % ", ".join(faltan))

    if args.romper:
        if fallas:
            print("\n>> CONTROL OK: con el defecto adentro el arnes se pone rojo.")
            return 0
        print("\n>> ⚠ EL CONTROL NO DISCRIMINA: el defecto esta puesto y todo dio verde.")
        return 1

    print("\n>> %s" % ("PASA" if fallas == 0 else "FALLA"))
    return 1 if fallas else 0


if __name__ == "__main__":
    sys.exit(main())
