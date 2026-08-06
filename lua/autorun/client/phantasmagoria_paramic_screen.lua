--[[-------------------------------------------------------------------------
    Phantasmagoria - pantallas de los microfonos parabolicos

    QUE HACE
    Dibuja en un RenderTarget y lo monta como submaterial de la pantalla de los
    modelos paramic2 y paramic3, para que muestren algo vivo en vez de un panel
    pintado. El paramic1 no tiene pantalla: tiene un LED, y va aparte.

    ESTE ARCHIVO NO HACE NADA SOLO. Define funciones y un concommand de prueba;
    no engancha ningun hook de dibujado ni toca ninguna entidad hasta que
    alguien lo llama. Mientras no se llame, los modelos se ven igual que antes
    de partirlos en submateriales.

    QUE MUESTRA CADA UNA, y de donde sale
    No es invento: los dos Canvas de Unity estan censados desde los assets del
    juego (AssetRipper, jerarquia del GameObject de cada tier).

      tier 2 -> lectura numerica. Campos del Canvas: Title, Session Text,
                Folder, MinText/MinValueText, PeakText/PeakValueText,
                Total Volume Text, dB, Duration, Duration Timer.
      tier 3 -> lo mismo MAS un radar. Campos extra: Radar > Noise Spots, y las
                marcas de distancia 30m L / 25m L / 15m L / 1m / 15m R / 25m R
                / 30m R.

    LO QUE NO HACE
    Nada de esto mide sonido. Los valores salen de PHANTASMAGORIA.ParamicData,
    que hoy arranca en cero: el que los llene es el sistema del mod. Dejarlo
    explicito importa — una pantalla que muestra ceros convincentes se puede
    confundir con una que anda y no detecta nada.
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

--[[
    Un RenderTarget por tier, con la RELACION DE ASPECTO de su pantalla.

    No es cosmetico: las UV de la pantalla vienen remapeadas a [0,1] (ver
    bl_merge.py --screen-fit), asi que la textura se estira sobre el rectangulo
    real. Con un RT cuadrado sobre una pantalla apaisada todo sale achatado, y
    un circulo del radar saldria ovalado sin que nada indique que el problema
    es el RT y no el dibujo.

    Medido en Blender sobre las caras de la pantalla (bl_screen_orient.py):
        tier 3: 0.0972 x 0.0610 m  -> 1.594 : 1
        tier 2: 10.143 x 7.196 u   -> 1.409 : 1
]]
local SCREENS = {
    ["models/phantasmagoria/paramic3.mdl"] = { rt = "phantasmagoria_paramic3_screen", w = 512, h = 320, layout = "radar" },
    ["models/phantasmagoria/paramic2.mdl"] = { rt = "phantasmagoria_paramic2_screen", w = 512, h = 364, layout = "meter" },
}

--[[
    Los datos que muestran las pantallas. Arrancan en cero A PROPOSITO: hoy no
    hay nada que los llene, y una pantalla mostrando ceros no debe confundirse
    con una que mide y no detecta.
]]
PHANTASMAGORIA.ParamicData = {
    volume   = 0,     -- dB actuales
    min      = 0,
    peak     = 0,
    duration = 0,     -- segundos de sesion
    spots    = {},    -- radar del tier 3: { { ang = -30..30, dist = 0..30, db = n } }
}

local GREEN     = Color( 60, 225, 130 )
local GREEN_DIM = Color( 26, 96, 58 )
local GREEN_HOT = Color( 150, 255, 190 )
local BG        = Color( 6, 14, 10 )

surface.CreateFont( "PhParamicBig",   { font = "Roboto", size = 58, weight = 700 } )
surface.CreateFont( "PhParamicMid",   { font = "Roboto", size = 24, weight = 600 } )
surface.CreateFont( "PhParamicSmall", { font = "Roboto", size = 17, weight = 500 } )
surface.CreateFont( "PhParamicTiny",  { font = "Roboto", size = 13, weight = 500 } )

local rts = {}

--[[
    El RT y su material se crean UNA vez por tier y se reusan.
]]
local function ensure( def )
    if rts[ def.rt ] then return rts[ def.rt ] end

    local rt = GetRenderTarget( def.rt, def.w, def.h )
    local mat = CreateMaterial( def.rt .. "_mat", "UnlitGeneric", {
        ["$basetexture"] = def.rt,

        -- $model 1 NO es opcional y es lo que costo la primera corrida en
        -- juego. Un material creado sin el se compila como material de
        -- mundo/brush; aplicado a un MODELO con SetSubMaterial no da error, no
        -- da textura de error y no imprime nada: la submalla simplemente NO SE
        -- DIBUJA y queda un agujero por el que se ve lo que hay detras.
        ["$model"] = "1",

        -- UnlitGeneric ya ignora la luz, que es lo que se quiere en una
        -- pantalla: encendida tiene que verse encendida en un sotano.
        ["$nolod"] = "1",
    } )
    mat:SetTexture( "$basetexture", rt )

    rts[ def.rt ] = { rt = rt, mat = mat, w = def.w, h = def.h, layout = def.layout }
    return rts[ def.rt ]
end

--[[-------------------------------------------------------------------------
    Layout del tier 2: lectura numerica, sin radar.
---------------------------------------------------------------------------]]
local function layoutMeter( w, h, d )
    draw.SimpleText( "GHOST HUNTN DISTRIBUTION INC", "PhParamicTiny", 12, 10, GREEN_DIM )
    draw.SimpleText( "PARABOLIC MICROPHONE II", "PhParamicSmall", 12, 26, GREEN )

    surface.SetDrawColor( GREEN_DIM )
    surface.DrawRect( 12, 52, w - 24, 1 )

    draw.SimpleText( "MIN",  "PhParamicSmall", 12, 64, GREEN_DIM )
    draw.SimpleText( string.format( "%.2f", d.min ), "PhParamicSmall", 100, 64, GREEN )
    draw.SimpleText( "PEAK", "PhParamicSmall", w - 160, 64, GREEN_DIM )
    draw.SimpleText( string.format( "%.2f", d.peak ), "PhParamicSmall", w - 90, 64, GREEN )

    -- El numero grande: seis digitos con ceros a la izquierda, como en el
    -- juego (000.00). Ancho fijo, si no el texto salta de posicion al cambiar.
    draw.SimpleText( string.format( "%06.2f", d.volume ), "PhParamicBig",
        w * 0.5, h * 0.52, GREEN_HOT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
    draw.SimpleText( "dB", "PhParamicMid", w * 0.5, h * 0.52 + 44, GREEN,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

    surface.SetDrawColor( GREEN_DIM )
    surface.DrawRect( 12, h - 40, w - 24, 1 )

    draw.SimpleText( "DURATION", "PhParamicTiny", 12, h - 30, GREEN_DIM )
    draw.SimpleText( string.format( "%02d:%02d", math.floor( d.duration / 60 ), math.floor( d.duration % 60 ) ),
        "PhParamicSmall", 12, h - 22, GREEN )
end

--[[-------------------------------------------------------------------------
    Layout del tier 3: el radar, mas la lectura numerica abajo.

    El arco va de -60 a +60 grados alrededor del eje del microfono, con anillos
    a 1, 15, 25 y 30 m — las mismas distancias que nombran los nodos del Canvas
    del juego (30m L, 25m L, 15m L, 1m, 15m R, 25m R, 30m R).
---------------------------------------------------------------------------]]
local RINGS = { 1, 15, 25, 30 }
local SWEEP = 60         -- grados a cada lado
local MAXD  = 30

local function radarPos( cx, cy, r, angDeg, dist )
    -- 0 grados = hacia arriba (adelante del microfono)
    local a = math.rad( angDeg - 90 )
    local rr = r * math.Clamp( dist / MAXD, 0, 1 )
    return cx + math.cos( a ) * rr, cy + math.sin( a ) * rr
end

local function layoutRadar( w, h, d )
    draw.SimpleText( "PARABOLIC MICROPHONE III", "PhParamicSmall", 10, 8, GREEN )
    draw.SimpleText( "AUDIO SWEEP", "PhParamicTiny", w - 10, 10, GREEN_DIM, TEXT_ALIGN_RIGHT )

    local cx, cy = w * 0.5, h * 0.76
    local r = h * 0.60

    draw.NoTexture()
    surface.SetDrawColor( GREEN_DIM )

    -- anillos de distancia
    for _, dist in ipairs( RINGS ) do
        local prevx, prevy
        for a = -SWEEP, SWEEP, 4 do
            local x, y = radarPos( cx, cy, r, a, dist )
            if prevx then surface.DrawLine( prevx, prevy, x, y ) end
            prevx, prevy = x, y
        end
        local lx, ly = radarPos( cx, cy, r, -SWEEP, dist )
        draw.SimpleText( dist .. "m", "PhParamicTiny", lx - 4, ly - 6, GREEN_DIM, TEXT_ALIGN_RIGHT )
        local rx, ry = radarPos( cx, cy, r, SWEEP, dist )
        draw.SimpleText( dist .. "m", "PhParamicTiny", rx + 4, ry - 6, GREEN_DIM )
    end

    -- radios de los extremos y del centro
    for _, a in ipairs( { -SWEEP, 0, SWEEP } ) do
        local x, y = radarPos( cx, cy, r, a, MAXD )
        surface.DrawLine( cx, cy, x, y )
    end

    -- los focos de ruido detectados
    for _, s in ipairs( d.spots or {} ) do
        local x, y = radarPos( cx, cy, r, s.ang or 0, s.dist or 0 )
        local rad = 6 + math.Clamp( ( s.db or 0 ) / 20, 0, 6 )
        surface.SetDrawColor( GREEN_HOT )
        local px, py
        for i = 0, 16 do
            local a = math.rad( i * 22.5 )
            local nx, ny = x + math.cos( a ) * rad, y + math.sin( a ) * rad
            if px then surface.DrawLine( px, py, nx, ny ) end
            px, py = nx, ny
        end
        draw.SimpleText( string.format( "%.1f dB", s.db or 0 ), "PhParamicTiny", x, y - rad - 10,
            GREEN_HOT, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
    end

    -- pie: los mismos campos que el Canvas del juego
    draw.SimpleText( "MIN",  "PhParamicTiny", 10, h - 30, GREEN_DIM )
    draw.SimpleText( string.format( "%.2f", d.min ), "PhParamicTiny", 44, h - 30, GREEN )
    draw.SimpleText( "PEAK", "PhParamicTiny", 110, h - 30, GREEN_DIM )
    draw.SimpleText( string.format( "%.2f", d.peak ), "PhParamicTiny", 152, h - 30, GREEN )
    draw.SimpleText( string.format( "%06.2f dB", d.volume ), "PhParamicMid", w - 10, h - 34,
        GREEN_HOT, TEXT_ALIGN_RIGHT )
    draw.SimpleText( string.format( "%02d:%02d", math.floor( d.duration / 60 ), math.floor( d.duration % 60 ) ),
        "PhParamicTiny", 10, h - 16, GREEN_DIM )
end

local LAYOUTS = { meter = layoutMeter, radar = layoutRadar }

--[[-------------------------------------------------------------------------
    Redibuja el contenido de una pantalla.

    TRES RESULTADOS DISTINTOS, a proposito:
      - pantalla invisible (se ve a traves)  -> el MATERIAL no dibuja. Falta
        $model 1, o el nombre del material no coincide con el del "!".
      - fondo liso, sin contenido            -> el material anda y el RT se
        limpia, pero el dibujo 2D cae fuera del recuadro.
      - contenido pero congelado             -> se monta y no se redibuja.
    render.Clear pinta el render target ENTERO y no depende del espacio 2D: por
    eso el fondo es lo que separa un problema del otro.
---------------------------------------------------------------------------]]
function PHANTASMAGORIA.DrawParamicScreen( def, drawFn )
    local e = ensure( def )

    -- Con x/y/w/h explicitos el viewport queda del tamano del RT y no del de
    -- la pantalla.
    render.PushRenderTarget( e.rt, 0, 0, e.w, e.h )
        cam.Start2D()
            render.Clear( BG.r, BG.g, BG.b, 255 )
            local fn = drawFn or LAYOUTS[ e.layout ]
            if fn then fn( e.w, e.h, PHANTASMAGORIA.ParamicData ) end
        cam.End2D()
    render.PopRenderTarget()
end

--[[-------------------------------------------------------------------------
    El indice del submaterial NO se cablea: se busca por nombre.

    Estaba cableado en 1, leido del .mdl del tier 3. Funciona para el tier 3 y
    para el tier 2, y es DESTRUCTIVO en el tier 1, donde el orden real es

        paramic1: 0 = cuerpo, 1 = paramic1_glass      <-- el 1 es el PLATO
        paramic2: 0 = cuerpo, 1 = paramic2_screen, 2 = paramic2_glass
        paramic3: 0 = cuerpo, 1 = paramic3_screen, 2 = paramic3_glass

    El tier 1 no tiene pantalla, asi que un indice fijo le monta el
    RenderTarget al plato parabolico. No da error: se ve mal, que es peor.
---------------------------------------------------------------------------]]
PHANTASMAGORIA.PARAMIC_SCREEN_SUFFIX = "_screen"

function PHANTASMAGORIA.FindScreenSubMaterial( ent )
    if not IsValid( ent ) then return nil end
    local mats = ent:GetMaterials()
    if not istable( mats ) then return nil end
    for i, m in ipairs( mats ) do
        -- GetMaterials() es base 1 y SetSubMaterial base 0: el desfasaje de
        -- uno se paga aca, una sola vez.
        if string.EndsWith( m, PHANTASMAGORIA.PARAMIC_SCREEN_SUFFIX ) then
            return i - 1, m
        end
    end
    return nil
end

-- El "!" le dice a Source que el nombre es el de un material ya creado en
-- memoria y no una ruta de archivo. Sin el busca un .vmt en disco, no lo
-- encuentra, y sale la textura de error.
function PHANTASMAGORIA.AttachParamicScreen( ent )
    local def = SCREENS[ ent:GetModel() or "" ]
    if not def then return false end
    local idx = PHANTASMAGORIA.FindScreenSubMaterial( ent )
    if not idx then return false end
    local e = ensure( def )
    ent:SetSubMaterial( idx, "!" .. def.rt .. "_mat" )
    return true, def
end

-- SetSubMaterial con el indice y SIN segundo argumento limpia el override.
function PHANTASMAGORIA.DetachParamicScreen( ent )
    local idx = PHANTASMAGORIA.FindScreenSubMaterial( ent )
    if not idx then return false end
    ent:SetSubMaterial( idx )
    return true
end

--[[-------------------------------------------------------------------------
    EL LED DEL TIER 1

    El tier 1 no tiene pantalla: tiene un LED rojo que parpadea al detectar un
    sonido. En el modelo ya esta — la mascara de $selfillum del cuerpo son
    1.838 texeles en una caja de 48x50 con 76.6 % de relleno, o sea un circulo
    (pi/4 = 78.5 %). No hay que agregar geometria ni textura.

    Para apagarlo y prenderlo alcanza con $selfillumtint, que MULTIPLICA la
    emision: en negro el LED se apaga y el resto del cuerpo no cambia, porque
    fuera de la mascara no hay emision que atenuar. Se hace sobre una copia
    creada en runtime y montada como submaterial 0, para no mutar el material
    compartido del disco.

    OJO: el tint vive en el MATERIAL, no en la entidad. Dos paramic1 a la vista
    parpadean juntos. Para independizarlos haria falta un material por entidad.
---------------------------------------------------------------------------]]
local ledMat

local function ensureLED()
    if ledMat then return ledMat end
    ledMat = CreateMaterial( "phantasmagoria_paramic1_led", "VertexLitGeneric", {
        ["$basetexture"]      = "models/phantasmagoria/paramic1",
        ["$bumpmap"]          = "models/phantasmagoria/paramic1_normal",
        ["$model"]            = "1",
        ["$phong"]            = "1",
        ["$phongexponent"]    = "12",
        ["$phongboost"]       = "1.5",
        ["$phongfresnelranges"] = "[0.7 1.4 3.0]",
        ["$selfillum"]        = "1",
        ["$selfillumtint"]    = "[1 1 1]",
        ["$halflambert"]      = "1",
    } )
    return ledMat
end

--[[
    El brillo del LED encendido, y por que es una constante con nombre.

    `$selfillumtint` MULTIPLICA la emision, asi que no esta acotado a 1: subirlo
    sube el brillo del LED y no toca el resto del cuerpo, porque fuera de la
    mascara no hay emision que multiplicar.

    Arranco en 1.0 y el autor lo juzgo en juego: *«funciona pero el brillo podria
    ser un poquito mas alto»* (ronda 3b, check 09). Va a 1.8. El verde y el azul
    quedan en la misma proporcion de antes (0.25 del rojo) para no correr el
    color hacia el rosa: lo que se pidio es mas brillo, no otro color.

    NO esta medido cual es el valor "correcto" — no hay un numero de Unity que
    decirle. Es un ajuste a ojo y por eso vive aca arriba, con nombre, en vez de
    estar escrito adentro de la cuenta.
]]
PHANTASMAGORIA.PARAMIC_LED_BOOST = 1.8

-- `f` de 0 a 1. 0 apaga el LED; 1 lo deja en el brillo elegido.
function PHANTASMAGORIA.SetParamicLED( ent, f )
    if not IsValid( ent ) then return false end
    if ent:GetModel() ~= "models/phantasmagoria/paramic1.mdl" then return false end
    local m = ensureLED()
    local b = f * ( PHANTASMAGORIA.PARAMIC_LED_BOOST or 1 )
    m:SetVector( "$selfillumtint", Vector( b, b * 0.25, b * 0.25 ) )
    ent:SetSubMaterial( 0, "!phantasmagoria_paramic1_led" )
    return true
end

--[[-------------------------------------------------------------------------
    Prueba manual. Apuntar a un paramic y correr:

        phantasmagoria_paramic_rt

    Vuelve a correrlo apuntando al mismo prop para sacarlo.

    En el tier 2 y el 3 monta el RenderTarget con su layout. En el tier 1
    parpadea el LED. En cualquier otro modelo avisa y no toca nada.

    Engancha el redibujado a PreDrawOpaqueRenderables, que corre una vez por
    frame ANTES de dibujar el mundo: dibujar dentro de un RT mientras se esta
    dibujando la escena deja el render target de la escena cambiado a la mitad.
---------------------------------------------------------------------------]]
local attached = nil

local function demoData()
    -- Datos de demostracion: se MUEVEN, porque una pantalla congelada con
    -- numeros plausibles no se distingue de una que quedo con la textura
    -- vieja. Cuando haya deteccion real, esto lo reemplaza el mod.
    local d = PHANTASMAGORIA.ParamicData
    local t = CurTime()
    d.volume   = 40 + math.sin( t * 1.7 ) * 18 + math.sin( t * 5.3 ) * 6
    d.min      = math.min( d.min == 0 and d.volume or d.min, d.volume )
    d.peak     = math.max( d.peak, d.volume )
    d.duration = t % 3600
    d.spots    = {
        { ang = math.sin( t * 0.6 ) * 45, dist = 12 + math.sin( t * 0.9 ) * 8, db = d.volume },
        { ang = math.cos( t * 0.4 ) * 30, dist = 24 + math.sin( t * 1.3 ) * 5, db = d.volume * 0.6 },
    }
end

concommand.Add( "phantasmagoria_paramic_rt", function()
    local ply = LocalPlayer()
    if not IsValid( ply ) then return end

    local ent = ply:GetEyeTrace().Entity
    if not IsValid( ent ) then
        MsgC( Color( 255, 120, 120 ), "[Phantasmagoria] No estas mirando ninguna entidad.\n" )
        return
    end

    if attached == ent then
        PHANTASMAGORIA.DetachParamicScreen( ent )
        ent:SetSubMaterial( 0 )
        hook.Remove( "PreDrawOpaqueRenderables", "phantasmagoria_paramic_rt" )
        attached = nil
        MsgC( Color( 120, 235, 120 ), "[Phantasmagoria] Devuelto a los materiales del modelo.\n" )
        return
    end

    -- Imprimir CON QUE se esta midiendo, no solo el resultado: si el modelo no
    -- es el que se cree, un "listo" a secas no lo distingue de un exito.
    local mdl  = ent:GetModel() or "?"
    local mats = ent:GetMaterials() or {}
    local idx  = PHANTASMAGORIA.FindScreenSubMaterial( ent )
    MsgC( Color( 235, 235, 235 ), "[Phantasmagoria] modelo = " .. mdl .. "\n" )
    for i, m in ipairs( mats ) do
        MsgC( Color( 200, 200, 200 ), string.format( "   SetSubMaterial(%d) -> %s%s\n",
            i - 1, m, ( i - 1 ) == idx and "   <-- la pantalla" or "" ) )
    end

    if mdl == "models/phantasmagoria/paramic1.mdl" then
        MsgC( Color( 235, 235, 235 ), "[Phantasmagoria] Este tier no tiene pantalla: parpadeo el LED.\n" )
        attached = ent
        hook.Add( "PreDrawOpaqueRenderables", "phantasmagoria_paramic_rt", function()
            if not IsValid( attached ) then
                hook.Remove( "PreDrawOpaqueRenderables", "phantasmagoria_paramic_rt" )
                attached = nil
                return
            end
            PHANTASMAGORIA.SetParamicLED( attached, math.abs( math.sin( CurTime() * 6 ) ) )
        end )
        return
    end

    if not idx then
        MsgC( Color( 255, 120, 120 ),
            "[Phantasmagoria] Ninguno de los " .. #mats .. " material(es) termina en '" ..
            PHANTASMAGORIA.PARAMIC_SCREEN_SUFFIX .. "': este modelo no tiene pantalla.\n" )
        return
    end

    local ok, def = PHANTASMAGORIA.AttachParamicScreen( ent )
    if not ok then
        MsgC( Color( 255, 120, 120 ), "[Phantasmagoria] No pude montar el RT en este modelo.\n" )
        return
    end

    attached = ent
    hook.Add( "PreDrawOpaqueRenderables", "phantasmagoria_paramic_rt", function()
        if not IsValid( attached ) then
            hook.Remove( "PreDrawOpaqueRenderables", "phantasmagoria_paramic_rt" )
            attached = nil
            return
        end
        demoData()
        PHANTASMAGORIA.DrawParamicScreen( def )
    end )

    MsgC( Color( 120, 235, 120 ), "[Phantasmagoria] RT montado en el submaterial " .. idx ..
        " (layout '" .. def.layout .. "', " .. def.w .. "x" .. def.h ..
        "). Volve a correrlo apuntando al mismo prop para sacarlo.\n" )
end, nil, "Monta un RenderTarget de prueba en la pantalla del paramic que estas mirando (o parpadea el LED del tier 1)" )
