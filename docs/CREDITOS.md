# Créditos

Phantasmagoria **incluye assets de terceros**. El código es MIT; **los assets no**, y sus autores
conservan todos sus derechos. Esta página existe para que el crédito sea explícito y verificable.

> **Si sos el autor de alguno de estos assets y querés que se retiren, se retiran.** Sin discusión y
> sin condiciones. Abrí un issue o escribí, y sale en la siguiente versión.

---

## Modelos y materiales

### K2 Meter | EMF Reader
- **Autor:** kiwontatv
- **Workshop:** [2266583399](https://steamcommunity.com/sharedfiles/filedetails/?id=2266583399)
- **Rutas:** `models/kiwontatv/ghost_busters/`, `materials/kiwontatv/ghost_busters/`
- 1 modelo, 11 texturas.

### Phasmophobia Equipment Props Pack
- **Workshop:** [2646265027](https://steamcommunity.com/sharedfiles/filedetails/?id=2646265027)
- **Rutas:** `models/phas/`, `materials/phas/`
- 22 modelos (20 de equipo + 2 bonus).

### Phasmophobia Prop Pack
- **Autor:** demit *(según el namespace `phasmophobia/demit/`)*
- **Workshop:** [2639082015](https://steamcommunity.com/sharedfiles/filedetails/?id=2639082015)
- **Rutas:** `models/phasmophobia/demit/`, `materials/models/phasmophobia/demit/`
- 13 modelos.

Los tres formaban parte de un gamemode de Phasmophobia para GMod que quedó abandonado.

### Excepción: un archivo que **no** es de ellos

`materials/phas/Strong Flashlight Glass.vmt` **lo escribimos nosotros**. El modelo
`eqp_flashlight_strong.mdl` declara esa textura en su header y el pack original **no la incluye**,
así que el lente salía con el checkerboard morado. El nombre tiene espacios y mayúsculas porque es
la cadena horneada en el binario y no se puede cambiar sin recompilar.

---

## Sonido

**Phasmophobia** — © [Kinetic Games](https://www.kineticgames.co.uk/). Los 265 efectos salen de un
rip de terceros (`phasmo-sounds-main`), convertidos a `.ogg`. Se usan como material de referencia
para un proyecto sin fines de lucro.

---

## Código y sistemas de terceros

| Qué | Autor | Para qué |
|---|---|---|
| [Terminator NextBot](https://steamcommunity.com/sharedfiles/filedetails/?id=2734691788) | **StrawWagen** | La base entera: locomotion, pathfinding, tasks, cloaking |
| `[gm] paranormal events` | — | Partículas, sonidos, y el catálogo de eventos que sirvió de especificación |
| Better Movement v2 | — | Opcional. Si está montado, la velocidad se calibra con su config |
| Datos de los 30 tipos | [tybayn](https://tybayn.github.io/phasmo-cheat-sheet/) | Velocidades, cordura y evidencias, vía el backend de su cheat sheet |

**Phasmophobia** es propiedad de Kinetic Games. Este proyecto no está afiliado ni respaldado por
ellos: es un homenaje jugable en otro motor.

---

## Sobre los duplicados

Como los assets vienen incluidos, tener además el addon original suscrito hace que **los dos monten
las mismas rutas** y GMod cargue uno solo sin avisar cuál.
[`lua/autorun/phantasmagoria_assetcheck.lua`](../lua/autorun/phantasmagoria_assetcheck.lua) lo
detecta y **avisa** — no desmonta, no bloquea, no rompe nada. La decisión es del jugador, y se
silencia con `phantasmagoria_assetcheck 0`.
