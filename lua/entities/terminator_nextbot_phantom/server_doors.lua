--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom / PUERTAS

    LO QUE PIDIO EL AUTOR, literal: "lo unico importante es que PASE las
    puertas, y cuando lo haga que la ACTIVE y la ABRA FISICAMENTE, eso deja la
    evidencia de la huella en la puerta".

    Eso cierra una pregunta que ESTADO.md dejaba abierta a proposito -- "un
    fantasma de Phasmophobia ATRAVIESA las puertas, asi que arreglar el bashing
    y dejarlo pasar son dos disenos distintos y hay que elegir cual". La
    eleccion es la tercera y es mejor que las dos: NO atraviesa y NO rompe,
    ABRE. Atravesar seria gratis de programar y regalaria la huella, que es una
    de las 7 evidencias y la que el autor nombro como el motivo.

    POR QUE NO ALCANZA CON LO QUE LA BASE YA HACE, leido y no supuesto:

    La base SI sabe abrir puertas -- tryToOpen ( shared.lua:1249-1417 ) tiene la
    rama de prop_door_rotating en :1334 y termina en Use2, y con nuestro
    interruptor en fantasma la rama de :1387 ( "not ShouldBeEnemy( blocker )"
    -> abrir en vez de romper ) se toma siempre. Pero tryToOpen tiene UN solo
    call site, ShootblockerThink ( :1109 ), y ese traza desde GetShootPos() a lo
    largo del AIM VECTOR, 150 u ( :1094 ). O sea que la base solo ve la puerta
    que tiene APUNTADA, no la que tiene delante -- y este fantasma es
    justamente el bot que no apunta a donde camina ( TERM_FISTS = false; el
    facewalk de server.lua lo corrige en calma y NO en hunt, donde el aim se va
    al enemigo ).

    Y las dos ramas que sacan a la base de una puerta trabada piden isFists
    explicitamente ( :1336 la trabada, :1340 la que se abrio encima ), asi que
    en este fantasma estan MUERTAS. Una puerta con llave no tiene salida.

    > ESO ES LECTURA, NO DIAGNOSTICO. El sintoma que reporto el autor -- "suele
    > quedarse pegado abriendolas" -- NO esta medido, y esta sesion ya mostro lo
    > que cuesta confundir las dos cosas: en el bloque del giro culpe al gate de
    > TERM_FISTS y era la mitad equivocada. Por eso este archivo trae un
    > CRONOMETRO ( phantom_doorBlocked ) que convierte "suele quedarse pegado"
    > en segundos, y lo cuenta IGUAL cuando la puerta ya estaba abierta: si el
    > atasco es contra puertas abiertas, este arreglo no es el arreglo, y el
    > instrumento tiene que poder decirlo.

    LA FORMA: una escalera de tres peldanos, y cada peldano se CUENTA aparte
    para que la corrida diga cual hizo el trabajo. Si el peldano 1 alcanza
    siempre, los otros dos son codigo muerto y hay que sacarlos; si nunca
    alcanza, la lectura de arriba estaba mal.
---------------------------------------------------------------------------]]

---------------------------------------------------------------------------
-- Las perillas
---------------------------------------------------------------------------
-- SE LLAMABA phantasmagoria_ghost_doors Y ESO ERA UN DEFECTO GRAVE: el comando
-- que imprime el reporte se llama IGUAL, y cuando una convar y un concommand
-- comparten nombre la consola resuelve la convar y el comando queda mudo. El
-- instrumento de puertas fue INALCANZABLE toda la ronda 2 -- dos filas de la
-- planilla fallaron por eso -- y encima "phantasmagoria_ghost_doors reset", que
-- la planilla mandaba correr antes de medir, le asignaba "reset" a la convar,
-- o sea 0, o sea APAGABA la apertura justo antes de medirla. Ver la guarda en
-- PHANTASMAGORIA.AddCommand ( server.lua ), que ahora lo vuelve un error
-- ruidoso al cargar. El comando conserva el nombre; la convar cambia.
--
-- Y pasa a TRES estados, igual que phasedoors, porque ahora hay un flag por NPC
-- detras: abrir puertas deja de ser una propiedad del addon y pasa a ser una
-- propiedad de CADA fantasma ( ENT.phantom_OpensDoors ).
local cvOpen = CreateConVar( "phantasmagoria_ghost_opendoors", "1", FCVAR_ARCHIVE,
    "0 = ninguno abre ( control ) · 1 = respeta el flag phantom_OpensDoors de cada NPC · 2 = abren TODOS, ignorando el flag.", 0, 2 )

-- Aparte de cvOpen a proposito: destrabar una puerta es un cambio PERMANENTE
-- en el mapa, y es la unica cosa de este archivo que no se deshace sola. Que
-- tenga su propio interruptor deja medir "abre" y "destraba" por separado.
local cvUnlock = CreateConVar( "phantasmagoria_ghost_doorunlock", "1", FCVAR_ARCHIVE,
    "El fantasma destraba las puertas con llave que le tapan el paso. OJO: destrabar es permanente y le cambia el mapa a todos.", 0, 1 )

-- EL RUIDO, Y POR QUE ES SU PROPIO FLAG.
--
-- Pedido del autor: "un flag abrir puertas cerradas con otro flag a que no
-- hagan ruido al abrirlas". El motivo que dio importa para el diseno: oir las
-- puertas fue lo que le dejo VER el comportamiento del fantasma adentro de la
-- casa. O sea que el ruido no es un efecto de sonido: es un instrumento de
-- observacion -- y por eso el default lo deja PRENDIDO y el flag existe para
-- apagarlo cuando el fantasma tenga que ser sigiloso ( el Myling de Diseno 5,
-- que camina en silencio, es exactamente este flag ).
--
-- Son DOS fuentes de sonido distintas y las dos hay que tapar:
--   el click del bot   Use2 emite common/wpn_select.wav ( shared.lua:1238 )
--   la puerta misma    el movesound del prop/brush, que lo emite el ENGINE
-- MISMA convencion que las otras dos, a proposito: 0 control · 1 el flag · 2
-- forzado. Tres convars con tres significados distintos para el mismo numero
-- serian tres formas de equivocarse en juego, con la planilla en la mano.
local cvSilent = CreateConVar( "phantasmagoria_ghost_doorsilent", "1", FCVAR_ARCHIVE,
    "0 = ninguno hace silencio ( control ) · 1 = respeta el flag phantom_SilentDoors de cada NPC ( que arranca en false: hacen ruido ) · 2 = TODOS abren en silencio.", 0, 2 )

---------------------------------------------------------------------------
-- ATRAVESAR
---------------------------------------------------------------------------
-- Pedido del autor despues de la primera corrida: abrir no alcanza, tiene que
-- ATRAVESAR -- y que sea por NPC, porque el Alternate ( docs/ALTERNATE.md ) NO
-- puede atravesar puertas. O sea que esto no es una convar global: es un FLAG
-- de clase con una convar que lo puede pisar en las dos direcciones.
--
--   ENT.phantom_PhasesDoors = false   en el Alternate, cuando exista
--   ENT.phantom_PhasesDoors = true    en el fantasma generico ( server.lua )
--
-- Tres estados a proposito: el 0 es el control negativo del check y el 2 es la
-- rama que NO es el default -- probar el mecanismo sobre un NPC que lo tiene
-- apagado, que es lo unico que confirma que el flag es lo que decide y no otra
-- cosa.
local cvPhase = CreateConVar( "phantasmagoria_ghost_phasedoors", "1", FCVAR_ARCHIVE,
    "0 = ninguno atraviesa ( control ) · 1 = respeta el flag phantom_PhasesDoors de cada NPC · 2 = atraviesan TODOS, ignorando el flag.", 0, 2 )

-- LA MASCARA, Y POR QUE ES UNA CONVAR Y NO UNA CONSTANTE.
--
-- El mecanismo NO se invento: hay DOS precedentes en el arbol y los dos usan
-- SetSolidMask, que es la mascara con la que el bot traza SU PROPIO movimiento
-- ( la base la fija al spawnear, terminator_nextbot_base/init.lua:110, desde
-- ENT.SolidMask = MASK_NPCSOLID en :68 ):
--
--   wraithcloaking.lua:133          MASK_NPCSOLID_BRUSHONLY
--   HIM, server.lua:630             MASK_NPCWORLDSTATIC
--
-- Y NO son la misma eleccion: difieren en CONTENTS_MOVEABLE, que es el bit que
-- llevan los BRUSH ENTITIES. La puerta que trabo al fantasma en la corrida del
-- autor es un func_door_rotating, que es exactamente eso -- asi que con la
-- mascara del wraith seguiria trabado y con la de HIM no.
--
-- ESO ES LECTURA DE UNA CONSTANTE DEL ENGINE, no una medicion, y este proyecto
-- ya pago dos veces por afirmar el contenido de una constante sin mirar el
-- numero. Dos cosas salen de ahi: la convar, para que el A/B sea un comando; y
-- que el instrumento imprima el AND contra CONTENTS_MOVEABLE, que convierte la
-- lectura en un numero en pantalla.
local cvPhaseMask = CreateConVar( "phantasmagoria_ghost_phasemask", "1", FCVAR_ARCHIVE,
    "1 = MASK_NPCWORLDSTATIC ( como HIM: pasa props Y brush entities como func_door_rotating ). 0 = MASK_NPCSOLID_BRUSHONLY ( como el wraith de la base: pasa props y NO brush entities ).", 0, 1 )

---------------------------------------------------------------------------
-- Numeros
---------------------------------------------------------------------------
local THINK_EVERY = 0.1  -- el Think de la tarea corre hasta 3 veces por tick

-- El alcance del sondeo ES PROPORCIONAL A LA VELOCIDAD, y esa es la unica
-- constante de este archivo que no es arbitraria: una prop_door_rotating tarda
-- ~1 s en abrirse, y a 280 u/s el fantasma cruza 280 u en ese segundo. Un
-- alcance fijo corto la abre cuando ya la choco -- que es exactamente el
-- sintoma reportado. Medio segundo de anticipacion, con piso y techo.
local LOOKAHEAD_SECONDS = 0.5
local LOOKAHEAD_MIN     = 60
local LOOKAHEAD_MAX     = 200

-- Por debajo de esto cuenta como "trabado". Mismo umbral que usa el facewalk y
-- que la base usa como frontera de "casi quieto" ( 30 u/s,
-- term_DefaultSpeedToAimAtProps = 30^2 contra Length2DSqr ).
local STUCK_SPEED = 30

-- Los peldanos 2 y 3 de la escalera. El 1 ( Use2 ) es el camino de la base y
-- tiene que alcanzar; los otros dos existen para que una puerta no sea nunca un
-- muro, y para que la corrida diga si hicieron falta.
local FORCE_AFTER = 1.5

-- No volver a tocar la MISMA puerta antes de esto. Una prop_door_rotating
-- responde a Use como TOGGLE: dos Use seguidos la abren y la cierran, que es
-- otra forma de quedarse pegado.
local RETRY_EVERY = 1.2

-- Cuanto despues se vuelve a leer el estado para saber si la puerta ABRIO. Sin
-- esto el contador diria "intente" y se leeria como "abri" -- medir la
-- intencion no es medir el resultado.
local VERIFY_AFTER = 0.9

-- La huella dura lo mismo que en el juego ( Diseno 8.5 usa 60 s ).
local PRINT_LIFE = 60

-- A que distancia de la hoja se vuelve no-solido. CORTO A PROPOSITO: el
-- sondeo llega hasta 200 u, pero ir no-solido desde tan lejos es peligroso --
-- con MASK_NPCWORLDSTATIC el fantasma tampoco choca con brush entities QUE NO
-- SON PUERTAS, y en un mapa cuyo piso sea un func_brush se caeria del mundo. Se
-- atraviesa cuando ya casi la toca, no cuando la ve.
local PHASE_RANGE = 45

-- Techo duro. Un fantasma no-solido para siempre es peor que uno trabado:
-- trabado se ve, no-solido se cae del mapa. Si esto salta, el instrumento lo
-- cuenta aparte y algo hay que mirar.
local PHASE_MAX = 5

-- Y su enfriamiento: sin esto el techo no sirve de nada. Si el fantasma sigue
-- pegado a la puerta, al tick siguiente vuelve a entrar en rango y re-atraviesa
-- en el mismo frame -- el contador subiria y el engine no llegaria a resolver
-- nada. Un segundo solido es lo que le da la chance de resolverlo.
local PHASE_COOLDOWN = 1

-- Cuanto se sigue atravesando DESPUES de perder la puerta de vista. Existe por
-- algo que NO se pudo medir sin el juego: que devuelve un TraceHull que arranca
-- adentro de la hoja. Deberia devolver la puerta en tr.Entity, y si devolviera
-- el mundo, el fantasma se volveria solido justo estando adentro de ella. La
-- gracia hace que ese caso no dependa de la respuesta: a 66 u/s son 33 u de
-- margen y a 280 son 140, con una hoja que tiene 4 de espesor.
local PHASE_GRACE = 0.5

-- ⚠ ACA VIVIA STUCK_PHASE_AFTER, EL RESCATE DE LA HOJA QUE SE ABRE ENCIMA, Y LA
-- RONDA 6 LO RETIRO. Se deja escrito para que nadie lo vuelva a escribir:
--
-- La rama pedia estar trabado > 2 s contra una puerta ABIERTA para prender el
-- atravesado. Nunca subio: `fasesPorAtasco` marco 0 en toda la sesion, tambien
-- en las lecturas con `atravesar 1`. Y el motivo es estructural, no de tuning:
-- el contador solo sube `if not self.phantom_Phasing`, y para una hoja abierta
-- A 0 u la regla de cercania ( distancia <= PHASE_RANGE ) ya prendio el
-- atravesado en el primer tick. **La rama no podia dispararse justo en el caso
-- para el que se escribio, porque la cercania llega antes.** Para que subiera
-- haria falta estar trabado contra una puerta abierta a MAS de 45 u, que es un
-- atasco contra otra cosa y donde atravesar la puerta no ayuda.
--
-- Lo que la ronda 6 SI midio, y por eso esto se puede sacar sin perder nada, es
-- el A/B del atravesado contra la misma trampa:
--
--     phasedoors 1  ->  peor 0,7 - 0,9 s
--     phasedoors 0  ->  peor 3,6 s -> 5,2 s, con velocidad 0 u/s
--
-- O sea: la hoja que se abre encima es una trampa real y **la cercania sola la
-- resuelve**. El segundo disparador para el mismo phasing no agregaba nada.

local DOOR_CLASSES = {
    [ "prop_door_rotating" ] = true,
    [ "func_door" ]          = true,
    [ "func_door_rotating" ] = true,
}

-- Cuantos saltos de `GetParent()` se suben cuando el sondeo pega en un PANEL
-- parenteado en vez de en la hoja ( ver el bloque grande de doorAhead ).
--
-- ⚠ EXISTE UNA SOLA VEZ A PROPOSITO, y no es cosmetico: hay DOS lugares que
-- suben la misma cadena -- doorAhead, que encuentra la puerta, y la huella, que
-- pregunta si el trace pego en esa puerta o en uno de sus paneles. Si los dos
-- topes no fueran el mismo numero, una puerta encontrada en el salto 4 no
-- dejaria huella porque el otro lado se rinde en el 3, y el sintoma seria
-- "abre pero no deja evidencia" en una sola puerta del mapa.
local PARENT_HOPS = 4

-- ¿`ent` ES la puerta, o uno de sus paneles parenteados? Existe porque el
-- `tr` que devuelve doorAhead pego en el HIJO ( ver la advertencia de ahi ), asi
-- que un `tr.Entity == door` pelado es FALSO justo en las puertas que el arreglo
-- del padre vino a rescatar.
local function esLaPuertaOSuPanel( ent, door )
    if not IsValid( ent ) or not IsValid( door ) then return false end

    local e = ent

    for _ = 1, PARENT_HOPS + 1 do
        if e == door then return true end
        if not IsValid( e ) then return false end

        e = e:GetParent()

    end

    return false
end

---------------------------------------------------------------------------
-- Leer el estado de una puerta
---------------------------------------------------------------------------
-- SON DOS FAMILIAS CON DOS CAMPOS DISTINTOS, y la base ya las trata por
-- separado ( shared.lua:1335 lee m_eDoorState, :1378 lee m_toggle_state ):
--
--   prop_door_rotating   m_eDoorState     0 cerrada · 1 abriendo · 2 abierta · 3 cerrando
--   func_door*           m_toggle_state   0 arriba/abierta · 1 abajo/cerrada · 2 subiendo · 3 bajando
--
-- Los dos enums son del ENGINE, o sea de un tercero, y estan leidos del uso que
-- les da la base y no de la memoria: :1337 compara "doorState ~= 2" para "no
-- esta abierta" y :1378 compara "m_toggle_state == 1" para "esta cerrada".
--
-- Devuelve el numero crudo ADEMAS del veredicto: si alguna vez un mapa trae una
-- puerta que no encaja, el instrumento imprime el numero y se ve.
local function readDoor( door )
    local class = door:GetClass()

    if class == "prop_door_rotating" then
        local state = door:GetInternalVariable( "m_eDoorState" )

        return {
            campo    = "m_eDoorState",
            crudo    = state,
            cerrada  = state == 0 or state == 3,
            abriendo = state == 1,
            abierta  = state == 2,
            locked   = door:GetInternalVariable( "m_bLocked" ) == true,
        }
    end

    local state = door:GetInternalVariable( "m_toggle_state" )

    return {
        campo    = "m_toggle_state",
        crudo    = state,
        cerrada  = state == 1 or state == 3,
        abriendo = state == 2,
        abierta  = state == 0,
        locked   = door:GetInternalVariable( "m_bLocked" ) == true,
    }
end

-- readDoor NO se exporta, y se fue en la ronda 6: no lo consumia nadie, y un
-- export sin consumidor se lee como API estable. Cuando el bloque de la linterna
-- UV lo necesite, volver a ponerlo es una linea.

---------------------------------------------------------------------------
-- Las huellas
---------------------------------------------------------------------------
-- Diseno 8.5 ya fijo la forma y aca se respeta al pie: el SERVIDOR guarda la
-- huella como DATO y no pinta nada; el cliente la dibuja solo mientras la UV
-- apunta. Ese dibujo NO es de este bloque: vive en
-- lua/autorun/phantasmagoria_evidencia.lua ( escrito el 2026-08-18 ), que
-- escucha el hook de mas abajo, la networkea y la dibuja bajo el gate
-- PHANTASMAGORIA.HoldingUV. Aca sigue estando solo el productor.
--
-- Los campos son los de 8.5 ( pos, normal, hand, expire ) mas dos: la puerta y
-- el fantasma. La puerta porque una prop_door_rotating GIRA, y una huella
-- guardada como punto de mundo queda flotando en el aire apenas la puerta se
-- mueve -- es la leccion de artagdoll ( un punto de mundo caduca en
-- milisegundos ) aplicada a un objeto que rota por diseno. Guardar la puerta
-- deja que el dibujo la siga; guardar solo pos, no.
PHANTASMAGORIA.Prints = PHANTASMAGORIA.Prints or {}

-- SON DOS MOMENTOS Y NO UNO, y separarlos arregla dos defectos que la primera
-- version de este archivo tenia juntos:
--
--   ① La huella se guardaba al INTENTAR abrir, no al abrir. Un Use2 que la
--      lista negra descarta, o que el hook TerminatorBlockUse veta, dejaba
--      huella igual: el contador media la intencion.
--   ② El punto se pasaba a coordenadas de la puerta con los angulos de la
--      puerta EN ESE INSTANTE. Si el guardado se hacia despues, la puerta ya
--      habia girado y el mismo punto de mundo daba otro punto local -- la
--      huella terminaba fuera de la hoja. Es la leccion de artagdoll ( un punto
--      de mundo caduca en milisegundos ) con la vuelta de tuerca de que aca el
--      sistema de referencia es lo que se mueve.
--
-- MakePrint corre EN EL CONTACTO, cuando la puerta todavia no se movio, y
-- congela lo relativo. CommitPrint corre cuando ya se sabe que abrio.
-- DE DONDE SALE EL PUNTO, Y POR QUE NO PUEDE SALIR DEL SONDEO
--
-- La r1 dejaba la huella en `tr.HitPos` del sondeo de doorAhead, y el autor lo
-- reporto mirandolo: *"la huella esta en la parte de abajo de la puerta a unos
-- centimetros de la puerta en vez de en ella misma"*. Las dos mitades de esa
-- frase son la misma causa y estaba escrita en el propio sondeo: **es un
-- TraceHull, no una linea**.
--
--   ① El HitPos de un hull es donde toca EL HULL, no donde toca la linea: queda
--     separado del plano por medio ancho del bot ( ~16 u ), o sea "a unos
--     centimetros de la puerta".
--   ② El hull arranca en `GetPos() + 8` y sube hasta 56, y su contacto se
--     resuelve abajo: la huella cae a la altura de los TOBILLOS.
--
-- Y el sondeo tiene que seguir siendo un hull -- una linea entra por el hueco
-- entre la hoja y el marco y no ve la puerta ( eso ya esta medido arriba ). O
-- sea que no es un parametro para ajustar: **son dos preguntas distintas**.
-- Encontrar la puerta quiere un volumen; dejar una mano quiere un punto.
--
-- Asi que la huella tira SU PROPIO trace, de linea, a la altura de una mano.
-- Si esa linea no llega ( entra por el hueco, o la hoja quedo en diagonal ), el
-- fallback NO es volver al punto del hull: es `NearestPoint` de la hoja sobre
-- la mano, que por construccion cae SOBRE la superficie -- que es justo lo que
-- el punto del hull no garantiza.
local HAND_HEIGHT = 48   -- u sobre los pies del bot: el pecho/mano de un ValveBiped de 72
local HAND_BACKOFF = 24   -- u que el tiro retrocede desde la hoja para arrancar AFUERA de ella.
                          -- Corto a proposito: arrancar lejos puede empezar del otro lado de
                          -- una pared cercana, y entonces el trace pega en la pared y no en la puerta.

-- ⚠⚠ LA r2 MIDIO ESTO Y LA PRIMERA VERSION ERRABA CASI SIEMPRE: de las cuatro
-- huellas que dejo el fantasma, **tres salieron por el fallback** ( `via
-- cercano` ) y una sola por el trace de linea. Se veian bien -- el fallback cae
-- sobre la superficie por construccion -- pero el camino que da la normal REAL
-- no estaba corriendo, y eso solo se supo porque el reporte imprime el `via`.
--
-- La causa es la misma que doorAhead ya tenia escrita para justificar su hull:
-- *"una linea entra por el hueco entre la puerta y el marco y no ve nada"*. Yo
-- tire la linea HACIA ADELANTE DEL BOT, que es exactamente el tiro que se cuela.
--
-- La linea ahora apunta A LA HOJA: se pide el punto mas cercano de la puerta a
-- la mano, se arranca 24 u por FUERA de ese punto y se traza hacia adentro. Asi
-- el tiro no depende de como este parado el bot, y pega en la cara que mira
-- hacia el -- que es la cara donde la mano tiene que quedar.
function PHANTASMAGORIA.HandPointOnDoor( ghost, door, trHull )
    if not IsValid( ghost ) or not IsValid( door ) then return nil end

    local mano = ghost:GetPos() + Vector( 0, 0, HAND_HEIGHT )

    -- La superficie de referencia es la que el HULL toco ( puede ser el panel
    -- parenteado y no la hoja: el panel ES parte de la puerta ), y si no toco
    -- nada util, la puerta misma.
    local sup      = ( trHull and esLaPuertaOSuPanel( trHull.Entity, door ) ) and trHull.Entity or door
    local objetivo = sup:NearestPoint( mano )
    local haciaMano = mano - objetivo

    -- Mano adentro de la hoja ( pasa cuando el fantasma esta ATRAVESANDO ): no
    -- hay un "hacia afuera" que sacar de la geometria, asi que se usa el cuerpo.
    if haciaMano:LengthSqr() < 0.01 then
        haciaMano = ghost:GetForward() * -1

    end

    haciaMano:Normalize()

    local linea = util.TraceLine( {
        start  = objetivo + haciaMano * HAND_BACKOFF,
        endpos = objetivo - haciaMano * 8,
        mask   = MASK_SOLID,
        filter = ghost,
    } )

    if linea.Hit and esLaPuertaOSuPanel( linea.Entity, door ) then
        return linea.HitPos, linea.HitNormal, "linea"

    end

    -- El fallback sigue existiendo -- algo puede meterse entre el punto de
    -- arranque y la hoja -- y ahora su normal sale de la misma geometria que el
    -- tiro: del punto de la superficie HACIA la mano.
    return objetivo, haciaMano, "cercano"

end

function PHANTASMAGORIA.MakePrint( ghost, door, pos, normal )
    -- El punto se guarda RELATIVO a la puerta justamente porque la puerta gira.
    -- El absoluto se recompone con LocalToWorld a la hora de dibujarlo.
    local lpos, lang = WorldToLocal( pos, normal:Angle(), door:GetPos(), door:GetAngles() )

    return {
        ent    = door,
        ghost  = ghost,
        pos    = pos,        -- absoluto al momento del contacto, para el instrumento
        lpos   = lpos,       -- relativo a la puerta: el que sirve para dibujar
        lang   = lang,
        normal = normal,
        hand   = math.random( 1, 4 ),
    }
end

function PHANTASMAGORIA.CommitPrint( p )
    local prints = PHANTASMAGORIA.Prints
    local now    = CurTime()

    -- Poda antes de agregar: sin esto la tabla crece toda la partida.
    for i = #prints, 1, -1 do
        local old = prints[ i ]
        if old.expire < now or not IsValid( old.ent ) then table.remove( prints, i ) end

    end

    p.expire = now + PRINT_LIFE
    prints[ #prints + 1 ] = p

    -- El enganche para el bloque de la UV. Ya tiene consumidor:
    -- lua/autorun/phantasmagoria_evidencia.lua lo escucha y networkea la huella.
    --
    -- ⚠ EL TERCER ARGUMENTO SE AGREGO EL 2026-08-18 Y NO ES OPCIONAL. Con
    -- ( ghost, door ) solamente, el consumidor sabe QUE paso pero no tiene la
    -- huella: no hay forma de llegar a `lpos`, `hand` ni `expire` desde ahi, y
    -- pescar `prints[ #prints ]` seria adivinar cual es la ultima. El sintoma
    -- de sacarlo es la clase de falla cara: el contador de huellas sube y la
    -- puerta se ve limpia. El consumidor lo comprueba y grita si llega nil.
    hook.Run( "PhantasmagoriaGhostUsedDoor", p.ghost, p.ent, p )

end

---------------------------------------------------------------------------
-- Encontrar la puerta que tapa el paso
---------------------------------------------------------------------------
-- TRES fuentes de direccion, en orden, y la que se uso se GUARDA para que el
-- instrumento la imprima. No es adorno: la hipotesis de arriba dice que la base
-- falla porque mira el aim en vez de la marcha, asi que "con que direccion
-- sondeamos" es precisamente el dato en disputa.
--
--   1. el PATH        a donde el cerebro quiere ir. Es la buena.
--   2. la MARCHA      loco:GetVelocity(), cuando no hay path
--   3. el CUERPO      GetForward(), cuando esta quieto -- que es justo el caso
--                     del atasco, donde las dos de arriba dan un vector nulo
local function forwardDir( ghost )
    local path = ghost:GetPath()

    if path and path:IsValid() then
        local goal = path:GetCurrentGoal()

        if goal and goal.pos then
            local delta = goal.pos - ghost:GetPos()
            delta.z = 0

            if delta:LengthSqr() > 1 then
                return delta:GetNormalized(), "path"

            end
        end
    end

    local loco = ghost.loco

    if loco then
        local vel = loco:GetVelocity()
        vel.z = 0

        if vel:Length() > 5 then
            return vel:GetNormalized(), "marcha"

        end
    end

    local fwd = ghost:GetForward()
    fwd.z = 0

    return fwd:GetNormalized(), "cuerpo"

end

-- El sondeo. Un TraceHull con el cuerpo del bot, no una linea: una linea entra
-- por el hueco entre la puerta y el marco y no ve nada.
local function doorAhead( ghost )
    local dir, src = forwardDir( ghost )

    local reach = math.Clamp( ghost:GetCurrentSpeed() * LOOKAHEAD_SECONDS, LOOKAHEAD_MIN, LOOKAHEAD_MAX )

    local mins, maxs = ghost:GetCollisionBounds()

    -- El techo del hull se baja a 64: con la altura entera ( 72 ) el marco de
    -- una puerta cuenta como choque y el sondeo devuelve la pared en vez de la
    -- hoja.
    local start = ghost:GetPos() + Vector( 0, 0, 8 )

    local tr = util.TraceHull( {
        start  = start,
        endpos = start + dir * reach,
        mins   = Vector( mins.x, mins.y, 0 ),
        maxs   = Vector( maxs.x, maxs.y, math.min( maxs.z, 64 ) - 8 ),
        mask   = MASK_SOLID,
        filter = ghost,
    } )

    local hit = tr.Entity

    if IsValid( hit ) and DOOR_CLASSES[ hit:GetClass() ] then
        ghost.phantom_doorBlocker = nil
        return hit, tr, src, reach

    end

    ---------------------------------------------------------------------------
    -- ⚠⚠⚠ LA PUERTA PUEDE SER EL **PADRE** DE LO QUE TOCAMOS -- y esta era la
    -- causa real del reporte de la r2, tres rondas mal adjudicada al vidrio
    ---------------------------------------------------------------------------
    -- El autor: *"quedan atrapados en dos puertas que tienen vidrios, ni siquiera
    -- la abren, son las dos puertas para ir a la piscina"*. Se le echo la culpa a
    -- la TRANSPARENCIA ( el panel deja pasar la vista y no el cuerpo, que es un
    -- modo de falla real de nextbot ) y era falso.
    --
    -- LO QUE PASA, leido del lump de ENTIDADES del .bsp: esas puertas estan
    -- armadas como un `func_door_rotating` con sus paneles PARENTEADOS encima.
    --
    --   door_terrace01  func_door_rotating   distance 90 · speed 100 · wait 4
    --      hijos: 2 prop_dynamic ( manijas ) · func_breakable *139 ( el VIDRIO )
    --             · func_brush *222 ( el MARCO )
    --   door_veranda01  func_door_rotating   idem, con *217 y *249
    --
    -- El sondeo pega SIEMPRE contra un hijo -- son los que sobresalen -- y el
    -- hijo es `func_breakable` / `func_brush`, que no estan en DOOR_CLASSES. La
    -- puerta, cuya clase SI esta en la lista, queda detras de sus propios
    -- paneles y el bot no la ve nunca. *El sintoma era correcto y la causa que se
    -- le adjudico era otra entidad.*
    --
    -- ⚠ POR QUE SE SUBE AL PADRE Y **NO** SE AGRANDA `DOOR_CLASSES`: porque el
    -- autor lo veto con motivo -- *"Peligroso hacer que las ventanas se puedan
    -- traspasar, eso no deberia hacerse para que el ghost no escape"* -- y porque
    -- `func_brush` es la clase con que se hacen paredes. Medido sobre el mapa:
    -- de 181 `func_breakable` solo **5** tienen una puerta arriba, y de 11
    -- `func_brush` solo **2**. O sea que esto alcanza a 7 entidades y deja 176
    -- ventanas y 9 paredes exactamente como estaban. Un ensanche de la lista
    -- blanca habria tocado las 192.
    --
    -- ⚠ MEDIDO EN JUEGO ANTES DE ESCRIBIR ESTO, y era la unica suposicion del
    -- arreglo: que `GetParent()` devuelva la puerta en RUNTIME, no solo que el
    -- `parentname` este en el BSP ( que es lo que escribio el compilador, no lo
    -- que resuelve el engine ). En el realm SERVER, que es donde corre esta
    -- funcion: `func_brush [466]` -> `func_door_rotating [89]` y
    -- `func_breakable [256]` -> el MISMO `[89]`. El engine es un tercero y esto
    -- se pregunto en vez de asumirse ( COR-5 ).
    --
    -- Bucle acotado y no un solo salto: en este mapa la cadena es de UN nivel,
    -- pero un mapa puede anidar y cuatro saltos con guarda no cuestan nada. El
    -- tope tambien protege de un ciclo de parenteo mal armado por un mapper.
    if IsValid( hit ) then
        local padre = hit:GetParent()

        for _ = 1, PARENT_HOPS do
            if not IsValid( padre ) then break end

            if DOOR_CLASSES[ padre:GetClass() ] then
                -- se limpia el blocker igual que en la rama de arriba: esto ES
                -- una puerta reconocida, no un obstaculo sin identificar
                ghost.phantom_doorBlocker = nil

                -- ⚠ SE DEVUELVE `tr` SIN TOCAR, Y SE DICE: el trace pego en el
                -- PANEL, no en la hoja. `tr.HitPos` / `tr.Fraction` describen el
                -- hijo. Para los usos GEOMETRICOS es correcto -- el panel esta EN
                -- la puerta, asi que la distancia es la misma cosa a centimetros.
                --
                -- ⚠⚠ Y ESTE RENGLON YA COBRO UNA VEZ: la primera version decia
                -- "es correcto para lo que los llamadores hacen hoy" y era FALSO,
                -- porque un llamador no usaba la geometria del `tr` sino su
                -- IDENTIDAD -- `if tr.Entity == door` para armar la huella, que
                -- con el padre devuelto da falso siempre. El autor lo vio en
                -- juego: *"ya abre las puertas, pero parece no dejar huellas"*.
                -- Arreglado con `esLaPuertaOSuPanel`. La leccion, para el
                -- proximo que agregue un uso: **un `==` entre entidades tambien
                -- es un uso del trace**, y revisar "los usos de tr" mirando solo
                -- HitPos y Fraction deja afuera justo el que se rompe.
                return padre, tr, src, reach

            end

            padre = padre:GetParent()

        end
    end

    ---------------------------------------------------------------------------
    -- ⚠⚠ LO QUE **NO** ES UNA PUERTA TAMBIEN SE GUARDA -- r3, fila 06
    ---------------------------------------------------------------------------
    -- El autor reporto: *"quedan atrapados en dos puertas que tienen vidrios, ni
    -- siquiera la abren, son las dos puertas para ir a la piscina"*.
    --
    -- Y el instrumento de puertas es CIEGO a eso por construccion: cuando el
    -- sondeo pega en algo que no esta en la lista blanca de tres clases, esta
    -- funcion devuelve `nil`, el cronometro de atasco contra puertas se pone en
    -- CERO, y el reporte imprime `delante ninguna puerta · peor 0,0 s`. O sea que
    -- **"no hay nada adelante" y "hay algo que no reconozco" escriben la misma
    -- linea** -- y el eje 6 es exactamente la diferencia entre las dos.
    --
    -- Esto no cambia comportamiento: guarda el hit crudo y sigue devolviendo nil.
    -- Va ANTES del return y NO mueve el return ni el orden de nada, porque la
    -- rama que llama a esta funcion tambien dispara `phantom_PhaseRelease` y
    -- `phantom_PhaseTimeout`, que son las dos que impiden que el fantasma quede
    -- no-solido para siempre.
    if IsValid( hit ) then
        -- ⚠⚠⚠ UN SER NO ES GEOMETRIA, Y MEZCLARLOS HIZO QUE ESTE INSTRUMENTO
        -- CONTARA AL QUE LO ESTABA MIDIENDO. Corrida del autor, r3 2026-08-10:
        -- se paro delante del fantasma para observarlo, el sondeo le pego A EL, y
        -- el reporte imprimio `player #1 targetname 'SEPULDOSKY'` seguido del
        -- consejo entero de DOOR_CLASSES -- *"si hay que agregarla, hay que tocar
        -- LAS DOS copias de la tabla"* -- sobre un JUGADOR. Y el contador de
        -- abajo subio 20 -> 84 -> 146 mientras el bot lo miraba a el.
        --
        -- Ese contador es el que la r2 uso para senalar las puertas con vidrio.
        -- O sea que **el acto de pararse a observar inflaba el numero que se iba
        -- a leer**: la escena que el instrumento existe para detectar ( una hoja
        -- que la lista blanca no reconoce ) y la escena mas comun de todas ( hay
        -- alguien parado adelante ) escribian el mismo renglon y el mismo total.
        --
        -- Se separan y se cuentan aparte. `esSer` decide por lo que la entidad
        -- ES, no por su clase: un nextbot NO es `IsNPC()` -- los otros fantasmas
        -- incluidos --, y esa rama ya se pago en server_collision.lua.
        local esSer = hit:IsPlayer() or hit:IsNPC() or hit:IsNextBot()

        ghost.phantom_doorBlocker = {
            clase   = hit:GetClass(),
            nombre  = hit:GetName(),
            indice  = hit:EntIndex(),
            modelo  = hit:GetModel(),
            frac    = tr.Fraction,
            dist    = math.Round( reach * tr.Fraction ),
            cuando  = CurTime(),
            esSer   = esSer,
        }

        -- ⚠ SE GUARDA CONTRA EL CONTADOR, **NO** CON UN `return` TEMPRANO. La
        -- primera version de este arreglo cortaba aca con `return nil` y era un
        -- defecto nuevo: esta funcion termina en `return nil, tr, src, reach`
        -- -- CUATRO valores --, asi que un `return nil` pelado le come tres al
        -- que llama. Es literal lo que el encabezado de este bloque advierte:
        -- *"NO mueve el return ni el orden de nada"*. Un arreglo que respeta la
        -- advertencia escrita al lado cuesta una linea; ignorarla, una ronda.
        if esSer then
            ghost.phantom_doorSer = ( ghost.phantom_doorSer or 0 ) + 1

        else

        -- ⚠⚠ CAMPO PROPIO Y NO `phantom_doorStats`, Y ES UN ARREGLO DE LA
        -- REVISION DE ESTA MISMA TANDA. La primera version hacia
        -- `local s = ghost.phantom_doorStats; if s then ... end`, y esa tabla la
        -- crea UNICAMENTE `stats()`, cuyos call sites estan TODOS detras de una
        -- puerta ya reconocida. O sea que en la escena exacta para la que este
        -- contador se escribio -- un fantasma trabado contra una hoja que la
        -- lista blanca NO reconoce, y que por lo tanto puede no haber visto una
        -- puerta valida en toda su vida -- el contador **no podia subir**, y la
        -- linea del reporte quedaba ademas debajo del early return de `st`.
        --
        -- *Un contador cuya precondicion la apaga el mismo escenario que vino a
        -- medir es un cero que no significa nada.* Y el arreglo obvio
        -- ( llamar `stats( ghost )` aca ) tampoco servia: `stats` es un local
        -- declarado DESPUES de esta funcion, asi que en este punto vale nil.
        ghost.phantom_doorNoPuerta = ( ghost.phantom_doorNoPuerta or 0 ) + 1

        end

    elseif tr.Hit then
        -- Pego en el MUNDO ( `IsValid` es false sobre worldspawn en GMod ): un
        -- brush, o un prop estatico horneado. Se distingue del caso de arriba
        -- porque ahi hay una entidad a la que se le puede preguntar cosas y aca
        -- no, y las dos escenas piden arreglos distintos.
        ghost.phantom_doorBlocker = {
            clase  = "( el MUNDO: brush o prop estatico )",
            indice = 0,
            frac   = tr.Fraction,
            dist   = math.Round( reach * tr.Fraction ),
            cuando = CurTime(),
        }

    else
        ghost.phantom_doorBlocker = nil

    end

    return nil, tr, src, reach

end

-- "Tengo una puerta ENCIMA", que no es lo mismo que "tengo una puerta
-- adelante": una hoja que el fantasma esta atravesando queda a los costados y
-- atras, y el sondeo direccional no la ve. Es un hull de largo cero con el
-- cuerpo del bot: lo unico que puede contestar si volver a ser solido lo
-- dejaria adentro de un solido.
local function doorOverlapping( ghost )
    local mins, maxs = ghost:GetCollisionBounds()
    local pos        = ghost:GetPos() + Vector( 0, 0, 8 )

    local tr = util.TraceHull( {
        start  = pos,
        endpos = pos,
        mins   = Vector( mins.x, mins.y, 0 ),
        maxs   = Vector( maxs.x, maxs.y, math.min( maxs.z, 64 ) - 8 ),
        mask   = MASK_SOLID,
        filter = ghost,
    } )

    local hit = tr.Entity

    return IsValid( hit ) and DOOR_CLASSES[ hit:GetClass() ] == true

end

---------------------------------------------------------------------------
-- El cerebro de la cosa
---------------------------------------------------------------------------
-- `reabrio` y `fasesPorAtasco` estaban aca hasta la ronda 6 y se fueron con sus
-- ramas: los dos marcaron 0 en las nueve lecturas, y no por falta de
-- oportunidad sino porque el atravesado por cercania llega antes que los dos.
-- El detalle esta donde vivian.
local function stats( ghost )
    ghost.phantom_doorStats = ghost.phantom_doorStats or {
        vistas = 0, intentos = 0, use = 0, unlock = 0, away = 0, open = 0,
        abrio = 0, fallo = 0, huellas = 0, fases = 0, fasesLargas = 0,
        silencios = 0, silenciosBase = 0, silenciosHermanas = 0, vetadas = 0,
    }

    return ghost.phantom_doorStats

end

---------------------------------------------------------------------------
-- Atravesar: quien puede, y el interruptor
---------------------------------------------------------------------------
-- LAS TRES CAPACIDADES SE RESUELVEN CON LA MISMA FUNCION, y eso no es
-- economia: son tres perillas con la misma convencion ( 0 control · 1 el flag ·
-- 2 forzado ) y tres copias de esta logica serian tres lugares donde una puede
-- quedar con la precedencia al reves sin que nada lo note.
--
-- Devuelve DOS cosas y la segunda es el motivo, porque "no atraviesa" tiene
-- causas distintas que desde afuera se ven igual: la convar, el flag del NPC, o
-- que ni siquiera haya puerta. El instrumento imprime el motivo.
local function resolve( ent, campo, cv, siDefault )
    local mode = cv:GetInt()

    if mode == 0 then return false, "la convar " .. cv:GetName() .. " esta en 0 ( control: nadie )" end
    if mode == 2 then return true, "la convar " .. cv:GetName() .. " esta en 2 ( forzado, ignora el flag )" end

    -- ANDAMIO: el override de consola, que gana sobre el campo. Existe porque en
    -- la ronda 3 el autor no pudo probar los flags -- el lua_run que le di
    -- escribe en la ENTIDAD, y cada fantasma nuevo nace con el default de la
    -- clase, asi que el override se perdia al respawnear. Va aca y no en
    -- AdditionalInitialize a proposito: asi alcanza tambien a los que ya
    -- estaban vivos, sin recorrer nada.
    local over = PHANTASMAGORIA.FlagOverrides[ campo ]

    if over ~= nil then
        return over, "el override de consola ( phantasmagoria_ghost_flag ) dice " .. ( over and "SI" or "NO" )

    end

    local flag = ent[ campo ]

    if flag == true then return true, "el flag " .. campo .. " del NPC dice SI" end
    if flag == false then return false, "el flag " .. campo .. " del NPC dice NO" end

    -- Nil NO es lo mismo que el default aunque se comporte igual: significa que
    -- una subclase se olvido de declararlo. Se dice, para que se vea.
    return siDefault, "el flag " .. campo .. " es nil ( la subclase no lo declaro; se asume " ..
        ( siDefault and "que SI" or "que NO" ) .. " )"

end

-- Compartido porque server_speed.lua tiene su propia perilla con la misma
-- convencion ( caminar o correr cazando ), y dos copias de esta funcion serian
-- dos precedencias que pueden divergir.
PHANTASMAGORIA.ResolveFlag = resolve

function ENT:phantom_CanPhaseDoors()
    return resolve( self, "phantom_PhasesDoors", cvPhase, true )

end

function ENT:phantom_CanOpenDoors()
    return resolve( self, "phantom_OpensDoors", cvOpen, true )

end

-- El unico de los tres cuyo default es NO: hoy hacen ruido, y el ruido es lo
-- que le dejo al autor ver el comportamiento adentro de la casa.
function ENT:phantom_WantsSilentDoors()
    return resolve( self, "phantom_SilentDoors", cvSilent, false )

end

---------------------------------------------------------------------------
-- EL VETO: que "no abre" signifique NO ABRE
---------------------------------------------------------------------------
-- DEFECTO MEDIDO EN LA RONDA 3, y la causa no estaba en nuestro codigo sino en
-- lo que nuestro codigo NO cubria. Con phantasmagoria_ghost_opendoors 0 el
-- instrumento decia "abre NO" -- correcto, nuestra escalera no corria -- y el
-- autor reporto que "sigue abriendo las puertas aunque este desactivado". LAS
-- DOS COSAS ERAN CIERTAS: la base tambien abre puertas, por su cuenta.
-- tryToOpen ( shared.lua:1249 ) termina en Use2 y lo llama ShootblockerThink
-- cada 0,1 s. Apagar nuestra escalera nunca iba a apagar la suya.
--
-- El punto de intercepcion es PUBLICO y vive adentro del propio Use2:
--     local block = hook.Run( "TerminatorBlockUse", self, toUse )   ( :1221 )
-- asi que el veto se pone ahi y no duplicando Use2.
--
-- LA LECCION, que ya tiene familia en este proyecto: APAGAR NUESTRA
-- IMPLEMENTACION NO ES APAGAR EL COMPORTAMIENTO cuando el comportamiento
-- tambien vive en el tercero. Un flag que dice "no abre" tiene que vetar TODOS
-- los caminos, no solo el que escribimos -- y el instrumento decia la verdad
-- sobre lo nuestro mientras el juego mostraba otra cosa, que es el modo de
-- falla mas caro de todos. Pariente de "saltear no es apagar".
--
-- Y LA MISMA LECCION, SIN APLICAR, ERA EL AGUJERO DEL SILENCIO -- revisado con
-- ojos frescos ANTES de correr la ronda 6, no despues:
--
--   El silencio colgaba SOLO de nuestra escalera, y la base abre puertas por su
--   cuenta por este mismo camino. Peor: es antagonico. Cuando la base abre una
--   prop_door_rotating se pone blockerTbl.term_NextUse = CurTime() + 3
--   ( shared.lua:1345 ) y nuestro Think respeta ese reloj a proposito, asi que
--   cuando la base gana la carrera NOS ABSTENEMOS justo los 3 s en los que la
--   puerta suena.
--
--   Y el check no lo habria visto: la fila 01 dispara phantasmagoria_ghost_testdoor,
--   que fuerza NUESTRO camino. Habria salido verde con el juego sonando -- el
--   mismo modo de falla que costo la ronda 3.
--
-- Va aca porque este hook corre ADENTRO de Use2 ( shared.lua:1221 ), despues de
-- handleDoubleDoors y ANTES del toUse:Use() y del click, o sea el unico punto
-- que ven las dos aperturas. La llamada explicita de la escalera se conserva
-- igual: los peldanos 2 y 3 usan Fire y no pasan por Use2.
hook.Add( "TerminatorBlockUse", "phantasmagoria_veto_puertas", function( bot, used )
    if not IsValid( bot ) then return end
    if not bot.IsPhantasmagoriaGhost then return end
    if not IsValid( used ) then return end
    if not DOOR_CLASSES[ used:GetClass() ] then return end

    if not bot:phantom_CanOpenDoors() then
        stats( bot ).vetadas = stats( bot ).vetadas + 1

        -- Vetada no se silencia a proposito: la hoja no se mueve, asi que no hay
        -- sonido que tapar, y silenciarla seria pedirle prestados los keyvalues
        -- a una puerta que nunca los iba a usar.
        return true

    end

    -- phantom_SilenceDoor devuelve true SOLO si abrio una ventana nueva. Nuestra
    -- escalera silencia ANTES de llamar a Use2, asi que cuando el hook vuelve a
    -- pasar por aca la ventana ya esta abierta y devuelve false. O sea que este
    -- contador mide UNA cosa y bien: las aperturas que la base hace sola y que
    -- hasta hoy sonaban.
    if bot:phantom_WantsSilentDoors() and bot:phantom_SilenceDoor( used ) then
        stats( bot ).silenciosBase = stats( bot ).silenciosBase + 1

    end

    -- Sin return: devolver el true de arriba bloquearia la apertura que se acaba
    -- de silenciar.
end )

local function phaseMask()
    if cvPhaseMask:GetBool() then
        return MASK_NPCWORLDSTATIC, "MASK_NPCWORLDSTATIC"

    end

    return MASK_NPCSOLID_BRUSHONLY, "MASK_NPCSOLID_BRUSHONLY"

end

-- phaseMask tampoco se exporta, por lo mismo: su unico consumidor esta en este
-- archivo.

-- Se restaura a self.SolidMask, que es el campo DECLARADO por la base
-- ( terminator_nextbot_base/init.lua:68, MASK_NPCSOLID ) y el mismo valor al
-- que vuelven los dos precedentes. No se lee la mascara actual de la entidad a
-- proposito: si algo mas la hubiera cambiado, restaurarla desde el campo la
-- devuelve al estado conocido en vez de perpetuar el ajeno.
function ENT:phantom_SetPhasing( on, motivo )
    on = on == true

    if on == ( self.phantom_Phasing == true ) then return end

    if on then
        if ( self.phantom_PhaseBlockUntil or 0 ) > CurTime() then return end

        local mask, name = phaseMask()

        self:SetSolidMask( mask )

        self.phantom_Phasing      = true
        self.phantom_PhasingSince = CurTime()
        self.phantom_PhasingMask  = name
        self.phantom_PhasingWhy   = motivo

        local st = stats( self )
        st.fases = st.fases + 1

    else
        self:SetSolidMask( self.SolidMask or MASK_NPCSOLID )

        self.phantom_Phasing    = false
        self.phantom_PhasingFor = CurTime() - ( self.phantom_PhasingSince or CurTime() )

    end
end

-- El techo duro, y corre en las DOS ramas del Think ( con puerta delante y sin
-- ella ) porque el caso que tiene que atrapar es justamente el que se sale de
-- las dos: quedar no-solido sin que nada lo devuelva. Fuerza la vuelta aunque
-- la hoja lo este tapando -- entre "expulsado de una puerta" y "no-solido para
-- siempre", lo primero se ve y lo segundo no.
function ENT:phantom_PhaseTimeout()
    if not self.phantom_Phasing then return end

    local since = self.phantom_PhasingSince or CurTime()
    if CurTime() - since < PHASE_MAX then return end

    local st = stats( self )
    st.fasesLargas = st.fasesLargas + 1

    self:phantom_SetPhasing( false )
    self.phantom_PhaseBlockUntil = CurTime() + PHASE_COOLDOWN

    PHANTASMAGORIA.Print( "#", self:EntIndex(), " atraveso mas de ", PHASE_MAX,
        " s seguidos y se lo forzo a solido. Eso no deberia pasar: mirar contra que puerta.\n" )

end

-- El unico lugar que apaga el atravesado por la via normal, y pide DOS cosas
-- que fallan distinto: que no haya una hoja encima ( medicion directa, pero
-- depende de que el trace conteste bien estando adentro de un solido ) y que
-- hayan pasado PHASE_GRACE segundos desde la ultima puerta ( no mide nada, pero
-- no depende de esa respuesta ). Con las dos, el caso que no se pudo medir no
-- decide solo.
function ENT:phantom_PhaseRelease()
    if not self.phantom_Phasing then return end

    if doorOverlapping( self ) then
        self.phantom_doorSeenAt = CurTime()
        return

    end

    if CurTime() - ( self.phantom_doorSeenAt or 0 ) < PHASE_GRACE then return end

    self:phantom_SetPhasing( false )

end

function ENT:phantom_DoorThink()
    local now  = CurTime()
    local last = self.phantom_doorThinkAt or 0

    if now - last < THINK_EVERY then return end

    -- El dt real y no la constante: el Think de una tarea corre dentro de un
    -- coroutine y no tiene periodo garantizado. El tope de 1 s existe para que
    -- un freeze del servidor no cargue diez segundos de golpe al cronometro.
    local dt = ( last > 0 ) and math.min( now - last, 1 ) or THINK_EVERY
    self.phantom_doorThinkAt = now

    local door, tr, dirSrc, reach = doorAhead( self )

    self.phantom_doorDirSrc = dirSrc
    self.phantom_doorReach  = reach

    if not IsValid( door ) then
        self.phantom_doorLast    = nil
        self.phantom_doorBlocked = 0
        self.phantom_doorInfo    = nil

        -- VOLVER A SER SOLIDO NO ES GRATIS, y por eso no alcanza con "ya no hay
        -- puerta adelante". Mientras el cuerpo siga METIDO en la hoja, dejarlo
        -- solido lo mete adentro de un solido: el engine lo expulsa a donde
        -- puede, que puede ser del otro lado o adentro de una pared. El sondeo
        -- de adelante no sirve para eso -- una puerta que ya paso queda ATRAS.
        self:phantom_PhaseRelease()
        self:phantom_PhaseTimeout()
        return

    end

    local info = readDoor( door )
    self.phantom_doorInfo = info

    -- LOS CONTADORES SE INICIALIZAN ANTES DE LA PUERTA DE LA CAPACIDAD, y eso
    -- lo destapo la ronda 3: con opendoors 0 el reporte decia "( todavia no vio
    -- ninguna puerta cerrada )" mientras el fantasma tenia puertas cerradas
    -- delante todo el tiempo. El early return se llevaba puesto al instrumento
    -- junto con la funcion. "No vio ninguna" y "vio y no abrio a proposito" son
    -- dos cosas distintas y el reporte las mostraba iguales.
    local st = stats( self )

    -- ATRAVESAR. El rango es corto a proposito ( ver PHASE_RANGE ): se vuelve
    -- no-solido cuando ya casi la toca, no cuando la ve a 200 u. Con la hoja
    -- encima, tr.Fraction es 0 y sigue atravesando hasta salir del otro lado.
    local distancia = tr.Fraction * reach

    -- El motivo NO se guarda en un campo: el reporte vuelve a llamar al
    -- resolvedor y lo imprime fresco. El campo phantom_PhaseWhy se escribia diez
    -- veces por segundo y no lo leia nadie.
    local puede, motivo = self:phantom_CanPhaseDoors()

    -- UNA SOLA PUERTA DE ENTRADA AL ATRAVESADO: LA CERCANIA. La segunda -- el
    -- rescate por atasco contra una hoja ABIERTA -- se retiro en la ronda 6
    -- porque no podia dispararse; el porque esta arriba, donde estaba su
    -- constante.
    if puede and distancia <= PHASE_RANGE then
        self.phantom_doorSeenAt = now
        self:phantom_SetPhasing( true, motivo )

    else
        -- Dos caminos distintos que terminan igual: la puerta todavia esta
        -- lejos, o la convar/el flag se apagaron en el medio. En los dos, salir
        -- pasa por la MISMA puerta de emergencia, que es la que se ocupa de no
        -- dejarlo solido adentro de la hoja.
        self:phantom_PhaseRelease()

    end

    self:phantom_PhaseTimeout()

    -- EL CRONOMETRO. Corre SIEMPRE que haya una puerta delante y el fantasma
    -- este casi quieto, este la puerta cerrada o abierta, y con la convar
    -- apagada tambien. Es la unica medicion de este archivo que no depende de
    -- que el arreglo sea el correcto: si el atasco resulta ser contra puertas
    -- ABIERTAS ( la hoja que se abrio encima del bot ), el arreglo de abajo no
    -- lo toca y esta linea es la que lo va a decir.
    if door ~= self.phantom_doorLast then
        self.phantom_doorLast    = door
        self.phantom_doorBlocked = 0

        -- Se cuenta al CAMBIAR de puerta y no por tick: el Think corre 10 veces
        -- por segundo, asi que contar cada pasada daria un numero que mide el
        -- tiempo parado delante y no las puertas encontradas.
        if info.cerrada then st.vistas = st.vistas + 1 end

    end

    if self:GetCurrentSpeed() < STUCK_SPEED then
        local blocked = ( self.phantom_doorBlocked or 0 ) + dt
        self.phantom_doorBlocked = blocked

        if blocked > ( self.phantom_doorWorst or 0 ) then
            self.phantom_doorWorst      = blocked
            self.phantom_doorWorstClass = door:GetClass()
            self.phantom_doorWorstState = info.abierta and "ABIERTA" or ( info.cerrada and "cerrada" or "en movimiento" )

        end
    else
        self.phantom_doorBlocked = 0

    end

    -- Idem phantom_PhaseWhy: el motivo lo reimprime el reporte, no un campo.
    local puedeAbrir = self:phantom_CanOpenDoors()

    if not puedeAbrir then return end

    -- Contra el TOGGLE: dos Use seguidos abren y cierran. Se respetan los dos
    -- relojes, el nuestro y el de la base ( term_NextUse, que tryToOpen pone en
    -- CurTime() + 3 cuando ella misma abre, shared.lua:1344 ). Respetar el de
    -- ella es lo que evita que los dos codigos se peleen la misma puerta.
    if ( door.phantom_nextTry or 0 ) > now then return end
    if ( door.term_NextUse or 0 ) > now then return end

    local blocked = self.phantom_doorBlocked or 0

    -- ⚠ ACA VIVIA LA RAMA `reabrio` -- volver a abrir con OpenAwayFrom la hoja
    -- que ya estaba ABIERTA y le tapaba el paso -- Y LA RONDA 6 LA RETIRO. Se
    -- deja escrito por el mismo motivo que la de arriba: para que no se
    -- reescriba.
    --
    -- Pedia `blocked >= FORCE_AFTER * 2`, o sea 3 s, y el atravesado por
    -- cercania destraba mucho antes: apenas el bot se mueve, la velocidad pasa
    -- de 30 u/s y `phantom_doorBlocked` vuelve a 0. **Nunca llegaba a 3.** El
    -- contador marco 0 en las nueve lecturas de la ronda 6, y estaba anotado en
    -- la planilla como ESPERADO antes de correr, asi que el 0 no se leyo como
    -- falla: se leyo como lo que era.
    --
    -- Si alguna vez el atravesado se apaga por diseno ( el Alternate de
    -- ALTERNATE.md no atraviesa ), este es el caso que queda sin salida y hay
    -- que volver a mirarlo -- pero entonces medido sobre ESE NPC, no sobre este.
    if not info.cerrada then return end -- abierta, abriendo o cerrando: no es asunto nuestro

    st.intentos = st.intentos + 1

    -- Destrabar va PRIMERO y no es un peldano: un Use sobre una puerta con
    -- llave no hace nada ( suena el candado y listo ), asi que sin esto los
    -- tres peldanos fallan igual. En Phasmophobia el fantasma no se queda
    -- afuera de un cuarto porque la puerta tenga llave.
    if info.locked and cvUnlock:GetBool() then
        door:Fire( "Unlock" )
        st.unlock = st.unlock + 1

        -- ⚠ ESTE DESTRABADO ERA MUDO, Y LO ES DESDE QUE SE ESCRIBIO. Cambia un
        -- estado PERMANENTE del mapa -- es la unica cosa de este archivo que no
        -- se deshace sola, y por eso tiene convar propia -- y no dejaba ni un
        -- ruido: el jugador se encontraba una puerta con llave abierta y no tenia
        -- forma de saber cuando ni quien. La ronda del +USE ( 2026-08-17 ) le
        -- pone las llaves que sobraban del banco ambiente, que es literal lo que
        -- el autor propuso: *"podemos hacer que el bot cierre puertas con
        -- pestillo y ahi aplicar esos sonidos"*.
        --
        -- ⚠⚠ LA REFERENCIA ES TARDIA A PROPOSITO: `server_events.lua` se incluye
        -- DESPUES que este archivo, asi que la funcion no existe al cargar --
        -- existe al llamar. Y el `isfunction` avisa UNA sola vez en vez de callar:
        -- si algun dia ese archivo no carga, "no sono la llave" y "no hay llave
        -- que sonar" tienen que poder distinguirse. Un aviso por destrabado
        -- taparia la bitacora justo en el momento en que hay que leerla.
        if isfunction( PHANTASMAGORIA.SonarLlave ) then
            PHANTASMAGORIA.SonarLlave( "unlock", door:WorldSpaceCenter() )

        elseif not PHANTASMAGORIA.avisoLlaveMudo then
            PHANTASMAGORIA.avisoLlaveMudo = true

            ErrorNoHalt( "[Phantasmagoria] PHANTASMAGORIA.SonarLlave NO existe: el destrabado de puertas " ..
                "va a ser MUDO toda la partida. Deberia venir de server_events.lua, que es el ultimo " ..
                "include de server.lua -- si ese archivo no cargo, faltan tambien los ocho eventos.\n" )

        end
    end

    door.phantom_nextTry = now + RETRY_EVERY

    -- EL SILENCIO, y va ANTES de tocar la puerta porque las dos mitades tienen
    -- que estar puestas cuando el sonido se emita. El contador vive ADENTRO de
    -- phantom_SilenceDoor desde que el hook tambien silencia: la misma apertura
    -- pasa por los dos call sites y contarlo aca la contaba dos veces.
    if self:phantom_WantsSilentDoors() then
        self:phantom_SilenceDoor( door )

    end

    -- LA ESCALERA. Cada peldano se cuenta aparte para que la corrida diga cual
    -- hizo el trabajo -- si el 1 alcanza siempre, los otros dos son codigo
    -- muerto y hay que sacarlos.
    if blocked < FORCE_AFTER then
        -- 1. El camino de la base. Use2 no es :Use() pelado: maneja puertas
        --    dobles ( slavename ), tiene lista negra por clase para no comerse
        --    un error ajeno, respeta el hook TerminatorBlockUse y emite el
        --    sonido ( shared.lua:1202-1246 ). Con el activator siendo el
        --    fantasma, prop_door_rotating abre para el lado contrario a el.
        st.use = st.use + 1
        self:Use2( door )

    elseif blocked < FORCE_AFTER * 2 and door:GetClass() == "prop_door_rotating" then
        -- 2. La entrada que existe justo para esto. LA CLASE IMPORTA y la
        --    primera version no la miraba: OpenAwayFrom es de CBasePropDoor,
        --    o sea SOLO prop_door_rotating. Sobre un func_door_rotating el Fire
        --    no hace nada y no avisa -- el peldano 2 se consumia entero sin
        --    tocar la puerta, y el 3 recien llegaba 1,5 s despues. Lo destapo
        --    la corrida del autor: la puerta que lo trababa era justamente un
        --    func_door_rotating.
        st.away = st.away + 1
        self:phantom_DoorOpenAwayFrom( door )

    else
        -- 3. El martillo. Abre para el lado que la puerta tenga por default,
        --    que puede ser hacia el fantasma -- feo, pero nunca un muro.
        st.open = st.open + 1
        door:Fire( "Open" )

    end

    -- Que la base no la re-toquetee en el mismo segundo.
    door.term_NextUse = now + RETRY_EVERY

    -- La huella se ARMA aca -- con la puerta todavia quieta, que es lo que hace
    -- valido el punto relativo -- y se GUARDA abajo, solo si abrio. El punto
    -- sale del trace, que es donde el cuerpo del bot toco la hoja. No se
    -- distingue por peldano: los tres son la misma accion fisica desde el punto
    -- de vista de la evidencia, y el criterio del autor es "cuando la abra".
    local pendiente

    -- ⚠ NO ES `tr.Entity == door`, Y LA IGUALDAD PELADA ERA UN DEFECTO REAL: en
    -- las puertas con paneles parenteados el trace pego en el VIDRIO y `door` es
    -- el PADRE, asi que la comparacion daba falso SIEMPRE y esas puertas abrian
    -- sin dejar evidencia -- `huellas` se quedaba en 0 justo en las dos puertas
    -- por las que se escribio el arreglo del padre. Lo reporto el autor en juego
    -- ( *"ya abre las puertas, pero parece no dejar huellas"* ) y el renglon que
    -- lo advertia estaba escrito en doorAhead: decia que devolver el `tr` del
    -- hijo *"es correcto para lo que los llamadores hacen hoy"*. No lo era. La
    -- revision de esa advertencia miro los usos GEOMETRICOS del `tr` ( HitPos,
    -- Fraction ) y no el de IDENTIDAD, que es el unico que la ruptura rompe:
    -- *un `==` entre entidades tambien es un uso del trace.*
    --
    -- El panel ES parte de la puerta, asi que la huella sobre el vidrio es la
    -- huella correcta: `MakePrint` la guarda relativa a la PUERTA ( lpos ), y
    -- como el panel esta parenteado se mueve rigido con ella -- el punto local
    -- sigue cayendo sobre el vidrio cuando la hoja gira.
    if tr and tr.Hit and esLaPuertaOSuPanel( tr.Entity, door ) then
        -- ⚠ EL PUNTO YA NO SALE DE `tr.HitPos`, Y EL MOTIVO ESTA ARRIBA, EN
        -- HandPointOnDoor: `tr` es un TraceHull y su contacto queda a medio
        -- ancho del bot de la hoja y a la altura de los tobillos. La condicion
        -- de arriba SIGUE saliendo del hull -- eso es "hay puerta y la toque",
        -- que es justo lo que un volumen contesta mejor que una linea.
        local pos, normal, via = PHANTASMAGORIA.HandPointOnDoor( self, door, tr )

        if pos then
            pendiente = PHANTASMAGORIA.MakePrint( self, door, pos, normal )
            pendiente.via = via   -- "linea" o "cercano": lo imprime el instrumento

        end
    end

    -- VERIFICACION, y es la diferencia entre "intente" y "abri". Sin esto el
    -- contador mide la intencion, que es la trampa que este proyecto ya pago
    -- una vez ( medir la intencion no es medir el resultado ).
    --
    -- LIMITE HONESTO DE ESTA MEDICION: relee el estado, no quien lo cambio. Si
    -- el jugador abre la misma puerta en esos VERIFY_AFTER segundos, el
    -- contador se lo anota al fantasma. Para la corrida alcanza -- el fantasma
    -- cruza puertas que el jugador no esta tocando -- pero no sirve como prueba
    -- si los dos estan en el mismo vano.
    timer.Simple( VERIFY_AFTER, function()
        if not IsValid( self ) then return end
        if not IsValid( door ) then return end

        local d = readDoor( door )

        -- ABRIENDO CUENTA COMO ABRIO, y esto lo corrige la ronda 3: el reporte
        -- daba "ABRIO 0 fallo 3" con el fantasma cruzando puertas a la vista.
        -- La hoja tarda mas de VERIFY_AFTER en llegar al tope, asi que a los
        -- 0,9 s el estado todavia es "en movimiento" y se contaba como FALLO --
        -- se ve en el propio reporte, que anoto "peor 0,9 s contra un
        -- func_door_rotating EN MOVIMIENTO". El instrumento medio bien y
        -- clasifico mal: leer un estado transitorio como el final.
        -- Y no vale cualquier movimiento: abriendo es un estado distinto de
        -- cerrando, y los dos enums los distinguen.
        if not ( d.abierta or d.abriendo ) then
            st.fallo = st.fallo + 1
            return

        end

        st.abrio = st.abrio + 1

        if not pendiente then return end

        PHANTASMAGORIA.CommitPrint( pendiente )
        st.huellas = st.huellas + 1

    end )
end

---------------------------------------------------------------------------
-- Abrir en silencio
---------------------------------------------------------------------------
-- SON DOS FUENTES DE SONIDO Y CADA UNA SE TAPA DISTINTO, y confundirlas seria
-- callar la mitad y creer que anda ( el click del bot y el chirrido de la
-- puerta se pisan, asi que a oido "casi no suena" pasa por "no suena" ).
--
-- ① EL CLICK DEL BOT. Use2 emite common/wpn_select.wav ( shared.lua:1238 ) y
--    ademas le mete un ApplyForceCenter al physics object. Las dos cosas
--    cuelgan del MISMO if, y arriba de ese if hay un debounce propio de la
--    base: "if nextUseSound < CurTime()". O sea que adelantar ese reloj apaga
--    las dos sin overridear Use2 ni duplicar su cuerpo. Es la propia base la
--    que trae el interruptor; solo hay que usarlo.
--
-- ② EL SONIDO DE LA PUERTA. No lo emite nuestro codigo: lo emite el ENGINE al
--    mover la hoja, y NO se intercepta -- se le borra a la puerta antes de
--    moverla y se le devuelve despues. El detalle, con el mod que lo resolvio
--    primero, esta mas abajo en DOOR_SOUND_KEYS.
--
--    ( Este parrafo decia otra cosa hasta la ronda 5: que el punto de
--    intercepcion era el hook EntityEmitSound. Era LECTURA y la medicion lo
--    refuto -- ver abajo. Se reescribe en vez de dejarlo al lado del codigo
--    nuevo: un comentario viejo junto a su propia refutacion es la trampa que
--    este proyecto ya pago dos veces. )
--
-- Y HAY DOS CALL SITES, no uno, desde la revision previa a la ronda 6:
--   la ESCALERA          silencia antes de abrir ( cubre los peldanos 2 y 3,
--                        que usan Fire y no pasan por Use2 )
--   TerminatorBlockUse   silencia adentro de Use2 ( cubre las aperturas que la
--                        BASE hace por su cuenta, que es lo que sonaba )
-- phantom_SilenceDoor es idempotente entre los dos y devuelve si abrio ventana
-- nueva; el contador vive adentro por eso.
--
-- ERA 1,5 s Y ESO NO ALCANZA. El autor reporto en la ronda 3 que "si suenan, es
-- el sonido de GOLPE de la puerta" -- y el golpe es el sonido de LLEGADA, el
-- que la hoja emite al terminar el recorrido, no al empezarlo. Una puerta tarda
-- mas de 1,5 s en abrir del todo ( el propio reporte la agarro "en movimiento"
-- a los 0,9 s ), asi que la ventana se cerraba justo antes del ruido que se
-- queria tapar. Tres segundos cubren el recorrido entero mas el golpe.
local SILENCE_WINDOW = 3

-- ② EL SONIDO DE LA PUERTA: NO SE BLOQUEA, SE LE BORRA A LA PUERTA.
--
-- La version anterior enganchaba EntityEmitSound y devolvia false. NO FUNCIONO,
-- y la bitacora que puse justamente para diagnosticarlo dio el veredicto:
-- **vacia**, con la ventana abierta, la puerta abriendose y el sonido oyendose.
-- No registro NADA -- ni siquiera sonidos sin bloquear cerca de la puerta --,
-- asi que el problema no era la ventana ni el nombre del archivo: el hook
-- SERVER-SIDE nunca ve esos sonidos, porque no nacen en Lua del servidor.
--
-- *Un log vacio donde tenia que haber algo vale mas que uno lleno: descarta la
-- familia entera de hipotesis, no una.* Habia tres candidatas ( ventana corta,
-- sonido de otro emisor, hook ciego ) y la lista vacia mato las dos primeras.
--
-- EL CAMINO BUENO LO SEÑALO EL AUTOR: "Immersive Door Openable" ( WSID
-- 3717549037, en dev/other/immersive door openable/ ). No engancha nada -- le
-- pisa a la puerta sus PROPIAS keyvalues de sonido con "" antes de moverla, y
-- se las devuelve despues ( sv_door.lua:61-67 y :90-96 ). Asi el sonido no se
-- bloquea: no llega a existir, y por eso ningun hook hacia falta.
--
-- Son SIETE campos y hacen falta los siete, porque son DOS familias de puerta:
--   CBaseDoor      ( func_door, func_door_rotating )  noise1 / noise2
--   CBasePropDoor  ( prop_door_rotating )             los cinco sound*override
-- noise2 es el GOLPE de llegada -- exactamente el que el autor reporto oir.
local DOOR_SOUND_KEYS = {
    "noise1",                   -- CBaseDoor: mientras se mueve
    "noise2",                   -- CBaseDoor: el golpe al llegar
    "soundopenoverride",        -- CBasePropDoor, los cinco de abajo
    "soundcloseoverride",
    "soundmoveoverride",
    "soundlockedoverride",
    "soundunlockedoverride",
}

-- DE QUE FAMILIA ES CADA CAMPO, y no es documentacion: es lo unico que deja
-- distinguir "esta puerta no tiene ese campo" de "esta puerta lo tiene y no me
-- lo deja leer". Las dos daban un nil identico, y la segunda es la que puede
-- dejar una puerta muda para siempre.
--
-- Se intentan las SIETE sobre las dos familias -- el mod de referencia hace lo
-- mismo -- pero solo se ALARMA cuando el campo que no se pudo leer es de la
-- familia propia de esa puerta. Un noise1 ausente en una prop_door_rotating es
-- lo esperado; un soundopenoverride ausente en una prop_door_rotating, no.
local DOOR_SOUND_OWNER = {
    noise1                = "CBaseDoor",
    noise2                = "CBaseDoor",
    soundopenoverride     = "CBasePropDoor",
    soundcloseoverride    = "CBasePropDoor",
    soundmoveoverride     = "CBasePropDoor",
    soundlockedoverride   = "CBasePropDoor",
    soundunlockedoverride = "CBasePropDoor",
}

local function doorFamily( door )
    if door:GetClass() == "prop_door_rotating" then return "CBasePropDoor" end

    return "CBaseDoor"

end

-- LAS HOJAS HERMANAS DE UNA PUERTA DOBLE, y esto era el otro agujero del
-- silencio. El engine abre la esclava junto con la maestra; nosotros
-- silenciabamos UNA. La base ya sabe que las dobles son un caso aparte
-- ( handleDoubleDoors, shared.lua:1150 ) y el mod de referencia propaga a
-- slavename y m_hMaster ( sv_door.lua:152-162 ). Faltaba de nuestro lado.
--
-- OJO CON EL ALCANCE, porque la ronda 6 mostro que esto NO es lo mismo que "dos
-- hojas al lado": gm_break_in_redux trae los vanos de a pares ( #763/#764,
-- #949/#950 ) como entidades INDEPENDIENTES, sin slavename -- el bot usa cada
-- una por su lado y las dos se silencian solas. Ahi este codigo no hace nada, y
-- esta bien que no haga nada. El caso que cubre es la doble de VERDAD, con
-- maestra y esclava, que ese mapa no tiene: por eso la ronda 6 no dio evidencia
-- ni a favor ni en contra.
--
-- Se CACHEA en la puerta porque un slavename no cambia en runtime, y la rama de
-- busqueda inversa -- "soy la esclava, quien es mi maestra" -- recorre todas las
-- prop_door_rotating del mapa, igual que la base. Una vez por puerta y no una
-- vez por apertura.
local function doorSiblings( door )
    local cached = door.phantom_DoorSiblings
    if cached then return cached end

    local out = {}
    local keys = door:GetKeyValues()

    -- 1. las esclavas que declara esta puerta
    local slaveName = keys and keys[ "slavename" ]

    if slaveName and slaveName ~= "" then
        for _, sibling in ipairs( ents.FindByName( slaveName ) ) do
            if IsValid( sibling ) and sibling ~= door and DOOR_CLASSES[ sibling:GetClass() ] then
                out[ #out + 1 ] = sibling

            end
        end
    end

    -- 2. y al reves: la maestra que nos declara a nosotros. Sin esto, silenciar
    --    la esclava deja sonando a la maestra, que es la mitad que el engine
    --    mueve primero.
    local ourName = door:GetName()

    if ourName and ourName ~= "" then
        for _, other in ipairs( ents.FindByClass( "prop_door_rotating" ) ) do
            if IsValid( other ) and other ~= door then
                local otherKeys = other:GetKeyValues()

                if otherKeys and otherKeys[ "slavename" ] == ourName then out[ #out + 1 ] = other end

            end
        end
    end

    door.phantom_DoorSiblings = out

    return out

end

-- La bitacora deja de anotar SONIDOS -- que no podemos ver -- y pasa a anotar
-- las OPERACIONES, que si podemos: que puerta, que valores se guardaron, y si
-- se restauraron. Es el instrumento que corresponde al mecanismo nuevo, y el
-- riesgo que vigila es el unico serio que tiene: **borrar y no devolver** deja
-- la puerta muda para todos, para siempre.
local BITACORA_MAX = 10

PHANTASMAGORIA.SilenceLog = PHANTASMAGORIA.SilenceLog or {}

-- ACA HABIA UNA TABLA `silenced`, escrita en dos lugares y leida en NINGUNO. Se
-- fue en la ronda 6 y vale anotar por que era peor que ruido: parecia el
-- registro autoritativo de puertas mudas, cuando el registro de verdad es el
-- campo phantom_DoorSounds barrido sobre ents.GetAll(). El primero que fuera a
-- arreglar la fila 03 la habria tocado a ella.

local function anotar( texto )
    local log = PHANTASMAGORIA.SilenceLog
    log[ #log + 1 ] = texto

    while #log > BITACORA_MAX do table.remove( log, 1 ) end

end

-- Devolver los sonidos. Es la mitad que NO puede fallar, asi que se la escribe
-- para que sea idempotente y para que se la pueda forzar a mano.
function PHANTASMAGORIA.RestoreDoorSounds( door, force )
    if not IsValid( door ) then return false end

    local saved = door.phantom_DoorSounds
    if not saved then return false end

    -- Si la puerta se volvio a silenciar mientras esperabamos, manda la ventana
    -- nueva: el timer viejo se retira sin tocar nada.
    if not force and ( door.phantom_SilentUntil or 0 ) > CurTime() then return false end

    -- SE DEVUELVE LO QUE SE GUARDO Y NADA MAS. La version anterior hacia
    -- "saved[ key ] or """, o sea que para toda clave que no se hubiera podido
    -- LEER escribia "" encima de un campo que nunca miramos. Y no era un borde
    -- raro: son 2 de 7 en una prop_door_rotating y 5 de 7 en una func_door, o
    -- sea que el camino peligroso estaba transitado en todas las puertas. Salia
    -- bien de casualidad, porque esas claves no existen en esa familia -- el dia
    -- que una exista y no se deje leer, ese "" es una puerta muda para siempre.
    --
    -- Este es el UNICO mecanismo del bloque que le cambia el mapa a todos de
    -- forma permanente, y es lo que vigila el check 03.
    local devueltos = 0

    for _, key in ipairs( DOOR_SOUND_KEYS ) do
        local val = saved[ key ]

        if val ~= nil then
            door:SetSaveValue( key, val )
            devueltos = devueltos + 1

        end
    end

    door.phantom_DoorSounds  = nil
    door.phantom_SilentUntil = nil

    anotar( "devuelto  " .. door:GetClass() .. " #" .. door:EntIndex() ..
        "   " .. devueltos .. " campo(s), los mismos que se guardaron" )

    return true

end

-- Una hoja. Devuelve true si ABRIO UNA VENTANA NUEVA, false si ya habia una.
-- Se llama una vez por la puerta usada y una por cada hermana, y cada una lleva
-- su propio guardado, su propia ventana y su propio timer de devolucion: asi el
-- arrastre a la doble no puede dejar a la hermana sin restaurar por culpa de la
-- otra.
local function silenceOne( door, esHermana )
    if not IsValid( door ) then return false end

    -- Los sonidos se guardan UNA vez: si se re-silencia con la ventana abierta,
    -- lo guardado ya es "" y devolverlo dejaria la puerta muda para siempre. El
    -- mod de referencia usa el mismo resguardo.
    local saved = door.phantom_DoorSounds
    local nueva = false
    local marca = esHermana and "silenciado ( hermana ) " or "silenciado "

    if not saved then
        nueva = true
        saved = {}

        local familia = doorFamily( door )
        local conValor, vacios, ilegibles = {}, {}, {}

        for _, key in ipairs( DOOR_SOUND_KEYS ) do
            local val = door:GetInternalVariable( key )

            -- LO QUE NO SE PUDO LEER NO SE PISA. Es la unica linea que hace
            -- falta para que este mecanismo no pueda dejar una puerta muda para
            -- siempre: si un campo no se deja leer, la puerta SUENA -- falla
            -- ruidosa, visible en el check y en la bitacora -- en vez de quedar
            -- muda, que es la falla que nadie nota hasta mucho despues.
            if val == nil then
                if DOOR_SOUND_OWNER[ key ] == familia then ilegibles[ #ilegibles + 1 ] = key end

            else
                saved[ key ] = val

                if val ~= "" then conValor[ #conValor + 1 ] = key .. "=" .. tostring( val )
                else vacios[ #vacios + 1 ] = key end

            end
        end

        door.phantom_DoorSounds = saved

        anotar( marca .. door:GetClass() .. " #" .. door:EntIndex() ..
            "   " .. ( #conValor > 0 and table.concat( conValor, "  " ) or "( ningun campo con sonido )" ) ..
            ( #vacios > 0 and ( "   declarados vacios: " .. table.concat( vacios, " " ) ) or "" ) )

        -- LA LINEA QUE ANTES NO EXISTIA, y es la que separa las dos cosas que
        -- la bitacora imprimia iguales. "No tenia sonido declarado" y "no lo
        -- pude leer" daban el mismo nil, y la segunda es la unica que puede
        -- terminar en una puerta muda. En la ronda 6 no aparecio ni una vez, y
        -- eso ahora significa algo: la diferencia se veria.
        if #ilegibles > 0 then
            anotar( "  OJO  " .. door:GetClass() .. " #" .. door:EntIndex() ..
                "   NO deja leer " .. table.concat( ilegibles, " " ) ..
                " -- son campos de SU PROPIA familia ( " .. familia .. " ). Esos NO se silencian: " ..
                "la puerta va a sonar, y eso es a proposito." )

        end
    end

    -- Solo las claves que se pudieron leer. Silenciar una que no se leyo seria
    -- exactamente el caso que despues no se puede devolver.
    for _, key in ipairs( DOOR_SOUND_KEYS ) do
        if saved[ key ] ~= nil then door:SetSaveValue( key, "" ) end

    end

    door.phantom_SilentUntil = CurTime() + SILENCE_WINDOW

    timer.Simple( SILENCE_WINDOW + 0.05, function()
        PHANTASMAGORIA.RestoreDoorSounds( door )

    end )

    return nueva

end

-- DEVUELVE true SOLO SI ABRIO UNA VENTANA NUEVA sobre la puerta USADA, y eso no
-- es cosmetico: es lo que deja contar aparte las aperturas de LA BASE sin contar
-- dos veces las nuestras. La escalera silencia antes de llamar a Use2, asi que
-- cuando el hook TerminatorBlockUse vuelve a pasar por aca la ventana ya esta
-- abierta y esto devuelve false; una apertura de la base llega sin ventana
-- previa.
--
-- El contador st.silencios vive ADENTRO por el mismo motivo: con dos call sites
-- para la misma apertura, contarlo afuera lo contaba dos veces.
function ENT:phantom_SilenceDoor( door )
    if not IsValid( door ) then return false end

    -- ① el click del bot: se adelanta el debounce que la propia base consulta.
    --    Va siempre, aunque la ventana ya este abierta: el click lo emite Use2 y
    --    la base puede llamarlo mas tarde que nosotros.
    self.nextUseSound = CurTime() + SILENCE_WINDOW

    -- ② los sonidos, de la puerta Y de sus hermanas. El engine mueve la esclava
    --    junto con la maestra, asi que silenciar una sola deja sonando a la otra
    --    mitad del vano.
    local nueva = silenceOne( door, false )
    local st    = stats( self )

    for _, hermana in ipairs( doorSiblings( door ) ) do
        if silenceOne( hermana, true ) then st.silenciosHermanas = st.silenciosHermanas + 1 end

    end

    if nueva then st.silencios = st.silencios + 1 end

    return nueva

end

-- OpenAwayFrom pide el TARGETNAME del que se aparta, no la entidad
-- ( CBasePropDoor::InputOpenAwayFrom resuelve por nombre ), y un NextBot
-- spawneado por script no tiene ninguno. Se le pone uno con prefijo propio para
-- no chocar con la logica de ningun mapa.
--
-- ESTO ES LECTURA DEL SDK Y NO ESTA MEDIDO EN GMOD. Por eso es el peldano 2 y
-- no el 1, y por eso el peldano 3 existe: si OpenAwayFrom resulta no estar
-- expuesto, el contador st.away sube y st.abrio no, y la corrida lo ve.
function ENT:phantom_DoorOpenAwayFrom( door )
    local name = self:GetName()

    if not name or name == "" then
        name = "phantasmagoria_ghost_" .. self:EntIndex()
        self:SetName( name )

    end

    door:Fire( "OpenAwayFrom", name )

end

---------------------------------------------------------------------------
-- El enganche
---------------------------------------------------------------------------
-- RunTask corta en el primer callback que devuelve no-nil ( taskoverride.lua:47 ),
-- asi que este NO puede devolver nada: si devolviera, le robaria el evento
-- Think a cualquier otra tarea que se agregue despues, y el sintoma seria una
-- tarea ajena que deja de correr sin error. Hoy ninguna tarea de la base
-- implementa Think ( grep sobre la base y HIM: cero ), o sea que hoy no se
-- notaria -- que es exactamente por que conviene escribirlo bien ahora.
ENT.MyClassTask.Think = function( self, _data )
    self:phantom_DoorThink()

end

---------------------------------------------------------------------------
-- Instrumento: las puertas
---------------------------------------------------------------------------
-- NINGUN numero de este reporte se tipea a mano: todos salen de las constantes
-- de arriba. Un instrumento que anuncia "el umbral es 30" con un 30 escrito al
-- lado deja de decir la verdad el dia que la constante cambia, y lo hace en
-- silencio -- que es el modo de falla que este proyecto ya pago varias veces.
---------------------------------------------------------------------------
-- Forzar una apertura, para poder MEDIR el silencio
---------------------------------------------------------------------------
-- TRES RONDAS SEGUIDAS SIN PODER MEDIR EL SILENCIO, y las tres por lo mismo: la
-- precondicion pedia que un fantasma silenciado abriera una puerta JUSTO
-- mientras el autor escuchaba, y eso no se puede forzar deambulando. En la
-- ronda 4 la lectura salio con "( todavia no vio ninguna puerta cerrada )" y la
-- bitacora vacia -- o sea que el check no fallo: NO SE CORRIO, y se marco como
-- falla porque desde afuera se ven igual.
--
-- *Un check cuya precondicion no se puede provocar no es un check.* Esto es el
-- boton que faltaba: agarra la puerta mas cercana al fantasma, le aplica el
-- silencio que corresponda segun las perillas de ahora, y la abre. La bitacora
-- se llena si o si, y el autor sabe EXACTAMENTE cuando escuchar.
--
-- No es una mecanica y no la reemplaza: la escalera normal sigue corriendo sola.
-- Es utileria de medicion, como phantasmagoria_hunt_reeval.
PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_testdoor", function( ply )
    local say = PHANTASMAGORIA.MakeSay( ply )

    local found = PHANTASMAGORIA.EachGhost( function( ghost )
        -- LA GUARDA QUE FALTABA, Y LA RONDA 6 LA PAGO CON LAS DOS PRIMERAS
        -- MEDICIONES DE LA FILA 01. Con opendoors en 0 este boton silenciaba la
        -- puerta, gritaba "ESCUCHA AHORA" y despues el Use2 se lo comia el veto:
        -- no se oyo nada porque LA PUERTA NO SE ABRIO. El reporte lo tenia
        -- escrito al lado ( "a los 0.9 s: m_eDoorState = 0  no se movio" ) y aun
        -- asi la fila se pudo marcar verde -- se salvo porque el autor volvio a
        -- probar con opendoors 1.
        --
        -- *Un instrumento que invita a un verde sin medir nada es peor que no
        -- tenerlo.* Y ademas le pedia prestados los keyvalues a una puerta que
        -- nunca se iba a mover, o sea que exponia al riesgo de la fila 03 sin
        -- contrapartida.
        local puedeAbrir, motivoAbrir = ghost:phantom_CanOpenDoors()

        if not puedeAbrir then
            say( "#" .. ghost:EntIndex() .. "  NO SE DISPARA: este fantasma no puede abrir puertas." )
            say( "    " .. motivoAbrir )
            say( "    Sin apertura no hay sonido que tapar: el silencio NO se puede medir asi." )
            return

        end

        local mejor, mejorDist

        for _, ent in ipairs( ents.FindInSphere( ghost:GetPos(), 400 ) ) do
            if not DOOR_CLASSES[ ent:GetClass() ] then continue end

            local d = ghost:GetPos():Distance( ent:NearestPoint( ghost:GetPos() ) )
            if not mejor or d < mejorDist then mejor, mejorDist = ent, d end

        end

        if not IsValid( mejor ) then
            say( "#" .. ghost:EntIndex() .. "  no hay ninguna puerta a menos de 400 u." )
            return

        end

        local info      = readDoor( mejor )
        local silencio  = ghost:phantom_WantsSilentDoors()

        say( "#" .. ghost:EntIndex() .. "  " .. mejor:GetClass() .. " #" .. mejor:EntIndex() ..
            " a " .. math.Round( mejorDist ) .. " u   " .. info.campo .. " = " .. tostring( info.crudo ) ..
            "   " .. ( info.abierta and "ABIERTA" or ( info.cerrada and "cerrada" or "en movimiento" ) ) )

        if silencio then
            -- El contador vive adentro de phantom_SilenceDoor. Contarlo aca
            -- tambien seria contar dos veces la misma ventana.
            ghost:phantom_SilenceDoor( mejor )

        end

        say( "    silencio " .. ( silencio and "SI ( ventana de " .. SILENCE_WINDOW .. " s abierta )" or "NO" ) ..
            "   -> ESCUCHA AHORA" )

        -- Se usa el mismo camino que la escalera ( peldano 1 ) para que lo que
        -- se mide sea lo que pasa de verdad y no un atajo distinto.
        if info.locked and cvUnlock:GetBool() then mejor:Fire( "Unlock" ) end

        mejor.term_NextUse = CurTime() + RETRY_EVERY
        ghost:Use2( mejor )

        timer.Simple( VERIFY_AFTER, function()
            if not IsValid( ghost ) or not IsValid( mejor ) then return end

            local d = readDoor( mejor )

            say( "    a los " .. VERIFY_AFTER .. " s: " .. d.campo .. " = " .. tostring( d.crudo ) ..
                "   " .. ( d.abierta and "ABIERTA" or ( d.abriendo and "abriendo" or "no se movio" ) ) ..
                "   -> correr phantasmagoria_ghost_doors para ver la bitacora." )

        end )
    end )

    if found <= 0 then
        say( "[Phantasmagoria] no hay ningun fantasma vivo." )

    end
end, "UTILERIA DE MEDICION. Hace que cada fantasma abra la puerta mas cercana AHORA, con el silencio que corresponda. Existe para poder medir el silencio, que no se puede provocar deambulando." )

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_doors", function( ply, _, args )
    local say = PHANTASMAGORIA.MakeSay( ply )

    -- "reset" existe por el A/B: los maximos y los contadores son acumulados de
    -- toda la vida del fantasma, asi que sin esto la segunda mitad de una
    -- comparacion arranca con los numeros de la primera encima. Es el mismo
    -- arrastre que la planilla de checks existe para impedir.
    -- "restore" es la red de seguridad del silencio, y existe porque ese
    -- mecanismo es el UNICO de este archivo que le cambia el mapa a todos de
    -- forma permanente si algo sale mal. Borrar los sonidos de una puerta y no
    -- devolverlos la deja muda para siempre, y nadie lo notaria hasta mucho
    -- despues. El timer ya la devuelve solo; esto es para cuando no.
    if args and args[ 1 ] == "restore" then
        local n = 0

        for _, ent in ipairs( ents.GetAll() ) do
            if ent.phantom_DoorSounds and PHANTASMAGORIA.RestoreDoorSounds( ent, true ) then n = n + 1 end

        end

        say( "[Phantasmagoria] sonidos devueltos a " .. n .. " puerta(s). Si esto devuelve mas de 0 " ..
            "sin haber tocado nada recien, hubo un silenciado que no se restauro solo." )
        return

    end

    -- "dobles" EXISTE PORQUE SIN EL, EL CHECK DE LA PUERTA DOBLE NO SE PUEDE
    -- CORRER, y ya sabemos como termina eso: en la ronda 4 un check cuya
    -- precondicion no se podia provocar se marco FALLA y se leyo como mecanismo
    -- roto. Aca la precondicion es del MAPA -- que exista una doble de verdad,
    -- con slavename -- y no hay forma de saberlo deambulando.
    --
    -- La ronda 6 mostro por que importa la distincion: gm_break_in_redux trae los
    -- vanos de a pares ( #763/#764, #949/#950 ) pero como entidades
    -- INDEPENDIENTES, sin slavename. El bot usa cada hoja por su lado y las dos
    -- se silencian solas, asi que el arrastre no hace nada y esta bien que no
    -- haga nada. "No aparecio" y "no anda" se ven igual sin esta lista.
    if args and args[ 1 ] == "dobles" then
        local n = 0

        for _, ent in ipairs( ents.GetAll() ) do
            if not DOOR_CLASSES[ ent:GetClass() ] then continue end

            local keys  = ent:GetKeyValues()
            local slave = keys and keys[ "slavename" ]

            if slave and slave ~= "" then
                n = n + 1

                local cuantas = #ents.FindByName( slave )

                say( "    " .. ent:GetClass() .. " #" .. ent:EntIndex() ..
                    "   nombre '" .. tostring( ent:GetName() ) .. "'" ..
                    "   slavename '" .. slave .. "'" ..
                    "   -> " .. cuantas .. " entidad(es) responden a ese nombre" )

            end
        end

        if n <= 0 then
            say( "[Phantasmagoria] este mapa NO tiene ninguna puerta doble de verdad " ..
                "( ninguna con slavename ). El arrastre a la hoja hermana no se puede medir aca, " ..
                "y eso es un DATO: no es que falle, es que no se corre." )

        else
            say( "[Phantasmagoria] " .. n .. " puerta(s) maestra(s) con esclava. Abrir una de esas con el " ..
                "fantasma y mirar que la bitacora traiga una linea 'silenciado ( hermana )'." )

        end

        return

    end

    if args and args[ 1 ] == "reset" then
        local n = PHANTASMAGORIA.EachGhost( function( ghost )
            ghost.phantom_doorStats      = nil
            ghost.phantom_doorWorst      = 0
            ghost.phantom_doorWorstClass = nil
            ghost.phantom_doorWorstState = nil
            ghost.phantom_doorBlocked    = 0

            -- ⚠ EL CONTADOR NUEVO ENTRA EN EL RESET. Sin esto, el A/B que la
            -- planilla manda hacer arrastraria el numero de la primera mitad al
            -- medir la segunda, que es la contaminacion que el reset existe para
            -- evitar. *Un contador nuevo que no entra en el reset convierte el
            -- boton de limpiar en un boton que limpia casi todo.*
            ghost.phantom_doorNoPuerta   = 0
            -- ⚠ Y el de SERES tambien, por la MISMA regla que el comentario de
            -- arriba enuncia -- que se escribio para el contador de al lado y se
            -- olvido al partirlo en dos el 2026-08-10. *Una regla escrita arriba
            -- del campo no se aplica sola al campo que nace debajo.*
            ghost.phantom_doorSer        = 0
            ghost.phantom_doorBlocker    = nil

        end )

        say( "[Phantasmagoria] contadores y peor-marca reseteados en " .. n .. " fantasma(s). Las huellas NO se tocan." )
        return

    end

    say( "[Phantasmagoria] convars: abrir " .. cvOpen:GetInt() ..
        " · atravesar " .. cvPhase:GetInt() ..
        " · silencio " .. cvSilent:GetInt() ..
        "   ( 0 nadie · 1 el flag del NPC · 2 todos )" ..
        "   destrabar " .. ( cvUnlock:GetBool() and "SI" or "NO" ) )

    -- LA MITAD DE ENFRENTE, Y NO ES DECORACION: server_steps.lua overridea
    -- IsSilentStepping, que es el mismo if del que cuelga el CLICK de Use2
    -- ( shared.lua:1234 ). O sea que un fantasma con las pisadas calladas abre
    -- puertas sin click aunque `silencio` este en 0 -- y el chirrido de la hoja
    -- sigue sonando, asi que desde afuera se lee como "el silencio anda a
    -- medias" en vez de como "otro bloque me lo apago".
    --
    -- Es exactamente el defecto que costo la fila 02 de la ronda 7: las dos
    -- mitades de una misma comparacion en dos pantallas distintas. *El numero de
    -- un A/B tiene que decir de que lado del A/B esta.*
    local cvSteps = GetConVar( "phantasmagoria_ghost_stepsilent" )
    local cvStepsHunt = GetConVar( "phantasmagoria_ghost_stepsonlyhunt" )

    say( "    pisadas: stepsilent " .. ( cvSteps and cvSteps:GetInt() or "??" ) ..
        " · stepsonlyhunt " .. ( cvStepsHunt and cvStepsHunt:GetInt() or "??" ) ..
        "   <- si alguna calla las pisadas, TAMBIEN calla el click de esta puerta" )

    -- LA CONSTANTE, MEDIDA Y NO CITADA. Toda la eleccion de mascara se apoya en
    -- una afirmacion sobre que bits trae MASK_NPCWORLDSTATIC, y este proyecto ya
    -- pago dos veces por afirmar el contenido de una constante sin mirar el
    -- numero. El AND contra CONTENTS_MOVEABLE -- el bit de los brush entities,
    -- o sea de func_door_rotating -- lo contesta en pantalla:
    --   sin MOVEABLE  -> el trace del bot ignora los brush entities y los pasa
    --   con MOVEABLE  -> los sigue chocando, y esa mascara no sirve para func_door_*
    local mask, maskName = phaseMask()
    local traeMoveable   = bit.band( mask, CONTENTS_MOVEABLE ) ~= 0

    say( "[Phantasmagoria] atravesar: modo " .. cvPhase:GetInt() ..
        " ( 0 nadie · 1 segun el flag del NPC · 2 todos )" )
    say( "    mascara   " .. maskName .. " = " .. mask ..
        "   CONTENTS_MOVEABLE ( " .. CONTENTS_MOVEABLE .. " ) " ..
        ( traeMoveable and "SI la trae -> sigue chocando con brush entities ( func_door_* )"
                       or "NO la trae -> los brush entities dejan de frenarlo" ) )
    say( "    la solida " .. ( MASK_NPCSOLID ) .. " es MASK_NPCSOLID, a la que vuelve al salir" )

    local found = PHANTASMAGORIA.EachGhost( function( ghost )
        local st   = ghost.phantom_doorStats
        local info = ghost.phantom_doorInfo

        say( "#" .. ghost:EntIndex() .. "  " .. ghost:GetClass() )

        -- Con que se sondeo. Es el dato en disputa: la hipotesis dice que la
        -- base falla por mirar el AIM en vez de la marcha.
        say( "    sondeo    direccion por " .. ( ghost.phantom_doorDirSrc or "( todavia no corrio )" ) ..
            "   alcance " .. math.Round( ghost.phantom_doorReach or 0 ) .. " u" ..
            "   ( velocidad x " .. LOOKAHEAD_SECONDS .. " s, entre " .. LOOKAHEAD_MIN .. " y " .. LOOKAHEAD_MAX .. " )" )

        -- Las TRES cosas que hacen falta para saber por que atraviesa o no, y
        -- separadas porque tienen causas distintas: si puede, por que, y si
        -- ahora mismo lo esta haciendo.
        -- LAS TRES CAPACIDADES, cada una con su motivo Y con el valor crudo del
        -- campo al lado. El valor crudo es lo que faltaba en la ronda 2: cuando
        -- el autor apago el flag a mano con un lua_run, no habia forma de ver si
        -- la asignacion habia entrado.
        for _, fila in ipairs( {
            { "abre     ", "phantom_OpensDoors",       ghost.phantom_CanOpenDoors },
            { "atraviesa", "phantom_PhasesDoors",      ghost.phantom_CanPhaseDoors },
            { "silencio ", "phantom_SilentDoors",      ghost.phantom_WantsSilentDoors },
            { "camina   ", "phantom_WalksWhenHunting", ghost.phantom_WalksHunting },
        } ) do
            local si, porque = fila[ 3 ]( ghost )

            say( "    " .. fila[ 1 ] .. " " .. ( si and "SI " or "NO " ) ..
                "  campo = " .. tostring( ghost[ fila[ 2 ] ] ) ..
                "   porque " .. porque )

        end

        if ghost.phantom_Phasing then
            say( "    estado    ATRAVESANDO hace " ..
                string.format( "%.1f", CurTime() - ( ghost.phantom_PhasingSince or CurTime() ) ) .. " s" ..
                "   con " .. tostring( ghost.phantom_PhasingMask ) )

        else
            say( "    estado    solido" ..
                ( ghost.phantom_PhasingFor and ( "   ( la ultima vez atraveso " ..
                    string.format( "%.1f", ghost.phantom_PhasingFor ) .. " s )" ) or "   ( nunca atraveso )" ) )

        end

        local door = ghost.phantom_doorLast

        if IsValid( door ) and info then
            say( "    delante   " .. door:GetClass() .. " #" .. door:EntIndex() ..
                "   " .. info.campo .. " = " .. tostring( info.crudo ) ..
                "   " .. ( info.abierta and "ABIERTA" or ( info.cerrada and "cerrada" or "en movimiento" ) ) ..
                ( info.locked and "   CON LLAVE" or "" ) ..
                "   a " .. math.Round( ghost:GetRangeTo( door ) ) .. " u" )

            say( "    trabado   " .. string.format( "%.1f", ghost.phantom_doorBlocked or 0 ) .. " s contra ESTA" ..
                "   ( velocidad " .. math.Round( ghost:GetCurrentSpeed() ) .. " u/s, el umbral es " .. STUCK_SPEED .. " )" )

        else
            -- ⚠ "NINGUNA PUERTA" Y "ALGO QUE NO RECONOZCO" NO SE PUEDEN SEGUIR
            -- IMPRIMIENDO IGUAL -- r3, fila 06. El autor reporto un fantasma
            -- atrapado en dos puertas con vidrio, y este renglon era el unico que
            -- podia hablar de eso: decia lo mismo con el pasillo despejado que
            -- con el bot pegado a una hoja de una clase que la lista blanca no
            -- conoce. Ver el bloque de `phantom_doorBlocker` en doorAhead.
            local bl = ghost.phantom_doorBlocker

            if bl and ( CurTime() - ( bl.cuando or 0 ) ) < 2 then
                say( "    delante   ninguna PUERTA, pero el sondeo SI pega:" )
                say( "              " .. tostring( bl.clase ) ..
                    ( bl.indice and bl.indice > 0 and ( " #" .. bl.indice ) or "" ) ..
                    ( ( bl.nombre and bl.nombre ~= "" ) and ( "  targetname '" .. bl.nombre .. "'" ) or "  sin targetname" ) ..
                    "  a " .. tostring( bl.dist ) .. " u" )

                if bl.modelo and bl.modelo ~= "" then
                    say( "              modelo '" .. bl.modelo .. "'" )

                end

                if bl.esSer then
                    -- ⚠ UN SER NO LLEVA EL CONSEJO DE DOOR_CLASSES. Antes si, y
                    -- el reporte terminaba diciendole al autor que evaluara
                    -- agregar `player` a la lista blanca de puertas -- sobre EL
                    -- MISMO, parado ahi para poder leer el reporte.
                    say( "              ⚠ ES UN SER, NO GEOMETRIA: no hay nada que agregar a ninguna lista." )
                    say( "                Se cuenta aparte a proposito ( ver los dos acumulados de abajo )." )
                    say( "                Si sos vos, corrase: parado ahi estas midiendo tu propio bloqueo." )

                else
                    say( "              ⚠ ESA CLASE **NO** ESTA EN DOOR_CLASSES ( prop_door_rotating, func_door," )
                    say( "                func_door_rotating ), asi que para este bloque no es una puerta: no la" )
                    say( "                abre, no la atraviesa, y el cronometro de trabado ni siquiera corre." )
                    say( "                Parate delante y corre phantasmagoria_ghost_puerta para el detalle." )

                end

            else
                say( "    delante   ninguna puerta, y el sondeo tampoco pega contra nada" )

            end

            -- ⚠ EL CONTADOR VA **ACA**, ARRIBA DEL early return DE `st`, y ese es
            -- el punto entero: el reporte corta con "( todavia no vio ninguna
            -- puerta cerrada )" cuando `phantom_doorStats` no existe, que es
            -- justo el estado de un fantasma que nunca reconocio una puerta --
            -- o sea la escena de la fila 06. Impreso mas abajo, el numero que
            -- esta fila fue a buscar no aparecia nunca.
            -- ⚠⚠ LOS DOS ACUMULADOS VAN SEPARADOS, y esa es toda la correccion:
            -- el de GEOMETRIA es el que senala una hoja que la lista blanca no
            -- reconoce ( el sintoma de la r2 ) y el de SERES sube cada vez que
            -- alguien -- casi siempre el que esta leyendo el reporte -- se para
            -- delante del bot. Sumados en un solo numero, observar el fenomeno
            -- lo inflaba: 20 -> 84 -> 146 en la corrida del 2026-08-10, con el
            -- autor parado ahi. *Un instrumento que cuenta al observador entre
            -- los sujetos no mide el fenomeno, mide la medicion.*
            say( "              acumulado: topo con GEOMETRIA que no es puerta " ..
                ( ghost.phantom_doorNoPuerta or 0 ) .. " tick(s) de sondeo" ..
                ( ( ghost.phantom_doorNoPuerta or 0 ) > 0
                  and "   ( parate ahi y corre phantasmagoria_ghost_puerta )" or "" ) )
            say( "                         topo con un SER ( jugador / NPC / nextbot ) " ..
                ( ghost.phantom_doorSer or 0 ) .. " tick(s)" ..
                "   ( NO es un defecto: alguien estaba delante )" )

        end

        -- EL NUMERO QUE CONTESTA EL SINTOMA REPORTADO. "Suele quedarse pegado
        -- abriendolas" es una frase; esto es un segundero. Y el estado va al
        -- lado porque cambia el veredicto: trabarse contra una puerta CERRADA
        -- es lo que este archivo arregla, contra una ABIERTA no.
        -- LA POSICION DEL A/B, PEGADA AL NUMERO QUE EL A/B COMPARA. Lo destapo la
        -- ronda 7: `peor` lo imprime ESTE comando y el interruptor runsafety solo
        -- se veia en phantasmagoria_ghost_speed. Las dos mitades de una misma
        -- comparacion en dos pantallas distintas es como se pierde un A/B: la
        -- corrida quedo sin poder decir de que lado estaba cada lectura, y la
        -- fila que existia justamente para dar ese numero se marco verde sin el.
        --
        -- La convar es de server_speed.lua, asi que se pide por nombre: un local
        -- compartido entre los dos archivos seria la dependencia cruzada que ya
        -- hay que desarmar en ResolveFlag.
        local cvSafety = GetConVar( "phantasmagoria_ghost_runsafety" )

        say( "    peor      " .. string.format( "%.1f", ghost.phantom_doorWorst or 0 ) .. " s" ..
            ( ghost.phantom_doorWorstClass and ( "   contra un " .. ghost.phantom_doorWorstClass ..
                " " .. tostring( ghost.phantom_doorWorstState ) ) or "" ) ..
            "   [ runsafety " .. ( cvSafety and cvSafety:GetInt() or "?" ) ..
            ( cvSafety and cvSafety:GetBool() and ": cazando respeta canRunOnPath ]" or ": cazando corre SIEMPRE ]" ) )

        if not st then
            say( "    contadores  ( todavia no vio ninguna puerta cerrada )" )
            return

        end

        -- vistas y vetadas van ANTES de intentos porque contestan la pregunta
        -- que la ronda 3 no pudo contestar: si no abre, es porque no vio
        -- puertas o porque vio y se abstuvo. Antes las dos daban el mismo cero.
        -- LA ETIQUETA DECIA "puertas cerradas DISTINTAS" Y ERA FALSA: la ronda 4
        -- reporto 191 en un mapa que no tiene 191 puertas. El contador sube
        -- cuando una puerta cerrada ENTRA al sondeo, y una misma puerta entra y
        -- sale muchas veces mientras el fantasma se mueve delante de ella. El
        -- numero estaba bien; la palabra "distintas" era mia y mentia.
        say( "    vistas    " .. st.vistas .. " veces que una puerta CERRADA entro al sondeo" ..
            "   ( la misma puerta cuenta varias si entra y sale )" )
        say( "    VETADAS   " .. st.vetadas .. " aperturas bloqueadas ( incluidas las que iba a hacer la BASE por su cuenta )" )
        say( "    intentos  " .. st.intentos .. " sobre una puerta CERRADA delante" )
        say( "    escalera  1 Use2 " .. st.use ..
            "   ·  2 OpenAwayFrom " .. st.away ..
            "   ·  3 Fire Open " .. st.open ..
            "   ·  destrabadas " .. st.unlock )
        say( "    atraveso  " .. st.fases .. " veces   ( todas por cercania: a " .. PHASE_RANGE .. " u o menos )" ..
            ( st.fasesLargas > 0 and ( "   ·  " .. st.fasesLargas .. " FORZADAS a solido por el techo de " ..
                PHASE_MAX .. " s: eso no deberia pasar" ) or "" ) )
        -- LOS DOS NUMEROS SEPARADOS, y el segundo es el que mide el agujero que
        -- se cerro antes de la ronda 6: el silencio colgaba solo de NUESTRA
        -- escalera y la base abre puertas por su cuenta. Si silenciosBase sube,
        -- son aperturas que hasta ese arreglo sonaban -- y phantasmagoria_ghost_testdoor
        -- no las podia ver, porque fuerza nuestro camino.
        say( "    silencio  " .. st.silencios .. " ventanas de silencio abiertas" ..
            "   ·  " .. st.silenciosBase .. " de ellas sobre aperturas de LA BASE, no de nuestra escalera" ..
            "   ·  " .. st.silenciosHermanas .. " hojas HERMANAS silenciadas de arrastre ( puertas dobles )" ..
            "   ( tapa el click del bot Y el sonido de la hoja, " .. SILENCE_WINDOW .. " s )" )
        say( "    resultado ABRIO " .. st.abrio .. "   fallo " .. st.fallo ..
            "   ( releyendo el estado " .. VERIFY_AFTER .. " s despues; ABRIENDO cuenta como abrio )" )
        say( "    huellas   " .. st.huellas .. " dejadas por este fantasma" )

    end )

    if found <= 0 then
        say( "[Phantasmagoria] no hay ningun fantasma vivo." )

    end

    -- Las huellas son globales y no por fantasma: van fuera del bucle.
    local prints = PHANTASMAGORIA.Prints
    local now    = CurTime()
    local vivas  = 0

    for _, p in ipairs( prints ) do
        if p.expire > now and IsValid( p.ent ) then vivas = vivas + 1 end

    end

    say( "[Phantasmagoria] huellas vivas: " .. vivas .. " de " .. #prints .. " guardadas" ..
        "   ( duran " .. PRINT_LIFE .. " s; se DIBUJAN con el gate abierto: en la consola del" ..
        " cliente  phantasmagoria_uv 1  -- gate provisional hasta que exista la linterna )" )

    -- LA BITACORA DE SONIDO, que existe para una falla concreta: en la ronda 3
    -- el autor reporto que la puerta "sigue sonando" y no habia forma de saber
    -- QUE sonaba. Aca sale con nombre de archivo y emisor, y si se bloqueo o no.
    -- Vacia NO significa que ande: significa que no hubo ninguna ventana de
    -- silencio abierta ( o que nadie sono cerca ), y eso tambien es un dato.
    local log      = PHANTASMAGORIA.SilenceLog
    local mudas    = 0

    for _, ent in ipairs( ents.GetAll() ) do
        if ent.phantom_DoorSounds then mudas = mudas + 1 end

    end

    say( "[Phantasmagoria] bitacora del silencio   ( puertas mudas AHORA MISMO: " .. mudas ..
        ( mudas > 0 and " -- deberia volver a 0 solo en " .. SILENCE_WINDOW .. " s )" or " )" ) )

    if #log <= 0 then
        say( "    VACIA. Con el silencio en 1 o 2 y una apertura, esto tiene que llenarse. " ..
            "Si sigue vacia, phantom_SilenceDoor no esta corriendo -- mirar la linea 'silencio' de arriba." )

    else
        for _, linea in ipairs( log ) do
            say( "    " .. linea )

        end
    end

    -- Un silenciado sin su devolucion es EL defecto grave de este mecanismo, y
    -- por eso el reporte lo cuenta en vez de dejarlo para que alguien lo note.
    if mudas > 0 then
        say( "    ( si este numero no baja solo, correr phantasmagoria_ghost_doors restore )" )

    end

    for i = math.max( #prints - 4, 1 ), #prints do
        local p = prints[ i ]
        if not p then continue end

        -- El `via` distingue las dos formas en que se pudo conseguir el punto, y
        -- existe porque la r1 dejo la huella en el lugar equivocado y el reporte
        -- no ayudaba a saber por que: `linea` es el trace de mano ( el bueno ),
        -- `cercano` es el fallback por NearestPoint, `manual` es el comando de
        -- prueba. Si una huella vuelve a quedar mal puesta, esta palabra dice
        -- cual de los tres caminos la puso.
        say( "    huella " .. i .. "  mano " .. p.hand ..
            "   en " .. ( IsValid( p.ent ) and ( p.ent:GetClass() .. " #" .. p.ent:EntIndex() ) or "( puerta borrada )" ) ..
            "   via " .. ( p.via or "?" ) ..
            "   quedan " .. math.max( math.Round( p.expire - now ), 0 ) .. " s" )

    end
end, "Imprime que puerta tiene delante cada fantasma, cuanto lleva trabado contra ella, que peldano de la escalera uso y cuantas huellas dejo." )

---------------------------------------------------------------------------
-- INSTRUMENTO: LA COSA QUE ESTOY MIRANDO -- r3, fila 06
---------------------------------------------------------------------------
-- El autor reporto: *"quedan atrapados en dos puertas que tienen vidrios, ni
-- siquiera la abren, son las dos puertas para ir a la piscina"*.
--
-- ⚠ NINGUNO DE LOS DOS INSTRUMENTOS QUE YA EXISTEN PUEDE CONTESTAR ESO, y el
-- motivo es estructural y no un olvido: `phantasmagoria_ghost_doors` y
-- `phantasmagoria_ghost_stuck` cuelgan **del fantasma**, y el fantasma solo sabe
-- de lo que la lista blanca de tres clases ya reconocio. Si esas dos hojas son
-- de otra clase, los dos comandos van a decir "ninguna puerta" para siempre, con
-- toda la razon y sin ayudar en nada.
--
-- Este cuelga **del jugador**: parado delante de la hoja y con el crosshair
-- encima, contesta que ES esa cosa y por que el fantasma no la trata como una
-- puerta. Es la diferencia entre adivinar el arreglo y medir el sujeto.
--
-- LAS TRES MASCARAS NO SON UN ADORNO: son lo que convierte "es de vidrio" en un
-- numero. Si `MASK_BLOCKLOS` NO pega y `MASK_NPCSOLID` SI, esa cosa **deja ver y
-- no deja pasar** -- que es la definicion de un panel de vidrio y tambien el
-- modo de falla que traba a un nextbot: el navmesh dice que hay camino, la vista
-- dice que hay camino, y el cuerpo no entra.
--
-- *El objetivo de este comando no es arreglar nada: es que la proxima ronda
-- tenga un dato en vez de una anecdota.*
local function contentsLegibles( n )
    local nombres = {
        { CONTENTS_SOLID,       "SOLID"       },
        { CONTENTS_WINDOW,      "WINDOW"      },
        { CONTENTS_GRATE,       "GRATE"       },
        { CONTENTS_MOVEABLE,    "MOVEABLE"    },
        { CONTENTS_MONSTER,     "MONSTER"     },
        { CONTENTS_PLAYERCLIP,  "PLAYERCLIP"  },
        { CONTENTS_MONSTERCLIP, "MONSTERCLIP" },
    }

    local puestos = {}

    for _, par in ipairs( nombres ) do
        if bit.band( n, par[ 1 ] ) ~= 0 then puestos[ #puestos + 1 ] = par[ 2 ] end

    end

    return #puestos > 0 and table.concat( puestos, "+" ) or "( ninguno de los mirados )"

end

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_puerta", function( ply, _, args )
    -- ⚠ ESTE COMANDO MIDE LO QUE EL OPERADOR ESTA MIRANDO, asi que desde la
    -- consola del servidor no hay sujeto. Se dice en vez de tirar un error de
    -- indexacion sobre un `ply` invalido.
    if not IsValid( ply ) then
        print( "[Phantasmagoria] este comando mide lo que estas MIRANDO: hay que correrlo desde el juego." )
        return

    end

    if not ply:IsAdmin() then
        ply:PrintMessage( HUD_PRINTCONSOLE, "[Phantasmagoria] hace falta ser admin." )
        return

    end

    local say = PHANTASMAGORIA.MakeSay( ply )
    local ojo = ply:EyePos()
    local dir = ply:GetAimVector()

    -- `MASK_NPCSOLID` es la del CUERPO del bot ( terminator_nextbot_base/
    -- init.lua:68 ) y `MASK_BLOCKLOS` la de su VISTA ( la base, shared.lua:239 ).
    -- Las dos salen de la base y no de una eleccion nuestra: por eso el veredicto
    -- de abajo habla del fantasma y no de un trace cualquiera.
    local MASCARAS = {
        { "MASK_SOLID",    MASK_SOLID    },
        { "MASK_NPCSOLID", MASK_NPCSOLID },
        { "MASK_BLOCKLOS", MASK_BLOCKLOS },
    }

    local pegaron = {}
    local ent, tr

    say( "" )
    say( "===== LA COSA QUE ESTAS MIRANDO ( r3, las puertas de vidrio ) =====" )

    for _, m in ipairs( MASCARAS ) do
        local t = util.TraceLine( { start = ojo, endpos = ojo + dir * 200, mask = m[ 2 ], filter = ply } )

        pegaron[ m[ 1 ] ] = t.Hit

        say( "  " .. m[ 1 ] .. string.rep( " ", 16 - #m[ 1 ] ) ..
            ( t.Hit and ( "PEGA a " .. math.Round( ( t.HitPos - ojo ):Length() ) .. " u  contra " ..
                ( IsValid( t.Entity ) and ( t.Entity:GetClass() .. " #" .. t.Entity:EntIndex() ) or "el MUNDO" ) ..
                "   MatType " .. tostring( t.MatType ) ..
                "   HitTexture '" .. tostring( t.HitTexture ) .. "'" )
              or "no pega ( nada solido para esta mascara en 200 u )" ) )

        if not ent and t.Hit and IsValid( t.Entity ) then ent, tr = t.Entity, t end
        if not tr and t.Hit then tr = t end

    end

    -- ⚠ EL VEREDICTO SALE DE LA **DIFERENCIA** ENTRE DOS MEDICIONES Y NO DE UNA
    -- SOLA. Un renglon que diga "es vidrio" sin decir de donde lo saco es una
    -- opinion con formato de dato.
    say( "" )

    if pegaron[ "MASK_NPCSOLID" ] and not pegaron[ "MASK_BLOCKLOS" ] then
        say( "  ⭐ VEREDICTO: DEJA VER Y NO DEJA PASAR. El cuerpo del bot choca ( NPCSOLID ) y su vista" )
        say( "     lo atraviesa ( BLOCKLOS ). Eso es un panel de vidrio, y es el modo de falla que traba" )
        say( "     a un nextbot: el navmesh y la vista dicen que hay camino, y el cuerpo no entra." )

    elseif pegaron[ "MASK_NPCSOLID" ] and pegaron[ "MASK_BLOCKLOS" ] then
        say( "  VEREDICTO: tapa las dos cosas, o sea que es un solido normal y no un vidrio." )
        say( "     Si el fantasma se traba aca, no es por transparencia." )

    elseif not pegaron[ "MASK_NPCSOLID" ] then
        say( "  VEREDICTO: el cuerpo del bot NO choca con esto. Si el fantasma se traba, lo traba otra" )
        say( "     cosa: apunta al marco, al piso, o a lo que tenga al lado." )

    end

    if not IsValid( ent ) then
        say( "" )
        say( "  no hay ninguna ENTIDAD ahi: pegaste en el mundo, o en un prop estatico horneado." )
        say( "  ⚠ Los prop_static NO existen como entidad en runtime. Un trace SI los pega, pero" )
        say( "    tr.Entity es el MUNDO y el discriminador de que pegaste en uno es que HitTexture" )
        say( "    valga '**studio**'. Mira ese campo en las tres lineas de arriba." )
        return

    end

    local clase = ent:GetClass()
    local dentro = tr and util.PointContents( tr.HitPos + dir * 2 ) or 0

    say( "" )
    say( "  clase       " .. clase )
    say( "  targetname  '" .. tostring( ent:GetName() ) .. "'" )
    say( "  indice      #" .. ent:EntIndex() .. "   modelo '" .. tostring( ent:GetModel() ) .. "'" )
    say( "  contents    " .. dentro .. "  ->  " .. contentsLegibles( dentro ) ..
        "   ( medido 2 u ADENTRO de la superficie )" )

    ---------------------------------------------------------------------------
    -- LA LINEA QUE CONTESTA "¿POR QUE EL FANTASMA NO LA ABRE?"
    ---------------------------------------------------------------------------
    if not DOOR_CLASSES[ clase ] then
        say( "" )
        say( "  ⭐ ESTA CLASE **NO** ESTA EN DOOR_CLASSES, que admite prop_door_rotating, func_door y" )
        say( "     func_door_rotating y nada mas. Para todo este bloque, esto NO es una puerta: el" )
        say( "     fantasma no la abre, no la atraviesa, y su cronometro de trabado ni siquiera arranca." )
        say( "     **Es la causa mas probable del reporte de la r2.**" )
        say( "     ⚠ Si hay que agregarla, hay que tocar LAS DOS copias de la tabla: la de este archivo" )
        say( "     y la de server_events.lua, o el evento de golpes queda mirando una lista distinta." )
        return

    end

    local info = readDoor( ent )

    say( "" )
    say( "  ES UNA PUERTA RECONOCIDA." )
    say( "  estado      " .. info.campo .. " = " .. tostring( info.crudo ) .. "   " ..
        ( info.abierta and "ABIERTA" or ( info.cerrada and "cerrada" or "en movimiento" ) ) ..
        ( info.locked and "   ⚠ CON LLAVE" or "" ) )

    -- Los keyvalues que deciden si el peldano 1 puede hacer algo: en un `func_door`
    -- el bit "Use Opens" de `spawnflags` es la diferencia entre una puerta que
    -- responde a Use y una que solo responde a un boton.
    local kv = ent.GetKeyValues and ent:GetKeyValues() or nil

    if istable( kv ) then
        for _, k in ipairs( { "spawnflags", "speed", "opendir", "slavename", "filtername" } ) do
            if kv[ k ] ~= nil then
                say( "  kv." .. k .. string.rep( " ", 12 - #k ) .. tostring( kv[ k ] ) )

            end
        end
    end

    ---------------------------------------------------------------------------
    -- EL SUBCOMANDO QUE MIDE EL EFECTO Y NO LA INTENCION
    ---------------------------------------------------------------------------
    if args and args[ 1 ] == "use" then
        local ghost

        PHANTASMAGORIA.EachGhost( function( g ) if not ghost then ghost = g end end )

        if not IsValid( ghost ) then
            say( "" )
            say( "  'use' necesita un fantasma en el mapa: lo que prueba es SU camino ( ghost:Use2 )," )
            say( "  no un Fire generico, justamente porque el fantasma es el que falla." )
            return

        end

        -- ⚠ SE NIEGA SI LA APERTURA ESTA VETADA, y es la leccion de la ronda 6:
        -- `testdoor` gritaba ESCUCHA AHORA sobre una apertura que el veto se iba a
        -- comer. Sin esta rama, un "no se movio" no mediria la puerta: mediria la
        -- convar.
        local puede, motivo = ghost:phantom_CanOpenDoors()

        if not puede then
            say( "" )
            say( "  ⚠ NO SE DISPARA NADA: la apertura esta vetada -- " .. tostring( motivo ) )
            return

        end

        local antes = readDoor( ent ).crudo

        ghost:Use2( ent )

        -- El estado de una puerta cambia en el tick siguiente, no en este: el
        -- veredicto llega diferido, igual que en el evento de puertas.
        timer.Simple( 0.3, function()
            if not IsValid( ent ) or not IsValid( ply ) then return end

            local say2 = PHANTASMAGORIA.MakeSay( ply )
            local desp = readDoor( ent ).crudo

            say2( "  use -> " .. ( desp ~= antes
                and ( "SE MOVIO ( " .. tostring( antes ) .. " -> " .. tostring( desp ) .. " )" )
                or ( "SIN EFECTO ( sigue en " .. tostring( antes ) .. " ). Con el veto ya descartado, " ..
                     "quedan la lista negra de clases de la base y el hook TerminatorBlockUse de un tercero." ) ) )

        end )

        say( "" )
        say( "  use disparado desde el fantasma #" .. ghost:EntIndex() .. ". El veredicto llega en 0,3 s." )

    end
end, "Mide la cosa que estas mirando: si el fantasma la reconoce como puerta, si es vidrio, y por que no la abre. Subcomando: 'use'." )
