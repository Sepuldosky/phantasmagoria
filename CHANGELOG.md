# Phantasmagoria — Changelog

**Estado:** ver [ESTADO.md](ESTADO.md) · **Diseño:** ver [docs/](docs/PHANTOM_Phasmophobia_Diseno.md)

Formato: una entrada por sesión de trabajo, la más reciente arriba. Se anota lo que se **hizo** y lo
que se **midió**, no lo que se planea.

---

## 2026-08-08 (27) — **La pose T era el ARMA** (corrida r17: 7 pasa · 0 falla · 1 sin correr)

La r17 contestó el bloque. Y los dos síntomas que el autor reportó en el mismo mensaje —
*«también tomó un arma y se deformó»* y la pose T — resultaron **el mismo evento**.

### La cadena, del dump del actlog

```
3115.93  Translate  ACT_MP_CROUCHWALK -> ACT_HL2MP_WALK_CROUCH_SMG1 (1801)
3116.25  Translate  ACT_MP_STAND_IDLE -> ACT_HL2MP_IDLE_SMG1 (1797)
3117.13  Translate  ACT_LAND (33)     -> ACT_INVALID (-1)
3117.13  Gesture    ACT_INVALID (-1)
```

El bot levantó una SMG del piso. `TranslateActivity` **le pregunta al arma antes que a nuestra
tabla** (`motionoverrides.lua:3694`; nuestro `IdleActivityTranslations` recién en `:3712`), así que
con un arma en la mano toda nuestra traducción queda anulada y el modelo vuelve a las **prestadas de
`m_anm`** — las `*_SMG1`. Eso es el estiramiento.

Y `luaWep:TranslateActivity( ACT_LAND )` devuelve **`-1`**, porque un arma no sabe traducir un
aterrizaje. La base hace `if newact then return newact end` y **`-1` es truthy en Lua**: sale tal
cual y termina en `AddGesture( -1 )` — la pose de referencia. **Ahí está la T.**

**El arreglo va en la causa:** `CanPickupWeapon` devuelve `false`. `DefaultWeapon = false` sólo decía
con qué *nace*; la tarea `movement_getweapon` seguía registrada. Convar
`phantasmagoria_ghost_pickup` (default 0) para que el A/B exista: en 1 los dos defectos tienen que
volver **juntos** — si vuelve uno solo, el diagnóstico está incompleto.

### El instrumento imprimió la pose T y después dijo que no la había

El veredicto salió *«ninguna actividad quedó SIN RESOLVER en esta ventana»* con
`Gesture ACT_INVALID (-1)` **tres líneas más arriba, en el mismo dump**. Con `act < 0`,
`SelectWeightedSequence` *tira* en vez de devolver -1; el `pcall` lo atrapaba y el evento quedaba con
`resolvio = nil` — que no es `false`, que es lo único que la línea marca. *Tres estados con dos
cuentas: el tercero se reparte solo, y siempre hacia el lado que uno no quería.*

Y es **el mismo defecto que este mismo bloque le había corregido a `actmiss` dos días antes**, en
otra función del mismo archivo. Arreglarlo en un lugar no lo arregla en el de al lado.

### `ph_ghost_bones` reventó antes de mirar un fantasma

`bad argument #1 to 'tostring' (value expected)`. `e:GetModel()` sobre una entidad sin modelo **no
devuelve `nil`: no devuelve nada**, y `tostring()` con cero argumentos da ese error. Es la **segunda
ronda seguida** en que nadie mide un hueso sobre el bot: en la r16 el instrumento miraba otras
clases, en la r17 se caía antes de llegar.

### Abierto: «sigue corriendo de lado»

Lo medido fuera del juego **descarta** la sospecha obvia: el orden de los pose params difiere entre
`m_anm` (`[0] move_y, [1] move_x`) y el nuestro (`[0] move_x, [1] move_y`), pero los `paramindex` de
las cuatro mezclas **resuelven a los mismos nombres**. La grilla compiló bien.

Lo que sí apareció es una **suposición mía sin medir**: la línea convierte con `v * 2 - 1` afirmando
que `GetPoseParameter` devuelve 0..1, y la r16 imprimió `move_y entre -1.04 y -1.00` — que exige un
crudo de `-0.02`, **fuera de 0..1**. Nadie lo miró. Ahora imprime el crudo, **se niega** a convertir
si cae fuera de rango, dice la **celda de la grilla**, y avisa cuando el bot se mueve y la celda no
es `N` — que es el síntoma exacto.

---

## 2026-08-08 (26) — **El instrumento de la pose T, el NextBot medible, y las secciones**

Los tres pendientes que dejó la r16, más la fila roja. Nada de esto está corrido en juego todavía:
lo que se cierra acá es *poder medirlo*.

### `ph_ghost_bones` no veía al NextBot — y era el check que el bloque existía para correr

Buscaba por **lista blanca de clases** (`prop_dynamic`, `prop_ragdoll`, `prop_physics`), que eran las
formas en que el fantasma se spawneaba cuando se escribió. Con el sujeto ya en
`terminator_nextbot_phantom`, la búsqueda miraba un banco vacío y contestaba *«no hay ningún
ghost_girl spawneado»* — que se lee como **no hay nada** cuando lo que pasaba era **no miro ahí**. La
fila 05 quedó sin correr y nadie midió un hueso sobre el bot.

Ahora busca **por modelo**, con una lista *negra* de una sola clase (`phys_bone_follower`, con el
motivo escrito al lado). Eso alcanza al bot, a los props y al ragdoll por igual — y a los 30 tipos de
§12.2 sin tocar nada. Cuando no encuentra, dice **entre cuántas entidades buscó y qué descartó**.

Y lee por los **dos** caminos (`GetBoneMatrix` y `GetBonePosition`), imprimiendo los dos cuando
difieren: sobre `ClientsideModel` el sondeo de la r2 ya midió que `GetBonePosition` devuelve una pose
congelada, y sobre un NextBot **no lo midió nadie**.

### La pose T: un instrumento, no una hipótesis

El autor la reportó dos veces tirando el fantasma con el physgun, y pidió el instrumento con todas
las letras. Una pose T es la de **referencia**: hay una actividad que la base pide y que no resuelve a
ninguna secuencia. **Cuál es sigue sin estar identificada, y esto no la adivina.**

| comando | qué contesta |
|---|---|
| `phantasmagoria_ghost_actmiss` | barre **todas** las actividades que la base puede pedir y lista las que no resuelven. **Contesta sin esperar el síntoma.** |
| `phantasmagoria_ghost_actlog 1` + `_dump` / `_clear` | anillo de 64 eventos: qué se pidió, qué salió, y si `SelectWeightedSequence` devolvió algo |

El universo de actividades está **censado del código de la base**, no recordado. Y medirlo con
`mdlacts.py` sobre `m_anm` destapó un sospechoso que el handoff no listaba: `HandleFlinching`
(`damageandhealth.lua:634`) llama `AddGesture` **directo** con un `ACT_FLINCH_*`, y **cinco de los
ocho no existen** ni en `m_anm` ni en nuestro modelo. *No* explica todavía la T del physgun — el daño
de caída entra por `HITGROUP_GENERIC`, que mapea a `ACT_FLINCH_PHYSICS`, de los tres que sí existen —
pero son actividades sin secuencia **confirmadas**.

Se envuelven los **seis** puntos de entrada y no uno: `AddGesture` es nativo y no pasa por
`DoGesture`, así que envolver sólo `DoGesture` habría dejado los ocho flinch fuera del instrumento —
*el mismo modo de falla que este bloque vino a arreglar*.

### La fila 03 era del instrumento: `timer.Simple(0)` no es «después»

Imprimía `hull 19x40x55` — **exactamente** el hull de colisión del `.phy` — porque mi timer se
registraba en `AdditionalInitialize` (`shared.lua:3011`) y el de la base en `:3039`, y los timers de
delay 0 disparan **en orden de registro**. Leía antes de que nadie escribiera. No se arregla con un
timer más largo (sería apostar a que la base no cambie de orden, y la apuesta no se vería fallar): se
mide **enganchado a `SetupCollisionBounds`**, o sea donde ocurre.

### Secciones: 284/325 → **325/325**, y el centro de las mezclas ya va de verdad

`mdlanim.donde()` resuelve buffer y offset **por sección** (la tabla vive en el `.mdl`, los datos en
el `.ani`, y **cada sección trae su propio `animblock`**). Las 41 secuencias partidas se portan.

Dos cosas que aparecieron al poder leerlas, y las dos corrigen lo que estaba escrito:

- **El centro de cada mezcla ES el idle.** `a_WalkC` y `idle_all_01` son la misma animación (0,056°
  de diferencia máxima). Como viven en bloques distintos del `.ani` (10 y 2) con offsets distintos,
  eso **acredita el lector de secciones por un camino que no se buscó**: dos lecturas de basura no
  coinciden.
- **La sustitución costaba más de lo que se creía.** El centro iba reemplazado por la dirección N, y
  el argumento escrito era que ahí la velocidad es ~0 y casi no se usa. Medido: la N difiere **39,11°**
  del centro real.

Y el nombre del animdesc de cada celda **se lee del `.mdl`, no se construye**: dos de las cuatro
mezclas no siguen la convención — el centro de `run_all_01` es `a_WalkC` (el del *walk*) y el de
`swimming_all` es `@swimming_all`. `a_RunC` y `a_SwimC` no existen.

**Modelo recompilado e instalado**: 39/39 animaciones, las 8 actividades intactas, malla sin cambios
(44,94 u).

### El arnés ya cubre el archivo del NextBot

`luaharness.py` no podía cargar `terminator_nextbot_phantom/server.lua` — no parsea el `continue` de
GMod — así que sobre sus 2000+ líneas lo único que había corrido era un chequeo de **sintaxis**. Ahora
lo traduce a `goto` emparejando bloques de verdad (un `str.replace` pondría la etiqueta en el bucle
equivocado: compila, corre, y saltea las iteraciones del bucle de afuera). Con eso, más `--fantasma` y
stubs que faltaban, los **10 comandos** del archivo se ejercitan en 17 variantes × 2.

Y ahí saltó un defecto **mío** antes de llegar a la planilla: el veredicto de `actmiss` decía
*«PASA: las 18 actividades resuelven»* cuando **ocho no se habían medido** (no existían como `ACT_*`
en ese build y caían en otra rama, sin sumar a ningún contador). *Un veredicto que no resta lo que no
pudo medir cuenta los ausentes como aprobados.*

### Consecuencia de diseño propagada

§18.2.1 tenía la cuenta de escondites con los ojos del bot en **64**. Con el hull nuevo van a **40** y
la fórmula pasa de `H > 64 − 46·t` a **`H > 40 − 22·t`**: todos los escondites se vuelven más fáciles.
Reescrita, con los números viejos en una columna aparte porque describen lo que se jugó hasta hoy.

---

## 2026-08-08 (25) — **El fantasma tiene cuerpo: `ghost_girl.mdl` en el NextBot** (corrida r16: 6 pasa · 1 falla · 1 sin correr)

`phantasmagoria/ghost_girl.mdl` pasa de prop verificado a cuerpo de
`terminator_nextbot_phantom`. Planilla `dev/checks/phantasmagoria-ghostbot-r16.html`.

### La precondición era otra de la que el plan decía

La base **no le pide al modelo una secuencia por nombre: le pide una ACTIVIDAD**, y el `ACT_MP_*` de
su tabla de movimiento **nunca llega** — `TranslateActivity` (`motionoverrides.lua:3681`) lo convierte
antes en un `ACT_HL2MP_*`. El plan heredado mandaba escribir `activity ACT_MP_RUN` en el QC: habría
declarado una actividad que nadie pide, y el estiramiento habría seguido intacto **sobre un modelo que
compila limpio**.

**Y ninguna de las siete de locomoción estaba entre las «284 portables» que el taller tenía contadas**
— ésas son las de arma en mano, justo las que un bot desarmado nunca pide. Las siete son mezclas 3×3 o
animaciones seccionadas. Lo que destrabó: `--listar` cuenta **secuencias**, y las 8 direcciones de cada
mezcla (`a_WalkN`, `a_RunSW`…) son **`animdesc` sueltos**; `mdlseq2smd.py` ya sabía direccionarlos y la
rama llevaba meses invisible. **35 animaciones portadas, 53/53 huesos cada una.**

### Lo medido en juego

| | |
|---|---|
| **8/8 actividades con UNA sola secuencia** | y es la nuestra, con 2171 visibles (el `$includemodel` se resolvió). **Era lo único del bloque sin medir y quedó medido: el descarte por nombre OCURRE.** |
| La secuencia viva cambia con el estado | `idle_all_01` a 0 u/s, `run_all_01` a 196 |
| La mezcla responde | `move_x +1.00`, `move_y` moviéndose; paso lateral confirmado a ojo |
| El ragdoll sobrevivió la recompilación | huesos y articulaciones correctos |

### El hull: el mecanismo anda y **el instrumento no lo midió**

`ENT.CollisionBounds` de la base está **clavado** en 32×32×72 para todos los modelos
(`terminator_nextbot_base/init.lua:39`). El fantasma pasa a 20×20×45, de **un solo factor** (44,94/72).

**La fila 03 salió roja y es culpa del instrumento.** Imprimió `hull 19x40x55` — que es *exactamente*
el hull de **colisión** del `.mdl` (18,90 × 40,14 × 54,55, del `.phy` del ragdoll). `GetCollisionBounds()`
devolvió la OBB del modelo porque **mi `timer.Simple(0)` corre ANTES que el de la base**: el mío se
registra en `AdditionalInitialize` (`shared.lua:3011`) y `SetupCollisionBounds` en `:3035`.

**El mecanismo sí anda, y lo prueba la otra columna:** `ojos z 40`, que es `round(45 − (45/72)·8)` con
*nuestro* `maxs.z`; con el de la base da **64**, que es lo que imprimió el control negativo. *Un check
que mide la cosa equivocada y otro que no mide no son lo mismo, y éste midió mal.*

**⚠ Consecuencia de diseño:** §18.2.1 sacó la cuenta de escondites con los ojos en 64
(`H > 64 − 46·t`); con 40 pasa a `H > 40 − 22·t`. **Todos los escondites se vuelven más fáciles.**

### Lo que quedó abierto

- **`ph_ghost_bones` no ve al NextBot** — busca `prop_dynamic`/`prop_ragdoll`, así que el check que
  este bloque existía para correr es justo el que no alcanza al sujeto. Fila 05 **sin correr**.
- **Una pose T al caer** [reportada por el autor]: hay una actividad que la base pide y que no resuelve
  a ninguna secuencia. No está identificada — hace falta el instrumento que registre **qué** actividad
  se pidió, que es lo que el autor pidió explícitamente.
- El centro de las cuatro mezclas sigue **sustituido** por la dirección N: el original está partido en
  secciones y `mdlseq2smd.py` no las soporta.

---

## 2026-08-08 (25) — Ronda 15 CORRIDA: **el tipo CERRADO, 8 de 9** — y tres verdes que no midieron lo suyo

**El mecanismo de la tajada A queda cerrado**, con evidencia completa en cinco filas: el tipo se
asigna al spawnear (`tipo Obake ( obake ) threshold 50 %`), el sorteo cubre **30 de 30** en dos
corridas con números distintos, el botón dio **las dos negativas exactas**, el override alcanzó a
**7 fantasmas nuevos** (todos Demon, `threshold 70`) y los 30 thresholds son los del juego. **La
tajada C ya tiene contra qué comparar.**

> **Y un número que parece un sesgo y no lo es:** `obambo x19` contra `yokai x3` sobre un esperado de
> 10. Con 300 tiros en 30 categorías la desviación típica es ~3,1 y el **máximo de 30 categorías**
> cae naturalmente cerca de 17-19; la segunda corrida dio 16 y 5. *No hay un dado cargado: hay treinta
> máximos compitiendo.*

### Las tres filas que no midieron lo que decían, y las tres por el mismo motivo

| | Pedía | Trajo |
|---|---|---|
| **01** | **dos** líneas de conteo, `server` y `cliente` | *«sí vi ese dato»* |
| **04** | **dos** fantasmas en la misma salida, el viejo con su tipo | uno solo |
| **08** | lo que dice **el marcador del cliente** | la salida del **servidor** |

⚠ **La 01 y la 08 son, juntas, la única prueba de que el realm CLIENTE funciona, y ninguna de las dos
trae un dato del cliente.** No es formalidad: en este taller el cliente ya fue el realm donde algo
estuvo apagado dos arranques sin un solo error de Lua.

### ⭐ Un defecto salió de adentro de una fila VERDE, y es de la familia que ya costó una ronda

La 03 imprimió `quiere … ( la escribe LA BASE ( shootAt sobre el enemigo ) )` con **`enemigo ninguno`
dos líneas más arriba, en la misma pantalla**, y el bot `quieto ( 0 u/s )`.

Las dos mitades son falsas en ese estado: `shootAt` pide `IsValid( GetEnemy )` —sin enemigo la cadena
de `shooting_handler` se sale antes— y el facewalk se sale por debajo de 30 u/s. **En ese hueco no hay
ningún escritor**: el valor quedó del último que corrió, y el `cambio hace 0.8 s` es cuando el bot
venía caminando y frenó.

*Una etiqueta que nombra a un escritor tiene que preguntar por la precondición de ESE escritor, aunque
el dato esté impreso al lado.* Es la misma familia que costó la ronda 12 —deducir quién escribió en
vez de medirlo— reaparecida en la rama de al lado.

### ⭐ Un `EntIndex` no es una identidad: GMod los recicla

La 04 leyó `#52 … Obake` y después `#52 … SIN TIPO`, con **un solo fantasma en la salida**. *«Perdió
el tipo»* —que sería un rojo grave— y *«otro fantasma heredó el número»* se ven **exactamente igual**.
Entró `serie N · nacio hace N s` en la cabecera de `ghost_where` y de las fichas del tipo: el serial
no se recicla nunca.

### ⚠ La 02 no estaba «sin correr»: estaba SIN SUJETO

Mandaba pesar el crucifijo del **Prop Pack de terceros**, y el autor contestó lo que convertía la fila
en otra cosa: *«no usar los modelos demit, solo los nuestros pues los estamos cambiando»*.

**Medidos los `.phy` de `models/phantasmagoria/eq/`: los 66 traen `mass 1.5` y `surfaceprop metal`** —
el default del `.qc`. Los del árbol raíz (`candle`, `ouija_board`, `musicbox`, `haunted_mirror`,
`monkeypaw`) **sí** están ajustados uno por uno, así que no es descuido general: el lote de
equipamiento nunca pasó por ahí.

> **No es la tonelada del Prop Pack.** Aquel era un tercero clavando 1000 kg; éste es *nadie les puso
> todavía el número*, y el síntoma tampoco es el mismo: no es que no se puedan levantar, es que **la
> sal, las pastillas y el cuaderno pesan lo mismo y suenan a chapa**.

Entró **`lua/phantasmagoria/prop_data_eq.lua`**, generado por `dev/gen_eq_propdata.py` desde los
`.mdl` **reales** — el generador se niega si algún modelo no cae en ninguna de las 20 familias, porque
un inventario escrito a mano es indistinguible de uno completo hasta que rompe. Las masas se copian de
las que `prop_data.lua` ya tenía decididas donde hay equivalente; el resto sale del objeto con el piso
de 0,2 kg que ese archivo documenta. **Los números son una propuesta para que el autor los corrija.**

**Archivo aparte por coordinación y no por estilo:** las entradas de terceros las retira **otra
sesión**. División por procedencia, fusión en runtime, un solo diccionario para `ApplyPropData`.

⚠ **El re-escalado que viene no invalida estos números**, aunque parezca que sí: la masa que Source
calcula sola depende del volumen, pero `PhysObj:SetMass()` la **clava**. La tabla no se calibra contra
el tamaño: lo reemplaza.

⚠ **Y hay un orden de carga obligatorio:** `prop_data_eq` **fusiona**, `prop_data` **asigna**. Al
revés, el segundo pisaría los 66 sin un solo error, con el único síntoma de equipamiento nuestro
pesando 1,5 kg. La columna nueva de la guarda **no cuenta su propia tabla sino cuántas sobrevivieron
en la de destino** — *una guarda que mide la fuente en vez del destino da verde justo en el modo de
falla que existe para atajar.*

Planilla `dev/checks/phantasmagoria-tipo-r15b.html`, **6 filas, sin correr**.

---

## 2026-08-08 (24) — **La cordura arranca: tajada A, el fantasma ya es uno de los 30** (escrita, sin correr)

§19 va en **tres tajadas**: **A · el tipo** → B · la cordura → C · el gatillo. Ésta es la A.

**Por qué el tipo va primero y no es un rodeo:** el gatillo de C no compara la cordura contra un
número fijo, la compara contra `hunt.threshold`, que es un dato **del tipo** (Demon 70, Shade 35,
Deogen 40). Sin tipo asignado, C no tiene contra qué comparar y B mediría una barra que no dispara
nada.

**Y el drenaje queda decidido: por CAUSAS, sin reloj de fondo** [decisión del autor]. No hay goteo
constante — baja por oscuridad (§19.4), cercanía del fantasma y cacerías. *Si no pasa nada, no baja
nada.* Los 10-20 min de §19.2 dejan de ser una tasa y pasan a ser la **escala**.

### Lo que entró

`lua/entities/terminator_nextbot_phantom/server_type.lua`, colgado del mismo patrón de includes que
`server_speed` / `server_doors` / `server_steps` / `server_stuck`, y **primero de la lista**: es el
único que no consume nada de los otros y es del que los otros van a colgar.

| | |
|---|---|
| **Tres orígenes, en orden** | override de consola → `ENT.PhantomType` de la clase (§12.2) → sorteo |
| **Networkeo** | `SetNWString` con la **key**, y el cliente resuelve la ficha con su propia copia de los 30 |
| **Instrumentos** | línea en `phantasmagoria_ghost_where`, en la línea de spawn, en el marcador del cliente |
| **Botón** | `phantasmagoria_ghost_type` — `<key>`, `random`, `auto`, `sorteo N`, `lista` |
| **Control** | `phantasmagoria_ghost_typeassign` (1, `0` = spawnean **sin tipo**, que es el estado de ayer) |

**El motivo del que ganó viaja con el fantasma** y se imprime al lado del tipo. Sin eso, «salió Oni»
no distingue un sorteo de un override olvidado de la corrida anterior — y los overrides de este addon
sobreviven al respawn a propósito (la lección de la ronda 3).

### ⚠ Lo que NO hace, y es deliberado

**No cambia ni un comportamiento.** `speed.base` está en los 30 tipos y `server_speed.lua` ya sabe
leer un campo (`phantom_SpeedMul`) que **gana** sobre su convar andamio — y este bloque **no lo
escribe**. Engancharlo habría cambiado la velocidad de todos los fantasmas de golpe, sin A/B, en la
misma ronda que estrena el mecanismo que la decide: *un rojo de velocidad ahí sería imposible de
atribuir.* Es una línea, y va con §5 y su propia planilla.

Por el mismo motivo la línea del instrumento dice `speed.base x0.900 ( NO aplicado todavia )`: *una
línea que muestra un dato que todavía no se usa tiene que decir que no se usa, o se lee como que sí.*

### El botón se niega dos veces, y la segunda salió de la revisión antes de correr

- Una key mal tipeada rebota **sugiriendo**: `twins` → `parecidos: the_twins`. El nombre del juego y
  la key no siempre coinciden («The Twins» es `the_twins`), así que equivocarse es lo normal — y un
  override aceptado apuntando a nada dejaría a los fantasmas siguientes **sin tipo, con el comando
  habiendo dicho que sí**.
- **Forzar un tipo con `typeassign 0` también rebota.** Aceptarlo habría dejado la peor salida
  posible: `override -> oni` arriba y `SIN TIPO` en las fichas de abajo, **en la misma pantalla**.
  Eso se lee como *«el override no funciona»*, que es la conclusión inversa a la verdadera.

### ⚠ El modo de falla del sorteo que no tira error

`ghost_types.lua` declara **dos** listas: `Types` (con clave) y `TypeOrder` (el array del sorteo). El
archivo es **generado**, o sea que se regenera. Si se desincronizan:

- en `Types` y no en `TypeOrder` → el tipo existe y **nunca sale sorteado**. 29 de 30, y se ve igual
  que un sorteo con suerte.
- en `TypeOrder` y no en `Types` → el sorteo devuelve una key que no resuelve, y el fantasma sale sin
  ficha.

Ninguno tira error. Va una guarda al arrancar que los cuenta y los nombra, y el subcomando
`sorteo 300` los mide **en seco** — 300 tiros sin spawnear nada, `distintos 30 de 30` y la lista de
los que **nunca salieron**. *Contar tipos spawneando fantasmas cuesta un spawn por muestra y no llega
a ninguna N útil.*

### Los dos arrastres del cargador, y los dos defectos de instrumento que destaparon

Las dos filas que el cargador de ayer dejó pendientes ya están escritas (01 y 02 de la planilla), y al
escribirlas apareció que **ninguna de las dos se podía medir**:

- **La guarda hacía `return` en silencio cuando todo estaba bien.** La consola de un servidor sano y
  la de uno donde el archivo **no corrió** se veían **exactamente igual** — y «no corrió» es el único
  defecto que la guarda existe para no repetir. *Una guarda que sólo habla cuando falla no puede
  acreditar que corrió: su silencio es el síntoma del defecto que vigila.* Ahora dice el conteo
  siempre y **con el realm**, y la fila espera **dos** líneas (`server` y `cliente`): una sola es rojo
  y además predice el rojo de la fila del networkeo.
- **La masa del crucifijo no tenía cómo medirse.** *«Se levanta»* es una impresión. El hook imprime
  ahora el par `1000.00 kg -> 0.60 kg`, que separa los tres modos: sin línea = el hook no corrió;
  `1000 -> 1000` = corrió y no corrigió; `0.60 -> 0.60` = sacaste el crucifijo del **otro** pack.

### Papeleo

**§19.6 estaba vencida:** decía que faltaba *«la decisión de §19.5 — cuál de las tres formas»* y
§19.5 ya había decidido (NEAD no se integra). El bullet sobrevivió tres versiones. *Una lista de
pendientes que no se tacha cuando la sección de arriba decide manda a re-discutir lo cerrado — y como
se lee antes que el cuerpo, gana ella.* §19.6 es ahora la tabla de las tres tajadas con su estado; los
pendientes de verdad se mudaron a §19.7.

Planilla `dev/checks/phantasmagoria-tipo-r15.html`, **9 filas, sin correr**.

---

## 2026-08-08 (23) — **`lua/phantasmagoria/` no lo cargaba nadie**: cargador escrito, sin pasada en juego

Antes de empezar §19 (la cordura) hacía falta una sola respuesta: *¿existe `PHANTASMAGORIA.Types` en
runtime?* **No existía.**

GMod auto-ejecuta un conjunto **fijo** de carpetas — `lua/autorun/`, `lua/entities/`, `lua/weapons/`,
`lua/effects/`, `lua/vgui/` — y `lua/phantasmagoria/` no está en esa lista. Una carpeta propia adentro
de `lua/` no corre sola. El grep de `include(` y `AddCSLuaFile` sobre **todo** el addon daba dos
líneas, las dos `AddCSLuaFile()` de las armas.

### Lo que estaba apagado, y uno de los dos no era "datos sin usar"

| | qué era | qué se perdía |
|---|---|---|
| `ghost_types.lua` | 30 tipos, con `hunt.threshold` y `speed.base` en los 30 | §19 no se podía **ni empezar**: el disparo del hunt lee el threshold **del tipo** |
| `prop_data.lua` | ⚠ **comportamiento, no datos** | el hook `PlayerSpawnedProp` que corrige la masa; su propio comentario: *«sin esto, un jugador que saque el crucifijo del Prop Pack desde el spawnmenu se lleva la tonelada»* |

**Esa red de seguridad nunca corrió.**

### ⚠ Por qué no dejó rastro: el consumidor todavía no estaba escrito

El grep de `ApplyPropData` / `PropData` / `Types` fuera de la carpeta da **cero usos**. Una tabla que
no existe sólo tira error cuando alguien la lee, y nadie la leía todavía. O sea: **el defecto no tenía
síntoma porque la función que lo hubiera mostrado era justo la que faltaba escribir** — y el síntoma
iba a aparecer el primer día de §19, disfrazado de *«la cordura no anda»*, a tres archivos de
distancia de la causa.

*Un archivo que existe no es un archivo que corre, y un `include` que nadie escribió no falla:
simplemente no pasa nada.* Los dos parsean, los dos están bien escritos, y los dos estaban apagados.

### El cargador

`lua/autorun/phantasmagoria_data.lua`. **Incluye, y nada más**, a propósito: la respuesta a *«¿por qué
este dato está o no está?»* tiene que ser *«mirá la lista de este archivo»*. Los dos van a los dos
realms — el HUD de cordura (§19.3) es cliente y necesita nombre y threshold del tipo; el hook de
`prop_data` ya se guarda solo con `if SERVER`.

⚠ **La guarda de `Initialize` NO puede detectar la falla que acaba de ocurrir**: si este archivo no
corre, la guarda tampoco. Detecta el otro modo (un rename, un `return` temprano, un error a mitad). Y
dice **el número**, no un booleano: `Types existe` no distingue 30 tipos de una tabla vacía.

### Medido, y lo que no

Parsea; las dos rutas existen; `ghost_types.lua` define **30** tipos; `PropData` en la línea 39; el
hook en la 118. **Sin pasada en juego:** nadie vio todavía el conteo de la guarda en una consola de
verdad, ni volvió a pesar el crucifijo del spawnmenu. Eso son dos filas de planilla y van con el
bloque de la cordura.

---

## 2026-08-08 (22) — Ronda 14 CORRIDA: **el alcance CERRADO, 5 de 5** — y el gate tapa una puerta lateral

Las cinco en verde, y la aproximación de la fila 04 salió **mejor de lo que la fila pedía**.

### El A/B, y el umbral queda acotado entre dos lecturas

| | `sightdist 3000` | `sightdist 0` (control) |
|---|---|---|
| `ShouldBeEnemy` a ~20.000 u | **NO** | **SÍ** |
| `mem` | **NO** | **SÍ, hace 0.0 s** |
| enemigo | **ninguno** | **`Player [1]`** |
| veredicto | `FUERA DE ALCANCE` | `la cadena entera funciona` |

Con `ve CanSeePosition SI · PosCanSee SI · ClearOrBreakable SI` en **las dos mitades**: el fantasma te
ve igual y no le importás. *Es exactamente lo pedido: no se le rompió la vista, se le acotó a quién
puede odiar.*

**La 04 acotó el umbral sin que la fila lo pidiera.** Cuatro lecturas acercándose —
**15.485 → 8.917 → 4.275 → 2.522 u** — con el volteo entre las dos últimas, o sea **atravesando el
3000**. Y en la de 2.522 u: `ShouldBeEnemy SI` sin la marca de fuera de alcance, `mem SI, hace 0.0 s`,
`enemigo Player [1]`. El autor lo dijo mejor: *«si pasé los 50 metros y me vio de inmediato»*. **El hunt
de cerca quedó intacto y el corte es limpio.**

Y la 05 confirmó la mitad que nadie había pedido: a 4.819 u, `enemigo ninguno` + `mem NO`. **Te suelta
al alejarte**, que es lo que sale de haber puesto el gate en `ShouldBeEnemy` — el mismo punto que lee
`ForgetOldEnemies`.

### ⚠ Y el gate tapa una entrada lateral que ninguna fila nombró

Entre la 01 y la 02 el autor le pegó un tiro, y las cuatro lecturas siguientes tienen `vida 827 / 900`
con `rel D_HT pri 1000`. **Ese 1000 es `MakeFeud`** (`damageandhealth.lua:482` →
`enemyoverrides.lua:1046`, *«hate players more than anything else»*), que reescribe la relación cuando
te pegan, sin preguntarle nada a nadie.

Pero **MakeFeud escribe la relación, y el gate corta antes de que la relación se lea**: la 02 muestra
`ShouldBeEnemy NO` a 20.879 u con el daño encima. O sea que **un fantasma baleado desde lejos ya no
viene a buscarte** — antes venía desde cualquier distancia. *Un límite puesto delante de una cadena
tapa también las entradas laterales de esa cadena, y las laterales son las que nadie recuerda.*

Queda así a propósito — en Phasmophobia al fantasma no se le dispara — pero es una **decisión, no un
descuido**, y ahora el instrumento la dice: el veredicto de fuera de alcance agrega una línea cuando el
fantasma tiene daño encima, que es el único momento en que alguien se va a preguntar *«le disparé y no
viene»*.

### Dos filas se corrieron con menos lecturas de las que pedían

La 02 pedía dos lecturas separadas 3 s y trae una; la queda cubierta por la 01, que es otra lectura a
otra distancia y otro momento (27.687 u contra 20.879 u). Y **la 05 pedía anotar cuánto tardó en
soltarte, y ese número no está** — trae una sola lectura ya del otro lado. El mecanismo es
determinístico (`ForgetOldEnemies` corre cada barrido, ~0,5 s) así que el veredicto no cambia, pero el
dato que la fila quería sigue sin medirse.

---

## 2026-08-08 (21) — Ronda 13b CORRIDA: **el arco de la mirada CERRADO**, y el rojo era de diseño

Marcó 6 pasa y 1 falla. **Las seis son verdes de verdad** — y la falla no lo es: su criterio se cumplió.

### El A/B, ahora sí como par

| | 02 · `facewalk 1` | 03 · `facewalk 0` (control) |
|---|---:|---:|
| régimen | `hunt SIN enemigo` | `hunt SIN enemigo` |
| `la escribio NOSOTROS` | **99** de 100 | **0** de 100 |
| `vs marcha` media | **1,1°** | **90,6°** |
| `giro` barrido · abanico | **670° · 151°** | **0° · 0°** |
| `congelada` | **0** de 98 | **44** de 48 |

Mismo régimen, misma ventana, **una sola convar de diferencia**. Es lo que la r13 no llegó a tener.

**Y el instrumento dejó de contradecirse:** seis `ghost_where` seguidos con el bot caminando derecho, los
seis con `la escribimos NOSOTROS` y `mirada vs marcha` entre 0 y 1,4° — **ninguno dice CONGELADA**. El
reordenamiento (primero lo medido, después lo inferido) sostiene.

**Y el botón se negó cuando tenía que negarse:** `phantasmagoria_ghost_look 30 calmasin` contestó
*«pediste 'calma SIN enemigo' y el fantasma está en 'calma CON enemigo'»* justo después de un
`hunt 0` — la memoria del enemigo no se vacía en el mismo frame. El operador esperó, repitió, y la
ventana salió limpia. *Eso es el lazo funcionando: la fila no se marcó verde sobre el régimen
equivocado porque el comando no la dejó.*

Residual anotado y no arreglado: la 07 dio `congelada 5 de 117` contra un criterio de `0`. Son 4 %, y
el candidato es el hueco deliberado del facewalk — se sale si el bot no está en el piso
(`m_JumpingToPos` / `IsOnGround`), porque ahí manda la base.

### La 06 de la r13 CERRADA: era latencia, y ahora está medida

`ve SI` → `mem SI, hace 0.0 s` → `enemigo Player [1]` → `la cadena entera funciona`, **a 31.253 u**. El
rojo de la r13 fue haber mirado en el primer segundo. Y la fila 01 de acá destapó **de dónde salen esos
segundos**: `enemy_handler` arranca con `data.playerCheckIndex = 0` (`shared.lua:3115`) y Lua indexa
desde 1, así que **el primer barrido de la rama de distancia infinita no mira a nadie**. Se ve en el
log: `idx 0` en las dos primeras lecturas, `idx 1` desde la tercera. Sumado a que esa rama corre
*después* de `FindPriorityEnemy`, la primera adquisición lejos cuesta **hasta tres barridos, ~1,5 s**.

El control de la línea `mem` también pasó: tapado a 3464 u da `mem NO` con `lo tapa el mundo ( brush ) a
2262 u`. *Una columna que nunca dice NO no es una medición.*

### ⚠ El rojo NO era del mecanismo: era el alcance

La fila 05 se marcó *Falla* y **su criterio se cumplió textualmente**. Lo que el autor reportó es otra
cosa, y tiene razón: el fantasma lo tomó de enemigo **a 31.253 u — 542 m en la mira del rifle**, del
otro lado de `gm_flatgrass`, con `mirada vs jugador 0°` y `movement_stalkenemy` corriendo. *La cadena
funcionaba perfecto; el problema es que funciona demasiado lejos.*

No es un bug de la base: lo hace **a propósito y con dos mecanismos**. `ShouldBeEnemy`
(`enemyoverrides.lua:507-515`) descarta por distancia a todo lo que no sea jugador y **exime a los
jugadores en su propio comentario** (*«ignore maxSeeingDist for plys»*); y `enemy_handler` tiene además
la rama *cheap infinite view distance*, que existe justamente para verte sin límite. Para un terminator
es correcto. Para un fantasma de Phasmophobia no: el hunt es adentro de una casa. *Un default de la
base que es correcto para lo que ella es puede ser un defecto de diseño para lo que uno construye
encima.*

**`phantasmagoria_ghost_sightdist` (3000, `0` = sin límite).** Va en `ShouldBeEnemy` y no en los cuatro
sitios, y ése es el motivo de que sea barato: es la puerta que consultan los cuatro, así que un solo
gate corta la adquisición **y** hace que te suelte al alejarte. ⚠ **El número no es mío:** 3000 es
`MaxSeeEnemyDistance`, el que la base ya aplica a todo lo demás — poner otro sería inventar un balance
que Diseño no fijó. Y el instrumento lo muestra: la distancia se imprime contra su tope, y el veredicto
distingue *fuera de alcance* de *puerta cerrada*, porque ahora hay **dos** motivos para un
`ShouldBeEnemy NO` con el hunt puesto.

Planilla `dev/checks/phantasmagoria-alcance-r14.html`, 5 filas, **sin correr**.

---

## 2026-08-08 (20) — Ronda 13 CORRIDA: **la fila del arreglo midió el régimen de al lado**

Marcó 6 pasa y 1 falla. **Tres de esos verdes no lo son**, y el hallazgo caro es de mi instrumento.

### La fila del arreglo no corrió, y su propia salida lo decía

La fila 02 era la que probaba el arreglo, y su primer renglón dice
`regimen hunt **CON** enemigo sostenido toda la ventana`. El defecto vivía en `hunt **SIN** enemigo`.
Con enemigo manda la base y **`NOSOTROS 0` es lo correcto por diseño** — así que el veredicto salió
con pinta de estar bien midiendo la fila de al lado (la 04, que dio lo mismo).

El botón se negaba a *promediar* dos regímenes, pero no a *correr entero* en el que no era. *Un botón
que se niega a lo que puede pasar en el medio, y no a lo que ya estaba mal al empezar, deja pasar el
error que de verdad ocurre.* Ahora `phantasmagoria_ghost_look` toma un segundo argumento
(`huntsin` · `huntcon` · `calmasin` · `calmacon`) y **se niega a arrancar** si no es ése, diciendo cuál
es. La precondición (fila 01) también se marcó verde con `hunt SI` y `enemigo Player [1]` en su propia
salida, pidiendo lo contrario; y la 07 se marcó verde con la nota cortada en el encabezado del
muestreo — **el veredicto de los 30 s nunca salió**.

### ⚠ Y el instrumento se contradijo a sí mismo en la misma corrida

Dos muestras, mismo estado (`hunt SI · enemigo ninguno · facewalk 1`, 196 u/s en línea recta):

```
quiere yaw 90 ( la escribimos NOSOTROS ( facewalk ) )      mirada vs marcha 0 grados
quiere yaw 90 ( NADIE la mueve hace 1.6 s -- CONGELADA )   mirada vs marcha 0 grados
```

**Causa:** `quieta` mide *que el valor no cambió* y yo lo llamaba *que nadie lo escribió*. Un bot que
camina derecho tiene dirección de marcha constante, así que el facewalk le escribe **el mismo ángulo
cada tick**: lo movemos siempre y el valor no se mueve nunca. Y la rama de `quieta` estaba **antes** de
la que sí tenía marca directa (`phantom_lookWroteAt`).

El «y caminando» que había agregado como discriminante no ataja nada de esto — el bot sí camina. *Un
discriminante que no separa los dos casos que se confunden es decoración.* **El que lo atajaba estaba
en la línea de abajo, `mirada vs marcha 0`, y no lo miré.** Reordenado: primero lo medido, después lo
inferido. Y el tercer balde dejó de llamarse `NADIE`: sin una marca adentro del `shootAt` de la base,
«no cambió y no fuimos nosotros» no distingue *nadie escribió* de *la base escribió el mismo valor*.
*Un balde nombrado por la conclusión que uno quiere sacar la regala.*

### Lo que sí cerró, y no se vuelve a correr

- **El control (`facewalk 0`)** reprodujo el defecto **exacto y en el régimen correcto**:
  `congelada 91 de 95`, `giro barrio 0 · abanico 0`, `nadie 96`.
- **La otra guarda:** `LA BASE 60 · NOSOTROS 0 · NADIE 0` con `vs jugador media 5,2°`. No le peleamos
  el aim a la base.
- **El separador, con sus dos lados:** tapado → `lo tapa el mundo ( brush ) a 215 u`; de frente → las
  tres columnas en `SI`. Y de yapa, `ai_ignoreplayers 1` dio `ShouldBeEnemy NO` con el veredicto
  correcto — el control de que la puerta puede cerrarse.

**El arreglo tiene evidencia, pero de una fila que no era la suya:** la primera toma de la 06 lo pilló
en `hunt SIN enemigo` con `facewalk 1` → `( la escribimos NOSOTROS ( facewalk ) )` y
`mirada vs marcha 0 grados`. Una muestra suelta contra una ventana de 100.

### La 06 no se puede leer todavía, y ahora hay con qué

`ve SI` + `ShouldBeEnemy SI` + `enemigo ninguno` a 26.014 u. Entre *«te ve»* y *«sos mi enemigo»* hay
dos pasos que no se veían, y **tienen latencias distintas**: adentro de `MaxSeeEnemyDistance` (3000 u)
`FindEnemies` escribe la memoria **antes** de `FindPriorityEnemy`, o sea un pase; arriba de 3000 u la
única rama es *cheap infinite view distance* (`shared.lua:3185`), que mira **un jugador por pase** y
corre **después** de `FindPriorityEnemy` — lo que escribe se lee recién en el pase siguiente: **~1 s**.

Y esa primera toma salió **inmediatamente después** de un `ai_ignoreplayers` pasando a 0, o sea en el
primer segundo de haberse abierto la puerta; la segunda toma **sí** adquirió, a 20.796 u. Con lo que
hay **no se puede separar «tardó» de «no lo hace»**. `phantasmagoria_ghost_rel` imprime ahora la línea
`mem` (memoria + edad) y el próximo barrido del `enemy_handler`, y el veredicto nombra el archivo y la
línea según cuál de los dos eslabones falle. *Un mecanismo con latencia necesita que el instrumento
diga cuánta, o el que mide la confunde con una falla.*

Planilla `dev/checks/phantasmagoria-mirada-r13b.html`, 7 filas, **sin correr**.

---

## 2026-08-07 (19) — La mirada clavada en hunt: **una guarda preguntaba por el flag y su premisa era el enemigo**

Reportado en juego después de la ronda 12: *«el stuck parece estar solucionado pero ahora el bot no me
sigue cuando está cazando, y queda mirando a un sitio en particular»*. **No sale del bloque del
encaje** — las tres perillas de las rondas 9-12 estaban en 0 en la corrida donde se vio.

### La cadena, y es más cerrada de lo que el comentario del facewalk decía

`enemyoverrides.lua:1874` —el único `SetDesiredEyeAngles` que puede correr caminando— vive dentro de
`Term_LookAround`, y a `Term_LookAround` la llama **un** sitio: `shooting_handler`
(`shared.lua:3512`). Cinco líneas antes, `:3492-3506`:

```lua
local wep = GetActiveLuaWeapon( self ) or GetActiveWeapon( self )
if not IsValid( wep ) then
    if TERM_FISTS then ... return
    elseif IsValid( enemy ) then shootAt( LastEnemyShootPos ) return
    else return                       -- <- NOSOTROS, SIEMPRE
    end
end
...
Term_LookAround( self )               -- <- INALCANZABLE para el fantasma
```

El fantasma pone `DefaultWeapon = false` y `TERM_FISTS = false`, así que `wep` **nunca** es válido y
los tres caminos se salen antes. **Para este bot el único escritor de la mirada es
`shootAt( LastEnemyShootPos )`, y ése pide un enemigo válido.**

### El defecto: `if myTbl.phantom_Hunting then return end`

El facewalk (2026-08-06) se apagaba en hunt con el comentario *«cazando manda la base: apunta al
enemigo»*. **La premisa de esa frase no es el hunt, es tener enemigo**, y son cosas distintas: el
fantasma entra en hunt por el flag —`phantasmagoria_hunt`, y mañana la cordura—, no porque haya visto
a nadie. En todo el hueco entre el flag y el primer avistaje no hay enemigo, la base se sale antes de
`Term_LookAround`, y esa guarda apagaba al único que quedaba. La cara quedaba clavada en el último yaw
que alguien hubiera escrito: **`-87.7` en dos lecturas tomadas a 1400 u de distancia una de la otra**.

**La guarda de verdad estaba escrita en la línea de abajo** (`IsValid( GetEnemy )`) y era inalcanzable
en hunt. *Una guarda cuya premisa es otra condición tiene que preguntar por esa condición, no por la
que suele venir con ella.*

### El instrumento acreditó el defecto, y con la etiqueta al lado del dato que la desmentía

`lookLines` imprimía `quiere … ( lo pide la base ( enemigo ) )` **deducido del flag**, y el reporte de
la ronda 12 lo mostró **doce veces al lado de `enemigo ninguno`, en la misma pantalla**. Nadie pedía
nada. *Una etiqueta deducida de un flag no es una medición de lo que pasó, y miente con la misma cara
con que acierta.*

Ahora se **mide**, con dos marcas que pone `BehaveUpdate`: cuándo cambió el valor (lo escriba quien lo
escriba) y cuándo lo escribimos nosotros. Y el «CONGELADA» pide su discriminante —**y caminando**—
porque un fantasma parado tiene la mirada quieta por el motivo correcto.

### `phantasmagoria_ghost_rel` gana la mitad que le faltaba: **ver**

Con sólo `ShouldBeEnemy`, *«no me sigue»* no se puede contestar: un `SI` al lado de `enemigo ninguno`
deja igual de vivas *«la relación está mal»* y *«la relación está bien y no me ve»*, que son dos
arreglos en dos archivos distintos. Ahora imprime `CanSeePosition` · `PosCanSee` · `ClearOrBreakable`
· `IsSeeEnemy`, **qué lo tapa** (del trace que `PosCanSee` ya devuelve, no de uno nuestro) y el
veredicto de las dos columnas juntas.

Y `Term_FOV`, que **no es decoración**: con `< 180` la detección es un cono alrededor del aim y una
cara clavada dejaría al bot ciego por atrás — las dos fallas serían **una**. Lo ponemos en 180
exactos, donde `IsInMyFov` devuelve `true` siempre y `FindEnemies` usa una esfera, así que **son dos
fallas separadas**. Eso hay que poder leerlo: un tercero mueve `termhunter_fovoverride` y cambia.

### ⚠ La otra mitad del reporte NO es un defecto, y no se tocó

*«No me sigue»* con el fantasma lejos es la forma actual del andamio: **`phantasmagoria_hunt 1` abre
la puerta (`ShouldBeEnemy`), no apunta el fantasma hacia vos.** Sin línea de visión no hay enemigo, y
sin enemigo el bot deambula (`movement_biginertia`, *«nothing better to do»*). La fila 8 de
`hunt-r1` cerró en verde **a 3 m**. Que el hunt salga a buscarte es Diseño 4/19 (la cordura), no un
arreglo de este archivo — se nombra acá para que no vuelva a leerse como regresión.

Planilla `dev/checks/phantasmagoria-mirada-r13.html`, 6 filas, **sin correr**.

---

## 2026-08-07 (18) — Ronda 11 CORRIDA: **el bailout nunca disparó, y el gatillo era mío**

Marcó 6 de 6. Una lo está, tres son *Sin correr*, y el hallazgo es un defecto de mi diseño que
**ninguna fila pedía**.

### `disparados 0` en las dos mitades del A/B, por dos causas del gatillo

Contaba *«N caminatas seguidas que vencen habiéndose movido menos de 15 u»*:

- **El bot encajado se mueve.** `SE MOVIO 93 u`, `69 u`, `64 u` — se sacude adentro de la jaula de
  props sin salir de ella, y cada una reseteaba el contador. *Cuánto se movió la caminata no dice si
  el bot se despegó: dice cuánto se agitó en el lugar.*
- **Entre caminata y caminata pasan hasta 81 s.** El gatillo colgaba del fin de una caminata, que la
  arranca el handler — que tras cada rescate vacía `historicPositions` y vuelve a juntar 81 a una por
  segundo. Medido: `rescates 1` en una ventana de 100 s. Con N=3, **cuatro minutos**.

**Medí el movimiento de la caminata en vez del desplazamiento neto, y até el arreglo al reloj del
mecanismo que estoy arreglando.** *Un rescate que espera al que falló hereda su latencia.*

**Reescrito sobre `quieto desde`**, que ya estaba medido y a la vista: 59,7 s en la r10, 47 s en la
r11, y **nunca más de 1 s** en el control con el bot sano. Pide además que el bot **quiera** moverse
(`GetDesiredSpeed` alto, velocidad real en cero), porque *estar quieto y estar trabado se ven igual
desde una posición* — sin eso, `movement_watch` (Diseño 18) haría que un fantasma plantado a
propósito se teletransportara solo.

⚠ **`_stuckbailout` → `_stuckbailoutsecs` (default 20).** Cambió de nombre porque **cambió de
unidad**: las dos son `FCVAR_ARCHIVE`, así que un `stuckbailout 3` guardado se leería como tres
segundos. *Una perilla que cambia de unidad tiene que cambiar de nombre, o el valor guardado miente en
silencio.*

### Tres filas *Sin correr*, y una que cerró a la cuarta

Las **01** y **02** porque en ninguna de las dos mitades se reprodujo el bucle de `SE MOVIO 0 u`; la
**03** porque se probó corriendo en vez de encerrando al bot en props. **La 04 CERRÓ**: `>>> PASA: la
convar en 0 le gano a un flag que dice que SI`, con los dos lados del A/B y 39 pisadas en el `listen`.
*El botón resolvió lo que cuatro recetas escritas no pudieron.*

### Dos hallazgos que salieron de contadores puestos para otra cosa

- **Catorce `SALTA altura pedida 20` en tres segundos** (`t=3005.8` a `t=3008.4`). Es el
  `simpleJumpMinHeight` de la base: un bucle de salto contra algo.
- **La alarma de `server_doors.lua` se disparó:** `atraveso mas de 5 s seguidos y se lo forzo a
  solido. Eso no deberia pasar`.

---

## 2026-08-07 (17) — Ronda 10 CORRIDA: el arreglo anduvo, **y destapó el defecto de abajo**

Marcó 8 de 8. Cuatro lo están, una es la que cierra el arco y dos son *Sin correr*.

### El arreglo hizo lo que prometía, con número

Los destinos **nacían a 71, 88, 96, 97, 99, 100, 104, 111, 116 y 133 u** — todos bajo el umbral de
150 de `:3676`. *La premisa de la r9 era una inferencia y ahora está medida.* Corregidos a ~300 u el
bot **se movió**: `SE MOVIO 152 u en 1,4 s`, `155 u en 0,8 s`, `185 u en 4,7 s`, con
`cortos 8 · corregidos 8 · sin reemplazo 0`. Y `llego` cayó de **7 de 7** a **1 de 6**: el resto dice
`se venció`, que es la verdad. **El éxito falso desapareció.**

### ⚠ Y la predicción del pie de la planilla quedó refutada

Decía *«arreglando la caminata el bot se despega y nunca se llega a la rama del teleport»*. Con el
destino sano a **306 u**, cinco `la caminata SE VENCIO ( 10 s )` seguidas con **`SE MOVIO 0 u`** y la
misma posición hasta el sexto decimal. **Encajado, el bot no puede caminar** — la caminata no es un
rescate para ese caso por construcción. La única rama que sacaría a un bot inmóvil es el teleport, y
`:3868` lo veta mientras `IsSeeEnemy` sea true, que es exactamente la situación porque se encaja
saltando *hacia* el jugador. *no puede caminar + no puede teletransportarse = physgun.*

Entró **`phantasmagoria_ghost_stuckbailout`** (default 3, `0` = control): tras N caminatas seguidas
que vencen habiéndose movido menos que el radio con el que la propia base define «quieto» (15 u), lo
teletransportamos nosotros con el helper de la base. **El gatillo no es una lectura: son los dos
números que esta ronda midió.** ⚠ Teletransporta a un fantasma que te está mirando: se ve.

### La fila 05, contestada con los datos de la 04

**El ciclo de 10 s es `extremeUnstuckingUntil`** (`:3913`), medido directo: `destino a 306 u` y
exactamente 10,0 s después `SE VENCIO ( 10 s )`. **Pero el caso con destino < 150 sigue sin
explicarse:** hoy un destino a 301 u del que el bot recorre 152 u da `LLEGO` a **1,4 s**, así que
`:3674` reacciona rápido — y en la r9, con ~100 u, tardaba 10 s. Los dos conjuntos no se reconcilian
y la medición que falta se provoca con `escapedist 0`, que es la mitad ① que nunca se corrió.

### Dos criterios míos refutados en su propia salida

- **`esperado … = -1 neto`.** Un ritmo **negativo**. El trimming de `:3774-3777` corre sólo dentro del
  `if #historicPositions > size`, y por arriba tampoco resta 2 en régimen: saca 2 y al pase siguiente
  inserta 1, o sea que **oscila**. No hay un neto que sea un número. Y el `faltan ~81 s` de al lado
  usaba mi `noNav` contra el de la base: la misma fracción de dos relojes que la r9 ya había
  refutado, **escrita otra vez en la línea de al lado**. Las dos se borraron.
- **«`tareas` tiene que seguir diciendo 8».** Salió 7, 8 y 8. El número de tareas activas **no es
  constante por diseño**.

### La fila del control de `stepsilent`, por cuarta ronda

Cuatro modos de falla distintos sobre la misma fila —falta el `hunt 1`, la convar nunca pasa por 0,
el flag no se pone, el flag se pone y se saca— *no son cuatro descuidos: son una receta de cinco
pasos demasiado larga para ejecutarla a mano.* Entró **`phantasmagoria_ghost_steps control`**, que
corre los cinco, mide, **escribe el veredicto binario** y devuelve el estado con `control off`.

---

## 2026-08-07 (16) — Ronda 9 CORRIDA: **el rescate se anuncia exitoso sin rescatar**

Planilla `dev/checks/phantasmagoria-encaje-r9.html` corrida por el autor. **Marcó 9 de 9 y cuatro lo
están** — pero encontró la causa del encaje, y **no es ninguno de los tres candidatos leídos**.

### Lo que midió

**Siete rescates en 60 s, cada 10 s clavados, con el bot inmóvil.** `rescates 7 ( TELEPORT 0 ·
CAMINAR 7 · llegó 7 · se venció 0 )`, con `quieto` subiendo monótono **1,5 → 8,7 → 18,6 → 28,6 →
38,8 → 48,7 → 59,7 s** y cinco `la caminata LLEGO ( < 150 u )` sobre la **misma posición exacta**
(`1691.524170 -780.388794 148.456223`). *La base se declaró exitosa siete veces sobre un bot que no
se movió un centímetro.*

**El teleport falla igual:** los tres de la sesión movieron **83 u, 8 u y 46 u**. Ninguno llega a dos
metros (52,5 u = 1 m). El autor lo escribió al lado sin verlo —*«lo vi moverse al camarote, sigue
parado aún»*— y necesitó un segundo `force` para despegarlo.

**La raíz es común a las dos ramas:** `freedomPos` se elige por **distancia mínima**
(`shared.lua:3849`, `distToMe < bestDist`) entre las navareas de una caja de ±3000 u, excluyendo sólo
la de abajo. Este mapa tiene **1715 navareas** porque el parcheador de la base crea áreas donde
camina alguien, así que «la más cercana que no es la mía» está pegada. Después `:3676` da la caminata
por terminada con `dist < 150`, y un destino que nace debajo de ese número vuelve al rescate un
no-operativo que se anuncia como éxito.

**Falta medir por qué el ciclo dura 10 s y no un tick.** Con el destino a menos de 150 u, `:3674`
debería declarar `SUCCESS` en el pase siguiente. Hay dos explicaciones y no se separan leyendo; el
instrumento ya imprime la distancia al destino en el evento.

### Los tres candidatos, resueltos

- **(a) el veto de `IsSeeEnemy` — CONFIRMADO**, aunque en la fila equivocada: con `ve SI`, 7 de 7 por
  `CAMINAR`; con `ve NO`, `TELEPORT`.
- **(b) los ~80 s fuera del piso — DESCARTADO para este caso:** encajado entre props y el techo, el
  `watch` dio **`piso SI`** casi siempre (queda apoyado en un prop), así que el umbral es **11** y la
  detección tarda ~3 s.
- **(c) la primera pasada nunca teletransporta — CONFIRMADO:** `canGotoEscape SI` → `CAMINAR`.
- **La hipótesis del salto — REFUTADA con número:** alturas pedidas 60, 60, 12, 67,9, 67,9 y 32. El
  tope es 245 y **nadie pide 245**.

### Cuatro filas verdes que no midieron lo que decían

Las **02** y **04** son *Sin correr* por su propia precondición escrita (`canGotoEscape NO` donde
pedía `SI`; `ve al enemigo NO` donde pedía `SI` — y la 04 era la fila estrella del arco). La **03**
pasó con `se movio 46 u` contra un criterio que pedía «cientos». La **08** se corrió mal por **tercera
ronda seguida**: `phantom_SilentSteps = false · override nil`, o sea que el `flag pasos 1` no se
puso, y no hubo flag al que ganarle.

### Dos defectos de instrumento, los dos míos

- **`hist N / umbral` emparejaba el numerador de la BASE con un denominador MÍO**, muestreados en
  instantes distintos. Con `noNav` oscilando salió `86/11` → `92/81` → `92/11` en muestras
  consecutivas. *Una fracción cuyas dos mitades vienen de dos relojes distintos no es una fracción.*
  Ahora se **mide** el salto real y el umbral va aparte.
- **El criterio «sube de a 1 o de a 4» era incumplible.** El trimming de `:3774-3777` saca **dos** por
  pase, así que lo que se ve es el neto: lo medido fue **+6** = 8 (`×4` `noNav`, `×2` `isUnstucking`)
  menos 2. Ninguno de los dos valores esperados podía aparecer nunca.

### Un dato que corrige una afirmación vieja

`tareas 8 ACTIVAS de 32 registradas`. `ESTADO.md` venía diciendo que las 31 tareas listadas eran «el
cerebro heredado **corriendo**», y es falso: `movement_watch`, `movement_stalkenemy`, `movement_camp`
y `movement_followsound` —las que el diseño da por gratis— están registradas y **no corren**.

### El arreglo, escrito y sin correr

**`phantasmagoria_ghost_escapedist`, default 300, `0` = control.** Cuando la base pone un destino a
menos de esa distancia, lo reemplazamos por el más cercano que esté más lejos, conservando el filtro
que no desatasca acercando al enemigo (`:3843`). El default es el **doble** del umbral de `:3676`, así
que un destino no puede nacer cumplido.

**Intervención mínima:** no se copia el handler vía `DoCustomTasks`, no se envuelve
`terminator_Extras.TeleportTermTo` (global de todos los terminators) ni `SetPosNoTeleport` (otros seis
call sites). Se corrige un campo de `data`, el mismo que ya leíamos.

**Corre en `AdditionalThink` y no en el poll, y el lugar no es intercambiable:** la corrutina llama
`AdditionalThink` en `behaviouroverrides.lua:676` y las tareas en `:694`, así que desde ahí llegamos
siempre antes del bloque que declara la llegada, en el mismo pase. Desde un poll de 4 Hz podrían pasar
0,25 s y `:3674` ya lo dio por cumplido. *Un arreglo que llega tarde a veces es un arreglo
intermitente, que es peor que ninguno porque no se puede medir.*

**El teleport no se corrigió a propósito:** tiene el mismo defecto y la apuesta es que arreglando la
caminata nunca se llega a esa rama, porque a ella sólo se entra con `not canGotoEscape` y ese reloj lo
pone la caminata al fallar. **Es una predicción, no una medición**, y el instrumento sigue contando
los teleports con su distancia.

Tres contadores separados —`cortos vistos`, `corregidos`, `sin reemplazo`— porque *un solo contador
leería igual un arreglo que no corrió y uno que no hacía falta*.

### El botón ahora se niega

Tres filas de la r9 se corrieron fuera de su precondición **con los valores impresos a la vista**.
`force` toma ahora `primero` / `segundo` / `veto`, comprueba el estado y **no gasta el disparo** si no
corresponde. Es la lección de `testdoor` en la ronda 6, otra vez: *imprimir la precondición junto al
veredicto no alcanza, hay que negarse.* Planilla `dev/checks/phantasmagoria-encaje-r10.html`, 8 filas.

### Y un pedido del autor, implementado

*«El ruido metálico al saltar es un remanente del terminator que es un androide robótico.»**
`ENT.MetallicMoveSounds = false`. **No es una desviación de la base: su propio bot desarmado ya lo
apaga** (`terminator_nextbot_fakeply.lua:67`, el molde de este fantasma, y `csoldier.lua:131`) — le
copiamos el `DefaultWeapon` y el `TERM_FISTS` y le dejamos los sonidos de robot. Censados los **cinco**
call sites: en los cuatro de movimiento el `MakeFootstepSound` está **afuera** del `if`, así que el
salto queda con la pisada de la superficie en vez de mudo. ⚠ Se lleva cuatro `ScreenShake` y tres
`Whaps`, y **cambia lo que midió la r8b**.

---

## 2026-08-07 (15) — El encaje contra el techo: **el instrumento, no el arreglo**

`server_stuck.lua` (nuevo, ~640 líneas de las que la mayoría son el porqué), más un arreglo en
`phantasmagoria_ghost_where`. Planilla `dev/checks/phantasmagoria-encaje-r9.html`, **9 filas, sin
correr**. **No cambia ningún comportamiento del NPC**: este bloque sólo mide.

### El defecto, y de dónde salió

Lo reportó el autor y **no salió de ninguna planilla** sino de preguntarle por su experiencia:
*«he visto que salta y queda pegado entre objetos y el techo de un interior, ahí hay que sacarlo con
el physgun»*. Es peor que un atasco de puerta: de aquél el fantasma sale solo, de éste no sale nunca.

La base **tiene** rescate (`reallystuck_handler`, `shared.lua:3647-3926`) y está registrado en
nuestro fantasma. **O sea que el rescate existe y no rescató**, y no había ningún instrumento que
dijera por qué. Hay tres candidatos leídos en la base —el veto de `IsSeeEnemy` (`:3868`), los ~80 s
de detección fuera del piso (`:3714`), y que la primera pasada nunca teletransporta (`:3864`)— y
**ninguno medido**. La hipótesis del autor (*«tal vez se soluciona evitando que salte tanto»*) tampoco.
Por eso esta ronda no toca el salto: en este proyecto el arreglo obvio ya apuntó al candado
equivocado dos veces.

### ⚠ Lo que se creía probado y no lo estaba: «el rescate está corriendo»

La evidencia era *«aparece en la lista de 32 tareas de `phantasmagoria_ghost_where`»*. Y esa lista no
puede probarlo. `_where` recorre `m_TaskList`, que es el **registro estático**: `SetupTasks` lo llena
con todas las tareas declaradas (`taskoverride.lua:398-402`) y **nadie lo vacía nunca**. Lo que dice
si una tarea *corre* es `m_ActiveTasks` (`terminator_nextbot_base/tasks.lua:104`).

Y el handler se termina a sí mismo en su propio `OnStart` si `ReallyStuckDisable` está puesto o si
`MoveSpeed <= 0` (`:3660`, `:3664`) — **y en los dos casos seguiría apareciendo en esa lista igual**.
*Una lista de lo que existe no puede contestar por lo que corre.* `_where` ahora imprime
`N ACTIVAS de M registradas` y marca cada una.

### El dato sale de la tabla `data` de la base, no de una sombra

`StartTask` guarda la tabla de cada tarea en `m_ActiveTasks[task]` (`taskoverride.lua:201`), y **es la
misma tabla** que el handler muta. Así que `ghost.m_ActiveTasks["reallystuck_handler"]` da lectura
directa de `historicPositions`, `maybeUnderCount`, `nextUnstuckGotoEscape` y
`extremeUnstuckingUntil` — o sea `canGotoEscape` **exacto**, no recalculado. Sólo `stuck` y
`sortaStuck` se recalculan, porque son locales del pase, y se recalculan **sobre los arrays de la
base**; el reporte lo dice en la misma línea. *Un control que toma las dos mitades de la misma fuente
no puede ver que esa fuente está mal.*

### La rama que tomó el rescate se lee del motivo que la base ya escribe

`StartTask` recibe un `reason` y el comentario de la base dice para qué (`:189`, *«This is an
essential debugging tool, Use it»*). El handler usa tres, y los tres son únicos:
`reallystuck AFTER TELEPORT` (`:3896`), `reallystuck SUCCESS` (`:3679`) y `reallystuck partial FAIL`
(`:3697`). No se detecta por `TeleportTermTo` —es un global de todos los terminators del servidor— ni
por `SetPosNoTeleport`, que tiene otros seis call sites.

**Y la rama de caminar no se detecta por `freedomGotoPosSimple`**, que es lo obvio: el bloque de
`:3674` lo borra apenas la distancia baja de 150 u, o sea que aparece y desaparece entre dos muestras.
Se detecta por `nextUnstuckGotoEscape`, que la rama pone en `+80 s` y **nadie baja nunca**. *Un
instrumento más frágil que lo que mide se rompe justo cuando hace falta.*

### El botón, y la trampa que tiene adentro

`overrideVeryStuck` (`:3747`, usado en `:3816`) fuerza la rama en ~1 s sin esperar los 80. Pero
**el primer disparo nunca teletransporta, ni con `hunt 0`**: con los dos relojes en 0,
`canGotoEscape` es `true` y `extremeStuck or not canGotoEscape` da false. Hace falta un **segundo**
disparo entre 5 y 80 s después. Un A/B corrido una sola vez habría leído eso como *«(a) es falsa»*,
que es la conclusión inversa. El botón lo imprime y la planilla lo separa en dos filas.

Tampoco es gratis: la primera línea de la rama es `ReallyAnger( 60 )`, y `canDoRun` consulta
`IsReallyAngry` (`motionoverrides.lua:754`, `:784`) — o sea que mueve el bloque de velocidad.

### Una cuarta salida que no estaba en ninguna lista, y sale de la aritmética

La rama de caminar pone el reloj en `CurTime() + 80` (`:3911`) y **vacía `historicPositions`**
(`:3923`). Para un bot que no está en el piso, volver a juntar 81 posiciones a una por segundo tarda
**81 s**. Si eso es así, cuando el handler vuelve a poder evaluar el reloj de 80 ya venció y
`canGotoEscape` es `true` otra vez: **un bot encajado en el aire nunca alcanzaría
`not canGotoEscape`, ni siquiera sin mirar a nadie**. Son 80 contra 81 — la clase de margen que no se
cierra leyendo. El reporte imprime los dos relojes con su signo y la cuenta regresiva al lado.

### Los saltos: contados, no juzgados

`ENT.JumpHeight` es 245 (`shared.lua:111`, `70 * 3.5`). Y `ENT.Term_Leaps` es `nil` en la base
(`:112`) y este fantasma no lo declara, así que las dos ramas de salto-hacia-el-enemigo
(`motionoverrides.lua:2693`, `:2697`) y el **único** call site de `JumpToPos` (`:2744`) están muertos
para nosotros. Eso da un control gratis: **`saltos leap` tiene que dar 0 siempre**.

Y **pedido no es ocurrido**: `ENT:Jump` se sale en silencio si no está en el piso (`:2971`), así que
los contadores separan `N pedidos` de `M ocurrieron`. Es la lección del botón `jump` de las pisadas.

### El instrumento que audita a los instrumentos también tenía el defecto

`dev/glua_check.py --selftest` se declaraba **NO USABLE** sobre este addon: 3 de 4 mutaciones daban
rojo y la del paréntesis daba verde. La causa no era el parser —era el **control positivo**, que
mutaba con un `re.sub` crudo sobre el texto y caía adentro del comentario de cabecera de
`client.lua`, cuyo primer `(` está en la línea 13. El código seguía siendo válido y el parser lo
aceptaba **con razón**. Se extrajo el scanner del traductor (que ya respetaba strings y comentarios)
a `_scan()`, y la mutación ahora sólo toca código. **Control de que el refactor no movió nada: los
100 archivos de la base + el addon dan el mismo veredicto que antes, byte por byte.**
*Un control que se rompe a sí mismo desacredita al instrumento sano que audita.*

---

## 2026-08-07 (14) — El silencio de las PISADAS, y **silenciar no puede significar «que no pase»**

`server_steps.lua`. Planillas `dev/checks/phantasmagoria-pisadas-r8.html` (8 filas) y `-r8b.html`
(4 filas), las dos **corridas**.

### La restricción del autor es la inversa de la de las puertas, y es lo que le da forma al archivo

*«El quitarle el sonido de los pasos debe ser coherente con que después el Paramic los va a poder
escuchar.»* Con las puertas el silencio se hizo **borrando un dato** —las siete keyvalues— y ahí está
bien. Acá no: la pisada tiene que **seguir ocurriendo**, con su posición y su intensidad, y lo único
que se apaga es que el jugador la escuche. Por eso el `hook.Run( "PhantasmagoriaGhostFootstep", … )`
corre **antes** del `return true` que silencia, y `callada` viaja **como dato** en vez de decidir si
el evento existe.

**Cerrado en juego:** el consumidor de prueba recibió **39 pisadas en 15 s, las 39 calladas**, cada
una con posición, pie, volumen y superficie, mientras el jugador no oía ninguna.

### ESTADO.md nombraba el punto de extensión equivocado, y era el mismo error de siempre

Decía que `IsSilentStepping()` *«apaga toda esa familia, no sólo las pisadas»*. Se censaron los
**seis** call sites de `MakeFootstepSound` y es al revés: **no tapa ninguna pisada.** Ni la de
caminar (`ProcessFootsteps`, `behaviouroverrides.lua:141`, no lo consulta), ni la del salto
(`motionoverrides.lua:2997`, con el chequeo en **:2999**, o sea *después*), ni las tres del
aterrizaje. Sólo la de la caída letal, y de rebote.

*No es una palanca gruesa: son dos palancas para dos familias y hacen falta las dos.* Sin
`IsSilentStepping` un fantasma «callado» sigue sonando al aterrizar, porque la base trae
`MetallicMoveSounds = true` (`shared.lua:161`) y este fantasma no lo pisa.

### Y ese override abría una fuga que no es un sonido

`LethalFallDamage` (`motionoverrides.lua:3577`) empieza con `if self:IsSilentStepping() then return
end` y el `TakeDamage( math.huge )` está **adentro**, en `:3596`. Ese `return` no se lleva sólo tres
`EmitSound`: se lleva la muerte. **Un flag de sonido habría regalado inmunidad a la caída letal.** Hay
override propio que repone el daño, y quedó medido: `silencio SI` → `vida 900 → -2147482748`.

### El agujero de la base, convertido en número

`footsteps.lua:330` hace `if not stepSound then return end` **antes** de llamarnos, así que una
superficie sin sonido de pisada tira el evento y el Paramic no lo vería. No se puede tapar sin
reescribir `MakeFootstepSound` (la base pide que no), pero sí medirlo: un envoltorio que sólo cuenta
da `PERDIDAS = pasos − vistas`. **`PERDIDAS 0` en las nueve lecturas, sobre cuatro fantasmas** —
hasta las superficies sin datos propios devuelven `default.stepleft`.

De paso salió el dato que el Paramic va a necesitar: el volumen viaja por superficie —`concrete 0,8`,
`dirt 0,4`, `cardboard 0,4`, **`wood 1`**—, y la madera es la más fuerte porque **no está en la tabla
de materiales de la base** (`footsteps.lua:265-286`) y cae al default.

### Tres defectos de instrumento, los tres míos

- **La fila del salto no se podía provocar.** De las tres filas que necesitaban forzar algo, dos
  tenían botón (`listen`, `falltest`) y la del salto dependía de que el bot decidiera saltar solo. La
  nota que la cerró —*«no escuche nada ni saltos ni nada»*— no distingue **«saltó y no sonó»** de
  **«nunca saltó»**, que es la única diferencia que esa fila existía para medir. *La regla estaba
  escrita en la planilla y la incumplí escribiendo la planilla.* Ahora hay `… steps jump`.
- **La bitácora identificaba al fantasma por `EntIndex`, y GMod lo reusa.** Seis líneas decían todas
  `#1340` con los pasos yendo 1 → 38 → 182 → 215 → **1**: no era un contador retrocediendo, era el
  fantasma que murió en el `falltest` y el que se spawneó después compartiendo etiqueta. *Una
  etiqueta que se repite entre dos objetos distintos no identifica: agrupa.* Ahora `#1340/c37`.
- **La ayuda de `_stepsilent` prometía un control que no da.** Decía *«0 = ninguno camina en
  silencio ( control )»*, copiada de las tres convars de puertas, donde hay **una** sola causa de
  silencio; acá hay dos y esta perilla gobierna una. La fila del control negativo se corrió mal **dos
  rondas seguidas** con el mismo síntoma: poner la perilla en 0, seguir sin oír nada, y que el
  reporte nombrara sólo la otra causa. **La perilla que acababas de mover no aparecía en la
  respuesta.** Arreglado en los dos lados: la ayuda ya no promete un control global, y `la decidio`
  imprime la capa tapada.

### Y la plantilla de checks eran cuatro cosas a reemplazar, no cuatro

Al reciclar la r7 la planilla salió con el `<title>` de la ronda anterior —el nombre de la pestaña, o
sea justo lo que se ve **antes** de abrir el archivo—, y la r7 arrastraba **dos** `</footer>` con un
párrafo huérfano de la r6 entre medio. No lo agarró la lista de cosas a cambiar: lo agarró un chequeo
que buscaba **arrastre del bloque anterior**. *Una lista de N ítems sólo encuentra los N que alguien
ya sabía.* `dev/PLANTILLA_CHECKS.md` corregido.

---

## 2026-08-06 (11) — Ronda 5 CORRIDA (5 pasa / 2 falla): **el sonido de una puerta no se intercepta, se le borra a la puerta**

`dev/checks/phantasmagoria-silencio-r5.html`. El campo pisado quedó arreglado (`campo = false` en el
reporte) y el instrumento por fin dice **quién** decidió la marcha.

### El silencio falló por cuarta vez, y esta vez con veredicto

**La bitácora que puse justamente para diagnosticarlo salió VACÍA** — con la ventana abierta, la
puerta abriéndose (`a los 0.9 s: m_toggle_state = 0 ABIERTA`), `silencio 3 aperturas silenciadas`, y
el sonido oyéndose. No registró **nada**: ni sonidos bloqueados ni sonidos sin bloquear cerca de la
puerta.

> **Un log vacío donde tenía que haber algo vale más que uno lleno: descarta la familia entera de
> hipótesis, no una.** Había tres candidatas —ventana corta, sonido de otro emisor, hook ciego— y la
> lista vacía mató las dos primeras de un golpe. `GM:EntityEmitSound` **server-side no ve** esos
> sonidos, porque no nacen en Lua del servidor.

### El camino bueno lo señaló el autor, y su aporte no es código: son siete nombres

*«Tengo un mod instalado para abrir las puertas silenciosamente, te recomiendo extraerlo y ver cómo
lo hace.»* — **Immersive Door Openable** (WSID `3717549037`), desempacado a
`dev/other/immersive door openable/` y dado de alta en `dev/mods_workshop_mapa.md` §2.

**No engancha nada.** Le pisa a la puerta sus **propias keyvalues** de sonido con `""` antes de
moverla y se las devuelve después (`sv_door.lua:61-67` / `:90-96`). Así el sonido no se bloquea: **no
llega a existir**, y por eso ningún hook hacía falta. Son **siete** campos y **dos familias**:

| Familia | Clases | Campos |
|---|---|---|
| `CBaseDoor` | `func_door`, `func_door_rotating` | `noise1` (mientras se mueve), `noise2` (**el golpe de llegada**) |
| `CBasePropDoor` | `prop_door_rotating` | `soundopenoverride`, `soundcloseoverride`, `soundmoveoverride`, `soundlockedoverride`, `soundunlockedoverride` |

`noise2` es exactamente el sonido que el autor venía reportando desde la ronda 3 (*«es el sonido de
GOLPE de la puerta»*). Se copia **la técnica, no el código**: el propio archivo acredita el original
al z-team y su licencia está sin verificar.

**Y el mecanismo trae un riesgo que el hook no tenía:** ya no bloquea un sonido, **le borra un dato a
una entidad del mapa**. Si el que devuelve falla, esa puerta queda muda para todos, para siempre.
Por eso el reporte cuenta *puertas mudas AHORA MISMO*, la bitácora pasó a anotar **operaciones** (un
`devuelto` por cada `silenciado`) y hay `phantasmagoria_ghost_doors restore`. La fila 03 de la ronda
6 es esa vigilancia, y es la más importante aunque parezca la más aburrida.

### Dos observaciones del autor que eran diseño, no defecto

- **«Sí camina, pero mientras te caza y no te ve, empieza a correr hasta verte.»** Con el flag puesto
  yo devolvía `nil` y dejaba decidir a la base — y la base sólo se niega a correr **cuando te ve**
  (`canDoRun`). Ahora cazando decidimos **las dos ramas**. `false` ahí es seguro *porque es un
  método*: en un callback de `RunTask` la misma palabra significaría además robarle el evento a otra
  tarea. La misma palabra con dos significados según dónde se escriba.
- **La hoja que se abre encima.** `trabado 15,2 s · delante func_door_rotating · ABIERTA · a 0 u`,
  con `peor 17,6 s`. Su propuesta, literal: *phase momentáneo **con la condición de que la puerta
  marque como ABIERTA**; si está cerrada no tiene por qué pasar, así evitamos que las puertas que
  abren en reversa dejen pillado al npc.* Es mejor que lo que yo tenía por dos motivos: una puerta
  **cerrada** ya la cubre la regla de cercanía —taparla ahí escondería otro problema— y limitarlo a
  la hoja abierta ataca justo el caso que no tiene ninguna otra salida. La rama vieja disparaba con
  cualquier puerta lejana y salió **0 en todos los reportes de tres rondas**: la fila que iba a
  borrarla terminó encontrando para qué servía.

Planilla: [`dev/checks/phantasmagoria-keyvalues-r6.html`](../dev/checks/phantasmagoria-keyvalues-r6.html),
**6 filas, ninguna corrida**.

---

## 2026-08-06 (10) — Ronda 4 CORRIDA (9 pasa / 2 falla): el veto anduvo, y un campo estaba pisado por un método

`dev/checks/phantasmagoria-veto-r4.html`. **Los cinco arreglos de la ronda 3 quedaron confirmados en
juego:** con `opendoors 0` las puertas ya no se abren y `VETADAS` sube (161 en una corrida); `vistas`
distingue *«no vio»* de *«vio y se abstuvo»*; los flags por comando **sobreviven al respawn** y el
reporte nombra la capa que ganó (override / campo / convar); `ABRIO` dejó de mentir —`ABRIO 5 fallo
0` con cinco huellas— y cazando corre.

### El defecto que estaba a la vista en cada línea del reporte

```
camina  NO   campo = function: 0x8088...   porque el flag ... es nil
```

`ENT.phantom_WalksWhenHunting` era un **campo** y en `server_speed.lua` había un **método homónimo**.
Como los `include` corren después de la declaración, la función pisaba al campo: el resolvedor leía
una función —que no es `true` ni `false`— y caía a la rama *«el flag es nil»*.

> **Y el check que lo ejercía PASÓ igual, porque el default de esa rama coincidía con lo esperado.**
> *Un default que coincide con lo esperado convierte un campo roto en un check verde*, y eso no lo
> agarra ninguna corrida: lo agarra una guarda o nadie. Hay guarda, corre **después** de los includes
> (antes el pisado todavía no ocurrió: una guarda que mira demasiado temprano siempre pasa) y su
> lista sale de la misma tabla `FLAGS` que usa el comando, así que un flag nuevo queda cubierto solo.

### `ShouldRun` dejó de ser un callback de tarea: era una carrera

La fila del `walkhunt` no se pudo juzgar. La lectura: cazando **a 0 u** del jugador, `deseada 66`
(caminando). Causa leída: `RunTask` corta en el primer callback no-nil, y el `ShouldRun` de
`movement_followenemy` hace `return length > targetFollowDist and self:canDoRun()` — que con el path
corto (o sea cuando ya te alcanzó) devuelve **`false`**, no `nil`. Eso corta el recorrido y el nuestro
no llega a correr. Ganar dependía del **orden** de las tareas, que además no es estable (`SetupTasks`
las arranca iterando con `pairs`).

> **Un punto de extensión que depende del orden de ejecución no es un punto de extensión: es una
> carrera.** `ENT:ShouldRun` de la base es un método común, así que ahora se overridea y se encadena
> —determinista, como ya hacían `ShouldBeEnemy` y `BehaveUpdate`—.

**Y el check tampoco podía discriminar:** a 0 u la base camina *por su cuenta*, así que «camina» no
separaba nuestro flag de su comportamiento normal. El instrumento ahora imprime **quién decidió la
marcha** (`override propio` / `la base`).

### El silencio: tres rondas sin poder medirse, y no era una falla

Las tres veces la lectura salió con *«todavía no vio ninguna puerta cerrada»* y la bitácora vacía —
la precondición pedía que un fantasma silenciado abriera una puerta **justo** mientras el autor
escuchaba, y eso no se provoca deambulando. El autor lo dijo exacto: *«de que suena, suena, pero con
el check 06 no puedo decir si la convar hace algo o no.»*

> **Un check cuya precondición no se puede provocar no es un check** — y marcado como FALLA cuando en
> realidad está SIN CORRER, se lee como un mecanismo roto. Hay botón:
> `phantasmagoria_ghost_testdoor` abre la puerta más cercana *ahora*, con el silencio que
> corresponda, y avisa **ESCUCHA AHORA**. Es utilería de medición, no una mecánica.

### Una etiqueta mía que mentía

`vistas 191 puertas cerradas DISTINTAS` en un mapa que no tiene 191 puertas. El contador sube cuando
una puerta cerrada **entra al sondeo**, y la misma puerta entra y sale muchas veces mientras el
fantasma se mueve delante de ella. *El número estaba bien; la palabra «distintas» era mía y mentía.*

### Anotado y no arreglado

`Interpenetrating entities! (terminator_nextbot_phantom and func_door)` en la consola: es el engine
quejándose de que el bot está **adentro** de la hoja, que es exactamente lo que el atravesado hace.
Ruidoso, no fatal. Y `atraveso N · **0** por ATASCO` en **todos** los reportes de las rondas 3 y 4,
sin excepción: la fila 06 de la ronda 5 lo cierra a propósito antes de borrar la rama.

Planilla: [`dev/checks/phantasmagoria-silencio-r5.html`](../dev/checks/phantasmagoria-silencio-r5.html),
**7 filas, ninguna corrida**.

---

## 2026-08-06 (9) — Ronda 3 CORRIDA (3 pasa / 5 falla): **apagar lo nuestro no apagaba el comportamiento**

`dev/checks/phantasmagoria-flags-r3.html`. Cinco fallas y **ninguna era del mecanismo que el check
decía medir**: cuatro eran instrumento y una era un hueco de diseño. Lo que sí cerró: el comando de
puertas por fin existe (fila 01) y la huella se puede ver (fila 06).

### La falla que ordena las demás: el veto no cubría a la base

Con `phantasmagoria_ghost_opendoors 0` el reporte decía `abre NO` — correcto, nuestra escalera no
corría — y el autor reportó *«sigue abriendo las puertas aunque esté desactivado»*. **Las dos cosas
eran ciertas.** `tryToOpen` (`shared.lua:1249`) termina en `Use2` y lo dispara `ShootblockerThink`
cada 0,1 s, por su cuenta. Apagar *nuestra* implementación nunca iba a apagar la de la base.

> **La regla: apagar NUESTRA implementación no es apagar EL COMPORTAMIENTO cuando el comportamiento
> también vive en el tercero.** Un flag que dice «no abre» tiene que vetar **todos** los caminos, no
> sólo el que escribimos. Y el modo de falla es el más caro que hay: **el instrumento decía la verdad
> sobre lo nuestro mientras el juego mostraba otra cosa.** Pariente de *«saltear no es apagar»*.

El arreglo no duplica `Use2`: el veto va en `TerminatorBlockUse`, el hook que la propia base declara
**adentro** de `Use2` (`:1221`). Y el contador `VETADAS` cuenta las aperturas bloqueadas *incluidas
las que iba a hacer la base*, que son las que antes se escapaban.

### Tres defectos del instrumento, los tres del mismo tipo: medir bien y clasificar mal

- **`ABRIO 0 fallo 3` con las puertas abriéndose a la vista.** La relectura a los 0,9 s agarraba la
  hoja *en movimiento* y lo anotaba como fallo — **y el propio reporte lo dejó escrito al lado**:
  `peor 0,9 s contra un func_door_rotating EN MOVIMIENTO`. *Leer un estado transitorio como si fuera
  el final.* Ahora `abriendo` cuenta como abrió, y no es aflojar el criterio: **abriendo y cerrando
  son estados distintos** en los dos enums.
- **«Todavía no vio ninguna puerta cerrada»** con puertas cerradas delante todo el tiempo: el `return`
  temprano de la capacidad se llevaba puesto al instrumento junto con la función. *«No vio ninguna» y
  «vio y se abstuvo» son dos cosas distintas y el reporte las mostraba iguales* — así que con el veto
  puesto, todos los ceros habrían sido falsos negativos. Los contadores nacen antes de la puerta.
- **La ventana de silencio de 1,5 s se cerraba justo antes del ruido que quería tapar.** El autor
  precisó *«es el sonido de GOLPE de la puerta»*, y el golpe es el de **llegada**, no el de arranque
  — una hoja tarda más de 1,5 s en llegar al tope, cosa que el propio reporte ya había medido. Son
  3 s. Y como *«sigue sonando»* no dice **quién** suena, hay bitácora: mientras haya una ventana
  abierta se anota todo sonido cercano con su emisor, su archivo y si se bloqueó. **Coste cero
  cuando no hay ventanas abiertas**, que es la única forma honesta de dejar un log así puesto.

### El andamio que faltaba, y la conclusión del autor era la correcta

*«No puedo probar los flags; maybe lo mejor es tener una toolgun dev.»* Tenía razón sobre el
problema: el `lua_run` que le di escribe el campo en **la entidad**, y todo fantasma spawneado
después nace con el default de su clase — **el override se perdía al respawnear y nada lo decía**, lo
que se lee como «el flag no funciona». Ahora hay
`phantasmagoria_ghost_flag <abrir|atravesar|silencio|caminar> <0|1|auto>`, que alcanza a los vivos
**y a los futuros**, y `auto` lo saca sin haber pisado ningún campo.

> **La regla: un andamio de prueba tiene que sobrevivir al ciclo de vida de lo que prueba.** Si para
> volver a medir hay que re-aplicarlo a mano, la medición depende de que nadie se olvide.

### Y lo de la fila 09: cazando ahora corre

*«Suele caminar al hacer hunting y correr cuando no me ve. Podría correr igualmente directo a mí.»*
**La causa está medida en el código y es una línea** — `canDoRun` se niega si el bot *no está
enojado*, **te ve**, y tiene la **vida entera**; las tres se cumplen siempre en un hunt normal,
porque nadie le pega. (`shouldDoWalk`, la de al lado, devuelve `true` por los dos caminos: no es la
que decide.) Se resuelve con el callback de tarea `ShouldRun`, más el flag
`phantom_WalksWhenHunting`, que arranca en `false` y existe para los tipos que acechan caminando.

**Trampa anotada, de la misma familia que la del `Think` y peor:** `RunTask` corta en el primer
callback que devuelve algo **no nil**, y en Lua `false` no es nil — devolver `false` ahí no significa
«que decida otro», significa «NO corras» *y* le roba el evento a las tareas de movimiento de la base.

### Lo que las otras filas midieron sin proponérselo

`atraveso N · 0 por ATASCO` apareció en **cuatro** reportes de filas distintas (`8/0`, `1/0`, `4/0`,
`4/0`). La fila que la juzgaba quedó sin correr, pero cuatro lecturas incidentales apuntan a que esa
rama es código muerto. La fila 10 de la ronda 4 la cierra a propósito, en vez de darla por muerta.

Planilla: [`dev/checks/phantasmagoria-veto-r4.html`](../dev/checks/phantasmagoria-veto-r4.html),
**11 filas, ninguna corrida**.

---

## 2026-08-06 (8) — Ronda 2 CORRIDA (7 pasa / 2 falla): **atraviesa**, y las dos fallas eran un defecto mío

`dev/checks/phantasmagoria-atraviesa-r2.html`, 9 filas, ninguna sin correr.

**El atravesado anduvo a la primera y en las dos direcciones.** Del reporte del autor: *«lo acabo de
ver pasar a través de una puerta, y la abrió como yo quería»*; el `peor` bajó de **3,6 s a 0,7 s**; el
control negativo (`phasedoors 0`) volvió a trabarlo (`peor 3,3 s`); no se lo vio caer del mundo ni
cruzar nada que no fuera una puerta; y el `ghost_where` capturó el instante en vivo:
`puerta func_door_rotating   trabado 0.0 s   ATRAVESANDO`.

**Y la constante quedó medida por su efecto**, que era la fila que más valía: con la máscara del
wraith puesta a propósito, *«sí se queda pillado en la puerta del brush»*. La predicción asimétrica
entre las dos clases de puerta se cumplió, así que `CONTENTS_MOVEABLE` es el bit que decide y
`MASK_NPCWORLDSTATIC` es la máscara correcta — **por medición, no por citar la constante**.

### Las dos fallas tenían UNA causa, y es la peor clase de defecto: el instrumento

**La convar `phantasmagoria_ghost_doors` y el comando `phantasmagoria_ghost_doors` se llamaban
igual.** Cuando eso pasa la consola resuelve el nombre contra las convars primero y el comando queda
**mudo** — y `concommand.Add` no devuelve error ni avisa. Consecuencias, las dos medidas en la
corrida:

- **El instrumento de puertas fue inalcanzable toda la ronda.** El autor lo reportó como pregunta
  —*«¿dónde veo el dato de la evidencia?»*— y la respuesta era que no había forma. Las filas 05 y 08
  no fallaron por el mecanismo: fallaron porque **el comando que las verificaba no existía**.
- **Peor: la planilla mandaba correr `phantasmagoria_ghost_doors reset` antes de medir**, y eso le
  asignaba `"reset"` → `0` a la convar. O sea que la instrucción escrita para *limpiar el
  instrumento* **apagaba la función justo antes de medirla**. Por eso los `peor 10,7` y `12,3` del
  final no son atribuibles a nada.

**La regla, que vale para todo el taller de GMod:** *una ConVar y un ConCommand no pueden compartir
nombre, y el que pierde es el comando, en silencio.* El arreglo no es renombrar y seguir: todo
comando del addon pasa ahora por `PHANTASMAGORIA.AddCommand`, que **se niega y grita** si
`ConVarExists( name )`. Y el censo se hizo sobre **las siete convars y los seis comandos**, no sobre
tres: la colisión era exactamente una.

> Emparenta con *«una guarda defensiva que falla hacia un valor creíble es peor que no tenerla»*,
> pero es su versión de más arriba: **acá lo que falló hacia un valor creíble fue el canal por el que
> se mide**. Un comando que imprime la ficha de una convar se lee como *«no hay datos»*, no como
> *«este comando no existe»*.

### Los dos flags que pidió el autor

`ENT.phantom_OpensDoors` y `ENT.phantom_SilentDoors`, con la **misma convención** que
`phantom_PhasesDoors` (`0` nadie · `1` el flag del NPC · `2` todos) — tres perillas con tres
significados distintos para el mismo número serían tres formas de equivocarse en juego con la
planilla en la mano. Los tres resolvedores son **una sola función**, por el mismo motivo.

**El silencio son DOS sonidos y se tapan distinto**, y confundirlos sería callar la mitad y creer que
anda: el click del bot lo emite `Use2` (`shared.lua:1238`) detrás de un debounce propio de la base
—`nextUseSound`—, así que adelantar ese reloj lo apaga **sin overridear nada**; el chirrido de la
hoja lo emite el **engine**, y el único punto de intercepción es `EntityEmitSound`. Que ese hook
alcance a un sonido nacido en el engine es **lectura, no medición**: el check 04 de la ronda 3 se
juzga de oído, que acá es el instrumento correcto, y pide anotar **cuál** de los dos sonó.

**El default deja el ruido PRENDIDO**, y no por inercia: el autor dijo que oír las puertas fue lo que
le dejó *ver* el comportamiento del fantasma adentro de la casa. El ruido es un instrumento de
observación antes que un efecto, y el flag existe para el Myling (§5), que caza en silencio.

### Lo que NO se arregló, a propósito

*«Intenta casi siempre abrir puertas»* es una observación del autor y quedó **sin tocar**: el flag
prende y apaga la **capacidad**, no la **frecuencia**. En Phasmophobia abrir una puerta es un
*evento*. La fila 08 de la ronda 3 existe para convertir «casi siempre» en un número **antes** de
decidir si hace falta un intervalo o una probabilidad por tipo — y está escrita para que marcar PASA
signifique *haber medido*, no que el número sea bajo.

Se agregó además una segunda puerta de entrada al atravesado (estar **trabado** contra una puerta
aunque esté a más de 45 u), a partir de una lectura de la ronda 2 que **la sugiere y no la prueba**.
Va con contador propio (`fasesPorAtasco`) y una fila que la juzga: si queda en 0, es código muerto y
sale.

Planilla: [`dev/checks/phantasmagoria-flags-r3.html`](../dev/checks/phantasmagoria-flags-r3.html),
**9 filas, ninguna corrida**.

### Cambio menor: el modelo de pruebas pasa al cadáver de HL2

`models/player/corpse1.mdl`, pedido del autor. **Es el mismo que usa HIM sobre esta misma base**
(`him/…/terminator_nextbot_homeless/shared.lua:12`), que es la mejor evidencia disponible de que
sirve: no es un modelo parecido, es el mismo modelo corriendo en el mismo cerebro, en producción.

**Y la carpeta importa** — existen `models/humans/corpse1.mdl` (el cadáver NPC/prop de HL2) y
`models/player/corpse1.mdl` (el playermodel de GMod, con `m_anm`), y hace falta el segundo porque el
criterio de la base no es el esqueleto sino el `$includemodel`. No hubo que deducirlo: **HIM trae una
tabla de traducción que hace exactamente ese mapeo** (`sv_zhomeless_shelter.lua:52`), o sea que el
tercero ya tropezó y dejó escrito el arreglo. El quemado es `charple`, que la misma tabla mapea
aparte — `corpse1` es el otro.

De paso, **el skin pasó a viajar con el modelo** en vez de ser un campo suelto: el `1` se eligió por
lo que significa *en* `scaryblackman` (ojos blancos) y no quiere decir nada en un cadáver.
`shared.lua:2989` lo aplica *si es número*, sin preguntar si ese `.mdl` tiene tantos skins — así que
cambiar de modelo se lo habría llevado puesto en silencio. `scaryblackman` sigue en la lista, con su
skin, y vuelve a ser el primero cuando esta entidad deje de ser un instrumento.

---

## 2026-08-06 (7) — La velocidad quedó bien en juego; abrir no alcanzó, y ahora **atraviesa**

### Lo que la corrida dejó, **fuera de la planilla**

El autor probó por consola, no llenando `veldoors-r1`. Vale como medición porque son líneas del
instrumento, no impresiones — pero **no cierra el bloque**, y las filas siguen sin marcar:

| Qué | Lectura | Fila que le corresponde |
|---|---|---|
| Velocidad | `objetivo 280` · `deseada 66` caminando · `deseada 280` corriendo, y `real` acompañando | 02 y 04 quedarían verdes |
| Destrabado | *«las puertas las destraban»* | 10, **en prosa**: sin el contador de `destrabadas` no es la fila |
| Puertas | **`peor 3,6 s`** contra un **`func_door_rotating`** | **11 en ROJO**: el criterio pedía < 2 s |

**La fila 11 hizo exactamente lo que estaba escrita para hacer:** el cronómetro convirtió *«suele
quedarse pegado»* en 3,6 s, y el texto de al lado nombró la clase — y la clase es la que cambia el
diagnóstico.

### El defecto que destapó la clase: el peldaño 2 era pólvora mojada

`OpenAwayFrom` es una entrada de `CBasePropDoor`, o sea **sólo `prop_door_rotating`**. Sobre un
`func_door_rotating` el `Fire` no hace nada **y no avisa**: el peldaño 2 se consumía entero sin tocar
la puerta y el 3 recién llegaba 1,5 s después. La escalera tenía un escalón que no existía para la
mitad de las puertas del mapa, y sólo se vio porque el instrumento imprime la **clase**. Corregido:
el peldaño 2 se saltea si no es un `prop_door_rotating`.

### Atravesar — un flag por NPC, no una convar

Pedido del autor: que atraviese, y **por NPC**, porque el Alternate (`docs/ALTERNATE.md`) no puede.
Así que es `ENT.phantom_PhasesDoors` (heredable por el árbol de bases: los 30 tipos lo reciben en
`true` sin escribir nada) con `phantasmagoria_ghost_phasedoors` de tres estados para pisarlo en las
dos direcciones — `0` nadie, `1` según el flag, `2` todos.

**El mecanismo no se inventó: hay dos precedentes en el árbol y los dos usan `SetSolidMask`** — el
módulo wraith de la base (`wraithcloaking.lua:133`) y HIM (`server.lua:630`). Lo que decidió cuál
copiar es que **usan máscaras distintas**:

| Máscara | Quién | Pasa props | Pasa brush entities (`func_door_*`) |
|---|---|:---:|:---:|
| `MASK_NPCSOLID_BRUSHONLY` | wraith de la base | sí | **no** |
| `MASK_NPCWORLDSTATIC` | HIM | sí | **sí** |

Difieren en `CONTENTS_MOVEABLE`, que es el bit de los brush entities — o sea de la puerta que
**efectivamente** lo trabó. Va la de HIM. **Y eso es lectura de una constante del engine**, que es
justo la clase de cosa que este proyecto ya pagó dos veces: por eso hay convar para el A/B, el
instrumento imprime el `bit.band` contra `CONTENTS_MOVEABLE` (check 01) **y** hay un check que la
mide por su efecto con la máscara equivocada puesta a propósito (check 04) — la predicción es
asimétrica entre las dos clases de puerta, que es lo que la vuelve discriminante.

**Atravesar y abrir quedan independientes y los dos prendidos**, que es lo que piden los dos mensajes
del autor: atravesar garantiza que **pase**, abrir es lo que deja la **huella**. El check 08 vigila
justo el riesgo de que ahora que nunca se traba, la escalera de apertura no llegue a dispararse.

### El riesgo del mecanismo, y las tres defensas

`MASK_NPCWORLDSTATIC` ignora **todos** los brush entities mientras dura, no sólo las puertas: en un
mapa cuyo piso sea un `func_brush`, el fantasma se cae del mundo. Mitigaciones: se vuelve no-sólido
sólo a **45 u** de una puerta (no a los 200 del sondeo), y se sale por una puerta de emergencia con
**tres** condiciones — que no haya una hoja encima, medio segundo de gracia, y un techo duro de 5 s
con enfriamiento. La gracia existe por algo que **no se pudo medir sin el juego**: qué devuelve un
`TraceHull` que arranca dentro de un sólido. *La defensa que no depende de esa respuesta está ahí
justamente porque la otra sí.*

Planilla: [`dev/checks/phantasmagoria-atraviesa-r2.html`](../dev/checks/phantasmagoria-atraviesa-r2.html),
**9 filas, ninguna corrida**.

---

## 2026-08-06 (6) — ESCRITO, sin correr: la velocidad se deriva del jugador y el fantasma abre las puertas

**Nada de esto se corrió en GMod.** La planilla es
[`dev/checks/phantasmagoria-veldoors-r1.html`](../dev/checks/phantasmagoria-veldoors-r1.html), 14
filas, criterios escritos **antes**.

### La velocidad — un callback declarado, no un override

El fantasma corría a **550 u/s** (la `RunSpeed` de la base, que no pisaba) contra los **280** de
Better Movement: **1,96×**, y al revés de lo que manda §1.1. Ahora sale de `sv_bm_speed_run` —
**no** de `ply:GetRunSpeed()`, que Better Movement multiplica por un factor dinámico clampeado 1..2
y devuelve entre 280 y 560 según el instante.

Se engancha en `ModifyMovementSpeed` (`motionoverrides.lua:3803`), que **es un callback de tarea y no
un método**: `RunTask` sólo llama a las tareas activas, así que un `ENT:ModifyMovementSpeed` no lo
llamaría nadie. Vive en `ENT.MyClassTask`, el punto de extensión que la base declara para esto
(`taskoverride.lua:328`). Efecto lateral útil: la tarea aparece **por nombre**
(`terminator_nextbot_phantom_handler`) en la lista de `phantasmagoria_ghost_where`, o sea que «se
enganchó» es una línea de la salida y no una suposición.

**Devuelve un factor y no un absoluto**, para no borrar la elección de marcha de la base (walk 130 /
move 300 / run 550 siguen existiendo, escalados). Y el divisor se **congela al spawnear**: leído en
vivo, `overcharging.lua:22` (`RunSpeed = max( RunSpeed * 1.40, 550 )`) se cancelaría solo y el
fantasma volvería a su velocidad normal justo cuando el mecanismo dice que tiene que acelerar.

### Las puertas — la tercera opción, que es mejor que las dos que estaban escritas

ESTADO.md dejaba abierto «atravesar o arreglar el bashing». El autor eligió **abrir**: atravesar es
gratis de programar y **regala la huella**, que es una de las 7 evidencias y el motivo que él nombró.

Lo que la base hace y por qué no alcanza, leído: `tryToOpen` (`shared.lua:1249`) sí abre puertas,
pero tiene **un solo call site** — `ShootblockerThink` (`:1109`), que traza a lo largo del **aim
vector**. Este fantasma es justamente el que no apunta a donde camina. Y las dos ramas que lo sacan
de una puerta trabada piden `isFists` (`:1336`, `:1340`): **muertas** sin puños.

Lo escrito: un sondeo propio con `TraceHull` a lo largo del **path** (con la marcha y el cuerpo como
respaldo, y la fuente usada impresa), alcance proporcional a la velocidad — media hoja de puerta
tarda ~1 s en abrirse y a 280 u/s eso son 280 u, así que un alcance fijo corto la abre cuando ya la
chocó. Después una escalera de tres peldaños **contados por separado**: `Use2` (el camino de la
base) → `OpenAwayFrom` → `Fire Open`, más el destrabado, que va primero porque un `Use` sobre una
puerta con llave no hace nada. Si el peldaño 1 alcanza siempre, los otros dos son código muerto y la
corrida lo va a decir.

**El síntoma sigue sin medir, y por eso hay cronómetro.** *«Suele quedarse pegado abriéndolas»* es una
frase del autor. `phantom_doorBlocked` corre **aunque la convar esté apagada** y anota contra qué se
trabó: una puerta **cerrada** es lo que este bloque arregla; una **abierta encima suyo** no, y ahí el
arreglo no sería el arreglo. Los checks 11 y 12 son esa medición y su control.

**La huella se guarda como dato** con la forma de §8.5 (`pos`, `normal`, `hand`, `expire`) más la
puerta y el punto **relativo a ella**: una `prop_door_rotating` gira, y una huella guardada como
punto de mundo queda flotando en el aire apenas la puerta se mueve. No se dibuja nada — eso es el
bloque de la UV — y queda `hook.Run( "PhantasmagoriaGhostUsedDoor", ghost, door )` para engancharlo.

### Límite declarado antes de correr

Una `prop_door_rotating` **con llave** marca como bloqueado el navarea de abajo (lo dice la base en
`shared.lua:657`), así que el camino puede evitarla y el fantasma no llegar nunca a tocarla — y el
destrabado, que es por contacto, no se dispara. El check 10 está escrito para distinguir ese caso
(«nunca la tuvo delante») de uno nuestro («la tuvo delante y no destrabó»).

### Instrumentos nuevos

`phantasmagoria_ghost_speed` (la cadena entera: convar → base → multiplicador → factor → las tres
marchas → lo que el locomotion tiene puesto) y `phantasmagoria_ghost_doors` (+ `reset`, para que el
A/B no arrastre contadores). Los dos números que más dicen —velocidad y segundos trabado— van también
en una línea de `phantasmagoria_ghost_where`, que es el comando que se tipea todo el tiempo.

---

## 2026-08-06 (5) — CERRADO en juego: el fantasma mira hacia donde camina, y una columna se invalidó al arreglarlo

Criterio escrito **antes** de correr, cumplido en las dos mitades:

| Medición | Antes | Ahora | Criterio |
|---|---:|---:|---|
| `mirada vs marcha` | media **74,4°**, máx **179,9°** | media **1,9°**, máx **6,2°** | < 20° ✅ |
| `mirada vs jugador` | media 111,1° | media **130,5°**, rango 2,2–168,8 | seguir grande ✅ |

**La mitad que podía salir mal no salió mal.** Si el arreglo hubiera dejado al fantasma siguiéndote
con la vista fuera del hunt, `mirada vs jugador` sería ~0 en las seis lecturas; es < 20° en **una**, y
esa se explica con la tabla al lado (`marcha yaw 88,6` contra `al ply yaw 93,5`: iba caminando derecho
hacia el jugador). **Geometría, no seguimiento** — y el instrumento lo exhibe sin argumentar.

### La confirmación salió de la columna que yo había degradado a control

El `delta` entre `mira` y `quiere` valía **0 en 15 de 15** lecturas antes del arreglo, y ahora vale
2,7 · 6,2 · 0,6 · 0,1. La columna que no medía nada **se movió justo cuando el arreglo entró**, lo que
ata el cambio a nuestro código.

### Y eso mismo la invalidó: `delta` == `mirada vs marcha` por construcción

Son el mismo número en las cuatro lecturas, y no es coincidencia: **desde el arreglo, en calma el que
escribe `DesiredEyeAngles` somos nosotros, con la dirección de marcha.** *Un instrumento que reporta
el valor que vos mismo escribiste no es una medición independiente.* Sigue valiendo en hunt (ahí lo
escribe la base) y con `phantasmagoria_ghost_facewalk 0`.

Corregida la etiqueta, que además decía `( control: 0 es lo esperado )` y con el arreglo puesto pasó a
ser **falsa** —un delta distinto de 0 se habría leído como falla—. Ahora dice **quién** lo pide.

### Dos observaciones que quedan sin explicación a propósito

Las dos fuentes de velocidad coinciden exactamente a régimen (`130/130`, `550/550`) y se separan
acelerando (`421/402`). Y el cambio tomó **sin recargar el mapa**. Las dos anotadas como hechos, no
como reglas.

---

## 2026-08-06 (4) — El fantasma ya mira hacia donde camina, y mi diagnóstico anterior culpaba al candado equivocado

Con el instrumento arreglado, la corrida 7 dio los números que faltaban:

| Medición | Calma (10 lecturas) | Hunt (6 lecturas) |
|---|---:|---:|
| `mirada vs jugador` | media **111,1°** (13,7–177,3) | media **2,8°** (0,0–14,6) |
| `mirada vs marcha` | media **74,4°**, máx **179,9°** | 0,8–34,6° |

**179,9° es caminar exactamente de espaldas.** Y del lado bueno: en hunt te apunta con 0,0–1,5° en
cuatro de seis lecturas, así que la columna `al ply` —agregada justamente para eso— discrimina.

### La corrección: culpé a los puños y era la mitad equivocada

Había escrito que la causa era el gate `if not myTbl.TERM_FISTS then return end`
(`motionoverrides.lua:2838`). Es real, **pero ese camino tiene DOS candados**: la línea siguiente
exige además `currentSpeed < term_DefaultSpeedToAimAtProps`, que vale **`30^2`**
(`motionoverrides.lua:1735`) contra `Length2DSqr` → un umbral de **30 u/s**. Este bot camina a 130 y
corre a 550, así que **devolverle los puños no lo habría arreglado**: una ronda entera gastada en el
arreglo obvio.

La causa real es más simple: **el único call site de `SetDesiredEyeAngles` que puede correr
*caminando* es el del enemigo** (`enemyoverrides.lua:1874`). Un terminator normal siempre tiene
enemigo; nuestro fantasma en calma no tiene ninguno **a propósito**.

**Y contesta la pregunta del autor —*«¿será que HIM funciona así? porque el terminator parece moverse
bien»*—: no es HIM ni es la base.** HIM también pone `TERM_FISTS = false`
(`him/…/terminator_nextbot_homeless/server.lua:22`), igual que `terminator_nextbot_fakeply:35` y
`csoldier:26`. Lo que ellos tienen y nosotros no es un enemigo permanente.

*Un camino cerrado por dos condiciones se diagnostica leyendo las dos. Con una sola, el arreglo
apunta al candado que no era.*

### El arreglo

`ENT:BehaveUpdate` encadena al `BaseClass` y **después** rellena el hueco: sin hunt, sin enemigo, en
el piso y a más de 30 u/s, apunta el facing a la dirección de marcha con el pitch aplanado — lo mismo
que hace la base al saltar (`motionoverrides.lua:3311`), aplicado al caso que no cubre.
`phantasmagoria_ghost_facewalk` (default 1) lo apaga para el A/B, así que auditarlo es un comando y
no una reversión.

**Sin correr.** El criterio está escrito antes: `mirada vs marcha` tiene que bajar de ~75° de media a
menos de 20°, **y `mirada vs jugador` tiene que seguir siendo grande y aleatorio** — si también se va
a cero, el fantasma quedó siguiéndote con la vista fuera del hunt, que es peor que el defecto
original.

---

## 2026-08-06 (3) — El instrumento de mirada falló tres veces, y destapó el primer defecto del FANTASMA

La planilla se vació y se volvió a correr con el instrumento de mirada puesto. Mismo veredicto —**7
pasa, 1 falla**— y **cuatro defectos nuevos: los tres primeros míos, el cuarto del bot**.

### ① Una guarda defensiva que fallaba hacia un valor creíble — la pescó el autor

`marcha` decía `quieto ( 0 u/s )` **siempre**, con el bot cruzando 1.400 u entre lecturas. La causa:
`IsValid( ghost.loco )`. **`CLuaLocomotion` no tiene método `IsValid`**, y el `IsValid()` de GMod
devuelve `false` para todo objeto que no lo tenga, así que la guarda caía siempre al vector cero.
**La base nunca envuelve `self.loco` en `IsValid`: lo llama directo**
(`terminator_nextbot_base/motion.lua:54`; grep sobre sus 71 archivos: cero).

*Una guarda defensiva que falla hacia un valor creíble es peor que no tenerla.* No tiró error ni
`nil`: tiró **«quieto»**, que es una lectura posible. Se detectó sólo porque el autor sabía que el
bot caminaba. Corregido sin guarda y **con las dos fuentes impresas** (`GetCurrentSpeed()` y
`Entity:GetVelocity()`), para que si alguna vuelve a dar cero se vea **cuál**.

### ② Ángulos sin normalizar: el mismo ángulo leído como dos opuestos

`mira yaw -449.7` al lado de `quiere yaw 270.4`, **con `delta 0` en la misma línea**. Las nueve
parejas del reporte son el mismo ángulo (−449,7 → −89,7; −451,9 → −91,9; −313,6 → 46,4). El delta
estaba bien; mentían los números de al lado. Todo pasa ahora por `math.NormalizeAngle`.

### ③ Vendí como discriminante una pareja que no podía discriminar ni en principio

**15 de 15 lecturas dieron `delta 0`** entre `mira` y `quiere`. No es calibración: `GetEyeAngles`
(`terminator_nextbot_base/shared.lua:81-93`) arma el ángulo con `self:GetAngles()` y **sólo pisa el
pitch** — el yaw de «dónde mira» **es** el del cuerpo, y no hay un yaw de cabeza aparte. Se conserva
como **control** (que el delta sea 0 es el dato) y el discriminante pasa a ser una línea nueva,
**`al ply`**: el rumbo al jugador más cercano y el ángulo contra la mirada, que es lo que separa
*girar siguiéndote* de *girar solo*.

### ④ Y el que no es del instrumento: **el fantasma no gira nunca en calma**

Cuatro lecturas cruzando el mapa (X de −598 a +3.520) con **`mira yaw 3.2` en las cuatro**; después
del hunt quedó clavado en 46,4. **No vuelve a un default: se congela en el último valor.** Censados
los cuatro call sites de `SetDesiredEyeAngles` —enemigo (`enemyoverrides.lua:1874`), caída y salto
(`motionoverrides.lua:3306` y `:3311`), y `justLookAt` vía el «mirar hacia el goal» que sale antes con
`if not myTbl.TERM_FISTS then return end` (`:2838`)—: **en calma no queda ni uno vivo.** Medición y
lectura coinciden, y es **el primer defecto del arco que no es del instrumento**.

Sin arreglar a propósito: un fantasma que se desliza sin girar puede leerse como bug o como rasgo, y
la línea que lo corrige cambia cómo se ve el bot. Es decisión del autor y necesita su propio check.

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
