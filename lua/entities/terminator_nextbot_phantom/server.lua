--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom / server

    Configuracion minima, EL INTERRUPTOR fantasma/cazador, y los instrumentos
    server-side:
      - el aviso de spawn (que modelo salio, donde, y si hay navmesh)
      - phantasmagoria_ghost_where, que dice donde esta cada fantasma vivo
      - phantasmagoria_ghost_rel, que dice a quien odia y por que
      - phantasmagoria_hunt / _reeval, el gatillo MANUAL y PROVISORIO del hunt
---------------------------------------------------------------------------]]

local function ghostPrint( ... )
    MsgC( Color( 190, 120, 255 ), "[Phantasmagoria] ", color_white, ... )

end

-- La mesa compartida del addon. Existe desde antes ( lua/phantasmagoria/ y el
-- espejo del cliente la usan ) y aca se crea a la defensiva porque este archivo
-- puede cargar primero. Sirve para que los archivos de al lado -- server_speed
-- y server_doors -- alcancen los helpers de este sin duplicarlos: include()
-- corre otro chunk, y un local no cruza.
PHANTASMAGORIA = PHANTASMAGORIA or {}
PHANTASMAGORIA.Print = ghostPrint

-- ANDAMIO. Overrides de flags puestos por consola, que GANAN sobre el campo de
-- la clase y valen tambien para los fantasmas que todavia no existen.
--
-- Nace de un problema real de la ronda 3: el autor no pudo probar los flags. El
-- lua_run que le di escribe en la ENTIDAD, y cada fantasma nuevo nace con el
-- default de su clase -- asi que el cambio se perdia al respawnear, sin que
-- nada lo dijera. Su propia conclusion fue "lo mejor es tener una toolgun dev
-- para agregar flags"; esto es la version barata de eso, y la toolgun sigue
-- siendo la buena cuando existan los 30 tipos.
--
-- Se borra con phantasmagoria_ghost_flag <nombre> auto.
PHANTASMAGORIA.FlagOverrides = PHANTASMAGORIA.FlagOverrides or {}

-- Segundos entre "spawneo con 0 navareas" y volver a medir. El parcheador de la
-- base trabaja de a poco, asi que medir en el mismo frame no dice nada.
local NAVCHECK_DELAY = 10

---------------------------------------------------------------------------
-- El modelo
---------------------------------------------------------------------------
-- Trampa 1 (Referencia 4.3): ENT.Models GANA sobre ENT.Model, y la base trae
-- ENT.Models = { "terminator" } heredado ( shared.lua:157 ). Un fantasma que
-- declare solo ENT.Model spawnea con Arnold, porque shared.lua:2973-2982 lee
-- Models primero y solo cae a Model si Models es nil.
--
-- El criterio de que un modelo sirva NO es el esqueleto: es que declare
-- $includemodel models/m_anm.mdl, porque la base mueve el cuerpo con
-- activities ACT_MP_* del set de player de HL2MP (Referencia 10).
-- EL SKIN VIAJA CON EL MODELO Y NO SUELTO, y no es prolijidad: el 1 se eligio
-- por lo que significa EN scaryblackman ( ojos blancos, Referencia 10 ) y no
-- quiere decir nada en otro modelo. Con el skin como campo aparte, cambiar de
-- modelo se lo lleva puesto en silencio -- shared.lua:2989 lo aplica si es
-- numero, sin preguntar si ese modelo tiene tantos skins.
local MODEL_CANDIDATES = {
    -- EL FANTASMA. Ghost_Girl_1 de Phasmophobia, ripeado y recompilado por este
    -- taller: 53 huesos ValveBiped, ragdoll de 15 solidos y las 8 actividades
    -- que la base pide portadas a NUESTRO esqueleto. Cerrado 7/7 como prop en la
    -- ronda 2 ( dev/checks/phantasmagoria-ghostrig-r2.html ).
    --
    -- skin en nil: tiene UN solo skin, y shared.lua:2989 aplica ModelSkin sin
    -- preguntar si ese indice existe.
    --
    -- ⚠ ESTE .mdl NO LLEGA A GITHUB. Es la condicion de la licencia del asset:
    -- models/phantasmagoria/ghost_girl* esta gitignoreado. O sea que en un clon
    -- limpio util.IsValidModel da false y pickModel cae al cadaver de abajo,
    -- avisando por ghostPrint. Eso es a proposito y no es un defecto: el que
    -- clona el repo tiene un fantasma que funciona, no un error.
    { mdl = "models/phantasmagoria/ghost_girl.mdl" },

    -- EL DE PRUEBAS, por pedido del autor ( 2026-08-06 ): el cadaver de HL2.
    -- Es el mismo que usa HIM sobre ESTA MISMA BASE ( him/.../homeless/shared.lua:12 ),
    -- que es la mejor evidencia posible de que sirve: no es un modelo parecido,
    -- es el mismo modelo corriendo en el mismo cerebro, en produccion.
    --
    -- OJO CON LA CARPETA, y esto ya costo caro una vez en este taller ( la
    -- lesson de hatman: dos archivos con el mismo nombre en carpetas distintas
    -- son binarios distintos ). Existen los dos:
    --
    --   models/humans/corpse1.mdl    el cadaver NPC/prop de HL2
    --   models/player/corpse1.mdl    el playermodel de GMod, con m_anm
    --
    -- y hace falta EL SEGUNDO, porque el criterio de la base no es el
    -- esqueleto sino el $includemodel models/m_anm.mdl. No hay que deducirlo:
    -- HIM trae una tabla de traduccion que hace exactamente ese mapeo
    -- ( sv_zhomeless_shelter.lua:52 ), o sea que el tercero ya tropezo y dejo
    -- escrito el arreglo.
    --
    -- Y no es el quemado: el quemado es "charple" ( humans/charple01 ->
    -- player/charple en la misma tabla ). corpse1 es el otro.
    { mdl = "models/player/corpse1.mdl" },

    -- El del DISENO, que vuelve cuando esta entidad deje de ser un instrumento.
    -- m_anm, hull identico al de Arnold, 54 flexcontrollers. Viene de otro addon
    -- del Workshop y NO esta en este repo.
    { mdl = "models/dejtriyev/scaryblackman.mdl", skin = 1 }, -- Referencia 10: skin 1 = ojos blancos

    -- Del que deriva el anterior. Viene con GMod.
    { mdl = "models/player/group01/male_04.mdl" },
}

local function pickModel()
    for _, cand in ipairs( MODEL_CANDIDATES ) do
        if util.IsValidModel( cand.mdl ) then return cand end

    end

    -- Ultimo recurso: la cadena literal "terminator", que shared.lua:2983
    -- traduce al modelo de la convar termhunter_modeloverride (Arnold por
    -- default). Feo a proposito: si sale Arnold, el modelo no esta montado.
    return { mdl = "terminator" }

end

local chosen = pickModel()

if chosen ~= MODEL_CANDIDATES[ 1 ] then
    ghostPrint( "el modelo ", MODEL_CANDIDATES[ 1 ].mdl, " no esta montado. Uso ", chosen.mdl, " en su lugar.\n" )

end

ENT.Models = { chosen.mdl }

-- Nil cuando el modelo no declara skin propio: shared.lua:2989 solo lo aplica
-- "if isnumber( myTbl.ModelSkin )", asi que nil deja el 0 del modelo y no
-- inventa un indice que ese .mdl puede no tener.
ENT.ModelSkin = chosen.skin

-- Si el elegido es el fantasma, se sabe aca y lo miran los dos bloques de abajo
-- ( el hull y la traduccion de actividades ). Los dos son correcciones para ESTE
-- modelo y aplicarselas al cadaver de HL2 -- que mide 76 u y trae las de m_anm
-- sin portar -- seria romperlo.
local esNuestroModelo = chosen.mdl == MODEL_CANDIDATES[ 1 ].mdl

---------------------------------------------------------------------------
-- ⚠ QUE ACTIVIDAD LLEGA AL MODELO, Y NO ES LA QUE DICE LA TABLA DE MOVIMIENTO
---------------------------------------------------------------------------
-- La base NO le pide al modelo una secuencia por nombre: le pide una ACTIVIDAD,
-- y el engine elige entre las secuencias que la declaran. La cadena, censada en
-- el codigo:
--
--   SetupMotionType    motionoverrides.lua:3742  -> uno de 8 ..._MOTIONTYPE_*
--   MotionTypeActivities    motion.lua:14        -> un ACT_MP_*
--   TranslateActivity  motionoverrides.lua:3681
--     -> IdleActivityTranslations :3668          -> ACT_HL2MP_IDLE + N
--   StartActivity      motion.lua:173            -> SelectWeightedSequence( act )
--
-- O SEA QUE EL ACT_MP_* NUNCA LLEGA AL MODELO. El handoff de este bloque decia
-- que el QC lleva `activity ACT_MP_RUN`; eso habria declarado una actividad que
-- nadie pide, y el fantasma habria seguido tomando las prestadas de m_anm.
--
-- ⚠ Y POR QUE SE PISA LA TABLA EN VEZ DE USAR LA HEREDADA: la de la base arma
-- las actividades con ARITMETICA sobre el enum ( IdleActivity + 1, + 2, ... ),
-- o sea que depende del orden exacto de los ACT_HL2MP_* en el enum de Lua. Ese
-- orden yo NO lo medi: lo derive, y la derivacion cierra con tres cosas del
-- .mdl de m_anm ( existen SWIM_IDLE y SWIM por separado, lo que justifica que
-- el +9 sea SWIM; y ACT_HL2MP_JUMP no tiene NI UNA secuencia, que es lo que
-- explica el comentario 'no normal jump anim' del +7 ). Cierra, pero derivar no
-- es medir.
--
-- Nombrando las actividades no queda nada que derivar: sea cual sea el numero,
-- el nombre resuelve al mismo. Es el punto de extension que la propia base
-- documenta ( "custom anim translation support" ), no un parche encima.
--
-- LAS DOS QUE NO SON EL PATRON, y las dos salieron de medir m_anm y no de leer
-- el enum:
--   JUMP    va a ACT_HL2MP_JUMP_SLAM porque ACT_HL2MP_JUMP no tiene secuencia.
--   RELOAD_CROUCH la base lo manda al +7, que bajo el patron de 10 ranuras por
--     arma es ACT_HL2MP_JUMP y no una recarga. Da igual para nosotros -- un bot
--     sin arma no recarga nunca -- pero se deja escrito para no "arreglarlo"
--     despues creyendo que es nuestro.
if esNuestroModelo then
    ENT.IdleActivity = ACT_HL2MP_IDLE
    ENT.IdleActivityTranslations = {
        [ ACT_MP_STAND_IDLE ]                = ACT_HL2MP_IDLE,
        [ ACT_MP_WALK ]                      = ACT_HL2MP_WALK,
        [ ACT_MP_RUN ]                       = ACT_HL2MP_RUN,
        [ ACT_MP_CROUCH_IDLE ]               = ACT_HL2MP_IDLE_CROUCH,
        [ ACT_MP_CROUCHWALK ]                = ACT_HL2MP_WALK_CROUCH,
        [ ACT_MP_JUMP ]                      = ACT_HL2MP_JUMP_SLAM,
        [ ACT_MP_SWIM ]                      = ACT_HL2MP_SWIM,
        [ ACT_LAND ]                         = ACT_LAND,

        -- Estas dos las hereda la base y NO tenemos secuencia propia: un bot con
        -- DefaultWeapon = false no dispara ni recarga nunca, asi que si alguna
        -- vez llegan, que caigan en las de m_anm y se vea. Declararlas apuntando
        -- a una nuestra que no existe seria peor.
        [ ACT_MP_ATTACK_STAND_PRIMARYFIRE ]  = ACT_HL2MP_GESTURE_RANGE_ATTACK,
        [ ACT_MP_ATTACK_CROUCH_PRIMARYFIRE ] = ACT_HL2MP_GESTURE_RANGE_ATTACK,
    }

end

---------------------------------------------------------------------------
-- ⚠ EL HULL CON EL QUE CAMINA, QUE LO PONE LA BASE Y NO EL MODELO
---------------------------------------------------------------------------
-- MEDIDO, y es el numero que decide como se ve el fantasma:
--
--   ENT.CollisionBounds de la base ... (-16,-16,0) .. (16,16,72)
--       terminator_nextbot_base/init.lua:39, CLAVADO. InitializeCollisionBounds
--       ( motionoverrides.lua:3855 ) solo lo multiplica por GetModelScale(), que
--       es 1. O sea: el mismo hull para todos los modelos.
--   malla del fantasma ............... 44,94 u de alto  ( leida del .vvd )
--   su hull de COLISION del .mdl ..... -7,9 .. 46,65
--
-- ⚠ LOS DOS ULTIMOS NUMEROS NO SON LO MISMO Y CONFUNDIRLOS YA MORDIO DOS VECES
-- EN ESTE TALLER: 104/116 del studiohdr es el hull de la FISICA ( sale del .phy
-- del ragdoll ) y no dice nada sobre la malla ni sobre por donde camina el bot.
-- La malla se mide en el .vvd, que es de donde salen los 44,94.
--
-- LO QUE EL HULL DE 72 LE HACE A UN CUERPO DE 45, medido en la formula de la
-- base y no mirandolo:
--
--   ViewOffset = round( maxsZ - (maxsZ/72) * 8 )   motionoverrides.lua:3883-3885
--
--   con 72 -> 64 . La cabeza de la nena termina en 44,7, asi que los OJOS del
--   fantasma quedan 19 u POR ENCIMA DE SU PROPIA CABEZA, en el aire. Y no es
--   cosmetico: ese punto es el origen de CanSeePosition ( shared.lua:239 ), o
--   sea que el fantasma ve desde donde no tiene cabeza, y `EntShootPos` lo
--   convierte tambien en el punto al que los demas trazan.
--
-- ⚠ LA HIPOTESIS DE QUE FLOTABA ES FALSA, Y LA MEDICION LA REFUTO. El plan de
-- este bloque decia "un cuerpo de 45 adentro de un hull de 72 flota". No: el
-- mins.z del hull es 0 y el origen del modelo esta en los pies ( el SMD va de
-- -0,22 a 44,72, que es la convencion de Source y por eso el QC usa --no-center ).
-- El hull no la levanta del piso -- le sobran 27 u ARRIBA de la cabeza. El
-- sintoma real no es que flote, es que ve y la ven desde el aire.
--
-- EL NUMERO NUEVO SALE DE UNA SOLA MEDICION Y UN SOLO FACTOR: 44,94 / 72 =
-- 0,624, aplicado tambien al ancho ( 16 -> 10 ). Asi el fantasma queda con la
-- misma proporcion hull/cuerpo que un jugador, que es lo que la base asume en
-- todas sus cuentas. No se elige un ancho "que parezca bien": se escala el que
-- ya estaba por lo unico que cambio.
--
-- LO QUE LA BASE DERIVA SOLA de esto, y por eso no hay que tocarlo:
--   ViewOffset ......... round( 45 - (45/72)*8 )   = 40  -> adentro de la cabeza
--   CrouchCollisionBounds maxs.z = 45 * 0,6        = 27
--   CrouchViewOffset ... round( 27 - (27/43)*11 )  = 20
--
-- ⚠ Y UNA CONSECUENCIA DE DISENO QUE HAY QUE ESCRIBIR ANTES DE QUE SORPRENDA:
-- Diseno 18.2.1 saco la cuenta de "que caja me tapa" con los ojos del bot en 64
-- ( H > 64 - 46*t ). Con el hull nuestro los ojos van a 40 y la cuenta pasa a
-- ser H > 40 - 22*t: TODOS los escondites se vuelven mas faciles, porque el
-- fantasma es mas bajo. Es correcto y es un cambio de balance, no un efecto
-- secundario -- el que revise Diseno 18 tiene que releerlo con 40.
--
-- Va por convar y no clavado porque es lo unico que hace el A/B posible: en 0
-- el fantasma camina con el hull de 72 de la base, que es el comportamiento de
-- hoy y el control negativo de la fila del hull.
local cvHull = CreateConVar( "phantasmagoria_ghost_hull", "1", FCVAR_ARCHIVE,
    "El fantasma usa un hull proporcional a SU cuerpo ( 20x20x45 ) en vez del de la base " ..
    "( 32x32x72, clavado en terminator_nextbot_base/init.lua:39 ). " ..
    "En 0 usa el de la base: los ojos le quedan 19 u sobre la cabeza. Sirve de control negativo. " ..
    "Se lee AL SPAWNEAR, asi que cambiarla no afecta a los fantasmas ya vivos.", 0, 1 )

-- 44,94 del .vvd, redondeado. El ancho es 16 * ( 45 / 72 ).
local HULL_ALTO  = 45
local HULL_ANCHO = 10

---------------------------------------------------------------------------
-- Desarmado
---------------------------------------------------------------------------
-- El molde es terminator_nextbot_fakeply: un bot desarmado que funciona.
-- Consecuencias medidas en el codigo, no cosmeticas:
--   sin TERM_FISTS no mira hacia el objetivo al moverse ( motionoverrides.lua:2838 )
--   sin TERM_FISTS no pega para desatascarse ( shared.lua:2142 )
-- Las dos son correctas para un fantasma, pero explican comportamiento raro.
ENT.DefaultWeapon = false
ENT.TERM_FISTS    = false

---------------------------------------------------------------------------
-- ATRAVIESA LAS PUERTAS
---------------------------------------------------------------------------
-- Un fantasma de Phasmophobia atraviesa las puertas; el Alternate de Mandela
-- Catalogue ( docs/ALTERNATE.md ) NO. Por eso esto es un FLAG DE CLASE y no una
-- convar: cada NPC del addon decide, y la convar
-- phantasmagoria_ghost_phasedoors solo existe para pisarlo en las dos
-- direcciones durante una corrida.
--
-- Heredable por el arbol de bases: los 30 tipos de Diseno 12.2 van a colgar de
-- esta clase y lo reciben en true sin escribir nada; el Alternate, cuando
-- exista, pone false y con eso alcanza.
--
-- ATRAVESAR Y ABRIR SON DOS COSAS Y LAS DOS SIGUEN PRENDIDAS, que es lo que
-- pidio el autor en los dos mensajes: atravesar es lo que garantiza que PASE
-- ( antes se trababa 3,6 s contra un func_door_rotating ), y abrir es lo que
-- deja la HUELLA, que fue el motivo por el que se eligio abrir en vez de
-- atravesar en el bloque anterior. Se apagan por separado
-- ( phantasmagoria_ghost_opendoors 0 deja el atravesado sin la apertura ).
ENT.phantom_PhasesDoors = true

-- Abrir puertas cerradas, tambien por NPC. Pedido del autor en la ronda 2, y
-- sale de una observacion suya: "intenta casi siempre abrir puertas". El flag
-- es lo que deja que eso sea una caracteristica de ALGUNOS tipos y no del motor
-- -- en Phasmophobia abrir una puerta es un EVENTO, no una constante.
--
-- OJO CON LO QUE ESTO NO ES: el flag prende y apaga la capacidad, no su
-- frecuencia. Que "casi siempre" intente abrir sigue siendo cierto con el flag
-- en true, y si lo que molesta es la frecuencia hace falta otra cosa
-- ( un intervalo o una probabilidad por tipo, que es Diseno 5 ). Se deja dicho
-- para que no se lea como resuelto.
ENT.phantom_OpensDoors = true

-- Y el silencio, que arranca APAGADO a proposito. El ruido de las puertas es lo
-- que le dejo al autor ver el comportamiento del fantasma adentro de la casa,
-- asi que sacarlo por default seria sacarle un instrumento. El flag existe para
-- los tipos que tienen que ser sigilosos -- el Myling de Diseno 5 camina en
-- silencio cazando, y es exactamente esto.
ENT.phantom_SilentDoors = false

-- Caminar cazando, tambien por NPC. Sale de una observacion del autor en la
-- ronda 3 -- "suele caminar al hacer hunting y correr cuando no me ve; podria
-- correr igualmente directo a mi" -- y la causa esta medida en la base:
-- canDoRun se niega si el bot no esta enojado, TE VE y tiene la vida entera.
-- El detalle en server_speed.lua.
--
-- Arranca en false: cazando CORRE. El flag existe para los tipos que acechan
-- caminando ( el Deogen de Diseno 5, que se arrastra cuando esta cerca ).
ENT.phantom_WalksWhenHunting = false

-- Y las PISADAS, pedido del autor del 2026-08-07. Mismo molde que el silencio
-- de las puertas: arranca en false ( suenan ) y el flag existe para el tipo que
-- camina callado, que es el Myling de Diseno 5.
--
-- OJO CON LEER ESTE false COMO "el fantasma hace ruido siempre": el flag es UNA
-- de las dos causas de silencio. La otra es la regla de estado
-- ( phantasmagoria_ghost_stepsonlyhunt, default 1 ), que calla a CUALQUIER
-- fantasma fuera del hunt porque en Phasmophobia el fantasma suena al caminar
-- en hunt y en eventos, no siempre. Las dos viven en server_steps.lua y el
-- reporte dice cual gano.
--
-- Y la restriccion que lo separa del silencio de puertas, que es la inversa:
-- aca la pisada TIENE QUE SEGUIR OCURRIENDO como evento, porque el Paramic
-- ( Diseno 7 ) la va a tener que oir. Silenciar es "que no se oiga", no "que no
-- pase". El detalle esta en el encabezado de server_steps.lua.
ENT.phantom_SilentSteps = false

---------------------------------------------------------------------------
-- EL INTERRUPTOR FANTASMA / CAZADOR
---------------------------------------------------------------------------
-- Fuera del hunt el fantasma NO ataca; dentro, si. Arranca en fantasma.
--
-- OJO: esto cambia la fila 4 del check anterior. Ese check pedia "camina hacia
-- el jugador" y por eso el bot quedaba hostil A PROPOSITO. Con este campo en
-- false ya NO persigue al spawnear: la fila 4 vale solo con hunt = 1.
ENT.phantom_Hunting = false

-- El interruptor NO es OnFirstRelationWithPlayer, y esa es la correccion mas
-- cara de este bloque. Diseno 3.1 dice "al entrar en hunt se re-evaluan
-- relaciones y la base hace el resto sola". Leyendo el codigo, nada dispara esa
-- re-evaluacion, y peor: la relacion NO SIRVE como interruptor. El recorrido:
--
--   SetupRelationships corre UNA sola vez, desde Initialize ( shared.lua:3079 ).
--   Por cada entidad llama SetupEntityRelationship -> GetDesiredEnemyRelationship
--   -> OnFirstRelationWithPlayer, y GUARDA el resultado en m_EntityRelationships
--   con Term_SetEntityRelationship ( enemyoverrides.lua:883, y el cuerpo del
--   guardado en terminator_nextbot_base/enemy.lua:44-47 ). Es un CACHE. El
--   nombre lo venia diciendo: OnFIRSTRelationWithPlayer.
--
-- Y hay un segundo motivo, mas fuerte, que sale de leer MakeFeud
-- ( enemyoverrides.lua:1046-1048 ): cuando al bot le pegan, PostTookDamage
-- ( damageandhealth.lua:482 ) llama MakeFeud, que para un jugador reescribe la
-- relacion a D_HT con prioridad 1000, sin preguntarle nada a nadie. O sea que un
-- interruptor hecho de relaciones se REABRE de un balazo, y no se vuelve a
-- cerrar nunca porque nada re-evalua el cache.
--
-- El interruptor de verdad es ShouldBeEnemy, que es donde la base LEE ese cache
-- ( enemyoverrides.lua:493 ) y que se consulta EN VIVO todo el tiempo:
--   FindEnemies / processFindingEnt  enemyoverrides.lua:596   ( ruta 1 de 18.7 )
--   ForgetOldEnemies                 enemyoverrides.lua:676   ( limpia memoria )
--   FindPriorityEnemy                enemyoverrides.lua:719   ( elige enemigo )
--   el fallback "sin enemigos"       shared.lua:3203          ( ruta 3 de 18.7 )
--   revalidar el enemigo anterior    shared.lua:3282
--   HaveEnemy                        terminator_nextbot_base/enemy.lua:136
--
-- Un false ahi no congela nada: el cerebro sigue corriendo entero y las 31
-- tareas siguen ahi. Es literalmente lo que pide Diseno 3.1 en su ultima linea
-- -- "el bot nunca deja de pensar, solo deja de tener a quien odiar" -- solo que
-- en la funcion de al lado. Y NO es DisableBehaviour: saltear no es apagar.
---------------------------------------------------------------------------
-- ⚠ EL ALCANCE DE LA VISTA, Y ES UN LIMITE QUE LA BASE LE SACA A LOS JUGADORES
---------------------------------------------------------------------------
-- MEDIDO EN LA RONDA 13b: el fantasma tomo al jugador de enemigo a **31.253 u**
-- ( 542 m en la mira del rifle ) del otro lado de gm_flatgrass, con
-- `mirada vs jugador 0 grados` y `movement_stalkenemy` corriendo. La cadena
-- funcionaba perfecto; el problema es que funciona DEMASIADO LEJOS.
--
-- No es un bug: la base lo hace a proposito y con dos mecanismos.
-- `ShouldBeEnemy` ( enemyoverrides.lua:507-515 ) descarta por distancia a todo
-- lo que NO sea jugador, y a los jugadores los exime en su propio comentario
-- ( "ignore maxSeeingDist for plys" ), dejandoles solo la niebla. Y
-- `enemy_handler` tiene ademas la rama "cheap infinite view distance"
-- ( shared.lua:3185 ), que existe justamente para verte sin limite.
--
-- Para un terminator es correcto -- te caza por todo el mapa. Para un fantasma
-- de Phasmophobia no: el hunt es adentro de una casa. *Un default de la base que
-- es correcto para lo que ella es puede ser un defecto de diseno para lo que uno
-- construye encima.*
--
-- EL LIMITE VA ACA Y NO EN LOS CUATRO SITIOS, y ese es el motivo de que sea
-- barato: ShouldBeEnemy es la puerta que consultan los cuatro
-- ( FindEnemies/processFindingEnt :596, ForgetOldEnemies :676, FindPriorityEnemy
-- :719, y la rama de distancia infinita :3202 ), asi que un solo gate corta la
-- adquisicion Y hace que se olvide al alejarte, sin tocar ninguno.
--
-- ⚠ EL NUMERO NO ES MIO: 3000 es `MaxSeeEnemyDistance`, el que la base ya usa
-- para todo lo demas. Poner otro seria inventar un balance que Diseno todavia no
-- fijo; poner el de ella es restaurar la simetria que ella misma rompio solo
-- para los jugadores. `0` = sin limite, que es el comportamiento medido en la
-- r13b y sirve de control.
-- ⚠ Y TAPA TAMBIEN LA ENTRADA LATERAL, que es la mitad que nadie evalua: pegarle
-- un tiro dispara MakeFeud ( damageandhealth.lua:482 -> enemyoverrides.lua:1046,
-- "hate players more than anything else" ), que reescribe la relacion a D_HT con
-- prioridad 1000. Pero MakeFeud escribe la RELACION y este gate corta ANTES de
-- que la relacion se lea, asi que **un fantasma baleado desde lejos ya no viene**.
-- Medido sin querer en la r14: el autor le pego entre dos filas y las cuatro
-- lecturas siguientes tienen `vida 827/900` con `rel D_HT pri 1000` y
-- `ShouldBeEnemy NO` a 20.879 u. *Un limite puesto delante de una cadena tambien
-- tapa las entradas laterales de esa cadena, y las laterales son las que nadie
-- recuerda.* Queda asi a proposito -- en Phasmophobia al fantasma no se le
-- dispara -- pero es una decision, no un descuido, y el instrumento la dice.
local cvSightDist = CreateConVar( "phantasmagoria_ghost_sightdist", "3000", FCVAR_ARCHIVE,
    "Distancia maxima a la que el fantasma puede tomar a un JUGADOR de enemigo, en unidades. " ..
    "0 = sin limite ( el comportamiento de la base, medido en la r13b: te toma a 31.253 u del otro lado del mapa ). " ..
    "El default es MaxSeeEnemyDistance, que es el limite que la base ya aplica a todo lo que no sea jugador. " ..
    "OJO: tapa tambien a MakeFeud, o sea que un fantasma baleado desde mas lejos que esto NO viene a buscarte.", 0, 50000 )

function ENT:ShouldBeEnemy( ent, fov, myTbl, entsTbl )
    myTbl = myTbl or self:GetTable()

    -- Fuera del hunt no hay enemigos. Ni jugadores ni NPCs: Diseno 3.1 dice
    -- "deja de tener a quien odiar", no "a quien odiar menos".
    if not myTbl.phantom_Hunting then return false end

    -- Solo a JUGADORES, y no por prolijidad: a los NPCs la base ya les aplica su
    -- propio tope ( :513 ). Meternos ahi seria poner un segundo limite sobre uno
    -- que ya existe, y despues no se sabria cual de los dos corto.
    local tope = cvSightDist:GetInt()

    if tope > 0 and ent:IsPlayer() and self:GetRangeTo( ent ) > tope then return false end

    return myTbl.BaseClass.ShouldBeEnemy( self, ent, fov, myTbl, entsTbl )

end

-- CONSECUENCIA MEDIDA EN EL CODIGO, no cosmetica: shared.lua:1387 usa
-- ShouldBeEnemy sobre lo que le bloquea el paso -- "not ShouldBeEnemy( blocker )"
-- -> openDoorTime = CurTime(), o sea ABRIR en vez de ROMPER. Con el interruptor
-- en fantasma esa rama se toma siempre. Es la que queremos, pero hay que
-- saberlo antes de leerlo como bug.

-- Este es el override que Diseno 3.1 nombraba, y aca queda como INSTRUMENTO y
-- no como mecanismo: cuenta cuantas veces la base evalua la relacion y con que
-- flag. Si 3.1 tuviera razon, prender el hunt la haria subir. El control de que
-- el contador no este simplemente roto es phantasmagoria_hunt_reeval, que la
-- dispara a mano: si ese comando lo mueve y prender el hunt no, el contador
-- funciona y lo que no ocurre es la re-evaluacion.
--
-- Trampa 1 ( Referencia 4.2b ): la implementacion default NO esta vacia --
-- implementa ExtraSpawnHealthPerPlayer ( damageandhealth.lua:872 ) -- asi que
-- hay que ENCADENAR al BaseClass o se mata en silencio. Hoy no duele porque no
-- declaramos el campo, y por eso mismo el defecto seria invisible.
--
-- Trampa 2 ( Referencia 4.2c ): la llamada pasa CUATRO argumentos
-- ( enemyoverrides.lua:947 ) y la declaracion de la base nombra uno. Se nombran
-- los cuatro aca para que se lea que existen.
--
-- Devuelve lo que devuelva el BaseClass, que es nil: enemyoverrides.lua:948 hace
-- "if newDisp then disp = newDisp end", asi que un nil deja pasar el D_HT de
-- :942. La relacion del fantasma con el jugador queda en D_HT SIEMPRE, a
-- proposito: un D_NU aca trabaria el interruptor cerrado para siempre, porque
-- la base exige D_HT en :493 y nada re-evalua el cache.
function ENT:OnFirstRelationWithPlayer( ply, disp, priority, theirDisp )
    self.phantom_relCalls       = ( self.phantom_relCalls or 0 ) + 1
    self.phantom_relLastTime    = CurTime()
    self.phantom_relLastHunting = self.phantom_Hunting == true

    return self.BaseClass.OnFirstRelationWithPlayer( self, ply, disp, priority, theirDisp )

end

-- La puerta unica para prender y apagar. Cuando exista la cordura ( Diseno 19 )
-- va a llamar a ESTO y no a tocar el campo, asi que el networkeo no se puede
-- olvidar en el camino.
--
-- SetNWBool y NO SetupDataTables: trampa 3 ( Referencia 4.3 ) dice que la base
-- networkea con slots hardcodeados y el Bool 0 ya es Crouching. Los NW vars van
-- por nombre y son otro sistema; ademas la base no usa ninguno ( grep de
-- SetNWBool/SetNW2Bool sobre sus 71 archivos: cero ).
function ENT:phantom_SetHunting( hunting )
    hunting = hunting == true

    self.phantom_Hunting = hunting
    self:SetNWBool( "phantasmagoria_hunting", hunting )

    return hunting

end

function ENT:phantom_IsHunting()
    return self.phantom_Hunting == true

end

---------------------------------------------------------------------------
-- Que mire hacia donde camina cuando NO esta cazando
---------------------------------------------------------------------------
-- DEFECTO MEDIDO EN JUEGO (corrida 7): en calma el yaw se congela y no se mueve
-- mas. Once lecturas con "mira yaw 141.7" mientras el bot cruzaba el mapa, y una
-- de ellas con "mirada vs marcha 179.9 grados", o sea caminando EXACTAMENTE de
-- espaldas. En hunt, en cambio, "mirada vs jugador" da 0.0-1.5 grados: te apunta
-- clavado.
--
-- LA CAUSA NO ES LA QUE YO HABIA ESCRITO, y el numero que lo corrige es uno:
-- terminator_Extras.term_DefaultSpeedToAimAtProps = 30^2 ( motionoverrides.lua:1735 ),
-- comparado contra Length2DSqr, o sea un umbral de 30 u/s. Yo habia anotado el
-- gate de TERM_FISTS ( :2838 ) como el motivo, y es solo la mitad: aun CON puños
-- ese camino pide ademas velocidad POR DEBAJO de 30 u/s, y este bot camina a 130
-- y corre a 550. Devolverle los puños NO lo habria arreglado -- habria sido una
-- ronda entera gastada en el arreglo obvio.
--
-- El motivo de verdad es mas simple: de los cuatro sitios que llaman
-- SetDesiredEyeAngles, el unico que puede correr caminando es el del ENEMIGO
-- ( enemyoverrides.lua:1874 ). Un terminator normal siempre tiene enemigo, asi
-- que siempre mira; nuestro fantasma en calma no tiene ninguno A PROPOSITO, y
-- ahi no queda nadie que le mueva la cara. Los otros dos son caida y salto
-- ( motionoverrides.lua:3306 y :3311 ).
--
-- ⚠ Y LA CADENA EXACTA ES MAS CERRADA TODAVIA, leida en la ronda 12 y peor de
-- lo que este comentario decia. enemyoverrides.lua:1874 vive adentro de
-- Term_LookAround, y a Term_LookAround la llama UN solo sitio: shooting_handler
-- ( shared.lua:3512 ). Pero cinco lineas antes, :3492-3506, esta esto:
--
--     local wep = GetActiveLuaWeapon( self ) or GetActiveWeapon( self )
--     if not IsValid( wep ) then
--         if TERM_FISTS then ... return
--         elseif IsValid( enemy ) then shootAt( LastEnemyShootPos ) return
--         else return                       -- <- NOSOTROS, SIEMPRE
--         end
--     end
--     ...
--     Term_LookAround( self )               -- <- INALCANZABLE para el fantasma
--
-- El fantasma pone DefaultWeapon = false y TERM_FISTS = false ( :125-126 ), asi
-- que `wep` nunca es valido y ese bloque se sale ANTES de Term_LookAround en los
-- tres caminos. O sea: para este bot el UNICO escritor de la mirada es
-- shootAt( LastEnemyShootPos ), y ese pide un enemigo valido. *Sin enemigo no
-- hay nadie que le mueva la cara, tenga o no tenga hunt.*
--
-- No es cosa de HIM ni de la base: HIM tambien pone TERM_FISTS = false
-- ( him/.../terminator_nextbot_homeless/server.lua:22 ), igual que
-- terminator_nextbot_fakeply:35 y csoldier:26. Lo que HIM y el terminator tienen
-- y nosotros no es un enemigo permanente.
--
-- El arreglo es la mitad que falta y nada mas: cuando no hay a quien mirar, mirar
-- hacia donde se camina. Es lo mismo que hace la base al saltar
-- ( motionoverrides.lua:3311, SetDesiredEyeAngles( self, GetVelocity():Angle() ) ),
-- aplicado al caso que ella no cubre.
local cvFaceWalk = CreateConVar( "phantasmagoria_ghost_facewalk", "1", FCVAR_ARCHIVE,
    "El fantasma mira hacia donde camina cuando no esta cazando. En 0 se desliza sin girar, que es el defecto original: sirve para el A/B.", 0, 1 )

-- Debajo de esto no hay direccion de marcha que valga la pena mirar. Es el mismo
-- numero que la base usa como frontera de "casi quieto", pero por el otro lado:
-- ella apunta al goal por DEBAJO de 30 u/s, nosotros a la marcha por ARRIBA.
local FACEWALK_MIN_SPEED = 30

function ENT:BehaveUpdate( interval )
    local myTbl = self:GetTable()

    -- El BaseClass PRIMERO: es el que corre el cerebro entero. Lo nuestro es un
    -- retoque de la cara despues, y solo en el hueco que la base deja vacio.
    myTbl.BaseClass.BehaveUpdate( self, interval )

    -- ⚠ EL SEGUIMIENTO DE LA MIRADA, Y VA ANTES DE NUESTRA PROPIA ESCRITURA a
    -- proposito: mide el valor con el que el frame anterior TERMINO, o sea el que
    -- dejo el ultimo que escribio, sea la base o nosotros. Puesto despues, se
    -- estaria midiendo lo que acabamos de escribir -- que es el defecto que ya
    -- pagamos una vez en la linea `quiere` del instrumento.
    local wantYaw = self:GetDesiredEyeAngles().y

    if not myTbl.phantom_lookLastYaw or math.abs( math.AngleDifference( wantYaw, myTbl.phantom_lookLastYaw ) ) > 0.5 then
        myTbl.phantom_lookLastYaw   = wantYaw
        myTbl.phantom_lookChangedAt = CurTime()

    end

    if not cvFaceWalk:GetBool() then return end

    ---------------------------------------------------------------------------
    -- ⚠ ACA HABIA UN `if myTbl.phantom_Hunting then return end` Y ERA EL BUG
    ---------------------------------------------------------------------------
    -- Reportado en juego despues de la ronda 11: "no me sigue cuando esta
    -- cazando, y queda mirando a un sitio en particular", con el yaw clavado en
    -- -87.7 en DOS lecturas tomadas a 1400 u de distancia una de la otra, y
    -- "cuando paso de hunt 1 a 0 se giro correctamente".
    --
    -- La guarda decia "cazando manda la base: apunta al enemigo". La premisa de
    -- esa frase no es EL HUNT, es TENER ENEMIGO -- y son cosas distintas: el
    -- fantasma entra en hunt por el flag ( phantasmagoria_hunt, y manana la
    -- cordura ), no porque haya visto a nadie. Entre el flag y el primer avistaje
    -- hay un hueco de duracion indefinida -- puede ser eterno si el jugador esta
    -- del otro lado del mapa -- y en TODO ese hueco no hay enemigo, la cadena de
    -- shooting_handler se sale antes de Term_LookAround ( ver arriba ), y esta
    -- guarda apagaba al unico que quedaba: nosotros. La cara quedaba clavada en
    -- el ultimo yaw que alguien hubiera escrito.
    --
    -- La guarda de verdad es la linea de abajo, que estaba escrita JUSTO DEBAJO y
    -- era inalcanzable en hunt. *Una guarda cuya premisa es otra condicion tiene
    -- que preguntar por esa condicion, no por la que suele venir con ella.*
    if IsValid( myTbl.GetEnemy( self ) ) then return end

    local loco = myTbl.loco
    if not loco then return end

    -- Saltando y en el aire tambien manda la base ( :3306 y :3311 ), que ademas
    -- mira hacia donde va a aterrizar. Pisarla seria romper algo que funciona.
    if myTbl.m_JumpingToPos then return end
    if not loco:IsOnGround() then return end

    local vel = loco:GetVelocity()
    if vel:Length2D() < FACEWALK_MIN_SPEED then return end

    local ang = vel:Angle()

    -- Plano a proposito. La base tambien aplana el pitch cuando no hay un cambio
    -- de altura dramatico ( enemyoverrides.lua:1866-1869 ), y un fantasma mirando
    -- al piso mientras baja una rampa se ve peor que uno mirando al frente.
    ang.p = 0
    ang.r = 0

    self:SetDesiredEyeAngles( ang )

    -- La otra mitad del instrumento de arriba: CUANDO escribimos NOSOTROS. Con
    -- las dos marcas, "cambio" y "la escribimos", el reporte puede decir quien
    -- movio la cara en vez de deducirlo del flag -- que es exactamente lo que
    -- hacia mal y lo que tapo este bug una ronda entera.
    myTbl.phantom_lookWroteAt = CurTime()

end

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------
-- AdditionalInitialize corre DESPUES de que la base resolvio modelo y FOV
-- ( shared.lua:3011, con el modelo en :2987 y el FOV en :3005 ), por eso es
-- el lugar correcto para pisar defaults. La implementacion de la base esta
-- vacia ( shared.lua:2909-2910 ): no hay que encadenar al BaseClass.
function ENT:AdditionalInitialize()
    -- Trampa 2 (Referencia 4.3): Term_FOV solo NO alcanza. El comentario de
    -- shared.lua:152 dice que poner un numero ignora la convar
    -- termhunter_fovoverride, y miente: el callback de la convar
    -- ( shared.lua:57-62 ) pisa Term_FOV justamente en las entidades que ya
    -- tienen numero, si AutoUpdateFOV es true - y el default es true
    -- ( shared.lua:154 ). Hay que poner LAS DOS.
    self.Term_FOV      = 180
    self.AutoUpdateFOV = false -- HIM pone nil aca ( server.lua:852 ); las dos son falsy

    -- La RunSpeed DECLARADA por la base, congelada en el unico momento en que
    -- se sabe limpia. Es el divisor de la conversion de velocidad
    -- ( server_speed.lua ) y NO se lee en vivo a proposito: overcharging.lua:22
    -- hace "self.RunSpeed = math.max( self.RunSpeed * 1.40, 550 )", y un divisor
    -- en vivo cancelaria el overcharge en silencio -- el fantasma volveria a su
    -- velocidad normal justo cuando el mecanismo dice que tiene que acelerar.
    self.phantom_BaseRunSpeed = self.RunSpeed

    -- EL HULL, Y ACA ES EL UNICO LUGAR DONDE SE PUEDE. shared.lua llama
    -- AdditionalInitialize en :3011 y InitializeCollisionBounds en :3017, o sea
    -- que esta es la ultima linea que corre ANTES de que la base lea
    -- CollisionBounds. Puesto un tick despues no pasa nada visible: el hull ya
    -- se aplico, el ViewOffset ya se calculo con el numero viejo, y la unica
    -- pista seria que los ojos siguen en 64.
    --
    -- Se escribe en la ENTIDAD y no en la clase a proposito: ENT.CollisionBounds
    -- es una tabla COMPARTIDA que viene de la base, y mutarla se lo llevaria
    -- puesto a todo terminator del mapa, incluidos los que no son nuestros.
    if esNuestroModelo and cvHull:GetBool() then
        self.CollisionBounds = {
            Vector( -HULL_ANCHO, -HULL_ANCHO, 0 ),
            Vector(  HULL_ANCHO,  HULL_ANCHO, HULL_ALTO ),
        }

    end

    -- Sincroniza el NW var con el campo. Va ANTES del return temprano de abajo:
    -- si queda del otro lado, el marcador del cliente miente en todo mapa que
    -- tenga navmesh, que son casi todos.
    self:phantom_SetHunting( self.phantom_Hunting )

    -- Diseno 19, tajada A: el tipo se elige ACA y no mas tarde, porque es lo que
    -- todo lo demas va a leer -- speed.base al primer tick, el hunt.threshold
    -- cuando exista la cordura. Un tipo que llega tarde es un fantasma que
    -- durante unos frames corre a la velocidad de otro.
    --
    -- Con guarda por el mismo motivo que la de server_speed.lua: si el include
    -- fallara, esto correria en CADA spawn y el error taparia la causa real.
    if self.phantom_ResolveType then
        self:phantom_ResolveType()

    else
        ghostPrint( "server_type.lua no cargo: el fantasma spawnea SIN TIPO y la cordura no va a tener contra que comparar.\n" )

    end

    ghostPrint( "spawn #", self:EntIndex(),
        "  modelo ", tostring( self:GetModel() ),
        "  skin ", self:GetSkin(),
        "  pos ", tostring( self:GetPos() ),
        "  hunt ", self.phantom_Hunting and "SI" or "NO",
        -- El tipo en la linea de spawn y no solo en el comando: es el unico
        -- lugar donde queda registro de con que tipo NACIO cada fantasma, y el
        -- override lo puede cambiar despues sin dejar rastro de cual era.
        "  tipo ", tostring( self.phantom_TypeKey or "NINGUNO" ),
        "\n" )

    -- EL HULL SE REPORTA UN TICK DESPUES, Y NO ES PROLIJIDAD: aca todavia no
    -- existe. InitializeCollisionBounds corre 6 lineas mas abajo que nosotros
    -- ( shared.lua:3017 ) y SetupCollisionBounds otro tick despues ( :3039 ), asi
    -- que imprimirlo aca imprimiria lo que acabamos de escribir en vez de lo que
    -- la base hizo con eso. Es el mismo defecto que ya pagamos en la linea
    -- `quiere` del instrumento de la mirada: una columna que te devuelve lo que
    -- tu propio codigo escribio no es una medicion.
    --
    -- Y lo que se imprime es la CONSECUENCIA, no el ajuste: los ojos contra la
    -- altura de la malla. "Los ojos a 40 y la cabeza a 44,7" se lee solo;
    -- "CollisionBounds = 45" hay que ir a buscar contra que.
    timer.Simple( 0, function()
        if not IsValid( self ) then return end

        local mins, maxs = self:GetCollisionBounds()

        -- ⚠ EL ALTO DE LA MALLA ES UNA CONSTANTE MEDIDA FUERA DE JUEGO Y TIENE
        -- QUE SERLO. En juego NO hay forma de preguntarlo: OBBMaxs() devuelve
        -- las collision bounds -- o sea justo lo que acabamos de escribir, con
        -- lo que la comparacion daria 45 contra 45 y siempre "OK" -- y
        -- GetModelBounds() devuelve el hull del .phy, que en este modelo llega a
        -- 46,65 porque es el del ragdoll. Los dos contestan con un numero
        -- creible a una pregunta que no es la que se hizo, y ese error ya se
        -- pago dos veces en este taller.
        -- 44,94 sale del .vvd ( vvdbounds.py sobre ghost_girl.vvd ), que es la
        -- unica fuente que contiene la malla y nada mas.
        local MALLA_ALTO = 44.94

        -- GetViewOffset puede no existir sobre un NextBot. Se prueba en vez de
        -- suponerlo, y si no esta se DICE -- un cero por metodo faltante se leeria
        -- como "los ojos estan en el piso", que es un defecto distinto.
        local okOff, off = pcall( self.GetViewOffset, self )
        local ojos = okOff and isvector( off ) and off.z or nil

        ghostPrint( "spawn #", self:EntIndex(),
            "  hull ", math.Round( maxs.x - mins.x ), "x", math.Round( maxs.y - mins.y ),
            "x", math.Round( maxs.z - mins.z ),
            "  ( la base sola da 32x32x72 )",
            "  malla ", MALLA_ALTO, " de alto",
            ojos and ( "  ojos z " .. math.Round( ojos, 1 ) ..
                ( ojos > MALLA_ALTO and "  <- LOS OJOS ESTAN SOBRE LA CABEZA" or "" ) )
                or "  ojos: GetViewOffset no se pudo leer en esta entidad",
            "\n" )

    end )

    -- El navmesh se mide DOS VECES a proposito, y esta es la correccion mas
    -- cara de la primera corrida (2026-08-05). La version anterior de este
    -- aviso decia "SIN NAVMESH: el bot no va a caminar" -- y el bot caminaba.
    -- Medicion correcta, prediccion falsa: con 0 areas la base llama a
    -- TryGeneratingAreas() ( shared.lua:3072-3075 ) y el parcheador
    -- ( terminator_areapatcher.lua, convar terminator_areapatching_enable,
    -- default 1 ) sigue creando areas donde caminan bots y jugadores. O sea que
    -- 0 al spawnear NO es 0 diez segundos despues.
    --
    -- Un instrumento no predice: mide, espera, y vuelve a medir.
    local areasAlSpawnear = navmesh.GetNavAreaCount()
    if areasAlSpawnear > 0 then return end

    ghostPrint( "0 navareas al spawnear. La base va a intentar parchear el mapa; " ..
        "se vuelve a medir en ", NAVCHECK_DELAY, " s.\n" )

    timer.Simple( NAVCHECK_DELAY, function()
        if not IsValid( self ) then return end

        local ahora = navmesh.GetNavAreaCount()

        if ahora > 0 then
            -- "van" y no "construyo": el numero SIGUE CRECIENDO. Medido en la
            -- corrida 3 (gm_graysonhouse): 42 aca y 137 un rato despues, con el
            -- bot caminando. El parcheador crea areas donde pisan bots y
            -- jugadores, asi que esto es una foto y no un total.
            ghostPrint( "van ", ahora, " navareas parcheadas a los ", NAVCHECK_DELAY,
                " s, y el parcheador sigue trabajando mientras alguien camine. El bot se mueve " ..
                "sobre un mapa PARCHEADO, no sobre un navmesh de verdad: esperar caminos raros.\n" )

        else
            ghostPrint( "SIGUEN 0 navareas: aca si el bot no va a caminar. " ..
                "nav_generate, o un mapa con navmesh.\n" )

        end
    end )
end

---------------------------------------------------------------------------
-- Instrumento: donde esta cada fantasma
---------------------------------------------------------------------------
-- Complementa al marcador del cliente y falla distinto: el marcador solo
-- dibuja fantasmas dentro del PVS del jugador, este los ve todos. Si uno
-- aparece aca y no en pantalla, el bot existe y el que fallo es el dibujo.
-- HUD_PRINTCONSOLE viaja por un user message TextMsg con techo de 255 BYTES, y
-- lo que pasa al pasarse NO es que se trunque: el servidor se NIEGA a mandarlo
-- ( "Refusing to send user message TextMsg of 256 bytes to client, user message
-- size limit is 255 bytes" ) y la linea entera se pierde. Medido en la primera
-- corrida (2026-08-05): la linea de TAREAS -- la mas informativa de las seis --
-- fue justo la unica que se paso, y el unico rastro fue ese aviso del engine,
-- que no dice cual se perdio. Un instrumento que pierde su mejor dato en
-- silencio es peor que no tenerlo.
local MAX_LINEA = 180 -- con margen: al trozo se le suma la sangria

-- Fabrica el "say" de un comando. Extraido a proposito: era un local adentro de
-- phantasmagoria_ghost_where, y todo comando nuevo que imprimiera por su cuenta
-- volvia a caer en el mismo pozo de 255 bytes sin avisar.
local function makeSay( ply )
    return function( line )
        line = tostring( line )

        if not IsValid( ply ) then -- consola del servidor, sin limite
            print( line )
            return

        end

        if line == "" then
            ply:PrintMessage( HUD_PRINTCONSOLE, "" )
            return

        end

        local primero = true

        while #line > 0 do
            local trozo = string.sub( line, 1, MAX_LINEA )
            line = string.sub( line, MAX_LINEA + 1 )
            ply:PrintMessage( HUD_PRINTCONSOLE, primero and trozo or "            " .. trozo )
            primero = false

        end
    end
end

-- Compartido a proposito: todo comando nuevo que imprima por su cuenta vuelve a
-- caer en el pozo de 255 bytes, y el aviso del engine no dice cual linea perdio.
PHANTASMAGORIA.MakeSay = makeSay

---------------------------------------------------------------------------
-- Registrar un comando, con la guarda que costo una ronda entera
---------------------------------------------------------------------------
-- UNA CONVAR Y UN CONCOMMAND NO PUEDEN LLAMARSE IGUAL, Y EL QUE PIERDE ES EL
-- COMANDO, EN SILENCIO. concommand.Add lo registra igual -- no devuelve error,
-- no avisa -- pero la consola resuelve el nombre contra las convars primero,
-- asi que tipearlo imprime la ficha de la convar y el comando no corre nunca.
--
-- Medido en la ronda 2 (2026-08-06) y costo DOS filas de la planilla: yo habia
-- creado la convar phantasmagoria_ghost_doors y el comando
-- phantasmagoria_ghost_doors. El instrumento de puertas fue INALCANZABLE toda
-- la ronda -- el autor lo reporto como "donde veo el dato de la evidencia (?)"
-- y la respuesta era que no habia forma de verlo. Y lo peor no fue eso: la
-- planilla mandaba correr "phantasmagoria_ghost_doors reset", que en vez de
-- resetear contadores le asignaba "reset" a la convar, o sea 0, o sea APAGABA
-- la apertura de puertas justo antes de medirla.
--
-- Por eso el registro pasa por aca y no por concommand.Add directo: la
-- colision se vuelve un error ruidoso al cargar en vez de un comando mudo.
function PHANTASMAGORIA.AddCommand( name, fn, help )
    if ConVarExists( name ) then
        ErrorNoHalt( "[Phantasmagoria] COLISION DE NOMBRE: '" .. name .. "' ya existe como CONVAR, " ..
            "asi que el comando homonimo queda inalcanzable ( la consola resuelve convars primero ). " ..
            "Renombrar uno de los dos.\n" )
        return false

    end

    concommand.Add( name, fn, nil, help )
    return true

end

---------------------------------------------------------------------------
-- Instrumento: hacia donde mira
---------------------------------------------------------------------------
-- Pedido del autor en la corrida 5, y es el que faltaba: "que el comando muestre
-- a donde esta mirando el phantom, porque yo lo veo moverse mirando a un solo
-- lado todo el tiempo". Sin esto, "mueve la vista" era una impresion y no un
-- numero, y ya me costo explicar la observacion antes de fijarla.
--
-- LA VERSION ANTERIOR DE ESTE BLOQUE TUVO TRES DEFECTOS, LOS TRES MIOS, Y LOS
-- TRES ESTAN CORREGIDOS ACA. Se dejan escritos porque los tres fallaban HACIA UN
-- VALOR PLAUSIBLE y ninguno tiraba error:
--
-- (1) marcha decia "quieto ( 0 u/s )" SIEMPRE, incluso con el bot cruzando el
--     mapa. La causa fue una guarda MIA: IsValid( ghost.loco ). CLuaLocomotion
--     NO tiene metodo IsValid, y el IsValid() de GMod devuelve false para todo
--     objeto que no lo tenga -- asi que la guarda caia siempre al vector cero.
--     La base NUNCA envuelve self.loco en IsValid: la llama directo
--     ( terminator_nextbot_base/motion.lua:54 ). Una guarda defensiva que falla
--     hacia un valor creible es peor que no tenerla: no se ve.
--
-- (2) Los yaws se imprimian SIN NORMALIZAR, asi que -449.7 y 270.4 -- que son
--     EL MISMO ANGULO -- se leian como direcciones opuestas, con el delta
--     diciendo 0 al lado. El delta estaba bien; los numeros de al lado lo
--     desmentian. Ahora todo pasa por math.NormalizeAngle.
--
-- (3) "quiere" se declaro como el discriminante y NO discrimina nada:
--     15 de 15 lecturas dieron delta 0. Y el motivo es estructural, no de
--     tuning: GetEyeAngles ( terminator_nextbot_base/shared.lua:81-93 ) arma el
--     angulo con self:GetAngles() y solo pisa el PITCH. O sea que el yaw de
--     "donde mira" ES el yaw del cuerpo, y no existe un yaw de cabeza aparte
--     que se le pueda comparar. La pareja mira/quiere no podia separar cabeza
--     de cuerpo ni en principio. Se conserva como CONTROL -- que el delta sea 0
--     es el dato -- y el discriminante de verdad pasa a ser otro: contra que
--     esta apuntado.
--
-- Las lineas, y que separa cada una:
--   mira       el yaw del CUERPO ( = donde mira ) y el pitch del aim
--   quiere     GetDesiredEyeAngles: control, el aim converge en el mismo frame
--   marcha     hacia donde se mueve y a que velocidad, por DOS fuentes
--   al jugador el rumbo al jugador mas cercano, y el angulo contra la mirada
--              -- ESTE es el que separa "gira siguiendote" de "gira solo"
local function lookLines( ghost, say )
    local eye  = ghost:GetEyeAngles()
    local want = ghost:GetDesiredEyeAngles()

    local eyeYaw  = math.NormalizeAngle( eye.y )
    local wantYaw = math.NormalizeAngle( want.y )

    say( "    mira    yaw " .. math.Round( eyeYaw, 1 ) ..
        "  pitch " .. math.Round( math.NormalizeAngle( eye.p ), 1 ) )

    -- El delta es el RETRASO del aim contra lo que se le pidio mirar, y lo que
    -- significa depende de QUIEN se lo pidio. Ojo con leerlo mal en calma:
    -- desde que existe el facewalk, en calma el que escribe DesiredEyeAngles
    -- somos nosotros con la direccion de marcha, asi que este delta pasa a ser
    -- identico a "mirada vs marcha" POR CONSTRUCCION -- medido en la corrida 8:
    -- 2.7/2.7, 6.2/6.2, 0.6/0.6, 0.1/0.1. Una columna que te devuelve lo que tu
    -- propio codigo acaba de escribir NO es una medicion independiente.
    -- Sigue valiendo como medicion con phantasmagoria_ghost_facewalk 0.
    --
    -- ⚠ DEFECTO 4, Y ES EL QUE TAPO EL BUG DE LA MIRADA EN HUNT UNA RONDA ENTERA.
    -- Esta etiqueta se DEDUCIA del flag: "si hunt, lo pide la base ( enemigo )".
    -- Y el reporte de la ronda 12 la imprimio doce veces al lado de
    -- `enemigo ninguno`, en la misma pantalla, sin que nadie lo viera -- porque
    -- la etiqueta afirmaba justo lo contrario de la columna de arriba. Nadie
    -- pedia nada: el fantasma estaba en hunt SIN enemigo y su cara no la escribia
    -- ni la base ni nosotros. *Una etiqueta deducida de un flag no es una
    -- medicion de lo que paso, y miente con la misma cara con que acierta.*
    --
    -- Ahora se MIDE, con dos marcas que pone BehaveUpdate: cuando cambio el valor
    -- ( lo escriba quien lo escriba ) y cuando lo escribimos nosotros. Si cambio
    -- recien y no fuimos nosotros, fue la base; si hace rato que no cambia, no
    -- fue nadie -- y ESE es el sintoma que el autor reporto como "queda mirando a
    -- un sitio en particular".
    local ahora    = CurTime()
    local cambio   = ghost.phantom_lookChangedAt
    local escribio = ghost.phantom_lookWroteAt

    local quieta   = cambio and ( ahora - cambio ) or nil
    local nuestra  = escribio and ( ahora - escribio ) or nil

    -- ⚠⚠ EL ORDEN DE ESTAS RAMAS ERA UN DEFECTO, Y LA RONDA 13 LO EXHIBIO CON
    -- DOS MUESTRAS DEL MISMO REGIMEN QUE SE CONTRADECIAN ENTRE SI. Las dos con
    -- `hunt SI · enemigo ninguno · facewalk 1` y el bot a 196 u/s en linea recta
    -- por gm_flatgrass:
    --
    --     mira yaw 90 · quiere yaw 90 ( la escribimos NOSOTROS ( facewalk ) )   mirada vs marcha 0
    --     mira yaw 90 · quiere yaw 90 ( NADIE la mueve hace 1.6 s -- CONGELADA ) mirada vs marcha 0
    --
    -- Mismo estado, misma rama del codigo, etiquetas opuestas. *Un rojo que
    -- contradice a un verde de la misma corrida acusa al instrumento.*
    --
    -- LA CAUSA: `quieta` mide QUE EL VALOR NO CAMBIO, y eso NO es "nadie lo
    -- escribio". Un bot que camina derecho tiene una direccion de marcha
    -- constante, asi que el facewalk le escribe **el mismo angulo cada tick**: lo
    -- estamos moviendo todo el tiempo y el valor no se mueve nunca. Y como la
    -- rama de `quieta` estaba ANTES que la de `nuestra`, ganaba ella.
    --
    -- El "y caminando" que agregue como discriminante no ataja nada de esto: el
    -- bot SI camina. El que lo atajaba estaba en la linea de abajo -- `mirada vs
    -- marcha 0` -- y no lo mire. *Un discriminante que no separa los dos casos
    -- que se confunden es decoracion.*
    --
    -- EL ORDEN BUENO: primero lo MEDIDO ( escribimos nosotros, y de eso hay marca
    -- directa ), despues lo inferido. La ultima rama queda honesta sobre lo que
    -- no puede saber: sin una marca adentro del `shootAt` de la base, "no cambio
    -- y no fuimos nosotros" no distingue "nadie escribio" de "la base escribio el
    -- mismo valor".
    local quienPide
    if not cambio then
        quienPide = "sin medir todavia ( el bot no corrio un BehaveUpdate aun )"

    elseif nuestra and nuestra <= 0.2 then
        quienPide = "la escribimos NOSOTROS ( facewalk ): = mirada vs marcha, no es dato aparte"

    elseif quieta <= 1 then
        quienPide = "la escribe LA BASE ( shootAt sobre el enemigo ), cambio hace " ..
            string.format( "%.1f", quieta ) .. " s"

    elseif ghost:GetCurrentSpeed() >= FACEWALK_MIN_SPEED then
        quienPide = "NO la escribimos nosotros y no cambia hace " .. string.format( "%.1f", quieta ) ..
            " s, CAMINANDO -- mirar `mirada vs marcha` aca abajo: si da ~0 es una constante, no un clavado"

    else
        quienPide = "no la escribimos y no cambia hace " .. string.format( "%.1f", quieta ) ..
            " s ( parado: no hay a donde mirar, es lo normal )"

    end

    say( "    quiere  yaw " .. math.Round( wantYaw, 1 ) ..
        "  pitch " .. math.Round( math.NormalizeAngle( want.p ), 1 ) ..
        "   delta " .. math.Round( math.abs( math.AngleDifference( wantYaw, eyeYaw ) ), 1 ) ..
        " grados ( " .. quienPide .. " )" )

    -- DOS fuentes de velocidad y las dos se imprimen, para que el instrumento
    -- diga con que esta midiendo. La de la base es GetCurrentSpeed
    -- ( terminator_nextbot_base/motion.lua:51, Length2D del loco, cacheada
    -- 0,01 s ); Entity:GetVelocity() es la de la entidad y en un NextBot puede
    -- no ser la misma cosa. Si alguna vuelve a dar 0 con el bot caminando, se
    -- ve CUAL, que es lo que la version anterior no dejaba ver.
    local vel     = ghost.loco and ghost.loco:GetVelocity() or vector_origin
    local spdLoco = ghost:GetCurrentSpeed()
    local spdEnt  = ghost:GetVelocity():Length()

    if spdLoco < 1 and spdEnt < 1 then
        say( "    marcha  quieto   ( loco " .. math.Round( spdLoco, 1 ) ..
            " u/s · ent " .. math.Round( spdEnt, 1 ) .. " u/s )" )

    else
        local marchaYaw = math.NormalizeAngle( vel:Angle().y )

        say( "    marcha  yaw " .. math.Round( marchaYaw, 1 ) ..
            "   loco " .. math.Round( spdLoco ) .. " u/s · ent " .. math.Round( spdEnt ) .. " u/s" ..
            "   mirada vs marcha " .. math.Round( math.abs( math.AngleDifference( marchaYaw, eyeYaw ) ), 1 ) .. " grados" )

    end

    -- El discriminante que faltaba. En hunt el bot deberia apuntarte; en calma,
    -- no. Sin esta linea, "el yaw cambio" no distingue seguirte de girar solo.
    local nearest, nearestDist
    for _, target in ipairs( player.GetAll() ) do
        local d = ghost:GetRangeTo( target )
        if not nearest or d < nearestDist then nearest, nearestDist = target, d end

    end

    if not IsValid( nearest ) then
        say( "    al ply  ( no hay jugadores )" )
        return

    end

    local rumbo = math.NormalizeAngle( ( nearest:GetPos() - ghost:GetPos() ):Angle().y )

    say( "    al ply  yaw " .. math.Round( rumbo, 1 ) .. "  a " .. math.Round( nearestDist ) .. " u" ..
        "   mirada vs jugador " .. math.Round( math.abs( math.AngleDifference( rumbo, eyeYaw ) ), 1 ) .. " grados" )

end

-- Itera los fantasmas vivos. Misma busqueda que usaba ghost_where: por el campo
-- IsPhantasmagoriaGhost y NO por clase, porque los 30 tipos de Diseno 12.2 van a
-- llamarse phantasmagoria_<tipo> y una busqueda por clase exacta va a envejecer
-- mal.
local function eachGhost( fn )
    local found = 0

    for _, ghost in ipairs( ents.GetAll() ) do
        if not ghost.IsPhantasmagoriaGhost then continue end
        if not IsValid( ghost ) then continue end

        found = found + 1
        fn( ghost )

    end

    return found

end

PHANTASMAGORIA.EachGhost = eachGhost

---------------------------------------------------------------------------
-- Instrumento: QUE SECUENCIA responde a cada actividad, y CUANTAS compiten
---------------------------------------------------------------------------
-- ESTE COMANDO EXISTE PARA MEDIR UNA SOLA COSA, que es lo unico del bloque del
-- modelo que quedo sin medir: si el engine DESCARTA la secuencia prestada
-- cuando el modelo dueno ya tiene una con el mismo nombre.
--
-- El fantasma declara sus 8 actividades con los nombres de secuencia de m_anm
-- ( walk_all, run_all_01, idle_all_01, ... ) justamente para que eso pase. Si
-- pasa, hay UNA secuencia por actividad y siempre gana la nuestra. Si NO pasa,
-- hay DOS con el mismo peso y SelectWeightedSequence tira una moneda cada vez:
-- el fantasma tomaria las proporciones del adulto de 1,83 una vez de cada dos.
--
-- ⚠ Y POR ESO NO ALCANZA CON MIRARLO NI CON `ph_ghost_bones`. Los dos miden UNA
-- muestra, y contra una moneda una muestra no distingue "siempre bien" de "bien
-- la mitad de las veces": el 50 % de las corridas darian verde sobre un modelo
-- roto. Lo que separa los dos casos no es la pose, es el CONTEO -- y el conteo
-- no depende de la suerte.
--
-- La cuenta se hace sobre GetSequenceCount(), que con $includemodel resuelto ya
-- incluye las prestadas: son 2171 con las de m_anm y 11 sin ellas, asi que el
-- propio total dice si el include se resolvio. Un total de 11 no seria un
-- "esta limpio": seria que m_anm no se monto y la medicion no vale.
local ACTS_QUE_PIDE_LA_BASE = {
    -- La cadena que las eligio esta en el encabezado de IdleActivityTranslations.
    { act = ACT_HL2MP_IDLE,          nuestra = "idle_all_01",  cuando = "parado" },
    { act = ACT_HL2MP_WALK,          nuestra = "walk_all",     cuando = "caminando" },
    { act = ACT_HL2MP_RUN,           nuestra = "run_all_01",   cuando = "corriendo" },
    { act = ACT_HL2MP_IDLE_CROUCH,   nuestra = "cidle_all",    cuando = "agachado quieto" },
    { act = ACT_HL2MP_WALK_CROUCH,   nuestra = "cwalk_all",    cuando = "agachado andando" },
    { act = ACT_HL2MP_JUMP_SLAM,     nuestra = "jump_slam",    cuando = "saltando" },
    { act = ACT_HL2MP_SWIM,          nuestra = "swimming_all", cuando = "nadando" },
    { act = ACT_LAND,                nuestra = "jump_land",    cuando = "al aterrizar ( gesto )" },
}

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_acts", function( ply )
    local say = makeSay( ply )

    local ghosts = {}
    eachGhost( function( g ) ghosts[ #ghosts + 1 ] = g end )

    if #ghosts == 0 then
        say( "[Phantasmagoria] SIN CORRER: no hay ningun fantasma vivo." )
        return

    end

    for _, ghost in ipairs( ghosts ) do
        local total = ghost:GetSequenceCount()

        say( "" )
        say( "[Phantasmagoria] #" .. ghost:EntIndex() .. "  " .. tostring( ghost:GetModel() ) )
        say( "    secuencias visibles: " .. total ..
            ( total > 100 and "  ( el $includemodel se resolvio: las prestadas estan )" or
              "  <- SIN LAS PRESTADAS: m_anm no se monto y esta medicion NO VALE" ) )

        -- Un solo barrido de las N secuencias, agrupando por actividad. Barrer
        -- una vez por actividad seria 8 pasadas sobre 2171.
        local porAct = {}
        for i = 0, total - 1 do
            local a = ghost:GetSequenceActivity( i )
            if a and a > 0 then
                porAct[ a ] = porAct[ a ] or {}
                table.insert( porAct[ a ], ghost:GetSequenceName( i ) )

            end
        end

        local malas = 0

        for _, fila in ipairs( ACTS_QUE_PIDE_LA_BASE ) do
            local cands = porAct[ fila.act ] or {}
            local elegida = ghost:GetSequenceName( ghost:SelectWeightedSequence( fila.act ) )

            -- El veredicto es el CONTEO y el NOMBRE juntos. Uno solo no alcanza:
            -- un conteo de 1 sobre la secuencia equivocada seria un modelo que
            -- responde siempre igual y siempre mal, y un nombre correcto con
            -- conteo 2 es la moneda.
            local ok = #cands == 1 and cands[ 1 ] == fila.nuestra
            if not ok then malas = malas + 1 end

            say( "    " .. ( ok and "OK  " or "!!  " ) .. string.format( "%-22s", fila.nuestra ) ..
                #cands .. " secuencia" .. ( #cands == 1 and "" or "s" ) ..
                "   elige: " .. tostring( elegida ) ..
                "   ( " .. fila.cuando .. " )" )

            if #cands ~= 1 then
                say( "         compiten: " .. table.concat( cands, ", " ) )

            end
        end

        -- La linea de estado ahora mismo, que es lo que ata el conteo con lo que
        -- se ve: si el bot esta caminando, la secuencia viva tiene que ser la
        -- nuestra. Sin esto el comando prueba que el modelo PUEDE elegir bien y
        -- no que la base le este pidiendo lo que creemos.
        local viva = ghost:GetSequenceName( ghost:GetSequence() )
        say( "    secuencia VIVA ahora: " .. tostring( viva ) ..
            "   ( actividad " .. tostring( ghost:GetSequenceActivityName( ghost:GetSequence() ) ) .. " )" )

        -- LOS POSE PARAMS, QUE SON LO QUE HACE MEDIBLE A LA MEZCLA. walk_all,
        -- run_all_01, cwalk_all y swimming_all son grillas 3x3 sobre move_y ( eje
        -- X ) y move_x ( eje Y ), leidas del mstudioseqdesc_t de m_anm y
        -- reproducidas identicas en el nuestro. Quien las mueve es BodyMoveXY
        -- ( motion.lua:353 ), que es del engine: la base no las toca nunca --
        -- grep sobre sus 71 archivos: los unicos SetPoseParameter son aim_yaw y
        -- aim_pitch, y viven en weapons.lua, que un bot desarmado no alcanza.
        --
        -- Sin esta linea, "camina de costado o hace moonwalk" es una impresion.
        -- Con ella es un numero: yendo derecho hacia vos move_x se va a un
        -- extremo y move_y se queda al medio; en un paso lateral se invierte.
        --
        -- ⚠ GetPoseParameter DEVUELVE 0..1 NORMALIZADO, no el rango declarado.
        -- Se imprimen las dos columnas -- el crudo y el remapeado a -1..1 -- para
        -- que no haya que acordarse: un 0.5 crudo y un 0.0 real son el mismo
        -- numero y el segundo es el que se compara contra la grilla.
        local px = ghost:GetPoseParameter( "move_x" )
        local py = ghost:GetPoseParameter( "move_y" )

        if px and py then
            say( string.format(
                "    pose  move_x %.2f ( -1..1: %+.2f )   move_y %.2f ( -1..1: %+.2f )   vel %d u/s",
                px, px * 2 - 1, py, py * 2 - 1, math.Round( ghost:GetCurrentSpeed() ) ) )

        else
            -- Un nil se DICE. Si el modelo no declara move_x/move_y, la mezcla no
            -- se puede mover y siempre se ve el centro -- que es un defecto real
            -- y no la ausencia de un dato de debug.
            say( "    pose  move_x/move_y NO EXISTEN en este modelo: la mezcla queda " ..
                "clavada en el centro y el fantasma camina siempre igual." )

        end

        if malas == 0 then
            say( "    >> PASA: 8/8 actividades con UNA sola secuencia, y es la nuestra." )

        else
            say( "    >> FALLA: " .. malas .. " de 8 actividades no resuelven a nuestra secuencia. " ..
                "Con 2 candidatas el estiramiento sale una vez de cada dos." )

        end
    end
end, "Cuenta cuantas secuencias responden a cada actividad que la base le pide al fantasma. " ..
    "Mide si el $includemodel descarto las prestadas de m_anm: tiene que dar 1 por actividad." )

---------------------------------------------------------------------------
-- EL BOTON DE LA MIRADA, Y LO QUE LO SEPARA DE UNA LECTURA ES QUE SE NIEGA
---------------------------------------------------------------------------
-- La ronda 9 dejo escrita la regla y la ronda 10 la cobro: *imprimir la
-- precondicion al lado del veredicto no alcanza -- el boton tiene que negarse.*
-- Tres filas de aquella planilla salieron verdes sobre un estado que la fila no
-- pedia, con la precondicion impresa dos lineas mas arriba.
--
-- Esta medicion tiene DOS precondiciones que un ojo no puede sostener 20 s:
--
--   ① UN SOLO FANTASMA. Los comandos iteran sobre todos, y con dos las lecturas
--     se mezclan en la misma pantalla sin que nada las separe.
--
--   ② UN SOLO REGIMEN. "hunt sin enemigo" y "hunt con enemigo" son los dos lados
--     del arreglo, y el bot cruza de uno al otro solo, en el segundo en que te
--     ve. Un promedio que atraviesa el cruce no describe ninguno de los dos.
--
-- Las dos se COMPRUEBAN y las dos ABORTAN, con el segundo exacto en que se
-- rompieron. Y hay una tercera que no es precondicion sino denominador:
--
--   ③ CUANTAS MUESTRAS CAMINABA. Una mirada quieta en un bot parado es lo
--     normal -- no hay a donde mirar. El defecto es la mirada quieta MIENTRAS
--     CAMINA, asi que el numerador de "congelada" solo tiene sentido sobre las
--     muestras en movimiento. *Un cero sin denominador de lecturas no es un
--     cero: es una linea que no se corrio.* Si el bot no camino nunca, esto no
--     da 0 congeladas: dice que la fila no se pudo correr.
local LOOK_HZ          = 0.25 -- 4 muestras por segundo
local LOOK_FROZEN_SECS = 1    -- lo que "nadie la movio" tiene que durar para contar

local function lookRegimen( ghost )
    return ( ghost.phantom_Hunting and "hunt" or "calma" ) ..
        " " .. ( IsValid( ghost:GetEnemy() ) and "CON enemigo" or "SIN enemigo" )

end

-- ⚠⚠ EL SEGUNDO ARGUMENTO, Y SALE DEL ROJO MAS CARO DE LA RONDA 13. La fila del
-- ARREGLO se marco verde habiendo medido `hunt CON enemigo`, que es el regimen de
-- OTRA fila -- ahi manda la base, `NOSOTROS` tiene que dar 0 por diseno, y el
-- veredicto salio con pinta de estar bien. El boton se negaba a promediar dos
-- regimenes, pero no a correr ENTERO en el que no era.
--
-- *Un boton que se niega a lo que puede pasar en el medio y no a lo que ya estaba
-- mal al empezar, deja pasar el error que de verdad ocurre.* La precondicion
-- estaba escrita en la fila y en la salida; lo que faltaba era que el boton la
-- pudiera EXIGIR.
local LOOK_REGIMENES = {
    huntsin   = "hunt SIN enemigo",
    huntcon   = "hunt CON enemigo",
    calmasin  = "calma SIN enemigo",
    calmacon  = "calma CON enemigo",
}

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_look", function( ply, _, args )
    local say  = makeSay( ply )
    local segs = math.Clamp( tonumber( args[ 1 ] or "" ) or 20, 5, 120 )

    -- Y SE DICE QUE SE CANCELO. El timer es uno solo, asi que tipear el comando
    -- dos veces mata la medicion anterior -- y una ventana de 25 s que se pierde
    -- en silencio se lee despues como "esta fila no imprimio nada".
    if timer.Exists( "phantasmagoria_look" ) then
        say( "[Phantasmagoria] habia una medicion corriendo y se CANCELO: su veredicto no va a salir." )

    end

    timer.Remove( "phantasmagoria_look" )

    local ghosts = {}
    eachGhost( function( g ) ghosts[ #ghosts + 1 ] = g end )

    if #ghosts == 0 then
        say( "[Phantasmagoria] SIN CORRER: no hay ningun fantasma vivo." )
        return

    end

    if #ghosts > 1 then
        say( "[Phantasmagoria] SIN CORRER: hay " .. #ghosts .. " fantasmas vivos y esta medicion es de UNO." )
        say( "    Con dos, las muestras de los dos caen en el mismo promedio y nada las separa despues." )
        return

    end

    local ghost = ghosts[ 1 ]
    local reg0  = lookRegimen( ghost )
    local quien = ply
    local total = math.ceil( segs / LOOK_HZ )

    -- El regimen PEDIDO, si lo pidieron. Se compara ANTES de arrancar el timer:
    -- una ventana de 25 s que despues resulta ser del regimen equivocado no es
    -- un dato, son 25 s tirados y una fila mal marcada.
    local pedido = string.lower( args[ 2 ] or "" )

    if pedido ~= "" then
        local esperado = LOOK_REGIMENES[ pedido ]

        if not esperado then
            say( "[Phantasmagoria] SIN CORRER: '" .. pedido .. "' no es un regimen." )
            say( "    Los cuatro: huntsin · huntcon · calmasin · calmacon.  ( o sin argumento, y mide el que haya )" )
            return

        end

        if esperado ~= reg0 then
            say( "[Phantasmagoria] SIN CORRER: pediste '" .. esperado .. "' y el fantasma esta en '" .. reg0 .. "'." )
            say( "    " .. ( ghost.phantom_Hunting and "hunt SI" or "hunt NO" ) ..
                " · enemigo " .. ( IsValid( ghost:GetEnemy() ) and tostring( ghost:GetEnemy() ) or "ninguno" ) )
            say( "    No se mide igual: el veredicto del regimen equivocado sale con pinta de estar bien." )
            return

        end
    end

    local n, nMov, nCongel = 0, 0, 0
    local nNuestra, nBase, nNadie = 0, 0, 0
    local sumMarcha, maxMarcha = 0, 0
    local sumPly, maxPly, minPly, nPly = 0, 0, 360, 0
    local barrido, yaw0, yawPrev = 0, nil, nil
    local dMin, dMax = 0, 0
    local roto = nil

    say( "[Phantasmagoria] MIRADA: " .. segs .. " s a " .. math.Round( 1 / LOOK_HZ ) .. " muestras/s." )
    say( "    regimen  " .. reg0 .. "   ( si cambia, la medicion se ABORTA: no se promedian dos regimenes )" )
    say( "    #" .. ghost:EntIndex() .. "  Term_FOV " .. tostring( ghost.Term_FOV ) ..
        " · facewalk " .. cvFaceWalk:GetInt() )

    timer.Create( "phantasmagoria_look", LOOK_HZ, total, function()
        local fin = makeSay( quien )

        if not IsValid( ghost ) then
            timer.Remove( "phantasmagoria_look" )
            fin( "[Phantasmagoria] SIN CORRER: el fantasma murio o lo borraron en el segundo " ..
                string.format( "%.1f", n * LOOK_HZ ) .. "." )
            return

        end

        -- ⚠ EL ABORTO VA ANTES DE ACUMULAR, Y LA MUESTRA DEL CRUCE NO ENTRA.
        -- Puesta adentro, la muestra que prueba que el promedio no sirve seria
        -- ademas una de las que lo forman. Por eso el acumulado vive en el `else`
        -- y no despues del `if`.
        local reg = lookRegimen( ghost )

        if reg ~= reg0 then
            roto = { seg = n * LOOK_HZ, de = reg0, a = reg }
            timer.Remove( "phantasmagoria_look" )

        else
            n = n + 1

            local eyeYaw = math.NormalizeAngle( ghost:GetEyeAngles().y )

            if yaw0 then
                local d = math.AngleDifference( eyeYaw, yaw0 )

                dMin = math.min( dMin, d )
                dMax = math.max( dMax, d )

                -- El barrido se suma entre muestras CONSECUTIVAS y el abanico se
                -- mide contra la primera. Los dos porque fallan distinto: el
                -- abanico se queda corto si el bot da mas de media vuelta
                -- ( AngleDifference envuelve ), y el barrido cuenta como giro el
                -- temblor de un bot parado. Para lo unico que hay que separar --
                -- clavada o no -- los dos dan CERO, y ese acuerdo es el dato.
                barrido = barrido + math.abs( math.AngleDifference( eyeYaw, yawPrev ) )

            else
                yaw0 = eyeYaw

            end

            yawPrev = eyeYaw

            -- QUIEN la escribio, sobre las dos marcas que pone BehaveUpdate. No
            -- es una deduccion del flag: es cuando cambio el valor y cuando lo
            -- escribimos nosotros.
            local ahora   = CurTime()
            local quieta  = ahora - ( ghost.phantom_lookChangedAt or ahora )
            local nuestra = ghost.phantom_lookWroteAt and ( ahora - ghost.phantom_lookWroteAt ) or nil

            -- ⚠ EL ORDEN ES EL DE lookLines Y POR EL MISMO MOTIVO: lo MEDIDO
            -- primero. `quieta` mide que el VALOR no cambio, y un bot que camina
            -- derecho recibe el mismo angulo cada tick -- lo escribimos siempre y
            -- el valor no se mueve nunca. Con la rama de `quieta` adelante, la
            -- r13 conto como NADIE muestras que eran NOSOTROS.
            local nadie = false

            if nuestra and nuestra <= 0.2 then
                nNuestra = nNuestra + 1

            elseif quieta <= LOOK_FROZEN_SECS then
                nBase = nBase + 1

            else
                nadie = true
                nNadie = nNadie + 1

            end

            -- EL DENOMINADOR. Todo lo de abajo cuelga de que el bot estuviera
            -- caminando en ESTA muestra.
            local vel = ghost.loco and ghost.loco:GetVelocity() or vector_origin

            if vel:Length2D() >= FACEWALK_MIN_SPEED then
                nMov = nMov + 1

                if nadie then nCongel = nCongel + 1 end

                local marcha = math.abs( math.AngleDifference( math.NormalizeAngle( vel:Angle().y ), eyeYaw ) )

                sumMarcha = sumMarcha + marcha
                maxMarcha = math.max( maxMarcha, marcha )

            end

            local nearest, nearestDist
            for _, target in ipairs( player.GetAll() ) do
                local d = ghost:GetRangeTo( target )
                if not nearest or d < nearestDist then nearest, nearestDist = target, d end

            end

            if IsValid( nearest ) then
                local rumbo = math.NormalizeAngle( ( nearest:GetPos() - ghost:GetPos() ):Angle().y )
                local aPly  = math.abs( math.AngleDifference( rumbo, eyeYaw ) )

                nPly   = nPly + 1
                sumPly = sumPly + aPly
                maxPly = math.max( maxPly, aPly )
                minPly = math.min( minPly, aPly )

            end

            if n < total then return end

        end

        -----------------------------------------------------------------------
        -- EL VEREDICTO
        -----------------------------------------------------------------------
        fin( "" )

        if roto then
            fin( "[Phantasmagoria] MIRADA: SIN CORRER -- el regimen cambio en el segundo " ..
                string.format( "%.1f", roto.seg ) .. "." )
            fin( "    de  " .. roto.de )
            fin( "    a   " .. roto.a )
            fin( "    Esta fila mide UN regimen. Un promedio que cruza el borde no describe ninguno" ..
                " de los dos, asi que no se emite: rehacer la ventana entera del lado que se queria medir." )
            return

        end

        fin( "[Phantasmagoria] MIRADA: " .. n .. " muestras, regimen " .. reg0 .. " sostenido toda la ventana." )
        fin( "    caminando   " .. nMov .. " de " .. n .. " muestras a >= " .. FACEWALK_MIN_SPEED .. " u/s" ..
            "   <- EL DENOMINADOR de la linea de abajo" )

        if nMov <= 0 then
            fin( "    SIN CORRER: el bot no camino en ninguna muestra." )
            fin( "    Una mirada quieta en un bot parado es lo NORMAL -- no hay a donde mirar --" ..
                " asi que sin muestras caminando no hay como distinguir el defecto de lo normal." )
            fin( "    Hacer que camine ( alejarse, o phantasmagoria_hunt 1 ) y repetir." )
            return

        end

        fin( "    congelada   " .. nCongel .. " de " .. nMov .. " muestras CAMINANDO" ..
            "   ( ni la escribimos nosotros ni cambio en " .. LOOK_FROZEN_SECS .. " s )" )

        fin( "    giro        barrio " .. math.Round( barrido ) .. " grados en total" ..
            " · abanico " .. math.Round( dMax - dMin ) .. " grados   ( los dos en 0 = CLAVADA )" )

        -- ⚠ EL CARTEL QUE FALTABA EN LA R13, y sin el la fila 02 se marco verde
        -- midiendo el regimen equivocado. `hunt CON enemigo` NO es donde vivia el
        -- defecto: ahi manda la base y NOSOTROS tiene que dar 0 por diseno. La
        -- mitad del A/B que prueba el arreglo es `hunt SIN enemigo`, y esa se
        -- corrio una sola vez -- con facewalk 0, o sea el control.
        if reg0 == "hunt CON enemigo" then
            fin( "    ⚠ ESTE NO ES EL REGIMEN DEL ARREGLO. Con enemigo manda la base y NOSOTROS tiene" ..
                " que dar 0: es la fila de la OTRA guarda. El arreglo se mide en `hunt SIN enemigo`." )

        end

        fin( "    vs marcha   media " .. math.Round( sumMarcha / nMov, 1 ) ..
            " · max " .. math.Round( maxMarcha, 1 ) .. " grados   ( sobre las " .. nMov .. " caminando )" )

        -- Con nPly en 0 NO se imprime un 0: no habia jugadores y un 0 grados se
        -- leeria como "te apunta clavado", que es justo lo contrario. La misma
        -- trampa del cero sin denominador, dos lineas mas abajo.
        if nPly <= 0 then
            fin( "    vs jugador  ( no hubo jugadores en ninguna muestra: sin dato, no cero )" )

        else
            fin( "    vs jugador  media " .. math.Round( sumPly / nPly, 1 ) ..
                " · min " .. math.Round( minPly, 1 ) ..
                " · max " .. math.Round( maxPly, 1 ) .. " grados   ( sobre " .. nPly .. " )" )

        end

        -- El tercer balde NO se llama "NADIE" y eso es correccion de la r13: sin
        -- una marca adentro del shootAt de la base, "no cambio y no fuimos
        -- nosotros" no distingue "nadie escribio" de "la base escribio el mismo
        -- valor". *Un balde nombrado por la conclusion que uno quiere sacar la
        -- regala.*
        fin( "    la escribio NOSOTROS " .. nNuestra .. " · LA BASE " .. nBase ..
            " · nadie, o la base el mismo valor " .. nNadie .. "   ( de " .. n .. ", medido )" )

    end )

end, "phantasmagoria_ghost_look [seg] [regimen]  -- muestrea la mirada y da el veredicto. " ..
    "El regimen ( huntsin/huntcon/calmasin/calmacon ) es OPCIONAL y hace que el boton se niegue si el " ..
    "fantasma no esta en el. Se NIEGA ademas si hay mas de un fantasma, si el regimen cambia en el " ..
    "medio, o si el bot no camino en ninguna muestra." )

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_where", function( ply )
    local say = makeSay( ply )

    local found = eachGhost( function( ghost )
        local enemy = ghost:GetEnemy() -- terminator_nextbot_base/enemy.lua:20
        local tasks = {}

        -- ⚠ ESTA LISTA DECIA MENOS DE LO QUE TODO EL MUNDO LEYO EN ELLA, Y LO
        -- DESTAPO EL BLOQUE DEL ENCAJE. m_TaskList es el REGISTRO estatico:
        -- SetupTasks lo llena con todas las tareas declaradas
        -- ( taskoverride.lua:398-402 ) y nadie lo vacia nunca, ni cuando una
        -- tarea termina. Es lo que lee HasTask ( :148 ), que pregunta si la tarea
        -- EXISTE.
        --
        -- Lo que dice si una tarea esta CORRIENDO es m_ActiveTasks
        -- ( terminator_nextbot_base/tasks.lua:104, que es lo que lee
        -- IsTaskActive ), y de ahi si la saca endTask.
        --
        -- La diferencia no es academica: el reallystuck_handler de la base se
        -- termina a si mismo en su propio OnStart si ReallyStuckDisable esta
        -- puesto o si MoveSpeed <= 0 ( shared.lua:3660 y :3664 ), y en los dos
        -- casos SEGUIRIA APARECIENDO ACA. La unica evidencia que teniamos de que
        -- el rescate estaba vivo era esta lista, y esta lista no lo podia decir.
        -- *Una lista de lo que existe no puede contestar por lo que corre.*
        local activas = istable( ghost.m_ActiveTasks ) and ghost.m_ActiveTasks or {}
        local nActivas = 0

        if istable( ghost.m_TaskList ) then
            for name, _ in pairs( ghost.m_TaskList ) do
                local viva = activas[ name ] ~= nil
                if viva then nActivas = nActivas + 1 end

                table.insert( tasks, { name = name, viva = viva } )

            end

            table.sort( tasks, function( a, b ) return a.name < b.name end )

        end

        say( "#" .. ghost:EntIndex() .. "  " .. ghost:GetClass() )
        say( "    pos     " .. tostring( ghost:GetPos() ) )
        say( "    vida    " .. ghost:Health() .. " / " .. ghost:GetMaxHealth() )
        say( "    modelo  " .. tostring( ghost:GetModel() ) )
        say( "    hunt    " .. ( ghost.phantom_Hunting and "SI ( cazador )" or "NO ( fantasma )" ) )
        say( "    enemigo " .. ( IsValid( enemy ) and tostring( enemy ) or "ninguno" ) )

        -- Diseno 19, tajada A. Va JUSTO DEBAJO del hunt a proposito: el dia que
        -- la tajada C exista, las dos lineas se leen juntas -- "hunt SI" con
        -- "threshold 70 %" al lado dice si el disparo tiene sentido. Con guarda
        -- porque este comando es el que se tipea cuando algo no carga.
        if PHANTASMAGORIA.TypeLines then
            PHANTASMAGORIA.TypeLines( ghost, say )

        else
            say( "    tipo    ( server_type.lua no cargo )" )

        end

        lookLines( ghost, say )

        -- UNA linea de cada bloque nuevo, no su reporte entero: para eso estan
        -- phantasmagoria_ghost_speed y phantasmagoria_ghost_doors. Van aca
        -- porque durante una corrida el comando que se tipea todo el tiempo es
        -- este, y las dos cosas que cambiaron son justamente las que no se ven
        -- desde adentro del juego.
        local loco = ghost.loco

        say( "    veloc   deseada " .. math.Round( loco and loco:GetDesiredSpeed() or -1 ) .. " u/s" ..
            "   real " .. math.Round( ghost:GetCurrentSpeed() ) .. " u/s" ..
            ( ghost.phantom_speedDbg and ( "   objetivo " .. math.Round( ghost.phantom_speedDbg.target ) .. " u/s" ) or "   ( sin convertir todavia )" ) )

        local door = ghost.phantom_doorLast

        say( "    puerta  " .. ( IsValid( door ) and door:GetClass() or "ninguna delante" ) ..
            "   trabado " .. string.format( "%.1f", ghost.phantom_doorBlocked or 0 ) .. " s" ..
            "   peor " .. string.format( "%.1f", ghost.phantom_doorWorst or 0 ) .. " s" ..
            "   " .. ( ghost.phantom_Phasing and "ATRAVESANDO" or "solido" ) )

        -- una por linea: son el dato que mas dice y el que mas largo se pone
        if #tasks <= 0 then
            say( "    tareas  ninguna" )

        else
            say( "    tareas  " .. nActivas .. " ACTIVAS de " .. #tasks .. " registradas" )

            for _, task in ipairs( tasks ) do
                say( "        " .. ( task.viva and "* " or "  " ) .. task.name ..
                    ( task.viva and "" or "   ( solo registrada: NO esta corriendo )" ) )

            end
        end
    end )

    if found <= 0 then
        say( "[Phantasmagoria] no hay ningun fantasma vivo." )

    end

    say( "[Phantasmagoria] " .. found .. " fantasma(s). Navareas en el mapa: " .. navmesh.GetNavAreaCount() .. "." )

end, "Imprime donde esta cada fantasma de Phantasmagoria, y si el mapa tiene navmesh." )

---------------------------------------------------------------------------
-- Instrumento: a quien odia, y por que
---------------------------------------------------------------------------
-- Separa las DOS cosas que Diseno 3.1 confundia en una:
--   rel            el CACHE  ( m_EntityRelationships, escrito una sola vez )
--   ShouldBeEnemy  la PUERTA ( leida en vivo, y donde vive el interruptor )
-- Sin las dos al lado, "el bot no me ataca" no distingue entre "no me odia" y
-- "me odia y no puede".
--
-- Los nombres de las disposiciones se leen de los globales y no se hardcodean:
-- son enums del engine, o sea de un tercero.
local DISP_NAMES = {}

for _, name in ipairs( { "D_ER", "D_HT", "D_FR", "D_LI", "D_NU" } ) do
    local value = _G[ name ]
    if value then DISP_NAMES[ value ] = name end

end

local function dispName( d )
    return DISP_NAMES[ d ] or ( "??? (" .. tostring( d ) .. ")" )

end

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_rel", function( ply )
    local say = makeSay( ply )

    local found = eachGhost( function( ghost )
        local enemy = ghost:GetEnemy()

        say( "#" .. ghost:EntIndex() .. "  " .. ghost:GetClass() )
        say( "    hunt      " .. ( ghost.phantom_Hunting and "SI ( cazador )" or "NO ( fantasma )" ) ..
            "   NW " .. ( ghost:GetNWBool( "phantasmagoria_hunting", false ) and "SI" or "NO" ) )
        say( "    enemigo   " .. ( IsValid( enemy ) and tostring( enemy ) or "ninguno" ) )

        -- La vida NO es decoracion aca: el check del balazo ( ronda 1, fila 07 )
        -- tiene como precondicion que al bot le hayan pegado, y este comando no
        -- la mostraba. "Le tire" quedaba como afirmacion del que corre la
        -- planilla en vez de dato del instrumento. Con la vida a la vista, la
        -- precondicion se ve en la misma salida que el veredicto.
        say( "    vida      " .. ghost:Health() .. " / " .. ghost:GetMaxHealth() ..
            ( ghost:Health() < ghost:GetMaxHealth() and "   ( recibio dano )" or "   ( INTACTO: nadie le pego )" ) )

        -- El contador de la re-evaluacion. Si Diseno 3.1 tuviera razon, prender
        -- el hunt lo haria subir. El control es phantasmagoria_hunt_reeval.
        local calls = ghost.phantom_relCalls or 0
        local lastT = ghost.phantom_relLastTime

        say( "    OnFirstRelationWithPlayer  " .. calls .. " llamada(s)" ..
            ( lastT and ( ", la ultima a t=" .. math.Round( lastT, 1 ) ..
                " con hunt=" .. ( ghost.phantom_relLastHunting and "SI" or "NO" ) ) or "" ) )

        -- ⚠ EL FOV, Y NO ES DECORACION: es el numero que decide si la mirada
        -- congelada de la ronda 12 podia ademas dejarlo CIEGO. Con Term_FOV < 180
        -- la deteccion es un cono alrededor del aim ( FindInCone,
        -- enemyoverrides.lua:629 ) y IsInMyFov ( :281-285 ) descarta a todo lo que
        -- este a mas de 200 u fuera de el -- o sea que una cara clavada seria un
        -- bot ciego por atras, y las dos fallas serian UNA. Con 180 exactos,
        -- IsInMyFov devuelve true SIEMPRE y FindEnemies usa una esfera: la
        -- deteccion no depende de a donde mire. Nosotros lo ponemos en 180
        -- ( :398 ), asi que son DOS fallas separadas -- pero eso hay que poder
        -- LEERLO, porque un tercero que mueva termhunter_fovoverride lo cambia.
        say( "    Term_FOV  " .. tostring( ghost.Term_FOV ) ..
            ( ( tonumber( ghost.Term_FOV ) or 0 ) >= 180 and
                "   ( >= 180: ve en TODAS las direcciones, la mirada no lo ciega )" or
                "   ⚠ < 180: solo ve en un cono. Una mirada clavada lo deja ciego por atras." ) )

        local players = player.GetAll()

        if #players <= 0 then
            say( "    ( no hay jugadores )" )
            return

        end

        for _, target in ipairs( players ) do
            -- GetRelationship es el wrapper publico de TERM_GetRelationship
            -- ( enemyoverrides.lua:813-816 ). Lee el cache, no lo escribe.
            local disp, priority = ghost:GetRelationship( target )

            -- ShouldBeEnemy SI toca estado: adentro cachea shouldNotSeeEnemy
            -- ( enemyoverrides.lua:295-317 ). Se llama igual porque es LA puerta
            -- y no hay forma honesta de preguntarla sin preguntarla; el bot la
            -- corre solo cada ~0,5 s ( shared.lua:3164 ), asi que el instrumento
            -- no agrega una clase de perturbacion que no estuviera ya ahi.
            local should = ghost:ShouldBeEnemy( target, nil, ghost:GetTable(), target:GetTable() )

            -- ⚠ Y LA DISTANCIA SE IMPRIME CONTRA SU TOPE, no sola. Desde la
            -- r13b hay DOS motivos por los que ShouldBeEnemy puede decir NO con
            -- el hunt puesto -- `ai_ignoreplayers` y nuestro `sightdist` -- y un
            -- `NO` pelado manda a mirar el interruptor cuando puede ser el
            -- alcance. *Un gate nuevo que no se ve en el instrumento convierte
            -- cada uso posterior en un diagnostico equivocado.*
            local dist = ghost:GetRangeTo( target )
            local tope = cvSightDist:GetInt()

            say( "    ply " .. target:Nick() ..
                "   rel " .. dispName( disp ) .. " pri " .. tostring( priority ) ..
                "   ShouldBeEnemy " .. ( should and "SI" or "NO" ) ..
                "   dist " .. math.Round( dist ) .. " u" ..
                ( tope <= 0 and "   ( sightdist 0: SIN limite )" or
                    ( "   ( sightdist " .. tope .. ( dist > tope and " -- FUERA DE ALCANCE, corta aca )" or " )" ) ) ) )

            -----------------------------------------------------------------
            -- LA MITAD QUE FALTABA: la PUERTA abierta no alcanza, hace falta VER
            -----------------------------------------------------------------
            -- Reportado en juego tras la ronda 11: "no me sigue cuando esta
            -- cazando". Con solo ShouldBeEnemy, ese reporte no se puede contestar:
            -- un SI al lado de `enemigo ninguno` deja igual de vivas "la relacion
            -- esta mal" y "la relacion esta bien y no me ve", que son dos arreglos
            -- distintos en dos archivos distintos.
            --
            -- La base pide DOS visibilidades y por dos caminos que no son el
            -- mismo, asi que se imprimen los dos:
            --
            --   CanSeePosition   enemyoverrides.lua:566, es el que usa FindEnemies
            --                    ( TraceLine con LineOfSightMask, filtrando al bot )
            --   PosCanSee+Clear  shared.lua:3204-3206, la rama "cheap infinite view
            --                    distance" que revisa UN jugador por pase y es la
            --                    unica que ignora MaxSeeEnemyDistance ( 3000 u )
            --
            -- Un NO en la primera y SI en la segunda no es una contradiccion: la
            -- primera apunta al mejor hitbox y la segunda al mismo punto pero con
            -- un hull. Que difieran es informacion, no ruido.
            local myShoot    = ghost:GetShootPos()
            local theirShoot = ghost:EntShootPos( target )

            local canSeeFind = ghost:CanSeePosition( target, ghost:GetTable(), target:GetTable() )
            local canSeeCheap, tr = terminator_Extras.PosCanSee( myShoot, theirShoot )
            local clear = canSeeCheap and ghost:ClearOrBreakable( myShoot, theirShoot ) or false

            -- QUE lo tapa, y sale del trace que PosCanSee ya devolvio -- no de un
            -- trace nuestro. Sin esto, "no te ve" no distingue una pared del mapa
            -- de un prop que el jugador acaba de poner, y solo una de las dos es
            -- un problema del fantasma.
            local tapa = ""
            if not canSeeCheap and tr then
                tapa = "   lo tapa " .. ( IsValid( tr.Entity ) and tostring( tr.Entity ) or "el mundo ( brush )" ) ..
                    " a " .. math.Round( myShoot:Distance( tr.HitPos ) ) .. " u"

            end

            say( "        ve  CanSeePosition " .. ( canSeeFind and "SI" or "NO" ) ..
                " · PosCanSee " .. ( canSeeCheap and "SI" or "NO" ) ..
                " · ClearOrBreakable " .. ( clear and "SI" or "NO" ) ..
                " · IsSeeEnemy " .. ( ghost.IsSeeEnemy and "SI" or "NO" ) .. tapa )

            -----------------------------------------------------------------
            -- EL ESLABON DEL MEDIO, Y LA R13 LO PIDIO CON UN ROJO
            -----------------------------------------------------------------
            -- La fila 06 dio `ve SI` + `ShouldBeEnemy SI` + `enemigo ninguno` a
            -- 26.014 u, y con eso solo no se puede decir si es un defecto: entre
            -- "te ve" y "sos mi enemigo" hay DOS pasos de la base y ninguno se
            -- veia.
            --
            --   ① m_EnemiesMemory   se escribe con UpdateEnemyMemory, por DOS
            --                       caminos que no cuestan lo mismo
            --   ② FindPriorityEnemy la lee ( enemyoverrides.lua:709 ) y elige
            --
            -- ⚠ Y LOS DOS CAMINOS DE ① TIENEN LATENCIAS DISTINTAS, que es lo que
            -- explica por que la fila 05 adquirio a 283 u y la 06 no a 26.014:
            --
            --   FindEnemies ( shared.lua:3168 ) corre ANTES de FindPriorityEnemy
            --   en el mismo pase, asi que adentro de MaxSeeEnemyDistance ( 3000 u )
            --   la adquisicion es de UN pase.
            --
            --   La rama "cheap infinite view distance" ( :3185 ) es la unica que
            --   pasa de 3000 u, mira UN jugador por pase, y corre DESPUES de
            --   FindPriorityEnemy -- o sea que lo que escribe recien se lee en el
            --   pase SIGUIENTE. Con `UpdateEnemies` cada 0,5 s, **son ~1 s**.
            --
            -- Sin esta linea, mirar medio segundo despues de abrir la puerta se
            -- lee igual que un defecto. *Un mecanismo con latencia necesita que
            -- el instrumento diga cuanta, o el que mide la confunde con una falla.*
            local mem  = istable( ghost.m_EnemiesMemory ) and ghost.m_EnemiesMemory[ target ] or nil
            local hData = istable( ghost.m_ActiveTasks ) and ghost.m_ActiveTasks[ "enemy_handler" ] or nil

            say( "        mem " .. ( mem and ( "SI, hace " .. string.format( "%.1f", CurTime() - ( mem.lastupdate or CurTime() ) ) .. " s" ) or "NO" ) ..
                " · enemy_handler " .. ( hData and ( "proximo barrido en " ..
                    string.format( "%+.1f", ( hData.UpdateEnemies or CurTime() ) - CurTime() ) .. " s · idx " ..
                    tostring( hData.playerCheckIndex ) ) or "NO ESTA CORRIENDO" ) )

            -- El veredicto de las columnas juntas, escrito una sola vez para que
            -- no haya que cruzarlas a mano en la consola.
            if not should and tope > 0 and dist > tope then
                say( "        -> FUERA DE ALCANCE: " .. math.Round( dist ) .. " u contra un sightdist de " ..
                    tope .. " u. No es la relacion ni la vista." )
                say( "           Es NUESTRO limite, no el de la base: con sightdist 0 te tomaria igual" ..
                    " ( medido en la r13b a 31.253 u )." )

                -- ⚠ EL CASO QUE VA A CONFUNDIR, Y SALIO DE LA R14 SIN QUE NINGUNA
                -- FILA LO PIDIERA: el autor le pego un tiro entre la 01 y la 02, y
                -- las cuatro lecturas siguientes tienen `vida 827/900` con
                -- `rel D_HT pri 1000` -- que es MakeFeud ( enemyoverrides.lua:1046,
                -- "hate players more than anything else" ), disparado por
                -- PostTookDamage ( damageandhealth.lua:482 ).
                --
                -- ANTES del gate, pegarle desde cualquier distancia lo mandaba a
                -- buscarte. Ahora no: MakeFeud escribe la RELACION, y el gate corta
                -- ANTES de que la relacion se lea. *Un limite puesto delante de una
                -- cadena tambien tapa las entradas laterales de esa cadena, y las
                -- laterales son las que nadie recuerda.*
                --
                -- Se dice solo cuando el fantasma tiene dano encima, porque es el
                -- unico momento en que alguien va a preguntarse "le dispare y no
                -- viene".
                if ghost:Health() < ghost:GetMaxHealth() then
                    say( "           ⚠ Y ESTE FANTASMA TIENE DANO: le pegaste, MakeFeud le puso" ..
                        " D_HT pri 1000, y el gate lo tapa igual. Antes venia a buscarte desde cualquier lado." )

                end

            elseif not should then
                say( "        -> la PUERTA esta cerrada: ShouldBeEnemy NO. Mirar hunt y rel, no la vista." )

            elseif not ( canSeeFind or clear ) then
                say( "        -> puerta abierta y NO te ve. No es la relacion: es que no hay linea de vision." )

            -- Contra ESTE jugador y no contra "hay algun enemigo": con dos
            -- jugadores, un `IsValid( enemy )` suelto le pondria el verde del
            -- primero a las lineas de todos.
            elseif enemy == target then
                say( "        -> puerta abierta, te ve y SOS el enemigo. La cadena entera funciona." )

            elseif not mem then
                say( "        -> te ve y NO estas en la memoria todavia. NO es un defecto sin esperar:" ..
                    " arriba de " .. tostring( ghost.MaxSeeEnemyDistance ) .. " u la adquisicion pide DOS" ..
                    " barridos ( ~1 s ) y el proximo esta en la linea de arriba." )
                say( "           Repetir el comando pasados 3 s. Si a los 3 s sigue sin memoria, ENTONCES si." )

            else
                say( "        -> ⚠ te ve, ESTA en la memoria y aun asi no sos el enemigo." ..
                    " El defecto esta en FindPriorityEnemy ( enemyoverrides.lua:694 ), no en la vista ni en la relacion." )

            end
        end
    end )

    if found <= 0 then
        say( "[Phantasmagoria] no hay ningun fantasma vivo." )

    end
end, "Imprime, por fantasma y por jugador, la relacion cacheada y el resultado en vivo de ShouldBeEnemy." )

---------------------------------------------------------------------------
-- ANDAMIO: el gatillo manual del hunt
---------------------------------------------------------------------------
-- ESTO NO ES DISENO, ES UN ANDAMIO, y se tira cuando exista la cordura.
--
-- El hunt de Phasmophobia lo dispara la cordura del jugador ( Diseno 4 y 19 ), y
-- la cordura no existe todavia. Sin gatillo, el interruptor no se puede ver en
-- juego: quedaria escrito y sin ejercer, que es exactamente la clase de cosa que
-- este proyecto arrastra en la advertencia final de ESTADO.md.
--
-- Cuando la cordura exista, el que llama a phantom_SetHunting es ella y este
-- comando se borra ( o queda de utileria de test, pero nunca de mecanica ).
local function adminOnly( ply )
    if not IsValid( ply ) then return true end -- consola del servidor
    if ply:IsAdmin() then return true end

    ply:PrintMessage( HUD_PRINTCONSOLE, "[Phantasmagoria] hace falta ser admin." )
    return false

end

PHANTASMAGORIA.AddCommand( "phantasmagoria_hunt", function( ply, _, args )
    if not adminOnly( ply ) then return end

    local say = makeSay( ply )
    local arg = args and args[ 1 ]

    if arg ~= "0" and arg ~= "1" then
        say( "[Phantasmagoria] uso: phantasmagoria_hunt 0|1   ( 0 = fantasma, 1 = cazador )" )

        local found = eachGhost( function( ghost )
            say( "    #" .. ghost:EntIndex() .. " hunt " .. ( ghost.phantom_Hunting and "SI" or "NO" ) )

        end )

        if found <= 0 then say( "    no hay ningun fantasma vivo." ) end
        return

    end

    local hunting = arg == "1"

    -- SOLO toca el flag. No re-dispara la relacion, no limpia memoria, no toca
    -- tareas: es el interruptor de Diseno 3.1 tal cual esta escrito, para que la
    -- corrida pueda medir que hace la base sola y que no.
    local found = eachGhost( function( ghost )
        ghost:phantom_SetHunting( hunting )

        say( "    #" .. ghost:EntIndex() .. "  hunt -> " .. ( hunting and "SI ( cazador )" or "NO ( fantasma )" ) ..
            "   llamadas a OnFirstRelationWithPlayer: " .. ( ghost.phantom_relCalls or 0 ) )

    end )

    if found <= 0 then
        say( "[Phantasmagoria] no hay ningun fantasma vivo." )
        return

    end

    say( "[Phantasmagoria] " .. found .. " fantasma(s) en " .. ( hunting and "HUNT" or "calma" ) ..
        ". Solo se movio el flag: ni la relacion ni la memoria se tocaron." )

end, "ANDAMIO. Prende ( 1 ) o apaga ( 0 ) el hunt de todos los fantasmas. Lo va a reemplazar la cordura." )

-- CONTROL del contador de arriba, no mecanismo.
--
-- Si phantasmagoria_hunt 1 no mueve las llamadas a OnFirstRelationWithPlayer,
-- hay dos explicaciones posibles: la base no re-evalua, o el contador esta roto.
-- Este comando dispara la re-evaluacion a mano. Si con el SI sube, el contador
-- funciona y lo que no ocurre es la re-evaluacion -- que es lo que hay que
-- medir, no suponer.
--
-- SetupEntityRelationship es ENT:SetupEntityRelationship( myTbl, ent, entsTbl )
-- ( enemyoverrides.lua:880 ). Su timer.Simple( 0 ) le pone la relacion reciproca
-- a ent, pero solo "if ent.AddEntityRelationship" ( :893 ), y un jugador no
-- tiene ese metodo: sobre jugadores es no-op.
--
-- OJO CON UN EFECTO QUE HOY NO SE VE: cada re-disparo vuelve a pasar por el
-- cuerpo default de OnFirstRelationWithPlayer, que lleva la cuenta
-- ExtraSpawnHealthPlayersDone y suma vida por jugador ( damageandhealth.lua:872-885 ).
-- Hoy sale por el "if not extraHpPerPly then return end" de la primera linea,
-- porque no declaramos ExtraSpawnHealthPerPlayer. El dia que se declare, este
-- comando INFLA la vida del fantasma cada vez que se lo llama -- que es
-- precisamente por que es un control de desarrollo y no una mecanica.
PHANTASMAGORIA.AddCommand( "phantasmagoria_hunt_reeval", function( ply )
    if not adminOnly( ply ) then return end

    local say = makeSay( ply )

    local found = eachGhost( function( ghost )
        local before = ghost.phantom_relCalls or 0
        local myTbl  = ghost:GetTable()

        for _, target in ipairs( player.GetAll() ) do
            ghost:SetupEntityRelationship( myTbl, target, target:GetTable() )

        end

        say( "    #" .. ghost:EntIndex() .. "  llamadas a OnFirstRelationWithPlayer: " ..
            before .. " -> " .. ( ghost.phantom_relCalls or 0 ) )

    end )

    if found <= 0 then
        say( "[Phantasmagoria] no hay ningun fantasma vivo." )

    end
end, "CONTROL. Re-dispara SetupEntityRelationship por jugador, para probar que el contador de re-evaluaciones esta vivo." )

---------------------------------------------------------------------------
-- ANDAMIO: mover los flags sin lua_run
---------------------------------------------------------------------------
-- La ronda 3 no pudo medir DOS filas por esto, y la causa no era el mecanismo:
-- el lua_run que le di al autor escribe el campo en la ENTIDAD, y todo fantasma
-- spawneado despues nace con el default de la clase. El override se perdia al
-- respawnear y nada lo decia -- se lee como "el flag no funciona".
--
-- La regla que deja: un ANDAMIO de prueba tiene que sobrevivir al ciclo de vida
-- de lo que prueba. Si para volver a medir hay que re-aplicarlo a mano, la
-- medicion depende de que nadie se olvide, y alguien se olvida.
--
-- Los nombres cortos son a proposito: se tipean en juego, con el fantasma
-- encima. "auto" borra el override y devuelve el mando al campo de la clase.
local FLAGS = {
    [ "abrir" ]     = { campo = "phantom_OpensDoors",       que = "abre puertas cerradas" },
    [ "atravesar" ] = { campo = "phantom_PhasesDoors",      que = "atraviesa las puertas" },
    [ "silencio" ]  = { campo = "phantom_SilentDoors",      que = "abre sin hacer ruido" },
    [ "caminar" ]   = { campo = "phantom_WalksWhenHunting", que = "camina en vez de correr cazando" },
    [ "pasos" ]     = { campo = "phantom_SilentSteps",      que = "camina sin hacer ruido ( el Myling )" },
}

local FLAG_ORDER = { "abrir", "atravesar", "silencio", "caminar", "pasos" }

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_flag", function( ply, _, args )
    if not adminOnly( ply ) then return end

    local say  = makeSay( ply )
    local name = args and args[ 1 ]
    local val  = args and args[ 2 ]
    local flag = name and FLAGS[ string.lower( name ) ]

    if not flag or ( val ~= "0" and val ~= "1" and val ~= "auto" ) then
        say( "[Phantasmagoria] uso: phantasmagoria_ghost_flag <nombre> <0|1|auto>" )
        say( "    auto = sin override, manda el campo de cada clase de fantasma." )

        for _, key in ipairs( FLAG_ORDER ) do
            local f   = FLAGS[ key ]
            local ov  = PHANTASMAGORIA.FlagOverrides[ f.campo ]

            say( "    " .. key .. string.rep( " ", 11 - #key ) ..
                ( ov == nil and "auto" or ( ov and "1   " or "0   " ) ) ..
                "  " .. f.campo .. "   ( " .. f.que .. " )" )

        end

        return

    end

    if val == "auto" then
        PHANTASMAGORIA.FlagOverrides[ flag.campo ] = nil

    else
        PHANTASMAGORIA.FlagOverrides[ flag.campo ] = val == "1"

    end

    -- El override NO toca los campos de las entidades: lo consulta el
    -- resolvedor, antes del campo. Asi se puede volver a "auto" sin haber
    -- pisado nada, que es lo que un lua_run no permite deshacer.
    local vivos = eachGhost( function() end )

    say( "[Phantasmagoria] " .. name .. " -> " .. val ..
        "   ( " .. flag.campo .. ", " .. flag.que .. " )" )
    say( "    alcanza a los " .. vivos .. " fantasma(s) vivos Y a los que spawneen despues." )
    say( "    verificar con phantasmagoria_ghost_doors: la linea dice el motivo que gano." )

end, "ANDAMIO. Pisa un flag de comportamiento en todos los fantasmas, vivos y futuros. Sin argumentos lista los cuatro." )

---------------------------------------------------------------------------
-- LA TAREA DE CLASE, y los dos bloques que cuelgan de ella
---------------------------------------------------------------------------
-- ENT.MyClassTask es el punto de extension que la base declara para agregar
-- comportamiento propio sin reescribir el cerebro ( taskoverride.lua:328-332,
-- "Simple way to add class-specific behaviour to a bot" ). DoClassTasks recorre
-- el arbol de bases, levanta el MyClassTask de cada clase y lo registra como
-- "<clase>_handler" con StartsOnInitialize forzado ( :344-358 ), o sea que la
-- nuestra se va a llamar terminator_nextbot_phantom_handler y va a APARECER POR
-- NOMBRE en la lista de tareas de phantasmagoria_ghost_where. "Se engancho" deja
-- de ser una suposicion y pasa a ser una linea de la salida.
--
-- Se declara VACIA aca y la llenan los dos archivos de abajo, cada uno con su
-- callback. Si alguno la declarara por su cuenta, el segundo pisaria al primero
-- y el sintoma seria un bloque entero que no corre, sin un solo error.
--
-- La lee scripted_ents.GetStored( clase ).t ( terminator_nextbot_base/shared.lua:169 ),
-- que es la tabla REGISTRADA -- y GMod registra la entidad recien despues de
-- correr shared.lua entero, includes adentro. Por eso alcanza con definirla
-- aca abajo y no hace falta adelantarla.
ENT.MyClassTask = {}

-- Diseno 19, tajada A: el TIPO de fantasma ( uno de los 30 ). Va PRIMERO de la
-- lista porque es el unico que no consume nada de los otros y porque los otros
-- van a colgar de el: speed.base ( Diseno 5 ) y el hunt.threshold de la tajada C
-- son campos DEL TIPO. Hoy no cambia ningun comportamiento: asigna, networkea y
-- publica el dato.
include( "server_type.lua" )

-- Diseno 1.1: la velocidad se deriva de la carrera real del jugador.
include( "server_speed.lua" )

-- Pedido del autor: que PASE las puertas, abriendolas fisicamente.
include( "server_doors.lua" )

-- Pedido del autor: que se le pueda quitar el sonido a las PISADAS, con la
-- restriccion de que el Paramic tenga que poder oirlas despues.
--
-- VA DESPUES DE server_doors.lua Y NO ES INDISTINTO: PHANTASMAGORIA.ResolveFlag
-- se define alli, y este archivo lo consume. server_speed.lua tiene el problema
-- al reves -- se incluye ANTES y lo resuelve en tiempo de ejecucion, con una
-- guarda -- y ese desorden ya esta anotado en ESTADO.md como pendiente. No se
-- arregla en esta ronda a proposito: mover ResolveFlag es un cambio de cero
-- comportamiento, y meterlo en la misma ronda que un mecanismo nuevo convierte
-- un rojo en un misterio.
include( "server_steps.lua" )

-- Reportado por el autor: el fantasma salta, queda encajado entre props y el
-- techo, y hay que sacarlo con el physgun. INSTRUMENTO SOLO -- mide el rescate
-- de la base ( reallystuck_handler ) y los saltos, y no cambia comportamiento.
--
-- VA DESPUES DE server_doors.lua, y la guarda del final de ese archivo lo
-- comprueba: no usa ENT.MyClassTask ( la clave Think ya es de las puertas ) sino
-- ENT:AdditionalThink, que la base declara como stub libre.
include( "server_stuck.lua" )

---------------------------------------------------------------------------
-- GUARDA: un campo pisado por un metodo del mismo nombre
---------------------------------------------------------------------------
-- DEFECTO MEDIDO EN LA RONDA 4. ENT.phantom_WalksWhenHunting era un CAMPO
-- ( false ) y en server_speed.lua habia un METODO homonimo. Como los includes
-- corren despues, la funcion pisaba al campo: el resolvedor leia una funcion
-- -- que no es true ni false -- y caia a la rama "el flag es nil".
--
-- Se veia en cada linea del reporte ( "campo = function: 0x8088..." ) y aun asi
-- el check que lo ejercia PASO, porque el default de la rama nil coincidia con
-- lo que se esperaba. *Un default que coincide con lo esperado convierte un
-- campo roto en un check verde*, y eso no lo agarra ninguna corrida: lo agarra
-- una guarda o nadie.
--
-- Corre DESPUES de los dos includes a proposito: antes de ellos el pisado
-- todavia no ocurrio, y una guarda que mira demasiado temprano es una guarda
-- que siempre pasa. Y la lista sale de FLAGS, o sea de la misma tabla que usa
-- el comando: si aparece un flag nuevo, queda cubierto sin tocar esto.
for _, key in ipairs( FLAG_ORDER ) do
    local campo = FLAGS[ key ].campo

    if isfunction( ENT[ campo ] ) then
        ErrorNoHalt( "[Phantasmagoria] EL CAMPO '" .. campo .. "' esta PISADO por un metodo del mismo " ..
            "nombre. El resolvedor va a leer una funcion y va a creer que el flag no esta declarado, " ..
            "sin tirar error. Renombrar el metodo.\n" )

    end
end
