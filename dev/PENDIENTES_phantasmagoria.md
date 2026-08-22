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

