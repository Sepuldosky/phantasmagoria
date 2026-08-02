# Phantasmagoria

Un NextBot de **Garry's Mod** que recrea los fantasmas de **Phasmophobia**, construido sobre la base
[Terminator NextBot](https://steamcommunity.com/sharedfiles/filedetails/?id=2734691788).

**Para sandbox.** No es un gamemode y no pretende serlo: es una entidad, sus equipos y sus mecánicas,
sueltos en el mundo para que cualquiera los use. Si alguien quiere armar un gamemode de investigación
encima, el diseño está pensado para no estorbarle — ganar en Phasmophobia es *identificar* al
fantasma, y eso es agnóstico de quién lleve el puntaje.

> **Estado: en diseño.** Hay tabla de tipos y documentación técnica; **todavía no hay entidad
> jugable**. Ver [ESTADO.md](ESTADO.md).

---

## La idea

Un solo NextBot implementa **todas** las mecánicas genéricas —estados, cordura, evidencias, hunt— y
los **30 tipos de fantasma no son 30 clases**: son 30 filas de una tabla que enciende y parametriza
lo mismo.

```lua
-- un Revenant es esto, y nada más:
T[ "revenant" ] = {
    name     = "Revenant",
    evidence = { "orbs", "writing", "freezing" },
    speed    = { base = 0.588, top = 1.765, losSpeedUp = false },
    hunt     = { threshold = 50 },
}
```

Los `speed` son **multiplicadores de la velocidad real del jugador**, no m/s absolutos: el addon se
calibra solo en cualquier servidor, con o sin mods de movimiento.

**La prueba de fuego del corte son `The Mimic` y `The Twins`.** Si alguno necesita un `if` especial
dentro del cerebro, el motor está mal cortado y hay que rediseñar antes de seguir.

## Qué hay hoy

| | |
|---|---|
| [`lua/phantasmagoria/ghost_types.lua`](lua/phantasmagoria/ghost_types.lua) | **Los 30 tipos** con velocidades, umbrales de cordura y evidencias. Generado, no escrito a mano |
| [`dev/gen_types.py`](dev/gen_types.py) | El generador de la tabla |
| [`docs/PHANTOM_Phasmophobia_Diseno.md`](docs/PHANTOM_Phasmophobia_Diseno.md) | El diseño: motor de rasgos, máquina de estados, conversión de unidades |
| [`docs/PHANTOM_Referencia.md`](docs/PHANTOM_Referencia.md) | La investigación de la base Terminator: qué regala y dónde están sus trampas |

## Assets

**No hay assets en este repo, a propósito.** El código es MIT; los modelos, sonidos y materiales no
son nuestros. Ver [`.gitignore`](.gitignore).

## Créditos

- **Terminator NextBot** — StrawWagen. La base de locomotion y comportamiento.
- **Phasmophobia** — Kinetic Games. Las mecánicas que esto recrea.
- Datos de tipos derivados del backend del [cheat sheet de tybayn](https://tybayn.github.io/phasmo-cheat-sheet/).

## Licencia

[MIT](LICENSE) — sólo el código. Los assets de terceros conservan la suya.
