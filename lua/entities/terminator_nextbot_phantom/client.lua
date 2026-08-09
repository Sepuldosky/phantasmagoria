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

-- ⚠ TRES VALORES DESDE DISENO 20, Y EL MOTIVO ES QUE ESTE MARCADOR PASO A
-- CORROMPER LO QUE MIDE. Dibuja con IgnoreZ, o sea a traves de las paredes:
-- hasta ayer era lo unico que hacia visible a un modelo oscuro en un mapa
-- oscuro, y desde que existe la ausencia ( server_cloak.lua ) es lo unico que
-- te dice donde esta un fantasma que el diseno quiere invisible. Una corrida
-- hecha con esto en 1 no mide la invisibilidad: la tapa.
--
--   0  nada
--   1  SIEMPRE -- el wallhack de siempre. Sigue siendo el default, porque es el
--      instrumento de todo lo demas.
--   2  HONESTO -- no dibuja al fantasma que no se dibuja. Es el modo obligatorio
--      de las filas de invisibilidad.
--
-- ⚠ Y EL MODO 2 NECESITA UNA SEGUNDA MITAD O NO SE PUEDE JUZGAR: "no lo veo" y
-- "no lo dibuje" se ven exactamente igual. Por eso en 2 hay una linea de HUD
-- que sigue contando los que NO dibujo. *El instrumento tiene que seguir
-- hablando justo cuando deja de dibujar.*
local cvMarker = CreateClientConVar( "phantasmagoria_debug_ghost", "1", true, false,
    "Marcador de desarrollo sobre los fantasmas. 0 = nada · 1 = siempre, atravesando paredes ( tapa la invisibilidad de Diseno 20 ) · 2 = HONESTO: no dibuja al fantasma invisible, y cuenta cuantos oculto en una linea de HUD.", 0, 2 )

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

---------------------------------------------------------------------------
-- EL ESTADO DE RENDER, LEIDO DEL DESTINO Y NO DE NUESTRA CREENCIA
---------------------------------------------------------------------------
-- Diseno 20.4. `GetNoDraw()` y `GetMaterial()` son lo que el ENGINE tiene
-- puesto de verdad en esta maquina: si el servidor cree una cosa y el cliente
-- tiene otra, esta funcion lo dice y el NW var de al lado dice la otra mitad.
--
-- *Preguntarle al servidor que cree haber escrito acredita el pedido; preguntar
-- GetNoDraw acredita el efecto.* Ese es exactamente el modo de falla que este
-- taller ya pago: una guarda que mide la fuente en vez del destino.
--
-- Devuelve: invisible ( bool ), texto.
local function renderState( ghost )
    local nodraw = ghost:GetNoDraw()
    local mat    = ghost:GetMaterial()

    -- El NW var es la CREENCIA del servidor y viaja aparte de la bandera. Que
    -- los dos coincidan no es obvio: son dos sistemas de red distintos, y la
    -- unica forma de ver una divergencia es imprimirlos juntos.
    local dice = ghost:GetNWBool( "phantasmagoria_invisible", false )

    local txt = ( nodraw and "INVISIBLE ( GetNoDraw true )" or "se dibuja" ) ..
        ( ( mat and mat ~= "" ) and ( "   material '" .. mat .. "'" ) or "" ) ..
        "   ·  el server dice " .. ( dice and "INVISIBLE" or "visible" ) ..
        ( ( nodraw ~= dice ) and "   !! NO COINCIDEN" or "" )

    return nodraw, txt

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

---------------------------------------------------------------------------
-- EL LADO CLIENTE, EN TEXTO -- y existe porque una planilla mia pedia algo
-- imposible
---------------------------------------------------------------------------
-- La fila del networkeo se marco verde TRES VECES sin traer un dato del
-- cliente, y las tres veces se pego la salida del SERVIDOR. No fue descuido del
-- que corria: *la fila pedia pegar lo que dice un marcador 3D, y un marcador no
-- produce texto.* El unico registro posible era la palabra del operador o una
-- captura.
--
-- Y el realm cliente es justo donde este taller ya tuvo algo apagado dos
-- arranques sin un solo error de Lua. Un punto ciego historico medido con el
-- instrumento que no deja rastro es la peor combinacion posible.
--
-- ⚠ LLAMA A typeLabel, LA MISMA FUNCION QUE DIBUJA, y eso no es ahorro: si
-- imprimiera su propia version del texto seria OTRA medicion, y el dia que las
-- dos diverjan el comando diria que todo esta bien sobre un marcador que dice
-- otra cosa. Este addon ya tuvo dos impresiones del mismo dato separandose.
--
-- El wrapper de comandos vive en server.lua y aca no existe -- include() corre
-- otro chunk y ese archivo es del otro realm --, asi que se declara la misma
-- guarda. Se duplica a proposito en vez de mover el original: mover codigo de
-- cero comportamiento en la misma ronda que estrena un instrumento convierte un
-- rojo en un misterio. Cuando exista un archivo compartido, se unifica.
-- A la defensiva y por el mismo motivo que server.lua lo hace: el orden entre
-- lua/autorun/ y lua/entities/ no esta garantizado, y si este archivo corre
-- primero la mesa todavia no existe.
PHANTASMAGORIA = PHANTASMAGORIA or {}

if not PHANTASMAGORIA.AddCommand then
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
end

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_cl", function()
    local function say( line )
        MsgC( Color( 190, 120, 255 ), "[cl] ", color_white, line, "\n" )

    end

    -- La primera linea dice con que esta midiendo. Aca eso ES la mitad del
    -- veredicto: si el cliente no tiene los 30 tipos, la key va a llegar igual y
    -- el marcador va a mostrar la key cruda -- que es un sintoma con OTRA causa.
    local T = PHANTASMAGORIA and PHANTASMAGORIA.Types
    local n = 0

    if istable( T ) then
        for _ in pairs( T ) do n = n + 1 end

    end

    say( "LO QUE VE EL CLIENTE, no el servidor.   tipos en la tabla LOCAL: " ..
        ( istable( T ) and ( n .. "" ) or "NO EXISTE ( lua/autorun/phantasmagoria_data.lua no corrio en cliente )" ) )

    -- ⚠ EL MODO DEL MARCADOR VA EN LA PRIMERA PANTALLA, y no es formalidad: el
    -- servidor no puede leerlo, asi que esta es la unica linea de toda la
    -- corrida que dice si la invisibilidad se estaba midiendo o se estaba
    -- tapando. Una fila de Diseno 20 corrida en modo 1 no vale, y sin esto no
    -- habria forma de saberlo despues.
    local modoTxt = cvMarker:GetInt()

    say( "phantasmagoria_debug_ghost " .. modoTxt .. "   ( " ..
        ( modoTxt == 0 and "apagado"
        or modoTxt == 1 and "SIEMPRE -- atraviesa paredes y DELATA al fantasma invisible: las filas de Diseno 20 no se pueden medir asi"
        or "HONESTO -- no dibuja al fantasma invisible" ) .. " )" )

    -- ⚠ LAS DOS BUSQUEDAS, Y NO SON LA MISMA. Reportado en juego el 2026-08-08:
    -- con `absence 1` el marcador NO se dibuja NI EN MODO 1, que es el modo que
    -- delata a proposito. Hay dos causas posibles y se ven exactamente igual
    -- desde la pantalla:
    --
    --   ( a ) el cliente NO TIENE la entidad -- o sea que EF_NODRAW se la lleva
    --         puesta del lado cliente, y entonces NINGUN marcador clientside
    --         puede dibujar un fantasma invisible: cae Diseno 20.4 entero y hay
    --         que networkear la posicion aparte.
    --   ( b ) el cliente la tiene y el marcador la saltea -- defecto nuestro,
    --         en el hook o en la busqueda.
    --
    -- El marcador busca por CLASE ( ents.FindByClass ) y este comando por CAMPO
    -- ( ents.GetAll + IsPhantasmagoriaGhost ). Imprimir los dos numeros separa
    -- ademas una tercera causa que nadie habia nombrado: que las dos busquedas
    -- no encuentren lo mismo.
    local porClase = #ents.FindByClass( "terminator_nextbot_phantom" )
    local porCampo = 0

    for _, e in ipairs( ents.GetAll() ) do
        if IsValid( e ) and e.IsPhantasmagoriaGhost then porCampo = porCampo + 1 end

    end

    say( "en el CLIENTE:  por clase ( lo que usa el marcador ) " .. porClase ..
        "   ·  por campo ( lo que usa este comando ) " .. porCampo ..
        ( porClase ~= porCampo and "   !! NO COINCIDEN: el marcador y este comando no ven lo mismo" or "" ) )

    if porClase <= 0 and porCampo <= 0 then
        say( "    NINGUNA de las dos encuentra nada. Si el servidor dice que hay un fantasma cerca" )
        say( "    ( phantasmagoria_ghost_where ), entonces EF_NODRAW se lleva la entidad del lado" )
        say( "    cliente y NINGUN marcador clientside puede dibujar un fantasma invisible: eso" )
        say( "    tumba Diseno 20.4 y hay que networkear la posicion por otro lado." )

    end

    local vistos = 0

    for _, ghost in ipairs( ents.GetAll() ) do
        if not ghost.IsPhantasmagoriaGhost then continue end
        if not IsValid( ghost ) then continue end

        vistos = vistos + 1

        local key = ghost:GetNWString( "phantasmagoria_type", "" )
        local t   = istable( T ) and key ~= "" and T[ key ] or nil

        say( "#" .. ghost:EntIndex() ..
            "   key networkeada " .. ( key ~= "" and ( "'" .. key .. "'" ) or "( vacia: el server no le asigno tipo )" ) ..
            "   ficha " .. ( t and ( "SI -> " .. t.name .. ", threshold " .. tostring( t.hunt and t.hunt.threshold ) .. " %" ) or "NO" ) )

        -- Diseno 20.4: el estado de render, del lado que lo dibuja. Es LA
        -- medicion de la invisibilidad, porque el criterio de esa mecanica es
        -- visual y un marcador 3D no produce texto -- que es lo que hizo que la
        -- fila del networkeo se marcara verde tres rondas sin evidencia.
        local invisible, estado = renderState( ghost )

        say( "     render:               " .. estado )

        -- Y QUE HACE EL MARCADOR CON ESO. Sin esta linea, un fantasma sin
        -- marcador no distingue "esta invisible y el modo honesto lo respeto"
        -- de "el marcador esta roto" ni de "no esta en el PVS".
        local modo = cvMarker:GetInt()

        say( "     el marcador " ..
            ( modo == 0 and "esta APAGADO ( phantasmagoria_debug_ghost 0 )"
            or ( modo >= 2 and invisible ) and "NO LO DIBUJA ( modo 2 honesto, y el fantasma esta invisible )"
            or "dibuja:  " .. typeLabel( ghost ) ..
               ( ( modo < 2 and invisible ) and "   !! EN MODO 1 SOBRE UN FANTASMA INVISIBLE: el marcador lo esta delatando" or "" ) ) )

    end

    if vistos <= 0 then
        say( "ningun fantasma EN EL PVS. El cliente solo tiene los que estan a la vista: " ..
            "que no aparezca aca NO prueba que no exista ( para eso, phantasmagoria_ghost_where )." )

    else
        say( vistos .. " fantasma(s) en el PVS." )

    end

end, "Imprime lo que el CLIENTE tiene de cada fantasma a la vista: la key networkeada, si resuelve a ficha, y el texto exacto que dibuja el marcador." )

-- Lo que el marcador vio en el ultimo frame, para la linea de HUD del modo 2.
-- Son DOS numeros y no uno: los que estan en el PVS y los que no dibuje. Sin el
-- segundo, una pantalla sin marcadores no distingue "los oculte" de "no hay
-- ninguno cerca".
local ultimoConteo = { enPVS = 0, ocultos = 0 }

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

    -- El conteo se escribe ANTES del early return, y esa es la diferencia entre
    -- un instrumento y un dibujo: con cero fantasmas la linea de HUD tiene que
    -- decir cero, no quedarse con el numero del frame anterior.
    ultimoConteo.enPVS   = #ghosts
    ultimoConteo.ocultos = 0

    if #ghosts <= 0 then return end

    local ply = LocalPlayer()
    if not IsValid( ply ) then return end

    -- Diseno 20.4: en modo 2 el marcador NO delata al fantasma invisible.
    local honesto = cvMarker:GetInt() >= 2

    local eyePos = ply:EyePos()
    local yaw = ply:EyeAngles().y

    cam.IgnoreZ( true )
    render.SetColorMaterial()

    for _, ghost in ipairs( ghosts ) do
        if not IsValid( ghost ) then continue end

        -- Se lee GetNoDraw y no el NW var a proposito: lo que decide si el
        -- marcador delata es si el fantasma SE DIBUJA, y eso lo contesta la
        -- bandera de la entidad. El NW var es la creencia del servidor y se
        -- imprime aparte, en phantasmagoria_ghost_cl, justo para que una
        -- divergencia entre los dos sea visible en vez de decidir en silencio.
        if ghost:GetNoDraw() then
            ultimoConteo.ocultos = ultimoConteo.ocultos + 1

            if honesto then continue end

        end

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

---------------------------------------------------------------------------
-- LA LINEA QUE SIGUE HABLANDO CUANDO EL MARCADOR DEJA DE DIBUJAR
---------------------------------------------------------------------------
-- Diseno 20.4, y es la mitad sin la cual el modo 2 no se puede juzgar: un
-- fantasma invisible deja de tener marcador, y una pantalla sin marcadores no
-- distingue tres cosas -- que lo oculte, que no hay ninguno cerca, o que el
-- marcador se rompio.
--
-- ⚠ Y ADEMAS ES LA UNICA EVIDENCIA QUE SOBREVIVE A UNA CAPTURA. La regla que
-- costo tres rondas en la tajada A es que *un criterio visual necesita un
-- instrumento que produzca texto*; una consola se pega en el chat, pero la
-- pregunta de este bloque -- "no lo veo" -- se contesta mirando la pantalla. Que
-- el conteo este DENTRO de la pantalla es lo que hace que la captura sea
-- evidencia y no una impresion.
--
-- Solo en modo 2: en 1 el marcador ya se ve y esta linea seria ruido permanente.
hook.Add( "HUDPaint", "phantasmagoria_ghost_marker_hud", function()
    if cvMarker:GetInt() < 2 then return end

    local txt = "debug_ghost 2 ( honesto )   ·   " .. ultimoConteo.enPVS .. " en PVS   ·   " ..
        ultimoConteo.ocultos .. " invisibles ( NO se dibujan )"

    -- Sin fondo ni caja: es un instrumento de desarrollo y tapar el mapa seria
    -- pelearle a lo que se esta tratando de mirar.
    draw.SimpleText( txt, "DermaDefault", 12, 12, colGhost, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )

end )
