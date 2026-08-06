--[[-------------------------------------------------------------------------
    Phantasmagoria - espejo maldito

    QUE HACE
    Maneja los CUATRO estados del vidrio de haunted_mirror.mdl, que en el juego
    original son un solo material (un ShaderGraph) con tres entradas:

        apagado   -> el vidrio negro, tal cual sale del .vmt de disco
        sostenido -> oscuro CON las nubes moradas en los bordes. Este estado
                     faltaba en la primera version y por eso `off` no mostraba
                     ninguna nube: en el juego las nubes aparecen al TOMAR el
                     espejo, no cuando esta tirado sin tocar.
        activo    -> un RenderTarget con la vista de la habitacion favorita,
                     tenida de violeta, con nubes en los bordes
        roto      -> las grietas emisivas

    ESTE ARCHIVO NO HACE NADA SOLO. Define funciones y un concommand de prueba;
    no engancha ningun hook de dibujado ni toca ninguna entidad hasta que
    alguien lo llama. Mientras no se llame, el espejo se ve como el .vmt.

    DE DONDE SALEN LOS NUMEROS
    Del material 'Mirror Glass' (63:150) del juego, que tiene exactamente tres
    samplers y ningun color base:
        63:1075  'Mirror mask'                        degradado radial
        65:1017  'Mirror_Mirror Glass Crack_Emission' las grietas, EN GRIS
        63:4704  'Mirror Render Texture'   1024x1024  el feed en vivo
    El violeta no esta en ninguna textura: lo pone el shader. Por eso aca es un
    tinte y no un PNG teñido.

    LO QUE NO HACE
    No decide CUANDO cambiar de estado. La cordura, el temporizador de 7.5 %/s,
    el minimo de 20 % por uso y la rotura por debajo de 20 % son del sistema del
    mod, no de este archivo. Dejarlo explicito importa: un espejo que muestra
    una habitacion fija se puede confundir con uno que sigue a la habitacion
    favorita y no la actualiza.
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

local MIRROR_MODEL = "models/phantasmagoria/haunted_mirror.mdl"

--[[
    LA RELACION DEL RT NO ES COSMETICA.

    Las UV del vidrio estan remapeadas a [0,1] (bl_merge --fit-slot 1), asi que
    la textura se estira sobre el rectangulo real del ovalo. Medido en Blender
    sobre las caras del submaterial (bl_screen_orient.py):

        ancho 0.1397  x  alto 0.1810   ->   1 : 1.2957, VERTICAL

    Con un RT cuadrado la habitacion sale achatada y nada indica que el problema
    es el RT y no el dibujo. 512 x 663 da 1:1.2949 (0.06 % de error).

    (Las texturas ESTATICAS del vidrio si son cuadradas y eso esta bien: como
    las UV ya cubren [0,1] sobre ese rectangulo, un 1024x1024 se estira de
    vuelta al mapear. El RT es distinto porque su contenido se GENERA con una
    camara que tiene su propia relacion de aspecto.)
]]
local RT_NAME = "phantasmagoria_mirror_rt"
local RT_W, RT_H = 512, 663

--[[
    El submaterial se busca POR NOMBRE, no por indice.

    El orden real de haunted_mirror.mdl, leido del binario:
        0 = mirror        (el marco)
        1 = mirror_glass  (el vidrio)
    Cablear el 1 funcionaria hoy y se romperia en silencio si el modelo se
    recompila con las piezas en otro orden — que es exactamente como el indice
    cableado de los paramic termino montandole el RenderTarget al plato.
]]
PHANTASMAGORIA.MIRROR_GLASS_SUFFIX = "_glass"

function PHANTASMAGORIA.FindMirrorGlass( ent )
    if not IsValid( ent ) then return nil end
    local mats = ent:GetMaterials()
    if not istable( mats ) then return nil end
    for i, m in ipairs( mats ) do
        -- GetMaterials() es base 1 y SetSubMaterial base 0.
        if string.EndsWith( m, PHANTASMAGORIA.MIRROR_GLASS_SUFFIX ) then
            return i - 1, m
        end
    end
    return nil
end

local rt, rtMat, maskMat

local function ensure()
    if rt then return end

    rt = GetRenderTarget( RT_NAME, RT_W, RT_H )
    rtMat = CreateMaterial( RT_NAME .. "_mat", "UnlitGeneric", {
        ["$basetexture"] = RT_NAME,

        -- $model 1 NO es opcional. Un material creado sin el se compila como
        -- material de mundo; aplicado a un MODELO con SetSubMaterial no da
        -- error, no da textura de error y no imprime nada: la submalla
        -- simplemente NO SE DIBUJA y queda un agujero. Costo una ronda entera
        -- en los paramic.
        ["$model"] = "1",

        -- El espejo tiene que verse encendido en un sotano oscuro.
        ["$nolod"] = "1",
    } )
    rtMat:SetTexture( "$basetexture", rt )

    -- La mascara de las nubes. Es la 'Mirror mask' del juego, recortada al
    -- mismo rectangulo UV que el resto: BLANCA en el borde y NEGRA al centro,
    -- que es justo donde aparecen las nubes moradas en las capturas.
    maskMat = Material( "models/phantasmagoria/mirror_glass_mask" )
end

--[[-------------------------------------------------------------------------
    Redibuja la vista de la habitacion adentro del RT.

    `pos` es el centro de la habitacion favorita y `yaw` el angulo del barrido
    (en el juego la vista es una panoramica que gira desde el centro del cuarto).
    Quien llama decide como avanza el yaw: no se cablea aca porque depende de si
    el mod quiere que el barrido dependa del tiempo o de la mirada del jugador.

    TRES RESULTADOS DISTINTOS, a proposito:
      - vidrio invisible (se ve a traves) -> el MATERIAL no dibuja: falta
        $model 1 o el nombre del "!" no coincide.
      - vidrio de un color liso            -> el material anda y el RT se limpia,
        pero render.RenderView no dibujo nada (pos adentro de un solido, o
        llamado fuera de un hook de render).
      - imagen congelada                   -> se monta y no se redibuja.
    El Clear pinta el RT ENTERO, asi que el fondo es lo que separa un caso del
    otro.
---------------------------------------------------------------------------]]
function PHANTASMAGORIA.DrawMirrorView( pos, yaw, fov )
    ensure()

    render.PushRenderTarget( rt, 0, 0, RT_W, RT_H )
        render.Clear( 0, 0, 0, 255, true, true )

        render.RenderView( {
            origin = pos,
            angles = Angle( 0, yaw or 0, 0 ),
            x = 0, y = 0, w = RT_W, h = RT_H,
            fov = fov or 90,
            drawviewmodel = false,
            -- El jugador NO se ve en su propio espejo: es la unica excepcion
            -- que el juego declara sobre el feed en vivo.
            drawhud = false,
        } )

        cam.Start2D()
            -- El violeta. Multiplicar tine la escena sin lavarla; el juego lo
            -- resuelve en el shader y aca es una capa.
            surface.SetDrawColor( 150, 60, 220, 90 )
            surface.DrawRect( 0, 0, RT_W, RT_H )

            -- Las nubes de las esquinas, con la mascara del juego: blanca en el
            -- borde, asi que dibujada en aditivo aparece SOLO en el contorno.
            --
            -- El aditivo lo declara el VMT con $additive 1, NO se pide desde
            -- aca: render.SetBlend() regula el ALFA y no el modo de mezcla, y
            -- usarlo para esto no da error — da nubes que tapan la habitacion
            -- en vez de sumarse.
            -- Y el material se carga de un .vmt de disco: con el .vtf solo,
            -- Material() devuelve la textura de error.
            if maskMat and not maskMat:IsError() then
                surface.SetDrawColor( 170, 70, 235, 200 )
                surface.SetMaterial( maskMat )
                surface.DrawTexturedRect( 0, 0, RT_W, RT_H )
            end
        cam.End2D()
    render.PopRenderTarget()
end

--[[-------------------------------------------------------------------------
    Los tres estados.

    El "!" le dice a Source que el nombre es el de un material ya creado en
    memoria y no una ruta de archivo. Sin el busca un .vmt en disco, no lo
    encuentra, y sale la textura de error.
---------------------------------------------------------------------------]]

-- Vidrio activo: monta el RenderTarget. Hay que seguir llamando
-- DrawMirrorView() cada frame o la imagen queda congelada.
function PHANTASMAGORIA.SetMirrorActive( ent )
    ensure()
    local idx = PHANTASMAGORIA.FindMirrorGlass( ent )
    if not idx then return false end
    ent:SetSubMaterial( idx, "!" .. RT_NAME .. "_mat" )
    return true
end

-- Vidrio SOSTENIDO: oscuro con las nubes moradas en los bordes. En el juego
-- este es el estado al TOMAR el espejo, antes de activarlo — el apagado de
-- verdad (el espejo en el piso, sin tocar) no tiene nubes.
function PHANTASMAGORIA.SetMirrorHeld( ent )
    local idx = PHANTASMAGORIA.FindMirrorGlass( ent )
    if not idx then return false end
    ent:SetSubMaterial( idx, "models/phantasmagoria/mirror_glass_held" )
    return true
end

-- Vidrio roto: las grietas emisivas. En el juego, una vez roto el espejo no se
-- puede volver a usar en lo que queda de la investigacion.
function PHANTASMAGORIA.SetMirrorBroken( ent )
    local idx = PHANTASMAGORIA.FindMirrorGlass( ent )
    if not idx then return false end
    ent:SetSubMaterial( idx, "models/phantasmagoria/mirror_glass_broken" )
    return true
end

-- Vidrio apagado: SetSubMaterial con el indice y SIN segundo argumento limpia
-- el override y vuelve al .vmt de disco.
function PHANTASMAGORIA.SetMirrorOff( ent )
    local idx = PHANTASMAGORIA.FindMirrorGlass( ent )
    if not idx then return false end
    ent:SetSubMaterial( idx )
    return true
end

--[[-------------------------------------------------------------------------
    Prueba manual.

    phantasmagoria_mirror <off|sostenido|activo|roto|info>

    Sobre el espejo que se este mirando. `activo` engancha un HUDPaint que
    redibuja el RT con un barrido, y se apaga con `off`: es el unico lugar de
    este archivo que engancha algo, y solo mientras se lo pida.
---------------------------------------------------------------------------]]
local HOOK = "phantasmagoria_mirror_rt"

concommand.Add( "phantasmagoria_mirror", function( ply, _, args )
    local modo = ( args[ 1 ] or "info" ):lower()
    local ent = ply:GetEyeTrace().Entity

    if not IsValid( ent ) then
        print( "[espejo] no estas mirando ninguna entidad" )
        return
    end

    if modo == "info" then
        print( "[espejo] modelo = " .. tostring( ent:GetModel() ) )
        local mats = ent:GetMaterials()
        for i, m in ipairs( mats or {} ) do
            print( string.format( "         submaterial %d = %s", i - 1, m ) )
        end
        local idx, name = PHANTASMAGORIA.FindMirrorGlass( ent )
        print( "         vidrio encontrado: " .. tostring( idx ) .. "  " .. tostring( name ) )
        return
    end

    if ent:GetModel() ~= MIRROR_MODEL then
        print( "[espejo] esa entidad no es " .. MIRROR_MODEL )
        return
    end

    hook.Remove( "HUDPaint", HOOK )

    if modo == "activo" then
        if not PHANTASMAGORIA.SetMirrorActive( ent ) then
            print( "[espejo] no se encontro el submaterial del vidrio" )
            return
        end
        -- Barrido: 30 grados por segundo desde la posicion del espejo. En el
        -- mod real el origen es el centro de la habitacion favorita, no esto.
        hook.Add( "HUDPaint", HOOK, function()
            if not IsValid( ent ) then hook.Remove( "HUDPaint", HOOK ) return end
            PHANTASMAGORIA.DrawMirrorView( ent:GetPos() + Vector( 0, 0, 40 ), CurTime() * 30 % 360, 90 )
        end )
        print( "[espejo] activo, con barrido de prueba" )
    elseif modo == "sostenido" then
        print( "[espejo] sostenido = " .. tostring( PHANTASMAGORIA.SetMirrorHeld( ent ) ) )
    elseif modo == "roto" then
        print( "[espejo] roto = " .. tostring( PHANTASMAGORIA.SetMirrorBroken( ent ) ) )
    elseif modo == "off" then
        print( "[espejo] apagado = " .. tostring( PHANTASMAGORIA.SetMirrorOff( ent ) ) )
    else
        print( "[espejo] uso: phantasmagoria_mirror <off|sostenido|activo|roto|info>" )
    end
end )
