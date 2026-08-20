# CORRIDA — el hunt directo · r1 (2026-08-20)

Planilla: `dev/checks/phantasmagoria-hunt-directo-r1.html` (fuera de git, por eso el reporte se
guarda acá) — 14 filas.
Bloque: `lua/entities/terminator_nextbot_phantom/server_hunt.lua` + tres enganches. Commits
`f78a0ae` y `d60dc5a`. CHANGELOG **(64)**.
Handoff de origen: `dev/HANDOFF_phantasmagoria_hunt_directo.md`.

**Resultado: 4 pasa · 0 falla · 10 sin correr (de 14).** Ninguna roja.

**Y el veredicto que ninguna fila mide**, textual del autor: *«el hunt directo probándolo ingame está
bien como gameplay, el bot hace lo que se supone que debe hacer»*. La corrida quedó a medias porque
el autor se fue a almorzar, no porque algo se cayera.

⚠ Este archivo **baja una fila de verde** (la 04, a *pasa parcial*) y **no sube ninguna**. Las dos
filas que el autor dejó en `SIN CORRER` con logs fuertes —la 01 y la 02— se quedan donde están: les
falta la banda de distancia declarada, y el §4.3 del handoff existe porque en esta misma
investigación una predicción correcta se dio por refutada con un log tomado en la banda equivocada.

---

## 1 · Lo que la corrida CERRÓ — y es más de lo que dice el conteo

### ⭐⭐⭐ El pedido del autor está entero en el log de la fila 02

```
movement_followenemy                   hunt: derecho a el
movement_approachlastseen              where did they go
movement_approachforcedcheckposition   i reached the goal and there's another spot i can check
movement_search                        i got there but nobody's here
movement_followenemy                   hunt: derecho a el
movement_duelenemy_near                i gotta punch em
```

**Perseguir → perder → buscar → volver a perseguir**, que es palabra por palabra el alcance que puso
el autor al abrir el bloque. Y no aparece ni `movement_watch` ni `movement_stalkenemy`.

Lo que lo vuelve una medición y no una impresión: **el motivo dice de quién es la decisión.**
`hunt: derecho a el` lo escribe nuestra escalera; la base dice
`ea, im just gonna rush them, nothing fancy`, que es lo que sale en el log de la fila 01. Los dos
motivos conviven en la misma corrida y sobre el mismo fantasma (#565), así que el A/B no depende de
acordarse de en qué estaba la perilla: **está en el texto de la línea**.

### ⭐⭐ La fila 01 cierra, sin proponérselo, la mitad más difícil del §3.4

En su log sale `movement_biginertia   i ran out of unreached spots, going back`.

Esa línea es el `elseif fails < 10` de `shared.lua:8209`, y para llegar ahí hay que **no** haber
entrado en el `elseif` de arriba:

```lua
elseif not self:IsMeleeWeapon( self:GetWeapon() ) and self:GetWeaponRange() > 2000 then
    self:StartTask( "movement_perch", nil, "i ran out of places, and i have a real weapon" )
```

Con `truerange 0` y el fantasma desarmado ese perch es **obligatorio** (`GetWeaponRange` devuelve
`math.huge`). O sea que la línea prueba **dos cosas a la vez**: que `truerange` estaba en 1, y que el
perch de `:8201` quedó cerrado. **Ése es el error de Lua con stack que el §3.4 prometía apagar
solo**, y quedó medido de rebote en una fila que está marcada sin correr.

### El contacto no es teoría: corrió 64 veces sin un error

61 disparos en la P0 y 3 en la fila 03, los 64 con `sin efecto` — o sea que `TakeDamageInfo` se
ejecutó y el jugador sobrevivió, porque el autor jugaba con `god`. La cadena entera del §3.5
—distancia en vivo → traza contra el mundo → hook `PhantasmagoriaGhostCatch` → `ability.onCatch` →
daño— corrió 64 veces. Lo único de la fila 09 que queda sin medir es **la muerte**.

Y de paso: `vetados por hook 0 · banish sin implementar 0` dice que ningún tipo trae `ability`
todavía, que es lo que el §7 anticipaba.

### La fila 00: 32 tareas registradas, 8 corriendo

`movement_watch` y `movement_stalkenemy` figuran como *«solo registrada: NO está corriendo»*. Es
exactamente la promesa del §3.1: **el hunt las cierra por estado, no borrándolas**, y el evento de
mirar fijo del Diseño §10 sigue teniendo con qué existir el día que se escriba.

⚠ Lo que esta fila **no** dice, y hay que leerlo con cuidado: que ese evento ande. Mide que las
tareas sigan en el registro, no que alguien las use.

### Los tres sitios de llamada están vivos

`perro ticks 22505` · `compuerta vistas 1401` · `escalera ve 44 · no ve 48`. Ninguno en cero, así que
la precondición del §4.1 se cumple y las filas que cuelgan de los contadores son legibles.

---

## 2 · Lo que la corrida DESTAPÓ

### ⚠⚠⚠ (A) El perro guardián acusaba a dos mecanismos APAGADOS — arreglado en esta sesión

Lo vio el autor y lo escribió como pregunta al costado de la P0:

> *«cuando está en calma, el watchdog dice que está zombie cuando en realidad ese estado no importa,
> ese watchdog no debería ser para el hunt?»*

**Pasó dos veces, las dos en calma**: el #93 en la P0 y el #59 en la fila 05, este último con
`huntdirect` ya en 0. Y el mensaje decía, textual, *«un StartTask que entró en m_ActiveTasks sin
callbacks, o un desvío que cayó en el early-out de taskoverride.lua:167»*.

**Las dos causas están apagadas fuera del hunt**, y se leyó el código para confirmarlo:

| mecanismo | dónde | por qué no puede ser |
|---|---|---|
| la compuerta | `phantom_HuntTaskGate` | sale por `if not phantom_Hunting` y por `if not cvHuntDirect` |
| la escalera propia | `EnemyAcquired` | delega en `BaseClass.EnemyAcquired` con la misma condición |
| el corte de estado | `phantom_HuntSwitched` | sale por la guarda de `huntdirect`, y además en la fila 05 nadie cambió de estado |

O sea que el episodio es **un agujero de la base sola**. La misma fila 05 muestra cómo termina cuando
es de ella: después del rescate viene `movement_handler   reallystuck SUCCESS`.

**El arreglo separa la cuenta y la culpa, no el rescate.** El episodio se cuenta ahora en dos
casilleros (`N en HUNT ( de este bloque ) · N en calma ( de la base sola )`) y el mensaje dice cuál de
los dos es, con los valores de `phantom_Hunting` y `huntdirect` adentro del texto. **El rescate se
dejó en los dos estados a propósito**: sacarlo cambiaría el IDLE, que este bloque sólo tenía que no
romper, y el gameplay que el autor acaba de aprobar corrió con el perro puesto.

> *Un instrumento que nombra una causa que no pudo correr no está midiendo: está eligiendo.*

⚠ Y queda una decisión que es del autor: **¿el rescate tiene que existir en calma?** Está en el §5.

### ⚠⚠ (B) La fila 04 está en verde con UNA SOLA mitad del A/B — y la otra mitad no está donde parece

**Lo que el log pegado sí prueba, y es sólido:** con `truerange 0` aparecen las dos,
`ea, camp or perch, perch` y `ea, camp or perch, camped because we're already in a good spot`, las dos
desde `EnemyAcquired` (`shared.lua:2458`). Y el log **se demuestra a sí mismo** que la perilla estaba
en 0: con la perilla en 1 esas dos líneas son imposibles, porque `doCamp` exige `notMelee` y
`IsMeleeWeapon` de un fantasma desarmado devuelve `true` (`server_hunt.lua:356`).

**Lo que no está: la mitad de tratamiento.** Y la candidata obvia **no sirve**. En la fila 01
`truerange` estaba en 1 y camp no salió, pero eso no discrimina:

```lua
local campIsGood = ( boredOrRand and not veryHighHealth ) or weapRange > 6000   -- shared.lua:2405
```

Con `truerange 1` muere el segundo disyunto (`weapRange` = 64) **y** con el fantasma a HP lleno muere
el primero (`veryHighHealth = myHp == maxHp`). La ausencia queda sobredeterminada.

> *Con dos candados posibles y uno solo medido, una ausencia no dice cuál de los dos cerró.*

**Cómo se cierra, y es una corrida de un minuto:** fantasma **HERIDO** —la fila 04 ya lo tenía, hay
líneas de `[Corpus:caliber]` en su propio log— a **más de 1400 u**, con `huntdirect 0` y
`truerange 1`, y no tiene que aparecer `ea, camp or perch`. Es el mismo escenario del control
cambiando **una** perilla.

Queda marcada **PASA PARCIAL**: el mecanismo está bien y el control es fuerte, pero lo que la fila
afirma es un ida y vuelta, y hay ida sola.

### ⚠⚠ (C) La fila 05 NO es binaria, y el handoff la anunciaba al revés

El handoff la daba por la más probable de quedar sin correr *«porque no se puede forzar»*. El autor la
forzó: *«al iniciar uno nuevo siempre hay un error de Lua con truerange 0»*. Y ese *siempre* tiene un
número:

```lua
local chanceNeeded = 15
if wepRange == math.huge or SqrDistGreaterThan( wepRange, 2500 ) then
    chanceNeeded = 85                                              -- shared.lua:8298
end
...
elseif table.Count( data.beenAreas ) > self.RunSpeed * 3 and math.random( 0, 100 ) < chanceNeeded then
    self:StartTask( "movement_perch", nil, "i wandered a long time, ill wait here" )
```

La perilla **no apaga** ese perch: lo baja de **85 % a 15 %**. Consecuencia directa para la planilla:
la mitad de control es fuerte (85 % explica el *«siempre»*), pero **una sola corrida con
`truerange 1` y sin perch no cierra nada** — 85 de cada 100 salen así por azar. El criterio tiene que
ser de conteo (N spawns y la proporción), o la fila se apoya en la 04, que sí es determinista.

⚠ **Y hay TRES perch distintos, que el handoff trataba como uno solo:**

| sitio | motivo | qué lo cierra con `truerange 1` | ¿determinista? |
|---|---|---|---|
| `shared.lua:2458` | `ea, camp or perch, perch` | `notMelee` pasa a false | **sí** |
| `shared.lua:8201` | `i ran out of places, and i have a real weapon` | `not IsMeleeWeapon` pasa a false | **sí** — y ya salió medido (§1) |
| `shared.lua:8308` | `i wandered a long time, ill wait here` | baja el chance de 85 a 15 | **no** |

El error de Lua que el §3.4 prometía apagar es el de **`:8201`**, y ése está cerrado. El que el autor
vio en la fila 05 es el de **`:8308`**, que es otro y no se apaga del todo. Los dos se imprimen igual
—*«tried to start already active task: movement_perch»*— y **el motivo de la línea es lo único que los
separa**.

### ⚠⚠ (D) Un defecto que la fila 08 iba a heredar, encontrado leyendo un `0` — arreglado en esta sesión

El reporte del #565 dice `cortes de tarea al cambiar de estado 0` en las filas 02 y 03. No es que el
corte esté roto: es **el orden en que se flipearon las perillas**. El autor prendió el hunt con
`huntdirect` todavía en 0 (fila 01) —y `phantom_HuntSwitched` sale por su primera guarda— y recién
después subió `huntdirect` a 1 (fila 02), que no pasa por esa función. **Para ese fantasma nunca hubo
una transición con la perilla puesta**, así que la fila 08 no se puede cerrar con él.

Y leyendo eso apareció el defecto de verdad: la guarda de `huntdirect` salía **antes** de actualizar
`phantom_huntCutFor`, así que el registro de *«sobre qué valor actué»* quedaba viejo:

```
huntdirect 0 · se PRENDE el hunt      -> sale por la guarda, huntCutFor sigue en false
huntdirect 1                             ( la perilla no pasa por esta funcion )
se APAGA el hunt ( hunting = false )  -> false == false, sale por la idempotencia
=> el corte del APAGADO no ocurre
```

Y el del apagado es justo el que `server.lua:1231` llama el importante: sin él el bot se queda en
`movement_followenemy` **corriéndote atrás con la cacería apagada** — *un fantasma en calma que te
persigue, que parece un hunt y no lo es*.

**Arreglo:** con `huntdirect` en 0 el registro se pone en `nil` —*«no sé sobre qué valor actué»*— y
como `nil` no es igual ni a `true` ni a `false`, la primera transición real que llegue después corta.
El costo máximo es **un corte de más**; el de no hacerlo es un corte de menos, y de los dos errores
posibles ése es el caro.

**Para correr la fila 08:** `phantasmagoria_ghost_huntdirect 1` **primero**, `phantasmagoria_hunt 1`
después, y mirar que `cortes` suba.

### ⚠ (E) Tres números altos en un fantasma «en calma», leídos y absueltos

La P0 imprime `escalera ve 44 · no ve 48`, `compuerta vistas 1401` y `pozos salvados 507` sobre el
#612 con `enemigo ninguno` y en calma. **No es un defecto:** los tres contadores sólo suben en hunt
(`EnemyAcquired`, `phantom_HuntTaskGate` y `CanMoveRightUpToEnemy` tienen la guarda de
`phantom_Hunting`) y son **acumulativos por fantasma** — el #612 tenía 372 s de vida y ya había cazado
antes de la P0. Se deja escrito para que la próxima sesión no lo abra como uno.

⚠ **Lo que sí es de calma, y ninguna fila lo mide:** `alcance 24373 veces` y `miedo 21274 veces`.
`GetWeaponRange`, `IsMeleeWeapon` y `EnemyIsLethalInMelee` no tienen guarda de estado **a propósito**
(el §3.4 los quiere cerrados *«en toda la base»*). O sea que el IDLE del fantasma también cambió con
este bloque, y el que tendría que mirarlo es la fila 11.

### ⚠ (F) La fila 03 corrió con `god`, y eso acota lo que probó — pero no la invalida

El §4.4 prohíbe `god` **con `fearless 0`**, que es donde `EnemyIsUnkillable` mira `HasGodMode()` y el
bot cambia de conducta. La corrida fue con `fearless 1`, así que lo que la fila 03 afirma vale. Lo que
`god` se lleva puesto es **la fila 09**, y por eso los 64 contactos dicen `sin efecto`.

---

## 3 · Lo que queda: las 10 sin correr, con lo que la r1 ya les dejó a favor

| fila | qué mide | lo que la r1 ya le dejó | qué falta, exactamente |
|---|---|---|---|
| **01** | control positivo, 30-40 m | `watch`, `stalkenemy` y `flankenemy` con motivos de la base en su log; y la 04 muestra el `stalkenemy` en bucle (`i did a good stalk and i want to do more` ×3) | **declarar la banda**. Es lo único |
| **02** | el pedido, 30-40 m | la cadena entera (§1) con `hunt: derecho a el` | ídem: el `cerebro` se corrió a 33 u, no en la banda |
| **05** | el error de Lua se apaga | la mitad de control, reproducible al 85 % | un criterio de **conteo**, no de una corrida (§2C) |
| **06** | una mesa no aborta el duelo | `props salvados 0` — el override existe y nunca mordió | armar el escenario (b): mesa en el medio, y que no salga `my enemy wasnt engagable!` |
| **07** | el crouch-jump | `pozos salvados 507`; y el autor: *«no lo medí, pero sí el bot salta cuando estoy en alturas y sobre props»* | la observación no es la medición: falta ver el `approachlastseen` que no aparece |
| **08** | el corte al prender el hunt | `cortes 2` en el #612 — el mecanismo dispara | correrla **con huntdirect 1 puesto antes** (§2D) |
| **09** | el desenlace | 64 contactos, la cadena entera hasta `TakeDamageInfo` (§1) | **sacarse el `god` y morirse.** Y mirar a quién se le atribuye la muerte |
| **10** | la órbita no existe en hunt | — | frontera abierta declarada: no hay código de este bloque que la cierre |
| **11** | no romper lo que ya cerró | puertas, pisadas, correa, voz y atascos no dieron un solo error en toda la corrida | pasarlas una por una; y agregarle el IDLE del §2E |
| **12** | el cadáver conserva las armas | `tu cadaver CONSERVA tus armas ( DontDropPrimary true )` en las **tres** lecturas del `cerebro` | la mitad dinámica: morirse y contar las armas en el piso. Y el A/B con `pickup 1` |

---

## 4 · Lo que se tocó en esta sesión

Un solo archivo, `lua/entities/terminator_nextbot_phantom/server_hunt.lua` (+82 −7), con dos arreglos
que salieron de leer la corrida:

1. **El perro guardián atribuye el episodio por estado** (§2A). Contador partido en dos y mensaje que
   dice de quién es la culpa. El rescate no se movió.
2. **`phantom_huntCutFor` se invalida cuando `huntdirect` está en 0** (§2D), para que el corte del
   apagado no se pierda después de un A/B.

Controles corridos sobre el archivo ya parcheado:

```
dev/parsear_sintaxis_glua.py   -> 0 errores de sintaxis, el control roto DETECTADO
dev/auditar_ent_a_runtime.py   -> 39 archivos, 0 lecturas de ENT a runtime, el control roto DETECTADO
```

**Ninguno de los dos arreglos se corrió en juego.** Los dos son de instrumento y de A/B: no tocan la
escalera, la compuerta ni el contacto, que es lo que el autor ya aprobó como gameplay.

---

## 5 · Las dos preguntas que quedan para el autor

1. **¿El rescate del perro guardián tiene que existir en calma?** Hoy sí, y el mensaje ya dice que el
   agujero es de la base. La alternativa es dejarlo sólo en hunt y que el IDLE lo siga cerrando
   `reallystuck_handler`, como hacía antes del bloque. Es una decisión de diseño sobre el IDLE, no un
   defecto, y por eso no la tomé yo.
2. **La fila 04:** ¿la corrés vos con el fantasma herido a más de 1400 u (§2B), o la dejamos apoyada
   en el mecanismo determinista y anotada como parcial?

---

## 6 · Fronteras que la r1 **no** movió

Siguen igual que en el §7 del handoff, y ninguna fila se las acreditó: la cordura como disparador, el
evento de mirar fijo del Diseño §10, el tope de la órbita contra `sightdist`, `interceptIfWeCan`, el
flanqueo por distancia (que **ninguna** fila ejercita: `flank de cerca 0` en las tres lecturas), y los
30 tipos sin poblar (`ability.onCatch` enganchado, no poblado).

Y las dos que el handoff dejó anotadas sin explicar siguen sin explicar: el
`render se dibuja / la politica pide INVISIBLE / !! NO COINCIDEN` de `server_cloak.lua`, y el
`movement_perch` + `movement_biginertia` activas a la vez.

---

## 7 · El reporte del autor, íntegro

Pegado tal cual, con sus comentarios `//` adentro. Es la evidencia cruda de todo lo de arriba, y la
planilla vive fuera de git.

```
REPORTE — Phantasmagoria r1 · el hunt directo: escalera propia, compuerta de tareas tácticas,
las dos mitades del A/B y el desenlace con onCatch
Pasa 4 · Falla 0 · Sin correr 10  (de 14)

P0 [PASA] ⚠⚠⚠ SE CORRE PRIMERO, CON UN FANTASMA VIVO Y EN CALMA
   nota: ] phantasmagoria_ghost_cerebro
         ===== EL CEREBRO DEL HUNT ( el hunt directo, 2026-08-20 ) =====
           phantasmagoria_ghost_huntdirect        = 1   escalera propia + compuerta
           phantasmagoria_ghost_truerange         = 1   dice su alcance real
           phantasmagoria_ghost_fearless          = 1   no le teme a nadie
           phantasmagoria_ghost_reachprops        = 1   un prop no lo hace desistir
           phantasmagoria_ghost_reachdrop         = 1   un pozo no lo hace desistir
           phantasmagoria_ghost_catch             = 1   el contacto mata
           phantasmagoria_ghost_reach             = 64 u
           phantasmagoria_ghost_huntflank         = 400 u
           ENT.InformRadius                       = 0
           --- fantasma #612/s10  ( calma )  onCatch kill ---
             enemigo   ninguno
             corriendo terminator_nextbot_phantom_handler · shooting_handler · enemy_handler ·
                     reallystuck_handler · awareness_handler · trancebreaking_handler ·
                     inform_handler · movement_search
             escalera  ve 44 · no ve 48 · sin enemigo 0 · delegadas a la base 0
             compuerta vistas 1401 · DESVIADAS 0 · dejadas pasar 1401
             contacto  ticks a tiro 2949 · tapados por una pared 0 · disparados 61 · MATARON 0 ·
                       sin efecto 61 · vetados por hook 0 · banish sin implementar 0
             tu cadaver  CONSERVA tus armas   ( DontDropPrimary true )
             le contesto a la base:  alcance 24373 veces ( 24373 desarmado ) · miedo 21274 veces
                       props salvados 0 · pozos salvados 507
             perro     ticks 22505 · episodios SIN tarea de movimiento 0 · cortes de tarea 2

         //Por cierto cuando esta en calma, el watchdog dice que esta zombie cuando en realidad
         //ese estado no importa, ese watchdog no deberia ser para el hunt?

         [phantasmagoria] el fantasma #93 lleva 1.5 s SIN NINGUNA TAREA movement_*, que es el
         sintoma del zombi ( un StartTask que entro en m_ActiveTasks sin callbacks, o un desvio
         que cayo en el early-out de taskoverride.lua:167 ). Se lo rescata con movement_handler.
             1. phantom_HuntWatchdog - server_hunt.lua:1165
             2. phantom_HuntTick     - server_hunt.lua:1196
             3. unknown              - server.lua:1400

00 [PASA] ⚠⚠ la promesa del §4.0: ninguna tarea se saca del registro
   nota: ] phantasmagoria_hunt 1
             #612  hunt -> SI ( cazador )   llamadas a OnFirstRelationWithPlayer: 1
         ] phantasmagoria_ghost_where
         #612  terminator_nextbot_phantom   serie 10   nacio hace 372.3 s
             vida    818 / 900      modelo  models/phantasmagoria/ghost_male.mdl
             hunt    SI ( cazador ) enemigo Player [1][SEPULDOSKY]
             tipo    Demon ( demon )  threshold 70 %  speed.base x1.000
             al ply  yaw -89  a 31 u   mirada vs jugador 8.3 grados
             tareas  8 ACTIVAS de 32 registradas
                 * awareness_handler   * enemy_handler   * inform_handler
                   movement_flankenemy      ( solo registrada: NO esta corriendo )
                   movement_followenemy     ( solo registrada: NO esta corriendo )
                   movement_stalkenemy      ( solo registrada: NO esta corriendo )
                   movement_watch           ( solo registrada: NO esta corriendo )
                   movement_camp            ( solo registrada: NO esta corriendo )
                   movement_perch           ( solo registrada: NO esta corriendo )
                 * movement_search
                 * reallystuck_handler  * shooting_handler
                 * terminator_nextbot_phantom_handler  * trancebreaking_handler
         [Phantasmagoria] 1 fantasma(s). Navareas en el mapa: 7637.

01 [SIN CORRER] ⚠⚠⚠ EL CONTROL POSITIVO · BANDA 30-40 m
   nota: [Phantasmagoria] spawn #565  serie 11  models/phantasmagoria/ghost_girl.mdl  hunt NO
         565	movement_inertia	[NULL Entity]	nothing better to do
         565	movement_biginertia	[NULL Entity]	im bored of small wandering
         565	KILLED 1 TASKS CONTAINING: movement
         565	movement_wait	[NULL Entity]	StopMoving was called!
         ] phantasmagoria_hunt 1
             #565  hunt -> SI ( cazador )
         565	movement_biginertia	[NULL Entity]	i ran out of unreached spots, going back
         565	movement_watch	Player [1][SEPULDOSKY]	ea, watching something
         565	movement_handler	Player	all done waiting
         565	movement_followenemy	Player	ea, im just gonna rush them, nothing fancy
         565	movement_duelenemy_near	Player	i gotta punch em
         565	movement_stalkenemy	Player	thats enough looking
         565	movement_flankenemy	Player	too close
         565	movement_approachlastseen	Player	my enemy wasnt engagable!
         565	movement_search	Player	my path failed for some reason
         565	movement_followenemy	Player	ea, im just gonna rush them, nothing fancy

         [Terminator Nextbot] tried to start already active task: movement_followenemy
           with reason: ea, im just gonna rush them, nothing fancy
           1. StartTask     - taskoverride.lua:176
           2. EnemyAcquired - shared.lua:2513

         565	movement_approachlastseen	Player	they're gone and im done
         565	movement_followenemy	Player	ea, im just gonna rush them, nothing fancy
         565	movement_duelenemy_near	Player	i gotta punch em

02 [SIN CORRER] ★★★ EL PEDIDO · BANDA 30-40 m
   nota: ] phantasmagoria_ghost_huntdirect 1
         565	movement_followenemy	Player	hunt: derecho a el
         565	movement_approachlastseen	Player	where did they go
         565	movement_approachforcedcheckposition	Player	i reached the goal and there's
                                                             another spot i can check
         565	movement_search	Player	i got there but nobody's here
         565	movement_followenemy	Player	hunt: derecho a el
         565	movement_duelenemy_near	Player	i gotta punch em
         ] phantasmagoria_ghost_cerebro
           --- fantasma #565/s12  ( HUNT )  onCatch kill ---
             enemigo   Player [1][SEPULDOSKY]  a 33 u  ( ~0.8 m )   lo ve SI   a tiro SI
             corriendo ... movement_duelenemy_near
             escalera  ve 2 · no ve 0 · sin enemigo 0 · delegadas a la base 0
             compuerta vistas 6 · DESVIADAS 0 · dejadas pasar 6
             contacto  ticks a tiro 10 · disparados 1 · MATARON 0 · sin efecto 1
             le contesto a la base:  alcance 3064 · miedo 4357
                       props salvados 0 · pozos salvados 69
             perro     ticks 2401 · episodios SIN tarea 0 · cortes de tarea 0

03 [PASA] ★ BANDA MENOR A 5 m · aquí vivía el lobotimised lemming
   nota: 565	movement_followenemy	Player	hunt: derecho a el
         565	movement_duelenemy_near	Player	i gotta punch em
         565	movement_followenemy	Player	hunt: derecho a el
         565	movement_duelenemy_near	Player	i gotta punch em
         ] phantasmagoria_ghost_cerebro
           --- fantasma #565/s12  ( HUNT )  onCatch kill ---
             enemigo   Player  a 230 u  ( ~5.8 m )   lo ve SI   a tiro NO
             escalera  ve 4 · no ve 0
             compuerta vistas 10 · DESVIADAS 0 · dejadas pasar 10
             contacto  ticks a tiro 50 · disparados 3 · MATARON 0 · sin efecto 3
             le contesto a la base:  alcance 10246 · miedo 15996
                       props salvados 0 · pozos salvados 436
             perro     ticks 6736 · episodios SIN tarea 0 · cortes de tarea 0

         //Ando con GOD por eso no me mata al tocar; no veo movement_watch ni stalk al moverme
         //en circulos, no mas cuando voy muy lejos pasa a followenemy como corresponde

04 [PASA] ★★ EL ARMA · BANDA MAYOR A 1400 u (36 m)
   nota: [Phantasmagoria] spawn #59  serie 13  ghost_girl.mdl  hunt NO  tipo deogen
         59	movement_biginertia	[NULL Entity]	im bored of small wandering
         59	movement_perch	[NULL Entity]	i wandered a long time, ill wait here
         59	movement_handler	[NULL Entity]	all done waiting
         59	movement_inertia	[NULL Entity]	nothing better to do
         ] phantasmagoria_hunt 1
             #59  hunt -> SI ( cazador )

         [Terminator Nextbot] tried to start already active task: movement_perch
           with reason: ea, camp or perch, perch
           1. StartTask     - taskoverride.lua:176
           2. EnemyAcquired - shared.lua:2458
           3. callback      - shared.lua:8062

         59	movement_perch	Player	ea, camp or perch, perch
         [Corpus:caliber] terminator_nextbot_phantom  in=39.7->39.7
         //Se fue a esconder?
         59	movement_camp	Player	ea, camp or perch, camped because we're already in a good spot
         59	movement_stalkenemy	Player	im bored
         59	movement_stalkenemy	Player	i did a good stalk and i want to do more
         59	movement_stalkenemy	Player	i did a good stalk and i want to do more
         //Huntdirect es clave para tenerlo en 1 y simular el comportamiento adecuado

05 [SIN CORRER] ⚠ LA QUE MÁS PROBABLE ES QUE QUEDE SIN CORRER
   nota: [Phantasmagoria] spawn #59  serie 14  hunt NO  tipo deildegast
         59	movement_biginertia	[NULL Entity]	im bored of small wandering
         59	movement_perch	[NULL Entity]	i wandered a long time, ill wait here
         ] phantasmagoria_ghost_huntdirect 0
         59	movement_camp	[NULL Entity]	i got to my camping spot
         59	movement_perch	[NULL Entity]	i saw them before, and lost sight of them
         59	KILLED 1 TASKS CONTAINING: movement
         [Phantasmagoria] el fantasma #59 lleva 1.5 s SIN NINGUNA TAREA movement_*, que es el
         sintoma del zombi ( ... ). Se lo rescata con movement_handler.
         59	movement_handler	[NULL Entity]	phantasmagoria: rescate del perro guardian
         59	movement_wait	[NULL Entity]	wait...
         59	movement_handler	[NULL Entity]	all done waiting
         ... ( ocho ciclos de wait / all done waiting ) ...
         59	KILLED 1 TASKS CONTAINING: movement
         59	movement_handler	[NULL Entity]	reallystuck SUCCESS
         59	movement_perch	[NULL Entity]	i wandered a long time, ill wait here

         //Al iniciar uno nuevo siempre hay un error de lua con truerange 0:
         [Phantasmagoria] spawn #59  serie 15  hunt NO  tipo raiju
         59	movement_perch	[NULL Entity]	i wandered a long time, ill wait here
         [Terminator Nextbot] tried to start already active task: movement_perch
           with reason: i wandered a long time, ill wait here
           1. StartTask - taskoverride.lua:176
           2. callback  - shared.lua:8308

         //Cambio truerange a 1:
         [Phantasmagoria] spawn #59  serie 17  hunt NO  tipo shade
         59	movement_inertia	[NULL Entity]	nothing better to do
         59	movement_biginertia	[NULL Entity]	i still want to wander   ( x4 )
         59	movement_handler	[NULL Entity]	all done waiting
         59	movement_wait	[NULL Entity]	wait...
         59	movement_followsound	[NULL Entity]	 i heard something
         //Inicio sin gritar el watchdog
         59	movement_search	[NULL Entity]	look for what made the sound
         59	movement_search	[NULL Entity]	arrived, but i still want to keep searching

06 [SIN CORRER] ★ EL ESCENARIO (b) DE TU A/B — una mesa en el medio
07 [SIN CORRER] ★ EL ESCENARIO (c) — el crouch-jump
   nota: //No lo medi pero si el bot salta cuando estoy en alturas y sobre props
08 [SIN CORRER] ★★ EL SÍNTOMA DEL PASEO — prender el hunt no interrumpía nada
09 [SIN CORRER] ★★★ EL DESENLACE — el contacto mata, y pasa por onCatch
10 [SIN CORRER] ⚠ FRONTERA ABIERTA — la órbita del acecho contra sightdist
11 [SIN CORRER] ⚠⚠ NO ROMPER LO QUE YA CERRÓ
12 [SIN CORRER] ★★ EL CADÁVER — matarte ya no te desarma
```
