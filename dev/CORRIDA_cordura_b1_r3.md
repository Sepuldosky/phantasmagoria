# CORRIDA — la cordura, tajada B1 · r3 (2026-08-20)

Planilla: `dev/checks/phantasmagoria-cordura-b1-r3.html` (6 filas, fuera de git).
Módulo: `lua/autorun/phantasmagoria_sanity.lua`.
Anteriores: [`CORRIDA_cordura_b1_r1.md`](CORRIDA_cordura_b1_r1.md) · [`CORRIDA_cordura_b1_r2.md`](CORRIDA_cordura_b1_r2.md).

**Resultado: 5 pasa · 0 falla · 1 sin correr (de 6).** El rojo de la r2 **cerró**, y la corrida
destapó **dos defectos del instrumento — uno de ellos mío, en esta misma planilla**.

---

## 1. Lo que cerró

### ⭐⭐⭐ La 02 midió el tokenizador de Source **en el juego**, y es la única evidencia que no es inferencia

Todo lo que sabíamos del break set salía de leer `CCommand::Tokenize`. La 02 lo midió:

```
] phantasmagoria_cordura_drenar 10 evento:sound
[Phantasmagoria] ( la consola te partio la causa; se rearmo y se normalizo a 'evento_sound' )
[Phantasmagoria] drenaje plano de 10 % contra 'evento_sound' ( evento sound ): entraron -10.00 %   ->   90.00 %
```

Ese aviso **sólo puede salir si el argumento llegó partido**: el comando cuenta cuántos caracteres
tuvo que normalizar y la línea aparece si y sólo si ese contador es mayor que cero. O sea que la fila
no dice *«el arreglo anda»* —eso lo dice la 01— sino **«el defecto sigue existiendo y la defensa lo
cubre»**, que es lo que separa un arreglo de un cambio de nombre.

*Un arreglo que nadie probó contra el defecto original es un cambio, no un arreglo.*

### La 01 cierra la fila 04 de la planilla vieja

```
[Phantasmagoria] drenaje plano de 10 % contra 'evento_sound' ( evento sound ): entraron -10.00 %
    evento sound           -10.00 %   1 veces
    ultima      evento sound   -10.00 %   hace 0.0 s   ( plana )
```

`1 veces`, **sin** `en X s / N ticks`, y ningún renglón `NO DECLARADA`. Con los otros tres criterios
ya medidos en la r2, **la fila 04 queda cerrada**.

### La 03: el grito salió entero, y la lista no se truncó

```
[Phantasmagoria] ⚠⚠ 'evento_ruido' NO ES UNA CAUSA DECLARADA.
                 Se aplica igual y va a salir como '⚠ NO DECLARADA' en el desglose --
                   presencia_calma  presencia_hunt  oscuridad  evento_sound  evento_throw  ...
                   evento_creak  regen  zonasegura  med_i  med_ii  med_iii  muerte  destierro  andamio
[Phantasmagoria] drenaje plano de 5 % contra 'evento_ruido' ( ⚠ NO DECLARADA ): entraron -5.00 %
```

Las 19 en **dos** líneas, ninguna cerca de los 255 — el corte a mano funcionó. El renglón salió
**propio y separado**, no fundido en otro, y **desapareció con el reset** de la última línea del botón.

### ⭐⭐ Y la 05, aunque quedó SIN CORRER, produjo el cierre aritmético más fuerte del arco

| causa | aplicado |
|---|---:|
| presencia calma | −0,84 |
| oscuridad ( mod ) | −0,42 |
| evento sound | −5,00 |
| evento throw | −55,00 (11 veces) |
| evento door | −20,00 (4 veces) |
| `evento_ruido` ⚠ NO DECLARADA | −10,00 (2 veces) |
| **suma** | **−91,26** |

`neto −91,26`, barra `8,74`. **Brecha 0,00 con seis causas y dieciséis aplicaciones planas** — el
doble de renglones que cualquier lectura anterior, y con un bucket **no declarado** adentro. *Una
causa desconocida no rompe la contabilidad: se lleva su propio renglón y el neto sigue cerrando.*

**Está bien marcada SIN CORRER**, y el criterio es el que la propia fila escribió: hay un renglón
`NO DECLARADA` vivo, que es lo que su `pass` prohíbe. No es un escritor clandestino —es el andamio de
la 03 y los dos disparos manuales— pero **esta fila no puede distinguir esas dos cosas**, y por eso el
veredicto correcto no es verde. Le falta: un `reset`, una lectura limpia, y la mitad offline.

### La 04: nada se rompió

Hunt prende, `phantasmagoria_ghost_events` sigue contando (`light 1`, `prop 1` disparados, bitácora
con tres renglones), y el `PlayerSpawn` sigue entregando armas y playermodel.

---

## 2. Los dos defectos que destapó, y el segundo es mío

### ⭐ (A) `REAL 0.000 s ( medido )` — un imposible impreso al lado de la palabra «medido»

Leyendo el reporte justo después de un `reset`, con 0 ticks:

```
tick        pedido 0.25 s  ·  REAL 0.000 s ( medido )   ( 0 ticks, ultimo hace 0.0 s )
```

Un período de tick de **cero segundos** es imposible. La guarda contra la división por cero estaba
puesta —`ticksReales > 0 and ... or 0`— y **ése era el defecto**: devolvía `0`, que es un número, y el
renglón lo imprime con la misma cara con la que imprime `0.300`. *La división por cero no era el
problema: el problema era **contestar**.*

El costo real no es el número: es que manda a buscar un timer muerto donde lo único que pasa es que
todavía no latió — y **gasta la credibilidad de todo lo que está impreso al lado**, en un reporte cuyo
único trabajo es que se le crea. Ahora dice `-- sin medir: 0 ticks desde el ultimo reset --`.

> El mismo renglón exhibió, de paso, un **cuarto estado del cero** que la r1 no había ejercido:
> `( ⚠ su fuente 'presencia' no se interrogo ni una vez )`. La r1 separó tres ceros (*nadie la llama* ·
> *su fuente corrió y dijo que no* · *su disparador no ocurrió*); éste es el cuarto —*la fuente ni
> siquiera se interrogó*— y salió impreso correcto sin que nadie lo hubiera visto antes.

### ⚠⚠⚠ (B) La r3 corrió con `regendelay` en **30** contra los **45** del diseño — y la fila que existía para agarrarlo la escribí sin ese criterio

```
goteo       0.200 %/s   retardo 30 s   techo 80 %
```

El diseño dice **45 s**, y es una de las tres decisiones que el autor tomó esa madrugada. La convar se
movió en un A/B de la r2 (sus lecturas muestran `45`, después `30`, después `5`) y **nunca se
restituyó**: es `FCVAR_ARCHIVE`.

**El P0 de la r1 y la r2 tenía el bloque de tasas en su criterio. El P0 que escribí para la r3 no.**
Le saqué la comprobación por brevedad, y el defecto exacto que esa comprobación existía para agarrar
estaba vivo mientras la fila salía verde. *Un criterio que se saca de una precondición no deja de
existir: pasa a estar cubierto por nadie.*

**Y hay una segunda mitad, que es la que vale.** La respuesta de la r1 al nº 91 fue *«acá tenés las
ocho líneas para restituir a fábrica»*, y esa respuesta **no puede restituir un número**: las ocho son
perillas de **encendido**. Las 24 convars del bloque son `FCVAR_ARCHIVE`, y **quince de ellas son
valores** — tasas, radios, techos, retardos. Una perilla de encendido en 0 se ve en el reporte, que
imprime `presencia 0`. Un retardo movido **no se ve**: el reporte imprime `30` con exactamente la
misma cara con la que imprime `45`, y hace falta acordarse del número de diseño para notarlo.

*Cuando la defensa contra un modo de falla es una lista para pegar a mano, cubre los casos que
estaban en la lista el día que se escribió.*

#### El arreglo: `phantasmagoria_cordura_fabrica`

Restituye **las 24** y ⭐ **dice cuáles estaban movidas**. Con `--decir` sólo informa y no toca nada,
para poder leer el estado **antes** de destruirlo — que es la mitad que importa: un restaurador mudo
deja al que prueba sin saber si la corrida anterior midió con las perillas de ésta, y esa duda **no se
puede resolver después**, porque el valor viejo ya se perdió.

- El default sale de `GetDefault()`, así que cambiar un valor de diseño en su `CreateConVar` **no deja
  una segunda copia envejeciendo al lado**.
- La comparación va **por número cuando los dos lo son**: `"0.20"` y `"0.2"` son la misma perilla, y
  compararlas como texto inventaría una movida que no existe — un falso positivo justo en el
  instrumento que existe para que el que prueba confíe en el estado. Verificado en un runtime Lua real
  sobre nueve pares, 0 fallas.
- La línea entró en el criterio del **P0 de la r3**, que ahora pide
  `phantasmagoria_cordura_fabrica --decir` diciendo `EN FABRICA`.

#### Qué números quedan tocados por esto

**Ninguno de la r3**: no midió el goteo. De la r2, la lectura que importaba —la fila **02**, donde el
goteo dio `0,200 %/s` y el techo se ejerció— salió con `retardo 45 s` en su propio reporte, así que
está limpia. Lo que **sí** queda contaminado es cualquier medición futura de la **fila 03** de la
planilla de 12 (el NETO de 10-20 min), porque el retardo es justo lo que decide ese balance.

---

## 3. Los instrumentos

```
find lua -name '*.lua' -print0 | xargs -0 python dev/luacheck_gmod.py   -> 39/39 OK
python dev/parsear_sintaxis_glua.py lua                                -> 39 archivos, 0 errores
python dev/auditar_returns_de_hooks.py lua                             -> 0 de 37
python dev/rutas_de_sonido.py                                          -> 186 rutas, 0 faltantes
python dev/auditar_puerta_cordura.py lua  ·  --control                 -> 0 clandestinos · DISCRIMINA
python dev/auditar_ids_tipeables.py lua   ·  --control                 -> 0 inalcanzables · DISCRIMINA
```

Planilla: `auditar_planilla.py` **SANA** (6 checks, y su puerta de `node --check` pasa) ·
`verificar_citas_de_planilla.py --control` **DISCRIMINA**, los **15 comandos** y las **7 rutas**
resuelven.

> Una confirmación en vivo, de paso: el verificador de citas encontró los `phantasmagoria_sanity_dark`,
> `_destierro` y compañía, que viven en las **líneas 2 a 8** del botón de P0. El arreglo del ancla
> `\b` (catálogo nº 102) funciona — antes esos ocho eran invisibles.

---

## 4. Estado de B1

**Cerrada**, con una fila a medio camino.

| | estado |
|---|---|
| P0 · 00 · 01 · 02 · 04 · 05 · 06 · 07 · 08 · 09 de la planilla de 12 | **cerradas** (r1 y r2) |
| **04** (la que estaba roja) | **cerrada** por la 01 y la 02 de la r3 |
| **03** (el NETO de 10-20 min) | PASA por criterio del autor, **sin número** — y ahora se sabe que el retardo estaba en 30 |
| **10** (el desglose de la sesión entera) | **SIN CORRER**: falta un `reset`, una lectura limpia y la mitad offline |

Lo que sigue es **B2** (los ocho eventos drenando de verdad) y **C** (el gatillo que jubila
`phantasmagoria_hunt`). Handoff en [`HANDOFF_cordura_b2_y_c.md`](HANDOFF_cordura_b2_y_c.md).
