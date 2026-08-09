--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom / cliente

    EL INSTRUMENTO: un marcador que atraviesa paredes sobre cada fantasma.
    Sin esto, un modelo negro sin ojos en un mapa oscuro es indistinguible de
    "no spawneo nada".

    ⚠ Y DESDE LA r22 ESTE ARCHIVO TAMBIEN ES LA MECANICA, no solo el
    instrumento: la ausencia ( Diseno 20 ① ) la hace el ENT:Draw de aca abajo.
    Hasta la r21 el encabezado decia *"NO se toca el dibujado de la entidad"* y
    eso ya no es cierto -- porque esconder al fantasma desde el SERVIDOR con
    SetNoDraw se cayo en juego: la entidad se dejaba de transmitir y el cliente
    se quedaba con una copia congelada. La salida es la de HIM
    ( PHANTOM_Referencia.md §6 ), y el detalle esta en el bloque del Draw.

    El marcador sigue siendo un hook aparte que dibuja encima y no le puede
    romper el render a nadie.

    La base ademas trae visualizadores propios que NO hay que reescribir:
      term_debugpath      dibuja el path. PIDE sv_cheats 1 ( base/init.lua:92 )
      term_debugtasks     imprime tareas, y vuelca el historial si le haces +use al bot
      term_debughearing   lo que el bot oye
---------------------------------------------------------------------------]]

-- ⚠ TRES VALORES DESDE DISENO 20, Y EL MOTIVO ES QUE ESTE MARCADOR PASO A
-- CORROMPER LO QUE MIDE. Dibuja con IgnoreZ, o sea a traves de las paredes:
-- hasta ayer era lo unico que hacia visible a un modelo oscuro en un mapa
-- oscuro, y desde que existe la ausencia ( server_cloak.lua ) es lo unico que
-- te dice donde esta un fantasma que el diseno quiere invisible. Una corrida
-- hecha con esto en 1 no mide la invisibilidad: la tapa.
--
--   0  nada
--   1  SIEMPRE -- el wallhack de siempre. Sigue siendo el default, porque es el
--      instrumento de todo lo demas.
--   2  HONESTO -- no dibuja al fantasma que no se dibuja. Es el modo obligatorio
--      de las filas de invisibilidad.
--
-- ⚠ Y EL MODO 2 NECESITA UNA SEGUNDA MITAD O NO SE PUEDE JUZGAR: "no lo veo" y
-- "no lo dibuje" se ven exactamente igual. Por eso en 2 hay una linea de HUD
-- que sigue contando los que NO dibujo. *El instrumento tiene que seguir
-- hablando justo cuando deja de dibujar.*
--
-- ⚠ LA r20 CORRIO Y ESTE ARCHIVO SE LLEVO LAS DOS FALLAS -- ninguna del
-- fantasma, las dos del instrumento. `GetNoDraw()` en el CLIENTE devolvio
-- `false` sobre un fantasma que en la pantalla no estaba: con eso, el modo 2
-- nunca salteaba a nadie y la linea de HUD conto `0 invisibles` con uno
-- delante. Desde la r21 el que decide es el NW var -- la unica de las cuatro
-- lecturas que se pudo acreditar -- y las otras tres se imprimen al lado
-- ( renderState ). *Diseno 20.4 daba por buena una lectura: el juego la
-- refuto, y la respuesta no es creerle a otra sino imprimir las cuatro.*
local cvMarker = CreateClientConVar( "phantasmagoria_debug_ghost", "1", true, false,
    "Marcador de desarrollo sobre los fantasmas. 0 = nada · 1 = siempre, atravesando paredes ( tapa la invisibilidad de Diseno 20 ) · 2 = HONESTO: no dibuja al fantasma invisible, y cuenta cuantos oculto en una linea de HUD.", 0, 2 )

---------------------------------------------------------------------------
-- ⚠⚠ LA AUSENCIA SE DIBUJA (O NO SE DIBUJA) ACA -- LA TECNICA DE HIM
---------------------------------------------------------------------------
-- Diseno 20 ①, tercera vuelta. La r20 y la r21 cerraron el diagnostico:
-- **`SetNoDraw` en el servidor no sirve para esto**. La entidad se dejaba de
-- transmitir, el cliente se quedaba con una copia congelada -- posicion vieja y
-- la bandera sin llegar, por eso `GetNoDraw()` daba `false` -- y el marcador
-- dibujaba donde el fantasma ESTABA. Tres sintomas que se veian como uno solo:
-- "no se ve el fantasma" ( bien ), "no se ve el marcador" ( mal ) y "el physgun
-- lo agarra en la posicion original" ( el mismo dato, desde otro testigo ).
--
-- LA SALIDA ES LA DE HIM, y estaba escrita en PHANTOM_Referencia.md §6 desde
-- antes de empezar el bloque: *"la invisibilidad de HIM no es un material:
-- SetHidden hace SetNotSolid + DrawShadow(false) + FL_NOTARGET, y el Draw del
-- cliente literalmente no dibuja"*. Medido en su fuente
-- ( terminator_nextbot_homeless/client.lua:54 ):
--
--     if not plsDraw and not self:IsSolid() then return end
--
-- **La entidad se sigue transmitiendo entera.** El cliente conserva la
-- posicion, el marcador puede seguirla, y lo unico que cambia es que el modelo
-- no se dibuja. Es exactamente lo que `SetNoDraw` NO podia dar.
--
-- ⚠ PERO LA SEÑAL DE HIM NO SE PORTA, Y ESA ES LA MITAD QUE HAY QUE MIRAR. HIM
-- pregunta `self:IsSolid()`, o sea que **su invisibilidad y su no-solidez son la
-- misma cosa** -- el mismo acoplamiento por el que Diseno 20.1 rechazo el cloak
-- de la base, ahora del otro lado. Nuestro fantasma ausente **sigue siendo
-- solido a proposito** ( la solidez tiene un dueno unico y es server_doors.lua ),
-- asi que con la señal de HIM esto no ocultaria a nadie NUNCA.
--
-- La señal nuestra es el NW var, que es **la unica lectura del cliente que la
-- r20 vio llegar bien**. *Se porta la tecnica, no el cableado: dos addons pueden
-- necesitar el mismo dibujo y distintas razones para dibujarlo.*
--
-- ⚠ Y LO QUE ESTO CUESTA, ESCRITO ANTES DE CORRERLO: con `SetNoDraw` la entidad
-- desaparecia del cliente y con ella **todo** lo que otros addons dibujen encima.
-- Ahora la entidad esta ahi, asi que un HUD de terceros que dibuje barras de
-- vida sobre lo que apuntas **puede delatar al fantasma invisible**. No es
-- hipotetico: en las capturas de la r20 hay una barra `Phantasmagoria Ghost
-- 900|900` flotando sobre el bot. `FL_NOTARGET` no la tapa -- esa bandera es
-- para los NPC. Tiene su fila en la planilla, y si sale roja la salida no es
-- volver a SetNoDraw: es mirar de donde sale esa barra.

-- Cuantas veces el Draw NO dibujo. Es LA acreditacion de esta mecanica y no un
-- adorno: solo lo puede tocar la rama que se saltea el dibujado, o sea que un
-- numero que sube prueba que **el codigo del render corrio y decidio no
-- dibujar**. Es lo que reemplaza a `GetNoDraw()` como "estado real", y es mejor
-- que aquello por el motivo que costo dos rondas: aquella era una bandera que
-- alguien mas podia escribir y que podia no llegar; esto es el camino del render
-- contandose a si mismo.
local saltosDeDraw = 0

-- El chunk de client.lua es OTRO chunk que el de shared.lua, asi que el
-- `BaseClass` que aquel declaro no se ve desde aca. Se vuelve a declarar por lo
-- mismo que se duplica la guarda de AddCommand mas abajo.
DEFINE_BASECLASS( ENT.Base )

function ENT:Draw()
    -- Se lee el NW var y NO `GetNoDraw()`, que es el cambio entero del bloque.
    if self:GetNWBool( "phantasmagoria_invisible", false ) then
        saltosDeDraw = saltosDeDraw + 1
        return

    end

    -- Se encadena en vez de llamar a DrawModel directo. Hoy el Draw de la base
    -- ES un DrawModel ( terminator_nextbot_base/cl_init.lua:25 ), asi que las
    -- dos ramas hacen lo mismo -- pero el dia que la base dibuje algo mas, la
    -- version que llama a DrawModel se lo comeria en silencio.
    if BaseClass and isfunction( BaseClass.Draw ) then
        BaseClass.Draw( self )

    else
        self:DrawModel()

    end
end

-- Diseno 1: 1 u = 1,905 cm, o sea 1 m ~ 52,5 u.
local UNITS_PER_METER = 52.5

local colGhost = Color( 190, 120, 255 )
local colText  = Color( 255, 255, 255 )

-- El estado del interruptor fantasma/cazador, en el color de la caja y en una
-- palabra. Es lo que hace que la corrida se pueda leer SIN consola: "no me
-- ataca" y "no puede atacarme" se ven igual desde adentro del juego.
-- Viene por NW var ( server.lua, phantom_SetHunting ) y NO por SetupDataTables:
-- la base networkea con slots hardcodeados y el Bool 0 ya es Crouching
-- ( Referencia 4.3, trampa 3 ).
local colHunt = Color( 255, 70, 70 )

-- EL TIPO ( Diseno 19, tajada A ), y esta es la unica lectura que prueba el
-- networkeo: el servidor escribe la key con SetNWString y el cliente la resuelve
-- contra su propia copia de PHANTASMAGORIA.Types.
--
-- LOS TRES ESTADOS SON DISTINTOS Y HAY QUE PODER SEPARARLOS, porque son tres
-- fallas distintas y sin esto las tres se ven como "no dice nada":
--
--   ""              el server no le asigno tipo    ( o typeassign 0 )
--   key sin ficha   la key VIAJO y el cliente no tiene los 30 -- o sea que
--                   lua/autorun/phantasmagoria_data.lua no corrio EN CLIENTE,
--                   que es justo la mitad que nadie miro nunca
--   nombre          la cadena entera funciona
--
-- ⚠ Y esto es un INSTRUMENTO, no la UI del juego. En Phasmophobia el tipo es
-- precisamente lo que hay que adivinar ( Diseno 12.1: "el tipo se sortea y no se
-- anuncia" ), asi que vive detras de phantasmagoria_debug_ghost como todo lo
-- demas de este marcador, y no se muda al HUD.
local function typeLabel( ghost )
    local key = ghost:GetNWString( "phantasmagoria_type", "" )
    if key == "" then return "sin tipo" end

    local T = PHANTASMAGORIA and PHANTASMAGORIA.Types
    local t = istable( T ) and T[ key ] or nil

    -- ASCII a proposito: esto se dibuja con DermaLarge, y un glifo que la fuente
    -- no tenga sale como un cuadrito -- que en la fila del networkeo se leeria
    -- como "el marcador esta roto" en vez de "el cliente no tiene los tipos".
    if not t then return key .. " ( !! sin ficha en el cliente )" end

    return t.name

end

---------------------------------------------------------------------------
-- ⚠ EL MUESTREADOR DE POSICION -- UN VALOR CONGELADO NO SE VE EN UNA LECTURA
---------------------------------------------------------------------------
-- Entro en la r21 y es la mitad que decide el bloqueante de la r20. Ahi el
-- cliente dijo `por clase 1 · por campo 1` -- o sea que TIENE la entidad -- y
-- sin embargo el marcador no aparecia por ningun lado, con `GetNoDraw()`
-- devolviendo false sobre un fantasma que en la pantalla NO SE VE. Tres hechos
-- que no cierran, y una pista suelta del autor que los explica a los tres:
-- *"cuando lo tomo el physgun va a su posicion original, aunque lo tenga en
-- frente"*.
--
-- La hipotesis que hay que MEDIR, no dar por buena: EF_NODRAW en el servidor
-- manda la entidad a FL_EDICT_DONTSEND ( CBaseEntity::UpdateTransmitState ), o
-- sea que el cliente deja de recibirla. La copia sigue en la lista -- por eso
-- los dos conteos dan 1 -- pero queda CONGELADA con los ultimos valores que
-- alcanzo a recibir: posicion vieja, y `GetNoDraw` en false porque la bandera
-- se puso en el mismo tick en que dejo de transmitirse. Si es asi, el marcador
-- si dibuja: dibuja donde el fantasma ESTABA, y eso desde la pantalla se lee
-- igual que "no dibuja nada".
--
-- ⚠ Y NO SE PUEDE DECIDIR TIPEANDO UN COMANDO: una posicion vieja y una
-- posicion actual son los dos un Vector plausible. Lo que las separa es que una
-- DEJA DE CAMBIAR, y eso es una medicion en el tiempo. Mismo patron que
-- phantasmagoria_ghost_look.
--
-- ⚠ LA TRAMPA DE ESTE MUESTREADOR, ESCRITA ANTES DE CORRERLO: un fantasma
-- QUIETO tambien tiene la posicion congelada. El instrumento no puede
-- distinguirlos solo -- por eso la fila trae su precondicion ( el fantasma
-- CAMINANDO, con `ghost_where` diciendo `marcha` ) y su control ( con
-- `absence 0`, visible y caminando, esto tiene que dar CERCA DE 0 ). *Un
-- numero que sube igual cuando el mecanismo anda y cuando no, no mide.*
local POS_EPSILON = 0.5

hook.Add( "Think", "phantasmagoria_ghost_possampler", function()
    for _, ghost in ipairs( ents.FindByClass( "terminator_nextbot_phantom" ) ) do
        if not IsValid( ghost ) then continue end

        local pos = ghost:GetPos()
        local ant = ghost.phantom_clPos

        if not ant or ant:DistToSqr( pos ) > ( POS_EPSILON * POS_EPSILON ) then
            ghost.phantom_clPos = pos
            ghost.phantom_clPosAt = CurTime()

            -- El primer muestreo cuenta como movimiento y esta bien que asi
            -- sea: `movimientos 1` con muchos segundos encima dice "llego una
            -- sola vez y despues nada", que es exactamente el sintoma.
            ghost.phantom_clMoves = ( ghost.phantom_clMoves or 0 ) + 1

        end
    end
end )

-- Devuelve: segundos desde el ultimo cambio de posicion ( nil si nunca se
-- muestreo ), y el texto.
local function posFreshness( ghost )
    local at = ghost.phantom_clPosAt
    if not at then return nil, "( sin muestrear todavia )" end

    local edad = CurTime() - at

    return edad, string.format( "%.1f s desde el ultimo cambio · %d movimiento(s) vistos", edad, ghost.phantom_clMoves or 0 )

end

-- Cuantos segundos sin moverse ya son sospechosos. No es un criterio de la
-- fila -- el criterio lo fija la planilla comparando contra el servidor -- es
-- el umbral con que el marcador decide GRITAR que puede estar mintiendo.
local POS_CONGELADA = 2

---------------------------------------------------------------------------
-- EL ESTADO DE RENDER, LEIDO DEL DESTINO Y NO DE NUESTRA CREENCIA
---------------------------------------------------------------------------
-- Diseno 20.4 pedia UNA lectura ( `GetNoDraw()` ) y la daba por buena: *"es
-- networkeado, o sea que el cliente puede leer GetNoDraw() y decir el estado
-- REAL"*. La r20 REFUTO esa frase en juego -- `render: se dibuja · el server
-- dice INVISIBLE` sobre un fantasma que no se veia --, asi que aca ya no hay
-- una lectura sino CUATRO, y ninguna manda sobre las otras:
--
--   GetNoDraw()                     lo que este taller venia creyendo que era
--                                   la verdad del engine
--   IsEffectActive( EF_NODRAW )     la MISMA bandera leida por el otro lado.
--                                   Si las dos difieren, una de las dos no
--                                   sirve para decidir y hay que saber cual
--   IsDormant()                     si el cliente dejo de RECIBIR la entidad.
--                                   Es la hipotesis de arriba, contestada por
--                                   el engine en una palabra
--   el NW var                       la creencia del servidor, que viaja por
--                                   OTRO sistema de red
--
-- *Preguntarle al servidor que cree haber escrito acredita el pedido.* Pero la
-- r20 mostro la vuelta de tuerca: **preguntarle al cliente tampoco acredita el
-- efecto si se le pregunta con el campo equivocado**. Dos lecturas de la misma
-- bandera al lado son mas baratas que otra ronda.
--
-- Devuelve: oculto ( bool, el que USA el marcador ), texto.
local function renderState( ghost )
    local nodraw  = ghost:GetNoDraw()
    local efecto  = ghost:IsEffectActive( EF_NODRAW )
    local dormida = ghost:IsDormant()
    local mat     = ghost:GetMaterial()

    -- ⚠ EL QUE DECIDE ES EL NW VAR, Y ES UN CAMBIO DE LA r21 CON MOTIVO
    -- MEDIDO. Hasta la r20 decidia `GetNoDraw()`, con este argumento escrito al
    -- lado: *"lo que decide si el marcador delata es si el fantasma SE DIBUJA, y
    -- eso lo contesta la bandera de la entidad"*. El argumento sigue siendo
    -- correcto y la lectura no: en la r20 esa bandera dijo `false` sobre un
    -- fantasma que no se dibujaba, asi que el modo honesto NUNCA se activo y la
    -- linea de HUD conto `0 invisibles` con uno delante ( fila 05, roja ).
    --
    -- El NW var es la unica de las cuatro lecturas que la r20 vio llegar bien.
    -- No es "la verdad del render": es la creencia del servidor, y se elige
    -- porque **es la que se puede acreditar**. Las otras tres se siguen
    -- imprimiendo, que es como una divergencia se vuelve un hallazgo en vez de
    -- una decision en silencio.
    local dice = ghost:GetNWBool( "phantasmagoria_invisible", false )

    local txt = "NW " .. ( dice and "INVISIBLE" or "visible" ) ..
        "  ·  GetNoDraw " .. ( nodraw and "true" or "false" ) ..
        "  ·  IsEffectActive( EF_NODRAW ) " .. ( efecto and "true" or "false" ) ..
        "  ·  IsDormant " .. ( dormida and "SI" or "no" ) ..
        ( ( mat and mat ~= "" ) and ( "  ·  material '" .. mat .. "'" ) or "" )

    -- ⚠ LAS TRES DE LA DERECHA CAMBIARON DE PAPEL Y NINGUNA SE BORRA. Desde que
    -- la ausencia la hace el Draw ( arriba ), **nosotros ya no escribimos
    -- EF_NODRAW nunca**: lo esperado es `GetNoDraw false · EF false · IsDormant
    -- no` SIEMPRE, invisible o no. O sea que dejaron de ser el mecanismo y
    -- pasaron a ser el CONTROL: si alguna se enciende, hay un escritor ajeno o
    -- la entidad se dejo de transmitir, y en los dos casos vuelve el defecto que
    -- costo la r20 -- el marcador dibujando en el lugar equivocado.
    --
    -- *Una lectura que se cae como mecanismo no se borra: se queda como
    -- alarma, porque ahora se sabe exactamente qué significa que se encienda.*
    if nodraw or efecto then
        txt = txt .. "\n                           !! ALGUIEN PUSO EF_NODRAW SOBRE EL FANTASMA Y NO FUIMOS NOSOTROS: " ..
            "la ausencia ya no usa SetNoDraw. Con esa bandera puesta el cliente deja de recibir la entidad " ..
            "y el marcador vuelve a dibujar la posicion vieja."

    elseif dormida then
        txt = txt .. "\n                           !! IsDormant SI sin EF_NODRAW: el cliente dejo de recibir la entidad " ..
            "por otro motivo. La posicion de abajo puede estar vieja."

    end

    return dice, txt

end

-- El haz sigue siendo largo a proposito: es lo que te dice desde otra
-- habitacion en que direccion esta, y atraviesa el techo porque se dibuja con
-- IgnoreZ.
local BEAM_HEIGHT = 220

-- La etiqueta va PEGADA A LA CABEZA, no arriba del haz. Primera corrida
-- (2026-08-05): en un mapa de casa se veian la caja y el haz y NO el texto.
-- Estaba a 250 u sobre la cabeza, o sea a ~322 del piso, por encima del techo y
-- fuera del campo de vision de un jugador parado al lado. El instrumento estaba
-- pensado para un mapa abierto y se probo adentro de una casa.
local LABEL_HEIGHT = 14

-- Escala del texto por unidad de distancia. Calibrada contra la corrida 2: a
-- 4 m ( 4 * 52,5 u ) la escala fija 0.35 se leia bien, asi que esa es la razon.
local LABEL_SCALE_PER_UNIT = 0.35 / ( 4 * UNITS_PER_METER )

---------------------------------------------------------------------------
-- EL LADO CLIENTE, EN TEXTO -- y existe porque una planilla mia pedia algo
-- imposible
---------------------------------------------------------------------------
-- La fila del networkeo se marco verde TRES VECES sin traer un dato del
-- cliente, y las tres veces se pego la salida del SERVIDOR. No fue descuido del
-- que corria: *la fila pedia pegar lo que dice un marcador 3D, y un marcador no
-- produce texto.* El unico registro posible era la palabra del operador o una
-- captura.
--
-- Y el realm cliente es justo donde este taller ya tuvo algo apagado dos
-- arranques sin un solo error de Lua. Un punto ciego historico medido con el
-- instrumento que no deja rastro es la peor combinacion posible.
--
-- ⚠ LLAMA A typeLabel, LA MISMA FUNCION QUE DIBUJA, y eso no es ahorro: si
-- imprimiera su propia version del texto seria OTRA medicion, y el dia que las
-- dos diverjan el comando diria que todo esta bien sobre un marcador que dice
-- otra cosa. Este addon ya tuvo dos impresiones del mismo dato separandose.
--
-- El wrapper de comandos vive en server.lua y aca no existe -- include() corre
-- otro chunk y ese archivo es del otro realm --, asi que se declara la misma
-- guarda. Se duplica a proposito en vez de mover el original: mover codigo de
-- cero comportamiento en la misma ronda que estrena un instrumento convierte un
-- rojo en un misterio. Cuando exista un archivo compartido, se unifica.
-- A la defensiva y por el mismo motivo que server.lua lo hace: el orden entre
-- lua/autorun/ y lua/entities/ no esta garantizado, y si este archivo corre
-- primero la mesa todavia no existe.
PHANTASMAGORIA = PHANTASMAGORIA or {}

if not PHANTASMAGORIA.AddCommand then
    function PHANTASMAGORIA.AddCommand( name, fn, help )
        if ConVarExists( name ) then
            ErrorNoHalt( "[Phantasmagoria] COLISION DE NOMBRE: '" .. name .. "' ya existe como CONVAR, " ..
                "asi que el comando homonimo queda inalcanzable ( la consola resuelve convars primero ). " ..
                "Renombrar uno de los dos.\n" )
            return false

        end

        concommand.Add( name, fn, nil, help )
        return true

    end
end

PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_cl", function()
    local function say( line )
        MsgC( Color( 190, 120, 255 ), "[cl] ", color_white, line, "\n" )

    end

    -- La primera linea dice con que esta midiendo. Aca eso ES la mitad del
    -- veredicto: si el cliente no tiene los 30 tipos, la key va a llegar igual y
    -- el marcador va a mostrar la key cruda -- que es un sintoma con OTRA causa.
    local T = PHANTASMAGORIA and PHANTASMAGORIA.Types
    local n = 0

    if istable( T ) then
        for _ in pairs( T ) do n = n + 1 end

    end

    say( "LO QUE VE EL CLIENTE, no el servidor.   tipos en la tabla LOCAL: " ..
        ( istable( T ) and ( n .. "" ) or "NO EXISTE ( lua/autorun/phantasmagoria_data.lua no corrio en cliente )" ) )

    -- ⚠ EL MODO DEL MARCADOR VA EN LA PRIMERA PANTALLA, y no es formalidad: el
    -- servidor no puede leerlo, asi que esta es la unica linea de toda la
    -- corrida que dice si la invisibilidad se estaba midiendo o se estaba
    -- tapando. Una fila de Diseno 20 corrida en modo 1 no vale, y sin esto no
    -- habria forma de saberlo despues.
    local modoTxt = cvMarker:GetInt()

    say( "phantasmagoria_debug_ghost " .. modoTxt .. "   ( " ..
        ( modoTxt == 0 and "apagado"
        or modoTxt == 1 and "SIEMPRE -- atraviesa paredes y DELATA al fantasma invisible: las filas de Diseno 20 no se pueden medir asi"
        or "HONESTO -- no dibuja al fantasma invisible" ) .. " )" )

    -- ⚠ LAS DOS BUSQUEDAS, Y NO SON LA MISMA. Reportado en juego el 2026-08-08:
    -- con `absence 1` el marcador NO se dibuja NI EN MODO 1, que es el modo que
    -- delata a proposito. Hay dos causas posibles y se ven exactamente igual
    -- desde la pantalla:
    --
    --   ( a ) el cliente NO TIENE la entidad -- o sea que EF_NODRAW se la lleva
    --         puesta del lado cliente, y entonces NINGUN marcador clientside
    --         puede dibujar un fantasma invisible: cae Diseno 20.4 entero y hay
    --         que networkear la posicion aparte.
    --   ( b ) el cliente la tiene y el marcador la saltea -- defecto nuestro,
    --         en el hook o en la busqueda.
    --
    -- El marcador busca por CLASE ( ents.FindByClass ) y este comando por CAMPO
    -- ( ents.GetAll + IsPhantasmagoriaGhost ). Imprimir los dos numeros separa
    -- ademas una tercera causa que nadie habia nombrado: que las dos busquedas
    -- no encuentren lo mismo.
    local porClase = #ents.FindByClass( "terminator_nextbot_phantom" )
    local porCampo = 0

    for _, e in ipairs( ents.GetAll() ) do
        if IsValid( e ) and e.IsPhantasmagoriaGhost then porCampo = porCampo + 1 end

    end

    -- ⚠ EL CONTADOR DEL DRAW, Y ES LA ACREDITACION DE LA MECANICA ENTERA. Solo
    -- lo toca la rama que se saltea el dibujado, asi que un numero que SUBE
    -- prueba que el camino del render corrio y decidio no dibujar -- que es
    -- justo lo que ninguna bandera podia probar. Se imprime siempre, tambien en
    -- 0: con el fantasma visible, 0 es lo correcto, y con uno invisible delante,
    -- 0 es el defecto. Los dos casos se leen distinto **si el numero esta**.
    say( "saltos del Draw ( veces que NO se dibujo un fantasma ): " .. saltosDeDraw ..
        "   -- tipear el comando dos veces: con un fantasma invisible a la vista tiene que SUBIR." )

    say( "en el CLIENTE:  por clase ( lo que usa el marcador ) " .. porClase ..
        "   ·  por campo ( lo que usa este comando ) " .. porCampo ..
        ( porClase ~= porCampo and "   !! NO COINCIDEN: el marcador y este comando no ven lo mismo" or "" ) )

    if porClase <= 0 and porCampo <= 0 then
        say( "    NINGUNA de las dos encuentra nada. Si el servidor dice que hay un fantasma cerca" )
        say( "    ( phantasmagoria_ghost_where ), entonces EF_NODRAW se lleva la entidad del lado" )
        say( "    cliente y NINGUN marcador clientside puede dibujar un fantasma invisible: eso" )
        say( "    tumba Diseno 20.4 y hay que networkear la posicion por otro lado." )

    end

    local vistos = 0

    for _, ghost in ipairs( ents.GetAll() ) do
        if not ghost.IsPhantasmagoriaGhost then continue end
        if not IsValid( ghost ) then continue end

        vistos = vistos + 1

        local key = ghost:GetNWString( "phantasmagoria_type", "" )
        local t   = istable( T ) and key ~= "" and T[ key ] or nil

        say( "#" .. ghost:EntIndex() ..
            "   key networkeada " .. ( key ~= "" and ( "'" .. key .. "'" ) or "( vacia: el server no le asigno tipo )" ) ..
            "   ficha " .. ( t and ( "SI -> " .. t.name .. ", threshold " .. tostring( t.hunt and t.hunt.threshold ) .. " %" ) or "NO" ) )

        -- Diseno 20.4: el estado de render, del lado que lo dibuja. Es LA
        -- medicion de la invisibilidad, porque el criterio de esa mecanica es
        -- visual y un marcador 3D no produce texto -- que es lo que hizo que la
        -- fila del networkeo se marcara verde tres rondas sin evidencia.
        local invisible, estado = renderState( ghost )

        say( "     render:               " .. estado )

        -- ⚠ LA POSICION DEL CLIENTE, Y ES LA FILA 01 DE LA r21. El servidor
        -- imprime la suya en phantasmagoria_ghost_where: si las dos NO
        -- COINCIDEN mientras el fantasma camina, la copia del cliente esta
        -- congelada y ningun marcador clientside sabe donde esta el fantasma
        -- -- que es la version de la causa ( a ) que la r20 no habia nombrado,
        -- porque la entidad SI esta y lo que falta es la informacion.
        local edad, txtPos = posFreshness( ghost )
        local p = ghost:GetPos()

        say( string.format( "     pos EN EL CLIENTE:    %.1f %.1f %.1f   ( %s )", p.x, p.y, p.z, txtPos ) )
        say( "                           comparar con la linea 'pos' de phantasmagoria_ghost_where, " ..
            "CON EL FANTASMA CAMINANDO." )

        if edad and edad >= POS_CONGELADA then
            say( "                           !! esta posicion NO CAMBIA hace " .. string.format( "%.1f", edad ) ..
                " s. Si el servidor lo da caminando, el cliente NO lo esta recibiendo." )

        end

        -- Y QUE HACE EL MARCADOR CON ESO. Sin esta linea, un fantasma sin
        -- marcador no distingue "esta invisible y el modo honesto lo respeto"
        -- de "el marcador esta roto" ni de "no esta en el PVS".
        local modo = cvMarker:GetInt()

        say( "     el marcador " ..
            ( modo == 0 and "esta APAGADO ( phantasmagoria_debug_ghost 0 )"
            or ( modo >= 2 and invisible ) and "NO LO DIBUJA ( modo 2 honesto, y el fantasma esta invisible )"
            or "dibuja:  " .. typeLabel( ghost ) ..
               ( ( modo < 2 and invisible ) and "   !! EN MODO 1 SOBRE UN FANTASMA INVISIBLE: el marcador lo esta delatando" or "" ) ) )

    end

    if vistos <= 0 then
        say( "ningun fantasma EN EL PVS. El cliente solo tiene los que estan a la vista: " ..
            "que no aparezca aca NO prueba que no exista ( para eso, phantasmagoria_ghost_where )." )

    else
        say( vistos .. " fantasma(s) en el PVS." )

    end

end, "Imprime lo que el CLIENTE tiene de cada fantasma a la vista: la key networkeada, si resuelve a ficha, y el texto exacto que dibuja el marcador." )

-- Lo que el marcador vio en el ultimo frame, para la linea de HUD del modo 2.
-- Eran DOS numeros y ahora son TRES, y el tercero entro por la r20: los que
-- estan en el PVS, los que no dibuje, y los que tengo con LA POSICION
-- CONGELADA. Sin el segundo, una pantalla sin marcadores no distingue "los
-- oculte" de "no hay ninguno cerca". Sin el tercero, un marcador dibujado en el
-- lugar equivocado se lee como un marcador correcto -- que es peor, porque es
-- el instrumento mintiendo con confianza.
local ultimoConteo = { enPVS = 0, ocultos = 0, congelados = 0 }

hook.Add( "PostDrawTranslucentRenderables", "phantasmagoria_ghost_marker", function( _bDrawingDepth, bDrawingSkybox, isDraw3DSkybox )
    if bDrawingSkybox or isDraw3DSkybox then return end
    if not cvMarker:GetBool() then return end

    -- LIMITACION CONOCIDA: solo encuentra fantasmas dentro del PVS. Uno lejos
    -- o detras de geometria simplemente no esta en el cliente, y la ausencia
    -- de marcador NO prueba que no exista. Para eso esta el comando
    -- phantasmagoria_ghost_where, que corre en el servidor y los ve todos.
    --
    -- Y ojo con los 30 tipos de Diseno 12.2: van a ser clases propias
    -- ( phantasmagoria_<tipo> ), asi que esta busqueda por clase exacta va a
    -- dejar de encontrarlos y hay que ampliarla cuando existan.
    local ghosts = ents.FindByClass( "terminator_nextbot_phantom" )

    -- El conteo se escribe ANTES del early return, y esa es la diferencia entre
    -- un instrumento y un dibujo: con cero fantasmas la linea de HUD tiene que
    -- decir cero, no quedarse con el numero del frame anterior.
    ultimoConteo.enPVS      = #ghosts
    ultimoConteo.ocultos    = 0
    ultimoConteo.congelados = 0

    if #ghosts <= 0 then return end

    local ply = LocalPlayer()
    if not IsValid( ply ) then return end

    -- Diseno 20.4: en modo 2 el marcador NO delata al fantasma invisible.
    local honesto = cvMarker:GetInt() >= 2

    local eyePos = ply:EyePos()
    local yaw = ply:EyeAngles().y

    cam.IgnoreZ( true )
    render.SetColorMaterial()

    for _, ghost in ipairs( ghosts ) do
        if not IsValid( ghost ) then continue end

        -- ⚠ DECIDE EL NW VAR, Y HASTA LA r20 DECIDIA GetNoDraw. El motivo
        -- entero esta arriba, en renderState: en juego esa bandera dijo `false`
        -- sobre un fantasma que no se dibujaba, asi que el modo honesto no se
        -- activaba nunca y este contador daba 0 con un fantasma invisible
        -- delante. Las cuatro lecturas se siguen imprimiendo en
        -- phantasmagoria_ghost_cl: la que decide es la que se pudo acreditar,
        -- no la que sonaba mejor.
        if ghost:GetNWBool( "phantasmagoria_invisible", false ) then
            ultimoConteo.ocultos = ultimoConteo.ocultos + 1

            if honesto then continue end

        end

        -- ⚠ Y ACA EL MARCADOR PUEDE ESTAR MINTIENDO. Si el cliente dejo de
        -- recibir la entidad, GetPos() devuelve la ultima que llego y la caja
        -- se dibuja donde el fantasma ESTABA. Un instrumento que no puede
        -- saberlo dibuja lo mismo que uno correcto; este lo dice en la
        -- etiqueta, que es donde el que mira ya esta mirando.
        local edadPos = posFreshness( ghost )
        local congelada = edadPos and edadPos >= POS_CONGELADA

        if congelada then ultimoConteo.congelados = ultimoConteo.congelados + 1 end

        local pos = ghost:GetPos()
        local mins, maxs = ghost:OBBMins(), ghost:OBBMaxs()
        local top = pos + Vector( 0, 0, maxs.z )

        local hunting = ghost:GetNWBool( "phantasmagoria_hunting", false )
        local col = hunting and colHunt or colGhost

        render.DrawWireframeBox( pos, angle_zero, mins, maxs, col, true )
        render.DrawLine( top, top + Vector( 0, 0, BEAM_HEIGHT ), col, true )

        local distU = eyePos:Distance( pos )
        local dist = math.Round( distU / UNITS_PER_METER, 1 )

        -- La escala sigue a la distancia para que el texto ocupe SIEMPRE lo
        -- mismo en pantalla. Con la escala fija que tenia, a 1,3 m tapaba media
        -- pantalla (corrida 3) -- justo cuando mas querias ver -- y de lejos no
        -- se leia. La constante sale de la corrida 2: a 4 m con 0.35 se leia
        -- bien. Los topes evitan el texto microscopico de cerca y uno de
        -- kilometros de largo del otro lado del mapa.
        local escala = math.Clamp( distU * LABEL_SCALE_PER_UNIT, 0.12, 1.5 )

        cam.Start3D2D( top + Vector( 0, 0, LABEL_HEIGHT ), Angle( 0, yaw - 90, 90 ), escala )
            draw.SimpleText( "PHANTOM #" .. ghost:EntIndex(), "DermaLarge", 0, 0, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
            draw.SimpleText( dist .. " m  " .. ( hunting and "HUNT" or "calma" ), "DermaLarge", 0, 6, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
            draw.SimpleText( typeLabel( ghost ), "DermaLarge", 0, 34, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )

            if congelada then
                draw.SimpleText( "!! POS CONGELADA " .. string.format( "%.0f", edadPos ) .. " s",
                    "DermaLarge", 0, 62, colHunt, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )

            end
        cam.End3D2D()

    end

    cam.IgnoreZ( false )

end )

---------------------------------------------------------------------------
-- LA LINEA QUE SIGUE HABLANDO CUANDO EL MARCADOR DEJA DE DIBUJAR
---------------------------------------------------------------------------
-- Diseno 20.4, y es la mitad sin la cual el modo 2 no se puede juzgar: un
-- fantasma invisible deja de tener marcador, y una pantalla sin marcadores no
-- distingue tres cosas -- que lo oculte, que no hay ninguno cerca, o que el
-- marcador se rompio.
--
-- ⚠ Y ADEMAS ES LA UNICA EVIDENCIA QUE SOBREVIVE A UNA CAPTURA. La regla que
-- costo tres rondas en la tajada A es que *un criterio visual necesita un
-- instrumento que produzca texto*; una consola se pega en el chat, pero la
-- pregunta de este bloque -- "no lo veo" -- se contesta mirando la pantalla. Que
-- el conteo este DENTRO de la pantalla es lo que hace que la captura sea
-- evidencia y no una impresion.
--
-- Solo en modo 2: en 1 el marcador ya se ve y esta linea seria ruido permanente.
hook.Add( "HUDPaint", "phantasmagoria_ghost_marker_hud", function()
    if cvMarker:GetInt() < 2 then return end

    local txt = "debug_ghost 2 ( honesto )   ·   " .. ultimoConteo.enPVS .. " en PVS   ·   " ..
        ultimoConteo.ocultos .. " invisibles ( NO se dibujan )" ..
        ( ultimoConteo.congelados > 0
        and ( "   ·   !! " .. ultimoConteo.congelados .. " CON LA POSICION CONGELADA ( el cliente no los esta recibiendo )" )
        or "" )

    -- Sin fondo ni caja: es un instrumento de desarrollo y tapar el mapa seria
    -- pelearle a lo que se esta tratando de mirar.
    draw.SimpleText( txt, "DermaDefault", 12, 12, colGhost, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )

end )
