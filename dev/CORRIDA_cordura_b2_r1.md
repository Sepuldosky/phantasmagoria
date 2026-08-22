# CORRIDA — la cordura, tajada B2 · r1 (2026-08-21)

Planilla: `dev/checks/phantasmagoria-cordura-b2.html` (11 filas, fuera de git).
Módulo: `lua/entities/terminator_nextbot_phantom/server_events.lua` (§19.8.4) +
`lua/autorun/phantasmagoria_sanity.lua` + `lua/phantasmagoria/luces.lua`.
Anterior: [`CORRIDA_cordura_b1_r3.md`](CORRIDA_cordura_b1_r3.md) ·
Handoff: [`HANDOFF_cordura_b2_y_c.md`](HANDOFF_cordura_b2_y_c.md).

| | |
|---|---|
| **Marcado por el autor** | 10 pasa · 1 falla · 0 sin correr |
| **Después de revisar los números** | **8 pasa · 2 falla · 1 verde que vale menos de lo que dice** |

La 06 la marcó el autor en verde **a propósito**, para que se la mirara: *«verifica tú, puse pasa
para que lo vieras más atento»*. Se la miró, y no pasa.

> ⭐⭐⭐ **EL TITULAR: ni el tope ni el piso se midieron en toda la corrida.** Las dos filas que los
> tocan fallaron **en direcciones opuestas** — la 04 llegó a la rama del **piso** buscando la del
> **tope**, y la 06 buscó la del **piso** y se quedó a cuatro puntos de llegar. `tope no mordio
> nunca` es la última línea de la sesión entera. El `math.max( tope, mayor )` sigue sin una sola
> medición en juego, y **las dos filas que existían para medirlo salieron verde y roja sin tocarlo**.

---

## 1. La 04 (ROJA): pidió la rama del **tope** y aterrizó en la del **piso**

La fila puso `phantasmagoria_ghost_santope 1`, disparó un `sound` a 26 u del fantasma, y pidió
ver `-1.00 %`. Salió **`-3.00 %`** — el costo base entero, sin recorte. La nota del autor
(*«parece que entró 3 en vez de 1 con el tope»*) describe el síntoma exacto.

**El motor hizo lo que dice su código**, y se demuestra con tres renglones de
`cobrarCordura` ([server_events.lua:5562-5574](lua/entities/terminator_nextbot_phantom/server_events.lua#L5562-L5574)):

```lua
local techo = math.max( tope, mayor )
if total > techo and techo > 0 then ...recorta... end
```

`mayor` es el **mayor costo individual del disparo**, y se calcula sobre exactamente el mismo
conjunto de cobros que suma `total`: los que pasaron el `f > 0` y el `base > 0`. De ahí sale un
teorema de una línea:

> **Con un solo cobro cargado, `mayor == total`.** Entonces `techo = max( tope, total ) ≥ total`,
> y la condición `total > techo` **es falsa siempre**.

O sea: **el tope no puede morder nunca en un disparo de un solo cobro, con ningún valor de
`santope`.** No es que el 1 no se leyó — es que la comparación no tiene forma de dar verdadero.
Con `N ≥ 2` cobros sí muerde, porque ahí `mayor < total`.

Y esto **no es un defecto del motor**: es literalmente lo que el comentario de arriba de esa línea
declara —*«un tope pensado contra la suma no puede decidir el costo de un solo sumando»*—, y es lo
que la **fila 06** existe para verificar. El tope es, por construcción, un tope de **apilamiento**.

### ⭐ El defecto real que la 04 sí encontró: **la línea del `piso` miente sobre la causa**

Con `tope = 1` y `mayor = 3`, la condición `mayor > tope` es verdadera, así que el reporte
**imprimió** ([server_events.lua:6843-6848](lua/entities/terminator_nextbot_phantom/server_events.lua#L6843-L6848)):

```
piso        1 vez/veces un costo INDIVIDUAL supero el tope y lo levanto
            ( hoy solo puede ser el 15 % de puerta del Yurei ). ...
```

**El paréntesis es falso.** Acababa de pasar con un `gallu`, un `sound` y ningún `per`: pasa cada
vez que `santope` se baja por debajo del costo base de una categoría — que es exactamente lo que la
fila 04 le manda hacer al operador. La línea nombra una causa que no es la causa, y manda a mirar
`ghost_flags.lua`, donde no está el problema.

*(Predicción del código: la truncación del pegado cortó justo antes del `ghost_events` de esa fila.)*

---

## 2. La 06 (ROJA): el `per.door = 15` **sí se leyó** — y el piso nunca se tocó

```
evento door             -2.02 %   1 veces
cobros      1 drenaje(s) aplicado(s)  ·  2.02 % pedido
tope        no mordio nunca
```

**Lo que la fila probó, y lo probó mejor que un verde.** Con el costo base de la categoría
(`door = 1.5`) el factor de caída tendría que valer **1,347**, y el máximo del factor es 1. O sea
que **es aritméticamente imposible que ese 2,02 haya salido del costo base**: el `per` del tipo
se leyó y `base = 15`. *Un número que sólo puede venir de un camino acredita ese camino más fuerte
que una línea que diga que lo tomó.*

**Lo que la fila NO probó, que es lo que vino a probar.** Despejando: `f = 2,02 / 15 = 0,135`, o sea
el jugador a **≈ 408 u del epicentro** — a nueve décimos del borde de 450. Y con eso:

| | |
|---|---|
| criterio (a) `evento door` = **−15,00 %** | ✗ salió −2,02 % |
| criterio (b) el motor dice `piso 1 vez/veces` | ✗ **no salió ninguna línea `piso`** |
| criterio (c) el mismo escenario sin el rasgo da −1,50 % | ✗ no se corrió |

El (b) no salió porque `mayor = 2,02` (se mide **después** de la caída, y eso es deliberado: *«un
Yurei a 400 u no tiene derecho al piso de 15, tiene derecho al piso de lo que su caída dejó»*), y
`2,02 > 6` es falso. **La fila del piso midió un disparo en el que el piso no podía activarse.**

> **La respuesta a la pregunta del autor** (*¿tanto gasta un yurei al abrir puertas?*): en el
> epicentro, sí — 15 % es literal de la fuente (:631) y es lo que hace que el tipo se juegue entero
> en un eje. Pero **no mediste el 15**: mediste el 2,02 de estar a 408 u. Si el 15 al lado de la
> puerta te parece mucho, ésa es una discusión de **diseño** y no de código, y hay que tenerla con
> el número medido en la mano — que todavía no existe.

---

## 3. ⭐⭐⭐ El hilo que atraviesa cuatro filas: los criterios se juzgan por la **dirección**, no por el número

Los criterios de la planilla citan porcentajes exactos, y todos suponen `f = 1`, o sea al operador
**adentro de la meseta**. Sólo uno salió así:

| fila | criterio | salió | `f` implícito | distancia al epicentro |
|---|---:|---:|---:|---:|
| 01 `sound` | −3,00 % | −2,36 % | 0,787 | ≈ **202 u** |
| 02 `throw` | ≈ −2,00 %/objeto | −1,18 % | 0,590 | ≈ **264 u** |
| 04 `sound` | −1,00 % | −3,00 % | 1,000 | ≤ 135 u ✔ |
| 06 `door` | −15,00 % | −2,02 % | 0,135 | ≈ **408 u** |
| **05 `sound` (Oni)** | **−6,00 / −3,00** | **−6,00 / −3,00** | **1,000** | **≤ 135 u ✔** |

Despejando la caída de §19.8.4 (`radio 450`, `meseta 135`, lineal): `d = 135 + (1 − f) × 315`.
Las cinco cierran, así que **la caída anda** — pero convierte a la 01, la 02 y la 06 en filas que
midieron *«drenó algo»* y no *«drenó lo que dice el diseño»*.

### Y el instrumento **no puede verificar su propio criterio**

Para juzgar `-15.00 %` hay que saber la distancia **jugador ↔ epicentro** en el instante del evento.
El reporte no la imprime. Lo único parecido es la distancia **jugador ↔ fantasma** del motivo de
`presencia`, y son dos números distintos por dos razones, las dos decisivas:

1. **Es otra distancia.** Separar el epicentro del fantasma es *literalmente lo que B2 vino a
   hacer* — el hueco del autor: *«un evento puede pasar a 450 u del fantasma con el jugador a diez
   metros del golpe»*. En la 06 se ve en crudo: la puerta a **325 u del fantasma**, el fantasma a
   **283 u del jugador**, y el cobro decidido por los **408 u** que no aparecen en ninguna parte.
2. **Es de otro instante.** El cobro es histórico; el motivo de `presencia` es la **última muestra
   viva**. Nada en el reporte ata los dos números.

*Un criterio expresado en un número que el instrumento no imprime se juzga a ojo, y a ojo pasa por
la dirección.* Y el costo es exacto: **cuatro de las once filas** quedaron sin poder decidirse.

**Éste es el arreglo con mejor relación en toda la ronda** (§6-A).

---

## 4. Lo que sí cerró, y con qué

### ⭐⭐⭐ 05 — la única fila que aterrizó en su número exacto, y prueba tres cosas de un saque

`-6.00 %` con `phantasmagoria_sanity_eventos 1` y `-3.00 %` con la perilla en `2`, **mismo fantasma,
mismo evento, mismo lugar**. Con `f = 1` exacto, ese par de números fija de una vez: el costo base de
`sound` (3,0), el `sanity.mult = 2.0` del Oni, y que el modo 2 del A/B **ignora los rasgos y nada
más**. Es la medición más limpia de la ronda.

### P0 y 10 — las 30 perillas en fábrica, en las dos puntas

```
[Phantasmagoria] las 30 perillas de la cordura estan EN FABRICA. Nada que restituir.
```

⭐ **Esto contesta la pregunta abierta**: la 04 bajó `santope` a 1, y la línea de restitución **sí
corrió**. La 05 y la 06 midieron con el tope en 6. (Igual conviene saber que **habrían pasado con el
tope en 1**: con un solo cobro el tope es inerte, así que un `santope` viejo atraviesa esas dos filas
sin dejar rastro, igual que el `regendelay 30` de B1 r3. El `--decir` es lo único que lo delata.)

### ⭐⭐ 02 — la esfera cuelga del **sujeto**, con las dos mitades en un solo disparo

`pasadas 2 · cobros 1 · 1 quedaron fuera de toda esfera`: dos `throw` del **mismo fantasma en el
mismo lugar**, uno cobró y el otro no. Si el radio colgara del fantasma, los dos habrían cobrado
igual. Es la evidencia de que B2 hizo lo que vino a hacer, y no es inferencia: es un contador
separando dos props a 318 u y 389 u.

### ⭐⭐ 08 — tres estados de la luz, los tres impresos, y el modulador acreditando de vuelta

| | `luz` | `oscuridad ( mod )` | `oscuridad CIEGA` |
|---|---|---:|---:|
| (a) `ciegamul 1.5` | `SIN LECTURA ⚠ no se pudo medir  x1.50` | +0,00 | **−1,09** |
| (b) `ciegamul 1.0` | `SIN LECTURA ⚠ no se pudo medir  x1.00` | +0,00 | **+0,00** |
| (c) linterna ON | `ILUMINADO ( medido )  x0.50` | **+0,70** | +0,00 |

Los tres estados donde había dos, y el `−1,09` de (a) es exactamente la mitad del `−2,18` de
`presencia calma`, que es lo que tiene que dar un `x1,50`. En (c) el modulador **devuelve** cordura
(`+0,70` sobre `−1,41`) y el neto queda en `−0,70`. La perilla nueva apaga la lectura-que-no-se-pudo-hacer
**sin tocar la buena**, que era el punto de la fila.

> El criterio (d) —la línea `⚠ punto ciego`— **no podía salir en este mapa y en ese lugar**: la 10
> lo explica sola (`en TODO el mapa hay 2 de esas clases y la mas cercana esta a 1182 u`, contra un
> radio de ambiente de 300 u). O sea que el `SIN LECTURA` de (a) y (b) **es honesto**: no hay nada
> que preguntar. Queda un criterio sin ejercer, no un criterio incumplido.

### 07 — la fuente sin sujeto lo dice, y con el nombre de lo que falta

```
presencia_tipo inactiva  ⚠ SIN SUJETO: 1 con el rasgo y mirado(s), pero
  `PHANTASMAGORIA.EstaManifestado` NO EXISTE -- las manifestaciones de §22 no estan escritas.
  El rasgo esta en los datos y no tiene de que colgarse
```

(a) y (b) exactos. De (c) se vio una mitad —`ningun fantasma a 525 u`, en la 03— y falta la otra:
el motivo dice `mirado(s)`, así que **el estado «NO lo está mirando» sigue sin ejercerse**. Un
tercer estado del cero sin medir.

### 03 y 01 — el borde y el primer cobro

La 03: `pasadas 1 · 1 evaluado(s) · 1 quedaron fuera de toda esfera · cobros 0`. El `1 evaluado(s)`
es lo que separa *«la pasada corrió, te miró y estabas lejos»* de *«la pasada no corrió»*.
La 01: `1 veces`, sin `en X s / N ticks`, ningún `⚠ NO DECLARADA`, y `sin donde 0` — tres de sus
cuatro mitades (la del monto, §3).

### 09 — nada se rompió, y la lista de luces mudada de archivo contesta por el mapa entero

El evento `light` salió `sin sujeto` **enumerando las siete clases y contando el mapa completo**, la
puerta se abrió con confirmación diferida (`estado 1 -> 2` a los 0,25 s), el `knock` sonó con su
banco de material, y el scheduler despertó **solo una vez** (`despertadas ESPONTANEAS: 1`) — o sea
que el motor corre sin que nadie lo empuje. `LIGHT_CLASSES` desde `luces.lua` funciona en sus dos
consumidores. La mitad de `hunt` + `PlayerSpawn` (armas y playermodel al respawnear) **no quedó
registrada** en la nota.

---

## 5. ⚠⚠ La 10 pasó sus cuatro criterios, y aun así **vale mucho menos de lo que dice**

Su encabezado promete *«el desglose cierra contra la barra **en toda la sesión**»*, y su precondición
dice **SE CORRE ÚLTIMA Y SIN RESETEAR**. Pero la **08 tiene dos `phantasmagoria_cordura_reset`
adentro de su propio botón**, y la 08 corre antes. Resultado: la lectura de la 10 es **idéntica** a
la de 08(c) —los mismos 47 ticks, los mismos 14,1 s, el mismo `neto −0.70 %`—, o sea que el control
del control auditó **una ventana de catorce segundos con dos causas continuas y cero eventos**.

Cierra, y cierra bien (`−1,41 + 0,70 = −0,71` contra una barra en `99,30`, brecha 0,01 de redondeo).
Pero comparado con el mismo control de B1 r3 —**seis causas, dieciséis aplicaciones planas, brecha
0,00**— es una sombra. Y mientras tanto, los contadores del motor, que **no** los borra ese reset,
seguían diciendo `cobros 2 · 3.52 % pedido` en la misma pantalla: **dos alcances distintos, dos
comandos de reset distintos, y un renglón que invita a leerlos como si fueran el mismo**.

*Una precondición que otra fila de la misma planilla destruye no es una precondición: es un deseo.*
Es el mismo defecto de clase que el par 04/06 — **la planilla no cruza sus propias filas**, ni por
lo que afirman ni por lo que se pisan.

De la 10 sí vale entero lo que **no** depende de la ventana: `sin donde 0` sobre las categorías que
llegaron a salir en toda la sesión (los contadores del motor no se resetearon), ningún
`NO DECLARADA`, ningún `⚠⚠ EL DESGLOSE NO CIERRA`, y las 30 perillas en fábrica.

---

## 6. Los arreglos — **APLICADOS el 2026-08-21**

### (A) ⭐⭐⭐ La foto del último disparo — el que arreglaba cuatro filas de una

`cobrarCordura` calculaba `d` y `f` por cobro y los tiraba. Ahora los guarda y el bloque
`CORDURA de los eventos` los imprime:

```
ultimo disparo  ( hace 0.3 s )  -- la distancia es JUGADOR -> EPICENTRO, que es la que decide el cobro
  SEPULDOSKY
    door       base  15.00 % ( `per` del tipo          )  x f 0.135 (  408 u de 450, meseta 135 )  =   2.02 %
    --  total 2.02 %  ·  mayor 2.02 %  ·  tope 6.00 %  ->  techo 6.00 % ( lo puso el TOPE )
    --  sin recorte ( el total no llego al techo )
```

Tres cosas que antes no se podían leer, y cada una mataba una fila:

1. **De cuál de los tres salió el `base`** (`pct` propio · `per` del tipo · base de la categoría).
   Es la pregunta que la 06 tuvo que contestar despejando una ecuación a mano dos días después.
2. **La distancia y el factor**, que es lo único que separa *«el rasgo no llegó»* de *«estabas
   lejos»* — dos causas que se ven igual (un porcentaje chico) y mandan a arreglar cosas distintas.
3. ⭐ **Quién puso el techo**, con las dos ramas dichas por su nombre: `( lo puso el TOPE )` contra
   `( lo puso el PISO: el cobro individual mas caro ( 15.00 % ) supera al tope )`. La r1 gastó dos
   filas sin tocar ninguna de las dos, y desde afuera los dos casos se leían igual.

La distancia **se guarda también cuando no cobra** (antes del `f <= 0`), así que la fila del borde
imprime `SIN COBRO: el epicentro mas cercano quedo a 3900 u, y el radio es 450 u` en vez de nada.
Acotado a 8 filas y 4 jugadores por foto, con su `( y N mas, no listados )`.

### (B) ⭐⭐ El techo salió de `cobrarCordura` — y ahora tiene mitad offline

La aritmética vivía adentro de la pasada, y `cordura_b2_offline.py` **declaraba** que no podía
correrla (`player.GetAll`, convars, la puerta). Por eso el tope quedaba cubierto **sólo** por la
planilla en juego, y por eso el defecto sobrevivió a dos filas.

Ahora es `decidirTecho( total, mayor, tope )`, se extrae por nombre y se corre en un intérprete de
Lua como las otras dos. Diez casos —el Yurei entero y a 408 u, el Oni apilando, el Poltergeist de la
04 nueva, `tope 0`, `total 0`— y **dos invariantes barridas**, entre ellas la que costó la fila:

> con `total == mayor` (o sea, un solo cobro) la escala es 1 para **360 combinaciones** de valor y
> tope. El recorte es imposible, y ahora eso es un control y no una sorpresa.

**Y discrimina**: cambiándole el `math.max( tope, mayor )` por un `tope` duro, el script grita en
siete líneas y nombra el Yurei. O sea que si algún día se toma la decisión (G), el instrumento
**obliga a tomarla a propósito** en vez de dejarla pasar.

### (C) La 04, reescrita — Poltergeist, `burst 4`, `santope 3`

```
phantasmagoria_ghost_type poltergeist      ( burst 4 -> cuatro cobros de `throw` )
phantasmagoria_ghost_santope 3
phantasmagoria_cordura_reset
phantasmagoria_ghost_events reset
phantasmagoria_ghost_event throw           ( parado ENTRE los props )
phantasmagoria_cordura
phantasmagoria_ghost_events
phantasmagoria_ghost_santope 6
phantasmagoria_ghost_type
```

PASA con las cuatro: `pedido` > 3,00 · `⚠ tope mordio` · `evento throw` = **3,00 exacto** · y
⚠ **la línea `piso` NO aparece**, con la foto diciendo `techo 3.00 % ( lo puso el TOPE )`. *Ese
renglón es la fila entera.* Si `pedido` sale corto hay que **acercarse**, no bajar el tope: por
debajo de 2,0 vuelve a caer en el piso.

### (D) La 06, reescrita — con la precondición **verificable en el reporte**

Su `pre` ya pedía *«y vos a menos de 135 u de esa puerta»*: la precondición estaba bien escrita y
**no había forma de comprobarla**. Ahora sí, y el criterio arranca por ahí:

> Si el `f` de la foto no es **1,000**, la fila es **SIN CORRER**. Acércate y repite.

Y el `fail` gana la rama que se comía la fila: *la foto dice `base 15.00 %` pero el cobro salió
chico* → **no es un rojo, es un SIN CORRER**. Se le agregó `pedido 15.00 %` como criterio (b) —el
potencial sin recortar— y se le fijó el `santope 6` explícito en el botón, para que no dependa de
que la 04 haya hecho su desmontaje.

### (E) La 10 — ahora **se arma su propio sujeto**

El problema no era la 10: era que **la 08 tiene dos `cordura_reset` adentro de su botón** y corre
antes. Cualquier redacción de *«no resetear»* iba a seguir siendo un deseo. El botón ahora trae
**cuatro eventos forzados de cuatro categorías, sin un solo reset**, y el criterio nuevo pide
**≥ 4 renglones de evento con `N veces`** cerrando contra la barra con brecha < 0,05.

*Un control que depende de la higiene de otras diez filas no controla nada; uno que se arma su propio
sujeto, sí.*

De paso quedó escrita la trampa que la r1 tuvo en pantalla sin verla: **el desglose del jugador y los
contadores del motor tienen comandos de reset distintos**, así que pueden estar hablando de dos
ventanas distintas en la misma pantalla (la r1 leyó `cobros 2 · 3.52 % pedido` al lado de un desglose
que decía `evento door +0.00 %`).

### (F) El paréntesis mentiroso

`( hoy solo puede ser el 15 % de puerta del Yurei )` ahora nombra los **dos** caminos —el rasgo caro
del tipo, o un `santope` bajado por debajo del costo base—, imprime el valor del tope, y remata con
*«la foto de abajo dice cuál de los dos fue»*.

### (G) La decisión que **sigue siendo tuya**: piso o 6 duro

No se tocó. Con el (B) puesto, ahora hay dos formas de tomarla con datos: la 06 arreglada la mide en
juego, y `decidirTecho` la mide sin el juego. ⚠ Y ojo con esto: **después de la r1 el piso seguía sin
una sola medición**, así que la recomendación de quedarse con él sigue apoyada en el argumento (que
el 6 duro deja el `per.door = 15` inalcanzable) y no en un número.

---

## 7. Las puertas, después de los cambios

```
python dev/cordura_b2_offline.py                     -> FALLOS: 0  ( 4 ok: caida, normalizador, TECHO, fusion )
python dev/cordura_b2_offline.py --control           -> DISCRIMINA ( 3 sabotajes de ghost_flags )
  + sabotaje del `math.max` -> tope duro             -> DETECTADO  ( 7 gritos, y nombra el Yurei )
python dev/luacheck_gmod.py  ( las 40 )              -> 40/40 OK
python dev/parsear_sintaxis_glua.py lua              -> 40 archivos, 0 errores   ·  DISCRIMINA
python dev/auditar_returns_de_hooks.py lua           -> 0 de 39
python dev/auditar_puerta_cordura.py lua  ·  --control -> 0 clandestinos · 0 de 8 sin productor · DISCRIMINA
python dev/auditar_planilla.py <planilla>            -> PLANILLA SANA ( 11 checks, todos en 'sin correr' )
python dev/verificar_citas_de_planilla.py <planilla> -> 12 comandos y 4 rutas resuelven
python dev/verificar_citas_de_planilla.py --control  -> DISCRIMINA
```

---

## 8. Lo que la r2 tiene que contestar

| | |
|---|---|
| **04** | el tope recortando un apilamiento, **sin** que aparezca la línea `piso` |
| **06** | el piso pagando los 15 con `f` = 1,000 — y si no llega, **SIN CORRER**, no rojo |
| **10** | el desglose cerrando sobre ≥ 4 renglones de evento |
| **01 · 02** | los mismos criterios de siempre, pero ahora **decidibles**: la foto dice el `f` |
| 07 | falta el estado *«NO lo está mirando»* — girarse antes de leer |
| 08 (d) | `⚠ punto ciego` **imposible en este mapa y en ese lugar** (la luz más cercana, a 1182 u de 300): o se prueba en otro sitio, o se declara sin ejercer |
| 09 | la mitad de `hunt` on/off + armas y playermodel al respawnear, que no quedó registrada |

Después de la r2, **C** (el gatillo que jubila `phantasmagoria_hunt`).
