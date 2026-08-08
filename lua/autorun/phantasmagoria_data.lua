--[[-------------------------------------------------------------------------
    Phantasmagoria - el cargador de los datos

    ⚠⚠ ESTE ARCHIVO EXISTE PORQUE `lua/phantasmagoria/` NO LO CARGABA NADIE.

    GMod auto-ejecuta un conjunto FIJO de carpetas -- `lua/autorun/`,
    `lua/entities/`, `lua/weapons/`, `lua/effects/`, `lua/vgui/` y unas pocas
    mas -- y `lua/phantasmagoria/` no esta en esa lista. Una carpeta propia
    adentro de `lua/` no corre sola: hay que incluirla desde algo que si corra.

    Y no habia nada: el grep de `include(` y `AddCSLuaFile` sobre TODO el addon
    daba dos lineas, las dos `AddCSLuaFile()` de las armas. Medido el 2026-08-08.

    LO QUE ESTABA MUERTO, Y NO ERA SOLO "DATOS SIN USAR":

      ghost_types.lua   los 30 tipos generados del juego, con `hunt.threshold`
                        en los 30 y `speed.base` en los 30. PHANTASMAGORIA.Types
                        no existia en runtime -- o sea que §19 ( la cordura
                        dispara el hunt cuando se cruza el threshold DEL TIPO )
                        no se podia ni empezar a escribir.

      prop_data.lua     ⚠ ESTO NO ES DATO, ES COMPORTAMIENTO. Registra un hook
                        `PlayerSpawnedProp` que corrige la masa de los props del
                        pack, y su propio comentario dice para que: "sin esto, un
                        jugador que saque el crucifijo del Prop Pack desde el
                        spawnmenu se lleva la tonelada". Esa red de seguridad
                        NUNCA CORRIO.

    *Un archivo que existe no es un archivo que corre, y un `require` que nadie
    escribio no falla: simplemente no pasa nada.* Los dos archivos parsean, los
    dos estan bien escritos, y los dos estaban apagados -- que es justo el modo
    de falla que no tira error ni deja rastro.

    QUE HACE ESTE ARCHIVO Y QUE NO:

    Incluye, y nada mas. No define nada propio a proposito: si manana hay que
    saber por que un dato esta o no esta, la respuesta tiene que ser "mira la
    lista de este archivo" y no "lee cinco archivos a ver cual lo toca".

    LOS DOS VAN EN LOS DOS REALMS, y no es por las dudas:

      Types      el HUD de cordura ( §19.3 ) y las pantallas del camion son
                 CLIENTE, y van a necesitar el nombre y el threshold del tipo.
      PropData   el hook de adentro ya se guarda solo con `if SERVER`, asi que
                 incluirlo en cliente cuesta la tabla y nada mas -- y la tabla
                 sirve para dibujar.

    El AddCSLuaFile va aparte del include porque son dos cosas distintas:
    manda el archivo al cliente ( para el que instalo el addon solo en el
    servidor ) y ejecutarlo aca son pasos independientes.
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

-- El orden importa poco hoy -- ninguno de los dos lee al otro -- pero se declara
-- una sola vez y en un solo lugar, que es el punto entero del archivo.
--
-- ⚠ SALVO UN PAR, Y AHI EL ORDEN ES OBLIGATORIO: prop_data_eq.lua FUSIONA sobre
-- PHANTASMAGORIA.PropData, y prop_data.lua ASIGNA esa tabla entera
-- ( `PropData = { ... }` ). Al reves, el segundo pisaria los 66 modelos propios
-- y no habria ni un error: la tabla existiria, con las entradas de terceros
-- adentro, y el unico sintoma seria equipamiento nuestro pesando 1,5 kg. La
-- columna `propios` de la guarda de abajo mide justamente eso.
local DATOS = {
    "phantasmagoria/ghost_types.lua",
    "phantasmagoria/prop_data.lua",

    -- Los 66 modelos NUESTROS de equipamiento. Aparte de prop_data.lua a
    -- proposito: ese archivo tiene las entradas de los packs de TERCEROS y las
    -- retira OTRA sesion cuando termine de reemplazar los modelos. La division
    -- es por PROCEDENCIA -- lo nuestro aca, lo ajeno alla -- y en runtime se
    -- fusionan en un solo diccionario, asi que ApplyPropData sigue leyendo un
    -- solo lugar. VA DESPUES de prop_data.lua ( ver el aviso de arriba ).
    "phantasmagoria/prop_data_eq.lua",

    -- ⚠ ESTE NO ES UN DATO, Y ROMPE LA REGLA DE ARRIBA A PROPOSITO. Es el anillo
    -- de actividades ( el instrumento de la pose T ). Vive aca y no adentro del
    -- ENT porque `luaharness.py` no puede cargar
    -- terminator_nextbot_phantom/server.lua -- no parsea el `continue` de GMod --
    -- y un instrumento que no se puede ejercitar fuera del juego ya costo una
    -- ronda entera en este arco ( ph_ghost_costura ).
    --
    -- En los DOS realms: el ENT lo escribe desde el servidor, y el conteo del
    -- cargador de abajo lo mira en los dos.
    "phantasmagoria/actlog.lua",
}

if SERVER then
    for _, ruta in ipairs( DATOS ) do
        AddCSLuaFile( ruta )

    end
end

for _, ruta in ipairs( DATOS ) do
    include( ruta )

end

---------------------------------------------------------------------------
-- LA GUARDA, porque este archivo ya fallo una vez POR NO EXISTIR
---------------------------------------------------------------------------
-- Un include que no encuentra el archivo tira error de Lua y se ve. Lo que NO
-- se ve es lo que acaba de pasar durante ocho rondas: que el include no este.
-- Esta guarda no puede detectar eso -- si este archivo no corre, la guarda
-- tampoco -- pero si detecta el otro modo: que el archivo corra y lo que
-- adentro tenia que definirse no se haya definido ( un rename, un `return`
-- temprano, un error a mitad ).
--
-- Cuenta y dice el NUMERO, no un booleano: `Types existe` no distingue una
-- tabla con los 30 tipos de una tabla vacia, y ese es exactamente el
-- discriminante que este proyecto ya pago caro en otros bloques.
local function contar( t )
    if not istable( t ) then return nil end

    local n = 0
    for _ in pairs( t ) do n = n + 1 end

    return n

end

--
-- ⚠ Y HABLA TAMBIEN CUANDO TODO ESTA BIEN, que es una correccion del 2026-08-08:
-- la version anterior hacia `return` en silencio en el caso bueno. O sea que la
-- consola de un servidor sano y la de uno donde este archivo NO CORRIO se veian
-- EXACTAMENTE IGUAL -- y "no corrio" es el unico defecto que este archivo existe
-- para no repetir. *Una guarda que solo habla cuando falla no puede acreditar
-- que corrio: su silencio es el sintoma del defecto que vigila.* Ahora la
-- ausencia de la linea del conteo ES la evidencia.
--
-- El REALM va en la linea por el mismo motivo: el cargador corre en los dos y la
-- falla interesante es de un solo lado ( el cliente sin los 30 tipos deja el
-- marcador diciendo la key cruda, sin ficha ). Con una sola linea sin realm, dos
-- consolas distintas se leen como una.
-- ⚠ CADA ARCHIVO DE `DATOS` TIENE QUE TENER SU COLUMNA ACA. Un archivo nuevo en
-- la lista de arriba sin una linea aca queda vigilado por nadie, y el cargador
-- seguiria imprimiendo su verde: el conteo diria "2 tipos, 9 modelos" con el
-- tercer archivo caido. Eso no es un verde parcial, es un verde equivocado.
hook.Add( "Initialize", "phantasmagoria_datos_cargados", function()
    local tipos = contar( PHANTASMAGORIA.Types )
    local props = contar( PHANTASMAGORIA.PropData )
    -- ActUniverse es la tabla, pero lo que el ENT llama son las FUNCIONES. Se
    -- comprueba una de cada: una tabla presente con las funciones sin definir
    -- seria un archivo que se corto a la mitad, y el ENT reventaria recien al
    -- primer evento -- o sea en juego y sin que nada lo anticipe.
    local acts = contar( PHANTASMAGORIA.ActUniverse )
    local pushOk = isfunction( PHANTASMAGORIA.PushActLog )
    local realm = SERVER and "server" or "cliente"

    -- ⚠ ESTA COLUMNA NO CUENTA SU PROPIA TABLA, y esa es toda la gracia. Contar
    -- PropDataEq diria 66 aunque prop_data.lua hubiera corrido despues y hubiera
    -- pisado PropData entera: la tabla de origen seguiria ahi, intacta y sin que
    -- nadie la lea. Lo que hay que medir es cuantas SOBREVIVIERON en la tabla
    -- que ApplyPropData consulta de verdad. *Una guarda que mide la fuente en
    -- vez del destino da verde justo en el modo de falla que existe para
    -- atajar.*
    local propios, propiosVivos = contar( PHANTASMAGORIA.PropDataEq ), 0

    if istable( PHANTASMAGORIA.PropDataEq ) and istable( PHANTASMAGORIA.PropData ) then
        for ruta in pairs( PHANTASMAGORIA.PropDataEq ) do
            if PHANTASMAGORIA.PropData[ ruta ] then propiosVivos = propiosVivos + 1 end

        end
    end

    if tipos and tipos > 0 and props and props > 0 and acts and acts > 0 and pushOk
        and propios and propios > 0 and propiosVivos == propios then

        MsgC( Color( 190, 120, 255 ), "[Phantasmagoria] ", color_white,
            "datos cargados en ", realm, ": ", tipos, " tipos · ", props, " modelos ( ",
            propios, " propios ) · ", acts, " actividades vigiladas.\n" )

        return

    end

    ErrorNoHalt( "[Phantasmagoria] LOS DATOS NO CARGARON BIEN en " .. realm .. ": " ..
        "Types " .. ( tipos and ( tipos .. " tipos" ) or "NO EXISTE" ) ..
        " · PropData " .. ( props and ( props .. " modelos" ) or "NO EXISTE" ) ..
        " · propios " .. ( propios and ( propiosVivos .. " de " .. propios .. " vivos en PropData" ) or "NO EXISTE" ) ..
        " · ActUniverse " .. ( acts and ( acts .. " actividades" ) or "NO EXISTE" ) ..
        " · PushActLog " .. ( pushOk and "OK" or "NO EXISTE" ) ..
        ".  Los tipos los necesita la cordura ( threshold por tipo ), PropData corrige la masa " ..
        "de los props, y el actlog es el instrumento de la pose T." ..
        ( ( propios and propiosVivos < propios ) and
            "  ⚠ 'propios' por debajo del total significa que prop_data.lua corrio DESPUES y piso la tabla: mirar el orden de DATOS." or "" ) .. "\n" )

end )
