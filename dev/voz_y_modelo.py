#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
voz_y_modelo.py -- ejecuta LOS BLOQUES REALES que deciden que CUERPO y que VOZ
le toca a cada fantasma, y dice quien decidio cada cosa.

Corre seis pedazos, extraidos de sus archivos por ANCLAS DE TEXTO y sin
reescribirlos:

    lua/phantasmagoria/ghost_types.lua      los 30 tipos ( datos REALES )
    lua/phantasmagoria/ghost_flags.lua      los rasgos, fusionados de verdad
    lua/phantasmagoria/ghost_models.lua     el registro + VozDelModelo
    .../server.lua        MODEL_CANDIDATES, pickModel, poolDelBot,
                          aplicarModeloDelBot, sexoQueExigeElTipo, ENT:Initialize
    .../server_events.lua ENT:phantom_EventVoice
    .../server_type.lua   ENT:phantom_PreelegirTipo, ENT:phantom_ResolveType

⚠ LOS RASGOS NO SON UNA MAQUETA. `ghost_types.lua` y `ghost_flags.lua` se cargan
enteros y se fusionan con su propio `AplicarRasgosDeEvento`, asi que cuando este
arnes dice "dos de los treinta fijan la voz" esta contando los treinta de verdad.
Una tabla de tipos inventada aca habria medido mi maqueta y no el addon.

POR QUE ESTE ARNES Y NO EL DE SIEMPRE
-------------------------------------
`dev/phastools/luaharness.py` NO puede construir este sujeto: no termina de
cargar `terminator_nextbot_phantom/server.lua` ( handoff §R5.3 ). O sea que no da
cobertura y no se le acredita ninguna. El molde que si funciona es
`dev/hull_por_modelo.py`, y este es el mismo: bloque real, anclas de texto,
degenerados de fabrica y una perilla `--romper`.

QUE DEFECTO VIGILA
------------------
Tres, y son los tres cabos del bloque del 2026-08-17:

  pool    `CLASE.Models = { chosen.mdl }` -- una lista de UNO, o sea que los
          seis fantasmas de la partida salian con el mismo cuerpo aunque la base
          sortea desde siempre ( shared.lua:2971 ).
  orden   la voz y el cuerpo se elegian por caminos que no se hablaban, asi que
          el Ghost_Male podia susurrar con voz de mujer. La prioridad es
          tipo > modelo > sorteo y el ORDEN es la decision: al reves, un Banshee
          --"Can only be female"-- hablaria grave.
  filtro  con el sorteo prendido un Banshee podia salir con el CUERPO del Male.

EL CONTROL DEL PROPIO ARNES ( --romper )
----------------------------------------
`--romper pool|orden|filtro|todos` le vuelve a meter cada defecto al bloque
extraido y el arnes TIENE que ponerse rojo, cada uno en SUS filas y no en todas:
si `--romper orden` pusiera rojo tambien al pool, no estaria discriminando, y un
arnes acoplado de mas acredita igual que uno flojo. Sin esta perilla un verde de
aca no prueba que pueda haber un rojo -- *y una perilla que nadie puede mover no
es un control.*

⚠ LO QUE ESTE ARNES NO MIDE, y hay que decirlo porque su verde se lee como
cobertura:
  · Que la base LLAME a nuestro `Initialize` y respete `self.Models`. Eso es del
    motor. Aca se mide la funcion que produce la lista, no que alguien la lea.
    La fila en juego sigue haciendo falta.
  · `PHANTASMAGORIA.ResolveTypeKey` de verdad: los grupos D y F le ponen un doble
    que CUENTA sus llamadas, porque lo que se mide es el cableado ( pre-elegir y
    consumir ), no el sorteo de tipo, que este bloque no toco.
  · Los numeros de las ACT_*: se estuban con enteros distintos. Este arnes no
    dice nada de la traduccion de actividades.
  · Como SUENA la voz 1 contra la 2. Mide que INDICE sale, no el clip.
"""

import argparse
import os
import sys

import lupa

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENTI = os.path.join(RAIZ, "lua", "entities", "terminator_nextbot_phantom")
DATA = os.path.join(RAIZ, "lua", "phantasmagoria")

SERVER = os.path.join(ENTI, "server.lua")
EVENTS = os.path.join(ENTI, "server_events.lua")
TIPOS = os.path.join(ENTI, "server_type.lua")

# Se buscan POR TEXTO y no por numero de linea: un rango clavado se desfasa con
# la primera linea que alguien agregue arriba, y ese desfase es SILENCIOSO --
# extraeria un pedazo cualquiera y lo correria como si fuera el bueno.
BLOQUES = [
    (os.path.join(DATA, "ghost_types.lua"), "PHANTASMAGORIA = PHANTASMAGORIA or {}", None),
    (os.path.join(DATA, "ghost_flags.lua"), "PHANTASMAGORIA = PHANTASMAGORIA or {}", None),
    (os.path.join(DATA, "ghost_models.lua"), "PHANTASMAGORIA = PHANTASMAGORIA or {}", None),
    (SERVER, "local MODEL_CANDIDATES = {",
     "\n---------------------------------------------------------------------------\n"
     "-- ⚠ EL HULL CON EL QUE CAMINA"),
    (EVENTS, "function ENT:phantom_EventVoice()", "\n-- ¿Esta categoria puede correr?"),
    (TIPOS, "function ENT:phantom_PreelegirTipo()",
     "\n---------------------------------------------------------------------------\n"
     "-- La linea que va en los instrumentos"),
]

# Los tres defectos, con el texto EXACTO que hay que encontrar antes de pisarlo.
# Si el ancla no aparece, el defecto ya no tiene esa forma y el arnes LO DICE en
# vez de reinyectar nada: un `--romper` que no encuentra que romper y sigue en
# silencio es una perilla muerta que igual imprime "CONTROL OK".
DEFECTOS = {
    "pool": ("    CLASE.Models    = pool",
             "    CLASE.Models    = { chosen.mdl }",
             "la lista de UNO: todos los fantasmas con el mismo cuerpo"),
    "orden": ("    if fija == 1 or fija == 2 then",
              "    if false then",
              "el tipo deja de mandar sobre el modelo ( prioridad invertida )"),
    "filtro": ("                self.Models = compatibles",
               "                local _ = compatibles",
               "el cuerpo no se filtra por el tipo"),
}

# Que GRUPO de filas tiene que ponerse rojo con cada defecto. Es la mitad del
# control que suele faltar: "hubo rojo" no distingue un arnes que discrimina de
# uno que se cae entero ante cualquier cambio.
ALCANCE = {"pool": {"B", "D"}, "orden": {"E"}, "filtro": {"D"}}

BOOT = r"""
-- Stubs. Los de tipo son los de GMod al pie de la letra; los demas son andamio y
-- estan declarados en el encabezado del arnes.
istable    = function( v ) return type( v ) == "table" end
isstring   = function( v ) return type( v ) == "string" end
isnumber   = function( v ) return type( v ) == "number" end
isfunction = function( v ) return type( v ) == "function" end
isbool     = function( v ) return type( v ) == "boolean" end

math.Round = function( num, idp )
    local mult = 10 ^ ( idp or 0 )
    return math.floor( num * mult + 0.5 ) / mult
end

table.Count = function( t )
    local n = 0
    for _ in pairs( t ) do n = n + 1 end
    return n
end

string.Trim = function( s )
    return ( string.gsub( s or "", "^%s*(.-)%s*$", "%1" ) )
end

-- La consola del arnes: se GUARDA lo impreso, porque varias filas comprueban que
-- un aviso SALIO. Un aviso que nadie puede leer no separa causas.
__salida = {}
local function guardar( ... )
    local partes = {}
    for i = 1, select( "#", ... ) do
        partes[ #partes + 1 ] = tostring( ( select( i, ... ) ) )
    end
    __salida[ #__salida + 1 ] = table.concat( partes )
end

ghostPrint  = guardar
MsgC        = guardar
ErrorNoHalt = guardar
Color       = function() return {} end

-- Los modelos MONTADOS, que es la perilla con la que se arman los escenarios.
__montados = {}
util = { IsValidModel = function( m ) return __montados[ m ] == true end }

-- Las convars, con sus callbacks, para poder mover la perilla y correr el camino
-- REAL del cambio -- que es justo lo que la r5 no podia hacer.
__cvars, __cbs = {}, {}

local cvMeta = {}
cvMeta.__index = cvMeta
function cvMeta:GetString() return __cvars[ self.n ] or "" end
function cvMeta:GetBool()
    local v = __cvars[ self.n ] or ""
    return v ~= "0" and v ~= ""
end
function cvMeta:GetFloat() return tonumber( __cvars[ self.n ] ) or 0 end
function cvMeta:GetInt()   return math.floor( tonumber( __cvars[ self.n ] ) or 0 ) end

function CreateConVar( name, def )
    __cvars[ name ] = def
    return setmetatable( { n = name }, cvMeta )
end

cvars = { AddChangeCallback = function( name, fn ) __cbs[ name ] = fn end }

function __setcvar( name, val )
    __cvars[ name ] = val
    if __cbs[ name ] then __cbs[ name ]( name, nil, val ) end
end

-- ACT_*: enteros DISTINTOS. Este arnes no mide actividades ( ver el encabezado ).
local __act = 0
for _, n in ipairs{ "ACT_HL2MP_IDLE", "ACT_HL2MP_WALK", "ACT_HL2MP_RUN",
    "ACT_HL2MP_IDLE_CROUCH", "ACT_HL2MP_WALK_CROUCH", "ACT_HL2MP_JUMP_SLAM",
    "ACT_HL2MP_SWIM", "ACT_LAND", "ACT_HL2MP_GESTURE_RANGE_ATTACK",
    "ACT_MP_STAND_IDLE", "ACT_MP_WALK", "ACT_MP_RUN", "ACT_MP_CROUCH_IDLE",
    "ACT_MP_CROUCHWALK", "ACT_MP_JUMP", "ACT_MP_SWIM",
    "ACT_MP_ATTACK_STAND_PRIMARYFIRE", "ACT_MP_ATTACK_CROUCH_PRIMARYFIRE" } do
    __act = __act + 1
    _G[ n ] = __act
end

-- La clase. En el juego la crea GMod; aca alcanza una tabla, porque lo que se
-- mide es que se ESCRIBE en ella.
ENT = {}

-- `cvAssign` es un local de server_type.lua y el pedazo extraido lo ve como
-- global. Se declara aca, con su default de 1 ( igual que el CreateConVar real ).
__typeassign = true
cvAssign = { GetBool = function() return __typeassign ~= false end }
"""

EXPORTS = """
_G.__ENT = ENT
_G.__sexoQueExigeElTipo = sexoQueExigeElTipo
"""


def extraer(texto, desde, hasta):
    i = texto.find(desde)
    if i < 0:
        raise SystemExit("!! no aparece el ancla de inicio: %r" % desde[:70])
    if hasta is None:
        return texto[i:]
    j = texto.find(hasta, i + len(desde))
    if j < 0:
        raise SystemExit("!! no aparece el ancla de fin: %r" % hasta[:70])
    return texto[i:j]


def arr(t):
    """Una tabla-array de Lua como lista de Python, recorrida 1..n a mano.

    No se usa `.values()`: su orden es el de `pairs`, que para una secuencia
    suele coincidir y no esta garantizado -- y aca el ORDEN del pool es parte de
    lo que se compara."""
    if t is None:
        return []
    out, i = [], 1
    while True:
        v = t[i]
        if v is None:
            return out
        out.append(v)
        i += 1


def lit(v):
    """Un valor de Python como literal de Lua. `None` tiene que dar `nil` y no
    `False`: `False` seria un global indefinido, que da nil por casualidad y
    dejaria de darlo el dia que alguien declare uno."""
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"%s"' % v.replace("\\", "\\\\").replace('"', '\\"')
    return repr(v)


class Tanteo(object):
    """Lleva la cuenta y, sobre todo, EL DENOMINADOR: un `0 fallas` sin cuantas
    comprobaciones lo produjeron se lee igual que un lector que no leyo nada."""

    def __init__(self):
        self.n = 0
        self.fallas = 0
        self.rojas = set()

    def fila(self, grupo, nombre, visto, esperado, nota=""):
        self.n += 1
        ok = visto == esperado
        if not ok:
            self.fallas += 1
            self.rojas.add(grupo)

        def corto(v):
            if isinstance(v, list):
                return "[" + ", ".join(os.path.basename(str(x)) for x in v) + "]"
            return repr(v)

        print("  %-56s %-34s %s%s" % (
            nombre, corto(visto), "OK  " if ok else "FALLA",
            ("  " + nota) if ok and nota else ("  esperaba %s" % corto(esperado) if not ok else "")))
        return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--romper", choices=sorted(DEFECTOS) + ["todos"],
                    help="reinyecta un defecto y exige que el arnes se ponga rojo EN SUS FILAS")
    args = ap.parse_args()

    trozos = [extraer(open(f, encoding="utf-8").read(), a, b) for f, a, b in BLOQUES]

    rotos = sorted(DEFECTOS) if args.romper == "todos" else ([args.romper] if args.romper else [])
    for cual in rotos:
        viejo, nuevo, _ = DEFECTOS[cual]
        cuantas = sum(tz.count(viejo) for tz in trozos)
        if cuantas != 1:
            raise SystemExit(
                "!! --romper %s no encontro su ancla ( %d veces ): %r\n"
                "   El defecto ya no tiene esa forma. Revisar el arnes ANTES de creerle "
                "a una corrida verde." % (cual, cuantas, viejo))
        trozos = [tz.replace(viejo, nuevo) for tz in trozos]

    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute(BOOT)

    # ⚠ CADA TROZO ES SU PROPIO CHUNK, y no es una preferencia de estilo:
    # `ghost_types.lua` termina en `return PHANTASMAGORIA.Types` -- un return de
    # ARCHIVO, que es como GMod pasa datos entre includes. Concatenados, ese
    # return corta el chunk y todo lo que viene despues NO SE CARGA; y si lo que
    # queda colgado da la casualidad de ser sintacticamente valido, el arnes
    # corre la mitad de los bloques y cuenta verde igual. Se comparten los
    # globales -- que es lo que comparten los archivos en GMod -- y los LOCALES
    # de cada uno se quedan en el suyo, tambien como en GMod.
    #
    # Por eso `EXPORTS` va pegado al trozo de server.lua: `sexoQueExigeElTipo` es
    # un `local` de ese archivo y desde otro chunk no se ve.
    for (ruta, _a, _b), tz in zip(BLOQUES, trozos):
        L.execute(tz + (EXPORTS if ruta == SERVER else ""))
    g = L.globals()
    lua = L.eval

    print("voz_y_modelo -- bloques REALES de server.lua, server_events.lua, "
          "server_type.lua\n                y los tres archivos de datos")
    if rotos:
        print("!! MODO --romper: %s\n   Las filas del grupo %s TIENEN que ponerse rojas, y "
              "SOLO esas.\n"
              % ("; ".join("%s ( %s )" % (c, DEFECTOS[c][2]) for c in rotos),
                 "/".join(sorted(set().union(*[ALCANCE[c] for c in rotos])))))
    else:
        print()

    t = Tanteo()
    GIRL = "models/phantasmagoria/ghost_girl.mdl"
    MALE = "models/phantasmagoria/ghost_male.mdl"
    CRONE = "models/phantasmagoria/ghost_oldcrone.mdl"
    CORPSE = "models/player/corpse1.mdl"
    MALE04 = "models/player/group01/male_04.mdl"
    TALLER = [GIRL, MALE, CRONE]
    AJENOS = [CORPSE, MALE04]

    def dicho():
        return "\n".join(arr(g["__salida"]))

    # =====================================================================
    print("  ( A ) el sexo del MODELO -- PHANTASMAGORIA.VozDelModelo, registro real")
    voz = g["PHANTASMAGORIA"]["VozDelModelo"]
    for mdl, esp, nota in [(GIRL, 1, "femenina"), (CRONE, 1, "femenina"),
                           (MALE, 2, "grave"), (CORPSE, None, "ajeno: no declara sexo")]:
        t.fila("A", "    " + os.path.basename(mdl), voz(mdl), esp, nota)

    # Degenerados DE FABRICA: no son un test que alguien tenga que acordarse de
    # escribir. `nil` y "" es lo que devuelve GetModel() de una entidad sin
    # modelo, que no es lo mismo que un modelo ajeno.
    for mdl, nombre in [(None, "GetModel() nil"), ("", "GetModel() vacio"),
                        (7, "GetModel() que no es cadena")]:
        t.fila("A", "    degenerado: " + nombre, voz(mdl), None)

    # Una ficha con `voz` fuera del catalogo: el catalogo tiene DOS voces, y un 3
    # indexaria VOZ[ 3 ] en server_events.lua -> fantasma MUDO, sin error.
    L.execute('PHANTASMAGORIA.GhostModelPorRuta[ "x.mdl" ] = { mdl = "x.mdl", voz = 3 }')
    L.execute('PHANTASMAGORIA.GhostModelPorRuta[ "y.mdl" ] = { mdl = "y.mdl" }')
    t.fila("A", "    degenerado: ficha con voz = 3 ( fuera del catalogo )", voz("x.mdl"), None)
    t.fila("A", "    degenerado: ficha SIN campo voz", voz("y.mdl"), None)

    # =====================================================================
    print("\n  ( B ) el POOL que va a la clase -- pickModel + poolDelBot + aplicarModeloDelBot")

    def escenario(montados, convar):
        L.execute("__montados = {}")
        for m in montados:
            L.execute("__montados[ %s ] = true" % lit(m))
        L.execute("__salida = {}")
        lua('__setcvar( "phantasmagoria_bot_modelo", %s )' % lit(convar))
        return arr(g["__ENT"]["Models"])

    t.fila("B", "    los 3 del taller montados, convar vacia",
           escenario(TALLER + AJENOS, ""), TALLER, "la base sortea entre los tres")
    t.fila("B", "    solo la nena y la vieja montadas",
           escenario([GIRL, CRONE] + AJENOS, ""), [GIRL, CRONE],
           "un modelo no montado no puede entrar al sorteo")
    t.fila("B", "    solo la nena montada",
           escenario([GIRL] + AJENOS, ""), [GIRL],
           "identico a lo que corria antes de este bloque")
    t.fila("B", "    NINGUNO del taller ( clon limpio: los .mdl no van a git )",
           escenario(AJENOS, ""), [CORPSE], "cae al camino de hoy, y NO a una lista vacia")
    t.fila("B", "    nada montado, ni siquiera el cadaver",
           escenario([], ""), ["terminator"], "el ultimo recurso de pickModel, feo a proposito")

    # ⭐ LA PERILLA LE GANA AL SORTEO. Sin esta fila, las cuatro filas del hull
    # ( handoff §R6.4 ) dejarian de poder correrse y nadie se enteraria.
    t.fila("B", "  * convar = ghost_male con los 3 montados: LA PERILLA GANA",
           escenario(TALLER + AJENOS, "ghost_male"), [MALE],
           "lista de UNO: las filas 01-04 del hull se siguen corriendo")
    t.fila("B", "    convar mal escrita: cae a la lista y sortea",
           escenario(TALLER + AJENOS, "ghost_nope"), TALLER)

    escenario([MALE, CRONE] + AJENOS, "")
    d = dicho()
    t.fila("B", "    sin la nena montada, avisa cual uso en su lugar",
           ("ghost_girl.mdl" in d and "no esta montado" in d), True)

    # =====================================================================
    print("\n  ( C ) el sexo que exige el TIPO -- sobre los 30 tipos REALES, ya fusionados")
    sexo = g["__sexoQueExigeElTipo"]
    claves = sorted(g["PHANTASMAGORIA"]["Types"].keys())
    fijan = sorted(k for k in claves if sexo(k) is not None)

    t.fila("C", "    tipos cargados ( el denominador )", len(claves), 30)
    t.fila("C", "    tipos que FIJAN la voz", fijan, ["banshee", "dayan"],
           'los dos que la fuente marca "Can only be female"')
    t.fila("C", "    y los dos la fijan en 1 ( femenina )",
           [sexo("banshee"), sexo("dayan")], [1, 1])
    t.fila("C", "    un tipo que no la fija ( spirit )", sexo("spirit"), None)
    t.fila("C", "    degenerado: key inexistente", sexo("no_existe"), None)
    t.fila("C", "    degenerado: key nil", sexo(None), None)

    # =====================================================================
    print("\n  ( D ) el CUERPO que le toca a ESTE fantasma -- ENT:Initialize real")

    def spawn(montados, convar, tipo, typeassign=True):
        escenario(montados, convar)
        L.execute("__salida = {}")
        L.execute("__typeassign = %s" % ("true" if typeassign else "false"))
        L.execute("""
            __llamadas = 0
            PHANTASMAGORIA.ResolveTypeKey = function( ent )
                __llamadas = __llamadas + 1
                return ent.__tipo, "sorteado ( doble del arnes )"
            end
            __f = setmetatable( { __tipo = %s,
                                  BaseClass = { Initialize = function() end } },
                                { __index = __ENT } )
            __f:Initialize()
        """ % lit(tipo))
        return arr(g["__f"]["Models"])

    t.fila("D", "  * banshee con los 3 montados: SOLO cuerpos femeninos",
           spawn(TALLER + AJENOS, "", "banshee"), [GIRL, CRONE],
           'la fuente: "ghost model ... will reflect this"')
    t.fila("D", "    dayan, el segundo sostenedor del rasgo",
           spawn(TALLER + AJENOS, "", "dayan"), [GIRL, CRONE])
    t.fila("D", "    spirit ( no fija ): el pool entero",
           spawn(TALLER + AJENOS, "", "spirit"), TALLER, "28 de los 30 no filtran nada")
    t.fila("D", "  * banshee con la convar en ghost_male: LA PERILLA GANA",
           spawn(TALLER + AJENOS, "ghost_male", "banshee"), [MALE],
           "la perilla existe para probar UN cuerpo")
    t.fila("D", "    banshee y solo el Male montado ( pool de 1 )",
           spawn([MALE] + AJENOS, "", "banshee"), [MALE],
           "no hay entre que elegir; la voz igual sale 1")

    # ⚠ El caso que NO puede dar una lista vacia: `math.random( 0 )` TIRA, y lo
    # hace adentro del Initialize de la base, o sea antes de que el fantasma
    # exista. Se fuerza poniendo a las tres en voz 2 y pidiendo un tipo de voz 1.
    for m in (GIRL, CRONE):
        L.execute("PHANTASMAGORIA.GhostModelPorRuta[ %s ].voz = 2" % lit(m))
    salio = spawn(TALLER + AJENOS, "", "banshee")
    d = dicho()
    for m in (GIRL, CRONE):
        L.execute("PHANTASMAGORIA.GhostModelPorRuta[ %s ].voz = 1" % lit(m))

    t.fila("D", "    degenerado: NINGUN cuerpo del sexo que el tipo pide",
           salio, TALLER, "no deja lista vacia ( math.random( 0 ) TIRA )")
    t.fila("D", "    ... y lo AVISA, que es lo que separa las dos causas",
           "ninguno de los" in d, True)

    t.fila("D", "    degenerado: typeassign 0 ( el control negativo del tipo )",
           spawn(TALLER + AJENOS, "", "banshee", typeassign=False), TALLER,
           "sin tipo no hay filtro, que es lo que ese control produce")

    # =====================================================================
    print("\n  ( E ) la VOZ -- ENT:phantom_EventVoice real, prioridad tipo > modelo > sorteo")

    def hablar(tipo, mdl, moneda=1):
        L.execute("math.random = function() return %d end" % moneda)
        L.execute("""
            __g = setmetatable( { __mdl = %s, phantom_TypeKey = %s },
                                { __index = __ENT } )
            __g.GetModel = function( self ) return self.__mdl end
            __g.phantom_EventFlags = function( self )
                local f = self.phantom_TypeKey and PHANTASMAGORIA.Types[ self.phantom_TypeKey ]
                return ( f and f.events ) or PHANTASMAGORIA.EventDefaults
            end
        """ % (lit(mdl), lit(tipo)))
        return lua("__g:phantom_EventVoice()"), g["__g"]["phantom_evVoiceWhy"]

    v, why = hablar("banshee", MALE)
    t.fila("E", "  * banshee con el cuerpo del Male: manda el TIPO", v, 1,
           "el ORDEN es la decision de este bloque")
    t.fila("E", "    ... y el motivo lo dice, no solo el numero",
           why.startswith("la fija el TIPO"), True)

    v, why = hablar("spirit", MALE)
    t.fila("E", "  * spirit con el Male: manda el MODELO", v, 2)
    t.fila("E", "    ... y el motivo lo dice", why.startswith("la fija el MODELO"), True)
    t.fila("E", "    spirit con la nena", hablar("spirit", GIRL)[0], 1)
    t.fila("E", "    spirit con la vieja", hablar("spirit", CRONE)[0], 1,
           "la vieja y la nena comparten banco: decision del autor")

    # El degenerado del bloque, y va DE FABRICA: tipo sin rasgo `voice`, modelo
    # sin campo `voz`, y LOS DOS A LA VEZ. Cae al sorteo y no tira.
    v, why = hablar("spirit", CORPSE, moneda=2)
    t.fila("E", "    degenerado: tipo sin rasgo Y modelo sin campo -> sorteo", v, 2)
    t.fila("E", "    ... y el motivo dice que fue SORTEADA", why.startswith("SORTEADA"), True)
    t.fila("E", "    degenerado: ni tipo ni modelo ( los dos nil )",
           hablar(None, None, moneda=1)[0], 1)

    # La voz es UNA por fantasma: la segunda llamada no vuelve a decidir.
    L.execute("math.random = function() return 2 end")
    t.fila("E", "    se guarda: la 2a llamada no re-sortea",
           lua("__g:phantom_EventVoice()"), 1,
           "sortear clip por clip delataria que el sonido es una tabla")

    # =====================================================================
    print("\n  ( F ) el tipo PRE-ELEGIDO se consume UNA vez -- server_type.lua real")
    L.execute("""
        __sets = {}
        __llamadas = 0
        __typeassign = true
        PHANTASMAGORIA.ResolveTypeKey = function( ent )
            __llamadas = __llamadas + 1
            return "oni", "sorteado ( doble del arnes )"
        end
        __t = setmetatable( {}, { __index = __ENT } )
        __t.phantom_SetType = function( self, key, motivo )
            __sets[ #__sets + 1 ] = tostring( key ) .. " | " .. tostring( motivo )
            return key
        end
        __t:phantom_PreelegirTipo()
        __t:phantom_ResolveType()
    """)
    t.fila("F", "    Initialize + AdditionalInitialize: UN solo sorteo", g["__llamadas"], 1,
           "pre-elegir y volver a sortear serian dos tipos distintos")
    t.fila("F", "    y el motivo declara que vino pre-elegido",
           "pre-elegido en Initialize" in g["__sets"][1], True)

    L.execute("__t:phantom_ResolveType()")
    t.fila("F", "    re-resolver un fantasma VIVO vuelve a sortear", g["__llamadas"], 2,
           "una key guardada seria un tipo que ya no se puede cambiar")
    t.fila("F", "    y ese 2o motivo YA NO dice pre-elegido",
           "pre-elegido en Initialize" in g["__sets"][2], False)

    L.execute("__typeassign = false; __llamadas = 0")
    t.fila("F", "    typeassign 0: no pre-elige nada",
           (lua("__t:phantom_PreelegirTipo()") is None and g["__llamadas"] == 0), True,
           "el control negativo del tipo no se toca")

    # =====================================================================
    print("\n  %d comprobaciones, %d falla(s)." % (t.n, t.fallas))
    print("  grupos:  A modelo->sexo · B pool · C tipo->sexo · D cuerpo por tipo · "
          "E voz · F pre-eleccion")

    if rotos:
        pedidas = set().union(*[ALCANCE[c] for c in rotos])
        print("  grupos rojos: %s   ( se esperaban: %s )"
              % (", ".join(sorted(t.rojas)) or "ninguno", ", ".join(sorted(pedidas))))

        if not t.fallas:
            print("\n>> ⚠ EL CONTROL NO DISCRIMINA: el defecto esta puesto y todo dio verde.")
            return 1
        faltan, sobran = pedidas - t.rojas, t.rojas - pedidas
        if faltan:
            print(">> ⚠ EL CONTROL NO LLEGA: %s no se puso rojo con el defecto adentro."
                  % ", ".join(sorted(faltan)))
            return 1
        if sobran:
            print(">> ⚠ EL CONTROL SE PASA: %s se puso rojo y ese defecto no lo toca; "
                  "el arnes esta acoplado de mas." % ", ".join(sorted(sobran)))
            return 1
        print("\n>> CONTROL OK: con el defecto adentro el arnes se pone rojo, y solo donde debe.")
        return 0

    print("\n>> %s" % ("PASA" if t.fallas == 0 else "FALLA"))
    return 1 if t.fallas else 0


if __name__ == "__main__":
    sys.exit(main())
