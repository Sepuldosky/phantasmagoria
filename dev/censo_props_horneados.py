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

⚠ LAS REGLAS DE §FAMILIAS ESTAN TRANSCRITAS A MANO desde el Lua y pueden quedar
desfasadas: son una COPIA. El auto-control de abajo prueba que discriminan, no
que esten al dia. Si se toca `PROP_CONSUJETO`, se toca esto -- y la forma de
darse cuenta es que el conteo de familias aca no coincida con el del addon.
"""
import collections
import os
import struct
import sys

# ---------------------------------------------------------------------------
# Las reglas del addon. COPIA de PROP_CONSUJETO en server_events.lua.
# El "vehiculo" no entra: se reconoce por IsVehicle() y un prop_static nunca
# es un vehiculo.
# ---------------------------------------------------------------------------
FAMILIAS = {
    "radio": dict(
        exacto={"citizenradio", "radio_reference", "radionette01", "german_radio", "radio_box"},
        parte=["radio"],
        nunca=["radioprotector", "radio_diolator", "radio_p1",
               "_p1", "_p2", "_p3", "_p4", "_gib", "broken", "destroyed"]),
    "telefono": dict(
        exacto={"oldphone", "phone", "phone_motel"}, parte=["phone"],
        nunca=["myphone", "headphone", "microphone", "_p1", "_gib", "broken"]),
    "televisor": dict(
        exacto={"tv", "tvset", "tv_plasma"}, parte=["tv_", "_tv", "television"],
        nunca=["_p1", "_p2", "_p3", "_p4", "_gib", "broken", "destroyed"]),
    "piano":      dict(exacto=set(), parte=["piano"], nunca=["_gib", "broken"]),
    "guitarra":   dict(exacto=set(), parte=["guitar"], nunca=["_gib", "broken"]),
    "microondas": dict(exacto=set(), parte=["microwave"], nunca=[]),
    "inodoro":    dict(exacto=set(), parte=["toilet"], nunca=[]),
    "peluche":    dict(exacto=set(), parte=["teddy"], nunca=[]),
    "reloj":      dict(exacto=set(), parte=["clock"], nunca=["_p1", "_gib", "broken"]),
}


def basename_de(ruta):
    """El mismo basename que `basenameDe` del Lua: sin carpeta y sin .mdl."""
    n = ruta.replace("\\", "/").split("/")[-1]
    return n[:-4].lower() if n.lower().endswith(".mdl") else n.lower()


def coincide(nom, regla):
    """El mismo orden que `modeloCoincide`: primero `nunca`, despues `exacto`,
    despues `parte`. El orden IMPORTA -- `nunca` gana."""
    for mal in regla["nunca"]:
        if mal in nom:
            return False
    if nom in regla["exacto"]:
        return True
    return any(p in nom for p in regla["parte"])


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

    # AUTO-CONTROL de la transcripcion de reglas. Si esto no discrimina, el
    # reparto por familias de abajo no significa nada y no se imprime.
    controles = [
        (coincide("radionette01", FAMILIAS["radio"]), True, "radionette01 es radio"),
        (coincide("radioprotector", FAMILIAS["radio"]), False, "radioprotector NO"),
        (coincide("tv_plasma", FAMILIAS["televisor"]), True, "tv_plasma es tele"),
        (coincide("tv_plasma_p1", FAMILIAS["televisor"]), False, "tv_plasma_p1 es un pedazo"),
    ]
    malos = [t for got, want, t in controles if got != want]
    if malos:
        raise SystemExit("CONTROL de reglas FALLADO (%s): no se reporta nada"
                         % ", ".join(malos))
    print("CONTROL de las reglas      : %d/%d -> discriminan" % (len(controles), len(controles)))

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
