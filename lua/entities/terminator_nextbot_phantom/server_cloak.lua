--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom / LA AUSENCIA

    Diseno 20, tajada ①. Fuera del hunt el fantasma NO SE VE. Sigue caminando,
    abriendo puertas, dejando huellas y disparando eventos: lo unico que cambia
    es que no se dibuja.

    LAS TRES INVISIBILIDADES DE DISENO 20 SON DISTINTAS Y ESTA ES SOLO LA
    PRIMERA:

      ①  LA AUSENCIA   fuera del hunt, minutos              <-- este archivo
      ②  EL PARPADEO   durante el hunt, DECIMAS de segundo  Diseno 20.6, sin escribir
      ③  LOS EVENTOS   manifestarse unos segundos           Diseno 7, otro bloque

    ⚠ LO QUE ESTE ARCHIVO NO TOCA, Y ES LA DECISION ENTERA DEL BLOQUE: LA
    SOLIDEZ. El fantasma ausente sigue siendo solido. El dueno unico de la
    solidez es server_doors.lua ( phantom_SetPhasing, con su techo de 5 s y su
    vigilante ), y este archivo no le disputa la maquina.

    POR QUE NO SE USA EL CLOAK DE LA BASE ( ENT.IsWraith ), que era lo que
    PHANTOM_Referencia.md §11 recomendaba. Medido sobre wraithcloaking.lua, y
    NO son los cooldowns:

      · el reloj wraithTerm_NextHidingSwap tiene UN SOLO LECTOR ( :128, en la
        misma funcion que lo escribe ). Pisarlo seria seguro: no es el problema.

      · el material de invisibilidad NUNCA SE APLICA SI EL BOT ES SOLIDO.
        CloakedMatFlicker difiere el material de verdad a un
        timer.Simple( 0.65-0.75 ) que arranca con `if self:IsSolid() then
        return end` ( :99 ). Un fantasma solido y "cloakeado" queda a medio ver
        para siempre, sin error y sin log.

      · el UNHIDE escribe la solidez SIN consultar NotSolidWhenCloaked
        ( :172-173 ) mientras el HIDE si la consulta ( :131 ). O sea que apagar
        la bandera NO apaga la escritura, y esa escritura pelea contra
        phantom_SetPhasing por la misma mascara, sin arbitro y en silencio.

    *Heredado y gratis no es lo mismo que correcto.* El detalle, con lineas, en
    PHANTOM_Phasmophobia_Diseno.md §20.1 y §20.2.

    Y LO QUE EL CLOAK DE LA BASE TAMPOCO DABA: wraithcloaking.lua NO define
    IsSilentStepping. Un fantasma cloakeado SIGUE SONANDO al caminar. El
    silencio vive en server_steps.lua y ya esta cerrado en juego: no se duplica
    aca ( Diseno 20.7 ).
---------------------------------------------------------------------------]]

---------------------------------------------------------------------------
-- La perilla
---------------------------------------------------------------------------
-- Misma convencion que las otras cuatro del addon ( 0 control · 1 el flag del
-- NPC · 2 forzado ), y por eso la resuelve la misma funcion. En 0 el fantasma
-- se ve siempre, que es el comportamiento anterior a este bloque: ese es el
-- control negativo.
--
-- El 2 no es decoracion y hace falta para una fila: fuerza la invisibilidad
-- IGNORANDO el hunt, o sea que permite medir el render solo, sin depender de
-- que el gatillo del hunt este del lado correcto. Sin el, "no se ve" y "esta en
-- hunt" se confunden.
local cvAbsence = CreateConVar( "phantasmagoria_ghost_absence", "1", FCVAR_ARCHIVE,
    "Diseno 20 ①: 0 = nadie desaparece ( CONTROL, el comportamiento anterior ) · " ..
    "1 = respeta el flag phantom_Absent de cada NPC ( arranca en true: el fantasma desaparece fuera del hunt ) · " ..
    "2 = TODOS desaparecen, y ademas IGNORANDO el hunt ( sirve para medir el render solo ).", 0, 2 )

---------------------------------------------------------------------------
-- Quien decide, y el motivo
---------------------------------------------------------------------------
-- EL NOMBRE DEL METODO NO ES EL DEL CAMPO, y es la leccion de la ronda 4: el
-- campo es ENT.phantom_Absent ( server.lua ) y el metodo es
-- phantom_WantsAbsence. Si se llamaran igual, el include pisaria el campo con
-- la funcion y el resolvedor caeria a la rama "es nil" -- con un default que
-- coincide con lo esperado, o sea un check verde sobre un campo ilegible. La
-- guarda del final de server.lua cubre este flag tambien, porque sale de la
-- misma tabla FLAGS.
function ENT:phantom_WantsAbsence()
    local resolver = PHANTASMAGORIA.ResolveFlag
    if not resolver then return false, "PHANTASMAGORIA.ResolveFlag no existe ( server_doors.lua no cargo )" end

    return resolver( self, "phantom_Absent", cvAbsence, true )

end

-- LA POLITICA COMPLETA EN UN SOLO LUGAR, y devuelve el motivo por la misma
-- razon que el resolvedor de pisadas: "se ve" tiene causas distintas que desde
-- afuera son identicas -- la convar en 0, el flag del NPC en false, o que el
-- fantasma este cazando. El reporte imprime cual.
--
-- Devuelve: visible ( bool ), motivo ( string ).
function ENT:phantom_WantsVisible( myTbl )
    myTbl = myTbl or self:GetTable()

    -- MANEJADO POR UN JUGADOR SE VE SIEMPRE, y va PRIMERO. Un bot invisible no
    -- se puede pilotear: el que lo maneja no sabe donde esta su propio cuerpo.
    -- Es la misma precedencia que ShouldRun le da al piloto en server_speed.lua.
    if myTbl.IsControlledByPlayer and myTbl.IsControlledByPlayer( self, myTbl ) then
        return true, "lo maneja un jugador"

    end

    local quiere, motivo = self:phantom_WantsAbsence()

    if not quiere then
        return true, "no desaparece: " .. motivo

    end

    -- EL 2 SE SALTEA EL HUNT A PROPOSITO. Con el 1, "invisible" y "no esta
    -- cazando" son la misma cosa y una fila que mida el render estaria midiendo
    -- tambien el gatillo del hunt. Con el 2 el render se mide solo.
    if cvAbsence:GetInt() == 2 then
        return false, "INVISIBLE forzado ( absence 2: ignora el hunt )"

    end

    if myTbl.phantom_Hunting then
        return true, "esta CAZANDO ( en hunt el fantasma se ve; el parpadeo es Diseno 20 ②, sin escribir )"

    end

    return false, "INVISIBLE: " .. motivo .. ", y no esta cazando"

end

---------------------------------------------------------------------------
-- Los contadores y la bitacora
---------------------------------------------------------------------------
-- `ajenos` es el unico que no cuenta nuestro trabajo: cuenta las veces que el
-- estado REAL de la entidad no coincidia con lo que nosotros creiamos haber
-- escrito. O sea que detecta a un segundo escritor de SetNoDraw. Tiene que dar
-- 0; si da otra cosa, hay alguien mas y el reporte lo dice antes de que se vea
-- como "la invisibilidad parpadea sola".
--
-- `hijosMax` mide la suposicion de Diseno 20.2 en vez de darla por buena: el
-- bucle sobre GetChildren() del wraith existe porque su bot lleva un arma
-- parenteada, y el nuestro no lleva ninguna. Si esto da 0 en toda una corrida,
-- SetNoDraw sobre la entidad alcanza.
local function stats( ghost )
    ghost.phantom_visStats = ghost.phantom_visStats or {
        ocultadas = 0, mostradas = 0, ajenos = 0, hijosMax = 0, hijosTocados = 0,
    }

    return ghost.phantom_visStats

end

-- TRANSICIONES, no muestras por tick: una linea por frame serian 66 por segundo
-- y la bitacora taparia el dato. Misma decision que en server_steps.lua.
local BITACORA_MAX = 40

PHANTASMAGORIA.VisLog = PHANTASMAGORIA.VisLog or {}

local function anotar( texto )
    local log = PHANTASMAGORIA.VisLog
    log[ #log + 1 ] = string.format( "%8.1f  ", CurTime() ) .. texto

    while #log > BITACORA_MAX do table.remove( log, 1 ) end

end

---------------------------------------------------------------------------
-- LA PRIMITIVA -- y es la unica que escribe como se dibuja el fantasma
---------------------------------------------------------------------------
-- Diseno 20.2 y 20.3. Cuatro efectos y ni uno mas:
--
--   el NW var        ⚠ ES EL QUE HACE EL TRABAJO, DESDE LA r22. Antes lo hacia
--                    SetNoDraw y ESO SE CAYO EN JUEGO ( r20 + r21 ): esa bandera
--                    manda la entidad a FL_EDICT_DONTSEND, o sea que el cliente
--                    DEJA DE RECIBIRLA -- se queda con una copia congelada, con
--                    la posicion vieja y con la bandera sin llegar ( por eso
--                    GetNoDraw() daba false del lado cliente ), y el marcador
--                    dibujaba donde el fantasma ESTABA.
--                    La salida es la de HIM ( Referencia §6, y estaba escrita
--                    desde antes del bloque ): **la entidad se sigue
--                    transmitiendo entera y el que no dibuja es el ENT:Draw del
--                    cliente**. De HIM se porta la tecnica y NO el cableado: el
--                    suyo pregunta self:IsSolid(), o sea que acopla invisible a
--                    no-solido -- el mismo acoplamiento por el que §20.1 rechazo
--                    el cloak de la base -- y nuestro fantasma ausente es solido
--                    a proposito.
--   DrawShadow       una sombra sin cuerpo es un delator gratis. Y ahora es
--                    IMPRESCINDIBLE, no una prolijidad: sin SetNoDraw, el engine
--                    no se lleva la sombra de arriba: se la lleva esta linea o
--                    no se la lleva nadie.
--   FL_NOTARGET      que los otros NPC lo ignoren mientras no se ve.
--                    ⚠ Va sobre EL BOT y no sobre el jugador, que es al reves
--                    que la trampa de NEAD ( Diseno 19.5 ): NO afecta a que el
--                    fantasma te vea a vos. Escrito para que nadie lo
--                    "corrija".
--   RemoveAllDecals  sangre flotando en el aire, idem.
--
-- ⚠ Y LO QUE YA NO ESTA: **SetNoDraw no se llama mas, en ningun camino**. Si
-- alguna vez vuelve a aparecer sobre este bot, el sintoma no va a ser "no se
-- ve" ( eso ya funciona ) sino "el marcador miente y el physgun lo agarra en
-- otro lado", que es un sintoma con la causa muy lejos del efecto. Por eso el
-- detector de abajo pasa a vigilar esa bandera en vez de escribirla.
--
-- ⚠ LO QUE NO HACE, y es la decision del bloque: no toca SetSolidMask, ni
-- SetCollisionGroup, ni SetNotSolid. La solidez tiene UN dueno y es
-- server_doors.lua.
--
-- ⚠ Y NO SUENA. El cloak de la base emite un pod de la Ciudadela al esconderse
-- y otro al aparecer; los FX de manifestacion son Diseno 20 ③, que es otro
-- bloque y tiene su propio banco. Un sonido puesto aca "de paso" seria un
-- delator que el diseno no pidio.
function ENT:phantom_SetVisible( visible, motivo )
    visible = visible == true

    local st = stats( self )

    self.phantom_Visible = visible
    self.phantom_VisWhy  = motivo or "( sin motivo declarado )"
    self.phantom_VisAt   = CurTime()

    self:DrawShadow( visible )

    -- ⚠ ESTA LINEA ERA EL TESTIGO Y AHORA ES EL MECANISMO. Entro para poder ver
    -- una divergencia contra SetNoDraw -- dos sistemas de red distintos,
    -- impresos juntos -- y termino ganando la discusion: **de las cuatro
    -- lecturas del cliente fue la unica que llego bien** ( r20 ), asi que es la
    -- que decide el ENT:Draw ( client.lua ) y la que decide el marcador honesto.
    -- *El repuesto que se puso al lado para poder comparar puede terminar siendo
    -- la pieza.*
    --
    -- SetNWBool y no SetupDataTables, por lo mismo que el hunt y el tipo: la
    -- base networkea con slots hardcodeados y el Bool 0 ya es Crouching
    -- ( Referencia 4.3, trampa 3 ).
    self:SetNWBool( "phantasmagoria_invisible", not visible )

    if visible then
        self:RemoveFlags( FL_NOTARGET )
        st.mostradas = st.mostradas + 1

    else
        self:AddFlags( FL_NOTARGET )
        self:RemoveAllDecals()
        st.ocultadas = st.ocultadas + 1

    end

    -- LOS HIJOS, con el mismo filtro que usa el wraith y por el mismo motivo:
    -- GetChildren() puede traer al jugador que lo espectatea, y entidades cuyo
    -- padre ya no es este bot. Se MIDE cuantos hay: la r20 dio `maximo visto 0`
    -- en toda la corrida, asi que la suposicion de Diseno 20.2 quedo confirmada
    -- y este bucle es una poliza que no se ejecuto nunca.
    --
    -- ⚠ Y POR ESO SIGUE USANDO SetNoDraw, QUE ES LA TECNICA QUE ACABAMOS DE
    -- RETIRAR. No es un olvido y no se puede arreglar en el aire: un hijo es
    -- OTRA entidad y de OTRA clase -- no pasa por nuestro ENT:Draw --, asi que la
    -- salida de la r22 no le llega. Sobre un hijo, SetNoDraw ademas no es lo
    -- mismo que sobre el bot: una entidad con padre no cae en la misma rama de
    -- transmision.
    --
    -- **La regla, escrita para el dia que `hijosMax` deje de dar 0:** ese dia
    -- este bucle NO alcanza y hay que darle a cada hijo su propio no-dibujado
    -- ( su Draw, o un RenderOverride ), midiendolo aparte. *Una poliza que
    -- quedo escrita con la tecnica vieja es una trampa con fecha: el dia que se
    -- ejecute va a fallar del modo que ya conocemos y nadie va a estar
    -- mirandola.*
    local kids = self:GetChildren()

    if #kids > st.hijosMax then st.hijosMax = #kids end

    for _, child in ipairs( kids ) do
        if not IsValid( child ) then continue end
        if child:IsPlayer() then continue end
        if child:GetParent() ~= self then continue end

        child:SetNoDraw( not visible )
        child:DrawShadow( visible )

        st.hijosTocados = st.hijosTocados + 1

        -- Ruidoso a proposito: si esto llega a correr, la corrida tiene que
        -- enterarse en el momento y no dos rondas despues.
        anotar( "#" .. self:EntIndex() .. "  !! HIJO TOCADO con la tecnica vieja ( SetNoDraw ): " ..
            tostring( child:GetClass() ) .. ". Ver el comentario del bucle." )

    end

    anotar( "#" .. self:EntIndex() .. "  " .. ( visible and "SE VE   " or "INVISIBLE" ) ..
        "   " .. tostring( motivo ) ..
        ( #kids > 0 and ( "   ( " .. #kids .. " hijos )" ) or "" ) )

    return visible

end

---------------------------------------------------------------------------
-- El reconciliador -- y es EL UNICO que aplica la politica
---------------------------------------------------------------------------
-- Corre cada tick desde ENT:BehaveUpdate. NO se engancha a phantom_SetHunting
-- aunque esa sea la puerta unica del hunt, y la decision es deliberada:
--
--   ( a ) enganchado a la puerta, el invariante "se ve <=> la politica lo pide"
--         valdria SOLO en el instante de la transicion. Reconciliando, vale
--         siempre.
--   ( b ) y de rebote sale un DETECTOR: si el estado real de la entidad no
--         coincide con lo que nosotros escribimos, alguien mas toco SetNoDraw.
--         Ese contador tiene que dar 0, y si da otra cosa lo dice el reporte en
--         vez de aparecer como un parpadeo inexplicable.
--
-- *Un invariante que solo se escribe en la transicion no es un invariante: es
-- una esperanza.*
--
-- ⚠ Y NO VA EN ENT.MyClassTask, QUE ERA LO OBVIO Y ESTA MAL. La clave natural
-- era `BehaveUpdatePriority`, que es la que usa el wraithcloaking_handler de la
-- base. Pero el comentario del propio autor de la base la desmiente en la linea
-- de al lado ( wraithcloaking.lua:69 ):
--
--     -- BehaveUpdatePriority doesn't run when being driven by ply
--
-- y esta MEDIDO en behaviouroverrides.lua: `RunTask( "BehaveUpdatePriority" )`
-- y `RunTask( "Think" )` viven los dos adentro del mismo coroutine de
-- prioridad ( :694-695 ), que no corre mientras un jugador maneja al bot --
-- para eso hay un `playerControlCor` aparte.
--
-- O sea que la PRIMERA rama de la politica -- "manejado por un jugador se ve
-- siempre" -- nunca se habria aplicado, y el sintoma seria el peor posible:
-- **un bot invisible que no se puede pilotear porque el que lo maneja no
-- encuentra su propio cuerpo**, sin un solo error. *Una tarea que no corre en
-- el caso que la politica existe para cubrir no es el lugar de esa politica.*
--
-- Se llama desde ENT:BehaveUpdate ( server.lua ), que es el tick de arriba de
-- todo y corre siempre. Un solo dueno de BehaveUpdate, un solo dueno de la
-- visibilidad.
function ENT:phantom_ReconcileVisibility( myTbl )
    myTbl = myTbl or self:GetTable()

    -- El contador es la prueba de que esto corre, y reemplaza a la que se
    -- perdio al salir de MyClassTask: la lista de tareas de ghost_where habria
    -- dicho `<clase>_handler ACTIVA` por nombre. Un contador es mejor prueba
    -- que un nombre -- dice que corrio, no que existe, que es la leccion de
    -- m_TaskList contra m_ActiveTasks.
    myTbl.phantom_visTicks = ( myTbl.phantom_visTicks or 0 ) + 1
    myTbl.phantom_visLastTick = CurTime()

    local quiere, motivo = myTbl.phantom_WantsVisible( self, myTbl )

    -- ⚠ CONTRA QUE SE RECONCILIA, Y CAMBIO EN LA r22. Era `not self:GetNoDraw()`
    -- porque esa bandera ERA el mecanismo. Ahora el mecanismo es el NW var, asi
    -- que se lee el NW var: sigue siendo *lo que quedo escrito* y no *lo que
    -- creemos haber escrito* -- son dos almacenamientos distintos y el campo
    -- phantom_Visible de al lado lo prueba.
    --
    -- Dejarlo apuntando a GetNoDraw habria sido peor que un rojo: con la bandera
    -- ya sin escribir, `real` daria SIEMPRE true, y sobre un fantasma que la
    -- politica quiere invisible el `return` de abajo no cortaria nunca -- 66
    -- llamadas por segundo a la primitiva, la bitacora tapada y el contador
    -- `se oculto` subiendo solo. *Cuando se cambia el mecanismo hay que
    -- preguntarse contra qué estaba comparando el que lo vigilaba.*
    local real = not self:GetNWBool( "phantasmagoria_invisible", false )

    -- ⚠ EL DETECTOR TAMBIEN CAMBIO DE SUJETO, Y NO SE BORRA. Medía a un segundo
    -- escritor de SetNoDraw; como nosotros ya no la escribimos, esa bandera pasa
    -- a tener un valor esperado FIJO -- false, siempre, invisible o no -- y
    -- cualquier otro valor es un tercero escribiendo. Ese tercero devolveria
    -- exactamente el defecto de la r20: la entidad deja de transmitirse, el
    -- cliente se congela y el marcador dibuja la posicion vieja.
    --
    -- *Un detector cuyo sujeto se apaga no queda en cero: queda midiendo otra
    -- cosa, y hay que decir cuál -- o se vuelve un verde que nadie puede mover.*
    -- Va ANTES de escribir, por el mismo motivo que el seguimiento de la mirada
    -- en BehaveUpdate: puesto despues compararia contra lo nuestro.
    if self:GetNoDraw() then
        local st = stats( self )
        st.ajenos = st.ajenos + 1

        anotar( "#" .. self:EntIndex() .. "  !! ESCRITOR AJENO: la entidad tiene EF_NODRAW puesto y " ..
            "la ausencia ya no usa SetNoDraw. Con eso el cliente deja de recibirla." )

    end

    if quiere == real and myTbl.phantom_Visible ~= nil then return end

    myTbl.phantom_SetVisible( self, quiere, motivo )

end

-- LA CONVAR ALCANZA A LOS VIVOS EN EL ACTO, y esto entro por la r18b sin que
-- ninguna fila de la ausencia lo pidiera: alla, la mitad de las filas leyo un
-- valor de hace un tick porque los dos comandos iban encadenados en la misma
-- linea. El reconciliador corre igual en el tick siguiente -- o sea que la
-- convar SIEMPRE funciono --, pero la primera lectura discrepaba y eso se lee
-- como un rojo.
--
-- ⚠ NO cubre al override de flags ( phantasmagoria_ghost_flag ausencia 0 ):
-- ese comando vive en server.lua y escribe una tabla, sin gancho donde
-- colgarse. Para esa fila la separacion la hace el instrumento, con las dos
-- causas de arriba. *Cuando no se puede arreglar el hueco, el instrumento tiene
-- que nombrarlo.*
function PHANTASMAGORIA.ReconcileAllVisibility( porque )
    if not PHANTASMAGORIA.EachGhost then return 0 end

    return PHANTASMAGORIA.EachGhost( function( ghost )
        if not ghost.phantom_ReconcileVisibility then return end

        ghost:phantom_ReconcileVisibility()

    end )
end

cvars.AddChangeCallback( "phantasmagoria_ghost_absence", function( _, old, new )
    local n = PHANTASMAGORIA.ReconcileAllVisibility( "la convar cambio de " .. tostring( old ) .. " a " .. tostring( new ) )

    -- Dice el numero siempre, incluido el 0: "no habia fantasmas" y "no se
    -- re-aplico" se ven igual en una consola muda, y la primera es una
    -- precondicion sin cumplir mientras la segunda es un defecto.
    PHANTASMAGORIA.Print( "phantasmagoria_ghost_absence ", tostring( old ), " -> ", tostring( new ),
        ": reconciliados ", n, " fantasma(s) vivo(s).\n" )

end, "phantasmagoria_absence_vivos" )

---------------------------------------------------------------------------
-- ⚠ EL CADAVER, Y ES UNA MEDICION DISFRAZADA DE POLIZA
---------------------------------------------------------------------------
-- La base mata al bot asi ( damageandhealth.lua:804-826 ): primero
-- BecomeRagdoll( dmg ), despues el gancho de abajo, y AL FINAL
-- self:SetNoDraw( true ) sobre el bot. O sea que el ragdoll nace mientras el
-- bot todavia esta con NUESTRO EF_NODRAW puesto.
--
-- ⚠ MEDIDO EN LA r20, Y LA RESPUESTA FUE QUE SI: salio el print, o sea que
-- BecomeRagdoll hereda la bandera y esta guarda no era decorativa. **Y desde la
-- r22 tiene que dejar de salir**, porque el bot ya no lleva EF_NODRAW puesto
-- nunca: la ausencia la hace el ENT:Draw del cliente, que es de ESTA entidad y
-- no del ragdoll, asi que un fantasma que muere invisible deja un cadaver
-- visible sin que nadie lo corrija.
--
-- Eso convierte a la guarda en una prediccion falsable, que es mejor que una
-- poliza: si el print vuelve a salir, alguien puso EF_NODRAW sobre el bot -- el
-- mismo tercero que cuenta `ESCRITORES AJENOS` -- y este es el segundo testigo,
-- en otro momento y por otro camino. *No se saca hasta que una corrida entera
-- diga que no hizo falta.*
--
-- ( Lo de abajo es el texto original, de cuando esto no estaba medido. )
-- NO ESTA MEDIDO si BecomeRagdoll hereda esa bandera. Si la hereda, un fantasma
-- que muere invisible deja un cadaver invisible -- que se leeria como "el
-- fantasma desaparecio al morir", un sintoma con causa muy lejos de su efecto.
--
-- La linea cuesta nada y es idempotente, pero **el print de al lado la
-- convierte en una medicion**: si sale, la herencia existe y queda documentada;
-- si no sale nunca en una corrida, no existe y esta guarda es una poliza que se
-- puede sacar. *Una poliza que no dice si hizo falta se queda para siempre.*
--
-- El stub de la base esta COMENTADO ( damageandhealth.lua:943-947 ), asi que no
-- hay a quien encadenar. Y su propio comentario pide declararla SHARED porque
-- cl_ragdolldeaths.lua tambien la llama para los ragdolls de cliente; la
-- declaracion compartida vive en shared.lua y esta es la mitad del servidor.
function ENT:AdditionalRagdollDeathEffects( ragdoll )
    if not IsValid( ragdoll ) then return end

    if ragdoll:GetNoDraw() then
        PHANTASMAGORIA.Print( "#", self:EntIndex(), " murio invisible y el ragdoll NACIO con EF_NODRAW: ",
            "BecomeRagdoll SI hereda la bandera. Se lo hace visible.\n" )

        anotar( "#" .. self:EntIndex() .. "  el RAGDOLL nacio invisible -- corregido" )

    end

    ragdoll:SetNoDraw( false )
    ragdoll:DrawShadow( true )

end

---------------------------------------------------------------------------
-- El instrumento
---------------------------------------------------------------------------
-- ⚠ ESTE COMANDO EXISTE PORQUE EL CRITERIO DE ESTE BLOQUE ES VISUAL. La fila
-- del networkeo de la tajada A se marco verde tres rondas seguidas sin traer un
-- dato del cliente, porque pedia PEGAR lo que dice un marcador 3D -- y un
-- marcador no produce texto. Un bloque entero sobre visibilidad choca con eso
-- en cada fila.
--
-- Este es el lado SERVIDOR. El lado cliente es phantasmagoria_ghost_cl, que
-- imprime lo que el engine tiene puesto de verdad ( GetNoDraw / GetMaterial ) y
-- no lo que nosotros creemos. Los dos hacen falta: **este dice lo que pedimos,
-- aquel dice lo que quedo**.
PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_vis", function( ply, _, args )
    local say = PHANTASMAGORIA.MakeSay( ply )
    local sub = args and args[ 1 ]

    if sub == "reset" then
        local n = PHANTASMAGORIA.EachGhost( function( ghost ) ghost.phantom_visStats = nil end )

        PHANTASMAGORIA.VisLog = {}

        say( "[Phantasmagoria] contadores y bitacora de visibilidad vaciados en " .. n .. " fantasma(s)." )
        return

    end

    local modo = cvAbsence:GetInt()

    say( "[Phantasmagoria] phantasmagoria_ghost_absence " .. modo .. "   ( " ..
        ( modo == 0 and "CONTROL: nadie desaparece"
        or modo == 1 and "respeta el flag phantom_Absent de cada NPC"
        or "FORZADO: todos invisibles, ignorando el hunt" ) .. " )" )

    -- ⚠ El estado del marcador de debug es del CLIENTE y desde el servidor NO se
    -- puede leer. Decirlo es parte del reporte: una corrida hecha con el
    -- marcador en 1 no mide esta mecanica, la tapa ( Diseno 20.4 ), y este
    -- comando no puede saber en cual esta.
    say( "    el marcador ( phantasmagoria_debug_ghost ) es del CLIENTE y no se lee desde aca." )
    say( "    para las filas de invisibilidad tiene que estar en 2 ( honesto ). Verificarlo con phantasmagoria_ghost_cl." )

    local found = PHANTASMAGORIA.EachGhost( function( ghost )
        local st = stats( ghost )
        local quiere, motivo = ghost:phantom_WantsVisible()
        local real = not ghost:GetNWBool( "phantasmagoria_invisible", false )

        say( "#" .. ghost:EntIndex() .. "  serie " .. tostring( ghost.phantom_Serial or "?" ) ..
            "   hunt " .. ( ghost.phantom_Hunting and "SI" or "NO" ) )

        -- LAS TRES COLUMNAS SON TRES COSAS DISTINTAS Y HAY QUE PODER
        -- SEPARARLAS: lo que la politica PIDE, lo que nosotros CREEMOS haber
        -- escrito, y lo que la entidad TIENE. Un instrumento que imprimiera una
        -- sola no podria distinguir "la politica esta al reves" de "alguien mas
        -- escribe encima".
        say( "    pide      " .. ( quiere and "VISIBLE" or "INVISIBLE" ) .. "   ( " .. motivo .. " )" )
        say( "    creemos   " .. ( ghost.phantom_Visible == nil and "( nunca escribimos: el reconciliador no corrio )"
            or ( ghost.phantom_Visible and "VISIBLE" or "INVISIBLE" ) ) ..
            ( ghost.phantom_VisAt and ( "   hace " .. string.format( "%.1f", CurTime() - ghost.phantom_VisAt ) .. " s" ) or "" ) )
        -- Sin columna de SOMBRA, y no es un olvido: DrawShadow es un SETTER sin
        -- getter, asi que imprimir "sombra si/no" seria repetir lo que acabamos
        -- de pedir y no lo que hay. Un dato que solo puede confirmar tu propia
        -- escritura no mide: la sombra se juzga mirando el piso, o no se juzga.
        -- ⚠ ESTA LINEA DICE LO QUE SE MANDO, NO LO QUE SE DIBUJO -- y decirlo es
        -- parte del reporte. Desde la r22 el que no dibuja es el ENT:Draw del
        -- CLIENTE, y desde el servidor eso no se puede leer: lo unico
        -- comprobable aca es que el NW var salio con el valor correcto. La otra
        -- mitad -- que el Draw haya corrido y se haya salteado -- la acredita el
        -- contador `saltos del Draw` de phantasmagoria_ghost_cl, y hacen falta
        -- las dos. *Un comando que no puede medir la mitad que importa tiene que
        -- nombrar al que sí puede.*
        say( "    networkeado " .. ( real and "VISIBLE" or "INVISIBLE ( el NW var salio )" ) ..
            "   FL_NOTARGET " .. ( ghost:IsFlagSet( FL_NOTARGET ) and "SI" or "NO" ) ..
            "   -- que el cliente lo OBEDEZCA se mide con phantasmagoria_ghost_cl ( saltos del Draw )" )

        -- El control de la bandera vieja. Tiene que decir NO siempre: la ausencia
        -- ya no la escribe, y si esta puesta el cliente deja de recibir la
        -- entidad y vuelve el defecto de la r20.
        if ghost:GetNoDraw() then
            say( "    !! EF_NODRAW PUESTO, y no fuimos nosotros ( la ausencia ya no usa SetNoDraw ). " ..
                "Con esa bandera la entidad deja de transmitirse: el marcador va a dibujar la posicion vieja." )

        end

        -- ⚠ LAS DOS CAUSAS DE UNA DISCREPANCIA, SEPARADAS POR LO QUE PASA EN LA
        -- LECTURA SIGUIENTE. Es la leccion de la r18b, aplicada antes de correr:
        -- alla el reporte imprimia `convertidas run 165` al lado de
        -- `deseada 280` y las dos eran ciertas -- una recien calculada y la otra
        -- escrita por el TICK, que en el frame de un cambio todavia no corrio.
        --
        -- Aca pasa lo mismo con cualquier comando encadenado
        -- ( `..._absence 0; ..._ghost_vis` ): la politica se lee EN VIVO y el
        -- render lo escribe el reconciliador en el tick siguiente. **La primera
        -- lectura despues de un cambio va a discrepar, y eso es correcto.**
        --
        -- *Un instrumento que solo dice "no coinciden" convierte lo normal en un
        -- rojo; el que dice como distinguirlo convierte dos lecturas en un
        -- veredicto.*
        if quiere ~= real then
            say( "    !! LO QUE PIDE Y LO QUE HAY NO COINCIDEN. Dos causas, y se separan volviendo a leer:" )
            say( "       ( a ) acabas de cambiar algo en ESTE frame ( convar, flag, hunt ). La politica se lee en vivo" )
            say( "             y el render lo escribe el reconciliador en el TICK: es normal y dura un tick." )
            say( "             Volve a tipear el comando SOLO, sin encadenarlo." )
            say( "       ( b ) si se lee igual TIPEADO SOLO dos veces, el reconciliador no esta corriendo:" )
            say( "             mirar la linea 'reconcil.' de arriba, que es la que lo mide." )

        end

        say( "    contados  se oculto " .. st.ocultadas .. " · se mostro " .. st.mostradas ..
            " · ESCRITORES AJENOS " .. st.ajenos .. " ( tiene que ser 0: cuenta ticks con EF_NODRAW puesto por un tercero )" )

        -- LA MEDICION DE DISENO 20.2, y no una curiosidad: si esto da 0, el
        -- bucle sobre los hijos es una poliza y SetNoDraw sobre la entidad
        -- alcanza. Si da distinto de 0, hay entidades pegadas al bot que se
        -- dibujan aparte y el bucle es imprescindible.
        say( "    hijos     " .. #ghost:GetChildren() .. " ahora · maximo visto " .. st.hijosMax ..
            " · tocados " .. st.hijosTocados ..
            "   ( si el maximo es 0, esconder la ENTIDAD alcanza y el bucle es poliza )" )

        -- QUE EL RECONCILIADOR CORRE, medido y no deducido de una lista. Es lo
        -- que reemplaza al `<clase>_handler ACTIVA` de las tareas: aquello dice
        -- que la tarea EXISTE, esto dice que el codigo se EJECUTO -- y la
        -- diferencia entre las dos ya costo una ronda en este addon
        -- ( m_TaskList contra m_ActiveTasks ).
        local ticks = ghost.phantom_visTicks or 0

        say( "    reconcil. " .. ticks .. " ticks" ..
            ( ghost.phantom_visLastTick and ( "   el ultimo hace " .. string.format( "%.2f", CurTime() - ghost.phantom_visLastTick ) .. " s" ) or "" ) ..
            ( ticks <= 0 and "   !! NUNCA CORRIO: ENT:BehaveUpdate no llama a phantom_ReconcileVisibility"
            or ( ghost.phantom_visLastTick and CurTime() - ghost.phantom_visLastTick > 1 ) and "   !! DEJO DE CORRER"
            or "" ) )

    end )

    if found <= 0 then
        say( "[Phantasmagoria] no hay ningun fantasma vivo." )

    end

    local log = PHANTASMAGORIA.VisLog

    say( "[Phantasmagoria] bitacora ( transiciones, ultimas " .. BITACORA_MAX .. " ):" )

    if #log <= 0 then
        -- Un comando mudo no distingue el exito del vacio ( regla 6 ): con la
        -- convar en 0 la bitacora vacia es CORRECTA, y con la convar en 1 es un
        -- defecto. Se dicen las dos.
        say( "    vacia. Con absence " .. modo .. " eso " ..
            ( modo == 0 and "es lo esperado ( el control no oculta a nadie )."
            or "significa que phantom_SetVisible no corrio NUNCA: mirar la linea 'tarea' de arriba." ) )

    else
        for _, linea in ipairs( log ) do say( "    " .. linea ) end

    end

end, "phantasmagoria_ghost_vis [reset]  -- que pide la politica de ausencia, que creemos haber escrito, y que tiene puesto la entidad." )

---------------------------------------------------------------------------
-- LAS DOS GUARDAS DEL CIERRE, y este archivo es el ultimo include
---------------------------------------------------------------------------
-- ① Las claves de MyClassTask. Si dos archivos declaran la misma, el segundo
--    pisa al primero y el sintoma es un bloque entero que no corre, sin un solo
--    error. Este archivo NO usa MyClassTask -- usa ENT:BehaveUpdate, por el
--    motivo de arriba --, y por eso puede auditar a los otros dos desde afuera.
for _, clave in ipairs( { "Think", "ModifyMovementSpeed" } ) do
    if not isfunction( ENT.MyClassTask and ENT.MyClassTask[ clave ] ) then
        ErrorNoHalt( "[Phantasmagoria] ENT.MyClassTask." .. clave .. " NO es una funcion despues de " ..
            "cargar server_cloak.lua. Alguien piso la clave de otro archivo y ese bloque no va a " ..
            "correr, sin tirar un solo error.\n" )

    end
end

-- ② Que ENT:BehaveUpdate llame al reconciliador. Es la unica forma de que la
--    politica se aplique, y su ausencia NO tira error: el fantasma se veria
--    siempre, o sea que este bloque entero se leeria como "no anda la
--    invisibilidad" -- y con el default en visible, como que nada cambio.
--
--    ⚠ ESTA GUARDA NO PUEDE VER LA LLAMADA, y decirlo es parte de la guarda.
--    En Lua no se lee el cuerpo de una funcion; lo unico comprobable al cargar
--    es DE QUE ARCHIVO salio. Si BehaveUpdate no viene de nuestra carpeta, el
--    override se perdio y con el la ausencia Y el facewalk. Que la llamada
--    exista adentro lo mide otra cosa, y en juego: el contador
--    `phantom_visTicks`, que phantasmagoria_ghost_vis imprime con su
--    "!! NUNCA CORRIO". *Una guarda que no puede comprobar la mitad que importa
--    tiene que nombrar a la que si puede.*
local fuente = isfunction( ENT.BehaveUpdate ) and debug.getinfo( ENT.BehaveUpdate, "S" ) or nil

if not isfunction( ENT.BehaveUpdate ) then
    ErrorNoHalt( "[Phantasmagoria] ENT:BehaveUpdate no existe: la ausencia ( Diseno 20 ① ) NO se va a " ..
        "aplicar nunca y el fantasma va a verse siempre, sin tirar error.\n" )

elseif fuente and fuente.short_src and not string.find( fuente.short_src, "terminator_nextbot_phantom", 1, true ) then
    ErrorNoHalt( "[Phantasmagoria] ENT:BehaveUpdate viene de '" .. tostring( fuente.short_src ) ..
        "' y no de nuestra carpeta: el override se perdio, y con el la ausencia y el facewalk.\n" )

end
