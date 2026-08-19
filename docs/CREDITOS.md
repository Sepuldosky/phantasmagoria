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

### Jeff the Hunter — el modelo del Alternate

- **Autor del modelo:** **SpongePierre** (*Pierre CHOSEROT*) — [perfil](http://steamcommunity.com/id/spongepierre)
- **Base:** el **Hunter de Left 4 Dead 2**, de **Valve** (malla y texturas `newinfec` / `hunter_01`)
- **Reupload por el que nos llegó:** **Foxy** (`FoxyTLG`), con co-creador *"ima made nando mo"* —
  Workshop [806714233](https://steamcommunity.com/sharedfiles/filedetails/?id=806714233), 26 nov 2016,
  declarado como *"Server content for 'Prop Hunt OXPLAY.RU'"*
- **Rutas:** `models/newinfec/`, `materials/models/newinfec/hunter/` *(pendiente de re-namespacear —
  ver [ALTERNATE.md](ALTERNATE.md) §3.2)*
- 1 modelo, 6 texturas.

> **El ítem es un REUPLOAD y el crédito no sale del subidor.** La API de Steam devuelve como
> `creator` al que lo resubió; el autor está escrito en la descripción de la página, en texto plano.
> **El pedido de retiro, si llega, es de SpongePierre** — no del que lo publicó. El detalle y la
> lección de método están en [ALTERNATE.md](ALTERNATE.md) §11.1.

### Huellas UV — **derivadas** de `[gm] paranormal events`

- **Rutas nuestras:** `materials/phantasmagoria/uv/` (4 PNG)
- **Origen:** `materials/effects/gmpa/decals/` de `[gm] paranormal events`
- **Qué se cambió:** son decals de **sangre** (`DecalModulate`, rojo sobre blanco). Se derivó de cada
  uno una **máscara blanca teñible** —`alfa × invertir(luminancia)`— para poder pintarlas de azul-UV
  desde el cliente. **La forma es de ellos**; el cambio es de canal y de color, no de dibujo.
- **Regenerable:** [`dev/uv_prints.py`](../dev/uv_prints.py)

| Nuestro archivo | Origen | `sha256` del `.vtf` de origen |
|---|---|---|
| `hand_left.png` | `hand_l1.vtf` | `520c8e04…2a0d2e9a` |
| `hand_right.png` | `hand_r1.vtf` | `5db31955…6f31041f` |
| `smear_left.png` | `hand_l2.vtf` | `5591b2bc…46073a61` |
| `smear_right.png` | `hand_r2.vtf` | `73daa7c9…617038e9` |

> **Los hashes están para que el crédito sea verificable en las dos direcciones.** Un asset
> renombrado no es un asset propio; si alguna vez alguien duda de si estas cuatro texturas son
> nuestras, el hash de la fuente contesta sin discusión.

### Partícula de los ghost orbs — **se usó una ronda y se retiró**

`particles/gmpa_fx.pcf` estuvo en el árbol entre el 2026-08-18 y ese mismo día (rondas 1 y 2), como
copia byte-por-byte del archivo de `[gm] paranormal events`, para el sistema `gmpa_ghost_orb_green`.

**Ya no está, y no hay nada que acreditar de él.** El orbe que usa el addon es propio —un sprite
dibujado en el cliente— y el `.pcf` salió entero junto con el modo que lo usaba. La entrada se deja
escrita porque *un crédito retirado tiene que poder auditarse igual que uno vigente*: si alguien
encuentra la partícula en un `.gma` viejo, esto dice de dónde salió y hasta cuándo estuvo.

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
| [StormFox 2](https://steamcommunity.com/sharedfiles/filedetails/?id=2447774443) ([repo](https://github.com/Nak2/StormFox2)) | **Nak2** | Opcional. Si está montado, de ahí sale el clima y la temperatura |
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
