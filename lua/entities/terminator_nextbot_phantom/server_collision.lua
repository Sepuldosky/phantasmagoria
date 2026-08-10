--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom / LA NO-SOLIDEZ CONTRA SERES

    PEDIDO DEL AUTOR, literal ( r2 ): *"Puedes hacer que el fantasma no colisione
    contra jugadores y npcs? Que es bastante molesto y eso lo convierte
    directamente en un fantasma."*

    Son las DOS mitades de la misma frase y conviene no perder la segunda: no es
    solo que moleste chocarlo, es que **un fantasma que te bloquea el pasillo
    deja de ser un fantasma**. La mecanica de esconderse de Diseno 18 se apoya en
    que el bot te alcance o no te alcance; que ademas te EMPUJE es informacion
    que el juego no tendria que estar dando.

    ---------------------------------------------------------------------------
    LO QUE HAY HOY, MEDIDO ( y no es lo que uno supondria )
    ---------------------------------------------------------------------------

    El addon NO escribe el grupo de colision en ningun lado. Lo que la entidad
    usa lo pone la base en dos lineas contiguas de su Initialize:

      terminator_nextbot_base/init.lua:110   SetCollisionGroup( COLLISION_GROUP_PLAYER )
      terminator_nextbot_base/init.lua:111   SetSolidMask( ENT.SolidMask )   -- MASK_NPCSOLID, init.lua:68

    ⚠ MASCARA Y GRUPO NO SON LA MISMA PALANCA, y confundirlas es el error que
    este archivo existe para no cometer. `GetSolidMask()` entra como campo `mask`
    de las trazas que el bot hace de SU PROPIO movimiento ( 11 sitios en la base,
    todos como `mask =` ); o sea gobierna **contra que choca el fantasma**, no
    **quien choca contra el fantasma**. Por eso el atravesado de puertas que ya
    existe ( server_doors.lua:624 / :635, unico escritor de solidez del addon )
    es unidireccional y NO resuelve este pedido: el jugador te sigue chocando.

    ---------------------------------------------------------------------------
    POR QUE **NO** SE CAMBIA EL GRUPO DE COLISION, que es la opcion obvia
    ---------------------------------------------------------------------------

    El wraith de la base hace exactamente eso ( wraithcloaking.lua:131-135:
    COLLISION_GROUP_DEBRIS + SetNotSolid ), asi que el precedente existe y es
    tentador. Se descarto por cuatro motivos, tres medidos y uno que no se pudo
    medir -- y el que no se pudo medir es el que decide:

      ( 1 ) EL GRUPO SE LEE EN NUEVE TRAZAS DE LA BASE. `GetCollisionGroup()`
            alimenta `collisiongroup =` en motionoverrides.lua:291, :940, :1036,
            :1289, :1360, :1569, :2920, footsteps.lua:256 y
            sh_terminator_funcs.lua:98. Cambiarlo mueve el StuckCheck, el sonido
            de pasos y los ~40 call sites de PosCanSeeComplex a la vez. Un
            cambio de una linea con nueve consumidores no es un cambio de una
            linea.

      ( 2 ) SE LLEVA PUESTOS LOS PROPS, QUE EL AUTOR NO PIDIO. Lo unico medido en
            este taller sobre la familia DEBRIS es
            `dev/trepang_slide_fix/CAMBIOS.md:1170` sobre
            COLLISION_GROUP_DEBRIS_TRIGGER -- *"choca contra el mundo y contra
            triggers, y contra nada mas: ni vehiculos, ni props, ni jugadores"* --
            y se descubrio EN JUEGO porque un auto atravesaba un cuerpo. Un
            fantasma que ademas atraviesa las cajas pierde el `throw`, que es la
            categoria insignia del Poltergeist.

      ( 3 ) ROMPE LA REGLA DE DUENO UNICO QUE EL ADDON SE PUSO POR ESCRITO
            ( shared.lua:23-26 y server_cloak.lua:260-261 ): la solidez la
            escribe server_doors.lua y nadie mas. Este archivo la respeta -- NO
            toca ni el grupo ni la mascara.

      ( 4 ) ⚠⚠ Y NO SE PUDO MEDIR SI LAS BALAS SIGUEN PEGANDO. La regla vive en
            `CGameRules::ShouldCollide`, que es C++, y no esta en ninguno de los
            153 `.lua` de los cuatro arboles del taller. **El fantasma tiene que
            seguir siendo matable**, y esa es justo la propiedad que el camino
            del grupo deja sin garantia. *Cuando una opcion apuesta la unica
            propiedad que no se puede equivocar, se elige la otra.*

    ---------------------------------------------------------------------------
    LO QUE SE HACE: `GM:ShouldCollide`, que no toca ninguna de las dos palancas
    ---------------------------------------------------------------------------

    Un hook que dice, por par de entidades, si esas dos chocan. No cambia grupo,
    no cambia mascara, no cambia solidez: el fantasma sigue siendo
    COLLISION_GROUP_PLAYER y las nueve trazas de la base siguen devolviendo lo
    mismo que hoy.

    ⚠⚠ Y LA MITAD QUE **NO** ESTA MEDIDA, DICHA DE FRENTE, PORQUE DECIDE SI ESTO
    FUNCIONA: `GM:ShouldCollide` solo se llama si alguna de las dos entidades
    tiene `SetCustomCollisionCheck( true )`, y **sobre CUAL de las dos hay que
    ponerla es una pregunta de API del engine que no esta medida en el taller**.
    El unico precedente vivo -- HIM, `sh_zdmghealth_autorun.lua:826-832` -- la
    pone sobre el JUGADOR, no sobre el nextbot ( y ese hook de HIM no tiene nada
    que ver con su bot: es para su lista `excommunicadees` ).

    Por eso hay DOS perillas y no una, y la segunda existe para separar lo que la
    primera no puede: `..._nocollide` marca al FANTASMA, `..._nocollide_ply`
    marca ademas a los JUGADORES. Las dos arrancan encendidas -- que es la unica
    configuracion que no puede fallar por este motivo -- y la planilla de la r3
    tiene una fila que apaga la segunda y vuelve a probar. *Dos condiciones
    encendidas a la vez es un criterio que se cumple a medias y se lee como
    cumplido ( catalogo nº 28 ); apagarlas de a una en la MISMA ronda cuesta un
    comando y lo separa.*

    ---------------------------------------------------------------------------
    EL SEGUNDO MECANISMO, QUE UN HOOK DE COLISION **NO** GOBIERNA
    ---------------------------------------------------------------------------

    `ENT:PhysicallyPushEnt` ( motionoverrides.lua:209-219 ) no es una colision:
    es un `ApplyForceOffset` explicito sobre el physobj del blanco. Y la base lo
    llama SIN FILTRAR POR TIPO sobre cualquier cosa que toque su hull en el
    chequeo de atasco -- `myTbl.PhysicallyPushEnt( self, hitEnt, 15000 )`,
    motionoverrides.lua:301 -- mas un empujon de 250 en enemyoverrides.lua:1730.
    Son sus DOS unicos call sites ( 3 hits en 153 archivos: 1 definicion + 2
    llamadas; cero en phantasmagoria y cero en HIM ).

    ⚠ HONESTIDAD SOBRE ESTE: **no esta medido que mover a un jugador por su
    physobj lo desplace** -- en Source el movimiento del jugador lo resuelve
    gamemovement y no VPhysics --, asi que este override puede estar apagando
    algo que no molestaba. Se hace igual porque cuesta seis lineas y **saca un
    candidato de la mesa**: si despues del cambio el fantasma sigue empujando,
    el mecanismo es otro y no hay que volver a discutir este. *Cuando hay tres
    mecanismos posibles y se arregla uno, el resultado no se puede leer.*

    El tercero -- la sombra fisica de masa 85 ( motion.lua:376-379 ) -- se deja
    intacto y se declara: si la fila 01 de la planilla sale ROJA con el contador
    del hook subiendo, ese es el sospechoso que queda.

    ---------------------------------------------------------------------------
    QUE MIDE ESTE ARCHIVO, Y POR QUE EL DENOMINADOR ES LA MITAD DEL INSTRUMENTO
    ---------------------------------------------------------------------------

    "El fantasma no me choco" es un no-evento: se ve exactamente igual si el
    mecanismo anda, si el hook nunca se llamo, o si simplemente no me le cruce.
    Por eso el contador tiene TRES cuentas y no una:

      llamadas   cuantas veces el engine llamo al hook, con fantasma o sin el.
                 Si esto es 0, `SetCustomCollisionCheck` no esta surtiendo
                 efecto y NADA de lo de abajo puede haber pasado.
      conFantasma cuantas de esas involucraban a un fantasma.
      atravesado  cuantas devolvieron false, desglosado por jugador / NPC /
                 nextbot.

    *Un cero sin su denominador de lecturas no es un resultado* -- catalogo nº 5,
    pagado en este mismo repo.
---------------------------------------------------------------------------]]

---------------------------------------------------------------------------
-- LAS PERILLAS
---------------------------------------------------------------------------
-- ⚠ TRES ESTADOS Y LOS TRES SIGNIFICAN ALGO DISTINTO. No es la convencion de
-- ResolveFlag ( 0 control / 1 el rasgo decide / 2 forzado ) porque aca no hay
-- rasgo por tipo: es la de phantasmagoria_ghost_absence, que ya usa 0/1/2 con
-- significados propios.
--
-- El 0 no es "apagado": es el CONTROL NEGATIVO, o sea el comportamiento exacto
-- de la r2, y es lo unico que prueba que el mecanismo nuevo es el que decide.
-- Sin el, "el fantasma no me choca" podria ser cualquier otra cosa.
local cvNoCol = CreateConVar( "phantasmagoria_ghost_nocollide", "1", FCVAR_ARCHIVE,
    "El fantasma ATRAVIESA a los seres vivos ( pedido del autor, r2 ). " ..
    "0 = CONTROL, colisiona como en la r2 · 1 = atraviesa jugadores, NPCs y otros nextbots · " ..
    "2 = atraviesa SOLO jugadores ( los NPCs lo siguen chocando ).", 0, 2 )

-- ⚠ ESTA EXISTE PORQUE NO SE MIDIO SOBRE QUE ENTIDAD HAY QUE PONER LA BANDERA.
-- Ver el encabezado. Marcar tambien a los jugadores no cambia el comportamiento
-- de nadie por si mismo -- el hook devuelve nil ( "decidi vos" ) para todo par
-- que no tenga un fantasma adentro -- pero hace que el engine consulte el hook
-- tambien cuando el que se mueve es el jugador.
--
-- Se restaura a false al apagarla, y eso NO es cortesia: dejar la bandera
-- puesta en un jugador despues de apagar la perilla haria que el control
-- negativo ( 0 ) no fuera un control.
local cvNoColPly = CreateConVar( "phantasmagoria_ghost_nocollide_ply", "1", FCVAR_ARCHIVE,
    "Marcar TAMBIEN a los jugadores con SetCustomCollisionCheck. Existe porque no esta medido " ..
    "sobre cual de las dos entidades del par hace falta la bandera para que GM:ShouldCollide " ..
    "se llame. 0 = solo el fantasma lleva la marca · 1 = el fantasma y los jugadores.", 0, 1 )

---------------------------------------------------------------------------
-- LOS CONTADORES
---------------------------------------------------------------------------
-- Globales y NO por entidad, a proposito: el hook recibe pares y no siempre hay
-- un fantasma del que colgarlos; y ademas este repo ya pago que un contador que
-- vive en la entidad **se muere con ella** ( la r23, el censo de hijos ), asi que
-- el numero que el operador lee puede ser de otro sujeto.
PHANTASMAGORIA.ColStats = PHANTASMAGORIA.ColStats or {
    llamadas    = 0,   -- el DENOMINADOR: cuantas veces corrio el hook, con fantasma o sin el
    conFantasma = 0,
    ply         = 0,
    npc         = 0,
    bot         = 0,
    ultimoT     = nil, -- sin esto, un contador monotono no dice si SIGUE corriendo
    -- ⚠ ACA VIVIAN `marcados` y `marcadosPly` y se fueron en la r3. No sobraban
    -- por prolijidad: eran CONTADORES de una propiedad que se puede LEER, y por
    -- eso mentian. El de jugadores solo lo escribia el camino de la perilla, asi
    -- que con el mecanismo andando marcaba 0; el de fantasmas mezclaba un
    -- acumulador de sesion con una foto de vivos en el mismo campo. Hoy los dos
    -- salen de recorrer el estado ( `PhantasmagoriaMarcado` ) al imprimir.
    -- *Si la propiedad se puede leer, no se cuenta.*
}

local function esSer( ent )
    if ent:IsPlayer() then return "ply" end
    if ent:IsNPC() then return "npc" end

    -- ⚠ UN NEXTBOT NO ES UN NPC PARA `IsNPC()`, y eso incluye a los OTROS
    -- FANTASMAS. Sin esta rama, dos fantasmas en el mismo cuarto se chocan entre
    -- ellos -- que es lo mismo que el autor reporto, con otro sujeto.
    if ent:IsNextBot() then return "bot" end

    return nil

end

---------------------------------------------------------------------------
-- EL HOOK
---------------------------------------------------------------------------
-- ⚠ DEVUELVE nil Y NO true PARA LOS PARES QUE NO NOS INTERESAN. `false` prohibe
-- la colision; `true` la FUERZA, y forzarla es una decision sobre pares ajenos
-- que no tenemos por que tomar -- pisaria a cualquier otro addon que tenga su
-- propio ShouldCollide. `nil` es "no opino", que es lo unico correcto acá.
hook.Add( "ShouldCollide", "phantasmagoria_ghost_nocollide", function( a, b )
    local st = PHANTASMAGORIA.ColStats

    st.llamadas = st.llamadas + 1
    st.ultimoT  = CurTime()

    local modo = cvNoCol:GetInt()
    if modo == 0 then return end

    if not IsValid( a ) or not IsValid( b ) then return end

    -- Cual de los dos es el fantasma. El hook no garantiza el orden.
    local ghost, otro

    if a.IsPhantasmagoriaGhost then ghost, otro = a, b
    elseif b.IsPhantasmagoriaGhost then ghost, otro = b, a
    else return end

    st.conFantasma = st.conFantasma + 1

    local que = esSer( otro )
    if not que then return end

    -- El modo 2 deja a los NPCs y a los nextbots chocando. Existe para el A/B:
    -- si el fantasma atraviesa jugadores y sigue trabandose contra un NPC, la
    -- causa esta en otro lado y este mecanismo queda descartado.
    if modo == 2 and que ~= "ply" then return end

    st[ que ] = st[ que ] + 1

    return false

end )

---------------------------------------------------------------------------
-- LA BANDERA
---------------------------------------------------------------------------
-- ⚠⚠ NO SE DECLARA `ENT:AdditionalInitialize` ACA, Y ES LA MISMA TRAMPA QUE
-- server_events.lua documenta para `AdditionalThink`: server.lua:837 ya la
-- define, y un archivo que la vuelva a declarar **no encadena, BORRA** -- se
-- llevaria puestos el serial, el hull, el FOV y la eleccion de tipo, sin un solo
-- error de Lua. El sintoma seria un fantasma sin tipo y con el hull de la base.
--
-- `OnEntityCreated` con un `timer.Simple( 0 )` es el patron seguro: la entidad
-- todavia no corrio su Initialize cuando el hook dispara, y el campo
-- IsPhantasmagoriaGhost viene de la CLASE, asi que ya esta.
local function marcar( ent )
    if not IsValid( ent ) then return end
    if not ent.IsPhantasmagoriaGhost then return end

    local quiere = cvNoCol:GetInt() ~= 0

    ent:SetCustomCollisionCheck( quiere )

    -- ⚠ EL CAMPO PROPIO EXISTE PARA PODER LEER EL ESTADO DESPUES, y no es
    -- decorativo: `SetCustomCollisionCheck` no tiene getter, asi que sin esto la
    -- unica forma de "saber" si un fantasma esta marcado es un contador -- y un
    -- contador solo sabe de los caminos que lo incrementan. Ver el bloque del
    -- reporte: la r3 se llevo una fila que no discriminaba justamente por eso.
    ent.PhantasmagoriaMarcado = quiere or nil

    return quiere

end

hook.Add( "OnEntityCreated", "phantasmagoria_ghost_nocollide", function( ent )
    if not IsValid( ent ) then return end
    if not ent.IsPhantasmagoriaGhost then return end

    -- El conteo NO se lleva mas en un contador: lo lee el reporte del estado vivo
    -- ( `PhantasmagoriaMarcado`, que `marcar` deja puesto ). Un acumulador aca y
    -- un pisado en `reaplicar` eran DOS semanticas en un campo, y por eso el
    -- mismo renglon decia "5 de ?" en una corrida y "1 de 1" en la siguiente.
    timer.Simple( 0, function()
        marcar( ent )
    end )
end )

-- ⚠⚠ NO SE ESCRIBE `false` A CIEGAS SOBRE UN JUGADOR, Y ES UN ARREGLO DE LA
-- REVISION. La primera version hacia
-- `ply:SetCustomCollisionCheck( <lo que queremos> )` en cada `PlayerSpawn`, o
-- sea una escritura ABSOLUTA, sin leer lo que habia. Eso **le pisa la bandera a
-- cualquier otro addon que la use**, y en este mismo taller hay uno: HIM la pone
-- sobre el jugador para su lista `excommunicadees`
-- ( sh_zdmghealth_autorun.lua:826 ). Al segundo respawn, su mecanica se apaga
-- sin un error y sin que nadie relacione las dos cosas.
--
-- La regla: **solo apagamos lo que nosotros prendimos**. El campo propio es la
-- unica forma de saberlo -- la bandera del engine no dice quien la escribio.
local function marcarPly( ply )
    if not IsValid( ply ) then return end

    local quiere = cvNoCol:GetInt() ~= 0 and cvNoColPly:GetBool()

    if quiere then
        ply.PhantasmagoriaMarcado = true
        ply:SetCustomCollisionCheck( true )

    elseif ply.PhantasmagoriaMarcado then
        ply.PhantasmagoriaMarcado = nil
        ply:SetCustomCollisionCheck( false )

    end

    return quiere

end

-- ⚠⚠⚠ `marcarPly` NO SE CUELGA DIRECTO DEL HOOK, Y ESA FUE LA FALLA MAS CARA
-- DE ESTE ARCO. Su `return quiere` existe porque `reaplicar` lo consume
-- ( :349 ), pero como CALLBACK ese valor lo lee `hook.Call`, y la fuente del
-- engine en disco dice ( garrysmod/lua/includes/modules/hook.lua, `Call` ):
--
--     if ( a != nil ) then return a, b, c, d, e, f end
--     ...
--     return GamemodeFunction( gm, ... )     -- <-- NUNCA SE LLEGA
--
-- O sea que un hook que devuelve algo **se saltea `GM:PlayerSpawn` entero**, y
-- `GM:PlayerSpawn` ( gamemodes/base/gamemode/player.lua:229-259 ) es el UNICO
-- que llama a `hook.Call( "PlayerLoadout" )`, a `hook.Call( "PlayerSetModel" )`
-- y a `pl:SetupHands()`. Medido: el jugador aparecia SIN PLAYERMODEL, sin
-- loadout y sin manos, y Cargo se quedaba sin su `PlayerLoadout` -- o sea sin
-- el gate `ready` del espejo de municion, que es lo mismo que "el cinturon no
-- baja" y "no se puede hacer unload" vistos por dos lados.
--
-- Y LA TRAMPA DE ARRIBA DE ESA: **`false` TAMPOCO ES `nil`**. Con las dos
-- perillas en 0 `quiere` vale `false`, el `!= nil` da verdadero igual y la
-- cadena se corta lo mismo. Las dos perillas que este bloque publica como
-- control negativo **no apagaban el defecto**: habrian absuelto al archivo
-- culpable. Un control que solo puede dar verde es el nº 42 del catalogo.
--
-- La envoltura es el mismo idiom que `OnEntityCreated` ya usa acá arriba: el
-- closure se queda con el booleano y le devuelve `nil` a la cadena.
hook.Add( "PlayerInitialSpawn", "phantasmagoria_ghost_nocollide", function( ply )
    marcarPly( ply )
end )

-- ⚠ TAMBIEN EN CADA SPAWN, y no solo en el inicial. No esta medido si un
-- jugador conserva la bandera al respawnear, y la diferencia entre "no la
-- conserva" y "el mecanismo no anda" no se puede ver desde el juego.
hook.Add( "PlayerSpawn", "phantasmagoria_ghost_nocollide", function( ply )
    marcarPly( ply )
end )

---------------------------------------------------------------------------
-- LAS PERILLAS ALCANZAN A LOS QUE YA EXISTEN
---------------------------------------------------------------------------
-- ⚠ CATALOGO Nº 26, PAGADO EN ESTE REPO: una perilla que gobierna un valor
-- CACHEADO EN LA ENTIDAD y solo se escribe al crearla **no hace nada con
-- sujetos ya vivos**, y eso se lee como "el control no funciona" o -- peor --
-- como "el mecanismo no existe", que es la conclusion inversa.
--
-- Y DICE EL NUMERO, INCLUIDO EL 0: *"no habia sujetos"* y *"no se re-aplico"*
-- se ven igual en una consola muda, y la primera es una precondicion sin
-- cumplir mientras la segunda es un defecto.
-- ⚠ SE CUENTAN LOS QUE QUEDARON MARCADOS, NO LOS QUE SE RECORRIERON, y no es lo
-- mismo: con la perilla en 0 la primera version escribia `marcados = N` sobre N
-- sujetos a los que les acababa de poner la bandera en **false**. El reporte
-- decia *"marcados 3 fantasma(s)"* con el mecanismo apagado. *Un contador que
-- lleva el nombre de una accion tiene que contar la accion, no las vueltas del
-- bucle.*
--
-- Y se imprimen los DOS numeros -- marcados y recorridos -- porque `0 de 0`
-- ( no habia sujetos ) y `0 de 3` ( habia y quedaron sin marcar ) son dos
-- estados distintos, y el primero es una precondicion sin cumplir mientras el
-- segundo seria un defecto.
local function reaplicar( cual )
    local nG, nP, mG, mP = 0, 0, 0, 0

    if isfunction( PHANTASMAGORIA.EachGhost ) then
        PHANTASMAGORIA.EachGhost( function( ghost )
            nG = nG + 1
            if marcar( ghost ) then mG = mG + 1 end

        end )
    end

    for _, ply in ipairs( player.GetAll() ) do
        nP = nP + 1
        if marcarPly( ply ) then mP = mP + 1 end

    end

    -- Los cuatro numeros NO se guardan en `ColStats`: se imprimen acá y se
    -- acabaron. Guardarlos era lo que hacia que el reporte mostrara la foto de
    -- la ULTIMA vez que se movio una perilla en vez del estado de ahora.
    MsgC( Color( 190, 120, 255 ), "[Phantasmagoria] ", color_white,
        cual, ": marca de colision aplicada a ", mG, " de ", nG, " fantasma(s) y ",
        mP, " de ", nP, " jugador(es).\n" )

end

cvars.AddChangeCallback( "phantasmagoria_ghost_nocollide", function( _, viejo, nuevo )
    reaplicar( "phantasmagoria_ghost_nocollide " .. tostring( viejo ) .. " -> " .. tostring( nuevo ) )

end, "phantasmagoria_ghost_nocollide" )

cvars.AddChangeCallback( "phantasmagoria_ghost_nocollide_ply", function( _, viejo, nuevo )
    reaplicar( "phantasmagoria_ghost_nocollide_ply " .. tostring( viejo ) .. " -> " .. tostring( nuevo ) )

end, "phantasmagoria_ghost_nocollide_ply" )

---------------------------------------------------------------------------
-- EL EMPUJON EXPLICITO DE LA BASE
---------------------------------------------------------------------------
-- La base llama a esto sobre CUALQUIER cosa que toque su hull, sin mirar de que
-- clase es ( motionoverrides.lua:299-303 ). No es una colision, asi que el hook
-- de arriba no lo gobierna: hay que interceptarlo aparte.
--
-- ⚠ ENCADENA AL BaseClass PARA TODO LO DEMAS, y eso es lo que mantiene vivo el
-- que el fantasma pueda apartar una caja de un empujon. Un override que
-- devuelva sin llamar al padre apagaria la funcion entera -- que es "saltear no
-- es apagar" al reves, y le costaria al fantasma un comportamiento que nadie
-- pidio sacar.
--
-- La firma la copia tal cual de la base ( motionoverrides.lua:209 ) porque el
-- segundo argumento es la FUERZA y los dos call sites pasan numeros distintos
-- ( 15000 y 250 ). Tragarse ese argumento seria el defecto nº 31 del catalogo:
-- *un valor de retorno no tiene un tipo, tiene un tipo por sitio de llamada.*
--
-- ⚠ SE ENCADENA POR `self.BaseClass` Y NO POR EL LOCAL `BaseClass`. El
-- `DEFINE_BASECLASS` de shared.lua:52 declara un LOCAL, y un `include()` abre un
-- chunk nuevo: desde aca ese nombre es una GLOBAL que vale nil, y la llamada
-- tiraria `attempt to index a nil value` en el primer atasco -- adentro del
-- StuckCheck de la base. Los diez overrides que ya tiene el addon usan
-- `self.BaseClass` / `myTbl.BaseClass` justamente por esto.
function ENT:PhysicallyPushEnt( ent, strength )
    if cvNoCol:GetInt() ~= 0 and IsValid( ent ) then
        local que = esSer( ent )

        -- Mismo criterio que el hook, y a proposito: si los dos no leyeran la
        -- misma regla, el modo 2 dejaria de significar lo mismo en los dos
        -- lugares y el A/B mediria dos mecanismos mezclados.
        if que and not ( cvNoCol:GetInt() == 2 and que ~= "ply" ) then
            PHANTASMAGORIA.ColStats.empujones = ( PHANTASMAGORIA.ColStats.empujones or 0 ) + 1
            return

        end
    end

    -- La guarda del padre, igual que en los otros overrides del addon
    -- ( server.lua:293, :411, :1911 ): si la base cambiara de nombre esta
    -- funcion, un indexado a pelo reventaria en el StuckCheck y el sintoma
    -- seria un fantasma que se traba, no un error legible.
    local base = self.BaseClass and self.BaseClass.PhysicallyPushEnt
    if isfunction( base ) then return base( self, ent, strength ) end

end

---------------------------------------------------------------------------
-- INSTRUMENTO
---------------------------------------------------------------------------
-- ⚠ NO SE LLAMA IGUAL QUE NINGUNA CONVAR. La guarda de PHANTASMAGORIA.AddCommand
-- ( server.lua:1023 ) grita si alguien lo intenta: una convar y un concommand
-- homonimos se resuelven a favor de la convar y el comando queda MUDO, que ya
-- costo dos filas de una planilla en la ronda 2 de puertas.
PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_solidez", function( ply )
    if IsValid( ply ) and not ply:IsAdmin() then
        ply:PrintMessage( HUD_PRINTCONSOLE, "[Phantasmagoria] hace falta ser admin." )
        return

    end

    local say = PHANTASMAGORIA.MakeSay( ply )
    local st  = PHANTASMAGORIA.ColStats

    say( "" )
    say( "===== SOLIDEZ CONTRA SERES ( pedido del autor, r2 ) =====" )
    say( "  phantasmagoria_ghost_nocollide     = " .. cvNoCol:GetInt() ..
        ( cvNoCol:GetInt() == 0 and "  ( CONTROL: colisiona como en la r2 )"
          or cvNoCol:GetInt() == 1 and "  ( atraviesa jugadores, NPCs y nextbots )"
          or "  ( atraviesa SOLO jugadores )" ) )
    say( "  phantasmagoria_ghost_nocollide_ply = " .. cvNoColPly:GetInt() ..
        ( cvNoColPly:GetBool() and "  ( la marca va en el fantasma Y en los jugadores )"
          or "  ( la marca va SOLO en el fantasma )" ) )
    -- ⚠⚠ ESTA LINEA SE LEE DEL ESTADO VIVO Y ANTES SE LEIA DE UN CONTADOR. La r3
    -- lo pago con una fila entera: `ColStats.marcadosPly` lo escribia SOLO
    -- `reaplicar` ( o sea el camino de la perilla ), y el camino del hook
    -- --`marcarPly` en PlayerSpawn, que es el normal-- no lo tocaba nunca. Asi
    -- que con la perilla EN 1 y el mecanismo andando el reporte decia
    -- `0 de ? jugador(es)`, **la misma lectura** que con la perilla en 0. La fila
    -- 02 usaba justamente ese renglon como criterio de su A/B: no podia
    -- distinguir sus dos mitades ni en principio.
    --
    -- El `?` del denominador era el mismo defecto: `vistosPly` tampoco existia
    -- hasta que corriera `reaplicar`. *Un contador solo sabe de los caminos que
    -- lo incrementan; el estado sabe de todos.* Familia "el instrumento que
    -- NOMBRA" del catalogo -- se llamaba `marcados` y contaba `re-aplicados`.
    local mG, nG, mP, nP = 0, 0, 0, 0
    if isfunction( PHANTASMAGORIA.EachGhost ) then
        PHANTASMAGORIA.EachGhost( function( ghost )
            nG = nG + 1
            if ghost.PhantasmagoriaMarcado then mG = mG + 1 end

        end )
    end
    for _, ply in ipairs( player.GetAll() ) do
        nP = nP + 1
        if ply.PhantasmagoriaMarcado then mP = mP + 1 end

    end

    say( "  marcados    " .. mG .. " de " .. nG .. " fantasma(s) · " ..
        mP .. " de " .. nP .. " jugador(es)" ..
        "   ( LEIDO DEL ESTADO VIVO, no de un contador: vale para los dos caminos" ..
        ", el del spawn y el de la perilla )" )
    say( "" )

    -- ⚠⚠ ESTE ES EL RENGLON QUE DECIDE, Y VA PRIMERO. Si `llamadas` es 0, el
    -- engine no esta consultando el hook y NINGUN numero de abajo puede haber
    -- pasado: el mecanismo no esta en juego y la fila no mide la colision, mide
    -- que SetCustomCollisionCheck no surtio efecto. Son dos rojos distintos y
    -- llevan a dos arreglos distintos.
    local desde = st.ultimoT and ( CurTime() - st.ultimoT ) or nil

    -- ⚠ ESTE NUMERO NO ES *NUESTRO* DENOMINADOR, Y HAY QUE DECIRLO. `ShouldCollide`
    -- es un hook GLOBAL del gamemode: lo dispara cualquier par que tenga la
    -- bandera, la haya puesto quien la haya puesto -- y en este taller hay
    -- terceros que la usan ( HIM sobre jugadores ). O sea que un numero grande
    -- prueba que el engine consulta el hook, y NO prueba que consulte por
    -- nosotros. Para eso esta el renglon de abajo. *Un denominador prestado
    -- infla el verde del numerador.*
    say( "  llamadas al hook  " .. st.llamadas ..
        "   ( TODO par que el engine consulte, tambien los de otros addons )" ..
        ( st.llamadas <= 0
          and "   !! CERO: el engine NO esta consultando GM:ShouldCollide. Con esto, nada de abajo corrio."
          or ( "   ( la ultima hace " .. ( desde and string.format( "%.1f", desde ) or "?" ) .. " s )" ) ) )
    say( "  de esas, con un fantasma adentro  " .. st.conFantasma ..
        ( ( st.llamadas > 0 and st.conFantasma <= 0 )
          and "   !! el hook corre pero NUNCA vio un fantasma: o no te le cruzaste, o la marca no esta puesta"
          or "" ) )
    say( "" )
    say( "  ATRAVESADO ( el hook devolvio false )" )
    say( "    jugadores  " .. st.ply )
    say( "    NPCs       " .. st.npc )
    say( "    nextbots   " .. st.bot .. "   ( incluye a los OTROS fantasmas )" )
    say( "    empujones vetados  " .. ( st.empujones or 0 ) ..
        "   ( PhysicallyPushEnt de la base, que NO es una colision y el hook no gobierna )" )
    say( "" )
    say( "  ⚠ lo que este comando NO puede decir: si te sigue empujando la SOMBRA FISICA" )
    say( "    ( PhysicsInitShadow masa 85, terminator_nextbot_base/motion.lua:376 ). Si los tres" )
    say( "    contadores de arriba suben y el fantasma te sigue frenando, ese es el sospechoso" )
    say( "    que queda -- y NO se toco en esta ronda a proposito." )

end, "Estado de la no-solidez contra jugadores y NPCs ( Diseno 22 )." )
