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

-- Cuanto hay que estar trabado contra una hoja ABIERTA antes de atravesarla.
-- Es el rescate de la puerta que se abrio en reversa encima del bot ( ronda 5:
-- 17,6 s clavado ). No corre para puertas cerradas a proposito: esas ya las
-- cubre la cercania, y taparlas con un atravesado escondería otro problema.
local STUCK_PHASE_AFTER = 2

local DOOR_CLASSES = {
    [ "prop_door_rotating" ] = true,
    [ "func_door" ]          = true,
    [ "func_door_rotating" ] = true,
}

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

PHANTASMAGORIA.ReadDoor = readDoor

---------------------------------------------------------------------------
-- Las huellas
---------------------------------------------------------------------------
-- Diseno 8.5 ya fijo la forma y aca se respeta al pie: el SERVIDOR guarda la
-- huella como DATO y no pinta nada; el cliente la dibuja solo mientras la UV
-- apunta. Ese dibujo NO es de este bloque -- necesita la linterna UV, que no
-- existe -- asi que lo unico que se escribe aca es el productor.
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

    -- El enganche para el bloque de la UV, que todavia no existe. Se declara
    -- ahora porque el productor es este y el consumidor es otro: si el gancho
    -- no esta, el bloque de la UV tiene que volver a tocar este archivo.
    hook.Run( "PhantasmagoriaGhostUsedDoor", p.ghost, p.ent )

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
        return hit, tr, src, reach

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
-- reabrio va SEPARADO de away aunque los dos disparen la misma entrada del
-- engine: uno es "la puerta estaba cerrada y el peldano 1 no alcanzo" y el otro
-- es "la hoja se abrio encima del bot". Son dos fallas distintas y un contador
-- compartido las volveria indistinguibles justo en el reporte.
local function stats( ghost )
    ghost.phantom_doorStats = ghost.phantom_doorStats or {
        vistas = 0, intentos = 0, use = 0, unlock = 0, away = 0, open = 0, reabrio = 0,
        abrio = 0, fallo = 0, huellas = 0, fases = 0, fasesLargas = 0,
        silencios = 0, fasesPorAtasco = 0, vetadas = 0,
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
hook.Add( "TerminatorBlockUse", "phantasmagoria_veto_puertas", function( bot, used )
    if not IsValid( bot ) then return end
    if not bot.IsPhantasmagoriaGhost then return end
    if not IsValid( used ) then return end
    if not DOOR_CLASSES[ used:GetClass() ] then return end

    if bot:phantom_CanOpenDoors() then return end

    stats( bot ).vetadas = stats( bot ).vetadas + 1

    return true

end )

local function phaseMask()
    if cvPhaseMask:GetBool() then
        return MASK_NPCWORLDSTATIC, "MASK_NPCWORLDSTATIC"

    end

    return MASK_NPCSOLID_BRUSHONLY, "MASK_NPCSOLID_BRUSHONLY"

end

PHANTASMAGORIA.PhaseMask = phaseMask

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

    local puede, motivo = self:phantom_CanPhaseDoors()
    self.phantom_PhaseWhy = motivo

    -- LA SEGUNDA PUERTA DE ENTRADA AL ATRAVESADO, REESCRITA CON LA CONDICION
    -- QUE PIDIO EL AUTOR EN LA RONDA 5. La version anterior disparaba con
    -- cualquier puerta que estuviera lejos, salio 0 en todos los reportes de
    -- tres rondas, y la fila que iba a borrarla encontro para que servia:
    --
    --     trabado 15,2 s   ·   delante func_door_rotating   m_toggle_state = 0
    --     ABIERTA   a 0 u
    --
    -- La hoja se abrio ENCIMA del bot y lo dejo clavado 17,6 s. Su propuesta,
    -- literal: *"que quede trabado mucho tiempo -> phase momentaneo, con la
    -- CONDICION de que la puerta marque como ABIERTA; si esta cerrada no tiene
    -- por que pasar, asi evitamos que las puertas que abren en reversa dejen
    -- pillado al npc"*.
    --
    -- Y es mejor que lo que yo tenia por dos motivos: una puerta CERRADA ya la
    -- cubre la regla de cercania -- el atasco ahi seria otro problema y taparlo
    -- con un atravesado lo escondería --, y limitarlo a la hoja abierta ataca
    -- exactamente el caso que no tiene ninguna otra salida.
    local trabadoContraEsta = ( self.phantom_doorBlocked or 0 ) > STUCK_PHASE_AFTER
    local porAtasco         = puede and trabadoContraEsta and info.abierta

    if porAtasco and not self.phantom_Phasing then
        stats( self ).fasesPorAtasco = stats( self ).fasesPorAtasco + 1

    end

    if puede and ( distancia <= PHASE_RANGE or porAtasco ) then
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

    local puedeAbrir, motivoAbrir = self:phantom_CanOpenDoors()
    self.phantom_OpenWhy = motivoAbrir

    if not puedeAbrir then return end

    -- Contra el TOGGLE: dos Use seguidos abren y cierran. Se respetan los dos
    -- relojes, el nuestro y el de la base ( term_NextUse, que tryToOpen pone en
    -- CurTime() + 3 cuando ella misma abre, shared.lua:1344 ). Respetar el de
    -- ella es lo que evita que los dos codigos se peleen la misma puerta.
    if ( door.phantom_nextTry or 0 ) > now then return end
    if ( door.term_NextUse or 0 ) > now then return end

    local blocked = self.phantom_doorBlocked or 0

    -- La hoja YA ESTA ABIERTA y aun asi el bot no pasa: se abrio encima suyo.
    -- Usarla ahora la CERRARIA, asi que el unico movimiento valido es volver a
    -- abrirla para el otro lado. Si ya estaba abierta hacia el lado correcto
    -- esto es un no-op y el bot sigue trabado -- ahi manda el overrideMiniStuck
    -- de la base ( shared.lua:1356 ), y el cronometro de arriba lo va a mostrar.
    if info.abierta then
        if blocked < FORCE_AFTER * 2 then return end
        if door:GetClass() ~= "prop_door_rotating" then return end

        door.phantom_nextTry = now + RETRY_EVERY
        st.reabrio = st.reabrio + 1

        self:phantom_DoorOpenAwayFrom( door )
        return

    end

    if not info.cerrada then return end -- abriendo o cerrando: dejarla terminar

    st.intentos = st.intentos + 1

    -- Destrabar va PRIMERO y no es un peldano: un Use sobre una puerta con
    -- llave no hace nada ( suena el candado y listo ), asi que sin esto los
    -- tres peldanos fallan igual. En Phasmophobia el fantasma no se queda
    -- afuera de un cuarto porque la puerta tenga llave.
    if info.locked and cvUnlock:GetBool() then
        door:Fire( "Unlock" )
        st.unlock = st.unlock + 1

    end

    door.phantom_nextTry = now + RETRY_EVERY

    -- EL SILENCIO, y va ANTES de tocar la puerta porque las dos mitades tienen
    -- que estar puestas cuando el sonido se emita.
    if self:phantom_WantsSilentDoors() then
        self:phantom_SilenceDoor( door )
        st.silencios = st.silencios + 1

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

    if tr and tr.Hit and tr.Entity == door then
        pendiente = PHANTASMAGORIA.MakePrint( self, door, tr.HitPos, tr.HitNormal )

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

-- La bitacora deja de anotar SONIDOS -- que no podemos ver -- y pasa a anotar
-- las OPERACIONES, que si podemos: que puerta, que valores se guardaron, y si
-- se restauraron. Es el instrumento que corresponde al mecanismo nuevo, y el
-- riesgo que vigila es el unico serio que tiene: **borrar y no devolver** deja
-- la puerta muda para todos, para siempre.
local BITACORA_MAX = 10

PHANTASMAGORIA.SilenceLog = PHANTASMAGORIA.SilenceLog or {}

local silenced = {} -- [ puerta ] = hasta cuando

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

    for _, key in ipairs( DOOR_SOUND_KEYS ) do
        door:SetSaveValue( key, saved[ key ] or "" )

    end

    door.phantom_DoorSounds  = nil
    door.phantom_SilentUntil = nil
    silenced[ door ] = nil

    anotar( "devuelto  " .. door:GetClass() .. " #" .. door:EntIndex() )

    return true

end

function ENT:phantom_SilenceDoor( door )
    -- ① el click del bot: se adelanta el debounce que la propia base consulta
    self.nextUseSound = CurTime() + SILENCE_WINDOW

    -- ② los sonidos de la puerta. Se guardan UNA vez: si se re-silencia con la
    --    ventana abierta, lo guardado ya es "" y devolverlo dejaria la puerta
    --    muda para siempre. El mod de referencia usa el mismo resguardo.
    local saved = door.phantom_DoorSounds

    if not saved then
        saved = {}
        local cuales = {}

        for _, key in ipairs( DOOR_SOUND_KEYS ) do
            local val = door:GetInternalVariable( key )
            saved[ key ] = val

            if val and val ~= "" then cuales[ #cuales + 1 ] = key .. "=" .. tostring( val ) end

        end

        door.phantom_DoorSounds = saved

        anotar( "silenciado " .. door:GetClass() .. " #" .. door:EntIndex() ..
            "   " .. ( #cuales > 0 and table.concat( cuales, "  " ) or "( no tenia ningun sonido declarado )" ) )

    end

    for _, key in ipairs( DOOR_SOUND_KEYS ) do
        door:SetSaveValue( key, "" )

    end

    door.phantom_SilentUntil = CurTime() + SILENCE_WINDOW
    silenced[ door ] = door.phantom_SilentUntil

    timer.Simple( SILENCE_WINDOW + 0.05, function()
        PHANTASMAGORIA.RestoreDoorSounds( door )

    end )
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
            ghost:phantom_SilenceDoor( mejor )
            stats( ghost ).silencios = stats( ghost ).silencios + 1

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

    if args and args[ 1 ] == "reset" then
        local n = PHANTASMAGORIA.EachGhost( function( ghost )
            ghost.phantom_doorStats      = nil
            ghost.phantom_doorWorst      = 0
            ghost.phantom_doorWorstClass = nil
            ghost.phantom_doorWorstState = nil
            ghost.phantom_doorBlocked    = 0

        end )

        say( "[Phantasmagoria] contadores y peor-marca reseteados en " .. n .. " fantasma(s). Las huellas NO se tocan." )
        return

    end

    say( "[Phantasmagoria] convars: abrir " .. cvOpen:GetInt() ..
        " · atravesar " .. cvPhase:GetInt() ..
        " · silencio " .. cvSilent:GetInt() ..
        "   ( 0 nadie · 1 el flag del NPC · 2 todos )" ..
        "   destrabar " .. ( cvUnlock:GetBool() and "SI" or "NO" ) )

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
            say( "    delante   ninguna puerta" )

        end

        -- EL NUMERO QUE CONTESTA EL SINTOMA REPORTADO. "Suele quedarse pegado
        -- abriendolas" es una frase; esto es un segundero. Y el estado va al
        -- lado porque cambia el veredicto: trabarse contra una puerta CERRADA
        -- es lo que este archivo arregla, contra una ABIERTA no.
        say( "    peor      " .. string.format( "%.1f", ghost.phantom_doorWorst or 0 ) .. " s" ..
            ( ghost.phantom_doorWorstClass and ( "   contra un " .. ghost.phantom_doorWorstClass ..
                " " .. tostring( ghost.phantom_doorWorstState ) ) or "" ) )

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
        say( "    reabrio   " .. st.reabrio .. " veces una hoja que ya estaba ABIERTA y le tapaba el paso" )
        say( "    atraveso  " .. st.fases .. " veces" ..
            "   ·  " .. st.fasesPorAtasco .. " de ellas por ATASCO y no por cercania" ..
            ( st.fasesLargas > 0 and ( "   ·  " .. st.fasesLargas .. " FORZADAS a solido por el techo de " ..
                PHASE_MAX .. " s: eso no deberia pasar" ) or "" ) )
        say( "    silencio  " .. st.silencios .. " aperturas silenciadas" ..
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
        "   ( duran " .. PRINT_LIFE .. " s; NO se dibujan todavia, falta la linterna UV -- Diseno 8.5 )" )

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

        say( "    huella " .. i .. "  mano " .. p.hand ..
            "   en " .. ( IsValid( p.ent ) and ( p.ent:GetClass() .. " #" .. p.ent:EntIndex() ) or "( puerta borrada )" ) ..
            "   quedan " .. math.max( math.Round( p.expire - now ), 0 ) .. " s" )

    end
end, "Imprime que puerta tiene delante cada fantasma, cuanto lleva trabado contra ella, que peldano de la escalera uso y cuantas huellas dejo." )
