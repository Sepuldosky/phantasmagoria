--[[-------------------------------------------------------------------------
    Phantasmagoria - los props HORNEADOS del mapa ( `prop_static` )

    POR QUE EXISTE. La pregunta del autor era *"algunos modelos estan baked en
    el mapa, me pregunto si seran posibles de tomar?"*. Como entidades NO: un
    `prop_static` no existe en runtime -- `ents.FindByClass( "prop_static" )`
    devuelve una lista vacia y tiene cero call sites en los 70 addons del
    taller. El compilador los hornea en el game lump `sprp` del `.bsp`, y ahi es
    donde hay que ir a buscarlos.

    P1, MEDIDO EN JUEGO EL 2026-08-11 y no asumido: el `.bsp` de este mapa viaja
    ADENTRO de `gmpublisher.gma` y lo monta el juego, asi que que el sistema de
    archivos virtual lo exponga por la ruta `maps/` era una afirmacion aparte de
    la de StormFox2 ( que hace el mismo `file.Open` pero sobre mapas sueltos ).
    Contesto que si, y las cuatro mitades:

        size=340212229 · magic=VBSP · vbsp=20 · lectura profunda 4/4 bytes

    La cuarta es la que no se podia saltear. Un handle que abre y no deja leer
    en profundidad hubiera sido un falso verde, porque este parser vive de
    `Seek`: el game lump esta hondo, no al principio.

    ⚠ NO SE LEE EL ARCHIVO ENTERO. Son 340 MB y el mapa entra en una string de
    Lua tan bien como en la RAM del servidor. Se navega con `Seek` y se leen
    tres tramos: el header ( 1032 bytes ), la tabla de game lumps, y los ~173 KB
    del `sprp`. StormFox2 hace exactamente eso.

    EL INSTRUMENTO GEMELO. `dev/censo_props_horneados.py` mide lo mismo desde
    afuera y YA DIO SU NUMERO: 418 modelos distintos en 1588 instancias. Eso es
    lo que vuelve auditable a este archivo -- si el Lua da otro numero, es el
    Lua el que esta mal. Sin ese numero previo, cualquier cosa que imprimiera
    este parser se leeria como correcta.

    ⚠⚠ Y POR ESO EL AUTO-CONTROL ABORTA EN VEZ DE REPORTAR. Si un `PropType`
    cae fuera del diccionario, la lectura se desalineo, y a partir de ahi todo
    lo que se cuente es **ruido con forma de dato** -- que es peor que no tener
    nada, porque tiene la forma de una medicion. El `.py` ya lo hace; se copia
    la idea, no solo el parseo.
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

---------------------------------------------------------------------------
-- LA REGLA DE IDENTIDAD DE UN MODELO, Y VIVE UNA SOLA VEZ
---------------------------------------------------------------------------
-- ⚠ `modeloCoincide( ent, regla )` de server_events.lua RECIBE UNA ENTIDAD:
-- llama a `basenameDe( ent )`, que hace `ent:GetModel()`. Un prop horneado es
-- una RUTA y nada mas, asi que no tiene con que entrar por ahi.
--
-- La tentacion es escribir un matcher paralelo para los estaticos. No: el dia
-- que alguien agregue una palabra a un `nunca` va a arreglar la mitad de los
-- casos y la otra mitad va a seguir sonando mal, sin error y sin rastro. *Una
-- regla que decide identidad tiene que existir una vez.* Es la misma leccion
-- que `PARENT_HOPS` en el bloque de las puertas, y ese defecto ya se cobro una
-- huella.
--
-- Entonces se parte en dos: la parte que SACA el modelo ( distinta para una
-- entidad y para una ruta ) y la parte que NORMALIZA y DECIDE ( una sola ).
-- server_events.lua delega las dos suyas aca.

--- El basename normalizado de una ruta de modelo: sin carpeta, sin `.mdl`.
function PHANTASMAGORIA.BasenameDeRuta( ruta )
    if not isstring( ruta ) or ruta == "" then return nil end

    -- El punto va ESCAPADO. ARC9 lo escribe sin escapar ( cl_drawmodel.lua:16 )
    -- y ahi el `.` matchea cualquier caracter: `foo_mdl` pasaria igual.
    return string.lower( string.match( ruta, "([^/\\]+)%.mdl$" ) or ruta )

end

--- ¿El basename ya normalizado cae en la regla de una familia?
-- El orden IMPORTA y es el del original: `nunca` primero y gana, despues
-- `exacto`, despues `parte`.
function PHANTASMAGORIA.NombreCoincide( nom, regla )
    if not isstring( nom ) or not istable( regla ) then return false end

    for _, mal in ipairs( regla.nunca or {} ) do
        if string.find( nom, mal, 1, true ) then return false end

    end

    if regla.exacto and regla.exacto[ nom ] then return true end

    for _, parte in ipairs( regla.parte or {} ) do
        if string.find( nom, parte, 1, true ) then return true end

    end

    return false

end

---------------------------------------------------------------------------
-- Leer enteros de una string. Little endian, que es lo que usa el .bsp
---------------------------------------------------------------------------
-- Se decodifica a mano en vez de usar `File:ReadLong()` por dos motivos: se lee
-- el tramo entero de una y se parsea en memoria ( 1588 `Seek` sueltos serian
-- 1588 viajes al disco ), y `File:ReadUShort` no esta en todas las builds --
-- una API asumida es un tercero asumido.
local byte = string.byte

local function u16( s, i )
    local a, b = byte( s, i, i + 1 )
    if not b then return nil end

    return a + b * 256

end

local function i32( s, i )
    local a, b, c, d = byte( s, i, i + 3 )
    if not d then return nil end

    local v = a + b * 256 + c * 65536 + d * 16777216
    if v >= 2147483648 then v = v - 4294967296 end

    return v

end

-- Un float de 32 bits, armado a mano: GLua corre Lua 5.1 y `string.unpack` es
-- de la 5.3. Los subnormales y el infinito se contemplan porque una coordenada
-- basura tiene que salir basura y no un numero creible -- si un exponente 255
-- devolviera 0 en silencio, un prop roto aterrizaria prolijo en el origen del
-- mapa y nadie lo notaria.
local function f32( s, i )
    local a, b, c, d = byte( s, i, i + 3 )
    if not d then return 0 end

    local signo = d >= 128 and -1 or 1
    local exp   = ( d % 128 ) * 2 + math.floor( c / 128 )
    local mant  = ( c % 128 ) * 65536 + b * 256 + a

    if exp == 0 then
        if mant == 0 then return 0 end

        return signo * mant * 2 ^ -149

    end

    if exp == 255 then
        return mant == 0 and signo * math.huge or 0 / 0

    end

    return signo * ( 1 + mant / 8388608 ) * 2 ^ ( exp - 127 )

end

---------------------------------------------------------------------------
-- ⚠⚠ TODA CANTIDAD LEIDA DEL ARCHIVO SE ACOTA CONTRA LO QUE EL TRAMO PUEDE
-- CONTENER, Y NO SOLO CONTRA EL CERO
---------------------------------------------------------------------------
-- LO QUE COSTO, medido el 2026-08-18 en `gm_uh_house`: las guardas de este
-- parser miraban **un solo lado** ( `if not n or n < 0` ). Un numero
-- absurdamente GRANDE pasaba entero, y el `for i = 1, ndict` de mas abajo
-- reviento con `table overflow` en la linea del `modelos[ i ] = nom`.
--
-- ⚠ EL ERROR NO SE PARECIA A LO QUE ERA. Subio por `EstaticosEnEsfera` ->
-- `EV.prop` -> `phantom_FireEvent` -> el concommand, o sea que el sintoma fue
-- **el evento `prop` inservible en cada disparo**, con una pila de nueve marcos
-- que apunta al consumidor y no a la causa. Un parser que TIRA en vez de
-- devolver `ok = false` convierte "este mapa no se puede leer" en "el addon esta
-- roto".
--
-- ⚠⚠ Y LA ASIMETRIA ES LA DE SIEMPRE: este archivo ya tenia tres auto-controles
-- finisimos contra la DESALINEACION -- la forma de la ruta, el sobrante en cero,
-- el PropType fuera del diccionario -- y ninguno contra un numero que no puede
-- ser una cantidad. *Los controles se escribieron para el modo de falla que ya
-- se habia visto.* El que faltaba era el barato.
--
-- EL LIMITE NO ES UNA CONSTANTE INVENTADA: es el tramo que YA se leyo dividido
-- por lo que ocupa cada entrada. Un diccionario de N rutas ocupa N*128 bytes; si
-- no entran en el `sprp` que se tiene en la mano, ese N no es un N -- es basura
-- con forma de numero, y decirlo asi es mas util que un `table overflow`.
local function cuentaValida( n, quedan, porcada )
    return n and n >= 0 and n <= math.floor( quedan / porcada )

end

--- El techo que se le pudo poner, para poder IMPRIMIRLO al lado del valor malo.
-- Un mensaje que dice "el numero es absurdo" sin decir contra que se lo comparo
-- manda a adivinar; con el techo, el que lo lee ve de una si el problema es el
-- numero o el tramo.
local function techo( quedan, porcada )
    return math.floor( quedan / porcada )

end

---------------------------------------------------------------------------
-- El parseo
---------------------------------------------------------------------------
local LUMP_GAME_LUMP = 35
local SPRP           = 0x73707270    -- 'sprp' leido como entero little endian

-- La cache es POR MAPA. Si no, un `changelevel` dejaria la lista del mapa
-- anterior viva y todo lo que se consultara despues serian props de otra casa
-- -- con coordenadas plausibles, que es la peor clase de dato equivocado.
local cache = nil

--- Parsea el `sprp` del mapa actual.
-- @return tabla { ok = bool, error = string, modelos = { ruta, ... },
--                 props = { { modelo = ruta, pos = Vector, ang = Angle }, ... } }
local function parsear()
    local mapa = game.GetMap()
    local ruta = "maps/" .. mapa .. ".bsp"
    local out  = { ok = false, mapa = mapa, ruta = ruta, modelos = {}, props = {} }

    local f = file.Open( ruta, "rb", "GAME" )
    if not f then
        out.error = "file.Open devolvio nil sobre '" .. ruta .. "' -- el mapa no esta " ..
            "expuesto por el sistema de archivos virtual"
        return out

    end

    out.bytes = f:Size()

    -- 1 · el header: "VBSP" + version + 64 lumps de { ofs, len, version, fourCC }
    f:Seek( 0 )
    local header = f:Read( 8 + 64 * 16 )
    if not header or #header < 8 + 64 * 16 then
        f:Close()
        out.error = "el header no entra: se leyeron " .. ( header and #header or 0 ) .. " de 1032 bytes"
        return out

    end

    if string.sub( header, 1, 4 ) ~= "VBSP" then
        f:Close()
        out.error = "los primeros 4 bytes no son 'VBSP' sino '" .. string.sub( header, 1, 4 ) .. "'"
        return out

    end

    out.version = i32( header, 5 )

    -- Los lumps arrancan en el byte 9 ( 1-based ) y miden 16 cada uno.
    local gl_ofs = i32( header, 9 + LUMP_GAME_LUMP * 16 )
    local gl_len = i32( header, 9 + LUMP_GAME_LUMP * 16 + 4 )
    if not gl_ofs or gl_ofs <= 0 or not gl_len or gl_len <= 0 then
        f:Close()
        out.error = "el mapa no tiene LUMP_GAME_LUMP ( offset " .. tostring( gl_ofs ) .. " )"
        return out

    end

    -- 2 · la tabla de game lumps: count, y despues count entradas de
    --     { id (4), flags (u16), version (u16), fileofs (int), filelen (int) }
    f:Seek( gl_ofs )
    local tabla = f:Read( math.min( gl_len, 4 + 512 * 16 ) )
    local ngl = tabla and i32( tabla, 1 )
    if not ngl or ngl < 0 then
        f:Close()
        out.error = "no se pudo leer la cantidad de game lumps"
        return out

    end

    out.gamelumps = ngl

    -- ⚠ El recorrido se acota a lo que `tabla` puede contener. Hoy el `break` de
    -- adentro alcanzaba ( `i32` devuelve nil pasado el final ), pero eso es una
    -- propiedad del lector y no del limite: escrito asi, el limite esta dicho.
    local maxgl = techo( #tabla - 4, 16 )
    local sv, sofs, slen
    for i = 0, math.min( ngl, maxgl ) - 1 do
        local base = 5 + i * 16
        local id = i32( tabla, base )
        if not id then break end

        if id == SPRP then
            sv   = u16( tabla, base + 6 )
            sofs = i32( tabla, base + 8 )
            slen = i32( tabla, base + 12 )

        end
    end

    if not sofs then
        f:Close()
        out.error = "este mapa no tiene game lump `sprp`: cero props horneados"
        return out

    end

    out.sprp_version = sv

    -- ⚠⚠ EL TRAMO QUE SE VA A LEER SE ACOTA CONTRA EL TAMANO DEL ARCHIVO ANTES
    -- DE LEERLO. `f:Read( slen )` con un `slen` basura intenta armar una string
    -- de Lua de ese tamano -- y el docstring de arriba dice, con todas las
    -- letras, que este mapa mide 340 MB y que por eso NO se lee entero. Un
    -- offset o un largo corridos convertirian esa promesa en lo contrario, sin
    -- una sola linea de aviso.
    if sofs < 0 or slen < 0 or ( out.bytes and ( sofs + slen ) > out.bytes ) then
        f:Close()
        out.error = "el game lump `sprp` dice vivir en " .. tostring( sofs ) .. "+" ..
            tostring( slen ) .. " bytes y el archivo mide " .. tostring( out.bytes ) ..
            ": la tabla de game lumps no dice donde esta el sprp de este mapa"
        return out

    end

    -- 3 · el `sprp` entero. Son ~173 KB, no 340 MB.
    f:Seek( sofs )
    local s = f:Read( slen )
    f:Close()

    -----------------------------------------------------------------------
    -- ⚠⚠ EL LUMP PUEDE VENIR COMPRIMIDO, Y ASI ES COMO SE DESCUBRIO
    -----------------------------------------------------------------------
    -- El 2026-08-18, en `gm_uh_house`, el parser reviento con `table overflow`
    -- porque leyo `dictEntries = 1095588428`. Ese numero, escrito de vuelta como
    -- cuatro bytes, es **'LZMA'**: no era una cantidad mal leida, eran los bytes
    -- de la firma de compresion interpretados como entero.
    --
    -- *Un campo numerico que no es un numero se lee como un numero enorme, y un
    -- numero enorme no se distingue de un dato valido mirando solo su signo.* Es
    -- lo que las guardas de arriba miraban antes.
    --
    -- Source comprime lumps con una cabecera propia de 17 bytes:
    --     'LZMA' (4) · tamano descomprimido (u32) · tamano comprimido (u32) ·
    --     5 bytes de propiedades LZMA1
    -- y despues el stream crudo. ⚠ Y OJO CON `slen`: en un lump comprimido el
    -- `filelen` de la tabla de game lumps trae el tamano **DESCOMPRIMIDO**, asi
    -- que el `f:Read( slen )` de arriba lee de mas y se mete en el lump vecino.
    -- No es un problema mientras el archivo de con los bytes -- lo que importa
    -- esta en los primeros 17 + comprimido --, pero por eso el chequeo de "no
    -- entra" se hace DESPUES de saber si esta comprimido y no antes.
    --
    -- ⚠⚠ ESTE CAMINO SE VERIFICA A SI MISMO Y POR ESO NO ES UNA APUESTA. Que
    -- `util.Decompress` acepte la cabecera "alone" ( propiedades + tamano en 8
    -- bytes + stream ) **no se pudo medir sin el juego**; lo que si se midio, con
    -- `dev/bsp_statics_offline.py` y el `lzma` de Python, es que **el dato esta
    -- ahi**: 15005 bytes se abren en 78334 y dan 188 modelos / 702 props con
    -- `sobrantes 0`. Asi que si la API contesta, el resultado pasa igual por los
    -- tres auto-controles de alineacion de mas abajo; y si no contesta, esto
    -- devuelve `ok = false` con motivo, que es exactamente donde estabamos.
    if s and #s >= 17 and string.sub( s, 1, 4 ) == "LZMA" then
        local real = i32( s, 5 )
        local comp = i32( s, 9 )
        out.comprimido = true

        if not real or not comp or real <= 0 or comp <= 0 or #s < 17 + comp then
            out.error = "el sprp esta comprimido ( LZMA ) y la cabecera no cierra: dice " ..
                tostring( comp ) .. " bytes comprimidos y hay " .. ( #s - 17 )
            return out

        end

        if not util or not util.Decompress then
            out.error = "el sprp esta comprimido ( LZMA, " .. comp .. " -> " .. real ..
                " bytes ) y `util.Decompress` no existe en esta build"
            return out

        end

        -- La cabecera "alone": 5 bytes de propiedades + el tamano descomprimido
        -- en 8 bytes little endian. `real` entra en 32 bits, asi que los cuatro
        -- de arriba van en cero.
        local props8 = string.sub( s, 13, 17 ) .. string.char(
            real % 256,
            math.floor( real / 256 ) % 256,
            math.floor( real / 65536 ) % 256,
            math.floor( real / 16777216 ) % 256,
            0, 0, 0, 0 )

        local abierto = util.Decompress( props8 .. string.sub( s, 18, 17 + comp ) )

        -- ⚠ NO ALCANZA CON QUE DEVUELVA ALGO. `util.Decompress` sobre basura
        -- puede devolver una string corta en vez de nil, y una string corta
        -- parseada como sprp da numeros creibles. El largo declarado en la
        -- cabecera es un testigo independiente del descompresor: si no coinciden,
        -- lo que salio no es el lump.
        if not abierto or #abierto ~= real then
            out.error = "el sprp esta comprimido ( LZMA ) y `util.Decompress` devolvio " ..
                ( abierto and ( #abierto .. " bytes" ) or "nil" ) .. " en vez de los " .. real ..
                " que declara la cabecera: no se puede leer este mapa"
            return out

        end

        s, slen = abierto, real

    end

    if not s or #s < slen then
        out.error = "el sprp no entra: se leyeron " .. ( s and #s or 0 ) .. " de " .. slen .. " bytes"
        return out

    end

    -- dictEntries (int) · dictEntries * 128 bytes de ruta de modelo
    local p = 1
    local ndict = i32( s, p ); p = p + 4
    if not cuentaValida( ndict, #s - 4, 128 ) then
        out.error = "dictEntries = " .. tostring( ndict ) .. ", y en los " .. #s ..
            " bytes del sprp entran como mucho " .. techo( #s - 4, 128 ) ..
            " rutas de 128 bytes -> eso no es una cantidad, es basura con forma de numero " ..
            "( el sprp puede estar comprimido, o la tabla de game lumps apuntar a otro lado )"
        return out

    end

    local modelos = {}
    local raras = 0
    for i = 1, ndict do
        local crudo = string.sub( s, p, p + 127 )
        local corte = string.find( crudo, "\0", 1, true )
        local nom = string.lower( corte and string.sub( crudo, 1, corte - 1 ) or crudo )
        modelos[ i ] = nom

        -- ⚠ EL CONTROL QUE DE VERDAD ATAJA UN CORRIMIENTO. El auto-control
        -- clasico -- "un PropType fuera del diccionario" -- suena mas fuerte de
        -- lo que es: medido sobre este mapa, leer el indice corrido UN BYTE da
        -- 256, que cae ADENTRO del rango 0..417 y pasa sin decir nada. O sea
        -- que atrapa la desalineacion grosera y deja pasar la sutil, que es la
        -- que produce numeros creibles.
        --
        -- La forma de la ruta si discrimina, y esta medido: las 418 entradas
        -- empiezan con `models/` y terminan en `.mdl`; leidas con un byte de
        -- corrimiento, CERO de 418 lo siguen haciendo.
        if not ( string.sub( nom, 1, 7 ) == "models/" and string.sub( nom, -4 ) == ".mdl" ) then
            raras = raras + 1

        end

        p = p + 128

    end

    if raras > 0 then
        out.error = raras .. " de " .. ndict .. " entradas del diccionario no tienen forma de " ..
            "ruta de modelo ( `models/...mdl` ) -> LECTURA DESALINEADA, el censo no vale"
        return out

    end

    -- leafEntries (int) · leafEntries * u16
    local nleaf = i32( s, p ); p = p + 4
    if not cuentaValida( nleaf, #s - ( p - 1 ), 2 ) then
        out.error = "leafEntries = " .. tostring( nleaf ) .. ", y despues del diccionario " ..
            "quedan " .. ( #s - ( p - 1 ) ) .. " bytes, o sea como mucho " ..
            techo( #s - ( p - 1 ), 2 ) .. " entradas de 2 -> la lectura no esta donde deberia"
        return out

    end

    p = p + nleaf * 2

    -- entryCount (int) · entryCount * StaticPropLump_t
    -- El minimo por entrada son los 26 bytes de Origin+Angles+PropType, que es
    -- lo que el chequeo de `paso` de abajo ya exige. Aca se usa el mismo numero
    -- para acotar la CANTIDAD, que es lo que evita el `for` gigante: las dos
    -- mitades del mismo criterio, y por eso el 26 esta una sola vez en el texto.
    local nprops = i32( s, p ); p = p + 4
    if not cuentaValida( nprops, #s - ( p - 1 ), 26 ) then
        out.error = "entryCount = " .. tostring( nprops ) .. ", y quedan " ..
            ( #s - ( p - 1 ) ) .. " bytes, o sea como mucho " .. techo( #s - ( p - 1 ), 26 ) ..
            " entradas de 26 ( el minimo de Origin+Angles+PropType ) -> la lectura no esta " ..
            "donde deberia"
        return out

    end

    -- ⚠ EL TAMANO DE ENTRADA SE CALCULA, NO SE ASUME. `StaticPropLump_t` cambia
    -- de tamano con la version del lump: 56 en v4, 72 en el v10 de este mapa, y
    -- otro mapa va a traer otra. Lo que NO cambia entre v4 y v11 es el arranque
    -- -- Origin (12) + Angles (12) + PropType (u16) -- o sea que el origen esta
    -- en +0 y el indice de modelo en +24 SIEMPRE.
    local resto = ( slen - ( p - 1 ) )
    local paso  = nprops > 0 and math.floor( resto / nprops ) or 0

    out.modelos    = modelos
    out.n_modelos  = ndict
    out.n_props    = nprops
    out.paso       = paso
    out.sobrantes  = resto - paso * nprops

    if nprops > 0 and paso < 26 then
        out.error = "bytes por entrada = " .. paso .. ", que no alcanza ni para " ..
            "Origin+Angles+PropType ( 26 ): la lectura no esta donde deberia"
        return out

    end

    -- ⚠ Y ESTE ES EL QUE ATAJA UN ARRANQUE CORRIDO. Si el arreglo de entradas
    -- no empieza donde creemos, `resto` cambia y la division deja resto: sobre
    -- este mapa 173420 bytes reparten 72 justos en 1588 entradas y sobra CERO.
    -- Un sobrante distinto de cero no es un detalle de padding, es la unica
    -- senal barata de que la cuenta no cierra.
    if nprops > 0 and out.sobrantes ~= 0 then
        out.error = "quedan " .. out.sobrantes .. " byte(s) sueltos despues de " .. nprops ..
            " entradas de " .. paso .. " -> la lectura no arranca donde deberia"
        return out

    end

    -- ⚠⚠ EL AUTO-CONTROL. Un `PropType` fuera del diccionario significa que la
    -- lectura se desalineo, y a partir de ahi todo lo que se cuente es ruido con
    -- forma de dato. Se ABORTA, no se reporta -- un censo desalineado que igual
    -- imprime numeros es peor que uno que falla, porque el que falla se ve.
    local props = {}
    for i = 0, nprops - 1 do
        local base = p + i * paso
        local t = u16( s, base + 24 )
        if not t or t < 0 or t >= ndict then
            out.error = "indice de modelo " .. tostring( t ) .. " fuera del diccionario ( 0.." ..
                ( ndict - 1 ) .. " ) en la entrada " .. i .. " -> LECTURA DESALINEADA, el censo no vale"
            return out

        end

        -- Origin y Angles son tres floats de 4 bytes cada uno: se decodifican
        -- aparte de los enteros porque el formato es otro ( IEEE 754 ).
        props[ i + 1 ] = {
            modelo = modelos[ t + 1 ],
            pos    = Vector( f32( s, base ), f32( s, base + 4 ), f32( s, base + 8 ) ),
            ang    = Angle( f32( s, base + 12 ), f32( s, base + 16 ), f32( s, base + 20 ) ),
        }

    end

    out.props = props
    out.ok    = true
    return out

end

---------------------------------------------------------------------------
-- La cara publica
---------------------------------------------------------------------------

--- Devuelve la lectura del mapa actual, parseando una sola vez.
-- ⚠ Devuelve la tabla SIEMPRE, con `ok = false` y un `error` legible si algo
-- salio mal. No devuelve nil: un nil obliga a cada consumidor a inventarse su
-- propio mensaje, y el que no lo haga va a tratar "no se pudo leer" y "no hay
-- props" como la misma cosa.
function PHANTASMAGORIA.Estaticos()
    if cache and cache.mapa == game.GetMap() then return cache end

    -- ⚠⚠ EL PARSEO VA ADENTRO DE UN `pcall`, Y NO PORQUE SE ESPEREN ERRORES:
    -- PORQUE EL CONTRATO DE ESTA FUNCION ES EL DE ARRIBA -- *"devuelve la tabla
    -- SIEMPRE, con `ok = false` y un `error` legible"* -- y un error de Lua
    -- adentro de `parsear` lo rompe **hacia arriba**: se lleva puesto al
    -- consumidor, al evento y al concommand que lo disparo.
    --
    -- Paso el 2026-08-18 en `gm_uh_house`, con un `table overflow`: la pila
    -- llegaba hasta `concommand.lua` y el evento `prop` quedaba inservible EN
    -- CADA DISPARO. El parser tenia todos sus errores previstos escritos como
    -- `out.error`, asi que la unica forma de que apareciera un error de Lua era
    -- justamente la que nadie previo -- que es la que el `pcall` cubre.
    --
    -- ⚠ Y LA FALLA SE CACHEA. Antes, al tirar error la asignacion `cache = ...`
    -- **nunca ocurria**, asi que el mapa se re-parseaba y re-reventaba en cada
    -- evento: un archivo que no se puede leer no se vuelve legible por releerlo.
    -- Guardar el fracaso es lo que convierte un error por disparo en uno por
    -- mapa, y ademas deja que `phantasmagoria_ghost_estaticos` lo IMPRIMA en vez
    -- de reventar el tambien.
    local ok, res = pcall( parsear )

    if ok then
        cache = res

    else
        cache = {
            ok      = false,
            mapa    = game.GetMap(),
            modelos = {},
            props   = {},
            error   = "el parseo del .bsp tiro un error de Lua y se atajo para no cortar la " ..
                "cadena del evento: " .. tostring( res ),
        }

    end

    return cache

end

--- El gemelo de `ents.FindInSphere` sobre lo horneado.
-- @param pos   centro
-- @param radio en unidades
-- @param filtro opcional: function( prop ) -> bool
function PHANTASMAGORIA.EstaticosEnEsfera( pos, radio, filtro )
    local datos = PHANTASMAGORIA.Estaticos()
    local out = {}
    if not datos.ok then return out end

    local r2 = radio * radio
    for _, prop in ipairs( datos.props ) do
        if prop.pos:DistToSqr( pos ) <= r2 then
            if not filtro or filtro( prop ) then out[ #out + 1 ] = prop end

        end
    end

    return out

end

--- Cuenta instancias por modelo. Lo usa el instrumento, no el evento.
function PHANTASMAGORIA.EstaticosPorModelo()
    local datos = PHANTASMAGORIA.Estaticos()
    local cuenta = {}
    if not datos.ok then return cuenta end

    for _, prop in ipairs( datos.props ) do
        cuenta[ prop.modelo ] = ( cuenta[ prop.modelo ] or 0 ) + 1

    end

    return cuenta

end
