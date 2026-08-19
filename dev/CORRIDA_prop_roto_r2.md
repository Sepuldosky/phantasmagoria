# CORRIDA r2 — el prop que se rompe, y el control negativo que la r1 no corrió (2026-08-19)

> **Por qué existe este archivo.** La planilla es un `.html` con su estado en el **localStorage del
> navegador**, y vive en `<workspace>/dev/checks/`, que **no es un repo git**. Lo único que queda de
> una corrida es el reporte pegado en el chat — y un chat se cierra.
>
> La corrida anterior está en [CORRIDA_clic_y_celular_r1.md](CORRIDA_clic_y_celular_r1.md), y la que
> ni siquiera arrancó, en [CORRIDA_clic_y_celular_parcial.md](CORRIDA_clic_y_celular_parcial.md).

---

## Lo que dio

    Pasa 4 · Falla 0 · Sin correr 1  (de 5)

La única sin correr es la **04**, que es offline y **ya se había corrido** el día anterior — *«no
recorrer, está ok»*. **El bloque cierra 5/5.**

| # | qué medía | resultado |
|---|---|---|
| **00** | conseguir un `prop_physics` que la consola **nombre** | `prop_physics #1067 modelo 'radio'` |
| **01** | romperlo a tiros, ¿para el sonido? | **para**, con `enganchados 1` / `callados 1` |
| **02** | control negativo: `E` de lejos | `lejos` **43**, ningún clic, la radio siguió |
| **03** | no romper lo que la r1 cerró | el `+USE` sigue apagando con su clic |
| **04** | los dos censos dicen lo mismo | corrida el 2026-08-18 |

---

## Lo que esta ronda cerró y no estaba cerrado

### ⭐ El pedido 2, cerrado en juego — y con él la precondición que nunca se había medido

La fila 00 consiguió por fin **un sujeto nombrado por la consola**, que es exactamente lo que le
faltó a la r1:

    ] phantasmagoria_ghost_event prop
        #1071  prop -> 1 disparo(s)
            OK -- creepy_music DESDE una radio ( prop_physics #1067  modelo 'radio' ) a 70 u,
                 ENTERO: 33.71 s  [ se apaga con +USE a 60 u ]  ( 5 familia(s) con sujeto en el radio )

`prop_physics`, con su `#NNN`, y con un clip de **33,71 s** — ventana de sobra. Y después del tiro:

      EL PROP QUE SE ROMPE ( pedido 2 )
        props de verdad que salieron a sonar con su corte puesto  1
        de esos, cuantos se CALLARON al morir                     1

> Si paro el sonido al pegarle un tiro

Es la lectura más limpia posible: **exactamente un** prop salió a sonar, se lo rompió, y el hook
corrió. `EMISORES creados en total 0` y `REGISTRO 0 entradas` en la misma lectura confirman que no
había ningún emisor nuestro de por medio que pudiera confundirse con el sujeto — que es justo lo que
arruinó la fila 01 de la r1.

**Y eso cierra la precondición que el bloque declaraba sin medir:** un `StopSound` sobre una entidad
**que se está yendo** *sí* llega a tiempo. El candidato alternativo — un emisor propio
`SetParent`-eado al prop, para que el prop nunca sostenga el canal — queda **descartado por
innecesario, no por malo**.

### ⭐ El control negativo corrió de verdad, y esta vez con sujeto

En la r1 esta fila estaba marcada verde con `lejos` en **0**, que su propio criterio declaraba «no se
corrió». Acá:

      REGISTRO DE LO QUE SUENA   1 entrada(s)  ( 1 sonando · 0 ya terminado(s) · 0 podada(s) )
        una radio      prop_physics #1067     prop DEL MAPA · apagable con +USE  quedan 6.3 s
      +USE ( el interruptor )   encendido, radio 60 u
        teclas IN_USE vistas por el hook  169
        apagados de verdad                2
        habia algo pero FUERA del radio   43
        lo mas cercano YA HABIA TERMINADO 0

> No se escucho nada y no se apago la radio en su musica

Las cuatro mitades: **ningún clic**, `lejos` subió a **43**, la radio **siguió sonando**, y el
candidato del registro era **`apagable`** — una radio, no un microondas. El diagnóstico de la r1 era
correcto: lo que faltaba era el sujeto, no el código.

### La fila 03 — no se rompió nada

> Apreté un prop_static de un teléfono, sí se apaga y suena el clic

---

## Frontera que la corrida dejó a la vista, y no es una tarea

En la lectura de la fila 02, `props de verdad que salieron a sonar con su corte puesto` marca **11**
y `de esos, cuantos se CALLARON al morir` marca **1**, con `apagados 2` y **una sola** entrada en el
registro. Los números cierran, pero por un camino que conviene dejar escrito:

- **Un `prop_physics` vivo que vuelve a sonar acumula entradas en `SONANDO`.** La poda es por
  `IsValid`, no por `hasta`, así que mientras el prop viva sus entradas viejas se quedan. No es
  audible y no engaña al `+USE` — la entrada que todavía suena tiene `hasta > now` y gana —, pero
  infla el conteo del registro.
- **El `CallOnRemove` limpia todas las entradas de ese prop con ese clip de una vez**, y suma **uno**
  solo a `callados`. Por eso 11 enganches pueden terminar en 1 callado sin que falte nada.
- **Y el hook se pisa a sí mismo si el mismo prop vuelve a sonar el mismo clip**, porque
  `CallOnRemove` indexa por nombre. Como el nombre lleva el clip adentro, dos clips distintos sobre
  la misma radio conviven; dos veces el mismo, no — y no hace falta que convivan, porque el que queda
  vivo hace exactamente lo mismo.

Nada de esto cambia lo que se oye. Va acá para que la próxima lectura de `enganchados` no se lea como
una fuga.
