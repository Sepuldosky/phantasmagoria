# Phantasmagoria — Estado actual y handoff

**Última actualización:** 2026-08-01
**Repo:** https://github.com/Sepuldosky/phantasmagoria (público, MIT)
**Changelog:** ver [CHANGELOG.md](CHANGELOG.md)
**Diseño vigente:** [docs/PHANTOM_Phasmophobia_Diseno.md](docs/PHANTOM_Phasmophobia_Diseno.md)
**Investigación de la base:** [docs/PHANTOM_Referencia.md](docs/PHANTOM_Referencia.md)
**NPC de evento especial:** [docs/ALTERNATE.md](docs/ALTERNATE.md) — el Alternate de Mandela Catalogue

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
| Catálogo de audio | **CERRADO** — 265/265 identificados y por acción ([§7.2](docs/PHANTOM_Phasmophobia_Diseno.md)) |
| Diseño de spawn / dificultad / cuartos | **CERRADO** — §12, §13, §14 del diseño |
| Zona segura / esconderse / hunt no determinista | **CERRADO** — §18; corrige dos filas de §2 |
| Percepción: las **6** rutas por las que el bot te ubica | **CERRADO** — §18.7; el arreglo son **dos campos**, no uno |
| Cordura: tasa, ámbito, oscuridad, camión | **DISEÑADO** — §19; falta la forma de la capa NEAD (§19.5) |
| **Props de equipamiento** | **EN EL ÁRBOL** — 36 modelos verificados, 0 referencias rotas |
| Detector de addons duplicados | **ESCRITO** — `lua/autorun/phantasmagoria_assetcheck.lua` |
| Entidad `terminator_nextbot_phantom` | **ESCRITA, SIN CORRER** — `lua/entities/terminator_nextbot_phantom/`, 3 archivos. Es un **instrumento**, no un fantasma (ver abajo) |
| Sistema de cuartos + toolgun | **NO EXISTE** — diseñado en §14 |
| SWEPs / entidades de equipo | **NO EXISTEN** — los modelos ya están, falta el Lua |
| Nada de esto en juego | **1 corrida** (2026-08-05) — el fantasma spawnea, camina y persigue. Refutó una predicción del documento |

---

## El próximo paso concreto: **correrla**

La entidad **está escrita** (2026-08-05) y **no se corrió ni una vez**. Son tres archivos:

```
lua/entities/terminator_nextbot_phantom/
    shared.lua    registro, clase, categoría — corre en los DOS realms
    server.lua    modelo, desarmado, FOV, y los avisos de spawn
    client.lua    el marcador que atraviesa paredes
```

**Su primer trabajo es ser instrumento, no ser un fantasma.** Por eso `IsWraith` está **fuera**
—corrige el snippet que este documento traía, que lo incluía— y por eso el bot queda **hostil a
propósito**: el criterio de cierre dice «camina hacia algo» y hace falta un algo.

### El check, declarado antes de correr

**Las precondiciones, medidas en la máquina del autor el 2026-08-05** (no supuestas):

| Precondición | Estado | Cómo se midió |
|---|---|---|
| El addon montado en GMod | ✅ | junction `garrysmod/addons/phantasmagoria` → el repo. El código entra al arrancar, sin copiar nada |
| La base Terminator montada | ✅ | WSID **2944078031**, título *«Terminator Nextbot»*. Ojo: `CREDITOS.md` anota `2734691788`, que **no** está suscrito |
| Un mapa con navmesh | ✅ | `maps/gm_construct.nav` (7,2 MB) y `gm_flatgrass.nav` (277 KB) ya existen. **No hace falta `nav_generate`** |
| `models/dejtriyev/scaryblackman.mdl` | ❌ | **no lo trae ningún addon montado** — barridos los 418 con contenido (395 `.gma` + 26 legacy `.bin` descomprimidos), las otras 455 carpetas del Workshop están vacías |

**El modelo faltante no bloquea el check, y por eso el fallback existe:** `server.lua` va a caer a
`models/player/group01/male_04.mdl` —presente en el índice de `garrysmod_dir.vpk`— y **lo va a decir
en consola**. Así que la predicción de la fila 2 cambia: **no** sale la silueta negra sin ojos, sale
un ciudadano de HL2. Si querés el modelo bueno, está desempacado en
`dev/other/phantom/dev2/scary black man (hood irony) playermodel/` y se monta con un junction a
`addons/`, igual que este repo.

> Los dos negativos de arriba salieron **con control**, porque el primer barrido mintió dos veces: el
> parser de títulos `.gma` daba 0 coincidencias hasta que se le leyó bien la lista de contenido
> requerido, y el barrido por substring daba «ninguno» sobre los legacy `.bin` **porque están
> comprimidos con LZMA** — lo delató que el control (Jeff, que sí está suscrito) tampoco aparecía en
> su propio archivo.

| # | Qué se hace | Verde | Rojo | **Corrida 1** (2026-08-05) |
|---|---|---|---|---|
| 1 | Abrir el spawnmenu, pestaña **NPCs** | hay categoría **Phantasmagoria → Fantasmas** con *Phantasmagoria Ghost* | no está | ✅ |
| 2 | Clickearlo | aparece un cuerpo, y la consola imprime `[Phantasmagoria] spawn #N modelo … pos …` | error de Lua, o nada | ✅ `spawn #253 modelo …male_04.mdl skin 1` |
| 3 | Mirarlo | hay caja violeta + haz + `PHANTOM #N` + distancia en metros, **también a través de una pared** | no se dibuja nada | ⚠️ **caja y haz sí, etiqueta no** |
| 4 | Alejarse y esperar | **camina hacia el jugador** — el marcador se mueve y la distancia baja | se queda clavado | ✅ camina y persigue |
| 5 | `phantasmagoria_ghost_where` en consola | lista pos, vida, modelo, enemigo, tareas y navareas | dice 0 fantasmas con uno vivo | sin correr |

**La entidad funciona.** Existe, aparece en el menú, spawnea, camina y te sigue. Los dos defectos
que salieron son **del instrumento**, no del fantasma, y los dos son la misma clase de error: *se
diseñó contra un escenario y se probó en otro*.

**① El aviso de navmesh predecía en vez de medir — y el juego lo refutó.** Decía «SIN NAVMESH: el bot
no va a caminar», había 0 navareas, y **el bot caminaba**. La medición del instante era correcta; la
predicción, falsa. La causa estaba en el código que yo mismo había leído para escribir el aviso: con
0 areas la base llama a **`TryGeneratingAreas()`** (`shared.lua:3072-3075`) y el **parcheador**
(`terminator_areapatcher.lua`, convar `terminator_areapatching_enable`, **default 1**) sigue creando
areas donde caminan bots y jugadores. Leí la rama del mensaje y no la línea de abajo, que es la que
actúa. **Arreglado midiendo dos veces**: informa el 0 al spawnear y **vuelve a medir a los 10 s**,
diciendo cuántas areas construyó el parche — o confirmando el 0, que ahí sí es terminal.

**② La etiqueta del marcador estaba sobre el techo.** Se veían la caja y el haz y no el texto: estaba
a 250 u sobre la cabeza (~322 del piso), y la corrida fue **adentro de una casa**. El instrumento se
diseñó para un mapa abierto. Bajada a 14 u — pegada a la cabeza. El haz largo se queda: es lo que te
dice desde otra habitación en qué dirección está.

El 3 y el 5 son **dos instrumentos que fallan distinto**: el marcador solo ve lo que está en el PVS,
el comando corre en el servidor y los ve a todos. Si el 5 lo encuentra y el 3 no, el bot existe y el
que falló es el dibujo.

### Si la fila 1 sale roja: la escalera que separa las causas

Cuatro formas de spawnearlo que dependen de cosas distintas, de más frágil a más cruda. La primera
que funcione dice dónde está el corte:

| Camino | De qué depende | Si anda y el anterior no |
|---|---|---|
| menú NPCs | registro **en el cliente** | falló `RegisterNPC` clientside — o sea el entrypoint (§4.4④) |
| `gmod_spawnnpc terminator_nextbot_phantom` | `list.GetEntry( "NPC", … )` **en el servidor** (`sandbox/gamemode/commands.lua:607`) | el registro corrió en el servidor y no en el cliente |
| `gm_spawnsent terminator_nextbot_phantom` | `ENT.Spawnable`, lista `SpawnableEntities` (`commands.lua:918`) | `RegisterNPC` falló en los dos realms, pero la clase existe |
| `lua_run ents.Create( "terminator_nextbot_phantom" ):Spawn()` | sólo que la clase esté registrada | la entidad está sana y todo el problema es de listas |

Si falla **también** el cuarto, la clase no se registró: hay un error de Lua al cargar y está en la
consola, arriba de todo.

Si algo sale distinto de lo que este documento predice, **gana el juego** y se corrige el documento.

### Lo que deliberadamente NO tiene, y por qué

| Ausente | Por qué |
|---|---|
| `ENT.IsWraith` | un instrumento invisible no sirve para ver dónde está |
| `OnFirstRelationWithPlayer` | es el interruptor fantasma/cazador (§3.1 del diseño), y hoy queremos al bot hostil para que camine hacia algo. Va en esa función y **nunca** en `DisableBehaviour` |
| `SetupDataTables` | el `Bool 0` ya es `Crouching` en la base (trampa ③) |
| máquina de estados, 30 tipos, rasgos, cordura, hunt, sonidos | todo eso viene **después** de verla caminar una vez |

Las trampas de la base están en §4.3 y §4.4 de la referencia. Resumidas:

1. **`ENT.Models`, no `ENT.Model`** — si no, spawnea con Arnold.
2. **`Term_FOV` necesita `AutoUpdateFOV = false`** o la convar global lo pisa en caliente.
3. **No usar `SetupDataTables` con `Bool 0`** — la base ya usa ese slot para `Crouching`.
4. **El interruptor fantasma/cazador es `OnFirstRelationWithPlayer`**, no `DisableBehaviour`.
5. **`ENT.Base = "terminator_nextbot"`**, no `"terminator_nextbot_base"` — el `_base` no tiene cerebro.
6. **El punto de entrada de una entidad-carpeta es `shared.lua`**, no `init.lua`: el registro tiene
   que correr **en el cliente**, que es donde se arma el spawnmenu (§4.4④).

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

- ~~La forma de la capa de compat con NEAD~~ **DECIDIDO: no se integra** (§19.5). NEAD hace
  `ply:SetNoTarget(true)` a un segundo a oscuras sin linterna, y la base respeta `FL_NOTARGET` en
  `ShouldBeEnemy` **y en el alerter** — invisible **e inaudible**. El override era posible, pero
  **las 6 muestras de oscuridad son API del engine, no de NEAD**: se reimplementan en 20 líneas, sin
  heredar el conflicto. **NEAD queda declarado no compatible, con aviso y sin bloquear** (precedente
  de `phantasmagoria_assetcheck.lua`). El sampler va **chico y autocontenido**: Cortex lo va a
  necesitar.
- **La pantalla del camión** (§19.3) — **EN CURSO EN OTRA SESIÓN, por el camino bueno: se está
  ripeando la pantalla real del camión de Phasmophobia.** El modelo ya está bien y el Lua que le pone
  la info está en proceso. **No hay que hacer nada con `tv_plasma`**: `dev/other/cs_office_tv/` queda
  sólo como respaldo del prop de CS:S y como registro de la trampa de `vpk.exe`. Lo que sigue
  valiendo de acá es §19.3: **HTML para las pantallas del camión, 2D para el equipo en mano**, y no
  asumir que `DHTML:GetHTMLMaterial()` sirva en `SetSubMaterial`.
- **¿`DHTML:GetHTMLMaterial()` sirve en `SetSubMaterial` sobre un modelo?** Sin medir. El camino
  seguro es HTML → nuestro RT → submaterial, que reusa la plomería del paramic.
- **Los 3 tiers de las pastillas** y qué restaura cada uno (§19.6). El modelo ya está:
  `models/phas/eqp_sanity_pills.mdl`.
- **Qué drena cordura y cuánto**, y **qué suma al medidor de actividad** 0-10 (§19.3, mecánica nueva
  que salió de las capturas del camión).

- ~~¿`MASK_BLOCKLOS` choca con `prop_physics`?~~ **MEDIDO Y REFUTADO EN JUEGO** (2026-08-03, §18.6):
  **no choca.** Control `true / Entity [59][prop_physics]`, con el mask `false / [NULL Entity]` —
  misma línea, única variable el mask. **Primera medición del proyecto y refutó al documento.**
  El arreglo es un campo: `ENT.LineOfSightMask` es por entidad con fallback al global
  (`shared.lua:2960`), y sus tres usos son la misma clase de pregunta.
  **MEDIDO EN JUEGO que el campo se respeta** (2026-08-03): de frente sin nada en medio `solid=true`
  —el control—, tras un container y tras unas compuertas `solid=false`. De paso salió que **las
  compuertas tampoco cortan `MASK_BLOCKLOS`**. Sigue **sin medir** que un `ENT.LineOfSightMask` de
  **subclase** sobreviva la línea de init: acá se seteó después del spawn.
  **El mask elegido es `MASK_SOLID`**, barriendo cinco candidatos en juego: es el único de los dos
  que sirven sin traer `CONTENTS_DEBRIS` (gibs cortando la vista) ni `CONTENTS_HITBOX` (caro, y este
  trace corre por enemigo y por barrido).
- ~~¿El mundo sí corta `MASK_BLOCKLOS`?~~ **MEDIDO: sí** — las cinco pegan en `worldspawn` contra una
  pared. **La rama catastrófica está muerta**, la base no es omnisciente.
- ~~¿Una entidad (jugador, NPC) corta `MASK_BLOCKLOS`?~~ **MEDIDO: no.** Mismo barrido contra un
  `npc_kleiner`: mismo patrón exacto que la caja, con una entidad de clase distinta. **`MASK_BLOCKLOS`
  es geometría del mundo y nada más**, y `CONTENTS_MONSTER` es el bit de «esto es una entidad». Con
  eso queda medido también el efecto secundario de `MASK_SOLID`: **jugadores y NPCs ocluyen**.

- **Plan del autor (2026-08-03): la entidad básica se escribe como instrumento** — primero existir y
  **mostrar dónde está**, después todo lo demás. Tres cosas para no tropezar:

  1. **NO ponerle `ENT.IsWraith = true` todavía.** §2 lo lista como el regalo que la hace invisible
     fuera del hunt — y un instrumento invisible no sirve para ver dónde está.
  2. **La base ya trae visualizadores**, no hace falta escribirlos: `term_debugpath` (dibuja el path;
     **pide `sv_cheats 1`**, `base/init.lua:92`), `term_debugtasks` (imprime tareas, y vuelca el
     historial al hacerle **+use** al bot) y `term_debughearing`.
  3. **El check NO depende de la entidad.** «¿Un prop corta `MASK_BLOCKLOS`?» es una pregunta de
     `util.TraceLine` entre dos puntos cualesquiera: se contesta desde consola sin NextBot. Hacerlo
     con el fantasma es **más convincente** —ejerce la cadena real, `GetShootPos` → `EntShootPos`→
     `CanSeePosition`— pero si la entidad se demora, la versión sintética desbloquea el diseño igual.
- **Dos defectos de la base, y muerden en momentos distintos** (§18.3):
  1. **Vista infinita sobre jugadores, y está etiquetada como feature** — `DoDefaultTasks` recorre
     `player.GetAll()` **sin filtro de distancia** cuando el bot no tiene enemigo (*«cheap infinite
     view distance»*, `shared.lua:3185`). Es la **ruta 3** de §18.7. **Vive y muerde hoy.** Se acota
     overrideando `ShouldBeEnemy`, que es **punto único**: las tres rutas de adquisición pasan por
     ahí. Por eso el arreglo son **dos campos MÁS un override**, no dos campos.
  2. **La dispersión se invierte pasando los 500 u** (`500 - sndDist`, y `VectorRand()` sin
     normalizar): más ruido mejora la puntería sólo hasta 500, y a 500 clavados **te da la posición
     exacta**. **Está DORMIDO** —vive en `shouldNotSeeEnemy`, muerta tras el `if` del alfa— y se
     hereda **en el instante en que se des-gatee** (§18.3). Arreglarlo en **esa misma** sesión.
- ~~Los sonidos ambiguos: 46 de 265.~~ **CERRADO** (2026-08-03): el autor los escuchó y los
  describió uno por uno; están catalogados y `_sin_identificar/` ya no existe. **265 de 265 mapeados**
  por acción, **incluidos los pasos del fantasma** — `ghost/footstep/boots_1-8`, §7.4.
- **Los pasos lejanos** (§7.5, pedido del autor): un ghost event de pisadas lentas a distancia, sin
  fuente visible. **No necesita assets nuevos** —es el banco de botas sonando lejos— y el rasgo
  (`ability.paranormalSoundInterval`) ya existe. Falta escribirlo, como todo lo demás.
- **La parabólica y el sound sensor no existen**: 36 modelos y ninguno es un micrófono
  ([EQUIPAMIENTO.md](docs/EQUIPAMIENTO.md) §9). Con la identificación de sonido cerrada, la mecánica
  de **delatar por sonido tiene audio y le faltan props dos veces** — también a la Music Box, que ya
  tiene su tarareo. Sin decidir cuál de los tres caminos se toma.
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
- ~~El arte de las huellas UV.~~ **CERRADO** (2026-08-02): se reciclan los decals de gmpa, derivados
  a máscaras teñibles con [`dev/uv_prints.py`](dev/uv_prints.py) y acreditados con hash. Cuatro
  texturas en `materials/phantasmagoria/uv/`. Lo que **queda** es el Lua: la evidencia `uv` la tienen
  **13 de los 30 tipos** y la mecánica está diseñada en
  [docs/EQUIPAMIENTO.md](docs/EQUIPAMIENTO.md) §8 — falta escribirla.
- **El Alternate** (Mandela Catalogue) — **NPC de evento especial, fuera de los 30 tipos.**
  **ACTUALIZADO 2026-08-05: el banco de voces pasó de 34 a 168 archivos (20,2 min) y eso cambió el
  diseño, no sólo los números.** Dos bancos nuevos mandan: `sayto_ghost` (62 líneas dirigidas a otro
  fantasma) **obliga a que el Alternate NO sea el fantasma del contrato** —se suma al sorteo, no lo
  reemplaza— y convierte al enemigo en **fuente de información**: le habla al otro fantasma, el
  jugador espía, y **7 de los 30 tipos tienen voz propia** (`demon`, `goryo`, `jinn`, `oni`,
  `poltergeist`, `shade`, `yokai` — verificado contra las claves de `ghost_types.lua`), así que 23
  de 30 partidas la conversación no revela nada. `idle_prayer` (10) es **la única ventana en la que
  el crucifijo destierra** en vez de sólo degradar: dura ~6 s, igual que `preacherwhispers`.
  **El loop está cerrado en ALTERNATE.md §7-§9**: el antagonista es a la vez el obstáculo, el sistema
  de pistas y la condición de victoria.
  **Y meter un segundo fantasma destapó que el daño de cordura estaba inflado al doble** (lo pescó el
  autor): con el anfitrión drenando en paralelo, la cordura llegaba a 0 en **4:03** y no entraba nada
  de lo que el diseño pide que pase. Arreglado con dos piezas (§5.2-§5.5): la aparición vuelve al
  **15 % del `about.txt`** —yo la había puesto en 30 %— y **mientras el Alternate está activo el
  fantasma anfitrión se calla**: no hace eventos, no drena y no caza, así que los drenajes no se
  apilan y **el silencio de la casa se vuelve el aviso de que llegó**. Las evidencias ya puestas NO
  se suprimen: el contrato se sigue pudiendo resolver.
  **Los 168 están TRANSCRITOS** (2026-08-05, `faster-whisper` local, con permiso del autor; el `.tsv`
  quedó **fuera del repo** a propósito). Dos resultados que cambian el diseño: (1) las líneas
  específicas **no nombran al fantasma — son adivinanzas** sobre la etimología y el folklore del
  nombre (*"they threw beans at you, once a year"* = Setsubun = Oni), o sea que la información viene
  **cifrada** y no trivializa la identificación; y (2) el lenguaje explícito **está confinado a
  `sanity_strong_attack`**, así que la compuerta de contenido cubre un solo banco.
  **Y el Principio T.H.I.N.K. del canon resultó ser el manual del addon** (ALTERNATE.md §9): las
  cinco letras mapean una a una sobre mecánicas que ya estaban diseñadas —**HINDER es literalmente la
  frase del `about.txt` sobre ralentizarlo 15 s**, y el *"if safe to do so"* de NEUTRALIZE es la
  ventana de rezo—. De ahí salen los dos tiers de contenido sin inventar nada, porque **la propia
  cinta muestra la diapositiva corrupta y después la corrige**. Abre tres pendientes: falta grabar la
  K canónica completa, y *"IDENTIFY the class type"* es un segundo bucle de identificación sin
  diseñar.
  **Las CUATRO clases quedaron escritas** (ALTERNATE.md §11, taxonomía del autor): Doppelgänger,
  Unspeakable, Flawed Impersonator y Tulpa — **los cuatro hacen M.A.D.**, la clase dice *cómo se
  acerca*. Tres consecuencias: (1) **lo de los flexes estaba mal planteado y se invierte** — el tell
  del Doppelgänger es *expresión fija y parpadeo incorrecto*, o sea que los **cero flexes de Jeff SON
  el tell**, y el del Flawed Impersonator son proporciones imposibles, que se hacen con
  `ManipulateBoneScale` sobre los 53 huesos ValveBiped; ninguna de las dos pedía morphs, y cae la
  advertencia de que un playermodel sin flexes rompía la mecánica; (2) **cada pieza ya diseñada
  pertenece a una clase** — la aparición con `preacherwhispers` es Tipo 3 (*The Preacher* lo es), la
  posesión de TV y pantallas es **cómo se desplaza un Tulpa** y no un truco, y *"mata directamente"*
  es Tipo 2; (3) **la tarjeta T.H.I.N.K. lista tres clases y hay cuatro** — no es error del canon (la
  cinta admite información incompleta) sino **una escena**: la clase que el manual no menciona es la
  única que viaja por pantallas, o sea la única que puede alcanzarte **dentro del camión**.
  Y el espejo maldito ya tiene el feed en vivo (`DrawMirrorView`), así que la segunda superficie del
  Tulpa no necesita código nuevo.
  **VERIFICADO CONTRA LA BASE (2026-08-05, §3.3-§3.4):** la invisibilidad **ya existe y no hace falta
  HIM** — `terminator_nextbot/wraithcloaking.lua`, 202 líneas, se enciende con `ENT.IsWraith = true`,
  y **el "cuándo" es un punto de extensión declarado** (`ENT.wraithTerm_CloakDecidingTask`, `:23`):
  el Alternate no escribe el cloak, escribe ese override. De paso **se cae una reserva propia**: yo
  había marcado `$allowdiffusemodulation 0` del `.vmt` de Jeff como riesgo para el fade, y la base no
  usa `SetColor` sino **`SetMaterial`**, así que la bandera no interviene — marqué un riesgo contra
  una técnica que la base no usa. Sin medir queda el efecto de `FL_NOTARGET` mientras está
  encubierto: **es la misma bandera de la trampa de NEAD** (§19.5). Y apareció el patrón que piden
  las posesiones: HIM usa **una tabla de props con probabilidad por prop**
  (`["homeless_camera"] = { defChance = 90, func = … }`), que es exactamente la forma del 30 % de la
  TV y el 30 % de las pantallas.
  **PENDIENTE DEL AUTOR — audio que todavía no existe:** la voz del **Tipo 4** (otro registro,
  susurro/teléfono, palabras inteligibles pero extrañas), la **señal musical** que acompaña su
  posesión de pantallas —**el Ave María de Bach/Gounod por Alessandro Moreschi**, 1902-1904, dominio
  público, *bajando una transferencia limpia y no un remaster*— y la **K canónica** de T.H.I.N.K.
  La señal musical **es el temporizador de la ventana de escape del camión**, así que su duración es
  una decisión de diseño y no de estética.
  **Diseño abierto y escrito: [docs/ALTERNATE.md](docs/ALTERNATE.md)** (2026-08-04). Tiene banco de
  audio propio (34 `.ogg`, duraciones medidas), modelo elegido y desempacado
  (`Jeff the Hunter`, WSID `806714233`) y los seis rostros de la TV ya derivados a
  `materials/phantasmagoria/alternate/`. **El gameplay loop está ratificado por el autor**: no se
  mata, se **degrada** —crucifijo y balas cambian su estado, no su vida— y la victoria es **llegar al
  camión**. Lo que falta antes de escribir Lua: el `.vmt` propio (el del Workshop trae
  `$allowdiffusemodulation 0` y `$Selfillum 1`, los dos en contra del "modelo oscuro"),
  **cómo entra al juego** (no puede salir del sorteo normal), y **qué le dice el libro de evidencias**
  a un fantasma que no es ninguno de los 30. **Crédito del modelo RESUELTO** (2026-08-04): autor
  **SpongePierre** sobre el Hunter de L4D2 de Valve, y el ítem del Workshop es un **reupload** de
  Foxy — ya está en [docs/CREDITOS.md](docs/CREDITOS.md). Salió de leer la descripción de la página:
  el campo `creator` de la API de Steam es **el subidor**, no el autor.
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
  **contra el `.gma` instalado**, no sólo contra el repo — el addon está desempacado en
  `dev/other/stormfox 2/` (2026-08-02). Falta escribir el mapeo y el camino propio para quien no lo
  tenga; §15.2 ya anota las **cuatro trampas** que salieron de leer los cuerpos (`GetCurrent`
  devuelve tabla, la nieve es lluvia bajo −2 °C, `GetRainAmount` da 0 nevando, `Temperature.Get`
  crashea con un tipo inválido). **gWeather y Simple Weather sin investigar.**
- **Los tiers de equipamiento** (§16): documentados, sin implementar. Va un tier por equipo en la v1.
- **Cuántos PHANTOM aguanta un servidor.** La base corre en coroutines presupuestadas
  (`ENT.CoroutineThresh`) pero nunca se midió.

---

## Advertencia que vale para todo el proyecto

**Nada de lo escrito hasta ahora se ejerció en juego.** Los documentos marcan **[verificado]** cuando
algo se leyó en el código y se auditó, y **[lectura]** cuando se leyó una sola vez. Ninguna de las dos
marcas significa "funciona": significan "el código dice esto". La primera corrida en GMod es la que
convierte esto en conocimiento.
