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
    --
    -- `nuestro`: sale del TALLER, o sea que tiene las 7 actividades portadas a
    -- nuestro esqueleto y pide el hull del fantasma. Lo miran los dos bloques de
    -- abajo. NO es lo mismo que "es el primero de la lista" -- ver el comentario
    -- de `esNuestroModelo`.
    { mdl = "models/phantasmagoria/ghost_girl.mdl", nuestro = true },

    -- LOS OTROS DOS DEL TALLER ( 2026-08-10 ), para que el bot no tenga solo a
    -- la nena. Mismo pipeline, mismos 53/56 huesos ValveBiped, mismo ragdoll de
    -- 15 solidos, mismas 7 actividades nuestras + ACT_LAND prestada.
    --
    -- ⚠ VAN DESPUES DE LA NENA A PROPOSITO: `pickModel` devuelve EL PRIMERO que
    -- exista, asi que este orden es una PRIORIDAD y no una lista. Ponerlos
    -- arriba cambiaria el fantasma que sale por defecto sin que nadie lo pida --
    -- y la nena es la unica de las tres con una pasada en juego cerrada.
    --
    -- Ghost_Male: 72.29 u, o sea del tamano de un playermodel ( male_07 mide
    -- 72.00 ), asi que el hull {-16,-16,0},{16,16,72} le entra sin tocar nada.
    { mdl = "models/phantasmagoria/ghost_male.mdl", nuestro = true },

    -- Ghost_OldCrone: 68.98 u. Es la primera de la familia CATRig ( son 8
    -- entidades ) y la primera con TRES materiales y el pelo TRANSLUCIDO.
    { mdl = "models/phantasmagoria/ghost_oldcrone.mdl", nuestro = true },

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

--[[
    ⚠ `ph_ghost_modelo` NO gobierna ESTA lista, y el autor lo reporto como "el
    comando no funciona": gobierna los comandos `ph_ghost_*` de
    autorun/server/phantasmagoria_ghostmodel.lua, que spawnean sus propios
    sujetos -- y ahi SI funciona ( con la convar en ghost_oldcrone,
    `ph_ghost_ragdoll` spawneo la vieja ). Lo que salia con la nena era el
    NextBot, que elige por esta funcion y devuelve EL PRIMERO que exista.

    Son dos mecanismos distintos y hasta hoy solo uno tenia perilla. Esta convar
    es la del bot; vacia mantiene el orden de MODEL_CANDIDATES, que es lo que
    habia.

    ⚠ HISTORIA DE ESTE COMENTARIO, PORQUE YA MINTIO DOS VECES Y DE FORMAS
    OPUESTAS. Decia "se resuelve en cada spawn, no se cachea": era falso, y el
    2026-08-17 el autor puso `ghost_male`, spawneo y salio la nena. Se corrigio
    a "hay que recargar el mapa", que era cierto pero describia un defecto en vez
    de arreglarlo. Ahora es cierto Y no hace falta recargar: la resolucion vive
    en `aplicarModeloDelBot()` y un `cvars.AddChangeCallback` la rehace, con
    aviso por consola de en que quedo.

    Toma efecto en el PROXIMO spawn; los fantasmas ya vivos no cambian.
    FCVAR_ARCHIVE la guarda entre sesiones.
]]
local cvBotModelo = CreateConVar( "phantasmagoria_bot_modelo", "", FCVAR_ARCHIVE,
    "Fuerza el modelo del NextBot ( ghost_girl, ghost_male, ghost_oldcrone ). " ..
    "Vacio = el primero de MODEL_CANDIDATES que exista." )

local function pickModel()
    local forzado = string.Trim( cvBotModelo:GetString() or "" )

    if forzado ~= "" then
        local ruta = "models/phantasmagoria/" .. forzado .. ".mdl"

        -- ⚠ SE BUSCA EN LA LISTA, no se arma una entrada nueva. Devolver
        -- `{ mdl = ruta }` pelado --que es lo que hacia-- perdia el `skin` y el
        -- `nuestro` de la entrada, y sin `nuestro` el bot sale SIN la traduccion
        -- de actividades y SIN el hull del fantasma. O sea que forzar un modelo
        -- del taller lo rompia, en silencio, con las dos correcciones que ese
        -- modelo necesita: *la perilla para probar un modelo apagaba lo que
        -- habia que probar.*
        for _, cand in ipairs( MODEL_CANDIDATES ) do
            if cand.mdl == ruta and util.IsValidModel( ruta ) then
                ghostPrint( "modelo FORZADO por phantasmagoria_bot_modelo: " .. ruta )
                return cand, true

            end
        end

        if util.IsValidModel( ruta ) then
            -- Existe pero no esta en la lista: se usa igual --el autor lo pidio
            -- por nombre-- pero SIN las correcciones, y diciendolo. Callarselo
            -- seria el mismo defecto de arriba con otra ropa.
            ghostPrint( "modelo FORZADO por phantasmagoria_bot_modelo: " .. ruta ..
                " -- NO esta en MODEL_CANDIDATES, asi que va sin la traduccion de" ..
                " actividades ni el hull del fantasma." )
            return { mdl = ruta }, true

        end

        -- Un nombre mal escrito no puede quedarse callado: sin este aviso, el
        -- bot sale con la nena y se lee como "la convar no funciona", que es
        -- exactamente la confusion que esta perilla viene a resolver.
        ghostPrint( "phantasmagoria_bot_modelo = '" .. forzado .. "' -> " .. ruta ..
            " NO esta montado; se sigue con la lista." )

    end

    for _, cand in ipairs( MODEL_CANDIDATES ) do
        if util.IsValidModel( cand.mdl ) then return cand end

    end

    -- Ultimo recurso: la cadena literal "terminator", que shared.lua:2983
    -- traduce al modelo de la convar termhunter_modeloverride (Arnold por
    -- default). Feo a proposito: si sale Arnold, el modelo no esta montado.
    return { mdl = "terminator" }

end

-- Los resuelve `aplicarModeloDelBot()`, al final de esta seccion y otra vez cada
-- vez que cambia la convar. Se DECLARAN aca porque los leen las funciones de
-- spawn de mas abajo, que cierran sobre ellos.
local chosen, porConvar

-- ⚠ `ENT.Models` y `ENT.ModelSkin` NO se escriben aca: los escribe
-- `aplicarModeloDelBot()`, mas abajo, que es el UNICO lugar donde se aplica el
-- modelo. Estaban aca y la tabla de traduccion de actividades se aplicaba 80
-- lineas despues, o sea que el modelo se decidia en dos sitios y sólo uno podia
-- rehacerse cuando cambia la convar. Ver el comentario de esa funcion.
--
-- Nil cuando el modelo no declara skin propio: shared.lua:2989 solo lo aplica
-- "if isnumber( myTbl.ModelSkin )", asi que nil deja el 0 del modelo y no
-- inventa un indice que ese .mdl puede no tener.

-- Si el elegido salio del TALLER, se sabe aca y lo miran los dos bloques de
-- abajo ( el hull y la traduccion de actividades ). Los dos son correcciones
-- para NUESTROS modelos y aplicarselas al cadaver de HL2 -- que mide 76 u y trae
-- las de m_anm sin portar -- seria romperlo.
--
-- ⚠ ANTES DECIA `chosen.mdl == MODEL_CANDIDATES[ 1 ].mdl`, o sea "es la nena".
-- El Male y la OldCrone salen del MISMO pipeline --mismos huesos ValveBiped,
-- mismo ragdoll de 15 solidos, mismas 7 actividades + ACT_LAND-- y con esa
-- linea corrian SIN las dos correcciones que necesitan. El bot se habria visto
-- mal y la culpa habria caido sobre el port. *Un criterio que dice "es el
-- primero de la lista" cuando quiere decir "es de los nuestros" acierta hasta
-- el dia que hay un segundo.*
local esNuestroModelo = false

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
local IDLE_NUESTRA = ACT_HL2MP_IDLE
local TRADUCCIONES_NUESTRAS
do
    TRADUCCIONES_NUESTRAS = {
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
-- DONDE SE APLICA EL MODELO, QUE AHORA ES UN SOLO LUGAR
---------------------------------------------------------------------------
--[[
    ⚠ EL DEFECTO QUE ESTO ARREGLA, MEDIDO EN JUEGO EL 2026-08-17. El autor puso
    `phantasmagoria_bot_modelo ghost_male`, spawneo desde el spawnmenu y salio la
    NENA -- y sin el aviso `modelo FORZADO`, que es la pista de que `pickModel()`
    ni se llamo. La causa: corria UNA sola vez, a nivel de archivo, y su
    resultado quedaba en `ENT.Models`, que es de la CLASE. La convar se leia al
    cargar y nunca mas, asi que la perilla solo servia antes de que el archivo
    existiera.

    Y habia una razon estructural para que nadie lo notara: el modelo se aplicaba
    en DOS sitios separados por ochenta lineas --`Models`/`ModelSkin` arriba, la
    tabla de actividades abajo-- asi que no habia un lugar al que volver a
    llamar. Primero se junta, despues se puede rehacer. *Una decision que se
    aplica en dos lugares no se puede deshacer en ninguno.*

    Se escribe en la tabla de la CLASE a proposito: la base lee `self.Models`
    cuando construye cada instancia --por eso nuestro `ENT.Models` de la carga
    funcionaba, siendo que la base ya habia corrido-- asi que reescribirla
    alcanza para el PROXIMO spawn. Los fantasmas ya vivos no cambian, que es lo
    correcto: nadie pidio mutarlos.
]]

-- `ENT` deja de existir cuando termina de cargar el archivo, y el callback de la
-- convar corre despues. Sin esta referencia el callback no tendria a quien
-- escribirle.
local CLASE = ENT

local function aplicarModeloDelBot()
    chosen, porConvar = pickModel()
    esNuestroModelo = chosen.nuestro == true

    CLASE.Models    = { chosen.mdl }
    CLASE.ModelSkin = chosen.skin

    -- nil devuelve las de la base, que es lo que corresponde a un modelo ajeno:
    -- nuestras 7 actividades no existen ahi y traducirle a ellas lo romperia.
    CLASE.IdleActivity             = esNuestroModelo and IDLE_NUESTRA or nil
    CLASE.IdleActivityTranslations = esNuestroModelo and TRADUCCIONES_NUESTRAS or nil

    -- ⚠ Solo avisa de una CAIDA, no de una eleccion. Sin el `not porConvar`,
    -- forzar ghost_male imprimia "el modelo ghost_girl.mdl no esta montado" --
    -- falso, y manda a buscar un problema de montaje que no existe.
    if not porConvar and chosen ~= MODEL_CANDIDATES[ 1 ] then
        ghostPrint( "el modelo ", MODEL_CANDIDATES[ 1 ].mdl, " no esta montado. Uso ",
            chosen.mdl, " en su lugar.\n" )

    end
end

aplicarModeloDelBot()

-- La perilla, ahora caliente. Se dice en que queda y DESDE CUANDO: un cambio que
-- no avisa se lee como "no funciono" y ya costo una pasada entera.
cvars.AddChangeCallback( "phantasmagoria_bot_modelo", function()
    aplicarModeloDelBot()
    ghostPrint( "phantasmagoria_bot_modelo cambio -> el PROXIMO fantasma sale con ",
        chosen.mdl, esNuestroModelo and "  ( con hull y actividades nuestras )"
            or "  ( AJENO: sin hull ni actividades nuestras )",
        ".  Los que ya estan vivos no cambian.\n" )

end, "phantasmagoria_modelo_del_bot" )

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
-- ⚠ CUANDO SE MIDE EL HULL, Y ES LA FILA 03 QUE SALIO ROJA EN LA RONDA 16
---------------------------------------------------------------------------
-- La fila imprimio `hull 19x40x55` donde el criterio pedia `20x20x45`, y
-- 19x40x55 es EXACTAMENTE el hull de COLISION del .mdl ( 18,90 x 40,14 x 54,55,
-- del .phy del ragdoll ). O sea que no leyo mal: leyo TEMPRANO, cuando
-- GetCollisionBounds todavia devolvia la OBB que el modelo trae de su .phy.
--
-- LA CAUSA FUE EL INSTANTE. Mi `timer.Simple( 0, ... )` se registraba adentro de
-- AdditionalInitialize ( shared.lua:3011 ) y el de la base -- el que llama a
-- SetupCollisionBounds -- en :3039. Los timers de delay 0 disparan EN ORDEN DE
-- REGISTRO, no "despues": el mio corria primero y leia antes de que nadie
-- escribiera.
--
-- *Un timer.Simple(0) no es «despues»: es «en orden de registro».* Y la otra
-- leccion de esa fila: escribi el comentario que advierte de esta trampa para
-- OBBMaxs() y cai una linea mas abajo con GetCollisionBounds(). Documentar un
-- modo de falla no protege a la linea de al lado.
--
-- EL ARREGLO NO ES UN TIMER MAS LARGO. `timer.Simple( 0.25 )` alcanzaria hoy,
-- pero seria el mismo instrumento apostando a que la base no cambie de orden --
-- y la apuesta no se veria fallar: volveria a imprimir un numero creible. Asi
-- que se mide DONDE OCURRE: enganchado a SetupCollisionBounds, que es la funcion
-- que escribe el hull. Deja de existir el instante que adivinar.
--
-- ⚠ Y EL MECANISMO SIEMPRE ANDUVO: lo probo la otra columna del mismo print.
-- `ojos z 40` = round( 45 - (45/72)*8 ) con NUESTRO maxs.z, y el control
-- negativo ( convar en 0 ) dio 64, que es el de la base. El A/B quedo probado
-- por los ojos, no por el hull.
function ENT:SetupCollisionBounds( myTbl )
    local base = self.BaseClass and self.BaseClass.SetupCollisionBounds

    if not isfunction( base ) then
        -- Sin la de la base no hay hull. Se avisa UNA vez y se sigue: un bot sin
        -- collision bounds se ve enseguida, pero un aviso por frame tapa la
        -- consola y con ella cualquier otra medicion.
        if not self.phantom_avisoSetupBounds then
            self.phantom_avisoSetupBounds = true
            ghostPrint( "SetupCollisionBounds de la base NO ENCONTRADA. El fantasma se queda " ..
                "sin hull: esto es un defecto del enganche del instrumento, no del modelo.\n" )

        end

        return

    end

    base( self, myTbl )

    -- Una sola vez. La base la llama de nuevo en cada agachada y en cada salto
    -- ( motionoverrides.lua:70, :2996, :3432, :3621 ), y un print por salto seria
    -- ruido -- pero peor: la linea del spawn dejaria de ser la del spawn.
    if self.phantom_hullReportado then return end
    self.phantom_hullReportado = true

    local mins, maxs = self:GetCollisionBounds()

    -- ⚠ EL ALTO DE LA MALLA ES UNA CONSTANTE MEDIDA FUERA DE JUEGO Y TIENE QUE
    -- SERLO. En juego NO hay forma de preguntarlo: OBBMaxs() devuelve las
    -- collision bounds -- o sea justo lo que acabamos de escribir, con lo que la
    -- comparacion daria 45 contra 45 y siempre "OK" -- y GetModelBounds()
    -- devuelve el hull del .phy, que en este modelo llega a 46,65 porque es el
    -- del ragdoll. Los dos contestan con un numero creible a una pregunta que no
    -- es la que se hizo, y ese error ya se pago tres veces en este taller.
    -- 44,94 sale del .vvd ( vvdbounds.py sobre ghost_girl.vvd ), que es la unica
    -- fuente que contiene la malla y nada mas.
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
        "  [ medido DENTRO de SetupCollisionBounds, no en un timer ]",
        "\n" )

end

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
-- ⚠ Y TAMPOCO LEVANTA UN ARMA DEL PISO. LOS DOS SINTOMAS DE LA r17 SON ESTO
---------------------------------------------------------------------------
-- `DefaultWeapon = false` dice con que NACE, no que no pueda agarrar una: la
-- tarea `movement_getweapon` ( shared.lua:4637 ) sigue registrada y el bot
-- levanta lo que encuentre. En la corrida de la r17 agarro una SMG, y eso
-- produjo LOS DOS defectos que el autor reporto en el mismo mensaje --
-- «tambien tomo un arma y se deformo» y la POSE T --, que resultaron ser el
-- mismo bug. La cadena esta MEDIDA en el dump del actlog:
--
--   3115.93  Translate  ACT_MP_CROUCHWALK -> ACT_HL2MP_WALK_CROUCH_SMG1 (1801)
--   3116.25  Translate  ACT_MP_STAND_IDLE -> ACT_HL2MP_IDLE_SMG1 (1797)
--   3117.13  Translate  ACT_LAND (33)     -> ACT_INVALID (-1)
--   3117.13  Gesture    ACT_INVALID (-1)
--
-- (1) `TranslateActivity` le pregunta AL ARMA **antes** que a nuestra tabla
--     ( motionoverrides.lua:3694, la rama `way #2`, y nuestro
--     IdleActivityTranslations recien se consulta en :3712 ). Con un arma en la
--     mano toda nuestra traduccion queda anulada y el modelo vuelve a las
--     actividades PRESTADAS de m_anm -- las `*_SMG1` de arriba. Eso es el
--     estiramiento: la nena de 1,14 m tomando las distancias del adulto de 1,83.
--
-- (2) Y `luaWep:TranslateActivity( ACT_LAND )` devuelve **-1**, porque un arma no
--     sabe traducir un aterrizaje. La base hace `if newact then return newact end`
--     y **-1 es truthy en Lua**, asi que ese -1 sale tal cual y termina en
--     `DoGesture( -1 )` ( :3456 ) -> `AddGesture( -1 )` -> **la pose de
--     referencia**. Ahi esta la POSE T.
--
-- *Dos sintomas que se reportaron como cosas distintas, con causas que parecian
-- de capas distintas -- un modelo estirado y una animacion faltante --, y eran
-- el mismo evento.* Lo que los junto fue el dump, no la lectura del codigo.
--
-- EL ARREGLO VA EN LA CAUSA: un fantasma de Phasmophobia no usa armas. Se
-- sobreescribe `CanPickupWeapon` ( weapons.lua:885 ), que es lo que consultan
-- tanto la tarea como el pickup automatico, en vez de sacar la tarea -- asi el
-- bot puede seguir yendo hacia un arma si algun dia eso sirve de senuelo, pero
-- no se la lleva.
--
-- La convar existe para que el A/B sea posible: en 1 vuelve a agarrar armas y
-- los dos defectos tienen que reaparecer JUNTOS. Si reaparece uno solo, el
-- diagnostico de arriba esta incompleto.
local cvPickup = CreateConVar( "phantasmagoria_ghost_pickup", "0", FCVAR_ARCHIVE,
    "El fantasma puede levantar armas del piso. En 0 ( default ) no puede: con un arma en la mano " ..
    "la base traduce las actividades contra el ARMA y no contra nuestra tabla, asi que el modelo " ..
    "vuelve a las prestadas de m_anm ( se estira ) y ACT_LAND pasa a ACT_INVALID ( pose T ). " ..
    "En 1 sirve de control negativo: los dos defectos tienen que volver juntos.", 0, 1 )

function ENT:CanPickupWeapon( wep, doingHolstered, myTbl, wepsTbl )
    if not cvPickup:GetBool() then return false end

    local base = self.BaseClass and self.BaseClass.CanPickupWeapon
    if not isfunction( base ) then return false end

    return base( self, wep, doingHolstered, myTbl, wepsTbl )

end

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

-- Y LA AUSENCIA ( Diseno 20 ① ), que arranca en TRUE al reves que los otros
-- tres. El motivo es que no es un rasgo de algunos tipos: en Phasmophobia el
-- fantasma fuera del hunt NO SE VE, y eso vale para los 30. El flag existe para
-- el que NO -- el Alternate de Mandela Catalogue ( docs/ALTERNATE.md ), cuyo
-- terror es justamente que se lo vea parado ahi.
--
-- ⚠ ES INVISIBILIDAD Y NADA MAS: el fantasma ausente SIGUE SIENDO SOLIDO. La
-- solidez tiene un dueno unico y es server_doors.lua. El motivo, con lineas del
-- codigo de la base, esta en el encabezado de server_cloak.lua y en Diseno
-- 20.1-20.2.
ENT.phantom_Absent = true

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

    -- LA AUSENCIA ( Diseno 20 ①, server_cloak.lua ) SE RECONCILIA ACA Y NO EN
    -- UNA TAREA, y el motivo esta medido: `RunTask( "BehaveUpdatePriority" )` y
    -- `RunTask( "Think" )` viven los dos adentro del coroutine de prioridad
    -- ( behaviouroverrides.lua:694-695 ), que NO corre mientras un jugador
    -- maneja al bot -- el propio autor de la base lo dice al lado del cloak del
    -- wraith ( wraithcloaking.lua:69 ). La primera rama de la politica es
    -- justamente "manejado por un jugador se ve siempre", asi que puesta ahi no
    -- se habria aplicado nunca y el sintoma seria un bot invisible imposible de
    -- pilotear, sin un solo error.
    --
    -- Va DESPUES del BaseClass por la misma razon que el facewalk: la base
    -- puede haber tocado el estado en su propio tick, y lo que queremos
    -- reconciliar es lo que quedo.
    --
    -- Con guarda -- el include podria fallar --, y la guarda del final de
    -- server_cloak.lua comprueba el otro sentido: que esta llamada exista.
    if myTbl.phantom_ReconcileVisibility then
        myTbl.phantom_ReconcileVisibility( self, myTbl )

    end

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
-- ⚠ UN EntIndex NO ES UNA IDENTIDAD ESTABLE, y eso dejo a medio medir una fila
-- de la ronda 15. GMod RECICLA los indices: la 04 leyo `#52 ... Obake` y
-- despues `#52 ... SIN TIPO`, y por la salida sola no se puede saber si el
-- fantasma perdio el tipo -- que seria un defecto grave -- o si es OTRO fantasma
-- que heredo el numero. Las dos cosas se ven exactamente igual.
--
-- El serial no se recicla nunca y la edad separa lo que un indice no puede.
-- Cuesta dos campos y convierte una lectura ambigua en una decidible.
PHANTASMAGORIA.SpawnSerial = PHANTASMAGORIA.SpawnSerial or 0

function ENT:AdditionalInitialize()
    PHANTASMAGORIA.SpawnSerial = PHANTASMAGORIA.SpawnSerial + 1

    self.phantom_Serial  = PHANTASMAGORIA.SpawnSerial
    self.phantom_BornAt  = CurTime()

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
        "  serie ", self.phantom_Serial,
        "  modelo ", tostring( self:GetModel() ),
        "  skin ", self:GetSkin(),
        "  pos ", tostring( self:GetPos() ),
        "  hunt ", self.phantom_Hunting and "SI" or "NO",
        -- El tipo en la linea de spawn y no solo en el comando: es el unico
        -- lugar donde queda registro de con que tipo NACIO cada fantasma, y el
        -- override lo puede cambiar despues sin dejar rastro de cual era.
        "  tipo ", tostring( self.phantom_TypeKey or "NINGUNO" ),
        "\n" )

    -- El hull se reporta cuando la base TERMINA de escribirlo, y quien avisa de
    -- eso es el enganche a SetupCollisionBounds que esta mas abajo en este mismo
    -- archivo. Aca no se puede: todavia no existe.

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

    -- ⚠ ESTA RAMA NOMBRABA A UN ESCRITOR SIN COMPROBAR SU PRECONDICION, y salio
    -- de una fila VERDE de la ronda 15. Decia "la escribe LA BASE ( shootAt
    -- sobre el enemigo )" con `enemigo ninguno` impreso DOS LINEAS MAS ARRIBA,
    -- en la misma pantalla, y el bot `quieto ( 0 u/s )`.
    --
    -- Las dos mitades son falsas ahi: `shootAt` pide `IsValid( GetEnemy )` -- sin
    -- enemigo la cadena de shooting_handler se sale antes ( shared.lua:3492-3506 )
    -- --, y el facewalk se sale por debajo de 30 u/s. O sea que con el bot
    -- frenado y sin enemigo NO HAY NINGUN ESCRITOR: el valor simplemente quedo
    -- del ultimo que corrio, y "cambio hace 0.8 s" es cuando el bot venia
    -- caminando y freno.
    --
    -- Es la MISMA familia de defecto que costo la ronda 12 -- una etiqueta que
    -- deduce quien escribio en vez de medirlo -- reaparecida en la rama de al
    -- lado. *Una etiqueta que nombra a un escritor tiene que preguntar por la
    -- precondicion de ESE escritor, aunque el dato este impreso al lado.*
    elseif quieta <= 1 and IsValid( ghost:GetEnemy() ) then
        quienPide = "la escribe LA BASE ( shootAt sobre el enemigo ), cambio hace " ..
            string.format( "%.1f", quieta ) .. " s"

    elseif quieta <= 1 then
        quienPide = "cambio hace " .. string.format( "%.1f", quieta ) ..
            " s y NO fue ninguno de los dos: sin enemigo la base no mira" ..
            ( ghost:GetCurrentSpeed() < FACEWALK_MIN_SPEED and " y el facewalk se sale por debajo de 30 u/s ( quedo del ultimo que corrio )" or "" )

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
    -- ⚠ ESTA ES PRESTADA A PROPOSITO desde el 2026-08-09. Nuestra `jump_land`
    -- portada deformaba al fantasma entero de forma persistente -- A/B en juego,
    -- una sola variable -- y se saco del QC; `ACT_LAND` la sirve ahora la de
    -- `m_anm`, que es una delta de Valve. El costo estaba pago: el terminator de
    -- fabrica no anima aterrizajes. Ver §20 de
    -- dev/HANDOFF_fantasma_rig_ragdoll_continuacion.md.
    { act = ACT_LAND,                nuestra = "jump_land",    cuando = "al aterrizar ( gesto )",
      prestada = true },
}

---------------------------------------------------------------------------
-- QUE DEVUELVE GetPoseParameter EN ESTE BUILD: MEDIDO, NO SUPUESTO
---------------------------------------------------------------------------
--[[
    ⚠ ESTA FUNCION EXISTE PORQUE LA SUPOSICION QUE REEMPLAZA FABRICO UN SINTOMA.

    El bloque de abajo afirmaba, en un comentario, que `GetPoseParameter`
    devuelve 0..1 normalizado, y convertia con `v * 2 - 1`. La r18 midio, con el
    bot corriendo DE FRENTE:

        pose  CRUDO  move_x +1.000   move_y +0.005   vel 196 u/s
        pose  -1..1  move_x +1.00    move_y -0.99    -> celda NW
        pose  ⚠ EL BOT SE MUEVE Y LA CELDA NO ES 'N' ... Es el sintoma de 'corre de lado'.

    El `move_y -0.99` sale de `0.005 * 2 - 1`. O sea que el aviso que "confirmaba"
    el reporte del autor lo produjo LA CONVERSION, sobre un crudo que ya decia
    move_y ~ 0 -- que es exactamente ir derecho. Y la misma corrida imprimio, en
    otra pasada, `move_x -0.999`: fuera de 0..1, imposible bajo la suposicion.

    *Un control que no puede equivocarse en voz alta no confirma un sintoma: lo
    fabrica.* Y este fabrico uno que YA TENIA un reporte del autor esperandolo,
    asi que corroboro una historia falsa durante dos rondas.

    Ahora no se supone: se SONDEA. Se escribe un valor conocido y se lee de
    vuelta. La sonda va al MINIMO del rango y no al maximo, porque con un rango
    -1..1 el maximo vale 1 en las dos convenciones ( crudo 1, normalizado 1 ) y
    no discrimina nada; el minimo vale -1 crudo y 0 normalizado.

    El sondeo pisa el parametro por menos de un tick y despues lo restaura --
    y mientras el bot se mueve el motor lo reescribe solo en el BodyUpdate
    siguiente ( BodyMoveXY, motion.lua:353 ).
]]
local function sondearPose( ent, nombre )
    local out = { nombre = nombre }

    local okId, id = pcall( ent.LookupPoseParameter, ent, nombre )
    if not okId or not isnumber( id ) or id < 0 then
        out.modo = "NO EXISTE"
        return out

    end
    out.id = id

    local okR, mini, maxi = pcall( ent.GetPoseParameterRange, ent, id )
    if not okR or not isnumber( mini ) or not isnumber( maxi ) or mini == maxi then
        out.modo = "SIN RANGO"
        return out

    end
    out.min, out.max = mini, maxi

    local okA, antes = pcall( ent.GetPoseParameter, ent, nombre )
    if not okA or not isnumber( antes ) then
        out.modo = "NO SE PUDO LEER"
        return out

    end
    out.antes = antes

    local okS = pcall( ent.SetPoseParameter, ent, nombre, mini )
    local okL, leido = pcall( ent.GetPoseParameter, ent, nombre )

    if not okS or not okL or not isnumber( leido ) then
        out.modo = "NO SE PUDO SONDEAR"
        return out

    end

    out.puesta, out.leida = mini, leido

    local pareceCrudo = math.abs( leido - mini ) < 0.01
    local pareceNorm  = math.abs( leido ) < 0.01

    if pareceCrudo and pareceNorm then
        -- Pasa si el minimo del rango ES cero. No es un empate para desempatar a
        -- ojo: las dos convenciones dan el mismo numero y la sonda no separa.
        out.modo = "AMBIGUO"

    elseif pareceCrudo then
        out.modo = "CRUDO"

    elseif pareceNorm then
        out.modo = "NORMALIZADO"

    else
        out.modo = "NINGUNA DE LAS DOS"

    end

    -- Restaurar EN LA CONVENCION QUE SE ACABA DE MEDIR. Con la lectura
    -- normalizada, `antes` no es un valor que SetPoseParameter entienda.
    if out.modo == "NORMALIZADO" then
        pcall( ent.SetPoseParameter, ent, nombre, mini + antes * ( maxi - mini ) )

    else
        pcall( ent.SetPoseParameter, ent, nombre, antes )

    end

    return out

end

--- El valor en -1..1 para ubicarlo en la grilla, o nil si el sondeo no alcanza.
--- La normalizacion usa el rango MEDIDO, no un -1..1 supuesto.
local function poseEnGrilla( s )
    if not s or not isnumber( s.antes ) or not isnumber( s.min ) then return nil end
    if s.modo ~= "CRUDO" and s.modo ~= "NORMALIZADO" and s.modo ~= "AMBIGUO" then return nil end

    local crudo = s.antes
    if s.modo == "NORMALIZADO" then crudo = s.min + s.antes * ( s.max - s.min ) end

    return ( crudo - s.min ) / ( s.max - s.min ) * 2 - 1, crudo

end

-- Grilla leida del .mdl: eje X = move_y, eje Y = move_x. N es ir de frente.
local CELDAS = {
    { "SW", "S", "SE" },
    { "W",  "C", "E"  },
    { "NW", "N", "NE" },
}

local function celda( tx, ty )
    local col = ty < -0.34 and 1 or ( ty > 0.34 and 3 or 2 )
    local fil = tx < -0.34 and 1 or ( tx > 0.34 and 3 or 2 )

    return CELDAS[ fil ][ col ]

end

--- El angulo entre dos direcciones 2D, en grados. nil si alguna es nula.
local function anguloEntre( ax, ay, bx, by )
    local la = math.sqrt( ax * ax + ay * ay )
    local lb = math.sqrt( bx * bx + by * by )
    if la < 0.05 or lb < 0.05 then return nil end

    local cos = ( ax * bx + ay * by ) / ( la * lb )

    return math.deg( math.acos( math.Clamp( cos, -1, 1 ) ) )

end

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

        -- ⚠ EL NOMBRE NO PRUEBA DE QUIEN ES LA SECUENCIA, y esto esta escrito
        -- porque el comando dijo `8/8 y es la nuestra` sobre una `jump_land` que
        -- ya no estaba en nuestro .mdl. La prestada se llama IGUAL a proposito
        -- --es justo lo que hace que el virtualmodel descarte la homonima-- asi
        -- que el nombre no discrimina. Y el CONTEO tampoco: al sacar la nuestra,
        -- la prestada deja de descartarse y `secuencias visibles` sigue dando
        -- 1725, el mismo numero. *Las dos mitades del criterio se quedaron ciegas
        -- al mismo tiempo, y el comentario de arriba decia que juntas alcanzaban.*
        --
        -- Lo que SI discrimina es el INDICE: el virtualmodel pone primero las
        -- locales del modelo dueno y despues las prestadas. `idle` es la ultima
        -- que declara nuestro QC, asi que todo indice mayor que el suyo es
        -- prestado.
        --
        -- ⚠ Y ESE SUPUESTO SE COMPRUEBA, no se cree: las siete filas que sabemos
        -- nuestras tienen que caer por debajo de la frontera. Si alguna no cae,
        -- hay dos causas posibles --el dedup fallo, o la frontera envejecio
        -- porque el QC cambio de orden-- y este comando NO puede separarlas: lo
        -- dice y no reparte etiquetas.
        -- El metodo se comprueba antes de llamarlo: si no existe, la columna del
        -- dueno dice `?` y el veredicto sale PARCIAL. Reventar aca dejaria sin
        -- imprimir tambien el conteo, que si se pudo medir.
        local frontera = isfunction( ghost.LookupSequence ) and ghost:LookupSequence( "idle" ) or nil
        local hayFrontera = frontera ~= nil and frontera >= 0

        local function deQuien( idx )
            if not hayFrontera or not idx or idx < 0 then return "?" end
            return idx <= frontera and "nuestra" or "PRESTADA"

        end

        local malas, prestadas, sorpresas = 0, 0, 0

        for _, fila in ipairs( ACTS_QUE_PIDE_LA_BASE ) do
            local cands = porAct[ fila.act ] or {}
            local idx = ghost:SelectWeightedSequence( fila.act )
            local elegida = ghost:GetSequenceName( idx )
            local duena = deQuien( idx )

            -- El veredicto es el CONTEO y el DUENO juntos. El nombre se imprime
            -- pero YA NO VOTA: un conteo de 1 sobre la secuencia equivocada seria
            -- un modelo que responde siempre igual y siempre mal, un conteo de 2
            -- es la moneda, y un nombre correcto no dice de quien es.
            local ok
            if fila.prestada then
                -- A proposito no la declaramos: alcanza con que resuelva a UNA, y
                -- si resolviera a una NUESTRA seria que el QC volvio a emitirla.
                ok = #cands == 1 and duena ~= "nuestra"

            else
                ok = #cands == 1 and cands[ 1 ] == fila.nuestra and duena ~= "PRESTADA"
                if duena == "PRESTADA" then sorpresas = sorpresas + 1 end

            end
            if not ok then malas = malas + 1 end
            if duena == "PRESTADA" then prestadas = prestadas + 1 end

            -- TRES marcas y no dos: si el conteo esta bien pero el dueno no se
            -- pudo leer, la fila no es OK ni !!, es `??`. Poner OK ahi seria
            -- contar como aprobado justo lo que no se midio.
            local marca
            if #cands ~= 1 then marca = "!!  "
            elseif duena == "?" then marca = "??  "
            elseif ok then marca = "OK  "
            else marca = "!!  " end

            say( "    " .. marca .. string.format( "%-22s", fila.nuestra ) ..
                #cands .. " secuencia" .. ( #cands == 1 and "" or "s" ) ..
                "   elige: " .. tostring( elegida ) .. " #" .. tostring( idx ) ..
                " [" .. duena .. "]" ..
                ( fila.prestada and " <- prestada A PROPOSITO" or "" ) ..
                "   ( " .. fila.cuando .. " )" )

            if #cands ~= 1 then
                say( "         compiten: " .. table.concat( cands, ", " ) )

            end
        end

        if not hayFrontera then
            say( "         !! la frontera no se pudo leer: este modelo no declara una " ..
                "secuencia `idle`, asi que la columna [nuestra/PRESTADA] dice `?` y de " ..
                "quien es cada una NO se midio." )

        elseif sorpresas > 0 then
            say( "         !! " .. sorpresas .. " fila(s) que esperabamos NUESTRAS " ..
                "resolvieron por encima de la frontera ( indice > " .. frontera .. " ). " ..
                "O el descarte por nombre no ocurrio, O el QC cambio de orden y `idle` " ..
                "ya no es la ultima local: este comando no distingue las dos." )

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
        -- ⚠ LO QUE DEVUELVE GetPoseParameter SE SONDEA, NO SE SUPONE, y la
        -- version que lo suponia fabricaba el sintoma que buscaba. Ver
        -- `sondearPose`.
        --
        -- ⚠ Y LO ESPERADO SE MIDE TAMBIEN. La version vieja exigia la celda `N`
        -- con el bot en movimiento, o sea daba por sentado que el bot camina
        -- hacia donde mira. Eso es cierto con `facewalk` puesto y falso en
        -- cuanto la base decide retroceder ( movement_backthehellup ) -- y
        -- entonces la fila reprobaria una mezcla CORRECTA. Ahora lo esperado
        -- sale del vector de velocidad contra la orientacion del bot, y el
        -- veredicto compara dos mediciones en vez de una medicion contra una
        -- creencia.
        local sx, sy = sondearPose( ghost, "move_x" ), sondearPose( ghost, "move_y" )
        local tx, cx = poseEnGrilla( sx )
        local ty, cy = poseEnGrilla( sy )

        for _, s in ipairs( { sx, sy } ) do
            if s.modo == "CRUDO" or s.modo == "NORMALIZADO" or s.modo == "AMBIGUO" then
                say( string.format(
                    "    pose  param %-6s id %d  rango %+.2f .. %+.2f   sonda: puse %+.2f y " ..
                    "lei %+.2f  -> LECTURA %s",
                    s.nombre, s.id, s.min, s.max, s.puesta, s.leida, s.modo ) )

            else
                say( "    pose  param " .. s.nombre .. "  -> " .. s.modo ..
                    "  ( sin esto no hay medicion de la mezcla, y el numero de abajo no sale )" )

            end
        end

        if tx and ty then
            local vel = ghost.loco and ghost.loco:GetVelocity() or ghost:GetVelocity()
            local rapidez = vel and vel:Length2D() or 0
            local ang = ghost:GetAngles()
            local adelante = rapidez > 1 and vel:Dot( ang:Forward() ) / rapidez or 0
            local derecha  = rapidez > 1 and vel:Dot( ang:Right() ) / rapidez or 0

            say( string.format( "    pose  MEDIDO  move_x %+.2f  move_y %+.2f   -> celda %s" ..
                "   ( crudo %+.3f / %+.3f )", tx, ty, celda( tx, ty ), cx, cy ) )
            say( string.format( "    pose  MARCHA  vel %d u/s   adelante %+.2f  derecha %+.2f" ..
                "   -> celda %s si move_y es 'derecha', %s si es 'izquierda'",
                math.Round( rapidez ), adelante, derecha,
                celda( adelante, derecha ), celda( adelante, -derecha ) ) )

            -- ⚠ EL VEREDICTO NECESITA QUE EL BOT SE ESTE MOVIENDO, y no porque
            -- sea mas comodo: `BodyMoveXY` se llama SOLO dentro de
            -- `if self:IsMoving()` ( motion.lua:351 ), asi que con el bot quieto
            -- estos dos parametros son los del ULTIMO movimiento y no describen
            -- nada de ahora. La r18 leyo `move_x +0.999` con `vel 0 u/s` dos
            -- veces y las dos lineas parecian datos.
            if rapidez <= 50 then
                say( "    pose  >> SIN CORRER: el bot esta quieto ( " .. math.Round( rapidez ) ..
                    " u/s ). BodyMoveXY solo escribe estos parametros MIENTRAS se mueve, " ..
                    "asi que esto es el ultimo movimiento, no el estado actual." )

            else
                local aDer = anguloEntre( tx, ty, adelante, derecha )
                local aIzq = anguloEntre( tx, ty, adelante, -derecha )
                local mejor = math.min( aDer or 999, aIzq or 999 )

                if not aDer or not aIzq then
                    say( "    pose  >> SIN CORRER: uno de los dos vectores es nulo y el angulo " ..
                        "no esta definido." )

                elseif mejor < 25 then
                    say( string.format( "    pose  >> CONCUERDAN: %.1f grados entre la mezcla y " ..
                        "la marcha ( convencion move_y = %s ). La mezcla reproduce el paso que " ..
                        "el bot esta dando.", mejor, aDer <= aIzq and "derecha" or "izquierda" ) )

                else
                    say( string.format( "    pose  >> ⚠ NO CONCUERDAN: %.1f grados con move_y = " ..
                        "derecha y %.1f con move_y = izquierda. La mezcla esta en %s y la marcha " ..
                        "va a %s: ESTE es 'corre de lado', y ahora es un numero que no depende " ..
                        "de que el bot camine hacia donde mira.",
                        aDer, aIzq, celda( tx, ty ), celda( adelante, derecha ) ) )

                end
            end

        elseif sx.modo == "NO EXISTE" or sy.modo == "NO EXISTE" then
            -- Un ausente se DICE. Si el modelo no declara move_x/move_y, la
            -- mezcla no se puede mover y siempre se ve el centro -- que es un
            -- defecto real y no la ausencia de un dato de debug.
            say( "    pose  >> move_x/move_y NO EXISTEN en este modelo: la mezcla queda " ..
                "clavada en el centro y el fantasma camina siempre igual." )

        else
            -- El tercer estado: los parametros existen y la lectura no se pudo
            -- caracterizar. No es "esta bien" ni "esta mal": es que este comando
            -- no midio, y la fila que dependa de esto va SIN CORRER.
            say( "    pose  >> SIN CORRER: los parametros existen pero el sondeo no pudo " ..
                "caracterizar la lectura ( " .. sx.modo .. " / " .. sy.modo .. " ). " ..
                "Sin eso, cualquier celda que imprimiera seria una suposicion con formato." )

        end

        local n = #ACTS_QUE_PIDE_LA_BASE

        if not hayFrontera then
            -- Ni PASA ni FALLA: la mitad del criterio no se pudo medir. Un
            -- veredicto que se emite igual convierte lo que no midio en aprobado.
            say( "    >> PARCIAL: " .. ( n - malas ) .. "/" .. n .. " con UNA sola secuencia, " ..
                "pero de QUIEN es cada una este comando NO lo midio ( sin frontera )." )

        elseif malas == 0 then
            say( "    >> PASA: " .. n .. "/" .. n .. " actividades con UNA sola secuencia -- " ..
                ( n - prestadas ) .. " nuestras y " .. prestadas ..
                " prestada(s) a proposito ( frontera: nuestras hasta el #" .. frontera .. " )." )

        else
            say( "    >> FALLA: " .. malas .. " de " .. n .. " actividades no resuelven como " ..
                "corresponde. Con 2 candidatas el estiramiento sale una vez de cada dos." )

        end
    end
end, "Cuenta cuantas secuencias responden a cada actividad que la base le pide al fantasma. " ..
    "Mide si el $includemodel descarto las prestadas de m_anm: tiene que dar 1 por actividad." )

---------------------------------------------------------------------------
-- Instrumento: LA POSE T -- que actividad se pidio, y si salio algo
---------------------------------------------------------------------------
-- Pedido textual del autor: "si hay algun cvar que calcule eso de la animacion
-- para que sepas cual es seria bueno". Reporto la pose T dos veces, las dos
-- tirando al fantasma con el physgun.
--
-- UNA POSE T ES LA POSE DE REFERENCIA: el modelo dibujado con su esqueleto de
-- reposo, o sea SIN ANIMACION. Asi que lo que hay que encontrar es una actividad
-- que la base pide y que no resuelve a ninguna secuencia -- ni nuestra ni
-- prestada de m_anm. No esta identificada y esto NO la adivina: la registra.
--
-- El anillo, la resolucion de nombres y el formato viven en
-- lua/phantasmagoria/actlog.lua, que el arnes SI puede cargar. Aca quedan las
-- envolturas, que son lo unico que necesita el motor.
--
-- ⚠ SON SEIS PUNTOS DE ENTRADA Y HAY QUE TENER LOS SEIS, porque no todos pasan
-- por el mismo lado y el que falte es justo el que no se va a ver:
--
--   TranslateActivity   la traduccion ACT_MP_* -> ACT_HL2MP_*
--   StartActivity       lo que de verdad cambia la secuencia del cuerpo
--   DoGesture/DoPosture los de la base ( ACT_LAND entra por aca, :3456 )
--   AddGesture          ⚠ NATIVO Y DIRECTO: HandleFlinching lo llama sin pasar
--                       por DoGesture ( damageandhealth.lua:634 ). Envolver solo
--                       DoGesture dejaria los ocho flinch fuera del instrumento,
--                       que es el modo de falla que la ronda 16 ya pago: un
--                       instrumento que mide donde el sujeto no pasa.
--   AddGestureSequence  el mismo camino cuando el gesto viene por nombre
local cvActLog = CreateConVar( "phantasmagoria_ghost_actlog", "0", FCVAR_ARCHIVE,
    "Anota que actividad se le pide al modelo y si resolvio a una secuencia. " ..
    "Sirve para identificar la POSE T: la actividad que no resuelve es la que falta. " ..
    "Se lee en cada llamada, asi que se puede prender y apagar con el bot vivo. " ..
    "Ver con phantasmagoria_ghost_actlog_dump.", 0, 1 )

-- Lo ultimo que se anoto por cada punto, para no escribir 66 eventos por segundo.
-- TranslateActivity corre en CADA BodyUpdate; sin este filtro el anillo de 64 se
-- llena en un segundo y el evento de la pose T se cae por el borde antes de que
-- el autor suelte el physgun.
--
-- ⚠ Y GUARDA EL INSTANTE, NO SOLO LA HUELLA. Ver `VENTANA_REPETIDO`.
local ultimoPorPunto = {}

--[[
    CADA CUANTO SE VUELVE A ANOTAR UN EVENTO IDENTICO.

    ⚠ ESTE NUMERO NO ESTABA Y LA r18 LO PAGO. El filtro era "distinto del
    anterior de su mismo punto", sin tiempo: un episodio que se repite igual --
    el autor levantando el fantasma con el physgun y soltandolo CUATRO VECES
    seguidas -- se anotaba UNA sola vez, la primera, y esa se cayo por el borde
    del anillo antes del dump. Las cuatro caidas quedaron representadas por cero
    eventos de `Gesture`, y el dump se leyo como que el gesto de aterrizaje no
    se pidio nunca.

    *Un filtro de repetidos sin ventana de tiempo no comprime un episodio: lo
    borra, y borra justo el que se repite -- que es el que uno estaba
    reproduciendo a proposito.*

    0.75 s deja el anillo en ~1,3 eventos por segundo y por punto en el peor
    caso ( TranslateActivity corre en cada BodyUpdate ), y no pierde ninguna
    repeticion que un humano pueda provocar a mano.
]]
local VENTANA_REPETIDO = 0.75

local function estadoAhora( self )
    local partes = {}

    -- Todo por pcall: son metodos de la base y de la metatabla de NextBot, y un
    -- instrumento que revienta al bot para poder describirlo no sirve. Un dato
    -- que no se pudo leer se omite; no se inventa un cero.
    local ok, aire = pcall( self.IsOnGround, self )
    if ok then partes[ #partes + 1 ] = aire and "en el piso" or "EN EL AIRE" end

    if self.m_Jumping then partes[ #partes + 1 ] = "saltando" end
    if self.m_Physguned then partes[ #partes + 1 ] = "PHYSGUN" end

    local okV, vel = pcall( self.GetCurrentSpeed, self )
    if okV and isnumber( vel ) then
        partes[ #partes + 1 ] = math.Round( vel ) .. " u/s"

    end

    -- ⚠ EL ARMA VA EN LA LINEA, Y EN LA r18 HABIA QUE DEDUCIRLA DEL SUFIJO.
    -- Que el bot tuviera un arma en la mano se leia del `_AR2` al final de la
    -- actividad traducida -- o sea del EFECTO que la fila estaba tratando de
    -- medir. Con eso, una ventana sin traducciones de arma es indistinguible de
    -- una ventana sin arma, que es exactamente la ambiguedad que dejo a la fila
    -- 03 medio medida. La causa se anota aparte del efecto.
    local okW, wep = pcall( self.GetActiveWeapon, self )
    local arma = ( okW and IsValid( wep ) ) and wep:GetClass() or nil

    partes[ #partes + 1 ] = arma and ( "ARMA " .. arma ) or "sin arma"

    return table.concat( partes, " " ), arma

end

--- Anota, si el log esta prendido y si el evento es distinto del anterior de su
--- mismo punto. Devuelve el evento o nil.
local function anotar( self, punto, ev )
    if not cvActLog:GetBool() then return end
    if not PHANTASMAGORIA.PushActLog then return end

    -- ⚠ LA HUELLA INCLUYE `resolvio`. Si el filtro mirara solo la actividad, el
    -- primer evento que NO resuelve quedaria tapado por el anterior que SI
    -- resolvio la misma -- que es exactamente el instante que se esta buscando.
    local huella = tostring( ev.pedida ) .. "|" .. tostring( ev.salida ) ..
        "|" .. tostring( ev.seq ) .. "|" .. tostring( ev.resolvio )

    local ahora = CurTime()
    local visto = ultimoPorPunto[ punto ]

    -- ⚠ `forzar` SALTEA EL FILTRO, y esta puesto donde el filtro estorba: el
    -- muestreo de la caida emite dos eventos por aterrizaje cuya huella es
    -- identica a proposito ( misma actividad, mismo estado ), y el filtro los
    -- comeria justo cuando el autor esta reproduciendo el sintoma a mano. Es una
    -- excepcion NOMBRADA en el evento y no una regla implicita en el filtro.
    if not ev.forzar
        and visto and visto.huella == huella and ( ahora - visto.t ) < VENTANA_REPETIDO then
        return

    end

    ultimoPorPunto[ punto ] = { huella = huella, t = ahora }

    ev.punto = punto
    ev.t = ahora
    ev.estado, ev.arma = estadoAhora( self )

    return PHANTASMAGORIA.PushActLog( ev )

end

--[[
    Que secuencia elige el modelo para una actividad, y si eligio alguna.

    ⚠ ESTA FUNCION SE COMIO EL RESULTADO DEL BLOQUE EN LA r17. El dump trajo

        3117.13  Translate  ACT_LAND (33)  -> ACT_INVALID (-1)
        3117.13  Gesture    ACT_INVALID (-1)          <- sin seq y SIN MARCA

    o sea LA POSE T, impresa, y el veredicto de abajo dijo «ninguna actividad
    quedo SIN RESOLVER en esta ventana». La causa: con `act = -1`,
    `SelectWeightedSequence` TIRA ERROR en vez de devolver -1, el `pcall` lo
    atrapaba y la funcion devolvia `nil, nil, nil` -- o sea `resolvio = nil`, que
    no es `false`, que es lo unico que la linea marca.

    *Un instrumento que no distingue «no resolvio» de «no pude preguntar»
    convierte su propio error en un verde.* Y el veredicto lo empeoraba contando
    los sin-dato como resueltos, que es exactamente el defecto que este mismo
    bloque le corrigio a `actmiss` dos dias antes, en otra funcion.

    Ahora hay TRES salidas y las tres se dicen:
      resolvio = true   hay secuencia
      resolvio = false  NO hay -- y una actividad < 0 es invalida POR DEFINICION,
                        sin preguntarle al modelo
      resolvio = nil    no se pudo preguntar, y el dump lo cuenta aparte
]]
local function resolver( self, act )
    if not isnumber( act ) then return nil, "no es un numero", nil end

    -- ⚠ ACT_INVALID ( -1 ) Y CUALQUIER NEGATIVO SE CONTESTAN ACA, sin tocar el
    -- modelo. No es un atajo de rendimiento: es que preguntarle al modelo por
    -- una actividad invalida ERROREA, y ese error se leia como ausencia de dato.
    -- Una actividad negativa no tiene secuencia por definicion, y eso es
    -- precisamente una pose de referencia.
    if act < 0 then return -1, "ACTIVIDAD INVALIDA", false end

    local ok, seq = pcall( self.SelectWeightedSequence, self, act )
    if not ok or not isnumber( seq ) then return nil, "no se pudo preguntar", nil end

    local nombre = seq >= 0 and tostring( self:GetSequenceName( seq ) ) or "NINGUNA"

    return seq, nombre, seq >= 0

end

---------------------------------------------------------------------------
-- Las envolturas
---------------------------------------------------------------------------
-- ⚠ NINGUNA DE ESTAS SE INSTALA SI NO SE ENCUENTRA LA ORIGINAL. Un instrumento
-- que tapa un metodo de la base y no lo puede llamar de vuelta no mide al
-- fantasma: lo rompe -- y romperlo se leeria como un defecto del modelo.
--
-- Los dos nativos se resuelven ACA ARRIBA y como LOCALES. Estaban abajo y como
-- globales: en Lua eso "anda" -- una global se resuelve al llamar, no al
-- definir -- pero deja dos nombres sueltos en _G que cualquier addon puede
-- pisar, y en un archivo de 2000 lineas el lector no tiene como saber que la
-- linea de arriba depende de una asignacion que esta cien lineas mas abajo.
local metaEnt     = FindMetaTable( "Entity" )
local metaNextBot = FindMetaTable( "NextBot" )

local origStartActivity = metaNextBot and metaNextBot.StartActivity
local origAddGesture    = metaEnt and metaEnt.AddGesture

-- ⚠ TranslateActivity DEVUELVE DOS VALORES y el segundo decide. La base hace
--     local jumpStartAct, isAnim = self:TranslateActivity( ACT_MP_JUMP_START )
--     if not isAnim then return end
-- ( motionoverrides.lua:3011-3013 ). El `false` sale del camino de fallback y es
-- lo que impide que se toque un gesto que no existe. Una envoltura que devuelve
-- solo el primer valor convierte ese `false` en nil... que tambien es falsy, asi
-- que ESA no rompe -- pero al reves si: cualquier envoltura de las de abajo que
-- se coma un valor de retorno cambia el comportamiento del bot en silencio. Por
-- eso todas devuelven con `return orig( ... )` o guardan en tabla y desempaquetan.
function ENT:TranslateActivity( act )
    local base = self.BaseClass and self.BaseClass.TranslateActivity

    if not isfunction( base ) then
        -- Sin base no hay nada que envolver y tampoco hay que inventar: se
        -- devuelve la actividad tal cual, que es lo que hace un modelo sin
        -- traduccion, y se avisa UNA vez.
        if not self.phantom_avisoTranslate then
            self.phantom_avisoTranslate = true
            ghostPrint( "TranslateActivity de la base NO ENCONTRADA: el instrumento de " ..
                "actividades queda ciego en ese punto y la traduccion no se aplica.\n" )

        end

        return act

    end

    local salida, encontrada = base( self, act )

    -- ⚠ UNA TRADUCCION QUE DEVUELVE UNA ACTIVIDAD INVALIDA ES EL EVENTO RAIZ, y
    -- hay que marcarla ACA. En la r17 el dump trajo
    --     Translate  ACT_LAND (33)  -> ACT_INVALID (-1)
    -- y la linea sali&oacute; sin marca porque este bloque ponia `resolvio = nil`
    -- fijo: la traduccion "no elige secuencia", asi que no parecia haber nada que
    -- marcar. Pero devolver -1 SI es el defecto -- lo que sigue es un
    -- DoGesture( -1 ), que es la pose de referencia.
    --
    -- De donde sale ese -1: la base le pregunta AL ARMA antes que a nuestra tabla
    -- ( motionoverrides.lua:3694-3710 ), y `luaWep:TranslateActivity( ACT_LAND )`
    -- devuelve -1 porque un arma no sabe traducir un aterrizaje. Como -1 es
    -- truthy en Lua, el `if newact then return newact end` de la base lo deja
    -- pasar tal cual.
    local salidaMala = isnumber( salida ) and salida < 0 or nil

    -- ⚠ GUARDA EN PROFUNDIDAD: una actividad NEGATIVA no sale de aca.
    -- `phantasmagoria_ghost_pickup 0` corta la causa conocida ( el arma ), pero
    -- el `if newact then return newact end` de la base deja pasar cualquier cosa
    -- truthy que devuelva un tercero -- otro addon que le ponga un arma, un SWEP
    -- con su propia traduccion. Si la salida es invalida, se usa NUESTRA tabla,
    -- que para eso esta.
    --
    -- Se anota igual ANTES de corregir, porque el evento es el dato: si esta
    -- linea empieza a aparecer con la convar en 0, el -1 viene de otro lado y eso
    -- hay que saberlo. *Un arreglo que tapa el sintoma sin dejar rastro se lleva
    -- puesta la unica evidencia de que el problema sigue.*
    --[[
        ⚠ SE LEE DE `self`, NO DE `ENT`, Y ESA LINEA CRASHEABA. La r19 la
        provoco por primera vez:

            server.lua:1872: attempt to index global 'ENT' (a nil value)
              1. TranslateActivity - server.lua:1872
              2. base - motionoverrides.lua:3456        <- el DoGesture( ACT_LAND )
              3. unknown - server.lua:2162              <- OnLandOnGround

        `ENT` es un global que existe MIENTRAS EL ARCHIVO SE CARGA; despues del
        `scripted_ents.Register` no esta. Todo lo que este archivo escribe en
        `ENT` durante la carga se lee en runtime por `self`, que lo encuentra por
        la cadena de metatablas -- y ademas respeta a quien lo haya sobreescrito.

        Y esto es peor que un crash cualquiera: la linea ES la guarda en
        profundidad que la r17 puso para que un -1 no saliera de aca. O sea que
        **la guarda estuvo rota desde que se escribio y nunca corrio**, porque el
        unico camino que la alcanza -- un arma devolviendo -1 en un aterrizaje --
        no se provoco hasta la r19. Cuando por fin se provoco, en vez de corregir
        el -1 tiro un error de Lua ADENTRO de `OnLandOnGround`, que se lleva
        puesto el resto del aterrizaje de la base.

        *Una guarda que solo se ejecuta en el caso que nunca pasa es codigo sin
        estrenar, y el dia que estrena falla.*

        El arnes no podia verlo: define `ENT` como global y lo deja puesto para
        siempre, asi que ahi la linea anda. Arreglado tambien alla -- el global se
        pone en nil despues de la carga, como en GMod.
    ]]
    if salidaMala and esNuestroModelo then
        local tabla = self.IdleActivityTranslations
        local nuestra = istable( tabla ) and tabla[ act ] or nil

        anotar( self, "Translate", {
            pedida = act,
            salida = salida,
            seq = nil,
            resolvio = false,
            seqName = nuestra and "corregida a nuestra tabla" or "y NUESTRA tabla tampoco la tiene",
        } )

        --[[
            ⚠ UN SOLO VALOR, Y EL `, true` QUE ESTABA ACA CRASHEABA LA BASE.

            La r20 lo provoco, una linea despues de arreglar el crash anterior:

                motion.lua:315: bad argument #2 to 'SetLayerPlaybackRate'
                                ( number expected, got boolean )
                  2. SetupGesturePosture - motion.lua:315
                  3. BehaveUpdate - behaviouroverrides.lua:118

            Porque el sitio de llamada es

                self:DoGesture( self:TranslateActivity( ACT_LAND ) )   ( :3456 )

            y `DoGesture( act, speed, wait )` recibe **los dos valores de retorno
            desparramados en su lista de argumentos**. O sea que el segundo valor
            de esta funcion no es "un booleano de encontre": ES EL `speed` DE
            DoGesture. La base hace `{ act, speed or 1, wait }`, y `true or 1` da
            `true`, que llega a `SetLayerPlaybackRate` como booleano.

            La base nunca devuelve `true`: devuelve UN valor cuando encontro
            traduccion ( `return translated` ) y `( activity, false )` en su
            fallback -- y `false or 1` si da 1. Devolver `true` estaba fuera del
            contrato.

            *Yo tenia escrito, dos rondas antes y en este mismo archivo, que «el
            segundo valor decide» -- razonando sobre el `if not isAnim then
            return end` de `:3011`. El mismo valor tiene DOS sitios de llamada con
            dos significados, y el que no mire es el que rompe.* Un valor de
            retorno no tiene un tipo: tiene un tipo POR SITIO DE LLAMADA.
        ]]
        if nuestra then return nuestra end

        -- Sin traduccion nuestra, se devuelve la idle: es lo que hace la base en
        -- su propio fallback, y es infinitamente mejor que un -1.
        --
        -- ⚠ `self.IdleActivity` y no `ENT.IdleActivity`, por lo de arriba. Y con
        -- un ultimo respaldo literal: si ni la instancia lo tiene, devolver el -1
        -- seria dejar pasar exactamente lo que esta rama existe para cortar.
        local idle = self.IdleActivity
        if isfunction( idle ) then idle = idle( self ) end

        -- El `false` si es del contrato ( es lo que devuelve el fallback de la
        -- base ) y ademas es lo que corta el DoGesture de `:3011`.
        return isnumber( idle ) and idle or ACT_HL2MP_IDLE, false

    end

    anotar( self, "Translate", {
        pedida = act,
        salida = salida,
        -- `encontrada == false` es el fallback de la base: NO habia traduccion y
        -- devolvio la idle. Eso NO es un defecto y por eso no se marca.
        seq = nil,
        resolvio = salidaMala and false or nil,
        cayoAlFallback = ( encontrada == false ) or nil,
    } )

    --[[
        ⚠ Y EL SEGUNDO VALOR SE SANEA ANTES DE PASARLO, aunque venga de la base.

        En `motionoverrides.lua:3456` el segundo valor de retorno cae como `speed`
        de `DoGesture`, y de ahi a `SetLayerPlaybackRate`, que exige un numero.
        Hoy la base solo devuelve `nil` o `false` ahi, asi que reenviarla tal cual
        anda. Pero *hoy* es una medicion sobre la version que tengo montada, y el
        precio de que un dia devuelva otra cosa es un error de Lua adentro de
        `BehaveUpdate` -- que es lo que acaba de pasar por mi propio `true`.

        Un numero SI se reenvia: seria un `speed` legitimo y comerselo cambiaria
        la velocidad del gesto en silencio.
    ]]
    if encontrada ~= nil and encontrada ~= false and not isnumber( encontrada ) then
        if not self.phantom_avisoSegundoValor then
            self.phantom_avisoSegundoValor = true
            ghostPrint( "TranslateActivity de la base devolvio " .. type( encontrada ) ..
                " como segundo valor. Ese valor cae como `speed` de DoGesture y ahi tiene " ..
                "que ser un numero: se lo reemplaza por false para no romper " ..
                "SetLayerPlaybackRate.\n" )

        end

        return salida, false

    end

    return salida, encontrada

end

function ENT:StartActivity( act )
    local seq, nombre, resolvio = resolver( self, act )

    anotar( self, "Start", {
        pedida = act,
        seq = seq,
        seqName = nombre,
        resolvio = resolvio,
    } )

    return origStartActivity( self, act )

end

function ENT:DoGesture( act, speed, wait )
    -- Un gesto puede venir por NOMBRE de secuencia ( isstring ), y en ese caso
    -- no hay actividad que resolver: se anota el nombre y se dice que el camino
    -- fue otro. Tratarlo como numero daria "ACT desconocida (nil)".
    if isstring( act ) then
        local seq = self:LookupSequence( act )

        anotar( self, "Gesture", {
            pedida = -1,
            seq = seq,
            seqName = act,
            resolvio = isnumber( seq ) and seq >= 0 or false,
        } )

    else
        local seq, nombre, resolvio = resolver( self, act )

        anotar( self, "Gesture", {
            pedida = act,
            seq = seq,
            seqName = nombre,
            resolvio = resolvio,
        } )

    end

    -- La guarda del BaseClass, igual que en TranslateActivity y por el mismo
    -- motivo: sin ella, un rename en la base convierte al instrumento en la
    -- causa de que el fantasma no haga gestos nunca.
    local base = self.BaseClass and self.BaseClass.DoGesture
    if not isfunction( base ) then return end

    return base( self, act, speed, wait )

end

function ENT:DoPosture( act, issequence, speed, noautokill )
    if not issequence then
        local seq, nombre, resolvio = resolver( self, act )

        anotar( self, "Posture", {
            pedida = act,
            seq = seq,
            seqName = nombre,
            resolvio = resolvio,
        } )

    end

    local base = self.BaseClass and self.BaseClass.DoPosture
    if not isfunction( base ) then return end

    return base( self, act, issequence, speed, noautokill )

end

-- ⚠ EL NATIVO, Y ES EL QUE MAS IMPORTA. HandleFlinching lo llama DIRECTO con un
-- ACT_FLINCH_* ( damageandhealth.lua:634 ) sin comprobar que exista, y cinco de
-- los ocho grupos de impacto piden una actividad que NO TIENE SECUENCIA ni en
-- m_anm ni en nuestro modelo ( medido con mdlacts.py, ver actlog.lua ).
function ENT:AddGesture( act, autokill )
    local seq, nombre, resolvio = resolver( self, act )

    anotar( self, "AddGest", {
        pedida = act,
        seq = seq,
        seqName = nombre,
        resolvio = resolvio,
    } )

    return origAddGesture( self, act, autokill )

end

-- Si el original no esta, la envoltura se DESINSTALA. Es preferible un
-- instrumento ausente y ruidoso a un bot que no puede empezar una actividad.
do
    if not isfunction( origStartActivity ) then
        ENT.StartActivity = nil
        ghostPrint( "NextBot:StartActivity no se pudo encontrar en la metatabla: la envoltura " ..
            "NO se instala y el actlog no va a ver los cambios de actividad del cuerpo. " ..
            "El bot funciona igual.\n" )

    end

    if not isfunction( origAddGesture ) then
        ENT.AddGesture = nil
        ghostPrint( "Entity:AddGesture no se pudo encontrar en la metatabla: la envoltura NO se " ..
            "instala y el actlog no va a ver los FLINCH, que son los que entran por ahi. " ..
            "El bot funciona igual.\n" )

    end
end

---------------------------------------------------------------------------
-- EL ATERRIZAJE, MUESTREADO -- porque el instante no se puede tipear
---------------------------------------------------------------------------
--[[
    ⚠ LO QUE FALTABA NO ERA UN DATO MAS: ERA EL INSTANTE.

    Las seis envolturas de arriba anotan cuando ALGO PIDE una actividad. La pose T
    del physgun no es una peticion: es lo que se DIBUJA en el medio segundo
    siguiente a la caida, y en ese medio segundo el autor tiene las dos manos en
    el physgun. La r18 lo dijo con todas las letras -- «la posicion T ocurre
    cuando tomo al ghost con el physgun y lo suelto a cierta altura» -- y el dump
    de esa misma corrida, con las cuatro caidas adentro, no tenia una sola linea
    que describiera el estado del CUERPO despues de ninguna de ellas.

    Esto engancha `OnLandOnGround` y muestrea 1,2 s a 0,05 s: que secuencia esta
    puesta, si el ciclo AVANZA, y a que velocidad se reproduce.

    LO QUE DISCRIMINA. Una pose de referencia es "no hay animacion", y eso tiene
    dos formas medibles y distintas:

      secuencia INVALIDA   GetSequence() < 0, o su nombre vacio -> no hay nada
                           que reproducir, y lo que se dibuja es el esqueleto de
                           reposo. Se marca `resolvio = false`.
      ciclo CONGELADO      la secuencia existe pero el ciclo no se mueve entre
                           muestras con playback > 0: la animacion esta puesta y
                           no corre.

    Los dos se ven igual en la pantalla y se arreglan en lugares distintos, que
    es el motivo de separarlos aca en vez de en la lectura del dump.

    ⚠ Y ESTO ES EL SERVIDOR. Si las muestras salen todas sanas y el autor igual
    vio la T, el defecto esta del lado del CLIENTE -- que es donde el modelo se
    dibuja -- y ahi mide `ph_ghost_land`. Este arco ya pago una vez el creer que
    medir en un realm dice algo del otro.
]]
local cvLandWatch = CreateConVar( "phantasmagoria_ghost_landwatch", "0", FCVAR_ARCHIVE,
    "Muestrea el cuerpo del fantasma durante 1,2 s DESPUES de cada aterrizaje y lo anota en el " ..
    "anillo del actlog. Es el instante de la pose T del physgun, que no se puede tipear. " ..
    "Necesita phantasmagoria_ghost_actlog 1 para que el anillo guarde.", 0, 1 )

local MUESTRAS_CAIDA, PASO_CAIDA = 24, 0.05

--[[
    ⚠ 24 MUESTRAS NO SON 24 EVENTOS, Y ESA CUENTA IMPORTA. El anillo guarda 64;
    cuatro caidas a 24 muestras serian 96 y se llevarian puestos exactamente los
    eventos de actividad que hay que leer al lado. Asi que el muestreo es fino y
    el REGISTRO es grueso: se anota la PRIMERA muestra que ve la pose de
    referencia -- que es el instante, con hora -- y un resumen al cerrar la
    ventana. Dos eventos por caida.

    *Un instrumento que para verse bien tiene que tapar al de al lado no midio
    mas: midio otra cosa.*
]]
local function muestrearCaida( self, alto )
    local id = "phantasmagoria_caida_" .. self:EntIndex()
    local previo, congelados, poses, vistas, n = nil, 0, 0, {}, 0
    local avisada, terminado = false, false

    timer.Create( id, PASO_CAIDA, MUESTRAS_CAIDA, function()
        -- ⚠ LA PARADA ES UNA BANDERA Y NO SOLO EL timer.Remove. Quitar el timer
        -- por nombre confia en que nadie mas tenga una referencia a esta funcion
        -- -- y el arnes justamente la tiene. Una ventana que puede emitir dos
        -- resumenes emite dos veredictos sobre la misma caida.
        if terminado then return end

        -- El bot puede morir o ser borrado en el medio, y un timer que le
        -- pregunta a una entidad invalida es un error de Lua en la consola del
        -- autor justo cuando estaba mirando el fantasma.
        if not IsValid( self ) then terminado = true timer.Remove( id ) return end

        local seq = self:GetSequence()
        local nombre = isnumber( seq ) and seq >= 0 and tostring( self:GetSequenceName( seq ) ) or ""
        local ciclo = self:GetCycle()
        local rate = self:GetPlaybackRate()

        -- Una secuencia invalida O sin nombre es la pose de referencia, y se
        -- marca con la misma columna que ya tiene el anillo para eso.
        local pose = ( not isnumber( seq ) or seq < 0 or nombre == "" or nombre == "nil" )

        -- El ciclo VUELVE A CERO al terminar un loop, y eso no es congelado. Se
        -- mide el cambio, no la direccion.
        local avanza = previo == nil or math.abs( ciclo - previo ) > 0.0005
        if not avanza and rate > 0 then congelados = congelados + 1 end
        previo = ciclo

        n = n + 1
        if pose then poses = poses + 1 end
        if nombre ~= "" and not vistas[ nombre ] then
            vistas[ nombre ] = true
            vistas[ #vistas + 1 ] = nombre

        end

        -- EL INSTANTE, y una sola vez por caida: con hora, para poder cruzarlo
        -- con las lineas de actividad de arriba.
        if pose and not avisada then
            avisada = true

            anotar( self, "Caida", {
                pedida = -1,
                seq = isnumber( seq ) and seq or nil,
                seqName = "POSE DE REFERENCIA ( T ) a los " ..
                    string.format( "%.2f", n * PASO_CAIDA ) .. " s del aterrizaje" ..
                    ( alto and ", caida de " .. alto .. " u" or "" ) ..
                    " -- el SERVIDOR no tiene secuencia puesta",
                resolvio = false,
                forzar = true,
            } )

        end

        if n >= MUESTRAS_CAIDA then
            anotar( self, "Caida", {
                pedida = -1,
                seq = nil,
                seqName = string.format(
                    "resumen: %d muestras en %.1f s%s -- %d sin secuencia, %d con el ciclo " ..
                    "congelado, secuencias vistas: %s",
                    n, n * PASO_CAIDA, alto and ( ", caida de " .. alto .. " u" ) or "",
                    poses, congelados,
                    #vistas > 0 and table.concat( vistas, ", " ) or "NINGUNA" ),
                -- El resumen de una ventana sana NO se marca: es el control de que
                -- el muestreo corrio. Una ventana sin ninguna muestra sana si.
                resolvio = poses == 0 and congelados == 0,
                forzar = true,
            } )

            -- ⚠ Y SE APAGA SOLO. El `timer.Create` de arriba pide 24
            -- repeticiones, pero el que decide cuando termina la ventana es esta
            -- funcion y no el contador del timer: si alguna vez corre de mas
            -- --otro addon reiniciando el timer, un arnes que lo llama a mano--
            -- emitiria un resumen por cada llamada extra y los resumenes se
            -- comerian el anillo. La condicion de parada vive donde esta el
            -- estado que la define.
            terminado = true
            timer.Remove( id )

        end
    end )
end

--- El aterrizaje de la base, con el muestreo colgado atras.
function ENT:OnLandOnGround( ent )
    local base = self.BaseClass and self.BaseClass.OnLandOnGround
    local ret

    -- La base PRIMERO: es la que hace el DoGesture( ACT_LAND ) y la que pone la
    -- actividad. Muestrear antes seria muestrear el estado que la caida todavia
    -- no toco -- que es el modo de falla de medir en el momento equivocado, y en
    -- este arco ya se pago con un timer.Simple( 0 ).
    if isfunction( base ) then ret = base( self, ent ) end

    if cvLandWatch:GetBool() then
        local okH, alto = pcall( self.FallHeight, self )

        muestrearCaida( self, okH and isnumber( alto ) and math.Round( alto ) or nil )

    end

    return ret

end

---------------------------------------------------------------------------
-- El censo: que actividades NO resuelven, sin esperar el sintoma
---------------------------------------------------------------------------
-- ⚠ ESTE ES EL COMANDO QUE PUEDE CONTESTAR LA PREGUNTA SIN QUE EL SINTOMA
-- OCURRA, y por eso va antes que el dump en la planilla. El log de arriba
-- necesita que la pose T pase mientras el log esta prendido; esto le pregunta al
-- modelo, ahora, por CADA actividad que la base puede llegar a pedirle, y lista
-- las que no tienen secuencia. Una actividad sin secuencia es, por definicion,
-- una pose de referencia esperando a que algo la pida.
--
-- El universo esta censado del codigo de la base, no recordado ( ver
-- lua/phantasmagoria/actlog.lua ). Si estuviera incompleto, esto daria verde
-- sobre una actividad que nunca miro.
PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_actmiss", function( ply )
    local say = PHANTASMAGORIA.MakeSay( ply )

    if not PHANTASMAGORIA.ActUniverse then
        say( "[Phantasmagoria] SIN CORRER: lua/phantasmagoria/actlog.lua no cargo. " ..
            "El universo de actividades no existe, asi que no hay contra que barrer." )
        return

    end

    local ghosts = {}
    PHANTASMAGORIA.EachGhost( function( g ) ghosts[ #ghosts + 1 ] = g end )

    if #ghosts == 0 then
        say( "[Phantasmagoria] SIN CORRER: no hay ningun fantasma vivo." )
        return

    end

    for _, ghost in ipairs( ghosts ) do
        say( "" )
        say( "[Phantasmagoria] #" .. ghost:EntIndex() .. "  " .. tostring( ghost:GetModel() ) )

        local total = ghost:GetSequenceCount()
        say( "    secuencias visibles: " .. total ..
            ( total > 100 and "  ( el $includemodel se resolvio )" or
              "  <- SIN LAS PRESTADAS: esta medicion NO VALE" ) )

        local sinSecuencia, sinEnum = 0, 0

        for _, fila in ipairs( PHANTASMAGORIA.ActUniverse ) do
            local act = PHANTASMAGORIA.ActNumber( fila.act )

            if not act then
                -- Que el ACT_ no exista en este build es un dato y no un error:
                -- se dice y se sigue. Declararlos por string es lo que permite
                -- llegar hasta aca en vez de no cargar el archivo.
                sinEnum = sinEnum + 1
                say( "    ??  " .. string.format( "%-34s", fila.act ) ..
                    "no existe como ACT_* en este build" )

            else
                local seq = ghost:SelectWeightedSequence( act )
                local hay = isnumber( seq ) and seq >= 0

                if not hay then sinSecuencia = sinSecuencia + 1 end

                say( "    " .. ( hay and "OK  " or "!!  " ) ..
                    string.format( "%-34s", fila.act ) ..
                    ( hay and ( "seq " .. seq .. " (" .. tostring( ghost:GetSequenceName( seq ) ) .. ")" )
                        or "NINGUNA SECUENCIA  <- pose de referencia ( T )" ) )

                if not hay then
                    say( "         se pide: " .. fila.via )
                    say( "         cubre:   " .. fila.cubre )

                end
            end
        end

        -- ⚠ EL VEREDICTO LLEVA EL DENOMINADOR, Y ESTA LINEA YA SALIO MAL UNA VEZ.
        -- La primera version decia ">> PASA: las 18 actividades del censo
        -- resuelven" contando `sinSecuencia == 0` -- y en la corrida del arnes
        -- OCHO de esas 18 no existian como ACT_* y por lo tanto NO SE MIDIERON:
        -- cayeron en la otra rama y no sumaron a ningun contador. O sea que el
        -- verde afirmaba sobre 18 habiendo mirado 10.
        --
        -- *Un veredicto que no resta lo que no pudo medir cuenta los ausentes
        -- como aprobados.* Ahora el numero que se dice es el de las MEDIDAS, y
        -- si falta alguna el veredicto no es PASA sino PARCIAL.
        local medidas = #PHANTASMAGORIA.ActUniverse - sinEnum

        if sinEnum > 0 then
            say( "    ⚠ " .. sinEnum .. " de " .. #PHANTASMAGORIA.ActUniverse ..
                " nombres del censo NO EXISTEN como ACT_* en este build: no se midieron. " ..
                "No cuentan ni a favor ni en contra." )

        end

        if sinSecuencia > 0 then
            say( "    >> " .. sinSecuencia .. " actividad(es) SIN SECUENCIA, de " .. medidas ..
                " medidas. Cada una es una pose de referencia en cuanto algo la pida." )
            say( "    >> Que esten NO prueba todavia que sean LA que vio el autor: eso lo ata " ..
                "el dump, que dice si alguna se pidio en el momento de la T." )

        elseif sinEnum > 0 then
            say( "    >> PARCIAL: las " .. medidas .. " actividades que se pudieron medir " ..
                "resuelven, pero " .. sinEnum .. " quedaron sin mirar. Esto NO descarta la lista." )

        else
            say( "    >> PASA: las " .. medidas .. " actividades del censo resuelven a alguna " ..
                "secuencia." )
            say( "    >> O sea que la pose T NO viene de una actividad de esta lista. " ..
                "El siguiente paso es el log en vivo ( phantasmagoria_ghost_actlog 1 )." )

        end
    end
end, "Barre TODAS las actividades que la base puede pedirle al modelo y dice cuales no resuelven " ..
    "a ninguna secuencia. Una actividad sin secuencia es una pose T esperando." )

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_actlog_dump", function( ply )
    local say = PHANTASMAGORIA.MakeSay( ply )

    if not PHANTASMAGORIA.ActLogEvents then
        say( "[Phantasmagoria] SIN CORRER: lua/phantasmagoria/actlog.lua no cargo." )
        return

    end

    local eventos = PHANTASMAGORIA.ActLogEvents()
    local totales = PHANTASMAGORIA.ActLogTotal()

    if #eventos == 0 then
        -- ⚠ EL VACIO TIENE QUE DECIR CUAL DE LOS DOS VACIOS ES. "No paso nada"
        -- y "el log estaba apagado" se ven igual desde afuera y significan lo
        -- contrario: el segundo no es una medicion.
        if not cvActLog:GetBool() then
            say( "[Phantasmagoria] SIN CORRER: el log esta APAGADO " ..
                "( phantasmagoria_ghost_actlog 0 ). No es que no haya pasado nada: no se miro." )

        else
            say( "[Phantasmagoria] el log esta prendido y no anoto NADA todavia. " ..
                "Con el bot vivo eso ya es raro: la primera actividad se anota al primer " ..
                "BodyUpdate." )

        end

        return

    end

    say( "[Phantasmagoria] " .. #eventos .. " evento(s) en el anillo, de " .. totales ..
        " anotados desde el ultimo clear." )

    if totales > #eventos then
        say( "    ( el anillo guarda los ultimos " .. #eventos .. "; los " ..
            ( totales - #eventos ) .. " anteriores se perdieron. Correr " ..
            "phantasmagoria_ghost_actlog_clear justo antes de reproducir el sintoma. )" )

    end

    say( "" )
    for _, ev in ipairs( eventos ) do
        say( "  " .. PHANTASMAGORIA.ActLogLine( ev ) )

    end

    local malos = PHANTASMAGORIA.ActLogUnresolved()
    local sinDato = PHANTASMAGORIA.ActLogNoData()

    say( "" )
    if #malos > 0 then
        say( "    >> " .. #malos .. " evento(s) SIN RESOLVER -- estos son los que dejan la pose T:" )
        for _, ev in ipairs( malos ) do
            say( "       " .. PHANTASMAGORIA.ActLogLine( ev ) )

        end

    end

    -- ⚠ LOS SIN DATO SE DICEN, Y ANTES SE CONTABAN COMO RESUELTOS. En la r17 el
    -- veredicto dijo "ninguna actividad quedo SIN RESOLVER" con la pose T impresa
    -- tres lineas mas arriba: los eventos cuya consulta erroreo tenian
    -- `resolvio = nil` y no entraban en ninguna de las dos cuentas.
    if #sinDato > 0 then
        say( "    >> " .. #sinDato .. " evento(s) donde NO SE PUDO PREGUNTAR si resolvia. " ..
            "No cuentan como resueltos ni como fallados:" )
        for _, ev in ipairs( sinDato ) do
            say( "       " .. PHANTASMAGORIA.ActLogLine( ev ) )

        end

    end

    --[[
        ⚠ QUE CONTIENE LA VENTANA, ANTES DE DECIR QUE NO CONTIENE EL DEFECTO.

        En la r18 este comando cerro con «ninguna actividad quedo SIN RESOLVER en
        esta ventana» sobre un dump donde el bot NUNCA aterrizo con el arma en la
        mano: las cuatro caidas fueron desarmado y los diecisiete segundos con el
        AR2 fueron sin caerse. O sea que la frase era cierta y no significaba
        nada -- y la fila que dependia de ella se marco roja.

        *Cuando un check puede salir vacio, el vacio tiene que ser una medicion.*
        Aca la medicion es la cuenta de VECES QUE EL SUJETO PASO POR EL PUNTO.
    ]]
    local censo = PHANTASMAGORIA.ActLogCenso and PHANTASMAGORIA.ActLogCenso( eventos )

    if censo then
        say( "    -- la ventana contiene: " .. censo.eventos .. " evento(s), " ..
            censo.conArma .. " con arma en la mano" ..
            ( #censo.armas > 0 and " ( " .. table.concat( censo.armas, ", " ) .. " )" or "" ) ..
            ", " .. censo.aterrizajes .. " con ACT_LAND, de ellos " ..
            censo.aterrizajesConArma .. " CON ARMA." )

        if not censo.landConocida then
            say( "    -- ⚠ este build no define ACT_LAND, asi que la cuenta de aterrizajes " ..
                "es 0 por no haber podido mirar, no por no haber habido." )

        end
    end

    -- LA PRECONDICION DE LA POSE T DEL ARMA, dicha ANTES del veredicto: el
    -- defecto necesita las dos cosas EN EL MISMO INSTANTE, y la ausencia de una
    -- de ellas no es un resultado sobre la otra.
    local provocado = censo and censo.aterrizajesConArma > 0

    if censo and not provocado then
        say( "    >> ⚠ PRECONDICION NO CUMPLIDA para la pose T del arma: hacen falta un " ..
            "aterrizaje y un arma AL MISMO TIEMPO, y en esta ventana hubo " ..
            censo.aterrizajes .. " aterrizaje(s) y " .. censo.conArma ..
            " evento(s) armado(s), pero 0 solapados." )
        say( "    >> Lo que siga NO descarta el defecto: dice que no se provoco. Para " ..
            "provocarlo hay que TIRARLO CON EL PHYSGUN mientras tiene el arma en la mano." )

    end

    if #malos == 0 and #sinDato == 0 and provocado then
        say( "    >> ninguna actividad quedo SIN RESOLVER en esta ventana, y de las " ..
            #eventos .. " se pudo preguntar por todas. Y la precondicion SI se cumplio: " ..
            censo.aterrizajesConArma .. " aterrizaje(s) con arma." )
        say( "    >> O sea que aca el descarte VALE: si la pose T se vio en esta ventana, " ..
            "no la causo una actividad sin secuencia -- hay que buscar en otro lado " ..
            "( una capa de gesto con peso, un SetSequence de otro addon, o el CLIENTE )." )

    elseif #malos == 0 and #sinDato == 0 then
        say( "    >> ninguna actividad quedo SIN RESOLVER, pero por lo de arriba eso NO es " ..
            "un descarte. Correr ph_ghost_land en el cliente y repetir provocandolo." )

    elseif #malos == 0 then
        say( "    >> NINGUN evento marcado como fallado, pero " .. #sinDato .. " sin dato: " ..
            "esta ventana NO descarta nada." )

    end
end, "Imprime las ultimas actividades que se le pidieron al fantasma y marca las que no resolvieron." )

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_actlog_clear", function( ply )
    local say = PHANTASMAGORIA.MakeSay( ply )

    if not PHANTASMAGORIA.ActLogClear then
        say( "[Phantasmagoria] SIN CORRER: lua/phantasmagoria/actlog.lua no cargo." )
        return

    end

    PHANTASMAGORIA.ActLogClear()
    ultimoPorPunto = {}
    say( "[Phantasmagoria] anillo vacio. Ahora reproducir el sintoma y correr " ..
        "phantasmagoria_ghost_actlog_dump." )

end, "Vacia el anillo del actlog. Correr justo antes de reproducir la pose T." )

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

        -- serie + edad, porque el EntIndex se recicla: ver el comentario de
        -- AdditionalInitialize. Sin esto, "#52 tenia tipo y ahora no" no
        -- distingue un fantasma que perdio el tipo de otro que heredo el numero.
        say( "#" .. ghost:EntIndex() .. "  " .. ghost:GetClass() ..
            "   serie " .. tostring( ghost.phantom_Serial or "?" ) ..
            "   nacio hace " .. ( ghost.phantom_BornAt and ( string.format( "%.1f", CurTime() - ghost.phantom_BornAt ) .. " s" ) or "?" ) )
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

        -- UNA linea de la ausencia ( Diseno 20 ① ), no su reporte: para eso
        -- esta phantasmagoria_ghost_vis. Va acá porque este es el comando que
        -- se tipea durante una corrida, y porque un fantasma invisible es
        -- justamente el que no se puede mirar.
        --
        -- Se imprime `GetNoDraw` -- el destino -- y al lado lo que la politica
        -- pide. Un instrumento que solo dijera "quiere ser invisible" no podria
        -- separar "la politica esta al reves" de "alguien mas lo dibuja".
        if ghost.phantom_WantsVisible then
            local quiere, motivo = ghost:phantom_WantsVisible()

            say( "    render  " .. ( ghost:GetNoDraw() and "INVISIBLE" or "se dibuja" ) ..
                "   la politica pide " .. ( quiere and "VISIBLE" or "INVISIBLE" ) ..
                ( ( quiere == not ghost:GetNoDraw() ) and "" or "   !! NO COINCIDEN" ) ..
                "   ( " .. motivo .. " )" )

        else
            say( "    render  ( server_cloak.lua no cargo )" )

        end

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
    -- ⚠ Este arranca en TRUE y los otros cuatro en false: no es un rasgo de
    -- algunos tipos sino la regla ( Diseno 20 ① ). El flag existe para el que NO
    -- desaparece, que hoy es el Alternate.
    [ "ausencia" ]  = { campo = "phantom_Absent",           que = "no se ve fuera del hunt ( Diseno 20 ① )" },
}

local FLAG_ORDER = { "abrir", "atravesar", "silencio", "caminar", "pasos", "ausencia" }

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

-- Pedido del autor ( r2 ): *"Puedes hacer que el fantasma no colisione contra
-- jugadores y npcs? Que es bastante molesto y eso lo convierte directamente en
-- un fantasma."*
--
-- VA DESPUES DE server_doors.lua Y NO ES INDISTINTO, aunque no lo consuma: ese
-- archivo es el DUENO UNICO de la solidez del fantasma ( escribe SetSolidMask en
-- dos lugares y nada mas ), y este archivo esta escrito para NO pelearle -- no
-- toca ni el grupo de colision ni la mascara. Leerlos en este orden es lo que
-- hace evidente que no se pisan.
--
-- ⚠ NO declara AdditionalInitialize ni AdditionalThink: las dos ya tienen dueno
-- y la segunda **no encadena, BORRA**. La marca de colision entra por
-- OnEntityCreated.
include( "server_collision.lua" )

-- Pedido del autor ( r2, fila 06 ): *"poder mantenerlos dentro de la casa en un
-- area sin que se escapen a la punta del mapa"*.
--
-- VA DESPUES de server_stuck.lua porque su primera guarda deja pasar derecho el
-- rescate de atascado ( `isUnstuck` ), que es justo lo que ese archivo mide: si
-- la correa compitiera con el rescate, el instrumento de atascos empezaria a
-- contar un defecto que introdujo esta.
include( "server_leash.lua" )

-- Diseno 20 ①: fuera del hunt el fantasma NO SE VE.
--
-- VA ULTIMO, y por dos motivos que son medibles. ( a ) consume
-- PHANTASMAGORIA.ResolveFlag, que se declara en server_doors.lua. ( b ) su
-- guarda del final comprueba que las claves de MyClassTask sigan siendo
-- funciones, y una guarda de ese tipo solo vale si corre despues de todos los
-- que podrian pisarlas.
--
-- ⚠ ESTE PARRAFO DECIA "las TRES claves ... y `BehaveUpdatePriority` de este
-- archivo" Y ERA FALSO EN LAS DOS MITADES ( corregido el 2026-08-09 ):
-- la guarda del cierre de server_cloak.lua itera DOS claves, y su bloque
-- "NO VA EN ENT.MyClassTask" dice explicitamente que descarto
-- esa clave porque cuelga de ENT:BehaveUpdate, que es un metodo y no una clave.
-- `BehaveUpdatePriority` NO se asigna en ningun archivo del addon.
--
-- La frase falsa costo real: server_events.lua copio ESTA lista para su propia
-- guarda y quedo tirando ErrorNoHalt en todos los arranques, acusandose de
-- pisar una clave que nunca existio. *Un comentario mentiroso se propaga al
-- lector que lo cita* -- y en un repo donde los comentarios son la
-- documentacion, eso lo convierte en un defecto con alcance.
include( "server_cloak.lua" )

-- Diseno 21: los eventos paranormales ( tirar objetos, parpadear las luces,
-- golpes, puertas, voces ), CERCA DEL FANTASMA y no cerca de un jugador al azar
-- como hace [gm] paranormal events.
--
-- VA ULTIMO, y por tres motivos medibles. ( a ) consume
-- PHANTASMAGORIA.ResolveFlag, que se declara en server_doors.lua. ( b ) delega
-- las puertas en Use2 y en el silenciador de server_doors.lua en vez de
-- reimplementarlos. ( c ) NO usa ENT.MyClassTask ni ENT:AdditionalThink -- las
-- dos claves ya tienen dueno y la segunda no se encadena, BORRA -- asi que
-- hereda la guarda de las tres claves de server_cloak.lua y la repite desde
-- aca, que ahora es el ultimo lugar donde alguien podria haberlas pisado.
include( "server_events.lua" )

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
