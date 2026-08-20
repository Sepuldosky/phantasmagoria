# Corrida r1 — la puerta por chance y el multiplicador global (2026-08-19)

Planilla: `dev/checks/phantasmagoria-puertas-chance-r1.html` (en el workspace, fuera del repo).
Veredicto del autor: **Pasa 9 · Falla 0 · Sin correr 0 (de 9)**, con la nota
*«Ambas funcionan bien, instrumentos tal vez "puedan" ser falsos, pero al menos como funcionalidad
está ok»*.

Mapa: `gm_break_in_redux` (por los índices y por las clases `func_door_rotating`).
Fantasmas: `#1322` (OldCrone, tipo revenant) para la P0, `#1325` (Male, tipo thaye → forzado a
revenant en la 05) para el resto.

---

## Lo que las nueve filas dejaron MEDIDO

**El pedido 1 está medido de punta a punta, y con los cuatro tramos separados.**

| fila | lo que salió |
|---|---|
| **00** control, `doorchance 0` | `CHANCE tiradas 0 · salio abrir 0 · abiertas 0 · huellas 0`, `atraveso 9`, `VETADAS 6`, `intentos 0` — **el 0 deja el comportamiento de hoy idéntico** |
| **01** techo, `doorchance 1` | `tiradas 3 · salio abrir 3 · abiertas de verdad 3 · huellas dejadas 3` — **los cuatro tramos completos**, con las tres huellas nombradas (`#1035 via cercano`, `#1036 via linea`, `#401 via linea`) |
| **02** sorteo, `doorchance 0.3` | `tiradas 17 · salio abrir 4 · abiertas 4 · huellas 4` — 4/17 = 0,24 contra un 0,30 pedido. *«Si abre unas pocas, good tal como quiero»* |
| **04** el evento | `pases del EVENTO 9`, y la bitácora con **6 `door efecto CONFIRMADO`** (`#402 1→2`, `#660 1→2`, `#1007 1→2`, `#9 1→2`, `#1058 1→2`, `#704 0→1`) |

**El evento `doors` dejó de estar inerte, y eso es lo que la bitácora no podía decir antes.** Con
`opendoors 0` puesto —la combinación en la que el autor juega— seis de nueve intentos movieron la
hoja. Antes de este bloque, el veto se comía el `Use2` entero y el resultado era `SIN EFECTO` en
**todos**.

---

## ⚠⚠⚠ LO QUE LOS NUEVE VERDES **NO** MIDIERON, y hay que tenerlo escrito

### 1. El núcleo del pedido 2 quedó sin medir: `typespeed` estaba en **0** toda la corrida

Las dos lecturas de velocidad (P0 y 05) dicen lo mismo, y no es lo que las filas pedían:

    multiplic.  x0.700
                = tipo x1.000 ( sin tipo: base neutra x1.000 ( phantasmagoria_ghost_typespeed 0
                  ( CONTROL: manda el andamio ) ) )   ×   global x0.700
    speed.base  campo VACIO   ...   motivo: phantasmagoria_ghost_typespeed 0 ( CONTROL: manda el andamio )

La fila 05 pedía `multiplic. x0.412` y `= tipo x0.588 × global x0.700`. Salió **x0.700** con
`tipo x1.000`. O sea que lo que se midió fue el camino **sin tipo** — y ese camino, con el cambio de
precedencia, hace **exactamente lo mismo que antes**: `1.0 × convar` es el `else` viejo escrito de
otra forma.

> **El código viejo y el código nuevo imprimen el mismo número en esa configuración.** La fila no
> podía distinguirlos, y la 06 (`speedmul 1` sobre el mismo sujeto) tampoco, por la misma razón.

*Es la asimetría nº 42 en su forma más barata: un falso verde que acredita.* La precondición de la
fila nombraba los once tipos válidos —el problema de los `speed.base 1.000`— y **no nombraba la
convar que borra el campo entero**. Un sujeto válido con `typespeed 0` es el mismo x1.000 contra el
que la precondición estaba escrita para proteger, entrando por la puerta de al lado.

**Qué falta, y es una lectura:** `phantasmagoria_ghost_typespeed 1`, después
`phantasmagoria_ghost_type revenant`, después `phantasmagoria_ghost_speedmul 0.7`, y por último
`phantasmagoria_ghost_speed` **solo**. Tiene que decir `x0.412` y `= tipo x0.588 × global x0.700`.

> ✅ **CORRIDA EL MISMO DÍA Y CERRADA** — ver la sección *EL RE-CORRIDO DE LA 05* más abajo.
> Salió `x0.412` con `= tipo x0.588 × global x0.700` y `COINCIDEN`. Este punto queda **saldado**;
> los puntos 2 y 3 de arriba siguen valiendo tal como están escritos.

### 2. La P0 sí dio un veredicto, y es el que el prompt anticipó: **el multiplicador es inocente**

Con `base 280` de Better Movement y `mul x0.700`, el fantasma corre a **196 u/s** contra los **280**
del jugador. `AHORA deseada 196 · real 196`. **Va más lento que el jugador**, medido.

Así que *«veo a los revenant ir rapidísimo»* no puede salir de esta perilla — el síntoma es real y el
lugar no (nº 85). La P0 nombra al sospechoso: **`phantasmagoria_ghost_typespeed` en 0**, que es
`FCVAR_ARCHIVE` y estaba guardado en la máquina del autor. Con esa convar en 0 **ningún tipo puede
mover la velocidad**: manda el andamio y nada más.

> **Hipótesis, no medición:** la r18 dejó registrado un `x2.000 de convar · 560` en su fila 05. Las
> dos convars son `FCVAR_ARCHIVE`, así que un `speedmul` alto sobrevivido de aquel A/B, con
> `typespeed 0` impidiendo que el tipo lo corrigiera, daría 560 u/s contra 280 — **el doble del
> jugador**, que sí es «rapidísimo». No está medido y no se le acredita a nadie: es la primera cosa
> que hay que mirar si el síntoma vuelve.
>
> ⚠ Y el pedido 2 **no arregla eso**: con `typespeed 0` el campo está vacío y la fórmula nueva da
> `1.0 × convar`, igual que la vieja. El arreglo de ese síntoma es `typespeed 1`.

### 3. La fila 03 no se corrió — y la culpa es de su propia precondición

Salió `CHANCE tiradas 0` con `atravesar 0`. Su propio criterio de FALLA lo dice: *«`tiradas` en 0 →
la fila no se corrió»*. La causa es que se usó `phantasmagoria_ghost_phasedoors 0` para clavar al
fantasma contra la puerta — **y la tirada sólo existe para un fantasma que IBA A ATRAVESAR**, así que
apagar el atravesado la desactiva por construcción.

**Y la precondición de la fila sugería justamente eso** (*«o con el `phasedoors 0` temporal si hace
falta»*). *Una precondición que apaga el mecanismo que la fila mide no es una precondición: es un
apagador con instrucciones.*

**Pero el defecto que la 03 iba a atrapar está refutado por otra vía, y por los números de las filas
que sí corrieron.** El Think de puertas corre a **10 Hz**; si la tirada fuera por tick, `tiradas`
estaría en los cientos. Salió:

    fila 01   tiradas 3    con  vistas 16
    fila 02   tiradas 17   con  vistas 20

`vistas` cuenta cada vez que una puerta cerrada **entra al sondeo** (la misma puerta cuenta varias).
Diecisiete tiradas contra veinte entradas es **una tirada por encuentro**, no por tick. Y `4 de 17`
con la chance en 0,30 es un sorteo que discrimina.

*La evidencia llegó del dato lateral de dos filas y no de la fila escrita para darla.* Vale, pero es
más débil: mide el promedio, no el caso de estar pegado diez segundos.

**Cómo se corre de verdad:** dejar `phasedoors 1`, `doorchance 0.3`, `phantasmagoria_ghost_doors
reset`, y bloquear al fantasma **con el cuerpo** contra una puerta cerrada (pararse del otro lado del
vano). Diez segundos. `tiradas` tiene que quedar en 1.

---

## Residuos que no son de este bloque, y no se tocaron

- **`1 FORZADAS a solido por el techo de 5 s: eso no deberia pasar`** en las filas 00, 01 y 04. Ya
  estaba anotado en `ESTADO.md` desde el bloque de la evidencia (52 atravesadas, 2 forzadas). Lo
  marca su propio instrumento.
- **`peor 19.7 s contra un prop_door_rotating cerrada`** (fila 03) con `opendoors 0` **y**
  `phasedoors 0`: es un atasco **por construcción** —no había forma de pasar— así que no es una
  medición del defecto del bot pegado. Pero el número queda para el bloque que viene.
- **Tres `door SIN EFECTO`** en la fila 04, los tres `prop_door_rotating` en estado 0: `#1037` está
  explicado por la propia bitácora (*«la puerta ya venía trabada»*), y `#537` / `#540` no. Con el
  veto descartado quedan las cuatro salidas silenciosas de la base — o que estuvieran cerradas con
  llave por el mapa. **No está medido.**
- El `sondeo direccion por cuerpo` de la fila 02 con `player #1 targetname 'SEPULDOSKY' a 0 u`: el
  autor estaba parado delante del bot. El contador de SERES existe justo para que eso no se lea como
  un defecto.

---

## ⭐⭐⭐ EL RE-CORRIDO DE LA 05, MISMO DÍA — **cierra, y con el número que el álgebra predecía**

El autor puso las cuatro líneas en orden (`typespeed 1` → `type revenant` → `speedmul 0.7` →
`ghost_speed` solo) con **el Revenant corriendo hacia él**, y salió:

    multiplic.  x0.412   [ foto de hace 0.16 s ]
                = tipo x0.588 ( campo phantom_SpeedMul ( tipo ) )   ×   global x0.700 ( phantasmagoria_ghost_speedmul )
    speed.base  campo x0.588   la tabla dice x0.588   COINCIDEN
    objetivo    115 u/s   ( base x multiplicador )
    factor      x0.210   ( objetivo / RunSpeed declarada 550 )
    AHORA       deseada 115 u/s   real 115 u/s
                deseada = la marcha 'run' de la linea de arriba: el factor YA llego al locomotion.
    marcha      CAZANDO   la decidio: override propio ( cazando, corre )

**0,588 × 0,700 = 0,412, y el reporte imprime los tres números por separado.** No es que dé «algo
distinto de antes»: da **exactamente lo que la fórmula nueva predice**, y el renglón `COINCIDEN`
prueba que el 0,588 salió de la tabla del tipo y no de otro lado. *Un número que cae donde el álgebra
lo puso es una medición; uno que simplemente cambió es una impresión.*

**La fila 05 pasa por el criterio que estaba escrito**, esta vez con el sujeto en el estado correcto.
Lo que la corrida anterior no pudo distinguir —el `1.0 × convar` que es el `else` viejo escrito de
otra forma— acá está separado en dos factores visibles.

### Y de paso cierra la P0, ahora con el tipo aplicado

`deseada 115 · real 115` con `marcha CAZANDO`, contra los **280 u/s** del jugador. **El Revenant lo
está persiguiendo al 41 % de su velocidad.** Es el mismo veredicto de la P0 —el multiplicador es
inocente— pero medido en el estado exacto en el que se reportó el síntoma: *cazando y viniendo hacia
él*. Con el tipo enganchado y el global en 0,7, un Revenant **no puede alcanzarlo nunca**.

### ⚠⚠ Dos consecuencias de haber prendido `typespeed 1`, que antes estaba en 0

1. **Los once tipos con `speed.base` distinto de 1.000 recién ahora mueven la velocidad.** Hasta hoy
   `typespeed 0` los anulaba a todos: cualquier fantasma corría al andamio. Los dos más lentos
   —`deildegast` y `deogen`, 0.235— con el global en 0,7 quedan en `0.165 × 280 = 46 u/s`, que es
   **caminar despacio**. No es un defecto: es la tabla haciéndose sentir por primera vez. Pero el
   número del global ahora **multiplica a los 30 tipos**, así que elegirlo es una decisión distinta
   de la que era cuando sólo tocaba a los sin-tipo.
2. **`speed.top` pasa de tentación a candidato con motivo.** El Revenant trae `top x1.765 ( alterna )`
   y el reporte lo imprime marcado como no usado. En Phasmophobia el Revenant es **lento mientras no
   sabe dónde estás y muy rápido cuando te ve** — eso *es* la alternancia entre 0,588 y 1,765. La
   sospecha razonable, y **no medida**, es que el «revenant rapidísimo» del autor sea el recuerdo del
   juego original y no una lectura de este addon. Sigue siendo un bloque aparte, con su propia
   planilla.

## ⭐⭐⭐ Y LA FILA 06 — EL CONTROL — TAMBIÉN CIERRA, con el número exacto

`speedmul 1` sobre el mismo Revenant `#88`, sin respawnear:

    multiplic.  x0.588   [ foto de hace 0.48 s ]
                = tipo x0.588 ( campo phantom_SpeedMul ( tipo ) )   ×   global x1.000 ( phantasmagoria_ghost_speedmul )
    speed.base  campo x0.588   la tabla dice x0.588   COINCIDEN
    objetivo    165 u/s      factor x0.299
    AHORA       deseada 165 u/s   real 165 u/s
    marcha      CAZANDO   la decidio: override propio ( cazando, corre )

**165 u/s es el número que el criterio pedía escrito de antemano** (`280 × 0.588 = 164,6`), y con el
global en `x1.000` el producto es el `speed.base` del tipo **pelado**. O sea: con la perilla en su
default, la precedencia nueva y la vieja dan **el mismo número sobre un sujeto CON tipo**. Eso es lo
que hacía falta medir, y no se podía deducir del cambio anterior — la 05 probó que los dos factores se
multiplican, y ésta prueba que **multiplicar por 1 no mueve a nadie**.

⭐ **Las dos mitades de la fila discriminaron.** La segunda era del instrumento: *«aparece el aviso del
global con la convar en 1 → el umbral del aviso está mal puesto»*. **No apareció** — la guarda
`math.abs( global - 1 ) > 0.0005` está bien puesta, y sale sola cuando no hay nada que avisar. Un
aviso que grita siempre no distingue nada.

### ✅ EL ARCO DEL PEDIDO 2 QUEDA CERRADO

    05   x0.412 = tipo x0.588 × global x0.700   ->  los dos factores SE MULTIPLICAN
    06   x0.588 = tipo x0.588 × global x1.000   ->  con el default, NADIE se mueve

**Con esto la frase «las filas de velocidad viejas no hay que re-correrlas» deja de ser una
afirmación y pasa a ser una medición.** Era exactamente lo que faltaba: el cambio de precedencia
alcanza a quien mueve la perilla y a nadie más.

### Lo que queda sin correr de este arco

- **La fila 03** y nada más: la tirada pegajosa, con la precondición arreglada (`phasedoors 1`,
  `doorchance 0.3`, `reset`, y el cuerpo en el vano — **nunca** `phasedoors 0`). El defecto que iba a
  atrapar está refutado a medias por los `tiradas 3 / vistas 16` y `tiradas 17 / vistas 20` de las
  filas 01 y 02, pero eso mide el promedio y no los diez segundos pegado.

---

## El reporte, pegado tal cual

```
REPORTE — Phantasmagoria r1 · la puerta por chance ( doorchance ), el evento que vuelve a mover la hoja, y el multiplicador global
Pasa 9 · Falla 0 · Sin correr 0  (de 9)

P0 [PASA] SE CORRE PRIMERO Y SIN TOCAR NINGUNA PERILLA · la lectura que separa las CINCO causas — El Revenant «rapidísimo»: una lectura dice de dónde sale la velocidad — y con los números de hoy no puede ser el multiplicador
   nota: [Phantasmagoria] spawn #1322  serie 6  modelo models/phantasmagoria/ghost_oldcrone.mdl  skin 0  pos 487.591125 -1138.493530 256.031250  hunt NO  tipo revenant
         [Phantasmagoria] spawn #1322  models/phantasmagoria/ghost_oldcrone.mdl  hull 30x30x69  ( la base sola da 32x32x72 )  malla 68.98 de alto  ojos z 61  [ medido DENTRO de SetupCollisionBounds, no en un timer ]
         ] phantasmagoria_ghost_speed
         [Phantasmagoria] Better Movement: MONTADO, sv_bm_enabled 1
             sv_bm_speed_run  280   walk 120   slowwalk 80
             ply SEPULDOSKY   GetRunSpeed() 280   contra la convar 280   ( x1.00 -- ese es _bmfraction )
             sv_bm_speed_inside_multiplier 1   ( adentro de un edificio el JUGADOR va a 280 u/s; el fantasma NO )
         [Phantasmagoria] conversion ENCENDIDA
         #1322  terminator_nextbot_phantom
             referencia  SEPULDOSKY   base 280 u/s   de sv_bm_speed_run ( Better Movement )
             multiplic.  x0.700   [ foto de hace 0.12 s ]
                         = tipo x1.000 ( sin tipo: base neutra x1.000 ( phantasmagoria_ghost_typespeed 0 ( CONTROL: manda el andamio ) ) )   ×   global x0.700 ( phantasmagoria_ghost_speedmul )
                         ⚠ el global esta en x0.700: este fantasma va MAS LENTO de lo que pide su tipo. Si lo ves rapido igual, el multiplicador NO es la causa:
                           mirar `base` y `fuente` de arriba ( derivespeed 0 -> 550 u/s de la base ),
                           y el `tipo` de abajo, que dice cual es de verdad.
             speed.base  campo VACIO   -> la base es x1.000 y toda la escala la pone phantasmagoria_ghost_speedmul.   motivo: phantasmagoria_ghost_typespeed 0 ( CONTROL: manda el andamio )
                         lo escribio: phantom_SetType -> sorteado entre los 30  [ pre-elegido en Initialize, ANTES de que la base sorteara el cuerpo ]   hace 18.0 s
                         tipo Revenant ( revenant ), que trae ademas: top x1.765 ( alterna ) · losSpeedUp no   ( Diseno 5.1, NO se usan todavia )
             objetivo    196 u/s   ( base x multiplicador )
             factor      x0.356   ( objetivo / RunSpeed declarada 550 )
             marchas     base run 550 · move 300 · walk 130
                         convertidas run 196 · move 107 · walk 46
             AHORA       deseada 46 u/s   real 46 u/s   ( deseada = lo que SetupSpeed escribio; real = lo que va )
                         deseada = la marcha 'walk' de la linea de arriba: el factor YA llego al locomotion.
             marcha      en calma   la decidio: la base   camina cazando: NO
             vetos       runsafety 1: cazando se respeta canRunOnPath ( acantilados, vanos < 25 u, curvas, pendientes )

00 [PASA] EL CONTROL · si esta fila no sale verde, el resto de la planilla no se puede correr — Con doorchance 0 el comportamiento de hoy queda idéntico: atraviesa, no abre, y no se tira ningún dado
   nota: [Phantasmagoria] spawn #1325  serie 8  modelo models/phantasmagoria/ghost_male.mdl  skin 0  pos 952.525818 315.555939 256.031250  hunt NO  tipo thaye
         [Phantasmagoria] spawn #1325  models/phantasmagoria/ghost_male.mdl  hull 32x32x72  ( la base sola da 32x32x72 )  malla 72.29 de alto  ojos z 64  [ medido DENTRO de SetupCollisionBounds, no en un timer ]
         ] phantasmagoria_hunt 1
             #1325  hunt -> SI ( cazador )   llamadas a OnFirstRelationWithPlayer: 1
         [Phantasmagoria] 1 fantasma(s) en HUNT. Solo se movio el flag: ni la relacion ni la memoria se tocaron.
         [Phantasmagoria] #1325 atraveso mas de 5 s seguidos y se lo forzo a solido. Eso no deberia pasar: mirar contra que puerta.
         ] phantasmagoria_ghost_doors
         [Phantasmagoria] convars: abrir 0 · atravesar 1 · silencio 0   ( 0 nadie · 1 el flag del NPC · 2 todos )   destrabar SI
             chance    0.00   ( CONTROL: el que iba a atravesar atraviesa; no se tira ningun dado )   <- phantasmagoria_ghost_doorchance
             pisadas: stepsilent 0 · stepsonlyhunt 1   <- si alguna calla las pisadas, TAMBIEN calla el click de esta puerta
         [Phantasmagoria] atravesar: modo 1 ( 0 nadie · 1 segun el flag del NPC · 2 todos )
             mascara   MASK_NPCWORLDSTATIC = 131083   CONTENTS_MOVEABLE ( 16384 ) NO la trae -> los brush entities dejan de frenarlo
             la solida 33701899 es MASK_NPCSOLID, a la que vuelve al salir
         #1325  terminator_nextbot_phantom
             sondeo    direccion por path   alcance 98 u   ( velocidad x 0.5 s, entre 60 y 200 )
             abre      NO   campo = true   porque la convar phantasmagoria_ghost_opendoors esta en 0 ( control: nadie )
             atraviesa SI   campo = true   porque el flag phantom_PhasesDoors del NPC dice SI
             silencio  NO   campo = false   porque la convar phantasmagoria_ghost_doorsilent esta en 0 ( control: nadie )
             camina    NO   campo = false   porque el flag phantom_WalksWhenHunting del NPC dice NO
             estado    solido   ( la ultima vez atraveso 1.0 s )
             delante   ninguna puerta, y el sondeo tampoco pega contra nada
                       acumulado: topo con GEOMETRIA que no es puerta 0 tick(s) de sondeo
                                  topo con un SER ( jugador / NPC / nextbot ) 178 tick(s)   ( NO es un defecto: alguien estaba delante )
             peor      3.0 s   contra un func_door_rotating cerrada   [ runsafety 1: cazando respeta canRunOnPath ]
             vistas    13 veces que una puerta CERRADA entro al sondeo   ( la misma puerta cuenta varias si entra y sale )
             VETADAS   6 aperturas bloqueadas ( incluidas las que iba a hacer la BASE por su cuenta )
             intentos  0 sobre una puerta CERRADA delante
             escalera  1 Use2 0   ·  2 OpenAwayFrom 0   ·  3 Fire Open 0   ·  destrabadas 0
             atraveso  9 veces   ( todas por cercania: a 45 u o menos )   ·  1 FORZADAS a solido por el techo de 5 s: eso no deberia pasar
             silencio  0 ventanas de silencio abiertas   ·  0 de ellas sobre aperturas de LA BASE, no de nuestra escalera   ·  0 hojas HERMANAS silenciadas de arrastre ( puertas dobles )
                       ( tapa el click del bot Y el sonido de la hoja, 3 s )
             resultado ABRIO 0   fallo 0   ( releyendo el estado 0.9 s despues; ABRIENDO cuenta como abrio )
             huellas   0 dejadas por este fantasma
             CHANCE    tiradas 0   ·  salio abrir 0   ·  abiertas de verdad 0   ·  huellas dejadas 0
                       rescates 0 ( decidio abrir y a los 3 s la hoja seguia cerrada: se dio vuelta a atravesar )   ·  pases del EVENTO 0 ( aperturas que el evento forzo por encima del veto )
         [Phantasmagoria] huellas vivas: 0 de 0 guardadas   ( duran 60 s; se DIBUJAN con el gate abierto: en la consola del cliente  phantasmagoria_uv 1  -- gate provisional hasta que exista la linterna )
         [Phantasmagoria] bitacora del silencio   ( puertas mudas AHORA MISMO: 0 )
             VACIA. Con el silencio en 1 o 2 y una apertura, esto tiene que llenarse. Si sigue vacia, phantom_SilenceDoor no esta corriendo -- mirar la linea 'silencio' de arriba.

01 [PASA] EL TECHO · separa «la chance nunca sale» de «sale y no abre» — Con doorchance 1 abre siempre — y deja huella. Las dos cosas, no una
   nota: ] phantasmagoria_ghost_doorchance 1
         ] phantasmagoria_ghost_doors
         [Phantasmagoria] convars: abrir 0 · atravesar 1 · silencio 0   ( 0 nadie · 1 el flag del NPC · 2 todos )   destrabar SI
             chance    1.00   ( el que IBA A ATRAVESAR abre en su lugar 100 de cada 100 encuentros )   <- phantasmagoria_ghost_doorchance
             pisadas: stepsilent 0 · stepsonlyhunt 1   <- si alguna calla las pisadas, TAMBIEN calla el click de esta puerta
         [Phantasmagoria] atravesar: modo 1 ( 0 nadie · 1 segun el flag del NPC · 2 todos )
             mascara   MASK_NPCWORLDSTATIC = 131083   CONTENTS_MOVEABLE ( 16384 ) NO la trae -> los brush entities dejan de frenarlo
             la solida 33701899 es MASK_NPCSOLID, a la que vuelve al salir
         #1325  terminator_nextbot_phantom
             sondeo    direccion por marcha   alcance 98 u   ( velocidad x 0.5 s, entre 60 y 200 )
             abre      NO   campo = true   porque la convar phantasmagoria_ghost_opendoors esta en 0 ( control: nadie )
             atraviesa SI   campo = true   porque el flag phantom_PhasesDoors del NPC dice SI
             silencio  NO   campo = false   porque la convar phantasmagoria_ghost_doorsilent esta en 0 ( control: nadie )
             camina    NO   campo = false   porque el flag phantom_WalksWhenHunting del NPC dice NO
             estado    solido   ( la ultima vez atraveso 0.7 s )
             delante   ninguna puerta, y el sondeo tampoco pega contra nada
                       acumulado: topo con GEOMETRIA que no es puerta 40 tick(s) de sondeo   ( parate ahi y corre phantasmagoria_ghost_puerta )
                                  topo con un SER ( jugador / NPC / nextbot ) 178 tick(s)   ( NO es un defecto: alguien estaba delante )
             peor      3.0 s   contra un func_door_rotating cerrada   [ runsafety 1: cazando respeta canRunOnPath ]
             vistas    16 veces que una puerta CERRADA entro al sondeo   ( la misma puerta cuenta varias si entra y sale )
             VETADAS   7 aperturas bloqueadas ( incluidas las que iba a hacer la BASE por su cuenta )
             intentos  3 sobre una puerta CERRADA delante
             escalera  1 Use2 3   ·  2 OpenAwayFrom 0   ·  3 Fire Open 0   ·  destrabadas 0
             atraveso  11 veces   ( todas por cercania: a 45 u o menos )   ·  1 FORZADAS a solido por el techo de 5 s: eso no deberia pasar
             silencio  0 ventanas de silencio abiertas   ·  0 de ellas sobre aperturas de LA BASE, no de nuestra escalera   ·  0 hojas HERMANAS silenciadas de arrastre ( puertas dobles )
                       ( tapa el click del bot Y el sonido de la hoja, 3 s )
             resultado ABRIO 3   fallo 0   ( releyendo el estado 0.9 s despues; ABRIENDO cuenta como abrio )
             huellas   3 dejadas por este fantasma
             CHANCE    tiradas 3   ·  salio abrir 3   ·  abiertas de verdad 3   ·  huellas dejadas 3
                       rescates 0 ( decidio abrir y a los 3 s la hoja seguia cerrada: se dio vuelta a atravesar )   ·  pases del EVENTO 0 ( aperturas que el evento forzo por encima del veto )
         [Phantasmagoria] huellas vivas: 3 de 3 guardadas   ( duran 60 s; se DIBUJAN con el gate abierto: en la consola del cliente  phantasmagoria_uv 1  -- gate provisional hasta que exista la linterna )
         [Phantasmagoria] bitacora del silencio   ( puertas mudas AHORA MISMO: 0 )
             VACIA. Con el silencio en 1 o 2 y una apertura, esto tiene que llenarse. Si sigue vacia, phantom_SilenceDoor no esta corriendo -- mirar la linea 'silencio' de arriba.
             huella 1  mano 4   en func_door_rotating #1035   via cercano   quedan 55 s
             huella 2  mano 1   en func_door_rotating #1036   via linea   quedan 55 s
             huella 3  mano 3   en func_door_rotating #401   via linea   quedan 60 s

02 [PASA] EL SORTEO · el criterio no puede ser un número exacto ni «salió algo» — Con doorchance 0.3 y veinte encuentros: ni 0 ni 20
   nota: ] phantasmagoria_ghost_doors
         [Phantasmagoria] convars: abrir 0 · atravesar 1 · silencio 0   ( 0 nadie · 1 el flag del NPC · 2 todos )   destrabar SI
             chance    0.30   ( el que IBA A ATRAVESAR abre en su lugar 30 de cada 100 encuentros )   <- phantasmagoria_ghost_doorchance
             pisadas: stepsilent 0 · stepsonlyhunt 1   <- si alguna calla las pisadas, TAMBIEN calla el click de esta puerta
         [Phantasmagoria] atravesar: modo 1 ( 0 nadie · 1 segun el flag del NPC · 2 todos )
             mascara   MASK_NPCWORLDSTATIC = 131083   CONTENTS_MOVEABLE ( 16384 ) NO la trae -> los brush entities dejan de frenarlo
             la solida 33701899 es MASK_NPCSOLID, a la que vuelve al salir
         #1325  terminator_nextbot_phantom
             sondeo    direccion por cuerpo   alcance 60 u   ( velocidad x 0.5 s, entre 60 y 200 )
             abre      NO   campo = true   porque la convar phantasmagoria_ghost_opendoors esta en 0 ( control: nadie )
             atraviesa SI   campo = true   porque el flag phantom_PhasesDoors del NPC dice SI
             silencio  NO   campo = false   porque la convar phantasmagoria_ghost_doorsilent esta en 0 ( control: nadie )
             camina    NO   campo = false   porque el flag phantom_WalksWhenHunting del NPC dice NO
             estado    solido   ( la ultima vez atraveso 1.3 s )
             delante   ninguna PUERTA, pero el sondeo SI pega:
                       player #1  targetname 'SEPULDOSKY'  a 0 u
                       modelo 'models/player/niko/niko_bellic/nikob.mdl'
                       ES UN SER, NO GEOMETRIA: no hay nada que agregar a ninguna lista.
                         Se cuenta aparte a proposito ( ver los dos acumulados de abajo ).
                         Si sos vos, corrase: parado ahi estas midiendo tu propio bloqueo.
                       acumulado: topo con GEOMETRIA que no es puerta 39 tick(s) de sondeo   ( parate ahi y corre phantasmagoria_ghost_puerta )
                                  topo con un SER ( jugador / NPC / nextbot ) 55 tick(s)   ( NO es un defecto: alguien estaba delante )
             peor      0.0 s   [ runsafety 1: cazando respeta canRunOnPath ]
             vistas    20 veces que una puerta CERRADA entro al sondeo   ( la misma puerta cuenta varias si entra y sale )
             VETADAS   12 aperturas bloqueadas ( incluidas las que iba a hacer la BASE por su cuenta )
             intentos  4 sobre una puerta CERRADA delante
             escalera  1 Use2 4   ·  2 OpenAwayFrom 0   ·  3 Fire Open 0   ·  destrabadas 0
             atraveso  13 veces   ( todas por cercania: a 45 u o menos )
             silencio  0 ventanas de silencio abiertas   ·  0 de ellas sobre aperturas de LA BASE, no de nuestra escalera   ·  0 hojas HERMANAS silenciadas de arrastre ( puertas dobles )
                       ( tapa el click del bot Y el sonido de la hoja, 3 s )
             resultado ABRIO 4   fallo 0   ( releyendo el estado 0.9 s despues; ABRIENDO cuenta como abrio )
             huellas   4 dejadas por este fantasma
             CHANCE    tiradas 17   ·  salio abrir 4   ·  abiertas de verdad 4   ·  huellas dejadas 4
                       rescates 0 ( decidio abrir y a los 3 s la hoja seguia cerrada: se dio vuelta a atravesar )   ·  pases del EVENTO 0 ( aperturas que el evento forzo por encima del veto )
         [Phantasmagoria] huellas vivas: 0 de 4 guardadas   ( duran 60 s; se DIBUJAN con el gate abierto: en la consola del cliente  phantasmagoria_uv 1  -- gate provisional hasta que exista la linterna )
         [Phantasmagoria] bitacora del silencio   ( puertas mudas AHORA MISMO: 0 )
             VACIA. Con el silencio en 1 o 2 y una apertura, esto tiene que llenarse. Si sigue vacia, phantom_SilenceDoor no esta corriendo -- mirar la linea 'silencio' de arriba.
             huella 1  mano 1   en func_door_rotating #1057   via linea   quedan 0 s
             huella 2  mano 2   en func_door_rotating #896   via linea   quedan 0 s
             huella 3  mano 2   en func_door_rotating #1008   via linea   quedan 0 s
             huella 4  mano 1   en func_door_rotating #897   via linea   quedan 0 s
         //Si abre unas pocas, good tal como quiero

03 [PASA] LA PEGAJOSA · ninguna otra fila puede ver este defecto — Pegado a la puerta diez segundos: tiradas sube UNA vez, no sesenta
   nota: ] phantasmagoria_ghost_doors reset
         [Phantasmagoria] contadores y peor-marca reseteados en 1 fantasma(s). Las huellas NO se tocan.
         ] phantasmagoria_ghost_phasedoors 0
         ] phantasmagoria_ghost_doors
         [Phantasmagoria] convars: abrir 0 · atravesar 0 · silencio 0   ( 0 nadie · 1 el flag del NPC · 2 todos )   destrabar SI
             chance    0.30   ( el que IBA A ATRAVESAR abre en su lugar 30 de cada 100 encuentros )   <- phantasmagoria_ghost_doorchance
             pisadas: stepsilent 0 · stepsonlyhunt 1   <- si alguna calla las pisadas, TAMBIEN calla el click de esta puerta
         [Phantasmagoria] atravesar: modo 0 ( 0 nadie · 1 segun el flag del NPC · 2 todos )
             mascara   MASK_NPCWORLDSTATIC = 131083   CONTENTS_MOVEABLE ( 16384 ) NO la trae -> los brush entities dejan de frenarlo
             la solida 33701899 es MASK_NPCSOLID, a la que vuelve al salir
         #1325  terminator_nextbot_phantom
             sondeo    direccion por path   alcance 60 u   ( velocidad x 0.5 s, entre 60 y 200 )
             abre      NO   campo = true   porque la convar phantasmagoria_ghost_opendoors esta en 0 ( control: nadie )
             atraviesa NO   campo = true   porque la convar phantasmagoria_ghost_phasedoors esta en 0 ( control: nadie )
             silencio  NO   campo = false   porque la convar phantasmagoria_ghost_doorsilent esta en 0 ( control: nadie )
             camina    NO   campo = false   porque el flag phantom_WalksWhenHunting del NPC dice NO
             estado    solido   ( la ultima vez atraveso 1.4 s )
             delante   func_door_rotating #1213   m_toggle_state = 1   cerrada   a 0 u
             trabado   0.7 s contra ESTA   ( velocidad 0 u/s, el umbral es 30 )
             peor      19.7 s   contra un prop_door_rotating cerrada   [ runsafety 1: cazando respeta canRunOnPath ]
             vistas    3 veces que una puerta CERRADA entro al sondeo   ( la misma puerta cuenta varias si entra y sale )
             VETADAS   7 aperturas bloqueadas ( incluidas las que iba a hacer la BASE por su cuenta )
             intentos  0 sobre una puerta CERRADA delante
             escalera  1 Use2 0   ·  2 OpenAwayFrom 0   ·  3 Fire Open 0   ·  destrabadas 0
             atraveso  0 veces   ( todas por cercania: a 45 u o menos )
             silencio  0 ventanas de silencio abiertas   ·  0 de ellas sobre aperturas de LA BASE, no de nuestra escalera   ·  0 hojas HERMANAS silenciadas de arrastre ( puertas dobles )
                       ( tapa el click del bot Y el sonido de la hoja, 3 s )
             resultado ABRIO 0   fallo 0   ( releyendo el estado 0.9 s despues; ABRIENDO cuenta como abrio )
             huellas   0 dejadas por este fantasma
             CHANCE    tiradas 0   ·  salio abrir 0   ·  abiertas de verdad 0   ·  huellas dejadas 0
                       rescates 0 ( decidio abrir y a los 3 s la hoja seguia cerrada: se dio vuelta a atravesar )   ·  pases del EVENTO 0 ( aperturas que el evento forzo por encima del veto )
         [Phantasmagoria] huellas vivas: 0 de 3 guardadas   ( duran 60 s; ... )
         [Phantasmagoria] bitacora del silencio   ( puertas mudas AHORA MISMO: 0 )
             VACIA. ...
             huella 1  mano 1   en func_door_rotating #1035   via cercano   quedan 0 s
             huella 2  mano 2   en func_door_rotating #1036   via linea   quedan 0 s
             huella 3  mano 2   en func_door_rotating #1035   via linea   quedan 0 s

04 [PASA] TU DECISIÓN · el evento siempre mueve la hoja, también con opendoors 0 — El evento doors deja de estar inerte: la bitácora dice efecto CONFIRMADO
   nota: ] phantasmagoria_ghost_doors
         [Phantasmagoria] convars: abrir 0 · atravesar 1 · silencio 0   ( 0 nadie · 1 el flag del NPC · 2 todos )   destrabar SI
             chance    0.30   ( el que IBA A ATRAVESAR abre en su lugar 30 de cada 100 encuentros )   <- phantasmagoria_ghost_doorchance
         #1325  terminator_nextbot_phantom
             sondeo    direccion por path   alcance 60 u   ( velocidad x 0.5 s, entre 60 y 200 )
             abre      NO   campo = true   porque la convar phantasmagoria_ghost_opendoors esta en 0 ( control: nadie )
             atraviesa SI   campo = true   porque el flag phantom_PhasesDoors del NPC dice SI
             estado    ATRAVESANDO hace 1.2 s   con MASK_NPCWORLDSTATIC
             delante   func_door_rotating #659   m_toggle_state = 0   ABIERTA   a 11 u
             trabado   6.4 s contra ESTA   ( velocidad 0 u/s, el umbral es 30 )
             peor      6.6 s   contra un prop_door_rotating cerrada   [ runsafety 1: cazando respeta canRunOnPath ]
             vistas    6 veces que una puerta CERRADA entro al sondeo
             VETADAS   3 aperturas bloqueadas ( incluidas las que iba a hacer la BASE por su cuenta )
             intentos  1 sobre una puerta CERRADA delante
             escalera  1 Use2 1   ·  2 OpenAwayFrom 0   ·  3 Fire Open 0   ·  destrabadas 0
             atraveso  7 veces   ·  1 FORZADAS a solido por el techo de 5 s: eso no deberia pasar
             resultado ABRIO 1   fallo 0
             huellas   1 dejadas por este fantasma
             CHANCE    tiradas 5   ·  salio abrir 1   ·  abiertas de verdad 1   ·  huellas dejadas 1
                       rescates 0   ·  pases del EVENTO 9 ( aperturas que el evento forzo por encima del veto )
             huella 1  mano 2   en func_door_rotating #659   via linea   quedan 51 s

         --- bitacora de eventos, la cola pertinente ---
              2403.3  #1325/s8 HUNT  door r=450 puerta prop_door_rotating #537 a 419 u -- INTENTADA ( estado 0 )  [ sin pestillo: el sorteo salio abrir ]  [FORZADO]
              2403.5  #1325/s8 door SIN EFECTO -- prop_door_rotating #537 no cambio de estado ( 0 ). El veto propio ya NO es sospechoso ( el evento pide pase ): quedan las cuatro salidas silenciosas de la base -- CanUseStuff, GetDriver, la lista negra de clases, o un TerminatorBlockUse de un TERCERO
              2406.1  #1325/s8 HUNT  door r=450 puerta func_door_rotating #402 a 423 u -- INTENTADA ( estado 1 )  [FORZADO]
              2406.4  #1325/s8 door efecto CONFIRMADO -- func_door_rotating #402  estado 1 -> 2
              2409.8  #1325/s8 HUNT  door r=450 puerta prop_door_rotating #1037 a 244 u -- INTENTADA ( estado 0 )  [ sin pestillo: la puerta ya venia trabada ( no es nuestra ) ]  [FORZADO]
              2410.1  #1325/s8 door SIN EFECTO -- prop_door_rotating #1037 no cambio de estado ( 0 ). ...
              2418.3  #1325/s8 HUNT  door r=450 puerta func_door_rotating #1203 a 442 u -- PESTILLO INTENTADO con llaves ( 1/2 trabadas )  [FORZADO]
              2418.3  #1325/s8 HUNT  door r=450 puerta prop_door_rotating #540 a 473 u -- INTENTADA ( estado 0 )  [FORZADO]
              2418.6  #1325/s8 pestillo CONFIRMADO -- func_door_rotating #1203 trabada ( m_bLocked true ); se suelta sola en 45 s
              2418.6  #1325/s8 door SIN EFECTO -- prop_door_rotating #540 no cambio de estado ( 0 ). ...
              2424.3  #1325/s8 HUNT  door r=450 puerta prop_door_rotating #525 a 330 u -- PESTILLO INTENTADO con llaves ( 2/2 trabadas )  [FORZADO]
              2424.6  #1325/s8 pestillo CONFIRMADO -- prop_door_rotating #525 trabada ( m_bLocked true ); se suelta sola en 45 s
              2437.6  #1325/s8 HUNT  door r=450 puerta func_door_rotating #660 a 125 u -- INTENTADA ( estado 1 )  [FORZADO]
              2437.6  #1325/s8 HUNT  door r=450 puerta func_door_rotating #1007 a 329 u -- INTENTADA ( estado 1 )  [FORZADO]
              2437.8  #1325/s8 door efecto CONFIRMADO -- func_door_rotating #660  estado 1 -> 2
              2437.8  #1325/s8 door efecto CONFIRMADO -- func_door_rotating #1007  estado 1 -> 2
              2446.0  #1325/s8 HUNT  door r=450 puerta func_door #9 a 472 u -- INTENTADA ( estado 1 )  [FORZADO]
              2446.0  #1325/s8 HUNT  door r=450 puerta func_door_rotating #1058 a 225 u -- INTENTADA ( estado 1 )  [FORZADO]
              2446.0  #1325/s8 HUNT  door r=450 puerta prop_door_rotating #704 a 432 u -- INTENTADA ( estado 0 )  [FORZADO]
              2446.2  #1325/s8 door efecto CONFIRMADO -- func_door #9  estado 1 -> 2
              2446.2  #1325/s8 door efecto CONFIRMADO -- func_door_rotating #1058  estado 1 -> 2
              2446.2  #1325/s8 door efecto CONFIRMADO -- prop_door_rotating #704  estado 0 -> 1

05 [PASA] EL PEDIDO 2 · sobre un tipo que NO sea x1.000, o la fila no puede fallar — speedmul 0.7 sobre un Revenant da x0.412 — y el reporte dice de dónde sale cada factor
   nota: ] phantasmagoria_ghost_speed
         [Phantasmagoria] Better Movement: MONTADO, sv_bm_enabled 1
             sv_bm_speed_run  280   walk 120   slowwalk 80
             ply SEPULDOSKY   GetRunSpeed() 280   contra la convar 280   ( x1.00 -- ese es _bmfraction )
         [Phantasmagoria] conversion ENCENDIDA
         #1325  terminator_nextbot_phantom
             referencia  SEPULDOSKY   base 280 u/s   de sv_bm_speed_run ( Better Movement )
             multiplic.  x0.700   [ foto de hace 0.49 s ]
                         = tipo x1.000 ( sin tipo: base neutra x1.000 ( phantasmagoria_ghost_typespeed 0 ( CONTROL: manda el andamio ) ) )   ×   global x0.700 ( phantasmagoria_ghost_speedmul )
                         ⚠ el global esta en x0.700: este fantasma va MAS LENTO de lo que pide su tipo. ...
             speed.base  campo VACIO   -> la base es x1.000 y toda la escala la pone phantasmagoria_ghost_speedmul.   motivo: phantasmagoria_ghost_typespeed 0 ( CONTROL: manda el andamio )
                         lo escribio: phantom_SetType -> override de consola ( ANDAMIO: phantasmagoria_ghost_type )   hace 32.6 s
                         tipo Revenant ( revenant ), que trae ademas: top x1.765 ( alterna ) · losSpeedUp no   ( Diseno 5.1, NO se usan todavia )
             objetivo    196 u/s   ( base x multiplicador )
             factor      x0.356   ( objetivo / RunSpeed declarada 550 )
             marchas     base run 550 · move 300 · walk 130
                         convertidas run 196 · move 107 · walk 46
             AHORA       deseada 196 u/s   real 196 u/s
                         deseada = la marcha 'run' de la linea de arriba: el factor YA llego al locomotion.
             marcha      CAZANDO   la decidio: override propio ( cazando, corre )   camina cazando: NO
         //Multiplicador si cambia su velocidad

06 [PASA] EL CONTROL DEL PEDIDO 2 · prueba que no se movió nadie que no pidió moverse — Con speedmul 1, el mismo Revenant da el número de antes del bloque, exacto
   nota: Si tiene su velocidad vieja con el mult en 1, funciona bien

07 [PASA] NO ROMPER LO QUE YA CERRÓ · este bloque tocó el veto, el Think de puertas y el evento — Con opendoors 1 las puertas siguen andando como antes — y el +USE y el pestillo también
   nota: Si no hay problemas ahi
```
