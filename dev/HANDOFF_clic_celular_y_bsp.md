# HANDOFF — el clic del interruptor, el celular que no era, y el `.bsp` que reventaba

**Fecha:** 2026-08-18 · **Repo:** `phantasmagoria` · **Changelog:** entradas **(43)** y **(44)**
**Planilla:** `dev/checks/phantasmagoria-clic-y-celular.html` — **8 filas, ninguna corrida en juego**

> Este documento está escrito para retomar sin contexto previo. Lo que decide el bloque está en el
> §3; lo que **no** se escribió y por qué, en el §4. Si vas a escribir un check, leé antes
> `memory/controles-que-premian-su-modo-de-falla.md`.

---

## 1 · De dónde viene

El autor cerró el bloque del `+USE` (CHANGELOG **41**, 13/13 en juego) y al cerrarlo pidió **tres
cosas**, textuales:

1. *«Agregar un cambio minúsculo en que al apretar el horneado o el physics, este emita un sonido de
   botón para demostrar que apagaste el objeto. ( En ui están candidatos para ese sonido:
   button_toggle_1 y 2 )»*
2. *«Al destruir un prop_physics que haga estos ruidos, sea una radio de cs office o un phone de cs
   office, el sonido debe parar.»* — y después agregó la mitad que faltaba: *«una radio phys que se
   rompa no detiene el sonido **ni permite pararlo**»*.
3. *«El ruido ( phone_vibrate.ogg ) corresponde a un celular; phone como prop horneado o phys son
   generalmente teléfonos fijos, así que phone_ring.ogg está bien, quita phone_vibrate.ogg»*

**La 1 y la 3 están escritas. La 2 no, y el §4 dice por qué.**

Después de este bloque sigue el pedido que el autor hizo hace **cuatro rondas** y que todavía no tiene
línea de investigación: **por qué el bot se queda pegado y después se despeja solo, y por qué a veces
quiere pasar a través de un vidrio**. Su pista: la base Terminator tendría convars para ver el
*thinking* del NPC — ⚠ **no está medido que existan**.

---

## 2 · Lo que está escrito y commiteado

### ① El celular que no era — `phone_vibrate` fuera de la familia teléfono
`server_events.lua`, familia `un telefono`: sale de `dur` y de `sonidos`. La familia queda con **un
solo clip** (`phone_ring`, 3,46 s) y eso está escrito ahí como decisión del autor, no como olvido. El
`.ogg` **queda en el disco**, sin consumidor, esperando un smartphone de verdad.

### ② El clic del interruptor
- Los dos clips **eran estéreo** (0,23 s y 0,35 s, 2 canales). **Source no espacializa un estéreo.**
  Pasaron por `dev/mono_posicionales.py` **antes** del cableado; quedaron en 1 canal con la misma
  duración. Backup en `dev/other/OLD/`, verificado por sha256 — ⚠ **`sound/` está gitignoreado y una
  conversión a mono no se deshace: esa copia es la única.**
- El extractor de `mono_posicionales.py` se **amplió** (lee `PROP_CONSUJETO` **y** `CLIC_APAGADO`) en
  vez de pegarle una lista, e imprime **el denominador por fuente**. Ése es el control: si dejara de
  ver la tabla vieja, diría *«ya están todas en mono»*, que es el resultado exacto de no haber mirado.
- El cableado es **una línea al final de `apagarCerca`**, en el **único** desenlace que apagó algo.
  `sound.Play` en la posición del objeto, guardada **antes** de borrarlo. Nivel `60`, no 75.
- **Sin perilla**, y el motivo está escrito: es una adición y no un recorte, así que su ausencia se
  distingue sola — el contador `apagados` dice cuántas veces tendría que haber sonado.

⚠⚠ **El clic NO suena en los otros tres desenlaces** (`lejos`, `tarde`, sin candidato). Si sonara,
además de mentirle al jugador **se come el control negativo de la planilla** (fila 04): el que la
corre oye el clic desde el otro cuarto y marca verde sobre un filtro que nunca decidió.

### ③ El `.bsp` que reventaba — CHANGELOG (44)
En `gm_uh_house` el evento `prop` tiraba `table overflow` **en cada disparo**, y bloqueaba la planilla
entera. La causa, medida: `dictEntries = 1095588428`, que escrito de vuelta como cuatro bytes es
**`LZMA`** — el lump `sprp` viene comprimido y el parser leyó la firma como si fuera una cantidad.

Dos defectos: **las guardas de conteo miraban un solo lado** (`n < 0`, nunca «no entra en el tramo»), y
**`parsear` podía tirar**, rompiendo su propio contrato escrito y sin cachear el fallo. Los dos
arreglados. El instrumento gemelo (`censo_props_horneados.py`) tenía el mismo defecto **con otra
cara: en Python se cuelga en vez de reventar**, y también quedó arreglado.

    gm_funkis_night   418 / 1588   ( sin cambios: es el CONTROL )
    gm_uh_house       188 /  702   sprp COMPRIMIDO · 11 modelos / 13 instancias reclamadas

---

## 3 · ⚠⚠⚠ LO QUE HAY QUE MEDIR PRIMERO — filas 00 y 01

La frase **«borrar el emisor ES un corte: una entidad que se va se lleva su canal»** está escrita en
**cinco lugares** — `server_events.lua:218`, `:875`, `:3409`, `dev/duracion_ogg.py:8` y el
CHANGELOG (41) — y **NUNCA SE MIDIÓ**. Nació como razón en un comentario y se citó después como si
fuera un resultado; el `:3409` es el más viejo, o sea que ya se propagó de una ronda a la siguiente.

- Si es **cierta** → romper el prop ya corta el sonido solo y el pedido 2 **está hecho**.
- Si es **falsa** → es un defecto real, `EMISOR_MARGEN` no protegió nunca de nada, y **hay que
  corregir los cinco lugares en el mismo commit**. *Si la prosa y el código discrepan, el próximo
  lector copia la prosa* — ya pasó exactamente así con esta frase.

Se mide con `clock_tick` (**46,55 s**, mono) y **no** con un clip corto: *un sonido que se termina solo
pasa por un borrado que funcionó.* La fila lleva un **cuarto comando** que no estaba en el plan
original y que es el que la vuelve una medición: `IsValid()` después del borrado. Sin él, *«el tic-tac
sigue»* no distingue **el borrado no calla** de **el borrado no ocurrió**.

Y **romper no es borrar** (fila 01, aparte a propósito): un `prop_physics` que se rompe puede spawnear
pedazos y sacarse a sí mismo en otro momento del frame. El camino a medir es el del autor —a tiros—,
con el remover del toolgun como segunda mitad para separar los dos caminos.

---

## 4 · Lo que NO se escribió, y por qué está dicho en vez de tapado

**El pedido 2 no tiene código.** Si las filas 00/01 salen verdes no hace falta ninguno.

Si salen rojas, el arreglo tiene **una segunda precondición sin medir**: si un `StopSound` sobre una
entidad *que se está yendo* llega a tiempo. Dos candidatos, con costos distintos:

- `EntityRemoved` global — el addon no tiene ninguno, y correría por **cada** entidad que muere;
- `ent:CallOnRemove` acotado a los props a los que **nosotros** hicimos sonar.

*Un arreglo cuyo mecanismo no está medido es una hipótesis con forma de commit.*

⚠ **La mitad de «ni permite pararlo» ya está confirmada leyendo el código, sin el motor:**
`podarSonando()` tira la entrada de `SONANDO` cuando la entidad deja de ser válida, y `apagarCerca()`
poda **antes** de buscar. O sea que **el registro suelta el único mango justo en el momento en que
haría falta**: rota la radio, el `+USE` no tiene a quién apagar, ni ahora ni nunca. Eso no depende de
lo que midan 00 y 01 — lo que ellas deciden es la otra mitad.

**Frontera menor, no audible:** la poda de `SONANDO` corre sólo cuando alguien mira el registro (en
`EV.prop`, en el `+USE` y en el reporte), así que quedan entradas inválidas contadas hasta la lectura
siguiente.

**Lo que no se pudo medir sin el juego, y es una sola cosa:** si el `util.Decompress` de GMod acepta la
cabecera «alone» que el `.lua` le arma para el lump comprimido. Que el **dato** está ahí sí se midió
(15005 bytes se abren en 78334). El camino **se verifica a sí mismo** contra el largo declarado en la
cabecera, y si falla degrada a `ok = false` con motivo. Es la rama de FALLA de la fila **P0**.

---

## 5 · La planilla — 8 filas, en este orden

`dev/checks/phantasmagoria-clic-y-celular.html` — ⚠ vive en el `dev/` de la **raíz del workspace**, que
**no** es un repo git, así que **no está versionada y no viaja con el push**. Está en el disco de la
máquina del autor, y **su estado (los tildes y las notas) vive en el localStorage del navegador**, con
la clave `phantasmagoria-clic-y-celular`.

⚠ **Hubo una corrida que no se pudo terminar**, y está guardada en
[CORRIDA_clic_y_celular_parcial.md](CORRIDA_clic_y_celular_parcial.md): las 7 filas quedaron sin
correr porque el evento `prop` reventaba en `gm_uh_house`. Ese error es el que originó la fila **P0** y
el CHANGELOG (44). **La fila 00 hay que rehacerla desde el primer comando.**

| # | qué mide |
|---|---|
| **P0** | el evento `prop` ya no revienta en `gm_uh_house`, y el censo dice **188 / 702**. **Se corre primero: sin esto no hay planilla.** |
| **00** | P1 — borrar la entidad, ¿calla el sonido? Con `clock_tick` y el control de `IsValid`. |
| **01** | P1b — **romper** un `prop_physics` que suena, ¿lo calla? Y el remover como segunda mitad. |
| **02** | offline: los dos clips en **mono** y con la misma duración, y el **denominador por fuente** del extractor. |
| **03** | el clic suena al apagar y **desde el objeto**. Trae un amplificador opcional (`evuseradius 512`). |
| **04** | **CONTROL NEGATIVO** — `E` desde lejos: **ningún clic** y `lejos` sube. La fila más importante de perder. |
| **05** | el teléfono suena `phone_ring` y nunca `phone_vibrate`, y la guarda 3b no grita al cargar. |
| **06** | no romper lo que andaba: el `+USE`, `E` en puertas/props/vehículos, y el pestillo. |

⚠ **Un comando por línea** — dos concommands en la misma línea corren en el mismo frame, y este repo ya
cerró tres filas verdes con el número anterior.
⚠ **La consola de Source corta en 255 caracteres y no avisa**, y el error resultante parece de
sintaxis de Lua. La planilla mide el largo de cada comando; el más largo de ésta mide **145**.
⚠ Si la fila 03 dejó `evuseradius` en **512**, la fila 04 **no mide nada y no puede darse cuenta**. Su
precondición es leerlo primero.

---

## 6 · Instrumentos (todos offline, todos con auto-control)

    find lua -name '*.lua' -print0 | xargs -0 python dev/luacheck_gmod.py   # 36/36 · SIN args revisa CERO y sale 0
    python dev/parsear_sintaxis_glua.py lua                                # 36/36 · el que COMPILA de verdad
    python dev/auditar_returns_de_hooks.py lua                             # 0/28
    python dev/rutas_de_sonido.py                                          # 165 citadas, 0 faltantes
    python dev/guarda_3b_offline.py                                        # corre LA guarda, y le mueve la perilla
    python dev/bsp_statics_offline.py <ruta.bsp>                           # corre EL parser sobre un .bsp real
    python dev/duracion_ogg.py sound/phantasmagoria/prop/radio             # calibra; sin esto dice PARCIAL
    python dev/mono_posicionales.py                                        # seco por defecto; --aplicar para tocar

**Nuevos de este bloque:** `rutas_de_sonido.py`, `guarda_3b_offline.py`, `bsp_statics_offline.py`.
Los dos últimos **cargan el `.lua` del addon y lo ejecutan** en un Lua real en vez de reimplementarlo:
dos copias de acuerdo entre sí no prueban nada del código que corre.

⚠ `luacheck_gmod.py` **no parsea sintaxis** y **sin argumentos revisa cero archivos y sale 0** — verde
sin medir. Va siempre con el `find ... | xargs`.

Para sacar un `.bsp` de un `.gma` del Workshop: `gmpublisher.gma` vive en
`steamapps/workshop/content/4000/<id>/`. `gm_uh_house` es **3670351244**, `gm_funkis_night` es
**3382694345**.

---

## 7 · ⚠⚠ Lo que hay que saber del repo antes de tocar nada

**Hay varias sesiones trabajando este repo al mismo tiempo, y hoy costó.** Mientras se escribía este
bloque, otra sesión editaba **el mismo `server_events.lua`** y **commiteó primero**: los cambios del
clic y del teléfono quedaron **adentro de `221c5e8`** («El cuerpo y la voz de cada fantasma»), que no
los menciona. Nadie perdió trabajo, pero **buscar «el clic» por `git log` no lo encuentra**.

Reglas que salieron de eso y de antes:

- **Nunca `git add -A`.** Stagear rutas explícitas y commitear con `git commit -F- -- rutas`, que no
  deja ventana entre el `add` y el `commit`.
- **Mirar `git log` DESPUÉS de commitear.** Un «no changes added» puede querer decir que tu trabajo ya
  está adentro del commit de otro.
- **El tell de la colisión intra-archivo es barato:** si un archivo que editaste **deja de aparecer en
  `git status`**, no se desmodificó — alguien lo commiteó.
- `lua/autorun/client/phantasmagoria_eq_check.lua` está modificado por otra sesión: **no stagearlo**.
- **Commits sin `Co-Authored-By`.**
- El autor es **chileno**: escribirle de **tú**, sin voseo. Vale también para estos documentos, que
  los lee él.

---

## 8 · Estado exacto al cerrar

- **Escrito, chequeado offline, SIN CORRER EN JUEGO.** Ninguna de las 8 filas se corrió.
- Chequeos al día: `luacheck 36/36` · `sintaxis 36/36` · `hooks 0/28` · `rutas 165/0 faltantes` ·
  guarda 3b callada **y comprobada gritando** · `bsp offline` reproduce el control 418/1588 y pasa su
  control negativo.
- Commits de este bloque: **`398f185`** (instrumentos y docs del clic/celular) y **`6172534`**
  (el arreglo del `.bsp`). El Lua del clic y del teléfono está en **`221c5e8`**, que es de otra sesión.
