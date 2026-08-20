# CORRIDA — la cordura, tajada B1 · r1 (2026-08-20)

Planilla: `dev/checks/phantasmagoria-cordura-b1.html` (fuera de git, por eso el reporte se guarda acá).
Módulo: `lua/autorun/phantasmagoria_sanity.lua`. CHANGELOG **(61)**.

**Resultado: 4 pasa · 0 falla · 8 sin correr (de 12).** Ninguna roja.

---

## 1. Lo que la corrida CERRÓ, y es más de lo que dice el conteo

### ⭐⭐⭐ El desglose CIERRA contra la barra en las CUATRO lecturas, a cero exacto

Es el resultado más fuerte del run y no lo mide ninguna fila sola: sale de cruzar las cuatro.

| fila | inicial | suma del desglose | predice | barra | brecha |
|---|---:|---:|---:|---:|---:|
| P0 | 100 | −0,51 | 99,49 | **99,49** | **0,00** |
| 00 | 100 | 0,00 | 100,00 | **100,00** | **0,00** |
| 02 | 100 | −45,90 | 54,10 | **54,10** | **0,00** |
| 03 | 100 | −11,90 | 88,10 | **88,10** | **0,00** |

Cuatro estados distintos —control, andamio, goteo, presencia con modulador— y la aritmética cierra
en los cuatro. **La mitad en juego de la fila 10 ya está prácticamente probada**: no hay ningún
escritor fuera de la puerta. Falta sólo correrla formalmente al final de una sesión.

### La fila 00 es un control de verdad, no un cero

`cordura 100.00` clavada, **103 ticks con el fantasma en la esfera (30,9 s)**, y el renglón con
`[ potencial −2,73 %, CONTROL: phantasmagoria_sanity_presencia en 0 ]`. Los tres a la vez, que es
exactamente lo que la fila pedía. *Un cero con 103 ticks al lado no se puede confundir con un cero de
«nunca pasó nada».*

Y el potencial de `oscuridad ( mod )` salió **−1,36 %, la mitad exacta de −2,73** — o sea que el
modulador ×1,5 estaba calculándose bien **aun con la causa suprimida**, que era el arreglo puesto
horas antes de correr.

### La fila 01 discrimina el HUNT, y el número lo confirma

| | medido | diseñado |
|---|---:|---:|
| calma | 0,070 %/s | 0,100 %/s en la meseta |
| hunt | 0,268 %/s | 0,350 %/s en la meseta |
| **razón hunt/calma** | **3,84** | **3,50** |

Las dos absolutas quedan por debajo porque no estuvo en la meseta (factor ~0,72 y ~0,77 — el reporte
decía 188-214 u, o sea en la caída lineal). **Pero la razón entre las dos no depende de dónde estés
parado**, y salió 3,84 contra 3,50. *Una razón entre dos ejes de la misma corrida cancela lo que la
medida absoluta no puede.* El discriminante del hunt funciona.

### El goteo pasivo da su número clavado

**14,10 % en 70,5 s = 0,200 %/s exacto.** Es la tasa que se eligió esta madrugada, medida sin
tolerancia.

---

## 2. Lo que la corrida DESTAPÓ

### ⚠⚠⚠ (A) El techo de 80 hace que los primeros 20 puntos sean de UNA SOLA DIRECCIÓN

En la fila 03: `regen inactiva 0/3198 muestras`, motivo *«en el techo del goteo ( 80 % )»* — con la
barra entre 100 y 88,10 **todo el tiempo**. O sea: **el goteo pasivo no actuó ni un solo tick en 16
minutos de juego.**

Es correcto por construcción y es **consecuencia directa de la decisión del techo**, pero ninguno de
los dos lo calculó al decidirla. La aritmética de §19.8.5 —el punto de equilibrio en f = 2/3— **sólo
vale por debajo de 80**. Arriba de 80 no hay equilibrio que calcular: la barra sólo baja.

**No es un defecto y probablemente es lo que se quiere** (arranque que drena, recuperación que
aparece cuando ya perdiste algo), pero queda escrito acá y en §19.8.5 para que no se descubra dentro
de tres meses leyendo un `0/3198`.

### ⚠⚠ (B) Tres defectos DEL INSTRUMENTO, los tres arreglados en el mismo día

1. **`( sin llamador todavia )` mentía sobre 9 de los 20 renglones.** Tres estados distintos se
   imprimían con el mismo texto: *nadie la llama* (los ocho eventos, cierto), *su fuente corrió y dijo
   que no* (`goteo pasivo` en la fila 03 — su fuente se interrogó **3.198 veces**), y *su disparador
   existe y no ocurrió* (la muerte, el destierro, una dosis). Decirle «sin llamador» al goteo manda a
   buscar un enganche que existe y funciona. Ahora cada causa lleva un campo `prod` y el renglón vacío
   dice cuál de los tres ceros es, con el número de interrogaciones y el último motivo.
   *Es el mismo defecto que este módulo existe para no pagar, y lo tenía el instrumento adentro.*

2. **El mensaje del techo escondía el hallazgo (A).** Decía *«en el techo del goteo ( 80 % )»* con la
   barra en 88,10 — se lee como «ya terminó su trabajo» cuando la verdad es «todavía no empezó y no va
   a empezar hasta que bajes de 80». Ahora dice
   `POR ENCIMA del techo del goteo ( 88.1 > 80 ): no actua hasta bajar de 80`.

3. **El tick impreso era el PEDIDO y no el real.** El reporte decía `0.25 s`; derivado de
   `segundos / ticks` en las cuatro lecturas, el período real es **0,300 s** — un 20 % más, porque el
   timer late a 0,05 y el tick sale en el primer latido que pasa el umbral. **Las tasas no se ven
   afectadas** porque el `dt` se mide (el goteo dio 0,200 clavado), pero *un instrumento que imprime lo
   que se pidió en el lugar de lo que pasa acredita el pedido y no el efecto*. Ahora imprime los dos.

### ⚠⚠⚠ (C) Dos perillas `FCVAR_ARCHIVE` quedaron en 0 desde la fila 00

El reporte de la fila 03 salió con **`destierro 0`** y **`eventos 0`**. La fila 00 las apaga a
propósito y el paso de volverlas a 1 se saltó — que es exactamente el catálogo nº 91, y las convars
`FCVAR_ARCHIVE` **siguen guardadas después de cerrar el juego**.

Todavía no mordió porque las filas que las necesitan no se corrieron. **Corridas así habrían salido
rojas por la perilla y no por el mecanismo:**

| fila | perilla que le falta | qué habría pasado |
|---|---|---|
| **09** los desenlaces | `destierro 0` | la mitad B (matar al fantasma) no restaura nada |
| **04** las dos formas | `eventos 0` | el drenaje plano de la mitad B se suprime |
| **07** la medicación | `meds` | (ya estaba en 1 en la fila 03) |

**Arreglo aplicado:** las tres filas llevan ahora la perilla **en el botón**, como primera línea del
comando. *Una salida que no se puede producir sin la precondición vale más que una precondición bien
escrita* (nº 70a) — y a las 6 de la mañana eso no es una frase, es la diferencia entre una ronda y dos.

### ⚠ (D) La fila 02 está marcada PASA y midió DOS de sus cuatro criterios

Verificados: la fuente pasa a `ACTIVA` con el motivo correcto (*«lejos y sin drenaje hace 115 s»*), y
el goteo acumula a **0,200 %/s clavado**. **No verificados:** (a) la lectura a los 30 s adentro del
retardo, y (d) **que la barra se detenga en 80,00** — la corrida terminó en 54,10.

O sea que **el techo de 80, que es una de las tres decisiones de esta madrugada, no se ejerció**. No
la marco yo; queda anotado para que se complete: alcanza con dejar correr el goteo ~130 s más desde
donde quedó y leer una vez.

### ⚠ (E) La fila 03: SIN CORRER está bien puesto, y su nota explica por qué

959 s (16 min) y la barra en 88,10 %. Extrapolado, llegar a 50 % daría **~67 minutos**, muy fuera de
la ventana de 10-20. **Pero la corrida no refuta los números, porque midió otro escenario**, y el
propio reporte lo dice con tres datos:

- `presencia 716/3198 muestras activa` = **22 % del tiempo dentro de la esfera** (su nota: *«no
  siguiendo al fantasma aquí en el asilo que es gigante»*).
- **75 % del drenaje ocurrió ILUMINADO**, o sea a ×0,5 (derivado del `+4,07 %` de `oscuridad ( mod )`
  contra el `−15,97 %` de base). Su nota: *«estoy con la linterna en todo momento»*.
- El goteo no actuó nunca, por el hallazgo (A).

*Una medición sólo refuta lo que sabe leer.* Con la linterna prendida y a 22 % de exposición, esta
corrida no puede juzgar los números — y el instrumento alcanzó para decirlo, que es lo que se le
pedía. Para que la fila 03 mida lo suyo hace falta **investigar cerca del fantasma** y aceptar la
oscuridad parte del tiempo.

---

## 3. Lo que queda

- **Completar la 02**: dejar subir el goteo hasta 80 y comprobar que ahí se detiene.
- **Correr 04, 05, 06, 07, 08, 09 y 10**, ya con las perillas metidas en el botón.
- **Rehacer la 03** con exposición real al fantasma, y anotar los cuatro valores (5/10/15/20 min).
- **B2** sigue siendo lo siguiente después de cerrar esta planilla.

---

## 4. El reporte pegado, íntegro

Tal cual salió del botón «Copiar reporte». **No se edita**: es el registro de con qué se midió.

```
REPORTE — Phantasmagoria r1 · la cordura, tajada B1: la variable, las dos formas de drenaje, la presencia, la recuperación y el desglose por causa
Pasa 4 · Falla 0 · Sin correr 8  (de 12)

P0 [PASA] ⚠⚠⚠ SE CORRE PRIMERO · sin esta fila ninguna otra se puede leer — El módulo cargó, las tres fuentes continuas están registradas y las ocho perillas son FCVAR_ARCHIVE: una que quedó de un A/B viejo invalida la planilla entera sin decir nada
   nota: ] phantasmagoria_cordura
         [Phantasmagoria] CORDURA -- Diseno 19.8, tajada B1
           tick        0.25 s   ( 180 ticks, ultimo hace 0.0 s )
           inicial     100 %
           fantasmas   1   ( via PHANTASMAGORIA.EachGhost )
           items Cargo registrados ( disparo: InitPostEntity )
           FUENTES CONTINUAS -- la forma que el rasgo del Phantom va a necesitar
             presencia      ACTIVA     14/176 muestras activa   ultimo motivo ( SEPULDOSKY ): calma · #32 a 188 u · 1 en la esfera
             regen          inactiva   0/176 muestras activa   ultimo motivo ( SEPULDOSKY ): en el techo del goteo ( 80 % )
             zonasegura     inactiva   0/176 muestras activa   ultimo motivo ( SEPULDOSKY ): la zona segura de §18.1 no esta escrita ( sin entidad camion y sin veto terminator_blocktarget
                     )
           PERILLAS DE CAUSA   ( 0 = control; suprimen el EFECTO, nunca la cuenta )
             presencia 1   ·  eventos 1 ( ANDAMIO: sin llamador hasta B2 )
             regen 1   ·  safe 1 ( sin sujeto: la zona no existe )   ·  meds 1   ·  muerte 1   ·  destierro 1
             oscuridad 1   ( MODULADOR, no causa )
           TASAS Y GEOMETRIA   ( renglon aparte a proposito: son numeros continuos )
             presencia   calma 0.100 %/s   hunt 0.350 %/s
             esfera      radio 400 u   meseta 150 u   en hunt x1.50 ( 600 u )
             goteo       0.200 %/s   retardo 45 s   techo 80 %
             zona segura 0.400 %/s   techo 100 %
             oscuridad   a oscuras x1.50   iluminado x0.50   radio de ambiente 300 u
             medicacion  I +25 %  ·  II +40 %  ·  III +60 %   enfriamiento 60 s
           SEPULDOSKY   cordura 99.49 %
             luz         a oscuras   ( nada cerca )
             esfera      14 ticks con el fantasma cerca  ( 4.2 s )
             presencia calma         -0.34 %   en    4.2 s / 14 ticks
             presencia hunt          +0.00 %   ( sin llamador todavia )
             oscuridad ( mod )       -0.17 %   en    4.2 s / 14 ticks
             evento sound            +0.00 %   ( sin llamador todavia )
             evento throw            +0.00 %   ( sin llamador todavia )
             evento light            +0.00 %   ( sin llamador todavia )
             evento prop             +0.00 %   ( sin llamador todavia )
             evento knock            +0.00 %   ( sin llamador todavia )
             evento door             +0.00 %   ( sin llamador todavia )
             evento furniture        +0.00 %   ( sin llamador todavia )
             evento creak            +0.00 %   ( sin llamador todavia )
             goteo pasivo            +0.00 %   ( sin llamador todavia )
             zona segura             +0.00 %   ( sin llamador todavia )
             medicacion I            +0.00 %   ( sin llamador todavia )
             medicacion II           +0.00 %   ( sin llamador todavia )
             medicacion III          +0.00 %   ( sin llamador todavia )
             muerte                  +0.00 %   ( sin llamador todavia )
             fantasma muerto         +0.00 %   ( sin llamador todavia )
             andamio consola         +0.00 %   ( sin llamador todavia )
             ------------------------------------------------------------
             neto                    -0.51 %   en 53 s de partida
             ultima      oscuridad ( mod )   -0.01 %   hace 0.0 s   ( continua )
             estado nacio por: PlayerInitialSpawn

00 [PASA] ⚠⚠⚠ EL CONTROL · si esta fila no sale verde, el resto no vale — Con las siete perillas de causa en 0 la barra no se mueve en varios minutos — y el reporte prueba que la fila se corrió: los ticks en la esfera y el potencial suprimido
   nota: ] phantasmagoria_sanity_presencia 0
         ] phantasmagoria_sanity_regen 0
         ] phantasmagoria_sanity_safe 0
         ] phantasmagoria_sanity_meds 0
         ] phantasmagoria_sanity_muerte 0
         ] phantasmagoria_sanity_destierro 0
         ] phantasmagoria_sanity_eventos 0
         ] phantasmagoria_cordura_reset
         [Phantasmagoria] cordura reseteada en 1 jugadores ( valor 100 %, desglose en cero, contadores de fuente en cero ).
         ] phantasmagoria_cordura
         [Phantasmagoria] CORDURA -- Diseno 19.8, tajada B1
           tick        0.25 s   ( 114 ticks, ultimo hace 0.1 s )
           inicial     100 %
           fantasmas   1   ( via PHANTASMAGORIA.EachGhost )
           items Cargo registrados ( disparo: InitPostEntity )
           FUENTES CONTINUAS -- la forma que el rasgo del Phantom va a necesitar
             presencia      ACTIVA     103/114 muestras activa   ultimo motivo ( SEPULDOSKY ): calma · #32 a 214 u · 1 en la esfera
             regen          inactiva   0/114 muestras activa   ultimo motivo ( SEPULDOSKY ): en el techo del goteo ( 80 % )
             zonasegura     inactiva   0/114 muestras activa   ultimo motivo ( SEPULDOSKY ): la zona segura de §18.1 no esta escrita ( sin entidad camion y sin veto terminator_blocktarget
                     )
           PERILLAS DE CAUSA   ( 0 = control; suprimen el EFECTO, nunca la cuenta )
             presencia 0   ·  eventos 0 ( ANDAMIO: sin llamador hasta B2 )
             regen 0   ·  safe 0 ( sin sujeto: la zona no existe )   ·  meds 0   ·  muerte 0   ·  destierro 0
             oscuridad 1   ( MODULADOR, no causa )
           TASAS Y GEOMETRIA   ( renglon aparte a proposito: son numeros continuos )
             presencia   calma 0.100 %/s   hunt 0.350 %/s
             esfera      radio 400 u   meseta 150 u   en hunt x1.50 ( 600 u )
             goteo       0.200 %/s   retardo 45 s   techo 80 %
             zona segura 0.400 %/s   techo 100 %
             oscuridad   a oscuras x1.50   iluminado x0.50   radio de ambiente 300 u
             medicacion  I +25 %  ·  II +40 %  ·  III +60 %   enfriamiento 60 s
           SEPULDOSKY   cordura 100.00 %
             luz         a oscuras   ( nada cerca )
             esfera      103 ticks con el fantasma cerca  ( 30.9 s )
             presencia calma         +0.00 %   en   30.9 s / 103 ticks   [ potencial -2.73 %, CONTROL: phantasmagoria_sanity_presencia en 0 ]
             presencia hunt          +0.00 %   ( sin llamador todavia )
             oscuridad ( mod )       +0.00 %   en   30.9 s / 103 ticks   [ potencial -1.36 %, CONTROL: phantasmagoria_sanity_presencia en 0 ]
             evento sound            +0.00 %   ( sin llamador todavia )
             evento throw            +0.00 %   ( sin llamador todavia )
             evento light            +0.00 %   ( sin llamador todavia )
             evento prop             +0.00 %   ( sin llamador todavia )
             evento knock            +0.00 %   ( sin llamador todavia )
             evento door             +0.00 %   ( sin llamador todavia )
             evento furniture        +0.00 %   ( sin llamador todavia )
             evento creak            +0.00 %   ( sin llamador todavia )
             goteo pasivo            +0.00 %   ( sin llamador todavia )
             zona segura             +0.00 %   ( sin llamador todavia )
             medicacion I            +0.00 %   ( sin llamador todavia )
             medicacion II           +0.00 %   ( sin llamador todavia )
             medicacion III          +0.00 %   ( sin llamador todavia )
             muerte                  +0.00 %   ( sin llamador todavia )
             fantasma muerto         +0.00 %   ( sin llamador todavia )
             andamio consola         +0.00 %   ( sin llamador todavia )
             ------------------------------------------------------------
             neto                    +0.00 %   en 34 s de partida
             ultima      -- nada la movio todavia --
             estado nacio por: reset

01 [PASA] ★★ LA PRESENCIA SOLA · el discriminante es el DESGLOSE, no la barra — Con el resto apagado y el fantasma cerca, todo el drenaje se atribuye a la presencia — y la segunda mitad prueba que el discriminante entre las dos tasas es el HUNT y nada más
   nota: En calma un gallu: presencia calma         -3.49 %   en   37.5 s / 125 ticks -> presencia calma         -5.84 %   en   71.1 s / 237 ticks
         En hunt el gallu: presencia hunt         -12.64 %   en   47.1 s / 157 ticks
         //Depende de la oscuridad cuanto me dañe, lo que noto es que si afecta

02 [PASA] ★★ LA RECUPERACIÓN SOLA · y el techo de 80, que es una decisión tuya de hoy — Sin fantasma cerca la barra sube, el desglose dice por qué vía, y el goteo se detiene en 80 % — que es lo que le deja territorio propio a las pastillas
   nota: ] phantasmagoria_cordura
         [Phantasmagoria] CORDURA -- Diseno 19.8, tajada B1
           tick        0.25 s   ( 385 ticks, ultimo hace 0.2 s )
           inicial     100 %
           fantasmas   1   ( via PHANTASMAGORIA.EachGhost )
           items Cargo registrados ( disparo: InitPostEntity )
           FUENTES CONTINUAS -- la forma que el rasgo del Phantom va a necesitar
             presencia      inactiva   0/385 muestras activa   ultimo motivo ( SEPULDOSKY ): sin fantasma en la esfera
             regen          ACTIVA     235/385 muestras activa   ultimo motivo ( SEPULDOSKY ): lejos y sin drenaje hace 115 s
             zonasegura     inactiva   0/385 muestras activa   ultimo motivo ( SEPULDOSKY ): la zona segura de §18.1 no esta escrita ( sin entidad camion y sin veto terminator_blocktarget
                     )
           PERILLAS DE CAUSA   ( 0 = control; suprimen el EFECTO, nunca la cuenta )
             presencia 1   ·  eventos 0 ( ANDAMIO: sin llamador hasta B2 )
             regen 1   ·  safe 0 ( sin sujeto: la zona no existe )   ·  meds 0   ·  muerte 0   ·  destierro 0
             oscuridad 1   ( MODULADOR, no causa )
           TASAS Y GEOMETRIA   ( renglon aparte a proposito: son numeros continuos )
             presencia   calma 0.100 %/s   hunt 0.350 %/s
             esfera      radio 400 u   meseta 150 u   en hunt x1.50 ( 600 u )
             goteo       0.200 %/s   retardo 45 s   techo 80 %
             zona segura 0.400 %/s   techo 100 %
             oscuridad   a oscuras x1.50   iluminado x0.50   radio de ambiente 300 u
             medicacion  I +25 %  ·  II +40 %  ·  III +60 %   enfriamiento 60 s
           SEPULDOSKY   cordura 54.10 %
             luz         ILUMINADO   ( linterna )
             esfera      0 ticks con el fantasma cerca  ( 0.0 s )
             presencia calma         +0.00 %   ( sin llamador todavia )
             presencia hunt          +0.00 %   ( sin llamador todavia )
             oscuridad ( mod )       +0.00 %   ( sin llamador todavia )
             evento sound            +0.00 %   ( sin llamador todavia )
             evento throw            +0.00 %   ( sin llamador todavia )
             evento light            +0.00 %   ( sin llamador todavia )
             evento prop             +0.00 %   ( sin llamador todavia )
             evento knock            +0.00 %   ( sin llamador todavia )
             evento door             +0.00 %   ( sin llamador todavia )
             evento furniture        +0.00 %   ( sin llamador todavia )
             evento creak            +0.00 %   ( sin llamador todavia )
             goteo pasivo           +14.10 %   en   70.5 s / 235 ticks
             zona segura             +0.00 %   ( sin llamador todavia )
             medicacion I            +0.00 %   ( sin llamador todavia )
             medicacion II           +0.00 %   ( sin llamador todavia )
             medicacion III          +0.00 %   ( sin llamador todavia )
             muerte                  +0.00 %   ( sin llamador todavia )
             fantasma muerto         +0.00 %   ( sin llamador todavia )
             andamio consola        -60.00 %   1 veces
             ------------------------------------------------------------
             neto                   -45.90 %   en 116 s de partida
             ultima      goteo pasivo   +0.06 %   hace 0.2 s   ( continua )
             estado nacio por: reset

03 [SIN CORRER] ⚠⚠ LA ÚNICA FILA QUE JUZGA LOS NÚMEROS y no el mecanismo · ventana de 10-20 min — El NETO: con actividad normal, ¿la barra llega al umbral típico de hunt (50 %) entre 10 y 20 minutos?
   nota: ] phantasmagoria_cordura
         [Phantasmagoria] CORDURA -- Diseno 19.8, tajada B1
           tick        0.25 s   ( 3198 ticks, ultimo hace 0.0 s )
           inicial     100 %
           fantasmas   1   ( via PHANTASMAGORIA.EachGhost )
           items Cargo registrados ( disparo: InitPostEntity )
           FUENTES CONTINUAS -- la forma que el rasgo del Phantom va a necesitar
             presencia      ACTIVA     716/3198 muestras activa   ultimo motivo ( SEPULDOSKY ): calma · #72 a 135 u · 1 en la esfera
             regen          inactiva   0/3198 muestras activa   ultimo motivo ( SEPULDOSKY ): en el techo del goteo ( 80 % )
             zonasegura     inactiva   0/3198 muestras activa   ultimo motivo ( SEPULDOSKY ): la zona segura de §18.1 no esta escrita ( sin entidad camion y sin veto terminator_blocktarget
                      )
           PERILLAS DE CAUSA   ( 0 = control; suprimen el EFECTO, nunca la cuenta )
             presencia 1   ·  eventos 0 ( ANDAMIO: sin llamador hasta B2 )
             regen 1   ·  safe 1 ( sin sujeto: la zona no existe )   ·  meds 1   ·  muerte 1   ·  destierro 0
             oscuridad 1   ( MODULADOR, no causa )
           TASAS Y GEOMETRIA   ( renglon aparte a proposito: son numeros continuos )
             presencia   calma 0.100 %/s   hunt 0.350 %/s
             esfera      radio 400 u   meseta 150 u   en hunt x1.50 ( 600 u )
             goteo       0.200 %/s   retardo 45 s   techo 80 %
             zona segura 0.400 %/s   techo 100 %
             oscuridad   a oscuras x1.50   iluminado x0.50   radio de ambiente 300 u
             medicacion  I +25 %  ·  II +40 %  ·  III +60 %   enfriamiento 60 s
           SEPULDOSKY   cordura 88.10 %
             luz         ILUMINADO   ( linterna )
             esfera      716 ticks con el fantasma cerca  ( 214.8 s )
             presencia calma        -15.97 %   en  214.8 s / 716 ticks
             presencia hunt          +0.00 %   ( sin llamador todavia )
             oscuridad ( mod )       +4.07 %   en  214.8 s / 716 ticks
             evento sound            +0.00 %   ( sin llamador todavia )
             evento throw            +0.00 %   ( sin llamador todavia )
             evento light            +0.00 %   ( sin llamador todavia )
             evento prop             +0.00 %   ( sin llamador todavia )
             evento knock            +0.00 %   ( sin llamador todavia )
             evento door             +0.00 %   ( sin llamador todavia )
             evento furniture        +0.00 %   ( sin llamador todavia )
             evento creak            +0.00 %   ( sin llamador todavia )
             goteo pasivo            +0.00 %   ( sin llamador todavia )
             zona segura             +0.00 %   ( sin llamador todavia )
             medicacion I            +0.00 %   ( sin llamador todavia )
             medicacion II           +0.00 %   ( sin llamador todavia )
             medicacion III          +0.00 %   ( sin llamador todavia )
             muerte                  +0.00 %   ( sin llamador todavia )
             fantasma muerto         +0.00 %   ( sin llamador todavia )
             andamio consola         +0.00 %   ( sin llamador todavia )
             ------------------------------------------------------------
             neto                   -11.90 %   en 959 s de partida
             ultima      oscuridad ( mod )   +0.01 %   hace 0.0 s   ( continua )
             estado nacio por: reset
         //Estoy con la linterna en todo momento y no siguiendo al fantasma aqui en el asilo que es gigante

04 [SIN CORRER] ⚠⚠⚠ NINGUNA OTRA FILA PUEDE VER ESTO · es lo que prueba que el rasgo del Phantom va a poder entrar — Las DOS formas existen y son distintas: la continua drena mientras la condición se cumple y deja de drenar cuando deja de cumplirse; la plana cobra una vez y no acumula segundos
05 [SIN CORRER] ★★ EL DESGLOSE NO MIENTE · una causa por vez · el discriminante es el [ potencial ] — Apagar una causa deja su renglón en cero mientras los otros siguen — y el cero apagado se distingue del cero que nunca ocurrió
06 [SIN CORRER] ⚠⚠ NO ROMPER LO QUE YA CERRÓ · el módulo es nuevo pero corre en el mismo tick que todo lo demás — El hunt se sigue disparando por phantasmagoria_hunt, los ocho eventos siguen andando, y las puertas / el +USE / el pestillo también
07 [SIN CORRER] ★★ LA MEDICACIÓN · tres tiers, tres sonidos · y el orden de las mitades importa — Los tres tiers dan +25 / +40 / +60, cada uno suena distinto (bebida / pastillas / adrenalina), y al 100 % la dosis se RECHAZA sin gastarse
08 [SIN CORRER] ⚠ SOFT-DEP · SIN CORRER si no tenés Corpus/Cargo montado, y eso no es un rojo — Con Cargo montado, los tres tiers aparecen como ítems del inventario — en los dos realms, que es lo que hace que el grid los dibuje y el menú Use exista
09 [SIN CORRER] ★ LOS DESENLACES · morir restaura, y matar al fantasma también — Morir devuelve la cordura al inicial, y matar al fantasma se la devuelve a todos — con la perilla en 0, el renglón queda en cero pero con su potencial
10 [SIN CORRER] ⚠⚠ EL CONTROL DEL CONTROL · un helper que nadie llama es el código viejo con un verde encima — Nadie escribe la cordura por fuera de la puerta: el desglose cierra contra la barra en toda la sesión, y ni una sola línea EL DESGLOSE NO CIERRA
```

> ⚠ **El texto `( sin llamador todavia )` que aparece nueve veces por lectura en este reporte es del
> instrumento de la r1 y está ARREGLADO desde el 2026-08-20.** Se deja tal cual porque es el registro
> de con qué se midió; el reporte de la r2 va a distinguir los tres ceros. Ver §2 (B) más arriba.
