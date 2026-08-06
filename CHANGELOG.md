# Phantasmagoria — Changelog

**Estado:** ver [ESTADO.md](ESTADO.md) · **Diseño:** ver [docs/](docs/PHANTOM_Phasmophobia_Diseno.md)

Formato: una entrada por sesión de trabajo, la más reciente arriba. Se anota lo que se **hizo** y lo
que se **midió**, no lo que se planea.

---

## 2026-08-06 (2) — El interruptor CERRADO, y los dos defectos de la ronda fueron de la planilla

`dev/checks/phantasmagoria-hunt-r1.html`: **7 pasa, 1 falla**. Las cuatro filas que faltaban salieron
verdes, incluidas las dos que podían pedir código — el bot **suelta al enemigo solo** al apagar el
hunt (*«pasa inmediatamente a calma»*) y **aguanta un balazo** a fondo.

**La línea que vale por todo el bloque** es la fila 02: `rel D_HT pri 1000` **y**
`ShouldBeEnemy NO`, juntas. La relación no se apagó —sigue odiándote— y el bot igual no ataca. Es la
separación que §3.1 confundía, exhibida en una salida.

**Y la fila 05 salió más fuerte que su criterio:** tres lecturas mientras cazaba, a 62, 568 y 310 u,
las tres con `1 llamada(s), la ultima a t=101 con hunt=NO`. **El timestamp es el dato** — la última
evaluación fue con el hunt apagado y el hunt se prendió después. No es que el contador no se movió en
el frame del flip: es que no se movió nunca más, y se ve el reloj.

### Los dos defectos de la planilla, los dos escritos por mí

**① El criterio de la 05 pedía «2 llamadas» y lo correcto era 1: arrastre de bloque anterior,
adentro de la planilla que existe para impedirlo.** Copié el contador del fantasma **#1066 de la
corrida 4**, que había recibido un `hunt_reeval`. El #1069 es otro fantasma. El autor lo juzgó por la
sustancia y marcó PASA, que es lo correcto: **el criterio decía el número equivocado, no la cosa
equivocada.**

**② El criterio de la 04 pedía DOS muestras, y las dos primeras habrían dado ROJO** — 42 u y 153 u
contra un umbral de 200. Los saltos siguientes fueron 470, 1.076 y **3.144 u**, para un camino total
de **4.885 u (93 m)**. Salió inequívoco porque el autor tomó **seis** muestras. El umbral estaba
bien; el número de muestras estaba mal — y la regla ya estaba escrita en `dev/PLANTILLA_CHECKS.md`:
*«un caso suelto no juzga»*. `movement_inertia` se turna con `movement_wait` y `movement_camp`, así
que una ventana de 30 s puede caer entera adentro de una pausa. **Escribí la regla en la plantilla y
no la apliqué al check que la necesitaba.**

**③ Y uno del instrumento:** `ghost_rel` no mostraba la vida, así que *«acá lo baleo»* era una
afirmación de quien corre la planilla y no un dato. Ahora imprime `vida N / M` con
`( recibio dano )` / `( INTACTO: nadie le pego )`.

### La fila 08 falla, y la falla vindica lo que yo había retractado

*«Por fijo es que mira a un lado generalmente, es muy poco que gira a ver otros lados y eso es cuando
está quieto.»* La rama de falla que escribí decía *«la explicación que descarté era la buena»*, y el
código dice eso: `motionoverrides.lua:2838` sale con `if not myTbl.TERM_FISTS then return end -- only
look towards goal if we have fists`, y aun con puños sólo apunta **por debajo** de un umbral de
velocidad. No gira mientras camina; lo poco que gira es estando quieto.

**Pero la lección es la contraria a «yo tenía razón».** El error nunca fue la cita: fue colgarla de
una frase suelta **antes de fijar la observación**, y después **retractarla de más** al primer «no,
sí mueve la vista». Las dos veces expliqué en vez de medir. Lo que lo cerró fue un check con
lado-que-falla escrito. Y sigue sin leerse la otra mitad: **qué** le mueve la cabeza cuando está
quieto.

### El instrumento que pidió el autor

*«Falta que el comando muestre a dónde está mirando el phantom.»* `phantasmagoria_ghost_where` ahora
imprime tres líneas que **se discriminan entre sí**: `mira` (`GetEyeAngles()` — y el yaw es **el del
cuerpo**, la función sólo pisa el pitch), `quiere` (`GetDesiredEyeAngles()`) y `marcha`
(`loco:GetVelocity()`, no `Entity:GetVelocity()`, que en un NextBot puede dar cero y leerse como
«está quieto»). `quiere ≠ mira` es *«algo le pide girar y no llega»*; `quiere == mira` quietos y
caminando es **que nadie se lo pide**. Sin las tres, «no mueve la cabeza» no distingue las dos causas.

---

## 2026-08-06 — El interruptor fantasma/cazador CORRIÓ, y §3.1 quedó refutado en juego

El primer comportamiento propio del fantasma. Arranca en `phantom_Hunting = false` y **no ataca a
nadie**; con el hunt prendido vuelve a ser el cazador que ya sabía ser. **Corrió**: **6 de 10 filas
en verde, 4 sin correr, 0 rojos**.

### §3.1 refutado, con el control disparado un segundo antes

El orden real de la corrida fue **al revés** del que pedía la tabla, y eso la hace más fuerte:

```
] phantasmagoria_hunt_reeval
    #1066  llamadas a OnFirstRelationWithPlayer: 1 -> 2      <- el contador está VIVO, medido acá
] phantasmagoria_hunt 1
    #1066  hunt -> SI ( cazador )   llamadas ...: 2          <- y prender el hunt NO lo movió
```

Con el control corriendo inmediatamente antes, «el contador no se movió» no puede ser «el contador
está roto». **Nada re-evalúa relaciones al entrar en hunt.** Y el bot **sí** cambió de actitud, lo
que confirma que el cambio viene del `ShouldBeEnemy` leyendo el flag en vivo.

**Pero la fila se midió en un INSTANTE, y eso ya salió mal tres veces acá.** `phantasmagoria_hunt`
imprime el contador en el mismo frame del flip; una re-evaluación un tick después no aparecería. Es
el mismo defecto que *«0 navareas al spawnear» no es «0 navareas»*. Se cierra con un
`phantasmagoria_ghost_rel` posterior, que sigue pendiente.

### La pregunta abierta contestada: **deambula**

*«En calma sólo mira en una dirección y se mueve aleatoriamente, onda deambulando.»* La predicción se
sostiene (`movement_handler` → `movement_inertia`, *«nothing better to do»*, `shared.lua:4184-4187`):
**«no te ataca» no se volvió «no hace nada»**. Queda como **[a ojo]**: la fila pedía dos `pos`
separadas y no se tomaron.

### Dos hallazgos que no salieron de ninguna fila

**① El fantasma va a 1,96× la carrera del jugador.** Lo reportó el autor y el código pone el número:
la base trae `ENT.RunSpeed = 550` (`shared.lua:132`, con el comentario *«bit faster than players...
in a straight line»*), el fantasma **no lo pisa**, y `sv_bm_speed_run` del autor es **280**.
**Contradice §1.1**, que manda derivar la velocidad de la carrera real. **Cuarta vez que «heredado»
no es «correcto»** — y la primera que lo agarra el juego y no la lectura.

**② Me pasé de explicar, y el autor lo corrigió en el mismo mensaje.** Leí *«sólo mira en una
dirección»* del reporte y le colgué encima la trampa ⑦ de Referencia §4.4 (sin `TERM_FISTS` el bot no
mira hacia su objetivo al moverse). El autor: **en calma sí mueve la vista, sólo que menos.** La cita
puede ser cierta en su alcance y aun así no ser la explicación de lo reportado. *Una observación en
prosa todavía no es una medición, y explicarla antes de fijarla convierte una frase suelta en un
hecho con cita.*

### La relación no sirve de interruptor, por dos motivos independientes

§3.1 proponía `OnFirstRelationWithPlayer` devolviendo `D_HT`/`D_NU`, con la frase *«al entrar en hunt
se re-evalúan relaciones y la base hace el resto sola»*. Leyendo el código:

**① Nada re-evalúa.** `SetupRelationships` corre una vez, desde `Initialize` (`shared.lua:3079`), y
el resultado se **guarda** con `Term_SetEntityRelationship` (`enemyoverrides.lua:883`, cuerpo en
`terminator_nextbot_base/enemy.lua:44-47`). Es un cache. **El nombre lo venía diciendo: `OnFirst…`.**

**② Y aunque re-evaluara, no aguanta.** `MakeFeud` (`enemyoverrides.lua:1046-1048`) reescribe la
relación del jugador a `D_HT` prioridad 1000 en cuanto al bot le pegan (`PostTookDamage`,
`damageandhealth.lua:482`). **Un interruptor de relaciones se reabre de un balazo.**

El ② no salió de buscar un segundo motivo: salió de preguntarse quién más escribe en
`m_EntityRelationships`. El grep daba cuatro sitios de `Term_SetEntityRelationship` fuera del setup y
había que leerlos todos —la regla de §18.7—; el que rompía la historia era el último.

### El interruptor es `ShouldBeEnemy`

Es donde la base **lee** ese cache (`enemyoverrides.lua:493`) y se consulta en vivo por seis caminos:
las tres rutas de adquisición de §18.7, `ForgetOldEnemies` (`:676`, el que **suelta** al enemigo), la
revalidación de `shared.lua:3282` y `HaveEnemy`. Un `false` ahí **no congela nada** — las 31 tareas
siguen corriendo enteras. Es literalmente la última línea de §3.1, *«el bot nunca deja de pensar,
sólo deja de tener a quién odiar»*, en la función de al lado. Y **no** es `DisableBehaviour`.

Es además **el mismo punto único** que §18.7 ya reservaba para el corte por distancia de la ruta 3,
así que las dos cosas van a convivir ahí.

`OnFirstRelationWithPlayer` se escribió igual, pero **como instrumento**: cuenta cuántas veces la
base evalúa la relación y con qué flag, y **encadena al `BaseClass`** (trampa ①: la implementación
default no está vacía, implementa `ExtraSpawnHealthPerPlayer`, `damageandhealth.lua:872`). Devuelve
`nil`, así que **la relación queda en `D_HT` siempre, a propósito**: un `D_NU` ahí trabaría el
interruptor **cerrado para siempre**, porque `:493` exige `D_HT` y nada re-evalúa el cache.

### El bloqueante era el gatillo, y se resolvió con andamio declarado

La cordura no existe, así que nada dispara el hunt y el interruptor no se podía ver. Tres comandos:

| Comando | Qué es |
|---|---|
| `phantasmagoria_hunt 0\|1` | **ANDAMIO**. Mueve **sólo el flag** — ni relación, ni memoria, ni tareas |
| `phantasmagoria_hunt_reeval` | **CONTROL** del contador, no mecanismo: si el contador no sube al prender el hunt, esto prueba que el contador no está roto |
| `phantasmagoria_ghost_rel` | Instrumento: la relación **cacheada** al lado del `ShouldBeEnemy` **en vivo** |

Que `phantasmagoria_hunt` mueva **sólo** el flag es deliberado: si además re-disparara la relación,
la fila que mide §3.1 no mediría nada.

### Dos cosas que el código dijo y no eran obvias

**El efecto secundario que si no se lee como bug:** `shared.lua:1387` usa `ShouldBeEnemy` sobre lo
que le bloquea el paso —`not ShouldBeEnemy( blocker )` → `openDoorTime`—, o sea **abrir en vez de
romper**. Con el interruptor en fantasma esa rama se toma siempre. Es la que queremos.

**Y una trampa dormida en el propio control:** `phantasmagoria_hunt_reeval` vuelve a pasar por el
cuerpo default de `OnFirstRelationWithPlayer`, que lleva la cuenta `ExtraSpawnHealthPlayersDone` y
suma vida por jugador. Hoy sale por el `if not extraHpPerPly then return end` de la primera línea. El
día que se declare el campo, **el control infla la vida del fantasma cada vez que se lo llama** — que
es por qué está declarado como control de desarrollo y no como mecánica.

### El límite honesto de esta corrida

Como la relación **nunca sale de `D_HT`**, el motivo ② no se mide: no hay nada que `MakeFeud` pueda
reabrir. Sigue siendo **[lectura]**. Lo que la última fila del check sí mide es su consecuencia
práctica —que el interruptor aguante un balazo—, y funciona como guardia de regresión: si alguien
alguna vez «simplifica» esto a un interruptor de relaciones, esa fila se pone roja.

### La fila 4 del check anterior cambia de premisa

Decía «camina hacia el jugador» y salía verde porque el bot era hostil **a propósito**, para que el
criterio «camina hacia algo» tuviera un algo. Con el interruptor, esa fila **sólo vale con
`phantasmagoria_hunt 1`**. No es una regresión: el criterio viejo medía un andamio.

### El instrumento, otra vez

`luaparser` da rojo en los tres archivos propios **y también en los tres de tercero que sí corren en
GMod**, todos por el `continue` que Lua 5.1 no tiene. Con `continue`, `!=` y `!` traducidos, los seis
quedan en verde. *Un rojo que también sale en el control no es un defecto del sujeto.*

---

## 2026-08-05 — El plato del micrófono parabólico: CERRADO en juego, en cuatro rondas

Los tres platos parabólicos se ven **translúcidos a la mitad**, con brillo, y se ve el cañón y el
mundo a través. Planilla `dev/checks/paramic-vidrio-r4.html`, **8/8**. Cerraron de paso los dos
checks que arrastraba la ronda 2 sin correr: el parpadeo del LED del tier 1 y el desmontaje del
RenderTarget, los dos PASA.

### `$alpha` no vuelve translúcido a nada

Seis mediciones en juego sobre el tier 1, con controles de los dos lados:

| Prueba | Resultado |
|---|---|
| `$alpha 0` (**control nulo**) | el plato **no cambia** |
| `$alpha 0.5` | el plato **no cambia** |
| `$alpha 0.5` + phong | idéntico → el phong no era |
| `$alpha 0.5` sobre el **cuerpo** | tampoco → no es de la submalla del plato |
| `$translucent 1` | el plato **DESAPARECE**, a la primera |
| `SetRenderMode` + alfa de entidad | el prop **entero** sí se vuelve translúcido |

Los cuatro primeros son el mismo hecho. **`$alpha` es la *modulación* de alfa: escala un material
que ya está en el camino translúcido, y no lo pone ahí.** El que lo pone es `$translucent`. El
control nulo es lo que lo vuelve concluyente — con `$alpha 0` el plato tenía que desaparecer y no se
movió, así que ninguna lectura de «se ve un poco translúcido» podía haber sido cierta.

### La advertencia que estaba escrita, era correcta, y por eso costó dos rondas

Los tres `.vmt` decían desde el primer día: *«NO se puede usar `$translucent` acá — el alpha del
`$basetexture` es la máscara de `$selfillum` y haría desaparecer el plato»*. **Era cierto**, y ahora
está medido por los dos lados: el alfa del atlas tiene el **99,9 % de los texeles en cero** en el
tier 1 y el 97,6 % en el 3.

Pero estaba escrita como **advertencia**, no como pregunta, y por eso cerró el camino que era el
bueno. Medirla costó un comando. *Una advertencia sin medición es una rama podada a ciegas.*

### El arreglo: darle al material su propia textura

`$translucent` cobra el alfa **por texel**, y el plato compartía el atlas del cuerpo, donde ese canal
ya tenía otro trabajo. `dev/phastools/glass_tex.py` copia el atlas cambiando **un solo canal** —el
alfa, a la constante 128 (= el `_Opacity 0.5` medido de Unity)— y sale `paramic1_glass.vtf` y
`paramic3_glass.vtf`; los tiers 2 y 3 comparten plato, así que comparten textura. Verificado por
**round-trip VTF→PNG**: el alfa vuelve 128/128, sobrevivió a DXT5. El cuerpo conserva su atlas con la
máscara de selfillum intacta —es la que prende el LED— porque ahora son dos archivos.

**Regla:** *`$alpha` no vuelve translúcido a nada; `$translucent` sí, y cobra el alfa de la textura.
Si esa textura está compartida con otra pieza que la usa para otra cosa, la translucidez no se
resuelve en el `.vmt`: se resuelve dándole al material su propia textura.*

### Tres lecturas anotadas como propiedad del sujeto, siendo del instrumento

1. **`$mostlyopaque` no era la causa.** Se aplicó al tier 3 dejando los otros dos de control, y el
   tier 3 con `TRANSLUCENT_TWOPASS` se veía **igual de opaco**. Refutado en juego. La bandera se dejó
   puesta —es la declaración correcta para un modelo mixto— pero *lo que se refutó fue la hipótesis,
   no el flag*.
2. **`$alpha` leído del material daba 1**, y eso no dice que el `.vmt` no lo declare: es la
   modulación, que el motor pisa al dibujar. El check medía el runtime creyendo medir el archivo, y
   estuvo a un paso de anotarse como «el `.vmt` no declara el alpha» con el archivo declarándolo. Se
   arregló leyendo el `.vmt` **como archivo**, que además dice **cuál** montó el juego.
3. **`GetRenderGroup()` daba 7 en los tres, y anoté que «no discrimina». Falso** — en la ronda 4 da
   **9**. Los tres casos de la ronda 3 estaban en el mismo estado (materiales opacos), así que el
   valor constante no probaba un instrumento ciego sino un conjunto sin variación en lo que
   importaba. *Un valor que sale igual en todos los casos sólo desacredita al instrumento si los
   casos diferían en lo que se estaba midiendo.* De paso deja medido que **el motor decide el grupo
   de render por los MATERIALES**: con el flag puesto y los materiales opacos seguía en 7.

Y un defecto de Lua con firma reusable: **`IMaterial:GetInt()` sobre una clave que el material no
define devuelve *cero valores*, no `nil`**, así que `tostring()` revienta. El volcado se cortaba
**justo después** de la línea que se leyó como resultado — parecía completo y el error parecía ruido
aparte.

### Lo demás de la sesión

- Los tres `.mdl` recompilados con `$mostlyopaque` (`flags=9`), geometría **byte a byte idéntica**
  salvo el checksum, **7/7 los tres** contra control.
- El LED del tier 1 a **×1,8** (`PHANTASMAGORIA.PARAMIC_LED_BOOST`), a pedido del autor. **Sin
  medir**: no hay número de Unity que lo fije.
- Instrumento nuevo: `phantasmagoria_paramic_vidrio`
  (`info`/`plano`/`trans`/`cero`/`phong`/`cuerpo`/`ent`/`off`), en
  `lua/autorun/client/phantasmagoria_paramic_glass.lua`.
- Y un defecto de la **planilla misma**, que venía en cuatro bloques: su `render()` pasaba
  `pass`/`fail`/`cmdNote` por `esc()`, y esos tres campos se escriben con `<code>` — el criterio se
  leía con el marcado literal adentro de la frase que decide el veredicto.

**Falta:** los tres siguen siendo props, no ítems. `PHANTASMAGORIA.ParamicData` arranca en cero y
nada lo llena; el disparador del LED no existe.

---

## 2026-08-05 — Sesión 14b: **LA PRIMERA CORRIDA**. Camina, y refutó al documento

**El proyecto dejó de ser papel.** `terminator_nextbot_phantom` aparece en el spawnmenu, spawnea,
**camina y persigue al jugador**. Tres filas verdes del check de cinco.

**Y el juego ganó de entrada.** El aviso de navmesh decía *«SIN NAVMESH: el bot no va a caminar»*,
había **0 navareas**, y **el bot caminaba igual**. La medición del instante era correcta; **la
predicción era falsa**. La causa estaba en el código que había leído *para escribir ese mismo aviso*:
con 0 areas la base llama a **`TryGeneratingAreas()`** (`shared.lua:3072-3075`) y el **parcheador**
(`terminator_areapatcher.lua`, convar `terminator_areapatching_enable`, **default 1**) sigue creando
areas donde caminan bots y jugadores. **Leí la rama del mensaje y no la línea de abajo, que es la que
actúa** — copié el `if` y me salteé la consecuencia.

**Arreglo: un instrumento no predice.** Ahora mide, espera 10 s y **vuelve a medir**, informando
cuántas areas construyó el parche — o confirmando el 0, que ahí sí es terminal. De paso el aviso dice
lo que antes callaba: que caminar sobre un mapa **parcheado** no es caminar sobre un navmesh de
verdad, y hay que esperar caminos raros.

**Segundo defecto, misma clase: la etiqueta del marcador estaba sobre el techo.** Se veían la caja y
el haz, y el texto no. Estaba a 250 u sobre la cabeza —~322 del piso— y la corrida fue **adentro de
una casa**. **El instrumento se diseñó para un mapa abierto y se probó en un interior.** Bajada a 14
u, pegada a la cabeza; el haz largo se queda, que es lo que te dice desde otra habitación en qué
dirección está.

**Los dos defectos son del instrumento, no del fantasma** — y los dos son *diseñar contra un
escenario y probar en otro*. El fantasma anduvo a la primera.

### Corrida 2, en `gm_uh_house`: cuatro filas verdes y el tercer defecto del instrumento

La etiqueta **se ve** (`PHANTOM #1090` · `4 m`): era la altura, confirmado. El bot se movió 68 u
entre el spawn y la consulta y tiene `enemigo Player [1]`, así que la adquisición también anda.

**Y el comando perdía su mejor línea sin decir cuál.** `phantasmagoria_ghost_where` imprimió pos,
vida, modelo y enemigo — **y no las tareas**. `HUD_PRINTCONSOLE` viaja por un user message `TextMsg`
con techo de **255 bytes**, y al pasarse **no trunca: el servidor se niega a mandar la línea entera**
(`Refusing to send user message TextMsg of 256 bytes`). De las seis líneas se perdió exactamente la
única que crece sin techo, que era la más informativa. **El único rastro fue un aviso del engine que
no nombra la línea perdida**, así que la salida pasa por completa si no se la lee contra la esperada.
Arreglado troceando toda línea a 180 bytes y sacando una tarea por renglón.

**Y queda un check sin ejercer, dicho en voz alta:** `gm_uh_house` trae **3340 navareas**, así que el
arreglo del aviso —el `timer` que re-mide a los 10 s— **no corrió**. El silencio fue el resultado
correcto para este mapa y **no prueba la rama nueva**: hace falta volver al mapa de la corrida 1.

### Corrida 3, en `gm_graysonhouse`: **CHECK CERRADO, cinco filas verdes**

El check que la corrida 2 dejó abierto se cerró volviendo al mapa sin navmesh:
`0 navareas al spawnear` → **`van 42 navareas a los 10 s`**. Y `ghost_where` trajo **las 31 tareas**,
que era la línea que se perdía.

**Las 31 tareas no son ruido: son el inventario del cerebro heredado.** Ahí está la §5 de la
referencia hecha lista y corriendo — `movement_watch` (el comportamiento HIM ya escrito),
`movement_stalkenemy`, `movement_camp`, `movement_backthehellup`, `movement_followsound`. **Lo que
falta no es escribir eso: es elegir cuándo.**

**Y el mismo comando destapó que el número era una foto.** A los 10 s: 42 navareas. Un rato después:
**137**. El parcheador sigue creando areas donde pisan bots y jugadores, así que el mensaje decía
«construyó 42» de algo que seguía creciendo — **tercera vez en este arco que un número medido en un
instante se escribe como si fuera permanente**. Ahora dice «van 42 … y sigue trabajando».

**Cuarto defecto del instrumento: la etiqueta tapaba media pantalla de cerca.** `cam.Start3D2D` con
escala fija crece sin techo al acercarse, y a **1,3 m** el `PHANTOM #276` no entraba en la pantalla —
justo cuando más querés ver. La escala ahora sigue a la distancia, calibrada contra la corrida 2 (a
4 m, escala 0,35), con topes. Sin confirmar en juego.

**El balance del arco: cuatro defectos, los cuatro del instrumento, ninguno del fantasma.** Las
cuatro filas del bot salieron verdes a la primera — **la lectura de la base era buena**. Todo lo que
falló fue lo que se agregó encima, y cada caso por lo mismo: **medir un escenario y escribir sobre
otro**. Un aviso que predijo el futuro desde un instante, un marcador de exteriores probado en un
interior, un límite de 255 bytes que descarta en vez de truncar, y un texto calibrado a 4 m mirado a
1,3 m.

---

## 2026-08-05 — Sesión 14: la primera entidad, escrita como instrumento

**La primera línea de código del proyecto.** `lua/entities/terminator_nextbot_phantom/` —
`shared.lua`, `server.lua`, `client.lua`. **Sigue habiendo 0 corridas en GMod**: esto es código sin
ejercer, y el check está declarado en ESTADO.md *antes* de correrlo.

**No es un fantasma, es un instrumento.** Existe, spawnea, camina y **muestra dónde está**: caja
violeta + haz + etiqueta con la distancia en metros, dibujados con `cam.IgnoreZ` **a través de las
paredes**. Sin eso, un modelo negro sin ojos en un mapa oscuro es indistinguible de «no spawneó
nada». Y el marcador tiene un segundo instrumento al lado que **falla distinto**:
`phantasmagoria_ghost_where` corre en el servidor y ve también lo que está fuera del PVS.

### La contradicción del documento, resuelta a favor del plan

ESTADO.md traía un snippet con `ENT.IsWraith = true` y, treinta líneas más abajo, el plan del autor
diciendo que **no** hay que ponerlo todavía. Vale el plan: **un instrumento invisible no sirve para
ver dónde está.** El snippet quedó reemplazado por la descripción de lo que realmente se escribió.

Por la misma razón el bot queda **hostil a propósito**: el criterio de cierre es «camina hacia algo»
y hace falta un algo. El interruptor fantasma/cazador es la próxima pasada, y va en
`OnFirstRelationWithPlayer` — **nunca** en `DisableBehaviour`.

### Cuatro cosas nuevas de la base, que salieron de escribirla y no de leerla

Están en [§4.4](docs/PHANTOM_Referencia.md) con archivo y línea:

1. **El punto de entrada de una entidad-carpeta es `shared.lua`, no `init.lua`** — el registro
   termina en `list.Set( "NPC", … )` y **el spawnmenu se arma en el cliente**. El snippet que
   arrastraba ESTADO.md metía el molde de un archivo *suelto* dentro de una *carpeta*. Se siguió el
   precedente de HIM, que es exactamente el mismo caso: subclase en otro addon, en carpeta.
2. **El navmesh es precondición del check.** La base avisa, pero **solo al creador** — y si la
   spawnea un script, no hay creador. Es la causa número uno de «spawnea y no hace nada», así que el
   aviso se reimplementó en tres líneas.
3. **`Spawnable` y `RegisterNPC` son dos listas distintas** (Entities y NPCs). Las 11 subclases de la
   base ponen `Spawnable = false` a propósito, para no estar duplicadas.
4. **`TERM_FISTS = false` apaga dos cosas que no son el puño**: sin puños el bot no mira hacia su
   objetivo al moverse ni pega para desatascarse.

### Y una corrección a la referencia

**`OnFirstRelationWithPlayer` no es una función vacía.** §4.2 citaba la línea 947, que es **la
llamada**; la definición está en `damageandhealth.lua:872` y su cuerpo implementa
`ExtraSpawnHealthPerPlayer`. Un override que no encadene al `BaseClass` **mata esa mecánica en
silencio** — hoy no duele porque no declaramos el campo, y por eso mismo el defecto sería invisible
hasta que alguien lo declare. De paso: la llamada pasa **cuatro** argumentos y la declaración nombra
uno.

### El instrumento de sintaxis también se midió

`luaparser` rechazó los dos archivos que usan `continue`. **El control lo refutó**: el mismo parser
rechaza `terminator_nextbot_fakeply.lua`, que corre en GMod hoy — `continue` es extensión de GMod y
no de Lua 5.1. Con el token neutralizado, los tres archivos parsean. **La medición decía «tu código
está roto» y lo que estaba roto era la regla del parser.**

---

## 2026-08-03 — Sesión 12: la primera medición en juego, y refutó al documento

**Primer dato del proyecto que sale del juego y no de leer código.** El bloqueante que la sesión 11
había dejado marcado —*¿`MASK_BLOCKLOS` choca con `prop_physics`?*— se midió con una caja delante y
dos traces idénticos salvo el mask:

```
control  (mask por defecto)   ->  true    Entity [59][prop_physics]
medicion (MASK_BLOCKLOS)      ->  false   [NULL Entity]
```

**Los props NO cortan la vista de la base.** El documento afirmaba que «debería» cortar, razonando
que el mask incluye `CONTENTS_SOLID` y que el `.phy` de un prop lo es: razonamiento plausible,
conclusión falsa. **El engine también es un tercero** — cuarta vez en este proyecto, y la primera en
que la medición llega *antes* de escribir el código en vez de después.

**El control es lo que la vuelve concluyente.** Sin él, un `Hit = false` sería indistinguible de «no
le estaba apuntando a la caja».

### El arreglo, y por qué es chico

`LineOfSightMask` es **por entidad con fallback al global** (`shared.lua:2960`), así que declarar
`ENT.LineOfSightMask` en el phantom alcanza. Y sus **tres** usos son la misma clase de pregunta —
`CanSeePosition` (`:574`) y los dos «¿vería al enemigo de pie / agachado?» (`:1108`, `:1137`)—, o sea
que cambiarlo los mueve coherentemente. **No toca** `terminator_Extras.PosCanSee`, que es global y
sigue con `MASK_BLOCKLOS`: ahí vive el filtro de la dispersión, que pregunta otra cosa.

**Qué mask poner queda SIN decidir a propósito.** Elegirlo leyendo la lista de constantes es
exactamente lo que acaba de fallar; §18.6 trae el barrido que los prueba a los cinco en juego, con
`MASK_BLOCKLOS` incluido **como control**.

### Y probablemente sea deliberado en la base

Un cazador que pierde el rastro detrás de cada silla se siente roto: ver a través del desorden es una
*feature* para un Terminator. Para un fantasma de Phasmophobia es lo contrario. **Tercera vez en §18
que «heredado» no es «correcto».**

### El barrido, corrido en la misma sesión: `MASK_SOLID`

Cinco masks contra la caja y contra una pared. **Contra la pared pegan las cinco** — o sea que la
rama catastrófica (que la base fuera omnisciente) **está muerta**. Contra la caja sólo la ven
`MASK_SOLID` y `MASK_SHOT`.

Decodificar los valores dio lo que no se había preguntado: **los tres masks que atraviesan la caja
tienen `CONTENTS_SOLID` igual que los dos que la ven.** Lo único que separa a los grupos es
**`CONTENTS_MONSTER`** — es decir, un `prop_physics` no se presenta como `CONTENTS_SOLID` ante un
trace de entidad, y `CONTENTS_MONSTER` es en la práctica el bit de *«esto es una entidad»*. La
consecuencia excede a las cajas: **`MASK_BLOCKLOS` ≈ sólo geometría del mundo**, y el bot heredado ve
a través de cualquier entidad no-brush.

Elegido **`MASK_SOLID`**: de los dos que sirven, `MASK_SHOT` trae `CONTENTS_DEBRIS` (gibs cortando la
vista) y `CONTENTS_HITBOX` (precisión de bala, más cara, y este trace corre por enemigo y por
barrido). Efecto secundario declarado: `MASK_SOLID` incluye `CONTENTS_MONSTER`, así que **jugadores y
NPCs pasan a ocluir**.

**Y una corrección más, del mismo tipo que la de arriba:** este documento afirmaba dos veces que
`MASK_BLOCKLOS` incluye `CONTENTS_OPAQUE`. **Falso** — 16449 no tiene el bit 128. Razonar sobre la
constante de memoria falló otra vez; el número medido lo desarmó.

### §19: la cordura, y la trampa de NEAD

La cordura no es una feature al costado: **es el gatillo**. §18 diseñó *cómo* caza el fantasma; el
umbral de cordura decide *cuándo*, así que sin ella §18 es un motor sin llave.

**Y estaba más diseñada de lo que dije.** Leí §4 —diez líneas— y concluí «es un stub», sin mirar que
**la mitad vivía en `EQUIPAMIENTO.md` §3.5** (la barra de Cargo, la vela que frena el drenaje,
`eqp_sanity_pills` con masa, los costos de las 7 posesiones) y que **`ghost_types.lua` ya trae
`hunt.threshold` en los 30 tipos**, con rangos low/high en 12. También afirmé que no teníamos modelo
de pastillas: **`models/phas/eqp_sanity_pills.mdl` estaba en el árbol**. Dos afirmaciones sin mirar,
en la misma respuesta.

Decisiones del autor: drenaje **10-20 min** *condicionado a que existan eventos paranormales* —una
barra que baja sin que pase nada no es tensión—, ámbito **por jugador** (el promedio es lectura, no
variable), y las pastillas **con 3 tiers**.

**Mecánica nueva, de las capturas del camión:** además de TEAM SANITY (promedio + barra por
jugador), hay un **TOTAL ACTIVITY 0-10** dibujado como historia contra el tiempo, donde 10 es hunt
sostenido. No estaba en ningún documento. Y la cordura va **detrás de un convar y en el camión, no
en el HUD**: verla te dice cuándo empieza el hunt, que es justo lo que el juego te hace estimar.

**La oscuridad la resuelve NEAD** (`nead_clientscript.lua:44-70`): seis muestras —lightmap horneado
y luz dinámica, en pies+10 y ojos, en ambos sentidos del vector— contra `NEAD_light_sen`. Es CLIENT
por fuerza. `NEAD_indark` **no se networkea**, así que se lee client-side si NEAD está montado —lo
que además respeta la calibración del usuario— y se muestrea igual si no.

**Y la trampa:** NEAD hace `ply:SetNoTarget(true)`, o sea `FL_NOTARGET`, que la base Terminator
respeta **en `ShouldBeEnemy` Y en el alerter**. Con NEAD montado, **un segundo a oscuras sin linterna
te vuelve invisible e inaudible para el fantasma** — la mecánica que §18.2 descartó, activada por un
tercero, en silencio. No es bug de nadie: NEAD existe para que la oscuridad esconda y Phasmophobia
para que no. Y **no alcanza con que nuestro bot no sea DrGBase**: NEAD sólo cachea NPCs y nextbots
DrGBase, pero `FL_NOTARGET` es una bandera global del engine. *Una integración puede alcanzarte por
un camino que su propia lista de entidades no contempla.*

Tampoco se arregla desde `terminator_blocktarget`: la bandera devuelve en la línea 434 y el hook
está en la 496. Hay que overridear `ShouldBeEnemy`, y falta decidir con cuánta precisión — la
opción simple **rompe `notarget` como herramienta de testeo**, que es la que §18 usó para medir.

### Y el «arreglo es un campo» era falso: hay **seis** rutas de percepción

Preguntado si se podía cerrar el tema, salió que no. `LineOfSightMask` cubre **dos** de las seis
formas en que el bot aprende dónde estás. Las otras cuatro: el **fallback «sin enemigos»**
(`shared:3203`, un jugador por tick, con `PosCanSee` **global** y `ClearOrBreakable` con `MASK_SOLID`
**hardcodeado** — ninguno consulta el campo), el **daño recibido** (a menos de 175 u actualiza
memoria **sin chequeo de vista**), el **sonido**, y **otro terminator delatándote** (`shared:4052`,
que importa para The Twins y para servidores con otros Terminators).

El comentario del autor de la base en la ruta 3 es `-- they are obscured by a prop`, y su respuesta
**no es «no te veo» sino «voy a chequear ahí»**: correcto para un cazador, lo contrario de lo que
pide un fantasma. Se apaga con la salida temprana que la propia base escribió —
`forcedCheckPositions = false`— y **eso no toca la investigación por sonido**, que es otra tarea
(`movement_followsound`) alimentada por otro subsistema. El fantasma sigue viniendo si hacés ruido.

Detalle que cambia el diseño de niveles de §18.2: `ClearOrBreakable` cuenta un prop **rompible** como
despejado. **Esconderse detrás de algo que se rompe no te esconde.**

**Cuarta vez en la sesión con la misma forma de error**, y ya no es mala suerte: el primer grep listó
cinco call sites de `UpdateEnemyMemory`, se leyeron tres, y se escribieron conclusiones sobre «el
mecanismo» como si fueran cinco — los dos salteados eran los que rompían la historia. No es que no
se encontraran: estuvieron impresas en pantalla y no se abrieron. **Cuando un grep devuelve N sitios
de algo que se va a describir como *el* mecanismo, se leen los N o se declara cuáles no.**

### La generalización, medida en la misma sesión

El mismo barrido contra un `npc_kleiner` —una entidad de clase completamente distinta a un prop— dio
**el mismo patrón exacto**: `MASK_SOLID` y `MASK_SHOT` le pegan, los otros tres lo atraviesan y
siguen hasta `worldspawn`.

La lectura de los bits pasó a medición: **`CONTENTS_MONSTER` es el bit de «esto es una entidad», y
`MASK_BLOCKLOS` es geometría del mundo y nada más.** El bot heredado ve a través de props, NPCs y
jugadores por igual. Con eso queda medido también el efecto secundario de elegir `MASK_SOLID`:
**jugadores y NPCs pasan a ocluir**, que era lo único de la decisión que estaba inferido.

Y un detalle que respalda el cambio: `CanSeePosition` termina en
`not tr.Hit or ( isentity(check) and tr.Entity == check )`. Con `MASK_BLOCKLOS` la rama derecha nunca
se cumple para un jugador o un NPC, así que todo pasa por `not tr.Hit`; con `MASK_SOLID` el rayo sí
pega en el objetivo y esa rama se vuelve el camino normal. **El swap no es un parche contra el diseño
de la función: es la mitad de la función que hoy no se usa.**

---

## 2026-08-03 — Sesión 11: zona segura, esconderse, y el hunt que la base **no** regala

El autor levantó tres huecos que la tabla de §2 daba por cubiertos. **Dos filas de esa tabla no
sobrevivieron releerlas contra el código**, y de los tres huecos **dos resultaron ser la misma
función de la base**, ya escrita y muerta detrás de un `if`.

### Lo que se refutó de nuestro propio diseño

| Fila de §2 | Qué decía | Qué es |
|---|---|---|
| `hazardousAreas` para encerrar al fantasma | «casi gratis» | **Falso.** Significa *«areas we took damage in»* y alimenta `AddAreasToAvoid`, que suma **costo**. Es un peaje, no un muro: si el único camino hacia vos lo cruza, **entra** |
| El hunt | «**gratis**» | Cierto y engañoso. La base *es* un cazador que te encuentra; el fantasma del juego está diseñado para **fallar** casi siempre. Gratis ≠ correcto |

### El hallazgo que ordenó las otras dos

`shouldNotSeeEnemy` (`enemyoverrides.lua:307-416`) **ya tiene adentro las reglas de Phasmophobia**:
linterna prendida `+80`, ruido reciente con bump por alcance, y la **dispersión** —cuando no te ve
claro **no guarda tu posición real**, guarda un punto al azar que se acerca cuanto más ruido hacés—.
Todo eso está muerto detrás de **una línea**: `if a >= maxSeen then return end`, donde `a` es el
**alfa del jugador**. El modelo existe para jugadores *transparentes*; para un jugador opaco —o sea,
todos— la función devuelve en la tercera línea. **El trabajo no es escribir un sistema: es cambiar
qué alimenta `seen`.**

### Cómo ve la base a un jugador — medido

Hacen falta **dos** filtros y los dos tienen que pasar: `ShouldBeEnemy` **y** `CanSeePosition`. La
segunda es **un solo `util.TraceLine` a un solo punto** (`MASK_BLOCKLOS`): no muestrea hitboxes, no
existe «parcialmente visible». **Y el punto cambia si estás agachado**, por una rama explícita en
`EntShootPos:186`:

| | Punto que se traza | z sobre los pies |
|---|---|---|
| De pie | hitbox de la **cabeza** | ~64 (estimado) |
| **Agachado** | **`WorldSpaceCenter`** | **18** |

Ojos del fantasma a **64** (`round(maxs.z − 8)`, `motionoverrides.lua:3883`). De ahí la cuenta que
contesta *«¿me tapa esta caja?»*: altura `H` a la fracción `t` del camino corta el rayo si
**`H > 64 − 46·t`**. Pegada a vos basta **18**; **de pie el rayo va horizontal a 64 y la misma caja
no tapa nada**. Conclusión: **agacharse detrás de un prop ya esconde, hoy, sin escribir una línea.**

### Una afirmación mía, refutada dos párrafos después de escribirla

La primera redacción de §18.2 usaba **la regla de los 100 u** como la frontera entre los dos niveles
de esconderse. Falsa por dos motivos independientes: esa regla vive **adentro de la función que yo
mismo había declarado muerta**, una subsección antes; y aun viva **no puentea el trace** —los dos
filtros tienen que pasar, así que sólo puede hacerte *más* difícil de ver—. **Leí como override lo
que era un AND.**

Desarmarla mejoró el diseño: el modo de falla real de la cobertura no es la distancia sino que **el
fantasma se mueve** —un paso al costado y la caja deja de tapar—, lo que re-justifica el hiding spot
por lo que de verdad lo distingue: **estar cerrado**.

### Decisiones del autor

| Pregunta | Respuesta |
|---|---|
| Zona segura | **Sólo targeting**, vía el veto público `terminator_blocktarget`. Entrás al camión y **te olvida**. Los props que te tira igual te pegan |
| ¿Aviso de «estás escondido»? | **No.** El juego no lo da: el **lugar** es el aviso |
| ¿Las sombras esconden? | **No.** Delata **el electrónico encendido en la mano**; por eso las sombras *parecen* ayudar |
| ¿Se revisan los escondites? | **Sí, y cuánto lo decide la dificultad** — fila nueva en §13, al lado de «se queda en su cuarto» |
| Equipo de terceros | Delata la linterna default más lo nuestro. El resto va como **capa de compatibilidad**, con la forma de `corpus_cargo_movecompat.lua` |

La segunda respuesta borró la parte cara del diseño: **cayó el nivel de luz como input**, que era el
único que pedía plumbing cliente→servidor (`render.GetLightColor` es CLIENT). El ocultamiento quedó
entero server-side.

### Lo que queda, y es un solo bloqueante

**¿`MASK_BLOCKLOS` choca con `prop_physics`? SIN MEDIR.** El mask incluye `CONTENTS_SOLID` y el
`.phy` de un prop lo es, así que *debería* — pero es **leer una constante, no medir el engine**.
Todo §18.2 depende de eso: si no chocara, esconderse detrás de una caja **no existe** y §14 pasa de
opcional a bloqueante. Es el primer check de la planilla y cuesta un minuto.

Más dos defectos de la base a arreglar antes de reusarla: `MaxSeeEnemyDistance` **no se aplica a
jugadores** (vista ilimitada salvo niebla, `:508`) y la dispersión **se invierte** pasando los 500 u.

---

## 2026-08-03 — Sesión 10: los pasos vuelven al fantasma, y un evento que no necesita assets

Continuación directa de la sesión 9, que había dejado a `ghost/` **sin banco de pasos**.

### La misma pregunta, hecha distinto, dio otra respuesta

En la sesión 9 la pregunta fue *«¿de quién es esta grabación?»* y el autor contestó *«del jugador, yo
lo reconozco del juego»* — correcto, y por eso los 8 se fueron a `player/footstep/carpet_loud_*`.
Esta sesión la pregunta fue *«¿para qué sirve acá?»* y contestó *«muy parecidos a la pisada de una
**bota**»* y *«como el jugador en Garry's Mod ya tiene su propio footstep, agregar este como pisada
de fantasma está ok»*. Volvieron como `ghost/footstep/boots_1-8`.

**Las dos escuchas no se contradicen y ninguna fue un error.** La grabación *es* de una persona
caminando; el **uso** en este addon es el fantasma, porque al jugador GMod ya le da los suyos. La
carpeta dice el uso, el `about.txt` dice el origen. **Cambió la pregunta, no el dato.**

### La medición que respalda el banco elegido

§1 pide que el fantasma se oiga a **20 m**, y a distancia sólo sobrevive el grave. Energía bajo
250 Hz / bajo 120 Hz / centroide, por banco:

| `stairs_under` | `wood` | **`boots`** | `stairs` | `asphalt` | `carpet` | `gravel` |
|---|---|---|---|---|---|---|
| 99,1 % · 65 Hz | 97,9 % · 103 Hz | **89,8 % · 183 Hz** | 72,5 % · 214 Hz | 40,1 % · 1264 Hz | 35,8 % · 1217 Hz | 2,3 % · 2261 Hz |

`carpet` y `gravel` son roce agudo: a 20 m no llegan. El banco de botas tiene cuerpo y aguanta.

### Otra lectura mía del nombre, refutada por el oído

Propuse `stairs_under` como el banco del evento leyendo `underneath_stairs_footsteps` como *«pasos
oídos desde debajo de la escalera»*, y el espectro parecía confirmarlo (94 % bajo 120 Hz, centroide
65 Hz — exactamente lo que suena estructural). El autor: *«son pisadas de una escalera»*. **El
espectro decía cómo suena, no qué es.** Su sospecha de que `under` sea *subterráneo* queda anotada
como sospecha: el crujido de madera de `stairs_under_2` apoya «escalera de madera», que no es lo
mismo que «sótano».

### El evento de pasos lejanos — §7.5, y no cuesta un asset

Pedido del autor, de una experiencia propia: pisadas lentas y pesadas a lo lejos, sin fuente visible.
**El rasgo ya existe** (`ability.paranormalSoundInterval`, 80-127 s; Myling 64-127) y **el banco
también** — son las botas sonando lejos. Lo que lo hace un evento y no un paso normal es *dónde* y
*a qué ritmo* suena: en una posición a media distancia y **fuera de línea de vista**, nunca en la
entidad, porque si sonara en el fantasma sería un localizador gratis que mata al spirit box, a la
parabólica y a la caja de música de un saque. Cadencia **pareja**: pasos aleatorios se leen como
ruido ambiente, pasos regulares se leen como *alguien*.

Y la crueldad sale de cruzar dos rasgos que ya estaban: **el Myling camina en silencio cazando**
(`IsSilentStepping`) **y es el que más sonido paranormal tira**. Hace ruido cuando no viene, y
ninguno cuando sí.

### La parabólica no existe — EQUIPAMIENTO §9

**36 modelos y ninguno es un micrófono**: ni Parabolic Microphone ni Sound Sensor. Y con la
identificación de sonido cerrada aparece el patrón: **la mecánica de delatar por sonido tiene audio y
le faltan props dos veces** — la Music Box (a 20 m el fantasma canta y delata su posición) ya tiene
su tarareo desde la sesión 9 y tampoco tiene modelo. Sin la herramienta, los pasos lejanos son
ambientación pura y no evidencia. Tres caminos anotados, **sin decidir** — lo que sí está decidido es
no fingir que la tenemos.

---

## 2026-08-03 — Sesión 9: los 46 sonidos identificados, y el fantasma que se quedó sin pasos

**Sin código.** El autor escuchó los 46 archivos de `_sin_identificar/` y los describió uno por uno.
Se movieron **65 archivos** (los 46 más 19 recatalogados), quedaron **265 de 265** mapeados por
acción, y la carpeta `_sin_identificar/` **ya no existe**.

### Lo que eran

Los tres grupos de §8.1 se cerraron: las **23 palabras sueltas** son respuestas del Spirit Box en voz
masculina y **literales al nombre** (`adult.ogg` dice «adult») salvo `Beep`, que es el motion sensor;
las **5 vocalizaciones** son del fantasma pero por función y no por daño; y los **8 `Hint`** no eran
ni Ouija ni spirit box sino **una voz británica** —el ayudante de la compañía— que resultó ser el
mismo hablante que `arrival`, `welcome_back`, `lobby_*` y `menu_intro`. Esos 20 estaban repartidos
entre `ui/` y sin identificar; hoy son `voice/`, con transcripción.

### La corrección que más cambia el diseño

**`GhostFootstepCarpet1-8` no eran los pasos del fantasma.** §7.1 los daba por suyos desde el
principio —por el nombre—, y el autor los reconoce como los del jugador. Se movieron, y `ghost/`
**quedó sin banco de pasos**: por la regla del árbol eso no es un error, es un fantasma que camina
en silencio. Queda anotado como abierto en §7.4 y en ESTADO.

### Medir antes de mover cambió qué se movía

La duda era si esos 8 eran una copia renombrada de `player/footstep/carpet_1-8`. Tres mediciones:

1. **16 hashes distintos** — no es el mismo archivo con otro nombre.
2. **Null-test** (alineado por correlación cruzada, ganancia por mínimos cuadrados): `corr`
   **0,32-0,80**, que es exactamente el rango de los controles cruzados y de dos tomas distintas del
   mismo set. Tampoco es una copia con otra ganancia — **mi hipótesis quedó refutada por mi propia
   medición**.
3. Pero las **duraciones emparejan una a una** (delta 2-11 ms en 7 de 8) y el set está **~10 dB más
   fuerte** (−17…−25 dB contra −27…−35 dB).

Misma superficie, **dos mezclas**. Por eso terminaron como `carpet_loud_1..8` y no como
`carpet_9..16`: metidos en un solo pool, el sorteo saltaría **13 dB entre pisada y pisada** — un
defecto audible que el nombre «correcto» habría creado en silencio.

La hipótesis alternativa del autor —que fueran las escaleras— **no sobrevivió**: `stairs_*` dura
0,25-0,52 s a −36…−43 dB y `stairs_under_*` 0,34-0,56 s a −21…−33 dB. Ninguno empareja como empareja
`carpet_*`.

### Lo que se decidió NO hacer

- **El Spirit Box quedó plano**, 22 archivos sueltos. Agruparlos por edad / parentesco / lugar /
  amenaza se lee solo, pero esa categorización sería **mía, no del autor**: el `about.txt` la sugiere
  como punto de partida y el corte va en el Lua. Con el pool entero, a «how old are you?» el fantasma
  puede contestar «kill».
- **Los 8 `hint` no se renombraron** aunque **dos** contradicen su nombre. El nombre viene del rip y
  la transcripción es de oído: cambiar una etiqueta dudosa por otra no es identificar. Lo que sí se
  escribió es el **orden por contenido**, que es lo que el Lua va a leer — ver abajo.

### La sospecha del autor, y la medición que no la apoya

El autor sospechó que `hint_friendly_ghost_2` **nunca se usó en el juego**, precisamente por lo raro
de su texto. No se pudo verificar, y **la única señal que lo habría apoyado dio negativa**: el audio
cortado suele delatarse en el formato, y éste no se delata.

Que coincida **significa algo**, porque el rip **no es uniforme** — 5 formatos entre los 265: 125 en
44100/mono, 71 en 44100/estéreo, 40 en 48000/mono, 22 en 22050/mono, 7 en 48000/estéreo. Y coincide
del todo: 44100/mono/s16 como las otras siete, `mean −27,0 dB` y `max −11,4 dB`, **el centro exacto
del grupo** (las otras van de −26,4 a −29,7 y de −11,1 a −13,2). Pasó por el mismo pipeline y el
mismo mastering que las líneas que sí se usan.

**Pero esto no refuta la sospecha, y no hay que escribirlo como si lo hiciera.** Una línea se puede
masterizar entera y quedar cortada después por un cambio de código, sin dejar rastro en el archivo.
Lo que dice la medición es que **el archivo no la apoya** — nada más.

### Y el autor tenía razón de más: son DOS los mal etiquetados

Ordenando las ocho por lo que **dicen** en vez de por cómo se llaman, aparece un segundo:
`hint_non_friendly_ghost_1` empieza literalmente con «nothing to report», y su único indicio es el
mismo «left in a hurry» que trae la línea agresiva. Con **2 de 8** mal puestos, deja de ser «un
archivo raro» y pasa a ser **la etiqueta del rip no es confiable como tier**. El orden por contenido
quedó escrito en el `about.txt`, que es donde el Lua lo va a buscar; los nombres siguen intactos
porque son el único rastro que queda hasta el rip.

### La regla

**Un nombre que describe al emisor no dice quién lo emite.** `GhostFootstepCarpet` describe
correctamente lo que se oye —una pisada sobre alfombra— y aun así atribuía mal quién la da. Sonaba a
persona caminando porque *eso* es lo que suena un fantasma caminando, y por eso el nombre sobrevivió
un mapeo entero sin que nadie lo dudara.

---

## 2026-08-02 — Sesión 8: StormFox 2 desempacado, y la API contra el addon que corre

**Sin código.** Se trajo el `.gma` suscrito (WSID `2447774443`, 307 archivos) a
`dev/other/stormfox 2/` con `gmad.exe`, para leer el mod **independiente de su repo de GitHub**.

### La afirmación de §15.2 se fortalece

Las 8 funciones y los 2 hooks que el diseño daba por *«verificado en su repo»* existen **en el addon
que realmente corre**, y los números de línea de la tabla coinciden. Un repo puede estar adelantado,
atrasado o en otra rama respecto de lo publicado; el `.gma` es lo que se ejecuta.

### Cuatro cosas que la tabla de firmas no podía decir

Salieron de leer los **cuerpos**, y las cuatro cambian cómo se usa la API:

1. **`Weather.GetCurrent()` devuelve la TABLA del clima** (`.Name`, `.Inherit`), no un string.
   `MapStormFoxWeather()` tiene que leer esos campos.
2. **La nieve no es un clima aparte: es lluvia bajo −2 °C.** La temperatura **causa** la
   clasificación, así que termómetro y nieve dejan de ser señales independientes. Y un clima que
   *hereda* de `Rain` da `IsSnowing()` **siempre false**, a cualquier temperatura.
3. **`GetRainAmount()` devuelve 0 mientras nieva** — arranca con `if not IsRaining() then return 0`.
   Sirve para graduar lluvia, no como cantidad de precipitación.
4. **`Temperature.Get()` con un tipo inválido avisa y después crashea** indexando un `nil`. Y su
   anotación LuaLS dice `---@return Color` cuando devuelve un número.

Más una trampa de catálogo: el mod **mezcla mayúsculas** en sus hooks —`StormFox2.weather.postchange`
en minúscula, `StormFox2.Weather.Think` capitalizado—. Normalizarlos da un hook que nunca dispara y
**no da error**.

### Y un «regalo» nuestro que quedó REFUTADO

§15.2 se anotaba dos: la mecánica de la vela y **«`DownFall.IsPointHit` es un tercer detector de
interior/exterior»**. El segundo es falso. Su primera línea es
`if not Weather.HasDownfall() then return false end`, y `HasDownfall` sólo es true con clima `Rain` o
heredado de `Rain`: **con cielo despejado devuelve false en todo el mapa, adentro y afuera**. Mapear
cuartos con eso daría «todos bajo techo» los días de sol, en silencio y sin error. Y aun lloviendo
tampoco lo es: su trace no va hacia arriba sino **en la dirección del viento**, así que contesta «¿le
está llegando la precipitación?» — que es justo lo que la vela necesita y justo lo que los cuartos no.
El detector de interior/exterior sigue siendo el de §14.1.

**La lección:** una función cuyo nombre describe **geometría** puede estar cerrada por una condición
de **estado** que el nombre no menciona. Las 10 líneas de la tabla de §15.2 apuntaban todas a la
declaración correcta — el error no estaba en la firma, estaba en el cuerpo.

### Corregido en el acto

Anuncié que el diseño «documentaba dos argumentos» de `postchange` y que el tercero era un hallazgo.
**Falso: el ejemplo de §15.2 ya tenía los tres.** Lo que faltaba era la firma de `prechange`, que
lleva **dos**. Corregido en el mapa de mods antes de que la afirmación se asentara.

---

## 2026-08-02 — Sesión 7: las huellas UV existen, y no eran lo que dije

**Primer asset generado del proyecto.** Decisión del autor: reciclar el material de gmpa en vez de
dibujarlo, con el crédito correspondiente.

### La corrección, y de dónde salió

En la sesión 6 escribí que gmpa traía «cuatro huellas de mano, izquierda y derecha, dos variantes» y
que **60 s de fade eran exactamente la duración de las huellas en Phasmophobia, así que el autor las
hizo para eso**. Las dos afirmaciones eran inferencias — del **nombre del archivo** y de un número
que coincidía. **Se decodificaron los cuatro `.vtf` y se miraron:**

- Son decals de **SANGRE**, rojo oscuro sobre blanco, shader `DecalModulate`. `$decalfadeduration 60`
  es un valor corriente de decal de gore.
- **Dos de los cuatro no son huellas.** `hand_l2` y `hand_r2` son **arrastres** de cuatro dedos
  raspando una superficie.

Los cuatro `sha256` sí son distintos, así que son cuatro texturas reales y no una repetida
(contrastado antes de asumir). **La lección, en su versión visual:** el nombre de un archivo miente
igual que un comentario — y acá sí había forma de refutarlo mirando, y no lo hice hasta la segunda
pasada.

### Hecho

- **[`dev/uv_prints.py`](../dev/uv_prints.py)** — deriva las cuatro texturas y explica cada paso.
  La forma vive en **dos canales**: el alfa recorta la silueta y el RGB lleva el detalle interno.
  Aplanar a blanco tiraba el detalle; usar sólo el RGB arrastraba el fondo. La derivación usa los dos
  — `máscara = alfa × invertir(luminancia)`, salida con RGB blanco — y el resultado es una **máscara
  teñible**: el azul-UV lo pone `SetDrawColor` en el cliente, sin una textura por color.
- **`materials/phantasmagoria/uv/`** — `hand_left`, `hand_right`, `smear_left`, `smear_right`.
  **Los nombres dicen lo que la cosa es**, no lo que decía el origen. **Namespace nuestro**, no el de
  ellos: dos addons montando la misma ruta es la colisión que `phantasmagoria_assetcheck` detecta.
- **Crédito con hash** en [docs/CREDITOS.md](docs/CREDITOS.md) — el `sha256` de cada `.vtf` de origen,
  para que el crédito sea verificable en las dos direcciones.
- [docs/ASSETS.md](docs/ASSETS.md) al día: los 36 props ya no son «pendiente de descargar», y las
  huellas UV **se generan, no se descargan**.

### Verificado

Los cuatro PNG escritos, releídos de disco: RGB uniforme en 255 (máscara pura) y alfa con la silueta
y su detalle. Compuestos sobre un gris de pared y teñidos de azul-UV, se leen como huellas.
**Nada de esto se vio en GMod todavía.**

---

## 2026-08-02 — Sesión 6: leer gmpa entero, y la evidencia UV

**Sin código.** Se leyeron las 1056 líneas de `gm_paranormalactivities.lua` de una sentada, en vez de
buscar bugs puntuales. Aparecieron seis defectos más y un asset huérfano.

### El defecto que cambia cómo se siente el mod

**La escalera de eventos no es exclusiva.** `RandomParanormalEvents()` tira `math.random(1,100)` una
vez y encadena **nueve `if eventChance <= N` sin un solo `elseif`**. Un tiro de 3 dispara **los
nueve** en el mismo frame: puerta + luz rota + botón + sonido + sangre + fling + parpadeo + susurro +
aparición. No es «un evento cada 120 s»: a veces pasa todo junto. Se copia la **lista** de eventos;
la escalera se reemplaza por una tabla de pesos.

### Dos entradas de §9 estaban mal, y eran nuestras

- **`FlingNearbyPhysicsProps` nunca corrió.** Su único call site testea `IsValid(ghost)` sobre un
  **global que no se declara en ninguna parte** (sólo existe como local dentro de
  `CreateGhostApparition`), así que la rama es inalcanzable. La función se lee sana, pero **nadie la
  ejerció**: era «gratis» en nuestra tabla y en realidad es código sin probar.
- **`BreakNearbyProps` no rompe props físicos.** Sólo `func_breakable` recibe `Fire("Break")`; a un
  `prop_physics` le aplica la misma fuerza random que Fling, sin límite de masa y sin sonido. No es
  «la versión brutal»: es Fling con menos guardas.

**La regla:** el nombre de una función miente igual que un comentario, y «la llama el propio mod» es
una suposición hasta que se busca el call site.

### Otros cuatro

Fuga de timers a 33 Hz (`GhostDistort_<entindex>`, `timer.Remove` no aparece nunca); `HuntPlayer`
apilando un timer de borrado por llamada; el debounce de puertas comprobado **después** de disparar
`Fire("Use")`; y `CheckFlashlightEffects()` entera muerta porque compara contra `weapon_flashlight`,
que no existe en GMod base.

### El hallazgo: gmpa trae cuatro decals que su Lua no usa jamás

`hand_l1/l2/r1/r2` (`.vmt` + `.vtf`) en `materials/effects/gmpa/decals/`, `DecalModulate` con
`$decalfadeduration 60.00`. **En 1056 líneas la palabra «decal» aparece una sola vez, en un
comentario.** Qué son exactamente esas cuatro texturas **no se miró en esta sesión** — se infirió del
nombre del archivo, y la sesión 7 refutó la inferencia.

### Diseñada la evidencia UV (EQUIPAMIENTO §8, nueva)

`uv` la tienen **13 de los 30 tipos** (medido sobre `ghost_types.lua`): sin ella, 13 tipos quedan sin
identificar. **Un PNG no puede ser un decal** (verificado: un decal pide `.vmt` con `$decal 1` +
`.vtf`), **pero sí puede ser un material dibujado a mano** (verificado: Cargo carga PNGs así en
producción). Y el decal es la herramienta equivocada igual: se ve siempre y para todos, cuando la
mecánica pide invisible-hasta-la-UV. La forma elegida es guardar la huella como **dato** server-side
y dibujarla client-side con `cam.Start3D2D` bajo la puerta de «tengo la UV apuntando» — que compra
además el teñido y el fade por código. La huella de sal (`salt_step.mdl`, que es un **modelo**) viaja
por la misma puerta con `SetNoDraw(true)`.

---

## 2026-08-02 — Sesión 5: qué forma tiene el equipo, y qué le da Cargo

**Sin código de entidades.** Se contestaron tres preguntas del autor y se corrigió un error propio.

### Medido

- **Los 36 modelos tienen `numbones = 1` y `numseq = 1`**, sin excepción (`dev/mdlinfo.py`). Eso
  decide la forma del equipo antes de discutirla: **no hay rig para `UseHands`** (el viewmodel
  flotante no es una elección estética, es la única opción sin recompilar) y **no hay animación**
  (todo el movimiento es código). Ver EQUIPAMIENTO §5.1.
- **Los 13 `.phy` del Prop Pack, uno por uno**: **6 en 1000 kg** y **7 en 100**, no trece en 1000.
  Los 13 declaran `surfaceprop metal` — de ahí que la sal sonara a chapa.

### Corregido — un error de la sesión anterior

EQUIPAMIENTO §1.2 afirmaba que el Prop Pack «clavó `1000` a mano en **todos** sus props». **Falso, y
lo desmiente la misma fuente que el párrafo citaba**: la frase generalizó a 13 desde los 3 casos de
su propia tabla, y ninguno de los otros diez se había abierto. `prop_data.lua` arrastraba la misma
frase en su header **mientras el comentario de su tabla, 35 líneas más abajo, decía «100 o 1000»**:
el archivo se contradecía a sí mismo. Corregidos los dos.

**No cambió ninguna decisión** — 100 kg para una linterna es igual de inusable que 1000 para un
crucifijo, y la vía sigue siendo `SetMass()` en runtime. **El código nunca dependió del error**: la
tabla fija una masa objetivo por modelo, no una corrección uniforme. Prosa mal, código bien.

### Diseñado (EQUIPAMIENTO §5 y §6, nuevas)

- **El reparto del equipo en cuatro formas** — SWEP lo que se sostiene, entidad lo que se planta y lo
  que es escenografía, ítem con `onUse` lo que se consume.
- **Integración con Cargo**, leída contra su código. El hallazgo que manda: **la captura de Cargo se
  come cualquier SWEP que el engine entregue** y le fabrica un def `autogen` de 2,5 kg sin precio.
  Con Cargo montado pasa igual — la elección es registrar defs propios o que salga mal solo.
- Tres registros de Cargo que encajan casi literalmente: `Wheel.RegisterLightSource` (linterna, UV,
  glowstick), `StatusPanel.RegisterBar` (la cordura de §3.5), `Capture.RegisterWorldPickup`.
- **El límite:** Cargo **no** tiene API para registrar slots. O categoría `weapons` + `equip_slots`
  (y se gana el hotbar 1-4 y el wheel gratis), o un `Slots.Register` que es trabajo de Cargo.

### Frontera declarada

Que un prop de 1 hueso y 1 secuencia funcione como `SWEP.ViewModel` **[sin verificar]**: los SWEPs de
`dev/other/` usan todos viewmodels dedicados `v_`/`c_`, ninguno un prop pelado. El camino alternativo
—dibujarlo a mano con `ClientsideModel`— **sí** tiene precedente leído (el NVG de Neosun), y su costo
es conocido: se dibuja en la pasada del mundo, así que atraviesa paredes.

---

## 2026-08-02 — Sesión 4: los props de equipamiento, verificados bit por bit

### Hecho

- **36 modelos consolidados** en `models/` + `materials/` desde tres packs del Workshop, con las
  rutas **verbatim** (no se renombró nada: los `.mdl` las llevan horneadas).
- **Detector de addons duplicados** — `lua/autorun/phantasmagoria_assetcheck.lua`. Compara los WSID
  incluidos contra `engine.GetAddons()` y **avisa**: no desmonta, no bloquea, no rompe nada. Se
  silencia con `phantasmagoria_assetcheck 0`.
- **[docs/CREDITOS.md](docs/CREDITOS.md)** y **[docs/EQUIPAMIENTO.md](docs/EQUIPAMIENTO.md)**.
- Los packs originales se borraron de `dev/` una vez consolidados (evita 265 MB duplicados en disco).

### Verificado (parseando `studiohdr_t`, no leyendo el Workshop)

- **0 colisiones de ruta entre los tres packs** — usan namespaces distintos (`kiwontatv/`, `phas/`,
  `phasmophobia/demit/`), así que conviven.
- **62 referencias `.mdl` → `.vmt` resueltas, 0 faltantes**, 0 `.vmt` apuntando a `.vtf` inexistente,
  0 acompañantes (`.vvd`/`.vtx`) faltantes.

### Tres correcciones a lo que dice el Workshop

1. **El K2 no tiene bodygroups: tiene 6 skins**, y son mejores. `bodyparts=1, nmodels=1` (cero
   bodygroups reales) y `numskinfamilies=6`. La tabla intercambia `level_0N` por `level_0N_active`
   de forma **acumulativa**, así que `SetSkin(0..5)` **es** la lectura EMF. Son 6 estados, no 5: el
   0 es "apagado".
2. **Las masas del Prop Pack son 100 o 1000 kg sin excepción.** Un crucifijo de una tonelada no se
   levanta con la mano. El Equipment Pack tiene masas realistas (0,1–7,2 kg) y por eso es el que
   conviene por defecto.
3. **El libro abierto tiene 7 skins en un pack y 8 en el otro.** La octava del Prop Pack es
   `book_cursed_demit`, la firma del autor: sortear `0..7` la sacaría como si fuera escritura del
   fantasma.

### Defecto del pack original, corregido

`eqp_flashlight_strong.mdl` declara la textura `Strong Flashlight Glass` y **el pack no la incluye**:
el lente salía con checkerboard morado. Se escribió el `.vmt` faltante, marcado como nuestro en
CREDITOS. El nombre lleva espacios y mayúsculas porque es la cadena horneada en el binario.

### Pendiente anotado

**251 MB en 58 texturas, todas 2048×2048 DXT5** — incluidas las de un encendedor y unas pastillas.
Bajar a 1024² ahorraría ~190 MB por cliente y sería invisible en juego. **No se tocó**: es modificar
el asset de un tercero.

---

## 2026-08-02 — Sesión 3: paranormal events es 1:1, y el sistema de cuartos

**Sin código.** Diseño de spawn, dificultad y cuartos, más una corrección de evaluación.

### La corrección: subestimé `[gm] paranormal events`

En la sesión 2 lo describí como «banco de efectos, no sistema». **Era un error, y el autor lo
señaló.** Leído con la lente de Phasmophobia, el mod implementa los mismos conceptos con los mismos
nombres: **Ghost Orbs** (una evidencia entera), **favourite room**, **aggro → hunt**, interferencia
de linterna, luces parpadeando, y los **tres tipos de manifestación** que nombra la wiki (visible,
sombra, translúcida). Sus 24 convars son el mejor borrador que tenemos de las nuestras.

Lo que está roto es la implementación, no el diseño. Tres defectos verificados a mano:

- **`if !IsValid(pos)` sobre un `Vector`** (líneas 852, 860, 868): siempre falso, así que
  `CreateGhostOrbs`, `CreateShadowLurker` y `CreateCockRoachSwarm` **nunca emiten su partícula**.
  Además las tres pisan su propio argumento con `local pos = ...` en la línea anterior.
- **`favoriteRoom = Vector(1000, 1000, 100)`** (línea 93), hardcodeado, con el comentario del autor
  `-- change this based on your map`. Es exactamente la carencia que resuelve el sistema de cuartos.
- **`GetConVar("gmpa_ghost_damage")` sin `CreateConVar`**: la función de daño es inalcanzable.

`HuntPlayer()` mueve al fantasma con `SetPos(pos + dir * 10)` — teleporte por tick, atravesando
paredes. Es la razón por la que este proyecto existe.

### Diseñado

- **Spawn por dos vías** (§12): `phantasmagoria_autospawn N` mantiene una población de tipos
  sorteados —la vía que le sirve a un gamemode— y **un NPC por tipo en el menú**, generados en un
  bucle sobre la tabla, no escritos a mano.
- **Dificultad** (§13): una convar con cinco presets. No cambia al fantasma: cambia cuánta ayuda da
  el juego. En amateur **se queda en su cuarto**; en Nightmare/Insanity se ocultan evidencias
  *emitidas*, sin tocar el tipo real.
- **Sistema de cuartos** (§14): flood fill sobre navareas con techo, cortando por puertas; toolgun
  `phantasmagoria_rooms` para corregir a mano; persistencia por mapa en JSON con IDs de `CNavArea`;
  y puntos marcados para los ítems malditos.

### Encontrado: la primitiva de «cuarto» ya está escrita y probada

`IsUnderSkyPos()` de HIM (`sv_zhomeless_shelter.lua:272`) hace un trace de 12.000 u hacia arriba con
`CONTENTS_SOLID` y decide interior/intemperie; y lo envuelve en `IsUnderSky( area )` **cacheado por
`CNavArea`**, que es justo el granulado que hace falta. Hay dos alternativas medidas: `get_env_state`
de Better Movement (5 traces, más robusto contra huecos en el techo, ya networkeado como
`ply:GetBmEnvIsInside()`) y `GetNookScore` de la base (mide *encierro*, no techo).

### Decidido

- Si un mapa no tiene cuartos marcados, **el addon degrada, no se rompe** (§14.5): la favourite room
  pasa a ser la navarea con mayor `GetNookScore`. El 99 % de los mapas de GMod nunca va a tener
  mapeo, y arrancar igual no es opcional.

---

## 2026-08-01 — Sesión 2: el giro a Phasmophobia, y el repo

### El cambio de rumbo

PHANTOM dejó de ser «un fantasma que te observa y se aleja» y pasó a ser **un motor de rasgos** que
recrea los 30 tipos de Phasmophobia. Nada del diseño anterior se tiró: el comportamiento de observar
es ahora el estado *fuera del hunt*, y el destierro pasó a ser un desenlace posible del hunt.

### Hecho

- **Repo creado.** `phantasmagoria/`, licencia MIT, `.gitignore` que excluye **todos** los assets.
- **Tabla de los 30 tipos generada** — `lua/phantasmagoria/ghost_types.lua`, 673 líneas.
  **No está escrita a mano:** sale de `dev/gen_types.py` sobre datos reales del juego. Valida
  sintaxis con `luaparser`.
- **Audio convertido:** 265 `.wav` → `.ogg` Vorbis q4. **141 MB → 11 MB (−92 %)**, 0 fallos.
  Originales intactos. Duraciones verificadas contra el original: **delta 0,000 s** en la muestra.
- **Borrados** `schizophrenia_v2` (39 MB) y `the hat man` (5,9 MB) por decisión del autor.
- Documentos movidos a `docs/` y rutas relativas reajustadas.

### La fuente de datos, y cómo se consiguió

La wiki de Fandom devuelve **HTTP 402** y el cheat sheet de tybayn es una SPA sin datos en el HTML.
Los datos reales salen de un endpoint que el propio cheat sheet consume:

```
https://zero-network.net/phasmophobia/data/ghosts.json?lang=en
```

**Requiere cabecera `Referer`/`Origin`**: sin ella responde `{"detail":"Not authorized"}`. Con ella,
62 KB con los 30 tipos, velocidades en m/s, umbrales de cordura, evidencias y notas de comportamiento.
Se llegó a él leyendo `scripts-v10/zn-v5.js:152` del repo del cheat sheet.

### Medido

- Los **seis tipos que no conocíamos** (Aswang, Gallu, Kormos, Deildegast, Obambo, Dayan) quedaron
  documentados con datos duros. **Ninguno rompe el motor**: todos son variantes de estados cíclicos,
  velocidad condicional o detección condicional. El corte de rasgos aguanta.
- Velocidades reales del juego: de **0,4 m/s** (Deogen de cerca, Deildegast frenado) a **3,0 m/s**
  (Revenant persiguiendo). El Spirit a 1,7 m/s es la unidad de referencia.
- Umbrales de cordura: de **10 %** (Obambo calmo) a **75 %** (Thaye).

### Decidido

- **La velocidad se deriva del jugador**, no de la wiki: los tipos son multiplicadores de la carrera
  real. Con Better Movement en `run 280`, un Spirit corre a 280 u/s.
- **El desenlace del hunt es un rasgo** (`ability.onCatch`): unos tipos matan, otros destierran.
- **Volver del destierro:** muriendo (rápido y aburrido) o por un ritual (el camino que puede salvar
  a alguien si esto termina en un gamemode).
- **Sandbox, no gamemode.**

### Trampa encontrada (no costó nada porque se vio antes de escribir código)

**`ply:GetRunSpeed()` no sirve para calibrar velocidad con Better Movement montado.** El mod escribe
en la API nativa (`sh_bm_main.lua:455`) pero multiplica por `_bmfraction`, un factor **dinámico**
clampeado entre 1 y 2. El getter devuelve **entre 280 y 560 según el instante en que lo leas**. Hay
que leer la convar base `sv_bm_speed_run`. `GetConVar("sv_bm_enabled") == nil` es el chequeo de
existencia del mod.

---

## 2026-08-01 — Sesión 1: investigación de la base

**Sin código.** Esta entrada existe para que la sesión 2 no empiece de cero.

### Alcance

Seis addons, **55.425 líneas de Lua en 125 archivos**, leídos con 14 lectores en paralelo. Cada API
afirmada fue auditada por un segundo pase que intentaba refutarla: **1.042 afirmaciones — 882
confirmadas, 147 imprecisas, 13 refutadas**.

### Lo que se descubrió

- **El comportamiento pedido ya estaba escrito en la base.** `movement_watch`
  (`shared.lua:6001`) se planta a distancia, se prohíbe disparar y mide si el jugador la mira con
  `enemyBearingToMeAbs() < 9`. El comentario del autor: `-- this is not a SNIPING behaviour!`
- **El fantasma se activa con un campo:** `ENT.IsWraith = true`.
- **La dimensión extra ya existía** en HIM: teleport a `Vector(80000,80000,80000)`, niebla negra,
  skybox tapado, `PreventTransmit` recursivo.
- `schizophrenia_v2` fue un **resultado negativo**: no tenía ninguna de las tres cosas que se fueron
  a buscar. Se borró en la sesión 2.

### Las tres refutaciones que habrían costado una tarde

1. **`ENT.Models` gana sobre `ENT.Model`** — declarar sólo `Model` spawnea con Arnold.
2. **`Term_FOV` solo no alcanza**: sin `AutoUpdateFOV = false`, la convar global lo pisa. El
   comentario del código dice lo contrario y miente.
3. **`SetupDataTables` con `NetworkVar("Bool", 0, …)` pisa `Crouching`** de la base. HIM tiene ese
   bug **vivo**: su señuelo nace agachado.

### Error propio, corregido

Se reportó que la «dimensión extra» no tenía precedente en ningún addon. **Era falso**: el grep que
lo «probó» exigía `SetPos` en la misma línea. Lo refutó leer el addon, no afinar el patrón.
