--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom / EVENTOS PARANORMALES

    Diseno 21. LO QUE PIDIO EL AUTOR, literal: "ver como lo hace el mod GM
    Paranormal Events para realizar los eventos paranormales como flicking de
    luces, lanzar objetos y demas, y agregar esas funcionalidades a
    phantasmagoria para que la entidad use eso, y que lo use CERCANO A LA
    ENTIDAD con cvars propias y flag para desactivar cada uno de esos sucesos
    paranormales ( que son en parte el gameplay normal de phasmophobia, el
    fantasma suele tirar cosas o hacer parpadear las luces en estado de Calma ).
    Los Flags son para hacer que algunos boten objetos otros los hagan con mayor
    intensidad y asi, nos puede servir para eventos como HUNTS y cosas asi."

    Los rasgos por tipo estan en lua/phantasmagoria/ghost_flags.lua, con la
    justificacion de cada uno. Este archivo es el MOTOR.

    ---------------------------------------------------------------------------
    LA DIFERENCIA DE FONDO CON gmpa, Y ES UNA SOLA PALABRA: **CERCA DE QUIEN**
    ---------------------------------------------------------------------------

    gmpa elige un jugador al azar y busca una navarea a menos de 2048 u DE EL
    ( GetRandomNavAroundPlayer, gm_paranormalactivities.lua:295-327 ). El
    fantasma no participa: sus eventos ocurren donde estas vos, no donde esta
    el. Por eso su actividad se siente como un generador de sustos ambiental y
    no como una presencia -- y por eso su "favourite room" tuvo que ser un
    Vector hardcodeado ( :93 ), porque no habia nadie a quien preguntarle.

    Aca el radio cuelga del FANTASMA. Todo evento pasa a menos de
    `phantasmagoria_ghost_evradius` unidades de el, lo que convierte la
    actividad paranormal en un instrumento de localizacion -- que es lo que es
    en Phasmophobia: la actividad te dice donde esta la habitacion, y la
    habitacion te dice donde poner las camaras.

    Consecuencia que hay que aceptar de frente: **si el fantasma esta lejos, no
    pasa nada, y eso es correcto.** Un jugador en la otra punta del mapa no
    tiene que oir nada. El instrumento lo dice con todas las letras cuando
    reporta un evento que no encontro sujeto.

    ---------------------------------------------------------------------------
    LOS CUATRO DEFECTOS DE gmpa QUE ESTE ARCHIVO NO HEREDA
    ---------------------------------------------------------------------------

    ( 1 ) LA ESCALERA NO ES EXCLUSIVA. gmpa tira math.random( 1, 100 ) UNA vez y
          encadena nueve `if eventChance <= N` SIN un solo `elseif`
          ( :562-670 ), asi que un tiro de 3 dispara los NUEVE en el mismo
          frame: puerta + luz rota + boton + sonido + sangre + fling + parpadeo
          + susurro + aparicion. No es "un evento cada 120 s", es una loteria
          donde a veces pasa todo junto.

          Aca hay UNA tabla de pesos y se sortea UNA categoria por disparo. El
          `count` del tipo repite el sorteo -- que es como The Twins hace dos
          cosas a la vez y el Poltergeist tira cuatro -- pero es un bucle
          declarado, no una cascada accidental.

    ( 2 ) EL DEBOUNCE SE COMPRUEBA DESPUES DE ACTUAR. gmpa mira
          `doorLastInteraction[ door:EntIndex() ]` en :761-765, o sea DESPUES
          del `door:Fire( "Use" )` de :758, y ademas escribe la tabla recien en
          :775 -- despues de un `return` que casi siempre gana. La regla de "no
          toques la misma puerta dos veces en 60 s" no previene nada.

          Aca la cuarentena se consulta ANTES de tocar nada, y se escribe en el
          mismo lugar donde se decide.

    ( 3 ) EL PARPADEO SON ~90 TIMERS ANIDADOS. gmpa hace
          `for i = 1, math.random( 32, 45 )` con un `timer.Simple( 0.1*i )` que
          adentro tiene otro `timer.Simple( 0.02*i )` ( :621-632 ). HIM, que
          hace el mismo efecto, usa DOS O CUATRO Fire con delay
          ( terminator_nextbot_homeless/server.lua:373-380 ). Se copia la forma
          de HIM.

    ( 4 ) `math.random( 1, #tabla )` SIN GUARDA, en siete lugares
          ( :280, :331, :338, :563, :571, :589, :619, :640, :755 ). En un mapa
          sin `light`, sin `func_button` o sin puertas -- o con el servidor
          vacio -- eso es un error de Lua por evento. Aca toda eleccion pasa por
          `elegir()`, que devuelve nil sobre una tabla vacia.

    ---------------------------------------------------------------------------
    DONDE SE ENGANCHA, Y POR QUE **NO** ES UN Think
    ---------------------------------------------------------------------------

    Las dos ranuras obvias estan ocupadas y la tercera es una trampa:

      ENT.MyClassTask.Think        es de server_doors.lua ( :1301 ). Y ademas
                                   `RunTask` CORTA EN EL PRIMER CALLBACK QUE
                                   DEVUELVE NO-NIL ( taskoverride.lua:47 ), asi
                                   que un segundo Think puede matar al de abajo.
      ENT:AdditionalThink          es de server_stuck.lua ( :990 ), que encadena
                                   con `myTbl.BaseClass.AdditionalThink` ( :1004 ).
                                   Un archivo nuevo que lo declare NO se encadena
                                   con el: lo BORRA, porque `myTbl.BaseClass`
                                   apunta a terminator_nextbot y no a la version
                                   anterior. El sintoma seria el instrumento de
                                   atascos mudo, sin un error.
      cualquier Think de tarea     ⚠ NO CORRE MIENTRAS UN JUGADOR MANEJA AL BOT.
                                   `RunTask( "Think" )` vive adentro del
                                   coroutine de prioridad
                                   ( behaviouroverrides.lua:694-695 ) y el propio
                                   autor de la base lo dice al lado del cloak
                                   ( wraithcloaking.lua:69 ). Un motor de eventos
                                   colgado de ahi se APAGA ENTERO cuando alguien
                                   posee al fantasma, sin un error y sin que el
                                   instrumento lo note.

    Asi que este bloque NO usa ninguna de las tres: usa **un solo timer de
    servidor** que recorre los fantasmas vivos con PHANTASMAGORIA.EachGhost.

    Y no es una concesion, es lo correcto para lo que hace: un evento cada 25-90
    segundos no necesita un callback por frame. Un timer de 1 Hz cuesta ~66
    veces menos y no pelea con nadie.

    LO QUE SE PIERDE Y COMO SE COMPENSA: un Think de tarea aparece POR NOMBRE en
    la lista de tareas de `phantasmagoria_ghost_where`, y "se engancho" deja de
    ser una suposicion. Un timer no aparece ahi. Por eso el reporte de este
    bloque imprime SIEMPRE el numero de vueltas del scheduler y hace cuanto fue
    la ultima -- porque *una guarda que solo habla cuando falla no puede
    acreditar que corrio*, y esa leccion la pago este mismo repo
    ( phantasmagoria_data.lua:124-130 ).

    ---------------------------------------------------------------------------
    LAS DOS COSAS QUE ESTE ARCHIVO NO TOCA, A PROPOSITO
    ---------------------------------------------------------------------------

      LA VISIBILIDAD    Las apariciones son el segundo rasgo mejor sostenido de
                        la tabla ( siete tipos ) y NO se escriben aca. La
                        visibilidad de este fantasma tiene un dueno unico que es
                        server_cloak.lua ( Diseno 20 ), con un reconciliador que
                        decide quien se ve y cuando. Un evento que llame
                        SetNoDraw por su cuenta le pelea al reconciliador y el
                        sintoma seria un fantasma parpadeando cuando no debe.
                        Cuando se escriba, entra por phantom_SetVisible.

      LAS PISADAS       server_steps.lua es el dueno. El evento de "pasos
                        lejanos" de Diseno 7.5 va ahi, no aca.

    Nada de esto se corrio en GMod antes de escribirlo. Si el juego contradice a
    los documentos, gana el juego.
---------------------------------------------------------------------------]]

---------------------------------------------------------------------------
-- LAS PERILLAS
---------------------------------------------------------------------------
-- El maestro es 0/1 y las de categoria son 0/1/2, que es la convencion de
-- PHANTASMAGORIA.ResolveFlag ( server_doors.lua:473-505 ):
--
--   0  CONTROL   nadie lo hace, ni siquiera el tipo que deberia
--   1  el flag del NPC ( o sea el rasgo del tipo ) decide
--   2  FORZADO   todos lo hacen, ignorando el rasgo
--
-- El 2 no es un lujo: es lo que hace medible una categoria que en 1 depende de
-- un sorteo. Sin el, un check de "el fantasma tira cosas" tendria que esperar a
-- que el peso salga favorecido, y un check que depende de un sorteo no es un
-- check.
local cvMaster = CreateConVar( "phantasmagoria_ghost_paranormal", "1", FCVAR_ARCHIVE,
    "Motor de eventos paranormales ( Diseno 21 ). 0 apaga TODO el bloque, incluido el scheduler.", 0, 1 )

local cvRadius = CreateConVar( "phantasmagoria_ghost_evradius", "450", FCVAR_ARCHIVE,
    "Radio base en unidades alrededor del FANTASMA dentro del cual pasan los eventos. " ..
    "450 u son ~8,5 m con la conversion de Diseno 1 ( 1 m = 52,5 u ), o sea el radio extendido " ..
    "de Phasmophobia. El rasgo `radius` del tipo lo multiplica.", 64, 4096 )

local cvMin = CreateConVar( "phantasmagoria_ghost_evmin", "25", FCVAR_ARCHIVE,
    "Segundos MINIMOS entre eventos de un mismo fantasma, antes de aplicar el rasgo `rate`.", 1, 600 )

local cvMax = CreateConVar( "phantasmagoria_ghost_evmax", "90", FCVAR_ARCHIVE,
    "Segundos MAXIMOS entre eventos de un mismo fantasma, antes de aplicar el rasgo `rate`.", 1, 1200 )

-- ⚠ Esta es la unica perilla del bloque que apaga algo que el autor pidio
-- EXPRESAMENTE que exista ( "nos puede servir para eventos como HUNTS" ), asi
-- que su default es 1 y no 0. Existe porque durante el hunt el fantasma ya hace
-- ruido por su cuenta, y alguien va a querer separar las dos fuentes al medir.
-- ⚠ DOS ESTADOS Y NO TRES, a diferencia de las ocho de categoria. El detalle
-- esta en phantom_FireEvent: el "2 = forzado" de las otras significa "ignora el
-- flag del NPC", y el hunt no tiene flag por NPC -- no hay nada que ignorar.
local cvHunt = CreateConVar( "phantasmagoria_ghost_evhunt", "1", FCVAR_ARCHIVE,
    "Eventos DURANTE el hunt. 0 = CONTROL ( en calma si, cazando no ) · 1 = los multiplicadores " ..
    "`hunt` del tipo deciden ( viven en ghost_flags.lua ). Esta convar tiene DOS estados, no tres.", 0, 1 )

-- La masa maxima de un prop que el fantasma puede mover. gmpa usa 10 kg
-- ( :463 ) y NO escala la fuerza por masa ( :490 ), asi que su limite no es una
-- decision de diseno sino una tapa a un bug de unidades: con fuerza fija, un
-- prop de 5 kg sale a 200 u/s y uno de 100 kg a 10 u/s. Aca la fuerza SI se
-- escala por masa ( es la forma que usan los cuatro precedentes del taller,
-- entre ellos sv_zhomeless_shelter.lua:1188 y terminator_weapon_dropper.lua:78 ),
-- asi que el limite pasa a ser lo que dice ser: hasta que peso se anima.
local cvMass = CreateConVar( "phantasmagoria_ghost_evmass", "60", FCVAR_ARCHIVE,
    "Masa maxima en kg de un prop que el fantasma puede tirar. Por encima, lo saltea.", 1, 5000 )

---------------------------------------------------------------------------
-- LAS OCHO CATEGORIAS
---------------------------------------------------------------------------
-- ⚠ ESTA LISTA ES LA CANONICA. ghost_flags.lua tiene una copia en
-- EventDefaults.weights y la guarda del final de este archivo compara las dos:
-- una categoria que exista aca y no alla nace con peso nil en los 30 tipos y el
-- sorteo la saltea siempre, sin un error. ( Y al reves: un peso alla sin
-- categoria aca es un rasgo que no le llega a nadie. )
--
-- `campo` es el nombre del flag por NPC, para PHANTASMAGORIA.ResolveFlag.
-- `cv` se llena abajo, despues de crear las convars, porque el orden importa:
-- una convar leida antes de crearse devuelve nil y `nil:GetInt()` revienta.
local CATS = {
    throw     = { orden = 1, que = "tira objetos fisicos cercanos",        campo = "phantom_EvThrow"     },
    knock     = { orden = 2, que = "golpea una puerta o pared",            campo = "phantom_EvKnock"     },
    creak     = { orden = 3, que = "hace crujir el piso",                  campo = "phantom_EvCreak"     },
    door      = { orden = 4, que = "abre o cierra una puerta",             campo = "phantom_EvDoor"      },
    light     = { orden = 5, que = "hace parpadear las luces",             campo = "phantom_EvLight"     },
    sound     = { orden = 6, que = "susurra, respira o tararea",           campo = "phantom_EvSound"     },
    prop      = { orden = 7, que = "hace sonar un trasto de la casa",      campo = "phantom_EvProp"      },
    furniture = { orden = 8, que = "abre un armario o un cajon",           campo = "phantom_EvFurniture" },
}

local CAT_ORDER = { "throw", "knock", "creak", "door", "light", "sound", "prop", "furniture" }

---------------------------------------------------------------------------
-- EL NEUTRO DE EMERGENCIA
---------------------------------------------------------------------------
-- ⚠ EL MOTOR TIENE QUE PODER CORRER SIN ghost_flags.lua. No porque sea probable
-- -- la guarda ( 2 ) del final grita si falta --, sino por COMO falla si no.
--
-- La primera version devolvia `PHANTASMAGORIA.EventDefaults` crudo. Si esa tabla
-- no existe, `phantom_EventFlags` devuelve nil, y el primer consumidor es
-- `phantom_ScheduleEvent` haciendo `flags.rate`... adentro del scheduler, con
-- `st.next` clavado en 0, o sea **un error de Lua por segundo, para siempre, y
-- `phantom_FireEvent` no se alcanza nunca**. Una guarda que grita una vez al
-- cargar no compensa un archivo que despues inunda la consola.
--
-- Con esta tabla, la falla degrada a "los 30 tipos se comportan igual", que es
-- exactamente lo que la guarda ( 2 ) dice que va a pasar. El instrumento y el
-- comportamiento cuentan la misma historia.
local NEUTRO = {
    rate = 1.0, count = 1, burst = 1, strength = 1.0, voice = 0,
    radius = { 1.0 },
    weights = { throw = 1, knock = 1, creak = 1, door = 1, light = 1, sound = 1, prop = 1, furniture = 1 },
    soundBanks = { voice = 1, breath = 1, humming = 1 },
    dir = { light = 0 },
    hunt = { rate = 1.0, count = 1, burst = 1, strength = 1.0, radius = 1.0 },
}

for _, key in ipairs( CAT_ORDER ) do
    CATS[ key ].cv = CreateConVar( "phantasmagoria_ghost_ev_" .. key, "1", FCVAR_ARCHIVE,
        "Evento paranormal '" .. key .. "': " .. CATS[ key ].que ..
        ". 0 control ( nadie ) · 1 el rasgo del tipo decide · 2 forzado.", 0, 2 )

end

-- Los defaults por NPC. Van en la CLASE y en `false` para ninguno: el default
-- de cada categoria es "si", y el rasgo del tipo lo modula por PESO, no por
-- booleano. El campo existe para que una subclase ( los 30 de Diseno 12.2 )
-- pueda apagar una categoria entera sin tocar el peso.
--
-- ⚠ Se declaran en nil A PROPOSITO y no en true: ResolveFlag distingue los tres
-- estados y DICE cual gano ( "el flag es nil ( la subclase no lo declaro )" ),
-- que es exactamente el dato que hace legible un reporte. Declararlos en true
-- borraria esa distincion sin cambiar el comportamiento.

---------------------------------------------------------------------------
-- LOS BANCOS DE SONIDO
---------------------------------------------------------------------------
-- Todos salen de sound/phantasmagoria/, que es NUESTRO namespace. gmpa trae 174
-- clips propios y NO se usa ninguno: montar `sound/gm_paranormal/` desde aca
-- seria la colision de rutas que phantasmagoria_assetcheck.lua existe para
-- detectar, y ademas el catalogo propio ya esta organizado POR EVENTO -- ver
-- sound/phantasmagoria/about.txt, que es el unico archivo del arbol de sonido
-- que se versiona.
--
-- ⚠ LAS LISTAS SON EXPLICITAS Y NO RANGOS. `event/creak/floorboard_*` va
-- 4, 6, 10, 11, 12, 13, 26, 28, 29 -- NO es contiguo. Un `for i = 1, 13` habria
-- pedido nueve archivos que no existen, y GMod no tira error por un sonido que
-- falta: no suena nada. Un banco con huecos se oye como un evento que a veces
-- es mudo, que es indistinguible de un evento que a veces no dispara.
local SND = {}

SND.throw = {
    "phantasmagoria/event/throw/throw_1.ogg",  "phantasmagoria/event/throw/throw_2.ogg",
    "phantasmagoria/event/throw/throw_3.ogg",  "phantasmagoria/event/throw/throw_4.ogg",
    "phantasmagoria/event/throw/throw_5.ogg",  "phantasmagoria/event/throw/throw_6.ogg",
    "phantasmagoria/event/throw/throw_7.ogg",  "phantasmagoria/event/throw/throw_8.ogg",
    "phantasmagoria/event/throw/throw_9.ogg",  "phantasmagoria/event/throw/throw_10.ogg",
    "phantasmagoria/event/throw/throw_11.ogg",
}

SND.knock = {
    "phantasmagoria/event/knock/door.ogg",
    "phantasmagoria/event/knock/window_1.ogg", "phantasmagoria/event/knock/window_2.ogg",
    "phantasmagoria/event/knock/window_3.ogg", "phantasmagoria/event/knock/window_4.ogg",
    "phantasmagoria/event/knock/window_5.ogg", "phantasmagoria/event/knock/window_6.ogg",
}

SND.impact = {
    "phantasmagoria/event/impact/wood_1.ogg", "phantasmagoria/event/impact/wood_2.ogg",
    "phantasmagoria/event/impact/wood_3.ogg", "phantasmagoria/event/impact/wood_4.ogg",
    "phantasmagoria/event/impact/wood_5.ogg", "phantasmagoria/event/impact/wood_6.ogg",
    "phantasmagoria/event/impact/wood_impact_1.ogg", "phantasmagoria/event/impact/wood_impact_2.ogg",
    "phantasmagoria/event/impact/wood_impact_3.ogg", "phantasmagoria/event/impact/wood_impact_4.ogg",
    "phantasmagoria/event/impact/wood_impact_5.ogg", "phantasmagoria/event/impact/wood_impact_6.ogg",
    "phantasmagoria/event/impact/metal_pipe_hit.ogg", "phantasmagoria/event/impact/metal_pipe_2.ogg",
    "phantasmagoria/event/impact/metal_pipe_6.ogg",   "phantasmagoria/event/impact/metal_deep.ogg",
    "phantasmagoria/event/impact/metal_tank.ogg",     "phantasmagoria/event/impact/stone.ogg",
}

SND.creak = {
    "phantasmagoria/event/creak/floorboard_4.ogg",  "phantasmagoria/event/creak/floorboard_6.ogg",
    "phantasmagoria/event/creak/floorboard_10.ogg", "phantasmagoria/event/creak/floorboard_11.ogg",
    "phantasmagoria/event/creak/floorboard_12.ogg", "phantasmagoria/event/creak/floorboard_13.ogg",
    "phantasmagoria/event/creak/floorboard_26.ogg", "phantasmagoria/event/creak/floorboard_28.ogg",
    "phantasmagoria/event/creak/floorboard_29.ogg", "phantasmagoria/event/creak/board_scrape.ogg",
    "phantasmagoria/event/creak/fence_shake_1.ogg", "phantasmagoria/event/creak/fence_shake_2.ogg",
    "phantasmagoria/event/creak/fence_shake_3.ogg", "phantasmagoria/event/creak/metal_hinge.ogg",
    "phantasmagoria/event/creak/rope_squeak.ogg",
}

SND.switch = {
    "phantasmagoria/light/switch_1.ogg", "phantasmagoria/light/switch_2.ogg",
    "phantasmagoria/light/switch_3.ogg", "phantasmagoria/light/switch_4.ogg",
}

-- Un solo clip, y por eso va en su propia tabla en vez de sumarse a `switch`:
-- romper una bombilla no es prenderla, y mezclarlos haria que el evento de
-- parpadeo a veces sonara a vidrio roto sin haber roto nada.
SND.bulb = { "phantasmagoria/event/impact/lightbulb_smash.ogg" }

-- ⚠ `break_slow.ogg` queda FUERA de SND.impact a proposito: dura mucho mas que
-- los demas y suena a algo cediendo, no a un golpe. En un banco de golpeteo
-- seria el clip que se oye como un bug.

SND.furniture = {
    "phantasmagoria/furniture/cabinet_close_1.ogg", "phantasmagoria/furniture/cabinet_close_2.ogg",
    "phantasmagoria/furniture/cabinet_close_3.ogg", "phantasmagoria/furniture/cabinet_close_4.ogg",
    "phantasmagoria/furniture/cabinet_close_5.ogg", "phantasmagoria/furniture/drawers_close_1.ogg",
    "phantasmagoria/furniture/drawers_close_2.ogg", "phantasmagoria/furniture/drawers_close_3.ogg",
    "phantasmagoria/furniture/drawers_close_4.ogg", "phantasmagoria/furniture/drawers_close_5.ogg",
}

-- ⚠ SIN LOS `_loop`. `prop/` trae fridge_loop, elevator_loop, sink_loop y
-- ceiling_fan, que son AMBIENTE y duran minutos: disparados como one-shot desde
-- sound.Play no se pueden parar, porque sound.Play no devuelve nada que se
-- pueda apagar. Un banco de eventos con un loop adentro es un evento que a veces
-- no termina.
SND.prop = {
    "phantasmagoria/prop/clock_tick.ogg",     "phantasmagoria/prop/phone_ring.ogg",
    "phantasmagoria/prop/phone_vibrate.ogg",  "phantasmagoria/prop/piano_key_1.ogg",
    "phantasmagoria/prop/piano_key_2.ogg",    "phantasmagoria/prop/piano_key_3.ogg",
    "phantasmagoria/prop/piano_key_4.ogg",    "phantasmagoria/prop/piano_key_5.ogg",
    "phantasmagoria/prop/guitar_string.ogg",  "phantasmagoria/prop/microwave_beep.ogg",
    "phantasmagoria/prop/car_alarm.ogg",      "phantasmagoria/prop/car_lock.ogg",
    "phantasmagoria/prop/teddy_laugh.ogg",    "phantasmagoria/prop/toilet_flush.ogg",
    "phantasmagoria/prop/tv_on.ogg",          "phantasmagoria/prop/tv_off.ogg",
    "phantasmagoria/prop/tv_noise.ogg",       "phantasmagoria/prop/tv_remote.ogg",
    "phantasmagoria/prop/key_1.ogg",          "phantasmagoria/prop/key_2.ogg",
}

SND.door = {
    "phantasmagoria/door/handle_open_1.ogg", "phantasmagoria/door/handle_open_2.ogg",
    "phantasmagoria/door/handle_open_3.ogg", "phantasmagoria/door/handle_open_4.ogg",
    "phantasmagoria/door/handle_open_5.ogg", "phantasmagoria/door/handle_open_7.ogg",
    "phantasmagoria/door/close_3.ogg", "phantasmagoria/door/close_4.ogg",
    "phantasmagoria/door/close_5.ogg", "phantasmagoria/door/close_6.ogg",
    "phantasmagoria/door/close_7.ogg", "phantasmagoria/door/close_gentle.ogg",
    "phantasmagoria/door/close_wood.ogg",
}

---------------------------------------------------------------------------
-- LA VOZ DEL FANTASMA, que es UNA y no un sorteo por clip
---------------------------------------------------------------------------
-- El catalogo tiene DOS voces y el indice del archivo ES la voz: la 1 femenina,
-- la 2 grave ( sound/phantasmagoria/about.txt ). Sortear clip por clip haria
-- que el mismo fantasma susurre con voz de mujer y respire con voz de hombre en
-- el mismo minuto -- que es peor que no tener dos voces, porque delata que el
-- sonido es una tabla.
--
-- Asi que la voz se sortea UNA VEZ por fantasma y se guarda. El rasgo `voice`
-- del tipo la fija cuando la fuente lo dice: Banshee y Dayan son "Can only be
-- female, ghost model and ghost name will reflect this".
local VOZ = {
    [ 1 ] = {
        voice = {
            "phantasmagoria/ghost/paranormal_voice/voice_1_cant_find_me.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_gasp_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_gasp_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_gasp_03.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_gasp_04.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_get_out_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_get_out_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_hey_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_hey_03.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_hey_07.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_high_laugh_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_high_laugh_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_high_laugh_03.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_mutterings_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_mutterings_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_mutterings_03.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_shhh_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_slow_laugh.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_slow_laugh_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_slow_laugh_03.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_sohungry.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_why_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_why_02.ogg",
        },
        breath = {
            "phantasmagoria/ghost/breathing/voice_1_01.ogg",
            "phantasmagoria/ghost/breathing/voice_1_02.ogg",
            "phantasmagoria/ghost/breathing/voice_1_03.ogg",
            "phantasmagoria/ghost/breathing/voice_1_04.ogg",
        },
        humming = {
            "phantasmagoria/ghost/humming/voice_1_singing.ogg",
            "phantasmagoria/ghost/humming/voice_1_musicbox.ogg",
            "phantasmagoria/ghost/humming/female.ogg",
        },
    },

    [ 2 ] = {
        voice = {
            "phantasmagoria/ghost/paranormal_voice/voice_2_cold_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_help_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_laugh_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_laugh_03.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_laugh_04.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_lost_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_moan_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_moan_03.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_moan_04.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_mutters_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_shout_get_out_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_watching_you_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_whisper_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_whisper_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_whisper_03.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_whisper_04.ogg",
        },
        breath = {
            "phantasmagoria/ghost/breathing/voice_2_01.ogg",
            "phantasmagoria/ghost/breathing/voice_2_02.ogg",
            "phantasmagoria/ghost/breathing/voice_2_03.ogg",
            "phantasmagoria/ghost/breathing/voice_2_04.ogg",
        },
        humming = {
            "phantasmagoria/ghost/humming/voice_2_singing.ogg",
            "phantasmagoria/ghost/humming/voice_2_musicbox.ogg",
            "phantasmagoria/ghost/humming/male.ogg",
        },
    },
}

---------------------------------------------------------------------------
-- BITACORA
---------------------------------------------------------------------------
-- Misma forma que StepLog, StuckLog y VisLog: un anillo acotado que el comando
-- de reporte vuelca. Existe porque un evento paranormal dura menos que el
-- tramite de medirlo -- tipear un comando son varios segundos y el susurro ya
-- termino --, asi que preguntar "que paso" en vivo devuelve siempre el estado
-- de reposo. La leccion esta en PLANTILLA_CHECKS.md punto 5.
local BITACORA_MAX = 60

PHANTASMAGORIA.EventLog = PHANTASMAGORIA.EventLog or {}

local function anotar( texto )
    local log = PHANTASMAGORIA.EventLog
    log[ #log + 1 ] = string.format( "%7.1f  %s", CurTime(), texto )

    while #log > BITACORA_MAX do table.remove( log, 1 ) end

end

---------------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------------

-- ⚠ LA GUARDA QUE gmpa NO TIENE, EN NUEVE LUGARES. `math.random( 1, 0 )` es un
-- error en LuaJIT, y una tabla vacia es el caso NORMAL: un mapa sin puertas, un
-- banco de sonido mal escrito, un servidor sin jugadores. Devolver nil hace que
-- el que llama tenga que decidir que hacer con el vacio, que es justo lo que
-- queremos que decida.
local function elegir( t )
    if not istable( t ) then return nil end

    local n = #t
    if n <= 0 then return nil end

    return t[ math.random( n ) ]

end

-- Pesos -> una key. Devuelve nil si TODOS los pesos son cero o negativos, que
-- es un estado legitimo ( un tipo al que le apagaron todas las categorias ) y
-- NO un error.
--
-- Recorre `orden` y no `pairs( pesos )` por lo mismo que SortearTipo
-- ( server_type.lua:148-152 ): pairs no tiene orden definido, asi que un sorteo
-- escrito sobre el hash seria irreproducible entre corridas y no habria forma
-- de contarlo.
local function sortearPeso( pesos, orden )
    local total = 0

    for _, key in ipairs( orden ) do
        local w = pesos[ key ]
        if isnumber( w ) and w > 0 then total = total + w end

    end

    if total <= 0 then return nil, total end

    local tiro = math.Rand( 0, total )
    local acum = 0

    for _, key in ipairs( orden ) do
        local w = pesos[ key ]

        if isnumber( w ) and w > 0 then
            acum = acum + w
            if tiro <= acum then return key, total end

        end
    end

    -- Solo se llega por error de coma flotante en el ultimo tramo. Se devuelve
    -- el ultimo con peso en vez de nil: un nil aca se leeria como "todos los
    -- pesos en cero", que es un estado distinto y ya tiene su rama arriba.
    for i = #orden, 1, -1 do
        local w = pesos[ orden[ i ] ]
        if isnumber( w ) and w > 0 then return orden[ i ], total end

    end

    return nil, total

end

-- "Un punto valido cerca del fantasma, preferentemente donde nadie mira."
--
-- NO usa navmesh a proposito, y esa es una decision con consecuencia: los
-- eventos NO dependen de que el mapa tenga navareas. La base parchea areas
-- ( terminator_areapatcher.lua, default 1 ) pero el parcheo es INCREMENTAL y
-- necesita un bot caminando, asi que al arrancar un mapa sin navmesh el
-- navmesh esta vacio por minutos. Un motor de eventos que dependiera de el
-- estaria mudo justo al principio de la partida, que es cuando el jugador
-- decide si el mod funciona.
--
-- Un trace al piso, en cambio, funciona en el primer frame de cualquier mapa.
local function puntoCerca( ghost, radio, evitarVista )
    local origen = ghost:GetPos() + Vector( 0, 0, 40 )
    local mejor, mejorVisible

    for intento = 1, 8 do
        local ang  = math.Rand( 0, 360 )
        local dist = math.Rand( radio * 0.25, radio )
        local cand = origen + Vector( math.cos( math.rad( ang ) ) * dist,
                                      math.sin( math.rad( ang ) ) * dist, 0 )

        -- Primero: que se pueda LLEGAR desde el fantasma. Sin esto el evento
        -- suena del otro lado de la pared del cuarto de al lado, que es
        -- exactamente lo que hace que la actividad de gmpa no ubique nada.
        local paso = util.TraceLine( {
            start  = origen,
            endpos = cand,
            mask   = MASK_SOLID_BRUSHONLY,
            filter = ghost,
        } )

        if paso.Hit then
            -- Se retrocede un poco del muro en vez de descartar: pegado a la
            -- pared sigue siendo un lugar valido para un ruido, y descartar
            -- gastaria los ocho intentos en cualquier cuarto chico.
            cand = paso.HitPos - ( cand - origen ):GetNormalized() * 16

        end

        -- Y despues: el piso, que es donde un ruido tiene sentido.
        local abajo = util.TraceLine( {
            start  = cand,
            endpos = cand - Vector( 0, 0, 160 ),
            mask   = MASK_SOLID_BRUSHONLY,
            filter = ghost,
        } )

        local pos = abajo.Hit and ( abajo.HitPos + Vector( 0, 0, 8 ) ) or cand

        if not evitarVista then return pos, "sin filtro de vista" end

        local visto = false

        for _, ply in ipairs( player.GetAll() ) do
            if not ply:Alive() then continue end

            local tr = util.TraceLine( {
                start  = ply:EyePos(),
                endpos = pos,
                mask   = MASK_BLOCKLOS,
                filter = ply,
            } )

            if not tr.Hit then visto = true break end

        end

        if not visto then return pos, "fuera de la vista de todos ( intento " .. intento .. " )" end

        mejor, mejorVisible = pos, true

    end

    -- Los ocho intentos cayeron a la vista de alguien. Se devuelve el ultimo y
    -- se DICE que es visible, en vez de no hacer nada: un evento que no ocurre
    -- porque el jugador estaba mirando es un evento que nunca ocurre en un
    -- pasillo, y el instrumento tiene que poder distinguir las dos cosas.
    --
    -- ⚠ ESTA FUNCION NUNCA DEVUELVE nil, Y ESO ES UN CONTRATO, NO UNA
    -- CASUALIDAD. `pos` siempre se resuelve ( el trace al piso tiene fallback ),
    -- asi que o se retorna adentro del bucle o `mejor` esta puesto al salir.
    --
    -- Se escribe porque la primera version tenia un `or "sin punto"` aca y
    -- CUATRO ramas `if not pos then return false, "no se encontro un punto"` en
    -- los eventos que la llaman -- todas inalcanzables. No hacian dano, pero le
    -- daban al operador una lista de motivos que el creia exhaustiva con uno
    -- adentro que no puede salir nunca. *Un instrumento que nombra un desenlace
    -- imposible envenena la lectura de los que si son posibles.*
    return mejor, "TODOS los intentos quedaron a la vista ( se uso igual )"

end

-- El estado por fantasma. Vive en la entidad y no en una tabla indexada por
-- EntIndex: los EntIndex se RECICLAN, y este repo ya pago esa leccion en la
-- ronda 23 ( "un registro indexado por un numero que se recicla" ).
local function estado( ghost )
    ghost.phantom_ev = ghost.phantom_ev or {
        next     = 0,
        vueltas  = 0,
        disparos = 0,
        ultimo   = nil,
        ultimoT  = 0,
        porCat   = {},
        motivos  = {},
        doorHasta = {},
    }

    return ghost.phantom_ev

end

---------------------------------------------------------------------------
-- LOS RASGOS: el getter, que es la regla 2 de ghost_flags.lua
---------------------------------------------------------------------------
-- ⚠ EL MOTOR NUNCA LEE self.phantom_Type. Lee ESTO.
--
-- No es estilo: The Mimic ( ghost_types.lua:556-557 ) imita "all behaviors,
-- tells, and abilities" de otro tipo cada 30-120 s, y lo va a hacer
-- sobreescribiendo este metodo para devolver la ficha del imitado. Si el motor
-- leyera el campo, el Mimic necesitaria un `if` adentro del motor -- y el
-- diseno declara al Mimic como la prueba de fuego del corte.
--
-- El repo hace hoy lo contrario y esta medido: phantom_GetType()
-- ( server_type.lua:268 ) tiene CERO llamadores y los cuatro consumidores leen
-- el campo crudo. Este archivo NO sigue ese patron, y esa divergencia es
-- deliberada.
function ENT:phantom_EventFlags()
    -- El neutro del archivo de datos si esta; el de emergencia si no. NUNCA nil:
    -- ver el bloque NEUTRO de arriba para lo que costaba devolver nil.
    local defaults = istable( PHANTASMAGORIA.EventDefaults ) and PHANTASMAGORIA.EventDefaults or NEUTRO

    -- Un fantasma SIN TIPO es un estado legitimo y con cuatro caminos medidos
    -- ( typeassign 0, override a una key inexistente, Types vacia, TypeOrder
    -- vacia -- server_type.lua:291, :177, :166, :203 ). No es "el tipo por
    -- defecto": es sin tipo, y se comporta como el neutro.
    local t = self.phantom_Type

    if not istable( t ) or not istable( t.events ) then
        return defaults, ( istable( t ) and "el tipo no tiene rasgos de evento ( ghost_flags.lua no fusiono )" or
            "el fantasma no tiene tipo ( se usa el neutro )" )

    end

    return t.events, "los rasgos del tipo " .. tostring( self.phantom_TypeKey )

end

-- La voz, sorteada una vez y guardada. Ver el bloque VOZ de arriba.
function ENT:phantom_EventVoice()
    if self.phantom_evVoice then return self.phantom_evVoice end

    local flags = self:phantom_EventFlags()
    local fija  = flags.voice

    -- 0 ( o nil ) significa "sorteada". 1 y 2 la fijan.
    if fija == 1 or fija == 2 then
        self.phantom_evVoice = fija

    else
        self.phantom_evVoice = math.random( 1, 2 )

    end

    return self.phantom_evVoice

end

-- ¿Esta categoria puede correr? Devuelve DOS cosas y la segunda es el motivo,
-- porque "no tira cosas" tiene causas distintas que desde afuera se ven igual:
-- la convar maestra, la convar de la categoria, el flag del NPC, el peso del
-- tipo en cero, o que no habia sujeto. El instrumento imprime el motivo.
function ENT:phantom_EventAllowed( cat )
    local info = CATS[ cat ]
    if not info then return false, "la categoria '" .. tostring( cat ) .. "' no existe" end

    if not cvMaster:GetBool() then
        return false, "phantasmagoria_ghost_paranormal esta en 0 ( el bloque entero apagado )"

    end

    local resolver = PHANTASMAGORIA.ResolveFlag

    -- Misma guarda que server_speed.lua:465 y server_cloak.lua:75. El
    -- resolvedor se declara en server_doors.lua y este archivo se incluye
    -- despues, asi que en condiciones normales existe -- pero si server_doors
    -- fallo al cargar, el sintoma tiene que ser una linea legible y no un
    -- error de indexacion en el primer evento.
    if not resolver then
        return false, "PHANTASMAGORIA.ResolveFlag no existe ( server_doors.lua no cargo )"

    end

    return resolver( self, info.campo, info.cv, true )

end

---------------------------------------------------------------------------
-- LOS OCHO EVENTOS
---------------------------------------------------------------------------
-- CONTRATO COMUN: cada uno recibe ( ghost, radio, fuerza, cuantos ) y devuelve
-- ( ok, detalle ). `ok` false NO es un error: la mayoria de las veces significa
-- "no habia sujeto", que es informacion. El detalle viaja al instrumento.
--
-- Ninguno emite sonido EN el fantasma. Esa regla no es estetica: un fantasma
-- que suena en su propia posicion es un localizador gratis, y mata de un saque
-- al spirit box, a la parabolica y a la caja musical, que son tres mecanicas
-- que existen para que ubicarlo cueste. El sonido sale del OBJETO ( el prop que
-- vuela, la puerta que cruje ) o de un PUNTO cercano.
local EV = {}

-- Las tres clases de puerta, con los nombres que usa server_doors.lua:217-221.
--
-- ⚠ SE DECLARA ACA ARRIBA Y NO AL LADO DEL EVENTO DE PUERTAS, aunque ahi seria
-- donde se lee mejor. En Lua el alcance de un `local` empieza DESPUES de su
-- declaracion, asi que una tabla declarada mas abajo referenciada desde una
-- funcion de mas arriba NO es esa tabla: es una GLOBAL que vale nil. No tira
-- error -- `nil[ clase ]` si, pero `X and nil[ ... ]` con la guarda puesta ni
-- eso -- y el sintoma seria que el evento de golpes nunca reconoce una puerta.
-- EV.knock la usa y esta declarado antes que EV.door.
local DOOR_CLASSES = {
    [ "prop_door_rotating" ] = true,
    [ "func_door" ]          = true,
    [ "func_door_rotating" ] = true,
}

---------------------------------------------------------------------------
-- throw -- el Poltergeist
---------------------------------------------------------------------------
-- Las clases: `prop_physics` Y `prop_physics_multiplayer`. gmpa solo mira la
-- primera ( :471 ), que en un servidor multijugador deja fuera buena parte de
-- lo que hay tirado.
local THROW_CLASSES = {
    [ "prop_physics" ]             = true,
    [ "prop_physics_multiplayer" ] = true,
}

-- Lo que NO se toca, y por que cada uno. Es una lista negra CORTA porque la
-- blanca de arriba ya hace el trabajo grueso; estos son los que pasan la blanca
-- y aun asi no hay que mover.
local function propVetado( ent, ghost )
    if ent == ghost then return "es el fantasma" end
    if ent.IsPhantasmagoriaGhost then return "es otro fantasma" end

    -- Un prop en la mano de alguien: moverlo pelea contra el physgun / gravity
    -- gun y el resultado es un tironeo. Los tres precedentes del taller lo
    -- filtran igual ( him/server.lua:526, corpus_cargo_capture.lua:914 ).
    if ent.IsPlayerHolding and ent:IsPlayerHolding() then return "alguien lo tiene agarrado" end
    if IsValid( ent:GetOwner() ) then return "tiene dueno ( GetOwner )" end

    -- Los items de Cargo son inventario, no decorado. Tirar el inventario de un
    -- jugador por el piso no es un evento paranormal, es una perdida de datos.
    if ent.CargoItem or ent.cargo_ItemID then return "es un item de Cargo" end

    -- Nuestro propio equipamiento plantado ( tripode, DOTS, sensor ): moverlo
    -- invalidaria una medicion del jugador, que es lo contrario de lo que un
    -- evento tiene que hacer.
    if ent.IsPhantasmagoriaEquipment then return "es equipamiento de Phantasmagoria" end

    return nil

end

EV.throw = function( ghost, radio, fuerza, cuantos )
    local candidatos, vetos = {}, 0
    local masaMax = cvMass:GetFloat()

    for _, ent in ipairs( ents.FindInSphere( ghost:GetPos(), radio ) ) do
        if not IsValid( ent ) then continue end
        if not THROW_CLASSES[ ent:GetClass() ] then continue end

        local veto = propVetado( ent, ghost )
        if veto then vetos = vetos + 1 continue end

        local phys = ent:GetPhysicsObject()
        if not IsValid( phys ) then continue end

        -- ⚠ UN PROP CONGELADO NO SE MUEVE Y NO AVISA. `ApplyForceCenter` sobre
        -- un physobj con la motion apagada no tira error: no pasa nada. Sin
        -- este filtro, un mapa lleno de props congelados por un jugador daria
        -- "evento disparado" en el reporte y silencio en el juego -- un verde
        -- que no corresponde a nada. El filtro ya existe escrito en la base
        -- ( motionoverrides.lua:182, con la meta cacheada ).
        if not phys:IsMotionEnabled() then vetos = vetos + 1 continue end
        if phys:GetMass() > masaMax then vetos = vetos + 1 continue end

        candidatos[ #candidatos + 1 ] = ent

    end

    if #candidatos <= 0 then
        return false, "no habia props fisicos movibles a " .. math.Round( radio ) .. " u ( " ..
            vetos .. " vetado(s) )"

    end

    local movidos = 0
    local total   = #candidatos

    for i = 1, math.min( cuantos, total ) do
        -- Se saca de la lista para no tirar el mismo prop dos veces en el mismo
        -- evento: con `count = 4` y dos props en el cuarto, sortear con
        -- reposicion daria "cuatro objetos" en el reporte y dos en la pantalla.
        local idx  = math.random( #candidatos )
        local prop = table.remove( candidatos, idx )

        if not IsValid( prop ) then continue end

        local phys = prop:GetPhysicsObject()
        if not IsValid( phys ) then continue end

        -- LA FUERZA SE ESCALA POR MASA. gmpa no lo hace ( :490 ) y por eso
        -- necesito un tope de 10 kg: con impulso fijo, la velocidad resultante
        -- es inversamente proporcional a la masa. Los cuatro precedentes del
        -- taller multiplican por GetMass y ninguno tiene tope de masa por ese
        -- motivo.
        local dir = ( prop:WorldSpaceCenter() - ghost:WorldSpaceCenter() )
        dir.z = 0

        if dir:LengthSqr() < 1 then dir = VectorRand() dir.z = 0 end

        dir:Normalize()
        dir.z = math.Rand( 0.25, 0.6 )

        local K = math.Rand( 180, 320 ) * fuerza

        phys:Wake()
        phys:ApplyForceCenter( dir * K * phys:GetMass() )

        local snd = elegir( SND.throw )
        if snd then prop:EmitSound( snd, 75, math.random( 92, 108 ) ) end

        movidos = movidos + 1

    end

    if movidos <= 0 then
        -- ⚠ EL CONTEO VA DE UNA COPIA TOMADA ANTES DEL BUCLE. La primera version
        -- imprimia `#candidatos + movidos`, y el bucle vacia la tabla con
        -- table.remove: con dos candidatos y movidos = 0 la linea decia
        -- literalmente "habia 0 candidato(s)" en una rama a la que solo se llega
        -- habiendo tenido al menos uno. *Un numero imposible al lado de un
        -- veredicto* es del catalogo, y delata el instrumento sin decir cual.
        return false, "habia " .. total .. " candidato(s) y ninguno sobrevivio al sorteo"

    end

    return true, movidos .. " prop(s) tirado(s) con fuerza x" .. string.format( "%.2f", fuerza )

end

---------------------------------------------------------------------------
-- knock -- el golpeteo, el evento mas barato y el que siempre funciona
---------------------------------------------------------------------------
-- No necesita props, ni puertas, ni luces, ni navmesh. Traza a una pared cerca
-- del fantasma y suena ahi. Es el piso del motor: si TODAS las demas categorias
-- quedan sin sujeto, esta contesta igual, y eso es deliberado -- un motor de
-- eventos que en un mapa pelado no hace absolutamente nada se lee como roto.
EV.knock = function( ghost, radio )
    local origen = ghost:GetPos() + Vector( 0, 0, 45 )
    local mejor, contra

    for _ = 1, 8 do
        local ang = math.Rand( 0, 360 )
        local dir = Vector( math.cos( math.rad( ang ) ), math.sin( math.rad( ang ) ), math.Rand( -0.2, 0.3 ) )

        local tr = util.TraceLine( {
            start  = origen,
            endpos = origen + dir * radio,
            mask   = MASK_SOLID,
            filter = ghost,
        } )

        if tr.Hit then
            mejor = tr.HitPos + tr.HitNormal * 4

            -- CONTRA QUE golpeo decide de que banco sale el clip, y no es un
            -- adorno: el catalogo separa las dos cosas por lo que SON
            -- ( about.txt ) -- `event/knock` es "golpeteo en puerta y ventana" y
            -- `event/impact` es "golpes contra madera, metal, piedra". Golpear
            -- una pared con el clip de una puerta se oye mal sin que nadie pueda
            -- decir por que.
            contra = ( IsValid( tr.Entity ) and DOOR_CLASSES[ tr.Entity:GetClass() ] ) and "puerta" or "pared"
            break

        end
    end

    -- Sin pared a la vista ( campo abierto ): suena al lado igual. Un fantasma
    -- afuera sigue haciendo ruido.
    local pos = mejor or ( origen + VectorRand() * math.min( radio, 120 ) )

    local banco = ( contra == "puerta" ) and SND.knock or SND.impact
    local snd   = elegir( banco )

    if not snd then
        return false, "el banco de golpes esta vacio ( contra " .. tostring( contra or "nada" ) .. " )"

    end

    -- Dos o tres golpes con separacion, no uno: un golpe suelto se confunde con
    -- un ruido del motor de fisica. Tres golpes iguales son inequivocamente
    -- alguien golpeando.
    local golpes = math.random( 2, 3 )

    for i = 1, golpes do
        timer.Simple( ( i - 1 ) * math.Rand( 0.28, 0.45 ), function()
            if not IsValid( ghost ) then return end
            sound.Play( snd, pos, 80, math.random( 94, 106 ) )

        end )
    end

    return true, golpes .. " golpe(s) a " .. math.Round( ghost:GetPos():Distance( pos ) ) .. " u" ..
        ( mejor and ( " ( contra " .. contra .. ", banco " ..
            ( contra == "puerta" and "event/knock" or "event/impact" ) .. " )" )
          or " ( al aire, no habia pared -- banco event/impact )" )

end

---------------------------------------------------------------------------
-- creak -- el crujido, la presencia ambiental
---------------------------------------------------------------------------
EV.creak = function( ghost, radio )
    -- puntoCerca nunca devuelve nil ( contrato declarado en su cuerpo ).
    local pos, comoSalio = puntoCerca( ghost, radio, true )

    local snd = elegir( SND.creak )
    if not snd then return false, "el banco event/creak esta vacio" end

    sound.Play( snd, pos, 72, math.random( 90, 105 ) )

    return true, "crujido a " .. math.Round( ghost:GetPos():Distance( pos ) ) .. " u  ( " .. comoSalio .. " )"

end

---------------------------------------------------------------------------
-- door -- la puerta que se mueve sola
---------------------------------------------------------------------------
-- ⚠ NO REIMPLEMENTA LA APERTURA. server_doors.lua tiene 1729 lineas dedicadas a
-- esto y sabe cosas que este bloque no: que los enums de estado estan
-- INVERTIDOS entre `prop_door_rotating` ( m_eDoorState ) y `func_door*`
-- ( m_toggle_state, donde 0 es ABIERTA ), que `OpenAwayFrom` es solo de
-- CBasePropDoor y pide un TARGETNAME, que `Use` es un TOGGLE, y como silenciar
-- una hoja borrandole sus siete keyvalues de sonido.
--
-- Aca solo se elige la puerta y se delega. Si esa delegacion no esta disponible
-- se DICE, en vez de improvisar un Fire.
--
-- ( DOOR_CLASSES esta declarada arriba de EV.throw, y el motivo esta escrito
--   ahi: EV.knock la necesita y en Lua un local no alcanza hacia atras. )

-- Cuarentena. gmpa tiene la misma idea y la comprueba DESPUES de actuar
-- ( :758 dispara, :761 comprueba, :775 escribe -- detras de un return ), asi que
-- no previene nada. Aca se consulta antes y se escribe en el mismo lugar.
local DOOR_COOLDOWN = 45

EV.door = function( ghost, radio )
    local st  = estado( ghost )
    local now = CurTime()
    local candidatos, enCuarentena = {}, 0

    for _, ent in ipairs( ents.FindInSphere( ghost:GetPos(), radio ) ) do
        if not IsValid( ent ) then continue end
        if not DOOR_CLASSES[ ent:GetClass() ] then continue end

        -- ANTES de tocar nada.
        if ( st.doorHasta[ ent ] or 0 ) > now then enCuarentena = enCuarentena + 1 continue end

        candidatos[ #candidatos + 1 ] = ent

    end

    if #candidatos <= 0 then
        return false, "no habia puertas a " .. math.Round( radio ) .. " u ( " ..
            enCuarentena .. " en cuarentena )"

    end

    local door = elegir( candidatos )

    -- La tabla se poda aca y no en un timer: sin poda es una fuga de referencias
    -- a entidades muertas que crece con la partida.
    for ent, hasta in pairs( st.doorHasta ) do
        if not IsValid( ent ) or hasta < now - DOOR_COOLDOWN then st.doorHasta[ ent ] = nil end

    end

    if not isfunction( ghost.Use2 ) then
        return false, "la base no expone Use2 ( server_doors.lua depende de el; no se improvisa un Fire )"

    end

    ---------------------------------------------------------------------------
    -- ⚠⚠ MEDIR EL DESTINO, PORQUE Use2 TIENE CINCO SALIDAS SILENCIOSAS
    ---------------------------------------------------------------------------
    -- La primera version llamaba Use2 y devolvia `true` sin mas. Pero Use2 de la
    -- base ( shared.lua:1200-1250 ) se va sin hacer nada, sin avisar, por CINCO
    -- caminos distintos -- se leyeron los cinco:
    --
    --   :1204  if not self.CanUseStuff then return end
    --   :1207  if toUse.GetDriver then return end        ( por PRESENCIA de un campo )
    --   :1210  if useClassBlacklist[ class ] then return end   ( se llena sola )
    --   :1221  local block = hook.Run( "TerminatorBlockUse", self, toUse )
    --   :1222  if block then return end
    --
    -- Y el cuarto lo tenemos NOSOTROS: server_doors.lua:566-578 devuelve true
    -- cuando phantom_CanOpenDoors() dice que no. O sea que con
    -- `phantasmagoria_ghost_opendoors 0` -- una convar real, un control
    -- documentado -- el evento sonaba la manija, no movia la hoja, y el
    -- instrumento imprimia "OK -- puerta prop_door_rotating #123". Verde exacto
    -- sobre cero comportamiento.
    --
    -- Enumerar las cinco salidas seria frágil ( la segunda se activa porque un
    -- tercero AGREGUE un campo ). Lo que no envejece es medir la hoja: se lee su
    -- estado antes, se llama, y se vuelve a leer un tick despues.
    local function leerEstado( d )
        if not IsValid( d ) then return nil end

        -- Los enums estan INVERTIDOS entre las dos familias, y eso ya esta
        -- medido en server_doors.lua:238-264: prop_door_rotating usa
        -- m_eDoorState ( 0 cerrada ) y func_door* usa m_toggle_state, donde
        -- 0 es ABIERTA. Por eso se devuelve el crudo y se compara contra si
        -- mismo, en vez de traducirlo a un booleano que se puede invertir.
        local clase = d:GetClass()

        if clase == "prop_door_rotating" then return d:GetInternalVariable( "m_eDoorState" ) end

        return d:GetInternalVariable( "m_toggle_state" )

    end

    local estadoAntes = leerEstado( door )

    -- El sonido de manija va ANTES del Use2, y no es cosmetico: el Use2 de la
    -- base emite su propio click ( shared.lua:1238 ) y le aplica un empujon al
    -- physobj ( :1243 ). Poner el nuestro antes deja los dos audibles en el
    -- orden en que ocurren -- manija, despues hoja.
    local snd = elegir( SND.door )
    if snd then sound.Play( snd, door:WorldSpaceCenter(), 70, math.random( 95, 105 ) ) end

    ghost:Use2( door )

    -- ⚠ LA CUARENTENA SE ESCRIBE ACA Y NO ANTES DE ELEGIR. En la primera version
    -- se escribia nueve lineas mas arriba, o sea que una puerta que NO se llego a
    -- tocar quedaba quemada 45 s igual: con opendoors en 0, a los pocos eventos
    -- el detalle pasaba a ser "no habia puertas ( 5 en cuarentena )", que se lee
    -- como un mapa sin puertas. Un debounce que castiga intentos fallidos
    -- fabrica la escasez que despues reporta.
    st.doorHasta[ door ] = now + DOOR_COOLDOWN

    local dist = math.Round( ghost:GetPos():Distance( door:WorldSpaceCenter() ) )

    -- El estado de una puerta cambia en el siguiente tick, no en este, asi que
    -- el veredicto llega diferido. La bitacora lo recibe cuando existe; el
    -- retorno de aca es "se intento", que es lo unico cierto en este frame.
    timer.Simple( 0.25, function()
        if not IsValid( door ) then return end

        local despues = leerEstado( door )

        if despues == estadoAntes then
            anotar( string.format( "#%s door SIN EFECTO -- %s #%d no cambio de estado ( %s ). " ..
                "Use2 tiene cinco salidas silenciosas; la mas probable es " ..
                "phantasmagoria_ghost_opendoors en 0 o el veto TerminatorBlockUse",
                IsValid( ghost ) and ghost:EntIndex() or "?", door:GetClass(), door:EntIndex(),
                tostring( despues ) ) )

        else
            anotar( string.format( "#%s door efecto CONFIRMADO -- %s #%d  estado %s -> %s",
                IsValid( ghost ) and ghost:EntIndex() or "?", door:GetClass(), door:EntIndex(),
                tostring( estadoAntes ), tostring( despues ) ) )

        end
    end )

    return true, "puerta " .. door:GetClass() .. " #" .. door:EntIndex() .. " a " .. dist ..
        " u -- INTENTADA ( estado " .. tostring( estadoAntes ) ..
        "; el efecto se confirma en la bitacora a los 0,25 s )"

end

---------------------------------------------------------------------------
-- light -- el parpadeo, y el evento con MAS riesgo de dar un verde vacio
---------------------------------------------------------------------------
-- ⚠⚠ LEER ESTO ANTES DE JUZGAR UN ROJO DE ESTA CATEGORIA.
--
-- gmpa hace `ents.FindByClass( "light" )` ( :570, :618 ) y son los DOS UNICOS
-- sitios en todo el taller -- sesenta y dos addons desempacados -- que buscan
-- esa clase. Nadie mas lo hace, y hay un motivo fuerte: **las luces estaticas
-- se hornean en el lightmap al compilar el mapa y NO EXISTEN como entidad en
-- runtime.** Lo que sobrevive son las que tienen targetname, justamente para
-- que un input las pueda tocar.
--
-- La evidencia es indirecta y se declara como tal ( no hay un .bsp ni GMod
-- alcanzable desde esta maquina para contarlas ):
--
--   · StormFox 2, cuyo tema ENTERO es la luz del mapa, tiene una via aparte y
--     explicita para la luz horneada -- `engine.LightStyle` + un net al cliente
--     que hace `render.RedownloadAllLightmaps` ( sh_maplight.lua:34-53, :79-88 ).
--     Si las baked fueran entidades, esa API global no haria falta.
--   · Su propio comentario dice `-- light_environment (SV) Fast, but not all
--     maps have it` ( :104 ): la via por entidad NO SIEMPRE EXISTE.
--   · NEAD, un addon cuyo tema es "¿el jugador esta iluminado?", censa SOLO
--     gmod_lamp y env_projectedtexture. Nunca `light`. Es el negativo mas caro
--     del arbol.
--
-- Por eso esta categoria busca en CINCO familias y no en una, y por eso cuando
-- no encuentra nada lo DICE con el conteo por familia. *Un evento de luces que
-- no encuentra luces no es un fallo del evento: es un dato sobre el mapa*, y la
-- unica forma de no confundirlos es que el instrumento imprima cual de los dos
-- fue.
--
-- El orden va de lo mas probable en sandbox a lo mas probable en un mapa de
-- horror hecho a mano.
local function lucesCerca( ghost, radio )
    local halladas, censo = {}, {}

    local function sumar( clase, ent, como )
        censo[ clase ] = ( censo[ clase ] or 0 ) + 1
        halladas[ #halladas + 1 ] = { ent = ent, como = como, clase = clase }

    end

    for _, ent in ipairs( ents.FindInSphere( ghost:GetPos(), radio ) ) do
        if not IsValid( ent ) then continue end

        local clase = ent:GetClass()

        -- ( 1 ) Las lamparas de sandbox. Son SENTs de Lua con getter y setter
        -- propios, y son las mas probables en un servidor de GMod porque las
        -- pone el jugador. HIM las trata igual ( server.lua:494-495 ).
        if clase == "gmod_light" or clase == "gmod_lamp" then
            if isfunction( ent.SetOn ) and isfunction( ent.GetOn ) then
                sumar( clase, ent, "seton" )

            end

        -- ( 2 ) Las del mapa que sobrevivieron. `Toggle` para las dos.
        elseif clase == "light" or clase == "light_spot" then
            sumar( clase, ent, "toggle" )

        -- ( 3 ) ⚠ Esta NO responde a `Toggle`: su input se llama `LightToggle`.
        -- Es una asimetria del engine y HIM la trata aparte ( server.lua:500 ).
        elseif clase == "point_spotlight" then
            sumar( clase, ent, "lighttoggle" )

        -- ( 4 ) Las dinamicas y los proyectores, que si o si existen en runtime
        -- porque no se pueden hornear.
        elseif clase == "light_dynamic" or clase == "env_projectedtexture" then
            sumar( clase, ent, "onoff" )

        end
    end

    return halladas, censo

end

EV.light = function( ghost, radio, _fuerza, _cuantos, dir )
    local halladas, censo = lucesCerca( ghost, radio )

    if #halladas <= 0 then
        -- El vacio MEDIDO, no el vacio silencioso. Ver el bloque de arriba.
        return false, "no habia luces alcanzables a " .. math.Round( radio ) .. " u " ..
            "( se buscaron gmod_light, gmod_lamp, light, light_spot, point_spotlight, " ..
            "light_dynamic y env_projectedtexture -- las estaticas horneadas NO son entidades )"

    end

    local L = elegir( halladas )

    -- El signo del tipo. dir = -1 significa "este tipo solo APAGA" ( Mare,
    -- Onryo, Hantu ), +1 "solo enciende" ( Jinn ), 0 las dos. Con un peso
    -- escalar Mare y Jinn serian el mismo tipo -- es el hallazgo que justifica
    -- el campo entero.
    local soloApaga    = dir == -1
    local soloEnciende = dir == 1

    ---------------------------------------------------------------------------
    -- ⚠ LEER EL ESTADO ANTES DE TOCAR, CUANDO SE PUEDE
    ---------------------------------------------------------------------------
    -- Solo una de las cinco familias tiene getter: los gmod_light / gmod_lamp,
    -- que son SENTs de Lua. El censo YA lo exige ( `isfunction( ent.GetOn )` ),
    -- asi que el dato estaba disponible y la primera version no lo miraba.
    --
    -- Y no mirarlo tenia un modo de falla exacto y verde: una lampara YA
    -- APAGADA -- por el jugador, o por un estallido anterior de este mismo motor,
    -- que las deja apagadas a proposito -- recibia tres `SetOn( false )`, sonaba
    -- el interruptor, y el reporte devolvia "3 conmutacion(es)" con **cero
    -- cambio visible**. Justo en la categoria cuyo encabezado promete que el
    -- vacio se va a poder distinguir del evento.
    --
    -- El precedente que este bloque copia lo consulta como PRIMERA linea:
    -- HIM, terminator_nextbot_homeless/server.lua:355, `if not ent:GetOn() then
    -- return end`. Se leyo el mecanismo y se salteo su guarda.
    local antes

    if L.como == "seton" then antes = L.ent:GetOn() end

    -- Un tipo que SOLO APAGA sobre una lampara que ya esta apagada no tiene
    -- nada que hacer, y decirlo es mejor que fingir. Lo mismo al reves.
    if antes ~= nil then
        if soloApaga and not antes then
            return false, L.clase .. " #" .. L.ent:EntIndex() .. " ya estaba APAGADA y el tipo solo apaga"

        end

        if soloEnciende and antes then
            return false, L.clase .. " #" .. L.ent:EntIndex() .. " ya estaba ENCENDIDA y el tipo solo enciende"

        end
    end

    -- ⚠ point_spotlight NO PUEDE OBEDECER UN SIGNO. Su unico input es
    -- `LightToggle` ( HIM lo despacha aparte por eso mismo, server.lua:500 ):
    -- conmuta, no acepta un estado. La primera version le mandaba `TurnOff` en
    -- la rama del estallido -- un input que la clase no tiene -- y en la del
    -- parpadeo le mandaba `LightToggle` DESCARTANDO el estado calculado, con lo
    -- que un Mare podia terminar ENCENDIENDO un foco mientras el reporte decia
    -- "( el tipo SOLO apaga )".
    --
    -- No se improvisa: si el tipo tiene signo y la luz no lo puede obedecer, se
    -- busca otra o se dice que no habia.
    if L.como == "lighttoggle" and dir ~= 0 then
        local otras = {}

        for _, cand in ipairs( halladas ) do
            if cand.como ~= "lighttoggle" then otras[ #otras + 1 ] = cand end

        end

        if #otras <= 0 then
            return false, "las " .. #halladas .. " luz(ces) cercanas son point_spotlight, que solo " ..
                "entiende LightToggle ( conmuta, no acepta un estado ), y este tipo tiene signo " ..
                ( soloApaga and "-1 ( solo apaga )" or "+1 ( solo enciende )" )

        end

        L = elegir( otras )
        if L.como == "seton" then antes = L.ent:GetOn() else antes = nil end

    end

    -- EL ESTALLIDO. La fuente lo nombra: Mare "Prefers turning off lights AND
    -- LIGHT BURSTING EVENTS" ( ghost_types.lua:268 ), o sea que romper la
    -- bombilla es un evento propio y no una variante del parpadeo. Por eso
    -- tiene su clip aparte ( SND.bulb ) y su rama.
    --
    -- ⚠ "ROMPER" ACA ES AUDIBLE Y VISUAL, NO ESTRUCTURAL: la luz queda APAGADA
    -- y nada mas. NO se le dispara `Break` ni `TakeDamage` como hace gmpa
    -- ( :574-575 ) -- y no es timidez, es que un evento aleatorio no tiene
    -- derecho a dejar un cambio permanente en el mapa de otro. Una luz apagada
    -- la vuelve a encender el proximo evento; una luz destruida no vuelve nunca
    -- y el jugador no tiene forma de saber que fue el fantasma.
    --
    -- El sesgo por tipo sale del signo: un tipo que SOLO APAGA es justo el que
    -- la fuente describe reventando bombillas.
    --
    -- ⚠ Y UN TIPO QUE SOLO ENCIENDE NO ESTALLA NUNCA. La primera version no
    -- consultaba `soloEnciende` aca -- estaba declarado dos lineas arriba y no
    -- se volvia a leer --, asi que el Jinn, cuyo unico rasgo en la fuente es
    -- *"cannot directly turn OFF"*, apagaba una luz el 10 % de las veces. O sea
    -- que el estallido COLAPSABA a Mare y a Jinn, que es exactamente lo que
    -- `dir` existe para impedir: el campo funcionaba en el parpadeo y la rama de
    -- al lado lo ignoraba.
    local estalla = ( not soloEnciende ) and math.random( 1, 100 ) <= ( soloApaga and 30 or 10 )

    if estalla then
        local snd = elegir( SND.bulb )
        if snd then sound.Play( snd, L.ent:GetPos(), 78, math.random( 96, 106 ) ) end

        -- `Sparks` es del engine y esta siempre montado. ⚠ Y PIDE MAS QUE EL
        -- ORIGEN: los CUATRO usos del arbol -- terminator_doorbash.lua:98-103,
        -- overcharging.lua:95-101, manhack_welder_term.lua:58-64 y
        -- weapon_terminatorfists_term.lua:57-63 -- setean ademas Magnitude,
        -- Scale y Radius, sin excepcion. La primera version pasaba solo el
        -- origen, que es una firma SIN PRECEDENTE en las cuatro que hay.
        -- Si con magnitud cero se dibuja algo o no, no se pudo medir desde
        -- disco; se copia la forma de los cuatro en vez de apostar.
        local ef = EffectData()
        ef:SetOrigin( L.ent:GetPos() )
        ef:SetMagnitude( 2 )
        ef:SetScale( 1 )
        ef:SetRadius( 4 )
        util.Effect( "Sparks", ef )

        timer.Simple( 0.05, function()
            if not IsValid( L.ent ) then return end

            if L.como == "seton" then L.ent:SetOn( false )

            -- point_spotlight solo conmuta, asi que "apagar" es un toggle y
            -- solo apaga si estaba encendido. No se puede garantizar el estado
            -- final; el detalle de abajo lo dice.
            elseif L.como == "lighttoggle" then L.ent:Fire( "LightToggle", "", 0 )

            else L.ent:Fire( "TurnOff", "", 0 ) end

        end )

        return true, "ESTALLIDO sobre " .. L.clase .. " #" .. L.ent:EntIndex() ..
            ( L.como == "lighttoggle" and " ( conmutada: point_spotlight no acepta un estado )"
              or " ( queda apagada, NO destruida )" ) ..
            ( soloApaga and "  ( el tipo SOLO apaga: 30% de estallido )" or "  ( 10% de estallido )" )

    end

    ---------------------------------------------------------------------------
    -- EL PARPADEO
    ---------------------------------------------------------------------------
    -- DOS a CINCO conmutaciones con delay, que es la forma de HIM
    -- ( server.lua:373-380 ). gmpa arma ~90 timers anidados por evento
    -- ( :621-632 ) para el mismo efecto visual.
    --
    -- ⚠⚠ EL SIGNO SE APLICA AL ESTADO FINAL, NO A CADA PASO, Y LA PRIMERA
    -- VERSION LO TENIA AL REVES. Forzaba `encender` adentro de CADA timer, asi
    -- que un tipo con signo hacia N veces la MISMA conmutacion: Mare mandaba
    -- tres `TurnOff` seguidos y Jinn tres `TurnOn`. O sea que **los dos tipos de
    -- luces del juego eran justo los dos que no parpadeaban**, y el reporte
    -- imprimia "3 conmutacion(es)" al lado de una luz que no hizo nada.
    --
    -- Un parpadeo pasa por los dos estados POR DEFINICION -- eso es parpadear.
    -- Lo que el signo restringe es donde TERMINA. Con `encender = ( i % 2 == 0 )`
    -- el ultimo paso da encendido si `pasos` es par, asi que la PARIDAD es la
    -- perilla: se elige el final y se ajusta la paridad para llegar.
    local final

    if soloApaga then final = false
    elseif soloEnciende then final = true
    -- Sin signo: termina en el OPUESTO de donde estaba, para que el evento se
    -- vea. Si la familia no tiene getter no hay como saberlo y se sortea.
    elseif antes ~= nil then final = not antes
    else final = math.random( 1, 2 ) == 1 end

    local pasos = math.random( 2, 5 )

    if ( pasos % 2 == 0 ) ~= final then pasos = pasos + 1 end

    for i = 1, pasos do
        timer.Simple( ( i - 1 ) * math.Rand( 0.08, 0.22 ), function()
            if not IsValid( ghost ) or not IsValid( L.ent ) then return end

            local encender = ( i % 2 == 0 )

            if L.como == "seton" then
                L.ent:SetOn( encender )

            elseif L.como == "lighttoggle" then
                -- Sin estado: conmuta y ya. Solo llega aca con dir == 0, porque
                -- el bloque de arriba lo saca de la eleccion si el tipo tiene
                -- signo.
                L.ent:Fire( "LightToggle", "", 0 )

            else
                -- `toggle` ( light, light_spot ) y `onoff` ( light_dynamic,
                -- env_projectedtexture ) comparten TurnOn / TurnOff.
                L.ent:Fire( encender and "TurnOn" or "TurnOff", "", 0 )

            end
        end )
    end

    local snd = elegir( SND.switch )
    if snd then sound.Play( snd, L.ent:GetPos(), 72, math.random( 92, 108 ) ) end

    local resumen = {}
    for clase, n in pairs( censo ) do resumen[ #resumen + 1 ] = clase .. " x" .. n end

    -- El detalle dice ANTES -> DESPUES cuando se puede leer, y "sin getter"
    -- cuando no. Un "3 conmutaciones" a secas no distingue una luz que parpadeo
    -- de una a la que le mandamos tres inputs que no hicieron nada.
    local transicion = ( antes == nil ) and "estado sin getter en esta clase"
        or ( ( antes and "encendida" or "apagada" ) .. " -> " .. ( final and "encendida" or "apagada" ) )

    return true, pasos .. " conmutacion(es) sobre " .. L.clase .. " #" .. L.ent:EntIndex() ..
        " ( " .. transicion .. " )  [ " .. table.concat( resumen, ", " ) .. " ]" ..
        ( soloApaga and "  ( el tipo SOLO apaga )" or soloEnciende and "  ( el tipo SOLO enciende )" or "" )

end

---------------------------------------------------------------------------
-- sound -- la voz paranormal
---------------------------------------------------------------------------
-- ⚠ NUNCA EN LA POSICION DEL FANTASMA. Ver el contrato comun de arriba: seria
-- un localizador gratis que mata al spirit box, a la parabolica y a la caja
-- musical de un saque.
EV.sound = function( ghost, radio, _fuerza, _cuantos, _dir, flags )
    local voz   = ghost:phantom_EventVoice()
    local bancos = VOZ[ voz ]

    if not bancos then return false, "la voz " .. tostring( voz ) .. " no tiene bancos" end

    local key = sortearPeso( flags.soundBanks or {}, { "voice", "breath", "humming" } )
    if not key then return false, "los tres soundBanks del tipo estan en cero" end

    local snd = elegir( bancos[ key ] )
    if not snd then return false, "el banco '" .. key .. "' de la voz " .. voz .. " esta vacio" end

    -- puntoCerca nunca devuelve nil ( contrato declarado en su cuerpo ).
    local pos, comoSalio = puntoCerca( ghost, radio, true )

    sound.Play( snd, pos, 70, math.random( 96, 104 ) )

    return true, "voz " .. voz .. " / banco " .. key .. " a " ..
        math.Round( ghost:GetPos():Distance( pos ) ) .. " u  ( " .. comoSalio .. " )"

end

---------------------------------------------------------------------------
-- prop -- un trasto de la casa que suena solo
---------------------------------------------------------------------------
EV.prop = function( ghost, radio )
    -- puntoCerca nunca devuelve nil ( contrato declarado en su cuerpo ).
    local pos, comoSalio = puntoCerca( ghost, radio, false )

    local snd = elegir( SND.prop )
    if not snd then return false, "el banco prop/ esta vacio" end

    sound.Play( snd, pos, 75, math.random( 97, 103 ) )

    -- La guarda del `or snd`: hoy las 20 entradas de SND.prop terminan en .ogg y
    -- llevan barra, asi que el match siempre resuelve -- pero una ruta nueva sin
    -- extension devolveria nil y la concatenacion tiraria error EN EL EVENTO, no
    -- al cargar. Un banco de sonido es justo el lugar donde alguien pega una
    -- ruta a mano.
    return true, ( string.match( snd, "([^/]+)%.ogg$" ) or snd ) .. " a " ..
        math.Round( ghost:GetPos():Distance( pos ) ) .. " u"

end

---------------------------------------------------------------------------
-- furniture -- el armario que se abre solo
---------------------------------------------------------------------------
EV.furniture = function( ghost, radio )
    -- puntoCerca nunca devuelve nil ( contrato declarado en su cuerpo ).
    local pos, comoSalio = puntoCerca( ghost, radio, true )

    local snd = elegir( SND.furniture )
    if not snd then return false, "el banco furniture/ esta vacio" end

    sound.Play( snd, pos, 72, math.random( 95, 105 ) )

    return true, "mueble a " .. math.Round( ghost:GetPos():Distance( pos ) ) .. " u  ( " .. comoSalio .. " )"

end

---------------------------------------------------------------------------
-- EL DESPACHADOR
---------------------------------------------------------------------------
-- Dispara UN evento de UNA categoria, `count` veces. Devuelve cuantos salieron.
--
-- `forzada` existe para el comando de disparo manual: sin el, medir una
-- categoria dependeria de que el sorteo la favorezca, y *un check que depende de
-- un sorteo no es un check* ( PLANTILLA_CHECKS.md, punto 4 ).
function ENT:phantom_FireEvent( forzada )
    local st    = estado( self )
    local flags = self:phantom_EventFlags()
    local cazando = self.phantom_Hunting == true

    -- Los multiplicadores del hunt. ⚠ ESTA CONVAR TIENE **DOS** ESTADOS Y NO
    -- TRES, a diferencia de las ocho de categoria, y la primera version declaro
    -- tres: 0 control · 1 el rasgo decide · 2 "forzado".
    --
    -- El 2 era mentira, y de la peor clase: producia EXACTAMENTE el mismo
    -- resultado que el 1 -- las dos ramas terminaban en `h = flags.hunt` -- y el
    -- reporte imprimia "( forzado )" al lado. O sea que una fila de planilla que
    -- pusiera `evhunt 2` para forzar habria medido lo mismo que con 1, con el
    -- instrumento confirmandole por escrito que estaba en el otro estado.
    -- Familia "tres estados con dos cuentas" del catalogo del taller.
    --
    -- Y el motivo de fondo es estructural, no un descuido: el 2 de las otras
    -- convars significa "ignora el flag del NPC", y el hunt NO TIENE flag por
    -- NPC -- se modula por los rasgos del tipo, que son datos y no una perilla.
    -- No hay nada que ignorar. *Copiar una convencion sin el mecanismo que la
    -- sostiene deja un estado que no se puede distinguir de su vecino.*
    local modo = cvHunt:GetInt()
    local mulCount, mulBurst, mulStr, mulRad = 1, 1, 1, 1

    if cazando then
        if modo == 0 and not forzada then
            st.motivos.hunt = "phantasmagoria_ghost_evhunt esta en 0 ( control: en el hunt no hay eventos )"
            return 0, st.motivos.hunt

        end

        local h = flags.hunt or NEUTRO.hunt

        mulCount = h.count    or 1
        mulBurst = h.burst    or 1
        mulStr   = h.strength or 1
        mulRad   = h.radius   or 1

    end

    local radioBase = cvRadius:GetFloat() * mulRad
    local fuerza    = ( flags.strength or 1 ) * mulStr

    -- ⚠ DOS EJES QUE **NO SE COMPONEN**, y en la primera version eran uno solo
    -- leido en dos lugares, o sea que se multiplicaba consigo mismo.
    --   `cuantos`  cuantas CATEGORIAS sortea este disparo   ( The Twins )
    --   `porTiro`  cuantos OBJETOS mueve un solo `throw`    ( el Poltergeist )
    -- Ver el comentario de `burst` en ghost_flags.lua para la cuenta del peor
    -- caso que esto evita ( del orden de 32 props y 32 EmitSound en un frame ).
    local cuantos = math.max( 1, math.floor( ( flags.count or 1 ) * mulCount ) )
    local porTiro = math.max( 1, math.floor( ( flags.burst or 1 ) * mulBurst ) )

    local salieron, ultimoDetalle = 0, nil

    -- EL BUCLE QUE SALVA A THE TWINS Y AL POLTERGEIST CON LA MISMA LINEA.
    -- Con count = 1 y radius = { 1.0 } es identico al comportamiento de los
    -- otros veintinueve tipos: no es una rama nueva, es un bucle de largo uno.
    for i = 1, cuantos do
        local cat

        if forzada then
            cat = forzada

        else
            cat = sortearPeso( flags.weights or {}, CAT_ORDER )

            if not cat then
                st.motivos.sorteo = "todos los pesos del tipo estan en cero"
                break

            end
        end

        local permitido, porque = self:phantom_EventAllowed( cat )

        if not permitido then
            st.motivos[ cat ] = porque
            continue

        end

        -- `radius` es un ARRAY indexado por la iteracion ( regla 3 de
        -- ghost_flags.lua ). The Twins tira la interaccion 1 al radio normal y
        -- la 2 al extendido; un escalar no puede expresar eso.
        local mulThis = ( istable( flags.radius ) and ( flags.radius[ i ] or flags.radius[ 1 ] ) ) or 1
        local radio   = radioBase * mulThis

        local fn = EV[ cat ]
        if not fn then st.motivos[ cat ] = "la categoria no tiene implementacion" continue end

        local ok, detalle = fn( self, radio, fuerza, porTiro,
            ( istable( flags.dir ) and flags.dir[ cat ] ) or 0, flags )

        st.motivos[ cat ] = ( ok and "OK -- " or "sin sujeto -- " ) .. tostring( detalle )

        if ok then
            salieron       = salieron + 1
            ultimoDetalle  = cat .. ": " .. tostring( detalle )
            st.porCat[ cat ] = ( st.porCat[ cat ] or 0 ) + 1
            st.ultimo      = cat
            st.ultimoT     = CurTime()

            anotar( string.format( "#%d %s %s r=%d %s", self:EntIndex(),
                cazando and "HUNT " or "calma", cat, math.Round( radio ), tostring( detalle ) ) )

        else
            anotar( string.format( "#%d %s %s SIN SUJETO -- %s", self:EntIndex(),
                cazando and "HUNT " or "calma", cat, tostring( detalle ) ) )

        end
    end

    if salieron > 0 then st.disparos = st.disparos + 1 end

    return salieron, ultimoDetalle

end

-- Cuando le toca el proximo. Se separa del disparo para que el comando manual
-- pueda disparar SIN mover el reloj: si el disparo forzado reprogramara, medir
-- una categoria a mano cambiaria el ritmo de la partida que se esta midiendo.
function ENT:phantom_ScheduleEvent( primeraVez )
    local st    = estado( self )
    local flags = self:phantom_EventFlags()

    local rate = flags.rate or 1

    if self.phantom_Hunting and cvHunt:GetInt() ~= 0 then
        rate = rate * ( ( flags.hunt and flags.hunt.rate ) or 1 )

    end

    -- Un rate de 0 o negativo apagaria el fantasma para siempre por division.
    -- No es un caso hipotetico: es lo que pasa si alguien escribe rate = 0 en
    -- ghost_flags.lua pensando que apaga los eventos ( lo que apaga una
    -- categoria son los PESOS ). Se clampea y no se divide por cero.
    rate = math.max( rate, 0.05 )

    local lo = math.min( cvMin:GetFloat(), cvMax:GetFloat() )
    local hi = math.max( cvMin:GetFloat(), cvMax:GetFloat() )

    -- La primera vez se acorta a proposito: un fantasma recien spawneado que no
    -- hace nada durante 90 s se lee como un fantasma roto, y el que lo spawneo
    -- esta mirandolo.
    local espera = math.Rand( lo, hi ) / rate
    if primeraVez then espera = math.Rand( 4, 12 ) end

    st.next = CurTime() + espera

    return espera

end

---------------------------------------------------------------------------
-- EL SCHEDULER
---------------------------------------------------------------------------
-- Un solo timer para todos los fantasmas. Ver el encabezado para por que no es
-- un Think.
--
-- ⚠ EL CONTADOR DE VUELTAS NO ES DECORACION. Es lo unico que distingue "el
-- scheduler corrio y ningun evento encontro sujeto" de "el scheduler no corrio".
-- Los dos se ven exactamente igual desde el juego -- silencio -- y son defectos
-- completamente distintos. El comando de reporte lo imprime SIEMPRE.
local TICK = 1

timer.Create( "phantasmagoria_event_scheduler", TICK, 0, function()
    if not cvMaster:GetBool() then return end

    local each = PHANTASMAGORIA.EachGhost
    if not isfunction( each ) then return end

    local now = CurTime()

    each( function( ghost )
        -- Solo los que tienen el motor. Un fantasma de otra clase que declare
        -- IsPhantasmagoriaGhost sin incluir este archivo no tiene el metodo, y
        -- llamarlo seria un error por tick.
        if not isfunction( ghost.phantom_FireEvent ) then return end

        local st = estado( ghost )
        st.vueltas = st.vueltas + 1

        if st.next <= 0 then
            ghost:phantom_ScheduleEvent( true )
            return

        end

        if now < st.next then return end

        ghost:phantom_FireEvent( nil )
        ghost:phantom_ScheduleEvent( false )

    end )
end )

---------------------------------------------------------------------------
-- INSTRUMENTO: el reporte
---------------------------------------------------------------------------
local function adminOnly( ply )
    if not IsValid( ply ) then return true end -- consola del servidor
    if ply:IsAdmin() then return true end

    ply:PrintMessage( HUD_PRINTCONSOLE, "[Phantasmagoria] hace falta ser admin." )
    return false

end

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_events", function( ply, _, args )
    if not adminOnly( ply ) then return end

    local say = PHANTASMAGORIA.MakeSay( ply )
    local sub = args and args[ 1 ]

    if sub == "reset" then
        PHANTASMAGORIA.EventLog = {}

        local n = PHANTASMAGORIA.EachGhost( function( ghost )
            ghost.phantom_ev = nil

        end )

        say( "[Phantasmagoria] bitacora y contadores borrados en " .. n .. " fantasma(s)." )
        return

    end

    say( "" )
    say( "===== EVENTOS PARANORMALES ( Diseno 21 ) =====" )
    say( "  maestro     phantasmagoria_ghost_paranormal = " .. cvMaster:GetInt() ..
        ( cvMaster:GetBool() and "  ( encendido )" or "  ⚠ APAGADO: el scheduler no corre" ) )
    say( "  radio base  " .. math.Round( cvRadius:GetFloat() ) .. " u   ( alrededor del FANTASMA, no del jugador )" )
    say( "  intervalo   " .. math.Round( cvMin:GetFloat() ) .. " a " .. math.Round( cvMax:GetFloat() ) ..
        " s, dividido por el `rate` del tipo" )
    say( "  masa tope   " .. math.Round( cvMass:GetFloat() ) .. " kg" )
    say( "  en el hunt  phantasmagoria_ghost_evhunt = " .. cvHunt:GetInt() ..
        ( cvHunt:GetInt() == 0 and "  ( CONTROL: cazando no hay eventos )"
          or "  ( los multiplicadores `hunt` del tipo deciden )" ) )

    say( "" )
    say( "  categorias  ( convar · rasgo del tipo se ve en la ficha de cada fantasma )" )
    -- ⚠ EL MOTIVO QUE IMPRIME ResolveFlag NOMBRA EL COMANDO EQUIVOCADO PARA
    -- ESTAS OCHO. Su string esta hardcodeado en server_doors.lua:488 y dice
    -- "( phantasmagoria_ghost_flag )", que es el andamio de los SEIS flags de
    -- server.lua -- y su tabla FLAGS no tiene ninguna categoria de evento. O sea
    -- que el reporte le dice al operador que tipee un comando que sobre estas
    -- ocho no borra nada y no avisa. Se aclara aca en vez de tocar
    -- server_doors.lua, que es de otro bloque y de otra sesion.
    say( "  ⚠ si un motivo dice 'el override de consola ( phantasmagoria_ghost_flag )', para ESTAS ocho" )
    say( "    el comando es phantasmagoria_ghost_evflag. El otro no las conoce y no lo dice." )

    for _, key in ipairs( CAT_ORDER ) do
        local c = CATS[ key ]
        say( "    " .. key .. string.rep( " ", 11 - #key ) .. c.cv:GetInt() ..
            "  " .. c.cv:GetName() .. "   ( " .. c.que .. " )" )

    end

    local vivos = PHANTASMAGORIA.EachGhost( function( ghost )
        -- ⚠ LA GUARDA QUE EL SCHEDULER Y EL DISPARO FORZADO TIENEN Y ESTE NO
        -- TENIA. Sin ella, un fantasma que declare IsPhantasmagoriaGhost sin
        -- descender de esta clase no tiene phantom_EventFlags, la llamada de
        -- abajo tira `attempt to call a nil value`, y como eachGhost no envuelve
        -- en pcall el reporte ENTERO muere a mitad de salida. O sea: el unico
        -- comando que existe para diagnosticar ese caso era el que se rompia en
        -- ese caso.
        if not isfunction( ghost.phantom_EventFlags ) then
            say( "" )
            say( "  --- fantasma #" .. ghost:EntIndex() .. "  ( " .. ghost:GetClass() .. " ) ---" )
            say( "    ⚠ NO TIENE EL MOTOR: declara IsPhantasmagoriaGhost pero no desciende de" )
            say( "      terminator_nextbot_phantom, asi que server_events.lua nunca corrio para el." )
            return

        end

        local st    = estado( ghost )
        local flags, deDonde = ghost:phantom_EventFlags()

        say( "" )
        say( "  --- fantasma #" .. ghost:EntIndex() .. "  ( " ..
            ( ghost.phantom_Hunting and "HUNT" or "calma" ) .. " ) ---" )
        say( "    rasgos    " .. deDonde )

        -- ⚠ SE IMPRIMEN LOS DOS: el RASGO ( lo que el tipo pide ) y el VALOR
        -- RESUELTO ( lo que se sorteo ). La voz solo se sortea en el primer
        -- evento de sonido, asi que un check de "la Banshee es femenina"
        -- corrido antes de eso leia "sin sortear" sobre una Banshee correcta y
        -- se anotaba como un rojo.
        local vozRasgo = flags.voice or 0
        say( "    voz       rasgo " .. ( vozRasgo == 0 and "0 ( se sortea )" or
            ( vozRasgo .. ( vozRasgo == 1 and " ( fija: femenina )" or " ( fija: grave )" ) ) ) ..
            "   resuelta " .. ( ghost.phantom_evVoice and
                ( ghost.phantom_evVoice .. ( ghost.phantom_evVoice == 1 and " ( femenina )" or " ( grave )" ) )
                or "SIN SORTEAR ( se sortea en el primer evento de sonido )" ) )

        -- ⚠ ESTAS DOS LINEAS SON LA ACREDITACION DEL SCHEDULER. Sin ellas, "no
        -- pasa nada" no distingue un motor apagado de un motor que corre y no
        -- encuentra sujetos.
        say( "    vueltas   " .. st.vueltas .. " del scheduler  ( a " .. TICK ..
            " Hz; si dice 0, el timer NO esta corriendo )" )
        -- ⚠ ESTE NUMERO Y EL `disparos` DE CADA CATEGORIA SON DOS CUENTAS
        -- DISTINTAS, y hasta la revision se llamaban igual. Este cuenta
        -- DESPERTADAS con al menos un exito; el de abajo cuenta EVENTOS por
        -- categoria. Con `count` > 1 -- o sea Poltergeist y The Twins, justo los
        -- dos tipos que este bloque existe para lucir -- divergen, y la suma de
        -- las ocho columnas puede ser mayor que este. En los otros 28 coinciden,
        -- que es lo que hace el defecto dificil de ver.
        say( "    despertadas con al menos un evento: " .. st.disparos .. "   ultimo: " ..
            ( st.ultimo and ( st.ultimo .. " hace " .. math.Round( CurTime() - st.ultimoT ) .. " s" )
              or "ninguno todavia" ) )

        local falta = st.next - CurTime()
        say( "    proximo   " .. ( st.next <= 0 and "sin programar" or
            ( falta > 0 and ( "en " .. math.Round( falta ) .. " s" ) or "YA ( vencido )" ) ) )

        say( "    rasgos:   rate x" .. string.format( "%.2f", flags.rate or 1 ) ..
            "  count " .. tostring( flags.count or 1 ) .. " ( categorias a la vez )" ..
            "  burst " .. tostring( flags.burst or 1 ) .. " ( objetos por tirada )" ..
            "  strength x" .. string.format( "%.2f", flags.strength or 1 ) ..
            "  radius " .. table.concat( flags.radius or { 1 }, "/" ) )

        if flags.hunt then
            say( "    en hunt:  rate x" .. string.format( "%.2f", flags.hunt.rate or 1 ) ..
                "  count x" .. tostring( flags.hunt.count or 1 ) ..
                "  burst x" .. tostring( flags.hunt.burst or 1 ) ..
                "  strength x" .. string.format( "%.2f", flags.hunt.strength or 1 ) ..
                "  radius x" .. string.format( "%.2f", flags.hunt.radius or 1 ) )

        end

        -- ⚠ `dir` Y `soundBanks` NO SALIAN EN NINGUNA SALIDA DE LOS TRES
        -- COMANDOS, y `dir` es el campo que ghost_flags.lua llama "el hallazgo
        -- mas fuerte del corte": es lo UNICO que separa a Mare de Jinn. Un rasgo
        -- que el instrumento no muestra no se puede auditar en juego, y su check
        -- se contesta mirando el .lua -- que es exactamente lo que una corrida en
        -- juego existe para no tener que hacer.
        local dirL = flags.dir and flags.dir.light or 0
        say( "    signo:    dir.light " .. dirL ..
            ( dirL == -1 and "  ( SOLO apaga -- Mare, Onryo, Hantu )" or
              dirL == 1 and "  ( SOLO enciende -- Jinn )" or "  ( las dos )" ) )

        local sb = flags.soundBanks or {}
        say( "    voces:    voice " .. tostring( sb.voice or 1 ) ..
            "  breath " .. tostring( sb.breath or 1 ) ..
            "  humming " .. tostring( sb.humming or 1 ) .. "   ( pesos del banco de sonido )" )

        for _, key in ipairs( CAT_ORDER ) do
            local w    = ( flags.weights or {} )[ key ]
            local hubo = st.porCat[ key ] or 0
            local why  = st.motivos[ key ]
            local ov   = PHANTASMAGORIA.FlagOverrides[ CATS[ key ].campo ]

            -- El override de consola SOBREVIVE AL RESPAWN y gana sobre el campo
            -- del NPC, y no aparecia en ningun lado del reporte: la unica pista
            -- era la linea `ultimo:`, que solo existe si esa categoria salio
            -- sorteada alguna vez. Un override puesto y olvidado se leia como
            -- "esa categoria no funciona".
            say( "      " .. key .. string.rep( " ", 11 - #key ) ..
                "peso " .. string.format( "%-5s", tostring( w ) ) ..
                ( ov == nil and "" or ( ov and "[OVERRIDE 1] " or "[OVERRIDE 0] " ) ) ..
                " eventos " .. string.format( "%-4d", hubo ) ..
                ( why and ( " ultimo: " .. why ) or " ( sin intentar todavia )" ) )

        end

        -- Los dos motivos que NO son de categoria y que antes se escribian en la
        -- misma tabla sin que ningun lector los alcanzara: los dos lectores
        -- recorren CAT_ORDER, y ni "hunt" ni "sorteo" estan ahi.
        if st.motivos.hunt then say( "      ( puerta del hunt ) " .. st.motivos.hunt ) end
        if st.motivos.sorteo then say( "      ( sorteo )         " .. st.motivos.sorteo ) end

    end )

    if vivos <= 0 then
        say( "" )
        say( "  ⚠ NO HAY NINGUN FANTASMA VIVO. Las lineas de arriba son la configuracion global;" )
        say( "    los contadores son POR FANTASMA y no existe ninguno que contar." )

    end

    local log = PHANTASMAGORIA.EventLog

    say( "" )
    say( "  bitacora ( " .. #log .. " / " .. BITACORA_MAX .. " ) -- lo que un comando en vivo ya no alcanza a ver:" )

    if #log <= 0 then
        say( "    vacia.  Si ademas 'vueltas' dice 0, el defecto es el scheduler y no los eventos." )

    else
        for i = 1, #log do say( "    " .. log[ i ] ) end

    end

    say( "" )

end, "Reporte del motor de eventos paranormales. 'reset' borra bitacora y contadores." )

---------------------------------------------------------------------------
-- INSTRUMENTO: el disparo forzado
---------------------------------------------------------------------------
-- ⚠ SIN ESTO LA PLANILLA NO SE PUEDE CORRER. Cada categoria depende de un
-- sorteo de pesos y de un intervalo de 25-90 s; medir "el fantasma tira cosas"
-- esperando a que salga favorecida es medir el sorteo. La regla ya esta escrita
-- en este repo: *un check cuya precondicion no se puede provocar no es un
-- check* ( server_doors.lua:1316-1329 ).
--
-- Dispara SIN reprogramar el reloj, a proposito: ver phantom_ScheduleEvent.
PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_event", function( ply, _, args )
    if not adminOnly( ply ) then return end

    local say = PHANTASMAGORIA.MakeSay( ply )
    local cat = args and args[ 1 ] and string.lower( args[ 1 ] )

    if not cat or not CATS[ cat ] then
        say( "[Phantasmagoria] uso: phantasmagoria_ghost_event <categoria>" )
        say( "    dispara esa categoria AHORA en todos los fantasmas vivos, sin tocar el reloj." )

        for _, key in ipairs( CAT_ORDER ) do
            say( "    " .. key .. string.rep( " ", 11 - #key ) .. CATS[ key ].que )

        end

        return

    end

    local vivos = PHANTASMAGORIA.EachGhost( function( ghost )
        if not isfunction( ghost.phantom_FireEvent ) then
            say( "    #" .. ghost:EntIndex() .. "  NO tiene el motor ( server_events.lua no cargo en esa clase )" )
            return

        end

        local salieron = ghost:phantom_FireEvent( cat )
        local st       = estado( ghost )

        say( "    #" .. ghost:EntIndex() .. "  " .. cat .. " -> " ..
            ( salieron > 0 and ( salieron .. " disparo(s)" ) or "NO SALIO" ) )
        say( "        " .. tostring( st.motivos[ cat ] or "sin motivo registrado ( el bucle ni lo intento )" ) )

    end )

    if vivos <= 0 then say( "[Phantasmagoria] no hay ningun fantasma vivo." ) end

end, "ANDAMIO. Dispara una categoria de evento paranormal AHORA. Sin argumentos lista las ocho." )

---------------------------------------------------------------------------
-- INSTRUMENTO: los flags de evento, sin lua_run
---------------------------------------------------------------------------
-- Mismo andamio y misma tabla de overrides que phantasmagoria_ghost_flag
-- ( server.lua:3333 ). Es un comando aparte y no una ampliacion de aquel porque
-- su tabla FLAGS es un `local` de server.lua: ampliarla desde aca seria
-- imposible, y editarla alla mezclaria este bloque con un archivo que otra
-- sesion esta tocando.
--
-- El override es el MISMO diccionario ( PHANTASMAGORIA.FlagOverrides ), asi que
-- los dos comandos son consistentes entre si aunque cada uno liste lo suyo.
-- ⚠ LA CONSECUENCIA HAY QUE DECIRLA: `phantasmagoria_ghost_flag` sin argumentos
-- lista SEIS flags y no los catorce que hay. Los ocho de evento se listan aca.
PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_evflag", function( ply, _, args )
    if not adminOnly( ply ) then return end

    local say  = PHANTASMAGORIA.MakeSay( ply )
    local name = args and args[ 1 ] and string.lower( args[ 1 ] )
    local val  = args and args[ 2 ]
    local info = name and CATS[ name ]

    if not info or ( val ~= "0" and val ~= "1" and val ~= "auto" ) then
        say( "[Phantasmagoria] uso: phantasmagoria_ghost_evflag <categoria> <0|1|auto>" )
        say( "    auto = sin override, manda el campo de cada clase de fantasma." )
        say( "    ⚠ el override gana sobre el campo pero NO sobre la convar en 0 o en 2." )

        for _, key in ipairs( CAT_ORDER ) do
            local c  = CATS[ key ]
            local ov = PHANTASMAGORIA.FlagOverrides[ c.campo ]

            say( "    " .. key .. string.rep( " ", 11 - #key ) ..
                ( ov == nil and "auto" or ( ov and "1   " or "0   " ) ) ..
                "  " .. c.campo .. "   ( " .. c.que .. " )" )

        end

        return

    end

    if val == "auto" then
        PHANTASMAGORIA.FlagOverrides[ info.campo ] = nil

    else
        PHANTASMAGORIA.FlagOverrides[ info.campo ] = val == "1"

    end

    say( "[Phantasmagoria] " .. name .. " -> " .. val .. "   ( " .. info.campo .. ", " .. info.que .. " )" )
    say( "    alcanza a los fantasmas vivos Y a los que spawneen despues." )

end, "ANDAMIO. Pisa el flag de una categoria de evento en todos los fantasmas. Sin argumentos lista las ocho." )

---------------------------------------------------------------------------
-- GUARDAS
---------------------------------------------------------------------------

-- ( 1 ) EL CAMPO PISADO POR UN METODO DEL MISMO NOMBRE.
-- Defecto MEDIDO en la ronda 4 de este repo: phantom_WalksWhenHunting era un
-- campo y server_speed.lua tenia un metodo homonimo, asi que el resolvedor leia
-- una funcion -- que no es true ni false -- y caia a la rama "el flag es nil".
-- El check que lo ejercia PASO igual, porque el default de esa rama coincidia
-- con lo esperado. *Un default que coincide con lo esperado convierte un campo
-- roto en un check verde*, y eso no lo agarra ninguna corrida: lo agarra una
-- guarda o nadie.
for _, key in ipairs( CAT_ORDER ) do
    local campo = CATS[ key ].campo

    if isfunction( ENT[ campo ] ) then
        ErrorNoHalt( "[Phantasmagoria] EL CAMPO '" .. campo .. "' esta PISADO por un metodo del mismo " ..
            "nombre. El resolvedor va a leer una funcion y va a creer que el flag no esta declarado, " ..
            "sin tirar error. Renombrar el metodo.\n" )

    end
end

-- ( 2 ) LAS DOS LISTAS DE CATEGORIAS TIENEN QUE COINCIDIR.
-- CAT_ORDER manda el sorteo y EventDefaults.weights manda los pesos. Una
-- categoria en una y no en la otra NO tira error:
--   · sin peso  -> nace en nil en los 30 tipos, el sorteo la saltea SIEMPRE, y
--                  la convar existe y no hace nada. Se lee como "esa categoria
--                  no funciona" y se busca el bug en el evento.
--   · sin cat   -> el peso existe en las 30 filas y no le llega a nadie.
-- Se comprueba al cargar porque al usar el sintoma ya ocurrio.
do
    local D = PHANTASMAGORIA.EventDefaults
    local pesos = ( istable( D ) and istable( D.weights ) ) and D.weights or nil

    if not pesos then
        ErrorNoHalt( "[Phantasmagoria] server_events.lua no encuentra PHANTASMAGORIA.EventDefaults.weights: " ..
            "ghost_flags.lua no cargo. El motor va a usar el neutro para todo y ningun tipo va a " ..
            "diferenciarse -- mirar la lista DATOS de lua/autorun/phantasmagoria_data.lua.\n" )

    else
        local faltan, sobran = {}, {}

        for _, key in ipairs( CAT_ORDER ) do
            if pesos[ key ] == nil then faltan[ #faltan + 1 ] = key end

        end

        for key in pairs( pesos ) do
            if not CATS[ key ] then sobran[ #sobran + 1 ] = key end

        end

        if #faltan > 0 then
            ErrorNoHalt( "[Phantasmagoria] categoria(s) de evento SIN PESO en EventDefaults.weights: " ..
                table.concat( faltan, ", " ) .. ". El sorteo las saltea siempre y la convar no hace nada.\n" )

        end

        if #sobran > 0 then
            ErrorNoHalt( "[Phantasmagoria] peso(s) en EventDefaults.weights sin categoria en server_events.lua: " ..
                table.concat( sobran, ", " ) .. ". No le llegan a nadie.\n" )

        end
    end
end

-- ( 3 ) CADA CATEGORIA TIENE QUE TENER IMPLEMENTACION.
-- Una entrada en CATS sin funcion en EV crea la convar, el flag y la linea del
-- reporte, y despues no hace nada. Es la forma mas creible de una categoria
-- muerta: todo el andamiaje existe.
do
    local sin = {}

    for _, key in ipairs( CAT_ORDER ) do
        if not isfunction( EV[ key ] ) then sin[ #sin + 1 ] = key end

    end

    if #sin > 0 then
        ErrorNoHalt( "[Phantasmagoria] categoria(s) declarada(s) en CATS y SIN implementacion en EV: " ..
            table.concat( sin, ", " ) .. ". Tienen convar, flag y linea de reporte, y no hacen nada.\n" )

    end
end

-- ( 4 ) LAS CLAVES DE MyClassTask, QUE ESTE ARCHIVO NO USA.
-- Va aca porque este es el ULTIMO include de server.lua y una guarda de este
-- tipo solo vale si corre despues de todos los que podrian pisar las claves.
--
-- ⚠⚠ SON DOS CLAVES Y NO TRES, Y LA PRIMERA VERSION DE ESTA GUARDA DECIA TRES.
-- Es un defecto que se agarro en la revision, y vale la pena dejarlo escrito
-- porque no fue un descuido de tipeo: fue **copiar un comentario en vez de
-- medir**. server.lua:3466-3468 afirma que la guarda de server_cloak.lua
-- "comprueba que las TRES claves de MyClassTask sigan siendo funciones -- Think
-- de las puertas, ModifyMovementSpeed de la velocidad y BehaveUpdatePriority de
-- este archivo". Esa frase es FALSA por partida doble:
--
--   · server_cloak.lua:826 lista DOS claves, no tres.
--   · server_cloak.lua:385-386 dice, con todas las letras, que descarto esa
--     clave: "⚠ Y NO VA EN ENT.MyClassTask, QUE ERA LO OBVIO Y ESTA MAL".
--     El cloak cuelga de ENT:BehaveUpdate.
--
-- Censo de asignaciones sobre el addon entero -- las TRES que hay, y se leyeron
-- las tres: ENT.MyClassTask = {} ( server.lua:3426, tabla nueva y vacia ),
-- .Think ( server_doors.lua:1301 ) y .ModifyMovementSpeed ( server_speed.lua:404 ).
-- `BehaveUpdatePriority` NO se asigna en ninguna parte: sus nueve apariciones en
-- el repo son comentarios.
--
-- O sea que la version anterior de esta guarda daba **ErrorNoHalt determinista
-- en todos los arranques**, acusando a este archivo de haber pisado una clave
-- que nunca existio. Es el nº 22 del catalogo del taller: *un control que
-- FABRICA el sintoma que busca*. Y la leccion es la de Term_FOV: **un
-- comentario mentiroso se propaga al lector que lo cita** -- yo fui el lector.
for _, clave in ipairs( { "Think", "ModifyMovementSpeed" } ) do
    if not isfunction( ENT.MyClassTask and ENT.MyClassTask[ clave ] ) then
        ErrorNoHalt( "[Phantasmagoria] ENT.MyClassTask." .. clave .. " NO es una funcion despues de " ..
            "incluir server_events.lua. Si este archivo la piso, el bloque de su dueno dejo de correr " ..
            "sin un solo error.\n" )

    end
end

-- ( 5 ) Y LA DE AL LADO, que es la que la guarda de arriba NO puede dar: el
-- cloak cuelga de ENT:BehaveUpdate, que es un METODO y no una clave de tabla.
-- Un archivo que lo pisara sin encadenar apagaria la ausencia entera en
-- silencio -- y este archivo es el ultimo include, o sea el ultimo sospechoso.
if not isfunction( ENT.BehaveUpdate ) then
    ErrorNoHalt( "[Phantasmagoria] ENT:BehaveUpdate NO es una funcion despues de incluir " ..
        "server_events.lua. Es de quien cuelga la ausencia ( server_cloak.lua ): si se piso, el " ..
        "fantasma deja de esconderse fuera del hunt y no hay error que lo diga.\n" )

end
