# HANDOFF — **DOS FRENTES EN UN CHAT**: la cordura (**B2 escrita, sin correr** · **C** el gatillo) y el **hunt directo** (12 filas listas)

**Fecha:** 2026-08-20 · **Repo:** `phantasmagoria` · **Autor:** chileno, escribirle de **tú** (sin voseo)

**Frente 1 — la cordura.** B1 **cerrada** ([`HANDOFF_cordura_b1.md`](HANDOFF_cordura_b1.md), corridas
`dev/CORRIDA_cordura_b1_r1.md` · `_r2.md` · `_r3.md`, CHANGELOG **(61)(62)(63)(65)**).
**B2 ESCRITA el 2026-08-20 y SIN CORRER EN JUEGO** — CHANGELOG **(66)**, planilla
`dev/checks/phantasmagoria-cordura-b2.html` (11 filas).
**Frente 2 — el hunt directo.** r1: 4 pasa · 0 falla · 10 sin correr (`dev/CORRIDA_hunt_directo_r1.md`,
CHANGELOG **(64)**). **La planilla r2 ya está escrita**: `dev/checks/phantasmagoria-hunt-directo-r2.html`,
**12 filas para correr** (13 menos la 03, que el autor declaró parcial).
**Diseño:** `docs/PHANTOM_Phasmophobia_Diseno.md` **§19** (cordura), **§18** (el hunt), **§21** (los
eventos) y **§5.5** (nueva: cómo se mata a un fantasma).

Pensado para retomar desde un chat limpio, sin contexto previo.

---

## 0. ⚠⚠⚠ Lo que hay que hacer, en orden, y por qué

**Todo lo que sigue son CORRIDAS EN JUEGO, salvo C.** Las dos tajadas de código están escritas y los
instrumentos offline están verdes — y ninguno de ellos ve el juego.

| | qué | cuesta |
|---|---|---|
| **1** | **Correr la planilla de B2** (`phantasmagoria-cordura-b2.html`, 11 filas) | una sesión; la fila **02** pide armar una escena con un prop |
| **2** | **Correr la r2 del hunt directo** (`phantasmagoria-hunt-directo-r2.html`, 12 filas) | no depende de nada de la cordura |
| **3** | **Escribir C**, el gatillo — **va sola, con su propia planilla** | es la única que todavía es código |

El orden entre 1 y 2 es indistinto: **no se tocan**. B2 tocó `server_events.lua`, `ghost_flags.lua`,
`phantasmagoria_sanity.lua` y `phantasmagoria_data.lua`; el hunt directo vive en `server_hunt.lua`,
`server.lua` y `server_stuck.lua`. **C es donde las dos cosas se encuentran de verdad.**

### ⚠⚠⚠ La regla que sigue vigente: **C no puede borrar `phantasmagoria_hunt`**

En la tabla de tajadas, C figura como *«jubila `phantasmagoria_hunt`»*. **Tomado literal rompe casi
todas las filas de la r2 del hunt**, que prenden el hunt con ese comando. **C deja de DEPENDER de él
como gatillo, pero el comando sigue existiendo como override manual declarado.** *Un andamio que
además es el instrumento de otra planilla no se jubila: se degrada a instrumento.* Y si algún día se
saca, se saca **después** de que esas filas hayan cerrado.


---

## 1. Dónde quedó todo, en una tabla

| | qué es | estado |
|---|---|---|
| **A** el tipo | asignarlo, networkearlo, forzarlo | **CERRADA en juego** (`server_type.lua`) |
| **B1** la cordura | la variable, la presencia, la recuperación, los instrumentos | **CERRADA.** r3: 5 pasa · 0 falla · 1 sin correr |
| **B2** los eventos | el tercer retorno `pos` en los ocho `EV.*` + la sub-tabla `sanity` | **ESCRITA el 2026-08-20, SIN CORRER EN JUEGO.** Planilla de 11 filas lista ← **empezar por acá** |
| **C** el gatillo | cordura bajo el `hunt.threshold` **del tipo**; degrada `phantasmagoria_hunt` a instrumento | **sin empezar** — es lo único que todavía es código |
| **hunt directo** | cómo persigue el fantasma (`server_hunt.lua`) | r1: 4 pasa · 0 falla · 10 sin correr. **Planilla r2 escrita, 12 filas listas** |

**Lo único que B1 dejó sin cerrar** son dos medias filas, y ninguna bloquea a B2:

- **fila 10** de `phantasmagoria-cordura-b1.html` — el desglose de la sesión entera. Cuesta un
  `phantasmagoria_cordura_reset`, jugar un rato y una lectura al final, más
  `python dev/auditar_puerta_cordura.py lua` y su `--control`.
- **fila 03** — el NETO de 10-20 min. Está marcada PASA por criterio del autor pero **sin número**, y
  la r3 descubrió que corrió con `regendelay` en 30 y no en 45. **Se vuelve a medir después de B2**,
  que es la que trae la mitad de drenaje que falta: medirla antes es medir media cosa.

---

## 2. ⚠⚠⚠ Antes de tocar una línea: la vuelta a fábrica

```
phantasmagoria_cordura_fabrica --decir
```

Las **30** convars del bloque son `FCVAR_ARCHIVE` y quedan guardadas en la máquina del que prueba.
La r1 perdió dos perillas de **encendido** (catálogo nº 91) y la r3 llegó con
`phantasmagoria_sanity_regendelay` en **30** contra los **45** del diseño, movida en un A/B de la r2.

⚠⚠ **Eran 24 hasta B2, y el número ya no se escribe: se deriva.** B2 agregó cinco perillas de cordura
**en otro archivo** (`server_events.lua`), y con la lista local que tenía B1 habrían quedado fuera de
la vuelta a fábrica — el defecto de la r3, pero peor, porque ni siquiera saldrían en el listado que lo
delata. Hoy el comando enumera un **registro compartido** (`PHANTASMAGORIA.PerillasCordura`), creado
con `or {}` en las dos puntas para que el orden de carga que decide el engine no pueda romperlo.
**Si el comando dice menos de 30, es que un archivo no cargó.**

**Con `--decir` sólo informa; sin él, restituye y dice qué movió.** Leer *antes* de restituir es la
mitad que importa: si la corrida anterior midió con esos valores, después ya no se puede saber.

> La lección que dejó, y vale para el próximo bloque: *cuando la defensa contra un modo de falla es
> una lista para pegar a mano, cubre los casos que estaban en la lista el día que se escribió.* Las
> ocho líneas de la r1 eran todas de encendido, y **una perilla de encendido en 0 se ve en el reporte;
> un retardo movido no** — el reporte imprime `30` con la misma cara que `45`.

---

## 3. B2 — **ESCRITA. Lo que falta es correrla.**

### 3.1 Qué entró, y en qué archivo

| pieza | dónde |
|---|---|
| el tercer retorno `epi` en los **ocho** `EV.*` | `server_events.lua` |
| la **pasada única** (`cobrarCordura`), el radio, la meseta, el tope y el tope de objetos | `server_events.lua` |
| los ocho costos (`san`) y sus ids literales (`sanCausa`) en la tabla canónica `CATS` | `server_events.lua` |
| la fuente continua `presencia_tipo` (el rasgo del Phantom), **registrada inactiva** | `server_events.lua` |
| la sub-tabla `sanity` (Oni `mult=2`, Yurei `per.door=15`, Phantom `presence=0.5`) + su guarda | `ghost_flags.lua` |
| la tabla canónica de las **seis clases de luz** y `LuzEncendida` (tri-estado) | `lua/phantasmagoria/luces.lua` **(nuevo)** |
| la lectura de luz de **tres estados**, la causa `oscuridad_ciega`, `ciegamul`, el registro compartido de perillas | `phantasmagoria_sanity.lua` |
| la columna de `luces.lua` en la guarda del cargador | `phantasmagoria_data.lua` |

### 3.2 ⚠⚠ Lo que hay que leer ANTES de correr la planilla

**Dos cosas salieron de escribir el bloque, no de correrlo, y las dos piden medición** — están en el
CHANGELOG **(66)** y en §19.8.4 del diseño:

1. **El tope de 6 % hacía imposible el 15 % del Yurei.** El techo pasó a ser
   `max( tope, el mayor costo individual )`. ⚠ **Es una lectura mía de dos números del diseño que se
   contradicen, no una decisión tuya**: se revierte sacando un `math.max`, y el reporte cuenta aparte
   las veces que el piso levantó el techo. Lo mide la fila **06**.
2. **La lectura de la luz tenía dos estados donde hay tres.** ⚠ **La perilla nueva
   `phantasmagoria_sanity_ciegamul` nace en 1,5 — el mismo número de antes — así que B2 NO mueve el
   gameplay.** Lo mide la fila **08**.

### 3.3 ⚠ Las perillas de la cordura ya no son 24: son **30**

B2 agregó cinco en `server_events.lua` (`sanrad`, `sanmeseta`, `santope`, `sanobjetos`, `sanpresrad`)
y una en el módulo (`ciegamul`). `phantasmagoria_cordura_fabrica` las enumera de un **registro
compartido** (`PHANTASMAGORIA.PerillasCordura`) y no de una lista pegada a mano: **si alguna vez dice
menos de 30, es que un archivo no cargó**.

### 3.4 ⚠⚠ La fila 02 es el bloque entero, y pide armar una escena

Las demás filas se cumplen igual con la hipótesis vieja — el epicentro de `sound` **es** el fantasma,
así que su verde no discrimina nada. La 02 es la única que separa *«la esfera cuelga del evento»* de
*«la esfera cuelga del fantasma»*: un `prop_physics` **solo** a ~300 u del fantasma, y vos parado
**en cada uno de los dos**. La planilla lo explica con la banda declarada.

### 3.5 Lo que B2 **no** hizo, y está declarado

- **La oscuridad no modula los eventos.** Aplicárselo movería el tope de 6 % a 9 % sin que nadie lo
  haya decidido. Frontera declarada: es una línea y una decisión tuya, no un descubrimiento.
- **`door` cobra por INTENTADA**, y el efecto se confirma 0,25 s después. Esperar el veredicto
  significaría cobrar dentro de un timer, o sea fuera de la pasada única. La bitácora imprime
  `door SIN EFECTO` cuando pasa, así que el caso es **contable**.
- **El rasgo del Phantom no tiene sujeto**: pide manifestación y §22 no está escrito.
  `PHANTASMAGORIA.EstaManifestado` es la costura, y la fila **07** mide que la fuente lo **diga**.


## 4. C — el gatillo, y lo que DEGRADA ( no jubila )

Cordura por debajo del `hunt.threshold` **del tipo** (`lua/phantasmagoria/ghost_types.lua`: el Spirit
en 50, el Demon en 70, y los que traen `thresholdLow`/`thresholdHigh` sortean en ese rango). Cuando
entre, **`phantasmagoria_hunt` deja de ser el gatillo** y pasa a ser lo que siempre dijo su ayuda: un
andamio.

⚠⚠⚠ **PERO NO SE BORRA — ver §0.** Nueve de las diez filas pendientes del frente 2 prenden el hunt
**con ese comando**. *Un andamio que además es el instrumento de otra planilla no se jubila: se
degrada a instrumento.*

### ⚠⚠⚠ La regla de §19.9.1, que no es un detalle de implementación

**Promedio en gamemode; CICLADO entre los vivos en sandbox — y los muertos FUERA del promedio.**
Si los muertos cuentan, **el primer muerto sube el promedio y protege a los vivos**, que es lo
contrario de lo que la partida quiere hacer.

### ⚠⚠ Y hay una regla del taller que muerde justo acá

**No meter el gatillo en el mismo bloque que otra cosa.** Es lo que B1 evitó a propósito: con el
gatillo adentro, un rojo tendría **dos causas posibles** —la cordura o el gate— y este taller ya pagó
por eso. C va sola, con su planilla.

⚠ Otra sesión reescribió **cómo persigue** el fantasma en `server_hunt.lua`, `server.lua` y
`server_stuck.lua`. B1 no los tocó a propósito; **C es donde las dos cosas se encuentran**. Leer el
`CHANGELOG` de esa sesión antes de escribir el gatillo.

---

## 4bis. FRENTE 2 — el hunt directo: **la planilla r2 está escrita, 12 filas para correr**

Bloque: `lua/entities/terminator_nextbot_phantom/server_hunt.lua` + tres enganches. Commits `f78a0ae`,
`d60dc5a` y `9b19b5c`. Detalle de la r1 en **`dev/CORRIDA_hunt_directo_r1.md`**.
**Planilla: `dev/checks/phantasmagoria-hunt-directo-r2.html`** (13 filas, fuera de git).

**El veredicto de gameplay ya está dado**, y no lo mide ninguna fila — textual del autor: *«el hunt
directo probándolo ingame está bien como gameplay, el bot hace lo que se supone que debe hacer»*.

La r2 ya trae lo que a la r1 le faltaba: la **banda de distancia** declarada en las filas 01 y 02, el
criterio de **conteo con N declarado** (10 spawns por rama) para el `chanceNeeded`, y **dos filas
nuevas** para los dos arreglos que salieron de *leer* la r1 y nunca se corrieron en juego — el perro
guardián que acusaba a dos mecanismos apagados (fila **08**) y el `phantom_huntCutFor` que se perdía
después de un A/B (fila **07**).

### 4bis.1 ⚠⚠ Las DOS preguntas del autor, **CONTESTADAS el 2026-08-20**

1. **¿El rescate del perro guardián tiene que existir en calma?** → **SÍ, se queda en calma**, con el
   mensaje arreglado. La fila **08** de la r2 es la que lo mide, y queda tal cual.
2. **La fila 04 de la r1 (el A/B con el fantasma HERIDO a más de 1400 u)** → **NO se corre.** Queda
   apoyada en el mecanismo determinista y anotada como **PARCIAL**. Es la fila **03** de la r2, y ya
   está marcada así. El motivo es del autor y abre un pendiente propio — ver §5.1.

⚠ **Entonces son 12 filas para correr, no 13.**

### 4bis.2 Fronteras que la r1 no movió, y ninguna fila se acreditó

La cordura como disparador (**es la tajada C**), el evento de mirar fijo del Diseño §10, el tope de la
órbita contra `sightdist`, `interceptIfWeCan`, el flanqueo por distancia (**ninguna fila lo
ejercita**: `flank de cerca 0` en las tres lecturas), y los 30 tipos sin poblar (`ability.onCatch`
enganchado, no poblado).

Y dos que siguen sin explicar: el `render se dibuja / la politica pide INVISIBLE / !! NO COINCIDEN` de
`server_cloak.lua`, y `movement_perch` + `movement_biginertia` activas a la vez.

## 5. Lo que sigue sin sujeto, y hay que saberlo antes de leer un cero

- **La zona segura de §18.1 NO EXISTE en código.** Cero `terminator_blocktarget`, ninguna entidad
  camión. Está registrada como fuente continua **INACTIVA que dice por qué lo está**, con
  `PHANTASMAGORIA.InSafeZone` como costura.
- **Las MANIFESTACIONES de §22 no existen**, y por eso el rasgo continuo del Phantom
  (`presencia_tipo`) se registró **inactivo diciendo por qué**. `PHANTASMAGORIA.EstaManifestado` es su
  costura. La fila **07** de la planilla de B2 mide que la fuente lo **diga**, no que drene.
- **El destierro de §5.4 no existe**; el único desenlace es **matar** al fantasma.
- ✅ **El punto ciego de la luz: CERRADO por B2 en el sentido que importaba.** No se le dio getter a
  las cuatro clases que no lo tienen —no se puede sin asumir APIs del engine— sino que se dejó de
  **fingir** que la ausencia de lectura era una lectura: `sin_lectura` es un tercer estado con renglón
  y perilla propios. **El ×1,5 sigue saliendo igual (`ciegamul` nace en 1,5), pero ahora es
  atribuible.** ⚠ Sigue siendo cierto que un mapa de iluminación horneada se lee como no-legible:
  §19.9.2 lo aceptó por escrito, y ahora tiene denominador.
- **El medidor de actividad (§19.3)** sigue sin diseñar.

### 5.1 ⚠⚠⚠ PENDIENTE NUEVO DEL AUTOR: **cómo se MATA a un fantasma**

> *«tengo por pendiente evitar que el fantasma muera o sea herido por armas de fuego, explosivos, melee
> (crush o cut) y al ser atacado con props phys como ragdolls (yo lo logro matar directamente y fácil
> tirándole un ragdoll), la forma de "matar" a un ghost tiene que ser distinto a eso. (Falta que
> atacarlo en melee no le haga daño ni le haga salir sangre... visceral blood puede tener la culpa)»*

**Está escrito en el diseño, §5.5**, con las cuatro preguntas que hay que contestar antes de tocar una
línea. Las tres razones por las que **no** es un `if` en `OnTakeDamage`:

1. **Matar al fantasma es hoy el único desenlace del addon** (el destierro no existe) y la vía de
   cordura `fantasma muerto` cuelga de `OnNPCKilled`. Cerrarle el daño sin poner otra puerta deja una
   partida sin final y una vía de cordura sin gatillo.
2. **El daño llega por cuatro caminos**: `OnTakeDamage` de la base, `DMG_CRUSH` del motor (el ragdoll),
   `DMG_CLUB` del melee de HL2, y la cadena propia de ARC9. *Una inmunidad escrita en una de las cuatro
   puertas se lee como una inmunidad.*
3. **La sangre no es del daño, es del consumidor.** Si se cierra el daño primero, la sangre deja de
   salir **por accidente** y nadie sabrá cuál de los dos era el mecanismo.

⚠ **Y no entra en la misma tanda que C**: con el gatillo adentro, un rojo tendría dos causas posibles.

## 6. Los comandos de la cordura

| comando | qué hace |
|---|---|
| `phantasmagoria_cordura` | **el reporte**: valor, desglose por causa, fuentes, perillas y tasas |
| `phantasmagoria_cordura_reset` | valor al inicial, desglose y contadores en cero. **Antes de cada fila** |
| `phantasmagoria_cordura_fabrica [--decir]` | **las 30** perillas a fábrica, **diciendo cuáles estaban movidas**. El total es derivado del registro |
| `phantasmagoria_cordura_set <0..100> [nick]` | **ANDAMIO**. Se anota como causa `andamio consola` a propósito |
| `phantasmagoria_cordura_med <1\|2\|3>` | **ANDAMIO**. Una dosis sin pasar por Cargo |
| `phantasmagoria_cordura_drenar <n> [causa]` | **ANDAMIO**. Dispara la forma **plana**. Default `evento_sound` |

Y los del motor de eventos, que B2 volvió parte del instrumental de la cordura:

| comando | qué hace |
|---|---|
| `phantasmagoria_ghost_event <categoria>` | **fuerza** una de las ocho, **sin mover el reloj**. Es lo que hace correr la planilla sin depender del sorteo |
| `phantasmagoria_ghost_events [reset]` | el reporte del motor. Al final trae el bloque **`CORDURA de los eventos`**: pasadas, cobros, pedido, recorte, piso, y **`sin donde`** |
| `phantasmagoria_ghost_type <key>` | **ANDAMIO**. Fuerza el tipo. ⚠ **Sobrevive al respawn a propósito**: si no lo sacás, la ronda siguiente mide un Oni creyendo que mide un sorteo |

⚠ Un comando por línea: **la consola de Source corta en 255 bytes y no avisa**.

⚠⚠⚠ **Y tampoco te entrega el texto entero: `CCommand::Tokenize` parte en `{ } ( ) ' :`**, así que
esos caracteres llegan como **tokens propios**. Le costó la fila 04 a la r2, y el id `evento:sound`
era **inalcanzable desde la consola desde el día que se escribió**. **Ningún id que B2 agregue puede
llevar un carácter del break set** — va guion bajo. Hoy hay **tres** controles:
`python dev/auditar_ids_tipeables.py lua` (21 causas, 0 rotas), el del arranque del módulo, y la
guarda ( 3c ) de `server_events.lua`, que verifica los ocho `sanCausa`. Los tres miden la
**propiedad**, no el arreglo.

---

## 7. Los instrumentos offline. Todos verdes el 2026-08-20.

```
find lua -name '*.lua' -print0 | xargs -0 python dev/luacheck_gmod.py
python dev/parsear_sintaxis_glua.py lua
python dev/auditar_returns_de_hooks.py lua
python dev/rutas_de_sonido.py
python dev/auditar_puerta_cordura.py lua      # y --control
python dev/auditar_ids_tipeables.py lua       # y --control
```

⚠ `luacheck_gmod.py` **sin argumentos revisa cero archivos y sale 0** — verde sin medir. Va siempre
con el `find ... | xargs`.

⚠ Y el nuevo de B2, que es el que más cubre:

```
python dev/cordura_b2_offline.py            # y --control
```

Corre el **código real** en un intérprete de Lua: extrae del archivo el cuerpo de `factorSanidad` y
`normalizarEpicentros` y ejecuta `ghost_flags.lua` entero con stubs. **No re-implementa nada** — *un
control que copia el cuerpo mide su copia*. Su `--control` **sabotea** el archivo de rasgos de tres
maneras y exige que la guarda hable de las tres. Existe porque las tres piezas que cubre fallan **en
silencio**: en juego las tres se ven como «drena poco».

⚠⚠⚠ **LA EXPECTATIVA QUE ESTE HANDOFF TENÍA SOBRE `auditar_puerta_cordura.py` ESTABA MAL ESCRITA, Y LA
CORRECCIÓN VALE SOLA.** Decía: *«al cerrar B2, mirar ese renglón y comprobar que dice ocho»*, sobre el
renglón «usan la API pública». **Al cerrarla dice 1, y el 1 es lo correcto**: §19.8.4 exige **una sola
pasada**, o sea un solo llamador con una sola llamada. La expectativa contaba **sitios de llamada**
para contestar una pregunta que es sobre **renglones del desglose** — y con la arquitectura correcta
ese renglón iba a decir 1 **para siempre**.

> *Un criterio numérico heredado de un handoff no es un criterio: hay que preguntarle **qué cuenta**
> antes de creerle el número.*

Se le agregó al auditor la mitad que sí contesta: que cada uno de los ocho **ids de causa** aparezca,
literal, fuera de la puerta. **Hoy dice `CAUSAS DE EVENTO SIN PRODUCTOR: 0 de 8`.** Y por eso los ids
se escriben **literales** en `CATS` en vez de construirse con `"evento_" .. key`: *un identificador que
sólo existe en runtime es invisible para todo instrumento que mida el código*.

Los tres de planilla viven en el `dev/` **del workspace**, que **no está en git**:

```
python dev/auditar_planilla.py <planilla>
python dev/verificar_citas_de_planilla.py <planilla> --addon phantasmagoria --control
python dev/parsear_cmds_planilla.py <planilla>
```

> ⚠ `parsear_cmds_planilla.py` sólo valida los `lua_run` de un botón. Sobre las planillas de la
> cordura da **0**, y eso es legítimo: es un barrido **sin sujeto**, no un barrido ciego.

---

## 8. ⚠⚠⚠ Git, y quién trabaja qué

**El índice de git es compartido entre sesiones.** Stagear rutas explícitas **no alcanza**: entre el
`git add` y el `git commit` hay una ventana, y si otra sesión commitea ahí, se lleva lo tuyo. Lo que
protege es **`git commit -F- -- <rutas>`**, que no deja ventana. El tell de que ya pasó es que **los
archivos que editaste dejan de aparecer en `git status`**.

⚠ **Un archivo NUEVO no lo agarra ese comando** (`pathspec did not match any file(s) known to git`).
Para ésos va `git add -N <nuevos> && git commit -F- -- <todas las rutas>` **encadenado en una sola
invocación**: el `-N` es intent-to-add y no stagea contenido, y el pathspec del `commit` sigue siendo
lo que limita qué entra.

### El reparto, al 2026-08-20

| repo | de quién es |
|---|---|
| **`phantasmagoria`** | **de este chat** — la cordura y el hunt directo, los dos frentes juntos |
| `corpus` · `corpus-cargo` | **de otra sesión**: la UI de Cargo (#74 / #72). ⚠ **No commitear ni pushear ahí** |

⚠ `lua/autorun/client/phantasmagoria_eq_check.lua` quedó modificado por una sesión anterior y sigue
sin commitear: **no stagearlo** hasta saber de quién es.

⚠⚠ **Y este arco chocó tres veces por numeración**, no por archivos: la entrada de CHANGELOG **(65)**
nació (64) y las dos del catálogo de memoria nacieron 107 y quedaron 112. *Cuando dos escrituras
chocan, la que se mueve es la que todavía no tiene lectores.* Con los dos frentes en un solo chat,
ese choque debería desaparecer dentro de `phantasmagoria`.
