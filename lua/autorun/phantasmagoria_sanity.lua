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
    "Multiplicador de la presencia con el jugador A OSCURAS **MEDIDO** ( §19.8.5 ): habia luces legibles cerca y todas estaban apagadas.", 0, 5 )

-- ⚠⚠⚠ LA TERCERA LECTURA, Y NACE EN EL MISMO 1.5 A PROPOSITO ( B2 ).
-- Hasta B1 habia DOS estados donde hay TRES: "medi que esta a oscuras" y "no
-- pude medir nada" salian las dos por el mismo `false` de `IsPlayerLit` y las
-- dos cobraban `darkmul`. Con 25 luces sin getter, eso es un tercio del drenaje
-- decidido sobre una lectura que el instrumento declara imposible.
--
-- Nace en 1.5 -- el numero de antes -- porque B2 tiene que poder medirse contra
-- B1 sin que el gameplay se mueva por abajo: una tajada que ademas cambia el
-- comportamiento deja un rojo con dos causas. Lo que gana el bloque hoy es que
-- ese tercio tenga renglon propio ( `oscuridad ciega` ) y perilla propia. En 1.0
-- la adivinanza deja de cobrar y se ve exactamente cuanto era.
local cvCiegaMul = CreateConVar( "phantasmagoria_sanity_ciegamul", "1.5", FCVAR_ARCHIVE,
    "Multiplicador de la presencia cuando NO SE PUDO LEER la luz ( ninguna luz legible cerca: sin getter, o mapa de iluminacion horneada ). Nace igual que darkmul para no mover el gameplay; en 1.0 la lectura que no se pudo hacer deja de cobrar.", 0, 5 )

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

-- EVENTOS ( B2 ) -- ⚠⚠ YA NO ES UN ANDAMIO, Y AHORA TIENE TRES ESTADOS
--
-- El header de B1 decia que ninguna de sus perillas era de tres estados A
-- PROPOSITO: no habia ningun rasgo POR TIPO que respetar, y *una perilla cuyo
-- valor intermedio no significa nada se lee como que el flag ya existe*. Con la
-- sub-tabla `sanity` de ghost_flags.lua escrita ( el x2 del Oni, el 15 % de
-- puerta del Yurei, el 0,5 %/s del Phantom ), ese 2 pasa a tener sujeto.
--
-- ⚠ Y LOS TRES ESTADOS TIENEN TRES CUENTAS DISTINTAS, que es la unica forma de
-- que no sea el defecto "tres estados con dos cuentas" del catalogo -- el mismo
-- que ya tuvo `phantasmagoria_ghost_evhunt`, cuyo 2 producia exactamente el
-- mismo resultado que el 1 con el reporte imprimiendo "( forzado )" al lado:
--
--   0   nadie drena por eventos                       ( CONTROL )
--   1   drena, y los rasgos del TIPO modulan          ( el juego )
--   2   drena, y los rasgos del tipo SE IGNORAN       ( A/B del rasgo )
--
-- El 2 sirve para una fila concreta y no es decorativo: con un Oni delante, 1 y
-- 2 dan 26 % y 13 % por manifestacion. Sin el, aislar el x2 del Oni pediria
-- cambiar el TIPO del fantasma -- o sea cambiar el sujeto para medir el rasgo.
-- ( Con un Spirit, 1 y 2 dan lo mismo: es el tipo baseline y no tiene rasgos.
--   Eso NO los vuelve indistinguibles -- el estado se distingue sobre el sujeto
--   que lo ejercita, no sobre cualquiera. )
local cvEventos = CreateConVar( "phantasmagoria_sanity_eventos", "1", FCVAR_ARCHIVE,
    "0 = los eventos no drenan ( CONTROL ) · 1 = drenan con los rasgos del tipo ( el juego ) · 2 = drenan IGNORANDO los rasgos del tipo, para poder aislar en un A/B el x2 del Oni, el 15 % de puerta del Yurei y el 0,5 %/s del Phantom.", 0, 2 )

---------------------------------------------------------------------------
-- LAS PERILLAS, JUNTAS, PARA PODER VOLVER A FABRICA DE UN COMANDO
---------------------------------------------------------------------------
-- ⚠⚠⚠ NACE DE LA r3, Y DE UN DEFECTO QUE YA TENIA DOS RONDAS DE VIDA. Todas
-- son FCVAR_ARCHIVE, o sea que quedan guardadas en la maquina del que prueba.
-- La r1 lo pago con dos perillas de ENCENDIDO que quedaron en 0 ( catalogo
-- nº 91 ) y la respuesta fue una lista de ocho lineas para pegar a mano.
--
-- La r3 mostro que esa respuesta cubria la mitad chica del problema: llego con
-- `phantasmagoria_sanity_regendelay` en 30 cuando el diseño dice 45, movida en
-- un A/B de la r2 y nunca restituida. Una lista de perillas de ENCENDIDO no
-- puede restituir un NUMERO -- y un numero movido no se nota, porque no hay
-- ningun renglon que diga "esto no es lo de fabrica": el reporte imprime 30 con
-- la misma cara con la que imprime 45.
--
-- ⭐ Por eso esto NO es una lista en la prosa de un handoff sino un COMANDO que
-- ademas DICE QUE MOVIO ( nº 70a: una salida que no se puede producir sin la
-- precondicion vale mas que una precondicion bien escrita ). Y el default no se
-- reescribe aca: sale de `GetDefault()`, asi que cambiar un valor de diseño en
-- su `CreateConVar` no deja una segunda copia envejeciendo al lado.
-- ⚠⚠⚠ B2 LO CONVIRTIO EN UN REGISTRO COMPARTIDO, Y LA RAZON ES EL CATALOGO
-- Nº 112: *toda defensa que consista en "acordate de restituir X" tiene que ser
-- un comando que ENUMERE EL UNIVERSO de X.* La version de B1 enumeraba un
-- universo escrito a mano en este archivo -- o sea que cubria exactamente las
-- perillas que estaban el dia que se escribio.
--
-- Y B2 rompe ese supuesto de la unica forma que importa: agrega perillas de
-- cordura EN OTRO ARCHIVO ( server_events.lua, el radio y el tope del drenaje
-- por evento ). Con una lista local no hay forma de que entren, y una perilla de
-- cordura fuera de la vuelta a fabrica es exactamente el defecto de la r3 --
-- salvo que ahora ni siquiera saldria en el listado que lo delata.
--
-- LA FORMA ES UNA TABLA Y NO UNA FUNCION, Y ESO ES DELIBERADO: el orden de carga
-- entre `lua/autorun/` y `lua/entities/` LO DECIDE EL ENGINE. Con una funcion de
-- registro, el que cargue primero encuentra nil y sus perillas no entran nunca,
-- en silencio. Con `X = X or {}` en las dos puntas, el que llegue primero crea la
-- tabla y el segundo la encuentra -- y no hay orden que lo rompa.
--
-- GMod no tiene API para enumerar convars por prefijo, asi que un registro es
-- inevitable; lo que se puede evitar es que el registro tenga UN solo dueño.
PHANTASMAGORIA.PerillasCordura = PHANTASMAGORIA.PerillasCordura or {}

for _, cv in ipairs( {
    cvTick, cvInicial,
    cvPresencia, cvCalma, cvHunt, cvRadio, cvMeseta, cvHuntRadio,
    cvDark, cvDarkMul, cvCiegaMul, cvLitMul, cvLitRadio,
    cvRegen, cvRegenRate, cvRegenDelay, cvRegenCap,
    cvSafe, cvSafeRate, cvSafeCap,
    cvMeds, cvMedCD,
    cvMuerte, cvDestierro, cvEventos,
} ) do
    PHANTASMAGORIA.PerillasCordura[ #PHANTASMAGORIA.PerillasCordura + 1 ] =
        { cv = cv, dueno = "phantasmagoria_sanity.lua" }

end

-- ⚠ SE DEDUPLICA AL LEER Y NO AL ESCRIBIR. Un `lua_reloadents` o un autorefresh
-- vuelve a correr el bloque de arriba, y una lista con la misma perilla dos veces
-- imprimiria "2 de 50 movidas" sobre una sola perilla movida. Deduplicar al
-- escribir obligaria a un barrido por cada registro; al leer cuesta una tabla en
-- un comando que corre a mano.
local function perillasTodas()
    local vistas, out = {}, {}

    for _, r in ipairs( PHANTASMAGORIA.PerillasCordura ) do
        local cv = r.cv

        if cv and not vistas[ cv:GetName() ] then
            vistas[ cv:GetName() ] = true
            out[ #out + 1 ] = r

        end
    end

    return out

end

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

    -- ⚠⚠⚠ EL RENGLON QUE B2 PARTIO EN DOS, Y ES LA MITAD QUE NADIE PODIA VER.
    -- Hasta B1 este drenaje se sumaba al de arriba, porque `IsPlayerLit`
    -- devolvia un BOOLEANO: "medi que esta a oscuras" y "no pude leer NINGUNA
    -- luz" salian las dos por el mismo `false`. En el mapa de la r3 eso son 25
    -- luces sin getter, o sea que casi todo lo que el renglon `oscuridad`
    -- acreditaba como medicion era una adivinanza -- y el x1,5 aporta un tercio
    -- del drenaje en toda lectura a oscuras.
    --
    -- Partido, el A/B se puede hacer: `ciegamul` en 1.0 apaga SOLO la
    -- adivinanza y deja viva la lectura buena, y la diferencia entre los dos
    -- renglones dice exactamente cuanto de la barra lo decidio algo que no se
    -- pudo medir. Junto, no habia ninguna corrida capaz de separarlos.
    { id = "oscuridad_ciega", fam = "presencia", fam2 = "oscuridad", label = "oscuridad CIEGA", prod = "fuente:presencia" },

    -- ⚠⚠⚠ LOS OCHO USABAN DOS PUNTOS -- `evento:sound` -- Y ESO LOS VOLVIA
    -- INALCANZABLES DESDE LA CONSOLA. La r2 dejo la fila 04 en ROJO por esto y
    -- el reporte lo dijo bien: entro una causa `evento` ⚠ NO DECLARADA.
    --
    -- El tokenizador de comandos de Source ( CCommand::Tokenize, tier1 ) parte
    -- la linea con un break set que incluye `{ } ( ) ' :`, y esos caracteres
    -- salen como TOKENS PROPIOS. Asi que `drenar 10 evento:sound` no llega como
    -- dos argumentos sino como CUATRO -- "10", "evento", ":", "sound" -- y el
    -- comando leia args[2], que es "evento". No hubo error de Lua ni de red: el
    -- string se partio antes de que el addon lo viera.
    --
    -- Es el pariente de la truncada a 255 de la consola: el transporte le come
    -- algo al texto sin avisar, y el sintoma aparece dos capas mas abajo,
    -- disfrazado de defecto del receptor. LA REGLA QUE QUEDA: ningun id que un
    -- andamio tenga que poder TIPEAR lleva un caracter del break set. El control
    -- de arranque de mas abajo lo verifica sobre las 19 causas y no sobre estas
    -- ocho, que es lo que lo hace un control y no un parche.
    { id = "evento_sound",     fam = "eventos", label = "evento sound",     prod = "B2" },
    { id = "evento_throw",     fam = "eventos", label = "evento throw",     prod = "B2" },
    { id = "evento_light",     fam = "eventos", label = "evento light",     prod = "B2" },
    { id = "evento_prop",      fam = "eventos", label = "evento prop",      prod = "B2" },
    { id = "evento_knock",     fam = "eventos", label = "evento knock",     prod = "B2" },
    { id = "evento_door",      fam = "eventos", label = "evento door",      prod = "B2" },
    { id = "evento_furniture", fam = "eventos", label = "evento furniture", prod = "B2" },
    { id = "evento_creak",     fam = "eventos", label = "evento creak",     prod = "B2" },

    -- ⚠⚠ EL RASGO CONTINUO POR TIPO ( B2 ), Y SU PERILLA ES LA DE **EVENTOS**
    -- AUNQUE NO SEA UN EVENTO. El sujeto es el mismo -- los rasgos de la
    -- sub-tabla `sanity` de un tipo -- y una fila que ponga `eventos 0` para
    -- correr un control tiene que apagar los rasgos ENTEROS: si este renglon
    -- quedara vivo, el control diria "con los rasgos apagados sigue drenando" y
    -- mandaria a buscar un segundo mecanismo que no existe.
    --
    -- Hoy es el 0,5 %/s del Phantom y NO TIENE SUJETO: pide que el fantasma
    -- este manifestandose, y las manifestaciones de §22 no estan escritas. Su
    -- fuente esta registrada y contesta POR QUE no aplica, que es lo unico que
    -- distingue esto de no haberlo escrito ( el precedente es la zona segura ).
    { id = "presencia_tipo", fam = "eventos", label = "rasgo continuo",  prod = "fuente:presencia_tipo" },

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

---------------------------------------------------------------------------
-- CONTROL DE ARRANQUE: que TODA causa se pueda TIPEAR
---------------------------------------------------------------------------
-- Nace de la r2, y no de una idea: los ocho ids de evento llevaban dos puntos y
-- el tokenizador de la consola de Source los partia en pedazos, asi que el
-- andamio de la fila 04 no podia nombrarlos ni una sola vez. El defecto vivio
-- desde que se escribio el bloque y NINGUN instrumento lo veia -- ni el
-- luacheck, ni el parser de sintaxis, ni el auditor de la puerta -- porque
-- ninguno de los tres sabe nada de la consola.
--
-- ⚠ Lo que se verifica NO es que los ocho tengan guion bajo: eso seria repetir
-- el arreglo en forma de check y saldria verde por construccion ( nº 42 ). Lo
-- que se verifica es la PROPIEDAD -- que ningun id de las 19 lleve un caracter
-- que el transporte rompa -- asi que una causa nueva de B2 escrita con dos
-- puntos vuelve a encender esto.
--
-- El break set de `CCommand::Tokenize` es `{}()':` ; se agregan los que rompen
-- la LINEA antes de llegar al tokenizador ( `;` separa comandos, `"` abre
-- comilla, el espacio separa argumentos ) y el `/` de un `//` comentado.
local ROMPEN_CONSOLA = { "{", "}", "(", ")", "'", ":", ";", '"', " ", "\t" }

do
    local rotos = {}

    for _, c in ipairs( CAUSAS ) do
        for _, ch in ipairs( ROMPEN_CONSOLA ) do
            -- `true` al final: comparacion literal, sin patrones. Buscar un
            -- caracter de puntuacion COMO patron es el error que convierte un
            -- control en un adorno que siempre pasa.
            if string.find( c.id, ch, 1, true ) then
                rotos[ #rotos + 1 ] = c.id
                break

            end
        end
    end

    if #rotos > 0 then
        ErrorNoHalt( "[Phantasmagoria] CORDURA: " .. #rotos .. " causa( s ) con un id que la consola de Source " ..
            "PARTE en pedazos, asi que ningun andamio las puede nombrar y su renglon del desglose es inalcanzable: " ..
            table.concat( rotos, ", " ) .. " -- reescribirlas con guion bajo.\n" )

    end
end

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
-- llamador que escribe mal el string -- "evento_ruido" en vez de "evento_sound" --
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
-- ⚠⚠ LA COPIA SE FUE, Y ESO ES B2. B1 tenia aca una lista de nombres de clase
-- COPIADA de server_events.lua, declarada como copia y acotada a lo unico que no
-- podia producir un falso verde: alimentaba el contador del punto ciego y nunca
-- decidia si un jugador estaba iluminado. La lista canonica vive hoy en
-- `lua/phantasmagoria/luces.lua` y este archivo la consulta.
--
-- ⚠⚠⚠ Y CON ELLA SE FUE UN DEFECTO MAS GRANDE QUE LA COPIA: LA FUNCION DEVOLVIA
-- DOS ESTADOS DONDE HAY TRES.
--
-- El `false` de "las lamparas de al lado estan APAGADAS" y el `false` de "no hay
-- una sola luz que se pueda preguntar" se imprimian igual, viajaban igual, y el
-- modulador de §19.9.2 le cobraba el x1,5 de la oscuridad a los dos por igual.
-- Con las 25 luces sin getter que midio la r3, eso es *un tercio del drenaje
-- decidido sobre una lectura que el propio instrumento declara que no puede
-- hacer* -- y el handoff de B2 lo puso como lo primero que habia que cerrar.
--
-- ⚠ LO QUE **NO** CAMBIA ES EL COMPORTAMIENTO, Y ESO ES DELIBERADO. La perilla
-- nueva `phantasmagoria_sanity_ciegamul` nace en 1.5, o sea EXACTAMENTE el mismo
-- numero que antes: una tajada que ademas mueve el gameplay deja un rojo con dos
-- causas posibles, que es lo que este bloque viene evitando desde B1. Lo que
-- cambia es que ese tercio del drenaje ahora tiene NOMBRE, RENGLON PROPIO en el
-- desglose y PERILLA PROPIA -- o sea que se puede aislar en un A/B y el autor
-- puede bajarla a 1.0 con una linea el dia que decida que una adivinanza no vale
-- un tercio de la barra. *Medir primero y recien despues mover el numero.*
--
-- ⚠ §19.9.2 acepto POR ESCRITO que un mapa de iluminacion horneada se lea como
-- oscuro. Esto no lo contradice: lo cuenta. La aceptacion sigue vigente y ahora
-- tiene denominador.

-- Las tres lecturas posibles. Son ids TIPEABLES ( sin ningun caracter del break
-- set de la consola ) porque dos de ellas son tambien ids de causa.
local LEIDO_ILUMINADO = "iluminado"
local LEIDO_OSCURO    = "oscuro"
local LEIDO_CIEGO     = "sin_lectura"

-- ⚠ DEVUELVE CUATRO COSAS Y LA PRIMERA SIGUE SIENDO EL BOOLEANO DE B1: cualquier
-- consumidor futuro que solo pregunte "¿esta iluminado?" sigue leyendo lo mismo.
-- El tercer y el cuarto valor son los que hacen la diferencia entre las dos
-- formas del `false`.
--
--   lit       true solo si se MIDIO que hay luz
--   motivo    texto
--   ciegas    cuantas luces se vieron y no se pudieron interrogar
--   lectura   LEIDO_ILUMINADO | LEIDO_OSCURO | LEIDO_CIEGO
function PHANTASMAGORIA.IsPlayerLit( ply )
    if not IsValid( ply ) or not ply:IsPlayer() then return false, "no es un jugador", 0, LEIDO_CIEGO end

    -- ⚠ `FlashlightIsOn` es SERVER-ONLY EN LAS DOS DIRECCIONES: leerlo en el
    -- cliente devuelve false con el haz pintando una pared ( medido por Cargo,
    -- corpus_cargo_lights.lua ). Acá estamos en el servidor, que es donde
    -- funciona -- y es la razon de fondo por la que §19.9.2 eligio la opcion B
    -- sobre la C: la mitad de C que corre en CLIENT no podria leer esto.
    if ply:FlashlightIsOn() then return true, "linterna", 0, LEIDO_ILUMINADO end

    local radio  = cvLitRadio:GetFloat()
    local radio2 = radio * radio
    local pos    = ply:GetPos()
    local ciegas, apagadas = 0, 0

    local clases = istable( PHANTASMAGORIA.LightClasses ) and PHANTASMAGORIA.LightClasses or nil

    if not clases then
        -- ⚠ SIN LA TABLA CANONICA LA RESPUESTA ES "NO SE PUEDE LEER", NO "A
        -- OSCURAS". Contestar oscuro seria fabricar una medicion sobre un
        -- archivo que no cargo, y el x1,5 saldria del mismo lugar del que sale
        -- una lectura buena. Es el nº 112b aplicado al caso peor: el instrumento
        -- sin sujeto no contesta.
        return false, "⚠ phantasmagoria/luces.lua NO CARGO: no hay lista de clases que preguntar", 0, LEIDO_CIEGO

    end

    for _, fam in ipairs( clases ) do
        for _, e in ipairs( ents.FindByClass( fam.clase ) ) do
            if not IsValid( e ) then continue end
            if e:GetPos():DistToSqr( pos ) > radio2 then continue end

            local encendida = PHANTASMAGORIA.LuzEncendida( fam, e )

            if encendida == nil then
                ciegas = ciegas + 1

            elseif encendida then
                return true, fam.clase .. " #" .. e:EntIndex() .. " a " ..
                    math.Round( e:GetPos():Distance( pos ) ) .. " u", ciegas, LEIDO_ILUMINADO

            else
                apagadas = apagadas + 1

            end
        end
    end

    -- ⚠⚠ EL ORDEN DE ESTOS DOS RETORNOS ES LA DECISION ENTERA. Una luz LEGIBLE y
    -- apagada al lado es una medicion: se sabe que ahi no hay luz. Una luz
    -- ilegible al lado no dice nada -- puede estar prendida iluminando el
    -- cuarto. Si el `ciegas > 0` fuera primero, un cuarto con una lampara de
    -- sandbox apagada Y un light_spot cerca se leeria como "no se pudo medir",
    -- y perderiamos la unica lectura buena que habia.
    if apagadas > 0 then
        return false, apagadas .. " luz(ces) legible(s) cerca y todas APAGADAS" ..
            ( ciegas > 0 and ( " ( y " .. ciegas .. " ilegible(s), que no cambian el veredicto )" ) or "" ),
            ciegas, LEIDO_OSCURO

    end

    if ciegas > 0 then
        return false, "NO SE PUEDE LEER: " .. ciegas .. " luz(ces) del mapa sin getter a " ..
            math.Round( radio ) .. " u y ninguna legible", ciegas, LEIDO_CIEGO

    end

    -- ⚠ CERO LUCES CERCA TAMPOCO ES UNA MEDICION DE OSCURIDAD, y este renglon es
    -- el que mas se paga. Un mapa con la iluminacion HORNEADA en el lightmap no
    -- tiene ni una entidad de luz y esta perfectamente iluminado: §19.9.2 lo
    -- acepto por escrito como el costo de la opcion B. Contarlo como `oscuro`
    -- seria acreditar una medicion que nadie hizo.
    return false, "no hay ninguna luz que preguntar a " .. math.Round( radio ) ..
        " u ( puede ser un mapa de iluminacion horneada: la opcion B no lo ve )", 0, LEIDO_CIEGO

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
            --
            -- ⚠⚠⚠ Y LA LECTURA TIENE **TRES** ESTADOS DESDE B2, ASI QUE EL
            -- DELTA VA A DOS RENGLONES DISTINTOS. Con dos, "medi que esta a
            -- oscuras" y "no pude leer nada" se anotaban contra el mismo
            -- renglon y ninguna corrida podia separarlos -- que es la mitad del
            -- drenaje que el punto ciego de las 25 luces sin getter se estaba
            -- llevando con cara de medicion. El multiplicador NACE IGUAL en los
            -- dos ( 1.5 ) para que B2 no mueva el gameplay por abajo; lo que
            -- cambia hoy es que se pueden aislar.
            local mul, causaMod = 1, nil

            if modulable then
                local _, _, _, lectura = PHANTASMAGORIA.IsPlayerLit( ply )

                if lectura == LEIDO_ILUMINADO then
                    mul, causaMod = cvLitMul:GetFloat(), "oscuridad"

                elseif lectura == LEIDO_OSCURO then
                    mul, causaMod = cvDarkMul:GetFloat(), "oscuridad"

                else
                    mul, causaMod = cvCiegaMul:GetFloat(), "oscuridad_ciega"

                end
            end

            aplicar( ply, base, causaId, dt, techo )

            if mul ~= 1 then
                aplicar( ply, base * mul - base, causaMod, dt, techo )

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
    -- ⚠⚠ Y CON CERO TICKS NO HAY NADA QUE MEDIR, ASI QUE NO SE IMPRIME UN NUMERO.
    -- La r3 leyo el reporte justo despues de un `reset` y salio
    -- `REAL 0.000 s ( medido )`: un periodo de tick de cero segundos es
    -- IMPOSIBLE, y estaba impreso al lado de la palabra `medido` y de una fila
    -- verde. Un instrumento que imprime un imposible como si fuera una medicion
    -- gasta la credibilidad de todo lo que imprime al lado -- y ademas manda a
    -- buscar un timer muerto donde lo unico que pasa es que todavia no latio.
    -- La division por cero no era el defecto: el defecto era CONTESTAR.
    local real = ticksReales > 0 and ( segsReales / ticksReales ) or nil

    say( "  tick        pedido " .. string.format( "%.2f", cvTick:GetFloat() ) .. " s  ·  REAL " ..
        ( real and ( string.format( "%.3f", real ) .. " s ( medido )" )
              or "-- sin medir: 0 ticks desde el ultimo reset --" ) ..
        "   ( " .. ticksTotal ..
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

        -- ⚠⚠ EL RENGLON DECIA "a oscuras" SOBRE DOS ESTADOS DISTINTOS, Y UNO DE
        -- LOS DOS NO ERA UNA MEDICION. Con el booleano, un cuarto con las
        -- lamparas apagadas y un mapa entero sin una sola luz legible escribian
        -- la misma palabra -- y el x1,5 salia igual en los dos. Ahora el rotulo
        -- ES la lectura, y el multiplicador que se aplico va en la misma linea:
        -- un reporte que dice el estado pero no lo que ese estado COBRA obliga a
        -- ir a buscar la convar para saber si el numero de arriba tiene sentido.
        local _, motivoLuz, ciegas, lectura = PHANTASMAGORIA.IsPlayerLit( p )

        local rotulo = ( lectura == LEIDO_ILUMINADO and "ILUMINADO   ( medido )" )
            or ( lectura == LEIDO_OSCURO and "a oscuras   ( medido )" )
            or "SIN LECTURA ⚠ no se pudo medir"

        local mulLuz = ( lectura == LEIDO_ILUMINADO and cvLitMul:GetFloat() )
            or ( lectura == LEIDO_OSCURO and cvDarkMul:GetFloat() )
            or cvCiegaMul:GetFloat()

        say( "    luz         " .. rotulo .. "   x" .. string.format( "%.2f", mulLuz ) ..
            ( cvDark:GetBool() and "" or "  ( SUPRIMIDO: phantasmagoria_sanity_dark en 0 )" ) ..
            "   ( " .. motivoLuz .. " )" )

        if ciegas > 0 then
            -- ⚠ LOS NOMBRES SALEN DE LA TABLA Y NO DE UNA FRASE ESCRITA ACA. Un
            -- "solo gmod_light y gmod_lamp" pegado a mano seria cierto hoy y
            -- envejeceria en silencio el dia que una clase gane getter -- y el
            -- renglon que existe para medir el punto ciego pasaria a describir
            -- un universo que ya no es el suyo.
            local legibles, total = {}, 0

            for _, fam in ipairs( PHANTASMAGORIA.LightClasses or {} ) do
                total = total + 1
                if fam.leer then legibles[ #legibles + 1 ] = fam.clase end

            end

            say( "                ⚠ punto ciego: " .. ciegas .. " luz(ces) del mapa sin getter a " ..
                math.Round( cvLitRadio:GetFloat() ) .. " u. De las " .. total ..
                " clases declaradas, las que se pueden preguntar son: " ..
                ( #legibles > 0 and table.concat( legibles, ", " ) or "NINGUNA ⚠" ) .. "." )

        end

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

-- ⭐ VOLVER A FABRICA, Y DECIR QUE ESTABA MOVIDO.
--
-- Las 24 son FCVAR_ARCHIVE. Restituir a mano es una precondicion que hay que
-- ACORDARSE de cumplir, y eso no sobrevive a las 6 de la mañana: la r1 perdio
-- dos perillas de encendido y la r3 llego con `regendelay` en 30 contra los 45
-- del diseño, movida en un A/B de la ronda anterior.
--
-- ⚠⚠ LO QUE HACE UTIL A ESTE COMANDO NO ES QUE RESTITUYA: ES QUE INFORME. Un
-- restaurador mudo deja al que prueba sin saber si la corrida anterior midio
-- con las perillas de esta -- y esa duda no se puede resolver despues, porque
-- el valor viejo ya se perdio. Sin `--decir` restituye e imprime lo que movio;
-- con `--decir` SOLO informa y no toca nada, para poder leer el estado antes de
-- destruirlo.
addCmd( "phantasmagoria_cordura_fabrica", function( ply, _, args )
    local say   = hacerSay( ply )
    local soloDecir = false

    for _, a in ipairs( args or {} ) do
        if string.lower( a ) == "--decir" then soloDecir = true end

    end

    local todas   = perillasTodas()
    local movidas = 0

    for _, reg in ipairs( todas ) do
        local cv       = reg.cv
        local hay, def = cv:GetString(), cv:GetDefault()

        -- La comparacion va por NUMERO cuando los dos lo son: "0.20" y "0.2"
        -- son la misma perilla y compararlas como texto inventaria una movida
        -- que no existe -- un falso positivo en el instrumento que existe para
        -- que el que prueba confie en el estado.
        local a, b = tonumber( hay ), tonumber( def )
        local iguales = ( a and b ) and ( a == b ) or ( hay == def )

        if not iguales then
            movidas = movidas + 1
            -- ⚠ SE NOMBRA AL DUEÑO. Con las perillas repartidas en dos archivos,
            -- "movida" sin dueño manda a buscarla en el que uno tiene abierto.
            say( "  " .. ( soloDecir and "MOVIDA " or "restituida " ) .. cv:GetName() ..
                "   " .. hay .. "  ->  " .. def .. "   [ " .. tostring( reg.dueno ) .. " ]" )

            if not soloDecir then cv:SetString( def ) end

        end
    end

    if movidas == 0 then
        say( "[Phantasmagoria] las " .. #todas .. " perillas de la cordura estan EN FABRICA. Nada que restituir." )

    else
        say( "[Phantasmagoria] " .. movidas .. " de " .. #todas .. " perillas " ..
            ( soloDecir and "estan movidas ( no se toco nada: sacale el --decir para restituirlas )."
                        or "estaban movidas y se restituyeron." ) )
        say( "                 ⚠ Si esto sale DESPUES de una corrida, esa corrida midio con estos valores." )

    end

end, "Vuelve TODAS las perillas de la cordura a su valor de fabrica y DICE cuales estaban movidas. El total sale del registro PHANTASMAGORIA.PerillasCordura -- que es compartido, asi que las que B2 agrego en server_events.lua tambien entran -- y no de un numero escrito al lado. Con --decir solo informa y no toca nada. Todas son FCVAR_ARCHIVE: una que quedo de un A/B viejo invalida una planilla entera sin decir nada." )

-- ANDAMIO de drenaje: la fila 04 necesita poder disparar la forma PLANA sin
-- esperar a que B2 exista, y la 05 necesita poder mover un renglon a la vez.
--
-- ⚠⚠⚠ ESTE COMANDO SALIO ROJO EN LA r2 Y LA CAUSA NO ESTABA ACA ADENTRO: los
-- ids de las ocho causas de evento llevaban dos puntos y la consola de Source
-- los parte. Ya estan reescritos con guion bajo, pero el comando queda con TRES
-- defensas mas, porque el arreglo de arriba no protege al que TIPEA:
--
--   ( 1 ) rearma la causa juntando todos los argumentos desde el segundo. Si el
--         tokenizador vuelve a partir algo, las piezas se pegan de nuevo.
--   ( 2 ) NORMALIZA los caracteres que rompen -- dos puntos incluidos -- a guion
--         bajo, asi que `evento:sound`, que es lo que dice la planilla vieja y
--         lo que la mano ya aprendio, sigue llegando al renglon correcto.
--   ( 3 ) ⭐ SI LA CAUSA NO ESTA DECLARADA, LO DICE EN EL ACTO. El reporte ya la
--         marcaba `⚠ NO DECLARADA`, pero eso se lee dos pantallas despues y
--         despues de haber gastado la corrida. Un andamio que acepta cualquier
--         string en silencio le regala al tester un rojo que parece del
--         mecanismo. Se aplica igual -- no se rechaza -- porque el renglon NO
--         DECLARADA es una funcion del instrumento y B2 tiene que poder
--         estrenarla a proposito.
local CAUSA_DEFAULT = "evento_sound"

local function normalizarCausa( args )
    if not args or not args[ 2 ] then return CAUSA_DEFAULT, false end

    -- Sin separador: el tokenizador ya se quedo con los espacios reales, asi que
    -- lo unico que puede haber partido son los caracteres del break set, y esos
    -- vuelven como tokens propios. `evento` + `:` + `sound` = `evento:sound`.
    local crudo = table.concat( args, "", 2 )

    local limpio, rotos = crudo, 0

    for _, ch in ipairs( ROMPEN_CONSOLA ) do
        -- El caracter se escapa antes de usarlo como patron: `(` y `)` crudos
        -- abren una captura y el gsub no reemplazaria nada -- silenciosamente,
        -- que es como este bloque se gano el rojo la primera vez.
        local patron = string.gsub( ch, "(%W)", "%%%1" )
        local n

        limpio, n = string.gsub( limpio, patron, "_" )
        rotos = rotos + n

    end

    -- El aviso se decide ANTES de bajar a minusculas: escribir `Evento_Sound` no
    -- es que la consola te haya partido nada, y decirselo al tester manda a
    -- buscar un defecto que no esta.
    return string.lower( limpio ), rotos > 0

end

addCmd( "phantasmagoria_cordura_drenar", function( ply, _, args )
    local say   = hacerSay( ply )
    local n     = tonumber( args and args[ 1 ] ) or 10
    local causa, seNormalizo = normalizarCausa( args )

    if not IsValid( ply ) then
        say( "[Phantasmagoria] este andamio necesita un jugador." )
        return

    end

    if seNormalizo then
        say( "[Phantasmagoria] ( la consola te partio la causa; se rearmo y se normalizo a '" .. causa .. "' )" )

    end

    if not CAUSA_POR_ID[ causa ] then
        say( "" )
        say( "[Phantasmagoria] ⚠⚠ '" .. causa .. "' NO ES UNA CAUSA DECLARADA." )
        say( "                 Se aplica igual y va a salir como '⚠ NO DECLARADA' en el desglose --" )
        say( "                 lo cual ENSUCIA la fila 10, que pide que no haya ninguna. Las declaradas:" )

        local linea = "                   "

        for i, c in ipairs( CAUSAS ) do
            linea = linea .. c.id .. ( i < #CAUSAS and "  " or "" )

            -- La consola de Source trunca la linea en 255 y no avisa, asi que
            -- una lista de 19 ids no se manda de una: se corta a mano.
            if #linea > 150 then
                say( linea )
                linea = "                   "

            end
        end

        if #string.Trim( linea ) > 0 then say( linea ) end
        say( "" )

    end

    local real = PHANTASMAGORIA.DrainSanity( ply, n, causa )

    say( "[Phantasmagoria] drenaje plano de " .. n .. " % contra '" .. causa .. "'" ..
        ( CAUSA_POR_ID[ causa ] and " ( " .. CAUSA_POR_ID[ causa ].label .. " )" or " ( ⚠ NO DECLARADA )" ) ..
        ": entraron " .. string.format( "%.2f", real ) .. " %   ->   " ..
        string.format( "%.2f", PHANTASMAGORIA.GetSanity( ply ) ) .. " %" )

end, "ANDAMIO. Dispara la forma PLANA de drenaje contra la causa que se le diga ( default evento_sound ), para poder medir la puerta antes de que B2 tenga llamadores. Los dos puntos se normalizan a guion bajo: la consola de Source los parte." )

MsgC( Color( 190, 120, 255 ), "[Phantasmagoria] ", color_white,
    "cordura B1 lista: " .. #FUENTES .. " fuentes continuas, " .. #CAUSAS ..
    " causas declaradas. Reporte: phantasmagoria_cordura\n" )
