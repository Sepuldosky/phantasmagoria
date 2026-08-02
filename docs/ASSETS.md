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
| Organizador | [`dev/organize_sounds.py`](../dev/organize_sounds.py) |

219 de los 265 están mapeados a carpetas por acción; **46 siguen sin identificar** y viven en
`sound/phantasmagoria/_sin_identificar/`. Ver el `about.txt` de esa carpeta.

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

Los equipos de Phasmophobia (EMF reader, spirit box, cámara, termómetro, libro, UV, D.O.T.S., sal,
crucifijo, velas, trípode) están portados a GMod por terceros. **Pendiente de descargar.**

## Addons de terceros de los que esto depende

| Addon | Para qué |
|---|---|
| **Terminator NextBot** | La base. Dependencia dura |
| `[gm] paranormal events` | Banco de efectos: `CreateShadowFigure`, partículas, susurros |
| Better Movement v2 | Opcional. Si está, la velocidad se calibra con su config |
