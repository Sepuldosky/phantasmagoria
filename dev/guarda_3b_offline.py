# -*- coding: utf-8 -*-
"""Corre **la guarda ( 3b ) de verdad**, fuera de GMod, sobre `PROP_CONSUJETO`.

QUE ES LA GUARDA 3b
-------------------
Vive al final de `server_events.lua` y compara, para cada familia `entero`, la
lista `sonidos` contra la tabla `dur`, **en las dos direcciones**:

  · un clip en `sonidos` SIN duracion cae en la tanda fija de `EMISOR_VIDA` y el
    emisor lo **decapita a los 20 s** -- sin tirar un solo error: se oye una
    radio que se corta, que es lo que se oia antes de arreglarlo;
  · una duracion HUERFANA ( medida para un clip que ya no esta en la lista ) es
    una nota mentirosa esperando lector.

POR QUE ESTE SCRIPT
-------------------
La guarda ya existe y grita al cargar el addon **en el juego**. Eso la vuelve un
control caro: hay que levantar GMod para saber si una edicion de la tabla quedo
coherente. Este script la corre **sin el motor**, en un Lua real ( `lupa` ), para
que editar `PROP_CONSUJETO` deje de necesitar una partida.

⚠⚠ NO REIMPLEMENTA LA GUARDA: la **recorta del `.lua` y la ejecuta**. Un control
que reimplementa lo que audita solo demuestra que las dos copias estan de
acuerdo -- y el dia que alguien toque la guarda de verdad, esta seguiria dando
verde sobre codigo que ya no corre. Por eso se saca del archivo, con marcas, y
si las marcas no estan el script **muere ruidoso** en vez de medir un vacio.

EL AUTO-CONTROL, Y ES LO QUE LO VUELVE CITABLE
----------------------------------------------
Una guarda que no grita puede estar callada por dos motivos: porque la tabla
esta bien, o porque **no corrio**. Los dos se ven igual. Asi que despues de la
pasada limpia se corren DOS casos rotos a proposito -- sacar un clip de
`sonidos` dejando su `dur`, y sacar su `dur` dejando el clip -- y la guarda
tiene que gritar en los dos, cada uno por su lado. *Una perilla que nadie puede
mover no es un control.*

USO
    python dev/guarda_3b_offline.py
"""
import os
import re
import sys

try:
    import lupa
except ImportError:
    print("! falta lupa:  pip install lupa")
    sys.exit(2)

AQUI = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(AQUI)
LUA = os.path.join(ADDON, "lua", "entities", "terminator_nextbot_phantom", "server_events.lua")

TABLA_INI = "local PROP_CONSUJETO = {"
GUARDA_MARCA = "-- ( 3b ) LAS FAMILIAS `entero` TIENEN QUE TENER MEDIDO CADA CLIP"


def leer():
    with open(LUA, encoding="utf-8") as f:
        return f.read()


def recorte(src, arranque, etiqueta, linea_entera=False):
    """Del `arranque` hasta la primera linea que sea exactamente `}` o `end`.

    Los dos bloques de interes son de nivel superior, asi que su cierre esta en la
    columna 0 y ninguna linea interna puede confundirse con el.

    ⚠ `linea_entera` NO es un lujo: buscar el `do` del bloque como SUBSTRING lo
    encuentra adentro de la primera palabra que lo contenga -- `medido`,
    `cuando`, `direcciones` -- y el recorte arranca en la mitad de un comentario.
    Eso ya paso escribiendo este script, y el sintoma fue un error de sintaxis de
    Lua que parecia del addon y era del lector.
    """
    if linea_entera:
        m = re.search(r"^%s\s*$" % re.escape(arranque), src, re.MULTILINE)
        i = m.start() if m else -1
    else:
        i = src.find(arranque)

    if i < 0:
        raise SystemExit(
            "!! no se encontro la marca de %s en el .lua. El script muere en vez de\n"
            "   medir un universo vacio: un recorte que sale vacio se ejecuta sin error\n"
            "   y la guarda 'no grita' porque no habia nada que mirar." % etiqueta)

    resto = src[i:]
    for m in re.finditer(r"^(\}|end)\s*$", resto, re.MULTILINE):
        return resto[: m.end()]

    raise SystemExit("!! no se encontro el cierre de %s." % etiqueta)


def correr(tabla_src, guarda_src):
    """Ejecuta tabla + guarda en un Lua real. Devuelve la lista de gritos."""
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    gritos = []

    g = lua.globals()
    g.ErrorNoHalt = lambda s: gritos.append(str(s).strip())
    g.EMISOR_VIDA = 20

    lua.execute(tabla_src + "\n" + guarda_src + "\n")
    return gritos


def partir(msg):
    """{ 'faltan': ..., 'sobran': ... } -- los dos lados del mensaje de la guarda.

    El `ErrorNoHalt` de la guarda tiene la forma
        ... SIN DURACION ( ... ): <faltan>   ·   HUERFANAS ( ... ): <sobran>
    y nombra las DOS categorias aunque una este vacia. Partirlo es lo que
    permite preguntar *de que lado* cayo el clip, en vez de si la palabra aparece.
    """
    if "SIN DURACION" not in msg or "HUERFANAS" not in msg:
        return {}

    resto = msg.split("SIN DURACION", 1)[1]
    izq, der = resto.split("HUERFANAS", 1)

    # se corta el `( ... )` explicativo de cada lado, que es prosa fija
    izq = izq.split("):", 1)[1] if "):" in izq else izq
    der = der.split("):", 1)[1] if "):" in der else der

    return {"faltan": izq.split("·")[0], "sobran": der}


def otro(lado):
    return "sobran" if lado == "faltan" else "faltan"


def resumen(texto, clip):
    t = " ".join(texto.split())
    if clip in t:
        return "NOMBRA el clip  -> %s" % (t[:80] + ("..." if len(t) > 80 else ""))
    return "vacio  -> %s" % (t[:60] or "( nada )")


def main():
    src = leer()
    tabla = recorte(src, TABLA_INI, "PROP_CONSUJETO")

    i = src.index(GUARDA_MARCA) if GUARDA_MARCA in src else -1
    if i < 0:
        raise SystemExit("!! no se encontro la guarda ( 3b ) en el .lua.")
    guarda = recorte(src[i:], "do", "la guarda ( 3b )", linea_entera=True)

    print("RECORTE ( el denominador del lector, no del sujeto ):")
    print("  PROP_CONSUJETO   %d lineas" % tabla.count("\n"))
    print("  guarda ( 3b )    %d lineas" % guarda.count("\n"))
    print("")

    # ------------------------------------------------------- la pasada de verdad
    gritos = correr(tabla, guarda)
    print("PASADA REAL sobre la tabla como esta hoy:")
    if gritos:
        for s in gritos:
            print("  !! GRITA: %s" % s)
    else:
        print("  callada.")
    print("")

    # ------------------------------------------------------- los dos negativos
    # Se rompe la tabla A PROPOSITO, de una sola de las dos direcciones cada vez.
    # El sujeto es `phone_ring`, que desde 2026-08-17 es el UNICO clip de la
    # familia telefono -- o sea el caso mas chico posible, que es donde una
    # guarda mal escrita se cuelga.
    CLIP = "phantasmagoria/prop/phone_ring.ogg"

    negativos = [
        ("sacar el clip de `sonidos` dejando su `dur`",
         '            "phantasmagoria/prop/phone_ring.ogg",\n',
         "sobran"),
        ("sacar su `dur` dejando el clip en `sonidos`",
         '            [ "phantasmagoria/prop/phone_ring.ogg" ] = 3.46,\n',
         "faltan"),
    ]

    print("CONTROL NEGATIVO ( la perilla se mueve, si no no es un control ):")
    fallas = 0

    for que, linea, lado_esperado in negativos:
        if tabla.count(linea) != 1:
            print("  !! %-46s la linea a sacar aparece %d vez/veces, no 1"
                  % (que, tabla.count(linea)))
            fallas += 1
            continue

        g2 = correr(tabla.replace(linea, ""), guarda)
        junto = " ".join(g2)

        # ⚠⚠ EL CRITERIO NO PUEDE SER *"el mensaje dice HUERFANAS"*. El texto del
        # `ErrorNoHalt` nombra **las dos** categorias SIEMPRE -- lleva
        # `SIN DURACION ( ... ): ninguno   ·   HUERFANAS ( ... ): ninguna` --, asi
        # que buscar la etiqueta da verde en la rama equivocada. Esa version de
        # este script existio y aprobo los dos casos leyendo la misma palabra:
        # el veredicto era correcto y el criterio no lo probaba.
        #
        # El discriminante de verdad es **de que lado del `·` aparece el clip**.
        lados = partir(junto)
        ok = (lados.get(lado_esperado, "").find(CLIP) >= 0
              and lados.get(otro(lado_esperado), "").find(CLIP) < 0)

        print("  %-9s %-46s" % ("DETECTA" if ok else "!! NO VE", que))
        print("            sin duracion: %s" % resumen(lados.get("faltan", ""), CLIP))
        print("            huerfanas   : %s" % resumen(lados.get("sobran", ""), CLIP))

        if not ok:
            fallas += 1

    print("")

    if fallas:
        print("!! el auto-control fallo en %d de %d caso(s): la guarda NO discrimina,"
              % (fallas, len(negativos)))
        print("   asi que su silencio de arriba no significa nada.")
        return 2

    print("AUTO-CONTROL: la guarda grita en los %d casos rotos y en ninguno mas."
          % len(negativos))

    if gritos:
        print("VEREDICTO: la tabla de hoy tiene un problema ( ver el grito de arriba ).")
        return 1

    print("VEREDICTO: `PROP_CONSUJETO` coherente -- la guarda ( 3b ) no grita, y se")
    print("           comprobo que SI grita cuando tiene que hacerlo.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
