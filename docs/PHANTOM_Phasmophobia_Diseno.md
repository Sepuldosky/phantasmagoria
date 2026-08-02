# PHANTOM — Diseño: un fantasma de Phasmophobia sobre la base Terminator

**Fecha:** 2026-08-01
**Documento hermano:** [PHANTOM_Referencia.md](PHANTOM_Referencia.md) — la investigación de la base.
**Fuente de mecánicas:** [wiki de Phasmophobia](https://phasmophobia.fandom.com/wiki/Ghost) (citada por el
autor; la wiki **no se pudo leer directo** — devuelve HTTP 402 — así que lo que sigue sale del texto
que pasó el autor más conocimiento previo del juego, **marcado tipo por tipo**, §6).

**La idea:** *un solo* NextBot, `terminator_nextbot_phantom`, que implementa **todas** las mecánicas
genéricas. Los 30 tipos de fantasma **no son 30 clases**: son 30 filas de una tabla de rasgos que
encienden y parametrizan lo mismo. Un Poltergeist es PHANTOM con `throwMultiple = true`; un Revenant
es PHANTOM con `speedOnLOS = 3.0`.

> **Colisión de nombres, a propósito:** «Phantom» también es uno de los 30 tipos del juego. El addon
> y la clase base se llaman `phantom`; el tipo del juego es `PHANTOM_TYPES.phantom`. No molesta, pero
> conviene saberlo antes de escribir el primer `if`.

---

## 1. La conversión de unidades — antes que nada

Phasmophobia habla en **metros y m/s**; Source habla en **unidades**. 1 u = 1,905 cm →
**1 m ≈ 52,5 u**. Toda la wiki hay que traducirla:

| Wiki | Unidades Source | Qué es |
|---|---:|---|
| 3 m | ~157 u | Rango de interacción con objetos |
| 5 m | ~262 u | Crucifijo contra Demon |
| **10 m** | **~525 u** | **Interferencia de electrónica, latido del corazón** |
| 15 m | ~787 u | Ídem para el Raiju |
| **20 m** | **~1050 u** | **Alcance de los sonidos del fantasma** |
| 1,7 m/s (velocidad normal) | **~89 u/s** | Caminata del fantasma |
| 3,0 m/s (Revenant con LOS) | ~158 u/s | Persecución rápida |

**Hallazgo cómodo:** `terminator_Extras.posIsInterrupting` usa un radio duro de **1000 u**
(≈19 m) — a un pelo de los 20 m de alcance sonoro del juego. La función que ya existe para «¿alguien
puede ver este punto?» sirve tal cual como «¿alguien me oiría desde acá?».

> **La velocidad NO se toma de la wiki.** Decisión del autor (2026-08-01): se deriva de la velocidad
> **real del jugador**, y los tipos son multiplicadores relativos a eso. Ver §1.1 — es más robusto
> que cualquier constante, porque se adapta solo a la config de cada servidor.

### 1.1 La velocidad se deriva del jugador **[verificado contra el mod]**

El autor usa **Better Movement v2**
([`dev/other/better movement v2 with sprint step time/`](../../dev/other/better%20movement%20v2%20with%20sprint%20step%20time/))
con `run 280 / walk 120 / slowwalk 80`. La velocidad de PHANTOM se define **relativa a eso**:
si el jugador corre a 280, un Spirit va a ~280 y un Revenant persiguiendo va a ~390.

**El hallazgo que simplifica todo:** no hace falta detectar el mod para la velocidad. Better Movement
**escribe en la API nativa de GMod** —
[`sh_bm_main.lua:455-457`](../../dev/other/better%20movement%20v2%20with%20sprint%20step%20time/lua/autorun/sh_bm_main.lua#L455):

```lua
ply:SetWalkSpeed( bm_vars.speed.walk:GetFloat() * _bmfraction )
ply:SetRunSpeed(  bm_vars.speed.run:GetFloat()  * _bmfraction )
ply:SetSlowWalkSpeed( bm_vars.speed.slowwalk:GetFloat() * _bmfraction )
```

> **⚠ Y acá está la trampa, que obliga a NO usar el getter.** Ese `_bmfraction` es **dinámico**:
> se calcula por tick y está clampeado entre **1 y 2** (líneas 449-452), con un `Lerp` que lo mueve
> suave. O sea que `ply:GetRunSpeed()` con Better Movement activo devuelve **entre 280 y 560 según el
> instante en que lo leas**. Un PHANTOM que calibre su velocidad con el getter en un momento
> cualquiera puede salir el doble de rápido de lo previsto, de forma intermitente e irreproducible.

La lectura correcta es la **convar base**, que es estable, con el getter como *fallback*:

```lua
-- devuelve la velocidad de carrera BASE del jugador, sin el factor dinámico de Better Movement
local function PlayerBaseRunSpeed( ply )
    local bmOn = GetConVar( "sv_bm_enabled" )
    if bmOn and bmOn:GetBool() then
        return GetConVar( "sv_bm_speed_run" ):GetFloat()   -- 280 — valor base, estable
    end
    return ply:GetRunSpeed()                                -- sin el mod, el nativo sirve
end
```

`GetConVar("sv_bm_enabled")` devuelve `nil` si el addon no está montado: **ese es el chequeo de
existencia**, y no hace falta nada más.

**Regalo del mod:** expone `ply:GetBmEnvIsInside()` (networked bool, `sh_bm_main.lua:152`) — ya sabe
si el jugador está **dentro de un edificio**. Para un juego que transcurre entero dentro de una casa,
eso es información gratis: sirve para el área de investigación, para la cordura (afuera no baja) y
para el `inside_multiplier` de 0.8 que el mod ya aplica.

---

## 2. El mapeo: qué ya está resuelto por la base

Lo importante de este diseño es cuánto **no** hay que escribir. La base Terminator resuelve el
estado más difícil de Phasmophobia —la cacería— porque *es* un cazador.

| Mecánica de Phasmophobia | De dónde sale | Estado |
|---|---|---|
| **Hunt**: perseguir y matar | El cerebro entero de la base | **gratis** |
| **Flicker** durante el hunt | `CloakedMatFlicker` del módulo wraith | **gratis** |
| Invisible fuera del hunt | `ENT.IsWraith = true` | **gratis** |
| Roaming entre puntos | Pathing + navmesh de la base | **gratis** |
| No salir del área de investigación | `ENT.hazardousAreas` / navareas prohibidas | casi gratis |
| Abrir/golpear puertas | `terminator_doorbash.lua` + `GhostInteractWithDoor()` | **gratis** |
| Tirar objetos (Poltergeist) | `FlingNearbyPhysicsProps(self)` de paranormal | **gratis** |
| Pasos audibles a 20 m | `ProcessFootsteps` + `IsSilentStepping()` | **gratis** |
| Silencio del Myling | `function ENT:IsSilentStepping() return true end` | **gratis** |
| Manifestación (ghost event) | `CreateShadowFigure(pos)` + partículas gmpa | **gratis** |
| Elegir dónde aparecer sin ser visto | `posIsInterrupting(pos)` | **gratis** |
| «El jugador me está mirando» | `enemyBearingToMeAbs(ply) < 9` | **gratis** |
| Favourite room | Guardar una `CNavArea` | trivial |
| Estados / cordura / evidencias | — | **hay que escribirlo** |

**Lo que hay que escribir de cero son tres cosas:** la máquina de estados de §3, el sistema de
cordura, y la tabla de rasgos de §5. Nada de eso es difícil; lo difícil ya está heredado.

---

## 3. La máquina de estados

De la wiki: el fantasma elige un estado, que dura **máximo 30 s** salvo el hunt. Se «despierta»
cuando se abre la puerta de salida por primera vez.

```
                        ┌──────────────────────────┐
      ┌────────────────►│  DORMIDO (pre-apertura)  │
      │                 └────────────┬─────────────┘
      │                              │ primera apertura de puerta → "awoken"
      │                              ▼
      │        ┌────────── selector de estado (cada ≤30 s) ──────────┐
      │        │                                                     │
      │   ┌────▼────┐  ┌─────────┐  ┌──────────┐  ┌───────────┐ ┌───▼────┐
      │   │  IDLE   │  │ ROAMING │  │ FAVOURITE│  │INTERACTION│ │ABILITY │
      │   │ 2-6 s   │  │ va a X  │  │  ROOM    │  │ objeto 3m │ │  ↓     │
      │   └─────────┘  └────┬────┘  └──────────┘  └───────────┘ └───┬────┘
      │                     │ (si tiene DOTS)                       │
      │                ┌────▼────┐                    ┌─────────────┼─────────────┐
      │                │ D.O.T.S │                    ▼             ▼             ▼
      │                └─────────┘               fuse box      ghost event    habilidad
      │                                                                        propia
      │                                                     cordura < umbral
      │                                                            │
      │                                              ┌─────────────▼──────────────┐
      └──────────────────────────────────────────────┤          HUNT              │
                       fin del hunt                  │  ← acá despierta la base:  │
                                                     │  D_HT + IsWraith flicker   │
                                                     └────────────────────────────┘
```

### 3.1 El interruptor limpio entre «fantasma» y «cazador»

Fuera del hunt el bot **no debe atacar**. La tentación es congelarlo con `DisableBehaviour`, y sería
un error: en este proyecto ya se pagó dos veces la lección de que **una puerta implementada como *no
correr* congela el estado — saltear no es apagar**.

La forma correcta es la **relación**, que es un solo lugar y no congela nada:

```lua
-- fuera del hunt: el jugador no es enemigo, el cerebro sigue corriendo
function ENT:OnFirstRelationWithPlayer( ply )
    return self.phantom_Hunting and D_HT or D_NU
end
```

Al entrar en hunt se re-evalúan relaciones y el jugador pasa a `D_HT`: la base hace el resto sola.
Al salir, vuelve a `D_NU`. El bot nunca deja de pensar, sólo deja de tener a quién odiar.

---

## 4. Cordura y hunt

La cordura es del **jugador**, no del fantasma, y es la variable que gobierna todo el juego.

- Baja con: oscuridad, ver manifestaciones, estar cerca del fantasma, hunts.
- Sube con: pastillas, luz.
- Cuando el promedio (o el mínimo, según el tipo) cae bajo `huntThreshold`, el fantasma **puede**
  cazar.

Se implementa como un número por jugador en el servidor, networkeado para el HUD. Es independiente
de la base Terminator: no hay nada que heredar acá, pero tampoco nada difícil.

**Durante el hunt** (de la wiki): la electrónica falla en 10 m y el fantasma parpadea. El parpadeo
es literalmente `CloakedMatFlicker`, y la interferencia es un bucle sobre jugadores en 525 u.

---

## 5. El catálogo de rasgos — el corazón del diseño

Cada tipo es una tabla de estos campos. **Ningún tipo necesita código propio**; si uno lo necesitara,
el motor está mal cortado.

```lua
PHANTOM_TYPES[ "revenant" ] = {
    name       = "Revenant",
    evidences  = { "emf5", "writing", "orbs" },
    speed      = { base = 1.0, onLOS = 3.0 },        -- m/s, se convierten a u/s al cargar
    hunt       = { threshold = 50 },
    strength   = "Muy rápido cuando te ve",
    weakness   = "Muy lento cuando te pierde",
}
```

### 5.1 Rasgos de velocidad

**Todos los valores son multiplicadores de `PlayerBaseRunSpeed()` (§1.1), no u/s absolutos.**
`1.0` = va tan rápido como vos corriendo. Así el addon se calibra solo en cualquier servidor.

| Rasgo | Qué hace | Tipos que lo usan |
|---|---|---|
| `speed.base` | Multiplicador de crucero (Spirit = 1.0) | todos |
| `speed.onLOS` | Multiplicador con línea de vista al jugador | Revenant (~1.4) |
| `speed.inverseDistance` | **Más rápido lejos, más lento cerca** | Deogen |
| `speed.perTemperature` | Escala con el frío de la sala | Hantu |
| `speed.rampDuringHunt` | Acelera mientras dura el hunt | Moroi (con cordura baja) |
| `speed.decaysOverContract` | Se vuelve lento con el tiempo | Thaye |
| `speed.nearFusebox` | Escala con cercanía al fusebox | Jinn |

Con los 280 del autor: Spirit ≈ 280 u/s, Revenant persiguiendo ≈ 390 u/s, Deogen de cerca ≈ 70 u/s.

Implementación: **una sola** función que devuelve u/s, enganchada al callback
`ModifyMovementSpeed` (`motionoverrides.lua:3803`) que la base ya expone. Todos los rasgos de arriba
son ramas de esa función. La conversión relativa vive en un solo lugar:

```lua
function ENT:PhantomDesiredSpeed( ply )
    local base = PlayerBaseRunSpeed( ply )      -- 280 con la config del autor
    local t    = self.phantom_Type.speed
    local mul  = t.base
    if t.onLOS and self:CanSeeEnemy() then mul = t.onLOS end
    -- …resto de rasgos…
    return base * mul
end
```

### 5.2 Rasgos de cacería

| Rasgo | Qué hace | Tipos |
|---|---|---|
| `hunt.threshold` | % de cordura que habilita el hunt (default 50) | Demon 70, Shade 35 |
| `hunt.durationMul` | Cuánto dura | Moroi, Demon |
| `hunt.blinkRate` | Frecuencia del parpadeo (fingerprint visual del tipo) | Deogen lento, Yokai rápido |
| `hunt.rangeMul` | Radio de interferencia (default 525 u) | Raiju 787 u |
| `hunt.canOpenDoors` | Si abre puertas persiguiendo | casi todos |
| `hunt.crucifixRange` | Radio del crucifijo (default 157 u) | Demon 262 u |
| `hunt.hearsOnly` | Sólo detecta por sonido, no por vista | Deogen (te encuentra siempre) |
| `hunt.deafRadius` | Sordo salvo muy cerca | Yokai |
| `hunt.targetsOne` | Fija un solo objetivo | Banshee |

### 5.3 Rasgos de habilidad

| Rasgo | Qué hace | Tipo |
|---|---|---|
| `ability.throwMultiple` | Tira varios objetos a la vez | Poltergeist |
| `ability.blowOutLights` | Apaga las luces al aparecer | Mare |
| `ability.turnOnLights` | **Enciende** luces / apaga velas | Onryo |
| `ability.fuseboxToggle` | Juega con el fusebox | Jinn |
| `ability.teleportToPlayer` | Se teletransporta al jugador | Wraith, Yokai |
| `ability.noFootprints` | No deja huellas en sal | Wraith |
| `ability.mimicType` | Copia los rasgos de **otro** tipo | The Mimic |
| `ability.twoEntities` | **Dos** cuerpos, uno decoy | The Twins |
| `ability.scream` | Grito dirigido a su objetivo | Banshee |
| `ability.paranormalSoundInterval` | 80-127 s (Myling 64-127) | todos |
| **`ability.onCatch`** | **`"kill"` o `"banish"`** — qué pasa cuando te alcanza | ver abajo |

### 5.4 El desenlace: matar o desterrar **[decisión del autor]**

El hunt que te alcanza **no hace lo mismo en todos los tipos**. Es un rasgo más:

```lua
ability.onCatch = "kill"     -- Demon, Revenant, Oni, Hantu, Moroi…  los letales
ability.onCatch = "banish"   -- Shade, Yurei, Phantom, Wraith, Goryo…  los rituales
```

- **`kill`** — muerte normal de GMod + jumpscare. Fiel al juego. Barato de implementar.
- **`banish`** — la dimensión de HIM: teleport a `Vector(80000,80000,80000)`, niebla negra a 800 u,
  skybox tapado, controles invertidos, `PreventTransmit` recursivo. Ver §7 del documento hermano.

Que el desenlace sea un rasgo tiene una consecuencia buena de diseño: **el jugador aprende a temerle
a tipos distintos por razones distintas**, y el destierro deja de ser un truco del addon para pasar a
ser una pista de identificación más — que es exactamente cómo funciona Phasmophobia.

**Falta definir:** cómo se vuelve del destierro (¿tiempo? ¿otro jugador? ¿un ritual?). No lo decido
solo; queda anotado como pregunta abierta.

**`The Mimic` y `The Twins` son las dos pruebas de fuego del diseño.** Si el motor está bien cortado,
el Mimic es `self.type = table.Copy(PHANTOM_TYPES[otroAlAzar])` cada N segundos, y los Twins son dos
entidades compartiendo un `phantom_TwinID`. Si alguno de los dos necesita un `if` especial en el
cerebro, hay que rediseñar antes de seguir.

---

## 6. Los 30 tipos — estado del conocimiento **[importante]**

De los 30 de la imagen, **conozco con confianza 24**. Los seis restantes son adiciones que **no pude
verificar**: la wiki devuelve 402 y la búsqueda web no trajo datos fiables.

**Verificables por conocimiento previo (24):** Spirit, Wraith, Phantom, Poltergeist, Banshee, Jinn,
Mare, Revenant, Shade, Demon, Yurei, Oni, Yokai, Hantu, Goryo, Myling, Onryo, The Twins, Raiju,
Obake, The Mimic, Moroi, Deogen, Thaye.

**NO verificados — te los pregunto (6):** **Aswang, Gallu, Kormos, Deildegast, Obambo, Dayan.**

De Obambo la búsqueda dio esto, y **lo doy como [lectura de tercero], no como verificado**: fuerza =
mientras está agresivo empieza a cazar rápido; debilidad = mientras está calmo es más fácil de
rastrear y caza lento; evidencias = Ghost Writing, UV, D.O.T.S.
([Sportskeeda](https://sportskeeda.com/esports/all-ghost-types-available-phasmophobia-attributes))

**Esto no bloquea nada.** La tabla de tipos es un archivo de datos: se completa cuando me pases los
seis, y el motor no cambia. Lo que sí importa es que ninguno de los seis exija un rasgo que no esté
en §5 — por eso te pido las **habilidades**, no el lore.

---

## 7. El sonido

### 7.1 Lo que hay

**265 `.wav`** en [`dev2/phasmo-sounds-main/`](../../dev/other/phantom/dev2/phasmo-sounds-main/) (141 MB) más **151 `.ogg`**
en paranormal events, de los cuales **68 no los usa nadie**.

Mapeo directo de lo que **sí** puedo identificar por nombre y duración:

| Uso en PHANTOM | Archivos | n |
|---|---|---:|
| Pasos del fantasma | `GhostFootstepCarpet1-8` | 8 |
| Pasos del jugador | `FootstepCarpet*`, `FOOTSTEP_*` (asfalto/grava/madera), `Stairs footsteps*` | ~50 |
| Tirar objetos (Poltergeist) | `Throwing 1-11` | 11 |
| Golpes / impactos | `Wood Impact 1-6`, `wood-1..6`, `IMPACT_*`, `metal-pipe-*` | ~18 |
| Puertas | `Door close 03-07`, `Door handle open 01-07`, `DOOR_Indoor_Wood_*`, `Door Loop` | ~15 |
| Golpeteo (ghost event) | `DoorKnocking`, `Window Knocking 1-6` | 7 |
| Muebles | `Cabinet Close 1-5`, `Drawers close 1-5`, `Cabinet/Drawers loop` | 12 |
| Luces / electricidad | `Lightswitch 1-4`, `LightbulbSmashSFX`, `Light_Humming`, `Flashlight Click` | 7 |
| Interferencia (hunt) | `Radio Static Noise`, `EMF Sound`, `EVP White Noise Loop`, `Walkie Talkie Static` | 4 |
| Latido a 10 m | `Heartbeat (loop) 2` | 1 |
| Muerte del jugador | `Death Jumpscare Riser`, `Player Dying SFX`, `Death` | 3 |
| Ambiente | `Nights Ambience Neighborhood`, `Rain`, `THUNDER_*`, `ThunderClap_*`, `Dark Cinematic Horror Room Tone 2` | ~10 |
| Trastos de casa | `Tv On/Off/Noise`, `PhoneRing`, `Fridge loop`, `Sink loop`, `TOILET_Flush`, `Clock Ticking`, `CeilingFan`, `Microwave Beep` | ~12 |

### 7.2 Lo que **no** sé, y te pregunto — §8

Hay tres grupos que no puedo mapear sin escucharlos, y por tu regla no los asumo. Están en §8.

### 7.3 Conversión a `.ogg` — **HECHA** [verificado]

Los 265 `.wav` sumaban **141 MB**, que GMod le haría descargar entera a cada cliente.
Convertidos el 2026-08-01 a Vorbis `q4 44.1 kHz`:

| | Antes | Después |
|---|---:|---:|
| Tamaño | 141 MB | **11 MB** (−92 %) |
| Archivos | 265 | **265** (0 fallos) |

- **Origen intacto:** [`dev2/phasmo-sounds-main/`](../../dev/other/phantom/dev2/phasmo-sounds-main/) no se tocó.
- **Salida:** [`dev2/phasmo-sounds-ogg/`](../../dev/other/phantom/dev2/phasmo-sounds-ogg/)
- **Nombres normalizados** para GMod: minúsculas, `_` en vez de espacios, sin paréntesis.
  `Ghost 1 (light attack).wav` → `ghost_1_light_attack.ogg`.
- **Verificado:** duraciones idénticas al original en la muestra contrastada
  (82,502 s / 4,049 s / 0,599 s / 0,342 s / 25,443 s — **delta 0,000 s** en los cinco).

Herramienta: `ffmpeg 8.1.2`, instalado en el sistema del autor con `winget install Gyan.FFmpeg`
durante esta sesión.

---

## 8. Lo que necesito que me digas

### 8.1 Sonidos — los tres grupos que no puedo identificar

**Grupo A — palabras sueltas (23 archivos, 0,3-0,6 s cada uno).** Supongo que son respuestas de voz
del **Spirit Box**, pero no sé *qué voz* (¿masculina? ¿femenina? ¿susurro? ¿varias?) ni si algunas
son del **Ouija Board**:

> `Adult` `Baby` `Child` `Kid` `Young` `Old` — suenan a respuestas de «how old are you?»
> `Dad` `Mum` `Son` `Daughter` — a respuestas de parentesco
> `Attack` `Away` `Behind` `Close` `Far` `Here` `Hate` `Hurt` `Kill` `Die` `Death` `Next` `Beep`

**Grupo B — vocalizaciones del fantasma (5 archivos, 2-4 s).** Los nombres hablan de daño y ataque,
pero en Phasmophobia el fantasma no recibe daño, así que no sé qué son en realidad:

> `Ghost 1 (damaged)` `Ghost 1 (light attack)` `Ghost 2 (damaged)` `Ghost 2 (light attack)` `Ghost 2 (strong attack)`

¿Son las **vocalizaciones de hunt/manifestación** (las 7 masculinas y 6 femeninas que menciona la
wiki)? Si lo son, me sirven como el «fingerprint sonoro» del contrato.

**Grupo C — sueltos que no ubico:**

> `Hint Aggressive Ghost` / `Hint Friendly Ghost` (×2) / `Hint Non Friendly Ghost` (×2) / `Hint None` (×3) — 2,5-6,8 s. ¿Ouija? ¿respuestas del spirit box largas?
> `ManHumming` / `WomanHumming` — 25 s cada uno. ¿El tarareo de un ghost event?
> `MetalWhine1/2` (1,1 s) · `MainToneLoop` (82 s) · `DeathZoneLoop` (14 s) · `Clicker_idle_26` (2,6 s) · `BearLaugh` · `GuitarSound` · `PianoKey1-5`

### 8.2 Los seis fantasmas que no conozco

**Aswang, Gallu, Kormos, Deildegast, Obambo, Dayan** — necesito **habilidad, fuerza y debilidad** de
cada uno (las evidencias son secundarias). Con eso completo la tabla de §6 y verifico que no haga
falta ningún rasgo nuevo en §5.

### 8.3 Decisiones ya tomadas (2026-08-01)

| Pregunta | Respuesta del autor |
|---|---|
| Velocidad | **Relativa al jugador**, vía Better Movement. Ver §1.1 |
| Desenlace del hunt | **Ambas según el tipo** — `ability.onCatch`. Ver §5.4 |
| Audio | **Convertir a `.ogg`** — hecho, §7.3 |

### 8.4 Cómo se vuelve del destierro **[decidido]**

**Dos salidas, y la asimetría es a propósito:**

| Salida | Quién la usa | Qué cuesta |
|---|---|---|
| **Morir** | el que se rindió | Rápida y aburrida. Siempre disponible. Perdés lo que llevabas |
| **Ritual** | los que están afuera | Lenta, pide equipo y coordinación. **Te trae de vuelta al mundo** |

La gracia es que la salida buena **no depende de vos**: depende de que alguien afuera se tome el
trabajo. Eso convierte el destierro en un evento de grupo en vez de un castigo individual, y le da
sentido al equipamiento — que es lo que hace que esto pueda sostener un gamemode si alguien lo
recoge. En una partida solo, el destierro es una muerte con más ceremonia; en grupo, es una misión
de rescate.

**Falta definir qué es el ritual concretamente** (qué objetos, dónde, cuánto tarda). Se decide junto
con el equipamiento, porque depende de qué props terminen portados.

---

## 9. Qué se recicla de `[gm] paranormal events`

> **⚠ Esta sección subestimó al mod. Leer §11 antes que esto.** Decir «banco de efectos, no sistema»
> fue un error de evaluación: el mod implementa los mismos conceptos que Phasmophobia, con los mismos
> nombres —orbes, favourite room, aggro, hunt, los tres tipos de manifestación—. Lo que está roto es
> la implementación, no el diseño. Lo de abajo sigue siendo cierto como inventario de *funciones
> llamables*; §11 es la lectura correcta del mod.

Sus funciones son globales y se llaman directo:

```lua
CreateShadowFigure( pos )         -- manifestación tipo "shadow" (la sana; respeta el argumento)
GhostInteractWithDoor()           -- puerta que se abre sola y se cierra en 3-15 s
FlingNearbyPhysicsProps( self )   -- ← el Poltergeist, literalmente
BreakNearbyProps( self )          -- versión brutal, para el Oni/Demon
ParticleEffectAttach( "gmpa_shadow_figure_clouds", PATTACH_POINT_FOLLOW, self, 0 )
table.Random( ghostwhispers )     -- 14 susurros: voc_comehere_01, voc_followme, voc_overhere
```

**Con la advertencia de §8 del documento hermano:** tres de sus cuatro efectos de partícula están
muertos por un `IsValid(Vector)`, así que las partículas conviene emitirlas a mano —
`ParticleEffect("gmpa_shadow_lurker", pos, Angle(0,0,0))` — que además da más control.

Sus **68 sonidos sin usar** siguen siendo la mejor fuente para el viaje a la otra dimensión:
`trans1..trans9`, `transformation_sigh_01..05` y los ambientes en loop.

---

## 10. Qué queda del diseño anterior

El documento hermano proponía un fantasma «que te observa y se aleja» con destierro a otra dimensión.
**Nada de eso se tira** — se reubica dentro de este marco:

| Idea del diseño anterior | Dónde vive ahora |
|---|---|
| Te observa de lejos, se aleja si lo mirás | El estado **IDLE/ROAMING** y el tipo **Phantom/Shade** (tímidos) |
| `movement_watch` con `enemyBearingToMeAbs` | El rasgo `shyness` — la wiki lo nombra como identificador propio de cada contrato |
| Invisible, se materializa donde no mirás | **Ghost event / manifestación** |
| La dimensión extra (teleport a 80000³) | **El desenlace de un hunt exitoso** — en vez de matarte, te destierra |

Ese último punto es el que más gana con el cambio: en Phasmophobia el hunt que te alcanza **te mata**,
y una muerte en GMod es barata y aburrida. **Que te mande a la dimensión vacía en lugar de matarte**
es más memorable, es reversible, y reutiliza la maquinaria de HIM que ya está escrita y estudiada.

---

## 11. `[gm] paranormal events` es 1:1 con Phasmophobia — corrección

> **Corrección de §9.** En la primera pasada lo describí como «banco de efectos, no sistema». **Me
> quedé corto y el autor tenía razón.** Leído con la lente de Phasmophobia, el mod no es un banco de
> efectos: es **un mini-Phasmophobia entero**, con los mismos conceptos y hasta los mismos nombres.
> Lo que está roto es la implementación, no el diseño.

### 11.1 El paralelismo, concepto por concepto **[verificado]**

| Concepto de Phasmophobia | En el mod | Estado del código |
|---|---|---|
| **Ghost Orbs** (evidencia) | `CreateGhostOrbs()` + partícula `gmpa_ghost_orb_green` | **muerto** (§11.2) |
| **Favourite Room** | convar `gmpa_favorite_room` + var `favoriteRoom` | **hardcodeado** (§11.2) |
| **Hunt** | `gmpa_aggro_threshold`, `CheckPlayerAggro()`, `HuntPlayer()` | primitivo, sin pathfinding |
| **Cordura / aggro** | `aggroLevels[ply]`, sube por cercanía y por linterna apagada | vivo y usable como modelo |
| **Interferencia electrónica** | `gmpa_flashlight_effect`, `FlashlightFlicker()`, `gmpa_flashlight_flicker_chance` | vivo |
| **Luces parpadeando** | `gmpa_flickering_lights` | vivo |
| **Ghost event: manifestación** | `CreateGhostApparition()` (visible), `CreateShadowFigure()` (sombra), `CreateShadowLurker()` (translúcida) | **son los tres tipos que nombra la wiki** |
| **Interacción con puertas** | `GhostInteractWithDoor()` | vivo |
| **Tirar / romper objetos** | `FlingNearbyPhysicsProps()`, `BreakNearbyProps()` | vivo |
| **Acecho** | `GhostStalkingBehavior()`, `GhostPeekAroundCorner()` | vivo |
| **Sonidos paranormales** | `PlayCreepySound()`, `gmpa_sounds` | vivo |
| **Radio de eventos** | `gmpa_radius` = **2048 u** (≈39 m) | vivo |
| **Frecuencia de actividad** | `gmpa_frequency`, `gmpa_delay_event_min/max` | vivo |

Los tres tipos de manifestación son literalmente los de la wiki: *«the ghost can be fully visible,
appear as a shadow, or have a dark translucent-like appearance»*.

**Su tabla de convars es el mejor borrador que tenemos de la nuestra.** 24 convars con el reparto de
responsabilidades ya pensado: un master, uno por familia de evento, y los tiempos separados en
min/max. Eso se copia de forma, no de código.

### 11.2 Por qué igual hay que reimplementarlo **[verificado leyendo el archivo]**

Tres defectos concretos, todos confirmados a mano:

1. **`if !IsValid(pos) then return end` sobre un `Vector`** — líneas 852, 860 y 868. `IsValid()` de
   un Vector es **siempre false**, así que `CreateCockRoachSwarm`, `CreateShadowLurker` y
   **`CreateGhostOrbs` nunca llegan a emitir su partícula**. Los orbes —una evidencia entera— están
   muertos en el mod. Peor: las tres funciones **pisan su propio argumento** (`local pos = ...`) en
   la línea de arriba, así que aunque se arreglara el `IsValid`, seguirían ignorando el punto que se
   les pasa.
2. **`favoriteRoom = Vector(1000, 1000, 100)`** — línea 93, hardcodeado, con el comentario del propio
   autor: `-- Set a "favorite" room position (change this based on your map)`. La favourite room del
   mod es un punto fijo que sólo cae bien por casualidad. **Ésta es exactamente la carencia que
   resuelve §14.**
3. **`GetConVar("gmpa_ghost_damage")` sin `CreateConVar`** — la convar se lee en `GhostDealDamage()`
   y **no se crea en ningún lado**. La función es inalcanzable.

Y `HuntPlayer()` mueve al fantasma con `ghost:SetPos(pos + dir * 10)`: teleporte de 10 u por tick,
sin navmesh y atravesando paredes. **Nuestra base hace eso infinitamente mejor** — es la razón por la
que existe este proyecto.

### 11.3 Qué tomamos, entonces

- **El catálogo de eventos y la forma de las convars** — como especificación, ya validada por alguien
  que hizo el mismo ejercicio.
- **Los assets**: las partículas (`gmpa_ghost_orb_green`, `gmpa_shadow_lurker`,
  `gmpa_shadow_figure_clouds`), los 151 sonidos, `homm.mdl`.
- **Las funciones sanas**, llamadas directo: `GhostInteractWithDoor()`, `FlingNearbyPhysicsProps(self)`,
  `BreakNearbyProps(self)`, `CreateShadowFigure(pos)`.
- **Los orbes los reimplementamos** en dos líneas, esquivando el bug:
  `ParticleEffect("gmpa_ghost_orb_green", pos, Angle(0,0,0))`.

---

## 12. Spawn: convar automático y menú

Dos vías, porque sirven a dos usuarios distintos.

### 12.1 Automático — la vía del gamemode

```
phantasmagoria_autospawn        0     cuántos fantasmas mantener vivos (0 = apagado)
phantasmagoria_autospawn_types  ""    lista separada por comas; vacío = sorteo entre los 30
phantasmagoria_autospawn_delay  30    segundos entre reintentos de spawn
```

Un `timer` server-side mantiene la población en `phantasmagoria_autospawn`. Si un fantasma muere o
se lo borra, repone al cabo de `_delay`. **El tipo se sortea y no se anuncia** — que es justamente el
punto del juego: hay que identificarlo.

Esto es lo que un gamemode quiere: pone `phantasmagoria_autospawn 1` al empezar la ronda, `0` al
terminar, y no necesita saber nada más de nuestra API.

### 12.2 Desde el menú — la vía del sandbox

**Un NPC por tipo en la pestaña NPCs**, con su nombre real. La base ya resuelve el registro y la
herencia de categoría (`terminator_Extras.RegisterNPC`, doc en `sh_terminator_registernpc.lua:42-65`):

```lua
-- se generan los 30 en un bucle, no se escriben a mano
for key, data in pairs( PHANTASMAGORIA.Types ) do
    local ENT = {}
    ENT.Base        = "terminator_nextbot_phantom"
    ENT.PrintName   = data.name                    -- "Oni", "Poltergeist", "The Twins"…
    ENT.Category    = "Phantasmagoria"
    ENT.SubCategory = "Fantasmas"
    ENT.Spawnable   = true
    ENT.PhantomType = key
    scripted_ents.Register( ENT, "phantasmagoria_" .. key )
    terminator_Extras.RegisterNPC( "phantasmagoria_" .. key, ENT )
end
```

Más una entrada `phantasmagoria_random` que sortea. Y un `concommand` equivalente para el que
prefiera la consola:

```
phantasmagoria_spawn <tipo>     spawnea en el trace del que lo ejecuta
```

> **Trampa a respetar:** `RegisterNPC` difiere el registro a un `timer.Simple(0)` para que
> `.Category`/`.SubCategory` se hereden por el árbol de bases. Si el bucle corre después de ese
> timer, hay que llamar `spawnmenu_reload`. Está documentado en la línea 72 del archivo.

---

## 13. La dificultad

En Phasmophobia la dificultad no cambia al fantasma: cambia **cuánta ayuda te da el juego**. Una sola
convar, con presets:

```
phantasmagoria_difficulty   1    0=amateur 1=intermediate 2=professional 3=nightmare 4=insanity
```

| | Amateur | Intermediate | Professional | Nightmare | Insanity |
|---|---|---|---|---|---|
| **Se queda en su cuarto** | **sí** | se mueve poco | libre | libre | libre |
| Evidencias que muestra | 3 | 3 | 3 | **2** | **1** |
| Cordura inicial | 100 % | 100 % | 100 % | 100 % | 75 % |
| Velocidad de pérdida | ×1,0 | ×1,0 | ×1,2 | ×1,5 | ×2,0 |
| Tiempo de gracia (setup) | 5 min | 2 min | 0 | 0 | 0 |
| Actividad del fantasma | baja | media | alta | alta | alta |

**«Se queda en su cuarto» es lo que hace falta que exista §14.** En amateur el fantasma tiene una
favourite room y no sale de ella salvo para cazar; en profesional o más, deambula por todo el mapa.

Las evidencias se ocultan **quitando de la lista** que el fantasma muestra, no cambiando su tipo: un
Oni en Insanity sigue siendo un Oni y sigue teniendo sus tres evidencias reales — pero sólo una es
observable, y el jugador tiene que deducir el resto por comportamiento. Eso ya está soportado por la
tabla: `evidence` es una lista de tres, y la dificultad decide cuántas se *emiten*.

---

## 14. Cuartos: cómo se mapea un escenario **[el pedido más técnico]**

Un cuarto es, como dijo el autor: **un conjunto de navareas conectadas con techo encima**. Hace falta
para la favourite room, para «se queda en su cuarto» en dificultad baja, y para saber dónde pueden
aparecer los ítems malditos (tarot, calaveras, muñeca vudú, espejo, caja de música, reloj de arena).

### 14.1 La primitiva ya existe y está probada **[verificado]**

HIM resuelve «¿esto tiene techo?» y lo cachea por navarea —
[`sv_zhomeless_shelter.lua:272-303`](../../dev/other/phantom/dev2/him/lua/autorun/server/sv_zhomeless_shelter.lua#L272):

```lua
local function IsUnderSkyPos( pos )
    pos = pos + vecUpOff
    local skyTraceResult = util.TraceLine( {
        start  = pos,
        endpos = pos + vec12kZ,          -- 12.000 u hacia arriba
        mask   = CONTENTS_SOLID,
    } )
    if skyTraceResult.HitSky then return true          -- ve el cielo -> a la intemperie
    elseif not skyTraceResult.Hit then return true     -- no golpea nada -> idem
    else return false end                              -- golpeó techo -> es interior
end
```

Y encima lo envuelve en `IsUnderSky( area )` **con caché por `CNavArea`**, que es exactamente el
granulado que necesitamos. Hay dos alternativas más, y conviene conocerlas:

| Método | Costo | Nota |
|---|---|---|
| `IsUnderSkyPos` (HIM) | **1 trace** | El más barato. Un hueco en el techo lo engaña |
| `get_env_state` (Better Movement, `sh_bm_main.lua:169`) | **5 traces** (centro + 4 a 120 u) | Más robusto contra huecos. Ya networkeado como `ply:GetBmEnvIsInside()` |
| `GetNookScore` (base Terminator) | varios | Mide *encierro*, no techo: ≥4 = rincón, ≤2,5 = abierto |

**Recomiendo el de 5 traces para el mapeo** (corre una vez, offline) y el de 1 trace para consultas
en runtime.

### 14.2 El detector automático

Flood fill sobre el navmesh, en una corrutina presupuestada (el patrón que HIM ya usa a 0,5 ms por
`Think`, `sv_zhomeless_shelter.lua:2614-2666`):

```
1. Para cada CNavArea del mapa: ¿tiene techo?  -> se cachea
2. Semilla: una navarea con techo sin cuarto asignado
3. Expandir por area:GetAdjacentAreas() mientras el vecino:
      - tenga techo
      - NO esté separado por una puerta (prop_door_rotating / func_door en el borde)
      - no supere el diámetro máximo del cuarto (convar, default ~1200 u)
4. El grupo resultante es un cuarto. Repetir hasta que no queden áreas.
5. Descartar cuartos de menos de N áreas (pasillos residuales).
```

El corte por puertas es lo que evita que una casa entera salga como un solo cuarto. **No va a ser
perfecto** —los mapas de GMod no fueron hechos para esto— y por eso existe 14.3.

### 14.3 La herramienta manual

**Una toolgun**, `phantasmagoria_rooms`, porque el automático siempre se va a equivocar en algún mapa:

| Acción | Qué hace |
|---|---|
| **Disparo primario** | Agrega la navarea bajo el cursor al cuarto activo |
| **Disparo secundario** | La quita |
| **Recargar** | Crea un cuarto nuevo y lo hace activo |
| **Panel** | Nombrar el cuarto, marcarlo como *favourite room* válida, marcar si acepta ítems malditos |

Con render de debug: cada cuarto pintado de un color distinto sobre el navmesh
(`debugoverlay.Box` / el patrón de `navmesh.GetAllNavAreas()`), para ver el mapeo mientras se corrige.

Y los comandos de consola equivalentes, que es lo que realmente se usa cuando se está mapeando:

```
phantasmagoria_rooms_detect        corre el detector automático
phantasmagoria_rooms_show 1        pinta los cuartos sobre el navmesh
phantasmagoria_rooms_save          guarda a disco
phantasmagoria_rooms_clear         borra el mapeo del mapa actual
```

### 14.4 Persistencia y puntos de ítem

```
data/phantasmagoria/rooms_<nombre_del_mapa>.json
```

```json
{
  "map": "gm_construct",
  "rooms": [
    { "id": 1, "name": "Sótano", "areas": [412, 413, 419],
      "favourite": true, "cursedSpots": [[128, -320, 64]] }
  ]
}
```

Los `areas` son IDs de `CNavArea` (`area:GetID()`), que son estables mientras no se regenere el
navmesh. **Si alguien corre `nav_generate`, el mapeo se invalida** — hay que detectarlo y avisar, no
fallar en silencio.

Los `cursedSpots` son los puntos donde pueden aparecer los ítems malditos. Se marcan con la misma
toolgun (un cuarto modo) y son posiciones de mundo, no áreas, porque un ítem se apoya en una mesa.

### 14.5 Qué pasa si no hay mapeo

**Degradar, nunca romper.** Si el mapa no tiene cuartos marcados:

- La favourite room es **una sola navarea con techo**, elegida por `GetNookScore` alto (la más
  metida en un rincón). Es peor que un cuarto real, pero funciona.
- «Se queda en su cuarto» pasa a ser «se queda dentro de un radio de N unidades» de esa área.
- Los ítems malditos aparecen en navareas con techo al azar.

Nunca hay un estado en el que el addon no arranque por falta de mapeo. Eso importa porque el 99 % de
los mapas de GMod nunca van a tener uno.
