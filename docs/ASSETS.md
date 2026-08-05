# Assets — cómo reconstruir el árbol local

**Los assets no están en el repo y no van a estarlo.** El código es MIT; los modelos, sonidos y
materiales son de terceros. Esta guía dice qué hace falta y de dónde sale.

## Sonido

**656 archivos** de **Phasmophobia** (Kinetic Games), 37 MB, de dos fuentes que no hay que confundir.

| | Archivos | Origen |
|---|---|---|
| Rip de terceros | 265 | `dev/other/phantom/dev2/phasmo-sounds-main/` (fuera del repo), `.ogg` Vorbis q4 — 141 MB → 11 MB |
| **Del juego** | **391** | extraídos de la instalación con [`dev/phastools/araudio.py`](../../dev/phastools/araudio.py); Vorbis **original**, copiado sin reencodear |

De los 391, **196 son equipamiento por tier y las 7 posesiones malditas** — una carpeta por ítem bajo
`equipment/` y `cursed/`, con los archivos prefijados `t1_`/`t2_`/`t3_` cuando el juego distingue el
tier. **Las siete posesiones malditas tienen sonido**; el audio ya no es el cuello de botella de §4
de [EQUIPAMIENTO.md](EQUIPAMIENTO.md).

| | |
|---|---|
| Destino | `sound/phantasmagoria/` |
| Organizador | [`dev/organize_sounds.py`](../dev/organize_sounds.py) (primer mapeo por nombre) |
| Recatálogo | [`dev/recatalog_sounds.py`](../dev/recatalog_sounds.py) (lo que el autor identificó de oído) |
| **Importador del juego** | [`dev/import_phasmo_audio.py`](../dev/import_phasmo_audio.py) — tabla explícita, falla si un patrón no resuelve, y verifica duración copia vs. juego (391/391) |

```bash
python -u dev/phastools/araudio.py dump out\audio    # los 4138 clips del juego
python -u dev/import_phasmo_audio.py --dry-run       # qué traería
python -u dev/import_phasmo_audio.py                 # copia y verifica
```

**Los 656 están mapeados** a carpetas por acción. Qué suena cada carpeta, las transcripciones de las
líneas habladas y lo que quedó como sospecha: [`sound/phantasmagoria/about.txt`](../sound/phantasmagoria/about.txt)
— el único archivo del árbol de sonido que se versiona, y sin el cual el árbol no se puede
reconstruir.

Dos cosas del import que cambian decisiones de Lua:

- **La asimetría de `scare_strong` está cerrada.** Existía sólo `voice_2`, y el diseño obligaba a
  degradar la voz 1 a `scare_light`. El archivo estaba en el juego: ya no hace falta la degradación.
- **El índice de voz del juego es el de este árbol**, y no por suposición: los archivos que ya
  estaban resultaron ser los mismos clips (cinco coincidencias exactas de duración, y la ambigua
  resuelta por correlación de envolvente, +0,999 contra +0,359 del segundo). El detalle está en
  `about.txt`.
- **El nombre no dice el tier de forma fiable.** El mismo ítem se escribe hasta de cuatro maneras
  (`Spiritbox_T1_Off`, `T2_SpiritboxOff`, `T3_SpiritbixOff` —con typo—, `Spirit box drop`), así que
  agrupar por nombre inventa huecos que no existen. La tabla del importador lleva **un patrón por
  tier**, a propósito.
- **Tres huecos que sí son reales**: el termómetro tiene un solo clip (T2), el sensor de movimiento
  **no tiene ninguno**, y de la güija sólo existen los dos sonidos de rotura. Detalle y método en
  `about.txt`, abiertos #15 y #16.

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

## Rostros del Alternate — **derivados, no descargados**

`materials/phantasmagoria/alternate/` (6 PNG de 768×1024) sale de los seis originales de 4096×4096
que están en `dev/alternate_src/`. Un comando:

```bash
python dev/alternate_tv.py
```

**Los originales no se usan tal cual por tres motivos**, y el primero es un fallo silencioso: los
`.png` **no sobreviven bajo `sound/`** (la lista blanca del `.gma` sólo admite `wav`/`mp3`/`ogg` ahí,
así que desaparecen al empaquetar, sin error). Los otros dos son peso —400 MB de VRAM contra 18— y
encuadre: `alternate_appear` viene corrido un 10 % respecto de los cinco rostros y pegarlos
"centrados" lo hacía saltar 100 px en pantalla. El detalle medido está en §4 de
[ALTERNATE.md](ALTERNATE.md).

## Addons de terceros de los que esto depende

| Addon | Para qué |
|---|---|
| **Terminator NextBot** | La base. Dependencia dura |
| **Jeff the Hunter Playermodel** (`806714233`) | El modelo del Alternate. Sólo si se usa ese NPC — ver [ALTERNATE.md](ALTERNATE.md) §3 |
| `[gm] paranormal events` | Banco de efectos: `CreateShadowFigure`, partículas, susurros |
| Better Movement v2 | Opcional. Si está, la velocidad se calibra con su config |
| **StormFox 2** | Opcional. Si está, de ahí salen el clima y la temperatura (ver §15 del diseño) |
