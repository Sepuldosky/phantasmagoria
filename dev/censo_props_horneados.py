# -*- coding: utf-8 -*-
"""Censo de los `prop_static` (props HORNEADOS) de un mapa, y que reclamarian
sobre ellos las familias de sonido del addon.

POR QUE EXISTE COMO ARCHIVO Y NO COMO UN SCRIPT DE UNA SESION: la primera
version de este censo se corrio el 2026-08-10 en un scratchpad y se perdio. Sus
numeros quedaron citados en ESTADO.md como prosa ("9 modelos y 11 instancias:
3 radios, 2 parlantes, 2 despertadores, 2 relojes, 1 telefono") y **no
reproducen**: contaban una familia -- los parlantes -- que el addon NO tiene, y
se perdian los inodoros, que si tiene. *Un censo cuyo instrumento no sobrevive
no se puede auditar, y lo que queda de el es una frase que nadie puede refutar.*

QUE MIDE, en dos pasadas que no hay que confundir:

  1. EL MAPA. Cuantos `prop_static` hay y de que modelos. Se lee el game lump
     `sprp` del `.bsp`, que es donde el compilador hornea los props estaticos:
     en runtime NO son entidades ( `ents.FindByClass( "prop_static" )` devuelve
     una lista vacia ) y por eso no se pueden contar desde Lua.

  2. QUE RECLAMARIA EL ADDON. Las reglas de `PROP_CONSUJETO`
     ( server_events.lua ) corridas sobre esos modelos. Esta es la pasada que
     decide el bloque: no alcanza con "hay 1588 props", hay que saber cuantos
     de esos el evento llamaria radio, telefono o inodoro -- **y cuantos
     llamaria mal**.

USO:
    python dev/censo_props_horneados.py <ruta al .bsp o al .gma que lo contiene>

⚠⚠ LAS REGLAS **NO SE TRANSCRIBEN**: se recortan del `.lua` y se ejecutan en un Lua
real ( `lupa` ), igual que `guarda_3b_offline.py`. Antes eran una COPIA a mano, y
la copia se desfaso. Este archivo lo pago, y esta es la factura ( 2026-08-18 ):

    los tres vetos del 2026-08-16 ( `radio_antenna`, `phone_book`, `toiletpaper` )
    entraron en `PROP_CONSUJETO` y NO entraron aca. Sobre gm_uh_house este censo
    siguio reclamando `props_radiostation/radio_antenna01_skybox` como *una radio*
    -- la ANTENA del skybox 3D -- y dio **11 modelos / 13 instancias** donde el
    addon corriendo de verdad da **10 / 12**. Ese 11/13 llego a citarse en el
    HANDOFF del bloque y en el CHANGELOG ( 44 ) como si fuera lo que el addon hace.

Y el auto-control de abajo **no podia verlo**: probaba que las reglas DISCRIMINAN,
que es una propiedad que una copia vieja conserva intacta. *Un control que audita
al instrumento contra si mismo no puede descubrir que el instrumento quedo viejo.*
Por eso ahora no hay copia que auditar, y el control tiene una segunda mitad que
sale roja si la tabla que se cargo no es la de hoy."""
import collections
import io
import os
import re
import struct
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(AQUI)

# ---------------------------------------------------------------------------
# Las reglas del addon -- RECORTADAS DEL .lua Y EJECUTADAS, no transcritas
# ---------------------------------------------------------------------------
# NO SE REIMPLEMENTA NADA. Se sacan del arbol tres cosas y se corren en un Lua
# real: la tabla `PROP_CONSUJETO` ( server_events.lua ) y las dos funciones que
# deciden, `BasenameDeRuta` y `NombreCoincide` ( bsp_statics.lua ). Dos copias
# de acuerdo entre si no prueban nada del codigo que corre -- y este archivo es
# justo el que lo pago: ver el aviso del encabezado.
#
# SI LAS MARCAS NO ESTAN, EL SCRIPT MUERE. Un recorte que sale vacio se ejecuta
# sin error y reparte cero props en cero familias, que es exactamente el aspecto
# de un mapa sin radios.
LUA_EVENTS = os.path.join(ADDON, "lua", "entities", "terminator_nextbot_phantom",
                          "server_events.lua")
LUA_BSP = os.path.join(ADDON, "lua", "phantasmagoria", "bsp_statics.lua")


def _recorte(src, arranque, etiqueta):
    """Del `arranque` hasta la primera linea que sea exactamente `}` o `end`.

    Los tres bloques son de nivel superior, asi que su cierre esta en la columna
    0 y ninguna linea interna puede confundirse con el. Es el mismo lector que
    usa `guarda_3b_offline.py`.
    """
    i = src.find(arranque)
    if i < 0:
        raise SystemExit(
            "!! no se encontro la marca de %s en el .lua.\n"
            "   El script muere en vez de repartir sobre una tabla vacia: un\n"
            "   censo sin reglas dice 'ninguno' en todas las familias, y eso se\n"
            "   lee igual que un mapa sin radios." % etiqueta)

    resto = src[i:]
    for m in re.finditer(r"^(\}|end)\s*$", resto, re.MULTILINE):
        return resto[: m.end()]

    raise SystemExit("!! no se encontro el cierre de %s." % etiqueta)


def cargar_reglas():
    """Devuelve ( familias, coincide, basename_de ) sacados del addon de verdad.

    `familias` es { "una radio": <tabla lua de `modelo`> }, y solo trae las que
    declaran `modelo`: las que se reconocen por `sujeto` ( el vehiculo ) no
    aplican a un `prop_static` y quedan afuera **con su motivo impreso**, no por
    olvido -- un cero sin explicar se lee como una familia que no reclamo nada.
    """
    try:
        import lupa
    except ImportError:
        raise SystemExit(
            "! falta lupa:  pip install lupa\n"
            "  NO hay camino de respaldo, a proposito. El respaldo seria volver a\n"
            "  transcribir las reglas a mano, que es el defecto que este bloque cerro.")

    ev = io.open(LUA_EVENTS, encoding="utf-8").read()
    bs = io.open(LUA_BSP, encoding="utf-8").read()

    tabla = _recorte(ev, "local PROP_CONSUJETO = {", "PROP_CONSUJETO")
    f_base = _recorte(bs, "function PHANTASMAGORIA.BasenameDeRuta( ruta )", "BasenameDeRuta")
    f_coin = _recorte(bs, "function PHANTASMAGORIA.NombreCoincide( nom, regla )", "NombreCoincide")

    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.PHANTASMAGORIA = lua.table()

    # Los predicados de GMod que usan las dos funciones. Se dan DE VERDAD y no
    # como `return true`: `NombreCoincide` los usa para RECHAZAR, asi que un stub
    # complaciente le sacaria una de sus salidas y el control negativo de abajo
    # pasaria a medir otra cosa.
    tipo = lua.eval("function(t) return function(v) return type(v) == t end end")
    g.isstring = tipo("string")
    g.istable = tipo("table")
    g.isfunction = tipo("function")

    lua.execute(f_base + "\n" + f_coin + "\n" + tabla + "\n_CENSO_TABLA = PROP_CONSUJETO\n")

    ph = g.PHANTASMAGORIA
    familias, sin_modelo = {}, []

    for fam in g._CENSO_TABLA.values():
        if fam["modelo"] is not None:
            familias[fam["que"]] = fam["modelo"]
        else:
            sin_modelo.append(fam["que"])

    if not familias:
        raise SystemExit("!! el recorte cargo 0 familias con `modelo`: no se reporta nada")

    print("reglas                     : leidas del .lua ( no transcritas ) -- "
          "%d familia(s) con `modelo`" % len(familias))
    if sin_modelo:
        print("  fuera por no declarar `modelo` ( se reconocen por `sujeto`, y un "
              "prop_static no es\n  una entidad ): %s" % ", ".join(sin_modelo))

    return familias, ph.NombreCoincide, ph.BasenameDeRuta


# ---------------------------------------------------------------------------
# .gma  ( el mapa del autor no esta suelto en maps/: viaja dentro del .gma del
#         Workshop, asi que hay que parsear su indice para encontrar el .bsp )
# ---------------------------------------------------------------------------
def bsp_desde_gma(path):
    f = open(path, "rb")
    if f.read(4) != b"GMAD":
        raise SystemExit("no es un .gma: %s" % path)
    ver = ord(f.read(1))
    f.read(8)   # steamid
    f.read(8)   # timestamp
    if ver > 1:
        while f.read(1) not in (b"\x00", b""):
            pass

    def cstr():
        out = bytearray()
        while True:
            c = f.read(1)
            if c in (b"\x00", b""):
                return out.decode("utf-8", "replace")
            out += c

    cstr(); cstr(); cstr()      # nombre, descripcion, autor
    f.read(4)                   # version del addon
    idx = []
    while True:
        num = struct.unpack("<I", f.read(4))[0]
        if num == 0:
            break
        nombre = cstr()
        size = struct.unpack("<q", f.read(8))[0]
        f.read(4)               # crc
        idx.append((nombre, size))

    base, off, tabla = f.tell(), 0, {}
    for nombre, size in idx:
        tabla[nombre] = (base + off, size)
        off += size

    bsps = [n for n in tabla if n.lower().endswith(".bsp")]
    print("archivos en el .gma        : %d" % len(tabla))
    print("mapas .bsp adentro         : %d   %s" % (len(bsps), bsps))
    if len(bsps) != 1:
        raise SystemExit("hay %d bsp adentro: pasar el .bsp directo" % len(bsps))
    off, size = tabla[bsps[0]]
    f.seek(off)
    return bsps[0], f.read(size)


# ---------------------------------------------------------------------------
# .bsp -> game lump `sprp`
# ---------------------------------------------------------------------------
def censo_sprp(bsp):
    if bsp[:4] != b"VBSP":
        raise SystemExit("no es un VBSP")
    print("version del bsp            : %d" % struct.unpack_from("<i", bsp, 4)[0])

    lumps = [struct.unpack_from("<iiii", bsp, 8 + i * 16) for i in range(64)]
    go = lumps[35][0]                                   # LUMP_GAME_LUMP
    n = struct.unpack_from("<i", bsp, go)[0]
    sprp = None
    for i in range(n):
        gid, _flags, ver, fo, fl = struct.unpack_from("<IHHii", bsp, go + 4 + i * 16)
        if gid == 0x73707270:                           # 'sprp'
            sprp = (ver, fo, fl)
    print("game lumps                 : %d" % n)
    if not sprp:
        raise SystemExit("este mapa no tiene lump sprp: cero props horneados")
    ver, fo, fl = sprp
    print("sprp version               : %d   ( offset %d, len %d )" % (ver, fo, fl))

    # ⚠⚠ EL LUMP PUEDE VENIR COMPRIMIDO, Y ESTE SCRIPT SE COLGABA CON ESO.
    # Medido el 2026-08-18 en `gm_uh_house`: el `sprp` arranca con la firma
    # `LZMA`, y leer esos cuatro bytes como entero da **1095588428**. El `for _
    # in range(ndict)` de abajo se ponia a llenar una lista de mil noventa y
    # cinco millones de entradas: no reventaba, **se colgaba**.
    #
    # ⚠ Y ESA ES LA PARTE QUE HAY QUE MIRAR. El gemelo en Lua, con el MISMO
    # numero, tiro `table overflow` en el acto. Un crash se ve; un cuelgue se
    # lee como *"todavia esta trabajando"*, o sea que el mismo defecto es peor
    # aca. *La cara que pone una falla depende del lenguaje, no de su gravedad.*
    s = bsp[fo:fo + fl]

    if s[:4] == b"LZMA":
        # Cabecera de lump comprimido de Source: 'LZMA' + descomprimido (u32) +
        # comprimido (u32) + 5 bytes de propiedades LZMA1, y despues el stream.
        # ⚠ En un lump comprimido el `filelen` de la tabla de game lumps trae el
        # tamano DESCOMPRIMIDO, asi que el slice de arriba se pasa de largo y hay
        # que quedarse con `comp` bytes contados desde el byte 17.
        import lzma
        real, comp = struct.unpack_from("<II", s, 4)
        print("sprp COMPRIMIDO            : %d -> %d bytes ( LZMA )" % (comp, real))
        crudo = s[12:17] + struct.pack("<Q", real) + s[17:17 + comp]
        try:
            s = lzma.LZMADecompressor(format=lzma.FORMAT_ALONE).decompress(crudo)
        except Exception as e:
            raise SystemExit("el sprp esta comprimido y no se pudo abrir: %s" % e)
        if len(s) != real:
            raise SystemExit("descomprimio %d bytes y la cabecera declara %d: no es el lump"
                             % (len(s), real))

    def cuenta_valida(n, quedan, porcada):
        """⚠ LAS DOS MITADES. La guarda original miraba `n < 0` y nada mas, asi
        que un numero absurdamente GRANDE pasaba entero. El techo no es una
        constante inventada: es el tramo que se tiene en la mano dividido por lo
        que ocupa cada entrada."""
        return 0 <= n <= (quedan // porcada)

    p = 0
    ndict = struct.unpack_from("<i", s, p)[0]; p += 4
    if not cuenta_valida(ndict, len(s) - 4, 128):
        raise SystemExit("dictEntries = %d y en los %d bytes del sprp entran como mucho %d "
                         "rutas de 128 -> eso no es una cantidad, es basura con forma de numero"
                         % (ndict, len(s), (len(s) - 4) // 128))

    modelos = []
    for _ in range(ndict):
        modelos.append(s[p:p + 128].split(b"\x00")[0].decode("ascii", "replace").lower())
        p += 128

    nleaf = struct.unpack_from("<i", s, p)[0]; p += 4
    if not cuenta_valida(nleaf, len(s) - p, 2):
        raise SystemExit("leafEntries = %d y quedan %d bytes -> la lectura no esta donde deberia"
                         % (nleaf, len(s) - p))
    p += nleaf * 2

    nprops = struct.unpack_from("<i", s, p)[0]; p += 4
    if not cuenta_valida(nprops, len(s) - p, 26):
        raise SystemExit("entryCount = %d y quedan %d bytes, o sea como mucho %d entradas de 26 "
                         "-> la lectura no esta donde deberia"
                         % (nprops, len(s) - p, (len(s) - p) // 26))

    # EL PASO SE CALCULA, NO SE ASUME. StaticPropLump_t cambia de tamano con la
    # version del lump ( 56 en v4, 72 en v10, ... ) y hay mapas con versiones
    # intermedias. Lo que NO cambia entre v4 y v11 es el arranque de la
    # estructura: Origin (12) + Angles (12), o sea que PropType vive en +24.
    resto = len(s) - p
    paso = resto // nprops if nprops else 0
    print("modelos distintos ( dict ) : %d" % ndict)
    print("instancias prop_static     : %d" % nprops)
    print("bytes por entrada          : %d   ( %d de resto, %d sobrantes )"
          % (paso, resto, resto - paso * nprops))

    cuenta = collections.Counter()
    for i in range(nprops):
        t = struct.unpack_from("<H", s, p + i * paso + 24)[0]
        # AUTO-CONTROL: un indice fuera del diccionario significa que la lectura
        # se desalineo, y a partir de ahi todo lo que se cuente es ruido con
        # forma de dato. Se aborta en vez de reportar.
        if not (0 <= t < ndict):
            raise SystemExit("indice de modelo %d fuera del dict en la entrada %d "
                             "-> LECTURA DESALINEADA, el censo no vale" % (t, i))
        cuenta[modelos[t]] += 1
    if sum(cuenta.values()) != nprops:
        raise SystemExit("las instancias no suman: %d contra %d"
                         % (sum(cuenta.values()), nprops))
    print("CONTROL: los indices caen dentro del dict y las instancias suman "
          "-> lectura alineada")
    return cuenta, ndict, nprops


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    ruta = sys.argv[1]
    if not os.path.exists(ruta):
        raise SystemExit("no existe: %s" % ruta)

    if ruta.lower().endswith(".gma"):
        nombre, bsp = bsp_desde_gma(ruta)
    else:
        nombre, bsp = os.path.basename(ruta), open(ruta, "rb").read()
    print("bsp                        : %s   %d bytes" % (nombre, len(bsp)))

    cuenta, ndict, nprops = censo_sprp(bsp)

    FAMILIAS, coincide, basename_de = cargar_reglas()

    # AUTO-CONTROL de las reglas. DOS MITADES, y la segunda es la que faltaba.
    #
    #   DISCRIMINAN    que digan que si a un caso y que no a otro. Esto ya
    #                  estaba, y es lo que dio verde mientras las reglas
    #                  envejecian: discriminar es una propiedad que una copia
    #                  vieja conserva intacta.
    #   ESTAN AL DIA   los tres vetos del 2026-08-16, uno por uno. Estos SI se
    #                  rompen si el recorte trajo una tabla vieja, y son lo unico
    #                  que sale rojo si alguien apunta el script a otra copia del
    #                  addon. Cada uno nombra su familia por el `que` del Lua,
    #                  asi que renombrar una familia tampoco pasa en silencio.
    controles = [
        (coincide("radionette01", FAMILIAS["una radio"]), True, "radionette01 es radio"),
        (coincide("radioprotector", FAMILIAS["una radio"]), False, "radioprotector NO"),
        (coincide("tv_plasma", FAMILIAS["un televisor"]), True, "tv_plasma es tele"),
        (coincide("tv_plasma_p1", FAMILIAS["un televisor"]), False, "tv_plasma_p1 es un pedazo"),
        (coincide("radio_antenna01_skybox", FAMILIAS["una radio"]), False,
         "radio_antenna01_skybox es la ANTENA del skybox ( veto 2026-08-16 )"),
        (coincide("phone_book", FAMILIAS["un telefono"]), False,
         "phone_book es una GUIA telefonica ( veto 2026-08-16 )"),
        (coincide("toiletpaperroll", FAMILIAS["un inodoro"]), False,
         "toiletpaperroll es PAPEL ( veto 2026-08-16 )"),
    ]
    malos = [t for got, want, t in controles if bool(got) != want]
    if malos:
        raise SystemExit("CONTROL de reglas FALLADO (%s): no se reporta nada"
                         % ", ".join(malos))
    print("CONTROL de las reglas      : %d/%d -> discriminan Y estan al dia "
          "( los 3 vetos del 2026-08-16 entre ellos )" % (len(controles), len(controles)))

    print("\n" + "=" * 74)
    print("LO QUE LAS FAMILIAS DEL ADDON RECLAMARIAN SOBRE ESTOS prop_static")
    print("=" * 74)
    tm = ti = 0
    for fam in sorted(FAMILIAS):
        hits = sorted((m, c) for m, c in cuenta.items()
                      if coincide(basename_de(m), FAMILIAS[fam]))
        if not hits:
            print("  %-11s  --  ninguno" % fam)
            continue
        print("  %-11s  %d modelo(s) / %d instancia(s)"
              % (fam, len(hits), sum(c for _, c in hits)))
        for m, c in hits:
            print("        x%-3d %s" % (c, m))
        tm += len(hits)
        ti += sum(c for _, c in hits)
    print("\nTOTAL RECLAMADO: %d modelos / %d instancias   de %d / %d"
          % (tm, ti, ndict, nprops))

    # Un modelo reclamado por dos familias suena a dos cosas distintas segun que
    # sorteo salga. No es fatal, pero tiene que ser una decision.
    doble = collections.defaultdict(list)
    for fam in FAMILIAS:
        for m in cuenta:
            if coincide(basename_de(m), FAMILIAS[fam]):
                doble[m].append(fam)
    d = {m: f for m, f in doble.items() if len(f) > 1}
    print("Modelos reclamados por MAS DE UNA familia: %d   %s" % (len(d), d or ""))

    print("\nLOS 15 MODELOS MAS INSTANCIADOS ( para saber que clase de mapa es ):")
    for m, c in cuenta.most_common(15):
        print("   x%-4d %s" % (c, m))


if __name__ == "__main__":
    main()
