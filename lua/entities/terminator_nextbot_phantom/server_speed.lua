--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom / VELOCIDAD

    Diseno 1.1 manda que la velocidad se DERIVE de la carrera real del jugador
    y que los 30 tipos sean multiplicadores sobre eso, para que el addon se
    calibre solo en cualquier servidor. Hoy no lo hacia: el fantasma heredaba
    ENT.RunSpeed = 550 de la base ( terminator_nextbot/shared.lua:132, con el
    comentario del autor de la base "bit faster than players... in a straight
    line" ) contra los 280 de Better Movement, o sea 1,96x. Lo agarro el JUEGO
    en la corrida 8, no la lectura.

    EL PUNTO DE EXTENSION ES DECLARADO, no hay que overridear nada. SetupSpeed
    ( motionoverrides.lua:3785-3807 ) elige entre RunSpeed / WalkSpeed /
    MoveSpeed / CrouchSpeed y DESPUES hace:

        speed = myTbl.RunTask( self, "ModifyMovementSpeed", speed ) or speed
        myTbl.loco:SetDesiredSpeed( speed )

    Ese es el UNICO call site de ModifyMovementSpeed en las 55k lineas de la
    base ( grep sobre los 71 archivos + HIM: una sola ocurrencia, y ninguna
    implementacion ). Lo llama BehaveUpdate cada tick
    ( behaviouroverrides.lua:114 ).

    ModifyMovementSpeed NO es un metodo de la entidad: es un callback de TAREA,
    y RunTask solo llama a las tareas ACTIVAS. Por eso cuelga de ENT.MyClassTask
    y no de ENT:ModifyMovementSpeed, que no lo llamaria nadie. MyClassTask es el
    punto de extension que la base declara para esto ( taskoverride.lua:328-332,
    "Simple way to add class-specific behaviour to a bot" ): DoClassTasks lo
    levanta de cada clase del arbol de bases y lo registra como
    "<clase>_handler" con StartsOnInitialize forzado ( :344-358 ). Efecto
    lateral util: la tarea aparece por nombre en phantasmagoria_ghost_where, o
    sea que "esta enganchado" se puede VER sin lua_run.
---------------------------------------------------------------------------]]

---------------------------------------------------------------------------
-- Las perillas
---------------------------------------------------------------------------
-- La conversion entera se apaga con una convar para que el A/B sea un comando
-- y no una reversion. En 0 el fantasma vuelve a los 550 de la base, que es el
-- defecto medido: ese es el control negativo del check.
local cvDerive = CreateConVar( "phantasmagoria_ghost_derivespeed", "1", FCVAR_ARCHIVE,
    "El fantasma deriva su velocidad de la carrera del jugador ( Diseno 1.1 ). En 0 usa los 550 u/s de la base, que es el defecto original: sirve para el A/B.", 0, 1 )

-- ANDAMIO, igual que phantasmagoria_hunt: el multiplicador lo va a poner la
-- tabla de tipos ( ghost_types.lua ya lo trae en los 30, speed.base ) via el
-- campo phantom_SpeedMul. Mientras el motor de rasgos no exista, esta convar es
-- la unica forma de moverlo en juego, y el campo GANA cuando exista.
-- 1.0 = Spirit = va tan rapido como vos corriendo ( Diseno 5.1 ).
local cvMul = CreateConVar( "phantasmagoria_ghost_speedmul", "1", FCVAR_ARCHIVE,
    "ANDAMIO. Multiplicador de la carrera del jugador ( Spirit = 1.0 ). Lo va a reemplazar speed.base de la tabla de tipos.", 0.1, 5 )

-- Sin Better Movement Y sin jugadores no hay de donde derivar nada. 400 es la
-- carrera default de un player de GMod sandbox. Se imprime como "fallback" en
-- el instrumento a proposito: un numero inventado tiene que verse como tal.
local GMOD_DEFAULT_RUN = 400

-- Cada cuanto se recalcula el objetivo. ModifyMovementSpeed corre CADA TICK, y
-- adentro no puede haber ni un GetConVar de mas: se cachea y listo.
local RECALC_EVERY = 0.5

---------------------------------------------------------------------------
-- De donde sale la carrera del jugador
---------------------------------------------------------------------------
-- Diseno 1.1, verificado contra el codigo del mod: Better Movement ESCRIBE en
-- la API nativa ( sh_bm_main.lua:455-457 ), asi que no hay que detectarlo para
-- que las cosas funcionen... pero el GETTER NO SIRVE:
--
--     ply:SetRunSpeed( bm_vars.speed.run:GetFloat() * _bmfraction )
--
-- y _bmfraction es dinamico, clampeado 1..2 con un Lerp por tick ( :450-453 ),
-- asi que ply:GetRunSpeed() devuelve entre 280 y 560 SEGUN EL INSTANTE. Un
-- fantasma calibrado con el getter sale el doble de rapido de forma
-- intermitente e irreproducible. Se lee la convar BASE, que es estable.
--
-- GetConVar( "sv_bm_enabled" ) == nil es el chequeo de existencia del mod: no
-- hace falta buscar archivos ni ganchos.
--
-- Devuelve DOS cosas y la segunda no es decoracion: es de donde salio el
-- numero. La regla de la casa es que el comando imprima con QUE esta midiendo,
-- y "280" no distingue la convar del getter ni del fallback.
function PHANTASMAGORIA.PlayerBaseRunSpeed( ply )
    local bmOn = GetConVar( "sv_bm_enabled" )

    if bmOn and bmOn:GetBool() then
        local run = GetConVar( "sv_bm_speed_run" )

        if run then
            return run:GetFloat(), "sv_bm_speed_run ( Better Movement )"

        end
    end

    if IsValid( ply ) then
        return ply:GetRunSpeed(), "ply:GetRunSpeed() de " .. ply:Nick() .. " ( sin Better Movement )"

    end

    return GMOD_DEFAULT_RUN, "fallback " .. GMOD_DEFAULT_RUN .. " ( ni mod ni jugadores )"

end

-- Contra quien se calibra. Solo importa SIN Better Movement, porque las convars
-- del mod son del servidor y valen para todos; con el mod montado el jugador de
-- referencia es irrelevante y aun asi se imprime, para que se vea que lo es.
function ENT:phantom_SpeedReferencePlayer()
    local enemy = self:GetEnemy()
    if IsValid( enemy ) and enemy:IsPlayer() then return enemy end

    local best, bestDist

    for _, ply in ipairs( player.GetAll() ) do
        local dist = self:GetRangeTo( ply )
        if not best or dist < bestDist then best, bestDist = ply, dist end

    end

    return best

end

---------------------------------------------------------------------------
-- La conversion
---------------------------------------------------------------------------
-- ES UN FACTOR, NO UN VALOR ABSOLUTO, y la decision merece explicacion porque
-- la alternativa parece mas simple y es peor.
--
-- La base tiene TRES marchas ( WalkSpeed 130 / MoveSpeed 300 / RunSpeed 550,
-- shared.lua:130-132 ) y elige entre ellas con ShouldRun/ShouldWalk. Devolver
-- un absoluto desde aca borraria esa eleccion: el fantasma andaria siempre a la
-- misma velocidad y "camina" vs "corre" dejaria de existir. Devolviendo un
-- factor, la marcha que la base eligio se conserva y lo que se calibra es la
-- ESCALA: con 280 y el multiplicador en 1.0 queda run 280 / move 153 / walk 66.
--
-- El divisor es la RunSpeed declarada por la base, capturada UNA VEZ al
-- spawnear ( AdditionalInitialize, server.lua ) y no leida en vivo. El motivo
-- es overcharging.lua:20-22:
--
--     self.RunSpeed = math.max( self.RunSpeed * 1.40, 550 )
--
-- Si el divisor se leyera en vivo, el overcharge se CANCELARIA solo -- el
-- fantasma volveria a los 280 justo cuando el mecanismo dice que tiene que ir
-- mas rapido -- y encima el bug seria invisible. Con el divisor congelado, el
-- overcharge multiplica el speed de entrada y sale multiplicado: sigue
-- funcionando, y la conversion no se lo lleva puesto.
function ENT:phantom_BaseRun()
    return self.phantom_BaseRunSpeed or self.RunSpeed or 550

end

-- Recalcula y cachea. Deja todo lo que uso en phantom_speedDbg para que el
-- instrumento imprima LOS INSUMOS y no solo el resultado: si el numero sale
-- raro, se tiene que poder ver cual de los cuatro lo torcio.
function ENT:phantom_RefreshSpeed()
    local ref             = self:phantom_SpeedReferencePlayer()
    local base, fuente    = PHANTASMAGORIA.PlayerBaseRunSpeed( ref )

    -- El campo gana sobre la convar: cuando el motor de rasgos exista va a
    -- escribir phantom_SpeedMul por tipo y el andamio deja de mandar solo.
    local mul, mulFuente
    if isnumber( self.phantom_SpeedMul ) then
        mul, mulFuente = self.phantom_SpeedMul, "campo phantom_SpeedMul ( tipo )"

    else
        mul, mulFuente = cvMul:GetFloat(), "convar phantasmagoria_ghost_speedmul ( ANDAMIO )"

    end

    local baseRun = self:phantom_BaseRun()
    local target  = base * mul
    local factor  = target / baseRun

    self.phantom_speedFactor = factor
    self.phantom_speedNext   = CurTime() + RECALC_EVERY
    self.phantom_speedDbg    = {
        ref       = IsValid( ref ) and ref:Nick() or "( ninguno )",
        base      = base,
        fuente    = fuente,
        mul       = mul,
        mulFuente = mulFuente,
        baseRun   = baseRun,
        target    = target,
        factor    = factor,
    }

    return factor

end

function ENT:phantom_SpeedFactor()
    if not self.phantom_speedFactor or ( self.phantom_speedNext or 0 ) < CurTime() then
        return self:phantom_RefreshSpeed()

    end

    return self.phantom_speedFactor

end

---------------------------------------------------------------------------
-- El enganche
---------------------------------------------------------------------------
-- RunTask corta en el PRIMER callback que devuelve algo no-nil
-- ( taskoverride.lua:47-60 ), y la linea de SetupSpeed es
-- "RunTask(...) or speed": devolver nil deja el valor de la base intacto. Por
-- eso el A/B apagado es un return pelado y no una copia del numero original --
-- copiarlo seria volver a escribir el default y que dejara de ser un control.
--
-- Nadie mas implementa este callback ( grep sobre la base y HIM: cero ), asi
-- que no hay riesgo de robarle el evento a otra tarea.
ENT.MyClassTask.ModifyMovementSpeed = function( self, _data, speed )
    if not cvDerive:GetBool() then return end
    if not isnumber( speed ) or speed <= 0 then return end

    -- El piso de 1 existe por una trampa de Lua y no por gameplay: SetupSpeed
    -- hace "RunTask(...) or speed", y en Lua el 0 es VERDADERO -- un 0 devuelto
    -- aca no cae al default, se aplica, y el fantasma queda clavado sin error.
    return math.max( speed * self:phantom_SpeedFactor(), 1 )

end

---------------------------------------------------------------------------
-- CAMINAR O CORRER CAZANDO
---------------------------------------------------------------------------
-- Observacion del autor en la ronda 3: "el ghost suele CAMINAR al hacer hunting
-- y CORRER cuando no me ve. Podria correr igualmente directo a mi."
--
-- LA CAUSA ESTA MEDIDA EN EL CODIGO Y ES UNA LINEA, canDoRun
-- ( shared.lua, ENT:canDoRun ):
--
--     if not angry and myTbl.IsSeeEnemy and Health == GetMaxHealth then return end
--
-- O sea: si NO esta enojado, TE VE, y esta con la vida entera -> no puede
-- correr. Las tres se cumplen siempre en nuestro fantasma, porque nadie le pega
-- durante un hunt normal. De ahi sale exactamente lo que el autor describe: te
-- ve y camina, te pierde y corre. ( shouldDoWalk, la funcion de al lado,
-- devuelve true por los dos caminos: no es la que decide. )
--
-- El punto de extension vuelve a ser una TAREA y no un metodo: ENT:ShouldRun
-- de la base ( motionoverrides.lua ) hace
-- "return myTbl.RunTask( self, 'ShouldRun' ) or false", asi que quien manda es
-- el callback de tarea.
--
-- TRAMPA, la misma familia que la del Think y peor: RunTask corta en el primer
-- callback que devuelve algo NO NIL, y en Lua false NO es nil. Devolver false
-- aca no significa "que decida otro": significa "NO corras", y ademas le roba
-- el evento a las tareas de movimiento de la base. Se devuelve true o nada.
local cvWalkHunt = CreateConVar( "phantasmagoria_ghost_walkhunt", "1", FCVAR_ARCHIVE,
    "0 = ninguno camina cazando ( todos corren ) · 1 = respeta el flag phantom_WalksWhenHunting de cada NPC ( que arranca en false: corren ) · 2 = TODOS caminan cazando.", 0, 2 )

-- EL NOMBRE NO ES phantom_WalksWhenHunting Y ESA ES LA CORRECCION DE LA RONDA
-- 4. Este metodo se llamaba igual que el CAMPO ( ENT.phantom_WalksWhenHunting ),
-- y como este archivo se incluye DESPUES de la declaracion del campo, la
-- funcion lo pisaba: el resolvedor leia una funcion, que no es true ni false, y
-- caia a la rama "es nil". El flag nunca fue legible.
--
-- Se vio en cada linea del reporte -- "campo = function: 0x8088..." -- y el
-- check que lo usaba paso IGUAL, porque el default de la rama nil coincidia con
-- lo que se queria. *Un default que coincide con lo esperado convierte un campo
-- roto en un check verde.* La guarda esta al final de server.lua.
function ENT:phantom_WalksHunting()
    -- El resolvedor vive en server_doors.lua, que se incluye DESPUES de este
    -- archivo. En tiempo de ejecucion ya esta, pero si ese include fallara esto
    -- correria cada tick: se dice y se sale, en vez de tirar un error por
    -- frame que tape la causa real.
    local resolver = PHANTASMAGORIA.ResolveFlag
    if not resolver then return false, "PHANTASMAGORIA.ResolveFlag no existe ( server_doors.lua no cargo )" end

    return resolver( self, "phantom_WalksWhenHunting", cvWalkHunt, false )

end

-- Y NO VA COMO CALLBACK DE TAREA, que es como estaba. Motivo medido en la
-- ronda 4: cazando a 0 u del jugador la lectura dio "deseada 66" ( caminando )
-- con el hunt puesto. RunTask corta en el primer callback que devuelve algo NO
-- NIL, y el ShouldRun de movement_followenemy hace
--
--     return length > targetFollowDist and self:canDoRun()
--
-- que con el path corto -- o sea cuando ya te alcanzo -- devuelve **false**, no
-- nil. Eso corta el recorrido y nuestro callback no llega a correr. O sea que
-- ganar dependia del ORDEN de las tareas, que ademas no es estable ( SetupTasks
-- las arranca iterando con pairs ).
--
-- ENT:ShouldRun de la base es un metodo comun ( motionoverrides.lua ), asi que
-- overridearlo y encadenar es deterministico y no compite con nadie. Es el
-- mismo patron que ya usan ShouldBeEnemy y BehaveUpdate en este addon.
--
-- *Un punto de extension que depende del orden de ejecucion no es un punto de
-- extension: es una carrera.*
function ENT:ShouldRun( myTbl )
    myTbl = myTbl or self:GetTable()

    -- Fuera del hunt manda la base: deambular alternando marcha se ve mejor que
    -- un fantasma corriendo por la casa todo el tiempo, y no es lo que se pidio.
    if myTbl.phantom_Hunting then
        -- CAZANDO DECIDIMOS NOSOTROS LAS DOS RAMAS, y la segunda es correccion
        -- de la ronda 5. Devolver nil con el flag puesto dejaba decidir a la
        -- base, y la base NO camina de forma consistente: canDoRun se niega
        -- solo cuando TE VE, asi que el fantasma "caminante" caminaba a la
        -- vista y arrancaba a correr apenas te perdia. El autor lo reporto
        -- exacto: *"si camina, pero aun persiste que mientras te caza y no te
        -- ve, empieza a correr hasta verte"*.
        --
        -- Aca false SI significa "no corras" y es seguro, porque esto es un
        -- METODO y no un callback de RunTask: no le corta el evento a nadie.
        -- Es la misma palabra con dos significados segun donde se escriba, y
        -- por eso el comentario de arriba insiste con la diferencia.
        local camina = self:phantom_WalksHunting()

        self.phantom_GaitWho = "override propio ( cazando, " .. ( camina and "camina" or "corre" ) .. " )"

        return not camina

    end

    self.phantom_GaitWho = "la base"

    return myTbl.BaseClass.ShouldRun( self, myTbl )

end

---------------------------------------------------------------------------
-- Instrumento: la velocidad, con sus cuatro insumos
---------------------------------------------------------------------------
-- Imprime la CADENA entera y no el resultado: convar del mod -> base ->
-- multiplicador -> factor -> las tres marchas -> lo que el locomotion tiene
-- puesto AHORA. Si el fantasma corre mal, la linea que discrepa dice donde.
--
-- Las dos ultimas son las que miden de verdad, y son distintas:
--   deseada   loco:GetDesiredSpeed(), o sea lo que SetupSpeed escribio. Es la
--             prueba de que el callback se engancho.
--   real      GetCurrentSpeed(), lo que el bot esta yendo. Puede ser menor sin
--             que nada este roto ( aceleracion, obstaculos, curvas ), asi que
--             un check que mida SOLO esta se cae por motivos que no son el bug.
PHANTASMAGORIA.AddCommand( "phantasmagoria_ghost_speed", function( ply )
    local say = PHANTASMAGORIA.MakeSay( ply )

    local bmOn = GetConVar( "sv_bm_enabled" )

    say( "[Phantasmagoria] Better Movement: " ..
        ( bmOn and ( "MONTADO, sv_bm_enabled " .. ( bmOn:GetBool() and "1" or "0" ) ) or "NO MONTADO ( GetConVar dio nil )" ) )

    if bmOn then
        say( "    sv_bm_speed_run  " .. GetConVar( "sv_bm_speed_run" ):GetFloat() ..
            "   walk " .. GetConVar( "sv_bm_speed_walk" ):GetFloat() ..
            "   slowwalk " .. GetConVar( "sv_bm_speed_slowwalk" ):GetFloat() )

        -- La trampa de Diseno 1.1, a la vista y no de palabra: el getter contra
        -- la convar, en el mismo renglon. Con el jugador quieto los dos
        -- coinciden; corriendo y girando, el getter se despega hasta 2x. Un
        -- check que dispare esto mientras el jugador esprinta es la unica forma
        -- de VER por que no se usa el getter.
        for _, target in ipairs( player.GetAll() ) do
            say( "    ply " .. target:Nick() ..
                "   GetRunSpeed() " .. math.Round( target:GetRunSpeed() ) ..
                "   contra la convar " .. math.Round( GetConVar( "sv_bm_speed_run" ):GetFloat() ) ..
                "   ( x" .. string.format( "%.2f", target:GetRunSpeed() / math.max( GetConVar( "sv_bm_speed_run" ):GetFloat(), 1 ) ) .. " -- ese es _bmfraction )" )

        end

        -- Dato del mod que Diseno 1.1 marca como regalo y que ademas explica
        -- una discrepancia legitima: adentro de un edificio el jugador va al
        -- 80 %, asi que "el fantasma me alcanza adentro" NO prueba que la
        -- conversion este mal.
        local inside = GetConVar( "sv_bm_speed_inside_multiplier" )
        if inside then
            say( "    sv_bm_speed_inside_multiplier " .. inside:GetFloat() ..
                "   ( adentro de un edificio el JUGADOR va a " .. math.Round( GetConVar( "sv_bm_speed_run" ):GetFloat() * inside:GetFloat() ) ..
                " u/s; el fantasma NO )" )

        end
    end

    say( "[Phantasmagoria] conversion " .. ( cvDerive:GetBool() and "ENCENDIDA" or "APAGADA ( el fantasma usa los 550 de la base )" ) )

    local found = PHANTASMAGORIA.EachGhost( function( ghost )
        local dbg = ghost.phantom_speedDbg

        say( "#" .. ghost:EntIndex() .. "  " .. ghost:GetClass() )

        if not dbg then
            say( "    ( todavia no calculo nada: el callback no corrio ni una vez )" )
            return

        end

        say( "    referencia  " .. dbg.ref .. "   base " .. math.Round( dbg.base ) .. " u/s   de " .. dbg.fuente )
        say( "    multiplic.  x" .. string.format( "%.3f", dbg.mul ) .. "   de " .. dbg.mulFuente )
        say( "    objetivo    " .. math.Round( dbg.target ) .. " u/s   ( base x multiplicador )" )
        say( "    factor      x" .. string.format( "%.3f", dbg.factor ) ..
            "   ( objetivo / RunSpeed declarada " .. math.Round( dbg.baseRun ) .. " )" )

        say( "    marchas     base run " .. math.Round( ghost.RunSpeed or 0 ) ..
            " · move " .. math.Round( ghost.MoveSpeed or 0 ) ..
            " · walk " .. math.Round( ghost.WalkSpeed or 0 ) )
        say( "                convertidas run " .. math.Round( ( ghost.RunSpeed or 0 ) * dbg.factor ) ..
            " · move " .. math.Round( ( ghost.MoveSpeed or 0 ) * dbg.factor ) ..
            " · walk " .. math.Round( ( ghost.WalkSpeed or 0 ) * dbg.factor ) )

        -- Sin guarda de IsValid sobre el loco, y esto NO es un descuido: en la
        -- corrida 6 una guarda mia hizo que la velocidad dijera "quieto ( 0 u/s )"
        -- con el bot cruzando 1.400 u entre lecturas. CLuaLocomotion no tiene
        -- metodo IsValid y el IsValid() de GMod devuelve false para todo objeto
        -- que no lo tenga; la base lo llama directo
        -- ( terminator_nextbot_base/motion.lua:54 ).
        local loco = ghost.loco

        say( "    AHORA       deseada " .. math.Round( loco and loco:GetDesiredSpeed() or -1 ) .. " u/s" ..
            "   real " .. math.Round( ghost:GetCurrentSpeed() ) .. " u/s" ..
            "   ( deseada = lo que SetupSpeed escribio; real = lo que va )" )

        -- EL DISCRIMINANTE QUE FALTABA EN LA RONDA 4. La fila del walkhunt no se
        -- pudo juzgar porque a 0 u del jugador la base camina POR SU CUENTA
        -- ( el ShouldRun de movement_followenemy pide que el path sea largo ),
        -- asi que "camina" no distinguia nuestro flag de su comportamiento
        -- normal. Sin esta linea, las dos causas se ven iguales.
        say( "    marcha      " .. ( ghost.phantom_Hunting and "CAZANDO" or "en calma" ) ..
            "   la decidio: " .. tostring( ghost.phantom_GaitWho or "( todavia nadie )" ) ..
            "   camina cazando: " .. ( ghost:phantom_WalksHunting() and "SI" or "NO" ) )

    end )

    if found <= 0 then
        say( "[Phantasmagoria] no hay ningun fantasma vivo." )

    end
end, "Imprime la cadena entera de la velocidad del fantasma: convar del mod, base, multiplicador, factor y lo que el locomotion tiene puesto ahora." )
