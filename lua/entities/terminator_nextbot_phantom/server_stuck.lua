--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom / EL ENCAJE CONTRA EL TECHO

    LO QUE REPORTO EL AUTOR, literal, y no salio de ninguna planilla sino de
    preguntarle por su experiencia con el NPC:

        "he visto que salta y queda pegado entre objetos y el techo de un
         interior, ahi hay que sacarlo con el physgun"

    Es peor que cualquier atasco de puerta: de un atasco de puerta el fantasma
    sale solo, de este no sale nunca.

    ---------------------------------------------------------------------------
    ESTE ARCHIVO NO ARREGLA NADA, Y ES A PROPOSITO
    ---------------------------------------------------------------------------

    La base TIENE rescate -- reallystuck_handler ( shared.lua:3647-3926 ) manda
    al bot a caminar a un costado y, si eso falla, LO TELETRANSPORTA. O sea que
    el rescate existe y NO RESCATO, y eso es lo que hay que explicar antes de
    tocar una sola linea de comportamiento.

    Hay tres mecanismos candidatos leidos en la base y NINGUNO medido. Los tres
    son LECTURA, no diagnostico, y en este proyecto esa diferencia ya costo dos
    rondas: en el bloque del giro se culpo al gate de TERM_FISTS y era la mitad
    equivocada, y en el silencio se culpo a la ventana y era el hook. La
    hipotesis del autor ( "tal vez se soluciona evitando que salte tanto" ) es
    razonable y tampoco esta medida.

    Asi que aca no hay perillas de comportamiento. Solo se mide.

    ---------------------------------------------------------------------------
    LA CORRECCION QUE DESTAPA ESTE BLOQUE, Y ES DE UN INSTRUMENTO NUESTRO
    ---------------------------------------------------------------------------

    ESTADO.md y el prompt del bloque dan por hecho que el rescate esta corriendo,
    con esta evidencia: "aparece en la lista de 32 tareas de cada
    phantasmagoria_ghost_where". Y esa lista NO PUEDE probar eso.

    _where recorre ghost.m_TaskList ( server.lua ), que es el REGISTRO estatico:
    SetupTasks lo llena con TODAS las tareas declaradas ( taskoverride.lua:398-402 )
    y nadie lo vacia nunca. Lo que dice si una tarea esta CORRIENDO es
    m_ActiveTasks ( terminator_nextbot_base/tasks.lua:104, que es lo que lee
    IsTaskActive ), y de ahi la saca endTask cuando termina.

    Y el reallystuck_handler puede terminarse SOLO, en su propio OnStart:

        if myTbl.ReallyStuckDisable then  self:TaskComplete( ... )   -- :3660
        if myTbl.MoveSpeed <= 0 then      self:TaskComplete( ... )   -- :3664

    En los dos casos la tarea sale de m_ActiveTasks y SIGUE en m_TaskList. O sea
    que _where la habria listado igual. *Una lista de lo que existe no puede
    contestar por lo que corre*, y la unica prueba que teniamos de que el rescate
    estaba vivo era exactamente esa lista.

    No se afirma que ese sea el defecto -- ReallyStuckDisable no lo declara nadie
    y MoveSpeed es 300 ( shared.lua:131 ), asi que lo mas probable es que la tarea
    este activa. Se afirma que NO ESTABA MEDIDO. Este archivo lo mide, y _where
    ahora marca cada tarea con "activa" o "solo registrada".

    ---------------------------------------------------------------------------
    DE DONDE SALE EL DATO: LA TABLA `data` DE LA BASE, NO UNA COPIA NUESTRA
    ---------------------------------------------------------------------------

    StartTask guarda la tabla de datos de cada tarea en myTbl.m_ActiveTasks[task]
    ( taskoverride.lua:201 ), y esa es LA MISMA TABLA que el handler recibe como
    `data` y va mutando. O sea que

        ghost.m_ActiveTasks[ "reallystuck_handler" ]

    da acceso de lectura al estado interno del rescate: historicPositions,
    historicNavs, maybeUnderCount, extremeUnstuckingUntil, nextUnstuckGotoEscape
    y freedomGotoPosSimple. No hace falta ninguna sombra.

    ESO IMPORTA MAS DE LO QUE PARECE. Una sombra -- recalcular por nuestra cuenta
    lo que la base calcula -- es el modo de falla que este proyecto ya pago: *un
    control que toma las dos mitades de la misma fuente no puede ver que esa
    fuente esta mal*. Lo unico que aca SI se recalcula son `stuck` y `sortaStuck`,
    porque son locales del pase y no viven en `data` -- pero se recalculan sobre
    los ARRAYS DE LA BASE, no sobre posiciones nuestras, y el reporte lo dice en
    la linea.

    ---------------------------------------------------------------------------
    LAS CUATRO SALIDAS QUE APAGAN EL RESCATE, Y SE MIDEN EN VEZ DE SUPONERSE
    ---------------------------------------------------------------------------

      1. myTbl.ReallyStuckDisable          shared.lua:3660   ( OnStart )
      2. myTbl.MoveSpeed <= 0              shared.lua:3664   ( OnStart )
      3. termhunter_doextremeunstucking    shared.lua:246, default 1
      4. que la tarea no este en m_ActiveTasks

    Nosotros no ponemos ninguna. El reporte las imprime igual: *hay que VERLO, no
    suponerlo* -- y la 3 es una convar de un tercero, que cualquiera puede haber
    movido en su servidor.

    ---------------------------------------------------------------------------
    LOS TRES CANDIDATOS, CON LA LINEA QUE LOS SEPARA
    ---------------------------------------------------------------------------

    (a) EL TELETRANSPORTE ESTA VETADO MIENTRAS EL BOT TE VE.  shared.lua:3868

            if not myTbl.IsSeeEnemy and extremeUnstucking:GetBool()
               and ( extremeStuck or not canGotoEscape ) then

        Si el fantasma se encaja SALTANDO HACIA VOS -- que es cuando pasa --
        sigue viendote, cae al elseif de :3899 y lo unico que hace es volver a
        intentar CAMINAR a un costado, cada 10 s, para siempre.
        Lo separa: la linea `ve al enemigo`.

    (b) DETECTARLO TARDA ~80 s SI NO ESTA EN EL PISO.  shared.lua:3714

        noNav exige myTbl.loco:IsOnGround(). Sin eso size queda en 80 en vez de
        10 ( :3710, :3718 ) y doAddCount en 1 en vez de 4 ( :3715, :3719 ), con
        una insercion por segundo ( nextCache, :3706 ). La evaluacion vive dentro
        de "if #data.historicPositions > size" ( :3771 ).
        Lo separa: la linea `en el piso`, y la cuenta regresiva de `hist`.

        OJO: no esta medido si un bot encajado entre props y el techo da
        IsOnGround true o false. Puede estar apoyado en un prop. ESO es lo
        primero que este instrumento tiene que contestar, y solo lo puede
        contestar con el bot encajado de verdad.

    (c) LA PRIMERA PASADA NUNCA ES LA DEL TELETRANSPORTE.  shared.lua:3864-3865

        extremeStuck = underDisplacement or not freedomPos, y IsUnderDisplacement
        ( :1986 ) mide DISPLACEMENTS DEL TERRENO, no props contra un techo.
        freedomPos casi siempre se encuentra. Y en el primer pase
        nextUnstuckGotoEscape y extremeUnstuckingUntil valen 0, asi que
        canGotoEscape es true y "not canGotoEscape" es false: la condicion entera
        da false y se va a caminar.
        Lo separa: la linea `escape`, y por eso el boton de abajo se aprieta DOS
        VECES.

    ---------------------------------------------------------------------------
    Y UNA CUARTA COSA QUE NINGUN PROMPT LISTABA, PORQUE SALE DE LA ARITMETICA
    ---------------------------------------------------------------------------

    La rama de caminar pone nextUnstuckGotoEscape = CurTime() + 80 ( :3911 ) y
    ademas vacia historicPositions ( :3923 ) con nextCache = CurTime() + 5
    ( :3915 ). Para un bot que NO esta en el piso, volver a juntar 81 posiciones
    a una por segundo tarda 81 s -- o sea que cuando el handler vuelve a poder
    evaluar, el reloj de 80 s YA VENCIO y canGotoEscape vuelve a ser true.

    Si eso es asi, el bot encajado en el aire no llega nunca a "not canGotoEscape"
    ni siquiera SIN mirar a nadie, y (a) no seria la unica puerta cerrada. Son 80
    contra 81: un margen de UN segundo, que es exactamente la clase de numero que
    no se puede cerrar leyendo. Por eso el reporte imprime los dos relojes con su
    signo y la cuenta regresiva de `hist` al lado -- para que la corrida lo
    conteste, no este comentario.

    ( isUnstucking duplica doAddCount ( :3725 ) y cambiaria la cuenta, pero dura
      a lo sumo 10 s ( unstuckingTimeout, :2143 ) y pide un path valido
      ( :2135 ). Se imprime tambien. )

    ---------------------------------------------------------------------------
    EL SALTO, QUE ES LA HIPOTESIS DEL AUTOR Y TAMPOCO ESTA MEDIDA
    ---------------------------------------------------------------------------

    ENT.JumpHeight de este fantasma es 245 -- lo hereda de la base
    ( shared.lua:111, 70 * 3.5 ) y lo confirmo phantasmagoria_ghost_steps jump.
    Es alto de verdad. Pero que el salto SEA la causa del encaje sigue sin
    medirse, y aca no se decide: se cuenta.

    Dato leido y con consecuencia: ENT.Term_Leaps es nil en la base
    ( shared.lua:112 ) y este fantasma no lo declara, asi que las dos ramas de
    salto-hacia-el-enemigo ( motionoverrides.lua:2693 y :2697 ) estan MUERTAS
    para nosotros, y con ellas el unico call site de JumpToPos ( :2744 ). O sea
    que `saltos leap` tiene que dar 0 SIEMPRE. Es un control gratis: si algun dia
    da otra cosa, alguien declaro Term_Leaps y no lo dijo.

    Lo que si puede saltar es la rama de :2749 -- Jump( jumpingHeight + 20 ),
    clampeado a JumpHeight -- por jumpstate == 1 ( GetJumpBlockState ) o por
    goalBasedJump ( "esta arriba nuestro" + IsAngry, :2668 ).

    Y un salto PEDIDO no es un salto OCURRIDO: ENT:Jump se sale en silencio si no
    esta en el piso ( motionoverrides.lua:2971 ). Los contadores separan las dos
    cosas, que es la leccion del boton `jump` de las pisadas: *un salto que no
    ocurre se lee igual que un salto sin consecuencia.*
---------------------------------------------------------------------------]]

local TASK = "reallystuck_handler"

---------------------------------------------------------------------------
-- Las constantes de la base, espejadas UNA VEZ y con su linea
---------------------------------------------------------------------------
-- Ningun numero de este reporte se tipea a mano. Es la misma regla que el
-- reporte de puertas: un instrumento que anuncia "el umbral es 80" con un 80
-- escrito al lado deja de decir la verdad el dia que la base cambia, y lo hace
-- en silencio.
local B = {
    SIZE          = 80,   -- shared.lua:3710
    SIZE_DIV      = 8,    -- shared.lua:3718   size = size / 8  -> 10
    ADD           = 1,    -- shared.lua:3715
    ADD_NONAV     = 4,    -- shared.lua:3719   doAddCount * 4
    ADD_UNSTUCK   = 2,    -- shared.lua:3726   doAddCount * 2
    CACHE_SECS    = 1,    -- shared.lua:3706   una insercion por segundo
    STUCK_RADIUS  = 15,   -- shared.lua:3792   SqrDistGreaterThan( distSqr, 15 )
    NAV_RADIUS    = 50,   -- shared.lua:3709   criterio "pretty tight"
    NAV_FAR       = 200,  -- shared.lua:3807   el instant unstuck check
    UNDER_THRESH  = 6,    -- shared.lua:3767   3 si IsFodder
    UNDER_FODDER  = 3,
    FREEDOM_BOX   = 3000, -- shared.lua:3833
    ESCAPE_SECS   = 80,   -- shared.lua:3911   nextUnstuckGotoEscape
    WALK_SECS     = 10,   -- shared.lua:3913   extremeUnstuckingUntil
    AFTER_WALK    = 5,    -- shared.lua:3915   nextCache
    ARRIVED_DIST  = 150,  -- shared.lua:3676   dist < 150 -> SUCCESS
}

-- El umbral de verdad es "#historicPositions > size", o sea size + 1 entradas.
local function threshold( size )
    return size + 1

end

---------------------------------------------------------------------------
-- Acceso a la tabla `data` del handler
---------------------------------------------------------------------------
-- Devuelve DOS cosas y la segunda es el motivo, por lo mismo que resolve() en
-- las puertas: "no hay data" tiene causas distintas que desde afuera se ven
-- igual -- la tarea nunca se registro, o se registro y su OnStart la termino.
local function stuckData( ghost )
    local activas = ghost.m_ActiveTasks

    if not istable( activas ) then
        return nil, "el bot no tiene m_ActiveTasks todavia ( no termino de inicializar )"

    end

    local data = activas[ TASK ]

    if istable( data ) then return data, "activa" end

    -- Y aca esta la distincion que _where no podia hacer.
    local registrada = istable( ghost.m_TaskList ) and ghost.m_TaskList[ TASK ] ~= nil

    if registrada then
        return nil, "REGISTRADA PERO NO ACTIVA: su OnStart la termino ( ReallyStuckDisable o MoveSpeed <= 0 )"

    end

    return nil, "NI SIQUIERA REGISTRADA: DoCustomTasks la saco del arbol de tareas"

end

---------------------------------------------------------------------------
-- Los contadores
---------------------------------------------------------------------------
-- `rescates` no es la suma de `teleport` + `caminar`: la rama de caminar se
-- cuenta por el reloj ( ver el poll ) y la del teleport por el motivo con el que
-- la base arranca movement_handler. Si alguna vez rescates > teleport + caminar,
-- hubo un pase que entro al if de :3816 y no salio por ninguna de las dos, que
-- es un caso que hoy el codigo no tiene -- y verlo seria el dato.
local function stuckStats( ghost )
    ghost.phantom_stuckStats = ghost.phantom_stuckStats or {
        rescates = 0, teleport = 0, caminar = 0, exitos = 0, fallos = 0,
        saltos = 0, saltosEnPiso = 0, saltosLeap = 0,
        -- El arreglo. `sinReemplazo` NO es lo mismo que `corregidos = 0`: uno
        -- dice que el destino estaba bien, el otro que estaba mal y no habia
        -- adonde mandarlo. Un solo contador confundiria las dos cosas.
        corregidos = 0, sinReemplazo = 0, cortosVistos = 0,
        -- El bailout. `bailoutSinDonde` es su propio `sinReemplazo`: no hay
        -- adonde mandarlo, que es distinto de que no haya hecho falta.
        bailouts = 0, bailoutSinDonde = 0,
    }

    return ghost.phantom_stuckStats

end

---------------------------------------------------------------------------
-- La bitacora: TRANSICIONES, no muestras
---------------------------------------------------------------------------
-- Mismo criterio que la de pisadas: una linea por muestra serian 4 por segundo y
-- eso no es una bitacora, es ruido que tapa el dato. Y la identidad va con
-- GetCreationID al lado del EntIndex porque GMod REUSA el indice: la ronda 8
-- mostro dos NPCs distintos leidos como uno.
local BITACORA_MAX = 40

PHANTASMAGORIA.StuckLog = PHANTASMAGORIA.StuckLog or {}

local function anotar( ghost, texto )
    local log = PHANTASMAGORIA.StuckLog

    log[ #log + 1 ] = string.format( "%6.1f  #%s/c%s  %s",
        CurTime(), ghost:EntIndex(), ghost:GetCreationID(), texto )

    while #log > BITACORA_MAX do table.remove( log, 1 ) end

end

PHANTASMAGORIA.AnotarStuck = anotar

---------------------------------------------------------------------------
-- El estado completo, en un solo lugar
---------------------------------------------------------------------------
-- Todo lo que devuelve sale de la base. Lo unico calculado por nosotros son
-- `stuck`, `sortaStuck` y `quieto`, y los tres van etiquetados como tales en el
-- reporte -- porque *un instrumento que no dice de donde saca cada numero deja
-- que un recalculo pase por medicion*.
function ENT:phantom_StuckState()
    local myTbl = self:GetTable()
    local data, porQue = stuckData( self )
    local loco = myTbl.loco

    local s = {
        data      = data,
        dataPorQue = porQue,
        pos       = self:GetPos(),
        enPiso    = loco and loco:IsOnGround() or false,
        veEnemigo = myTbl.IsSeeEnemy == true,
        enemigo   = self:GetEnemy(),
        fodder    = myTbl.IsFodder == true,
        unstuck   = myTbl.isUnstucking == true,
        override  = myTbl.overrideVeryStuck,
        saltando  = myTbl.m_Jumping == true,
        leapeando = myTbl.m_JumpingToPos == true,
        cayendo   = myTbl.m_Falling == true,

        -- Las cuatro salidas
        disable   = myTbl.ReallyStuckDisable,
        moveSpeed = myTbl.MoveSpeed,
    }

    local cv = GetConVar( "termhunter_doextremeunstucking" )

    -- Con guarda, y no es paranoia: la convar es de la BASE. Si la base no cargo
    -- o le cambian el nombre, esto tiene que decirlo y no caerse.
    -- ( shared.lua:246, default 1 )
    s.teleportOn   = cv and cv:GetBool() or false
    s.teleportConv = cv and cv:GetInt() or nil

    -- El navarea con los MISMOS argumentos que :3709. Es una funcion pura de la
    -- posicion, asi que preguntarla dos veces no la mueve.
    local nav = navmesh.GetNearestNavArea( s.pos, false, B.NAV_RADIUS, false, false, -2 )

    s.nav      = IsValid( nav ) and nav or nil
    s.navVecin = s.nav and #s.nav:GetAdjacentAreas() or 0

    -- noNav es la condicion ENTERA de :3714, con el IsOnGround adelante. Se
    -- escribe igual que alla, en el mismo orden, para que se pueda comparar.
    s.noNav = s.enPiso and ( not s.nav or s.navVecin <= 0 )

    s.size    = s.noNav and ( B.SIZE / B.SIZE_DIV ) or B.SIZE
    s.umbral  = threshold( s.size )
    -- `porPase` y `faltan` VIVIAN ACA Y SE FUERON con la linea que los imprimia:
    -- eran una prediccion del ritmo de insercion que la ronda 10 refuto en su
    -- propia salida ( ver el comentario del reporte ). Un campo que se calcula y
    -- nadie lee parece un registro autoritativo y no lo es.

    -- La nav mas lejana que mira el "instant unstuck check" de :3807. Se imprime
    -- porque es la otra puerta rapida y pide lo mismo ( noNav ), o sea que
    -- tampoco salva a un bot en el aire.
    local navLejos = navmesh.GetNearestNavArea( s.pos, false, B.NAV_FAR, false, false, -2 )
    s.navLejos = IsValid( navLejos ) and navLejos or nil

    if not data then return s end

    local hist = data.historicPositions
    local navs = data.historicNavs

    s.hist = istable( hist ) and #hist or 0
    s.navs = istable( navs ) and #navs or 0

    s.evalua = s.hist >= s.umbral

    -- RECALCULADO, y sobre los arrays de la BASE. `stuck` y `sortaStuck` son
    -- locales del pase ( :3745-3746 ) y no sobreviven a la llamada; lo que si
    -- sobrevive son las dos listas, que es de donde salen.
    if istable( hist ) then
        s.stuck = true

        for _, historicPos in ipairs( hist ) do
            if s.pos:DistToSqr( historicPos ) > B.STUCK_RADIUS ^ 2 then
                s.stuck = false
                break

            end
        end
    end

    if istable( navs ) then
        s.sortaStuck = true

        for _, historicNav in ipairs( navs ) do
            if historicNav ~= nav then
                s.sortaStuck = false
                break

            end
        end
    end

    s.maybeUnder  = data.maybeUnderCount or 0
    s.underThresh = s.fodder and B.UNDER_FODDER or B.UNDER_THRESH
    s.under       = s.maybeUnder >= s.underThresh

    -- LOS DOS RELOJES, con su signo. Negativo = ya vencio.
    s.escapeIn = ( data.nextUnstuckGotoEscape or 0 ) - CurTime()
    s.walkIn   = ( data.extremeUnstuckingUntil or 0 ) - CurTime()
    s.cacheIn  = ( data.nextCache or 0 ) - CurTime()

    -- canGotoEscape, EXACTO: los dos terminos salen de `data`. :3865
    s.canEscape = s.escapeIn < 0 and s.walkIn < 0

    s.caminandoA = data.freedomGotoPosSimple

    return s

end

---------------------------------------------------------------------------
-- ¿Existe freedomPos? -- PREDICCION, no medicion, y se dice
---------------------------------------------------------------------------
-- extremeStuck = underDisplacement or not freedomPos ( :3864 ), asi que sin
-- saber si freedomPos existe no se puede predecir la rama. freedomPos se elige
-- en el loop de :3836-3859, que ademas prefiere areas visibles -- pero eso
-- decide CUAL, no SI. Para el binario alcanza con la primera que pase los dos
-- filtros, que es exactamente lo que hace el "if not freedomPos then" de :3846.
--
-- ES UNA RE-DERIVACION Y PUEDE DIVERGIR. Se marca como prediccion en el reporte
-- y la medicion de verdad sigue siendo por que rama salio la base. Tener las dos
-- es lo que permite que una refute a la otra; si el reporte predijera "camina" y
-- la base teletransportara, el que esta mal es este loop y se ve.
--
-- Con minDist > 0 deja de ser una re-derivacion y pasa a ser EL ARREGLO: la
-- misma busqueda, pero exigiendo que el destino este a mas de esa distancia.
-- Devuelve el MAS CERCANO que la pase, para no mandar al bot a cruzar el mapa.
local function buscarEscape( ghost, minDist )
    local myPos   = ghost:GetPos()
    local enemigo = ghost:GetEnemy()

    local distToEnemy = 0
    local enemyPos    = myPos

    if IsValid( enemigo ) then
        distToEnemy = ghost.DistToEnemy or 0
        enemyPos    = ghost.EnemyLastPos or enemigo:GetPos()

    end

    -- El nearestNavArea del loop NO es el de :3709: usa 10000 de radio y otros
    -- flags ( :3830 ). Se copia tal cual, porque es el que se excluye.
    local nearest = navmesh.GetNearestNavArea( myPos, false, 10000, false, true, 2 )

    local maxs  = Vector( B.FREEDOM_BOX, B.FREEDOM_BOX, B.FREEDOM_BOX )
    local caja  = navmesh.FindInBox( myPos + maxs, myPos + -maxs )
    local total = #caja

    local mejor, mejorDist, pasaron = nil, math.huge, 0

    for _, area in ipairs( caja ) do
        if area == nearest then continue end
        if not IsValid( area ) then continue end

        local centro = area:GetCenter()

        -- El filtro de la base que NO se puede perder: no desatascar al bot
        -- acercandolo al enemigo ( :3843 ).
        if centro:Distance( enemyPos ) < distToEnemy then continue end

        local distToMe = centro:Distance2D( myPos )

        if distToMe < minDist then continue end

        pasaron = pasaron + 1

        if distToMe < mejorDist then
            mejorDist = distToMe
            mejor     = centro

        end
    end

    return mejor, total, pasaron, mejorDist

end

local function freedomPosExists( ghost )
    local mejor, total = buscarEscape( ghost, 0 )

    return mejor ~= nil, total

end

---------------------------------------------------------------------------
-- EL ARREGLO: un destino que no puede nacer ya cumplido
---------------------------------------------------------------------------
-- MEDIDO EN LA RONDA 9, y no es ninguno de los tres candidatos que se leyeron.
-- El rescate ARRANCA -- siete veces en 60 s, cada 10 s clavados -- y no mueve al
-- bot un centimetro. La bitacora lo dijo con dos numeros que no se pueden
-- discutir: `quieto` subiendo monotono de 1,5 a 59,7 s, y cinco
-- `la caminata LLEGO` sobre la MISMA posicion exacta. Los teleports de la misma
-- sesion movieron 83, 8 y 46 u: ninguno llega a dos metros.
--
-- LA CAUSA, en dos lineas de la base que se muerden entre si:
--
--   :3849   elseif not wasVisible and distToMe < bestDist then   -> el MAS CERCANO
--   :3676   if dist < 150 then ... reallystuck SUCCESS           -> llego
--
-- El destino se elige por distancia minima entre las navareas de una caja de
-- +-3000 u, excluyendo solo la de abajo. En un mapa PARCHEADO por la propia base
-- ( 1715 navareas en la corrida, y el parcheador crea areas donde camina
-- alguien ) "la mas cercana que no es la mia" esta pegada -- y nace ya debajo
-- del umbral con el que :3676 la va a dar por cumplida.
--
-- *Un rescate cuyo destino nace debajo de su propio umbral de exito se anuncia
-- exitoso sin rescatar.*
--
-- EL ARREGLO ES EL MINIMO QUE ATACA ESA CAUSA: cuando la base pone un destino
-- mas cerca que MIN, lo reemplazamos por el mas cercano que este MAS LEJOS que
-- MIN. No se toca el handler, no se copia la tarea, no se envuelve ningun
-- global de terceros: se corrige un campo de `data`, que es el mismo que ya
-- leiamos para medir.
--
-- POR QUE ALCANZA CON LA CAMINATA, aunque el teleport tenga el mismo defecto:
-- la rama del teleport solo se alcanza con `not canGotoEscape`, y ese reloj lo
-- pone la caminata al fallar ( :3911 ). Si la caminata funciona, el bot se
-- despega y no se llega al teleport. Es una prediccion, no una medicion -- y el
-- instrumento sigue contando los teleports con su distancia, asi que si siguen
-- apareciendo cortos se va a ver.
--
-- EL DEFAULT ES 300 Y SALE DE UN NUMERO DE LA BASE, no de un gusto: es el DOBLE
-- del umbral de :3676. Un destino a mas de 2x el radio de exito no puede nacer
-- cumplido ni quedar cumplido por el primer paso.
--
-- Y 0 ES EL CONTROL, con la convencion de la casa: apaga la correccion y deja el
-- comportamiento de la ronda 9, que es el lado del A/B que ya esta medido.
local cvEscapeDist = CreateConVar( "phantasmagoria_ghost_escapedist", tostring( B.ARRIVED_DIST * 2 ), FCVAR_ARCHIVE,
    "Distancia MINIMA a la que se corrige el destino del rescate de la base. 0 = sin corregir ( control: el comportamiento medido en la ronda 9 ). " ..
    "El default es el doble del umbral con el que shared.lua:3676 da la caminata por terminada.", 0, 3000 )

---------------------------------------------------------------------------
-- EL DEFECTO DE ABAJO, QUE EL ARREGLO DE ARRIBA DESTAPO
---------------------------------------------------------------------------
-- LA RONDA 10 REFUTO UNA PREDICCION MIA, Y ESTABA ESCRITA COMO PREDICCION. El
-- pie de la planilla decia: "la apuesta es que arreglando la caminata el bot se
-- despega y nunca se llega a la rama del teleport". Falso.
--
-- Con el destino ya corregido a 306 u, el autor lo dejo encajado y la bitacora
-- dio esto CINCO veces seguidas, con la misma posicion hasta el sexto decimal:
--
--   759.8  DESTINO CORREGIDO  100 u -> 306 u
--   769.8  la caminata SE VENCIO ( 10 s )   SE MOVIO 0 u   el destino estaba a 306 u
--   771.9  DESTINO CORREGIDO  100 u -> 306 u
--   781.8  la caminata SE VENCIO ( 10 s )   SE MOVIO 0 u   ...
--
-- *SE MOVIO 0 u en 10 s con un destino sano.* El arreglo de arriba hizo lo que
-- prometia -- `llego` cayo de 7/7 a 1/6 y el resto dice `se vencio`, que es la
-- verdad -- y con eso quedo a la vista lo que aquel exito falso tapaba: **el bot
-- encajado no puede caminar**. No es que el rescate lo mande mal: es que la
-- caminata no es un rescate para este caso, por construccion.
--
-- Y LA OTRA MITAD ES EL VETO. La unica rama que saca a un bot que no se puede
-- mover es el teleport, y :3868 la prohibe mientras `IsSeeEnemy` sea true --
-- que es exactamente la situacion del autor, porque se encaja saltando HACIA el.
-- Las dos mitades juntas dan el sintoma tal como lo reporto:
--
--     no puede caminar  +  no puede teletransportarse  =  hay que sacarlo con
--     el physgun.
--
-- POR ESO ESTE BAILOUT EXISTE.
--
-- ⚠⚠ Y SU PRIMER GATILLO ERA MIO Y ESTABA MAL. LA RONDA 11 LO REFUTO SIN QUE
-- NINGUNA FILA LO PIDIERA: contaba "N caminatas seguidas que vencen habiendose
-- movido menos de 15 u", y con el bot encajado de verdad **nunca disparo**.
-- `disparados 0` con `llevamos 0` en las dos mitades del A/B. Dos causas, y las
-- dos son del gatillo:
--
--   ① EL BOT ENCAJADO SE MUEVE. Las caminatas dieron `SE MOVIO 93 u`, `69 u`,
--     `64 u` -- se sacude adentro de la jaula de props sin salir de ella. Cada
--     una de esas reseteaba el contador. *Cuanto se movio la caminata no dice si
--     el bot se despego: dice cuanto se agito en el lugar.*
--
--   ② ENTRE CAMINATA Y CAMINATA PUEDEN PASAR 81 SEGUNDOS. El gatillo colgaba del
--     FIN de una caminata, y la caminata la arranca el handler -- que despues de
--     cada rescate vacia `historicPositions` ( :3923 ) y necesita volver a
--     juntar 81 a una por segundo cuando el bot esta en el piso. Medido en la
--     ronda 11: `rescates 1` en toda una ventana de 100 s, con `hist 80/81` al
--     final. Con N = 3 caminatas, el bailout tardaria CUATRO MINUTOS en llegar.
--
-- Las dos son el mismo error: **medi el movimiento de la caminata en vez del
-- desplazamiento neto desde que quedo trabado**, y ate el arreglo al reloj del
-- mecanismo que estoy arreglando. *Un rescate que espera al que fallo hereda su
-- latencia.*
--
-- EL GATILLO BUENO YA ESTABA MEDIDO Y A LA VISTA EN EL REPORTE: `quieto desde`,
-- que es el tiempo desde que el bot salio por ultima vez de un radio de 15 u --
-- el mismo radio con el que la base define "stuck" ( :3792 ). Llego a 59,7 s en
-- la ronda 10 y a 47 s en la 11, y en un bot sano se queda en 0-1 s ( medido en
-- el control de la ronda 11: 100 muestras deambulando, `quieto` nunca paso de
-- 1 s ). No depende del handler, no lo resetea una sacudida, y se puede leer en
-- cualquier tick.
--
-- Y PIDE ADEMAS QUE EL BOT QUIERA MOVERSE: `GetDesiredSpeed()` alto con
-- `GetCurrentSpeed()` en cero. Sin eso, el dia que exista `movement_watch` -- el
-- comportamiento de Diseno 18 que se planta a distancia a mirarte -- un fantasma
-- quieto A PROPOSITO se teletransportaria solo. *Estar quieto y estar trabado se
-- ven igual desde una posicion; lo que los separa es si queria moverse.*
--
-- ⚠ TELETRANSPORTA A UN FANTASMA QUE TE ESTA MIRANDO, y eso se ve. Es un cambio
-- de comportamiento, no un arreglo invisible: el default es 20 s porque la
-- alternativa medida es que el jugador lo saque con el physgun, y 0 lo apaga
-- entero para el A/B.
--
-- ⚠ Y LA CONVAR CAMBIO DE NOMBRE PORQUE CAMBIO DE UNIDAD. La vieja se llamaba
-- `_stuckbailout` y contaba CAMINATAS; esta cuenta SEGUNDOS. Las dos son
-- FCVAR_ARCHIVE, asi que un servidor que hubiera guardado `stuckbailout 3` leeria
-- ese 3 como tres segundos y teletransportaria al fantasma todo el tiempo.
-- *Una perilla que cambia de unidad tiene que cambiar de nombre, o el valor
-- guardado miente en silencio.*
local cvBailout = CreateConVar( "phantasmagoria_ghost_stuckbailoutsecs", "20", FCVAR_ARCHIVE,
    "SEGUNDOS que el bot puede pasar sin salir de un radio de 15 u ( QUERIENDO moverse ) antes de que lo teletransportemos nosotros. " ..
    "0 = nunca ( control: el comportamiento medido en la ronda 10, donde el bot quedo trabado para siempre ). " ..
    "Existe porque con el bot encajado la caminata no lo mueve y el teleport de la base esta vetado por IsSeeEnemy ( shared.lua:3868 ). " ..
    "OJO: reemplaza a _stuckbailout, que contaba CAMINATAS y nunca llegaba a disparar.", 0, 300 )

-- Debajo de esto no hay intencion de moverse que valga: es el mismo numero que
-- server.lua usa como frontera de "casi quieto" para la mirada.
local BAILOUT_SPEED = 30

---------------------------------------------------------------------------
-- La prediccion de la rama, escrita ANTES de correr
---------------------------------------------------------------------------
-- Devuelve la rama y el termino que la decide. Que devuelva el TERMINO y no
-- solo la rama es lo que la hace util: "camina" no dice si fue por el veto de
-- IsSeeEnemy o por canGotoEscape, y esas son dos hipotesis distintas que desde
-- afuera se ven iguales -- que es el motivo entero de este archivo.
local function predecirRama( s, hayFreedom )
    if not s.data then return "NINGUNA", "el rescate no esta corriendo ( " .. s.dataPorQue .. " )" end
    if not s.teleportOn then
        return "CAMINAR", "termhunter_doextremeunstucking esta en 0: el teleport esta apagado en el servidor"

    end

    local extremeStuck = s.under or not hayFreedom

    if s.veEnemigo then
        return "CAMINAR", "el VETO de :3868 -- IsSeeEnemy es true. Es el candidato (a), y es el unico termino que lo cierra"

    end

    if not ( extremeStuck or not s.canEscape ) then
        return "CAMINAR", "extremeStuck NO ( underDisplacement " .. ( s.under and "SI" or "NO" ) ..
            ", freedomPos " .. ( hayFreedom and "EXISTE" or "no existe" ) .. " ) y canGotoEscape SI. Es el candidato (c)"

    end

    return "TELEPORT", "no ve al enemigo, y " ..
        ( extremeStuck and "extremeStuck SI" or "canGotoEscape NO ( el reloj de " .. B.ESCAPE_SECS .. " s sigue corriendo )" )

end

---------------------------------------------------------------------------
-- EL POLL
---------------------------------------------------------------------------
-- Cuelga de ENT:AdditionalThink, que la base declara como stub vacio
-- ( shared.lua:2872, "THINK stub, inside coroutine! for your convenience" ) y
-- llama en cada pase de la corrutina de prioridad ( behaviouroverrides.lua:676 ).
--
-- NO va en ENT.MyClassTask.Think, y no es una preferencia: server_doors.lua ya
-- declaro esa clave, y una segunda asignacion la pisaria entera. El sintoma
-- seria el bloque de puertas dejando de correr sin un solo error. Al final del
-- archivo hay una guarda que lo comprueba en vez de confiar en que me acuerde.
--
-- QUE MIRA, Y POR QUE NO MIRA freedomGotoPosSimple:
--
-- El marcador obvio de "arranco la rama de caminar" seria que
-- data.freedomGotoPosSimple pase de nil a un vector. Y es FRAGIL: el bloque de
-- :3674 corre al principio de CADA pase y lo borra apenas la distancia baja de
-- 150 u, o sea que puede aparecer y desaparecer entre dos muestras nuestras.
-- *Un instrumento mas fragil que lo que mide se rompe justo cuando hace falta.*
--
-- El marcador que si sirve es data.nextUnstuckGotoEscape: la rama de caminar lo
-- pone en CurTime() + 80 ( :3911 ) y NADIE lo baja nunca. Un valor que sube y se
-- queda 80 s arriba no se lo pierde un muestreo de 4 Hz.
local POLL_HZ = 0.25

local function poll( self, myTbl )
    local nxt = myTbl.phantom_stuckNextPoll or 0
    if nxt > CurTime() then return end

    myTbl.phantom_stuckNextPoll = CurTime() + POLL_HZ

    local data = myTbl.m_ActiveTasks and myTbl.m_ActiveTasks[ TASK ]
    local pos  = self:GetPos()

    ---------------------------------------------------------------------------
    -- Cuanto hace que no se mueve. ES NUESTRO, y con el radio de la base.
    ---------------------------------------------------------------------------
    -- No reemplaza a `stuck`: la base pide que TODAS las posiciones historicas
    -- esten dentro del radio, esto solo mide desde la ultima vez que salio de el.
    -- Sirve para el caso que la base todavia no puede evaluar, que es justamente
    -- el del bot encajado en el aire durante los primeros 80 s.
    local ancla = myTbl.phantom_stuckAnchor

    if not ancla or pos:DistToSqr( ancla ) > B.STUCK_RADIUS ^ 2 then
        myTbl.phantom_stuckAnchor = pos
        myTbl.phantom_stuckSince  = CurTime()

    end

    ---------------------------------------------------------------------------
    -- EL GATILLO DEL BAILOUT, sobre el numero que la ronda 11 dejo a la vista
    ---------------------------------------------------------------------------
    -- Vive ACA y no en el fin de una caminata, y eso es el arreglo entero: el
    -- gatillo viejo colgaba del handler y heredaba su latencia de hasta 81 s, y
    -- se reseteaba con cada sacudida dentro de la jaula. `quieto` no depende de
    -- nadie -- se mide contra el ancla de arriba, que es el mismo radio con el
    -- que la base define "stuck".
    --
    -- LAS DOS CONDICIONES SON UNA SOLA IDEA: quieto Y queriendo moverse. Sin la
    -- segunda, un fantasma plantado a proposito -- `movement_watch`, que es
    -- Diseno 18 y hoy esta registrada pero no corriendo -- se teletransportaria
    -- solo. *Estar quieto y estar trabado se ven igual desde una posicion.*
    local tope = cvBailout:GetInt()

    if tope > 0 and not myTbl.phantom_bailoutPendiente then
        local quieto  = CurTime() - ( myTbl.phantom_stuckSince or CurTime() )
        local deseada = myTbl.loco and myTbl.loco:GetDesiredSpeed() or 0
        local real    = myTbl.GetCurrentSpeed( self )

        if quieto >= tope and deseada > BAILOUT_SPEED and real < BAILOUT_SPEED then
            myTbl.phantom_bailoutPendiente = true
            myTbl.phantom_bailoutPorQue = string.format( "quieto %.1f s ( tope %d ) · deseada %d u/s · real %d u/s",
                quieto, tope, math.Round( deseada ), math.Round( real ) )

        end
    end

    ---------------------------------------------------------------------------
    -- La muestra anterior, para poder decir CUANTO SE MOVIO en un evento
    ---------------------------------------------------------------------------
    -- Sin esto, "SALIO POR TELEPORT" no distingue un rescate de un manotazo: la
    -- ronda 9 midio teleports de 8, 46 y 83 u -- menos de dos metros -- y el
    -- unico motivo por el que se vio fue que el muestreador del boton `force`
    -- comparaba contra una posicion guardada. La bitacora no lo hacia.
    local antesPos = myTbl.phantom_stuckPollPos
    local antesT   = myTbl.phantom_stuckPollTime

    myTbl.phantom_stuckPollPos  = pos
    myTbl.phantom_stuckPollTime = CurTime()

    myTbl.phantom_stuckPrevPos  = antesPos or pos
    myTbl.phantom_stuckPrevTime = antesT or CurTime()

    ---------------------------------------------------------------------------
    -- La rama de CAMINAR, por el reloj que no baja nunca
    ---------------------------------------------------------------------------
    if not data then return end

    ---------------------------------------------------------------------------
    -- EL DELTA DE `hist`, MEDIDO -- y esto reemplaza a un numero que YO predecia
    ---------------------------------------------------------------------------
    -- ⚠ DEFECTO DE INSTRUMENTO QUE DESTAPO LA RONDA 9, Y ERA MIO. El reporte
    -- imprimia `hist N / umbral` con el numerador de la BASE y el denominador
    -- calculado por MI, cada uno muestreado en un instante distinto. Con el bot
    -- encajado en el borde de una navarea, `noNav` oscilaba entre muestras y la
    -- salida quedo asi:
    --
    --     10 s  hist 86/11      11 s  hist 92/81      39 s  hist 92/11
    --
    -- El umbral saltando entre 11 y 81 de un segundo al otro. *Una fraccion
    -- cuyo numerador y denominador vienen de dos relojes distintos no es una
    -- fraccion.*
    --
    -- Y el criterio de la planilla ("sube de a 1 o de a 4") era INCUMPLIBLE por
    -- otro motivo mio: doAddCount inserta ( 1, 2, 4 u 8 ) pero el trimming de
    -- :3774-3777 saca DOS por pase una vez superado el umbral, asi que lo que se
    -- ve es el NETO. Lo medido fue +6, que es 8 - 2 -- o sea noNav ( x4 ) con
    -- isUnstucking ( x2 ), y el reporte confirmaba `isUnstucking true` al lado.
    -- Ninguno de los dos valores que yo habia escrito podia aparecer nunca.
    --
    -- El arreglo es dejar de predecirlo: se mide el salto real entre muestras.
    local hist = istable( data.historicPositions ) and #data.historicPositions or 0
    local histAntes = myTbl.phantom_stuckHistPrev

    if histAntes and hist ~= histAntes then
        myTbl.phantom_stuckHistJump   = hist - histAntes
        myTbl.phantom_stuckHistJumpAt = CurTime()

    end

    myTbl.phantom_stuckHistPrev = hist

    ---------------------------------------------------------------------------
    -- Adonde dijo la base que iba a caminar, y desde donde
    ---------------------------------------------------------------------------
    -- La base BORRA data.freedomGotoPosSimple antes de anunciar el SUCCESS
    -- ( :3677, y el StartTask recien en :3679 ), asi que en el evento ya no
    -- esta. Se guarda al verlo para poder contestar la pregunta que la ronda 9
    -- dejo abierta: *cuando la caminata "LLEGO", cuanto se habia movido.*
    local destino = data.freedomGotoPosSimple

    if destino then
        if not myTbl.phantom_stuckWalkTo then
            myTbl.phantom_stuckWalkFrom = pos
            myTbl.phantom_stuckWalkAt   = CurTime()

        end

        myTbl.phantom_stuckWalkTo = destino

    end

    local escape = data.nextUnstuckGotoEscape or 0
    local visto  = myTbl.phantom_stuckLastEscape

    -- La primera muestra solo ancla: sin esto, un fantasma que ya venia con el
    -- reloj puesto contaria un rescate que ocurrio antes de que mirasemos.
    if visto == nil then
        myTbl.phantom_stuckLastEscape = escape
        return

    end

    if escape <= visto then return end

    myTbl.phantom_stuckLastEscape = escape

    local st = stuckStats( self )
    st.rescates = st.rescates + 1
    st.caminar  = st.caminar + 1

    local s = self:phantom_StuckState()

    -- Arranca una caminata nueva: se reinicia el par ORIGEN/DESTINO para que el
    -- SUCCESS de mas abajo mida ESTA caminata y no la anterior.
    myTbl.phantom_stuckWalkFrom = pos
    myTbl.phantom_stuckWalkAt   = CurTime()
    myTbl.phantom_stuckWalkTo   = data.freedomGotoPosSimple

    -- LA DISTANCIA AL DESTINO, QUE ES LO QUE LA RONDA 9 NO PUDO CONTESTAR.
    -- La base declara la caminata terminada con dist < 150 ( :3676 ), asi que un
    -- destino que ya nace debajo de ese numero convierte al rescate en un
    -- no-operativo que se anuncia como exito. Sin esta columna, siete
    -- `la caminata LLEGO` sobre la misma posicion se leen como siete rescates.
    local aDestino = "sin destino"

    if data.freedomGotoPosSimple then
        aDestino = math.Round( pos:Distance2D( data.freedomGotoPosSimple ) ) .. " u ( llega con < " .. B.ARRIVED_DIST .. " )"

    end

    -- EL CONTEXTO VIAJA CON EL EVENTO. Un "rescate 3" suelto no dice nada; lo
    -- que separa las hipotesis es con que valores arranco -- y esos valores
    -- cambian en el segundo siguiente. Es la regla 5 de la plantilla: la
    -- precondicion incluye el instante en que se lee.
    anotar( self, "RESCATE -> CAMINAR   ve " .. ( s.veEnemigo and "SI" or "NO" ) ..
        " · piso " .. ( s.enPiso and "SI" or "NO" ) ..
        " · hist " .. tostring( s.hist ) .. " ( umbral " .. tostring( s.umbral ) .. " en ESTA muestra )" ..
        " · canEscape " .. ( s.canEscape and "SI" or "NO" ) ..
        " · under " .. tostring( s.maybeUnder ) .. "/" .. tostring( s.underThresh ) ..
        " · quieto " .. string.format( "%.1f", CurTime() - ( myTbl.phantom_stuckSince or CurTime() ) ) .. " s" ..
        " · destino a " .. aDestino )

end

---------------------------------------------------------------------------
-- LA CORRECCION DEL DESTINO
---------------------------------------------------------------------------
-- ⚠ EL LUGAR IMPORTA Y NO ES INTERCAMBIABLE CON EL POLL. La corrutina de
-- prioridad corre, en este orden ( behaviouroverrides.lua:669-696 ):
--
--     myTbl.AdditionalThink( self, myTbl )        :676   <- ACA estamos
--     ...
--     myTbl.RunTask( self, "BehaveUpdatePriority" ) :694 <- ACA lee :3674
--
-- O sea que corriendo aca llegamos SIEMPRE antes que el bloque que declara la
-- llegada, en el mismo pase. Si esto colgara del poll de 4 Hz, entre que la base
-- pone el destino y nosotros lo miraramos podrian pasar hasta 0,25 s -- y en ese
-- hueco :3674 ya lo dio por cumplido. *Un arreglo que llega tarde a veces es un
-- arreglo intermitente, que es peor que ninguno porque no se puede medir.*
--
-- Por eso NO tiene gate de frecuencia. El costo por pase es una comparacion de
-- vectores; la busqueda cara solo corre cuando aparece un destino corto NUEVO,
-- o sea una vez por rescate.
local function corregirDestino( self, myTbl, data )
    local minDist = cvEscapeDist:GetInt()

    local destino = data.freedomGotoPosSimple

    if not destino then
        myTbl.phantom_escapeVisto = nil
        return

    end

    -- Ya decidimos sobre ESTE destino. Sin esta guarda volveriamos a corregir a
    -- medida que el bot se acerca caminando, y una llegada legitima -- el bot
    -- camino de verdad y entro en el radio -- quedaria cancelada para siempre.
    if myTbl.phantom_escapeVisto == destino then return end

    myTbl.phantom_escapeVisto = destino

    if minDist <= 0 then return end -- control: sin corregir

    local pos  = self:GetPos()
    local dist = pos:Distance2D( destino )

    if dist >= minDist then return end

    -- El destino nacio corto. Se cuenta SIEMPRE, se corrija o no: es el numero
    -- que dice cuantas veces la base habria dado por bueno un rescate nulo.
    local st = stuckStats( self )
    st.cortosVistos = st.cortosVistos + 1

    local mejor, total, pasaron, mejorDist = buscarEscape( self, minDist )

    if not mejor then
        -- NO SE INVENTA UN PUNTO. La base tiene un fallback que tira un vector
        -- al azar ( :3902-3907 ) y nosotros no lo copiamos: si no hay adonde ir,
        -- lo que corresponde es decirlo y dejar que la base haga lo suyo. Un
        -- destino inventado se veria igual que uno bueno en la bitacora.
        st.sinReemplazo = st.sinReemplazo + 1

        anotar( self, "DESTINO CORTO ( " .. math.Round( dist ) .. " u ) y SIN REEMPLAZO a mas de " ..
            minDist .. " u   ( " .. total .. " navareas miradas, " .. pasaron .. " pasaron el filtro )" )
        return

    end

    data.freedomGotoPosSimple = mejor
    myTbl.phantom_escapeVisto = mejor

    st.corregidos = st.corregidos + 1

    anotar( self, "DESTINO CORREGIDO   " .. math.Round( dist ) .. " u -> " .. math.Round( mejorDist ) .. " u" ..
        "   ( minimo " .. minDist .. ", umbral de LLEGO " .. B.ARRIVED_DIST .. " · " ..
        pasaron .. " de " .. total .. " navareas pasaron )" )

end

---------------------------------------------------------------------------
-- EL BAILOUT, ejecutado fuera del StartTask que lo marco
---------------------------------------------------------------------------
-- Hace lo mismo que la rama de teleport de la base ( :3875-3878 ) porque es lo
-- unico que se midio que funcione con el bot encajado: el `force` de la ronda 9
-- lo despego dos veces. No se reimplementa el teleport -- se llama al helper de
-- la base, que ademas reinicia la corrutina, frena el movimiento y limpia el
-- stuck del locomotor. Reescribir eso seria heredar sus bugs futuros sin
-- ninguna ventaja.
local function hacerBailout( self, myTbl )
    if not myTbl.phantom_bailoutPendiente then return end

    local porQue = myTbl.phantom_bailoutPorQue or "?"

    myTbl.phantom_bailoutPendiente = nil
    myTbl.phantom_bailoutPorQue    = nil

    local minDist = math.max( cvEscapeDist:GetInt(), B.ARRIVED_DIST )
    local destino, total, pasaron = buscarEscape( self, minDist )

    local st = stuckStats( self )

    if not destino then
        -- NO SE INVENTA UN PUNTO, por lo mismo que en corregirDestino: un
        -- destino inventado se veria igual que uno bueno, y este teletransporta
        -- de verdad.
        st.bailoutSinDonde = st.bailoutSinDonde + 1

        anotar( self, "BAILOUT ABORTADO: no hay ninguna navarea a mas de " .. minDist ..
            " u   ( " .. total .. " miradas, " .. pasaron .. " pasaron )" )
        return

    end

    local antes = self:GetPos()

    terminator_Extras.TeleportTermTo( self, destino )
    self:InvalidatePath( "phantasmagoria: bailout, quedo trabado" )

    -- El ancla se reinicia a mano: sin esto `quieto` seguiria contando desde
    -- antes del teleport y el gatillo volveria a dispararse en el pase siguiente,
    -- que es un bucle de teleports. El poll lo haria solo al detectar que se
    -- movio, pero "solo" es un tick despues y el gatillo mira cada tick.
    myTbl.phantom_stuckAnchor = self:GetPos()
    myTbl.phantom_stuckSince  = CurTime()

    st.bailouts = st.bailouts + 1

    -- El dato que importa es CUANTO SE MOVIO, no que se llamo: el teleport de la
    -- base movia 8 u y se anunciaba igual. Y el POR QUE viaja al lado, porque un
    -- gatillo de dos terminos no se puede leer desde el resultado.
    anotar( self, "BAILOUT   se movio " .. math.Round( self:GetPos():Distance( antes ) ) .. " u" ..
        "   ( " .. porQue .. " )" ..
        "   ve " .. ( myTbl.IsSeeEnemy and "SI" or "NO" ) ..
        "   <- la base NO habria podido: :3868 lo veta mientras te ve" )

end

function ENT:AdditionalThink( myTbl )
    myTbl = myTbl or self:GetTable()

    local data = myTbl.m_ActiveTasks and myTbl.m_ActiveTasks[ TASK ]

    if data then corregirDestino( self, myTbl, data ) end

    hacerBailout( self, myTbl )

    poll( self, myTbl )

    -- Se encadena aunque el stub de la base este vacio, por lo mismo que
    -- AdditionalFootstep: es gratis y evita que una version futura de la base
    -- que SI ponga algo ahi quede muerta por nuestro override.
    return myTbl.BaseClass.AdditionalThink( self, myTbl )

end

---------------------------------------------------------------------------
-- LA RAMA DEL TELEPORT, POR EL MOTIVO QUE LA BASE YA ESCRIBE
---------------------------------------------------------------------------
-- La base pasa un `reason` en cada StartTask y su propio comentario dice por que
-- ( taskoverride.lua:189: "This is an essential debugging tool, Use it." ).
-- El handler usa tres motivos, y los tres son unicos:
--
--   "reallystuck AFTER TELEPORT"   :3896   la rama del TELEPORT corrio
--   "reallystuck SUCCESS"          :3679   la caminata llego ( < 150 u )
--   "reallystuck partial FAIL"     :3697   la caminata se quedo sin los 10 s
--
-- Se anota ANTES de encadenar a proposito. StartTask se sale temprano si la
-- tarea ya estaba activa ( :167 ), asi que anotar despues perderia el evento --
-- y lo que interesa no es que movement_handler haya arrancado, sino que LA RAMA
-- haya corrido, que es lo que el motivo dice.
--
-- Y no se detecta por terminator_Extras.TeleportTermTo: eso es un global que
-- comparten todos los terminators del servidor, y envolverlo seria tocar a
-- terceros para medirnos a nosotros. Tampoco por SetPosNoTeleport, que tiene
-- otros seis call sites ( motionoverrides.lua:376, :1691, :2578, :2936, :3364 )
-- y contaria movimientos que no son rescates.
local MOTIVOS = {
    [ "reallystuck AFTER TELEPORT" ] = { campo = "teleport", texto = "RESCATE -> TELEPORT" },
    [ "reallystuck SUCCESS" ]        = { campo = "exitos",   texto = "la caminata LLEGO   ( < " .. B.ARRIVED_DIST .. " u )" },
    [ "reallystuck partial FAIL" ]   = { campo = "fallos",   texto = "la caminata SE VENCIO ( " .. B.WALK_SECS .. " s )" },
}

function ENT:StartTask( task, data, reason )
    -- El shim de argumentos de la base ( taskoverride.lua:160 ): si `data` es un
    -- string, ESE es el motivo. Copiarlo aca no es duplicar logica, es leer el
    -- mismo argumento que ella va a leer -- sin esto el motivo del handler, que
    -- viaja en la tercera posicion con un nil en el medio, se leeria igual, pero
    -- cualquier otro call site del proyecto no.
    local motivo = isstring( data ) and data or reason

    if isstring( motivo ) then
        local hit = MOTIVOS[ motivo ]

        if hit then
            local myTbl = self:GetTable()
            local st    = stuckStats( self )

            st[ hit.campo ] = st[ hit.campo ] + 1

            if hit.campo == "teleport" then st.rescates = st.rescates + 1 end

            local s = self:phantom_StuckState()

            -- ⚠ CUANTO SE MOVIO, Y ES LA COLUMNA QUE FALTABA EN LA RONDA 9.
            -- Salieron siete `la caminata LLEGO` con la MISMA posicion
            -- ( 1691.52 -780.39 148.46 ) y `quieto` subiendo 1,5 -> 59,7 s: la
            -- base se declaro exitosa siete veces sobre un bot que no se movio
            -- un centimetro. La bitacora lo mostraba y habia que cruzarlo a
            -- mano contra otra linea. Ahora lo dice el evento.
            --
            -- Para el TELEPORT la referencia es la muestra anterior del poll
            -- ( <= 0,25 s antes, y se imprime el intervalo: un numero de
            -- desplazamiento sin su ventana no se puede leer ). Para la
            -- caminata es el punto donde arranco ESA caminata.
            local movio, desde

            if hit.campo == "teleport" then
                desde = myTbl.phantom_stuckPrevPos
                movio = desde and ( math.Round( s.pos:Distance( desde ) ) .. " u en <= " ..
                    string.format( "%.2f", CurTime() - ( myTbl.phantom_stuckPrevTime or CurTime() ) ) .. " s" )

            else
                desde = myTbl.phantom_stuckWalkFrom
                movio = desde and ( math.Round( s.pos:Distance( desde ) ) .. " u en " ..
                    string.format( "%.1f", CurTime() - ( myTbl.phantom_stuckWalkAt or CurTime() ) ) .. " s de caminata" )

                if myTbl.phantom_stuckWalkTo then
                    movio = movio .. " · el destino estaba a " ..
                        math.Round( ( myTbl.phantom_stuckWalkFrom or s.pos ):Distance2D( myTbl.phantom_stuckWalkTo ) ) .. " u"

                end

                myTbl.phantom_stuckWalkTo = nil

                -- ⚠ ACA VIVIA EL GATILLO DEL BAILOUT Y SE FUE AL POLL. Contaba
                -- caminatas seguidas que vencian habiendose movido menos de 15 u,
                -- y con el bot encajado nunca disparo: las caminatas daban
                -- `SE MOVIO 93 u`, `69 u`, `64 u` -- el bot se sacude adentro de
                -- la jaula sin salir de ella -- y ademas entre una y otra pasaban
                -- hasta 81 s. Ver el comentario largo de la convar.

            end

            anotar( self, hit.texto .. "   ve " .. ( s.veEnemigo and "SI" or "NO" ) ..
                " · piso " .. ( s.enPiso and "SI" or "NO" ) ..
                " · SE MOVIO " .. ( movio or "?? ( sin muestra previa )" ) ..
                " · pos " .. tostring( s.pos ) )

        end
    end

    return self.BaseClass.StartTask( self, task, data, reason )

end

---------------------------------------------------------------------------
-- LOS SALTOS
---------------------------------------------------------------------------
-- La hipotesis del autor es que el encaje viene del salto. Contarlos no la
-- prueba, pero sin contarlos "se encaja saltando" no se puede pasar de
-- impresion a dato: lo que la convierte en medicion es que el reporte pueda
-- decir "el ultimo salto fue hace 2,3 s" al lado de "quieto hace 40 s".
--
-- PEDIDO NO ES OCURRIDO. ENT:Jump se sale sin avisar si no esta en el piso
-- ( motionoverrides.lua:2971 ), asi que se separan las dos cuentas. La guarda se
-- re-deriva aca -- es la misma condicion de esa linea, escrita igual -- y por
-- eso el reporte dice `pedidos` y `en el piso` en vez de un solo numero.
function ENT:Jump( height, fakeJump )
    local myTbl = self:GetTable()
    local st    = stuckStats( self )

    st.saltos = st.saltos + 1

    -- Sin IsValid( loco ): CLuaLocomotion no tiene ese metodo y el IsValid() de
    -- GMod devuelve false para todo objeto que no lo tenga. La base la llama
    -- directo y nosotros ya pagamos esa guarda una vez ( defecto 1 de lookLines ).
    local enPiso = myTbl.loco and myTbl.loco:IsOnGround() or false

    if fakeJump or enPiso then
        st.saltosEnPiso = st.saltosEnPiso + 1

        myTbl.phantom_lastJumpTime   = CurTime()
        myTbl.phantom_lastJumpHeight = height
        myTbl.phantom_lastJumpPos    = self:GetPos()
        myTbl.phantom_lastJumpLeap   = myTbl.phantom_jumpFromLeap == true

        if myTbl.phantom_jumpFromLeap then st.saltosLeap = st.saltosLeap + 1 end

        anotar( self, "SALTA   altura pedida " .. tostring( height ) ..
            " · tope JumpHeight " .. tostring( myTbl.JumpHeight ) ..
            ( myTbl.phantom_jumpFromLeap and " · LEAP ( JumpToPos )" or "" ) )

    end

    return myTbl.BaseClass.Jump( self, height, fakeJump )

end

-- Marca el origen para el Jump de adentro. JumpToPos llama a myTbl.Jump
-- ( motionoverrides.lua:3144 ), que resuelve a NUESTRO override -- o sea que sin
-- esta marca los leaps se contarian dos veces o ninguna, segun donde se contara.
--
-- Con Term_Leaps nil este camino esta muerto ( ver el encabezado ), asi que
-- `saltos leap` tiene que dar 0. Es el control de que el encabezado no miente.
function ENT:JumpToPos( pos, height )
    local myTbl = self:GetTable()

    myTbl.phantom_jumpFromLeap = true

    local ok = myTbl.BaseClass.JumpToPos( self, pos, height )

    myTbl.phantom_jumpFromLeap = nil

    return ok

end

---------------------------------------------------------------------------
-- EL INSTRUMENTO
---------------------------------------------------------------------------
local function lineas( ghost, say )
    local s = ghost:phantom_StuckState()
    local st = stuckStats( ghost )

    say( "#" .. ghost:EntIndex() .. "/c" .. ghost:GetCreationID() ..
        "   " .. ( ghost.phantom_Hunting and "CAZANDO" or "en calma" ) ..
        "   a " .. math.Round( ghost:GetCurrentSpeed() ) .. " u/s" ..
        "   pos " .. tostring( s.pos ) )

    -- LAS CUATRO SALIDAS, SIEMPRE, aunque esten todas abiertas. Una linea que
    -- solo aparece cuando hay problema no deja distinguir "no hay" de "no se
    -- midio", y tres de estas cuatro las puede haber movido un tercero.
    say( "    el rescate   " .. string.upper( s.dataPorQue ) )
    say( "    las salidas  ReallyStuckDisable " .. tostring( s.disable ) ..
        " · MoveSpeed " .. tostring( s.moveSpeed ) ..
        " · termhunter_doextremeunstucking " .. tostring( s.teleportConv ) )

    -- EL VETO, primero, porque es el candidato (a) y el unico termino que separa
    -- las tres hipotesis. Sin esta linea las tres se ven iguales desde afuera:
    -- en las tres el bot se queda quieto y no lo rescata nadie.
    say( "    ve al enemigo " .. ( s.veEnemigo and "SI  <- VETA el teleport ( :3868 )" or "NO" ) ..
        "   enemigo " .. ( IsValid( s.enemigo ) and tostring( s.enemigo ) or "ninguno" ) )

    say( "    en el piso    " .. ( s.enPiso and "SI" or "NO  <- sin esto noNav es false ( :3714 )" ) ..
        "   saltando " .. ( s.saltando and "SI" or "NO" ) ..
        " · leap " .. ( s.leapeando and "SI" or "NO" ) ..
        " · cayendo " .. ( s.cayendo and "SI" or "NO" ) )

    local quieto = CurTime() - ( ghost.phantom_stuckSince or CurTime() )

    say( "    quieto desde  " .. string.format( "%.1f", quieto ) .. " s" ..
        "   ( NUESTRO, no de la base: desde que salio de un radio de " .. B.STUCK_RADIUS .. " u )" )

    if not s.data then
        say( "    ^ sin la tarea activa no hay nada mas que leer: el resto vive en su tabla `data`." )
        return

    end

    -- ⚠ ESTA LINEA DECIA `hist N / umbral` Y LA RONDA 9 LA REFUTO. El numerador
    -- lo escribe la BASE en su pase y el denominador lo calculaba YO en el mio,
    -- asi que con `noNav` oscilando el umbral saltaba entre 11 y 81 de una
    -- muestra a la otra ( `86/11`, `92/81`, `92/11` en muestras consecutivas ).
    -- *Una fraccion cuyas dos mitades vienen de dos relojes distintos no es una
    -- fraccion.* Ahora el salto REAL se mide y el umbral se imprime al lado
    -- diciendo que es el de esta muestra.
    local salto = ghost.phantom_stuckHistJump
    local saltoAt = ghost.phantom_stuckHistJumpAt

    say( "    hist          " .. s.hist ..
        ( salto and ( "   ultimo salto MEDIDO " .. ( salto > 0 and "+" or "" ) .. salto ..
            " hace " .. string.format( "%.1f", CurTime() - ( saltoAt or CurTime() ) ) .. " s" ) or "   ( todavia sin dos muestras )" ) )

    -- ⚠ ACA HABIA UNA SEGUNDA PREDICCION Y LA RONDA 10 TAMBIEN LA REFUTO, EN LA
    -- MISMA SALIDA EN LA QUE APARECIO. Imprimia
    --
    --     esperado  +1 por pase de la base, menos 2 del trimming = -1 neto
    --               -> faltan ~81 s para que PUEDA evaluar
    --
    -- Un neto NEGATIVO, que significaria que el array nunca crece. Dos errores
    -- mios encima: el trimming de :3774-3777 corre SOLO dentro del
    -- `if #historicPositions > size`, asi que por debajo del umbral no resta
    -- nada; y arriba del umbral tampoco resta 2 en regimen, porque saca 2 y al
    -- pase siguiente inserta 1, de modo que el array OSCILA en vez de crecer.
    -- No hay un "neto" que sea un numero.
    --
    -- Y el `faltan ~N s` decia 81 mientras el bot evaluaba a los pocos segundos,
    -- porque ese calculo usa MI `noNav` y la base usaba el de SU pase: la misma
    -- fraccion de dos relojes que la ronda 9 ya habia refutado, escrita otra vez
    -- en la linea de al lado.
    --
    -- *Predecir un numero que se puede medir es regalar un criterio que nunca se
    -- cumple.* Se borro la prediccion; queda el umbral, etiquetado como el de
    -- esta muestra, y la medicion de arriba.
    say( "    umbral        " .. s.umbral .. " EN ESTA MUESTRA" ..
        "   ( 11 con noNav · 81 sin el, y la base usa el de SU pase, no el de esta linea )" ..
        ( s.evalua and "   -> YA EVALUA" or "" ) )

    say( "    noNav         " .. ( s.noNav and "SI" or "NO" ) ..
        "   navarea " .. ( s.nav and ( "#" .. s.nav:GetID() .. " con " .. s.navVecin .. " vecinas" ) or "NINGUNA a " .. B.NAV_RADIUS .. " u" ) ..
        " · a " .. B.NAV_FAR .. " u " .. ( s.navLejos and ( "#" .. s.navLejos:GetID() ) or "NINGUNA" ) )

    -- Recalculado, y se dice en la misma linea. Los arrays son los de la base;
    -- la cuenta es nuestra porque `stuck` y `sortaStuck` son locales del pase.
    say( "    stuck " .. ( s.stuck and "SI " or "NO " ) ..
        " · sortaStuck " .. ( s.sortaStuck and "SI " or "NO " ) ..
        "  ( RECALCULADO sobre los arrays de la base, no sobre posiciones nuestras )" )

    say( "    displacement  maybeUnderCount " .. s.maybeUnder .. " / " .. s.underThresh ..
        "  -> underDisplacement " .. ( s.under and "SI" or "NO" ) ..
        "   ( mide TERRENO, no props: shared.lua:1986 )" )

    say( "    override      overrideVeryStuck " .. tostring( s.override ) ..
        " · isUnstucking " .. tostring( s.unstuck ) )

    say( "    escape        canGotoEscape " .. ( s.canEscape and "SI" or "NO" ) ..
        "   nextUnstuckGotoEscape " .. string.format( "%+.1f", s.escapeIn ) .. " s" ..
        " · extremeUnstuckingUntil " .. string.format( "%+.1f", s.walkIn ) .. " s" ..
        " · proximo pase " .. string.format( "%+.1f", s.cacheIn ) .. " s" )

    say( "    caminando a   " .. ( s.caminandoA and ( tostring( s.caminandoA ) ..
        "  a " .. math.Round( s.pos:Distance2D( s.caminandoA ) ) .. " u ( llega con < " .. B.ARRIVED_DIST .. " )" ) or "ninguna ( freedomGotoPosSimple nil )" ) )

    -- La re-derivacion cuesta un FindInBox de +-3000 u, y por eso vive aca y no
    -- en el muestreador de `watch`: un instrumento que lagea el servidor cambia
    -- lo que mide. El comando se tipea a mano, una vez.
    local hay, total = freedomPosExists( ghost )
    local rama, porQue = predecirRama( s, hay )

    say( "    freedomPos    " .. ( hay and "EXISTE" or "NO EXISTE" ) ..
        "   ( " .. total .. " navareas en la caja de +-" .. B.FREEDOM_BOX .. " u )" ..
        "   RE-DERIVADO de :3836 -- prediccion, no medicion" )

    say( "    PREDICCION    si el rescate arrancara AHORA iria por " .. rama )
    say( "                  " .. porQue )

    local jt = ghost.phantom_lastJumpTime

    say( "    saltos        " .. st.saltos .. " pedidos · " .. st.saltosEnPiso .. " ocurrieron · " ..
        st.saltosLeap .. " leap ( tiene que ser 0: Term_Leaps es " .. tostring( ghost.Term_Leaps ) .. " )" )

    say( "    el ultimo     " .. ( jt and ( "hace " .. string.format( "%.1f", CurTime() - jt ) .. " s" ..
        " · altura pedida " .. tostring( ghost.phantom_lastJumpHeight ) ..
        " · tope " .. tostring( ghost.JumpHeight ) ..
        " · a " .. math.Round( s.pos:Distance( ghost.phantom_lastJumpPos or s.pos ) ) .. " u de aca" ) or "no salto nunca" ) )

    say( "    rescates      " .. st.rescates ..
        "   ( TELEPORT " .. st.teleport .. " · CAMINAR " .. st.caminar ..
        " · llego " .. st.exitos .. " · se vencio " .. st.fallos .. " )" )

    -- EL ARREGLO, CON LOS TRES NUMEROS SEPARADOS. `cortos 0` significa que la
    -- base eligio bien y la correccion no hizo falta; `corregidos 0` con
    -- `cortos > 0` significa que hizo falta y no pudo. Un solo contador
    -- confundiria las dos cosas, que es como se lee un arreglo que no corrio
    -- igual que uno que no hacia falta.
    say( "    el arreglo    escapedist " .. cvEscapeDist:GetInt() ..
        ( cvEscapeDist:GetInt() <= 0 and "  ( 0 = SIN CORREGIR, el comportamiento de la ronda 9 )" or
            ( "  ( minimo; el umbral de LLEGO de la base es " .. B.ARRIVED_DIST .. " )" ) ) )

    say( "                  destinos cortos vistos " .. st.cortosVistos ..
        " · corregidos " .. st.corregidos ..
        " · sin reemplazo " .. st.sinReemplazo )

    -- EL BAILOUT, con su contador de seguidas EN VIVO. El contador es la mitad
    -- que dice si el gatillo esta cerca; sin el, un `bailouts 0` no distingue
    -- "nunca hizo falta" de "hizo falta y falta una caminata mas".
    -- LOS DOS TERMINOS DEL GATILLO, SIEMPRE, aunque uno solo este cerca. Con el
    -- gatillo viejo el reporte decia `llevamos 0` y eso no distinguia "nunca
    -- hizo falta" de "el contador se resetea con cada sacudida" -- que es lo que
    -- estaba pasando y tardo una ronda entera en verse.
    local deseada = ghost.loco and ghost.loco:GetDesiredSpeed() or 0

    say( "    el bailout    stuckbailoutsecs " .. cvBailout:GetInt() .. " s" ..
        ( cvBailout:GetInt() <= 0 and "  ( 0 = NUNCA, el comportamiento de la ronda 10 )" or
            "  ( segundos quieto QUERIENDO moverse )" ) )

    say( "                  quieto " .. string.format( "%.1f", quieto ) .. " s" ..
        " · deseada " .. math.Round( deseada ) .. " u/s" ..
        " · real " .. math.Round( ghost:GetCurrentSpeed() ) .. " u/s" ..
        "   -> " .. ( ( quieto >= cvBailout:GetInt() and cvBailout:GetInt() > 0 ) and "el tiempo YA alcanza" or "el tiempo todavia no" ) ..
        " · " .. ( ( deseada > BAILOUT_SPEED and ghost:GetCurrentSpeed() < BAILOUT_SPEED ) and "QUIERE moverse y no puede" or "no quiere moverse ( o si se mueve )" ) )

    say( "                  disparados " .. st.bailouts ..
        " · abortados por no haber adonde " .. st.bailoutSinDonde )

end

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_stuck", function( ply, _, args )
    local say = PHANTASMAGORIA.MakeSay( ply )
    local sub = args and args[ 1 ]

    ---------------------------------------------------------------------------
    if sub == "reset" then
        local n = PHANTASMAGORIA.EachGhost( function( ghost )
            ghost.phantom_stuckStats      = nil
            ghost.phantom_lastJumpTime    = nil
            ghost.phantom_stuckLastEscape = nil

        end )

        PHANTASMAGORIA.StuckLog = {}

        say( "[Phantasmagoria] contadores de encaje reseteados en " .. n .. " fantasma(s), y bitacora vaciada." )
        return

    end

    ---------------------------------------------------------------------------
    -- EL BOTON: provocar la precondicion sin encajar al bot
    ---------------------------------------------------------------------------
    -- myTbl.overrideVeryStuck ( leido en :3747, usado en el if de :3816 ) fuerza
    -- la rama de rescate SIN esperar los 80 segundos. O sea que el boton para
    -- provocar la precondicion ya existe en la base y es un campo.
    --
    -- ⚠ ESTO NO ES EL ENCAJE, Y CONFUNDIRLO SERIA EL ERROR MAS CARO DE ESTA
    -- RONDA. Forzar la bandera prueba POR QUE RAMA sale el rescate. NO prueba
    -- que un bot encajado llegue a esa bandera -- para eso hay que encajarlo con
    -- el physgun, y lo que contesta ahi es `en el piso` y la cuenta de `hist`.
    -- Son dos mediciones y miden cosas distintas.
    --
    -- ⚠ Y NO ES GRATIS: la primera linea de la rama es self:ReallyAnger( 60 )
    -- ( :3817 ). El bot queda REALMENTE ENOJADO un minuto, y eso mueve el bloque
    -- de velocidad ( canDoRun consulta IsReallyAngry, motionoverrides.lua:754 y
    -- :784 ). Se avisa porque una corrida de velocidad hecha justo despues de
    -- esto mediria otra cosa.
    if sub == "force" then
        ---------------------------------------------------------------------------
        -- ⚠ EL BOTON AHORA SE NIEGA, Y ESO SALIO DE LA RONDA 9
        ---------------------------------------------------------------------------
        -- TRES de las nueve filas se corrieron FUERA de su precondicion y se
        -- marcaron verdes igual. La 02 pedia `canGotoEscape SI` y salio NO; la
        -- 04 -- la fila estrella del A/B -- pedia `ve al enemigo SI` y salio NO
        -- las dos veces. El boton IMPRIMIA los dos valores en la primera linea
        -- de su salida y aun asi la corrida siguio de largo.
        --
        -- *Imprimir la precondicion al lado del veredicto no alcanza: hay que
        -- negarse.* Es exactamente lo que la ronda 6 dejo escrito con testdoor,
        -- que gritaba ESCUCHA AHORA sobre una apertura que el veto se iba a
        -- comer -- y ahi tambien el dato estaba impreso al lado.
        --
        -- El argumento declara QUE FILA estas corriendo, y el comando comprueba
        -- que el mundo este de ese lado antes de gastar el disparo. Sin
        -- argumento se comporta como en la r9, porque para explorar sirve.
        local ESPERA = {
            [ "primero" ] = {
                fila  = "la del candidato (c): el primer disparo NO teletransporta",
                ok    = function( s ) return s.canEscape end,
                pide  = "canGotoEscape SI",
                pista = "Ya venis de un disparo anterior. Espera a que venza el reloj de " .. B.ESCAPE_SECS .. " s, o corre la fila 'segundo'.",
            },
            [ "segundo" ] = {
                fila  = "la del control POSITIVO: sin verte, TIENE que teletransportar",
                ok    = function( s ) return not s.canEscape and not s.veEnemigo end,
                pide  = "canGotoEscape NO y ve al enemigo NO",
                pista = "Si canGotoEscape da SI, corre 'primero' y volve en " .. B.AFTER_WALK .. "-" .. B.ESCAPE_SECS .. " s. Si te ve, apaga el hunt o salite de su linea de vision.",
            },
            [ "veto" ] = {
                fila  = "la del candidato (a): VIENDOTE no tiene que teletransportar",
                ok    = function( s ) return not s.canEscape and s.veEnemigo end,
                pide  = "canGotoEscape NO y ve al enemigo SI",
                pista = "`hunt 1` NO alcanza: IsSeeEnemy es lo que consulta :3868, y pide linea de vista. Parate delante del fantasma.",
            },
        }

        local quiere = sub and args[ 2 ] and ESPERA[ string.lower( args[ 2 ] ) ]

        if args[ 2 ] and not quiere then
            say( "[Phantasmagoria] uso: phantasmagoria_ghost_stuck force [primero|segundo|veto]" )
            say( "    Sin argumento dispara igual que antes. Con argumento, se NIEGA si la precondicion no esta." )

            for _, key in ipairs( { "primero", "segundo", "veto" } ) do
                say( "    " .. key .. string.rep( " ", 9 - #key ) .. ESPERA[ key ].pide .. "   -- " .. ESPERA[ key ].fila )

            end

            return

        end

        local n = PHANTASMAGORIA.EachGhost( function( ghost )
            local s = ghost:phantom_StuckState()

            if not s.data then
                say( "#" .. ghost:EntIndex() .. "  NO SE PUEDE: " .. s.dataPorQue )
                say( "    Sin la tarea activa el campo no lo lee nadie. Eso YA es el resultado del check." )
                return

            end

            if quiere and not quiere.ok( s ) then
                say( "#" .. ghost:EntIndex() .. "/c" .. ghost:GetCreationID() .. "  SIN DISPARAR: la precondicion NO se cumple." )
                say( "    la fila pide   " .. quiere.pide )
                say( "    ahora mismo    canGotoEscape " .. ( s.canEscape and "SI" or "NO" ) ..
                    " · ve al enemigo " .. ( s.veEnemigo and "SI" or "NO" ) ..
                    "   ( escape " .. string.format( "%+.1f", s.escapeIn ) .. " s · walk " .. string.format( "%+.1f", s.walkIn ) .. " s )" )
                say( "    " .. quiere.pista )
                say( "    ESTA FILA ES 'Sin correr'. No se gasto el disparo, asi que el estado no cambio." )
                return

            end

            local hay = freedomPosExists( ghost )
            local rama, porQue = predecirRama( s, hay )

            say( "#" .. ghost:EntIndex() .. "/c" .. ghost:GetCreationID() .. "  DISPARO" )
            say( "    ve al enemigo " .. ( s.veEnemigo and "SI" or "NO" ) ..
                " · hunt " .. ( ghost.phantom_Hunting and "SI" or "NO" ) ..
                "   <- ESTE es el lado del A/B en el que estas" )
            say( "    canGotoEscape " .. ( s.canEscape and "SI" or "NO" ) ..
                "   escape " .. string.format( "%+.1f", s.escapeIn ) .. " s" ..
                " · walk " .. string.format( "%+.1f", s.walkIn ) .. " s" )
            say( "    PREDICCION    " .. rama .. "   ( " .. porQue .. " )" )

            if s.canEscape then
                -- LA TRAMPA (c), DICHA POR EL INSTRUMENTO Y NO POR LA PLANILLA.
                -- Con los dos relojes vencidos, "extremeStuck or not canGotoEscape"
                -- es false salvo que underDisplacement o la falta de freedomPos
                -- lo salven -- o sea que el primer disparo NUNCA teletransporta,
                -- ni con hunt 0. Un check que se corra una sola vez leeria eso
                -- como "(a) es falsa", que es la conclusion inversa.
                say( "    ⚠ PRIMER DISPARO: la rama del teleport esta cerrada por (c), pase lo que pase con IsSeeEnemy." )
                say( "      Volve a tirar entre " .. B.AFTER_WALK .. " s y " .. B.ESCAPE_SECS .. " s. EL QUE MIDE ES EL SEGUNDO." )

            end

            say( "    el proximo pase del handler es en " .. string.format( "%.1f", math.max( s.cacheIn, 0 ) ) .. " s" ..
                "   ( ReallyAnger 60 s de regalo: no medir velocidad justo despues )" )

            ghost.overrideVeryStuck = true

        end )

        if n == 0 then
            say( "[Phantasmagoria] no hay ningun fantasma vivo." )
            return

        end

        -- EL MUESTREADOR, porque la ventana dura menos que el tramite de
        -- medirla. Es la regla 5 de la plantilla: si el estado que medis dura
        -- menos que tipear el comando, el check mide el tramite y devuelve el
        -- valor de reposo, que se lee como un resultado.
        local antes = {}

        PHANTASMAGORIA.EachGhost( function( ghost )
            local st = stuckStats( ghost )
            antes[ ghost:GetCreationID() ] = { r = st.rescates, t = st.teleport, c = st.caminar, pos = ghost:GetPos() }

        end )

        local quien = ply

        timer.Create( "phantasmagoria_stuck_force", 0.25, 48, function()
            local fin = PHANTASMAGORIA.MakeSay( quien )

            PHANTASMAGORIA.EachGhost( function( ghost )
                local st  = stuckStats( ghost )
                local ant = antes[ ghost:GetCreationID() ]
                if not ant then return end
                if st.rescates <= ant.r then return end

                antes[ ghost:GetCreationID() ] = nil

                local salioPor = st.teleport > ant.t and "TELEPORT" or ( st.caminar > ant.c and "CAMINAR" or "??" )

                fin( "#" .. ghost:EntIndex() .. "/c" .. ghost:GetCreationID() ..
                    "  SALIO POR " .. salioPor ..
                    "   se movio " .. math.Round( ghost:GetPos():Distance( ant.pos ) ) .. " u" ..
                    "   ve al enemigo " .. ( ghost.IsSeeEnemy and "SI" or "NO" ) )

            end )

            if table.IsEmpty( antes ) then timer.Remove( "phantasmagoria_stuck_force" ) end

        end )

        say( "    ( muestreando 12 s: el resultado sale solo cuando la rama corra )" )
        return

    end

    ---------------------------------------------------------------------------
    -- EL OTRO BOTON: mirar el encaje DE VERDAD, mientras dura
    ---------------------------------------------------------------------------
    -- La medicion que el `force` no puede dar: encajar al bot con el physgun y
    -- props contra un techo, y ver si IsOnGround da true o false y si `hist`
    -- llega a su umbral alguna vez. Eso tarda ~81 s en el aire, o sea mas de lo
    -- que nadie va a mirar la consola tipeando.
    --
    -- Imprime por transicion y no por muestra -- 90 lineas iguales tapan el
    -- cambio, que es lo unico informativo -- con un latido cada 10 s para que un
    -- tramo sin cambios se distinga de un muestreador muerto.
    if sub == "watch" then
        local segs = math.Clamp( tonumber( args[ 2 ] or "" ) or 90, 5, 240 )

        timer.Remove( "phantasmagoria_stuck_watch" )

        local quien = ply
        local prev, n = {}, 0

        say( "[Phantasmagoria] MIRANDO el encaje durante " .. segs .. " s, una muestra por segundo." )
        say( "    Encajar al fantasma AHORA con el physgun. Solo imprime cuando algo CAMBIA, y late cada 10 s." )

        timer.Create( "phantasmagoria_stuck_watch", 1, segs, function()
            n = n + 1
            local fin = PHANTASMAGORIA.MakeSay( quien )
            local latido = ( n % 10 ) == 0

            PHANTASMAGORIA.EachGhost( function( ghost )
                local s   = ghost:phantom_StuckState()
                local key = ghost:GetCreationID()
                local ant = prev[ key ]

                -- La firma es lo que decide si hubo cambio. Va SIN la posicion y
                -- sin los relojes a proposito: los dos cambian todo el tiempo y
                -- harian que cada muestra pareciera una transicion.
                local firma = tostring( s.enPiso ) .. tostring( s.veEnemigo ) .. tostring( s.evalua ) ..
                    tostring( s.stuck ) .. tostring( s.sortaStuck ) .. tostring( s.canEscape ) ..
                    tostring( s.noNav ) .. tostring( s.data ~= nil )

                if not latido and ant == firma then return end

                prev[ key ] = firma

                local quieto = CurTime() - ( ghost.phantom_stuckSince or CurTime() )

                -- `hist` va SOLO, con el umbral de esta muestra entre parentesis
                -- y marcado. En la ronda 9 iban pegados como fraccion y el
                -- denominador saltaba entre 11 y 81 entre muestras consecutivas,
                -- porque lo calculaba yo con MI `noNav` y el numerador venia del
                -- pase de la base. Se leia como si el array se hubiera
                -- desbordado. `nav` es la columna que explica el salto.
                fin( string.format( "%3d s  #%s/c%s  piso %s · ve %s · hist %s (umb %s) · nav %s · stuck %s · sorta %s · esc %s · quieto %.0f s%s",
                    n, ghost:EntIndex(), key,
                    s.enPiso and "SI" or "NO",
                    s.veEnemigo and "SI" or "NO",
                    tostring( s.hist or "-" ), tostring( s.umbral ),
                    s.noNav and "NO" or "SI",
                    s.stuck and "SI" or "NO",
                    s.sortaStuck and "SI" or "NO",
                    s.canEscape and "SI" or "NO",
                    quieto,
                    latido and "  ( latido )" or "  <- CAMBIO" ) )

            end )

            if n >= segs then
                fin( "[Phantasmagoria] fin del muestreo: " .. n .. " muestras. El resumen completo con phantasmagoria_ghost_stuck." )

            end
        end )

        return

    end

    ---------------------------------------------------------------------------
    -- El reporte
    ---------------------------------------------------------------------------
    local cv = GetConVar( "termhunter_doextremeunstucking" )

    say( "[Phantasmagoria] termhunter_doextremeunstucking " .. ( cv and cv:GetInt() or "?? ( la convar de la base no existe )" ) ..
        "   ( 0 = el teleport de rescate esta APAGADO en este servidor )" )

    local vivos = PHANTASMAGORIA.EachGhost( function( ghost )
        say( "" )
        lineas( ghost, say )

    end )

    if vivos == 0 then
        say( "[Phantasmagoria] no hay ningun fantasma vivo." )
        return

    end

    local log = PHANTASMAGORIA.StuckLog

    say( "" )
    say( "bitacora ( " .. #log .. " eventos, no una linea por muestra ):" )

    if #log == 0 then
        -- UN VACIO QUE SIGNIFICA ALGO. Sin saltos ni rescates tiene que estar
        -- vacia; con el fantasma saltando y esto vacio, el que fallo es el
        -- override de Jump y no el bot.
        say( "    ( vacia: o no salto ni se rescato nadie todavia, o los overrides no se estan llamando )" )

    end

    for _, linea in ipairs( log ) do
        say( "    " .. linea )

    end

end, "Reporte del rescate de atascos de la base: si esta corriendo, en que estado esta el bot y por que rama saldria. " ..
    "'reset' limpia · 'force [primero|segundo|veto]' fuerza la rama con overrideVeryStuck y SE NIEGA si la precondicion de esa fila no esta · " ..
    "'watch [seg]' muestrea mientras encajas al bot con el physgun." )

---------------------------------------------------------------------------
-- GUARDA: la clave de MyClassTask pisada
---------------------------------------------------------------------------
-- server.lua ya avisa que si dos archivos declaran la misma clave de
-- MyClassTask el segundo pisa al primero y el sintoma es un bloque entero que no
-- corre, sin un solo error. Este archivo NO usa MyClassTask -- usa
-- AdditionalThink -- justamente por eso, y la guarda comprueba que sigue siendo
-- cierto en vez de confiar en el comentario.
--
-- Es la misma forma que la guarda del campo pisado del final de server.lua: *un
-- default que coincide con lo esperado convierte un campo roto en un check
-- verde*, y eso no lo agarra una corrida, lo agarra una guarda o nadie.
if not isfunction( ENT.MyClassTask and ENT.MyClassTask.Think ) then
    ErrorNoHalt( "[Phantasmagoria] server_stuck.lua esperaba encontrar ENT.MyClassTask.Think ya declarado " ..
        "por server_doors.lua y no esta. O cambio el orden de los includes, o el bloque de puertas " ..
        "dejo de colgar de ahi -- en los dos casos la guarda de este archivo dejo de cubrir nada.\n" )

end
