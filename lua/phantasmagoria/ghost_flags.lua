--[[-------------------------------------------------------------------------
    Phantasmagoria - LOS RASGOS DE EVENTO DE LOS 30 TIPOS

    Diseno 21. Esta tabla es la mitad de datos del motor de eventos
    paranormales; la otra mitad -- el motor -- vive en
    lua/entities/terminator_nextbot_phantom/server_events.lua

    ⚠⚠ POR QUE ESTO NO VA ADENTRO DE ghost_types.lua, QUE ERA LO OBVIO.

    ghost_types.lua dice, en su primera linea, "GENERADO AUTOMATICAMENTE. No
    editar a mano". Y no es una convencion: dev/gen_types.py:119 abre el archivo
    con io.open( OUT, "w" ) y lo PISA ENTERO. Un rasgo escrito a mano ahi
    desaparece la proxima vez que alguien regenere los tipos, sin error y sin
    rastro -- y el sintoma seria un Poltergeist que dejo de tirar cosas, tres
    semanas despues, sin que nada haya tocado el motor.

    ( Y el generador hoy ni siquiera es re-corrible: su entrada, dev/g2.json, NO
      ESTA EN DISCO. Eso hace la trampa PEOR, no mejor: la regeneracion es un
      evento raro, y un defecto que aparece una vez por semestre no se asocia
      con su causa. )

    Asi que los rasgos viven aca y se FUSIONAN sobre las filas al cargar. La
    fusion es la de prop_data_eq.lua sobre prop_data.lua, y por el mismo motivo:
    la division es por PROCEDENCIA -- lo generado alla, lo decidido aca -- y en
    runtime hay un solo diccionario.

    ---------------------------------------------------------------------------
    LOS RASGOS SALEN DE LOS COMENTARIOS DE LA FUENTE, NO DE LA IMAGINACION
    ---------------------------------------------------------------------------

    Cada fila de ghost_types.lua trae un bloque "-- Comportamiento del juego
    ( de la fuente; guia lo que hay que implementar )". Se leyeron los 30 y se
    saco de ahi el eje que cada tipo mueve. La linea de la fuente va citada al
    lado de cada rasgo, con su numero de linea en ghost_types.lua, para que la
    afirmacion se pueda auditar sin volver a la wiki.

    ⚠ CINCO TIPOS NO DICEN NADA DE EVENTOS y por eso NO TIENEN FILA aca: aswang,
    demon, gallu, obambo y spirit. No es un olvido -- es el dato. Spirit ademas
    es explicitamente el baseline del juego. Una fila neutra escrita "por
    prolijidad" convertiria cinco mediciones en cinco suposiciones
    indistinguibles de las otras veinticinco.

    ( Eran SEIS hasta que se agrego el rasgo `voice`: dayan no tiene ni un rasgo
      de evento, pero la fuente dice "Can only be female" y la voz SI tiene
      destino. La fila de dayan tiene un solo campo. Vale como aviso general:
      *"este tipo no dice nada" depende del eje que se este mirando*, y agregar
      un eje puede sacar una fila de esa lista sin que ningun dato haya
      cambiado. )

    ⚠ Y UN AVISO SOBRE demon: el brief de este bloque esperaba "mas eventos", y
    la fuente NO LO DICE -- solo dice que caza antes ( hunt.threshold = 70, que
    ya esta en ghost_types.lua ). Se deja sin fila a proposito.

    ---------------------------------------------------------------------------
    LAS TRES REGLAS DEL CORTE, Y LAS DOS QUE LO PROBARON
    ---------------------------------------------------------------------------

    El corte se probo contra The Mimic y The Twins, que son las pruebas de fuego
    que el diseno declara: si alguno necesita un `if` en el motor, el motor esta
    mal cortado. Sobreviven los dos, con tres condiciones que son estructurales
    y hay que respetarlas desde hoy aunque el Mimic no exista todavia:

    ( 1 ) LOS RASGOS VAN EN SUB-TABLAS, NUNCA EN LA RAIZ DE LA FILA.
          The Mimic imita "all behaviors, tells, and abilities ... EXCLUDING
          EVIDENCE" ( ghost_types.lua:556-557 ). Con los rasgos adentro de
          `events`, imitar es devolver el `events` del imitado y listo. Sueltos
          al lado de `name` y `evidence` haria falta una lista de exclusiones
          campo por campo, que hay que mantener cada vez que se agrega un rasgo:
          un `if` diferido.

    ( 2 ) EL MOTOR LEE POR UN GETTER, NUNCA EL CAMPO.
          ENT:phantom_EventFlags(). El Mimic lo va a sobreescribir para devolver
          la ficha del imitado sin tocar `phantom_Type` -- porque `phantom_Type`
          es lo que el HUD networkea, y cambiarlo cada 30-120 s le regalaria al
          jugador la respuesta que el Mimic existe para esconder.

          ⚠ EL REPO HACE HOY LO CONTRARIO Y ESTA MEDIDO: phantom_GetType()
          ( server_type.lua:268 ) tiene CERO llamadores, y los cuatro
          consumidores que hay leen `phantom_Type` crudo
          ( server_type.lua:282 y :320, server_speed.lua:266 y :687 ). O sea que
          el patron instalado es el que rompe al Mimic. Este archivo no lo
          arregla -- no es su bloque -- pero el motor de eventos no lo copia.

    ( 3 ) `radius` ES UN ARRAY, NO UN ESCALAR.
          The Twins hace "2 interactions at the same time, one within its
          standard radius and the other within its extended radius"
          ( ghost_types.lua:576-577 ). Con `count = 2` y `radius = { 1.0, 4.0 }`
          el motor es un bucle de largo `count` que indexa el array por la
          iteracion. Con `count = 1` y `radius = { 1.0 }` ese bucle es
          EXACTAMENTE el comportamiento de los otros veintinueve: no hay rama
          nueva, hay un bucle de largo uno.

    ---------------------------------------------------------------------------
    QUE SE DECLARO FUERA DE ALCANCE, Y POR QUE SE ESCRIBE ACA
    ---------------------------------------------------------------------------

    Se escriben para que la proxima sesion no los "descubra" y los meta como un
    `if`. Un hueco anotado sobre el eje correcto es lo unico que evita eso.

      breaker         Hantu "cannot turn ON the breaker" ( :200 ) y Jinn
                      "cannot directly turn OFF the breaker" ( :222 ) son la
                      asimetria mejor sostenida de toda la tabla -- y GMod NO
                      TIENE cuadro de luces. El rasgo tiene dos sostenedores y
                      CERO destino. No se escribe un mecanismo sin destino.

      llamas          Onryo apaga velas ( :388-394 ). Las velas son un item de
                      equipamiento ( EQUIPAMIENTO.md ) que todavia no es una
                      entidad encendible. Mismo caso.

      temperatura     Hantu y nadie mas ( :199, :202 ). Los doce tipos con
                      evidence "freezing" son EVIDENCIA, no evento: no cuentan
                      como sostenedores. Singleton real -- no se crea el rasgo
                      hasta que haya un segundo tipo.

      apariciones     Oni, Shade, Phantom, Deogen, Goryo, Obake, Wraith -- siete
                      sostenedores, o sea el segundo mejor rasgo de la tabla. Y
                      NO SE ESCRIBE, porque la visibilidad de este fantasma
                      tiene UN dueno unico y es server_cloak.lua ( Diseno 20 ).
                      Un evento de manifestacion que llame SetNoDraw por su
                      cuenta pelea contra el reconciliador de la ausencia y el
                      sintoma seria un fantasma que parpadea cuando no debe.
                      Cuando se escriba, entra POR phantom_SetVisible y no por
                      al lado.

      react.*         Yokai reacciona a la voz, Raiju y Revenant a la
                      electronica, Phantom a que lo fotografien. Son PERCEPCION
                      -- que cambia como te DETECTA -- y no eventos. Van con el
                      bloque de percepcion ( Diseno 18 ), no con este.

      posicion doble  The Twins "motion sensors, salt and spirit box responses
                      only occur at its PHYSICAL location" ( :574-575 ). Eso no
                      es un rasgo: es que la entidad tenga dos posiciones. Y los
                      tres consumidores que nombra no existen. Fuera de alcance
                      por escrito.
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

---------------------------------------------------------------------------
-- LA FILA NEUTRA -- el contrato, y el unico lugar donde vive un default
---------------------------------------------------------------------------
-- Todo lo que el motor lee tiene que estar aca con su valor neutro. No es
-- prolijidad: el resolvedor de mas abajo NO inventa defaults, los saca de esta
-- tabla, asi que un rasgo que exista en una fila de tipo y no exista aca se lee
-- como nil en los otros veintinueve. La guarda del final lo comprueba.
--
-- 1.0 y 1 son el neutro EN TODOS los ejes multiplicativos a proposito: un tipo
-- sin fila y un tipo con la fila neutra tienen que ser indistinguibles en
-- comportamiento -- si no, "sin fila" seria un tercer estado sin nombre.
PHANTASMAGORIA.EventDefaults = {
    -- Multiplicador de la FRECUENCIA. 2.0 = el doble de eventos por minuto.
    rate     = 1.0,

    -- Cuantas CATEGORIAS sortea el despachador en un disparo. Es la
    -- simultaneidad entre cosas distintas: The Twins hace "2 interactions at the
    -- same time" (:576).
    count    = 1,

    -- Cuantos OBJETOS mueve un solo evento de tirar. Es la simultaneidad adentro
    -- de una misma categoria: el Poltergeist tira "MULTIPLE objects at the same
    -- time" (:429).
    --
    -- ⚠⚠ SON DOS EJES Y ANTES ERAN UNO, Y ESO FUE UN DEFECTO MEDIBLE. La primera
    -- version usaba `count` para las dos cosas, y el motor lo pasaba a los dos
    -- lugares: mandaba el bucle del despachador Y entraba como tope de props del
    -- evento de tirar. O sea que se MULTIPLICABA CONSIGO MISMO.
    --
    -- La cuenta del peor caso, con el Poltergeist cazando: count 4 x hunt.count
    -- 2 = 8 sorteos, peso de throw 8 sobre 16 = la mitad, por hasta 8 props cada
    -- uno => del orden de 32 props y 32 EmitSound EN UN FRAME, con techo de 64.
    -- Y el reporte lo mostraba como "1 disparo".
    --
    -- El comentario viejo decia "el motor lo usa en DOS ejes y significa lo mismo
    -- en los dos". Significaba lo mismo, si -- lo que no estaba escrito, ni era
    -- cierto, es que los dos ejes fueran INDEPENDIENTES. *Un flag que se lee en
    -- dos lugares se compone en dos lugares, salvo que alguien lo impida.*
    burst    = 1,

    -- Multiplicador de la INTENSIDAD ( la fuerza del impulso al tirar un prop ).
    --
    -- ⚠ HONESTIDAD SOBRE ESTE EJE: el autor lo pidio explicitamente ( "otros
    -- los hagan con mayor intensidad" ) y la fuente lo mueve en UN SOLO TIPO
    -- ( Poltergeist :433 "can throw objects faster and further" ). O sea que hoy
    -- veintinueve filas llevan el neutro. Sobrevive como EJE porque el pedido es
    -- del autor y porque cuesta un campo; NO sobrevive como "rasgo descubierto
    -- en los datos", y esa distincion importa el dia que alguien lo cite como
    -- evidencia de algo.
    strength = 1.0,

    -- Multiplicador del RADIO, indexado por la iteracion del bucle ( regla 3 ).
    -- El motor usa radius[ i ] or radius[ 1 ], asi que un array de largo 1
    -- sirve para cualquier count.
    radius   = { 1.0 },

    -- Pesos del sorteo de categoria. 0 = el tipo nunca hace esa categoria.
    -- Las ocho categorias son las que el motor implementa; la lista canonica
    -- vive en server_events.lua y la guarda del final compara las dos.
    weights  = {
        throw     = 1,
        knock     = 1,
        creak     = 1,
        door      = 1,
        light     = 1,
        sound     = 1,
        prop      = 1,
        furniture = 1,
    },

    -- Sub-pesos del evento de sonido: de que banco sale el clip.
    soundBanks = {
        voice   = 1,   -- ghost/paranormal_voice
        breath  = 1,   -- ghost/breathing
        humming = 1,   -- ghost/humming   ( el "singing ghost event" del juego )
    },

    -- EL SIGNO, que es el hallazgo mas fuerte del corte y el que ningun peso
    -- escalar puede expresar: +1 = este tipo SOLO enciende · -1 = SOLO apaga ·
    -- 0 = las dos. Mare y Jinn colapsan en el mismo tipo si esto no existe.
    --
    -- ⚠ De los cuatro tipos que lo sostienen en la fuente, HOY SOLO UNO TIENE
    -- DESTINO ( Mare, sobre luces ). Los otros tres piden el breaker y las
    -- llamas, que no existen -- ver el aviso de arriba. Se escribe igual porque
    -- el eje `light` si tiene destino y porque es un campo de tabla.
    dir      = {
        light = 0,
    },

    -- LA VOZ. 0 = sorteada al azar entre las dos · 1 = femenina · 2 = grave.
    --
    -- El catalogo tiene DOS voces y el indice del archivo ES la voz
    -- ( sound/phantasmagoria/about.txt ): la 1 femenina, la 2 grave. El motor la
    -- sortea UNA vez por fantasma y la guarda, para que el mismo fantasma no
    -- susurre con una voz y respire con la otra -- lo que seria peor que no
    -- tener dos voces, porque delata que el sonido es una tabla.
    --
    -- Lo fijan los dos tipos que la fuente marca como "Can only be female,
    -- ghost model and ghost name will reflect this" ( banshee :57, dayan :82 ).
    voice    = 0,

    -- Los mismos ejes, pero DURANTE EL HUNT. Multiplican a los de arriba.
    --
    -- Este es el rasgo MEJOR SOSTENIDO de la tabla entera -- nueve tipos --, y
    -- es exactamente lo que el autor pidio: "nos puede servir para eventos como
    -- HUNTS". Poltergeist :434 tira "every 0.5s with an increased force",
    -- Raiju :452 sube su alcance de 10 a 15 m "during events and hunts", Myling
    -- :310 acorta el alcance de sus ruidos de 20 a 12 m, Obake :328 cambia de
    -- modelo, Hantu :199, Shade :500, Deogen :141, Phantom :414, Oni :372.
    hunt     = {
        rate     = 1.0,
        count    = 1,
        burst    = 1,
        strength = 1.0,
        radius   = 1.0,
    },
}

---------------------------------------------------------------------------
-- LAS 25 FILAS -- solo los DELTAS
---------------------------------------------------------------------------
-- Cada fila lleva SOLO lo que la difiere del neutro. Escribir la fila completa
-- en las 25 haria imposible leer de un vistazo que mueve cada tipo, que es la
-- pregunta que esta tabla existe para contestar.
--
-- El numero entre parentesis es la linea de ghost_types.lua de donde sale.
local F = {}

F[ "banshee" ] = {
    -- "Prefers singing ghost events" (:55) -- el banco de tarareo es
    -- ghost/humming/, que el catalogo ya tiene y que salio de la caja musical.
    weights    = { sound = 3 },
    soundBanks = { humming = 6, voice = 1, breath = 1 },
    -- (:57) "Can only be female".
    voice      = 1,
}

F[ "dayan" ] = {
    -- ⚠ FILA DE UN SOLO CAMPO, y esta bien que lo sea. La fuente no le da
    -- ningun rasgo de evento ( :82-83 son el modelo y la caza ), pero SI dice
    -- "Can only be female, ghost model and ghost name will reflect this"
    -- (:82) -- y la voz tiene destino, asi que el dato no se tira.
    --
    -- Es el segundo sostenedor de `voice` y por eso el rasgo no es un `if`
    -- disfrazado.
    voice   = 1,
}

F[ "deildegast" ] = {
    -- INVERSO y por eso solo baja el peso: (:99-102) pierde velocidad por cada
    -- objeto unico que tocan LOS JUGADORES. No tira nada -- es un contador, no
    -- un evento -- pero un fantasma cuyo tema son los objetos que TOCAN otros
    -- no tiene por que estar tirandolos el mismo.
    weights = { throw = 0.5 },
}

F[ "deogen" ] = {
    -- "33% chance to give heavy breathing through the spirit box when a player
    -- is within 1m" (:139). El banco es ghost/breathing/, que trae ademas un
    -- clip llamado literalmente deogen.ogg.
    weights    = { sound = 2 },
    soundBanks = { breath = 6, voice = 1, humming = 1 },
}

F[ "goryo" ] = {
    -- "will not show if a player is in the same room" (:182-183). La parte de
    -- DOTS es apariciones y quedo fuera de alcance; lo que si tiene destino es
    -- que es un tipo esquivo, asi que hace menos ruido cerca.
    rate    = 0.8,
}

F[ "hantu" ] = {
    -- (:201) "More likely to turn off the breaker". El breaker no existe ( ver
    -- el aviso de arriba ), asi que lo que se escribe es lo unico que SI tiene
    -- destino: que es un tipo que APAGA. El signo, no el peso.
    weights = { light = 2 },
    dir     = { light = -1 },
    -- (:199) el aliento congelado solo se ve cazando con el breaker apagado.
    hunt    = { rate = 1.3 },
}

F[ "jinn" ] = {
    -- (:222) "cannot directly turn off the breaker" -- o sea el OPUESTO exacto
    -- de Hantu, y la razon entera por la que `dir` existe. Con un peso escalar
    -- Jinn y Hantu serian el mismo tipo.
    dir     = { light = 1 },
    weights = { light = 2 },
}

F[ "kormos" ] = {
    -- (:245) solo te ve si te moves a menos de 5 m. Un fantasma que depende del
    -- movimiento ajeno hace menos ruido propio.
    rate    = 0.8,
}

F[ "mare" ] = {
    -- EL TIPO DE LAS LUCES, y el unico sostenedor de `dir` con destino real.
    --   (:263-264) apaga el switch o la lampara que un jugador prendio a <4 m
    --   (:265-266) unico que toca un switch DURANTE un evento
    --   (:268)     "Prefers turning off lights and light bursting events"
    --   (:269)     "Cannot turn on lights ( including TVs and computers )"
    weights = { light = 6, throw = 0.5 },
    dir     = { light = -1 },
    -- (:264) los 4 m del juego son ~210 u con la conversion de Diseno 1
    -- ( 1 m = 52,5 u ), o sea bastante menos que nuestro radio base.
    radius  = { 0.5 },
}

F[ "moroi" ] = {
    -- (:290-295) maldice al que lo ESCUCHA: spirit box, sonido paranormal por
    -- parabolica, o sonido grabable. Su mecanica entera pasa por hacer ruido.
    weights = { sound = 3 },
}

F[ "myling" ] = {
    -- (:311-312) "Makes sounds through the parabolic microphone / sound recorder
    -- MORE FREQUENTLY than other ghosts" -- el sostenedor mas literal del eje.
    weights = { sound = 4 },
    -- (:310) pasos y voces a 12 m cazando contra 20 m normal: CAZANDO SE ACERCA
    -- el alcance, no se aleja. El multiplicador es menor que uno a proposito.
    hunt    = { radius = 0.6 },
    -- Y la crueldad, que sale de cruzar este rasgo con phantom_SilentSteps
    -- ( server_steps.lua ): el Myling camina EN SILENCIO cazando y es el que mas
    -- sonido paranormal tira fuera del hunt. Hace ruido cuando no viene y
    -- ninguno cuando si.
}

F[ "obake" ] = {
    -- (:331) "25% chance to miss a footstep during events" -- no es un evento
    -- nuevo sino un rasgo de pisadas, y vive en server_steps.lua. Lo que si
    -- entra aca es (:328-329): cambia de modelo un parpadeo DURANTE LA CAZA.
    hunt    = { rate = 1.2 },
}

F[ "oni" ] = {
    -- (:368) "More active around multiple people" -- la fuente lo condiciona a
    -- la cantidad de jugadores y nosotros lo escribimos como tasa constante.
    -- ⚠ ES UNA APROXIMACION Y SE DECLARA: la condicion ( contar jugadores ) es
    -- barata, pero meterla aca convertiria un dato en una funcion. Cuando el
    -- motor tenga moduladores, esta linea se reemplaza.
    rate    = 1.6,
    -- (:372) parpadea mas en la caza.
    hunt    = { rate = 1.4 },
}

F[ "onryo" ] = {
    -- (:388-394) el tipo de las llamas. Sin velas encendibles, lo que queda con
    -- destino es que APAGA cosas -- (:394) "Cannot light fire sources".
    weights = { light = 3 },
    dir     = { light = -1 },
    -- (:389) apaga una llama a menos de 4 m: mismo radio corto que Mare.
    radius  = { 0.5 },
}

F[ "phantom" ] = {
    -- (:414) "Less visible during hunts". La visibilidad esta fuera de alcance;
    -- lo que tiene destino es que es un tipo retraido y hace menos ruido.
    rate    = 0.8,
    hunt    = { rate = 0.7 },
}

F[ "poltergeist" ] = {
    -- EL TIPO DE LOS OBJETOS. Es la fila que mas se aleja del neutro y la unica
    -- que mueve los cuatro ejes a la vez:
    --   (:429-430) "will throw MULTIPLE objects at the same time"
    --   (:432)     "Has a higher chance to throw & interact with objects"
    --   (:433)     "Can throw objects faster and further"
    --   (:434)     "During hunts... every 0.5s with an increased force"
    weights  = { throw = 8, furniture = 2 },
    -- DOS interacciones simultaneas ( no cuatro: `count` es el bucle del
    -- despachador, y cuatro sorteos con peso 8/16 saturaban el frame ) ...
    count    = 2,
    -- ... y CUATRO objetos por tirada, que es lo que la fuente describe de
    -- verdad: "will throw MULTIPLE objects at the same time" (:429).
    burst    = 4,
    strength = 1.8,
    radius   = { 1.4 },
    -- (:434) el "cada 0,5 s" del juego es una tasa absurda para GMod -- serian
    -- 120 eventos por minuto -- asi que se traduce como un multiplicador fuerte
    -- y no literal. Que sea una TRADUCCION y no el numero de la fuente esta
    -- escrito aca para que nadie lo "corrija" a 0.5 mas adelante.
    hunt     = { rate = 3.0, strength = 1.6, burst = 2 },
    -- (:431) "Only ghost that can throw an item while the ghost is in a lit
    -- room" -- sin destino hoy ( no medimos luz ambiente en el servidor, y esa
    -- decision ya esta tomada en Diseno 19.4 ). Anotado, no escrito.
}

F[ "raiju" ] = {
    -- (:452) "During events and hunts, causes electronic disturbance at 15m
    -- instead of 10m" -- el unico tipo cuyo radio la fuente da EN NUMEROS para
    -- los dos estados, asi que el 1.5 de abajo es 15/10 y no una impresion.
    radius  = { 1.0 },
    hunt    = { radius = 1.5, rate = 1.3 },
    -- (:456) latido mas fuerte cerca.
    weights = { sound = 2 },
}

F[ "revenant" ] = {
    -- (:472-474) lento hasta detectarte y despues 3 m/s. Nada de eventos en la
    -- fuente; lo que entra es que su tema es la persecucion, no la casa.
    rate    = 0.8,
}

F[ "shade" ] = {
    -- EL TIPO TIMIDO, y el unico con un peso en CERO por lectura directa:
    --   (:490-491) no hace eventos en la misma sala que un jugador
    --   (:492-497) no hace interacciones que dejen EMF 2/3/5 en la misma sala
    --   (:498-499) "Chance for doing ghost events DECREASES the higher average
    --              sanity is above 50% ( cannot do ghost events at 100% )"
    rate    = 0.4,
    weights = { throw = 0.25, door = 0.5 },
    -- (:500-501) tampoco apaga fuegos cazando en la misma sala.
    hunt    = { rate = 0.6 },
    -- ⚠ La condicion "en la misma sala que un jugador" NO esta implementada: es
    -- la primitiva de cuarto ( Diseno 14 ), que no existe. La tasa baja es una
    -- APROXIMACION de un rasgo condicional, igual que la de Oni, y se declara
    -- por el mismo motivo.
}

F[ "thaye" ] = {
    -- (:538) "More active when younger" -- condicional a su edad, que envejece
    -- cada 1-2 min (:536-537). Sin el ciclo de edad, la tasa alta es la mitad
    -- del rasgo. Aproximacion declarada.
    rate    = 1.3,
}

F[ "the_mimic" ] = {
    -- ⚠ ESTA FILA ES UN MARCADOR, NO UN RASGO. El Mimic imita a otro tipo cada
    -- 30-120 s (:556-557) y eso NO se resuelve con numeros: se resuelve con la
    -- indireccion del getter ( regla 2 de arriba ). La fila existe para que el
    -- que venga a escribir el Mimic encuentre el lugar y lea la regla, y para
    -- que la guarda del final no la cuente como "tipo sin rasgos por olvido".
    --
    -- Los numeros de abajo son los NEUTROS explicitos: mientras no exista la
    -- imitacion, el Mimic se comporta como un Spirit, que es lo correcto -- no
    -- como un promedio de los veintinueve, que no seria ninguno.
    rate    = 1.0,
    -- (:558) siempre da Ghost Orbs de mas. Es evidencia, no evento.
}

F[ "the_twins" ] = {
    -- LA PRUEBA DE FUEGO DEL ARRAY. (:576-577) "Can do 2 interactions at the
    -- same time, one within its standard radius ( 2.12m, 4.24m ) and the other
    -- within its EXTENDED radius ( 8.48m, 16.97m )".
    --
    -- 8.48 / 2.12 = 4.0 exacto, y 16.97 / 4.24 = 4.002. Los dos pares dan el
    -- mismo factor, asi que el 4.0 de abajo es la razon de la fuente y no una
    -- eleccion. Por eso `radius` es un array: el motor tira la interaccion 1 al
    -- radio normal y la 2 al extendido, con UN bucle.
    count   = 2,
    radius  = { 1.0, 4.0 },
    -- `burst` queda en el neutro A PROPOSITO y ahi esta la diferencia con el
    -- Poltergeist: los Twins hacen DOS interacciones distintas en dos radios;
    -- el Poltergeist hace UNA con cuatro objetos. Con un solo eje los dos
    -- colapsaban en "hace mas cosas".
}

F[ "wraith" ] = {
    -- (:592-593) se teletransporta a un jugador al azar. Es movimiento, no
    -- evento, y lo va a hacer otro bloque. Lo que entra: (:595-596) no toca la
    -- sal, o sea que es un tipo que interactua poco con el piso.
    weights = { creak = 0.5 },
}

F[ "yokai" ] = {
    -- (:613) "More active when talking near it" -- condicional a la voz, que es
    -- percepcion y quedo fuera de alcance. Aproximacion declarada, como Oni.
    rate    = 1.3,
    -- (:615-617) su evento de caja musical pasa de 5 a 2,5 m: es el unico tipo
    -- cuyo radio la fuente ACORTA. Y (:614) cazando oye a 2,5 m.
    radius  = { 0.5 },
    weights = { sound = 2 },
}

F[ "yurei" ] = {
    -- EL TIPO DE LAS PUERTAS, y el unico sostenedor del eje:
    --   (:631) "Can shut a door and drop sanity of nearby players by 15%"
    --   (:635) "ONLY ghost that can close or interact with an exit door outside
    --          of a hunt/event"
    --   (:636) "Must fully open / shut a door"
    --
    -- ⚠ Es un singleton y NO es un `if` disfrazado, y la diferencia importa:
    -- `door` es una categoria que el motor tiene igual -- las otras veintinueve
    -- filas la llevan en 1 --, asi que lo unico que Yurei aporta es un numero.
    -- El motor no lo nombra en ninguna parte. Un `if` seria que el motor
    -- preguntara "sos Yurei".
    weights = { door = 6 },
}

PHANTASMAGORIA.GhostFlags = F

---------------------------------------------------------------------------
-- LA FUSION
---------------------------------------------------------------------------
-- Escribe `events` sobre cada fila de PHANTASMAGORIA.Types. Va sobre la fila y
-- no en una tabla paralela por la regla 1: el dia que el Mimic imite, tiene que
-- poder devolver el `events` del imitado de una sola pieza.
--
-- Copia PROFUNDA del neutro por fila, y no una referencia compartida: dos tipos
-- apuntando a la misma sub-tabla `weights` significaria que tocar el peso de uno
-- toca el del otro. Es el modo de falla mas silencioso que tiene una tabla de
-- configuracion -- funciona hasta que alguien escribe en runtime.
local function copiar( t )
    local out = {}

    for k, v in pairs( t ) do
        out[ k ] = istable( v ) and copiar( v ) or v

    end

    return out

end

-- Fusion de UN NIVEL sobre las sub-tablas conocidas. NO es un merge recursivo
-- generico a proposito: `radius` es un ARRAY y un merge recursivo sobre arrays
-- da resultados que nadie espera -- fusionar { 1.0, 4.0 } sobre { 1.0 } deja
-- { 1.0, 4.0 }, que aca es lo correcto por casualidad, pero fusionar { 1.0 }
-- sobre { 1.0, 4.0 } dejaria el 4.0 del vecino. Los arrays se REEMPLAZAN.
local SUBTABLAS = { "weights", "soundBanks", "dir", "hunt" }

-- ⚠ ESTA LISTA TIENE QUE CONTENER TODO ESCALAR DE EventDefaults. Un escalar
-- nuevo en el neutro que no se agregue aca se puede escribir en una fila de tipo
-- y NO SE FUSIONA: la fila queda con el neutro, el rasgo no hace nada, y no hay
-- error. La guarda del final del archivo compara las dos listas.
local ESCALARES = { "rate", "count", "burst", "strength", "voice" }

local function fusionar( base, delta )
    for _, key in ipairs( SUBTABLAS ) do
        if istable( delta[ key ] ) then
            for k, v in pairs( delta[ key ] ) do
                -- ⚠ COPIA PROFUNDA TAMBIEN ACA, y la primera version no la
                -- hacia: asignaba `v` verbatim. Hoy es inocuo porque los 25
                -- deltas solo tienen escalares adentro de weights/soundBanks/
                -- dir/hunt -- se verificaron las 25 filas --, pero el dia que
                -- alguien anide una tabla ( `hunt = { radius = { 1.5 } }` es el
                -- caso obvio, porque `radius` ES un array en la raiz ) el objeto
                -- quedaria COMPARTIDO entre PHANTASMAGORIA.GhostFlags y la fila
                -- fusionada de Types, y una escritura en runtime sobre uno
                -- tocaria al otro.
                --
                -- Es exactamente el modo de falla que el comentario de `copiar`
                -- dice estar evitando: la copia profunda cubria el nivel de
                -- arriba y no este.
                base[ key ][ k ] = istable( v ) and copiar( v ) or v

            end
        end
    end

    -- `radius` se reemplaza entero ( ver arriba ).
    if istable( delta.radius ) then base.radius = copiar( delta.radius ) end

    for _, key in ipairs( ESCALARES ) do
        if delta[ key ] ~= nil then base[ key ] = delta[ key ] end

    end

    return base

end

function PHANTASMAGORIA.AplicarRasgosDeEvento()
    local T = PHANTASMAGORIA.Types

    if not istable( T ) then
        ErrorNoHalt( "[Phantasmagoria] ghost_flags.lua corrio ANTES que ghost_types.lua: " ..
            "PHANTASMAGORIA.Types no existe y los 30 tipos se quedan sin rasgos de evento. " ..
            "Mirar el orden de DATOS en lua/autorun/phantasmagoria_data.lua.\n" )
        return 0, 0

    end

    local conRasgos, total = 0, 0

    for key, fila in pairs( T ) do
        total = total + 1
        fila.events = fusionar( copiar( PHANTASMAGORIA.EventDefaults ), F[ key ] or {} )

        if F[ key ] then conRasgos = conRasgos + 1 end

    end

    -- ⚠ UN DELTA QUE APUNTA A UN TIPO QUE NO EXISTE ES UN RASGO QUE NO CORRE, y
    -- se lee EXACTAMENTE IGUAL que un tipo neutro. Es el modo de falla de un
    -- rename o de un error de tipeo en la key, y no tira error solo.
    for key in pairs( F ) do
        if not T[ key ] then
            ErrorNoHalt( "[Phantasmagoria] ghost_flags.lua declara rasgos para '" .. tostring( key ) ..
                "' y ese tipo NO EXISTE en PHANTASMAGORIA.Types. El rasgo no se aplica a nadie " ..
                "y el sintoma seria un tipo comportandose como neutro, sin error.\n" )

        end
    end

    return conRasgos, total

end

---------------------------------------------------------------------------
-- LA GUARDA: que la fila neutra cubra todo lo que las filas de tipo mueven
---------------------------------------------------------------------------
-- El modo de falla que ataja: alguien agrega `weights.window = 3` a una fila de
-- tipo y se olvida de agregar `window = 1` al neutro. El resultado NO es un
-- error -- es que veintinueve tipos tienen ese peso en nil, el sorteo los saltea
-- y la categoria pasa a ser exclusiva de un tipo POR ACCIDENTE. Se ve igual que
-- una decision de diseno.
--
-- Se comprueba al cargar y no al usar, porque al usar el sintoma ya ocurrio.
local function auditarNeutro()
    local D, faltan = PHANTASMAGORIA.EventDefaults, {}

    -- ( a ) TODO ESCALAR DEL NEUTRO TIENE QUE ESTAR EN `ESCALARES`, o `fusionar`
    -- lo ignora en silencio y el rasgo del tipo no llega nunca a la fila. Es el
    -- modo de falla mas barato de cometer -- se agrega un campo al neutro y se
    -- olvida la lista -- y el mas caro de encontrar, porque el campo EXISTE y
    -- tiene el valor neutro: se lee como "el rasgo no hace nada".
    local enLista = {}
    for _, key in ipairs( ESCALARES ) do enLista[ key ] = true end

    for key, val in pairs( D ) do
        if not istable( val ) and not enLista[ key ] then
            faltan[ #faltan + 1 ] = "EventDefaults." .. key .. " ( escalar fuera de ESCALARES: no se fusiona )"

        end
    end

    for _, key in ipairs( SUBTABLAS ) do
        if not istable( D[ key ] ) then
            faltan[ #faltan + 1 ] = "EventDefaults." .. key .. " ( en SUBTABLAS y no es tabla en el neutro )"

        end
    end

    -- ( b ) Todo rasgo que una fila de tipo mueve tiene que existir en el neutro
    -- Y TENER SU MISMO TIPO DE DATO.
    --
    -- ⚠ LA COMPROBACION DE TIPO NO ESTABA, y el hueco caia justo sobre el unico
    -- campo que la version anterior EXIMIA por nombre. `F[ "mare" ] = { radius =
    -- 0.5 }` -- un escalar donde va un array, que es el error de tipeo natural
    -- porque los otros cuatro ejes SI son escalares -- pasaba las dos ramas:
    -- `D.radius ~= nil` es cierto, y el `elseif istable( val )` daba false. Y
    -- despues `fusionar` lo descartaba en silencio ( `if istable( delta.radius )` ),
    -- asi que Mare se quedaba con { 1.0 } y el rasgo no existia. Cero ruido.
    --
    -- El simetrico es peor: una tabla donde va un escalar
    -- ( `hunt = { radius = { 1.5 } }` ) SI se fusiona, y revienta despues, en el
    -- motor, a 1 Hz -- `cvRadius:GetFloat() * mulRad` con `mulRad` tabla.
    local function nombreTipo( v )
        if istable( v ) then return "tabla" end
        return type( v )

    end

    for tipo, delta in pairs( F ) do
        for key, val in pairs( delta ) do
            if D[ key ] == nil then
                faltan[ #faltan + 1 ] = tipo .. "." .. key .. " ( no existe en EventDefaults )"

            elseif nombreTipo( val ) ~= nombreTipo( D[ key ] ) then
                faltan[ #faltan + 1 ] = tipo .. "." .. key .. " es " .. nombreTipo( val ) ..
                    " y el neutro es " .. nombreTipo( D[ key ] )

            elseif istable( val ) and key ~= "radius" then
                for sub, subval in pairs( val ) do
                    if D[ key ][ sub ] == nil then
                        faltan[ #faltan + 1 ] = tipo .. "." .. key .. "." .. sub ..
                            " ( no existe en EventDefaults )"

                    elseif nombreTipo( subval ) ~= nombreTipo( D[ key ][ sub ] ) then
                        faltan[ #faltan + 1 ] = tipo .. "." .. key .. "." .. sub .. " es " ..
                            nombreTipo( subval ) .. " y el neutro es " .. nombreTipo( D[ key ][ sub ] )

                    end
                end
            end
        end
    end

    if #faltan > 0 then
        ErrorNoHalt( "[Phantasmagoria] ghost_flags.lua: " .. #faltan .. " rasgo(s) existen en una fila " ..
            "de tipo y NO en EventDefaults, asi que los demas tipos los tienen en nil y el motor los " ..
            "saltea sin avisar: " .. table.concat( faltan, ", " ) .. "\n" )

    end

    return #faltan

end

---------------------------------------------------------------------------
-- EL ORDEN: LA GUARDA CORRE **ANTES** DE LA FUSION
---------------------------------------------------------------------------
-- ⚠ ESTABA AL REVES Y ES UN DEFECTO DE GUARDA CLASICO: `AplicarRasgosDeEvento`
-- se llamaba arriba, y `auditarNeutro` quedaba aca abajo -- o sea que la guarda
-- que existe para detectar una fila mal formada corria DESPUES de que esa fila
-- hubiera pasado por el fusionador.
--
-- Y el fusionador no la sobrevive: `base[ key ][ k ] = v` con `base[ key ]` nil
-- ( una sub-tabla declarada en SUBTABLAS y ausente del neutro ) tira error de
-- Lua y **aborta el archivo entero**, con lo cual `auditarNeutro` -- la unica
-- linea que habria dicho cual era el campo -- no llega a correr nunca.
--
-- *Una guarda que corre despues del paso que puede matarla no es una guarda: es
-- una autopsia que no se hace.*
local malFormados = auditarNeutro()

if malFormados > 0 then
    ErrorNoHalt( "[Phantasmagoria] ghost_flags.lua NO FUSIONA por " .. malFormados ..
        " rasgo(s) mal formado(s) ( arriba ). Los 30 tipos quedan con el neutro y ninguno se " ..
        "diferencia -- que es un defecto visible en juego, a diferencia de una fusion a medias.
" )

else
    PHANTASMAGORIA.AplicarRasgosDeEvento()

end
