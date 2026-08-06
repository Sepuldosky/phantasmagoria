--[[-------------------------------------------------------------------------
    Phantasmagoria - DIAGNOSTICO del plato parabolico opaco

    EL SINTOMA
    Los tres platos se ven opacos en juego. Sus VMT declaran `$alpha 0.5`, que
    es el `_Opacity` medido del material de Unity, y el check 06 de la ronda 2
    esperaba verlos a media transparencia.

    ESTE ARCHIVO NO ARREGLA NADA. Es un instrumento: monta materiales de prueba
    para separar DOS familias de causas que producen el mismo sintoma.

      (A) NIVEL MODELO. El .mdl no esta marcado two-pass, asi que el motor
          dibuja el prop entero en el pase opaco y NINGUN material puede ser
          translucido ahi. MEDIDO en el binario: los tres paramic tienen
          flags=1, sin el bit 3 (TRANSLUCENT_TWOPASS). Se corrige en el .qc con
          `$mostlyopaque` y recompilando — ya aplicado SOLO al tier 3, para que
          los tiers 1 y 2 queden de control.

      (B) NIVEL MATERIAL. El .vmt no carga, o algo adentro del .vmt derrota al
          `$alpha`. El sospechoso es `$phong 1` con `$phongboost 3.0`.

    COMO SE SEPARAN, y por que hace falta mas de un comando

    Un solo material de prueba no alcanza: si se ve translucido no sabemos si
    `$alpha` funciona o si estamos viendo un reflejo, y si se ve opaco no
    sabemos si la culpa es del material o del pase. Por eso hay un control de
    cada lado:

      cero    -> `$alpha 0`. Es el CONTROL NULO: tiene que DESAPARECER. Si no
                 desaparece, `$alpha` no se esta aplicando y cualquier lectura
                 de "se ve un poco translucido" era imaginacion.
      cuerpo  -> el mismo material translucido sobre el submaterial 0, que es el
                 CUERPO. Es el CONTROL POSITIVO del pase: si el cuerpo tampoco
                 se vuelve translucido, el problema no es del plato sino del
                 modelo entero, o sea la familia (A).
      plano   -> `$alpha 0.5` pelado sobre el plato.
      phong   -> lo mismo MAS phong. `plano` contra `phong` es un A/B de una
                 sola variable: los dos son de runtime, los dos llevan
                 `$model 1`, y lo unico que cambia es el phong.

    UNA HIPOTESIS QUE YA ESTA REFUTADA, sin gastar una corrida
    Que a los `*_glass.vmt` les falte `$model 1`. Los VMT del CUERPO
    (`paramic1.vmt`, `paramic2.vmt`, `paramic3.vmt`) son `VertexLitGeneric` y
    tampoco lo llevan, y se dibujan bien desde la ronda 1. El `$model 1` que
    costo la ronda anterior era de `CreateMaterial`, no de un .vmt de disco.

    LO QUE NO SE PUEDE HACER, y hay que tenerlo presente al leer el resultado
    Reproducir el .vmt de disco tal cual en runtime: un `CreateMaterial` SIN
    `$model 1` no dibuja (medido en la ronda 2). Asi que los materiales de
    prueba difieren del archivo en esa clave. Por eso el veredicto sobre el
    ARCHIVO sale del volcado de `info`, que lo lee, y no de compararlo con el
    material de prueba.

    LO QUE YA MIDIO LA PRIMERA CORRIDA (ronda 3, y corrige a este archivo)

      - `$mostlyopaque` NO alcanza. El tier 3 con TRANSLUCENT_TWOPASS en el
        .mdl (flags=9, medido) se ve tan opaco como los tiers 1 y 2 sin la
        bandera. La familia (A) no queda descartada, pero la bandera sola no era.
      - `GetRenderGroup()` NO discrimina: dio 7 en los tres, con y sin bandera.
      - `$alpha` leido del MATERIAL da 1 en los tres, y eso NO significa que el
        .vmt no lo declare: es la modulacion de alfa, que el motor escribe al
        dibujar. Por eso el volcado ahora lee el .vmt como ARCHIVO.

    USO
        phantasmagoria_paramic_vidrio            <- volcado, no toca nada
        phantasmagoria_paramic_vidrio plano      <- $alpha 0.5 pelado
        phantasmagoria_paramic_vidrio trans      <- $translucent 1
        phantasmagoria_paramic_vidrio cero       <- $alpha 0, control nulo
        phantasmagoria_paramic_vidrio phong
        phantasmagoria_paramic_vidrio cuerpo     <- control positivo, submaterial 0
        phantasmagoria_paramic_vidrio ent        <- control de ENTIDAD, sin material
        phantasmagoria_paramic_vidrio off        <- devuelve el prop
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

local W   = Color( 235, 235, 235 )
local DIM = Color( 175, 175, 175 )
local OK  = Color( 120, 235, 120 )
local BAD = Color( 255, 120, 120 )

PHANTASMAGORIA.PARAMIC_GLASS_SUFFIX = "_glass"

--[[
    El indice del plato NO se cablea. Es la misma leccion que costo la ronda 2
    con la pantalla, y aca es peor todavia porque el indice del plato cambia
    entre tiers:

        paramic1:  0 cuerpo   1 paramic1_glass
        paramic2:  0 cuerpo   1 paramic2_screen   2 paramic2_glass
        paramic3:  0 cuerpo   1 paramic3_screen   2 paramic3_glass

    Devuelve el indice BASE 0 (el de SetSubMaterial) y el nombre, porque
    GetMaterials() es base 1 y el desfasaje se paga una sola vez, aca.
]]
function PHANTASMAGORIA.FindGlassSubMaterial( ent )
    if not IsValid( ent ) then return nil end
    local mats = ent:GetMaterials()
    if not istable( mats ) then return nil end
    for i, m in ipairs( mats ) do
        if string.EndsWith( m, PHANTASMAGORIA.PARAMIC_GLASS_SUFFIX ) then
            return i - 1, m
        end
    end
    return nil
end

--[[
    CreateMaterial devuelve el material YA CREADO si el nombre existe, y en ese
    caso IGNORA la tabla de keyvalues nueva. Dos consecuencias, las dos son
    trampas de silencio:

      - un modo por nombre, si no el segundo modo devuelve el material del
        primero y el A/B mide una sola cosa dos veces;
      - el TIER va en el nombre, porque el $basetexture del plato del tier 1 es
        paramic1 y el de los tiers 2 y 3 es paramic3 (el plato esta compartido).
        Sin eso, probar el tier 1 y despues el 3 le monta al 3 la textura del 1.
]]
local cache = {}

local function testMaterial( key, tier, base, extra )
    local name = "phantasmagoria_vidrio_" .. key .. "_" .. tier
    if cache[ name ] then return cache[ name ], name end

    local kv = {
        [ "$basetexture" ] = base,

        -- $model 1 no es opcional en un CreateMaterial: sin el se compila como
        -- material de mundo y la submalla NO SE DIBUJA, sin error y sin textura
        -- de error. Medido en la ronda 2.
        [ "$model" ]       = "1",
    }
    for k, v in pairs( extra or {} ) do kv[ k ] = v end

    local m = CreateMaterial( name, "VertexLitGeneric", kv )
    cache[ name ] = m
    return m, name
end

-- El $basetexture sale del PROPIO .vmt del plato, no de una tabla nuestra: asi
-- el material de prueba y el archivo no pueden divergir por un dato repetido.
-- Si el archivo no cargo, GetString devuelve nil y se cae al nombre del modelo,
-- que es lo que `info` imprime para que se note.
local function glassBaseTexture( glassMat, tier )
    local b = glassMat and glassMat:GetString( "$basetexture" )
    if b and b ~= "" then return b, "del .vmt" end
    return "models/phantasmagoria/paramic" .. ( tier == 1 and 1 or 3 ), "FALLBACK (el .vmt no dio $basetexture)"
end

local function tierOf( ent )
    local mdl = ent:GetModel() or ""
    local n = string.match( mdl, "paramic(%d)%.mdl$" )
    return tonumber( n )
end

--[[
    Lector seguro de una propiedad de material.

    `IMaterial:GetInt("$loquesea")` sobre una clave que el material NO define no
    devuelve nil: devuelve CERO VALORES. Pasarselo a `tostring()` revienta con
    "bad argument #1 (value expected)" y el volcado se corta ahi, con las lineas
    que faltan indistinguibles de lineas que no existen. Paso en la primera
    corrida de la ronda 3, y el error aparecio DESPUES de la linea que se leyo
    como resultado — o sea que el volcado parecia completo.

    Distinguir NO DEFINIDO de un valor es parte del dato: que el plato no defina
    `$translucent` es exactamente lo que hay que saber.
]]
local function mv( mat, method, key )
    if not mat then return "sin material" end
    local ok, v = pcall( function()
        if key then return mat[ method ]( mat, key ) end
        return mat[ method ]( mat )
    end )
    if not ok then return "ERROR: " .. tostring( v ) end
    if v == nil then return "NO DEFINIDO" end
    return tostring( v )
end

--[[-------------------------------------------------------------------------
    El volcado. Imprime CON QUE se esta midiendo, no solo el resultado.
---------------------------------------------------------------------------]]
local function dump( ent, tier )
    local mats = ent:GetMaterials() or {}
    local gi, gname = PHANTASMAGORIA.FindGlassSubMaterial( ent )

    MsgC( W, "[Vidrio] modelo = " .. ( ent:GetModel() or "?" ) .. "   tier = " .. tostring( tier ) .. "\n" )
    for i, m in ipairs( mats ) do
        MsgC( DIM, string.format( "   SetSubMaterial(%d) -> %s%s\n",
            i - 1, m, ( i - 1 ) == gi and "   <-- el PLATO" or "" ) )
    end

    -- El motor decide en que pase va el prop ENTERO. Si esta API no existe en
    -- esta build, se dice; no se infiere.
    local okrg, rg = pcall( function() return ent:GetRenderGroup() end )
    --[[
        SI discrimina, y decir lo contrario fue un error de lectura.

        En la ronda 3 dio 7 (OPAQUE) en los tres tiers — incluido el que ya
        tenia TRANSLUCENT_TWOPASS en el .mdl— y de ahi anote «este numero es la
        ranura de GMod y no la decision del motor». **Falso.** En la ronda 4,
        con los platos ya en `$translucent 1`, los tres dan 9 (BOTH).

        Lo que salio igual en los tres casos de la ronda 3 salia igual porque
        los tres estaban en el MISMO estado —materiales opacos—, no porque el
        numero fuera ciego. *Un valor constante sobre un conjunto que no varia
        en lo que importa no prueba que el instrumento no mida.*

        Lo que este numero SI dice: el motor decide el grupo mirando los
        MATERIALES, no solo el flag del .mdl — el flag solo no lo movio de 7.
        Lo que NO se puede separar con los datos que hay: si el 9 necesita el
        flag ademas del material, porque los tres tienen las dos cosas.
    ]]
    MsgC( W, "   GetRenderGroup() = " .. ( okrg and tostring( rg ) or "no disponible en esta build" ) ..
        "   (OPAQUE=" .. tostring( RENDERGROUP_OPAQUE ) ..
        ", TRANSLUCENT=" .. tostring( RENDERGROUP_TRANSLUCENT ) ..
        ", BOTH=" .. tostring( RENDERGROUP_BOTH ) .. ")\n" )
    MsgC( DIM, "      con el plato opaco daba 7; con $translucent da 9. El motor lo decide por los MATERIALES.\n" )

    if not gname then
        MsgC( BAD, "   Ningun material termina en '_glass': este modelo no tiene plato.\n" )
        return
    end

    --[[
        LO QUE DICE EL ARCHIVO. Es la unica lectura autoritativa de que declara
        el .vmt, y ademas prueba CUAL archivo montó el juego — si otro addon
        pisa la ruta, lo que sale acá es el del otro addon.

        Va antes que el estado del material a proposito: en la primera corrida
        de la ronda 3 se leyo `$alpha = 1` del material y se estuvo a un paso de
        anotar "el .vmt no declara el alpha", con el archivo declarandolo.
    ]]
    local vmtPath = "materials/" .. gname .. ".vmt"
    local txt = file.Read( vmtPath, "GAME" )
    MsgC( W, "   ARCHIVO " .. vmtPath .. "\n" )
    if not txt then
        MsgC( BAD, "      no se pudo leer\n" )
    else
        local n = 0
        for line in string.gmatch( txt, "[^\r\n]+" ) do
            local t = string.Trim( line )
            -- Sin comentarios ni llaves: lo que queda son las claves.
            if t ~= "" and t ~= "{" and t ~= "}" and string.sub( t, 1, 2 ) ~= "//" then
                MsgC( DIM, "      " .. t .. "\n" )
                n = n + 1
            end
        end
        MsgC( DIM, "      (" .. n .. " claves)\n" )
    end

    --[[
        ESTADO DEL MATERIAL EN RUNTIME. NO es lo que dice el archivo.

        `$alpha` es la modulacion de alfa: el motor la escribe mientras dibuja,
        asi que leerla desde un concommand devuelve el valor de reposo (1) diga
        lo que diga el .vmt. Por eso el bloque de arriba existe.

        Y `GetInt`/`GetFloat` sobre una clave que el material NO define devuelven
        CERO VALORES —no nil—, asi que un `tostring()` directo revienta con
        "value expected". Es lo que corto este volcado en la primera corrida,
        justo despues de la linea que mas importaba.
    ]]
    local gm = Material( gname )
    MsgC( W, "   ESTADO EN RUNTIME (no es lo que dice el archivo)\n" )
    MsgC( DIM, "      IsError        = " .. mv( gm, "IsError" ) ..
        "   shader = " .. mv( gm, "GetShader" ) .. "\n" )
    MsgC( DIM, "      $basetexture   = " .. mv( gm, "GetString", "$basetexture" ) .. "\n" )
    MsgC( DIM, "      $alpha         = " .. mv( gm, "GetFloat", "$alpha" ) ..
        "   <- modulacion, se pisa al dibujar: NO dice que declara el .vmt\n" )
    MsgC( DIM, "      $translucent   = " .. mv( gm, "GetInt", "$translucent" ) ..
        "   $phong = " .. mv( gm, "GetInt", "$phong" ) ..
        "   $phongboost = " .. mv( gm, "GetFloat", "$phongboost" ) .. "\n" )

    -- El cuerpo es el control dentro del mismo modelo: se dibuja bien desde la
    -- ronda 1, y tampoco lleva $model.
    local bname = mats[ 1 ]
    if bname then
        local bm = Material( bname )
        MsgC( W, "   CUERPO (control): " .. bname .. "\n" )
        MsgC( DIM, "      IsError = " .. mv( bm, "IsError" ) ..
            "   shader = " .. mv( bm, "GetShader" ) ..
            "   $model = " .. mv( bm, "GetInt", "$model" ) .. "\n" )
    end
end

--[[-------------------------------------------------------------------------
    Los modos.
---------------------------------------------------------------------------]]
local MODES = {
    plano  = { key = "plano", extra = { [ "$alpha" ] = "0.5" },
               say = "plato con $alpha 0.5 PELADO (sin phong). Esperado: se ve el canon a traves." },
    cero   = { key = "cero",  extra = { [ "$alpha" ] = "0" },
               say = "plato con $alpha 0 - CONTROL NULO. Esperado: el plato DESAPARECE." },
    phong  = { key = "phong", extra = { [ "$alpha" ] = "0.5", [ "$phong" ] = "1",
                                        [ "$phongexponent" ] = "40", [ "$phongboost" ] = "3.0",
                                        [ "$phongfresnelranges" ] = "[0.2 1.0 4.0]",
                                        [ "$halflambert" ] = "1" },
               say = "plato con $alpha 0.5 MAS phong, como el .vmt. Contra 'plano', la unica variable es el phong." },
    -- `cuerpo` comparte a proposito el key y los keyvalues de `plano`: es EL
    -- MISMO material, montado en otro indice. Si fuera una copia con otro
    -- nombre, el A/B tendria dos variables (el indice y el material) y no
    -- podria decir cual de las dos movio el resultado.
    cuerpo = { key = "plano", extra = { [ "$alpha" ] = "0.5" }, onBody = true,
               say = "CUERPO con $alpha 0.5 - CONTROL POSITIVO del pase. Si el cuerpo tampoco se vuelve translucido, la causa es del MODELO, no del plato." },

    --[[
        `$translucent 1` en vez de `$alpha`. Prueba una PREDICCION que quedo
        escrita en los tres .vmt sin medirse: que `$translucent` haria
        desaparecer el plato, porque lee el alfa del $basetexture y ese alfa es
        la mascara de $selfillum del cuerpo, casi toda negra.

        Los dos desenlaces sirven, que es la razon de que este modo exista:
          - el plato DESAPARECE (o queda a manchones) -> la prediccion era
            correcta, y el arreglo es darle al plato una textura propia con
            alfa uniforme, no cambiar una linea del .vmt.
          - el plato queda a media transparencia -> la prediccion era falsa y
            `$translucent 1` es el arreglo entero, una linea por archivo.
    ]]
    trans  = { key = "trans", extra = { [ "$translucent" ] = "1" },
               say = "plato con $translucent 1 (lee el alfa de la textura). Mira si DESAPARECE o si queda a medias: las dos cosas son un resultado." },
}

--[[
    El control de nivel ENTIDAD, que no pasa por el material.

    `SetRenderMode` + alfa en el color es el camino de GMod para volver
    translucido un prop, y es independiente de todo lo que discuten los otros
    modos. Contesta la pregunta mas grande que quedo abierta: *¿este prop puede
    ser translucido de alguna manera?* Si por aca si, el pase funciona y la
    familia "es el modelo" queda muerta.

    OJO: es un cambio CLIENTSIDE sobre una entidad del servidor. Si parpadea o
    vuelve solo, es la actualizacion de red pisandolo, no el resultado.
]]
local function entMode( ent, on )
    if on then
        ent:SetRenderMode( RENDERMODE_TRANSALPHA )
        ent:SetColor( Color( 255, 255, 255, 128 ) )
    else
        ent:SetRenderMode( RENDERMODE_NORMAL )
        ent:SetColor( Color( 255, 255, 255, 255 ) )
    end
end

concommand.Add( "phantasmagoria_paramic_vidrio", function( _, _, args )
    local ply = LocalPlayer()
    if not IsValid( ply ) then return end

    local ent = ply:GetEyeTrace().Entity
    if not IsValid( ent ) then
        MsgC( BAD, "[Vidrio] No estas mirando ninguna entidad.\n" )
        return
    end

    local tier = tierOf( ent )
    if not tier then
        MsgC( BAD, "[Vidrio] " .. ( ent:GetModel() or "?" ) .. " no es un paramic. No toco nada.\n" )
        return
    end

    local mode = string.lower( args[ 1 ] or "info" )

    if mode == "info" then
        dump( ent, tier )
        return
    end

    local gi = PHANTASMAGORIA.FindGlassSubMaterial( ent )

    if mode == "off" then
        -- Limpia TODOS los indices, no solo el del plato: el modo `cuerpo`
        -- escribe en el 0 y olvidarlo deja un prop a medio devolver que se lee
        -- como un resultado. Y deshace `ent`, que no pasa por los submateriales
        -- y por eso es el que mas facil se olvida puesto.
        for i = 0, #( ent:GetMaterials() or {} ) - 1 do ent:SetSubMaterial( i ) end
        entMode( ent, false )
        MsgC( OK, "[Vidrio] Devuelto: submateriales limpios y render mode normal.\n" )
        return
    end

    if mode == "ent" then
        entMode( ent, true )
        MsgC( W, "[Vidrio] tier " .. tier .. "  RENDERMODE_TRANSALPHA + color alfa 128.\n" )
        MsgC( OK, "   No pasa por el material. Si el prop ENTERO se vuelve translucido, el pase funciona y la causa NO es el modelo.\n" )
        return
    end

    local def = MODES[ mode ]
    if not def then
        MsgC( BAD, "[Vidrio] Modo desconocido '" .. mode .. "'. Son: info, plano, trans, cero, phong, cuerpo, ent, off.\n" )
        return
    end

    local idx = def.onBody and 0 or gi
    if not idx then
        MsgC( BAD, "[Vidrio] Este modelo no tiene submaterial que termine en '_glass'.\n" )
        return
    end

    local _, gname = PHANTASMAGORIA.FindGlassSubMaterial( ent )
    local base, origen = glassBaseTexture( gname and Material( gname ) or nil, tier )
    local _, matName = testMaterial( def.key, tier, base, def.extra )

    ent:SetSubMaterial( idx, "!" .. matName )

    MsgC( W, "[Vidrio] tier " .. tier .. "  SetSubMaterial(" .. idx .. ") <- !" .. matName .. "\n" )
    MsgC( DIM, "   $basetexture = " .. base .. "  (" .. origen .. ")\n" )
    MsgC( OK, "   " .. def.say .. "\n" )
end, function( _, arg )
    local out = {}
    for _, m in ipairs( { "info", "plano", "trans", "cero", "phong", "cuerpo", "ent", "off" } ) do
        if string.find( m, string.Trim( arg or "" ), 1, true ) == 1 then
            out[ #out + 1 ] = "phantasmagoria_paramic_vidrio " .. m
        end
    end
    return out
end, "Diagnostico del plato opaco: separa causa de MATERIAL de causa de MODELO" )
