# PENDIENTES — Phantasmagoria

Cosas que **el autor pidió o que aparecieron a mitad de una ronda** y que no pertenecen a la tajada
que se estaba corriendo. Viven acá para que no se pierdan entre el chat y la próxima planilla.

> Regla de la casa: una idea dicha en medio de una corrida **no entra en esa corrida**. Se anota con
> las palabras del autor, con lo que hay que decidir, y con lo que haría falta para medirla. *Meterla
> en la ronda en curso ensucia el sujeto que se estaba midiendo; olvidarla es peor.*

---

## 1. ⭐ El Yurei tiene que abrir la puerta **rápido y fuerte**, no como cualquiera

**Pedido por el autor el 2026-08-21**, al cerrar la fila 06 de la cordura B2 (donde el `per.door = 15`
quedó medido en juego por primera vez):

> *«La verdad que sí funciona, aunque está cerrando las puertas como lo hace cualquier ghost. Digo
> que el evento del Yurei este tiene que buscar la puerta más cercana al jugador y abrirla
> rápidamente, puede ser 2 veces más rápida y un 1/2 más ruidosa; ya que el abrir puertas aquí en
> GMod no lo hicimos como parcial, y así no funcionan las puertas en el motor Source, será tendrá que
> ser la diferencia del Yurei.»*

### Por qué es una buena traducción, y no un capricho

La fuente le da al Yurei tres líneas, y **una de las tres no se puede cumplir en Source**:

- `(:631)` *"Can shut a door and drop sanity of nearby players by 15%"* → **escrito y medido** (`per.door = 15`).
- `(:635)` *"ONLY ghost that can close or interact with an exit door outside of a hunt/event"* → sin destino.
- `(:636)` **"Must fully open / shut a door"** → **imposible como diferencia observable**: en GMod las
  puertas no abren parcialmente, así que *todos* los fantasmas ya la abren "del todo". La línea que
  debía distinguir al Yurei **no distingue nada**.

*Un rasgo cuya única expresión es imposible en el motor no es un rasgo: hay que darle otro cuerpo o
declararlo muerto.* Lo que el autor propone es darle otro cuerpo, sobre tres ejes que en Source **sí**
son observables:

| eje | hoy | propuesta |
|---|---|---|
| **elección de la puerta** | la más cercana **al fantasma** (o sorteo entre las del radio) | la más cercana **al jugador** |
| **velocidad** | la del `func_door` / `prop_door_rotating` | **×2** |
| **volumen** | el del evento `door` | **×1,5** |

### Lo que hay que decidir antes de escribirlo

1. ⚠ **La elección por jugador rompe la simetría del motor de eventos**, que hoy elige *alrededor del
   fantasma* a propósito (`evradius` decide DÓNDE pasa; `sanrad` decide A QUIÉN le llega — están
   separados justamente para que no se muevan juntos). Un rasgo que elija por jugador es el **primer**
   evento que mira al jugador para decidir su sujeto. Se puede, pero es una excepción declarada y hay
   que escribir por qué.
2. **¿La velocidad se puede tocar en un `func_door`?** `speed` es un keyvalue del mapa. Hay que medir
   si `SetKeyValue`/`Fire` lo acepta en caliente, y qué pasa con `prop_door_rotating`, que es otra
   entidad con otro campo. **Esto puede no ser posible**, y entonces el eje se cae.
3. **El ×1,5 de volumen**: ¿es el volumen del `EmitSound` del evento, o el sonido propio de la puerta
   (que lo emite la entidad del mapa)? Son dos cosas distintas y sólo una la controla el addon.
4. **¿Cuál de los tres ejes lleva el peso?** Si la velocidad no se puede tocar, la diferencia queda en
   "elige la puerta de al lado tuyo y suena más fuerte", que igual es una diferencia legible.

### Alcance

Es **Diseño 21 (eventos paranormales)**, no la cordura. Va con planilla propia. No se toca en B2 ni en
C. La fila que lo mida tiene que separar los tres ejes: *un cambio de tres ejes a la vez que sale
"raro" no dice cuál de los tres.*

---

## 2. Sin reproducir: un spawn que pareció ignorar el override de tipo

En la r2 de la cordura B2, la nota de la fila **09** muestra dos spawns seguidos con
`PHANTASMAGORIA.TypeOverride` en `'phantom'`:

```
spawn #175  serie 3  ...  tipo phantom
spawn #175  serie 4  ...  tipo spirit
```

Lo único que borra el override es `phantasmagoria_ghost_type auto|random`, y **imprime
`override BORRADO`** ([server_type.lua:639](../lua/entities/terminator_nextbot_phantom/server_type.lua#L639)).
Esa línea no está en el pegado.

**El autor no lo observó**, y hay una explicación benigna que lo cubre entero: la consola se limpió
con `clear` durante la sesión, así que el orden de las líneas pegadas **no es necesariamente la
cronología real** y el `override BORRADO` pudo perderse con el resto.

Queda anotado y **no se persigue**. Si vuelve a aparecer con la consola limpia y sin `clear` en el
medio, entonces sí es un defecto: el override se lee de un global (`PHANTASMAGORIA.TypeOverride`) y
tiene un solo lector, así que sería fácil de acorralar. *Una anomalía que no se reproduce no es un
defecto, pero tampoco es nada: es una anotación con fecha.*
