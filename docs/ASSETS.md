# Assets — cómo reconstruir el árbol local

**Los assets no están en el repo y no van a estarlo.** El código es MIT; los modelos, sonidos y
materiales son de terceros. Esta guía dice qué hace falta y de dónde sale.

## Sonido

265 archivos de **Phasmophobia** (Kinetic Games), rippeados por terceros y convertidos a `.ogg`.

| | |
|---|---|
| Origen | `dev/other/phantom/dev2/phasmo-sounds-main/` (fuera del repo) |
| Convertidos | `.ogg` Vorbis q4 — 141 MB → 11 MB |
| Destino | `sound/phantasmagoria/` |
| Organizador | [`dev/organize_sounds.py`](../dev/organize_sounds.py) (primer mapeo por nombre) |
| Recatálogo | [`dev/recatalog_sounds.py`](../dev/recatalog_sounds.py) (lo que el autor identificó de oído) |

**Los 265 están mapeados** a carpetas por acción. Los 46 que el nombre no justificaba se cerraron el
2026-08-03 y `_sin_identificar/` ya no existe. Qué suena cada carpeta, las transcripciones de las
líneas habladas y lo que quedó como sospecha: [`sound/phantasmagoria/about.txt`](../sound/phantasmagoria/about.txt)
— el único archivo del árbol de sonido que se versiona, y sin el cual el árbol no se puede
reconstruir.

## Modelos

| Modelo | Ruta | Estado |
|---|---|---|
| Scary Black Man | `models/dejtriyev/scaryblackman.mdl` | **el vigente** — skin 0 negro total, skin 1 ojos blancos |
| Quemado de HL2 | `models/humans/charple*.mdl` | a evaluar — es contenido base de HL2 |
| Otros | — | el autor busca más |

**El criterio para aceptar un modelo nuevo:** tiene que declarar `$includemodel models/m_anm.mdl`.
La base Terminator mueve el cuerpo con activities `ACT_MP_*`, que son las del set de **player**.
Un modelo con animaciones de NPC no camina. Comprobación:

```bash
python -c "import re;d=open('MODELO.mdl','rb').read();print([x.decode() for x in re.findall(rb'[ -~]{4,}',d) if x.endswith(b'.mdl')])"
```

Si en esa lista no aparece `models/m_anm.mdl`, el modelo no sirve tal cual. La historia completa
está en §10 de [PHANTOM_Referencia.md](PHANTOM_Referencia.md).

## Props de equipamiento

**Ya están en el árbol** (sesión 4): 36 modelos, 63 `.vmt` y 58 `.vtf` de tres packs del Workshop con
namespaces distintos y **0 colisiones entre ellos**. Verificados desde el binario; el detalle de cada
uno y qué mecánica cubre está en [EQUIPAMIENTO.md](EQUIPAMIENTO.md). Autores en
[CREDITOS.md](CREDITOS.md).

| | |
|---|---|
| Rutas | `models/` + `materials/` bajo `kiwontatv/`, `phas/`, `phasmophobia/demit/` |
| Verificador | [`dev/verify_tree.py`](../dev/verify_tree.py) — cruza cada textura contra su `.vmt` y su `.vtf` |
| Inspector | [`dev/mdlinfo.py`](../dev/mdlinfo.py) — bodygroups, skins, masa, `surfaceprop` |
| Visor de texturas | [`dev/vtf2png.py`](../dev/vtf2png.py) — `.vtf` → `.png`, con hoja de contactos |

## Huellas de la evidencia UV — **generadas, no descargadas**

`materials/phantasmagoria/uv/` (4 PNG) **no se descarga: se genera** desde los decals de sangre que
`[gm] paranormal events` trae y nunca usa. Un comando:

```bash
python dev/uv_prints.py
```

Necesita el addon de origen montado en `dev/other/` (el script lo dice si falta). La derivación y el
porqué están en §8.6 de [EQUIPAMIENTO.md](EQUIPAMIENTO.md); el crédito, con el hash de cada fuente,
en [CREDITOS.md](CREDITOS.md).

## Addons de terceros de los que esto depende

| Addon | Para qué |
|---|---|
| **Terminator NextBot** | La base. Dependencia dura |
| `[gm] paranormal events` | Banco de efectos: `CreateShadowFigure`, partículas, susurros |
| Better Movement v2 | Opcional. Si está, la velocidad se calibra con su config |
| **StormFox 2** | Opcional. Si está, de ahí salen el clima y la temperatura (ver §15 del diseño) |
