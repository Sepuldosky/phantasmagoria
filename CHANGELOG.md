# Phantasmagoria — Changelog

**Estado:** ver [ESTADO.md](ESTADO.md) · **Diseño:** ver [docs/](docs/PHANTOM_Phasmophobia_Diseno.md)

Formato: una entrada por sesión de trabajo, la más reciente arriba. Se anota lo que se **hizo** y lo
que se **midió**, no lo que se planea.

---

## 2026-08-02 — Sesión 5: qué forma tiene el equipo, y qué le da Cargo

**Sin código de entidades.** Se contestaron tres preguntas del autor y se corrigió un error propio.

### Medido

- **Los 36 modelos tienen `numbones = 1` y `numseq = 1`**, sin excepción (`dev/mdlinfo.py`). Eso
  decide la forma del equipo antes de discutirla: **no hay rig para `UseHands`** (el viewmodel
  flotante no es una elección estética, es la única opción sin recompilar) y **no hay animación**
  (todo el movimiento es código). Ver EQUIPAMIENTO §5.1.
- **Los 13 `.phy` del Prop Pack, uno por uno**: **6 en 1000 kg** y **7 en 100**, no trece en 1000.
  Los 13 declaran `surfaceprop metal` — de ahí que la sal sonara a chapa.

### Corregido — un error de la sesión anterior

EQUIPAMIENTO §1.2 afirmaba que el Prop Pack «clavó `1000` a mano en **todos** sus props». **Falso, y
lo desmiente la misma fuente que el párrafo citaba**: la frase generalizó a 13 desde los 3 casos de
su propia tabla, y ninguno de los otros diez se había abierto. `prop_data.lua` arrastraba la misma
frase en su header **mientras el comentario de su tabla, 35 líneas más abajo, decía «100 o 1000»**:
el archivo se contradecía a sí mismo. Corregidos los dos.

**No cambió ninguna decisión** — 100 kg para una linterna es igual de inusable que 1000 para un
crucifijo, y la vía sigue siendo `SetMass()` en runtime. **El código nunca dependió del error**: la
tabla fija una masa objetivo por modelo, no una corrección uniforme. Prosa mal, código bien.

### Diseñado (EQUIPAMIENTO §5 y §6, nuevas)

- **El reparto del equipo en cuatro formas** — SWEP lo que se sostiene, entidad lo que se planta y lo
  que es escenografía, ítem con `onUse` lo que se consume.
- **Integración con Cargo**, leída contra su código. El hallazgo que manda: **la captura de Cargo se
  come cualquier SWEP que el engine entregue** y le fabrica un def `autogen` de 2,5 kg sin precio.
  Con Cargo montado pasa igual — la elección es registrar defs propios o que salga mal solo.
- Tres registros de Cargo que encajan casi literalmente: `Wheel.RegisterLightSource` (linterna, UV,
  glowstick), `StatusPanel.RegisterBar` (la cordura de §3.5), `Capture.RegisterWorldPickup`.
- **El límite:** Cargo **no** tiene API para registrar slots. O categoría `weapons` + `equip_slots`
  (y se gana el hotbar 1-4 y el wheel gratis), o un `Slots.Register` que es trabajo de Cargo.

### Frontera declarada

Que un prop de 1 hueso y 1 secuencia funcione como `SWEP.ViewModel` **[sin verificar]**: los SWEPs de
`dev/other/` usan todos viewmodels dedicados `v_`/`c_`, ninguno un prop pelado. El camino alternativo
—dibujarlo a mano con `ClientsideModel`— **sí** tiene precedente leído (el NVG de Neosun), y su costo
es conocido: se dibuja en la pasada del mundo, así que atraviesa paredes.

---

## 2026-08-02 — Sesión 4: los props de equipamiento, verificados bit por bit

### Hecho

- **36 modelos consolidados** en `models/` + `materials/` desde tres packs del Workshop, con las
  rutas **verbatim** (no se renombró nada: los `.mdl` las llevan horneadas).
- **Detector de addons duplicados** — `lua/autorun/phantasmagoria_assetcheck.lua`. Compara los WSID
  incluidos contra `engine.GetAddons()` y **avisa**: no desmonta, no bloquea, no rompe nada. Se
  silencia con `phantasmagoria_assetcheck 0`.
- **[docs/CREDITOS.md](docs/CREDITOS.md)** y **[docs/EQUIPAMIENTO.md](docs/EQUIPAMIENTO.md)**.
- Los packs originales se borraron de `dev/` una vez consolidados (evita 265 MB duplicados en disco).

### Verificado (parseando `studiohdr_t`, no leyendo el Workshop)

- **0 colisiones de ruta entre los tres packs** — usan namespaces distintos (`kiwontatv/`, `phas/`,
  `phasmophobia/demit/`), así que conviven.
- **62 referencias `.mdl` → `.vmt` resueltas, 0 faltantes**, 0 `.vmt` apuntando a `.vtf` inexistente,
  0 acompañantes (`.vvd`/`.vtx`) faltantes.

### Tres correcciones a lo que dice el Workshop

1. **El K2 no tiene bodygroups: tiene 6 skins**, y son mejores. `bodyparts=1, nmodels=1` (cero
   bodygroups reales) y `numskinfamilies=6`. La tabla intercambia `level_0N` por `level_0N_active`
   de forma **acumulativa**, así que `SetSkin(0..5)` **es** la lectura EMF. Son 6 estados, no 5: el
   0 es "apagado".
2. **Las masas del Prop Pack son 100 o 1000 kg sin excepción.** Un crucifijo de una tonelada no se
   levanta con la mano. El Equipment Pack tiene masas realistas (0,1–7,2 kg) y por eso es el que
   conviene por defecto.
3. **El libro abierto tiene 7 skins en un pack y 8 en el otro.** La octava del Prop Pack es
   `book_cursed_demit`, la firma del autor: sortear `0..7` la sacaría como si fuera escritura del
   fantasma.

### Defecto del pack original, corregido

`eqp_flashlight_strong.mdl` declara la textura `Strong Flashlight Glass` y **el pack no la incluye**:
el lente salía con checkerboard morado. Se escribió el `.vmt` faltante, marcado como nuestro en
CREDITOS. El nombre lleva espacios y mayúsculas porque es la cadena horneada en el binario.

### Pendiente anotado

**251 MB en 58 texturas, todas 2048×2048 DXT5** — incluidas las de un encendedor y unas pastillas.
Bajar a 1024² ahorraría ~190 MB por cliente y sería invisible en juego. **No se tocó**: es modificar
el asset de un tercero.

---

## 2026-08-02 — Sesión 3: paranormal events es 1:1, y el sistema de cuartos

**Sin código.** Diseño de spawn, dificultad y cuartos, más una corrección de evaluación.

### La corrección: subestimé `[gm] paranormal events`

En la sesión 2 lo describí como «banco de efectos, no sistema». **Era un error, y el autor lo
señaló.** Leído con la lente de Phasmophobia, el mod implementa los mismos conceptos con los mismos
nombres: **Ghost Orbs** (una evidencia entera), **favourite room**, **aggro → hunt**, interferencia
de linterna, luces parpadeando, y los **tres tipos de manifestación** que nombra la wiki (visible,
sombra, translúcida). Sus 24 convars son el mejor borrador que tenemos de las nuestras.

Lo que está roto es la implementación, no el diseño. Tres defectos verificados a mano:

- **`if !IsValid(pos)` sobre un `Vector`** (líneas 852, 860, 868): siempre falso, así que
  `CreateGhostOrbs`, `CreateShadowLurker` y `CreateCockRoachSwarm` **nunca emiten su partícula**.
  Además las tres pisan su propio argumento con `local pos = ...` en la línea anterior.
- **`favoriteRoom = Vector(1000, 1000, 100)`** (línea 93), hardcodeado, con el comentario del autor
  `-- change this based on your map`. Es exactamente la carencia que resuelve el sistema de cuartos.
- **`GetConVar("gmpa_ghost_damage")` sin `CreateConVar`**: la función de daño es inalcanzable.

`HuntPlayer()` mueve al fantasma con `SetPos(pos + dir * 10)` — teleporte por tick, atravesando
paredes. Es la razón por la que este proyecto existe.

### Diseñado

- **Spawn por dos vías** (§12): `phantasmagoria_autospawn N` mantiene una población de tipos
  sorteados —la vía que le sirve a un gamemode— y **un NPC por tipo en el menú**, generados en un
  bucle sobre la tabla, no escritos a mano.
- **Dificultad** (§13): una convar con cinco presets. No cambia al fantasma: cambia cuánta ayuda da
  el juego. En amateur **se queda en su cuarto**; en Nightmare/Insanity se ocultan evidencias
  *emitidas*, sin tocar el tipo real.
- **Sistema de cuartos** (§14): flood fill sobre navareas con techo, cortando por puertas; toolgun
  `phantasmagoria_rooms` para corregir a mano; persistencia por mapa en JSON con IDs de `CNavArea`;
  y puntos marcados para los ítems malditos.

### Encontrado: la primitiva de «cuarto» ya está escrita y probada

`IsUnderSkyPos()` de HIM (`sv_zhomeless_shelter.lua:272`) hace un trace de 12.000 u hacia arriba con
`CONTENTS_SOLID` y decide interior/intemperie; y lo envuelve en `IsUnderSky( area )` **cacheado por
`CNavArea`**, que es justo el granulado que hace falta. Hay dos alternativas medidas: `get_env_state`
de Better Movement (5 traces, más robusto contra huecos en el techo, ya networkeado como
`ply:GetBmEnvIsInside()`) y `GetNookScore` de la base (mide *encierro*, no techo).

### Decidido

- Si un mapa no tiene cuartos marcados, **el addon degrada, no se rompe** (§14.5): la favourite room
  pasa a ser la navarea con mayor `GetNookScore`. El 99 % de los mapas de GMod nunca va a tener
  mapeo, y arrancar igual no es opcional.

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
