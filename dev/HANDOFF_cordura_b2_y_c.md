# HANDOFF — **DOS FRENTES EN UN CHAT**: la cordura (**B2** los eventos · **C** el gatillo) y el **comportamiento del hunt directo**

**Fecha:** 2026-08-20 · **Repo:** `phantasmagoria` · **Autor:** chileno, escribirle de **tú** (sin voseo)

**Frente 1 — la cordura.** Lo anterior: [`HANDOFF_cordura_b1.md`](HANDOFF_cordura_b1.md). B1 **cerrada**.
Corridas `dev/CORRIDA_cordura_b1_r1.md` · `_r2.md` · `_r3.md`. CHANGELOG **(61) (62) (63) (65)**.
**Frente 2 — el hunt directo.** Handoff de origen: [`HANDOFF_phantasmagoria_hunt_directo.md`](HANDOFF_phantasmagoria_hunt_directo.md).
Corrida `dev/CORRIDA_hunt_directo_r1.md` — **4 pasa · 0 falla · 10 sin correr**. CHANGELOG **(64)**.
**Diseño:** `docs/PHANTOM_Phasmophobia_Diseno.md` **§19** (cordura), **§18** (el hunt) y **§21** (los eventos).

Pensado para retomar desde un chat limpio, sin contexto previo.

---

## 0. ⚠⚠⚠ Por qué los dos frentes van juntos, y dónde chocan

Hasta hoy fueron **dos sesiones paralelas** sobre el mismo repo: una escribió la cordura
(`phantasmagoria_sanity.lua`) y la otra reescribió **cómo persigue** el fantasma (`server_hunt.lua`,
`server.lua`, `server_stuck.lua`). Se evitaron a propósito. **A partir del próximo chat son una sola**,
por decisión del autor.

Eso saca un problema y mete otro.

**Lo que se gana:** ya no hay dos sesiones compitiendo por el índice de git de este repo, que fue lo
que en `4e0859b` se llevó 2.564 líneas ajenas adentro de un commit que no las nombraba.

### ⚠⚠⚠ Lo que hay que cuidar: **C no puede borrar `phantasmagoria_hunt`**

La tajada **C** hace que la cordura dispare el hunt, y en la tabla de tajadas eso figura como
*«jubila `phantasmagoria_hunt`»*. **Tomado literal, rompe diez filas del otro frente**: las 01, 02,
05, 06, 07, 08, 09, 11 y 12 de `phantasmagoria-hunt-directo-r1.html` prenden el hunt **con ese
comando**, y sin él ninguna se puede correr.

**La regla, entonces:** C deja de **depender** de `phantasmagoria_hunt` como gatillo, pero el comando
**sigue existiendo como override manual declarado**. *Un andamio que además es el instrumento de otra
planilla no se jubila: se degrada a instrumento.* Y si algún día se saca, se saca **después** de que
esas diez filas hayan cerrado, no antes.

### El orden que se sugiere, y por qué

1. **Las 10 filas del hunt directo primero.** No dependen de nada de la cordura, y **dos arreglos de
   esa sesión nunca se corrieron en juego** (§5.3): están esperando una pasada.
2. **B2 después.** Toca `server_events.lua`, que ninguno de los dos frentes tocó todavía.
3. **C al final**, que es donde las dos cosas se encuentran de verdad — y para entonces las filas del
   hunt ya cerraron y `phantasmagoria_hunt` puede degradarse sin dejar a nadie sin instrumento.

---

## 1. Dónde quedó todo, en una tabla

| | qué es | estado |
|---|---|---|
| **A** el tipo | asignarlo, networkearlo, forzarlo | **CERRADA en juego** (`server_type.lua`) |
| **B1** la cordura | la variable, la presencia, la recuperación, los instrumentos | **CERRADA.** r3: 5 pasa · 0 falla · 1 sin correr |
| **B2** los eventos | el tercer retorno `pos` en los ocho `EV.*` + la sub-tabla `sanity` de `ghost_flags.lua` | **sin empezar** ← acá |
| **C** el gatillo | cordura bajo el `hunt.threshold` **del tipo**; degrada `phantasmagoria_hunt` a instrumento | **sin empezar** ← y al final acá |
| **hunt directo** | cómo persigue el fantasma (`server_hunt.lua`) | **4 pasa · 0 falla · 10 sin correr** + 2 arreglos sin pasada en juego ← **empezar por acá**, §4bis |

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

Las **24** convars del bloque son `FCVAR_ARCHIVE` y quedan guardadas en la máquina del que prueba.
La r1 perdió dos perillas de **encendido** (catálogo nº 91) y la r3 llegó con
`phantasmagoria_sanity_regendelay` en **30** contra los **45** del diseño, movida en un A/B de la r2.

**Con `--decir` sólo informa; sin él, restituye y dice qué movió.** Leer *antes* de restituir es la
mitad que importa: si la corrida anterior midió con esos valores, después ya no se puede saber.

> La lección que dejó, y vale para el próximo bloque: *cuando la defensa contra un modo de falla es
> una lista para pegar a mano, cubre los casos que estaban en la lista el día que se escribió.* Las
> ocho líneas de la r1 eran todas de encendido, y **una perilla de encendido en 0 se ve en el reporte;
> un retardo movido no** — el reporte imprime `30` con la misma cara que `45`.

---

## 3. B2 — que los ocho eventos drenen

### 3.1 Lo que YA está y no hay que escribir

- **Los ocho renglones del desglose existen** (`evento_sound` … `evento_creak`) y hoy dicen
  `( sin llamador todavia: los ocho eventos son B2 )`. **B2 no toca el instrumento.**
- **La puerta está probada en juego**: la forma plana cae en su renglón (r3, filas 01 y 02), y una
  causa mal escrita se grita en el acto y se lleva su propio renglón sin romper el neto (r3, fila 03).
- **La perilla `phantasmagoria_sanity_eventos` ya existe** y hoy es un andamio declarado como tal.

### 3.2 Lo que hay que escribir, y en este orden

**(a) El tercer retorno `pos` en los ocho `EV.*`** de `server_events.lua`
(`EV.throw` :3223 · `EV.knock` :3440 · `EV.creak` :3546 · `EV.door` :3675 · `EV.light` :4128 ·
`EV.sound` :4388 · `EV.prop` :4503 · `EV.furniture` :5121).

⚠ **El drenaje se mide desde DONDE SONÓ, no desde el fantasma.** Un `knock` en una puerta al otro lado
de la casa no puede cobrarle al que está parado al lado del fantasma. Cada `EV.*` ya sabe dónde
ocurrió su efecto —el prop que tiró, la puerta que golpeó, la luz que parpadeó—; lo que falta es
**devolverlo**.

**(b) UNA sola pasada sobre los jugadores en `ENT:phantom_FireEvent`** (`server_events.lua:5142`), no
una por evento. Es el único sitio que ve el resultado de los ocho.

**(c) La sub-tabla `sanity` de `ghost_flags.lua`** — §19.8.4. Ahí viven el `mult = 2` del Oni, el
`per.door = 15` del Yurei y el `presence = 0.5` del Phantom.

> ⚠⚠ **Y ahí es donde la arquitectura de B1 cobra.** El `presence` del Phantom es una **tasa**
> (0,5 %/s mientras lo mires dentro de 525 u) y **SUMA** al drenaje plano de la manifestación: mirar
> un `singing` entero cuesta `10 % + 7,5 % = 17,5 %`. Entra por `RegisterSanityRate`, no por
> `DrainSanity`. **Las dos formas ya están medidas y son distintas** (r2 y r3, fila 04): si el rasgo
> no entra, no va a ser por la puerta.

**(d) Subir `LIGHT_CLASSES` de `server_events.lua` a `lua/phantasmagoria/` y borrar la copia** que B1
dejó acotada en el módulo de la cordura. Ver §5.

### 3.3 ⚠ Un `2` de tres estados recién ahora significa algo

El header de las convars de B1 dice que ninguna es de tres estados (`0 = nadie · 1 = respeta el flag ·
2 = todos`) **a propósito**: en B1 no había ningún flag por tipo que respetar, y una perilla cuyo
valor intermedio no significa nada se lee como que el flag ya existe. **Con la sub-tabla `sanity`
escrita, ese `2` pasa a tener sujeto.**

---

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

## 4bis. FRENTE 2 — el hunt directo: **10 filas sin correr**, y dos arreglos sin pasada en juego

Bloque: `lua/entities/terminator_nextbot_phantom/server_hunt.lua` + tres enganches. Commits `f78a0ae`,
`d60dc5a` y `9b19b5c`. Planilla `dev/checks/phantasmagoria-hunt-directo-r1.html` (14 filas, fuera de
git). Detalle completo en **`dev/CORRIDA_hunt_directo_r1.md`**.

**El veredicto de gameplay ya está dado**, y no lo mide ninguna fila — textual del autor: *«el hunt
directo probándolo ingame está bien como gameplay, el bot hace lo que se supone que debe hacer»*. La
corrida quedó a medias porque se fue a almorzar, no porque algo se cayera.

### 4bis.1 Las 10 que faltan, y qué le falta a cada una

| fila | qué mide | qué falta, exactamente |
|---|---|---|
| **01** | control positivo, 30-40 m | **declarar la banda de distancia**. Es lo único |
| **02** | el pedido (perseguir → perder → buscar → volver) | ídem: el `cerebro` se corrió a 33 u, no en la banda |
| **05** | el error de Lua se apaga | ⚠ **NO es binaria**: `truerange 1` baja un `chanceNeeded` de 85 a 15 en el tercer sitio. Hace falta un criterio de **CONTEO con N declarado** |
| **06** | una mesa no aborta el duelo | armar el escenario: mesa en el medio, y que **no** salga `my enemy wasnt engagable!` |
| **07** | el crouch-jump | *«no lo medí, pero sí el bot salta»* — **la observación no es la medición**: falta ver el `approachlastseen` que no aparece |
| **08** | el corte al prender el hunt | correrla **con `phantasmagoria_ghost_huntdirect 1` puesto ANTES** |
| **09** | el desenlace | **sacarse el `god` y morirse**, y mirar a quién se le atribuye la muerte |
| **10** | la órbita no existe en hunt | frontera abierta declarada: **no hay código de este bloque que la cierre** |
| **11** | no romper lo que ya cerró | pasarlas una por una, más el IDLE |
| **12** | el cadáver conserva las armas | la mitad dinámica: morirse y contar las armas en el piso, más el A/B con `pickup 1` |

⚠ La **04** está en **pasa parcial**, no verde: le falta la otra mitad del A/B, y se cierra con una
corrida de un minuto con el fantasma **HERIDO** a más de 1400 u.

### 4bis.2 ⚠⚠ Dos arreglos de esa sesión que NUNCA se corrieron en juego

Los dos salieron de **leer** la corrida, no de correrla, y los dos son de instrumento y de A/B — no
tocan la escalera, la compuerta ni el contacto, que es lo que el autor ya aprobó:

1. **El perro guardián atribuía el episodio a dos mecanismos APAGADOS.** Su `ErrorNoHalt` nombraba
   causas que están bajo una guarda de estado que el disparo no tiene, así que gritó dos veces con el
   fantasma en calma acusando a mecanismos que no podían ser. Contador partido por estado y mensaje
   que dice de quién es la culpa. *Un falso diagnóstico no es un falso rojo ni un falso verde: es un
   rojo verdadero con la etiqueta cambiada, y por eso no lo agarra ninguna planilla.*
2. **`phantom_huntCutFor` se invalida cuando `huntdirect` está en 0**, para que el corte del apagado
   no se pierda después de un A/B.

**Empezar por acá**: una pasada que confirme que ninguno de los dos rompió nada es más barata que
descubrirlo con diez filas encima.

### 4bis.3 ⚠⚠⚠ Las DOS preguntas que quedaron para el autor, y siguen sin respuesta

Van al principio del próximo chat, porque las dos son **decisiones de diseño y no defectos**:

1. **¿El rescate del perro guardián tiene que existir en calma?** Hoy sí, y el mensaje ya dice que el
   agujero es de la base. La alternativa es dejarlo sólo en hunt y que el IDLE lo siga cerrando
   `reallystuck_handler`, como antes del bloque.
2. **La fila 04:** ¿la corre él con el fantasma herido a más de 1400 u, o queda apoyada en el
   mecanismo determinista y anotada como parcial?

### 4bis.4 Fronteras que la r1 no movió, y ninguna fila se acreditó

La cordura como disparador (**es la tajada C de este mismo handoff**), el evento de mirar fijo del
Diseño §10, el tope de la órbita contra `sightdist`, `interceptIfWeCan`, el flanqueo por distancia
(**ninguna fila lo ejercita**: `flank de cerca 0` en las tres lecturas), y los 30 tipos sin poblar
(`ability.onCatch` enganchado, no poblado).

Y dos que siguen sin explicar: el `render se dibuja / la politica pide INVISIBLE / !! NO COINCIDEN` de
`server_cloak.lua`, y `movement_perch` + `movement_biginertia` activas a la vez.

---

## 5. Lo que sigue sin sujeto, y hay que saberlo antes de leer un cero

- **La zona segura de §18.1 NO EXISTE en código.** Cero `terminator_blocktarget`, ninguna entidad
  camión. Está registrada como fuente continua **INACTIVA que dice por qué lo está**, con
  `PHANTASMAGORIA.InSafeZone` como costura.
- **El destierro de §5.4 no existe**; el único desenlace es **matar** al fantasma.
- ⚠⚠ **El punto ciego de la luz llegó a 25 luces sin getter.** `a oscuras` es el **default cuando no
  hay nada legible**, y el ×1,5 aporta **un tercio del drenaje** en toda lectura a oscuras.
  *El modulador está decidiendo un tercio del número sobre una lectura que el propio instrumento
  declara que no puede hacer.* No es un rojo —avisa— pero **es lo primero que B2 tiene que cerrar**:
  de las seis clases de luz, hoy sólo `gmod_light` y `gmod_lamp` tienen getter.
- **El medidor de actividad (§19.3)** sigue sin diseñar.

---

## 6. Los comandos de la cordura

| comando | qué hace |
|---|---|
| `phantasmagoria_cordura` | **el reporte**: valor, desglose por causa, fuentes, perillas y tasas |
| `phantasmagoria_cordura_reset` | valor al inicial, desglose y contadores en cero. **Antes de cada fila** |
| `phantasmagoria_cordura_fabrica [--decir]` | las 24 perillas a fábrica, **diciendo cuáles estaban movidas** |
| `phantasmagoria_cordura_set <0..100> [nick]` | **ANDAMIO**. Se anota como causa `andamio consola` a propósito |
| `phantasmagoria_cordura_med <1\|2\|3>` | **ANDAMIO**. Una dosis sin pasar por Cargo |
| `phantasmagoria_cordura_drenar <n> [causa]` | **ANDAMIO**. Dispara la forma **plana**. Default `evento_sound` |

⚠ Un comando por línea: **la consola de Source corta en 255 bytes y no avisa**.

⚠⚠⚠ **Y tampoco te entrega el texto entero: `CCommand::Tokenize` parte en `{ } ( ) ' :`**, así que
esos caracteres llegan como **tokens propios**. Le costó la fila 04 a la r2, y el id `evento:sound`
era **inalcanzable desde la consola desde el día que se escribió**. **Ningún id que B2 agregue puede
llevar un carácter del break set** — va guion bajo. Hay dos controles y hacen falta los dos:
`python dev/auditar_ids_tipeables.py lua` (texto fuente, sin juego) y uno al arrancar el módulo.

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

⚠⚠ **`auditar_puerta_cordura.py` va a cambiar de significado con B2.** Hoy dice
*«Usan la API publica: NINGUNO todavia»* y eso es **lo esperado**. Cuando B2 escriba sus llamadores,
ese cero pasa a ser un **defecto**: el auditor exige que el único escritor del número sea el módulo,
pero **no puede exigir que alguien lo llame** (es el nº 89 por el otro lado). Al cerrar B2, mirar ese
renglón y comprobar que dice **ocho**.

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
