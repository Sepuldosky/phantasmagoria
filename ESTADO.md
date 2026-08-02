# Phantasmagoria — Estado actual y handoff

**Última actualización:** 2026-08-01
**Repo:** https://github.com/Sepuldosky/phantasmagoria (público, MIT)
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
| Diseño de spawn / dificultad / cuartos | **CERRADO** — §12, §13, §14 del diseño |
| **Props de equipamiento** | **EN EL ÁRBOL** — 36 modelos verificados, 0 referencias rotas |
| Detector de addons duplicados | **ESCRITO** — `lua/autorun/phantasmagoria_assetcheck.lua` |
| Entidad `terminator_nextbot_phantom` | **NO EXISTE** ← el próximo paso |
| Sistema de cuartos + toolgun | **NO EXISTE** — diseñado en §14 |
| SWEPs / entidades de equipo | **NO EXISTEN** — los modelos ya están, falta el Lua |
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

- **Los sonidos ambiguos: 46 de 265.** Están en `sound/phantasmagoria/_sin_identificar/`, con el
  detalle de qué falta saber de cada uno en el `about.txt` de esa carpeta (agrupados y con duración).
  El autor los describe y ahí se renombran por literalidad y se mueven a la carpeta que toque.
  Los otros **219 ya están mapeados** por acción.
- **Los equipos.** La **forma** ya está decidida ([docs/EQUIPAMIENTO.md](docs/EQUIPAMIENTO.md) §5):
  SWEP lo que se sostiene, entidad lo que se planta y la escenografía, ítem con `onUse` lo que se
  consume. Falta **elegir cuáles entran primero** — EMF reader, spirit box, cámara, termómetro, libro
  de escritura, UV, DOTS, salt, crucifijo — y escribir el primero de punta a punta. El viewmodel es
  el prop flotando frente a la cámara: los 36 modelos tienen **1 hueso y 1 secuencia**, así que no
  hay manos ni animación posibles sin recompilar (§5.1, medido).
- **Cargo.** La integración está diseñada y leída contra su código (§6), sin escribir. Lo que hay que
  saber antes de tocar nada: **la captura de Cargo se come cualquier SWEP** que el engine entregue y
  le fabrica un def de 2,5 kg sin precio, así que registrar defs propios no es opcional si Cargo
  está montado. Sigue siendo **soft-dep**: sin Cargo tiene que haber camino propio.
- **El ritual de vuelta** del destierro: qué es y qué hace falta para ejecutarlo.
- **Las posesiones malditas: son 7 y tenemos 1.** Documentadas con sus mecánicas y costes de cordura
  en [docs/EQUIPAMIENTO.md](docs/EQUIPAMIENTO.md) §4. Sólo la **Voodoo Doll** tiene modelo; el
  **Summoning Circle** es armable hoy con las velas + el encendedor que ya están en disco, y es el
  candidato natural para el primero. Faltan modelo para Ouija, Espejo, Caja de Música, Pata de Mono
  y Tarot.
- **El detector de cuartos no va a ser perfecto** en mapas de GMod, que no fueron hechos para esto.
  Por eso hay toolgun manual y por eso §14.5 define qué pasa cuando no hay mapeo: degradar, nunca
  romper.
- **El clima**: se integra con **StormFox 2** en vez de reimplementarse (§15). Su API está verificada
  contra el repo (publicado 2021, actualizado 2026-05-01: mantenimiento activo); falta escribir el
  mapeo y el camino propio para quien no lo tenga. **gWeather y
  Simple Weather sin investigar.**
- **Los tiers de equipamiento** (§16): documentados, sin implementar. Va un tier por equipo en la v1.
- **Cuántos PHANTOM aguanta un servidor.** La base corre en coroutines presupuestadas
  (`ENT.CoroutineThresh`) pero nunca se midió.

---

## Advertencia que vale para todo el proyecto

**Nada de lo escrito hasta ahora se ejerció en juego.** Los documentos marcan **[verificado]** cuando
algo se leyó en el código y se auditó, y **[lectura]** cuando se leyó una sola vez. Ninguna de las dos
marcas significa "funciona": significan "el código dice esto". La primera corrida en GMod es la que
convierte esto en conocimiento.
