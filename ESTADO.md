# Phantasmagoria — Estado actual y handoff

**Última actualización:** 2026-08-06
**Repo:** https://github.com/Sepuldosky/phantasmagoria (público, MIT)
**Changelog:** ver [CHANGELOG.md](CHANGELOG.md)
**Diseño vigente:** [docs/PHANTOM_Phasmophobia_Diseno.md](docs/PHANTOM_Phasmophobia_Diseno.md)
**Investigación de la base:** [docs/PHANTOM_Referencia.md](docs/PHANTOM_Referencia.md)
**NPC de evento especial:** [docs/ALTERNATE.md](docs/ALTERNATE.md) — el Alternate de Mandela Catalogue

Documento de traspaso: pensado para retomar el trabajo sin contexto previo.

---

## Dónde está parado esto

**El proyecto dejó de ser papel el 2026-08-05: el fantasma camina en GMod.** Hay investigación
exhaustiva de la base, un diseño completo, la tabla de los 30 tipos generada desde datos reales del
juego, y **una entidad que existe, spawnea del menú, camina y te persigue**, verificada en **tres
corridas sobre dos mapas**.

**El 2026-08-06 se le escribió el primer comportamiento propio: el interruptor fantasma/cazador, y
CORRIÓ.** Fuera del hunt deambula y no ataca; dentro, caza. **6 de 10 filas en verde, 4 sin correr,
0 rojos** — y §3.1 del diseño quedó **refutado en juego**, con su control disparado un segundo antes.
Sigue sin haber máquina de estados, ni tipos, ni cordura.

Lo que existe:

| Pieza | Estado |
|---|---|
| Investigación de la base Terminator | **CERRADA** — 55k líneas leídas, 1.042 APIs auditadas |
| Diseño del motor de rasgos | **CERRADO** — [docs/](docs/PHANTOM_Phasmophobia_Diseno.md) |
| Tabla de los 30 tipos | **GENERADA** — `lua/phantasmagoria/ghost_types.lua`, valida sintaxis |
| Conversión de audio | **HECHA** — 265 archivos, 141 MB → 11 MB |
| Catálogo de audio | **CERRADO** — 265/265 identificados y por acción ([§7.2](docs/PHANTOM_Phasmophobia_Diseno.md)) |
| Diseño de spawn / dificultad / cuartos | **CERRADO** — §12, §13, §14 del diseño |
| Zona segura / esconderse / hunt no determinista | **CERRADO** — §18; corrige dos filas de §2 |
| Percepción: las **6** rutas por las que el bot te ubica | **CERRADO** — §18.7; el arreglo son **dos campos**, no uno |
| Cordura: tasa, ámbito, oscuridad, camión | **DISEÑADO** — §19; falta la forma de la capa NEAD (§19.5) |
| **Props de equipamiento** | **EN EL ÁRBOL** — 36 modelos verificados, 0 referencias rotas |
| Detector de addons duplicados | **ESCRITO** — `lua/autorun/phantasmagoria_assetcheck.lua` |
| Entidad `terminator_nextbot_phantom` | **CORRIENDO EN JUEGO** — `lua/entities/terminator_nextbot_phantom/`, 3 archivos. Check de 5 filas **cerrado en verde** |
| Interruptor fantasma / cazador | **CERRADO EN JUEGO** — el primer comportamiento propio. Dos rondas: la tabla de 10 filas (6 verdes) y la planilla de 8 (**7 pasa, 1 falla**). §3.1 **refutado en juego** |
| Sistema de cuartos + toolgun | **NO EXISTE** — diseñado en §14 |
| SWEPs / entidades de equipo | **NO EXISTEN** — los modelos ya están, falta el Lua |
| Corridas en GMod | **6** (2026-08-05 ×3; 2026-08-06 ×3) — refutaron **dos** predicciones del documento y destaparon **11** defectos: **10 del instrumento y 1 del fantasma** (el primero del arco) |

---

## El próximo paso concreto

**El interruptor está cerrado.** Lo que sigue son dos cosas, en el orden que decida el autor:
**la velocidad** (el fantasma va a 1,96× la carrera del jugador, contra lo que pide §1.1) y
**la cordura** (§19), que es la que tiene que reemplazar al andamio `phantasmagoria_hunt`.

Y una **decisión del autor** que destapó la corrida 6: **el fantasma no gira nunca en calma** —se
congela en el último yaw y se desliza—. Está medido y leído (los cuatro call sites de
`SetDesiredEyeAngles`, ninguno vivo en calma). El arreglo es una línea, pero **cambia cómo se ve el
bot**: hay que decidir si es bug o rasgo antes de tocarlo.

---

## El interruptor fantasma / cazador — **CORRIENDO EN JUEGO**

El fantasma arranca en `phantom_Hunting = false` y **no ataca a nadie**; con el hunt prendido vuelve
a ser el cazador que ya sabía ser. El gatillo es **manual y provisorio** —un concommand— porque la
cordura, que es la que debería dispararlo (§4 y §19), todavía no existe.

### ⚠ §3.1 nombra la función equivocada, y hay dos motivos

§3.1 propone `OnFirstRelationWithPlayer` devolviendo `D_HT` o `D_NU`, y dice *«al entrar en hunt se
re-evalúan relaciones y la base hace el resto sola»*. Leyendo el código, **eso no funciona**, por dos
razones independientes:

**① Nada re-evalúa.** `SetupRelationships` corre **una sola vez**, desde `Initialize`
(`shared.lua:3079`). Itera `ents.Iterator()` y registra un hook `terminator_postentitycreated`
(`enemyoverrides.lua:846-869`), que cubre a los que aparecen **después**, no a los que ya estaban.
Por cada entidad llama `SetupEntityRelationship` → `GetDesiredEnemyRelationship` →
`OnFirstRelationWithPlayer` y **guarda** el resultado con `Term_SetEntityRelationship`
(`enemyoverrides.lua:883`, cuerpo en `terminator_nextbot_base/enemy.lua:44-47`). Es un **cache**.
El nombre lo venía diciendo: `OnFirst…`.

**② Y aunque re-evaluara, la relación no aguanta.** `MakeFeud` (`enemyoverrides.lua:1046-1048`)
reescribe la relación del jugador a `D_HT` con prioridad 1000 en cuanto al bot le pegan
(`PostTookDamage`, `damageandhealth.lua:482`), sin preguntarle nada a nadie. **Un interruptor hecho
de relaciones se reabre de un balazo** y no se vuelve a cerrar, porque nada re-evalúa el cache.

**El interruptor de verdad es `ShouldBeEnemy`** — el lugar donde la base **lee** ese cache
(`enemyoverrides.lua:493`) y que se consulta en vivo por seis caminos:

| Quién lo llama | Dónde | Para qué |
|---|---|---|
| `processFindingEnt` (barrido) | `enemyoverrides.lua:596` | ruta 1 de §18.7 |
| `ForgetOldEnemies` | `enemyoverrides.lua:676` | limpiar memoria — **es el que suelta al enemigo** |
| `FindPriorityEnemy` | `enemyoverrides.lua:719` | elegir enemigo |
| el fallback «sin enemigos» | `shared.lua:3203` | ruta 3 de §18.7 |
| revalidar el enemigo anterior | `shared.lua:3282` | continuidad |
| `HaveEnemy` | `terminator_nextbot_base/enemy.lua:136` | la pregunta pública |

Un `false` ahí **no congela nada**: el cerebro sigue corriendo entero y las 31 tareas siguen ahí. Es
literalmente lo que pide la última línea de §3.1 —*«el bot nunca deja de pensar, sólo deja de tener a
quién odiar»*— sólo que en la función de al lado. Y **no** es `DisableBehaviour`.

**Entonces `OnFirstRelationWithPlayer` queda escrito, pero como INSTRUMENTO y no como mecanismo:**
cuenta cuántas veces la base evalúa la relación y con qué flag, y encadena al `BaseClass` (trampa ①:
la implementación default **no está vacía**, implementa `ExtraSpawnHealthPerPlayer`,
`damageandhealth.lua:872`). Devuelve lo que devuelva el `BaseClass` —`nil`—, así que **la relación
del fantasma con el jugador queda en `D_HT` siempre, a propósito**: un `D_NU` ahí trabaría el
interruptor cerrado para siempre, porque la base exige `D_HT` en `:493` y nada re-evalúa el cache.

> **Consecuencia honesta para el check:** como la relación nunca sale de `D_HT`, **el motivo ② no se
> mide en esta corrida** — no hay nada que `MakeFeud` pueda reabrir. Sigue siendo **[lectura]**. Lo
> que la fila 10 sí mide es su **consecuencia práctica**: que el interruptor aguante un balazo. Si
> alguien alguna vez «simplifica» esto a un interruptor de relaciones, esa fila se pone roja.

### Lo que se agregó

```
lua/entities/terminator_nextbot_phantom/
    server.lua    ENT.phantom_Hunting, ShouldBeEnemy, OnFirstRelationWithPlayer,
                  phantom_SetHunting/phantom_IsHunting, y tres comandos
    client.lua    el marcador cambia de color y dice HUNT / calma
```

| Comando | Qué es | Qué hace |
|---|---|---|
| `phantasmagoria_hunt 0\|1` | **ANDAMIO** | mueve **sólo el flag**. Ni relación ni memoria ni tareas — para que la corrida pueda medir qué hace la base sola |
| `phantasmagoria_hunt_reeval` | **CONTROL** | re-dispara `SetupEntityRelationship` a mano. Existe para probar que el contador de la fila 6 **no está roto** |
| `phantasmagoria_ghost_rel` | instrumento | por fantasma y por jugador: el flag, la relación **cacheada**, y el resultado **en vivo** de `ShouldBeEnemy` |

El estado viaja por `SetNWBool`, **no** por `SetupDataTables` (trampa ③: el `Bool 0` ya es
`Crouching`). Son sistemas distintos y no colisionan; la base no usa ningún NW var —grep sobre sus 71
archivos: cero—.

**Un efecto secundario medido en el código, que si no se lee como bug:** `shared.lua:1387` usa
`ShouldBeEnemy` sobre lo que le bloquea el paso —`not ShouldBeEnemy( blocker )` → `openDoorTime`—, o
sea **abrir en vez de romper**. Con el interruptor en fantasma esa rama se toma siempre. Es la que
queremos.

### El check — **criterios escritos ANTES de correr, ninguno corrido**

Precondiciones ya medidas y sin cambios: junction, base WSID `2944078031`, `scaryblackman` **no**
montado → sale `male_04` por el fallback y está bien.

| # | Qué se hace | Verde | Rojo | **C4** `#1066` |
|---|---|---|---|---|
| 1 | Spawnearlo y mirar consola + marcador | consola dice `hunt NO`; el marcador es **violeta** y dice `calma` | dice `hunt SI`, o el marcador es rojo | ✅ `hunt NO`, violeta, `3.9 m calma` |
| 2 | `phantasmagoria_ghost_rel` de una | `ShouldBeEnemy NO` y `enemigo ninguno` para todos los jugadores | `ShouldBeEnemy SI`, o ya tiene enemigo | ⬜ **sin correr** |
| 3 | Quedarse **quieto y a la vista** 30 s | **no se acerca**: la distancia del marcador no baja de forma sostenida | camina hacia vos y la distancia baja | ✅ no se acerca |
| 4 | **La pregunta abierta.** Dos `phantasmagoria_ghost_where` separados ≥ 30 s, con el jugador quieto | la `pos` cambió **> 200 u**: deambula | cambió ≤ 200 u: **se quedó clavado**, y «no te ataca» se volvió «no hace nada» | ✅ **deambula** (a ojo, no por `pos`) |
| 5 | En el mismo `ghost_where`, mirar las tareas | la lista **no está vacía** y sigue apareciendo `movement_handler` | no hay tareas → algo se congeló y saltear fue apagar | ⬜ **sin correr** |
| 6 | **La medición que puede tirar abajo §3.1.** `phantasmagoria_hunt 1` y **nada más**; después `phantasmagoria_ghost_rel` | las llamadas a `OnFirstRelationWithPlayer` **NO subieron** → nada re-evalúa | subieron → la base **sí** re-evalúa, §3.1 tenía razón y se corrige este documento | ✅ **quedaron en 2** → §3.1 REFUTADO |
| 7 | **Control de la fila 6:** `phantasmagoria_hunt_reeval` | las llamadas **suben** (+1 por jugador por fantasma) | no suben → el contador está roto y **la fila 6 no midió nada** | ✅ `1 -> 2` |
| 8 | Con `hunt 1`, alejarse y esperar | **te persigue**: `enemigo Player [N]`, `ShouldBeEnemy SI`, marcador **rojo** con `HUNT` | no te toma como enemigo | ✅ persigue, rojo, `3 m HUNT` |
| 9 | `phantasmagoria_hunt 0` y **nada más** | en **≤ 3 s** `enemigo` pasa a `ninguno` y deja de perseguir | sigue con enemigo pasados 3 s → hay que limpiar la memoria a mano | ⬜ **sin correr** |
| 10 | Con `hunt 0`, **pegarle un tiro** y esperar 5 s | sigue en `enemigo ninguno` y `ShouldBeEnemy NO` | te toma como enemigo → el interruptor no aguanta un balazo | ⬜ **sin correr** |

## Corrida 4 (2026-08-06) — **6 de 10 en verde, 4 sin correr, 0 rojos**

**El interruptor funciona en las dos direcciones**, y las capturas lo muestran: en calma, caja violeta
y `3.9 m calma`; en hunt, caja roja y `3 m HUNT`.

**§3.1 quedó REFUTADO, y con el control disparado un segundo antes.** El orden real de la corrida fue
**al revés** del que pide la tabla, y eso la hace **más fuerte**, no más débil:

```
] phantasmagoria_hunt_reeval
    #1066  llamadas a OnFirstRelationWithPlayer: 1 -> 2      ← el contador está VIVO, medido acá
] phantasmagoria_hunt 1
    #1066  hunt -> SI ( cazador )   llamadas ...: 2          ← y prender el hunt NO lo movió
```

Con el control corriendo inmediatamente antes, «el contador no se movió» no puede ser «el contador
está roto». **Nada re-evalúa relaciones al entrar en hunt.** Y el bot **sí** cambia de actitud —fila
8—, lo que confirma que el cambio viene del `ShouldBeEnemy` leyendo el flag en vivo y **no** de
ninguna re-evaluación: exactamente la distinción que el aviso de arriba pedía no confundir.

> ### ⚠ La fila 6 se midió en un INSTANTE, y eso ya salió mal tres veces en este proyecto
>
> `phantasmagoria_hunt` imprime el contador **en el mismo frame del flip**. Si la base re-evaluara un
> tick después, esa línea no lo vería. La lectura del código dice que no puede pasar —nada observa
> `phantom_Hunting`— pero **eso es lectura, y la medición que tengo es una foto**. Es literalmente el
> defecto ① de la corrida 1 (*«0 navareas al spawnear» no es «0 navareas»*) y el del contador de
> areas que pasó de 42 a 137. **Se cierra con un `phantasmagoria_ghost_rel` ahora**: si sigue
> diciendo 2, la fila queda cerrada y de paso cae la fila 2, que tampoco se corrió.

**La pregunta abierta quedó contestada: deambula.** *«En calma sólo mira en una dirección y se mueve
aleatoriamente, onda deambulando»* — la predicción se sostiene (`movement_handler` cae en
`movement_inertia` con el comentario *«nothing better to do»*, `shared.lua:4184-4187`). **«No te
ataca» no se volvió «no hace nada».** Queda como **[a ojo]** y no como medición: la fila pedía dos
`pos` separadas y no se tomaron, así que el número no existe. Lo que sí quedó descartado es la rama
catastrófica.

> **Y acá me pasé de explicar, en el mismo párrafo en que lo anotaba.** Leí *«sólo mira en una
> dirección»* del reporte y le colgué encima la trampa ⑦ de Referencia §4.4 —sin `TERM_FISTS` el bot
> no mira hacia su objetivo al moverse, `motionoverrides.lua:2838`—. El autor corrigió enseguida:
> **en calma sí mueve la vista, sólo que menos.** La cita puede seguir siendo cierta en su propio
> alcance (mirar *hacia el goal* al moverse) y aun así **no era la explicación de lo que se estaba
> reportando**. *Una observación en prosa todavía no es una medición, y explicarla antes de fijarla
> convierte una frase suelta en un hecho con cita.* Queda **sin caracterizar**: cuánto mueve la vista
> en calma, y qué la mueve.

### El hallazgo nuevo, que es del autor y no de ninguna fila: **va casi al doble que el jugador**

*«Se mueve a una velocidad muy rápida, muchísimo más rápido que yo por el mod Better Movement.»*
El número: la base trae `ENT.RunSpeed = 550` (`shared.lua:132`, con el comentario del propio autor de
la base *«bit faster than players... in a straight line»*) y el fantasma **no lo pisa**, así que
hereda 550 contra los **280** de `sv_bm_speed_run`. Son **1,96×**. También hereda `MoveSpeed = 300` y
`WalkSpeed = 130`.

**Esto contradice §1.1 del diseño**, que dice que la velocidad se **deriva de la carrera real del
jugador** justamente para que el addon se calibre solo en cualquier servidor. No es un defecto de
este bloque —nunca se tocó la velocidad— pero **es la cuarta vez que «heredado» resulta no ser
«correcto»**, y esta vez lo agarró el juego y no la lectura. Queda abierto abajo.

## Corrida 6 (2026-08-06) — el instrumento nuevo falló **tres veces**, y destapó el primer defecto del FANTASMA

La planilla se vació y se volvió a correr con el instrumento de mirada puesto. **Mismo veredicto —7
pasa, 1 falla— y cuatro defectos nuevos: los tres primeros míos, el cuarto del bot.**

### ① `marcha` decía `quieto ( 0 u/s )` SIEMPRE — y lo pescó el autor

*«Lo raro es que muestre que la marcha esté en 0 o quieto»*, con el bot cruzando 1.400 u entre
lecturas. **La causa fue una guarda que escribí para estar seguro:** `IsValid( ghost.loco )`.
`CLuaLocomotion` **no tiene método `IsValid`**, y el `IsValid()` de GMod devuelve `false` para todo
objeto que no lo tenga — así que la guarda caía **siempre** al vector cero.

**La base nunca envuelve `self.loco` en `IsValid`: lo llama directo**
(`terminator_nextbot_base/motion.lua:54`). Grep sobre sus 71 archivos: cero ocurrencias.

> *Una guarda defensiva que falla hacia un valor creíble es peor que no tenerla.* No tiró error, no
> tiró `nil`: tiró **«quieto»**, que es una lectura perfectamente posible. La única razón por la que
> se detectó es que el autor sabía que el bot estaba caminando. **Sexta vez en el arco que el defecto
> es del instrumento**, y la primera en que el modo de falla es *hacia un valor plausible*.

Corregido: sin guarda, y **con las dos fuentes impresas** —`GetCurrentSpeed()` (la de la base) y
`Entity:GetVelocity()`— para que si alguna vuelve a dar cero se vea **cuál**.

### ② Los yaws se imprimían sin normalizar, así que el mismo ángulo se leía como dos opuestos

`mira yaw -449.7` al lado de `quiere yaw 270.4`, **con `delta 0` en la misma línea**. Los dos números
eran el mismo ángulo y el delta estaba bien; lo que mentía eran los números de al lado.

| Lectura | `mira` crudo | `quiere` crudo | `mira` norm. | `quiere` norm. |
|---|---:|---:|---:|---:|
| 08 a | −449,7 | 270,4 | **−89,7** | **−89,6** |
| 08 b | −451,9 | 268,1 | **−91,9** | **−91,9** |
| 06 | −313,6 | 46,4 | **46,4** | **46,4** |

**Las nueve parejas del reporte son el mismo ángulo.** Todo pasa ahora por `math.NormalizeAngle`.

### ③ `quiere` lo declaré como el discriminante y no discrimina — y el motivo es estructural

**15 de 15 lecturas dieron `delta 0`.** No es calibración: `GetEyeAngles`
(`terminator_nextbot_base/shared.lua:81-93`) arma el ángulo con `self:GetAngles()` y **sólo pisa el
`pitch`**. O sea que **el yaw de «dónde mira» *es* el yaw del cuerpo, y no existe un yaw de cabeza
aparte** que se le pueda comparar. La pareja `mira`/`quiere` no podía separar cabeza de cuerpo **ni
en principio**, y yo la vendí como el par que lo separaba.

Se conserva **como control** —que el delta sea 0 es el dato: el aim converge en el mismo frame— y el
discriminante de verdad pasa a ser una línea nueva: **`al ply`**, el rumbo al jugador más cercano y
el ángulo contra la mirada. Sin eso, «el yaw cambió» no distingue *girar siguiéndote* de *girar solo*.

### ④ Y el que NO es del instrumento: **el fantasma no gira nunca en calma**

Cuatro lecturas cruzando el mapa —de X = −598 a X = +3.520— con **`mira yaw 3.2` en las cuatro**.
Después del hunt quedó clavado en 46,4 por tres lecturas más. **No vuelve a un default: se congela en
el último valor y deja de actualizarse.** Es lo que el autor venía diciendo desde la corrida 4:
*«se mueve mirando a un solo lado todo el tiempo»*.

Y la lectura del código coincide, censando **los cuatro** call sites de `SetDesiredEyeAngles`:

| Dónde | Cuándo dispara | ¿En calma? |
|---|---|---|
| `enemyoverrides.lua:1874` | apuntando al **enemigo** | **no** — en calma no hay enemigo |
| `motionoverrides.lua:3306` | **cayendo** | no |
| `motionoverrides.lua:3311` | **saltando** a una posición | no |
| `shared.lua:1543` (`justLookAt`) | vía el «mirar hacia el goal» de `motionoverrides.lua:2838` | **no** — sale antes con `if not myTbl.TERM_FISTS then return end` |
| `terminator_nextbot_base/init.lua:161` | una vez, al inicializar | — |

**En calma, sin enemigo, sin caer, sin saltar y sin puños, no queda ni un solo call site vivo.**
Medición y lectura coinciden, y esta vez el defecto **es del fantasma**: es el primero del arco que
no es del instrumento.

> **Decisión pendiente, y es del autor:** un fantasma que **se desliza sin girar** puede leerse como
> bug o como rasgo. El arreglo es una línea —apuntar el facing a la dirección de marcha cuando no hay
> enemigo— pero **cambia cómo se ve el bot y necesita su propio check**, así que no se tocó.

---

## Corrida 5 (2026-08-06) — la planilla CORRIDA: **7 pasa, 1 falla**

`dev/checks/phantasmagoria-hunt-r1.html`. **El interruptor queda cerrado**: las cuatro filas que
faltaban salieron verdes, incluidas las dos que podían pedir código.

| # | Resultado |
|---|---|
| 01 · un fantasma, arrancó en calma | ✅ `spawn #1069 … hunt NO` |
| 02 · la puerta cerrada y la relación abierta | ✅ **`rel D_HT pri 1000` + `ShouldBeEnemy NO`** — el resultado del bloque en una línea |
| 03 · el cerebro entero | ✅ **31 tareas**, con `movement_handler`; el refactor no rompió nada |
| 04 · deambula, medido | ✅ **4.885 u de camino** (93 m), neto 2.161 u |
| 05 · el contador fuera del instante | ✅ **1 llamada**, `la ultima a t=101 con hunt=NO`, en **tres** lecturas |
| 06 · suelta al enemigo al apagar | ✅ *«pasa inmediatamente a calma»* — la base lo hace sola |
| 07 · aguanta un balazo | ✅ baleado a fondo: sigue `enemigo ninguno` / `ShouldBeEnemy NO` |
| 08 · la vista en calma | ❌ **FALLA** — y la falla vindica lo que yo había retractado |

**La fila 02 es la que vale por todo el bloque:** `rel D_HT pri 1000` **y** `ShouldBeEnemy NO` en la
misma línea. La relación **no** se apagó —sigue odiándote— y el bot igual no ataca. Eso es
exactamente la separación que §3.1 confundía, exhibida.

**Y la 05 salió más fuerte que lo que pedía el criterio.** Tres `ghost_rel` mientras cazaba, a 62,
568 y 310 u, las tres con `1 llamada(s), la ultima a t=101 con hunt=NO`. El **timestamp** es el dato:
la última evaluación fue a t=101 **con el hunt apagado**, y el hunt se prendió después. No es que el
contador no se movió en el frame del flip — es que **no se movió nunca más**, y se ve el reloj.

### ⚠ Tres defectos de esta ronda, y **DOS son de la planilla**

**① El criterio de la fila 05 pedía «2 llamadas», y lo correcto era 1 — arrastre de bloque anterior,
cometido por mí adentro de la planilla que existe para impedirlo.** Escribí el 2 copiando el contador
del fantasma **#1066 de la corrida 4**, que había recibido un `hunt_reeval`. El #1069 es otro
fantasma y nunca lo recibió: su contador arranca y se queda en 1. *«Una planilla mide un bloque y no
arrastra información de bloques anteriores»* — y el que arrastró fue el criterio. El autor lo juzgó
por la sustancia y marcó PASA, que es lo correcto: **el criterio decía el número equivocado, no la
cosa equivocada.**

**② El criterio de la fila 04 pedía DOS muestras, y las dos primeras habrían dado ROJO.** Los saltos
reales, con el jugador quieto:

| Intervalo | Δ | Contra mi umbral de 200 u |
|---|---:|---|
| 03 → 04#1 | **42 u** | ❌ habría dicho «clavado» |
| 04#1 → #2 | **153 u** | ❌ habría dicho «clavado» |
| #2 → #3 | 470 u | ✅ |
| #3 → #4 | 1.076 u | ✅ |
| #4 → #5 | **3.144 u** | ✅ |

Salió inequívoco porque el autor tomó **seis** muestras y no dos. El umbral estaba bien; **el número
de muestras estaba mal**, y lo peor es que la regla ya estaba escrita en `dev/PLANTILLA_CHECKS.md`:
*«un caso suelto no juzga; si el resultado depende de un sorteo, repetir»*. `movement_inertia` se
turna con `movement_wait` y `movement_camp`, así que una ventana de 30 s puede caer entera adentro de
una pausa. **Escribí la regla en la plantilla y no la apliqué al check que la necesitaba.**

**③ `phantasmagoria_ghost_rel` no muestra la vida, así que la precondición de la fila 07 no era
visible.** *«Acá lo baleo completamente bajándole la vida»* quedaba como afirmación del que corre la
planilla y no como dato del instrumento — y la regla de la casa es que **el comando imprima con qué
está midiendo**. Corregido: ahora imprime `vida N / M` y dice `( recibio dano )` o `( INTACTO: nadie
le pego )`.

### La fila 08 falla, y la falla vindica la explicación que yo había retractado

*«Por fijo es que mira a un lado generalmente, es muy poco que gira a ver otros lados y eso es cuando
está quieto.»*

La rama de falla que escribí decía: *«en calma la cabeza está totalmente fija → la explicación que
descarté era la buena»*. Y el código dice exactamente eso
([`motionoverrides.lua:2838-2845`](../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/motionoverrides.lua#L2838)):

```lua
if not myTbl.TERM_FISTS then return end -- only look towards goal if we have fists

local currentSpeed = vecMeta.Length2DSqr( locoMeta.GetVelocity( myTbl.loco ) )
if currentSpeed < terminator_Extras.term_DefaultSpeedToAimAtProps then
    ...justLookAt( self, towardsPos )
```

Sin puños ese camino **no corre nunca**; y aun con puños, sólo apunta **por debajo** de un umbral de
velocidad. Las dos mitades coinciden con lo observado: **la cabeza no gira mientras camina, y lo poco
que gira es estando quieto.**

> **Pero la lección no es «yo tenía razón», es la contraria.** Mi error nunca fue la cita: fue
> **colgarla de una frase suelta antes de fijar la observación**, y después **retractarla de más** al
> primer «no, sí mueve la vista». Las dos veces expliqué en vez de medir. Lo que cerró esto fue un
> check con lado-que-falla escrito, no un argumento. *Y lo que sigue sin leerse es la otra mitad:
> **qué** le mueve la cabeza cuando está quieto.*

**Por eso el instrumento cambió, y es el pedido literal del autor** —*«falta que el comando muestre a
dónde está mirando»*—. `phantasmagoria_ghost_where` ahora imprime **tres** líneas que se discriminan
entre sí:

| Línea | De dónde sale | Qué separa |
|---|---|---|
| `mira` | `GetEyeAngles()` (`terminator_nextbot_base/shared.lua:81`) | **el yaw es el del CUERPO**: la función sólo pisa el *pitch* con `GetAimPitch()` |
| `quiere` | `GetDesiredEyeAngles()` (`motion.lua:139`) | lo que alguna tarea le **pidió** mirar |
| `marcha` | `loco:GetVelocity()` | hacia dónde se mueve, y el ángulo contra `mira` |

`quiere ≠ mira` significa *«algo le pide girar y no llega»*; `quiere == mira`, los dos quietos y
caminando, significa **que nadie se lo pide** — que es lo que predice no tener `TERM_FISTS`. Sin las
tres juntas, «no mueve la cabeza» no distingue las dos causas.

> Ojo con el `loco`: la base mueve al bot por el locomotion, no por la física de la entidad
> (`motionoverrides.lua:2840` usa `locoMeta.GetVelocity( myTbl.loco )`). Un `Entity:GetVelocity()`
> sobre un NextBot puede dar cero y leerse como «está quieto».

---

### La planilla de la ronda 1 → **CORRIDA**: `dev/checks/phantasmagoria-hunt-r1.html`

La corrida 4 se llevó adelante contra la tabla de acá arriba, que es lo que el encargo pedía. **Para
lo que falta se armó la planilla**, que es la convención de la casa para checks en juego
(`dev/PLANTILLA_CHECKS.md`; hay 24 ejemplares en `dev/checks/`) y que la tabla markdown no da: un
campo de nota por check —*«la nota se llena aunque el check pase»*—, `SIN CORRER` como estado
legítimo, y el botón que arma el reporte.

Son **8 checks**: las cuatro filas que quedaron sin correr, más cuatro que salieron de la corrida
misma.

| En la planilla | De dónde sale |
|---|---|
| 01 · hay **un** fantasma vivo y arrancó en calma | precondición nueva: los comandos iteran sobre todos y con dos las lecturas se mezclan |
| 02 · la puerta cerrada **y** la relación abierta | la fila 2 — y es la **primera ejecución en la historia** de `phantasmagoria_ghost_rel` |
| 03 · el cerebro sigue entero | la fila 5 — y `ghost_where` **se refactorizó** (`makeSay` + `eachGhost`) y no se volvió a correr |
| 04 · deambula, **medido** | la fila 4, que salió **[a ojo]**: acá se toman las dos `pos` |
| 05 · el contador **fuera del instante** del flip | cierra la única debilidad de la corrida 4 |
| 06 · al apagar suelta al enemigo en ≤ 3 s | la fila 9 |
| 07 · aguanta un balazo | la fila 10 — **guardia de regresión** del interruptor |
| 08 · en calma mueve la vista **menos** que cazando | fija la observación que expliqué antes de caracterizarla |

**Los dos instrumentos sin ejercer son la razón por la que 02 y 03 van antes que nada:** si tiran
error de Lua, el que falló es el instrumento y no el fantasma, y hay que anotarlo igual. La **06** y
la **07** son las dos que pueden salir rojas y pedir código.

> **La planilla también es un tercero, y se auditó.** Seis bloques: sin arrastre del bloque anterior
> (0 ocurrencias de «paramic»), sin bloque `RESULTS` que pise el estado al cargar, `STORE` único
> —contrastado contra **23 de las 25** planillas; las dos que faltan no declaran la clave en ninguna
> forma que el patrón reconozca, y queda dicho—, el título del reporte cambiado (que es el que no se
> ve en la página y por eso se olvida), 32 campos con HTML crudo balanceados, y los 8 checks en
> `idle`. **El primer barrido cubrió 20 de 24 porque mi propio patrón pedía `const STORE` y cuatro
> planillas lo escriben sin `const`** — un inventario a medias, otra vez, esta vez en el auditor.

**Predicciones, para que la refutación sea barata:** 1-3 verdes, 4 **deambula** (`movement_handler`
cae en `movement_inertia` con el comentario *«nothing better to do»*, `shared.lua:4184-4187`), 5
verde, **6 verde en el sentido de que §3.1 queda refutado**, 7 verde, 8-10 verdes. Si algo sale
distinto, **gana el juego** y se corrige el documento.

> **⚠ La fila 6 se puede leer mal de la forma más fácil.** Al prender el hunt el bot **sí** va a
> cambiar de actitud —eso es la fila 8— y es tentador anotarlo como que §3.1 tenía razón. **No lo
> tiene:** el cambio viene del `ShouldBeEnemy`, que lee el flag **en vivo**, y §3.1 afirmaba otra
> cosa muy concreta —que se **re-evalúan las relaciones**—. Lo único que mide la fila 6 es el
> contador, y la fila 7 existe para que un contador quieto no se pueda confundir con un contador
> roto. *Medir la consecuencia no es medir el mecanismo.*

> **Dos cosas de la fila 10 que hay que saber antes de leerla mal.** ① El tiro **sí** te mete en su
> memoria: la ruta 4 de §18.7 (`PostTookDamage` → `UpdateEnemyMemory`, `damageandhealth.lua:500`)
> **no chequea línea de vista ni relación**. Lo que la fila mide es que `ForgetOldEnemies` y
> `FindPriorityEnemy` te descarten igual, porque las dos preguntan `ShouldBeEnemy`. ② El bot **va a
> girar la cabeza** hacia el disparo — `TookDamagePos` (`damageandhealth.lua:515`) — y eso **no** es
> tomarte de enemigo: si girar contara como rojo, la fila mediría otra cosa. La vida es 900, así que
> unos tiros no lo matan.

> **La fila 4 del check anterior cambia de premisa.** Decía «camina hacia el jugador» y salía verde
> porque el bot era hostil **a propósito**. Con el interruptor, esa fila **sólo vale con
> `phantasmagoria_hunt 1`** — que es exactamente lo que mide la fila 8 de acá. No es una regresión:
> es que el criterio viejo medía un andamio.

---

## El check de la entidad mínima — **CERRADO EN VERDE**

Son tres archivos:

```
lua/entities/terminator_nextbot_phantom/
    shared.lua    registro, clase, categoría — corre en los DOS realms
    server.lua    modelo, desarmado, FOV, y los avisos de spawn
    client.lua    el marcador que atraviesa paredes
```

**Su primer trabajo es ser instrumento, no ser un fantasma.** Por eso `IsWraith` está **fuera**
—corrige el snippet que este documento traía, que lo incluía— y por eso el bot queda **hostil a
propósito**: el criterio de cierre dice «camina hacia algo» y hace falta un algo.

### Las precondiciones, medidas en la máquina del autor (no supuestas)

| Precondición | Estado | Cómo se midió |
|---|---|---|
| El addon montado en GMod | ✅ | junction `garrysmod/addons/phantasmagoria` → el repo. El código entra al arrancar, sin copiar nada |
| La base Terminator montada | ✅ | WSID **2944078031**, título *«Terminator Nextbot»*. Ojo: `CREDITOS.md` anota `2734691788`, que **no** está suscrito |
| Un mapa con navmesh | ✅ | `maps/gm_construct.nav` (7,2 MB) y `gm_flatgrass.nav` (277 KB) ya existen. **No hace falta `nav_generate`** |
| `models/dejtriyev/scaryblackman.mdl` | ❌ | **no lo trae ningún addon montado** — barridos los 418 con contenido (395 `.gma` + 26 legacy `.bin` descomprimidos), las otras 455 carpetas del Workshop están vacías |

**El modelo faltante no bloquea el check, y por eso el fallback existe:** `server.lua` va a caer a
`models/player/group01/male_04.mdl` —presente en el índice de `garrysmod_dir.vpk`— y **lo va a decir
en consola**. Así que la predicción de la fila 2 cambia: **no** sale la silueta negra sin ojos, sale
un ciudadano de HL2. Si querés el modelo bueno, está desempacado en
`dev/other/phantom/dev2/scary black man (hood irony) playermodel/` y se monta con un junction a
`addons/`, igual que este repo.

> Los dos negativos de arriba salieron **con control**, porque el primer barrido mintió dos veces: el
> parser de títulos `.gma` daba 0 coincidencias hasta que se le leyó bien la lista de contenido
> requerido, y el barrido por substring daba «ninguno» sobre los legacy `.bin` **porque están
> comprimidos con LZMA** — lo delató que el control (Jeff, que sí está suscrito) tampoco aparecía en
> su propio archivo.

| # | Qué se hace | Verde | Rojo | **C1** `gm_graysonhouse` | **C2** `gm_uh_house` | **C3** `gm_graysonhouse` |
|---|---|---|---|---|---|---|
| 1 | Abrir el spawnmenu, pestaña **NPCs** | hay categoría **Phantasmagoria → Fantasmas** con *Phantasmagoria Ghost* | no está | ✅ | ✅ | ✅ |
| 2 | Clickearlo | aparece un cuerpo, y la consola imprime `[Phantasmagoria] spawn #N modelo … pos …` | error de Lua, o nada | ✅ `#253` | ✅ `#1090` | ✅ `#276` |
| 3 | Mirarlo | hay caja violeta + haz + `PHANTOM #N` + distancia en metros, **también a través de una pared** | no se dibuja nada | ⚠️ sin etiqueta | ✅ `4 m` | ✅ `1.3 m` |
| 4 | Alejarse y esperar | **camina hacia el jugador** — el marcador se mueve y la distancia baja | se queda clavado | ✅ camina y persigue | ✅ se movió 68 u, `enemigo Player [1]` | ✅ se movió 137 u |
| 5 | `phantasmagoria_ghost_where` en consola | lista pos, vida, modelo, enemigo, tareas y navareas | dice 0 fantasmas con uno vivo | sin correr | ⚠️ todo menos las tareas | ✅ **las 31 tareas** |

## ✅ CHECK CERRADO — las cinco filas en verde

**La entidad funciona.** Existe, aparece en el menú, spawnea, camina, te persigue, te toma como
enemigo, y los dos instrumentos reportan. Verificado en **tres corridas sobre dos mapas**, uno con
navmesh y otro sin.

**Los CUATRO defectos que salieron son del INSTRUMENTO, no del fantasma.** El fantasma anduvo a la
primera y nunca falló. Los cuatro están corregidos; tres, confirmados en juego.

**① El aviso de navmesh predecía en vez de medir — y el juego lo refutó.** Decía «SIN NAVMESH: el bot
no va a caminar», había 0 navareas, y **el bot caminaba**. La medición del instante era correcta; la
predicción, falsa. La causa estaba en el código que yo mismo había leído para escribir el aviso: con
0 areas la base llama a **`TryGeneratingAreas()`** (`shared.lua:3072-3075`) y el **parcheador**
(`terminator_areapatcher.lua`, convar `terminator_areapatching_enable`, **default 1**) sigue creando
areas donde caminan bots y jugadores. Leí la rama del mensaje y no la línea de abajo, que es la que
actúa. **Arreglado midiendo dos veces**: informa el 0 al spawnear y **vuelve a medir a los 10 s**,
diciendo cuántas areas lleva el parche — o confirmando el 0, que ahí sí es terminal.
**Confirmado en la corrida 3**: `0 navareas al spawnear` → `van 42 navareas a los 10 s`.

> **Y el número sigue creciendo, lo cual obligó a cambiar el verbo.** El mismo `ghost_where`, un rato
> después, dio **137**. El parcheador crea areas donde pisan bots y jugadores, así que la lectura es
> **una foto y no un total** — decía «construyó 42» y ahora dice «van 42 … y sigue trabajando».
> Tercera vez en este arco que un número medido en un instante se escribe como si fuera permanente.

**② La etiqueta del marcador estaba sobre el techo.** Se veían la caja y el haz y no el texto: estaba
a 250 u sobre la cabeza (~322 del piso), y la corrida fue **adentro de una casa**. El instrumento se
diseñó para un mapa abierto. Bajada a 14 u — pegada a la cabeza. El haz largo se queda: es lo que te
dice desde otra habitación en qué dirección está. **Corregido y confirmado en la corrida 2.**

**③ `phantasmagoria_ghost_where` perdía su mejor línea, y el aviso no decía cuál.**
`HUD_PRINTCONSOLE` viaja por un user message `TextMsg` con techo de **255 bytes**, y al pasarse **no
se trunca: el servidor se niega a mandarlo** — `Refusing to send user message TextMsg of 256 bytes`.
De las seis líneas por fantasma se perdió exactamente una: **la de tareas**, que es la más
informativa y la única que crece sin techo. El único rastro fue ese aviso del engine, que **no dice
cuál se perdió**: sin leer la salida esperada al lado de la real, pasa por completa.
Arreglado troceando toda línea a 180 bytes —red de seguridad para las seis— y sacando **una tarea por
línea**, que además se lee mejor. **Confirmado en la corrida 3: llegaron las 31.**

**④ La etiqueta tapaba media pantalla de cerca.** Con escala fija, `cam.Start3D2D` crece sin techo al
acercarse: a **1,3 m** el `PHANTOM #276` no entraba en la pantalla — justo cuando más querés ver.
Ahora **la escala sigue a la distancia** para ocupar siempre lo mismo, calibrada contra la corrida 2
(a 4 m, escala 0,35) y con topes en 0,12 y 1,5. **Sin confirmar en juego.**

> **Las 31 tareas de la fila 5 no son ruido: son el inventario del cerebro heredado**, y ahí está la
> §5 de la referencia hecha lista — `movement_watch` (el comportamiento HIM ya escrito),
> `movement_stalkenemy`, `movement_camp`, `movement_backthehellup`, `movement_followsound`. Todo eso
> ya corre. Lo que falta no es escribirlo: es elegir cuándo.

El 3 y el 5 son **dos instrumentos que fallan distinto**: el marcador solo ve lo que está en el PVS,
el comando corre en el servidor y los ve a todos. Si el 5 lo encuentra y el 3 no, el bot existe y el
que falló es el dibujo.

### Si la fila 1 sale roja: la escalera que separa las causas

Cuatro formas de spawnearlo que dependen de cosas distintas, de más frágil a más cruda. La primera
que funcione dice dónde está el corte:

| Camino | De qué depende | Si anda y el anterior no |
|---|---|---|
| menú NPCs | registro **en el cliente** | falló `RegisterNPC` clientside — o sea el entrypoint (§4.4④) |
| `gmod_spawnnpc terminator_nextbot_phantom` | `list.GetEntry( "NPC", … )` **en el servidor** (`sandbox/gamemode/commands.lua:607`) | el registro corrió en el servidor y no en el cliente |
| `gm_spawnsent terminator_nextbot_phantom` | `ENT.Spawnable`, lista `SpawnableEntities` (`commands.lua:918`) | `RegisterNPC` falló en los dos realms, pero la clase existe |
| `lua_run ents.Create( "terminator_nextbot_phantom" ):Spawn()` | sólo que la clase esté registrada | la entidad está sana y todo el problema es de listas |

Si falla **también** el cuarto, la clase no se registró: hay un error de Lua al cargar y está en la
consola, arriba de todo.

Si algo sale distinto de lo que este documento predice, **gana el juego** y se corrige el documento.

### Lo que deliberadamente NO tiene, y por qué

| Ausente | Por qué |
|---|---|
| `ENT.IsWraith` | un instrumento invisible no sirve para ver dónde está |
| ~~`OnFirstRelationWithPlayer`~~ | **ya no está ausente** — se escribió el 2026-08-06, pero como instrumento y no como interruptor. Ver el bloque de arriba |
| `SetupDataTables` | el `Bool 0` ya es `Crouching` en la base (trampa ③) |
| máquina de estados, 30 tipos, rasgos, cordura, sonidos | todo eso venía **después** de verla caminar una vez — y ya caminó |

**Dato de la corrida 3 que es decisión de diseño pendiente: la vida es 900**, el default de la base
(`terminator_Extras.healthDefault`). Un fantasma de Phasmophobia no se mata a balazos: §5.4 dice que
el desenlace es `kill` o `banish` por tipo, así que ese número va a dejar de ser salud y a pasar a
ser otra cosa.

Las trampas de la base están en §4.3 y §4.4 de la referencia. Resumidas:

1. **`ENT.Models`, no `ENT.Model`** — si no, spawnea con Arnold.
2. **`Term_FOV` necesita `AutoUpdateFOV = false`** o la convar global lo pisa en caliente.
3. **No usar `SetupDataTables` con `Bool 0`** — la base ya usa ese slot para `Crouching`.
4. **El interruptor fantasma/cazador es `ShouldBeEnemy`** —y **nunca** `DisableBehaviour`—. Esta
   línea decía `OnFirstRelationWithPlayer`, que es lo que dice §3.1, y **es la función equivocada**:
   ésa escribe un cache que se llena una vez. Corregido el 2026-08-06 leyendo el código; el detalle,
   arriba.
5. **`ENT.Base = "terminator_nextbot"`**, no `"terminator_nextbot_base"` — el `_base` no tiene cerebro.
6. **El punto de entrada de una entidad-carpeta es `shared.lua`**, no `init.lua`: el registro tiene
   que correr **en el cliente**, que es donde se arma el spawnmenu (§4.4④).

---

## Decisiones tomadas

| Tema | Decisión | Cuándo |
|---|---|---|
| Base | `terminator_nextbot` (no DRGBase, no VJ) | 2026-08-01 |
| Velocidad | Relativa a la carrera real del jugador, vía Better Movement | 2026-08-01 |
| Desenlace del hunt | Por tipo: `kill` o `banish` | 2026-08-01 |
| Vuelta del destierro | Muriendo (rápido) **o** por ritual (el camino divertido) | 2026-08-01 |
| Audio | `.ogg`, originales intactos aparte | 2026-08-01 |
| Alcance | Sandbox, **no** gamemode | 2026-08-01 |
| Modelos | `scaryblackman` + el quemado de HL2 + los que aparezcan | 2026-08-01 |

---

## Lo que está abierto

- **LA VELOCIDAD: el fantasma va a 1,96× la carrera del jugador, y §1.1 dice que tiene que derivarse
  de ella.** Medido en juego por el autor (corrida 4) y con número desde el código: la base trae
  `ENT.RunSpeed = 550` (`shared.lua:132`), el fantasma **no lo pisa**, y `sv_bm_speed_run` del autor
  es **280**. También hereda `MoveSpeed = 300` y `WalkSpeed = 130`. El arreglo ya está diseñado —§1.1:
  los tipos son **multiplicadores de la carrera real**, y el getter de Better Movement **no sirve**
  porque lo multiplica por `_bmfraction` (1..2), así que hay que leer la convar— pero **no está
  escrito**. Ojo con `overcharging.lua:20-22`, que puede volver a subirlo (`RunSpeed * 1.40`, piso
  550).
- **Cuánto mueve la vista el fantasma en calma, y qué se la mueve.** Sin caracterizar. El autor
  reporta que **sí** la mueve, menos que cazando.

- ~~La forma de la capa de compat con NEAD~~ **DECIDIDO: no se integra** (§19.5). NEAD hace
  `ply:SetNoTarget(true)` a un segundo a oscuras sin linterna, y la base respeta `FL_NOTARGET` en
  `ShouldBeEnemy` **y en el alerter** — invisible **e inaudible**. El override era posible, pero
  **las 6 muestras de oscuridad son API del engine, no de NEAD**: se reimplementan en 20 líneas, sin
  heredar el conflicto. **NEAD queda declarado no compatible, con aviso y sin bloquear** (precedente
  de `phantasmagoria_assetcheck.lua`). El sampler va **chico y autocontenido**: Cortex lo va a
  necesitar.
- **La pantalla del camión** (§19.3) — **EN CURSO EN OTRA SESIÓN, por el camino bueno: se está
  ripeando la pantalla real del camión de Phasmophobia.** El modelo ya está bien y el Lua que le pone
  la info está en proceso. **No hay que hacer nada con `tv_plasma`**: `dev/other/cs_office_tv/` queda
  sólo como respaldo del prop de CS:S y como registro de la trampa de `vpk.exe`. Lo que sigue
  valiendo de acá es §19.3: **HTML para las pantallas del camión, 2D para el equipo en mano**, y no
  asumir que `DHTML:GetHTMLMaterial()` sirva en `SetSubMaterial`.
- **¿`DHTML:GetHTMLMaterial()` sirve en `SetSubMaterial` sobre un modelo?** Sin medir. El camino
  seguro es HTML → nuestro RT → submaterial, que reusa la plomería del paramic.
- **Los 3 tiers de las pastillas** y qué restaura cada uno (§19.6). El modelo ya está:
  `models/phas/eqp_sanity_pills.mdl`.
- **Qué drena cordura y cuánto**, y **qué suma al medidor de actividad** 0-10 (§19.3, mecánica nueva
  que salió de las capturas del camión).

- ~~¿`MASK_BLOCKLOS` choca con `prop_physics`?~~ **MEDIDO Y REFUTADO EN JUEGO** (2026-08-03, §18.6):
  **no choca.** Control `true / Entity [59][prop_physics]`, con el mask `false / [NULL Entity]` —
  misma línea, única variable el mask. **Primera medición del proyecto y refutó al documento.**
  El arreglo es un campo: `ENT.LineOfSightMask` es por entidad con fallback al global
  (`shared.lua:2960`), y sus tres usos son la misma clase de pregunta.
  **MEDIDO EN JUEGO que el campo se respeta** (2026-08-03): de frente sin nada en medio `solid=true`
  —el control—, tras un container y tras unas compuertas `solid=false`. De paso salió que **las
  compuertas tampoco cortan `MASK_BLOCKLOS`**. Sigue **sin medir** que un `ENT.LineOfSightMask` de
  **subclase** sobreviva la línea de init: acá se seteó después del spawn.
  **El mask elegido es `MASK_SOLID`**, barriendo cinco candidatos en juego: es el único de los dos
  que sirven sin traer `CONTENTS_DEBRIS` (gibs cortando la vista) ni `CONTENTS_HITBOX` (caro, y este
  trace corre por enemigo y por barrido).
- ~~¿El mundo sí corta `MASK_BLOCKLOS`?~~ **MEDIDO: sí** — las cinco pegan en `worldspawn` contra una
  pared. **La rama catastrófica está muerta**, la base no es omnisciente.
- ~~¿Una entidad (jugador, NPC) corta `MASK_BLOCKLOS`?~~ **MEDIDO: no.** Mismo barrido contra un
  `npc_kleiner`: mismo patrón exacto que la caja, con una entidad de clase distinta. **`MASK_BLOCKLOS`
  es geometría del mundo y nada más**, y `CONTENTS_MONSTER` es el bit de «esto es una entidad». Con
  eso queda medido también el efecto secundario de `MASK_SOLID`: **jugadores y NPCs ocluyen**.

- **Plan del autor (2026-08-03): la entidad básica se escribe como instrumento** — primero existir y
  **mostrar dónde está**, después todo lo demás. Tres cosas para no tropezar:

  1. **NO ponerle `ENT.IsWraith = true` todavía.** §2 lo lista como el regalo que la hace invisible
     fuera del hunt — y un instrumento invisible no sirve para ver dónde está.
  2. **La base ya trae visualizadores**, no hace falta escribirlos: `term_debugpath` (dibuja el path;
     **pide `sv_cheats 1`**, `base/init.lua:92`), `term_debugtasks` (imprime tareas, y vuelca el
     historial al hacerle **+use** al bot) y `term_debughearing`.
  3. **El check NO depende de la entidad.** «¿Un prop corta `MASK_BLOCKLOS`?» es una pregunta de
     `util.TraceLine` entre dos puntos cualesquiera: se contesta desde consola sin NextBot. Hacerlo
     con el fantasma es **más convincente** —ejerce la cadena real, `GetShootPos` → `EntShootPos`→
     `CanSeePosition`— pero si la entidad se demora, la versión sintética desbloquea el diseño igual.
- **Dos defectos de la base, y muerden en momentos distintos** (§18.3):
  1. **Vista infinita sobre jugadores, y está etiquetada como feature** — `DoDefaultTasks` recorre
     `player.GetAll()` **sin filtro de distancia** cuando el bot no tiene enemigo (*«cheap infinite
     view distance»*, `shared.lua:3185`). Es la **ruta 3** de §18.7. **Vive y muerde hoy.** Se acota
     overrideando `ShouldBeEnemy`, que es **punto único**: las tres rutas de adquisición pasan por
     ahí. Por eso el arreglo son **dos campos MÁS un override**, no dos campos.
  2. **La dispersión se invierte pasando los 500 u** (`500 - sndDist`, y `VectorRand()` sin
     normalizar): más ruido mejora la puntería sólo hasta 500, y a 500 clavados **te da la posición
     exacta**. **Está DORMIDO** —vive en `shouldNotSeeEnemy`, muerta tras el `if` del alfa— y se
     hereda **en el instante en que se des-gatee** (§18.3). Arreglarlo en **esa misma** sesión.
- ~~Los sonidos ambiguos: 46 de 265.~~ **CERRADO** (2026-08-03): el autor los escuchó y los
  describió uno por uno; están catalogados y `_sin_identificar/` ya no existe. **265 de 265 mapeados**
  por acción, **incluidos los pasos del fantasma** — `ghost/footstep/boots_1-8`, §7.4.
- **Los pasos lejanos** (§7.5, pedido del autor): un ghost event de pisadas lentas a distancia, sin
  fuente visible. **No necesita assets nuevos** —es el banco de botas sonando lejos— y el rasgo
  (`ability.paranormalSoundInterval`) ya existe. Falta escribirlo, como todo lo demás.
- ~~**La parabólica no existe**~~ **PORTADA Y CERRADA EN JUEGO** (2026-08-05): los **tres tiers**
  del Parabolic Microphone están en el árbol (`models/phantasmagoria/paramic1-3.mdl`), con su plato
  parabólico translúcido, sus pantallas dibujando un RenderTarget con el contenido real del Canvas
  del juego, y el LED del tier 1 parpadeando. Cuatro rondas de checks en juego, la última 8/8
  (`dev/checks/paramic-vidrio-r4.html`). Ver el CHANGELOG del 2026-08-05.
  **Lo que falta no es el asset sino la mecánica:** siguen siendo props, no ítems —falta la forma
  (SWEP/entidad) y sobre todo **conectar las pantallas a datos reales**, porque
  `PHANTASMAGORIA.ParamicData` arranca en CERO y nada lo llena. El disparador del LED tampoco existe.
- **El sound sensor sigue sin prop.** Con la identificación de sonido cerrada, la mecánica de
  **delatar por sonido tiene audio y ya tiene la mitad de sus props** — le falta a la Music Box, que
  ya tiene su tarareo.
- **Los equipos.** La **forma** ya está decidida ([docs/EQUIPAMIENTO.md](docs/EQUIPAMIENTO.md) §5):
  SWEP lo que se sostiene, entidad lo que se planta y la escenografía, ítem con `onUse` lo que se
  consume. Falta **elegir cuáles entran primero** — EMF reader, spirit box, cámara, termómetro, libro
  de escritura, UV, DOTS, salt, crucifijo — y escribir el primero de punta a punta. El viewmodel es
  el prop flotando frente a la cámara: los 36 modelos tienen **1 hueso y 1 secuencia**, así que no
  hay manos ni animación posibles sin recompilar (§5.1, medido).
- **Cargo.** La integración está diseñada y leída contra su código (§6), sin escribir. Lo que hay que
  saber antes de tocar nada: **la captura de Cargo se come cualquier SWEP** que el engine entregue y
  le fabrica un def de 2,5 kg sin precio, así que registrar defs propios no es opcional si Cargo
  está montado. Sigue siendo **soft-dep**: sin Cargo tiene que haber camino propio.
- ~~El arte de las huellas UV.~~ **CERRADO** (2026-08-02): se reciclan los decals de gmpa, derivados
  a máscaras teñibles con [`dev/uv_prints.py`](dev/uv_prints.py) y acreditados con hash. Cuatro
  texturas en `materials/phantasmagoria/uv/`. Lo que **queda** es el Lua: la evidencia `uv` la tienen
  **13 de los 30 tipos** y la mecánica está diseñada en
  [docs/EQUIPAMIENTO.md](docs/EQUIPAMIENTO.md) §8 — falta escribirla.
- **El Alternate** (Mandela Catalogue) — **NPC de evento especial, fuera de los 30 tipos.**
  **ACTUALIZADO 2026-08-05: el banco de voces pasó de 34 a 168 archivos (20,2 min) y eso cambió el
  diseño, no sólo los números.** Dos bancos nuevos mandan: `sayto_ghost` (62 líneas dirigidas a otro
  fantasma) **obliga a que el Alternate NO sea el fantasma del contrato** —se suma al sorteo, no lo
  reemplaza— y convierte al enemigo en **fuente de información**: le habla al otro fantasma, el
  jugador espía, y **7 de los 30 tipos tienen voz propia** (`demon`, `goryo`, `jinn`, `oni`,
  `poltergeist`, `shade`, `yokai` — verificado contra las claves de `ghost_types.lua`), así que 23
  de 30 partidas la conversación no revela nada. `idle_prayer` (10) es **la única ventana en la que
  el crucifijo destierra** en vez de sólo degradar: dura ~6 s, igual que `preacherwhispers`.
  **El loop está cerrado en ALTERNATE.md §7-§9**: el antagonista es a la vez el obstáculo, el sistema
  de pistas y la condición de victoria.
  **Y meter un segundo fantasma destapó que el daño de cordura estaba inflado al doble** (lo pescó el
  autor): con el anfitrión drenando en paralelo, la cordura llegaba a 0 en **4:03** y no entraba nada
  de lo que el diseño pide que pase. Arreglado con dos piezas (§5.2-§5.5): la aparición vuelve al
  **15 % del `about.txt`** —yo la había puesto en 30 %— y **mientras el Alternate está activo el
  fantasma anfitrión se calla**: no hace eventos, no drena y no caza, así que los drenajes no se
  apilan y **el silencio de la casa se vuelve el aviso de que llegó**. Las evidencias ya puestas NO
  se suprimen: el contrato se sigue pudiendo resolver.
  **Los 168 están TRANSCRITOS** (2026-08-05, `faster-whisper` local, con permiso del autor; el `.tsv`
  quedó **fuera del repo** a propósito). Dos resultados que cambian el diseño: (1) las líneas
  específicas **no nombran al fantasma — son adivinanzas** sobre la etimología y el folklore del
  nombre (*"they threw beans at you, once a year"* = Setsubun = Oni), o sea que la información viene
  **cifrada** y no trivializa la identificación; y (2) el lenguaje explícito **está confinado a
  `sanity_strong_attack`**, así que la compuerta de contenido cubre un solo banco.
  **Y el Principio T.H.I.N.K. del canon resultó ser el manual del addon** (ALTERNATE.md §9): las
  cinco letras mapean una a una sobre mecánicas que ya estaban diseñadas —**HINDER es literalmente la
  frase del `about.txt` sobre ralentizarlo 15 s**, y el *"if safe to do so"* de NEUTRALIZE es la
  ventana de rezo—. De ahí salen los dos tiers de contenido sin inventar nada, porque **la propia
  cinta muestra la diapositiva corrupta y después la corrige**. Abre tres pendientes: falta grabar la
  K canónica completa, y *"IDENTIFY the class type"* es un segundo bucle de identificación sin
  diseñar.
  **Las CUATRO clases quedaron escritas** (ALTERNATE.md §11, taxonomía del autor): Doppelgänger,
  Unspeakable, Flawed Impersonator y Tulpa — **los cuatro hacen M.A.D.**, la clase dice *cómo se
  acerca*. Tres consecuencias: (1) **lo de los flexes estaba mal planteado y se invierte** — el tell
  del Doppelgänger es *expresión fija y parpadeo incorrecto*, o sea que los **cero flexes de Jeff SON
  el tell**, y el del Flawed Impersonator son proporciones imposibles, que se hacen con
  `ManipulateBoneScale` sobre los 53 huesos ValveBiped; ninguna de las dos pedía morphs, y cae la
  advertencia de que un playermodel sin flexes rompía la mecánica; (2) **cada pieza ya diseñada
  pertenece a una clase** — la aparición con `preacherwhispers` es Tipo 3 (*The Preacher* lo es), la
  posesión de TV y pantallas es **cómo se desplaza un Tulpa** y no un truco, y *"mata directamente"*
  es Tipo 2; (3) **la tarjeta T.H.I.N.K. lista tres clases y hay cuatro** — no es error del canon (la
  cinta admite información incompleta) sino **una escena**: la clase que el manual no menciona es la
  única que viaja por pantallas, o sea la única que puede alcanzarte **dentro del camión**.
  Y el espejo maldito ya tiene el feed en vivo (`DrawMirrorView`), así que la segunda superficie del
  Tulpa no necesita código nuevo.
  **VERIFICADO CONTRA LA BASE (2026-08-05, §3.3-§3.4):** la invisibilidad **ya existe y no hace falta
  HIM** — `terminator_nextbot/wraithcloaking.lua`, 202 líneas, se enciende con `ENT.IsWraith = true`,
  y **el "cuándo" es un punto de extensión declarado** (`ENT.wraithTerm_CloakDecidingTask`, `:23`):
  el Alternate no escribe el cloak, escribe ese override. De paso **se cae una reserva propia**: yo
  había marcado `$allowdiffusemodulation 0` del `.vmt` de Jeff como riesgo para el fade, y la base no
  usa `SetColor` sino **`SetMaterial`**, así que la bandera no interviene — marqué un riesgo contra
  una técnica que la base no usa. Sin medir queda el efecto de `FL_NOTARGET` mientras está
  encubierto: **es la misma bandera de la trampa de NEAD** (§19.5). Y apareció el patrón que piden
  las posesiones: HIM usa **una tabla de props con probabilidad por prop**
  (`["homeless_camera"] = { defChance = 90, func = … }`), que es exactamente la forma del 30 % de la
  TV y el 30 % de las pantallas.
  **PENDIENTE DEL AUTOR — audio que todavía no existe:** la voz del **Tipo 4** (otro registro,
  susurro/teléfono, palabras inteligibles pero extrañas), la **señal musical** que acompaña su
  posesión de pantallas —**el Ave María de Bach/Gounod por Alessandro Moreschi**, 1902-1904, dominio
  público, *bajando una transferencia limpia y no un remaster*— y la **K canónica** de T.H.I.N.K.
  La señal musical **es el temporizador de la ventana de escape del camión**, así que su duración es
  una decisión de diseño y no de estética.
  **Diseño abierto y escrito: [docs/ALTERNATE.md](docs/ALTERNATE.md)** (2026-08-04). Tiene banco de
  audio propio (34 `.ogg`, duraciones medidas), modelo elegido y desempacado
  (`Jeff the Hunter`, WSID `806714233`) y los seis rostros de la TV ya derivados a
  `materials/phantasmagoria/alternate/`. **El gameplay loop está ratificado por el autor**: no se
  mata, se **degrada** —crucifijo y balas cambian su estado, no su vida— y la victoria es **llegar al
  camión**. Lo que falta antes de escribir Lua: el `.vmt` propio (el del Workshop trae
  `$allowdiffusemodulation 0` y `$Selfillum 1`, los dos en contra del "modelo oscuro"),
  **cómo entra al juego** (no puede salir del sorteo normal), y **qué le dice el libro de evidencias**
  a un fantasma que no es ninguno de los 30. **Crédito del modelo RESUELTO** (2026-08-04): autor
  **SpongePierre** sobre el Hunter de L4D2 de Valve, y el ítem del Workshop es un **reupload** de
  Foxy — ya está en [docs/CREDITOS.md](docs/CREDITOS.md). Salió de leer la descripción de la página:
  el campo `creator` de la API de Steam es **el subidor**, no el autor.
- **El ritual de vuelta** del destierro: qué es y qué hace falta para ejecutarlo.
- **Las posesiones malditas: son 7 y tenemos 1.** Documentadas con sus mecánicas y costes de cordura
  en [docs/EQUIPAMIENTO.md](docs/EQUIPAMIENTO.md) §4. Sólo la **Voodoo Doll** tiene modelo; el
  **Summoning Circle** es armable hoy con las velas + el encendedor que ya están en disco, y es el
  candidato natural para el primero. Faltan modelo para Ouija, Espejo, Caja de Música, Pata de Mono
  y Tarot.
- **El detector de cuartos no va a ser perfecto** en mapas de GMod, que no fueron hechos para esto.
  Por eso hay toolgun manual y por eso §14.5 define qué pasa cuando no hay mapeo: degradar, nunca
  romper.
- **El clima**: se integra con **StormFox 2** en vez de reimplementarse (§15). Su API está verificada
  **contra el `.gma` instalado**, no sólo contra el repo — el addon está desempacado en
  `dev/other/stormfox 2/` (2026-08-02). Falta escribir el mapeo y el camino propio para quien no lo
  tenga; §15.2 ya anota las **cuatro trampas** que salieron de leer los cuerpos (`GetCurrent`
  devuelve tabla, la nieve es lluvia bajo −2 °C, `GetRainAmount` da 0 nevando, `Temperature.Get`
  crashea con un tipo inválido). **gWeather y Simple Weather sin investigar.**
- **Los tiers de equipamiento** (§16): documentados, sin implementar. Va un tier por equipo en la v1.
- **Cuántos PHANTOM aguanta un servidor.** La base corre en coroutines presupuestadas
  (`ENT.CoroutineThresh`) pero nunca se midió.

---

## Advertencia que vale para todo el proyecto

**Casi nada de lo escrito se ejerció en juego** — la excepción es la entidad mínima, cerrada en tres
corridas el 2026-08-05. Todo lo demás sigue siendo lectura. Los documentos marcan **[verificado]**
cuando algo se leyó en el código y se auditó, y **[lectura]** cuando se leyó una sola vez. Ninguna de
las dos marcas significa "funciona": significan "el código dice esto".

**Y la primera corrida mostró para qué sirve la distinción.** Las cuatro filas del fantasma salieron
verdes a la primera: la lectura de la base **era buena**. Los cuatro defectos salieron todos de la
parte que ningún documento cubría — **lo que yo agregué encima**, y cada uno por medir un escenario y
escribir sobre otro: un aviso que predijo el futuro desde un instante, un marcador de exteriores
probado en un interior, un límite de 255 bytes que descarta en vez de truncar, y un texto calibrado a
4 m mirado a 1,3 m. **La lectura del tercero aguantó; lo que no aguantó fue suponer el contexto de
uso.**
