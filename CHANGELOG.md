# Phantasmagoria — Changelog

**Estado:** ver [ESTADO.md](ESTADO.md) · **Diseño:** ver [docs/](docs/PHANTOM_Phasmophobia_Diseno.md)

Formato: una entrada por sesión de trabajo, la más reciente arriba. Se anota lo que se **hizo** y lo
que se **midió**, no lo que se planea.

---

## 2026-08-18 (44) — **`table overflow` en `gm_uh_house`: el parser leía la firma `LZMA` como si fuera una cantidad. Dos defectos y no uno, el gemelo en Python tenía el mismo con otra cara, y el arnés nuevo se disfrazó de hallazgo sobre el mapa.**

El autor cargó la planilla del bloque anterior en `gm_uh_house` y no pudo correr **ni una fila**: el
evento `prop` tiraba un error de Lua en cada disparo.

    [phantasmagoria] .../bsp_statics.lua:271: table overflow
      1. parsear  2. Estaticos  3. EstaticosEnEsfera  4. fn (EV.prop)
      5. phantom_FireEvent  6. fn  7. EachGhost  8. unknown  9. concommand.lua:60

### ⭐⭐ La causa, medida y exacta: no era un número mal leído, **eran cuatro letras**

`dictEntries = 1095588428`. Ese número, escrito de vuelta como cuatro bytes little endian, es
**`LZMA`**. El game lump `sprp` de ese mapa viene **comprimido**, y el parser leyó la firma de
compresión como si fuera la cantidad de rutas del diccionario.

*Un campo numérico que no es un número se lee como un número enorme* — y un número enorme no se
distingue de un dato válido mirando sólo su signo, que es lo único que este parser miraba.

### ⚠⚠ Y son **dos** defectos, con la misma raíz y consecuencias distintas

**( 1 ) Todas las guardas de conteo miraban un solo lado.** `if not n or n < 0` rechaza el negativo y
deja pasar el absurdo. El límite correcto no es una constante inventada: es **el tramo que ya se leyó
dividido por lo que ocupa cada entrada** — un diccionario de N rutas ocupa `N*128` bytes, y si no
entran en el `sprp` que se tiene en la mano, ese N no es un N. Puestas las dos mitades en
`dictEntries`, `leafEntries`, `entryCount`, el recorrido de game lumps y el propio `sofs+slen` contra
el tamaño del archivo.

⚠ **Lo que vuelve esto una entrada y no un parche:** este archivo ya tenía **tres auto-controles
finísimos** contra la desalineación — la forma de la ruta (`models/…mdl`), el sobrante en cero, el
`PropType` fuera del diccionario — y **ninguno** contra un número que no puede ser una cantidad. *Los
controles se habían escrito para el modo de falla que ya se había visto.* El que faltaba era el
barato.

**( 2 ) `parsear` podía tirar, y eso rompe el contrato que el propio archivo tiene escrito.**
`Estaticos()` promete, con todas las letras, *«devuelve la tabla SIEMPRE, con `ok = false` y un
`error` legible… no devuelve nil»*. Un error de Lua adentro se lleva puesto al consumidor, al evento y
al concommand — nueve marcos de pila que **apuntan al consumidor y no a la causa**, y un evento `prop`
inservible. Ahora va en `pcall`. ⚠ Y **la falla se cachea**: antes, al tirar, la asignación
`cache = parsear()` nunca ocurría, así que el mapa se **re-parseaba y re-reventaba en cada disparo**.
Un archivo que no se puede leer no se vuelve legible por releerlo.

### ⚠⚠ El instrumento gemelo tenía el mismo defecto, y en Python es **peor**

`dev/censo_props_horneados.py` — el `.py` que valida al Lua — hacía `for _ in range(ndict)` sin
ninguna guarda. Con el mismo 1095588428 no revienta: **se cuelga**, llenando una lista de mil noventa
y cinco millones de entradas. Se lo corrió y hubo que matarlo.

*La cara que pone una falla depende del lenguaje, no de su gravedad.* Un crash se ve; **un cuelgue se
lee como «todavía está trabajando»**. El mismo defecto, en el instrumento que existe para auditar al
otro, es el que más tarda en descubrirse.

### El lump comprimido, y por qué esto **no** es una apuesta

Source comprime lumps con una cabecera propia de 17 bytes: `LZMA` + tamaño descomprimido + tamaño
comprimido + 5 bytes de propiedades LZMA1. ⚠ Y **`filelen` de la tabla de game lumps trae el tamaño
DESCOMPRIMIDO**, así que el `Read( slen )` se pasa de largo y se mete en el lump vecino.

Lo que **sí** se midió sin el juego, con Python: **15005 bytes se abren en 78334**, y ahí adentro hay
`188 modelos / 702 props`, `paso 72`, **`sobrantes 0`**, primer modelo
`models/props/CS_Militia/circularsaw01.mdl`. O sea que el dato está y queda alineado.

Lo que **no** se pudo medir sin el juego es **una sola cosa**: si el `util.Decompress` de GMod acepta
la cabecera «alone» que el `.lua` le arma. Por eso el camino **se verifica a sí mismo** — compara el
largo que sale contra el que declara la cabecera antes de creerle — y si falla degrada a `ok = false`
con motivo, que es exactamente donde estábamos. Un `util.Decompress` sobre basura puede devolver una
string corta en vez de `nil`, y una string corta parseada como `sprp` da **números creíbles**: el
largo declarado es el testigo independiente del descompresor.

    gm_funkis_night   418 modelos / 1588 props    ( sin cambios: es el CONTROL )
    gm_uh_house       188 modelos /  702 props    sprp COMPRIMIDO, 11 modelos / 13 instancias reclamadas

### ⭐ `dev/bsp_statics_offline.py` — el parser de `.bsp` deja de necesitar una partida

**Carga el `.lua` del addon y lo ejecuta** en un Lua real, con `file.Open` / `game.GetMap` /
`util.Decompress` apuntando a un `.bsp` de verdad. No lo reimplementa. Distingue **tres** salidas, que
es lo que hacía falta: `ok`, `ok = false` con motivo (que es el parser haciendo su trabajo), y **error
de Lua** (que es el rojo). Trae el control de `gm_funkis_night` y, sobre un mapa comprimido, un
**control negativo**: con un descompresor que devuelve basura, el parser tiene que decir `ok = false`
y **no** producir números.

⚠⚠ **Y el arnés se equivocó primero, de la peor manera.** `lupa` decodificaba como UTF-8 cada string
de Lua que cruzaba a Python — y acá las strings de Lua son **los bytes crudos del `.bsp`**. Reventó
con `'utf-8' codec can't decode byte 0xfe`… y **el `pcall` que se acababa de agregar al addon lo
atajó y lo imprimió como `ok = false` del mapa**. Un defecto del instrumento, disfrazado de hallazgo
sobre el sujeto, servido por la red de contención recién puesta. El arnés ahora **separa los dos
`ok = false`**: el que el parser decide, y el que sale de un error atajado — que no es una propiedad
del mapa.

⚠ Y una tercera del mismo rato: el control del generador de la planilla buscaba `418 / 1588` como
resto del bloque viejo, y **la fila nueva cita ese número a propósito**. El marcador dejó de
discriminar: se cambió el criterio, no se silenció el control.

### Sobre el segundo pedido del autor, que sigue sin escribirse

El autor agregó la mitad que faltaba: *«una radio phys que se rompa no detiene el sonido **ni permite
pararlo**»*. **Esa segunda mitad queda confirmada leyendo el código, sin el motor:** `podarSonando()`
tira la entrada del registro `SONANDO` cuando la entidad deja de ser válida, y `apagarCerca()` poda
antes de buscar. O sea que **el registro suelta el único mango justo en el momento en que haría
falta**: rota la radio, el `+USE` no tiene a quién apagar, ni ahora ni nunca.

La otra mitad — si el sonido sobrevive al borrado de la entidad — sigue siendo la pregunta de las
filas 00 y 01, y ahora se puede correr, porque el mapa ya no revienta.

### Los chequeos

    luacheck 36/36 · sintaxis real 36/36 · returns de hooks 0/28 · rutas de sonido 165/0 faltantes
    guarda 3b callada y comprobada gritando · bsp offline: control 418/1588 + negativo del camino comprimido

---

## 2026-08-17 (43) — **El clic del interruptor y el celular que no era un celular. Y el tercer pedido no se escribió: la afirmación en la que se apoya está en CINCO lugares del repo y nunca se midió.**

Tres pedidos del autor, textuales, dados al cerrar el bloque del `+USE` ( entrada **41** ). **Dos están escritos y medidos
offline. El tercero no, y el motivo es el hallazgo de la entrada.**

⚠ **SIN CORRER EN JUEGO.** Planilla nueva en `dev/checks/phantasmagoria-clic-y-celular.html`, siete
filas, copiada de la del `+USE` (que ya trae la guarda de largo de 255 en el generador).

### ⚠⚠⚠ La frase que decide el bloque está escrita cinco veces y **nunca se midió**

> *«Borrar el emisor **ES** un corte: una entidad que se va se lleva su canal.»*

Censadas hoy con `rg --no-ignore`, con denominador: **cinco sitios** —
`server_events.lua:218`, `:875` y `:3409`, `dev/duracion_ogg.py:8` y `CHANGELOG (41)`. **Nació como
razón en un comentario y se citó después como si fuera un resultado**; el `:3409` es el más viejo, o
sea que ya se propagó de una ronda a la siguiente. *Un comentario mentiroso se propaga al lector que
lo cita* — y acá el lector escribió código con él (`EMISOR_MARGEN` existe por esa frase).

**Decide dos cosas a la vez, y por eso es la fila 00 y no una nota al pie:**

- **si es cierta** → romper el prop **ya corta el sonido solo**, y el segundo pedido del autor está
  hecho sin escribir una línea;
- **si es falsa** → el pedido es un defecto real, `EMISOR_MARGEN` no protegió nunca de nada, y **hay
  que corregir los cinco lugares en el mismo commit**, no sólo el código.

Se mide con `clock_tick` (**46,55 s** medidos, mono) y **no** con un clip corto: *un sonido que se
termina solo pasa por un borrado que funcionó*. La fila lleva **un cuarto comando que el prompt no
pedía** y que es el que la vuelve una medición: `print(IsValid(PHT.e))` después del borrado. Sin él,
*«el tic-tac sigue»* no distingue **el borrado no calla** de **el borrado no ocurrió**, y esas dos
mandan a arreglar lugares distintos.

Y la fila 01 es aparte a propósito: **romper no es borrar**. Un `prop_physics` que se rompe puede
spawnear pedazos y sacarse a sí mismo en otro momento del frame, o quedar vivo con otro modelo. El
pedido dice *«destruir»*, así que el camino que se mide es el suyo — a tiros — y no el `Remove()`
limpio del remover, que entra como segunda mitad para distinguir los dos caminos.

### ⚠⚠ Lo que **no** se escribió, y por qué está dicho en vez de tapado

**El segundo pedido del autor no tiene código en este commit.** Si sale verde no hace falta ninguno;
si sale rojo, el arreglo tiene **una segunda precondición sin medir** — si un `StopSound` sobre una
entidad *que se está yendo* llega a tiempo — y dos candidatos con costos distintos: un
`EntityRemoved` global (el addon no tiene ninguno, y correría por cada entidad que muere en el mapa) o
un `ent:CallOnRemove` acotado a los props a los que **nosotros** hicimos sonar. *Un arreglo cuyo
mecanismo no está medido es una hipótesis con forma de commit.*

Queda anotada también la parte chica y no audible: la poda del registro `SONANDO` corre **sólo cuando
alguien lo mira** (en `EV.prop`, en el `+USE` y en el reporte), así que quedan entradas inválidas
contadas hasta la lectura siguiente.

### ⭐⭐ El clic: los dos clips eran **estéreo**, y esta vez se vio **antes** de escribir la línea

    ui/button_toggle_1.ogg    0,23 s    44100    2 CANALES
    ui/button_toggle_2.ogg    0,35 s    44100    2 CANALES
    ui/button_click.ogg       0,30 s    44100    1 canal    ( ya era mono, y NO se usó )

**Source no espacializa un estéreo: lo tira en 2D.** Cableados como venían, el clic se habría oído
igual de fuerte en toda la casa y **no desde el objeto que apagaste** — que es exactamente lo que el
sonido viene a comunicar. Es el defecto que la r3 pagó en **quince archivos**, visto esta vez antes
del cableado y no después.

`button_click` ya era mono y habría costado cero, pero **suena distinto** y el autor eligió los
toggles de oído: la conveniencia técnica no decide por él. Queda ofrecida, diciendo que suena
diferente.

**El extractor se amplió, no se le pegó una lista.** `dev/mono_posicionales.py` saca sus rutas del
Lua; agregarle el banco del clic a mano habría sido *una medición vieja el día que alguien edita el
otro archivo*. Ahora lee dos fuentes (`PROP_CONSUJETO` y `CLIC_APAGADO`) e imprime **el denominador
por fuente**, que es el control de la trampa: tocar el extractor podía dejar de ver la tabla vieja sin
que nada avisara, y el script habría dicho *«ya están todas en mono»* — **el resultado exacto de no
haber mirado**. Tres defensas: la marca se busca con `str.index` (revienta, no devuelve vacío), una
fuente con cero rutas **aborta**, y el conteo va partido.

    PROP_CONSUJETO  30 rutas · CLIC_APAGADO 2 · TOTAL sin repetir 25 · ya mono 23 · estéreo 2
    re-lectura del disco:  1 canal y delta 0,000 s en los dos

**El backup es la única copia** (`sound/` está gitignoreado y una conversión a mono no se deshace):
verificado por sha256 **antes** de tocar, y comprobado después contra un `sha256` tomado por fuera del
script. Se le agregó una guarda: **un backup que ya existe no se pisa**.

⚠ **Hallazgo lateral del dedupe:** `PROP_CONSUJETO` cita **30 rutas pero son 23 distintas** — `dur` y
`sonidos` nombran los mismos clips desde el bloque del `+USE`. Sin dedupe, la próxima corrida habría
**re-encodeado dos veces** el mismo `.ogg` (una pérdida de calidad silenciosa) y habría inflado el
contador de convertidos. No pasó todavía porque cuando el script corrió en la r3 la tabla `dur` no
existía.

**El cableado, y dónde no va.** Una línea al final de `apagarCerca`, en el **único** desenlace que
apagó algo. El `+USE` tiene **cuatro salidas y tres no apagan nada** (`lejos`, `tarde`, y no haber
candidato); un clic en cualquiera de esas hace dos daños — le miente al jugador, que es lo contrario
de lo que el autor pidió, y **se come el control negativo de la planilla**, porque el que la corre oye
el clic desde el otro cuarto y marca verde sobre un filtro que nunca decidió. *Un instrumento que
confirma sin haber medido no es un instrumento: es un adorno que acredita.* Es la fila 04.

Dos decisiones más, con su motivo escrito: `sound.Play` en la **posición del objeto** y no `EmitSound`
sobre él, porque el sujeto puede ser un emisor nuestro que **acaba de dejar de existir** y un sonido
colgado de una entidad se va con ella — y así los dos casos (emisor nuestro y prop del mapa) salen por
la misma línea. La posición se guarda **antes** de borrar nada. Y el nivel es **60** y no los 75 del
resto: el que aprieta está a 128 u como mucho, y un clic que se oye desde el otro cuarto vuelve a ser
2D por otra puerta.

⚠ **Sin perilla, y el motivo va escrito:** es una **adición** y no un recorte, así que su ausencia se
distingue sola — el contador `apagados` dice cuántas veces tendría que haber sonado. *Un banco que se
achica necesita perilla; uno que crece, no.*

### ⭐ El celular que no era: `phone_vibrate` fuera de la familia teléfono

El autor: *«phone como prop horneado o phys son generalmente teléfonos fijos»*. Y los modelos que la
familia reclama le dan la razón — `oldphone`, `phone_motel`, el `phone` de `cs_office` son fijos. El
clip **no sonaba mal: sonaba a otro objeto.**

Dos líneas y un comentario. **El control ya existía y no hubo que inventarlo:** la guarda `( 3b )`
compara `sonidos` contra `dur` en las dos direcciones, así que sacarlo de una sola grita al cargar.

⚠ **La consecuencia va dicha en vez de descubrirse:** la familia queda con **un solo clip**, o sea que
un teléfono **siempre suena igual**. Con 3,46 s y un evento cada 25–90 s no molesta, pero el que abra
la tabla y vea una sola entrada tiene que poder distinguir *«falta algo»* de *«falta a propósito»*.

⚠ **El `.ogg` no se borró del disco** y eso también es a propósito: queda sin consumidor esperando un
smartphone de verdad. Lo que no puede pasar es lo del revés — **una ruta citada sin archivo enmudece
sin error**.

### ⚠⚠ Dos instrumentos nuevos y versionados, y uno de ellos casi da un falso verde

`dev/rutas_de_sonido.py` — las *«164 rutas de sonido citadas, 0 faltantes»* se citan en **cuatro
entradas de este changelog** y se rederivaban **a mano en cada ronda**. *Un número que sobrevive a su
instrumento es una frase que nadie puede refutar.* Ahora trae **denominador doble** (archivos leídos y
rutas distintas) y un auto-control que le pregunta por una ruta inventada. Hoy da **165**, y el delta
es exactamente lo que se tocó: **+2** del clic, **−1** de `phone_vibrate`.

`dev/guarda_3b_offline.py` — corre **la guarda de verdad** fuera de GMod: la **recorta del `.lua` y la
ejecuta** en un Lua real (`lupa`). No la reimplementa, porque dos copias de acuerdo entre sí no prueban
nada del código que corre. Y le **mueve la perilla**: rompe la tabla a propósito de una dirección por
vez (sacar el clip de `sonidos` dejando su `dur`, y al revés) y comprueba que grita en las dos. *Una
guarda callada puede estarlo porque la tabla está bien o porque no corrió, y las dos se ven igual.*

⚠⚠ **Y ese instrumento nuevo dio un falso verde en su primera versión, agarrado por mirar la salida y
no el veredicto.** El criterio era *«el mensaje dice `HUERFANA`»* — pero el `ErrorNoHalt` de la guarda
**nombra las dos categorías siempre**, lleve o no lleve algo cada lado (`SIN DURACION ( … ): ninguno ·
HUERFANAS ( … ): ninguna`). Así que **los dos casos rotos pasaban leyendo la misma palabra**: el
veredicto era correcto y el criterio no lo probaba. Se ve en que las dos filas imprimían **el mismo
texto**. El discriminante real es **de qué lado del `·` cae el clip**, y ahora se imprimen los dos
lados. Es el nº 42 del catálogo con otro disfraz: un control cuyo modo de falla lo satisface.

⚠ Y un defecto de lector, del mismo rato: buscar el `do` del bloque **como substring** lo encuentra
adentro de la primera palabra que lo contenga (`medido`, `cuando`, `direcciones`), y el recorte arranca
en la mitad de un comentario. El síntoma fue un **error de sintaxis de Lua que parecía del addon y era
del lector**.

### Los chequeos, todos corridos con el código de este bloque puesto

    luacheck                 36 / 36
    sintaxis real (lupa)     36 / 36     con su auto-control: discrimina
    returns de hooks          0 / 28     este bloque NO agrega hooks
    rutas de sonido          165 citadas, 0 faltantes   ( eran 164: +2 −1 )
    guarda 3b offline        callada, y grita en los 2 casos rotos a propósito
    duracion_ogg              4 / 4 valores previos reproducidos ( calibrado )
    largo de comandos        el más largo de la planilla mide 145 de 255

⚠ **SIN COMMITEAR, y por una razón que hay que leer antes de commitear:** otra sesión está editando
**el mismo `server_events.lua`** en paralelo ( el bloque de voz y cuerpo por tipo y por modelo de la entrada **42**, que se escribió mientras se
escribía éste: `dev/voz_y_modelo.py`, `server.lua`, `server_type.lua` y `ghost_models.lua` ). Sus cambios y los de este
bloque **conviven en el archivo** y ninguno pisó al otro, pero `git commit -- server_events.lua`
se llevaría su trabajo a medio hacer bajo este mensaje — que es exactamente la falla simétrica que
este repo ya pagó una vez, y esa vez llegó pusheada.

---

## 2026-08-17 (42) — **Cada fantasma con su cuerpo y su voz. La base sorteaba desde siempre y nuestro código le pasaba una lista de UNO; y la puerta que hacía cara la parte difícil resultó ser un `Initialize` que este addon nunca había escrito.**

Tres cabos del `dev/PROMPT_fantasmas_sexo_modelo_y_voz.txt`. Detalle completo en
`dev/HANDOFF_fantasmas_male_oldcrone.md` §R7.

### ✅ PASADA EN JUEGO EL MISMO DÍA — 7 de 14 filas PASAN, y la cadena de la voz cerró en las DOS direcciones

(4 quedan a medias, 1 se retiró como criterio y 2 siguen sin correr. El desglose sale de contar la tabla, no
de una cuenta a mano — la primera versión de esta línea decía «5 de 12» y estaba mal en las dos mitades.)

⭐ **El par que cierra la prioridad, y las dos mitades salieron de UNA sola tanda**, con
`phantasmagoria_bot_modelo ghost_male` —cuerpo fijo, filtro apagado porque el pool es de uno— y tipos al azar:

    tipo que NO fija la voz  +  cuerpo de hombre  ->  voz 2 ( grave )     <- manda el MODELO
    banshee                  +  cuerpo de hombre  ->  voz 1 ( femenina )  <- manda el TIPO

Con el cuerpo constante, lo único que cambia entre las dos líneas es el tipo: el cambio de voz **no puede
atribuirse al modelo ni a la moneda**. Cualquiera de las dos sola habría sido compatible con la hipótesis
contraria; el par no. Diez ejemplos.

⚠ Y que esto se pudiera medir **depende de una decisión tomada por otro motivo**: que la perilla le gane al
sorteo y al filtro. Se escribió para que las filas del hull siguieran corriéndose, y terminó siendo la
única puerta al estado —banshee con cuerpo de hombre— que este mismo bloque vuelve imposible por todos los
otros caminos.

### ⚠ Y LA PASADA DESTAPÓ UN DEFECTO QUE NINGUNA RELECTURA HABÍA VISTO: la voz sobrevivía al cambio de tipo

`phantasmagoria_ghost_type banshee` sobre un fantasma **vivo que ya había hablado** le cambiaba el tipo y
**no** la voz: `phantom_EventVoice()` cachea en `phantom_evVoice` y nada la invalidaba. El resultado es el
estado que la fuente prohíbe — un *"Can only be female"* hablando grave — producido **por la perilla que
existe para probar justamente eso**. Catálogo nº 26: *una perilla que no alcanza a los sujetos que ya
existen se lee como «el mecanismo no existe», que es la conclusión inversa a la verdadera.*

Arreglado con `ENT:phantom_ResetVoice()`, colgado de la **puerta única** (`phantom_SetType`) al lado de
`phantom_ApplyTypeSpeed` y por el mismo motivo: SetType tiene dos entradas y `ResolveType` sólo cubre una.
En el spawn no hace nada — la voz todavía no se resolvió — y el descarte **se dice por consola**, porque un
cambio silencioso en algo que el jugador oye es indistinguible de un bug.

No rompe la decisión de la r2: la voz se sigue sorteando UNA vez por fantasma. Lo que se agrega es que un
cambio en **la entrada que la decide** la vuelva a resolver, que es lo contrario de sortear clip por clip.

El arnés pasa a **53 comprobaciones** con un cuarto defecto reinyectable (`--romper revoz`) y un grupo G.

⭐ **Y el arnés auditó al que lo escribió**: `orden` se declaró tiñendo sólo el grupo E, el arnés contestó
*«EL CONTROL SE PASA: G se puso rojo y ese defecto no lo toca»* — y **tenía razón el arnés**: la fila de G
comprueba que un banshee vivo pase a voz 1, o sea que depende del mismo orden de prioridad. El error estaba
en el alcance declarado. *La mitad del control que pide DÓNDE también audita al que la escribe.*

También cerró **08b** (el tipo cambia en fantasmas vivos ⇒ la key pre-elegida se consume y se borra) y la
mitad del Male de la fila **11**: `ph_ghost_facing` dio **85,0 y 85,5** contra los **85,5 predichos offline**
desde el SMD por `ghostbrazo_off.py`, sin el motor. Y la segunda corrida marcó `manos 23,53 u`: con el umbral
viejo de la nena (25,23 × 0,9 = 22,70) **la alarma falsa habría saltado**, y con el del Male (43,49 × 0,9 =
39,14) no salta. El falso positivo que la entrada nº 50 predijo se reprodujo en vivo y quedó suprimido.

Planilla: **7 de 14 PASAN**, 4 a medias, 1 retirada, 2 sin correr.

    fila 01   variedad de modelo   3 spawns, 3 modelos distintos ( y otra tanda igual )
    fila 04   el filtro tipo -> cuerpo   `ghost_type banshee` + 20 spawns, NI UNO el Male
    fila 10   hull y malla por modelo    44.94/20x20x45 · 72.29/32x32x72 · 68.98/30x30x69

La **04** cierra con margen: bajo la hipótesis nula —sin filtro, sorteo uniforme sobre tres— veinte
spawns sin un solo Male tienen probabilidad `(2/3)²⁰ ≈ 3 en 10.000`. Y arrastra un corolario que no
hay que volver a medir: **el filtro sólo se dispara si la pre-elección del tipo corrió**, o sea que el
`ENT:Initialize()` nuevo —el que corre ANTES de que la base sortee el modelo— funciona en juego.

La **10** son las filas 01-03 de §R6.4, del bloque anterior, que **nunca se habían corrido**. Los tres
números dan exactamente lo calculado offline, con la nena —el control que NO tenía que cambiar—
idéntica a lo que corrió las 22 rondas. Y un segundo cálculo, de otra parte del código, que tenía que
concordar y concuerda: la columna de ojos da **40 · 64 · 61** = `round( alto − (alto/72)·8 )` para los
tres altos.

### ⚠ Y EL HALLAZGO DE MÉTODO: EL ARREGLO DEL CABO 3 DEJÓ SIN PODER FALLAR A LA FILA DEL CABO 2

La fila que probaba la prioridad decía *«forzar un Banshee y oírlo femenino, porque el TIPO manda
sobre el modelo»*. Era discriminante cuando se escribió —con el modelo suelto, «manda el tipo» daba
voz 1 y «manda el modelo» daba voz 2— y **el filtro del cabo 3 la mató**: garantiza que todo Banshee
salga con cuerpo femenino, o sea voz 1 **también por modelo**. Las dos hipótesis predicen lo mismo y
la fila sale verde **con el orden invertido**.

La fila describe bien el mecanismo, cita bien la fuente y pasa; lo único que perdió es la capacidad
de salir roja. El arreglo es de la FILA: el estado que hace falta —un Banshee con cuerpo de hombre—
sigue siendo alcanzable **porque la perilla le gana al filtro** (`bot_modelo ghost_male` deja el pool
en uno). Queda como fila **05b**, y la vieja pasa a **dato anotado y no criterio de PASA**.

*Cuando un bloque agrega una restricción, la pregunta no es sólo qué filas nuevas hacen falta sino
**qué filas viejas dejaron de poder alcanzar su caso**.* Catálogo de controles, entrada 61.

**Lo que falta**: 05b (la única que prueba el orden de prioridad), 02, 03, 06/07 con su `por:`, 08b y
09, más las filas 04-07 de §R6.4. Planilla completa en §R7.5.

### Lo que se midió

    dev/voz_y_modelo.py       46 comprobaciones, 0 fallas
                              --romper pool   -> 6 rojas, grupos B+D   ( y sólo B+D )
                              --romper orden  -> 2 rojas, grupo  E     ( y sólo E )
                              --romper filtro -> 2 rojas, grupo  D     ( y sólo D )
    dev/hull_por_modelo.py    11/11, sin cambios: el bloque de la r6 sigue en pie
    dev/luacheck_gmod.py      4 archivos OK, con sus dos controles versionados en la MISMA pasada
                              ( _roto.lua FALLA · _sano.lua OK )
    dev/auditar_returns_de_hooks.py   0 de 28 hook.Add con return fuera de la API

El arnés carga **los 30 tipos de verdad**, fusionados por su propio `AplicarRasgosDeEvento`: cuando
dice *«dos de los treinta fijan la voz»* está contando los treinta y no una maqueta mía.

### Los tres cabos

**El cuerpo por fantasma.** `terminator_nextbot/shared.lua:2971` sortea un modelo de `ENT.Models`
**en cada instancia** — o sea que la variedad existía y lo que la apagaba era
`CLASE.Models = { chosen.mdl }`, una lista de un elemento. Ahora va el pool de los modelos del taller
montados. ⚠ **Con `phantasmagoria_bot_modelo` puesta la lista sigue siendo de UNO**: las filas 01-04
del hull (§R6.4) fuerzan un modelo y leen la línea del spawn, y un sorteo que le gane a la perilla las
convierte en *«a veces sale el que pediste»* — con lo que se cae el único control que ese bloque
tiene, **y ese bloque todavía no se corrió en juego**.

**El sexo del modelo.** Campo `voz` en `ghost_models.lua` (1 femenina · 2 grave), al lado de `altura`
y `reposoBrazo`, que es la única casa de lo propio de cada modelo. No es un número libre: es **el
índice del archivo** en el catálogo de sonido. La nena y la vieja comparten banco, **preguntado al
autor antes de escribir nada**: en Phasmophobia la voz no se diferencia por edad, y el único tipo que
envejece (Thaye) lo demuestra con sus acciones.

**La prioridad tipo > modelo > sorteo**, en `phantom_EventVoice()`. Al revés, un Banshee con el cuerpo
del Male hablaría grave, que es justo lo que la fuente prohíbe.

### Tres cosas que valen fuera de este bloque

⚠ **Los dos eslabones usan el MISMO campo, y por eso no hay nada que sincronizar.** El rasgo `voice`
del tipo y el campo `voz` del modelo valen 1 o 2 con el mismo significado, porque salen de la misma
frase de la fuente (*"Can only be female, ghost model and ghost name will reflect this"*). Un tipo que
mañana fije la voz 2 filtra el cuerpo solo, sin tocar una línea. *Un segundo dato que hay que mantener
de acuerdo con el primero es el que se desincroniza.*

⚠ **La invariante que el prompt no nombró: `esNuestroModelo`, `IdleActivity*` y `ModelSkin` son de la
CLASE y el sorteo es por INSTANCIA.** Un pool mezclado le aplicaría a un modelo ajeno las correcciones
del nuestro — la regresión del `1a16191` dada vuelta. El pool se arma sólo con los `nuestro`, y **el
que queda afuera se dice**: «salen menos modelos de los que hay» y «ese modelo no está montado» se
leen igual en una consola muda.

⚠ **Y una medición que corrigió al encargo: una lista vacía no da «otra cosa», TIRA.** El prompt decía
que `models[ math.random( 0 ) ]` devolvía algo raro; `math.random( 0 )` levanta *"interval is empty"*
adentro del `Initialize` de la base — antes de que el fantasma exista — y **sólo en el camino que
corre en las máquinas de otros**, porque un clon limpio no tiene los `.mdl`. Por eso el pool cae a UNO
cuando no hay ninguno del taller montado.

### El cabo 3, que se creía caro y no lo era

Que un `banshee` no salga con el cuerpo del Male exigía elegir el tipo **antes** que el modelo, y el
prompt daba por sospechosas las dos salidas que veía (pisar el modelo con `SetModel` después, o mover
`phantom_ResolveType` entero). Hay una tercera: la base elige el modelo **adentro de su propio
`Initialize`** (`shared.lua:2913`, sorteo en `:2971`), y **este addon no tenía un `Initialize` propio**
— cero definiciones en los 13 archivos de la entidad. Ahora lo tiene, escribe `self.Models` filtrado
en la tabla de la **instancia** y recién después encadena. No hay `SetModel` a posteriori y el hull de
la r6 no se toca.

Lo único que se adelanta es el **sorteo** del tipo: `phantom_PreelegirTipo()` guarda la key y
`phantom_ResolveType` **la consume y la borra**, en su lugar de siempre. ⚠ Si quedara guardada,
`phantasmagoria_ghost_type auto` sobre un fantasma vivo le devolvería el mismo tipo para siempre:
*una caché de una decisión es una decisión que ya no se puede volver a tomar.* Y `typeassign 0` sigue
siendo el control negativo que era — sin tipo no hay filtro.

### Del arnés

⚠ **Su `--romper` no pide sólo que haya rojo: pide rojo EN SUS FILAS**, y falla si un defecto tiñe un
grupo que no le toca. Un arnés que se cae entero ante cualquier cambio acredita igual que uno flojo.

⚠ **Y una regla que se cobró escribiéndolo:** `ghost_types.lua` termina en `return
PHANTASMAGORIA.Types`, un return de **archivo**. Concatenado con los otros bloques, ese return corta
el chunk y todo lo que sigue no se carga — y si lo que queda colgado da la casualidad de ser
sintácticamente válido, el arnés corre la mitad de los bloques y **cuenta verde igual**. Cada trozo se
ejecuta como su propio chunk, que es lo que hace GMod entre archivos.

---

## 2026-08-17 (41) — **`+USE` apaga la radio, la radio suena entera, y las llaves se mudan a una puerta con pestillo. El corte que se saca decapitaba 6 de 6, y sacarlo sin el interruptor habría sido un defecto y no un arreglo.**

Tres pedidos del autor, textuales, que él llamó *«minúsculos»*. **Dos lo son.**

### ✅ CERRADO EN JUEGO EL MISMO DÍA — 13 de 13, sin una falla

`dev/checks/phantasmagoria-use-y-llaves.html` corrió entera, incluidas las **cuatro filas del bloque
anterior que habían quedado sin correr** (las perillas en `0` las hicieron medibles hoy). El autor:
*«en cuanto a comportamiento todo bien»*. Los números que cierran cada mecanismo:

    +USE          teclas 24 · apagados 2 · lejos 15 · tarde 5
    emisores      vivos 4 = conteo real 4 durante los clips · vivos 0 = 0 en reposo · creados 38
    salteados     83   ( el barrido no se cuenta a sí mismo )
    censo         418 / 1588 y 8 modelos / 11 instancias, igual que el .py
    llaves        con la convar en 0 suenan; en 1 sale `NO SALIO / sin sujeto -- ...` y NO se oye nada

El `lejos 15` es el que hace valer al `apagados 2`: sin él, *«se apagó»* no distingue el mecanismo de
un clip que se terminaba solo. Y el `vivos 4 = 4` con **cuatro relojes a la vez** es la prueba de que
el registro cuenta también a los emisores **no apagables** — si sólo hubiera guardado los del `+USE`,
la fila de la fuga habría dicho `0` con cuatro emisores vivos en el mapa.

⚠ **TRES FILAS DIERON EL VEREDICTO CORRECTO SIN PROBARLO ELLAS SOLAS, y eso se anota en vez de
cobrarse el verde entero.** Vale distinguir *el veredicto es correcto* de *la fila lo probó*:

- **A1** predecía `( 3 familia(s) con sujeto )` desde el `.bsp` y salió **4**. Por el criterio literal
  era rojo; no lo es: la predicción estaba atada a **(−512 −425 272)** y el fantasma spawneó a
  **(−609 −291 224)**, a ~150 u, con lo que entra una cuarta familia al radio de 450 u. *Una
  predicción calculada para una posición no es una predicción para la habitación* — el número que la
  fila tenía que comparar debía salir del censo **en la posición real**, no de una constante escrita.
- **A3** pedía dos mitades (gana el `prop_physics`, borrado gana el horneado) y la corrida trajo la
  primera. La segunda la sostiene **A1**, donde la radio y el teléfono horneados salieron nombrados
  sin ningún prop real cerca.
- **00** pedía seis pulsaciones en dos escenas y trajo dos, las dos **`mirando worldspawn`** — que es
  justo la mitad rara, la que decide. La otra la sostiene el `teclas 24` de la fila 02.

⚠ Y una que no es de este bloque pero quedó a la vista: el hook de prueba `pruebaUse` **no aparece
removido** en el registro de la corrida. Muere solo al cambiar de mapa, pero mientras viva imprime una
línea por cada `E` de la sesión.

### ⭐⭐ El corte de la radio no era un caso borde: decapitaba **6 de 6**

`largo = { 6, 14 }` contra clips de **26,78 a 60,78 s**. No había *un* clip de la familia que alcanzara
a terminar. Y el final es la parte que importa: medido con planitud espectral, tres de los cuatro clips
principales **terminan en ruido de banda ancha** —la estática y el apagado— mientras el corte caía
siempre en el medio tonal. O sea que `StopSound` se comía el apagado, y la promesa escrita en el propio
código —*«un radioruido que arranca y para solo es lo que hace una radio poseída»*— se cumplía a medias
**desde el día que se escribió**.

Las seis duraciones salen de `dev/duracion_ogg.py`, que es un instrumento nuevo y **versionado**:
lee el `granule` del último page Ogg y el samplerate del header Vorbis, y trae su **auto-control** —
remide los cuatro clips que ya estaban medidos con otra herramienta y **reproduce a 0,004 s**. Sin ese
control, un lector recién escrito imprime números plausibles sobre cualquier cosa. Los dos nuevos:

    creepy_music 33,71 · creepy_music_old 26,78 · creepy_music_slowdown 42,23
    creepy_montage 41,41 · creepy_radio_easteregg_helpmewithend 60,78 · ritual_chanting_loop 32,75

De yapa el instrumento cuenta canales, y confirma que **los seis son mono** — que es la precondición de
que suenen *desde* el objeto. Y su verdicto se **niega a decir OK** si en la corrida no entró ningún
clip de control: dice `PARCIAL`. Una corrida sin calibrar publicando números es la nº 14 del catálogo.

### ⭐⭐⭐ Sacar el corte y poner el interruptor son **UN SOLO CAMBIO**

Sin corte y sin interruptor, un clip de 60,78 s se solapa con el evento siguiente — que es **literal el
defecto que la r3 pagó** y el motivo por el que `largo` existía. Por eso las dos mitades entran juntas.

Las dos vías obvias para el `+USE` estaban **las dos** cerradas, y por motivos distintos: `PlayerUse`
sobre el prop no existe (**un `prop_static` no es una entidad**) y `PlayerUse` sobre el emisor tampoco
(**es un `info_target` sin modelo ni colisión**, así que el trace de uso no le pega). Queda `KeyPress`
con `IN_USE` en el servidor, resuelto a mano contra un registro. El addon **no tenía ningún**
`hook.Add( "KeyPress" )` — medido, 0 en los 36 `.lua`.

⚠ **El hook no devuelve nada, nunca.** `hook.Call` aborta la cadena con cualquier valor, y de `E`
cuelgan abrir puertas, agarrar props y entrar a vehículos, nuestros y de terceros. Este taller ya pagó
eso dos veces (`Corpus.OnReady`, y el `return` de `PlayerSpawn` que se saltea `GM:PlayerSpawn` entero).
`dev/auditar_returns_de_hooks.py` **aprendió a nombrarlo**: `KeyPress` y `KeyRelease` entran en
`RETORNO_ES_DEFECTO`, porque sin la entrada el hook nuevo caía en `revisar` y el auditor no podía
nombrar el defecto que existe para detectar.

El criterio de «cerca» es una **decisión y no un número suelto**: **sólo distancia, sin mirada**. Pedir
que le apunten pierde porque **el objeto es invisible** — no hay nada a que apuntar, y sería una
lotería y no realismo. 128 u, o sea entrar al cuarto.

### ⭐ La segunda mitad que se olvida: **borrar el emisor también decapita**

Una entidad que se va se lleva su canal, así que un emisor que muere a los 20 s corta un clip de 33
por la otra puerta — y la línea del reporte seguiría diciendo `ENTERO`. Ahora la vida del emisor sale
de la duración medida más un margen, y **la duración vive al lado del clip**: *una constante que decide
comportamiento tiene que existir una vez*. Con su guarda de carga, que mira **las dos direcciones** —
un clip sin duración (que decapitaría en silencio) y una duración huérfana (que es una nota mentirosa
esperando lector).

### ⭐ La trampa 3 se disolvió por construcción en vez de parchearse

`EMISORES.vivos` se descontaba en un `timer.Simple( vida + 0.5 )`. Con el `+USE` borrando el emisor a
los dos segundos, **ese timer iba a correr igual** y a descontar de un contador que ya no tenía a quién
contar: el número se habría separado del conteo real del mapa y **la fila de la fuga habría salido roja
sin que hubiera fuga**. Hoy `vivos` se **deriva** del registro al leerlo. Un contador que se calcula no
se puede desincronizar, porque no hay dos escrituras que puedan quedar en desacuerdo. El conteo real de
entidades sigue imprimiéndose al lado: derivar uno no vuelve redundante al otro, lo vuelve comparable.

### Las llaves: no se borran, se mudan

`SND.prop` son ocho clips y **los ocho son llaves** de verdad (las dos que no lo eran eran el
presentador británico, y se fueron en la r3). No suenan mal: suenan **donde no corresponde**. Con
`phantasmagoria_ghost_evllaves 1`, sin ninguna familia con sujeto el evento `prop` **no suena** y sale
por el camino `return false` **que el código ya tenía**, o sea que la bitácora sigue imprimiendo
`SIN SUJETO -- <motivo>`. ⚠ Eso no es un detalle: si el evento se volviera mudo, la fila del control
negativo **no podría distinguir «no había sujeto» de «el evento no corrió»**.

Y aparecen donde sí hay: el evento de puertas puede **trabar** una puerta cerrada con `Fire( "Lock" )`
y ahí suenan las `key_lock_*`; el **destrabado que ya existía** (`server_doors.lua:1036`, desde la
ronda de las puertas) deja de ser **mudo** y suena `key_unlock_*`. Los ocho clips se declaran ahora en
tres bancos y `SND.prop` se arma con ellos, para que agregar un `key_lock_4` no entre en un solo lado.

⚠ **Que `Fire( "Lock" )` funcione sobre las clases de este mapa NO está medido**: el engine es un
tercero y `Entity:Fire` con un input que la clase no acepta **no tira error** — `AcceptInput` devuelve
false en silencio. Por eso el código **relee `m_bLocked` un tick después** y la bitácora dice
`pestillo CONFIRMADO` o `pestillo SIN EFECTO`.

⚠⚠ **Trabar una puerta es una mecánica con consecuencia y no un sonido**: si el bot traba la única
salida de un cuarto, eso no es un susto, es un softlock. Los tres límites están puestos **antes de la
primera corrida**: tope de **2** a la vez, **45 s** de vida, y `phantasmagoria_ghost_pestillo soltar`.
Y no se traba una puerta **que ya venía trabada**: sin esa regla, el mecanismo «trabar puertas»
terminaría **destrabando el mapa**, porque a los 45 s soltaría un pestillo que no era suyo.

### Lo que el teléfono no es

El autor pidió el `+USE` para *«las radios y teléfonos»*. Medido: `phone_ring` **3,46 s** y
`phone_vibrate` **1,11 s** — esa familia **nunca se cortó** porque nunca hizo falta. El interruptor le
entra igual (mismo mecanismo, cuesta cero) **pero no resuelve ningún síntoma**, y por eso **no hay
ninguna fila que pida apagar un teléfono**: *una fila que sólo se puede aprobar con reflejos no mide el
mecanismo, mide al que la corre.* El sujeto de verdad del bloque es la radio.

### La planilla lleva las cuatro filas que el bloque anterior no corrió

Y **las tres perillas nuevas existen para que se puedan correr hoy**: puestas en 0, el motor se comporta
exactamente como antes de este bloque. Lo único que no tiene control es que la radio ahora suena entera
— dicho en el encabezado, con el argumento de por qué ninguna de esas cuatro filas lo mide.

⚠ **Frontera con nombre:** `ritual_chanting_loop` es un **loop**. Entró a la familia en la r3 con el
argumento de que *«un loop cortado se oye como una radio que arranca y para»* — cierto cuando había
corte, y **sin sostener ahora que no lo hay**. No se saca (lo pidió el autor por su nombre), pero la
fila de «la radio suena entera» no se corre con él.

### Lo que el cierre deja pedido para el bloque siguiente

Tres cosas, textuales del autor, **ninguna escrita en esta ronda**:

1. Que apretar `+USE` sobre el horneado o el `prop_physics` **emita un sonido de botón**, para que el
   jugador sepa que apagó algo. Candidatos suyos: `ui/button_toggle_1` y `_2`, *«ambos suenan como
   apretar un interruptor sutil»*. ⚠ **Los dos son ESTÉREO** (medido hoy con `dev/duracion_ogg.py`:
   0,23 s y 0,35 s, **2 canales**), así que van a sonar **planos y en 2D** — Source no espacializa un
   estéreo. Pasan por `dev/mono_posicionales.py` **antes** de cablearse, o el bloque repite en silencio
   el defecto que la r3 pagó en quince archivos.
2. Que al **destruir** un `prop_physics` que está sonando (la radio de cs_office, el teléfono) **el
   sonido pare**. Hoy el registro poda por entidad inválida, pero la poda sólo corre cuando alguien
   mira el registro: hace falta el camino del borrado.
3. **Sacar `phone_vibrate.ogg` de la familia teléfono.** El autor: *«corresponde a un celular; `phone`
   como prop horneado o phys son generalmente teléfonos fijos, así que `phone_ring.ogg` está bien»*.
   Es el mismo criterio que mudó las alarmas de auto en la r1: *el sonido tiene que nombrar al objeto
   que está ahí.*

**Verificación offline:** `luacheck 36/36` · `sintaxis 36/36` (lupa, un Lua real) ·
`auditar_returns_de_hooks 0 de 28` (el `KeyPress` nuevo ya en el denominador) · **164 rutas de sonido
citadas, 0 faltantes en disco** · `dev/duracion_ogg.py` reproduce 4 de 4 valores previos. Y el
generador de la planilla estrena su **guarda de largo de 255**, con su propio auto-control: mide los 19
comandos de las trece filas (el más largo, **154**) y se probó que **puede ponerse roja**, tanto sobre
el comando principal como sobre los que viven adentro de una nota. En la corrida real **ninguna línea
se truncó**, que era lo que la guarda existía para evitar.

## 2026-08-17 (40) — **Tres constantes de la nena leídas para los tres modelos: el hull, el alto de malla y la pose de reposo. Y el camino que el plan elegía para la pose del brazo NO PUEDE arreglarla.**

Dos cabos del `dev/PROMPT_fantasmas_r6.txt`. El primero es una regresión y está cerrado offline; el
segundo era una compuerta que pedía una pasada en juego, y se contestó **calculándola**.

### ⭐ El hull de los adultos era el de la nena — y el número ya existía en el addon

En juego, con la OldCrone: `spawn #442 hull 20x20x45 malla 44.94 de alto`. Los dos números son de la
nena. A un cuerpo de **68,98 u** se le puso una caja de **45** —le cubre el 65 %— y la línea de
diagnóstico afirmaba un alto de malla que no era el de ese modelo.

**Cómo llegó, que es la parte que vale.** Hasta el `1a16191` el flag `esNuestroModelo` decía *«es la
nena»*, así que los adultos corrían con el 32x32x72 de la base: mal, pero de otra manera. Al arreglar
ese flag —y había que arreglarlo, apagaba también las actividades— el hull de la nena pasó a los tres.
*Un arreglo correcto puede destapar una constante escondida detrás del defecto que arregló.*

Y el remate: **`lua/phantasmagoria/ghost_models.lua` ya tenía `altura` medida por modelo desde el
2026-08-10**. Los `local HULL_ALTO / HULL_ANCHO / MALLA_ALTO` eran una **segunda casa** para un número
que decide geometría. Ahora hay una sola, y se consulta **en el spawn** y no al cargar el archivo: que
ese autorun compartido haya corrido antes que la entidad no está garantizado en ningún lado.

La regla es una y vale para cualquier modelo del taller — el alto es la altura medida, el ancho se
escala con el mismo factor `altura / 72` que ya producía el 20x20x45:

    modelo            altura   hull
    ghost_girl        44,94    20x20x45   <- IDÉNTICO a lo que ya corría
    ghost_male        72,29    32x32x72
    ghost_oldcrone    68,98    30x30x69

Las tres alturas se **remidieron hoy** con `vvdbounds.py` sobre los `.vvd` **montados** y reproducen
(44,941 · 72,291 · 68,979). El ancho sigue sin salir de la malla y eso no cambió: los bbox en X de los
tres (30,4 / 51,9 / 42,5) están dominados por los brazos de la pose de reposo. Lo que sí se mira es que
la relación no se descoloque: `bbox_X / ancho del hull` da **1,52 / 1,62 / 1,42**.

El comentario del Male decía que *«el hull de la base le entra sin tocar nada»*. Era una hipótesis
escrita; ahora es un resultado: la regla, aplicada a su 72,29, devuelve 32x32x72 exactamente. **La
predicción se cumplió, pero el número no sale de la predicción.**

**Verificación**, sin poder cargar el archivo (`luaharness` no construye este sujeto, §R5.3):
`dev/hull_por_modelo.py` ejecuta el bloque **REAL** —`hullDelModelo()` extraído del server y el
registro entero— y da **11/11**, con los degenerados de fábrica (GetModel nil y vacío, modelo fuera del
registro, ficha sin `altura`, y **el registro NO cargado**, que tiene que devolver nil y no tirar). Su
control negativo `--romper` reinyecta el defecto y el arnés se pone rojo **con la nena en verde** y los
dos adultos en rojo: exactamente como se comportó la regresión de verdad, y por eso nadie la vio.

### ⭐⭐ La compuerta del cabo 2 se contestó SIN el motor — y refutó el camino que el plan elegía

El prompt pedía correr `ph_ghost_facing` con el Male y la nena antes de tocar `mdlseq2smd.py`. Ese
número —`brazo izq, MÁXIMO de la ventana`— es geometría pura: la posición de dos huesos y el eje
vertical. **Se calcula del `.smd` que se compiló**, y el ángulo contra Z es invariante a todo yaw, que
es lo único que el archivo no sabe.

`dev/phastools/ghostbrazo_off.py` lo hace, y trae **dos controles de distinta fuente**:

    CONTROL 1  reproducir las constantes que el instrumento publica ( otra ronda, otro camino )
               brazo 46,53 contra 46,50 publicado · manos 25,23 contra 25,23
    CONTROL 2  reproducir el número que la OldCrone dio EN JUEGO
               run_n calculado 119,2 gr  contra  119,0 gr medidos   dif 0,2

Con eso, la compuerta:

    modelo            walk_n    run_n     idle     veredicto del autor
    ghost_girl          48,7     65,9     33,8     CERRADA en juego, 22 rondas
    ghost_male          56,3     85,5     46,9     «luce perfecto»
    ghost_oldcrone      65,4    119,2     48,8     «las manos a la altura de la cara»

**No dan lo mismo, y ordenan igual que los tres veredictos del autor.** El mecanismo está confirmado.

### ⭐⭐ Pero el camino (A) del plan multiplica por la identidad

El plan era conjugar en `mdlseq2smd.py` (`A_nuestra = L_nuestra · inv(L_hl2) · A_hl2`) en vez de copiar
crudo. `dev/phastools/ghostretarget_off.py` lo **simula sobre los SMD que ya están en disco**, sin tocar
la herramienta ni recompilar:

    brazo izq MÁXIMO, run_n       HOY    con (A)   HL2 en su rig
    ghost_girl                   65,9      65,9        52,9
    ghost_male                   85,5      85,6        52,9
    ghost_oldcrone              119,2     119,3        52,9

No mueve nada. Y la causa se midió en vez de discutirse, separando las **dos** cosas que un reposo puede
tener distintas:

    cadena del brazo izq    reposo: ROTACIÓN      reposo: DIRECCIÓN DEL HIJO
                            ( la arregla A )       ( no la arregla A )
    ghost_girl                0,1 · 0,4 · 0,0         9,3 · 4,1 · 25,7
    ghost_male                0,1 · 0,4 · 0,0         2,0 · 15,2 · 23,3
    ghost_oldcrone            0,1 · 0,4 · 0,0        27,9 · 8,4 · 48,2

**Los dos reposos ya tienen la misma rotación local**, así que `L_nuestra · inv(L_hl2)` ES la identidad.
Lo que difiere es **dónde está el hijo** en el marco del padre, y la dirección de un miembro es `R · p`:
la conjugación corrige la `R` y el error vive en la `p`. La segunda columna reproduce exacto la tabla de
`ghostpose_off.py`, que era la evidencia del mecanismo — o sea que **la evidencia era correcta y el
arreglo que se le adjudicó no la toca.**

El control que lo hace creíble es `--identidad`: conjugar usando `L_hl2` de los dos lados tiene que dar
lo de hoy, y da **dif 0,0000** en los tres. Un orden de multiplicación invertido o una transpuesta de
más habrían dado un número plausible igual.

El único camino que alcanza esa magnitud es **(B)**: girar el **marco local** de esos huesos con
`smdreorient.py` —que es el arreglo de los dedos un nivel más arriba— porque girar el marco **sí**
cambia la `p` del hijo sin mover nada en el mundo, y ese es su invariante. Toca el esqueleto: bloque
propio.

### El instrumento de la compuerta publicaba dos constantes de la nena, y una era un umbral

`ph_ghost_facing` tenía `REPOSO_BRAZO, REPOSO_MANOS = 46.5, 25.23` clavados e impresos para cualquier
modelo — el mismo defecto que el `MALLA_ALTO` del server, pero adentro del instrumento. Y uno de los dos
no es decorativo: `pareceReposo` compara `manosMax > REPOSO_MANOS * 0.9`, y **el Male tiene las manos a
43,49 u en su propio reposo**. Con el umbral de la nena (22,7) el ⭐ *«EL CUERPO ESTÁ DIBUJADO EN LA POSE
DE REPOSO»* se prende solo sobre un Male sano: *un control que fabrica el síntoma que busca*, y justo
sobre los dos modelos que están por probarse por primera vez.

Ahora salen de la ficha (`reposoBrazo` / `reposoManos`), medidos de una sola corrida:

    modelo            brazo vs vertical   manos separadas
    ghost_girl              46,53 gr           25,23 u
    ghost_male              56,56 gr           43,49 u
    ghost_oldcrone          53,85 gr           36,91 u

Y si la ficha no los trae, la comparación **no se hace** y se dice: `false` habría afirmado *«no parece
reposo»*, que es una conclusión que nadie midió.

### La falda tiesa: NO es un defecto, y ya estaba medido

Los pesos del material `clothes` siguen a las piernas (ruedo a pies y gemelos, cintura al `Pelvis`). Lo
que no puede hacer es moverse por inercia: Source no simula tela, eso pide `$jigglebone` y **huesos de
falda que el rig no tiene**. Bloque propio, y no se tocó nada.

### Lo que falta

La pasada en juego: spawnear los tres y leer la línea del spawn (`hull` y `malla` tienen que ser los de
cada uno), y `ph_ghost_facing` con el Male y la nena para confirmar los 65,9 y 85,5 predichos — la
OldCrone ya confirmó su 119 a 0,2 gr.

---

## 2026-08-17 (39) — **Los props HORNEADOS del mapa suenan. Un emisor invisible y sin modelo, y el jugador le atribuye el sonido al prop que hay al lado.**

La pregunta del autor era *«algunos modelos están baked en el mapa, me pregunto si serán posibles de
tomar?»*. Como entidades **no**: `ents.FindByClass( "prop_static" )` devuelve vacío y tiene cero call
sites en los 70 addons del taller. Se leen del `.bsp`, y ahora se leen.

### ⭐⭐ Las dos precondiciones del engine, medidas en juego antes de escribir una línea

**P1 — el `.bsp` se abre y se lee estando el mapa adentro de un `.gma`.** StormFox2 hace el mismo
`file.Open` pero sobre mapas sueltos; que el sistema de archivos virtual lo exponga por `maps/` cuando
viaja adentro de `gmpublisher.gma` era otra afirmación. Verde, y con **cuatro** mitades porque *abrir
no es leer*: `size=340212229 · magic=VBSP · vbsp=20 · lectura profunda 4/4 bytes`. La cuarta es la que
no se podía saltear — un handle que abre y no deja leer hondo hubiera sido un falso verde, y el parser
vive de `Seek`.

**P2 — el emisor.** Un `prop_static` no tiene entidad, y todo el evento emite con `ent:EmitSound` y
corta con `ent:StopSound`. `sound.Play` no sirve: no devuelve nada que se pueda apagar, y `clock_tick`
dura **46,55 s**. Verde las tres — se oye · suena desde ahí · `StopSound` lo corta — **y la segunda
pasó más fuerte que su criterio**: con un `info_target` invisible y sin modelo puesto en la radio, el
autor localizó el tic-tac y se lo adjudicó **al reloj horneado que hay a 29 u**. *El jugador ubica el
sonido por dirección y por plausibilidad del objeto*, así que alcanza la opción barata y el emisor
tiene que ir en la posición del prop que matcheó.

### ⚠⚠ La consola de Source corta en 255 caracteres, y el síntoma es un error de sintaxis de Lua

La primera versión de la línea de P1 medía **559**. Entraron 255, se perdieron 304, y lo que llegó fue
`'<name>' expected near '<eof>'` — o sea un rojo que parece del código y es **del transporte**. Y el
control no podía verlo: **compilar la línea no mide su largo**, y un prefijo truncado compila entero
antes de truncarse. De los cinco comandos generados, tres pasaban de 255 y el chequeo les dio verde.
Ahora el generador de la planilla mide el largo, y su guarda se probó con una inyección real.

### ⚠ El auto-control que se copió del `.py` no atrapa un corrimiento de un byte

«Un `PropType` fuera del diccionario» suena más fuerte de lo que es: medido sobre este mapa, leer el
índice corrido **un** byte da 256, que cae **adentro** del rango 0..417 y pasa sin decir nada. Atrapa
la desalineación grosera y deja pasar la sutil, que es la que produce números creíbles. Entran dos que
sí discriminan: la **forma de las rutas del diccionario** (medido: 418/418 válidas, y con un byte de
corrimiento **0 de 418**) y **sobrantes ≠ 0**. Los dos abortan en vez de reportar.

El lector se validó **antes** de correrlo en juego portando su aritmética exacta a Python contra el
`.bsp` real: 418/1588/72/sobrantes 0, las cinco coordenadas del censo clavadas, y el decoder de float
a mano **bit-exacto** contra `struct.unpack` sobre 1200 valores. En juego dio lo mismo.

### ⭐ Los cuatro falsos positivos, destapados y arreglados: de 12/19 a 8/11

No los creó este bloque — **corrían desde antes sobre los `prop_physics`** y lo único nuevo es que por
fin se midieron contra un universo grande. `radio_antenna01_skybox` entraba a *radio* por el substring
(es una antena del skybox 3D); `phone_book` a *teléfono* (es una guía); y la familia *inodoro* era
`parte = { "toilet" }` **sin ningún `nunca`**, así que **6 de las 9 «inodoro» del mapa eran papel
higiénico** — dos de cada tres cadenas las tiraba un rollo. Con los tres vetos: **8 modelos / 11
instancias**, sin perder ni uno bueno.

*Y a la antena la salvaba la distancia, no la regla* (9210 en Y contra una casa que ocupa de −1100 a
100): **una regla que sólo funciona porque el objeto estaba lejos no es una regla.**

### Las tres trampas que el bloque tenía escritas desde antes de empezar

- **Una regla que decide identidad tiene que existir una vez.** `modeloCoincide` recibe una *entidad*
  y un horneado es una *ruta*. La salida fácil era un matcher paralelo, y entonces el día que alguien
  toque un `nunca` arregla la mitad de los casos. Se partió en la parte que **saca** el modelo (sí es
  distinta) y la que **normaliza y decide** (una sola, en el módulo). El cuerpo se movió sin cambiarle
  una línea ni el orden: mover una regla y corregirla en el mismo paso deja sin saber cuál de las dos
  explica un cambio de comportamiento.
- **El barrido no se cuenta a sí mismo.** El emisor es una entidad de verdad y aparece en el próximo
  `ents.FindInSphere`; sin el salteo, el fantasma le haría sonar la radio a un emisor de radio. *Un
  instrumento que cuenta al observador entre los sujetos mide la medición.* El salteo lleva **número**
  y no silencio — «no apareció» se cumple igual si el barrido no corrió. Medido: **2**.
- **El emisor se crea recién cuando la familia gana el sorteo.** Crearlo en el barrido sería fabricar
  cuatro entidades por evento para usar una: las otras tres serían fuga *y* ensuciarían el barrido
  siguiente.

### Lo medido en juego

`phantasmagoria_ghost_estaticos`: **418 modelos / 1588 instancias**, coincide con el `.py`; control de
sobrantes 0 y las 418 rutas con forma de modelo; **8/11** reclamadas. Emisores: **creados 7, vivos 0,
y el conteo real en el mapa también 0** — subieron y volvieron. Salteados **2**.

### Fronteras abiertas, dichas para que ninguna fila se las acredite

- **El corte de la radio decapita el clip, y está medido.** Con planitud espectral (control: ruido
  blanco 0,557 · tono puro 0,000), **tres de los cuatro** clips en juego terminan en ruido de banda
  ancha — la estática y el apagado. El corte de la r3 cae entre los 6 y los 14 s, que en los cuatro es
  el **medio tonal**: `StopSound` siempre se come el final, y la promesa era *«arranca y para sola»*.
  El autor lo pidió explícito: **que suenen completos**. Va junto con el `+USE` de abajo y **no antes**
  — sacar el corte sin el interruptor reintroduce el solapamiento que la r3 cerró.
- **Apagar la radio o el teléfono con `+USE`**, sólo esos dos por ahora. Pedido del autor, sin escribir.
- **El ruido de llaves cuando no hay sujeto.** El autor: si el evento es circunstancial, unas llaves sin
  llaves sobran. Idea suya para reubicarlas: que el bot cierre puertas con pestillo.
- Las filas 03, 04 y 05 de la planilla (que la radio horneada suene, el control negativo con el
  mecanismo puesto, y el A/B real-contra-horneado) **no se corrieron todavía**.

---

## 2026-08-10 (38) — **Las puertas parenteadas ABREN en juego. Y la advertencia que el propio arreglo se escribió cobró el mismo día: un `==` entre entidades también es un uso del trace.**

El autor lo corrió en juego: **«ya abre las puertas»**. El arreglo del padre —subir por `GetParent()`
cuando el sondeo pega en el vidrio o el marco parenteados, sin tocar `DOOR_CLASSES`— hace lo que se
escribió para hacer, en las dos puertas del reporte de la r2. **La causa que se le adjudicó al vidrio
durante tres rondas era falsa y la buena era el parenteo.**

### ⭐⭐ El «parece no dejar huellas» tenía causa, y era el renglón que el arreglo mismo advertía

El autor lo reportó dudando: *«pero parece no dejar huellas (No estoy seguro)»*. **La duda tenía
razón**, y el defecto se leyó en el código sin necesidad de otra pasada:

```lua
if tr and tr.Entity == door then          -- <-- FALSO SIEMPRE en estas puertas
    pendiente = PHANTASMAGORIA.MakePrint( self, door, tr.HitPos, tr.HitNormal )
```

El `tr` pegó en el **panel** y `door` ahora es el **padre**: la igualdad no se cumple nunca, así que
`pendiente` quedaba `nil` y `huellas` se quedaba en **0 justo en las dos puertas por las que existe el
arreglo**. Abrían sin dejar evidencia.

Y esto **estaba advertido en el propio archivo**, tres rondas más arriba en el mismo día: el bloque
del padre decía que devolver el `tr` del hijo *«es correcto para lo que los llamadores hacen hoy»*.
No lo era. **La revisión que escribió esa frase miró los usos GEOMÉTRICOS del trace** (`HitPos`,
`Fraction`, que efectivamente dan lo mismo a centímetros) **y no el de IDENTIDAD, que es el único que
la ruptura rompe.** La lección queda escrita en los dos renglones: *un `==` entre entidades también
es un uso del trace, y revisar «los usos de `tr`» por sus campos numéricos deja afuera precisamente
el que se cae.*

Arreglo: `esLaPuertaOSuPanel( tr.Entity, door )`, que sube la misma cadena. El punto sobre el vidrio
**es** la huella correcta — `MakePrint` la guarda relativa a la puerta y el panel está parenteado, o
sea que se mueve rígido con la hoja y el punto local sigue cayendo sobre el vidrio cuando gira.

**MEDIDO EN JUEGO EL MISMO DÍA Y CIERRA:** `intentos 1 · escalera 1 Use2 1 · ABRIO 1 · fallo 0 ·
huellas 1`, y el detalle `huella 1 mano 4 en func_door_rotating #467, quedan 60 s`, con
`huellas vivas: 1 de 1 guardadas`. La huella se guarda contra la **puerta** (`func_door_rotating`, la
clase del padre) y no contra el panel, que es lo que el arreglo prometía.

### El tope de saltos existe UNA sola vez, y no es cosmético

`PARENT_HOPS = 4`, consumido por los **dos** lados que suben la cadena. Con dos números sueltos, una
puerta encontrada en el salto 4 no dejaría huella porque el otro lado se rinde en el 3 — y el síntoma
sería *«abre pero no deja evidencia»* **en una sola puerta del mapa**, que es la clase de defecto que
no se encuentra buscándolo. Es la regla del lote de equipamiento (una constante que decide geometría
tiene que existir una vez) aplicada a un tope de iteración.

### Lo que NO se midió, dicho y no disimulado

- **La planilla del bloque (`dev/checks/phantasmagoria-puertas-parenteadas.html`) nunca se creó.** El
  bloque se cierra por el veredicto en juego del autor y no por sus seis filas. **Tres de las seis
  quedaron cubiertas por la corrida** (01/02 abre · el arreglo de la huella · y el **control
  negativo**, que el autor midió con el ojo: *«confirmo que no traspasa los ventanales»*), y el
  **acumulado** cerró en `topó con GEOMETRÍA que no es puerta 0 tick(s)` contra los **383** de la
  corrida anterior — ⚠ pero **no en condiciones equivalentes**: en esta pasada el fantasma vio **una
  sola** puerta cerrada, así que el 0 dice «no volvió a topar con geometría no reconocida», no «el
  mismo escenario da 0». Lo que sostiene que esto no es un ensanche de la lista blanca sigue siendo
  la **lectura del BSP** (de 181 `func_breakable` sólo 5 tienen puerta arriba, y de 11 `func_brush`
  sólo 2) más el **diff** con `DOOR_CLASSES` intacta en sus dos copias, tres clases cada una.
- **La huella no se puede VER en juego** y esto no cambió: no existe consumidor que la dibuje —hace
  falta la linterna UV—, así que el único lector es `phantasmagoria_ghost_doors`. Lo que se verificó
  es el **productor del dato** y el contador, que es lo que se podía verificar hoy.
- **`func_movelinear` sigue sin abrirse.** Está fuera de `DOOR_CLASSES` y el mapa tiene 1 con hijos:
  con el arreglo del padre tampoco se abre, porque el padre tampoco está en la lista. Es una decisión
  aparte y sigue pendiente.

Checks al día: **luacheck 35/35 · sintaxis real 35/35 · returns de hooks 0/26 · 164 rutas de sonido,
0 faltantes** (este último con auto-control: una ruta inventada tiene que dar faltante).

### Lo que pidió el autor para después

El bloque que sigue son los **props horneados** (que suenen los `prop_static` del mapa). **Y después
de ése**, la pregunta que el autor dejó planteada: **por qué el bot se queda pegado y después se
despeja solo, y por qué a veces quiere pasar a través de un vidrio.** Su pista: la base Terminator
tendría convars para ver el *thinking* del NPC. Sin medir todavía — no se sabe si esas convars existen
ni qué exponen.

⚠ **UNA HIPÓTESIS APUNTABA AL ARREGLO DE HOY Y LA CORRIDA LA DESCARTÓ.** El atravesado tiene **una
sola puerta de entrada: la cercanía** (`puede and distancia <= PHASE_RANGE`, 45 u), y esa distancia es
`tr.Fraction * reach` — o sea **la distancia AL PANEL**, no a la hoja. Antes del arreglo, `doorAhead`
devolvía `nil` en las puertas parenteadas y el no-sólido **no podía prenderse ahí**; después, el
vidrio resuelve a puerta reconocida, así que en principio acercarse al panel lo prende a 45 u **del
vidrio** — y con `MASK_NPCWORLDSTATIC` (131083, sin `CONTENTS_MOVEABLE`) el fantasma tampoco choca con
brush entities que no son puertas. Eso se habría visto exactamente como *«quiere pasar a través de un
vidrio»*.

**No pasa.** El autor lo mira y reporta *«confirmo que no traspasa los ventanales»*, con el reporte
mostrando `atravesó 1 vez (todas por cercanía)` y `estado sólido (la última vez atravesó 0,5 s)`: el
no-sólido se prende **sobre la puerta** y por medio segundo, que es para lo que se escribió, y las
ventanas siguen frenándolo. Esa rama queda cerrada y **el «pasar a través de un vidrio» no es de este
arreglo**.

⚠ Pero ojo con lo que eso cierra y lo que no: *«no lo traspasa» no es «no lo intenta»*. **Querer y
poder son dos cosas**, y el síntoma que el autor describió es de intención (el bot *quiere* pasar).
Eso —junto con el «se queda pegado y se despeja solo», cuyo candidato más cercano sigue siendo la
misma máquina (`PHASE_MAX = 5` es techo duro y `PHASE_COOLDOWN` lo libera)— es material del bloque de
después de los props horneados, y ahí sí valen las convars de *thinking* de la base.

---

## 2026-08-10 (37) — **La r3 corrió 14/14 en verde y cinco de esas filas no lo estaban. Y el defecto más caro lo trajo la propia r3.**

La planilla salió **14 pasa · 0 falla**. Las **notas** dicen otra cosa en cinco filas, que es exactamente
para lo que el footer pedía llenarlas: *«en la r1 el hallazgo más caro entró por una nota de una fila
marcada PASA»*. Volvió a pasar.

### ⭐⭐⭐ Un `return` en un hook de `PlayerSpawn` se saltea `GM:PlayerSpawn` ENTERO

Tres síntomas reportados como tres problemas —aparecer **sin playermodel**, **errores de Lua en otros
addons**, y **Cargo sin cinturón** (la munición no bajaba y el `unload` se negaba)— eran **UN defecto**,
y su causa era una línea de `server_collision.lua`, el archivo que la r3 estrenó: `marcarPly` colgada
**directo** de `PlayerInitialSpawn` y `PlayerSpawn`, con `return quiere` al final.

Leído en la fuente del engine en disco (`garrysmod/lua/includes/modules/hook.lua`, `Call`):

```lua
if ( a != nil ) then return a, b, c, d, e, f end
...
return GamemodeFunction( gm, ... )      -- <-- NUNCA SE LLEGA
```

Un hook que devuelve algo **no corta la cola de la fila: se saltea la función del gamemode**. Y
`GM:PlayerSpawn` (`gamemodes/base/gamemode/player.lua:229-259`) es el **único** que llama a
`PlayerLoadout` (:251), a `PlayerSetModel` (:255) y a `SetupHands()` (:257). Esa parte **no depende del
orden de `pairs()`**: el `GamemodeFunction` se saltea siempre.

**Y las dos perillas del bloque no lo apagaban: `false` tampoco es `nil`.** Con `nocollide 0` y
`nocollide_ply 0` la función devolvía `false`, el `!= nil` daba verdadero y la cadena se cortaba igual.
El «0 de control» que el bloque publicaba **sólo podía absolver al archivo culpable**.

Arreglo: los dos `hook.Add` envueltos en un closure que se queda con el booleano (el `return` se
consume en `reaplicar`, así que sacárselo rompería el re-conteo). Medido con un arnés que **copia** el
`hook.Call` del engine: A sin el hook y D arreglado corren la cadena entera; **B (`true`) y C (`false`)
la cortan idéntico**. Instrumento nuevo permanente: `dev/auditar_returns_de_hooks.py` — audita los 26
`hook.Add` del addon y hoy da **0 sospechosos de 26** (probado contra el código de ayer: 3 de 3).

### Las cinco filas que su propio criterio reprobaba

- **04 · el veto del throw.** Salió `alguien lo tiene agarrado` sosteniendo con la **physgun**, que es
  literal el camino de FALLA de la fila. Refuta una medición que el archivo daba por firme: se afirmaba
  que `IsPlayerHolding()` **no cubre la physgun**, citando artagdoll. **Sí la cubre** — aquella medición
  fue sobre un **ragdoll** y ésta sobre un `prop_physics`; *una medición sólo refuta lo que sabe leer*.
  Consecuencia: la rama de la physgun era **código muerto**. Decisión del autor: la gravity gun **deja
  de vetar** (por lore de HL2 ya desestabiliza los props), y el veto de physgun pasa a ser el único.
  Alcanza también al **+USE**, que era la misma línea — dicho, no disimulado.
- **05 · el censo de `EF_NODRAW`** decía `NINGUNO` con un fantasma muerto en la partida, que su propio
  renglón declara *rojo del INSTRUMENTO*. La muestra vivía en `phantom_ReconcileVisibility`, que se
  llama desde `ENT:BehaveUpdate` — **el tick que deja de correr cuando el bot muere**. Rama inalcanzable
  por construcción. Movida a `AdditionalRagdollDeathEffects` con `timer.Simple(0)` (la base pone
  `SetNoDraw` **después** del gancho). *La r3 ya había arreglado dónde se GUARDA el dato y no dónde se
  TOMA.* Columnas re-rotuladas: `VIVO` son ticks y `cadaver` son muertes, y el renglón las sumaba.
- **02 · el A/B de la marca** no podía discriminar: `marcadosPly` lo escribía **sólo** el camino de la
  perilla, así que con el mecanismo andando marcaba `0` — la misma lectura que apagado. Ahora el reporte
  **lee el estado vivo**. Se borraron los cuatro contadores que quedaban sin lector; el de fantasmas
  mezclaba un acumulador de sesión con una foto de vivos en el mismo campo (por eso saltaba de `5 de ?`
  a `1 de 1`). *Si la propiedad se puede leer, no se cuenta.*
- **03 · la cuarta predicción no se pudo verificar.** `phantasmagoria_ghost_opendoors` tiene default
  **1** pero es `FCVAR_ARCHIVE`: quedó en **0** de una ronda anterior que la usó de control y sobrevivió
  al reinicio. La planilla no la listaba en el setup. *Una convar archivada no vuelve a su default porque
  reinicies.* Agregada al setup con esa nota. **Re-corrida el mismo día y CIERRA EN VERDE:** con la
  convar en 1, `intentos 2 · ABRIO 2 · fallo 0`, resuelto en el escalón 1 (`Use2`) las dos veces — sin
  llegar a `OpenAwayFrom` ni a `Fire Open` — y 2 huellas dejadas. La r3 queda cerrada, 14/14 medido.

### El sondeo de puertas contaba AL OBSERVADOR entre los sujetos

La corrida de cierre lo destapó sola. El autor se paró delante del fantasma para poder leer el reporte,
el sondeo le pegó **a él**, y salió `player #1 targetname 'SEPULDOSKY'` seguido del consejo entero de
`DOOR_CLASSES` — *«si hay que agregarla, hay que tocar LAS DOS copias de la tabla»* — **sobre un
jugador**. Y el acumulado `topó con algo que NO es puerta` subió **20 → 84 → 146** mientras lo miraba.

Ese acumulado es el que la r2 usó para señalar las puertas con vidrio. O sea que **el acto de pararse a
observar inflaba el número que se iba a leer**, y la escena que el instrumento existe para detectar (una
hoja que la lista blanca no reconoce) y la más común de todas (hay alguien parado adelante) escribían el
mismo renglón y el mismo total. *Un instrumento que cuenta al observador entre los sujetos no mide el
fenómeno, mide la medición.* Se partió en dos acumulados —GEOMETRÍA y SERES (`IsPlayer`/`IsNPC`/
`IsNextBot`, que es la rama que `server_collision.lua` ya había pagado: un nextbot no es `IsNPC()`)— y el
consejo de `DOOR_CLASSES` ya no se le da a un ser.

Dos trampas más, agarradas al escribirlo: el primer intento cortaba con un `return nil` pelado y esta
función termina en **`return nil, tr, src, reach`** — cuatro valores —, o sea que le comía tres al que
llama; es literal lo que el encabezado del bloque advierte tres líneas más arriba. Y el contador nuevo no
entraba en el `reset`, debajo de un comentario que enuncia esa misma regla para el contador de al lado:
*una regla escrita arriba del campo no se aplica sola al campo que nace debajo.*

**Y el chequeo de sintaxis del repo no parsea.** `luacheck_gmod.py` dio `OK` sobre las tres versiones,
incluida la rota: sólo mide `continue` neutralizados y saltos crudos. Se agregó un parseo real (LuaJIT
vía lupa, con `continue` neutralizado como hace el otro): **35 archivos, 0 errores de sintaxis**. La
primera corrida de ese parseo dio falso rojo porque *no* neutralizó `continue` — lo desmintió el control
obvio, correrlo sobre la versión de `HEAD`, que "falló" igual.
- **12 · el sorteo de categorías era CON REEMPLAZO.** `count` está documentado como *«categorías a la
  vez»*, pero `sortearPeso` se llamaba fresco cada vuelta: con el poltergeist (`throw` pesa 8 de 16) la
  misma salía dos veces con probabilidad 1/2, y la bitácora del autor tiene `throw`+`throw` en 3 de 4
  despertadas. Para **The Twins** rompe la mecánica: `radius` está indexado por iteración, así que eran
  dos veces lo mismo a dos distancias. Ahora sortea sin reemplazo, con mensaje propio para «se agotaron».

### El banco de voz, y el británico no estaba donde se buscó

El `whisper` está **limpio**: los dos son 100 % `paranormal_voice/`. Los respiros del **jugador** estaban
en el banco **`breath`**, que es otro peso y suena con la reserva puesta o sin ella. Y `deogen.ogg` **no
está en ningún banco** mientras el tipo `deogen` saca `breath = 6`: *el tipo que existe para delatarse
con un sonido sacaba 6:1 de un banco que no lo contiene*. Eso y `ghost/banshee_scream/` (22 clips, cero
consumidores) no son defectos: esperan el spiritbox y el paramic, igual que `humming`.

**Los 8 de `breath` los rehízo el autor a mano en Audacity** sobre los originales — las tres variantes
generadas por script se descartaron. Crecieron entre ×1,25 y ×1,40; backup verificado por sha256 en
`dev/other/OLD/…(BACKUP BEFORE FANTASMAGORIZAR BREATHING)`.

**Y pasaron a MONO el mismo día**, por decisión del autor: Source no espacializa un estéreo y el fantasma
con AUSENCIA se ubica de oído. La objeción que se había levantado —que un downmix sobre una cadena con
fase puede cancelar— **se midió antes de tocar** (RMS de L, de R y de (L+R)/2, canal por canal) y **no
aplicaba: los ocho dieron entre −0,00 y −0,65 dB**, o sea material prácticamente mono ya. *Una
advertencia correcta en general puede no aplicar al caso, y la diferencia se mide en un minuto.*
Re-codificados **desde el backup en una sola generación** a Vorbis q10 — 201 kbps mono contra los 209
kbps **por canal** del export del autor; la primera pasada había salido a q6 (85 kbps) y eso era tirar
bitrate sobre un asset hecho a mano que nadie de este lado puede juzgar de oído. Segundo backup, aparte
del anterior: `…(BACKUP BEFORE BREATHING A MONO)` guarda **el trabajo del autor**, el otro guarda el rip
crudo — hacen falta los dos.

Con eso el `about.txt` pasa de **29 estéreo a 21**, y el censo destapó que ese número **nunca fue del
árbol**: es el universo de rutas que el Lua **cita** (164, todas resuelven). El árbol entero tiene **250
estéreo de 826**, casi todos en carpetas que ningún `.lua` toca todavía. Los dos números son ciertos y
contestan preguntas distintas; quedan medidos y nombrados para que nadie lea uno como error del otro.
(`event/impact` tiene 10 estéreo en disco y 9 citados — por eso el número **se mide sobre las citas** y
no se resta de una lista.)

**El roster de radio suma dos** por pedido del autor. `creepy_radio_easteregg_helpmewithend` **era
estéreo** y pasó por `dev/mono_posicionales.py` antes de entrar: sin eso habría roto **en silencio** la
promesa de la familia, el defecto exacto que la r3 acababa de pagar en 15 archivos. El instrumento lo
detectó solo, porque saca las rutas del Lua.

### Método

- **Un inventario hecho con `git log` no ve un archivo `??`.** La sesión paralela declaró que no había
  tocado ningún `.lua` fuera de su commit, y era **cierto de su commit y falso de su working tree**:
  `server_collision.lua` es untracked y no aparece en ningún diff.
- **El instrumento de sintaxis sin argumentos revisa CERO archivos y sale 0.** Verde sin medir.
- **El «presentador británico» apareció, y no estaba en la radio.** Vivía en `SND.prop` — el banco de
  **fallback** del evento `prop`, el que suena cuando no hay objeto reconocible cerca — bajo
  `phantasmagoria/prop/key_1.ogg` y `key_2.ogg`. Por eso el síntoma parecía sin causa: el locutor
  aparecía justo cuando no había nada que lo explicara. Lo cierran dos datos que no son el nombre:
  duran **3,47 s y 3,44 s** contra los **0,50-0,96 s** de las llaves reales, y en el rip original
  `Key 1.wav`/`Key 2.wav` están entre `Hint None.wav` y `Arrival 1.wav`, no entre `Key Pickup 1.wav`.
  El autor los mudó a `voice/` al identificarlos, lo que dejó las dos rutas **colgadas** y el fallback
  sin un clip válido; entran las ocho llaves reales de `prop/`. Hoy: **164 rutas de sonido citadas, 0
  faltantes, 0 citas de `voice/`**.
- **Y la r3 había dado por MEDIDO que `voice/` no tenía consumidor.** La medición era correcta y la
  conclusión falsa: contó las rutas que **contienen la palabra `voice`** y las 39 dieron
  `paranormal_voice/`. El consumidor estaba en una ruta que **no contiene esa palabra**. *Un censo
  acotado por la carpeta donde esperás que esté el sospechoso no puede encontrarlo donde no está* — el
  universo correcto eran las 164 rutas, no las que se llamaban como la sospecha.
- No se pudo identificar por medición cuál clip de radio traía voz hablada: la métrica de banda de voz
  **falló su propio control** (`creepy_news` quedó más lejos del locutor que `creepy_music`) porque la
  estática de banda ancha aplana el espectro. Se dice en vez de rankear con un instrumento que no
  discrimina — y al final la respuesta no estaba ahí.

---

## 2026-08-09 (36) — **El fantasma deja de ser un cuerpo: atraviesa. Y los sonidos dejan de mentir sobre el mundo.**

La r2 corrió **9 · 2 · 0**. Esta entrada cierra las dos fallas, contesta las tres preguntas que el
autor dejó en las notas, y estrena **cinco mecanismos que nunca corrieron** — ninguno sin su `0` de
control.

### ⭐ El pedido que encabeza: *«que no colisione contra jugadores y npcs»*

`server_collision.lua`, nuevo. **No toca ni el grupo de colisión ni la máscara**, que es lo que
permite que server_doors.lua siga siendo el dueño único de la solidez y que las nueve trazas de la
base sigan devolviendo lo mismo: usa `GM:ShouldCollide`, más un override de `PhysicallyPushEnt` para
el empujón explícito de 15000 que la base aplica **sin filtrar por tipo** sobre lo que toque su hull.

**Por qué no el camino obvio.** El wraith de la base cambia el grupo a `COLLISION_GROUP_DEBRIS`, y
era tentador. Se descartó por cuatro motivos y el que decide es el que **no se pudo medir**: la regla
de qué grupos alcanza una bala vive en `CGameRules::ShouldCollide`, que es C++ y no está en ninguno
de los 153 `.lua` de los cuatro árboles. **El fantasma tiene que seguir siendo matable**, y ésa es
justo la propiedad que ese camino deja sin garantía. *Cuando una opción apuesta la única propiedad
que no se puede equivocar, se elige la otra.*

⚠ **Y la mitad que sigue sin medirse va con dos perillas en vez de una.** `GM:ShouldCollide` sólo se
llama si alguna de las dos entidades tiene `SetCustomCollisionCheck`, y **sobre cuál de las dos hace
falta no está medido**: el único precedente del taller (HIM) la pone sobre el *jugador*, no sobre el
bot. Las dos arrancan encendidas —la única configuración que no puede fallar por ese motivo— y la
fila 02 de la planilla las separa **en la misma ronda**, porque dos condiciones encendidas a la vez
son un criterio que se cumple a medias y se lee como cumplido.

### Las dos fallas de la r2

**Fila 05 — el `throw` tiraba el prop que tenías agarrado.** No era que el veto no corriera:
**`IsPlayerHolding()` no cubre la physgun**, y eso está medido **en juego** en este mismo taller
sobre artagdoll (*«agarrados: 0 de 1»* con el cuerpo sostenido del pecho). Entra la señal que
faltaba, por `OnPhysgunPickup`/`PhysgunDrop`, guardando **el jugador y no un booleano** para que una
desconexión no deje la marca pegada. Motivo canónico propio, distinto del de la gravity gun: si
compartieran clave, el desglose no podría decir cuál de las dos mitades disparó.

⚠ Y el comentario que sostenía esa línea **era falso en dos formas**: decía *«los TRES precedentes del
taller lo filtran igual»* y después nombraba **dos**, y ninguno de los dos filtra. *Un comentario que
cuenta mal sus propios ejemplos es la señal más barata de que nadie los abrió.*

**Fila 08 — la ráfaga de `ESCRITOR AJENO`.** El diagnóstico **se da vuelta**: la guarda del cadáver
ya estaba puesta cuando salió esa corrida, así que el sujeto **no era un cadáver**. Tres cambios, y
ninguno es apagar el sensor: la alarma pasa a **flanco** (de nivel escribía una línea por tick contra
un anillo de 40, y **borraba la prueba de todo lo demás en 0,6 s** — por eso el reporte llegó con 38
de 40 renglones diciendo lo mismo); el cadáver **se cuenta aparte**, porque un `0` sin un número que
sí se movió no acredita nada; y entra `PHANTASMAGORIA.NoDrawSeen`, un censo por serie que
**sobrevive al fantasma** — que es exactamente lo que le faltó al autor, cuyo sujeto ya no existía
cuando fue a mirarlo. La línea nueva además **nombra al sospechoso**: hay un tercero medido en este
taller que hace `SetNoDraw` sobre una entidad **viva** (el KnockDown del fork de Trepang² Slide) y
deja dos marcas legibles.

### Los sonidos son circunstanciales, que es el pedido más largo del reporte

`SND.prop` pasa de **18 clips planos a 2**. Los otros dieciséis se mudaron a **nueve familias con
sujeto real** —vehículo, radio, teléfono, televisor, piano, guitarra, microondas, inodoro, peluche,
reloj— que se reconocen **por nombre de modelo**, con lista negra. Y el barrido se invirtió: un solo
`ents.FindInSphere` clasificando contra todas las familias, en vez de uno por familia.

⚠ **El comentario que justificaba dejar el piano en el banco plano contradecía al autor con todas las
letras** — decía que *«un crujido de piano puede sonar en cualquier casa»* mientras él pedía lo
contrario. *Una regla se aplica a los casos que la cumplen, no a los que uno no tuvo ganas de mudar.*

**La lista negra no es paranoia: sale de un censo de 6542 `.mdl`.** Cinco de los nueve basenames que
contienen «radio» **no son radios**: tres son pastillas anti-radiación (`radioprotector`) y dos un
detector (`radio_diolator`). Y de los cinco que contienen `tv_`, **uno es un televisor y cuatro son
pedazos rotos**. Sin la lista, la mayoría de los «radios» del taller son un blister.

**Y la radio entra por fin** (Diseño §21.9.8 ①, escrita el 3 de agosto y sin cablear): emite en la
entidad y **se corta con `StopSound`**, porque sus clips duran de 19,5 a 159,8 s medidos.

### ⚠⚠ Source no espacializa estéreo — y 14 de los 21 clips de las familias nuevas lo eran

La promesa entera de este bloque es *«el teléfono suena DESDE el teléfono»*, y **dos tercios de las
familias nuevas la incumplían en silencio**: se oían, y se oían igual desde cualquier lado. Medidas
las **156** rutas del motor con `ffprobe`: **44 estéreo**.

Convertidos a mono los **15** que esta ronda promete posicionales sobre un objeto nombrado
(`dev/mono_posicionales.py`), con backup verificado por sha256 y **re-lectura del disco** — los 15
quedaron en 1 canal, con la misma duración y con el sample rate 44100 de la reparación de la r2
intacto. Los otros **29 no se tocaron**: suenan en un punto cerca del fantasma, no sobre un objeto
que el jugador esté mirando, **y el autor ya los escuchó y los dio por buenos**. Quedan medidos, con
su propia fila.

*Un asset que el autor ya aprobó no se cambia sin preguntarle; uno que rompe la mecánica que se está
entregando, sí — y la diferencia se escribe.*

### Las voces se guardan, el golpe suena a lo que golpea, y el fantasma no se va del mapa

- **La reserva de voz.** El corte es **por si se entiende o no**: susurros, murmullos, jadeos y
  quejidos siguen de ambiente (8 clips por voz); las frases, las risas y el canto se reservan para el
  paramic y la manifestación. Se re-rutea **el peso**, no la tabla de datos: `ghost_flags.lua` no se
  toca. ⚠ Y el control **no reproducía la r2** hasta que la revisión lo agarró: con la perilla en 0
  los 8 de `whisper` quedaban inalcanzables. *Un control que no reproduce el estado que dice
  reproducir es un tercer estado sin nombre.*
- **Fila 11 contestada, y estaba al revés.** `SND.knock` tenía **1 clip de puerta y 6 de ventana**, y
  el código elegía ese banco entero al pegar en una **puerta**: golpear una puerta sonaba a ventana
  **6 de cada 7 veces**, y una ventana real caía en «pared», donde no hay un solo clip de ventana.
  Ahora son **cinco bancos**, la clase gana al material, el material gana al default, y la bitácora
  imprime **el clip que sonó** — sin eso, el defecto era invisible en el log.
- **La correa** (`server_leash.lua`). El fantasma no se escapaba por capricho: su tarea de deambular
  **puntúa por distancia** y encadena a otra de radio 5000-6000 que penaliza lo ya visitado. Se
  filtra el **destino** en `SetupPathShell` — no se aborta ni se teleporta, porque devolver `nil`
  encadena a `biginertia` y **lo manda más lejos**.
- **Las puertas de vidrio.** El instrumento que faltaba: `phantasmagoria_ghost_puerta` cuelga **del
  jugador** y no del fantasma, y traza con las tres máscaras de la base. Si `MASK_NPCSOLID` pega y
  `MASK_BLOCKLOS` no, esa cosa **deja ver y no deja pasar**, que es la definición de un panel de
  vidrio. Y `doorAhead` ahora guarda **lo que no es una puerta**: hasta hoy, «no hay nada adelante» y
  «hay algo que no reconozco» escribían la misma línea.

### La revisión adversarial, y los seis que introdujo esta misma tanda

Seis lentes sobre el diff propio y un verificador por hallazgo — **66 defectos propuestos**. Los que
más enseñan son los que **entraron con los arreglos de esta ronda**:

| | qué pasaba |
|---|---|
| **`clock_tick` dura 46,55 s** | quedó en el banco plano, disparado con `sound.Play`, que **no se puede parar**. Es más largo que tres de los cuatro clips de radio que esta misma ronda se negó a poner ahí *por ese motivo exacto*, y el comentario que lo prohíbe estaba **veinte líneas más abajo, escrito el mismo día**. *Una regla escrita en un bloque no se aplica sola al bloque de al lado.* |
| **el contador de la fila 06** | colgaba de `phantom_doorStats`, una tabla que **sólo existe si el fantasma ya reconoció una puerta** — o sea que en la escena exacta para la que se escribió (una hoja que la lista blanca **no** reconoce) no podía subir. *Un contador cuya precondición la apaga el mismo escenario que vino a medir es un cero que no significa nada.* |
| **el falso rojo de la correa** | con `leash 1` un fantasma cazando pasa derecho por la guarda del hunt, así que los dos contadores quedan en 0 — y el reporte tenía escrito *«el override no corrió ni una vez»*. Habría cantado un **rojo sobre el mecanismo funcionando como se diseñó**. Es el nº 30 del catálogo. |
| **`marcados` contaba vueltas** | con la perilla en 0 decía *«marcados 3 fantasma(s)»* sobre tres sujetos a los que les acababa de poner la bandera en **false**. Ahora cuenta la marca puesta y lleva su denominador. |
| **`marcarPly` pisaba a un tercero** | escritura absoluta de `SetCustomCollisionCheck` en cada respawn, sin leer lo que había: le apagaba la bandera a HIM, que la usa para su propia lista. Ahora **sólo apagamos lo que nosotros prendimos**. |
| **un comentario que se invalidó solo** | afirmaba *«los 39 hits de una ruta que termina en `voice/` son los 39 de paranormal_voice»* — y al nombrar en ese mismo comentario la carpeta del encargado, el grep que describe pasó a dar 40. *El criterio de una medición hay que escribirlo, o el texto que la cita la rompe.* |

Y una que **no** es un defecto y se deja escrita para que nadie la busque de nuevo: **el presentador
británico no había que quitarlo de ningún lado**. Medido, las 39 rutas entre comillas que terminan en
`voice/` son las 39 de `ghost/paranormal_voice/` — la voz del fantasma. La carpeta del encargado
(26 archivos) **no tiene un solo consumidor** en el addon.

### Lo que se midió y no se escribió

**Los props horneados del mapa: sí se puede, y no se hizo.** Los `prop_static` no existen como
entidad en runtime (`ents.FindByClass( "prop_static" )` tiene **cero** call sites en los 70 addons
desempacados del taller), pero **se puede abrir el `.bsp` y leer el game lump `sprp`** — StormFox2 lo
hace y funciona, con un `FindStaticsInSphere` que es el gemelo exacto de `ents.FindInSphere`. No se
escribió porque falta el número que decide y cuesta diez minutos: **nadie contó cuántas radios, teles
o pianos estáticos tiene el mapa del autor**. Si es cero, todo el parser sobra.

Planilla: `dev/checks/phantasmagoria-eventos-r3.html`, 13 filas. **Nada de esto corrió en juego.**

---

## 2026-08-09 (35) — **La r1 de eventos corrió: 8 · 0 · 3. El motor anduvo; el que mintió fue el audio, y el instrumento lo acreditó.**

Primera corrida en juego del bloque de eventos paranormales (Diseño §21). El autor: las ocho
categorías dispararon, la perilla por categoría apagó sólo la suya, el A/B por tipo salió —*«un
Poltergeist se comporta más agresivo con los props, rompió hasta una ventana»*—, el hunt subió la
intensidad y la tesis se confirmó: *«no sonó nada estando lejos»*.

**Pero cuatro de esos ocho verdes podían salir verdes con el defecto adentro, y uno lo tenía.**

### ⚠⚠ El banco de VOZ estaba mudo entero, y el reporte decía `OK`

Entre las notas de la fila 10, dos líneas del **mismo disparo**:

```
    #442  sound -> 2 disparo(s)
        OK -- voz 1 / banco voice a 221 u
*** Invalid sample rate (48000) for sound 'phantasmagoria\ghost\paranormal_voice\voice_1_why_01.ogg'
```

Censados los **826 `.ogg`** del árbol con dos instrumentos independientes (parseo del header Vorbis y
`ffprobe`, mismo resultado): **270 con un sample rate que Source rechaza** — 264 a 48000 y 6 a 32000.
**El banco `voice` roto al 100 %: 39 de 39 clips, las dos voces.**

**La causa raíz estaba escrita como una decisión correcta** en `sound/phantasmagoria/about.txt`: los
391 clips extraídos del juego *«son el Vorbis ORIGINAL de Unity, copiados tal cual: reencodear
ya-comprimido sólo pierde»*. Cierto sobre la **calidad**, falso sobre la **compatibilidad**. La
partición por vendor string del Ogg lo muestra:

| vendor | total | inválidos |
|---|---:|---:|
| `Fmod5Sharp` (rip del juego, copiado tal cual) | 391 | **268** |
| `Lavf` (reencodeado por ffmpeg) | 265 | 0 |
| `Xiph libVorbis` (terceros / radio) | 170 | 2 |
| **TOTAL** | **826** | **270** |

⚠⚠ **Y ESTA TABLA SE PUBLICÓ MAL PRIMERO, en cuatro archivos, con la palabra «denominador» al
lado.** Decía sólo las dos primeras filas — *«los 265 que pasaron por ffmpeg dan 0, los 391 que se
saltearon dan 268»*— y **0 + 268 = 268 contra 270 inválidos**. Faltaban dos, que son de una **tercera
fuente que el encabezado de `about.txt` no declaraba** (decía «656 archivos, de DOS fuentes» cuando
son 826 y tres). La causa raíz sigue en pie y explica **268 de 270**; lo que no se sostenía era
presentarla como una partición cerrada.

> *Una partición que no suma el total no es una prueba: es una anécdota con tabla. Y se publica igual
> cuando el que la escribe ya tiene la respuesta y el número que falta es chico.*

> *El sample rate no es calidad, es compatibilidad. Una decisión puede ser correcta en el eje que la
> motivó y desastrosa en un eje que nadie nombró.*

**Reparados los 270 a 44100** con **`dev/resample_44100.py`**, con la calidad elegida **por archivo**
contra el bitrate de origen para no perder además ancho de banda. Tres reglas, y las tres son
lecciones ya pagadas acá: backup **verificado por sha256** antes de tocar nada (`sound/` está
gitignoreado, así que **git no era la red de contención**), conversión a temporal **medida** —sample
rate, canales y duración— antes de reemplazar, y **re-medición del árbol entero** al final, no sólo
de lo que se tocó. Resultado: 270/270 OK, 0 rechazados, **0 inválidos restantes**. El backup vive
**al lado del checkout**, no adentro: `dev/other/OLD/phantasmagoria_sound (BACKUP BEFORE RESAMPLE
44100)/` de la carpeta que contiene el repo.

⚠ **El script se versiona, y ese es el punto.** Hizo un cambio irreversible sobre assets que **no
están en git**: sin él en el repo, la única forma de auditar qué se hizo sería creerle a esta entrada.
*Un cambio destructivo cuyo instrumento no queda versionado es un cambio que nadie puede revisar.* Es
idempotente — corrido de nuevo sobre el árbol ya reparado dice `sujetos: 0 · nada que hacer`.

**Y el instrumento lo acreditó:** `EV.sound` hacía `sound.Play` y devolvía `true` **literal** en la
línea siguiente — el mismo archivo documenta que `sound.Play` no devuelve nada. **El autor ya había
arreglado este exacto modo de falla para `door`, en el mismo archivo**, con la lección escrita al lado.
*Una lección aprendida en una función no se aplica sola a la de al lado.* Ahora el detalle **nombra
el archivo elegido**, que es lo que permite aparear nuestra línea con la del engine.

### Las luces: se midió el BSP, y el recuerdo del autor era correcto

Pedido sobre la fila 04: *«el mod GM paranormal podía tocar luces horneadas en el mapa»*. Se sacó
`maps/gm_funkis_night.bsp` del `.gma` del Workshop y se parseó el `LUMP_ENTITIES` (VBSP v20, 1224
bloques): el mapa tiene **322 luces escritas en el BSP y 43 con `targetname` y lightstyle conmutable,
en 12 grupos**. gmpa **no tocaba lo horneado** — tocaba las que sobreviven por tener nombre. Y en
cobertura de clase **somos más amplios**: gmpa mira sólo `light` y pierde los 17 `light_spot` (el baño
entero); nosotros miramos siete clases.

La diferencia es el **radio**, y eso es la tesis. Las 43 nombradas caben en **862 × 1056 u** mientras
**37 de las 65 puertas y 14 de los 15 `prop_physics` no tienen ninguna luz nombrada a 450 u** — por
eso `throw` y `door` pueden tener sujeto cuando `light` no, y **por eso ese cruce no diagnostica
nada** (se intentó usarlo como prueba y la medición lo refutó).

**Dos cambios**, ninguno toca el radio: `lucesCerca` pasa de `ents.FindInSphere` a `ents.FindByClass`
con filtro de distancia a mano —una `light` es un point entity sin modelo ni colisión y no está
medido que la partición espacial la indexe; gmpa usaba FindByClass y le funcionaba—, y **el mensaje
de vacío deja de medir su propio método**: imprime cuántas hay en todo el mapa, la distancia a la más
cercana y dónde está el fantasma. ⚠ Además decía **«alcanzables»** y en esa función no hay **un solo
trace**.

> *Un vacío que sólo describe su propio método no es una medición del mundo: tres causas distintas
> escriben la misma línea.*

### El veto de sandbox nombraba dos campos que no existen

`propVetado` decía `ent.CargoItem or ent.cargo_ItemID`. Un grep sobre **todo el workspace** devuelve
una sola aparición de cada uno: **esa línea**. El veto de inventario **nunca vetó nada**. Los
marcadores reales son `CargoContainer` y `CargoEntry`.

⚠ **Y cambiar el nombre no lo hizo alcanzable**: hoy ningún escritor de esos dos campos produce una
entidad de las dos clases de `THROW_CLASSES`. Se cambió un campo **inexistente** por uno **real que
tampoco alcanza al sujeto**; queda como póliza y **ninguna fila lo acredita**.

> *Un veto que nombra un campo inexistente se lee igual que uno que anda: el código está escrito, el
> comentario es correcto, y la guarda no existe. Y uno que nombra el campo correcto sobre un sujeto
> que nunca llega se lee todavía mejor.*

Entraron además **constraints** (sin él, veinte tablas soldadas de 5 kg pasan el tope de masa una por
una), **parenteado**, y `IsMoveable` junto a `IsMotionEnabled` — el precedente que el propio
comentario citaba usa **las dos** y estaba copiada la mitad. El contador de vetados pasó a **desglose
por motivo** y se imprime **también en el éxito**: antes salía sólo en la rama de fracaso, o sea en la
única escena que la fila 09 excluye por precondición.

### Dos pedidos del autor, aplicados

- **Las voces salen del fantasma** (`ghost:EmitSound`, así la voz lo **sigue** al caminar). La regla
  que lo impedía defendía tres mecánicas —spirit box, parabólica, caja musical— que tienen **cero
  líneas de código**. *Una regla sostenida por código que no existe no se puede falsar, y por eso
  sobrevive a la evidencia.* Las otras siete categorías siguen sonando lejos; la tesis no se toca.
- **Los sonidos de auto necesitan un auto.** `EV.prop` sorteaba de una tabla plana sin mirar el mundo
  (cero `ents.*` en su cuerpo). `car_alarm` y `car_lock` pasan a `PROP_CONSUJETO` y suenan **desde**
  el vehículo. Un solo test cubre HL2 y Glide: **Glide pisa `Entity:IsVehicle()` en el metatable**
  (`sh_glide.lua:326-330`).

### El instrumento: cinco defectos, y dos son reincidencias del propio repo

- **La acreditación del scheduler no podía darse.** El disparo forzado escribía **los mismos
  contadores** que el timer. La planilla pedía un `reset` antes de medir ritmo: *le pedía al operador
  que no ensuciara el instrumento en vez de que el instrumento separara.* Ahora son dos cuentas y la
  bitácora rotula `[FORZADO]`.
- **La bitácora sin serie**: `#442` pelado, y GMod recicla el EntIndex — en la r1 hay un `#442` con
  números de Poltergeist y otro que la ficha declara Shade. **Ya estaba cerrado en `server_cloak.lua`
  y en `server_steps.lua`.** *Que una lección esté cerrada en el repo no la aplica al archivo que se
  escribe mañana: lo que se hereda es el texto, no la práctica.*
- **El intervalo sorteado se tiraba.** Decidir si el `rate` del hunt dividía el intervalo obligó a
  restar timestamps a mano; la respuesta fue que **sí dividía** — el código estaba bien y **la duda la
  fabricó el instrumento**.
- **`bitacora ( 60 / 60 )`** decía lo mismo con 60 renglones que con 600. Ahora cuenta las descartadas
  y cuántos fantasmas escribieron.
- **El `reset` nileaba `phantom_ev` entera**, que guarda contadores **pero también** la cuarentena de
  puertas y el reloj — y dejaba `next = 0`, que el scheduler lee como «recién nacido» y reprograma a
  4-12 s. *Un botón que existe para limpiar el instrumento no puede fabricarle el primer dato a la
  medición que viene.*

### La alarma de `EF_NODRAW` acusaba a un inocente

El autor preguntó por una ráfaga de `!! ESCRITOR AJENO` sobre `#452/s10` mientras veía bien a
`#442/s11`. **No es código nuestro: el escritor es la base, en la muerte del bot**
(`damageandhealth.lua:826`). `#452/s10` era un **cadáver**. El defecto era de **alcance** — el
reconciliador sigue corriendo sobre el cadáver los ~10 s que sobrevive a su muerte — y ahora la alarma
exige `not self.term_Dead`, que la base escribe en `OnKilled` (`:677`) **antes** del `:826`.

> *Una alarma que no acota su sujeto no mide de menos: mide de más, y el falso positivo cuesta lo
> mismo que el defecto que buscaba.*

### La fila 02 se cerró **fuera del juego**, y el número del handoff estaba mal por partida doble

Ejecutando `ghost_types.lua` + `ghost_flags.lua` en un intérprete Lua real: **30 de 30 filas con
`events`, 61 de 61 campos de delta, cero `ErrorNoHalt`** — con control negativo (anulando la fusión da
`0 de 30` y `0 de 61`, o sea que la medición discrimina). Los «25 de 30» del handoff no envejecieron,
pero **`the_mimic` es idéntico al neutro**: las que de verdad se diferencian son **24**. Y `conRasgos`
se computa y **se tira**: el número que separa «25 con rasgos propios» de «0» no sale por ninguna
salida.

### ⚠⚠ La revisión adversarial mató CUARENTA defectos del código de esta misma sesión

Cinco lentes independientes sobre el diff, con verificación adversarial de cada hallazgo: **40
confirmados, 11 refutados**. Los tres peores **los introdujo esta tanda**, y los tres son *un arreglo
correcto en su eje que rompe algo en un eje que nadie nombró*.

- **Un veto por `GetCreator` habría apagado `throw` entero.** En GMod **todo prop del spawnmenu lleva
  creator**, así que en un servidor sandbox real la categoría insignia se queda muda **con un motivo
  que suena razonable** — y corría antes que la masa y que los constraints, tapando a los dos filtros
  que sí distinguen. Lo encontraron cuatro lentes por separado. La distinción que faltaba es
  **spawnear contra construir**: lo que protege el trabajo del jugador es `HasConstraints`.
  *Un veto que no distingue «es de alguien» de «alguien lo armó» no protege al jugador: le apaga el
  juego.* Y de paso: **`GetCreator()` y `GetOwner()` no devuelven `nil` cuando no hay nadie, devuelven
  `NULL`, que es truthy** — la cadena `a or b or c` cortaba en el primero y `GetOwner()` era código
  muerto.
- **El `EmitSound` de las voces le voló el audio al cadáver.** El scheduler disparaba sobre fantasmas
  muertos y eso era un defecto **benigno**: con `sound.Play` en un punto el susurro sonaba. Con
  `EmitSound` el canal cuelga de la entidad, y la base ya le puso `EF_NODRAW` al morir — el cliente
  deja de recibirla. Es el mecanismo de la r22 aplicado en contra. *Un cambio correcto puede volver
  grave un defecto que ya estaba y era benigno.*
- **El sonido con sujeto agarraba la silla en la que estás sentado**, y el auto que estás manejando.

**Y el arreglo del cadáver era la mitad del arreglo:** la guarda entró en el **contador** y no en **la
línea que el operador lee**. *Arreglar el contador y dejar el texto es arreglar la mitad que nadie
mira.*

**El `reset` se contradecía en tres frentes, los tres escritos en la misma edición:** el comentario
decía *«el reloj NO se toca»* y dos líneas abajo lo reprogramaba; ponía `vueltas` en 0 mientras el
reporte dice al lado que **un 0 significa que el timer no corre**; y era el único de los cuatro
recorridos que llamaba al método sin comprobar que existiera. *Un comentario y su código pueden
contradecirse en dos líneas consecutivas sin que ninguna prueba lo note.*

**Y la peor, porque el propio prompt de revisión la pidió:** el rótulo *«INCLUYE el multiplicador del
hunt»* se decidía leyendo `phantom_Hunting` **al imprimir** con el número calculado **al sortear** —
la familia «la foto vieja», reaparecida en el instrumento escrito para cerrar otra.

Detalle completo en Diseño §21.9.9.

### Aviso de método, y toca a todo el repo

Un agente midió que **la herramienta Grep del harness truncó en silencio y sub-reportó el universo
14×** sobre este workspace. Cualquier afirmación del tipo «el único sitio que hace X» hecha con un
Grep de árbol entero **está sin denominador** hasta rehacerla con `rg --no-ignore` acotado y el total
impreso.

---

## 2026-08-09 (34) — **El motor no cargó en juego: un salto de línea CRUDO dentro de un string. Y el verificador de sintaxis había dicho OK.**

Primera corrida en GMod del bloque de eventos. `ghost_flags.lua:749` tiraba
`unfinished string near '"diferencia -- que es un defecto visible en juego...'` y el archivo
**entero** no cargaba: `rasgos de evento 0 de 30 filas con events`.

**La causa:** ese `ErrorNoHalt` se escribió a través de un script de Python adentro de un heredoc de
shell — **dos capas de escape** — y el `\n` final llegó a Lua como un salto de línea **real** en vez
de como la secuencia de dos caracteres. Un string corto de Lua no puede contener un salto crudo.

### ⚠ Lo que importa no es la línea: es que EL VERIFICADOR DIO VERDE

La entrada anterior acreditó *«sintaxis verificada con cinco archivos de control»*. **Esa
acreditación era falsa.** Medido aislando el caso:

```lua
local x = f( "primera parte
segunda parte" )
```

`luaparser`: **OK**. GMod: `unfinished string`. El taller ya tenía anotado que `luaparser` da
**falsos rojos** sobre Lua de GMod (rechaza `continue`); lo que no estaba medido es que también da un
**falso VERDE** sobre esto. *Un verificador que sólo da falsos rojos se descubre la primera vez que
se usa; uno que da un falso verde se descubre en el juego, y mientras tanto ACREDITA.*

Y el error se repitió **dos veces más** en la misma sesión —al generar los archivos de control con
`printf`, y al escribir esta misma entrada de changelog por `python -c`— lo que fija la regla real:
**la prosa y el código no se escriben a través de una capa de shell.** Van con la herramienta de
archivos, que no tiene niveles de escape.

**Entra `dev/luacheck_gmod.py`**, con dos instrumentos porque ninguno solo alcanza: `luaparser` con
`continue` neutralizado, **más un lexer propio** que separa a mano los cuatro contextos (comentario
de línea, comentario largo, string largo, string corto) y busca ese único defecto. Trae **sus dos
controles versionados** — `luacheck_control_roto.lua` y `luacheck_control_sano.lua` — porque un
verificador sin control es lo que produjo esta entrada. El sano cubre lo que un detector ingenuo
confundiría: strings largos `[[ ]]` con saltos (legales), comentarios con comillas sueltas, comillas
escapadas.

Corrido sobre **los 32 `.lua` del addon**: el defecto estaba en esa sola línea, y los otros 31 están
limpios.

### Lo que la corrida SÍ acreditó, y no es poco

- **La degradación elegante funcionó en su primer uso real.** El `NEUTRO` de emergencia del motor
  —que existe justamente por si `ghost_flags.lua` no carga, y que salió de la revisión adversarial—
  hizo que **los eventos siguieran corriendo** con el archivo de rasgos caído: el autor escuchó el
  teléfono, el crujido, los golpes y el mueble, y tiró props a mano. Sin ese fallback el scheduler
  habría tirado un error de Lua **por segundo, para siempre**.
- **Los tres instrumentos dijeron la verdad todo el tiempo.** `rasgos: el tipo no tiene rasgos de
  evento ( ghost_flags.lua no fusiono )` en la ficha del fantasma; la guarda (2) de
  `server_events.lua` nombrando la causa; y el cargador con `0 de 30 filas con events` más la flecha
  a la lista `DATOS`. **Ninguno dijo que estaba todo bien.**
- **`vueltas 364 del scheduler`** — la línea que existe para distinguir *«el motor no corre»* de *«el
  motor corre y no encuentra sujeto»*. Hizo exactamente eso.
- El evento de luces reportó su vacío **enumerando las siete clases que buscó**, en un mapa sin luces
  alcanzables: el vacío como medición y no como silencio.
- Y `throw` mostró su propia discriminación sin que nadie la pidiera: el primer disparo forzado dio
  `NO SALIO -- no habia props fisicos movibles a 450 u ( 0 vetado(s) )` y los cuatro siguientes
  `1 prop(s) tirado(s)`. **El `( 0 vetado(s) )` es el dato**: no había candidatos, no es que los
  hubiera descartado.

### Lo que queda sin medir hasta la próxima corrida

Con la fusión caída, **los 30 tipos se comportaron como el neutro** — el Shade de la corrida tenía
`rate x1.00 count 1 burst 1`. O sea que **la fila 06 de la planilla (Poltergeist contra Shade), que
es el corazón del pedido del autor, todavía no se ejerció.** Verificado fuera del juego que
`auditarNeutro` devuelve **0 mal formados** sobre las 25 filas —o sea que la fusión va a correr— pero
eso es una simulación, no una corrida.

⚠ Y hay una consecuencia del orden nuevo que hay que tener presente al leer el próximo arranque: la
guarda corre **antes** de la fusión y, si encuentra un rasgo mal formado, **se niega a fusionar**.
Eso produce *exactamente el mismo síntoma* que el archivo que no carga (`0 de 30 filas con events`),
y las dos causas se distinguen sólo por cuál `ErrorNoHalt` salió arriba.

---

## 2026-08-09 (33) — **Los eventos paranormales: el motor ESCRITO, y quince defectos propios agarrados antes de que llegaran al juego**

Pedido del autor: portar los eventos de `[gm] paranormal events` —parpadeo de luces, tirar objetos y
lo demás— **cerca de la entidad**, con convar por evento, flag para desactivarlos uno por uno, y
rasgos por tipo *«para que algunos boten objetos, otros los hagan con mayor intensidad, y nos pueda
servir para HUNTS»*.

**Nada de esto corrió en GMod.** Lo verificado fuera del juego es la sintaxis (con cinco archivos de
control que ya corren hoy, incluido el `shared.lua` de la base) y que **las 152 rutas de sonido
citadas existen en disco, 152 de 152**. La planilla es `dev/checks/phantasmagoria-eventos-r1.html`,
11 filas, las cuatro primeras medibles por consola.

### Lo que entró

- `lua/entities/terminator_nextbot_phantom/server_events.lua` — el motor. **Ocho categorías**
  (`throw`, `knock`, `creak`, `door`, `light`, `sound`, `prop`, `furniture`), una **tabla de pesos**
  en vez de la cascada de nueve `if` sin `elseif` de gmpa, y **una convar por categoría** con la
  convención de tres estados del repo (`0` control · `1` el rasgo del tipo decide · `2` forzado).
- `lua/phantasmagoria/ghost_flags.lua` — los rasgos de **25 de los 30 tipos**, sacados de los
  comentarios «Comportamiento del juego» de `ghost_types.lua`, con la línea citada al lado de cada
  uno. Va en un archivo aparte porque `dev/gen_types.py:119` **pisa `ghost_types.lua` entero**.
- Tres instrumentos: `phantasmagoria_ghost_events` (reporte), `phantasmagoria_ghost_event <cat>`
  (disparo forzado — sin él la planilla no se puede correr, porque cada categoría depende de un
  sorteo) y `phantasmagoria_ghost_evflag` (el andamio de los ocho flags).

### La tesis: **cerca de quién**

gmpa elige un jugador al azar y hace pasar las cosas a ≤2048 u *de él*. El fantasma no participa —
por eso su *favourite room* tuvo que ser un `Vector` hardcodeado. Acá **el radio cuelga del
fantasma**, lo que convierte la actividad en un instrumento de localización. Consecuencia aceptada de
frente: **si el fantasma está lejos, no pasa nada, y eso es correcto.**

### ⚠ La revisión adversarial encontró QUINCE defectos en código recién escrito

Doce agentes en seis ejes, cada hallazgo pasado por un escéptico con el sesgo puesto en **refutar**.
Los cuatro que dejan una regla:

**① Un comentario mentiroso se propaga al lector que lo cita — y el lector fui yo.**
`server.lua:3466-3468` afirmaba que la guarda de `server_cloak.lua` comprueba **tres** claves de
`MyClassTask`, *«…y `BehaveUpdatePriority` de este archivo»*. Falso en las dos mitades: el cloak lista
**dos** (`:826`) y **descartó esa clave a propósito** (`:385-386`). Copié la lista del comentario en
vez de medir, y la guarda nueva quedaba tirando `ErrorNoHalt` **en todos los arranques**, acusando al
archivo nuevo de pisar una clave que nunca existió — el nº 22 del catálogo, *un control que fabrica
el síntoma que busca*. Los dos comentarios corregidos; el censo real son tres asignaciones en todo el
addon.

**② Un flag que se lee en dos lugares se compone en dos lugares.** `count` mandaba el bucle del
despachador **y** entraba como tope de props del evento de tirar: **se multiplicaba consigo mismo**.
Un Poltergeist cazando llegaba a ~32 props y 32 `EmitSound` en un frame (techo 64), y el reporte lo
mostraba como «1 disparo». Partido en `count` (categorías simultáneas) y `burst` (objetos por
tirada) — que además es lo que separa al Poltergeist de los Twins.

**③ Medir el destino, no enumerar las salidas.** `EV.door` devolvía `true` después de llamar `Use2`,
que tiene **cinco salidas silenciosas**, y la cuarta es **nuestra propia convar**
(`phantasmagoria_ghost_opendoors 0` → veto `TerminatorBlockUse`). Con esa convar en 0: sonaba la
manija, la hoja no se movía, y el instrumento imprimía `OK -- puerta prop_door_rotating #123`.
**Verde exacto sobre cero comportamiento.** Ahora se lee el estado de la hoja antes y después, y la
bitácora dice `efecto CONFIRMADO` o `SIN EFECTO`. (Enumerar las cinco sería frágil: una se activa
porque un tercero *agregue* un campo.)

**④ Se leyó el mecanismo de HIM y se salteó su guarda.** El parpadeo copió la forma (2-4 `Fire` con
delay, contra los ~90 timers anidados de gmpa) y no la **primera línea** del precedente:
`if not ent:GetOn() then return end`. Sin ella, una lámpara **ya apagada** recibía tres
`SetOn(false)`, sonaba el interruptor, y el reporte devolvía «3 conmutaciones» con cero cambio
visible — justo en la categoría cuyo encabezado promete distinguir el vacío del evento.

Y dos que valen como advertencia sobre copiar convenciones:

- **`evhunt` declaraba tres estados y entregaba dos.** El `2` producía *exactamente* lo mismo que el
  `1` mientras el reporte imprimía «forzado». Se copió la convención de tres estados **sin el
  mecanismo que la sostiene**: el `2` significa «ignorá el flag del NPC», y el hunt no tiene flag por
  NPC. Hoy la convar declara dos y dice por qué.
- **La guarda de datos corría DESPUÉS de la fusión que protege.** El paso capaz de matarla ocurría
  primero, y si moría, la única línea que habría dicho cuál era el campo no llegaba a correr. *Una
  guarda que corre después del paso que puede matarla no es una guarda: es una autopsia que no se
  hace.*

Los otros nueve: el estallido de luz ignoraba `soloEnciende` (o sea que el Jinn, cuyo único rasgo es
*«cannot turn off»*, apagaba luces); `point_spotlight` recibía `TurnOff`, un input que no tiene, y en
el parpadeo perdía la dirección; el signo se aplicaba a **cada paso** en vez de al **estado final**,
con lo cual los dos tipos de luces del juego eran justo los dos que **no parpadeaban**; `Sparks` iba
sin `Magnitude`/`Scale`/`Radius`, que los cuatro precedentes del árbol sí setean; la cuarentena de
puertas se escribía antes de saber si se iba a actuar (fabricando la escasez que después reportaba);
el reporte no tenía la guarda `isfunction` que sí tienen el scheduler y el disparo forzado, así que
moría entero en el único caso que existe para diagnosticar; `dir` y `soundBanks` —el primero es *el*
hallazgo del corte— no salían en ninguna salida; dos cuentas distintas se llamaban `disparos`; y un
mensaje de error imprimía «habia 0 candidato(s)» en una rama a la que sólo se llega habiendo tenido
al menos uno.

### Y una corrección al diseño, del arco de lectura

**`FlingNearbyPhysicsProps` de gmpa SÍ corre.** §11.2 decía *«su **único** call site»* habiendo leído
uno de **tres** (`:612` muerto, `:1040` y `:1055` vivos vía `activeGhosts`). Estuvo siete días en el
documento y llegó a la memoria del proyecto. Corregido en §9, §11.2, §11.3 y §2 del diseño, con una
nota fechada en la entrada vieja de este changelog — **la entrada no se reescribe**: es el registro
de lo que se midió aquel día. *Declarar muerta una función es una afirmación sobre TODOS sus call
sites, así que exige contarlos.*

---

## 2026-08-09 (33) — **La r23b: 3 pasa · 1 sin correr. La roja era de la planilla, y la bitácora se llenó de spawns**

**01 pasa:** el censo imprimió `NINGUNO todavia` con sus tres líneas de ceguera — nadie parenteó nada
en toda la sesión, dicho *con* el aviso de que un hijo de menos de 0,25 s puede no aparecer.

**02 estaba verde por su propio criterio** y se marcó roja porque **la fila no explicaba qué es un
hijo**: pedía juzgar si el vacío estaba bien declarado y nunca dijo que un *hijo* es otra entidad que
un tercero pega al fantasma con `SetParent`, que se mueve con él y se dibuja por su cuenta — o sea que
nuestro `ENT:Draw` no la alcanza. *Una fila que usa un término del código sin traducirlo mide la
jerga, no el mecanismo.*

**04 pasa otra vez**, sobre datos nuevos: `#1332` con las series `s29`, `s36` y `s39` (tres fantasmas
bajo el mismo `EntIndex`) y `#1323` de `s10` a `s38`. Ninguna línea con `s?`.

### ⚠ Lo que ninguna fila marcó: la ventana de la bitácora se la comieron los spawns

Entre t=421 y t=451, **28 líneas** `SE VE … absence 0`, una por segundo, series 5→37, alternando dos
`EntIndex`: una racha de spawns, cada bot nuevo escribiendo su primer estado. De 40 renglones, 28 se
fueron ahí y el tramo que la corrida quería mirar quedó en 12.

El síntoma es idéntico al que la fila 06 de la r22 vigila (*la bitácora inundada* = el reconciliador
reescribiendo cada tick) y la causa es la contraria. Ahora la primera escritura de cada bot va
rotulada `[ INICIAL: primer estado del spawn, no es una transición ]` y el reporte dice cuántas de
las que se ven son spawns, con un `!!` si pasan de la mitad. *Una ventana que se llena tiene que
decir con qué se llenó, o el que lee cree que vio todo.*

### Dos preguntas del autor

`SetNoDraw` ya no rige **para el fantasma** (r22), pero el bucle de hijos lo sigue usando **sobre un
hijo**, porque un hijo es de otro addon y no le podemos escribir su `Draw`. Y el marcador que «se
pega» al cruzar un **areaportal** es la limitación conocida del PVS, no una regresión — y ahora se
delata solo, con el `!! POS CONGELADA` de la r21.

---

## 2026-08-09 (32) — **La r23: 1 pasa · 3 sin correr. El índice reciclado queda CERRADO; el hijo no tuvo sujeto**

**Lo que sí midió (fila 04, que el autor dejó en *sin correr* para que la revisara alguien):** con más
de cien fantasmas spawneados la bitácora trajo `#89/s103` y `#89/s131`, `#100/s114` y `#100/s142`,
`#78/s1…s124`. **El `EntIndex` se recicla en segundos** y la serie desempata; ninguna línea salió con
`s?`. El defecto que hizo que la r22 se contradijera dentro de una misma pantalla queda cerrado.

### ⚠ Las otras tres no eran verdes: no tuvieron sujeto

Las tres notas dicen `hijos 0 ahora · maximo visto 0 · tocados 0`. Ninguna de las tres líneas que las
filas pedían —la del hijo con clase y modelo, el `nodraw SI`, el `[ re-aplicado: cambio la cantidad de
hijos ]`— salió. La hoja lo advertía en la rama roja y en el pie, y aun así se marcaron verdes:
*una advertencia que vive en la rama que nadie lee cuando algo sale bien no es una advertencia — el
que corre puntúa desde la rama de PASA.*

Y no fue mala suerte, la fila estaba mal pensada de dos maneras: exigía **presenciar el instante** en
que un tercero parentea algo (en la r22 pasó una vez, y pudo durar menos de un segundo), y el único
lugar que miraba hijos era el reconciliador **cuando el fantasma tiene que estar invisible** — o sea
que **la ventana abierta era la equivocada**, porque dispararle y agarrarlo con el physgun pasa con el
fantasma visible.

### Lo que entró: el censo

Un **censo de hijos global**, que sobrevive al instante *y al fantasma* — las dos cosas que le
faltaron a la r22, donde el bot que había tenido el hijo ya no existía cuando se lo fue a buscar y su
contador se había ido con él. Se muestrea siempre, no sólo con el fantasma invisible, limitado a 4
veces por segundo, y `phantasmagoria_ghost_vis` lo imprime aunque no quede ningún fantasma vivo.

⚠ **Declara su propia ceguera**: un hijo que viva menos de 0,25 s puede no aparecer nunca, así que un
censo vacío se imprime con esa advertencia al lado — *un cero tiene que decir de qué es cero*. Y el
`reset` no lo borra: para eso está `resetcenso`, que además avisa qué cambia de significado.

⚠ Escrito y movido: el censo quedó al principio **antes** de `quien()` y `anotar()`, o sea que los
habría tomado como globales `nil` — un error que sólo hubiera aparecido el día que apareciera un hijo.
*Una guarda que sólo corre en el caso raro es código sin estrenar*: se agarró leyendo el orden de
declaración, no corriéndolo.

Planilla: `dev/checks/phantasmagoria-hijo-r23b.html`.

---

## 2026-08-09 (31) — **La r22 CERRÓ la ausencia (8/8), y dos de esos verdes traían un hallazgo adentro**

`saltos del Draw 4493` y subiendo, el marcador siguiendo a un fantasma que no se ve, `ESCRITORES
AJENOS 0`, la bitácora con una línea por transición real. **§20 ① queda cerrada en juego.**

### ⚠ La alarma escrita en la r22 disparó en su primera corrida

`!! HIJO TOCADO con la tecnica vieja ( SetNoDraw ): base_gmodentity`, con `( 1 hijos )`. La r20 había
dado `hijos máximo visto 0` en toda su corrida y §20.2 lo tomó como confirmación de que el bot no
lleva nada parenteado: **ese 0 era una ausencia no medida** — decía *«en esta corrida no pasó»* y se
leyó como *«no puede pasar»*.

Y el bucle destapó un agujero propio, invisible mientras nunca corría: **el reconciliador es
idempotente**, así que un hijo que nace *con el fantasma ya invisible* no pasaba por la primitiva
nunca — un objeto dibujado colgando de un fantasma que no se ve. Entró un **tercer motivo de
re-aplicación** (cambió la cantidad de hijos), consultado sólo cuando queremos ocultar, y rotulado en
la bitácora como `[ re-aplicado: cambio la cantidad de hijos ]` — *dos causas que escriben la misma
línea necesitan que la línea diga cuál fue*.

`base_gmodentity` es la clase base genérica y no identifica a nadie, así que el instrumento imprime
ahora **modelo e índice** de cada hijo, y `phantasmagoria_ghost_vis` los lista. *No se acusa a un
tercero sin un dato que lo señale; se agranda el instrumento hasta que lo señale.*

### ⚠ La bitácora se contradijo sola dentro de una misma pantalla

El reporte de un fantasma con `serie 4` y **30 ticks de vida** decía `hijos máximo visto 0 · tocados
0` mientras la bitácora, dos líneas más abajo, mostraba un `!! HIJO TOCADO` para `#1310` y
transiciones repartidas en cien segundos. Las dos eran ciertas: **el `EntIndex` se recicla**, y ese
log tenía al menos dos fantasmas escribiendo bajo el mismo número — ya se había visto sin entenderlo,
dos `spawn #1327` seguidos con series 10 y 11. Cada línea lleva ahora `#idx/sN`, con nuestra serie,
que no se recicla. *Un identificador que el engine reusa no puede ser la clave de un registro que
sobrevive al sujeto.*

### La barra de vida tiene dueño

Es el elemento `npcid` de DGL4 (`holohud2/elements/npcid.lua`): un elemento de HUD del **cliente**,
no una entidad — así que **no tiene relación con el `base_gmodentity`**, eran dos hallazgos distintos.
Se apaga en la config de HOLOHUD2. ⚠ Perilla de otro addon y por jugador: sirve para correr las
filas, no como garantía del diseño.

Planilla: `dev/checks/phantasmagoria-hijo-r23.html` (4 filas, hoja de acecho).

---

## 2026-08-09 (30) — **La ausencia se muda al `ENT:Draw` del cliente: la técnica de HIM**

Diagnóstico cerrado por el autor: `SetNoDraw` no sirve para esto. `EF_NODRAW` en el servidor manda la
entidad a `FL_EDICT_DONTSEND` — el cliente deja de **recibirla** y se queda con una copia congelada.
Los tres síntomas de la r20 eran **uno solo**: el fantasma no se veía (bien), el marcador tampoco
(mal), y el physgun lo agarraba en la posición original.

**La salida estaba escrita en `PHANTOM_Referencia.md` §6 desde antes de empezar el bloque:** *«la
invisibilidad de HIM no es un material: el `Draw` del cliente literalmente no dibuja»*
(`terminator_nextbot_homeless/client.lua:54`). La entidad se sigue transmitiendo entera.

**De HIM se porta la técnica y NO el cableado.** Su `Draw` pregunta `self:IsSolid()`: su invisibilidad
*es* su no-solidez — el mismo acoplamiento por el que §20.1 rechazó el cloak de la base, ahora del
otro lado. Nuestro fantasma ausente es sólido a propósito. La señal nuestra es el **NW var**, la única
lectura del cliente que la r20 vio llegar bien. *Dos addons pueden necesitar el mismo dibujo y
distintas razones para dibujarlo.*

### La acreditación cambia de lugar

Ya no hay bandera que preguntar, así que se cuenta **el camino del render**: `saltos del Draw`, en
`phantasmagoria_ghost_cl`, sólo lo puede tocar la rama que se saltea el dibujado. *Un contador que
sólo puede escribir el mecanismo prueba que el mecanismo corrió; una bandera sólo prueba que alguien
la escribió.* ⚠ Y trae su precondición adentro: el `Draw` sólo corre para lo que está en pantalla, así
que un 0 con el fantasma fuera del PVS no es un rojo, es una fila que no midió.

### Tres cosas cambiaron de sujeto sin cambiar de nombre, y ninguna se borró

- **`ESCRITORES AJENOS`** medía un segundo escritor de `SetNoDraw`. Como nosotros ya no la
  escribimos, esa bandera pasa a tener un valor esperado fijo y el contador vigila a **cualquiera**
  que la ponga — con el mismo `0` de antes y un significado nuevo: *volvió el defecto de la r20*.
  *Un detector cuyo sujeto se apaga no queda en cero: queda midiendo otra cosa, y hay que decir cuál
  — o se vuelve un verde que nadie puede mover.*
- **El reconciliador** compara contra el NW var. Dejarlo leyendo `GetNoDraw()` habría hecho `real`
  siempre `true`: sobre un fantasma que la política quiere invisible, el `return` de idempotencia no
  cortaría nunca — **66 llamadas por segundo a la primitiva, la bitácora tapada y `se oculto`
  subiendo solo, sin un error de Lua**. *Cuando se cambia el mecanismo hay que preguntarse contra qué
  estaba comparando el que lo vigilaba.*
- **La guarda del cadáver**, que en la r20 midió que `BecomeRagdoll` hereda la bandera, pasa a ser una
  **predicción falsable**: ahora tiene que dejar de hablar. *Una póliza que no dice si hizo falta se
  queda para siempre; una que hace una predicción se puede sacar.*

⚠ **Lo que la técnica nueva cuesta, escrito antes de correrla:** la entidad ya no desaparece del
cliente, así que **un HUD de terceros puede delatar al fantasma invisible** — en las capturas de la
r20 hay una barra `Phantasmagoria Ghost 900|900` sobre el bot, y `FL_NOTARGET` no la tapa. Es la fila
05 de la r22, y si sale roja la salida **no** es volver a `SetNoDraw`.

⚠ **Trampa con fecha, escrita en su lugar:** el bucle sobre los hijos sigue usando `SetNoDraw` porque
un hijo es otra entidad y no pasa por nuestro `Draw`. `hijosMax` dio 0 en la r20, así que hoy no corre
nunca; si imprime `!! HIJO TOCADO`, deja de ser póliza.

Planilla: `dev/checks/phantasmagoria-draw-r22.html` (8 filas).

---

## 2026-08-09 (29) — **La ausencia ANDA (r20: 7/2/1). Las dos rojas son del instrumento, y la frase que se cayó estaba en el diseño**

Diseño §20 ①. La r20 corrió sobre `server_cloak.lua`, escrito la sesión anterior y sin una sola
pasada en juego.

**Lo que quedó cerrado, y no se re-discute:** invisible en calma y visible en hunt (03), el control
`absence 0` (04), el flag por NPC con la convar en 1 (08), `absence 2` forzando también en hunt (09),
el reconciliador corriendo (02), y los dos números que medían suposiciones del diseño en vez de
darlas por buenas: **`ESCRITORES AJENOS 0`** y **`hijos máximo visto 0`** (07) — o sea que `SetNoDraw`
sobre la entidad alcanza y el bucle sobre los hijos es póliza. La 10 cerró **con dato**:
`BecomeRagdoll` **SÍ hereda `EF_NODRAW`**, salió la línea que lo dice, y esa guarda no era decorativa.
La 06 quedó *sin correr* por lo mismo que falló el resto: *«no lo puedo ver»*.

### ⚠⚠ Lo que se cayó es una frase de §20.3, escrita como un hecho y nunca medida

> *«`SetNoDraw` … es **networkeado**, o sea que el cliente puede leer `GetNoDraw()` y decir el estado
> REAL»*

En juego, con el fantasma invisible y **fuera de la pantalla**, el cliente imprimió `render: se
dibuja · el server dice INVISIBLE`. De esa frase colgaban **las dos mitades de §20.4**: el modo
honesto nunca salteó a nadie, y la línea de HUD contó `0 invisibles` con uno delante. *Una propiedad
de la red que nadie midió sostenía el instrumento entero de un bloque.*

### ⚠ Y la fila 01 no fue roja: contestó (b), que era una de sus dos salidas verdes

`por clase 1 · por campo 1` es, **por el texto de esa misma fila**, *«el cliente LO TIENE»* — y con
eso descartó la causa (a), la que habría tumbado §20.4 de una. Se marcó roja porque el marcador
seguía sin aparecer: *puntuar una fila de diagnóstico por el síntoma que la trajo, y no por su
criterio, convierte un resultado en una falla.*

### ⭐ La tercera causa la nombra una pista escrita al margen de otra fila

> *«cuando lo tomo el physgun va a su posición original, aunque lo tenga en frente»*

Con eso, los tres hechos que no cerraban cierran juntos: **la entidad está en el cliente, pero
congelada**. Hipótesis a medir en la r21: `EF_NODRAW` manda la entidad a `FL_EDICT_DONTSEND`, el
cliente deja de **recibirla**, la copia queda con la posición vieja y con la bandera sin llegar — y
entonces **el marcador sí dibuja: dibuja donde el fantasma estaba**, que desde la pantalla se lee
igual que «no dibuja nada». El NW var llegó porque viaja por otro sistema, que es exactamente para lo
que `phantom_SetVisible` decía en un comentario que iba a servir.

### Lo que entró — `client.lua` y nada más (`server_cloak.lua` no se abrió)

- **Cuatro lecturas en vez de una**: `NW` · `GetNoDraw()` · `IsEffectActive( EF_NODRAW )` ·
  `IsDormant()`, impresas juntas, con el `!!` que dice cuál de las dos divergencias posibles salió.
  *El principio de §20.4 —preguntarle al destino y no a la fuente— era correcto; el defecto fue
  elegir un solo campo del destino sin comprobar que contestara.*
- **El que decide pasa a ser el NW var**, con el motivo escrito: no es «la verdad del render», es la
  única lectura que se pudo acreditar.
- **Un muestreador de posición**, porque *un valor congelado no se ve en una sola lectura*. Imprime
  `movimiento(s) vistos` y los segundos desde el último cambio. ⚠ Su trampa va escrita **antes** de
  correrlo: un fantasma quieto también da congelado, así que las filas piden el fantasma caminando y
  la 02 de la r21 es el control que le exige decir que NO.
- **El marcador declara su propia mentira**: `!! POS CONGELADA N s` en la etiqueta 3D y un tercer
  número en la línea de HUD.

Planilla nueva: `dev/checks/phantasmagoria-render-r21.html` (7 filas). ⚠ **Si la 01 sale (a′),
`SetNoDraw` deja de servir para ① *y* para ②** — y la salida que §20.3 tenía escrita para el parpadeo
(networkear el horario al cliente) **cae con ella**. El reemplazo se decide **después** de cerrar la
hoja: cambiar cómo se vuelve invisible el fantasma es cambiar la mecánica que se está midiendo.

---

## 2026-08-09 (28) — **`speed.base` CERRADO en juego**, y dos rondas de instrumento para llegar (r18: 8/8 con tres verdes falsos · r18b: 5/5)

Diseño 5.1. `phantom_SetType` escribe `phantom_SpeedMul` con el `speed.base` del tipo, y ese campo
gana sobre la convar andamio. Va en **la puerta única** y no en el spawn, porque
`phantasmagoria_ghost_type <key>` cambia el tipo de un fantasma **vivo**.

**Medido en juego, en los dos sentidos y sobre la misma `serie`:**

| | `multiplic.` | `objetivo` | `convertidas run` | `deseada` / `real` |
|---|---:|---:|---:|---:|
| Deogen `x0.235` | x0.235 | 66 | 66 | 66 / 66 |
| Revenant `x0.588` | x0.588 | 165 | 165 | 165 / 165 |
| control `typespeed 0` + andamio en 2 | x2.000 **de convar** | 560 | 560 | *«salió volando»* |

Y las tres piezas de plomería: `campo VACIO · motivo: typespeed 0` con el tipo intacto, `SIN TIPO`
sin línea `!!` de residuo, y `SON 11 DE 30` con la lista de los tipos que discriminan.

### ⚠ La r18 salió 8 de 8 y tres de esos verdes imprimieron el número del tipo ANTERIOR

`phantom_ApplyTypeSpeed` invalidaba el caché **del factor** (`phantom_speedNext = 0`) para que el
próximo tick recalculara. Recalcula — **pero el reporte no lee el factor: lee `phantom_speedDbg`**,
que sólo se reescribe en ese recalculo. Y **dos concommands en la misma línea corren en el mismo
frame**, sin tick en el medio. La 05 lo dijo en una sola pantalla: `x0.588 de campo
phantom_SpeedMul ( tipo )` con **`campo VACIO` dos líneas abajo**.

*Invalidar un caché no actualiza lo que ya se calculó de él: marca que hay que recalcular, y el que
imprime no es el que recalcula.*

**La 06 fue el control sin que ninguna fila lo pidiera:** el mismo comando, dos veces, sobre el mismo
estado — encadenado `x1.000 / 280`, solo y 16 s después `x0.235 / 66`. Y las notas del autor
(*«se puso más rápido»*, *«va más rápido aún»*) concuerdan con los valores **verdaderos** y no con los
impresos: la impresión del operador fue mejor instrumento que la consola, porque la consola tenía un
caché adentro.

**Y la 03 pasó por casualidad**: habían pasado 0,6 s y el tick ya había refrescado. *Una fila que pasa
porque el operador tardó en tipear no midió nada.*

### ⚠ Y arreglarlo movió el problema un eslabón abajo (r18b)

Con `dbg` ya fresco (`[ foto de hace 0.00 s ]`), tres filas quedaron con `convertidas run 165` al lado
de `deseada 280`. **Esta vez el número no está mal:** `deseada` sale del locomotion, que lo escribe
`SetupSpeed` **en el tick**, así que en el frame del cambio todavía tiene el valor anterior — y el bot
de verdad va a la velocidad vieja un tick más. **El defecto era del criterio**, que pedía que las dos
coincidieran en la misma salida: imposible en el frame de un cambio. Las tres pasaron porque el autor
volvió a tipear el comando solo, sin que ninguna fila se lo pidiera.

*En una cadena de valores derivados, cada eslabón tiene su propio instante: arreglar el caché de
arriba deja al descubierto al lector de abajo.*

### Lo que entró al instrumento, y cada cosa por una fila que falló

- **Sello de tiempo en la foto** (`[ foto de hace N s ]`) y comparación contra el estado en vivo, con
  un `!! ESTA FOTO YA NO VALE` que dice cuánto valdría ahora. El reporte ya comparaba el campo contra
  la tabla y esa comparación funcionó; **nadie estaba comparando el campo contra el multiplicador
  impreso tres líneas arriba**.
- **`phantom_ApplyTypeSpeed` recalcula en el acto** — sólo si ya había foto: en el spawn no, porque
  `phantom_speedDbg == nil` es la única prueba de que el callback nunca corrió.
- **`phantasmagoria_ghost_speedmul` ganó su propio callback**, que es lo que le faltaba a la 03.
- **`deseada` se compara contra las tres `convertidas`** y, cuando no coincide, el reporte nombra las
  dos causas **separándolas por lo que pasa en la lectura siguiente**.
- **El tipo se nombra en el reporte de velocidad.** La 04 de la r18b pedía *«y el tipo sigue diciendo
  Revenant»* sobre una salida que **no imprime el tipo**: la única pista era `top x1.765`, que también
  es la del Deogen. *Un check no puede pedir un dato que el comando no imprime, y una pista parecida
  no lo reemplaza.*
- **`phantasmagoria_ghost_type lista` cuenta los tipos que discriminan.** El default de la convar
  andamio es `1.0` y **19 de los 30 tipos traen `speed.base` exactamente 1.000**: sobre cualquiera de
  esos, el enganche roto y el enganche andando imprimen el mismo número.

### Lo que queda

- **La 05 de la r18b está *Sin correr*** y lo dice su propia salida: `ghost_speed` imprimió *«no hay
  ningun fantasma vivo»* — el fantasma se spawneó después. Residual de **un comando**.
- **`speed.top`, `isRange`, `alt` y `losSpeedUp` no se toman** (13 de los 30 traen segunda velocidad):
  se imprimen marcados como no usados. Es §5.1 entero y va después.

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

## 2026-08-08 (26) — Ronda 15b CORRIDA: **6 de 6, la tajada A CERRADA en juego** — y una fila mía pedía algo imposible

**Cerrado con evidencia dura.** `84 modelos ( 66 propios )` en la línea del cargador: el **84 = 18 +
66** prueba de una sola vez que la fusión corrió **y** que el orden de carga es el bueno. El serial
hizo decidible lo que la r15 no pudo (`#397 serie 1` Myling contra `#156 serie 2` SIN TIPO — dos
sujetos, no uno que perdió el dato). Y **cinco masas corregidas en juego**, con el `antes` en
**1.50 kg en las cinco**, o sea que el censo de los 66 estaba bien medido:

```
masa corregida: .../crucifix_i.mdl     1.50 kg -> 0.60 kg
masa corregida: .../crucifix_ii.mdl    1.50 kg -> 0.60 kg
masa corregida: .../crucifix_iii.mdl   1.50 kg -> 0.60 kg
masa corregida: .../tripod_i.mdl       1.50 kg -> 2.00 kg
masa corregida: .../salt_i.mdl         1.50 kg -> 0.30 kg
```

El crucifijo se verificó además **por fuera del log**, con el weight tool: *dos instrumentos
independientes sobre el mismo hecho*.

### Corrección del autor, aplicada

**Los crucifijos II y III son metálicos** — la tabla los tenía en `item`. Es exactamente para lo que
salió como propuesta. ⚠ **El tier I no se tocó:** el autor no se pronunció sobre él. En el juego el
tier 1 es de madera, pero eso es lectura mía y no su decisión. *Una enmienda sobre un eje no autoriza
a fijar de contrabando el sub-eje que el autor no votó.*

Y el generador tenía un defecto que esta corrección destapó: las excepciones enganchaban sólo por
**sufijo** (`base.endswith("_" + clave)`), así que una excepción por **modelo entero**
(`crucifix_ii`) no habría enganchado nunca — y la línea habría salido con el valor de la familia,
callada y con cara de correcta. Ahora acepta las dos formas.

### ⭐ Una fila mía pedía algo imposible, y por eso falló tres veces

La fila del networkeo se marcó verde **tres rondas seguidas** sin traer un dato del cliente, y las
tres veces se pegó la salida del **servidor**. No fue descuido del que corría: *la fila pedía pegar lo
que dice un marcador 3D, y un marcador no produce texto.* El único registro posible era la palabra del
operador o una captura.

Y el realm cliente es justo donde este taller ya tuvo algo apagado dos arranques sin un error de Lua.
**Un punto ciego histórico medido con el instrumento que no deja rastro es la peor combinación
posible.**

Entró **`phantasmagoria_ghost_cl`**: un comando **del realm cliente** que imprime, por fantasma en el
PVS, la key networkeada, si resuelve a ficha, y **el texto exacto que dibuja el marcador**. ⚠ Llama a
`typeLabel`, **la misma función que dibuja**, y eso no es ahorro: una copia sería otra medición, y el
día que las dos diverjan el comando diría que todo está bien sobre un marcador que dice otra cosa.

*Un criterio visual necesita un instrumento que produzca texto, o la fila nunca va a tener más
evidencia que la vista de alguien.*

### Los otros dos verdes con letra chica

- **La 01 pedía DOS líneas de conteo y la nota trae UNA, la del cliente.** Por el criterio literal era
  rojo. **No lo es, y lo prueban las filas vecinas:** el comando de tipos corre en el servidor y dijo
  `30 tipos cargados`; el fantasma recibió tipo al spawnear; y el hook de masas —que es
  `PlayerSpawnedProp`, servidor— imprimió cinco correcciones. *El veredicto es correcto y la fila no
  lo probó: lo probaron sus vecinas.*
- **La 06 pasó midiendo la rama de al lado.** Salió `no la escribimos y no cambia hace 1.2 s
  ( parado )` —honesto y correcto—, pero **la rama corregida pide `cambio hace ≤ 1 s`** y con 1,2 s no
  se pasa por ahí. La rama nueva **no se ejerció**: provocarla pide leer dentro del primer segundo tras
  frenar, una ventana más corta que el trámite de tipear. Va con muestreador.

**Residual:** la 02 volvió a traer un solo fantasma en la salida, así que *«al vivo no se le borra el
tipo»* sigue sin medirse — ahora con el serial ya quitando la ambigüedad que lo hacía peligroso.

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

  > ⚠ **REFUTADO el 2026-08-09** (ver §11.2 del diseño y la entrada de eventos paranormales).
  > Son **tres** call sites, no uno: `:612` está muerto, pero `:1040` y `:1055` iteran `activeGhosts`
  > y **corren en el servidor**. Esta entrada se deja como estaba porque es el registro de lo que se
  > midió aquel día; la corrección va acá abajo y no encima.

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
