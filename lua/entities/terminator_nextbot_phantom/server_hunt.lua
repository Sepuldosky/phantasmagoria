--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom / EL HUNT DIRECTO

    PEDIDO DEL AUTOR, literal, al abrir la investigacion:

      *"la idea del hunt es que no tome en cuenta ninguna logica asi, que si ve
      al jugador busque la posicion mas directa para atacarlo"*

    y el alcance que puso el mismo, tambien literal:

      *"el NPC deberia ser capaz de perseguirte, perderte y seguir buscando en
      hunt"*

    O sea, en una linea: **perseguir, perder, buscar SI. Observar, acechar,
    campear, flanquear de lejos NO.**

    ---------------------------------------------------------------------------
    LA DECISION DE ARQUITECTURA, Y ES LA QUE ORDENA TODO EL ARCHIVO
    ---------------------------------------------------------------------------

    NO se usa `DoCustomTasks` para sacar tareas del registro, que es la forma de
    HIM ( him/.../server.lua:997 reasigna `self.TaskList` entero con cinco
    tareas ). Se conserva TODO registrado y se cierra **por estado**. Tres
    motivos, en orden de peso:

      ( 1 ) `movement_watch` y `movement_stalkenemy` TIENEN UNA SEGUNDA VIDA y el
            diseno ya se la asigno. Diseno 10, tabla de reubicacion:
            *"Te observa de lejos, se aleja si lo miras"* -> el estado
            IDLE/ROAMING, con `movement_watch` y `enemyBearingToMeAbs`. El autor
            llego a lo mismo solo, mirando el log:

              *"movement_stalkenemy y movement_watch puede funcionar para asustar
              al jugador en un evento a lo lejos ( En phasmophobia hay un evento
              donde se te quedan mirando fijo como a 5-10 metros )"*

            Sacarlas del registro las mata en LOS DOS estados.

      ( 2 ) `TaskList` se arma UNA SOLA VEZ al spawnear ( taskoverride.lua:390 ),
            asi que no expresa "lista de hunt" contra "lista de calma".

      ( 3 ) Sacar una tarea del registro y dejarle un `StartTask` apuntando NO da
            error: da un ZOMBI. La tarea entra igual en `m_ActiveTasks`
            -- `IsTaskActive` dice que si y el debug la imprime -- pero `RunTask`
            la saltea porque no encuentra sus callbacks ( taskoverride.lua:39-40 ).
            El bot se queda parado, sin tarea de movimiento, EN SILENCIO, hasta
            que lo rescate `reallystuck_handler`.
            Por eso las puertas se cierran EN LA CONDICION y ademas hay un perro
            guardian que GRITA ( seccion 8 ).

    ---------------------------------------------------------------------------
    LO QUE EL AUTOR MIDIO EN JUEGO EL 2026-08-20, Y NO SE VUELVE A CORRER
    ---------------------------------------------------------------------------
    Dos corridas con `term_debugtasks 1` en `ue_macy_state_psych_center_night`.

      · A 39 m, hunt recien prendido, lo primero que hace la base es
        `movement_watch` -> `movement_stalkenemy` x50. **El bucle de acecho NO
        TIENE TOPE mientras te vea**: `stalksSinceLastSeen` se resetea a 0 cada
        vez que te ve ( shared.lua:6618 ) y el reinicio pide
        `stalksSinceLastSeen < ratio * 5` ( :6972 ), o sea `0 < 5`, para siempre.
        *"Por stalkearme le dio la vuelta al asilo, ahora esta a 80 metros"*.

      · A los 80 m se PERDIO SOLO: `phantasmagoria_ghost_sightdist` vale 3000 u
        ( ~75 m ) y la orbita del stalk no lo consulta por ningun lado.

      · Prender el hunt NO interrumpe la tarea en curso: el flag prende, el
        enemigo pasa a ser valido, y el bot sigue en `movement_biginertia`
        caminando a un punto al azar a 5000-6000 u ( shared.lua:8192 ).

      · El fantasma NO PEGA, y son DOS interruptores y no uno:
        `phantasmagoria_ghost_pickup 0` ( no levanta armas ) y
        `ENT.TERM_FISTS = false`, que es el gate del punetazo de la base
        ( shared.lua:7686, `if fistiCuffs and self.TERM_FISTS then` ).

      · El juego imprimio solo, con stack, el diagnostico del arma:
        `movement_perch  i ran out of places, and i have a real weapon`
        sobre un fantasma DESARMADO. Ver la seccion 2.

    ---------------------------------------------------------------------------
    LO QUE ESTE ARCHIVO **NO** HACE, Y ES A PROPOSITO
    ---------------------------------------------------------------------------
      · **La cordura** ( Diseno 19.8 ). El hunt lo sigue disparando
        `phantasmagoria_hunt`, que es manual y provisorio. Cuando la cordura
        exista va a llamar a `phantom_SetHunting`, que es la puerta unica, y
        todo esto la sigue sin tocar una linea.
      · **El evento de mirar fijo** ( Diseno 10 ). Este bloque solo tiene que NO
        romperlo: `watch` y `stalkenemy` quedan registradas y sanas.
      · **El tope de la orbita del stalk contra `sightdist`**. Es una frontera
        abierta declarada: el dia que el stalk viva en el estado IDLE, ese tope
        tiene que existir. No es codigo de este bloque.
      · **Los 30 tipos y sus rasgos.** `ability.onCatch` queda ENGANCHADO, no
        poblado ( seccion 7 ).
      · **Parchear la base.** Es de un tercero. Todo lo de aca son overrides.
---------------------------------------------------------------------------]]

---------------------------------------------------------------------------
-- LAS PERILLAS, Y POR QUE SON SEIS Y NO UNA
---------------------------------------------------------------------------
-- Catalogo nº 28: dos condiciones encendidas a la vez es un criterio que se
-- cumple a medias y se lee como cumplido. Este bloque toca CINCO mecanismos
-- distintos -- el arma, el miedo, los props, el pozo, la escalera -- y si
-- estuvieran los cinco detras de una sola perilla, apagarla no diria cual de los
-- cinco produjo el cambio. Una por mecanismo es lo que hace que la planilla
-- pueda tener una fila por mecanismo.
--
-- Todas arrancan en 1 ( el comportamiento nuevo ) y el 0 devuelve el de la base
-- EXACTO, encadenando. El 0 es el control, no un modo degradado.

local cvHuntDirect = CreateConVar( "phantasmagoria_ghost_huntdirect", "1", FCVAR_ARCHIVE,
    "EN HUNT el fantasma va derecho: la escalera de la base se reduce a perseguir / buscar, y las " ..
    "tareas tacticas ( watch, stalk, camp, perch, backthehellup, los dos wander ) se desvian. " ..
    "0 = CONTROL: la escalera de la base entera, que es lo que el autor midio el 2026-08-20 " ..
    "( x50 de movement_stalkenemy a 39 m ). Las tareas NUNCA se sacan del registro: fuera del hunt " ..
    "siguen vivas para el evento de mirar fijo de Diseno 10.", 0, 1 )

local cvTrueRange = CreateConVar( "phantasmagoria_ghost_truerange", "1", FCVAR_ARCHIVE,
    "El fantasma dice la verdad sobre su alcance. La base devuelve math.huge sin arma " ..
    "( weapons.lua:1935, 'our eyes have infinite range' ) y ademas IsMeleeWeapon devuelve false, " ..
    "asi que un bot que solo mata tocandote es tratado como francotirador: campIsGood, camp y perch " ..
    "se abren en toda la base. 0 = CONTROL, vuelve a mentir.", 0, 1 )

local cvFearless = CreateConVar( "phantasmagoria_ghost_fearless", "1", FCVAR_ARCHIVE,
    "El fantasma no le tiene miedo a nadie: EnemyIsLethalInMelee ( shared.lua:2740 ) queda en false. " ..
    "Esa funcion prende tooDangerousToApproach, el creeping agachado y movement_backthehellup, y da " ..
    "true con solo tener godmode puesto ( :2720 ). 0 = CONTROL: encadena a la base y el bot vuelve a " ..
    "retroceder. OJO: con el control en 0, testear con `god` cambia el comportamiento del bot.", 0, 1 )

local cvReachProps = CreateConVar( "phantasmagoria_ghost_reachprops", "1", FCVAR_ARCHIVE,
    "Un PROP entre el fantasma y vos no lo hace desistir. La base traza un hull con MASK_SOLID de " ..
    "ojos a ojos ( motionoverrides.lua:76 ) y escribe NothingOrBreakableBetweenEnemy; una mesa lo " ..
    "pone en false y el duelo aborta con 'my enemy wasnt engagable!'. El autor VERIFICO en juego que " ..
    "el fantasma atraviesa las mesas y las empuja. 0 = CONTROL, la mesa vuelve a cortar.", 0, 1 )

local cvReachDrop = CreateConVar( "phantasmagoria_ghost_reachdrop", "1", FCVAR_ARCHIVE,
    "Un pozo de 18 u ( ni el jugador en el aire ) no hace desistir al fantasma. CanMoveRightUpToEnemy " ..
    "( enemyoverrides.lua:1256 ) traza StepHeight hacia abajo desde el PUNTO MEDIO entre los dos " ..
    "origenes: con el jugador saltando ese punto queda en el aire y da false. Su propio docstring dice " ..
    "'very lazy check' y el cache de 0,5 s sobrevive a un cambio de enemigo. 0 = CONTROL.", 0, 1 )

local cvCatch = CreateConVar( "phantasmagoria_ghost_catch", "1", FCVAR_ARCHIVE,
    "El contacto MATA ( Diseno 5.4, ability.onCatch ). 0 = CONTROL: el fantasma llega, se te pega y " ..
    "no pasa nada, que es exactamente el sintoma que reporto el autor -- sirve para separar 'no llega' " ..
    "de 'llega y no mata'.", 0, 1 )

---------------------------------------------------------------------------
-- EL ALCANCE. UN SOLO NUMERO, UNA SOLA CASA
---------------------------------------------------------------------------
-- Este numero decide DOS cosas: que le contesta el fantasma a la base cuando le
-- preguntan su alcance de arma, y a que distancia el contacto mata. Tienen que
-- ser el MISMO numero, o el bot se planta a una distancia a la que su propio
-- desenlace no dispara -- y el sintoma seria "llega y no me mata", que es
-- justamente el que estamos arreglando.
--
-- *Una constante que decide geometria tiene que existir UNA vez.* La leccion es
-- del lote de equipamiento de Phasmophobia y ya costo una ronda ahi.
--
-- 64 u: el hull del bot mide 32 de ancho y el del jugador otros 32, o sea que
-- origen contra origen se tocan a ~32 u. El resto es margen de tick -- a 300 u/s
-- y 0,05 s de intervalo el bot avanza 15 u entre dos mediciones. NO es un numero
-- del juego original: es geometria de este motor, y por eso es convar.
local cvReach = CreateConVar( "phantasmagoria_ghost_reach", "64", FCVAR_ARCHIVE,
    "Alcance del fantasma en unidades, origen contra origen. Es el MISMO numero para dos cosas: lo que " ..
    "GetWeaponRange le contesta a la base cuando el fantasma esta desarmado, y la distancia a la que " ..
    "el contacto mata. Los hulls miden 32 de ancho cada uno, asi que 64 es 'tocandote' con margen de " ..
    "un tick de carrera.", 16, 512 )

local function alcance()
    return cvReach:GetInt()

end

---------------------------------------------------------------------------
-- LA CONTABILIDAD, POR FANTASMA
---------------------------------------------------------------------------
-- Todo lo que este archivo decide es invisible desde afuera: un desvio de tarea
-- no deja huella y una condicion que no se cumplio tampoco. Sin estos
-- contadores, "el hunt directo funciona" seria una impresion.
--
-- Y CADA CONTADOR TIENE SU DENOMINADOR. `desvios 0` solo no distingue "la
-- compuerta anda y la base no pidio ninguna tarea tactica" de "la compuerta no
-- corre": para eso esta `vistas`, que cuenta TODOS los StartTask que pasaron por
-- la compuerta estando en hunt. Los dos en cero quiere decir que no corrio.
local function stats( ghost )
    ghost.phantom_huntStats = ghost.phantom_huntStats or {
        -- la compuerta
        vistas = 0, desvios = 0, dejadas = 0,
        aFollow = 0, aLastSeen = 0, aSearch = 0, flanksCerca = 0,
        porTarea = {},

        -- la escalera propia
        escaleraVe = 0, escaleraNoVe = 0, escaleraSinEnemigo = 0, escaleraBase = 0,

        -- el contacto
        cerca = 0, parados = 0, contactos = 0, muertes = 0, sinEfecto = 0, tapados = 0, banish = 0,

        -- el perro guardian
        sinTarea = 0, rescates = 0,

        -- lo que se le contesto a la base
        rangePedidos = 0, rangeMentira = 0, miedoPedidos = 0,
        propsSalvados = 0, pozosSalvados = 0,
    }

    return ghost.phantom_huntStats

end

---------------------------------------------------------------------------
-- 1 · EL REPARTO ENTRE FANTASMAS, QUE HOY ESTA PRENDIDO
---------------------------------------------------------------------------
-- `ENT.InformRadius = 20000` en la base ( shared.lua:135 ) y el fantasma no la
-- pisaba. Con eso `GetNearbyAllies` ( enemyoverrides.lua:1603 ) devuelve vecinos,
-- `GetOtherHuntersProbableEntrance` ( :1331 ) devuelve un punto, y entonces
-- **`movement_followenemy` construye un path de FLANQUEO en su propio OnStart**
-- ( shared.lua:7381; el comentario del autor de la base dice literalmente
-- *"split up!"* ) aunque no este flanqueando. O sea: la tarea que ES nuestra
-- persecucion directa da un rodeo por su cuenta si hay otro fantasma cerca.
--
-- Con un solo fantasma no muerde; con dos, si. HIM pone exactamente esto
-- ( him/.../server.lua:17 ).
--
-- VA COMO CAMPO Y NO COMO CONVAR a proposito: no es un A/B de este bloque, es
-- una decision de diseno. El dia que se quiera que dos fantasmas coordinen, se
-- sube A PROPOSITO y se mide. El instrumento lo imprime para que un 0 heredado
-- no pase por olvido.
--
-- ⚠⚠ EL NUMERO SE GUARDA ADEMAS EN UN LOCAL, Y ESO NO ES REDUNDANCIA: ES EL
-- ARREGLO DE UN ERROR QUE EL AUTOR SE COMIO EN LA PRIMERA CORRIDA.
-- `ENT` es un global que **solo existe mientras este archivo se esta cargando**;
-- apenas termina el chunk vuelve a ser nil. El reporte de mas abajo lo leia como
-- `ENT.InformRadius`, y el reporte corre DESPUES -- asi que el comando moria con
--
--     server_hunt.lua:1217: attempt to index global 'ENT' (a nil value)
--
-- justo despues de imprimir las perillas, y se llevaba puesto TODO el bloque por
-- fantasma, que es el que trae los contadores. Las guardas del final de este
-- archivo tambien tocan `ENT`, y esas SI valen: corren al cargar.
-- *Un mismo nombre es valido o nil segun CUANDO se lo lea, y las dos lecturas se
-- escriben igual.*
--
-- El local sobrevive al chunk porque es un upvalue de las funciones de este
-- archivo. Y de paso el numero queda con UNA sola casa: el campo se asigna
-- desde el local, no al reves.
local INFORM_RADIUS = 0

ENT.InformRadius = INFORM_RADIUS

---------------------------------------------------------------------------
-- 2 · DECIRLE LA VERDAD A LA BASE SOBRE EL ARMA
---------------------------------------------------------------------------
--[[
    ES LO QUE MAS PAGA POR LINEA ESCRITA, y no es una opinion: cierra `camp` y
    `perch` en TODA la base a la vez -- incluidas ramas que ni siquiera estan en
    la lista de puertas de la compuerta -- y mata un error de Lua que hoy sale en
    consola con stack.

    LOS TRES VALORES DERIVADOS QUE MIENTEN HOY, con la linea de cada uno:

      GetWeaponRange()  ->  math.huge      weapons.lua:1935
                            *"our eyes have infinite range"*, dice el autor de la
                            base. Es correcto para un bot que dispara y no tiene
                            arma en la mano; es falso para uno que MATA
                            TOCANDOTE.

      IsMeleeWeapon()   ->  false          weapons.lua:978
                            Sale por `if not IsValid( wep ) then return false end`
                            ANTES de llegar a su propia regla de abajo
                            ( `range < 150 -> melee` ). O sea que arreglar
                            GetWeaponRange solo NO alcanza: la rama que lo
                            consultaria no se ejecuta nunca sin arma.

      EnemyIsLethalInMelee() -> true si tenes godmode    shared.lua:2740 / :2720

    LO QUE SE ABRE CON ESAS TRES MENTIRAS ( todo esto es de la base, no nuestro ):

      campIsGood      = true SIEMPRE      ( weapRange > 6000 )
      withinWeapRange = true SIEMPRE
      notMelee        = true SIEMPRE
      canCover        = deja de ser imposible, porque IsRangedWeapon( nil ) da true

    y ademas dan `true` todas las comparaciones de alcance de la base:
    `> 1250` ( shared.lua:6968 y :7439 ), `> 2000` ( :8201 ), `> 6000` ( :2405 ).
    *Un fantasma que solo mata tocandote esta siendo tratado como francotirador.*

    EL ERROR DE LUA QUE ESTO MATA, y el juego lo imprimio solo en la corrida 2b
    del autor, sin que nadie lo buscara:

        176  movement_perch  [NULL Entity]  i ran out of places, and i have a real weapon
        [Terminator Nextbot] ... tried to start already active task: movement_perch
          1. StartTask - taskoverride.lua:176
           2. callback - shared.lua:8203

    La rama de shared.lua:8201 pide `not IsMeleeWeapon( GetWeapon() ) and
    GetWeaponRange() > 2000`. El fantasma desarmado cumple LAS DOS, la base dice
    *"tengo un arma de verdad"* sobre un bot que no tiene nada, y de paso destapa
    un bug de la base -- arrancar `movement_perch` estando ya activa -- que solo
    un bot con esas dos propiedades puede disparar. **Ese bug NO se parchea**: se
    apaga solo cuando el fantasma deja de mentir.

    CONSECUENCIA DECLARADA, EN LA OTRA DIRECCION. `blockerAtGoodRange`
    ( shared.lua:1322 ) hoy es `true` para cualquier bloqueador porque compara
    contra `math.huge^2`. Con el alcance real, un bloqueador a mas de 64 u deja de
    estar "a buen alcance". Se reviso rama por rama y NO toca abrir puertas: la
    unica rama que hace `use = true` sobre una `prop_door_rotating`
    ( shared.lua:1343, `doorState ~= 2` ) NO consulta ese valor, y las que si lo
    consultan piden ademas `isFists`, que en este bot es false. *Se dice igual,
    porque una consecuencia que no se escribio es la que despues se lee como un
    bug nuevo.*
]]

function ENT:GetWeaponRange( myTbl, wep, wepTable )
    myTbl = myTbl or self:GetTable()

    -- Se resuelve el arma ACA y se le pasa resuelta al BaseClass. No es
    -- prolijidad: la base tira ErrorNoHaltWithStack si `myTbl.GetActiveLuaWeapon`
    -- no esta ( weapons.lua:1937, su propio "you did it wrong" ), asi que
    -- llamarla con un myTbl a medias seria pedirle el error a ella.
    wep = wep or ( isfunction( myTbl.GetActiveLuaWeapon ) and myTbl.GetActiveLuaWeapon( self, myTbl ) )
        or self:GetActiveWeapon()

    local st = self.phantom_huntStats
    if st then st.rangePedidos = st.rangePedidos + 1 end

    -- CON arma se encadena siempre, aun con la perilla en 1: el pickup puede
    -- volver a 1 ( phantasmagoria_ghost_pickup ) y en ese caso el alcance de la
    -- SMG es un dato de la SMG, no nuestro. Nuestra unica afirmacion es sobre el
    -- fantasma DESARMADO.
    if IsValid( wep ) or not cvTrueRange:GetBool() then
        return myTbl.BaseClass.GetWeaponRange( self, myTbl, wep, wepTable )

    end

    if st then st.rangeMentira = st.rangeMentira + 1 end

    return alcance()

end

-- Y LA SEGUNDA MITAD, SIN LA CUAL LA PRIMERA NO CIERRA `camp`.
--
-- `doCamp` ( shared.lua:2412 ) es
--     dist > 1400 and ( not doWatch ) and campIsGood and withinWeapRange and notMelee
-- y con el alcance ya arreglado sigue quedando:
--     campIsGood      = boredOrRand and not veryHighHealth
--     withinWeapRange = dist > alcance -> true a cualquier distancia util
--     notMelee        = true
-- o sea que un fantasma AL QUE LE PEGARON UNA VEZ ( `veryHighHealth` deja de ser
-- true ) vuelve a campear con un 35 % de probabilidad. `notMelee` es la puerta
-- que lo cierra de verdad, y es la que esta funcion abre.
--
-- `doWatch` de esa misma linea NO EXISTE en la funcion: es un global `nil`, asi
-- que `not doWatch` es `true` siempre. Es un defecto de la base y no se toca;
-- solo hay que saber que esa condicion no cierra nada.
function ENT:IsMeleeWeapon( wep )
    if cvTrueRange:GetBool() then
        wep = wep or self:GetActiveWeapon()

        -- Desarmado, este bot ES un arma de melee: su alcance es el contacto. No
        -- es una mentira comoda al reves -- es la misma regla que la base aplica
        -- a cualquier arma con `range < 150` ( weapons.lua:995 ), leida sobre el
        -- alcance que le acabamos de decir.
        if not IsValid( wep ) then return true end

    end

    return self.BaseClass.IsMeleeWeapon( self, wep )

end

-- Y EL MIEDO.
--
-- `EnemyIsLethalInMelee` ( shared.lua:2740 ) da true si el jugador es
-- "unkillable" ( vida > 10000 **o godmode**, :2720 ) o si mato dos NPC de la base
-- a menos de 350 u en los ultimos 15 minutos ( hook `terminator_markkillers`,
-- :2755 ). Prende `tooDangerousToApproach`, el creeping agachado, y
-- `movement_backthehellup`.
--
-- Un fantasma de Phasmophobia no evalua si podes con el. Y hay una razon de
-- MEDICION ademas de una de diseno: con `god` puesto -- que es como se testea un
-- hunt sin morirse en la primera fila -- la base cambia de comportamiento, y
-- entonces la planilla estaria midiendo un bot distinto del que juega el jugador.
-- Con la perilla en 1 esa contaminacion desaparece; con la perilla en 0 vuelve, y
-- ahi `god` es una PRECONDICION de la fila. El instrumento lo avisa solo.
function ENT:EnemyIsLethalInMelee( enemy )
    local st = self.phantom_huntStats
    if st then st.miedoPedidos = st.miedoPedidos + 1 end

    if cvFearless:GetBool() then return end

    return self.BaseClass.EnemyIsLethalInMelee( self, enemy )

end

---------------------------------------------------------------------------
-- 3 · ENSENARLE A LA BASE COMO ES **ESTE** BOT
---------------------------------------------------------------------------
--[[
    ACA ESTA EL DESACOPLE Y ES NUESTRO, NO DE LA BASE.

    El autor aislo el bucle `followenemy -> duelenemy_near -> "my enemy wasnt
    engagable!" -> approachlastseen -> followenemy` en TRES escenarios, y dieron
    tres resultados distintos:

      a) Parking plano, sin props, a 5 m, dando vueltas en circulo.
         NO aparece. *"no deja de perseguirme"*.
      b) El mismo lugar con MESAS de por medio ( congeladas y descongeladas ).
         APARECE. *"Ese approachlastseen fue porque choco con la mesa!"*
      c) CROUCH-JUMP del jugador ( el salto a lo HL1 ). APARECE.
         Este no estaba planeado: lo midio sin querer.

    Son DOS funciones distintas, una por escenario, y **arreglar una no acredita
    la otra**. Por eso hay dos perillas y la planilla tiene dos filas.

    La condicion que las consume es `badEnemy` de `movement_duelenemy_near`
    ( shared.lua:7595-7604 ):

        badEnemy si  ( not canCover and not NothingOrBreakableBetweenEnemy )   <- (b)
                  o  ( not rangedWep and not CanMoveRightUpToEnemy( enemy ) )  <- (c)

    y el desenlace no perdona: `if data.badEnemyCounts > 6 **or
    data.fightingPlayer** then` ( :7636 ). **Contra un NPC la base tolera 6 ticks
    malos; contra un jugador aborta en el PRIMERO.**

    Y las dos funciones trazan SIN CONSULTAR la solidez del fantasma, que tiene un
    dueno unico y es `server_doors.lua`. *La base esta calculando el alcance de un
    bot que no es el nuestro.*
]]

-- ESCENARIO (b): EL PROP DE POR MEDIO.
--
-- `NothingOrBreakableBetweenEnemy` no es una funcion: es un CAMPO que
-- `enemy_handler` escribe cada tick ( shared.lua:3316-3327 ) desde
-- `ClearOrBreakable`, con un hull de 2 u y MASK_SOLID de ojos a ojos. El rescate
-- del segundo trace ( :3317 ) solo corre si `DontShootThroughProps`, que
-- unicamente pone el csoldier ( terminator_nextbot_csoldier.lua:113 ).
--
-- EL DISCRIMINANTE ES `doSmallHull`, Y NO ES ARBITRARIO. Este override tiene que
-- tocar la pregunta "¿alcanzo a mi enemigo?" y NO la pregunta "¿por donde
-- camino?", porque de la segunda cuelga la esquiva de obstaculos de la base
-- ( motionoverrides.lua:1174, :1197, :1227, :1260, :1865-1866 ) y un fantasma que
-- cree que los props no existen deja de esquivarlos y se encaja -- que es el
-- defecto que server_stuck.lua existe para medir.
--
-- El censo de los call sites del hull chico sobre ESTA clase da DOS:
--     shared.lua:3316   el campo del enemigo            <- el que queremos
--     shared.lua:5389   ir a golpear lo que hizo ruido  <- inerte: sin TERM_FISTS
--                                                          no golpea nada
-- Todos los de movimiento pasan `doSmallHull` falso o un `hullMul`. O sea que una
-- guarda de una linea acota el cambio a un solo consumidor vivo.
--
-- Y LO QUE DEVUELVE ES EL "O ROMPIBLE" DE LA BASE, no un true inventado: la base
-- YA tiene el concepto de "hay algo en el medio pero igual voy a pasar"
-- ( `hitNothingOrHitBreakable` ). Lo unico que decimos es que, para este bot, un
-- prop que puede EMPUJAR cuenta como rompible. El `hitNothing` se devuelve tal
-- cual vino, asi que la rama de `DontShootThroughProps` no se entera de nada.
function ENT:ClearOrBreakable( start, endpos, doSmallHull, hullMul )
    local claro, traza, vacio = self.BaseClass.ClearOrBreakable( self, start, endpos, doSmallHull, hullMul )

    if claro then return claro, traza, vacio end
    if not cvReachProps:GetBool() then return claro, traza, vacio end
    if doSmallHull ~= true then return claro, traza, vacio end
    if not traza then return claro, traza, vacio end

    -- Solo entidades. Si lo que pego es el MUNDO ( o un brush del mapa ), sigue
    -- siendo un muro: el fantasma atraviesa puertas, no paredes. `traza.Entity`
    -- viene NULL o worldspawn en ese caso.
    local pego = traza.Entity
    if not IsValid( pego ) then return claro, traza, vacio end
    if pego:IsWorld() then return claro, traza, vacio end

    local st = self.phantom_huntStats
    if st then st.propsSalvados = st.propsSalvados + 1 end

    return true, traza, vacio

end

-- ESCENARIO (c): EL JUGADOR EN EL AIRE, Y EL POZO DE 18 u.
--
-- `CanMoveRightUpToEnemy` ( enemyoverrides.lua:1256 ) delega en
-- `GetIsFlatGroundToEnemy` ( :1201 ), que toma el punto medio EXACTO entre los
-- dos origenes y traza `StepHeight` ( 18 u ) hacia abajo con
-- `MASK_SOLID_BRUSHONLY | CONTENTS_MONSTERCLIP`. Con el jugador saltando, ese
-- punto medio sube y el trace no encuentra piso. Da false tambien con pisos
-- distintos y con huecos de escalera. Su propio docstring lo llama *"very lazy
-- check"* y avisa que el cache de 0,5 s **sobrevive a un cambio de enemigo**.
--
-- La pregunta que la funcion contesta es *"¿me puedo caer en un pozo yendo
-- derecho?"*. Para este fantasma EN CACERIA la respuesta es que no le importa: va
-- derecho igual, y si se cae, el pathing y `server_stuck.lua` lo levantan.
--
-- FUERA DEL HUNT SE ENCADENA A LA BASE. Un fantasma en calma no tiene ningun
-- motivo para ignorar un pozo, y ademas dejarlo encadenado es lo que hace que la
-- fila de la planilla pueda comparar los dos estados en la misma corrida.
--
-- ⚠⚠ SE LE PREGUNTA A LA BASE PRIMERO **AUNQUE LA RESPUESTA NO SE USE**, y no es
-- un descuido: es lo que convierte al contador en una medicion. Escrito al reves
-- -- cortocircuitar y contar -- `pozos salvados` subia en CADA llamada estando en
-- hunt, o sea tambien cuando la base iba a decir que si, y entonces el numero no
-- podia distinguir *"rescate un caso que nos habria hecho desistir"* de *"el
-- override existe"*. La fila de la planilla se apoya en ese numero, asi que un
-- contador que sube siempre le da un verde que no midio nada.
--
-- Cuesta lo que cuesta el trace de la base, que **ya esta cacheado 0,5 s** por
-- ella misma ( enemyoverrides.lua:1204 ), asi que no se agrega trabajo: se agrega
-- el denominador.
function ENT:CanMoveRightUpToEnemy( enemy )
    local base = self.BaseClass.CanMoveRightUpToEnemy( self, enemy )

    if base then return base end
    if not cvReachDrop:GetBool() then return base end
    if not self.phantom_Hunting then return base end

    local st = self.phantom_huntStats
    if st then st.pozosSalvados = st.pozosSalvados + 1 end

    return true

end

---------------------------------------------------------------------------
-- 4 · LA ESCALERA PROPIA
---------------------------------------------------------------------------
--[[
    `ENT:EnemyAcquired` ( shared.lua:2360 ) es EL EMBUDO: la llaman 21 sitios y es
    la que decide todo el reparto tactico. Su orden real, con la linea de cada
    rama, para que se lea por que la persecucion directa casi no sale:

       :2376  term_ExpensivePath y el path sirve   -> SALE SIN DECIDIR
       :2378  tooDangerousToApproach
        -1    intercept / isBeingFooled / no ve    -> approachlastseen
        -2    doBaitWatch                          -> movement_watch
       :2410  doNormalWatch / beginFirstWatch      -> movement_watch
        -3    campDangerousEnemy                   -> movement_camp
       :2412  doCamp                               -> movement_camp / perch
        -4    canRushKiller                        -> flankenemy
        -5    tooDangerousToApproach               -> stalk / backthehellup / camp
       :2417  doStalk                              -> movement_stalkenemy
       :2420  doFlank                              -> movement_flankenemy
        -6    else                                 -> movement_followenemy

    **La persecucion directa es el ULTIMO else de diez.**

    En hunt la reemplazamos entera por cuatro renglones. No es una copia de la
    escalera de la base con ramas comentadas -- eso seria copiar codigo de un
    tercero, que conserva la propiedad de discriminar mientras envejece
    ( catalogo nº 87, el que costo dos dias ) --: es una escalera NUEVA y corta.

    LO QUE SE CONSERVA DE LA BASE, Y POR QUE CADA COSA:

      · La escalera FISICA ( `terminator_HandlingLadder` ). No tiene nada que ver
        con tactica: es trepar. Se delega igual que la base y se devuelve nil
        igual que ella, para que los llamadores caigan por el mismo lado.

      · `CanSeePosition` fresco en vez del campo cacheado `IsSeeEnemy`. Es lo que
        hace la base, con su propio comentario al lado explicando por que
        ( *"check here so it's always accurate, fucked me over tho"* ).

    LO QUE SE DEJA AFUERA A PROPOSITO Y QUEDA DECLARADO:

      · `interceptIfWeCan` ( adelantarse a donde vas a estar ). Es defendible para
        un hunt y no esta pedido; meterlo agrega `movement_intercept`, que es otra
        tarea con vida propia. Queda anotado como frontera, no como olvido.

      · El corte por `term_ExpensivePath` ( :2376 ). Ese corte devuelve **nil**, y
        `movement_handler` lo lee como *"EnemyAcquired no hizo nada"* y sigue de
        largo hasta `movement_inertia` -- o sea que el atajo de rendimiento de la
        base puede terminar en un PASEO. Nuestra escalera decide siempre; es mas
        barata que la de ella ( dos ramas, sin trazas ), asi que no hay nada que
        ahorrar.
        Y ES LA TRAMPA DE MEDICION DEL BLOQUE: con la perilla en 0, una fila que
        espere ver una rama de la escalera y no la vea puede estar midiendo ESTO y
        no el arreglo. *Si una fila sale vacia, el vacio tiene que ser una
        medicion.*
]]
function ENT:EnemyAcquired( currentTask )
    if not IsValid( self ) then return end

    local myTbl = self:GetTable()

    if not myTbl.phantom_Hunting or not cvHuntDirect:GetBool() then
        local previo = self.phantom_huntStats
        if previo then previo.escaleraBase = previo.escaleraBase + 1 end

        return myTbl.BaseClass.EnemyAcquired( self, currentTask )

    end

    local st = stats( self )
    local enemy = self:GetEnemy()

    if not IsValid( enemy ) then
        st.escaleraSinEnemigo = st.escaleraSinEnemigo + 1

        self:TaskComplete( currentTask )
        self:StartTask( "movement_approachlastseen", nil, "hunt: el enemigo dejo de valer" )
        return true

    end

    -- Trepar no es tactica. Misma delegacion y mismo return que la base
    -- ( shared.lua:2368 ), que devuelve nada a proposito.
    if myTbl.terminator_HandlingLadder then
        self:TermHandleLadder()
        return

    end

    local veo = self:CanSeePosition( enemy )

    self:TaskComplete( currentTask )

    -- `PreventShooting` lo prende la rama de `beginFirstWatch` de la base
    -- ( :2440 ) y NADIE lo apaga si esa rama fue la ultima en correr antes de que
    -- se prendiera el hunt. La base lo limpia en cada una de sus ramas de
    -- persecucion; se hace lo mismo por el mismo motivo.
    myTbl.PreventShooting = nil

    if veo then
        st.escaleraVe = st.escaleraVe + 1
        self:StartTask( "movement_followenemy", nil, "hunt: derecho a el" )

    else
        st.escaleraNoVe = st.escaleraNoVe + 1
        self:StartTask( "movement_approachlastseen", nil, "hunt: donde se metio" )

    end

    return true

end

---------------------------------------------------------------------------
-- 5 · LA COMPUERTA: LAS PUERTAS QUE NO PASAN POR LA ESCALERA
---------------------------------------------------------------------------
--[[
    En `terminator_nextbot/shared.lua` hay **64 `StartTask` apuntando a las tareas
    que sobran** ( 19 stalkenemy, 14 perch, 12 flankenemy, 9 camp, 6 watch,
    4 backthehellup ). Pero solo ONCE viven adentro de tareas que en hunt siguen
    corriendo, y estan contados uno por uno:

        movement_search           :5712 perch
        movement_approachlastseen :7325 perch
        movement_followenemy      :7436 stalk · :7439 camp · :7446 stalk · :7449 perch
        movement_duelenemy_near   :7662 perch · :7667 stalk · :7689 stalk · :7932 watch

    Los otros 53 estan dentro de tareas que, con esta compuerta puesta, no
    arrancan. **Once sitios, no sesenta y cuatro.**

    POR QUE UNA COMPUERTA EN `StartTask` Y NO UNA GUARDA EN CADA SITIO: los sitios
    estan adentro del cuerpo de tareas de un tercero. Guardarlos uno por uno pide
    copiarlos, y una copia de codigo ajeno conserva la propiedad de discriminar
    mientras envejece -- se guarda, no se copia. El cuello unico ya existia y ya
    es nuestro: `ENT:StartTask` esta overrideado en `server_stuck.lua:1035` desde
    la ronda de los atascos.

    LA TRAMPA DEL DESVIO, Y NO ES GRATIS ( se reviso sitio por sitio ):
    `StartTask` sale temprano si la tarea ya esta activa ( taskoverride.lua:167 ).
    Si se desvia X -> followenemy en un sitio donde followenemy YA estaba activa,
    el StartTask no hace nada Y la tarea vieja ya se cerro: el bot queda sin
    ninguna. Los once sitios se leyeron con su contexto y **los once hacen
    `TaskFail` / `TaskComplete` de la tarea que los contiene ANTES del StartTask**,
    incluidos los cuatro que viven adentro de `movement_followenemy` -- o sea que
    el destino nunca esta activo en el momento del desvio. Igual hay perro
    guardian, porque *"se reviso" no es "no puede pasar"*.

    Y LA FAMILIA "NO PUEDO LLEGAR" ES OTRO PROBLEMA Y NO SE DISFRAZA. Cuatro de
    los once sitios ( :7325, :7446, :7449, :7662/:7667 ) disparan porque
    `data.Unreachable`. Mandarlos a `movement_followenemy` seria un bucle de un
    tick: la tarea nueva recalcula que no llega y vuelve a salir. Van a
    `movement_search` con los MISMOS numeros que la base usa para el caso
    equivalente ( searchWant 20, searchRadius 2000, shared.lua:7662 ), que ademas
    es "buscar" -- una de las tres cosas que el autor pidio conservar. Y se
    CUENTAN aparte: si ese contador sube, el problema es de navmesh y no de este
    bloque.
]]

-- Las tareas que se cierran EN HUNT. Siguen registradas: esto es un estado, no un
-- registro. Fuera del hunt las siete estan disponibles enteras.
local CERRADAS = {
    -- las tacticas del reparto de la escalera
    [ "movement_watch" ]         = true,
    [ "movement_stalkenemy" ]    = true,
    [ "movement_camp" ]          = true,
    [ "movement_perch" ]         = true,
    [ "movement_backthehellup" ] = true,

    -- Y EL VAGABUNDEO, que se apaga POR CONDICION y no por registro. De el cuelga
    -- `server_leash.lua` ( la correa ), que es de fuera del hunt: sacarlo del
    -- registro se llevaria puesta la correa entera. Ademas es el que produjo el
    -- sintoma medido -- prender el hunt y ver al bot seguir caminando a un punto
    -- al azar a 5000-6000 u.
    [ "movement_inertia" ]       = true,
    [ "movement_biginertia" ]    = true,
}

-- El flanqueo NO esta en la lista de arriba, y es una decision del autor mirando
-- su propio log:
--
--     *"Parece que flankenemy esta bien como accion, watch y stalk no en hunt"*
--
-- `SetupFlankingPath` ( pathoverrides.lua:408 ) le SUMA COSTO a las navareas entre
-- el bot y vos para que A* las esquive: `flankAroundCorridorBetween` ( :451 )
-- infla el corredor directo y `FlankAroundEasyEntraceToThing` ( :463 ) castiga la
-- entrada facil con `FLANK_DEFAULT_COST * 2`. La ruta larga es el objetivo
-- declarado, no un efecto.
--
-- Y `movement_flankenemy` SIEMPRE construye ese path, aun cuando entra como
-- `"too close pal"`. A 2 m eso es un no-op; a 30 m es el desvio. **Lo que se
-- acepta no es la tarea: es la distancia a la que se la deja entrar.**
--
-- El numero es 400 u y NO es mio: es la frontera que la base ya usa en su propio
-- `doFlank` ( shared.lua:2420, `dist >= 400` ). Poniendo el corte ahi, las dos
-- mitades no se solapan -- lo que la base considera "flanqueo de verdad" es
-- exactamente lo que nosotros cerramos.
local cvFlank = CreateConVar( "phantasmagoria_ghost_huntflank", "400", FCVAR_ARCHIVE,
    "En hunt, distancia en unidades por debajo de la cual movement_flankenemy se deja entrar ( cerrar " ..
    "desde cerca, que es lo que el autor vio y aprobo ). Por encima se desvia a la persecucion directa, " ..
    "porque esa tarea SIEMPRE construye un path de rodeo. 400 u es la frontera del propio doFlank de la " ..
    "base ( shared.lua:2420 ). 0 = nunca se deja entrar.", 0, 4000 )

-- Los motivos de la familia "no puedo llegar". Se identifican POR EL MOTIVO y no
-- por la tarea, y eso tiene precedente en esta misma carpeta: el override de
-- `StartTask` de `server_stuck.lua` ya lee motivos ( su tabla MOTIVOS ), y el
-- propio autor de la base dice al lado del argumento *"This is an essential
-- debugging tool, Use it."* ( taskoverride.lua:189 ). Son subcadenas y no
-- igualdades porque los cuatro sitios escriben la misma idea con colas distintas
-- ( *"i cant reach the pos, ill try looking at it?"*, *"i cant get to them, lets
-- see if i can get LOS"* ).
--
-- Si un dia la base cambia esos textos, esto deja de reconocerlos y el desvio cae
-- al default ( perseguir / buscar por vista ). Eso NO deja al bot sin tarea:
-- degrada a la rama de al lado. Y se nota, porque `aSearch` se va a cero mientras
-- `desvios` sigue subiendo -- que es justamente para lo que estan los dos
-- contadores separados.
local NO_LLEGO = { "i cant reach", "i cant get to" }

local function esNoLlego( motivo )
    if not isstring( motivo ) then return false end

    for _, aguja in ipairs( NO_LLEGO ) do
        if string.find( motivo, aguja, 1, true ) then return true end

    end

    return false

end

-- Devuelve la terna ( task, data, reason ) ya desviada, o la misma que entro. La
-- llama `ENT:StartTask` de server_stuck.lua, que es el dueno unico de ese
-- override. Ver la guarda del final de este archivo.
function ENT:phantom_HuntTaskGate( task, data, reason )
    local myTbl = self:GetTable()

    if not myTbl.phantom_Hunting then return task, data, reason end
    if not cvHuntDirect:GetBool() then return task, data, reason end
    if not isstring( task ) then return task, data, reason end

    local st = stats( self )
    st.vistas = st.vistas + 1

    local cerrada = CERRADAS[ task ]

    if not cerrada and task == "movement_flankenemy" then
        -- `DistToEnemy` lo escribe `enemy_handler` cada tick ( shared.lua:3309 ) y
        -- es el mismo numero con el que la base toma todas sus decisiones de
        -- distancia. Si todavia no corrio no hay con que decidir, y se cierra: de
        -- los dos errores posibles, el rodeo es el caro.
        local dist = myTbl.DistToEnemy

        if isnumber( dist ) and dist <= cvFlank:GetInt() then
            st.flanksCerca = st.flanksCerca + 1
            st.dejadas = st.dejadas + 1

            return task, data, reason

        end

        cerrada = true

    end

    if not cerrada then
        st.dejadas = st.dejadas + 1
        return task, data, reason

    end

    st.desvios = st.desvios + 1
    st.porTarea[ task ] = ( st.porTarea[ task ] or 0 ) + 1

    local motivo = isstring( reason ) and reason or "?"
    local cola = "  ( era " .. task .. ": " .. motivo .. " )"
    local enemy = myTbl.GetEnemy( self )

    -- A `movement_search` van TRES casos, y no es economia: es que los tres
    -- comparten la misma propiedad y esa propiedad es lo que evita un bucle de un
    -- tick. `movement_search` es la unica de las tres candidatas que NO PUEDE
    -- fallar por falta de un punto -- su centro cae en cascada `data.searchCenter`
    -- -> `EnemyLastPosOffsetted` -> `self:GetPos()` ( shared.lua:5437 ) -- y ademas
    -- dura muchos segundos, asi que no puede reentrar cada frame.
    --
    --   ( 1 ) La familia "no puedo llegar". Mandarla a `followenemy` seria un
    --         bucle: la tarea nueva recalcula que no llega y vuelve a salir.
    --   ( 2 ) El vagabundeo. En hunt no se pasea, se BUSCA -- que ademas es una de
    --         las tres cosas que el autor pidio conservar.
    --   ( 3 ) Sin enemigo valido. `movement_approachlastseen` puede vencerse en el
    --         acto si no hay ninguna posicion que aproximar, y esa es la unica
    --         combinacion de este bloque que podria repetirse cada frame.
    local aBuscar = esNoLlego( motivo )
        or task == "movement_inertia" or task == "movement_biginertia"
        or not IsValid( enemy )

    if aBuscar then
        st.aSearch = st.aSearch + 1

        -- Los numeros son los que la base usa para su propio caso equivalente
        -- ( "my enemy is gone and i cant get to where they were", shared.lua:7662 ):
        -- 20 de `searchWant` y 2000 u de radio. No se inventa un balance nuevo.
        local centro = IsValid( enemy ) and self:GetLastEnemyPosition( enemy ) or myTbl.EnemyLastPosOffsetted

        return "movement_search",
            { searchCenter = centro, searchWant = 20, searchRadius = 2000 },
            "hunt: busco" .. cola

    end

    if myTbl.IsSeeEnemy then
        st.aFollow = st.aFollow + 1
        return "movement_followenemy", nil, "hunt: derecho a el" .. cola

    end

    st.aLastSeen = st.aLastSeen + 1
    return "movement_approachlastseen", nil, "hunt: donde se metio" .. cola

end

---------------------------------------------------------------------------
-- 6 · PRENDER EL HUNT TIENE QUE INTERRUMPIR LO QUE ESTE HACIENDO
---------------------------------------------------------------------------
-- MEDIDO EN LAS DOS CORRIDAS: con el fantasma vagabundeando,
-- `phantasmagoria_hunt 1` prende el flag y el enemigo pasa a ser valido -- las
-- lineas siguientes ya dicen `Player [1][SEPULDOSKY]` -- pero la tarea sigue
-- siendo la vieja:
--
--     movement_biginertia  Player  i still want to wander
--     movement_handler     Player  im all done wandering
--     movement_wait        Player  wait...
--
-- `movement_biginertia` elige un punto al azar a 5000-6000 u ( shared.lua:8192 ) y
-- solo re-decide si `IsSeeEnemy` ( :8262 ). En la corrida vieja de `gm_prison`
-- esto hizo que el fantasma se fuera a la sala de control mirando al jugador, y el
-- autor lo leyo como un flanqueo. **No lo era: era un paseo que nadie mato.**
--
-- El mecanismo ya existe y aparece en los propios logs del autor como
-- `KILLED n TASKS CONTAINING: movement` ( taskoverride.lua:136 ). La secuencia
-- -- matar y arrancar `movement_handler` en la linea siguiente -- es la que usa la
-- base en sus cinco sitios ( shared.lua:3896, :4100, ... ), no una invencion.
--
-- SE LLAMA EN LAS DOS DIRECCIONES. Al APAGAR el hunt tambien hay que cortar: el
-- bot puede quedar en `movement_followenemy` persiguiendo a alguien que ya no es
-- enemigo, y el sintoma seria un fantasma en calma corriendo detras tuyo. Que es
-- peor que el original, porque parece un hunt.
--
-- Lo llama `phantom_SetHunting` ( server.lua ), que es LA PUERTA UNICA: el dia que
-- la cordura mueva el flag, esto la sigue sin que nadie se acuerde de engancharlo.
-- Colgarlo de un Think que comparara el flag contra su propio ultimo valor seria
-- una SEGUNDA copia del estado, y esa copia se desincroniza sin decirlo -- es el
-- mismo razonamiento que ya esta escrito al lado de la voz de la caceria.
-- El valor sobre el que se corto por ultima vez. Va como CAMPO DE CLASE en false
-- y no en nil, y esa diferencia importa: `phantom_SetHunting` se llama tambien
-- desde `AdditionalInitialize` con el valor que el fantasma ya trae, y con nil
-- esa llamada de arranque contaria como un cambio.
ENT.phantom_huntCutFor = false

function ENT:phantom_HuntSwitched( hunting )
    if not cvHuntDirect:GetBool() then return end

    -- ⚠ ESTE CONSUMIDOR **SI** SE GUARDA CONTRA LA REPETICION, al reves que la voz
    -- de la caceria, que cuelga de la misma puerta y a la que se le escribio al
    -- lado justamente que la condicion NO va. No es una contradiccion: la voz es
    -- idempotente ( `Start` no corta un clip que ya suena ) y esto NO -- mata
    -- tareas y tira el path. Llamado dos veces con el mismo valor, le mataria al
    -- bot la tarea que acaba de empezar para volver a ponerle la misma.
    --
    -- Y NO es una segunda copia del estado, que es lo que aquel parrafo prohibe:
    -- es el registro de SOBRE QUE VALOR SE ACTUO, que es lo unico contra lo que
    -- una guarda de idempotencia puede comparar. La copia prohibida es la que
    -- pretende saber cual es el estado; esta solo sabe que hizo ella misma.
    if self.phantom_huntCutFor == hunting then return end
    self.phantom_huntCutFor = hunting

    local st = stats( self )

    self:KillAllTasksWith( "movement" )

    -- SIN GUARDA DE "YA ESTA ACTIVA" A PROPOSITO: la linea de arriba las mato a
    -- TODAS, incluida `movement_handler`. Si en vez de matarlas se hubiera
    -- filtrado, esta llamada podria caer en el early-out de taskoverride.lua:167 y
    -- el bot quedaria sin ninguna.
    self:StartTask( "movement_handler", nil,
        hunting and "hunt: arranco la caceria" or "hunt: se apago la caceria" )

    -- La base invalida ademas el path cuando corta asi. Se copia el gesto porque
    -- la mitad del sintoma era una tarea vieja y la otra mitad un path viejo:
    -- matar la tarea sin invalidar el path deja al bot caminando al punto del
    -- paseo con una tarea nueva encima.
    self:InvalidatePath( "phantasmagoria: cambio el estado de caceria" )

    st.rescates = st.rescates + 1

end

---------------------------------------------------------------------------
-- 7 · EL CONTACTO
---------------------------------------------------------------------------
--[[
    EL SINTOMA, textual del autor: *"el bot no me mata, llega cerca y se pega a mi.
    Pero no me golpea ni ataca realmente"*. Su hipotesis era el pickup del arma; es
    la mitad. Son DOS interruptores:

      · `phantasmagoria_ghost_pickup 0` -- no levanta armas del piso. Deliberado.
      · `ENT.TERM_FISTS = false` -- y el punetazo de la base esta detras de ese
        flag: `if fistiCuffs and self.TERM_FISTS then` ( shared.lua:7686 ).

    Con el pickup en 1 seguiria sin pegarte si no hay un arma tirada. Y en todo el
    addon NO HAY UNA SOLA LINEA que le haga dano al jugador: los unicos
    `TakeDamage` son del fantasma contra si mismo ( server_steps.lua, la caida ).

    POR QUE **NO** SE PRENDEN LOS PUNOS, que era la salida de una linea: aunque
    `TERM_FISTS` estuviera en true, el punetazo vive adentro de
    `movement_duelenemy_near`, y esa tarea tiene dos escapes que devuelven el
    problema por otro lado -- el `quitTime` de 4 a 8 s ( shared.lua:7505 ) y el
    *"the bot isnt just gonna follow you around like a lobotimised lemming"* de
    :7932. **La base decidio explicitamente que no te persiga sin parar**, que es
    correcto para un addon de sandbox y es lo contrario de un hunt.

    Se hace como HIM: el contacto es UN PASO NUESTRO, no un arma. HIM lo dispara
    desde adentro de su propia tarea de movimiento ( him/.../server.lua:2019,
    `Homeless_InstantScorn( enemy )` ) con un hook de override para que un spawnset
    lo vuelva letal. Nosotros no tenemos tarea propia -- a proposito, ver LA
    DECISION DE ARQUITECTURA -- asi que cuelga de `ENT:BehaveUpdate`, que es el tick
    de arriba de todo de esta carpeta y ya tiene un inquilino con el mismo patron
    ( el reconciliador de la ausencia, server_cloak.lua ).

    Y EL DESENLACE NO SE HARDCODEA, porque el diseno ya lo decidio. Diseno 5.4,
    marcada [decision del autor]:

        ability.onCatch = "kill"     -- Demon, Revenant, Oni, Hantu, Moroi...
        ability.onCatch = "banish"   -- Shade, Yurei, Phantom, Wraith, Goryo...

    Hoy ningun tipo trae `ability` ( `ghost_types.lua` es generado y su esquema no
    tiene el campo ), asi que el default es `kill`. El gancho existe desde el dia
    uno: si se hardcodea, hay que volver a abrir el cerebro.
]]

-- `banish` NO CAE A `kill`, y es una decision. Un default plausible en el lugar de
-- un mecanismo que no existe es un check verde sobre codigo que no se escribio --
-- este proyecto ya lo pago con un campo pisado que devolvia exactamente lo
-- esperado. Un tipo con `banish` tiene que verse SIN implementar, no verse como un
-- Demon.
function ENT:phantom_OnCatchMode()
    local t = self.phantom_Type

    return ( t and t.ability and t.ability.onCatch ) or "kill"

end

-- El desenlace. Devuelve true si el sujeto quedo efectivamente resuelto.
function ENT:phantom_Catch( victima )
    local st = stats( self )
    local modo = self:phantom_OnCatchMode()

    st.contactos = st.contactos + 1

    -- EL PUNTO DE INTERCEPCION ES PUBLICO, mismo molde que `TerminatorBlockUse` de
    -- server_doors.lua y que el `homeless_ScornOverride` de HIM: los eventos
    -- ( jumpscare, camara, sonido ) van a querer engancharse aca sin tocar esta
    -- funcion. Devolver true VETA el desenlace.
    if hook.Run( "PhantasmagoriaGhostCatch", self, victima, modo ) == true then
        st.tapados = st.tapados + 1
        return false

    end

    if modo ~= "kill" then
        st.banish = st.banish + 1

        if not PHANTASMAGORIA.avisoOnCatch then
            PHANTASMAGORIA.avisoOnCatch = true

            ErrorNoHalt( "[Phantasmagoria] ability.onCatch = '" .. tostring( modo ) .. "' TODAVIA NO ESTA " ..
                "IMPLEMENTADO ( Diseno 5.4 lo declara; solo 'kill' tiene codigo ). El fantasma alcanzo al " ..
                "jugador y NO le hizo nada, a proposito: caer a 'kill' seria hacer pasar un mecanismo " ..
                "inexistente por uno que anda.\n" )

        end

        return false

    end

    -- Con el fantasma como atacante Y como inflictor: asi la muerte se le atribuye
    -- a el en el kill feed, y los addons de gore que miran el atacante ( Visceral,
    -- Zippy's ) ven algo valido en vez de un dano del mundo.
    local dmg = DamageInfo()
    dmg:SetDamage( victima:Health() + math.max( victima:Armor(), 0 ) + 100 )
    dmg:SetAttacker( self )
    dmg:SetInflictor( self )
    dmg:SetDamageType( DMG_SLASH )
    dmg:SetDamagePosition( victima:GetPos() )

    victima:TakeDamageInfo( dmg )

    local murio = ( not IsValid( victima ) ) or ( not victima:Alive() ) or victima:Health() <= 0

    if murio then
        st.muertes = st.muertes + 1

    else
        -- ESTA RAMA ES LA QUE HACE QUE LA FILA SE PUEDA LEER. Un `TakeDamage` puede
        -- no matar por godmode, por buddha, o porque otro addon lo filtro, y desde
        -- afuera eso se ve IGUAL que "el contacto no disparo". Sin este contador,
        -- la fila "el contacto mata" tendria dos causas distintas con el mismo
        -- rojo.
        st.sinEfecto = st.sinEfecto + 1

    end

    return murio

end

-- El tick del contacto. Corre desde `ENT:BehaveUpdate` ( server.lua ), DESPUES del
-- BaseClass.
--
-- LA PARED SI TE SALVA Y EL PROP NO, y esta escrito asi a proposito:
-- `MASK_SOLID_BRUSHONLY` mira geometria de brushes, no props. Un fantasma que te
-- mata a traves de una pared es un bug; uno que no te mata porque hay una silla en
-- el medio es el mismo defecto que este bloque vino a arreglar. Los abortos por
-- trace se CUENTAN ( `cerca` sube y `contactos` no ), asi que "estuvo al lado y no
-- paso nada" deja de ser una impresion.
local trazaContacto = {
    mask = MASK_SOLID_BRUSHONLY,
}

function ENT:phantom_HuntContact( myTbl )
    myTbl = myTbl or self:GetTable()

    if not myTbl.phantom_Hunting then return end

    local enemy = myTbl.GetEnemy( self )
    if not IsValid( enemy ) then return end
    if not enemy:IsPlayer() then return end
    if not enemy:Alive() then return end

    -- Origen contra origen, EN VIVO. No se usa `myTbl.DistToEnemy` -- que seria
    -- gratis -- porque ese campo lo escribe la corrutina del enemy_handler y puede
    -- tener uno o dos ticks de atraso; a 300 u/s eso es medio alcance.
    local dist = self:GetPos():Distance( enemy:GetPos() )
    if dist > alcance() then return end

    local st = stats( self )
    st.cerca = st.cerca + 1

    -- ⚠⚠ EL CONTROL SE APAGA **DESPUES** DE CONTAR, Y ESE ORDEN ES EL QUE HACE
    -- QUE LA CONVAR SIRVA. La ayuda de `phantasmagoria_ghost_catch` promete
    -- separar *"no llega"* de *"llega y no mata"*; puesto arriba, el 0 dejaba
    -- `ticks a tiro` en cero y las dos cosas volvian a verse iguales -- o sea que
    -- el control negativo destruia el unico numero que lo hacia legible. Con el
    -- contador antes, la corrida de control dice `ticks a tiro 340 · disparados 0`,
    -- que es una medicion de que el fantasma SI llego.
    if not cvCatch:GetBool() then return end

    -- Un solo desenlace por segundo y por fantasma. Sin esto, un contacto que no
    -- mata ( godmode ) volveria a dispararse cada tick y llenaria la consola con el
    -- aviso de `banish` o con hooks de terceros.
    if ( myTbl.phantom_nextCatch or 0 ) > CurTime() then return end

    trazaContacto.start  = self:GetShootPos()
    trazaContacto.endpos = enemy:EyePos()
    trazaContacto.filter = { self, enemy }

    -- ⚠ Y EL ENFRIAMIENTO SE CONSUME DESPUES DEL TRACE, no antes. Una pared entre
    -- los dos no es un intento fallido: es un intento que no ocurrio, y gastarle
    -- el segundo lo volveria mas lento justo cuando salgas de atras de la pared.
    -- `parados` sube todos los ticks que estuviste a tiro con algo solido en el
    -- medio, que es lo que separa "la pared te salvo" de "el contacto no existe".
    if util.TraceLine( trazaContacto ).Hit then
        st.parados = st.parados + 1
        return

    end

    myTbl.phantom_nextCatch = CurTime() + 1

    self:phantom_Catch( enemy )

end

---------------------------------------------------------------------------
-- 8 · EL PERRO GUARDIAN
---------------------------------------------------------------------------
-- LO QUE VIGILA, y es el modo de falla mas caro de este bloque: un `StartTask` a
-- una tarea que no corre NO da error, da un ZOMBI. Entra igual en `m_ActiveTasks`
-- -- `IsTaskActive` dice que si y `term_debugtasks` la imprime -- pero `RunTask` la
-- saltea porque no encuentra sus callbacks ( taskoverride.lua:39-40 ). El bot se
-- queda parado, sin tarea de movimiento, en silencio y sin una linea en consola,
-- hasta que lo rescate `reallystuck_handler` -- que puede tardar decenas de
-- segundos.
--
-- El mismo agujero lo abre la trampa del desvio: si algun dia un sitio hiciera
-- `TaskComplete` y el destino ya estuviera activo, el `StartTask` no haria nada.
-- Los once sitios se leyeron y ninguno esta en ese caso, pero *"se reviso" no es
-- "no puede pasar"*.
--
-- NO ALCANZA CON DETECTARLO: TIENE QUE GRITAR. Un rescate silencioso convierte un
-- defecto en una intermitencia, y una intermitencia no se puede medir en una
-- planilla. Grita una vez por fantasma y por episodio, y el contador queda.
local SIN_TAREA_MAX = 1.5

local function tieneMovimiento( myTbl )
    local activas = myTbl.m_ActiveTasksNum
    if not activas then return false end

    for i = 1, #activas do
        local dat = activas[ i ]
        if not dat then break end

        if string.find( dat[ 1 ], "movement_", 1, true ) then return true end

    end

    return false

end

function ENT:phantom_HuntWatchdog( myTbl )
    myTbl = myTbl or self:GetTable()

    if tieneMovimiento( myTbl ) then
        myTbl.phantom_sinTareaDesde = nil
        myTbl.phantom_sinTareaAviso = nil
        return

    end

    local desde = myTbl.phantom_sinTareaDesde

    if not desde then
        myTbl.phantom_sinTareaDesde = CurTime()
        return

    end

    if CurTime() - desde < SIN_TAREA_MAX then return end

    local st = stats( self )
    st.sinTarea = st.sinTarea + 1

    if not myTbl.phantom_sinTareaAviso then
        myTbl.phantom_sinTareaAviso = true

        ErrorNoHalt( "[Phantasmagoria] el fantasma #" .. self:EntIndex() .. " lleva " ..
            string.format( "%.1f", CurTime() - desde ) .. " s SIN NINGUNA TAREA movement_*, que es el " ..
            "sintoma del zombi ( un StartTask que entro en m_ActiveTasks sin callbacks, o un desvio que " ..
            "cayo en el early-out de taskoverride.lua:167 ). Se lo rescata con movement_handler. " ..
            "Mirar el ultimo StartTask con term_debugtasks 1.\n" )

    end

    myTbl.phantom_sinTareaDesde = CurTime()

    self:StartTask( "movement_handler", nil, "phantasmagoria: rescate del perro guardian" )

end

-- Un solo enganche desde BehaveUpdate, para no pedirle dos llamadas a server.lua.
function ENT:phantom_HuntTick( myTbl )
    myTbl = myTbl or self:GetTable()

    myTbl.phantom_huntTicks = ( myTbl.phantom_huntTicks or 0 ) + 1

    -- ⚠ SE CREA LA TABLA DE CONTADORES ACA Y NO EN LOS CAMINOS CALIENTES.
    -- `GetWeaponRange` y `EnemyIsLethalInMelee` se llaman decenas de veces por
    -- segundo y solo INCREMENTAN si la tabla ya existe -- crearla ahi seria
    -- meterle una asignacion condicional a la ruta mas caliente del bot. Pero si
    -- nadie la creara hasta el primer desvio, el reporte diria "alcance 0 veces"
    -- sobre un fantasma al que la base le pregunto mil veces, y ese cero se lee
    -- como "el override no corre". Un tick de arranque cuesta nada y deja los
    -- contadores vivos desde el primer frame.
    stats( self )

    self:phantom_HuntContact( myTbl )
    self:phantom_HuntWatchdog( myTbl )

end

---------------------------------------------------------------------------
-- INSTRUMENTO
---------------------------------------------------------------------------
-- Todo lo de este archivo es invisible: un desvio no deja huella, una condicion
-- que no se cumplio tampoco, y `term_debugtasks 1` -- que es lo que uso el autor y
-- sigue siendo la mejor herramienta para ver el reparto -- avisa en su propio
-- banner que *"this enables some laggy debug trackers"*. Este comando dice lo mismo
-- sin lag, y ademas dice EN QUE ESTADO estan las perillas, que es la mitad que un
-- log de tareas no puede mostrar.
local function estadoPerilla( cv, siUno, siCero )
    return "  " .. string.format( "%-38s", cv:GetName() ) .. " = " .. cv:GetInt() ..
        "   " .. ( cv:GetBool() and siUno or siCero )

end

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_cerebro", function( ply )
    -- ⚠ EL `say` COMPARTIDO Y NO UNO PROPIO. `PrintMessage( HUD_PRINTCONSOLE )`
    -- corta en 255 bytes SIN AVISAR, y varias lineas de este reporte -- la de las
    -- perillas con su explicacion al lado, la de la compuerta con sus cuatro
    -- destinos -- pasan de ahi. Un `say` casero se veria bien en el `MsgN` del
    -- servidor y truncado en la consola del jugador, o sea que el mismo comando
    -- diria dos cosas distintas segun quien lo corra. `PHANTASMAGORIA.MakeSay`
    -- existe justamente porque este pozo ya se pago una vez.
    local say = PHANTASMAGORIA.MakeSay( ply )

    say( "" )
    say( "===== EL CEREBRO DEL HUNT ( el hunt directo, 2026-08-20 ) =====" )
    say( estadoPerilla( cvHuntDirect, "escalera propia + compuerta", "!! CONTROL: la escalera de la base entera" ) )
    say( estadoPerilla( cvTrueRange,  "dice su alcance real",        "!! CONTROL: math.huge, como la base" ) )
    say( estadoPerilla( cvFearless,   "no le teme a nadie",          "!! CONTROL: encadena; `god` cambia el bot" ) )
    say( estadoPerilla( cvReachProps, "un prop no lo hace desistir", "!! CONTROL: la mesa corta el duelo" ) )
    say( estadoPerilla( cvReachDrop,  "un pozo no lo hace desistir", "!! CONTROL: el salto corta el duelo" ) )
    say( estadoPerilla( cvCatch,      "el contacto mata",            "!! CONTROL: llega y no pasa nada" ) )
    say( "  " .. string.format( "%-38s", "phantasmagoria_ghost_reach" ) .. " = " .. alcance() .. " u" ..
        "   ( alcance de arma Y distancia del contacto: es el mismo numero )" )
    say( "  " .. string.format( "%-38s", "phantasmagoria_ghost_huntflank" ) .. " = " .. cvFlank:GetInt() .. " u" ..
        "   ( por debajo de esto se deja entrar movement_flankenemy )" )
    -- ⚠ `INFORM_RADIUS` y no `ENT.InformRadius`: ver el bloque del campo, arriba.
    -- Esta linea es la que mato al comando entero en la primera corrida.
    say( "  " .. string.format( "%-38s", "ENT.InformRadius" ) .. " = " .. INFORM_RADIUS ..
        "   ( la base trae 20000; en 0, followenemy deja de armar el path de 'split up!' )" )

    -- LA PRECONDICION QUE CONTAMINA LA MEDICION, ARRIBA DE LAS FILAS Y NO EN UNA
    -- NOTA AL PIE: con `fearless 0`, `EnemyIsUnkillable` mira `HasGodMode()`
    -- ( shared.lua:2720 ) y el bot pasa a tratarte como letal. O sea que testear
    -- con `god` puesto mide OTRO bot.
    if not cvFearless:GetBool() then
        local conGod = 0

        for _, p in ipairs( player.GetAll() ) do
            if p.HasGodMode and p:HasGodMode() then conGod = conGod + 1 end

        end

        if conGod > 0 then
            say( "" )
            say( "  !! " .. conGod .. " jugador(es) con GODMODE y phantasmagoria_ghost_fearless en 0:" )
            say( "     EnemyIsUnkillable ( shared.lua:2720 ) los da por letales y el bot cambia de" )
            say( "     comportamiento. Lo que se mida asi NO es lo que juega el jugador." )

        end
    end

    local vivos = PHANTASMAGORIA.EachGhost( function( ghost )
        local st = stats( ghost )
        local enemy = ghost:GetEnemy()

        say( "" )
        say( "  --- fantasma #" .. ghost:EntIndex() .. "/s" .. tostring( ghost.phantom_Serial or "?" ) ..
            "  ( " .. ( ghost.phantom_Hunting and "HUNT" or "calma" ) .. " )" ..
            "  onCatch " .. tostring( ghost:phantom_OnCatchMode() ) .. " ---" )

        if IsValid( enemy ) then
            local d = ghost:GetPos():Distance( enemy:GetPos() )

            say( "    enemigo   " .. tostring( enemy ) ..
                "  a " .. math.Round( d ) .. " u  ( ~" .. string.format( "%.1f", d / 39.3701 ) .. " m )" ..
                "   lo ve " .. ( ghost.IsSeeEnemy and "SI" or "NO" ) ..
                "   a tiro " .. ( d <= alcance() and "SI" or "NO" ) )

        else
            say( "    enemigo   ninguno" )

        end

        -- LA TAREA QUE DE VERDAD CORRE, y no la lista registrada. La diferencia ya
        -- costo una lectura equivocada en una sesion vieja -- se leyo "32 tareas"
        -- como "32 corriendo" y era falso.
        local corriendo = {}

        for _, dat in ipairs( ghost.m_ActiveTasksNum or {} ) do
            if not dat then break end
            corriendo[ #corriendo + 1 ] = dat[ 1 ]

        end

        say( "    corriendo " .. ( #corriendo > 0 and table.concat( corriendo, " · " ) or "!! NINGUNA" ) )

        -- ⚠ EL VALOR DE **ESTA** ENTIDAD, Y SOLO SI NO COINCIDE CON EL DE LA CLASE.
        -- La linea del panel de arriba dice lo que la CLASE declara; un `lua_run`
        -- sobre un fantasma vivo escribe en la ENTIDAD, y entonces el panel diria
        -- 0 mientras el bot anda con otro numero. Es exactamente el problema que
        -- `PHANTASMAGORIA.FlagOverrides` existe para resolver del otro lado, y ya
        -- costo una ronda entera en este addon: *el default de la clase y el valor
        -- del sujeto se leen igual y no son lo mismo.*
        if ( ghost.InformRadius or INFORM_RADIUS ) ~= INFORM_RADIUS then
            say( "              !! ESTA entidad tiene InformRadius " .. tostring( ghost.InformRadius ) ..
                ", no " .. INFORM_RADIUS .. ": alguien lo piso en la instancia y el panel de arriba" )
            say( "                 -- que lee la CLASE -- no lo puede ver. followenemy le vuelve a" )
            say( "                 armar el path de 'split up!' si hay otro fantasma cerca." )

        end

        say( "    escalera  ve " .. st.escaleraVe .. " · no ve " .. st.escaleraNoVe ..
            " · sin enemigo " .. st.escaleraSinEnemigo ..
            " · delegadas a la base " .. st.escaleraBase )

        say( "    compuerta vistas " .. st.vistas .. " · DESVIADAS " .. st.desvios ..
            " · dejadas pasar " .. st.dejadas ..
            "   ( -> follow " .. st.aFollow .. " · lastseen " .. st.aLastSeen ..
            " · search " .. st.aSearch .. " · flank de cerca " .. st.flanksCerca .. " )" )

        -- EL DENOMINADOR. `desvios 0` solo no distingue "la compuerta anda y la
        -- base no pidio nada tactico" de "la compuerta no corre".
        if st.vistas <= 0 then
            say( "              !! vistas EN CERO: la compuerta no se llamo ni una vez. O el fantasma" )
            say( "                 nunca entro en hunt, o ENT:StartTask ( server_stuck.lua ) dejo de" )
            say( "                 consultar phantom_HuntTaskGate." )

        end

        if next( st.porTarea ) then
            local partes = {}

            for tarea, n in SortedPairs( st.porTarea ) do
                partes[ #partes + 1 ] = tarea .. " x" .. n

            end

            say( "              desviadas por tarea: " .. table.concat( partes, " · " ) )

        end

        say( "    contacto  ticks a tiro " .. st.cerca ..
            " · tapados por una pared " .. st.parados ..
            " · disparados " .. st.contactos ..
            " · MATARON " .. st.muertes ..
            " · sin efecto " .. st.sinEfecto ..
            " · vetados por hook " .. st.tapados ..
            " · banish sin implementar " .. st.banish )

        -- Tres cuentas y no una, y cada par separa una causa distinta:
        --   cerca > 0 y contactos 0   -> lo tapo la pared del trace, o el enfriamiento
        --   contactos > 0 y muertes 0 -> pega y no mata ( godmode, buddha, hook )
        if st.cerca > 0 and st.contactos <= 0 then
            say( "              ( estuvo a tiro y no disparo. Con `catch 0` es el control y es lo" )
            say( "                esperado; con `catch 1` mirar `tapados por una pared`. En ningun" )
            say( "                caso quiere decir 'el contacto no existe': llego. )" )

        end

        -- ⚠ EL CADAVER DEL JUGADOR, Y VA ACA AUNQUE EL CAMPO SEA DE server.lua.
        -- Reportado en juego el 2026-08-20: al matarte, el hook global del
        -- tercero ( terminator_weapon_dropper.lua ) te crea hasta 6 armas en el
        -- piso a partir de tu inventario. Se apaga con `DontDropPrimary`, que
        -- cuelga de `phantasmagoria_ghost_pickup`.
        --
        -- Se imprime el CAMPO DE LA ENTIDAD y no la convar, y esa es la
        -- diferencia que hace que la linea sirva: el tercero lee el campo, asi
        -- que si la sincronizacion de `BehaveUpdate` dejara de correr, la convar
        -- seguiria diciendo 0 y el jugador seguiria soltando las armas. Un
        -- `true` aca es la unica prueba de que lo que decide llego a destino.
        local noSuelta = ghost.DontDropPrimary == true

        say( "    tu cadaver  " .. ( noSuelta and "CONSERVA tus armas" or "!! SUELTA tus armas" ) ..
            "   ( DontDropPrimary " .. tostring( ghost.DontDropPrimary ) ..
            ", sincronizado desde phantasmagoria_ghost_pickup )" )

        say( "    le contesto a la base:  alcance " .. st.rangePedidos .. " veces ( " .. st.rangeMentira ..
            " de ellas desarmado ) · miedo " .. st.miedoPedidos .. " veces" )
        say( "              props salvados " .. st.propsSalvados .. " · pozos salvados " .. st.pozosSalvados )

        say( "    perro     ticks " .. tostring( ghost.phantom_huntTicks or 0 ) ..
            " · episodios SIN tarea de movimiento " .. st.sinTarea ..
            " · cortes de tarea al cambiar de estado " .. st.rescates )

        -- Y ESTA ES LA GUARDA DE QUE EL TICK EXISTA. Si `BehaveUpdate` dejara de
        -- llamar a phantom_HuntTick, el contacto y el perro guardian quedarian
        -- muertos EN SILENCIO, y desde afuera se veria igual que un fantasma que
        -- nunca llego a tocarte.
        if ( ghost.phantom_huntTicks or 0 ) <= 0 then
            say( "              !! ticks EN CERO: ENT:BehaveUpdate ( server.lua ) NO esta llamando a" )
            say( "                 phantom_HuntTick. Sin eso no hay contacto ni perro guardian." )

        end
    end )

    if vivos <= 0 then
        say( "" )
        say( "  no hay ningun fantasma en el mapa." )

    end

end, "Estado del hunt directo: las perillas, la escalera propia, la compuerta de tareas y el contacto." )

---------------------------------------------------------------------------
-- GUARDAS DE CARGA
---------------------------------------------------------------------------
-- 1 · EL CUELLO DE `StartTask`. Este archivo NO declara `ENT:StartTask`: el dueno
--     unico es server_stuck.lua ( :1035 ), y un segundo `function ENT:StartTask`
--     aca no encadenaria, BORRARIA al primero -- que es la misma trampa que este
--     addon ya tiene escrita para `AdditionalThink` y para las claves de
--     `MyClassTask`. En vez de eso, aquel consulta `phantom_HuntTaskGate`. Esta
--     guarda comprueba el otro sentido: que el override siga existiendo y siga
--     siendo nuestro. Si alguien lo pisara, la compuerta se quedaria sin llamador
--     y el hunt volveria a la escalera de la base SIN UN SOLO ERROR.
if not isfunction( ENT.StartTask ) then
    ErrorNoHalt( "[Phantasmagoria] ENT:StartTask NO existe despues de incluir server_hunt.lua. " ..
        "Deberia venir de server_stuck.lua, que es su dueno unico y quien llama a phantom_HuntTaskGate. " ..
        "Sin el, las once puertas tacticas de la base quedan abiertas en hunt y el sintoma es " ..
        "'el hunt no cambio nada'.\n" )

else
    local fuente = debug.getinfo( ENT.StartTask, "S" )

    if fuente and not string.find( tostring( fuente.short_src ), "terminator_nextbot_phantom", 1, true ) then
        ErrorNoHalt( "[Phantasmagoria] ENT:StartTask viene de '" .. tostring( fuente.short_src ) ..
            "', que NO es de esta carpeta. La compuerta del hunt cuelga de nuestro override; con el " ..
            "pisado, el desvio de tareas no corre.\n" )

    end
end

-- 2 · LA PUERTA DEL ESTADO. `phantom_SetHunting` ( server.lua ) es la puerta unica
--     del flag y es la que tiene que llamar a `phantom_HuntSwitched`. Si esa
--     llamada desapareciera, prender el hunt dejaria de interrumpir la tarea en
--     curso -- que es exactamente el defecto que este bloque vino a cerrar -- y el
--     sintoma seria "a veces tarda en reaccionar", que es de los caros.
if not isfunction( ENT.phantom_SetHunting ) then
    ErrorNoHalt( "[Phantasmagoria] ENT:phantom_SetHunting NO existe: server_hunt.lua se incluyo antes " ..
        "que su declaracion en server.lua. El corte de la tarea en curso al prender el hunt no se va a " ..
        "enganchar.\n" )

end
