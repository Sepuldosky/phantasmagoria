# CORRIDA — la cordura, tajada B2 · r2 (2026-08-21)

Planilla: `dev/checks/phantasmagoria-cordura-b2.html` (11 filas, fuera de git) ·
[artefacto](https://claude.ai/code/artifact/11bfe22b-e87c-48e0-9cdc-c71abebf4fa1).
Anterior: [`CORRIDA_cordura_b2_r1.md`](CORRIDA_cordura_b2_r1.md).

**Resultado: 9 pasa · 0 falla · 2 sin correr (de 11).** Y las dos SIN CORRER **las marcó bien el
autor**, que es la mitad del resultado.

> ⭐⭐⭐ **EL TITULAR: las dos ramas del `math.max( tope, mayor )` quedaron medidas en juego.** El tope
> en la **04** (recortó un apilamiento de 6,23 a 3,00) y el piso en la **06** (pagó los 15 del Yurei
> contra un tope de 6). En la r1 **ninguna de las dos** se había tocado, con una fila roja y una
> verde. Tres rondas después de escribirlo, el arreglo tiene número.

---

## 1. ⭐⭐⭐ La foto se pagó sola, y en su primera salida **dio vuelta un veredicto**

La fila **02** midió lo mismo que en la r1 y salió al revés:

| | r1 | r2 |
|---|---|---|
| lo que dio | `evento throw −1.18 %` | `evento throw −0.56 %` |
| lo que se pudo leer | nada más | `x f 0.282 ( 361 u de 450, meseta 135 )` |
| veredicto | **PASA** | **SIN CORRER** |

La escena era la misma en su defecto: el prop se fue a 395 u del fantasma y el operador estaba a 29 u
del fantasma — o sea **ni la mitad A** (< 135 u del prop) **ni la B** (> 450 u del prop). En la r1 el
`−1,18 %` se leyó como *«drenó, entonces anda»*. En la r2 el instrumento dice el número que decide y
**la fila se cae sola, sin discusión y sin arqueología**.

*Eso es exactamente lo que se compró: no que la fila pase, sino que el operador pueda saber si su
verde vale.*

Y la 01 lo confirma por el otro lado — **por primera vez en todo el arco aterrizó en su número
exacto**:

```
sound  base 3.00 % ( base de la categoria )  x f 1.000 (  73 u de 450, meseta 135 )  =  3.00 %
```

En la r1 dio `−2,36 %` y hubo que despejar una ecuación dos días después para saber por qué.

---

## 2. La 04: el tope, medido — y la fila reescrita hizo exactamente lo que se le pidió

```
throw  base 2.00 %  x f 0.747 ( 215 u )  =  1.49 %
throw  base 2.00 %  x f 0.475 ( 301 u )  =  0.95 %
throw  base 2.00 %  x f 1.000 ( 117 u )  =  2.00 %
throw  base 2.00 %  x f 0.892 ( 169 u )  =  1.78 %
--  total 6.23 %  ·  mayor 2.00 %  ·  tope 3.00 %  ->  techo 3.00 % ( lo puso el TOPE )
--  RECORTADO x0.482: se perdieron 3.23 % ( 52 % de lo pedido )
```

Los cuatro criterios: `pedido 6,23 > 3,00` · `⚠ tope mordio 1 vez/veces` · `evento throw −3,00 %`
**exacto** · y ⚠ **sin línea `piso`**, con la foto diciendo `lo puso el TOPE`.

- La escala cierra: `3,00 / 6,23 = 0,4815` contra el `x0.482` impreso.
- El desglose cierra con **brecha 0,00**: `0,66 + 0,33 + 3,00 = 3,99 = 100 − 96,01`.
- El `sanobjetos` acotó como dice: `count 2 × burst 4` = **ocho epicentros**, y **cobran cuatro**.
- Y `mayor 2,00 < tope 3,00`, así que **el otro mecanismo no participó** — que es la única forma de
  que este número sea una medición del tope y no una del piso.

*El criterio (d) —«la línea `piso` NO aparece»— es el que convierte esta fila en una medición. Sin
él, `−3,00 %` es compatible con las dos ramas.*

---

## 3. La 06: el piso, medido — y la implicación vale, aunque la evidencia directa se perdió

`evento door −15.00 %` con `phantasmagoria_ghost_santope 6`.

> **Si el piso no existiera**, el techo sería 6, `total = 15 > 6`, y habría salido `−6,00` recortado.
> Que salga **15,00 exacto** sólo es posible si `techo = 15`, o sea si `mayor` levantó el techo.

Es la primera vez en el arco que el piso se ejerce. Vale también lo que la fila reescrita agregó y
funcionó: el intento que **no** llegó dio `−4,66 %` (o sea `f = 0,311`, ~352 u de la puerta) y el
operador lo descartó y repitió **en vez de anotarlo como verde** — que es lo que pasó en la r1.

⚠ **Lo que sí se perdió**: la línea `piso` y la foto del intento bueno no quedaron en el registro; lo
pegado es el reporte del intento fallido. La fila queda **cerrada por implicación aritmética**, no por
cita. Es sólido, pero conviene que la próxima corrida que toque el Yurei pegue el bloque entero.

---

## 4. La 08 salió completa por primera vez — con el criterio que la r1 declaró **imposible**

```
⚠ punto ciego: 5 luz(ces) del mapa sin getter a 300 u. De las 7 clases declaradas,
  las que se pueden preguntar son: gmod_light, gmod_lamp.
```

En la r1 escribí que el (d) era *imposible en este mapa y en ese lugar* (la luz más cercana a 1182 u
contra un radio de 300). En la r2 salió, y salió en **cinco** lecturas distintas de la sesión con
conteos distintos (1, 2, 5, 6) — o sea que **cuenta lo que hay cerca y no una constante**.

Las otras tres cierran fino:

| | `ciegamul 1.5` | `ciegamul 1.0` |
|---|---:|---:|
| `presencia calma` | −1,84 (18,6 s) | −2,82 (29,4 s) |
| `oscuridad CIEGA` | **−0,92** | **+0,00** |
| tasa efectiva | 0,0989 %/s | 0,0959 %/s |

El `−0,92` es **exactamente la mitad** del `−1,84`, que es lo que tiene que aportar un ×1,5. Y la
presencia sigue drenando igual con la perilla en 1,0: *la perilla apaga el modulador y no lo
modulado*, que era el punto de la fila.

---

## 5. ⭐⭐ La 10: de sombra a ser el control más fuerte del arco

La reescritura funcionó. La fila ya no depende de que nadie haya reseteado: **trae su propia tanda**.

```
evento sound  -3.00  ·  throw -1.12  ·  light -4.00 ( 2 veces )  ·  knock -1.22  ·  door -0.39
continuas     calma -1.21  ·  hunt -0.56  ·  mod +0.55  ·  CIEGA -0.33
muerte        +5.27
```

- **Cinco renglones de evento con `N veces`** (el criterio nuevo pedía ≥ 4). ✔
- ⭐ Los cinco eventos suman **9,73**, y el motor dice `cobros 6 · 9.73 % pedido`. **Dos contadores
  independientes —el desglose por jugador y el acumulador del motor— coinciden al centésimo.** Eso no
  lo había dado ninguna corrida del arco.
- El cierre: `−9,73 − 1,55 + 5,27 = −6,01` contra `neto −5.99` y barra `94.01`. **Brecha 0,02**, por
  debajo del 0,05 que pide el criterio.
- Ningún `NO DECLARADA`, ningún `EL DESGLOSE NO CIERRA`, `sin donde 0`, y `fabrica --decir` en fábrica.

Y dos cosas que **ninguna fila pidió y aparecieron solas**:

- **`muerte +5.27 % 1 veces`** — la vía de recuperación de §19.8.5 se estrenó en juego, con signo
  positivo y su propio renglón. Nadie escribió una fila para eso.
- **`despertadas ESPONTANEAS: 1`** — el scheduler despertó solo. El motor corre sin que lo empujen.

---

## 6. Las dos SIN CORRER, y las dos están bien puestas

| | por qué |
|---|---|
| **02** | el prop cayó a 361 u del operador: ni A ni B. Lo dijo la foto (§1) |
| **07** | (a) y (b) salieron textuales —`⚠ SIN SUJETO: 1 con el rasgo y mirado(s), pero PHANTASMAGORIA.EstaManifestado NO EXISTE`— pero **falta (c)**: que el motivo *cambie* al darle la espalda o alejarse. Sin ese cambio no se puede distinguir una fuente que mide de un renglón decorativo |

*Marcar SIN CORRER una fila que salió a mitad de camino es la decisión que más veces salvó a este
taller, y esta ronda la tomó el autor dos veces sin que nadie se lo pidiera.*

---

## 7. Lo que queda

| | estado |
|---|---|
| **09** | la luz y el hunt medidos; **falta la mitad del respawn** (armas y playermodel a ojo tras un `kill`). Hay una señal indirecta: la 10 muestra `muerte +5.27 % 1 veces`, o sea que hubo una muerte y el listener de `PlayerSpawn` corrió — pero eso **no** prueba que la cadena siguiera hasta el loadout |
| **07 (c)** | girarse y volver a leer: es un comando y diez segundos |
| **06** | cerrada por implicación; la próxima que toque el Yurei que pegue el bloque del motor entero |
| el `piso` / `6 duro` | la decisión sigue siendo del autor — pero **ya no se toma a ciegas**: hay número en juego (06) y control offline (`decidirTecho`) |

Anotado aparte en [`PENDIENTES_phantasmagoria.md`](PENDIENTES_phantasmagoria.md): el pedido del autor
de que **el Yurei abra la puerta más cercana al jugador, al doble de velocidad y ~1,5× más ruidosa**
—porque el *"must fully open / shut a door"* de la fuente **no se puede expresar en Source**— y la
anomalía no reproducida del override de tipo.

Lo que sigue es **C**: el gatillo que jubila `phantasmagoria_hunt`.

---

## 8. Las puertas

```
python dev/cordura_b2_offline.py                     -> FALLOS: 0  ( 4 ok: caida, normalizador, TECHO, fusion )
python dev/cordura_b2_offline.py --control           -> DISCRIMINA
  + sabotaje del `math.max` -> tope duro             -> DETECTADO  ( 7 gritos, y nombra el Yurei )
python dev/luacheck_gmod.py  ( las 40 )              -> 40/40 OK
python dev/parsear_sintaxis_glua.py lua              -> 40 archivos, 0 errores   ·  DISCRIMINA
python dev/auditar_returns_de_hooks.py lua           -> 0 de 39
python dev/auditar_puerta_cordura.py lua  ·  --control -> 0 clandestinos · 0 de 8 sin productor · DISCRIMINA
python dev/auditar_planilla.py <planilla>            -> PLANILLA SANA ( 11 checks )
python dev/verificar_citas_de_planilla.py <planilla> -> 12 comandos y 4 rutas resuelven  ·  DISCRIMINA
```
