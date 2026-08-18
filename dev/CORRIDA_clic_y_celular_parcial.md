# CORRIDA PARCIAL — planilla del clic y el celular (2026-08-18)

> **Por qué existe este archivo.** La planilla es un `.html` con su estado en el **localStorage del
> navegador**, y vive en `<workspace>/dev/checks/`, que **no es un repo git**. O sea que lo único que
> queda de una corrida es el reporte pegado en el chat — y un chat se cierra. Esto es ese reporte,
> guardado donde sí sobrevive.
>
> ⚠ **No es un resultado: es una corrida que no se pudo terminar.** Vale como registro de qué se
> intentó y con qué se chocó, no como medición de ninguna fila.

---

## Lo que dio

    Pasa 0 · Falla 0 · Sin correr 7  (de 7)

Las siete filas quedaron **SIN CORRER**. La única con nota es la 00.

## La nota de la fila 00

El primer comando **sí funcionó**:

    ] lua_run PHT={} PHT.e=ents.Create("info_target") PHT.e:SetPos(Entity(1):GetPos()+Vector(0,0,20)) PHT.e:Spawn() print("emisor #"..PHT.e:EntIndex())
    emisor #411

Y ahí se cortó todo. El autor estaba midiendo en **`gm_uh_house`** (no en `gm_funkis_night`, que es el
mapa del setup), y el evento `prop` reventaba en cada disparo:

    ] phantasmagoria_ghost_event prop

    [phantasmagoria] addons/phantasmagoria/lua/phantasmagoria/bsp_statics.lua:271: table overflow
      1. parsear             - bsp_statics.lua:271
      2. Estaticos           - bsp_statics.lua:393
      3. EstaticosEnEsfera   - bsp_statics.lua:403
      4. fn                  - server_events.lua:3349
      5. phantom_FireEvent   - server_events.lua:3987
      6. fn                  - server_events.lua:4872
      7. EachGhost           - server.lua:1753
      8. unknown             - server_events.lua:4855
      9. unknown             - concommand.lua:60

Se repitió **idéntico en el segundo disparo**, que es el dato que delató la otra mitad del defecto:
el fallo **no se cacheaba**, así que el mapa se re-parseaba y re-reventaba en cada evento.

---

## Qué se hizo con eso

Está entero en el **CHANGELOG (44)** y en el `§2 ③` del
[HANDOFF](HANDOFF_clic_celular_y_bsp.md). Resumido:

- La causa: `dictEntries = 1095588428`, que escrito de vuelta como cuatro bytes es **`LZMA`**. El lump
  `sprp` de ese mapa viene comprimido y el parser leyó la firma como si fuera una cantidad.
- Dos defectos: las guardas de conteo **miraban un solo lado**, y `parsear` **podía tirar** rompiendo
  su propio contrato escrito, sin cachear el fallo.
- Arreglado, y con el lump comprimido leído: ese mapa tiene **188 modelos / 702 props**, con
  **11 modelos / 13 instancias** que las familias reclaman.

---

## Cómo se retoma

1. La planilla vive en `<workspace>/dev/checks/phantasmagoria-clic-y-celular.html`. **Su estado está
   en el localStorage del navegador**, con la clave `phantasmagoria-clic-y-celular`: si se abre en el
   mismo navegador, la nota de la fila 00 sigue ahí.
2. **Se empieza por la fila `P0`**, que es nueva y no existía en esta corrida: comprueba que el evento
   `prop` ya no revienta en `gm_uh_house` y que el censo dice **188 / 702**. Sin esa fila en verde,
   ninguna de las otras se puede correr en ese mapa.
3. ⚠ **La fila 00 hay que rehacerla desde el principio.** El `emisor #411` de arriba quedó huérfano
   (muere al cambiar de mapa) y el `PHT` global se pierde con el `lua_run` anterior. Los cuatro
   comandos van **uno por línea**, y el cuarto — el `IsValid` — es el que distingue *«el borrado no
   calla»* de *«el borrado no ocurrió»*.
4. ⚠ El setup de la planilla dice `gm_funkis_night`. Si se corre en `gm_uh_house`, los números del
   censo que citan las filas **son otros** (188 / 702, no 418 / 1588) — está dicho en la fila P0.
