# El Alternate — NPC de evento especial **[2026-08-04, ampliado 2026-08-05]**

> **Qué es esto.** El diseño del único NPC de Phantasmagoria que **no** es uno de los 30 tipos de
> Phasmophobia. Nace de un banco de audio que trajo el autor y de un `about.txt` suyo; este documento
> existe porque ese `about.txt` no es lugar para un diseño, y porque lo que se midió alrededor de él
> —el modelo, las imágenes, las duraciones— **no cabe en un archivo que describe una carpeta de
> sonidos**.
>
> **Ficción.** El Alternate viene de [Mandela Catalogue](https://mandelacatalogue.fandom.com/), una
> serie de analog horror de Alex Kister. Su mecánica central —M.A.D., *Metaphysical Awareness
> Disorder*— es angustiante a propósito **dentro de esa ficción**. Acá es un enemigo de un juego de
> Garry's Mod: una barra que baja y un NPC que persigue. Nada de lo que sigue describe ni recomienda
> nada fuera de eso.

**Fuente del comportamiento:** `sound/phantasmagoria/ghost/special/alternate/about.txt` y las notas
del autor. Este documento conserva la ficha entera (§13) y le agrega lo que se midió.

> **2026-08-05 — el banco se triplicó y eso cambió el diseño, no sólo los números.** De 34 a **168
> archivos**. Lo nuevo no es "más de lo mismo": `sayto_ghost` obliga a que **haya otro fantasma en el
> mapa** (§7) y `idle_prayer` abre **la única ventana en la que se lo puede desterrar** (§8). Las dos
> secciones son nuevas y son el loop.

---

## 1. Qué es, en una línea

Un demonio o ángel caído de tiempos bíblicos que **no se caza ni se destierra por la vía normal: te
desgasta**. No es un fantasma con evidencias que se identifica y se despacha; es un evento que entra,
te estudia, te vacía la cordura por todos los canales a la vez y te mata cuando estás lejos del
camión.

De la wiki, citado por el autor:

> They are demonic and sadistic shapeshifters who drive their victims insane […] realised by the
> alternates through the transmission of a psychological condition, Metaphysical Awareness Disorder,
> caused by exposure to *"verbal information that is not desired to be known"*.

**Esa última frase es el diseño entero.** El daño no lo hace estar cerca: lo hace *escucharlo*. §5 la
convierte en una regla que el motor puede evaluar, y §7 la convierte en el dilema que sostiene la
partida: **la información que necesitás para ganar es la que te está matando.**

---

## 2. El banco de audio **[medido 2026-08-05]**

**168 `.ogg`**, hechos con Microsoft SAM por el autor. **22.050 Hz**, mono y estéreo mezclados,
**1.209 s = 20,2 minutos** de voz.

| Grupo | n | mín | mediana | máx | total | Rol |
|---|---:|---:|---:|---:|---:|---|
| `sanity_attack` | 30 | 1,8 s | 5,8 s | 9,8 s | 170,8 s | frases largas que dañan la cordura |
| `sayto_ghost` (genérico) | 25 | 2,6 s | 6,5 s | 9,8 s | 165,7 s | le habla **al otro fantasma** → §7 |
| `hurt` | 21 | 1,5 s | **2,8 s** | 6,2 s | 68,4 s | burlas por no recibir daño + acuse de la degradación |
| `biblequote_yapping` | 14 | 10,8 s | **21,1 s** | 24,1 s | **272,9 s** | cita bíblica + reproche directo a Dios. **Cero daño** |
| `idle_lament` | 13 | 3,8 s | 5,8 s | 7,8 s | 78,0 s | habla con su propio "yo", lamenta la caída |
| `sayto_ghost_demon` | 10 | 3,3 s | 6,9 s | 10,1 s | 69,7 s | el nombre le queda grande |
| `idle_prayer` | 10 | 4,6 s | **5,9 s** | 8,1 s | 62,6 s | le habla a Dios, pide respuestas o perdón → **§8** |
| `sanity_strong_attack` | 8 | 2,6 s | 4,4 s | 8,0 s | 40,0 s | induce al jugador a dañarse a sí mismo |
| `sayto_ghost_jinn` | 8 | 7,0 s | 10,5 s | 11,6 s | 78,5 s | nombre prestado |
| `sayto_ghost_goryo` | 5 | 5,3 s | 9,7 s | 11,6 s | 46,5 s | **respetuoso** — le reconoce el título nobiliario |
| `sayto_ghost_oni` | 5 | 9,0 s | 10,8 s | 12,6 s | 53,2 s | irónico: no es un Oni de verdad |
| `sayto_ghost_poltergeist` | 3 | 5,1 s | 9,7 s | 10,6 s | 25,4 s | insultante, menospreciativo |
| `sayto_ghost_shade` | 3 | 8,6 s | 9,0 s | 9,4 s | 26,9 s | "fantasma con nombre de romano cobarde" |
| `sayto_ghost_yokai` | 3 | 3,6 s | 8,9 s | 9,2 s | 21,7 s | nombre prestado |
| `here` | 3 | 0,7 s | 1,4 s | 1,4 s | 3,5 s | señuelo: dice "acá" para despistar |
| `banished` | 2 | 1,3 s | 1,4 s | 1,4 s | 2,7 s | *"un simple Oooh o no…"* → **§8** |
| `watching_player` | 2 | 0,9 s | 1,2 s | 1,2 s | 2,1 s | *"I see you"* / *"I'm watching you"* |
| `hunt_loop_long` | 1 | — | 13,4 s | — | 13,4 s | repetido rápido y con más fuerza → *hunt cursed* |
| `preacherwhispers` | 1 | — | **6,0 s** | — | 6,0 s | ininteligible; el golpe grande → §6 |
| `hunt_loop` | 1 | — | 1,3 s | — | 1,3 s | *"nothing is worth the risk"*, en loop |

> ⚠ **Trampa del instrumento, anotada para el que vuelva a medir esto.** El sample rate de un Ogg
> Vorbis está a **`+12`** del marcador `\x01vorbis`, no a `+11`: en `+11` está el byte de canales, y
> leer cuatro bytes desde ahí devuelve `canales | (rate << 8)`. La primera corrida dio **5.644.801 Hz**
> y duraciones divididas por 256 —`preacherwhispers` "duraba" 0,02 s— y **el error se delató solo
> porque 5,6 MHz es imposible**. Si el corrimiento hubiera sido de un campo plausible, las duraciones
> falsas habrían pasado derecho al diseño.

### 2.1 Cuatro cosas que las duraciones deciden solas

**a) `biblequote_yapping` dejó de ser relleno: son 4,5 minutos.** Mediana **21,1 s** contra los 10,4 s
de la única pieza que había antes. Eso ya no tapa un hueco de cooldown: **es una capa de ambiente**.
Ver §10, fase 0.

**b) `hurt` es el banco más corto del set** (mediana 2,8 s). Correcto: es reacción, no discurso. Puede
dispararse encima de otra cosa sin que suene a bug, porque una interjección corta encimada se lee
como interrupción y no como dos voces peleando.

**c) `idle_prayer` mide lo mismo que `preacherwhispers`.** Mediana **5,9 s** contra **6,0 s**. Esa
simetría no la inventé y es demasiado buena para no usarla: **él tiene 6 segundos tuyos (§6) y vos
tenés 6 segundos suyos (§8).** El diseño sale del disco.

**d) Las líneas específicas son MÁS LARGAS que las genéricas, pero no siempre** — y esa mezcla es la
que hace bueno al §7:

| | rango |
|---|---|
| `sayto_ghost` genérico (25) | 2,6 … **9,8 s** |
| `sayto_ghost_<tipo>` específico (37) | 3,3 … 12,6 s |

**Toda línea de más de 9,8 s nombra a un fantasma, sin excepción** — son 12 de las 37. Pero **25 de
las 37 caen dentro del rango genérico y son indistinguibles por duración**, y las peores son las de
`demon` (9 de 10). O sea: hay un tell real, y es **poco fiable**. Justo lo que hace falta para que el
jugador desarrolle una corazonada en vez de una regla.

### 2.2 Auditoría de los tags — dos mienten, y no importa

Los 168 se revisaron comparando el nombre de archivo contra el `TITLE` embebido en los comentarios
Vorbis. **164 coinciden, 4 no tienen tag, y 2 mienten:**

```
alternatemandela_banished_1.ogg   ->  TITLE=alternatemandela_hurt_1
alternatemandela_banished_2.ogg   ->  TITLE=alternatemandela_hurt_2
```

**No son copias de los `hurt`**, y eso hubo que medirlo en vez de suponerlo: `banished_1` dura 1,39 s
y `hurt_1` 1,95 s; los tamaños y los `sha256` también difieren. El tag quedó pegado del lote de
exportación anterior. **Miente la etiqueta, no el archivo** — que es la única forma de este problema
que no cuesta nada.

Valía la pena mirarlo igual: `banished` es **el único sonido del banco que significa que el jugador
ganó** (§8.5). Si hubiera resultado ser un `hurt` renombrado, el final de la partida habría sonado a
burla.

### 2.3 La transcripción — qué es y qué no **[2026-08-05, con permiso del autor]**

Los 168 se transcribieron **localmente**, con `faster-whisper` modelo `small`, sin que nada saliera
de la máquina. Antes de eso, todo este documento estaba construido sobre duraciones y sobre las
descripciones por grupo del autor.

**Es aproximada y hay que tratarla como tal.** SAM distorsiona y el modelo `small` falla justo donde
más importa: **los nombres propios** (`Goryo` → *Morio*, `Jinn` → *JID*, `Yokai` → *Yaka*), y varias
líneas salen medio rotas. Sirve para **clasificar y decidir diseño**; **no sirve para subtítulos** sin
volver a correrla con `medium` o sin que el autor pase el texto original con el que generó las voces.

Cuatro archivos no devolvieron texto, y los cuatro tienen sentido: `preacherwhispers` (es
ininteligible **a propósito**), `hunt_loop`, `hunt_loop_long` y `banished_2`.

**Los bancos coinciden con sus etiquetas** — se verificó leyendo, no sólo contando. `idle_prayer`
efectivamente le habla a Dios (*"I said your name, I still say it, it doesn't open anything now"*),
`idle_lament` habla consigo mismo (*"I have a name. It's just a noise I make now"*), y el genérico de
`sayto_ghost` es genérico de verdad.

**El archivo NO se guardó en el repo.** Vive en el scratchpad de la sesión. El repo es público y una
transcripción literal de `sanity_strong_attack` es exactamente lo que no conviene dejar indexado; si
se quiere en `dev/`, va con entrada propia en `.gitignore`. **Decisión pendiente del autor.**

#### El resultado que importa para la compuerta de contenido: está confinado

Se barrieron los 168 con un patrón amplio de lenguaje de inducción. **Fuera de
`sanity_strong_attack` no aparece ninguno.** Los cuatro candidatos que saltaron en `sanity_attack`
son amenaza y desesperanza, no instrucción:

> *"If you close your eyes, I will take your place, and no one will notice."*
> *"Your God is dead."* · *"You will die alone."*

Eso hace que **la compuerta de contenido sensible (§14, sin decidir) tenga que cubrir un solo banco**, que es la mejor noticia
posible para esa decisión: es un interruptor, no una auditoría permanente.

---

## 3. El modelo: `Jeff the Hunter` **[medido 2026-08-04]**

**Workshop [806714233](https://steamcommunity.com/sharedfiles/filedetails/?id=806714233)**,
desempacado a [`dev/other/jeff the hunter player model/`](../../dev/other/jeff%20the%20hunter%20player%20model/)
y dado de alta en [`dev/mods_workshop_mapa.md`](../../dev/mods_workshop_mapa.md) §2.

> **Ojo con el formato:** Steam lo tiene como `806714233/99472719169836756_legacy.bin`. Es un GMA
> **comprimido con LZMA-alone**, no un `.gma` crudo, y por eso el lector del skill lo rechaza con
> *"falta el magic GMAD"*. Se descomprime con `lzma.FORMAT_ALONE` y de ahí sigue el flujo normal.

Es el **Hunter de Left 4 Dead 2** (`models/newinfec/newhun.mdl`; *newinfec* = new infected)
re-riggeado a playermodel de GMod.

### 3.1 Lo que sirve

| Medido | Por qué importa |
|---|---|
| **53 huesos, `ValveBiped.Bip01_*` completo** | Es el esqueleto que la base Terminator sabe vestir. |
| **5 includes de animación de player de HL2** (`m_anm`, `m_gst`, `m_pst`, `m_shd`, `m_ss`) | Camina, corre, agacha y gesticula sin compilar nada. |
| **3 pose params**: `move_yaw`, `body_pitch`, `body_yaw` | *"Se queda en la esquina mirándote"* sale gratis: es girar dos pose params. |
| 5 attachments (`attach_blur`, `lfoot`, `rfoot`, `lhand`, `rhand`), 4 cadenas de IK | Pisadas y efectos tienen dónde colgarse. |

### 3.2 Las cuatro reservas

| # | Medido | Consecuencia |
|---|---|---|
| 1 | **`flexdesc_count` = `flexcontroller_count` = `flexrules_count` = 0** | **No tiene flexes** — y **eso NO es un problema**: el tell del Doppelgänger es *expresión fija y parpadeo incorrecto*, o sea que cero flexes **es** el tell, y el del Flawed Impersonator son proporciones, que son **huesos**. Ver §11.1, que corrige lo que esta fila decía antes. |
| 2 | **hull `(-16384, -16384, -38,5) → (-9999, -9999, 34,7)`** | Roto: en X/Y ni siquiera contiene el origen. Hay que `SetCollisionBounds` a mano o el bot arranca con una caja absurda. |
| 3 | **`$allowdiffusemodulation 0`** en el `.vmt` *(leído)* | Bloquea la modulación de color de la entidad. **Preocupa MENOS de lo que decía este documento**: la base no usa `SetColor` para ocultarse, usa `SetMaterial` + `SetRenderMode` → §3.3. Sigue importando para teñir, no para el cloak. |
| 4 | **`$Selfillum 1` sin `$selfillummask`** *(leído)* | Usa el alfa del basetexture (`hunter_01.vtf`, DXT5, con `EIGHTBITALPHA`): partes del modelo se auto-iluminan y **nunca queda del todo oscuro** — lo contrario de lo que pide el about. |

**3 y 4 se resuelven con material propio en namespace propio, y eso hay que hacerlo igual**: dejarlo
en `models/newinfec/` colisiona con cualquiera que tenga el addon suscrito (precedente:
`phantasmagoria_assetcheck.lua`). **No gastar una medición en el punto 3** — el `.vmt` nuevo cuesta
menos que comprobar el viejo.

La proxy `BloodyHands` del `.vmt` es de L4D2 y no existe en GMod. Es inofensiva: ruido de consola.

> **El nombre del `.gma` ("Jeff the Hunter Player Model") no coincide con el de la página ("Jeff the
> Hunter Playermodel").** Otra vez lo mismo: el nombre sirve para buscar, nunca para emparejar.

### 3.3 La invisibilidad ya está en la base **[verificado contra el código, 2026-08-05]**

El autor afirmó que Terminator puede hacerse invisible porque HIM lo hace. **Es cierto, y no hace
falta HIM:** está en la base, en un archivo dedicado —
[`terminator_nextbot/wraithcloaking.lua`](../../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/wraithcloaking.lua),
202 líneas— y se enciende con `ENT.IsWraith = true`. El ejemplo vivo es
`terminator_nextbot_wraith.lua`.

Qué hace al ocultarse (`:130-145`):

| Llamada | Para qué |
|---|---|
| `SetRenderMode( RENDERMODE_TRANSALPHA )` | el modo de dibujado |
| `SetMaterial( FlickerBarelyVisibleMat )` | **reemplaza el material entero** — no modula color |
| `SetCollisionGroup( COLLISION_GROUP_DEBRIS )` + `SetSolidMask( MASK_NPCSOLID_BRUSHONLY )` | atraviesa cosas, si `NotSolidWhenCloaked` |
| `AddFlags( FL_NOTARGET )` | deja de ser objetivo |

**Dos consecuencias que cambian este documento:**

**a) La reserva 3 de §3.2 pierde casi todo el filo.** Yo había marcado `$allowdiffusemodulation 0`
como riesgo para el fade *"invisible mientras se mueve"*. **La base no usa `SetColor` para eso: usa
`SetMaterial`**, o sea que **sustituye** el material de Jeff en vez de modularlo, y la bandera del
`.vmt` no interviene. El `.vmt` propio sigue haciendo falta por el `$Selfillum` (§3.2 reserva 4) y
por la colisión de rutas — **pero no por el cloak.** *Marqué un riesgo contra una técnica que la base
no usa.*

**b) El "cuándo" ya es un punto de extensión, y es justo el que necesitamos.** La línea 23 declara:

```lua
ENT.wraithTerm_CloakDecidingTask = function( self, data ) end -- override the default cloaking deciding func
```

**El Alternate no tiene que escribir el cloak: tiene que escribir esa función.** *"Invisible mientras
se moviliza, visible parado en una esquina oscura"* (§13) es exactamente lo que ese override decide.
El swap tiene un enfriamiento propio de `0,25-0,75 s`, así que no puede parpadear más rápido que eso.

> ⚠ **Ojo con `FL_NOTARGET`.** Es **la misma bandera** que §19.5 del diseño general documentó como la
> trampa de NEAD: la base la respeta en `ShouldBeEnemy` **y en el alerter**. Mientras esté encubierto
> el Alternate va a ser invisible **e inaudible** para cualquier otro bot — incluido el fantasma
> anfitrión, si termina siendo un NextBot. Acá probablemente no moleste (el Alternate es el agresor,
> no la presa), pero **no está medido** y es el tipo de cosa que muerde tarde.

### 3.4 El patrón de "manosear props" ya existe, y es lo que piden las posesiones

Buscando el paparazzi que mencionó el autor apareció algo más útil que el paparazzi. **No es un NPC
que saca fotos**: es un **prop** (`homeless_camera`, `models/maxofs2d/camera.mdl`) con un método
`TakePhoto()` —sonido `NPC_CScanner.TakePhoto`, un disparo cada 5 s, `maxPhotos` de 1 a 2 y **un 25 %
de que sea infinito**— y el bot lo usa desde **una tabla de props con probabilidad por prop**
(`terminator_nextbot_homeless/server.lua:490`):

```lua
["homeless_camera"] = { defChance = 90, func = function( ent ) ent:TakePhoto() end },
```

**Eso es exactamente la forma que necesitan las posesiones de §13** —la radio, la TV del camión, las
pantallas del equipo, los espejos del Tipo 4— que el `about.txt` ya define **con probabilidad**
(30 % la TV, 30 % las pantallas). El patrón está escrito y probado en un addon que corre; no hay que
inventarlo.

---

## 4. Las imágenes de la TV **[derivadas 2026-08-04]**

Seis PNG de 4096×4096 RGBA que trajo el autor: `alternate_1..5` son una secuencia de rostro neutro a
risa maligna, y `alternate_appear` es la silueta negra con sólo los ojos.

> **`alternate_appear` no es "una imagen suelta": es el `plain base`.** La wiki, sobre los
> Doppelgängers: *"can start off as a 'plain base' before mimicking a human; Alex Kister has stated
> that this 'plain base' is pitch dark, similar to N"*. La imagen **es** el estado sin forma tomada,
> y eso le da un momento propio: lo que se ve **antes** de que elija una cara.

**Originales** (60 MB) en `dev/alternate_src/`, fuera del árbol del addon.
**Derivadas** en `materials/phantasmagoria/alternate/`, seis PNG de **768×1024**, 4,3 MB en disco y
**18 MB en VRAM**.
**Regenerable:** [`dev/alternate_tv.py`](../dev/alternate_tv.py).

### 4.1 Por qué no se usan los originales tal cual — tres motivos, dos de ellos medidos

**a) La ruta, y es un fallo silencioso.** Llegaron a
`sound/phantasmagoria/ghost/special/alternate/alternateTV/`. La lista blanca del `.gma` sólo admite
`wav`/`mp3`/`ogg` bajo `sound/`; los `.png` sólo viven bajo `materials/`. Montado por junction anda
perfecto y **al empaquetar para el Workshop desaparecen sin un solo error** — exactamente la trampa
que [`phantasmagoria_trucktv_screen.lua`](../lua/autorun/client/phantasmagoria_trucktv_screen.lua)
documenta para los `.html`, en otro tipo de archivo.

**b) El peso.** 4096² RGBA son ~64 MB de VRAM cada uno: los seis, ~400 MB, para dibujarse en una
pantalla de **1024×593**. A 1024 de alto sobra resolución y el total cae a 18 MB.

**c) El encuadre, medido sobre el canal alfa** (umbral 8/255 — el alfa no cae a cero limpio en los
bordes, así que un `getbbox()` crudo devuelve el canvas entero y **no sirve para recortar**):

| | contenido en X | centro |
|---|---|---|
| `alternate_1..5` | 604 … 3174 | **46,1 %** |
| `alternate_appear` | 1296 … 3296 | **56,1 %** |

Los cinco rostros están registrados entre sí —sus bordes no se mueven más de 8 px sobre 4096— pero
`appear` está corrido **un 10 % del ancho**. Pegando los seis "centrados" tal cual, `appear` **salta
unos 100 px** en una pantalla de 1024, y eso se lee como error de dibujo.

Por eso el recorte **no es uno por imagen**: los cinco de la secuencia comparten un bbox **común**
(recortando cada uno con el suyo, la cabeza temblaría entre cuadro y cuadro, que es peor que el
margen que sobra) y `appear` usa el suyo.

Verticalmente no hubo nada que decidir: **en los seis el contenido llega hasta `y=4096`**, o sea el
cuello ya está al ras del borde inferior. El anclado abajo que pide el autor **sale del propio
asset**.

### 4.2 La regla de dibujado

Una sola, igual para las seis: **alto = alto de la pantalla, centrado, pegado al borde inferior**.
No hacen falta tablas de offsets por imagen. Verificado sobre un montaje a 1024×593 con ruido blanco
detrás.

No se escribe `.vmt`: un PNG bajo `materials/` se levanta con
`Material("phantasmagoria/alternate/alternate_1.png", "smooth")` para dibujarlo en 2D o dentro de un
RenderTarget, y también por `asset://garrysmod/materials/phantasmagoria/alternate/…` desde la página
del DHTML. Ninguno de los dos caminos necesita material declarado.

### 4.3 Una diferencia medida que quedó SIN resolver **[decisión de arte pendiente]**

Ancho del contenido a la misma altura, en px sobre un lienzo de 768:

| | y=15 % | y=25 % | y=35 % | y=50 % |
|---|---:|---:|---:|---:|
| `alternate_1` / `_3` / `_5` | 479 | **543** | 573 | 553 |
| `alternate_appear` | 297 | **333** | 337 | 319 |

**La cabeza de `appear` mide el 61 % de las otras cinco.** No es un defecto de la derivación: viene
así del original, porque `appear` tiene proporcionalmente más cuello y hombros. En pantalla se lee
como *"está más lejos"*.

**No se corrigió a propósito**: si `appear` es el `plain base` —otra manifestación, no el cuadro 0 de
la secuencia— la diferencia es correcta y hasta deseable. Si en cambio tiene que ser el mismo ente a
la misma distancia, el arreglo es escalar `appear` por 543/333 = **1,63×** anclado por la coronilla y
dejar que los hombros se salgan por abajo (que es donde está el borde de la pantalla, así que no se
pierde nada). **Es una decisión del autor, no técnica.**

### 4.4 Dónde se dibujan

La plomería ya existe: [`phantasmagoria_trucktv_screen.lua`](../lua/autorun/client/phantasmagoria_trucktv_screen.lua)
monta **HTML → RenderTarget → submaterial**, la pantalla se busca **por sufijo `_screen`** y no por
índice, y el material necesita **`$model 1`** o la submalla no se dibuja (sin error y sin textura
rosa).

Dos decisiones sobre eso:

- **La cara va ENCIMA del layout que esté puesto, no como un quinto layout.** Ver las barras de
  cordura del propio equipo detrás de la cara es peor que una cara limpia.
- El **ruido blanco** que pide el autor va como capa en la misma página, detrás de la imagen.

> ⚠ **Hereda un desconocido.** El convar `phantasmagoria_trucktv_flipv` existe porque la orientación
> de la V nunca se midió en juego. Una cara es el mejor instrumento posible para esa prueba: al revés
> no hay forma de dudarlo.

---

## 5. La cordura: un solo reloj, y un multiplicador de voluntariedad

**El problema.** El about le da al Alternate **seis canales** de ataque —spiritbox, paramic, la TV
del camión, las pantallas del equipo, la aparición, y tocarlo— todos a **15 %**. Con un reloj por
canal se suman y te vacían en segundos. Sin ningún reloj, peor.

### 5.1 La regla

**Un solo reloj por jugador, compartido por todos los canales.** Piso global: **25 s**.

**Por qué 25 y no otro número** — de las duraciones medidas en §2:

- Tiene que ser **mayor que el clip más largo (9,8 s)** o se pisan dos voces, y dos voces encimadas
  suenan a bug, no a fantasma. *(Con el banco de 168 el máximo subió de 7,2 a 9,8 s; los 25 s siguen
  alcanzando, pero el margen se achicó y ya no conviene bajarlos.)*
- A 25 s el audio ocupa ~25 % del tiempo: queda silencio en el medio, que es donde vive el miedo.

Y el 15 % **no es plano: es el techo**. El multiplicador es **cuánto te lo buscaste**, que es la
traducción mecánica de *"verbal information that is not desired to be known"*:

| Modo | Qué es | Daño |
|---|---|---:|
| **Forzado** | la aparición con `preacherwhispers` (§6) | **15 %**, ignora el reloj |
| **Provocado** | hablarle al spiritbox, apuntarle con la paramic, pegarle | **7,5 %** |
| **Expuesto** | la TV, las pantallas del equipo, verlo en la esquina, **quedarte a escuchar** (§7) — sólo mientras esté en tu FOV o al alcance del oído | **3,75 %** |
| **Gratis** | `biblequote_yapping`, `idle_lament`, `idle_prayer`, `hurt`, `banished` | **0** |

Encima del global, **75 s por canal**, para que no sea siempre el mismo y el jugador no aprenda a
evitar uno solo.

**La fila "Gratis" no es una excepción: es la mitad del diseño.** Son **60 de los 168 archivos** y
son los que hacen que el silencio tenga textura y que quedarse cerca no sea siempre un error.

### 5.2 ⚠ El re-escalado de 2026-08-05, y por qué había que hacerlo

**La primera versión de esta tabla estaba inflada al doble, y el error se destapó recién cuando §7
metió un segundo fantasma en el mapa.** Lo pescó el autor.

**De dónde salió.** El 15 % del `about.txt` se escribió cuando el Alternate era **lo único** que
había en la casa. Sobre ese número yo puse la aparición en **30 %** —el doble— y escalé el resto
hacia abajo desde ahí. Dos errores en la misma dirección, y ninguno se veía mientras el Alternate
fuera el único que drenaba.

**Qué pasaba al apilar** con el drenaje del fantasma anfitrión ([§19.2](PHANTOM_Phasmophobia_Diseno.md),
100 → 0 en 10-20 min):

| | %/s | 100 → 0 |
|---|---:|---:|
| Alternate pasivo, tabla vieja (7,5 % / 25 s) | 0,300 | 5:33 |
| Fantasma anfitrión (15 min) | 0,111 | 15:00 |
| **Los dos a la vez** | **0,411** | **4:03** |

**En cuatro minutos no se identifica un fantasma, no se descubre que hay un Alternate y no se caza
una ventana de rezo con el crucifijo en la mano.** Las tres cosas que §10 pide que pasen no entraban.

**El arreglo son dos piezas**, y la primera está en §5.5.

### 5.3 Qué da la tabla nueva

Sin apilar (por §5.5), y con 25 s de reloj:

| Conducta | Tiempo a cordura 0 |
|---|---|
| Exposición **pasiva** continua | **11 min 07 s** |
| **Provocándolo** sin parar | **5 min 33 s** |
| Línea base del juego, sin Alternate | 10-20 min |

**El Alternate ya no suma drenaje: lo reemplaza**, y sólo castiga al que se engancha.

Una partida de 15 min jugada con cuidado, con tres apariciones: ~53 % gastado en exposición
intermitente y **45 % en las tres apariciones**. O sea que **lo que de verdad te mata pasa a ser el
momento de seis segundos sin control**, que es donde tiene que estar el peso. Con la tabla vieja,
tres apariciones se comían el 90 % ellas solas y el resto del diseño era decorado.

### 5.4 Cadencia de la aparición, ahora que pesa 15 %

Sigue siendo **una cada 4-5 min como techo** (§6). Con 15 % eso son ~45-60 % de la barra por partida
larga: suficiente para que se le tenga miedo, no tanto como para que no haya partida.

### 5.5 Supresión — mientras el Alternate está, la casa se calla **[nuevo, 2026-08-05]**

La segunda pieza del arreglo, y **no es un parche de balance: sale del propio banco de voces.**

El Alternate es **hostil al fantasma de la casa**. Las 62 líneas de §7 son burlas, insultos y envidia
en su cara. Dos entidades que se detestan no se reparten la casa en paz.

**Regla: mientras el Alternate está activo, el fantasma anfitrión se calla.** No hace eventos, no
drena cordura, **y no caza**.

Tres cosas se arreglan de un saque:

1. **El drenaje deja de apilarse.** Es lo que hace que los números de §5.3 cierren.
2. **Dos fantasmas cazándote a la vez sería ilegible.** Nadie puede jugar contra dos relojes de
   cacería que no ve. Esto lo cancela sin una regla ad-hoc.
3. **El silencio se vuelve el aviso.** Si la casa se queda muda —sin eventos, sin actividad en el
   monitor del camión— **el Alternate está acá.** Eso mecaniza la fase 0 de §10, que hasta ahora
   dependía sólo de que alguien oyera el monólogo bíblico de lejos.

> **Y el cambio NO es un alivio, aunque los números se parezcan.** El jugador pierde una amenaza
> **conocida** —el fantasma normal, con sus escondites, su umbral de cordura y su reloj de cacería—
> y recibe una que no sabe leer. Cambiar lo legible por lo ilegible es un empeoramiento aunque el
> drenaje por segundo sea el mismo.

**Lo que NO se suprime:** las evidencias del anfitrión. Las huellas ya puestas, la escritura ya
escrita y la temperatura siguen ahí. El contrato se puede seguir resolviendo — lo que se detiene es
la actividad, no el rastro. Si se suprimieran las evidencias, el Alternate volvería imposible la
partida en vez de difícil.

### 5.6 El "taparse los oídos" SÍ existe, y es el equipamiento

El autor anotó que la contra del lore —no verlo ni oírlo— *"como gameplay loop no es posible, porque
no hay manera de ignorar o taparse los oídos"*.

**Sí la hay: el equipamiento es los oídos.** Apagar el spiritbox, bajar la paramic, no pararse
delante de la TV, no mirar la esquina, **irse de la conversación** (§7). Ignorarlo es un verbo que
GMod ya tiene y que el jugador ya está ejecutando por otros motivos; el multiplicador de §5.1 sólo lo
hace **pagar**.

### 5.7 El silencio tiene que sonar

`biblequote_yapping` (14 piezas, mediana 21,1 s, **daño 0**) suena **durante el cooldown**. Sin eso,
25 s de nada se leen como que el fantasma se fue, y el jugador vuelve a hacer justo lo que lo estaba
matando sin sentir que decidió nada.

---

## 6. La aparición y la parálisis **[duración medida, forma propuesta]**

`preacherwhispers` dura **6,0 s exactos**. La duración no hay que elegirla: está en el archivo.

> **Esta escena es de una clase concreta.** *The Preacher* es un **Flawed Impersonator (Tipo 3)**
> (§11), y el rasgo de esa clase —*no puede engañar con sutileza, así que recurre al acoso directo*—
> describe exactamente lo que pasa acá: se muestra entero, corre hacia vos y te habla encima.

Pero 6 s de input bloqueado en primera persona es muchísimo, y en Garry's Mod la gente va a creer
que se colgó el juego. La forma:

| Tramo | Qué pasa |
|---|---|
| **0,0 – 0,8 s** | la cámara se va sola hacia él por **lerp**, el movimiento sigue siendo del jugador. Se siente como que **te agarra**. |
| **0,8 – 5,0 s** | bloqueo real. **No se rompe** — decisión del autor, y es fiel: a un Alternate no se le escapa. |
| **~4,5 s** | **desaparece mientras el audio sigue sonando.** |
| **5,0 – 6,0 s** | el control vuelve de a poco mientras la voz se apaga. |

**Que desaparezca durante el audio y no después** es la decisión que más rinde: recuperar el control
mirando un pasillo vacío es más barato de implementar y bastante más efectivo que animar una
desaparición.

**El golpe del 30 % se aplica al TERMINAR el audio, no al empezar.** Quien muera ahí muere en el
instante en que los susurros paran, y eso se lee como causado en vez de como azar.

**Cadencia:** una vez cada 4-5 min como techo, y **nunca dos seguidas al mismo jugador** si hay
varios.

---

## 7. El otro fantasma — el Alternate como fuente de información **[nuevo, 2026-08-05]**

### 7.1 El banco impone una premisa, y hay que aceptarla

Hay **62 líneas** dirigidas a otro fantasma. Eso no es un detalle de sabor: **obliga a que el
Alternate NO sea el fantasma del contrato.** Es un intruso que aparece en una casa que ya tiene
dueño, y se dedica a hostigar a los dos: a vos y al de la casa.

Eso arregla, de paso, el problema abierto de *"cómo entra al juego"*: no reemplaza el sorteo de los
30 tipos, **se suma**. La partida sigue teniendo su fantasma normal, con sus evidencias y su
identificación. El Alternate entra encima.

### 7.2 La mecánica: **no te lo dice a vos — se lo dice al otro, y vos escuchás**

Esta es la decisión central de la sección, y de ella cuelga todo lo demás.

El Alternate **no le habla al jugador** cuando habla de fantasmas: **se burla del otro fantasma en su
cara**. El jugador está **espiando una conversación ajena**.

Eso resuelve el problema que hundiría la mecánica si fuera al revés. Un Alternate es, por lore, un
**mentiroso**: si te dijera a vos qué fantasma hay, no le podrías creer, y una pista en la que no se
puede confiar y que además cuesta cordura es una pista que nadie va a usar. **Pero no tiene ningún
motivo para mentirle a un fantasma sobre lo que ese fantasma es.** Le está restregando su naturaleza.
Por eso lo que decís de él es cierto — y por eso es cierto **sin volverlo honesto**.

**Y entonces la información se vuelve el dilema.** Lo que el jugador más necesita —qué fantasma hay—
está en la boca de la cosa que lo está matando por escucharla. Eso es M.A.D. convertido en decisión
de juego: *verbal information that is not desired to be known*, sólo que sí la deseás, y ahí está la
trampa.

### 7.3 Qué se puede aprender **[transcrito 2026-08-05]**

**7 de los 30 tipos tienen voz propia.** Verificado contra las claves de
`lua/phantasmagoria/ghost_types.lua`: `demon`, `goryo`, `jinn`, `oni`, `poltergeist`, `shade`,
`yokai` **existen los siete, escritos igual**. Los otros **23 caen al banco genérico**.

#### ⚠ Corrección: no dice el nombre — dice una adivinanza

**Lo que este documento decía era falso.** Decía que una línea específica te daba *"el tipo, servido —
se salta media investigación"*. **No.** Transcritos los 168 archivos, el Alternate **casi nunca
pronuncia el nombre del tipo**: habla de la **etimología y el folklore del nombre**, que es lo lógico
—se está burlando de cómo lo llamaron, no informando a nadie.

| Pool | Lo que realmente dice | La pista |
|---|---|---|
| `poltergeist` | *"German, noisy ghost. They ran out of language entirely, and just described the sound"* | la etimología literal |
| `oni` | *"They threw beans at you, once a year, and you left"* | **Setsubun**, la fiesta japonesa de tirar porotos para echar a los oni |
| `jinn` | *"[Made of] smokeless fire, in form of clay. That is my living image, not yours"* | el Corán: los jinn de fuego sin humo, los humanos de barro — **y de paso es el tema de la envidia** |
| `goryo` | *"A noble, who hides badly… They built you a shrine to make you stop"* | los goryō son nobles vengativos que se apaciguan con santuarios |
| `yokai` | *"[Yokai] is not a species. It is a shrug. It means we do not know what that was"* | exacto, y es la mejor línea del set |
| `shade` | *"Shade… That is [a name] for a bad Roman, and they gave it to a shy one"* | umbra / shade |

**Eso mejora el diseño en vez de romperlo.** La información **no viene servida: viene cifrada**, y
descifrarla pide que el jugador sepa algo, lo busque, o lo discuta con el equipo. Deja de ser un
atajo que trivializa la identificación y pasa a ser una **pista que hay que trabajar** — y en
multijugador, una conversación de verdad entre jugadores.

Y el pool genérico se explica solo. Una de sus 25 líneas dice:

> *"There is no name for you in any of the books I must read."*

**El genérico es el Alternate admitiendo que a ése no lo reconoce.** No es un resultado nulo: es un
negativo con voz.

> ⚠ **Y esto casi se pierde por creerle al instrumento.** El primer conteo automático buscó los 30
> nombres de tipo en las transcripciones y encontró **5 de 37** — con lo que la mecánica entera
> parecía muerta. Era **Whisper destrozando nombres propios**: `Goryo` salió `Morio`, `Jinn` salió
> `JID`, `Yokai` salió `Yaka`. Son justo las palabras que un ASR falla —raras, no inglesas, y encima
> dichas por SAM. **La conclusión correcta no estaba en el conteo sino en leer el texto**, que estaba
> lleno de identificación. Un grep sobre una transcripción automática mide dos cosas a la vez, y una
> es el transcriptor.

#### El resumen

| Al escuchar | El jugador se lleva |
|---|---|
| línea específica (37 archivos) | **una adivinanza cuya respuesta es el tipo** |
| línea genérica (25 archivos) | que el Alternate **tampoco lo reconoce**, y pagó igual |

Que sea una apuesta y no una recompensa es lo que la hace jugable: 23 de 30 partidas la conversación
no te da un tipo, así que escucharla nunca es "lo obvio".

**Y el tell de §2.1(d) es la textura fina:** toda línea de **más de 9,8 s nombra a alguien**, pero
**25 de las 37 específicas son indistinguibles por duración**. El jugador veterano va a aprender que
*"si sigue hablando, está nombrando"* — y va a tener razón lo suficiente para confiar, y se va a
equivocar lo suficiente para que no sea un semáforo.

### 7.4 El tono es información también

El autor escribió cada pool con una actitud distinta, y eso es contenido que el jugador puede leer
antes de entender las palabras:

| Pool | Actitud | Lo que delata |
|---|---|---|
| `goryo` | **respeto** — le reconoce el título nobiliario | es el **único** que trata bien a alguien. Oír al Alternate ser cortés es información por sí solo |
| `demon` | insulto: el nombre le queda grande, y lamenta que no sea de los suyos | 10 líneas, las más cortas del set específico |
| `oni`, `jinn`, `yokai` | ironía: son **nombres prestados**, no son eso de verdad | los tres pools más largos |
| `poltergeist` | menosprecio directo | |
| `shade` | *"fantasma con nombre de romano cobarde"* | |

**El envidia lo que el otro fue.** El genérico son burlas ontológicas, insultos, y el reproche de que
el otro no puede volver a habitar el cuerpo que perdió. El Alternate le echa en cara al fantasma
haber sido humano — que es exactamente lo que él nunca fue y lo que §8 explica que le duele.

### 7.5 Cuánto cuesta y cómo se llega

- **Escuchar es `Expuesto` (×0,5 = 7,5 %)**, no `Provocado`: no lo buscaste, te quedaste. La decisión
  no es "activarlo", es **no irte**.
- **La paramic lo trae desde lejos** — y eso es `Provocado` (×1,0 = 15 %). Queda un intercambio
  limpio: **cerca es barato en cordura y caro en riesgo; lejos con la paramic es seguro y cuesta el
  doble.**
- **En multijugador hay un rol nuevo**: alguien se banca la cordura para traerle el dato al equipo.
  El evento es del mundo, así que lo oye el que está cerca — no todos.

---

## 8. La ventana — rezo, lamento y el destierro **[nuevo, 2026-08-05]**

### 8.1 Los dos idles no son ambiente: son un estado

`idle_lament` (13) *"habla solo a su yo y lamenta la caída"*. `idle_prayer` (10) *"le habla directo a
Dios y pide respuestas o perdón"*.

Son **los únicos momentos en que el Alternate no está atacando a nadie**. Y el segundo es más que
eso: **es el único momento en que quiere algo que no puede tomar.**

### 8.2 La regla: el crucifijo sólo destierra durante el rezo

| Estado | Qué hace el crucifijo |
|---|---|
| cualquier otro | **lo degrada**: lo saca de manifestado y lo devuelve a invisible-merodeando (§12). Se consume |
| **durante `idle_prayer`** | **lo destierra.** Se acabó |

**El lore lo justifica sin forzar nada.** Es un ángel caído pidiendo perdón. En ese instante —y sólo
en ese— el símbolo no es un objeto que odia: es lo que está pidiendo. Por eso tiene poder sobre él
justo ahí, y por eso el resto del tiempo apenas lo espanta.

`idle_lament` **no** abre la ventana. Se lamenta consigo mismo, no pide nada. Es la pista falsa
honesta: suena parecido, no sirve, y aprender a distinguirlos **es** la habilidad que la mecánica
enseña.

### 8.3 La ventana dura seis segundos, y es el mismo seis

`idle_prayer`: mediana **5,9 s**, máximo 8,1 s. `preacherwhispers`: **6,0 s**.

**Él tiene seis segundos tuyos, vos tenés seis segundos suyos.** No lo elegí: estaba en el disco.

Seis segundos es poquísimo si tenés que cruzar la casa, y por eso la ventana no puede ser el único
camino: tiene que **repetirse**. El rezo entra en la rotación de idles, no es un evento raro. Lo
difícil no es que aparezca — es **estar cerca cuando aparece, con el crucifijo, y sin haberte quedado
sin cordura escuchándolo**.

### 8.4 El nudo: el instrumento que te mata es el que te salva

La paramic es cómo escuchás el rezo desde lejos. La paramic es `Provocado` (×1,0). Y quedarte cerca
para oírlo sin ella es `Expuesto` (×0,5) pero con el cuerpo a tiro.

**No hay una forma barata de saber cuándo está rezando.** Es la misma tensión de §7 en otro eje, y
las dos se resuelven con la misma decisión del jugador: *cuánto estoy dispuesto a escuchar*.

### 8.5 `banished` — la puntuación

Dos archivos, **1,3 y 1,4 s**. *"Un simple Oooh o no…"*, en palabras del autor.

Que sea **corto** después de todo lo anterior es lo que lo hace funcionar: veinte minutos de discurso
y se va con una sílaba. **Es el único sonido del banco que significa que ganaste**, y por eso no
debería sonar en ningún otro contexto — ni de prueba, ni de teaser, ni de susto.

Sirve igual para el **Summoning Circle invertido** (§12): completar el círculo durante un rezo cierra
el mismo camino sin gastar crucifijo, para quien prefiera el ritual.

---

## 9. El Principio T.H.I.N.K. — el manual del juego, y es canon **[aportado por el autor 2026-08-05]**

> **Fuente:** *The THINK Principle*, episodio no listado de The Mandela Catalogue y primer video de la
> playlist `ORIGINAL_COPIES`. Son dos cintas VHS de transmisiones de emergencia del ficticio
> **United States Department of Temporal Phenomena**, hechas para instruir a la población sobre los
> Alternates. Texto aportado por el autor desde la wiki.

### 9.1 Cada letra ya es una mecánica de este addon

Esto no es una capa de sabor que se le pega al diseño. **Es el manual, y las cinco entradas ya
existían acá antes de conocerlo:**

| Letra | Canon | Lo que ya estaba diseñado |
|---|---|---|
| **T**ELL an authority figure about your encounter | avisá | el camión, el equipo; en multijugador el que escucha le trae el dato a los demás (§7.5) |
| **H**INDER the alternate's movement | frenalo | **`about.txt` del autor**: *"dispararle lo ralentiza a un mero demonio por unos 15 segundos"*. Es la misma frase |
| **I**DENTIFY the class type | qué **clase** es | §7 y §11 — y ojo que es *class type*, no el tipo de fantasma: es Tipo 1 / 2 / 3 |
| **N**EUTRALIZE the alternate **(if safe to do so)** | eliminalo | el crucifijo (§12). **Y "si es seguro" es literalmente la ventana de rezo de §8** |
| **K**NOW YOUR PLACE in reality | tu lugar en lo real | la cordura (§5) |

**La convergencia con el `about.txt` del autor llega hasta la última imagen de la cinta:** termina con
*"a tall, entirely black alternate standing in the corner, staring"*. El about, escrito aparte, pide
que **se esconda en esquinas oscuras y ahí sea visible mientras observa**. Y `alternate_appear.png`
(§4) **es esa imagen**.

### 9.2 La tarjeta va en el camión, y la trae la radio que él ya posee

El principio tiene que ser **guía real y funcional dentro del juego**, no un póster. Es el nombre en
ficción de las reglas que el addon ya tiene, y por eso el jugador lo aprende **porque le sirve**.

Y el vehículo ya está en disco: `event_creepy_eas_paranormal_radio_advise.ogg`, el evento de radio
formato **Emergency Alert** que —según el `about.txt`— **el Alternate posee**.

> **Ahí está el nudo, y es canon puro:** la transmisión de emergencia que existe para salvarte es la
> que él controla.

### 9.3 La K, y por qué la versión canónica es mejor que la que tenemos grabada

En la cinta, el pase de diapositiva a la K **corta la música**, y la pantalla dice:

> **KILL YOURSELF** — *there's not enough room for the two of us*

Estática. Y vuelve a la diapositiva original, con la música:

> **KNOW YOUR PLACE** — *in reality*

**El original ya trae las dos versiones y ya trae la elegancia que buscábamos.** La segunda mitad
—*"there's not enough room for the two of us"*— es **el argumento del Alternate**: quiere tu lugar.
Sin ella queda un insulto de internet; con ella queda una criatura explicando qué vino a hacer.

**Y eso reencuadra las ocho grabadas.** `sanity_strong_attack_1` y `_8` son *"Kill yourself!"*
repetido — o sea **la línea del canon con la mitad buena arrancada**. No hay que escribir nada mejor:
hay que **dejar de recortarla**.

### 9.4 Los dos tiers salen de la cinta, sin inventar nada

| Tier | Qué hace | Qué se ve/oye |
|---|---|---|
| **Por defecto** | la transmisión llega a la K, **la música se corta**, estática — y vuelve con **KNOW YOUR PLACE in reality** | no se dice nada explícito. El corte está, el hueco está, y **el jugador lo llena solo** |
| **Opt-in** | el mismo pase, con la diapositiva corrupta **completa** — la frase entera, no las dos palabras | |

**El tier por defecto no es una versión aguada: es la propia cinta.** El original muestra la
corrupción *y después* la corrige, así que quitar el cuadro corrupto deja una transmisión que
tartamudea exactamente donde el jugador va a notar que falta algo. Es más inquietante y no hay nada
que sacar de contexto.

### 9.5 IDENTIFY the class type — una mecánica que no teníamos

La cinta 2 cierra con **KNOW YOUR ENEMY** y enumera **tres clases**. **La taxonomía del autor tiene
cuatro** (§11), y esa diferencia es una escena, no un error → §11.3.

Lo que enumera **la tarjeta**:

| Clase, según la cinta | Cómo la ilustra |
|---|---|
| **Tipo 1 — Doppelgänger** | dos personas casi idénticas |
| **Tipo 2 — Detectable** | el ángel Gabriel, y el Alternate de Gabriel |
| **Tipo 3** | deformados junto a quien copian |

**"IDENTIFY the class type" es un segundo bucle de identificación**, en paralelo al de los 30 tipos de
fantasma: el jugador tiene que averiguar **con qué clase de Alternate está**. Falta decidir qué lo
distingue en juego y qué se hace distinto con cada uno.

⚠ **Y la tarjeta se queda corta a propósito** — la taxonomía real tiene cuatro. Eso es material de
juego, no un error de este documento: **§11.3**.

### 9.6 Lo que la cinta 1 autoriza, y viene bien

El comunicado dice tener *"a loaded firearm or any ranged weapon at all times"*, y —textual—
*"while we heavily discourage any form of contact or communication with an Alternate, **we make
exceptions at attempts at executing them yourself**"*.

**Dispararle está sancionado por la autoridad en ficción.** En un addon de Garry's Mod, donde el
jugador va a disparar igual, tener el permiso escrito en el canon resuelve solo el problema de por
qué el arma está ahí — y §12 ya dice que no lo mata, sólo lo frena. Que es **HINDER**.

---

## 10. El arco de una partida

Las cinco fases, y qué banco las sostiene. Ninguna necesita HUD: **todo el estado del Alternate se
comunica por audio.**

| Fase | Qué siente el jugador | Banco |
|---|---|---|
| **0. No sabés que está** | **La casa se apaga** (§5.5): el fantasma del contrato deja de dar eventos y el monitor de actividad del camión se va a cero. Y de a ratos, un monólogo bíblico larguísimo desde un pasillo vacío. Sin EMF, sin nada en el equipo | `biblequote_yapping` (4,5 min) |
| **1. Son dos** | Escuchás una conversación que no es con vos. **Ahí se entiende que el fantasma del contrato no es lo único que hay.** Y si la línea es larga, además te enteraste de qué es el otro | `sayto_ghost*` (62) |
| **2. Te estudia** | Aparece en esquinas oscuras y te mira. Dice "acá" desde donde no está. *"I see you"*. No ataca todavía — el about lo pide explícitamente | `watching_player`, `here` |
| **3. Te desgasta** | El reloj de §5. Spiritbox, paramic, la TV, las pantallas | `sanity_attack` (30), `sanity_strong_attack` (8) |
| **4. Te agarra** | La aparición. Seis segundos sin control | `preacherwhispers` |
| **5. Te caza** | Cacería al 50 %, velocidad de revenant, detecta escondidos | `hunt_loop`, `hunt_loop_long` |

Y **cruzando todas**, dos hilos que maneja el jugador:

- **Averiguar qué fantasma hay** — el Alternate es un atajo que cobra cordura (§7).
- **Cazar la ventana de rezo** — el único final que no es morir o huir (§8).

**El antagonista es al mismo tiempo el obstáculo, el sistema de pistas y la condición de victoria.**
Ahí está el loop, y sale entero del banco de voces.

> **Lo que hay que cuidar:** las fases 0 y 1 son **lentas a propósito** y es donde el diseño se puede
> caer. Si el jugador llega a la fase 3 sin haber pasado por la 0, el Alternate es un fantasma más
> que grita. **El monólogo bíblico lejano es la fase que hace que todo lo demás signifique algo**, y
> es justo la que va a dar ganas de acortar cuando se pruebe en juego.

---

## 11. Las cuatro clases **[taxonomía del autor, 2026-08-05]**

**Los cuatro hacen M.A.D.** La clase no dice *si* te ataca la cordura: dice **cómo se acerca**. Por
eso *IDENTIFY the class type* (§9) es una pregunta con consecuencias y no una etiqueta.

| # | Clase | Qué es | Cómo se delata |
|---|---|---|---|
| **1** | **Doppelgänger** | copia a su víctima. **Sin presencia física real** | anomalías sutiles: **expresión facial fija**, **parpadeo incorrecto**, deformaciones apenas perceptibles |
| **2** | **Unspeakable** (ángel caído, Satán/Lucifer) | no necesita esconderse ni imitar. Manipulación a gran escala, la fe, la corrupción histórica. **Puede crear otros alternos.** **El único que ataca directamente más allá del M.A.D.**, se manifiesta físicamente, supuestamente omnipotente | no se delata: no le hace falta |
| **3** | **Flawed Impersonator** | transformación **fallida o interrumpida**. Violento y visualmente aterrador. Al no poder engañar, va al **acoso directo y la guerra psicológica masiva** | **anatomía imposible**: extremidades larguísimas, rostros vacíos sin ojos ni boca, proporciones invertidas. **N** y **The Preacher** son de acá |
| **4** | **Tulpa** | creado por la **imaginación de un individuo**, en general un niño, tras consumir multimedia corrupto | **se mueve por superficies reflectantes, espejos y pantallas de TV.** *El Intruso* es uno |

### 11.1 ⚠ Lo de los flexes estaba mal planteado — y se invierte

Este documento venía diciendo que **Jeff sin flexes** (§3.2) era un problema para la variante
impostora. **No lo es, y en un caso es exactamente al revés.**

| Clase | El tell **real** | Qué necesita en el motor |
|---|---|---|
| **1 Doppelgänger** | *"expresión facial fija, parpadeo incorrecto"* | **cero flexes.** Una cara que no se mueve nunca y no parpadea **es** el tell. No hay que deformar nada: hay que **congelar** |
| **3 Flawed Impersonator** | *"extremidades exageradamente largas, proporciones invertidas"* | **manipulación de HUESOS**, no de flexes: `ManipulateBoneScale` / `ManipulateBonePosition` sobre los **53 huesos ValveBiped** que Jeff sí tiene (§3.1) |

**Ninguna de las dos pedía flexes.** Yo había leído "cara deformada" y salté a los morphs; el canon
que aportó el autor dice **proporciones**, que es el esqueleto.

Y eso **mata la advertencia** que este documento traía: decía que un jugador con un modelo sin flexes
—robots, anime, ports— recibiría un impostor perfecto sin pista. **Falso.** Congelar la expresión y
suprimir el parpadeo funciona en **cualquier** modelo, porque es quitar movimiento, no agregarlo. Y
alargar huesos funciona en cualquier rig humanoide.

> Lo que sí sigue valiendo del párrafo viejo: **la segunda pata del tell tiene que ser de
> comportamiento** —el andar, la distancia a la que se queda, que **no responde** si le hablás— para
> que quien no mire de cerca tenga otra forma de darse cuenta.

### 11.2 Dónde encaja cada clase en lo que ya está diseñado

| Ya diseñado | De qué clase es en realidad |
|---|---|
| La aparición con `preacherwhispers` y la parálisis (§6) | **Tipo 3.** *The Preacher* es un Flawed Impersonator, y "no puede engañar, así que acosa de frente" es literalmente esa escena |
| La posesión de la TV del camión y de las pantallas del equipo (§4) | **Tipo 4.** No es un truco de fantasma: **es cómo se desplaza un Tulpa** |
| *"No destierra, mata directamente"* + la cacería (§13) | **Tipo 2.** El único que ataca más allá del M.A.D. |
| El que se pasea de lejos con el playermodel de un jugador | **Tipo 1** |

**La posesión de pantallas deja de ser un adorno.** El `about.txt` la daba al 30 % como una gracia; con
la clase 4 encima, **las pantallas son su medio de transporte**, y eso vuelve coherente todo el
trabajo de §4. Además el addon ya tiene la otra superficie: el **espejo maldito**
([`phantasmagoria_mirror.lua`](../lua/autorun/client/phantasmagoria_mirror.lua)) ya dibuja un feed en
vivo sobre un vidrio con `PHANTASMAGORIA.DrawMirrorView( pos, yaw, fov )`. Una cara en ese feed no
necesita código nuevo: necesita **decidir qué posición se le pasa**.

### 11.3 El manual está incompleto, y eso es una escena

La tarjeta T.H.I.N.K. enumera **tres** clases (§9.5). Acá hay **cuatro**.

**No es una contradicción del canon: es caracterización, y la cinta lo admite sola.** Abre con
*"until we have a complete understanding of the threat"*. El USDTP publicó su manual con información
incompleta.

Cómo mapean las tres de la cinta contra estas cuatro no está cerrado —*Type Two: Detectable* es
**probablemente** el Unspeakable, por el ejemplo del ángel Gabriel, pero **eso es inferencia mía y no
está confirmado**. Lo que sí es robusto: **el Tulpa no está en la tarjeta**, se lo mire como se lo
mire.

> **Y el Tulpa es justo el que viaja por pantallas.** O sea: **la clase de la que el manual no te
> avisa es la única que puede alcanzarte adentro del camión.** El jugador estudia la tarjeta, aprende
> las tres, se mete en la zona segura — y llega la cuarta por el monitor.
>
> Eso no hay que construirlo: sale de cruzar la tarjeta con la taxonomía. Sólo hay que **no arreglar**
> la tarjeta.

### 11.4 Una clase por partida, y cada una es otro juego **[decisión del autor, 2026-08-05]**

**Aparece UNA sola al empezar**, y puede ser cualquiera de las cuatro. Tener un **Tipo 2** es lo más
peligroso que puede pasar.

Cada clase trae su **vector de daño** y su **contra**, y ésa es la prueba que la taxonomía pasa: no
son cuatro skins del mismo enemigo.

| Clase | Cómo hace daño | Cómo se la saca de encima |
|---|---|---|
| **1 Doppelgänger** | copia; sin presencia física real | **crucifijo, directo** |
| **2 Unspeakable** | M.A.D. por voz **+ ataque directo**; el único que mata por sí mismo | **ritual + crucifijo** — se lo expulsa del mapa, no se lo elimina |
| **3 Flawed Impersonator** | acoso directo, guerra psicológica masiva. **Habla con el banco del Tipo 2** por la colmena (§11.5) además de su registro gutural | **crucifijo, directo** |
| **4 Tulpa** | **daña a quien tenga pantallas o espejos** | **crucifijo, directo** |

**El crucifijo mata a tres de las cuatro. Sólo el Tipo 2 pide ritual**, y eso deja el diseño más
prolijo de lo que estaba: la **ventana de rezo** de §8 deja de ser una regla general y pasa a ser
**la mecánica del Tipo 2, y de nadie más**. Lo cual es coherente solo, porque `idle_prayer` es **una
voz del Tipo 2** (§11.5).

**El Tipo 2 invoca alternos extra, y la cantidad la fija la dificultad: 1 normalmente, 2 sólo en la
máxima.** Una vez sola, y con demora.

> El tope duro está bien puesto, y el razonamiento del autor también: **el Tipo 2 ya no se queda
> quieto**, y encima está el fantasma anfitrión. Tres entidades activas en una casa es el techo de
> lo que un equipo puede leer; la cuarta no agrega miedo, agrega ruido.

#### El Tipo 4 en el camión

Llegar al camión **no es que te mate ahí**: es que **toma las pantallas por un rato**, y hay una
**ventana diminuta para salir** antes de que el daño entre.

> **Eso protege la victoria por retirada de §12 en vez de romperla.** El camión no deja de ser
> seguro: deja de serlo **por un rato**, y te avisa. Si el Tulpa pudiera matar adentro, la única
> condición de victoria que no depende de matar nada se caería, y con ella el final del arco de §10.

### 11.5 ⚠ El problema de cobertura: los 168 archivos son la voz de UNA clase

**El autor confirma que el banco entero es la voz del Tipo 2** (los Unspeakable / ángeles caídos), y
que el Tipo 2 **comanda a las otras clases con mente de colmena, haciéndolas hablar y dañar con
M.A.D.**

Eso es coherente y explica el contenido —el reproche a Dios, el lamento por la caída, la envidia de
lo humano son de un ángel caído, no de un tulpa infantil— **pero deja un agujero de contenido que hay
que ver antes de escribir código:**

| Clase | Audio propio disponible |
|---|---|
| **2 Unspeakable** | **168 archivos, 20,2 min** |
| **3 Flawed Impersonator** | `preacherwhispers` (1). El autor lo describe como **gutural** — *The Preacher* es de esta clase |
| **1 Doppelgänger** | **copia voces** — no tiene banco propio (§11.6) |
| **4 Tulpa** | **nada** |

**Con una clase por partida, el banco de 20 minutos suena en 1 de cada 4 partidas.** Y una partida de
Tipo 4 sola se queda sin `sayto_ghost` (§7), sin `idle_prayer` (§8) y sin `biblequote_yapping` (§10,
fase 0): **el arco entero que este documento diseñó no ocurre**.

Eso no está mal *por definición* —un Alternate mudo que sólo vive en las pantallas da miedo, y su
vector de daño y su contra existen igual— pero **hay que decidirlo a propósito y no descubrirlo en
juego**.

#### La salida que no cuesta nada, y usa lo que el autor ya dijo

**La mente de colmena no exige que el Tipo 2 esté en el mapa.** Si comanda desde afuera, entonces
**las voces suenan siempre, en cualquier partida**, salgan por la boca de la clase que salga — y el
Tipo 2 **presente en persona** pasa a ser la escalada, no la condición para que haya audio.

Con eso: los 168 archivos se usan en las cuatro partidas, cada clase conserva su vector y su contra,
y *"tener un Tipo 2 es lo más peligroso"* sigue siendo cierto. **Es un cambio de encuadre, no de
mecánica.** Queda **propuesto, sin ratificar**.

### 11.6 La voz del Tipo 1: no copiar el micrófono **[recomendación]**

El autor plantea que el Tipo 1 copia voces, y duda de cómo: micrófono del jugador, TFA Vox, *"no
todos hablan desde el juego"*. La duda está bien puesta y **las dos opciones obvias son las malas**:

- **El micrófono del jugador** — grabar y reproducir la voz de una persona real en un servidor
  público es un problema aparte del diseño, y encima **falla justo con quien no usa micrófono**, que
  es mucha gente.
- **TFA Vox** — es una dependencia que no todos tienen. El jugador sin el mod recibe un Doppelgänger
  mudo y **no tiene forma de saber que el juego le sacó la pista**. Es el mismo error que §11.1
  acaba de corregir con los flexes, en otro eje.

**La opción que funciona para todos: que copie los sonidos que el jugador ya hace.** Pasos,
el clic de la linterna, el pitido del EMF, la cámara. Existen **para todo jugador**, sin mod y sin
micrófono.

> **Y es más perturbador que una voz.** Escuchar *tu propio EMF* pitando en un cuarto donde no
> estás no se puede confundir con nada, y no necesita que nadie diga una palabra. El Tipo 1 no
> presume de imitar: se delata siendo **casi** correcto, que es exactamente lo que la clase es.

### 11.7 El audio del Tipo 4 — y la señal musical es la ventana **[decisión del autor, 2026-08-05]**

El Tulpa **no usa el banco del Tipo 2**: lleva voz propia, y el autor la va a grabar aparte —**otro
registro** (susurro, teléfono), palabras **inteligibles pero extrañas**, no el mismo timbre de SAM.

Y arriba de eso, **una señal musical al tomar las pantallas**. Esa decisión es la más importante de
la clase, y conviene entender por qué:

> **La música no es ambientación: es el temporizador.** §11.4 dice que llegar al camión le da al
> jugador *"una ventana diminuta para salir antes de que el daño entre"*. **Esa ventana es la
> señal.** Mientras suena, se puede salir. Cuando termina, no.
>
> En palabras del autor: *"la idea es generar un cue de música o sonido para asustar y darle tiempo
> al jugador para evitar los daños, no solamente lo visual"*. Es decir: la clase que ataca por la
> vista **avisa por el oído**, y eso resuelve solo el problema de que un jugador mirando para otro
> lado no tendría forma de enterarse.

Que el temporizador sea **audible y de duración fija** también lo hace aprendible: a la segunda
partida el jugador sabe cuánto le queda sin mirar ningún HUD.

#### La grabación: Alessandro Moreschi

La referencia del video del Intruso es —confirmado por el autor— **Alessandro Moreschi**, *"el último
castrato"*, y la pieza es el **Ave María de Bach/Gounod**. Grabado en el Vaticano entre **1902 y
1904**; es el único castrato del que se conservan registros.

**Y funciona por un motivo que no es casualidad.** Es la única voz sobreviviente de una práctica que
convertía a una persona en otra cosa: algo casi humano, hecho mal, que no debería existir. Es la
tesis del Alternate, grabada de verdad. Además el soporte acústico de 1902 —el temblor, la
saturación, el ruido de superficie— **ya es analog horror por su propia edad**, sin filtro encima.

> **Licencia — la rareza de este proyecto: no hay ninguna pregunta.** Una grabación de 1902-1904 es
> **dominio público** por antigüedad (en EE. UU. los registros previos a 1923 entraron al dominio
> público el 1 de enero de 2022 por la Music Modernization Act; en la UE el plazo de 50 años venció
> hace décadas). Sería de los **poquísimos** assets de audio del addon sin nada que acreditar ni que
> pedir.
>
> ⚠ **La única trampa: usar una transferencia limpia, no un remaster moderno.** La grabación es
> libre; **una restauración reciente puede reclamar derechos propios sobre esa versión**. Bajarla del
> primer video que aparezca es exactamente cómo se hereda un problema que el original no tiene.

---

## 12. Cómo se lo enfrenta **[ratificado por el autor, 2026-08-04]**

**El verbo no es matar: es degradar.** Y no es un invento — ya estaba en el about del autor:
dispararle *"lo ralentiza a un mero demonio por unos 15 segundos"*. Eso no es daño, es **cambio de
estado**, y es un verbo mucho mejor que la muerte para esta criatura.

| Acción | Qué hace | Qué cuesta |
|---|---|---|
| **Dispararle** | lo ralentiza 15 s, y **te contesta**. Es **HINDER** (§9) | **5 % de cordura por impacto** — estás simulando desesperación |
| **El crucifijo, contra Tipo 1 / 3 / 4** | **lo elimina.** Es **NEUTRALIZE** | se consume |
| **El crucifijo, contra Tipo 2, fuera del rezo** | lo saca de manifestado → invisible-merodeando | se consume |
| **Ritual + crucifijo, contra Tipo 2 durante `idle_prayer`** | **lo expulsa del mapa** → §8 | se consume, y el ritual lleva tiempo |
| **Llegar al camión** | la victoria por retirada — con la salvedad del Tipo 4 (§11.4) | — |

> **El reparto por clase es de §11.4**, y ordena esta tabla: **el crucifijo solo alcanza para tres de
> las cuatro**, y la **ventana de rezo dejó de ser una regla general** — es la mecánica del **Tipo 2 y
> de nadie más**. Encaja sin forzar nada, porque `idle_prayer` **es una voz del Tipo 2** (§11.5).
>
> Y esto le da sentido a *IDENTIFY the class type* (§9): **equivocarse de clase cuesta un crucifijo.**
> Tirárselo a un Tipo 2 creyendo que era un Tipo 3 lo gasta y no lo mata. La identificación deja de
> ser sabor y pasa a ser la decisión que gobierna el inventario.

> ❓ **Cómo se aplica el crucifijo, sin decidir.** El autor propone **tirárselo**. A favor: obliga a
> apuntar bajo presión, GMod maneja el objeto físico nativamente, y errar tiene costo real —queda en
> el piso y hay que ir a buscarlo mientras te cazan—. En contra: en Phasmophobia el crucifijo se
> **coloca** y actúa por radio, así que tirarlo es un verbo nuevo para quien viene del juego.
> Las dos formas son defendibles; **lo que no puede pasar es que se gaste sin que el jugador entienda
> por qué no funcionó**, y ahí el `hurt` de §12.1 ya tiene la respuesta puesta: que conteste.

### 12.1 `hurt` es sabor — el indicador de estado es que **se lo ve**

21 líneas, mediana **2,8 s**: son las más cortas del set, y tienen que serlo. Son reacción, no
discurso, y pueden sonar encima de otra cosa sin parecer un bug (una interjección corta encimada se
lee como interrupción).

> **[respondido por el autor, 2026-08-05] Las 21 están MEZCLADAS** — insultos y "no me hacés nada"
> revueltos, sin subconjuntos separables. **Así que el banco no puede señalar el estado**, y el
> diseño anterior de este documento —que las usaba de indicador— queda descartado.

**El indicador estaba en el `about.txt` desde el principio:** dispararle lo vuelve *"un mero demonio
por unos 15 segundos"*.

**Entonces la señal es que SE LO VE.** Un mero demonio no tiene lo que hace especial a un Alternate:
durante esos 15 s **pierde la invisibilidad al moverse** (§13, "mientras se moviliza, invisible") y
el jugador lo ve caminar.

Es mejor indicador que cualquier línea de voz por tres motivos: no necesita HUD, no necesita separar
ningún banco, y **es la misma propiedad que el jugador ya aprendió a leer** — venía viéndolo sólo
quieto en las esquinas, y de golpe lo ve moverse. El estado se comunica rompiendo una regla que ya
conocía.

`hurt` queda entonces como **sabor puro**: suena al pegarle, diga lo que diga.

### 12.2 Por qué vuelve, y por qué eso está bien

**El gancho de lore justifica que vuelva:** es un ángel caído. El símbolo no lo mata, **le recuerda
lo que perdió**. Por eso retrocede, y por eso retrocede *nada más* — salvo en la ventana de §8, que
es cuando lo que perdió es lo que está pidiendo.

**Irse también es ganar.** El about ya dice que su plan es matarte cuando estés lejos del camión;
entonces el camión es la contrajugada. Y tiene que sentirse como que **te dejó ir**, no como que le
ganaste.

> **Esto NO choca con la base.** [ESTADO.md](../ESTADO.md) ya tiene decidido *"desenlace del hunt:
> por tipo, `kill` o `banish`"*. El Alternate es un tipo **`kill`** con una ruta de `banish`
> condicionada, y el marco ya lo contempla.

---

## 13. La ficha de comportamiento — del `about.txt` del autor, íntegra

**Manifestación**

- **No deja orbes.** Modelo custom oscuro el **100 %** de las veces.
- Se esconde en **esquinas oscuras** (les gusta la oscuridad según el lore) y **ahí es visible**
  mientras observa. **Mientras se moviliza, invisible.**
- Hace una **aparición completa**: se muestra entero, corre hasta el jugador y arranca
  `preacherwhispers` → §6.
- **No canta.** Al moverse tiene **pisadas tenues**.

**Evidencias y detección**

| | |
|---|---|
| Huellas dactilares | **sí** |
| EMF | **5**, al interactuar con objetos |
| Spirit box | **sí** — contesta con los ataques de cordura; cada respuesta daña, y **ataca más seguido si el jugador habla** |
| Paramic | **sí** — usarla lo hace hablar, y **te daña si lo escuchás** |
| Ambiente helado | **no** |
| Escritura | **no** |
| DOTS | **no** |

**Posesiones**

- **La radio.** Es el dueño del evento
  `sound/phantasmagoria/prop/radio/event_creepy_eas_paranormal_radio_advise.ogg` *(verificado: el
  archivo existe)*. Debería ejecutarlo **al menos una vez** al encontrar una radio manipulable
  —aunque no siempre.
- **La TV del camión** — 30 % de que lo haga. Muestra su cara y daña la cordura si estás cerca.
- **Las pantallas del equipamiento** — 30 % de que lo haga.

**Cacería y muerte**

- Caza al **50 %**. Se mueve **rápido** (velocidad de revenant).
- **Detecta jugadores escondidos.**
- **No destierra: mata.**
- **No se puede matar por daño** → §12. La ruta de destierro es §8.
- **No ataca de inmediato:** simula que investiga a su víctima. La idea es matar cuando el jugador
  esté **lo suficientemente lejos del camión o de la salida** — si hay camión, traza el camino y mide
  la distancia; si no hay, lo hace igual.

---

## 14. Lo que queda abierto

- ~~¿Las 21 de `hurt` se separan en dos grupos?~~ **CERRADO 2026-08-05: están mezcladas.** El
  indicador de degradación pasó a ser **visual** (§12.1).
- ❓ **Nadie sabe qué DICEN los 168 archivos, y no se puede averiguar acá.** No hay STT instalado
  (`whisper`, `faster_whisper`, `vosk`, `pocketsphinx`: ninguno). `speech_recognition` sí está, pero
  sin motor offline su único camino es **subir los audios a la API de Google**, que no se hace con
  archivos del autor sin que lo pida. Los comentarios Vorbis sólo traen `TITLE` y `TRACKNUMBER`, no
  el texto. **Todo lo de este documento está construido sobre las duraciones y sobre lo que el autor
  describió por grupo** — que alcanzó, pero es una base más fina de lo que parece. Tres salidas, de
  la más barata a la más cara: el autor **tiene el texto** con el que generó las voces en SAM;
  `pip install faster-whisper` y se transcribe local sin que nada salga de la máquina; o seguir
  describiendo por grupo.
- ❗ **La K: falta grabar la línea canónica completa.** Las ocho de `sanity_strong_attack` están
  grabadas, pero **`_1` y `_8` son la frase del canon con la mitad buena arrancada** (§9.3). Hace
  falta grabar en SAM: la recitación de las cinco letras, **KNOW YOUR PLACE in reality** (el tier por
  defecto), y la diapositiva corrupta **entera** — *"there's not enough room for the two of us"*, que
  es la parte que la vuelve un argumento en vez de un insulto.
- ❗ **§11.5 — la cobertura de audio, y es la decisión más grande que queda abierta.** Los 168
  archivos son la voz **del Tipo 2**. Con una clase por partida, **el banco suena en 1 de cada 4**, y
  una partida de Tipo 4 sola se queda sin §7, sin §8 y sin la fase 0 de §10. Hay una salida que no
  cuesta nada —**que la mente de colmena mande desde fuera del mapa**, así las voces suenan siempre y
  el Tipo 2 presente es la escalada— pero está **propuesta, sin ratificar**.
- **Tipo 3** — **resuelto 2026-08-05:** habla con el banco del Tipo 2 por la mente de colmena
  (además de su registro gutural propio), así que **el problema de cobertura de §11.5 casi no le
  afecta**: replica los ataques a la cordura y puede usar `here` para llamar al jugador.
- 🎙 **PENDIENTE DEL AUTOR — grabar la voz del Tipo 4** (§11.7): otro registro (susurro / teléfono),
  palabras **inteligibles pero extrañas**, distinto del timbre de SAM. **No hay ni un archivo
  todavía.**
- 🎙 **PENDIENTE DEL AUTOR — conseguir la música** (§11.7): el **Ave María de Bach/Gounod por
  Alessandro Moreschi** (1902-1904, dominio público) **y piezas similares** para no repetir siempre
  la misma. **Bajar una transferencia limpia, no un remaster moderno** — la grabación es libre, una
  restauración reciente puede reclamar derechos propios sobre esa versión.
- 🎙 **PENDIENTE DEL AUTOR — grabar la K canónica** (§9.3, ya listado más arriba).
- ❗ **Cuánto dura la señal musical del Tipo 4**, que **es la ventana de escape del camión** (§11.7).
  Sin decidir, y es un número que se siente enseguida: corto de más frustra, largo de más lo vuelve
  inofensivo.
- ~~§11.6 — la voz del Tipo 1~~ **RATIFICADO por el autor 2026-08-05**: nada de micrófono ni de
  TFA Vox. Copia **los sonidos que el jugador ya hace** — pasos, clic de linterna, equipamiento de
  Phantasmagoria.
- ❗ **Los alternos extra del Tipo 2: ¿de qué clase son?** El **cuántos** ya está decidido
  (§11.4: **1**, y **2 sólo en dificultad máxima**), pero no de qué clase. Si son de otra, esa
  partida termina con varias clases a la vez y el jugador necesita **un crucifijo por cada una más el
  ritual**. La aritmética del inventario no está hecha.
- ❗ **La supresión de §5.5 se decidió con una sola criatura en mente.** ¿Un Tulpa que vive en las
  pantallas también calla al fantasma anfitrión? Probablemente no, y entonces la regla es **por
  clase** y no global.
- ❗ **§11.3 — que la tarjeta liste tres y haya cuatro es una ESCENA.** No arreglar la tarjeta.
  Falta escribir cómo se entera el jugador.
- **La compuerta de contenido sensible.** El diseño está en §9.4 y el barrido de §2.3 confirma que
  **cubre un solo banco**. Falta la decisión del autor sobre el default y el aviso, y una nota de
  implementación que no es menor: el spirit box tiene que mandar por `net` a los clientes que lo
  tengan habilitado, **no `EmitSound` desde el server**, o la convar es decorativa.
- **Retirar `sanity_strong_attack_1`, `_7` y `_8`**, y mover `_4` y `_6` a `sanity_attack` (son
  amenazas, no inducción). **Propuesto, sin ratificar.** Renumerar no rompe nada: no hay una línea de
  Lua escrita.
- **§4.3** — si `appear` se reescala para igualar la cabeza. Decisión de arte del autor.
- **¿El Alternate miente alguna vez?** §7.2 dice que no, y la razón es fuerte (le habla al fantasma,
  no a vos). **Pero es una decisión de diseño y se puede revisar** — un `sayto` falso, uno cada
  muchas partidas, volvería a poner en duda todo lo que oíste. Riesgo: información no verificable
  que ya costó cordura es lo que hace que una mecánica se abandone.
- **Cómo se elige el fantasma "anfitrión".** §7.1 dice que el Alternate se suma al sorteo normal.
  Falta: ¿puede aparecer con cualquiera de los 30? ¿Los 7 con voz propia son más probables, para que
  la conversación rinda? *(Sesgar el sorteo hacia los 7 es tentador y probablemente esté mal: se
  notaría, y el 23/30 de silencio es lo que hace valiosa a la línea que sí nombra.)*
- **El modelo oscuro**: los puntos 3 y 4 de §3.2 piden un `.vmt` propio en namespace propio.
  **Sin escribir.**
- ~~El fade de invisibilidad: qué técnica~~ **RESUELTO 2026-08-05 leyendo la base** (§3.3): no hay
  que escribir el cloak, ya existe en `wraithcloaking.lua` y se enciende con `ENT.IsWraith = true`.
  Lo único que hay que escribir es **`wraithTerm_CloakDecidingTask`**, el override del *cuándo*.
  Queda sin medir el efecto lateral de `FL_NOTARGET` mientras está encubierto.
- **Qué le dice el libro de evidencias** a un fantasma que no es ninguno de los 30. "Ningún tipo
  coincide" **es** una respuesta, y probablemente la mejor.
- **Multijugador**: el reloj de §5.1 es por jugador, pero la aparición, las posesiones y las
  conversaciones de §7 son del mundo. Sin resolver.
- **El `hunt_loop` de 1,3 s** necesita una cadencia de repetición. Sin definir.
- **Nada de esto corrió en GMod.** Vale la advertencia de [ESTADO.md](../ESTADO.md) para todo el
  proyecto: leído y medido no es lo mismo que funciona.

---

## 15. Procedencia y créditos

| Qué | De dónde | Estado |
|---|---|---|
| **Comportamiento y banco de audio** | del autor del proyecto — 168 archivos generados con Microsoft SAM | propio |
| **El personaje y el lore** | **Mandela Catalogue**, de **Alex Kister**. Las clases Tipo 1/2/3 y **el Principio T.H.I.N.K. entero** (§9) son suyos, citados de la wiki de la comunidad | ficción de terceros, homenaje |
| **`Jeff the Hunter Playermodel`** | Workshop [806714233](https://steamcommunity.com/sharedfiles/filedetails/?id=806714233) — **el ítem es un REUPLOAD**, y el crédito es de tres | ver §15.1 |
| **Rostros de la TV** | del autor del proyecto | propio |

### 15.1 El modelo: tres créditos, no uno **[resuelto 2026-08-04, leyendo la página]**

| Quién | Qué le corresponde |
|---|---|
| **Valve** | el Hunter de **Left 4 Dead 2** — la malla y las texturas base (`newinfec`, `hunter_01`) |
| **SpongePierre** (*Pierre CHOSEROT*) — [perfil](http://steamcommunity.com/id/spongepierre) | **el autor de Jeff**: la edición y el rig a playermodel. Lo dice la propia descripción del ítem: *"This is author http://steamcommunity.com/id/spongepierre"* |
| **Foxy** (`FoxyTLG`), con co-creador *"ima made nando mo"* | **el reupload**, 26 nov 2016, declarado como *"Server content for 'Prop Hunt OXPLAY.RU'"* |

**A quien hay que escucharle un pedido de retiro es a SpongePierre**, no al que lo resubió.

> ⚠ **La lección de método, porque casi cuesta un crédito mal puesto.** La API de Steam
> (`GetPublishedFileDetails`) devuelve `creator` = `76561198177763163`, que es **el subidor**. En un
> reupload el subidor **no es** el autor por definición, así que resolver ese SteamID64 a un nombre
> habría dado un crédito **equivocado con toda confianza**. El campo contesta *"quién lo publicó"* y
> yo lo leí como *"de quién es"*. La respuesta correcta estaba escrita en la descripción de la
> página, en texto plano, todo el tiempo: **el instrumento estructurado no siempre contesta la
> pregunta que uno cree que le hizo.**

> ⚠ **Dos instrumentos se contradicen sobre el estado del ítem, y queda SIN resolver.** La API dice
> **activo y público** (`banned=0`, `visibility=0`, 5.425 suscriptores, consultado 2026-08-04); la
> lectura de la página dice que fue **removido de la comunidad por violar las guidelines y sólo lo ve
> el subidor**. El autor del proyecto **puede abrir la página y leer la descripción**, lo que no pasa
> con un ítem removido para terceros. Precedente en
> [`dev/mods_workshop_mapa.md`](../../dev/mods_workshop_mapa.md): los "removed" leídos del HTML ya
> fueron **falsos positivos** antes y la API es la fuente que ese doc trata como autoritativa. Se
> anota la contradicción y **no se declara ninguna de las dos**. Da igual para el uso —hay copia
> local desempacada— pero **no da igual para pedirle permiso a nadie**.

*Control que sí cerró:* la página declara **3,720 MB** y el `.bin` instalado mide **3.719.831 bytes**.
Es el mismo ítem.
