--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom / LA CORREA

    PEDIDO DEL AUTOR, r2, fila 06: *"Lo que si me gustaria y no es como efecto es
    poder mantenerlos dentro de la casa en un area sin que se escapen a la punta
    del mapa."*

    ---------------------------------------------------------------------------
    NO ES UN CAPRICHO DEL BOT: ES SU FUNCION DE PUNTAJE, Y ESTA MEDIDA
    ---------------------------------------------------------------------------

    El fantasma no "se aburre y se va". La rama del despachante que corre cuando
    no hay enemigo, ni arma, ni sonido, ni curiosidad arranca `movement_inertia`
    con el motivo literal *"nothing better to do"*, y esa tarea saca su destino
    de `findValidNavResult` con radio `math.random( 3000, 4000 )` y una funcion
    de puntaje que **PREMIA LA DISTANCIA**:

        score = area2:GetCenter():DistToSqr( startPos ) * math.Rand( 0.8, 1.4 )

    Cuando a `inertia` se le acaba el `Want`, encadena a `movement_biginertia`,
    que es peor y es la causa mecanica del reclamo: radio
    `math.random( 5000, 6000 )`, el mismo puntaje por distancia, y ademas
    **penaliza x0,00001 las areas ya visitadas**. O sea que cada ciclo lo empuja
    mas lejos que el anterior, a proposito.

    Y escapar del radio no es un fallback sino **el resultado preferido**:
    `findValidNavResult` retorna en cuanto un area supera el radio, salvo que el
    llamador ponga `data.blockRadiusEnd` -- y ni `inertia` ni `biginertia` lo
    ponen.

    *El bot no se escapa: esta haciendo exactamente lo que su puntaje le pide.*

    ---------------------------------------------------------------------------
    LAS TRES FORMAS POSIBLES, Y POR QUE SE ELIGIO FILTRAR EL DESTINO
    ---------------------------------------------------------------------------

      TELETRANSPORTAR   rompe la unica cosa que este bot tiene que hacer bien
                        ( que lo veas venir ), y ademas ya hay un teleport de
                        rescate vivo en la base ( `overrideVeryStuck`,
                        pathoverrides.lua:1719-1729 ) con el que se confundiria
                        en cualquier log.

      EL PEAJE          `AddAreasToAvoid` **NO es un muro**: suma a un
                        multiplicador que se consume como `cost = cost *
                        additionalCost` ( pathoverrides.lua:393 y :575-579 ), asi
                        que si el unico camino cruza, entra igual. Y peor para
                        esto: actua sobre el CAMINO y no sobre la ELECCION, o sea
                        que el fantasma seguiria eligiendo la punta del mapa y
                        solo pagaria mas caro llegar.

      ABORTAR EL PATH   llega tarde -- el destino ya se eligio y el fantasma ya
                        encaro -- y el sintoma es un bot que sale y vuelve
                        oscilando. ⚠ Y hay algo peor, medido: devolver `false` /
                        `nil` desde el shell hace que `inertia` marque
                        `InvalidateAfterwards` y **encadene a `biginertia`**
                        ( shared.lua:8045-8050 ), o sea que el fantasma se va
                        MAS lejos. *El rechazo obvio produce el comportamiento
                        contrario al pedido.*

    Queda **reemplazar el destino**: si el punto elegido cae fuera de la correa,
    se lo cambia por el punto navegable mas cercano al ancla y se llama al
    BaseClass con ese. El fantasma no se frena, no se teleporta, y el primer
    wander despues de cruzar la linea lo trae de vuelta caminando.

    ---------------------------------------------------------------------------
    EL EMBUDO, Y POR QUE HAY QUE TENERLE RESPETO
    ---------------------------------------------------------------------------

    `SetupPathShell` es el embudo unico de los destinos de los DOS wander, pero
    NO solo de ellos: por ahi pasan tambien el hunt ( `stalkenemy` ), la
    investigacion por sonido, la busqueda de armas, los escondites, y **el
    rescate de atascado**. Son 29 call sites. Por eso las guardas de abajo estan
    en un orden que no es cosmetico, y cada una tiene su motivo escrito.

    ---------------------------------------------------------------------------
    EL ANCLA: LA POSICION DE SPAWN
    ---------------------------------------------------------------------------

    La base NO guarda una: `HomePos`, `LeashLength`, `wanderRadius`,
    `MaxWanderDistance` y `RestrictTo` dan **cero archivos** sobre sus 71 `.lua`.
    Su `init.lua:131` usa la posicion del spawn solo para resolver `m_NavArea` y
    la tira.

    Se descarta el `favouriteRoom` de gmpa: es `Vector( 1000, 1000, 100 )`
    hardcodeado y su propio autor comenta *"change this based on your map"*
    ( gm_paranormalactivities.lua:93 ). Eso no es un ancla, es un placeholder.

    Queda la posicion de spawn, que ademas es la que **el autor controla sin
    aprender nada nuevo**: pone el fantasma en la casa y la casa queda definida.
    Y si se equivoco, `phantasmagoria_ghost_correa aqui` la vuelve a fijar donde
    el fantasma este parado.

    ⚠ EL RADIO VA EN CONVAR Y NO EN UNA CONSTANTE porque **no se midio cuanto
    mide una casa en los mapas del autor**. Lo unico medido es
    `gm_funkis_night`: sus 43 luces conmutables caben en una caja de
    862 x 1056 u, o sea que la casa entra holgada en 1500 u desde su centro
    ( ~28,5 m con la conversion de Diseno 1 ). Ese es el default y es un dato del
    mapa medido, no un numero elegido -- si en otro mapa queda corto, se mueve la
    convar y el reporte dice con cual esta midiendo.
---------------------------------------------------------------------------]]

local cvLeash = CreateConVar( "phantasmagoria_ghost_leash", "1", FCVAR_ARCHIVE,
    "La correa: el fantasma no elige destinos lejos de donde spawneo. " ..
    "0 = CONTROL, deambula por todo el mapa como en la r2 · 1 = correa en CALMA ( el hunt es libre ) · " ..
    "2 = correa TAMBIEN en el hunt.", 0, 2 )

local cvRadio = CreateConVar( "phantasmagoria_ghost_leashradius", "1500", FCVAR_ARCHIVE,
    "Radio de la correa en unidades alrededor del ancla. 1500 u son ~28,5 m: en gm_funkis_night " ..
    "la casa entera cabe en una caja de 862 x 1056 u ( medido en el BSP en la r1 ).", 128, 16384 )

---------------------------------------------------------------------------
-- ⚠ CUANTOS CLAMPS SEGUIDOS ANTES DE DEJAR PASAR UNO
---------------------------------------------------------------------------
-- Un fantasma que quedo en un bolsillo del navmesh fuera de la casa pediria
-- destinos lejanos una y otra vez, se los clampearia a un ancla que no puede
-- alcanzar, y `SetupPathShell` devolveria `blocked4` cada vez. Eso NO es
-- inofensivo: `term_ConsecutivePathFailures` escala a `overrideVeryStuck` en
-- pathoverrides.lua **a los 5 fallos** si el area actual es huerfana ( :1726-1732,
-- que es una rama distinta de la de los 15 y cae justo en este caso ). O sea que
-- la correa mal puesta puede disparar el rescate de emergencia en bucle.
--
-- Dejar pasar uno cada N rompe el bucle sin apagar la correa, y el contador se
-- imprime: *una valvula de escape que nadie puede ver es indistinguible de la
-- correa no funcionando.*
local CLAMPS_SEGUIDOS = 8

local function estado( ghost )
    ghost.phantom_leash = ghost.phantom_leash or {
        ancla     = nil,
        anclaDe   = nil,   -- "spawn" o "mano", para que el reporte lo diga
        clamps    = 0,
        pasados   = 0,     -- los que la valvula dejo pasar
        libres    = 0,     -- los que ya estaban adentro
        hunt      = 0,     -- los que pasaron derecho por estar cazando
        seguidos  = 0,
        ultimoT   = nil,
        ultimaD   = nil,   -- a que distancia estaba el destino rechazado
    }

    return ghost.phantom_leash

end

-- ⚠ EL ANCLA SE CAPTURA PEREZOSAMENTE Y **NO** EN AdditionalInitialize. Ese
-- metodo ya lo declara server.lua:837, y un archivo que lo vuelva a declarar
-- **no encadena: BORRA** -- se llevaria puestos el serial, el hull, el FOV y la
-- eleccion de tipo, sin un solo error de Lua. Es la misma trampa que
-- server_events.lua documenta para `AdditionalThink`.
--
-- Capturar en el primer uso no pierde nada: el primer `SetupPathShell` de un
-- fantasma ocurre mucho antes de que se haya movido lejos.
local function ancla( ghost, st )
    if st.ancla then return st.ancla end

    st.ancla   = ghost:GetPos()
    st.anclaDe = "spawn"

    return st.ancla

end

---------------------------------------------------------------------------
-- EL FILTRO
---------------------------------------------------------------------------
function ENT:SetupPathShell( endpos, isUnstuck )
    local base = self.BaseClass and self.BaseClass.SetupPathShell

    -- Sin el padre no hay nada que filtrar y tampoco nada que hacer. Se avisa
    -- una vez y no por llamada: esto corre decenas de veces por minuto.
    if not isfunction( base ) then
        if not self.phantom_leashSinBase then
            self.phantom_leashSinBase = true
            ErrorNoHalt( "[Phantasmagoria] la base no expone SetupPathShell: la correa no puede filtrar nada.\n" )

        end

        return nil, "blocked_phantom_nobase"

    end

    local modo = cvLeash:GetInt()

    -- ( 1 ) EL RESCATE DE ATASCADO PASA DERECHO, SIEMPRE. shared.lua:2124 llama
    -- con `isUnstuck = true` para sacar al bot de un encaje; clampear eso lo
    -- deja encajado, que es el sintoma que el autor YA reporto por otro lado y
    -- que server_stuck.lua existe para medir. *Una correa que compite con el
    -- rescate convierte un problema chico en uno que necesita el physgun.*
    if isUnstuck or self.isUnstucking then return base( self, endpos, isUnstuck ) end

    if modo == 0 then return base( self, endpos, isUnstuck ) end

    -- ( 2 ) EL HUNT ES LIBRE salvo que la convar diga lo contrario. Es la linea
    -- de server.lua:592 invertida, y usa la MISMA puerta unica: `phantom_Hunting`
    -- se escribe en un solo lugar del addon ( phantom_SetHunting ).
    --
    -- ⚠ Y EL COSTO DE LA OTRA OPCION HAY QUE ESCRIBIRLO, porque es de diseno y
    -- no de codigo: con la correa puesta en el hunt, un jugador aprende en dos
    -- partidas que basta con pararse afuera del circulo. Por eso el default es 1
    -- y el 2 existe para el que quiera un fantasma que literalmente no puede
    -- salir de la casa.
    -- ⚠ EL PASO POR ACA SE CUENTA, y no es decoracion: sin este contador, un
    -- fantasma cazando deja `libres` y `clamps` en 0, y el reporte tiene escrito
    -- *"LOS DOS EN CERO: el override no corrio ni una vez"*. O sea que el
    -- instrumento cantaria un ROJO sobre el mecanismo funcionando exactamente
    -- como se diseño. Es el nº 30 del catalogo del taller -- *una fila que
    -- pregunta CUAL DE DOS solo puede fallar si contesta NINGUNA* -- y esta vez
    -- se agarro antes de llegar al juego.
    if modo == 1 and self.phantom_Hunting then
        local st = estado( self )
        st.hunt = ( st.hunt or 0 ) + 1

        return base( self, endpos, isUnstuck )

    end

    if not isvector( endpos ) then return base( self, endpos, isUnstuck ) end

    local st = estado( self )

    -- ( 3 ) SIN NAVMESH NO HAY A DONDE CLAMPEAR. `getNearestPosOnNav` sobre un
    -- mapa sin areas devolveria un punto inutil y el destino nuevo seria peor
    -- que el viejo. Correa apagada es un estado legitimo y el reporte lo dice --
    -- *un default silencioso aca haria que "el fantasma no se escapa" y "la
    -- correa no existe" se lean igual.*
    if navmesh.GetNavAreaCount() <= 0 then return base( self, endpos, isUnstuck ) end

    local centro = ancla( self, st )
    local radio  = cvRadio:GetFloat()

    if endpos:DistToSqr( centro ) <= radio * radio then
        st.libres = st.libres + 1
        st.seguidos = 0

        return base( self, endpos, isUnstuck )

    end

    -- ( 4 ) LA VALVULA. Ver el bloque de CLAMPS_SEGUIDOS.
    st.seguidos = st.seguidos + 1

    if st.seguidos > CLAMPS_SEGUIDOS then
        st.seguidos = 0
        st.pasados  = st.pasados + 1

        return base( self, endpos, isUnstuck )

    end

    st.clamps  = st.clamps + 1
    st.ultimoT = CurTime()
    st.ultimaD = endpos:Distance( centro )

    -- ⚠ SE REEMPLAZA EL DESTINO, NO SE RECHAZA. Ver el encabezado: un rechazo
    -- encadena a `biginertia` y lo manda MAS lejos.
    local cerca = terminator_Extras and terminator_Extras.getNearestPosOnNav

    if not isfunction( cerca ) then return base( self, endpos, isUnstuck ) end

    local destino = cerca( centro )

    return base( self, ( destino and destino.pos ) or centro, isUnstuck )

end

---------------------------------------------------------------------------
-- INSTRUMENTO
---------------------------------------------------------------------------
PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_correa", function( ply, _, args )
    if IsValid( ply ) and not ply:IsAdmin() then
        ply:PrintMessage( HUD_PRINTCONSOLE, "[Phantasmagoria] hace falta ser admin." )
        return

    end

    local say = PHANTASMAGORIA.MakeSay( ply )
    local sub = args and args[ 1 ]

    if sub == "aqui" then
        local n = PHANTASMAGORIA.EachGhost( function( ghost )
            local st = estado( ghost )

            st.ancla   = ghost:GetPos()
            st.anclaDe = "mano"
            st.seguidos = 0

        end )

        say( "[Phantasmagoria] ancla de la correa fijada donde esta parado cada fantasma: " .. n .. " sujeto(s)." )
        say( "                 ⚠ los contadores NO se borran: hacen falta para comparar antes y despues." )
        return

    end

    say( "" )
    say( "===== LA CORREA ( pedido del autor, r2 fila 06 ) =====" )
    say( "  phantasmagoria_ghost_leash       = " .. cvLeash:GetInt() ..
        ( cvLeash:GetInt() == 0 and "  ( CONTROL: deambula por todo el mapa, como en la r2 )"
          or cvLeash:GetInt() == 1 and "  ( correa en CALMA; el hunt es libre )"
          or "  ( correa TAMBIEN en el hunt )" ) )
    say( "  phantasmagoria_ghost_leashradius = " .. math.Round( cvRadio:GetFloat() ) .. " u" ..
        "   ( ~" .. string.format( "%.1f", cvRadio:GetFloat() / 52.5 ) .. " m con la conversion de Diseno 1 )" )
    say( "  valvula     deja pasar 1 destino lejano cada " .. CLAMPS_SEGUIDOS ..
        " clamps seguidos ( para no disparar el rescate de la base en bucle )" )

    local vivos = PHANTASMAGORIA.EachGhost( function( ghost )
        local st = estado( ghost )

        say( "" )
        say( "  --- fantasma #" .. ghost:EntIndex() .. "/s" .. tostring( ghost.phantom_Serial or "?" ) ..
            "  ( " .. ( ghost.phantom_Hunting and "HUNT" or "calma" ) .. " ) ---" )

        -- ⚠ EL ANCLA PUEDE NO EXISTIR TODAVIA, y eso NO es un defecto: se
        -- captura en el primer SetupPathShell. Decirlo evita que un "sin ancla"
        -- se lea como la correa rota.
        if not st.ancla then
            say( "    ancla     TODAVIA NO CAPTURADA ( se toma en el primer destino que pida el bot )" )

        else
            local d = ghost:GetPos():Distance( st.ancla )

            say( "    ancla     " .. tostring( st.ancla ) .. "   ( " .. tostring( st.anclaDe ) .. " )" )
            say( "    distancia " .. math.Round( d ) .. " u   " ..
                ( d <= cvRadio:GetFloat() and "( ADENTRO de la correa )"
                  or "( !! AFUERA -- el proximo wander lo trae caminando, sin teleport )" ) )

        end

        -- ⚠ TRES CUENTAS Y NO UNA. `clamps 0` solo no distingue "la correa anda
        -- y el bot nunca quiso irse" de "la correa no corre". `libres` es el
        -- denominador: si `libres` sube y `clamps` no, el filtro esta corriendo
        -- y el bot simplemente se queda cerca. Si los DOS estan en 0, el
        -- override no se esta llamando.
        say( "    contados  destinos ADENTRO " .. st.libres ..
            " · CLAMPEADOS " .. st.clamps ..
            " · dejados pasar por la valvula " .. st.pasados ..
            " · pasados por HUNT " .. ( st.hunt or 0 ) )

        -- ⚠ LA CUARTA CUENTA ENTRA EN EL CRITERIO, y sin ella el veredicto era
        -- un falso rojo: con `leash 1` un fantasma cazando pasa DERECHO por la
        -- guarda del hunt, asi que `libres` y `clamps` quedan en 0 mientras el
        -- override corre decenas de veces por minuto -- exactamente como se
        -- diseño.
        if st.libres <= 0 and st.clamps <= 0 and ( st.hunt or 0 ) <= 0 then
            say( "              !! LOS TRES EN CERO: el override no corrio ni una vez. O el bot no pidio" )
            say( "                 un destino todavia, o SetupPathShell no esta encadenando." )

        elseif st.libres <= 0 and st.clamps <= 0 then
            say( "              ( los dos primeros en 0 con 'por HUNT' > 0 es CORRECTO: la correa no" )
            say( "                actua cazando con leash 1. Para medirla, sacarlo del hunt. )" )

        end

        if st.ultimoT then
            say( "    ultimo    clampeado hace " .. string.format( "%.1f", CurTime() - st.ultimoT ) ..
                " s, un destino que estaba a " .. math.Round( st.ultimaD or 0 ) .. " u del ancla" )

        end
    end )

    if vivos <= 0 then
        say( "" )
        say( "  no hay ningun fantasma en el mapa." )

    end

end, "Estado de la correa del fantasma. Subcomando: 'aqui' fija el ancla donde esta parado." )
