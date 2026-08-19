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

-- ⚠ LA RESERVA DE VOZ ( r3 ). Ver el bloque VOZ mas abajo para el corte y el
-- pedido del autor que lo origina. Es DOS estados y no tres, por el mismo motivo
-- que `evhunt`: no hay un flag por NPC que ignorar, el corte es del catalogo.
local cvReserva = CreateConVar( "phantasmagoria_ghost_evreserva", "1", FCVAR_ARCHIVE,
    "Reserva los bancos `voice` ( las frases y las risas ) y `humming` ( el canto ) para el paramic " ..
    "y para los eventos de manifestacion, dejando en el sorteo ambiente solo `whisper` y `breath`. " ..
    "0 = CONTROL, todo al sorteo ( el comportamiento de la r2 ) · 1 = reserva puesta.", 0, 1 )

---------------------------------------------------------------------------
-- LOS PROPS HORNEADOS DEL MAPA
---------------------------------------------------------------------------
-- La perilla existe para poder correr el A/B: con ella en 0 el evento se
-- comporta EXACTAMENTE como antes de este bloque, asi que la fila que dice "la
-- radio horneada suena" tiene contra que compararse. Sin control, "sono una
-- radio" no distingue el mecanismo nuevo de un ambiente que ya sonaba.
local cvHorneados = CreateConVar( "phantasmagoria_ghost_evhorneados", "1", FCVAR_ARCHIVE,
    "Deja que el evento `prop` use tambien los props HORNEADOS del mapa ( prop_static, leidos del " ..
    ".bsp ) cuando ninguna entidad real cubre la familia. Las entidades reales SIEMPRE tienen " ..
    "prioridad. 0 = CONTROL, solo entidades ( el comportamiento previo ) · 1 = tambien horneados.", 0, 1 )

-- Cuanto vive un emisor de un prop horneado cuando la familia NO declara corte
-- NI duracion. Es una tanda fija y generosa a proposito: `SoundDuration` no es
-- confiable sobre `.ogg` del lado del servidor, y el clip mas largo de las
-- familias cortas esta bien por debajo de esto.
--
-- ⚠ Las familias que declaran `dur` NO pasan por aca: su emisor vive lo que dura
-- el clip mas el margen de abajo. Ver el bloque `entero` de la radio.
local EMISOR_VIDA = 20

-- El colchon entre el final del clip y el borrado del emisor. Existe porque
-- **borrar NUESTRO emisor ES un corte**, asi que un emisor que muere en el
-- segundo exacto del final decapita el ultimo suspiro del clip -- que es justo
-- la parte que este bloque vino a rescatar.
--
-- ⚠⚠ MEDIDO EL 2026-08-18 ( fila 00 ), y hasta esa fecha esto era una razon
-- escrita en un comentario que se citaba como si fuera un resultado. Vale para
-- el `info_target` que creamos nosotros: se borro uno con `clock_tick` ( 46,55 s )
-- sonando y el tic-tac se corto, con el `IsValid` de control diciendo que el
-- borrado habia ocurrido de verdad.
--
-- ⚠⚠⚠ Y **NO** ES UNA LEY DEL MOTOR. La misma pasada midio el otro lado ( fila
-- 01 ): romper, borrar o desintegrar un `prop_physics` que esta sonando **NO**
-- corta su sonido. Por eso el prop de verdad lleva un `StopSound` explicito en
-- su `CallOnRemove` y no se apoya en el borrado -- ver el bloque
-- `EL PROP QUE SE ROMPE`. *La frase valia donde nacio y se habia mudado sola.*
local EMISOR_MARGEN = 2

---------------------------------------------------------------------------
-- EL INTERRUPTOR: +USE APAGA EL TRASTO QUE ESTA SONANDO
---------------------------------------------------------------------------
-- Pedido del autor, literal: *"quiero que veas si se puede apagar el prop
-- horneado apretando +USE cerca de donde esta sonando el ruido para poder apagar
-- las radios y telefonos ( solo esos por ahora, ya que no quiero que apagues con
-- un temporizador las radios, deja que suenen completos los audios )"*.
--
-- ⚠⚠ ESTA PERILLA Y LA DE ABAJO SON **UN SOLO CAMBIO** Y NO DOS. Sacarle el
-- corte a la radio sin el interruptor deja un clip de hasta 60,78 s solapandose
-- con el evento siguiente, que es literal el defecto que la r3 pago y el motivo
-- por el que existia `largo`. Por eso el default de las dos es 1 y por eso el
-- control ( las dos en 0 ) devuelve el comportamiento anterior COMPLETO.
local cvUse = CreateConVar( "phantasmagoria_ghost_evuse", "1", FCVAR_ARCHIVE,
    "El jugador apaga con +USE el trasto que esta sonando ( solo las familias marcadas `apagable`: " ..
    "radio y telefono ). 0 = CONTROL, +USE no apaga nada · 1 = apaga el mas cercano dentro del radio.", 0, 1 )

-- ⚠ EL CRITERIO DE "CERCA" ES UNA DECISION Y ESTA TOMADA A PROPOSITO: **solo
-- distancia, sin mirada**. Las dos formas se consideraron; pedir que le apuntes
-- pierde porque **el objeto es INVISIBLE** -- el emisor es un `info_target` sin
-- modelo, y el prop horneado no es una entidad --, o sea que no hay nada a que
-- apuntar y el jugador tendria que adivinar el pixel. Un criterio de mirada
-- sobre un sujeto que no se dibuja no es realismo: es una loteria.
--
-- 128 u son ~2,4 m con la conversion de Diseno 1 ( 1 m = 52,5 u ): hay que
-- entrar al cuarto y ponerse al lado, no alcanza con pasar por el pasillo.
local cvUseRad = CreateConVar( "phantasmagoria_ghost_evuseradius", "128", FCVAR_ARCHIVE,
    "Radio en unidades dentro del cual el +USE de un jugador apaga un trasto que esta sonando. " ..
    "Es SOLO distancia: no hace falta apuntarle, porque el objeto es invisible.", 16, 1024 )

-- LAS LLAVES QUE SUENAN SIN LLAVES. El autor: *"acabar con el ruido de llaves al
-- aplicar el evento de prop sin props elegibles ( podemos hacer que el bot
-- cierre puertas con pestillo y ahi aplicar esos sonidos )"*.
--
-- ⚠ CON PERILLA, y no es un lujo: un banco que se achica y uno que se rompe se
-- oyen IGUAL. Con esto en 0 el banco ambiente vuelve a sonar como antes, asi que
-- "ya no suenan llaves" se puede distinguir de "el evento se quedo mudo".
local cvLlaves = CreateConVar( "phantasmagoria_ghost_evllaves", "1", FCVAR_ARCHIVE,
    "Sin ninguna familia con sujeto, el evento `prop` NO suena el banco ambiente ( las llaves ) y " ..
    "dice por que. 0 = CONTROL, las llaves suenan igual ( el comportamiento previo ) · 1 = callado.", 0, 1 )

-- EL PESTILLO. La otra mitad del pedido: las llaves no se borran, se mudan a una
-- mecanica que SI tiene llaves.
--
-- ⚠⚠ TRABAR UNA PUERTA ES UNA MECANICA CON CONSECUENCIA, NO UN SONIDO. Si el bot
-- traba la unica salida de un cuarto, eso no es un susto: es un softlock. Los
-- tres limites viven abajo, en el bloque del pestillo, y son parte del diseno y
-- no del tuning: tope de puertas trabadas a la vez, vida maxima del pestillo, y
-- un comando para soltarlas todas.
local cvPestillo = CreateConVar( "phantasmagoria_ghost_evpestillo", "1", FCVAR_ARCHIVE,
    "El evento de puertas puede TRABAR una puerta cerrada ( Fire 'Lock' ) y ahi suenan las llaves. " ..
    "0 = CONTROL, nunca traba ( el comportamiento previo ) · 1 = puede trabar, con tope y con vida.", 0, 1 )

-- ⚠ LOS CONTADORES SON DEL INSTRUMENTO Y SON TRES, NO UNO.
--   `vivos`      la fila de la FUGA: tiene que subir durante el clip y VOLVER a
--                cero. Una sola lectura no distingue "no hay fuga" de "todavia
--                no se creo ninguno", por eso tambien esta `creados`.
--   `creados`    el acumulado de la sesion. Es el que vuelve legible al `vivos`:
--                un `vivos = 0` con `creados = 0` no acredita nada.
--   `salteados`  cuantas veces el barrido se encontro un emisor y lo salteo. Va
--                con NUMERO y no con silencio -- "no aparecio el emisor entre
--                los sujetos" se cumple igual si el barrido no corrio nunca.
--
-- ⚠⚠ `vivos` YA NO SE INCREMENTA NI SE DECREMENTA A MANO, Y ESO ES EL ARREGLO DE
-- UNA TRAMPA QUE SE VEIA DESDE ANTES DE ESCRIBIR EL +USE. Antes el descuento
-- vivia en un `timer.Simple( vida + 0.5 )`: si el +USE borra el emisor A LOS DOS
-- SEGUNDOS, ese timer igual iba a correr treinta segundos despues y a descontar
-- de un contador que ya no tenia a quien contar. El numero se habria separado
-- del conteo real del mapa, y **la fila de la fuga habria salido roja por un
-- motivo que no es una fuga**.
--
-- Ahora `vivos` se DERIVA del registro `SONANDO` en el momento de leerlo. Un
-- contador que se calcula no se puede desincronizar: no hay dos escrituras que
-- puedan quedar en desacuerdo, porque hay una sola lectura.
--
-- ⚠ El conteo REAL de emisores en el mapa se sigue imprimiendo al lado, y sigue
-- siendo un instrumento distinto: el registro dice lo que este archivo CREE, el
-- barrido de entidades dice lo que HAY. Si se separan, el que miente es el
-- registro. Derivar uno no vuelve redundante al otro -- lo vuelve comparable.
local EMISORES = { creados = 0, salteados = 0 }

-- ⚠ LOS CONTADORES DEL +USE, Y SON CUATRO PORQUE HAY CUATRO DESENLACES DISTINTOS
-- Y TRES DE ELLOS SE VEN IGUAL DESDE AFUERA ( "apreté E y no pasó nada" ):
--   `teclas`    todas las pulsaciones de IN_USE que el hook vio. Es la
--               acreditacion de que el hook ESTA VIVO -- sin este numero, la
--               fila del control negativo no distingue "no habia nada cerca" de
--               "el hook no corre en este realm", que es justo lo que P1 mide.
--   `apagados`  cuantas veces apago algo de verdad.
--   `lejos`     cuantas veces habia algo sonando y apagable, pero fuera del
--               radio. ESTE es el numero de la fila del control negativo: un
--               cero ahi no prueba nada, un uno prueba que el filtro decidio.
--   `tarde`     cuantas veces el candidato mas cercano ya habia terminado su
--               clip. Va aparte porque apagar un silencio se lee como exito y es
--               el falso verde de la trampa 4.
local USE = { teclas = 0, apagados = 0, lejos = 0, tarde = 0, ultimoLog = 0 }

-- ⚠ LOS DOS CONTADORES DEL PROP QUE SE ROMPE. *"Rompi la radio y sigue
-- sonando"* tiene **TRES** explicaciones que se oyen exactamente igual, y sin
-- estos numeros la fila que lo mide no puede elegir entre ellas -- que es lo que
-- le paso a la fila 01 del 2026-08-18, que salio roja sin diagnostico:
--   `enganchados`  cuantos props de verdad se fueron a sonar CON su
--                  `CallOnRemove` puesto. Si esto queda en 0, el sonido nunca
--                  salio de un prop_physics: el sujeto era otro ( casi seguro un
--                  emisor nuestro ), y la fila midio otra cosa.
--   `callados`     cuantas veces ese hook CORRIO de verdad al morir el prop. Si
--                  `enganchados` sube y `callados` no, el prop no se estaba
--                  borrando; si suben los dos y el ruido sigue, el que no llega
--                  a tiempo es el `StopSound` del motor -- y recien ahi hace
--                  falta un mecanismo distinto.
--
-- ✅ MEDIDO EN JUEGO EL 2026-08-19 ( r2, filas 00 y 01 ), Y CERRO LA TERCERA:
-- una radio `prop_physics` #1067 salio a sonar `creepy_music` ( 33,71 s ), se le
-- pego un tiro y **el sonido paro**, con `enganchados 1` y `callados 1` en la
-- misma lectura. O sea que un `StopSound` sobre una entidad **que se esta
-- yendo** SI llega a tiempo -- que era la precondicion que este bloque
-- declaraba sin medir. El candidato alternativo ( un emisor propio
-- `SetParent`-eado al prop, para que el prop nunca sostenga el canal ) queda
-- descartado por innecesario, no por malo.
local ROTOS = { enganchados = 0, callados = 0 }

-- ⚠ LA VENTANA DEL LOG DEL +USE, Y ES UNA VENTANA DE TIEMPO Y NO UN FILTRO DE
-- REPETIDOS. `E` se aprieta muchas veces seguidas -- para abrir puertas, para
-- agarrar cosas -- y con una radio sonando lejos cada pulsacion escribiria un
-- renglon: la bitacora quedaria tapada justo en la corrida que hay que leer.
-- Pero un filtro "no repitas lo mismo" borraria el episodio que alguien esta
-- reproduciendo a proposito ( ese defecto ya se pago acá, con el physgun ), asi
-- que lo que se limita es la FRECUENCIA. **Los contadores suben SIEMPRE**: lo
-- que se rate-limita es la prosa, nunca el numero que la fila lee.
local USE_LOG_CADA = 2

-- EL CLIC DEL INTERRUPTOR. Pedido del autor, textual: *"agregar un cambio
-- minusculo en que al apretar el horneado o el physics, este emita un sonido de
-- boton para demostrar que apagaste el objeto. ( En ui estan candidatos para ese
-- sonido: button_toggle_1 y 2, ambos suenan como apretar un interruptor sutil,
-- funcionan para simular apagar un objeto )"*.
--
-- ⚠⚠ SUENA **SOLO** EN EL DESENLACE QUE APAGO ALGO, NUNCA EN LOS OTROS TRES.
-- El +USE tiene cuatro salidas y tres no apagan nada ( `lejos`, `tarde`, y no
-- haber candidato ). Un clic en cualquiera de esas hace dos danos: le miente al
-- jugador -- que es lo contrario de lo que el sonido viene a hacer -- y **se
-- come el control negativo de la planilla**, porque el que la corre oye el clic
-- desde el otro cuarto y marca verde sobre un filtro que nunca decidio. El
-- cableado esta al final de `apagarCerca` a proposito, despues de los dos
-- `return false`.
--
-- ⚠⚠ LOS DOS CLIPS ERAN **ESTEREO** ( 2 canales, medidos con
-- `dev/duracion_ogg.py`: 0,23 s y 0,35 s ) Y PASARON POR
-- `dev/mono_posicionales.py` ANTES de entrar aca. **Source no espacializa un
-- estereo: lo tira en 2D**, asi que cableados como venian el clic se habria oido
-- igual de fuerte en toda la casa y no DESDE el objeto que apagaste -- que es
-- exactamente lo que el sonido viene a comunicar. Es el defecto que la r3 pago
-- en quince archivos, visto esta vez antes de escribir la linea.
--
-- ⚠ `ui/button_click.ogg` YA ERA MONO y no se uso: suena distinto, y el autor
-- eligio estos dos de oido. La conveniencia tecnica no decide por el.
--
-- ⚠ ESTA TABLA LA LEE `dev/mono_posicionales.py`, que saca sus rutas del Lua y
-- no de una lista a mano. Las dos marcas de abajo son su delimitador: si
-- desaparecen, el script **revienta** en vez de medir un universo vacio.
local CLIC_APAGADO = {
    "phantasmagoria/ui/button_toggle_1.ogg",
    "phantasmagoria/ui/button_toggle_2.ogg",
}
-- FIN DE CLIC_APAGADO

-- El nivel del clic, y es mas bajo que los 75 del resto del archivo a proposito:
-- el que aprieta esta a `cvUseRad` unidades como mucho ( 128 por default ), y un
-- clic que se oye desde el otro cuarto vuelve a ser un sonido 2D por otra
-- puerta. 60 lo deja audible bien pasado el radio del interruptor sin llevarlo a
-- toda la casa.
local CLIC_NIVEL = 60

-- LO QUE ESTA SONANDO AHORA POR EL EVENTO `prop`.
--
-- Cada entrada: { ent, snd, fam, emisor, hasta, quien }. `emisor` dice si la
-- entidad la creamos nosotros ( y por lo tanto se puede borrar ) o si es un prop
-- de verdad del mapa ( y entonces al +USE **solo** le toca callarlo: borrar la
-- radio de otro no es apagarla ).
--
-- ⚠ `hasta` NO es decoracion: sin el, el +USE sobre un emisor cuyo clip ya
-- termino imprimiria "apagado" habiendo apagado un silencio. Es la trampa 4 del
-- lado del instrumento -- *un sonido que se termino solo pasa por un +USE que
-- funciono*.
local SONANDO = {}

-- La poda. Corre en los tres lugares donde alguien mira el registro ( el evento,
-- el +USE y el reporte ) y NO en un timer: un timer mas seria un escritor mas
-- sobre el mismo estado, y este bloque acaba de sacar uno justamente por eso.
--
-- ⚠ SE PODA POR ENTIDAD INVALIDA Y **NO** POR `hasta`. Una entrada vencida sigue
-- valiendo mientras el emisor exista: es la que deja decir *"lo que tenias mas
-- cerca ya habia terminado"* en vez de *"no habia nada"*, y esas dos frases son
-- diagnosticos distintos. El vencimiento lo mira quien decide, no la poda.
--
-- Devuelve cuantas quedaron y cuantas se cayeron, porque un registro que se
-- vacia solo y uno que nunca se lleno **se leen igual en una foto**.
local function podarSonando()
    local caidas = 0

    for i = #SONANDO, 1, -1 do
        if not IsValid( SONANDO[ i ].ent ) then
            table.remove( SONANDO, i )
            caidas = caidas + 1

        end
    end

    return #SONANDO, caidas

end

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

---------------------------------------------------------------------------
-- ⚠⚠ LOS GOLPES VAN EN CINCO BANCOS Y NO EN DOS -- EL ARREGLO DE LA FILA 11
---------------------------------------------------------------------------
-- Pregunta del autor, r2: *"mi pregunta es si el sonido viene de una fuente
-- real, es decir, que func_breakable_surf de una ventana genere ese ruido?"*
--
-- LA RESPUESTA MEDIDA ES **NO, Y ESTABA AL REVES**. `SND.knock` tenia SIETE
-- entradas: UNA de puerta y SEIS de ventana. Como el codigo elegia ese banco
-- entero cuando el trace pegaba en una PUERTA, golpear una puerta sonaba a
-- ventana **6 de cada 7 veces ( 85,7 % )**. Y la otra mitad es peor y nadie la
-- habia preguntado: `contra` solo podia valer "puerta" o "pared", asi que una
-- ventana REAL caia en "pared" y se llevaba `SND.impact`, donde hay **cero**
-- clips de ventana. Los seis `window_*` eran INALCANZABLES golpeando una
-- ventana.
--
-- El catalogo lo decia y el codigo no lo implementaba: `about.txt:226` describe
-- `event/knock` como *"golpeteo en puerta Y ventana"* -- dos cosas en una
-- carpeta -- y el comentario del Lua CITABA bien esa linea mientras la linea de
-- abajo trataba la carpeta como una sola. *Un comentario correcto al lado de un
-- codigo que no lo implementa es indistinguible de un comentario mentiroso: los
-- dos hacen que el lector no mire.*
--
-- ⚠ EL COSTO HONESTO DE PARTIRLO, y se escribe porque nadie lo va a ver:
-- `impact_stone` queda con **UN** clip, y el evento repite el mismo clip 2-3
-- veces a proposito ( ver EV.knock ). Hoy la piedra sale 1 de 18 y pasa
-- desapercibida; partido, toda pared de hormigon suena siempre igual salvo por
-- el pitch. Es un hueco de ASSET, no de codigo, y esta declarado en vez de
-- tapado.
SND.knock_door = {
    "phantasmagoria/event/knock/door.ogg",
}

SND.knock_window = {
    "phantasmagoria/event/knock/window_1.ogg", "phantasmagoria/event/knock/window_2.ogg",
    "phantasmagoria/event/knock/window_3.ogg", "phantasmagoria/event/knock/window_4.ogg",
    "phantasmagoria/event/knock/window_5.ogg", "phantasmagoria/event/knock/window_6.ogg",
}

SND.impact_wood = {
    "phantasmagoria/event/impact/wood_1.ogg", "phantasmagoria/event/impact/wood_2.ogg",
    "phantasmagoria/event/impact/wood_3.ogg", "phantasmagoria/event/impact/wood_4.ogg",
    "phantasmagoria/event/impact/wood_5.ogg", "phantasmagoria/event/impact/wood_6.ogg",
    "phantasmagoria/event/impact/wood_impact_1.ogg", "phantasmagoria/event/impact/wood_impact_2.ogg",
    "phantasmagoria/event/impact/wood_impact_3.ogg", "phantasmagoria/event/impact/wood_impact_4.ogg",
    "phantasmagoria/event/impact/wood_impact_5.ogg", "phantasmagoria/event/impact/wood_impact_6.ogg",
}

SND.impact_metal = {
    "phantasmagoria/event/impact/metal_pipe_hit.ogg", "phantasmagoria/event/impact/metal_pipe_2.ogg",
    "phantasmagoria/event/impact/metal_pipe_6.ogg",   "phantasmagoria/event/impact/metal_deep.ogg",
    "phantasmagoria/event/impact/metal_tank.ogg",
}

SND.impact_stone = {
    "phantasmagoria/event/impact/stone.ogg",
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

-- ⚠ `break_slow.ogg` queda FUERA de los tres bancos de impacto a proposito:
-- dura mucho mas que
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
-- ⚠⚠ Y SIN LOS DE AUTO, QUE ES OTRA COSA Y SALIO DE LA r1 EN JUEGO. El autor:
-- *«sonidos de auto no deberian sonar a menos que se lo haga a un vehiculo de
-- half life 2 o Glide»*. `car_alarm` y `car_lock` estaban en esta tabla, que se
-- sortea SIN MIRAR EL MUNDO, asi que sonaba una alarma de auto en una casa
-- vacia. Se mudaron a PROP_CONSUJETO, abajo.
--
-- *Un banco plano de sonidos "de objetos" es una lista de objetos que el juego
-- afirma que estan ahi. Los que nombran un objeto identificable tienen que
-- comprobarlo; los que no ( un crujido de piano, unas llaves ) pueden sonar en
-- cualquier casa y por eso se quedan.*
-- ⚠⚠ QUEDAN **TRES** Y ANTES ERAN DIECIOCHO -- ES EL PEDIDO DE LA r2 Y NO UN
-- RECORTE. El autor, literal: *"sabes quiero lo mismo para otros sonidos,
-- sonidos de radio solo para radio, sonidos de telefono solo para telefonos"* y
-- *"Ruido de tecla de piano o guitarra suena un poco raro en mapas donde no hay
-- pianos ni guitarras, los sonidos tienen que ser circuntanciales."*
--
-- Los otros quince se mudaron a PROP_CONSUJETO, abajo, cada uno con el objeto
-- que tiene que estar presente. Los tres que quedan son los que **no nombran un
-- objeto operable**: unas llaves tintineando y un reloj andando pueden pasar en
-- cualquier casa, y no le prometen al jugador que hay algo ahi.
--
-- ⚠ Y EL COMENTARIO QUE JUSTIFICABA DEJAR EL PIANO ACA CONTRADECIA AL AUTOR CON
-- TODAS LAS LETRAS. Decia: *"los que no ( un crujido de piano, unas llaves )
-- pueden sonar en cualquier casa y por eso se quedan"*. Estaba escrito en la r2
-- como si fuera una regla derivada, y la regla de la que se derivaba -- la del
-- auto -- decia exactamente lo contrario. *Una regla se aplica a los casos que
-- la cumplen, no a los que uno no tuvo ganas de mudar.*
--
-- CONSECUENCIA QUE HAY QUE ACEPTAR DE FRENTE, y es la misma tesis de §21.1: en
-- un cuarto sin un solo objeto reconocible, `prop` va a sonar a llaves o a
-- reloj, o va a decir SIN SUJETO. Eso es correcto: la categoria existe para que
-- el ruido te diga que hay algo ahi.
-- ⚠⚠ Y SON DOS Y NO TRES, PORQUE `clock_tick` MIDE **46,55 s**. Estuvo en esta
-- lista hasta que la revision de esta misma tanda lo midio, y era el defecto que
-- el bloque de la radio -- veinte lineas mas abajo, escrito el mismo dia --
-- declara intolerable con estas palabras: *"`sound.Play` no devuelve nada que se
-- pueda apagar, asi que un clip de 42 s disparado como one-shot en un punto es
-- un ruido que no termina y que se solapa con el siguiente evento"*.
--
-- Es MAS LARGO que tres de los cuatro clips de radio que esta ronda se nego a
-- poner en el banco plano por ese motivo exacto. *Una regla escrita en un bloque
-- no se aplica sola al bloque de al lado, aunque los haya escrito la misma mano
-- el mismo dia.* Se fue a su propia familia con sujeto ( un reloj ) y con corte.
-- ⚠⚠⚠ ACA VIVIA EL "PRESENTADOR BRITANICO" QUE EL AUTOR REPORTO TRES RONDAS
-- SEGUIDAS, Y NADIE LO ENCONTRO PORQUE SE LO BUSCO EN LA CARPETA EQUIVOCADA.
-- Este banco citaba `prop/key_1.ogg` y `prop/key_2.ogg`, que **no son llaves: es
-- el encargado hablando**. La r3 dio por MEDIDO que la carpeta del presentador
-- ( `voice/` ) no tenia un solo consumidor, y era cierto -- el consumidor estaba
-- en `prop/`, con dos clips suyos guardados ahi bajo un nombre de utileria.
--
-- COMO SE VEIA EN JUEGO: este es el banco de FALLBACK, el que suena cuando el
-- evento `prop` no encuentra un objeto reconocible cerca. O sea que el locutor
-- aparecia justo cuando NO habia nada que lo explicara, y se leia como *"sono la
-- radio sola"*. El sintoma estaba lo mas lejos posible de su causa.
--
-- LOS DOS DATOS QUE LO CIERRAN, y ninguno es el nombre del archivo:
--   · DURACION. `key_1`/`key_2` miden **3,47 s y 3,44 s** -- largo de frase. Las
--     llaves de verdad de esta misma carpeta miden **0,50 a 0,96 s**.
--   · PROCEDENCIA. En el rip original `Key 1.wav` y `Key 2.wav` estan entre
--     `Hint None.wav`, `Arrival 1.wav` y `Welcome Back 1.wav`, o sea entre las
--     lineas del encargado -- no entre `Key Pickup 1.wav` / `Key lock 1.wav`,
--     que si son utileria.
-- *El nombre de un asset miente como un comentario, y una carpeta tambien.*
--
-- El autor los mudo a `voice/` al identificarlos, lo que dejo estas dos rutas
-- COLGADAS: el fallback se quedaba sin un solo clip valido y habria enmudecido
-- en silencio. Entran las ocho llaves REALES de `prop/` -- todas mono, todas de
-- menos de un segundo. Son mas que dos a proposito: un banco de fallback que se
-- repite se nota mas que uno que varia. Si `lock`/`unlock` se pisan con la
-- familia de puertas, se recorta a los `pickup` y no hace falta tocar nada mas.
-- ⚠⚠ LAS OCHO SE DECLARAN EN TRES BANCOS Y `SND.prop` SE ARMA CON ELLOS, y no
-- es cosmetica: el bloque del pestillo ( 2026-08-17 ) le da a `key_lock_*` y
-- `key_unlock_*` un consumidor donde SI hay una llave, y el banco ambiente sigue
-- existiendo para el CONTROL ( `phantasmagoria_ghost_evllaves 0` ). Escritas dos
-- veces, el dia que alguien agregue un `key_lock_4` va a entrar en un solo lado
-- y el otro banco va a quedar callado sin que nada lo diga.
-- *Una lista que decide comportamiento tiene que existir UNA vez.*
SND.key_pickup = {
    "phantasmagoria/prop/key_pickup_1.ogg",
    "phantasmagoria/prop/key_pickup_4.ogg",
}

SND.key_lock = {
    "phantasmagoria/prop/key_lock_1.ogg",
    "phantasmagoria/prop/key_lock_2.ogg",
    "phantasmagoria/prop/key_lock_3.ogg",
}

SND.key_unlock = {
    "phantasmagoria/prop/key_unlock_1.ogg",
    "phantasmagoria/prop/key_unlock_2.ogg",
    "phantasmagoria/prop/key_unlock_3.ogg",
}

SND.prop = {}

for _, banco in ipairs( { SND.key_pickup, SND.key_lock, SND.key_unlock } ) do
    for _, ruta in ipairs( banco ) do SND.prop[ #SND.prop + 1 ] = ruta end

end

-- Sonidos que NOMBRAN un objeto, y por eso no se sortean si el objeto no esta.
-- El sonido sale DE la entidad ( `EmitSound` ), no de un punto: una alarma que
-- suena a tres metros del auto es peor que no tener alarma.
--
-- ⚠ `IsVehicle()` alcanza para las DOS familias que el autor nombro, y esta
-- medido: Glide **pisa el metodo del metatable de Entity** para que devuelva
-- true en los suyos ( `glide/lua/autorun/sh_glide.lua:326-330`,
-- `return tab and tab.IsGlideVehicle or IsVehicle( self )` ). Se comprueba
-- igual `IsGlideVehicle` a mano por si el orden de carga deja el parche sin
-- aplicar -- cuesta una comparacion y evita un silencio dificil de diagnosticar.
---------------------------------------------------------------------------
-- EL DISCRIMINADOR POR NOMBRE DE MODELO
---------------------------------------------------------------------------
-- Pedido del autor, r2: *"Creo que mejor que buscar entre tanto modelo
-- directamente es hacer algo general para tomar esos modelos por nombre y
-- discriminador."* Esto es esa cosa general.
--
-- ⚠ NO PUEDE SER UNA LISTA BLANCA DE CLASES, Y ESTA MEDIDO: HIM monta
-- `models/props_lab/citizenradio.mdl` sobre un SENT de Lua con
-- `ENT.Base = "base_anim"` ( him/lua/entities/homeless_radio/ ), no sobre un
-- `prop_physics`. Un filtro por clase pierde esa radio entera. El criterio es
-- **tiene modelo y el modelo coincide**, y nada mas.
--
-- ⚠ Y NO PUEDE SER SOLO UN HASH DE RUTAS EXACTAS, aunque `prop_data.lua` de este
-- mismo addon use esa forma y sea O(1): el autor pidio "nombre Y discriminador",
-- y su propio catastro tiene seis radios que se llaman distinto -- citizenradio,
-- radio_reference, radionette01, german_radio, radio_box, radio. Enumerarlas es
-- exactamente lo que dijo que no quiere hacer.
--
-- Asi que son TRES campos y el tercero es el que evita el desastre:
--   exacto  basenames completos ( sin `.mdl` ), para lo que se conoce por nombre
--   parte   substrings del basename, para la familia entera
--   nunca   substrings que DESCALIFICAN, y corren PRIMERO
--
-- ⚠⚠ EL `nunca` NO ES PARANOIA: SALE DE UN CENSO DE **6542 `.mdl`** DEL TALLER,
-- y cinco de los nueve basenames que contienen "radio" NO SON RADIOS:
--
--   radios de verdad ( 4 )   radio · dez_radio · fmradio · wick_dev_fmradio
--   PASTILLAS ANTI-RADIACION ( 3 )   drug_radioprotector · dez_drug_radioprotector
--                            · wick_radioprotector
--   UN DETECTOR ( 2 )        dev_radio_diolator · dev_radio_diolator_hud
--
-- Sin la lista negra, **la mayoria de los "radios" del taller son pastillas**, y
-- el fantasma pondria musica creepy adentro de un blister. Los cinco se vetan
-- por `radioprotector` y `radio_diolator`, que son las dos raices.
--
--   · `radio_p1` es **el modelo ROTO** de la radio de CS:S -- lo senalo el autor
--     en el mismo mensaje, y contiene "radio".
--   · `models/nizckm/mwiii/executions/weapons/bromeo_805_myphone` es un **ARMA**
--     de Modern Warfare III y contiene "phone".
--   · `eqp_parabolic_microphone_iii` -- **nuestro propio paramic** -- contiene
--     "phone" adentro de "microphone". Lo veta `microphone`, y si no, el
--     fantasma haria sonar un telefono desde el instrumento con el que el
--     jugador lo esta escuchando.
--   · "radiator" NO hace falta vetarlo: no contiene "radio". Se midio, y se dice
--     para que nadie lo agregue de nuevo por las dudas -- *un veto que no puede
--     disparar ensucia la lista de motivos de los que si.*
--
-- ⚠ Y EL DENOMINADOR DE ESE CENSO TIENE UN LIMITE QUE HAY QUE DECIR: los 6542
-- `.mdl` son los del WORKSPACE ( addons desempacados y repos propios ). **El
-- contenido montado de HL2, CS:S y L4D2 no esta ahi**, asi que "cero pianos" en
-- el censo NO significa que no haya pianos en juego: significa que el censo no
-- los puede ver. La lista blanca por nombre exacto existe justamente para eso.
-- ⚠ LAS DOS DELEGAN EN `phantasmagoria/bsp_statics.lua`, Y NO ES UN REFACTOR DE
-- ADORNO.
--
-- Estas funciones reciben una ENTIDAD -- `basenameDe` hace `ent:GetModel()`. Un
-- prop HORNEADO ( `prop_static` ) no es una entidad: es una ruta de modelo
-- leida del `.bsp`, asi que no tiene con que entrar por aca. La salida facil
-- era escribir un matcher paralelo para los estaticos, y entonces el dia que
-- alguien agregue una palabra a un `nunca` va a arreglar la mitad de los casos
-- y la otra mitad va a seguir sonando mal, sin error y sin rastro.
--
-- *Una regla que decide identidad tiene que existir una vez.* Es la misma
-- leccion que `PARENT_HOPS` en el bloque de las puertas, y ese defecto ya se
-- cobro una huella. Asi que la regla se parte en dos: la parte que SACA el
-- modelo -- que si es distinta entre una entidad y una ruta -- y la parte que
-- NORMALIZA y DECIDE, que vive una sola vez en el modulo y la usan las dos.
--
-- El cuerpo que estaba aca se movio tal cual, sin cambiarle una linea ni el
-- orden ( `nunca` primero y gana, despues `exacto`, despues `parte` ): mover
-- una regla y corregirla en el mismo paso deja sin saber cual de las dos cosas
-- explica un cambio de comportamiento.
local function basenameDe( ent )
    local m = ent.GetModel and ent:GetModel()
    return PHANTASMAGORIA.BasenameDeRuta( m )

end

local function modeloCoincide( ent, regla )
    return PHANTASMAGORIA.NombreCoincide( basenameDe( ent ), regla )

end

local PROP_CONSUJETO = {
    {
        que     = "un vehiculo",
        sonidos = {
            "phantasmagoria/prop/car_alarm.ogg",
            "phantasmagoria/prop/car_lock.ogg",
        },
        sujeto  = function( ent )
            if not ( ent:IsVehicle() or ent.IsGlideVehicle == true ) then return false end

            -- ⚠ `IsVehicle()` dice true sobre la SILLA en la que te sentas.
            -- `prop_vehicle_prisoner_pod` es el asiento de sandbox -- y tambien
            -- el asiento de pasajero de Glide ( base_glide/init.lua ), cuyo
            -- chasis lleva `IsGlideVehicle` aparte: excluir la clase no pierde
            -- ningun auto de verdad.
            if ent:GetClass() == "prop_vehicle_prisoner_pod" then return false end

            -- Y una alarma que suena en el auto que estas MANEJANDO no es un
            -- susto: es un bug con cara de susto. `GetDriver` puede no existir
            -- en una entidad ajena que solo puso el campo `IsGlideVehicle`, asi
            -- que se pregunta antes de llamarlo.
            if isfunction( ent.GetDriver ) and IsValid( ent:GetDriver() ) then return false end

            return true

        end,
    },

    ---------------------------------------------------------------------------
    -- LA RADIO -- Diseno 21.9.8 ①, que estaba diseñada y sin escribir
    ---------------------------------------------------------------------------
    -- Los diez `.ogg` de `sound/phantasmagoria/prop/radio/` estaban en disco
    -- desde el 2026-08-03 y **ninguna linea de Lua los citaba**. El pedido
    -- estaba escrito en `about.txt:242-244` -- *"que el fantasma agarre un prop
    -- de radio de HL2 o CS ( la de office ) y reproduzca esto"* -- y el autor lo
    -- repitio en la r2 poniendo el catastro de modelos.
    --
    -- ⚠ POR QUE NO SE PODIAN CABLEAR AL BANCO PLANO, medido: duran de **19,5 a
    -- 159,8 segundos** ( ffprobe sobre los diez ). `sound.Play` no devuelve nada
    -- que se pueda apagar, asi que un clip de 42 s disparado como one-shot en un
    -- punto es un ruido que no termina y que se solapa con el siguiente evento.
    -- Es el mismo motivo por el que los cuatro `_loop` quedaron fuera en la r1.
    --
    -- Por eso esta familia lleva `largo`: se emite con `ent:EmitSound` -- el
    -- canal cuelga de la radio, asi que la sigue si alguien la mueve -- y se
    -- corta con `ent:StopSound` a los pocos segundos. Un radioruido que arranca
    -- y para solo es lo que hace una radio poseida; uno de 42 s es un bug.
    --
    -- ⚠⚠ CUATRO DE LOS DIEZ CLIPS NO ENTRAN, Y NO ES POR DURACION: el autor
    -- pidio en la misma r2 *"quitar tambien los sonidos del presentador
    -- britanico que en realidad no es un sonido de miedo es parte del equipo de
    -- cazafantasmas"*. Los cuatro que se dejan afuera son los que **puede que
    -- tengan voz hablada** y nadie los escucho todavia: `creepy_news`,
    -- `creepy_music_news`, `creepy_radio_easteregg_helpmewithend` y
    -- `event_creepy_eas_paranormal_radio_advise` ( un aviso de emergencia ). Los
    -- dos `ritual_*` quedan afuera por ser loops de 33 y 160 s.
    --
    -- *No se cablea un clip cuyo contenido nadie midio a una regla que habla de
    -- su contenido.* Van a la pregunta abierta de la r3, con nombre y duracion.
    --
    -- ( Y el presentador britanico de verdad -- la carpeta `voice/` del arbol de
    --   sonido, 26 archivos -- **no tiene un solo consumidor** en el addon.
    --
    --   ⚠ EL CRITERIO DE LA MEDICION HAY QUE ESCRIBIRLO, PORQUE SIN EL NO SE
    --   REPRODUCE Y ESTE COMENTARIO LA INVALIDA. Lo que se cuenta son las rutas
    --   ENTRE COMILLAS, o sea las que el motor puede llegar a emitir: son 39, y
    --   las 39 empiezan con `phantasmagoria/ghost/paranormal_voice/` -- que es la
    --   voz DEL FANTASMA y no la del encargado. Un `rg` que cuente tambien los
    --   comentarios da otro numero, justamente porque estos dos renglones
    --   nombran la carpeta del encargado para explicar que no se usa.
    --
    --   Y el instrumento correcto es la BARRA: un `rg voice` a secas da decenas
    --   de hits que son el RASGO `voice` del tipo de fantasma ( el indice 1 / 2
    --   de la voz, en ghost_flags.lua ). Un check escrito sobre `voice` sin barra
    --   acusaria al encargado de algo que no hizo y "arreglaria" el rasgo.
    --
    --   ⚠⚠⚠ "No habia nada que quitar" ERA FALSO, y el 2026-08-10 se encontro lo
--   que habia. La medicion de arriba es CORRECTA y aun asi la conclusion era
--   equivocada, que es lo que la vuelve util: conto las rutas que **contienen
--   la palabra `voice`** y las 39 dieron `paranormal_voice/`. El presentador
--   estaba en `SND.prop`, bajo `phantasmagoria/prop/key_1.ogg` -- una ruta que
--   **no contiene la palabra `voice` en ninguna parte**, asi que el censo no
--   podia verla ni con el criterio bien escrito.
--
--   *Un censo acotado por la carpeta donde ESPERAS que este el sospechoso no
--   puede encontrarlo donde no esta.* El universo correcto no eran las rutas
--   con `voice`: eran TODAS las rutas de sonido citadas ( son 164 ), cruzadas
--   contra lo que suena en cada una. Hoy la afirmacion vale y esta medida al
--   reves -- **cero** citas a `phantasmagoria/voice/` en todo el Lua -- que es
--   la direccion en la que un cero significa algo. )
    {
        que     = "una radio",

        -----------------------------------------------------------------------
        -- ⚠⚠ ACA VIVIA `largo = { 6, 14 }` Y LA RONDA DEL +USE LO SACO. QUEDA
        -- ESCRITO PARA QUE NO SE REESCRIBA.
        -----------------------------------------------------------------------
        -- Pedido del autor: *"no quiero que apagues con un temporizador las
        -- radios, deja que suenen completos los audios"*. Y no era una
        -- preferencia: **el corte decapitaba 6 de 6**. Medidas las duraciones
        -- contra los clips y no contra el nombre ( `dev/duracion_ogg.py`, que
        -- reproduce a 0,004 s los cuatro valores que ya existian ):
        --
        --     corte 6-14 s   ·   clips de 26,78 a 60,78 s   ->  6 de 6 cortados
        --
        -- No hay UN clip de esta familia que alcance a terminar. Y el final es la
        -- parte que importa: medido con planitud espectral, tres de los cuatro
        -- clips principales **terminan en ruido de banda ancha** -- la estatica y
        -- el apagado -- mientras el corte caia en el medio tonal. O sea que
        -- `StopSound` se comia siempre el apagado, y la promesa escrita quince
        -- lineas mas arriba -- *"un radioruido que arranca y para solo es lo que
        -- hace una radio poseida"* -- se cumplia a medias desde el dia que se
        -- escribio.
        --
        -- ⚠ SACAR EL CORTE SIN PONER EL INTERRUPTOR HABRIA SIDO UN DEFECTO Y NO
        -- UN ARREGLO: un clip de 60,78 s se solapa con el evento siguiente, que
        -- es el motivo por el que `largo` existia. Las dos mitades son el mismo
        -- cambio -- ver `cvUse` arriba.
        entero   = true,
        apagable = true,

        -- ⚠ LA SEGUNDA MITAD QUE SE OLVIDA. El emisor vivia `largo[2] + 2`
        -- segundos; si el clip pasa a sonar entero y el emisor se va antes,
        -- **borrarlo lo decapita igual, por otra puerta** -- una entidad que se
        -- va se lleva su canal. Por eso la duracion vive ACA, al lado del clip, y
        -- de aca salen las dos cosas que dependen de ella ( la vida del emisor y
        -- la ventana del +USE ): *una constante que decide comportamiento tiene
        -- que existir UNA vez*.
        --
        -- Medidas con `dev/duracion_ogg.py` ( granule del ultimo page / rate,
        -- leido del binario ). Las cuatro primeras ya estaban medidas con otro
        -- instrumento y son el AUTO-CONTROL del lector: reprodujeron a 0,004 s.
        -- Las dos ultimas son nuevas de esta ronda y salieron de la misma corrida
        -- calibrada. Los seis clips son MONO, que es la precondicion de que
        -- suenen DESDE el objeto ( Source no espacializa un estereo ).
        dur = {
            [ "phantasmagoria/prop/radio/creepy_music.ogg" ]          = 33.71,
            [ "phantasmagoria/prop/radio/creepy_music_old.ogg" ]      = 26.78,
            [ "phantasmagoria/prop/radio/creepy_music_slowdown.ogg" ] = 42.23,
            [ "phantasmagoria/prop/radio/creepy_montage.ogg" ]        = 41.41,
            [ "phantasmagoria/prop/radio/creepy_radio_easteregg_helpmewithend.ogg" ] = 60.78,
            [ "phantasmagoria/prop/radio/ritual_chanting_loop.ogg" ]  = 32.75,
        },

        -- ⚠ UNO DE LOS SEIS ES UN LOOP Y HAY QUE DECIRLO EN VEZ DE DESCUBRIRLO
        -- EN JUEGO. `ritual_chanting_loop` mide 32,75 s de audio, pero si el
        -- motor lo trata como bucle no tiene "final": lo que lo corta pasa a ser
        -- la muerte del emisor a los 34,75 s, o sea el corte por otra puerta.
        -- Entro a la familia en la r3 con el argumento de que *"un loop cortado
        -- se oye como una radio que arranca y para"* -- que era cierto cuando
        -- habia corte y **queda sin sostener ahora que no lo hay**.
        -- No se saca en esta ronda: sacarlo seria decidir por el autor sobre un
        -- clip que el pidio expresamente. Queda como frontera abierta y con
        -- nombre, para que la fila de "la radio suena entera" **no se corra con
        -- este clip** y para que un rojo suyo no se lea como un rojo del bloque.
        -- ⚠ LOS DOS DE ABAJO LOS PIDIO EL AUTOR EXPLICITAMENTE ( r3, 2026-08-10 ):
        -- *"Agrega creepy_radio_easteregg_helpmewithend.ogg y ritual_chanting_loop
        -- al roster de los sonidos de radio"*. Los dos motivos por los que estaban
        -- afuera quedan CONTESTADOS y no simplemente ignorados:
        --   · la duracion ( 60 s y 32 s ) no importa en ESTA familia, que es la
        --     unica que lleva `largo` y corta con StopSound a los 6-14 s;
        --   · el de `_loop` tampoco: un loop cortado a los 10 s se oye como una
        --     radio que arranca y para, que es justo lo que se busca.
        --
        -- ⚠⚠ `creepy_radio_easteregg_helpmewithend` ERA ESTEREO ( medido con
        -- ffprobe, 2 canales, 60 s ) y por eso paso por dev/mono_posicionales.py
        -- ANTES de entrar aca. Sin esa conversion habria roto EN SILENCIO la
        -- promesa de la familia -- Source no espacializa un estereo, lo tira en 2D
        -- --, que es el defecto exacto que la r3 acababa de pagar en 15 archivos.
        -- `ritual_chanting_loop` ya venia en 1 canal.
        sonidos = {
            "phantasmagoria/prop/radio/creepy_music.ogg",
            "phantasmagoria/prop/radio/creepy_music_old.ogg",
            "phantasmagoria/prop/radio/creepy_music_slowdown.ogg",
            "phantasmagoria/prop/radio/creepy_montage.ogg",
            "phantasmagoria/prop/radio/creepy_radio_easteregg_helpmewithend.ogg",
            "phantasmagoria/prop/radio/ritual_chanting_loop.ogg",
        },
        modelo  = {
            -- El catastro del autor, verificado sobre nada -- son nombres que el
            -- dijo de memoria mirando el spawnmenu, y por eso van como `exacto`
            -- ademas del substring: si alguno esta mal escrito, el substring lo
            -- salva igual.
            exacto = {
                [ "citizenradio" ]    = true,   -- HL2, props_lab
                [ "radio_reference" ] = true,   -- Portal
                [ "radionette01" ]    = true,   -- gm_funkis_night
                [ "german_radio" ]    = true,   -- Day of Defeat
                [ "radio_box" ]       = true,
            },
            parte = { "radio" },
            -- Las dos raices de los cinco falsos positivos medidos, mas el
            -- modelo roto que senalo el autor y los sufijos de pedazos.
            -- ⚠ `radio_antenna` lo destapo el censo de props HORNEADOS
            -- ( 2026-08-16 ): `props_radiostation/radio_antenna01_skybox` entraba
            -- a esta familia por el substring "radio" y es una ANTENA del skybox
            -- 3D. Vive a 9210 en Y de una casa que ocupa de -1100 a 100, asi que
            -- una consulta por radio probablemente no lo alcanzaria nunca --
            -- **pero eso lo salva la distancia, no la regla**, y una regla que
            -- solo funciona porque el objeto estaba lejos no es una regla.
            nunca = { "radioprotector", "radio_diolator", "radio_p1", "radio_antenna",
                      "_p1", "_p2", "_p3", "_p4", "_gib", "broken", "destroyed" },
        },
    },

    ---------------------------------------------------------------------------
    -- EL TELEFONO
    ---------------------------------------------------------------------------
    -- El autor: *"Telefonos en l4d estan en su carpeta prop_interior, variantes
    -- phone_motel y phone ( p_1 son partes del prop destruido ) en css tambien
    -- hay varios telefonos, oldphone de css militia es uno, css office tiene
    -- radio y phone."*
    {
        que     = "un telefono",

        -- ⚠ EL AUTOR PIDIO EL +USE PARA *"las radios y telefonos"*, Y EN ESTA
        -- FAMILIA CASI NO TIENE NADA QUE APAGAR. Medido: `phone_ring` dura
        -- **3,46 s** -- por eso esta familia nunca
        -- tuvo `largo`, nunca hizo falta cortarla. Ponerle el interruptor es
        -- coherente y cuesta cero ( el mecanismo es el mismo ), **pero no
        -- resuelve ningun sintoma**: para llegar a apretar hay que estar al lado
        -- y dentro de una ventana de tres segundos y medio.
        -- *Una fila que solo se puede aprobar con reflejos no mide el mecanismo,
        -- mide al que la corre.* El sujeto de verdad del bloque es la radio; el
        -- telefono entra de arrastre, y esta escrito para que nadie le pida a la
        -- planilla una fila que no se puede correr.
        --
        -- `entero` no le cambia el sonido -- ya sonaba completo -- pero le
        -- ajusta la vida del emisor: pasa de los 20 s fijos a 5,46 s, o sea deja
        -- de haber un `info_target` mudo dando vueltas dieciseis segundos.
        --
        -- ⚠⚠ ESTA FAMILIA TIENE **UN SOLO CLIP**, Y ES UNA DECISION DEL AUTOR Y
        -- NO UN OLVIDO. Textual ( 2026-08-17 ): *"tambien el ruido
        -- ( phone_vibrate.ogg ) corresponde a un celular; phone como prop
        -- horneado o phys son generalmente telefonos fijos, asi que
        -- phone_ring.ogg esta bien, quita phone_vibrate.ogg"*. Los modelos que
        -- esta familia reclama -- `oldphone`, `phone_motel`, el `phone` de
        -- cs_office -- son telefonos FIJOS, y un telefono fijo no vibra: el clip
        -- no sonaba mal, sonaba a OTRO OBJETO.
        --
        -- LA CONSECUENCIA VA DICHA ACA EN VEZ DE DESCUBRIRSE EN JUEGO: **un
        -- telefono ahora suena siempre igual**. Con 3,46 s y un evento cada
        -- 25-90 s no molesta, pero el que abra esta tabla y vea UNA sola entrada
        -- tiene que poder distinguir "falta algo" de "falta a proposito".
        --
        -- ⚠ EL `.ogg` NO SE BORRA DEL DISCO, y eso tambien es a proposito: queda
        -- sin consumidor esperando el dia que haya un smartphone de verdad, que
        -- es el prop al que le corresponde. Lo que NO puede pasar es lo del
        -- reves -- una ruta CITADA sin archivo en disco **enmudece sin error** --
        -- y por eso el cierre chequea que toda ruta resuelva.
        --
        -- El control de este cambio ya existia y no hubo que inventarlo: la
        -- guarda ( 3b ) del final del archivo compara `sonidos` contra `dur` en
        -- las DOS direcciones, asi que sacarlo de una sola de las dos tablas
        -- grita al cargar.
        entero   = true,
        apagable = true,
        dur = {
            [ "phantasmagoria/prop/phone_ring.ogg" ] = 3.46,
        },
        sonidos = {
            "phantasmagoria/prop/phone_ring.ogg",
        },
        modelo  = {
            exacto = { [ "oldphone" ] = true, [ "phone" ] = true, [ "phone_motel" ] = true },
            parte  = { "phone" },
            -- `myphone` es un ARMA de MWIII, medida en el taller. `headphone` y
            -- `microphone` no aparecieron en el censo pero son la misma familia
            -- de falsos positivos y cuestan una comparacion.
            -- ⚠ `phone_book` es una GUIA telefonica, no un telefono. Entraba por
            -- el substring "phone" igual que los otros tres de esta lista, y lo
            -- destapo el censo de props horneados ( 2026-08-16 ): el autor lo
            -- confirmo mirandolo, *"no es un telefono, es un libro"*.
            nunca  = { "myphone", "headphone", "microphone", "phone_book",
                       "_p1", "_gib", "broken" },
        },
    },

    ---------------------------------------------------------------------------
    -- EL TELEVISOR
    ---------------------------------------------------------------------------
    -- ⚠ "tv" A SECAS SERIA UN DESASTRE como substring ( matchea `tvrip`,
    -- `motv...`, cualquier cosa ). Van los delimitados y los basenames exactos.
    --
    -- ⚠⚠ Y EL `nunca` LLEVA LOS SUFIJOS DE PEDAZOS, QUE EN ESTA FAMILIA SON
    -- MAYORIA. Censo del taller: de los CINCO basenames que contienen "tv_",
    -- **uno es un televisor y cuatro son pedazos rotos** -- `tv_plasma` mas
    -- `tv_plasma_p1` a `_p4` ( dev/other/cs_office_tv/ ). Sin esto, cuatro de
    -- cada cinco "televisores" que el evento puede encontrar son escombros, y
    -- el fantasma prende una tele que ya exploto. El autor uso la misma
    -- convencion al describir sus telefonos de L4D: *"p_1 son partes del prop
    -- destruido"*.
    {
        que     = "un televisor",
        sonidos = {
            "phantasmagoria/prop/tv_on.ogg",     "phantasmagoria/prop/tv_off.ogg",
            "phantasmagoria/prop/tv_noise.ogg",  "phantasmagoria/prop/tv_remote.ogg",
        },
        -- ⚠ `tv_noise` dura 10,03 s medidos: sin este corte queda sonando
        -- encima del evento siguiente. Es el mismo motivo que la radio, con
        -- otro numero -- y el numero se midio, no se supuso.
        largo   = { 4, 9 },
        modelo  = {
            exacto = { [ "tv" ] = true, [ "tvset" ] = true, [ "tv_plasma" ] = true },
            parte  = { "tv_", "_tv", "television" },
            nunca  = { "_p1", "_p2", "_p3", "_p4", "_gib", "broken", "destroyed" },
        },
    },

    ---------------------------------------------------------------------------
    -- EL PIANO -- el caso que el autor nombro por su nombre
    ---------------------------------------------------------------------------
    {
        que     = "un piano",
        sonidos = {
            "phantasmagoria/prop/piano_key_1.ogg", "phantasmagoria/prop/piano_key_2.ogg",
            "phantasmagoria/prop/piano_key_3.ogg", "phantasmagoria/prop/piano_key_4.ogg",
            "phantasmagoria/prop/piano_key_5.ogg",
        },
        modelo  = { parte = { "piano" }, nunca = { "_gib", "broken" } },
    },

    {
        que     = "una guitarra",
        sonidos = { "phantasmagoria/prop/guitar_string.ogg" },
        modelo  = { parte = { "guitar" }, nunca = { "_gib", "broken" } },
    },

    {
        que     = "un microondas",
        sonidos = { "phantasmagoria/prop/microwave_beep.ogg" },
        modelo  = { parte = { "microwave" } },
    },

    {
        que     = "un inodoro",
        sonidos = { "phantasmagoria/prop/toilet_flush.ogg" },
        -- ⚠⚠ ESTA FAMILIA NO TENIA `nunca` NINGUNO, y era la peor de las cuatro.
        -- El censo de props horneados ( 2026-08-16 ) midio que **6 de las 9
        -- instancias de "inodoro" del mapa eran PAPEL HIGIENICO** --
        -- `toiletpaperroll` x4 y `toiletpaperdispenser_residential` x2 -- o sea
        -- que dos de cada tres veces que el fantasma tiraba la cadena, la tiraba
        -- un rollo. El autor lo marco dos veces: *"NO ES TOILET"*.
        --
        -- Un solo veto cubre los dos modelos porque los dos empiezan igual, y se
        -- prefiere `toiletpaper` a dos entradas sueltas: cualquier variante del
        -- pack ( `toiletpaperroll_2`, otro dispenser ) queda cubierta sin volver
        -- a tocar la lista.
        modelo  = { parte = { "toilet" }, nunca = { "toiletpaper", "_gib", "broken" } },
    },

    {
        que     = "un peluche",
        sonidos = { "phantasmagoria/prop/teddy_laugh.ogg" },
        modelo  = { parte = { "teddy" } },
    },

    -- El reloj. Llego aca desde el banco plano por su duracion ( ver el
    -- comentario de SND.prop ): 46,55 s son treinta veces mas que cualquier otro
    -- clip ambiente, y sin sujeto ni corte era un tic-tac que se comia el evento
    -- siguiente.
    {
        que     = "un reloj",
        sonidos = { "phantasmagoria/prop/clock_tick.ogg" },
        largo   = { 5, 12 },
        modelo  = { parte = { "clock" }, nunca = { "_p1", "_gib", "broken" } },
    },
}

-- ⚠ LA MITAD DE LA PREGUNTA DEL AUTOR QUE TIENE RESPUESTA Y ES **NO** ( con su
-- consuelo ): *"Algunos modelos estan baked en el mapa, me pregunto si seran
-- posibles de tomar?"*
--
-- Como ENTIDADES, no. Los `prop_static` se hornean en el BSP al compilar y no
-- existen en runtime: `ents.FindByClass( "prop_static" )` tiene **cero** call
-- sites en los 70 addons desempacados del taller, y no es casualidad. Un trace
-- SI los pega, pero `tr.Entity` es el MUNDO ( `IsWorld()` da true ) y el
-- discriminador de que pegaste en uno es `tr.HitTexture == "**studio**"` -- el
-- NOMBRE del modelo no viene del trace.
--
-- Lo que SI se puede, y hay un tercero en este mismo taller que lo hace y
-- funciona: **abrir el `.bsp` desde Lua y leer el game lump `sprp`**. StormFox2
-- lo tiene escrito -- `file.Open( "maps/" .. game.GetMap() .. ".bsp", "rb",
-- "GAME" )`, el fourCC 1936749168, la tabla de rutas de modelo, y hasta un
-- `FindStaticsInSphere( pos, radio )` que es el gemelo exacto de
-- `ents.FindInSphere` sobre lo horneado.
--
-- NO SE ESCRIBE EN ESTA RONDA, y el motivo es una medicion que falta y cuesta
-- diez minutos: **nadie conto cuantas radios, televisores o pianos ESTATICOS
-- tiene el mapa del autor.** La r1 ya saco `gm_funkis_night.bsp` del `.gma` y
-- parseo su LUMP_ENTITIES ( 322 luces, 43 conmutables, 15 prop_physics ); lo que
-- no toco es el lump `sprp`. Si ahi hay cero objetos de estas ocho familias,
-- todo el parser sobra. *Primero el numero que decide, despues el codigo.*

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
--
-- ⚠ Y DESDE EL 2026-08-17 EL SORTEO NO ES LA SEGUNDA OPCION SINO LA TERCERA: en
-- el medio esta EL MODELO. La prioridad es **tipo > modelo > sorteo** y vive en
-- `phantom_EventVoice()`, mas abajo, con el porque del orden. Antes de esto la
-- voz y el cuerpo se elegian por caminos que no se hablaban, asi que el
-- Ghost_Male podia susurrar con voz de mujer.
---------------------------------------------------------------------------
-- ⚠⚠ LA RESERVA: `whisper` SUENA SOLO, `voice` Y `humming` SE GUARDAN
---------------------------------------------------------------------------
-- Pedido del autor, r2, literal: *"Los sonidos de paranormal_voice se escuchan
-- creo que con el paramic o en eventos cuando el fantasma se manifiesta, no es
-- un sonido que suene por sonar, lo mismo que los cantos. Tal vez un pequeño
-- whisper podria ser sonido del fantasma sin usar paramic o en evento."*
--
-- Es una correccion de DISENO y no un bug: el banco `paranormal_voice` es -- lo
-- dice su propio nombre y `about.txt` -- **lo que la parabolica le oye DECIR**.
-- Que el fantasma grite "get out" cada cuarenta segundos al aire libre gasta la
-- carta antes de que exista el equipo que la reparte.
--
-- EL CORTE ES POR **SI SE ENTIENDE O NO**, y esa es la unica regla que no
-- depende de que a uno le guste el clip:
--   whisper   lo que NO dice palabras -- susurro, murmullo, jadeo, quejido,
--             shhh. Es presencia, no mensaje: puede sonar solo.
--   voice     lo que DICE algo ( "get out", "why", "watching you" ) **y las
--             risas**, que no dicen palabras pero son un susto y no una
--             presencia. Reservado.
--   humming   el canto y la caja musical. Reservado -- el autor los nombro
--             aparte y §21.9.8 ② ya los tiene diseñados como un evento con
--             puesta en escena ( el fantasma se queda quieto y te mira ), que no
--             existe todavia.
--
-- Quedan OCHO en `whisper` por voz, que es lo mismo que tenia `breath` por dos.
--
-- ⚠ LA RESERVA NO BORRA NADA Y TIENE PERILLA. Los clips reservados siguen en la
-- tabla y `phantasmagoria_ghost_evreserva 0` los devuelve al sorteo, que es el
-- comportamiento exacto de la r2. Sin ese control, "ya casi no habla" y "el
-- banco se rompio otra vez" se leen igual -- y este bloque ya tuvo un banco
-- mudo entero con el instrumento diciendo OK.
local VOZ = {
    [ 1 ] = {
        whisper = {
            "phantasmagoria/ghost/paranormal_voice/voice_1_mutterings_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_mutterings_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_mutterings_03.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_shhh_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_gasp_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_gasp_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_gasp_03.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_gasp_04.ogg",
        },
        voice = {
            "phantasmagoria/ghost/paranormal_voice/voice_1_cant_find_me.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_get_out_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_get_out_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_hey_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_hey_03.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_hey_07.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_high_laugh_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_high_laugh_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_1_high_laugh_03.ogg",
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
        whisper = {
            "phantasmagoria/ghost/paranormal_voice/voice_2_whisper_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_whisper_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_whisper_03.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_whisper_04.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_mutters_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_moan_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_moan_03.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_moan_04.ogg",
        },
        voice = {
            "phantasmagoria/ghost/paranormal_voice/voice_2_cold_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_help_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_laugh_02.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_laugh_03.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_laugh_04.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_lost_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_shout_get_out_01.ogg",
            "phantasmagoria/ghost/paranormal_voice/voice_2_watching_you_01.ogg",
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

-- ⚠⚠ EL MISMO DEFECTO YA CERRADO DOS VECES EN ESTE ADDON, Y ENTRO OTRA VEZ POR
-- UN INSTRUMENTO NUEVO. La bitacora escribia `#442` pelado, y **GMod recicla el
-- EntIndex**: en la corrida r1 hay un `#442` que tira 4 props con la fuerza de
-- un Poltergeist y, dos pantallas mas abajo, un `#442` que la ficha declara
-- Shade. Las dos lineas son ciertas y son de sujetos distintos.
--
-- La solucion ya estaba escrita y en produccion en OTROS DOS archivos del mismo
-- addon -- `server_cloak.lua:163` con `/sN` y `server_steps.lua:430` con `/cN`.
-- Se usa `/sN` ( `phantom_Serial`, server.lua:841 ) porque es la MISMA serie que
-- imprimen `ghost_where` y `ghost_vis`, y el valor de un identificador esta en
-- poder cruzar dos instrumentos.
--
-- *Que una leccion este cerrada en el repo no la aplica al archivo que se
-- escribe mañana: lo que se hereda es el texto, no la practica.*
local function quien( ghost )
    if not IsValid( ghost ) then return "#?" end

    return "#" .. ghost:EntIndex() .. "/s" .. tostring( ghost.phantom_Serial or "?" )

end

-- ⚠ LO QUE SE DESCARTA SE CUENTA. El volcado decia `bitacora ( 60 / 60 )` tanto
-- si hubo 60 renglones como si hubo 600: la ventana llena se lee igual que la
-- ventana justa, y el que mira cree que vio todo. La r23b ya pago esta leccion
-- en la bitacora de la ausencia, donde 28 de 40 renglones eran spawns.
PHANTASMAGORIA.EventLogPerdidas = PHANTASMAGORIA.EventLogPerdidas or 0

local function anotar( texto )
    local log = PHANTASMAGORIA.EventLog
    log[ #log + 1 ] = string.format( "%7.1f  %s", CurTime(), texto )

    while #log > BITACORA_MAX do
        table.remove( log, 1 )
        PHANTASMAGORIA.EventLogPerdidas = PHANTASMAGORIA.EventLogPerdidas + 1

    end
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

---------------------------------------------------------------------------
-- LAS LLAVES, PARA EL QUE TENGA UNA PUERTA
---------------------------------------------------------------------------
-- Se EXPORTA porque tiene dos consumidores en dos archivos: el pestillo de acá y
-- el destrabado de `server_doors.lua:1036`, que existe desde la ronda de las
-- puertas y hasta hoy era mudo. Los bancos se quedan donde viven todos los demas
-- ( este archivo es el dueno del catalogo de sonido de eventos ) y lo que viaja
-- es la funcion, no la tabla.
--
-- ⚠ `server_doors.lua` se incluye ANTES que este archivo, asi que alla la
-- referencia tiene que ser tardia -- se llama en runtime, no al cargar. Alla hay
-- un `isfunction` con aviso de una sola vez: sin el, un dia que este archivo no
-- cargue el destrabado se quedaria mudo Y sin decir por que, que es la forma de
-- falla que este bloque entero vino a corregir.
--
-- Devuelve la ruta que sono ( o nil ), y ese retorno NO es decorativo: es lo que
-- deja que quien llama escriba en la bitacora QUE clip sono, en vez de afirmar
-- que sono alguno.
function PHANTASMAGORIA.SonarLlave( tipo, pos, nivel )
    local banco = ( tipo == "lock" and SND.key_lock )
        or ( tipo == "unlock" and SND.key_unlock )
        or SND.key_pickup

    local snd = elegir( banco )
    if not snd or not isvector( pos ) then return nil end

    -- 68 de nivel y no los 75 de un prop: una llave en una cerradura es un ruido
    -- chico, y este sonido va a sonar a la distancia de una puerta y no a la de
    -- una habitacion.
    sound.Play( snd, pos, nivel or 68, math.random( 96, 104 ) )

    return snd

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

---------------------------------------------------------------------------
-- ⭐ LA VOZ DE LA CACERIA -- ES UN LOOP, Y POR ESO **NO** VIVE EN `VOZ`
---------------------------------------------------------------------------
-- Pedido del autor ( 2026-08-18 ), literal: *"ahora que los ghost tienen sexo y
-- modelo correspondiente, que asignaras en loop las voces de caceria"*.
--
-- `sound/phantasmagoria/ghost/hunt/` tiene CATORCE clips y estaban en disco
-- desde el 2026-08-03 **sin un solo consumidor en todo el Lua**. Trece son la
-- caceria real del juego repartida por voz -- `voice_1_*` y `voice_2_*` --, o sea
-- el MISMO indice que decide el sexo del cuerpo en `ghost_models.lua` y que fija
-- el rasgo `voice` del tipo. El catorceavo es `breath_1.ogg` y tiene su bloque
-- aparte, mas abajo.
--
-- ⚠⚠ POR QUE ESTE BANCO NO ENTRA EN LA TABLA `VOZ` DE ARRIBA, que era lo obvio.
-- `VOZ` es lo que sortea `EV.sound`, o sea el evento paranormal AMBIENTE, y ese
-- dispara one-shot con `EmitSound( snd, 70, math.random( 96, 104 ) )` sin
-- guardar nada con que apagarlo. Estos clips miden de **21,05 a 64,92 s**
-- ( `dev/duracion_ogg.py`; el lector quedo calibrado en la misma corrida contra
-- los cuatro clips de control de `prop/radio`, 4 de 4 OK ). Metidos ahi, el dia
-- que un tipo trajera un peso `hunt` en sus `soundBanks` el fantasma largaria
-- sesenta y cinco segundos de caceria en plena calma y **nadie podria pararlos**
-- -- que es, palabra por palabra, el motivo por el que los cuatro `_loop` de
-- `prop/` quedaron fuera del banco plano en la r1 y por el que `clock_tick` se
-- fue del suyo despues.
--
-- *Una tabla que un sorteo recorre es la promesa de que cualquiera de sus
-- entradas puede salir sola.* Estas no pueden: son un estado, no un evento.
--
-- ⚠ Y EL LARGO VA ESCRITO AL LADO DE LA RUTA, EN LA MISMA FILA. `SoundDuration`
-- no es confiable sobre `.ogg` del lado del servidor -- ya esta escrito mas
-- arriba, en el bloque de `EMISOR_VIDA` --, asi que el encadenado no puede
-- preguntarle al motor cuanto dura lo que acaba de emitir. Una segunda tabla
-- `ruta -> segundos` habria sido una lista paralela que se desincroniza el dia
-- que alguien agregue un clip en una sola de las dos.
---------------------------------------------------------------------------
-- ⭐⭐ r2 ( 2026-08-18 ) -- **UN FANTASMA, UN ARCHIVO**, Y EL FLAG DE LOS TRES MODOS
---------------------------------------------------------------------------
-- La r1 encadenaba clips DISTINTOS y paso 11 de 11 en juego. El autor la corrio
-- entera y agrego la acotacion que faltaba, literal: *"los fantasmas en
-- phasmophobia solo usan un solo archivo de audio loopeado en toda la partida,
-- es decir cada voz es particular al fantasma. Los «Alternates» que busco
-- construir mas adelante hablan con varias voces, asi que el hunt deberia ser
-- tipo un flag para cada fantasma."*
--
-- O sea que la r1 no estaba rota: **estaba resolviendo el caso general cuando el
-- caso normal es el particular**. Encadenar seis clips distintos hace que el
-- fantasma suene a un banco de sonido; quedarse con UNO lo vuelve un individuo,
-- que es la misma tesis del `fingerprint sonoro` que Diseno §5 le pide a la voz.
--
-- LOS TRES MODOS, y son tres y no dos porque el autor nombro los tres casos:
--
--   uno      ( DEFAULT ) el clip se sortea UNA VEZ por fantasma y se loopea toda
--            la partida. Es Phasmophobia, y es lo que el autor describio.
--   varios   encadena clips distintos sin repetir el anterior -- el
--            comportamiento de la r1. Queda para los **Alternates**, que "hablan
--            con varias voces", y **es tambien el CONTROL**: la r1 corrio 11 de
--            11 con esto, asi que apagar el modo nuevo devuelve un estado que ya
--            esta medido en juego, no una hipotesis.
--   mudo     este fantasma no hace ruido de caceria. Es el *"para que algunos
--            hagan ruido de hunt y otros no"*.
--
-- ⚠⚠ Y EL DEFAULT ES `uno` AUNQUE SEA EL MODO NUEVO. Escrito al reves -- default
-- `varios`, que es lo ya medido -- el pedido del autor quedaria detras de una
-- perilla que hay que acordarse de mover, o sea implementado y apagado. *Una
-- correccion cuyo efecto depende de que alguien tipee algo no es una correccion:
-- es una opcion.* Lo que se paga a cambio es que el estado medido pasa a ser el
-- que hay que pedir, y por eso `varios` es explicitamente el CONTROL y tiene su
-- fila propia en la planilla.
--
-- ⚠ LA PRIORIDAD ES **override del fantasma > rasgo del tipo > convar global >
-- `uno`**, y el orden es la decision. El override por fantasma va primero porque
-- es el andamio con el que el autor va a poder tener dos fantasmas al lado, uno
-- mudo y otro no, que es literalmente lo que pidio. El rasgo del tipo va segundo
-- porque es la regla del juego y no una prueba. La convar global va tercera
-- porque es del que MIDE, no del diseno; y si estuviera primera, tocarla para un
-- A/B pisaria en silencio un rasgo que un tipo declara -- que es el defecto nº 49
-- del catalogo con otra cara.
--
-- ⚠ HOY NINGUN TIPO DECLARA EL RASGO, y eso esta bien: los treinta caen al
-- default. La lectura ya esta escrita para que el dia que `ghost_flags.lua`
-- declare `huntVoice = "mudo"` en un tipo, funcione sin tocar una linea de aca.
-- *Un gancho que no se escribe el dia que se disena el mecanismo se escribe el
-- dia que hace falta, o sea con el archivo de datos ya lleno.*
---------------------------------------------------------------------------
-- POR QUE NO SE USA `AngryLoopingSounds` DE LA BASE, QUE HACE CASI ESTO
---------------------------------------------------------------------------
-- La base TIENE el mecanismo: `ENT.IdleLoopingSounds` / `ENT.AngryLoopingSounds`
-- + `SpokenLinesThink` ( terminator nextbot/spokenlines.lua:39-100 ), que
-- encadena un `CreateSound` y lo reinicia cuando termina. Se leyo entero antes
-- de escribir esto, y no sirve por TRES motivos medidos, no por estilo:
--
--   ① ESTA APAGADO. `ENT.CanSpeak = false` ( su shared.lua:177 ) y el phantom no
--      lo prende en ninguna linea: `SpokenLinesThink` sale en su primer `if`.
--      O sea que hoy el subsistema entero es codigo muerto para nosotros.
--   ② EL DISPARADOR ES OTRO. Elige el banco con `self:IsAngry()`, que es *tener
--      enemigo / que te hayan pegado / `terminator_PermanentAngry`*
--      ( motionoverrides.lua:659 ) -- **no** nuestro flag de hunt. Este addon ya
--      pago una ronda entera por confundir las dos cosas: server.lua:1260 dice
--      con todas las letras *"esa frase no es EL HUNT, es TENER ENEMIGO -- y son
--      cosas distintas"*.
--   ③ Y SE QUEDA PRENDIDO. `terminator_AngryTime` es una latch y
--      `terminator_PermanentAngry` no se apaga nunca: la caceria seguiria
--      sonando despues de que el hunt se apago, que es el sintoma mas caro de
--      todos ( se oye como "el fantasma sigue cazando" cuando ya no ).
--
-- Se cuelga entonces de `phantom_SetHunting` ( server.lua ), que es LA PUERTA
-- UNICA del flag y ya esta declarada como tal en su propio bloque.
---------------------------------------------------------------------------
-- EL CANAL, Y QUE NO CHOCA CON NADA
---------------------------------------------------------------------------
-- Va por `CHAN_VOICE`. La ventaja no es cosmetica: un `EmitSound` nuevo en el
-- mismo canal reemplaza al que estaba sonando, asi que un timer que dispare dos
-- veces no deja dos cacerias superpuestas. Igual se llama `StopSound` con el
-- nombre del archivo, que no depende de esa promesa del engine.
--
-- Censo de quien mas usa `CHAN_VOICE` sobre el bot -- son cuatro lineas y las
-- cuatro estan en `spokenlines.lua` ( :145, :185, :208, :240 ), o sea adentro del
-- subsistema que el ① de arriba deja apagado. `EV.sound`, la otra voz que sale
-- del fantasma, emite en `CHAN_AUTO` ( no pasa canal ): no se cortan entre si.
---------------------------------------------------------------------------

-- ⚠ EL HUECO ENTRE UNA VUELTA Y LA SIGUIENTE ES **POR MODO**, y no es un ajuste
-- fino: son dos cosas distintas con el mismo nombre.
--
--   en `uno`     el archivo se re-emite a si mismo, asi que el empalme es EL
--                MISMO PUNTO cada vuelta y el oido lo aprende. Cualquier hueco
--                audible convierte un loop en "se corta y arranca". Va en CERO:
--                lo unico que queda es el jitter del timer ( un frame, ~15 ms a
--                66 tick ), y el largo esta medido a 2 decimales, o sea ±5 ms.
--   en `varios`  el clip que entra es OTRO, asi que el cambio se oye igual. Un
--                respiro corto ahi lee como una pausa del fantasma y no como un
--                corte -- y ademas tapa el salto de sonoridad entre dos clips
--                que no estan nivelados ( ver el bloque de LUFS, abajo ).
local HUNT_GAP = { uno = 0.00, varios = 0.15 }

---------------------------------------------------------------------------
-- ⚠⚠ LA TERCERA COLUMNA ES **SONORIDAD MEDIDA**, Y SALIO DE UNA CORRIDA EN JUEGO
---------------------------------------------------------------------------
-- El autor, corriendo la fila 09 de la r1: *"Ese loop se siente mas bajito que
-- las «canciones» tarareadas. El loop_03 es un canto, ese suena mas fuerte por
-- lo agudo de la voz, el loop_01 es como un gorgoteo grave femenino, le hacemos
-- una ecualizacion?"*
--
-- Se fue a medir antes de contestar, con `dev/sonoridad_ogg.py` ( EBU R128 sobre
-- ffmpeg ). Los dos clips que nombro:
--
--     voice_1_loop_01  ( el gorgoteo )   -26,4 LUFS
--     voice_1_loop_03  ( el canto )      -20,0 LUFS      ->  6,4 LU de brecha
--
-- ⚠ Y LA RESPUESTA A LA PREGUNTA ES **NO**: no falta ecualizar. LUFS lleva la
-- ponderacion K, que ya modela la sensibilidad del oido por frecuencia, asi que
-- esos 6,4 LU **no** son "se percibe mas bajo por ser grave": son mas bajo. Una
-- ecualizacion corrige el ESPECTRO y este defecto es de GANANCIA -- aplicarla
-- cambiaria el timbre de la voz para arreglar algo que no es el timbre.
--
-- ⚠⚠ Y EL MODO `uno` LO CONVIERTE DE ESTETICO EN JUGABLE. El banco entero va de
-- **-30,5 a -18,2 LUFS: 12,3 LU de dispersion**. Encadenando ( la r1 ) eso se
-- promediaba solo. Con un clip fijo por fantasma NO se promedia: al que le toque
-- `voice_2_loop_03` caza 10 dB mas bajo que al que le toque `voice_1_loop_04`,
-- toda la partida, y la caceria es la senal con la que el jugador decide correr.
--
-- ⚠⚠⚠ LO QUE ESTE LADO **NO** PUEDE ARREGLAR, Y HAY QUE DECIRLO. El `volume` de
-- `EmitSound` va de 0 a 1: **solo baja**. O sea que nivelar desde el Lua empareja
-- HACIA ABAJO y los clips por debajo del objetivo se quedan donde estan. Subir
-- los tres flojos ( `voice_2_loop_03`, `voice_2_grim`, `voice_1_loop_01` ) es
-- tocar los `.ogg`, y eso es decision del autor: `sound/` esta gitignoreado y una
-- normalizacion no se deshace sin el backup previo.
--
-- Por eso la nivelacion tiene perilla y **arranca en 0**: el estado que el autor
-- ya oyo y aprobo 11 de 11 no se cambia sin que el lo pida. La perilla existe
-- para que pueda comparar en juego, que es donde se decide.
local HUNT_LUFS_OBJETIVO = -24.0

-- ⚠ EL LARGO Y EL LUFS SON DATO MEDIDO, NO ESTIMADO.
--   largo   `python dev/duracion_ogg.py sound/phantasmagoria/ghost/hunt`, con el
--           lector calibrado en la MISMA sesion contra `prop/radio` ( 4 de 4 de
--           control OK ). Ese instrumento ademas cuenta canales, y los trece son
--           **mono** -- la precondicion de que el motor los espacialice, o sea de
--           que la caceria te sirva para ubicar al fantasma.
--   lufs    `python dev/sonoridad_ogg.py sound/phantasmagoria/ghost/hunt`
--           ( EBU R128 integrado, ffmpeg ).
-- Los dos los vuelve a comprobar `dev/caceria_bancos.py` contra el archivo.
--
--     { ruta, largo en s, LUFS integrado }
local HUNT = {
    -- La voz 1 ( femenina ): ghost_girl y ghost_oldcrone.
    [ 1 ] = {
        { "phantasmagoria/ghost/hunt/voice_1_loop_01.ogg", 47.22, -26.4 },
        { "phantasmagoria/ghost/hunt/voice_1_loop_02.ogg", 21.05, -19.9 },
        { "phantasmagoria/ghost/hunt/voice_1_loop_03.ogg", 24.24, -20.0 },
        { "phantasmagoria/ghost/hunt/voice_1_loop_04.ogg", 58.33, -18.2 },
        { "phantasmagoria/ghost/hunt/voice_1_loop_05.ogg", 64.92, -24.2 },
        { "phantasmagoria/ghost/hunt/voice_1_inhales.ogg", 34.32, -22.3 },
    },

    -- La voz 2 ( grave ): ghost_male.
    [ 2 ] = {
        { "phantasmagoria/ghost/hunt/voice_2_loop_01.ogg",    41.23, -24.1 },
        { "phantasmagoria/ghost/hunt/voice_2_loop_02.ogg",    40.97, -24.0 },
        { "phantasmagoria/ghost/hunt/voice_2_loop_03.ogg",    50.09, -30.5 },
        { "phantasmagoria/ghost/hunt/voice_2_loop_04.ogg",    36.81, -20.2 },
        { "phantasmagoria/ghost/hunt/voice_2_loop_05.ogg",    39.37, -20.7 },
        { "phantasmagoria/ghost/hunt/voice_2_whispering.ogg", 22.88, -24.3 },
        { "phantasmagoria/ghost/hunt/voice_2_grim.ogg",       28.03, -30.2 },
    },
}

---------------------------------------------------------------------------
-- ⚠⚠ `breath_1.ogg` -- EL PEDIDO DEL AUTOR, Y LAS DOS COSAS QUE SE MIDIERON
---------------------------------------------------------------------------
-- El autor lo ofrecio asi: *"breath_1 puede ser para los sin tipo si es que lo
-- necesitan"*. Es un permiso condicional, y la condicion se fue a medir en vez
-- de darla por buena. Las dos mediciones dicen que HOY no lo necesitan, y por
-- que si algun dia lo necesitaran habria que tocarlo ANTES:
--
--   ① NO HAY FANTASMA SIN VOZ. `phantom_EventVoice()` devuelve **siempre** 1 o
--      2: si el tipo no la fija y el modelo tampoco -- que es el caso degenerado
--      normal, y el unico que existe con un cuerpo ajeno -- cae al
--      `math.random( 1, 2 )` de su ultima rama. O sea que el fantasma "sin tipo"
--      no se queda sin banco: se queda sin QUIEN DECLARE su voz, que es otra
--      cosa, y el sorteo ya se hace cargo. Un fallback puesto sobre un caso que
--      no ocurre es codigo que nadie va a oir nunca y que igual acredita.
--
--   ② Y ES **ESTEREO**, que sobre este clip en particular no es un detalle:
--      44100 / **2 canales** / 2,60 s ( `dev/duracion_ogg.py`, que lo marca solo
--      con `!! 2 CANALES` ). **Source no espacializa un estereo: lo tira en 2D.**
--      La caceria es justamente el sonido cuyo TRABAJO es dejarte ubicar al
--      fantasma; servido en 2D se oiria igual de fuerte pegado a la puerta que
--      desde el otro cuarto, y el jugador leeria eso como "el mod no ubica
--      nada". Los trece de voz son mono y no tienen el problema.
--
-- Queda declarado igual, y con un solo consumidor: **el banco de la voz vacio**.
-- Eso hoy es inalcanzable ( los dos tienen seis y siete clips ), y esta escrito
-- para que el dia que alguien vacie uno la caceria no enmudezca EN SILENCIO --
-- que es el modo de falla que `dev/rutas_de_sonido.py` describe en su cabecera:
-- un sonido que falta no da error, da silencio, y el silencio se disfraza de las
-- otras tres causas. El instrumento de abajo lo rotula `DEGRADADO`.
--
-- ⚠ SI ALGUN DIA SE LO QUIERE DE VERDAD: pasarlo a mono primero, con
-- `dev/mono_posicionales.py`, que hace el backup antes ( una conversion a mono
-- no se deshace y `sound/` esta gitignoreado ). Cablearlo como esta seria meter
-- el defecto que ese script existe para sacar.
local HUNT_NEUTRA = {
    { "phantasmagoria/ghost/hunt/breath_1.ogg", 2.60, -21.1 },
}

---------------------------------------------------------------------------
-- LAS PERILLAS
---------------------------------------------------------------------------
-- ⚠ DOS ESTADOS Y NO TRES, igual que `evhunt` y `evreserva`: no hay un flag por
-- NPC que ignorar. El 0 es el CONTROL y reproduce EXACTAMENTE lo de antes de
-- este bloque -- el hunt mudo --, que es lo que hace que "no se oye la caceria"
-- se pueda separar de "el hunt no se prendio".
local cvHuntVoz = CreateConVar( "phantasmagoria_ghost_huntvoz", "1", FCVAR_ARCHIVE,
    "La voz de la caceria. Mientras el fantasma esta en hunt suena el clip de " ..
    "sound/phantasmagoria/ghost/hunt/ que le toca a SU voz ( 1 femenina, 2 grave ). " ..
    "0 = CONTROL, el hunt vuelve a ser mudo ( el comportamiento previo al 2026-08-18 ) - 1 = puesta.", 0, 1 )

---------------------------------------------------------------------------
-- ⭐ 80, Y ES LA SEGUNDA DECISION DEL AUTOR SOBRE EL MISMO NUMERO
---------------------------------------------------------------------------
-- ⚠⚠⚠ ESTE BLOQUE DECIA **150** Y LO DECIA CITANDO AL AUTOR. El 2026-08-19 el
-- autor pidio **80**, o sea que la decision de la r3 queda REVERTIDA -- y el
-- comentario se reescribe en vez de dejarse al lado del numero nuevo, porque un
-- comentario viejo junto a su propia refutacion es la trampa que este taller ya
-- pago dos veces.
--
-- LA HISTORIA DEL NUMERO, entera, porque las CUATRO paradas dicen cosas distintas
--
--   70   el de la voz ambiente ( `EV.sound` ). Presencia de cuarto.
--   80   r1: la caceria tiene que oirse desde el otro lado de la casa, porque es
--        la senal con la que el jugador decide correr. **Este es el de hoy.**
--   150  r3: *"el otro comando para aumentar el volumen a 150 esta bien"*, elegido
--        contra la alternativa de emparejar los clips desde el Lua o normalizar
--        los `.ogg`.
--   80   2026-08-19: el autor vuelve al 80.
--
-- ⚠ LO QUE **NO** CAMBIA CON ESTA REVERSION, y es lo que hay que no volver a
-- discutir: la brecha de **12,3 LU de dispersion** del banco sigue intacta, igual
-- que con 150. El SNDLVL multiplica a los catorce clips POR IGUAL, asi que nunca
-- fue la perilla que podia emparejarlos -- ni subiendo ni bajando. Resuelve
-- *"hasta donde llega"* y no *"unos suenan mas que otros"*, y son dos
-- afirmaciones distintas. Si la segunda molesta algun dia, las dos vias siguen
-- donde estaban: `phantasmagoria_ghost_huntvoznivelar 1` empareja hacia abajo, y
-- normalizar los `.ogg` es lo unico que empareja hacia arriba.
--
-- ⚠ Y LO QUE EL 150 TENIA EN CONTRA ESTABA ESCRITO ACA DESDE LA r3, sin medirse:
-- un SNDLVL de 150 esta en el orden de un tren ( `SNDLVL_TRAIN` ), asi que casi
-- no se atenua con la distancia y **en un mapa abierto la caceria se oye de muy
-- lejos**. El renglon decia que adentro de una casa eso era justo lo que se
-- queria. El autor jugo con el puesto y volvio al 80: *la advertencia estaba bien
-- y el veredicto era del juego, no del renglon.*
--
-- El tope se dejo en 180 y no se toca. Con el default en 80 sobra margen para
-- volver a subirlo sin recompilar nada, que es justo lo que esta reversion
-- necesito: la perilla estaba a mano y el callback la aplica en vivo.
local cvHuntVozLvl = CreateConVar( "phantasmagoria_ghost_huntvozlvl", "80", FCVAR_ARCHIVE,
    "SNDLVL de la voz de caceria. 70 es el de la voz ambiente ( EV.sound ), 80 -- el elegido por el " ..
    "autor -- se oye a traves de un par de paredes, y 150 casi no se atenua con la distancia ( en un " ..
    "mapa abierto se oye de lejisimos ). Sube el ALCANCE de los catorce clips POR IGUAL: no cambia " ..
    "la brecha de sonoridad entre ellos.",
    50, 180 )

-- ⚠ EL DEFAULT DE ESTA ES `auto` Y NO UN MODO, y no es lo mismo. `auto` significa
-- *no opino, decide el fantasma o su tipo*; escribir `uno` aca haria que la
-- convar global -- que es del que mide -- pisara el rasgo de un tipo que manana
-- declare `mudo`, en silencio y en todas las partidas. Es el nº 49 del catalogo:
-- una perilla que apaga justamente lo que existe para probar.
local cvHuntVozModo = CreateConVar( "phantasmagoria_ghost_huntvozmodo", "auto", FCVAR_ARCHIVE,
    "Modo de la voz de caceria para los fantasmas que no lo declaren ellos ni su tipo. " ..
    "auto = el default del bloque ( uno ) - uno = UN clip sorteado una vez y loopeado toda la " ..
    "partida ( Phasmophobia ) - varios = encadena clips distintos ( el CONTROL: es la r1, medida " ..
    "11 de 11 en juego ) - mudo = este fantasma no hace ruido de caceria." )

-- ⚠ ARRANCA EN 0 A PROPOSITO. Ver el bloque de LUFS: el autor ya oyo y aprobo el
-- estado sin nivelar, asi que el cambio no se le mete sin que lo pida. La perilla
-- existe para que pueda comparar EN JUEGO, que es donde se decide -- y no para
-- dejar el arreglo escrito y apagado, que seria la trampa inversa.
local cvHuntVozNivel = CreateConVar( "phantasmagoria_ghost_huntvoznivelar", "0", FCVAR_ARCHIVE,
    "Nivela la sonoridad de los clips de caceria bajando los mas fuertes hasta " ..
    tostring( HUNT_LUFS_OBJETIVO ) .. " LUFS. El banco tiene 12,3 LU de dispersion medida y el " ..
    "`volume` de EmitSound SOLO BAJA, asi que esto empareja hacia abajo y los tres clips que ya " ..
    "estan por debajo del objetivo no se pueden subir desde aca. 0 = CONTROL, como suena hoy.", 0, 1 )

---------------------------------------------------------------------------
-- EL MODO DE CADA FANTASMA
---------------------------------------------------------------------------
local MODOS = { uno = true, varios = true, mudo = true }

--[[
    phantom_HuntVoiceMode() -> "uno" | "varios" | "mudo", motivo

    ⚠ DEVUELVE EL MOTIVO Y NO SOLO EL MODO, por lo mismo que `phantom_EventVoice`:
    "salio mudo" no distingue *lo puso el andamio* de *lo pide el tipo* de *lo
    forzo la convar global*, y las tres se ven igual en una consola. El reporte
    lo imprime.

    ⚠ Y NO CACHEA. La voz se cachea porque sortear clip por clip delataria que el
    sonido es una tabla; el modo no sortea nada -- es una lectura de tres campos
    -- y cachearlo lo volveria otra perilla que no alcanza a los que ya existen
    ( nº 26 ). Se resuelve en cada vuelta del loop, que es una vez cada 20-65 s.
]]
function ENT:phantom_HuntVoiceMode()
    -- ① el override del fantasma: el andamio con el que el autor pone dos al
    --    lado, uno mudo y otro no.
    local propio = self.phantom_huntVozModo

    if MODOS[ propio ] then
        return propio, "lo fija ESTE fantasma ( phantasmagoria_ghost_cazavoz )"

    end

    -- ② el rasgo del tipo. Hoy ninguno de los 30 lo declara y todos caen mas
    --    abajo; la lectura existe para que declararlo manana no toque codigo.
    local flags = self:phantom_EventFlags()
    local delTipo = flags and flags.huntVoice

    if MODOS[ delTipo ] then
        return delTipo, "lo fija el TIPO " .. tostring( self.phantom_TypeKey ) ..
            " ( rasgo huntVoice = " .. delTipo .. " )"

    end

    -- ③ la convar global, que es del que mide.
    local global = string.lower( string.Trim( cvHuntVozModo:GetString() or "" ) )

    if MODOS[ global ] then
        return global, "lo fuerza phantasmagoria_ghost_huntvozmodo = " .. global

    end

    -- ⚠ UN VALOR QUE NO ES NINGUNO DE LOS TRES SE DICE, no se traga. `auto` es el
    -- default legitimo y calla; cualquier otra cosa es un tipeo y el sintoma
    -- seria "la convar no hace nada", que se lee como que el modo no existe.
    if global ~= "" and global ~= "auto" then
        return "uno", "phantasmagoria_ghost_huntvozmodo dice '" .. global ..
            "', que NO es uno/varios/mudo/auto -- se usa el default"

    end

    -- ④ el default del bloque, que es lo que el autor describio de Phasmophobia.
    return "uno", "el default ( un solo archivo por fantasma, como Phasmophobia )"

end

---------------------------------------------------------------------------
-- EL ENCADENADO
---------------------------------------------------------------------------

-- ⚠ LA CLAVE DEL TIMER ES LA **SERIE** Y NO EL EntIndex, por lo mismo que la
-- bitacora de arriba: GMod recicla el EntIndex, asi que dos fantasmas separados
-- por un respawn pueden compartir nombre de timer y el segundo le apagaria la
-- caceria al primero. Se guarda ademas EN el fantasma, para que el `Stop` borre
-- exactamente el timer que el `Start` creo aunque la serie cambiara en el medio.
local function idCaceria( ghost )
    return "phantasmagoria_huntvoz_s" .. tostring( ghost.phantom_Serial or ( "e" .. ghost:EntIndex() ) )

end

-- Devuelve true si habia algo sonando ( o sea: si esta llamada CALLO algo ).
-- Que devuelva el hecho y no un ok es lo que deja que la bitacora no escriba
-- "se apago la caceria" cuando no habia ninguna -- que es la mitad del spam de
-- un log que despues nadie lee.
local function pararCaceria( ghost, motivo )
    if not IsValid( ghost ) then return false end

    local id = ghost.phantom_huntTimer

    if id then
        timer.Remove( id )
        ghost.phantom_huntTimer = nil

    end

    local snd = ghost.phantom_huntSnd
    if not snd then return false end

    ghost.phantom_huntSnd   = nil
    ghost.phantom_huntHasta = nil

    ghost:StopSound( snd )

    anotar( quien( ghost ) .. "  caceria CALLADA  ( " .. tostring( motivo or "sin motivo declarado" ) .. " )" )

    return true

end

-- Declarada antes de definirse porque se llama a si misma desde el timer: sin
-- esto el `local` de adentro seria un upvalue nil en la primera vuelta y la
-- caceria sonaria UNA vez -- que se oye exactamente igual que "los clips no
-- encadenan", pero por un motivo que no tiene nada que ver con el sonido.
local sonarCaceria

function sonarCaceria( ghost )
    if not IsValid( ghost ) then return false end

    -- Las tres puertas, cada una con SU motivo. "No suena" tiene causas
    -- distintas que desde afuera se oyen igual ( catalogo nº 49 ), y las tres
    -- terminan en la bitacora diciendo cual fue.
    if not cvHuntVoz:GetBool() then
        return pararCaceria( ghost, "phantasmagoria_ghost_huntvoz esta en 0 ( el CONTROL )" )

    end

    -- `term_Dead` lo pone la base en la primera linea de su OnKilled
    -- ( damageandhealth.lua:676 ). Se mira ademas del OnKilled propio porque
    -- entre la muerte y el Remove pasan varios frames, y en ese hueco el timer
    -- puede vencer: un cadaver que sigue cazando es el peor de los sintomas
    -- posibles, porque suena a mecanica y no a bug.
    if ghost.term_Dead then
        return pararCaceria( ghost, "el fantasma esta muerto" )

    end

    if not ghost:phantom_IsHunting() then
        return pararCaceria( ghost, "el hunt se apago" )

    end

    -- ⚠ LA CUARTA PUERTA ES EL MODO, Y SE LEE EN CADA VUELTA A PROPOSITO. Es el
    -- *"para que algunos hagan ruido de hunt y otros no"* del autor. Se resuelve
    -- aca y no en el `Start` porque asi un `cazavoz mudo` tipeado en el medio de
    -- una caceria la calla en la vuelta siguiente sin que nadie re-prenda el
    -- hunt -- y el motivo entra en la bitacora, que es lo que distingue *lo
    -- pusieron mudo* de *el bloque dejo de andar*.
    local modo, porQueModo = ghost:phantom_HuntVoiceMode()

    if modo == "mudo" then
        return pararCaceria( ghost, "modo MUDO -- " .. tostring( porQueModo ) )

    end

    local voz       = ghost:phantom_EventVoice()
    local banco     = HUNT[ voz ]
    local degradado = ""

    if not istable( banco ) or #banco <= 0 then
        banco     = HUNT_NEUTRA
        degradado = "  ( DEGRADADO: la voz " .. tostring( voz ) .. " no tiene banco de caceria; " ..
            "suena el neutro, que es ESTEREO y no se espacializa )"

    end

    if #banco <= 0 then
        return pararCaceria( ghost, "ni la voz " .. tostring( voz ) .. " ni el banco neutro tienen un clip" )

    end

    ---------------------------------------------------------------------------
    -- QUE CLIP -- Y ACA ES DONDE LOS DOS MODOS SE SEPARAN
    ---------------------------------------------------------------------------
    local idx

    if modo == "uno" then
        -- ⭐ UN FANTASMA, UN ARCHIVO. Se sortea la PRIMERA vez y se guarda; de
        -- ahi en adelante todas las vueltas re-emiten el mismo. Es lo que el
        -- autor describio de Phasmophobia y lo que vuelve la voz *de ese
        -- fantasma* en vez de *del banco*.
        --
        -- ⚠ SE GUARDA EL INDICE Y SE **RE-VALIDA**, no se guarda la ruta suelta.
        -- El indice apunta a `banco`, y `banco` depende de la VOZ: si la voz
        -- cambiara ( `phantasmagoria_ghost_type banshee` sobre un fantasma vivo,
        -- que es un camino real y ya medido ) un indice viejo apuntaria a otro
        -- clip -- o a ninguno, si el banco nuevo es mas corto. Se comprueba que
        -- siga en rango y que la ruta guardada sea la de ese indice; si no, se
        -- vuelve a sortear y SE DICE.
        idx = ghost.phantom_huntFijo

        local fila = idx and banco[ idx ]

        if not fila or ( ghost.phantom_huntFijoRuta and fila[ 1 ] ~= ghost.phantom_huntFijoRuta ) then
            idx = math.random( #banco )

            ghost.phantom_huntFijo     = idx
            ghost.phantom_huntFijoRuta = banco[ idx ][ 1 ]
            ghost.phantom_huntFijoWhy  = fila and
                "RE-SORTEADO: el clip anterior no pertenece al banco de la voz " .. tostring( voz ) or
                "sorteado una vez, al entrar en hunt por primera vez"

        end
    else
        -- `varios` -- el encadenado de la r1, que corrio 11 de 11 en juego y
        -- queda como CONTROL y como el camino de los Alternates.
        --
        -- ⚠ NO REPETIR EL CLIP ANTERIOR, y sorteando sobre los OTROS n-1 en vez
        -- de volver a tirar hasta que salga otro: un reintento es un bucle cuya
        -- cota superior no esta escrita en ninguna parte, y con un banco de un
        -- solo clip no termina nunca. Esto elige uniforme entre los n-1
        -- restantes y corrige el indice, que es la misma cuenta hecha una vez.
        local n = #banco
        idx = math.random( n )

        if n > 1 and ghost.phantom_huntIdx then
            idx = math.random( n - 1 )
            if idx >= ghost.phantom_huntIdx then idx = idx + 1 end

        end
    end

    local clip = banco[ idx ]
    local ruta, dur, lufs = clip[ 1 ], clip[ 2 ], clip[ 3 ]

    -- El anterior se para POR NOMBRE ademas de por canal. `CHAN_VOICE` ya
    -- reemplaza lo que este sonando ahi, pero eso es una promesa del engine
    -- sobre un canal compartido; el `StopSound` nombra el archivo y no depende
    -- de ella.
    local previo = ghost.phantom_huntSnd
    if previo then ghost:StopSound( previo ) end

    -- ⚠ LA NIVELACION SOLO BAJA, y el `math.min( 1, ... )` no es una precaucion
    -- de estilo: tres clips del banco estan POR DEBAJO del objetivo y su factor
    -- da mayor que 1. Un `volume` > 1 en `EmitSound` no sube nada -- el engine
    -- lo satura -- pero si lo escribieramos sin el clamp, el reporte diria
    -- "x1,45" sobre un clip que suena exactamente igual que sin nivelar, y eso
    -- es un numero que afirma un efecto que no existe.
    local vol = 1

    if cvHuntVozNivel:GetBool() and isnumber( lufs ) then
        vol = math.min( 1, 10 ^ ( ( HUNT_LUFS_OBJETIVO - lufs ) / 20 ) )

    end

    -- ⚠⚠ PITCH **100 CLAVADO**, Y NO ES UN OLVIDO. Las otras familias sortean
    -- 96-104 para que el banco no se oiga como una tabla. Aca el pitch cambia el
    -- LARGO REAL del clip -- la propia base lo divide,
    -- `duration / ( pitch / 100 )` en spokenlines.lua:29 -- y el largo esta
    -- escrito a mano en la tabla de arriba porque `SoundDuration` no es
    -- confiable server-side sobre `.ogg`. Con pitch sorteado el encadenado se
    -- corre hasta un 4 %: sobre los 64,92 s del clip mas largo son 2,6 s de
    -- silencio o de solape POR VUELTA, y el error se ACUMULA porque cada vuelta
    -- agenda la siguiente. Un desfasaje que crece se oye recien despues de
    -- varios minutos de hunt, o sea nunca en una prueba corta.
    --
    -- ⚠⚠⚠ Y EN EL MODO `uno` ESO DEJA DE SER UNA PRECAUCION Y PASA A SER LA
    -- CONDICION DE QUE EL LOOP EXISTA: el empalme cae siempre en el mismo punto
    -- del mismo archivo, asi que un desfasaje que crece se oye como un hueco que
    -- se agranda vuelta a vuelta. Encadenando clips distintos se disimulaba.
    ghost:EmitSound( ruta, cvHuntVozLvl:GetInt(), 100, vol, CHAN_VOICE )

    ghost.phantom_huntSnd   = ruta
    ghost.phantom_huntIdx   = idx
    ghost.phantom_huntVol   = vol
    ghost.phantom_huntHasta = CurTime() + dur

    local id = idCaceria( ghost )
    ghost.phantom_huntTimer = id

    timer.Create( id, dur + ( HUNT_GAP[ modo ] or 0 ), 1, function()
        if not IsValid( ghost ) then timer.Remove( id ) return end

        sonarCaceria( ghost )

    end )

    -- La bitacora NOMBRA EL ARCHIVO, por lo mismo que `EV.sound`: cuando el
    -- engine escriba `Invalid sample rate` o `Missing sound` en la linea de al
    -- lado, las dos lineas tienen que poder aparearse. Un "caceria voz 2" pelado
    -- no dice cual de los siete.
    --
    -- ⚠ Y NOMBRA EL MODO. En `uno` esta linea se repite igual cada vuelta -- es
    -- el mismo archivo -- y sin el modo escrito, un lector de la bitacora leeria
    -- eso como "el encadenado se trabo", que es el sintoma opuesto al correcto.
    anotar( quien( ghost ) .. "  caceria voz " .. tostring( voz ) .. " [" .. modo .. "]  " ..
        string.GetFileFromFilename( ruta ) .. string.format( "  %.2f s", dur ) ..
        ( vol < 1 and string.format( "  vol %.2f", vol ) or "" ) .. degradado )

    return true

end

--[[
    phantom_HuntVoiceStart() -> true si a partir de ahora suena

    IDEMPOTENTE A PROPOSITO: si ya hay un clip en el aire NO lo corta. Sin eso,
    cualquier llamada repetida a `phantom_SetHunting( true )` -- que es lo que
    hace el andamio de consola y lo que va a hacer la cordura de Diseno 19 --
    reiniciaria la caceria desde el principio cada vez, y el sintoma seria un
    fantasma que "traba" la respiracion. La invariante que se sostiene es
    *en hunt suena algo*, no *cada llamada arranca un clip*.
]]
function ENT:phantom_HuntVoiceStart()
    if self.phantom_huntSnd then return true end

    sonarCaceria( self )

    return self.phantom_huntSnd ~= nil

end

function ENT:phantom_HuntVoiceStop( motivo )
    return pararCaceria( self, motivo )

end

--[[
    LA MUERTE, POR EL GANCHO QUE LA BASE DEJO PARA ESTO.

    `AdditionalOnKilled` es un stub declarado por la base con ese comentario
    ( damageandhealth.lua:664, *"stub! for your convenience"* ) y lo llama su
    `OnKilled` en :686. Se usa ese y NO un override de `OnKilled`, que es la
    Trampa 1 de este addon: la implementacion default de la base NO esta vacia y
    un override que no encadene mata mecanica en silencio.

    ⚠ SE ENCADENA IGUAL, aunque HOY el de la base sea el stub vacio. Cuesta una
    linea y cubre el dia que la base le ponga cuerpo -- que es exactamente la
    forma del defecto que server.lua:1100-1108 describe: *"hoy no duele porque no
    declaramos el campo, y por eso mismo el defecto seria invisible"*.

    ⚠ Y NO ALCANZA CON EL BORRADO DE LA ENTIDAD: entre la muerte y el Remove hay
    frames ( la base arma el ragdoll y corre hooks ), y ahi el timer puede vencer.
    Por eso `sonarCaceria` mira ademas `term_Dead` en cada vuelta: son dos redes
    para el mismo hueco y ninguna de las dos cubre sola los dos extremos.
]]
function ENT:AdditionalOnKilled( dmg )
    self:phantom_HuntVoiceStop( "el fantasma murio" )

    local base = self.BaseClass

    if base and isfunction( base.AdditionalOnKilled ) then
        return base.AdditionalOnKilled( self, dmg )

    end
end

---------------------------------------------------------------------------
-- ⚠ LA PERILLA TIENE QUE ALCANZAR A LOS QUE YA EXISTEN -- CATALOGO Nº 26
---------------------------------------------------------------------------
-- Es el defecto que este mismo archivo cerro el 2026-08-17 con
-- `phantom_ResetVoice`: *una perilla que no alcanza a los sujetos que ya existen
-- se lee como "el control no funciona" o, peor, como "el mecanismo no existe"*.
-- Sin este callback, `phantasmagoria_ghost_huntvoz 1` tipeado con el fantasma ya
-- cazando no haria nada hasta el proximo cambio de hunt, y el que mide
-- concluiria que el bloque entero no anda. Con el, la perilla es un A/B de
-- verdad: se puede prender y apagar SOBRE EL MISMO hunt.
cvars.AddChangeCallback( "phantasmagoria_ghost_huntvoz", function( _, _, nuevo )
    local prendida = ( tonumber( nuevo ) or 0 ) ~= 0

    if not isfunction( PHANTASMAGORIA.EachGhost ) then return end

    PHANTASMAGORIA.EachGhost( function( ghost )
        if not ghost:phantom_IsHunting() then return end

        if prendida then
            ghost:phantom_HuntVoiceStart()

        else
            ghost:phantom_HuntVoiceStop( "phantasmagoria_ghost_huntvoz paso a 0 en vivo" )

        end
    end )

end, "phantasmagoria_huntvoz_alcanza_a_los_vivos" )

-- ⚠ LAS OTRAS DOS PERILLAS TAMBIEN TIENEN QUE ALCANZAR AL QUE YA ESTA CAZANDO, y
-- por un motivo mas fuerte que la de arriba: las dos cambian **como suena el clip
-- que ya esta en el aire**, no si suena. Sin esto, tipear `huntvoznivelar 1` en
-- medio de una caceria no cambiaria nada hasta que el clip actual termine -- y el
-- clip actual puede durar **64,92 s**. El que mide oiria "no hizo nada", movería
-- otra cosa, y cuando el cambio finalmente entrara se lo atribuiria a lo otro.
--
-- ⚠ SE RE-EMITE, no se re-sortea: `Stop` + `Start` sobre el modo `uno` vuelve al
-- MISMO archivo, porque el clip fijo vive en `phantom_huntFijo` y esto no lo
-- toca. Lo unico que se pierde es la posicion adentro del clip, y eso es
-- inevitable: `EmitSound` no tiene seek.
local function reemitirVivos( porQue )
    if not isfunction( PHANTASMAGORIA.EachGhost ) then return end

    PHANTASMAGORIA.EachGhost( function( ghost )
        if not ghost:phantom_IsHunting() then return end
        if not ghost.phantom_huntSnd then return end

        ghost:phantom_HuntVoiceStop( porQue )
        ghost:phantom_HuntVoiceStart()

    end )
end

cvars.AddChangeCallback( "phantasmagoria_ghost_huntvoznivelar", function()
    reemitirVivos( "cambio phantasmagoria_ghost_huntvoznivelar: se re-emite el MISMO clip" )

end, "phantasmagoria_huntvoznivelar_alcanza_a_los_vivos" )

cvars.AddChangeCallback( "phantasmagoria_ghost_huntvozlvl", function()
    reemitirVivos( "cambio phantasmagoria_ghost_huntvozlvl: se re-emite el MISMO clip" )

end, "phantasmagoria_huntvozlvl_alcanza_a_los_vivos" )

-- ⚠ EL MODO **NO** LLEVA CALLBACK, y la omision es deliberada. Se lee en cada
-- vuelta del loop ( `sonarCaceria` ), asi que ya alcanza a los vivos solo -- y
-- re-emitir al cambiarlo cortaria el clip en curso para poner el mismo archivo
-- desde el principio, que es justo el "traba la respiracion" que la idempotencia
-- del `Start` existe para evitar. La unica diferencia es que `mudo` tarda hasta
-- una vuelta en hacer efecto, y el comando de abajo lo resuelve callando a mano.

---------------------------------------------------------------------------
-- EL ANDAMIO DEL FLAG POR FANTASMA
---------------------------------------------------------------------------
-- Pedido del autor: *"un flag para cada fantasma"*, para que *"algunos hagan
-- ruido de hunt y otros no"*. La convar global no alcanza para eso -- es global
-- --, y el rasgo del tipo tampoco, porque exige que los que uno quiera separar
-- tengan tipos distintos. Este comando setea el override POR ENTIDAD, que es el
-- eslabon ① de la prioridad.
--
-- ⚠ ES UN ANDAMIO Y ESTA DECLARADO COMO TAL. El lugar definitivo de "este tipo
-- de fantasma no hace ruido de caceria" es el rasgo `huntVoice` en
-- `ghost_flags.lua`; esto existe para poder PROBARLO hoy, con dos fantasmas al
-- lado, sin inventarle un rasgo a un tipo que la fuente no describe asi.
--
-- ⚠ `mudo` CALLA EN EL ACTO y no en la vuelta siguiente. Sin eso, el comando se
-- oiria como que no hizo nada durante hasta 64,92 s -- el clip mas largo del
-- banco --, que es exactamente la forma de falla que el comentario de las
-- perillas de arriba describe.
PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_cazavoz", function( ply, _, args )
    local say = PHANTASMAGORIA.MakeSay( ply )
    local arg = string.lower( string.Trim( ( args and args[ 1 ] ) or "" ) )

    if arg ~= "auto" and not MODOS[ arg ] then
        say( "[Phantasmagoria] uso: phantasmagoria_ghost_cazavoz uno|varios|mudo|auto" )
        say( "    uno     UN clip sorteado una vez y loopeado toda la partida ( Phasmophobia )" )
        say( "    varios  encadena clips distintos sin repetir el anterior ( la r1 -- es el CONTROL )" )
        say( "    mudo    este fantasma no hace ruido de caceria" )
        say( "    auto    saca el override y manda el tipo, o la convar, o el default" )
        say( "" )
        say( "    Toca a TODOS los fantasmas vivos. Para separar dos, spawnear uno, tipear," )
        say( "    spawnear el otro y volver a tipear: el override queda pegado a cada entidad." )

        local found = PHANTASMAGORIA.EachGhost( function( ghost )
            local modo, porQue = ghost:phantom_HuntVoiceMode()

            say( "    " .. quien( ghost ) .. "  modo " .. modo .. "   ( " .. tostring( porQue ) .. " )" )

        end )

        if found <= 0 then say( "    no hay ningun fantasma vivo." ) end
        return

    end

    local found = PHANTASMAGORIA.EachGhost( function( ghost )
        ghost.phantom_huntVozModo = ( arg ~= "auto" ) and arg or nil

        local modo, porQue = ghost:phantom_HuntVoiceMode()

        if modo == "mudo" then
            ghost:phantom_HuntVoiceStop( "phantasmagoria_ghost_cazavoz mudo" )

        elseif ghost:phantom_IsHunting() then
            -- Estaba mudo y dejo de estarlo: hay que arrancarlo, porque el loop
            -- se apago y no hay ninguna vuelta agendada que lo vuelva a mirar.
            ghost:phantom_HuntVoiceStart()

        end

        say( "    " .. quien( ghost ) .. "  modo -> " .. modo .. "   ( " .. tostring( porQue ) .. " )" )

    end )

    if found <= 0 then say( "[Phantasmagoria] no hay ningun fantasma vivo." ) end

end, "ANDAMIO. Modo de la voz de caceria POR FANTASMA: uno ( un clip loopeado, el default ) - " ..
    "varios ( encadena, el control ) - mudo ( sin ruido de caceria ) - auto ( saca el override ). " ..
    "Sin argumento imprime el modo de cada uno y quien lo decidio." )

---------------------------------------------------------------------------
-- ELEGIR EL CLIP A MANO -- Y NO ES UN LUJO, ES LO QUE VUELVE CORRIBLE UNA FILA
---------------------------------------------------------------------------
-- El banco tiene **12,3 LU de dispersion medida** y los dos extremos son los que
-- hay que oir para decidir si hay que normalizar los `.ogg`:
-- `voice_2_loop_03` y `voice_2_grim` a -30 LUFS contra `voice_1_loop_04` a -18,2.
--
-- ⚠ SIN ESTE COMANDO, ESA FILA DE LA PLANILLA DEPENDE DE UN SORTEO: habria que
-- spawnear fantasmas hasta que salga el clip flojo -- una chance de 1 en 7 por
-- spawn --, y **un check que depende de un sorteo no es un check**. Es la misma
-- leccion que la convar de peso de los eventos, escrita al principio de este
-- archivo: *"sin el, un check de 'el fantasma tira cosas' tendria que esperar a
-- que el peso salga favorecido"*.
--
-- ⚠ Y SOLO TIENE SENTIDO EN EL MODO `uno`, que es el unico que guarda un clip
-- fijo. En `varios` la vuelta siguiente lo pisa, asi que en vez de fingir que
-- funciono se dice -- un comando que acepta callado una orden que no puede
-- cumplir es el nº 63 con otra cara.
PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_cazaclip", function( ply, _, args )
    local say = PHANTASMAGORIA.MakeSay( ply )
    local arg = string.lower( string.Trim( ( args and args[ 1 ] ) or "" ) )
    local n   = tonumber( arg )

    if arg ~= "auto" and not n then
        say( "[Phantasmagoria] uso: phantasmagoria_ghost_cazaclip <n>|auto" )
        say( "    Fija a mano QUE clip del banco de su voz loopea cada fantasma vivo." )
        say( "    auto = lo vuelve a sortear." )
        say( "" )

        for _, voz in ipairs( { 1, 2 } ) do
            say( "    voz " .. voz .. ":" )

            for i, c in ipairs( HUNT[ voz ] or {} ) do
                say( string.format( "      %d  %-24s %6.2f s   %6.1f LUFS", i,
                    string.GetFileFromFilename( c[ 1 ] ), c[ 2 ], c[ 3 ] or 0 ) )

            end
        end

        return

    end

    local found = PHANTASMAGORIA.EachGhost( function( ghost )
        local modo = ghost:phantom_HuntVoiceMode()

        if modo ~= "uno" then
            say( "    " .. quien( ghost ) .. "  SALTEADO: esta en modo '" .. modo ..
                "', que no guarda un clip fijo. Ponerlo en 'uno' primero." )
            return

        end

        if arg == "auto" then
            ghost.phantom_huntFijo     = nil
            ghost.phantom_huntFijoRuta = nil
            ghost.phantom_huntFijoWhy  = nil

            say( "    " .. quien( ghost ) .. "  clip -> se vuelve a sortear" )

        else
            local voz   = ghost:phantom_EventVoice()
            local banco = HUNT[ voz ] or {}

            if not banco[ n ] then
                say( "    " .. quien( ghost ) .. "  el banco de la voz " .. tostring( voz ) ..
                    " tiene " .. #banco .. " clips: " .. n .. " no existe." )
                return

            end

            ghost.phantom_huntFijo     = n
            ghost.phantom_huntFijoRuta = banco[ n ][ 1 ]
            ghost.phantom_huntFijoWhy  = "FORZADO a mano ( phantasmagoria_ghost_cazaclip " .. n .. " )"

            say( "    " .. quien( ghost ) .. "  clip -> " ..
                string.GetFileFromFilename( banco[ n ][ 1 ] ) ..
                string.format( "  ( %.1f LUFS )", banco[ n ][ 3 ] or 0 ) )

        end

        -- Se re-emite para que el cambio se oiga YA. Sin esto habria que esperar
        -- a que termine el clip anterior, y el mas largo dura 64,92 s: el
        -- comando se leeria como que no hizo nada.
        if ghost:phantom_IsHunting() then
            ghost:phantom_HuntVoiceStop( "phantasmagoria_ghost_cazaclip" )
            ghost:phantom_HuntVoiceStart()

        end
    end )

    if found <= 0 then say( "[Phantasmagoria] no hay ningun fantasma vivo." ) end

end, "ANDAMIO. Fija a mano que clip del banco loopea cada fantasma ( modo 'uno' ). Sin argumento " ..
    "lista los dos bancos con su largo y su sonoridad medida. auto lo vuelve a sortear." )

---------------------------------------------------------------------------
-- EL INSTRUMENTO
---------------------------------------------------------------------------
-- ⚠ NO SE LLAMA COMO NINGUNA CONVAR. `phantasmagoria_ghost_huntvoz` YA es una
-- convar de este archivo, y un concommand homonimo queda inalcanzable en
-- silencio -- la guarda de `PHANTASMAGORIA.AddCommand` lo volveria un error
-- ruidoso, pero el nombre se elige bien de entrada.
--
-- ⚠⚠ Y EXISTE TAMBIEN PORQUE `phantasmagoria_ghost_ev` **NO EXISTE**. El bloque
-- de la voz, mas arriba en este archivo, cierra diciendo *"El reporte de
-- `phantasmagoria_ghost_ev` lo imprime"* -- y ese comando no esta registrado en
-- ninguna parte del addon ( censo sobre `PHANTASMAGORIA.AddCommand`: 16 usos y
-- ninguno es ese ). O sea que el motivo por el que se eligio cada voz, que ese
-- bloque se tomo el trabajo de guardar en `phantom_evVoiceWhy`, no habia forma
-- de leerlo en juego.
--
-- *Un comentario que cita un instrumento no prueba que el instrumento exista.*
PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_caceria", function( ply )
    local say = PHANTASMAGORIA.MakeSay( ply )

    say( "[Phantasmagoria] LA VOZ DE LA CACERIA" )
    say( "  phantasmagoria_ghost_huntvoz     " ..
        ( cvHuntVoz:GetBool() and "1 ( puesta )" or "0 ( CONTROL: el hunt es mudo )" ) )
    -- ⚠ EL NIVEL SE IMPRIME CON LO QUE **NO** HACE. Es la perilla con la que el
    -- autor decidio la brecha de sonoridad, y sube los catorce clips por igual:
    -- sin esta linea, la de abajo -- que imprime la brecha por banco -- se leeria
    -- como algo que el nivel deberia haber arreglado.
    say( "  phantasmagoria_ghost_huntvozlvl  " .. cvHuntVozLvl:GetInt() ..
        "  ( SNDLVL; sube el alcance de TODOS los clips por igual, no la brecha entre ellos )" )
    say( "  phantasmagoria_ghost_huntvozmodo " .. tostring( cvHuntVozModo:GetString() ) ..
        "   ( el default global; el fantasma y su tipo mandan por encima )" )
    say( "  phantasmagoria_ghost_huntvoznivelar " ..
        ( cvHuntVozNivel:GetBool() and
            ( "1 ( bajando todo a " .. HUNT_LUFS_OBJETIVO .. " LUFS )" ) or
            "0 ( CONTROL: como suena sin nivelar )" ) )

    -- EL DENOMINADOR VA IMPRESO. Un "suena la voz 2" no vale nada si nadie sabe
    -- sobre cuantos clips habia, y un banco que quedo en cero se lee igual que
    -- un fantasma callado.
    --
    -- ⚠ Y VA LA **DISPERSION DE SONORIDAD**, que es el dato que el autor
    -- encontro con el oido en la r1 ( *"ese loop se siente mas bajito"* ). Con
    -- el modo `uno` deja de ser estetico: al fantasma le toca UN clip para toda
    -- la partida, asi que la brecha entre el mas fuerte y el mas flojo del banco
    -- es, literalmente, cuanto puede variar la caceria entre dos partidas.
    for _, voz in ipairs( { 1, 2 } ) do
        local banco = HUNT[ voz ] or {}
        local total, lo, hi = 0, nil, nil

        for _, c in ipairs( banco ) do
            total = total + c[ 2 ]

            if isnumber( c[ 3 ] ) then
                lo = ( not lo or c[ 3 ] < lo ) and c[ 3 ] or lo
                hi = ( not hi or c[ 3 ] > hi ) and c[ 3 ] or hi

            end
        end

        say( string.format( "  banco voz %d                      %d clips, %.1f s de material%s",
            voz, #banco, total,
            ( lo and hi ) and string.format( "   sonoridad %.1f a %.1f LUFS ( %.1f LU de brecha )",
                lo, hi, hi - lo ) or "" ) )

    end

    say( "  banco NEUTRO                     " .. #HUNT_NEUTRA ..
        " clip ( breath_1, ESTEREO: no se espacializa. Solo si el banco de la voz queda vacio )" )
    say( "" )

    local found = PHANTASMAGORIA.EachGhost( function( ghost )
        -- ⚠⚠ SE LEE EL CAMPO CACHEADO Y **NO** SE LLAMA A `phantom_EventVoice()`,
        -- que era lo natural de escribir y esta mal: ese metodo no es un getter,
        -- es EL RESOLVEDOR -- sortea la voz y la GUARDA. Un instrumento que la
        -- llama le fija la voz al fantasma en el momento en que alguien tipea el
        -- comando, o sea que *mirar cambia al sujeto*. Es el catalogo nº 30, el
        -- instrumento que corrompe la pasada: la voz quedaria decidida antes de
        -- que el fantasma hablara, y una corrida en la que se miro el reporte
        -- temprano dejaria de ser comparable con una en la que no.
        --
        -- Que todavia no este resuelta es un ESTADO legitimo y se imprime como
        -- tal: un fantasma recien spawneado que no hablo ni cazo no tiene voz, y
        -- eso no es lo mismo que tener una y que el reporte no la sepa.
        local voz = ghost.phantom_evVoice

        say( "  " .. quien( ghost ) .. "  hunt " .. ( ghost:phantom_IsHunting() and "SI" or "NO" ) ..
            "   voz " .. ( voz and tostring( voz ) or "SIN RESOLVER ( no hablo ni cazo todavia )" ) )

        -- EL MOTIVO Y NO SOLO EL NUMERO: "salio voz 1" no distingue *la fijo el
        -- tipo* de *la fijo el modelo* de *la sorteo la moneda*, y las tres se
        -- ven igual en una consola.
        say( "        por que:  " .. tostring( ghost.phantom_evVoiceWhy or
            "todavia nadie la resolvio -- se decide en el primer evento de sonido o al entrar en hunt" ) )

        -- El modo y QUIEN lo decidio, por lo mismo que la voz: "salio mudo" no
        -- distingue el andamio del rasgo del tipo de la convar global.
        local modo, porQueModo = ghost:phantom_HuntVoiceMode()

        say( "        modo:     " .. modo .. "   ( " .. tostring( porQueModo ) .. " )" )

        -- ⚠ EL CLIP FIJO SE IMPRIME AUNQUE NO ESTE SONANDO, y es el dato que
        -- vuelve verificable el modo `uno`: sin el, "un fantasma un archivo" se
        -- comprueba escuchando tres minutos, y con el se comprueba leyendo dos
        -- renglones de dos corridas separadas. Es el mismo argumento por el que
        -- la voz guarda su motivo.
        if modo == "uno" and ghost.phantom_huntFijoRuta then
            say( "        su clip:  " .. string.GetFileFromFilename( ghost.phantom_huntFijoRuta ) ..
                "   ( " .. tostring( ghost.phantom_huntFijoWhy or "sin motivo declarado" ) .. " )" )

        elseif modo == "uno" then
            say( "        su clip:  todavia sin sortear -- se elige al entrar en hunt por primera vez" )

        end

        local snd = ghost.phantom_huntSnd

        if snd then
            local resta = ( ghost.phantom_huntHasta or 0 ) - CurTime()
            local vol   = ghost.phantom_huntVol or 1

            say( string.format( "        suena:    %s   quedan %.1f s%s",
                string.GetFileFromFilename( snd ), resta,
                vol < 1 and string.format( "   vol %.2f ( nivelado, -%.1f dB )",
                    vol, -20 * math.log( vol, 10 ) ) or "" ) )

        elseif modo == "mudo" then
            say( "        suena:    NADA, y esta bien: este fantasma esta en modo MUDO." )

        elseif not ghost:phantom_IsHunting() then
            say( "        suena:    NADA, y esta bien: no esta en hunt." )

        elseif not cvHuntVoz:GetBool() then
            say( "        suena:    NADA porque phantasmagoria_ghost_huntvoz esta en 0 ( el CONTROL )." )

        elseif ghost.term_Dead then
            say( "        suena:    NADA porque el fantasma esta muerto." )

        else
            say( "        suena:    NADA, y NO deberia: esta en hunt, vivo y con la perilla puesta." )
            say( "                  Mirar la bitacora por la ultima linea que diga 'caceria'." )

        end
    end )

    if found <= 0 then say( "  no hay ningun fantasma vivo." ) end

end, "Reporte de la voz de caceria: las dos perillas, el tamano de cada banco, y por cada fantasma " ..
    "su voz, QUIEN la decidio, que clip suena y cuanto le queda. Si no suena, dice por que." )

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
        vueltaT  = nil,      -- CurTime de la ultima vuelta: sin esto, `vueltas`
                             -- no distingue un timer sano de uno que murio
        disparos = 0,        -- despertadas ESPONTANEAS ( las del scheduler )
        forzados = 0,        -- despertadas del comando: NO acreditan al motor
        ultimaEspera = nil,  -- el intervalo SORTEADO, no el rango
        ultimoRate   = nil,  -- el rate con el que se dividio ESE sorteo
        ultimoRango  = nil,  -- { lo, hi } ya divididos
        ultimoMulHunt = nil, -- el multiplicador del hunt que se APLICO al
                             -- sortear. Se guarda el HECHO y no la condicion:
                             -- preguntar `phantom_Hunting` al imprimir describe
                             -- el presente y no el sorteo
        ultimaFuePrimera = nil,
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
--
-- ⚠ LA PRIORIDAD ES **tipo > modelo > sorteo**, Y EL ORDEN ES LA DECISION.
-- Escrito al reves --modelo antes que tipo-- un Banshee con el cuerpo del
-- Ghost_Male hablaria con voz grave, que es exactamente lo que la fuente
-- prohibe ( "Can only be female" ). El tipo es una regla del juego; el modelo es
-- de que cuerpo salio el sonido. Cuando las dos hablan, gana la regla.
--
-- ⚠ Y LOS DOS ESLABONES USAN **EL MISMO CAMPO** `voice`, que es lo que hace que
-- esto no sea un `if` disfrazado: el rasgo del tipo ( ghost_flags.lua ) y el
-- campo `voz` de la ficha del modelo ( ghost_models.lua ) valen 1 o 2 con el
-- mismo significado --el indice del archivo en el catalogo-- porque los dos
-- salen de la misma frase de la fuente: *"Can only be female, ghost model and
-- ghost name will reflect this"*. Un tipo que manana fije la 2 filtra el cuerpo
-- solo, sin tocar esta funcion.
--
-- EL CASO DEGENERADO, que es el normal: tipo sin rasgo `voice` ( 28 de 30 ) y
-- modelo sin ficha ( el cadaver de HL2, cualquier ajeno ), los dos a la vez.
-- Cae al sorteo de siempre y NO tira. Ninguna de las dos ramas inventa un
-- default: `flags.voice` vale 0 en el neutro y `VozDelModelo` devuelve nil.
--
-- ⚠ SE GUARDA EL MOTIVO, no solo el numero. "Salio voz 1" no distingue *la fijo
-- el tipo* de *la fijo el modelo* de *la sorteo la moneda*, y las tres se ven
-- igual en una consola. Sin el motivo, una fila que fuerza un Banshee con el
-- Male y lo oye femenino no prueba nada: la moneda tambien da 1 la mitad de las
-- veces. Lo imprime `phantasmagoria_ghost_caceria`.
--
-- ⚠ ACA DECIA `phantasmagoria_ghost_ev` Y ESE COMANDO **NUNCA EXISTIO** -- censo
-- sobre `PHANTASMAGORIA.AddCommand`: cero registros con ese nombre. O sea que
-- este campo, que se guarda a proposito para poder distinguir quien decidio la
-- voz, **no habia forma de leerlo en juego**, y el comentario afirmaba que si.
-- Se corrige el 2026-08-18, en la misma pasada en que se escribio el instrumento
-- que lo imprime de verdad. *Un comentario que cita un instrumento no prueba que
-- el instrumento exista* -- y dejarlo escrito una vez encontrado es propagar la
-- mentira al proximo lector, que es como llego hasta aca.
function ENT:phantom_EventVoice()
    if self.phantom_evVoice then return self.phantom_evVoice end

    local flags = self:phantom_EventFlags()
    local fija  = flags.voice

    -- 0 ( o nil ) significa "sorteada". 1 y 2 la fijan.
    if fija == 1 or fija == 2 then
        self.phantom_evVoice    = fija
        self.phantom_evVoiceWhy = "la fija el TIPO " .. tostring( self.phantom_TypeKey ) ..
            " ( rasgo voice = " .. fija .. " )"

    else
        -- El sexo del cuerpo. Con guarda por el mismo motivo que `hullDelModelo`:
        -- el registro lo monta un autorun compartido y no hay nada escrito que
        -- garantice que corrio antes que esta entidad. Si no esta, se sortea --
        -- que es el comportamiento anterior a este bloque-- y se dice.
        local delModelo = PHANTASMAGORIA and isfunction( PHANTASMAGORIA.VozDelModelo )
            and PHANTASMAGORIA.VozDelModelo( self:GetModel() ) or nil

        if delModelo then
            self.phantom_evVoice    = delModelo
            self.phantom_evVoiceWhy = "la fija el MODELO " .. tostring( self:GetModel() ) ..
                " ( campo voz = " .. delModelo .. " )"

        else
            self.phantom_evVoice    = math.random( 1, 2 )
            self.phantom_evVoiceWhy = "SORTEADA: ni el tipo " .. tostring( self.phantom_TypeKey ) ..
                " ni el modelo " .. tostring( self:GetModel() ) .. " la declaran"

        end
    end

    return self.phantom_evVoice

end

--[[
    ⚠ LA VOZ SE INVALIDA CUANDO CAMBIA EL TIPO, Y ESTE METODO EXISTE PARA ESO.

    Medido en juego el 2026-08-17: `phantasmagoria_ghost_type banshee` sobre un
    fantasma VIVO que ya habia hablado le cambiaba el tipo y **no** la voz. El
    resultado es el estado que la fuente prohibe -- tipo "Can only be female" con
    voz grave -- producido por la perilla que existe justamente para probar eso.

    Es el nº 26 del catalogo de controles: *una perilla que no alcanza a los
    sujetos que ya existen se lee como "el control no funciona" o, peor, como "el
    mecanismo no existe"* -- que es la conclusion inversa a la verdadera, porque
    en el spawn el mecanismo anda.

    ⚠ NO ROMPE LA DECISION DE LA r2. La voz se sigue sorteando UNA vez por
    fantasma y guardando; lo que se agrega es que un cambio de TIPO --que es el
    primer eslabon de la prioridad-- la vuelva a resolver. Sortear clip por clip
    seguiria estando mal; re-resolver cuando cambia la entrada que la decide es
    lo contrario de eso.

    ⚠ Y NO ES UN CAMINO NUEVO EN EL SPAWN: ahi `phantom_SetType` corre ANTES del
    primer evento de sonido, asi que `phantom_evVoice` es nil y esto no hace
    nada. El unico que lo ejerce es el andamio de consola.

    Devuelve la voz que se descarto ( o nil ), para que quien llame pueda DECIRLO.
    Un cambio silencioso en un valor que el jugador oye es indistinguible de un
    bug ( catalogo nº 49: *los avisos que valen son los que distinguen entre las
    causas* ).
]]
function ENT:phantom_ResetVoice( motivo )
    local vieja = self.phantom_evVoice
    if not vieja then return nil end

    self.phantom_evVoice    = nil
    self.phantom_evVoiceWhy = nil

    -- ⚠⚠ Y CON ELLA SE VA EL CLIP FIJO DE LA CACERIA ( r2, 2026-08-18 ). El
    -- modo `uno` guarda UN clip por fantasma y ese clip **pertenece al banco de
    -- una voz**: si la voz se descarta y el clip no, un `ghost_type banshee`
    -- sobre un fantasma vivo con cuerpo de Male lo dejaria hablando femenino y
    -- **cazando grave**, que es el mismo estado que la fuente prohibe y que este
    -- metodo existe para impedir -- sobreviviendo por la puerta de al lado.
    --
    -- Es el nº 61 del catalogo: *el arreglo de un cabo deja sin poder fallar a
    -- la fila que probaba el otro*. `phantom_ResetVoice` se escribio el
    -- 2026-08-17 y era completo ese dia; el campo nuevo lo volvio parcial sin
    -- que nada avisara.
    --
    -- ⚠ SE BORRA TAMBIEN EL `..Ruta`, que es la mitad que hace la re-validacion
    -- de `sonarCaceria` posible: con el indice en nil y la ruta puesta, la
    -- comprobacion de coherencia no tendria contra que comparar.
    self.phantom_huntFijo     = nil
    self.phantom_huntFijoRuta = nil
    self.phantom_huntFijoWhy  = nil

    -- `PHANTASMAGORIA.Print` y no `ghostPrint`: este archivo no tiene el local de
    -- server.lua, porque include() corre otro chunk y un local no cruza. Con
    -- guarda, para que un include roto no se convierta en un error de Lua
    -- adentro de un cambio de tipo.
    local decir = istable( PHANTASMAGORIA ) and PHANTASMAGORIA.Print

    if isfunction( decir ) then
        decir( "#", self:EntIndex(), " la voz ", vieja, " se DESCARTA ( ",
            tostring( motivo or "sin motivo declarado" ),
            " ). Se vuelve a resolver en el proximo evento de sonido.\n" )

    end

    return vieja

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
-- SIETE de los ocho emiten LEJOS del fantasma: el sonido sale del OBJETO ( el
-- prop que vuela, la puerta que cruje ) o de un PUNTO cercano. La regla no es
-- estetica -- un ruido que sale de la posicion exacta del fantasma es un
-- localizador gratis.
--
-- ⚠ LA EXCEPCION ES `sound`, Y ES UNA DECISION DEL AUTOR ( r1, en juego ):
-- *«las voces deberian ser del fantasma, no que las haga sonar donde no debe»*.
-- Una voz no es un ruido ambiente: es EL que la emite. Lo que quedo de la regla
-- vieja: el radio sigue colgando del fantasma, asi que la tesis del bloque no se
-- toca -- lo que cambia es de donde sale ESE sonido, no hasta donde llega la
-- actividad.
--
-- ⚠ Y la justificacion vieja hay que leerla por lo que era: decia que emitir en
-- el fantasma *«mata al spirit box, a la parabolica y a la caja musical»*, y las
-- TRES tienen hoy cero lineas de codigo. Defendia una decision presente con tres
-- mecanicas futuras. Si alguna se escribe y la voz de cerca la rompe, se revisa
-- ENTONCES, con la mecanica delante. *Una regla sostenida por codigo que no
-- existe no se puede falsar, y por eso sobrevive a la evidencia.*
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

---------------------------------------------------------------------------
-- ⚠⚠ LA MARCA DEL PHYSGUN, Y ES EL ARREGLO DE LA FILA 05 DE LA r2
---------------------------------------------------------------------------
-- El autor, en juego: *"Si te tira lo tomado con el physgun"*, con la linea
-- `OK -- 1 prop(s) tirado(s) ... ( ultimo prop_physics #63 a 181 u )` **sin
-- sufijo de vetados**, o sea `vetosN == 0`: el prop que tenia agarrado paso los
-- ocho vetos de `propVetado` y los cuatro filtros de `EV.throw`.
--
-- ⚠⚠ LO QUE DECIA ACA QUEDO REFUTADO EN JUEGO EL 2026-08-10 ( fila 04 de la r3 )
-- y se corrige diciendolo, porque tres parrafos de abajo se apoyaban en ello.
--
-- DECIA: *"`Entity:IsPlayerHolding()` **NO cubre la physgun**, y no es una lectura
-- de la wiki: esta MEDIDO EN JUEGO sobre artagdoll -- con el cuerpo agarrado del
-- pecho con la physgun, su conteo dio 'agarrados: 0 de 1'
-- ( `dev/other/artagdoll/ARTAGDOLL_CHANGELOG.md:2174-2182` )"*.
--
-- LO MEDIDO: el autor sostuvo un `prop_physics` **con la physgun** y el motivo
-- que imprimio el desglose fue `alguien lo tiene agarrado` -- el de
-- `IsPlayerHolding`, no el de esta marca. **Si la cubre.**
--
-- POR QUE LAS DOS MEDICIONES NO SE CONTRADICEN: artagdoll midio sobre un
-- **ragdoll** y esto es un **prop_physics**. Son dos sujetos distintos y el
-- comentario los trato como uno. *Una medicion solo refuta lo que sabe leer.*
--
-- CONSECUENCIA, y es la que importaba: mientras `IsPlayerHolding` corriera
-- primero, **este veto era codigo muerto**. Hoy es el unico que queda en pie
-- ( ver `propVetado` ), asi que la marca ya no es "la otra mitad": es la mitad.
--
-- ⚠ Y EL COMENTARIO QUE SOSTENIA ESA LINEA ERA FALSO EN DOS FORMAS, las dos
-- corregidas abajo: decia *"los TRES precedentes del taller lo filtran igual"* y
-- despues nombraba DOS -- y ninguno de los dos FILTRA. `him/server.lua:526` no
-- descarta nada, cambia un peso de chance; `corpus_cargo_capture.lua:914` es el
-- camino de SOLTAR un carry por +USE. Cero de los 16 call sites ajenos de
-- `IsPlayerHolding` en el workspace acompanan la llamada con una comprobacion de
-- physgun. *Un comentario que cuenta mal sus propios ejemplos es la senal mas
-- barata de que nadie los abrio.*
--
-- LA SENAL QUE SI EXISTE, y es la que artagdoll uso para cerrar el mismo caso:
-- los hooks del physgun. Se guarda **el jugador y no un booleano**, a proposito:
-- si `PhysgunDrop` no llegara a disparar ( una desconexion sosteniendo el prop ),
-- el Player queda NULL y el `IsValid` apaga el veto solo. Un `true` pegado seria
-- la marca PERMANENTE que ya nos costo una revision con `GetCreator`.
--
-- `OnPhysgunPickup` y no `PhysgunPickup`: el segundo es el que PREGUNTA si se
-- permite -- un prop protection puede vetarlo despues -- y el primero corre
-- cuando el agarre YA se concreto. Es el motivo textual de artagdoll
-- ( `gaze.lua:1465-1467` ).
--
-- ⚠ CUANTOS SUJETOS MAS VETA, porque esa es la pregunta que el veto de
-- `GetCreator` no supo contestar: como mucho UNO POR JUGADOR, y **solo mientras
-- dura el agarre**. La diferencia con aquel no es de tamano sino de NATURALEZA:
-- `creator` es permanente y lo escribe el spawnmenu al nacer, asi que su
-- conjunto era *"todo prop que alguna vez spawneo alguien"*, para siempre. Esta
-- marca vive entre dos hooks y el prop vuelve al pozo de candidatos solo.
hook.Add( "OnPhysgunPickup", "phantasmagoria_throw_physgun", function( ply, ent )
    if IsValid( ent ) then ent.PhantasmagoriaPhysgunHolder = ply end

end )

hook.Add( "PhysgunDrop", "phantasmagoria_throw_physgun", function( _ply, ent )
    if IsValid( ent ) then ent.PhantasmagoriaPhysgunHolder = nil end

end )

-- Lo que NO se toca, y por que cada uno. Es una lista negra CORTA porque la
-- blanca de arriba ya hace el trabajo grueso; estos son los que pasan la blanca
-- y aun asi no hay que mover.
--
-- ⚠ DEVUELVE DOS VALORES: ( motivo, muestra ). El motivo es CANONICO y sin datos
-- adentro porque el llamador lo usa de CLAVE para contar; la muestra es el
-- nombre concreto y va aparte. Metidos en el mismo string, "tiene dueno
-- ( Player [1][Nick] )" y "tiene dueno ( Player [2][Otro] )" son dos claves
-- distintas y el desglose se abre en una fila POR ENTIDAD -- que es lo contrario
-- de agrupar. *Una clave de agregacion con la identidad del sujeto adentro no
-- agrega: enumera.*
--
-- ⚠ CUATRO DE ESTOS MOTIVOS NO PUEDEN SALIR HOY, y se dice para que ninguna
-- fila los acredite:
--   "es el fantasma" / "es otro fantasma"  la LISTA BLANCA ( THROW_CLASSES )
--   "es inventario de Cargo"               corre antes y solo deja pasar
--                                          prop_physics y _multiplayer; ninguno
--                                          de los tres sujetos llega ahi.
--   "es equipamiento de Phantasmagoria"    por otro motivo: NADIE escribe todavia
--                                          `IsPhantasmagoriaEquipment`.
-- Los tres primeros dejan de ser inalcanzables el dia que THROW_CLASSES crezca;
-- el cuarto, el dia que exista el equipo ( Diseno 8 ). Por eso se escriben.
-- ⚠ Y la cuenta decia TRES: el cuarto se olvidaba porque su motivo es distinto,
-- que es justo la razon por la que hay que enumerarlos.
local function propVetado( ent, ghost )
    if ent == ghost then return "es el fantasma" end
    if ent.IsPhantasmagoriaGhost then return "es otro fantasma" end

    -- ⚠⚠⚠ ACA HABIA UN `IsPlayerHolding()` Y SE FUE POR DOS MOTIVOS DISTINTOS,
    -- uno del autor y uno medido. NO se borro por limpieza.
    --
    -- ( 1 ) DECISION DEL AUTOR ( r3, 2026-08-10 ): *"Nadie usa gravity gun y esta
    -- arma en HL2 hace 'inestable' a los props igualmente por lore del arma, si un
    -- fantasma quisiera pegarle o tratar de tirar el objeto tomado por el gravity
    -- gun deberia ser factible bajo la logica de Half Life 2."* O sea que un prop
    -- en la gravity gun **deja de estar vetado a proposito**.
    -- ⚠ Y ALCANZA TAMBIEN AL +USE, que el autor no nombro: era la misma linea la
    -- que cubria los dos. Se dice en vez de disimularlo -- un prop que llevas con
    -- E ahora tambien se puede volar.
    --
    -- ( 2 ) LA MEDICION QUE SOSTENIA EL ORDEN QUEDO REFUTADA EN JUEGO. El bloque
    -- de arriba afirmaba, en negrita y como MEDIDO, que `IsPlayerHolding()` **no
    -- cubre la physgun**. La fila 04 de la r3 lo dio vuelta: el autor sostuvo el
    -- prop **con la physgun** y el motivo que salio fue `alguien lo tiene
    -- agarrado`, que solo lo puede devolver esa llamada. O sea que SI la cubre, y
    -- por eso este `return` se comia al de abajo: **la rama de la physgun era
    -- codigo muerto** y las "dos claves para acreditar cada mitad" no podian
    -- cumplirse ni en principio.
    -- ⚠ Como se reconcilia con artagdoll, que midio lo contrario: aquello fue
    -- sobre un **ragdoll** agarrado del pecho, no sobre un `prop_physics`. *Una
    -- medicion solo refuta lo que sabe leer* -- el comentario tomo un resultado
    -- sobre ragdolls y lo cito como si hablara de props.
    if IsValid( ent.PhantasmagoriaPhysgunHolder ) then
        return "lo tienen con la PHYSGUN", tostring( ent.PhantasmagoriaPhysgunHolder )

    end

    -- ⚠⚠ ACA HUBO UN VETO POR `GetCreator()` Y DURO UNA REVISION. La idea era
    -- razonable -- "GetOwner esta vacio en los props de sandbox, el que guarda
    -- al creador es GetCreator" -- y el efecto era APAGAR LA CATEGORIA ENTERA:
    -- en GMod **todo prop spawneado del spawnmenu lleva creator**, asi que en un
    -- servidor sandbox real casi no queda sujeto y `throw` -- la categoria
    -- insignia del Poltergeist -- se queda muda con un motivo que suena
    -- razonable. Peor: corria ANTES que la masa y que los constraints, o sea que
    -- tapaba a los dos filtros que si distinguen.
    --
    -- La distincion que faltaba es SPAWNEAR contra CONSTRUIR. Lo que hay que
    -- proteger es el trabajo del jugador, y eso lo mide `HasConstraints` mas
    -- abajo, no el hecho de haber sacado un barril del menu.
    --
    -- *Un veto que no distingue "es de alguien" de "alguien lo armo" no protege
    -- al jugador: le apaga el juego.*
    --
    -- Queda CPPI, que no es lo mismo: cuando hay un prop protection instalado,
    -- el dueño es una politica EXPLICITA del operador del servidor y no un
    -- residuo del spawnmenu.
    --
    -- ⚠ Y LA CADENA VA CON `IsValid` PASO A PASO, NO CON `or`. `GetCreator()` y
    -- `GetOwner()` **no devuelven nil cuando no hay nadie: devuelven NULL**, que
    -- en Lua es TRUTHY. Un `a or b or c` corta en el primero y los de atras son
    -- codigo muerto -- que es exactamente lo que le paso a `GetOwner()` mientras
    -- `GetCreator` estuvo en el medio.
    local dueno = ent.CPPIGetOwner and ent:CPPIGetOwner() or nil

    if not IsValid( dueno ) then dueno = ent:GetOwner() end

    if IsValid( dueno ) then return "tiene dueno", tostring( dueno ) end

    -- ⚠⚠ ESTA LINEA NOMBRABA DOS CAMPOS QUE NO EXISTEN. Decia
    -- `ent.CargoItem or ent.cargo_ItemID`, y un grep sobre TODO el workspace
    -- devuelve una sola aparicion de cada uno: ESTA linea. Los marcadores de
    -- verdad son `CargoContainer` ( corpus_cargo_containers.lua:212 ) y
    -- `CargoEntry` ( corpus_cargo_inventory.lua:387, :1162 ).
    --
    -- ⚠ PERO EL ARREGLO **NO** HIZO ALCANZABLE AL VETO, y decir lo contrario
    -- seria acreditarlo de mas: HOY ningun escritor de esos dos campos produce
    -- una entidad de las dos clases de THROW_CLASSES -- `CargoEntry` cae sobre
    -- `corpus_cargo_item` y `CargoContainer` sobre lo que el servidor decida
    -- attachear. Se cambio un campo inexistente por uno real que **tampoco**
    -- alcanza al sujeto. Sigue escrito como poliza porque
    -- `CARGO.Containers.Attach` es API publica y su propio init la anuncia como
    -- *«turn any entity into a container»*: el dia que alguien la llame sobre un
    -- prop_physics, esto ya esta.
    --
    -- *Un veto que nombra un campo inexistente se lee igual que uno que anda; y
    -- uno que nombra el campo correcto sobre un sujeto que no llega, tambien.*
    if ent.CargoContainer or ent.CargoEntry then return "es inventario de Cargo" end

    -- Nuestro propio equipamiento plantado ( tripode, DOTS, sensor ): moverlo
    -- invalidaria una medicion del jugador, que es lo contrario de lo que un
    -- evento tiene que hacer.
    -- ⚠ HOY NO VETA A NADIE: `IsPhantasmagoriaEquipment` no lo escribe todavia
    -- ningun archivo del addon. Se deja escrito a proposito porque el equipo es
    -- Diseno 8, pero NO se puede acreditar en una corrida -- y una fila que lo
    -- de por probado estaria puntuando codigo sin estrenar.
    if ent.IsPhantasmagoriaEquipment then return "es equipamiento de Phantasmagoria" end

    -- Una construccion del jugador. Sin esto, el tope de masa se burla solo:
    -- veinte tablas de 5 kg soldadas pasan el filtro una por una y el fantasma
    -- arrastra la casa entera. Y peor que el efecto es el modo: soltar fuerza
    -- sobre un contraption puede reventarlo, que es una perdida de trabajo del
    -- jugador y no un susto.
    --
    -- ⭐ ESTE es el veto que protege al jugador, y por eso el de `GetCreator` no
    -- hacia falta: distingue lo que alguien ARMO de lo que alguien SACO del menu.
    if constraint.HasConstraints( ent ) then return "es parte de una construccion ( constraints )" end

    -- Un prop parenteado se mueve con su padre; empujarlo no lo mueve y ademas
    -- puede ser el hijo de OTRO addon colgado de algo -- la familia de entidades
    -- que la r22 encontro colgando del propio fantasma.
    if IsValid( ent:GetParent() ) then return "esta parenteado", tostring( ent:GetParent() ) end

    return nil

end

EV.throw = function( ghost, radio, fuerza, cuantos )
    local candidatos = {}
    local masaMax = cvMass:GetFloat()

    -- El desglose, no el total. Ver el encabezado de `propVetado`.
    --
    -- `muestras` guarda UN ejemplo por motivo: el nombre concreto no puede ir en
    -- la clave -- ahi fragmenta la cuenta -- pero perderlo tampoco sirve, porque
    -- la fila del sandbox pide justamente pegar QUIEN es el dueño.
    local vetos, muestras, vetosN = {}, {}, 0

    local function vetar( motivo, muestra )
        vetos[ motivo ] = ( vetos[ motivo ] or 0 ) + 1
        vetosN = vetosN + 1

        if muestra then muestras[ motivo ] = muestra end

    end

    for _, ent in ipairs( ents.FindInSphere( ghost:GetPos(), radio ) ) do
        if not IsValid( ent ) then continue end
        if not THROW_CLASSES[ ent:GetClass() ] then continue end

        local veto, muestra = propVetado( ent, ghost )
        if veto then vetar( veto, muestra ) continue end

        -- ⚠ ESTE `continue` NO CONTABA, y el desglose se leia como si contara
        -- todo lo descartado: `vetosN` no cerraba contra los prop_physics de la
        -- esfera y no habia forma de darse cuenta. *Un descarte silencioso
        -- adentro de un bucle que publica su cuenta rompe la cuenta.*
        local phys = ent:GetPhysicsObject()
        if not IsValid( phys ) then vetar( "sin PhysObj" ) continue end

        -- ⚠ UN PROP CONGELADO NO SE MUEVE Y NO AVISA. `ApplyForceCenter` sobre
        -- un physobj con la motion apagada no tira error: no pasa nada. Sin
        -- este filtro, un mapa lleno de props congelados por un jugador daria
        -- "evento disparado" en el reporte y silencio en el juego -- un verde
        -- que no corresponde a nada. El filtro ya existe escrito en la base
        -- ( motionoverrides.lua:182, con la meta cacheada ).
        --
        -- ⚠ SON DOS PREGUNTAS Y NO UNA, Y EN ESTE ORDEN. `IsMotionEnabled` es la
        -- del physgun ( lo congelo el jugador ); `IsMoveable` incluye ademas al
        -- que el motor tiene inmovil por otro motivo. El precedente que este
        -- comentario citaba -- motionoverrides.lua:182 -- usa LAS DOS, y aca
        -- estaba copiada la mitad.
        --
        -- Preguntadas al reves, TODO lo congelado con el physgun caeria en el
        -- rotulo del motor, y el desglose diria "el mapa esta trabado" sobre una
        -- escena que en realidad es "el jugador congelo todo". Son dos escenas
        -- con dos arreglos distintos: por eso se cuentan aparte y por eso el
        -- orden no es indiferente.
        if not phys:IsMotionEnabled() then vetar( "congelado por el jugador" ) continue end
        if not phys:IsMoveable() then vetar( "inmovil ( el motor )" ) continue end
        if phys:GetMass() > masaMax then vetar( "pesa mas de " .. math.Round( masaMax ) .. " kg" ) continue end

        candidatos[ #candidatos + 1 ] = ent

    end

    -- El desglose se arma una vez y lo usan las tres salidas. En la r1 el conteo
    -- de vetados se imprimia SOLO en la rama de fracaso, o sea en la unica
    -- escena que la fila del sandbox excluye por precondicion: para probar el
    -- veto hay que tener un prop lanzable Y uno vetado, y en esa escena el
    -- numero no salia. *Un contador que solo habla cuando no hay nada no puede
    -- acreditar el filtro.*
    --
    -- ⚠ De las tres salidas, DOS son alcanzables: "no habia candidatos" y el
    -- exito. La tercera ( ningun candidato sobrevivio al sorteo ) es defensiva y
    -- no tiene camino conocido -- haria falta que las entidades se invalidaran
    -- entre el censo y el bucle, en el mismo frame y sin cesion. Lleva el
    -- desglose por consistencia, no porque se la haya visto.
    local detalleVetos = ""

    if vetosN > 0 then
        local partes = {}

        for motivo, n in pairs( vetos ) do
            partes[ #partes + 1 ] = n .. " " .. motivo ..
                ( muestras[ motivo ] and ( " ( p.ej. " .. muestras[ motivo ] .. " )" ) or "" )

        end

        -- El orden es lexicografico y por lo tanto estable y reproducible, que
        -- es lo que hace comparables dos corridas. NO es por cantidad: dos
        -- pasadas de la misma escena tienen que escribir el mismo renglon.
        table.sort( partes )
        detalleVetos = "  ( " .. vetosN .. " vetado(s): " .. table.concat( partes, " · " ) .. " )"

    end

    if #candidatos <= 0 then
        return false, "no habia props fisicos movibles a " .. math.Round( radio ) .. " u" .. detalleVetos

    end

    local movidos = 0
    local total   = #candidatos
    local ultimo               -- el ultimo prop tirado, para el detalle

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
        ultimo  = prop

    end

    if movidos <= 0 then
        -- ⚠ EL CONTEO VA DE UNA COPIA TOMADA ANTES DEL BUCLE. La primera version
        -- imprimia `#candidatos + movidos`, y el bucle vacia la tabla con
        -- table.remove: con dos candidatos y movidos = 0 la linea decia
        -- literalmente "habia 0 candidato(s)" en una rama a la que solo se llega
        -- habiendo tenido al menos uno. *Un numero imposible al lado de un
        -- veredicto* es del catalogo, y delata el instrumento sin decir cual.
        return false, "habia " .. total .. " candidato(s) y ninguno sobrevivio al sorteo" .. detalleVetos

    end

    -- ⚠ LAS OTRAS SIETE CATEGORIAS NOMBRAN SU SUJETO Y SU DISTANCIA; esta era la
    -- unica que no, y por eso su linea de bitacora ( "4 prop(s) tirado(s) con
    -- fuerza x1.80" ) es la unica que no se puede cruzar contra nada: no dice
    -- QUE tiro ni DONDE. Sin eso, dos escenas muy distintas -- el fantasma en el
    -- cuarto con el jugador, y el fantasma tirando cosas a 600 u en otra
    -- habitacion -- escriben el mismo renglon.
    local donde = ""

    if IsValid( ultimo ) then
        donde = "  ( ultimo " .. ultimo:GetClass() .. " #" .. ultimo:EntIndex() .. " a " ..
            math.Round( ghost:GetPos():Distance( ultimo:GetPos() ) ) .. " u )"

    end

    return true, movidos .. " prop(s) tirado(s) con fuerza x" ..
        string.format( "%.2f", fuerza ) .. donde .. detalleVetos

end

---------------------------------------------------------------------------
-- knock -- el golpeteo, el evento mas barato y el que siempre funciona
---------------------------------------------------------------------------
-- No necesita props, ni puertas, ni luces, ni navmesh. Traza a una pared cerca
-- del fantasma y suena ahi. Es el piso del motor: si TODAS las demas categorias
-- quedan sin sujeto, esta contesta igual, y eso es deliberado -- un motor de
-- eventos que en un mapa pelado no hace absolutamente nada se lee como roto.
-- ⚠ UNA SOLA TABLA DE DESPACHO, Y LA BITACORA LEE DE ELLA. La version anterior
-- escribia la misma condicion en TRES lugares -- la eleccion del banco, el
-- rotulo del log y la rama de "al aire" -- y solo la primera decidia. Con eso,
-- arreglar la primera y olvidar las otras dos deja el log mintiendo con cara de
-- dato. La entrada de DEFAULT es explicita y no un `or`: *un default implicito
-- es una decision que nadie tomo y nadie puede auditar.*
local KNOCK_SUP = {
    puerta  = { banco = "knock_door",   carpeta = "event/knock ( puerta )"  },
    ventana = { banco = "knock_window", carpeta = "event/knock ( ventana )" },
    madera  = { banco = "impact_wood",  carpeta = "event/impact ( madera )" },
    metal   = { banco = "impact_metal", carpeta = "event/impact ( metal )"  },
    piedra  = { banco = "impact_stone", carpeta = "event/impact ( piedra )" },
}

-- El DEFAULT es madera y no "lo que sea": es el banco mas grande ( 12 clips ) y
-- el mas de casa. En un mapa sin surfaceprops bien puestos, TODO cae acá, y eso
-- hay que saberlo al leer una corrida.
local KNOCK_DEFAULT = "madera"

-- ⚠ EL MAPA DE MATERIALES ES LA MITAD **NO MEDIDA** DE ESTE BLOQUE, y va dicho.
-- `tr.MatType` sobre una entidad tiene precedente firme en la propia base
-- ( motionoverrides.lua:138, `traceResult.MatType == MAT_GLASS` ) y en HIM
-- ( server.lua:1166 ). Lo que **NO** esta medido en ninguno de los 153 `.lua`
-- del taller es si viene poblado sobre un BRUSH del mundo o sobre un prop
-- estatico horneado: los dos usos del taller que lo leen contra el suelo
-- ( glide_wheel/init.lua:413 y el fork de Trepang ) llevan los dos un fallback
-- `or 0`, o sea que se verian identicos si la senal no llegara nunca. Es
-- exactamente el falso verde del catalogo nº 42.
--
-- Por eso la fila 11 de la r3 imprime el CRUDO al lado del veredicto, y por eso
-- la mitad que contesta la pregunta del autor -- puerta y ventana -- sale de la
-- CLASE de `tr.Entity` y no del material: si MatType resultara mudo, se pierden
-- solo madera/metal/piedra y las paredes quedan tan sordas como hoy.
local KNOCK_MAT = {
    [ MAT_GLASS ]    = "ventana",
    [ MAT_WOOD ]     = "madera",
    [ MAT_METAL ]    = "metal",
    [ MAT_GRATE ]    = "metal",
    [ MAT_VENT ]     = "metal",
    [ MAT_CONCRETE ] = "piedra",
    [ MAT_TILE ]     = "piedra",
}

EV.knock = function( ghost, radio )
    local origen = ghost:GetPos() + Vector( 0, 0, 45 )
    local mejor, contra, porque, matCrudo, claseGolpeada

    for _ = 1, 8 do
        local ang = math.Rand( 0, 360 )
        local dir = Vector( math.cos( math.rad( ang ) ), math.sin( math.rad( ang ) ), math.Rand( -0.2, 0.3 ) )

        -- MASK_SOLID y no BRUSHONLY: es lo que hace que el trace pegue en la
        -- hoja de una puerta y en el panel de un func_breakable_surf, que son
        -- justo los dos sujetos de esta categoria. ( El mismo archivo usa
        -- MASK_SOLID_BRUSHONLY en puntoCerca, donde lo que interesa es el
        -- mundo. )
        local tr = util.TraceLine( {
            start  = origen,
            endpos = origen + dir * radio,
            mask   = MASK_SOLID,
            filter = ghost,
        } )

        if tr.Hit then
            mejor    = tr.HitPos + tr.HitNormal * 4
            matCrudo = tr.MatType

            -- LA ESCALERA: la CLASE gana al material, y el material gana al
            -- default. La clase es la unica de las tres que esta medida
            -- funcionando ( es la linea que ya distinguia la puerta ).
            local clase = IsValid( tr.Entity ) and tr.Entity:GetClass() or nil
            claseGolpeada = clase

            if clase and DOOR_CLASSES[ clase ] then
                contra, porque = "puerta", "la clase de la entidad"

            elseif clase == "func_breakable_surf" then
                -- La clase de una ventana rompible de Source. La base ya la
                -- trata como vidrio ( motionoverrides.lua:140 ) y el arma de
                -- punos tambien ( weapon_terminatorfists_term.lua:462 ).
                contra, porque = "ventana", "la clase de la entidad ( func_breakable_surf )"

            elseif matCrudo and KNOCK_MAT[ matCrudo ] then
                contra, porque = KNOCK_MAT[ matCrudo ], "el material del trace ( MatType " .. matCrudo .. " )"

            else
                contra = KNOCK_DEFAULT
                porque = "NINGUNA senal discrimino ( MatType " .. tostring( matCrudo ) ..
                    " ) -- cayo al default"

            end

            break

        end
    end

    -- Sin pared a la vista ( campo abierto ): suena al lado igual. Un fantasma
    -- afuera sigue haciendo ruido.
    --
    -- ⚠ ESTE ES UN TERCER CAMINO Y NO UN CASO DEL DEFAULT: no hubo superficie
    -- que clasificar, ni siquiera hay HitPos. Se rotula distinto para que una
    -- corrida pueda separar "no discrimino el material" de "no habia contra que
    -- golpear", que llevan a arreglos distintos.
    local pos = mejor or ( origen + VectorRand() * math.min( radio, 120 ) )

    if not mejor then
        contra, porque = KNOCK_DEFAULT, "al aire: los 8 traces fallaron, no habia superficie"

    end

    local sup   = KNOCK_SUP[ contra ] or KNOCK_SUP[ KNOCK_DEFAULT ]
    local snd   = elegir( SND[ sup.banco ] )

    if not snd then
        return false, "el banco '" .. sup.banco .. "' esta vacio ( contra " .. tostring( contra ) ..
            ", decidido por " .. tostring( porque ) .. " )"

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

    -- ⚠ EL DETALLE NOMBRA EL CLIP, Y ESA ES LA LINEA QUE HACIA INVISIBLE AL
    -- DEFECTO. El log viejo decia `( contra puerta, banco event/knock )` -- que
    -- era CIERTO -- mientras sonaba `window_4.ogg`. La variable `snd` existia y
    -- no aparecia en el retorno. Es la misma leccion que EV.sound pago en la r1
    -- con el sample rate: *dos lineas que hablan del mismo disparo y no se
    -- pueden aparear no son dos mediciones, es una.*
    return true, golpes .. " golpe(s) a " .. math.Round( ghost:GetPos():Distance( pos ) ) .. " u" ..
        "  [ " .. ( string.match( snd, "([^/]+)%.ogg$" ) or snd ) .. " ]" ..
        "  ( contra " .. contra .. ", banco " .. sup.carpeta .. "; lo decidio " .. porque ..
        ( claseGolpeada and ( "; la entidad es " .. claseGolpeada ) or "; pego en el MUNDO" ) .. " )"

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

---------------------------------------------------------------------------
-- EL PESTILLO -- las llaves, mudadas a una mecanica que SI tiene llaves
---------------------------------------------------------------------------
-- El autor, en la misma frase en que pidio sacarlas del ambiente: *"( podemos
-- hacer que el bot cierre puertas con pestillo y ahi aplicar esos sonidos )"*.
--
-- Y ya habia con que, sin inventar nada: `server_doors.lua` **lee** si una puerta
-- esta trabada ( `door:GetInternalVariable( "m_bLocked" )`, :281 y :293 ) y ya
-- **destraba** ( `door:Fire( "Unlock" )`, :1036, detras de la convar
-- `phantasmagoria_ghost_doorunlock` ). El pestillo es el gemelo de eso.
--
-- ⚠⚠ QUE `Fire( "Lock" )` FUNCIONE SOBRE LAS CLASES DE ESTE MAPA **NO ESTA
-- MEDIDO**: el engine es un tercero, y `Entity:Fire` con un input que la clase no
-- acepta **no tira error** -- `AcceptInput` devuelve false en silencio. Es
-- exactamente el pecado que este archivo ya documenta en `point_spotlight` y en
-- el encabezado de `EV.door`. Por eso no se afirma que trabo: se **relee
-- `m_bLocked` un tick despues** y la bitacora dice cual de las dos cosas paso.
--
-- ⚠⚠⚠ Y TRABAR UNA PUERTA ES UNA MECANICA CON CONSECUENCIA, NO UN SONIDO: si el
-- bot traba la unica salida de un cuarto, eso no es un susto, es un softlock. Los
-- tres limites son parte del diseno y estan puestos ANTES de la primera corrida,
-- no despues de que alguien quede encerrado:
--
--   PESTILLO_MAX    cuantas puede haber trabadas A LA VEZ por el fantasma. Con
--                   dos, siempre queda camino en una casa de 65 puertas.
--   PESTILLO_VIDA   segundos hasta que se suelta sola. Es el limite que de verdad
--                   protege: aunque las dos trabadas fueran las dos salidas del
--                   mismo cuarto, la espera tiene techo y es corta.
--   el comando      `phantasmagoria_ghost_pestillo soltar` las abre todas ya. Es
--                   la salida de emergencia del que esta jugando.
--
-- ⚠ Y NO SE TRABA UNA PUERTA QUE YA VENIA TRABADA. No es un caso raro: el mapa
-- trae puertas con llave y el fantasma las destraba para pasar. Sin esta regla, el
-- pestillo se acreditaria el trabado de otro y despues **la soltaria**, o sea que
-- el mecanismo "trabar puertas" terminaria DESTRABANDO el mapa.
local PESTILLO_MAX  = 2
local PESTILLO_VIDA = 45

-- Array y no diccionario por entidad: hay que poder recorrerlo en orden y podarlo
-- sin que una entidad borrada deje una clave colgada.
local PESTILLOS = {}

local function podarPestillos()
    for i = #PESTILLOS, 1, -1 do
        if not IsValid( PESTILLOS[ i ].door ) then table.remove( PESTILLOS, i ) end

    end

    return #PESTILLOS

end

local function trabada( door )
    return door:GetInternalVariable( "m_bLocked" ) == true

end

-- ⚠ LOS DOS ENUMS ESTAN INVERTIDOS ENTRE LAS DOS FAMILIAS, y eso ya esta medido
-- en `server_doors.lua:238-264`: `prop_door_rotating` usa `m_eDoorState` ( 0
-- cerrada ) y `func_door*` usa `m_toggle_state`, donde **0 es ABIERTA**. Copiar
-- una sola de las dos lecturas haria que el pestillo trabara puertas abiertas en
-- la mitad de las clases -- y una puerta abierta y trabada no se ve distinta
-- hasta que alguien intenta cerrarla.
local function cerrada( door )
    if door:GetClass() == "prop_door_rotating" then
        local s = door:GetInternalVariable( "m_eDoorState" )
        return s == 0 or s == 3

    end

    local s = door:GetInternalVariable( "m_toggle_state" )
    return s == 1 or s == 3

end

local function soltarPestillo( p, motivo )
    if not IsValid( p.door ) then return false end

    p.door:Fire( "Unlock" )

    if isfunction( PHANTASMAGORIA.SonarLlave ) then
        PHANTASMAGORIA.SonarLlave( "unlock", p.door:WorldSpaceCenter() )

    end

    anotar( string.format( "pestillo SUELTO -- %s #%d ( %s )",
        p.door:GetClass(), p.door:EntIndex(), motivo ) )

    return true

end

---------------------------------------------------------------------------
-- EL EVENTO DE PUERTAS
---------------------------------------------------------------------------
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

    ---------------------------------------------------------------------------
    -- ¿TRABAR EN VEZ DE ABRIR?
    ---------------------------------------------------------------------------
    -- Se decide ACA, antes de la guarda de `Use2`, y a proposito: el pestillo no
    -- pasa por `Use2` -- es un `Fire` directo --, asi que una base que no lo
    -- exponga no tiene por que apagar tambien esta mitad.
    --
    -- ⚠ LAS CUATRO CONDICIONES SE COMPRUEBAN EN ESTE ORDEN Y CADA UNA DICE QUE
    -- NO POR SU CUENTA. Un solo `if` con cuatro `and` habria dado un "no trabo"
    -- que no distingue el tope alcanzado de la puerta abierta -- y ahi la fila de
    -- la planilla no puede saber si el mecanismo esta apagado o si nunca le toco
    -- un sujeto valido.
    -- ⚠ ES UN LOCAL DE ESTA LLAMADA Y NO UN CAMPO DE `st`, A PROPOSITO. Guardado
    -- en el estado del fantasma, el motivo del ultimo "no trabo" sobreviviria a
    -- la llamada que lo produjo y se imprimiria al lado del disparo siguiente:
    -- una FOTO VIEJA puesta junto a un veredicto nuevo, que es la familia de
    -- defecto que este archivo ya pago en el comando de disparo forzado.
    local pestilloNo

    if cvPestillo:GetBool() then
        local puestos = podarPestillos()
        local noPorque

        if puestos >= PESTILLO_MAX then
            noPorque = "ya hay " .. puestos .. " puerta(s) trabada(s), que es el tope"

        elseif not cerrada( door ) then
            noPorque = "la puerta elegida no esta cerrada"

        elseif trabada( door ) then
            noPorque = "la puerta ya venia trabada ( no es nuestra, y soltarla seria destrabar el mapa )"

        elseif math.random( 1, 3 ) > 1 then
            -- ⚠ UNO DE CADA TRES Y NO SIEMPRE. Con el pestillo en todas, el
            -- evento de puertas dejaria de abrir -- que es lo que el autor usa
            -- para VER donde esta el fantasma adentro de la casa ( es un
            -- instrumento de observacion suyo, y esta escrito asi en
            -- server_doors.lua ). El sorteo va con numero en la bitacora para que
            -- "no salio" no se confunda con "no funciona".
            noPorque = "el sorteo salio abrir ( el pestillo es 1 de cada 3 )"

        end

        if not noPorque then
            st.doorHasta[ door ] = now + DOOR_COOLDOWN

            door:Fire( "Lock" )

            if isfunction( PHANTASMAGORIA.SonarLlave ) then
                PHANTASMAGORIA.SonarLlave( "lock", door:WorldSpaceCenter() )

            end

            local p = { door = door, hasta = now + PESTILLO_VIDA }
            PESTILLOS[ #PESTILLOS + 1 ] = p

            -- ⚠ MEDIR EL DESTINO. `Fire( "Lock" )` sobre una clase que no acepta
            -- el input **no avisa**: `AcceptInput` devuelve false en silencio. El
            -- veredicto llega diferido porque el estado cambia en el tick
            -- siguiente, y el retorno de este frame dice "INTENTADO", que es lo
            -- unico cierto ahora.
            local yoAhora = quien( ghost )

            timer.Simple( 0.25, function()
                if not IsValid( door ) then return end

                if trabada( door ) then
                    anotar( string.format( "%s pestillo CONFIRMADO -- %s #%d trabada ( m_bLocked true ); " ..
                        "se suelta sola en %d s", yoAhora, door:GetClass(), door:EntIndex(), PESTILLO_VIDA ) )

                else
                    -- No quedo trabada: se saca del registro. Dejarla adentro
                    -- ocuparia una de las dos plazas del tope Y le sonaria un
                    -- `key_unlock` a los 45 s a una puerta que nunca se trabo.
                    for i = #PESTILLOS, 1, -1 do
                        if PESTILLOS[ i ] == p then table.remove( PESTILLOS, i ) end

                    end

                    anotar( string.format( "%s pestillo SIN EFECTO -- %s #%d NO quedo trabada. " ..
                        "Fire( 'Lock' ) no lo acepta esta clase, o algo la destrabo en el mismo tick",
                        yoAhora, door:GetClass(), door:EntIndex() ) )

                end
            end )

            -- La soltada automatica. Comprueba que el pestillo siga siendo NUESTRO
            -- antes de tocar nada: si lo sacamos del registro ( porque no trabo, o
            -- porque el comando lo solto ), este timer no tiene que hacer sonar
            -- una llave sobre una puerta ajena.
            timer.Simple( PESTILLO_VIDA, function()
                for i = #PESTILLOS, 1, -1 do
                    if PESTILLOS[ i ] == p then
                        table.remove( PESTILLOS, i )
                        soltarPestillo( p, "se cumplio la vida de " .. PESTILLO_VIDA .. " s" )

                    end
                end
            end )

            return true, "puerta " .. door:GetClass() .. " #" .. door:EntIndex() .. " a " ..
                math.Round( ghost:GetPos():Distance( door:WorldSpaceCenter() ) ) ..
                " u -- PESTILLO INTENTADO con llaves ( " .. ( puestos + 1 ) .. "/" .. PESTILLO_MAX ..
                " trabadas; el efecto se confirma en la bitacora a los 0,25 s )"

        end

        -- Se anota el NO, porque un pestillo que nunca sale y uno que no existe
        -- se ven igual desde afuera.
        pestilloNo = noPorque

    else
        pestilloNo = "phantasmagoria_ghost_evpestillo esta en 0 ( control )"

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
    -- Y el cuarto lo tenemos NOSOTROS: server_doors.lua devuelve true cuando
    -- phantom_CanOpenDoors() dice que no. O sea que con
    -- `phantasmagoria_ghost_opendoors 0` -- una convar real, un control
    -- documentado -- el evento sonaba la manija, no movia la hoja, y el
    -- instrumento imprimia "OK -- puerta prop_door_rotating #123". Verde exacto
    -- sobre cero comportamiento.
    --
    -- ⚠ ESO SE ARREGLO EL 2026-08-19, Y DEL LADO DEL COMPORTAMIENTO. El arreglo
    -- de aquella vez fue del INSTRUMENTO -- la bitacora paso a decir
    -- `door SIN EFECTO` en vez de `OK` -- y la hoja siguio sin moverse un año de
    -- rondas. Ahora el evento pide un pase de un solo uso antes de su Use2 ( ver
    -- abajo ), asi que la cuarta salida ya no lo alcanza. Las OTRAS CUATRO
    -- siguen ahi, y por eso la medicion de abajo no se toca: sigue siendo la
    -- unica que no envejece.
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

    -- ⚠⚠⚠ EL PASE, Y ES LA LINEA QUE VUELVE A ESTE EVENTO UN EVENTO. Hasta el
    -- 2026-08-19 la cuarta salida silenciosa de Use2 -- nuestro propio veto de
    -- server_doors.lua -- se comia esta apertura entera cuando
    -- `phantasmagoria_ghost_opendoors` estaba en 0, que es la combinacion en la
    -- que el autor juega. La manija sonaba, la hoja no se movia, y la bitacora de
    -- abajo lo decia con esas palabras ( `door SIN EFECTO` ) sin que nadie
    -- pudiera arreglarlo desde este archivo. Eso era el instrumento diciendo la
    -- verdad sobre un comportamiento roto: el defecto estaba MEDIDO y sin
    -- corregir.
    --
    -- DECISION DEL AUTOR ( 2026-08-19 ), entre las dos lecturas de su pedido:
    -- el evento **siempre** mueve la hoja, tambien con `opendoors 0`. La
    -- probabilidad ( `phantasmagoria_ghost_doorchance` ) es para el fantasma que
    -- NAVEGA y llega a una puerta; esto es una manifestacion deliberada, la
    -- dispara un comando, y un evento que no hace nada no es "calmado": esta
    -- roto.
    --
    -- ⚠ El pase dura UNA apertura y UNA puerta ( ver phantom_GrantDoorPass ). No
    -- se toca `opendoors`: su 0 sigue siendo el control negativo de cuatro filas
    -- de las planillas de puertas, y el veto sigue vetando todo lo demas --
    -- incluida la apertura que la BASE hace por su cuenta.
    if isfunction( ghost.phantom_GrantDoorPass ) then
        ghost:phantom_GrantDoorPass( door, "evento doors" )

    end

    ghost:Use2( door )

    -- ⚠ LA CUARENTENA SE ESCRIBE ACA Y NO ANTES DE ELEGIR. En la primera version
    -- se escribia nueve lineas mas arriba, o sea que una puerta que NO se llego a
    -- tocar quedaba quemada 45 s igual: con opendoors en 0, a los pocos eventos
    -- el detalle pasaba a ser "no habia puertas ( 5 en cuarentena )", que se lee
    -- como un mapa sin puertas. Un debounce que castiga intentos fallidos
    -- fabrica la escasez que despues reporta.
    st.doorHasta[ door ] = now + DOOR_COOLDOWN

    local dist = math.Round( ghost:GetPos():Distance( door:WorldSpaceCenter() ) )

    -- ⚠ LA IDENTIDAD SE CAPTURA ACA, EN EL FRAME DEL DISPARO, y no adentro del
    -- callback. Un cuarto de segundo despues el fantasma puede estar muerto o
    -- borrado, y `quien( ghost )` sobre una entidad invalida devuelve `#?`: el
    -- renglon del veredicto -- que es el unico que dice si la puerta se movio de
    -- verdad -- quedaba sin dueño, y el censo de sujetos de la bitacora no lo
    -- podia contar. *La identidad se toma cuando se sabe, no cuando se imprime.*
    local yo = quien( ghost )

    -- El estado de una puerta cambia en el siguiente tick, no en este, asi que
    -- el veredicto llega diferido. La bitacora lo recibe cuando existe; el
    -- retorno de aca es "se intento", que es lo unico cierto en este frame.
    timer.Simple( 0.25, function()
        if not IsValid( door ) then return end

        local despues = leerEstado( door )

        if despues == estadoAntes then
            -- ⚠ EL SOSPECHOSO CAMBIO EL 2026-08-19 Y LA LINEA TENIA QUE
            -- CAMBIAR CON EL. Decia que la causa mas probable era
            -- `opendoors 0` o el veto, y desde el pase de un solo uso esos dos
            -- ya no pueden ser: quedan las CUATRO salidas de la base. Un
            -- instrumento que sigue nombrando al sospechoso que se descarto
            -- manda a mirar donde ya no esta.
            anotar( string.format( "%s door SIN EFECTO -- %s #%d no cambio de estado ( %s ). " ..
                "El veto propio ya NO es sospechoso ( el evento pide pase ): quedan las cuatro " ..
                "salidas silenciosas de la base -- CanUseStuff, GetDriver, la lista negra de clases, " ..
                "o un TerminatorBlockUse de un TERCERO",
                yo, door:GetClass(), door:EntIndex(),
                tostring( despues ) ) )

        else
            anotar( string.format( "%s door efecto CONFIRMADO -- %s #%d  estado %s -> %s",
                yo, door:GetClass(), door:EntIndex(),
                tostring( estadoAntes ), tostring( despues ) ) )

        end
    end )

    return true, "puerta " .. door:GetClass() .. " #" .. door:EntIndex() .. " a " .. dist ..
        " u -- INTENTADA ( estado " .. tostring( estadoAntes ) ..
        "; el efecto se confirma en la bitacora a los 0,25 s )" ..
        ( pestilloNo and ( "  [ sin pestillo: " .. pestilloNo .. " ]" ) or "" )

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
-- ⭐ ESTO YA NO ES EVIDENCIA INDIRECTA: SE MIDIO ( r1, sobre el mapa del autor ).
-- Se saco `maps/gm_funkis_night.bsp` del .gma del Workshop y se parseo el
-- LUMP_ENTITIES ( VBSP v20, 1224 bloques ). El mapa trae **322 luces escritas en
-- el BSP -- 268 `light` + 54 `light_spot` -- y 43 de ellas con `targetname` y
-- lightstyle conmutable ( 32-43 ), repartidas en 12 grupos** ( cocina, tres
-- dormitorios, dos baños, hall, lavadero, cuna, sauna, oficina, cobertizo ).
-- Como los 43 comparten solo 12 lightstyles, tocar UNA apaga el grupo entero:
-- el apagon se ve por habitacion, que es exactamente lo que el autor recordaba
-- de gmpa.
--
-- O sea que la premisa se sostiene y la conclusion de gmpa tambien: **gmpa no
-- tocaba lo horneado**, tocaba las que sobreviven por tener nombre. Y en
-- cobertura de CLASE nosotros somos estrictamente mas amplios: gmpa mira solo
-- `light`, asi que pierde los 17 `light_spot` -- el baño entero de ese mapa.
--
-- ⚠ LO QUE NOS DIFERENCIA DE GMPA NO ES LA CLASE, ES EL RADIO, y eso es la
-- tesis y no un olvido: gmpa busca en todo el mapa y nosotros a
-- `phantasmagoria_ghost_evradius` del FANTASMA. En ese mapa las 43 nombradas
-- caben en una caja de 862 x 1056 u ( la casa ) mientras las puertas y los props
-- se reparten por todo el terreno -- 37 de las 65 puertas y 14 de los 15
-- prop_physics no tienen NINGUNA luz nombrada a 450 u. Por eso `throw` y `door`
-- pueden tener sujeto en el mismo instante en que `light` no lo tiene, y por eso
-- ese cruce NO sirve para diagnosticar nada.
--
-- ⚠⚠ Y SE BUSCA CON `ents.FindByClass` Y NO CON `ents.FindInSphere`. Una `light`
-- es un point entity sin modelo y sin solidez, y la particion espacial que
-- alimenta a FindInSphere indexa lo solido: no esta medido que una `light`
-- aparezca ahi con NINGUN radio. gmpa usa FindByClass y su rama de luces
-- funcionaba. No se cambio el radio ni la tesis -- se cambio de donde sale la
-- lista, que es la unica hipotesis que quedaba viva despues de medir el mapa.
-- *Cuando dos implementaciones difieren en el resultado y en el mecanismo,
-- primero se iguala el mecanismo.*
--
-- Cuando no encuentra nada lo DICE, y ahora dice tambien cuantas hay en TODO el
-- mapa y a que distancia esta la mas cercana: sin esos dos numeros, "no hay
-- luces en el mapa", "hay pero lejos" y "las busco mal" escriben LA MISMA LINEA.
-- *Un vacio que solo describe su propio metodo no es una medicion del mundo.*
--
-- El orden va de lo mas probable en sandbox a lo mas probable en un mapa de
-- horror hecho a mano. Son SIETE clases en CUATRO familias de trato ( `seton`,
-- `toggle`, `lighttoggle`, `onoff` ) -- decia "cinco familias" y nunca fueron
-- cinco.
local LIGHT_CLASSES = {
    -- ( 1 ) Las lamparas de sandbox. Son SENTs de Lua con getter y setter
    -- propios, y son las mas probables en un servidor de GMod porque las pone
    -- el jugador. HIM las trata igual ( server.lua:494-495 ).
    { clase = "gmod_light",           como = "seton" },
    { clase = "gmod_lamp",            como = "seton" },

    -- ( 2 ) Las del mapa que sobrevivieron al compilado por tener targetname.
    { clase = "light",                como = "toggle" },
    { clase = "light_spot",           como = "toggle" },

    -- ( 3 ) ⚠ Esta NO responde a `Toggle`: su input se llama `LightToggle`.
    -- Es una asimetria del engine y HIM la trata aparte ( server.lua:500 ).
    --
    -- ⚠⚠ EL NOMBRE DEL INPUT NO ESTA MEDIDO, Y SU UNICA FUENTE ES HIM. Grep de
    -- `LightToggle` sobre todo el workspace: cuatro apariciones, tres de HIM y
    -- esta. Cero apariciones de `LightOn` / `LightOff`, que es como se llaman
    -- los inputs de CPointSpotlight en Source. O sea que este renglon es un
    -- comentario de un tercero COPIADO, que es el pecado que este mismo archivo
    -- documenta en el encabezado de `EV.door` ( "lo que no envejece es medir la
    -- hoja" ).
    --
    -- No se cambia sobre memoria -- eso seria el mismo pecado del otro lado --
    -- pero el reporte deja de afirmar que conmuto: `Entity:Fire` con un input
    -- que la clase no acepta **no tira error**, `AcceptInput` devuelve false en
    -- silencio. Se mide con una linea en juego, y esta anotado en la planilla.
    { clase = "point_spotlight",      como = "lighttoggle" },

    -- ( 4 ) Las dinamicas y los proyectores, que si o si existen en runtime
    -- porque no se pueden hornear.
    { clase = "light_dynamic",        como = "onoff" },
    { clase = "env_projectedtexture", como = "onoff" },
}

-- El censo GLOBAL, con el MISMO recorrido de clases que la busqueda de al lado.
-- Que compartan la tabla no es prolijidad: si el mensaje de vacio contara sobre
-- otra lista que la busqueda, podria decir "0 en todo el mapa" con luces que la
-- busqueda si mira, o al reves. *Un instrumento que mide una lista distinta de
-- la que usa el sujeto no lo esta midiendo a el.*
-- ⚠⚠ Y COMPARTIR LA TABLA NO ALCANZABA: LA BUSQUEDA TIENE UN FILTRO MAS.
-- `lucesCerca` descarta las `seton` que no traen getter y setter ( son SENTs de
-- Lua y sin eso no se las puede tocar ), y este censo no lo hacia. Con una
-- lampara de sandbox rota cerca, el mensaje de vacio decia "no habia luces a
-- 450 u ( en TODO el mapa hay 1 y la mas cercana esta a 30 u )" -- dos mitades
-- ciertas que juntas se leen como un defecto de radio que no existe.
--
-- *Compartir la lista no es compartir el criterio: el filtro tambien es parte de
-- lo que hace que dos censos hablen del mismo universo.*
local function lucesUtilizable( fam, ent )
    if fam.como ~= "seton" then return true end

    return isfunction( ent.SetOn ) and isfunction( ent.GetOn )

end

local function lucesEnElMapa( ghost )
    local n, mejor = 0, nil
    local pos = ghost:GetPos()

    for _, fam in ipairs( LIGHT_CLASSES ) do
        for _, ent in ipairs( ents.FindByClass( fam.clase ) ) do
            if not IsValid( ent ) then continue end
            if not lucesUtilizable( fam, ent ) then continue end

            n = n + 1

            local d = ent:GetPos():Distance( pos )
            if not mejor or d < mejor then mejor = d end

        end
    end

    return n, mejor

end

local function lucesCerca( ghost, radio )
    local halladas, censo = {}, {}
    local origen = ghost:GetPos()
    local radio2 = radio * radio

    local function sumar( clase, ent, como )
        censo[ clase ] = ( censo[ clase ] or 0 ) + 1
        halladas[ #halladas + 1 ] = { ent = ent, como = como, clase = clase }

    end

    for _, fam in ipairs( LIGHT_CLASSES ) do
        for _, ent in ipairs( ents.FindByClass( fam.clase ) ) do
            if not IsValid( ent ) then continue end
            if ent:GetPos():DistToSqr( origen ) > radio2 then continue end

            -- Las de sandbox son SENTs de Lua: si no traen su getter y su
            -- setter no se las puede ni leer ni tocar, asi que no son sujeto.
            -- Las otras cinco clases se manejan por input del engine y no
            -- necesitan nada. Es la MISMA pregunta que hace el censo global --
            -- por eso vive en una funcion y no duplicada en dos lugares.
            if not lucesUtilizable( fam, ent ) then continue end

            sumar( fam.clase, ent, fam.como )

        end
    end

    return halladas, censo

end

EV.light = function( ghost, radio, _fuerza, _cuantos, dir )
    local halladas, censo = lucesCerca( ghost, radio )

    if #halladas <= 0 then
        -- El vacio MEDIDO, no el vacio silencioso. Ver el bloque de arriba.
        --
        -- ⚠ DECIA "alcanzables" Y NO HAY NINGUN FILTRO DE ALCANCE: en esta
        -- funcion no hay un solo trace. La palabra mandaba al que diagnostica a
        -- buscar un filtro de visibilidad que nunca se escribio. Dice "a menos
        -- de", que es lo unico que la busqueda hace.
        local enMapa, masCerca = lucesEnElMapa( ghost )

        local dondeEsta = "el fantasma esta en " .. tostring( ghost:GetPos() )
        local global    = "en TODO el mapa hay " .. enMapa .. " de esas clases"

        if masCerca then
            global = global .. " y la mas cercana esta a " .. math.Round( masCerca ) .. " u"

        end

        return false, "no habia luces a menos de " .. math.Round( radio ) .. " u " ..
            "( " .. global .. " · " .. dondeEsta .. " · se buscaron gmod_light, gmod_lamp, " ..
            "light, light_spot, point_spotlight, light_dynamic y env_projectedtexture -- " ..
            "las estaticas SIN targetname no sobreviven como entidad )"

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
    -- Solo una de las cuatro familias tiene getter: los gmod_light / gmod_lamp,
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
            ( L.como == "lighttoggle"
              and " ( se mando LightToggle SIN COMPROBAR: no esta medido que la clase acepte ese input )"
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

    return true, pasos .. " input(s) enviado(s) a " .. L.clase .. " #" .. L.ent:EntIndex() ..
        " ( " .. transicion .. " )  [ " .. table.concat( resumen, ", " ) .. " ]" ..
        -- ⚠ DICE "input(s) enviado(s)" Y NO "conmutacion(es)": para las cuatro
        -- clases sin getter, lo unico que sabemos es que se mando el input. La
        -- palabra vieja afirmaba el efecto sobre las tres familias que no lo
        -- pueden leer -- que es el mismo verde-sin-comportamiento que el
        -- encabezado de esta categoria dice estar cazando.
        ( L.como == "lighttoggle" and "  ( LightToggle: nombre de input SIN MEDIR sobre esta clase )" or "" ) ..
        ( soloApaga and "  ( el tipo SOLO apaga )" or soloEnciende and "  ( el tipo SOLO enciende )" or "" )

end

---------------------------------------------------------------------------
-- sound -- la voz paranormal
---------------------------------------------------------------------------
-- ⭐ LA UNICA DE LAS OCHO QUE SUENA EN EL FANTASMA. Ver el contrato comun de
-- arriba: es la excepcion, es del autor, y el motivo es que una voz no es un
-- ruido ambiente -- es el que la emite.
--
-- Se emite con `ghost:EmitSound` y no con `sound.Play` en su posicion, y la
-- diferencia importa: `EmitSound` ata el canal a la ENTIDAD, asi que la voz
-- SIGUE al fantasma mientras camina en vez de quedar clavada donde arranco. Un
-- tarareo que se queda atras mientras el fantasma se aleja delata que el sonido
-- no es de el.
-- ⚠ `_radio` deja de usarse EN ESTA CATEGORIA y se marca con el guion bajo como
-- las otras tres que no lo usan. El radio sigue decidiendo si la categoria se
-- elige; lo que ya no decide es donde suena.
EV.sound = function( ghost, _radio, _fuerza, _cuantos, _dir, flags )
    local voz   = ghost:phantom_EventVoice()
    local bancos = VOZ[ voz ]

    if not bancos then return false, "la voz " .. tostring( voz ) .. " no tiene bancos" end

    ---------------------------------------------------------------------------
    -- ⚠⚠ LA RESERVA SE APLICA SOBRE LOS PESOS, NO SOBRE LA TABLA DE DATOS
    ---------------------------------------------------------------------------
    -- Los rasgos por tipo viven en ghost_flags.lua con las claves `voice`,
    -- `breath` y `humming` en 25 de los 30 tipos. Renombrarlas para meter
    -- `whisper` habria significado tocar un archivo de DATOS -- que ademas es el
    -- que `gen_types.py` no pisa, o sea el unico lugar donde los rasgos
    -- sobreviven -- para expresar una decision de COMPORTAMIENTO. Y peor: un
    -- tipo con `humming 4` ( el Myling ) habria quedado con un peso apuntando a
    -- una clave inexistente, que en `sortearPeso` no es un error: es un peso que
    -- nunca sale.
    --
    -- Asi que los datos no se tocan y lo que se re-rutea es el peso: con la
    -- reserva puesta, el peso de `voice` va al banco `whisper` y el de `humming`
    -- sale del sorteo. Es reversible por convar, no toca 25 filas, y el reporte
    -- puede decir las dos cosas -- que banco sono y de que peso vino.
    local reserva = cvReserva:GetBool()
    local pesos   = flags.soundBanks or {}
    local orden, mapa

    if reserva then
        orden = { "voice", "breath" }
        mapa  = { voice = "whisper", breath = "breath" }

    else
        orden = { "voice", "breath", "humming" }
        mapa  = { voice = "voice", breath = "breath", humming = "humming" }

    end

    -- ⚠⚠ EL CONTROL TIENE QUE REPRODUCIR LA r2 Y NO LO HACIA. Con la reserva en
    -- 0 el mapa manda el peso `voice` al banco `voice`, que despues del corte de
    -- esta ronda tiene 15 clips en la voz 1 y 8 en la voz 2 -- pero en la r2 ese
    -- peso sorteaba sobre **los 23 y los 16**, o sea sobre `whisper` + `voice`
    -- juntos, que era una sola tabla. Los 8 de `whisper` quedaban INALCANZABLES
    -- justo en el estado que existe para volver al comportamiento anterior.
    --
    -- *Un control que no reproduce el estado que dice reproducir no es un
    -- control: es un tercer estado sin nombre* -- y habria hecho que la fila 08
    -- comparara la reserva contra algo que nunca corrio.
    --
    -- La union se arma UNA VEZ y se guarda en la propia tabla VOZ: esto corre en
    -- cada evento de sonido, y rearmar 23 entradas por disparo seria basura para
    -- el recolector sin ningun motivo. La clave lleva guion bajo adelante para
    -- que se lea como lo que es -- un derivado y no un banco del catalogo.
    if not reserva then
        if not bancos._todaLaVoz then
            local t = {}

            for _, ruta in ipairs( bancos.whisper or {} ) do t[ #t + 1 ] = ruta end
            for _, ruta in ipairs( bancos.voice or {} ) do t[ #t + 1 ] = ruta end

            bancos._todaLaVoz = t

        end

        mapa.voice = "_todaLaVoz"

    end

    local key = sortearPeso( pesos, orden )

    -- ⚠ UN TIPO QUE **SOLO** TARAREA SE QUEDA SIN POZO CON LA RESERVA PUESTA, y
    -- eso hay que decirlo en vez de devolver "los soundBanks estan en cero", que
    -- seria falso: no estan en cero, estan reservados. Degrada a `whisper` -- que
    -- es lo que el autor pidio que quede -- y lo ROTULA, para que una corrida no
    -- lea el degradado como el comportamiento normal del tipo.
    local degradado = ""

    if not key then
        if reserva then
            key, degradado = "voice", "  ( DEGRADADO: con la reserva puesta este tipo se quedaba sin pozo )"

        else
            return false, "los tres soundBanks del tipo estan en cero"

        end
    end

    local banco = mapa[ key ] or key
    local snd = elegir( bancos[ banco ] )
    if not snd then return false, "el banco '" .. banco .. "' de la voz " .. voz .. " esta vacio" end

    ghost:EmitSound( snd, 70, math.random( 96, 104 ) )

    -- ⚠ EL DETALLE NOMBRA EL ARCHIVO, y esto no es cosmetico. En la r1 esta
    -- categoria imprimia "OK -- voz 1 / banco voice a 221 u" mientras el engine
    -- escribia, en la linea de al lado, `Invalid sample rate (48000) for sound
    -- 'phantasmagoria\ghost\paranormal_voice\voice_1_why_01.ogg'`. Las dos
    -- lineas hablaban del mismo disparo y NO se podian aparear, porque la
    -- nuestra no decia que clip habia elegido. `EV.prop` ya lo hacia.
    -- ⚠ DICE EL BANCO **Y** EL PESO DEL QUE VINO, porque con la reserva puesta
    -- ya no son la misma palabra: un `whisper` que salio del peso `voice` y uno
    -- que hubiera salido de un peso `whisper` inexistente se leen igual, y solo
    -- el primero existe. Sin los dos nombres, la fila que mida la reserva no
    -- puede distinguir "la reserva funciono" de "el tipo no tenia voice".
    local comoSeLlama = ( banco == "_todaLaVoz" ) and "whisper+voice ( el pozo entero de la r2 )" or banco

    return true, ( string.match( snd, "([^/]+)%.ogg$" ) or snd ) ..
        "  ( voz " .. voz .. " / banco " .. comoSeLlama ..
        ( banco ~= key and ( ", del peso '" .. key .. "'" ) or "" ) ..
        ", en el fantasma" .. ( reserva and "; RESERVA puesta" or "; reserva APAGADA ( control )" ) ..
        " )" .. degradado

end

---------------------------------------------------------------------------
-- prop -- un trasto de la casa que suena solo
---------------------------------------------------------------------------
EV.prop = function( ghost, radio )
    -- ⭐ PRIMERO EL MUNDO, DESPUES EL SORTEO. Hasta la r1 esto era al reves --
    -- se sorteaba un sonido de una tabla plana y se lo emitia en un punto -- y
    -- por eso sonaban alarmas de auto sin auto. Ahora los sonidos que nombran un
    -- objeto entran al sorteo SOLO si ese objeto esta a la vista del radio, y
    -- cuando entran, suenan DESDE el.
    --
    -- ⚠ UN SOLO BARRIDO PARA LAS OCHO FAMILIAS, Y ESTE ES EL CAMBIO DE FORMA DE
    -- LA r3. La version de la r2 tenia el `ents.FindInSphere` **adentro** del
    -- bucle de familias: con una familia daba 1 barrido y no se notaba, con las
    -- ocho de hoy darian OCHO barridos de la misma esfera en el mismo tick,
    -- siete de ellos redundantes. Se invierten los bucles: la esfera se pide una
    -- vez y cada entidad se clasifica contra todas las familias en la misma
    -- pasada.
    -- La poda del registro de lo que suena. Va acá y no en un timer: este es el
    -- unico camino que agrega entradas, asi que es el lugar natural para sacar
    -- las que ya no tienen entidad.
    podarSonando()

    local esfera = ents.FindInSphere( ghost:GetPos(), radio )
    local hallado, cuantas = {}, 0

    for _, ent in ipairs( esfera ) do
        if not IsValid( ent ) then continue end
        if ent == ghost then continue end

        -- ⚠⚠ EL BARRIDO NO SE PUEDE ENCONTRAR A SI MISMO. Los emisores de los
        -- props horneados son entidades de verdad, asi que aparecen en el
        -- proximo `ents.FindInSphere`. Sin este salteo, el mecanismo crearia una
        -- entidad que su propio buscador encuentra y el fantasma le haria sonar
        -- la radio a un emisor de radio.
        --
        -- *Un instrumento que cuenta al observador entre los sujetos no mide el
        -- fenomeno: mide la medicion.* Es la misma forma del defecto que la r3
        -- cerro en el sondeo de puertas.
        --
        -- El salteo LLEVA NUMERO y no silencio: "no aparecio el emisor entre los
        -- sujetos" se cumple igual si el barrido no corrio.
        if ent.PhantasmagoriaEmisor then
            EMISORES.salteados = EMISORES.salteados + 1
            continue

        end

        for i, fam in ipairs( PROP_CONSUJETO ) do
            if hallado[ i ] then continue end

            -- Dos formas de ser sujeto y no una: un predicado ( el vehiculo,
            -- que se reconoce por IsVehicle y no por su modelo ) o una regla de
            -- modelo. Nunca las dos.
            local es = fam.sujeto and fam.sujeto( ent ) or
                ( fam.modelo and modeloCoincide( ent, fam.modelo ) )

            if es then
                hallado[ i ] = ent
                cuantas = cuantas + 1

            end
        end

        if cuantas >= #PROP_CONSUJETO then break end

    end

    ---------------------------------------------------------------------------
    -- LOS PROPS HORNEADOS -- el relleno de un mapa que no tiene props sueltos
    ---------------------------------------------------------------------------
    -- ⚠ LAS ENTIDADES CON PRIORIDAD SON LAS REALES, y por eso esta pasada corre
    -- DESPUES y solo sobre las familias que quedaron SIN sujeto. Si hay una
    -- radio `prop_physics` a 3 m y una horneada a 8 m, gana la de verdad: se
    -- puede empujar, romper y mirar. Lo horneado es el relleno.
    --
    -- ⚠⚠ Y NO SE CREA NINGUN EMISOR ACA. Se guarda un DESCRIPTOR ( modelo +
    -- posicion ) y el emisor se crea solo para la familia que GANA el sorteo.
    -- Crearlos en el barrido seria fabricar cuatro entidades por evento para
    -- usar una: las otras tres serian fuga, y encima aparecerian en el proximo
    -- barrido -- o sea que el mecanismo se ensuciaria a si mismo justo por
    -- adelantarse.
    local horneado = {}

    if cvHorneados:GetBool() and cuantas < #PROP_CONSUJETO then
        local cerca = PHANTASMAGORIA.EstaticosEnEsfera( ghost:GetPos(), radio )

        for _, est in ipairs( cerca ) do
            local nom = PHANTASMAGORIA.BasenameDeRuta( est.modelo )

            for i, fam in ipairs( PROP_CONSUJETO ) do
                -- `fam.sujeto` no aplica: es el vehiculo, y se reconoce por
                -- IsVehicle(). Un prop horneado nunca es un vehiculo.
                if not hallado[ i ] and fam.modelo and PHANTASMAGORIA.NombreCoincide( nom, fam.modelo ) then
                    -- El MAS CERCANO gana, que es lo que hace el barrido de
                    -- entidades por accidente ( se queda con el primero que
                    -- encuentra ) y aca se hace a proposito.
                    local d = est.pos:DistToSqr( ghost:GetPos() )

                    if not horneado[ i ] or d < horneado[ i ].d then
                        horneado[ i ] = { modelo = est.modelo, pos = est.pos, d = d }

                    end
                end
            end
        end
    end

    ---------------------------------------------------------------------------
    -- ⚠⚠ SE SORTEA LA FAMILIA Y DESPUES EL CLIP -- Y NO AL REVES
    ---------------------------------------------------------------------------
    -- La r2 armaba un pozo plano con UNA entrada por cada clip de cada familia
    -- presente. Con dos clips de auto contra dieciocho de ambiente eso era 10 %
    -- y se leia razonable; con la familia radio ( cuatro clips ) mas siete
    -- familias mas, el ambiente -- que ahora tiene tres -- quedaria en menos del
    -- 10 % y una casa con una radio sonaria a radio casi siempre.
    --
    -- *Un sorteo plano sobre pozos de tamano muy distinto no reparte por
    -- categoria: reparte por cuantos archivos tiene cada carpeta*, que es un
    -- dato del catalogo de audio y no una decision de diseno.
    --
    -- Ahora cada familia presente pesa 1, y el ambiente pesa 1. Con una radio en
    -- la sala eso es 50/50 radio-ambiente; con radio y tele, 33 % cada uno.
    local opciones = {}

    if #SND.prop > 0 then opciones[ #opciones + 1 ] = { ambiente = true } end

    -- ⚠ SE CUENTA APARTE Y NO SE DEDUCE DE `#opciones`. Hasta esta ronda el
    -- detalle imprimia `#opciones - 1` asumiendo que el ambiente siempre estaba
    -- adentro; con el banco ambiente vacio ese numero se corria en uno y nadie
    -- lo habria notado, porque un "3" y un "4" se leen los dos como un dato.
    local conSujeto = 0

    for i, fam in ipairs( PROP_CONSUJETO ) do
        if IsValid( hallado[ i ] ) then
            opciones[ #opciones + 1 ] = { fam = fam, ent = hallado[ i ] }
            conSujeto = conSujeto + 1

        elseif horneado[ i ] then
            -- Un horneado pesa lo mismo que una entidad real: la prioridad ya
            -- se ejercio arriba ( solo entran las familias que quedaron sin
            -- sujeto ), asi que darle menos peso aca lo penalizaria DOS veces.
            opciones[ #opciones + 1 ] = { fam = fam, est = horneado[ i ] }
            conSujeto = conSujeto + 1

        end
    end

    ---------------------------------------------------------------------------
    -- LAS LLAVES QUE SONABAN SIN LLAVES
    ---------------------------------------------------------------------------
    -- El autor: *"acabar con el ruido de llaves al aplicar el evento de prop sin
    -- props elegibles"*. `SND.prop` son ocho clips y **los ocho son llaves** ( las
    -- dos que no lo eran, `key_1` y `key_2`, resultaron ser el presentador
    -- britanico y se mudaron a `voice/` en la r3 ). No suenan mal: suenan **donde
    -- no corresponde**, que es justo el cuarto donde no hay nada que las explique.
    --
    -- ⚠⚠ Y LA LINEA TIENE QUE SEGUIR SALIENDO. Un evento que se vuelve mudo hace
    -- que la fila del control negativo no pueda distinguir *"no habia sujeto"* de
    -- *"el evento no corrio"*, que es la trampa 5 de este bloque y una vieja
    -- conocida del taller: **un vacio no es una medicion**. Por eso esto sale por
    -- el camino `return false, motivo`, que `phantom_FireEvent` YA imprime como
    -- `SIN SUJETO -- <motivo>` en la bitacora ( no es un camino nuevo: es el que
    -- el codigo tenia ).
    if conSujeto <= 0 and cvLlaves:GetBool() then
        return false, "sin ningun objeto reconocible a " .. math.Round( radio ) ..
            " u  ( 0 familia(s) con sujeto en el radio; el banco ambiente NO suena porque " ..
            "phantasmagoria_ghost_evllaves esta en 1 -- las llaves se mudaron al pestillo de " ..
            "las puertas. Con la convar en 0 vuelven a sonar aca, que es el control )"

    end

    if #opciones <= 0 then
        return false, "no habia ningun objeto reconocible a " .. math.Round( radio ) ..
            " u y el banco ambiente esta vacio"

    end

    local elegida = elegir( opciones )

    if elegida.fam then
        local fam = elegida.fam
        local ent = elegida.ent
        local snd = elegir( fam.sonidos )

        if not snd then
            return false, "la familia '" .. fam.que .. "' no tiene sonidos"

        end

        -- EL EMISOR DE UN PROP HORNEADO, creado recien ahora que se sabe cual
        -- familia gano.
        --
        -- MEDIDO EN JUEGO ( P2, 2026-08-16 ): un `info_target` sin modelo SE OYE
        -- y SUENA DESDE SU POSICION. La prueba fue mas fuerte que el criterio:
        -- con el emisor puesto en la radio, el autor localizo el tic-tac y se lo
        -- atribuyo al reloj horneado que hay a 29 u -- o sea que el jugador
        -- ubica el sonido por direccion Y por plausibilidad del objeto. Por eso
        -- el emisor va en la posicion DEL PROP QUE MATCHEO y no en la del
        -- fantasma: es lo unico que hace que la atribucion caiga en el objeto
        -- correcto.
        --
        -- Y por eso alcanza la opcion barata: no hace falta un `prop_dynamic`
        -- con el modelo del prop -- que ademas matchearia su propia familia en
        -- el proximo barrido ( ver el salteo de arriba ).
        local emisor

        if elegida.est then
            emisor = ents.Create( "info_target" )

            if not IsValid( emisor ) then
                return false, "no se pudo crear el emisor para el prop horneado '" ..
                    tostring( elegida.est.modelo ) .. "'"

            end

            emisor:SetPos( elegida.est.pos )
            emisor:Spawn()

            -- ⚠ LA MARCA VA ANTES DE QUE NADIE PUEDA BARRER. Es lo que lo saca
            -- del proximo `ents.FindInSphere`.
            emisor.PhantasmagoriaEmisor = true
            ent = emisor

            EMISORES.creados = EMISORES.creados + 1

        end

        ent:EmitSound( snd, 75, math.random( 97, 103 ) )

        -- ⚠ EL CLIP LARGO SE CORTA, Y POR ESO ESTA FAMILIA EMITE EN LA ENTIDAD.
        -- `sound.Play` no devuelve nada que se pueda apagar; `EmitSound` ata el
        -- canal a la entidad y `StopSound` lo suelta.
        --
        -- ⚠⚠ SON TRES CAMINOS Y NO DOS, Y EL DEL MEDIO ES NUEVO:
        --   `fam.largo`   corta con StopSound a los pocos segundos ( el televisor
        --                 y el reloj: `tv_noise` dura 10,03 s y `clock_tick`
        --                 46,55 s, y sin corte se comen el evento siguiente ).
        --   `fam.entero`  NO corta: suena hasta el final, y el que lo apaga es el
        --                 jugador con +USE. La radio y el telefono.
        --   ninguno       clips de menos de un segundo y medio: no hay nada que
        --                 cortar y el emisor vive la tanda fija.
        -- `finClip` es CUANDO deja de oirse, y se calcula por camino en vez de
        -- reusar un solo numero: es lo que separa "esto todavia suena" de "esto
        -- ya termino" cuando alguien aprieta +USE, y las dos cosas se ven igual
        -- desde afuera. Donde no se conoce, se guarda una COTA SUPERIOR y esta
        -- dicho -- una cota no es una medicion, pero un `hasta` inventado corto
        -- convertiria un +USE valido en un "ya habia terminado".
        local corte, dur, finClip = "", nil, EMISOR_VIDA

        if fam.entero then
            dur = fam.dur and fam.dur[ snd ]

            -- ⚠ SI FALTA LA DURACION SE DICE, NO SE ADIVINA. La guarda del final
            -- del archivo grita al cargar si una familia `entero` tiene un clip
            -- sin medir, pero si igual llegara hasta aca, un numero inventado
            -- seria peor que ninguno: la vida del emisor decide si el clip se
            -- oye entero, o sea que un default silencioso volveria a decapitar
            -- por la puerta que este bloque vino a cerrar.
            finClip = dur or EMISOR_VIDA
            corte   = dur and ( ", ENTERO: " .. string.format( "%.2f", dur ) .. " s" )
                or ", ENTERO pero SIN DURACION DECLARADA ( el emisor vive la tanda fija; ver la guarda 3b )"

        elseif fam.largo then
            local cuando = math.Rand( fam.largo[ 1 ], fam.largo[ 2 ] )

            timer.Simple( cuando, function()
                if not IsValid( ent ) then return end
                ent:StopSound( snd )

            end )

            finClip = cuando
            corte   = ", cortado a los " .. string.format( "%.1f", cuando ) .. " s"

        end

        ---------------------------------------------------------------------
        -- EL REGISTRO DE LO QUE SUENA -- de aca come el +USE
        ---------------------------------------------------------------------
        -- ⚠ ENTRAN LOS DOS: el emisor de un horneado Y el prop de verdad. Sacar
        -- el corte de la radio le saca el corte TAMBIEN a la radio
        -- `prop_physics` que alguien spawnee, y esa no tiene emisor -- si el
        -- registro solo mirara emisores, el jugador tendria una radio real
        -- sonando sesenta segundos y ningun modo de callarla.
        -- *Un cambio que alcanza a dos clases de sujeto necesita un interruptor
        -- que alcance a las dos.*
        --
        -- ⚠⚠ Y AL PROP DE VERDAD **NO SE LO BORRA**: `emisor` es lo que autoriza
        -- el `SafeRemoveEntity` de mas abajo. Apagar la radio de otro es callarla,
        -- no hacerla desaparecer.
        --
        -- ⚠ LA CONDICION TIENE DOS MITADES Y NINGUNA SOBRA. `fam.apagable` es
        -- para el +USE; `IsValid( emisor )` es para el CONTADOR, porque de este
        -- mismo registro sale `vivos` -- y si solo entraran las familias
        -- apagables, los emisores del reloj y del televisor quedarian fuera de la
        -- cuenta y **la fila de la fuga diria 0 con emisores vivos en el mapa**.
        -- El mismo registro sirve a dos consumidores con criterios distintos, y
        -- cada uno filtra lo suyo al leer.
        if fam.apagable or IsValid( emisor ) then
            SONANDO[ #SONANDO + 1 ] = {
                ent    = ent,
                snd    = snd,
                fam    = fam,
                emisor = IsValid( emisor ),
                hasta  = CurTime() + finClip,
                nombre = fam.que,
            }
        end

        -----------------------------------------------------------------------
        -- EL PROP QUE SE ROMPE -- pedido 2 del autor
        -----------------------------------------------------------------------
        -- Textual: *"al destruir un prop_physics que haga estos ruidos, sea una
        -- radio de cs office o un phone de cs office, el sonido debe parar"*, y
        -- despues la mitad que faltaba: *"una radio phys que se rompa no detiene
        -- el sonido NI PERMITE PARARLO"*.
        --
        -- ⚠⚠ SON DOS DEFECTOS Y NO UNO, Y EL SEGUNDO ESTA CONFIRMADO LEYENDO EL
        -- CODIGO, SIN EL MOTOR: `podarSonando()` tira la entrada de `SONANDO` en
        -- cuanto la entidad deja de ser valida, y `apagarCerca()` poda **antes**
        -- de buscar. O sea que el registro **suelta el unico mango justo en el
        -- momento en que haria falta**: rota la radio, el +USE no tiene a quien
        -- apagar, ni ahora ni nunca. Eso no dependia de ninguna medicion.
        --
        -- ⚠⚠⚠ Y POR ESO EL ARREGLO NO ES CONFIAR EN EL BORRADO. La frase
        -- *"borrar el emisor ES un corte: una entidad que se va se lleva su
        -- canal"* estuvo escrita en cinco lugares de este repo **sin medirse**,
        -- y el 2026-08-18 se midio por fin, en las dos direcciones:
        --
        --     fila 00   borrar un `info_target` NUESTRO mientras suena
        --               -> SI corta ( medido con clock_tick, 46,55 s )
        --     fila 01   romper / borrar / desintegrar un `prop_physics`
        --               -> NO corta: el sonido sigue
        --
        -- La frase valia para nuestro emisor y **no** como ley del motor. Asi que
        -- aca se llama a `StopSound` A MANO, mientras la entidad todavia es
        -- valida, en vez de esperar que el borrado lo haga.
        --
        -- ⚠ VA SOLO SOBRE PROPS DE VERDAD ( `not IsValid( emisor )` ). Sobre
        -- nuestro emisor seria un defecto: lo borra `SafeRemoveEntityDelayed` en
        -- el segundo exacto de `dur + EMISOR_MARGEN`, y un `StopSound` ahi
        -- **decapitaria el ultimo suspiro del clip** -- que es justo lo que
        -- `EMISOR_MARGEN` existe para rescatar.
        --
        -- ⚠⚠ EL NOMBRE DEL HOOK LLEVA EL CLIP ADENTRO, y no es cosmetico:
        -- `CallOnRemove` indexa por nombre, asi que dos sonidos sobre la MISMA
        -- radio con el mismo nombre dejarian **un solo** hook vivo y el primer
        -- clip no se callaria nunca. Con el clip en el nombre, cada uno tiene el
        -- suyo. ( Que el evento vuelva a elegir la misma radio antes de que
        -- termine el clip anterior es raro, pero el sorteo no lo prohibe. )
        if not IsValid( emisor ) then
            ent:CallOnRemove( "phantasmagoria_prop_callar_" .. snd, function( e )
                -- ⚠ EL CONTADOR SUBE ANTES QUE EL `StopSound`, igual que
                -- `USE.teclas` en el hook del +USE y por el mismo motivo: es la
                -- acreditacion de que **el hook corrio**. Sin este numero, "rompi
                -- la radio y sigue sonando" no distingue *el StopSound no llego a
                -- tiempo* de *nunca se engancho nada*, y las dos se oyen igual.
                -- Esa confusion es la que dejo la fila 01 sin diagnostico.
                ROTOS.callados = ROTOS.callados + 1

                e:StopSound( snd )

                -- Y se saca del registro en el acto. `podarSonando()` lo sacaria
                -- igual en la lectura siguiente, pero dejarlo aca vuelve al
                -- borrado y al callado **un solo evento**: no queda ninguna
                -- ventana en la que el +USE crea tener un candidato que ya no
                -- suena.
                for i = #SONANDO, 1, -1 do
                    if SONANDO[ i ].ent == e and SONANDO[ i ].snd == snd then
                        table.remove( SONANDO, i )

                    end
                end
            end )

            ROTOS.enganchados = ROTOS.enganchados + 1

        end

        -- ⚠ LIMPIAR EL EMISOR, Y NO ANTES DE TIEMPO. Si se lo borra mientras
        -- suena, borrarlo ES el corte -- medido sobre NUESTRO emisor el
        -- 2026-08-18, fila 00; sobre un prop de verdad NO vale, ver
        -- `EL PROP QUE SE ROMPE`. Si se lo deja, el mapa se llena: en la prueba a mano de P2
        -- quedaron cuatro `info_target` vivos en cuatro comandos.
        --
        -- Las tres vidas, en el mismo orden que los tres caminos de arriba:
        --   con `dur` medida   el clip entero mas `EMISOR_MARGEN`;
        --   con `largo`        el corte mas el margen;
        --   sin ninguno        la tanda fija generosa.
        if IsValid( emisor ) then
            local vida = ( dur and ( dur + EMISOR_MARGEN ) )
                or ( fam.largo and ( fam.largo[ 2 ] + EMISOR_MARGEN ) )
                or EMISOR_VIDA

            SafeRemoveEntityDelayed( emisor, vida )

            -- ⚠ ACA VIVIA UN `timer.Simple( vida + 0.5 )` QUE DESCONTABA
            -- `EMISORES.vivos`, Y SE FUE POR LA TRAMPA 3 DE ESTE BLOQUE: con el
            -- +USE borrando el emisor antes de tiempo, ese timer iba a correr
            -- igual y a descontar de un contador que ya no tenia a quien contar.
            -- El numero se habria separado del conteo real del mapa y la fila de
            -- la fuga habria salido roja sin fuga. Hoy `vivos` se DERIVA del
            -- registro -- ver el bloque EMISORES arriba.

        end

        -- El sujeto se NOMBRA distinto segun de donde salio, y no es cosmetico:
        -- sin esta palabra, la linea de un horneado y la de un `prop_physics` se
        -- leen igual, y entonces la fila que dice "sono una radio" no distingue
        -- el mecanismo nuevo del que ya andaba.
        local quien

        if elegida.est then
            quien = "prop_static HORNEADO  modelo '" .. tostring( elegida.est.modelo ) ..
                "'  ( emisor #" .. ent:EntIndex() .. " )"

        else
            quien = ent:GetClass() .. " #" .. ent:EntIndex() ..
                ( basenameDe( ent ) and ( "  modelo '" .. basenameDe( ent ) .. "'" ) or "" )

        end

        return true, ( string.match( snd, "([^/]+)%.ogg$" ) or snd ) ..
            " DESDE " .. fam.que .. " ( " .. quien .. " ) a " ..
            math.Round( ghost:GetPos():Distance( ent:GetPos() ) ) .. " u" .. corte ..
            ( fam.apagable and "  [ se apaga con +USE a " .. cvUseRad:GetInt() .. " u ]" or "" ) ..
            "  ( " .. conSujeto .. " familia(s) con sujeto en el radio )"

    end

    -- puntoCerca nunca devuelve nil ( contrato declarado en su cuerpo ).
    local pos = puntoCerca( ghost, radio, false )
    local snd = elegir( SND.prop )

    sound.Play( snd, pos, 75, math.random( 97, 103 ) )

    -- La guarda del `or snd`: hoy las entradas de SND.prop terminan en .ogg y
    -- llevan barra, asi que el match siempre resuelve -- pero una ruta nueva sin
    -- extension devolveria nil y la concatenacion tiraria error EN EL EVENTO, no
    -- al cargar. Un banco de sonido es justo el lugar donde alguien pega una
    -- ruta a mano.
    --
    -- ⚠ EL DETALLE DICE CUANTAS FAMILIAS TENIAN SUJETO, y ese numero es el que
    -- separa dos escenas que se leen igual: "sono a llaves porque no habia nada
    -- reconocible" y "sono a llaves habiendo una radio al lado". La primera es
    -- el mecanismo funcionando; la segunda es el sorteo.
    return true, ( string.match( snd, "([^/]+)%.ogg$" ) or snd ) .. " a " ..
        math.Round( ghost:GetPos():Distance( pos ) ) .. " u" ..
        "  ( ambiente; " .. conSujeto .. " familia(s) con sujeto en el radio" ..
        ( cvLlaves:GetBool() and "" or "; llaves EN CONTROL -- phantasmagoria_ghost_evllaves 0" ) .. " )"

end

---------------------------------------------------------------------------
-- EL INTERRUPTOR: +USE APAGA LO QUE ESTA SONANDO
---------------------------------------------------------------------------
-- ⚠⚠ LAS DOS VIAS OBVIAS ESTAN CERRADAS, Y POR MOTIVOS DISTINTOS. Se averiguo
-- antes de escribir una linea:
--
--   `PlayerUse` sobre el prop     un `prop_static` NO ES UNA ENTIDAD. No hay a
--                                 quien usar -- es la misma razon por la que
--                                 existe todo el bloque de los horneados.
--   `PlayerUse` sobre el emisor   el emisor es un `info_target`: sin modelo y
--                                 sin colision, asi que el trace de uso no le
--                                 pega. `PlayerUse` se dispara POR ENTIDAD, y
--                                 esa entidad nunca va a ser el sujeto de un
--                                 trace.
--
-- Queda `KeyPress` con `IN_USE` y resolver a mano contra el registro. El addon
-- no tenia ningun `hook.Add( "KeyPress" )` ( medido: 0 en los 36 `.lua`; lo unico
-- parecido es un `ply:KeyDown( IN_USE )` de CLIENTE en el trucktv, que es para
-- otra cosa ). La tecnica se leyo de los 8 archivos de terceros que si lo usan
-- -- ARC9, Glide, ZBase, quick loadouts. ⚠ De un tercero se porta la TECNICA, no
-- el cableado.
--
-- ⚠⚠⚠ ESTE HOOK NO DEVUELVE NADA. NUNCA. `E` ya abre puertas, agarra props,
-- entra a vehiculos y lo consumen addons de terceros; `hook.Call` **aborta la
-- cadena** cuando un hook devuelve un valor, o sea que un `return` de aca se
-- lleva puestos a los de mas abajo en la fila. En este taller eso se pago dos
-- veces: `Corpus.OnReady` y el `return` de `PlayerSpawn` que se saltea
-- `GM:PlayerSpawn` ENTERO -- y con el, playermodel y loadout. Las salidas
-- tempranas de acá abajo son todas `return` PELADO, y `dev/auditar_returns_de_hooks.py`
-- lo comprueba en cada cierre.
local function apagarCerca( ply )
    podarSonando()

    local desde = ply:WorldSpaceCenter()
    local now   = CurTime()
    local radio = cvUseRad:GetInt()

    -- Se busca el mas cercano ENTRE LOS QUE TODAVIA SUENAN, y aparte el mas
    -- cercano entre los que ya terminaron. Los dos numeros hacen falta: sin el
    -- segundo, apretar al lado de un emisor cuyo clip ya se acabo imprimiria
    -- "no habia nada cerca", que manda a buscar un defecto de distancia donde lo
    -- que hubo fue llegar tarde.
    local mejor, mejorD, tardeD

    for i = 1, #SONANDO do
        local s = SONANDO[ i ]

        -- El filtro de familia se aplica ACA, al leer, y no al escribir: en el
        -- registro tambien viven los emisores del reloj y del televisor, que
        -- estan para el contador y **no** para el interruptor. El autor pidio
        -- *"solo esos por ahora"* y esa frontera es suya, no del mecanismo.
        if s.fam.apagable then
            local d = desde:Distance( s.ent:WorldSpaceCenter() )

            if s.hasta > now then
                if not mejorD or d < mejorD then mejor, mejorD = s, d end

            elseif not tardeD or d < tardeD then
                tardeD = d

            end
        end
    end

    -- Solo se habla si habia ALGO: un `E` en un mapa en silencio no escribe nada.
    -- Y si habia, se habla como mucho una vez cada `USE_LOG_CADA` segundos.
    local puedeHablar = ( now - USE.ultimoLog ) >= USE_LOG_CADA

    if not mejor then
        if tardeD then
            USE.tarde = USE.tarde + 1

            if puedeHablar then
                USE.ultimoLog = now

                anotar( string.format( "+USE de %s: lo mas cercano ( a %d u ) YA HABIA TERMINADO su clip. " ..
                    "No se apago nada, y eso NO es una falla del radio", ply:Nick(), math.Round( tardeD ) ) )

            end
        end

        return false

    end

    if mejorD > radio then
        USE.lejos = USE.lejos + 1

        if puedeHablar then
            USE.ultimoLog = now

            anotar( string.format( "+USE de %s: %s sonando a %d u, FUERA del radio de %d u. No se apago -- " ..
                "es el control negativo del interruptor", ply:Nick(), mejor.nombre,
                math.Round( mejorD ), radio ) )

        end

        return false

    end

    -- ⚠ LA POSICION SE GUARDA **ANTES** DE TOCAR NADA, y no es prolijidad: si el
    -- emisor es nuestro, tres lineas mas abajo deja de existir, y preguntarle
    -- despues por su posicion no devuelve la posicion -- devuelve un vector cero
    -- o un error, o sea el clic sonando en el origen del mapa.
    local donde = mejor.ent:WorldSpaceCenter()

    -- Apagar es callar SIEMPRE y borrar SOLO SI el emisor es nuestro.
    mejor.ent:StopSound( mejor.snd )

    local clase = mejor.ent:GetClass() .. " #" .. mejor.ent:EntIndex()

    if mejor.emisor then SafeRemoveEntity( mejor.ent ) end

    -- EL CLIC DEL INTERRUPTOR, en el unico lugar donde de verdad se apago algo.
    --
    -- ⚠ VA EN LA POSICION DEL OBJETO Y NO EN EL JUGADOR: el clic tiene que
    -- llegar DESDE donde estaba el ruido, que es lo que lo vuelve *"apagaste ese
    -- trasto"* en vez de *"apretaste una tecla"*.
    --
    -- ⚠⚠ `sound.Play` Y NO `EmitSound`, Y LA RAZON ES LA DE ARRIBA AL REVES: el
    -- sujeto puede ser un emisor nuestro que **acaba de dejar de existir**, y un
    -- sonido colgado de una entidad se va con ella. `sound.Play` es un sonido del
    -- mundo en un punto: no tiene de quien colgar. Ademas los dos casos -- emisor
    -- nuestro y prop de verdad del mapa -- salen por la MISMA linea, asi que el
    -- clic no suena distinto segun de quien fuera la radio.
    sound.Play( CLIC_APAGADO[ math.random( #CLIC_APAGADO ) ], donde,
        CLIC_NIVEL, math.random( 97, 103 ) )

    -- Se saca del registro en el acto y no en la poda siguiente: para un prop de
    -- verdad la entidad sigue siendo valida, asi que la poda no lo sacaria nunca
    -- y un segundo +USE "apagaria" un silencio.
    for i = #SONANDO, 1, -1 do
        if SONANDO[ i ] == mejor then table.remove( SONANDO, i ) end

    end

    USE.apagados = USE.apagados + 1

    anotar( string.format( "+USE de %s APAGO %s ( %s%s ) a %d u, faltandole %.1f s de clip",
        ply:Nick(), mejor.nombre, clase, mejor.emisor and ", emisor nuestro: BORRADO" or ", prop del mapa: solo callado",
        math.Round( mejorD ), math.max( 0, mejor.hasta - now ) ) )

    return true

end

hook.Add( "KeyPress", "phantasmagoria_prop_use", function( ply, key )
    if key ~= IN_USE then return end

    -- ⚠ EL CONTADOR SUBE ANTES QUE CUALQUIER PERILLA, y es a proposito: es la
    -- acreditacion de que el hook LLEGA AL SERVIDOR. Si subiera despues del
    -- `cvUse`, una convar en 0 y un hook que no corre imprimirian el mismo cero,
    -- y esa es exactamente la pregunta que la precondicion P1 vino a contestar.
    USE.teclas = USE.teclas + 1

    if not cvUse:GetBool() then return end
    if not IsValid( ply ) or not ply:IsPlayer() then return end

    apagarCerca( ply )

    -- Y no se devuelve nada. Ver el aviso de arriba.

end )

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
    -- ⚠⚠ UN CADAVER NO HACE EVENTOS PARANORMALES, y hasta la r2 SI los hacia.
    -- La base deja la entidad viva unos 10 s despues de la muerte
    -- ( damageandhealth.lua ), y ni el scheduler ni el comando manual miraban
    -- `term_Dead`: un fantasma muerto seguia tirando props y susurrando.
    --
    -- Se volvio URGENTE con el cambio de esta misma tanda. Con `sound.Play` en
    -- un punto, la voz del cadaver al menos SONABA ( mal, pero sonaba ). Con
    -- `ghost:EmitSound` el canal cuelga de la ENTIDAD, y la base ya le puso
    -- `EF_NODRAW` al morir -- que la manda a `FL_EDICT_DONTSEND` y el cliente
    -- **deja de recibirla**. O sea que el evento se dispara, el reporte dice OK,
    -- y no lo escucha nadie. Es el mecanismo que la r22 midio, aplicado en
    -- contra nuestra.
    --
    -- *Un cambio correcto puede volver grave un defecto que ya estaba y era
    -- benigno: hay que preguntarse a quien mas le cambia el piso.*
    --
    -- Va ACA y no en el scheduler porque el disparo manual no pasa por el
    -- scheduler, y hereda la guarda cualquier llamador futuro.
    if self.term_Dead then return 0, "el fantasma esta MUERTO ( la base lo borra a los ~10 s )" end

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

    -- ⚠⚠ EL SORTEO VA SIN REEMPLAZO, Y ANTES NO LO IBA. Lo destapo la bitacora
    -- del autor en la r3: `throw` salio REPETIDO en 3 de las 4 despertadas.
    -- No era mala suerte -- `sortearPeso` se llamaba fresco en cada vuelta sobre
    -- el mismo orden, asi que con el poltergeist ( throw pesa 8 de 16 ) sacar la
    -- misma dos veces tenia probabilidad 1/2 por tirada.
    --
    -- Por que es un defecto y no una preferencia: `count` esta documentado como
    -- *"categorias A LA VEZ"* y existe para **The Twins**, cuyo `radius` es un
    -- ARRAY INDEXADO POR ITERACION ( la vuelta 1 al radio normal, la 2 al
    -- extendido ). Dos tiros de la misma categoria no son dos interacciones: son
    -- la misma dos veces, a dos distancias. *Un parametro que dice "a la vez"
    -- tiene que sortear sin reemplazo o no dice eso.*
    --
    -- La copia se hace SOLO si hace falta ( count > 1 y sin forzar ): con count 1
    -- --los otros veintinueve tipos-- esto es exactamente el codigo de antes y no
    -- se paga una tabla por evento.
    local restantes = CAT_ORDER
    if cuantos > 1 and not forzada then
        restantes = {}
        for _, k in ipairs( CAT_ORDER ) do restantes[ #restantes + 1 ] = k end

    end

    -- EL BUCLE QUE SALVA A THE TWINS Y AL POLTERGEIST CON LA MISMA LINEA.
    -- Con count = 1 y radius = { 1.0 } es identico al comportamiento de los
    -- otros veintinueve tipos: no es una rama nueva, es un bucle de largo uno.
    for i = 1, cuantos do
        local cat

        if forzada then
            cat = forzada

        else
            cat = sortearPeso( flags.weights or {}, restantes )

            if not cat then
                -- ⚠ DOS ESTADOS DISTINTOS Y NO COMPARTEN RENGLON: que el tipo
                -- tenga todo en cero es un error de configuracion; que se
                -- agoten a mitad de camino es `count` pidiendo mas categorias
                -- de las que tienen peso, y es esperable. Con un solo mensaje,
                -- el segundo se leeria como el primero y mandaria a revisar
                -- ghost_flags.lua para nada.
                st.motivos.sorteo = ( i > 1 )
                    and ( "se agotaron las categorias con peso en la vuelta " .. i
                          .. " de " .. cuantos .. " ( count pide mas de las que hay )" )
                    or "todos los pesos del tipo estan en cero"
                break

            end

            -- sin reemplazo: sale del orden para las vueltas siguientes. Se
            -- recorre al reves para que el remove no saltee un elemento.
            if restantes ~= CAT_ORDER then
                for n = #restantes, 1, -1 do
                    if restantes[ n ] == cat then table.remove( restantes, n ) end

                end
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

            anotar( string.format( "%s %s %s r=%d %s%s", quien( self ),
                cazando and "HUNT " or "calma", cat, math.Round( radio ),
                tostring( detalle ), forzada and "  [FORZADO]" or "" ) )

        else
            anotar( string.format( "%s %s %s SIN SUJETO -- %s%s", quien( self ),
                cazando and "HUNT " or "calma", cat, tostring( detalle ),
                forzada and "  [FORZADO]" or "" ) )

        end
    end

    -- ⚠⚠ DOS CUENTAS Y NO UNA, y esto es lo que hacia INCONTESTABLE a la fila 01.
    -- La pregunta de esa fila es "¿el motor corrio SOLO?", y hasta la r1 el
    -- disparo forzado sumaba en el MISMO contador que el scheduler: el reporte
    -- decia `despertadas con al menos un evento: 87` sobre una sesion en la que
    -- el operador habia forzado a mano, y ese 87 no distingue las dos cosas. El
    -- pie de la planilla avisaba de la contaminacion y pedia un `reset`, o sea
    -- que le pedia al operador que no ensuciara el instrumento en vez de que el
    -- instrumento separara. *Cuando un contador tiene dos escritores y uno es el
    -- operador, no acredita al otro: hay que partirlo.*
    if salieron > 0 then
        if forzada then
            st.forzados = ( st.forzados or 0 ) + 1

        else
            st.disparos = st.disparos + 1

        end
    end

    return salieron, ultimoDetalle

end

-- Cuando le toca el proximo. Se separa del disparo para que el comando manual
-- pueda disparar SIN mover el reloj: si el disparo forzado reprogramara, medir
-- una categoria a mano cambiaria el ritmo de la partida que se esta midiendo.
function ENT:phantom_ScheduleEvent( primeraVez )
    local st    = estado( self )
    local flags = self:phantom_EventFlags()

    local rate = flags.rate or 1
    local mulHunt = 1

    if self.phantom_Hunting and cvHunt:GetInt() ~= 0 then
        mulHunt = ( flags.hunt and flags.hunt.rate ) or 1
        rate = rate * mulHunt

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

    -- ⚠ EL VALOR SORTEADO SE GUARDA, y hasta la r1 se tiraba: la funcion lo
    -- calculaba, lo devolvia, y el unico llamador ( el scheduler ) ignoraba el
    -- retorno. El reporte imprimia el RANGO de la convar y "proximo en N s",
    -- que juntos no dejan reconstruir el sorteo.
    --
    -- Costo real, medido en esta ronda: para decidir si el `rate` del hunt
    -- estaba dividiendo el intervalo hubo que sacar los huecos a mano de los
    -- timestamps de la bitacora y compararlos contra una media teorica. La
    -- respuesta era que SI dividia -- o sea que el codigo estaba bien y la duda
    -- la fabrico el instrumento. *Un valor que decide el comportamiento y no se
    -- imprime obliga a re-derivarlo, y re-derivar es donde se cuelan los
    -- errores.*
    st.ultimaEspera = espera
    st.ultimoRate   = rate
    st.ultimoRango  = { lo / rate, hi / rate }
    st.ultimaFuePrimera = primeraVez == true

    -- ⚠ SE GUARDA EL HECHO, NO LA CONDICION. La primera version dejaba que el
    -- reporte decidiera el rotulo "INCLUYE el multiplicador del hunt" leyendo
    -- `phantom_Hunting` **al imprimir**, mientras el numero que acompañaba se
    -- habia calculado **al sortear**. Un fantasma que entra en hunt despues del
    -- sorteo leia un rotulo que su propio numero desmentia: es la familia "la
    -- foto vieja" que este repo ya cerro dos veces ( r18 y r18b ).
    --
    -- Y se guarda el MULTIPLICADOR y no un booleano: un tipo cazando cuyo
    -- `hunt.rate` es 1.0 estaria en hunt sin que el hunt cambie nada, y el
    -- rotulo diria que incluye algo que no incluye.
    st.ultimoMulHunt = mulHunt

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

        -- ⚠ EL CONTADOR SOLO ES MONOTONO: SIN LA HORA NO DICE SI SIGUE CORRIENDO.
        -- `vueltas 209` se lee igual en un timer sano que en uno que murio hace
        -- diez minutos con 209 vueltas hechas, y esta linea es LA acreditacion
        -- del motor. Con la marca, el reporte puede decir "hace 0,4 s" o gritar.
        -- Copiado de server_cloak.lua, que ya lo hace para el reconciliador.
        st.vueltaT = CurTime()

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

---------------------------------------------------------------------------
-- LOS PROPS HORNEADOS DEL MAPA -- el instrumento de la fila 02
---------------------------------------------------------------------------
-- ⚠ EL NOMBRE NO PUEDE COLISIONAR CON UNA CONVAR. Una convar y un concommand
-- homonimos se registran los dos, la consola resuelve contra la convar primero
-- y el comando queda MUDO -- le costo dos filas a la ronda 2, y peor: la
-- planilla mandaba correr `<nombre> reset`, que en vez de resetear le asignaba
-- "reset" a la convar, o sea 0, o sea APAGABA lo que iba a medir. Por eso el
-- registro pasa por `AddCommand`, que vuelve la colision un error ruidoso.
-- Verificado antes de elegirlo: `phantasmagoria_ghost_estaticos` no existe hoy
-- ni como comando ni como convar.
--
-- ⚠⚠ Y LO QUE VUELVE AUDITABLE A ESTE COMANDO NO ESTA ACA: los numeros ya los
-- midio `dev/censo_props_horneados.py`, que queda en el repo y se vuelve a
-- correr con una linea. 418 modelos distintos en 1588 instancias. **Si el Lua
-- da otro numero, es el Lua el que esta mal.** Sin ese numero previo, cualquier
-- cosa que imprimiera esto se leeria como correcta -- que es como se perdio el
-- censo viejo, cuyo desglose no reproduce y quedo citado como prosa.
PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_estaticos", function( ply )
    if not adminOnly( ply ) then return end

    local say = PHANTASMAGORIA.MakeSay( ply )
    local d = PHANTASMAGORIA.Estaticos()

    say( "===== PROPS HORNEADOS ( prop_static, leidos del .bsp ) =====" )
    say( "  mapa        " .. tostring( d.mapa ) .. "   ( " .. tostring( d.ruta ) .. " )" )

    if not d.ok then
        say( "  !! NO SE PUDO LEER: " .. tostring( d.error ) )
        say( "  ⚠ esto NO es 'el mapa no tiene props horneados'. Es que no se pudo medir," )
        say( "    y las dos cosas se leen igual si uno mira un cero. La fila 02 es ROJA." )
        return

    end

    say( "  bsp         " .. d.bytes .. " bytes · VBSP " .. tostring( d.version ) ..
        " · sprp v" .. tostring( d.sprp_version ) .. " · " .. d.paso .. " bytes por entrada" )
    say( "  CONTROL     " .. d.sobrantes .. " byte(s) sobrantes ( tiene que ser 0 ) · " ..
        "las " .. d.n_modelos .. " rutas del diccionario tienen forma de modelo" )
    say( "" )
    say( "  modelos distintos     " .. d.n_modelos .. "     ( el .py midio 418 )" )
    say( "  instancias            " .. d.n_props .. "    ( el .py midio 1588 )" )

    local coincide = ( d.n_modelos == 418 and d.n_props == 1588 )
    say( "  -> " .. ( coincide and "COINCIDE con el censo de Python"
        or "!! NO COINCIDE. En gm_funkis_night el numero correcto es 418/1588; " ..
           "en otro mapa esta linea no aplica y hay que correr el .py sobre ese mapa." ) )

    -- El reparto por familias. Usa `modeloCoincide` NO: eso recibe una entidad.
    -- Usa la MISMA regla por debajo -- `NombreCoincide` -- que es todo el punto
    -- de haber partido `basenameDe` en dos ( ver el aviso de trampa 1 arriba ).
    local porModelo = PHANTASMAGORIA.EstaticosPorModelo()
    say( "" )
    say( "  LO QUE LAS FAMILIAS RECLAMARIAN SOBRE ESTOS " .. d.n_props .. ":" )

    local totM, totI = 0, 0
    for _, fam in ipairs( PROP_CONSUJETO ) do
        if fam.modelo then
            local nm, ni, muestra = 0, 0, {}
            for ruta, cuantos in pairs( porModelo ) do
                if PHANTASMAGORIA.NombreCoincide( PHANTASMAGORIA.BasenameDeRuta( ruta ), fam.modelo ) then
                    nm, ni = nm + 1, ni + cuantos
                    muestra[ #muestra + 1 ] = "x" .. cuantos .. " " .. ruta

                end
            end

            if nm > 0 then
                say( "    " .. fam.que .. ":  " .. nm .. " modelo(s) / " .. ni .. " instancia(s)" )
                table.sort( muestra )
                for _, linea in ipairs( muestra ) do say( "        " .. linea ) end

                totM, totI = totM + nm, totI + ni

            else
                say( "    " .. fam.que .. ":  ninguno" )

            end
        end
    end

    say( "  TOTAL RECLAMADO  " .. totM .. " modelo(s) / " .. totI .. " instancia(s)" )
    -- ⚠ ESTE BLOQUE SE ESCRIBIO EN PASADO EL 2026-08-16, Y EL MOTIVO IMPORTA.
    -- Mientras los cuatro falsos positivos estuvieron vivos, aca los anunciaba
    -- en presente. Se arreglaron el mismo dia y el texto quedo igual: la salida
    -- decia "8 modelo(s) / 11 instancia(s)" arriba y "el censo identifico 4
    -- modelos / 8 falsos" abajo, o sea que el propio instrumento se contradecia
    -- y el renglon viejo acusaba un defecto que ya no existia.
    --
    -- *Un instrumento que describe un defecto que el mismo ya no tiene no es
    -- documentacion vieja: es una medicion falsa, y la lee alguien que confia en
    -- el numero de al lado.* Queda como historia, y sirve de control: si algun
    -- dia el total vuelve a dar 12/19, es que un `nunca` se perdio.
    say( "" )
    say( "  HISTORIA -- este censo destapo 4 modelos / 8 instancias FALSOS ( 2026-08-16 )" )
    say( "    y ya estan ARREGLADOS en las reglas. Eran defectos que corrian sobre los" )
    say( "    prop_physics desde antes; este comando no los creo, los midio contra un" )
    say( "    universo grande por primera vez:" )
    say( "      radio_antenna01_skybox  -> ANTENA del skybox 3D  ( veto 'radio_antenna' )" )
    say( "      phone_book              -> una GUIA telefonica   ( veto 'phone_book' )" )
    say( "      toiletpaperroll x4 + toiletpaperdispenser x2 -> PAPEL ( veto 'toiletpaper' )" )
    say( "        eran 6 de las 9 'inodoro' del mapa, o sea dos de cada tres cadenas." )
    say( "    El total paso de 12/19 a 8/11. ⚠ Si alguna vez vuelve a dar 12/19, se" )
    say( "    perdio un `nunca`: este renglon es el control de esa regresion." )

    -- Las filas 06 ( la fuga ) y 07 ( el instrumento no se cuenta a si mismo ).
    -- ⚠ Se imprime tambien el conteo REAL de emisores en el mapa, y no solo el
    -- contador propio: si los dos numeros se separan, el que miente es el
    -- contador -- y un contador que miente convierte a la fila de la fuga en un
    -- verde que no mide nada.
    local reales = 0
    for _, e in ipairs( ents.FindByClass( "info_target" ) ) do
        if e.PhantasmagoriaEmisor then reales = reales + 1 end

    end

    -- `vivos` se DERIVA del registro y no de un contador que alguien mantiene a
    -- mano: ver el bloque EMISORES arriba y la trampa 3 del bloque del +USE.
    local _, caidas = podarSonando()
    local vivos, sonando, vencidos = 0, 0, 0
    local now = CurTime()

    for i = 1, #SONANDO do
        if SONANDO[ i ].emisor then vivos = vivos + 1 end
        if SONANDO[ i ].hasta > now then sonando = sonando + 1 else vencidos = vencidos + 1 end

    end

    say( "" )
    say( "  EMISORES ( las filas de la fuga y del salteo )" )
    say( "    vivos ahora      " .. vivos .. "   ( contados en el mapa: " .. reales ..
        ( vivos == reales and " -- coinciden )" or " -- ⚠ NO COINCIDEN, el registro miente )" ) )
    say( "    creados en total " .. EMISORES.creados ..
        ( EMISORES.creados == 0 and "   ( todavia ninguno: un 'vivos 0' aca no acredita nada )" or "" ) )
    say( "    salteados por el barrido " .. EMISORES.salteados ..
        ( EMISORES.salteados == 0 and "   ( con un emisor vivo al lado esto tiene que subir )" or "" ) )
    say( "    horneados en el sorteo   " .. ( cvHorneados:GetBool() and "1 ( encendido )"
        or "0 ( APAGADO -- control: el evento se comporta como antes del bloque )" ) )

    -- ⚠ EL REGISTRO SE IMPRIME ENTERO Y CON SUS DOS ESTADOS. Un "3 sonando" sin
    -- la lista no dice QUE suena, y un emisor cuyo clip ya termino ( `vencido` )
    -- no es lo mismo que uno sonando: apretar +USE al lado del segundo no apaga
    -- nada y eso NO es una falla del radio.
    say( "" )
    say( "  REGISTRO DE LO QUE SUENA   " .. #SONANDO .. " entrada(s)  ( " .. sonando ..
        " sonando · " .. vencidos .. " ya terminado(s) · " .. caidas .. " podada(s) en esta lectura )" )

    if #SONANDO <= 0 then
        say( "    vacio. Con `creados " .. EMISORES.creados .. "` esto se lee como " ..
            ( EMISORES.creados > 0 and "'todo se limpio', que es lo que se espera en reposo."
              or "'todavia no sono nada', que NO acredita el mecanismo." ) )

    else
        for i = 1, #SONANDO do
            local s = SONANDO[ i ]
            say( string.format( "    %-14s %-22s %s%s  quedan %.1f s", s.nombre,
                IsValid( s.ent ) and ( s.ent:GetClass() .. " #" .. s.ent:EntIndex() ) or "( invalida )",
                s.emisor and "emisor nuestro" or "prop DEL MAPA",
                s.fam.apagable and " · apagable con +USE" or " · NO apagable",
                math.max( 0, s.hasta - now ) ) )

        end
    end

    -- LAS FILAS DEL +USE. Los cuatro contadores estan porque los cuatro
    -- desenlaces se ven igual desde afuera: "apreté E y no pasó nada".
    say( "" )
    say( "  +USE ( el interruptor )   " .. ( cvUse:GetBool() and ( "encendido, radio " ..
        cvUseRad:GetInt() .. " u" ) or "0 ( APAGADO -- control )" ) )
    say( "    teclas IN_USE vistas por el hook  " .. USE.teclas ..
        ( USE.teclas == 0 and "   ⚠ CERO: o nadie apreto E, o el hook NO llega al servidor ( la P1 )"
          or "   ( el hook llega al servidor: esto es la P1 medida sin instrumento aparte )" ) )
    say( "    apagados de verdad                " .. USE.apagados )
    say( "    habia algo pero FUERA del radio   " .. USE.lejos ..
        "   ( este es el numero del control negativo; un 0 no prueba que el filtro decida )" )
    say( "    lo mas cercano YA HABIA TERMINADO " .. USE.tarde ..
        "   ( apagar un silencio se lee como exito: es la trampa 4 )" )

    -- EL PROP QUE SE ROMPE. Los dos numeros van juntos y en este orden porque
    -- **el segundo no se puede leer sin el primero**: un `callados 0` con
    -- `enganchados 0` no dice que el arreglo falle, dice que ningun prop de
    -- verdad llego a sonar todavia -- y esa es exactamente la lectura que la
    -- fila 01 no pudo hacer el 2026-08-18.
    say( "" )
    say( "  EL PROP QUE SE ROMPE ( pedido 2 )" )
    say( "    props de verdad que salieron a sonar con su corte puesto  " .. ROTOS.enganchados ..
        ( ROTOS.enganchados == 0
          and "   ⚠ CERO: todavia no sono ningun prop_physics. Un 'rompi la radio y sigue sonando' con este numero en 0 midio OTRA COSA -- el sonido salia de un emisor nuestro"
          or  "" ) )
    say( "    de esos, cuantos se CALLARON al morir                     " .. ROTOS.callados ..
        ( ROTOS.enganchados > 0 and ROTOS.callados == 0
          and "   ⚠ con enganchados > 0, esto en 0 quiere decir que el prop no se estaba borrando ( romper != borrar )"
          or  "" ) )

    -- EL PESTILLO. Se imprime aca y no solo en su comando porque la fila que
    -- pregunta "el evento prop dejo de sonar a llaves" y la que pregunta "las
    -- llaves aparecieron donde si hay" son la misma decision partida en dos.
    local trabadas = podarPestillos()

    say( "" )
    say( "  PESTILLO   " .. ( cvPestillo:GetBool() and "encendido" or "0 ( APAGADO -- control )" ) ..
        " · trabadas ahora " .. trabadas .. "/" .. PESTILLO_MAX ..
        " · vida " .. PESTILLO_VIDA .. " s · soltar todas: phantasmagoria_ghost_pestillo soltar" )
    say( "  LLAVES SIN SUJETO   " .. ( cvLlaves:GetBool()
        and "el evento `prop` NO suena el banco ambiente sin ninguna familia con sujeto"
        or "0 ( CONTROL -- el banco ambiente suena igual, como antes del bloque )" ) )

end, "Censa los prop_static horneados del mapa y que reclamarian las familias de sonido." )

---------------------------------------------------------------------------
-- INSTRUMENTO Y SALIDA DE EMERGENCIA DEL PESTILLO
---------------------------------------------------------------------------
-- ⚠ ESTE COMANDO NO ES UN LUJO NI UN DEBUG: es el limite de diseno numero tres
-- del pestillo. Trabar una puerta es la unica mecanica de este bloque que puede
-- dejar a alguien encerrado, y una mecanica con esa consecuencia necesita una
-- salida que no dependa de esperar 45 segundos ni de que el fantasma colabore.
--
-- ⚠⚠ Y LISTA ANTES DE SOLTAR. Un comando que solo suelta no deja medir nada: la
-- fila del pestillo necesita ver CUALES estan trabadas y cuanto les queda, y esa
-- lectura tiene que poder hacerse SIN cambiar el estado -- si la unica forma de
-- saber que habia dos trabadas fuera soltarlas, el instrumento destruiria lo que
-- mide, que es el defecto nº 48 del catalogo del taller.
PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_pestillo", function( ply, _, args )
    if not adminOnly( ply ) then return end

    local say = PHANTASMAGORIA.MakeSay( ply )
    local now = CurTime()
    local n   = podarPestillos()

    say( "===== PESTILLO ( las puertas que el fantasma trabo ) =====" )
    say( "  perilla      phantasmagoria_ghost_evpestillo = " .. ( cvPestillo:GetBool() and "1" or "0 ( control )" ) )
    say( "  tope         " .. n .. " de " .. PESTILLO_MAX .. " trabada(s) a la vez · vida " ..
        PESTILLO_VIDA .. " s" )

    if n <= 0 then
        say( "  ninguna trabada AHORA." )
        say( "  ⚠ esto no distingue 'el pestillo no salio' de 'ya se soltaron': mirar el renglon" )
        say( "    `pestillo CONFIRMADO` / `SIN EFECTO` en phantasmagoria_ghost_events." )

    else
        for i = 1, n do
            local p = PESTILLOS[ i ]

            -- Se relee `m_bLocked` en vez de creerle al registro: el registro dice
            -- lo que pedimos, la puerta dice lo que hay. Si se separan, el
            -- hallazgo es la separacion.
            say( string.format( "    %s #%d   m_bLocked=%s   le quedan %.0f s",
                p.door:GetClass(), p.door:EntIndex(), tostring( trabada( p.door ) ),
                math.max( 0, p.hasta - now ) ) )

        end
    end

    if args and args[ 1 ] == "soltar" then
        local sueltas = 0

        for i = n, 1, -1 do
            local p = PESTILLOS[ i ]
            table.remove( PESTILLOS, i )
            if soltarPestillo( p, "a mano, por comando" ) then sueltas = sueltas + 1 end

        end

        say( "  -> SOLTADAS " .. sueltas .. " de " .. n .. "." )

    else
        say( "  ( para abrirlas todas: phantasmagoria_ghost_pestillo soltar )" )

    end

end, "Lista las puertas que el fantasma trabo con pestillo; con 'soltar' las destraba todas." )

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_events", function( ply, _, args )
    if not adminOnly( ply ) then return end

    local say = PHANTASMAGORIA.MakeSay( ply )
    local sub = args and args[ 1 ]

    if sub == "reset" then
        PHANTASMAGORIA.EventLog = {}
        PHANTASMAGORIA.EventLogPerdidas = 0

        -- ⚠⚠ EL RESET NO PUEDE NILEAR LA TABLA ENTERA, y lo hacia. `phantom_ev`
        -- guarda contadores PERO TAMBIEN estado de comportamiento: `doorHasta`
        -- ( la cuarentena por puerta ) y `next` ( el reloj ). Nilearla:
        --   · borra la cuarentena, asi que el evento de puertas puede repetir la
        --     misma hoja que acababa de usar;
        --   · deja `next = 0`, y el scheduler trata el 0 como "recien nacido" y
        --     reprograma con `primeraVez`, o sea 4-12 s en vez del intervalo del
        --     tipo.
        -- Y la planilla manda correr `reset` JUSTO ANTES de las filas que miden
        -- ritmo. *Un boton que existe para limpiar el instrumento no puede
        -- fabricarle el primer dato a la medicion que viene.*
        local sinMotor = {}

        local n = PHANTASMAGORIA.EachGhost( function( ghost )
            -- ⚠ LOS OTROS TRES RECORRIDOS DE FANTASMAS DE ESTE ARCHIVO
            -- COMPRUEBAN QUE EL METODO EXISTA Y ESTE NO LO HACIA. Un fantasma de
            -- otra clase que declare `IsPhantasmagoriaGhost` sin incluir este
            -- archivo hace reventar el reset A LA MITAD: los que ya se
            -- recorrieron quedan reseteados, los de atras no, y el comando corta
            -- con un error de Lua. *Una guarda que esta en tres de cuatro sitios
            -- no es una guarda: es una costumbre.*
            if not isfunction( ghost.phantom_ScheduleEvent ) then
                sinMotor[ #sinMotor + 1 ] = quien( ghost )
                return

            end

            local st = estado( ghost )

            -- ⚠ `vueltas` NO SE BORRA, y esto es el arreglo de una
            -- contradiccion: el reporte imprime, al lado de ese numero, *"si
            -- dice 0, el timer NO esta corriendo"*. Ponerlo en cero fabricaba el
            -- sintoma exacto de un motor muerto, en el comando que el operador
            -- corre JUSTO ANTES de medir. No es un contador de la medicion: es
            -- la acreditacion de que el motor existe.
            st.disparos = 0
            st.forzados = 0
            st.porCat   = {}
            st.motivos  = {}
            st.ultimo   = nil
            st.ultimoT  = 0

            -- La cuarentena de puertas NO se toca: es comportamiento. El reloj
            -- SI se reprograma, y a proposito -- ver el texto de abajo.
            ghost:phantom_ScheduleEvent( false )

        end )

        -- ⚠ LOS CUATRO DEL +USE SI SE BORRAN, PORQUE SON DEL INSTRUMENTO Y DE
        -- NADIE MAS: nadie se comporta distinto porque `teclas` valga 0 o 900. Lo
        -- que NO se toca es `SONANDO` ni `PESTILLOS`, que son COMPORTAMIENTO --
        -- vaciar el registro dejaria una radio sonando que el +USE ya no puede
        -- apagar, y vaciar los pestillos dejaria puertas trabadas sin quien las
        -- suelte. *Un boton que limpia el instrumento no puede tocar el mundo.*
        USE.teclas, USE.apagados, USE.lejos, USE.tarde = 0, 0, 0, 0

        say( "[Phantasmagoria] bitacora y contadores borrados en " .. ( n - #sinMotor ) .. " fantasma(s)." )
        say( "                 la cuarentena de puertas NO se toca ( es comportamiento )." )
        say( "                 los cuatro contadores del +USE SI se borran ( son del instrumento )." )
        say( "                 el registro de lo que suena y los pestillos NO: son el mundo." )
        -- ⚠ ESTA LINEA DECIA "el reloj NO se toca" Y LA LINEA DE ARRIBA LO
        -- REPROGRAMA. Reprogramar es lo correcto -- si no, la primera muestra de
        -- la medicion seria el resto del intervalo en vuelo, que esta sesgado
        -- corto -- pero el operador tiene que saber cual de las dos cosas pasa.
        -- *Un comentario y su codigo pueden contradecirse en dos lineas
        -- consecutivas sin que ninguna prueba lo note.*
        say( "                 el reloj SE REPROGRAMA con el intervalo del tipo ( 25-90 s / rate )," )
        say( "                 no con el de bienvenida ni con el resto del anterior." )

        if #sinMotor > 0 then
            say( "                 ⚠ " .. #sinMotor .. " sin el motor, NO reseteado(s): " ..
                table.concat( sinMotor, ", " ) )

        end

        return

    end

    say( "" )
    say( "===== EVENTOS PARANORMALES ( Diseno 21 ) =====" )
    say( "  maestro     phantasmagoria_ghost_paranormal = " .. cvMaster:GetInt() ..
        ( cvMaster:GetBool() and "  ( encendido )" or "  ⚠ APAGADO: el scheduler no corre" ) )
    say( "  radio base  " .. math.Round( cvRadius:GetFloat() ) .. " u   ( alrededor del FANTASMA, no del jugador )" )
    say( "  intervalo   " .. math.Round( cvMin:GetFloat() ) .. " a " .. math.Round( cvMax:GetFloat() ) ..
        " s, dividido por el `rate` del tipo Y ADEMAS por el `hunt.rate` si esta cazando" )
    say( "              ( el valor que de verdad salio esta en la linea 'sorteado' de cada fantasma )" )
    say( "  masa tope   " .. math.Round( cvMass:GetFloat() ) .. " kg" )
    say( "  reserva     phantasmagoria_ghost_evreserva = " .. cvReserva:GetInt() ..
        ( cvReserva:GetBool() and "  ( `voice` y `humming` guardados para el paramic y la manifestacion )"
          or "  ( CONTROL: todo al sorteo, como en la r2 )" ) )
    say( "  en el hunt  phantasmagoria_ghost_evhunt = " .. cvHunt:GetInt() ..
        ( cvHunt:GetInt() == 0 and "  ( CONTROL: cazando no hay eventos )"
          or "  ( los multiplicadores `hunt` del tipo deciden )" ) )

    -- ⚠ LAS TRES DEL BLOQUE DEL +USE SE IMPRIMEN ACA AUNQUE TENGAN SU PROPIO
    -- RENGLON EN `phantasmagoria_ghost_estaticos`. El operador lee ESTE comando
    -- para saber en que estado esta el motor antes de una corrida, y una perilla
    -- que solo se ve en otro comando es una perilla que va a estar en el valor
    -- equivocado durante una fila entera -- ya paso en este mismo repo con
    -- `opendoors`, que dio un verde exacto sobre cero comportamiento.
    say( "  +USE        phantasmagoria_ghost_evuse = " .. cvUse:GetInt() ..
        ( cvUse:GetBool() and ( "  ( apaga radio y telefono a " .. cvUseRad:GetInt() .. " u )" )
          or "  ( CONTROL: +USE no apaga nada )" ) )
    say( "  llaves      phantasmagoria_ghost_evllaves = " .. cvLlaves:GetInt() ..
        ( cvLlaves:GetBool() and "  ( sin sujeto el evento `prop` NO suena, y dice por que )"
          or "  ( CONTROL: el banco ambiente suena igual que antes del bloque )" ) )
    say( "  pestillo    phantasmagoria_ghost_evpestillo = " .. cvPestillo:GetInt() ..
        ( cvPestillo:GetBool() and ( "  ( puede trabar hasta " .. PESTILLO_MAX .. ", vida " ..
          PESTILLO_VIDA .. " s )" ) or "  ( CONTROL: nunca traba )" ) )

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
        -- ⚠ EL ROTULO DEL CADAVER, Y ENTRA POR LA MISMA LECCION QUE ESTA ESCRITA
        -- EN server_cloak.lua: la guarda de `term_Dead` se puso en el MOTOR y no
        -- en el TEXTO, o sea la mitad que el operador lee. Sin esto, un cadaver
        -- se lista como "( calma )" con su `proximo en 12 s` como si fuera a
        -- ocurrir -- y no va a ocurrir nunca, porque phantom_FireEvent lo corta.
        -- El comando gemelo de este MISMO commit ya lo hacia bien; este no.
        --
        -- *Que la leccion este escrita en el archivo de al lado no la aplica.*
        say( "  --- fantasma #" .. ghost:EntIndex() .. "  ( " ..
            ( ghost.term_Dead and "MUERTO -- el motor NO dispara; la base lo borra a los ~10 s"
              or ( ghost.phantom_Hunting and "HUNT" or "calma" ) ) .. " ) ---" )
        say( "    rasgos    " .. deDonde )

        -- ⚠ SE IMPRIMEN LOS DOS: el RASGO ( lo que el tipo pide ) y el VALOR
        -- RESUELTO ( lo que se sorteo ). La voz solo se sortea en el primer
        -- evento de sonido, asi que un check de "la Banshee es femenina"
        -- corrido antes de eso leia "sin sortear" sobre una Banshee correcta y
        -- se anotaba como un rojo.
        --
        -- ⚠ Y DESDE ESTE BLOQUE SE IMPRIME **LA CADENA ENTERA**, no sus dos
        -- puntas. Con la prioridad tipo > modelo > sorteo, un "resuelta 1" sobre
        -- un Banshee no distingue *la fijo el tipo* de *salio 1 en la moneda*, y
        -- la moneda acierta la mitad de las veces: una fila que lea solo el
        -- resultado da VERDE sobre el mecanismo apagado en el 50 % de las
        -- corridas. El `por:` es lo que la vuelve una medicion.
        local vozRasgo  = flags.voice or 0
        local vozModelo = PHANTASMAGORIA and isfunction( PHANTASMAGORIA.VozDelModelo )
            and PHANTASMAGORIA.VozDelModelo( ghost:GetModel() ) or nil

        say( "    voz       tipo " .. ( vozRasgo == 0 and "0 ( no la fija )" or
            ( vozRasgo .. ( vozRasgo == 1 and " ( fija: femenina )" or " ( fija: grave )" ) ) ) ..
            "   modelo " .. ( vozModelo and
                ( vozModelo .. ( vozModelo == 1 and " ( femenina )" or " ( grave )" ) )
                or "no la declara" ) ..
            "   resuelta " .. ( ghost.phantom_evVoice and
                ( ghost.phantom_evVoice .. ( ghost.phantom_evVoice == 1 and " ( femenina )" or " ( grave )" ) )
                or "SIN SORTEAR ( se resuelve en el primer evento de sonido )" ) )

        -- El motivo va en su propia linea porque es lo unico que separa las tres
        -- causas, y una linea que se corta no se lee.
        if ghost.phantom_evVoice then
            say( "              por: " .. tostring( ghost.phantom_evVoiceWhy or "( sin motivo declarado )" ) )

        end

        -- ⚠ ESTAS DOS LINEAS SON LA ACREDITACION DEL SCHEDULER. Sin ellas, "no
        -- pasa nada" no distingue un motor apagado de un motor que corre y no
        -- encuentra sujetos.
        --
        -- ⚠ EL NUMERO SOLO ES MONOTONO Y NO CADUCA: `vueltas 209` se lee igual
        -- en un timer sano que en uno que murio hace diez minutos habiendo hecho
        -- 209. La hora de la ultima vuelta es lo que lo vuelve una medicion del
        -- PRESENTE. *Un contador que solo sube dice que algo corrio alguna vez,
        -- no que este corriendo.*
        local desdeVuelta = st.vueltaT and ( CurTime() - st.vueltaT ) or nil

        say( "    vueltas   " .. st.vueltas .. " del scheduler  ( a " .. TICK .. " Hz; " ..
            ( desdeVuelta == nil and "TODAVIA NINGUNA: el timer no lo alcanzo ( o no esta corriendo )"
              or ( desdeVuelta > TICK * 2
                   and ( "!! LA ULTIMA FUE HACE " .. string.format( "%.1f", desdeVuelta ) ..
                         " s, y deberia ser cada " .. TICK .. " s: EL TIMER DEJO DE CORRER" )
                   or ( "la ultima hace " .. string.format( "%.1f", desdeVuelta ) .. " s" ) ) ) .. " )" )
        -- ⚠ ESTE NUMERO Y EL `disparos` DE CADA CATEGORIA SON DOS CUENTAS
        -- DISTINTAS, y hasta la revision se llamaban igual. Este cuenta
        -- DESPERTADAS con al menos un exito; el de abajo cuenta EVENTOS por
        -- categoria. Con `count` > 1 -- o sea Poltergeist y The Twins, justo los
        -- dos tipos que este bloque existe para lucir -- divergen, y la suma de
        -- las ocho columnas puede ser mayor que este. En los otros 28 coinciden,
        -- que es lo que hace el defecto dificil de ver.
        --
        -- ⚠⚠ Y SON DOS CUENTAS TAMBIEN POR OTRO EJE: espontaneas contra
        -- forzadas. La fila 01 de la planilla pregunta "¿el motor corrio SOLO?"
        -- y hasta la r1 este numero sumaba los disparos del operador, asi que la
        -- fila no podia contestarse con su propia salida.
        --
        -- ⚠ EL CONTADOR SE PARTIO Y SU VECINO NO. `st.ultimo` lo escribe
        -- cualquiera de los dos caminos, asi que colgado del renglon rotulado
        -- "( el scheduler, solo )" mostraba el ultimo evento del OPERADOR como
        -- si fuera del motor -- que es exactamente lo que el corte existia para
        -- impedir. Va en su propia linea, sin dueño.
        say( "    despertadas ESPONTANEAS ( el scheduler, solo ): " .. st.disparos )
        say( "    despertadas FORZADAS ( phantasmagoria_ghost_event ): " .. ( st.forzados or 0 ) ..
            ( ( st.forzados or 0 ) > 0
              and "   <- estas NO acreditan al motor; van rotuladas [FORZADO] en la bitacora"
              or "" ) )
        say( "    ultimo evento ( de cualquiera de los dos caminos ): " ..
            ( st.ultimo and ( st.ultimo .. " hace " .. math.Round( CurTime() - st.ultimoT ) .. " s" )
              or "ninguno todavia" ) )

        local falta = st.next - CurTime()
        say( "    proximo   " .. ( st.next <= 0 and "sin programar" or
            ( falta > 0 and ( "en " .. string.format( "%.1f", falta ) .. " s" )
              or ( "YA ( vencido hace " .. string.format( "%.1f", -falta ) .. " s )" ) ) ) )

        -- El intervalo REALMENTE SORTEADO, no el rango de la convar. Sin esta
        -- linea, decidir si el `rate` del hunt divide el intervalo obliga a
        -- restar timestamps de la bitacora a mano.
        if st.ultimaEspera then
            local r = st.ultimoRango or { 0, 0 }

            -- ⚠ EL ROTULO DEL HUNT SALE DE LO QUE SE APLICO AL SORTEAR, no de lo
            -- que el fantasma este haciendo AHORA. Ver `ultimoMulHunt`.
            local mh = st.ultimoMulHunt or 1

            say( "    sorteado  " .. string.format( "%.1f", st.ultimaEspera ) .. " s" ..
                ( st.ultimaFuePrimera and "  ( la PRIMERA, que va a 4-12 s a proposito y no usa el rate )"
                  or ( "  ( rango efectivo " .. string.format( "%.1f", r[ 1 ] ) .. " a " ..
                       string.format( "%.1f", r[ 2 ] ) .. " s, con rate x" ..
                       string.format( "%.2f", st.ultimoRate or 1 ) ..
                       ( mh ~= 1
                         and ( " -- INCLUYE el x" .. string.format( "%.2f", mh ) ..
                               " del hunt, aplicado AL SORTEAR" )
                         or " -- sin multiplicador de hunt en ese sorteo" ) .. " )" ) ) )

        end

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

        -- ⚠ EL PESO Y EL BANCO YA NO SE LLAMAN IGUAL, Y LA LINEA DE ARRIBA
        -- SIGUE HABLANDO DE PESOS. Sin esta segunda linea, un operador lee
        -- `voice 4` y espera oir frases, que es exactamente lo que la reserva
        -- impide. *Cuando un rotulo deja de nombrar lo que produce, el
        -- instrumento tiene que decir las dos cosas o miente por omision.*
        if cvReserva:GetBool() then
            say( "              -> con la RESERVA puesta, el peso 'voice' sale por el banco `whisper`" )
            say( "                 ( 8 clips ) y el peso 'humming' NO participa. Los guarda para el" )
            say( "                 paramic y para la manifestacion. Apagar con phantasmagoria_ghost_evreserva 0." )

        else
            say( "              -> reserva APAGADA ( control ): los tres pesos salen por su banco homonimo," )
            say( "                 o sea el comportamiento de la r2." )

        end

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

    -- ⚠ LA BITACORA ES GLOBAL, y el que la lee la lee como si fuera de UN
    -- fantasma. En la r1 hay un tramo con `#442` y `#452` intercalados y nada lo
    -- decia. Se cuenta cuantos sujetos distintos la escribieron, con la serie de
    -- `quien()` como clave -- que es lo que hace separables las lineas.
    local sujetos, nSujetos = {}, 0

    for i = 1, #log do
        local id = string.match( log[ i ], "(#%d+/s%S+)" )

        if id and not sujetos[ id ] then
            sujetos[ id ] = true
            nSujetos = nSujetos + 1

        end
    end

    local perdidas = PHANTASMAGORIA.EventLogPerdidas or 0

    say( "" )
    say( "  bitacora ( " .. #log .. " / " .. BITACORA_MAX .. " renglones" ..
        ( nSujetos > 0 and ( ", de " .. nSujetos .. " fantasma(s)" ) or "" ) ..
        ( perdidas > 0 and ( ", " .. perdidas .. " YA DESCARTADAS" ) or "" ) ..
        " ) -- lo que un comando en vivo ya no alcanza a ver:" )

    if perdidas > 0 then
        say( "    ⚠ la ventana se lleno y tiro " .. perdidas .. " renglon(es). Lo de abajo es la COLA," ..
            " no la corrida entera." )

    end

    if nSujetos > 1 then
        say( "    ⚠ hay " .. nSujetos .. " fantasmas escribiendo aca. Filtrar por la serie ( /sN )" ..
            " antes de leer un ritmo: el EntIndex se recicla." )

    end

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

        -- ⚠⚠ EL SEGUNDO RETORNO SE TIRABA, Y CON EL LA UNICA GUARDA NUEVA DE ESTA
        -- TANDA. `phantom_FireEvent` devuelve ( salieron, porque ), y la guarda
        -- del cadaver contesta por ahi -- pero este comando descartaba el segundo
        -- valor e imprimia `st.motivos[ cat ]`, que es la FOTO DEL DISPARO
        -- ANTERIOR. Sobre un fantasma muerto decia "NO SALIO" y abajo el motivo
        -- de la vez que si habia salido: un motivo viejo puesto al lado de un
        -- veredicto nuevo, que es la familia de la foto vieja otra vez.
        --
        -- *Escribir una guarda que contesta por un canal que nadie lee es
        -- escribir una guarda muda -- y peor, deja hablando al que estaba antes.*
        local salieron, porque = ghost:phantom_FireEvent( cat )
        local st = estado( ghost )

        say( "    #" .. ghost:EntIndex() .. "  " .. cat .. " -> " ..
            ( salieron > 0 and ( salieron .. " disparo(s)" ) or "NO SALIO" ) )
        say( "        " .. tostring( ( salieron <= 0 and porque )
            or st.motivos[ cat ]
            or "sin motivo registrado ( el bucle ni lo intento )" ) )

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

-- ( 3b ) LAS FAMILIAS `entero` TIENEN QUE TENER MEDIDO CADA CLIP, Y NINGUNO DE MAS.
-- Es la guarda del bloque del +USE, y las dos direcciones importan por motivos
-- distintos:
--
--   · un clip SIN duracion cae en la tanda fija de `EMISOR_VIDA`, o sea que el
--     emisor se muere a los 20 s y **decapita el clip por la otra puerta** --
--     exactamente el defecto que sacarle el `largo` a la radio vino a cerrar. No
--     tira ningun error: se oye una radio que se corta, que es lo que se oia
--     antes, y la ronda se cierra creyendo que el arreglo entro.
--   · una duracion HUERFANA ( medida para un clip que ya no esta en la lista ) es
--     una nota mentirosa esperando lector: el proximo que agregue un clip la va a
--     copiar como si describiera algo.
--
-- ⚠ LA LISTA SE SACA CONTANDO LAS ASIGNACIONES Y NO LEYENDO LA PROSA QUE LAS
-- DESCRIBE. Esta guarda recorre `PROP_CONSUJETO` de verdad; la guarda gemela de
-- MyClassTask que esta veinte lineas mas abajo existe porque una version anterior
-- copio la lista de un comentario y quedo gritando por una clave que nunca hubo.
do
    local faltan, sobran = {}, {}

    for _, fam in ipairs( PROP_CONSUJETO ) do
        if fam.entero then
            local declarados = {}

            for _, ruta in ipairs( fam.sonidos or {} ) do
                declarados[ ruta ] = true

                if not ( fam.dur and fam.dur[ ruta ] ) then
                    faltan[ #faltan + 1 ] = fam.que .. " -> " .. ruta

                end
            end

            for ruta in pairs( fam.dur or {} ) do
                if not declarados[ ruta ] then
                    sobran[ #sobran + 1 ] = fam.que .. " -> " .. ruta

                end
            end
        end

        -- `apagable` sin `entero` no es fatal, pero si es una incoherencia que se
        -- paga tarde: la ventana del +USE sale de `dur`, asi que una familia
        -- apagable sin duraciones se apaga bien mientras el clip suena y despues
        -- queda "apagable" durante los 20 s de la tanda fija -- o sea que el
        -- jugador apagaria un silencio y el instrumento lo contaria como exito.
        if fam.apagable and not fam.entero then
            faltan[ #faltan + 1 ] = fam.que .. " -> es `apagable` y NO es `entero` ( sin duraciones, " ..
                "la ventana del +USE es la tanda fija y no el clip )"

        end
    end

    if #faltan > 0 or #sobran > 0 then
        ErrorNoHalt( "[Phantasmagoria] duraciones de clip mal declaradas en PROP_CONSUJETO. " ..
            "SIN DURACION ( el emisor los va a decapitar a los " .. EMISOR_VIDA .. " s ): " ..
            ( #faltan > 0 and table.concat( faltan, " | " ) or "ninguno" ) ..
            "   ·   HUERFANAS ( duracion de un clip que ya no esta en la familia ): " ..
            ( #sobran > 0 and table.concat( sobran, " | " ) or "ninguna" ) .. "\n" )

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
--   · la guarda de server_cloak.lua ( "LAS DOS GUARDAS DEL CIERRE" ) itera
--     `{ "Think", "ModifyMovementSpeed" }`: DOS claves, no tres.
--   · el bloque "NO VA EN ENT.MyClassTask" del mismo archivo dice, con todas las
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

-- ( 6 ) LA REGLA DE IDENTIDAD DE MODELO VIVE EN OTRO ARCHIVO, Y ESTE NO CONTROLA
-- CUANDO CARGA. `basenameDe` y `modeloCoincide` delegan en
-- `phantasmagoria/bsp_statics.lua`, que lo incluye `lua/autorun/`. El orden
-- entre `lua/autorun/` y `lua/entities/` lo decide el ENGINE, que es un tercero,
-- y este taller ya pago tres defectos por asumir tres APIs suyas.
--
-- Que las funciones no esten AHORA no es fatal -- las delegadas se llaman en
-- runtime, no al incluir -- pero que no esten NUNCA si lo es: la clasificacion
-- de familias reventaria recien en el primer evento de props, o sea en juego y
-- con el fantasma delante. Se avisa en el momento barato.
--
-- ⚠ El chequeo va DIFERIDO a `Initialize` a proposito. Hacerlo aca mismo diria
-- "no existe" en el caso perfectamente sano de que los entities carguen
-- primero, y una guarda que grita cuando todo esta bien se aprende a ignorar --
-- que es como se pierde la vez que si importaba.
hook.Add( "Initialize", "phantasmagoria_eventos_regla_de_modelo", function()
    if isfunction( PHANTASMAGORIA.BasenameDeRuta ) and isfunction( PHANTASMAGORIA.NombreCoincide ) then return end

    ErrorNoHalt( "[Phantasmagoria] la regla de identidad de modelo NO EXISTE: " ..
        "`PHANTASMAGORIA.BasenameDeRuta` / `NombreCoincide` deberian venir de " ..
        "phantasmagoria/bsp_statics.lua, que carga desde lua/autorun/phantasmagoria_data.lua. " ..
        "Sin ellas, el evento de props no puede clasificar NINGUNA familia y revienta en el " ..
        "primer sorteo. Mirar si el archivo esta en la lista DATOS.\n" )

end )
