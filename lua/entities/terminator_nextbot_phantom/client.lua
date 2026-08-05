--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom / cliente

    EL INSTRUMENTO: un marcador que atraviesa paredes sobre cada fantasma.
    Sin esto, un modelo negro sin ojos en un mapa oscuro es indistinguible de
    "no spawneo nada".

    NO se toca el dibujado de la entidad. La base ya tiene su propio Draw y
    su propio material de wraith; esto es un hook aparte que dibuja encima y
    no puede romperle el render a nadie.

    La base ademas trae visualizadores propios que NO hay que reescribir:
      term_debugpath      dibuja el path. PIDE sv_cheats 1 ( base/init.lua:92 )
      term_debugtasks     imprime tareas, y vuelca el historial si le haces +use al bot
      term_debughearing   lo que el bot oye
---------------------------------------------------------------------------]]

local cvMarker = CreateClientConVar( "phantasmagoria_debug_ghost", "1", true, false,
    "Dibuja un marcador sobre los fantasmas de Phantasmagoria. Instrumento de desarrollo.", 0, 1 )

-- Diseno 1: 1 u = 1,905 cm, o sea 1 m ~ 52,5 u.
local UNITS_PER_METER = 52.5

local colGhost = Color( 190, 120, 255 )
local colText  = Color( 255, 255, 255 )

local BEAM_HEIGHT  = 220
local LABEL_HEIGHT = 250

hook.Add( "PostDrawTranslucentRenderables", "phantasmagoria_ghost_marker", function( _bDrawingDepth, bDrawingSkybox, isDraw3DSkybox )
    if bDrawingSkybox or isDraw3DSkybox then return end
    if not cvMarker:GetBool() then return end

    -- LIMITACION CONOCIDA: solo encuentra fantasmas dentro del PVS. Uno lejos
    -- o detras de geometria simplemente no esta en el cliente, y la ausencia
    -- de marcador NO prueba que no exista. Para eso esta el comando
    -- phantasmagoria_ghost_where, que corre en el servidor y los ve todos.
    --
    -- Y ojo con los 30 tipos de Diseno 12.2: van a ser clases propias
    -- ( phantasmagoria_<tipo> ), asi que esta busqueda por clase exacta va a
    -- dejar de encontrarlos y hay que ampliarla cuando existan.
    local ghosts = ents.FindByClass( "terminator_nextbot_phantom" )
    if #ghosts <= 0 then return end

    local ply = LocalPlayer()
    if not IsValid( ply ) then return end

    local eyePos = ply:EyePos()
    local yaw = ply:EyeAngles().y

    cam.IgnoreZ( true )
    render.SetColorMaterial()

    for _, ghost in ipairs( ghosts ) do
        if not IsValid( ghost ) then continue end

        local pos = ghost:GetPos()
        local mins, maxs = ghost:OBBMins(), ghost:OBBMaxs()
        local top = pos + Vector( 0, 0, maxs.z )

        render.DrawWireframeBox( pos, angle_zero, mins, maxs, colGhost, true )
        render.DrawLine( top, top + Vector( 0, 0, BEAM_HEIGHT ), colGhost, true )

        local dist = math.Round( eyePos:Distance( pos ) / UNITS_PER_METER, 1 )

        cam.Start3D2D( top + Vector( 0, 0, LABEL_HEIGHT ), Angle( 0, yaw - 90, 90 ), 0.35 )
            draw.SimpleText( "PHANTOM #" .. ghost:EntIndex(), "DermaLarge", 0, 0, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
            draw.SimpleText( dist .. " m", "DermaLarge", 0, 6, colGhost, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
        cam.End3D2D()

    end

    cam.IgnoreZ( false )

end )
