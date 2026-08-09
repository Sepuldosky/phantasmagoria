--[[-------------------------------------------------------------------------
    Phantasmagoria - QUE ACTIVIDAD SE LE PIDIO AL MODELO, Y SI RESOLVIO

    Este archivo es el instrumento que pidio el autor con estas palabras:

        "hizo una animacion en pose T: o sea que le falta una"
        "parece que le falta animacion cuando cae, un landing animation,
         porque al tirarla queda en T"      ( tirandola con el physgun )
        "si hay algun cvar que calcule eso de la animacion para que sepas
         cual es seria bueno"

    UNA POSE T ES LA POSE DE REFERENCIA. No es "una animacion fea": es lo que
    se ve cuando NO HAY ANIMACION -- el modelo dibujado con su esqueleto de
    reposo. O sea que hay una actividad que la base pide y que no resuelve a
    ninguna secuencia, ni nuestra ni prestada de m_anm.

    ⚠ CUAL ES NO ESTA IDENTIFICADA Y ESTE ARCHIVO NO LA ADIVINA. Lo unico que
    hace es registrar QUE SE PIDIO, QUE SALIO, y SI SALIO ALGO -- que es lo que
    convierte "queda en T" en un nombre.

    ---------------------------------------------------------------------------
    POR QUE ESTA ACA Y NO ADENTRO DEL ENT

    `luaharness.py` NO PUEDE CARGAR terminator_nextbot_phantom/server.lua: no
    parsea el `continue` de GMod, asi que sobre ese archivo lo unico que corrio
    en toda la ronda 16 fue un chequeo de SINTAXIS. Un instrumento nuevo escrito
    ahi adentro nace sin poder ejercitarse fuera del juego, que es exactamente
    la situacion de ph_ghost_costura -- y esa costo una ronda entera.

    Asi que la parte que se puede probar sin motor ( el anillo, la resolucion de
    nombres, el veredicto ) vive aca, en un archivo que el arnes SI carga, y en
    el ENT quedan nada mas que las envolturas que lo llaman.

    ---------------------------------------------------------------------------
    ⚠ TODO SE DECLARA POR NOMBRE Y SE RESUELVE EN RUNTIME, Y NO ES ESTILO

    Una tabla escrita como `{ [ACT_FLINCH_CHEST] = ... }` revienta con
    `table index is nil` si ese ACT_ no existe en este build -- y no falla la
    linea: NO CARGA EL ARCHIVO ENTERO. Ya paso en la ronda 16 y dio un rojo del
    instrumento sobre codigo sano.

    Declarando los nombres como STRING y resolviendolos contra _G en runtime, un
    ACT_ que no exista es un DATO ( se reporta "no existe en este build" ) en vez
    de un archivo caido. Y de paso el instrumento sirve igual en el arnes, donde
    los numeros de los ACT_ son arbitrarios a proposito.
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

---------------------------------------------------------------------------
-- EL UNIVERSO DE ACTIVIDADES QUE LA BASE PUEDE PEDIRLE AL MODELO
---------------------------------------------------------------------------
-- ⚠ ESTA LISTA ESTA CENSADA DEL CODIGO DE LA BASE, NO RECORDADA. Sale de un
-- grep de las seis maneras en que una actividad puede llegar al modelo
-- ( TranslateActivity, StartActivity, DoGesture, DoPosture, AddGesture,
-- AddGestureSequence ) sobre los 71 archivos del addon Terminator, mas la tabla
-- MotionTypeActivities. Si la lista estuviera incompleta, el comando de abajo
-- daria verde sobre una actividad que nunca miro -- que es el modo de falla que
-- ya se pago con las "284 portables" contadas sobre la unidad equivocada.
--
-- La columna `cubre` dice quien tiene una secuencia para eso, MEDIDO fuera del
-- juego con dev/phastools/mdlacts.py sobre m_anm.mdl y sobre ghost_girl.mdl.
-- No se usa para el veredicto -- el veredicto lo da SelectWeightedSequence en
-- vivo -- pero es lo que deja leer un rojo sin ir a buscar contra que.
PHANTASMAGORIA.ActUniverse = {
    -- LAS SIETE DEL MOVIMIENTO. Llegan por SetupMotionType -> MotionTypeActivities
    -- -> TranslateActivity -> StartActivity. El ACT_MP_* nunca llega al modelo:
    -- lo que llega es el ACT_HL2MP_* de la derecha.
    { act = "ACT_HL2MP_IDLE",         via = "parado",              cubre = "nuestra idle_all_01" },
    { act = "ACT_HL2MP_WALK",         via = "caminando",           cubre = "nuestra walk_all" },
    { act = "ACT_HL2MP_RUN",          via = "corriendo",           cubre = "nuestra run_all_01" },
    { act = "ACT_HL2MP_IDLE_CROUCH",  via = "agachado quieto",     cubre = "nuestra cidle_all" },
    { act = "ACT_HL2MP_WALK_CROUCH",  via = "agachado andando",    cubre = "nuestra cwalk_all" },
    { act = "ACT_HL2MP_SWIM",         via = "nadando",             cubre = "nuestra swimming_all" },
    { act = "ACT_HL2MP_JUMP_SLAM",    via = "saltando",            cubre = "nuestra jump_slam" },

    -- EL GESTO DE ATERRIZAJE, motionoverrides.lua:3456. Es DoGesture, no
    -- StartActivity: no pasa por SetupActivity y no aparece en GetSequence().
    { act = "ACT_LAND",               via = "al aterrizar ( gesto, caida >= 50 u )",
      cubre = "nuestra jump_land" },

    -- ⚠ LOS OCHO FLINCH, Y CINCO NO EXISTEN EN NINGUN LADO.
    -- damageandhealth.lua:583-591 mapea hitgroup -> ACT_FLINCH_* y los toca con
    -- `AddGesture( gesture )` DIRECTO ( :634 ): no pasa por TranslateActivity ni
    -- por DoGesture, y no comprueba que la secuencia exista.
    --
    -- Medido con mdlacts.py sobre m_anm.mdl:
    --   PHYSICS 3 secuencias · HEAD 3 · STOMACH 3
    --   CHEST 0 · LEFTARM 0 · RIGHTARM 0 · LEFTLEG 0 · RIGHTLEG 0
    --
    -- Y nuestro modelo no declara ninguna. O sea que cinco de los ocho grupos de
    -- impacto piden una actividad que NO TIENE SECUENCIA. Esto es un hallazgo de
    -- este bloque y NO estaba en la lista de sospechosos del handoff.
    --
    -- ⚠ PERO NO ES, TODAVIA, LA EXPLICACION DE LA POSE T QUE REPORTO EL AUTOR:
    -- el la vio TIRANDO EL BOT CON EL PHYSGUN, y el dano de caida entra por
    -- HITGROUP_GENERIC ( 0 ), que mapea a ACT_FLINCH_PHYSICS -- de los tres que
    -- SI existen. Se listan igual porque son actividades sin secuencia
    -- confirmadas, y porque el instrumento tiene que poder separarlas: si el
    -- dump muestra un FLINCH sin resolver justo antes de la T, ya esta.
    { act = "ACT_FLINCH_PHYSICS",     via = "dano generico / caida ( hitgroup 0 )",
      cubre = "m_anm, 3 secuencias" },
    { act = "ACT_FLINCH_HEAD",        via = "dano en la cabeza",   cubre = "m_anm, 3 secuencias" },
    { act = "ACT_FLINCH_STOMACH",     via = "dano en el abdomen",  cubre = "m_anm, 3 secuencias" },
    { act = "ACT_FLINCH_CHEST",       via = "dano en el pecho",    cubre = "NADIE -- medido 0 en m_anm" },
    { act = "ACT_FLINCH_LEFTARM",     via = "dano brazo izq",      cubre = "NADIE -- medido 0 en m_anm" },
    { act = "ACT_FLINCH_RIGHTARM",    via = "dano brazo der",      cubre = "NADIE -- medido 0 en m_anm" },
    { act = "ACT_FLINCH_LEFTLEG",     via = "dano pierna izq",     cubre = "NADIE -- medido 0 en m_anm" },
    { act = "ACT_FLINCH_RIGHTLEG",    via = "dano pierna der",     cubre = "NADIE -- medido 0 en m_anm" },

    -- ACT_MP_JUMP_START, motionoverrides.lua:3011. NINGUNA de las dos tablas de
    -- traduccion lo tiene como clave -- ni la de la base ni la nuestra -- asi que
    -- TranslateActivity cae a su fallback y devuelve ( IdleActivity, false ). El
    -- `false` es lo que salva: `if not isAnim then return end` corta ANTES del
    -- DoGesture. Se mide igual, porque "la lectura del codigo dice que no pasa"
    -- no es lo mismo que "no pasa".
    { act = "ACT_MP_JUMP_START",      via = "al empezar un salto ( cae al fallback )",
      cubre = "no aplica: la base corta antes de usarla" },

    -- Las de arma. Un bot con DefaultWeapon = false no las pide nunca, y estan
    -- para que ESO se pueda ver en vez de suponerse.
    { act = "ACT_HL2MP_GESTURE_RANGE_ATTACK", via = "disparar ( bot desarmado: nunca )",
      cubre = "m_anm" },
}

---------------------------------------------------------------------------
-- Numero de actividad -> NOMBRE, resuelto del enum real y cacheado
---------------------------------------------------------------------------
-- No hay una funcion de GMod que haga esto, asi que se arma barriendo _G. Es
-- caro una vez y gratis despues.
--
-- ⚠ VARIOS ACT_ COMPARTEN NUMERO ( son alias ), asi que esto guarda TODOS los
-- nombres de cada numero y los junta con "/". Quedarse con el primero que
-- aparece daria un nombre que depende del orden de `pairs`, que en Lua no esta
-- definido -- o sea un instrumento que contesta distinto en dos corridas
-- identicas.
local nombrePorNumero = nil

local function construirTabla()
    nombrePorNumero = {}

    for k, v in pairs( _G ) do
        if isstring( k ) and isnumber( v ) and string.sub( k, 1, 4 ) == "ACT_" then
            local yaHay = nombrePorNumero[ v ]

            if yaHay then
                nombrePorNumero[ v ] = yaHay .. "/" .. k

            else
                nombrePorNumero[ v ] = k

            end
        end
    end
end

--- El nombre de una actividad. Devuelve tambien el numero, porque un nombre sin
--- numero no se puede cruzar con lo que imprime otro instrumento.
function PHANTASMAGORIA.ActName( act )
    if not isnumber( act ) then return "<" .. tostring( act ) .. ">" end
    if not nombrePorNumero then construirTabla() end

    local n = nombrePorNumero[ act ]

    -- Un numero sin nombre no es un error: puede ser una actividad de un addon
    -- que registro la suya. Se dice el numero y se dice que no se conoce, en vez
    -- de devolver "nil" -- que se leeria como que la actividad no existe.
    return ( n or "ACT desconocida" ) .. " (" .. act .. ")"

end

--- El numero de una actividad declarada por nombre, o nil si este build no la
--- tiene. El nil ES un dato y por eso se devuelve en vez de tirar error.
function PHANTASMAGORIA.ActNumber( nombre )
    local v = _G[ nombre ]

    return isnumber( v ) and v or nil

end

---------------------------------------------------------------------------
-- EL ANILLO
---------------------------------------------------------------------------
-- ⚠ POR QUE UN ANILLO Y NO UN PRINT EN VIVO. El sintoma dura menos de un
-- segundo y le pasa al autor mientras arrastra el bot con el physgun: pedirle
-- que mire la consola en ese momento es pedirle que no mire el fantasma. El
-- anillo deja que el dato se busque DESPUES, que es cuando se sabe que hay algo
-- que buscar.
--
-- 64 eventos: con el bot quieto se escribe uno cada varios segundos ( solo los
-- CAMBIOS ), y en una caida se escriben tres o cuatro. 64 cubre de sobra el
-- "recien lo tire" sin que la consola sea ilegible.
local CAPACIDAD = 64

local anillo, proximo, total = {}, 1, 0

--- Borra el anillo. Existe para que el autor pueda dejarlo limpio JUSTO ANTES de
--- tirar el bot: un dump de 64 eventos viejos con el que importa al final es un
--- dump que no se lee.
function PHANTASMAGORIA.ActLogClear()
    anillo, proximo, total = {}, 1, 0

end

--[[
    Anota un evento. `ev` es una tabla con:

      punto     donde se lo agarro ( "Translate", "Start", "Gesture", ... )
      pedida    la actividad que entro, numero
      salida    la que salio ( solo en Translate ), numero o nil
      seq       el indice de secuencia elegido, o nil si el punto no elige
      seqName   su nombre
      resolvio  false cuando NO hay secuencia -> el sospechoso de la pose T
      estado    una linea con lo que estaba pasando ( aire, physgun, velocidad )
      t         CurTime, o el que le pasen ( el arnes le pasa uno )

    Devuelve el evento guardado, para que el arnes pueda mirarlo.
]]
function PHANTASMAGORIA.PushActLog( ev )
    if not istable( ev ) then return nil end

    ev.n = total + 1
    anillo[ proximo ] = ev

    proximo = proximo % CAPACIDAD + 1
    total = total + 1

    return ev

end

--- Los eventos en ORDEN CRONOLOGICO, del mas viejo al mas nuevo.
--- El anillo guarda desordenado a proposito ( escribir es O(1) ), asi que
--- desenrollarlo es trabajo de la lectura y no de la escritura.
function PHANTASMAGORIA.ActLogEvents()
    local out = {}

    -- Con menos de CAPACIDAD eventos, el anillo todavia no dio la vuelta y las
    -- posiciones altas estan vacias: se recorre 1..total. Pasada la vuelta se
    -- arranca en `proximo`, que es la posicion mas VIEJA.
    if total < CAPACIDAD then
        for i = 1, total do out[ #out + 1 ] = anillo[ i ] end

    else
        for i = 0, CAPACIDAD - 1 do
            out[ #out + 1 ] = anillo[ ( proximo - 1 + i ) % CAPACIDAD + 1 ]

        end
    end

    return out

end

--- Cuantos se anotaron desde que arranco. NO es #eventos: el anillo tira los
--- viejos, y un dump de 64 sobre 900 eventos totales tiene que decir que hubo
--- 900 -- si no, se lee como que eso es todo lo que paso.
function PHANTASMAGORIA.ActLogTotal()
    return total

end

--[[
    LA LINEA DE UN EVENTO. Se arma aca y no en el comando porque es lo unico que
    el arnes puede comprobar sin motor -- y porque el formato es la mitad del
    instrumento: una lista de numeros sin el "NO RESOLVIO" al lado es una lista
    que hay que interpretar.
]]
function PHANTASMAGORIA.ActLogLine( ev )
    if not istable( ev ) then return "" end

    local partes = {
        string.format( "%7.2f", ev.t or 0 ),
        string.format( "%-9s", ev.punto or "?" ),
        PHANTASMAGORIA.ActName( ev.pedida ),
    }

    -- La flecha solo cuando la actividad CAMBIO. Un "X -> X" en cada linea es
    -- ruido que tapa las dos o tres lineas donde de verdad cambio.
    --
    -- ⚠ PERO EL "NO CAMBIO" HAY QUE DECIRLO, Y EN LA r18 NO SE DIJO. El dump
    -- trajo cuatro veces
    --     1370.67  Translate  ACT_LAND (33)  [en el piso 0 u/s]
    -- una linea PELADA, que se lee igual que un evento al que no se le anoto
    -- salida. Son cosas distintas: "la base devolvio la misma actividad" es una
    -- medicion, "no hay dato de salida" es la ausencia de una. *Un formato que
    -- borra la diferencia entre un dato y su ausencia deja que el lector elija,
    -- y el lector elige el que esperaba.*
    if ev.salida ~= nil and ev.salida ~= ev.pedida then
        partes[ #partes + 1 ] = "-> " .. PHANTASMAGORIA.ActName( ev.salida )

    elseif ev.salida ~= nil then
        partes[ #partes + 1 ] = "( sin traducir: sale la misma )"

    end

    if ev.seq ~= nil then
        partes[ #partes + 1 ] = "seq " .. tostring( ev.seq ) ..
            " (" .. tostring( ev.seqName ) .. ")"

    elseif ev.seqName then
        -- Sin numero de secuencia pero CON motivo. La version anterior no
        -- imprimia nada en este caso, asi que el evento del `Gesture
        -- ACT_INVALID` -- la pose T -- salio en el dump de la r17 como una linea
        -- pelada, indistinguible de una traduccion normal.
        partes[ #partes + 1 ] = "( " .. tostring( ev.seqName ) .. " )"

    end

    -- ⚠ ESTA ES LA COLUMNA POR LA QUE EXISTE EL ARCHIVO. Va con marca visible y
    -- en mayusculas: es la unica linea que hay que encontrar en un dump de 64.
    if ev.resolvio == false then
        partes[ #partes + 1 ] = "<<<< NO RESOLVIO -- POSE DE REFERENCIA ( T )"

    elseif ev.resolvio == nil and ev.seqName then
        partes[ #partes + 1 ] = "<<<< NO SE PUDO PREGUNTAR"

    end

    if ev.estado and ev.estado ~= "" then
        partes[ #partes + 1 ] = "[" .. ev.estado .. "]"

    end

    return table.concat( partes, "  " )

end

--- Los sospechosos: los eventos que no resolvieron. Se devuelven aparte porque
--- en un dump de 64 lineas la que importa se pierde, y porque el veredicto del
--- comando es sobre ESTOS y no sobre el largo del dump.
function PHANTASMAGORIA.ActLogUnresolved()
    local out = {}

    for _, ev in ipairs( PHANTASMAGORIA.ActLogEvents() ) do
        if ev.resolvio == false then out[ #out + 1 ] = ev end

    end

    return out

end

--[[
    Los eventos donde NO SE PUDO PREGUNTAR, que son un tercer estado y no la
    ausencia de uno.

    ⚠ ESTA FUNCION EXISTE POR EL DEFECTO QUE SE COMIO EL RESULTADO DE LA r17. El
    anillo guardaba tres estados en `resolvio` -- true, false y nil -- y el
    veredicto solo miraba `false`. Los `nil` ( la consulta al modelo erroreo )
    caian en el mismo saco que los resueltos, asi que el comando pudo imprimir
    la pose T y despues afirmar «ninguna actividad quedo SIN RESOLVER».

    *Tres estados con dos cuentas: el tercero se reparte solo, y siempre hacia el
    lado que uno no queria.*

    ⚠ Y solo cuenta los eventos que INTENTARON resolver. `Translate` no elige
    secuencia -- no es que no haya podido preguntar, es que no pregunta -- asi
    que un `resolvio = nil` ahi es correcto y no es un sin-dato. El discriminante
    es `seqName`: lo pone `resolver()` en las tres salidas y solo en ellas.
]]
function PHANTASMAGORIA.ActLogNoData()
    local out = {}

    for _, ev in ipairs( PHANTASMAGORIA.ActLogEvents() ) do
        if ev.resolvio == nil and ev.seqName ~= nil then out[ #out + 1 ] = ev end

    end

    return out

end

--[[
    ⚠ QUE PASO EN LA VENTANA -- O SEA SI EL SINTOMA LLEGO A PROVOCARSE.

    ESTA FUNCION EXISTE POR LA r18, Y POR LA FILA QUE DECIDIA. La 03 exigia que
    los DOS defectos del arma volvieran juntos con `pickup 1`; volvio uno
    ( las traducciones `*_AR2` ) y el otro no. Leido de frente eso refuta el
    diagnostico. Pero el dump, mirado con la hora en la mano, dice otra cosa:

        1370.67 .. 1377.96   cuatro ACT_LAND      <- SIN arma
        1393.45 .. 1393.89   las lineas *_AR2     <- CON arma, y sin caidas
        1409.13 en adelante  vuelven sin sufijo   <- ya la solto

    o sea que en toda la ventana NO HUBO NI UN ATERRIZAJE CON EL ARMA EN LA
    MANO: el segundo defecto no se refuto, no se PROVOCO. Y el comando dijo
    «ninguna actividad quedo SIN RESOLVER», que se lee como un descarte.

    *Un instrumento que no puede decir si el sujeto paso por el punto de medida
    convierte "no lo provoque" en "no pasa".* Es el mismo defecto de familia que
    contar los ausentes como aprobados, del otro lado: contar los ausentes como
    REFUTADOS.

    Devuelve una tabla con la cuenta de lo que la ventana contiene, no con lo
    que se buscaba. El veredicto lo arma quien la lee.
]]
function PHANTASMAGORIA.ActLogCenso( eventos )
    eventos = eventos or PHANTASMAGORIA.ActLogEvents()

    -- Por NOMBRE y en runtime, como todo lo de este archivo: en el arnes los
    -- numeros de los ACT_ son arbitrarios a proposito, y una tabla indexada por
    -- la constante no cargaria.
    local land = PHANTASMAGORIA.ActNumber( "ACT_LAND" )

    local c = {
        eventos = #eventos,
        aterrizajes = 0,          -- eventos con ACT_LAND como actividad pedida
        aterrizajesConArma = 0,   -- ... y con un arma en la mano en ese instante
        conArma = 0,
        sinResolver = 0,
        sinDato = 0,
        armas = {},               -- los nombres, para que "con arma" sea comprobable
        landConocida = land ~= nil,
    }

    local vistas = {}

    for _, ev in ipairs( eventos ) do
        local armado = isstring( ev.arma ) and ev.arma ~= ""

        if armado then
            c.conArma = c.conArma + 1

            if not vistas[ ev.arma ] then
                vistas[ ev.arma ] = true
                c.armas[ #c.armas + 1 ] = ev.arma

            end
        end

        if land and ev.pedida == land then
            c.aterrizajes = c.aterrizajes + 1
            if armado then c.aterrizajesConArma = c.aterrizajesConArma + 1 end

        end

        if ev.resolvio == false then
            c.sinResolver = c.sinResolver + 1

        elseif ev.resolvio == nil and ev.seqName ~= nil then
            c.sinDato = c.sinDato + 1

        end
    end

    return c

end
