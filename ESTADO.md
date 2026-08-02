# Phantasmagoria — Estado actual y handoff

**Última actualización:** 2026-08-01
**Changelog:** ver [CHANGELOG.md](CHANGELOG.md)
**Diseño vigente:** [docs/PHANTOM_Phasmophobia_Diseno.md](docs/PHANTOM_Phasmophobia_Diseno.md)
**Investigación de la base:** [docs/PHANTOM_Referencia.md](docs/PHANTOM_Referencia.md)

Documento de traspaso: pensado para retomar el trabajo sin contexto previo.

---

## Dónde está parado esto

**En diseño cerrado, sin una sola línea de entidad escrita.** Hay investigación exhaustiva de la
base, un diseño completo, y la tabla de los 30 tipos generada desde datos reales del juego.
**No hay nada corrido en GMod todavía** — ni una vez.

Lo que existe:

| Pieza | Estado |
|---|---|
| Investigación de la base Terminator | **CERRADA** — 55k líneas leídas, 1.042 APIs auditadas |
| Diseño del motor de rasgos | **CERRADO** — [docs/](docs/PHANTOM_Phasmophobia_Diseno.md) |
| Tabla de los 30 tipos | **GENERADA** — `lua/phantasmagoria/ghost_types.lua`, valida sintaxis |
| Conversión de audio | **HECHA** — 265 archivos, 141 MB → 11 MB |
| Entidad `terminator_nextbot_phantom` | **NO EXISTE** ← el próximo paso |
| Equipos (EMF, spirit box, etc.) | **NO EXISTEN** — props a descargar |
| Nada de esto en juego | **0 corridas** |

---

## El próximo paso concreto

**Escribir la entidad mínima y verla spawnear.** No la máquina de estados entera: el esqueleto de
§4.1 del diseño, con el modelo correcto y `IsWraith`, y confirmarlo en juego. Hasta que eso no
aparezca en el spawnmenu y camine, todo lo demás es papel.

```lua
-- lua/entities/terminator_nextbot_phantom/init.lua  (aun no escrito)
AddCSLuaFile()
ENT.Base = "terminator_nextbot"          -- NO "terminator_nextbot_base"
DEFINE_BASECLASS( ENT.Base )
ENT.PrintName = "Phantasmagoria Ghost"
ENT.Spawnable = true
terminator_Extras.RegisterNPC( "terminator_nextbot_phantom", ENT )

if CLIENT then return end

ENT.Models   = { "models/dejtriyev/scaryblackman.mdl" }  -- Models, NO Model
ENT.ModelSkin = 1
ENT.IsWraith = true
ENT.DefaultWeapon = false
ENT.TERM_FISTS    = false
```

Las cuatro trampas que ya sabemos y que hay que respetar desde la primera línea están en §4.3 de la
referencia. Resumidas:

1. **`ENT.Models`, no `ENT.Model`** — si no, spawnea con Arnold.
2. **`Term_FOV` necesita `AutoUpdateFOV = false`** o la convar global lo pisa en caliente.
3. **No usar `SetupDataTables` con `Bool 0`** — la base ya usa ese slot para `Crouching`.
4. **El interruptor fantasma/cazador es `OnFirstRelationWithPlayer`**, no `DisableBehaviour`.

---

## Decisiones tomadas

| Tema | Decisión | Cuándo |
|---|---|---|
| Base | `terminator_nextbot` (no DRGBase, no VJ) | 2026-08-01 |
| Velocidad | Relativa a la carrera real del jugador, vía Better Movement | 2026-08-01 |
| Desenlace del hunt | Por tipo: `kill` o `banish` | 2026-08-01 |
| Vuelta del destierro | Muriendo (rápido) **o** por ritual (el camino divertido) | 2026-08-01 |
| Audio | `.ogg`, originales intactos aparte | 2026-08-01 |
| Alcance | Sandbox, **no** gamemode | 2026-08-01 |
| Modelos | `scaryblackman` + el quemado de HL2 + los que aparezcan | 2026-08-01 |

---

## Lo que está abierto

- **Los sonidos ambiguos.** ~40 de los 265 no se pueden mapear por nombre. Ver
  [docs/SONIDOS.md](docs/SONIDOS.md) — el autor va a describirlos y ahí se renombran por literalidad.
- **Los equipos.** Props portados a descargar. Decidir cuáles entran primero: EMF reader, spirit box,
  cámara, termómetro, libro de escritura, UV, DOTS, salt, crucifijo.
- **El ritual de vuelta** del destierro: qué es y qué hace falta para ejecutarlo.
- **Cuántos PHANTOM aguanta un servidor.** La base corre en coroutines presupuestadas
  (`ENT.CoroutineThresh`) pero nunca se midió.

---

## Advertencia que vale para todo el proyecto

**Nada de lo escrito hasta ahora se ejerció en juego.** Los documentos marcan **[verificado]** cuando
algo se leyó en el código y se auditó, y **[lectura]** cuando se leyó una sola vez. Ninguna de las dos
marcas significa "funciona": significan "el código dice esto". La primera corrida en GMod es la que
convierte esto en conocimiento.
