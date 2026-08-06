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
local MODEL_CANDIDATES = {
    -- El elegido: m_anm, hull identico al de Arnold, 54 flexcontrollers.
    -- Viene de otro addon del Workshop, NO esta en este repo.
    "models/dejtriyev/scaryblackman.mdl",
    -- Del que deriva el anterior. Viene con GMod.
    "models/player/group01/male_04.mdl",
}

local function pickModel()
    for _, mdl in ipairs( MODEL_CANDIDATES ) do
        if util.IsValidModel( mdl ) then return mdl end

    end

    -- Ultimo recurso: la cadena literal "terminator", que shared.lua:2983
    -- traduce al modelo de la convar termhunter_modeloverride (Arnold por
    -- default). Feo a proposito: si sale Arnold, el modelo no esta montado.
    return "terminator"

end

local chosenModel = pickModel()

if chosenModel ~= MODEL_CANDIDATES[ 1 ] then
    ghostPrint( "el modelo ", MODEL_CANDIDATES[ 1 ], " no esta montado. Uso ", chosenModel, " en su lugar.\n" )

end

ENT.Models = { chosenModel }

-- Referencia 10: skin 0 = silueta negra sin ojos, skin 1 = ojos blancos.
-- Se aplica en shared.lua:2989 solo si es numero. Alternable con SetSkin.
ENT.ModelSkin = 1

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

---------------------------------------------------------------------------
-- Instrumento: hacia donde mira
---------------------------------------------------------------------------
-- Pedido del autor en la corrida 5, y es el que faltaba: "que el comando muestre
-- a donde esta mirando el phantom, porque yo lo veo moverse mirando a un solo
-- lado todo el tiempo". Sin esto, "mueve la vista" era una impresion y no un
-- numero, y ya me costo explicar la observacion antes de fijarla.
--
-- Se imprimen TRES cosas y no una, porque son las que se discriminan entre si:
--
--   mira    ENT:GetEyeAngles()         terminator_nextbot_base/shared.lua:81
--           OJO: el yaw NO es un yaw de cabeza. La funcion arma el angulo con
--           self:GetAngles() y solo le pisa el PITCH con GetAimPitch(). O sea
--           que horizontalmente "donde mira" ES hacia donde apunta el cuerpo.
--   quiere  ENT:GetDesiredEyeAngles()  terminator_nextbot_base/motion.lua:139
--           lo que alguna tarea le PIDIO mirar. Es el que separa las dos causas
--           posibles de una cabeza quieta.
--   marcha  loco:GetVelocity()         la direccion en la que se esta moviendo
--
-- Como se leen juntos:
--   quiere =/= mira        algo le pide girar y no llega -> es velocidad de giro
--   quiere == mira, quietos, caminando  -> NADIE le pide girar, que es lo que
--                          predice no tener TERM_FISTS ( motionoverrides.lua:2838,
--                          "only look towards goal if we have fists" )
--   mira =/= marcha        camina para un lado mirando para otro
local function lookLines( ghost, say )
    local eye  = ghost:GetEyeAngles()
    local want = ghost:GetDesiredEyeAngles()

    -- La base mueve al bot por el locomotion, no por la fisica de la entidad:
    -- el que tiene la velocidad de verdad es loco ( motionoverrides.lua:2840 usa
    -- locoMeta.GetVelocity( myTbl.loco ) ). Entity:GetVelocity() en un NextBot
    -- puede dar cero y leerse como "esta quieto".
    local vel = IsValid( ghost.loco ) and ghost.loco:GetVelocity() or vector_origin
    local spd = vel:Length()

    say( "    mira    yaw " .. math.Round( eye.y, 1 ) .. "  pitch " .. math.Round( eye.p, 1 ) )

    say( "    quiere  yaw " .. math.Round( want.y, 1 ) .. "  pitch " .. math.Round( want.p, 1 ) ..
        "   delta " .. math.Round( math.abs( math.AngleDifference( want.y, eye.y ) ), 1 ) .. " grados" )

    if spd < 1 then
        say( "    marcha  quieto ( " .. math.Round( spd, 1 ) .. " u/s )" )

    else
        local marcha = vel:Angle().y
        say( "    marcha  yaw " .. math.Round( marcha, 1 ) .. "  a " .. math.Round( spd ) .. " u/s" ..
            "   mirada vs marcha " .. math.Round( math.abs( math.AngleDifference( marcha, eye.y ) ), 1 ) .. " grados" )

    end
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

concommand.Add( "phantasmagoria_ghost_where", function( ply )
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

end, nil, "Imprime donde esta cada fantasma de Phantasmagoria, y si el mapa tiene navmesh." )

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

concommand.Add( "phantasmagoria_ghost_rel", function( ply )
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
end, nil, "Imprime, por fantasma y por jugador, la relacion cacheada y el resultado en vivo de ShouldBeEnemy." )

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

concommand.Add( "phantasmagoria_hunt", function( ply, _, args )
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

end, nil, "ANDAMIO. Prende ( 1 ) o apaga ( 0 ) el hunt de todos los fantasmas. Lo va a reemplazar la cordura." )

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
concommand.Add( "phantasmagoria_hunt_reeval", function( ply )
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
end, nil, "CONTROL. Re-dispara SetupEntityRelationship por jugador, para probar que el contador de re-evaluaciones esta vivo." )
