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
| **Hunt**: perseguir y matar | El cerebro entero de la base | **gratis**, pero ver §18 |
| **Flicker** durante el hunt | `CloakedMatFlicker` del módulo wraith | **gratis** |
| Invisible fuera del hunt | `ENT.IsWraith = true` | **gratis** |
| Roaming entre puntos | Pathing + navmesh de la base | **gratis** |
| ~~No salir del área de investigación~~ | ~~`ENT.hazardousAreas`~~ | **REFUTADO — §18.1** |
| Abrir/golpear puertas | `terminator_doorbash.lua` + `GhostInteractWithDoor()` | **gratis** |
| Tirar objetos (Poltergeist) | ~~`FlingNearbyPhysicsProps(self)` de paranormal~~ **escrito propio**: `server_events.lua` (§21) | **escrito, sin correr en juego** |
| Pasos audibles a 20 m | `ProcessFootsteps` + `IsSilentStepping()` | **gratis** |
| Silencio del Myling | `function ENT:IsSilentStepping() return true end` | **gratis** |
| Manifestación (ghost event) | `CreateShadowFigure(pos)` + partículas gmpa | **gratis** |
| Elegir dónde aparecer sin ser visto | `posIsInterrupting(pos)` | **gratis** |
| «El jugador me está mirando» | `enemyBearingToMeAbs(ply) < 9` | **gratis** |
| Favourite room | Guardar una `CNavArea` | trivial |
| Estados / cordura / evidencias | — | **hay que escribirlo** |

**Lo que hay que escribir de cero son tres cosas:** la máquina de estados de §3, el sistema de
cordura, y la tabla de rasgos de §5. Nada de eso es difícil; lo difícil ya está heredado.

> **⚠ Esta tabla se leyó de nuevo contra el código el 2026-08-03 y dos filas no sobrevivieron.**
> `hazardousAreas` **no** encierra al fantasma, y «el hunt es gratis» oculta que el hunt heredado es
> el de un cazador que te encuentra, no el de un fantasma al que se le puede escapar. Las dos, más el
> agujero de esconderse, en **§18**. El resto de la tabla sigue en pie.

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

La forma correcta es **un solo lugar que no congela nada**. Este párrafo decía que ese lugar era la
*relación*, y **era la función equivocada** — la corrección está abajo.

> ### ⚠ CORREGIDO 2026-08-06 — **REFUTADO EN JUEGO**: la relación no sirve de interruptor
>
> **El motivo ① está MEDIDO** (corrida 4): con el control disparado un segundo antes
> (`phantasmagoria_hunt_reeval` movió el contador `1 -> 2`), prender el hunt lo dejó **en 2**. Nada
> re-evalúa. El motivo ② sigue siendo **[lectura]** — ver el límite declarado en
> [ESTADO.md](../ESTADO.md).
>
> Lo que decía este bloque:
>
> ```lua
> function ENT:OnFirstRelationWithPlayer( ply )
>     return self.phantom_Hunting and D_HT or D_NU
> end
> -- "Al entrar en hunt se re-evalúan relaciones y la base hace el resto sola."
> ```
>
> **No funciona, por dos razones independientes:**
>
> **① Nada re-evalúa.** `SetupRelationships` corre **una sola vez**, desde `Initialize`
> ([`shared.lua:3079`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/shared.lua#L3079)),
> y el resultado se **guarda** con `Term_SetEntityRelationship`
> ([`enemyoverrides.lua:883`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L883),
> cuerpo en [`terminator_nextbot_base/enemy.lua:44-47`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot_base/enemy.lua#L44)).
> Es un **cache**. El nombre lo venía diciendo: `OnFirst…`.
>
> **② Y aunque re-evaluara, no aguanta.** `MakeFeud`
> ([`enemyoverrides.lua:1046-1048`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L1046))
> reescribe la relación del jugador a `D_HT` prioridad 1000 en cuanto al bot le pegan
> (`PostTookDamage`, [`damageandhealth.lua:482`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/damageandhealth.lua#L482)).
> **Un interruptor de relaciones se reabre de un balazo** y no se vuelve a cerrar.
>
> **El interruptor es `ShouldBeEnemy`**, que es donde la base *lee* ese cache
> ([`enemyoverrides.lua:493`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L493))
> y se consulta en vivo por seis caminos —los tres de adquisición de §18.7 más `ForgetOldEnemies`
> (`:676`, el que **suelta** al enemigo), la revalidación de `shared.lua:3282` y `HaveEnemy`—:
>
> ```lua
> function ENT:ShouldBeEnemy( ent, fov, myTbl, entsTbl )
>     myTbl = myTbl or self:GetTable()
>     if not myTbl.phantom_Hunting then return false end
>     return myTbl.BaseClass.ShouldBeEnemy( self, ent, fov, myTbl, entsTbl )
> end
> ```
>
> `OnFirstRelationWithPlayer` **sigue habiendo que escribirla**, pero encadenando al `BaseClass`
> (implementa `ExtraSpawnHealthPerPlayer`, `damageandhealth.lua:872`) y **sin devolver `D_NU`**: un
> `D_NU` ahí trabaría el interruptor **cerrado para siempre**, porque `:493` exige `D_HT` y nada
> re-evalúa el cache. Queda como instrumento que cuenta re-evaluaciones.
>
> Es el **mismo punto único** que §18.7 ya reservaba para el corte por distancia, así que las dos
> cosas van a convivir en esta función. **Sin correr:** el check está en
> [ESTADO.md](../ESTADO.md).

El bot nunca deja de pensar, sólo deja de tener a quién odiar — esa última frase sí se sostiene, y es
justamente lo que un `false` en `ShouldBeEnemy` consigue: las 31 tareas siguen corriendo enteras.

---

## 4. Cordura y hunt

La cordura es del **jugador**, no del fantasma, y es la variable que gobierna todo el juego.

- Baja con: oscuridad, ver manifestaciones, estar cerca del fantasma, hunts.
- Sube con: pastillas, luz.
- Cuando el promedio (o el mínimo, según el tipo) cae bajo `huntThreshold`, el fantasma **puede**
  cazar.

Se implementa como un número por jugador en el servidor, networkeado para el HUD. Es independiente
de la base Terminator: no hay nada que heredar acá, pero tampoco nada difícil.

> **§19 desarrolla todo esto** (2026-08-03) — incluida la **trampa de NEAD**, que activa la mecánica
> que §18.2 descartó. Y la mitad del equipo de cordura ya estaba diseñada en
> [EQUIPAMIENTO.md §3.5](EQUIPAMIENTO.md): la barra de Cargo, la vela que frena el drenaje y los
> costos de las 7 posesiones. **Estas diez líneas nunca fueron todo el diseño de cordura**, sólo la
> parte que vive en este archivo.

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
| ~~`hunt.blinkRate`~~ → `hunt.blink` | **Dos duraciones**, `visible` e `invisible`, en segundos | ⚠ ver abajo y **§20.6** |
| `hunt.rangeMul` | Radio de interferencia (default 525 u) | Raiju 787 u |
| `hunt.canOpenDoors` | Si abre puertas persiguiendo | casi todos |
| `hunt.crucifixRange` | Radio del crucifijo (default 157 u) | Demon 262 u |
| `hunt.hearsOnly` | Sólo detecta por sonido, no por vista | Deogen (te encuentra siempre) |
| `hunt.deafRadius` | Sordo salvo muy cerca | Yokai |
| `hunt.targetsOne` | Fija un solo objetivo | Banshee |

> ⚠ **`hunt.blinkRate` no existe en la tabla, y su ejemplo de esta tabla no tiene respaldo**
> [2026-08-08]. Los 30 tipos traen `hunt.threshold` y `thresholdLow`/`High`, **y nada más**: el
> parpadeo hay que agregarlo. Y el *«Deogen lento, Yokai rápido»* que decía esta fila salió de algún
> lado que no es la fuente generada — los comentarios del **Yokai** hablan de voz, música y distancia
> de detección, y **ninguno menciona visibilidad ni parpadeo**. Los que sí lo mencionan son
> **Phantom** (*«less visible during hunts»*), **Oni** (*«blinks more frequently … making them more
> visible»*) y **Deogen** (*«is more visible during hunts»*).
>
> ⚠ **Y ojo con la palabra:** en Phasmophobia *blink* es el momento en que **aparece**, no el momento
> en que desaparece. Con el sentido invertido, el Oni sale invisible y el Phantom visible — y las dos
> fuentes seguirían pareciendo correctas.
>
> ⭐ **RESUELTO en §20.6 [2026-08-08], y no fijando el sentido por escrito sino cambiando el nombre:**
> el campo pasa a ser `hunt.blink = { visible = {min,max}, invisible = {min,max} }`, en segundos.
> *Una duración trae su dirección adentro; una frecuencia no.* `blinkRate` queda prohibido en el
> código. El dato va **a mano y en un archivo aparte** (`lua/phantasmagoria/ghost_blink.lua`),
> porque `ghost_types.lua` es generado — y **hoy ni siquiera se puede regenerar: `dev/g2.json` no
> está en el repo**, y el esquema del generador no tiene ningún campo de parpadeo.

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
| ~~Pasos del fantasma~~ | ~~`GhostFootstepCarpet1-8`~~ | **REFUTADO — §7.4** |
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

### 7.2 Lo que no sabía — **CERRADO** (2026-08-03)

Los tres grupos de §8.1 los escuchó el autor y los describió uno por uno. Los **46** archivos de
`_sin_identificar/` están catalogados y esa carpeta ya no existe. El detalle por archivo —qué dijo
el autor, qué se midió, y las transcripciones de las líneas habladas— vive en
`sound/phantasmagoria/about.txt`, que es lo único del árbol de sonido que se versiona.

Lo que la identificación **agregó** al diseño:

| Uso en PHANTOM | Carpeta | n |
|---|---|---:|
| Respiración del fantasma cazando | `ghost/hunt/` | 1 |
| El fantasma se acerca y come cordura | `ghost/scare_light/` | 2 |
| Ataque fuerte (**sólo voz 2**) | `ghost/scare_strong/` | 1 |
| Quejido de daño del fantasma | `ghost/hurt/` | 2 |
| Tarareo del ghost event de aparición | `ghost/humming/` | 2 |
| Respuestas del Spirit Box (voz masculina, literales) | `equipment/spiritbox_response/` | 22 |
| Beep del motion sensor | `equipment/motion_sensor_beep.ogg` | 1 |
| Loop de estar muerto — candidato para **la otra dimensión** | `player/dead_loop.ogg` | 1 |
| Tono de interior de la casa (82 s) | `ambience/house_tone_loop.ogg` | 1 |
| La voz del encargado (intel del caso + menú) | `voice/` | 18 |

**Las dos voces.** `voice_1` es más femenina, `voice_2` más grave. El índice **es** la voz: elegir
siempre el mismo entre carpetas es lo que hace que un fantasma suene a *un* fantasma — el
«fingerprint sonoro» que §5 pedía para que el jugador distinga un hunt de un ghost event. Y la
asimetría hay que respetarla: **`scare_strong` sólo existe para la voz 2**, así que un fantasma con
voz 1 degrada a `scare_light`, no suena en silencio.

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

### 7.4 Los pasos del fantasma: **botas** [medido + oído]

`ghost/footstep/boots_1-8` — y el camino hasta ahí vale más que el resultado.

Los 8 `GhostFootstepCarpet` estaban en `ghost/footstep/` **por su nombre**. Primera escucha del
autor: *«el paso es del jugador, yo lo reconozco del juego»* → se movieron al jugador y el fantasma
**quedó sin banco**, es decir caminando en silencio y sin error. Segunda escucha, con la pregunta ya
cambiada de *«¿de quién es la grabación?»* a *«¿para qué sirve acá?»*: *«muy parecidos a la pisada de
una **bota**»*, y *«como el jugador en Garry's Mod ya tiene su propio footstep, agregar este como
pisada de fantasma está ok»*. Volvieron, renombrados por lo que se oye.

**Las dos escuchas no se contradicen.** La grabación es de una persona caminando —por eso no eran
«los pasos del fantasma» de Phasmophobia— y el **uso** acá es el fantasma, porque al jugador GMod ya
le da los suyos. La carpeta dice el uso; el `about.txt` dice el origen. La lección de método:
**cambiar la pregunta cambió la respuesta sin que ningún dato cambiara.**

Y el banco sirve por una razón medible además del oído: §1 pide que el fantasma se oiga a **20 m
(~1050 u)**, y a distancia sólo sobrevive el grave.

| Banco | <250 Hz | <120 Hz | centroide |
|---|---:|---:|---:|
| `stairs_under` | 99,1 % | 93,9 % | 65 Hz |
| `wood` | 97,9 % | 96,6 % | 103 Hz |
| **`boots`** (el del fantasma) | **89,8 %** | 34,6 % | **183 Hz** |
| `stairs` | 72,5 % | 40,1 % | 214 Hz |
| `carpet` | 35,8 % | 6,9 % | 1217 Hz |
| `gravel` | 2,3 % | 0,5 % | 2261 Hz |

`carpet` y `gravel` son roce agudo: a 20 m no llegan. (`stairs_under` **no** es «pasos oídos desde
debajo de la escalera» — ésa fue una lectura del nombre del rip y el autor la refutó: son pisadas
**en** una escalera.)

Lo medido antes del primer movimiento, para no repetirlo:

- **No** son los mismos archivos que `player/footstep/carpet_1-8`: 16 hashes distintos, y el
  null-test (alineado por correlación cruzada, ganancia por mínimos cuadrados) da `corr` 0,32-0,80
  — exactamente el rango de los controles cruzados. **No es una copia con otra ganancia.**
- Pero las duraciones emparejan una a una: 0,342/0,335 · 0,382/0,372 · 0,396/0,392 · 0,396/0,368 ·
  0,333/0,327 · 0,302/0,299 · 0,296/0,285 · 0,292/0,290 — **delta 2-11 ms en 7 de 8**.
- Y el set está **~10 dB más fuerte**: media −17…−25 dB contra −27…−35 dB.

Lectura: misma superficie, **dos mezclas** — una audible en el mundo y una para tus propios pies.
Por eso `carpet_loud` y no `carpet_9..16`: en un solo pool el sorteo saltaría 13 dB entre pisada y
pisada. Y por eso siguen siendo el candidato natural cuando haya que darle pasos al fantasma.

La hipótesis alternativa —que fueran las escaleras— **no sobrevivió la medición**: `stairs_*` dura
0,25-0,52 s a −36…−43 dB y `stairs_under_*` 0,34-0,56 s a −21…−33 dB; ninguno de los dos empareja
como empareja `carpet_*`.

### 7.5 Ghost event: **los pasos lejanos** [pedido del autor, 2026-08-03]

> *«Estaba solo en mi casa y empecé a escuchar ruidos de alguien caminando lentamente con unas botas.
> Podríamos simular algo parecido: sonidos de pisadas a lo lejos del jugador.»*

**El rasgo ya existe:** `ability.paranormalSoundInterval` (§5.3), 80-127 s para todos, **64-127 el
Myling**. Y no hace falta banco nuevo — es `ghost/footstep/boots_*` tocado **lejos** y con cadencia
lenta. Lo que lo distingue de los pasos normales del fantasma no es el sonido: es **dónde** y **a qué
ritmo** suena.

Lo que hace que funcione, y que es todo decisión de implementación:

- **Se emite en una posición, no en la entidad.** El evento no debe delatar dónde está el fantasma
  de verdad: es un punto a media distancia, idealmente **fuera de línea de vista** (el detector de
  §14.1 ya sabe si hay pared en el medio). Si sonara en el fantasma sería un localizador gratis y
  mataría el spirit box, la parabólica y la caja de música de un saque.
- **Cadencia lenta y constante.** Lo que asusta es que sea *regular*: pasos aleatorios se leen como
  ruido ambiente, pasos parejos se leen como **alguien**. 3-5 pisadas por evento, no una.
- **Sin fuente visible.** Es la única forma de que el jugador dude de sí mismo, que es el punto.

**La asimetría del Myling la vuelve cruel, y ya está diseñada:** es el tipo que **camina en silencio
cazando** (`ENT:IsSilentStepping()`, §3) y el que **más sonido paranormal tira**. O sea: el que hace
ruido cuando no viene, y no hace ninguno cuando sí. No hay que escribir nada nuevo para eso — sale de
cruzar dos rasgos que ya están.

**Lo que falta decidir:** sin una herramienta para *oír a distancia*, el evento es ambientación pura
y no evidencia. Su consumidor natural sería la **parabólica** — que no tenemos, ver
[EQUIPAMIENTO.md](EQUIPAMIENTO.md) §9.

---

## 8. Lo que necesito que me digas

### 8.1 ~~Sonidos — los tres grupos que no puedo identificar~~ **CERRADO (2026-08-03)**

Los **46** los escuchó el autor. Lo que contestó, resumido:

| Grupo | Qué era |
|---|---|
| **A** — 23 palabras sueltas | **Spirit Box, voz masculina**, y **literales al nombre**: `adult.ogg` dice «adult». Salvo `Beep`, que es el **motion sensor** cuando algo lo cruza |
| **B** — 5 vocalizaciones | Sí eran las del fantasma, pero **por función, no por daño**: `light/strong attack` es el fantasma acercándose y comiéndote la cordura; `damaged` es un quejido de golpe. Y son **dos voces** — la 1 más femenina, la 2 más grave —, que es exactamente el «fingerprint sonoro» que pedía §5 |
| **C** — los 8 `Hint` | **No** eran Ouija ni spirit box: es **una voz británica**, el ayudante de la compañía, dando intel del caso al llegar. Mismo hablante que `arrival`, `welcome_back`, `lobby_*` y `menu_intro`, que estaban sueltos en `ui/`. Los 20 juntos hoy en `voice/`, con transcripción |
| **C** — sueltos | `ManHumming`/`WomanHumming` = el tarareo del ghost event de aparición (y de la cajita musical). `MainToneLoop` = tono de interior de la casa. `DeathZoneLoop` = el loop de estar muerto — **candidato para la otra dimensión**. `Clicker_idle_26` = la respiración del fantasma **cazando**. `BearLaugh` = el peluche del cuarto del bebé. `GuitarSound` = una cuerda de guitarra. `MetalWhine1/2` = movimiento metálico, probablemente una puerta |

Y una corrección al mapeo previo: **los `GhostFootstepCarpet` no eran del fantasma** — §7.4.

**Los 8 `hint` no se ordenan por su nombre.** Dos de los ocho contradicen su propio texto
(`hint_friendly_ghost_2` habla de *«reports of violence»*; `hint_non_friendly_ghost_1` empieza con
*«nothing to report»*), así que si la briefing se elige por agresividad, **el tier sale del contenido
y no del nombre** — la escalera está en `sound/phantasmagoria/about.txt`. Los nombres se conservan
porque son el único rastro hasta el rip. Sobre si alguno **nunca se usó** en el juego original: no es
verificable desde los archivos, y la señal de formato que lo habría apoyado **dio negativa** — el
rip tiene 5 formatos distintos y estas 8 caen todas en el mismo, con el mastering agrupado en
1,4 dB. Eso no refuta la sospecha; sólo dice que el archivo no la apoya.

El detalle por archivo está en `sound/phantasmagoria/about.txt`, con lo que quedó marcado como
**sospecha** del autor separado de lo que se midió.

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
FlingNearbyPhysicsProps( self )   -- el Poltergeist. CORRE ( 3 call sites, 2 vivos ). Ver §11.2
BreakNearbyProps( self )          -- NO rompe props. El nombre miente. Ver abajo
ParticleEffectAttach( "gmpa_shadow_figure_clouds", PATTACH_POINT_FOLLOW, self, 0 )
table.Random( ghostwhispers )     -- 14 susurros: voc_comehere_01, voc_followme, voc_overhere
```

> **Corrección de las dos últimas (2026-08-02, leyendo el archivo entero).** Este bloque decía «el
> Poltergeist, literalmente» y «versión brutal, para el Oni/Demon». Ninguna de las dos se sostiene:
>
> - ~~**`FlingNearbyPhysicsProps` no se llama nunca.**~~ **REFUTADO EL 2026-08-09, y por el mismo
>   error de método que este bloque existe para denunciar.** El párrafo decía: *«su **único** call
>   site (línea ~608) es `if IsValid(ghost) then FlingNearbyPhysicsProps(ghost) end`, y `ghost` ahí
>   es un global que no se declara en ninguna parte […] **nadie la ejerció jamás**»*.
>
>   **Son TRES call sites, no uno**, y dos están vivos:
>
>   | línea | call site | ¿corre? |
>   |---|---|---|
>   | `:612` | `if IsValid(ghost) then …` dentro de `RandomParanormalEvents` | **no** — `ghost` ahí sí es el global inexistente |
>   | `:1040` | `for _, ghost in ipairs(activeGhosts) do` — `ParanormalEventTimer` | **sí** |
>   | `:1055` | `for _, ghost in ipairs(activeGhosts) do` — `ParanormalGhostTimer` | **sí** |
>
>   `activeGhosts` se llena en `:946` (`table.insert`), dentro del `if SERVER` de `:915`. O sea que
>   **en el servidor, con una aparición viva, la función corre** — el `ghost` de los dos bucles es la
>   variable del `for`, no el global.
>
>   Lo que sí sobrevive del párrafo: la función **se lee sana** (radio 500, tope de 10 props, límite
>   de masa 10 kg, `ApplyForceCenter` random, sonido). Y una consecuencia que cambia de signo: el
>   `massLimit = 10` **sí** fue una tapa a algo que ocurría de verdad, porque la fuerza de gmpa
>   **no se escala por masa** (`:490`) y con impulso fijo la velocidad resultante es inversamente
>   proporcional a la masa.
>
>   ⚠ **La lección es la del propio bloque, cometida por quien lo escribió.** El párrafo original
>   decía «se leen los N o se declara cuáles no» tres secciones más arriba, y después escribió
>   **«su único call site»** habiendo leído uno. Un `grep FlingNearbyPhysicsProps` sobre el archivo
>   devuelve cuatro líneas —la definición y tres llamadas— y las tres llamadas estuvieron impresas
>   en pantalla todo el tiempo. *Declarar muerta una función es una afirmación sobre TODOS sus call
>   sites, así que exige contarlos; y es exactamente el tipo de afirmación que después se cita como
>   cerrada.* Esta entrada estuvo siete días en el documento y llegó a la memoria del proyecto.
> - **`BreakNearbyProps` no rompe props físicos.** Sólo a `func_breakable` le dispara `Fire("Break")`;
>   a un `prop_physics` le aplica **la misma fuerza random que Fling**, sin el límite de masa y sin
>   sonido. No es una versión brutal: es Fling con menos guardas y peor nombre.
>
> **La regla otra vez:** el nombre de una función miente igual que un comentario, y «la llama el
> propio mod» es una suposición hasta que se busca el call site.

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

#### Segunda pasada (2026-08-02): seis defectos más, leyendo las 1056 líneas

Los tres de arriba salieron de buscar bugs concretos. Éstos salieron de leer el archivo **entero**, y
el primero cambia cómo se siente el mod más que los otros cinco juntos:

4. **La escalera de eventos no es exclusiva.** `RandomParanormalEvents()` tira
   `math.random(1,100)` una vez y después encadena **nueve `if eventChance <= N`** —5, 10, 15, 25,
   30, 40, 50, 60, 80— **sin un solo `elseif`**. Un tiro de 3 dispara **los nueve**: puerta + luz
   rota + botón + sonido + sangre del techo + fling + parpadeo + susurro + una aparición, todo en el
   mismo frame. No es «un evento cada 120 s»: es una lotería donde a veces pasa **todo junto**. La
   forma que el autor claramente quiso —una tabla de pesos— es la que hay que copiar, no el código.
5. ~~**`FlingNearbyPhysicsProps` es inalcanzable**~~ **REFUTADO ( ver §11.2 ): tiene tres call
   sites y dos corren.** Lo que sí sobrevive de este punto: **`BreakNearbyProps` no rompe props
   físicos** —
   ver la corrección al bloque de §9.
6. **Fuga de timers a 33 Hz.** `timer.Create("GhostDistort_"..EntIndex(), 0.03, 0, ...)` y
   **`timer.Remove` no aparece nunca** para ese nombre. Cuando la aparición muere, el callback hace
   `if not IsValid(ghost) then return end` y **el timer sigue corriendo para siempre**. Acotado por
   reciclado de EntIndex, pero son decenas de timers a 33 Hz haciendo nada.
7. **`HuntPlayer` crea un `timer.Simple(10-15)` de borrado en cada llamada**, y la llama
   `CheckPlayerAggro` por cada fantasma × cada jugador. Se apilan docenas sobre la misma entidad.
8. **El debounce de puertas está muerto.** `GhostInteractWithDoor` comprueba
   `doorLastInteraction[door:EntIndex()]` **después** de haber disparado `door:Fire("Use")`. La regla
   de «no tocar la misma puerta dos veces en 60 s» no previene nada. (La función igual sirve: lo que
   nos interesa de ella es el `Fire("Use")` + el cierre diferido, no su contabilidad.)
9. **`CheckFlashlightEffects()` es una rama muerta entera [lectura]:** compara
   `ply:GetActiveWeapon():GetClass() == "weapon_flashlight"`, y **la linterna de GMod base no es un
   arma**. Toda la mecánica de «la luz baja el aggro» nunca se ejecuta.

**Lo que esto no cambia:** el veredicto de §11.1 sigue en pie — el mod es 1:1 con Phasmophobia como
*diseño*. **Lo que sí cambia:** cuáles son «las funciones sanas» de §11.3.

### 11.3 Qué tomamos, entonces

- **El catálogo de eventos y la forma de las convars** — como especificación, ya validada por alguien
  que hizo el mismo ejercicio. **La forma, no el código:** su escalera de `if` es acumulativa
  (defecto 4), así que se copia la *lista* de eventos y se escribe una tabla de pesos.
- **Los assets**: las partículas (`gmpa_ghost_orb_green`, `gmpa_shadow_lurker`,
  `gmpa_shadow_figure_clouds`), los 151 sonidos, `homm.mdl`, **y los cuatro decals de huella de
  mano** que el mod trae y nunca cablea — ver `EQUIPAMIENTO.md` §8.
- **Las funciones llamables**, con lo que ahora sabemos de cada una:

  | Función | Veredicto tras la 2.ª pasada |
  |---|---|
  | `GhostInteractWithDoor()` | **Sirve.** Su contabilidad de 60 s está muerta, pero el `Fire("Use")` + cierre diferido es lo que queremos |
  | `CreateShadowFigure(pos)` | **Sirve.** Es la que respeta el argumento |
  | `FlingNearbyPhysicsProps(self)` | ~~Se lee sana pero nunca corrió~~ **CORRE** — tiene **tres** call sites (`:612` muerto, `:1040` y `:1055` vivos vía `activeGhosts`). Ver la corrección de §11.2 |
  | `BreakNearbyProps(self)` | **No hace lo que el nombre dice.** Si querés romper `prop_physics`, hay que escribirlo |

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
| **Revisa escondites** (§18.2.3) | no | no | a veces | **sí** | **sí, y antes** |
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

---

## 15. El clima — la mecánica que faltaba **[verificado]**

El juego tiene **8 climas**, y no son decorado: cambian iluminación, visión, sonido ambiente y
**temperatura**. La temperatura importa porque *Freezing* es una evidencia.

| Clima | Iluminación | Visión | Sonido | Temp. | Efecto propio |
|---|---|---|---|---:|---|
| Clear | Dim | Alta | Bajo | 13 °C | — |
| Sunrise | **Brillante** | Alta | Bajo | 16 °C | Ilumina exteriores y cuartos con ventana |
| Light Rain | Modesta | Alta | Medio | 8 °C | Ruido constante, no tapa las interacciones |
| **Heavy Rain** | Dim | Modesta | **Alto** | 8 °C | **Tapa los pasos del fantasma.** Apaga fuego tier 1/2. Relámpagos que iluminan |
| Fog | Modesta | **Pobre** | Bajo | 13 °C | Sólo afecta exteriores — **y no afecta la visión del fantasma** |
| Snow | Modesta | Modesta | Bajo | **5 °C** | Se ve el aliento; **dificulta ver los Ghost Orbs** |
| Windy | Dim | Alta | Medio | 8 °C | Viento entre los árboles |
| **Blood Moon** | Modesta | Alta | Medio | 13 °C | **2 % de probabilidad.** Ver abajo |

**Blood Moon** es un modificador global, no un clima más:

- Fantasma **+15 % de velocidad durante los hunts**
- Drenaje pasivo de cordura **+100 %**
- Más eventos
- No se puede elegir ni pedir con la Monkey Paw

**Encaja con lo que ya tenemos.** El audio del clima **ya está mapeado y en disco**:

| Clima | Archivos ya organizados |
|---|---|
| Light / Heavy Rain | `ambience/rain.ogg`, `ambience/rain_window.ogg` |
| Heavy Rain (truenos) | `ambience/thunder_rumble_1-2.ogg`, `ambience/thunder_clap_a/c/d.ogg` |
| Windy | `ambience/forest_wind_loop.ogg` |
| Clear / noche | `ambience/night_neighborhood.ogg`, `ambience/room_tone.ogg` |

Y engancha con dos cosas ya diseñadas: la **temperatura** alimenta el rasgo `speed.perTemperature`
del Hantu (§5.1), y `ply:GetBmEnvIsInside()` de Better Movement (§1.1) permite aplicar el clima
**sólo afuera**, que es como funciona en el juego.

### 15.1 No lo escribimos: nos integramos **[decisión del autor, 2026-08-02]**

**Un sistema de clima es un addon entero.** Ya existen varios buenos en el Workshop y reimplementarlo
sería competir con ellos y perder. La misma regla que ya se aplicó con Better Movement (§1.1):
**detectar en runtime, usar lo que haya, y tener un camino propio si no hay nada.**

| Addon | ID | Publicado | Última actualización | Nota |
|---|---|---|---|---|
| **StormFox 2** | [2447774443](https://steamcommunity.com/sharedfiles/filedetails/?id=2447774443) | 2021 | **2026-05-01** | **El elegido.** El más completo, con API pública y mantenimiento activo |
| gWeather | [3322707383](https://steamcommunity.com/sharedfiles/filedetails/?id=3322707383) | 2025 | — | Sin investigar |
| Simple Weather | [531458635](https://steamcommunity.com/sharedfiles/filedetails/?id=531458635) | 2015 | 2025-09 | El más básico, pero **sigue mantenido**. Sin investigar |

*(Fechas aportadas por el autor. Steam devolvió HTTP 429 y no se pudieron verificar desde acá.)*

**StormFox 2 es el objetivo de integración** — decisión del autor, y los datos la respaldan: es el
único de los tres con API pública documentada en un repo, y se actualizó hace tres meses.

> **Cuidado con datar un addon por su ID.** El número del Workshop es secuencial por **publicación**,
> y no dice nada sobre el mantenimiento: Simple Weather es de 2015 **y se actualizó en septiembre de
> 2025**. Un ID viejo no es un addon abandonado. (Nota escrita porque en la primera pasada se dedujo
> lo contrario a partir del ID, y era falso.)

> El autor **no piensa usar ninguno personalmente**. Por eso la integración es *opcional de verdad*:
> el camino sin addon de clima tiene que ser jugable, no un modo degradado triste.

### 15.2 La API de StormFox 2 **[verificado contra el `.gma` instalado]**

Leída primero de [`Nak2/StormFox2`](https://github.com/Nak2/StormFox2), no de la descripción del
Workshop. **Re-verificada el 2026-08-02 contra el addon que realmente corre** — el `.gma` suscrito
(WSID `2447774443`, 307 archivos) desempacado a `dev/other/stormfox 2/`. **Las ocho funciones y los
dos hooks existen, y los números de línea de la tabla coinciden.** Es una afirmación más fuerte que
la anterior: un repo puede estar adelantado, atrasado o en otra rama respecto de lo publicado.

| Función | Archivo | Para qué nos sirve |
|---|---|---|
| `StormFox2.Temperature.Get( sType )` | `framework/sh_temperature.lua:91` | **La evidencia Freezing sale de acá** |
| `StormFox2.Temperature.Convert( from, to, n )` | `:140` | Pasar a °C sin hacer cuentas |
| `StormFox2.Weather.GetCurrent()` | `framework/sh_weather_handle.lua:124` | El clima actual |
| `StormFox2.Weather.IsRaining()` | `:380` | Lluvia |
| `StormFox2.Weather.IsSnowing()` | `:390` | Nieve → el clima frío de §15 |
| `StormFox2.Weather.GetRainAmount()` | `:399` | Distinguir lluvia leve de fuerte |
| **`StormFox2.DownFall.IsEntityHit( ent, bDont_cache )`** | `:420` | **Si a la vela le está cayendo agua** → se apaga. **El 2.º argumento no estaba en esta tabla:** saltea la caché (delega en `Wind.IsEntityInWind`) |
| **`StormFox2.DownFall.IsPointHit( pos )`** | `:429` | Si a un punto **le está llegando la precipitación**. **No es lo mismo que "está a la intemperie"** — ver abajo |

Y dos hooks para reaccionar a los cambios en vez de encuestar:

```lua
hook.Add( "StormFox2.weather.postchange", "phantasmagoria_weather", function( sName, nPercent, nDelta )
    PHANTASMAGORIA.OnWeatherChanged( sName, nPercent )
end )
-- el otro es prechange, y lleva DOS argumentos, no tres:
--   hook.Run( "StormFox2.weather.prechange",  sName, nPercentage )          -- :48
--   hook.Run( "StormFox2.weather.postchange", sName, nPercentage, nDelta )  -- :115
```

> **Trampa de mayúsculas al catalogar sus hooks.** El mod **mezcla los dos estilos**: los de clima van
> en minúscula (`StormFox2.weather.postchange`, `.prechange`, `.clear`, `.setlight`) y otros van
> capitalizados (`StormFox2.Weather.Think`, `.Stamp`, `.SendForcast`). Copiar el string tal cual
> aparece en el `hook.Run`; normalizarlo a un estilo da un hook que nunca dispara y **no da error**.

#### Lo que la tabla no decía, y sale de leer los cuerpos **[medido 2026-08-02]**

Cuatro cosas que cambian cómo se usa esta API, ninguna deducible de las firmas:

1. **`Weather.GetCurrent()` NO devuelve un string: devuelve la TABLA del clima.**
   `return CurrentWeather or StormFox2.Weather.Get("Clear")` — un objeto con `.Name` y `.Inherit`.
   `MapStormFoxWeather()` (§15.3) tiene que leer **esos campos**, no tratar el retorno como una clave.
2. **La nieve no es un clima aparte: es lluvia bajo −2 °C.** `IsSnowing()` es
   `wT.Name == "Rain" and Temperature.Get() <= -2`, y `IsRaining()` es el complemento
   (`> -2`) **más** todo lo que hereda de `Rain`. O sea: la temperatura **causa** la clasificación,
   no al revés — y con eso el termómetro y la nieve dejan de ser dos señales independientes.
   **Asimetría a tener presente:** un clima que *hereda* de `Rain` (una tormenta) da `IsRaining()`
   true a cualquier temperatura y `IsSnowing()` **siempre false**, porque su `.Name` no es `"Rain"`.
3. **`GetRainAmount()` devuelve 0 mientras nieva.** Su primera línea es
   `if not IsRaining() then return 0 end`. Sirve para graduar lluvia, **no** como "cantidad de
   precipitación": en una nevada lee 0 en silencio. La cantidad cruda es `Weather.GetPercent()`.
4. **`Temperature.Get(sType)` con un tipo inválido avisa y después CRASHEA.** Emite
   `StormFox2.Warning(...)` y acto seguido hace `convert_to[sType](n)` sobre un `nil`. Usar sólo
   `"celsius"` (el default), `"fahrenheit"` o `"kelvin"`. Su hermana `Convert` sí usa `error()` limpio.
   Nota aparte: la anotación LuaLS de `Get` declara `---@return Color` y **devuelve un número** — el
   comentario de un tercero miente igual que cualquier otro.

**Dos regalos que resuelven cosas que estaban abiertas:**

1. **`DownFall.IsEntityHit( ent )` implementa la mecánica de lluvia fuerte tal cual**: el juego apaga
   los fuegos tier 1 y 2 bajo la lluvia. Con esto, la vela y el incienso se apagan **sólo si
   efectivamente les está cayendo agua**, que es más fino que "está lloviendo".
2. ~~**`DownFall.IsPointHit( pos )` es un tercer detector de interior/exterior**, junto a
   `IsUnderSkyPos` de HIM y `GetBmEnvIsInside` de Better Movement (§14.1). Si StormFox está montado,
   es el más barato de los tres, porque ya lo calcula para su propio uso.~~

   > **REFUTADO leyendo el cuerpo (2026-08-02). No sirve como detector de interior/exterior.** Su
   > primera línea es `if not StormFox2.Weather.HasDownfall() then return false end` — y `HasDownfall`
   > es true **sólo si el clima es `Rain` o hereda de `Rain`**. Con cielo despejado, `IsPointHit`
   > devuelve **false en todo el mapa**, adentro y afuera. Usarlo para mapear cuartos daría «todos
   > están bajo techo» los días de sol, en silencio y sin error.
   >
   > Y aun lloviendo tampoco lo es: el trace no va hacia arriba, va **en la dirección del viento**
   > (`-StormFox2.Wind.GetNorm() * 262144`). Contesta *«¿a este punto le está llegando la
   > precipitación?»*, que es una pregunta con viento adentro. **Para la vela es exactamente lo que
   > queremos** — un alero a favor del viento no la apaga — y para los cuartos no sirve.
   >
   > **El detector de interior/exterior sigue siendo el de §14.1** (`IsUnderSkyPos` de HIM, y
   > `GetBmEnvIsInside` como alternativa). El regalo era uno solo, no dos: la mecánica de la vela.
   > **La lección:** una función cuyo nombre describe geometría puede estar cerrada por una condición
   > de estado que el nombre no menciona.

### 15.3 La forma concreta

Una sola función decide de dónde sale el clima, y **nadie más en el addon pregunta por StormFox**:

```lua
-- Devuelve { key = "heavy_rain", tempC = 8, illum = ..., vision = ..., sound = ... }
function PHANTASMAGORIA.GetWeather()
    -- 1. StormFox 2, si esta montado
    if StormFox2 and StormFox2.Weather and StormFox2.Weather.GetCurrent then
        return PHANTASMAGORIA.MapStormFoxWeather()
    end

    -- 2. …hueco para gWeather / Simple Weather, cuando se investiguen…

    -- 3. Propio: una convar y la tabla de 8 filas de arriba. Sin efectos
    --    visuales: solo los NUMEROS que el addon necesita (temperatura,
    --    visibilidad, ruido ambiente) mas los sonidos que ya estan en disco.
    return PHANTASMAGORIA.OwnWeather()
end
```

El camino propio **no dibuja lluvia ni niebla** — eso es lo caro y es justamente lo que hacen bien
los addons de clima. Sólo mantiene el estado y los números que las mecánicas consultan, más el audio
ambiente que ya está mapeado. Un jugador sin addon de clima igual tiene noches frías que ayudan al
termómetro y tormentas que tapan los pasos; lo que no tiene es el aguacero en pantalla.

Convar: `phantasmagoria_weather` — `-1` = auto (usa StormFox si está, si no sortea), `0..7` = fijar
uno de los 8.

---

## 16. Los equipos tienen **tres tiers** — y el K2 es el Tier 2 **[verificado]**

Cada equipo del juego existe en tres versiones. Para el EMF, la fuente las describe así:

| Tier | Cómo muestra el nivel |
|---|---|
| 1 | Una **aguja** que apunta al número |
| **2** | **5 LEDs de colores; la cantidad encendida es el nivel** |
| 3 | **Pantalla LCD** con nivel, dirección y distancia a la fuente |

**El `emf_reader_k2.mdl` que tenemos es literalmente el Tier 2**: 5 LEDs, y sus 6 skins acumulativos
encienden de a uno. No es "un EMF genérico" — es una pieza concreta de la progresión del juego.

Eso da una estructura gratis para el equipamiento:

- **Tier 1** = barato, información cruda (el `eqp_emf_reader` del otro pack puede cumplir acá)
- **Tier 2** = el K2, información legible de un vistazo
- **Tier 3** = sin modelo; requeriría una pantalla con dirección y distancia

Otros tiers que la fuente menciona de paso y que afectan mecánicas ya diseñadas:

- **Incienso Tier 1** hace que el fantasma **huya** en vez de quedarse cerca.
- **Fuego tier 1 y 2** (encendedor, velas) **se apaga bajo lluvia fuerte** — engancha con §15.
- La **cámara Tier 2 y 3** tiene pantalla para apuntar.

**Para la primera versión: un solo tier por equipo.** Los tiers son progresión económica, y sin
economía no significan nada. Pero conviene que la tabla de equipos tenga el campo `tier` desde el
principio, porque agregarlo después obliga a tocar todas las entidades.

---

## 17. Lo que hay en el juego y **no** vamos a hacer

Para que quede escrito por qué, y no se re-discuta:

| Contenido | Por qué no |
|---|---|
| **Ferryman of the Drowned**, **Ghost in the Machine** | Son **puzzles de mapas concretos** (Point Hope, Nell's Diner) con recompensa de ID Badge. Dependen de la geometría de esos mapas: no se portan a GMod |
| Desafíos semanales | Contenido rotativo atado a los mapas del juego |
| Apocalypse bronze / silver / gold | Logros de dificultad extrema; sin economía ni progresión no significan nada |
| Eventos estacionales (Winter's Jest, Cursed Hollow, Crimson Eye) | Contenido temporal del juego original |

### Nota sobre el rumbo del juego

El [roadmap 2026 de Kinetic Games](https://www.kineticgames.co.uk/news/phasmophobias-roadmap-for-2026)
retrasó la 1.0 a **2027** e incluye un **overhaul completo de los modelos de fantasma**: cada tipo
pasaría a tener apariencia, animaciones e historia propias. Hoy el modelo **no** indica el tipo
(salvo Banshee y Dayan, que son femeninos), y todo el diseño de §5 se apoya en eso.

**No cambia nada de lo nuestro** —somos un mod de GMod, no un port— pero si algún día se quiere
alinear, el motor de rasgos ya lo soporta: sería un campo `model` por tipo en la tabla, y nada más.

---

## 18. Zona segura, esconderse, y por qué el hunt heredado **no** alcanza **[2026-08-03]**

Tres huecos que el autor levantó y que §2 daba por cubiertos. **Dos de los tres son la misma
función de la base**, ya escrita, sólo que enchufada a la entrada equivocada.

Salvo donde se indique, todo lo de acá se leyó en
[`terminator nextbot/…/enemyoverrides.lua`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua)
y está marcado **[verificado]**. Las mecánicas del juego original vienen del autor —la wiki devuelve
402, §6— y van como **[dato del autor]**.

### 18.1 La zona segura es de *targeting*, no de pathing **[decisión del autor]**

**§2 estaba mal.** `ENT.hazardousAreas` no sirve para encerrar al fantasma:

- En la base significa otra cosa: *«areas we took damage in»*
  ([`shared.lua:2932`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/shared.lua#L2932)).
  Ya tiene dueño.
- Alimenta `AddAreasToAvoid( areas, mul )`
  ([`pathoverrides.lua:386`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/pathoverrides.lua#L386)),
  que **suma costo** a `pathAreasAdditionalCost`. Es un **peaje, no un muro**.

Y ahí muere la mecánica: si el único camino hacia el jugador cruza la zona segura, el fantasma
**paga el peaje y entra**. Un camión al que se puede entrar cuando sale más barato no es un camión
seguro.

**La zona segura del juego no es un lugar al que el fantasma no va: es un lugar donde no sos un
objetivo.** Esa pregunta la contesta un veto que la base expone en público:

```lua
if hook.Run( "terminator_blocktarget", self, ent ) == true then return false end
```
— [`enemyoverrides.lua:496`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L496), dentro de `ShouldBeEnemy`.

**El veto muerde de verdad [verificado].** `ShouldBeEnemy` es el filtro que decide si `FindEnemies`
llega a llamar `UpdateEnemyMemory`
([`:596-609`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L596)),
y `ForgetOldEnemies` limpia la memoria de quien deja de calificar
([`:676`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L676)).
Entrás al camión y el fantasma no sólo te suelta: **te olvida.**

Por qué el hook y no las dos alternativas obvias:

| Mecanismo | Veredicto |
|---|---|
| **`terminator_blocktarget`** | **El elegido.** Un solo lugar, sin estado que mantener, y es la API que la base ofrece para esto |
| `FL_NOTARGET` | Funciona —la base lo chequea en [`:434`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L434) y el alerter también— pero es una bandera **global**: te vuelve invisible para todos los NPC del servidor. Esto es un addon de sandbox |
| La relación de §3.1 | Es el switch fantasma/cazador, que cambia dos veces por hunt. La zona segura cambia veinte veces por partida |

**Sólo protege del targeting [decisión del autor].** Si un Poltergeist tira un prop y entra por la
puerta del camión, te pega. El camión es seguro *del fantasma*, no del mundo.

Tres cosas que el veto **no** resuelve y hay que escribir aparte:

1. **El fantasma tampoco debería caminar ahí.** Eso sí es pathing, y ahí el costo alto de
   `AddAreasToAvoid` está bien —como preferencia, no como promesa— sumado a que el selector de
   roaming nunca sortee esas áreas.
2. **El sonido no queda bloqueado.** El alerter es un sistema aparte: un jugador que hace ruido
   adentro del camión sigue mandando `SaveSoundHint`. Hay que filtrarlo en el mismo lugar, o el
   camión te delata desde adentro.
3. **De dónde sale la zona.** «Afuera de la casa» no existe en `gm_construct`. Con mapeo, sale de
   §14. Sin mapeo —el 99 % de los mapas, §14.5— la degradación honesta es **una entidad**: se
   spawnea el camión y su radio *es* la zona. Encima da el objeto físico que enseña la regla sin
   explicarla.

### 18.2 Esconderse: dos niveles, y la frontera son 100 unidades

**Dos correcciones del autor que definen esto [dato del autor]:**

- **El juego no te avisa que estás escondido.** Vas a un hiding spot; el lugar *es* el aviso.
  → **no lleva HUD.**
- **La oscuridad no oculta.** Lo que te delata es tener **un electrónico encendido en la mano** —
  por eso las sombras *parecen* ayudar. Detrás de cierto objeto sí ayuda.
  → **cae el nivel de luz**, que era el único input que pedía plumbing cliente→servidor. Todo el
  ocultamiento queda server-side y gratis.

> **La consecuencia de sacar el HUD no es sólo sacar el HUD.** El borrador previo puntuaba el
> escondite con `GetNookScore` —un valor **continuo** sobre navareas—. En Phasmophobia el escondite
> es legible porque está **autorado**: un placard es un placard. Un puntaje continuo no lo es: el
> jugador no tiene forma de saber que *ese* rincón cuenta, y sin HUD tampoco se lo dice nadie. El
> puntaje se va con el HUD. **Lo que reemplaza al cartel no es otro cartel: es que el escondite sea
> un lugar discreto y reconocible.**

Queda partido en dos niveles, y **la línea que los separa NO es la distancia** — ver §18.2.1, que
corrige un error de la primera redacción de esta sección:

| Nivel | Qué es | Qué cuesta | Dónde falla — **a propósito** |
|---|---|---|---|
| **Detrás de un objeto** | Línea de vista cortada. `CanSeePosition` es un trace ([`:563`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L563)) — **pero con el mask heredado los props NO cortan, medido en juego, §18.6** | **un campo**, `ENT.LineOfSightMask` | **El fantasma se mueve.** Un paso al costado y la caja deja de tapar |
| **Hiding spot** | Volumen **cerrado** y marcado: no se resuelve caminando alrededor | Mapeo — misma toolgun y mismo JSON de §14 | Hay que poder **abrirlo** — §18.2.3 |

Los dos son legibles sin cartel: la caja la ves entre vos y el fantasma, y el placard es un placard.
Y el modo de falla del primero es el correcto: **te obliga a seguir al fantasma con la vista en vez
de contar segundos.** El segundo existe justamente porque hay veces en que no podés seguirlo.

### 18.2.1 Cómo ve la base a un jugador — el mecanismo entero **[verificado]**

Escrito porque de esto depende si el nivel 1 existe, y porque la primera redacción de §18.2 lo dio
por sabido y se equivocó.

Para que el bot te registre tienen que pasar **dos** filtros, no uno
([`:596-609`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L596)):
`ShouldBeEnemy` (relación, FOV, niebla, y la tirada de §18.3) **y** `CanSeePosition`. La segunda es
todo el asunto:

```lua
local tr = util.TraceLine( {
    start  = myTbl.GetShootPos( self ),
    endpos = pos,                     -- pos = EntShootPos( check )
    mask   = self.LineOfSightMask,    -- MASK_BLOCKLOS ( shared.lua:239 )
    filter = self
} )
local seeBasic = not tr.Hit or ( isentity( check ) and tr.Entity == check )
```
— [`:563-580`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L563)

**Un solo rayo, a un solo punto.** No muestrea hitboxes: no existe «parcialmente visible». Si el
rayo pega en cualquier cosa que no seas vos, **no te ve**. La cobertura es binaria — que es una
propiedad buena para un mecanismo que el jugador tiene que aprender sin que nadie se lo explique.

**Y el punto cambia si estás agachado**, por una rama explícita en `EntShootPos`
([`:186-240`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L186)):

```lua
local isCrouchingPlayer = isPly and ent:Crouching()
if not isCrouchingPlayer then
    -- hitbox de la CABEZA primero, despues pecho, despues generico
end
-- agachado cae aca:
local pos = entMeta.WorldSpaceCenter( ent )
```

| | Punto que se traza | z sobre los pies |
|---|---|---|
| De pie | hitbox de la **cabeza** | ~64 **[estimado]** |
| **Agachado** | **`WorldSpaceCenter`** — centro de la caja de colisión | **18** |

Los ojos del fantasma salen de `GetShootPos`, que es `LocalToWorld( GetViewOffset() )`
([`base/shared.lua:137`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot_base/shared.lua#L137)),
y el offset de `round( maxs.z − (maxs.z/72)·8 )`
([`motionoverrides.lua:3883-3886`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/motionoverrides.lua#L3883)).

> ⚠ **ESTA SECCIÓN SE ESCRIBIÓ CON LOS OJOS EN 64 Y AHORA ESTÁN EN 40.** Los 64 salían de
> `maxs.z = 72`, que es el hull **clavado** de la base
> ([`terminator_nextbot_base/init.lua:39`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot_base/init.lua#L39)),
> el mismo para todos los modelos. Nuestro fantasma mide **44,94 u** de alto (medido en el `.vvd`,
> no en el hull de colisión) y desde el 2026-08-08 usa un hull proporcional a su cuerpo — `20×20×45`
> —, del que la base deriva sola `ViewOffset = 40`, crouch 27 y crouch view 20.
> Va por `phantasmagoria_ghost_hull` (default 1); en 0 vuelve al de la base y a los 64.
>
> **Es un cambio de balance y no un efecto secundario**: con los ojos en 64 el fantasma miraba desde
> 19 u *por encima de su propia cabeza*. Los números de abajo están reescritos con 40; los viejos
> quedan en la última columna porque describen lo que se jugó hasta esa fecha.

**La cuenta que contesta «¿me tapa esta caja?»:** el rayo va de los ojos (40) al punto trazado (18),
así que una caja de altura `H` a la fracción `t` del camino lo corta si **`H > 40 − 22·t`**.

| Dónde está la caja | Altura que necesita | *(antes, con ojos en 64)* |
|---|---|---|
| Pegada a vos (`t ≈ 1`) | **> 18** — cualquier caja | > 18 |
| A mitad de camino | **> 29** | > 41 |
| Pegada al fantasma (`t ≈ 0`) | **> 40** | > 64 |

**Todos los escondites se vuelven más fáciles**, y la razón es que el fantasma es más bajo: una
`wood_crate001a` (~45 u) ya no «todavía sirve» a mitad de camino, sino que sobra. Lo que **no**
cambia es el extremo `t ≈ 1`: pegado a vos, el que manda es el punto trazado (18) y no los ojos.

**De pie el rayo va casi horizontal a 40, así que esa misma caja no tapa nada.** O sea:
**agacharse ya es un mecanismo de esconderse, hoy, sin escribir una línea** — y la diferencia entre
agachado y de pie detrás del mismo objeto es enorme y se aprende en una partida. Eso sigue valiendo,
pero el margen es más chico que con 64: la ventaja de agacharse contra este fantasma es de 22 u de
caída del rayo, no de 46.

### 18.2.2 Corrección: «los 100 u» no son la frontera **[refutado]**

> La primera redacción de §18.2 decía que «detrás de un objeto» **falla a menos de 100 u**. Es falso
> por dos motivos independientes, y el error habría cambiado la implementación:
>
> 1. Esa regla vive **adentro** de `shouldNotSeeEnemy`
>    ([`:404`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L404)),
>    la función que muere en la línea 317 para jugadores opacos (§18.3). **Hoy no corre.**
> 2. Aun cuando corra, **no puentea el trace.** `shouldNotSeeEnemy` es un filtro *extra* encima de
>    `CanSeePosition`, y las dos tienen que pasar: sólo puede hacerte **más** difícil de ver, nunca
>    más fácil. **La línea de vista no la pisa la cercanía.**
>
> Si la caja corta el rayo, no te ve — a 1000 unidades o a 20. **El modo de falla real del nivel 1
> es que el fantasma se mueve**, y es mejor que el inventado: es legible, es justo, y re-justifica el
> hiding spot por lo que de verdad lo distingue —**estar cerrado**— y no por un umbral de distancia.

### 18.2.3 El escondite se puede revisar, y **cuánto depende de la dificultad** [decisión del autor]

Un escondite que nunca se revisa es una estrategia dominante; uno que siempre se revisa no es un
escondite. La perilla es la **dificultad** (§13), que es donde el juego original pone todo lo que no
cambia al fantasma sino cuánta ayuda te da:

| | Amateur | Intermediate | Professional | Nightmare | Insanity |
|---|---|---|---|---|---|
| **El fantasma revisa escondites** | no | no | a veces | sí | sí, y antes |

Encaja con la fila «se queda en su cuarto» que §13 ya tiene: en dificultad baja el fantasma es
predecible y perdonador, en alta no. Y no necesita mecánica nueva — revisar es **acercarse al
volumen y forzar un `CanSeePosition` desde adentro**, que es lo que hace abrir el placard.

### 18.2.4 El delator es la linterna default y lo nuestro; el resto es **capa de compatibilidad** [decisión del autor]

Lo que te delata (§18.2) son **`ply:FlashlightIsOn()`** y **nuestros ítems encendidos**. Punto. Un
SWEP cualquiera del sandbox **no** delata: si delatara, esconderse dejaría de existir en cualquier
servidor con addons, que es donde este mod va a correr.

El soporte para equipo de terceros va como **capa de compatibilidad separada**, con la forma que
Corpus ya usa —`corpus-cargo/lua/corpus_cargo/shared/corpus_cargo_movecompat.lua`—: **archivo
aparte, convar propia, leída contra el mod vivo y nunca supuesta, y degradación honesta en las dos
direcciones.** Si el mod no está o su toggle está en 0, la capa no hace nada y el camino base sigue
siendo toda la historia.

**El escondite se rompe si te vio entrar, y eso sale gratis.** `UpdateEnemyMemory` guarda dónde te
vio por última vez; si te vio meterte, va ahí. El escondite sirve **sólo si cortaste la línea de
vista antes de entrar** — que es la regla exacta del juego, sin escribir nada.

### 18.3 El hunt heredado es el de un cazador — y el arreglo ya está escrito

§2 decía «Hunt: **gratis**». Lo que es gratis es un cazador que te encuentra. **El fantasma de
Phasmophobia está diseñado para fallar la mayoría de las veces**, y eso no se hereda.

**Pero la base ya tiene el modelo, en `shouldNotSeeEnemy`**
([`:307-416`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L307)),
y lo que hay adentro son, literalmente, las reglas del juego **[verificado]**:

| En la base | Línea | La regla del juego |
|---|---|---|
| Linterna prendida → `+80` a la tirada | [`:346`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L346) | la luz te delata |
| Arma en mano con holdtype ≠ `normal` → `+80` | [`:340`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L340) | *casi* — ver abajo |
| Ruido reciente → bump escalado por el alcance | [`:369-379`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L369) | el ruido te delata |
| A menos de 100 u, **siempre** te ve | [`:404`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L404) | si lo tenés encima, te encontró |

Y el **hunt no determinista está en la misma función**
([`:387-401`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L387)):
cuando no te ve claro **no guarda tu posición real**, guarda
`enemy:GetPos() + randNoZ * investigateRadius` —un punto al azar a cientos de unidades— y sólo lo
acepta si es visible desde vos (`PosCanSee`). El fantasma va a *cerca de donde estabas*. Y
`investigateRadius = 500 - sndDist`: **cuanto más fuerte el ruido, más cerca cae la corazonada.**

**El problema es una línea.** Todo eso vive detrás de un portón en
[`:317`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L317):

```lua
if a >= maxSeen then cacheShouldNotSee( enemy, false ) return end -- dont waste any more performance
```

`a` es el **alfa del jugador** y `maxSeen` es 150: el modelo existe para jugadores *transparentes*
(cloak). Para un jugador opaco —o sea, todos— la función devuelve en la tercera línea y **nada de lo
de arriba corre nunca**.

> **Entonces el trabajo no es escribir un sistema de esconderse ni un hunt nuevo. Es cambiar qué
> alimenta `seen`**: de «transparencia del jugador» a un puntaje de ocultamiento. Es una refactor
> chica y hereda comportamiento ya tuneado. **§18.2 y §18.3 son la misma función.**

Las entradas del puntaje, después de las correcciones del autor:

| Entrada | De dónde sale |
|---|---|
| Línea de vista cortada | La base, gratis (§18.2) |
| Dentro de un hiding spot marcado | Nuestro, §14 |
| **Electrónico encendido en la mano** | **Nuestro** — ver abajo |
| Ruido reciente | La base, [`:369`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L369) |
| ~~Nivel de luz / oscuridad~~ | **DESCARTADO** — el autor: las sombras no ocultan |

**La señal no es «linterna»: es electrónico encendido.** `enemy:FlashlightIsOn()` está bien y ya
está —§11.2 defecto 9 ya había establecido que la linterna de GMod no es un arma—, pero el bump de
holdtype de [`:340`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L340)
dispara con **cualquier** arma empuñada, prendida o no. Para nuestro equipo el chequeo lo escribimos
nosotros y es exacto: un campo en el SWEP (`SWEP.PhantomIsElectronic`) más su estado de encendido.

Eso convierte al EMF y al spirit box en **decisiones durante el hunt** —apagarlos antes de
esconderse—, que es lo que hace que el equipamiento de [EQUIPAMIENTO.md](EQUIPAMIENTO.md) importe
mecánicamente y no sólo como props.

#### Dos defectos de la base que hay que arreglar **antes** de construir encima

1. **Vista infinita sobre jugadores — y NO es un bug: está etiquetado como feature [verificado].**

   La primera redacción culpaba al `if isPly then -- ignore maxSeeingDist for plys` de
   [`:508`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L508).
   **Eso es la consecuencia, no la causa.** El motor está en `DoDefaultTasks`
   ([`shared.lua:3185`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/shared.lua#L3185)),
   y el autor de la base lo nombra él mismo:

   ```lua
   elseif not fodder and not validPotentialNew and not myTbl.IgnoringPlayers( self ) then -- cheap infinite view distance
       -- only run this code if no enemies, go thru player table one-by-one and check los
       local allPlayers = player.GetAll()
   ```

   Recorre **`player.GetAll()` sin filtro de distancia**, un jugador por tick en round-robin, y sólo
   cuando el bot **no tiene enemigo**. El mapa real de alcances queda así:

   | Camino | Alcance |
   |---|---|
   | `FindEnemies` (barrido en cono) | **acotado a 3000** por `FindInSphere`/`FindInCone` |
   | El fallback «sin enemigos» (= la **ruta 3** de §18.7) | **ilimitado, a propósito** |

   En un mapa abierto, un fantasma cazando sin objetivo fijado **te engancha desde el otro extremo**
   si hay línea de vista. Correcto para un Terminator; lo contrario de un fantasma de Phasmophobia.
   **Tercera vez que «heredado» ≠ «correcto»: no hay que arreglarlo, hay que acotarlo.**

   **Y hay un punto único donde acotarlo:** esa rama llama `ShouldBeEnemy` **antes que nada**, así
   que **overridear `ShouldBeEnemy` con un corte por distancia para jugadores arregla todos los
   caminos de una** — el mismo punto que iba a hacer falta para NEAD antes de descartarlo (§19.5).

2. **La dispersión se invierte pasando los 500 u — y hoy está DORMIDO [verificado].**
   `investigateRadius = 500 - sndDist`, y `VectorRand()` **no está normalizado** (componentes en
   −1..1, magnitud hasta ~1,41×). El radio negativo sólo invierte la dirección: no achica nada.

   | Alcance del ruido | Radio | Dispersión real |
   |---:|---:|---|
   | 200 | 300 | ~424 u |
   | **500** | **0** | **te clava la posición exacta** |
   | 1000 | −500 | ~707 u — **igual que con radio +500** |

   La intención era *más ruido ⇒ mejor puntería*, y se cumple **sólo hasta 500**. Pasado ese punto,
   un ruido más fuerte **vuelve a empeorar** la corazonada.

   > **La diferencia con el defecto 1: éste no muerde hoy.** Vive dentro de `shouldNotSeeEnemy`, la
   > función que muere en la línea 317 para jugadores opacos. **Lo heredamos en el momento exacto en
   > que la des-gateemos** — o sea, al implementar §18.3. Por eso hay que arreglarlo **en esa misma
   > sesión** y no después: es una trampa esperando a que enciendan el mecanismo.

   *El engine también es un tercero* — la lección de §14 del roadmap #46, otra vez.

### 18.4 Lo que esto agrega a §5.2

Cae un rasgo nuevo que la tabla no tenía:

| Rasgo | Qué hace | Tipos |
|---|---|---|
| **`hunt.searchRadius`** | Cuánto dispersa la corazonada de dónde estás. **Es `investigateRadius`**, que ya es un número en la base | Deogen `0`, los tímidos alto |

Es la única perilla que hace que un fantasma se sienta astuto y otro ciego. Y con ella
**`hunt.hearsOnly` deja de ser un caso especial**: el Deogen —que te encuentra escondido— es
`searchRadius = 0`, no una rama en el cerebro. Que es exactamente lo que §5 exigía: *ningún tipo
necesita código propio*.

### 18.5 Lo que queda abierto

- ~~El «check» del hiding spot~~ **CERRADO** (2026-08-03) — se revisa, y **cuánto lo decide la
  dificultad**. §18.2.3.
- ~~Qué cuenta como «electrónico encendido» en el equipo de terceros~~ **CERRADO** (2026-08-03) —
  linterna default más lo nuestro; el resto, **capa de compatibilidad** con la forma de Corpus.
  §18.2.4.
- ~~¿`MASK_BLOCKLOS` choca con `prop_physics`?~~ **MEDIDO EN JUEGO Y REFUTADO** (2026-08-03) —
  **no choca.** Ver **§18.6**, que trae el arreglo.

  De la misma familia, todavía sin medir y más chicas: la **cabeza a ~64** es estimación (lo
  verificado es el *mecanismo*, hitbox de cabeza vs `WorldSpaceCenter`, no el número), y el hull
  agachado del jugador —maxs.z 36, centro 18— es el estándar del engine, tampoco medido acá.
- **¿El mundo sí corta `MASK_BLOCKLOS`? [SIN MEDIR]** — abierta *por* §18.6. Si los props no cortan,
  hay que confirmar que las paredes sí: si tampoco cortaran, `CanSeePosition` sería casi siempre
  true y la base entera sería omnisciente, lo que afectaría mucho más que a nuestro diseño. Es
  probable que corten (la base funciona y pierde jugadores), pero **«probable» es exactamente lo que
  §18.6 acaba de castigar.** Mismos dos comandos, apuntando a una pared.

### 18.6 Los props **NO** cortan `MASK_BLOCKLOS` — medido en juego **[2026-08-03]**

**La primera medición del proyecto, y refutó lo que este documento afirmaba dos secciones más
arriba.** El autor lo corrió con una caja delante, dos traces idénticos salvo el mask:

```
] lua_run ... util.TraceLine{start=e,endpos=e+p:GetAimVector()*300,filter=p} ...
true    Entity [59][prop_physics]                 <- control: la caja ESTA ahi

] lua_run ... util.TraceLine{... ,mask=MASK_BLOCKLOS, ...} ...
false   [NULL Entity]                             <- con el mask de la base: PASA DE LARGO
```

Mismo origen, mismo destino, mismo filtro; **la única variable es el mask.** El rayo con
`MASK_BLOCKLOS` no pega en la caja ni en nada: `Hit` es **false**. **El control es lo que lo vuelve
concluyente** — sin él, un `false` sería indistinguible de «no le estaba apuntando».

> **Yo había escrito que «debería» cortar**, razonando que el mask incluye `CONTENTS_SOLID` y que el
> `.phy` de un prop lo es. El razonamiento era plausible y la conclusión falsa. *El engine también es
> un tercero* — cuarta vez en este proyecto, y la primera en que la medición llega **antes** de
> escribir el código en vez de después.

**Y probablemente sea deliberado en la base.** Un cazador que pierde el rastro detrás de cada silla
se siente roto; para un Terminator, ver a través del desorden es una *feature*. Para un fantasma de
Phasmophobia es exactamente lo contrario. **«Heredado» no es «correcto»** — tercera vez en §18.

#### El arreglo es un campo, y el radio de explosión está acotado **[verificado]**

`LineOfSightMask` **es por entidad, con fallback al global**
([`shared.lua:2960`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/shared.lua#L2960)):

```lua
myTbl.LineOfSightMask = myTbl.LineOfSightMask or LineOfSightMask
```

Declarar `ENT.LineOfSightMask` en el phantom gana. Y los **tres** usos de `self.LineOfSightMask` son
la misma clase de pregunta —*¿puedo ver?*—, así que cambiarlo los mueve de forma coherente:

| Sitio | Qué pregunta |
|---|---|
| [`:574`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L574) | `CanSeePosition` — el trace del que depende todo §18.2 |
| [`:1108`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L1108) · [`:1137`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L1137) | «¿vería al enemigo de pie / agachado?» |

**Lo que NO cambia:** `terminator_Extras.PosCanSee` es **global**, no por entidad, y sigue usando
`MASK_BLOCKLOS` pase lo que pase. Ahí vive el filtro de la dispersión de §18.3
([`:395`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L395)),
que pregunta otra cosa —*¿este punto es visible desde el jugador?*— y puede quedarse como está.

#### El barrido de masks — **corrido, y contestó más de lo preguntado [medido]**

Cinco masks, el mismo trace, apuntando primero a la caja y después a una pared:

| Mask | Valor | **a la caja** | a la pared |
|---|---:|---|---|
| `MASK_SOLID` | 33570827 | **`[396][prop_physics]`** | `[0][worldspawn]` |
| `MASK_SHOT` | 1174421507 | **`[396][prop_physics]`** | `[0][worldspawn]` |
| `MASK_OPAQUE` | 16513 | `[0][worldspawn]` | `[0][worldspawn]` |
| `MASK_VISIBLE` | 24705 | `[0][worldspawn]` | `[0][worldspawn]` |
| `MASK_BLOCKLOS` | 16449 | `[0][worldspawn]` | `[0][worldspawn]` |

**Las paredes cortan las cinco.** La rama catastrófica de §18.5 está **muerta**: la base no es
omnisciente, pierde al jugador detrás de geometría del mundo. Eso era lo único que podía volver este
problema más grande que nuestro diseño.

**Y esta corrida mide mejor que la de arriba.** La primera dio `[NULL Entity]` porque no había nada
detrás de la caja; ésta da `worldspawn`, que **prueba que el rayo atravesó el prop** en vez de
simplemente no haberle pegado a nada.

##### Por qué, decodificando los valores **[lectura de los números]**

| Mask | Bits |
|---|---|
| `MASK_BLOCKLOS` 16449 | SOLID(1) + BLOCKLOS(64) + MOVEABLE(16384) |
| `MASK_OPAQUE` 16513 | SOLID + OPAQUE(128) + MOVEABLE |
| `MASK_VISIBLE` 24705 | ↑ + IGNORE_NODRAW_OPAQUE(8192) |
| `MASK_SOLID` 33570827 | SOLID + WINDOW(2) + GRATE(8) + MOVEABLE + **MONSTER(33554432)** |
| `MASK_SHOT` 1174421507 | SOLID + WINDOW + MOVEABLE + DEBRIS + **MONSTER** + HITBOX |

**Los tres que atraviesan la caja tienen `CONTENTS_SOLID` igual que los dos que la ven.** Lo único
que separa a los grupos es **`CONTENTS_MONSTER`**. Es decir: un `prop_physics` **no se presenta como
`CONTENTS_SOLID`** ante un trace de entidad — `CONTENTS_MONSTER` es en la práctica el bit de *«esto
es una entidad»*, y el nombre miente como tantos otros en este proyecto.

**La consecuencia es más grande que las cajas:** `MASK_BLOCKLOS` ≈ **sólo geometría del mundo**. El
bot heredado ve a través de *cualquier* entidad no-brush.

> **Corrección al margen:** §18.6 y §18.5 decían que `MASK_BLOCKLOS` incluye `CONTENTS_OPAQUE`.
> **Falso** — 16449 no tiene el bit 128. Lo afirmé dos veces razonando de memoria sobre la
> constante; el número medido lo desarma. Misma familia que todo el resto de esta sección.

##### El campo se respeta — **medido en juego** [2026-08-03]

`ENT.LineOfSightMask` no quedó como lectura de una línea: se ejerció contra un
`terminator_nextbot_loreaccurate` vivo, cambiando el mask y llamando `CanSeePosition` **en el mismo
instante** para las dos lecturas (así el bot puede caminar sin partir la comparación):

| Situación | `blos` | `solid` | Qué prueba |
|---|---|---|---|
| **De frente, nada en medio** (agachado) | true | **true** | **El control.** `MASK_SOLID` devuelve `true` cuando debe: **no rompe el trace, lo cambia** |
| De pie tras un container | true | **false** | El prop corta |
| Agachado tras unas compuertas | true | **false** | **Otro tipo de entidad**, mismo resultado |

> **El control salió de una lectura que yo no había pedido.** Mi diseño era «de pie tras una caja →
> `solid = true`», que dependía de una caja **baja**; un container tapa aun de pie. La lectura *de
> frente sin nada en medio* prueba el positivo directamente y es **mejor control**: si el mask
> rompiera el trace en lugar de cambiarlo, ahí habría dado `false`. *Un control vale por lo que
> descarta, no por la geometría que uno imaginó.*

**Dato extra que no se buscaba:** las **compuertas tampoco cortan `MASK_BLOCKLOS`**. Ya estaba medido
para props y NPCs; ahora también para entidades de puerta. Para un fantasma que abre y cruza puertas
(§2, `GhostInteractWithDoor`) eso no es menor.

**Lo que sigue SIN medir**, y es una afirmación distinta: que `ENT.LineOfSightMask` declarado en una
**subclase** sobreviva la línea de init (`myTbl.LineOfSightMask = myTbl.LineOfSightMask or
LineOfSightMask`, `shared.lua:2960`). Acá el campo se seteó **después** del spawn, salteando esa
línea. El idiom del `or` lo hace probable, pero probable no es medido.

##### La decisión: **`MASK_SOLID`** [2026-08-03]

```lua
ENT.LineOfSightMask = MASK_SOLID
```

De los dos que sirven, `MASK_SHOT` trae dos bits que no queremos para *ver*:

- **`CONTENTS_DEBRIS`** — escombros y gibs cortarían la línea de vista. Un pedazo de algo en el piso
  no debería esconderte.
- **`CONTENTS_HITBOX`** — precisión de bala. Es más caro, y este trace corre **por enemigo y por
  barrido**.

`MASK_SOLID` trae `CONTENTS_GRATE`, o sea que una reja o malla **sí** corta la vista. Discutible
—a través de una reja se ve— pero es el lado conservador, y si algún día molesta se saca un bit:
`bit.band( MASK_SOLID, bit.bnot( CONTENTS_GRATE ) )`.

**Efecto secundario, ahora MEDIDO y no inferido:** `MASK_SOLID` incluye `CONTENTS_MONSTER`, así que
**jugadores y NPCs pasan a ocluir**. Esconderse detrás de un compañero funciona; y en un sandbox
lleno de NPCs el fantasma puede quedar puntualmente ciego por gente en el medio. Se acepta a
propósito —es coherente con «la línea de vista es la línea de vista»— pero queda escrito para no
diagnosticarlo dos veces.

##### La generalización, confirmada sobre un NPC **[medido]**

La lectura de los bits decía que **nada que no sea mundo corta `MASK_BLOCKLOS`**. Se midió con el
mismo barrido apuntándole a un `npc_kleiner`, que es una entidad de clase completamente distinta a
un prop:

| Mask | a la caja | **al NPC** | a la pared |
|---|---|---|---|
| `MASK_SOLID` | `[396][prop_physics]` | **`NPC [386][npc_kleiner]`** | `[0][worldspawn]` |
| `MASK_SHOT` | `[396][prop_physics]` | **`NPC [386][npc_kleiner]`** | `[0][worldspawn]` |
| `MASK_OPAQUE` | `[0][worldspawn]` | `[0][worldspawn]` | `[0][worldspawn]` |
| `MASK_VISIBLE` | `[0][worldspawn]` | `[0][worldspawn]` | `[0][worldspawn]` |
| `MASK_BLOCKLOS` | `[0][worldspawn]` | `[0][worldspawn]` | `[0][worldspawn]` |

**Mismo patrón, misma frontera, dos tipos de entidad distintos.** La lectura pasó a medición:
`CONTENTS_MONSTER` es el bit de *«esto es una entidad»*, y **`MASK_BLOCKLOS` es geometría del mundo
y nada más**. El bot heredado ve a través de props, NPCs y jugadores por igual.

> **⚠ El mask NO alcanza. Leer §18.7 antes de implementar** — hay una segunda ruta de adquisición
> que no consulta `self.LineOfSightMask`, y el «arreglo es un campo» de esta sección es incompleto.

> **Un detalle que respalda el cambio.** `CanSeePosition` termina en
> `not tr.Hit or ( isentity( check ) and tr.Entity == check )`. Con `MASK_BLOCKLOS` la rama derecha
> **nunca** se cumple para un jugador o un NPC —el trace no los toca—, así que todo pasa por
> `not tr.Hit`. Con `MASK_SOLID` el rayo **sí** pega en el objetivo y la segunda rama se vuelve el
> camino normal. Esa rama ya estaba escrita: **el swap no es un parche contra el diseño de la
> función, es la mitad de la función que hoy no se usa.**

---

### 18.7 Las **seis** rutas de percepción — enumeración completa **[verificado]**

Escrita porque §18.6 dijo *«el arreglo es un campo»* leyendo **una** ruta, y hay seis. El error de
método está al final; primero la tabla, que es lo que se usa.

| # | Ruta | Chequeo | Mask | ¿La cubre `LineOfSightMask`? |
|---|---|---|---|---|
| 1 | `FindEnemies`, barrido en cono/esfera ([`:613`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L613)) | `ShouldBeEnemy` + `CanSeePosition` | `self.LineOfSightMask` | **sí** |
| 2 | Enemigo actual, cada tick ([`shared:3307`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/shared.lua#L3307)) | `CanSeePosition` | `self.LineOfSightMask` | **sí** |
| 3 | **Fallback «sin enemigos»** ([`shared:3203`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/shared.lua#L3203)) | `IsInMyFov` + `PosCanSee` + `ClearOrBreakable` | `MASK_BLOCKLOS` **global** + `MASK_SOLID` **hardcodeado** | **NO** |
| 4 | Daño recibido ([`damageandhealth:500`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/damageandhealth.lua#L500)) | **ninguno** si el atacante está a < `CloseEnemyDistance` | — | no aplica |
| 5 | Sonido → `movement_followsound` | `SaveSoundHint` / `validSoundHint` | — | no aplica |
| 6 | **Otro terminator te delata** ([`shared:4052`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/shared.lua#L4052)) | red entre bots, `MakeFeud` | — | no aplica |

**La 6 importa más de lo que parece:** un bot le pasa tu posición a otro. Relevante para **The
Twins** (§5.3, dos entidades) y para cualquier servidor con otros Terminators montados.

**La 4 es fuerte y hay que declararla:** pegarle al fantasma a menos de 175 u
(`ENT.CloseEnemyDistance`) actualiza su memoria **sin ningún chequeo de línea de vista**. Es
correcto —te sintió— y se queda, pero conviene saberlo antes de diagnosticar «me encontró y yo
estaba tapado».

#### La ruta 3, en detalle — y por qué se filtraba

```lua
local canSee = terminator_Extras.PosCanSee( myShoot, theirShoot )          -- MASK_BLOCKLOS, solo mundo
local clearOrBreakable = canSee and myTbl.ClearOrBreakable( self, myShoot, theirShoot )
if clearOrBreakable then                    -- perfect visibility
    myTbl.UpdateEnemyMemory( self, pickedPlayer, pickedPlayer:GetPos() )   -- tu posicion REAL
elseif canSee then                          -- they are obscured by a prop
    myTbl.RegisterForcedEnemyCheckPos( self, pickedPlayer )                -- "andá a fijarte ahí"
```

Corre **sólo cuando el bot no tiene enemigo**, un jugador por tick. El comentario `-- they are
obscured by a prop` es del autor de la base: **ya contempló el caso, y su respuesta no es "no te
veo" sino "voy a chequear"** — lo correcto para un cazador, lo contrario de lo que pide un fantasma.

`ClearOrBreakable` ([`motionoverrides:76`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/motionoverrides.lua#L76))
es un **`TraceHull`** con `mask = MASK_SOLID` **hardcodeado** y las bounds del bot × 0.5 — o sea que
la base **ya tenía** un camino que ve props; sólo que lo usa para *«¿está despejado?»* y no para
*«¿lo percibo?»*. Dos masks para dos preguntas, a propósito.

> **Consecuencia para §18.2 que cambia el diseño de niveles:** `ClearOrBreakable` cuenta un prop
> **rompible** como despejado. **Esconderse detrás de algo que se rompe no te esconde.**

#### El arreglo completo: **dos campos y un override**

> **Corrección (2026-08-03): eran dos campos y quedaron cortos.** Los dos campos tapan la fuga del
> *«andá a fijarte ahí»*, pero **la ruta 3 sigue adquiriéndote a distancia infinita** cuando el
> camino está despejado — es la *«cheap infinite view distance»* del defecto 1 de §18.3. Sin el
> override, un fantasma sin objetivo te engancha desde el otro extremo del mapa.

```lua
ENT.LineOfSightMask = MASK_SOLID     -- rutas 1 y 2  (§18.6, MEDIDO)
-- y al spawnear:
myTbl.forcedCheckPositions = false   -- la fuga de la ruta 3
-- y ademas:
function ENT:ShouldBeEnemy( ent, fov, myTbl, entsTbl )  -- corte por distancia en jugadores
```

**El override es el punto único**: las tres rutas que adquieren pasan por `ShouldBeEnemy` antes que
nada, así que un corte por distancia ahí las acota a las tres de una sola vez.

El segundo usa **la salida temprana que la propia base escribió**
([`:1494`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L1494)):
`if checkPositions == false then return end`. Las tres llamadas quedan no-op para siempre, sin tocar
la lista de tareas, y `movement_handler` tampoco arranca el barrido porque exige que la tabla tenga
entradas ([`:4146`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/shared.lua#L4146)).

**Y NO se lleva puesta la investigación por sonido** —que era el riesgo—: eso es la tarea
`movement_followsound`, alimentada por `lastHeardSoundHint`, un subsistema completamente aparte
([`shared:5107`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/shared.lua#L5107)).
El fantasma sigue viniendo cuando hacés ruido, que es exactamente la mecánica que queremos.

Con los dos campos la ruta 3 queda cerrada del todo: `ClearOrBreakable` **ya** detecta el prop, así
que nunca te metía en memoria; lo único que se filtraba era el punto a revisar.

#### El error de método, que ya no es mala suerte **[cuarta vez en la sesión]**

El primer grep de la sesión listó **cinco** call sites de `UpdateEnemyMemory`. **Leí tres.** Después
escribí conclusiones sobre «el mecanismo de visión» como si los hubiera leído todos — y los dos que
salté (`shared.lua:3209` y `:3376`) son justamente los que rompían la historia.

No fue que no encontré las rutas: **las encontré, las tuve impresas en pantalla, y no las abrí.**
Junto con las otras tres de §18 —la regla de los 100 u citada desde una función que yo mismo había
declarado muerta, `CONTENTS_OPAQUE` afirmado dos veces sin mirar el número, y «los props deberían
cortar»— **el patrón es siempre el mismo: leer un sitio y generalizar al mecanismo.**

**La regla que queda:** cuando un grep devuelve N call sites de algo que se va a describir como *el*
mecanismo, **se leen los N o se declara cuáles no** — un inventario a medias escrito como completo
es indistinguible de uno completo hasta que rompe.

---

## 19. La cordura — el gatillo de todo **[2026-08-03]**

§18 diseñó **cómo** caza el fantasma. La cordura decide **cuándo**: sin ella, §18 es un motor sin
llave. Por eso no es una feature al costado.

> **Lo que este documento tenía mal:** §4 son diez líneas y las leí como «el diseño de cordura».
> **La mitad ya estaba escrita en [EQUIPAMIENTO.md](EQUIPAMIENTO.md) §3.5** —la barra de Cargo, la
> vela que frena el drenaje, `eqp_sanity_pills` con masa y descripción, y los costos de cordura de
> las 7 posesiones malditas— y **los datos por tipo estaban en `ghost_types.lua`**. Buscar en un solo
> archivo y concluir sobre el proyecto es la falla de §18.7 otra vez, en otro eje.

### 19.1 Los datos ya están, generados del juego **[verificado]**

`lua/phantasmagoria/ghost_types.lua` trae **`hunt.threshold` en los 30 tipos** y
`thresholdLow`/`thresholdHigh` en **12**. No hay que inventar números.

Y los comentarios por tipo —de la misma fuente— ya especifican mecánicas de cordura que §4 no
menciona:

```lua
-- Banshee:
--   Hunts based on target's sanity instead of average sanity
--   Target loses 15% sanity if they touch the ghost during a singing ghost event
-- Aswang:
--   Will immediately end a hunt if the ghost enters an official hiding spot that a
--     detected player is currently in
```

> **El Aswang confirma §18.2 desde afuera.** Los datos del juego dicen **«official hiding spot»**: el
> escondite es un lugar **discreto y nombrado**, no un puntaje continuo. §18.2 llegó ahí discutiendo
> contra mi propio borrador; acá lo dice la fuente sola.

### 19.2 Las tres decisiones **[decisión del autor]**

| Pregunta | Respuesta |
|---|---|
| **Tasa de drenaje** | **10-20 min de 100 a 0**, como el juego — **condicionado** a que haya eventos paranormales que sostengan la tensión |
| **Ámbito** | **Por jugador.** El promedio existe como **lectura**, no como la variable |
| **Pastillas** | **Existen y tienen 3 tiers** — `models/phas/eqp_sanity_pills.mdl` ya está en el árbol |

**La primera es una condición, no un número.** Una barra que baja quince minutos sin que pase nada no
es tensión: es una barra. En palabras del autor, *«mientras existan eventos paranormales que asusten
y entretengan al jugador todo bien; lo atmosférico también es el punto que lo mantiene
entretenido»*. **El drenaje sólo funciona si los eventos (§7.5, §11.1) están escritos** — si no, hay
que acortarlo. Queda como dependencia declarada entre dos sistemas que parecían independientes.

### 19.3 El camión: dos pantallas, y una es una mecánica que no teníamos

De las capturas del juego que pasó el autor:

| Pantalla | Qué muestra |
|---|---|
| **TEAM SANITY** | El **promedio** arriba, y **una barra por jugador** con nombre y % |
| **TOTAL ACTIVITY** | Un gráfico **0-10** contra el tiempo. **10 = hunt sostenido** |

**El medidor de actividad no estaba en ningún documento.** Es una segunda variable global —cuánto
está pasando— dibujada como **historia** y no como instante, y es lo que convierte «no pasó nada en
cinco minutos» en información en vez de aburrimiento. Entra como diseño nuevo, y engancha con la
condición de §19.2.

**Cargo ya tiene la puerta:** `StatusPanel.RegisterBar` (EQUIPAMIENTO.md §3.5). La barra por jugador
es literalmente eso.

#### Cómo se dibujan: **HTML sobre RT**, y el modelo ya está extraído

El reparto se justifica solo, y no es la misma técnica para las dos cosas:

| | Equipo en mano | Pantallas del camión |
|---|---|---|
| Técnica | **2D**, como `phantasmagoria_paramic_screen.lua` | **HTML → RT** |
| Por qué | barato, y está siempre a la vista | pesado, pero **sólo se ve dentro del camión** y son pocas |
| Lo que gana | — | el gráfico de actividad y las barras salen gratis en CSS/SVG; a mano son `DrawLine` |

> **`DHTML:GetHTMLMaterial()` existe, pero NO se asume que sirva en `SetSubMaterial` sobre un
> modelo** — es exactamente el fallo silencioso que el archivo del paramic documenta (material sin
> `$model 1` ⇒ la submalla no se dibuja, sin error y sin textura rosa). **El camino seguro es
> HTML → nuestro RT → submaterial**: se dibuja el material del DHTML dentro del RT que ya tiene
> `$model 1` y se reusa toda la plomería existente. Un blit de más y cero riesgo. Cuál de los dos
> anda es **una medición, no una decisión**.

**El modelo: `tv_plasma` de CS:Source, ya extraído** a
[`dev/other/cs_office_tv/`](../../dev/other/cs_office_tv/) (2026-08-03) — **CS:S no viene montado por
defecto en GMod**, es tan común que lo parece pero es contenido de Valve que hay que tener.

⚠ **Y el patrón del paramic NO se aplica tal cual.** Medido con `dev/mdlinfo.py`: `tv_plasma.mdl`
tiene **una sola textura** (`TV_plasma`), igual que `tv_plasma_p1..p4` (`TV_plasma_p`). Los paramic
funcionan porque **fueron cortados en Blender** (`bl_merge.py --screen-fit`) y su pantalla es una
submalla propia terminada en `_screen`. En un `tv_plasma` sin cortar, `SetSubMaterial(0, …)`
reemplaza **el televisor entero, marco incluido**.

Falta entonces: cortar la pantalla con las herramientas que ya existen en `dev/phastools/`
(`bl_merge.py`, `bl_screen_orient.py` para la relación de aspecto) **y renombrar a namespace propio
en la misma pasada**, porque dejarlo en `models/props/cs_office/` colisiona con el CS:S de quien lo
tenga montado. El detalle y la receta de extracción están en el `LEEME.md` de esa carpeta.

> **Va detrás de un convar, por decisión del autor:** *«es medio tramposo»*. Ver tu cordura te dice
> cuándo empieza el hunt, que es justo lo que el juego te hace **estimar**. Lo fiel es tenerlo **en
> el camión** y no en el HUD — y con la zona segura de §18.1 ya definida, «en el camión» es una
> condición que sabemos evaluar.

### 19.4 La oscuridad: NEAD tiene el algoritmo **[verificado contra el mod montado]**

`render.GetLightColor` y `render.ComputeDynamicLighting` **son CLIENT** — el servidor de GMod no
puede saber cuánta luz recibe un punto. NEAD lo resuelve en 20 líneas
(`nead_clientscript.lua:44-70`; referencia propia en
[`dev/Cortex_NEAD_Referencia.md`](../../dev/Cortex_NEAD_Referencia.md)):

- `render.GetLightColor` en **pies+10** y en **los ojos** (lightmap horneado)
- `render.ComputeDynamicLighting` en las dos alturas y en **ambos sentidos** del vector (luz dinámica)
- Suma RGB de las seis muestras, cada una contra `NEAD_light_sen` (default **0.001**)
- Su condición de esconderse ya excluye `ply:FlashlightIsOn()` — **el mismo delator de §18.2.4**

**Pero `NEAD_indark` nunca se networkea:** es client-side; lo único que viaja al server es `hidden`.
La forma, igual que `GetWeather()` con StormFox (§15.3):

```lua
-- CLIENT, en el tick de cordura
local function InDarkness( ply )
    if ply.NEAD_indark ~= nil then return ply.NEAD_indark end  -- NEAD montado: costo cero,
                                                               -- y respeta SU calibracion
    return PHANTASMAGORIA.SampleDarkness( ply )                -- propio: las mismas 6 muestras
end
```

Preferir el valor de NEAD no es sólo ahorro: **es respetar la sensibilidad que el usuario ya
ajustó**. El autor confirma que en la práctica anda —*«hay varios mapas medio oscuros donde me he
ocultado usando ese mod»*— y el propio mod avisa que no es perfecto.

### 19.5 ⚠ La trampa de NEAD: te vuelve **intargeteable**

```lua
ply:SetNoTarget( bool )   -- nead_serverscript.lua:180
```

`SetNoTarget` prende **`FL_NOTARGET`**, y la base Terminator lo respeta **en dos lugares**:

| Dónde | Efecto |
|---|---|
| `ShouldBeEnemy` ([`:434`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L434)) | Sale antes de todo: **no sos enemigo** |
| El alerter | **Descarta tus sonidos** — *«dont alert for stuff that doesnt want to be targeted»* |

**Con NEAD montado, un segundo a oscuras sin linterna te vuelve invisible E inaudible para nuestro
fantasma.** Silencioso, sin error, y es exactamente la mecánica que §18.2 descartó.

**No es un bug de nadie: es un choque de premisas.** NEAD existe para que la oscuridad te esconda;
Phasmophobia existe para que no.

Y ojo: **no alcanza con que nuestro fantasma no sea DrGBase.** NEAD sólo cachea NPCs y nextbots con
`Base == "drgbase_nextbot"`, así que su lógica *directa* ignora a un Terminator — pero `FL_NOTARGET`
es una **bandera global del engine** y por ahí nos alcanza igual. *Una integración puede llegarte por
un camino que su propia lista de entidades no contempla.*

#### La decisión: **no se integra NEAD** [decisión del autor, 2026-08-03]

**El override era posible** —overridear `ShouldBeEnemy` en el phantom; desde `terminator_blocktarget`
no, porque la bandera devuelve en la línea 434 y el hook está en la 496— **pero no vale la pena, y la
razón es mejor que la imposibilidad:**

**No necesitamos NEAD para nada.** Las seis muestras de §19.4 son `render.GetLightColor` y
`render.ComputeDynamicLighting`: **API estándar del engine, no propiedad de NEAD**. Reimplementarlas
no es copiar, es usar las dos funciones que cualquiera usaría. Son 20 líneas. Depender de un addon
entero por 20 líneas **y encima heredarle un conflicto de diseño** es un mal negocio.

Lo que sí se recicla de NEAD es **lo que ya está medido**: que hay que muestrear en **dos alturas** y
en **ambos sentidos** del vector (si no, la luz dinámica que te da de espaldas no cuenta), y que
`0.001` es un umbral que el autor ya probó en juego.

> **«No compatible» significa avisar, no bloquear** — precedente del propio autor:
> `phantasmagoria_assetcheck.lua` detecta addons duplicados y **avisa sin bloquear**, porque
> *«bloquear un mod por despecho, como la controversia de TFA VOX, está mal»*. Si NEAD está montado,
> el detector lo dice y explica el efecto: **con NEAD, la oscuridad te esconde del fantasma**. El
> jugador decide si lo quiere.

**Y el sampler se escribe chico y autocontenido**, sin acoplarlo a la cordura: **Cortex va a
necesitar lo mismo** más adelante y tiene que poder levantarlo tal cual.

### 19.6 Las tres tajadas, y en qué va cada una **[2026-08-08]**

> ⚠ **Este bloque decía «falta la decisión de §19.5 — cuál de las tres formas», y §19.5 ya había
> decidido**: NEAD **no** se integra, y el motivo está escrito ahí mismo (las seis muestras son API
> del engine, no propiedad de NEAD). El bullet quedó vivo tres versiones. *Una lista de pendientes
> que no se tacha cuando la sección de arriba decide manda a re-discutir lo cerrado — y como se lee
> antes que el cuerpo, gana ella.*

**El drenaje es por CAUSAS, sin reloj de fondo** [decisión del autor, 2026-08-08]. No hay goteo
constante: la cordura baja por la oscuridad (§19.4), por la cercanía del fantasma y por las cacerías.
*Si no pasa nada, no baja nada* — que es la primera de §19.2 llevada al mecanismo en vez de al número.

El trabajo va en **tres tajadas, en este orden**, y el orden no es de gusto: cada una es la
precondición de la siguiente.

| | Qué es | Estado |
|---|---|---|
| **A · el tipo** | Asignarlo al spawnear desde `PHANTASMAGORIA.Types`, networkearlo, poder forzarlo | **ESCRITA, sin pasada en juego** (`server_type.lua`, planilla `phantasmagoria-tipo-r15`) |
| **B · la cordura** | Por jugador, servidor, networkeada, con sus causas e instrumentos | sin empezar |
| **C · el gatillo** | Cordura bajo el `hunt.threshold` **del tipo** → `phantom_SetHunting( true )` | sin empezar |

**Por qué A va primero:** C no compara la cordura contra un número fijo, la compara contra
`hunt.threshold`, que es un dato **del tipo** (Demon 70, Shade 35, Deogen 40). Sin tipo asignado, C no
tiene contra qué comparar y B mediría una barra que no dispara nada. Y de paso desbloquea §5 entero:
`speed.base` está en los 30 y `server_speed.lua` ya sabe leer un campo que gana sobre su convar
andamio.

**Sólo `hunt.threshold` en la tajada A.** `thresholdLow`/`thresholdHigh` (12 de los 30 tipos) es el
rango condicional de §5.2 —el Mare según la luz, el Yokai si hablás, el Obambo según su ciclo— y es
de después. El comando los imprime igual, marcados como no usados, para que estén a la vista sin
parecer implementados.

⚠ **Y la tajada A no engancha `speed.base` a propósito**, aunque el campo esté y el consumidor
también. Escribirlo cambiaría la velocidad de todos los fantasmas de golpe, sin A/B, en la misma
ronda que estrena el mecanismo que la decide: *un rojo de velocidad ahí sería imposible de atribuir.*

### 19.7 Lo que falta

- **Los 3 tiers de las pastillas** (§16): el modelo es uno; los tiers son cuánto restauran. El autor
  quiere **ripear el resto de los ítems**, así que la tabla lleva `tier` desde el principio.
- **Qué drena y cuánto** (tajada B): oscuridad (§19.4), ver manifestaciones, cercanía del fantasma
  —el banco `ghost/scare_light` del catálogo **ya es ese evento**, §7.2— y los hunts. ⚠ Los 10-20 min
  de §19.2 dejan de ser un **reloj** y pasan a ser la **escala**: son cuánto tiene que tardar una
  partida con actividad normal, no una tasa que corra sola. Con las causas apagadas la barra no se
  mueve, y eso es el diseño y no un bug.
- **El medidor de actividad** (§19.3): qué suma actividad y con qué peso.

---

## 20. La invisibilidad — **son DOS mecánicas y una tercera que no hay que pisar** [2026-08-08]

> **Esta sección DECIDE.** Las decisiones salen de leer `wraithcloaking.lua` línea por línea contra
> nuestros propios archivos, y cada una lleva la medición al lado. Lo que sigue sin medir está
> marcado como tal.

La palabra «invisibilidad» junta tres cosas con requisitos **opuestos**, y separarlas es el trabajo:

| | Qué es | Cuánto dura | ¿Sólido? | Estado |
|---|---|---|---|---|
| **①  LA AUSENCIA** | fuera del hunt el fantasma no se ve; se mueve, interactúa y hace ruido paranormal | minutos | **sí** (ver §20.2) | **escrita**, `server_cloak.lua` |
| **②  EL PARPADEO** | durante el hunt alterna visible/invisible para desorientar | **décimas** | **sí, siempre** | diseñada acá, **sin escribir** |
| **③  LOS EVENTOS** | se manifiesta unos segundos: modelo completo · sombra opaca · silueta translúcida | segundos | indistinto | §7, otro bloque |

**② no es cloak: es sólo render.** En hunt el fantasma te alcanza y te mata; uno que se vuelve
intangible cada 0,2 s no puede cazar. Y **③ necesita `SetMaterial`**, no `SetNoDraw`, porque una
sombra opaca y una silueta translúcida son *materiales* y no ausencias.

### 20.1 ⚠ El cloak de la base **acopla la invisibilidad a la NO-SOLIDEZ, en dos lugares distintos**

`PHANTOM_Referencia.md` §11 recomendaba `ENT.IsWraith = true` y decía que el costo eran «los
cooldowns asimétricos, que hay que tener en cuenta al elegir los tiempos». **El costo es otro y es
mayor.** Censado sobre las 202 líneas del módulo:

**(a) El reloj tiene UN solo lector, y esa mitad de la preocupación queda refutada.**
`wraithTerm_NextHidingSwap` se escribe en tres lugares y se lee en **uno** (`:128`), dentro de la
misma función que lo escribe. Grep sobre los 71 archivos de la base + HIM: ningún otro consumidor.
O sea que *pisarlo* (`self.wraithTerm_NextHidingSwap = 0`) sería técnicamente seguro. **No es el
bloqueante**, y la duda que el plan del bloque dejaba abierta —«hay que leer si algo más lo consulta
antes de romperlo»— queda cerrada por medición.

**(b) El material de invisibilidad NUNCA se aplica si el bot es sólido.** `CloakedMatFlicker`
(`:83-114`) pone `FlickerBarelyVisibleMat` en el acto y difiere el material *de verdad* a un
`timer.Simple( 0.65-0.75 )` que arranca con:

```lua
if self:IsSolid() then return end          -- :99
```

⚠ **Esto solo ya decide ②.** El parpadeo del hunt exige sólido; con el bot sólido el segundo paso
se sale siempre y el fantasma queda **permanentemente a medio ver**, sin error y sin log. Y decide
también contra `NotSolidWhenCloaked = false` como atajo: apagar la no-solidez apaga la
invisibilidad.

**(c) El `unhide` escribe la solidez SIN preguntar por la bandera, y el `hide` sí pregunta.** La
asimetría es del tercero:

```lua
if hide then
    if self.NotSolidWhenCloaked then          -- :131  GUARDADO
        self:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
        self:SetSolidMask( MASK_NPCSOLID_BRUSHONLY )
    end
    ...
else
    timer.Simple( 0.25, function()
        self:SetCollisionGroup( COLLISION_GROUP_NPC )   -- :172  SIN GUARDAR
        self:SetSolidMask( MASK_NPCSOLID )              -- :173  SIN GUARDAR
```

⚠ **Y eso choca contra un mecanismo nuestro que ya está cerrado en juego.**
`server_doors.lua` es el dueño de la solidez del fantasma: `phantom_SetPhasing` escribe
`SetSolidMask` para atravesar la hoja, tiene un techo duro de 5 s y un vigilante que grita
*«atravesó más de 5 s seguidos y se lo forzó a sólido. Eso no debería pasar»*. Con el cloak
encendido habría **dos escritores independientes de la misma máscara, sin árbitro**: el último que
corre gana, en silencio. Los dos síntomas concretos son un fantasma invisible que de golpe te
bloquea el paso, y un fantasma que se vuelve sólido **adentro de una hoja de puerta** porque el
`timer.Simple( 0.25 )` del unhide venció ahí.

**(d) Cada `DoHiding` cuesta un `EmitSound`, un `RemoveAllDecals`, un add/remove de `FL_NOTARGET`,
un `timer.Simple( 0.65-0.75 )` y —al aparecer— otro `timer.Simple( 0.25 )` con un segundo
`EmitSound` y un `OnStuck()`.** A la cadencia de ② (3-5 conmutaciones por segundo) eso es una
tormenta de timers superpuestos y un sonido cada 0,2 s.

> **Y lo que el módulo NO hace, contra lo que la Referencia sugería:** `wraithcloaking.lua` **no
> define `IsSilentStepping`**. El único `ENT:IsSilentStepping` de la base es `sharedextras.lua:7`,
> que devuelve `false` pelado — y nosotros ya lo pisamos en `server_steps.lua`. **Un fantasma
> cloakeado sigue sonando al caminar**, y el silencio de verdad ya está resuelto y cerrado en juego.
> **No se duplica.**

### 20.2 **DECISIÓN: la invisibilidad no toca la solidez, y `IsWraith` queda APAGADO**

Las tres salidas que había sobre la mesa eran: (a) pisar el reloj, (b) no usar `DoHiding` para ② y
sí para ①, (c) reimplementar el módulo. **Gana una cuarta, que apareció al medir (b):**

> **Una sola primitiva propia — `ENT:phantom_SetVisible( visible, motivo )` — para ① y para ②, que
> cambia SÓLO cómo se dibuja y no toca la solidez nunca.**

Y no es «reimplementar 202 líneas». De esas 202, el bucle sobre `GetChildren()` no nos aplica (ver
abajo), la danza de solidez la queremos fuera, el `CloakedMatFlicker` diferido está roto para
nuestro caso, y la `SpecialAction` es para el jugador-piloto. **Lo que queríamos del módulo son
cinco cosas** —`DrawShadow`, `FL_NOTARGET`, `RemoveAllDecals`, el material y los FX— y las cinco son
una línea cada una.

**Por qué (b) —«la base tal cual para la ausencia»— no alcanza, aunque para ① los tiempos del cloak
sí sirvan:** el conflicto de solidez de §20.1(c) es de **①**, no de ②. Un fantasma ausente que
atraviesa puertas es exactamente el caso donde los dos escritores se pisan. *La hipótesis del plan
era razonable y la medición la corrige por el lado que no se estaba mirando.*

**Lo que esto gana, y es el criterio de diseño y no una comodidad:** *la solidez del fantasma
conserva un dueño único*. Hoy es `server_doors.lua`, y su vigilante puede seguir afirmando que un
no-sólido de más de 5 s es imposible. Con el cloak encendido, esa afirmación dejaría de ser cierta y
**el vigilante no lo sabría**.

⚠ **Lo que esto CUESTA, escrito para que no aparezca después como sorpresa:** el fantasma ausente
**sigue siendo sólido**, o sea que se lo puede chocar, empujar con el physgun y tapar con un prop
sin verlo. En Phasmophobia el fantasma en fase de deambuleo *no* tiene cuerpo. Es una diferencia
real con el juego y se acepta a cambio del dueño único; si algún día molesta, la no-solidez fuera
del hunt se agrega **en `server_doors.lua`**, que es el que ya sabe manejarla, y no en el cloak.

> **La medición que falta y que la planilla de ① tiene que traer:** `#self:GetChildren()`. El bucle
> del wraith existe porque el bot lleva un arma parenteada (`weapons.lua:321`), y el nuestro no
> lleva ninguna (`DefaultWeapon = false` + `CanPickupWeapon` en false desde la r17). **Si el conteo
> da 0, `SetNoDraw` solo alcanza; si da distinto de 0, hay que recorrerlos** — y por eso el
> instrumento lo imprime en vez de que este documento lo dé por sentado.
>
> ⚠⚠ **MEDIDO, Y DIO LAS DOS COSAS. La r20 dio `hijos máximo visto 0` en toda su corrida; la r22
> imprimió `!! HIJO TOCADO … base_gmodentity` con `( 1 hijos )`.** O sea que **el 0 de la r20 era una
> ausencia no medida y no una ausencia**: decía *«en esta corrida no pasó»* y se leyó como *«no puede
> pasar»*. El bot no lleva arma, pero **algo de fuera le parentea una entidad** — la clase impresa era
> la base genérica, así que no identifica a nadie, y por eso el instrumento imprime ahora también el
> modelo y el índice.
>
> Y el bucle destapó un agujero propio, que no se veía mientras nunca corría: **el reconciliador es
> idempotente**, así que un hijo que nace *mientras el fantasma ya está invisible* no pasaba por la
> primitiva nunca — quedaba un objeto dibujado colgando de un fantasma que no se ve. Hay un tercer
> motivo de re-aplicación (cambió la cantidad de hijos), y la bitácora lo rotula para que no se
> confunda con una transición. Lo cierra `phantasmagoria-hijo-r23`.

### 20.3 Cuál de las tres invisibilidades de Source, y para qué

| | Qué hace | Dónde va | Por qué |
|---|---|---|---|
| `SetNoDraw( true )` | no se dibuja **nada** | **① y ②** | barato, no toca la solidez, alternable cada tick, y es **networkeado**: el cliente puede leer `GetNoDraw()` y decir el estado REAL ⚠ **la última mitad está REFUTADA, ver abajo** |
| `SetMaterial( mat )` | se dibuja con otro material | **③** | es lo único que da **silueta translúcida** y **sombra opaca** |
| `SetRenderMode` + alpha | el clásico | ninguna, por ahora | ⚠ la lección ya pagada en este taller: **`$alpha` no vuelve translúcido a nada, es `$translucent`**, y un material sin la flag se dibuja opaco sin un solo error |

> ⚠⚠⚠ **DECISIÓN REVERTIDA (r22, 2026-08-09, decisión del autor): `SetNoDraw` NO se usa para ①, y la
> fila de arriba queda como historia.** El diagnóstico se cerró en juego: **la ausencia se hace en el
> `ENT:Draw` del cliente, con la técnica de HIM**, y la entidad se sigue transmitiendo entera.
>
> | | Qué hace | Dónde va |
> |---|---|---|
> | **el `Draw` del cliente no dibuja** | el modelo no se dibuja y **la entidad sigue viajando**: el cliente conserva la posición y el marcador puede seguirla | **① y (probablemente) ②** |
>
> **De HIM se porta la técnica y no el cableado.** Su `Draw` pregunta `self:IsSolid()`
> (`terminator_nextbot_homeless/client.lua:54`), o sea que **su invisibilidad es su no-solidez** — el
> mismo acoplamiento por el que §20.1 rechazó el cloak de la base, ahora del otro lado. Nuestro
> fantasma ausente **es sólido a propósito**, así que con esa señal no escondería a nadie nunca: la
> señal nuestra es el **NW var**. *Dos addons pueden necesitar el mismo dibujo y distintas razones
> para dibujarlo.*
>
> **Y la acreditación cambia de lugar, que es la mitad que faltaba:** ya no hay bandera que preguntar,
> así que se cuenta **el camino del render**. `saltos del Draw` sólo lo puede tocar la rama que se
> saltea el dibujado. *Un contador que sólo puede escribir el mecanismo prueba que el mecanismo
> corrió; una bandera sólo prueba que alguien la escribió.*
>
> ⚠ **Lo que cuesta, y tiene su fila:** con `SetNoDraw` la entidad desaparecía del cliente y con ella
> todo lo que otros addons dibujen encima. Ahora está ahí, así que **un HUD de terceros puede delatar
> al fantasma invisible** (en las capturas de la r20 hay una barra `Phantasmagoria Ghost 900|900`
> flotando sobre el bot). `FL_NOTARGET` no la tapa: esa bandera es para los NPC.
>
> ⚠⚠ **REFUTADO EN JUEGO (r20, 2026-08-09): «el cliente puede leer `GetNoDraw()` y decir el estado
> REAL» es falso** — y esto es lo que llevó a la reversión de arriba. Con el fantasma invisible y **fuera de la pantalla**, el cliente imprimió
> `render: se dibuja · el server dice INVISIBLE`. La lectura que esta tabla daba por buena devolvió
> `false` sobre una entidad que el engine no estaba dibujando — y de esa frase colgaban **las dos
> mitades de §20.4**: el modo honesto nunca salteó a nadie y la línea de HUD contó `0 invisibles` con
> uno delante. *Una propiedad de la red que nadie midió sostuvo el instrumento entero de un bloque.*
>
> La causa: `EF_NODRAW` manda la entidad a `FL_EDICT_DONTSEND`, o sea que el cliente **deja de
> recibirla** — la copia sigue en la lista (los dos conteos de la r20 dieron 1) pero congelada, con la
> posición vieja y la bandera sin llegar. **Diagnóstico cerrado por el autor el 2026-08-09**, con tres
> testigos que decían lo mismo por caminos distintos: el marcador que no aparecía, la posición vieja,
> y el physgun agarrando al fantasma donde había estado.
>
> Y el dato que estaba en disco desde el principio: **ni `wraithcloaking.lua` ni HIM usan
> `SetNoDraw`** — el wraith se esconde con `SetMaterial` (`:94`, `:110`) y `SetRenderMode` (`:136`),
> HIM directamente no dibuja en su `Draw`. Las dos son la familia que *no* deja de transmitir.
> §20.1 rechazó el módulo del wraith por cómo acopla la solidez, y eso sigue en pie: **la técnica de
> render y el módulo son dos decisiones distintas, y sólo una de las dos se había medido.** *Dos
> terceros independientes evitaban la misma primitiva y ninguno de los dos documentos lo dijo como una
> advertencia — se leyó como estilo.*

⚠ **El riesgo abierto de ② es la RED, no el render.** `SetNoDraw` es una bandera de entidad que
viaja en el snapshot. Con un ciclo visible de **0,08 s** y snapshots a ~20-30 Hz, un pulso corto
puede caber en **dos** actualizaciones o en **una**, y el cliente se lo tragaría. Eso **no es una
objeción a la decisión**: es la fila de check que ② tiene que traer, y si sale roja la salida está
escrita — mover el parpadeo al cliente, networkeando **el horario** y no cada conmutación. Queda
anotado ahora para que el día que aparezca no se lea como «el material está mal».

### 20.4 **DECISIÓN: qué hace el marcador de debug cuando el fantasma es invisible**

`phantasmagoria_debug_ghost` (cliente, default **1**) dibuja caja, haz de 220 u y etiqueta **con
`IgnoreZ`**. Hasta hoy era el instrumento que hacía visible un modelo oscuro en un mapa oscuro.
**Desde este bloque es lo único que te dice dónde está algo que el diseño quiere invisible:
cualquier corrida hecha con eso en 1 no mide la mecánica, la tapa.**

La convar pasa a tener **tres** valores, y el default no cambia:

| | Qué hace |
|---|---|
| `0` | nada |
| `1` | **siempre** — el wallhack de hoy. Sirve para todo lo que no sea la invisibilidad |
| `2` | **honesto** — no dibuja al fantasma que está invisible. Es el modo obligatorio de las filas de ① y ② |

Y las dos mitades que hacen que el modo 2 sea medible, porque **«no lo veo» y «no lo dibujé» se ven
exactamente igual**:

- **La etiqueta dice el estado de render**, leído del **destino** y no de nuestra creencia: el
  cliente lee `GetNoDraw()` y `GetMaterial()` de la entidad —que es lo que el engine va a usar de
  verdad— y lo imprime al lado de lo que el servidor *dice* por NW var. **Si los dos divergen, eso
  mismo es el hallazgo**, y hoy no habría forma de verlo.
  > ⚠ **Y divergieron en la primera corrida — pero el hallazgo no era el que este renglón esperaba.**
  > La divergencia no delató al servidor: delató a *la lectura*. Desde la r21 se imprimen **cuatro**
  > —`NW`, `GetNoDraw()`, `IsEffectActive( EF_NODRAW )` e `IsDormant()`— y **la que decide es el NW
  > var**, que es la única que se pudo acreditar. *El principio («preguntar al destino, no a la
  > fuente») era correcto; el defecto fue elegir un solo campo del destino y no comprobar que
  > contestara.* Dos lecturas de la misma bandera, al lado, salen más baratas que otra ronda.
- **En modo 2 hay una línea de HUD permanente** — `debug_ghost 2 ( honesto ) · N en PVS · M
  invisibles ( no se dibujan )`. Un fantasma invisible deja de dibujar su marcador, pero el contador
  sigue subiendo: *el instrumento sigue hablando cuando deja de dibujar*. Es la regla que costó tres
  rondas en la tajada A —**si el criterio es visual, el instrumento tiene que producir texto**— y
  además queda dentro de la captura.
  > ⚠ **La línea habló, y dijo `0`.** En la r20 contó `0 invisibles` con el fantasma invisible
  > delante, porque colgaba de la misma lectura refutada. *Un instrumento que sigue hablando cuando
  > deja de dibujar es media garantía: la otra mitad es que lo que dice se pueda acreditar.* Desde la
  > r21 cuenta por el NW var y trae un **tercer** número —`K con la posición CONGELADA`—, que es el
  > que cubre el modo de falla que ninguna de las dos mitades podía ver: **un marcador dibujado en el
  > lugar equivocado se ve igual que uno correcto**, y desde la pantalla se lee como «no se dibuja».

### 20.5 De dónde sale el parpadeo — **las dos fuentes, y una de las dos ya no existe**

| | Qué es | Qué trae | Confianza |
|---|---|---|---|
| **A** | `lua/phantasmagoria/ghost_types.lua`, los comentarios por tipo. Backend del cheat sheet de tybayn (zero-network.net) | **prosa**, ningún número de parpadeo | datos del juego |
| **B** | resumen que pasó el autor, generado por Gemini | **los números** | **sin verificar** |

**Lo que dice B, como hipótesis a confirmar:** estándar visible 0,08-0,3 s · invisible 0,1-1,0 s;
Phantom invisible 1,0-2,0 s; Oni invisible < 0,5 s; Deogen más visible cuanto más cerca; Myling
parpadeo estándar (lo suyo es el alcance del ruido).

**Dónde coinciden las dos** (lo que se puede dar por bueno): **Phantom** menos visible · **Oni** más
visible · **Deogen** más visible. Y son **los tres únicos** tipos cuyos comentarios de la fuente A
mencionan visibilidad.

> ⚠ **El «Yokai rápido» de §5.2 no tiene respaldo y queda marcado como INVENTADO.** Los comentarios
> del Yokai hablan de voz, música y distancia de detección; ninguno menciona parpadeo. **Y la
> ausencia es genuina, no un recorte:** `dev/gen_types.py:104` trunca las notas en `notes[:8]`, y
> contadas las 30 fichas sólo **banshee** y **shade** llegan al tope. El Yokai trae 5. *Una ausencia
> sólo vale como dato cuando se sabe que el generador no la produjo.*
>
> ⚠ **Y regenerar la tabla NO es una opción hoy: `dev/g2.json` no está en el repo.** El encabezado
> de `ghost_types.lua` manda «regenerar con dev/gen_types.py» y esa instrucción es, ahora mismo, un
> callejón sin salida. Además el generador lee `min_speed` / `max_speed` / `alt_speed` /
> `hunt_sanity` y las notas del wiki: **no hay ningún campo de parpadeo en el esquema**, así que ni
> con el JSON de vuelta saldría el número.

### 20.6 **DECISIÓN: `blinkRate` no se escribe. Se escriben DOS DURACIONES**

⚠ **La trampa de vocabulario puede invertir la implementación entera.** La fuente A dice del Oni
*«blinks MORE frequently during hunts, making them more visible»* y la B dice *«parpadea muy poco»*.
Las dos concluyen **más visible**, por mecanismos opuestos: en Phasmophobia **«blink» es el momento
en que APARECE**; en castellano «parpadear» se entiende como el momento en que **desaparece**. Con
el sentido invertido, **el Oni sale invisible y el Phantom visible — y las dos fuentes seguirían
pareciendo correctas**.

**La decisión no es fijar el sentido por escrito: es elegir un nombre que no se pueda invertir.**

```lua
-- hunt.blink = { visible = { 0.08, 0.30 }, invisible = { 0.10, 1.00 } }   -- segundos
```

Una **duración** trae su dirección adentro; una **frecuencia** no. `visible` e `invisible` no
admiten dos lecturas, y el Oni y el Phantom salen del mismo par de campos sin ningún `if` de tipo:
el Oni con `invisible` corto, el Phantom con `invisible` largo. **La palabra `blinkRate` queda
prohibida en el código de este addon**, y `blink` sobrevive sólo como nombre de la tabla.

**Y el dato va en un archivo aparte, `lua/phantasmagoria/ghost_blink.lua`, escrito a mano.** No
dentro de `ghost_types.lua`, por dos motivos que son el mismo: ese archivo dice **«GENERADO
AUTOMÁTICAMENTE. No editar a mano»**, así que una edición manual se perdería en la próxima
regeneración **sin dejar rastro**; y mezclar datos del juego con datos inventados en el mismo
archivo destruye la única propiedad que hace confiable al primero. *Si es a mano, que se vea que es
a mano* — y que se vea **desde el nombre del archivo**, no desde un comentario adentro.

Cada entrada lleva su procedencia (`fuente = "B"` / `"derivado"` / `"INVENTADO"`) y el instrumento
la imprime. Los tipos sin entrada usan el estándar, y el reporte dice *estándar* y no un número
huérfano.

### 20.7 Las tres trampas que quedan vivas, y qué se hace con cada una

- **① `IsSilentStepping` NO tapa las pisadas** — censados los seis call sites de
  `MakeFootstepSound`: ninguno de caminar, saltar o aterrizar lo consulta antes de sonar. El
  silencio de verdad vive en `server_steps.lua` y **ya está cerrado en juego**. *No se duplica.*
- **② `FL_NOTARGET` sobre NUESTRO fantasma es al revés que la trampa de NEAD.** §19.5 rechazó NEAD
  porque le pone la bandera **al jugador** y eso lo vuelve invisible para el fantasma. Acá va sobre
  el **bot**, y hace que otros NPC lo ignoren — **no afecta a que él te vea**. Queda escrito para
  que nadie lo «corrija».
- **③ El hueco de 0,25 s (D-2) deja de existir**, y no porque se lo arregle: porque la decisión de
  §20.2 no pasa nunca por `DoHiding`. La solidez la sigue escribiendo un solo dueño y el hueco era
  del otro camino.

### 20.8 En qué orden va el código

| | Qué | Depende de | Estado |
|---|---|---|---|
| **①** | la ausencia fuera del hunt: la primitiva, la política, el marcador honesto | nada sin verificar | **escrita** — `server_cloak.lua`, planilla `phantasmagoria-ausencia-r20` |
| **②** | el parpadeo del hunt | los números de la fuente **B**, sin verificar, y la fila de red de §20.3 | diseñada, sin escribir |
| **③** | los estados estéticos de los eventos | §7 y los materiales | otro bloque |

---

## 21. Los eventos paranormales — **CORRIÓ EN JUEGO (r1), y la r2 está escrita sin correr** [2026-08-09]

**Pedido del autor, literal:** *«ver como lo hace el mod GM Paranormal Events para realizar los
eventos paranormales como flicking de luces, lanzar objetos y demas, y agregar esas funcionalidades a
phantasmagoria para que la entidad use eso, y que lo use **cercano a la entidad** con cvars propias y
flag para desactivar cada uno de esos sucesos paranormales (que son en parte el gameplay normal de
phasmophobia, el fantasma suele tirar cosas o hacer parpadear las luces en estado de Calma). Los
Flags son para hacer que algunos boten objetos otros los hagan con mayor intensidad y asi, nos puede
servir para eventos como **HUNTS** y cosas asi.»*

Motor en `lua/entities/terminator_nextbot_phantom/server_events.lua`; rasgos por tipo en
`lua/phantasmagoria/ghost_flags.lua`. Planilla `dev/checks/phantasmagoria-eventos-r1.html`.

### 21.1 La diferencia de fondo con gmpa es **una sola palabra: cerca de quién**

gmpa elige **un jugador al azar** y busca una navarea a ≤2048 u *de él*
(`GetRandomNavAroundPlayer`, `:295-327`). El fantasma no participa en la elección. Por eso su
actividad se siente como un generador de sustos ambiental y no como una presencia — y por eso su
*favourite room* tuvo que ser un `Vector` hardcodeado (`:93`): no había nadie a quien preguntarle.

Acá **el radio cuelga del fantasma**. Todo evento pasa a menos de `phantasmagoria_ghost_evradius`
(450 u ≈ 8,5 m) de él, lo que convierte la actividad paranormal en un **instrumento de
localización** — que es lo que es en el juego: la actividad te dice dónde está la habitación, y la
habitación te dice dónde poner las cámaras.

**La consecuencia hay que aceptarla de frente, y la fila 08 de la planilla la mide:** si el fantasma
está lejos, no pasa nada, y eso es *correcto*. Un jugador en la otra punta del mapa no tiene que oír
nada.

### 21.2 Las ocho categorías

| categoría | qué hace | banco de sonido |
|---|---|---|
| `throw` | tira props físicos cercanos | `event/throw` |
| `knock` | golpea una puerta o una pared | `event/knock` (puerta) · `event/impact` (pared) |
| `creak` | hace crujir el piso | `event/creak` |
| `door` | abre o cierra una puerta, delegando en `server_doors.lua` | `door/` |
| `light` | parpadeo o estallido de luces cercanas | `light/` · `event/impact/lightbulb_smash` |
| `sound` | susurra, respira o tararea | `ghost/paranormal_voice` · `breathing` · `humming` |
| `prop` | hace sonar un trasto de la casa | `prop/` |
| `furniture` | abre un armario o un cajón | `furniture/` |

**Los 152 clips citados existen en disco, 152 de 152** (verificado por script, no por inventario a
ojo). El catálogo ya estaba organizado *por evento* desde el cierre de audio del 2026-08-03: `event/`
con sus cuatro sub-bancos existía antes que el motor.

**Cero assets de gmpa.** Montar `sound/gm_paranormal/` sería la colisión de rutas que
`phantasmagoria_assetcheck.lua` existe para detectar.

Y **la voz es una y se sortea una sola vez por fantasma**: el catálogo tiene dos (la 1 femenina, la 2
grave) y *el índice del archivo es la voz*. Sortear clip por clip haría que el mismo fantasma susurre
con una voz y respire con la otra, que es peor que no tener dos — delata que el sonido es una tabla.
La fijan los dos tipos que la fuente marca *«Can only be female»*: Banshee y Dayan.

### 21.3 Los cuatro defectos de gmpa que el motor **no** hereda

1. **La escalera no es exclusiva.** gmpa tira `math.random(1,100)` una vez y encadena **nueve
   `if eventChance <= N` sin un solo `elseif`** (`:562-670`): un tiro de 3 dispara los nueve en el
   mismo frame. Acá hay **una tabla de pesos** y se sortea **una** categoría por disparo.
2. **El debounce se comprueba después de actuar.** gmpa mira `doorLastInteraction` en `:761-765`, o
   sea *después* del `Fire("Use")` de `:758`, y escribe la tabla en `:775`, detrás de un `return` que
   casi siempre gana.
3. **El parpadeo son ~90 timers anidados** (`:621-632`). Acá son 2-5 `Fire` con delay, que es la
   forma de HIM (`terminator_nextbot_homeless/server.lua:373-380`).
4. **`math.random(1, #tabla)` sin guarda, en nueve lugares.** Toda elección pasa por `elegir()`, que
   devuelve `nil` sobre una tabla vacía.

### 21.4 Dónde se engancha — y por qué **no** es un `Think`

Las dos ranuras obvias están ocupadas y la tercera es una trampa:

| candidato | por qué no |
|---|---|
| `ENT.MyClassTask.Think` | es de `server_doors.lua:1301`. Y `RunTask` **corta en el primer callback que devuelve no-nil** (`taskoverride.lua:47`) |
| `ENT:AdditionalThink` | es de `server_stuck.lua:990`. Un archivo nuevo que lo declare **no encadena: BORRA**, porque `myTbl.BaseClass` apunta a `terminator_nextbot` y no a la versión anterior |
| cualquier `Think` de tarea | ⚠ **no corre mientras un jugador maneja al bot** — vive dentro del coroutine de prioridad (`behaviouroverrides.lua:694-695`). El motor se apagaría entero, sin un error |

Va en **un solo `timer.Create` de servidor a 1 Hz** que recorre `PHANTASMAGORIA.EachGhost`. Un evento
cada 25-90 s no necesita un callback por frame.

**Lo que se pierde y cómo se compensa:** un `Think` de tarea aparece por nombre en
`phantasmagoria_ghost_where`, y «se enganchó» deja de ser una suposición. Un timer no. Por eso el
reporte imprime **siempre** el contador de vueltas del scheduler: *una guarda que sólo habla cuando
falla no puede acreditar que corrió.*

### 21.5 Los rasgos: tres reglas que salvan al Mimic y a los Twins

Los rasgos viven en `ghost_flags.lua` y **no** en `ghost_types.lua`, porque ese archivo lo **pisa
entero** `dev/gen_types.py:119`. Se fusionan sobre las filas al cargar.

1. **Van en sub-tablas, nunca en la raíz de la fila.** El Mimic imita *«all behaviors … excluding
   evidence»*: con los rasgos dentro de `events`, imitar es devolver el `events` del imitado. Sueltos
   al lado de `evidence` haría falta una lista de exclusiones campo por campo — un `if` diferido.
2. **El motor lee por un getter (`ENT:phantom_EventFlags()`), nunca el campo.** ⚠ El repo hace hoy lo
   contrario y está medido: `phantom_GetType()` tiene **cero llamadores** y los cuatro consumidores
   leen `phantom_Type` crudo. El motor de eventos **no copia ese patrón**, a propósito.
3. **`radius` es un array indexado por la iteración.** Los Twins hacen *«2 interactions at the same
   time»*, una al radio normal y otra al extendido (8,48/2,12 = **4,00 exacto**, y 16,97/4,24 =
   4,002: el factor sale de la fuente, no de una elección). Con `count = 1` y `radius = { 1.0 }` el
   bucle es idéntico al de los otros 29 — no es una rama nueva, es un bucle de largo uno.

**`count` y `burst` son dos ejes y no uno**, y esa separación salió de la revisión: eran el mismo
campo leído en dos lugares y **se multiplicaban entre sí** (un Poltergeist cazando llegaba a ~32
props y 32 `EmitSound` en un frame, con techo de 64, y el reporte lo mostraba como «1 disparo»). Hoy
`count` = categorías simultáneas, `burst` = objetos por tirada. **Y eso es lo que separa al
Poltergeist de los Twins:** el primero hace *una* interacción con cuatro objetos, los segundos hacen
*dos* interacciones distintas en dos radios. Con un solo eje los dos colapsaban en «hace más cosas».

Y el hallazgo más fuerte del corte es **el signo**, `dir`: +1 «solo enciende», −1 «solo apaga», 0 las
dos. Cuatro tipos lo sostienen en la fuente y son los que **ningún peso escalar puede distinguir** —
Mare *«cannot turn ON lights»* contra Jinn *«cannot directly turn OFF the breaker»*. Con un peso, los
dos son «el tipo que toca las luces». ⚠ Honestidad sobre el alcance: de los cuatro, **hoy sólo Mare
tiene destino implementable**; los otros tres piden el breaker y las llamas, que no existen.

### 21.6 Qué se declaró **fuera de alcance**, y por qué se escribe

| eje | sostenedores | por qué no se escribió |
|---|---|---|
| **apariciones** | 7 (Oni, Shade, Phantom, Deogen, Goryo, Obake, Wraith) | la visibilidad tiene **dueño único**: `server_cloak.lua` (§20). Entra por `phantom_SetVisible` o no entra |
| **breaker** | 2 (Hantu, Jinn) — la asimetría mejor sostenida de la tabla | **GMod no tiene cuadro de luces.** Dos sostenedores y **cero destino** |
| **llamas** | 1 (Onryo) | las velas todavía no son una entidad encendible |
| **temperatura** | 1 (Hantu) | singleton real. Los 12 tipos con `freezing` son **evidencia**, no evento |
| **`react.*`** | 4 | es **percepción** (§18), no eventos |
| **posición doble** | 1 (Twins) | no es un rasgo: es que la entidad tenga dos posiciones |
| **linterna del jugador** | — | gmpa la tiene, y rota: `weapon_flashlight` **no existe en GMod** (0 SWEPs en 62 addons). No se portó esta ronda |
| **`func_breakable`** | — | gmpa lo tiene (`:1010`) y es su única rama buena de romper. No se portó esta ronda |

*No se escribe un mecanismo sin destino* — y se anota, para que la próxima sesión no lo «descubra» y
lo meta como un `if`.

### 21.7 La revisión adversarial, y las cuatro reglas que dejó

Doce agentes en seis ejes (Lua/alcance, semántica, integración, gameplay, rendimiento, instrumento),
cada hallazgo pasado por un escéptico con el sesgo puesto en **refutar**. **Quince defectos
confirmados sobre código recién escrito.** Los cuatro que dejan una regla que sobrevive a este
bloque:

- **Un comentario mentiroso se propaga al lector que lo cita — y esta vez el lector fui yo.**
  `server.lua:3466-3468` afirmaba que la guarda de `server_cloak.lua` comprueba **tres** claves de
  `MyClassTask`, *«…y `BehaveUpdatePriority` de este archivo»*. Es falso en las dos mitades: el cloak
  lista **dos** (`:826`) y **descartó esa clave a propósito** (`:385-386`, con todas las letras).
  `server_events.lua` copió **la lista del comentario en vez de medir**, y quedó tirando
  `ErrorNoHalt` determinista **en todos los arranques**, acusándose de pisar una clave que nunca
  existió. Es el nº 22 del catálogo: *un control que fabrica el síntoma que busca*. Los dos
  comentarios están corregidos, y el censo real son **tres** asignaciones en todo el addon:
  `= {}` (`server.lua:3426`), `.Think` y `.ModifyMovementSpeed`.
- **Un flag que se lee en dos lugares se compone en dos lugares, salvo que alguien lo impida.**
  `count` estaba documentado como sirviendo a dos ejes; lo que no estaba escrito —ni era cierto— es
  que fueran **independientes**.
- **Medir el destino, no enumerar las salidas.** `EV.door` devolvía `true` tras llamar `Use2`, que
  tiene **cinco salidas silenciosas** — y la cuarta es **nuestra propia convar**
  `phantasmagoria_ghost_opendoors 0` vía el veto `TerminatorBlockUse`. Con esa convar en 0 el evento
  sonaba la manija, la hoja no se movía, y el instrumento imprimía `OK -- puerta prop_door_rotating
  #123`: **verde exacto sobre cero comportamiento.** Enumerar las cinco sería frágil (la segunda se
  activa porque un tercero *agregue* un campo: `if toUse.GetDriver then return end`); lo que no
  envejece es leer el estado de la hoja antes y después.
- **Se leyó el mecanismo de HIM y se salteó su guarda.** El parpadeo copió la forma (2-4 `Fire` con
  delay) y no la **primera línea** del precedente: `if not ent:GetOn() then return end`. Sin ella,
  una lámpara ya apagada recibía tres `SetOn(false)`, sonaba el interruptor, y el reporte devolvía
  «3 conmutaciones» con **cero cambio visible** — justo en la categoría cuyo encabezado promete que
  el vacío se va a poder distinguir del evento.

Dos más, del eje instrumento, que valen como advertencia general: **`evhunt` declaraba tres estados y
entregaba dos** (el `2` producía exactamente lo mismo que el `1` mientras el reporte imprimía
«forzado»), porque se copió la convención de tres estados **sin el mecanismo que la sostiene** — el
`2` significa «ignorá el flag del NPC» y el hunt no tiene flag por NPC. Y **la guarda de datos corría
después de la fusión que protege**, o sea que el paso capaz de matarla ocurría primero: *una guarda
que corre después del paso que puede matarla no es una guarda, es una autopsia que no se hace.*

Y una del arco de lectura, que corrige a este documento: **`FlingNearbyPhysicsProps` sí corre.**
§11.2 decía «su **único** call site» habiendo leído uno de **tres**. Ver la corrección ahí.

### 21.8 Lo que falta

- **El ritmo.** Los defaults (25-90 s, radio 450 u, masa 60 kg, fuerza 180-320 × masa) son una
  elección de escritorio. La fila 10 de la planilla es la única que los juzga. → **La r1 lo aprobó**:
  *«si no es muy seguido se siente bien ese sentido»*.
- **La cordura.** Mientras no exista, los eventos no drenan nada — y §19 dice que el drenaje está
  **condicionado a que existan eventos**. Este bloque es la mitad que faltaba de ese par.
- **`deogen.ogg`** está en el catálogo (`ghost/breathing/`) y **sin cablear**: es el clip propio del
  Deogen, que la fuente describe respirando por el spirit box. Hoy sería un singleton; se anota como
  asset disponible, no como hueco de diseño.

---

## 21.9 LA r1 CORRIÓ (2026-08-09) — y su hallazgo más caro no fue del motor

**Reporte del autor: 8 pasa · 0 falla · 3 sin correr.** El motor anduvo: `vueltas 209 del scheduler`,
las ocho categorías dispararon, la perilla por categoría apagó sólo la suya, el A/B por tipo salió
—*«si parece que si, un Poltergeist se comporta más agresivo con los props, rompió hasta una
ventana»*—, el hunt subió la intensidad y la tesis de §21.1 se confirmó: *«no sonó nada estando
lejos»*.

**Pero cuatro de esos ocho verdes podían salir verdes con el defecto adentro**, y uno de ellos lo
tenía. Lo que sigue son las cinco correcciones que la corrida forzó.

### 21.9.1 ⚠⚠ El banco de VOZ estaba mudo entero, y el instrumento decía `OK`

El autor pegó, entre las notas de la fila 10:

```
] phantasmagoria_ghost_event sound
    #442  sound -> 2 disparo(s)
        OK -- voz 1 / banco voice a 221 u
*** Invalid sample rate (48000) for sound 'phantasmagoria\ghost\paranormal_voice\voice_1_why_01.ogg'
```

Las dos líneas son del mismo disparo: **nosotros dijimos que sonó y el engine dijo que lo rechazó.**
Censados los 826 `.ogg` del árbol: **270 con un sample rate que Source no acepta**, y **el banco
`voice` roto al 100 % — 39 de 39 clips, las dos voces**. La categoría que el bloque existe para
lucir era la única completamente muda.

**La causa raíz estaba escrita como una decisión correcta en `sound/phantasmagoria/about.txt`:** los
391 clips extraídos del juego *«son el Vorbis ORIGINAL de Unity, copiados tal cual: reencodear
ya-comprimido sólo pierde»*. Es cierto sobre la **calidad** y falso sobre la **compatibilidad** —
copiar tal cual se trae el sample rate nativo de Unity, 48000, que Source rechaza. La partición por
vendor string del Ogg:

| vendor | total | inválidos |
|---|---:|---:|
| `Fmod5Sharp` (rip del juego, copiado tal cual) | 391 | **268** |
| `Lavf` (reencodeado por ffmpeg) | 265 | 0 |
| `Xiph libVorbis` (terceros / radio) | 170 | 2 |
| **TOTAL** | **826** | **270** |

> *El sample rate no es calidad, es compatibilidad. Una decisión de no reencodear puede ser correcta
> en el eje que la motivó y desastrosa en un eje que nadie nombró.*

⚠⚠ **Y ESTA TABLA ESTUVO MAL PUBLICADA, con la palabra «denominador» al lado, en cuatro archivos y
en el mensaje del commit `091aa68`.** Traía sólo las dos primeras filas, y **0 + 268 = 268 contra 270
inválidos**: faltaban dos, los dos clips de `prop/radio/`, de una **tercera fuente que el encabezado
de `about.txt` no declaraba** — decía *«656 archivos, de DOS fuentes»* cuando son **826 y tres**. La
causa raíz sigue en pie y explica **268 de 270**; lo que no se sostenía era llamarla partición
cerrada. Lo agarró la auditoría previa al push, tarde: el commit ya había salido.

> *Una partición que no suma el total no es una prueba: es una anécdota con tabla. Y se publica igual
> cuando el que la escribe ya tiene la respuesta y el número que falta es chico.*

Es el mismo defecto que el catálogo del taller lleva anotado como **un máximo sin su denominador** —
esta vez cometido por el que había escrito, dos párrafos antes, que *«una lista filtrada no es el
universo»*.

**Y el instrumento lo acreditó.** `EV.sound` hacía `sound.Play` y devolvía `true` **literal** en la
línea siguiente — el mismo archivo documenta que `sound.Play` no devuelve nada. Peor: **el autor ya
había arreglado este exacto modo de falla para `door`, en el mismo archivo**, y ahí la lección
está escrita («lo que no envejece es medir la hoja»). *Una lección aprendida en una función no se
aplica sola a la de al lado.*

### 21.9.2 Las luces del mapa: gmpa no tocaba lo horneado, y nuestra clase era **más** amplia

El autor pidió, sobre la fila 04: *«el mod GM paranormal podía tocar luces horneadas en el mapa […]
estoy probando en gm_funkis_night donde yo me acuerdo que el mod ese podía hacer eso»*.

**Se midió el mapa, no se opinó.** Se sacó `maps/gm_funkis_night.bsp` del `.gma` del Workshop y se
parseó el `LUMP_ENTITIES` (VBSP v20, 1224 bloques):

| | |
|---|---:|
| luces escritas en el BSP | **322** (268 `light` + 54 `light_spot`) |
| con `targetname` y lightstyle conmutable (32-43) | **43** |
| grupos distintos (targetnames) | **12** |

O sea que **el recuerdo del autor es correcto y la premisa de gmpa también**: no tocaba el lightmap,
tocaba las que sobreviven al compilado por tener nombre. Como los 43 comparten sólo 12 lightstyles,
apagar una apaga el grupo — **el apagón se ve por habitación**, que es exactamente lo que se
recordaba.

**Y en cobertura de clase nosotros somos estrictamente más amplios:** gmpa mira sólo `light`
(`gm_paranormalactivities.lua:570`, `:618`), así que pierde los 17 `light_spot` de ese mapa — el baño
entero. Nosotros miramos siete clases.

**Lo que nos diferencia es el radio, y eso es §21.1 y no un olvido.** Las 43 nombradas caben en una
caja de **862 × 1056 u** (la casa); las puertas y los props se reparten por todo el terreno — **37 de
las 65 puertas y 14 de los 15 `prop_physics` no tienen ninguna luz nombrada a 450 u**. Por eso
`throw` y `door` pueden tener sujeto en el mismo instante en que `light` no lo tiene, y **por eso ese
cruce no diagnostica nada** (se intentó usarlo como prueba de que el fantasma estaba en la casa: la
medición lo refutó).

**Quedan dos causas vivas y el instrumento no las separaba:**

1. el fantasma no estaba a 450 u de la casa, o
2. `ents.FindInSphere` no devuelve entidades **puntuales y no sólidas** — una `light` no tiene modelo
   ni colisión, y la partición espacial indexa lo sólido.

**Se cerró la (2) por construcción**, que era lo barato: `lucesCerca` pasa a recorrer
`ents.FindByClass` por clase con el filtro de distancia a mano. Mismo radio, misma tesis, mismo
censo — sólo cambia de dónde sale la lista, y es el mecanismo que gmpa usaba y le funcionaba.
*Cuando dos implementaciones difieren en el resultado y en el mecanismo, primero se iguala el
mecanismo.*

**Y el mensaje de vacío pasa a medir el mundo y no su propio método.** Decía *«no había luces
alcanzables a 450 u»* y enumeraba las siete clases; ahora imprime **cuántas hay en TODO el mapa, a
qué distancia está la más cercana y dónde está parado el fantasma**. ⚠ Además decía **«alcanzables»**
y en esa función **no hay un solo trace**: la palabra mandaba a buscar un filtro de visibilidad que
nunca se escribió.

> *Un vacío que sólo describe su propio método no es una medición del mundo: tres causas distintas
> escriben la misma línea.*

### 21.9.3 El veto de sandbox nombraba dos campos que no existen

`propVetado` decía `if ent.CargoItem or ent.cargo_ItemID then return "es un item de Cargo" end`. Un
grep sobre **todo el workspace** devuelve una sola aparición de cada uno: **esa línea**. El veto de
inventario **nunca vetó nada** — `CARGO.Containers.Attach`
acepta cualquier entidad, incluido un `prop_physics`, que es justo lo que la lista blanca deja pasar.
Los marcadores reales son `ent.CargoContainer` y `ent.CargoEntry`.

> *Un veto que nombra un campo inexistente se lee igual que uno que anda: el código está escrito, el
> comentario es correcto, y la guarda no existe.*

⚠⚠ **Y CAMBIAR EL NOMBRE NO LO HIZO ALCANZABLE, que es la mitad que casi se acredita de más.** La
revisión adversarial lo midió: **hoy ningún escritor de `CargoContainer` ni de `CargoEntry` produce
una entidad de las dos clases de `THROW_CLASSES`** — `CargoEntry` cae sobre `corpus_cargo_item` y
`CargoContainer` sobre lo que el servidor decida attachear. Se cambió un campo **inexistente** por
uno **real que tampoco alcanza al sujeto**. Queda escrito como póliza (la API es pública y se anuncia
como *«turn any entity into a container»*), pero **ninguna fila puede acreditarlo**, y por eso la
lección tiene una segunda mitad:

> *Un veto que nombra el campo correcto sobre un sujeto que nunca llega es tan inerte como uno que
> nombra un campo que no existe — y se lee todavía mejor.*

Entraron además tres vetos que faltaban —**constraints** (sin él, veinte tablas soldadas de 5 kg
pasan el tope de masa una por una y el fantasma arrastra la casa), **parenteado**, y `IsMoveable`
junto a `IsMotionEnabled` (el precedente que el propio comentario citaba usa **las dos** y estaba
copiada la mitad)— y el contador de vetados pasó de un entero a **un desglose por motivo**, que
además se imprime **también en el éxito**: antes salía sólo en la rama de fracaso, o sea en la única
escena que la fila 09 excluye por precondición.

### 21.9.9 ⚠⚠ La revisión adversarial mató **cuarenta** defectos en el código de esta misma tanda

Escrito el bloque de arriba, se revisó con cinco lentes independientes y verificación adversarial de
cada hallazgo: **40 confirmados, 11 refutados**. Los tres peores **los introdujo esta tanda**, y los
tres son de la misma familia: *un arreglo correcto en su eje que rompe algo en un eje que nadie
nombró*.

**① El veto por `GetCreator` habría apagado `throw` entero.** El razonamiento era bueno —*«`GetOwner`
está vacío en los props de sandbox, el que guarda al creador es `GetCreator`»*— y el efecto es que
**en GMod todo prop del spawnmenu lleva creator**, así que en un servidor sandbox real casi no queda
sujeto: la categoría insignia del Poltergeist se queda muda **con un motivo que suena razonable**.
Peor: corría antes que la masa y que los constraints, tapando a los dos filtros que sí distinguen.
Cuatro lentes lo encontraron por separado.

La distinción que faltaba es **spawnear contra construir**. Lo que hay que proteger es el trabajo del
jugador, y eso lo mide `HasConstraints`, no el hecho de haber sacado un barril del menú.

> *Un veto que no distingue «es de alguien» de «alguien lo armó» no protege al jugador: le apaga el
> juego.*

Y trajo un defecto de Lua puro que vale por sí solo: **`GetCreator()` y `GetOwner()` no devuelven
`nil` cuando no hay nadie — devuelven `NULL`, que es *truthy***. La cadena `a or b or c` cortaba en el
primero y **`GetOwner()` era código muerto**. La cadena va ahora con `IsValid` paso a paso.

**② El `EmitSound` de las voces le voló el audio al cadáver — y esa regresión la trajo el arreglo del
autor.** El scheduler disparaba eventos sobre fantasmas muertos (la base deja la entidad viva ~10 s) y
eso era un defecto **benigno**: con `sound.Play` en un punto, el susurro del cadáver sonaba. Con
`ghost:EmitSound` el canal cuelga de la **entidad**, y la base ya le puso `EF_NODRAW` al morir — que
la manda a `FL_EDICT_DONTSEND` y **el cliente deja de recibirla**. Es el mecanismo que la r22 midió,
aplicado en contra. La guarda va en `phantom_FireEvent` y no en el scheduler, porque el disparo manual
no pasa por el scheduler.

> *Un cambio correcto puede volver grave un defecto que ya estaba y era benigno: hay que preguntarse
> a quién más le cambia el piso.*

**③ El sonido con sujeto agarraba la silla en la que estás sentado.** `IsVehicle()` dice `true` sobre
`prop_vehicle_prisoner_pod`, y una alarma sonando en el auto que estás **manejando** no es un susto:
es un bug con cara de susto.

**Y el arreglo del cadáver era la mitad del arreglo.** La guarda `term_Dead` entró en el **contador**
y no en **la línea que el operador lee**: el mismo comando seguía acusando al inocente aunque el
número ya no subiera. Ahora hay dos ramas y la del cadáver **dice la verdad** en vez de callarse —
silenciarla dejaría al que ya vio la alarma pensando que se la ocultaron.

> *Arreglar el contador y dejar el texto es arreglar la mitad que nadie mira.*

**El `reset` se contradecía a sí mismo en tres frentes, y los tres los escribí en la misma edición:**
el comentario decía *«el reloj NO se toca: es comportamiento»* y **dos líneas abajo** lo reprogramaba;
ponía `vueltas` en 0 mientras la línea de al lado del reporte dice que **un 0 significa que el timer
no está corriendo** —fabricando el síntoma exacto de un motor muerto, en el comando que se corre justo
antes de medir—; y era **el único de los cuatro recorridos de fantasmas** que llamaba al método sin
comprobar que existiera.

> *Un comentario y su código pueden contradecirse en dos líneas consecutivas sin que ninguna prueba lo
> note.*

**Y la que más duele, porque el propio prompt de revisión la pidió:** el rótulo *«INCLUYE el
multiplicador del hunt»* se decidía leyendo `phantom_Hunting` **al imprimir** mientras el número que lo
acompañaba se había calculado **al sortear**. Es la familia «la foto vieja» que este repo ya cerró dos
veces (r18 y r18b), reaparecida en el instrumento que se escribió para cerrar otra. Ahora se guarda el
**hecho** (`ultimoMulHunt`) y no la condición — y se guarda el multiplicador y no un booleano, porque
un tipo cazando con `hunt.rate = 1.0` está en hunt sin que el hunt cambie nada.

**Tres más que valen como regla:**

- **`vueltas` es monótono y no caduca**: `209` se lee igual en un timer sano que en uno que murió hace
  diez minutos con 209 hechas — y esa línea es *la* acreditación del motor. Lleva la hora de la última
  vuelta y grita si pasó más del doble del tick.
- **El contador se partió en espontáneas/forzadas y su vecino `ultimo` no**: colgado del renglón
  rotulado *«( el scheduler, solo )»*, mostraba el último evento **del operador** como si fuera del
  motor. Va en su propia línea.
- **`quien( ghost )` adentro de un `timer.Simple`**: un cuarto de segundo después el fantasma puede no
  existir, y el renglón del veredicto de puertas —el único que dice si la hoja se movió— salía sin
  dueño. *La identidad se toma cuando se sabe, no cuando se imprime.*

**Y una del catálogo, sobre un comentario que este archivo ya sabía no copiar:** el input
`LightToggle` de `point_spotlight` **nunca se midió** — su única fuente es HIM, y los inputs de
`CPointSpotlight` en Source son `LightOn`/`LightOff`. Como `Fire` con un input inexistente **no tira
error**, el reporte decía *«N conmutaciones»* sobre algo que podía no haber pasado. No se cambió el
código sobre memoria (eso sería el mismo pecado del otro lado): el detalle dice ahora **«input(s)
enviado(s)»** y la medición es una línea en la planilla.

### 21.9.4 Las voces salen del fantasma — y la regla que lo impedía defendía código inexistente

Pedido del autor: *«las voces deberían ser del fantasma, no que las haga sonar donde no debe»*. En la
r1 salían a **112-450 u** de él (`puntoCerca`), y eso estaba **declarado** en el contrato común:
emitir en el fantasma *«mata al spirit box, a la parabólica y a la caja musical»*.

**Las tres tienen hoy cero líneas de código.** La regla defendía una decisión presente con tres
mecánicas futuras.

> *Una regla sostenida por código que no existe no se puede falsar, y por eso sobrevive a la
> evidencia.*

**`sound` pasa a ser la excepción de las ocho** y se emite con `ghost:EmitSound` —no con `sound.Play`
en su posición— para que la voz **siga al fantasma** mientras camina: un tarareo que se queda atrás
delata que el sonido no es de él. Las otras siete siguen sonando lejos. **La tesis no se toca:** el
radio sigue colgando del fantasma; lo que cambió es de dónde sale *ese* sonido, no hasta dónde llega
la actividad.

### 21.9.5 Los sonidos que **nombran** un objeto ahora tienen que encontrarlo

Pedido: *«sonidos de auto no deberían sonar a menos que se lo haga a un vehículo de half life 2 o
Glide»*. `EV.prop` sorteaba de una tabla plana **sin mirar el mundo** — cero `ents.*` en su cuerpo —
así que sonaba una alarma de auto en una casa vacía.

`car_alarm` y `car_lock` salen del banco ambiente y entran en `PROP_CONSUJETO`: sólo participan del
sorteo si hay un vehículo en el radio, y cuando salen **suenan desde él**. Un solo test cubre las dos
familias que el autor nombró, y está medido: **Glide pisa `Entity:IsVehicle()` en el metatable**
(`sh_glide.lua:326-330`) para que devuelva `true` en los suyos.

> *Un banco plano de sonidos «de objetos» es una lista de objetos que el juego afirma que están ahí.
> Los que nombran algo identificable tienen que comprobarlo; un crujido de piano puede sonar en
> cualquier casa.*

### 21.9.6 El instrumento: cinco defectos, y dos son reincidencias del propio repo

| | qué pasaba |
|---|---|
| **la acreditación del scheduler** | el disparo forzado escribía **los mismos contadores** que el timer, así que `despertadas: 87` no distinguía «el motor corrió solo» de «yo lo forcé». La planilla pedía un `reset` antes de medir ritmo: *le pedía al operador que no ensuciara el instrumento en vez de que el instrumento separara.* Ahora son dos cuentas y la bitácora rotula `[FORZADO]`. |
| **la bitácora sin serie** | escribía `#442` pelado, y GMod **recicla el EntIndex**: en la r1 hay un `#442` con números de Poltergeist y, dos pantallas abajo, un `#442` que la ficha declara Shade. **El mismo defecto ya estaba cerrado en `server_cloak.lua` y en `server_steps.lua`.** *Que una lección esté cerrada en el repo no la aplica al archivo que se escribe mañana: lo que se hereda es el texto, no la práctica.* |
| **el intervalo sorteado** | se calculaba, se devolvía, y el único llamador tiraba el retorno. Para decidir si el `rate` del hunt dividía el intervalo hubo que **restar timestamps de la bitácora a mano**; la respuesta fue que sí dividía, o sea que el código estaba bien y **la duda la fabricó el instrumento**. |
| **la ventana que se llena** | `bitacora ( 60 / 60 )` decía lo mismo con 60 renglones que con 600. Es la r23b otra vez, donde 28 de 40 renglones eran spawns. Ahora cuenta las descartadas **y** cuántos fantasmas escribieron. |
| **el `reset`** | nileaba `phantom_ev` **entera** — que guarda contadores **pero también** la cuarentena de puertas y el reloj —, y dejaba `next = 0`, que el scheduler lee como «recién nacido» y reprograma a 4-12 s. *Un botón que existe para limpiar el instrumento no puede fabricarle el primer dato a la medición que viene.* |

### 21.9.7 La alarma de `EF_NODRAW` acusaba a un inocente

El autor preguntó por una ráfaga de `!! ESCRITOR AJENO` sobre `#452/s10` mientras veía a `#442/s11`
perfectamente. **No es un remanente nuestro: el escritor es la base, en la muerte del bot**
(`terminator_nextbot/damageandhealth.lua:826`, `self:SetNoDraw( true )`, más `:823` sobre cada hijo).
`#452/s10` era un **cadáver**.

El defecto era de **alcance**: el reconciliador sigue corriendo sobre el cadáver los ~10 s que la
entidad sobrevive a su muerte. Ahora la alarma exige `not self.term_Dead`, que la propia base escribe
en `OnKilled` (`:677`) **antes** de llegar al `:826` — la guarda no tiene carrera.

> *Una alarma que no acota su sujeto no mide de menos: mide de más, y el falso positivo cuesta lo
> mismo que el defecto que buscaba.*

Y quedan dos cosas dichas y no arregladas, que la r2 tiene que mirar: **`ESCRITORES AJENOS` muere con
el fantasma**, así que el `0` que se leyó era de otro sujeto; y **la fila 11 habría dado PASA aunque
el escritor ajeno fuera real**, porque su criterio no mira ni la bitácora ni el contador.

### 21.9.8 Lo que queda diseñado y **sin escribir**

Los dos pedidos que la fila 10 abrió y que **no** entraron en esta tanda, con lo que ya está medido:

**① La radio.** *«Faltan los sonidos de radio creepy, para eso se puede usar los props de radio de
half life 2 y counter strike.»* — **Los diez `.ogg` ya están en disco** (`sound/phantasmagoria/prop/
radio/`) y **ninguna línea de Lua los cita**; el pedido estaba escrito en `about.txt` desde antes.
⚠ Pero **no se pueden cablear al banco `prop` como está**: medidas sus duraciones, van de **19 a 160
segundos**, y `sound.Play` no devuelve nada que se pueda apagar — es el mismo motivo por el que los
`_loop` quedaron fuera. La radio necesita **su propia categoría con sujeto real** (un prop de radio),
emitida con `ent:EmitSound` para poder pararla con `ent:StopSound`, y una guarda de duración.

**② El canto que te mira.** *«El canto se da para asustar al jugador, es un evento donde la aparición
se queda quieta y te mira, también canta caminando y manifestándose.»* — Hoy `EV.sound` con banco
`humming` es **sonido y nada más**. Y hay dos obstáculos medidos: **parar al fantasma le congela la
cara**, porque el único escritor de la mirada se sale por debajo de 30 u/s (es el defecto que §15
cerró desde el otro lado), y «quedarse quieto» no tiene una pieza limpia — el piso duro es 1 u/s.

**③ El sexo del fantasma.** *«Tal vez hace falta un flag para decir que el fantasma es hombre o mujer
así poblamos bien los sonidos y aparte usamos los modelos correspondientes según sexo.»* — **La mitad
del sonido ya existe y se llama `voice`**: el rasgo del tipo la fija (Banshee y Dayan son *«can only
be female»*) y si no, se sortea una vez por fantasma. Lo que **no** tiene dónde engancharse es la
mitad de los modelos: `ENT.Models` es un campo **de clase**, no por instancia. Esa es la pieza nueva,
y va con §12.2.
