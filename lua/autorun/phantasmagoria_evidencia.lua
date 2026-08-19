--[[-------------------------------------------------------------------------
    Phantasmagoria - las dos evidencias que se VEN: huellas UV y ghost orbs

    QUE ES ESTE ARCHIVO Y QUE NO

    Es el CONSUMIDOR que faltaba, mas un banco de pruebas para poder mirarlo
    sin depender de que un fantasma se digne a abrir una puerta.

    El productor de huellas ya existia y estaba vivo desde la ronda 6:
    `MakePrint` / `CommitPrint` en server_doors.lua guardan la huella como DATO
    cuando el fantasma abre una puerta de verdad. Lo que NO existia era nadie
    que la dibujara -- el propio instrumento lo confesaba en su salida:
    "NO se dibujan todavia, falta la linterna UV". Este archivo cierra esa
    mitad: networkea la huella al cliente y la dibuja bajo un gate.

    Los orbes no existian NI COMO DATO. Diseno 11.3 los daba por "dos lineas"
    ( ParticleEffect sobre la particula de gmpa ) y eso era cierto salvo por dos
    detalles que se midieron el 2026-08-18: **gmpa no esta suscripto** ( barridos
    los 880 addons del workshop local ), y **una particula del engine la ven
    todos y no admite gate**, cuando el orbe de Phasmophobia se ve SOLO por la
    videocamara. Se probo igual, copiando el .pcf al arbol, y en la r2 el autor
    comparo los dos mirando: *"se ve muchisimo mejor el nuestro, mejor saquemos
    el de GM Paranormal"*. **La particula y su modo se fueron enteros** -- lo que
    queda es el orbe propio, un sprite dibujado en el cliente.

    EL GATE ES PROVISIONAL, Y ESTA EN UNA SOLA FUNCION A PROPOSITO

    Diseno 8.4 fija la mecanica: la huella tiene que ser INVISIBLE hasta que le
    apuntas con la linterna UV. Un decal se ve siempre y para todos, y eso
    convierte la linterna en un adorno. La linterna todavia no existe, asi que
    el gate de hoy es una convar de cliente ( phantasmagoria_uv ). Cuando exista,
    se cambia el cuerpo de PHANTASMAGORIA.HoldingUV y NINGUN consumidor se
    entera. Si el gate se leyera inline en el hook de dibujo, mañana habria que
    volver a tocar el dibujo.

    LO QUE ESTE ARCHIVO NO DECIDE

    - Donde salen los orbes SOLOS. Eso es la habitacion favorita ( Diseno 14 ),
      que todavia no existe. Lo que se deja listo es la API que esa capa va a
      llamar: PHANTASMAGORIA.SpawnOrbs( pos, n, radio ) y
      PHANTASMAGORIA.StartOrbEmitter( pos, periodo, dur, n, radio ). El dia que
      el detector de cuartos ande, la habitacion favorita es una linea.
    - CUANDO el orbe se ve. En Phasmophobia es visible unicamente por la
      videocamara con vision nocturna, igual que la huella solo bajo la UV. El
      mecanismo YA ESTA -- PHANTASMAGORIA.SeeingOrbs(), un solo lugar -- y hoy
      devuelve una convar porque la camara no existe. Con la particula esto era
      imposible; con un sprite es una linea.
---------------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

PHANTASMAGORIA = PHANTASMAGORIA or {}

local MSG_PRINT = "phantasmagoria_uv_print"
local MSG_SYNC  = "phantasmagoria_uv_sync"
local MSG_CLEAR = "phantasmagoria_uv_clear"
local MSG_ORB   = "phantasmagoria_orb_add"
local MSG_ORBX  = "phantasmagoria_orb_clear"

-- Las cuatro texturas son las de EQUIPAMIENTO 8.6, y el indice NO es
-- decorativo: `MakePrint` guarda `hand = math.random( 1, 4 )` y este orden es el
-- que ese numero significa. Cambiar el orden aca renombra huellas ya guardadas.
local HAND_TEX = {
    "phantasmagoria/uv/hand_left.png",
    "phantasmagoria/uv/hand_right.png",
    "phantasmagoria/uv/smear_left.png",
    "phantasmagoria/uv/smear_right.png",
}

---------------------------------------------------------------------------
-- Registrar comandos sin depender del orden de carga
---------------------------------------------------------------------------
-- PHANTASMAGORIA.AddCommand ya existe y trae la guarda que costo una ronda
-- entera ( una convar y un concommand con el mismo nombre: gana la convar, en
-- silencio ). Pero vive en el server.lua de la entidad, y este archivo es
-- autorun: no hay garantia de que ya este definido cuando esto corre, y el
-- cliente lo tiene en otro archivo todavia. Asi que se usa el del proyecto SI
-- ESTA, y si no se replica la misma guarda -- no una version sin guarda, que
-- seria volver a pagar la misma ronda.
local function addCmd( name, fn, help )
    if PHANTASMAGORIA.AddCommand then
        return PHANTASMAGORIA.AddCommand( name, fn, help )

    end

    if ConVarExists( name ) then
        ErrorNoHalt( "[Phantasmagoria] COLISION DE NOMBRE: '" .. name .. "' ya existe como " ..
            "CONVAR, asi que el comando homonimo queda inalcanzable.\n" )
        return false

    end

    concommand.Add( name, fn, nil, help )
    return true

end

-- Los comandos de abajo CREAN cosas en el mundo ( evidencia falsa, particulas
-- para todos ), asi que van cerrados a admin. En un listen server el host es
-- superadmin, o sea que para el autor esto es transparente; en un server con
-- gente evita que la evidencia -- que es LA mecanica del juego -- se pueda
-- falsificar desde cualquier consola.
local function permitido( ply )
    if not IsValid( ply ) then return true end   -- consola del server
    return ply:IsAdmin()

end

-- El techo de 255 bytes de PrintMessage ya mordio antes; se reusa el partidor
-- del proyecto si esta, y si no se imprime igual pero cortando a mano.
local function say( ply )
    if PHANTASMAGORIA.MakeSay then return PHANTASMAGORIA.MakeSay( ply ) end

    return function( line )
        line = tostring( line )

        if not IsValid( ply ) then print( line ) return end

        while true do
            ply:PrintMessage( HUD_PRINTCONSOLE, string.sub( line, 1, 200 ) )
            line = string.sub( line, 201 )
            if #line <= 0 then break end

        end
    end
end

if SERVER then
    util.AddNetworkString( MSG_PRINT )
    util.AddNetworkString( MSG_SYNC )
    util.AddNetworkString( MSG_CLEAR )
    util.AddNetworkString( MSG_ORB )
    util.AddNetworkString( MSG_ORBX )

    -----------------------------------------------------------------------
    -- Networking de las huellas
    -----------------------------------------------------------------------
    -- Se manda LO RELATIVO ( lpos / lang contra la puerta ) y no el punto de
    -- mundo, por el mismo motivo por el que MakePrint lo guarda asi: una
    -- prop_door_rotating GIRA, y un punto de mundo enviado una vez queda
    -- flotando en el aire apenas la hoja se mueve. El cliente recompone con
    -- LocalToWorld en cada frame, asi que la huella viaja con la puerta gratis.
    --
    -- El tiempo viaja como RESTANTE y no como `expire`: CurTime del server y
    -- CurTime del cliente no son el mismo numero, y mandar un absoluto haria
    -- que la huella caduque en el momento equivocado -- con un desfasaje que
    -- crece con el uptime del server, o sea invisible en una prueba corta.
    --
    -- Y EL EntIndex VIAJA APARTE DE LA ENTIDAD, que parece redundante y no lo
    -- es: net.ReadEntity devuelve NULL si el cliente todavia no conoce esa
    -- entidad, y una puerta fuera del PVS del que recibe entra justo en ese
    -- caso. Con solo la entidad, la huella llegaria muerta y se descartaria
    -- para siempre -- un agujero que se abre segun DONDE este parado el que
    -- mira, o sea el modo de falla que no se reproduce cuando uno lo busca.
    -- Con el indice, el cliente la re-resuelve mas tarde y la huella aparece
    -- cuando la puerta entra en PVS.
    local function enviarPrint( p, ply )
        net.Start( MSG_PRINT )
            net.WriteEntity( p.ent )
            net.WriteUInt( p.ent:EntIndex(), 13 )
            net.WriteVector( p.lpos )
            net.WriteAngle( p.lang )
            net.WriteUInt( p.hand or 1, 3 )
            net.WriteFloat( math.max( ( p.expire or 0 ) - CurTime(), 0 ) )

        if IsValid( ply ) then net.Send( ply ) else net.Broadcast() end

    end

    -- El enganche que CommitPrint dejo puesto en la ronda 6 "para el bloque de
    -- la UV, que todavia no existe". Este es ese bloque.
    hook.Add( "PhantasmagoriaGhostUsedDoor", "phantasmagoria_uv_red", function( _ghost, _door, p )
        -- Sin el tercer argumento no hay nada que dibujar. Si esto se dispara
        -- con p == nil, el productor es una version de server_doors.lua que
        -- emite el hook sin la huella: la evidencia se guarda pero no se ve, y
        -- el sintoma seria "el contador sube y la pared esta limpia".
        if not p then
            ErrorNoHalt( "[Phantasmagoria] PhantasmagoriaGhostUsedDoor llego SIN la huella " ..
                "( 3er argumento ). server_doors.lua esta desactualizado.\n" )
            return

        end

        enviarPrint( p )

    end )

    -- Resync: un cliente que entra tarde, o que hizo un `retry`, no vio los
    -- net.Broadcast anteriores. Sin esto, "no veo nada" tendria dos causas
    -- posibles ( el dibujo o el alta ) y ninguna forma de separarlas.
    net.Receive( MSG_SYNC, function( _, ply )
        local prints = PHANTASMAGORIA.Prints or {}
        local now    = CurTime()

        for _, p in ipairs( prints ) do
            if p.expire and p.expire > now and IsValid( p.ent ) then enviarPrint( p, ply ) end

        end

        -- Los orbes viajan por el MISMO pedido: son la otra mitad de lo que este
        -- cliente no vio. Se llama por la tabla global y no por una local porque
        -- la funcion se define mas abajo en el archivo -- un upvalue todavia no
        -- existe cuando este closure se crea, y un campo de tabla se resuelve
        -- recien cuando el mensaje llega.
        if PHANTASMAGORIA.SyncOrbsTo then PHANTASMAGORIA.SyncOrbsTo( ply ) end

    end )

    -----------------------------------------------------------------------
    -- API: dejar una huella a mano
    -----------------------------------------------------------------------
    -- No duplica MakePrint/CommitPrint a proposito. Duplicarlas seria tener dos
    -- versiones de "como se guarda una huella" que divergen la primera vez que
    -- alguien toque una: el banco de pruebas dejaria de probar el camino real,
    -- y lo peor es que seguiria dando verde.
    function PHANTASMAGORIA.DropPrint( ent, pos, normal, autor )
        if not PHANTASMAGORIA.MakePrint or not PHANTASMAGORIA.CommitPrint then
            return nil, "server_doors.lua no cargo: MakePrint/CommitPrint no existen"

        end

        if not IsValid( ent ) then return nil, "la superficie no es una entidad valida" end

        local p = PHANTASMAGORIA.MakePrint( autor, ent, pos, normal )
        p.via = "manual"   -- el instrumento de puertas lo imprime: distingue este camino del del fantasma

        PHANTASMAGORIA.CommitPrint( p )

        return p

    end

    addCmd( "phantasmagoria_huella", function( ply )
        local decir = say( ply )

        if not permitido( ply ) then decir( "[Phantasmagoria] hace falta ser admin." ) return end

        if not IsValid( ply ) then
            decir( "[Phantasmagoria] este comando traza desde el ojo del jugador: correrlo en la consola del server no tiene sujeto." )
            return

        end

        local tr = ply:GetEyeTrace()

        if not tr.Hit then
            decir( "[Phantasmagoria] no estas apuntando a ninguna superficie." )
            return

        end

        -- El AUTOR de la huella de prueba es el jugador, y eso viaja por el
        -- hook igual que si fuera el fantasma. Es deliberado: prueba el camino
        -- entero ( hook -> red -> dibujo ) y no una version recortada de el.
        -- Un consumidor futuro que asuma "el primer argumento es un nextbot"
        -- tiene que tolerarlo, o se va a romper con el comando de testeo.
        local p, err = PHANTASMAGORIA.DropPrint( tr.Entity, tr.HitPos, tr.HitNormal, ply )

        if not p then
            decir( "[Phantasmagoria] no se pudo: " .. tostring( err ) )
            return

        end

        local sup = tr.Entity:GetClass() .. " #" .. tr.Entity:EntIndex()
        if tr.Entity:IsWorld() then sup = "el MUNDO ( brush del mapa: no gira, la huella queda fija )" end

        decir( "[Phantasmagoria] huella " .. p.hand .. " ( " .. HAND_TEX[ p.hand ] .. " ) sobre " .. sup )
        decir( "    guardadas ahora: " .. #( PHANTASMAGORIA.Prints or {} ) .. "   ·   dura 60 s" )
        decir( "    para VERLA hace falta el gate: en TU consola   phantasmagoria_uv 1" )

    end, "Deja una huella UV de prueba en la superficie a la que apuntas ( por el camino real: MakePrint + CommitPrint + hook + red )." )

    addCmd( "phantasmagoria_huella_limpiar", function( ply )
        local decir = say( ply )

        if not permitido( ply ) then decir( "[Phantasmagoria] hace falta ser admin." ) return end
        local n     = #( PHANTASMAGORIA.Prints or {} )

        PHANTASMAGORIA.Prints = {}

        net.Start( MSG_CLEAR )
        net.Broadcast()

        decir( "[Phantasmagoria] " .. n .. " huellas borradas ( server y clientes )." )

    end, "Borra todas las huellas UV guardadas, en el server y en los clientes." )

    -----------------------------------------------------------------------
    -- API: los ghost orbs
    -----------------------------------------------------------------------
    -- ⚠⚠ EL ORBE ES PROPIO, Y LA PARTICULA DE gmpa SE FUE EN LA r2. La r1 la
    -- usaba, y el autor la miro en juego: *"¿son verdes? no deberian ser blancos
    -- tenues, cosa que apenas se noten; los orbes son como particulas de polvo
    -- que se mueven erraticamente"*. Tenia razon, y el cambio ademas resuelve la
    -- deuda que la r1 habia dejado escrita como imposible: **una particula del
    -- engine la ven todos y no admite gate**, mientras que el orbe de
    -- Phasmophobia se ve SOLO por la videocamara. Un sprite dibujado en el
    -- cliente arregla las dos cosas de una.
    --
    -- El modo de comparacion duro exactamente una ronda, que es lo que valia:
    -- comparados los dos, el autor dictamino *"se ve muchisimo mejor el
    -- nuestro"* y el .pcf salio del arbol junto con el crédito de terceros.

    -- El orbe propio se guarda como DATO, igual que la huella, y por el mismo
    -- motivo: quien decide donde hay orbes es el server, quien decide si se ven
    -- es el cliente. El movimiento erratico NO viaja: se calcula en el cliente a
    -- partir de la semilla, asi que un orbe cuesta un mensaje y no un stream.
    PHANTASMAGORIA.Orbs = PHANTASMAGORIA.Orbs or {}

    -- El contador va en 10 bits, o sea 1023 orbes por mensaje. Se manda de a
    -- TANDAS en vez de confiar en que nadie pida mas: un `WriteUInt` que se pasa
    -- del ancho **no tira error, escribe el numero truncado**, y el cliente
    -- leeria una cantidad que no es la que hay -- con lo que el resto del
    -- mensaje se desfasa y lo que sale son orbes en coordenadas basura.
    local ORB_TANDA = 512

    local function enviarOrbs( lista, ply )
        if #lista <= 0 then return end

        for desde = 1, #lista, ORB_TANDA do
            local hasta = math.min( desde + ORB_TANDA - 1, #lista )

            net.Start( MSG_ORB )
                net.WriteUInt( hasta - desde + 1, 10 )

                for i = desde, hasta do
                    local o = lista[ i ]

                    net.WriteVector( o.pos )
                    net.WriteUInt( o.seed, 16 )
                    -- ttl 0 = no caduca. La habitacion favorita los va a querer
                    -- mientras el fantasma este ahi, no por un rato.
                    net.WriteFloat( o.expire > 0 and math.max( o.expire - CurTime(), 0 ) or 0 )

                end

            if IsValid( ply ) then net.Send( ply ) else net.Broadcast() end

        end
    end

    -- El alta la decide el SERVER y el dibujo lo hace cada cliente: la evidencia
    -- es del mundo y no de quien mira, pero QUIEN la ve es del cliente. Ese
    -- reparto es lo que hace posible el gate de la camara -- y es exactamente lo
    -- que una particula del engine no permite.
    -- Poda, como en CommitPrint: sin esto la tabla crece toda la partida y el
    -- sync de un cliente que entra tarde le manda orbes que ya no existen. Va
    -- UNA vez por lote y no una por orbe -- con 60 orbes, lo segundo son 3600
    -- vueltas para tirar los mismos muertos.
    local function podarOrbs()
        local now = CurTime()

        for i = #PHANTASMAGORIA.Orbs, 1, -1 do
            local v = PHANTASMAGORIA.Orbs[ i ]
            if v.expire > 0 and v.expire < now then table.remove( PHANTASMAGORIA.Orbs, i ) end

        end
    end

    local function crearOrb( pos, dur )
        dur = tonumber( dur ) or 0

        local o = {
            pos    = pos,
            seed   = math.random( 0, 65535 ),
            expire = dur > 0 and ( CurTime() + dur ) or 0,
        }

        PHANTASMAGORIA.Orbs[ #PHANTASMAGORIA.Orbs + 1 ] = o
        return o

    end

    function PHANTASMAGORIA.SpawnOrb( pos, dur )
        podarOrbs()
        enviarOrbs( { crearOrb( pos, dur ) } )

        return true

    end

    -- ⚠ EL LOTE MANDA **UN** MENSAJE, y no es una optimizacion prematura: la
    -- fila del rendimiento de la r2 pide 60 orbes de una, y llamar N veces a
    -- SpawnOrb serian 60 net.Start en el mismo frame. El canal no esta pensado
    -- para eso, y lo que se pierde cuando se satura no avisa: llegan menos
    -- orbes de los que el server cree que mando, o sea que el reporte del
    -- server y lo que se ve dejan de ser la misma cosa **sin un error**.
    function PHANTASMAGORIA.SpawnOrbs( pos, n, radio, dur )
        n     = math.max( tonumber( n ) or 1, 1 )
        radio = tonumber( radio ) or 0

        podarOrbs()

        local lote = {}

        for _ = 1, n do
            local p = pos

            if radio > 0 then
                p = pos + Vector( math.Rand( -radio, radio ),
                                  math.Rand( -radio, radio ),
                                  math.Rand( -radio, radio ) )

            end

            lote[ #lote + 1 ] = crearOrb( p, dur )

        end

        enviarOrbs( lote )

        return #lote

    end

    -- La usa el resync ( ver el net.Receive de MSG_SYNC, mas arriba ).
    function PHANTASMAGORIA.SyncOrbsTo( ply )
        local now   = CurTime()
        local vivos = {}

        for _, o in ipairs( PHANTASMAGORIA.Orbs ) do
            if o.expire <= 0 or o.expire > now then vivos[ #vivos + 1 ] = o end

        end

        enviarOrbs( vivos, ply )

    end

    function PHANTASMAGORIA.ClearOrbs()
        local n = #PHANTASMAGORIA.Orbs

        PHANTASMAGORIA.Orbs = {}

        net.Start( MSG_ORBX )
        net.Broadcast()

        return n

    end

    -- El emisor existe para lo que el autor describio en la r2: *"un solo orbe
    -- que se mueva, aparezca y desaparezca"*. Un orbe suelto no caduca y se
    -- queda quieto ahi para siempre; el emisor con n = 1 lo hace nacer, derivar
    -- unos segundos y apagarse, y otro nace despues. Eso es lo que la habitacion
    -- favorita va a pedirle: presencia intermitente, no un adorno fijo.
    PHANTASMAGORIA.OrbEmitters = PHANTASMAGORIA.OrbEmitters or {}

    function PHANTASMAGORIA.StartOrbEmitter( pos, periodo, dur, n, radio )
        periodo = math.max( tonumber( periodo ) or 3, 0.1 )
        dur     = tonumber( dur ) or 60

        local id   = table.Count( PHANTASMAGORIA.OrbEmitters ) + 1
        local name = "phantasmagoria_orb_" .. id .. "_" .. math.floor( CurTime() * 100 )

        PHANTASMAGORIA.OrbEmitters[ id ] = { pos = pos, timer = name }

    -- ⚠ EL EMISOR LE DA VIDA A LO QUE EMITE, y con la particula no hacia falta
        -- porque se apagaba sola. Un orbe propio por default NO caduca, asi que
        -- un emisor que dispara cada 3 s durante 30 dejaria **treinta orbes
        -- permanentes** apilados en el mismo punto -- que no es un cuarto con
        -- orbes, es un montoncito que crece.
        -- Con vida = dos periodos, la poblacion se estabiliza y los orbes ROTAN:
        -- nacen, derivan y se apagan. Con n = 1 -- el default desde la r3 -- eso
        -- es exactamente lo que el autor pidio: *"basta con tener un solo orbe
        -- que se mueva, aparezca y desaparezca"*.
        local durOrb = periodo * 2

        PHANTASMAGORIA.SpawnOrbs( pos, n, radio, durOrb )

        -- Repeticiones = 0 es infinito; con dur > 0 se calcula cuantas entran,
        -- asi el timer se muere solo y no queda una fuga como la que gmpa tiene
        -- con sus timers a 33 Hz que nadie remueve ( Diseno 11.2, defecto 6 ).
        local reps = dur > 0 and math.max( math.floor( dur / periodo ), 1 ) or 0

        timer.Create( name, periodo, reps, function()
            PHANTASMAGORIA.SpawnOrbs( pos, n, radio, durOrb )

        end )

        return id

    end

    function PHANTASMAGORIA.StopOrbEmitters()
        local n = 0

        for _, e in pairs( PHANTASMAGORIA.OrbEmitters ) do
            if timer.Exists( e.timer ) then
                timer.Remove( e.timer )
                n = n + 1

            end
        end

        PHANTASMAGORIA.OrbEmitters = {}
        return n

    end

    addCmd( "phantasmagoria_orbe", function( ply, _, args )
        local decir = say( ply )

        if not permitido( ply ) then decir( "[Phantasmagoria] hace falta ser admin." ) return end

        local n     = tonumber( args[ 1 ] ) or 1
        -- Los defaults salen de la r2: el autor probo 6 y anoto *"para que sea
        -- parecido a la de phasmophobia tiene que ser un solo orbe que se mueva
        -- erratico ( es como un orbe -> un fantasma ), eso se soluciona con 1 64,
        -- ahi si se ve perfecto"*. UNO, con 64 u de dispersion.
        local radio = tonumber( args[ 2 ] ) or 64
        local dur   = tonumber( args[ 3 ] ) or 0
        local pos

        if IsValid( ply ) then
            local tr = ply:GetEyeTrace()
            -- 24 u por encima de la superficie: un orbe naciendo DENTRO del
            -- brush se recorta y parece que no salio nada.
            pos = tr.Hit and ( tr.HitPos + tr.HitNormal * 24 ) or ply:EyePos()

        else
            local a = player.GetAll()[ 1 ]
            if not IsValid( a ) then decir( "[Phantasmagoria] no hay jugadores: no se donde ponerlo." ) return end
            pos = a:EyePos()

        end

        local puestos = PHANTASMAGORIA.SpawnOrbs( pos, n, radio, dur )

        decir( "[Phantasmagoria] " .. puestos .. " orbe(s) en " .. tostring( pos ) ..
            ( dur > 0 and ( "   ( " .. dur .. " s )" ) or "   ( no caducan )" ) )
        decir( "    se calibra en el cliente con phantasmagoria_orbe_tam · _alfa · _deriva," )
        decir( "    y se apaga con phantasmagoria_orbes 0." )

    end, "Spawnea N ghost orbs donde apuntas. Uso: phantasmagoria_orbe [n=1] [radio=64] [dur=0]  ( dur 0 = no caducan )." )

    addCmd( "phantasmagoria_orbe_emisor", function( ply, _, args )
        local decir   = say( ply )

        if not permitido( ply ) then decir( "[Phantasmagoria] hace falta ser admin." ) return end
        local periodo = tonumber( args[ 1 ] ) or 3
        local dur     = tonumber( args[ 2 ] ) or 60
        local n       = tonumber( args[ 3 ] ) or 1
        local radio   = tonumber( args[ 4 ] ) or 64

        if not IsValid( ply ) then decir( "[Phantasmagoria] necesita un jugador que apunte." ) return end

        local tr  = ply:GetEyeTrace()
        local pos = tr.Hit and ( tr.HitPos + tr.HitNormal * 24 ) or ply:EyePos()
        local id  = PHANTASMAGORIA.StartOrbEmitter( pos, periodo, dur, n, radio )

        decir( "[Phantasmagoria] emisor #" .. id .. " en " .. tostring( pos ) )
        decir( "    " .. n .. " orbes cada " .. periodo .. " s, radio " .. radio ..
            " u, durante " .. ( dur > 0 and ( dur .. " s" ) or "SIEMPRE" ) )
        decir( "    apagar: phantasmagoria_orbe_limpiar" )

    end, "Emisor de orbes donde apuntas. Uso: phantasmagoria_orbe_emisor [periodo] [dur] [n] [radio]." )

    addCmd( "phantasmagoria_orbe_limpiar", function( ply )
        local decir = say( ply )

        if not permitido( ply ) then decir( "[Phantasmagoria] hace falta ser admin." ) return end

        local emisores = PHANTASMAGORIA.StopOrbEmitters()
        local orbes    = PHANTASMAGORIA.ClearOrbs()

        decir( "[Phantasmagoria] " .. emisores .. " emisores apagados   ·   " .. orbes .. " orbes borrados." )
        decir( "    se van en el acto: son dato, y el cliente deja de dibujarlos." )

    end, "Apaga los emisores y borra todos los orbes." )

end

if CLIENT then
    local cv_uv     = CreateClientConVar( "phantasmagoria_uv",        "0",   true, false,
        "GATE PROVISIONAL de la evidencia UV: 1 = como si tuvieras la linterna UV encendida." )
    local cv_escala = CreateClientConVar( "phantasmagoria_uv_escala", "0.1", true, false,
        "Escala del dibujo 3D2D de la huella. 0.1 = una mano de ~13 u de lado." )
    local cv_rot    = CreateClientConVar( "phantasmagoria_uv_rot",    "0",   true, false,
        "Grados de giro de la huella sobre su propia superficie ( calibracion del 'arriba' )." )

    PHANTASMAGORIA.UVPrints = PHANTASMAGORIA.UVPrints or {}

    local MATS = {}

    for i, ruta in ipairs( HAND_TEX ) do
        MATS[ i ] = Material( ruta, "smooth" )

    end

    -----------------------------------------------------------------------
    -- El gate, en UNA funcion
    -----------------------------------------------------------------------
    -- Cuando exista la linterna UV, lo unico que cambia es el cuerpo de esto.
    -- La huella de sal ( demit/salt_step.mdl, EQUIPAMIENTO 8.5 ) va a colgar
    -- del mismo gate: una sola condicion para las dos evidencias UV.
    function PHANTASMAGORIA.HoldingUV()
        if cv_uv:GetBool() then return true end

        -- Aca va, el dia que exista: el item UV en la mano y encendido.
        return false

    end

    net.Receive( MSG_PRINT, function()
        local ent  = net.ReadEntity()
        local idx  = net.ReadUInt( 13 )
        local lpos = net.ReadVector()
        local lang = net.ReadAngle()
        local hand = net.ReadUInt( 3 )
        local ttl  = net.ReadFloat()

        PHANTASMAGORIA.UVPrints[ #PHANTASMAGORIA.UVPrints + 1 ] = {
            ent    = ent,
            idx    = idx,   -- para re-resolver si la puerta todavia no llego
            lpos   = lpos,
            lang   = lang,
            hand   = math.Clamp( hand, 1, #HAND_TEX ),
            expire = CurTime() + ttl,
        }
    end )

    net.Receive( MSG_CLEAR, function()
        PHANTASMAGORIA.UVPrints = {}

    end )

    -- Un cliente que entra tarde no vio los broadcast anteriores. Pedir el
    -- resync al entrar hace que "no veo nada" signifique una sola cosa.
    local function pedirSync()
        net.Start( MSG_SYNC )
        net.SendToServer()

    end

    -- El callback va INLINE aunque `pedirSync` ya exista: `dev/auditar_returns_de_hooks.py`
    -- no puede leer el cuerpo de un callback nombrado y lo reporta como
    -- "sin cuerpo visible", o sea una alarma que va a estar todas las corridas y
    -- que nunca es nada. Un control que grita siempre enseña a ignorarlo.
    hook.Add( "InitPostEntity", "phantasmagoria_uv_sync", function()
        pedirSync()

    end )

    -- ⚠⚠ Y EL COMANDO EXISTE PORQUE EN SINGLEPLAYER NO HAY OTRA FORMA DE MEDIR
    -- ESTO. La r1 puso una fila que decia "hacer `retry` y ver si las huellas
    -- siguen", y el autor la marco FALLA preguntando *"¿deberia funcionar
    -- realmente? o sea estoy en singleplayer"*. Tenia razon y el que estaba mal
    -- era el check: en singleplayer el `retry` **reinicia el servidor**, asi que
    -- `PHANTASMAGORIA.Prints` se va con el mapa. No hay huella que resincronizar,
    -- y la fila no podia distinguir "el resync no anda" de "no quedo nada que
    -- mandar" -- las dos se ven igual: cero huellas.
    --
    -- Esto pide el resync SIN tocar el servidor: vacia la lista local y la
    -- vuelve a pedir. Si vuelve, el camino funciona; y en el medio hay un
    -- instante con la lista en cero que prueba que se vacio de verdad.
    addCmd( "phantasmagoria_uv_resync", function()
        local antes = #PHANTASMAGORIA.UVPrints

        PHANTASMAGORIA.UVPrints = {}
        pedirSync()

        print( "[Phantasmagoria] lista local vaciada ( tenia " .. antes .. " ) y resync pedido." )
        print( "    correr phantasmagoria_uv_estado en un segundo: tiene que volver a " .. antes ..
            " ( menos las que hayan caducado )." )

    end, "Vacia las huellas de ESTE cliente y se las vuelve a pedir al server. Mide el resync sin reiniciar nada." )

    -----------------------------------------------------------------------
    -- El dibujo
    -----------------------------------------------------------------------
    hook.Add( "PostDrawTranslucentRenderables", "phantasmagoria_uv_huellas", function( _depth, skybox )
        if skybox then return end
        if not PHANTASMAGORIA.HoldingUV() then return end

        local lista = PHANTASMAGORIA.UVPrints
        if #lista <= 0 then return end

        local now    = CurTime()
        local escala = math.max( cv_escala:GetFloat(), 0.001 )
        local giro   = cv_rot:GetFloat()

        for i = #lista, 1, -1 do
            local p = lista[ i ]

            -- La PODA es solo por tiempo. Una puerta invalida NO borra la
            -- huella: puede ser una puerta que todavia no entro en PVS, y
            -- borrarla ahi la perderia para siempre. Se reintenta resolverla
            -- por indice y, si no esta, este frame simplemente no la dibuja.
            if not IsValid( p.ent ) then p.ent = Entity( p.idx or 0 ) end

            if p.expire <= now then
                table.remove( lista, i )

            elseif IsValid( p.ent ) then
                -- Recomponer contra la puerta EN ESTE FRAME es lo que hace que
                -- la huella siga a la hoja cuando gira. MakePrint guardo
                -- ( pos, normal:Angle() ) relativos, asi que lo que sale de
                -- LocalToWorld es exactamente eso: el punto y la normal.
                local pos, ang = LocalToWorld( p.lpos, p.lang, p.ent:GetPos(), p.ent:GetAngles() )
                local normal   = ang:Forward()

                -- El idiom de pegar un 3D2D sobre una superficie de normal N.
                ang:RotateAroundAxis( ang:Right(), -90 )
                if giro ~= 0 then ang:RotateAroundAxis( normal, giro ) end

                -- Fade por tiempo restante ( 8.5 ): el alfa sale de `expire` y
                -- no de $decalfadeduration, justamente porque no es un decal.
                local alfa = 200 * math.Clamp( ( p.expire - now ) / 10, 0, 1 )

                cam.Start3D2D( pos + normal * 0.2, ang, escala )
                    surface.SetMaterial( MATS[ p.hand ] )
                    surface.SetDrawColor( 180, 220, 255, alfa )
                    surface.DrawTexturedRect( -64, -64, 128, 128 )
                cam.End3D2D()

            end
        end
    end )

    -----------------------------------------------------------------------
    -- Los ghost orbs: mota de polvo, no bola verde
    -----------------------------------------------------------------------
    -- El autor, mirando el modo pcf en juego: *"¿son verdes? no deberian ser
    -- blancos tenues, cosa que apenas se noten; los orbes son como particulas de
    -- polvo que se mueven erraticamente"*. Eso es lo que dibuja esto, y las tres
    -- convars existen porque "apenas se noten" es un criterio que hay que
    -- calibrar mirando y no un numero que yo pueda adivinar de este lado.
    --
    -- ⚠ EL MOVIMIENTO NO VIAJA POR LA RED. Cada orbe trae una SEMILLA y el
    -- cliente deriva la deriva de ella: un orbe cuesta un mensaje y no un
    -- stream de posiciones a 33 Hz. Que cada cliente vea la mota en un lugar
    -- ligeramente distinto no importa -- lo que la mecanica necesita es que
    -- todos vean orbes EN EL MISMO CUARTO, y eso es la posicion base, que si
    -- viaja. ( Si algun dia importa el punto exacto -- una foto que puntua --,
    -- la semilla alcanza para reproducirlo: es determinista. )
    local cv_orbes   = CreateClientConVar( "phantasmagoria_orbes",        "1",  true, false,
        "GATE PROVISIONAL de los ghost orbs: 1 = visibles. El dia que exista la videocamara, este es el gate que pasa a preguntar por ella." )
    local cv_orbTam  = CreateClientConVar( "phantasmagoria_orbe_tam",     "4",  true, false,
        "Tamaño del sprite del orbe, en unidades." )
    local cv_orbAlfa = CreateClientConVar( "phantasmagoria_orbe_alfa",    "70", true, false,
        "Alfa maximo del orbe ( 0-255 ). Bajo = 'apenas se nota'." )
    local cv_orbDrv  = CreateClientConVar( "phantasmagoria_orbe_deriva",  "10", true, false,
        "Amplitud en unidades de la deriva erratica alrededor del punto donde nacio." )

    PHANTASMAGORIA.Orbs = PHANTASMAGORIA.Orbs or {}

    -- Aditivo y sin $ignorez: se suma a lo que hay detras ( por eso se lee como
    -- polvo iluminado y no como una pelota ) pero LO TAPA UNA PARED, que es lo
    -- que un orbe adentro de un cuarto tiene que respetar.
    local ORB_MAT = Material( "sprites/light_glow02_add" )

    -- Segundos que tarda un orbe en aparecer y en irse. Corto: no es una luz que
    -- se enciende, es polvo que entra en foco.
    local FADE_ORBE = 1.2

    -- Dos senos de frecuencias que no son multiplo una de otra: con uno solo el
    -- movimiento se lee como un pendulo, y "erratico" es justamente lo que un
    -- pendulo no es. El eje Z va mas lento y mas corto: flota, no rebota.
    local function orbPos( o, t, amp )
        local s = o.seed * 0.001

        return o.pos + Vector(
            ( math.sin( t * 0.53 + s ) + math.sin( t * 1.27 + s * 2.7 ) * 0.5 ) * amp,
            ( math.cos( t * 0.47 + s * 1.9 ) + math.sin( t * 1.11 + s ) * 0.5 ) * amp,
            ( math.sin( t * 0.31 + s * 3.3 ) + math.cos( t * 0.83 + s * 1.3 ) * 0.4 ) * amp * 0.6
        )
    end

    -- Cuando exista la videocamara con vision nocturna, cambia el cuerpo de esto
    -- y nada mas -- igual que HoldingUV para la huella.
    function PHANTASMAGORIA.SeeingOrbs()
        return cv_orbes:GetBool()

    end

    net.Receive( MSG_ORB, function()
        local n = net.ReadUInt( 10 )

        for _ = 1, n do
            local pos  = net.ReadVector()
            local seed = net.ReadUInt( 16 )
            local ttl  = net.ReadFloat()

            PHANTASMAGORIA.Orbs[ #PHANTASMAGORIA.Orbs + 1 ] = {
                pos    = pos,
                seed   = seed,
                nacio  = CurTime(),   -- para el fade IN; ver el dibujo
                expire = ttl > 0 and ( CurTime() + ttl ) or 0,
            }
        end
    end )

    net.Receive( MSG_ORBX, function()
        PHANTASMAGORIA.Orbs = {}

    end )

    hook.Add( "PostDrawTranslucentRenderables", "phantasmagoria_orbes", function( _depth, skybox )
        if skybox then return end
        if not PHANTASMAGORIA.SeeingOrbs() then return end

        local lista = PHANTASMAGORIA.Orbs
        if #lista <= 0 then return end

        local now  = CurTime()
        local tam  = math.max( cv_orbTam:GetFloat(), 0.1 )
        local alfa = math.Clamp( cv_orbAlfa:GetFloat(), 0, 255 )
        local amp  = math.max( cv_orbDrv:GetFloat(), 0 )

        render.SetMaterial( ORB_MAT )

        for i = #lista, 1, -1 do
            local o = lista[ i ]

            if o.expire > 0 and o.expire <= now then
                table.remove( lista, i )

            else
                -- El titileo es parte del "apenas se nota": un brillo constante
                -- se lee como una luz puesta ahi, y una mota de polvo entra y
                -- sale de la luz.
                local pulso = 0.55 + 0.45 * math.sin( now * 1.7 + o.seed * 0.01 )
                local a     = alfa * pulso

                -- ⚠ FADE EN LAS DOS PUNTAS, y la de ENTRADA es la que faltaba.
                -- El autor en la r3: *"funciona pero cambian rapidamente de
                -- posicion sin un fade in o fade out, es tosco en ese sentido"*.
                -- Y tenia razon dos veces: el orbe nuevo aparecia de golpe con
                -- el alfa entero, y como cada uno nace en OTRO punto del radio,
                -- lo que se leia no era "uno se apago y nacio otro" sino **el
                -- mismo orbe teletransportandose**. Con las dos puntas en fade,
                -- el relevo pasa desapercibido y quedan dos motas que se cruzan.
                --
                -- El fade de salida era de 5 s y la vida de un orbe del emisor
                -- es de 6: o sea que pasaba el 83 % de su vida apagandose, que
                -- es otra forma de verse mal. FADE fijo y corto para los dos
                -- lados, acotado a un tercio de la vida cuando el orbe es breve.
                -- `nacio` es un campo NUEVO: un orbe que ya estaba vivo cuando
                -- este archivo se recargo en caliente no lo tiene, y una resta
                -- contra nil adentro de un hook de render no tira un error --
                -- tira MILES, uno por frame, hasta que alguien limpie. Un `or`
                -- cuesta nada y evita que un reload deje el juego inusable.
                local nacio = o.nacio or now
                local fade  = FADE_ORBE

                if o.expire > 0 then
                    fade = math.min( fade, ( o.expire - nacio ) / 3 )

                end

                if fade <= 0 then fade = FADE_ORBE end

                a = a * math.Clamp( ( now - nacio ) / fade, 0, 1 )

                if o.expire > 0 then
                    a = a * math.Clamp( ( o.expire - now ) / fade, 0, 1 )

                end

                render.DrawSprite( orbPos( o, now, amp ), tam, tam, Color( 255, 255, 255, a ) )

            end
        end
    end )

    addCmd( "phantasmagoria_uv_toggle", function()
        local prendida = cv_uv:GetBool()

        RunConsoleCommand( "phantasmagoria_uv", prendida and "0" or "1" )
        print( "[Phantasmagoria] linterna UV ( simulada ): " .. ( prendida and "APAGADA" or "ENCENDIDA" ) )

    end, "Alterna el gate provisional de la UV. Bindeable a una tecla." )

    -- El estado del CLIENTE, que es donde se decide si se ve o no. Existe para
    -- que "no veo la huella" se pueda partir en tres causas separables: no
    -- llego el dato, el gate esta cerrado, o la textura no cargo.
    addCmd( "phantasmagoria_uv_estado", function()
        local now    = CurTime()
        local vivas  = 0
        local sinEnt = 0

        -- Las dos cuentas van separadas a proposito: "viva pero sin puerta
        -- resuelta" es un estado real ( la hoja todavia no entro en PVS ) y
        -- meterlo adentro de `vivas` haria que el instrumento reporte 0 con la
        -- huella perfectamente guardada. Un contador que junta dos causas no
        -- deja separar ninguna.
        for _, p in ipairs( PHANTASMAGORIA.UVPrints ) do
            if p.expire > now then
                vivas = vivas + 1
                if not IsValid( p.ent ) then sinEnt = sinEnt + 1 end

            end
        end

        print( "[Phantasmagoria] gate UV: " .. ( PHANTASMAGORIA.HoldingUV() and "ABIERTO" or "CERRADO ( phantasmagoria_uv 1 )" ) )
        print( "    huellas que conoce este cliente: " .. vivas .. " vivas de " .. #PHANTASMAGORIA.UVPrints .. " recibidas" )
        print( "    de esas, sin la puerta resuelta todavia ( fuera de PVS ): " .. sinEnt )
        print( "    escala " .. cv_escala:GetFloat() .. "   giro " .. cv_rot:GetFloat() .. " grados" )

        for i, ruta in ipairs( HAND_TEX ) do
            local m   = MATS[ i ]
            local err = ( not m ) or m:IsError()

            print( "    textura " .. i .. "  " .. ( err and "ERROR ( no cargo )" or "ok" ) .. "  " .. ruta )

        end

        -- Los orbes van en el mismo reporte porque comparten el modo de falla:
        -- "no veo nada" con el gate cerrado se ve igual que con la lista vacia.
        local vivosOrb = 0

        for _, o in ipairs( PHANTASMAGORIA.Orbs or {} ) do
            if o.expire <= 0 or o.expire > now then vivosOrb = vivosOrb + 1 end

        end

        print( "[Phantasmagoria] gate ORBES: " .. ( PHANTASMAGORIA.SeeingOrbs() and "ABIERTO" or "CERRADO ( phantasmagoria_orbes 1 )" ) )
        print( "    orbes que conoce este cliente: " .. vivosOrb .. " vivos de " .. #( PHANTASMAGORIA.Orbs or {} ) .. " recibidos" )
        print( "    sprite: " .. ( ORB_MAT:IsError() and "ERROR ( no cargo )" or "ok" ) .. "  " .. ORB_MAT:GetName() )
        print( "    tam " .. cv_orbTam:GetFloat() .. "   alfa " .. cv_orbAlfa:GetFloat() ..
            "   deriva " .. cv_orbDrv:GetFloat() .. " u" )

    end, "Estado del cliente para la evidencia UV: gate, huellas conocidas y si las texturas cargaron." )

end
