# Phantasmagoria — Estado actual y handoff

**Última actualización:** 2026-08-20
**Repo:** https://github.com/Sepuldosky/phantasmagoria (público, MIT)
**Changelog:** ver [CHANGELOG.md](CHANGELOG.md)
**Diseño vigente:** [docs/PHANTOM_Phasmophobia_Diseno.md](docs/PHANTOM_Phasmophobia_Diseno.md)
**Investigación de la base:** [docs/PHANTOM_Referencia.md](docs/PHANTOM_Referencia.md)
**NPC de evento especial:** [docs/ALTERNATE.md](docs/ALTERNATE.md) — el Alternate de Mandela Catalogue

Documento de traspaso: pensado para retomar el trabajo sin contexto previo.

---

## 🔴 EMPEZAR ACÁ — traspaso del 2026-08-07 (el encaje contra el techo)

> 🔜 **LO SIGUIENTE ES LA CORDURA — el prompt está escrito: `dev/PROMPT_phantasmagoria_cordura_B1.txt`.**
> CHANGELOG **(60)**. Acotado a **B1** (la variable + la presencia + la recuperación + los
> instrumentos; archivo nuevo, **no toca `server_events.lua`**). B2 y C quedan fuera a propósito.
>
> ✅ **§22 CIERRA.** El 0,5%/s del Phantom **SUMA** al drenaje base. Tres formas, cinco eventos, la
> tabla sumando 1 en las seis filas, los drenajes con sus tres modificadores, las pisadas y el objetivo
> de la Banshee. **Cero código de manifestaciones, y es lo correcto**: cuatro de los cinco necesitan la
> cordura.
>
> ⚠⚠⚠ **LO ÚNICO DE B1 QUE, ESCRITO MAL, NO SE ARREGLA AGREGANDO CÓDIGO:** la API tiene que saber
> expresar **dos formas** de drenaje desde el primer día — el **plano** (un número, una vez: las
> manifestaciones y los ocho eventos) y el **continuo condicionado** (una tasa por segundo mientras
> algo se cumple: la presencia, la oscuridad y el Phantom). *Escribir sólo la primera deja al rasgo del
> Phantom sin poder entrar, y el instrumento no lo diría.*
>
> ⚠ **Dos decisiones del autor siguen abiertas y hay que preguntarlas antes de escribir:** la
> calibración de la regeneración pasiva (0,2%/s con retardo de 45 s **o** 0,05%/s sin retardo) y el
> techo de la zona segura (100% u 80%) — que **no tienen por qué ser el mismo número**.
>
> ⭐ **Tres cosas que §19 no sabía y el prompt incorpora:** las pastillas de Cargo **ya están** (§19.9.8
> quedó viejo), el medidor de actividad **ya tiene números** (§22 le puso la escala), y el consumidor
> **existe y está vacío** (el monitor del camión dibuja 61 enteros 0..10 que nadie llena).

> ⭐⭐ **LO ÚLTIMO (2026-08-20, cuarta tanda): LA TABLA DE MANIFESTACIONES CERRADA — las seis filas
> suman 1.** CHANGELOG **(59)**, diseño §22.12-§22.15. Sigue sin haber código de manifestaciones.
>
> ⭐⭐ **El arreglo del Oni salió de leer cómo paga su cambio CADA UNA de las otras cinco filas.** La
> Banshee toma exactamente **1/3 de cada bucket** ajeno para pagar su `singing`; el Kormos reparte en
> partes iguales lo que liberan sus ceros; el Shade le da todo a `mist`; el Mare redistribuye **dentro**
> del bucket. *Las columnas subdividen, el bucket es la unidad, y las cuatro pagan.* El Oni era la única
> que no aplicaba la operación. **Recomendada: descuento proporcional** (le saca 1/4 a cada bucket que
> no es `chase`) — conserva el `chase` en **×2 exacto** y no inventa carácter.
>
> ⚠ **La trampa era normalizar**, que parece lo neutral: deja el `chase` en ×1,67 y *diluye el rasgo sin
> que nadie lo decida*. Y el arreglo **cuesta**: el Oni baja de **26% a 22,50%** de drenaje esperado —
> el 120% lo inflaba un 16%. Si se siente flojo, la perilla es su ×2 o su `rate`, no romper la suma.
>
> ⚠ **El `rate = 1.6` que el Oni YA tiene no lo vuelve un duplicado:** *«more active»* es **frecuencia**
> y el `chase` doblado es **distribución**. Son dos líneas distintas de la wiki. *Dos rasgos que empujan
> en la misma dirección no son el mismo rasgo* — acusarlos habría borrado uno.
>
> ⭐⭐ **Y de la spec de la Banshee salió una clasificación que faltaba:** `chase`, `appear` y `mist` son
> las manifestaciones **DIRIGIDAS** (viajan hacia alguien); `singing` y `standing` ocurren **ante**
> alguien. **Las tres dirigidas necesitan elegir un jugador y las dos restantes un observador, y hoy
> ninguna de las dos elecciones existe.** Es previa a los cinco eventos.
>
> ⚠⚠ **El roaming-stalk de la Banshee toca lo que OTRA SESIÓN escribe ahora** (`server_hunt.lua` nuevo,
> más `server.lua` y `server_stuck.lua` modificados en el árbol). **No se toca desde acá hasta que ese
> bloque cierre.**

> ⭐⭐ **LO ÚLTIMO (2026-08-20, tercera tanda): LAS PROBABILIDADES Y EL DRENAJE.** CHANGELOG **(58)**,
> diseño §22.9-§22.12. Sigue sin haber una línea de código de las manifestaciones.
>
> ⭐⭐ **La redistribución del drenaje PRESERVA la base del juego, y eso es un control que nadie
> pidió:** con `standing` 5%, `mist`/`singing`/`appear` 10% y `chase` 15%, el esperado por
> manifestación da **10,00% exacto en cuatro de los seis tipos** — que es la base de Phasmophobia. Los
> dos que se salen tienen motivo (el Kormos no tiene `chase` ni `mist`; el Oni lleva su ×2).
>
> ⚠⚠⚠ **LA FILA DEL ONI SUMA 120% Y LAS OTRAS CINCO SUMAN EXACTAMENTE 1** (sumado con fracciones, no
> con los % redondeados, que habrían dado 100,01 y lo habrían escondido). Que las otras cierren en 1
> es lo que lo vuelve un **error** y no una convención de pesos. El exceso es exactamente **1/5**, el
> tamaño de la duplicación de su `chase`: *se le dobló y no se le descontó a nadie.* Si se ejecuta como
> pesos, su `chase` real sería **33,33%** y no el 40% escrito, y su esperado pasa de **26% a 21,67%**.
>
> ⚠⚠ **La columna «Red light» no tiene destino** — el efecto no se replica, pero su probabilidad está
> contada dentro del 100%. Borrarla a secas deja al Standard en 14/15. Propuesta: **plegarla sobre
> `Standing (Standard)`**.
>
> ⚠⚠⚠ **El Phantom es de otra especie de regla:** 0,5%/s **mientras lo mires**, a 10 m (**525 u**). Los
> otros dos modificadores (Banshee condicional, Oni ×2) son un número por evento; el suyo es un
> **Think con línea de vista y distancia**. *Implementado como los otros dos, el rasgo no existe.*
>
> ⚠⚠ **El «objetivo de la Banshee» NO EXISTE** — censado, ninguna línea lo nombra. Su regla de drenaje
> lo necesita, y el hunt también.
>
> ✅ **Pisadas cerradas: sólo `chase` suena.** El bloqueante ② se abarata a un `or` con un término.
>
> ⚠⚠ **Y `standing` dejó de ser el evento barato:** su precondición es *«quieto, mirando, cerca y en
> LOS»*, y ahí le cae encima el defecto medido de §21 — **parar al fantasma le congela la cara**. Es el
> único de los cinco cuyo comportamiento entero es el caso que ese defecto rompe. **El más barato pasa
> a ser `appear`.**

> ⭐⭐ **LO ÚLTIMO (2026-08-20, segunda tanda): LOS CUATRO SUSTOS EN MONO Y §22 CON NUEVE DECISIONES
> TOMADAS.** CHANGELOG **(57)**. Sigue sin haber una línea de código de las manifestaciones.
>
> ⭐ **`mono_posicionales.py --aplicar`: 3 de 3, un canal, delta 0,000 s**, backup por sha256 y
> verificado además con un **segundo instrumento**. Los sustos son **posicionales**. ⚠ **No viaja en
> el commit**: `sound/` está gitignoreado, los `.ogg` cambiaron en disco y viajan en el `.gma`.
> El respaldo está en `dev/other/OLD/…(BACKUP BEFORE MONO POSICIONALES)`, ahora con 21 clips.
>
> ⚠ **Las marcas `-- SUSTOS voz N` del Lua son parte del instrumento**: el script extrae entre ellas y
> revienta si alguien las borra. Van **dos pares** porque un solo par se habría llevado los 30 clips de
> la voz 2 **que el autor ya dio por buenos**.
>
> ⭐ **`appear` dura 10 s** (igual que `chase`), y **`standing` tiene DOS comportamientos de equipo**:
> no grita, salvo la variante que hace parpadear las luces **de forma continua**. *El caos no se sigue
> de la actividad ni del evento: se sigue de la manifestación SOSTENIDA.*
>
> ⚠⚠⚠ **El drenaje de cordura que se habría contado dos veces.** Si el parpadeo de las manifestaciones
> pasara por `EV.light`, cada una cobraría el drenaje del evento **por cada luz que toque**. La
> pregunta del autor —¿se puede parpadear sin pasar por el evento?— se contestó **leyendo**: hoy
> **no**, `EV.light` es monolítica (censo + estallido + parpadeo inline). **Decisión: extraer el
> parpadeo y que el evento sea un llamador más** — *el drenaje pertenece al EVENTO, no al EFECTO*. ⚠ Y
> esa refactorización necesita un control que **cuente los que NO pasan** por el helper (nº 89), no
> sólo uno que sabotee el helper.

> ⭐⭐⭐ **LO ÚLTIMO (2026-08-20): LAS MANIFESTACIONES DISEÑADAS Y DECIDIDAS — §22 completa. LO
> SIGUIENTE ES LA CORDURA.** Detalle en el CHANGELOG **(55)** y **(56)**. **Ninguna línea de código de
> las manifestaciones está escrita, y es a propósito.**
>
> ⭐⭐ **De los tres bloqueantes queda UNO.** ShadowForm se destrabó con una decisión de **alcance**:
> no habrá tiers de linterna como ítem, se usa **la de HL2** (compatibilidad con Cargo primero), y la
> **UV es la misma en violeta**, desbloqueable desde el wheelmenu. La medición de (55) —cero
> `ProjectedTexture` en el addon— era correcta y **quedó sin objeto**. *El obstáculo no se salvó, se
> salió del camino.* Queda medir si esa linterna proyecta la sombra del nextbot
> (`r_flashlightdepthtexture`): diez segundos.
>
> ⭐ **La escala de actividad quedó completa y su mitad de abajo ya corre:** los **ocho eventos** que
> ya cerraron en juego hacen actividad **< 6**; `standing` 6-7; `mist`/`singing`/`appear` 7-8; `chase`
> 8-9; el hunt 10. *No hay que inventarla, hay que enchufarla.*
>
> ⭐ **`scare_light` y `scare_strong` registradas** (179 → **183** rutas vigiladas), **sin consumidor y
> dicho así**. Y que no puedan sonar solas se **leyó** antes de escribirlas: el sorteo recorre una lista
> fija, nunca `pairs`.
>
> ⚠⚠ **Los cuatro sustos NO coinciden entre sí:** `scare_strong/voice_1` es **mono** y los otros tres
> **estéreo**, y Source no espacializa estéreo. 2D puede ser lo correcto para un susto de contacto —
> **lo que no puede ser es que uno se comporte distinto que sus hermanos**. Decisión abierta;
> `mono_posicionales.py` **no** los toca a propósito.
>
> ⚠ **El canto se CORTA** con `StopSound` al terminar la manifestación — lo que obliga a que salga por
> `ghost:EmitSound` y no por `sound.Play`, que no devuelve nada que se pueda apagar.
>
> 🔜 **LO SIGUIENTE ES LA CORDURA**, y el autor la termina él. Su dependencia de Cargo **ya está
> resuelta**: las pastillas son consumibles de un solo uso, stackeables. Después van las **tres
> formas** (render puro) y recién después los **cinco eventos**.

> ✅ **EL BLOQUE DEL BOT PEGADO Y EL VIDRIO SE CIERRA SIN ESCRIBIR CÓDIGO (2026-08-20).** Lo pidió el
> autor hace seis rondas, nunca tuvo línea de investigación, y **las dos mitades resultaron no ser del
> addon**. Las contestó él:
>
> · **El vidrio** — *«era el navmesh del mapa, que era bastante malo en la casa grande»*. No es un
> defecto de nuestro pathing ni de la máscara de atravesar: el bot pedía un camino que el navmesh
> declaraba válido. **Nada que arreglar acá.** ⚠ Vale como precaución para futuras corridas: un
> síntoma de navegación medido en un solo mapa puede ser del mapa, y el addon no tiene forma de
> distinguirlo desde adentro.
>
> · **El pegado** — *«era que me estaba mirando con `movement_watch` o parado por `movement_stalk`»*.
> O sea que **no estaba trabado: estaba haciendo lo que su tarea decía**, y lo que se leía como un
> atasco era comportamiento deliberado de la base. **Lo está resolviendo otra sesión.** ⚠ Ojo con
> `phantom_doorWorst`: ese cronómetro cuenta *«velocidad < 30 u/s con una puerta delante»* y **no sabe
> por qué** el bot está quieto, así que un `peor 19,7 s` puede ser un `movement_watch` y no una puerta
> que no abre. *Un cronómetro de atasco que no lee la TAREA mide quietud, no bloqueo.*
>
> ⭐ **Y las dos juntas dejan una lección barata:** el prompt de aquel bloque traía como pista *«la base
> Terminator tendría convars para ver el thinking del NPC»*, y **nunca hizo falta medirlo** — el autor
> lo resolvió mirando el juego. *Dos rondas de investigación que no se gastaron porque el que ve la
> pantalla sabe cosas que la consola no imprime.*

> ⭐⭐⭐ **LO ÚLTIMO (2026-08-19, cierre del pedido 2): `x0.412` EXACTO, Y EL NÚMERO CAE DONDE EL
> ÁLGEBRA LO PUSO.** Detalle en el CHANGELOG **(54)**. Con el sujeto en el estado correcto
> (`typespeed 1`) el reporte dio `= tipo x0.588 ( campo phantom_SpeedMul ) × global x0.700`, con
> `speed.base campo x0.588 · la tabla dice x0.588 · COINCIDEN`. **0,588 × 0,700 = 0,412**: no es que
> el número «haya cambiado», es que cae exactamente donde la fórmula lo predice, con los tres
> factores impresos por separado. *Un número que cae donde el álgebra lo puso mide el mecanismo; uno
> que simplemente es distinto del anterior sólo mide que algo se movió.*
>
> ⭐⭐ **Y cierra la P0 en la escena que originó el reporte:** `deseada 115 · real 115` con
> `marcha CAZANDO` contra los **280 u/s** del jugador — **el Revenant lo persigue al 41 % de su
> velocidad y no puede alcanzarlo nunca**. Mismo veredicto que con el tipo apagado, ahora con el tipo
> puesto: **el multiplicador es inocente del «rapidísimo»**.
>
> ⚠⚠ **Dos consecuencias de haber prendido `typespeed 1`, que llevaba quién sabe cuánto en 0:**
> (1) los **once** tipos con `speed.base` ≠ 1.000 recién ahora mueven la velocidad — o sea que **la
> mitad de Diseño 5.1 estaba apagada en la máquina del autor sin que nada lo dijera**; los dos más
> lentos (`deildegast`/`deogen`, 0.235) con el global en 0,7 quedan en **46 u/s**, que es caminar
> despacio, y el global ahora multiplica a los 30. (2) **`speed.top` pasa de tentación a candidato con
> motivo**: el Revenant trae `top x1.765 ( alterna )`, y en Phasmophobia el Revenant es lento mientras
> no sabe dónde estás y muy rápido cuando te ve — eso *es* la alternancia. **Sospecha no medida:** que
> el «revenant rapidísimo» sea el recuerdo del juego original y no una lectura de este addon.
>
> ✅ **Y LA FILA 06 CERRÓ EN LA MISMA SESIÓN: `x0.588 = tipo x0.588 × global x1.000`, `objetivo
> 165 u/s`** — el número que el criterio pedía escrito de antemano (`280 × 0.588 = 164,6`). Con el
> global en 1 el producto es el `speed.base` del tipo **pelado**, y eso **no se podía deducir de la
> 05**: aquélla probó que los dos factores se multiplican, ésta que **multiplicar por 1 no mueve a
> nadie**. Su segunda mitad también discriminó y era del instrumento: el aviso del global **no
> apareció** con la convar en 1, así que la guarda `math.abs( global - 1 ) > 0.0005` está bien puesta.
>
> **EL ARCO DEL PEDIDO 2 QUEDA CERRADO**, y con él la frase *«las filas de velocidad viejas no hay que
> re-correrlas»* deja de ser una afirmación y pasa a ser una medición — era lo único que el bloque
> había escrito sin poder respaldar.
>
> ⚠ **Queda sin correr, de este arco: la fila 03 y nada más** — la tirada pegajosa, con la
> precondición arreglada (`phasedoors 1`, `doorchance 0.3`, `reset`, el cuerpo en el vano; **nunca**
> `phasedoors 0`). El defecto que iba a atrapar está refutado **a medias** por los `tiradas 3 /
> vistas 16` y `tiradas 17 / vistas 20` de las filas 01 y 02: eso mide el promedio, no los diez
> segundos pegado.

> ⭐⭐⭐ **LO ÚLTIMO (2026-08-19, r1 CORRIDA): 9 DE 9 EN JUEGO, LOS DOS DEFAULTS MOVIDOS… Y TRES DE
> ESOS NUEVE VERDES NO MIDEN LO QUE DICEN.** Detalle en el CHANGELOG **(53)**; la corrida entera en
> `dev/CORRIDA_puertas_chance_r1.md`.
>
> ⭐⭐ **Los dos defaults, por decisión del autor:** `phantasmagoria_ghost_doorchance` **0 → 0.1** (el
> número sale de la fila 02: con 0,30 salieron 4 de 17 y anotó *«si abre unas pocas, good tal como
> quiero»*), y `phantasmagoria_ghost_huntvozlvl` **150 → 80**, que **revierte la decisión de la r3**.
> Lo que el 150 tenía en contra estaba escrito en el código desde la r3 y **sin medirse** —un SNDLVL de
> 150 casi no se atenúa y en un mapa abierto se oye de lejísimos—: el autor jugó con él puesto y volvió
> al 80. *La advertencia estaba bien y el veredicto era del juego, no del renglón.* La brecha de
> 12,3 LU sigue intacta: el SNDLVL nunca fue la perilla que podía emparejar los clips.
>
> ⭐ **El pedido 1 está medido de punta a punta.** Fila 00 `tiradas 0 · atraveso 9 · VETADAS 6` (el
> control se corrió de verdad); fila 01 `tiradas 3 · salio abrir 3 · abiertas 3 · huellas 3` —los
> cuatro tramos—; fila 02 `17 tiradas · 4 abrir` con la chance en 0,30; fila 04 `pases del EVENTO 9` y
> **seis `door efecto CONFIRMADO`**. **El evento `doors` dejó de estar inerte con `opendoors 0`**, que
> es la combinación en la que el autor juega.
>
> ⚠⚠⚠ **EL NÚCLEO DEL PEDIDO 2 SIGUE SIN MEDIRSE: `phantasmagoria_ghost_typespeed` ESTABA EN 0.** Las
> dos lecturas dicen `= tipo x1.000 ( sin tipo… typespeed 0 )  ×  global x0.700`, cuando la fila pedía
> `= tipo x0.588 × global x0.700`. Con el campo vacío la fórmula nueva da `1.0 × convar`, que es **el
> `else` viejo escrito de otra forma**: el código viejo y el nuevo imprimen **el mismo número** en esa
> configuración, así que ni la 05 ni su control la 06 podían distinguirlos. *La precondición enumeraba
> los once tipos válidos y no nombraba la perilla que vuelve inválido a cualquiera de ellos.*
> **Falta una lectura:** `typespeed 1` → `type revenant` → `speedmul 0.7` → `ghost_speed` solo. Tiene
> que decir `x0.412`.
>
> ⚠⚠ **La P0 SÍ dio veredicto, y absuelve al multiplicador:** `280 × 0.700 = 196 u/s` contra los 280
> del jugador, con `deseada 196 · real 196`. **El fantasma va más lento que el jugador, medido**, así
> que *«revenant rapidísimo»* no sale de esta perilla. La P0 nombra al sospechoso: **`typespeed 0`**,
> que impide que **cualquier** tipo mueva la velocidad. Hipótesis anotada y no medida: la r18 registró
> un `x2.000 de convar · 560`, las dos convars son `FCVAR_ARCHIVE`, y un `speedmul` sobrevivido de
> aquel A/B con `typespeed 0` daría 560 contra 280 — el doble. ⚠ **Y el pedido 2 no arregla eso**: el
> arreglo es `typespeed 1`.
>
> ⚠⚠⚠ **LA FILA 03 NO SE CORRIÓ Y LA CULPA ES DE SU PROPIA PRECONDICIÓN.** Salió `tiradas 0` porque se
> usó `phasedoors 0` para clavar al bot — y la tirada **sólo existe para el que iba a atravesar** —,
> y la precondición sugería justamente eso. *Un apagador con instrucciones.* El defecto que iba a
> atrapar **queda refutado por otra vía**: el Think corre a 10 Hz y salieron `tiradas 3 / vistas 16` y
> `tiradas 17 / vistas 20`, o sea **una tirada por encuentro y no por tick**. Más débil que la fila
> propia: mide el promedio, no los diez segundos pegado. Se corre bien con `phasedoors 1` y el cuerpo
> en el vano.
>
> ⚠ **Residuos anotados y no tocados:** `1 FORZADAS a solido por el techo de 5 s` (ya estaba), tres
> `door SIN EFECTO` en `prop_door_rotating` estado 0 —uno explicado por *«ya venía trabada»*, `#537` y
> `#540` **no**—, y `peor 19.7 s` con `opendoors 0` **y** `phasedoors 0`, que es un atasco **por
> construcción** y no una medición del bot pegado.

> ⭐⭐⭐ **LO ÚLTIMO (2026-08-19): LOS DOS PEDIDOS DEL CIERRE ANTERIOR, ESCRITOS Y SIN CORRER EN JUEGO.**
> La puerta que se abre **por chance** y el multiplicador global que el tipo se comía. Detalle en el
> CHANGELOG **(52)**. Planilla nueva: `dev/checks/phantasmagoria-puertas-chance-r1.html`, **nueve filas**,
> con los tres auditores de planilla en verde.
>
> ⚠⚠⚠ **EL PEDIDO 2 TRAE UNA TRAMPA Y ESTÁ DICHA ANTES DE CORRER: el arreglo pedido es correcto y el
> síntoma que se le atribuyó NO SE SIGUE DE ÉL.** El autor ve *«revenant rapidísimos aunque tenga mi
> multiplicador en 0.7»*, pero el Revenant tiene `speed.base 0.588` y nadie lee `speed.top`: hoy va
> **× 0.588, más lento que el jugador**, y con su multiplicador aplicado queda en **× 0.412**, más lento
> todavía. *El síntoma es real y el lugar no.* Los cinco sospechosos que sí explicarían un fantasma
> rápido los separa **una sola lectura**, que es la **fila P0** y se corre **primero**. Sin ella, el
> cambio se lleva un crédito que no le toca.
>
> ⭐⭐ **`phantasmagoria_ghost_doorchance` (0…1, default 0).** La probabilidad de que un fantasma que
> **iba a atravesar** abra en su lugar. Es convar nueva y **no** un tercer valor de `opendoors`, cuyo `0`
> es el control negativo de cuatro filas viejas. Con la perilla en 0 el comportamiento de hoy queda
> idéntico. **La tirada es pegajosa por par (fantasma, puerta) y de TRES estados** —`abrir`,
> `atravesar`, y la entrada ausente—: por tick sería una probabilidad diez veces por segundo, o sea que
> abriría siempre, y **la fila 03 es la única que puede ver ese defecto**. La apertura pasa **por la
> escalera** (la huella sale de ahí y de ningún otro lado) y **el veto consulta la decisión** (si no,
> el contador sube, la hoja no se mueve, y no hay error).
>
> ⭐⭐ **El evento `doors` vuelve a mover la hoja, también con `opendoors 0`** — decisión del autor entre
> las dos lecturas posibles de su pedido. Y eso corrige un defecto **medido y sin corregir**: el veto se
> comía su `Use2` entero, y aquello **se había arreglado del lado del instrumento** (la bitácora decía
> `door SIN EFECTO`) **y no del lado del comportamiento**. Mecanismo: un **pase de un solo uso**, contado
> aparte de `VETADAS`.
>
> ⚠ **El default de `doorchance` está en 0 y hay que moverlo.** Cuando el autor elija el número en juego,
> ese número va **al default, en el código**: `FCVAR_ARCHIVE` guarda en su máquina y **no viaja en el
> `.gma`**.
>
> ⚠ **Lo que NO se escribió, a propósito:** `speed.top` / `isRange` / `alt` / `losSpeedUp` (13 de los 30
> tipos traen segunda velocidad). Es tentador **justamente porque** el `top 1.765` del Revenant
> explicaría el síntoma — y por eso no va acá: mezclarlo haría imposible saber cuál de los dos cambios
> produjo qué.

> ⭐⭐⭐ **LO ÚLTIMO (2026-08-19): LAS TRES RONDAS CERRADAS Y PUSHEADAS** (`f4d2057`) — 11/12, 12/12 y
> **7/7**. El trace de mano pasó de **1 de 4** a **5 de 6** huellas por el camino bueno, el orbe tiene
> fade en las dos puntas, y la partícula de gmpa está afuera. Detalle en el CHANGELOG **(50)**.
>
> ⚠⚠ **`f4d2057` SE LLEVÓ LA ENTRADA (48) DEL CLIC, que es de otra sesión**, bajo un mensaje que no la
> menciona. No se perdió nada, pero **buscar el clic por `git log` no lo va a encontrar**. Armé el
> índice hunk por hunk para no hacer exactamente esto, y falló porque **las dos sesiones insertamos al
> principio del CHANGELOG**: git juntó los dos textos en un hunk contiguo y mi criterio de mayoría lo
> declaró mío. *El hunk no es la unidad de autoría.* Y con ella vino una colisión de numeración: hubo
> **dos entradas (48)**; la del clic se quedó con el número y la mía pasó a **(49)**.
>
> ⭐⭐⭐ **La r2 corrida: 12 DE 12, Y EL VERDE DE LA FILA 02 ESCONDÍA EL DATO.**
> Detalle en el CHANGELOG **(49)**. Planilla nueva: `dev/checks/phantasmagoria-evidencia-r3.html`,
> **siete filas**. Sin correr en juego.
>
> ⚠⚠ **Tres de cada cuatro huellas del fantasma salían por el FALLBACK** (`via cercano`), no por el
> trace de mano. La fila pasó —el fallback cae sobre la superficie por construcción, para eso se
> eligió— pero **el camino que da la normal real casi nunca corría**, y eso no lo dice el ojo: lo
> dice el `via`. *Un verde que se apoya en el plan B es un verde prestado.* La causa estaba escrita
> hace rondas en el mismo archivo: `doorAhead` justifica su hull diciendo que **una línea se cuela
> por el hueco del marco**, y yo tiré la línea hacia adelante del bot, que es ese tiro. Ahora la
> línea **apunta a la hoja** (`NearestPoint` + 24 u de retroceso + tiro hacia adentro).
>
> ⭐ **La partícula de gmpa SE FUE del addon**, por dictamen del autor comparando los dos en juego:
> *«se ve muchísimo mejor el nuestro»*. Se fueron el `.pcf`, la carpeta `particles/`, la convar
> `phantasmagoria_orbe_modo`, las tres ramas del código y el crédito —**marcado retirado, no
> borrado**—. El addon **no depende de ningún asset de terceros para los orbes**: el sprite
> (`sprites/light_glow02_add`) viene con el juego.
>
> ⭐ **Un orbe, no seis.** *«Es como un orbe → un fantasma»*: `phantasmagoria_orbe` sin argumentos
> pone **uno** con 64 u de dispersión, y el emisor quedó con `n = 1` — que es, literalmente, *«un
> solo orbe que se mueva, aparezca y desaparezca»*.
>
> **Límite conocido y aceptado por el autor:** con la puerta **ya abierta** la huella a veces queda
> mal pintada. Con la hoja abierta lo que se apunta suele ser el **canto**, y una mano de 13 u sobre
> un canto de 4 se lee mal por geometría. *«Por ahora está aceptable.»*
>
> ⚠ **Y un hallazgo que NO es de este bloque:** el instrumento de puertas imprimió
> `2 FORZADAS a solido por el techo de 5 s: eso no deberia pasar` (52 atravesadas). Es del bloque de
> atravesar y **lo marca su propio instrumento**; no se tocó.

> ⭐⭐⭐ **LO ÚLTIMO (2026-08-18, r1 corrida): 11 DE 12 EN JUEGO, Y LAS TRES NOTAS DEL AUTOR VALIERON
> MÁS QUE LOS ONCE VERDES.** Detalle en el CHANGELOG **(47)**. Planilla nueva:
> `dev/checks/phantasmagoria-evidencia-r2.html`, **once filas**. Los tres arreglos están escritos y
> **sin correr en juego**.
>
> ⚠ **La huella del fantasma caía a la altura de los tobillos y separada de la hoja**, y la causa
> estaba escrita en el encabezado del propio sondeo: **es un `TraceHull`**, cuyo contacto queda a
> medio ancho del bot del plano y se resuelve abajo. Y el sondeo **tiene que seguir siendo un hull**
> (una línea entra por el hueco del marco y no ve la puerta), así que no era un parámetro para
> ajustar: **son dos preguntas distintas** — encontrar la puerta quiere un volumen, dejar una mano
> quiere un punto. `PHANTASMAGORIA.HandPointOnDoor` tira su propio trace de línea a 48 u, y el
> fallback es `NearestPoint` (que cae **sobre** la superficie) y no el punto del hull. El instrumento
> imprime `via linea` / `cercano` / `manual`.
>
> ⚠ **La única fila roja acusaba a un código sano, y la pregunta del autor era la corrección:**
> *«¿debería funcionar realmente? o sea estoy en singleplayer»*. En singleplayer el `retry`
> **reinicia el servidor**, así que no queda huella que resincronizar — la fila no podía distinguir
> «el resync no anda» de «no quedó nada que mandar». Ahora hay `phantasmagoria_uv_resync`, que mide
> el camino sin tocar el server.
>
> ⭐ **El orbe pasó a ser PROPIO** — *«¿son verdes? no deberían ser blancos tenues… como partículas
> de polvo que se mueven erráticamente»* —, y eso **salda la deuda que la r1 dejó escrita**: una
> partícula la ven todos y no admite gate; un sprite client-side sí, que es como el orbe funciona en
> Phasmophobia. `sprites/light_glow02_add`, aditivo y sin `$ignorez` (lo tapa una pared).
> **El movimiento no viaja: viaja una SEMILLA** y el cliente deriva la deriva — un orbe cuesta un
> mensaje y no un stream. Calibración en tres convars de cliente (`_tam`, `_alfa`, `_deriva`), y
> **`dur 0` = no caducan**, que es la forma que va a usar la habitación favorita.
>
> El modo `pcf` queda **una ronda** para comparar, con una decisión pendiente en la fila 08 de la r2:
> **si el propio convence, se saca `particles/gmpa_fx.pcf` del addon** y con él el crédito de
> terceros.

> ⭐⭐⭐ **LO ÚLTIMO (2026-08-18, más tarde): LA EVIDENCIA QUE SE VE — las huellas tenían productor
> desde la ronda 6 y NINGÚN consumidor; los orbes no existían ni como dato.** Detalle en el CHANGELOG
> **(46)**. Planilla nueva: `dev/checks/phantasmagoria-evidencia-r1.html`, **doce filas**.
> **Nada de esto está probado en juego todavía.**
>
> Pedido del autor: *«sobre los orbes y las manos que quedan en las puertas… quiero que veas para que
> podamos testear eso, tipo spawnear una huella y un orbe, cosa que cuando tengamos el código de
> habitación favorita del ghost se pueda generar esos efectos»*.
>
> Lo escrito es `lua/autorun/phantasmagoria_evidencia.lua`: la huella viaja al cliente y **se
> dibuja** bajo `PHANTASMAGORIA.HoldingUV()` — hoy la convar `phantasmagoria_uv`, **gate provisional**
> hasta que exista la linterna, y está en una función justo para que ese día cambie **un cuerpo**.
> Comandos: `phantasmagoria_huella` · `phantasmagoria_huella_limpiar` · `phantasmagoria_orbe` ·
> `phantasmagoria_orbe_emisor` · `phantasmagoria_orbe_limpiar` (server, admin) ·
> `phantasmagoria_uv_toggle` · `phantasmagoria_uv_estado` (cliente).
>
> ⚠⚠ **Las «dos líneas» que el diseño daba por hechas para los orbes no habrían dibujado nada.**
> §11.3 cerraba el tema con `ParticleEffect( "gmpa_ghost_orb_green", … )`, y la línea es correcta —
> lo que no se había mirado es si la partícula **existe en la máquina donde iba a correr**. Barridos
> los **880 addons** del workshop local: **gmpa no está suscripto**, el `.pcf` sólo vivía en
> `dev/other/`. *Un `ParticleEffect` sobre un sistema que no existe no dibuja y no tira error* — el
> mismo silencio con el que los orbes estuvieron muertos dentro de gmpa toda su vida, allá por un
> `IsValid()` sobre un `Vector`. El archivo se copió a `particles/gmpa_fx.pcf` (**no se versiona**:
> `particles/` está en el `.gitignore` como todo asset — reponerlo con el `cp` de `docs/ASSETS.md`),
> y el código hace `file.Exists` **antes** de `game.AddParticles` y grita si falta.
>
> ⚠ **El hook `PhantasmagoriaGhostUsedDoor` ahora lleva TRES argumentos** (`ghost, door, p`). Con dos,
> el consumidor sabe qué pasó pero no tiene la huella, y el síntoma sería *«el contador sube y la
> puerta se ve limpia»*. El consumidor **grita si llega `nil`**.
>
> ⚠ **El defecto que apareció revisando lo propio, y que sólo se rompe según dónde estés parado:**
> `net.ReadEntity` devuelve NULL si el cliente todavía no conoce la entidad, y una puerta **fuera del
> PVS del que recibe** entra justo en ese caso. La primera versión podaba con `not IsValid( p.ent )`
> y perdía esa huella **para siempre**. Ahora viaja también el `EntIndex`, la poda es **sólo por
> tiempo**, y `phantasmagoria_uv_estado` cuenta **por separado** las vivas y las que todavía no
> resolvieron su puerta.
>
> **Lo que queda abierto y es de diseño, no de código:** en Phasmophobia el orbe se ve **sólo por la
> videocamara**, igual que la huella sólo bajo la UV. Una partícula del engine no admite gate por
> jugador — para eso hay que reimplementar el orbe como sprite client-side, con el mismo patrón que
> la huella. Y **cuánto dura una emisión** de `gmpa_ghost_orb_green` no lo sabemos: sale de la
> corrida (filas 10 y 12) o no sale.
>
> **La API que espera a la habitación favorita** (§14 del diseño, que sigue sin existir):
> `PHANTASMAGORIA.SpawnOrbs( pos, n, radio )` y
> `PHANTASMAGORIA.StartOrbEmitter( pos, periodo, dur, n, radio )`. El emisor calcula sus repeticiones
> y **se muere solo** — no repite la fuga de timers de gmpa.

> ⭐⭐⭐ **LO ÚLTIMO (2026-08-18): LA CACERÍA CORRIÓ 11 DE 11 Y LA CORRIDA DEVOLVIÓ LO QUE FALTABA
> — UN FANTASMA, UN ARCHIVO. Y la pregunta sobre ecualizar se midió: no es ecualización, son
> 12,3 LU.** Detalle en el CHANGELOG **(49)**. Planilla nueva:
> `dev/checks/phantasmagoria-caceria-r2.html`, **once filas**.
>
> El autor: *«los fantasmas en phasmophobia solo usan un solo archivo de audio loopeado en toda la
> partida … los Alternates hablan con varias voces, así que el hunt debería ser tipo un flag para
> cada fantasma»*. Lo anterior **no estaba roto: resolvía el caso general cuando el caso normal es
> el particular** — encadenar seis clips hace que el fantasma suene *a un banco de sonido*.
>
> **Tres modos**, con prioridad **fantasma → tipo → convar → default**: `uno` (el default, un clip
> sorteado una vez y loopeado toda la partida) · `varios` (encadena — los Alternates, **y es EL
> CONTROL**: es lo único ya medido 11 de 11) · `mudo`. ⚠ El default es el modo **nuevo** a
> conciencia: *una corrección cuyo efecto depende de que alguien tipee algo no es una corrección, es
> una opción*.
>
> ⚠⚠ **El clip fijo reabrió un cabo que la entrada anterior había cerrado en su mitad.**
> `phantom_ResetVoice` descarta la voz al cambiar el tipo y era completo **el día que se escribió**;
> el campo nuevo lo volvió parcial sin que nada avisara — un Banshee sobre cuerpo de Male quedaría
> hablando femenino y **cazando grave**. Es el nº 61 del catálogo.
>
> ⚠⚠ **«¿le hacemos una ecualización?» — NO.** Instrumento nuevo `dev/sonoridad_ogg.py` (EBU R128):
> el gorgoteo está a **−26,4 LUFS** y el canto a **−20,0**; el banco entero abarca **12,3 LU**. El
> oído del autor midió bien, pero LUFS **ya lleva la ponderación del oído**, así que eso es
> **ganancia y no espectro**: ecualizar cambiaría el timbre para arreglar algo que no es el timbre.
> Y **el modo `uno` lo vuelve jugable**: encadenando la brecha se promediaba sola; con un clip fijo, a
> quien le toque `voice_2_loop_03` caza 10 dB más bajo **toda la partida**.
>
> ⚠⚠⚠ **Lo que el Lua NO puede arreglar:** el `volume` de `EmitSound` **sólo baja**, así que nivelar
> desde acá empareja hacia abajo y los tres clips flojos no se pueden subir — eso es tocar los `.ogg`,
> con backup previo, y **lo decide el autor**. Por eso `phantasmagoria_ghost_huntvoznivelar` arranca
> en **0**: el estado que ya se aprobó no se cambia sin pedirlo. Las filas **09 y 10** son esa
> decisión, y la 10 es corrible sólo gracias a `phantasmagoria_ghost_cazaclip`, que fija el clip a
> mano — sin él dependría de un sorteo de 1 en 7, y **un check que depende de un sorteo no es un
> check**.
>
> ⭐ **CERRADO (CHANGELOG 50): 11 de 11 otra vez, y el autor eligió.** *«pensándolo bien mejor no, el
> otro comando para aumentar el volumen a 150 está bien»* — **ni se tocan los `.ogg` ni se baja
> nada**: `phantasmagoria_ghost_huntvozlvl` pasa de **80 a 150** por default, con el techo a 180 para
> que el valor elegido no quede pegado al máximo. El default se mueve con él porque `FCVAR_ARCHIVE`
> guarda **en la máquina del que tipeó** y esa configuración **no viaja en el `.gma`**.
>
> ⚠⚠ **Y no arregla la brecha:** el SNDLVL sube los catorce clips **por igual**, así que los 12,3 LU
> siguen intactos — resuelve *«al flojo no lo escucho»* y no *«unos suenan más que otros»*. Las dos
> vías para eso siguen sin tocar: `huntvoznivelar 1` empareja hacia abajo, y normalizar los `.ogg` es
> lo único que empareja hacia arriba. ⚠ 150 está en el orden de `SNDLVL_TRAIN`: en una casa es lo que
> se busca, **en un mapa abierto se va a oír de muy lejos**.

> ⭐⭐⭐ **LO ÚLTIMO (2026-08-18): EL HUNT DEJA DE SER MUDO — catorce clips que estaban en disco
> hace quince días sin un solo consumidor, y la voz que sale es la del CUERPO.** Detalle en el
> CHANGELOG **(45)**. Planilla nueva: `dev/checks/phantasmagoria-caceria-r1.html`, **once filas**.
>
> Pedido del autor: *«ahora que los ghost tienen sexo y modelo correspondiente, que asignaras en loop
> las voces de cacería»*. `ghost/hunt/` tenía **14 `.ogg` desde el 2026-08-03 y ninguna línea de Lua
> los citaba**; trece son la cacería del juego repartida por el **mismo índice** que ya decide el sexo
> del cuerpo. Quedan **6 clips / 250,1 s** en la voz 1 y **7 / 259,4 s** en la 2, encadenados sin
> repetir el anterior, colgados de `phantom_SetHunting` — la puerta única del flag.
>
> ⚠⚠ **La base YA tenía el mecanismo y no servía, por tres motivos medidos y ninguno de estilo:**
> `AngryLoopingSounds` está **apagado** (`CanSpeak = false`), se dispara con `IsAngry()` — que es
> *tener enemigo*, no el hunt, y este addon ya pagó una ronda por confundirlos — y además **latchea**,
> con lo que la cacería seguiría sonando después de que el hunt se apagó.
>
> ⚠⚠ **Y `breath_1.ogg` NO se cabló, aunque el autor lo ofreció.** El permiso era condicional
> (*«si es que lo necesitan»*) y la condición se fue a medir: **no hay fantasma sin voz**
> — `phantom_EventVoice()` devuelve siempre 1 o 2, y el degenerado cae al sorteo —, y el clip es
> **estéreo** (44100 / 2 canales), o sea que **Source no lo espacializa**: servido en 2D se oiría
> igual de fuerte desde cualquier lado, justo en el sonido cuyo trabajo es dejarte ubicar al
> fantasma. Queda declarado como banco neutro rotulado `DEGRADADO`, alcanzable sólo si un banco de
> voz queda vacío. Si alguna vez se lo quiere: **a mono primero**, con `dev/mono_posicionales.py`.
>
> **Instrumento nuevo:** `dev/caceria_bancos.py` — los largos están **escritos a mano** en el Lua
> (`SoundDuration` no es confiable server-side sobre `.ogg`) y ése es el dato que se desincroniza en
> silencio; el arnés compara cada número contra el archivo. **Y su propia perilla lo agarró
> mintiendo:** `--romper todos` inyectaba cuatro defectos y reportaba **tres** — uno pisaba al otro —
> y se daba por pasado porque exigía «al menos una falla». Ahora cada modo declara **cuántas**.
>
> ⚠ **Un comentario citaba un instrumento que no existe:** el bloque de la voz decía *«El reporte de
> `phantasmagoria_ghost_ev` lo imprime»* y ese comando **no está registrado en ninguna parte**, así
> que `phantom_evVoiceWhy` — el motivo por el que se eligió cada voz — no se podía leer en juego.
> Lo imprime ahora `phantasmagoria_ghost_caceria`.
>
> **Nada de esto corrió en juego.** Todo lo que pasa adentro del motor de sonido — encadenado, corte
> instantáneo, espacialización, dos fantasmas a la vez, el cadáver que sigue respirando — son las
> once filas de la planilla. El A/B está a mano y funciona **en vivo**:
> `phantasmagoria_ghost_huntvoz 0` devuelve el hunt mudo sobre el mismo fantasma que ya está cazando.

> ⭐⭐⭐ **LO ÚLTIMO (2026-08-18): EL EVENTO `prop` REVENTABA EN `gm_uh_house` Y YA NO. La causa no
> era un número mal leído: eran las cuatro letras `LZMA`.** Detalle en el CHANGELOG **(44)**.
>
> El `sprp` de ese mapa viene **comprimido**, y el parser leía la firma de compresión como si fuera la
> cantidad de rutas del diccionario (`1095588428`). **Dos defectos, no uno:** todas las guardas de
> conteo miraban **un solo lado** (`n < 0`, nunca «no entra en el tramo»), y `parsear` **podía tirar**,
> rompiendo el contrato que el propio archivo tiene escrito — con lo que el error subía hasta el
> concommand y el evento quedaba inservible **en cada disparo**, porque el fallo tampoco se cacheaba.
>
> ⚠ **El instrumento gemelo tenía el mismo defecto con otra cara:** `dev/censo_props_horneados.py` no
> revienta con ese número, **se cuelga**. *Un crash se ve; un cuelgue se lee como «todavía está
> trabajando».* Los dos arreglados, y los dos leen ahora el lump comprimido.
>
>     gm_funkis_night   418 / 1588   ( sin cambios: es el CONTROL )
>     gm_uh_house       188 /  702   sprp COMPRIMIDO · 10 modelos / 12 instancias reclamadas
>     ( ⚠ se cito 11/13 hasta el 2026-08-18: era el numero del instrumento en
>       Python, que tenia las reglas de ANTES de los tres vetos del 2026-08-16.
>       El addon corriendo siempre dijo 10/12. Hoy el .py lee las reglas del .lua. )
>
> ⚠⚠ **LO ÚNICO QUE NO SE PUDO MEDIR SIN EL JUEGO** es si el `util.Decompress` de GMod acepta la
> cabecera que el `.lua` le arma. Que el **dato** está ahí sí se midió (15005 bytes se abren en 78334).
> Por eso el camino **se verifica a sí mismo** contra el largo declarado en la cabecera, y si falla
> degrada a `ok = false` con motivo. Es la fila **P0** de la planilla.
>
> **Instrumento nuevo:** `dev/bsp_statics_offline.py` **carga el `.lua` del addon y lo ejecuta** sobre
> un `.bsp` del disco — el parser de mapas deja de necesitar una partida. Distingue `ok`, `ok = false`
> con motivo, y **error de Lua**, que son tres cosas distintas.
>
> ⚠ **Y el arnés nuevo se equivocó primero, de la peor manera:** `lupa` decodificaba como UTF-8 los
> bytes crudos del `.bsp`, y **el `pcall` recién agregado al addon atajó esa excepción y la imprimió
> como `ok = false` del mapa**. Un defecto del instrumento disfrazado de hallazgo sobre el sujeto,
> servido por la red de contención recién puesta. Ahora el arnés separa los dos `ok = false`.
>
> ### ⚠⚠ Y SOBRE EL SEGUNDO PEDIDO DEL AUTOR, que sigue sin escribirse
>
> El autor agregó la mitad que faltaba: *«una radio phys que se rompa no detiene el sonido **ni permite
> pararlo**»*. **Esa segunda mitad está confirmada leyendo el código, sin el motor:** `podarSonando()`
> tira la entrada de `SONANDO` cuando la entidad deja de ser válida, y `apagarCerca()` poda antes de
> buscar — o sea que **el registro suelta el único mango justo cuando haría falta**. Rota la radio, el
> `+USE` no tiene a quién apagar, ni ahora ni nunca.
>
> La otra mitad — si el sonido sobrevive al borrado de la entidad — sigue siendo la pregunta de las
> filas **00 y 01**, y ahora se puede correr, porque el mapa ya no revienta.

> ⭐⭐⭐ **LO ÚLTIMO (2026-08-17): EL CLIC DEL INTERRUPTOR Y EL CELULAR QUE NO ERA UN CELULAR.
> ESCRITO, CHEQUEADO OFFLINE, Y *SIN CORRER EN JUEGO*.** Detalle en el CHANGELOG **(43)**. Planilla
> nueva: `dev/checks/phantasmagoria-clic-y-celular.html`, **siete filas**.
>
> **De los tres pedidos que el autor dio al cerrar el `+USE`, dos están escritos y el tercero no —
> y eso último no es un olvido:**
>
> · ✅ **El clic.** Una línea al final de `apagarCerca`, en el **único** desenlace que apagó algo.
>   ⚠⚠ Los dos clips **eran estéreo** (0,23 s y 0,35 s, 2 canales, medidos con `dev/duracion_ogg.py`)
>   y **Source no espacializa un estéreo**: pasaron por `dev/mono_posicionales.py` **antes** del
>   cableado, y quedaron en 1 canal con la misma duración (backup verificado por sha256 en
>   `dev/other/OLD/` — `sound/` está gitignoreado, esa copia es la única). El extractor se **amplió**
>   para ver el banco nuevo, no se le pegó una lista, y ahora imprime **el denominador por fuente**.
>   Sin perilla: es una adición, no un recorte, y `apagados` dice cuántas veces tendría que haber
>   sonado.
> · ✅ **El celular.** `phone_vibrate` fuera de la familia teléfono (dos líneas y el comentario). La
>   familia queda con **UN** clip — un teléfono siempre suena igual — y eso es decisión del autor, no
>   un síntoma. El `.ogg` **queda en el disco**, sin consumidor, esperando un smartphone de verdad.
> · ⛔ **Que romper el prop corte el sonido: NO SE ESCRIBIÓ.** Ver abajo.
>
> ### ⚠⚠⚠ LA PRECONDICIÓN QUE HAY QUE MEDIR PRIMERO — filas 00 y 01 de la planilla
>
>
> ✅ **LA FRASE DE LOS CINCO LUGARES SE MIDIÓ, Y LA RESPUESTA SON DOS.** *«Borrar el emisor **ES** un
> corte: una entidad que se va se lleva su canal»* estaba en `server_events.lua:218`, `:875` y
> `:3409`, en `dev/duracion_ogg.py:8` y en el CHANGELOG (41), y **nunca se había medido**: nació como
> razón en un comentario y se citó después como si fuera un resultado.
>
> · Sobre **nuestro** `info_target` es **cierta** (r1 fila 00: `clock_tick` de 46,55 s cortado por el
>   borrado, con el `IsValid` de control diciendo que el borrado ocurrió).
> · Como **ley del motor es falsa** (r1 fila 01, y confirmado en la r2: un `prop_physics` que suena
>   sigue sonando después de romperlo).
>
> Valía donde nació y **se había mudado sola** a los otros cuatro lugares. Los cinco quedaron
> **acotados al emisor**, con la fecha y el contraejemplo al lado — no borrados: *si la prosa y el
> código discrepan, el próximo lector copia la prosa*.
>
> ✅ **Y EL PEDIDO 2 ESTÁ CERRADO EN JUEGO (r2, 2026-08-19).** El arreglo es un `ent:CallOnRemove`
> acotado a los props a los que **nosotros** hicimos sonar, con un `StopSound` **explícito** — no se
> apoya en el borrado, justamente porque el borrado es lo que estaba en duda. Con eso se cerró
> también **la segunda precondición que nunca se había medido**: un `StopSound` sobre una entidad
> *que se está yendo* **sí llega a tiempo**, así que el candidato alternativo (emisor propio
> `SetParent`-eado al prop) **no hace falta**. Los dos contadores `ROTOS.enganchados` /
> `ROTOS.callados` quedan en el reporte: son los que separan las tres causas de *«rompí la radio y
> sigue sonando»*, que se oyen exactamente igual.
>
> **Chequeos offline al día:** luacheck 37/37 · sintaxis real 37/37 · returns de hooks **0/32** ·
> **179 rutas de sonido citadas, 0 faltantes** · la guarda `( 3b )` **callada, y comprobada gritando**
> en dos casos rotos a propósito · `bsp_statics_offline.py` reproduce el control **418/1588** y da
> **188/702** · el censo de familias da **7/7 → discriminan Y están al día**, con sus dos negativos
> ejercidos.
>
> **Instrumentos nuevos y versionados:** `dev/rutas_de_sonido.py`, `dev/guarda_3b_offline.py` y
> `dev/bsp_statics_offline.py` (los tres **recortan el `.lua` del addon y lo ejecutan** en un Lua real
> — no lo reimplementan). Y `dev/censo_props_horneados.py` **dejó de ser una copia**: ahora recorta
> `PROP_CONSUJETO`, `BasenameDeRuta` y `NombreCoincide` del `.lua` y los ejecuta, porque su copia a
> mano se desfasó y estuvo dos días dando **11 / 13** donde el addon daba **10 / 12**.
>
> ⚠⚠ **VARIAS SESIONES TOCARON `server_events.lua` Y `CHANGELOG.md` LOS MISMOS DÍAS.** Los cambios
> del clic y el teléfono quedaron **adentro de `221c5e8`** («El cuerpo y la voz de cada fantasma»), y
> la entrada (48) del changelog quedó **adentro de `f4d2057`** («la evidencia que se ve»): las dos son
> de otras sesiones y **ninguna las menciona en su mensaje**. Nadie perdió trabajo, pero buscarlos por
> `git log` no los encuentra. ⚠ Hay además **dos entradas numeradas (50)** en el CHANGELOG, de dos
> sesiones distintas.
>
> ### 🔜 DESPUÉS DE ESTO
>
> El pedido que el autor hizo hace **cinco rondas** y que todavía no tiene línea de investigación:
> **por qué el bot se queda pegado y después se despeja solo, y por qué a veces quiere pasar a través
> de un vidrio** (ver el punto 2 de la lista de más abajo, que sigue vigente). Su pista: la base
> Terminator tendría convars para ver el *thinking* del NPC. ⚠ **No está medido que existan.**

> ⭐⭐⭐ **LO ÚLTIMO (2026-08-17): EL `+USE` APAGA LA RADIO, LA RADIO SUENA ENTERA Y LAS LLAVES SE MUDAN
> A UN PESTILLO. CERRADO EN JUEGO, 13 de 13, commit `ce9deca` y pusheado.** Detalle en el CHANGELOG
> **(41)**, con los números de cada mecanismo. La planilla
> `dev/checks/phantasmagoria-use-y-llaves.html` corrió entera **incluidas las cuatro filas que el
> bloque de props horneados había dejado sin correr** — las tres perillas nuevas en `0` las hicieron
> medibles hoy. El autor: *«en cuanto a comportamiento todo bien»*.
>
> Lo que quedó corriendo: `phantasmagoria_ghost_evuse` (hook `KeyPress`/`IN_USE` en el servidor, **sólo
> distancia y sin mirada**, porque el objeto es invisible; 128 u) · la familia radio sin `largo` y con
> `dur` medida por clip (`dev/duracion_ogg.py`, instrumento nuevo con auto-control) ·
> `phantasmagoria_ghost_evllaves` (sin sujeto el evento `prop` no suena, **y la línea sigue saliendo**)
> · `phantasmagoria_ghost_evpestillo` (`Fire( "Lock" )`, tope 2, vida 45 s, y
> `phantasmagoria_ghost_pestillo soltar` como salida de emergencia).
>
> ⚠ **Tres filas dieron el veredicto correcto sin probarlo ellas solas** y está anotado en el
> CHANGELOG en vez de acreditado: la A1 predecía `3 familias` desde el `.bsp` y salió `4` **porque el
> fantasma spawneó a ~150 u del punto de la predicción** (una predicción atada a una posición no vale
> para la habitación); la A3 trajo una de sus dos mitades y la otra la sostiene la A1; la 00 trajo dos
> pulsaciones de seis, pero las dos de la mitad que decide.
> ⚠ **Frontera con nombre:** `ritual_chanting_loop` es un loop y la fila de «suena entera» no se corrió
> con él. Y el `+USE` es **sólo** para radio y teléfono, por decisión del autor.
>
> ### 🔜 LO SIGUIENTE, PEDIDO POR EL AUTOR AL CERRAR (tres cosas)
>
> ⚠ **ESTA LISTA YA NO ES EL ESTADO: se escribió el 2026-08-17 al cerrar el `+USE`, y el bloque de
> arriba (CHANGELOG **43**) hizo la 1 y la 3. La 2 depende de una medición. Queda como estaba porque
> explica POR QUÉ se hizo cada cosa.**
>
> 1. Que apretar `+USE` **emita un sonido de botón**, sobre el horneado y sobre el `prop_physics`, para
>    que se note que apagaste el objeto. Candidatos suyos: `ui/button_toggle_1` y `_2`, *«ambos suenan
>    como apretar un interruptor sutil»*. ⚠⚠ **LOS DOS SON ESTÉREO** — medido el 2026-08-17 con
>    `dev/duracion_ogg.py`: 0,23 s y 0,35 s, **2 canales**. Source **no espacializa un estéreo**, así
>    que van a sonar planos y en 2D. Pasan por `dev/mono_posicionales.py` **antes** de cablearse, o el
>    bloque repite en silencio el defecto que la r3 pagó en quince archivos.
> 2. Que al **destruir** un `prop_physics` que está sonando (la radio de cs_office, el teléfono) **el
>    sonido pare**. Hoy el registro `SONANDO` poda por entidad inválida, pero **la poda sólo corre
>    cuando alguien mira el registro**: falta el camino del borrado (`EntityRemoved`, o el `StopSound`
>    en el momento).
> 3. **Sacar `phone_vibrate.ogg` de la familia teléfono.** El autor: *«corresponde a un celular; `phone`
>    como prop horneado o phys son generalmente teléfonos fijos, así que `phone_ring.ogg` está bien»*.
>    ⚠ Es un cambio de **una línea en la lista y una en `dur`**, y la guarda de carga (3b) grita si se
>    saca de una sola de las dos.
>
> **DESPUÉS DE ESO** sigue el pedido que el autor hizo hace tres rondas y que todavía no tiene línea
> de investigación: **por qué el bot se queda pegado y después se despeja solo, y por qué a veces
> quiere pasar a través de un vidrio** (ver el punto 2 de la lista de abajo, que sigue vigente).


> ⭐⭐⭐ **LO ÚLTIMO (2026-08-10). LA r3 CERRÓ 14/14 MEDIDO y el bloque de las PUERTAS PARENTEADAS
> CERRÓ EN JUEGO.** Detalle en el CHANGELOG, entradas **(37)** y **(38)**. Lo de abajo, escrito el
> 2026-08-09, describe la r3 *antes* de correrla: sigue valiendo como explicación de por qué se hizo
> cada cosa, pero **el estado ya no es «sin correr en juego»**.
>
> **LO QUE SIGUE, EN ESTE ORDEN:**
>
> 1. **PROPS HORNEADOS** — que suenen los `prop_static` del mapa. **Prompt completo en
>    `dev/PROMPT_phantasmagoria_props_horneados.txt`.** Censo rehecho el 2026-08-10 con instrumento
>    versionado (`dev/censo_props_horneados.py`): `gm_funkis_night` tiene **1588 `prop_static` / 418
>    modelos**, y las reglas reales de `PROP_CONSUJETO` reclamarían **12 modelos / 19 instancias**, de
>    los cuales **4 modelos / 8 instancias son FALSOS POSITIVOS** (una antena de skybox, una guía
>    telefónica, y seis rollos/dispensadores de papel higiénico que la familia «inodoro» toma por
>    inodoros). Verdaderos: **8 modelos / 11 instancias**.
>    ⚠ **El desglose que este documento citaba antes —«9 modelos, 3 radios, 2 parlantes, 2
>    despertadores…»— NO REPRODUCE:** contaba una familia que el addon no tiene (no hay familia
>    «speaker») y se perdía los inodoros. Su script no sobrevivió, y por eso el nuevo vive en `dev/`.
>    ⚠ **El bloqueante real no es leer el BSP:** un `prop_static` **no tiene entidad**, y las familias
>    con clip largo necesitan `EmitSound`/`StopSound` (el `clock_tick` dura 46,55 s) — la salida es un
>    **emisor invisible en el origen del prop**, y cuál entidad sirve para eso es una **precondición
>    sin medir**.
> 2. **POR QUÉ EL BOT SE QUEDA PEGADO Y SE DESPEJA SOLO, y por qué a veces quiere pasar a través de un
>    vidrio.** Pedido del autor, **después** de los props horneados. Su pista: la base Terminator
>    tendría **convars para ver el *thinking*** del NPC. ⚠ **Nada de esto está medido**: no se sabe si
>    esas convars existen ni qué exponen. Censarlas en la base (`rg --no-ignore` con denominador) antes
>    de escribir una línea de instrumento propio.
>    ⚠ **Una hipótesis apuntaba al arreglo de las puertas y ya está DESCARTADA en juego:** el
>    no-sólido entra sólo por cercanía (`distancia <= PHASE_RANGE`, 45 u) medida **al PANEL**, así que
>    el vidrio de una puerta podría prenderlo — pero el autor midió *«no traspasa los ventanales»*, con
>    `atravesó 1 vez` y `0,5 s` sobre la **puerta**. **El pasar-a-través-del-vidrio no es de ahí.**
>    ⚠ Lo que **no** cierra eso: *«no lo traspasa» no es «no lo intenta»* — **querer y poder son dos
>    cosas** y el síntoma reportado es de intención. Candidato vivo para el «se queda pegado y se
>    despeja solo»: `PHASE_MAX = 5` (techo duro) + `PHASE_COOLDOWN`. `phantasmagoria_ghost_doors` ya
>    imprime fases y fases largas, así que ese eje se mide con lo que hay.
>
> ⚠ **Frontera que quedó abierta a propósito:** `func_movelinear` (1 en el mapa, con hijos) **no
> abre** — no está en `DOOR_CLASSES` y el arreglo del padre no lo alcanza. Agregarla es tocar la
> tabla, que es lo que el bloque de las puertas decidió no hacer.

> ⭐⭐ **LO ÚLTIMO (2026-08-09, r3): EL FANTASMA ATRAVIESA. Escrito, revisado, y SIN CORRER EN JUEGO.**
>
> **La r2 dio 9 · 2 · 0.** Esta tanda cierra las dos fallas, contesta las tres preguntas del autor y
> estrena **cinco mecanismos nuevos**, cada uno con su `0` de control. **Lo primero del chat
> siguiente: correr `dev/checks/phantasmagoria-eventos-r3.html` (13 filas).**
>
> **EL PEDIDO QUE ENCABEZA:** *«que no colisione contra jugadores y npcs, que es bastante molesto y
> eso lo convierte directamente en un fantasma»*. Entra `server_collision.lua`, que **no toca ni el
> grupo de colisión ni la máscara** — la solidez sigue teniendo dueño único en `server_doors.lua` —
> sino `GM:ShouldCollide`, más un override de `PhysicallyPushEnt` para el empujón de 15000 que la
> base aplica sin filtrar por tipo.
>
> ⚠⚠ **DOS COSAS DE ESE BLOQUE NO SE PUDIERON MEDIR LEYENDO, Y LAS DOS DECIDEN SI FUNCIONA.**
> (a) **Sobre cuál de las dos entidades hace falta `SetCustomCollisionCheck`**: el único precedente
> del taller (HIM) la pone sobre el JUGADOR, no sobre el bot. Van **dos perillas** encendidas y la
> fila 02 las separa en la misma ronda. (b) **Si las balas siguen pegando**: la regla vive en
> `CGameRules::ShouldCollide`, que es C++. La fila 03 es la que no se puede saltear.
>
> **LAS DOS FALLAS, CON SU CAUSA MEDIDA.** La 05: `IsPlayerHolding()` **no cubre la physgun**, y está
> medido en juego en este taller sobre artagdoll. La 08 **se da vuelta**: la guarda del cadáver ya
> estaba puesta, así que el sujeto de la ráfaga **no era un cadáver** — la alarma pasa a flanco
> (de nivel borraba la bitácora entera en 0,6 s), cuenta el cadáver aparte, **sobrevive al fantasma**
> con `PHANTASMAGORIA.NoDrawSeen`, y **nombra al sospechoso**.
>
> ⚠⚠ **EL HALLAZGO QUE NO SALIÓ DE NINGUNA FILA: SOURCE NO ESPACIALIZA ESTÉREO.** La promesa entera
> del bloque nuevo es *«el teléfono suena DESDE el teléfono»*, y **14 de los 21 clips de las familias
> nuevas eran estéreo**: la incumplían en silencio. Medidas las **156** rutas del motor, **44 estéreo**.
> Se pasaron a mono los **15** posicionales sobre un objeto nombrado (`dev/mono_posicionales.py`,
> backup por sha256 y re-lectura del disco); los **29** restantes —creak, impact, breathing, humming—
> **no se tocaron**, porque el autor ya los escuchó y los dio por buenos, y tienen su propia fila.
>
> **LO QUE ENTRÓ ADEMÁS:** `SND.prop` de 18 clips planos a **2**, con nueve familias con sujeto
> reconocidas **por nombre de modelo** (lista negra medida sobre **6542 `.mdl`**: cinco de los nueve
> «radio» son pastillas anti-radiación y un detector; cuatro de los cinco `tv_` son escombros) · la
> **radio** cableada por fin, con `StopSound` · la **reserva de voz** (susurros sí, frases y canto
> no) · el banco de golpes partido en **cinco** (`SND.knock` tenía 1 puerta y 6 ventanas, así que
> golpear una puerta sonaba a ventana 6 de cada 7 veces) · la **correa** (`server_leash.lua`) · y
> `phantasmagoria_ghost_puerta`, que cuelga **del jugador** y contesta por qué el fantasma no abre
> las dos puertas de la piscina.
>
> ⚠ **LA REVISIÓN ADVERSARIAL PROPUSO 66 DEFECTOS Y SEIS LOS INTRODUJO ESTA MISMA TANDA.** Los tres
> que dejan regla: `clock_tick` mide **46,55 s** y quedó en el banco plano que este mismo archivo
> prohíbe veinte líneas más abajo *escrito el mismo día*; el contador de la fila 06 colgaba de una
> tabla que **sólo existe si el fantasma ya reconoció una puerta**, o sea que no podía subir en la
> escena para la que se escribió; y la correa cantaba un **rojo sobre sí misma funcionando**, porque
> cazando pasa derecho y los dos contadores quedan en 0. Detalle en el CHANGELOG (36).
>
> **UNA PREGUNTA PARA EL AUTOR, Y BLOQUEA SEIS CLIPS:** de los diez `.ogg` de `prop/radio/` se
> cablearon **cuatro**. Quedaron afuera `creepy_news`, `creepy_music_news`,
> `creepy_radio_easteregg_helpmewithend` y `event_creepy_eas_paranormal_radio_advise` **porque nadie
> los escuchó** y pueden traer voz hablada — y el pedido de esta ronda incluye *«quitar los sonidos
> del presentador británico»*. Los dos `ritual_*` quedan afuera por ser loops.
>
> ---
>
> ⭐ **LO ANTERIOR (2026-08-09): LA r1 DE EVENTOS CORRIÓ — 8 pasa · 0 falla · 3 sin correr. EL MOTOR
> ANDUVO. El que mintió fue el AUDIO, y el instrumento lo acreditó.**
>
> **Lo que quedó cerrado con evidencia del autor y no se re-discute:** las ocho categorías disparan,
> la perilla por categoría apaga sólo la suya, el A/B por tipo salió —*«un Poltergeist se comporta
> más agresivo con los props, rompió hasta una ventana»*, contra un Shade que *«no hizo casi nada
> como corresponde»*—, el hunt sube la intensidad, y **la tesis de §21.1 se confirmó en juego**:
> *«no sonó nada estando lejos»*. El ritmo también: *«si no es muy seguido se siente bien»*.
>
> ⚠⚠ **PERO CUATRO DE ESOS OCHO VERDES PODÍAN SALIR VERDES CON EL DEFECTO ADENTRO, Y UNO LO TENÍA.**
>
> **① EL BANCO DE VOZ ESTABA MUDO ENTERO Y EL REPORTE DECÍA `OK`.** Las dos líneas son del mismo
> disparo: `OK -- voz 1 / banco voice a 221 u` y, abajo,
> `*** Invalid sample rate (48000) for sound '...voice_1_why_01.ogg'`. Censados los **826 `.ogg`**:
> **270 con un rate que Source rechaza**, y **`voice` roto al 100 % — 39 de 39 clips**. La causa raíz
> estaba escrita como una decisión correcta en `about.txt` (*«reencodear ya-comprimido sólo
> pierde»*): cierto sobre la calidad, falso sobre la compatibilidad. **Reparados los 270 a 44100**,
> con backup verificado por sha256 y el árbol entero re-medido → **0 inválidos**. ⚠ `sound/` está
> **gitignoreado**: git no era la red de contención, el backup está en
> `dev/other/OLD/phantasmagoria_sound (BACKUP BEFORE RESAMPLE 44100)`.
>
> **② LAS LUCES: SE MIDIÓ EL BSP Y EL AUTOR TENÍA RAZÓN.** Se sacó `gm_funkis_night.bsp` del `.gma`
> del Workshop y se parseó el lump de entidades: **322 luces en el BSP, 43 con `targetname` y
> lightstyle conmutable, en 12 grupos**. gmpa **no tocaba lo horneado** y **buscaba la misma clase que
> nosotros** — de hecho somos más amplios (él pierde los 17 `light_spot`). La diferencia es el
> **radio**, y eso es la tesis. ⚠ **El cruce «si `throw` y `door` salieron, el fantasma estaba en la
> casa» está REFUTADO por medición**: 37 de 65 puertas y 14 de 15 props no tienen ninguna luz nombrada
> a 450 u.
>
> **③ EL VETO DE SANDBOX NOMBRABA DOS CAMPOS QUE NO EXISTEN.** `ent.CargoItem or ent.cargo_ItemID`:
> un grep sobre todo el workspace devuelve **una sola aparición de cada uno — esa línea**. El veto
> nunca vetó nada. ⚠ **Y cambiarle el nombre NO lo hizo alcanzable**: ningún escritor de
> `CargoContainer`/`CargoEntry` produce hoy una entidad de las dos clases de `THROW_CLASSES`. Queda
> como póliza y **ninguna fila lo acredita**.
>
> **④ LA ALARMA DE `EF_NODRAW` ACUSABA A UN INOCENTE.** La pregunta del autor tiene respuesta: **no es
> código nuestro**, el escritor es **la base, en la muerte del bot** (`damageandhealth.lua:826`).
> `#452/s10` era un **cadáver** y el reconciliador le seguía corriendo encima los ~10 s que sobrevive.
>
> **LO QUE ENTRÓ (r2, sin correr):** los 270 `.ogg` reparados · el veto de Cargo real
> (`CargoContainer`/`CargoEntry`) + constraints + parenteado + `IsMoveable` · desglose de vetados por
> motivo, también en el éxito · `lucesCerca` por `ents.FindByClass` y el mensaje de vacío midiendo el
> mapa · **las voces salen del fantasma** (pedido del autor) · **los sonidos de auto exigen un auto**
> (pedido del autor) · bitácora con serie `/sN` y rótulo `[FORZADO]` · dos cuentas separadas
> (espontáneas / forzadas) · el intervalo **sorteado** impreso · el `reset` que ya no borra
> comportamiento · la alarma acotada por `term_Dead`.
>
> ⚠⚠ **Y LA REVISIÓN ADVERSARIAL MATÓ CUARENTA DEFECTOS DE ESE MISMO CÓDIGO — los tres peores los
> introdujo esta tanda, y los tres son *un arreglo correcto en su eje que rompe algo en un eje que
> nadie nombró*.** (a) Un veto por `GetCreator` **habría apagado `throw` entero en sandbox**, porque
> todo prop del spawnmenu lleva creator — lo encontraron cuatro lentes por separado, y de paso:
> **`GetCreator()`/`GetOwner()` devuelven `NULL`, que es truthy**, así que la cadena `or` dejaba a
> `GetOwner` como código muerto. (b) El `EmitSound` de las voces **le voló el audio al cadáver**: el
> scheduler disparaba sobre muertos y con `sound.Play` eso sonaba, con `EmitSound` no, porque la base
> ya le puso `EF_NODRAW`. (c) El sonido con sujeto **agarraba la silla en la que estás sentado**.
> Además: mi arreglo del cadáver era **la mitad** (la guarda entró en el contador y no en la línea que
> el operador lee), el `reset` **se contradecía en tres frentes**, y el rótulo del hunt era **la foto
> vieja otra vez**. Todo arreglado; detalle en §21.9.9.
>
> **LO PRIMERO DEL CHAT SIGUIENTE:** correr `dev/checks/phantasmagoria-eventos-r2.html`. ⚠ **La fila
> de las luces es la que decide**: en `gm_funkis_night`, parado **dentro de la casa**, el mensaje de
> vacío ahora imprime el conteo global — si dice «0 en todo el mapa» con 43 medidas en el BSP, el
> defecto era el método de búsqueda y queda probado en una corrida.
>
> **Lo que quedó DISEÑADO Y SIN ESCRIBIR (§21.9.8), con lo ya medido:** la **radio** —los 10 `.ogg`
> están en disco y ninguna línea los cita, pero duran **19 a 160 s** y `sound.Play` no se puede
> parar: necesita categoría propia con sujeto y `ent:StopSound`—; el **canto que te mira** —parar al
> fantasma hoy **le congela la cara**, porque el único escritor de la mirada se sale por debajo de
> 30 u/s—; y el **sexo del fantasma** —la mitad del sonido **ya existe y se llama `voice`**; lo que
> falta es la de los modelos, y `ENT.Models` es un campo **de clase**—.
>
> ⚠ **Aviso de método que toca a todo el repo:** se midió que **el Grep del harness truncó en silencio
> y sub-reportó el universo 14×** sobre este workspace. Toda afirmación del tipo *«el único sitio que
> hace X»* hecha con un Grep de árbol entero **está sin denominador** hasta rehacerla con
> `rg --no-ignore` acotado y el total impreso.
>
> ---
>
> **LO ANTERIOR (2026-08-09): LOS EVENTOS PARANORMALES ESTÁN ESCRITOS Y NO CORRIERON. Diseño §21.**
> Es un bloque **paralelo** al del hijo/ausencia — lo escribió otra sesión, sobre archivos nuevos, y
> no toca `server_cloak.lua` ni la planilla de la r23b.
>
> **Qué hay:** `server_events.lua` (el motor, último include de `server.lua`) y `ghost_flags.lua`
> (los rasgos de **25 de los 30 tipos**, en un archivo aparte porque `gen_types.py` **pisa
> `ghost_types.lua` entero**). **Ocho categorías** — `throw`, `knock`, `creak`, `door`, `light`,
> `sound`, `prop`, `furniture` — con **una convar por categoría** (`0` control · `1` el rasgo del
> tipo decide · `2` forzado) y **una tabla de pesos** en lugar de la cascada de nueve `if` sin
> `elseif` de gmpa.
>
> **La tesis, y es la diferencia entera con `[gm] paranormal events`: el radio cuelga del FANTASMA,
> no de un jugador al azar.** Eso convierte la actividad en un instrumento de localización — y trae
> una consecuencia que hay que aceptar de frente: **si el fantasma está lejos, no pasa nada, y eso es
> correcto.** La fila 08 de la planilla es la que lo mide.
>
> **Dónde se enganchó, y por qué NO es un `Think`:** `MyClassTask.Think` es de las puertas,
> `ENT:AdditionalThink` es de los atascos (y un archivo nuevo que lo declare **no encadena: BORRA**),
> y **ningún `Think` de tarea corre mientras un jugador maneja al bot** — el motor se apagaría entero
> sin un error. Va en **un `timer.Create` de servidor a 1 Hz**. Lo que se pierde es aparecer en la
> lista de tareas de `ghost_where`; se compensa imprimiendo **siempre** el contador de vueltas del
> scheduler, porque *una guarda que sólo habla cuando falla no puede acreditar que corrió*.
>
> ⚠⚠ **LA REVISIÓN ADVERSARIAL ENCONTRÓ QUINCE DEFECTOS EN CÓDIGO RECIÉN ESCRITO, Y ESTÁN
> ARREGLADOS.** Los cuatro que dejan regla, en el CHANGELOG y en §21.7. El peor para este documento:
> **`server.lua:3466-3468` afirmaba que la guarda de `server_cloak.lua` comprueba TRES claves de
> `MyClassTask` — y son DOS.** El archivo nuevo **copió la lista del comentario en vez de medir** y
> quedó gritando `ErrorNoHalt` en todos los arranques por una clave que nunca existió. *Un comentario
> mentiroso se propaga al lector que lo cita.* Los dos comentarios están corregidos; el censo real
> son tres asignaciones en todo el addon (`= {}`, `.Think`, `.ModifyMovementSpeed`).
>
> ⚠⚠ **CORRIÓ EN GMOD Y NO CARGÓ — ARREGLADO, PERO LO IMPORTANTE ES POR QUÉ (r24b, commit `95049c5`).**
> `ghost_flags.lua:749` tenía un **salto de línea CRUDO dentro de un string corto** (un `\n` que
> atravesó dos capas de escape: shell → Python → Lua). El archivo **entero** no cargaba:
> `rasgos de evento 0 de 30 filas con events`.
>
> **Y el verificador de sintaxis había dicho OK.** Esa acreditación era falsa y está medida:
> `luaparser` **acepta** un salto crudo dentro de un string corto y GMod lo rechaza. El taller ya
> sabía que da falsos **rojos** (rechaza `continue`); lo que no estaba medido es que da un falso
> **VERDE**. *Un falso rojo se descubre la primera vez que se usa; un falso verde se descubre en el
> juego, y mientras tanto ACREDITA.* Entra **`dev/luacheck_gmod.py`** — dos instrumentos, con **sus
> dos controles versionados** — y los **32 `.lua` del addon pasan**. Catálogo nº 42.
>
> **Lo que la corrida SÍ acreditó:** el `NEUTRO` de emergencia del motor (que salió de la revisión
> adversarial, justamente por si este archivo no carga) **mantuvo los eventos andando** con los
> rasgos caídos — sonaron teléfono, crujido, golpes y mueble. Sin él, un error de Lua por segundo.
> Y los tres instrumentos nombraron la causa: la ficha del fantasma, la guarda del motor y el
> cargador. `vueltas 364 del scheduler` hizo lo que existe para hacer.
>
> **LO QUE FALTA, Y ES LO PRIMERO DEL CHAT SIGUIENTE:** con la fusión caída **los 30 tipos se
> comportaron como el neutro** (el Shade de la corrida: `rate x1.00 count 1 burst 1`), así que **la
> fila 06 de la planilla —Poltergeist contra Shade, el corazón del pedido— todavía NO se ejerció.**
> Al arrancar, mirar la línea del cargador:
> - `30 tipos ( 30 con rasgos de evento )` → la fusión corrió, la 06 tiene sentido.
> - `0 de 30` otra vez → mirar **cuál `ErrorNoHalt` salió arriba**: ahora hay **dos** causas con el
>   mismo síntoma, el archivo que no carga y **la guarda que se niega a fusionar** por un rasgo mal
>   formado. Simulado fuera del juego, `auditarNeutro` da **0 mal formados** — pero es una
>   simulación, no una corrida.
>
> **Lo verificado fuera del juego, y nada más que eso:** la sintaxis **con el verificador nuevo**
> (el viejo dio el falso verde de arriba) y que **las 152 rutas de sonido citadas existen en disco,
> 152 de 152**.
>
> **Lo siguiente:** `dev/checks/phantasmagoria-eventos-r1.html` — 11 filas, las **cuatro primeras por
> consola** (sin sorteo). La 06 es el corazón del pedido del autor: un Poltergeist y un Shade **no se
> comportan igual**. ⚠ El pie de la hoja anota tres trampas del instrumento *antes* de correrlo, y la
> primera es que **el disparo forzado corrompe la pasada** (`phantasmagoria_ghost_events reset` antes
> de cualquier fila que mida ritmo).
>
> ⚠ **Y una corrección al diseño que salió de este arco:** **`FlingNearbyPhysicsProps` de gmpa SÍ
> corre.** §11.2 decía «su **único** call site» habiendo leído uno de **tres**. Estuvo siete días en
> el documento. *Declarar muerta una función es una afirmación sobre TODOS sus call sites.*
>
> ---
>
> ⭐ **LA r23b CORRIÓ (2026-08-09) — 3 pasa · 1 sin correr, y la roja no era del código.**
>
> - **01 PASA.** El censo imprimió `NINGUNO todavia` con sus tres líneas de ceguera. Es un resultado
>   legítimo: nadie parenteó nada en toda la sesión, dicho *con* el aviso de que un hijo de menos de
>   0,25 s puede no aparecer nunca.
> - **02 estaba VERDE por su propio criterio**, y se marcó roja porque **la fila no explicaba qué es
>   un hijo**. Defecto de la planilla, no del código: pedía juzgar si el vacío estaba bien declarado y
>   nunca dijo que un *hijo* es **otra entidad que un tercero pega al fantasma con `SetParent`**, que
>   se mueve con él y **se dibuja por su cuenta** — o sea que nuestro `ENT:Draw` no la alcanza y
>   quedaría flotando a la vista, delatándolo. *Una fila que usa un término del código sin traducirlo
>   mide la jerga, no el mecanismo.* Ya está escrito en la hoja.
> - **04 PASA otra vez, y el autor pidió que lo revisara alguien.** En esos datos: **`#1332` con las
>   series `s29`, `s36` y `s39`** — tres fantasmas distintos bajo el mismo `EntIndex` — y `#1323`
>   desde `s10` hasta `s38`. Ninguna línea con `s?`.
>
> ⚠⚠ **Y HAY UN DATO QUE NINGUNA FILA MARCÓ: la bitácora se llenó de spawns.** Entre t=421 y t=451
> hay **28 líneas** `SE VE … absence 0`, una por segundo, series 5→37, alternando dos `EntIndex`: una
> **racha de spawns**, cada fantasma nuevo escribiendo su primer estado. De los 40 renglones de
> ventana, 28 se fueron en eso y el tramo que la corrida quería mirar quedó en 12.
>
> El síntoma es **idéntico** al que la fila 06 de la r22 vigila (*«la bitácora inundada»* = el
> reconciliador reescribiendo cada tick) y la causa es la contraria: spawnearon 33 fantasmas. Desde
> ahora la primera escritura de cada bot va rotulada `[ INICIAL: primer estado del spawn, no es una
> transición ]`, y el reporte dice **cuántas de las que se ven son spawns**, con un `!!` si pasan de
> la mitad. *Una ventana que se llena tiene que decir con qué se llenó, o el que lee cree que vio
> todo.*
>
> **Dos preguntas del autor, contestadas:** (a) `SetNoDraw` ya no rige **para el fantasma** —eso es la
> r22— pero el bucle de hijos lo sigue usando **sobre un hijo**, porque un hijo es de otro addon y no
> le podemos escribir su `Draw`; las dos cosas conviven a propósito. (b) El marcador que «se pega» al
> cruzar un **areaportal** es la limitación conocida del PVS, no una regresión: el cliente deja de
> recibir la entidad y el marcador se queda con la última posición — y **ahora eso se delata solo**,
> con el `!! POS CONGELADA` que entró en la r21.
>
> ---
>
> **LO ANTERIOR (2026-08-09): la r23 corrió y el veredicto real es 1 pasa · 3 SIN CORRER. La única
> que midió cerró con evidencia dura; las otras tres fueron una hoja mal pensada — mía.**
>
> **La 04 PASA, y hay que releerla porque el autor la dejó en *sin correr* pidiendo que la mirara
> alguien.** Con más de cien fantasmas spawneados, la bitácora trajo el par que la fila pedía:
> `#89/s103` (t=182,5) y `#89/s131` (t=198,3) · `#100/s114` y `#100/s142` · `#78/s1`, `s2`, `s3` …
> `s124`. **El `EntIndex` se recicla en segundos**, la serie desempata, y ninguna línea salió con
> `s?`. El defecto que hizo que la r22 se contradijera a sí misma queda cerrado.
>
> ⚠⚠ **Las otras tres NO son verdes: ninguna tuvo sujeto.** Las tres notas dicen
> `hijos 0 ahora · maximo visto 0 · tocados 0` — **no apareció un solo hijo en más de cien
> fantasmas**. La 01 pedía la línea del hijo con clase y modelo; la 02, un `nodraw SI` sobre ese hijo;
> la 03, la línea `[ re-aplicado: cambio la cantidad de hijos ]`. **No salió ninguna de las tres.**
> La hoja lo decía en la rama roja y en el pie — *«si no aparece ninguno, no es un verde: es Sin
> correr»* — y aun así se marcaron verdes. *Una advertencia que vive en la rama que nadie lee cuando
> algo sale bien no es una advertencia: el que corre puntúa desde la rama de PASA.*
>
> ⚠ **Y no fue mala suerte: la fila estaba mal pensada de dos maneras.** (a) Exigía **presenciar el
> instante** en que un tercero parentea algo — en la r22 pasó *una* vez, en un tramo con hunt, physgun
> y disparos, y pudo durar menos de un segundo. (b) Peor: el único lugar que miraba hijos era el
> reconciliador **cuando el fantasma tiene que estar invisible** — o sea que **la ventana abierta era
> la equivocada**, porque disparar y agarrar con el physgun pasa con el fantasma *visible*.
>
> **Lo que entró (r23b):** un **censo de hijos GLOBAL**, que sobrevive al instante *y al fantasma* —
> que son las dos cosas que le faltaron a la r22, donde cuando se fue a buscar quién era el hijo el
> bot que lo había tenido ya no existía y su contador se había ido con él. Se muestrea **siempre**
> (no sólo con el fantasma invisible), limitado a 4 veces por segundo, y `phantasmagoria_ghost_vis` lo
> imprime aunque no quede ningún fantasma vivo. ⚠ **Declara su propia ceguera**: un hijo que viva menos
> de 0,25 s puede no aparecer nunca, así que un censo vacío se imprime *con esa advertencia al lado* —
> *un cero tiene que decir de qué es cero*. Y el `reset` **no** lo borra (`resetcenso` para eso).
>
> ⚠ Un detalle del camino: el censo quedó escrito **antes** de `quien()` y `anotar()`, o sea que los
> habría tomado como globales `nil` — un error que sólo hubiera aparecido el día que apareciera un
> hijo. Es la trampa de siempre (*una guarda que sólo corre en el caso raro es código sin estrenar*),
> agarrada leyendo el orden de declaración y no corriéndolo.
>
> **Lo siguiente:** `dev/checks/phantasmagoria-hijo-r23b.html`. Se juega normal y **se corre el
> comando al final**, no durante.
>
> ---
>
> **LO ANTERIOR (2026-08-09): la r22 CORRIÓ — 8 de 8. LA AUSENCIA (§20 ①) QUEDA CERRADA EN JUEGO.**
>
> El fantasma no se ve **y el marcador lo sigue**, que es lo que la r20 no podía dar:
> `saltos del Draw 4493` y subiendo · `NW INVISIBLE · GetNoDraw false · IsEffectActive false ·
> IsDormant no` · `pos EN EL CLIENTE … 0.1 s desde el último cambio · 2457 movimientos vistos` ·
> `ESCRITORES AJENOS 0` · la bitácora con una línea por transición real. La técnica de HIM anduvo, y
> el `Draw` del cliente es ahora el dueño del render.
>
> ⚠⚠ **Y DOS DE ESOS OCHO VERDES TRAEN UN HALLAZGO ADENTRO. Los dos están en las notas, no en los
> veredictos.**
>
> **① La alarma que se escribió en la r22 disparó en su primera corrida:**
> `!! HIJO TOCADO con la tecnica vieja ( SetNoDraw ): base_gmodentity`, con `( 1 hijos )`. La r20
> había dado `hijos máximo visto 0` y §20.2 lo tomó como confirmación de que el bot no lleva nada
> parenteado: **ese 0 era una ausencia no medida** — decía *«en esta corrida no pasó»* y se leyó como
> *«no puede pasar»*. Quedan tres preguntas sin contestar: **quién** es ese hijo (`base_gmodentity` es
> la clase base genérica y no identifica a nadie), si **`SetNoDraw` lo esconde de verdad** (sobre un
> hijo no cae en la misma rama de transmisión, y es lo único que tenemos: es otra entidad, de otro
> addon, y no le podemos escribir su `Draw`), y qué pasa con uno que nace **con el fantasma ya
> invisible**.
>
> ⭐ **Ese tercer caso era un agujero abierto y ya está tapado, sin correrlo:** el reconciliador es
> idempotente, así que un hijo nacido durante la invisibilidad **no se ocultaba nunca** — un objeto
> dibujado colgando de un fantasma que no se ve, o sea un delator. Entró un tercer motivo de
> re-aplicación, rotulado en la bitácora como `[ re-aplicado: cambio la cantidad de hijos ]` para que
> no se lea como una transición.
>
> **② La bitácora se contradijo sola dentro de una misma pantalla.** El reporte de un fantasma con
> `serie 4` y **30 ticks de vida** decía `hijos máximo visto 0 · tocados 0` mientras la bitácora, dos
> líneas más abajo, mostraba un `!! HIJO TOCADO` para `#1310` y transiciones repartidas en cien
> segundos. Las dos cosas eran ciertas: **el `EntIndex` se recicla**, y ese log tenía por lo menos dos
> fantasmas escribiendo bajo el mismo número. Ya se había visto sin entenderlo — dos `spawn #1327`
> seguidos, series 10 y 11. Cada línea lleva ahora `#idx/sN`. *Un identificador que el engine reusa no
> puede ser la clave de un registro que sobrevive al sujeto.*
>
> **La barra de vida de la fila 05 tiene dueño y perilla:** es el elemento `npcid` de DGL4
> (`holohud2/elements/npcid.lua`), un elemento de HUD del **cliente** — no una entidad, así que **no
> tiene nada que ver con el `base_gmodentity`**. Se apaga en la config de HOLOHUD2. ⚠ Pero es una
> perilla **de otro addon y por jugador**: sirve para correr las filas, no como garantía del diseño.
>
> **Lo siguiente:** `dev/checks/phantasmagoria-hijo-r23.html` (4 filas, hoja de acecho — su *«sin
> correr»* vale tanto como un verde). Y **el parpadeo ② quedó destrabado** por la r22: con el render
> decidiéndose en el cliente, lo que viaja es el NW var y no un dibujo, así que networkear *el
> horario* vuelve a estar disponible.
>
> ---
>
> **LO ANTERIOR (2026-08-09): DIAGNÓSTICO CERRADO POR EL AUTOR — `SetNoDraw` no sirve, y la ausencia
> pasa a hacerse EN EL CLIENTE, con la técnica de HIM. Planilla `phantasmagoria-draw-r22` (8 filas).**
>
> **Lo que se cayó:** `EF_NODRAW` en el servidor manda la entidad a `FL_EDICT_DONTSEND` — el cliente
> deja de **recibirla** y se queda con una copia congelada. Los tres síntomas de la r20 eran **uno
> solo**: el fantasma no se veía (bien), el marcador tampoco (mal), y el physgun lo agarraba en la
> posición original (el mismo dato con un testigo que no escribimos nosotros).
>
> **La salida estaba escrita en `PHANTOM_Referencia.md` §6 desde antes de empezar el bloque:** *«la
> invisibilidad de HIM no es un material: `SetHidden` hace `SetNotSolid` + `DrawShadow(false)` +
> `FL_NOTARGET`, y el `Draw` del cliente literalmente no dibuja»*
> (`terminator_nextbot_homeless/client.lua:54`). **La entidad se sigue transmitiendo entera**, así que
> el cliente conserva la posición y el marcador puede seguirla.
>
> ⚠ **De HIM se porta la TÉCNICA y no el cableado.** Su `Draw` pregunta `self:IsSolid()`: su
> invisibilidad *es* su no-solidez — el mismo acoplamiento por el que §20.1 rechazó el cloak de la
> base, ahora del otro lado. Nuestro fantasma ausente **es sólido a propósito**, así que con esa señal
> no escondería a nadie. La señal nuestra es el **NW var**, la única lectura del cliente que la r20
> vio llegar bien. *Dos addons pueden necesitar el mismo dibujo y distintas razones para dibujarlo.*
>
> ⭐ **La acreditación cambia de lugar, y es la mitad que la r20 no tenía.** Ya no hay bandera que
> preguntar: el que decide no dibujar es el camino del render, así que es él el que se cuenta.
> `phantasmagoria_ghost_cl` imprime **`saltos del Draw`**, que sólo puede tocar la rama que se saltea
> el dibujado. *Un contador que sólo puede escribir el mecanismo prueba que el mecanismo corrió; una
> bandera sólo prueba que alguien la escribió.*
>
> ⚠⚠ **Lo que la técnica nueva cuesta, escrito antes de correrla (fila 05):** con `SetNoDraw` la
> entidad desaparecía del cliente y con ella **todo** lo que otros addons dibujen encima. Ahora está
> ahí, así que **un HUD de terceros puede delatar al fantasma invisible** — en las capturas de la r20
> hay una barra `Phantasmagoria Ghost 900|900` flotando sobre el bot, y `FL_NOTARGET` no la tapa (esa
> bandera es para los NPC). Si esa fila sale roja, **la salida no es volver a `SetNoDraw`**.
>
> ⚠ **Tres cosas cambiaron de sujeto sin cambiar de nombre, y ninguna se borró:**
> `ESCRITORES AJENOS` ya no cuenta un segundo escritor de `SetNoDraw` sino **cualquiera** que la
> escriba (nosotros ya no) — sigue teniendo que dar 0 y ahora significa *«volvió el defecto de la
> r20»*. El reconciliador compara contra el NW var y no contra la bandera: dejarlo como estaba habría
> hecho **66 llamadas por segundo** a la primitiva, sin un solo error de Lua. Y la guarda del cadáver,
> que en la r20 **midió** que `BecomeRagdoll` hereda la bandera, pasa a ser una **predicción falsable**
> — ahora tiene que dejar de hablar. *Cuando se cambia el mecanismo hay que preguntarse contra qué
> estaba comparando el que lo vigilaba.*
>
> ⚠ Y queda una trampa con fecha, escrita en su lugar: el bucle sobre los hijos sigue usando
> `SetNoDraw` porque un hijo es **otra entidad** y no pasa por nuestro `Draw`. `hijosMax` dio **0** en
> la r20, así que hoy no corre nunca; si alguna vez imprime `!! HIJO TOCADO`, ese bucle deja de ser
> póliza y hay que darle a cada hijo su propio no-dibujado.
>
> ⭐ **Y el parpadeo ② se destraba de rebote:** la objeción de §20.3 era que un pulso de 0,08 s cabe en
> un solo snapshot. Con el render en el cliente lo que viaja es el NW var y no un dibujo, y la salida
> escrita —networkear **el horario**— vuelve a estar disponible, porque la entidad se transmite.
>
> ---
>
> **LO ANTERIOR (2026-08-09): la r20 CORRIÓ — 7 pasa · 2 falla · 1 sin correr. LA AUSENCIA ANDA. Las
> dos rojas son del INSTRUMENTO, y las dos son la misma.**
>
> **La mecánica de §20 ① queda medida en juego y no se re-discute:** invisible en calma y visible en
> hunt (03), el control `absence 0` la apaga (04), el flag por NPC la apaga con la convar en 1 (08),
> `absence 2` la fuerza también cazando (09), el reconciliador corre (02), y `ESCRITORES AJENOS 0` ·
> `hijos máximo visto 0` (07) — o sea que **`SetNoDraw` sobre la entidad alcanza y el bucle sobre los
> hijos es póliza**. La 10 cerró con dato: **`BecomeRagdoll` SÍ hereda `EF_NODRAW`** y salió la línea
> que lo dice, así que esa guarda no era decorativa. La 06 quedó **sin correr** por lo mismo que
> falló todo lo demás: *«no lo puedo ver»*.
>
> ⚠⚠ **LO QUE SE CAYÓ ES UNA FRASE DEL DISEÑO, escrita como un hecho y nunca medida.** §20.3 decía de
> `SetNoDraw`: *«es networkeado, o sea que el cliente puede leer `GetNoDraw()` y decir el estado
> REAL»*. En juego, con el fantasma invisible y fuera de la pantalla, el cliente imprimió
> **`render: se dibuja · el server dice INVISIBLE`**. De esa frase colgaban **las dos mitades de
> §20.4**: el modo honesto nunca salteó a nadie y la línea de HUD contó `0 invisibles` con uno
> delante (fila 05, roja). *Una propiedad de la red que nadie midió sostenía el instrumento entero de
> un bloque.*
>
> ⚠ **Y LA FILA 01 NO FUE ROJA: contestó (b), que es una de sus dos salidas verdes.** `por clase 1 ·
> por campo 1` es, por el texto de esa misma fila, *«el cliente LO TIENE»*. Marcarla roja porque el
> marcador seguía sin aparecer es **puntuar la fila por el síntoma que la trajo y no por su
> criterio** — y el criterio contestó bien: descartó la (a) que habría tumbado §20.4 de una.
>
> ⭐ **LA TERCERA CAUSA LA NOMBRA UNA PISTA SUELTA, escrita al margen de la fila 10:** *«cuando lo
> tomo el physgun va a su posición original, aunque lo tenga en frente»*. Con eso, los tres hechos
> que no cerraban cierran juntos: **la entidad está en el cliente pero congelada**. La hipótesis —y
> hay que medirla, no darla por buena— es que `EF_NODRAW` manda la entidad a `FL_EDICT_DONTSEND`: el
> cliente deja de **recibirla**, la copia queda con la posición vieja y con la bandera sin llegar
> (por eso `GetNoDraw` en `false`), y **el marcador sí dibuja: dibuja donde el fantasma estaba** — que
> desde la pantalla se lee igual que «no dibuja nada». El NW var llegó porque viaja por otro sistema,
> que es exactamente lo que el comentario de `phantom_SetVisible` decía que iba a servir para esto.
>
> **Lo que entró (r21, `client.lua` y NADA MÁS — `server_cloak.lua` no se abrió):**
>
> - **Cuatro lecturas en vez de una**: `NW` · `GetNoDraw()` · `IsEffectActive( EF_NODRAW )` ·
>   `IsDormant()`, impresas juntas. *El principio de §20.4 —preguntarle al destino y no a la fuente—
>   era correcto; el defecto fue elegir un solo campo del destino sin comprobar que contestara.*
> - **El que decide pasa a ser el NW var**, con el motivo escrito al lado: no es «la verdad del
>   render», es **la única lectura que se pudo acreditar**.
> - **Un muestreador de posición**, porque *un valor congelado no se ve en una sola lectura*: una
>   posición vieja y una actual son las dos un `Vector` plausible. Imprime `movimiento(s) vistos` y
>   `N s desde el último cambio`. ⚠ Su trampa está escrita antes de correrlo: **un fantasma quieto
>   también da congelado**, así que las filas piden el fantasma CAMINANDO y la 02 es el control.
> - **El marcador declara su propia mentira**: si la posición está congelada, la etiqueta 3D dice
>   `!! POS CONGELADA N s` y la línea de HUD suma un tercer número. *Un marcador dibujado en el lugar
>   equivocado se ve igual que uno correcto.*
>
> **Lo siguiente: correr `dev/checks/phantasmagoria-render-r21.html` (7 filas).** La 01 decide entre
> (a′) *el cliente no lo recibe* y (b) *sí lo recibe y el defecto es del marcador*.
> ⚠⚠ **Y si sale (a′), NO improvisar el reemplazo en la misma ronda**: `SetNoDraw` dejaría de servir
> para ① *y* para ②, y la salida que §20.3 tenía escrita para el parpadeo —networkear el horario—
> **cae con ella**, porque una entidad que no se transmite tampoco puede recibir nada por la entidad.
> Dato ya en disco para esa decisión: **`wraithcloaking.lua` nunca usa `SetNoDraw`** — se esconde con
> `SetMaterial` y `SetRenderMode`. §20.1 rechazó ese módulo por cómo acopla la solidez y eso sigue en
> pie: *la técnica de render y el módulo son dos decisiones distintas, y sólo una de las dos se había
> medido.*
>
> ⚠ **Numeración:** la sesión paralela usa **r19** para su propia ronda (el crash de
> `TranslateActivity`). La ausencia fue **r20** y esta es **r21**.


> **LO ANTERIOR (2026-08-09): la r18b CORRIÓ — 5 de 5. `speed.base` queda CERRADO en juego, la foto
> vieja está arreglada, y el arreglo destapó el SEGUNDO lector viejo sin que ninguna fila lo pidiera.**
>
> **El arco de Diseño 5.1 cierra con evidencia dura, y en los dos sentidos:**
>
> - **Deogen x0.235** → `multiplic. x0.235 · objetivo 66 · convertidas run 66 · deseada 66 · real 66`.
> - **Revenant x0.588** → `165` en las cinco cifras, **con la misma `serie 1`**: cambiar el tipo de un
>   fantasma vivo mueve la velocidad en el acto, que es el motivo entero de escribir en la puerta
>   única.
> - **El control**: `typespeed 0` con el andamio en 2 → `multiplic. x2.000 de convar ( ANDAMIO )`,
>   `campo VACIO · motivo: typespeed 0`, `objetivo 560`, y el autor: ***«salió volando»***.
> - **El sello nuevo funciona**: `[ foto de hace 0.00 s ]` en las cuatro filas, y el `!!` de foto
>   vencida no apareció nunca — que es el resultado (a) que la fila 01 pedía anotar.
>
> ⚠ **Y ARREGLAR LA FOTO MOVIÓ EL PROBLEMA UN ESLABÓN ABAJO.** Con `dbg` ya fresco, tres filas
> quedaron con `convertidas run 165` al lado de **`deseada 280`**. Esta vez **el número no está mal**:
> `deseada` sale del locomotion, que lo escribe `SetupSpeed` **en el tick**, así que en el mismo frame
> del cambio todavía tiene el valor anterior — y el bot de verdad va a la velocidad vieja un tick más.
>
> **El defecto era del CRITERIO, no del número.** Las filas 02 y 03 pedían que `convertidas` y
> `deseada` coincidieran *en la misma salida*, y **en el frame de un cambio eso es imposible**. Las
> tres pasaron porque el autor volvió a tipear el comando solo, sin que ninguna fila se lo pidiera —
> y esa segunda lectura da `165/165` y `66/66`. *En una cadena de valores derivados, cada eslabón
> tiene su propio instante: arreglar el caché de arriba deja al descubierto al lector de abajo.*
>
> Entró la línea que lo dice: si `deseada` no es ninguna de las tres `convertidas`, el reporte
> **nombra las dos causas y las separa por lo que pasa en la lectura siguiente** — (a) cambiaste algo
> en este frame, volvé a tipear el comando solo; (b) si sigue sin coincidir tipeado solo, el callback
> no llega al locomotion y *eso* sí es el defecto. Y cuando coincide lo dice también, con el nombre de
> la marcha.
>
> ⚠ **Y una fila pedía un dato que el comando no imprime.** La 04 exigía *«y el tipo sigue diciendo
> Revenant»* sobre una salida de `ghost_speed`, **que no imprime el tipo en ningún lado**. Con el
> campo vacío, la única pista era `top x1.765`… que también es la del Deogen. Ahora esa línea dice el
> nombre y la key. *Un check no puede pedir un dato que el comando no imprime, y una pista parecida no
> lo reemplaza.*
>
> ⚠ **LA 05 NO PASÓ: está SIN CORRER, y lo dice su propia salida.** `phantasmagoria_ghost_speed`
> imprimió **`no hay ningun fantasma vivo`** — el fantasma se spawneó *después*. La línea que la fila
> pedía (`campo VACIO … motivo: el fantasma no tiene tipo`) nunca salió. Lo que sí trajo el
> `ghost_where` de al lado —`tipo SIN TIPO` sin línea `!!` de residuo— es **la 08 de la r18 otra vez**,
> que ya estaba cerrada. Queda como residual de **un solo comando**: con un fantasma sin tipo vivo,
> `phantasmagoria_ghost_speed`.
>
> **Sigue abierto y sin diagnosticar:** con `absence 1` el marcador **no se dibuja ni en modo 1**. Ver
> el bloque de más abajo; `phantasmagoria_ghost_cl` ya imprime los dos conteos que lo deciden.
> → **Corrido en la r20:** los dos conteos dieron **1 y 1**, así que la entidad SÍ está en el cliente
> y la causa es otra. Ver el bloque de arriba.


> **LO ANTERIOR (2026-08-08): la r18 CORRIÓ — 8 de 8, y TRES de esos verdes imprimieron el número
> del tipo ANTERIOR. El mecanismo está bien; el instrumento mintió.**
>
> **Lo que quedó cerrado con evidencia limpia, y no se re-discute:** la **01** (`SON 11 DE 30` con la
> lista de los que discriminan), la **03** (el campo le ganó a un andamio puesto en 2 — lectura
> fresca), la **07** (`speed.base x0.235 APLICADO` y los rasgos de §5.1 marcados como no usados) y la
> **08** (`SIN TIPO` **sin** la línea `!!` de residuo). El enganche funciona.
>
> ⚠ **LAS TRES QUE NO MIDIERON, y las tres por el mismo defecto — mío, y del instrumento:**
>
> | | Pedía | Trajo |
> |---|---|---|
> | **02** | `x0.235` · `objetivo 66` | `x1.000` · `280`, con `campo x0.235 COINCIDEN` tres líneas arriba |
> | **04** | `x0.588` · `165` (Revenant) | `x0.235` · `66` — el Deogen anterior |
> | **05** | `x2.000 de convar` · `560` | **`x0.588 de campo phantom_SpeedMul ( tipo )` con `campo VACIO` DOS LÍNEAS ABAJO** |
>
> **La causa: `phantom_ApplyTypeSpeed` invalidaba el caché del FACTOR y el reporte no lee el factor.**
> Ponía `phantom_speedNext = 0` para que el próximo tick recalculara — y recalcula, pero lo que el
> comando imprime es `phantom_speedDbg`, **que sólo se reescribe en ese recalculo**. Y **dos
> concommands en la misma línea corren en el MISMO FRAME**, sin tick en el medio: `speed.base campo`
> (leído en vivo) salía nuevo y `multiplic. / objetivo / factor / convertidas / AHORA` salían viejos.
> *Invalidar un caché no actualiza lo que ya se calculó de él: marca que hay que recalcular, y el que
> imprime no es el que recalcula.*
>
> ⭐ **La 06 fue, sin que nadie lo pidiera, el control que lo prueba.** El comando se corrió **dos
> veces sobre el mismo estado**: encadenado dio `x1.000 / 280`, y solo, 16 s después, `x0.235 / 66`.
> *Dos lecturas del mismo estado que no coinciden acusan al instrumento* — y acá además dicen cuál de
> las dos es la buena. Esa segunda lectura es la que cierra la 06 en verde de verdad.
>
> ⭐ **Y las notas del autor concuerdan con los valores VERDADEROS y no con los impresos.** *«Vi que
> se puso más rápido»* en la 04 y *«va más rápido aún»* en la 05: con el reporte diciendo 66 en las
> dos. Es evidencia independiente de que el mecanismo hacía lo correcto mientras el reporte decía
> otra cosa — y de que **la impresión del operador puede ser mejor instrumento que la consola cuando
> la consola tiene un caché adentro**.
>
> ⚠ **Y la 03 pasó por casualidad.** El andamio no pasa por `phantom_ApplyTypeSpeed`, así que tampoco
> refrescaba nada; salió bien porque entre ese comando y el anterior habían pasado 0,6 s y el tick ya
> había recalculado. *Una fila que pasa porque el operador tardó en tipear no midió nada.*
>
> **Tres arreglos, y el tercero es el que faltaba:** `phantom_ApplyTypeSpeed` **recalcula en el acto**
> —sólo si ya había foto, porque `phantom_speedDbg == nil` es la única prueba de que el callback nunca
> corrió—; `phantasmagoria_ghost_speedmul` ganó su propio callback; y **la foto lleva ahora sello de
> tiempo y se compara contra el estado en vivo**, con un `!!` que dice *«esta foto ya no vale»* y qué
> valdría ahora. *El reporte ya comparaba el campo contra la tabla y esa comparación funcionó — nadie
> estaba comparando el campo contra el multiplicador impreso tres líneas arriba.*
>
> Planilla `dev/checks/phantasmagoria-speedbase-r18b.html`, **5 filas, sin correr**: el detector nuevo
> primero, las tres re-corridas, y la mitad de la 08 que se cerró con `ghost_where` en vez de con
> `ghost_speed`.
>
> ⚠ **REPORTADO EN JUEGO Y SIN DIAGNOSTICAR: con `absence 1` el marcador NO SE DIBUJA NI EN MODO 1.**
> El modo 1 es el que delata a propósito, así que esto no es el modo honesto funcionando. Hay dos
> causas y **desde la pantalla se ven idénticas**: (a) el cliente **no tiene la entidad** —o sea que
> `EF_NODRAW` se la lleva puesta del lado cliente, y entonces **ningún marcador clientside puede
> dibujar un fantasma invisible**: cae §20.4 entero y hay que networkear la posición aparte—; o (b)
> el cliente la tiene y el marcador la saltea, que sería defecto nuestro. **`phantasmagoria_ghost_cl`
> ahora imprime los DOS conteos** —por clase (lo que usa el marcador) y por campo (lo que usa el
> comando)— y una sola corrida decide. La r18 corrió con `absence 0`, así que **no está contaminada**
> por esto.


> **LO ANTERIOR (2026-08-08): `speed.base` ENGANCHADO y la INVISIBILIDAD arrancada. Dos bloques
> ESCRITOS, los dos SIN correr, con una planilla cada uno.**
>
> **① `speed.base` (Diseño 5.1) — es una línea y por eso mismo lleva planilla propia: SÍ cambia
> comportamiento.** `phantom_SetType` escribe ahora `phantom_SpeedMul` con el `speed.base` del tipo, y
> ese campo gana sobre la convar andamio. El `( NO aplicado todavia )` de `TypeLines` dejó de ser
> cierto y se actualizó **en la misma edición** que el enganche, que era lo que su propio comentario
> pedía.
>
> - **Va en `phantom_SetType`, la PUERTA ÚNICA, y no en el spawn.** `phantasmagoria_ghost_type <key>`
>   cambia el tipo de un fantasma **vivo**: colgado del spawn, forzar un tipo en caliente dejaría el
>   multiplicador del tipo VIEJO con el reporte diciendo `campo phantom_SpeedMul ( tipo )` — **la
>   fuente correcta con el valor equivocado**, que es el peor modo de falla posible.
> - **Y BORRA**, que es la mitad que se olvida. Un fantasma que pierde el tipo vuelve al andamio, y si
>   quedara residuo el reporte diría `( tipo )` sobre un `SIN TIPO`. Hay una línea `!!` que lo caza.
> - ⚠ **El A/B necesitaba una perilla que no existía, y el motivo es del propio enganche:** desde que
>   el campo se escribe, **la convar andamio ya no se puede mover**. Entró
>   `phantasmagoria_ghost_typespeed` (1, `0` = control). **No es `typeassign 0`**: ese apaga el tipo
>   entero —threshold, ficha, networkeo— y un rojo ahí tendría cuatro causas. Alcanza a los fantasmas
>   **vivos** por callback, y lo dice: *una perilla que no llega a los sujetos que ya existen es una
>   perilla que el operador cree que movió.*
> - ⚠ **Un check que pruebe un Spirit NO PUEDE FALLAR**, y el comando ahora lo cuenta solo:
>   **19 de los 30 tipos traen `speed.base` exactamente 1.000**, que es el default de la convar. Los
>   sujetos salen de los **11 que discriminan** — la última línea de `phantasmagoria_ghost_type lista`
>   los lista. Los elegidos: **Deogen 0.235 · Revenant 0.588**.
> - `speed.top`, `isRange`, `alt` y `losSpeedUp` **no** se toman (13 de los 30 traen segunda
>   velocidad): se imprimen marcados como no usados, igual que los 12 rangos de threshold.
>
> Planilla `dev/checks/phantasmagoria-speedbase-r18.html`, **8 filas, sin correr**.
>
> ---
>
> **② LA INVISIBILIDAD — diseño primero (Diseño §20, nuevo) y después la tajada ①.**
>
> ⚠ **Y la decisión de diseño REVIRTIÓ la recomendación de `PHANTOM_Referencia.md` §11.2, que decía
> «usar `ENT.IsWraith = true`». Queda APAGADO, y no por los cooldowns.** Medido sobre las 202 líneas
> de `wraithcloaking.lua`:
>
> - **El reloj que parecía el bloqueante tiene UN SOLO LECTOR** (`:128`, en la misma función que lo
>   escribe; grep sobre los 71 archivos + HIM: cero consumidores más). Pisarlo sería seguro. *La duda
>   que el plan dejaba abierta queda cerrada, y la respuesta es que no era el problema.*
> - **Lo que sí bloquea es que el módulo ACOPLA EL INVISIBLE A LA NO-SOLIDEZ, en dos lugares
>   distintos y ninguno documentado:** su material de verdad se difiere a un timer que arranca con
>   `if self:IsSolid() then return end` (`:99`) —o sea que **un bot sólido y «cloakeado» queda
>   permanentemente a medio ver, sin error**—, y su `unhide` escribe `SetSolidMask` y
>   `SetCollisionGroup` **sin consultar `NotSolidWhenCloaked`** (`:172-173`), mientras el `hide` sí lo
>   consulta (`:131`). **Apagar la bandera no apaga la escritura.**
> - Y eso **pelea contra `server_doors.lua`**, que es el dueño único de la solidez del fantasma y
>   tiene un vigilante que llama imposible a lo que esto produciría. *Dos escritores de la misma
>   máscara sin árbitro: gana el último, en silencio.*
>
> **La decisión: `ENT:phantom_SetVisible()`, propia, que cambia SÓLO el render y no toca la solidez
> nunca.** No son 202 líneas reimplementadas: lo que queríamos del módulo eran cinco cosas de una
> línea cada una. ⚠ **El costo, escrito para que no sorprenda: el fantasma ausente SIGUE SIENDO
> SÓLIDO** — se lo puede chocar sin verlo. Es una diferencia deliberada con Phasmophobia a cambio del
> dueño único.
>
> ⚠ **Y el reconciliador NO va en `MyClassTask`, que era lo obvio.** `BehaveUpdatePriority` y `Think`
> viven los dos dentro del coroutine de prioridad (`behaviouroverrides.lua:694-695`), que **no corre
> mientras un jugador maneja al bot** — el propio autor de la base lo dice en la línea de al lado del
> cloak. La primera rama de la política es justamente *«manejado por un jugador se ve siempre»*, así
> que ahí no se habría aplicado nunca y el síntoma sería **un bot invisible imposible de pilotear, sin
> un solo error**. Va en `ENT:BehaveUpdate`, y su prueba de vida es un contador de ticks y no un
> nombre en una lista — *m_TaskList dice que existe, un contador dice que corrió.*
>
> ⭐ **EL MARCADOR DE DEBUG PASÓ A CORROMPER LO QUE MIDE, y ahora tiene tres valores.**
> `phantasmagoria_debug_ghost` dibuja con `IgnoreZ`: **es lo único que te dice dónde está algo que el
> diseño quiere invisible**. El `2` (honesto) no dibuja al fantasma invisible — y como *«no lo veo»* y
> *«no lo dibujé»* se ven igual, en ese modo hay **una línea de HUD que sigue contando los que
> ocultó**. Entra en una captura, que es lo que una pantalla vacía no hace. El cliente además imprime
> el estado leyendo `GetNoDraw()` —**el destino**— al lado de lo que el servidor *cree*, así que una
> divergencia se ve en vez de deducirse.
>
> ⭐ **`blinkRate` NO SE ESCRIBE: se escriben DOS DURACIONES.** La fuente A dice del Oni *«blinks more
> frequently… making them more visible»* y la B dice *«parpadea muy poco»*: las dos concluyen **más
> visible**, por mecanismos opuestos, porque en Phasmophobia *blink* es el momento en que **aparece**.
> Con el sentido invertido **el Oni sale invisible y el Phantom visible, y las dos fuentes seguirían
> pareciendo correctas**. La decisión no es fijar el sentido por escrito sino **elegir un nombre que
> no se pueda invertir**: `hunt.blink = { visible = {…}, invisible = {…} }`, en segundos. *Una
> duración trae su dirección adentro; una frecuencia no.*
>
> ⚠ **Y el dato va a mano, en `lua/phantasmagoria/ghost_blink.lua`, porque no hay otra opción:
> `dev/g2.json` NO ESTÁ EN EL REPO.** El encabezado de `ghost_types.lua` manda «regenerar con
> `dev/gen_types.py`» y esa instrucción es hoy un callejón sin salida; además el esquema del generador
> (`min_speed`/`max_speed`/`alt_speed`/`hunt_sanity` + notas del wiki) **no tiene ningún campo de
> parpadeo**. Ni con el JSON de vuelta saldría el número.
>
> ⚠ **El «Yokai rápido» de §5.2 queda marcado como INVENTADO, y la ausencia está verificada:**
> `gen_types.py:104` trunca las notas en `notes[:8]`, y contadas las 30 fichas **sólo banshee y shade
> llegan al tope**. El Yokai trae 5, así que su silencio sobre el parpadeo es real y no un recorte.
> *Una ausencia sólo vale como dato cuando se sabe que el generador no la produjo.*
>
> Planilla `dev/checks/phantasmagoria-ausencia-r20.html`, **10 filas, sin correr** — la 01 es el bloqueante del marcador y manda sobre otras dos. La ② (el parpadeo)
> está **diseñada y sin escribir** a propósito: sus números vienen de la fuente B sin verificar, y su
> riesgo real es la **red** y no el render — con un pulso visible de 0,08 s y snapshots a ~20-30 Hz el
> cliente se lo puede tragar (Diseño §20.3).


> **LO ANTERIOR (2026-08-08): la r15b CORRIÓ — 6 de 6. La TAJADA A queda CERRADA en juego, y las
> masas de los 66 propios también.**
>
> **Lo que cerró con evidencia dura:** `84 modelos ( 66 propios )` en la línea del cargador —el
> **84 = 18 + 66** prueba que la fusión corrió **y** que el orden de carga es el bueno—; el serial
> nuevo hizo decidible la lectura que la r15 no pudo (`#397 serie 1` Myling contra `#156 serie 2`
> SIN TIPO); y **cinco masas corregidas en juego**, `1.50 kg` en las cinco, o sea que **el censo de
> los 66 estaba bien medido**: `crucifix_i/ii/iii → 0.60`, `tripod_i → 2.00`, `salt_i → 0.30`. El
> crucifijo verificado además **por fuera del log**, con el weight tool.
>
> ⭐ **Corrección del autor, ya aplicada: los crucifijos II y III son metálicos.** La tabla los tenía
> en `item`. Es exactamente para lo que salió como propuesta. **El tier I no se tocó** —el autor no se
> pronunció sobre él— y queda anotado como pregunta abierta.
>
> ⚠ **Y tres de los seis verdes tienen letra chica. Ninguno cambia el veredicto; los tres dicen algo
> del instrumento:**
>
> - **La 01 pedía DOS líneas y la nota trae UNA, la del cliente.** Por el criterio literal era rojo.
>   **No lo es, y lo prueban las filas vecinas:** el comando de tipos corre en el **servidor** y dijo
>   `30 tipos cargados`; el fantasma recibió tipo al spawnear (servidor); y el hook de masas —que es
>   `PlayerSpawnedProp`, **servidor**— imprimió cinco correcciones. *El veredicto es correcto y la
>   fila no lo probó: lo probaron sus vecinas.*
> - ⭐ **La 03 volvió a pegar la consola del servidor, y esta vez la culpa es MÍA: la fila pedía algo
>   imposible.** Pedía *pegar* lo que dice un marcador 3D, y **un marcador no produce texto** — el
>   único registro posible era la palabra del operador o una captura. Tres rondas seguidas terminaron
>   pegando el servidor por eso. → Entró **`phantasmagoria_ghost_cl`**, un comando **del realm
>   cliente** que imprime la key networkeada, si resuelve a ficha, y **el texto exacto que dibuja el
>   marcador** — llamando a la misma función que dibuja, no a una copia. *Un criterio visual necesita
>   un instrumento que produzca texto, o la fila nunca va a tener más evidencia que la vista de
>   alguien.*
> - **La 06 pasó midiendo la rama de al lado.** Salió `no la escribimos y no cambia hace 1.2 s
>   ( parado )` — que es honesto y correcto—, pero **la rama corregida pide `cambio hace ≤ 1 s`** y
>   con 1,2 s no se pasa por ahí. La rama nueva **no se ejerció**: para provocarla hay que leer dentro
>   del primer segundo después de que el bot frene, o sea una ventana más corta que el trámite de
>   tipear. Va con muestreador, no con una fila más.
>
> **De la sesión paralela, confirmado en juego por el autor:** el fantasma **ya no levanta armas**
> (`ENT:CanPickupWeapon` en false — la causa de la pose T de la r17), y `ghost_girl.mdl` es el cuerpo.
> *«Ahora el ghost no toma armas como un terminator.»* Y se está trabajando un modelo rippeado que
> **por ahora corre de costado**.
>
> **Residual menor, sin ronda propia:** la 02 volvió a traer **un solo fantasma** en la salida (el
> primero se borró antes de spawnear el segundo), así que *«al vivo no se le borra el tipo»* sigue sin
> medirse. Ahora es lectura de tres líneas —la convar sólo se lee en `phantom_ResolveType`, que corre
> en el spawn y en el comando— y el serial ya quitó la ambigüedad que hacía peligrosa la lectura.

> **LO ANTERIOR (2026-08-08): la r15 CORRIÓ — 8 de 9. El MECANISMO del tipo queda CERRADO, y tres de
> esos verdes no midieron lo que decían.**
>
> **Lo que quedó cerrado con evidencia completa, y no se re-discute:** el tipo se asigna al spawnear
> (`tipo Obake ( obake ) threshold 50 % speed.base x1.000 ( NO aplicado todavia )`); el sorteo cubre
> **30 de 30** en dos corridas con números distintos (`obambo x19`/`yokai x3`, después
> `hantu x16`/`mare x5` — sobre 300 tiros en 30 categorías eso **no es sesgo**: la σ es ~3,1 y hay 30
> máximos compitiendo); el botón dio **las dos negativas exactas**; el override alcanzó a **7
> fantasmas nuevos**, todos Demon con `threshold 70`; y los 30 thresholds son los del juego
> (Demon 70 · Shade 35 · Deogen 40 · Thaye 75 · Obambo 65), con los 12 rangos marcados como no usados.
> **La tajada C ya tiene contra qué comparar.**
>
> ⚠ **Las tres que no alcanzan, y las tres por el mismo motivo: la evidencia pegada no es la que el
> criterio pedía.**
>
> | | Pedía | Trajo |
> |---|---|---|
> | **01** | **dos** líneas de conteo, `server` y `cliente` | *«sí vi ese dato»* — ni el texto ni cuántas |
> | **04** | **dos** fantasmas en la misma salida, el viejo con su tipo | uno solo |
> | **08** | lo que dice **el marcador del cliente** | la salida del **servidor** |
>
> ⚠ **Y la 01 y la 08 son, juntas, la única prueba de que el realm CLIENTE funciona.** Ninguna de las
> dos trae un dato del cliente. En este taller el cliente ya fue el realm donde algo estuvo apagado
> dos arranques sin un solo error de Lua.
>
> ⭐ **UN DEFECTO SALIÓ DE ADENTRO DE UNA FILA VERDE, y es de la familia que ya costó una ronda.** La
> 03 imprimió `quiere … ( la escribe LA BASE ( shootAt sobre el enemigo ) )` con **`enemigo ninguno`
> dos líneas más arriba, en la misma pantalla**, y el bot `quieto ( 0 u/s )`. Las dos mitades son
> falsas ahí: `shootAt` pide un enemigo válido y el facewalk se sale por debajo de 30 u/s — **en ese
> hueco no hay ningún escritor** y el valor quedó del último que corrió. *Una etiqueta que nombra a un
> escritor tiene que preguntar por la precondición de ESE escritor, aunque el dato esté impreso al
> lado.* Arreglado.
>
> ⭐ **Y un `EntIndex` no es una identidad: GMod los recicla.** La 04 leyó `#52 Obake` y después
> `#52 SIN TIPO` — *«perdió el tipo»* y *«otro fantasma heredó el número»* se ven **exactamente
> igual**. Entró `serie N · nacio hace N s` en la cabecera de los dos instrumentos.
>
> ⚠ **La 02 no estaba «sin correr»: estaba SIN SUJETO** — y la aclaración del autor abrió un bloque
> entero. Ver el punto **4** de «lo pendiente» abajo: los 66 modelos propios traen **todos**
> `mass 1.5` y `surfaceprop metal`.
>
> Planilla `dev/checks/phantasmagoria-tipo-r15b.html`, **6 filas, sin correr**.

> **LO ANTERIOR (2026-08-08): la CORDURA arrancó por la tajada A — el fantasma ya es uno de los 30.
> ESCRITA, SIN correr.**
>
> `server_type.lua`. El fantasma elige tipo al spawnear, lo guarda, lo networkea y lo publica en
> `phantasmagoria_ghost_where`, en la línea de spawn y en el marcador del cliente. Botón:
> `phantasmagoria_ghost_type`, con `lista`, `sorteo N`, `random` y `auto`.
>
> **Por qué el tipo va primero y no es un rodeo:** el gatillo de la tajada C no compara la cordura
> contra un número fijo, la compara contra `hunt.threshold`, que es un dato **del tipo** (Demon 70,
> Shade 35, Deogen 40). Sin tipo asignado, C no tiene contra qué comparar y B mediría una barra que
> no dispara nada.
>
> ⚠ **NO cambia ni un comportamiento, y es deliberado.** `speed.base` está en los 30 tipos y
> `server_speed.lua` ya sabe leer un campo (`phantom_SpeedMul`) que **gana** sobre su convar andamio
> — y este bloque **no lo escribe**. Engancharlo habría cambiado la velocidad de todos los fantasmas
> de golpe, sin A/B, en la misma ronda que estrena el mecanismo que la decide: *un rojo de velocidad
> ahí sería imposible de atribuir.* Es una línea, y va con §5 y su propia planilla.
>
> **Tres orígenes del tipo, en orden, y ninguno es silencioso:** el override de consola → el campo
> `ENT.PhantomType` de la clase (que es como §12.2 va a generar los 30 NPCs del spawnmenu) → el
> sorteo. **El motivo del que ganó viaja con el fantasma y se imprime al lado del tipo** — sin eso,
> «salió Oni» no distingue un sorteo de un override olvidado de la corrida anterior, y los overrides
> de este addon sobreviven al respawn a propósito (la lección de la ronda 3).
>
> **El botón se niega dos veces, y la segunda salió de la revisión antes de correr:** una key mal
> tipeada rebota sugiriendo (`twins` → `parecidos: the_twins`), y **forzar un tipo con
> `typeassign 0` también rebota**. Aceptarlo habría dejado la peor salida posible —`override -> oni`
> arriba y `SIN TIPO` en las fichas de abajo, **en la misma pantalla**—, que se lee como *«el
> override no funciona»*: la conclusión inversa a la verdadera.
>
> ⚠ **Y hay un modo de falla del sorteo que no tira error: `TypeOrder` y `Types` desincronizadas.**
> El archivo es **generado**, o sea que se regenera. Un tipo que esté en `Types` y no en `TypeOrder`
> **existe y no puede salir sorteado nunca** — 29 de 30, y se ve igual que un sorteo con suerte. Va
> una guarda al arrancar y la fila **05** lo mide con 300 tiros en seco (`distintos 30 de 30` ·
> `NUNCA salio ninguno`).
>
> Planilla `dev/checks/phantasmagoria-tipo-r15.html`, **9 filas, sin correr** — las **01 y 02** son
> las dos que arrastraba el cargador de ayer.

> **LO ANTERIOR (2026-08-08): `lua/phantasmagoria/` NO LO CARGABA NADIE. Cargador escrito, SIN pasada
> en juego.**
>
> Salió de una sola pregunta antes de empezar §19: *¿existe `PHANTASMAGORIA.Types` en runtime?*
> **No existía.** GMod auto-ejecuta un conjunto **fijo** de carpetas (`lua/autorun/`, `lua/entities/`,
> `lua/weapons/`, `lua/effects/`, `lua/vgui/`) y `lua/phantasmagoria/` no está en la lista. El grep de
> `include(`/`AddCSLuaFile` sobre **todo** el addon daba dos líneas, las dos de las armas.
>
> Apagados quedaban los **30 tipos** (o sea que §19 no se podía ni empezar: el disparo del hunt lee el
> `hunt.threshold` **del tipo**) y ⚠ **`prop_data.lua`, que no es dato sino comportamiento**: registra
> `PlayerSpawnedProp` para corregir la masa, y su propio comentario dice para qué — *«sin esto, un
> jugador que saque el crucifijo del Prop Pack desde el spawnmenu se lleva la tonelada»*. **Esa red de
> seguridad nunca corrió.**
>
> ⚠ **Y no dejó rastro porque el consumidor todavía no estaba escrito.** El grep de `ApplyPropData` /
> `PropData` / `Types` fuera de la carpeta da **cero usos**: una tabla que no existe sólo tira error
> cuando alguien la lee. **El defecto no tenía síntoma porque la función que lo hubiera mostrado era
> justo la que faltaba** — y el síntoma iba a aparecer el primer día de la cordura, disfrazado de *«la
> cordura no anda»*, a tres archivos de la causa.
>
> El cargador es `lua/autorun/phantasmagoria_data.lua`: **incluye y nada más**, los dos en los dos
> realms (el HUD de cordura de §19.3 es cliente). ⚠ **Su guarda NO puede detectar la falla que acaba de
> ocurrir** — si el archivo no corre, la guarda tampoco; detecta el otro modo (rename, `return`
> temprano, error a mitad) y dice **el número**, no un booleano.
>
> **Medido:** parsea, las dos rutas existen, **30** tipos, `PropData` en la 39, el hook en la 118.
> **Sin pasada en juego:** nadie vio el conteo en una consola de verdad ni volvió a pesar el crucifijo.
>
> ⭐ **Las dos filas ya están escritas —son la 01 y la 02 de `phantasmagoria-tipo-r15`— y al escribirlas
> aparecieron DOS defectos de instrumento que había que arreglar antes de poder correrlas:**
>
> - **La guarda hacía `return` en silencio cuando todo estaba bien.** O sea que la consola de un
>   servidor sano y la de uno donde este archivo **no corrió** se veían **exactamente igual** — y «no
>   corrió» es el único defecto que la guarda existe para no repetir. *Una guarda que sólo habla
>   cuando falla no puede acreditar que corrió: su silencio es el síntoma del defecto que vigila.*
>   Ahora dice el conteo siempre, **con el realm**, y la fila espera **dos** líneas: `server` y
>   `cliente`. Una sola es rojo, y además predice cuál va a ser el rojo de la fila del networkeo.
> - **La masa del crucifijo no tenía cómo medirse.** *«Se levanta»* es una impresión, y con la
>   tonelada puesta tampoco se distingue de estar trabado contra algo. El hook imprime ahora el par
>   `1000.00 kg -> 0.60 kg`, que además separa los tres modos: **sin línea** = el hook no corrió;
>   `1000 -> 1000` = corrió y no corrigió; `0.60 -> 0.60` = sacaste el crucifijo del **otro** pack y
>   la fila midió otro modelo.

> **LO ANTERIOR (2026-08-08): la r14 CORRIÓ — 5 de 5. El ALCANCE y la MIRADA quedan los dos CERRADOS
> en juego.**
>
> **El A/B del `sightdist`, con `ve … SI` en las dos mitades** (el fantasma te ve igual y no le
> importás): con **3000** → `ShouldBeEnemy NO`, `mem NO`, `enemigo ninguno`, `FUERA DE ALCANCE`; con
> **0** → `ShouldBeEnemy SI`, `mem SI, hace 0.0 s`, `enemigo Player [1]`, `la cadena entera funciona`.
>
> **La fila 04 acotó el umbral sin que la fila lo pidiera:** cuatro lecturas acercándose —
> **15.485 → 8.917 → 4.275 → 2.522 u** — con el volteo entre las dos últimas, o sea **atravesando el
> 3000**, y adquisición inmediata al cruzar (*«si pasé los 50 metros y me vio de inmediato»*). **El
> hunt de cerca quedó intacto y el corte es limpio.** Y la 05: a 4.819 u, `enemigo ninguno` + `mem NO`
> — **te suelta al alejarte**, que sale del mismo punto que lee `ForgetOldEnemies`.
>
> ⚠ **EL GATE TAPA UNA ENTRADA LATERAL, y salió de un tiro que el autor pegó entre dos filas.** Las
> cuatro lecturas siguientes tienen `vida 827/900` con `rel D_HT pri 1000` — eso es **`MakeFeud`**
> (`damageandhealth.lua:482` → `enemyoverrides.lua:1046`, *«hate players more than anything else»*),
> que reescribe la relación cuando te pegan. Pero **MakeFeud escribe la relación y el gate corta antes
> de que la relación se lea**: `ShouldBeEnemy NO` a 20.879 u con el daño encima. **Un fantasma baleado
> desde lejos ya no viene a buscarte.** *Un límite puesto delante de una cadena tapa también las
> entradas laterales, y las laterales son las que nadie recuerda.* Queda así a propósito —en
> Phasmophobia al fantasma no se le dispara— pero es una decisión, y el instrumento la dice cuando el
> fantasma tiene daño encima.
>
> **Lo que quedó sin medirse:** la 05 pedía **cuánto tardó en soltarte** y trae una sola lectura ya del
> otro lado. El mecanismo es determinístico (~0,5 s por barrido) así que el veredicto no cambia, pero
> el número no está. Y sigue abierto el residual de la r13b: `congelada 5 de 117` en calma contra un
> criterio de `0` (4 %), candidato el hueco del facewalk cuando el bot no está en el piso.

> **LO ANTERIOR (2026-08-08): la r13b CORRIÓ y el ARCO DE LA MIRADA ESTÁ CERRADO. El rojo era de
> diseño, no del mecanismo.**
>
> **El A/B quedó como par de verdad**, mismo régimen y una sola convar de diferencia:
>
> | | `facewalk 1` | `facewalk 0` (control) |
> |---|---:|---:|
> | `la escribio NOSOTROS` | **99**/100 | **0**/100 |
> | `vs marcha` media | **1,1°** | **90,6°** |
> | `giro` barrido · abanico | **670° · 151°** | **0° · 0°** |
> | `congelada` | **0**/98 | **44**/48 |
>
> **El instrumento dejó de contradecirse** (seis `ghost_where` seguidos caminando derecho, los seis
> `la escribimos NOSOTROS`, ninguno CONGELADA) y **el botón se negó cuando tenía que negarse**: pedir
> `calmasin` justo después de `hunt 0` dio *«el fantasma está en calma CON enemigo»* — la memoria no se
> vacía en el mismo frame. El operador esperó y repitió. *Ése es el lazo funcionando.*
>
> **La 06 de la r13 era LATENCIA, y ahora está medida:** `ve SI` → `mem SI, hace 0.0 s` → `enemigo
> Player [1]` a **31.253 u**. Y salió de dónde vienen esos segundos: `enemy_handler` arranca con
> `playerCheckIndex = 0` (`shared.lua:3115`) y Lua indexa desde 1, así que **el primer barrido de la
> rama de distancia infinita no mira a nadie** (`idx 0`, `idx 0`, `idx 1` en el log). Con esa rama
> corriendo *después* de `FindPriorityEnemy`: **hasta tres barridos, ~1,5 s.**
>
> ⚠ **EL ROJO: el fantasma te caza a 31.253 u — 542 m por la mira del rifle**, del otro lado de
> flatgrass, con `mirada vs jugador 0°` y `movement_stalkenemy`. **La cadena funcionaba perfecto; el
> defecto es que funciona demasiado lejos.** La base lo hace a propósito y con dos mecanismos:
> `ShouldBeEnemy` exime a los jugadores del tope de distancia *en su propio comentario*, y
> `enemy_handler` tiene la rama *cheap infinite view distance*. Correcto para un terminator; para un
> fantasma de Phasmophobia no, porque el hunt es adentro de una casa.
>
> **`phantasmagoria_ghost_sightdist` (3000, `0` = sin límite).** Va en `ShouldBeEnemy`, que es la
> puerta que consultan los cuatro caminos: un solo gate corta la adquisición **y** hace que te suelte
> al alejarte — esa segunda mitad nadie la pidió y por eso tiene fila propia. ⚠ **El número no es mío:**
> 3000 es `MaxSeeEnemyDistance`, el que la base ya aplica a todo lo demás.
>
> **Residual sin arreglar:** la guardia en calma dio `congelada 5 de 117` contra un criterio de `0`
> (4 %); el candidato es el hueco deliberado del facewalk cuando el bot no está en el piso.
>
> Planilla `dev/checks/phantasmagoria-alcance-r14.html`, **5 filas, sin correr**.

> **LO ANTERIOR (2026-08-08): la r13 CORRIÓ — 6 pasa, 1 falla, y TRES de esos verdes no lo son.**
>
> **La fila del ARREGLO no corrió**, y su propia salida lo decía: `regimen hunt CON enemigo`, cuando el
> defecto vivía en `hunt SIN enemigo`. Ahí manda la base y **`NOSOTROS 0` es lo correcto por diseño**,
> así que el veredicto salió con pinta de estar bien midiendo la fila de al lado. *Un botón que se
> niega a lo que puede pasar en el medio, y no a lo que ya estaba mal al empezar, deja pasar el error
> que de verdad ocurre.* → `ghost_look` toma ahora un segundo argumento
> (`huntsin`/`huntcon`/`calmasin`/`calmacon`) y **se niega a arrancar** si no es ése. La **01** se marcó
> verde con `hunt SI` + `enemigo Player [1]` pidiendo lo contrario, y la **07** con la nota cortada en
> el encabezado: **el veredicto de los 30 s nunca salió**.
>
> ⚠ **Y mi instrumento se contradijo en la misma corrida.** Dos muestras, mismo estado
> (`hunt SI · enemigo ninguno · facewalk 1`, 196 u/s derecho): una dijo `la escribimos NOSOTROS` y la
> otra `NADIE la mueve hace 1.6 s -- CONGELADA`, **las dos con `mirada vs marcha 0 grados` al lado**.
> `quieta` mide *que el valor no cambió* y yo lo llamaba *que nadie lo escribió* — un bot que camina
> derecho recibe **el mismo ángulo cada tick**. La rama estaba adelante de la que sí tenía marca
> directa. Reordenado, y el tercer balde dejó de llamarse `NADIE`.
>
> **CERRADO y no se repite:** el control con `facewalk 0` reprodujo el defecto exacto en el régimen
> correcto (`congelada 91/95`, `giro 0 · 0`); la guarda del enemigo dio `LA BASE 60 · NOSOTROS 0` con
> `vs jugador 5,2°`; y el separador mostró sus dos lados. **El arreglo tiene evidencia pero de otra
> fila:** la 06 lo pilló en `hunt SIN enemigo` con `facewalk 1` → `la escribimos NOSOTROS` y
> `mirada vs marcha 0`. Una muestra contra una ventana de 100.
>
> **La 06 (`ve SI` + `enemigo ninguno` a 26.014 u) NO se puede leer todavía.** Salió en el primer
> segundo después de un `ai_ignoreplayers → 0`, y la segunda toma **sí** adquirió a 20.796 u. Arriba de
> `MaxSeeEnemyDistance` (3000 u) la única rama es *cheap infinite view distance*, que mira **un jugador
> por pase** y corre **después** de `FindPriorityEnemy`: **~1 s, dos barridos**. `ghost_rel` imprime
> ahora `mem` (memoria + edad) y el próximo barrido, y el veredicto nombra cuál eslabón falla.
>
> Planilla `dev/checks/phantasmagoria-mirada-r13b.html`, **7 filas, sin correr**.

> **LO ANTERIOR (2026-08-07, después de la r12): la mirada clavada en hunt. ARREGLADA, SIN CORRER.**
> Reportado en juego: *«el stuck parece estar solucionado pero ahora el bot no me sigue cuando está
> cazando, y queda mirando a un sitio en particular»* — el yaw en `-87.7` en **dos lecturas tomadas a
> 1400 u de distancia una de la otra**, y *«cuando pasé de hunt 1 a 0 se giró correctamente»*.
>
> **No sale del bloque del encaje:** en esa corrida `escapedist` y `stuckbailoutsecs` estaban **los dos
> en 0**. Sale del facewalk (2026-08-06), que se apagaba con `if phantom_Hunting then return end`.
> **La premisa de esa guarda no es el hunt, es tener enemigo**, y el fantasma entra en hunt por el flag
> — no porque haya visto a nadie. En ese hueco no hay enemigo, la base se sale antes de
> `Term_LookAround` (sin arma ni puños, `shared.lua:3492-3506` corta los tres caminos, así que
> **para este bot el único escritor de la mirada es `shootAt` sobre el enemigo**) y esa guarda apagaba
> al único que quedaba. La guarda de verdad —`IsValid( GetEnemy )`— estaba escrita **en la línea de
> abajo** y era inalcanzable. *Una guarda cuya premisa es otra condición tiene que preguntar por esa
> condición, no por la que suele venir con ella.*
>
> ⚠ **El instrumento acreditó el defecto.** `lookLines` imprimía `( lo pide la base ( enemigo ) )`
> **deducido del flag**, y el reporte de la r12 lo mostró **doce veces al lado de `enemigo ninguno`, en
> la misma pantalla**. Ahora se **mide**: cuándo cambió el valor y cuándo lo escribimos nosotros.
>
> ⚠ **La otra mitad del reporte NO es este defecto.** `phantasmagoria_hunt 1` **abre la puerta**
> (`ShouldBeEnemy`), **no apunta el fantasma hacia vos**: sin línea de visión no hay enemigo, y sin
> enemigo el bot deambula (`movement_biginertia`, *«nothing better to do»*). La fila 8 de `hunt-r1`
> cerró en verde **a 3 m** y nadie la corrió nunca a distancia. Que el hunt salga a buscarte es
> **Diseño 4/19 (la cordura)**, no un arreglo de este archivo.
>
> **Botón nuevo, y se niega:** `phantasmagoria_ghost_look [seg]` aborta si hay más de un fantasma, si
> el régimen (`hunt/calma` × `con/sin enemigo`) cambia en el medio —y dice en qué segundo— y si el bot
> no caminó en ninguna muestra. `phantasmagoria_ghost_rel` ahora imprime `CanSeePosition`, `PosCanSee`,
> `ClearOrBreakable`, **qué lo tapa** y `Term_FOV` (180 → la mirada **no** lo ciega; con menos, las dos
> fallas serían una).
>
> Planilla `dev/checks/phantasmagoria-mirada-r13.html`, **7 filas, sin correr**. ⚠ La r12 dejó
> `escapedist` y `stuckbailoutsecs` en **0** y las dos son `FCVAR_ARCHIVE`: **reponerlas antes de
> correr nada**, o cualquier encaje va a parecer una regresión nueva.

> **LO ANTERIOR (2026-08-07): corrieron la 9 y la 10. El encaje está EXPLICADO ENTERO y el
> arreglo va por la mitad.**
>
> **La r9 midió que el rescate arranca y no rescata:** siete `RESCATE → CAMINAR` en 60 s, `quieto`
> subiendo monótono a 59,7 s, cinco `la caminata LLEGO` sobre la misma posición, y teleports de
> **83, 8 y 46 u**. Causa: `freedomPos` se elige por **distancia mínima** (`:3849`) sobre 1715
> navareas parcheadas y `:3676` da la caminata por terminada con `dist < 150` — *el destino nacía
> debajo del umbral con el que lo daban por cumplido.* **La r10 lo confirmó con números:** nacían a
> 71-133 u, todos bajo 150.
>
> **`phantasmagoria_ghost_escapedist` (300, `0` = control) arregló esa mitad:** los destinos van a
> ~300 u, el bot se mueve 152/155/185 u, y `llego` cayó de 7/7 a 1/6 — el éxito falso desapareció.
>
> ⚠ **Y ahí apareció el defecto de abajo, que mi predicción daba por resuelto:** con el destino sano
> a 306 u, **`SE MOVIO 0 u` en 10 s, cinco veces seguidas**. Encajado **no puede caminar**. La única
> rama que sacaría a un bot inmóvil es el teleport, y `:3868` lo veta mientras te ve.
> *no puede caminar + no puede teletransportarse = physgun.*
>
> **El bailout está escrito, y la r11 REFUTÓ su primer gatillo sin que ninguna fila lo pidiera:**
> `disparados 0` en las dos mitades. Contaba caminatas que vencían sin mover al bot, y el bot
> encajado **sí se mueve** (`SE MOVIO 93 u`, `69 u`, `64 u` — se sacude en la jaula), además de que
> entre caminata y caminata pasan hasta **81 s**. *Medí el movimiento de la caminata en vez del
> desplazamiento neto, y até el arreglo al reloj del mecanismo que estoy arreglando.*
>
> **Reescrito sobre el número que ya estaba a la vista: `quieto desde`.**
> `phantasmagoria_ghost_stuckbailoutsecs` (**20 s**, `0` = control) — quieto **y queriendo moverse**,
> porque un fantasma plantado a propósito (`movement_watch`, Diseño 18) se teletransportaría solo. ⚠
> Cambió de nombre porque cambió de unidad: el `_stuckbailout` viejo contaba caminatas y era
> `FCVAR_ARCHIVE`.
>
> **Lo pendiente de medir, en orden:** (1) el A/B del bailout nuevo, **encerrándolo en props** — las
> tres filas *Sin correr* de la r11 lo fueron porque el bucle no se reprodujo; (2) la mitad ①
> (`escapedist 0`) con el bot encajado, que es la única que cierra por qué en la r9 un destino de
> ~100 u tardaba 10 s en dar `LLEGO` cuando hoy uno de 301 u lo da en 1,4 s; (3) **catorce saltos en
> tres segundos**, que salió del contador de saltos sin que ninguna fila lo pidiera.
>
> ⭐ **La fila del control de `stepsilent` CERRÓ a la cuarta**, con el botón nuevo
> (`phantasmagoria_ghost_steps control`), los dos lados del A/B y 39 pisadas en el `listen`.
>
> ⚠ **Tres arreglos de método que costaron caro:** el botón `force` **se niega** si la precondición no
> está; se **borraron dos líneas predictivas** que la r10 refutó en su propia salida (una imprimía un
> ritmo **negativo**); y *cuatro modos de falla distintos sobre la misma fila no son cuatro descuidos:
> son una receta demasiado larga* — por eso el botón.
>
> **El salto queda descartado como causa, con número:** las alturas pedidas fueron 60, 60, 12, 67,9,
> 67,9 y 32. El tope es 245 y **nadie pide 245**.
>
> ⚠ **Y la evidencia de que el rescate estaba corriendo no servía como evidencia.** Era *«aparece en
> la lista de 32 tareas de `phantasmagoria_ghost_where`»*, y esa lista sale de `m_TaskList`, que es el
> **registro estático** y nadie lo vacía nunca. Arreglado antes de correr, y la corrida lo confirmó:
> **8 ACTIVAS de 32 registradas** — `movement_watch`, `movement_stalkenemy`, `movement_camp` y
> `movement_followsound` están registradas y **no corriendo**, al revés de lo que este documento
> venía afirmando.

**Lo anterior a esta sesión está pusheado en `c92dca2`.** Lo de la sesión de velocidad y puertas son dos archivos nuevos
(`server_speed.lua`, `server_doors.lua`) colgados de `ENT.MyClassTask`, y **cinco rondas corridas en
juego**. Las planillas viven en `dev/checks/` y **no están versionadas** (`dev/` está fuera de todo
repo), igual que `dev/other/`.

**La ronda 6 CORRIÓ: la planilla marcó 7 de 7 en verde. Cinco lo están; dos no, y las corrige el
propio reporte.** El detalle está en «Ronda 6 corrida» más abajo, y el resumen es:

- **El silencio quedó CERRADO en juego**, después de cuatro rondas. Con `doorsilent 2` no suena
  nada; con `0` la misma familia de puerta suena. Y las dos mitades que se agregaron antes de
  correr quedaron **medidas**, no supuestas.
- **La 06 no midió su mecanismo**: `fasesPorAtasco` marcó **0 en toda la sesión**, que es su propio
  criterio de FALLA escrito de antemano. Lo que se midió es el control negativo, y es bueno — pero
  es otra cosa.
- **La 05 pasó a ojo**, sin la medición que la propia fila pedía.

**La ronda 7 CORRIÓ y quedó cerrada: 6 de 6.** El veto de geometría anda, la hoja hermana quedó
cerrada en `gm_prison`, y `testdoor` ya no miente. La fila **02** se cerró **por criterio del autor y
no por número** —su número no podía discriminar y el error era del check— con el A/B observacional:
con `runsafety 1` camina al subir escaleras y al pegarse a objetos, con `0` corre para todo. Detalle
en «Ronda 7 corrida».

> ⚠ **El defecto abierto más grave del arco, y no salió de ninguna fila sino de preguntar por la
> experiencia con el NPC: el fantasma salta, queda encajado entre props y el techo, y hay que sacarlo
> con el physgun.** Es el primero que necesita intervención manual. La base tiene rescate
> (`reallystuck_handler`, que teletransporta o borra) y está registrado en nuestro fantasma — o sea
> que **el rescate existe y no rescató**, y no hay ningún instrumento que diga por qué.

**Lo pendiente ahora, en orden** (prompt del chat siguiente en
[`dev/PROMPT_phantasmagoria_encaje.txt`](../dev/PROMPT_phantasmagoria_encaje.txt) — el punto 2 de
abajo **ya se hizo**, y el prompt viejo `…_encaje_y_pisadas.txt` queda sólo como registro):

1. **El encaje contra el techo — INSTRUMENTO ESCRITO, PLANILLA SIN CORRER.** Lo que falta es
   correrla. Primero el instrumento —que `reallystuck_handler` diga cuándo arranca y qué hace— y
   recién después tocar el salto. La hipótesis del autor (*«tal vez se soluciona evitando que salte
   tanto»*) es razonable y **no está medida**; darla por buena antes de instrumentar es exactamente
   lo que costó las rondas 5 y 6.

   > **Hay tres mecanismos candidatos leídos en la base, y ninguno medido.** El más fuerte:
   > **el teletransporte está vetado mientras el bot te ve** — `shared.lua:3868` es
   > `if not myTbl.IsSeeEnemy and extremeUnstucking:GetBool() and ( extremeStuck or not canGotoEscape )`.
   > Si se encaja saltando hacia vos, sigue viéndote, cae siempre al `elseif` de `:3899` y lo único
   > que hace es volver a intentar **caminar** a un costado, cada 10 s, para siempre. Los otros dos:
   > **detectarlo tarda ~80 s si no está en el piso** (`noNav`, `:3714`, exige `IsOnGround`, y sin él
   > `size` queda en 80 en vez de 10 con una inserción por segundo), y **la primera pasada nunca es
   > la del teletransporte** (`IsUnderDisplacement` mide terreno, no props, así que `extremeStuck` da
   > false).
   >
   > **Y la base regala el botón:** `myTbl.overrideVeryStuck` (`:3747`, usado en el `if` de `:3816`)
   > fuerza la rama de rescate en ~1 s, sin esperar los 80. Permite el A/B de `IsSeeEnemy` **sin
   > encajar al bot de verdad** — pero eso mide *qué rama toma el rescate*, no *que un bot encajado
   > llegue a ella*. Las dos mediciones hacen falta y son fáciles de confundir; en la planilla son
   > las filas **02-04** y las **05-06**.
   >
   > ⚠ **Y el A/B no se puede correr de un solo disparo, que es como estaba planteado.** Con los dos
   > relojes en 0, `canGotoEscape` es `true` y `extremeStuck or not canGotoEscape` da **false**: el
   > **primer** disparo va a caminar *aunque `hunt` esté en 0*. Hace falta un **segundo** disparo
   > entre 5 y 80 s después. Un A/B corrido una sola vez habría leído eso como *«(a) es falsa»* — la
   > conclusión inversa.
2. **El silencio de las PISADAS, por flag** — **CORRIDO, 4 de 8 cerradas** (2026-08-07). Es
   `server_steps.lua`. **La restricción del autor quedó CERRADA en juego** —39 pisadas calladas y
   publicadas al consumidor— y las otras cuatro filas se marcaron verdes sin la medición que pedían.
   Re-corrida en
   [`dev/checks/phantasmagoria-pisadas-r8b.html`](../dev/checks/phantasmagoria-pisadas-r8b.html),
   **4 filas**. Ver «Ronda 8 CORRIDA» más abajo. Pedido del
   autor (2026-08-07). En Phasmophobia el
   fantasma suena al caminar **en hunt y en eventos**, no siempre, así que esto depende del estado
   igual que `phantom_Hunting`. El Myling (§5) es el tipo que camina callado: es exactamente este
   flag, como `phantom_SilentDoors` lo fue para las puertas.

   > **Y la restricción es la INVERSA de la de las puertas, y la puso el autor antes de que se
   > escribiera una línea: el Paramic tiene que poder oírlas después.** Con las puertas el silencio
   > se hizo **borrando un dato** —las siete keyvalues— y ahí está bien. Acá no: la pisada tiene que
   > **seguir ocurriendo** como evento, con su posición y su intensidad, y lo único que se apaga es
   > que el jugador la escuche. *Silenciar no puede significar «que no pase»; tiene que significar
   > «que no se oiga», con el hecho intacto para el que después lo vaya a medir.* Si se implementa
   > borrando la pisada, el bloque del Paramic va a tener que volver a tocar este archivo y el
   > síntoma va a ser un Paramic que no detecta nada, sin un solo error.

   Los dos puntos de extensión, leídos: **`ENT:AdditionalFootstep( footPos, foot, stepSound, volume,
   filter )`** (`footsteps.lua:203`) es un stub declarado por la base para esto —*«if it returns
   true, blocks default sound playing»*— y **recibe `footPos`**, o sea que es el lugar donde se sabe
   que hubo una pisada y dónde. Y el gancho para el consumidor va como el de las puertas
   (`hook.Run( "PhantasmagoriaGhostUsedDoor", … )`), por el mismo motivo: el productor es este
   bloque y el consumidor es otro.

   > ⚠ **Este párrafo decía sobre `IsSilentStepping()` algo que es falso, y se corrige acá porque es
   > el documento de traspaso.** Decía que *«lo consulta en ~11 lugares […]: apagarlo apaga toda esa
   > familia, no sólo las pisadas»*. Se censaron los **seis** call sites de `MakeFootstepSound` y es
   > al revés: **no tapa ninguna pisada.** Ni la de caminar —`ProcessFootsteps`
   > (`behaviouroverrides.lua:141`) no lo consulta en ningún lado—, ni la del salto
   > (`motionoverrides.lua:2997`, con el chequeo en **:2999**, o sea *después*), ni las tres del
   > aterrizaje (`:3459`, `:3474`, `:3485`, con sus chequeos en la línea siguiente). El único que sí
   > tapa es el de la caída letal (`:3599`), y de rebote, por el `return` de `:3578`.
   >
   > O sea que **no es una palanca gruesa: son dos palancas para dos familias, y hacen falta las
   > dos.** `AdditionalFootstep` para la pisada; `IsSilentStepping` para todo lo que la rodea —sin
   > eso, un fantasma «callado» sigue sonando al aterrizar, porque la base trae
   > `ENT.MetallicMoveSounds = true` (`shared.lua:161`) y este fantasma no lo pisa. Es la regla 2 en
   > miniatura. *El error no era de matiz: apuntaba al candado equivocado, que es lo que este
   > proyecto ya pagó dos veces.*
3. **La cordura (§19)**, que es la que tiene que reemplazar al andamio `phantasmagoria_hunt`.

### Revisión con ojos frescos, ANTES de correr — dos arreglos entraron encima

La planilla pasó de 6 a 7 filas porque una revisión del bloque destapó **dos defectos que la ronda
6 no habría podido ver**, los dos contrastados contra el código de la base y contra el mod de
referencia:

- **(a) El silencio colgaba sólo de NUESTRA escalera**, y la base abre puertas por su cuenta
  (`ShootblockerThink` → `tryToOpen` → `Use2`). Y es antagónico: cuando la base abre una
  `prop_door_rotating` se pone `term_NextUse = CurTime() + 3` (`shared.lua:1345`) y nuestro Think
  respeta ese reloj a propósito, así que **nos absteníamos justo los 3 s en los que la puerta
  suena**. La fila 01 no lo veía: `phantasmagoria_ghost_testdoor` fuerza nuestro camino, o sea que
  **habría salido verde con el juego sonando** — el modo de falla de la ronda 3, otra vez. Ahora el
  silencio vive también en `TerminatorBlockUse`, el mismo hook que el veto, que es el único punto
  que ven las dos aperturas. La fila **04** es nueva y mide exactamente eso, con su contador propio
  (`silencio N · M de ellas sobre aperturas de LA BASE`).
- **(b) El restore escribía `""` sobre los campos que nunca pudo LEER** (`saved[key] or ""`), sobre
  el único mecanismo del bloque que le cambia el mapa a todos para siempre. No era un borde raro:
  son 2 de 7 claves en una `prop_door_rotating` y 5 de 7 en una `func_door`, o sea que el camino
  peligroso estaba transitado en cada puerta y salía bien **de casualidad**, porque esas claves no
  existen en esa familia. Ahora lo que no se lee no se pisa —la puerta suena, que es la falla
  ruidosa— y la bitácora separa *«no tenía sonido»* de *«no lo pude leer»*, que antes imprimían la
  misma línea.

**Y la planilla misma tenía el defecto de la familia:** `render()` escapaba `title` y `tag`, que
llevan `<code>`/`<strong>`, así que los siete títulos se leían literales. La corrección anterior
había arreglado el criterio y se olvidó del encabezado. Arreglado, con `plain()` para que el
reporte que se pega en el chat no salga con tags.

---

## Ronda 11 CORRIDA (2026-08-07) — **el bailout nunca disparó, y el gatillo era mío**

Marcó 6 de 6. **Una lo está, tres son *Sin correr*, y el hallazgo es un defecto de mi diseño que
ninguna fila pedía.**

### ⚠ `disparados 0` en las dos mitades del A/B — y las dos causas son del gatillo

El gatillo contaba *«N caminatas seguidas que vencen habiéndose movido menos de 15 u»*. Con el bot
encajado de verdad **nunca llegó a dispararse**:

- **① El bot encajado SE MUEVE.** Las caminatas dieron `SE MOVIO 93 u`, `69 u`, `64 u` — se sacude
  adentro de la jaula de props sin salir de ella. Cada una reseteaba el contador. *Cuánto se movió la
  caminata no dice si el bot se despegó: dice cuánto se agitó en el lugar.*
- **② Entre caminata y caminata pueden pasar 81 s.** El gatillo colgaba del **fin** de una caminata,
  y la arranca el handler — que tras cada rescate vacía `historicPositions` y necesita volver a
  juntar 81 a una por segundo. Medido: **`rescates 1` en toda una ventana de 100 s**, con `hist 80/81`
  al final. Con N=3, el bailout tardaría **cuatro minutos**.

**Las dos son el mismo error: medí el movimiento de la caminata en vez del desplazamiento neto desde
que quedó trabado, y até el arreglo al reloj del mecanismo que estoy arreglando.** *Un rescate que
espera al que falló hereda su latencia.*

**El gatillo bueno ya estaba medido y a la vista en el reporte: `quieto desde`** — llegó a 59,7 s en
la r10 y a 47 s en la r11, y en el control de la r11 (100 muestras deambulando) **nunca pasó de 1 s**.
No depende del handler y no lo resetea una sacudida. Pide además que el bot **quiera** moverse
(`GetDesiredSpeed` alto con velocidad real en cero): sin eso, el día que exista `movement_watch`
—Diseño 18, hoy registrada y no corriendo— un fantasma plantado a propósito se teletransportaría
solo. *Estar quieto y estar trabado se ven igual desde una posición; lo que los separa es si quería
moverse.*

⚠ **Y la convar cambió de nombre porque cambió de unidad:** `_stuckbailout` contaba caminatas,
`_stuckbailoutsecs` cuenta segundos (default **20**). Las dos son `FCVAR_ARCHIVE`, así que un servidor
con `stuckbailout 3` guardado habría leído ese 3 como tres segundos. *Una perilla que cambia de unidad
tiene que cambiar de nombre, o el valor guardado miente en silencio.*

### Las tres filas que no midieron lo que decían

- **01 y 02 son *Sin correr*:** en **ninguna** de las dos mitades se reprodujo el bucle de
  `SE MOVIO 0 u` de la r10 — el bot se movía 64-93 u por caminata. Sin la condición que el bailout
  existe para atacar, no hay A/B. La fila lo decía textual.
- **03 es *Sin correr*, y contesto la pregunta del autor:** *«¿o querías que lo encerrara en props?»*
  — **sí**. Se probó corriendo y saltando de camarote en camarote, así que dio `rescates 0 · destinos
  cortos 0` y no midió ni el A/B de `escapedist` ni el ciclo de 10 s. **Lo que sí dejó, y vale:** el
  fantasma *«me logra seguir sin bloquearse»* con 11 saltos de 40-100 u.

### ⭐ La 04 CERRÓ, después de cuatro rondas

`>>> PASA: la convar en 0 le gano a un flag que dice que SI`, con `override true` y `ahora mismo
SUENA` — **y el A/B completo**, porque con `stepsilent 1` y el mismo override el reporte dice
`CALLADA   el tipo camina callado ( el override … dice SI )`. Más `listen 20` con **39 pisadas, 8
calladas publicadas al consumidor**. *El botón resolvió lo que cuatro recetas escritas no pudieron.*

### La 05 pasa, y de paso destapó dos cosas que nadie pidió

`disparados 0 · rescates 0` con el bot sano, en hunt y en calma, con la bitácora vacía. ✔

> **⚠ CATORCE SALTOS EN TRES SEGUNDOS.** Entre `t=3005.8` y `t=3008.4`, catorce `SALTA altura pedida
> 20` seguidos — el `simpleJumpMinHeight` de la base, o sea el default de `jumpingHeight or
> aboveUsJumpHeight or simpleJumpMinHeight`. Es un bucle de salto contra algo, y **no lo pidió ninguna
> fila**: salió del contador que existe para otra cosa. Va a la próxima ronda.
>
> **Y la alarma del bloque de puertas se disparó:** `#1335 atraveso mas de 5 s seguidos y se lo forzo
> a solido. Eso no deberia pasar: mirar contra que puerta.` Es la guarda de `server_doors.lua`
> avisando de lo que ella misma llama imposible.

---

## Ronda 10 CORRIDA (2026-08-07) — el arreglo anduvo, **y destapó el defecto de abajo**

**Marcó 8 de 8. Cuatro lo están, una es la que cierra el arco y dos son *Sin correr*.**

### El arreglo hizo exactamente lo que prometía

`destinos cortos vistos 8 · corregidos 8 · sin reemplazo 0`, y **los destinos nacían a 71, 88, 96,
97, 99, 100, 104, 111, 116 y 133 u** — todos por debajo del umbral de 150 con el que `:3676` los daba
por cumplidos. *La premisa de la r9 era una inferencia y ahora está medida.* Corregidos a ~300 u, el
bot **se movió**: `SE MOVIO 152 u en 1,4 s`, `155 u en 0,8 s`, `185 u en 4,7 s`. Y `llego` cayó de
**7 de 7** a **1 de 6**: los demás dicen `se venció`, que es la verdad. *El éxito falso desapareció.*

### ⚠ Y mi predicción del pie de la planilla quedó REFUTADA

Decía: *«la apuesta es que arreglando la caminata el bot se despega y nunca se llega a la rama del
teleport»*. Con el destino ya sano a **306 u**, el autor lo dejó encajado y salió esto **cinco veces
seguidas**, con la misma posición hasta el sexto decimal:

```
759.8  DESTINO CORREGIDO  100 u -> 306 u
769.8  la caminata SE VENCIO ( 10 s )   SE MOVIO 0 u   el destino estaba a 306 u
771.9  DESTINO CORREGIDO  100 u -> 306 u
781.8  la caminata SE VENCIO ( 10 s )   SE MOVIO 0 u   ...
```

**`SE MOVIO 0 u` en 10 s con un destino sano.** El defecto de abajo no es adónde lo manda: es que
**encajado no puede caminar**, y la caminata no es un rescate para ese caso por construcción. La
única rama que sacaría a un bot que no se puede mover es el **teleport**, y `:3868` la prohíbe
mientras `IsSeeEnemy` sea true — que es exactamente la situación, porque se encaja saltando *hacia*
el jugador.

> **no puede caminar + no puede teletransportarse = hay que sacarlo con el physgun.**
> Las dos mitades juntas dan el síntoma tal como el autor lo reportó. Y el criterio de FALLA de la
> fila 04 lo tenía escrito de antemano: *«`SE MOVIO 0 u` con el destino ya corregido separa "el
> destino era malo" de "no puede caminar", y son arreglos distintos»*. Eran los dos.

**Entró `phantasmagoria_ghost_stuckbailout` (default 3, `0` = control):** tras N caminatas seguidas
que vencen habiéndose movido menos que el radio con el que la propia base define «quieto» (15 u), lo
teletransportamos nosotros. *El gatillo no es una lectura: son los dos números que esta ronda midió.*
⚠ Teletransporta a un fantasma que te está mirando, y eso se ve — es un cambio de comportamiento, no
un arreglo invisible.

### La fila 04 no fue un A/B: nunca se corrió la mitad ①

Las dos sesiones se corrieron con `escapedist 300`. **Sin la mitad rota no hay A/B**, y la fila lo
decía. Lo que sí quedó es un antes/después contra la r9, que vale pero no es lo mismo.

### La fila 05, contestada acá porque el autor la dejó abierta

**PASA para el caso con destino ≥ 150, y con evidencia directa:** `RESCATE → CAMINAR … destino a
306 u` y exactamente 10,0 s después `la caminata SE VENCIO ( 10 s )`. **El ciclo de 10 s es
`extremeUnstuckingUntil`** (`:3913`), no un `SUCCESS` tardío — que era la segunda de las dos
explicaciones escritas en el criterio.

**Y para el caso con destino < 150 sigue sin explicarse.** Con el arreglo puesto, un destino a 301 u
del que el bot recorre 152 u da `LLEGO` a **1,4 s**, o sea que `:3674` reacciona rápido cuando
corresponde. Entonces en la r9, con destinos de ~100 u, el `LLEGO` tendría que haber sido casi
inmediato y tardaba 10 s. **Los dos conjuntos de datos no se reconcilian**, y la medición que falta
—el par (`destino a N u`, tiempo hasta el `LLEGO`) con un destino corto— se provoca con
`escapedist 0`, que es justo la mitad que no se corrió. *No se cierra por lectura.*

### Dos criterios míos que la corrida refutó, los dos en su propia salida

- **`esperado +1 … menos 2 del trimming = -1 neto`.** Un neto **negativo**, que significaría que el
  array nunca crece. Dos errores: el trimming de `:3774-3777` corre **sólo** dentro del
  `if #historicPositions > size`, así que por debajo del umbral no resta nada; y por arriba tampoco
  resta 2 en régimen, porque saca 2 y al pase siguiente inserta 1, de modo que **oscila**. No hay un
  neto que sea un número. Y el `faltan ~81 s` de al lado usaba mi `noNav` contra el de la base — *la
  misma fracción de dos relojes que la r9 ya había refutado, escrita otra vez en la línea de al
  lado.* **Las dos líneas se borraron**: la medición (`último salto MEDIDO`) ya estaba al lado.
- **«`tareas` tiene que seguir diciendo 8».** Salió 7, 8 y 8, con `movement_duelenemy_near` y
  `movement_inertia` entrando y saliendo. **El número de tareas activas no es constante por diseño**,
  y el criterio lo trataba como invariante.

### La fila 08, por cuarta ronda

`phantasmagoria_ghost_flag pasos 1` seguido de `pasos auto`, sin leer el reporte ni enganchar el
oyente. **Cuatro modos de falla distintos sobre la misma fila** —en la r8 faltó el `hunt 1`, en la r8b
la convar nunca pasó por 0, en la r9 el flag no se puso, en la r10 se puso y se sacó— *no son cuatro
descuidos: son una receta de cinco pasos demasiado larga para ejecutarla a mano.* Entró
**`phantasmagoria_ghost_steps control`**, que corre los cinco pasos, mide, **escribe el veredicto
binario** y devuelve el estado con `control off`.

---

## Ronda 9 CORRIDA (2026-08-07) — la planilla marcó 9 de 9, y **cuatro lo están**

**Y lo que encontró no es ninguno de los tres candidatos: el rescate ARRANCA, corre SIETE veces en
60 s, y no mueve al bot ni un centímetro.**

### El hallazgo, que estaba adentro de una fila verde

La fila 06 dejó `rescates 7 ( TELEPORT 0 · CAMINAR 7 · llegó 7 · se venció 0 )` y esta bitácora:

| t | evento | `quieto` |
|---:|---|---:|
| 1566,4 | `RESCATE → CAMINAR` | 1,5 s |
| 1576,6 | `RESCATE → CAMINAR` | 8,7 s |
| 1586,5 | `RESCATE → CAMINAR` | 18,6 s |
| 1596,5 | `RESCATE → CAMINAR` | 28,6 s |
| 1606,7 | `RESCATE → CAMINAR` | 38,8 s |
| 1616,6 | `RESCATE → CAMINAR` | 48,7 s |
| 1627,6 | `RESCATE → CAMINAR` | 59,7 s |

**Cada 10 s clavados, y `quieto` sube monótono de 1,5 a 59,7 s** — o sea que el bot **nunca** salió
del radio de 15 u. Y los cinco `la caminata LLEGO ( < 150 u )` del medio traen la **misma posición
exacta**, `1691.524170 -780.388794 148.456223`. *La base se declaró exitosa siete veces sobre un bot
que no se movió.*

**El teleport tiene el mismo defecto y también quedó medido:** los tres de la sesión movieron
**83 u, 8 u y 46 u**. Ninguno llega a **dos metros** (52,5 u = 1 m); el de 8 u son quince
centímetros. Y el autor lo escribió al lado sin verlo: *«lo vi moverse al camarote, sigue parado
aún»*, y hizo falta **un segundo `force`** para despegarlo. El criterio de FALLA de la fila 03 decía
esto textual —*«si `se movio` da chico con `SALIO POR TELEPORT`, teletransportó a tres metros: el
rescate corre pero no rescata»*— y la fila se marcó verde igual.

**La raíz es común a las dos ramas y está en `:3836-3859`:** `freedomPos` se elige por **distancia
mínima** (`distToMe < bestDist`) entre las navareas de la caja, excluyendo sólo la de abajo. Y este
mapa tiene **1715 navareas** porque el parcheador de la base crea áreas donde camina alguien — así
que «la más cercana que no es la mía» está **pegada**. Después, `:3676` declara la caminata terminada
con `dist < 150`, y un destino que ya nace debajo de ese número convierte al rescate en un
**no-operativo que se anuncia como éxito**.

> **Lo que NO está medido y hay que medir antes de arreglar:** por qué el ciclo dura **10 s** y no un
> tick. Con el destino a menos de 150 u, `:3674` debería declarar `SUCCESS` en el pase siguiente, no
> a los diez segundos. Hay dos explicaciones posibles —que `Distance2D` dé ≥ 150 y el `SUCCESS`
> llegue justo antes de que venza `extremeUnstuckingUntil`, o que el destino se recalcule— y **no se
> pueden separar leyendo**. El instrumento ya imprime la distancia al destino en el evento; falta
> correrlo.

### Las cuatro filas que no midieron lo que decían

- **La 02 es *Sin correr* por su propia precondición.** Pedía `canGotoEscape SI` y salió
  `canGotoEscape NO   escape +63.1 s` — o sea que **el reloj ya estaba puesto**: la rama de caminar
  había corrido sola, sin que nadie apretara nada. La fila decía qué hacer con eso, textual: *Sin
  correr*.
- **La 04 es *Sin correr*, y es la fila estrella del arco.** Pedía `ve al enemigo SI` y las **dos**
  lecturas dicen `ve al enemigo NO · hunt SI`. La precondición estaba escrita —*«no es `hunt 1`: es
  que la salida diga `ve al enemigo SI`»*— y aun así se marcó verde. Midió, otra vez, lo mismo que la
  03.
- **La 03 pasó, pero su número desmiente su propio criterio.** `SALIO POR TELEPORT   se movio 46 u`
  contra un PASA que pedía *«cientos de unidades»*.
- **La 08 se corrió mal por TERCERA ronda seguida.** El reporte dice `phantom_SilentSteps = false ·
  override nil`: **el `flag pasos 1` no se puso**, así que no hubo flag en 1 al que ganarle — que es
  lo único que hace del `0` un control. Y no hay salida de `listen`, que era el instrumento del
  criterio.

**Lo bueno: los pares existen, sólo que en las filas equivocadas.**
El candidato **(c)** quedó medido dentro de la fila 03 (`canGotoEscape SI` → `CAMINAR`), y el
candidato **(a)** dentro de la fila 06 (`ve SI` → 7 de 7 por `CAMINAR`, contra `ve NO` → `TELEPORT`).
**El A/B del veto está cerrado**, sólo que ninguna de las dos filas que lo dicen es la que lo pedía.

### (b) DESCARTADO, con número

Encajado entre props y el techo, el `watch` dio **`piso SI`** en casi todas las muestras: el fantasma
queda **apoyado en un prop**. Así que el umbral es **11 y no 81**, y la detección tarda ~3 s, no ~81.
La cuenta de los 80-contra-81 del bloque anterior **no aplica a este caso** — sigue abierta para un
encaje que sí quede en el aire.

### El arreglo elegido (decisión del autor), escrito y sin correr

**`phantasmagoria_ghost_escapedist`, default 300, `0` = control.** Cuando la base pone un destino a
menos de esa distancia, lo reemplazamos por el **más cercano que esté más lejos** que ella —
conservando el filtro de la base que no desatasca acercando al enemigo (`:3843`). El default sale de
un número de la base y no de un gusto: es el **doble** del umbral de `:3676`, así que un destino no
puede nacer cumplido ni quedar cumplido por el primer paso.

**Es la intervención mínima:** no se copia el handler vía `DoCustomTasks`, no se envuelve
`terminator_Extras.TeleportTermTo` (que es un global de todos los terminators del servidor) ni
`SetPosNoTeleport` (que tiene otros seis call sites). Se corrige un campo de `data`, que es el mismo
que ya leíamos para medir.

**Y corre en `AdditionalThink`, no en el poll de 4 Hz, y el lugar no es intercambiable:** la corrutina
de prioridad llama `AdditionalThink` en `behaviouroverrides.lua:676` y `RunTask("BehaveUpdatePriority")`
en `:694`, así que desde ahí llegamos **siempre** antes del bloque que declara la llegada, en el mismo
pase. Desde el poll podrían pasar hasta 0,25 s y en ese hueco `:3674` ya lo dio por cumplido — *un
arreglo que llega tarde a veces es un arreglo intermitente, que es peor que ninguno porque no se puede
medir.*

> **El teleport NO se corrigió, a propósito.** Tiene el mismo defecto (83, 8 y 46 u) y la apuesta es
> que arreglando la caminata el bot se despega y nunca se llega a esa rama, porque a ella sólo se
> entra con `not canGotoEscape` y **ese reloj lo pone la caminata al fallar** (`:3911`). **Es una
> predicción, no una medición** — y el instrumento sigue contando los teleports con su distancia, así
> que si siguen apareciendo cortos se va a ver.

### El arreglo de método: el botón se niega

Tres filas de la r9 se corrieron fuera de su precondición y se marcaron verdes, **y el botón imprimía
los dos valores en la primera línea de su salida**. Ahora `force` toma `primero` / `segundo` / `veto`,
comprueba el estado y **no gasta el disparo** si no corresponde — con el motivo, el valor actual y qué
hacer para llegar al lado que falta. Es lo mismo que la ronda 6 dejó escrito con `testdoor`, que
gritaba `ESCUCHA AHORA` sobre una apertura que el veto se iba a comer: allí el dato también estaba
impreso al lado. *Imprimir la precondición junto al veredicto no alcanza: hay que negarse.*

### Dos defectos de instrumento, los dos míos

- **`hist N / umbral` emparejaba el numerador de la BASE con un denominador MÍO**, cada uno muestreado
  en un instante distinto. Con el bot en el borde de una navarea, `noNav` oscilaba y salió
  `86/11` → `92/81` → `92/11` en muestras consecutivas: el umbral saltando entre 11 y 81 de un
  segundo al otro. *Una fracción cuyas dos mitades vienen de dos relojes distintos no es una
  fracción.* Ahora se **mide** el salto real y el umbral va aparte, etiquetado como el de esa muestra.
- **El criterio «sube de a 1 o de a 4» era incumplible, y lo escribí yo.** El trimming de
  `:3774-3777` saca **dos** por pase una vez superado el umbral, así que lo que se ve es el **neto**.
  Lo medido fue **+6** = 8 (`×4` por `noNav`, `×2` por `isUnstucking`, que el propio reporte confirmaba
  en `true`) menos 2. **Ninguno de los dos valores que la planilla esperaba podía aparecer nunca.**

### Y un dato que corrige una afirmación vieja de este documento

`_where` dijo **`tareas 8 ACTIVAS de 32 registradas`**. Este documento y la memoria venían diciendo
que *«las 31 tareas que lista `ghost_where` son el inventario del cerebro heredado **corriendo**»*, y
es falso: `movement_watch`, `movement_stalkenemy`, `movement_camp` y `movement_followsound`
—justamente las que el diseño da por gratis— están **registradas y NO corriendo**. Lo que corre son
ocho: `awareness`, `enemy`, `inform`, `movement_inertia`, `reallystuck`, `shooting`,
`terminator_nextbot_phantom_handler` y `trancebreaking`.

### El salto: la hipótesis del autor no se sostiene con el número

`saltos 5 pedidos · 5 ocurrieron · 0 leap`, y las alturas pedidas fueron **60, 60, 12, 67,9, 67,9 y
32**. El tope es 245 pero **nadie pide 245**: el máximo real fue **68 u**. El control de `Term_Leaps`
pasó (`0 leap`). *«Tal vez se soluciona evitando que salte tanto»* era razonable y **el instrumento la
refuta**: el fantasma no salta alto por su cuenta. El único que pide 245 es nuestro propio botón
`phantasmagoria_ghost_steps jump`.

### Pedido nuevo del autor, ya implementado

*«Me molesta el ruido metálico al saltar, eso es un remanente del terminator que es un androide
robótico, el phantom debería saltar con ruidos normales»*. Entró `ENT.MetallicMoveSounds = false` en
`server_steps.lua`, y **no es una desviación de la base: su propio bot desarmado ya lo apaga**
(`terminator_nextbot_fakeply.lua:67`, que es literalmente el molde de este fantasma, y
`csoldier.lua:131`). *Le copiamos el `DefaultWeapon` y el `TERM_FISTS` y le dejamos los sonidos de
robot.* Los cinco call sites están censados en el archivo; en los cuatro de movimiento el
`MakeFootstepSound` está **afuera** del `if`, así que el salto no queda mudo: queda con la pisada de
la superficie. ⚠ Se lleva cuatro `ScreenShake` y tres `Whaps`, y **cambia lo que midió la r8b**: sin
metálicos, la fila del salto de aquella ronda deja de discriminar.

---

## El encaje — el bloque escrito (2026-08-07), **corrido en la ronda 9**

`server_stuck.lua`, colgado de `ENT:AdditionalThink` y **no** de `ENT.MyClassTask` — esa clave
(`Think`) ya es de `server_doors.lua`, y una segunda asignación la pisaría entera con el síntoma de
un bloque que deja de correr sin un solo error. Hay una guarda al final del archivo que lo comprueba
en vez de confiar en el comentario. Planilla
[`phantasmagoria-encaje-r9.html`](../dev/checks/phantasmagoria-encaje-r9.html), **9 filas**
(7 del encaje + 2 de regresión de pisadas).

**No cambia ningún comportamiento del NPC.** Ni una convar de mecanismo, ni un flag nuevo.

| Qué entró | Por qué |
|---|---|
| Lectura de `m_ActiveTasks["reallystuck_handler"]` | Es **la misma tabla `data`** que el handler muta (`taskoverride.lua:201`), así que `canGotoEscape` sale **exacto** y no recalculado |
| `phantasmagoria_ghost_stuck` | El reporte: las cuatro salidas, `IsSeeEnemy`, `IsOnGround`, `hist N/umbral` con cuenta regresiva, los dos relojes con signo, y la **predicción** de la rama |
| `… force` | **El botón.** `overrideVeryStuck` dispara la rama en ~1 s. Con muestreador propio, porque la ventana dura menos que el trámite de medirla |
| `… watch [seg]` | La otra medición: encajar al bot con el physgun y ver si `IsOnGround` da true o false. Imprime **por transición**, con latido cada 10 s |
| Override de `StartTask` | La rama tomada se lee del `reason` que **la base ya escribe** (`reallystuck AFTER TELEPORT` / `SUCCESS` / `partial FAIL`) |
| Override de `Jump` y `JumpToPos` | Los saltos, separando **pedidos** de **ocurridos** (`ENT:Jump` se sale en silencio fuera del piso, `motionoverrides.lua:2971`) |
| `_where` marca `* activa` | El arreglo del párrafo de arriba |

**La rama de caminar NO se detecta por `freedomGotoPosSimple`**, que es lo obvio: el bloque de
`:3674` lo borra apenas la distancia baja de 150 u, o sea que aparece y desaparece entre dos muestras
nuestras. Se detecta por `nextUnstuckGotoEscape`, que la rama pone en `+80 s` y **nadie baja nunca**.
*Un instrumento más frágil que lo que mide se rompe justo cuando hace falta.*

### Una cuarta salida que no estaba en ninguna lista, y sale de la aritmética

La rama de caminar pone el reloj en `CurTime() + 80` (`:3911`) y **vacía `historicPositions`**
(`:3923`). Para un bot que no está en el piso, volver a juntar 81 posiciones a una por segundo tarda
**81 s** — o sea que cuando el handler vuelve a poder evaluar, el reloj de 80 **ya venció** y
`canGotoEscape` es `true` otra vez. Si eso es así, **un bot encajado en el aire nunca alcanza
`not canGotoEscape`, ni siquiera sin mirar a nadie**, y (a) no sería la única puerta cerrada. Son 80
contra 81: un margen de un segundo, que es la clase de número que no se cierra leyendo. El reporte
imprime los dos relojes con su signo y la cuenta regresiva de `hist` al lado; las filas 05 y 06
traen los datos.

### Los saltos: contados, no juzgados

`ENT.JumpHeight` es **245** (`shared.lua:111`, `70 * 3.5`). Y `ENT.Term_Leaps` es **`nil`** en la base
(`:112`) y este fantasma no lo declara, así que las dos ramas de salto-hacia-el-enemigo
(`motionoverrides.lua:2693`, `:2697`) y el **único** call site de `JumpToPos` (`:2744`) están muertos
para nosotros. Eso deja un control gratis: **`saltos leap` tiene que dar 0 siempre.** Lo que sí puede
saltar es `:2749`, por `GetJumpBlockState` o por «está arriba nuestro» + `IsAngry`.

### El instrumento que audita a los instrumentos también tenía el defecto

`dev/glua_check.py --selftest` se declaraba **NO USABLE** sobre este addon. La causa no era el parser
sino su **control positivo**: mutaba con un `re.sub` crudo y caía adentro del comentario de cabecera
de `client.lua`, cuyo primer `(` está en la línea 13. El código seguía siendo válido y el parser lo
aceptaba con razón. Arreglado extrayendo el scanner del traductor a `_scan()` — la mutación ahora
sólo toca código, y el refactor se controló exigiendo **el mismo veredicto sobre los 100 archivos**
de la base y el addon. *Un control que se rompe a sí mismo desacredita al instrumento sano que
audita.*

---

## Ronda 8 CORRIDA (2026-08-07) — la planilla marcó 8 de 8, y **cuatro lo están**

**Lo que cerró es lo que más importaba: la restricción del autor.** Con las pisadas silenciadas, el
consumidor de prueba recibió **39 pisadas en 15 s, las 39 calladas**, cada una con posición, pie,
volumen y superficie, mientras el jugador no oía ninguna. *Silenciar significó «que no se oiga» y no
«que no pase»*, medido con un tercero enganchado al hook público y no con nuestros contadores.

| Fila | Qué quedó medido |
|---|---|
| **01** | `pasos 45 · el gancho vio 45 · PERDIDAS 0`. **El agujero de `footsteps.lua:330` no mordió**: incluso las superficies sin datos propios devuelven `default.stepleft`. Es la primera buena noticia concreta para el bloque del Paramic |
| **02** | **39 de 39 calladas y publicadas.** La fila entera del bloque |
| **04** | El flag por NPC calla (8 de 8 con el override en 1) |
| **05** | Las dos primeras lecturas de la regla de estado, con motivos **distintos**: `no esta cazando…` → `CALLADA`, y `esta cazando, y el flag … dice NO` → `SUENA` |

**Y de paso salió un dato que nadie pidió y que el Paramic va a necesitar:** el volumen viaja por
superficie — `concrete 0,8`, `dirt 0,4`, `cardboard 0,4`, **`wood 1`**. La madera es la más fuerte
justamente porque **no está en la tabla de materiales de la base** (`footsteps.lua:265-286` sólo
nombra CONCRETE, METAL, DIRT, VENT, GRATE, TILE, SLOSH) y cae al default `volume = 1`.

### Las cuatro que no midieron lo que decían

- **La 03 tiene su rojo escrito en su propia nota.** Con `stepsilent 0` el oyente recibió **11
  pisadas y las 11 calladas** — que es *textualmente* su criterio de FALLA. Se puso verde después de
  mover **otra** convar (`stepsonlyhunt 0`), o sea midiendo el mecanismo de la fila 05 en el lugar de
  la 03. La precondición pedía `phantasmagoria_hunt 1` y no estaba puesto, y la propia fila decía qué
  hacer con eso: **Sin correr**. *Sigue sin medirse que el estado `0` le gane a un flag que dice SÍ,
  que es lo único que lo hace un control.*
- **La 06 no se puede leer.** La nota fue *«no escuche nada ni saltos ni nada»*, y esa frase **no
  distingue «saltó y no sonó» de «nunca saltó»** — que es exactamente la diferencia que esa fila
  existía para medir, porque los metálicos sólo viven en el salto y el aterrizaje. **El defecto es
  del instrumento y es mío:** de las tres filas que necesitaban provocar algo, dos tenían botón
  (`listen`, `falltest`) y ésta dependía de que el bot decidiera saltar solo. *La regla estaba escrita
  en la planilla y la incumplí escribiendo la planilla.* Ahora hay `phantasmagoria_ghost_steps jump`.
- **La 07 no tiene un solo número.** Ninguna salida de `falltest`, ninguna línea `vida N → 0`, y sin
  decir con qué `stepsilent` se corrió — y la mitad que importa es la de `2`, porque con `0` el
  override delega en la base y no prueba nada. Que el fantasma se haya muerto en pantalla no es la
  medición: la medición era el número de los dos lados.
- **La 08 se cerró con la nota vacía.**

### El defecto de instrumento que destapó la corrida

**La bitácora identificaba al fantasma por `EntIndex`, y GMod lo reusa.** Sus seis líneas decían
todas `#1340` y los pasos iban 1 → 38 → 182 → 215 → **1**: no era un contador retrocediendo, era el
fantasma que murió en el `falltest` y el que se spawneó después compartiendo etiqueta. *Una etiqueta
que se repite entre dos objetos distintos no identifica: agrupa.* Ahora imprime `#1340/c37`.

## Ronda 8b CORRIDA — la fuga CERRADA, y la fila del control se corrió mal **por segunda vez**

**Lo que cierra, y es lo que la r8 no había medido:**

- **La fuga de la caída letal está TAPADA, con número.** `silencio SI` → `vida 900 → -2147482748`.
  Con el silencio puesto el fantasma **muere igual**: el override repone el `TakeDamage` que el
  `return` de `motionoverrides.lua:3578` se llevaba. Era el riesgo de comportamiento del bloque y
  queda medido del lado que importa.
- **El botón `jump` funciona y la fila 06 dejó de ser inprovocable.** Cuatro saltos forzados,
  `pasos 47 → 48`, `49 → 50`, `51 → 52`, `54 → 55`, y el de calma contado como `callada` (8 → 13 sin
  mover `sonadas`). El arreglo de método aterrizó.
- **La bitácora ya distingue fantasmas:** `#1323/c6335` y `#1317/c6519` conviven en el mismo log.
- **La línea cruzada del reporte de puertas anda:** `pisadas: stepsilent 0 · stepsonlyhunt 1`.
- **Y `pasos = el gancho vio` en las nueve lecturas, con `PERDIDAS 0` en las nueve**, sobre cuatro
  fantasmas distintos. El agujero de `footsteps.lua:330` está medido y no muerde.

### La fila del control negativo se corrió mal otra vez, y la culpa es de una etiqueta que miente

La fila pedía `stepsilent 0`. Las líneas `convars:` de esa nota arrancan en **2** y siguen en **1**,
**y nunca pasan por 0**; y la lectura ③ —la que la r8 tampoco hizo, y que es la única que prueba que
el `0` le gana a un flag que dice SÍ— sigue sin correrse. Lo que se midió es, otra vez, la regla de
estado.

**Pero el defecto de fondo apareció en la fila 04 y es real:** con `stepsilent 0` y el fantasma fuera
del hunt, el reporte dice `CALLADA`. Es correcto —son dos causas independientes— pero la ayuda de la
convar decía *«0 = ninguno camina en silencio ( control )»*, copiada de las tres de puertas, donde hay
**una** sola causa. *La etiqueta prometía un control global que el mecanismo no da*, y el síntoma fue
el mismo las dos rondas: poner la perilla en 0, seguir sin oír nada, y que el reporte nombrara sólo
la otra causa. **La perilla que acababas de mover no aparecía en la respuesta.** Arreglado en los dos
lados: la ayuda ya no promete un control global, y `la decidio` imprime ahora la capa tapada
(`[ la otra capa, tapada por esta: … ]`).

### Lo que queda sin medir, y es chico

- El **③** de la fila 01: `stepsilent 0` contra un flag en 1.
- La **mitad audible del salto**: los tres primeros saltos ocurrieron con el fantasma en `SUENA` y no
  hay veredicto de oído sobre ellos; la nota *«no sonó nada cuando saltó»* está escrita después del
  salto silenciado. Sin esa mitad, «no se oyó» no distingue el silencio de que no hubiera nada que
  tapar.
- Los pasos **②③④** de la fila 04: que `stepsilent 2` mate el click de la puerta (el acople que
  documenté), el listado de **cinco** flags, y `doorsilent 2`.

Nada de eso bloquea el bloque: son coberturas, no defectos abiertos. **Ya están colgadas de la
planilla del encaje como las filas de regresión 08 y 09** — el ③ en la 08, y la mitad audible del
salto más el acople con la puerta en la 09.

---

> **Y una observación que no es de este bloque y conviene no perder:** el `_where` de la fila 01
> muestra `hunt NO` con `veloc deseada 252 u/s`. En calma la conversión daba **60** (ronda 6:
> `130 × 252/550 = 59,6`). No lo toca nada de `server_steps.lua`, y esta ronda no lo midió — pero
> está en la salida que pegó el autor y merece una lectura antes de la próxima de velocidad.

---

## Las pisadas — el bloque escrito (2026-08-07)

`server_steps.lua`, colgado de `server.lua` **después** de `server_doors.lua` (consume
`PHANTASMAGORIA.ResolveFlag`). Planilla
[`phantasmagoria-pisadas-r8.html`](../dev/checks/phantasmagoria-pisadas-r8.html), **8 filas**.

**La restricción del autor es lo que da forma al archivo, y es la inversa de la de las puertas:** el
Paramic tiene que poder oír las pisadas después. Por eso el `hook.Run( "PhantasmagoriaGhostFootstep",
ghost, paso )` corre **antes** del `return true` que silencia, y `callada` viaja **como dato** en vez
de decidir si el evento existe. Si alguien invierte esas dos líneas, el síntoma es un Paramic que no
detecta nada sin un solo error.

| Qué entró | Por qué |
|---|---|
| Override de **`AdditionalFootstep`** (`footsteps.lua:203`) | Es el stub declarado para esto, y cubre los **seis** call sites de `MakeFootstepSound`, salto y aterrizaje incluidos |
| Override de **`IsSilentStepping`** | La otra mitad: sin él el fantasma «callado» sigue sonando al aterrizar. Ver la corrección de arriba |
| Campo `ENT.phantom_SilentSteps` + convar `_stepsilent` (0/1/2) | El flag del **Myling**, con la convención de la casa. Entra a `FLAGS`, así que lo cubren el comando **y** la guarda del campo pisado |
| Convar `_stepsonlyhunt` (0/1, **default 1**) | La regla de estado: en Phasmophobia suena en hunt y en eventos, no siempre. **Cambia lo de hoy** — deambulando pasa a ser mudo; `0` devuelve el comportamiento anterior y es el control |
| Envoltorio contador de `MakeFootstepSound` | Mide el agujero de `footsteps.lua:330` (`if not stepSound then return end`, *antes* de llamarnos): `pasos - vistas` = pisadas que el Paramic no va a ver nunca |
| `phantasmagoria_ghost_steps listen [seg]` | **El botón.** Engancha un consumidor de verdad al hook público. Sin él, «la pisada se sigue publicando» no se puede provocar — y un check cuya precondición no se puede provocar no es un check |
| `phantasmagoria_ghost_steps falltest` | El botón de la fila 07, porque la rama pide una caída de **2000 u** |
| Una línea nueva en el reporte de **puertas** | Silenciar pisadas también calla el click de `Use2` (`shared.lua:1234`, mismo `if`). Sin esto, las dos mitades de un A/B quedan en dos pantallas — el defecto de la fila 02 de la ronda 7 |

**Y el override de `IsSilentStepping` abría una fuga que no es un sonido.** `LethalFallDamage`
(`motionoverrides.lua:3577`) empieza con `if self:IsSilentStepping() then return end` y el
`TakeDamage( math.huge )` está **adentro**, en `:3596`: ese `return` no se lleva sólo tres
`EmitSound`, se lleva la muerte. Con `ENT.TakesFallDamage = true` en la base y sin pisarlo nosotros,
el flag de sonido **habría regalado inmunidad a la caída letal**. Hay override propio que repone el
daño, y la fila 07 lo mide con su botón. *Se censaron los cinco call sites de `IsSilentStepping` que
no son un `EmitSound` directo buscando exactamente esto; los otros cuatro son efectos, y el del
click arrastra además el `ApplyForceCenter` del mismo `if`.*

**Lo que se decidió y no se midió, para que se lea como lo que es:** que el default de
`_stepsonlyhunt` sea `1`. Sale de lo que el autor describió como objetivo, no de una corrida.

---

## Ronda 6 corrida (2026-08-07) — el silencio CERRADO, y dos verdes que no lo son

**Los dos arreglos escritos antes de correr quedaron medidos, y el que más importaba dio un
número:**

| Qué | Medido |
|---|---|
| **(a) El silencio sobre las aperturas de LA BASE** | **11 de 42** ventanas fueron aperturas que la base hizo sola. **Una de cada cuatro puertas sonaba** y ninguna fila anterior las podía ver |
| **(b) El restore devuelve lo que guardó** | `puertas mudas AHORA MISMO` volvió a **0** en cada lectura, cada `devuelto` dice la misma cantidad de campos que su `silenciado` (5 en `prop_door_rotating`, 2 en `func_door*`), y el autor confirmó que **vuelven a sonar** |
| La alarma nueva (`OJO … NO deja leer`) | **Nunca apareció** — `GetInternalVariable` leyó todos los campos de la familia propia en las dos familias. Es un silencio que significa algo, porque ahora la diferencia se vería |
| Sin doble conteo | Dos `testdoor` seguidos sobre la misma puerta dentro de la ventana → **una** línea `silenciado` y **un** incremento |
| El veto sigue vivo | `VETADAS 4` con `opendoors 0`, y es el control del hook: los dos cuelgan del mismo `TerminatorBlockUse` |
| Destrabar | **`destrabadas 2`** — primera vez en el arco que la rama del `Unlock` se ejerce |

### ⚠ La fila 06 se marcó verde y su propio criterio dice FALLA

La corrida se hizo con **`phasedoors 0`**, o sea con el atravesado **apagado**. Y `porAtasco` empieza
con `puede and …`: **con la convar en 0 la rama no puede evaluarse ni en principio.** El número lo
dice sin ambigüedad: `atraveso 29 veces · **0 de ellas por ATASCO**`, y también 0 en las filas donde
`atravesar` estaba en **1**.

Y hay un motivo estructural, no de tuning: el contador sólo sube `if not self.phantom_Phasing`, y
para una hoja abierta **a 0 u** la regla de cercanía (`distancia <= 45`) ya prendió el atravesado en
el primer tick. *La rama por atasco no puede dispararse justo en el caso para el que se escribió,
porque la cercanía llega antes.* Para que subiera haría falta estar trabado > 2 s contra una puerta
abierta a **más de 45 u** — que es un atasco contra otra cosa, donde atravesar la puerta no ayuda.

**Lo que la corrida sí midió, y es valioso:** el A/B del atravesado, limpio.

| `phasedoors` | `peor` contra una hoja **ABIERTA** |
|---|---:|
| 1 | **0,7 – 0,9 s** |
| 0 | **3,6 s → 5,2 s**, con `velocidad 0 u/s` |

O sea: **la trampa de la hoja que se abre encima es real, y la cercanía sola la resuelve.** La rama
por atasco es peso muerto. Se retira o se marca la fila como retirada — un check cuyo mecanismo no
puede dispararse no es un check, que ya es la lección de la ronda 4.

> **Y una predicción escrita antes de correr que se cumplió:** `reabrio` quedó en **0** toda la
> sesión, por la misma competencia (`STUCK_PHASE_AFTER 2` dispara antes que `FORCE_AFTER*2 = 3`).
> Estaba anotado en la planilla como *esperado*, así que esta vez el 0 no se leyó como falla.

### ⚠ La fila 05 pasó a ojo

*«Si solo camina, está perfecto»* es una observación, y la fila pedía `deseada` = la walk convertida
en **tres lecturas viéndote y tres sin verte**, más la línea `la decidió: override propio ( cazando,
camina )`. Nada de eso está en la nota. **No es que falle: no se midió**, y es la misma distinción
que costó una ronda entera con el silencio. La conversión de velocidad sí quedó verificada de paso,
por otro lado: `objetivo 252` con `deseada 60` en calma (`130 × 252/550 = 59,6`) y `deseada 252`
cazando.

### El defecto que destapó la corrida: `testdoor` no mira si la apertura está permitida

Las **dos primeras** mediciones de la fila 01 son nulas y el reporte lo tiene escrito al lado:

```
[Phantasmagoria] convars: abrir 0 · ...        ← opendoors estaba en 0
] phantasmagoria_ghost_testdoor
#1324  prop_door_rotating #646 ... cerrada
    silencio SI ( ventana de 3 s abierta )   -> ESCUCHA AHORA
    a los 0.9 s: m_eDoorState = 0   no se movio
```

El botón silenció la puerta, gritó **ESCUCHA AHORA**, y el `Use2` se lo comió el veto (`VETADAS`
subió). *No se oyó nada porque la puerta no se abrió.* Es el modo de falla más caro del proyecto en
miniatura: **el instrumento invitó a un verde que no medía nada**, y la fila se salvó sólo porque el
autor volvió a probar con `opendoors 1`. Además abre una ventana de silencio —y le pide prestados
los keyvalues a una puerta— para una apertura que nunca iba a ocurrir, o sea que expone al riesgo de
la fila 03 sin contrapartida.

Arreglo: `testdoor` tiene que consultar `phantom_CanOpenDoors` y **negarse ruidosamente**, con el
motivo que ya devuelve el resolvedor.

### Dos observaciones que no son defectos de este bloque

- **Cazando y a 92 u, el fantasma orbita en vez de cerrar:** `mirada vs jugador 0,9°` con
  `mirada vs marcha 162,4°` a 252 u/s. Te mira y se mueve casi de espaldas. Es la base
  (`movement_duelenemy_near` está en la lista de tareas), y es comportamiento de terminator armado:
  un hunt de Phasmophobia quiere una recta. Va para el bloque de la cordura.
- **La puerta doble no mordió en este mapa:** `gm_break_in_redux` trae las hojas de a pares
  (`#763/#764`, `#949/#950`, `#928/#929`) pero como entidades **independientes** — el bot usa cada
  una por su lado y la bitácora muestra `silenciado` para las dos. El agujero de `slavename` sigue
  siendo real en el código; esta corrida **no da evidencia ni a favor ni en contra**.

---

## Ronda 7 CORRIDA (2026-08-07) — 6 de 6 en verde, y **la 02 no midió nada**

**Lo que quedó cerrado en juego, con dato:**

- **El veto de geometría existe y se ve.** Cinco lecturas de `_speed` cazando: tres con
  `override propio ( cazando, corre )` y `deseada 252`, y **dos** con
  `override propio ( cazando quiere correr, pero canRunOnPath de la base lo VETA )` y `deseada 60`.
  El hallazgo grande de la revisión **corrió**.
- **La hoja hermana quedó CERRADA**, y hacía falta otro mapa: en `gm_prison` apareció la doble de
  verdad. La bitácora lo muestra completo — `silenciado prop_door_rotating #703` +
  `silenciado ( hermana ) #704`, y después `devuelto #703` y `devuelto #704`, **5 campos cada uno** —
  con el contador en `1 → 2 hojas HERMANAS` y el veredicto del autor: *«no hay sonidos al abrir
  puertas dobles»*. El agujero que la ronda 6 no pudo medir por falta de mapa está tapado.
- **Las dos ramas retiradas no dejaron hueco:** `peor` 0,1 → 0,6 → **1,2 s** contra una
  `func_door_rotating` ABIERTA, y el reporte ya no nombra `reabrio` ni `por ATASCO`. Queda un pelo
  arriba del ~1 s del criterio; el autor lo describe como *«atasca 1 segundo… pasa bien»*.
- **De paso se contestó una pregunta abierta de la ronda 6:** el `objetivo 252` no era un misterio —
  `sv_bm_speed_run 280` × `speedmul 0.900`, y ahora el instrumento imprime de dónde sale cada
  factor.

### La 02: el número no discriminó, y el criterio que la cierra es del autor

El A/B se corrió entero — mismo circuito de `gm_prison`, `hunt 1`, `phasedoors 1`, cinco lecturas por
lado — y `peor` dio **0,0 s en las dos mitades**. Con `intentos`, `Use2` y `ABRIO` idénticos (5/5/4).

**Y el número no podía dar otra cosa.** Con `phasedoors 1` el fantasma **no se traba nunca**: las
diez líneas `delante` dicen `velocidad 252 u/s, el umbral es 30`. `peor` sólo cuenta por debajo de
30 u/s con una puerta delante, así que está en el piso de los dos lados por construcción. *Le pedí a
un medidor de atascos-en-puertas que contestara sobre atascos-que-no-son-en-puertas.* El criterio
numérico de esa fila estaba mal escrito, y el error es del check, no de la corrida.

**El discriminante existía y era observacional.** Con `runsafety 1` el autor lo ve **caminar al subir
escaleras y al pegarse a objetos y barandas**; con `0` lo ve **correr para todo, subiendo y bajando
escaleras**. La diferencia es visible, consistente y se mueve con el interruptor.

Y el veredicto es suyo, textual: *«se nota que no es un bot tonto, está midiendo su ambiente y lo
encuentro bien»*, y **no rompe la persecución**. Con eso la fila queda **cerrada por criterio del
autor, no por número** — y así hay que leerla: nadie midió que el veto prevenga un atasco.

> **Y se descartó un arreglo que yo había propuesto.** Iba a mover la marcha vetada de la *walk*
> (60 u/s) a la *move* (137), porque un terminator sin conversión vetado va a 130 y el nuestro cae a
> menos de la mitad. El autor probó el frenado y le gusta. *Era la solución a un problema que él no
> tiene*, y proponerla de nuevo requiere que alguien reporte el problema primero.

### El hallazgo de verdad de esta ronda no salió de ninguna fila

Preguntando por la experiencia con el NPC apareció **el primer defecto que necesita intervención
manual**: *«he visto que salta y queda pegado entre objetos y el techo de un interior, ahí hay que
sacarlo con el physgun»*.

Es peor que cualquier atasco de puerta —de un atasco de puerta sale solo— y **no lo cubre ningún
check**. Lo que se sabe hasta acá:

- La base **tiene** rescate: `reallystuck_handler` (`shared.lua:3647`), que primero manda al bot a
  caminar a un lado y, si eso falla, lo **teletransporta o lo borra**. Está registrado en nuestro
  fantasma: aparece en la lista de tareas de cada `phantasmagoria_ghost_where`.
- O sea que **el rescate existe y no rescató**. Las dos hipótesis, sin medir ninguna: que no llega a
  dispararse, o que se dispara y no puede — su chequeo pide `navmesh.GetNearestNavArea( pos, false,
  50, … )` con criterio estrecho, y un bot encajado contra un techo puede estar fuera de todo
  navarea.
- No hay instrumento: nada dice cuándo `reallystuck_handler` arranca ni qué hace.
- La hipótesis del autor —*«tal vez se soluciona evitando que salte tanto»*— es razonable y **no está
  medida**. `canRunOnPath` veta correr `isInTheMiddleOfJump`, así que `runsafety 1` toca el borde de
  este caso, pero **no hay evidencia de que lo prevenga** y no hay que darlo por arreglado.

### Dos cosas del autor que son diseño, no defectos

- **`phasedoors 2` es la palanca de dificultad más grande medida hasta ahora**, e independiente de
  todo lo demás: *«con `phasedoors 2` es más difícil de escapar definitivamente»*, mientras que entre
  `runsafety 0` y `1` no notó diferencia de dificultad. Dato directo para los 30 tipos (§5, §12.2):
  atravesar es lo que separa un fantasma fácil de uno que no tiene puerta que lo pare.
- **El bucle central ya funciona sin nada de atmósfera.** Sin efectos, sin audio, sin cordura:
  *«ya es tenso escapar… me escondo detrás de muros o props y el bot pasa de largo o trata de ver
  cómo alcanzarme»*. Que esconderse funcione es §18 andando sin haberse escrito.

### El defecto del instrumento, y es mío

**`peor` lo imprime `phantasmagoria_ghost_doors`, y ese comando no decía en qué posición estaba
`runsafety`** — el interruptor sólo se veía en `phantasmagoria_ghost_speed`. Las dos mitades de una
misma comparación en dos pantallas distintas: así se pierde un A/B. Peor, deja sin saber si la fila
03 corrió con el veto puesto o no, porque el autor nunca volvió a `runsafety 1` y nada en la salida
de `_doors` lo dice.

Arreglado: `peor` sale ahora con `[ runsafety N: … ]` pegado al lado.

**Y uno más, chico y del mismo color:** el reporte que genera la planilla r7 se identificaba a sí
mismo como *«ronda 6»* — el título del reporte se reemplaza junto con el array de checks y se me
pasó. Dos rondas distintas archivadas con el mismo encabezado. Arreglado.

**Falta:** re-correr **sólo la fila 02**, con las dos mitades y con `intentos > 0` en cada una. La
planilla ya trae la receta exacta. Las filas **05** y **06** no se pudieron revisar acá: el reporte
llegó cortado antes de sus notas.

---

## Lo que la ronda 7 midió — lo escrito antes de correr

Salió entera de la revisión y de lo que la ronda 6 midió.

| Qué entró | Dónde | Fila |
|---|---|---|
| **`ShouldRun` cazando respeta `canRunOnPath`** | `server_speed.lua` | **01 · 02** |
| A/B del anterior: `phantasmagoria_ghost_runsafety 0` devuelve el defecto exacto de la ronda 5 | `server_speed.lua` | 02 |
| **Se retiraron `fasesPorAtasco` y `reabrio`**, con el porqué escrito donde vivían | `server_doors.lua` | 03 |
| **El silencio arrastra a la hoja hermana** de una puerta doble (`slavename` + la búsqueda inversa, cacheada por puerta) | `server_doors.lua` | 04 |
| `phantasmagoria_ghost_doors dobles`, para que la fila 04 tenga una precondición **medible** | `server_doors.lua` | 04 |
| `testdoor` se niega si el fantasma no puede abrir | `server_doors.lua` | 05 |
| El bot manejado por un jugador vuelve a respetar la tecla de sprint | `server_speed.lua` | — |
| Guarda en el reporte de velocidad sobre `sv_bm_speed_walk` / `_slowwalk` | `server_speed.lua` | 06 |
| Se fueron `silenced`, `ReadDoor`, `PhaseMask`, `phantom_PhaseWhy`, `phantom_OpenWhy` | `server_doors.lua` | 06 |

**El más caro es el primero, y la causa fue citar media función.** El comentario que justificaba el
`return true` pelado cita la primera línea de `canDoRun` —la de *«te ve y camina»*— y se detiene ahí.
La segunda es `if not myTbl.canRunOnPath( self, myTbl ) then return end`, y esa se niega a correr por
**nueve motivos más**: acantilado, `NAV_MESH_CROUCH`, curvatura > 0,45, pendiente confinada (*«can
get us stuck in the ceiling»*, dice la base), obstáculo cerca, mitad de un salto, y **el navarea
siguiente con lado menor a 25 u, que es la medida de un vano de puerta**. *Un override que anula una
regla tiene que anular esa regla, no la función que la contiene.*

> **Y el arreglo se escribió por lectura, no por medición.** Por eso la fila 02 pide el número —`peor`
> con `runsafety 0` contra `runsafety 1`— y su criterio de FALLA dice explícitamente que si no
> mejora, el rojo es **de la justificación** y vale igual.

**Sigue abierto y sin tocar:**

- `doorAhead` traza con `MASK_SOLID` sin filtro, así que cualquier cosa delante de la puerta (un
  prop, un jugador) se lleva el hit y el bloque entero deja de ver la puerta — incluido el
  cronómetro.
- El cronómetro se resetea al cambiar la puerta del sondeo: si el hull alterna entre dos hojas, nunca
  llega a `FORCE_AFTER` y los peldaños 2 y 3 quedan inalcanzables sin un solo error.
- `ResolveFlag` vive en `server_doors.lua` y lo consume `server_speed.lua`, que carga antes. **Se
  difirió a propósito:** es un movimiento de cero comportamiento, y meterlo en la misma ronda que un
  cambio de marcha convierte un rojo en un misterio.
- Cazando y de cerca, el fantasma **orbita** en vez de cerrar (`movement_duelenemy_near`). Es la base
  y es comportamiento de terminator armado; va con el bloque de la cordura.

### Estado por pieza, en una línea cada una

| Pieza | Estado |
|---|---|
| Velocidad derivada del jugador | **CERRADA en juego** — `objetivo` = `sv_bm_speed_run` × multiplicador |
| Atravesar puertas | **CERRADO en juego** — `peor` 3,6 s → 0,7 s, control y máscara confirmados |
| Abrir + huella + destrabar | **CERRADO en juego** — `ABRIO` acompaña a `intentos`, huellas con expiración |
| El veto (`opendoors 0`) | **CERRADO en juego** — `VETADAS` sube; alcanza también a la base |
| Flags por comando | **CERRADO en juego** — sobreviven al respawn, el reporte nombra la capa que ganó |
| Correr cazando | **CORRE en juego**; falta confirmar que el que *camina* camine también sin verte |
| **Silencio de puertas** | **CERRADO en juego (ronda 6)** — por keyvalues, con dos call sites: la escalera y `TerminatorBlockUse`. 11 de 42 ventanas fueron aperturas de la BASE |
| Rescate de la hoja abierta | **RETIRADO de hecho** — `fasesPorAtasco` = 0 siempre y no puede subir: la cercanía llega antes. La trampa existe y **la cercanía sola la resuelve** (`peor` 5,2 s → 0,9 s) |

### Las cinco reglas que costaron una ronda cada una

Están escritas en el código, en el archivo donde muerden. Se repiten acá porque son lo que hay que
tener presente **antes** de tocar nada:

1. **Una ConVar y un ConCommand no pueden compartir nombre**, y el que pierde es el comando, en
   silencio. Todo comando pasa por `PHANTASMAGORIA.AddCommand`, que se niega y grita.
2. **Apagar nuestra implementación no es apagar el comportamiento** cuando el tercero también lo
   hace. La base abre puertas sola; el veto va en su hook público `TerminatorBlockUse`.
3. **Un campo pisado por un método homónimo** con un default que coincide con lo esperado **da un
   check verde**. Hay guarda al final de `server.lua`, y corre *después* de los includes.
4. **`RunTask` corta en el primer valor no-`nil`, y `false` no es `nil`.** `MyClassTask` sirve para
   eventos que nadie más consume; para los que la base ya implementa, va el override de método.
5. **`GM:EntityEmitSound` server-side no ve los sonidos del engine.** El silencio de una puerta se
   hace borrándole sus **siete** keyvalues, no interceptando.

### Lo que sigue, en orden

1. Correr la **ronda 6** y cerrar el silencio.
2. **La cordura (§19)**, que es la que tiene que reemplazar al andamio `phantasmagoria_hunt`. Es el
   bloque grande que queda antes del motor de tipos.
3. Pendiente menor: cerrar `veldoors-r1` como planilla (nunca se llenó; su A/B de la fila 12 quedó
   sin correr).

> ⚠ **Hay otro chat trabajando sobre este mismo repo.** En el árbol quedó
> `lua/autorun/server/phantasmagoria_ghostmodel.lua` sin trackear, que **no es de esta sesión** y no
> se commiteó. Stagear siempre rutas explícitas.

---

## Dónde está parado esto

**El proyecto dejó de ser papel el 2026-08-05: el fantasma camina en GMod.** Hay investigación
exhaustiva de la base, un diseño completo, la tabla de los 30 tipos generada desde datos reales del
juego, y **una entidad que existe, spawnea del menú, camina y te persigue**, verificada en **tres
corridas sobre dos mapas**.

**El 2026-08-06 se le escribió el primer comportamiento propio: el interruptor fantasma/cazador, y
CORRIÓ.** Fuera del hunt deambula y no ataca; dentro, caza. **6 de 10 filas en verde, 4 sin correr,
0 rojos** — y §3.1 del diseño quedó **refutado en juego**, con su control disparado un segundo antes.
Sigue sin haber máquina de estados, ni tipos, ni cordura.

Lo que existe:

| Pieza | Estado |
|---|---|
| Investigación de la base Terminator | **CERRADA** — 55k líneas leídas, 1.042 APIs auditadas |
| Diseño del motor de rasgos | **CERRADO** — [docs/](docs/PHANTOM_Phasmophobia_Diseno.md) |
| Tabla de los 30 tipos | **GENERADA** — `lua/phantasmagoria/ghost_types.lua`, valida sintaxis |
| Conversión de audio | **HECHA** — 265 archivos, 141 MB → 11 MB |
| Catálogo de audio | **CERRADO** — 265/265 identificados y por acción ([§7.2](docs/PHANTOM_Phasmophobia_Diseno.md)) |
| Diseño de spawn / dificultad / cuartos | **CERRADO** — §12, §13, §14 del diseño |
| Zona segura / esconderse / hunt no determinista | **CERRADO** — §18; corrige dos filas de §2 |
| Percepción: las **6** rutas por las que el bot te ubica | **CERRADO** — §18.7; el arreglo son **dos campos**, no uno |
| Cordura: tasa, ámbito, oscuridad, camión | **DISEÑADO** — §19; falta la forma de la capa NEAD (§19.5) |
| **Props de equipamiento** | **EN EL ÁRBOL** — 36 modelos verificados, 0 referencias rotas |
| Detector de addons duplicados | **ESCRITO** — `lua/autorun/phantasmagoria_assetcheck.lua` |
| Entidad `terminator_nextbot_phantom` | **CORRIENDO EN JUEGO** — `lua/entities/terminator_nextbot_phantom/`, 3 archivos. Check de 5 filas **cerrado en verde** |
| Interruptor fantasma / cazador | **CERRADO EN JUEGO** — el primer comportamiento propio. Tabla de 10 filas (6 verdes) + planilla de 8 (7 pasa, 1 falla), y la falla **cerrada en la corrida 8**. §3.1 **refutado en juego** |
| Velocidad derivada del jugador (§1.1) | **ANDA EN JUEGO, sin planilla** — `objetivo 280`, `deseada 66/280`. Medido por consola, no llenando `veldoors-r1`: las filas siguen sin marcar |
| Las puertas: abrir y destrabar | **ABRE Y DESTRABA, pero NO ALCANZÓ** — `peor 3,6 s` contra un `func_door_rotating` (fila 11 de `veldoors-r1` en **rojo**, que es lo que estaba escrita para hacer) |
| Las puertas: **atravesar** | **CERRADO EN JUEGO** — `atraviesa-r2`: **7 pasa / 2 falla**, `peor` 3,6 s → **0,7 s**, control negativo y máscara confirmados. Las 2 fallas eran **un defecto del instrumento**, no del mecanismo |
| Los flags de puerta (abrir / silencio) | **CORRIDOS Y ROJOS** — `flags-r3`: 3 pasa / 5 falla. Ninguna falla era del mecanismo: 4 instrumento + 1 hueco de diseño. Todas arregladas, sin correr |
| ⚠ Colisión ConVar/ConCommand | **ARREGLADA Y BLINDADA** — `PHANTASMAGORIA.AddCommand` se niega y grita si el nombre ya es convar. Costó **dos filas** de la ronda 2 |
| ⚠ El veto de apertura no cubría a la base | **ARREGLADO** — `TerminatorBlockUse`. *Apagar lo nuestro no apagaba el comportamiento*: la base abre puertas por su cuenta |
| Andamio para mover flags en juego | **CERRADO EN JUEGO** — `phantasmagoria_ghost_flag`; el reporte nombra la capa que ganó (override / campo / convar) |
| El veto de apertura | **CERRADO EN JUEGO** — `veto-r4`: con `opendoors 0` las puertas no se abren y `VETADAS` sube (161 en una corrida) |
| Correr cazando | **CERRADO EN JUEGO** (`silencio-r5`) — el flag ya es legible y el reporte dice quién decidió la marcha. Falta que el que camina camine **también sin verte**: arreglado, sin correr |
| El silencio de las puertas | **MECANISMO CAMBIADO ENTERO** — el hook `EntityEmitSound` está **ciego** server-side (bitácora vacía). Ahora se le borran a la puerta sus 7 keyvalues, como hace `Immersive Door Openable`. Planilla `phantasmagoria-keyvalues-r6`, 6 filas |
| ⚠ Riesgo nuevo: puertas mudas | El silencio **borra un dato del mapa**, no bloquea un sonido. Hay contador de *puertas mudas ahora mismo*, un `devuelto` por cada `silenciado`, y `phantasmagoria_ghost_doors restore` |
| Sistema de cuartos + toolgun | **NO EXISTE** — diseñado en §14 |
| SWEPs / entidades de equipo | **NO EXISTEN** — los modelos ya están, falta el Lua |
| Corridas en GMod | **10** (2026-08-05 ×3; 2026-08-06 ×5; 2026-08-07 ×2) — refutaron **dos** predicciones del documento y **una lectura mía sobre la causa del giro**; destaparon **16** defectos: **15 del instrumento y 1 del fantasma**. Los dos últimos son de la ronda 7 y los dos míos: `peor` se imprimía sin decir de qué lado del A/B estaba, y el reporte de la planilla r7 se llamaba a sí mismo «ronda 6» |
| La marcha cazando (`canRunOnPath`) | **CERRADA EN JUEGO por criterio del autor** — el veto se ve (`deseada` 252 → 60) y el A/B observacional es limpio: con 1 camina en escaleras y cerca de objetos, con 0 corre para todo. **Nadie midió que prevenga un atasco**, y así hay que leerlo |
| ⚠ Salta y queda encajado contra el techo | **DEFECTO ABIERTO, el primero que necesita physgun.** Sin instrumento y sin check. `reallystuck_handler` existe, está registrado y no rescató |
| **El silencio de las PISADAS** | **CORRIDO — 4 de 8 cerradas.** La restricción del autor **CERRADA en juego**: 39 pisadas calladas y publicadas al consumidor. `PERDIDAS 0`. Las otras cuatro se marcaron verdes sin la medición que pedían (una con su rojo escrito en la nota); re-corrida en `pisadas-r8b` |
| La hoja hermana de una puerta doble | **CERRADA EN JUEGO** — `gm_prison`, ronda 7: `silenciado ( hermana )` y su `devuelto`, 5 campos cada uno |
| El silencio de las puertas | **CERRADO EN JUEGO** — ronda 6, al quinto intento y con el tercer mecanismo. Ver «Ronda 6 corrida» |

---

## **Velocidad** y **puertas** — ESCRITO, sin correr

**El bloque ya está escrito** (2026-08-06): `server_speed.lua` y `server_doors.lua`, colgados de
`ENT.MyClassTask`. La planilla es [`dev/checks/phantasmagoria-veldoors-r1.html`](../dev/checks/phantasmagoria-veldoors-r1.html)
— **14 filas, ninguna corrida**. Lo que sigue es la lectura de la que salió, que se conserva porque
es lo que hay que releer si algún check sale rojo; **la decisión de las puertas cambió** y está al
final de esta sección.

### A. La velocidad — hay un hook declarado, no hace falta overridear nada

**El problema, medido en juego:** el fantasma corre a **550 u/s** y camina a **130** (se ve en
`marcha loco 550 u/s` de las corridas 7 y 8). La carrera del autor con Better Movement es **280**, o
sea **1,96×**. §1.1 del diseño manda lo contrario: la velocidad se **deriva** de la carrera real del
jugador, y los 30 tipos son **multiplicadores** sobre ella, para que el addon se calibre solo en
cualquier servidor.

**De dónde salen esos números:** `ENT.RunSpeed = 550`, `ENT.MoveSpeed = 300`, `ENT.WalkSpeed = 130`
(`shared.lua:130-132`, con el comentario del autor de la base *«bit faster than players... in a
straight line»*). El fantasma no los pisa.

**El punto único donde se aplican, y el hook que evita tocarlo:**
`SetupSpeed` (`motionoverrides.lua:3785-3807`) elige entre `RunSpeed`/`WalkSpeed`/`MoveSpeed`/
`CrouchSpeed` y **después** hace:

```lua
speed = myTbl.RunTask( self, "ModifyMovementSpeed", speed ) or speed
myTbl.loco:SetDesiredSpeed( speed )
```

**`ModifyMovementSpeed` es un callback de tarea y su único call site es ése** — o sea que es el
punto de extensión declarado para escalar la velocidad **sin overridear `SetupSpeed`**. Lo llama
`BehaveUpdate` cada tick (`behaviouroverrides.lua:110`).

**La trampa de Better Movement, ya verificada contra su código:** `ply:GetRunSpeed()` **no sirve** —
lo multiplica por `_bmfraction`, un factor dinámico clampeado 1..2, así que devuelve entre 280 y 560
**según el instante**. Hay que leer la convar base **`sv_bm_speed_run`**, y
`GetConVar( "sv_bm_enabled" ) == nil` es el chequeo de existencia del mod. Sin Better Movement montado
tiene que haber camino propio.

**Y una que puede volver a subirla por atrás:** `overcharging.lua:20-22` hace
`self.RunSpeed = math.max( self.RunSpeed * 1.40, 550 )` — un piso de 550 metido a mano. Si el
overcharge se dispara alguna vez, se lleva puesta la conversión.

### B. Las puertas — la hipótesis más fuerte es **la otra mitad de la trampa ⑦**

**El síntoma, reportado por el autor:** *«suele quedarse pegado abriéndolas»*. **Sin medir todavía.**

**La pista, y hay que medirla antes de creerle:** `ENT.TERM_FISTS = false` apaga **dos** cosas que no
son el puño (Referencia §4.4⑦). La primera —*no mira hacia su objetivo al moverse*— **ya mordió esta
sesión** y fue el defecto del giro. La segunda es
`tryToHitUnstuck = isstring( myTbl.TERM_FISTS )` (`shared.lua:2142`, usado en `:2151`): **sin puños
el bot no pega para desatascarse.** Y en el manejo de puertas, las dos ramas que abren a golpes piden
`isFists` explícitamente (`shared.lua:1336` para la trabada, `:1340` para la que se atascó):
**las dos están muertas en nuestro fantasma.** Una puerta cerrada con llave no tiene salida.

> **Es hipótesis, no diagnóstico**, y esta sesión ya mostró por qué importa la diferencia: culpé al
> gate de `TERM_FISTS` por el giro y **era la mitad equivocada** (había un segundo candado de 30 u/s).
> Antes de tocar nada: reproducirlo con `phantasmagoria_ghost_where` al lado, que ya imprime `mira`,
> `marcha` y `pos`, y mirar si se queda **quieto** contra la puerta o **empujando**.

**Descartado por lectura, para que nadie lo persiga:** el interruptor **no** es la causa. La rama que
mi `ShouldBeEnemy` hace tomar siempre (`shared.lua:1387`) está **después** de la rama propia de
`prop_door_rotating` (`:1334`), que es la puerta común de GMod y gana antes. Sólo afecta a otros
bloqueadores.

### La elección que este documento dejaba abierta, ya tomada por el autor

Decía: *un fantasma de Phasmophobia **atraviesa** las puertas, así que «arreglar el bashing» y
«dejarlo pasar» son dos diseños distintos y hay que elegir cuál.* **La respuesta del autor fue una
tercera, y es mejor que las dos:** ni atravesar ni romper — **abrir**. *«Lo único importante es que
pase las puertas; cuando lo haga, que la active y la abra físicamente, eso deja la evidencia de la
huella en la puerta.»*

Atravesar habría sido lo más barato de programar y **regala la huella**, que es una de las 7
evidencias y la tienen 13 de los 30 tipos. El bashing queda descartado con lo suyo sin usar
(`terminator_doorbash.lua`, `ENT:CanBashLockedDoor` en `shared.lua:2330`, `ENT:BashLockedDoor` en
`:2344`).

**Y la hipótesis de arriba no se dio por buena.** *«Suele quedarse pegado abriéndolas»* sigue **sin
medir**, así que el código trae un cronómetro (`phantom_doorBlocked`) que corre **aunque la convar
esté apagada** y que anota **contra qué** se trabó: una puerta *cerrada* es lo que este bloque
arregla; una *abierta encima suyo* no, y en ese caso el arreglo no sería el arreglo. Los checks 11 y
12 de la planilla son esa medición y su control.

**Límite declarado antes de correr:** una `prop_door_rotating` con llave marca como **bloqueado** el
navarea de abajo (lo dice la base en `shared.lua:657`), así que el camino puede evitarla y el
fantasma no llegar nunca a tocarla — y el destrabado, que es por contacto, no se dispara. El check 10
está escrito para separar ese caso («nunca la tuvo delante») de uno nuestro («la tuvo delante y no
destrabó»).

---

## Abrir no alcanzó: ahora **atraviesa**, y es un flag por NPC

La corrida del autor (por consola, no con la planilla) dejó la velocidad andando —`objetivo 280`,
`deseada 66` caminando y `280` corriendo— y **`peor 3,6 s` contra un `func_door_rotating`**. La fila
11 hizo exactamente lo que estaba escrita para hacer: convirtió *«suele quedarse pegado»* en un
número **y nombró la clase**, que es lo que cambia el diagnóstico.

**Y la clase destapó un defecto propio:** `OpenAwayFrom` es entrada de `CBasePropDoor`, o sea **sólo
`prop_door_rotating`**. Sobre un `func_door_rotating` el `Fire` no hace nada y no avisa — el peldaño 2
de la escalera se consumía entero sin tocar la puerta. Corregido.

Lo nuevo es `ENT.phantom_PhasesDoors` (no una convar: el Alternate no puede atravesar, y los 30 tipos
lo heredan en `true` sin escribir nada), con `phantasmagoria_ghost_phasedoors` de tres estados para
el A/B. **El mecanismo tiene dos precedentes en el árbol** —`wraithcloaking.lua:133` y HIM
`server.lua:630`, los dos con `SetSolidMask`— **y usan máscaras distintas**: difieren en
`CONTENTS_MOVEABLE`, el bit de los brush entities, o sea de la puerta que efectivamente lo trabó. Va
`MASK_NPCWORLDSTATIC`, la de HIM.

**Atravesar y abrir siguen siendo dos cosas y las dos están prendidas:** atravesar garantiza que
*pase*, abrir es lo que deja la *huella*.

---

## Ronda 2 CERRADA: atraviesa. Y el defecto que costó las dos filas que fallaron

`peor` bajó de **3,6 s a 0,7 s**, el control negativo volvió a trabarlo, y la máscara quedó medida
**por su efecto** (con la del wraith puesta a propósito, *«sí se queda pillado en la puerta del
brush»*) — así que `CONTENTS_MOVEABLE` es el bit que decide, por medición y no por citar la constante.

**Las dos fallas tenían una sola causa y era mía: `phantasmagoria_ghost_doors` era a la vez convar y
comando.** La consola resuelve convars primero, así que el comando quedó **mudo** — sin error, sin
aviso. El instrumento de puertas fue inalcanzable toda la ronda (de ahí *«¿dónde veo el dato de la
evidencia?»*), y la propia planilla mandaba correr `phantasmagoria_ghost_doors reset`, que en vez de
limpiar contadores le ponía **0** a la convar y **apagaba la apertura justo antes de medirla**.

*Una ConVar y un ConCommand no pueden compartir nombre, y el que pierde es el comando, en silencio.*
Vale para todo el taller de GMod. Arreglado con `PHANTASMAGORIA.AddCommand`, que se niega y grita, y
censadas **las siete convars y los seis comandos**.

Entran además los dos flags pedidos —`phantom_OpensDoors` y `phantom_SilentDoors`— con la misma
convención que `phantom_PhasesDoors`. **El silencio son dos sonidos distintos:** el click del bot
(que se apaga adelantando el debounce que la propia base consulta) y el chirrido de la hoja (que lo
emite el **engine**, y sólo se puede interceptar con `EntityEmitSound` — eso es lectura, no medición).

---

## Ronda 3: 5 rojos, y ninguno era del mecanismo que el check decía medir

**El que ordena a los demás:** con `opendoors 0` el instrumento decía `abre NO` y el fantasma seguía
abriendo — y las dos cosas eran ciertas, porque **la base abre puertas por su cuenta**
(`tryToOpen` → `Use2`, disparado por `ShootblockerThink` cada 0,1 s). *Apagar nuestra implementación
no es apagar el comportamiento cuando el comportamiento también vive en el tercero*, y el modo de
falla es el más caro: **el instrumento decía la verdad sobre lo nuestro mientras el juego mostraba
otra cosa.** El veto va ahora en `TerminatorBlockUse`, el hook que la base declara adentro de `Use2`.

Los otros cuatro, en una línea cada uno:

- **`ABRIO 0 fallo 3`** con las puertas abriéndose a la vista: leí un estado **transitorio** como
  final, y el propio reporte lo tenía escrito al lado (*«en movimiento»*).
- **«Todavía no vio ninguna puerta»** viéndolas: el `return` temprano se llevaba el instrumento junto
  con la función, así que *«no vio»* y *«vio y se abstuvo»* daban el mismo cero.
- **El silencio seguía sonando**: la ventana de 1,5 s se cerraba **antes del golpe de llegada**. Son
  3 s, y hay bitácora porque *«sigue sonando»* no dice **quién** suena.
- **Los flags no se podían probar**: el `lua_run` escribe en la entidad y **se pierde al respawnear**,
  sin que nada lo diga. *Un andamio de prueba tiene que sobrevivir al ciclo de vida de lo que prueba.*

Y entró lo de la fila 09: **cazando corre**. La causa estaba medida en la base — `canDoRun` se niega
si el bot no está enojado, te ve, y tiene la vida entera; las tres se cumplen siempre en un hunt
normal. Va con `phantom_WalksWhenHunting` para los tipos que acechan caminando.

---

## Ronda 4: 9 verdes. Las dos fallas no eran del mecanismo

Quedaron confirmados en juego los cinco arreglos de la ronda 3. Las dos que fallaron:

- **Un campo pisado por un método del mismo nombre.** `ENT.phantom_WalksWhenHunting` era campo y
  método a la vez; como los `include` corren después, la función ganaba y el resolvedor leía una
  función creyendo que el flag no estaba declarado. Se veía en **cada línea** del reporte
  (`campo = function: 0x8088…`) **y el check pasó igual**, porque el default de esa rama coincidía
  con lo esperado. *Un default que coincide con lo esperado convierte un campo roto en un check
  verde.* Hay guarda, y corre **después** de los includes: antes, el pisado todavía no ocurrió.
- **El silencio sigue sin medirse, tres rondas.** No es que falle: **no se corre**. La precondición
  pedía que un fantasma silenciado abriera una puerta justo mientras el autor escuchaba. *Un check
  cuya precondición no se puede provocar no es un check* — y marcado como FALLA se lee como un
  mecanismo roto. Hay botón: `phantasmagoria_ghost_testdoor`.

Y una corrección de método: **`ShouldRun` dejó de ser un callback de tarea porque era una carrera.**
`RunTask` corta en el primer callback no-nil y el de `movement_followenemy` devuelve **`false`**
(no `nil`) cuando el path es corto — o sea cuando ya te alcanzó. Ganar dependía del orden de las
tareas, que ni siquiera es estable. *Un punto de extensión que depende del orden de ejecución no es
un punto de extensión.* Ahora se overridea el método y se encadena.

---

## Ronda 5: el silencio falló por cuarta vez, y por fin con veredicto

**La bitácora salió VACÍA** con la ventana abierta, la puerta abriéndose y el sonido oyéndose — no
registró ni un sonido bloqueado ni uno sin bloquear. *Un log vacío donde tenía que haber algo vale
más que uno lleno: descarta la familia entera de hipótesis, no una.* `GM:EntityEmitSound`
**server-side no ve** esos sonidos, porque no nacen en Lua del servidor.

**El camino bueno lo señaló el autor** y su aporte no es código: son **siete nombres de keyvalue**.
`Immersive Door Openable` (WSID `3717549037`, desempacado en `dev/other/`) no engancha nada — le pisa
a la puerta sus propios campos de sonido con `""` antes de moverla y se los devuelve después. Así el
sonido **no llega a existir**. `noise1`/`noise2` para `CBaseDoor` y los cinco `sound*override` para
`CBasePropDoor`, y `noise2` es el **golpe de llegada**: justo el que se venía oyendo desde la ronda 3.

**Riesgo nuevo, y es de otra clase:** ya no bloqueamos un sonido, **borramos un dato del mapa**. Una
puerta que no recupere sus valores queda muda para todos, para siempre.

Y dos observaciones del autor que eran diseño: que el que camina cazando **corría al perderte de
vista** (yo dejaba decidir a la base, que sólo se niega a correr cuando te ve), y el rescate de la
**hoja que se abre encima** —17,6 s clavado— con su condición: sólo si la puerta está **ABIERTA**.

---

## El próximo paso concreto

> ⚠ **ESTA SECCIÓN ESTUVO VENCIDA VARIAS RONDAS Y APUNTABA A TRABAJO CERRADO** (2026-08-08). Decía
> *«correr `keyvalues-r6`»* — que es la **ronda 6, corrida el 2026-08-07** y documentada más arriba en
> este mismo archivo. *Una sección que dice qué hacer después envejece más rápido que una que dice qué
> pasó, y se lee primero.* Si vuelve a quedar así, el síntoma es el mismo: manda a hacer algo que ya
> tiene su bloque de resultados arriba.

**1 · El bailout nunca disparó, y está prendido por default.** `phantasmagoria_ghost_stuckbailoutsecs`
está en **20 s** y el contador leyó `disparados 0` en la **r10, la r11 y la r12** — las tres. En la r12
el A/B no discriminó porque **el fantasma se escapó solo en las dos mitades**, así que el mecanismo
sigue **sin haberse observado nunca**. Es un teleport que le va a pasar a un jugador algún día en una
situación que nadie vio. El bloqueante no es código: es que **desde la r10 nadie logró volver a
encajarlo de verdad**, y sin la mitad rota no hay A/B.

**2 · Dos residuales chicos, que no merecen ronda propia** — se cuelgan de la próxima que toque el
tema: `congelada 5 de 117` en calma contra un criterio de `0` (r13b; candidato, el hueco del facewalk
cuando el bot no está en el piso), y **cuánto tarda en soltarte** con `sightdist` puesto (r14, fila 05:
la fila lo pedía y trae una sola lectura ya del otro lado).

**3 · La cordura (§19) — ARRANCADA. La tajada A está ESCRITA y lo único que falta es correrla.** Todo
lo de las últimas cuatro rondas fue sobre cómo se **comporta** el hunt; la cordura es la que **decide
cuándo** empieza, y reemplaza al andamio `phantasmagoria_hunt` (que queda de test). **Se decidió el
2026-08-08, con el autor:**

- **Drenaje por CAUSAS, sin reloj de fondo.** No hay goteo constante: la cordura baja por oscuridad
  (§19.4), cercanía del fantasma y cacerías. *Si no pasa nada, no baja nada.*
- **Va en tres tajadas, en este orden:** **A · el tipo del fantasma** → **B · la cordura** por
  jugador, servidor, networkeada, con sus causas e instrumentos → **C · el gatillo**, cordura bajo el
  `hunt.threshold` del tipo → `phantom_SetHunting( true )`, con su A/B.
- **Sólo `hunt.threshold` en la tajada A.** `thresholdLow`/`thresholdHigh` (12 de los 30 tipos) es un
  rango condicional por tipo (§5.2) y es de después. El comando los imprime marcados como no usados:
  a la vista, sin parecer implementados.

**Lo pendiente ahora, en orden:**

1. ✔ **La tajada A está CERRADA en juego** (r15 8/9 + r15b 6/6). Lo que queda del bloque son **tres
   residuales chicos, sin ronda propia**, que se cuelgan de la próxima que toque el tema:
   - **`phantasmagoria_ghost_cl` no se corrió nunca** — es el comando cliente que entró *después* de
     la r15b, justamente para que la fila del networkeo pueda dejar registro. Una línea de check.
   - **La rama corregida de la etiqueta de la mirada no se ejerció** (hace falta leer dentro del
     primer segundo tras frenar: ventana más corta que el trámite de tipear, va con muestreador).
   - **«Al fantasma vivo no se le borra el tipo»** sigue sin medirse: las dos corridas trajeron un
     solo fantasma en la salida.
2. **Enganchar `speed.base` (§5)**, que es una línea y ya tiene los dos lados: el campo
   `phantom_SpeedMul` gana sobre la convar andamio y el instrumento de velocidad ya imprime **de
   dónde salió el multiplicador**. Con su planilla, porque **sí** cambia comportamiento.
3. **La INVISIBILIDAD** — pedido del autor (2026-08-08): que el fantasma aparezca sólo en hunt y en
   eventos. Prompt escrito y autocontenido en
   [`dev/PROMPT_phantasmagoria_invisibilidad_y_speed.txt`](../dev/PROMPT_phantasmagoria_invisibilidad_y_speed.txt),
   que lleva también el punto 2. Lo esencial, para que no se pierda si el prompt se traspapela:

   > **Son DOS mecánicas y no una.** ① **La ausencia** fuera del hunt (invisible, puede ser no sólido,
   > dura minutos) es lo que la base regala con `ENT.IsWraith = true`. ② **El parpadeo** durante el
   > hunt (décimas de segundo) **no es cloak: es sólo render**, porque en hunt el fantasma tiene que
   > seguir siendo **sólido** — uno que se vuelve intangible cada 0,2 s no puede alcanzarte.
   >
   > ⚠ **Y el módulo de la base NO puede hacer ②:** `DoHiding` pone `+ math.Rand( 2.5, 3.5 )` al
   > materializarse (`wraithcloaking.lua:164`), y el ciclo entero de Phasmophobia —visible 0,08-0,3 s,
   > invisible 0,1-1,0 s— **dura menos que ese cooldown solo**. Encima se niega en silencio con un
   > `return` pelado (`:128`). *No es un parámetro a considerar: es una incompatibilidad en el único
   > rango que importa*, y la Referencia §5.3 —que decía «tener en cuenta»— quedó corregida.
   >
   > ⚠ **El marcador de debug pasa a ser un wallhack.** `phantasmagoria_debug_ghost` está en **1** por
   > default y dibuja con `IgnoreZ`: desde este bloque es lo único que te dice dónde está un fantasma
   > que el diseño quiere invisible. Cualquier corrida con eso en 1 **no mide la mecánica, la tapa.**
4. **La tajada B**, la cordura por jugador.
5. **Las masas y los materiales de las otras 19 familias** — la r15b probó cinco modelos de tres.

### 4 · Los 66 modelos propios pesan todos lo mismo y suenan a chapa **[medido, 2026-08-08]**

La fila 02 mandaba pesar el crucifijo del **Prop Pack de terceros**, y el autor contestó lo que
convertía la fila en otra cosa: *«no usar los modelos demit, solo los nuestros pues los estamos
cambiando»*. **La fila no estaba sin correr: estaba sin sujeto.**

Medidos los `.phy` de `models/phantasmagoria/eq/` — **los 66 traen `mass 1.5` y `surfaceprop metal`**,
que es el default del `.qc` sin ajustar. Los del árbol raíz (`candle`, `ouija_board`, `musicbox`,
`haunted_mirror`, `monkeypaw`) **sí** están ajustados uno por uno (`wood`, `paper`, `glass`, `flesh`,
`cloth`), así que no es descuido general: es que el lote de equipamiento nunca pasó por ahí.

> **No es la tonelada del Prop Pack.** Aquel era un tercero clavando 1000 kg; éste es *nadie les puso
> todavía el número*. El síntoma tampoco es el mismo: no es que no se puedan levantar, es que **la
> sal, las pastillas y el cuaderno pesan lo mismo y suenan a chapa**.

Entró **`lua/phantasmagoria/prop_data_eq.lua`**, generado por `dev/gen_eq_propdata.py` **desde los
`.mdl` reales** (los nombres salen del disco, no de la memoria; el generador se niega si algún modelo
no cae en ninguna de las 20 familias). Las masas se copian de las que `prop_data.lua` ya tenía
decididas donde existe el equivalente, y el resto sale del objeto con el piso de 0,2 kg que ese mismo
archivo documenta. ⚠ **Los números son una propuesta para que el autor los corrija.**

**Archivo aparte, y por un motivo de coordinación, no de estilo:** las entradas de los packs de
terceros las va a **retirar otra sesión** cuando termine de reemplazar los modelos. La división es
por **procedencia** —lo nuestro en `prop_data_eq`, lo ajeno en `prop_data`— y en runtime se fusionan
en un solo diccionario, así que `ApplyPropData` sigue leyendo un solo lugar.

⚠ **El re-escalado que viene NO invalida estos números**, aunque parezca que sí: el autor va a
cambiarle el tamaño a los modelos, y la masa que Source calcula sola **sí** depende del volumen — pero
`PhysObj:SetMass()` la **clava**. Esta tabla no se calibra contra el tamaño: lo reemplaza.

⚠ **Y hay un orden de carga que es obligatorio:** `prop_data_eq.lua` **fusiona** sobre
`PHANTASMAGORIA.PropData` y `prop_data.lua` **asigna** esa tabla entera. Al revés, el segundo pisaría
los 66 **sin un solo error**, y el único síntoma sería equipamiento nuestro pesando 1,5 kg. La guarda
del cargador lo mide con una columna que **no cuenta su propia tabla sino cuántas sobrevivieron en la
de destino**: `30 tipos · N modelos ( 66 propios )`.

> ✔ **CERRADO EN JUEGO (r15b):** `84 modelos ( 66 propios )` — el **84 = 18 + 66** prueba la fusión y
> el orden de una sola vez. Y cinco masas corregidas con el `antes` en **1.50 kg en las cinco**, o sea
> que **el censo de los 66 estaba bien medido**.
>
> **Corrección del autor, aplicada:** los crucifijos **II y III son metálicos** (la tabla los tenía en
> `item`). ⚠ **El tier I quedó sin tocar** porque el autor no se pronunció sobre él — en el juego el
> tier 1 es de madera, pero eso es mi lectura y no su decisión. *Una enmienda sobre un eje no autoriza
> a fijar de contrabando el sub-eje que el autor no votó.* **Pregunta abierta.**
>
> **Lo que sigue sin decidirse:** las masas y materiales de las otras 19 familias. Nadie las
> contradijo, pero tampoco las miró una por una: la r15b probó **cinco** modelos de **tres** familias.

✔ **§19.6 estaba vencida y quedó corregida:** decía que faltaba «la decisión de §19.5 — cuál de las
tres formas», y §19.5 ya había decidido (NEAD no se integra). Ahora ese bloque es la tabla de las
tres tajadas con su estado, y los pendientes de verdad se mudaron a §19.7.

**Pendiente menor de papeleo:** `veldoors-r1` nunca se llenó como planilla — los mecanismos se
verificaron por consola, pero el A/B de la fila **12** no se corrió.

---

## El interruptor fantasma / cazador — **CORRIENDO EN JUEGO**

El fantasma arranca en `phantom_Hunting = false` y **no ataca a nadie**; con el hunt prendido vuelve
a ser el cazador que ya sabía ser. El gatillo es **manual y provisorio** —un concommand— porque la
cordura, que es la que debería dispararlo (§4 y §19), todavía no existe.

### ⚠ §3.1 nombra la función equivocada, y hay dos motivos

§3.1 propone `OnFirstRelationWithPlayer` devolviendo `D_HT` o `D_NU`, y dice *«al entrar en hunt se
re-evalúan relaciones y la base hace el resto sola»*. Leyendo el código, **eso no funciona**, por dos
razones independientes:

**① Nada re-evalúa.** `SetupRelationships` corre **una sola vez**, desde `Initialize`
(`shared.lua:3079`). Itera `ents.Iterator()` y registra un hook `terminator_postentitycreated`
(`enemyoverrides.lua:846-869`), que cubre a los que aparecen **después**, no a los que ya estaban.
Por cada entidad llama `SetupEntityRelationship` → `GetDesiredEnemyRelationship` →
`OnFirstRelationWithPlayer` y **guarda** el resultado con `Term_SetEntityRelationship`
(`enemyoverrides.lua:883`, cuerpo en `terminator_nextbot_base/enemy.lua:44-47`). Es un **cache**.
El nombre lo venía diciendo: `OnFirst…`.

**② Y aunque re-evaluara, la relación no aguanta.** `MakeFeud` (`enemyoverrides.lua:1046-1048`)
reescribe la relación del jugador a `D_HT` con prioridad 1000 en cuanto al bot le pegan
(`PostTookDamage`, `damageandhealth.lua:482`), sin preguntarle nada a nadie. **Un interruptor hecho
de relaciones se reabre de un balazo** y no se vuelve a cerrar, porque nada re-evalúa el cache.

**El interruptor de verdad es `ShouldBeEnemy`** — el lugar donde la base **lee** ese cache
(`enemyoverrides.lua:493`) y que se consulta en vivo por seis caminos:

| Quién lo llama | Dónde | Para qué |
|---|---|---|
| `processFindingEnt` (barrido) | `enemyoverrides.lua:596` | ruta 1 de §18.7 |
| `ForgetOldEnemies` | `enemyoverrides.lua:676` | limpiar memoria — **es el que suelta al enemigo** |
| `FindPriorityEnemy` | `enemyoverrides.lua:719` | elegir enemigo |
| el fallback «sin enemigos» | `shared.lua:3203` | ruta 3 de §18.7 |
| revalidar el enemigo anterior | `shared.lua:3282` | continuidad |
| `HaveEnemy` | `terminator_nextbot_base/enemy.lua:136` | la pregunta pública |

Un `false` ahí **no congela nada**: el cerebro sigue corriendo entero y las 31 tareas siguen ahí. Es
literalmente lo que pide la última línea de §3.1 —*«el bot nunca deja de pensar, sólo deja de tener a
quién odiar»*— sólo que en la función de al lado. Y **no** es `DisableBehaviour`.

**Entonces `OnFirstRelationWithPlayer` queda escrito, pero como INSTRUMENTO y no como mecanismo:**
cuenta cuántas veces la base evalúa la relación y con qué flag, y encadena al `BaseClass` (trampa ①:
la implementación default **no está vacía**, implementa `ExtraSpawnHealthPerPlayer`,
`damageandhealth.lua:872`). Devuelve lo que devuelva el `BaseClass` —`nil`—, así que **la relación
del fantasma con el jugador queda en `D_HT` siempre, a propósito**: un `D_NU` ahí trabaría el
interruptor cerrado para siempre, porque la base exige `D_HT` en `:493` y nada re-evalúa el cache.

> **Consecuencia honesta para el check:** como la relación nunca sale de `D_HT`, **el motivo ② no se
> mide en esta corrida** — no hay nada que `MakeFeud` pueda reabrir. Sigue siendo **[lectura]**. Lo
> que la fila 10 sí mide es su **consecuencia práctica**: que el interruptor aguante un balazo. Si
> alguien alguna vez «simplifica» esto a un interruptor de relaciones, esa fila se pone roja.

### Lo que se agregó

```
lua/entities/terminator_nextbot_phantom/
    server.lua    ENT.phantom_Hunting, ShouldBeEnemy, OnFirstRelationWithPlayer,
                  phantom_SetHunting/phantom_IsHunting, y tres comandos
    client.lua    el marcador cambia de color y dice HUNT / calma
```

| Comando | Qué es | Qué hace |
|---|---|---|
| `phantasmagoria_hunt 0\|1` | **ANDAMIO** | mueve **sólo el flag**. Ni relación ni memoria ni tareas — para que la corrida pueda medir qué hace la base sola |
| `phantasmagoria_hunt_reeval` | **CONTROL** | re-dispara `SetupEntityRelationship` a mano. Existe para probar que el contador de la fila 6 **no está roto** |
| `phantasmagoria_ghost_rel` | instrumento | por fantasma y por jugador: el flag, la relación **cacheada**, y el resultado **en vivo** de `ShouldBeEnemy` |

El estado viaja por `SetNWBool`, **no** por `SetupDataTables` (trampa ③: el `Bool 0` ya es
`Crouching`). Son sistemas distintos y no colisionan; la base no usa ningún NW var —grep sobre sus 71
archivos: cero—.

**Un efecto secundario medido en el código, que si no se lee como bug:** `shared.lua:1387` usa
`ShouldBeEnemy` sobre lo que le bloquea el paso —`not ShouldBeEnemy( blocker )` → `openDoorTime`—, o
sea **abrir en vez de romper**. Con el interruptor en fantasma esa rama se toma siempre. Es la que
queremos.

### El check — **criterios escritos ANTES de correr, ninguno corrido**

Precondiciones ya medidas y sin cambios: junction, base WSID `2944078031`, `scaryblackman` **no**
montado → sale `male_04` por el fallback y está bien.

| # | Qué se hace | Verde | Rojo | **C4** `#1066` |
|---|---|---|---|---|
| 1 | Spawnearlo y mirar consola + marcador | consola dice `hunt NO`; el marcador es **violeta** y dice `calma` | dice `hunt SI`, o el marcador es rojo | ✅ `hunt NO`, violeta, `3.9 m calma` |
| 2 | `phantasmagoria_ghost_rel` de una | `ShouldBeEnemy NO` y `enemigo ninguno` para todos los jugadores | `ShouldBeEnemy SI`, o ya tiene enemigo | ⬜ **sin correr** |
| 3 | Quedarse **quieto y a la vista** 30 s | **no se acerca**: la distancia del marcador no baja de forma sostenida | camina hacia vos y la distancia baja | ✅ no se acerca |
| 4 | **La pregunta abierta.** Dos `phantasmagoria_ghost_where` separados ≥ 30 s, con el jugador quieto | la `pos` cambió **> 200 u**: deambula | cambió ≤ 200 u: **se quedó clavado**, y «no te ataca» se volvió «no hace nada» | ✅ **deambula** (a ojo, no por `pos`) |
| 5 | En el mismo `ghost_where`, mirar las tareas | la lista **no está vacía** y sigue apareciendo `movement_handler` | no hay tareas → algo se congeló y saltear fue apagar | ⬜ **sin correr** |
| 6 | **La medición que puede tirar abajo §3.1.** `phantasmagoria_hunt 1` y **nada más**; después `phantasmagoria_ghost_rel` | las llamadas a `OnFirstRelationWithPlayer` **NO subieron** → nada re-evalúa | subieron → la base **sí** re-evalúa, §3.1 tenía razón y se corrige este documento | ✅ **quedaron en 2** → §3.1 REFUTADO |
| 7 | **Control de la fila 6:** `phantasmagoria_hunt_reeval` | las llamadas **suben** (+1 por jugador por fantasma) | no suben → el contador está roto y **la fila 6 no midió nada** | ✅ `1 -> 2` |
| 8 | Con `hunt 1`, alejarse y esperar | **te persigue**: `enemigo Player [N]`, `ShouldBeEnemy SI`, marcador **rojo** con `HUNT` | no te toma como enemigo | ✅ persigue, rojo, `3 m HUNT` |
| 9 | `phantasmagoria_hunt 0` y **nada más** | en **≤ 3 s** `enemigo` pasa a `ninguno` y deja de perseguir | sigue con enemigo pasados 3 s → hay que limpiar la memoria a mano | ⬜ **sin correr** |
| 10 | Con `hunt 0`, **pegarle un tiro** y esperar 5 s | sigue en `enemigo ninguno` y `ShouldBeEnemy NO` | te toma como enemigo → el interruptor no aguanta un balazo | ⬜ **sin correr** |

## Corrida 4 (2026-08-06) — **6 de 10 en verde, 4 sin correr, 0 rojos**

**El interruptor funciona en las dos direcciones**, y las capturas lo muestran: en calma, caja violeta
y `3.9 m calma`; en hunt, caja roja y `3 m HUNT`.

**§3.1 quedó REFUTADO, y con el control disparado un segundo antes.** El orden real de la corrida fue
**al revés** del que pide la tabla, y eso la hace **más fuerte**, no más débil:

```
] phantasmagoria_hunt_reeval
    #1066  llamadas a OnFirstRelationWithPlayer: 1 -> 2      ← el contador está VIVO, medido acá
] phantasmagoria_hunt 1
    #1066  hunt -> SI ( cazador )   llamadas ...: 2          ← y prender el hunt NO lo movió
```

Con el control corriendo inmediatamente antes, «el contador no se movió» no puede ser «el contador
está roto». **Nada re-evalúa relaciones al entrar en hunt.** Y el bot **sí** cambia de actitud —fila
8—, lo que confirma que el cambio viene del `ShouldBeEnemy` leyendo el flag en vivo y **no** de
ninguna re-evaluación: exactamente la distinción que el aviso de arriba pedía no confundir.

> ### ⚠ La fila 6 se midió en un INSTANTE, y eso ya salió mal tres veces en este proyecto
>
> `phantasmagoria_hunt` imprime el contador **en el mismo frame del flip**. Si la base re-evaluara un
> tick después, esa línea no lo vería. La lectura del código dice que no puede pasar —nada observa
> `phantom_Hunting`— pero **eso es lectura, y la medición que tengo es una foto**. Es literalmente el
> defecto ① de la corrida 1 (*«0 navareas al spawnear» no es «0 navareas»*) y el del contador de
> areas que pasó de 42 a 137. **Se cierra con un `phantasmagoria_ghost_rel` ahora**: si sigue
> diciendo 2, la fila queda cerrada y de paso cae la fila 2, que tampoco se corrió.

**La pregunta abierta quedó contestada: deambula.** *«En calma sólo mira en una dirección y se mueve
aleatoriamente, onda deambulando»* — la predicción se sostiene (`movement_handler` cae en
`movement_inertia` con el comentario *«nothing better to do»*, `shared.lua:4184-4187`). **«No te
ataca» no se volvió «no hace nada».** Queda como **[a ojo]** y no como medición: la fila pedía dos
`pos` separadas y no se tomaron, así que el número no existe. Lo que sí quedó descartado es la rama
catastrófica.

> **Y acá me pasé de explicar, en el mismo párrafo en que lo anotaba.** Leí *«sólo mira en una
> dirección»* del reporte y le colgué encima la trampa ⑦ de Referencia §4.4 —sin `TERM_FISTS` el bot
> no mira hacia su objetivo al moverse, `motionoverrides.lua:2838`—. El autor corrigió enseguida:
> **en calma sí mueve la vista, sólo que menos.** La cita puede seguir siendo cierta en su propio
> alcance (mirar *hacia el goal* al moverse) y aun así **no era la explicación de lo que se estaba
> reportando**. *Una observación en prosa todavía no es una medición, y explicarla antes de fijarla
> convierte una frase suelta en un hecho con cita.* Queda **sin caracterizar**: cuánto mueve la vista
> en calma, y qué la mueve.

### El hallazgo nuevo, que es del autor y no de ninguna fila: **va casi al doble que el jugador**

*«Se mueve a una velocidad muy rápida, muchísimo más rápido que yo por el mod Better Movement.»*
El número: la base trae `ENT.RunSpeed = 550` (`shared.lua:132`, con el comentario del propio autor de
la base *«bit faster than players... in a straight line»*) y el fantasma **no lo pisa**, así que
hereda 550 contra los **280** de `sv_bm_speed_run`. Son **1,96×**. También hereda `MoveSpeed = 300` y
`WalkSpeed = 130`.

**Esto contradice §1.1 del diseño**, que dice que la velocidad se **deriva de la carrera real del
jugador** justamente para que el addon se calibre solo en cualquier servidor. No es un defecto de
este bloque —nunca se tocó la velocidad— pero **es la cuarta vez que «heredado» resulta no ser
«correcto»**, y esta vez lo agarró el juego y no la lectura. Queda abierto abajo.

## Corrida 8 (2026-08-06) — **el fantasma ya mira hacia donde camina**, y el criterio se cumplió en las dos mitades

Escrito **antes** de correr: `mirada vs marcha` tenía que bajar de ~75° a **menos de 20°**, y
`mirada vs jugador` tenía que **seguir siendo grande y aleatorio**. Las dos:

| Medición | Antes (corrida 7) | Ahora (corrida 8) | Criterio |
|---|---:|---:|---|
| `mirada vs marcha` | media **74,4°**, máx **179,9°** | media **1,9°**, máx **6,2°** | < 20° ✅ |
| `mirada vs jugador` | media 111,1° | media **130,5°**, rango 2,2–168,8 | seguir grande ✅ |

**La mitad que podía salir mal no salió mal.** Si el arreglo hubiera dejado al fantasma siguiéndote
con la vista fuera del hunt, `mirada vs jugador` sería ~0 en **las seis** lecturas. Es < 20° en
**una sola**, y esa una se explica sola con la tabla al lado: en esa lectura `marcha yaw 88,6` y
`al ply yaw 93,5` — **iba caminando derecho hacia el jugador**, a 111 u. El ángulo chico es
geometría, no seguimiento, y el instrumento lo exhibe sin que haya que argumentarlo.

> **Y hay una confirmación independiente que salió de la columna que yo había degradado a control:**
> el `delta` entre `mira` y `quiere` valía **0 en 15 de 15 lecturas** antes del arreglo, y ahora vale
> 2,7 · 6,2 · 0,6 · 0,1. **La columna que no medía nada se movió justo cuando el arreglo entró**, lo
> que ata el cambio a nuestro código y no a otra cosa.

### ⚠ Pero eso mismo la invalidó, y hay que decirlo: `delta` == `mirada vs marcha` **por construcción**

| Lectura | `delta` | `mirada vs marcha` |
|---|---:|---:|
| 130 u/s | 2,7 | **2,7** |
| 421 u/s | 6,2 | **6,2** |
| 550 u/s | 0,6 | **0,6** |
| 550 u/s | 0,1 | **0,1** |

Son el mismo número en las cuatro, y no es coincidencia: **desde el arreglo, en calma el que escribe
`DesiredEyeAngles` somos nosotros, con la dirección de marcha.** La columna te devuelve lo que tu
propio código acaba de escribir. *Un instrumento que reporta el valor que vos mismo escribiste no es
una medición independiente* — sigue valiendo en hunt (ahí lo escribe la base) y con
`phantasmagoria_ghost_facewalk 0`.

Corregido en la etiqueta, que además decía **`( control: 0 es lo esperado )`** y con el arreglo puesto
eso pasó a ser falso: un delta distinto de 0 se habría leído como falla. Ahora dice **quién** lo
pide: *«lo pide la base ( enemigo )»*, *«lo pedimos NOSOTROS: = mirada vs marcha, no es dato aparte»*
o *«no lo pide nadie: 0 es lo esperado»*.

### Dos cosas menores, medidas y sin explicar de más

- **Las dos fuentes de velocidad coinciden exactamente a régimen y se separan acelerando:** `130/130`
  y `550/550` en las lecturas estables, `421/402` en una. Queda anotado como observación; **no** se
  le pone causa.
- **El cambio tomó sin recargar el mapa.** El autor lo dice y el fantasma nuevo (#409) sale ya con el
  comportamiento nuevo. Anotado como hecho, no como regla: no se probó que valga siempre.

**Y sigue a la vista el pendiente de la velocidad:** `550 u/s` en calma es la `RunSpeed` heredada, o
sea 1,96× la carrera del jugador, contra lo que pide §1.1.

---

## Corrida 6 (2026-08-06) — el instrumento nuevo falló **tres veces**, y destapó el primer defecto del FANTASMA

La planilla se vació y se volvió a correr con el instrumento de mirada puesto. **Mismo veredicto —7
pasa, 1 falla— y cuatro defectos nuevos: los tres primeros míos, el cuarto del bot.**

### ① `marcha` decía `quieto ( 0 u/s )` SIEMPRE — y lo pescó el autor

*«Lo raro es que muestre que la marcha esté en 0 o quieto»*, con el bot cruzando 1.400 u entre
lecturas. **La causa fue una guarda que escribí para estar seguro:** `IsValid( ghost.loco )`.
`CLuaLocomotion` **no tiene método `IsValid`**, y el `IsValid()` de GMod devuelve `false` para todo
objeto que no lo tenga — así que la guarda caía **siempre** al vector cero.

**La base nunca envuelve `self.loco` en `IsValid`: lo llama directo**
(`terminator_nextbot_base/motion.lua:54`). Grep sobre sus 71 archivos: cero ocurrencias.

> *Una guarda defensiva que falla hacia un valor creíble es peor que no tenerla.* No tiró error, no
> tiró `nil`: tiró **«quieto»**, que es una lectura perfectamente posible. La única razón por la que
> se detectó es que el autor sabía que el bot estaba caminando. **Sexta vez en el arco que el defecto
> es del instrumento**, y la primera en que el modo de falla es *hacia un valor plausible*.

Corregido: sin guarda, y **con las dos fuentes impresas** —`GetCurrentSpeed()` (la de la base) y
`Entity:GetVelocity()`— para que si alguna vuelve a dar cero se vea **cuál**.

### ② Los yaws se imprimían sin normalizar, así que el mismo ángulo se leía como dos opuestos

`mira yaw -449.7` al lado de `quiere yaw 270.4`, **con `delta 0` en la misma línea**. Los dos números
eran el mismo ángulo y el delta estaba bien; lo que mentía eran los números de al lado.

| Lectura | `mira` crudo | `quiere` crudo | `mira` norm. | `quiere` norm. |
|---|---:|---:|---:|---:|
| 08 a | −449,7 | 270,4 | **−89,7** | **−89,6** |
| 08 b | −451,9 | 268,1 | **−91,9** | **−91,9** |
| 06 | −313,6 | 46,4 | **46,4** | **46,4** |

**Las nueve parejas del reporte son el mismo ángulo.** Todo pasa ahora por `math.NormalizeAngle`.

### ③ `quiere` lo declaré como el discriminante y no discrimina — y el motivo es estructural

**15 de 15 lecturas dieron `delta 0`.** No es calibración: `GetEyeAngles`
(`terminator_nextbot_base/shared.lua:81-93`) arma el ángulo con `self:GetAngles()` y **sólo pisa el
`pitch`**. O sea que **el yaw de «dónde mira» *es* el yaw del cuerpo, y no existe un yaw de cabeza
aparte** que se le pueda comparar. La pareja `mira`/`quiere` no podía separar cabeza de cuerpo **ni
en principio**, y yo la vendí como el par que lo separaba.

Se conserva **como control** —que el delta sea 0 es el dato: el aim converge en el mismo frame— y el
discriminante de verdad pasa a ser una línea nueva: **`al ply`**, el rumbo al jugador más cercano y
el ángulo contra la mirada. Sin eso, «el yaw cambió» no distingue *girar siguiéndote* de *girar solo*.

### ④ Y el que NO es del instrumento: **el fantasma no gira nunca en calma**

Cuatro lecturas cruzando el mapa —de X = −598 a X = +3.520— con **`mira yaw 3.2` en las cuatro**.
Después del hunt quedó clavado en 46,4 por tres lecturas más. **No vuelve a un default: se congela en
el último valor y deja de actualizarse.** Es lo que el autor venía diciendo desde la corrida 4:
*«se mueve mirando a un solo lado todo el tiempo»*.

Y la lectura del código coincide, censando **los cuatro** call sites de `SetDesiredEyeAngles`:

| Dónde | Cuándo dispara | ¿En calma? |
|---|---|---|
| `enemyoverrides.lua:1874` | apuntando al **enemigo** | **no** — en calma no hay enemigo |
| `motionoverrides.lua:3306` | **cayendo** | no |
| `motionoverrides.lua:3311` | **saltando** a una posición | no |
| `shared.lua:1543` (`justLookAt`) | vía el «mirar hacia el goal» de `motionoverrides.lua:2838` | **no** — doblemente cerrado, ver abajo |
| `terminator_nextbot_base/init.lua:161` | una vez, al inicializar | — |

**En calma, sin enemigo, sin caer y sin saltar, no queda ni un solo call site vivo.** Medición y
lectura coinciden, y esta vez el defecto **es del fantasma**: el primero del arco que no es del
instrumento.

> ### ⚠ CORRECCIÓN (corrida 7) — yo había culpado a los puños, y es la mitad equivocada
>
> Escribí que la causa era el gate `if not myTbl.TERM_FISTS then return end`
> (`motionoverrides.lua:2838`). **Es real, pero ese camino tiene DOS candados**, y el segundo cambia
> el diagnóstico entero: la línea siguiente exige además
> `currentSpeed < terminator_Extras.term_DefaultSpeedToAimAtProps`, que vale **`30^2`**
> (`motionoverrides.lua:1735`) comparado contra `Length2DSqr` → un umbral de **30 u/s**.
> **Este bot camina a 130 y corre a 550.** O sea que **devolverle los puños NO lo habría arreglado**:
> habría sido una ronda entera gastada en el arreglo obvio.
>
> **La causa de verdad es más simple:** el único call site que puede correr *caminando* es el del
> **enemigo**. Un terminator normal siempre tiene enemigo, así que siempre mira; nuestro fantasma en
> calma no tiene ninguno **a propósito**, y ahí no queda nadie que le mueva la cara.
>
> **Y contesta la pregunta del autor —*«¿será que HIM funciona así? porque el terminator parece
> moverse bien»*—: no es HIM ni es la base.** HIM también pone `TERM_FISTS = false`
> (`him/…/terminator_nextbot_homeless/server.lua:22`), igual que `terminator_nextbot_fakeply:35` y
> `csoldier:26`. Lo que ellos tienen y nosotros no es **un enemigo permanente**.
>
> *Un camino cerrado por dos condiciones se diagnostica leyendo las dos. Con una sola, el arreglo
> apunta al candado que no era.*

### El arreglo, escrito y con convar para el A/B

`ENT:BehaveUpdate` encadena al `BaseClass` y **después** rellena el hueco: cuando no está cazando, no
tiene enemigo, está en el piso y se mueve a más de 30 u/s, apunta el facing a la dirección de marcha.
Es lo mismo que hace la base al saltar (`motionoverrides.lua:3311`), aplicado al caso que no cubre.

`phantasmagoria_ghost_facewalk` (default **1**) lo apaga: en **0** vuelve el deslizamiento original,
así que el A/B es un comando y no una reversión.

**Los números que tiene que mover, de la corrida 7:**

| Medición | Calma (10 lecturas) | Hunt (6 lecturas) |
|---|---:|---:|
| `mirada vs jugador` | media **111,1°** (13,7–177,3) | media **2,8°** (0,0–14,6) |
| `mirada vs marcha` | media **74,4°**, máx **179,9°** | 0,8–34,6° |

**179,9° es caminar exactamente de espaldas.** El criterio del check nuevo sale de acá: en calma,
`mirada vs marcha` tiene que bajar de ~75° de media a **menos de 20°**, y `mirada vs jugador` tiene
que **seguir siendo grande y aleatorio** — si también se va a cero, el fantasma quedó siguiéndote con
la vista fuera del hunt, que es peor que el defecto original.

---

## Corrida 5 (2026-08-06) — la planilla CORRIDA: **7 pasa, 1 falla**

`dev/checks/phantasmagoria-hunt-r1.html`. **El interruptor queda cerrado**: las cuatro filas que
faltaban salieron verdes, incluidas las dos que podían pedir código.

| # | Resultado |
|---|---|
| 01 · un fantasma, arrancó en calma | ✅ `spawn #1069 … hunt NO` |
| 02 · la puerta cerrada y la relación abierta | ✅ **`rel D_HT pri 1000` + `ShouldBeEnemy NO`** — el resultado del bloque en una línea |
| 03 · el cerebro entero | ✅ **31 tareas**, con `movement_handler`; el refactor no rompió nada |
| 04 · deambula, medido | ✅ **4.885 u de camino** (93 m), neto 2.161 u |
| 05 · el contador fuera del instante | ✅ **1 llamada**, `la ultima a t=101 con hunt=NO`, en **tres** lecturas |
| 06 · suelta al enemigo al apagar | ✅ *«pasa inmediatamente a calma»* — la base lo hace sola |
| 07 · aguanta un balazo | ✅ baleado a fondo: sigue `enemigo ninguno` / `ShouldBeEnemy NO` |
| 08 · la vista en calma | ❌ **FALLA** — y la falla vindica lo que yo había retractado |

**La fila 02 es la que vale por todo el bloque:** `rel D_HT pri 1000` **y** `ShouldBeEnemy NO` en la
misma línea. La relación **no** se apagó —sigue odiándote— y el bot igual no ataca. Eso es
exactamente la separación que §3.1 confundía, exhibida.

**Y la 05 salió más fuerte que lo que pedía el criterio.** Tres `ghost_rel` mientras cazaba, a 62,
568 y 310 u, las tres con `1 llamada(s), la ultima a t=101 con hunt=NO`. El **timestamp** es el dato:
la última evaluación fue a t=101 **con el hunt apagado**, y el hunt se prendió después. No es que el
contador no se movió en el frame del flip — es que **no se movió nunca más**, y se ve el reloj.

### ⚠ Tres defectos de esta ronda, y **DOS son de la planilla**

**① El criterio de la fila 05 pedía «2 llamadas», y lo correcto era 1 — arrastre de bloque anterior,
cometido por mí adentro de la planilla que existe para impedirlo.** Escribí el 2 copiando el contador
del fantasma **#1066 de la corrida 4**, que había recibido un `hunt_reeval`. El #1069 es otro
fantasma y nunca lo recibió: su contador arranca y se queda en 1. *«Una planilla mide un bloque y no
arrastra información de bloques anteriores»* — y el que arrastró fue el criterio. El autor lo juzgó
por la sustancia y marcó PASA, que es lo correcto: **el criterio decía el número equivocado, no la
cosa equivocada.**

**② El criterio de la fila 04 pedía DOS muestras, y las dos primeras habrían dado ROJO.** Los saltos
reales, con el jugador quieto:

| Intervalo | Δ | Contra mi umbral de 200 u |
|---|---:|---|
| 03 → 04#1 | **42 u** | ❌ habría dicho «clavado» |
| 04#1 → #2 | **153 u** | ❌ habría dicho «clavado» |
| #2 → #3 | 470 u | ✅ |
| #3 → #4 | 1.076 u | ✅ |
| #4 → #5 | **3.144 u** | ✅ |

Salió inequívoco porque el autor tomó **seis** muestras y no dos. El umbral estaba bien; **el número
de muestras estaba mal**, y lo peor es que la regla ya estaba escrita en `dev/PLANTILLA_CHECKS.md`:
*«un caso suelto no juzga; si el resultado depende de un sorteo, repetir»*. `movement_inertia` se
turna con `movement_wait` y `movement_camp`, así que una ventana de 30 s puede caer entera adentro de
una pausa. **Escribí la regla en la plantilla y no la apliqué al check que la necesitaba.**

**③ `phantasmagoria_ghost_rel` no muestra la vida, así que la precondición de la fila 07 no era
visible.** *«Acá lo baleo completamente bajándole la vida»* quedaba como afirmación del que corre la
planilla y no como dato del instrumento — y la regla de la casa es que **el comando imprima con qué
está midiendo**. Corregido: ahora imprime `vida N / M` y dice `( recibio dano )` o `( INTACTO: nadie
le pego )`.

### La fila 08 falla, y la falla vindica la explicación que yo había retractado

*«Por fijo es que mira a un lado generalmente, es muy poco que gira a ver otros lados y eso es cuando
está quieto.»*

La rama de falla que escribí decía: *«en calma la cabeza está totalmente fija → la explicación que
descarté era la buena»*. Y el código dice exactamente eso
([`motionoverrides.lua:2838-2845`](../dev/other/phantom/dev2/terminator%20nextbot/lua/entities/terminator_nextbot/motionoverrides.lua#L2838)):

```lua
if not myTbl.TERM_FISTS then return end -- only look towards goal if we have fists

local currentSpeed = vecMeta.Length2DSqr( locoMeta.GetVelocity( myTbl.loco ) )
if currentSpeed < terminator_Extras.term_DefaultSpeedToAimAtProps then
    ...justLookAt( self, towardsPos )
```

Sin puños ese camino **no corre nunca**; y aun con puños, sólo apunta **por debajo** de un umbral de
velocidad. Las dos mitades coinciden con lo observado: **la cabeza no gira mientras camina, y lo poco
que gira es estando quieto.**

> **Pero la lección no es «yo tenía razón», es la contraria.** Mi error nunca fue la cita: fue
> **colgarla de una frase suelta antes de fijar la observación**, y después **retractarla de más** al
> primer «no, sí mueve la vista». Las dos veces expliqué en vez de medir. Lo que cerró esto fue un
> check con lado-que-falla escrito, no un argumento. *Y lo que sigue sin leerse es la otra mitad:
> **qué** le mueve la cabeza cuando está quieto.*

**Por eso el instrumento cambió, y es el pedido literal del autor** —*«falta que el comando muestre a
dónde está mirando»*—. `phantasmagoria_ghost_where` ahora imprime **tres** líneas que se discriminan
entre sí:

| Línea | De dónde sale | Qué separa |
|---|---|---|
| `mira` | `GetEyeAngles()` (`terminator_nextbot_base/shared.lua:81`) | **el yaw es el del CUERPO**: la función sólo pisa el *pitch* con `GetAimPitch()` |
| `quiere` | `GetDesiredEyeAngles()` (`motion.lua:139`) | lo que alguna tarea le **pidió** mirar |
| `marcha` | `loco:GetVelocity()` | hacia dónde se mueve, y el ángulo contra `mira` |

`quiere ≠ mira` significa *«algo le pide girar y no llega»*; `quiere == mira`, los dos quietos y
caminando, significa **que nadie se lo pide** — que es lo que predice no tener `TERM_FISTS`. Sin las
tres juntas, «no mueve la cabeza» no distingue las dos causas.

> Ojo con el `loco`: la base mueve al bot por el locomotion, no por la física de la entidad
> (`motionoverrides.lua:2840` usa `locoMeta.GetVelocity( myTbl.loco )`). Un `Entity:GetVelocity()`
> sobre un NextBot puede dar cero y leerse como «está quieto».

---

### La planilla de la ronda 1 → **CORRIDA**: `dev/checks/phantasmagoria-hunt-r1.html`

La corrida 4 se llevó adelante contra la tabla de acá arriba, que es lo que el encargo pedía. **Para
lo que falta se armó la planilla**, que es la convención de la casa para checks en juego
(`dev/PLANTILLA_CHECKS.md`; hay 24 ejemplares en `dev/checks/`) y que la tabla markdown no da: un
campo de nota por check —*«la nota se llena aunque el check pase»*—, `SIN CORRER` como estado
legítimo, y el botón que arma el reporte.

Son **8 checks**: las cuatro filas que quedaron sin correr, más cuatro que salieron de la corrida
misma.

| En la planilla | De dónde sale |
|---|---|
| 01 · hay **un** fantasma vivo y arrancó en calma | precondición nueva: los comandos iteran sobre todos y con dos las lecturas se mezclan |
| 02 · la puerta cerrada **y** la relación abierta | la fila 2 — y es la **primera ejecución en la historia** de `phantasmagoria_ghost_rel` |
| 03 · el cerebro sigue entero | la fila 5 — y `ghost_where` **se refactorizó** (`makeSay` + `eachGhost`) y no se volvió a correr |
| 04 · deambula, **medido** | la fila 4, que salió **[a ojo]**: acá se toman las dos `pos` |
| 05 · el contador **fuera del instante** del flip | cierra la única debilidad de la corrida 4 |
| 06 · al apagar suelta al enemigo en ≤ 3 s | la fila 9 |
| 07 · aguanta un balazo | la fila 10 — **guardia de regresión** del interruptor |
| 08 · en calma mueve la vista **menos** que cazando | fija la observación que expliqué antes de caracterizarla |

**Los dos instrumentos sin ejercer son la razón por la que 02 y 03 van antes que nada:** si tiran
error de Lua, el que falló es el instrumento y no el fantasma, y hay que anotarlo igual. La **06** y
la **07** son las dos que pueden salir rojas y pedir código.

> **La planilla también es un tercero, y se auditó.** Seis bloques: sin arrastre del bloque anterior
> (0 ocurrencias de «paramic»), sin bloque `RESULTS` que pise el estado al cargar, `STORE` único
> —contrastado contra **23 de las 25** planillas; las dos que faltan no declaran la clave en ninguna
> forma que el patrón reconozca, y queda dicho—, el título del reporte cambiado (que es el que no se
> ve en la página y por eso se olvida), 32 campos con HTML crudo balanceados, y los 8 checks en
> `idle`. **El primer barrido cubrió 20 de 24 porque mi propio patrón pedía `const STORE` y cuatro
> planillas lo escriben sin `const`** — un inventario a medias, otra vez, esta vez en el auditor.

**Predicciones, para que la refutación sea barata:** 1-3 verdes, 4 **deambula** (`movement_handler`
cae en `movement_inertia` con el comentario *«nothing better to do»*, `shared.lua:4184-4187`), 5
verde, **6 verde en el sentido de que §3.1 queda refutado**, 7 verde, 8-10 verdes. Si algo sale
distinto, **gana el juego** y se corrige el documento.

> **⚠ La fila 6 se puede leer mal de la forma más fácil.** Al prender el hunt el bot **sí** va a
> cambiar de actitud —eso es la fila 8— y es tentador anotarlo como que §3.1 tenía razón. **No lo
> tiene:** el cambio viene del `ShouldBeEnemy`, que lee el flag **en vivo**, y §3.1 afirmaba otra
> cosa muy concreta —que se **re-evalúan las relaciones**—. Lo único que mide la fila 6 es el
> contador, y la fila 7 existe para que un contador quieto no se pueda confundir con un contador
> roto. *Medir la consecuencia no es medir el mecanismo.*

> **Dos cosas de la fila 10 que hay que saber antes de leerla mal.** ① El tiro **sí** te mete en su
> memoria: la ruta 4 de §18.7 (`PostTookDamage` → `UpdateEnemyMemory`, `damageandhealth.lua:500`)
> **no chequea línea de vista ni relación**. Lo que la fila mide es que `ForgetOldEnemies` y
> `FindPriorityEnemy` te descarten igual, porque las dos preguntan `ShouldBeEnemy`. ② El bot **va a
> girar la cabeza** hacia el disparo — `TookDamagePos` (`damageandhealth.lua:515`) — y eso **no** es
> tomarte de enemigo: si girar contara como rojo, la fila mediría otra cosa. La vida es 900, así que
> unos tiros no lo matan.

> **La fila 4 del check anterior cambia de premisa.** Decía «camina hacia el jugador» y salía verde
> porque el bot era hostil **a propósito**. Con el interruptor, esa fila **sólo vale con
> `phantasmagoria_hunt 1`** — que es exactamente lo que mide la fila 8 de acá. No es una regresión:
> es que el criterio viejo medía un andamio.

---

## El check de la entidad mínima — **CERRADO EN VERDE**

Son tres archivos:

```
lua/entities/terminator_nextbot_phantom/
    shared.lua    registro, clase, categoría — corre en los DOS realms
    server.lua    modelo, desarmado, FOV, y los avisos de spawn
    client.lua    el marcador que atraviesa paredes
```

**Su primer trabajo es ser instrumento, no ser un fantasma.** Por eso `IsWraith` está **fuera**
—corrige el snippet que este documento traía, que lo incluía— y por eso el bot queda **hostil a
propósito**: el criterio de cierre dice «camina hacia algo» y hace falta un algo.

### Las precondiciones, medidas en la máquina del autor (no supuestas)

| Precondición | Estado | Cómo se midió |
|---|---|---|
| El addon montado en GMod | ✅ | junction `garrysmod/addons/phantasmagoria` → el repo. El código entra al arrancar, sin copiar nada |
| La base Terminator montada | ✅ | WSID **2944078031**, título *«Terminator Nextbot»*. Ojo: `CREDITOS.md` anota `2734691788`, que **no** está suscrito |
| Un mapa con navmesh | ✅ | `maps/gm_construct.nav` (7,2 MB) y `gm_flatgrass.nav` (277 KB) ya existen. **No hace falta `nav_generate`** |
| `models/dejtriyev/scaryblackman.mdl` | ❌ | **no lo trae ningún addon montado** — barridos los 418 con contenido (395 `.gma` + 26 legacy `.bin` descomprimidos), las otras 455 carpetas del Workshop están vacías |

**El modelo faltante no bloquea el check, y por eso el fallback existe:** `server.lua` va a caer a
`models/player/group01/male_04.mdl` —presente en el índice de `garrysmod_dir.vpk`— y **lo va a decir
en consola**. Así que la predicción de la fila 2 cambia: **no** sale la silueta negra sin ojos, sale
un ciudadano de HL2. Si querés el modelo bueno, está desempacado en
`dev/other/phantom/dev2/scary black man (hood irony) playermodel/` y se monta con un junction a
`addons/`, igual que este repo.

> Los dos negativos de arriba salieron **con control**, porque el primer barrido mintió dos veces: el
> parser de títulos `.gma` daba 0 coincidencias hasta que se le leyó bien la lista de contenido
> requerido, y el barrido por substring daba «ninguno» sobre los legacy `.bin` **porque están
> comprimidos con LZMA** — lo delató que el control (Jeff, que sí está suscrito) tampoco aparecía en
> su propio archivo.

| # | Qué se hace | Verde | Rojo | **C1** `gm_graysonhouse` | **C2** `gm_uh_house` | **C3** `gm_graysonhouse` |
|---|---|---|---|---|---|---|
| 1 | Abrir el spawnmenu, pestaña **NPCs** | hay categoría **Phantasmagoria → Fantasmas** con *Phantasmagoria Ghost* | no está | ✅ | ✅ | ✅ |
| 2 | Clickearlo | aparece un cuerpo, y la consola imprime `[Phantasmagoria] spawn #N modelo … pos …` | error de Lua, o nada | ✅ `#253` | ✅ `#1090` | ✅ `#276` |
| 3 | Mirarlo | hay caja violeta + haz + `PHANTOM #N` + distancia en metros, **también a través de una pared** | no se dibuja nada | ⚠️ sin etiqueta | ✅ `4 m` | ✅ `1.3 m` |
| 4 | Alejarse y esperar | **camina hacia el jugador** — el marcador se mueve y la distancia baja | se queda clavado | ✅ camina y persigue | ✅ se movió 68 u, `enemigo Player [1]` | ✅ se movió 137 u |
| 5 | `phantasmagoria_ghost_where` en consola | lista pos, vida, modelo, enemigo, tareas y navareas | dice 0 fantasmas con uno vivo | sin correr | ⚠️ todo menos las tareas | ✅ **las 31 tareas** |

## ✅ CHECK CERRADO — las cinco filas en verde

**La entidad funciona.** Existe, aparece en el menú, spawnea, camina, te persigue, te toma como
enemigo, y los dos instrumentos reportan. Verificado en **tres corridas sobre dos mapas**, uno con
navmesh y otro sin.

**Los CUATRO defectos que salieron son del INSTRUMENTO, no del fantasma.** El fantasma anduvo a la
primera y nunca falló. Los cuatro están corregidos; tres, confirmados en juego.

**① El aviso de navmesh predecía en vez de medir — y el juego lo refutó.** Decía «SIN NAVMESH: el bot
no va a caminar», había 0 navareas, y **el bot caminaba**. La medición del instante era correcta; la
predicción, falsa. La causa estaba en el código que yo mismo había leído para escribir el aviso: con
0 areas la base llama a **`TryGeneratingAreas()`** (`shared.lua:3072-3075`) y el **parcheador**
(`terminator_areapatcher.lua`, convar `terminator_areapatching_enable`, **default 1**) sigue creando
areas donde caminan bots y jugadores. Leí la rama del mensaje y no la línea de abajo, que es la que
actúa. **Arreglado midiendo dos veces**: informa el 0 al spawnear y **vuelve a medir a los 10 s**,
diciendo cuántas areas lleva el parche — o confirmando el 0, que ahí sí es terminal.
**Confirmado en la corrida 3**: `0 navareas al spawnear` → `van 42 navareas a los 10 s`.

> **Y el número sigue creciendo, lo cual obligó a cambiar el verbo.** El mismo `ghost_where`, un rato
> después, dio **137**. El parcheador crea areas donde pisan bots y jugadores, así que la lectura es
> **una foto y no un total** — decía «construyó 42» y ahora dice «van 42 … y sigue trabajando».
> Tercera vez en este arco que un número medido en un instante se escribe como si fuera permanente.

**② La etiqueta del marcador estaba sobre el techo.** Se veían la caja y el haz y no el texto: estaba
a 250 u sobre la cabeza (~322 del piso), y la corrida fue **adentro de una casa**. El instrumento se
diseñó para un mapa abierto. Bajada a 14 u — pegada a la cabeza. El haz largo se queda: es lo que te
dice desde otra habitación en qué dirección está. **Corregido y confirmado en la corrida 2.**

**③ `phantasmagoria_ghost_where` perdía su mejor línea, y el aviso no decía cuál.**
`HUD_PRINTCONSOLE` viaja por un user message `TextMsg` con techo de **255 bytes**, y al pasarse **no
se trunca: el servidor se niega a mandarlo** — `Refusing to send user message TextMsg of 256 bytes`.
De las seis líneas por fantasma se perdió exactamente una: **la de tareas**, que es la más
informativa y la única que crece sin techo. El único rastro fue ese aviso del engine, que **no dice
cuál se perdió**: sin leer la salida esperada al lado de la real, pasa por completa.
Arreglado troceando toda línea a 180 bytes —red de seguridad para las seis— y sacando **una tarea por
línea**, que además se lee mejor. **Confirmado en la corrida 3: llegaron las 31.**

**④ La etiqueta tapaba media pantalla de cerca.** Con escala fija, `cam.Start3D2D` crece sin techo al
acercarse: a **1,3 m** el `PHANTOM #276` no entraba en la pantalla — justo cuando más querés ver.
Ahora **la escala sigue a la distancia** para ocupar siempre lo mismo, calibrada contra la corrida 2
(a 4 m, escala 0,35) y con topes en 0,12 y 1,5. **Sin confirmar en juego.**

> **Las 31 tareas de la fila 5 no son ruido: son el inventario del cerebro heredado**, y ahí está la
> §5 de la referencia hecha lista — `movement_watch` (el comportamiento HIM ya escrito),
> `movement_stalkenemy`, `movement_camp`, `movement_backthehellup`, `movement_followsound`. Todo eso
> ya corre. Lo que falta no es escribirlo: es elegir cuándo.

El 3 y el 5 son **dos instrumentos que fallan distinto**: el marcador solo ve lo que está en el PVS,
el comando corre en el servidor y los ve a todos. Si el 5 lo encuentra y el 3 no, el bot existe y el
que falló es el dibujo.

### Si la fila 1 sale roja: la escalera que separa las causas

Cuatro formas de spawnearlo que dependen de cosas distintas, de más frágil a más cruda. La primera
que funcione dice dónde está el corte:

| Camino | De qué depende | Si anda y el anterior no |
|---|---|---|
| menú NPCs | registro **en el cliente** | falló `RegisterNPC` clientside — o sea el entrypoint (§4.4④) |
| `gmod_spawnnpc terminator_nextbot_phantom` | `list.GetEntry( "NPC", … )` **en el servidor** (`sandbox/gamemode/commands.lua:607`) | el registro corrió en el servidor y no en el cliente |
| `gm_spawnsent terminator_nextbot_phantom` | `ENT.Spawnable`, lista `SpawnableEntities` (`commands.lua:918`) | `RegisterNPC` falló en los dos realms, pero la clase existe |
| `lua_run ents.Create( "terminator_nextbot_phantom" ):Spawn()` | sólo que la clase esté registrada | la entidad está sana y todo el problema es de listas |

Si falla **también** el cuarto, la clase no se registró: hay un error de Lua al cargar y está en la
consola, arriba de todo.

Si algo sale distinto de lo que este documento predice, **gana el juego** y se corrige el documento.

### Lo que deliberadamente NO tiene, y por qué

| Ausente | Por qué |
|---|---|
| `ENT.IsWraith` | un instrumento invisible no sirve para ver dónde está |
| ~~`OnFirstRelationWithPlayer`~~ | **ya no está ausente** — se escribió el 2026-08-06, pero como instrumento y no como interruptor. Ver el bloque de arriba |
| `SetupDataTables` | el `Bool 0` ya es `Crouching` en la base (trampa ③) |
| máquina de estados, 30 tipos, rasgos, cordura, sonidos | todo eso venía **después** de verla caminar una vez — y ya caminó |

**Dato de la corrida 3 que es decisión de diseño pendiente: la vida es 900**, el default de la base
(`terminator_Extras.healthDefault`). Un fantasma de Phasmophobia no se mata a balazos: §5.4 dice que
el desenlace es `kill` o `banish` por tipo, así que ese número va a dejar de ser salud y a pasar a
ser otra cosa.

Las trampas de la base están en §4.3 y §4.4 de la referencia. Resumidas:

1. **`ENT.Models`, no `ENT.Model`** — si no, spawnea con Arnold.
2. **`Term_FOV` necesita `AutoUpdateFOV = false`** o la convar global lo pisa en caliente.
3. **No usar `SetupDataTables` con `Bool 0`** — la base ya usa ese slot para `Crouching`.
4. **El interruptor fantasma/cazador es `ShouldBeEnemy`** —y **nunca** `DisableBehaviour`—. Esta
   línea decía `OnFirstRelationWithPlayer`, que es lo que dice §3.1, y **es la función equivocada**:
   ésa escribe un cache que se llena una vez. Corregido el 2026-08-06 leyendo el código; el detalle,
   arriba.
5. **`ENT.Base = "terminator_nextbot"`**, no `"terminator_nextbot_base"` — el `_base` no tiene cerebro.
6. **El punto de entrada de una entidad-carpeta es `shared.lua`**, no `init.lua`: el registro tiene
   que correr **en el cliente**, que es donde se arma el spawnmenu (§4.4④).

---

## Decisiones tomadas

| Tema | Decisión | Cuándo |
|---|---|---|
| Base | `terminator_nextbot` (no DRGBase, no VJ) | 2026-08-01 |
| Velocidad | Relativa a la carrera real del jugador, vía Better Movement | 2026-08-01 |
| Desenlace del hunt | Por tipo: `kill` o `banish` | 2026-08-01 |
| Vuelta del destierro | Muriendo (rápido) **o** por ritual (el camino divertido) | 2026-08-01 |
| Audio | `.ogg`, originales intactos aparte | 2026-08-01 |
| Alcance | Sandbox, **no** gamemode | 2026-08-01 |
| Modelos | `scaryblackman` + el quemado de HL2 + los que aparezcan | 2026-08-01 |

---

## Lo que está abierto

- ~~LA VELOCIDAD: el fantasma va a 1,96× la carrera del jugador~~ **CERRADO EN JUEGO el 2026-08-06**
  (`server_speed.lua`): `objetivo 280`, `deseada 66` caminando y `280` corriendo, con `real`
  acompañando. **Este bullet siguió diciendo «no está escrito» durante ocho rondas** — el mismo defecto
  que la sección «El próximo paso concreto». Lo único que queda es papeleo: las filas de
  `veldoors-r1` nunca se marcaron, porque se midió por consola.
- ~~Cuánto mueve la vista el fantasma en calma, y qué se la mueve~~ **CERRADO EN JUEGO el 2026-08-08**
  (r13b, fila 07): en calma la escribimos **nosotros** con el facewalk — `NOSOTROS 104 · LA BASE 11` de
  120 muestras — con `vs marcha` media **16,3°** y `vs jugador` media **121,9°** (rango 5,5–180). O
  sea: mira hacia donde camina y **no** te sigue con la vista, que es exactamente lo que pedía el
  criterio de la corrida 8.

- ~~La forma de la capa de compat con NEAD~~ **DECIDIDO: no se integra** (§19.5). NEAD hace
  `ply:SetNoTarget(true)` a un segundo a oscuras sin linterna, y la base respeta `FL_NOTARGET` en
  `ShouldBeEnemy` **y en el alerter** — invisible **e inaudible**. El override era posible, pero
  **las 6 muestras de oscuridad son API del engine, no de NEAD**: se reimplementan en 20 líneas, sin
  heredar el conflicto. **NEAD queda declarado no compatible, con aviso y sin bloquear** (precedente
  de `phantasmagoria_assetcheck.lua`). El sampler va **chico y autocontenido**: Cortex lo va a
  necesitar.
- **La pantalla del camión** (§19.3) — **EN CURSO EN OTRA SESIÓN, por el camino bueno: se está
  ripeando la pantalla real del camión de Phasmophobia.** El modelo ya está bien y el Lua que le pone
  la info está en proceso. **No hay que hacer nada con `tv_plasma`**: `dev/other/cs_office_tv/` queda
  sólo como respaldo del prop de CS:S y como registro de la trampa de `vpk.exe`. Lo que sigue
  valiendo de acá es §19.3: **HTML para las pantallas del camión, 2D para el equipo en mano**, y no
  asumir que `DHTML:GetHTMLMaterial()` sirva en `SetSubMaterial`.
- **¿`DHTML:GetHTMLMaterial()` sirve en `SetSubMaterial` sobre un modelo?** Sin medir. El camino
  seguro es HTML → nuestro RT → submaterial, que reusa la plomería del paramic.
- **Los 3 tiers de las pastillas** y qué restaura cada uno (§19.6). El modelo ya está:
  `models/phas/eqp_sanity_pills.mdl`.
- **Qué drena cordura y cuánto**, y **qué suma al medidor de actividad** 0-10 (§19.3, mecánica nueva
  que salió de las capturas del camión).

- ~~¿`MASK_BLOCKLOS` choca con `prop_physics`?~~ **MEDIDO Y REFUTADO EN JUEGO** (2026-08-03, §18.6):
  **no choca.** Control `true / Entity [59][prop_physics]`, con el mask `false / [NULL Entity]` —
  misma línea, única variable el mask. **Primera medición del proyecto y refutó al documento.**
  El arreglo es un campo: `ENT.LineOfSightMask` es por entidad con fallback al global
  (`shared.lua:2960`), y sus tres usos son la misma clase de pregunta.
  **MEDIDO EN JUEGO que el campo se respeta** (2026-08-03): de frente sin nada en medio `solid=true`
  —el control—, tras un container y tras unas compuertas `solid=false`. De paso salió que **las
  compuertas tampoco cortan `MASK_BLOCKLOS`**. Sigue **sin medir** que un `ENT.LineOfSightMask` de
  **subclase** sobreviva la línea de init: acá se seteó después del spawn.
  **El mask elegido es `MASK_SOLID`**, barriendo cinco candidatos en juego: es el único de los dos
  que sirven sin traer `CONTENTS_DEBRIS` (gibs cortando la vista) ni `CONTENTS_HITBOX` (caro, y este
  trace corre por enemigo y por barrido).
- ~~¿El mundo sí corta `MASK_BLOCKLOS`?~~ **MEDIDO: sí** — las cinco pegan en `worldspawn` contra una
  pared. **La rama catastrófica está muerta**, la base no es omnisciente.
- ~~¿Una entidad (jugador, NPC) corta `MASK_BLOCKLOS`?~~ **MEDIDO: no.** Mismo barrido contra un
  `npc_kleiner`: mismo patrón exacto que la caja, con una entidad de clase distinta. **`MASK_BLOCKLOS`
  es geometría del mundo y nada más**, y `CONTENTS_MONSTER` es el bit de «esto es una entidad». Con
  eso queda medido también el efecto secundario de `MASK_SOLID`: **jugadores y NPCs ocluyen**.

- **Plan del autor (2026-08-03): la entidad básica se escribe como instrumento** — primero existir y
  **mostrar dónde está**, después todo lo demás. Tres cosas para no tropezar:

  1. **NO ponerle `ENT.IsWraith = true` todavía.** §2 lo lista como el regalo que la hace invisible
     fuera del hunt — y un instrumento invisible no sirve para ver dónde está.
  2. **La base ya trae visualizadores**, no hace falta escribirlos: `term_debugpath` (dibuja el path;
     **pide `sv_cheats 1`**, `base/init.lua:92`), `term_debugtasks` (imprime tareas, y vuelca el
     historial al hacerle **+use** al bot) y `term_debughearing`.
  3. **El check NO depende de la entidad.** «¿Un prop corta `MASK_BLOCKLOS`?» es una pregunta de
     `util.TraceLine` entre dos puntos cualesquiera: se contesta desde consola sin NextBot. Hacerlo
     con el fantasma es **más convincente** —ejerce la cadena real, `GetShootPos` → `EntShootPos`→
     `CanSeePosition`— pero si la entidad se demora, la versión sintética desbloquea el diseño igual.
- **Dos defectos de la base, y muerden en momentos distintos** (§18.3):
  1. **Vista infinita sobre jugadores, y está etiquetada como feature** — `DoDefaultTasks` recorre
     `player.GetAll()` **sin filtro de distancia** cuando el bot no tiene enemigo (*«cheap infinite
     view distance»*, `shared.lua:3185`). Es la **ruta 3** de §18.7. **Vive y muerde hoy.** Se acota
     overrideando `ShouldBeEnemy`, que es **punto único**: las tres rutas de adquisición pasan por
     ahí. Por eso el arreglo son **dos campos MÁS un override**, no dos campos.
  2. **La dispersión se invierte pasando los 500 u** (`500 - sndDist`, y `VectorRand()` sin
     normalizar): más ruido mejora la puntería sólo hasta 500, y a 500 clavados **te da la posición
     exacta**. **Está DORMIDO** —vive en `shouldNotSeeEnemy`, muerta tras el `if` del alfa— y se
     hereda **en el instante en que se des-gatee** (§18.3). Arreglarlo en **esa misma** sesión.
- ~~Los sonidos ambiguos: 46 de 265.~~ **CERRADO** (2026-08-03): el autor los escuchó y los
  describió uno por uno; están catalogados y `_sin_identificar/` ya no existe. **265 de 265 mapeados**
  por acción, **incluidos los pasos del fantasma** — `ghost/footstep/boots_1-8`, §7.4.
- **Los pasos lejanos** (§7.5, pedido del autor): un ghost event de pisadas lentas a distancia, sin
  fuente visible. **No necesita assets nuevos** —es el banco de botas sonando lejos— y el rasgo
  (`ability.paranormalSoundInterval`) ya existe. Falta escribirlo, como todo lo demás.
- ~~**La parabólica no existe**~~ **PORTADA Y CERRADA EN JUEGO** (2026-08-05): los **tres tiers**
  del Parabolic Microphone están en el árbol (`models/phantasmagoria/paramic1-3.mdl`), con su plato
  parabólico translúcido, sus pantallas dibujando un RenderTarget con el contenido real del Canvas
  del juego, y el LED del tier 1 parpadeando. Cuatro rondas de checks en juego, la última 8/8
  (`dev/checks/paramic-vidrio-r4.html`). Ver el CHANGELOG del 2026-08-05.
  **Lo que falta no es el asset sino la mecánica:** siguen siendo props, no ítems —falta la forma
  (SWEP/entidad) y sobre todo **conectar las pantallas a datos reales**, porque
  `PHANTASMAGORIA.ParamicData` arranca en CERO y nada lo llena. El disparador del LED tampoco existe.
- **El sound sensor sigue sin prop.** Con la identificación de sonido cerrada, la mecánica de
  **delatar por sonido tiene audio y ya tiene la mitad de sus props** — le falta a la Music Box, que
  ya tiene su tarareo.
- **Los equipos.** La **forma** ya está decidida ([docs/EQUIPAMIENTO.md](docs/EQUIPAMIENTO.md) §5):
  SWEP lo que se sostiene, entidad lo que se planta y la escenografía, ítem con `onUse` lo que se
  consume. Falta **elegir cuáles entran primero** — EMF reader, spirit box, cámara, termómetro, libro
  de escritura, UV, DOTS, salt, crucifijo — y escribir el primero de punta a punta. El viewmodel es
  el prop flotando frente a la cámara: los 36 modelos tienen **1 hueso y 1 secuencia**, así que no
  hay manos ni animación posibles sin recompilar (§5.1, medido).
- **Cargo.** La integración está diseñada y leída contra su código (§6), sin escribir. Lo que hay que
  saber antes de tocar nada: **la captura de Cargo se come cualquier SWEP** que el engine entregue y
  le fabrica un def de 2,5 kg sin precio, así que registrar defs propios no es opcional si Cargo
  está montado. Sigue siendo **soft-dep**: sin Cargo tiene que haber camino propio.
- ~~El arte de las huellas UV.~~ **CERRADO** (2026-08-02): se reciclan los decals de gmpa, derivados
  a máscaras teñibles con [`dev/uv_prints.py`](dev/uv_prints.py) y acreditados con hash. Cuatro
  texturas en `materials/phantasmagoria/uv/`. Lo que **queda** es el Lua: la evidencia `uv` la tienen
  **13 de los 30 tipos** y la mecánica está diseñada en
  [docs/EQUIPAMIENTO.md](docs/EQUIPAMIENTO.md) §8 — falta escribirla.
- **El Alternate** (Mandela Catalogue) — **NPC de evento especial, fuera de los 30 tipos.**
  **ACTUALIZADO 2026-08-05: el banco de voces pasó de 34 a 168 archivos (20,2 min) y eso cambió el
  diseño, no sólo los números.** Dos bancos nuevos mandan: `sayto_ghost` (62 líneas dirigidas a otro
  fantasma) **obliga a que el Alternate NO sea el fantasma del contrato** —se suma al sorteo, no lo
  reemplaza— y convierte al enemigo en **fuente de información**: le habla al otro fantasma, el
  jugador espía, y **7 de los 30 tipos tienen voz propia** (`demon`, `goryo`, `jinn`, `oni`,
  `poltergeist`, `shade`, `yokai` — verificado contra las claves de `ghost_types.lua`), así que 23
  de 30 partidas la conversación no revela nada. `idle_prayer` (10) es **la única ventana en la que
  el crucifijo destierra** en vez de sólo degradar: dura ~6 s, igual que `preacherwhispers`.
  **El loop está cerrado en ALTERNATE.md §7-§9**: el antagonista es a la vez el obstáculo, el sistema
  de pistas y la condición de victoria.
  **Y meter un segundo fantasma destapó que el daño de cordura estaba inflado al doble** (lo pescó el
  autor): con el anfitrión drenando en paralelo, la cordura llegaba a 0 en **4:03** y no entraba nada
  de lo que el diseño pide que pase. Arreglado con dos piezas (§5.2-§5.5): la aparición vuelve al
  **15 % del `about.txt`** —yo la había puesto en 30 %— y **mientras el Alternate está activo el
  fantasma anfitrión se calla**: no hace eventos, no drena y no caza, así que los drenajes no se
  apilan y **el silencio de la casa se vuelve el aviso de que llegó**. Las evidencias ya puestas NO
  se suprimen: el contrato se sigue pudiendo resolver.
  **Los 168 están TRANSCRITOS** (2026-08-05, `faster-whisper` local, con permiso del autor; el `.tsv`
  quedó **fuera del repo** a propósito). Dos resultados que cambian el diseño: (1) las líneas
  específicas **no nombran al fantasma — son adivinanzas** sobre la etimología y el folklore del
  nombre (*"they threw beans at you, once a year"* = Setsubun = Oni), o sea que la información viene
  **cifrada** y no trivializa la identificación; y (2) el lenguaje explícito **está confinado a
  `sanity_strong_attack`**, así que la compuerta de contenido cubre un solo banco.
  **Y el Principio T.H.I.N.K. del canon resultó ser el manual del addon** (ALTERNATE.md §9): las
  cinco letras mapean una a una sobre mecánicas que ya estaban diseñadas —**HINDER es literalmente la
  frase del `about.txt` sobre ralentizarlo 15 s**, y el *"if safe to do so"* de NEUTRALIZE es la
  ventana de rezo—. De ahí salen los dos tiers de contenido sin inventar nada, porque **la propia
  cinta muestra la diapositiva corrupta y después la corrige**. Abre tres pendientes: falta grabar la
  K canónica completa, y *"IDENTIFY the class type"* es un segundo bucle de identificación sin
  diseñar.
  **Las CUATRO clases quedaron escritas** (ALTERNATE.md §11, taxonomía del autor): Doppelgänger,
  Unspeakable, Flawed Impersonator y Tulpa — **los cuatro hacen M.A.D.**, la clase dice *cómo se
  acerca*. Tres consecuencias: (1) **lo de los flexes estaba mal planteado y se invierte** — el tell
  del Doppelgänger es *expresión fija y parpadeo incorrecto*, o sea que los **cero flexes de Jeff SON
  el tell**, y el del Flawed Impersonator son proporciones imposibles, que se hacen con
  `ManipulateBoneScale` sobre los 53 huesos ValveBiped; ninguna de las dos pedía morphs, y cae la
  advertencia de que un playermodel sin flexes rompía la mecánica; (2) **cada pieza ya diseñada
  pertenece a una clase** — la aparición con `preacherwhispers` es Tipo 3 (*The Preacher* lo es), la
  posesión de TV y pantallas es **cómo se desplaza un Tulpa** y no un truco, y *"mata directamente"*
  es Tipo 2; (3) **la tarjeta T.H.I.N.K. lista tres clases y hay cuatro** — no es error del canon (la
  cinta admite información incompleta) sino **una escena**: la clase que el manual no menciona es la
  única que viaja por pantallas, o sea la única que puede alcanzarte **dentro del camión**.
  Y el espejo maldito ya tiene el feed en vivo (`DrawMirrorView`), así que la segunda superficie del
  Tulpa no necesita código nuevo.
  **VERIFICADO CONTRA LA BASE (2026-08-05, §3.3-§3.4):** la invisibilidad **ya existe y no hace falta
  HIM** — `terminator_nextbot/wraithcloaking.lua`, 202 líneas, se enciende con `ENT.IsWraith = true`,
  y **el "cuándo" es un punto de extensión declarado** (`ENT.wraithTerm_CloakDecidingTask`, `:23`):
  el Alternate no escribe el cloak, escribe ese override. De paso **se cae una reserva propia**: yo
  había marcado `$allowdiffusemodulation 0` del `.vmt` de Jeff como riesgo para el fade, y la base no
  usa `SetColor` sino **`SetMaterial`**, así que la bandera no interviene — marqué un riesgo contra
  una técnica que la base no usa. Sin medir queda el efecto de `FL_NOTARGET` mientras está
  encubierto: **es la misma bandera de la trampa de NEAD** (§19.5). Y apareció el patrón que piden
  las posesiones: HIM usa **una tabla de props con probabilidad por prop**
  (`["homeless_camera"] = { defChance = 90, func = … }`), que es exactamente la forma del 30 % de la
  TV y el 30 % de las pantallas.
  **PENDIENTE DEL AUTOR — audio que todavía no existe:** la voz del **Tipo 4** (otro registro,
  susurro/teléfono, palabras inteligibles pero extrañas), la **señal musical** que acompaña su
  posesión de pantallas —**el Ave María de Bach/Gounod por Alessandro Moreschi**, 1902-1904, dominio
  público, *bajando una transferencia limpia y no un remaster*— y la **K canónica** de T.H.I.N.K.
  La señal musical **es el temporizador de la ventana de escape del camión**, así que su duración es
  una decisión de diseño y no de estética.
  **Diseño abierto y escrito: [docs/ALTERNATE.md](docs/ALTERNATE.md)** (2026-08-04). Tiene banco de
  audio propio (34 `.ogg`, duraciones medidas), modelo elegido y desempacado
  (`Jeff the Hunter`, WSID `806714233`) y los seis rostros de la TV ya derivados a
  `materials/phantasmagoria/alternate/`. **El gameplay loop está ratificado por el autor**: no se
  mata, se **degrada** —crucifijo y balas cambian su estado, no su vida— y la victoria es **llegar al
  camión**. Lo que falta antes de escribir Lua: el `.vmt` propio (el del Workshop trae
  `$allowdiffusemodulation 0` y `$Selfillum 1`, los dos en contra del "modelo oscuro"),
  **cómo entra al juego** (no puede salir del sorteo normal), y **qué le dice el libro de evidencias**
  a un fantasma que no es ninguno de los 30. **Crédito del modelo RESUELTO** (2026-08-04): autor
  **SpongePierre** sobre el Hunter de L4D2 de Valve, y el ítem del Workshop es un **reupload** de
  Foxy — ya está en [docs/CREDITOS.md](docs/CREDITOS.md). Salió de leer la descripción de la página:
  el campo `creator` de la API de Steam es **el subidor**, no el autor.
- **El ritual de vuelta** del destierro: qué es y qué hace falta para ejecutarlo.
- **Las posesiones malditas: son 7 y tenemos 1.** Documentadas con sus mecánicas y costes de cordura
  en [docs/EQUIPAMIENTO.md](docs/EQUIPAMIENTO.md) §4. Sólo la **Voodoo Doll** tiene modelo; el
  **Summoning Circle** es armable hoy con las velas + el encendedor que ya están en disco, y es el
  candidato natural para el primero. Faltan modelo para Ouija, Espejo, Caja de Música, Pata de Mono
  y Tarot.
- **El detector de cuartos no va a ser perfecto** en mapas de GMod, que no fueron hechos para esto.
  Por eso hay toolgun manual y por eso §14.5 define qué pasa cuando no hay mapeo: degradar, nunca
  romper.
- **El clima**: se integra con **StormFox 2** en vez de reimplementarse (§15). Su API está verificada
  **contra el `.gma` instalado**, no sólo contra el repo — el addon está desempacado en
  `dev/other/stormfox 2/` (2026-08-02). Falta escribir el mapeo y el camino propio para quien no lo
  tenga; §15.2 ya anota las **cuatro trampas** que salieron de leer los cuerpos (`GetCurrent`
  devuelve tabla, la nieve es lluvia bajo −2 °C, `GetRainAmount` da 0 nevando, `Temperature.Get`
  crashea con un tipo inválido). **gWeather y Simple Weather sin investigar.**
- **Los tiers de equipamiento** (§16): documentados, sin implementar. Va un tier por equipo en la v1.
- **Cuántos PHANTOM aguanta un servidor.** La base corre en coroutines presupuestadas
  (`ENT.CoroutineThresh`) pero nunca se midió.

---

## Advertencia que vale para todo el proyecto

**Casi nada de lo escrito se ejerció en juego** — la excepción es la entidad mínima, cerrada en tres
corridas el 2026-08-05. Todo lo demás sigue siendo lectura. Los documentos marcan **[verificado]**
cuando algo se leyó en el código y se auditó, y **[lectura]** cuando se leyó una sola vez. Ninguna de
las dos marcas significa "funciona": significan "el código dice esto".

**Y la primera corrida mostró para qué sirve la distinción.** Las cuatro filas del fantasma salieron
verdes a la primera: la lectura de la base **era buena**. Los cuatro defectos salieron todos de la
parte que ningún documento cubría — **lo que yo agregué encima**, y cada uno por medir un escenario y
escribir sobre otro: un aviso que predijo el futuro desde un instante, un marcador de exteriores
probado en un interior, un límite de 255 bytes que descarta en vez de truncar, y un texto calibrado a
4 m mirado a 1,3 m. **La lectura del tercero aguantó; lo que no aguantó fue suponer el contexto de
uso.**
