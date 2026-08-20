# HANDOFF — el hunt directo: la escalera propia, la compuerta de tareas tácticas y el desenlace

**Fecha:** 2026-08-20 · **Repo:** `phantasmagoria` · **Commits:** `f78a0ae` (el bloque) y `d60dc5a`
(los dos defectos de la primera corrida)
**Planilla:** `dev/checks/phantasmagoria-hunt-directo-r1.html` — **14 filas**, artefacto en
<https://claude.ai/code/artifact/be72e4e8-82fe-4a4c-a128-1fdcfd884480>

> ⚠⚠⚠ **NADA DE ESTO SE CORRIÓ EN JUEGO.** Lo único que el autor ejerció fue el arranque del
> servidor: spawneó un fantasma, corrió `phantasmagoria_ghost_cerebro` y `phantasmagoria_ghost_where`,
> y de ahí salieron los dos defectos del §5. **La planilla está entera en *sin correr*.** El trabajo
> de la sesión que lea esto es correrla y cerrar el bloque.

> ⚠⚠ **HAY OTRA SESIÓN VIVA SOBRE ESTE MISMO REPO**, escribiendo la **cordura** (tajada B1,
> `dev/PROMPT_phantasmagoria_cordura_B1.txt`). No se toca nada de eso. Consecuencias operativas en
> el §8.

> Este documento está escrito para retomar **sin contexto previo**. Lo que decide la arquitectura y
> no hay que volver a discutir está en el §3. Antes de escribir o corregir un check, leer
> `memory/controles-que-premian-su-modo-de-falla.md` — está numerado hasta el **102** y las tres
> últimas salieron de este bloque.

---

## 1 · De dónde viene

Sale de una sesión de investigación del 2026-08-19/20 con **dos corridas del autor en juego** con
`term_debugtasks 1`. El traspaso original, con archivo y línea para todo, sigue siendo válido y está
en **`dev/PROMPT_phantasmagoria_hunt_directo.txt`** — no se re-averigua nada de sus §2 y §3.

Lo pedido, textual del autor al abrir:

> *«la idea del hunt es que no tome en cuenta ninguna logica asi, que si ve al jugador busque la
> posicion mas directa para atacarlo»*

y el alcance que puso él mismo:

> *«el NPC deberia ser capaz de perseguirte, perderte y seguir buscando en hunt»*

O sea: **perseguir, perder, buscar SÍ. Observar, acechar, campear, flanquear de lejos NO.**

---

## 2 · Qué se escribió

Un archivo nuevo, `lua/entities/terminator_nextbot_phantom/server_hunt.lua` (≈1.440 líneas,
comentado como el resto del addon), más **tres enganches** que viven en otros archivos:

| enganche | archivo | qué cuelga de ahí |
|---|---|---|
| `ENT:StartTask` | `server_stuck.lua` | la **compuerta** que desvía las tareas tácticas |
| `ENT:BehaveUpdate` | `server.lua` | el **contacto** y el **perro guardián** (`phantom_HuntTick`) |
| `phantom_SetHunting` | `server.lua` | el **corte de la tarea en curso** al prender/apagar el hunt |

**Cinco mecanismos, seis perillas — una por mecanismo** (catálogo nº 28: dos condiciones encendidas
a la vez es un criterio que se cumple a medias y se lee como cumplido). Todas `FCVAR_ARCHIVE`,
todas arrancan en 1, y el **0 devuelve el comportamiento de la base exacto, encadenando**:

| convar | qué apaga |
|---|---|
| `phantasmagoria_ghost_huntdirect` | la escalera propia de dos ramas + la compuerta |
| `phantasmagoria_ghost_truerange` | `GetWeaponRange` e `IsMeleeWeapon` vuelven a mentir |
| `phantasmagoria_ghost_fearless` | `EnemyIsLethalInMelee` vuelve a encadenar |
| `phantasmagoria_ghost_reachprops` | un prop vuelve a abortar el duelo |
| `phantasmagoria_ghost_reachdrop` | un pozo / el salto vuelven a abortarlo |
| `phantasmagoria_ghost_catch` | el desenlace |

Más dos números: `phantasmagoria_ghost_reach` (**64 u**, y es el **mismo** para el alcance de arma y
para la distancia del contacto — una constante que decide geometría tiene que existir una vez) y
`phantasmagoria_ghost_huntflank` (**400 u**, que es la frontera del propio `doFlank` de la base).

Y un campo sin perilla: `ENT.InformRadius = 0`, como HIM.

**El instrumento es `phantasmagoria_ghost_cerebro`.** Imprime las perillas, la escalera, la
compuerta con su reparto, el contacto, y **los contadores de los tres sitios de llamada**
(`vistas`, `ticks`, `cortes`) — porque un helper impecable que nadie llama es el código viejo con un
verde encima (catálogo nº 89).

---

## 3 · Lo que decide el bloque, y **no** hay que volver a discutir

### 3.1 · Las tareas NO se sacan del registro

La forma de HIM — reasignar `TaskList` entero con `DoCustomTasks` — es tentadora, está escrita en el
tercero (`him/.../server.lua:997`) y **está mal aquí**. Tres motivos, en orden de peso:

1. **`movement_watch` y `movement_stalkenemy` tienen una segunda vida y el diseño ya se la asignó.**
   Diseño §10 se las dio al estado **IDLE** — *«en phasmophobia hay un evento donde se te quedan
   mirando fijo como a 5-10 metros»*, palabras del autor. Sacarlas del registro las mata en **los
   dos** estados.
2. `TaskList` se arma **una sola vez** al spawnear (`taskoverride.lua:390`), así que no expresa
   «lista de hunt» contra «lista de calma».
3. Un `StartTask` a una tarea **no registrada** no da error: da un **zombi**. Entra igual en
   `m_ActiveTasks`, `IsTaskActive` dice que sí y el debug la imprime, pero `RunTask` la saltea
   porque no encuentra callbacks (`taskoverride.lua:39-40`). El bot se queda parado, **en
   silencio**, hasta que lo rescate `reallystuck_handler`.

Se cierran **por estado** (`phantom_Hunting`). La **fila 00** de la planilla es la que lo comprueba.

> **Si una sesión futura lee HIM y le parece obvio copiarlo, es esto.**

### 3.2 · Once puertas, no sesenta y cuatro

Hay **64** `StartTask` a las tareas que sobran, pero solo **11** viven dentro de tareas que en hunt
siguen corriendo. La compuerta va en el cuello único que ya era nuestro y **no** copiando cuerpos de
tareas de un tercero (catálogo nº 87: una copia de código ajeno conserva la propiedad de discriminar
mientras envejece).

Los once se leyeron **con su contexto** y los once hacen `TaskFail`/`TaskComplete` **antes** del
`StartTask`, así que el destino nunca está activo en el momento del desvío — que es la trampa de
`taskoverride.lua:167`. Igual hay **perro guardián**: 1,5 s sin ninguna `movement_*` activa y grita
con `ErrorNoHalt` además de rescatar. *«Se revisó» no es «no puede pasar».*

### 3.3 · La familia `data.Unreachable` no se disfraza

Cuatro de las once disparan porque el bot **no llega**. Mandarlas a `followenemy` sería un bucle de
un tick. Van a `movement_search` con los números que la base usa para su caso equivalente
(`searchWant 20`, radio 2000) — y **se cuentan aparte**: si el contador `search` del reporte sube
mucho, el problema es de **navmesh** y no de este bloque.

Lo mismo el vagabundeo y el caso «sin enemigo válido»: `movement_search` es la única de las tres
candidatas que **no puede fallar por falta de un punto** (su centro cae en cascada) y **no puede
reentrar cada frame**.

### 3.4 · El arma son **dos** funciones, no una

`GetWeaponRange` devuelve `math.huge` sin arma (`weapons.lua:1935`, *«our eyes have infinite
range»*), **y además** `IsMeleeWeapon` sale por `if not IsValid( wep ) then return false end`
**antes** de llegar a su propia regla de `range < 150`. Arreglar solo la primera **no cierra
`camp`**: deja `notMelee` en true, y un fantasma **herido** vuelve a campear con un 35 %.

Con las dos se cierran `camp` y `perch` en toda la base, y **se apaga solo** el error de Lua con
stack que el juego imprimió en la corrida 2b (`movement_perch ... i have a real weapon` sobre un bot
desarmado, `shared.lua:8201`). **Ese bug de la base no se parchea.**

### 3.5 · El desenlace es un paso nuestro, no los puños

Hasta este bloque **no había una sola línea en el addon que le hiciera daño al jugador** — los
únicos `TakeDamage` eran del fantasma contra sí mismo al caerse. No se prenden los puños porque
aunque `TERM_FISTS` estuviera en true, el puñetazo vive dentro de `movement_duelenemy_near`, que se
rinde a los 4-8 s y sale por el *«the bot isnt just gonna follow you around like a lobotimised
lemming»* de `:7932`.

Bifurca en `ability.onCatch` (Diseño §5.4) desde el día uno, con el hook público
`PhantasmagoriaGhostCatch` para vetarlo. ⚠ **`banish` no cae a `kill`**: grita que no está
implementada y no hace nada. *Un default plausible en el lugar de un mecanismo que no existe es un
verde sobre código que nadie escribió.*

---

## 4 · Cómo correr la planilla

**El orden importa y no es cosmético.**

1. **P0 primero, siempre.** Las seis perillas son `FCVAR_ARCHIVE`: están guardadas en la máquina del
   autor y una que quedó de un A/B viejo invalida todo lo que sigue sin decir nada (catálogo nº 91).
   La P0 también verifica los **tres sitios de llamada** — si `ticks` da 0, el contacto y el perro
   guardián están muertos y las filas 09 y 11 no se pueden correr.
2. **La fila 01 es el control positivo y de ella cuelgan las demás.** Casi todo lo que este bloque
   promete tiene forma de **ausencia** («ya no aparece `stalkenemy`», «ya no sale `camp`», «ya no
   aborta el duelo»), y **una ausencia sola nunca discrimina**: la cumple igual un mecanismo roto que
   nunca aparece (catálogo nº 93). Si la 01 no sale verde, las filas **02, 04 y 10** quedan **SIN
   CORRER**, no en verde.
3. **Toda fila que habla de una rama de la escalera declara su banda de distancia.** No es
   prolijidad: en esta misma investigación una predicción correcta se dio por refutada con un log
   tomado **casi entero a menos de 5 m**, donde la rama que se buscaba *no puede aparecer*. Las
   filas **01, 02 y 04** son de **30-40 m**; las **03, 06, 07, 09 y 12** son de **menos de 5 m**.
4. **Sin `god`.** Con `fearless 0`, `EnemyIsUnkillable` mira `HasGodMode()` y el bot **cambia de
   comportamiento** — lo que se mida así no es lo que juega el jugador. El reporte lo avisa solo. Y
   la fila 09 pide morirse, así que ahí `god` la invalida directamente.
5. **`SIN CORRER` es un estado legítimo.** Si la mitad de control positivo de una fila no se
   reprodujo, la fila **no pasa**: se marca sin correr y se dice por qué.

**La fila más probable de quedar sin correr es la 05** (el error de Lua con stack): no se puede
forzar, necesita que `movement_biginertia` se quede sin lugares. Está dicho de frente en la propia
fila, y el mecanismo lo cubre igual la 04.

---

## 5 · Lo que ya se rompió una vez, en el primer arranque

Las dos las encontró el autor apenas prendió el servidor, y las dos están arregladas en `d60dc5a`.
Se dejan escritas porque **las dos son de clase, no de tipeo**.

### 5.1 · El reporte se moría por leer `ENT` a runtime

```
server_hunt.lua:1217: attempt to index global 'ENT' (a nil value)
  1. unknown - server_hunt.lua:1217
   2. unknown - lua/includes/modules/concommand.lua:60
```

`ENT` **solo existe mientras el chunk del archivo de la entidad se ejecuta**; al terminar vuelve a
`nil`. `ENT.X = 1` arriba y las guardas del final del archivo son válidas — corren al cargar; el
mismo `ENT.X` dentro de un concommand corre después y revienta. *Las dos lecturas se escriben igual y
lo que decide es CUÁNDO se ejecuta la línea.*

⚠ **El síntoma fue peor que un error suelto:** murió justo **después** de imprimir las perillas, así
que la primera mitad del reporte se veía perfecta y se llevó puesto **todo el bloque por fantasma**
— que es el que trae los contadores. *Una salida vacía y una salida truncada se ven igual cuando lo
truncado es lo de abajo.*

**Instrumento nuevo: `dev/auditar_ent_a_runtime.py`.** Ninguno de los otros tres podía verlo (el
parser dice si **compila**, y esto compila). Censo sobre los 38 `.lua`: **1 aparición**, la del
defecto. Trae `--control` embebido porque **su primera versión dio verde sobre el archivo que el
juego acababa de reprobar**.

### 5.2 · Al matarte, el fantasma te hacía soltar las armas

Reporte del autor, con el mecanismo ya identificado por él: *«es parte del comportamiento normal del
terminator para poder tener armas de fuego que tomar»*. Exacto, y **no es de este addon**: es un hook
global del tercero, `autorun/server/terminator_weapon_dropper.lua` (encabezado: *«give the bot some
weapons plssss!»*), que escucha `DoPlayerDeath` y te **crea** hasta 6 armas nuevas en el piso.

La salida ya existía en el tercero y **había tres**. Se censaron los **otros** consumidores de cada
una antes de elegir:

| salida | otros consumidores | costo |
|---|---|---|
| `CanFindWeaponsOnTheGround` | 4, y uno muerde | `canGetWeapon` se sale con `{}` → el fantasma **dejaría de caminar hacia las armas**, que es una decisión escrita a propósito (el señuelo) |
| `terminator_playerdropweapons 0` | — | convar **global** del tercero y `FCVAR_ARCHIVE` |
| **`DontDropPrimary`** | **1**, e inerte acá | **cero** |

*Cuando un tercero ofrece tres puertas para lo mismo, la que sirve es la que tiene menos consumidores
del otro lado, no la que se llama parecido.*

**Cuelga de `phantasmagoria_ghost_pickup`**, no es un `true` fijo: es la misma decisión, y con
`pickup 1` el drop tiene que volver — que es lo que hace medible la **fila 12**.

---

## 6 · Qué hacer con los resultados

1. Volcar la corrida a **`dev/CORRIDA_hunt_directo_r1.md`**, con el mismo formato que las otras
   `CORRIDA_*.md` del repo: fila por fila, veredicto, y **la nota aunque la fila pase** — casi todo
   lo que se descubre tarde estaba escrito al costado de algo que había pasado.
2. **Escribir la entrada del CHANGELOG, que está PENDIENTE.** En `f78a0ae` y `d60dc5a` no se tocó
   `CHANGELOG.md` ni `ESTADO.md` a propósito: la sesión de la cordura los tenía abiertos, y editar el
   mismo archivo desde dos sesiones es la falla que ningún pathspec separa. La cordura ya consumió
   las entradas **(61)** y **(62)**, así que a este bloque le toca la **(63)** — pero **verificar el
   número antes de escribirlo**, que para eso está el `grep '^## ' CHANGELOG.md | head`.
3. Actualizar `ESTADO.md` con lo mismo, y con la misma precaución.

---

## 7 · Fronteras abiertas — para que ninguna fila se las acredite

- ⚠⚠⚠ **La cordura no es de este bloque.** El hunt lo sigue disparando `phantasmagoria_hunt`, que es
  **manual y provisorio**. Se está escribiendo en otra sesión (§19.8, tajada B1). Cuando exista va a
  llamar a `phantom_SetHunting` — que es la **puerta única** — y todo el hunt directo la sigue sin
  tocar una línea. **Ese es el contrato entre los dos bloques y es lo único que hay que respetar.**
- **El evento de mirar fijo (§10) tampoco se escribió.** Este bloque solo tenía que **no romperlo**,
  y eso es lo que mide la fila 00. ⚠ Ojo con leer esa fila como «el evento anda»: mide que las tareas
  **sigan registradas**, no que alguien las use.
- ⚠⚠ **El tope de la órbita del acecho contra `sightdist` sigue abierto** — es la fila 10. El
  fantasma puede acecharse hasta perderse solo (medido a 80 m, con `sightdist` en 3000 u ≈ 75 m). En
  hunt ya no puede pasar porque el acecho no arranca, **pero el día que el acecho viva en el estado
  IDLE ese tope va a tener que existir**.
- **`interceptIfWeCan` se dejó fuera de la escalera propia a propósito.** Adelantarse a dónde vas a
  estar es defendible para un hunt y **no está pedido**; meterlo agrega `movement_intercept`, que es
  otra tarea con vida propia.
- ⚠ **El flanqueo se acepta por DISTANCIA, no por tarea**, y **ninguna fila lo ejercita sola**: hoy,
  en hunt, ningún camino llega a pedir un flanqueo (los seis sitios que lo inician viven dentro de
  `watch`, `stalkenemy` y `camp`, que están cerradas). El corte de 400 u está como **red**, no como
  mecanismo medido.
- **Los 30 tipos siguen sin poblar.** `ability.onCatch` quedó **enganchado, no poblado**: hoy ningún
  tipo trae `ability`, así que todos matan. La fila 09 prueba el **gancho**.
- **Sin explicar, visto en la salida del primer arranque y NO tocado:** `render se dibuja / la
  politica pide INVISIBLE / !! NO COINCIDEN` a los 4,6 s de spawnear (es de `server_cloak.lua`), y un
  Kormos con `movement_perch` **y** `movement_biginertia` activas a la vez. Lo segundo es la misma
  familia del bug de la base que destapó el §2.6 del prompt. Ninguna de las dos es de este bloque.

---

## 8 · Reglas de la casa

- El autor es **chileno**: escribirle de **tú**, sin voseo. Vale también para este archivo, que lo
  lee él.
- ⚠⚠⚠ **HAY OTRA SESIÓN VIVA SOBRE ESTE REPO, Y `git add <ruta>` NO ALCANZA. MEDIDO ACÁ, EN ESTE
  MISMO BLOQUE.** La regla vieja era «nunca `git add -A`, stagear rutas explícitas». Se cumplió al
  pie de la letra y **falló igual**: el commit `4e0859b`, que iba a llevar un solo archivo, se llevó
  **siete** — toda la tajada B1 de la cordura (`phantasmagoria_sanity.lua` con sus 1.636 líneas, su
  CORRIDA, su auditor, y las entradas (61) y (62) del CHANGELOG) bajo un mensaje que describe 292 de
  2.856 líneas.

  **El índice es de la CARPETA, no de la sesión.** Entre mi `git add` y mi `git commit` pasaron
  segundos, y en esa ventana la otra sesión stageó lo suyo; mi `commit` se llevó la unión. No hubo
  hook ni `commit.all`: fue la ventana. *Una precaución que se aplica en dos pasos tiene una ventana
  entre los dos pasos, y la ventana es el defecto.*

  **La receta endurecida, y es de un paso:**

  ```
  git commit -F - -- ruta/uno ruta/dos      # commitea SOLO esas rutas, ignorando el resto del indice
  ```

  Con `-- <rutas>` git arma el commit desde esas rutas y **no** desde lo que otro haya stageado. Y
  después, siempre: `git show --stat HEAD` y contar los archivos. El *tell* del defecto viejo era que
  un archivo tuyo **dejara de aparecer** en `git status`; el *tell* de éste es al revés — aparecen
  archivos ajenos en tu `--stat`, y **el número de archivos del commit no coincide con el que
  pediste**.
- Commits **sin** `Co-Authored-By`.
- **La base Terminator es de un tercero y no se toca.** Todo va en
  `lua/entities/terminator_nextbot_phantom/`.
- `dev/other/` está fuera de todo repo. `phantasmagoria/dev/` **sí** está en git; la planilla, en
  cambio, vive en el `dev/checks/` de la raíz del workspace, que **no** lo está.
- Antes de teorizar sobre un síntoma en juego, **leer el `console.log`**
  (`D:\Steam\steamapps\common\GarrysMod`).
- **La consola de Source trunca en 255 y el síntoma es un error de sintaxis de Lua.** Vale para
  cualquier `lua_run` de medición. La planilla mide el largo de sus propios comandos y lo imprime.
- **Si el juego contradice a los documentos, gana el juego.**
