--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom / server

    Configuracion minima + los dos instrumentos server-side:
      - el aviso de spawn (que modelo salio, donde, y si hay navmesh)
      - phantasmagoria_ghost_where, que dice donde esta cada fantasma vivo
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

    ghostPrint( "spawn #", self:EntIndex(),
        "  modelo ", tostring( self:GetModel() ),
        "  skin ", self:GetSkin(),
        "  pos ", tostring( self:GetPos() ), "\n" )

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

concommand.Add( "phantasmagoria_ghost_where", function( ply )
    local function say( line )
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

    local found = 0

    for _, ghost in ipairs( ents.GetAll() ) do
        if not ghost.IsPhantasmagoriaGhost then continue end
        if not IsValid( ghost ) then continue end

        found = found + 1

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
        say( "    enemigo " .. ( IsValid( enemy ) and tostring( enemy ) or "ninguno" ) )

        -- una por linea: son el dato que mas dice y el que mas largo se pone
        if #tasks <= 0 then
            say( "    tareas  ninguna" )

        else
            say( "    tareas  " .. #tasks )

            for _, name in ipairs( tasks ) do
                say( "        - " .. name )

            end
        end

    end

    if found <= 0 then
        say( "[Phantasmagoria] no hay ningun fantasma vivo." )

    end

    say( "[Phantasmagoria] " .. found .. " fantasma(s). Navareas en el mapa: " .. navmesh.GetNavAreaCount() .. "." )

end, nil, "Imprime donde esta cada fantasma de Phantasmagoria, y si el mapa tiene navmesh." )
