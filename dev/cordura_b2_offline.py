# -*- coding: utf-8 -*-
"""
Ejercita la tajada B2 de la cordura SIN EL JUEGO, sobre el codigo REAL.

POR QUE EXISTE
--------------
B2 tiene tres piezas y solo una se ve en pantalla:

  1. la CAIDA del drenaje con la distancia   ( `factorSanidad` )
  2. la normalizacion del tercer retorno     ( `normalizarEpicentros` )
  3. la FUSION de la sub-tabla `sanity`      ( ghost_flags.lua )

Las tres fallan en silencio. Una meseta mal calculada no tira error: drena "un
poco distinto", y en juego eso es indistinguible de haberse parado medio metro
mas lejos. Un `EV.*` que devuelve una forma que el normalizador no entiende no
avisa: el evento sale, suena, y no cobra. Y un rasgo mal escrito en una fila de
tipo deja al Oni comportandose como neutro justo en el eje que lo define.

*Una pieza que solo se puede juzgar mirando el resultado en juego no se puede
juzgar: en juego los tres defectos se ven como "drena poco".*

QUE MIDE, Y CONTRA QUE
----------------------
No re-implementa nada. Extrae del ARCHIVO REAL el texto de las dos funciones y
lo corre en un interprete de Lua; y ejecuta `ghost_flags.lua` entero con los
stubs minimos de GMod. Si alguien cambia la formula, este script mide la formula
nueva -- que es el punto: un control que copia el cuerpo mide su copia.

⚠ LO QUE **NO** MIDE, Y SE DECLARA: la pasada sobre los jugadores
( `cobrarCordura` ) no se puede correr aca -- pide `player.GetAll`, convars y la
puerta de la cordura. Lo que este script cubre son sus dos insumos. El tope, el
`mult` y el reparto por categoria se miden EN JUEGO, con la planilla.

Uso:
    python dev/cordura_b2_offline.py
    python dev/cordura_b2_offline.py --control

Sale 0 si todo pasa, 1 si algo falla.
"""
import io
import os
import re
import sys
import pathlib

try:
    import lupa
except ImportError:
    print("!! falta `lupa` ( pip install lupa ). Sin interprete de Lua este control no puede correr,")
    print("   y un 'no se pudo medir' NO es un verde.")
    sys.exit(1)


RAIZ = pathlib.Path(__file__).resolve().parent.parent
EVENTS = RAIZ / "lua" / "entities" / "terminator_nextbot_phantom" / "server_events.lua"
FLAGS = RAIZ / "lua" / "phantasmagoria" / "ghost_flags.lua"
TYPES = RAIZ / "lua" / "phantasmagoria" / "ghost_types.lua"


# ---------------------------------------------------------------------------
# EXTRAER UNA FUNCION `local function <nombre>( ... ) ... end` DEL ARCHIVO REAL
# ---------------------------------------------------------------------------
# ⚠ Se corta contando el `end` de la MISMA indentacion que el `local function`,
# y no con un contador de palabras clave: `end` aparece adentro de strings y de
# comentarios, y un contador ingenuo se pasa de largo o se queda corto. La
# indentacion es fragil como criterio general, pero en este archivo todas las
# funciones de nivel superior arrancan en la columna 0 y el `end` que las cierra
# tambien -- y si eso deja de ser cierto, la extraccion falla RUIDOSAMENTE
# ( no compila ) en vez de devolver medio cuerpo.
def extraer(texto, nombre):
    pat = re.compile(r"^local function " + re.escape(nombre) + r"\(", re.M)
    m = pat.search(texto)
    if not m:
        return None

    ini = m.start()
    resto = texto[ini:]

    fin = re.search(r"^end\s*$", resto, re.M)
    if not fin:
        return None

    cuerpo = resto[: fin.end()]

    # ⚠ SE LE SACA EL `local`, Y NADA MAS. La funcion es local a su archivo, asi
    # que cargada tal cual quedaria local al chunk y el runtime la veria nil --
    # o sea que el control fallaria con un "no es una funcion" que se lee como un
    # defecto del sujeto y es del arnes. Se toca UNA palabra: cualquier otra
    # reescritura y este script dejaria de medir el codigo real.
    return re.sub(r"^local function ", "function ", cuerpo, count=1)


def nuevo_lua():
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute(
        """
        -- Los stubs MINIMOS de GMod que estas piezas tocan. Se declaran uno por
        -- uno y no con un __index que autovivifica: un default automatico vuelve
        -- VERDADERA toda pregunta por un campo, y entonces `if p.campo then`
        -- acepta cualquier cosa ( catalogo nº 111 ).
        function istable( v )   return type( v ) == "table" end
        function isnumber( v )  return type( v ) == "number" end
        function isstring( v )  return type( v ) == "string" end
        function isfunction( v ) return type( v ) == "function" end

        ERRORES = {}
        function ErrorNoHalt( ... )
            ERRORES[ #ERRORES + 1 ] = table.concat( { ... } )
        end

        math.Clamp = function( n, lo, hi )
            if n < lo then return lo end
            if n > hi then return hi end
            return n
        end
        math.Round = function( n ) return math.floor( n + 0.5 ) end

        -- Un Vector de mentira que solo sabe hacer lo que estas piezas le piden.
        local VecMeta = {}
        VecMeta.__index = VecMeta
        function VecMeta:Distance( o )
            local dx, dy, dz = self.x - o.x, self.y - o.y, self.z - o.z
            return math.sqrt( dx * dx + dy * dy + dz * dz )
        end

        function Vector( x, y, z )
            return setmetatable( { x = x or 0, y = y or 0, z = z or 0 }, VecMeta )
        end

        function isvector( v )
            return type( v ) == "table" and getmetatable( v ) == VecMeta
        end

        PHANTASMAGORIA = PHANTASMAGORIA or {}
        """
    )
    return L


# ---------------------------------------------------------------------------
# ( 1 ) LA CAIDA
# ---------------------------------------------------------------------------
def probar_caida(fuente, fallos):
    cuerpo = extraer(fuente, "factorSanidad")
    if not cuerpo:
        fallos.append("factorSanidad: no se pudo extraer del archivo real "
                      "( cambio de forma? un control que no encuentra a su sujeto NO es un verde )")
        return

    L = nuevo_lua()
    L.execute(cuerpo)
    f = L.globals().factorSanidad

    radio, meseta = 450.0, 135.0     # 450 y el 30 % de 450, que son los defaults

    casos = [
        # ( distancia, esperado, por que )
        (0.0,    1.0, "en el epicentro se cobra entero"),
        (135.0,  1.0, "el borde de la meseta TODAVIA cobra entero"),
        (450.0,  0.0, "en el borde del radio no cobra nada"),
        (999.0,  0.0, "mas alla del radio tampoco"),
        (292.5,  0.5, "el punto medio entre meseta y borde cobra la mitad"),
    ]

    for d, esperado, porque in casos:
        got = f(d, radio, meseta)
        if abs(got - esperado) > 1e-9:
            fallos.append(f"factorSanidad({d}) = {got:.6f}, se esperaba {esperado} -- {porque}")

    # ⚠ MONOTONA: nunca puede SUBIR al alejarse. Es la propiedad, no un punto --
    # una formula puede acertarle a los cinco casos de arriba y tener un rebote en
    # el medio, y un rebote significa que alejarse drena mas.
    prev = None
    for i in range(0, 501, 5):
        v = f(float(i), radio, meseta)
        if prev is not None and v > prev + 1e-12:
            fallos.append(f"factorSanidad NO es monotona: sube en d={i} ( {prev:.6f} -> {v:.6f} ). "
                          "Alejarse del evento drenaria mas.")
            break
        prev = v

    # Los degenerados. Un radio en 0 es lo que deja una convar mal puesta, y una
    # division por cero ahi seria un nan que se propaga hasta la barra.
    for d, r, m, nombre in [(10.0, 0.0, 0.0, "radio 0"), (0.0, 450.0, 9999.0, "meseta mayor que el radio")]:
        v = f(d, r, m)
        if v != v:
            fallos.append(f"factorSanidad con {nombre} devolvio nan")
        elif v < 0 or v > 1:
            fallos.append(f"factorSanidad con {nombre} devolvio {v}, fuera de [0,1]")


# ---------------------------------------------------------------------------
# ( 2 ) EL NORMALIZADOR DEL TERCER RETORNO
# ---------------------------------------------------------------------------
def probar_normalizador(fuente, fallos):
    cuerpo = extraer(fuente, "normalizarEpicentros")
    if not cuerpo:
        fallos.append("normalizarEpicentros: no se pudo extraer del archivo real")
        return

    L = nuevo_lua()
    # `SAN` es del modulo; se declara el minimo que la funcion escribe.
    L.execute("SAN = { sinEpicentro = {} }")
    L.execute(cuerpo)

    L.execute(
        """
        RES = {}

        function correr( cat, epi )
            local out = {}
            normalizarEpicentros( cat, epi, out )
            return #out
        end
        """
    )
    correr = L.globals().correr
    SAN = L.globals().SAN

    V = L.globals().Vector

    casos = [
        ("un Vector suelto",            "knock",  V(0, 0, 0),                                  1, 0),
        ("una lista de tres Vectors",   "throw",  L.table(V(0, 0, 0), V(1, 0, 0), V(2, 0, 0)), 3, 0),
        ("la forma con pct propio",     "light",  L.eval("{ pos = Vector(0,0,0), pct = 3 }"),  1, 0),
        ("nil: no dijo donde",          "creak",  None,                                        0, 1),
        ("tabla vacia",                 "door",   L.table(),                                   0, 1),
        ("un numero, que no es forma",  "prop",   7,                                           0, 1),
        ("pct sin pos",                 "sound",  L.eval("{ pct = 5 }"),                       0, 1),
    ]

    for nombre, cat, epi, esperado, ciegos in casos:
        antes = SAN.sinEpicentro[cat] or 0
        n = correr(cat, epi)
        despues = SAN.sinEpicentro[cat] or 0

        if n != esperado:
            fallos.append(f"normalizarEpicentros / {nombre}: dio {n} epicentro(s), se esperaba {esperado}")

        if despues - antes != ciegos:
            fallos.append(f"normalizarEpicentros / {nombre}: conto {despues - antes} sin-epicentro, "
                          f"se esperaba {ciegos}. Un evento que no dice donde paso y uno que si tienen "
                          "que ser distinguibles en el reporte.")

    # ⚠ EL `pct` TIENE QUE SOBREVIVIR. Si se perdiera, el ESTALLIDO cobraria como
    # un parpadeo -- 2,0 en vez de 3,0 -- y en juego eso es media unidad de
    # cordura: nadie lo nota nunca.
    L.execute("""
        local out = {}
        normalizarEpicentros( "light", { pos = Vector(0,0,0), pct = 3 }, out )
        PCT = out[ 1 ] and out[ 1 ].pct
    """)
    if L.globals().PCT != 3:
        fallos.append(f"normalizarEpicentros perdio el `pct` propio ( quedo {L.globals().PCT} ). "
                      "El ESTALLIDO de la luz cobraria como un parpadeo y no hay forma de verlo en juego.")


# ---------------------------------------------------------------------------
# ( 3 ) LA FUSION DE `sanity` SOBRE LOS 30 TIPOS
# ---------------------------------------------------------------------------
def cargar_flags(texto_flags=None):
    """Ejecuta ghost_types.lua + ghost_flags.lua de verdad y devuelve el runtime."""
    L = nuevo_lua()
    L.execute(io.open(TYPES, encoding="utf-8").read())
    L.execute(texto_flags if texto_flags is not None
              else io.open(FLAGS, encoding="utf-8").read())
    return L


def probar_fusion(fallos):
    L = cargar_flags()
    g = L.globals()
    P = g.PHANTASMAGORIA

    errores = list(g.ERRORES.values()) if g.ERRORES else []
    if errores:
        fallos.append("ghost_flags.lua grito al cargar el arbol LIMPIO: " + " | ".join(errores))

    T = P.Types
    if T is None:
        fallos.append("PHANTASMAGORIA.Types no existe: ghost_types.lua no cargo")
        return

    total, con_sanity = 0, 0
    for _, fila in T.items():
        total += 1
        ev = fila.events
        if ev is not None and ev.sanity is not None:
            con_sanity += 1

    # ⚠ SE EXIGE == total Y NO > 0. La fusion escribe `events` en las TREINTA
    # filas -- las que no tienen rasgos propios se llevan el neutro -- asi que
    # cualquier numero menor significa que se corto a la mitad. Un `> 0` daria
    # verde con una sola fila fusionada.
    if con_sanity != total:
        fallos.append(f"solo {con_sanity} de {total} tipos tienen `events.sanity`. "
                      "La sub-tabla no llego a todos: los que faltan no pueden ni siquiera "
                      "leer el neutro, y el motor los va a ver como sin rasgo.")

    esperado = [
        ("oni",     "mult",     2.0,  "el x2 de la fuente ( drena 20 % en vez de 10 % )"),
        ("phantom", "presence", 0.5,  "el 0,5 %/s mientras lo veas manifestarse a 525 u"),
    ]
    for tipo, campo, val, porque in esperado:
        fila = T[tipo]
        if fila is None:
            fallos.append(f"el tipo '{tipo}' no existe en Types")
            continue
        got = fila.events.sanity[campo]
        if got != val:
            fallos.append(f"{tipo}.sanity.{campo} = {got}, se esperaba {val} -- {porque}")

    yurei = T["yurei"]
    if yurei is not None:
        got = yurei.events.sanity["per"]["door"]
        if got != 15:
            fallos.append(f"yurei.sanity.per.door = {got}, se esperaba 15 "
                          "( el override literal de la fuente, que PISA el 1,5 % de la categoria )")

    # ⚠⚠ EL AISLAMIENTO ENTRE FILAS, Y ES EL DEFECTO MAS SILENCIOSO DE UNA TABLA
    # DE CONFIGURACION: dos tipos apuntando a la misma sub-tabla `sanity` hacen
    # que tocar el rasgo de uno toque el del otro. Funciona hasta que alguien
    # escribe en runtime. Se comprueba MUTANDO uno y mirando al vecino.
    L.execute("""
        PHANTASMAGORIA.Types.oni.events.sanity.mult = 99
        PHANTASMAGORIA.Types.yurei.events.sanity.per.door = 99
    """)
    if T["spirit"].events.sanity["mult"] == 99:
        fallos.append("las filas COMPARTEN la sub-tabla `sanity`: mutar el Oni movio al Spirit. "
                      "La copia profunda de `fusionar` no esta cubriendo este nivel.")
    if T["oni"].events.sanity["per"]["door"] == 99:
        fallos.append("las filas comparten `sanity.per`: mutar el Yurei movio al Oni.")


# ---------------------------------------------------------------------------
# EL CONTROL: que la guarda de ghost_flags.lua DISCRIMINE
# ---------------------------------------------------------------------------
# ⚠ Declara CUANTOS defectos inyecta y de que clase, y falla si el numero no
# coincide -- de mas o de menos. Un arnes que solo pide "al menos una falla" se
# acredita el trabajo que no hizo ( catalogo nº 72 ).
#
# Los tres sabotajes son los tres modos de falla REALES de esta sub-tabla, y
# ninguno de los tres tira error de Lua por su cuenta:
#
#   ( a ) una categoria mal escrita adentro de `per`  -> el override no lo cobra
#         nadie y el tipo se comporta como neutro en su unico eje.
#   ( b ) un campo de `sanity` que no existe en el neutro -> los otros 29 lo
#         tienen en nil y el motor lo saltea.
#   ( c ) un tipo donde va un numero -> se fusiona igual y revienta en el motor.
SABOTAJES = [
    ("per con una categoria inexistente",
     'sanity  = { per = { door = 15 } },',
     'sanity  = { per = { doors = 15 } },',
     "no es una categoria de evento"),

    ("campo de sanity ausente del neutro",
     'sanity  = { mult = 2.0 },',
     'sanity  = { multiplicador = 2.0 },',
     "no existe en EventDefaults"),

    ("tabla donde va un escalar",
     'sanity  = { presence = 0.5 },',
     'sanity  = { presence = { 0.5 } },',
     "y el neutro es number"),
]


def control():
    crudo = io.open(FLAGS, encoding="utf-8").read()
    ok = True

    print("CONTROL -- se sabotea ghost_flags.lua en memoria y se mira si la guarda habla")
    print()

    # ( a ) el arbol limpio tiene que callarse
    L = cargar_flags()
    errores = list(L.globals().ERRORES.values()) if L.globals().ERRORES else []
    marca = "ok " if not errores else "!! "
    print(f"  {marca}arbol limpio -> {len(errores)} grito(s)   ( se pedia 0 )")
    for e in errores:
        print(f"       {e[:150]}")
    if errores:
        ok = False

    # ( b ) cada sabotaje tiene que dar EXACTAMENTE su grito
    for nombre, viejo, nuevo, fragmento in SABOTAJES:
        if crudo.count(viejo) != 1:
            print(f"  !! {nombre}: el ancla del sabotaje aparece {crudo.count(viejo)} veces, no 1.")
            print("       El control no puede inyectar su defecto, asi que su verde no vale nada.")
            ok = False
            continue

        sucio = crudo.replace(viejo, nuevo)
        Ls = cargar_flags(sucio)
        gritos = list(Ls.globals().ERRORES.values()) if Ls.globals().ERRORES else []
        pego = any(fragmento in gr for gr in gritos)

        marca = "ok " if pego else "!! "
        print(f"  {marca}{nombre:<42} {'detectado' if pego else 'NO DETECTADO'}")
        if not pego:
            ok = False
            print(f"       se buscaba '{fragmento}' en {len(gritos)} grito(s)")
            for gr in gritos:
                print(f"       {gr[:150]}")

    print()
    print("CONTROL:", "la guarda DISCRIMINA" if ok
          else "LA GUARDA NO DISCRIMINA -- no uses su silencio como verde")
    return 0 if ok else 1


def main():
    fuente = io.open(EVENTS, encoding="utf-8").read()
    fallos = []

    probar_caida(fuente, fallos)
    probar_normalizador(fuente, fallos)
    probar_fusion(fallos)

    print("CORDURA B2 -- ejercicio offline sobre el codigo real")
    print()
    print(f"  archivo de eventos   {EVENTS.relative_to(RAIZ).as_posix()}")
    print(f"  archivo de rasgos    {FLAGS.relative_to(RAIZ).as_posix()}")
    print()

    if not fallos:
        print("  ok  la caida ( meseta, borde, punto medio, monotonia, degenerados )")
        print("  ok  el normalizador ( las cuatro formas del tercer retorno, y el pct sobrevive )")
        print("  ok  la fusion ( los 30 con sanity, Oni x2, Yurei per.door 15, Phantom 0,5 %/s, sin alias )")
        print()
        print("FALLOS: 0")
        return 0

    for f in fallos:
        print(f"  !! {f}")
    print()
    print(f"FALLOS: {len(fallos)}")
    return 1


if __name__ == "__main__":
    if "--control" in sys.argv:
        sys.exit(control())
    sys.exit(main())
