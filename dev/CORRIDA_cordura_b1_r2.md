# CORRIDA — la cordura, tajada B1 · r2 (2026-08-20)

Planilla: `dev/checks/phantasmagoria-cordura-b1.html` (fuera de git, por eso el reporte se guarda acá).
Módulo: `lua/autorun/phantasmagoria_sanity.lua`. r1 en [`CORRIDA_cordura_b1_r1.md`](CORRIDA_cordura_b1_r1.md).

**Resultado: 10 pasa · 1 falla · 1 sin correr (de 12).** La roja es la **04**, y **su causa no estaba
en la cordura**.

---

## 1. El rojo, y por qué el bloque entero lo agradece

### ⚠⚠⚠ La fila 04 salió roja por el TOKENIZADOR DE LA CONSOLA, no por el mecanismo

La mitad B de la 04 pedía tipear `phantasmagoria_cordura_drenar 10 evento:sound`. Salió:

```
[Phantasmagoria] drenaje plano de 10 % contra 'evento': entraron -10.00 %   ->   82.37 %
...
    evento sound            +0.00 %   ( sin llamador todavia: los ocho eventos son B2 )
    evento ⚠ NO DECLARADA   -10.00 %   1 veces
```

El drenaje entró, pero contra una causa llamada `evento`. **El string de causa se partió antes de que
el addon lo viera.**

`CCommand::Tokenize` (tier1) parte la línea de consola con un break set que incluye `{ } ( ) ' :`, y
esos caracteres **salen como tokens propios**. Así que el argumento no llegó como uno sino como
**tres** — `"evento"`, `":"`, `"sound"` — y el comando, que leía `args[2]`, drenó contra `evento`.

**No hubo error de Lua, ni de red, ni de permisos.** El síntoma apareció dos capas más abajo,
disfrazado de defecto del receptor. *Es el pariente exacto de la truncada a 255 de la consola de
Source: el transporte le come algo al texto sin avisar y el receptor carga con la culpa.*

⚠ **El defecto vivía desde que se escribió el bloque, y los cinco instrumentos offline lo daban
verde** — `luacheck_gmod`, `parsear_sintaxis_glua`, `auditar_returns_de_hooks`, `rutas_de_sonido` y
`auditar_puerta_cordura`. Ninguno de los cinco sabe nada de la consola: el id era Lua válido, la
puerta era la única escritora y el desglose cerraba. **El único renglón del reporte que se podía
ejercer con `:` en el id no se podía ejercer nunca**, y ningún control lo miraba.

### ⭐ Lo que hizo que el rojo fuera legible en vez de invisible

Tres decisiones de diseño anteriores, todas cobrando el mismo día:

1. **Una causa desconocida NO se funde en un "otras".** Si se fundiera, el drenaje habría sumado en un
   cajón genérico o —peor— en el renglón correcto por parecido, y `evento sound` habría quedado en
   cero **con las dos mitades del reporte de acuerdo entre sí**.
2. **El `neto` cerró igual**: `−7,63 − 10,00 = −17,63`, barra `82,37`. El control del nº 89 siguió
   siendo verde *mientras* la atribución estaba mal, que es exactamente lo que ese control promete y
   lo que hace falta entender antes de leerlo como un cheque en blanco.
3. **El texto de `fail` de la propia fila 04 predecía este renglón, palabra por palabra**:
   *«`phantasmagoria_cordura_drenar` mueve el renglón equivocado → el string de causa no llega; el
   reporte lo marca como ⚠ NO DECLARADA».* La planilla se escribió anticipando el modo de falla y
   después lo encontró. *Un criterio de rojo que nombra la salida exacta convierte una lectura rara
   en un veredicto.*

### Y lo que la 04 SÍ probó, que es tres cuartos de la fila

La roja se llevó **un** criterio de cuatro. Los otros tres salieron:

| criterio | medido |
|---|---|
| (a) adentro, la fuente dice `ACTIVA` con motivo | `calma · #612 a 176 u · 1 en la esfera` |
| (b) afuera **deja de crecer** | `presencia hunt` **congelado en −1,85 % / 9,0 s / 30 ticks** en las dos lecturas |
| (c) la continua se imprime `en X s / N ticks` | sí, en los tres renglones continuos |
| (d) la plana se imprime `1 veces`, sin segundos ni ticks | **sí** — `1 veces`, y `ultima ... ( plana )` |

O sea: **las dos formas ya son distintas y el instrumento las distingue.** Lo que falló fue *contra
qué renglón* cayó la plana, no *qué forma* tenía. Y `ultima ... hace 11,2 s ( continua )` en la
lectura de lejos es la prueba directa de que la continua **dejó de aplicar** al romperse la condición
— que es lo que la fila existe para demostrar y lo que habilita el rasgo del Phantom.

---

## 2. Lo que la r2 CERRÓ, y la r1 no había podido

### ⭐⭐ El techo de 80 se EJERCIÓ (fila 02), y el sobrante quedó medido

La r1 dejó la 02 con 2 de 4 criterios: el techo *decidido esa noche* no se había ejercido nunca.

```
goteo pasivo           +40.09 %   en  200.7 s / 669 ticks   [ potencial +40.14 % ]
SEPULDOSKY   cordura 80.00 %
```

- **669 ticks × 0,300 s = 200,7 s**, y `200,7 × 0,200 %/s = 40,14 %` = **el potencial, clavado**.
- El **aplicado** es 40,09: los **0,05 que sobraban los comió el techo**, y el desglose los deja
  afuera en vez de acreditárselos.
- La barra quedó en **80,00**, no en 80,09.

*El par potencial/aplicado no estaba pensado para medir el techo —se puso para las perillas de
control— y terminó siendo el único lugar donde el techo se ve como número.*

El cierre: `−0,06 − 0,03 + 40,09 − 60,00 = −20,00`, barra `80,00`. **Brecha 0,00.**

### ⭐⭐ El clamp en 0 se midió igual de fino (fila 05, mitad B)

```
presencia hunt         -20.01 %   en  159.3 s / 531 ticks   [ potencial -36.50 % ]
oscuridad ( mod )       -9.99 %   en  159.3 s / 531 ticks   [ potencial -18.25 % ]
SEPULDOSKY   cordura 0.00 %
```

`−20,01 − 9,99 − 70,00 (andamio) = −100,00`, barra `0,00`. **Brecha 0,00 con la barra en el piso** —
el otro extremo del rango, que ninguna lectura de la r1 tocó.

Y el modulador: `−18,25` es **exactamente la mitad** de `−36,50`, que es lo que tiene que dar un ×1,5
descompuesto en base + delta.

### ⭐ El modulador ×0,5 se midió por PRIMERA VEZ (fila 09)

Todas las lecturas de la r1 y casi todas las de la r2 salieron `a oscuras`. La 09 fue la única con
`luz  ILUMINADO  ( linterna )`:

```
presencia calma         -0.94 %   en   12.6 s / 42 ticks
oscuridad ( mod )       +0.47 %   en   12.6 s / 42 ticks
```

**El delta del modulador es POSITIVO y vale la mitad exacta.** La rama iluminada del ×0,5 nunca se
había ejercido, y sale con el signo correcto: la luz **devuelve** la mitad del drenaje base.

### El resto de los cierres numéricos

| fila | qué | medido | diseñado |
|---|---|---|---|
| 00 | control con la esfera ocupada | `100.00` clavada, **97 ticks (29,1 s)**, potenciales `−0,80` calma + `−7,08` hunt y `−3,94` oscuridad = **la mitad exacta de 7,88** | — |
| 01 | presencia calma **en la meseta** (63 u) | `8,48 % / 87,6 s` = **0,0968 %/s** | 0,100 %/s |
| 02 · 08 | goteo pasivo | **0,200 %/s** en las dos lecturas (`40,09/200,7` y `8,64/43,2`) | 0,200 %/s |
| 05 | goteo suprimido | `4 ticks × 0,3 s × 0,200 = 0,24 %` = **el potencial, exacto** | — |
| 07 | los tres tiers | `+25 / +40 / +60`, tres sonidos distintos, sin errores de Lua | §19.9.7 |
| 08 | los tres ítems en Cargo | modelo, precio, trivia, `Use`, **stackean en el inventario** | §19.9.7 |

> ⚠ **La 01 mejoró y sigue 3 % baja.** La r1 midió `0,070 %/s` y lo explicó por la caída (188-214 u);
> la r2 midió **a 63 u, adentro de la meseta**, y dio `0,0968`. La explicación de la r1 queda
> confirmada, y el 3,2 % que falta es tiempo de caminata: el reporte da un solo promedio y el jugador
> no estuvo quieto. *No hay defecto que perseguir acá, pero tampoco hay que anotarlo como 0,100.*

---

## 3. Lo que se arregló DESPUÉS de la corrida

Todo en `lua/autorun/phantasmagoria_sanity.lua`, más un instrumento nuevo.

### (a) Los ocho ids de evento pasan a guion bajo

`evento:sound` → `evento_sound`, y los siete hermanos. Quedan alineados con los que ya estaban bien
(`presencia_calma`, `med_i`). **Ningún otro archivo los usaba**: B2 todavía no existe y el diseño
(§19.9.5) no fija el string, así que el rename no rompe nada.

### (b) ⭐ El control de arranque, que es lo que hacía falta y no el rename

Un check que verifique *«los ocho llevan guion bajo»* sale verde por construcción el día que se
escribe y **no cubre a la causa número 20** (catálogo nº 42). Lo que se agregó verifica **la
propiedad sobre las 19 causas declaradas**: ningún id lleva un carácter que el transporte parta
(`{ } ( ) ' : ; " espacio tab`). Una causa de B2 escrita con dos puntos vuelve a encender el rojo, en
el arranque y por consola.

⚠ La búsqueda va con `string.find( id, ch, 1, true )` — **comparación literal, sin patrones**. Buscar
un carácter de puntuación *como patrón* es justo lo que convierte un control en un adorno que siempre
pasa.

### (c) El comando queda con tres defensas, porque el rename no protege al que TIPEA

1. **Rearma** la causa juntando todos los argumentos desde el segundo (`evento` + `:` + `sound`).
2. **Normaliza** los caracteres que rompen a guion bajo, así que `evento:sound` —lo que dice la
   planilla vieja y lo que la mano ya aprendió— sigue llegando al renglón correcto, y **avisa** que la
   consola lo partió. El aviso se decide **antes** de bajar a minúsculas: escribir `Evento_Sound` no
   es que la consola te haya partido nada, y decírselo manda a buscar un defecto que no está.
3. ⭐ **Si la causa no está declarada, lo grita en el acto** y lista las 19. El reporte ya la marcaba
   `⚠ NO DECLARADA`, pero eso se lee **dos pantallas después y con la corrida ya gastada**. Se aplica
   igual —no se rechaza— porque el renglón NO DECLARADA es una **función** del instrumento y B2 tiene
   que poder estrenarla a propósito.

Verificado en un runtime Lua real (lupa), sobre la forma de tokens que la consola produce de verdad:

| lo que llega | resuelve a | ¿avisa? |
|---|---|---|
| `"10","evento",":","sound"` | `evento_sound` | sí |
| `"10","evento:sound"` | `evento_sound` | sí |
| `"10","evento_sound"` | `evento_sound` | no |
| `"10","Evento_Sound"` | `evento_sound` | **no** (sólo mayúsculas) |
| `"10"` | `evento_sound` (default) | no |

### (d) `dev/auditar_ids_tipeables.py` — el mismo control, sin juego

Barre el texto fuente de la tabla `CAUSAS` y sale 1 si algún id lleva un carácter del break set.
`--control` inyecta **el defecto de la r2 tal cual** sobre una copia del árbol real y exige
detectarlo.

```
causas declaradas   19
con caracter roto   0
IDS INALCANZABLES DESDE LA CONSOLA: 0

CONTROL
  arbol limpio  -> 0 ids rotos de 19   ( se pedia 0 )
  ok dos puntos en un id     inyectados 1, detectados 1
CONTROL: el instrumento DISCRIMINA
```

⚠ **No reemplaza al de arranque, y no al revés.** Éste corre sin juego sobre el texto; el otro corre
en el realm donde el defecto muerde. Y **no reemplaza a `auditar_puerta_cordura.py`**: ese mide
*quién escribe*, éste mide *quién puede ser nombrado*. Son dos preguntas distintas y la r2 probó que
un árbol puede estar verde en la primera y roto en la segunda.

---

## 4. Lo que queda abierto

> **La planilla de la r3 ya está escrita:** `dev/checks/phantasmagoria-cordura-b1-r3.html`, **6 filas**,
> artefacto en <https://claude.ai/code/artifact/8c6dc8ac-b4bb-408b-9fbe-bd030efeea85>. No repite
> lo que la r2 cerró — sólo lo que quedó, más las dos filas que el arreglo trajo con él.

### 🔜 La 04, de nuevo — y sólo su mitad B

Tres de sus cuatro criterios ya están medidos y no cambian. Con el arreglo puesto, la mitad B son
**dos líneas**: `phantasmagoria_cordura_drenar 10 evento_sound` y leer. Tiene que salir
`evento sound   -10.00 %   1 veces` y **ningún** renglón `NO DECLARADA`.

### 🔜 La 10, que quedó sin correr

Es la última por diseño (pide la sesión entera sin resetear) y la 04 la interrumpió. Sus dos mitades
offline **ya están verdes**; falta la lectura en juego al final de la próxima sesión.

> ⚠ Y hay algo que anotar antes de correrla: la r2 **produjo** un renglón `NO DECLARADA`, que es
> justo lo que el `pass` de la 10 prohíbe. No fue un escritor clandestino sino el andamio con una
> causa partida — pero la 10 **no puede distinguir esas dos cosas**, así que si vuelve a aparecer hay
> que mirar quién lo produjo antes de leerlo como un rojo del bloque.

### ⚠⚠ El punto ciego de la luz creció, y decide un TERCIO del drenaje

El reporte lo viene diciendo en cada lectura, y en la r2 llegó a **25 luces del mapa sin getter**:

```
luz  a oscuras  ( nada legible cerca ( 25 luces del mapa sin getter: no se pueden interrogar ) )
⚠ punto ciego: 25 luces del mapa sin getter
```

`a oscuras` es el **default cuando no hay nada legible**, y el ×1,5 aporta **un tercio del drenaje
total** en toda lectura a oscuras de esta corrida. O sea: *el modulador está decidiendo un tercio del
número sobre una lectura que el propio instrumento declara que no puede hacer.* No es un rojo —el
reporte no miente, avisa— pero **es lo primero que B2 tiene que cerrar** cuando suba `LIGHT_CLASSES`
de `server_events.lua` a `lua/phantasmagoria/`: de las seis clases, hoy sólo `gmod_light` y
`gmod_lamp` tienen getter.

### 📌 La 03 quedó marcada PASA sin número en el reporte pegado

El autor la dio por buena (*«esa sí la probamos»*). Es la única fila del run cuyo veredicto **no tiene
una lectura de `phantasmagoria_cordura` al lado**, así que queda anotado: si el balance de la 03
—cruzar el 50 % entre 10 y 20 min— se va a usar para decidir tasas antes de B2, conviene una lectura
con número.

---

## 5. Los instrumentos, después del arreglo

Todos verdes el 2026-08-20, sobre el árbol ya parcheado:

```
find lua -name '*.lua' -print0 | xargs -0 python dev/luacheck_gmod.py   -> 39/39 OK
python dev/parsear_sintaxis_glua.py lua                                -> 39 archivos, 0 errores
python dev/auditar_returns_de_hooks.py lua                             -> 0 de 37
python dev/rutas_de_sonido.py                                          -> 186 rutas, 0 faltantes
python dev/auditar_puerta_cordura.py lua                               -> 0 clandestinos
python dev/auditar_puerta_cordura.py --control                         -> DISCRIMINA (3/3)
python dev/auditar_ids_tipeables.py lua                                -> 0 inalcanzables   [ NUEVO ]
python dev/auditar_ids_tipeables.py --control                          -> DISCRIMINA (1/1)  [ NUEVO ]
```

Y los de planilla, en el `dev/` del workspace (fuera de git):

```
python dev/auditar_planilla.py ...                      -> PLANILLA SANA, 12 checks sin correr
python dev/verificar_citas_de_planilla.py ... --control -> DISCRIMINA; 19 comandos y 7 rutas resuelven
python dev/parsear_cmds_planilla.py ...                 -> 0 comandos
```

> ⚠ **Ese último `0` es legítimo y conviene dejarlo escrito para no volver a mirarlo con sospecha:**
> `parsear_cmds_planilla.py` sólo valida los `lua_run` de un botón, y esta planilla **no tiene
> ninguno** — todas sus filas son concommands. No es un barrido ciego; es un barrido sin sujeto. La
> diferencia se comprueba en un segundo corriéndolo sobre `phantasmagoria-hunt-directo-r1.html`, donde
> sí encuentra comandos (y reporta uno mudo).
