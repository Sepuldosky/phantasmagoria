--[[-------------------------------------------------------------------------
    Phantasmagoria - LA CORDURA, tajada B1   ( Diseno 19.8 )

    §18 diseno COMO caza el fantasma y la cordura decide CUANDO. Sin ella §18 es
    un motor sin llave. Las tres tajadas, en orden, y esta es la segunda:

      A  el TIPO      ESCRITA        ( server_type.lua )
      B  la CORDURA   por jugador, en el servidor, con sus causas
         B1  la variable + la presencia + la recuperacion + los instrumentos  <-- ESTE ARCHIVO
         B2  la esfera de los eventos: el tercer retorno `pos` en los ocho
             ( server_events.lua + ghost_flags.lua )
      C  el GATILLO   cordura por debajo del hunt.threshold DEL TIPO

    ⚠⚠ ESTE ARCHIVO ES SOLO B1, Y LA FRONTERA NO ES DE GUSTO. No dispara el
    hunt, no jubila `phantasmagoria_hunt` y no toca `server_events.lua`. Meter el
    gatillo aca haria que un rojo tuviera dos causas posibles -- la cordura o el
    gate -- y este taller ya pago por eso.

    ⚠ Tampoco toca `server_hunt.lua`, `server.lua` ni `server_stuck.lua`: OTRA
    SESION acaba de reescribir ahi COMO persigue el fantasma ( commit f78a0ae ).
    B1 escribe el numero que decide cuando empieza. Las dos cosas se encuentran
    en C, no antes.

    --------------------------------------------------------------------------
    LAS DOS FORMAS DE DRENAJE, Y POR QUE LAS DOS EXISTEN DESDE EL PRIMER DIA
    --------------------------------------------------------------------------
    Esta es la unica decision de este archivo que, escrita mal, no se arregla
    agregando codigo despues: se arregla rehaciendo B1.

      PLANO      un numero, una vez, con un motivo.
                 Las manifestaciones de §22 ( standing 5 % · mist/singing/appear
                 10 % · chase 15 % ) y los ocho eventos de B2.
                 Puerta:  PHANTASMAGORIA.DrainSanity( ply, pct, causa )

      CONTINUO   una tasa por segundo condicionada a algo que cambia tick a
                 tick. La PRESENCIA de §19.8.2 ya es de esta familia, y el rasgo
                 del Phantom ( §22.10: 0,5 %/s mientras lo mires dentro de
                 525 u, y SUMA al drenaje plano ) no entraria de ninguna otra
                 forma.
                 Puerta:  PHANTASMAGORIA.RegisterSanityRate( id, fn )

    ⚠ La forma continua NO se escribe como "llamame por tick y yo multiplico".
    Se escribe como un REGISTRO de fuentes que el tick interroga. La diferencia
    no es de estilo: con llamadas empujadas desde afuera, una fuente que dejo de
    llamar y una fuente que no existe se ven EXACTAMENTE IGUAL en el reporte
    ( cero ), y esa es la familia del nº 89 del catalogo. Interrogadas, una
    fuente inactiva dice que esta inactiva y por que.

    --------------------------------------------------------------------------
    EL CONTADOR VA ANTES DE LA PERILLA. SIEMPRE.   ( catalogo nº 100 )
    --------------------------------------------------------------------------
    Toda causa acumula lo que HABRIA hecho aunque su perilla este en 0. La
    perilla suprime el EFECTO, nunca la cuenta. Sin esto la fila 00 de la
    planilla -- "con todas las perillas en 0 la barra no se mueve" -- no
    distingue "el control funciono" de "el fantasma nunca estuvo cerca", que es
    el mismo cero que da un mecanismo que jamas corrio.

    Por eso el reporte, con la perilla en 0, imprime:
        presencia calma    0,0 %  aplicado   ( CONTROL: 728 ticks en la esfera,
                                               habria drenado 18,2 % )

    --------------------------------------------------------------------------
    LO QUE SE DECIDIO EL 2026-08-20 Y §19 DEJABA ABIERTO   [ decision del autor ]
    --------------------------------------------------------------------------
      · La regeneracion pasiva va con el numero del autor: 0,2 %/s CON RETARDO
        de 45 s ( §19.8.5 ). Sin retardo el punto de empate cae en f = 2/3 y el
        hunt.threshold no se alcanza nunca.
      · Los techos NO son el mismo numero: el goteo pasivo llega a 80 % y la
        zona segura a 100 %. Asi las tres vias tienen territorio propio -- el
        goteo te devuelve la partida, el camion te deja impecable, y la pastilla
        es lo unico instantaneo.
      · Las pastillas se registran como items de Cargo ( soft-dep ) ademas del
        andamio de consola.

    --------------------------------------------------------------------------
    ⚠ LA ZONA SEGURA NO EXISTE, Y ESO SE MIDIO ANTES DE ESCRIBIR ESTO
    --------------------------------------------------------------------------
    §19.8.5 lista cuatro vias de goteo y una es la zona segura ( +0,4 %/s ).
    Censo del 2026-08-20 sobre `lua/`: CERO apariciones de
    `terminator_blocktarget` y ninguna entidad camion -- y §18.1 dice que la
    zona SALE de esa entidad ( *"se spawnea el camion y su radio es la zona"* ).
    O sea que la via esta disenada y no tiene sujeto.

    Se registra igual, como fuente continua INACTIVA que dice por que lo esta.
    El motivo no es prolijidad: sin su renglon, la fila 02 de la planilla no
    distingue "la zona no recupera" de "la zona no existe", y las dos se
    imprimen como un cero. `PHANTASMAGORIA.InSafeZone` es la costura por donde
    entra el dia que §18.1 se escriba, y ningun llamador se entera.

    --------------------------------------------------------------------------
    LO QUE ESTE ARCHIVO NO HACE, Y DONDE VIVE CADA UNO
    --------------------------------------------------------------------------
      · No DIBUJA la cordura. §19.9.4: el indicador es el mundo. La barrita de
        Cargo y la pantalla TEAM SANITY del camion son consumidores, y cuando
        dibujen tienen que ponerle ELLOS la oscilacion de ±2 % ( §19.8.7 ): el
        valor guardado es exacto a proposito, o el gatillo de C comparara contra
        `hunt.threshold` un numero con ruido y ninguna corrida sera reproducible.
      · No mide ACTIVIDAD ( §19.3 ). Tiene numeros desde §22 y no es esto.
      · No cobra los ocho eventos. Es B2, y su renglon ya existe en el desglose
        para que el dia que llegue no haya que tocar el instrumento.
---------------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

PHANTASMAGORIA = PHANTASMAGORIA or {}

---------------------------------------------------------------------------
-- LOS TIERS DE LA MEDICACION -- SHARED, y no es un detalle de orden
---------------------------------------------------------------------------
-- Las defs de Cargo se registran en LOS DOS REALMS o el grid del cliente no las
-- dibuja y el menu "Use" no aparece: el snapshot de Cargo solo transporta defs
-- autogeneradas, y `isfunction( def.onUse )` se evalua del lado del cliente
-- sobre algo que no viaja por JSON. Es leccion pagada por Craving en su primera
-- pasada en juego ( corpus_craving_items.lua, encabezado ), no una precaucion.
-- Por eso esta tabla y el registro viven ARRIBA del `if SERVER`.
--
-- ⚠⚠ Y LOS TRES NO SON LA MISMA PASTILLA TRES VECES. El sonido lo delata:
-- t1 es una BEBIDA, t2 son PASTILLAS y t3 es ADRENALINA. El efecto es el mismo
-- mecanismo con tres numeros, pero el feedback es de tres objetos distintos, asi
-- que el clip sale del TIER y no de la accion -- un unico sonido para los tres
-- suena mal justo en el momento en que el jugador esta gastando plata.
--
-- Y por eso la funcion se llama `UseSanityMed` y no `TakePills`: *el nombre de
-- una funcion que atiende tres cosas tiene que nombrar lo que hacen, no a la
-- primera de las tres.* "Adrenalina" no es "pastilla", y el nombre mentiroso
-- caeria justo en el tercio mas caro.
--
-- Los +25/+40/+60 son de §19.8.5 y NO los 40/45/50 de la fuente: tres tiers
-- separados por 5 puntos son el mismo item con tres precios. Los 20/40/60 USD
-- salen de la regla de tiers de EQUIPAMIENTO §10 ( T2 x2, T3 x3 ). El peso NO se
-- estima aca: sale de `prop_data_eq.lua`, que ya lo decidio por familia ( 0,2 ).
PHANTASMAGORIA.SanityMeds = {
    [ 1 ] = {
        id      = "med_i",
        cargo   = "phantasmagoria_sanity_med_i",
        nombre  = "Sanity Medication I",
        que     = "bebida",
        pct     = 25,
        precio  = 20,
        peso    = 0.2,
        modelo  = "models/phantasmagoria/eq/sanity_medication_i.mdl",
        sonido  = "phantasmagoria/equipment/sanity_meds/t1_drink.ogg",
        trivia  = "Tier I. A bitter draught. Restores 25% sanity on the spot.",
    },
    [ 2 ] = {
        id      = "med_ii",
        cargo   = "phantasmagoria_sanity_med_ii",
        nombre  = "Sanity Medication II",
        que     = "pastillas",
        pct     = 40,
        precio  = 40,
        peso    = 0.2,
        modelo  = "models/phantasmagoria/eq/sanity_medication_ii.mdl",
        sonido  = "phantasmagoria/equipment/sanity_meds/t2_pills.ogg",
        trivia  = "Tier II. Prescription pills. Restores 40% sanity on the spot.",
    },
    [ 3 ] = {
        id      = "med_iii",
        cargo   = "phantasmagoria_sanity_med_iii",
        nombre  = "Sanity Medication III",
        que     = "adrenalina",
        pct     = 60,
        precio  = 60,
        peso    = 0.2,
        modelo  = "models/phantasmagoria/eq/sanity_medication_iii.mdl",
        sonido  = "phantasmagoria/equipment/sanity_meds/t3_adrenaline.ogg",
        trivia  = "Tier III. Adrenaline shot. Restores 60% sanity on the spot.",
    },
}

---------------------------------------------------------------------------
-- El registro en Cargo, con MAS DE UNA SEÑAL y guarda de idempotencia
---------------------------------------------------------------------------
-- ⚠⚠ NO cuelga de `Corpus.OnReady`, y no es preferencia: esa barrera NO DISPARA
-- EN EL REALM CLIENTE ( medido en Corpus: 4.413 defs y 3 barras del StatusPanel
-- colgadas, sin un solo error de Lua ). Registrar ahi dejaria las tres defs
-- vivas en el servidor e inexistentes en el grid, que es exactamente el modo de
-- falla que esta seccion existe para evitar.
--
-- Cuelga entonces de TRES señales: el intento inmediato ( por si Cargo ya boteo,
-- que pasa cuando este addon carga despues ), `InitPostEntity`, y un reintento
-- con techo. La guarda de idempotencia hace que sobren dos de las tres, y la
-- linea de log dice CUAL disparo y CUANTAS defs solto -- sin eso, "se registro"
-- y "se registro tres veces" se leen igual.
local CARGO_INTENTOS_MAX = 20
local cargoHecho, cargoIntentos, cargoQuien = false, 0, nil

local function registrarEnCargo( quien )
    if cargoHecho then return false end

    cargoIntentos = cargoIntentos + 1

    if not Corpus or not isfunction( Corpus.GetModule ) then return false end

    local cargo = Corpus.GetModule( "cargo" )
    if not istable( cargo ) or not istable( cargo.Items ) or not isfunction( cargo.Items.Register ) then
        return false

    end

    -- Categoria ABIERTA: Cargo la auto-registra si nadie la declaro. El registro
    -- explicito solo le fija etiqueta y orden, y por eso va con guarda de
    -- existencia en vez de asumirse.
    if isfunction( cargo.Items.RegisterCategory ) then
        cargo.Items.RegisterCategory( "medical", "Medical", 40 )

    end

    local n = 0

    for tier, med in ipairs( PHANTASMAGORIA.SanityMeds ) do
        cargo.Items.Register( {
            id        = med.cargo,
            name      = med.nombre,
            weight    = med.peso,
            -- `stackable` y no `unique`: el autor lo cerro el 2026-08-20
            -- ( *"las pastillas son consumibles de un solo uso stackeable"* ), y
            -- ademas es lo unico que habilita el QUICK BIND F1-F4 de Cargo
            -- ( corpus_cargo_ui.lua:288, condicionado a class == "stackable" ).
            -- §19.9.7: lo que se usa en panico va a una tecla.
            class     = "stackable",
            category  = "medical",
            size      = { 1, 1 },
            max_stack = 5,
            value     = med.precio,
            model     = med.modelo,
            trivia    = med.trivia,

            -- ⚠ Devolver FALSE hace que Cargo NO descuente la unidad. Es el
            -- regalo del precedente de Craving ( corpus_craving_items.lua:61-66 )
            -- y lo que hace que tomar una pastilla al 100 % no la desperdicie.
            -- El onUse se registra en los dos realms como toda def; solo CORRE
            -- en el servidor.
            onUse = function( ply )
                if not SERVER then return false end
                if not isfunction( PHANTASMAGORIA.UseSanityMed ) then return false end

                local ok = PHANTASMAGORIA.UseSanityMed( ply, tier, "cargo" )
                return ok == true

            end,
        } )

        n = n + 1

    end

    cargoHecho, cargoQuien = true, quien

    MsgC( Color( 190, 120, 255 ), "[Phantasmagoria] ", color_white,
        "cordura: " .. n .. " defs de medicacion registradas en Cargo  ( disparo: " .. tostring( quien ) ..
        ", intento " .. cargoIntentos .. ", realm " .. ( SERVER and "server" or "client" ) .. " )\n" )

    return true

end

if not registrarEnCargo( "inmediato" ) then
    hook.Add( "InitPostEntity", "phantasmagoria_sanity_cargo", function()
        registrarEnCargo( "InitPostEntity" )

    end )

    timer.Create( "phantasmagoria_sanity_cargo_retry", 2, CARGO_INTENTOS_MAX, function()
        if registrarEnCargo( "reintento" ) then
            timer.Remove( "phantasmagoria_sanity_cargo_retry" )

        end
    end )
end

-- Todo lo de abajo es servidor: la cordura es autoritativa del servidor
-- ( §19.8.7 ) y el cliente la lee por la NW.
if not SERVER then return end

util.PrecacheSound( PHANTASMAGORIA.SanityMeds[ 1 ].sonido )
util.PrecacheSound( PHANTASMAGORIA.SanityMeds[ 2 ].sonido )
util.PrecacheSound( PHANTASMAGORIA.SanityMeds[ 3 ].sonido )

---------------------------------------------------------------------------
-- LAS PERILLAS
---------------------------------------------------------------------------
-- Convencion de la casa: el 0 de una perilla de causa es el CONTROL, no un
-- apagado de conveniencia. Y las de TASA son numeros continuos: van en su
-- propio renglon del reporte y no mezcladas con las de encendido, porque tres
-- significados para el mismo digito en la misma pantalla es como se pierde una
-- corrida.
--
-- ⚠ Ninguna es de tres estados ( 0 = nadie · 1 = respeta el flag · 2 = todos )
-- a proposito: en B1 no hay ningun flag POR TIPO que respetar. La sub-tabla
-- `sanity` de `ghost_flags.lua` -- donde viven el `mult = 2` del Oni, el
-- `per.door = 15` del Yurei y el `presence = 0.5` del Phantom ( §19.8.4 ) -- es
-- B2. Poner hoy un estado 2 que no tiene flag debajo seria una perilla cuyo
-- valor intermedio no significa nada, y se leeria como que el flag ya existe.

local cvTick = CreateConVar( "phantasmagoria_sanity_tick", "0.25", FCVAR_ARCHIVE,
    "Segundos entre ticks de cordura. El dt real se mide, no se asume: bajarlo afina la resolucion de las causas CONTINUAS y no cambia las tasas.", 0.05, 2 )

local cvInicial = CreateConVar( "phantasmagoria_sanity_inicial", "100", FCVAR_ARCHIVE,
    "Cordura con la que arranca un jugador que spawnea o se conecta ( §19.9.6 ). La cordura NO persiste entre mapas.", 0, 100 )

-- PRESENCIA ( §19.8.2 )
local cvPresencia = CreateConVar( "phantasmagoria_sanity_presencia", "1", FCVAR_ARCHIVE,
    "0 = la presencia del fantasma no drena ( CONTROL: el reporte igual cuenta los ticks en la esfera y lo que habria drenado ) · 1 = drena.", 0, 1 )

local cvCalma = CreateConVar( "phantasmagoria_sanity_calma", "0.10", FCVAR_ARCHIVE,
    "TASA %/s de la presencia con el fantasma EN CALMA, en el centro de la esfera ( §19.8.2: 100 -> 0 en ~16,7 min ).", 0, 5 )

local cvHunt = CreateConVar( "phantasmagoria_sanity_hunt", "0.35", FCVAR_ARCHIVE,
    "TASA %/s de la presencia con el fantasma CAZANDO ( §19.8.2: 100 -> 0 en ~4,8 min ). Queda debajo del 0,5 %/s del Phantom a proposito, o el rasgo del tipo deja de ser especial.", 0, 5 )

local cvRadio = CreateConVar( "phantasmagoria_sanity_radio", "400", FCVAR_ARCHIVE,
    "Radio de la esfera de presencia en unidades ( ~7,6 m ). SEPARADO de phantasmagoria_ghost_evradius a proposito: uno decide donde puede pasar un evento y el otro a quien le llega la presencia.", 0, 4096 )

local cvMeseta = CreateConVar( "phantasmagoria_sanity_meseta", "150", FCVAR_ARCHIVE,
    "Hasta esta distancia la presencia drena al 100 % de su tasa; de ahi cae lineal a 0 en el borde. Los 150 u son el equivalente del heartbeat range y por eso NO escalan con el x1,5 del hunt.", 0, 4096 )

local cvHuntRadio = CreateConVar( "phantasmagoria_sanity_huntradio", "1.5", FCVAR_ARCHIVE,
    "Multiplicador del RADIO cuando el fantasma esta cazando ( §19.8.2: 600 u ). El ruido de la caceria se oye mas lejos que la presencia en calma.", 1, 4 )

-- OSCURIDAD ( §19.9.2 ) -- es un MODULADOR, no una causa propia
local cvDark = CreateConVar( "phantasmagoria_sanity_dark", "1", FCVAR_ARCHIVE,
    "0 = la luz no modula nada, x1 siempre ( CONTROL ) · 1 = la presencia drena x0,5 con luz y x1,5 a oscuras. NO es una causa: si drenara sola, la barra bajaria en cualquier mapa oscuro sin fantasma y contradiria la regla del autor.", 0, 1 )

local cvDarkMul = CreateConVar( "phantasmagoria_sanity_darkmul", "1.5", FCVAR_ARCHIVE,
    "Multiplicador de la presencia con el jugador A OSCURAS ( §19.8.5 ).", 0, 5 )

local cvLitMul = CreateConVar( "phantasmagoria_sanity_litmul", "0.5", FCVAR_ARCHIVE,
    "Multiplicador de la presencia con el jugador ILUMINADO ( §19.8.5: la luz no restaura, FRENA ).", 0, 5 )

local cvLitRadio = CreateConVar( "phantasmagoria_sanity_litradio", "300", FCVAR_ARCHIVE,
    "Radio en unidades dentro del cual una lampara encendida del mapa cuenta como luz de ambiente.", 0, 4096 )

-- REGENERACION PASIVA ( §19.8.5 )
local cvRegen = CreateConVar( "phantasmagoria_sanity_regen", "1", FCVAR_ARCHIVE,
    "0 = sin goteo pasivo ( CONTROL ) · 1 = goteo pasivo. Es para SANDBOX ILIMITADO: un gamemode con partidas que terminan lo va a querer en 0, y por eso la perilla existe con el motivo escrito.", 0, 1 )

local cvRegenRate = CreateConVar( "phantasmagoria_sanity_regenrate", "0.2", FCVAR_ARCHIVE,
    "TASA %/s del goteo pasivo -- la mitad del camion. Es el numero del autor y solo funciona junto con el retardo: sin el, el punto de empate cae en f = 2/3 y el hunt.threshold no se alcanza nunca.", 0, 5 )

local cvRegenDelay = CreateConVar( "phantasmagoria_sanity_regendelay", "45", FCVAR_ARCHIVE,
    "Segundos SIN NINGUN DRENAJE que hacen falta para que el goteo pasivo arranque. Durante una investigacion real la ventana casi nunca se cumple ( los eventos salen cada 25-90 s ); cuando la partida se calma de verdad, se cumple sola. Y una condicion con retardo no puede parpadear.", 0, 600 )

local cvRegenCap = CreateConVar( "phantasmagoria_sanity_regencap", "80", FCVAR_ARCHIVE,
    "Techo del goteo pasivo [ decision del autor, 2026-08-20 ]. Distinto del techo del camion a proposito: asi el goteo te devuelve la partida, el camion te deja impecable y la pastilla sigue siendo lo unico que sube desde 80 al instante.", 0, 100 )

-- ZONA SEGURA ( §19.8.5 ) -- registrada e INACTIVA: la zona no existe
local cvSafe = CreateConVar( "phantasmagoria_sanity_safe", "1", FCVAR_ARCHIVE,
    "0 = la zona segura no recupera ( CONTROL ) · 1 = recupera. ⚠ HOY NO TIENE SUJETO: la zona segura de §18.1 no esta escrita ( no hay entidad camion ni veto terminator_blocktarget ), asi que la fuente se reporta INACTIVA.", 0, 1 )

local cvSafeRate = CreateConVar( "phantasmagoria_sanity_saferate", "0.4", FCVAR_ARCHIVE,
    "TASA %/s de la zona segura ( §19.8.5: 0 -> 100 en ~4 min sentado ). Como cuesta tiempo, volver al camion es una decision y no un boton.", 0, 5 )

local cvSafeCap = CreateConVar( "phantasmagoria_sanity_safecap", "100", FCVAR_ARCHIVE,
    "Techo de la zona segura [ decision del autor, 2026-08-20 ]: el camion SI llega a 100.", 0, 100 )

-- MEDICACION ( §19.8.5 / §19.9.7 )
local cvMeds = CreateConVar( "phantasmagoria_sanity_meds", "1", FCVAR_ARCHIVE,
    "0 = la medicacion no restaura ( CONTROL: el reporte cuenta igual los usos y lo que habrian dado ) · 1 = restaura.", 0, 1 )

local cvMedCD = CreateConVar( "phantasmagoria_sanity_medcd", "60", FCVAR_ARCHIVE,
    "Segundos de enfriamiento entre dos dosis de medicacion, del tier que sean ( §19.8.5 ).", 0, 600 )

-- DESENLACES ( §19.8.5 )
local cvMuerte = CreateConVar( "phantasmagoria_sanity_muerte", "1", FCVAR_ARCHIVE,
    "0 = morir no restaura ( CONTROL ) · 1 = morir restaura al valor inicial. En gamemode la partida TERMINA, asi que no hay a que volver; en sandbox el atajo compite contra sv_cheats y el menu Q, o sea que no es un exploit.", 0, 1 )

local cvDestierro = CreateConVar( "phantasmagoria_sanity_destierro", "1", FCVAR_ARCHIVE,
    "0 = matar al fantasma no restaura ( CONTROL ) · 1 = restaura la cordura de todos. Es el equivalente al fin del contrato: lo que en Phasmophobia hace el reloj, aca lo hace el desenlace.", 0, 1 )

-- EVENTOS ( B2 ) -- la perilla existe hoy para que la puerta sea uniforme
local cvEventos = CreateConVar( "phantasmagoria_sanity_eventos", "1", FCVAR_ARCHIVE,
    "0 = los eventos no drenan ( CONTROL ) · 1 = drenan. ⚠ ANDAMIO HASTA B2: hoy los ocho eventos de server_events.lua NO llaman a la puerta, asi que su renglon del desglose vale 0 por falta de llamador y no por esta perilla.", 0, 1 )

---------------------------------------------------------------------------
-- LAS CAUSAS DECLARADAS
---------------------------------------------------------------------------
-- El desglose imprime ESTA lista, en este orden, incluyendo las que valen 0.
-- Una causa que no aparece y una causa que vale 0 son cosas distintas y tienen
-- que verse distinto: la primera es un llamador que no existe, la segunda es un
-- mecanismo que no disparo.
--
-- `fam` es lo que la perilla gatea. Una causa cuya familia no este en PERILLAS
-- pasa siempre -- y el reporte la marca, porque una causa sin perilla no se
-- puede aislar en un A/B y eso es un hueco del instrumento, no un detalle.
-- ⚠⚠ `prod` DICE QUIEN TENDRIA QUE HABER DISPARADO ESTA CAUSA, y no es
-- documentacion: es lo que separa TRES estados que hasta la r1 se imprimian
-- IGUAL, con el mismo `+0.00 %` y el mismo `( sin llamador todavia )`.
--
--   ( a ) nadie la llama todavia          los ocho eventos, que son B2
--   ( b ) su fuente CORRIO y nunca aplico  `presencia hunt` con el fantasma en
--                                          calma, o el goteo con la barra arriba
--                                          del techo
--   ( c ) su disparador existe y no ocurrio  la muerte, el destierro, una dosis
--
-- El texto de la r1 decia ( a ) para los veinte. Medido contra la corrida del
-- 2026-08-20: de los renglones en cero, NUEVE eran ( b ) o ( c ) y el reporte
-- los acusaba de no tener llamador -- entre ellos `goteo pasivo` en la fila 03,
-- que **no** es que nadie lo llame: es que su fuente se interrogo 3.198 veces y
-- contesto que no. *Dos estados distintos impresos igual es exactamente el
-- defecto que este modulo existe para no volver a pagar,* y esta vez lo tenia
-- el instrumento adentro.
local CAUSAS = {
    { id = "presencia_calma", fam = "presencia", label = "presencia calma", prod = "fuente:presencia" },
    { id = "presencia_hunt",  fam = "presencia", label = "presencia hunt",  prod = "fuente:presencia" },
    -- ⚠ LA UNICA CAUSA CON DOS PERILLAS, y las dos hacen falta. `presencia`
    -- porque el modulador no existe sin lo que modula -- si no, la corrida de
    -- control veria moverse la barra por el x1,5 de una presencia apagada. Y
    -- `oscuridad` porque tiene que poder aislarse en su propio A/B.
    { id = "oscuridad", fam = "presencia", fam2 = "oscuridad", label = "oscuridad ( mod )", prod = "fuente:presencia" },

    { id = "evento:sound",     fam = "eventos", label = "evento sound",     prod = "B2" },
    { id = "evento:throw",     fam = "eventos", label = "evento throw",     prod = "B2" },
    { id = "evento:light",     fam = "eventos", label = "evento light",     prod = "B2" },
    { id = "evento:prop",      fam = "eventos", label = "evento prop",      prod = "B2" },
    { id = "evento:knock",     fam = "eventos", label = "evento knock",     prod = "B2" },
    { id = "evento:door",      fam = "eventos", label = "evento door",      prod = "B2" },
    { id = "evento:furniture", fam = "eventos", label = "evento furniture", prod = "B2" },
    { id = "evento:creak",     fam = "eventos", label = "evento creak",     prod = "B2" },

    { id = "regen",      fam = "regen",      label = "goteo pasivo",    prod = "fuente:regen"      },
    { id = "zonasegura", fam = "safe",       label = "zona segura",     prod = "fuente:zonasegura" },
    { id = "med_i",      fam = "meds",       label = "medicacion I",    prod = "PHANTASMAGORIA.UseSanityMed( ply, 1 )" },
    { id = "med_ii",     fam = "meds",       label = "medicacion II",   prod = "PHANTASMAGORIA.UseSanityMed( ply, 2 )" },
    { id = "med_iii",    fam = "meds",       label = "medicacion III",  prod = "PHANTASMAGORIA.UseSanityMed( ply, 3 )" },
    { id = "muerte",     fam = "muerte",     label = "muerte",          prod = "el hook PlayerSpawn, al respawnear" },
    { id = "destierro",  fam = "destierro",  label = "fantasma muerto", prod = "el hook OnNPCKilled" },
    { id = "andamio",    fam = nil,          label = "andamio consola", prod = "phantasmagoria_cordura_set" },
}

local CAUSA_POR_ID = {}
for _, c in ipairs( CAUSAS ) do CAUSA_POR_ID[ c.id ] = c end

local PERILLAS = {
    presencia = cvPresencia,
    oscuridad = cvDark,
    eventos   = cvEventos,
    regen     = cvRegen,
    safe      = cvSafe,
    meds      = cvMeds,
    muerte    = cvMuerte,
    destierro = cvDestierro,
}

-- Devuelve ( pasa, convar ). Cuando una causa tiene dos perillas, la convar que
-- devuelve es la PRIMERA que esta apagada: el reporte la nombra, y "quedo en 0
-- por esta perilla" tiene que decir cual, no cualquiera de las dos.
local function perillaDe( causaId )
    local c = CAUSA_POR_ID[ causaId ]
    if not c then return true, nil end

    local cvA = c.fam and PERILLAS[ c.fam ]
    local cvB = c.fam2 and PERILLAS[ c.fam2 ]

    if cvA and not cvA:GetBool() then return false, cvA end
    if cvB and not cvB:GetBool() then return false, cvB end

    return true, cvA or cvB

end

---------------------------------------------------------------------------
-- EL ESTADO POR JUGADOR
---------------------------------------------------------------------------
-- ⚠ EL NUMERO VIAJA POR NW2Float Y ESO NO ES LO MISMO QUE NWFloat.
-- §19.8.7 lo decide asi, y son DOS ALMACENES DISTINTOS del engine: un consumidor
-- que llame `ply:GetNWFloat( "phantasmagoria_sanity" )` va a recibir 0 con la
-- barra al 72 %, sin error y sin nada que lo delate. Los otros tres campos
-- networkeados del addon usan la familia vieja ( SetNWBool/SetNWString ), asi que
-- la confusion tiene donde nacer.
--
-- Por eso el lector publico existe: los tres consumidores declarados -- la
-- barrita de Cargo, el HUD propio y la pantalla TEAM SANITY del camion -- llaman
-- a PHANTASMAGORIA.GetSanity y no adivinan el nombre ni la familia.
local NW = "phantasmagoria_sanity"

-- ⚠ DECLARADOS ACA Y NO AL LADO DEL TICK, aunque el tick sea su unico escritor:
-- `presenciaDe` los LEE para cachear por numero de tick, y esta mas arriba en el
-- archivo. Un `local` declarado despues de su lector no es ese local: el lector
-- ve un GLOBAL nil, y `nil == nil` habria dado la cache por valida en el primer
-- tick de cada jugador -- con el valor cacheado todavia sin escribir.
local ultimoTick  = 0
local ticksTotal  = 0
local ticksReales = 0    -- para poder imprimir el periodo MEDIDO y no el pedido
local segsReales  = 0

local function nuevoAcumulador()
    local acc = {}

    for _, c in ipairs( CAUSAS ) do
        acc[ c.id ] = { aplicado = 0, potencial = 0, segundos = 0, ticks = 0, veces = 0 }

    end

    return acc

end

local function estado( ply, quien )
    local st = ply.phantom_San

    if not st then
        st = {
            val           = cvInicial:GetFloat(),
            -- ⚠ El inicial se CONGELA al crear el estado. El cierre del
            -- desglose de mas abajo compara `inicial + suma` contra la barra, y
            -- leer la convar en el momento de imprimir haria que mover
            -- `phantasmagoria_sanity_inicial` a mitad de corrida inventara una
            -- brecha que no existe -- un falso ROJO del unico control que puede
            -- descubrir a un escritor que no paso por la puerta.
            inicial       = cvInicial:GetFloat(),
            t0            = CurTime(),
            acc           = nuevoAcumulador(),
            extra         = {},        -- causas NO declaradas, en orden de aparicion
            extraOrden    = {},
            ultima        = nil,
            ultimoDrenaje = 0,
            esferaTicks   = 0,
            esferaSegs    = 0,
            medUltimo     = 0,
            medUsos       = 0,
            nacioPor      = quien or "lazy ( el tick lo creo )",
        }

        ply.phantom_San = st
        ply:SetNW2Float( NW, st.val )

    end

    return st

end

-- El bucket de una causa, declarada o no. Una causa desconocida NO se funde en
-- un "otras": se le hace su propio renglon y se marca. Fundirla haria que un
-- llamador que escribe mal el string -- "evento_sound" en vez de "evento:sound" --
-- sume igual y el renglon correcto quede en 0, con las dos mitades del reporte
-- de acuerdo entre si.
local function bucket( st, causaId )
    local b = st.acc[ causaId ]
    if b then return b, true end

    b = st.extra[ causaId ]

    if not b then
        b = { aplicado = 0, potencial = 0, segundos = 0, ticks = 0, veces = 0 }
        st.extra[ causaId ] = b
        st.extraOrden[ #st.extraOrden + 1 ] = causaId

    end

    return b, false

end

---------------------------------------------------------------------------
-- LA PUERTA UNICA -- el unico lugar del addon que escribe el numero
---------------------------------------------------------------------------
-- `delta` en puntos de cordura: negativo drena, positivo restaura.
-- `dt` no nil marca la forma CONTINUA ( y entonces suma segundos y ticks );
--      nil marca la forma PLANA ( y entonces suma veces ).
-- `techo` limita las restauraciones ( el goteo pasivo llega a 80, el camion a
--      100 ). Los drenajes lo ignoran y siempre pueden llegar a 0.
--
-- ⚠ EL ORDEN DE ESTE CUERPO ES EL BLOQUE ENTERO: primero se cuenta el
-- POTENCIAL, despues se consulta la perilla. Al reves, una corrida de control
-- deja el contador en cero y borra la evidencia de que el sujeto llego -- que es
-- el mismo cero que da un mecanismo que nunca corrio ( catalogo nº 100 ).
local function aplicar( ply, delta, causaId, dt, techo )
    if not IsValid( ply ) or not ply:IsPlayer() then return 0 end
    if not isnumber( delta ) or delta ~= delta then return 0 end
    if delta == 0 and not dt then return 0 end

    local st = estado( ply )
    local b, declarada = bucket( st, causaId )

    -- ( 1 ) LA CUENTA, siempre, pase o no pase la perilla.
    b.potencial = b.potencial + delta

    if dt then
        b.segundos = b.segundos + dt
        b.ticks    = b.ticks + 1

    else
        b.veces = b.veces + 1

    end

    -- ( 2 ) LA PERILLA, que suprime el efecto y nada mas.
    local pasa, cv = perillaDe( causaId )
    if not pasa then return 0, cv end

    -- ( 3 ) EL EFECTO, y lo que se acredita es lo que REALMENTE entro. Un
    -- +40 % sobre una barra en 90 con techo 100 acredita 10, no 40: acreditar lo
    -- pedido dejaria un desglose que no cierra contra el valor y haria ver como
    -- restauracion lo que fue un desperdicio.
    local antes = st.val
    local tope  = ( delta > 0 and isnumber( techo ) ) and math.Clamp( techo, 0, 100 ) or 100

    -- Un techo por debajo del valor actual no BAJA la barra: la via no aplica.
    -- Sin esta guarda, el goteo pasivo con techo 80 le robaria cordura a un
    -- jugador que viene del camion con 100.
    if delta > 0 and antes >= tope then return 0 end

    st.val = math.Clamp( antes + delta, 0, delta > 0 and tope or 100 )

    local real = st.val - antes
    if real == 0 then return 0 end

    b.aplicado = b.aplicado + real

    ply:SetNW2Float( NW, st.val )

    st.ultima = {
        causa    = causaId,
        label    = declarada and CAUSA_POR_ID[ causaId ].label or ( causaId .. " ⚠ no declarada" ),
        delta    = real,
        t        = CurTime(),
        continua = dt ~= nil,
    }

    -- ⚠ Solo un drenaje APLICADO reinicia el retardo del goteo. Si lo reiniciara
    -- el potencial, una corrida con la presencia en 0 tendria la regeneracion
    -- bloqueada por un drenaje que nunca ocurrio, y la fila 02 saldria roja por
    -- culpa del control de la fila 01.
    if real < 0 then st.ultimoDrenaje = CurTime() end

    return real

end

---------------------------------------------------------------------------
-- LA API PUBLICA
---------------------------------------------------------------------------
-- §19.9.5 y §22.4 dejaron escrito el contrato antes de que existiera el cuerpo,
-- y las cinco manifestaciones de §22 ya estan escritas contra el. `causa` es un
-- string y NO es decoracion: es lo que el instrumento desglosa, y sin el "la
-- barra bajo 30 %" no distingue una caceria de una guija.
--
-- Las dos posesiones malditas que son TASA -- el mirror con 7,5 %/s y la music
-- box con 2,6 %/s -- pueden entrar por RegisterSanityRate ( lo correcto ) o
-- llamando a DrainSanity por tick ( lo que §19.9.5 contemplaba ). Las dos
-- funcionan; la primera ademas se puede apagar y auditar sin tocar su dueño.

function PHANTASMAGORIA.GetSanity( ply )
    if not IsValid( ply ) or not ply:IsPlayer() then return nil end

    return estado( ply ).val

end

function PHANTASMAGORIA.DrainSanity( ply, pct, causa )
    if not isnumber( pct ) or pct <= 0 then return 0 end

    return aplicar( ply, -math.abs( pct ), causa or "sin_causa", nil, nil )

end

function PHANTASMAGORIA.RestoreSanity( ply, pct, causa, techo )
    if not isnumber( pct ) or pct <= 0 then return 0 end

    return aplicar( ply, math.abs( pct ), causa or "sin_causa", nil, techo )

end

-- ANDAMIO, y se declara como tal en su propio nombre de causa. Existe para que
-- una fila de planilla pueda partir de un valor conocido sin depender de que el
-- fantasma coopere. Se contabiliza como cualquier otra causa a proposito: una
-- corrida donde alguien lo uso tiene que poder distinguirse de una donde no.
function PHANTASMAGORIA.SetSanity( ply, pct, causa )
    if not IsValid( ply ) or not ply:IsPlayer() then return 0 end
    if not isnumber( pct ) then return 0 end

    local st = estado( ply )

    return aplicar( ply, math.Clamp( pct, 0, 100 ) - st.val, causa or "andamio", nil, 100 )

end

---------------------------------------------------------------------------
-- LA FORMA CONTINUA: el registro de fuentes
---------------------------------------------------------------------------
-- `fn( ply, dt )` devuelve:
--     rate       %/s, con signo ( negativo drena ). nil = la fuente NO aplica
--                este tick, y eso es un dato: el reporte lo cuenta.
--     causaId    contra que renglon del desglose se anota
--     techo      para las positivas
--     nota       texto corto: por que aplica, o por que no
--     modulable  true si la oscuridad de §19.9.2 la multiplica
--
-- ⚠ La fuente NO consulta su perilla. Si lo hiciera, devolveria nil con la
-- perilla en 0 y el reporte perderia el potencial -- que es justo lo que la
-- fila 00 necesita leer. La perilla vive en la puerta.
local FUENTES = {}

function PHANTASMAGORIA.RegisterSanityRate( id, fn, etiqueta )
    if not isstring( id ) or not isfunction( fn ) then
        ErrorNoHalt( "[Phantasmagoria] RegisterSanityRate: hace falta ( id string, fn function ).\n" )
        return false

    end

    for _, f in ipairs( FUENTES ) do
        if f.id == id then
            ErrorNoHalt( "[Phantasmagoria] RegisterSanityRate: '" .. id .. "' ya estaba registrada. " ..
                "Dos fuentes con el mismo id dejarian el desglose contando dos veces contra un renglon.\n" )
            return false

        end
    end

    FUENTES[ #FUENTES + 1 ] = {
        id        = id,
        fn        = fn,
        etiqueta  = etiqueta or id,
        activos   = 0,
        inactivos = 0,
        nota      = "todavia no corrio",
        notaDe    = nil,
    }

    return true

end

---------------------------------------------------------------------------
-- LA ESFERA DE PRESENCIA
---------------------------------------------------------------------------
-- §19.8.2, con la enmienda del autor: el discriminante es el HUNT y NADA MAS.
-- No se lee `absence` ni el estado de render -- §20.6 los va a hacer titilar
-- entre 2 y 10 veces por segundo, y una tasa colgada de eso repartiria el mismo
-- drenaje entre dos renglones segun el frame en que cayo el tick.
-- `phantom_Hunting` cambia DOS VECES POR HUNT y es exactamente lo que el jugador
-- percibe como "esta cazando" sin necesidad de verlo.
--
-- ⚠ Y el escondite NO protege de la cordura. §18.2 diseño el escondite contra el
-- TARGETING: meterse en el ropero salva de que te encuentre, no de oirlo.

-- Iterar los fantasmas vivos. `PHANTASMAGORIA.EachGhost` vive en el server.lua
-- de la entidad y este archivo es autorun, asi que no hay garantia de orden de
-- CARGA -- aunque en tiempo de ejecucion siempre este. El fallback hace lo mismo
-- ( campo IsPhantasmagoriaGhost y no clase, porque los 30 tipos de §12.2 se van
-- a llamar phantasmagoria_<tipo> ) y el reporte dice POR CUAL DE LOS DOS CAMINOS
-- salio: un fallback que funciona bien es invisible justo cuando tapa algo.
local viaGhosts = "sin usar"

local function cadaFantasma( fn )
    if isfunction( PHANTASMAGORIA.EachGhost ) then
        viaGhosts = "PHANTASMAGORIA.EachGhost"
        return PHANTASMAGORIA.EachGhost( fn )

    end

    viaGhosts = "⚠ fallback propio ( EachGhost no existia )"

    local n = 0

    for _, g in ipairs( ents.GetAll() ) do
        if not IsValid( g ) then continue end
        if not g.IsPhantasmagoriaGhost then continue end

        n = n + 1
        fn( g )

    end

    return n

end

-- Meseta al 100 %, caida lineal a 0 en el borde ( §19.8.2 ).
local function factorDistancia( d, radio, meseta )
    if radio <= 0 then return 0 end
    if d >= radio then return 0 end

    meseta = math.min( meseta, radio )
    if d <= meseta then return 1 end
    if radio <= meseta then return 1 end

    return 1 - ( d - meseta ) / ( radio - meseta )

end

-- ⚠ CON DOS FANTASMAS SE TOMA EL MAS FUERTE, NO LA SUMA, y es una decision mia
-- que conviene poder discutir: sumando, la tasa crece sin techo con la cantidad
-- de fantasmas y la escala de §19.2 -- 10-20 min con actividad normal, que es la
-- VARA de todo el bloque -- deja de significar nada. Con el maximo, dos fantasmas
-- encima tuyo drenan como uno y el sandbox no se vuelve una licuadora.
-- El reporte imprime CUANTOS estaban en la esfera, asi que la decision se ve.
-- ⚠ CACHEADA POR TICK, y el criterio es el NUMERO DE TICK y no el tiempo: dos
-- fuentes la consultan en el mismo tick ( la presencia y el goteo, que necesita
-- saber si estas dentro del radio ) y sin cache eso son dos barridos de
-- ents.GetAll por jugador. Cachear por tiempo dejaria la respuesta viva mas alla
-- del tick que la produjo, que es como una cache se vuelve un dato viejo.
local function presenciaDe( ply )
    local st = ply.phantom_San

    if st and st.presCache == ticksTotal then
        local c = st.presVal
        return c[ 1 ], c[ 2 ], c[ 3 ], c[ 4 ], c[ 5 ]

    end

    local pos = ply:GetPos()
    local mejor, mejorGhost, mejorD, mejorHunt, enEsfera = 0, nil, nil, false, 0

    cadaFantasma( function( g )
        local cazando = g.phantom_Hunting == true
        local radio   = cvRadio:GetFloat() * ( cazando and cvHuntRadio:GetFloat() or 1 )
        local d       = g:GetPos():Distance( pos )
        local f       = factorDistancia( d, radio, cvMeseta:GetFloat() )

        if f <= 0 then return end

        enEsfera = enEsfera + 1

        local tasa = ( cazando and cvHunt:GetFloat() or cvCalma:GetFloat() ) * f

        if tasa > mejor then
            mejor, mejorGhost, mejorD, mejorHunt = tasa, g, d, cazando

        end
    end )

    if st then
        st.presCache = ticksTotal
        st.presVal   = { mejor, mejorGhost, mejorD, mejorHunt, enEsfera }

    end

    return mejor, mejorGhost, mejorD, mejorHunt, enEsfera

end

---------------------------------------------------------------------------
-- LA OSCURIDAD: un MODULADOR, y devuelve ESTADO + MOTIVO
---------------------------------------------------------------------------
-- §19.9.2 eligio la opcion B ( la luz que lleva el jugador + las luces del mapa
-- que se puedan LEER ), y lo que la hace barata no es el algoritmo sino la
-- forma: una sola funcion que devuelve estado y motivo. Si mañana entra la
-- opcion C ( el sampler de 6 muestras de §19.4 ), cambia el cuerpo y ningun
-- llamador se entera.
--
-- ⚠ EL DEFECTO SE ESCRIBE ACA Y NO SE DESCUBRE DESPUES, y es mas grande de lo
-- que §19.9.2 suponia. De las seis clases de luz que el addon conoce
-- ( server_events.lua ), SOLO las dos de sandbox -- gmod_light y gmod_lamp --
-- tienen getter: `light`, `light_spot`, `point_spotlight`, `light_dynamic` y
-- `env_projectedtexture` se CONMUTAN por input del engine y no se pueden LEER.
-- O sea que un mapa iluminado por sus propias luces se va a leer como oscuro,
-- igual que uno de iluminacion horneada.
--
-- Por eso la funcion devuelve un TERCER valor: cuantas luces vio y no pudo
-- interrogar. Ese numero convierte el punto ciego en una medicion en pantalla en
-- vez de en un silencio -- que es la unica forma de que un dia alguien decida si
-- vale la pena la opcion C.
--
-- ⚠⚠ La lista de clases ILEGIBLES es una COPIA de LIGHT_CLASSES, que vive
-- `local` en server_events.lua y B1 no puede tocar ese archivo. Es la familia del
-- nº 87 ( un instrumento que declara ser una copia ) y por eso se acota a lo
-- unico que no puede producir un falso verde: la copia SOLO alimenta el contador
-- del punto ciego. Si envejece, el punto ciego se reporta MAS CHICO de lo que
-- es; nunca decide si un jugador esta iluminado. B2 -- que si toca ese archivo --
-- tiene que subir LIGHT_CLASSES a `lua/phantasmagoria/` y borrar esta copia.
local LUCES_LEGIBLES  = { "gmod_light", "gmod_lamp" }
local LUCES_ILEGIBLES = { "light", "light_spot", "point_spotlight", "light_dynamic", "env_projectedtexture" }

function PHANTASMAGORIA.IsPlayerLit( ply )
    if not IsValid( ply ) or not ply:IsPlayer() then return false, "no es un jugador", 0 end

    -- ⚠ `FlashlightIsOn` es SERVER-ONLY EN LAS DOS DIRECCIONES: leerlo en el
    -- cliente devuelve false con el haz pintando una pared ( medido por Cargo,
    -- corpus_cargo_lights.lua ). Acá estamos en el servidor, que es donde
    -- funciona -- y es la razon de fondo por la que §19.9.2 eligio la opcion B
    -- sobre la C: la mitad de C que corre en CLIENT no podria leer esto.
    if ply:FlashlightIsOn() then return true, "linterna", 0 end

    local radio  = cvLitRadio:GetFloat()
    local radio2 = radio * radio
    local pos    = ply:GetPos()
    local ciegas = 0

    for _, clase in ipairs( LUCES_LEGIBLES ) do
        for _, e in ipairs( ents.FindByClass( clase ) ) do
            if not IsValid( e ) then continue end
            if not isfunction( e.GetOn ) then continue end
            if e:GetPos():DistToSqr( pos ) > radio2 then continue end
            if not e:GetOn() then continue end

            return true, clase .. " #" .. e:EntIndex() .. " a " .. math.Round( e:GetPos():Distance( pos ) ) .. " u", ciegas

        end
    end

    for _, clase in ipairs( LUCES_ILEGIBLES ) do
        for _, e in ipairs( ents.FindByClass( clase ) ) do
            if not IsValid( e ) then continue end
            if e:GetPos():DistToSqr( pos ) > radio2 then continue end

            ciegas = ciegas + 1

        end
    end

    if ciegas > 0 then
        return false, "nada legible cerca ( " .. ciegas .. " luces del mapa sin getter: no se pueden interrogar )", ciegas

    end

    return false, "nada cerca", 0

end

---------------------------------------------------------------------------
-- LA ZONA SEGURA: la costura, hoy sin sujeto
---------------------------------------------------------------------------
-- §18.1 la definio como un veto de TARGETING ( `terminator_blocktarget` ) cuya
-- geometria sale de una ENTIDAD: *"se spawnea el camion y su radio es la zona"*.
-- Censo del 2026-08-20: ni el hook ni la entidad existen en `lua/`.
--
-- Devuelve estado + motivo por la misma razon que IsPlayerLit: el dia que §18.1
-- se escriba, cambia este cuerpo y ni la fuente continua ni el reporte se
-- enteran.
function PHANTASMAGORIA.InSafeZone( ply )
    if not IsValid( ply ) or not ply:IsPlayer() then return false, "no es un jugador" end

    return false, "la zona segura de §18.1 no esta escrita ( sin entidad camion y sin veto terminator_blocktarget )"

end

---------------------------------------------------------------------------
-- LAS FUENTES CONTINUAS QUE B1 REGISTRA
---------------------------------------------------------------------------
-- La presencia se escribe COMO FUENTE REGISTRADA y no cableada adentro del tick
-- a proposito: es la prueba de que el mecanismo que el rasgo del Phantom va a
-- necesitar existe y funciona. Si la presencia fuera un caso especial del tick,
-- la fila 04 de la planilla no probaria nada -- estaria midiendo el tick, no el
-- registro.
PHANTASMAGORIA.RegisterSanityRate( "presencia", function( ply, dt )
    if not ply:Alive() then return nil, nil, nil, "muerto" end

    local tasa, ghost, d, cazando, enEsfera = presenciaDe( ply )

    local st = estado( ply )

    -- ⚠ ESTE CONTADOR VA ANTES DE TODO LO DEMAS, y es lo que hace legible la
    -- fila 00: un cero de drenaje sin ticks en la esfera no dice que el control
    -- funciono, dice que el fantasma nunca estuvo cerca.
    if enEsfera > 0 then
        st.esferaTicks = st.esferaTicks + 1
        st.esferaSegs  = st.esferaSegs + dt

    end

    if tasa <= 0 then
        return nil, nil, nil, "sin fantasma en la esfera"

    end

    return -tasa,
           cazando and "presencia_hunt" or "presencia_calma",
           nil,
           ( cazando and "HUNT" or "calma" ) .. " · #" .. ( IsValid( ghost ) and ghost:EntIndex() or 0 ) ..
               " a " .. math.Round( d or 0 ) .. " u · " .. enEsfera .. " en la esfera",
           true

end, "presencia del fantasma" )

PHANTASMAGORIA.RegisterSanityRate( "regen", function( ply, dt )
    if not ply:Alive() then return nil, nil, nil, "muerto" end

    local st = estado( ply )

    -- ⚠⚠ EL TEXTO DECIA "en el techo del goteo ( 80 % )" CON LA BARRA EN 88, Y
    -- ESO ESCONDIA LA CONSECUENCIA MAS IMPORTANTE DE LA DECISION DEL TECHO:
    -- arriba de 80 el goteo NO ACTUA, asi que los primeros 20 puntos de la barra
    -- son de una sola direccion. En la corrida del 2026-08-20 la fuente contesto
    -- esto 3.198 veces seguidas y el reporte se leia como "ya termino su
    -- trabajo" en vez de "todavia no empezo".
    local techo = cvRegenCap:GetFloat()

    if st.val >= techo then
        return nil, nil, nil, string.format(
            "POR ENCIMA del techo del goteo ( %.1f > %d ): no actua hasta bajar de %d",
            st.val, math.Round( techo ), math.Round( techo ) )

    end

    local _, _, _, _, enEsfera = presenciaDe( ply )
    if enEsfera > 0 then
        return nil, nil, nil, "dentro del radio de presencia"

    end

    local desde = CurTime() - st.ultimoDrenaje
    local pide  = cvRegenDelay:GetFloat()

    if desde < pide then
        return nil, nil, nil, "drenaje hace " .. math.Round( desde, 1 ) .. " s ( pide " .. math.Round( pide ) .. " s )"

    end

    return cvRegenRate:GetFloat(), "regen", cvRegenCap:GetFloat(),
           "lejos y sin drenaje hace " .. math.Round( desde ) .. " s"

end, "goteo pasivo" )

PHANTASMAGORIA.RegisterSanityRate( "zonasegura", function( ply, dt )
    if not ply:Alive() then return nil, nil, nil, "muerto" end

    local dentro, motivo = PHANTASMAGORIA.InSafeZone( ply )
    if not dentro then return nil, nil, nil, motivo end

    return cvSafeRate:GetFloat(), "zonasegura", cvSafeCap:GetFloat(), motivo

end, "zona segura ( camion )" )

---------------------------------------------------------------------------
-- EL TICK
---------------------------------------------------------------------------
-- El dt se MIDE, no se asume: un timer de GMod no garantiza su periodo y bajar
-- `phantasmagoria_sanity_tick` no tiene que cambiar las tasas. Corriendo a 20 Hz
-- con salida temprana, el periodo lo decide la convar sin callbacks ni recrear
-- el timer.
local function tick()
    local ahora = CurTime()
    local dt    = ahora - ultimoTick

    if dt < cvTick:GetFloat() then return end
    if dt <= 0 then return end

    -- Un dt gigante ( carga de mapa, pausa del singleplayer ) drenaria medio
    -- minuto de golpe y se leeria como un salto del mecanismo.
    if dt > 5 then dt = cvTick:GetFloat() end

    ultimoTick  = ahora
    ticksTotal  = ticksTotal + 1
    ticksReales = ticksReales + 1
    segsReales  = segsReales + dt

    for _, ply in ipairs( player.GetAll() ) do
        if not IsValid( ply ) then continue end

        -- La tercera señal del valor inicial: aunque los dos hooks fallen, el
        -- estado nace aca. Un wiring que cuelga de un solo hook.Add es
        -- exactamente el defecto que le costo a Corpus 4.413 defs.
        estado( ply, "tick" )

        for _, f in ipairs( FUENTES ) do
            local rate, causaId, techo, nota, modulable = f.fn( ply, dt )

            -- ⚠ EL MOTIVO ES DEL ULTIMO JUGADOR EVALUADO, Y EL REPORTE LO DICE.
            -- Con un solo jugador -- el caso normal en sandbox -- da igual; con
            -- dos, un motivo sin dueño se leeria como una propiedad de la fuente
            -- y no del sujeto, que es justo el error que hace perder una ronda.
            f.nota   = nota or ""
            f.notaDe = ply:Nick()

            if rate == nil or rate == 0 then
                f.inactivos = f.inactivos + 1
                continue

            end

            f.activos = f.activos + 1

            local base = rate * dt

            -- LA OSCURIDAD ES UN MODULADOR Y SE ANOTA APARTE. Se aplica la base
            -- contra su causa y el DELTA del multiplicador contra `oscuridad`:
            -- asi el renglon de la oscuridad dice exactamente cuanto agrego o
            -- cuanto ahorro, y el de la presencia sigue siendo comparable entre
            -- una corrida a oscuras y una con luz. Sumar todo a la presencia
            -- haria que el modulador no se pudiera aislar en ningun A/B.
            -- ⚠ EL MULTIPLICADOR SE CALCULA AUNQUE `phantasmagoria_sanity_dark`
            -- este en 0, y la perilla lo suprime adentro de la puerta como a
            -- todas las demas. Saltear el calculo aca dejaria el renglon de la
            -- oscuridad en cero SIN su potencial -- o sea sin poder distinguir
            -- "el control funciono" de "el jugador nunca estuvo ni iluminado ni
            -- a oscuras", que es el mismo cero del catalogo nº 100 y es
            -- justamente lo que esta arquitectura existe para no volver a pagar.
            local mul = 1

            if modulable then
                local lit = PHANTASMAGORIA.IsPlayerLit( ply )
                mul = lit and cvLitMul:GetFloat() or cvDarkMul:GetFloat()

            end

            aplicar( ply, base, causaId, dt, techo )

            if mul ~= 1 then
                aplicar( ply, base * mul - base, "oscuridad", dt, techo )

            end
        end
    end
end

timer.Create( "phantasmagoria_sanity_tick", 0.05, 0, function()
    -- Un error adentro del tick no puede matar el timer ni llevarse por delante
    -- lo que venga despues: la cordura corre para siempre y un solo fantasma en
    -- un estado raro no tiene que apagar el sistema entero en silencio.
    local ok, err = pcall( tick )

    if not ok then
        ErrorNoHalt( "[Phantasmagoria] cordura: el tick tiro un error y se sigue corriendo: " .. tostring( err ) .. "\n" )

    end
end )

---------------------------------------------------------------------------
-- LA MEDICACION -- la unica via instantanea
---------------------------------------------------------------------------
-- §19.9.7: instantanea, y el precedente es Craving y no Coagulant.
-- Devuelve ( ok, motivo ). El `false` es lo que hace que Cargo NO consuma la
-- unidad, asi que los dos rechazos -- barra llena y enfriamiento -- son
-- anti-desperdicio y no errores.
function PHANTASMAGORIA.UseSanityMed( ply, tier, quien )
    if not IsValid( ply ) or not ply:IsPlayer() then return false, "sin jugador" end

    local med = PHANTASMAGORIA.SanityMeds[ tier ]
    if not med then return false, "tier invalido ( 1, 2 o 3 )" end

    local st = estado( ply )

    if st.val >= 100 then
        return false, "cordura al 100 %: no se gasta"

    end

    local cd    = cvMedCD:GetFloat()
    local desde = CurTime() - st.medUltimo

    if st.medUsos > 0 and desde < cd then
        return false, "enfriamiento: faltan " .. math.Round( cd - desde, 1 ) .. " s"

    end

    st.medUltimo = CurTime()
    st.medUsos   = st.medUsos + 1

    -- El sonido sale del TIER. Va antes de la perilla a proposito: con
    -- `phantasmagoria_sanity_meds 0` el jugador tiene que poder comprobar que el
    -- clip correcto suena, que es la mitad del bloque que el autor pidio.
    ply:EmitSound( med.sonido, 70, 100, 1, CHAN_ITEM )

    local real = aplicar( ply, med.pct, med.id, nil, 100 )

    return true, med.que .. " ( tier " .. tier .. " ): +" .. math.Round( real, 1 ) ..
        " % de " .. med.pct .. " pedidos, via " .. tostring( quien or "?" )

end

---------------------------------------------------------------------------
-- LOS DESENLACES
---------------------------------------------------------------------------
-- ⚠⚠ NINGUNO DE ESTOS HOOKS DEVUELVE UN VALOR, Y NO ES UN DESCUIDO.
-- `hook.Call` ABORTA LA CADENA cuando cualquier hook devuelve algo, y en
-- `PlayerSpawn` eso se saltea `GM:PlayerSpawn` ENTERO -- con el loadout, el
-- playermodel y lo que sea que cuelgue mas abajo en la fila. Le costo a este
-- ecosistema tres sintomas que eran un solo defecto. El corte no es para todos:
-- es para los que estan mas abajo, asi que ni siquiera se ve del lado del que
-- lo causa.

local function arrancar( ply, quien )
    if not IsValid( ply ) or not ply:IsPlayer() then return end

    local st = ply.phantom_San

    if not st then
        estado( ply, quien )
        return

    end

    -- Reconectarse o respawnear NO reinicia el desglose: el reporte tiene que
    -- poder decir "esta partida drenaste 240 % en total" aunque hayas muerto
    -- tres veces. Lo unico que se toca es el valor.
    --
    -- ⚠ Y se toca POR LA PUERTA. Escribir `st.val` directo aca dejaria la suma
    -- del desglose y la barra discrepando, y el unico control que puede
    -- descubrir a un escritor clandestino acusaria a este archivo.
    aplicar( ply, st.inicial - st.val, "andamio", nil, 100 )

end

hook.Add( "PlayerInitialSpawn", "phantasmagoria_sanity_inicial", function( ply )
    arrancar( ply, "PlayerInitialSpawn" )

end )

hook.Add( "PlayerSpawn", "phantasmagoria_sanity_spawn", function( ply )
    if not IsValid( ply ) then return end

    local st = ply.phantom_San

    -- El primer spawn siempre fija el valor. Los siguientes solo si la muerte
    -- restaura -- si no, respawnear seria un atajo que la perilla en 0 diria
    -- haber cerrado.
    if not st then
        arrancar( ply, "PlayerSpawn ( primero )" )
        return

    end

    if not st.murio then return end

    -- La marca se consume SIEMPRE, y el `aplicar` corre SIEMPRE: la perilla
    -- `phantasmagoria_sanity_muerte` vive adentro de la puerta y suprime el
    -- efecto sin borrar la cuenta. Salir temprano aca dejaria el renglon
    -- `muerte` en cero durante la corrida de control, o sea sin poder distinguir
    -- "el control funciono" de "nadie murio" ( catalogo nº 100 ).
    st.murio = nil

    aplicar( ply, st.inicial - st.val, "muerte", nil, 100 )

end )

hook.Add( "PlayerDeath", "phantasmagoria_sanity_muerte", function( ply )
    if not IsValid( ply ) or not ply:IsPlayer() then return end

    -- Se marca en la MUERTE y se cobra en el SPAWN: entre las dos hay una
    -- ventana en la que el jugador esta muerto y la barra tiene que seguir
    -- diciendo con cuanto murio. Y la marca se pone aunque la perilla este en 0,
    -- porque es un hecho y no un efecto.
    estado( ply ).murio = CurTime()

end )

-- ⚠ El destierro de §5.4 NO EXISTE, asi que el unico desenlace disponible es
-- MATAR al fantasma. La causa se llama `destierro` igual, porque es el mismo
-- renglon del diseño y el dia que §5.4 se escriba no hay que renombrar nada.
--
-- Cuelga de `OnNPCKilled`, que la base Terminator REEMITE para sus nextbots
-- ( damageandhealth.lua:829 ) -- no es exclusivo de los NPC del engine.
-- El cuerpo va adentro de un pcall: un error en un listener de `hook.Run` aborta
-- el resto de la secuencia del que lo disparo, y ahi al lado esta la muerte del
-- fantasma a medio procesar.
hook.Add( "OnNPCKilled", "phantasmagoria_sanity_destierro", function( ent )
    if not IsValid( ent ) then return end
    if not ent.IsPhantasmagoriaGhost then return end

    pcall( function()
        for _, ply in ipairs( player.GetAll() ) do
            if not IsValid( ply ) then continue end

            local st = estado( ply )

            aplicar( ply, st.inicial - st.val, "destierro", nil, 100 )

        end
    end )
end )

---------------------------------------------------------------------------
-- LOS INSTRUMENTOS
---------------------------------------------------------------------------
-- §19.8.8 lo dice y hay que cumplirlo tal cual: UNA BARRA QUE BAJA NO DICE QUE
-- LA BAJO. El reporte es la mitad del trabajo de este bloque, no el adorno.

local function addCmd( name, fn, help )
    if isfunction( PHANTASMAGORIA.AddCommand ) then
        return PHANTASMAGORIA.AddCommand( name, fn, help )

    end

    -- La misma guarda que la del proyecto, replicada y no salteada: una convar y
    -- un concommand con el mismo nombre resuelven a la convar y el comando queda
    -- MUDO. Eso costo la ronda 2 entera.
    if ConVarExists( name ) then
        ErrorNoHalt( "[Phantasmagoria] COLISION DE NOMBRE: '" .. name .. "' ya existe como CONVAR.\n" )
        return false

    end

    concommand.Add( name, fn, nil, help )
    return true

end

local function hacerSay( ply )
    if isfunction( PHANTASMAGORIA.MakeSay ) then return PHANTASMAGORIA.MakeSay( ply ) end

    return function( line )
        if IsValid( ply ) then ply:PrintMessage( HUD_PRINTCONSOLE, tostring( line ) )
        else print( line ) end

    end
end

local function pct( n )
    return ( n >= 0 and "+" or "" ) .. string.format( "%.2f", n ) .. " %"

end

-- Busca la fuente continua por id, para poder decir CUANTAS veces se la
-- interrogo y que contesto la ultima. Sin eso, "su fuente corrio y nunca aplico"
-- seria una afirmacion sin numero -- y una afirmacion sin numero es prosa.
local function fuentePorId( id )
    for _, f in ipairs( FUENTES ) do
        if f.id == id then return f end

    end
end

-- ⚠⚠ LOS TRES CEROS, Y POR QUE NO PUEDEN COMPARTIR TEXTO.
-- Un renglon en `+0.00 %` lo cumplen tres estados distintos, y hasta la r1 los
-- tres imprimian `( sin llamador todavia )`:
--
--   ( a ) NADIE LA LLAMA            los ocho eventos. Es cierto y es B2.
--   ( b ) SU FUENTE CORRIO Y DIJO QUE NO   `goteo pasivo` con la barra arriba
--         del techo: la fuente se interrogo 3.198 veces. Decirle "sin llamador"
--         manda a buscar un enganche que existe y funciona.
--   ( c ) SU DISPARADOR EXISTE Y NO OCURRIO   la muerte, el destierro, una dosis.
--
-- El texto sale de `prod`, que es un campo de la causa y no una adivinanza del
-- que imprime.
local function porQueEnCero( c )
    local prod = c and c.prod

    if not prod then return "( nunca ocurrio )" end

    if prod == "B2" then
        return "( sin llamador todavia: los ocho eventos son B2 )"

    end

    local fid = string.match( prod, "^fuente:(.+)$" )

    if fid then
        local f = fuentePorId( fid )

        if not f then
            return "( ⚠ su fuente '" .. fid .. "' NO ESTA REGISTRADA )"

        end

        local total = f.activos + f.inactivos

        if total <= 0 then
            return "( ⚠ su fuente '" .. fid .. "' no se interrogo ni una vez )"

        end

        return "( la fuente '" .. fid .. "' corrio " .. total ..
            " veces y nunca aplico aca: " .. tostring( f.nota ) .. " )"

    end

    return "( nunca ocurrio; lo dispara " .. prod .. " )"

end

local function fila( say, label, b, cv, causa )
    local hayAlgo = b.aplicado ~= 0 or b.potencial ~= 0 or b.veces > 0 or b.ticks > 0

    local linea = string.format( "    %-20s %10s", label, pct( b.aplicado ) )

    if b.ticks > 0 then
        linea = linea .. string.format( "   en %6.1f s / %d ticks", b.segundos, b.ticks )

    elseif b.veces > 0 then
        linea = linea .. string.format( "   %d veces", b.veces )

    end

    -- ⚠ EL POTENCIAL SOLO SE IMPRIME CUANDO DIFIERE DE LO APLICADO, y ahi es la
    -- linea mas informativa del reporte: es la que separa "el control funciono"
    -- de "el sujeto nunca llego".
    if math.abs( b.potencial - b.aplicado ) > 0.005 then
        linea = linea .. "   [ potencial " .. pct( b.potencial )

        if cv and not cv:GetBool() then
            linea = linea .. ", CONTROL: " .. cv:GetName() .. " en 0"

        elseif b.aplicado == 0 and b.potencial ~= 0 then
            linea = linea .. ", tope alcanzado"

        end

        linea = linea .. " ]"

    end

    if not hayAlgo then
        linea = linea .. "   " .. porQueEnCero( causa )

    end

    say( linea )

end

addCmd( "phantasmagoria_cordura", function( ply )
    local say = hacerSay( ply )

    say( "" )
    say( "[Phantasmagoria] CORDURA -- Diseno 19.8, tajada B1" )
    -- ⚠ EL PEDIDO Y EL REAL NO SON EL MISMO NUMERO, y hasta la r1 se imprimia
    -- solo el pedido. El timer late a 0,05 s y el tick sale en el primer latido
    -- que pasa el umbral, asi que con `_tick 0.25` el periodo real es 0,30 --
    -- un 20 % mas. Las TASAS no se ven afectadas porque el dt se mide ( el goteo
    -- dio 0,200 %/s clavado ), pero un instrumento que imprime lo que se pidio
    -- en el lugar de lo que pasa acredita el pedido y no el efecto.
    local real = ticksReales > 0 and ( segsReales / ticksReales ) or 0

    say( "  tick        pedido " .. string.format( "%.2f", cvTick:GetFloat() ) ..
        " s  ·  REAL " .. string.format( "%.3f", real ) .. " s ( medido )   ( " .. ticksTotal ..
        " ticks, ultimo hace " .. string.format( "%.1f", CurTime() - ultimoTick ) .. " s )" )
    say( "  inicial     " .. math.Round( cvInicial:GetFloat() ) .. " %" )
    -- ⚠ El conteo va a un local ANTES de la concatenacion: `cadaFantasma` es lo
    -- que ESCRIBE `viaGhosts`, y el orden en que Lua evalua los operandos de un
    -- `..` no esta garantizado. Inline, el reporte podria imprimir el camino de
    -- la corrida ANTERIOR al lado del conteo de esta.
    local nGhosts = cadaFantasma( function() end )
    say( "  fantasmas   " .. nGhosts .. "   ( via " .. viaGhosts .. " )" )
    say( "  items Cargo " .. ( cargoHecho and ( "registrados ( disparo: " .. tostring( cargoQuien ) .. " )" )
        or ( "NO registrados ( " .. cargoIntentos .. " intentos; Cargo no esta montado )" ) ) )

    say( "" )
    say( "  FUENTES CONTINUAS -- la forma que el rasgo del Phantom va a necesitar" )

    for _, f in ipairs( FUENTES ) do
        local total = f.activos + f.inactivos

        -- "muestras" y no "ticks": con dos jugadores el tick produce DOS
        -- lecturas por fuente, y llamarlas ticks daria un denominador que no
        -- cierra contra el contador de ticks de arriba.
        say( string.format( "    %-14s %s   %d/%d muestras activa   ultimo motivo%s: %s",
            f.id,
            f.activos > 0 and "ACTIVA  " or "inactiva",
            f.activos, total,
            f.notaDe and ( " ( " .. f.notaDe .. " )" ) or "",
            f.nota ) )

    end

    say( "" )
    say( "  PERILLAS DE CAUSA   ( 0 = control; suprimen el EFECTO, nunca la cuenta )" )
    say( "    presencia " .. cvPresencia:GetInt() ..
        "   ·  eventos " .. cvEventos:GetInt() .. " ( ANDAMIO: sin llamador hasta B2 )" )
    say( "    regen " .. cvRegen:GetInt() ..
        "   ·  safe " .. cvSafe:GetInt() .. " ( sin sujeto: la zona no existe )" ..
        "   ·  meds " .. cvMeds:GetInt() ..
        "   ·  muerte " .. cvMuerte:GetInt() ..
        "   ·  destierro " .. cvDestierro:GetInt() )
    say( "    oscuridad " .. cvDark:GetInt() .. "   ( MODULADOR, no causa )" )

    say( "" )
    say( "  TASAS Y GEOMETRIA   ( renglon aparte a proposito: son numeros continuos )" )
    say( "    presencia   calma " .. string.format( "%.3f", cvCalma:GetFloat() ) ..
        " %/s   hunt " .. string.format( "%.3f", cvHunt:GetFloat() ) .. " %/s" )
    say( "    esfera      radio " .. math.Round( cvRadio:GetFloat() ) ..
        " u   meseta " .. math.Round( cvMeseta:GetFloat() ) ..
        " u   en hunt x" .. string.format( "%.2f", cvHuntRadio:GetFloat() ) ..
        " ( " .. math.Round( cvRadio:GetFloat() * cvHuntRadio:GetFloat() ) .. " u )" )
    say( "    goteo       " .. string.format( "%.3f", cvRegenRate:GetFloat() ) ..
        " %/s   retardo " .. math.Round( cvRegenDelay:GetFloat() ) ..
        " s   techo " .. math.Round( cvRegenCap:GetFloat() ) .. " %" )
    say( "    zona segura " .. string.format( "%.3f", cvSafeRate:GetFloat() ) ..
        " %/s   techo " .. math.Round( cvSafeCap:GetFloat() ) .. " %" )
    say( "    oscuridad   a oscuras x" .. string.format( "%.2f", cvDarkMul:GetFloat() ) ..
        "   iluminado x" .. string.format( "%.2f", cvLitMul:GetFloat() ) ..
        "   radio de ambiente " .. math.Round( cvLitRadio:GetFloat() ) .. " u" )
    say( "    medicacion  I +" .. PHANTASMAGORIA.SanityMeds[ 1 ].pct ..
        " %  ·  II +" .. PHANTASMAGORIA.SanityMeds[ 2 ].pct ..
        " %  ·  III +" .. PHANTASMAGORIA.SanityMeds[ 3 ].pct ..
        " %   enfriamiento " .. math.Round( cvMedCD:GetFloat() ) .. " s" )

    for _, p in ipairs( player.GetAll() ) do
        if not IsValid( p ) then continue end

        local st = estado( p )

        say( "" )
        say( "  " .. p:Nick() .. "   cordura " .. string.format( "%.2f", st.val ) .. " %" ..
            ( p:Alive() and "" or "   ( MUERTO )" ) )

        local lit, motivoLuz, ciegas = PHANTASMAGORIA.IsPlayerLit( p )

        say( "    luz         " .. ( lit and "ILUMINADO" or "a oscuras" ) .. "   ( " .. motivoLuz .. " )" ..
            ( ciegas > 0 and ( "   ⚠ punto ciego: " .. ciegas .. " luces del mapa sin getter" ) or "" ) )

        say( "    esfera      " .. st.esferaTicks .. " ticks con el fantasma cerca  ( " ..
            string.format( "%.1f", st.esferaSegs ) .. " s )" )

        local suma = 0

        for _, c in ipairs( CAUSAS ) do
            local b = st.acc[ c.id ]
            suma = suma + b.aplicado

            local _, cv = perillaDe( c.id )
            fila( say, c.label, b, cv, c )

        end

        for _, id in ipairs( st.extraOrden ) do
            fila( say, id .. " ⚠ NO DECLARADA", st.extra[ id ], nil, nil )
            suma = suma + st.extra[ id ].aplicado

        end

        say( "    " .. string.rep( "-", 60 ) )
        say( string.format( "    %-20s %10s   en %.0f s de partida", "neto", pct( suma ), CurTime() - st.t0 ) )

        -- ⚠ EL CIERRE DEL DESGLOSE CONTRA EL VALOR. Sin esto, un renglon que se
        -- olvida de anotar deja la suma y la barra discrepando sin que nada lo
        -- diga -- y el desglose se leeria completo. `partida` es el valor con el
        -- que se arranco, que es el inicial salvo que alguien lo haya movido.
        local esperado = st.inicial + suma
        local brecha   = st.val - esperado

        if math.abs( brecha ) > 0.05 then
            say( string.format( "    ⚠⚠ EL DESGLOSE NO CIERRA: barra %.2f, desglose predice %.2f, brecha %.2f",
                st.val, esperado, brecha ) )
            say( "       Alguien escribio la cordura sin pasar por la puerta, o una causa no se anota." )

        end

        if st.ultima then
            say( "    ultima      " .. st.ultima.label .. "   " .. pct( st.ultima.delta ) ..
                "   hace " .. string.format( "%.1f", CurTime() - st.ultima.t ) .. " s" ..
                "   ( " .. ( st.ultima.continua and "continua" or "plana" ) .. " )" )

        else
            say( "    ultima      -- nada la movio todavia --" )

        end

        say( "    estado nacio por: " .. tostring( st.nacioPor ) )

    end

    say( "" )

end, "Reporte de la cordura ( Diseno 19.8, B1 ): valor, desglose por causa, fuentes continuas y perillas." )

addCmd( "phantasmagoria_cordura_reset", function( ply )
    local say = hacerSay( ply )
    local n = 0

    for _, p in ipairs( player.GetAll() ) do
        if not IsValid( p ) then continue end

        p.phantom_San = nil
        estado( p, "reset" )
        n = n + 1

    end

    for _, f in ipairs( FUENTES ) do
        f.activos, f.inactivos, f.nota, f.notaDe = 0, 0, "reseteada", nil

    end

    ticksTotal, ticksReales, segsReales = 0, 0, 0

    say( "[Phantasmagoria] cordura reseteada en " .. n .. " jugadores ( valor " ..
        math.Round( cvInicial:GetFloat() ) .. " %, desglose en cero, contadores de fuente en cero )." )

end, "Vuelve la cordura de todos al inicial y pone el desglose y los contadores en cero. Se corre ANTES de cada fila de la planilla." )

-- ANDAMIO, declarado en su propia ayuda. §19.9.8: un andamio que no se anuncia
-- como andamio se convierte en la feature.
addCmd( "phantasmagoria_cordura_set", function( ply, _, args )
    local say = hacerSay( ply )
    local n   = tonumber( args and args[ 1 ] )

    if not n then
        say( "[Phantasmagoria] uso: phantasmagoria_cordura_set <0..100> [ nick ]" )
        return

    end

    local objetivo = args[ 2 ]
    local tocados  = 0

    for _, p in ipairs( player.GetAll() ) do
        if not IsValid( p ) then continue end
        if objetivo and not string.find( string.lower( p:Nick() ), string.lower( objetivo ), 1, true ) then continue end

        PHANTASMAGORIA.SetSanity( p, n, "andamio" )
        tocados = tocados + 1

        say( "[Phantasmagoria] " .. p:Nick() .. " -> " .. string.format( "%.2f", PHANTASMAGORIA.GetSanity( p ) ) .. " %" )

    end

    if tocados == 0 then say( "[Phantasmagoria] ningun jugador coincidio." ) end

end, "ANDAMIO. Fija la cordura de un jugador para poder partir de un valor conocido en una fila. Se anota como causa 'andamio consola' a proposito." )

-- ANDAMIO. §19.9.8 lo pedia para poder medir la restauracion sin depender de
-- Cargo, y sigue haciendo falta aunque las defs ya se registren: la planilla
-- tiene que poder correr en un server sin Corpus montado.
addCmd( "phantasmagoria_cordura_med", function( ply, _, args )
    local say  = hacerSay( ply )
    local tier = tonumber( args and args[ 1 ] ) or 2

    if not IsValid( ply ) then
        say( "[Phantasmagoria] este andamio necesita un jugador ( no corre desde la consola del server )." )
        return

    end

    local ok, motivo = PHANTASMAGORIA.UseSanityMed( ply, tier, "andamio" )

    say( "[Phantasmagoria] medicacion tier " .. tier .. ": " .. ( ok and "TOMADA" or "RECHAZADA" ) .. " -- " .. tostring( motivo ) )
    say( "                 cordura " .. string.format( "%.2f", PHANTASMAGORIA.GetSanity( ply ) ) .. " %" )

end, "ANDAMIO. Toma una dosis de medicacion ( 1 = bebida, 2 = pastillas, 3 = adrenalina ) sin pasar por Cargo. Un RECHAZADO con la barra llena es el anti-desperdicio funcionando, no un defecto." )

-- ANDAMIO de drenaje: la fila 04 necesita poder disparar la forma PLANA sin
-- esperar a que B2 exista, y la 05 necesita poder mover un renglon a la vez.
addCmd( "phantasmagoria_cordura_drenar", function( ply, _, args )
    local say   = hacerSay( ply )
    local n     = tonumber( args and args[ 1 ] ) or 10
    local causa = args and args[ 2 ] or "evento:sound"

    if not IsValid( ply ) then
        say( "[Phantasmagoria] este andamio necesita un jugador." )
        return

    end

    local real = PHANTASMAGORIA.DrainSanity( ply, n, causa )

    say( "[Phantasmagoria] drenaje plano de " .. n .. " % contra '" .. causa .. "': entraron " ..
        string.format( "%.2f", real ) .. " %   ->   " .. string.format( "%.2f", PHANTASMAGORIA.GetSanity( ply ) ) .. " %" )

end, "ANDAMIO. Dispara la forma PLANA de drenaje contra la causa que se le diga ( default evento:sound ), para poder medir la puerta antes de que B2 tenga llamadores." )

MsgC( Color( 190, 120, 255 ), "[Phantasmagoria] ", color_white,
    "cordura B1 lista: " .. #FUENTES .. " fuentes continuas, " .. #CAUSAS ..
    " causas declaradas. Reporte: phantasmagoria_cordura\n" )
