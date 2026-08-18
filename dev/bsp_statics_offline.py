# -*- coding: utf-8 -*-
"""Corre **el parser de `.bsp` del addon**, tal cual, sobre un mapa del disco.

POR QUE EXISTE
--------------
`lua/phantasmagoria/bsp_statics.lua` lee el game lump `sprp` a mano. Hasta el
2026-08-18 la unica forma de saber si sobrevivia a un mapa nuevo era **cargar
GMod y disparar el evento**, y cuando no sobrevivio el sintoma no se parecio a la
causa: en `gm_uh_house` tiro `table overflow` que subio por `EstaticosEnEsfera`
-> `EV.prop` -> `phantom_FireEvent` -> el concommand, o sea **nueve marcos de
pila que apuntan al consumidor** y dejan el evento `prop` inservible en cada
disparo.

⚠⚠ NO REIMPLEMENTA EL PARSER: **carga el `.lua` y lo ejecuta** en un Lua real
(`lupa`), con `file.Open` / `game.GetMap` / `Vector` / `Angle` apuntando a un
`.bsp` de verdad. Un arnes que reimplementa lo que audita solo demuestra que las
dos copias estan de acuerdo — y el dia que alguien toque el parser, seguiria
dando verde sobre codigo que ya no corre. Es la misma decision que
`dev/guarda_3b_offline.py`.

EL AUTO-CONTROL
---------------
`gm_funkis_night` esta medido por un instrumento independiente
(`dev/censo_props_horneados.py`): **418 modelos en 1588 instancias**. Si el mapa
de control entra en la corrida y no reproduce esos numeros, el arnes **no publica
nada**: un lector recien escrito imprime numeros plausibles sobre cualquier cosa.
Y si el mapa de control NO entra, dice `PARCIAL` en vez de `OK` — misma regla que
`dev/duracion_ogg.py`.

⚠ UN MAPA QUE FALLA NO ES UN ROJO DEL ARNES. El parser tiene que poder decir
`ok = false` con un `error` legible sobre un mapa que no sabe leer; lo que seria
un rojo es que **tire** en vez de contestar. Por eso el arnes distingue las tres
salidas: `ok`, `ok = false` con motivo, y **error de Lua**.

USO
    python dev/bsp_statics_offline.py <ruta.bsp> [ mas.bsp ... ]
    python dev/bsp_statics_offline.py --todos <carpeta con .bsp>
"""
import os
import sys

try:
    import lupa
except ImportError:
    print("! falta lupa:  pip install lupa")
    sys.exit(2)

AQUI = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(AQUI)
BSPLUA = os.path.join(ADDON, "lua", "phantasmagoria", "bsp_statics.lua")

# Medido por `dev/censo_props_horneados.py`, que es un instrumento distinto.
# Es el CONTROL, no el resultado.
CONTROL = {"gm_funkis_night": (418, 1588)}

PRELUDIO = """
PHANTASMAGORIA = {}
function Vector( x, y, z ) return { x = x, y = y, z = z } end
function Angle( p, y, r ) return { p = p, y = y, r = r } end
function isstring( v ) return type( v ) == "string" end
function istable( v )  return type( v ) == "table"  end
"""


def _descomprimir_alone(datos):
    """El `util.Decompress` de banco: LZMA1 con cabecera 'alone'.

    ⚠⚠ ESTO NO PRUEBA QUE `util.Decompress` DE GMod ACEPTE LA MISMA CABECERA.
    Prueba lo otro, que es lo que se puede probar sin el juego: que los bytes que
    el `.lua` arma **son** un stream LZMA1 valido y que lo que sale de ahi parsea
    como un `sprp`. La API del motor es un tercero y queda medida en juego.
    """
    import lzma
    try:
        return lzma.LZMADecompressor(format=lzma.FORMAT_ALONE).decompress(bytes(datos))
    except Exception:
        return None


def entorno(lua, ruta_bsp, decompresor=None):
    """Deja `file.Open`, `game.GetMap` y `util.Decompress` apuntando a lo real."""
    datos = open(ruta_bsp, "rb").read()
    mapa = os.path.splitext(os.path.basename(ruta_bsp))[0]
    estado = {"pos": 0}

    def _seek(_self, n):
        estado["pos"] = int(n)

    def _read(_self, n):
        i = estado["pos"]
        n = int(n)
        # Se replica el limite de un handle real: leer de mas devuelve lo que hay.
        # Devolver mas de lo que existe convertiria al arnes en mas permisivo que
        # el juego, que es la direccion que produce falsos verdes.
        if n < 0 or i < 0 or i > len(datos):
            return None
        trozo = datos[i:i + n]
        estado["pos"] = i + len(trozo)
        return trozo

    def _size(_self):
        return len(datos)

    def _close(_self):
        return None

    # ⚠ Con `encoding=None` las CLAVES de la tabla también viajan en bytes: una
    # clave `str` entra como otra cosa y el campo queda `nil`, que del lado de
    # Lua se ve como «la API no existe» y no como «el arnés la pasó mal».
    handle = lua.table_from({b"Seek": _seek, b"Read": _read,
                             b"Size": _size, b"Close": _close})

    def _open(_ruta, _modo, _path):
        # El parser pide `maps/<mapa>.bsp`; el arnes sirve el archivo que le
        # dieron y NO comprueba el nombre, porque el sujeto es el .bsp y no la
        # ruta virtual de GMod.
        estado["pos"] = 0
        return handle

    g = lua.globals()
    g.file = lua.table_from({b"Open": _open})
    g.game = lua.table_from({b"GetMap": lambda: mapa.encode("utf-8")})
    g.util = lua.table_from({b"Decompress": decompresor or _descomprimir_alone})
    return mapa


def medir(ruta_bsp, decompresor=None):
    """( estado, dict ) con estado en {'ok', 'sin_ok', 'error_lua'}."""
    # ⚠⚠ `encoding=None` NO ES UN DETALLE: sin el, lupa intenta decodificar como
    # UTF-8 cada string de Lua que cruza a Python -- y acá las strings de Lua son
    # los BYTES CRUDOS del .bsp. La primera versión reventó con
    # `'utf-8' codec can't decode byte 0xfe`, y lo peor no fue el error: fue que
    # el `pcall` del propio addon lo atajó y lo reportó como `ok = false` **del
    # mapa**. Un defecto del instrumento disfrazado de hallazgo sobre el sujeto.
    lua = lupa.LuaRuntime(unpack_returned_tuples=True, encoding=None)
    lua.execute(PRELUDIO)
    mapa = entorno(lua, ruta_bsp, decompresor)

    try:
        lua.execute(open(BSPLUA, encoding="utf-8").read())
    except Exception as e:
        return "error_lua", {"mapa": mapa, "detalle": "al cargar el .lua: %s" % e}

    try:
        d = lua.globals()[b"PHANTASMAGORIA"][b"Estaticos"]()
    except Exception as e:
        # ⚠ Esto SI seria un rojo del addon: `Estaticos()` promete devolver la
        # tabla siempre. Que llegue una excepcion hasta aca es el defecto del
        # 2026-08-18 sin atajar.
        return "error_lua", {"mapa": mapa, "detalle": str(e)}

    campos = {"mapa": mapa}
    for k in ("ok", "error", "version", "bytes", "gamelumps", "sprp_version",
              "comprimido", "n_modelos", "n_props", "paso", "sobrantes"):
        v = d[k.encode("utf-8")]
        campos[k] = v.decode("utf-8", "replace") if isinstance(v, bytes) else v

    return ("ok" if campos["ok"] else "sin_ok"), campos


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2

    if args[0] == "--todos":
        if len(args) < 2 or not os.path.isdir(args[1]):
            print("!! --todos necesita una carpeta")
            return 2
        rutas = sorted(os.path.join(args[1], f) for f in os.listdir(args[1])
                       if f.lower().endswith(".bsp"))
    else:
        rutas = args

    rutas = [r for r in rutas if os.path.isfile(r)]
    if not rutas:
        print("!! 0 archivos .bsp -- un cero SIN LEER no es una medicion")
        return 2

    print("DENOMINADOR: %d mapa(s) .bsp" % len(rutas))
    print("")

    fallas, controlados = 0, []

    for r in rutas:
        estado, d = medir(r)
        mapa = d["mapa"]
        print("%s   ( %.1f MB )" % (mapa, os.path.getsize(r) / 1048576.0))

        if estado == "error_lua":
            print("   !! ERROR DE LUA -- el parser TIRO en vez de contestar `ok = false`.")
            print("      %s" % d["detalle"])
            fallas += 1
            print("")
            continue

        if estado == "sin_ok":
            # ⚠ HAY DOS `ok = false` Y NO SE PUEDEN LEER IGUAL. Uno es el parser
            # diciendo, con conocimiento de causa, que no sabe leer este mapa. El
            # otro es el `pcall` de `Estaticos()` atajando un error de Lua que
            # nadie previó — y ése no es una propiedad del mapa, es un defecto
            # del parser o del arnés. Ya pasó: el arnés decodificaba el .bsp como
            # UTF-8 y su propia excepción salió impresa como motivo del mapa.
            if "tiro un error de Lua" in (d["error"] or ""):
                print("   !! ok = false POR UN ERROR DE LUA ATAJADO -- esto no es del mapa,")
                print("      es del parser o de este arnés:")
                print("      %s" % d["error"])
                fallas += 1
            else:
                print("   ok = false ( contestó en vez de tirar, que es lo que se le pide )")
                print("   motivo: %s" % d["error"])
            print("")
            continue

        print("   ok · vbsp %s · game lumps %s · sprp v%s%s · %s modelos / %s props · "
              "paso %s · sobrantes %s"
              % (d["version"], d["gamelumps"], d["sprp_version"],
                 "  [ sprp COMPRIMIDO ]" if d["comprimido"] else "",
                 d["n_modelos"], d["n_props"], d["paso"], d["sobrantes"]))

        # ⚠ EL CONTROL NEGATIVO DEL CAMINO COMPRIMIDO, y sólo se puede correr
        # sobre un mapa que de verdad lo use. Se le da un descompresor que
        # devuelve basura del largo equivocado: el parser tiene que decir
        # `ok = false`, NO producir números. Sin esto, «descomprimió y parseó» no
        # se distingue de «parseó cualquier cosa que le pusieron adelante».
        if d["comprimido"]:
            est2, d2 = medir(r, decompresor=lambda _b: b"basura")
            bien = (est2 == "sin_ok")
            print("   CONTROL NEGATIVO del camino comprimido: con un descompresor que "
                  "devuelve basura -> %s" % ("ok = false, como debe ser" if bien
                                             else "!! DIO %s, el largo declarado no se está usando" % est2))
            if not bien:
                fallas += 1

        esperado = CONTROL.get(mapa)
        if esperado:
            controlados.append(mapa)
            dio = (int(d["n_modelos"]), int(d["n_props"]))
            if dio == esperado:
                print("   CONTROL: reproduce %d / %d medidos por censo_props_horneados.py" % esperado)
            else:
                print("   !! CONTROL: se esperaban %d / %d y dio %d / %d -- el lector NO reproduce"
                      % (esperado + dio))
                fallas += 1

        print("")

    print("-" * 78)
    if fallas:
        print("!! %d mapa(s) con problema. NO se publica nada de esta corrida." % fallas)
        return 1

    if not controlados:
        print("PARCIAL: ningun mapa de control entro en esta corrida, asi que el arnes NO quedo")
        print("         calibrado aca. Los numeros valen si en la MISMA sesion corrio sobre")
        print("         %s y dio OK." % ", ".join(sorted(CONTROL)))
        return 3

    print("OK: el arnes reproduce el censo previo; lo demas de esta corrida vale.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
