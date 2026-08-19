# CORRIDA r1 — la planilla del clic y el celular, corrida entera (2026-08-18)

> **Por qué existe este archivo.** La planilla es un `.html` con su estado en el **localStorage del
> navegador**, y vive en `<workspace>/dev/checks/`, que **no es un repo git**. Lo único que queda de
> una corrida es el reporte pegado en el chat — y un chat se cierra. Esto es ese reporte.
>
> La corrida **anterior** a ésta, que no se pudo terminar porque el evento `prop` reventaba en
> `gm_uh_house`, está en [CORRIDA_clic_y_celular_parcial.md](CORRIDA_clic_y_celular_parcial.md).

---

## Lo que dio, y lo que dice después de leerlo

    Pasa 6 · Falla 1 · Sin correr 1  (de 8)          <- lo que marcó el autor
    Pasa 5 · Falla 1 · Sin correr 2  (de 8)          <- lo que las notas sostienen

**La diferencia es la fila 04**, y no es una discrepancia de criterio: es la propia rama de FALLA de
esa fila la que lo dice. Ver abajo.

| # | marcado | sostiene | qué pasó |
|---|---|---|---|
| **P0** | PASA | **PASA** | 188 / 702, y confirmado aparte por `bsp_statics_offline.py` con el control 418 / 1588 |
| **00** | PASA | **PASA** | borrar nuestro `info_target` **sí** corta el `clock_tick` |
| **01** | FALLA | **FALLA, sin diagnóstico** | el sujeto no quedó identificado — puede haber medido otra cosa |
| **02** | SIN CORRER | **PASA** | cerrada offline el mismo día: mono, misma duración, denominador por fuente en pie |
| **03** | PASA | **PASA** | el clic suena y llega desde el objeto |
| **04** | PASA | **SIN CORRER** | `lejos` quedó en **0**, y la fila decía por escrito que eso es «no se corrió» |
| **05** | PASA | **PASA** | `phone_ring` siempre, `phone_vibrate` nunca |
| **06** | PASA | **PASA** | el `+USE`, la `E` y el pestillo siguen andando |

### La 04 — verde sobre un vacío

Su rama de FALLA, textual: *«`lejos` queda en **0** → **la fila no se corrió**: no había candidato en
el registro, así que el silencio no prueba nada. Un vacío no es una medición.»* Y quedó en 0 en las
**dos** lecturas, la de radio 60 y la de radio 256.

**La causa está medida y es del sujeto, no del código.** En las dos lecturas lo único sonando eran
*un microondas*, *un televisor* y *un inodoro* — las tres `NO apagable`. El `+USE` ni las mira, así
que `apagarCerca()` salió por la puerta de «no había nada» **sin tocar ningún contador**, que se ve
idéntico a un filtro que rechazó por distancia. Y el otro motivo por el que el sujeto no fue una
radio: `phone_ring` dura **3,46 s**, que no alcanza para caminar a otro cuarto.

### La 01 — roja sin sujeto

La nota dice *«se rompió la radio, sigue sonando; borrar tampoco apaga el sonido, desintegrar
tampoco»*. Pero la **00**, de la misma corrida, midió que borrar **sí** calla. Las dos no pueden ser
la misma afirmación, y la corrida no registró de quién colgaba el sonido: en `gm_uh_house` **no hay
ninguna radio horneada**, el evento sortea **una familia por disparo**, y todo lo que aparece en el
registro son `info_target` nuestros. *Es posible que la radio que se rompió nunca haya sido la que
sonaba.*

### El desacuerdo del censo, que la corrida destapó sin proponérselo

El reporte en juego dice `TOTAL RECLAMADO 10 modelo(s) / 12 instancia(s)`. El HANDOFF y el
CHANGELOG (44) citaban **11 / 13**. Ganaba el juego: `dev/censo_props_horneados.py` tenía las reglas
de antes de los tres vetos del 2026-08-16 y seguía contando `radio_antenna01_skybox` — la antena del
skybox 3D — como *una radio*. Está en el CHANGELOG (48).

---

## El reporte, como lo pegó el autor

    REPORTE — Phantasmagoria · el clic del interruptor, el prop roto que sigue sonando, y el celular
    que no era un celular
    Pasa 6 · Falla 1 · Sin correr 1  (de 8)

### P0 [PASA] — el evento `prop` ya no revienta, y el censo dice 188 / 702

    ] phantasmagoria_ghost_estaticos
    ===== PROPS HORNEADOS ( prop_static, leidos del .bsp ) =====
      mapa        gm_uh_house   ( maps/gm_uh_house.bsp )
      bsp         32591904 bytes · VBSP 20 · sprp v10 · 72 bytes por entrada
      CONTROL     0 byte(s) sobrantes ( tiene que ser 0 ) · las 188 rutas del diccionario tienen forma de modelo
      modelos distintos     188     ( el .py midio 418 )
      instancias            702    ( el .py midio 1588 )
      LO QUE LAS FAMILIAS RECLAMARIAN SOBRE ESTOS 702:
        una radio:  ninguno
        un telefono:  3 modelo(s) / 3 instancia(s)
            x1 models/ill_hanger/props/phonebooth.mdl
            x1 models/props/cs_militia/oldphone01.mdl
            x1 models/props/cs_office/phone.mdl
        un televisor:  1 modelo(s) / 1 instancia(s)
            x1 models/props/cs_militia/television_console01.mdl
        un piano:  2 modelo(s) / 3 instancia(s)
            x1 models/fishy/furniture/piano.mdl
            x2 models/fishy/furniture/piano_seat.mdl
        una guitarra:  ninguno
        un microondas:  1 modelo(s) / 1 instancia(s)
            x1 models/props/cs_office/microwave.mdl
        un inodoro:  3 modelo(s) / 4 instancia(s)
            x1 models/props/cs_militia/toilet.mdl
            x1 models/props_c17/furnituretoilet001a.mdl
            x2 models/props/cs_office/paper_toilet.mdl
        un peluche:  ninguno
        un reloj:  ninguno
      TOTAL RECLAMADO  10 modelo(s) / 12 instancia(s)
      EMISORES ( las filas de la fuga y del salteo )
        vivos ahora      0   ( contados en el mapa: 0 -- coinciden )
        creados en total 0
        salteados por el barrido 0
        horneados en el sorteo   1 ( encendido )
      REGISTRO DE LO QUE SUENA   0 entrada(s)
      +USE ( el interruptor )   encendido, radio 60 u
        teclas IN_USE vistas por el hook  0
        apagados de verdad                0
        habia algo pero FUERA del radio   0
        lo mas cercano YA HABIA TERMINADO 0
      PESTILLO   encendido · trabadas ahora 0/2 · vida 45 s
      LLAVES SIN SUJETO   el evento `prop` NO suena el banco ambiente sin ninguna familia con sujeto

*( El bloque del censo se repite idéntico en las lecturas de abajo; lo que cambia de una a otra son
las secciones `EMISORES`, `REGISTRO` y `+USE`, que van completas. )*

### 00 [PASA] — borrar la entidad mientras suena **sí** la calla

> Emisores distintos, y se corta correspondientemente el tic-tac

### 01 [FALLA] — romper el prop no lo calla, y borrarlo tampoco

> Se rompio la radio, sigue sonando; Borrar tambien no apaga el sonido, desintegrar tampoco.

⚠ Sin el `#NNN` del sujeto, esta nota no distingue *el defecto* de *haber roto una radio callada*.

### 02 [SIN CORRER] — offline

> No se, no he tocado el script pero no veo problemas en la consola

⚠ **Se corrió después, el mismo día, y dio verde.** Ver arriba.

### 03 [PASA] — el clic

> Afirmativo, se escucha bien

### 04 [PASA / **sin correr**] — el control negativo

> `phantasmagoria_ghost_evuseradius` = `60`. Es una buena distancia.

**De cerca**, con radio 60:

    ] phantasmagoria_ghost_event prop
        #883  prop -> 1 disparo(s)
            OK -- phone_ring DESDE un telefono ( prop_static HORNEADO  modelo
                 'models/props/cs_militia/oldphone01.mdl'  ( emisor #1089 ) ) a 79 u,
                 ENTERO: 3.46 s  [ se apaga con +USE a 60 u ]  ( 5 familia(s) con sujeto en el radio )

      EMISORES
        vivos ahora      3   ( contados en el mapa: 3 -- coinciden )
        creados en total 19
        salteados por el barrido 116
        horneados en el sorteo   1 ( encendido )
      REGISTRO DE LO QUE SUENA   3 entrada(s)  ( 3 sonando · 0 ya terminado(s) · 0 podada(s) )
        un microondas  info_target #1083      emisor nuestro · NO apagable  quedan 18.0 s
        un televisor   info_target #1087      emisor nuestro · NO apagable  quedan 2.9 s
        un microondas  info_target #1088      emisor nuestro · NO apagable  quedan 18.0 s
      +USE ( el interruptor )   encendido, radio 60 u
        teclas IN_USE vistas por el hook  55
        apagados de verdad                3
        habia algo pero FUERA del radio   0
        lo mas cercano YA HABIA TERMINADO 1

**De más lejos**, con radio 256:

    ] phantasmagoria_ghost_event prop
        #883  prop -> 1 disparo(s)
            OK -- phone_ring DESDE un telefono ( prop_static HORNEADO  modelo
                 'models/props/cs_militia/oldphone01.mdl'  ( emisor #1091 ) ) a 72 u,
                 ENTERO: 3.46 s  [ se apaga con +USE a 256 u ]  ( 5 familia(s) con sujeto en el radio )

      EMISORES
        vivos ahora      5   ( contados en el mapa: 5 -- coinciden )
        creados en total 22
        salteados por el barrido 131
      REGISTRO DE LO QUE SUENA   5 entrada(s)  ( 4 sonando · 1 ya terminado(s) · 0 podada(s) )
        un microondas  info_target #1083      emisor nuestro · NO apagable  quedan 11.4 s
        un televisor   info_target #1087      emisor nuestro · NO apagable  quedan 0.0 s
        un microondas  info_target #1088      emisor nuestro · NO apagable  quedan 11.4 s
        un inodoro     info_target #1089      emisor nuestro · NO apagable  quedan 15.7 s
        un televisor   info_target #1090      emisor nuestro · NO apagable  quedan 2.4 s
      +USE ( el interruptor )   encendido, radio 256 u
        teclas IN_USE vistas por el hook  56
        apagados de verdad                4
        habia algo pero FUERA del radio   0
        lo mas cercano YA HABIA TERMINADO 1

> Se puede apagar de mas lejos o detras de un muro pero como dije, esto se soluciona con distancia 60
> por defecto, suficiente distancia.

⚠ **`habia algo pero FUERA del radio` quedó en 0 en las dos.** Ninguna de las dos lecturas tiene un
candidato `apagable` sonando: los cinco del registro son microondas, televisor e inodoro.

### 05 [PASA] — el teléfono

> Asi es ya no suena el celular, solo el ring de telefono

### 06 [PASA] — no romper lo que andaba

> Asi es

---

## Cómo se retoma

La planilla de la ronda siguiente es `<workspace>/dev/checks/phantasmagoria-prop-roto-r2.html`,
**cinco filas**, con la clave de localStorage `phantasmagoria-prop-roto-r2`. Su fila **00** existe
para una sola cosa: **conseguir un `prop_physics` que la consola nombre** antes de romperlo.
