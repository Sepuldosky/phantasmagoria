# PHANTOM — Documento de referencia

**Fecha del estudio:** 2026-08-01
**Objetivo:** un NextBot nuevo, **fuera del proyecto Corpus**, sobre la base *Terminator NextBot*,
con el comportamiento de **HIM** (te observa de lejos; cuando lo mirás, se aleja) más una feature
propia: **mandarte a una dimensión extra**.
**Carpeta estudiada:** [`dev2/`](../../dev/other/phantom/dev2/) — seis addons, **55.425 líneas de Lua en 125 archivos**.

Este documento es el resultado de leer los seis addons con 14 lectores en paralelo y de **auditar
adversarialmente cada API afirmada** contra el código: **1.042 afirmaciones verificadas una por una
— 882 confirmadas, 147 imprecisas, 13 refutadas**. Las refutaciones están incorporadas al texto; las
tres que más caro salían están en §4.3.

**Marca de confianza.** **[verificado]** = leído en el código, con archivo y línea, y contrastado por
un segundo agente que intentó refutarlo. **[lectura]** = leído una sola vez, no ejercido en juego.
**[propuesta]** = diseño nuestro, no existe todavía. **Nada de este documento se corrió en juego.**

---

## 1. El veredicto, en una página

**La base ya tiene escrito el comportamiento que querés.** No es una analogía: la tarea
`movement_watch` de la base Terminator se planta a distancia del jugador, **se prohíbe disparar**,
lo mira fijo, mide si el jugador la está mirando de vuelta, y si lo está, se escabulle. El comentario
del propio autor en [`shared.lua:6053`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/shared.lua#L6053)
dice `-- this is not a SNIPING behaviour!`.

Los cinco pilares de PHANTOM y dónde sale cada uno:

| Pilar | De dónde sale | Esfuerzo |
|---|---|---|
| Locomotion, pathfinding, navmesh | Base Terminator, heredado | **cero** |
| Te observa de lejos sin atacar | `movement_watch` ya escrita, §5.1 | ajustar 3 números |
| Detectar que el jugador lo mira | `ENT:enemyBearingToMeAbs()` ya escrita, §5.2 | **cero** |
| Aparecer/desaparecer como fantasma | `ENT.IsWraith = true`, **un campo**, §5.3 | **cero** |
| Dimensión extra | HIM ya la construyó entera, §7 | portar, moderado |

**Lo que hay que escribir de verdad es poco:** la máquina de estados que hilvana esas piezas, y la
amputación del lore de HIM. El resto es configuración.

**La decisión de arquitectura:** `ENT.Base = "terminator_nextbot"` — **no** `"terminator_nextbot_base"`.
Ver §3, es la trampa más fácil de comer.

---

## 2. Qué hay en la carpeta

| Addon | Lua | Archivos | Rol para PHANTOM |
|---|---:|---:|---|
| [`terminator nextbot/`](../../dev/other/phantom/dev2/terminator%20nextbot/) | 37.323 | 71 | **La base.** Todo el chasis y medio comportamiento |
| [`him/`](../../dev/other/phantom/dev2/him/) | 17.107 | 47 | **El pariente directo.** Ya es un fantasma sobre esta base |
| [`[gm] paranormal events/`](../../dev/other/phantom/dev2/%5Bgm%5D%20paranormal%20events/) | 1.056 | 1 | Banco de efectos y sonidos. API global, código frágil |
| [`scary black man .../`](../../dev/other/phantom/dev2/scary%20black%20man%20%28hood%20irony%29%20playermodel/) | 1 | 1 | Modelo. El más compatible de todos (§10) |
| [`phasmo-sounds-main/`](../../dev/other/phantom/dev2/phasmo-sounds-main/) | — | 265 | 265 `.wav` de Phasmophobia (141 MB). Ver diseño §7 |

> **Borrados el 2026-08-01 por decisión del autor:** `schizophrenia_v2/` (909 líneas) y
> `the hat man/` (29). El estudio de ambos se conserva en §9 y §10 porque su conclusión sigue siendo
> útil: uno era un resultado negativo y el otro dejó la regla de los `.mdl` homónimos.

---

## 3. El linaje: dónde engancha PHANTOM **[verificado]**

Son **cuatro** capas, no dos:

```
base_nextbot                     (engine, GMod)
  └─ terminator_nextbot_base     "SB Advanced NextBot Base" — chasis: networking, tasks-API, getters
       └─ terminator_nextbot     StrawWagen — EL CEREBRO: 33 tasks, pathing, enemigos, coroutines
            ├─ terminator_nextbot_wraith, _snail, _fakeply, _csoldier…  (11 subclases de ejemplo)
            ├─ terminator_nextbot_homeless   ← HIM, en el addon `him` (otro addon: se puede)
            └─ terminator_nextbot_phantom    ← PHANTOM   [propuesta]
```

**`terminator_nextbot_base` no tiene cerebro.** En sus 10 archivos no existe `BehaveUpdate`, ni
`BehaveStart`, ni `RunBehaviour` — cero coincidencias fuera de un comentario. Heredar de ahí no da
nada útil y rompe en varios puntos. **Las 11 subclases del addon y HIM heredan todas de
`terminator_nextbot`.**

**Un addon aparte puede subclasear sin problema** — HIM lo demuestra: vive en otro addon, en formato
carpeta, y funciona. El registro está documentado por el propio autor en
[`sh_terminator_registernpc.lua:42-65`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/autorun/sh_terminator_registernpc.lua#L42),
con un ejemplo explícito de "declará tu propia clase". El registro se difiere a un `timer.Simple(0)`
para que `.Category`/`.SubCategory` se hereden por el árbol de bases.

### El ciclo de vida, en corto **[verificado]**

`BehaveUpdate` **no piensa**: prepara estado y crea hasta 4 coroutines en `myTbl.BehaviourThreads`
(`priorityCor` = enemigos, `motionCor` = movimiento, `playerControlCor`, `disabledCor`). Es
`ENT:Think()` quien las reanuda con un presupuesto de tiempo por tick (`ENT.CoroutineThresh`) y
`NextThink(CurTime())` para autoacelerarse.

Los puntos de extensión pensados para vos: **`AdditionalInitialize`**, **`AdditionalThink`**,
**`MyClassTask`**, **`DoCustomTasks`**, **`MySpecialActions`**.

> **Importante para el orden:** `AdditionalInitialize` corre **después** de que la base resolvió el
> modelo y el FOV ([`shared.lua:3010`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/shared.lua#L3010)).
> Por eso es el lugar correcto para pisar defaults — es lo que hace HIM con `Term_FOV` (§4.3).

---

## 4. La plantilla mínima, y las tres trampas del contrato

### 4.1 El esqueleto **[verificado]**

El archivo más corto del addon,
[`terminator_nextbot_snail.lua`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot_snail.lua),
son **21 líneas**. El boilerplate real son 8:

```lua
AddCSLuaFile()
ENT.Base = "terminator_nextbot"        -- string exacto, ver §3
DEFINE_BASECLASS( ENT.Base )
ENT.PrintName = "Phantom"
ENT.Spawnable = true
terminator_Extras.RegisterNPC( "terminator_nextbot_phantom", ENT )

if CLIENT then return end              -- todo lo de abajo es server-only
-- …campos…
```

El molde más cercano a PHANTOM es
[`terminator_nextbot_fakeply.lua`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot_fakeply.lua)
(103 líneas): un bot **desarmado** que funciona — `ENT.DefaultWeapon = false`, `ENT.TERM_FISTS = false`.

Hay **~90 campos `ENT.*`** con default. Casi todos opcionales.

### 4.2 El bot pacífico **[verificado]**

Por default **el bot odia a los jugadores**: `GetDesiredEnemyRelationship` devuelve `D_HT` con
prioridad 1000 ([`enemyoverrides.lua:941-945`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L941)).
La puerta que lo decide es `ShouldBeEnemy`, líneas 493-494: sin `D_HT`, `return false`.

Se apaga en **un** lugar — sobreescribir `OnFirstRelationWithPlayer`, cuyo retorno pisa el `D_HT`:

```lua
function ENT:OnFirstRelationWithPlayer( ply ) return D_NU end
```

Alternativa sin subclasear: el hook `terminator_blocktarget` (línea 497).

> **⚠ Sirve para un bot pacífico, NO para un interruptor — 2026-08-06 [lectura].** El párrafo de
> arriba es cierto **al spawnear** y nada más: el retorno se **guarda** en `m_EntityRelationships`
> (`enemyoverrides.lua:883`) y `SetupRelationships` corre **una vez** (`shared.lua:3079`). Un bot que
> nace pacífico y se queda pacífico se resuelve así; uno que tiene que **alternar** en caliente, no
> — y encima `MakeFeud` (`:1046-1048`) reescribe la relación a `D_HT` de un balazo. Para alternar el
> punto es `ShouldBeEnemy`, que es donde se **lee** ese cache (`:493`). Ver §3.1 del diseño.

> **Dos correcciones a lo que decía este párrafo, del 2026-08-05, al escribir la entidad**
> [verificado]:
>
> **(a) La línea 947 es la llamada, no la definición.** La definición vive en otro archivo:
> [`damageandhealth.lua:872`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/damageandhealth.lua#L872).
>
> **(b) La implementación default NO está vacía.** Es cierto que no devuelve nada, y por eso el
> `D_HT` sobrevive — pero su cuerpo **implementa `ExtraSpawnHealthPerPlayer`**: cuenta jugadores,
> ignora al primero y a los `FL_NOTARGET`, y le sube `SpawnHealth` y el max health al bot por cada
> jugador de más. **Un override que no encadene al `BaseClass` mata esa mecánica en silencio.**
> Hoy no nos duele —no declaramos el campo— y por eso mismo el defecto sería invisible hasta que
> alguien lo declare.
>
> **(c) La firma de la llamada tiene cuatro argumentos**, no uno:
> `OnFirstRelationWithPlayer( self, ent, disp, priority, theirDisp )` (`enemyoverrides.lua:947`).
> La declaración solo nombra `ply`, así que los otros tres están disponibles y sin documentar.

### 4.3 Las tres trampas caras **[verificado — las tres salieron de refutar al lector]**

**① `ENT.Models` gana sobre `ENT.Model`.** Un PHANTOM que declare sólo
`ENT.Model = "models/npc/hatman.mdl"` **spawnea con Arnold**. El código
([`shared.lua:2973-2982`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/shared.lua#L2973))
es `local models = myTbl.Models; if models then model = models[math.random(#models)] end; if not
model then model = myTbl.Model end` — y la base trae `ENT.Models = { "terminator" }` heredado.
**Usá siempre `ENT.Models = { … }`.**

**② `Term_FOV` solo no alcanza.** El comentario de la línea 152 dice que poner un número ignora la
convar `termhunter_fovoverride`. **El comentario miente.** El callback de la convar
([`shared.lua:57-62`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/shared.lua#L57))
pisa `Term_FOV` justamente en las entidades que ya tienen número, si `AutoUpdateFOV` es true —
y el default es true. Hay que poner **las dos**:

```lua
self.Term_FOV = 180
self.AutoUpdateFOV = false   -- si no, la convar global te lo pisa en caliente
```

Es exactamente lo que hace HIM en `AdditionalInitialize` (`server.lua:851-852`).

**③ `SetupDataTables` colisiona con la base — y HIM tiene el bug vivo.** La base **no usa**
`SetupDataTables`: networkea con un helper propio de slots **hardcodeados**
([`terminator_nextbot_base/shared.lua:43-73`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot_base/shared.lua#L43)).
El slot `Bool 0` **ya es `Crouching`**. HIM declara `self:NetworkVar("Bool", 0, "IsDecoy")`
(`shared.lua:34`) sobre ese mismo slot: cuando hace `decoy:SetIsDecoy(true)` (`server.lua:1537`),
**le pone `Crouching = true` al señuelo**. PHANTOM debe empezar en slots libres (Bool 1+) o no usar
`SetupDataTables`.

Slots ocupados por la base: `Entity 0-1`, `Bool 0`, `Int 0-3`, `Float 0-1`, `Angle 0`, `Vector 0-2`.

### 4.4 Lo que salió de escribir la entidad de verdad **[2026-08-05]**

Las tres de arriba salieron de auditar el código. Estas cuatro salieron de tener que decidir cosas
que la lectura no obliga a decidir.

**④ El punto de entrada de una entidad-carpeta es `shared.lua`, no `init.lua`** — porque el registro
**tiene que correr en el cliente**. `terminator_Extras.RegisterNPC` termina en
`list.Set( "NPC", … )` y en `language.Add`
([`sh_terminator_registernpc.lua:21-26`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/autorun/sh_terminator_registernpc.lua#L21)),
y **el spawnmenu se arma en el cliente**: si el registro corre solo en el servidor, la entidad existe
y no está en el menú. El precedente exacto está en el vecino: HIM vive en otro addon, es una carpeta,
y su entrada es `shared.lua` con `AddCSLuaFile()` + `AddCSLuaFile( "client.lua" )` y el
`if CLIENT then include… elseif SERVER then include…` al final
([`him/…/terminator_nextbot_homeless/shared.lua:1-2, 43-49`](../../dev/other/phantom/dev2/him/lua/entities/terminator_nextbot_homeless/shared.lua)).
La base hace lo mismo. **[verificado por precedente]**

> El snippet que arrastraba ESTADO.md ponía ese contenido en `.../terminator_nextbot_phantom/init.lua`,
> que es el molde de un archivo **suelto** (`terminator_nextbot_wraith.lua` y compañía: `AddCSLuaFile()`
> + `if CLIENT then return end`) metido dentro de una **carpeta**. Que un `init.lua` solo deje al
> cliente sin registrar es **[inferencia, no medida]** — el loader de carpetas incluye `cl_init.lua` en
> el cliente, no `init.lua`, así que el `AddCSLuaFile()` lo manda y nadie lo incluye. No se midió
> porque no hacía falta arriesgarlo: se siguió el precedente que ya funciona.

**⑤ El navmesh es precondición del check, no del código.** `Initialize` avisa si
`navmesh.GetNavAreaCount() <= 0` (`shared.lua:3047-3066`) — pero **solo al creador**, y si la entidad
la spawnea un script no hay creador a quien avisarle. Un bot sin navmesh spawnea y no camina, y eso
es indistinguible de un bug propio. Es la causa número uno de «spawnea y no hace nada».

**⑥ `Spawnable = false` en las subclases de la base es deliberado, y son dos listas.**
`ENT.Spawnable` gobierna la pestaña **Entities**; `RegisterNPC` gobierna la pestaña **NPCs**. Las 11
subclases del addon ponen `Spawnable = false` con el comentario `-- dont show up in entity spawn
category` (p. ej. [`terminator_nextbot_cmetro.lua:15`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot_cmetro.lua#L15)):
están en el menú de NPCs y no quieren estar dos veces.

**⑦ `TERM_FISTS = false` apaga dos cosas que no son el puño.** Sin puños el bot **no mira hacia su
objetivo al moverse** (`motionoverrides.lua:2838`, con el comentario *«only look towards goal if we
have fists»*) y **no pega para desatascarse** (`shared.lua:2142`,
`tryToHitUnstuck = isstring( TERM_FISTS )`). Las dos son correctas para un fantasma; las dos explican
comportamiento que si no se lee como bug.

---

## 5. Lo que ya está hecho y no hay que escribir

### 5.1 `movement_watch` — el comportamiento HIM, ya escrito **[verificado]**

[`shared.lua:6001`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/shared.lua#L6001).
Invalida el path, se planta a `tooCloseDist`, y:

```lua
self.PreventShooting = true -- this is not a SNIPING behaviour!
…
local lookingAtBearing = 9
local lookingAtLenient = 15
local enemyIsLookingAtMe = enemyBearingToMeAbs < lookingAtBearing

if goodEnemy and not enemyIsLookingAtMe then
    data.SneakyStaring = true                     -- te miro y no te enterás
elseif enemyIsLookingAtMe and not data.slinkAway … then
    data.slinkAway = CurTime() + math.random( 8, 10 )   -- me viste: me voy en 8-10s
```

Y la salida (líneas 6268-6283): si al vencer `slinkAway` seguís mirando, `TaskComplete` +
`StartTask("movement_stalkenemy")`; si dejaste de mirar, **te perdona** (`data.slinkAway = nil`).

Para PHANTOM basta cambiar tres números: `tooCloseDist` (base 250 → 800-1500; el clamp mínimo es 75),
los tiempos de `slinkAway`, y la condición de salida.

**Regalo:** la línea 6071 hace `self:RunTask("StartStaring")` y **ningún task en todo el addon define
ese callback**. Es un punto de extensión libre: PHANTOM lo define y recibe "empecé a mirarte fijo"
sin parchear nada.

### 5.2 Detectar que el jugador te mira **[verificado]**

`ENT:enemyBearingToMeAbs( enemy )` —
[`enemyoverrides.lua:117`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/enemyoverrides.lua#L117).
Devuelve el ángulo **absoluto en grados** entre hacia dónde mira el jugador y dónde está el bot.
Hermana: `enemyPitchToMeAbs`. Motor: `WorldToLocal` + `atan2` (`terminator_funcs.lua:83-101`).

```lua
if self:enemyBearingToMeAbs( ply ) < 9 then  -- me está mirando de frente
```

> Corrijo lo que supuse a mitad de la investigación: dije que la base no resolvía el cono de visión
> inverso. Sí lo resuelve, y con una llamada.

Complemento — **"¿alguien puede ver este punto?"**:
`terminator_Extras.posIsInterrupting( pos )` →
[`terminator_funcs.lua:111`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/autorun/server/terminator_funcs.lua#L111),
devuelve `true, ply`. Es línea de vista + un radio duro de 1000u, **no** cono de visión. Es la
función para elegir dónde materializarse sin que te vean. Variantes: `posIsInterruptingAlive`,
`areaIsInterruptingSomeone( navarea )`.

### 5.3 El fantasma que aparece y desaparece — **un campo** **[verificado]**

```lua
ENT.IsWraith = true
ENT.NotSolidWhenCloaked = true
```

Con eso, `Initialize` llama `InitializeWraith` y viene gratis: material override, `SetNotSolid`,
`FL_NOTARGET` (invisible para otros NPC), `DrawShadow(false)`, sin decals, bloqueo de disparo
mientras está invisible, flicker aleatorio y una acción para el jugador-piloto.
**No hay que copiar `wraithcloaking.lua`.**

El punto de extensión existe y está pensado para esto — el comentario de la línea 45 dice *"so every
wraith can have different logic for hiding"*:

```lua
ENT.wraithTerm_CloakDecidingTask = function( self, data )
    self:DoHiding( self:enemyBearingToMeAbs() < 9 )   -- desaparecer cuando me miran
end
```

Look: `ENT.FlickerBarelyVisibleMat` / `ENT.FlickerInvisibleMat` (default: pared de escudo combine).
Sonidos: `ENT:PlayHideFX()` / `ENT:PlayUnhideFX()`.
Silencio: `function ENT:IsSilentStepping() return self.wraithTerm_IsCloaked end`.

> ⚠ **ESTE PÁRRAFO DECÍA ALGO FALSO Y SE CORRIGE ACÁ (2026-08-08), porque el bloque de la
> invisibilidad va a leerlo.** Decía que `IsSilentStepping` *«se consume en 10 puntos y mata pasos,
> golpes metálicos y sonidos de caída»*. **Se censaron los seis call sites de `MakeFootstepSound` en
> el bloque de las pisadas y es al revés: no tapa NINGUNA pisada.** Ni la de caminar
> (`ProcessFootsteps`, `behaviouroverrides.lua:141`, no lo consulta), ni la del salto
> (`motionoverrides.lua:2997`, con el chequeo en :2999 — o sea *después*), ni las tres del aterrizaje
> (`:3459`, `:3474`, `:3485`, cada una con su chequeo en la línea siguiente). El único que sí tapa es
> el de la caída letal (`:3599`), y de rebote. **Un fantasma «cloakeado» sigue sonando**, y hacen
> falta las dos palancas: `AdditionalFootstep` para la pisada e `IsSilentStepping` para lo que la
> rodea. Ver ESTADO.md, bloque de las pisadas.

> **Dos defectos del módulo** [verificado, por refutación]: (a) los cooldowns son **asimétricos al
> revés de lo que parece** — esconderse deja 0,25-0,75 s (`wraithcloaking.lua:138`), aparecer deja
> **2,5-3,5 s** (`:164`), o sea que tras materializarse no puede volver a desaparecer por más de dos
> segundos; (b) la restauración de solidez ocurre dentro de un `timer.Simple(0.25)`, así que **hay un
> cuarto de segundo en que el bot se declara visible pero sigue atravesable**.
>
> ⚠ **Y (a) no es un detalle a «tener en cuenta»: es un BLOQUEANTE para el parpadeo de Phasmophobia**,
> donde el ciclo entero —visible 0,08-0,3 s, invisible 0,1-1,0 s— dura **menos que el cooldown solo**.
> Encima `DoHiding` **se niega en silencio** cuando el reloj no venció (`:128`, un `return` pelado):
> el pedido se pierde sin dejar rastro. Ver §5.3 del prompt de la invisibilidad.

### 5.4 Otras piezas listas **[verificado]**

| Necesidad | Pieza | Dónde |
|---|---|---|
| Mirar sin disparar | `self:shootAt( pos, true )` | `shared.lua:1516` |
| Retroceder sin dejar de mirar | `loco:SetMaxYawRate(0)` alrededor del `path:Update` | `behaviouroverrides.lua:218-233` |
| Velocidad según si lo miran | callback `ModifyMovementSpeed` | `motionoverrides.lua:3803` |
| Retirada ya implementada | task `movement_backthehellup` | `shared.lua:4283` |
| Frenar en seco | `StopMoving()` + `InvalidatePath()` | `compatibilityhacks.lua:343` |
| Giro de cabeza sobrenatural | `ENT.AimSpeed` (grados/s; base 180, terminator 480) | `weapons.lua:1151` |
| Teleport seguro del bot | `terminator_Extras.TeleportTermTo` | `terminator_funcs.lua:315` |
| Oír disparos/ruidos | `terminator_Extras.RegisterListener( self )` | `terminator_alerter.lua:60` |

**Evento propio sin tocar el addon:** dejar `lua/terminator_events/phantom.lua` en **nuestro** addon —
`terminator_events.lua:176` hace `file.Find("terminator_events/*.lua", "LUA")`, que barre **todos** los
addons montados. Trae `deleteAfterMeet` ("desaparece después de que te vio") y `scout`.
**Pero ojo: `onStartFunc` nunca se ejecuta** — defecto real del addon, §12.

---

## 6. HIM: cómo resolvió el problema **[verificado]**

`terminator_nextbot_homeless` es **un péndulo de dos estados**, sin combate:

- **INVISIBLE / no sólido** → busca una navarea con línea de vista hacia vos.
- **SÓLIDO / quieto** → se planta y te mira.

El disparador es un acumulador, **`data.discomfort`**, que sube según cuánto lo mirás y baja cuando
mirás para otro lado. Al cruzar `maxDiscomfort` → `SetHidden(true)` y vuelve a empezar.
(`server.lua:2187-2261`; los umbrales se calculan por distancia antes de usarse, 1373-1420 — a menos
de 800u sólo tolera **una** unidad de incomodidad.)

**La detección es doble.** Server por ángulo (`enemyBearingToMeAbs`) **y cliente por proyección a
pantalla** dentro de su propio `ENT:Draw` (`client.lua:53-126`), que clasifica en tres zonas y manda
dos net messages: `homeless_seen` y `homeless_seen_seen_seen` ("te vi mirándome de verdad").
Trata aparte los render targets — cámaras y espejos.

**La invisibilidad de HIM no es un material:** `SetHidden` hace `SetNotSolid` + `DrawShadow(false)` +
`FL_NOTARGET`, y el `Draw` del cliente literalmente **no dibuja**
(`if not plsDraw and not self:IsSolid() then return end`). Es una solución distinta de la del wraith
y más barata; la del wraith es más vistosa.

**Dónde se materializa:** un `scoreFunction` (líneas 1691-1838) puntúa navareas por
`area2:IsVisible(enemysShootPos)`, **penaliza fuerte estar justo enfrente** y premia terreno alto.
Sólo se revela si el jugador **no** lo mira, está quieto y no está muy cerca — con 0,5 s de delay
para frenar de verdad.

**Detalles que valen:** si lo seguís apuntando mientras es invisible, **se clona en un señuelo**
(1483-1546). Y hackea `gmod_camera` para que **sí aparezca en la foto** aunque sea invisible —
una vez capturado, el hijack se apaga para siempre (`client.lua:278-313`).

### 6.1 `homeless_someone.lua` — el efecto puro, sin nextbot **[verificado]**

Una figura **enteramente clientside**: sin física, sin red, copia tu animación, se pega detrás tuyo o
asoma de una pared. Detecta que la mirás **midiendo la distancia en píxeles al centro de la pantalla**
dentro de su `RenderOverride`, con un cono que **se ensancha a medida que te familiarizás** y castigo
por mirar de reojo (181-222). Cuando la mirás, **huye acelerando cúbicamente** hasta salir del mapa
(431-457), sin pathfinding.

**Es el comportamiento que describiste, en su forma más barata, y no toca el nextbot para nada.**
Vale como segunda capa de PHANTOM: apariciones baratas y frecuentes que no cuestan un NextBot.

> **Trampa de nombre** [verificado]: [`overlooking.lua`](../../dev/other/phantom/dev2/him/lua/homeless_shelter/overlooking.lua)
> **no observa nada** — construye un campamento en un mirador y después lo tira abajo con fuerza
> física. El cálculo real de los miradores del mapa está en `sv_zhomeless_shelter.lua:2330-2397`.

---

## 7. La dimensión extra — ya está construida **[verificado]**

Corrijo lo que dije al empezar: busqué "dimension/realm/limbo" con grep y no encontré nada, y
concluí que era feature nueva. **Me equivoqué** — el grep pedía `SetPos` en la misma línea. HIM la
tiene entera, en `sh_zdmghealth_autorun.lua`:

| Pieza | Línea | Qué hace |
|---|---|---|
| El traslado | 663 | `Homeless_InstantScorn` → **`Vector(80000, 80000, 80000)`** |
| El decorado | 196-260 | Niebla negra a 800u, skybox tapado con quads, HUD negro |
| El borrado del mundo | 1433-1451 | `PreventTransmit` recursivo de todo lo cercano |
| El castigo | 954-968 | Pantalla espejada, controles invertidos, chat/voz/uso/colisión off |

Es el precedente literal y **se porta casi tal cual**. Los 8×10⁴ en los tres ejes es la esquina del
mapa de Source (límite 16.384u por eje en mapas normales, pero el espacio de coordenadas llega mucho
más lejos y no hay geometría ahí).

**Para el viaje:** el addon paranormal trae **68 sonidos que nunca usa**, incluido un grupo
literalmente llamado `trans1..trans9` (con variantes `lp` de loop) y `transformation_sigh_01..05`,
más ambientes en loop (`drone1lp..4lp`, `office1lp..5lp`) para que la otra dimensión **suene**. §8.

---

## 8. `[gm] paranormal events` — API global y código frágil **[verificado]**

**Un solo archivo Lua de 1.056 líneas.** Sin entidades, sin SWEPs, sin net messages, sin
concommands. **Su API es que todas sus funciones son globales sin `local`** — PHANTOM las llama
directo. Ese es el punto de entrada y no hay otro.

Lo que sirve:

```lua
CreateShadowFigure( pos )        -- única función de aparición sana que respeta el argumento (:826)
GhostInteractWithDoor()          -- abre una puerta del mapa y la cierra en 3-15s (cooldown propio)
FlingNearbyPhysicsProps( self )  -- poltergeist centrado en PHANTOM (acepta cualquier entidad)
ParticleEffectAttach( "gmpa_shadow_figure_clouds", PATTACH_POINT_FOLLOW, self, 0 )  -- aura de humo
table.Random( ghostwhispers )    -- 14 susurros, incluye voc_comehere_01, voc_followme, voc_overhere
```

Las tablas `ghostwhispers`, `creepySounds` y `poltergeistsounds` también son globales. Los 84 paths
que referencian **existen en disco** [verificado].

> **Advertencia de calidad** [verificado]: **tres de los cuatro efectos de partícula nunca corren**
> por un `IsValid(Vector)` (que siempre es falso), el sangrado de techo nunca dibuja por un typo de
> mayúscula, y la función de daño es inalcanzable. **Conviene emitir las partículas a mano** —
> el addon ya hizo `game.AddParticles` + `PrecacheParticleSystem` de las cinco, así que
> `ParticleEffect("gmpa_shadow_lurker", pos, Angle(0,0,0))` funciona y esquiva los tres bugs.

`models/gmpa/homm.mdl` es un **fast zombie recompilado** (21 secuencias propias, cero `$includemodel`):
sirve sólo remapeando `ENT.MotionTypeActivities`. No es candidato para PHANTOM.

**No hay nada parecido a una dimensión extra acá.** Lo más cercano es un `ScreenFade` rojo de 0,2 s.

---

## 9. `schizophrenia_v2` — resultado negativo **[verificado — carpeta ya borrada]**

> Se borró el 2026-08-01. Se conserva el hallazgo porque justifica el borrado y evita que alguien
> vuelva a bajarlo pensando que sirve.


`ENT.Base = "drgbase_nextbot"` (línea 2 de ambas entidades). **No contiene ninguna de las tres cosas
que fuiste a buscar:**

- **No detecta si el jugador lo mira.** Cero `EyeAngles`, cero `GetAimVector`, cero producto punto,
  cero traces hacia el jugador.
- **No tiene efecto de aparecer/desaparecer.** Cero `SetNoDraw`/`SetRenderMode`/`SetColor`/alpha.
  Su único hook de dibujado, `ENT:CustomDraw`, **está vacío** (línea 447).
- **No tiene lógica de "te observa".** La visión es puramente declarativa (`SightFOV = 190`,
  `SightRange = 15000`) y **la implementa DRGBase**, no este archivo.

Lo único portable (API de GMod pura, 1:1 a Terminator): overlay de pantalla completa a **un** jugador
vía `ply:ConCommand("pp_mat_overlay …")` con timer de limpieza, y música global no atenuada con
`CreateSound(game.GetWorld())` + `SetSoundLevel(0)`. Todo lo demás son disparadores de DRGBase
(`OnNewEnemy`, `OnChaseEnemy`, `CustomThink`) que habría que reescribir enteros.

**Recomendación: no lo uses como fuente.** v1 y v2 difieren en 11 hunks, todos cosméticos.

---

## 10. Los modelos **[verificado — censo binario]**

> **El hatman se borró el 2026-08-01.** El modelo vigente es **`models/dejtriyev/scaryblackman.mdl`**.
> La tabla se conserva entera porque el criterio (`$includemodel m_anm`) es lo que hay que aplicar a
> **cualquier** modelo futuro, y porque la trampa de los dos `.mdl` homónimos vale para todo el
> proyecto. Nota para el registro: el `playermodel/hatman.mdl` **sí** era funcional; el que no servía
> era el de `npc/`.


**El criterio no es el esqueleto.** Los ocho candidatos tienen ValveBiped. La base maneja el cuerpo
con activities `ACT_MP_*`, que son las del set de **player** de HL2MP — el propio autor lo declara en
el helptext de su convar: *"Model needs to be rigged for player movement"*
([`shared.lua:25`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/shared.lua#L25)).
**El criterio real es: ¿declara `$includemodel models/m_anm.mdl`?**

| Modelo | ¿Sirve? | `$includemodel` extraído del binario | Origen |
|---|---|---|---|
| `models/playermodel/hatman.mdl` | **SÍ, tal cual** | **`m_anm`** + `m_gst`/`m_pst`/`m_shd`/`m_ss` | `player/gman_high.mdl` |
| `models/npc/hatman.mdl` | **NO** | `combine_soldier_anims`, `male_shared`, `male_gestures`, `male_postures`, `male_ss` — **sin `m_anm`** | ídem (mismo mesh) |
| `models/dejtriyev/scaryblackman.mdl` | **SÍ, el mejor** | **`m_anm`** | `player/group01/male_04.mdl` |
| `models/terminator/…/arnold.mdl` | *(la referencia)* | **`m_anm`** | — |
| `models/gmpa/homm.mdl` | con trabajo | ninguno — fast zombie, cero `ACT_MP_*` | — |
| `schizo.mdl` / `schizo2.mdl` | NO | sin set de activities usable | — |

Los dos hatman son **el mismo mesh** (vvd/vtx/phy byte-idénticos salvo 4 bytes de checksum),
recompilado dos veces con sets de animación distintos. El de `playermodel/` tiene 70 huesos, superset
de los 56 de Arnold. `scaryblackman` coincide con Arnold en **todo** lo que mide el header (flags,
hull `(-13,-13,0)..(13,13,72)`, eyeposition, mass 90) y encima conserva 54 flexcontrollers de
`male_04`, o sea que se le puede mover la cara.

**La única pista visible entre los dos hatman es la carpeta `npc/` vs `playermodel/`** — y es
exactamente la que importa. Es el tipo de detalle que cuesta una tarde de "por qué no se mueve".

**Bodygroups de hatman** (los tiene en los dos .mdl): `SetBodygroup(0, 0)` = con sombrero,
`SetBodygroup(0, 1)` = **sin** sombrero; `SetBodygroup(1, 1)` = con maletín. Idea directa: quitarle
el sombrero cuando desaparece.

**Skins de scaryblackman:** `ENT.ModelSkin = 0` → silueta **completamente negra, sin ojos**;
`ENT.ModelSkin = 1` → **ojos blancos**. Alternable en runtime con `SetSkin`.

**La receta del look, y no necesita ningún shader:** `UnlitGeneric` sobre una VTF de **16×16 DXT1 de
color plano**. Decodificando los bloques: cuerpo = `#000000` puro, ojos = `#FFFFFF` puro.
`UnlitGeneric` ignora la iluminación, así que el cuerpo sale **más oscuro que cualquier sombra del
mapa** sin `$selfillum`. `black.vtf` (hatman) y `blackman.vtf` (scary black man) son **el mismo
archivo** (md5 `498cb7c9244d20f4e67a40ae5397ffc7`).

---

## 11. Diseño propuesto **[propuesta — SUPERADO, ver documento hermano]**

> **El diseño de esta sección quedó reencuadrado el 2026-08-01.** PHANTOM pasó a ser un fantasma de
> **Phasmophobia** con 30 tipos configurables: ver
> **[PHANTOM_Phasmophobia_Diseno.md](PHANTOM_Phasmophobia_Diseno.md)**. Nada de lo de abajo se
> descarta —la máquina de estados de acá es el estado *fuera del hunt*, y el destierro pasó a ser el
> desenlace del hunt— pero el marco correcto es el otro documento. §1-§10 y §12-§13 siguen vigentes
> tal cual: son la base, no el diseño.


Un `ENT` de ~150 líneas apoyado en lo de §5. La máquina de estados:

```
       ┌──────────────── AUSENTE (invisible, no sólido) ─────────────────┐
       │  busca navarea con vista hacia el jugador                       │
       │  filtro: posIsInterrupting(pos) == false  → nadie mira ese punto│
       └───────────────────────┬─────────────────────────────────────────┘
                               │ llega y el jugador no lo mira
                               ▼
       ┌──────────── OBSERVANDO (sólido, quieto, a 800-1500u) ───────────┐
       │  movement_watch adaptada · shootAt(ply:GetShootPos(), true)     │
       │  acumula presión con enemyBearingToMeAbs() < 9                  │
       └──────┬──────────────────────────────────┬───────────────────────┘
              │ te fuiste / dejaste de mirar     │ presión > umbral
              ▼                                  ▼
           AUSENTE                     ┌──── RETIRADA ────┐   ← el 90% de las veces
                                       │ DoHiding(true)   │
                                       │ SetMaxYawRate(0) │
                                       └──────────────────┘
                                                 │  contador global alto + muchos encuentros
                                                 ▼
                                       ┌── DESTIERRO ──┐   ← el desenlace, raro
                                       │ dimensión §7  │
                                       └───────────────┘
```

Decisiones que recomiendo:

1. **Heredar de `terminator_nextbot`** y **no** reescribir el cerebro con `DoCustomTasks`. HIM lo
   reescribió entero (5 tareas propias, ~1.500 líneas) porque necesitaba su lore. PHANTOM no:
   con `MyClassTask` agrega su tarea y deja las 33 de la base.
2. **Usar `ENT.IsWraith = true`** y no la invisibilidad de HIM. Es un campo contra 44 líneas, y el
   punto de extensión `wraithTerm_CloakDecidingTask` está hecho para esto. Costo: los cooldowns
   asimétricos de §5.3, que hay que tener en cuenta al elegir los tiempos.
3. **`OnFirstRelationWithPlayer` → `D_NU`** desde el día uno, o la base lo hace cazador.
4. **La dimensión, portada de HIM**, no reinventada — y **detrás de un contador de encuentros**, para
   que sea el final de un arco y no un evento aleatorio.
5. **Modelo: `models/dejtriyev/scaryblackman.mdl` con `ModelSkin = 1`** para el primer prototipo (es
   el más compatible), y `models/playermodel/hatman.mdl` para la versión final, que es la que tiene
   la silueta con identidad.
6. **Segunda capa barata:** el patrón de `homeless_someone` (§6.1) para apariciones clientside
   frecuentes que no cuestan un NextBot.

**Lo que hay que escribir de cero:** la máquina de estados de arriba, el contador de encuentros, y
el ritual de destierro. Todo lo demás es configurar y portar.

---

## 12. Defectos de terceros a esquivar **[verificado]**

| # | Dónde | Qué |
|---|---|---|
| D-1 | `terminator_events.lua:110-173` | **`onStartFunc` nunca se ejecuta.** Fatal si registrás un evento de tercero contando con él |
| D-2 | `wraithcloaking.lua:163-201` | 0,25 s en que el bot se declara visible pero sigue atravesable |
| D-3 | `taskoverride.lua:117-132` | `KillAllTasksWith` hace `table.remove` sobre el array que `ipairs` está recorriendo — saltea elementos |
| D-4 | `terminator_alerter.lua:224-258` | Reemplaza **cuatro funciones globales del engine** de forma permanente |
| D-5 | `gm_paranormalactivities.lua` | 3 de 4 efectos de partícula muertos por `IsValid(Vector)`; sangrado de techo muerto por un typo |
| D-6 | `him/…/shared.lua:34` | El `NetworkVar Bool 0` que pisa `Crouching` (§4.3③) — **no lo copies** |
| D-7 | `sv_zhomeless_shelter.lua:238` | Bug de nombre de timer en la entidad que se autoborra tras N miradas |

Y dos comentarios del código que **mienten** y que costaron refutaciones: el de `Term_FOV`
(`shared.lua:152`) y el de `ThreshMulIfClose` (`shared.lua:91`, dice `* 2`, el código hace `* 3` con
piso 1500 — repetido en `csoldier.lua:101` y `fakeply.lua:40`).

---

## 13. Huecos declarados

- **Nada de esto se corrió en juego.** Todo es lectura de código, por exhaustiva que haya sido.
- **No se verificó que los seis addons monten sin colisión de rutas** entre sí. `him` y
  `terminator nextbot` conviven por diseño; los otros cuatro no se contrastaron. Dada la historia del
  proyecto con `autorun/server/cvars.lua`, conviene mirarlo antes de montar todo junto.
- **El `.pcf` de partículas no se extrajo**: los cinco nombres `gmpa_*` salen del Lua que los
  precachea, no del binario.
- **`ENT.MotionTypeActivities` no se mapeó** para `homm.mdl`; se sabe que hace falta, no cuánto.
- **El costo en CPU de la base no se midió.** `ENT.CoroutineThresh` es la palanca
  (`behaviouroverrides.lua:495-555`) y el addon corre en coroutines presupuestadas, pero cuántos
  PHANTOM aguanta un servidor es una pregunta abierta.
- **La dimensión extra de HIM se leyó, no se ejerció.** El `PreventTransmit` recursivo y el
  `Vector(80000,80000,80000)` son lo que dice el código; qué pasa con otros addons corriendo al mismo
  tiempo (mapas grandes, addons que iteran entidades) no se probó.
