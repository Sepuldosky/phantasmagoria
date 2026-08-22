# PENDIENTES — Phantasmagoria

Cosas que **el autor pidió o que aparecieron a mitad de una ronda** y que no pertenecen a la tajada
que se estaba corriendo. Viven acá para que no se pierdan entre el chat y la próxima planilla.

> Regla de la casa: una idea dicha en medio de una corrida **no entra en esa corrida**. Se anota con
> las palabras del autor, con lo que hay que decidir, y con lo que haría falta para medirla. *Meterla
> en la ronda en curso ensucia el sujeto que se estaba midiendo; olvidarla es peor.*

---

## 1. ⭐ El Yurei tiene que abrir la puerta **rápido y fuerte**, no como cualquiera

**Pedido por el autor el 2026-08-21**, al cerrar la fila 06 de la cordura B2 (donde el `per.door = 15`
quedó medido en juego por primera vez):

> *«La verdad que sí funciona, aunque está cerrando las puertas como lo hace cualquier ghost. Digo
> que el evento del Yurei este tiene que buscar la puerta más cercana al jugador y abrirla
> rápidamente, puede ser 2 veces más rápida y un 1/2 más ruidosa; ya que el abrir puertas aquí en
> GMod no lo hicimos como parcial, y así no funcionan las puertas en el motor Source, será tendrá que
> ser la diferencia del Yurei.»*

### Por qué es una buena traducción, y no un capricho

La fuente le da al Yurei tres líneas, y **una de las tres no se puede cumplir en Source**:

- `(:631)` *"Can shut a door and drop sanity of nearby players by 15%"* → **escrito y medido** (`per.door = 15`).
- `(:635)` *"ONLY ghost that can close or interact with an exit door outside of a hunt/event"* → sin destino.
- `(:636)` **"Must fully open / shut a door"** → **imposible como diferencia observable**: en GMod las
  puertas no abren parcialmente, así que *todos* los fantasmas ya la abren "del todo". La línea que
  debía distinguir al Yurei **no distingue nada**.

*Un rasgo cuya única expresión es imposible en el motor no es un rasgo: hay que darle otro cuerpo o
declararlo muerto.* Lo que el autor propone es darle otro cuerpo, sobre tres ejes que en Source **sí**
son observables:

| eje | hoy | propuesta |
|---|---|---|
| **elección de la puerta** | la más cercana **al fantasma** (o sorteo entre las del radio) | la más cercana **al jugador** |
| **velocidad** | la del `func_door` / `prop_door_rotating` | **×2** |
| **volumen** | el del evento `door` | **×1,5** |

### Lo que hay que decidir antes de escribirlo

1. ⚠ **La elección por jugador rompe la simetría del motor de eventos**, que hoy elige *alrededor del
   fantasma* a propósito (`evradius` decide DÓNDE pasa; `sanrad` decide A QUIÉN le llega — están
   separados justamente para que no se muevan juntos). Un rasgo que elija por jugador es el **primer**
   evento que mira al jugador para decidir su sujeto. Se puede, pero es una excepción declarada y hay
   que escribir por qué.
2. **¿La velocidad se puede tocar en un `func_door`?** `speed` es un keyvalue del mapa. Hay que medir
   si `SetKeyValue`/`Fire` lo acepta en caliente, y qué pasa con `prop_door_rotating`, que es otra
   entidad con otro campo. **Esto puede no ser posible**, y entonces el eje se cae.
3. **El ×1,5 de volumen**: ¿es el volumen del `EmitSound` del evento, o el sonido propio de la puerta
   (que lo emite la entidad del mapa)? Son dos cosas distintas y sólo una la controla el addon.
4. **¿Cuál de los tres ejes lleva el peso?** Si la velocidad no se puede tocar, la diferencia queda en
   "elige la puerta de al lado tuyo y suena más fuerte", que igual es una diferencia legible.

### Alcance

Es **Diseño 21 (eventos paranormales)**, no la cordura. Va con planilla propia. No se toca en B2 ni en
C. La fila que lo mida tiene que separar los tres ejes: *un cambio de tres ejes a la vez que sale
"raro" no dice cuál de los tres.*

---

## 2. Sin reproducir: un spawn que pareció ignorar el override de tipo

En la r2 de la cordura B2, la nota de la fila **09** muestra dos spawns seguidos con
`PHANTASMAGORIA.TypeOverride` en `'phantom'`:

```
spawn #175  serie 3  ...  tipo phantom
spawn #175  serie 4  ...  tipo spirit
```

Lo único que borra el override es `phantasmagoria_ghost_type auto|random`, y **imprime
`override BORRADO`** ([server_type.lua:639](../lua/entities/terminator_nextbot_phantom/server_type.lua#L639)).
Esa línea no está en el pegado.

**El autor no lo observó**, y hay una explicación benigna que lo cubre entero: la consola se limpió
con `clear` durante la sesión, así que el orden de las líneas pegadas **no es necesariamente la
cronología real** y el `override BORRADO` pudo perderse con el resto.

Queda anotado y **no se persigue**. Si vuelve a aparecer con la consola limpia y sin `clear` en el
medio, entonces sí es un defecto: el override se lee de un global (`PHANTASMAGORIA.TypeOverride`) y
tiene un solo lector, así que sería fácil de acorralar. *Una anomalía que no se reproduce no es un
defecto, pero tampoco es nada: es una anotación con fecha.*

---

## 3. ⭐⭐ Un MENÚ propio en el spawnmenu — y la dificultad que le falta a la cacería

**Pedido por el autor el 2026-08-22**, mirando el panel de VJ Base: un desplegable de dificultad
(*Neanderthal −99 %* … *Extinction +900 %*) más categorías con las perillas del addon.

> *«¿Por qué no tenemos un menú propio de Phantasmagoria? Donde podamos aplicar dificultad in-game
> así como VJ tiene opciones de lo mismo, incluso nos sirve para más cosas como perillas de nuestros
> cvars.»*

### El censo, que es lo que decide si vale la pena

| | |
|---|---|
| convars del addon | **85** |
| `FCVAR_ARCHIVE` | **84 de 85** |
| integración con el spawnmenu | **cero** — ni un `PopulateToolMenu` en todo el árbol |
| familias | `ghost_*` **57** · `sanity_*` **25** · sueltas 3 |
| con registro compartido | **30** (`PHANTASMAGORIA.PerillasCordura`, sólo la cordura) |

Ochenta y cinco perillas archivadas y **ninguna forma de verlas que no sea la consola**. Que
`phantasmagoria_cordura_fabrica --decir` haya tenido que existir —y que la r3 de B1 se haya
invalidado entera por un `regendelay` en 30— **es el síntoma de esto**, no un accidente.

### ⭐ Y no es adorno: es el eje que le falta a la tajada C

La tabla de duraciones de la wiki está indexada por **dificultad × tamaño de mapa**, y GMod no tiene
ninguno de los dos. En el prompt de C eso obligó a *colapsar* la tabla a un solo número elegido a
dedo. **Con un selector de dificultad, el eje existe y la tabla se porta entera.** Es el mismo
problema del Yurei (§1): un dato de la fuente que no se puede expresar porque falta el eje — sólo que
éste **sí** se puede construir.

*La dificultad es un PRESET que escribe las perillas; las perillas siguen siendo la verdad.* Por eso
no hay retrabajo: C escribe las perillas, el menú después escribe presets adentro de ellas.

### ⚠⚠⚠ La trampa tiene nombre y este taller ya la pagó

**El spawnmenu se arma en `OnGamemodeLoaded`, ANTES de que los módulos booteen en `Initialize`, y
`ToolMenu:Init()` lee `GetTools()` UNA SOLA VEZ.** Registrar tarde **no se dibuja nunca**, y el modo
de falla es el peor de todos: la categoría sale **vacía pero presente** — parece instalada y no hace
nada. Ver la memoria `spawnmenu-se-arma-antes-del-boot`. Cualquier diseño de este menú arranca por
ahí o repite el defecto.

### ⚠ Las 84 son de SERVIDOR, así que el panel no puede escribirlas directo

Son `game lua_server`. Un panel de cliente **no** las puede tocar con `ConCommand`: hace falta un
`net` con **chequeo de admin en el servidor** — que es exactamente por qué el panel de VJ abre con
*«Only admins can use this menu!»*. Y el servidor **no confía en el valor del cliente**: lo valida y
lo recorta contra el `min`/`max` que la propia convar ya declara.

### ⚠⚠ Y el preset choca de frente con `phantasmagoria_cordura_fabrica`

Ese comando existe para contestar *«las 30 perillas están EN FABRICA»*, y **es la primera línea del
P0 de todas las planillas de la cordura**. Un preset de dificultad que mueva treinta perillas de un
saque va a hacer que `--decir` liste treinta movidas, y **el P0 de cada planilla se pone rojo por
funcionar bien**. Hay que resolverlo antes de escribir el preset, no después:

- o el `fabrica` aprende el concepto de **estado con nombre** (*«en el preset Difícil, 30 de 30
  coinciden»*), y el P0 pasa a exigir *un estado conocido* en vez de *fábrica*;
- o los presets se declaran **incompatibles con correr planillas**, y el menú lo dice en pantalla.

La primera es más trabajo y es la correcta. *Un instrumento que existe para detectar perillas movidas
no puede quedarse mudo el día que mover perillas se vuelve una función del producto.*

### Cómo se construye, para que no envejezca

**No pegando 85 filas a mano.** Ése es el defecto de B1 r3 otra vez: una lista pegada a mano cubre lo
que estaba el día que se escribió. El menú tiene que ser un **lector de un registro**, igual que
`PerillasCordura` — cada `CreateConVar` se registra con su metadata (categoría, etiqueta, tipo,
mín/máx, y si es de tres estados) y el panel **dibuja lo que el registro enumere**. Así una perilla
nueva aparece en el menú sin que nadie toque el menú, y una que se borra desaparece sola.

### Orden recomendado

**C primero, menú después** — pero **las perillas nuevas de C nacen con metadata**, para que el menú
sea después un lector y no una transcripción. Hacerlo al revés significa construir el panel alrededor
de convars que C está por agregar, o sea hacerlo dos veces.

### ⭐ Y una segunda funcion del menú: que el fantasma **aparezca solo**

**Pedido por el autor el 2026-08-22**:

> *«Falta una opción para spawnear automáticamente un ghost aleatorio (hasta 3 con chance) en el mapa
> con los periodos de gracia que tiene Phasmophobia (Amateur: 5 minutos, Intermediate: 2 minutos, o
> Professional y el resto: inmediatamente en el mapa), tipo para que alguien que entra al juego
> sandbox no deba spawnearlo desde el menú, lo que lo hace más "sorpresivo" y adecuado a GMod.»*

Es una buena idea por una razón que va más allá de la comodidad: **hoy el jugador sabe que hay un
fantasma porque lo puso él.** Eso mata el primer acto entero — la parte en la que no sabes si hay algo
y estás buscando evidencia. Un spawn automático y demorado devuelve esa incertidumbre, y es lo único
del bloque que **no se puede conseguir con perillas**.

| dificultad | cuándo aparece |
|---|---|
| Amateur | a los **5 minutos** |
| Intermediate | a los **2 minutos** |
| Professional y arriba | **inmediatamente** |

Y la cantidad: **1 fantasma, hasta 3 por sorteo**. (En Phasmophobia el multi-fantasma no es estándar,
así que esto es nuestro: hay que declarar los pesos del sorteo y no dejarlos implícitos.)

#### ⚠⚠⚠ COLISIÓN DE NOMBRES, Y HAY QUE ATAJARLA AHORA

**Ya hay dos cosas distintas llamadas «periodo de gracia», y una tercera en camino:**

| | qué es | orden de magnitud |
|---|---|---|
| **fase de preparación** (*setup phase*) | desde que empieza la partida hasta que el fantasma puede actuar | **minutos** (5 / 2 / 0) |
| **gracia de la cacería** (*hunt grace period*) | la cacería empezó, parpadean las luces, pero el fantasma **no ve, no detecta y no mata** | **segundos** (5 / 4 / 3 / 2 / 2 / 1) |
| lo que pide este pedido | cuándo **aparece** el fantasma en el mapa | minutos |

El autor usó «periodo de gracia» para las dos primeras, y es entendible porque la wiki también las
mezcla en el habla. **Pero en el código no pueden compartir nombre**, ni en las convars, ni en el
reporte, ni en los criterios de la planilla: son de escalas distintas (minutos contra segundos), de
bloques distintos (arranque contra cacería), y **un rojo que diga «la gracia no anduvo» tendría dos
sujetos posibles**. Este taller ya pagó por eso con `count`, que se leía en dos lugares y terminaba
componiéndose consigo mismo.

Nombres propuestos, y hay que fijarlos antes de escribir la primera línea:

- `phantasmagoria_ghost_preparacion` — los minutos antes de que aparezca / pueda actuar.
- `phantasmagoria_hunt_gracia` — los segundos de aviso inofensivo al empezar la cacería.

*Dos mecanismos con el mismo nombre no son un problema de estilo: son un rojo que no se puede
diagnosticar.*

#### Lo que hay que decidir

1. **¿Aparece a los N minutos, o aparece ya y no puede actuar hasta los N minutos?** No es lo mismo:
   en la primera no hay orbes ni huellas ni eventos hasta que llegue; en la segunda la evidencia
   existe desde el principio y lo que falta es el peligro. Phasmophobia hace **la segunda** (el
   fantasma está desde el minuto cero; lo que la fase de preparación bloquea es la cacería). El pedido
   del autor dice *«spawnear»*, o sea la primera. **Hay que elegir a propósito.**
2. **Qué cuenta como «empezó la partida» en sandbox**, que no tiene rondas. ¿La carga del mapa? ¿El
   primer jugador que entra? ¿Un comando? Sin una respuesta, el reloj no tiene desde dónde contar.
3. **Qué pasa si ya hay un fantasma spawneado a mano.** El auto-spawn no puede sumar uno encima sin
   avisar: o respeta el que existe, o lo dice.
4. **Que se pueda apagar**, obviamente — y que el reporte diga si el fantasma que estás viendo lo puso
   el auto-spawn o una persona. Es el mismo principio que separó `despertadas ESPONTANEAS` de
   `despertadas FORZADAS` en el motor de eventos: *cuando un contador tiene dos escritores y uno es el
   operador, no acredita al otro.*

#### El CUARTO FAVORITO — la idea del autor (2026-08-22), y qué le cambiaría

> *«Mejor una perilla para que spawnee dentro de los x minutos (1-10, mejor no inmediato porque al
> iniciar un server o singleplayer cargan más cosas). Antes de spawnear se debe elegir en el navmesh
> el "cuarto favorito" (interior o exterior; el exterior debería ser un área circular favorita
> haciendo trace al cielo para confirmar, interior debería hacer trace a las paredes y techo). Por eso
> el fantasma spawnea en su cuarto favorito y genera su corral ahí para que no se vaya tan lejos, que
> hasta el momento tenemos el corral en 1500 u. Luego de spawnear se aplica la fase de preparación.»*

La idea es buena y además **es canónica**: la fuente de 2021 dice que tras matar, el fantasma
*«will teleport back to their favourite room, and reset to idle phase»* — o sea que el cuarto favorito
no es decoración de spawn, es **el ancla del ciclo de ocio entero**, y por ahí toca la tajada C.

##### ⭐⭐⭐ Lo primero: el cuarto favorito YA EXISTE y se llama `ancla`

`server_leash.lua` ya tiene la correa (`phantasmagoria_ghost_leashradius` = **1500 u**, bien
recordado) y ya guarda un `ancla` con un campo `anclaDe` que hoy vale `"spawn"` o `"mano"`. **Lo que
la idea propone no es un sistema nuevo: es un tercer valor de ese campo** — `"cuarto favorito"` — y
una forma deliberada de elegirlo en vez de *«donde lo pusieron»*.

Eso cambia el tamaño del trabajo por completo, y hay que aprovecharlo: nada de un detector de cuartos
nuevo. *Un mecanismo que ya existe con el nombre equivocado se renombra, no se reescribe.*

##### ⚠⚠⚠ Y hay una restricción dura que el propio archivo documenta

`server_leash.lua` avisa que un ancla en **un bolsillo huérfano del navmesh** hace que la correa
clampee destinos inalcanzables, `SetupPathShell` devuelva `blocked4` una y otra vez, y
`term_ConsecutivePathFailures` dispare **`overrideVeryStuck` a los 5 fallos**, en bucle.

O sea que el selector **no puede elegir "un área interior linda"**: tiene que elegir una
**bien conectada**. El criterio no es estético, es de navegación:

- que el área tenga vecinos alcanzables (no una isla),
- y que un porcentaje declarado del corral de 1500 u sea **navegable desde ahí**.

*Un cuarto favorito mal elegido no queda feo: rompe la navegación y dispara el rescate de emergencia
en bucle.* Esa comprobación va **antes** de aceptar el candidato, y el reporte tiene que decir cuántos
candidatos se descartaron y por qué.

##### Interior / exterior: `HitSky` es exacto, no una heurística

El `TraceResult` de GMod trae **`HitSky`**. Un trace hacia arriba que golpea cielo da la respuesta
sin estimar alturas ni contar paredes. Es mejor que "trace al techo y mido la distancia", que falla en
naves grandes y en atrios. Dos salvedades para escribir en el comentario: los **skybox 3D**, y las
áreas techadas por un `func_brush` sin material de cielo.

##### ⚠ El "cuarto" no es una primitiva del navmesh — y no hace falta que lo sea

Un `CNavArea` es un rectángulo, y un cuarto son muchas áreas. Detectar cuartos de verdad (flood-fill
con altura de techo parecida, sin saltos) es un proyecto entero. **Pero la correa ya es un punto más
un radio**, así que el cuarto favorito puede ser simplemente **el ancla**, y lo único que cambia entre
interior y exterior es el **radio** (afuera conviene más grande: no hay paredes que acoten) y el sesgo
de la elección. Recomiendo empezar así y dejar el detector de cuartos anotado como una mejora futura.

##### ⚠⚠ Por qué el exterior importa de verdad, y no es un caso de borde

En `gm_flatgrass` o `gm_construct` **casi todo es exterior**. Un selector que sólo acepte interior no
encuentra sujeto en la mitad de los mapas donde esto se va a usar — y el modo de falla es el de
siempre en este taller: **el auto-spawn no dispara y no dice por qué**, que se lee igual que "está
apagado". Si no hay candidato, tiene que gritarlo con el conteo de lo que descartó.

##### ⚠ Tu instinto del "respiro" es correcto, pero el mecanismo es otro

El riesgo real al arrancar no es la carga: es que **el navmesh puede no existir**. El addon ya lo sabe
— `phantasmagoria_trucktv_plan.lua` chequea `navmesh.IsLoaded()` e intenta `navmesh.Load()`. Si el
único freno es un temporizador, en un mapa sin navmesh **esperás diez minutos y falla en silencio**.

**Separar las dos preguntas**: *«¿puedo?»* (navmesh cargado, hay candidato conectado) se contesta
apenas arranca y **habla al toque si la respuesta es no**; *«¿cuándo?»* (el temporizador) es para la
sorpresa, no para la seguridad. *Un temporizador que además hace de precondición convierte un
"no puedo" en un "todavía no".*

##### ⚠ Un retraso aleatorio vuelve la función imposible de probar

Si el spawn cae en un punto sorteado entre 1 y 10 minutos, **ninguna fila de planilla lo puede medir**
sin esperar diez minutos y rezar. Que sean **dos perillas (mín y máx) y que `mín == máx` sea legal**:
así el juego tiene su sorpresa y la planilla tiene su determinismo. Es la misma solución que la
perilla de certeza del dado en la tajada C.

##### ⚠⚠ Los dos retrasos se COMPONEN, y la suma puede exceder la sesión

Spawn a los 1-10 min **+** fase de preparación de 5 min (Amateur) = hasta **15 minutos** hasta la
primera cacería posible. En una sesión de sandbox eso es *nunca*. Dos consecuencias:

- el preset de dificultad tiene que fijar **los dos números juntos**, no uno;
- y el reporte tiene que imprimir **el total y el momento estimado**, no los dos sumandos por
  separado. *Dos esperas que se suman y se reportan aparte se leen como la mitad de lo que son.*

Además: el reloj **no** cuenta desde la carga del mapa. Cargás el mapa, te vas diez minutos, y el
fantasma aparece y caza sin que nadie lo vea. Cuenta desde el **primer jugador vivo**.

##### ⭐⭐ Y la mejora que de verdad le agregaría: que el cuarto favorito sea DESCUBRIBLE

En Phasmophobia el cuarto favorito no es un detalle interno: **es lo que el jugador está buscando**.
Es donde se concentran las lecturas, y encontrarlo es media partida.

Phantasmagoria ya tiene con qué — `phantasmagoria_evidencia.lua` maneja `Orbs`, `OrbEmitters` y
`UVPrints`. Si el ancla pasa a ser un cuarto favorito de verdad, **la evidencia debería sesgarse hacia
él**: más orbes ahí, más huellas ahí, más eventos ahí. Con eso el corral deja de ser una restricción
técnica (*«que no se vaya lejos»*) y se convierte en **una mecánica** (*«hay un lugar de esta casa que
es suyo, y encontrarlo es el juego»*).

Es la diferencia entre que el corral sea algo que el jugador **sufre** y algo que el jugador
**caza**. Y no cuesta un sistema nuevo: cuesta que tres productores de evidencia consulten un ancla
que ya va a existir.

---

## 4. ⭐⭐ La TEMPERATURA como evidencia, y el cuarto favorito como *loop de juego*

**Pedido por el autor el 2026-08-22**, continuando el cuarto favorito (§3):

> *«Otra evidencia sobre el cuarto favorito es la temperatura. Tenemos a StormFox para eso, pero digo
> que eso es "compatible": mejor es hacer que nosotros mismos "sintamos" el frío, tipo que salga una
> nube chiquita de la cabeza del jugador a unos pocos centímetros de la cara. El equipamiento simula
> mejor la temperatura en vez de medirla realmente como lo es con StormFox. En todo lado del mapa
> fluctúa de 10-25 °C; en la habitación del fantasma está cerca de 10 por unos minutos y luego baja
> hasta bajo cero, −3 o −4 (siempre debería ser más fría aunque no sea bajo 0). Esa es la evidencia de
> que ese es el cuarto (…) aunque esas evidencias las da el tipo de ghost: no todos tienen temperatura
> baja u orbes. También, en algunas dificultades el cuarto favorito cambia cada cierto tiempo.»*

### ⭐ La línea ya estaba dibujada, y esto cae del otro lado

`ghost_flags.lua:110` ya se ocupó del tema y decidió **la mitad que NO se escribía**:

> *«temperatura — Hantu y nadie más (:199, :202). Los doce tipos con evidence "freezing" son
> EVIDENCIA, no evento: no cuentan como sostenedores. Singleton real — no se crea el rasgo hasta que
> haya un segundo tipo.»*

O sea que el archivo ya separó **temperatura como EVENTO** (el poder del Hantu — un singleton, no se
escribe) de **temperatura como EVIDENCIA** (doce sostenedores en la fuente — sin portar). Lo que el
autor propone es exactamente el segundo, que quedó anotado y nunca se hizo. **No hay conflicto: hay
una mitad esperando.**

### ⭐⭐ «Simular en vez de medir» no es un atajo: es la arquitectura correcta

Y ya tiene precedente en este addon — `IsPlayerLit` de B2 distingue *«medí que está a oscuras»* de
*«no pude leer nada»*, y esa distinción decidía un tercio del drenaje. Lo mismo acá:

- una función propia, `PHANTASMAGORIA.TemperaturaEn( pos )`, que devuelve **valor + motivo**;
- **StormFox como MODULADOR del ambiente, nunca como fuente de verdad.**

⚠⚠ Y hay dos razones duras, no de gusto. **(1)** Un tercero no puede ser dependencia de un loop
central: si StormFox no está, la evidencia desaparece; si cambia, se rompe sin avisar. *El engine
también es un tercero, y un addon ajeno lo es más.* **(2)** Si StormFox manda, **no se puede
garantizar la invariante que el propio autor pide** — *«siempre debería ser más fría aunque no sea
bajo 0»* —, porque el ambiente lo decide otro.

### La curva, y la invariante que una planilla sí puede exigir

| | |
|---|---|
| ambiente | fluctúa **10-25 °C** |
| cuarto, primeros minutos | cerca de **10 °C** |
| cuarto, después de la rampa | **−3 / −4 °C** |
| **invariante** | **el cuarto < el ambiente SIEMPRE**, incluso a mitad de rampa |

Esa última fila es la que vale para un check: no depende del reloj ni de la posición, así que una fila
la puede exigir sin esperar a que la rampa termine. *Un criterio que sólo se cumple al final de una
rampa no se puede correr; uno que se cumple en todo punto, sí.*

⚠ Y la rampa es un **TERCER reloj** que se compone con el retraso de spawn y con la fase de
preparación (§3). Tres esperas encadenadas. El reporte tiene que imprimir **el total**, no los tres
sumandos por separado.

### ⚠⚠ La nube de vaho es de CLIENTE, y no puede saber dónde está el cuarto

Si el cliente calcula la temperatura, necesita el ancla — y entonces **cualquiera con un dump de Lua
encuentra el cuarto favorito en diez segundos**, que es todo el misterio del juego regalado. El
servidor manda **la lectura en tu posición** y nada más; el cliente sólo dibuja el vaho.

Es la misma decisión que *«el equipamiento simula en vez de medir»*, aplicada a la red: **el cliente
recibe un síntoma, nunca la causa.**

### ⚠⚠⚠ El agujero del loop, y hay que taparlo antes de escribir la primera evidencia

El autor tiene razón en que las evidencias las da el tipo (*«no todos tienen temperatura baja u
orbes»*). Pero eso abre un hueco que en Phasmophobia no existe:

- allá cada fantasma tiene **3 evidencias de un pool de 7**, así que siempre hay tres caminos;
- acá el pool implementado son **orbes, huellas UV y (con esto) temperatura** — tres. Un tipo cuyas
  tres evidencias canónicas sean otras tres queda con **CERO**, y su cuarto favorito es
  **indescubrible**. El loop no se degrada: se corta.

**La red de contención no cuesta un sistema nuevo**: los eventos paranormales ya tienen epicentro
(B2), y el ancla va a existir. Que los eventos **se concentren cerca del ancla** da un indicio
**independiente del tipo** — la casa te dice dónde vive aunque no tengas ni un instrumento. Es lo que
en Phasmophobia hace que puedas encontrar el cuarto sin evidencia: el fantasma vuelve ahí y se le
oye.

*Una mecánica de descubrimiento que depende de datos por tipo necesita un piso que no dependa de
ellos, o algunos tipos simplemente no tienen juego.*

### El cuarto que se mueve

Es una perilla (intervalo en segundos, **0 = nunca**), y en las dificultades altas se enciende. Dos
cosas al escribirlo:

1. **Mover el ancla mueve el corral** y, si la evidencia se sesga hacia él, mueve toda la evidencia.
   No es un cambio cosmético: es el mundo reacomodándose.
2. **El reporte tiene que decir cuándo se movió y adónde.** Sin eso, *«no encuentro nada»* y *«se
   movió hace diez segundos»* se leen igual — y el jugador (y el que prueba) culpan al instrumento.

### La configuración por mapa

> *«Que en el menú podamos guardar configuraciones sobre el spawn según el mapa: interior, exterior o
> mixto; por defecto interior, y si no logra encontrar dónde esconderse pasa a exterior.»*

Buena, y encaja con §3. Persiste en `data/phantasmagoria/mapas/<mapa>.json`. Dos advertencias:

- ⚠ **El fallback interior → exterior TIENE QUE DECIRLO.** En un mapa mayormente exterior vas a caer
  al fallback siempre, y sin el aviso nunca te enterás de que la búsqueda interior falló — ni de si
  falló porque no hay interiores o porque el selector de conectividad (§3) rechazó a todos los
  candidatos. Son dos causas distintas con arreglos distintos.
- ⚠ **Una configuración que se guarda sola persiste un error.** Si una elección mala queda escrita en
  el `.json`, vuelve en cada sesión de ese mapa. El reporte tiene que decir **de dónde salió el valor
  vigente** — default, archivo guardado, o elección manual de esta sesión — exactamente como
  `anclaDe` distingue `"spawn"` de `"mano"`.

