# HANDOFF — la cordura, tajada B1: la variable, las dos formas de drenaje y el desglose por causa

**Fecha:** 2026-08-20 · **Repo:** `phantasmagoria` · **Autor:** chileno, escribirle de **tú** (sin voseo)
**Planilla de la r3 — la que hay que correr:** `dev/checks/phantasmagoria-cordura-b1-r3.html`, **6 filas**,
artefacto en <https://claude.ai/code/artifact/8c6dc8ac-b4bb-408b-9fbe-bd030efeea85>
**Planilla completa (12 filas, r1 y r2):** `dev/checks/phantasmagoria-cordura-b1.html`, artefacto en
<https://claude.ai/code/artifact/3c2a6008-39b8-47fa-9a1c-92f3538bce4a>
**Corridas:** `dev/CORRIDA_cordura_b1_r1.md`, `_r2.md` y **`_r3.md`** (reportes íntegros + análisis)
**CHANGELOG:** **(61)** el bloque, **(62)** la r1, **(63)** la r2 y el tokenizador, **(65)** la r3 y la vuelta a fábrica
**Diseño:** `docs/PHANTOM_Phasmophobia_Diseno.md` **§19** entero, sobre todo §19.8 y §19.9

> ✅✅ **B1 ESTÁ CERRADA (r3 del 2026-08-20: 5 pasa · 0 falla · 1 sin correr).** Este documento queda
> como el **registro del bloque**; para seguir, el handoff vivo es
> **[`HANDOFF_cordura_b2_y_c.md`](HANDOFF_cordura_b2_y_c.md)**.
>
> ⚠⚠⚠ **Y lo primero de cualquier corrida futura es `phantasmagoria_cordura_fabrica --decir`.** La r3
> corrió con `regendelay` en **30** contra los **45** del diseño: las ocho líneas de restitución que
> este handoff lista más abajo son todas de **encendido**, y **no pueden restituir un número**.

Pensado para retomar desde un chat limpio, sin contexto previo.

---

## 0. ⚠⚠⚠ Antes que nada: dónde está esto en `git log`

Las entradas (61) y (62) **no tienen commit propio**. Viajaron enteras dentro de **`4e0859b`**, cuyo
mensaje dice *«dev: handoff del hunt directo, para correr la planilla desde un chat limpio»* — de
**otra sesión**, que commiteó el índice completo mientras ésta tenía sus rutas ya stageadas. De las
2.856 líneas de ese commit, **292 son ese handoff y 2.564 son la cordura**. El commit `e1ea7b9` deja
el rastro escrito en el propio CHANGELOG.

**No se reescribió la historia a propósito:** ya estaba pusheado y la otra sesión seguía viva, así que
un `--force` podía llevarse trabajo en vuelo.

> **La lección, para la próxima sesión que commitee acá:** hay **varios chats trabajando este repo al
> mismo tiempo** y el **índice de git es compartido**. Stagear rutas explícitas **no alcanza** — entre
> el `git add` y el `git commit` hay una ventana, y si el otro commitea ahí, se lleva lo tuyo. Lo que
> protege es **`git commit -F- -- <rutas>`**, que no deja ventana. Y el tell de que ya pasó es que
> **los archivos que editaste dejan de aparecer en `git status`**.
>
> ⚠ Y `lua/autorun/client/phantasmagoria_eq_check.lua` está modificado por otra sesión: **no stagearlo.**

---

## 1. Qué es esto, en una línea

Un número por jugador que baja cuando el fantasma está cerca, sube cuando el jugador se refugia, y un
instrumento que dice **QUÉ lo bajó**.

§18 diseñó **cómo** caza el fantasma; la cordura decide **cuándo**. Las tres tajadas:

| | qué es | estado |
|---|---|---|
| **A** el tipo | asignarlo, networkearlo, forzarlo | **CERRADA en juego** (`server_type.lua`) |
| **B1** la cordura | la variable + la presencia + la recuperación + los instrumentos | **ESCRITA. r2 corrida: 10 pasa · 1 falla · 1 sin correr** — falta la **mitad B de la 04** y la **10** |
| **B2** los eventos | el tercer retorno `pos` en los ocho + `ghost_flags.lua` | sin empezar |
| **C** el gatillo | cordura bajo el `hunt.threshold` **del tipo**; jubila `phantasmagoria_hunt` | sin empezar |

**Archivo único:** `lua/autorun/phantasmagoria_sanity.lua` (~1.770 líneas). **No toca**
`server_events.lua` (es B2), ni `server_hunt.lua` / `server.lua` / `server_stuck.lua` (otra sesión
reescribió ahí *cómo persigue* el fantasma; las dos cosas se encuentran en C, no antes).

---

## 2. La arquitectura, y las tres cosas que no se arreglan agregando código

### ⭐⭐⭐ (a) La API expresa DOS formas de drenaje

```lua
PHANTASMAGORIA.DrainSanity( ply, pct, causa )        -- PLANO: un número, una vez
PHANTASMAGORIA.RestoreSanity( ply, pct, causa, techo )
PHANTASMAGORIA.RegisterSanityRate( id, fn )          -- CONTINUO: una tasa condicionada, por tick
PHANTASMAGORIA.GetSanity( ply )                      -- el lector público
PHANTASMAGORIA.SetSanity( ply, pct, causa )          -- ANDAMIO
PHANTASMAGORIA.UseSanityMed( ply, tier, quien )      -- los tres tiers, una puerta
```

El **Phantom** drena 0,5 %/s mientras lo mires dentro de 525 u **y eso SUMA al drenaje plano** (§22.10):
mirar un `singing` entero cuesta `10 % + 7,5 % = 17,5 %`. Con una sola forma, **ese rasgo no entra**.

### ⭐⭐⭐ (b) La forma continua es un REGISTRO QUE EL TICK INTERROGA

No son llamadas empujadas desde afuera, y no es estilo: con llamadas empujadas, **una fuente que dejó
de llamar y una fuente que no existe se ven idénticas en el reporte** — cero las dos (catálogo nº 89).
Interrogada, una fuente inactiva **dice que lo está y por qué**.

`fn( ply, dt )` devuelve `rate, causaId, techo, nota, modulable`. **`nil` = no aplica este tick**, y eso
se cuenta. ⚠ **La fuente NO consulta su perilla**: si lo hiciera, devolvería `nil` con la perilla en 0
y el reporte perdería el potencial.

La **presencia** se escribió *como fuente registrada* a propósito: si fuera un caso especial adentro
del tick, la fila 04 estaría midiendo el tick y no el registro.

### ⭐⭐⭐ (c) El contador va ANTES de la perilla

Toda causa acumula su **potencial** aunque su perilla esté en 0; la perilla suprime el **efecto**,
nunca la cuenta (catálogo nº 100). Más un contador de **ticks en la esfera** que vive del otro lado de
esa perilla, para que el cero del control **pruebe que la corrida se hizo**.

⚠ La **oscuridad** es **la única causa con DOS perillas** — la suya y la de `presencia` — porque *un
modulador no existe sin lo que modula*: con una sola, la corrida de control vería moverse la barra por
el ×1,5 de una presencia apagada.

---

## 3. Las decisiones del autor. **No se re-discuten.**

| decisión | valor | por qué |
|---|---|---|
| goteo pasivo | **0,2 %/s con retardo de 45 s** | su número, con la condición que lo hace funcionar; sin el retardo el empate cae en `f = 2/3` y el umbral no se alcanza nunca |
| techos | **goteo 80 · camión 100** | las tres vías con territorio propio; la pastilla es lo único que sube desde 80 al instante |
| pastillas | **`stackable`, un uso**, +25/40/60, 20/40/60 USD | `stackable` es lo único que habilita el quick bind F1-F4 de Cargo |
| presencia | **esfera, SIN línea de visión**; discriminante = **el HUNT y nada más** | el escondite protege del *targeting*, no de la cordura; y una tasa no se cuelga de algo que titila |
| oscuridad | **MODULADOR, no causa** (×0,5 con luz, ×1,5 a oscuras) | si drenara sola, bajaría en cualquier mapa oscuro sin fantasma |
| la cordura | **NO se dibuja** | el indicador es el mundo (§19.9.4) |
| morir | **SÍ restaura** | en gamemode la partida termina; en sandbox compite contra `sv_cheats` |

⚠ **Leer §19.8.3, §19.9.2 y §19.9.4 antes de proponer nada**: existen para que no se re-proponga algo
ya descartado (*«drena más si lo estás mirando»* está descartado, y por dos razones que no son de CPU).

---

## 4. ⚠⚠ Lo que NO tiene sujeto, y hay que saberlo antes de leer un cero

- **La zona segura de §18.1 NO EXISTE en código.** Censo: cero `terminator_blocktarget`, ninguna
  entidad camión — y §18.1 dice que la zona *sale de esa entidad*. Está registrada como fuente
  continua **INACTIVA que dice por qué lo está**, con `PHANTASMAGORIA.InSafeZone` como costura.
- **Los ocho eventos no llaman a la puerta** (es B2). Sus ocho renglones existen en el desglose y
  dicen `( sin llamador todavía: los ocho eventos son B2 )`.
- **El destierro de §5.4 no existe**; el único desenlace disponible es **matar** al fantasma.
- **`LIGHT_CLASSES` vive `local` en `server_events.lua`** y B1 no podía tocarlo, así que hay una copia
  acotada — **y sólo alimenta el contador del punto ciego** de `IsPlayerLit` (de las seis clases de
  luz, sólo `gmod_light` y `gmod_lamp` tienen getter). Si envejece, el punto ciego se reporta **más
  chico**; nunca decide si un jugador está iluminado. **B2 tiene que subir la tabla a
  `lua/phantasmagoria/` y borrar la copia.**

---

## 5. La corrida r2: **10 pasa · 1 falla · 1 sin correr**

Detalle en `dev/CORRIDA_cordura_b1_r2.md`. La r1 (4 pasa · 0 falla · 8 sin correr) sigue en
`dev/CORRIDA_cordura_b1_r1.md` y lo que cerró **no** se volvió a medir.

### ⚠⚠⚠ La roja fue la 04, y su causa NO estaba en la cordura

`phantasmagoria_cordura_drenar 10 evento:sound` drenó contra una causa llamada `evento`.
`CCommand::Tokenize` (tier1) parte la línea de consola con un break set que incluye **`{ } ( ) ' :`**,
así que el argumento llegó como **tres tokens** y el comando leía `args[2]`. **Sin un solo error de
Lua**, y con los cinco instrumentos offline en verde: ninguno sabe nada de la consola.

**Ya está arreglado** (los ocho ids pasan a `evento_sound`, control de arranque sobre las 19 causas,
tres defensas en el comando, y `dev/auditar_ids_tipeables.py`). Lo que queda de esa fila es **la
mitad B**: dos líneas.

⚠ **Tres de sus cuatro criterios ya están medidos y no cambian**: la fuente dice `ACTIVA` con motivo
adentro, `presencia hunt` **quedó congelado** al salir del radio (`−1,85 % / 9,0 s / 30 ticks` en las
dos lecturas), y la plana se imprimió `1 veces` sin segundos ni ticks. *Las dos formas ya son
distintas y el instrumento las distingue* — lo que falló fue contra **qué renglón** cayó la plana.

### Lo que la r2 cerró y la r1 no había podido

- **El techo de 80 se EJERCIÓ** (02): `200,7 s × 0,200 %/s = 40,14 %` de potencial, **40,09
  aplicado**, barra en **80,00**. *Los 0,05 que sobraban los comió el techo.*
- **El clamp en 0** (05B) cerró con brecha **0,00** — el otro extremo del rango.
- **El modulador ×0,5 se midió por primera vez** (09, con linterna): delta **+0,47** sobre base
  −0,94, positivo y mitad exacta.
- **La 01 en la meseta** (63 u): `0,0968 %/s` contra `0,100` — confirma la explicación que la r1 dio
  para su `0,070`.
- **La 08 con Cargo montado**: los tres tiers como ítems, con modelo, precio, trivia, `Use` y stack.

### Lo que queda de la planilla

- **04**, sólo la mitad B: `phantasmagoria_cordura_drenar 10 evento_sound` y leer. Tiene que salir
  `evento sound  −10.00 %  1 veces` y **ningún** renglón `NO DECLARADA`.
- **10**, sin correr: va última por diseño (pide la sesión entera sin resetear) y la 04 la interrumpió.
  Sus dos mitades offline están verdes.
  ⚠ La r2 **produjo** un renglón `NO DECLARADA`, que es lo que el `pass` de la 10 prohíbe — y **la 10
  no puede distinguir** un escritor clandestino de un andamio mal tipeado. Mirar quién lo produjo
  antes de leerlo como un rojo del bloque.
- **03** quedó PASA **sin una lectura con número al lado**: es la única del run así. Si su balance
  (cruzar el 50 % entre 10 y 20 min) va a decidir tasas antes de B2, conviene una lectura con número.

### ⚠⚠ El punto ciego de la luz llegó a 25 luces sin getter

`a oscuras` es el **default cuando no hay nada legible**, y el ×1,5 aporta **un tercio del drenaje**.
*El modulador está decidiendo un tercio del número sobre una lectura que el propio instrumento declara
que no puede hacer.* No es un rojo —avisa— pero es **lo primero que B2 tiene que cerrar** al subir
`LIGHT_CLASSES` a `lua/phantasmagoria/`.

⚠ **El artefacto abre limpio** (el auditor reprueba cualquier check premarcado). Las marcas de la r1 y
la r2 están en sus dos `CORRIDA_*.md`.

---

## 6. ⚠⚠⚠ Las perillas son `FCVAR_ARCHIVE` y ya mordieron una vez

En la r1 la fila 00 dejó **`destierro 0`** y **`eventos 0`**, y nunca se restituyeron (catálogo nº 91).
Corridas así, **la 09 y la 04 habrían salido rojas por la perilla y no por el mecanismo**.

⚠ **Y volvió a pasar en la r2**: el último reporte del run salió con `eventos 0` y `meds 0`. No costó
nada porque la 04 y la 07 ya llevan su perilla en el botón —o sea que la defensa funcionó, no que el
problema se fuera—, pero **la próxima sesión arranca con esas dos apagadas**.

**Ya está arreglado**: las filas 04, 07 y 09 llevan su perilla como **primera línea del comando** —
*una salida que no se puede producir sin la precondición vale más que una precondición bien escrita*
(nº 70a). Igual, para dejar todo de fábrica:

```
phantasmagoria_sanity_presencia 1
phantasmagoria_sanity_regen 1
phantasmagoria_sanity_safe 1
phantasmagoria_sanity_meds 1
phantasmagoria_sanity_muerte 1
phantasmagoria_sanity_destierro 1
phantasmagoria_sanity_eventos 1
phantasmagoria_sanity_dark 1
```

---

## 7. Los comandos

| comando | qué hace |
|---|---|
| `phantasmagoria_cordura` | **el reporte**: valor, desglose por causa, fuentes, perillas y tasas |
| `phantasmagoria_cordura_reset` | valor al inicial, desglose y contadores en cero. **Antes de cada fila** |
| `phantasmagoria_cordura_set <0..100> [nick]` | **ANDAMIO**. Se anota como causa `andamio consola` a propósito |
| `phantasmagoria_cordura_med <1\|2\|3>` | **ANDAMIO**. Una dosis sin pasar por Cargo |
| `phantasmagoria_cordura_drenar <n> [causa]` | **ANDAMIO**. Dispara la forma **plana**. Default `evento_sound` |

⚠ Un comando por línea: **la consola de Source corta en 255 bytes y no avisa**.

⚠⚠⚠ **Y la consola tampoco te entrega el texto entero: `CCommand::Tokenize` parte en `{ } ( ) ' :`**,
así que esos caracteres llegan como **tokens propios**. Le costó la fila 04 a la r2. Ningún id que un
andamio tenga que poder **tipear** los lleva, y hay dos controles que lo verifican —uno al arrancar el
módulo, otro offline (`dev/auditar_ids_tipeables.py`)—. El `drenar` además **rearma y normaliza**, así
que `evento:sound` sigue llegando bien, avisando; y **si la causa no está declarada lo grita en el
acto** en vez de dejártelo descubrir dos pantallas después.

---

## 8. Los instrumentos offline. Todos verdes el 2026-08-20.

```
find lua -name '*.lua' -print0 | xargs -0 python dev/luacheck_gmod.py
python dev/parsear_sintaxis_glua.py lua
python dev/auditar_returns_de_hooks.py lua
python dev/rutas_de_sonido.py
python dev/auditar_puerta_cordura.py --control     # y sin --control sobre lua/
python dev/auditar_ids_tipeables.py lua            # y --control
```

⚠ `luacheck_gmod.py` **sin argumentos revisa cero archivos y sale 0** — verde sin medir. Va siempre
con el `find ... | xargs`.

**`dev/auditar_puerta_cordura.py` es nuevo y es el que §3.2 del prompt exigía:** un control que mide la
puerta **no descubre que alguien no la llama** (nº 89). Barre el **texto fuente**, **exige** que el
único escritor sea el módulo y **prohíbe** el patrón viejo (`GetNWFloat` sobre el mismo nombre devuelve
**0** con la barra al 72 %: `NW2Float` y `NWFloat` son **dos almacenes distintos** del engine). Su
`--control` inyecta 3 defectos sobre una **copia del árbol real** —no una sandbox, que le sacaría justo
lo que lee (nº 82)— y falla si el número no coincide, de más o de menos (nº 72).

**`dev/auditar_ids_tipeables.py` es el otro nuevo, y nace del rojo de la r2.** Barre la tabla `CAUSAS`
del texto fuente y falla si algún id lleva un carácter del break set de la consola. ⚠ **No reemplaza a
`auditar_puerta_cordura.py`**: ese mide **quién escribe** el número, éste mide **quién puede ser
nombrado**. La r2 probó que un árbol puede estar verde en el primero y roto en el segundo. Su
`--control` inyecta el defecto de la r2 tal cual sobre una copia del árbol real.

Los tres de planilla viven en el `dev/` **del workspace**, que **no está en git**:

```
python dev/auditar_planilla.py dev/checks/phantasmagoria-cordura-b1.html
python dev/verificar_citas_de_planilla.py dev/checks/phantasmagoria-cordura-b1.html --addon phantasmagoria --control
python dev/parsear_cmds_planilla.py dev/checks/phantasmagoria-cordura-b1.html
```

> ⚠ **`verificar_citas_de_planilla.py` tenía un defecto que se arregló el 2026-08-20** y llevaba vivo
> por lo menos una ronda cerrada: **no podía ver ningún comando que no fuera el primero de un bloque
> `cmd` multilínea**. Su patrón arranca con `\b`, y en `...1\nphantasmagoria_ghost_where` la `n` del
> escape y la `p` del comando son **las dos caracteres de palabra** — no hay borde, así que la
> alternativa **no puede matchear jamás**. En `phantasmagoria-hunt-directo-r1` eran **4 de 18**
> invisibles. *El cero no dice «no hay», dice «este patrón no puede encontrar nada».*

---

## 9. Lo que sigue

1. **Cerrar la planilla**: la **mitad B de la 04** (dos líneas) y la **10**. La 02 y la 03 ya
   cerraron en la r2 — la 02 con el techo ejercido, la 03 por criterio del autor y sin número.
2. **B2** — la esfera de los eventos: el tercer retorno `pos` en los ocho `EV.*` y **una sola pasada**
   sobre los jugadores en `phantom_FireEvent`. Los ocho renglones del desglose ya existen: **B2 no toca
   el instrumento**. Y de paso, subir `LIGHT_CLASSES` a `lua/phantasmagoria/`.
3. **C** — el gatillo contra el `hunt.threshold` **del tipo**, que jubila `phantasmagoria_hunt`.
   ⚠ §19.9.1: **promedio en gamemode, CICLADO entre los vivos en sandbox**, con los muertos **fuera**
   del promedio (si no, el primer muerto sube el promedio y protege a los vivos).
4. Sigue sin diseñar el **medidor de actividad** (§19.3).
