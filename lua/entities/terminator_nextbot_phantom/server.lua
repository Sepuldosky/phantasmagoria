--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom / server

    Configuracion minima, EL INTERRUPTOR fantasma/cazador, y los instrumentos
    server-side:
      - el aviso de spawn (que modelo salio, donde, y si hay navmesh)
      - phantasmagoria_ghost_where, que dice donde esta cada fantasma vivo
      - phantasmagoria_ghost_rel, que dice a quien odia y por que
      - phantasmagoria_hunt / _reeval, el gatillo MANUAL y PROVISORIO del hunt
---------------------------------------------------------------------------]]

local function ghostPrint( ... )
    MsgC( Color( 190, 120, 255 ), "[Phantasmagoria] ", color_white, ... )

end

-- La mesa compartida del addon. Existe desde antes ( lua/phantasmagoria/ y el
-- espejo del cliente la usan ) y aca se crea a la defensiva porque este archivo
-- puede cargar primero. Sirve para que los archivos de al lado -- server_speed
-- y server_doors -- alcancen los helpers de este sin duplicarlos: include()
-- corre otro chunk, y un local no cruza.
PHANTASMAGORIA = PHANTASMAGORIA or {}
PHANTASMAGORIA.Print = ghostPrint

-- ANDAMIO. Overrides de flags puestos por consola, que GANAN sobre el campo de
-- la clase y valen tambien para los fantasmas que todavia no existen.
--
-- Nace de un problema real de la ronda 3: el autor no pudo probar los flags. El
-- lua_run que le di escribe en la ENTIDAD, y cada fantasma nuevo nace con el
-- default de su clase -- asi que el cambio se perdia al respawnear, sin que
-- nada lo dijera. Su propia conclusion fue "lo mejor es tener una toolgun dev
-- para agregar flags"; esto es la version barata de eso, y la toolgun sigue
-- siendo la buena cuando existan los 30 tipos.
--
-- Se borra con phantasmagoria_ghost_flag <nombre> auto.
PHANTASMAGORIA.FlagOverrides = PHANTASMAGORIA.FlagOverrides or {}

-- Segundos entre "spawneo con 0 navareas" y volver a medir. El parcheador de la
-- base trabaja de a poco, asi que medir en el mismo frame no dice nada.
local NAVCHECK_DELAY = 10

---------------------------------------------------------------------------
-- El modelo
---------------------------------------------------------------------------
-- Trampa 1 (Referencia 4.3): ENT.Models GANA sobre ENT.Model, y la base trae
-- ENT.Models = { "terminator" } heredado ( shared.lua:157 ). Un fantasma que
-- declare solo ENT.Model spawnea con Arnold, porque shared.lua:2973-2982 lee
-- Models primero y solo cae a Model si Models es nil.
--
-- El criterio de que un modelo sirva NO es el esqueleto: es que declare
-- $includemodel models/m_anm.mdl, porque la base mueve el cuerpo con
-- activities ACT_MP_* del set de player de HL2MP (Referencia 10).
-- EL SKIN VIAJA CON EL MODELO Y NO SUELTO, y no es prolijidad: el 1 se eligio
-- por lo que significa EN scaryblackman ( ojos blancos, Referencia 10 ) y no
-- quiere decir nada en otro modelo. Con el skin como campo aparte, cambiar de
-- modelo se lo lleva puesto en silencio -- shared.lua:2989 lo aplica si es
-- numero, sin preguntar si ese modelo tiene tantos skins.
local MODEL_CANDIDATES = {
    -- EL DE PRUEBAS, por pedido del autor ( 2026-08-06 ): el cadaver de HL2.
    -- Es el mismo que usa HIM sobre ESTA MISMA BASE ( him/.../homeless/shared.lua:12 ),
    -- que es la mejor evidencia posible de que sirve: no es un modelo parecido,
    -- es el mismo modelo corriendo en el mismo cerebro, en produccion.
    --
    -- OJO CON LA CARPETA, y esto ya costo caro una vez en este taller ( la
    -- lesson de hatman: dos archivos con el mismo nombre en carpetas distintas
    -- son binarios distintos ). Existen los dos:
    --
    --   models/humans/corpse1.mdl    el cadaver NPC/prop de HL2
    --   models/player/corpse1.mdl    el playermodel de GMod, con m_anm
    --
    -- y hace falta EL SEGUNDO, porque el criterio de la base no es el
    -- esqueleto sino el $includemodel models/m_anm.mdl. No hay que deducirlo:
    -- HIM trae una tabla de traduccion que hace exactamente ese mapeo
    -- ( sv_zhomeless_shelter.lua:52 ), o sea que el tercero ya tropezo y dejo
    -- escrito el arreglo.
    --
    -- Y no es el quemado: el quemado es "charple" ( humans/charple01 ->
    -- player/charple en la misma tabla ). corpse1 es el otro.
    { mdl = "models/player/corpse1.mdl" },

    -- El del DISENO, que vuelve cuando esta entidad deje de ser un instrumento.
    -- m_anm, hull identico al de Arnold, 54 flexcontrollers. Viene de otro addon
    -- del Workshop y NO esta en este repo.
    { mdl = "models/dejtriyev/scaryblackman.mdl", skin = 1 }, -- Referencia 10: skin 1 = ojos blancos

    -- Del que deriva el anterior. Viene con GMod.
    { mdl = "models/player/group01/male_04.mdl" },
}

local function pickModel()
    for _, cand in ipairs( MODEL_CANDIDATES ) do
        if util.IsValidModel( cand.mdl ) then return cand end

    end

    -- Ultimo recurso: la cadena literal "terminator", que shared.lua:2983
    -- traduce al modelo de la convar termhunter_modeloverride (Arnold por
    -- default). Feo a proposito: si sale Arnold, el modelo no esta montado.
    return { mdl = "terminator" }

end

local chosen = pickModel()

if chosen ~= MODEL_CANDIDATES[ 1 ] then
    ghostPrint( "el modelo ", MODEL_CANDIDATES[ 1 ].mdl, " no esta montado. Uso ", chosen.mdl, " en su lugar.\n" )

end

ENT.Models = { chosen.mdl }

-- Nil cuando el modelo no declara skin propio: shared.lua:2989 solo lo aplica
-- "if isnumber( myTbl.ModelSkin )", asi que nil deja el 0 del modelo y no
-- inventa un indice que ese .mdl puede no tener.
ENT.ModelSkin = chosen.skin

---------------------------------------------------------------------------
-- Desarmado
---------------------------------------------------------------------------
-- El molde es terminator_nextbot_fakeply: un bot desarmado que funciona.
-- Consecuencias medidas en el codigo, no cosmeticas:
--   sin TERM_FISTS no mira hacia el objetivo al moverse ( motionoverrides.lua:2838 )
--   sin TERM_FISTS no pega para desatascarse ( shared.lua:2142 )
-- Las dos son correctas para un fantasma, pero explican comportamiento raro.
ENT.DefaultWeapon = false
ENT.TERM_FISTS    = false

---------------------------------------------------------------------------
-- ATRAVIESA LAS PUERTAS
---------------------------------------------------------------------------
-- Un fantasma de Phasmophobia atraviesa las puertas; el Alternate de Mandela
-- Catalogue ( docs/ALTERNATE.md ) NO. Por eso esto es un FLAG DE CLASE y no una
-- convar: cada NPC del addon decide, y la convar
-- phantasmagoria_ghost_phasedoors solo existe para pisarlo en las dos
-- direcciones durante una corrida.
--
-- Heredable por el arbol de bases: los 30 tipos de Diseno 12.2 van a colgar de
-- esta clase y lo reciben en true sin escribir nada; el Alternate, cuando
-- exista, pone false y con eso alcanza.
--
-- ATRAVESAR Y ABRIR SON DOS COSAS Y LAS DOS SIGUEN PRENDIDAS, que es lo que
-- pidio el autor en los dos mensajes: atravesar es lo que garantiza que PASE
-- ( antes se trababa 3,6 s contra un func_door_rotating ), y abrir es lo que
-- deja la HUELLA, que fue el motivo por el que se eligio abrir en vez de
-- atravesar en el bloque anterior. Se apagan por separado
-- ( phantasmagoria_ghost_opendoors 0 deja el atravesado sin la apertura ).
ENT.phantom_PhasesDoors = true

-- Abrir puertas cerradas, tambien por NPC. Pedido del autor en la ronda 2, y
-- sale de una observacion suya: "intenta casi siempre abrir puertas". El flag
-- es lo que deja que eso sea una caracteristica de ALGUNOS tipos y no del motor
-- -- en Phasmophobia abrir una puerta es un EVENTO, no una constante.
--
-- OJO CON LO QUE ESTO NO ES: el flag prende y apaga la capacidad, no su
-- frecuencia. Que "casi siempre" intente abrir sigue siendo cierto con el flag
-- en true, y si lo que molesta es la frecuencia hace falta otra cosa
-- ( un intervalo o una probabilidad por tipo, que es Diseno 5 ). Se deja dicho
-- para que no se lea como resuelto.
ENT.phantom_OpensDoors = true

-- Y el silencio, que arranca APAGADO a proposito. El ruido de las puertas es lo
-- que le dejo al autor ver el comportamiento del fantasma adentro de la casa,
-- asi que sacarlo por default seria sacarle un instrumento. El flag existe para
-- los tipos que tienen que ser sigilosos -- el Myling de Diseno 5 camina en
-- silencio cazando, y es exactamente esto.
ENT.phantom_SilentDoors = false

-- Caminar cazando, tambien por NPC. Sale de una observacion del autor en la
-- ronda 3 -- "suele caminar al hacer hunting y correr cuando no me ve; podria
-- correr igualmente directo a mi" -- y la causa esta medida en la base:
-- canDoRun se niega si el bot no esta enojado, TE VE y tiene la vida entera.
-- El detalle en server_speed.lua.
--
-- Arranca en false: cazando CORRE. El flag existe para los tipos que acechan
-- caminando ( el Deogen de Diseno 5, que se arrastra cuando esta cerca ).
ENT.phantom_WalksWhenHunting = false

-- Y las PISADAS, pedido del autor del 2026-08-07. Mismo molde que el silencio
-- de las puertas: arranca en false ( suenan ) y el flag existe para el tipo que
-- camina callado, que es el Myling de Diseno 5.
--
-- OJO CON LEER ESTE false COMO "el fantasma hace ruido siempre": el flag es UNA
-- de las dos causas de silencio. La otra es la regla de estado
-- ( phantasmagoria_ghost_stepsonlyhunt, default 1 ), que calla a CUALQUIER
-- fantasma fuera del hunt porque en Phasmophobia el fantasma suena al caminar
-- en hunt y en eventos, no siempre. Las dos viven en server_steps.lua y el
-- reporte dice cual gano.
--
-- Y la restriccion que lo separa del silencio de puertas, que es la inversa:
-- aca la pisada TIENE QUE SEGUIR OCURRIENDO como evento, porque el Paramic
-- ( Diseno 7 ) la va a tener que oir. Silenciar es "que no se oiga", no "que no
-- pase". El detalle esta en el encabezado de server_steps.lua.
ENT.phantom_SilentSteps = false

---------------------------------------------------------------------------
-- EL INTERRUPTOR FANTASMA / CAZADOR
---------------------------------------------------------------------------
-- Fuera del hunt el fantasma NO ataca; dentro, si. Arranca en fantasma.
--
-- OJO: esto cambia la fila 4 del check anterior. Ese check pedia "camina hacia
-- el jugador" y por eso el bot quedaba hostil A PROPOSITO. Con este campo en
-- false ya NO persigue al spawnear: la fila 4 vale solo con hunt = 1.
ENT.phantom_Hunting = false

-- El interruptor NO es OnFirstRelationWithPlayer, y esa es la correccion mas
-- cara de este bloque. Diseno 3.1 dice "al entrar en hunt se re-evaluan
-- relaciones y la base hace el resto sola". Leyendo el codigo, nada dispara esa
-- re-evaluacion, y peor: la relacion NO SIRVE como interruptor. El recorrido:
--
--   SetupRelationships corre UNA sola vez, desde Initialize ( shared.lua:3079 ).
--   Por cada entidad llama SetupEntityRelationship -> GetDesiredEnemyRelationship
--   -> OnFirstRelationWithPlayer, y GUARDA el resultado en m_EntityRelationships
--   con Term_SetEntityRelationship ( enemyoverrides.lua:883, y el cuerpo del
--   guardado en terminator_nextbot_base/enemy.lua:44-47 ). Es un CACHE. El
--   nombre lo venia diciendo: OnFIRSTRelationWithPlayer.
--
-- Y hay un segundo motivo, mas fuerte, que sale de leer MakeFeud
-- ( enemyoverrides.lua:1046-1048 ): cuando al bot le pegan, PostTookDamage
-- ( damageandhealth.lua:482 ) llama MakeFeud, que para un jugador reescribe la
-- relacion a D_HT con prioridad 1000, sin preguntarle nada a nadie. O sea que un
-- interruptor hecho de relaciones se REABRE de un balazo, y no se vuelve a
-- cerrar nunca porque nada re-evalua el cache.
--
-- El interruptor de verdad es ShouldBeEnemy, que es donde la base LEE ese cache
-- ( enemyoverrides.lua:493 ) y que se consulta EN VIVO todo el tiempo:
--   FindEnemies / processFindingEnt  enemyoverrides.lua:596   ( ruta 1 de 18.7 )
--   ForgetOldEnemies                 enemyoverrides.lua:676   ( limpia memoria )
--   FindPriorityEnemy                enemyoverrides.lua:719   ( elige enemigo )
--   el fallback "sin enemigos"       shared.lua:3203          ( ruta 3 de 18.7 )
--   revalidar el enemigo anterior    shared.lua:3282
--   HaveEnemy                        terminator_nextbot_base/enemy.lua:136
--
-- Un false ahi no congela nada: el cerebro sigue corriendo entero y las 31
-- tareas siguen ahi. Es literalmente lo que pide Diseno 3.1 en su ultima linea
-- -- "el bot nunca deja de pensar, solo deja de tener a quien odiar" -- solo que
-- en la funcion de al lado. Y NO es DisableBehaviour: saltear no es apagar.
function ENT:ShouldBeEnemy( ent, fov, myTbl, entsTbl )
    myTbl = myTbl or self:GetTable()

    -- Fuera del hunt no hay enemigos. Ni jugadores ni NPCs: Diseno 3.1 dice
    -- "deja de tener a quien odiar", no "a quien odiar menos".
    if not myTbl.phantom_Hunting then return false end

    return myTbl.BaseClass.ShouldBeEnemy( self, ent, fov, myTbl, entsTbl )

end

-- CONSECUENCIA MEDIDA EN EL CODIGO, no cosmetica: shared.lua:1387 usa
-- ShouldBeEnemy sobre lo que le bloquea el paso -- "not ShouldBeEnemy( blocker )"
-- -> openDoorTime = CurTime(), o sea ABRIR en vez de ROMPER. Con el interruptor
-- en fantasma esa rama se toma siempre. Es la que queremos, pero hay que
-- saberlo antes de leerlo como bug.

-- Este es el override que Diseno 3.1 nombraba, y aca queda como INSTRUMENTO y
-- no como mecanismo: cuenta cuantas veces la base evalua la relacion y con que
-- flag. Si 3.1 tuviera razon, prender el hunt la haria subir. El control de que
-- el contador no este simplemente roto es phantasmagoria_hunt_reeval, que la
-- dispara a mano: si ese comando lo mueve y prender el hunt no, el contador
-- funciona y lo que no ocurre es la re-evaluacion.
--
-- Trampa 1 ( Referencia 4.2b ): la implementacion default NO esta vacia --
-- implementa ExtraSpawnHealthPerPlayer ( damageandhealth.lua:872 ) -- asi que
-- hay que ENCADENAR al BaseClass o se mata en silencio. Hoy no duele porque no
-- declaramos el campo, y por eso mismo el defecto seria invisible.
--
-- Trampa 2 ( Referencia 4.2c ): la llamada pasa CUATRO argumentos
-- ( enemyoverrides.lua:947 ) y la declaracion de la base nombra uno. Se nombran
-- los cuatro aca para que se lea que existen.
--
-- Devuelve lo que devuelva el BaseClass, que es nil: enemyoverrides.lua:948 hace
-- "if newDisp then disp = newDisp end", asi que un nil deja pasar el D_HT de
-- :942. La relacion del fantasma con el jugador queda en D_HT SIEMPRE, a
-- proposito: un D_NU aca trabaria el interruptor cerrado para siempre, porque
-- la base exige D_HT en :493 y nada re-evalua el cache.
function ENT:OnFirstRelationWithPlayer( ply, disp, priority, theirDisp )
    self.phantom_relCalls       = ( self.phantom_relCalls or 0 ) + 1
    self.phantom_relLastTime    = CurTime()
    self.phantom_relLastHunting = self.phantom_Hunting == true

    return self.BaseClass.OnFirstRelationWithPlayer( self, ply, disp, priority, theirDisp )

end

-- La puerta unica para prender y apagar. Cuando exista la cordura ( Diseno 19 )
-- va a llamar a ESTO y no a tocar el campo, asi que el networkeo no se puede
-- olvidar en el camino.
--
-- SetNWBool y NO SetupDataTables: trampa 3 ( Referencia 4.3 ) dice que la base
-- networkea con slots hardcodeados y el Bool 0 ya es Crouching. Los NW vars van
-- por nombre y son otro sistema; ademas la base no usa ninguno ( grep de
-- SetNWBool/SetNW2Bool sobre sus 71 archivos: cero ).
function ENT:phantom_SetHunting( hunting )
    hunting = hunting == true

    self.phantom_Hunting = hunting
    self:SetNWBool( "phantasmagoria_hunting", hunting )

    return hunting

end

function ENT:phantom_IsHunting()
    return self.phantom_Hunting == true

end

---------------------------------------------------------------------------
-- Que mire hacia donde camina cuando NO esta cazando
---------------------------------------------------------------------------
-- DEFECTO MEDIDO EN JUEGO (corrida 7): en calma el yaw se congela y no se mueve
-- mas. Once lecturas con "mira yaw 141.7" mientras el bot cruzaba el mapa, y una
-- de ellas con "mirada vs marcha 179.9 grados", o sea caminando EXACTAMENTE de
-- espaldas. En hunt, en cambio, "mirada vs jugador" da 0.0-1.5 grados: te apunta
-- clavado.
--
-- LA CAUSA NO ES LA QUE YO HABIA ESCRITO, y el numero que lo corrige es uno:
-- terminator_Extras.term_DefaultSpeedToAimAtProps = 30^2 ( motionoverrides.lua:1735 ),
-- comparado contra Length2DSqr, o sea un umbral de 30 u/s. Yo habia anotado el
-- gate de TERM_FISTS ( :2838 ) como el motivo, y es solo la mitad: aun CON puños
-- ese camino pide ademas velocidad POR DEBAJO de 30 u/s, y este bot camina a 130
-- y corre a 550. Devolverle los puños NO lo habria arreglado -- habria sido una
-- ronda entera gastada en el arreglo obvio.
--
-- El motivo de verdad es mas simple: de los cuatro sitios que llaman
-- SetDesiredEyeAngles, el unico que puede correr caminando es el del ENEMIGO
-- ( enemyoverrides.lua:1874 ). Un terminator normal siempre tiene enemigo, asi
-- que siempre mira; nuestro fantasma en calma no tiene ninguno A PROPOSITO, y
-- ahi no queda nadie que le mueva la cara. Los otros dos son caida y salto
-- ( motionoverrides.lua:3306 y :3311 ).
--
-- No es cosa de HIM ni de la base: HIM tambien pone TERM_FISTS = false
-- ( him/.../terminator_nextbot_homeless/server.lua:22 ), igual que
-- terminator_nextbot_fakeply:35 y csoldier:26. Lo que HIM y el terminator tienen
-- y nosotros no es un enemigo permanente.
--
-- El arreglo es la mitad que falta y nada mas: cuando no hay a quien mirar, mirar
-- hacia donde se camina. Es lo mismo que hace la base al saltar
-- ( motionoverrides.lua:3311, SetDesiredEyeAngles( self, GetVelocity():Angle() ) ),
-- aplicado al caso que ella no cubre.
local cvFaceWalk = CreateConVar( "phantasmagoria_ghost_facewalk", "1", FCVAR_ARCHIVE,
    "El fantasma mira hacia donde camina cuando no esta cazando. En 0 se desliza sin girar, que es el defecto original: sirve para el A/B.", 0, 1 )

-- Debajo de esto no hay direccion de marcha que valga la pena mirar. Es el mismo
-- numero que la base usa como frontera de "casi quieto", pero por el otro lado:
-- ella apunta al goal por DEBAJO de 30 u/s, nosotros a la marcha por ARRIBA.
local FACEWALK_MIN_SPEED = 30

function ENT:BehaveUpdate( interval )
    local myTbl = self:GetTable()

    -- El BaseClass PRIMERO: es el que corre el cerebro entero. Lo nuestro es un
    -- retoque de la cara despues, y solo en el hueco que la base deja vacio.
    myTbl.BaseClass.BehaveUpdate( self, interval )

    if not cvFaceWalk:GetBool() then return end

    -- Cazando manda la base: apunta al enemigo y lo hace mejor que esto.
    if myTbl.phantom_Hunting then return end
    if IsValid( myTbl.GetEnemy( self ) ) then return end

    local loco = myTbl.loco
    if not loco then return end

    -- Saltando y en el aire tambien manda la base ( :3306 y :3311 ), que ademas
    -- mira hacia donde va a aterrizar. Pisarla seria romper algo que funciona.
    if myTbl.m_JumpingToPos then return end
    if not loco:IsOnGround() then return end

    local vel = loco:GetVelocity()
    if vel:Length2D() < FACEWALK_MIN_SPEED then return end

    local ang = vel:Angle()

    -- Plano a proposito. La base tambien aplana el pitch cuando no hay un cambio
    -- de altura dramatico ( enemyoverrides.lua:1866-1869 ), y un fantasma mirando
    -- al piso mientras baja una rampa se ve peor que uno mirando al frente.
    ang.p = 0
    ang.r = 0

    self:SetDesiredEyeAngles( ang )

end

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------
-- AdditionalInitialize corre DESPUES de que la base resolvio modelo y FOV
-- ( shared.lua:3011, con el modelo en :2987 y el FOV en :3005 ), por eso es
-- el lugar correcto para pisar defaults. La implementacion de la base esta
-- vacia ( shared.lua:2909-2910 ): no hay que encadenar al BaseClass.
function ENT:AdditionalInitialize()
    -- Trampa 2 (Referencia 4.3): Term_FOV solo NO alcanza. El comentario de
    -- shared.lua:152 dice que poner un numero ignora la convar
    -- termhunter_fovoverride, y miente: el callback de la convar
    -- ( shared.lua:57-62 ) pisa Term_FOV justamente en las entidades que ya
    -- tienen numero, si AutoUpdateFOV es true - y el default es true
    -- ( shared.lua:154 ). Hay que poner LAS DOS.
    self.Term_FOV      = 180
    self.AutoUpdateFOV = false -- HIM pone nil aca ( server.lua:852 ); las dos son falsy

    -- La RunSpeed DECLARADA por la base, congelada en el unico momento en que
    -- se sabe limpia. Es el divisor de la conversion de velocidad
    -- ( server_speed.lua ) y NO se lee en vivo a proposito: overcharging.lua:22
    -- hace "self.RunSpeed = math.max( self.RunSpeed * 1.40, 550 )", y un divisor
    -- en vivo cancelaria el overcharge en silencio -- el fantasma volveria a su
    -- velocidad normal justo cuando el mecanismo dice que tiene que acelerar.
    self.phantom_BaseRunSpeed = self.RunSpeed

    -- Sincroniza el NW var con el campo. Va ANTES del return temprano de abajo:
    -- si queda del otro lado, el marcador del cliente miente en todo mapa que
    -- tenga navmesh, que son casi todos.
    self:phantom_SetHunting( self.phantom_Hunting )

    ghostPrint( "spawn #", self:EntIndex(),
        "  modelo ", tostring( self:GetModel() ),
        "  skin ", self:GetSkin(),
        "  pos ", tostring( self:GetPos() ),
        "  hunt ", self.phantom_Hunting and "SI" or "NO",
        "\n" )

    -- El navmesh se mide DOS VECES a proposito, y esta es la correccion mas
    -- cara de la primera corrida (2026-08-05). La version anterior de este
    -- aviso decia "SIN NAVMESH: el bot no va a caminar" -- y el bot caminaba.
    -- Medicion correcta, prediccion falsa: con 0 areas la base llama a
    -- TryGeneratingAreas() ( shared.lua:3072-3075 ) y el parcheador
    -- ( terminator_areapatcher.lua, convar terminator_areapatching_enable,
    -- default 1 ) sigue creando areas donde caminan bots y jugadores. O sea que
    -- 0 al spawnear NO es 0 diez segundos despues.
    --
    -- Un instrumento no predice: mide, espera, y vuelve a medir.
    local areasAlSpawnear = navmesh.GetNavAreaCount()
    if areasAlSpawnear > 0 then return end

    ghostPrint( "0 navareas al spawnear. La base va a intentar parchear el mapa; " ..
        "se vuelve a medir en ", NAVCHECK_DELAY, " s.\n" )

    timer.Simple( NAVCHECK_DELAY, function()
        if not IsValid( self ) then return end

        local ahora = navmesh.GetNavAreaCount()

        if ahora > 0 then
            -- "van" y no "construyo": el numero SIGUE CRECIENDO. Medido en la
            -- corrida 3 (gm_graysonhouse): 42 aca y 137 un rato despues, con el
            -- bot caminando. El parcheador crea areas donde pisan bots y
            -- jugadores, asi que esto es una foto y no un total.
            ghostPrint( "van ", ahora, " navareas parcheadas a los ", NAVCHECK_DELAY,
                " s, y el parcheador sigue trabajando mientras alguien camine. El bot se mueve " ..
                "sobre un mapa PARCHEADO, no sobre un navmesh de verdad: esperar caminos raros.\n" )

        else
            ghostPrint( "SIGUEN 0 navareas: aca si el bot no va a caminar. " ..
                "nav_generate, o un mapa con navmesh.\n" )

        end
    end )
end

---------------------------------------------------------------------------
-- Instrumento: donde esta cada fantasma
---------------------------------------------------------------------------
-- Complementa al marcador del cliente y falla distinto: el marcador solo
-- dibuja fantasmas dentro del PVS del jugador, este los ve todos. Si uno
-- aparece aca y no en pantalla, el bot existe y el que fallo es el dibujo.
-- HUD_PRINTCONSOLE viaja por un user message TextMsg con techo de 255 BYTES, y
-- lo que pasa al pasarse NO es que se trunque: el servidor se NIEGA a mandarlo
-- ( "Refusing to send user message TextMsg of 256 bytes to client, user message
-- size limit is 255 bytes" ) y la linea entera se pierde. Medido en la primera
-- corrida (2026-08-05): la linea de TAREAS -- la mas informativa de las seis --
-- fue justo la unica que se paso, y el unico rastro fue ese aviso del engine,
-- que no dice cual se perdio. Un instrumento que pierde su mejor dato en
-- silencio es peor que no tenerlo.
local MAX_LINEA = 180 -- con margen: al trozo se le suma la sangria

-- Fabrica el "say" de un comando. Extraido a proposito: era un local adentro de
-- phantasmagoria_ghost_where, y todo comando nuevo que imprimiera por su cuenta
-- volvia a caer en el mismo pozo de 255 bytes sin avisar.
local function makeSay( ply )
    return function( line )
        line = tostring( line )

        if not IsValid( ply ) then -- consola del servidor, sin limite
            print( line )
            return

        end

        if line == "" then
            ply:PrintMessage( HUD_PRINTCONSOLE, "" )
            return

        end

        local primero = true

        while #line > 0 do
            local trozo = string.sub( line, 1, MAX_LINEA )
            line = string.sub( line, MAX_LINEA + 1 )
            ply:PrintMessage( HUD_PRINTCONSOLE, primero and trozo or "            " .. trozo )
            primero = false

        end
    end
end

-- Compartido a proposito: todo comando nuevo que imprima por su cuenta vuelve a
-- caer en el pozo de 255 bytes, y el aviso del engine no dice cual linea perdio.
PHANTASMAGORIA.MakeSay = makeSay

---------------------------------------------------------------------------
-- Registrar un comando, con la guarda que costo una ronda entera
---------------------------------------------------------------------------
-- UNA CONVAR Y UN CONCOMMAND NO PUEDEN LLAMARSE IGUAL, Y EL QUE PIERDE ES EL
-- COMANDO, EN SILENCIO. concommand.Add lo registra igual -- no devuelve error,
-- no avisa -- pero la consola resuelve el nombre contra las convars primero,
-- asi que tipearlo imprime la ficha de la convar y el comando no corre nunca.
--
-- Medido en la ronda 2 (2026-08-06) y costo DOS filas de la planilla: yo habia
-- creado la convar phantasmagoria_ghost_doors y el comando
-- phantasmagoria_ghost_doors. El instrumento de puertas fue INALCANZABLE toda
-- la ronda -- el autor lo reporto como "donde veo el dato de la evidencia (?)"
-- y la respuesta era que no habia forma de verlo. Y lo peor no fue eso: la
-- planilla mandaba correr "phantasmagoria_ghost_doors reset", que en vez de
-- resetear contadores le asignaba "reset" a la convar, o sea 0, o sea APAGABA
-- la apertura de puertas justo antes de medirla.
--
-- Por eso el registro pasa por aca y no por concommand.Add directo: la
-- colision se vuelve un error ruidoso al cargar en vez de un comando mudo.
function PHANTASMAGORIA.AddCommand( name, fn, help )
    if ConVarExists( name ) then
        ErrorNoHalt( "[Phantasmagoria] COLISION DE NOMBRE: '" .. name .. "' ya existe como CONVAR, " ..
            "asi que el comando homonimo queda inalcanzable ( la consola resuelve convars primero ). " ..
            "Renombrar uno de los dos.\n" )
        return false

    end

    concommand.Add( name, fn, nil, help )
    return true

end

---------------------------------------------------------------------------
-- Instrumento: hacia donde mira
---------------------------------------------------------------------------
-- Pedido del autor en la corrida 5, y es el que faltaba: "que el comando muestre
-- a donde esta mirando el phantom, porque yo lo veo moverse mirando a un solo
-- lado todo el tiempo". Sin esto, "mueve la vista" era una impresion y no un
-- numero, y ya me costo explicar la observacion antes de fijarla.
--
-- LA VERSION ANTERIOR DE ESTE BLOQUE TUVO TRES DEFECTOS, LOS TRES MIOS, Y LOS
-- TRES ESTAN CORREGIDOS ACA. Se dejan escritos porque los tres fallaban HACIA UN
-- VALOR PLAUSIBLE y ninguno tiraba error:
--
-- (1) marcha decia "quieto ( 0 u/s )" SIEMPRE, incluso con el bot cruzando el
--     mapa. La causa fue una guarda MIA: IsValid( ghost.loco ). CLuaLocomotion
--     NO tiene metodo IsValid, y el IsValid() de GMod devuelve false para todo
--     objeto que no lo tenga -- asi que la guarda caia siempre al vector cero.
--     La base NUNCA envuelve self.loco en IsValid: la llama directo
--     ( terminator_nextbot_base/motion.lua:54 ). Una guarda defensiva que falla
--     hacia un valor creible es peor que no tenerla: no se ve.
--
-- (2) Los yaws se imprimian SIN NORMALIZAR, asi que -449.7 y 270.4 -- que son
--     EL MISMO ANGULO -- se leian como direcciones opuestas, con el delta
--     diciendo 0 al lado. El delta estaba bien; los numeros de al lado lo
--     desmentian. Ahora todo pasa por math.NormalizeAngle.
--
-- (3) "quiere" se declaro como el discriminante y NO discrimina nada:
--     15 de 15 lecturas dieron delta 0. Y el motivo es estructural, no de
--     tuning: GetEyeAngles ( terminator_nextbot_base/shared.lua:81-93 ) arma el
--     angulo con self:GetAngles() y solo pisa el PITCH. O sea que el yaw de
--     "donde mira" ES el yaw del cuerpo, y no existe un yaw de cabeza aparte
--     que se le pueda comparar. La pareja mira/quiere no podia separar cabeza
--     de cuerpo ni en principio. Se conserva como CONTROL -- que el delta sea 0
--     es el dato -- y el discriminante de verdad pasa a ser otro: contra que
--     esta apuntado.
--
-- Las lineas, y que separa cada una:
--   mira       el yaw del CUERPO ( = donde mira ) y el pitch del aim
--   quiere     GetDesiredEyeAngles: control, el aim converge en el mismo frame
--   marcha     hacia donde se mueve y a que velocidad, por DOS fuentes
--   al jugador el rumbo al jugador mas cercano, y el angulo contra la mirada
--              -- ESTE es el que separa "gira siguiendote" de "gira solo"
local function lookLines( ghost, say )
    local eye  = ghost:GetEyeAngles()
    local want = ghost:GetDesiredEyeAngles()

    local eyeYaw  = math.NormalizeAngle( eye.y )
    local wantYaw = math.NormalizeAngle( want.y )

    say( "    mira    yaw " .. math.Round( eyeYaw, 1 ) ..
        "  pitch " .. math.Round( math.NormalizeAngle( eye.p ), 1 ) )

    -- El delta es el RETRASO del aim contra lo que se le pidio mirar, y lo que
    -- significa depende de QUIEN se lo pidio. Ojo con leerlo mal en calma:
    -- desde que existe el facewalk, en calma el que escribe DesiredEyeAngles
    -- somos nosotros con la direccion de marcha, asi que este delta pasa a ser
    -- identico a "mirada vs marcha" POR CONSTRUCCION -- medido en la corrida 8:
    -- 2.7/2.7, 6.2/6.2, 0.6/0.6, 0.1/0.1. Una columna que te devuelve lo que tu
    -- propio codigo acaba de escribir NO es una medicion independiente.
    -- Sigue valiendo como medicion en hunt ( ahi lo escribe la base ) y con
    -- phantasmagoria_ghost_facewalk 0.
    local quienPide
    if ghost.phantom_Hunting then
        quienPide = "lo pide la base ( enemigo )"

    elseif cvFaceWalk:GetBool() then
        quienPide = "lo pedimos NOSOTROS: = mirada vs marcha, no es dato aparte"

    else
        quienPide = "no lo pide nadie: 0 es lo esperado"

    end

    say( "    quiere  yaw " .. math.Round( wantYaw, 1 ) ..
        "  pitch " .. math.Round( math.NormalizeAngle( want.p ), 1 ) ..
        "   delta " .. math.Round( math.abs( math.AngleDifference( wantYaw, eyeYaw ) ), 1 ) ..
        " grados ( " .. quienPide .. " )" )

    -- DOS fuentes de velocidad y las dos se imprimen, para que el instrumento
    -- diga con que esta midiendo. La de la base es GetCurrentSpeed
    -- ( terminator_nextbot_base/motion.lua:51, Length2D del loco, cacheada
    -- 0,01 s ); Entity:GetVelocity() es la de la entidad y en un NextBot puede
    -- no ser la misma cosa. Si alguna vuelve a dar 0 con el bot caminando, se
    -- ve CUAL, que es lo que la version anterior no dejaba ver.
    local vel     = ghost.loco and ghost.loco:GetVelocity() or vector_origin
    local spdLoco = ghost:GetCurrentSpeed()
    local spdEnt  = ghost:GetVelocity():Length()

    if spdLoco < 1 and spdEnt < 1 then
        say( "    marcha  quieto   ( loco " .. math.Round( spdLoco, 1 ) ..
            " u/s · ent " .. math.Round( spdEnt, 1 ) .. " u/s )" )

    else
        local marchaYaw = math.NormalizeAngle( vel:Angle().y )

        say( "    marcha  yaw " .. math.Round( marchaYaw, 1 ) ..
            "   loco " .. math.Round( spdLoco ) .. " u/s · ent " .. math.Round( spdEnt ) .. " u/s" ..
            "   mirada vs marcha " .. math.Round( math.abs( math.AngleDifference( marchaYaw, eyeYaw ) ), 1 ) .. " grados" )

    end

    -- El discriminante que faltaba. En hunt el bot deberia apuntarte; en calma,
    -- no. Sin esta linea, "el yaw cambio" no distingue seguirte de girar solo.
    local nearest, nearestDist
    for _, target in ipairs( player.GetAll() ) do
        local d = ghost:GetRangeTo( target )
        if not nearest or d < nearestDist then nearest, nearestDist = target, d end

    end

    if not IsValid( nearest ) then
        say( "    al ply  ( no hay jugadores )" )
        return

    end

    local rumbo = math.NormalizeAngle( ( nearest:GetPos() - ghost:GetPos() ):Angle().y )

    say( "    al ply  yaw " .. math.Round( rumbo, 1 ) .. "  a " .. math.Round( nearestDist ) .. " u" ..
        "   mirada vs jugador " .. math.Round( math.abs( math.AngleDifference( rumbo, eyeYaw ) ), 1 ) .. " grados" )

end

-- Itera los fantasmas vivos. Misma busqueda que usaba ghost_where: por el campo
-- IsPhantasmagoriaGhost y NO por clase, porque los 30 tipos de Diseno 12.2 van a
-- llamarse phantasmagoria_<tipo> y una busqueda por clase exacta va a envejecer
-- mal.
local function eachGhost( fn )
    local found = 0

    for _, ghost in ipairs( ents.GetAll() ) do
        if not ghost.IsPhantasmagoriaGhost then continue end
        if not IsValid( ghost ) then continue end

        found = found + 1
        fn( ghost )

    end

    return found

end

PHANTASMAGORIA.EachGhost = eachGhost

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_where", function( ply )
    local say = makeSay( ply )

    local found = eachGhost( function( ghost )
        local enemy = ghost:GetEnemy() -- terminator_nextbot_base/enemy.lua:20
        local tasks = {}

        -- m_TaskList es la tabla que lee HasTask ( taskoverride.lua:148 ),
        -- indexada por nombre de tarea.
        if istable( ghost.m_TaskList ) then
            for name, _ in pairs( ghost.m_TaskList ) do
                table.insert( tasks, name )

            end

            table.sort( tasks )

        end

        say( "#" .. ghost:EntIndex() .. "  " .. ghost:GetClass() )
        say( "    pos     " .. tostring( ghost:GetPos() ) )
        say( "    vida    " .. ghost:Health() .. " / " .. ghost:GetMaxHealth() )
        say( "    modelo  " .. tostring( ghost:GetModel() ) )
        say( "    hunt    " .. ( ghost.phantom_Hunting and "SI ( cazador )" or "NO ( fantasma )" ) )
        say( "    enemigo " .. ( IsValid( enemy ) and tostring( enemy ) or "ninguno" ) )

        lookLines( ghost, say )

        -- UNA linea de cada bloque nuevo, no su reporte entero: para eso estan
        -- phantasmagoria_ghost_speed y phantasmagoria_ghost_doors. Van aca
        -- porque durante una corrida el comando que se tipea todo el tiempo es
        -- este, y las dos cosas que cambiaron son justamente las que no se ven
        -- desde adentro del juego.
        local loco = ghost.loco

        say( "    veloc   deseada " .. math.Round( loco and loco:GetDesiredSpeed() or -1 ) .. " u/s" ..
            "   real " .. math.Round( ghost:GetCurrentSpeed() ) .. " u/s" ..
            ( ghost.phantom_speedDbg and ( "   objetivo " .. math.Round( ghost.phantom_speedDbg.target ) .. " u/s" ) or "   ( sin convertir todavia )" ) )

        local door = ghost.phantom_doorLast

        say( "    puerta  " .. ( IsValid( door ) and door:GetClass() or "ninguna delante" ) ..
            "   trabado " .. string.format( "%.1f", ghost.phantom_doorBlocked or 0 ) .. " s" ..
            "   peor " .. string.format( "%.1f", ghost.phantom_doorWorst or 0 ) .. " s" ..
            "   " .. ( ghost.phantom_Phasing and "ATRAVESANDO" or "solido" ) )

        -- una por linea: son el dato que mas dice y el que mas largo se pone
        if #tasks <= 0 then
            say( "    tareas  ninguna" )

        else
            say( "    tareas  " .. #tasks )

            for _, name in ipairs( tasks ) do
                say( "        - " .. name )

            end
        end
    end )

    if found <= 0 then
        say( "[Phantasmagoria] no hay ningun fantasma vivo." )

    end

    say( "[Phantasmagoria] " .. found .. " fantasma(s). Navareas en el mapa: " .. navmesh.GetNavAreaCount() .. "." )

end, "Imprime donde esta cada fantasma de Phantasmagoria, y si el mapa tiene navmesh." )

---------------------------------------------------------------------------
-- Instrumento: a quien odia, y por que
---------------------------------------------------------------------------
-- Separa las DOS cosas que Diseno 3.1 confundia en una:
--   rel            el CACHE  ( m_EntityRelationships, escrito una sola vez )
--   ShouldBeEnemy  la PUERTA ( leida en vivo, y donde vive el interruptor )
-- Sin las dos al lado, "el bot no me ataca" no distingue entre "no me odia" y
-- "me odia y no puede".
--
-- Los nombres de las disposiciones se leen de los globales y no se hardcodean:
-- son enums del engine, o sea de un tercero.
local DISP_NAMES = {}

for _, name in ipairs( { "D_ER", "D_HT", "D_FR", "D_LI", "D_NU" } ) do
    local value = _G[ name ]
    if value then DISP_NAMES[ value ] = name end

end

local function dispName( d )
    return DISP_NAMES[ d ] or ( "??? (" .. tostring( d ) .. ")" )

end

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_rel", function( ply )
    local say = makeSay( ply )

    local found = eachGhost( function( ghost )
        local enemy = ghost:GetEnemy()

        say( "#" .. ghost:EntIndex() .. "  " .. ghost:GetClass() )
        say( "    hunt      " .. ( ghost.phantom_Hunting and "SI ( cazador )" or "NO ( fantasma )" ) ..
            "   NW " .. ( ghost:GetNWBool( "phantasmagoria_hunting", false ) and "SI" or "NO" ) )
        say( "    enemigo   " .. ( IsValid( enemy ) and tostring( enemy ) or "ninguno" ) )

        -- La vida NO es decoracion aca: el check del balazo ( ronda 1, fila 07 )
        -- tiene como precondicion que al bot le hayan pegado, y este comando no
        -- la mostraba. "Le tire" quedaba como afirmacion del que corre la
        -- planilla en vez de dato del instrumento. Con la vida a la vista, la
        -- precondicion se ve en la misma salida que el veredicto.
        say( "    vida      " .. ghost:Health() .. " / " .. ghost:GetMaxHealth() ..
            ( ghost:Health() < ghost:GetMaxHealth() and "   ( recibio dano )" or "   ( INTACTO: nadie le pego )" ) )

        -- El contador de la re-evaluacion. Si Diseno 3.1 tuviera razon, prender
        -- el hunt lo haria subir. El control es phantasmagoria_hunt_reeval.
        local calls = ghost.phantom_relCalls or 0
        local lastT = ghost.phantom_relLastTime

        say( "    OnFirstRelationWithPlayer  " .. calls .. " llamada(s)" ..
            ( lastT and ( ", la ultima a t=" .. math.Round( lastT, 1 ) ..
                " con hunt=" .. ( ghost.phantom_relLastHunting and "SI" or "NO" ) ) or "" ) )

        local players = player.GetAll()

        if #players <= 0 then
            say( "    ( no hay jugadores )" )
            return

        end

        for _, target in ipairs( players ) do
            -- GetRelationship es el wrapper publico de TERM_GetRelationship
            -- ( enemyoverrides.lua:813-816 ). Lee el cache, no lo escribe.
            local disp, priority = ghost:GetRelationship( target )

            -- ShouldBeEnemy SI toca estado: adentro cachea shouldNotSeeEnemy
            -- ( enemyoverrides.lua:295-317 ). Se llama igual porque es LA puerta
            -- y no hay forma honesta de preguntarla sin preguntarla; el bot la
            -- corre solo cada ~0,5 s ( shared.lua:3164 ), asi que el instrumento
            -- no agrega una clase de perturbacion que no estuviera ya ahi.
            local should = ghost:ShouldBeEnemy( target, nil, ghost:GetTable(), target:GetTable() )

            say( "    ply " .. target:Nick() ..
                "   rel " .. dispName( disp ) .. " pri " .. tostring( priority ) ..
                "   ShouldBeEnemy " .. ( should and "SI" or "NO" ) ..
                "   dist " .. math.Round( ghost:GetRangeTo( target ) ) .. " u" )

        end
    end )

    if found <= 0 then
        say( "[Phantasmagoria] no hay ningun fantasma vivo." )

    end
end, "Imprime, por fantasma y por jugador, la relacion cacheada y el resultado en vivo de ShouldBeEnemy." )

---------------------------------------------------------------------------
-- ANDAMIO: el gatillo manual del hunt
---------------------------------------------------------------------------
-- ESTO NO ES DISENO, ES UN ANDAMIO, y se tira cuando exista la cordura.
--
-- El hunt de Phasmophobia lo dispara la cordura del jugador ( Diseno 4 y 19 ), y
-- la cordura no existe todavia. Sin gatillo, el interruptor no se puede ver en
-- juego: quedaria escrito y sin ejercer, que es exactamente la clase de cosa que
-- este proyecto arrastra en la advertencia final de ESTADO.md.
--
-- Cuando la cordura exista, el que llama a phantom_SetHunting es ella y este
-- comando se borra ( o queda de utileria de test, pero nunca de mecanica ).
local function adminOnly( ply )
    if not IsValid( ply ) then return true end -- consola del servidor
    if ply:IsAdmin() then return true end

    ply:PrintMessage( HUD_PRINTCONSOLE, "[Phantasmagoria] hace falta ser admin." )
    return false

end

PHANTASMAGORIA.AddCommand( "phantasmagoria_hunt", function( ply, _, args )
    if not adminOnly( ply ) then return end

    local say = makeSay( ply )
    local arg = args and args[ 1 ]

    if arg ~= "0" and arg ~= "1" then
        say( "[Phantasmagoria] uso: phantasmagoria_hunt 0|1   ( 0 = fantasma, 1 = cazador )" )

        local found = eachGhost( function( ghost )
            say( "    #" .. ghost:EntIndex() .. " hunt " .. ( ghost.phantom_Hunting and "SI" or "NO" ) )

        end )

        if found <= 0 then say( "    no hay ningun fantasma vivo." ) end
        return

    end

    local hunting = arg == "1"

    -- SOLO toca el flag. No re-dispara la relacion, no limpia memoria, no toca
    -- tareas: es el interruptor de Diseno 3.1 tal cual esta escrito, para que la
    -- corrida pueda medir que hace la base sola y que no.
    local found = eachGhost( function( ghost )
        ghost:phantom_SetHunting( hunting )

        say( "    #" .. ghost:EntIndex() .. "  hunt -> " .. ( hunting and "SI ( cazador )" or "NO ( fantasma )" ) ..
            "   llamadas a OnFirstRelationWithPlayer: " .. ( ghost.phantom_relCalls or 0 ) )

    end )

    if found <= 0 then
        say( "[Phantasmagoria] no hay ningun fantasma vivo." )
        return

    end

    say( "[Phantasmagoria] " .. found .. " fantasma(s) en " .. ( hunting and "HUNT" or "calma" ) ..
        ". Solo se movio el flag: ni la relacion ni la memoria se tocaron." )

end, "ANDAMIO. Prende ( 1 ) o apaga ( 0 ) el hunt de todos los fantasmas. Lo va a reemplazar la cordura." )

-- CONTROL del contador de arriba, no mecanismo.
--
-- Si phantasmagoria_hunt 1 no mueve las llamadas a OnFirstRelationWithPlayer,
-- hay dos explicaciones posibles: la base no re-evalua, o el contador esta roto.
-- Este comando dispara la re-evaluacion a mano. Si con el SI sube, el contador
-- funciona y lo que no ocurre es la re-evaluacion -- que es lo que hay que
-- medir, no suponer.
--
-- SetupEntityRelationship es ENT:SetupEntityRelationship( myTbl, ent, entsTbl )
-- ( enemyoverrides.lua:880 ). Su timer.Simple( 0 ) le pone la relacion reciproca
-- a ent, pero solo "if ent.AddEntityRelationship" ( :893 ), y un jugador no
-- tiene ese metodo: sobre jugadores es no-op.
--
-- OJO CON UN EFECTO QUE HOY NO SE VE: cada re-disparo vuelve a pasar por el
-- cuerpo default de OnFirstRelationWithPlayer, que lleva la cuenta
-- ExtraSpawnHealthPlayersDone y suma vida por jugador ( damageandhealth.lua:872-885 ).
-- Hoy sale por el "if not extraHpPerPly then return end" de la primera linea,
-- porque no declaramos ExtraSpawnHealthPerPlayer. El dia que se declare, este
-- comando INFLA la vida del fantasma cada vez que se lo llama -- que es
-- precisamente por que es un control de desarrollo y no una mecanica.
PHANTASMAGORIA.AddCommand( "phantasmagoria_hunt_reeval", function( ply )
    if not adminOnly( ply ) then return end

    local say = makeSay( ply )

    local found = eachGhost( function( ghost )
        local before = ghost.phantom_relCalls or 0
        local myTbl  = ghost:GetTable()

        for _, target in ipairs( player.GetAll() ) do
            ghost:SetupEntityRelationship( myTbl, target, target:GetTable() )

        end

        say( "    #" .. ghost:EntIndex() .. "  llamadas a OnFirstRelationWithPlayer: " ..
            before .. " -> " .. ( ghost.phantom_relCalls or 0 ) )

    end )

    if found <= 0 then
        say( "[Phantasmagoria] no hay ningun fantasma vivo." )

    end
end, "CONTROL. Re-dispara SetupEntityRelationship por jugador, para probar que el contador de re-evaluaciones esta vivo." )

---------------------------------------------------------------------------
-- ANDAMIO: mover los flags sin lua_run
---------------------------------------------------------------------------
-- La ronda 3 no pudo medir DOS filas por esto, y la causa no era el mecanismo:
-- el lua_run que le di al autor escribe el campo en la ENTIDAD, y todo fantasma
-- spawneado despues nace con el default de la clase. El override se perdia al
-- respawnear y nada lo decia -- se lee como "el flag no funciona".
--
-- La regla que deja: un ANDAMIO de prueba tiene que sobrevivir al ciclo de vida
-- de lo que prueba. Si para volver a medir hay que re-aplicarlo a mano, la
-- medicion depende de que nadie se olvide, y alguien se olvida.
--
-- Los nombres cortos son a proposito: se tipean en juego, con el fantasma
-- encima. "auto" borra el override y devuelve el mando al campo de la clase.
local FLAGS = {
    [ "abrir" ]     = { campo = "phantom_OpensDoors",       que = "abre puertas cerradas" },
    [ "atravesar" ] = { campo = "phantom_PhasesDoors",      que = "atraviesa las puertas" },
    [ "silencio" ]  = { campo = "phantom_SilentDoors",      que = "abre sin hacer ruido" },
    [ "caminar" ]   = { campo = "phantom_WalksWhenHunting", que = "camina en vez de correr cazando" },
    [ "pasos" ]     = { campo = "phantom_SilentSteps",      que = "camina sin hacer ruido ( el Myling )" },
}

local FLAG_ORDER = { "abrir", "atravesar", "silencio", "caminar", "pasos" }

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_flag", function( ply, _, args )
    if not adminOnly( ply ) then return end

    local say  = makeSay( ply )
    local name = args and args[ 1 ]
    local val  = args and args[ 2 ]
    local flag = name and FLAGS[ string.lower( name ) ]

    if not flag or ( val ~= "0" and val ~= "1" and val ~= "auto" ) then
        say( "[Phantasmagoria] uso: phantasmagoria_ghost_flag <nombre> <0|1|auto>" )
        say( "    auto = sin override, manda el campo de cada clase de fantasma." )

        for _, key in ipairs( FLAG_ORDER ) do
            local f   = FLAGS[ key ]
            local ov  = PHANTASMAGORIA.FlagOverrides[ f.campo ]

            say( "    " .. key .. string.rep( " ", 11 - #key ) ..
                ( ov == nil and "auto" or ( ov and "1   " or "0   " ) ) ..
                "  " .. f.campo .. "   ( " .. f.que .. " )" )

        end

        return

    end

    if val == "auto" then
        PHANTASMAGORIA.FlagOverrides[ flag.campo ] = nil

    else
        PHANTASMAGORIA.FlagOverrides[ flag.campo ] = val == "1"

    end

    -- El override NO toca los campos de las entidades: lo consulta el
    -- resolvedor, antes del campo. Asi se puede volver a "auto" sin haber
    -- pisado nada, que es lo que un lua_run no permite deshacer.
    local vivos = eachGhost( function() end )

    say( "[Phantasmagoria] " .. name .. " -> " .. val ..
        "   ( " .. flag.campo .. ", " .. flag.que .. " )" )
    say( "    alcanza a los " .. vivos .. " fantasma(s) vivos Y a los que spawneen despues." )
    say( "    verificar con phantasmagoria_ghost_doors: la linea dice el motivo que gano." )

end, "ANDAMIO. Pisa un flag de comportamiento en todos los fantasmas, vivos y futuros. Sin argumentos lista los cuatro." )

---------------------------------------------------------------------------
-- LA TAREA DE CLASE, y los dos bloques que cuelgan de ella
---------------------------------------------------------------------------
-- ENT.MyClassTask es el punto de extension que la base declara para agregar
-- comportamiento propio sin reescribir el cerebro ( taskoverride.lua:328-332,
-- "Simple way to add class-specific behaviour to a bot" ). DoClassTasks recorre
-- el arbol de bases, levanta el MyClassTask de cada clase y lo registra como
-- "<clase>_handler" con StartsOnInitialize forzado ( :344-358 ), o sea que la
-- nuestra se va a llamar terminator_nextbot_phantom_handler y va a APARECER POR
-- NOMBRE en la lista de tareas de phantasmagoria_ghost_where. "Se engancho" deja
-- de ser una suposicion y pasa a ser una linea de la salida.
--
-- Se declara VACIA aca y la llenan los dos archivos de abajo, cada uno con su
-- callback. Si alguno la declarara por su cuenta, el segundo pisaria al primero
-- y el sintoma seria un bloque entero que no corre, sin un solo error.
--
-- La lee scripted_ents.GetStored( clase ).t ( terminator_nextbot_base/shared.lua:169 ),
-- que es la tabla REGISTRADA -- y GMod registra la entidad recien despues de
-- correr shared.lua entero, includes adentro. Por eso alcanza con definirla
-- aca abajo y no hace falta adelantarla.
ENT.MyClassTask = {}

-- Diseno 1.1: la velocidad se deriva de la carrera real del jugador.
include( "server_speed.lua" )

-- Pedido del autor: que PASE las puertas, abriendolas fisicamente.
include( "server_doors.lua" )

-- Pedido del autor: que se le pueda quitar el sonido a las PISADAS, con la
-- restriccion de que el Paramic tenga que poder oirlas despues.
--
-- VA DESPUES DE server_doors.lua Y NO ES INDISTINTO: PHANTASMAGORIA.ResolveFlag
-- se define alli, y este archivo lo consume. server_speed.lua tiene el problema
-- al reves -- se incluye ANTES y lo resuelve en tiempo de ejecucion, con una
-- guarda -- y ese desorden ya esta anotado en ESTADO.md como pendiente. No se
-- arregla en esta ronda a proposito: mover ResolveFlag es un cambio de cero
-- comportamiento, y meterlo en la misma ronda que un mecanismo nuevo convierte
-- un rojo en un misterio.
include( "server_steps.lua" )

---------------------------------------------------------------------------
-- GUARDA: un campo pisado por un metodo del mismo nombre
---------------------------------------------------------------------------
-- DEFECTO MEDIDO EN LA RONDA 4. ENT.phantom_WalksWhenHunting era un CAMPO
-- ( false ) y en server_speed.lua habia un METODO homonimo. Como los includes
-- corren despues, la funcion pisaba al campo: el resolvedor leia una funcion
-- -- que no es true ni false -- y caia a la rama "el flag es nil".
--
-- Se veia en cada linea del reporte ( "campo = function: 0x8088..." ) y aun asi
-- el check que lo ejercia PASO, porque el default de la rama nil coincidia con
-- lo que se esperaba. *Un default que coincide con lo esperado convierte un
-- campo roto en un check verde*, y eso no lo agarra ninguna corrida: lo agarra
-- una guarda o nadie.
--
-- Corre DESPUES de los dos includes a proposito: antes de ellos el pisado
-- todavia no ocurrio, y una guarda que mira demasiado temprano es una guarda
-- que siempre pasa. Y la lista sale de FLAGS, o sea de la misma tabla que usa
-- el comando: si aparece un flag nuevo, queda cubierto sin tocar esto.
for _, key in ipairs( FLAG_ORDER ) do
    local campo = FLAGS[ key ].campo

    if isfunction( ENT[ campo ] ) then
        ErrorNoHalt( "[Phantasmagoria] EL CAMPO '" .. campo .. "' esta PISADO por un metodo del mismo " ..
            "nombre. El resolvedor va a leer una funcion y va a creer que el flag no esta declarado, " ..
            "sin tirar error. Renombrar el metodo.\n" )

    end
end
