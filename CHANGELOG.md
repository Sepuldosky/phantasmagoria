# Phantasmagoria — Changelog

**Estado:** ver [ESTADO.md](ESTADO.md) · **Diseño:** ver [docs/](docs/PHANTOM_Phasmophobia_Diseno.md)

Formato: una entrada por sesión de trabajo, la más reciente arriba. Se anota lo que se **hizo** y lo
que se **midió**, no lo que se planea.

---

## 2026-08-01 — Sesión 2: el giro a Phasmophobia, y el repo

### El cambio de rumbo

PHANTOM dejó de ser «un fantasma que te observa y se aleja» y pasó a ser **un motor de rasgos** que
recrea los 30 tipos de Phasmophobia. Nada del diseño anterior se tiró: el comportamiento de observar
es ahora el estado *fuera del hunt*, y el destierro pasó a ser un desenlace posible del hunt.

### Hecho

- **Repo creado.** `phantasmagoria/`, licencia MIT, `.gitignore` que excluye **todos** los assets.
- **Tabla de los 30 tipos generada** — `lua/phantasmagoria/ghost_types.lua`, 673 líneas.
  **No está escrita a mano:** sale de `dev/gen_types.py` sobre datos reales del juego. Valida
  sintaxis con `luaparser`.
- **Audio convertido:** 265 `.wav` → `.ogg` Vorbis q4. **141 MB → 11 MB (−92 %)**, 0 fallos.
  Originales intactos. Duraciones verificadas contra el original: **delta 0,000 s** en la muestra.
- **Borrados** `schizophrenia_v2` (39 MB) y `the hat man` (5,9 MB) por decisión del autor.
- Documentos movidos a `docs/` y rutas relativas reajustadas.

### La fuente de datos, y cómo se consiguió

La wiki de Fandom devuelve **HTTP 402** y el cheat sheet de tybayn es una SPA sin datos en el HTML.
Los datos reales salen de un endpoint que el propio cheat sheet consume:

```
https://zero-network.net/phasmophobia/data/ghosts.json?lang=en
```

**Requiere cabecera `Referer`/`Origin`**: sin ella responde `{"detail":"Not authorized"}`. Con ella,
62 KB con los 30 tipos, velocidades en m/s, umbrales de cordura, evidencias y notas de comportamiento.
Se llegó a él leyendo `scripts-v10/zn-v5.js:152` del repo del cheat sheet.

### Medido

- Los **seis tipos que no conocíamos** (Aswang, Gallu, Kormos, Deildegast, Obambo, Dayan) quedaron
  documentados con datos duros. **Ninguno rompe el motor**: todos son variantes de estados cíclicos,
  velocidad condicional o detección condicional. El corte de rasgos aguanta.
- Velocidades reales del juego: de **0,4 m/s** (Deogen de cerca, Deildegast frenado) a **3,0 m/s**
  (Revenant persiguiendo). El Spirit a 1,7 m/s es la unidad de referencia.
- Umbrales de cordura: de **10 %** (Obambo calmo) a **75 %** (Thaye).

### Decidido

- **La velocidad se deriva del jugador**, no de la wiki: los tipos son multiplicadores de la carrera
  real. Con Better Movement en `run 280`, un Spirit corre a 280 u/s.
- **El desenlace del hunt es un rasgo** (`ability.onCatch`): unos tipos matan, otros destierran.
- **Volver del destierro:** muriendo (rápido y aburrido) o por un ritual (el camino que puede salvar
  a alguien si esto termina en un gamemode).
- **Sandbox, no gamemode.**

### Trampa encontrada (no costó nada porque se vio antes de escribir código)

**`ply:GetRunSpeed()` no sirve para calibrar velocidad con Better Movement montado.** El mod escribe
en la API nativa (`sh_bm_main.lua:455`) pero multiplica por `_bmfraction`, un factor **dinámico**
clampeado entre 1 y 2. El getter devuelve **entre 280 y 560 según el instante en que lo leas**. Hay
que leer la convar base `sv_bm_speed_run`. `GetConVar("sv_bm_enabled") == nil` es el chequeo de
existencia del mod.

---

## 2026-08-01 — Sesión 1: investigación de la base

**Sin código.** Esta entrada existe para que la sesión 2 no empiece de cero.

### Alcance

Seis addons, **55.425 líneas de Lua en 125 archivos**, leídos con 14 lectores en paralelo. Cada API
afirmada fue auditada por un segundo pase que intentaba refutarla: **1.042 afirmaciones — 882
confirmadas, 147 imprecisas, 13 refutadas**.

### Lo que se descubrió

- **El comportamiento pedido ya estaba escrito en la base.** `movement_watch`
  (`shared.lua:6001`) se planta a distancia, se prohíbe disparar y mide si el jugador la mira con
  `enemyBearingToMeAbs() < 9`. El comentario del autor: `-- this is not a SNIPING behaviour!`
- **El fantasma se activa con un campo:** `ENT.IsWraith = true`.
- **La dimensión extra ya existía** en HIM: teleport a `Vector(80000,80000,80000)`, niebla negra,
  skybox tapado, `PreventTransmit` recursivo.
- `schizophrenia_v2` fue un **resultado negativo**: no tenía ninguna de las tres cosas que se fueron
  a buscar. Se borró en la sesión 2.

### Las tres refutaciones que habrían costado una tarde

1. **`ENT.Models` gana sobre `ENT.Model`** — declarar sólo `Model` spawnea con Arnold.
2. **`Term_FOV` solo no alcanza**: sin `AutoUpdateFOV = false`, la convar global lo pisa. El
   comentario del código dice lo contrario y miente.
3. **`SetupDataTables` con `NetworkVar("Bool", 0, …)` pisa `Crouching`** de la base. HIM tiene ese
   bug **vivo**: su señuelo nace agachado.

### Error propio, corregido

Se reportó que la «dimensión extra» no tenía precedente en ningún addon. **Era falso**: el grep que
lo «probó» exigía `SetPos` en la misma línea. Lo refutó leer el addon, no afinar el patrón.
