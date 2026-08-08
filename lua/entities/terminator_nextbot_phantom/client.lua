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

-- El estado del interruptor fantasma/cazador, en el color de la caja y en una
-- palabra. Es lo que hace que la corrida se pueda leer SIN consola: "no me
-- ataca" y "no puede atacarme" se ven igual desde adentro del juego.
-- Viene por NW var ( server.lua, phantom_SetHunting ) y NO por SetupDataTables:
-- la base networkea con slots hardcodeados y el Bool 0 ya es Crouching
-- ( Referencia 4.3, trampa 3 ).
local colHunt = Color( 255, 70, 70 )

-- EL TIPO ( Diseno 19, tajada A ), y esta es la unica lectura que prueba el
-- networkeo: el servidor escribe la key con SetNWString y el cliente la resuelve
-- contra su propia copia de PHANTASMAGORIA.Types.
--
-- LOS TRES ESTADOS SON DISTINTOS Y HAY QUE PODER SEPARARLOS, porque son tres
-- fallas distintas y sin esto las tres se ven como "no dice nada":
--
--   ""              el server no le asigno tipo    ( o typeassign 0 )
--   key sin ficha   la key VIAJO y el cliente no tiene los 30 -- o sea que
--                   lua/autorun/phantasmagoria_data.lua no corrio EN CLIENTE,
--                   que es justo la mitad que nadie miro nunca
--   nombre          la cadena entera funciona
--
-- ⚠ Y esto es un INSTRUMENTO, no la UI del juego. En Phasmophobia el tipo es
-- precisamente lo que hay que adivinar ( Diseno 12.1: "el tipo se sortea y no se
-- anuncia" ), asi que vive detras de phantasmagoria_debug_ghost como todo lo
-- demas de este marcador, y no se muda al HUD.
local function typeLabel( ghost )
    local key = ghost:GetNWString( "phantasmagoria_type", "" )
    if key == "" then return "sin tipo" end

    local T = PHANTASMAGORIA and PHANTASMAGORIA.Types
    local t = istable( T ) and T[ key ] or nil

    -- ASCII a proposito: esto se dibuja con DermaLarge, y un glifo que la fuente
    -- no tenga sale como un cuadrito -- que en la fila del networkeo se leeria
    -- como "el marcador esta roto" en vez de "el cliente no tiene los tipos".
    if not t then return key .. " ( !! sin ficha en el cliente )" end

    return t.name

end

-- El haz sigue siendo largo a proposito: es lo que te dice desde otra
-- habitacion en que direccion esta, y atraviesa el techo porque se dibuja con
-- IgnoreZ.
local BEAM_HEIGHT = 220

-- La etiqueta va PEGADA A LA CABEZA, no arriba del haz. Primera corrida
-- (2026-08-05): en un mapa de casa se veian la caja y el haz y NO el texto.
-- Estaba a 250 u sobre la cabeza, o sea a ~322 del piso, por encima del techo y
-- fuera del campo de vision de un jugador parado al lado. El instrumento estaba
-- pensado para un mapa abierto y se probo adentro de una casa.
local LABEL_HEIGHT = 14

-- Escala del texto por unidad de distancia. Calibrada contra la corrida 2: a
-- 4 m ( 4 * 52,5 u ) la escala fija 0.35 se leia bien, asi que esa es la razon.
local LABEL_SCALE_PER_UNIT = 0.35 / ( 4 * UNITS_PER_METER )

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

        local hunting = ghost:GetNWBool( "phantasmagoria_hunting", false )
        local col = hunting and colHunt or colGhost

        render.DrawWireframeBox( pos, angle_zero, mins, maxs, col, true )
        render.DrawLine( top, top + Vector( 0, 0, BEAM_HEIGHT ), col, true )

        local distU = eyePos:Distance( pos )
        local dist = math.Round( distU / UNITS_PER_METER, 1 )

        -- La escala sigue a la distancia para que el texto ocupe SIEMPRE lo
        -- mismo en pantalla. Con la escala fija que tenia, a 1,3 m tapaba media
        -- pantalla (corrida 3) -- justo cuando mas querias ver -- y de lejos no
        -- se leia. La constante sale de la corrida 2: a 4 m con 0.35 se leia
        -- bien. Los topes evitan el texto microscopico de cerca y uno de
        -- kilometros de largo del otro lado del mapa.
        local escala = math.Clamp( distU * LABEL_SCALE_PER_UNIT, 0.12, 1.5 )

        cam.Start3D2D( top + Vector( 0, 0, LABEL_HEIGHT ), Angle( 0, yaw - 90, 90 ), escala )
            draw.SimpleText( "PHANTOM #" .. ghost:EntIndex(), "DermaLarge", 0, 0, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
            draw.SimpleText( dist .. " m  " .. ( hunting and "HUNT" or "calma" ), "DermaLarge", 0, 6, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
            draw.SimpleText( typeLabel( ghost ), "DermaLarge", 0, 34, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
        cam.End3D2D()

    end

    cam.IgnoreZ( false )

end )
