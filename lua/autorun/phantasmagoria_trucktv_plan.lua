--[[-------------------------------------------------------------------------
    Phantasmagoria - el plano del sitio para los monitores del camion

    POR QUE ESTE ARCHIVO EXISTE, Y POR QUE ES COMPARTIDO

    **La biblioteca `navmesh` de Garry's Mod es SOLO DE SERVIDOR.** En el
    cliente `navmesh` no existe, y llamar `navmesh.IsLoaded()` desde ahi tira
    *attempted to index nil with key 'IsLoaded'*. La pantalla de la TV se dibuja
    en el CLIENTE (RenderTarget + panel HTML), asi que el plano no se puede
    armar donde se dibuja: **lo arma el servidor y viaja por red.**

    Eso no salio de leer la documentacion: salio del juego. La primera version
    tenia `BuildSitePlan` adentro del archivo de cliente y moria en la primera
    llamada. Un arnes que stubbea `navmesh` en un solo realm no podia agarrarlo
    — el stub existia en los dos, que es justamente la diferencia que importaba.

    QUE HACE
      SERVIDOR : arma el plano una vez por mapa y lo cachea; responde pedidos
                 por piso, comprimido y en pedazos.
      CLIENTE  : pide, arma de vuelta, cachea por piso y avisa por callback.

    Nada de esto se dispara solo: el cliente pide cuando alguien monta el layout
    del mapa.
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

local MSG = "phantasmagoria_trucktv_plan"

--[[-------------------------------------------------------------------------
    SEPARAR PISOS

    La primera version ordenaba las areas por Z y cortaba donde dos consecutivas
    se separaban mas de 140 unidades. **Una escalera llena ese hueco**: el
    navmesh de una escalera es una rampa continua, asi que la lista ordenada no
    tiene ningun corte y el mapa entero colapsa a un solo "piso" con los niveles
    dibujados uno encima del otro. No da error: da un plano mas cargado.

    Medido sobre .nav de verdad (`dev/phastools/navfloors.py`):

        ttt_csgobank     hueco -> 1 piso   picos -> 2, 90 % de solape
        gm_terminal_v1a  hueco -> 1 piso   picos -> 3, 74 % de solape
        gm_suppression   hueco -> 1 piso   picos -> 5, 89 % de solape
        gm_construct     hueco -> 6 pisos  pero ninguno apilado: es terreno

    Fallaba en las dos direcciones. Lo que lo arregla, en tres pasos:

    1. HISTOGRAMA DE Z PESADO POR SUPERFICIE. Un piso es una masa de suelo a una
       altura; una escalera es un hilo repartido entre dos. Pesar por superficie
       hace que la escalera no forme pico. Contar areas no alcanza: una escalera
       tiene muchas areas chiquitas.
    2. PICOS SEPARADOS AL MENOS POR UN JUGADOR (72 u + margen).
    3. **EL SOLAPE EN XY.** El eje Z solo no puede contestar la pregunta: dos
       masas a distinta altura son dos pisos si se tapan mirando desde arriba, y
       son el mismo nivel si estan una al lado de la otra. Sin esto,
       gm_construct da 15 "pisos" que son la colina, la pileta y las rampas.

    Y una cuarta que no cambia cuantos pisos hay pero rompe todo lo demas: la
    caja de normalizacion es GLOBAL. Con una caja por piso, cambiar de piso
    reescala el plano y los pisos dejan de estar registrados entre si.
---------------------------------------------------------------------------]]
local FLOOR_BIN     = 16        -- ancho del bin del histograma, en unidades
local FLOOR_MIN_SEP = 96        -- 72 (alto del jugador) + margen
local FLOOR_MIN_W   = 0.01      -- un pico tiene que pesar al menos el 1 %
local STACK_MIN     = 0.25      -- solape XY para llamarlo "otro piso"
local MAX_AREAS     = 4000      -- tope duro por piso; si recorta, AVISA
local AREA_MIN      = 300       -- u2: menos que esto es astilla del navmesh

-- Celda del test de solape. **64 y no 128**: una celda gruesa INFLA el solape,
-- porque dos regiones que no se tocan pueden caer en la misma celda. Con 128 el
-- Lua daba 5 pisos en gm_suppression y la implementacion de referencia en
-- Python daba 4 — o sea que no eran el mismo algoritmo. 64 es del ancho de un
-- jugador, que es la escala a la que "estan uno encima del otro" significa algo.
local CELL = 64

local function cellSet( grupo )
    local s, n = {}, 0
    for _, q in ipairs( grupo ) do
        for cx = math.floor( q[ 1 ] / CELL ), math.floor( q[ 3 ] / CELL ) do
        for cy = math.floor( q[ 2 ] / CELL ), math.floor( q[ 4 ] / CELL ) do
            local k = cx .. "," .. cy
            if not s[ k ] then s[ k ] = true; n = n + 1 end
        end
        end
    end
    return s, n
end

local function overlapFrac( g1, g2 )
    local s1, n1 = cellSet( g1 )
    local s2, n2 = cellSet( g2 )
    if n1 == 0 or n2 == 0 then return 0 end
    local hit = 0
    for k in pairs( s1 ) do if s2[ k ] then hit = hit + 1 end end
    return hit / math.min( n1, n2 )
end

--[[
    Arma el plano completo, con TODOS los pisos. Devuelve nil y un MOTIVO cuando
    no se puede: el motivo importa, porque "este mapa no tiene navmesh" y "el
    navmesh existe y esta vacio" se arreglan distinto y se ven igual.

    `refZ` fija cual es la planta baja. El navmesh NO lo sabe y no puede saberlo
    — son alturas, no semantica —, asi que hace falta una referencia externa. La
    que usamos es la altura del jugador que pidio el plano.
]]
function PHANTASMAGORIA.BuildSitePlan( refZ )
    if not navmesh then
        return nil, "la biblioteca navmesh no existe en este realm (es solo de servidor)"
    end
    --[[
        "No esta cargado" NO quiere decir "no existe".

        El mensaje anterior decia "este mapa no tiene navmesh (probar
        nav_generate)" y mandaba a generar uno sobre un mapa del Workshop que
        traia el suyo hecho a mano. `navmesh.IsLoaded()` contesta si el motor lo
        tiene en memoria, y eso no es lo mismo que si el archivo esta en el
        disco: hay mapas donde el .nav esta y Garry's Mod no lo levanta solo.

        Asi que antes de rendirse hay que INTENTAR cargarlo, y despues separar
        los tres estados, que piden tres cosas distintas del usuario:
          - no existe el archivo         -> nav_generate
          - existe y Load() no lo levanta -> el archivo esta roto o es de otra version
          - carga y no tiene areas        -> el navmesh esta vacio
    ]]
    if not navmesh.IsLoaded() then
        local ruta = "maps/" .. game.GetMap() .. ".nav"
        if not file.Exists( ruta, "GAME" ) then
            return nil, "este mapa no trae " .. ruta .. " (probar nav_generate)"
        end
        navmesh.Load()
        if not navmesh.IsLoaded() then
            return nil, string.format( "%s existe (%d bytes) pero navmesh.Load() no lo cargo",
                ruta, file.Size( ruta, "GAME" ) or -1 )
        end
    end
    local areas = navmesh.GetAllNavAreas()
    if not areas or #areas == 0 then
        return nil, "el navmesh esta cargado y no tiene areas"
    end

    local A = {}
    for _, a in ipairs( areas ) do
        if IsValid( a ) then
            local nw, se = a:GetCorner( 0 ), a:GetCorner( 2 )
            local x0, x1 = math.min( nw.x, se.x ), math.max( nw.x, se.x )
            local y0, y1 = math.min( nw.y, se.y ), math.max( nw.y, se.y )
            A[ #A + 1 ] = { x0, y0, x1, y1, a:GetCenter().z, ( x1 - x0 ) * ( y1 - y0 ) }
        end
    end
    if #A == 0 then return nil, "el navmesh no devolvio areas validas" end

    -- 1. histograma pesado por superficie
    local zmin, zmax = math.huge, -math.huge
    for _, q in ipairs( A ) do
        zmin, zmax = math.min( zmin, q[ 5 ] ), math.max( zmax, q[ 5 ] )
    end
    local nb = math.max( 1, math.floor( ( zmax - zmin ) / FLOOR_BIN ) + 1 )
    local hist, total = {}, 0
    for i = 1, nb do hist[ i ] = 0 end
    for _, q in ipairs( A ) do
        local i = math.floor( ( q[ 5 ] - zmin ) / FLOOR_BIN ) + 1
        hist[ i ] = hist[ i ] + q[ 6 ]
        total = total + q[ 6 ]
    end

    -- 2. picos, y fusion de los que quedan a menos de un jugador
    local picos = {}
    for i = 1, nb do
        if hist[ i ] > 0 and hist[ i ] / total > FLOOR_MIN_W then
            local esMax = true
            for j = math.max( 1, i - 3 ), math.min( nb, i + 3 ) do
                if hist[ j ] > hist[ i ] then esMax = false break end
            end
            if esMax then picos[ #picos + 1 ] = { zmin + ( i - 0.5 ) * FLOOR_BIN, hist[ i ] } end
        end
    end
    if #picos == 0 then picos[ 1 ] = { ( zmin + zmax ) * 0.5, total } end

    local fus = { picos[ 1 ] }
    for i = 2, #picos do
        if picos[ i ][ 1 ] - fus[ #fus ][ 1 ] < FLOOR_MIN_SEP then
            if picos[ i ][ 2 ] > fus[ #fus ][ 2 ] then fus[ #fus ] = picos[ i ] end
        else
            fus[ #fus + 1 ] = picos[ i ]
        end
    end

    local grupos = {}
    for i = 1, #fus do grupos[ i ] = {} end
    for _, q in ipairs( A ) do
        local best, bd = 1, math.huge
        for i, p in ipairs( fus ) do
            local d = math.abs( p[ 1 ] - q[ 5 ] )
            if d < bd then best, bd = i, d end
        end
        table.insert( grupos[ best ], q )
    end

    -- 3. fusionar los consecutivos que NO se tapan: mismo nivel, otra altura
    local i = 1
    while i < #grupos do
        if overlapFrac( grupos[ i ], grupos[ i + 1 ] ) < STACK_MIN then
            for _, q in ipairs( grupos[ i + 1 ] ) do table.insert( grupos[ i ], q ) end
            table.remove( grupos, i + 1 )
            table.remove( fus, i + 1 )
        else
            i = i + 1
        end
    end

    -- 4. caja GLOBAL
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, q in ipairs( A ) do
        x0, y0 = math.min( x0, q[ 1 ] ), math.min( y0, q[ 2 ] )
        x1, y1 = math.max( x1, q[ 3 ] ), math.max( y1, q[ 4 ] )
    end
    local sx, sy = x1 - x0, y1 - y0
    if sx <= 0 or sy <= 0 then return nil, "el navmesh no tiene extension en XY" end

    local ground = 1
    if refZ then
        local bd = math.huge
        for k, p in ipairs( fus ) do
            local d = math.abs( p[ 1 ] - refZ )
            if d < bd then ground, bd = k, d end
        end
    end

    -- a [0,1]. La Y del mundo se invierte: en Source +Y es el norte y en una
    -- pantalla el norte va arriba, o sea hacia y menor.
    local pisos, recortadas = {}, 0
    for k, g in ipairs( grupos ) do
        if #g > MAX_AREAS then
            recortadas = recortadas + ( #g - MAX_AREAS )
            for j = #g, MAX_AREAS + 1, -1 do g[ j ] = nil end
        end
        --[[
            EL FILTRO DE RUIDO VA ACA Y NO ARRIBA, y la diferencia importa.

            El navmesh parte los bordes en astillas de pocas unidades. Dibujadas
            se ven como suciedad; sumadas al histograma de alturas, en cambio,
            son informacion buena. Asi que se descartan al EMITIR y no al medir:
            la separacion de pisos sigue viendo el navmesh entero.

            (Y hay una segunda razon, de metodo: `navlua_check.py` compara esta
            separacion contra la implementacion de referencia en Python. Filtrar
            antes del histograma habria hecho divergir las dos por un cambio que
            no tiene nada que ver con separar pisos.)

            El umbral sale del mod 3D Minimap (`sv_minimap_minareasize`, 300 u2),
            que llego a lo mismo por su cuenta.
        ]]
        local out, sucias = {}, 0
        for _, q in ipairs( g ) do
            if ( q[ 3 ] - q[ 1 ] ) * ( q[ 4 ] - q[ 2 ] ) < AREA_MIN then
                sucias = sucias + 1
            else
                out[ #out + 1 ] = {
                    math.Round( ( q[ 1 ] - x0 ) / sx, 4 ),
                    math.Round( ( y1 - q[ 4 ] ) / sy, 4 ),
                    math.Round( ( q[ 3 ] - q[ 1 ] ) / sx, 4 ),
                    math.Round( ( q[ 4 ] - q[ 2 ] ) / sy, 4 ),
                }
            end
        end
        pisos[ k ] = { areas = out, z = fus[ k ][ 1 ], sucias = sucias }
    end

    return {
        pisos  = pisos,
        ar     = sx / sy,
        bounds = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 },
        ground = ground,
        recortadas = recortadas,
    }
end

-- Pasa una posicion del mundo a coordenadas [0,1] del plano. La caja es global,
-- asi que vale para cualquier piso: es lo que los mantiene registrados.
function PHANTASMAGORIA.WorldToPlan( plan, pos )
    local b = plan.bounds
    return ( pos.x - b.x0 ) / ( b.x1 - b.x0 ), ( b.y1 - pos.y ) / ( b.y1 - b.y0 )
end

function PHANTASMAGORIA.FloorOf( plan, z )
    local best, bd = 1, math.huge
    for k, p in ipairs( plan.pisos ) do
        local d = math.abs( p.z - z )
        if d < bd then best, bd = k, d end
    end
    return best
end

--[[-------------------------------------------------------------------------
    LAS PAREDES

    **El navmesh no tiene paredes.** Es superficie caminable, y adentro de una
    casa las areas de dos habitaciones se TOCAN a traves de la puerta, asi que
    el plano sale como una mancha continua y no se ve donde termina un cuarto.
    Eso no se arregla dibujando distinto: el dato no esta.

    De donde sale entonces. Se muestrea una grilla sobre la caja del plano, a
    una altura fija por encima del piso, y se pregunta si ese punto esta adentro
    de geometria solida. Lo que queda marcado es la PLANTA del edificio.

    POR QUE `util.PointContents` Y NO UN TRACE. PointContents contesta por los
    brushes del BSP, que es de lo que estan hechas las paredes; los props son
    los muebles. Un trace con MASK_SOLID marcaria tambien cada silla, y el mapa
    de Phasmophobia muestra la PLANTA, no el amoblamiento. Ademas es mucho mas
    barato, que con decenas de miles de celdas no es un detalle.
    Si algun mapa tiene las paredes hechas con props, esto va a devolver casi
    cero solidas — por eso el porcentaje se INFORMA en vez de asumirse, y hay un
    convar para pasar a traces.

    LA ALTURA IMPORTA. Se muestrea a 50 unidades sobre el piso: por encima de la
    base de los muebles y por debajo de casi cualquier techo. Al ras del suelo,
    cada escalon y cada zocalo saldrian de pared.

    Y LA FILA j VA CON LA V DEL PLANO, o sea con la Y del mundo INVERTIDA, igual
    que las areas. Si se emitiera en el orden natural del mundo, las paredes
    saldrian espejadas verticalmente respecto del piso que tienen que tapar —
    y espejado se ve plausible, que es lo peor que puede verse.
---------------------------------------------------------------------------]]
local WALL_CELLS_MAX = 45000        -- tope de celdas por piso
local WALL_CELL_MIN  = 8            -- unidades por celda; medio jugador
local WALL_H         = 50           -- altura de muestreo sobre el piso

function PHANTASMAGORIA.BuildWalls( plan, floor )
    if not plan or not plan.bounds then return nil, "sin plano" end
    local piso = plan.pisos and plan.pisos[ floor ]
    if not piso then return nil, "ese piso no existe" end

    local b = plan.bounds
    local sx, sy = b.x1 - b.x0, b.y1 - b.y0
    if sx <= 0 or sy <= 0 then return nil, "la caja del plano esta vacia" end

    local cell = math.max( WALL_CELL_MIN, math.sqrt( sx * sy / WALL_CELLS_MAX ) )
    local w    = math.ceil( sx / cell )
    local h    = math.ceil( sy / cell )
    local z    = piso.z + WALL_H

    local trazar = GetConVar( "phantasmagoria_trucktv_walltrace" )
    trazar = trazar and trazar:GetBool() or false

    local t0 = SysTime()
    local rle, corrida, actual, solidas = {}, 0, false, 0
    local p = Vector( 0, 0, z )

    for j = 0, h - 1 do
        -- y1 - ... : la fila 0 es el BORDE SUPERIOR del plano dibujado
        p.y = b.y1 - ( j + 0.5 ) * cell
        for i = 0, w - 1 do
            p.x = b.x0 + ( i + 0.5 ) * cell

            local solido
            if trazar then
                solido = util.TraceLine( {
                    start = p, endpos = p, mask = MASK_SOLID } ).StartSolid or false
            else
                solido = bit.band( util.PointContents( p ), CONTENTS_SOLID ) ~= 0
            end

            if solido then solidas = solidas + 1 end
            if solido == actual then
                corrida = corrida + 1
            else
                rle[ #rle + 1 ] = corrida
                corrida, actual = 1, solido
            end
        end
    end
    rle[ #rle + 1 ] = corrida

    return {
        w = w, h = h,
        rle = rle,
        -- para el volcado en consola: sin esto, "las paredes no se ven" no se
        -- puede separar de "no habia ninguna pared que ver"
        pct = math.Round( solidas / ( w * h ) * 100, 1 ),
        ms  = math.Round( ( SysTime() - t0 ) * 1000, 1 ),
        modo = trazar and "trace" or "brushes",
    }
end

--[[-------------------------------------------------------------------------
    EL TRANSPORTE

    Un piso de un mapa mediano son ~1.100 rectangulos, o sea unos 35 KB de JSON.
    Un mensaje de red de Garry's Mod no puede pasar de 64 KB, asi que va
    comprimido y **en pedazos**: el tope no es una recomendacion, y un plano que
    entra hoy y no entra en el mapa siguiente seria un fallo que aparece en un
    mapa y no en otro.
---------------------------------------------------------------------------]]
local CHUNK = 30000

if SERVER then
    util.AddNetworkString( MSG )

    -- Server-side: quien decide como se miden las paredes es el que las mide.
    CreateConVar( "phantasmagoria_trucktv_walltrace", "0", FCVAR_ARCHIVE,
        "0 = las paredes salen de los brushes del BSP; 1 = de traces, que ademas marcan props" )

    local cache        -- el plano, armado una vez por mapa
    local cacheMap
    local cacheMuros = {}   -- las paredes, una vez por piso: son caras de armar

    --[[
        phantasmagoria_trucktv_nav

        El monitor del mapa dice "SIN SEÑAL" y un motivo, pero el motivo llega
        despues de que el servidor ya decidio. Esto imprime los hechos crudos,
        del lado donde `navmesh` existe, para poder discutir con datos y no con
        el cartel: si el archivo esta o no, cuanto pesa, si el motor lo tiene
        cargado y cuantas areas ve.
    ]]
    concommand.Add( "phantasmagoria_trucktv_nav", function( ply )
        local function di( s )
            MsgC( Color( 200, 220, 220 ), s .. "\n" )
            if IsValid( ply ) then ply:PrintMessage( HUD_PRINTCONSOLE, s ) end
        end

        local ruta = "maps/" .. game.GetMap() .. ".nav"
        di( "[Phantasmagoria] navmesh de " .. game.GetMap() )
        di( string.format( "   %s : %s", ruta,
            file.Exists( ruta, "GAME" )
                and string.format( "existe, %d bytes", file.Size( ruta, "GAME" ) or -1 )
                or "NO EXISTE" ) )
        di( "   navmesh.IsLoaded() = " .. tostring( navmesh.IsLoaded() ) )
        if not navmesh.IsLoaded() and file.Exists( ruta, "GAME" ) then
            navmesh.Load()
            di( "   despues de navmesh.Load(): " .. tostring( navmesh.IsLoaded() ) )
        end
        local a = navmesh.IsLoaded() and navmesh.GetAllNavAreas() or nil
        di( "   areas = " .. ( a and #a or 0 ) )

        cache, cacheMap, cacheMuros = nil, nil, {}   -- que el proximo pedido rearme
        local plan, motivo = PHANTASMAGORIA.BuildSitePlan( IsValid( ply ) and ply:GetPos().z or nil )
        if not plan then
            di( "   BuildSitePlan -> nil: " .. tostring( motivo ) )
        else
            di( string.format( "   BuildSitePlan -> %d piso(s), planta baja %d, %d recortadas",
                #plan.pisos, plan.ground, plan.recortadas ) )
            for k, p in ipairs( plan.pisos ) do
                di( string.format( "      piso %d   z=%9.1f   %d areas", k, p.z, #p.areas ) )
            end
        end
    end, nil, "Imprime el estado del navmesh y del plano del sitio (servidor)" )

    net.Receive( MSG, function( _, ply )
        local floor = net.ReadUInt( 8 )

        if cacheMap ~= game.GetMap() then cache, cacheMap, cacheMuros = nil, game.GetMap(), {} end
        if not cache then
            local plan, motivo = PHANTASMAGORIA.BuildSitePlan( ply:GetPos().z )
            if not plan then
                net.Start( MSG )
                    net.WriteUInt( 2, 4 )                  -- 2 = error
                    net.WriteString( motivo or "sin plano" )
                net.Send( ply )
                return
            end
            cache = plan
        end

        local n = #cache.pisos
        floor = math.Clamp( floor > 0 and floor or cache.ground, 1, n )

        -- EL PAYLOAD LLEVA DOS COSAS. Antes era el array de areas pelado; ahora
        -- va { a = areas, w = muros } por el MISMO canal, porque partirlo en dos
        -- mensajes seria tener dos ensamblados que se pueden desincronizar y un
        -- estado intermedio (piso nuevo, paredes viejas) que se ve plausible.
        local muros = cacheMuros[ floor ]
        if muros == nil then
            muros = PHANTASMAGORIA.BuildWalls( cache, floor ) or false
            cacheMuros[ floor ] = muros
        end
        local datos  = util.Compress( util.TableToJSON( {
            a = cache.pisos[ floor ].areas,
            w = muros or nil,
        } ) )
        local trozos = math.max( 1, math.ceil( #datos / CHUNK ) )

        net.Start( MSG )
            net.WriteUInt( 0, 4 )                          -- 0 = cabecera
            net.WriteFloat( cache.ar )
            net.WriteUInt( n, 8 )
            net.WriteUInt( cache.ground, 8 )
            net.WriteUInt( floor, 8 )
            net.WriteUInt( math.min( cache.recortadas, 65535 ), 16 )
            net.WriteFloat( cache.bounds.x0 ) net.WriteFloat( cache.bounds.y0 )
            net.WriteFloat( cache.bounds.x1 ) net.WriteFloat( cache.bounds.y1 )
            net.WriteUInt( trozos, 8 )
            -- la altura de cada piso, para que el cliente sepa en cual esta
            for k = 1, n do net.WriteFloat( cache.pisos[ k ].z ) end
        net.Send( ply )

        for i = 1, trozos do
            local parte = string.sub( datos, ( i - 1 ) * CHUNK + 1, i * CHUNK )
            net.Start( MSG )
                net.WriteUInt( 1, 4 )                      -- 1 = pedazo
                net.WriteUInt( floor, 8 )
                net.WriteUInt( i, 8 )
                net.WriteUInt( trozos, 8 )
                net.WriteUInt( #parte, 16 )
                net.WriteData( parte, #parte )
            net.Send( ply )
        end
    end )
end

if CLIENT then
    local plan          -- { ar, floors, ground, zs = {}, bounds }
    local cacheAreas = {}
    local cacheMuros = {}
    local pendiente = {}
    local onReady               -- callback que espera el piso pedido
    local pedidoFloor

    --[[
        Pide un piso. `cb( areas, plan, motivo )`:
          areas ~= nil  -> llego
          areas == nil  -> no hay plano, y `motivo` dice por que

        Si el piso ya esta cacheado responde en el acto, sin ir a la red.
    ]]
    function PHANTASMAGORIA.RequestSitePlan( floor, cb )
        floor = floor or 0
        if floor > 0 and cacheAreas[ floor ] then
            if plan then plan.muros = cacheMuros[ floor ] or nil end
            cb( cacheAreas[ floor ], plan )
            return
        end
        onReady, pedidoFloor = cb, floor
        net.Start( MSG )
            net.WriteUInt( floor, 8 )
        net.SendToServer()
    end

    function PHANTASMAGORIA.SitePlanInfo() return plan end

    net.Receive( MSG, function()
        local kind = net.ReadUInt( 4 )

        if kind == 2 then
            local motivo = net.ReadString()
            plan = nil
            if onReady then local cb = onReady; onReady = nil; cb( nil, nil, motivo ) end
            return
        end

        if kind == 0 then
            local p = { ar = net.ReadFloat(), floors = net.ReadUInt( 8 ),
                        ground = net.ReadUInt( 8 ), floor = net.ReadUInt( 8 ),
                        recortadas = net.ReadUInt( 16 ) }
            p.bounds = { x0 = net.ReadFloat(), y0 = net.ReadFloat(),
                         x1 = net.ReadFloat(), y1 = net.ReadFloat() }
            local trozos = net.ReadUInt( 8 )
            p.zs = {}
            for k = 1, p.floors do p.zs[ k ] = net.ReadFloat() end
            -- pisos[] con la forma que espera FloorOf, para no tener dos
            -- representaciones del mismo dato
            p.pisos = {}
            for k = 1, p.floors do p.pisos[ k ] = { z = p.zs[ k ] } end
            plan = p
            pendiente = { floor = p.floor, total = trozos, partes = {} }
            return
        end

        -- kind == 1: un pedazo
        local floor  = net.ReadUInt( 8 )
        local idx    = net.ReadUInt( 8 )
        local total  = net.ReadUInt( 8 )
        local largo  = net.ReadUInt( 16 )
        local datos  = net.ReadData( largo )

        if not pendiente or pendiente.floor ~= floor then return end
        pendiente.partes[ idx ] = datos
        pendiente.total = total

        for i = 1, total do if not pendiente.partes[ i ] then return end end

        local crudo = util.Decompress( table.concat( pendiente.partes ) )
        local bulto = crudo and util.JSONToTable( crudo ) or nil
        local areas = bulto and bulto.a or nil
        pendiente = nil
        if not areas then
            if onReady then local cb = onReady; onReady = nil; cb( nil, nil, "el plano llego roto" ) end
            return
        end

        cacheAreas[ floor ] = areas
        cacheMuros[ floor ] = bulto.w or false
        if plan then plan.floor, plan.muros = floor, bulto.w or nil end
        if onReady then local cb = onReady; onReady = nil; cb( areas, plan ) end
    end )
end
