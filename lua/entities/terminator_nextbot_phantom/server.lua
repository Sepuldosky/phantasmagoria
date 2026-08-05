--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom / server

    Configuracion minima + los dos instrumentos server-side:
      - el aviso de spawn (que modelo salio, donde, y si hay navmesh)
      - phantasmagoria_ghost_where, que dice donde esta cada fantasma vivo
---------------------------------------------------------------------------]]

local function ghostPrint( ... )
    MsgC( Color( 190, 120, 255 ), "[Phantasmagoria] ", color_white, ... )

end

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

    -- La causa numero uno de "spawnea y no camina" no vive en esta entidad:
    -- vive en el mapa. La base tiene su propio aviso pero se lo manda solo al
    -- creador ( shared.lua:3047-3066 ), y si lo spawnea un script no hay
    -- creador a quien avisarle.
    if navmesh.GetNavAreaCount() <= 0 then
        ghostPrint( "SIN NAVMESH EN ESTE MAPA: el bot no va a caminar. " ..
            "Corre nav_generate, o usa un mapa con navmesh.\n" )

    end
end

---------------------------------------------------------------------------
-- Instrumento: donde esta cada fantasma
---------------------------------------------------------------------------
-- Complementa al marcador del cliente y falla distinto: el marcador solo
-- dibuja fantasmas dentro del PVS del jugador, este los ve todos. Si uno
-- aparece aca y no en pantalla, el bot existe y el que fallo es el dibujo.
concommand.Add( "phantasmagoria_ghost_where", function( ply )
    local function say( line )
        if IsValid( ply ) then
            ply:PrintMessage( HUD_PRINTCONSOLE, line )

        else
            print( line )

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
        say( "    tareas  " .. ( #tasks > 0 and table.concat( tasks, ", " ) or "ninguna" ) )

    end

    if found <= 0 then
        say( "[Phantasmagoria] no hay ningun fantasma vivo." )

    end

    say( "[Phantasmagoria] " .. found .. " fantasma(s). Navareas en el mapa: " .. navmesh.GetNavAreaCount() .. "." )

end, nil, "Imprime donde esta cada fantasma de Phantasmagoria, y si el mapa tiene navmesh." )
