# HANDOFF — la cordura, tajadas **B2** (los eventos drenan) y **C** (el gatillo calma → hunt)

**Fecha:** 2026-08-20 · **Repo:** `phantasmagoria` · **Autor:** chileno, escribirle de **tú** (sin voseo)
**Lo anterior:** [`HANDOFF_cordura_b1.md`](HANDOFF_cordura_b1.md) — B1 **cerrada**, r1/r2/r3 corridas
**Corridas:** `dev/CORRIDA_cordura_b1_r1.md` · `_r2.md` · `_r3.md`
**CHANGELOG:** **(61)** el bloque · **(62)** r1 · **(63)** r2 y el tokenizador · **(65)** r3 y la vuelta a fábrica
**Diseño:** `docs/PHANTOM_Phasmophobia_Diseno.md` **§19** entero, más **§18** (el hunt) y **§21** (los eventos)

Pensado para retomar desde un chat limpio, sin contexto previo.

---

## 1. Dónde quedó todo, en una tabla

| | qué es | estado |
|---|---|---|
| **A** el tipo | asignarlo, networkearlo, forzarlo | **CERRADA en juego** (`server_type.lua`) |
| **B1** la cordura | la variable, la presencia, la recuperación, los instrumentos | **CERRADA.** r3: 5 pasa · 0 falla · 1 sin correr |
| **B2** los eventos | el tercer retorno `pos` en los ocho `EV.*` + la sub-tabla `sanity` de `ghost_flags.lua` | **sin empezar** ← acá |
| **C** el gatillo | cordura bajo el `hunt.threshold` **del tipo**; jubila `phantasmagoria_hunt` | **sin empezar** ← y después acá |

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

## 4. C — el gatillo, y lo que jubila

Cordura por debajo del `hunt.threshold` **del tipo** (`lua/phantasmagoria/ghost_types.lua`: el Spirit
en 50, el Demon en 70, y los que traen `thresholdLow`/`thresholdHigh` sortean en ese rango). Cuando
entre, **`phantasmagoria_hunt` deja de ser el gatillo** y pasa a ser lo que siempre dijo su ayuda: un
andamio.

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

## 8. ⚠⚠⚠ Git: hay varias sesiones sobre este repo al mismo tiempo

El índice de git es **compartido**. Stagear rutas explícitas **no alcanza**: entre el `git add` y el
`git commit` hay una ventana, y si otra sesión commitea ahí, se lleva lo tuyo. Lo que protege es
**`git commit -F- -- <rutas>`**, que no deja ventana. El tell de que ya pasó es que **los archivos que
editaste dejan de aparecer en `git status`**.

⚠ `lua/autorun/client/phantasmagoria_eq_check.lua` está modificado por otra sesión: **no stagearlo.**
