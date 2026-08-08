--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom / PISADAS

    LO QUE PIDIO EL AUTOR, literal: "quitarle tambien el sonido a las pisadas
    con un flag, puesto que en Phasmophobia el fantasma suena con sus pisadas al
    estar en hunt como tambien en eventos ( donde se aparece para sacar
    evidencia o asustar al jugador, como tambien quitar cordura en algunos
    casos ). El quitarle el sonido de los pasos debe ser coherente con que
    despues el Paramic los va a poder escuchar, tomar en cuenta eso."

    LA RESTRICCION ES LA INVERSA DE LA DE LAS PUERTAS, Y LA PUSO EL ANTES DE QUE
    SE ESCRIBIERA UNA LINEA.

    Con las puertas el silencio se hace BORRANDO UN DATO: se le pisan a la
    puerta sus siete keyvalues de sonido y se las devuelve despues, asi el
    sonido no llega a existir. Ahi esta bien, porque nadie va a querer medir
    despues el chirrido de una hoja.

    Aca NO sirve. El Paramic ( microfono parabolico, Diseno 7 ) tiene que poder
    OIR estas pisadas mas adelante. O sea que la pisada TIENE QUE SEGUIR
    OCURRIENDO como evento -- con su posicion y su intensidad -- y lo unico que
    se apaga es que el JUGADOR la escuche por el altavoz.

        Silenciar no puede significar "que no pase". Tiene que significar "que
        no se oiga", con el hecho intacto para el que despues lo vaya a medir.

    Por eso el orden de AdditionalFootstep de mas abajo NO es cosmetico: el
    hook.Run va PRIMERO y corre SIEMPRE, y recien despues se decide si se
    bloquea el sonido. Si algun dia alguien invierte esas dos lineas, el sintoma
    va a ser un Paramic que no detecta nada, sin un solo error.

    ---------------------------------------------------------------------------
    LOS DOS PUNTOS DE EXTENSION, CENSADOS EN LA BASE. Y EL SEGUNDO NO HACE LO
    QUE ESTADO.md CREIA.
    ---------------------------------------------------------------------------

    ESTADO.md daba por sentado que ENT:IsSilentStepping ( sharedextras.lua:7 )
    era "el interruptor propio de la base" para esto, y que el problema era que
    "apaga TODA esa familia, no solo las pisadas". Se censaron los SEIS call
    sites de MakeFootstepSound y es al reves:

      footsteps.lua:104        caminar ( timed )        NO lo tapa
      footsteps.lua:152        caminar ( perfect )      NO lo tapa
      motionoverrides.lua:2997 saltar                   NO -- el chequeo esta en
                                                        :2999, o sea DESPUES
      motionoverrides.lua:3459 aterrizar ( >500 u )     NO -- chequeo en :3460
      motionoverrides.lua:3474 aterrizar ( >250 u )     NO -- chequeo en :3475
      motionoverrides.lua:3485 aterrizar ( >50 u )      NO -- chequeo en :3486
      motionoverrides.lua:3599 caida letal              SI, por el return de :3578

    Y ProcessFootsteps ( behaviouroverrides.lua:141 ), que es el que dispara las
    pisadas de caminar cada tick, no lo consulta en ningun lado.

    *IsSilentStepping no apaga las pisadas.* Apaga la escalera ( :2592, :2951 ),
    los extras metalicos del salto y del aterrizaje, el viento de la caida
    ( :3203, :3260, :3273 ), el vacio ( :3557 ), el overcharge
    ( overcharging.lua:37 ) y el click de Use2 ( shared.lua:1234 ). O sea: todo
    lo que rodea a la pisada, y la pisada no.

    Asi que no es "una palanca gruesa": son DOS palancas para DOS familias, y
    hacen falta LAS DOS. Solo con AdditionalFootstep el fantasma "callado"
    seguiria sonando al saltar y al aterrizar, porque la base trae
    ENT.MetallicMoveSounds = true ( shared.lua:161 ). Eso es la regla 2 del
    proyecto en miniatura: *apagar NUESTRA implementacion no es apagar EL
    COMPORTAMIENTO cuando el tercero tambien lo hace.*

    ( ⚠ Este parrafo decia "y este fantasma no lo pisa", y desde la ronda 9 SI lo
      pisa: el autor pidio que el salto no suene a robot y el campo pasa a false
      unas lineas mas abajo. El override de IsSilentStepping sigue haciendo
      falta igual -- tapa el sonido de caida, el vacio, el overcharge y el click
      de Use2, que no cuelgan de MetallicMoveSounds. )

    Lo que la base trae prendido y nosotros NO pisamos ( verificado, no supuesto ):
      ENT.ReallyHeavy        = true   shared.lua:160
      ENT.FootstepClomping   = true   shared.lua:171
      ENT.Term_FootstepMode  = "human"  :164   ( el sonido sale de la superficie )
      ENT.Term_FootstepTiming = "timed" :163

    El clomping SI queda tapado por AdditionalFootstep, porque vive en
    footsteps.lua:340, o sea DESPUES del return de :331. Los metalicos no.

    ---------------------------------------------------------------------------
    EL AGUJERO QUE LA BASE DEJA, Y QUE ACA SE MIDE EN VEZ DE COMENTARSE
    ---------------------------------------------------------------------------

    footsteps.lua:330 es

        if not stepSound then return end

    y esta ANTES del AdditionalFootstep de :331. O sea que cuando la superficie
    no da sonido de pisada -- util.GetSurfaceData sin stepLeftSound/stepRightSound
    para ese material -- la pisada OCURRE y nuestro gancho no se entera nunca.

    Es exactamente el modo de falla que el autor pidio evitar, salvo que el dato
    lo tira la base y no nosotros. No se puede tapar sin reescribir
    MakeFootstepSound entera, y la base aconseja explicitamente no hacerlo
    ( "You can override this entire function but i'd advise against it",
    footsteps.lua:214 ).

    Lo que SI se puede es medirlo, y por eso existe el envoltorio de
    MakeFootstepSound de mas abajo: cuenta los pasos REALES, mientras
    AdditionalFootstep cuenta los pasos que el gancho VIO. La resta es el
    agujero, con un numero, y el bloque del Paramic va a saber de antemano
    cuantas pisadas no va a poder oir nunca. *Un agujero medido es una decision;
    un agujero comentado es una sorpresa.*

    ---------------------------------------------------------------------------
    LO QUE NO LLEGA AL GANCHO, DICHO ANTES DE QUE ALGUIEN LO SUPONGA
    ---------------------------------------------------------------------------

    AdditionalFootstep recibe volume pero NO recibe `lvl` ni `soundWeightAdj`
    ( footsteps.lua:243 y :365 ): el nivel con el que el engine atenua la pisada
    se calcula despues de llamarnos. No se inventa un numero para rellenarlo.

    Y no hace falta: `lvl` gobierna como el ENGINE atenua el sonido para el oido
    del jugador, y el Paramic no va a usar la atenuacion del engine -- va a
    tener su propia posicion y su propio alcance. Con footPos y volume alcanza
    para modelar intensidad. Si algun dia hace falta el lvl de verdad, el unico
    lugar donde existe es adentro de MakeFootstepSound.

    ---------------------------------------------------------------------------
    Y EL CONSUMIDOR TIENE QUE USAR EL HOOK, NO LA TAREA
    ---------------------------------------------------------------------------

    La base ofrece DOS caminos para lo mismo, seguidos:

        if self:AdditionalFootstep( ... ) then return end          -- :331 metodo
        if self:RunTask( "AdditionalFootstep", ... ) then return end -- :332 tarea

    Nosotros tomamos el METODO ( :331 ), por lo mismo que ShouldRun dejo de ser
    callback de tarea en la ronda 4: el metodo es deterministico y no compite
    con nadie, y RunTask corta en el primer valor no-nil. Pero eso tiene una
    consecuencia que hay que dejar escrita: cuando silenciamos devolvemos true
    en :331, asi que :332 NO CORRE. Un consumidor que se enganche por
    MyClassTask "AdditionalFootstep" queda ciego JUSTO cuando la pisada es
    silenciosa, que es el unico caso que le importa al Paramic.

    Por eso el gancho de este archivo es un hook.Run y no una tarea.
---------------------------------------------------------------------------]]

---------------------------------------------------------------------------
-- EL FANTASMA NO ES UN ANDROIDE ( pedido del autor, ronda 9 )
---------------------------------------------------------------------------
-- Literal, despues de correr la fila 09: "me molesta el ruido metalico al
-- saltar, eso es un remanente del terminator que es un androide robotico, el
-- phantom deberia saltar con ruidos normales".
--
-- Tiene razon y no es cosmetico: la base trae ENT.MetallicMoveSounds = true
-- ( shared.lua:161 ) porque su terminator ES una maquina, y este fantasma lo
-- heredaba sin que nadie lo hubiera decidido. Es la regla de "heredado y gratis
-- no es lo mismo que correcto" en una linea.
--
-- LA EVIDENCIA DE QUE ES EL CAMPO CORRECTO Y NO UN PARCHE, censados los CINCO
-- call sites ( grep sobre la base: cinco, no cuatro -- el quinto es la caida
-- letal ):
--
--   motionoverrides.lua:2999  saltar          2 EmitSound + ScreenShake
--   motionoverrides.lua:3460  aterrizar >500  2 EmitSound + 3 Whaps + ScreenShake
--   motionoverrides.lua:3475  aterrizar >250  2 EmitSound + ScreenShake
--   motionoverrides.lua:3486  aterrizar >50   2 EmitSound + ScreenShake
--   motionoverrides.lua:3579  caida letal     2 EmitSound
--
-- En los cuatro primeros el MakeFootstepSound esta AFUERA del if ( :2997,
-- :3459, :3474, :3485 ), asi que apagar los metalicos NO deja al salto mudo:
-- deja la pisada de la superficie, que es exactamente "ruidos normales". Y en
-- el quinto el TakeDamage esta afuera tambien ( :3596 ), asi que esto no toca
-- la caida letal ni el override que la repone.
--
-- Y NO ES UNA DESVIACION DE LA BASE: su propio bot desarmado ya lo apaga.
-- terminator_nextbot_fakeply.lua:67 y terminator_nextbot_csoldier.lua:131 traen
-- MetallicMoveSounds = false, y fakeply es literalmente el molde de este
-- fantasma ( server.lua lo dice ). *Lo copiamos a medias: le tomamos el
-- DefaultWeapon y el TERM_FISTS y le dejamos los sonidos de robot.*
--
-- ⚠ LO QUE ESTO SE LLEVA, dicho para que no se lea como gratis: los cuatro
-- util.ScreenShake del salto y el aterrizaje ( 16 / 4 / 0,5 de amplitud ) y los
-- tres Whaps de la caida de mas de 500 u. Son efecto, no dano: killScale y
-- killBoxScale estan afuera del if, o sea que aplastar sigue aplastando igual.
--
-- ⚠ Y CAMBIA LO QUE MIDIO LA RONDA 8b: la fila del salto probaba que silenciar
-- la pisada callaba TAMBIEN los metalicos. Con el campo en false ya no hay
-- metalicos que callar, asi que esa fila deja de discriminar y hay que
-- reescribirla contra la pisada de superficie. La linea `la base metalicos …`
-- del reporte de este archivo lo va a decir sola.
ENT.MetallicMoveSounds = false

---------------------------------------------------------------------------
-- Las perillas
---------------------------------------------------------------------------
-- MISMA CONVENCION QUE LAS TRES DE PUERTAS Y LA DE MARCHA, a proposito:
-- 0 nadie ( control ) · 1 el flag del NPC · 2 todos. Cinco perillas con cinco
-- significados distintos para el mismo numero serian cinco formas de
-- equivocarse en juego, con la planilla en la mano.
--
-- El default es 1 y el flag arranca en false, o sea que POR EL FLAG las pisadas
-- suenan. El silencio del Myling es una propiedad de ESE tipo, no del motor.
--
-- ⚠ LA AYUDA DE ESTA CONVAR DECIA UNA MENTIRA Y LA RONDA 8b LA DESTAPO. Decia
-- "0 = ninguno camina en silencio ( control )", con la misma redaccion que las
-- tres de puertas. Alla es cierto porque hay UNA sola causa de silencio; aca hay
-- DOS, y esta convar solo gobierna una. La fila 04 de la r8b lo muestra al pie
-- de la letra: con stepsilent en 0 y el fantasma fuera del hunt, el reporte dice
-- CALLADA y el motivo es stepsonlyhunt.
--
-- O sea que la etiqueta prometia un control GLOBAL que el mecanismo no da. Y no
-- es cosmetico: la fila del control negativo se corrio mal DOS RONDAS SEGUIDAS,
-- y las dos veces el sintoma fue el mismo -- poner la convar en 0, seguir sin
-- oir nada, y no tener a mano que la otra causa estaba activa.
--
-- *Una perilla que se describe como control tiene que poder controlar, o
-- decir contra que no puede.*
local cvSilentSteps = CreateConVar( "phantasmagoria_ghost_stepsilent", "1", FCVAR_ARCHIVE,
    "Gobierna SOLO el flag phantom_SilentSteps: 0 = el flag no silencia a nadie · 1 = respeta el flag de cada NPC ( arranca en false: suenan ) · 2 = el flag silencia a TODOS. " ..
    "OJO: no es un control global -- phantasmagoria_ghost_stepsonlyhunt silencia por su cuenta fuera del hunt, y para que 0 se OIGA hacen falta las dos.", 0, 2 )

-- LA REGLA DE ESTADO, Y ES UNA COSA DISTINTA DEL FLAG. Va aparte por el mismo
-- motivo por el que cvUnlock esta aparte de cvOpen en las puertas: son dos
-- causas independientes del mismo efecto, y si comparten perilla el reporte no
-- puede decir cual de las dos silencio la pisada.
--
--   el flag    -> ESTE TIPO camina callado siempre ( el Myling de Diseno 5 )
--   la regla   -> CUALQUIER fantasma solo suena cuando esta manifestado
--
-- La regla sale del pedido del autor: en Phasmophobia el fantasma suena al
-- caminar EN HUNT y EN EVENTOS, no siempre. Hoy no hay eventos, asi que el hunt
-- es lo unico que se le puede atar -- cuando existan los eventos ( Diseno 19 ),
-- esta condicion crece ahi adentro y no en otro lado.
--
-- ⚠ EL DEFAULT EN 1 CAMBIA EL COMPORTAMIENTO DE HOY: deambulando, el fantasma
-- pasa a ser mudo. Se elige asi porque es lo que el autor describio como
-- objetivo, y porque deja al Paramic siendo la unica forma de ubicar a un
-- fantasma en calma, que es exactamente la experiencia de Phasmophobia.
-- Con 0 vuelve a sonar como antes de este bloque, y ese es el control negativo
-- de la fila.
--
-- Y ojo con la asimetria contra las puertas, que es deliberada: alli el ruido
-- se dejo PRENDIDO por default porque oir las puertas es lo que le dejo al
-- autor VER el comportamiento adentro de la casa. Aca el autor pidio lo
-- contrario de forma explicita. La diferencia no es de criterio: es que en un
-- caso lo pidio y en el otro no.
local cvOnlyHunt = CreateConVar( "phantasmagoria_ghost_stepsonlyhunt", "1", FCVAR_ARCHIVE,
    "1 = las pisadas solo se oyen CAZANDO ( Phasmophobia: hunt y eventos ) · 0 = se oyen siempre, como antes de este bloque ( control ).", 0, 1 )

---------------------------------------------------------------------------
-- Quien decide el silencio, y el motivo
---------------------------------------------------------------------------
-- EL NOMBRE DEL METODO NO ES EL DEL CAMPO, y eso es la ronda 4. El campo es
-- ENT.phantom_SilentSteps ( server.lua ) y el metodo es phantom_WantsSilentSteps.
-- Si se llamaran igual, el include pisaria el campo con la funcion, el
-- resolvedor leeria una funcion -- que no es true ni false -- y caeria a la
-- rama "el flag es nil", con un default que coincide con lo esperado. O sea: un
-- check verde sobre un flag ilegible. La guarda esta al final de server.lua y
-- cubre este flag tambien, porque sale de la misma tabla FLAGS.
function ENT:phantom_WantsSilentSteps()
    -- El resolvedor vive en server_doors.lua. Este archivo se incluye DESPUES,
    -- asi que en tiempo de ejecucion ya esta; la guarda existe para que un
    -- include roto diga QUE falto en vez de tirar un error por pisada.
    local resolver = PHANTASMAGORIA.ResolveFlag
    if not resolver then return false, "PHANTASMAGORIA.ResolveFlag no existe ( server_doors.lua no cargo )" end

    return resolver( self, "phantom_SilentSteps", cvSilentSteps, false )

end

-- LA DECISION COMPLETA, EN UN SOLO LUGAR, y devuelve el motivo por la misma
-- razon que resolve(): "no se oyo la pisada" tiene causas distintas que desde
-- afuera se ven igual -- el tipo es un Myling, el fantasma no esta cazando, o
-- la convar de control esta en 0. El reporte imprime cual.
--
-- El orden importa y es el del pedido: el flag del tipo gana, porque un Myling
-- camina callado TAMBIEN cazando, que es justamente lo que lo hace un Myling.
function ENT:phantom_StepsSilenced( myTbl )
    myTbl = myTbl or self:GetTable()

    local porFlag, motivo = self:phantom_WantsSilentSteps()

    if porFlag then
        return true, "el tipo camina callado ( " .. motivo .. " )"

    end

    -- LAS DOS CAUSAS, NO LA PRIMERA QUE GANA. Esta rama corta antes de que nadie
    -- llegue a ver que contesto la capa del flag, y eso hizo ilegible la fila del
    -- control negativo en las rondas 8 y 8b: el autor ponia stepsilent en 0,
    -- seguia sin oir nada, y el reporte solo nombraba stepsonlyhunt -- o sea que
    -- la perilla que acababa de mover NO APARECIA EN LA RESPUESTA.
    --
    -- *Un resolvedor que corta en la primera causa contesta por que hay silencio,
    -- pero no por que no lo apago lo que acabas de tocar.*
    if cvOnlyHunt:GetBool() and not myTbl.phantom_Hunting then
        return true, "no esta cazando, y phantasmagoria_ghost_stepsonlyhunt esta en 1" ..
            "   [ la otra capa, tapada por esta: " .. motivo .. " ]"

    end

    if not cvOnlyHunt:GetBool() then
        return false, "suenan siempre: stepsonlyhunt 0 ( control ), y " .. motivo

    end

    return false, "esta cazando, y " .. motivo

end

---------------------------------------------------------------------------
-- Los contadores
---------------------------------------------------------------------------
-- `pasos` y `vistas` NO son el mismo numero y esa es toda la gracia:
--
--   pasos    los llama la base a MakeFootstepSound. Son las pisadas REALES.
--   vistas   las que llegaron a AdditionalFootstep, o sea las que el gancho
--            pudo publicar.
--   perdidas la resta. Son las que footsteps.lua:330 descarto por no tener
--            sonido de superficie, y son las que el Paramic NO va a poder oir.
--
-- Si `perdidas` da 0 en una corrida entera, el agujero es teorico y se puede
-- dejar documentado. Si da un numero grande, el Paramic necesita otra fuente y
-- conviene saberlo AHORA y no cuando el Paramic no detecte nada.
local function stepStats( ghost )
    -- No hay un contador de saltos aca a proposito, aunque el salto sea uno de
    -- los seis call sites: no habria quien lo lea. La ronda 7 saco cuatro
    -- escrituras sin lector de server_doors.lua y la leccion es esa -- un campo
    -- que se escribe y nadie mira parece un registro autoritativo y no lo es.
    ghost.phantom_stepStats = ghost.phantom_stepStats or {
        pasos = 0, vistas = 0, calladas = 0, sonadas = 0, calladasCazando = 0,
    }

    return ghost.phantom_stepStats

end

---------------------------------------------------------------------------
-- La bitacora: TRANSICIONES, no pisadas
---------------------------------------------------------------------------
-- Una linea por pisada serian ~2,5 lineas por segundo caminando, y una bitacora
-- que hay que leer a 150 lineas por minuto no es una bitacora: es ruido que
-- tapa el dato. Lo informativo es CUANDO CAMBIA la decision y por que -- que es
-- lo unico que un A/B necesita leer.
--
-- Es la misma leccion que el reporte de puertas, al reves: alla el problema fue
-- que un numero no decia de que lado del A/B estaba; aca el problema seria que
-- el dato existe pero esta enterrado.
local BITACORA_MAX = 40

PHANTASMAGORIA.StepLog = PHANTASMAGORIA.StepLog or {}

local function anotarPaso( texto )
    local log = PHANTASMAGORIA.StepLog
    log[ #log + 1 ] = texto

    while #log > BITACORA_MAX do table.remove( log, 1 ) end

end

---------------------------------------------------------------------------
-- EL ENVOLTORIO QUE MIDE EL AGUJERO
---------------------------------------------------------------------------
-- Cuenta y delega, nada mas. NO reimplementa MakeFootstepSound -- la base pide
-- explicitamente que no se la sobreescriba ( footsteps.lua:214 ) y tiene razon:
-- adentro hay un shim de argumentos ( :224-228, si el primer parametro es un
-- numero es en realidad volumeMul ), la eleccion de superficie, y la tabla de
-- volumenes por material. Copiar todo eso para agregar un `+ 1` seria heredar
-- sus bugs futuros.
--
-- Por eso los argumentos pasan por ... verbatim: este envoltorio no puede
-- MIRARLOS sin arriesgarse a interpretar mal el shim.
function ENT:MakeFootstepSound( ... )
    local st = stepStats( self )
    st.pasos = st.pasos + 1

    return self.BaseClass.MakeFootstepSound( self, ... )

end

---------------------------------------------------------------------------
-- EL PUNTO DE EXTENSION DE VERDAD
---------------------------------------------------------------------------
-- Stub declarado por la base para exactamente esto ( footsteps.lua:203 ), con
-- su comentario: "if it returns true, blocks default sound playing". Devolver
-- true bloquea las TRES cosas que vienen despues -- el screenshake ( :334 ), el
-- clomping ( :340 ) y el EmitSound de la pisada ( :365 ) -- y ninguna otra.
function ENT:AdditionalFootstep( footPos, foot, stepSound, volume, filter )
    local myTbl = self:GetTable()
    local st    = stepStats( self )

    st.vistas = st.vistas + 1

    local callada, motivo = self:phantom_StepsSilenced( myTbl )

    -- ⚠ EL HECHO PRIMERO. ESTA LINEA VA ANTES DEL RETURN Y NO ES UN DETALLE DE
    -- ESTILO: es la restriccion entera de este bloque. La pisada ocurrio, con su
    -- posicion y su intensidad, la escuche el jugador o no. El consumidor
    -- ( Paramic, Diseno 7 ) se entera igual, y por eso `callada` viaja como
    -- DATO en vez de decidir si el evento existe.
    --
    -- Se declara ahora aunque el consumidor no exista, por lo mismo que
    -- PhantasmagoriaGhostUsedDoor: el productor es este bloque y el consumidor
    -- es otro. Si el gancho no esta, el bloque del Paramic tiene que volver a
    -- tocar este archivo -- y el que lo toque va a estar tentado de resolverlo
    -- borrando el silencio.
    hook.Run( "PhantasmagoriaGhostFootstep", self, {
        pos       = footPos,
        pie       = foot and "der" or "izq",
        sonido    = stepSound,
        volumen   = volume,
        -- `lvl` NO va: la base lo calcula despues de llamarnos ( footsteps.lua:365 ).
        -- Ver el encabezado. No se rellena con un numero inventado.
        velocidad = myTbl.GetCurrentSpeed( self ),
        cazando   = myTbl.phantom_Hunting == true,
        callada   = callada,
        motivo    = motivo,
    } )

    -- La transicion, para la bitacora. Se compara contra lo anterior de ESTE
    -- fantasma, asi que dos fantasmas con decisiones distintas no se pisan.
    if myTbl.phantom_stepLastSilent ~= callada or myTbl.phantom_stepLastWhy ~= motivo then
        myTbl.phantom_stepLastSilent = callada
        myTbl.phantom_stepLastWhy    = motivo

        -- EL EntIndex NO ALCANZA PARA NOMBRAR A UN FANTASMA, Y LA RONDA 8 LO
        -- MOSTRO: la bitacora de la fila 01 traia seis lineas todas con "#1340",
        -- y los pasos iban 1 -> 38 -> 182 -> 215 -> **1**. No es que un contador
        -- retrocediera: GMod REUSA el indice de una entidad borrada, asi que el
        -- fantasma que murio en el falltest y el que se spawneo despues salian
        -- con la misma etiqueta. Dos NPCs distintos leidos como uno.
        --
        -- GetCreationID es unico por entidad y por carga de mapa, asi que el
        -- corte se ve. *Una etiqueta que se repite entre dos objetos distintos
        -- no identifica: agrupa.*
        anotarPaso( "#" .. self:EntIndex() .. "/c" .. self:GetCreationID() .. "  " ..
            ( callada and "CALLADA" or "suena  " ) .. "   " .. motivo ..
            "   ( paso " .. st.pasos .. ", a " .. math.Round( myTbl.GetCurrentSpeed( self ) ) .. " u/s )" )

    end

    if callada then
        st.calladas = st.calladas + 1
        if myTbl.phantom_Hunting then st.calladasCazando = st.calladasCazando + 1 end

        return true

    end

    st.sonadas = st.sonadas + 1

    -- Y SE ENCADENA. El stub de la base devuelve nil hoy, asi que esto no
    -- cambia nada -- pero es gratis y evita que una version futura de la base
    -- que SI bloquee algo quede muda por nuestro override. Es el mismo patron
    -- que ShouldBeEnemy y ShouldRun.
    return myTbl.BaseClass.AdditionalFootstep( self, footPos, foot, stepSound, volume, filter )

end

---------------------------------------------------------------------------
-- LA OTRA MITAD: todo lo que rodea a la pisada
---------------------------------------------------------------------------
-- Sin esto el flag seria una mentira medible: un fantasma "callado" que salta y
-- aterriza seguiria emitiendo metal_canister_impact_soft2.wav y
-- flesh_impact_hard1.wav ( motionoverrides.lua:3000-3001 y :3462-3489 ), porque
-- la base trae MetallicMoveSounds = true y esos EmitSound cuelgan de
-- IsSilentStepping, no de AdditionalFootstep.
--
-- ⚠ Y ARRASTRA DOS COSAS QUE NO SON PISADAS. Se decide, no se hereda de rebote:
--
--   ① EL CLICK DE LA PUERTA ( shared.lua:1234 ). Ya tiene su propio flag
--      ( phantom_SilentDoors, que lo apaga adelantando nextUseSound ). Con esto
--      un fantasma con pisadas calladas y puertas ruidosas pierde igual el
--      click, aunque el chirrido de la hoja siga sonando. Se acepta a
--      proposito: un Myling que camina en silencio y despues hace click al
--      abrir seria el mismo tipo de mentira. Pero CONTAMINA EL A/B DE LAS
--      PUERTAS, asi que el reporte de puertas ahora nombra el estado de este
--      bloque, y este nombra el de aquel. Es la leccion de la ronda 7: *el
--      numero de un A/B tiene que decir de que lado del A/B esta.*
--
--   ② EL EMPUJON DEL Use2. En shared.lua:1234-1245 el ApplyForceCenter esta
--      DENTRO del mismo if que el click, o sea que silenciar tambien deja de
--      empujar lo que usa. Es un cambio de comportamiento, no de sonido. Ya
--      pasaba con phantom_SilentDoors por el mismo if, asi que esto no
--      introduce nada nuevo -- pero no estaba escrito en ningun lado.
function ENT:IsSilentStepping()
    local myTbl = self:GetTable()

    if self:phantom_StepsSilenced( myTbl ) then return true end

    return myTbl.BaseClass.IsSilentStepping( self )

end

---------------------------------------------------------------------------
-- LA FUGA QUE EL OVERRIDE DE ARRIBA ABRIA, Y NO ES UN SONIDO
---------------------------------------------------------------------------
-- Se censaron los cinco call sites de IsSilentStepping que NO son un EmitSound
-- directo, buscando cual se lleva puesto algo que no sea ruido:
--
--   overcharging.lua:37        el rayo del overcharge      efecto, no importa
--   motionoverrides.lua:3260   el splash del agua          efecto, no importa
--   motionoverrides.lua:3273   arranca el sonido de caida  sonido, es lo pedido
--   shared.lua:1234            el click de Use2            + el ApplyForceCenter
--   motionoverrides.lua:3578   LethalFallDamage            **+ el TakeDamage**
--
-- El ultimo es el grave. LethalFallDamage empieza con
--
--     if self:IsSilentStepping() then return end          -- :3578
--
-- y el self:TakeDamage( math.huge ) esta DENTRO de la funcion, en :3596. O sea
-- que ese return no se lleva solo los tres EmitSound: se lleva la muerte. Con
-- ENT.TakesFallDamage = true en la base ( shared.lua:144 ) y sin pisarlo
-- nosotros, el override de arriba le habria regalado al fantasma INMUNIDAD A LA
-- CAIDA LETAL ( > 2000 u, motionoverrides.lua:3239 y :3447 ) como efecto
-- secundario de un flag de sonido.
--
-- Es exactamente lo que ESTADO.md advertia sobre este interruptor -- "puede ser
-- lo que se quiere, pero hay que decidirlo y medirlo, no heredarlo de rebote" --
-- y la respuesta es que NO se quiere: esta ronda es sobre pisadas y no sobre
-- caidas. Este override CONSERVA el comportamiento de hoy. Si algun dia un tipo
-- tiene que ser inmune a las caidas, eso es ENT.TakesFallDamage = false, que es
-- el campo que la base declara para eso y que se lee como lo que es.
--
-- Ojo con el alcance: el dano de caida NORMAL ( :3497-3512 ) nunca colgo de
-- IsSilentStepping, asi que no estaba en riesgo y no se toca.
function ENT:LethalFallDamage()
    -- Sin silencio no hay nada que arreglar: manda la base entera.
    if not self:phantom_StepsSilenced() then
        return self.BaseClass.LethalFallDamage( self )

    end

    -- Silenciado: se reproduce lo que la base hace MENOS los sonidos y el
    -- screenshake, que es justo lo que el flag promete apagar.
    if self.TakesFallDamage then
        self:TakeDamage( math.huge )

    else
        -- La rama de :3599 es una pisada, y una pisada silenciada sigue siendo
        -- un HECHO: va por MakeFootstepSound para que la cuenten los contadores
        -- y para que el gancho la publique. AdditionalFootstep la va a callar
        -- sola, que es la unica capa que tiene que decidir eso.
        self:MakeFootstepSound( self:GetTable(), 1 )

    end
end

---------------------------------------------------------------------------
-- El instrumento
---------------------------------------------------------------------------
-- No colisiona con ninguna convar: las de este archivo son _stepsilent y
-- _stepsonlyhunt. Igual pasa por AddCommand, que es la guarda que costo dos
-- filas de la ronda 2.
PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_steps", function( ply, _, args )
    local say = PHANTASMAGORIA.MakeSay( ply )
    local sub = args and args[ 1 ]

    if sub == "reset" then
        local n = PHANTASMAGORIA.EachGhost( function( ghost )
            ghost.phantom_stepStats      = nil
            ghost.phantom_stepLastSilent = nil
            ghost.phantom_stepLastWhy    = nil

        end )

        PHANTASMAGORIA.StepLog = {}

        say( "[Phantasmagoria] contadores de pisadas reseteados en " .. n .. " fantasma(s), y bitacora vaciada." )
        return

    end

    ---------------------------------------------------------------------------
    -- EL BOTON: un consumidor de verdad, porque sin uno el check no existe
    ---------------------------------------------------------------------------
    -- LA PROMESA CENTRAL DE ESTE BLOQUE ES QUE EL PARAMIC VA A PODER OIR LAS
    -- PISADAS SILENCIADAS. Sin un consumidor eso no se puede provocar, y *un
    -- check cuya precondicion no se puede provocar no es un check* -- esa regla
    -- ya costo una ronda entera con el silencio de las puertas y se resolvio
    -- con un boton ( phantasmagoria_ghost_testdoor ). Este es el equivalente.
    --
    -- Y ES A PROPOSITO UN TERCERO: se engancha al hook publico y NO mira ningun
    -- contador nuestro. Si leyera phantom_stepStats estaria comprobando que
    -- nuestro contador cuenta, que es lo que ya hace el reporte; enganchado al
    -- hook comprueba lo unico que le importa al Paramic -- que el evento SALGA,
    -- con datos suficientes para ubicar al fantasma.
    --
    -- Por eso imprime la DISTANCIA al jugador y no la posicion cruda: es la
    -- cuenta que el microfono parabolico va a tener que hacer, y hacerla aca
    -- prueba que los datos alcanzan para hacerla.
    if sub == "listen" then
        local segs = math.Clamp( tonumber( args[ 2 ] or "" ) or 10, 2, 60 )

        -- Re-tipearlo mientras corre no apila dos oyentes: el segundo pisa al
        -- primero. Un instrumento que se duplica en silencio cuenta doble.
        hook.Remove( "PhantasmagoriaGhostFootstep", "phantasmagoria_steps_listen" )

        local oidas, calladas = 0, 0
        local muestras = {}
        local quien    = ply

        hook.Add( "PhantasmagoriaGhostFootstep", "phantasmagoria_steps_listen", function( ghost, paso )
            oidas = oidas + 1
            if paso.callada then calladas = calladas + 1 end

            if #muestras < 8 then
                local dist = IsValid( quien ) and math.Round( quien:GetPos():Distance( paso.pos ) ) or -1

                muestras[ #muestras + 1 ] = ( paso.callada and "CALLADA" or "suena  " ) ..
                    "  a " .. ( dist >= 0 and ( dist .. " u" ) or "?? u" ) .. " del jugador" ..
                    "  vol " .. math.Round( paso.volumen or 0, 2 ) ..
                    "  pie " .. tostring( paso.pie ) ..
                    "  " .. tostring( paso.sonido )

            end
        end )

        say( "[Phantasmagoria] ESCUCHANDO el hook PhantasmagoriaGhostFootstep durante " .. segs .. " s." )
        say( "    Caminar cerca del fantasma AHORA. El resumen sale solo al terminar." )

        timer.Simple( segs, function()
            hook.Remove( "PhantasmagoriaGhostFootstep", "phantasmagoria_steps_listen" )

            -- El say se rehace aca: el jugador pudo desconectarse en el medio, y
            -- MakeSay ya cae a la consola del servidor si el ply no es valido.
            local fin = PHANTASMAGORIA.MakeSay( quien )

            fin( "[Phantasmagoria] el oyente recibio " .. oidas .. " pisada(s) en " .. segs .. " s" ..
                "   ( " .. calladas .. " calladas · " .. ( oidas - calladas ) .. " sonadas )" )

            if oidas == 0 then
                -- UN CERO QUE HAY QUE SABER LEER, y por eso se separan las dos
                -- causas en vez de imprimir "no se recibio nada": que nadie
                -- caminara y que el gancho este roto dan el mismo cero.
                fin( "    0 = o el fantasma no camino en esos segundos ( mirar `pasos` en el reporte )," )
                fin( "        o el hook no se esta disparando, que es el defecto que este boton busca." )
                return

            end

            for _, linea in ipairs( muestras ) do fin( "    " .. linea ) end

            if calladas > 0 then
                fin( "    ^ las CALLADAS son la prueba: el jugador no las oyo y el consumidor SI las recibio." )

            end
        end )

        return

    end

    ---------------------------------------------------------------------------
    -- EL BOTON QUE FALTABA, Y LA RONDA 8 LO PAGO CON LA FILA 06
    ---------------------------------------------------------------------------
    -- La fila 06 ( "callar la pisada calla tambien lo que la rodea" ) pedia
    -- VERLO SALTAR Y ATERRIZAR, porque los sonidos metalicos de
    -- motionoverrides.lua:3000 y :3462-3489 solo existen ahi. Se escribio con su
    -- propia salida -- "si no salta ni una vez es Sin correr, no es un verde" --
    -- y aun asi se marco verde con la nota "no escuche nada ni saltos ni nada",
    -- que NO distingue "salto y no sono" de "nunca salto".
    --
    -- Y la culpa es del instrumento, no de quien corrio: de las ocho filas, esta
    -- era la unica cuya precondicion dependia de que el bot decidiera saltar
    -- solo. Las otras dos que necesitaban provocacion tenian boton ( listen,
    -- falltest ) y esta no. *Un check cuya precondicion no se puede provocar no
    -- es un check* -- la regla estaba escrita en la planilla y la incumpli
    -- escribiendo la planilla.
    --
    -- Fuerza el salto por el mismo ENT:Jump de la base ( motionoverrides.lua:2970 ),
    -- que es el que dispara el MakeFootstepSound de :2997 y los metalicos de
    -- :2999. O sea que ejerce el camino de verdad y no una imitacion.
    if sub == "jump" then
        local n = PHANTASMAGORIA.EachGhost( function( ghost )
            -- La guarda de la base ( :2971 ) se sale en silencio si no esta en el
            -- piso: sin decirlo, un salto que no ocurre se lee como un salto sin
            -- sonido, que es exactamente el verde falso que este boton evita.
            local enPiso = ghost.loco and ghost.loco:IsOnGround()

            if not enPiso then
                say( "#" .. ghost:EntIndex() .. "  NO SALTA: no esta en el piso, y ENT:Jump se sale sin avisar." )
                say( "    Esperar a que aterrice y repetir. Un salto que no ocurre suena igual que uno callado." )
                return

            end

            local antes = stepStats( ghost ).pasos

            ghost:Jump( ghost.JumpHeight or 60 )

            say( "#" .. ghost:EntIndex() .. "  SALTO FORZADO  ( altura " .. ( ghost.JumpHeight or 60 ) .. " )" )
            say( "    pasos " .. antes .. " -> " .. stepStats( ghost ).pasos ..
                "   ( el salto emite su propia pisada: motionoverrides.lua:2997 )" )
            say( "    ESCUCHA AHORA el aterrizaje. metalicos " .. tostring( ghost.MetallicMoveSounds ) ..
                " · clomping " .. tostring( ghost.FootstepClomping ) )

        end )

        if n == 0 then say( "[Phantasmagoria] no hay ningun fantasma vivo." ) end
        return

    end

    ---------------------------------------------------------------------------
    -- EL BOTON DE LA FILA QUE SE CORRIO MAL CUATRO RONDAS SEGUIDAS
    ---------------------------------------------------------------------------
    -- La fila es "que stepsilent 0 le gane a un flag en 1", y es la UNICA que
    -- convierte al 0 en un control: si el estado 0 no le gana a un flag que dice
    -- que SI, no controla nada. Se corrio mal en la r8, la r8b, la r9 y la r10, y
    -- cada vez por un paso distinto de una receta de cinco:
    --
    --   r8    la precondicion pedia hunt 1 y no estaba puesto
    --   r8b   las convars arrancaron en 2 y siguieron en 1, nunca pasaron por 0
    --   r9    el flag no se puso ( `override nil` en la propia salida )
    --   r10   se puso el flag y se saco, sin leer el reporte ni enganchar el oyente
    --
    -- *Cuatro modos de falla distintos sobre la misma fila no son cuatro
    -- descuidos: son una receta demasiado larga para ejecutarla a mano.* La
    -- respuesta que ya funciono dos veces en este proyecto es un boton -- el
    -- `listen` y el `jump` de la r8b -- asi que este corre los cinco pasos, mide,
    -- imprime el veredicto BINARIO y devuelve todo a donde estaba.
    --
    -- Y devuelve el estado a proposito: un boton de prueba que deja el servidor
    -- movido hace que la fila SIGUIENTE se corra sobre otra configuracion, que es
    -- como se torcieron tres filas de la ronda 8.
    if sub == "control" and args[ 2 ] == "off" then
        local v = PHANTASMAGORIA.StepControlVuelta

        if not v then
            say( "[Phantasmagoria] no hay nada que devolver: `control` no se corrio en esta sesion." )
            return

        end

        RunConsoleCommand( "phantasmagoria_ghost_stepsilent", tostring( v.convar ) )
        PHANTASMAGORIA.FlagOverrides[ "phantom_SilentSteps" ] = v.flag

        PHANTASMAGORIA.EachGhost( function( ghost )
            local antes = v.hunt[ ghost:GetCreationID() ]
            if antes ~= nil then ghost:phantom_SetHunting( antes ) end

        end )

        PHANTASMAGORIA.StepControlVuelta = nil

        say( "[Phantasmagoria] devuelto: stepsilent " .. v.convar ..
            " · flag " .. tostring( v.flag ) .. " · hunt como estaba." )
        return

    end

    if sub == "control" then
        local vueltaConvar = cvSilentSteps:GetInt()
        local vueltaFlag   = PHANTASMAGORIA.FlagOverrides[ "phantom_SilentSteps" ]
        local vueltaHunt   = {}

        PHANTASMAGORIA.EachGhost( function( ghost )
            vueltaHunt[ ghost:GetCreationID() ] = ghost.phantom_Hunting == true
            ghost:phantom_SetHunting( true )

        end )

        RunConsoleCommand( "phantasmagoria_ghost_stepsilent", "0" )
        PHANTASMAGORIA.FlagOverrides[ "phantom_SilentSteps" ] = true

        say( "[Phantasmagoria] CONTROL de stepsilent: los cinco pasos, corridos por el comando." )
        say( "    hunt -> SI · stepsilent -> 0 · flag pasos -> 1   ( se devuelve todo al terminar )" )

        -- La convar tarda un frame en tomar el valor: RunConsoleCommand encola.
        timer.Simple( 0.1, function()
            local fin = PHANTASMAGORIA.MakeSay( ply )

            fin( "    convar leida  stepsilent " .. cvSilentSteps:GetInt() ..
                ( cvSilentSteps:GetInt() == 0 and "" or "   <- NO llego a 0: el resto de esta fila no vale" ) )

            local visto = false

            PHANTASMAGORIA.EachGhost( function( ghost )
                local callada, motivo = ghost:phantom_StepsSilenced()

                visto = true

                fin( "    #" .. ghost:EntIndex() .. "  campo " .. tostring( ghost.phantom_SilentSteps ) ..
                    " · override " .. tostring( PHANTASMAGORIA.FlagOverrides[ "phantom_SilentSteps" ] ) ..
                    " · cazando " .. ( ghost.phantom_Hunting and "SI" or "NO" ) )
                fin( "    #" .. ghost:EntIndex() .. "  ahora mismo " .. ( callada and "CALLADA" or "SUENA" ) )
                fin( "        la decidio  " .. motivo )

                -- EL VEREDICTO, BINARIO Y ESCRITO POR EL COMANDO. Es la regla 6
                -- de la plantilla: si la conclusion sale de comparar dos cosas,
                -- la comparacion la hace el comando -- un criterio que exige
                -- cruzar tres lineas a mano invita a un veredicto inferido, y
                -- esta fila ya se cerro cuatro veces por inferencia.
                if callada then
                    fin( "        >>> FALLA: el flag en 1 le GANO a la convar en 0, o hay otra capa callando." )
                    fin( "            El estado 0 no es un control. Leer el motivo de arriba: nombra la capa que gano." )

                else
                    fin( "        >>> PASA: la convar en 0 le gano a un flag que dice que SI. ESO es un control." )

                end
            end )

            if not visto then
                fin( "    no hay ningun fantasma vivo: la fila es Sin correr." )

            end

            fin( "    Ahora: caminar cerca y correr `phantasmagoria_ghost_steps listen 15` para la otra mitad." )
            fin( "    Cuando termines: `phantasmagoria_ghost_steps control off` devuelve todo." )

        end )

        -- El estado a devolver se guarda en la mesa compartida y NO en un upvalue
        -- de este bloque: si el autor tipea el comando dos veces, el segundo
        -- guardaria como "original" el estado que dejo el primero.
        PHANTASMAGORIA.StepControlVuelta = PHANTASMAGORIA.StepControlVuelta or {
            convar = vueltaConvar, flag = vueltaFlag, hunt = vueltaHunt,
        }

        return

    end

    ---------------------------------------------------------------------------
    -- EL OTRO BOTON: la fuga de la caida letal
    ---------------------------------------------------------------------------
    -- La rama que este archivo tapa ( ver el override de LethalFallDamage ) se
    -- dispara con una caida de mas de 2000 u, y eso no se puede provocar en la
    -- mayoria de los mapas. Sin boton, esa fila seria "sin correr" para siempre
    -- y la fuga quedaria tapada por lectura y no por medicion.
    --
    -- ⚠ MATA AL FANTASMA, que es exactamente el punto: si NO lo mata con el
    -- silencio puesto, la fuga sigue abierta.
    if sub == "falltest" then
        local n = PHANTASMAGORIA.EachGhost( function( ghost )
            local callada, motivo = ghost:phantom_StepsSilenced()
            local antes = ghost:Health()

            ghost:LethalFallDamage()

            local vivo    = IsValid( ghost )
            local despues = vivo and ghost:Health() or 0

            say( "#" .. ( vivo and ghost:EntIndex() or "?" ) ..
                "  silencio " .. ( callada and "SI" or "NO" ) .. "  ( " .. motivo .. " )" )
            say( "    vida " .. antes .. " -> " .. despues .. ( vivo and "" or "   ( la entidad ya no existe )" ) )
            say( "    esperado: MUERE en los dos casos. Si sobrevive con silencio SI," ..
                " el return de motionoverrides.lua:3578 se llevo el TakeDamage." )

        end )

        if n == 0 then say( "[Phantasmagoria] no hay ningun fantasma vivo." ) end
        return

    end

    -- LA MITAD DE ENFRENTE DEL A/B, EN LA MISMA PANTALLA. Con guarda porque un
    -- instrumento mas fragil que lo que mide se rompe justo cuando hace falta:
    -- si server_doors.lua no cargo, esto tiene que decirlo y no caerse.
    local cvDoor = GetConVar( "phantasmagoria_ghost_doorsilent" )

    say( "[Phantasmagoria] convars: stepsilent " .. cvSilentSteps:GetInt() ..
        "   ( 0 nadie · 1 el flag del NPC · 2 todos )" )
    say( "    stepsonlyhunt " .. cvOnlyHunt:GetInt() ..
        ( cvOnlyHunt:GetBool() and "  ( solo suenan CAZANDO )" or "  ( suenan siempre: control )" ) )
    say( "    doorsilent    " .. ( cvDoor and cvDoor:GetInt() or "??" ) ..
        "  <- se imprime aca porque silenciar pisadas TAMBIEN se lleva el click de la puerta" )

    local vivos = PHANTASMAGORIA.EachGhost( function( ghost )
        local st = stepStats( ghost )
        local callada, motivo = ghost:phantom_StepsSilenced()

        say( "" )
        say( "#" .. ghost:EntIndex() .. "  " .. ( ghost.phantom_Hunting and "CAZANDO" or "en calma" ) ..
            "   a " .. math.Round( ghost:GetCurrentSpeed() ) .. " u/s" )

        say( "    ahora mismo   " .. ( callada and "CALLADA" or "SUENA" ) )
        say( "    la decidio    " .. motivo )

        -- El campo crudo al lado del veredicto, que es lo que destapo el pisado
        -- de la ronda 4: ahi el reporte imprimia "campo = function: 0x8088..."
        -- en cada linea y el check pasaba igual. Si esto dice algo que no sea
        -- true/false/nil, el flag esta pisado.
        say( "    campo         phantom_SilentSteps = " .. tostring( ghost.phantom_SilentSteps ) ..
            "   override " .. tostring( PHANTASMAGORIA.FlagOverrides[ "phantom_SilentSteps" ] ) )

        say( "    pasos " .. st.pasos .. " · el gancho vio " .. st.vistas ..
            " · calladas " .. st.calladas .. " ( " .. st.calladasCazando .. " cazando )" ..
            " · sonadas " .. st.sonadas )

        -- EL AGUJERO DE footsteps.lua:330, CON NUMERO. Se imprime SIEMPRE,
        -- incluso en 0: un 0 aca significa "la base no tiro ninguna pisada", y
        -- eso es un dato para el bloque del Paramic. Una linea que solo aparece
        -- cuando hay problema no deja distinguir "no hubo" de "no se midio".
        local perdidas = st.pasos - st.vistas

        say( "    PERDIDAS      " .. perdidas .. "   pisadas que ocurrieron y el gancho NO vio" ..
            ( perdidas > 0 and "  <- superficie sin sonido de pisada ( footsteps.lua:330 )" or "" ) )

        -- Lo que la base trae prendido, porque decide que MAS suena cuando la
        -- pisada se calla. Si alguien pone MetallicMoveSounds = false en un
        -- tipo, esta linea lo va a decir sin tocar el reporte.
        say( "    la base       metalicos " .. tostring( ghost.MetallicMoveSounds ) ..
            " · clomping " .. tostring( ghost.FootstepClomping ) ..
            " · pesado " .. tostring( ghost.ReallyHeavy ) ..
            " · modo " .. tostring( ghost.Term_FootstepMode ) )

    end )

    if vivos == 0 then
        say( "[Phantasmagoria] no hay ningun fantasma vivo." )
        return

    end

    local log = PHANTASMAGORIA.StepLog

    say( "" )
    say( "bitacora ( " .. #log .. " transiciones, no una linea por pisada ):" )

    if #log == 0 then
        -- UN VACIO QUE SIGNIFICA ALGO, y por eso se dice en vez de no imprimir
        -- nada. Sin fantasmas caminando la bitacora tiene que estar vacia; con
        -- un fantasma caminando y esto vacio, el que fallo es el override.
        say( "    ( vacia: o nadie camino todavia, o AdditionalFootstep no se esta llamando )" )

    end

    for _, linea in ipairs( log ) do
        say( "    " .. linea )

    end

end, "Reporte de las pisadas: quien decidio el silencio, cuantas se perdieron antes del gancho, y la bitacora de transiciones. " ..
    "'reset' limpia · 'listen [seg]' engancha un consumidor de prueba al hook y dice que recibio · " ..
    "'jump' fuerza un salto · 'control' corre la fila del control de stepsilent ENTERA y escribe el veredicto ( 'control off' devuelve todo ) · " ..
    "'falltest' MATA al fantasma para probar la caida letal." )
