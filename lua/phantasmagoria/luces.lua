--[[-------------------------------------------------------------------------
    Phantasmagoria - LAS SEIS CLASES DE LUZ, EN UN SOLO LUGAR

    Tajada B2 de la cordura ( Diseno 19.8 ). Este archivo no existia: la lista
    vivia `local` adentro de server_events.lua y `phantasmagoria_sanity.lua`
    tenia una COPIA de los nombres, declarada como copia en su propio comentario
    y acotada a lo unico que no podia producir un falso verde -- alimentaba el
    contador del punto ciego y nada mas.

    ⚠ POR QUE SE SUBE, Y NO ES PROLIJIDAD. Los dos consumidores contestan
    preguntas distintas sobre EL MISMO universo:

      server_events.lua   ¿que luz puedo TOCAR para el evento `light`?
      la cordura          ¿este jugador esta ILUMINADO?  ( §19.9.2, opcion B )

    Con dos listas, una clase agregada en una y no en la otra da dos universos
    que se leen como uno. Y la asimetria es la peor posible: la lista de la
    cordura, al envejecer, reporta el punto ciego MAS CHICO de lo que es -- o
    sea que el instrumento que existe para medir lo que no se puede leer
    subdeclara justo eso. El propio comentario de B1 lo dejo escrito y le puso
    fecha de vencimiento: *"B2 -- que si toca ese archivo -- tiene que subir
    LIGHT_CLASSES a lua/phantasmagoria/ y borrar esta copia."*

    --------------------------------------------------------------------------
    ⚠⚠ `leer` NO ES `como`, Y CONFUNDIRLOS ES EL PUNTO CIEGO ENTERO
    --------------------------------------------------------------------------
    Son dos ejes independientes y el archivo los declara por separado:

      como   COMO SE LA CONMUTA. Es lo que le importa a EV.light.
      leer   SI SU ESTADO SE PUEDE PREGUNTAR. Es lo que le importa a la cordura.

    De las seis clases, DOS se pueden leer y son las de sandbox. Las otras
    cuatro se conmutan por input del engine y no exponen getter: `light`,
    `light_spot`, `point_spotlight`, `light_dynamic` y `env_projectedtexture`
    -- o sea que un mapa iluminado por sus PROPIAS luces se lee igual que uno
    de iluminacion horneada, que es el defecto que §19.9.2 acepto por escrito
    al elegir la opcion B.

    Lo que B2 cambia NO es esa aceptacion: es que el resultado deje de tener
    DOS estados donde hay TRES. Ver `PHANTASMAGORIA.LuzEncendida`.
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

PHANTASMAGORIA.LightClasses = {
    -- ( 1 ) Las lamparas de sandbox. Son SENTs de Lua con getter y setter
    -- propios, y son las mas probables en un servidor de GMod porque las pone
    -- el jugador. HIM las trata igual ( server.lua:494-495 ).
    -- SON LAS UNICAS DOS QUE SE PUEDEN LEER.
    { clase = "gmod_light",           como = "seton",       leer = "GetOn" },
    { clase = "gmod_lamp",            como = "seton",       leer = "GetOn" },

    -- ( 2 ) Las del mapa que sobrevivieron al compilado por tener targetname.
    { clase = "light",                como = "toggle",      leer = false },
    { clase = "light_spot",           como = "toggle",      leer = false },

    -- ( 3 ) ⚠ Esta NO responde a `Toggle`: su input se llama `LightToggle`.
    -- Es una asimetria del engine y HIM la trata aparte ( server.lua:500 ).
    --
    -- ⚠⚠ EL NOMBRE DEL INPUT NO ESTA MEDIDO, Y SU UNICA FUENTE ES HIM. Grep de
    -- `LightToggle` sobre todo el workspace: cuatro apariciones, tres de HIM y
    -- esta. Cero apariciones de `LightOn` / `LightOff`, que es como se llaman
    -- los inputs de CPointSpotlight en Source. O sea que este renglon es un
    -- comentario de un tercero COPIADO.
    --
    -- No se cambia sobre memoria -- eso seria el mismo pecado del otro lado --
    -- pero el reporte no afirma que conmuto: `Entity:Fire` con un input que la
    -- clase no acepta **no tira error**, `AcceptInput` devuelve false en
    -- silencio. Se mide con una linea en juego, y esta anotado en la planilla.
    { clase = "point_spotlight",      como = "lighttoggle", leer = false },

    -- ( 4 ) Las dinamicas y los proyectores, que si o si existen en runtime
    -- porque no se pueden hornear.
    { clase = "light_dynamic",        como = "onoff",       leer = false },
    { clase = "env_projectedtexture", como = "onoff",       leer = false },
}

---------------------------------------------------------------------------
-- ¿ES SUJETO? -- la pregunta de EV.light
---------------------------------------------------------------------------
-- Las de sandbox son SENTs de Lua: si no traen su getter y su setter no se las
-- puede ni leer ni tocar, asi que no son sujeto. Las otras cuatro clases se
-- manejan por input del engine y no necesitan nada.
--
-- ⚠ Vive aca y no duplicada en los dos barridos de server_events.lua porque el
-- censo global y la busqueda cercana tienen que compartir el CRITERIO y no solo
-- la lista: *un instrumento que mide una lista distinta de la que usa el sujeto
-- no lo esta midiendo a el* -- y compartir la lista sin el filtro ya dio, una
-- ronda atras, un "no habia luces a 450 u ( en TODO el mapa hay 1 y la mas
-- cercana esta a 30 u )".
function PHANTASMAGORIA.LuzUtilizable( fam, ent )
    if not istable( fam ) or not IsValid( ent ) then return false end
    if fam.como ~= "seton" then return true end

    return isfunction( ent.SetOn ) and isfunction( ent.GetOn )

end

---------------------------------------------------------------------------
-- ¿ESTA ENCENDIDA? -- la pregunta de la cordura, y son TRES respuestas
---------------------------------------------------------------------------
-- ⚠⚠⚠ DEVUELVE `nil` Y ESO NO ES UN ERROR: ES LA TERCERA RESPUESTA.
--
--     true    encendida   ( medido )
--     false   apagada     ( medido )
--     nil     NO SE PUEDE PREGUNTAR
--
-- El defecto que esto cierra estaba vivo y avisado: `IsPlayerLit` devolvia un
-- BOOLEANO, asi que "apagada" y "no se puede leer" salian las dos por el mismo
-- `false`, y el modulador de §19.9.2 le cobraba el x1,5 de la oscuridad a las
-- dos por igual. Con 25 luces sin getter en el mapa de prueba, eso es *un tercio
-- del drenaje decidido sobre una lectura que el propio instrumento declara que
-- no puede hacer*.
--
-- ⚠ Y el `nil` NO SE REEMPLAZA POR UN VALOR, NI DEL LADO SEGURO. Un fallback
-- booleano -- de cualquiera de los dos lados -- es el defecto nº 112b del
-- catalogo: *el fallback de una guarda no puede ser un valor del mismo tipo que
-- el resultado valido, porque se imprime con la misma cara*. Quien llama decide
-- que hacer con la ausencia, y la cordura le puso su propia perilla y su propio
-- renglon del desglose para poder medirla.
function PHANTASMAGORIA.LuzEncendida( fam, ent )
    if not istable( fam ) or not IsValid( ent ) then return nil end
    if not fam.leer then return nil end

    -- El nombre del getter sale del DATO y no de un `if` por clase: el dia que
    -- una clase nueva traiga otro nombre, se agrega arriba y esto no cambia.
    local fn = ent[ fam.leer ]
    if not isfunction( fn ) then return nil end

    return fn( ent ) == true

end

---------------------------------------------------------------------------
-- LA GUARDA: que `leer` nombre un getter que exista de verdad
---------------------------------------------------------------------------
-- Modo de falla que ataja: alguien escribe `leer = "GetEnabled"` sobre una clase
-- cuyo SENT expone `GetOn`. No hay error -- `LuzEncendida` devuelve nil -- y el
-- unico sintoma es que esa clase se suma al punto ciego para siempre, o sea que
-- el instrumento se degrada EN LA DIRECCION DE SU PROPIO MODO DE FALLA y nadie
-- lo nota. Se comprueba sobre entidades REALES y no sobre la tabla: la tabla no
-- sabe que metodos tiene un SENT.
--
-- ⚠ Corre en `InitPostEntity` y no al cargar: al cargar no hay ni una entidad
-- del mapa spawneada, asi que un barrido daria cero sujetos y el silencio se
-- leeria como "todo bien" -- que es el nº 93, una ausencia sola no discrimina.
if SERVER then
    hook.Add( "InitPostEntity", "phantasmagoria_luces_getter", function()
        local rotas, vistas = {}, 0

        for _, fam in ipairs( PHANTASMAGORIA.LightClasses ) do
            if not fam.leer then continue end

            for _, ent in ipairs( ents.FindByClass( fam.clase ) ) do
                if not IsValid( ent ) then continue end

                vistas = vistas + 1

                -- `LuzUtilizable` ya descarta el SENT roto, que es un caso
                -- legitimo y NO es un error de la tabla. Lo que se busca aca es
                -- el otro: el SENT sano cuyo getter se llama distinto de como
                -- dice `leer`.
                if PHANTASMAGORIA.LuzUtilizable( fam, ent ) and not isfunction( ent[ fam.leer ] ) then
                    rotas[ fam.clase ] = ( rotas[ fam.clase ] or 0 ) + 1

                end
            end
        end

        if not next( rotas ) then return end

        local partes = {}
        for clase, n in pairs( rotas ) do partes[ #partes + 1 ] = clase .. " x" .. n end
        table.sort( partes )

        ErrorNoHalt( "[Phantasmagoria] luces.lua: el campo `leer` de " .. table.concat( partes, ", " ) ..
            " nombra un getter que esas entidades NO TIENEN ( se miraron " .. vistas .. " ). " ..
            "No hay error visible: esas luces pasan a contar como CIEGAS para siempre y el punto " ..
            "ciego de la cordura se reporta mas grande de lo que es.\n" )

    end )
end
