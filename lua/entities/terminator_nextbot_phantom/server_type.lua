--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom / EL TIPO DE FANTASMA

    TAJADA A DE LA CORDURA ( Diseno 19 ). Las tres, en orden, y esta es la
    primera:

      A  el TIPO      asignarlo al spawnear, networkearlo, poder forzarlo  <-- esto
      B  la CORDURA   por jugador, en el servidor, con sus causas
      C  el GATILLO   cordura por debajo del hunt.threshold DEL TIPO

    Por que el tipo va primero y no es un rodeo: el gatillo de C no compara la
    cordura contra un numero fijo, la compara contra `hunt.threshold`, que es un
    dato DEL TIPO ( Demon 70, Shade 35, Deogen 40 ). Sin un tipo asignado, C no
    tiene contra que comparar y B mediria una barra que no dispara nada.

    LO QUE ESTE ARCHIVO HACE, Y LO QUE NO:

      SI   elige un tipo al spawnear, lo guarda, lo networkea y lo publica en
           los instrumentos. Un DATO y su plomeria.

      NO   no cambia NI UN comportamiento. speed.base esta en los 30 tipos y
           server_speed.lua ya sabe leer un campo `phantom_SpeedMul` que GANA
           sobre la convar andamio... y este archivo NO lo escribe, a proposito.
           Escribirlo aca haria que la velocidad de todos los fantasmas cambiara
           de golpe, sin A/B, en la misma ronda que estrena el mecanismo que la
           decide. *Un rojo de velocidad en esta ronda seria imposible de
           atribuir.* Lo escribe la tajada de Diseno 5, con su propia planilla, y
           el enganche es una linea.

    LOS TRES ORIGENES DEL TIPO, EN ORDEN DE PRIORIDAD, Y NINGUNO ES SILENCIOSO:

      1  el OVERRIDE de consola   phantasmagoria_ghost_type <key>   ( ANDAMIO )
      2  el campo de la CLASE     ENT.PhantomType, que es como Diseno 12.2 va a
                                  generar los 30 NPCs del spawnmenu
      3  el SORTEO                entre los 30, que es lo que el juego hace

    El motivo del que gano se guarda en el NPC y se imprime al lado del tipo. Sin
    eso, "salio Oni" no distingue un sorteo de un override olvidado de la corrida
    anterior -- y los overrides de este addon sobreviven al respawn a proposito
    ( la leccion de la ronda 3 ), asi que olvidarse uno puesto es facil.
---------------------------------------------------------------------------]]

---------------------------------------------------------------------------
-- Las perillas
---------------------------------------------------------------------------
-- EL CONTROL NEGATIVO DEL BLOQUE, y no es decoracion: en 0 el fantasma spawnea
-- SIN TIPO, que es exactamente el estado de ayer. Sirve para dos cosas
-- distintas y las dos hacen falta:
--
--   ( a ) probar que la linea de tipo en ghost_where sale del mecanismo y no de
--         un default escrito en el instrumento;
--   ( b ) probar que el instrumento SABE DECIR "sin tipo". Un reporte que sólo
--         se probo con el mecanismo andando no distingue "no hay tipo" de "no
--         mire". Ese es el modo de falla que este proyecto ya pago varias veces.
local cvAssign = CreateConVar( "phantasmagoria_ghost_typeassign", "1", FCVAR_ARCHIVE,
    "El fantasma elige un tipo de los 30 al spawnear ( Diseno 19, tajada A ). En 0 spawnea SIN TIPO, que es el estado anterior a este bloque: es el control negativo.", 0, 1 )

-- ANDAMIO, y sobrevive al respawn como los otros overrides de este addon. El
-- motivo esta medido en la ronda 3: un lua_run escribe en LA ENTIDAD, y el
-- fantasma siguiente nace con el default -- el cambio se perdia sin que nada lo
-- dijera. Se borra con `phantasmagoria_ghost_type auto`.
--
-- Nace nil y se declara aca igual: asi el campo existe en un lugar que se puede
-- grepear, en vez de aparecer por primera vez adentro del comando que lo escribe.
PHANTASMAGORIA.TypeOverride = PHANTASMAGORIA.TypeOverride

---------------------------------------------------------------------------
-- LA GUARDA DE LAS DOS LISTAS, que es la que puede fallar en silencio
---------------------------------------------------------------------------
-- ghost_types.lua declara DOS cosas: la tabla `Types` ( con clave ) y el array
-- `TypeOrder` ( el indice estable para UI y para el SORTEO ). El sorteo recorre
-- el array; todo lo demas lee la tabla.
--
-- Si las dos se desincronizan -- y el archivo es GENERADO, o sea que se
-- regenera -- pasa esto:
--
--   en Types y NO en TypeOrder   el tipo existe y NUNCA sale sorteado. 29 de 30.
--   en TypeOrder y NO en Types   el sorteo devuelve una key que no resuelve a
--                                nada, y el fantasma sale sin ficha.
--
-- Ninguno de los dos tira un error. El primero es peor: se ve igual que un
-- sorteo con suerte, y sólo se nota contando cientos de spawns. Por eso la
-- comparacion se hace al cargar y se dice el numero.
local function auditarListas()
    local T     = PHANTASMAGORIA.Types
    local orden = PHANTASMAGORIA.TypeOrder

    if not istable( T ) or not istable( orden ) then
        return nil, "PHANTASMAGORIA.Types o .TypeOrder no existen ( lua/autorun/phantasmagoria_data.lua no cargo )"

    end

    local enOrden = {}
    local huerfanas, faltantes = {}, {}

    for _, key in ipairs( orden ) do
        enOrden[ key ] = true
        if not T[ key ] then table.insert( huerfanas, key ) end

    end

    for key in pairs( T ) do
        if not enOrden[ key ] then table.insert( faltantes, key ) end

    end

    table.sort( huerfanas )
    table.sort( faltantes )

    return { huerfanas = huerfanas, faltantes = faltantes, nTypes = table.Count( T ), nOrden = #orden }

end

PHANTASMAGORIA.AuditarTipos = auditarListas

hook.Add( "Initialize", "phantasmagoria_tipos_sincronizados", function()
    local a, err = auditarListas()

    if not a then
        ErrorNoHalt( "[Phantasmagoria] EL SORTEO DE TIPOS NO PUEDE FUNCIONAR: " .. err .. ".\n" )
        return

    end

    if #a.huerfanas <= 0 and #a.faltantes <= 0 then return end

    ErrorNoHalt( "[Phantasmagoria] Types y TypeOrder NO COINCIDEN ( " .. a.nTypes .. " tipos, " .. a.nOrden ..
        " en el orden ). Sorteables pero sin ficha: " .. ( #a.huerfanas > 0 and table.concat( a.huerfanas, ", " ) or "ninguno" ) ..
        ".  Con ficha pero NUNCA sorteables: " .. ( #a.faltantes > 0 and table.concat( a.faltantes, ", " ) or "ninguno" ) ..
        ".  Regenerar con dev/gen_types.py.\n" )

end )

---------------------------------------------------------------------------
-- Elegir
---------------------------------------------------------------------------
-- El sorteo recorre TypeOrder y no `pairs( Types )` a proposito: pairs no tiene
-- orden definido, asi que un sorteo escrito sobre el hash seria irreproducible
-- entre corridas y no habria forma de contarlo. Con el array, "el tercero" es
-- siempre el mismo tercero.
function PHANTASMAGORIA.SortearTipo()
    local orden = PHANTASMAGORIA.TypeOrder
    if not istable( orden ) or #orden <= 0 then return nil end

    local T = PHANTASMAGORIA.Types
    if not istable( T ) then return nil end

    -- Un solo tiro, y si la key no resuelve se devuelve igual: la guarda de
    -- arriba ya grito, y tapar el hueco aca -- reintentando hasta que salga una
    -- buena -- convertiria una lista rota en un sorteo sesgado invisible.
    return orden[ math.random( #orden ) ]

end

-- Devuelve: key, motivo. Los dos se guardan en el NPC porque el segundo es lo
-- que hace legible al primero.
function PHANTASMAGORIA.ResolveTypeKey( ent )
    local T = PHANTASMAGORIA.Types

    if not istable( T ) or table.Count( T ) <= 0 then
        return nil, "PHANTASMAGORIA.Types no cargo ( ver lua/autorun/phantasmagoria_data.lua )"

    end

    local ov = PHANTASMAGORIA.TypeOverride

    if ov then
        if T[ ov ] then return ov, "override de consola ( ANDAMIO: phantasmagoria_ghost_type )" end

        -- No se cae al sorteo callado: el que puso el override espera ESE tipo.
        return nil, "el override de consola pide '" .. tostring( ov ) .. "' y ese tipo NO EXISTE"

    end

    -- Diseno 12.2: los 30 NPCs del spawnmenu se generan con ENT.PhantomType = key
    -- sobre esta misma base. Hoy no existe ninguno, asi que esta rama esta
    -- escrita y sin ejercer -- y por eso se puede probar a mano con un lua_run
    -- sobre la entidad, que es lo que hace la fila del check.
    local declarado = ent.PhantomType

    if declarado then
        if T[ declarado ] then return declarado, "campo de la clase ENT.PhantomType ( Diseno 12.2 )" end

        -- Grita Y sortea: un fantasma sin tipo no puede cazar nunca ( tajada C ),
        -- asi que dejarlo sin tipo por un error de tipeo de otro archivo es peor
        -- que darle uno. Pero el motivo viaja con el, y se lee en ghost_where.
        ErrorNoHalt( "[Phantasmagoria] la clase '" .. ent:GetClass() .. "' declara PhantomType = '" ..
            tostring( declarado ) .. "' y ese tipo no existe en PHANTASMAGORIA.Types. Se sortea uno.\n" )

        local key = PHANTASMAGORIA.SortearTipo()

        return key, "SORTEADO -- la clase pedia '" .. tostring( declarado ) .. "' y ese tipo no existe"

    end

    local key = PHANTASMAGORIA.SortearTipo()
    if not key then return nil, "el sorteo no devolvio nada ( TypeOrder vacia )" end

    return key, "sorteado entre los " .. #PHANTASMAGORIA.TypeOrder

end

---------------------------------------------------------------------------
-- Ponerselo, y networkearlo
---------------------------------------------------------------------------
-- LA PUERTA UNICA, igual que phantom_SetHunting: el dia que la tajada C lea el
-- threshold, lo va a leer del campo, y el cliente lo va a leer del NW var. Si
-- alguien escribe `ghost.phantom_TypeKey = "oni"` a mano, los dos se separan y
-- el sintoma es un HUD que dice otro tipo que el que caza.
--
-- SetNWString y NO SetupDataTables, por el mismo motivo que el hunt: la base
-- networkea con slots hardcodeados ( Referencia 4.3, trampa 3 ). Los NW vars van
-- por nombre y son otro sistema.
--
-- Viaja la KEY y no la ficha: los 30 tipos ya estan en el cliente -- el cargador
-- los incluye en los dos realms a proposito -- asi que mandar el nombre, el
-- threshold y las evidencias seria mandar por la red algo que el cliente ya
-- tiene. Y hace de prueba cruzada: si el cliente resuelve la key a una ficha, el
-- cargador corrio en cliente.
function ENT:phantom_SetType( key, motivo )
    local T = PHANTASMAGORIA.Types
    local data = istable( T ) and key and T[ key ] or nil

    self.phantom_TypeKey = data and key or nil
    self.phantom_Type    = data
    self.phantom_TypeWhy = motivo or "( sin motivo declarado )"

    -- La cadena vacia y no nil: GetNWString del cliente devuelve el default
    -- cuando nunca se escribio, y "nunca se escribio" y "se escribio vacio" son
    -- dos estados distintos que en la fila del networkeo hay que poder separar.
    self:SetNWString( "phantasmagoria_type", self.phantom_TypeKey or "" )

    return self.phantom_TypeKey

end

function ENT:phantom_GetType()
    return self.phantom_Type

end

-- El numero que la tajada C va a comparar contra la cordura. Se expone ahora
-- -- aunque nadie lo llame todavia -- porque es el unico consumidor declarado
-- del dato, y tenerlo escrito hace que la fila del check pueda pedirlo por
-- nombre en vez de leer la tabla a mano.
--
-- Devuelve nil sin tipo, y NO un default de 50: un fantasma sin tipo no tiene
-- que cazar al 50 %, tiene que no cazar y que se vea. *Un default plausible en
-- el lugar de un dato faltante es un check verde sobre un mecanismo apagado.*
function ENT:phantom_HuntThreshold()
    local t = self.phantom_Type

    return t and t.hunt and t.hunt.threshold or nil

end

-- Llamado desde AdditionalInitialize ( server.lua ). Aparte de el a proposito:
-- asi el comando puede re-resolver un fantasma vivo sin duplicar la logica.
function ENT:phantom_ResolveType()
    if not cvAssign:GetBool() then
        self:phantom_SetType( nil, "phantasmagoria_ghost_typeassign 0 ( CONTROL: no se asigna tipo )" )
        return nil

    end

    local key, motivo = PHANTASMAGORIA.ResolveTypeKey( self )

    return self:phantom_SetType( key, motivo )

end

---------------------------------------------------------------------------
-- La linea que va en los instrumentos
---------------------------------------------------------------------------
-- Compartida porque la imprimen dos comandos distintos y ya hubo un caso en este
-- addon de dos impresiones del mismo dato divergiendo.
--
-- ⚠ DICE QUE speed.base NO ESTA APLICADO, y esa aclaracion es el punto de la
-- linea. Sin ella, leer "speed.base 0.900" al lado de la velocidad se entiende
-- como que el fantasma ya va al 0,9 -- y no: el multiplicador que manda hoy
-- sigue siendo la convar andamio. *Una linea que muestra un dato que todavia no
-- se usa tiene que decir que no se usa, o se lee como que si.*
function PHANTASMAGORIA.TypeLines( ghost, say )
    local t = ghost.phantom_Type

    if not t then
        say( "    tipo    SIN TIPO   ( " .. tostring( ghost.phantom_TypeWhy or "nunca se resolvio: phantom_ResolveType no corrio" ) .. " )" )
        return

    end

    say( "    tipo    " .. t.name .. "   ( " .. tostring( ghost.phantom_TypeKey ) .. " )" ..
        "   threshold " .. tostring( ghost:phantom_HuntThreshold() ) .. " %" ..
        "   speed.base x" .. string.format( "%.3f", t.speed and t.speed.base or 0 ) .. " ( NO aplicado todavia )" )

    say( "            lo eligio: " .. tostring( ghost.phantom_TypeWhy ) ..
        "   ·  networkeado como '" .. ghost:GetNWString( "phantasmagoria_type", "" ) .. "'" )

end

---------------------------------------------------------------------------
-- El boton, y se niega
---------------------------------------------------------------------------
-- Cinco formas, y las cuatro ultimas existen porque la primera no puede
-- contestarlas:
--
--   ( sin args )        la ficha de cada fantasma vivo + el estado del override
--   <key>               fuerza ese tipo: override + los vivos
--   random              saca el override y RE-SORTEA a cada vivo
--   auto                saca el override y no toca a nadie mas
--   sorteo [N]          N sorteos SIN SPAWNEAR NADA, con la distribucion
--   lista               los 30, con su threshold
--
-- `sorteo` es el que mide el sorteo de verdad. Contar tipos spawneando fantasmas
-- cuesta un spawn por muestra y no llega a ninguna N util; este hace 300 tiros
-- en un frame y dice CUANTOS DISTINTOS SALIERON. Un sorteo roto -- clavado en
-- uno, o cubriendo 12 de 30 porque TypeOrder quedo corta -- se ve en ese numero
-- y en ningun otro lado.
local function adminOnly( ply )
    if not IsValid( ply ) then return true end
    if ply:IsAdmin() then return true end

    ply:PrintMessage( HUD_PRINTCONSOLE, "[Phantasmagoria] hace falta ser admin." )
    return false

end

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_type", function( ply, _, args )
    if not adminOnly( ply ) then return end

    local say = PHANTASMAGORIA.MakeSay( ply )
    local sub = args and args[ 1 ] and string.lower( args[ 1 ] )
    local T   = PHANTASMAGORIA.Types

    -- LA PRIMERA LINEA DICE CON QUE ESTA MIDIENDO, siempre, y en este bloque eso
    -- no es formalidad: el defecto que abrio la sesion fue que esta tabla no
    -- existia en runtime, y ningun comando lo habria dicho.
    local a = PHANTASMAGORIA.AuditarTipos()

    if not a then
        say( "[Phantasmagoria] PHANTASMAGORIA.Types NO EXISTE en runtime. Sin eso no hay tipos, " ..
            "no hay sorteo y la cordura no tiene contra que comparar." )
        say( "    lo carga lua/autorun/phantasmagoria_data.lua. Si ese archivo no esta o no corrio, " ..
            "el error de arriba es el sintoma y este comando no puede hacer nada." )
        return

    end

    say( "[Phantasmagoria] " .. a.nTypes .. " tipos cargados · " .. a.nOrden .. " en el orden de sorteo" ..
        ( ( #a.huerfanas > 0 or #a.faltantes > 0 ) and "   !! LAS DOS LISTAS NO COINCIDEN" or "" ) )
    say( "    asignacion al spawnear: " .. ( cvAssign:GetBool() and "ENCENDIDA" or "APAGADA ( typeassign 0: spawnean SIN TIPO )" ) ..
        "   ·  override: " .. ( PHANTASMAGORIA.TypeOverride and ( "'" .. PHANTASMAGORIA.TypeOverride .. "'" ) or "ninguno ( sortea )" ) )

    ---------------------------------------------------------------------------
    if sub == "lista" then
        for _, key in ipairs( PHANTASMAGORIA.TypeOrder or {} ) do
            local t = T[ key ]

            say( "    " .. key .. string.rep( " ", math.max( 1, 14 - #key ) ) ..
                ( t and ( t.name .. string.rep( " ", math.max( 1, 14 - #t.name ) ) ..
                    "threshold " .. tostring( t.hunt and t.hunt.threshold ) .. " %" ..
                    "   speed.base x" .. string.format( "%.3f", t.speed and t.speed.base or 0 ) ..
                    ( t.hunt and t.hunt.thresholdLow and t.hunt.thresholdHigh and ( "   rango " .. t.hunt.thresholdLow .. "-" .. t.hunt.thresholdHigh .. " % ( Diseno 5.2, NO se usa todavia )" ) or "" ) )
                or "!! SIN FICHA: esta en TypeOrder y no en Types" ) )

        end

        return

    end

    ---------------------------------------------------------------------------
    if sub == "sorteo" then
        local n = math.Clamp( tonumber( args[ 2 ] ) or 300, 1, 100000 )
        local cuenta, distintos = {}, 0
        local peor, mejor

        for _ = 1, n do
            local key = PHANTASMAGORIA.SortearTipo() or "( nil )"

            if not cuenta[ key ] then distintos = distintos + 1 end
            cuenta[ key ] = ( cuenta[ key ] or 0 ) + 1

        end

        for key, veces in pairs( cuenta ) do
            if not mejor or veces > cuenta[ mejor ] then mejor = key end
            if not peor  or veces < cuenta[ peor  ] then peor  = key end

        end

        -- La division la hace el comando ( regla 6 de la plantilla ): un criterio
        -- que pide restar y dividir a mano se marca de memoria.
        local nuncaSalieron = {}

        for _, key in ipairs( PHANTASMAGORIA.TypeOrder or {} ) do
            if not cuenta[ key ] then table.insert( nuncaSalieron, key ) end

        end

        say( "[Phantasmagoria] SORTEO EN SECO: " .. n .. " tiros, sin spawnear nada." )
        say( "    distintos   " .. distintos .. " de " .. a.nOrden ..
            "   ( con " .. n .. " tiros sobre " .. a.nOrden .. ", esperado " .. a.nOrden .. " salvo mala suerte extrema )" )
        say( "    mas salido  " .. tostring( mejor ) .. " x" .. ( mejor and cuenta[ mejor ] or 0 ) ..
            "   ·  menos salido " .. tostring( peor ) .. " x" .. ( peor and cuenta[ peor ] or 0 ) ..
            "   ·  esperado x" .. math.Round( n / math.max( a.nOrden, 1 ), 1 ) .. " cada uno" )
        say( "    NUNCA salio " .. ( #nuncaSalieron > 0 and table.concat( nuncaSalieron, ", " ) or "ninguno -- los " .. a.nOrden .. " son alcanzables" ) )

        return

    end

    ---------------------------------------------------------------------------
    local function fichas()
        local found = PHANTASMAGORIA.EachGhost( function( ghost )
            say( "#" .. ghost:EntIndex() .. "  " .. ghost:GetClass() )
            PHANTASMAGORIA.TypeLines( ghost, say )

        end )

        if found <= 0 then say( "    no hay ningun fantasma vivo." ) end

        return found

    end

    if not sub then
        say( "    uso: phantasmagoria_ghost_type <key> | random | auto | sorteo [N] | lista" )
        fichas()

        return

    end

    ---------------------------------------------------------------------------
    -- SE NIEGA CON LA CONVAR EN 0, y esto salio de la revision antes de correr.
    -- `typeassign 0` es el control negativo: phantom_ResolveType deja SIN TIPO
    -- pase lo que pase. Aceptar un override ahi habria dejado la peor de las
    -- salidas posibles -- el comando diciendo `override -> oni` y las fichas de
    -- abajo diciendo `SIN TIPO`, en la misma pantalla -- y eso se lee como "el
    -- override no funciona", que es la conclusion inversa a la verdadera.
    --
    -- `auto` y `lista` y `sorteo` NO se niegan: no dependen de la convar.
    if ( sub == "random" or ( sub ~= "auto" and T[ sub ] ) ) and not cvAssign:GetBool() then
        say( "[Phantasmagoria] NO se toco nada: phantasmagoria_ghost_typeassign esta en 0 ( CONTROL )." )
        say( "    con la convar en 0 todo fantasma queda SIN TIPO, asi que un override no se veria." )
        say( "    para llegar al lado que falta:  phantasmagoria_ghost_typeassign 1" )

        return

    end

    ---------------------------------------------------------------------------
    if sub == "auto" or sub == "random" then
        PHANTASMAGORIA.TypeOverride = nil

        if sub == "auto" then
            say( "[Phantasmagoria] override BORRADO. Los que spawneen a partir de ahora sortean." )
            say( "    a los vivos NO se les toca el tipo: para re-sortearlos, 'random'." )
            fichas()

            return

        end

        say( "[Phantasmagoria] override BORRADO y los vivos RE-SORTEADOS." )
        say( "    antes:" )
        fichas()

        PHANTASMAGORIA.EachGhost( function( ghost ) ghost:phantom_ResolveType() end )

        say( "    despues del re-sorteo:" )
        fichas()

        return

    end

    ---------------------------------------------------------------------------
    -- SE NIEGA, que es lo que lo separa de una asignacion. Una key mal tipeada
    -- que se aceptara dejaria el override puesto apuntando a nada, y los
    -- fantasmas siguientes saldrian SIN TIPO -- con el comando habiendo dicho
    -- "listo". El nombre del tipo del juego y su key no siempre coinciden
    -- ( "The Twins" es `the_twins` ), asi que equivocarse es lo normal.
    if not T[ sub ] then
        say( "[Phantasmagoria] '" .. sub .. "' no es un tipo. NO se toco nada." )

        local parecidos = {}

        for _, key in ipairs( PHANTASMAGORIA.TypeOrder or {} ) do
            if string.find( key, sub, 1, true ) or string.find( string.lower( T[ key ].name ), sub, 1, true ) then
                table.insert( parecidos, key )

            end
        end

        say( "    " .. ( #parecidos > 0
            and ( "parecidos: " .. table.concat( parecidos, ", " ) )
            or  "ninguno se parece. 'phantasmagoria_ghost_type lista' imprime los " .. a.nOrden .. "." ) )

        return

    end

    PHANTASMAGORIA.TypeOverride = sub

    say( "[Phantasmagoria] override -> '" .. sub .. "' ( " .. T[ sub ].name .. " )." )
    say( "    alcanza a los fantasmas vivos Y a los que spawneen despues, hasta que alguien ponga 'auto'." )

    -- ⚠ HOY ESTO NO CAMBIA NINGUN COMPORTAMIENTO: el tipo todavia no lo lee
    -- nadie. Cuando Diseno 5 enganche speed.base, cambiarlo en vivo va a cambiar
    -- la velocidad en el acto, y esa linea de aviso tiene que actualizarse con
    -- el enganche -- no despues.
    say( "    NADA de comportamiento cambia todavia: el tipo es un dato hasta que Diseno 5 lo lea." )

    PHANTASMAGORIA.EachGhost( function( ghost ) ghost:phantom_ResolveType() end )

    fichas()

end, "Asigna, fuerza o audita el tipo de fantasma ( Diseno 19, tajada A ). Sin argumentos imprime la ficha de cada fantasma vivo." )
