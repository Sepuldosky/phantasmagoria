--[[-------------------------------------------------------------------------
    LAS CAMARAS DE LA PANTALLA DE CCTV

    Llena el layout `cctv` de `phantasmagoria_trucktv_screen.lua` con camaras
    de verdad: las descubre, las renderiza a un RenderTarget y compone la
    imagen sobre el rectangulo del visor.

    QUE ES CADA PESTAÑA, y que hace este archivo:

      CCTV CAMERAS   camaras RT de Garry's Mod. IMPLEMENTADA.
                     Dos origenes: las que pone el jugador con el toolgun
                     (`gmod_cameraprop`) y las que trae el mapa
                     (`point_camera`). Cual de los dos puebla la lista lo
                     decide `phantasmagoria_cctv_source`.
      VIDEO CAMERAS  la camara que se pone en tripode. NO IMPLEMENTADA.
      HEAD CAMERAS   camaras enganchadas al hueso `head` de un jugador.
                     NO IMPLEMENTADA.

    Las dos ultimas estan en la pantalla porque estan en el juego, y la
    pestaña dice NO INPUT — que es exactamente lo que significa: la pestaña
    existe y no hay fuente. Dejarlas afuera habria sido peor: una pantalla con
    una sola pestaña no se parece a la del juego, y agregar la pestaña despues
    obliga a rehacer la lista.

    POR QUE EL FEED SE COMPONE EN SOURCE Y NO EN LA PAGINA. Un panel DHTML no
    puede contener un RenderTarget. Pero la pantalla entera ya se arma sobre un
    RT en `DrawTruckTV`, asi que ahi caben los dos: la pagina primero, el feed
    encima. Eso ademas deja el titulo y el timecode del lado de Lua, que es
    donde corre el reloj de verdad.
---------------------------------------------------------------------------]]

if SERVER then return end

PHANTASMAGORIA = PHANTASMAGORIA or {}

-- Resolucion del RT de cada camara. NO es cuadrada a proposito: el visor es
-- apaisado (~690x440, 1,57:1) y un RT cuadrado estirado ahi deforma la imagen
-- sin que nada lo indique — el mismo bicho que el RT cuadrado sobre la pantalla
-- de 1,594:1 de los paramic. 512x320 = 1,6:1, y ademas se le pasa a RenderView
-- la relacion REAL del visor, que Lua ya conoce porque la pagina se la manda.
local CAM_W, CAM_H = 512, 320

--[[
    DE DONDE SALEN LAS CAMARAS.

    `all` es el default a proposito: en un mapa sin `point_camera` y sin nada
    puesto con el toolgun, cualquiera de los otros dos valores deja la pantalla
    vacia y eso se lee como "la pantalla no anda" y no como "no hay camaras".
]]
local cvSource = CreateClientConVar( "phantasmagoria_cctv_source", "all", true, false,
    "De donde salen las camaras CCTV: all | tool | map" )

--[[
    OFFSET DE ANGULO, en "pitch yaw roll".

    Existe por el mismo motivo que el `flipv` de la pantalla: si el modelo de la
    camara esta autorado mirando a otro lado, la imagen sale girada y hay que
    poder CORREGIRLO midiendo, no recompilando ni probando a ciegas. Se corre
    `phantasmagoria_cctv info`, se mira hacia donde apunta la camara en el
    mundo, se compara con lo que muestra la pantalla y recien ahi se toca esto.

    Default 0 0 0 a proposito: si hiciera falta un offset, quiero que el
    sintoma aparezca y no que quede tapado por un numero puesto de antemano.
]]
local cvAngOff = CreateClientConVar( "phantasmagoria_cctv_angoffset", "0 0 0", true, false,
    "Offset de angulo de las camaras: \"pitch yaw roll\"" )

-- Con esto prendido el RT de la camara se dibuja tambien en una esquina del HUD
-- y lleva marcas de color adentro. Ver el comentario de la marca en renderCam:
-- separa "el RT no llega a la pantalla" de "el RT llega y RenderView no dibujo",
-- que a ojo son el mismo negro.
local cvDebug = CreateClientConVar( "phantasmagoria_cctv_debug", "0", true, false,
    "Dibuja el RT de la camara en el HUD, con marcas de diagnostico" )

-- Como se pinta el RT sobre la pantalla: "render" (por defecto, toma la
-- ITexture directo) o "surface" (por material, que es lo que anda en el HUD y
-- lo que usa el resto del addon). Ver el comentario en DrawCctvFeed.
local cvDraw = CreateClientConVar( "phantasmagoria_cctv_draw", "render", true, false,
    "Como se pinta el feed: render | surface" )

local function angOffset()
    local p, y, r = string.match( cvAngOff:GetString(), "^%s*(-?[%d%.]+)%s+(-?[%d%.]+)%s+(-?[%d%.]+)%s*$" )
    return tonumber( p ) or 0, tonumber( y ) or 0, tonumber( r ) or 0
end

-- Cuantas camaras entran en la lista de la derecha. Es la cantidad de celdas
-- que dibuja la pagina, y esta escrito una sola vez: si cambia el layout,
-- cambia aca y la paginacion sigue cerrando.
local POR_PAGINA = 4

--[[
    LAS CLASES.

    `gmod_cameraprop` es la que crea la herramienta Camera del toolgun.
    `point_camera` es la entidad de mapa (la que un `info_camera_link` engancha
    a un monitor). Se buscan por clase y no por nombre: un mapa puede llamar a
    sus camaras como quiera.

    OJO con dar por hecho que `point_camera` existe del lado cliente. Puede no
    estar replicada, y en ese caso la lista sale corta SIN ERROR. Por eso el
    comando `phantasmagoria_cctv info` imprime cuantas encontro de cada clase:
    una lista vacia tiene que poder distinguirse de una busqueda que no llego.
]]
local CLASES = {
    tool = { "gmod_cameraprop" },
    map  = { "point_camera" },
}

local ESTADO = {
    cams    = {},      -- { { ent, origen, nombre }, ... }
    sel     = 0,       -- indice en `cams`; 0 = ninguna
    page    = 1,
    tab     = "cctv",
    rec     = false,
    nv      = false,
    zoom    = 0,       -- pasos de zoom, 0..ZOOM_MAX
    pan     = {},      -- [ent] = grados de yaw acumulados
    rt      = nil,
    mat     = nil,
    t0      = 0,       -- CurTime en que arranco el timecode
    ultimo  = 0,       -- ultima vez que se rastrearon las camaras
}

local ZOOM_MAX  = 4
local ZOOM_STEP = 12      -- grados de FOV que saca cada paso
local FOV_BASE  = 90
local PAN_STEP  = 15      -- grados por click

--[[-------------------------------------------------------------------------
    DESCUBRIR
---------------------------------------------------------------------------]]
local function nombreDe( ent, origen, i )
    -- El nombre NO sale de la entidad: `gmod_cameraprop` no tiene ninguno util
    -- y `point_camera` puede traer uno vacio. Se numera por origen, que es lo
    -- que el jugador puede verificar mirando el mundo.
    return ( origen == "map" and "MAP " or "CAM " ) .. string.format( "%02d", i )
end

local function rastrear()
    local quiero = cvSource:GetString()
    local out, porOrigen = {}, { tool = 0, map = 0 }

    for origen, clases in pairs( CLASES ) do
        if quiero == "all" or quiero == origen then
            for _, clase in ipairs( clases ) do
                for _, e in ipairs( ents.FindByClass( clase ) ) do
                    if IsValid( e ) then
                        porOrigen[ origen ] = porOrigen[ origen ] + 1
                        out[ #out + 1 ] = { ent = e, origen = origen,
                                            nombre = nombreDe( e, origen, porOrigen[ origen ] ) }
                    end
                end
            end
        end
    end

    -- Orden ESTABLE por EntIndex. Sin esto el orden depende de lo que devuelva
    -- `ents.FindByClass`, y la camara 2 podria ser otra en el cuadro siguiente:
    -- la lista se veria igual y estaria mirando a otro lado.
    table.sort( out, function( a, b ) return a.ent:EntIndex() < b.ent:EntIndex() end )

    ESTADO.cams = out
    ESTADO.porOrigen = porOrigen

    if ESTADO.sel > #out then ESTADO.sel = #out end
    if ESTADO.sel == 0 and #out > 0 then ESTADO.sel = 1 end
    return out
end

local function camSel()
    if ESTADO.tab ~= "cctv" then return nil end
    local c = ESTADO.cams[ ESTADO.sel ]
    if c and IsValid( c.ent ) then return c end
    return nil
end

--[[-------------------------------------------------------------------------
    RENDERIZAR

    `render.RenderView` no se puede llamar mientras el motor esta dibujando la
    escena: hay que hacerlo ANTES, en `PreRender`. Llamarlo desde el hook que
    dibuja el prop (`PreDrawOpaqueRenderables`, que es donde vive el resto de
    esta pantalla) deja la vista rota o directamente cuelga.
---------------------------------------------------------------------------]]
local function asegurarRT()
    if ESTADO.rt then return end

    --[[
        DOS COSAS QUE LA PRIMERA VERSION TENIA MAL, y el sintoma de las dos es
        el mismo: el visor sale NEGRO, sin un solo error en consola.

        1. `GetRenderTarget()` a secas crea un RT SIN BUFFER DE PROFUNDIDAD, y
           `render.RenderView` sobre eso no puede dibujar una escena 3D: no hay
           donde resolver que tapa a que. Hace falta `GetRenderTargetEx` con un
           depth propio (`MATERIAL_RT_DEPTH_SEPARATE`, porque el RT no mide lo
           mismo que la pantalla). Medido contra ARC9, cuya mira PiP hace
           exactamente esto y funciona:
           `Arc9 Base/lua/weapons/arc9_base/cl_pipscope_new.lua:15`.

        2. El `$basetexture` se declaraba con el nombre en texto y NO se hacia
           el `SetTexture`. El propio archivo de la pantalla lo hace
           (`ensureScreen`) y este no: la textura del RT nunca quedaba montada
           en el material. Van las dos formas —el nombre real del RT en la
           tabla y el SetTexture despues—, que es lo que hacen los dos ejemplos
           que sabemos que andan.

        Los flags `bit.bor(4,8,256,512)` son los de ARC9: sin filtrado de mip,
        sin filtrado anisotropico, clamp en S y en T. Un RT de camara no
        necesita mips y el clamp evita que el borde repita.
    ]]
    --[[
        EL NOMBRE VA VERSIONADO, y no es cosmético.

        `GetRenderTargetEx` y `CreateMaterial` CACHEAN POR NOMBRE en el motor:
        si ya existe uno con ese nombre, devuelven el viejo e **ignoran los
        parámetros nuevos**. El RT de la primera versión se creó con
        `GetRenderTarget()` —sin buffer de profundidad— y al arreglarlo en el
        mismo arranque de GMod la llamada seguía devolviendo aquel, así que el
        arreglo no podía tener efecto sin reiniciar el juego. El síntoma es
        exactamente el mismo que el defecto original: negro, sin error.

        Subir el sufijo obliga al motor a crear uno nuevo. Hay que subirlo cada
        vez que cambien el tamaño, el formato o el modo de profundidad.
    ]]
    local RT_NOMBRE = "phantasmagoria_cctv_feed_v2"

    ESTADO.rt = GetRenderTargetEx( RT_NOMBRE, CAM_W, CAM_H,
        RT_SIZE_LITERAL, MATERIAL_RT_DEPTH_SEPARATE,
        bit.bor( 4, 8, 256, 512 ), 0, IMAGE_FORMAT_RGB888 )

    ESTADO.mat = CreateMaterial( RT_NOMBRE .. "_mat", "UnlitGeneric", {
        ["$basetexture"] = ESTADO.rt:GetName(),
        -- Sin $model: este material NO se aplica a un modelo, se dibuja en 2D
        -- adentro de otro RT. El $model 1 que hizo falta para el material de la
        -- pantalla es para SetSubMaterial, que es otro caso.
        ["$nolod"]       = "1",
        ["$translucent"] = "0",
        ["$vertexcolor"] = "1",
    } )
    ESTADO.mat:SetTexture( "$basetexture", ESTADO.rt )
end

--[[
    LA VISION NOCTURNA.

    Copiada en forma del NVG de Neosun (`dev/other/[vmanip] neosun's cooler
    nightvision`, cl_arctic_nvg.lua:180-197): primero se desatura con un
    `DrawColorModify` de `$pp_colour_colour = 0`, y despues se tiñe y se sube el
    contraste. Los numeros son los de sus gafas verdes, con el add en verde.

    No es "parecido a": es el mismo mecanismo (`$pp_colour_*`) aplicado adentro
    del RenderTarget de la camara en vez de sobre la pantalla del jugador.
]]
-- Primera pasada: DESATURAR. `$pp_colour_colour = 0` deja la imagen en gris.
-- Neosun hace exactamente esto antes de teñir (cl_arctic_nvg.lua:180-192), y
-- saltearlo es lo que hacia que el NV se viera como "la imagen mas clara" en
-- vez de verde: teñir sin desaturar antes deja el color original debajo y lo
-- unico que se nota es la subida de brillo.
local NV_GRIS = {
    ["$pp_colour_addr"]       = 0,
    ["$pp_colour_addg"]       = 0,
    ["$pp_colour_addb"]       = 0,
    ["$pp_colour_brightness"] = 0,
    ["$pp_colour_contrast"]   = 1,
    ["$pp_colour_colour"]     = 0,
    ["$pp_colour_mulr"]       = 0,
    ["$pp_colour_mulg"]       = 0,
    ["$pp_colour_mulb"]       = 0,
}

-- Segunda pasada: teñir y levantar. Los valores son del orden de los de las
-- gafas verdes de Neosun. NO ESTAN MEDIDOS en juego todavia — la primera
-- version se veia lavada y esto es la correccion, no una medicion.
local NV_CC = {
    ["$pp_colour_addr"]       = -0.02,
    ["$pp_colour_addg"]       = 0.05,
    ["$pp_colour_addb"]       = -0.02,
    ["$pp_colour_brightness"] = 0.04,
    ["$pp_colour_contrast"]   = 2.2,
    ["$pp_colour_colour"]     = 1,
    ["$pp_colour_mulr"]       = 0,
    ["$pp_colour_mulg"]       = 0,
    ["$pp_colour_mulb"]       = 0,
}

local function renderCam( c )
    asegurarRT()
    local ent = c.ent
    local op, oy, orr = angOffset()
    local ang = ent:GetAngles()
    ang.p = ang.p + op
    ang.y = ang.y + oy + ( ESTADO.pan[ ent ] or 0 )
    ang.r = orr      -- una camara montada no rota sobre su eje salvo que se pida

    local fov = math.Clamp( FOV_BASE - ESTADO.zoom * ZOOM_STEP, 10, 120 )

    -- La relacion la manda la pagina (ph.viewrect). Si todavia no llego se usa
    -- la del RT, que es lo mas cercano: dibujar con una relacion inventada
    -- deforma la imagen y no hay nada en pantalla que lo diga.
    local ar = CAM_W / CAM_H
    if ESTADO.view and ESTADO.view.h > 0 then
        ar = ESTADO.view.w / ESTADO.view.h
    end

    --[[
        LA BANDERA, y el bicho que existe para tapar.

        `render.RenderView` dibuja una escena COMPLETA, y eso incluye disparar
        de nuevo los hooks de dibujado del mundo — entre ellos el
        `PreDrawOpaqueRenderables` desde el que se compone la pantalla del
        camion. O sea que MIENTRAS este RT esta activo, el juego vuelve a
        componer la pantalla y `DrawCctvFeed` intenta dibujar ESTE MISMO RT.

        Una textura no se puede leer mientras es el render target activo: el
        motor no da error, simplemente no dibuja nada. Y como la composicion de
        adentro es la ultima que corre antes de que el prop se dibuje, el visor
        queda negro — con el titulo y el timecode encima, porque esos no leen
        ninguna textura. Que es exactamente el sintoma.

        Con la bandera puesta, `DrawCctvFeed` se saltea entero: la pasada de
        adentro no dibuja y la del frame principal si. De paso ahorra componer
        la pantalla dos veces por cuadro.
    ]]
    ESTADO.renderizando = true
    ESTADO.dentro = ( ESTADO.dentro or 0 )

    render.PushRenderTarget( ESTADO.rt )
        render.Clear( 0, 0, 0, 255, true, true )
        render.RenderView( {
            origin        = ent:GetPos(),
            angles        = ang,
            x = 0, y = 0, w = CAM_W, h = CAM_H,
            fov           = fov,
            aspectratio   = ar,
            znear         = 4,
            zfar          = 32768,
            drawviewmodel = false,
            drawhud       = false,
            dopostprocess = false,
        } )
        if ESTADO.nv then
            cam.Start2D()
                DrawColorModify( NV_GRIS )   -- primero a gris
                DrawColorModify( NV_CC )     -- y recien ahi el verde
            cam.End2D()
        end

        --[[
            LA MARCA DE DIAGNOSTICO, y por que separa tres cosas y no dos.

            Un visor negro tiene tres causas posibles y a ojo se ven iguales:
              (a) el RT no llega a la pantalla   -> no se ve NI la marca
              (b) el RT llega pero RenderView no dibujo -> se ve la marca sobre
                  negro
              (c) todo anda y la camara mira a un lugar oscuro -> se ve la marca
                  sobre la escena

            La marca se dibuja DENTRO del RT y despues del RenderView, asi que
            si aparece prueba que el RT recibe dibujos y que el material lo
            muestra. Sin ella, (a) y (b) son indistinguibles y se termina
            arreglando la mitad equivocada.
        ]]
        if cvDebug:GetBool() then
            cam.Start2D()
                surface.SetDrawColor( 255, 0, 0, 255 )
                surface.DrawRect( 0, 0, 24, 24 )
                surface.DrawRect( CAM_W - 24, CAM_H - 24, 24, 24 )
                surface.SetDrawColor( 0, 255, 0, 255 )
                surface.DrawRect( CAM_W * 0.5 - 12, CAM_H * 0.5 - 2, 24, 4 )
                surface.DrawRect( CAM_W * 0.5 - 2, CAM_H * 0.5 - 12, 4, 24 )
            cam.End2D()
        end
    render.PopRenderTarget()

    ESTADO.renderizando = false
end

--[[-------------------------------------------------------------------------
    COMPONER: el feed y los dos textos que van encima

    Lo llama `DrawTruckTV` cuando el layout es `cctv`, ya adentro del
    `PushRenderTarget` de la pantalla y del `cam.Start2D()`.
---------------------------------------------------------------------------]]
surface.CreateFont( "PhCctvTitle", { font = "Bahnschrift", size = 30, weight = 700,
                                     extended = true } )
surface.CreateFont( "PhCctvTC",    { font = "Bahnschrift", size = 27, weight = 700,
                                     extended = true } )

local function timecode( seg )
    if seg < 0 then seg = 0 end
    local cs = math.floor( seg * 100 ) % 100
    local t  = math.floor( seg )
    return string.format( "%02d:%02d:%02d:%02d",
        math.floor( t / 3600 ), math.floor( t / 60 ) % 60, t % 60, cs )
end

function PHANTASMAGORIA.DrawCctvFeed( view )
    -- Sin rectangulo no se dibuja NADA. El rectangulo lo manda la pagina cuando
    -- se dibuja el layout; si todavia no llego, dibujar en (0,0) pondria el feed
    -- arriba a la izquierda tapando las pestañas, que se lee como un bug de
    -- posicion y en realidad es un bug de secuencia.
    if not view or view.w <= 0 or view.h <= 0 then return end

    -- Se guarda para que el render del proximo cuadro use la relacion REAL del
    -- visor. Un cuadro de desfase no se ve; una relacion inventada si.
    ESTADO.view = view

    -- Estamos DENTRO del RenderView de la camara: el RT que habria que dibujar
    -- es el target activo y no se puede leer. Ver el comentario de la bandera
    -- en renderCam. Se cuenta para poder decir si esto pasa de verdad y cuanto:
    -- `phantasmagoria_cctv info` lo imprime.
    if ESTADO.renderizando then
        ESTADO.dentro = ( ESTADO.dentro or 0 ) + 1
        return
    end
    ESTADO.fuera = ( ESTADO.fuera or 0 ) + 1

    --[[
        DOS COSAS SEPARADAS, porque hasta ahora estaban juntas y por eso el
        diagnostico se estanco. "El visor esta negro" puede ser:

          (i)  este bloque NO se ejecuta      -> `feedNo` sube y `feedSi` no
          (ii) se ejecuta y no pinta nada     -> `feedSi` sube igual

        Con un solo contador las dos se veian iguales. Y con el debug prendido
        se pinta ademas un rectangulo MAGENTA solido en el mismo rect y con las
        mismas coordenadas: si aparece el magenta y no la camara, el rect y el
        dibujado estan bien y lo que falla es la TEXTURA — que es un tercer caso
        distinto de los dos anteriores.
    ]]
    local c = camSel()
    if not ( c and ESTADO.rt and ESTADO.mat ) then
        ESTADO.feedNo = ( ESTADO.feedNo or 0 ) + 1
        ESTADO.feedMotivo = ( not c and "sin camara elegida" )
            or ( not ESTADO.rt and "ESTADO.rt es nil" )
            or "ESTADO.mat es nil"
    else
        ESTADO.feedSi = ( ESTADO.feedSi or 0 ) + 1

        if cvDebug:GetBool() then
            surface.SetDrawColor( 255, 0, 255, 255 )
            draw.NoTexture()
            surface.DrawRect( view.x, view.y, view.w, view.h )
        end

        --[[
            DOS CAMINOS PARA PINTAR EL MISMO RT, y el convar existe para que la
            corrida elija en vez de que yo adivine.

            `surface.DrawTexturedRect` es el que usa el resto de este addon y el
            que funciona en el HUD. Pero dibujar un RT DENTRO de otro RT no es
            el mismo caso, y `render.DrawTextureToScreenRect` toma la ITexture
            directo, sin pasar por el material ni por el estado de `surface`.

            Si con "render" se ve y con "surface" no, el problema es el camino
            de dibujo; si no se ve con ninguno, es la textura y hay que buscar
            en otro lado. Un convar convierte esa pregunta en UNA corrida.
        ]]
        if cvDraw:GetString() == "render" then
            --[[
                `render.DrawTextureToScreenRect` toma las coordenadas en
                espacio de PANTALLA (ScrW x ScrH) y las remapea al viewport del
                RenderTarget activo. O sea que pasarle el rect en pixeles del RT
                dibuja la imagen ESCALADA por RT/pantalla: con 1024x593 sobre
                1920x1080 el feed salio 367x244 en vez de 688x445 y corrido
                arriba-izquierda, tapando media pestaña. Medido contra la
                captura: los numeros dan.

                Se premultiplica por pantalla/RT para deshacerlo. El tamaño del
                RT se MIDE (`render.GetRenderTarget()`), no se escribe: la
                pantalla es 1024x593 hoy y eso es una consecuencia del modelo,
                no una constante de este archivo.
            ]]
            local rt = render.GetRenderTarget()
            local vw = rt and rt:Width()  or ScrW()
            local vh = rt and rt:Height() or ScrH()
            local fx, fy = ScrW() / math.max( vw, 1 ), ScrH() / math.max( vh, 1 )
            render.DrawTextureToScreenRect( ESTADO.rt,
                view.x * fx, view.y * fy, view.w * fx, view.h * fy )
        else
            surface.SetDrawColor( 255, 255, 255, 255 )
            surface.SetMaterial( ESTADO.mat )
            surface.DrawTexturedRect( view.x, view.y, view.w, view.h )
        end
    end

    -- El titulo va SIEMPRE que haya camara elegida, con o sin imagen: dice cual
    -- esta seleccionada y eso sigue siendo cierto sin señal.
    if c then
        local n = ESTADO.sel
        draw.SimpleText( string.format( "%s %02d / %02d", c.nombre, n, #ESTADO.cams ),
            "PhCctvTitle", view.x + 14, view.y + 10, Color( 245, 197, 24 ) )
    end

    -- El timecode corre SIEMPRE, como el `StopWatch` del juego.
    draw.SimpleText( timecode( CurTime() - ESTADO.t0 ), "PhCctvTC",
        view.x + view.w - 14, view.y + view.h - 37, Color( 245, 197, 24 ),
        TEXT_ALIGN_RIGHT )
end

--[[-------------------------------------------------------------------------
    LO QUE VE LA PAGINA
---------------------------------------------------------------------------]]
local function empujar()
    local d = PHANTASMAGORIA.TruckData
    if not d then return end

    local lista = {}
    if ESTADO.tab == "cctv" then
        local base = ( ESTADO.page - 1 ) * POR_PAGINA
        for i = 1, POR_PAGINA do
            local c = ESTADO.cams[ base + i ]
            if c then
                lista[ #lista + 1 ] = { name = c.nombre, selected = ( base + i ) == ESTADO.sel }
            end
        end
    end

    d.cctv = {
        tab      = ESTADO.tab,
        live     = camSel() ~= nil,
        rec      = ESTADO.rec,
        nv       = ESTADO.nv,
        cameras  = lista,
        page     = ESTADO.page,
        pages    = math.max( math.ceil( #ESTADO.cams / POR_PAGINA ), 1 ),
    }
    if PHANTASMAGORIA.PushTruckTVData then
        PHANTASMAGORIA.PushTruckTVData( "cctv" )
    end
end

--[[-------------------------------------------------------------------------
    LOS CLICKS

    Los engancha `phantasmagoria_trucktv_screen.lua` por este nombre. Cada
    accion cambia estado y vuelve a empujar: la pagina NO decide nada sola, asi
    que lo que se dibuja siempre es lo que el mod cree.
---------------------------------------------------------------------------]]
function PHANTASMAGORIA.TruckTVCctvInput( _layout, que, valor )
    if que == "tab" then
        ESTADO.tab = valor
        ESTADO.page = 1

    elseif que == "cam" then
        -- `valor` es el indice de CELDA (0..3), no el de camara: hay que sumarle
        -- la pagina. Tomarlo directo funcionaria en la pagina 1 y elegiria la
        -- camara equivocada en la 2, que es el tipo de error que solo aparece
        -- cuando hay suficientes camaras.
        local celda = tonumber( valor ) or 0
        local idx = ( ESTADO.page - 1 ) * POR_PAGINA + celda + 1
        if ESTADO.cams[ idx ] then ESTADO.sel = idx end

    elseif que == "act" then
        if valor == "rec" then
            ESTADO.rec = not ESTADO.rec
        elseif valor == "nv" then
            ESTADO.nv = not ESTADO.nv
        elseif valor == "zoom+" then
            ESTADO.zoom = math.Clamp( ESTADO.zoom + 1, 0, ZOOM_MAX )
        elseif valor == "zoom-" then
            ESTADO.zoom = math.Clamp( ESTADO.zoom - 1, 0, ZOOM_MAX )
        elseif valor == "pan-" or valor == "pan+" then
            local c = camSel()
            if c then
                local d = ( valor == "pan+" ) and PAN_STEP or -PAN_STEP
                ESTADO.pan[ c.ent ] = ( ESTADO.pan[ c.ent ] or 0 ) + d
            end
        elseif valor == "page-" then
            ESTADO.page = math.max( ESTADO.page - 1, 1 )
        elseif valor == "page+" then
            local pages = math.max( math.ceil( #ESTADO.cams / POR_PAGINA ), 1 )
            ESTADO.page = math.min( ESTADO.page + 1, pages )
        end
    end

    empujar()
end

--[[-------------------------------------------------------------------------
    EL LATIDO
---------------------------------------------------------------------------]]
ESTADO.t0 = 0

hook.Add( "InitPostEntity", "phantasmagoria_cctv_init", function()
    ESTADO.t0 = CurTime()
    rastrear()
    empujar()
end )

hook.Add( "PreRender", "phantasmagoria_cctv_render", function()
    -- Rastrear cuesta un FindByClass por clase: a 60 Hz seria gratis igual,
    -- pero una vez por segundo alcanza y deja el presupuesto para el render.
    if CurTime() - ESTADO.ultimo > 1 then
        ESTADO.ultimo = CurTime()
        local antes = #ESTADO.cams
        rastrear()
        if #ESTADO.cams ~= antes then empujar() end
    end

    -- El RenderView va ACA y no en el hook que dibuja el prop: el motor no
    -- deja abrir una vista adentro de la que ya esta dibujando.
    local c = camSel()
    if c then renderCam( c ) end
end )

--[[-------------------------------------------------------------------------
    EL RT EN EL HUD

    Dibujarlo aca, fuera de la pantalla del camion, es lo que separa el problema
    en dos mitades: si en el HUD se ve la imagen y en el prop no, el RenderView
    anda y lo que falla es la composicion sobre el RT de la pantalla; si en el
    HUD tambien esta negro, el problema es de la camara y no de la pantalla.
---------------------------------------------------------------------------]]
hook.Add( "HUDPaint", "phantasmagoria_cctv_debug", function()
    if not cvDebug:GetBool() or not ESTADO.rt or not ESTADO.mat then return end
    local w, h = 320, 200
    local x, y = 16, 16

    surface.SetDrawColor( 255, 255, 255, 255 )
    surface.SetMaterial( ESTADO.mat )
    surface.DrawTexturedRect( x, y, w, h )

    surface.SetDrawColor( 255, 255, 0, 255 )
    surface.DrawOutlinedRect( x, y, w, h )

    local c = camSel()
    draw.SimpleText(
        c and ( c.nombre .. "  " .. tostring( c.ent ) ) or "SIN CAMARA ELEGIDA",
        "DermaDefault", x, y + h + 4, Color( 255, 255, 0 ) )
    draw.SimpleText(
        "rojo en 2 esquinas + cruz verde = el RT recibe dibujos y el material lo muestra",
        "DermaDefault", x, y + h + 20, Color( 200, 200, 200 ) )
end )

--[[-------------------------------------------------------------------------
    DIAGNOSTICO

    `info` imprime cuantas camaras encontro DE CADA ORIGEN. Sin eso, una lista
    vacia no se distingue de una busqueda que no encontro nada porque la clase
    no existe del lado cliente — que es un riesgo real con `point_camera`.
---------------------------------------------------------------------------]]
concommand.Add( "phantasmagoria_cctv", function( _, _, args )
    local sub = ( args[ 1 ] or "info" ):lower()

    if sub == "info" then
        rastrear()
        MsgC( Color( 160, 190, 200 ), "[Phantasmagoria] CCTV\n" )
        MsgC( Color( 200, 200, 200 ), "  origen (convar) : " .. cvSource:GetString() .. "\n" )
        for origen, clases in pairs( CLASES ) do
            local n = ( ESTADO.porOrigen or {} )[ origen ] or 0
            MsgC( Color( 200, 200, 200 ), string.format( "  %-5s (%s) : %d\n",
                origen, table.concat( clases, ", " ), n ) )
        end
        MsgC( Color( 200, 200, 200 ), "  en la lista     : " .. #ESTADO.cams ..
            "   seleccionada: " .. ESTADO.sel ..
            "   pagina: " .. ESTADO.page .. "\n" )
        MsgC( Color( 200, 200, 200 ), "  rec: " .. tostring( ESTADO.rec ) ..
            "   nv: " .. tostring( ESTADO.nv ) ..
            "   zoom: " .. ESTADO.zoom .. "\n" )
        local op, oy, orr = angOffset()
        MsgC( Color( 200, 200, 200 ), string.format(
            "  offset ang     : %g %g %g   RT: %dx%d\n", op, oy, orr, CAM_W, CAM_H ) )
        --[[
            LA MEDICION QUE CONFIRMA (o refuta) LA CAUSA DEL VISOR NEGRO.

            `dentro` cuenta las veces que la pantalla se compuso MIENTRAS el RT
            de la camara estaba activo — o sea, adentro del RenderView, donde
            ese RT no se puede leer. Si `dentro` es > 0, esa era la causa. Si es
            0 y el visor sigue negro, la causa es otra y hay que buscar en otro
            lado en vez de dar por bueno el arreglo.
        ]]
        MsgC( Color( 200, 200, 200 ), string.format(
            "  composiciones   : %d fuera del RenderView, %d ADENTRO (esas no dibujan el feed)\n",
            ESTADO.fuera or 0, ESTADO.dentro or 0 ) )
        MsgC( Color( 200, 200, 200 ), string.format(
            "  dibujo del feed : %d veces SI, %d veces NO%s\n",
            ESTADO.feedSi or 0, ESTADO.feedNo or 0,
            ESTADO.feedMotivo and ( "  (ultimo motivo: " .. ESTADO.feedMotivo .. ")" ) or "" ) )
        MsgC( Color( 200, 200, 200 ),
            "  camino dibujo   : " .. cvDraw:GetString() ..
            "   (phantasmagoria_cctv_draw render|surface)\n" )
        MsgC( Color( 200, 200, 200 ), string.format(
            "  RT / material   : rt=%s  mat=%s%s\n",
            ESTADO.rt and "ok" or "NIL",
            ESTADO.mat and "ok" or "NIL",
            ( ESTADO.mat and ESTADO.mat.IsError and ESTADO.mat:IsError() )
                and "  <-- MATERIAL DE ERROR" or "" ) )
        MsgC( Color( 200, 200, 200 ), "  visor (px)      : " ..
            ( ESTADO.view and string.format( "%d,%d  %dx%d",
                ESTADO.view.x, ESTADO.view.y, ESTADO.view.w, ESTADO.view.h )
              or "AUN NO LLEGO de la pagina" ) .. "\n" )
        -- La POSICION y el ANGULO de cada camara, que es lo unico que permite
        -- separar "la camara mira a una pared" de "la entidad no esta donde
        -- creo". Una `point_camera` que no se replique bien al cliente da
        -- (0,0,0) y renderizaria desde el origen del mapa — que en pantalla se
        -- ve como una imagen rara, no como un error.
        for i, c in ipairs( ESTADO.cams ) do
            local p, a = c.ent:GetPos(), c.ent:GetAngles()
            MsgC( Color( 150, 170, 175 ), string.format(
                "   %2d  %-8s %-6s  pos(%.0f %.0f %.0f)  ang(%.0f %.0f %.0f)  %s\n",
                i, c.nombre, c.origen, p.x, p.y, p.z, a.p, a.y, a.r, tostring( c.ent ) ) )
        end

    elseif sub == "next" then
        if #ESTADO.cams > 0 then
            ESTADO.sel = ( ESTADO.sel % #ESTADO.cams ) + 1
            empujar()
        end

    elseif sub == "nv" or sub == "rec" then
        PHANTASMAGORIA.TruckTVCctvInput( "cctv", "act", sub )

    elseif sub == "debug" then
        RunConsoleCommand( "phantasmagoria_cctv_debug",
            cvDebug:GetBool() and "0" or "1" )
        MsgC( Color( 160, 190, 200 ), "[Phantasmagoria] CCTV debug -> " ..
            ( cvDebug:GetBool() and "OFF" or "ON" ) .. "\n" )
        MsgC( Color( 200, 200, 200 ),
            "  Que mirar en el recuadro del HUD:\n" ..
            "    ni marcas ni imagen  -> el RT no llega a la pantalla (material)\n" ..
            "    marcas sobre negro   -> el RT llega y RenderView no dibujo\n" ..
            "    marcas sobre escena  -> anda; si el prop igual esta negro, falla\n" ..
            "                            la composicion sobre el RT de la pantalla\n" )

    else
        MsgC( Color( 200, 200, 200 ),
            "uso: phantasmagoria_cctv [info|next|nv|rec|debug]\n" )
    end
end )
