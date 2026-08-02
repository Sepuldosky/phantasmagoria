# Equipamiento — inventario verificado y mapeo a mecánicas

**Fecha:** 2026-08-02
**Método:** los 36 `.mdl` parseados **desde el binario** (`studiohdr_t`), no desde la descripción del
Workshop. Bodygroups, familias de skin, texturas, `cdmaterials`, masa y `surfaceprop` salen del
header. Cada textura declarada se cruzó contra el `.vmt` en disco, y cada `$basetexture` contra
su `.vtf`. **Créditos:** [CREDITOS.md](CREDITOS.md).

**Estado del árbol:** 36 modelos, 63 `.vmt`, 58 `.vtf`. **62 referencias resueltas, 0 faltantes,
0 acompañantes (`.vvd`/`.vtx`) faltantes.** Los tres packs usan namespaces distintos
(`kiwontatv/`, `phas/`, `phasmophobia/demit/`) — **0 colisiones de ruta entre ellos**, así que
conviven sin pisarse.

---

## 1. Los tres hallazgos que corrigen lo que dice el Workshop

### 1.1 El K2 no tiene bodygroups: tiene **6 skins**, y son perfectos

La descripción habla de bodygroups para 5 niveles. El binario dice `bodyparts=1, nmodels=1` —
**cero bodygroups reales** — y `numskinfamilies=6`. Las once texturas son `reader`, `level_01..05`
y `level_01..05_active`, y la tabla de skins las intercambia de forma **acumulativa**:

| Skin | LEDs encendidos | Qué cambia respecto del anterior |
|---:|---:|---|
| 0 | ninguno | — |
| 1 | 1 | `level_01` → `level_01_active` |
| 2 | 2 | + `level_02_active` |
| 3 | 3 | + `level_03_active` |
| 4 | 4 | + `level_04_active` |
| 5 | **5** | + `level_05_active` |

**Son 6 estados, no 5** (el 0 es "apagado"), y el mapeo con la evidencia es literal:

```lua
ent:SetSkin( emfLevel )   -- emfLevel 0..5 — y EMF 5 es la evidencia
```

Mejor de lo prometido: un bodygroup exigiría combinar máscaras; el skin es un entero directo.

> **Y no es "un EMF genérico": es el Tier 2 del juego.** La fuente describe los tres tiers del EMF
> Reader así — Tier 1: una aguja; **Tier 2: 5 LEDs de colores, la cantidad encendida es el nivel**;
> Tier 3: pantalla LCD con nivel, dirección y distancia. El K2 es exactamente la descripción del
> Tier 2. Ver §16 del diseño.

### 1.2 Las masas del Prop Pack son inutilizables — **corregido en Lua**

La masa vive en el `.phy`, en un bloque KeyValues de **texto plano** al final del archivo. Leyéndolo
se ve de dónde sale la diferencia:

| Modelo | `mass` | `volume` | **`totalmass`** | `surfaceprop` |
|---|---:|---:|---:|---|
| `phas/eqp_crucifix` | 1.0 | 79,8 | **0,61 kg** | `item` |
| `demit/crucifix` | **1000.0** | 98,0 | **1000 kg** | `metal` |
| `phas/eqp_lighter` | 1.0 | 0,77 | **0,025 kg** | `eqp_lighter` |

El Equipment Pack deja `mass 1.0` y **le deja el cálculo a Source** (volumen × densidad del
surfaceprop); el Prop Pack clava el número a mano. El mismo crucifijo pesa 0,6 kg en un pack y una
tonelada en el otro — y con una tonelada sólo lo movés con physgun, nunca con la mano.

> **Corrección (2026-08-02).** Este párrafo decía que el Prop Pack clavó `1000` en **todos** sus
> props. Es falso, y lo desmiente la misma fuente que el párrafo cita. Leídos los **13** `.phy`:
>
> | `mass` | Cuántos | Cuáles |
> |---:|---:|---|
> | **1000** | 6 | `camera_open`, `crucifix`, `cursed_book`, `cursed_book_open`, `emf`, `uv_torch` |
> | **100** | 7 | `flashlight`, `motion_sensor`, `salt`, `salt_b`, `salt_step`, `spiritbox`, `ther_m` |
>
> **No cambia nada de lo que sigue:** 100 kg para una linterna es igual de inusable que 1000 para un
> crucifijo, y la vía sigue siendo `SetMass()` en runtime. Lo que cambia es el hábito — la frase
> generalizó a 13 desde los 3 casos de la tabla de arriba, y ninguno de los diez restantes se había
> abierto. **La tabla de `prop_data.lua` nunca dependió de esto** (fija una masa objetivo por modelo,
> no una corrección uniforme), así que el código estaba bien mientras la prosa estaba mal. Los 13
> declaran además `surfaceprop metal`, lo que confirma por qué la sal sonaba a chapa.

**Se arregla en runtime, sin tocar los assets.** Tres vías posibles y sólo una conviene:

| Vía | Veredicto |
|---|---|
| `PhysObj:SetMass()` en Lua | **La elegida.** Reversible, no modifica el asset del tercero |
| Parchear el `.phy` | Posible (el bloque es texto plano) pero altera lo que el autor publicó |
| Descompilar y recompilar | Innecesario |

La tabla vive en [`lua/phantasmagoria/prop_data.lua`](../lua/phantasmagoria/prop_data.lua), junto con
`PHANTASMAGORIA.ApplyPropData( ent )`, que se llama desde el `Initialize` de cada prop. Hay además
un hook `PlayerSpawnedProp` de red de seguridad: si alguien saca el crucifijo del Prop Pack **desde
el menú Q**, igual le baja la tonelada.

> **El `surfaceprop` también se corrige,** con `PhysObj:SetMaterial()` — decide fricción, elasticidad
> y a qué suena el objeto al golpear. El crucifijo del Prop Pack venía como `metal` y sonaba a chapa.
>
> **Ojo con inventar surfaceprops:** `book` **no existe** en Source. Verificado contra
> `sourceengine/scripts/surfaceproperties.txt` de la instalación: existen `item`, `paper`,
> `cardboard`, `sand`, `metal`, `plastic`; `book` no. Un surfaceprop inexistente no da error — cae a
> `default` en silencio, que es la peor forma de equivocarse. Los libros quedaron en `paper`.
>
> Nota aparte: `eqp_lighter` declara el surfaceprop **`eqp_lighter`**, que tampoco existe en el
> juego base. El pack no trae `scripts/surfaceproperties_*.txt`, así que también cae a `default`.

### 1.3 El libro abierto tiene 7 skins en un pack y **8** en el otro

- `phas/eqp_ghost_book_open.mdl` → **7** familias (`ghost_book_0..6`). Coincide con lo esperado.
- `demit/cursed_book_open.mdl` → **8**. La octava es `book_cursed_demit`: la firma del autor, un
  easter egg. Si se usa este modelo, el sorteo debe ser `math.random(0, 6)` y no `0..7`, o
  eventualmente sale la firma como si fuera escritura del fantasma.

---

## 2. Inventario completo

### 2.1 `phas/` — Equipment Props Pack (22)

| Modelo | Skins | Masa | Uso previsto |
|---|---:|---:|---|
| `eqp_emf_reader` | 1 | 0,5 | EMF alternativo (sin niveles — preferir el K2) |
| `eqp_spirit_box` | 1 | 0,6 | Evidencia Spirit Box |
| `eqp_thermometer` | 1 | 0,8 | Evidencia Freezing |
| `eqp_ghost_book` | 1 | 3,4 | Libro cerrado |
| `eqp_ghost_book_open` | **7** | 7,2 | **Evidencia Ghost Writing** — §3.2 |
| `eqp_dots_projector` | 1 | 0,8 | Evidencia D.O.T.S — §3.3 |
| `eqp_flashlight_uv` | 1 | 0,3 | Evidencia Ultraviolet |
| `eqp_salt_tube` | 1 | 0,6 | Sal (el tubo; los montones están en el otro pack) |
| `eqp_crucifix` | 1 | 0,6 | **Impide un hunt** |
| `eqp_smudge_sticks` | 1 | 0,5 | Apacigua — se prende con el encendedor |
| `eqp_candle` | 1 | 1,7 | Frena la pérdida de cordura |
| `eqp_lighter` | 1 | 0,0 | Prende velas e incienso. **Masa 0: hay que pisarla** |
| `eqp_sanity_pills` | 1 | 0,1 | Restaura cordura |
| `eqp_flashlight` | 1 | 0,9 | Luz |
| `eqp_flashlight_strong` | 1 | 0,6 | Luz fuerte. **Le faltaba un VMT** — ver CREDITOS |
| `eqp_glowstick` | **2** | 0,3 | Luz. Skin 0 apagada / **skin 1 encendida** (`glowstick_emission`) |
| `eqp_digital_camera` | 1 | 0,6 | Foto |
| `eqp_video_camera` | 1 | 3,4 | Cámara RT |
| `eqp_head_mounted_camera` | 1 | 7,2 | Cámara RT en la cabeza |
| `eqp_tripod` | 1 | 5,5 | **El único con bodygroup real** — §3.4 |
| `evt_bone` | 1 | 0,5 | Hueso: fotografiar y recoger |
| `evt_voodoo_doll` | 1 | 0,7 | **Ítem maldito**: tocarla repetido fuerza un hunt |

### 2.2 `demit/` — Prop Pack (13)

**Solapa con el anterior en 9 props.** Lo que aporta de exclusivo:

| Modelo | Por qué importa |
|---|---|
| `motion_sensor` | **No existe en el otro pack** |
| `salt` / `salt_b` | Montones de sal — el otro sólo trae el tubo |
| `salt_step` | **La pisada en la sal**: la evidencia de que el fantasma pasó |

Los otros diez (`crucifix`, `emf`, `spiritbox`, `ther_m`, `uv_torch`, `flashlight`, `camera_open`,
`cursed_book`, `cursed_book_open`) son alternativas a los de `phas/`. **Recomiendo `phas/` por
defecto** (masas realistas) y quedarse de éste sólo con los cuatro de arriba.

### 2.3 `kiwontatv/` — K2 (1)

`emf_reader_k2` — 6 skins, masa 4,1. **El EMF principal**, por §1.1.

---

## 3. Cómo se implementa cada mecánica

### 3.1 EMF Reader
`SetSkin(0..5)` según el nivel. El nivel sale de la distancia al fantasma y de si el tipo tiene
`emf5` entre sus evidencias: sin esa evidencia el aparato **nunca** llega a 5, que es justamente lo
que el jugador está midiendo.

### 3.2 Ghost Writing — el efecto que describiste
El libro cerrado en el suelo; cuando el fantasma escribe:

1. `eqp_ghost_book` se levanta unas unidades.
2. Se agita en yaw, izquierda-derecha, un momento corto.
3. Cae al mismo punto y se reemplaza por `eqp_ghost_book_open` con `SetSkin(math.random(0,6))`.

El paso 3 es un swap de entidad, no un cambio de modelo, porque las masas y los físicos difieren
(3,4 vs 7,2 kg).

### 3.3 D.O.T.S Projector
Una luz de GMod (`ProjectedTexture`) con una textura de puntos como `SetTexture`. El fantasma se
vuelve visible como silueta **sólo cuando cruza ese cono** y sólo si tiene `dots` entre sus
evidencias. Con `$translucent` sobre la silueta se consigue el look sin escribir un shader.

### 3.4 Trípode
Único con bodygroup: bodypart `closed`, 2 submodelos.

```lua
ent:SetBodygroup( 0, 0 )   -- eqp_tripod.smd         -> abierto
ent:SetBodygroup( 0, 1 )   -- eqp_tripod_closed.smd  -> cerrado
```

> El bodypart **se llama** `closed` pero su submodelo 0 es el abierto. El nombre engaña; el binario
> manda.

### 3.5 Cordura — la barra
Es del **jugador**, no del fantasma. Baja con la oscuridad, las manifestaciones y la cercanía; sube
con `eqp_sanity_pills` y con luz. La vela la frena.

**Sobre integrarla con Cargo:** Phantasmagoria está **fuera de Corpus** y no puede depender de él.
La forma correcta es detección en runtime, sin asumir nada:

```lua
if Corpus and Corpus.GetModule and Corpus.GetModule( "cargo" ) then
    -- registrar la cordura como barra medible de Cargo
end
```

Y **siempre** un camino propio cuando Cargo no está: un HUD mínimo, o la pantalla interactiva que
mencionaste (una TV con RT que muestre cordura, cámaras y sonidos). Sin Cargo el addon no puede
quedarse sin forma de leer la cordura.

---

## 4. Las posesiones malditas: son **7**, y tenemos **1**

**[verificado]** contra el backend del cheat sheet (`wiki.json`, mismo origen que la tabla de tipos),
no de memoria.

| Posesión | Qué hace | Cordura | Modelo |
|---|---|---:|---|
| **Voodoo Doll** | Cada alfiler fuerza una interacción del fantasma. El del **corazón** dispara un *cursed hunt* — igual que si la usás con 0 % de cordura | 5 % por alfiler, **10 %** el del corazón | ✅ `phas/evt_voodoo_doll` |
| **Summoning Circle** | Encender las **5 velas rojas** con un encendedor. Al prender la quinta: evento, el fantasma se teletransporta al círculo, espera **5 s** y arranca un cursed hunt | **16 % por vela**, 80 % total | ⚠️ **armable** — ver abajo |
| **Ouija Board** | Preguntás y responde deletreando con la güija. Da el cuarto **actual**, no el favorito. Hay que despedirse para cerrar la sesión | **50 %** | ❌ |
| **Haunted Mirror** | Muestra el **cuarto favorito**. Se rompe si el usuario se queda sin cordura, y al romperse arranca un cursed hunt | 7,5 %/s, mínimo 20 % | ❌ |
| **Music Box** | A **20 m** el fantasma canta y delata su posición **sin hacerse visible**; a **5 m** se materializa y camina hacia la caja | 2,6 %/s a menos de 3 m | ❌ |
| **Monkey Paw** | Deseos: cada uno da información o actividad forzada, y cobra. Un dedo se dobla por deseo concedido | variable | ❌ |
| **Tarot Cards** | Mazo de **10 cartas** al azar; cada carta un efecto (ej. duplicar la actividad 20 s, 20 % de probabilidad) | variable | ❌ |

### 4.1 El Summoning Circle se puede hacer **hoy**

No hace falta un modelo de «círculo»: hace falta **5 velas rojas y un encendedor**, y los dos están
en disco (`phas/eqp_candle`, `phas/eqp_lighter`). El círculo es un **decal** en el piso.

Es además el que mejor encaja con lo que ya está diseñado: usa el sistema de cuartos (§14 del diseño)
para elegir dónde aparece, usa el encendedor que ya tiene modelo, y su desenlace —teleport del
fantasma + hunt— es exactamente lo que la base Terminator hace bien.

### 4.2 Las otras cinco

Sin modelo propio. Opciones, de menos a más trabajo: un prop plano con textura custom (sirve para
Ouija y Tarot, que son objetos planos), buscar ports sueltos en el Workshop, o dejarlas fuera de la
primera versión. **La Music Box es la que más valor daría** por su mecánica: delatar la posición del
fantasma sin mostrarlo es justo el tipo de tensión que el resto del addon busca.

> **Nota de la fuente:** aparecieron dos grupos con ~78 entradas cada uno, `ferryman` y
> `ghost_machine`, que no corresponden a ninguna de las 7 ni a ningún tipo de fantasma. Son contenido
> más nuevo que no conozco y **no está investigado**. Si el juego sumó mecánicas grandes, están ahí.

---

## 5. Cómo se sostiene el equipo: **SWEP, entidad o ítem**

### 5.1 La medición que decide la forma **[medido 2026-08-02]**

`python dev/mdlinfo.py models/` sobre los 36:

```
los 36 modelos:  numbones = 1,  numseq = 1
```

Un hueso y una secuencia, sin excepción. Eso cierra dos preguntas antes de discutirlas:

1. **Manos: imposible.** `SWEP.UseHands` necesita un viewmodel con el rig de brazos (`ValveBiped`).
   Un hueso solo no lo tiene. **El equipo flotando frente a la cámara no es una elección estética:
   es la única opción sin descompilar y recompilar.**
2. **Animación: no hay.** Una sola secuencia es la pose de referencia. No hay draw, ni idle, ni
   guardado. **Todo el movimiento tiene que ser código** — bob, sway por velocidad, un lerp al
   sacarlo. El abierto/cerrado del trípode es un bodygroup, no una animación (§3.4).

### 5.2 El reparto

No todo el equipo es la misma cosa, y meterlo todo en SWEPs sería tan malo como no usar ninguno:

| Tipo | Forma | Por qué |
|---|---|---|
| Se sostiene y se lee — EMF/K2, spirit box, termómetro, UV, cámara de fotos | **SWEP** | Es lo único que da mano, viewmodel y hotbar; y es lo que Cargo equipa vía `def.weapon_class` (§6) |
| Se planta y queda — trípode, DOTS, sensor de movimiento, cámara de video | **Entidad** | El SWEP es el *deployer*: el ataque primario spawnea la entidad y la saca del inventario |
| Se consume — pastillas, sal, incienso, encendedor | **Ítem con `onUse`** | Son los quick slots F1-F4 de Cargo, que **exigen** `onUse`: sin él el slot los rechaza |
| Escenografía — libro, crucifijo, vela, muñeca vudú | **Entidad** | Nunca están en la mano: el fantasma interactúa con ellos en el piso (§3.2, §4) |

### 5.3 El viewmodel flotante — dos caminos, y uno está verificado y el otro no

**Camino corto — el prop *es* el viewmodel.** Se reposiciona con `CalcViewModelView`:

```lua
SWEP.ViewModel     = "models/kiwontatv/ghost_busters/emf_reader_k2.mdl"
SWEP.WorldModel    = "models/kiwontatv/ghost_busters/emf_reader_k2.mdl"
SWEP.UseHands      = false   -- 1 hueso: no hay dónde enganchar las manos
SWEP.ViewModelFOV  = 60      -- el prop no fue autorado para el FOV 90 de un viewmodel

function SWEP:CalcViewModelView( vm, oldPos, oldAng, pos, ang )
    local bob = math.sin( CurTime() * 2 ) * 0.3
    return pos + ang:Forward() * 12 + ang:Right() * 6 + ang:Up() * ( -5 + bob ), ang
end

-- el nivel del K2 en la mano: el skin, desde una var networked del propio SWEP
function SWEP:PreDrawViewModel( vm )
    vm:SetSkin( self:GetEMFLevel() )
end
```

> **[sin verificar]** Que un prop de **1 hueso y 1 secuencia** funcione como `SWEP.ViewModel` es lo
> que sé del engine, **no algo contrastado contra código de este workspace**. Busqué precedente: los
> SWEPs de `dev/other/` usan **todos** viewmodels dedicados `v_`/`c_`, ninguno un prop pelado. Es
> barato de medir en la primera pasada — si no renderiza o aparece en un lugar absurdo, se ve al
> instante. **El engine es un tercero:** vale la misma desconfianza que ARC9.

**Camino largo — dibujarlo a mano. [verificado]** Tiene precedente leído en este workspace: el NVG de
Neosun (`dev/other/[vmanip] neosun's cooler nightvision/lua/autorun/cl_arctic_nvg.lua:73` y `:255`)
dibuja props exactamente así — `ClientsideModel` → `SetNoDraw(true)` → `SetPos`/`SetAngles`/
`DrawModel()` dentro de un hook de render, anclado a un attachment. Anclarlo a `EyePos()`/
`EyeAngles()` en vez de al hueso de la cabeza da el objeto flotante con control total.

**Su costo, que es conocido y no chico:** se dibuja en la pasada del mundo, así que usa el FOV del
mundo y **atraviesa paredes**. Los viewmodels no lo hacen porque el engine los dibuja en un rango de
profundidad aparte.

**Orden recomendado:** el corto primero. Si en juego el prop-como-viewmodel se porta mal, el largo
está probado y el trabajo de posicionamiento se recicla entero.

---

## 6. Integración con **Cargo** — soft-dep, y hay más superficie de la que parece

Cargo es el módulo de inventario del ecosistema Corpus
([`github.com/Sepuldosky/corpus-cargo`](https://github.com/Sepuldosky/corpus-cargo); en el workspace,
`../../corpus-cargo/`). Phantasmagoria está **fuera** de Corpus y no puede hard-depender de él: vale
lo mismo que §3.5 — detección en runtime y **siempre** un camino propio.

### 6.1 El hallazgo que decide todo: **si el equipo es SWEP, Cargo se lo come solo** [verificado]

`../../corpus-cargo/lua/corpus_cargo/server/corpus_cargo_capture.lua` captura **toda** arma que el
engine le entregue al jugador y le fabrica un def `autogen`. Sin registrar nada, nuestros SWEPs
entrarían al inventario con el **peso de fallback (2,5 kg)**, categoría `weapons` y **sin precio**.
Con defs propios entran con la masa real que ya está medida del `.phy`.

**No es opcional decidirlo:** con Cargo montado pasa igual. La elección es entre hacerlo bien o que
salga mal solo. (La vía de escape existe y es `CARGO.Capture.Ignore`, para lo que no deba ser ítem.)

### 6.2 Lo que se gana registrando defs

`Cargo.Items.Register{ id, name, weight, class, category, ... }`:

| Se gana | Detalle |
|---|---|
| **Íconos gratis** | El pipeline renderiza el modelo a PNG y lo cachea. Los 36 props tienen ícono sin dibujar nada |
| **Peso → velocidad** | La curva cobra los 7,2 kg del libro abierto y los 5,5 del trípode. Cargar el kit completo *debe* costar, y acá sale gratis |
| **Drop, contenedores, comercio** | `def.value` los hace comerciables; sin `value` no se venden (ausencia = "no está a la venta", no "gratis") |
| **Consumibles** | `def.onUse` para pastillas/sal/incienso. **Se registra en los dos realms** (COR-12): la UI habilita el botón mirando `isfunction(def.onUse)` del lado cliente |

### 6.3 Tres registros vivos que encajan casi literalmente [verificado]

| API de Cargo | Uso acá |
|---|---|
| `Wheel.RegisterLightSource( id, spec )` | Linterna, linterna fuerte, UV y glowstick como **grupo de luces del wheel radial**. Es exactamente para lo que se diseñó |
| `StatusPanel.RegisterBar( module, spec )` | La **cordura** de §3.5 como barra: `{ id, label, getValue = function(ply) → 0..100, color }` |
| `Capture.RegisterWorldPickup( class, spec )` | Props tirados en el mapa que se recogen con WALK+USE y entran al grid |

### 6.4 El límite honesto: **Cargo no tiene API para registrar slots** [verificado]

`corpus_cargo_slots.lua` es data, y la columna de equipamiento está maquetada a mano en la UI. Los
slots de arma filtran por `category:weapons`, así que **para que un equipo entre en un slot de arma
su categoría tiene que ser `weapons`**. Dos salidas:

- **Hoy, sin tocar Cargo:** categoría `weapons` + `def.equip_slots = { "primary", "secondary",
  "sidearm" }`. Da las **teclas 1-4 estilo STALKER, el wheel radial y el enfundado** gratis, y un
  hotbar de 3-4 equipos que es *justo* el de Phasmophobia. Cuesta aparecer bajo la pestaña Weapons,
  mezclados con las armas si hay ARC9.
- **A mediano plazo:** pedirle a Cargo un `Slots.Register` para una fila de *gear*. Eso es trabajo de
  Cargo, no de este addon. **No apendear a `Slots.List` por la ventana:** el slot no se renderiza en
  la columna y quedaría medio implementado.

### 6.5 La forma del enganche

```lua
-- ni una llamada a Corpus en file-scope: el orden de carga entre addons no se asume
hook.Add( "Initialize", "phantasmagoria_cargo", function()
    if not ( Corpus and Corpus.GetModule and Corpus.GetModule( "cargo" ) ) then
        PHANTASMAGORIA.OwnInventory()   -- el camino propio, que tiene que existir igual
        return
    end
    PHANTASMAGORIA.RegisterCargoItems()
end )
```

Y la regla que no se negocia: **sin Cargo el addon no puede quedarse sin forma de sostener el equipo
ni de leer la cordura.** Degradar, nunca romper — la misma de §14.5 del diseño.

---

## 7. Pendiente: el peso de las texturas

**251 MB en 58 `.vtf`.** Todas son **2048×2048 DXT5** (5,3 MB cada una) — incluidas las de un
encendedor y unas pastillas, que en pantalla ocupan cuarenta píxeles.

| Resolución | Tamaño estimado |
|---|---:|
| 2048² (actual) | 251 MB |
| 1024² | ~63 MB |
| 512² | ~16 MB |

Bajar a 1024² sería invisible en juego para casi todo y ahorra ~190 MB de descarga por cliente.
**No lo hice: es modificar el asset de un tercero y cambia lo que ellos publicaron.** Queda como
recomendación, y es tu decisión.

---

## 8. La evidencia **Ultraviolet**: huellas que sólo existen bajo la luz

### 8.1 El tamaño de la pregunta **[medido sobre `ghost_types.lua`]**

`uv` es una de las 7 evidencias y la tienen **13 de los 30 tipos** — empatada con `writing` y `emf5`
como la segunda más frecuente. **Sin UV, 13 tipos quedan sin identificar.** No es adorno.

### 8.2 Los decals ya existen, y están huérfanos **[hallazgo, 2026-08-02]**

`[gm] paranormal events` trae en `materials/effects/gmpa/decals/`:

```
hand_l1.vmt + .vtf     hand_r1.vmt + .vtf
hand_l2.vmt + .vtf     hand_r2.vmt + .vtf
```

**Su Lua no las usa jamás.** En 1056 líneas la palabra «decal» aparece **una sola vez**, en un
comentario (línea 948: `-- Visualize favorite room with mist and decals`). Ni un `game.AddDecal`, ni
un `util.Decal`. Los assets están completos, en el formato correcto, y sin cablear.

> **Corrección de la primera versión de esta sección (mismo día).** La escribí diciendo «cuatro
> huellas de mano, izquierda y derecha, dos variantes» y que **60 s de fade son exactamente la
> duración de las huellas en Phasmophobia, así que el autor las hizo para esto**. Las dos cosas eran
> inferencias del **nombre de archivo** y de un número que coincidía. **Se miraron, y las refutan:**
>
> | Archivo | Qué es realmente |
> |---|---|
> | `hand_l1` | Palma completa, mano izquierda — **rojo oscuro sobre blanco** |
> | `hand_r1` | Palma completa, mano derecha |
> | `hand_l2` / `hand_r2` | **No son huellas: son arrastres** de cuatro dedos raspando |
>
> **Son decals de SANGRE**, no de UV: el shader `DecalModulate` multiplica el fondo para dejar una
> mancha, y `$decalfadeduration 60` es un valor corriente de decal de gore. Los cuatro `.vtf` sí
> tienen hash distinto (contrastados), así que son cuatro texturas reales y no una repetida.
>
> **La forma sirve igual** — ver §8.6 — pero hay que **derivarla**, no copiarla. Y la lección es la
> de siempre, en su versión visual: **el nombre de un archivo miente igual que un comentario, y acá
> sí había forma de refutarlo mirando.** Dos de los cuatro «hand_*» no son manos.

### 8.3 ¿Sirve un `.png`? Depende del camino — y hay dos

**Como decal: NO. [verificado]** Un decal de Source necesita **`.vmt` con `$decal 1` + `.vtf`**. Lo
confirma el workspace: ARC9MW registra `game.AddDecal("molotovscorch", "decals/molotovscorch")` y al
lado están el `.vmt` (con `"$decal" 1`) y el `.vtf`. **Un PNG no puede ser un decal.**

**Como material dibujado a mano: SÍ. [verificado]** Cargo lo hace en producción
(`corpus_cargo_lights.lua:112`): `Material("corpus_cargo/wheel/flashlight.png", "smooth mips")`,
con un `file.Exists` como gate. La regla que sale de ahí y vale para todo el addon:

> **Un PNG sirve donde se acepta un `IMaterial`; falla donde se pide un texture ID o un parámetro de
> shader.** (Cargo pagó el segundo caso: `WepSelectIcon` no admite PNG.)

### 8.4 Pero el decal es la herramienta equivocada, aunque salga gratis

**Un decal se ve siempre y para todos.** La mecánica pide lo contrario: la huella tiene que ser
**invisible hasta que le apuntás con la UV**. Pegarlas como decal hace que el jugador las vea sin la
linterna, y entonces la evidencia deja de ser evidencia — **peor que no tenerla**, porque convierte
la linterna UV en un adorno.

`util.DecalEx` es client-side y parece la salida (pegar sólo en el cliente que tiene la UV prendida).
**Su trampa:** no hay forma de borrar un decal individual. Al apagar la UV quedan pegadas hasta un
`RemoveAllDecals`, que además borra la sangre y todo lo demás de esa superficie.

### 8.5 La forma que sí da la mecánica

El servidor guarda la huella como **dato**; el cliente la dibuja **sólo bajo la puerta**:

```lua
-- SERVER: al interactuar, guardar el punto. No se pinta nada.
prints[#prints+1] = { pos = tr.HitPos, normal = tr.HitNormal, hand = math.random(1,4),
                      expire = CurTime() + 60 }

-- CLIENT: existe únicamente mientras la UV apunta. Las cuatro texturas son
-- MÁSCARAS BLANCAS (§8.6): el color entero lo pone SetDrawColor.
local MAT = Material("phantasmagoria/uv/hand_left.png", "smooth")
hook.Add("PostDrawTranslucentRenderables", "phantasmagoria_uv", function()
    if not PHANTASMAGORIA.HoldingUV() then return end        -- la puerta ES la mecánica
    for _, p in ipairs(PHANTASMAGORIA.Prints) do
        local ang = p.normal:Angle(); ang:RotateAroundAxis(ang:Right(), -90)
        cam.Start3D2D(p.pos + p.normal * 0.2, ang, 0.1)
            surface.SetMaterial(MAT); surface.SetDrawColor(180, 220, 255, 200)
            surface.DrawTexturedRect(-64, -64, 128, 128)
        cam.End3D2D()
    end
end)
```

Tres cosas que esto compra y el decal no: **el color** (teñir un PNG blanco con `SetDrawColor`, sin
una textura por color), **el fade** (alfa desde `expire - CurTime()`, sin depender de
`$decalfadeduration`), y **la puerta**, que es toda la mecánica.

**La huella de sal viaja en la misma puerta.** `demit/salt_step.mdl` es un **modelo**, no un decal:
se spawnea con `SetNoDraw(true)` y se dibuja client-side con la misma condición. Un solo gate para
las dos evidencias UV, y ningún mecanismo nuevo.

### 8.6 Lo que falta decidir

Los cuatro decals de gmpa dan la escala (`$decalscale .35`), el fade (60 s) y la forma, pero **son de
sangre**: copiarlos tal cual daría manos rojas. Queda una sola pregunta abierta: **arte propio, o
derivar de esos `.vtf` una máscara teñible**. Son assets de un tercero, y este repo no los versiona
— decisión del autor.
