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

### 1.2 Las masas del Prop Pack son inutilizables

| Pack | Masas |
|---|---|
| Equipment Props (`phas/`) | **0,1 – 7,2 kg** — realistas |
| Prop Pack (`demit/`) | **100 o 1000 kg**, sin excepción |

Un crucifijo de una tonelada no se puede levantar ni empujar: el physgun lo mueve, la mano no. Si se
usa un modelo del Prop Pack hay que pisar la masa en Lua:

```lua
local phys = ent:GetPhysicsObject()
if IsValid( phys ) then phys:SetMass( 0.6 ) end
```

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

## 4. Pendiente: el peso de las texturas

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
