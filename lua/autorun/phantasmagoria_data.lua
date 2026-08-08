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
local DATOS = {
    "phantasmagoria/ghost_types.lua",
    "phantasmagoria/prop_data.lua",
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

hook.Add( "Initialize", "phantasmagoria_datos_cargados", function()
    local tipos = contar( PHANTASMAGORIA.Types )
    local props = contar( PHANTASMAGORIA.PropData )

    if tipos and tipos > 0 and props and props > 0 then return end

    ErrorNoHalt( "[Phantasmagoria] LOS DATOS NO CARGARON BIEN: " ..
        "Types " .. ( tipos and ( tipos .. " tipos" ) or "NO EXISTE" ) ..
        " · PropData " .. ( props and ( props .. " modelos" ) or "NO EXISTE" ) ..
        ".  Los tipos los necesita la cordura ( threshold por tipo ) y PropData corrige la masa " ..
        "de los props del pack.\n" )

end )
