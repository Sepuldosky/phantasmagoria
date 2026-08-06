--[[-------------------------------------------------------------------------
    Phantasmagoria - Camara de fotos: PRUEBA de viewmodel con manos (nivel 0)

    QUE PRUEBA ESTE ARCHIVO
    Que se puede tener manos animadas sosteniendo un prop de Phasmophobia
    SIN compilar nada: sin Blender, sin SMD, sin studiomdl.

    LA MEDICION QUE LO HACE POSIBLE  [medido 2026-08-03, leyendo el binario]
    c_medkit.mdl (garrysmod_dir.vpk) declara:
        40 huesos    - ValveBiped completo de los dos brazos, y ademas
                       'medkit_bone' (parent = -1), suelto, para el objeto
         6 secuencias- anim_ref, anim_draw, anim_idle, anim_fire, anim_holster,
                       anim_idle_layer
         1 material  - "healthKit01"
         1 bodypart / 1 submodelo / 0 attachments

    El dato que cambia el problema es el ULTIMO: un material, y es el del
    botiquin. Un viewmodel c_ de Source NO contiene los brazos - contiene el
    objeto, el esqueleto y las animaciones. Los brazos los pone UseHands
    bonemergeando el c_arms_* del playermodel, que es otra entidad.
    Por eso tapar el submaterial 0 borra el botiquin ENTERO y no toca ni una
    mano. Y por eso nunca hay que modelar manos.

    LO QUE ESTE ARCHIVO NO PRUEBA
    Que el gesto quede bien. anim_idle es la pose para sostener un botiquin de
    HL2 (16.9 x 10.5 x 4.4 u); la camara mide 2.78 x 6.38 x 3.97 u, o sea es
    bastante mas chica. Que los dedos no la atraviesen es exactamente lo que
    hay que mirar en juego, y no lo decide ningun numero de este archivo.

    COMO SE CALIBRA
    Todo por convar de cliente, en vivo, sin reiniciar el mapa. Los defaults
    son CERO a proposito: la primera corrida tiene que mostrar donde cae el
    hueso crudo, no una pose ya maquillada que esconde de donde salio.

        ph_vm_x / _y / _z          offset en el espacio del hueso ancla
        ph_vm_pitch / _yaw / _roll rotacion, en ese orden
        ph_vm_scale                escala del prop dibujado
        ph_vm_hide                 0 nada / 1 submaterial / 2 escala de hueso
        ph_vm_bone                 nombre del hueso ancla
        ph_vm_dump                 imprime el estado REAL, medido del vm

    NOTA sobre ph_vm_hide 2: escala 'medkit_bone' a cero. Si el ancla es ese
    mismo hueso, la matriz que se lee para colocar la camara sale escalada a
    cero tambien y la camara desaparece con el botiquin. No esta corregido a
    proposito: es la rama que el check 09 mide.
---------------------------------------------------------------------------]]

AddCSLuaFile()

SWEP.Base       = "weapon_base"
SWEP.PrintName  = "Camara de fotos [prueba de viewmodel]"
SWEP.Author     = "Phantasmagoria"
SWEP.Purpose    = "Prototipo nivel 0: manos animadas sin compilar modelo."
SWEP.Category   = "Phantasmagoria"

SWEP.Spawnable      = true
SWEP.AdminOnly      = false
SWEP.DrawAmmo       = false
SWEP.DrawCrosshair  = false

-- El viewmodel es PRESTADO: aporta esqueleto y animaciones, no geometria.
SWEP.ViewModel      = "models/weapons/c_medkit.mdl"
SWEP.WorldModel     = "models/phas/eqp_digital_camera.mdl"
SWEP.UseHands       = true
-- 54 es el FOV para el que Valve autoro los viewmodels de HL2. Con 90 los
-- brazos salen estirados; no es una preferencia, es el numero del modelo.
SWEP.ViewModelFOV   = 54
SWEP.HoldType       = "camera"

SWEP.Primary.ClipSize      = -1
SWEP.Primary.DefaultClip   = -1
SWEP.Primary.Automatic     = false
SWEP.Primary.Ammo          = "none"
SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

local PROP_MODEL  = "models/phas/eqp_digital_camera.mdl"
local HIDE_MAT    = "phantasmagoria/vm_invisible"
local SEQ_DRAW    = "anim_draw"
local SEQ_IDLE    = "anim_idle"
local SEQ_FIRE    = "anim_fire"
local SEQ_HOLSTER = "anim_holster"

if CLIENT then
    -- Pose CALIBRADA en juego (ronda 3). Hasta aca los defaults eran cero a
    -- proposito, para que la primera corrida mostrara el hueso crudo; ya se
    -- midio, asi que ahora el default es la pose que se vio bien.
    --
    -- OJO: estos convars son FCVAR_ARCHIVE (el `true`), o sea el valor queda
    -- guardado en el cfg del cliente. En una maquina que ya los toco, cambiar
    -- el default de aca NO cambia nada: gana el guardado. Es la unica forma
    -- conocida de que esto "ande en mi maquina" y no en la del que se suscribe.
    -- Para eso esta ph_vm_reset.
    CreateClientConVar("ph_vm_x",     "2", true, false, "Offset del prop sobre el eje Forward del hueso")
    CreateClientConVar("ph_vm_y",     "5", true, false, "Offset sobre Right")
    CreateClientConVar("ph_vm_z",     "-2", true, false, "Offset sobre Up")
    CreateClientConVar("ph_vm_pitch", "0", true, false, "Rotacion del prop: pitch")
    CreateClientConVar("ph_vm_yaw",   "180", true, false, "Rotacion del prop: yaw")
    CreateClientConVar("ph_vm_roll",  "180", true, false, "Rotacion del prop: roll")
    CreateClientConVar("ph_vm_scale", "1", true, false, "Escala del prop dibujado")
    -- Default 2 desde la ronda 2: el submaterial invisible se APLICA pero no es
    -- invisible - el botiquin sale blanco, o sea el .vmt se encontro y el alpha
    -- no surtio efecto. La escala de hueso lo oculta de verdad y ya se vio en
    -- juego. El modo 1 queda para poder auditar si el .vmt corregido sirve.
    CreateClientConVar("ph_vm_hide",  "2", true, false, "0 no ocultar / 1 submaterial / 2 escala de hueso")
    -- Default cambiado en la ronda 3: anclado a 'medkit_bone' la camara no
    -- acompanaba el giro; anclada a la mano si, y se ve en juego. 'medkit_bone'
    -- es un hueso RAIZ (parent = -1, leido del binario) y el modelo montado no
    -- es el de Valve, asi que nada obligaba a que estuviera animado igual.
    CreateClientConVar("ph_vm_bone",  "ValveBiped.Bip01_R_Hand", true, false, "Hueso ancla del prop")
    -- 0 reproduce el dibujo de la ronda 1 (solo render override): es la reversion
    -- que audita el arreglo de la orientacion, no una opcion de gusto.
    CreateClientConVar("ph_vm_draw",  "1", true, false, "0 dibujo de la ronda 1 / 1 con SetPos+SetAngles+SetupBones")
end

---------------------------------------------------------------------------
-- Secuencias por NOMBRE, no por activity.
--
-- c_medkit no expone ACT_VM_*: sus secuencias se llaman anim_draw, anim_idle,
-- anim_fire, anim_holster. SendWeaponAnim(ACT_VM_DRAW) sobre este modelo no
-- tiene por que resolver a nada. Buscar por nombre es determinista y ademas
-- deja el fallo visible: LookupSequence devuelve -1 y se imprime una vez.
---------------------------------------------------------------------------
function SWEP:PlaySeq( name )
    local ply = self:GetOwner()
    if not IsValid( ply ) then return end
    local vm = ply:GetViewModel()
    if not IsValid( vm ) then return end

    local seq = vm:LookupSequence( name )
    if not seq or seq < 0 then
        if not self.warned then
            self.warned = true
            print( "[phantasmagoria vm] la secuencia '" .. name .. "' no existe en " .. tostring( vm:GetModel() ) )
        end
        return
    end

    vm:SendViewModelMatchingSequence( seq )
    self.IdleAt = CurTime() + vm:SequenceDuration( seq )
end

function SWEP:Deploy()
    self:PlaySeq( SEQ_DRAW )
    return true
end

function SWEP:Holster()
    self:PlaySeq( SEQ_HOLSTER )

    -- Devolver el viewmodel como estaba. NO es cosmetico: el viewmodel es UNA
    -- entidad reusada por todas las armas del jugador, asi que un submaterial
    -- invisible que no se limpia aca deja invisible el arma SIGUIENTE, sin
    -- ningun error y sin relacion aparente con esta.
    if CLIENT then
        local ply = self:GetOwner()
        local vm  = IsValid( ply ) and ply:GetViewModel()
        if IsValid( vm ) then
            vm:SetSubMaterial( 0, nil )
            local b = vm:LookupBone( "medkit_bone" )
            if b then vm:ManipulateBoneScale( b, Vector( 1, 1, 1 ) ) end
        end
        self.hideMode = nil
    end

    return true
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire( CurTime() + 1 )
    self:PlaySeq( SEQ_FIRE )
end

function SWEP:SecondaryAttack()
end

function SWEP:Think()
    -- Devolver a idle cuando la secuencia previa termino. No es cosmetico:
    -- si nadie la devuelve, el viewmodel se queda clavado en el ultimo frame
    -- de anim_draw y parece que la animacion "no corre".
    if self.IdleAt and CurTime() >= self.IdleAt then
        self.IdleAt = nil
        self:PlaySeq( SEQ_IDLE )
    end
end

if not CLIENT then return end

---------------------------------------------------------------------------
-- Ocultar la geometria prestada
---------------------------------------------------------------------------
local function applyHide( vm )
    local mode = GetConVar( "ph_vm_hide" ):GetInt()

    -- Submaterial: se pone y se saca con la misma llamada, sin estado propio.
    vm:SetSubMaterial( 0, mode == 1 and HIDE_MAT or nil )

    -- Escala de hueso: hay que revertirla explicitamente, porque a diferencia
    -- del submaterial NO se limpia sola al cambiar de modo.
    local b = vm:LookupBone( "medkit_bone" )
    if b then
        vm:ManipulateBoneScale( b, mode == 2 and vector_origin or Vector( 1, 1, 1 ) )
    end
end

function SWEP:PreDrawViewModel( vm )
    local mode = GetConVar( "ph_vm_hide" ):GetInt()
    if self.hideMode ~= mode then
        self.hideMode = mode
        applyHide( vm )
    end
end

---------------------------------------------------------------------------
-- Dibujar el prop en el hueso
--
-- Va en PostDrawViewModel, no en un hook de render del mundo. Esa es la
-- diferencia con el "camino largo" de EQUIPAMIENTO.md 5.3: ahi el prop se
-- dibuja en la pasada del mundo y ATRAVIESA PAREDES, porque el engine dibuja
-- los viewmodels en un rango de profundidad aparte. Aca el prop entra dentro
-- de esa misma pasada. Eso lo mide el check 05.
---------------------------------------------------------------------------
function SWEP:PostDrawViewModel( vm )
    if not IsValid( self.propEnt ) then
        self.propEnt = ClientsideModel( PROP_MODEL, RENDERGROUP_OPAQUE )
        if not IsValid( self.propEnt ) then return end
        self.propEnt:SetNoDraw( true )
    end

    local boneName = GetConVar( "ph_vm_bone" ):GetString()
    local b = vm:LookupBone( boneName )
    if not b then return end

    local m = vm:GetBoneMatrix( b )
    if not m then return end

    local pos = m:GetTranslation()
    local ang = m:GetAngles()

    -- La pose que este frame USO de verdad, con su marca de tiempo. La lee
    -- ph_vm_ang. Existe porque la matriz del hueso leida FUERA del pase de
    -- render no es la misma que adentro -- el viewmodel solo esta en su pose de
    -- render mientras se lo dibuja -- y en la ronda 3 eso hizo que el comando
    -- informara un yaw casi constante en los DOS anclajes, incluido el que en
    -- pantalla rotaba bien. La marca de tiempo esta para que un valor viejo no
    -- se pueda leer como uno fresco, que es lo que paso.
    self.dbgAng = ang
    self.dbgAt  = CurTime()

    pos = pos + ang:Forward() * GetConVar( "ph_vm_x" ):GetFloat()
              + ang:Right()   * GetConVar( "ph_vm_y" ):GetFloat()
              + ang:Up()      * GetConVar( "ph_vm_z" ):GetFloat()

    ang:RotateAroundAxis( ang:Up(),      GetConVar( "ph_vm_yaw"   ):GetFloat() )
    ang:RotateAroundAxis( ang:Right(),   GetConVar( "ph_vm_pitch" ):GetFloat() )
    ang:RotateAroundAxis( ang:Forward(), GetConVar( "ph_vm_roll"  ):GetFloat() )

    local e = self.propEnt

    -- RONDA 3, modo 2: la matriz del hueso ENTERA, sin descomponerla.
    --
    -- Los modos 0 y 1 pasan por GetTranslation() + GetAngles() y le entregan al
    -- prop dos valores sueltos. Este no descompone nada: compone la matriz del
    -- hueso con una de offset y la empuja como matriz de modelo. Si el defecto
    -- de orientacion esta en la descomposicion, este modo lo esquiva; si esta
    -- en el hueso, este modo falla IGUAL. Por eso existen los dos.
    --
    -- Con ph_vm_hide 2 la matriz viene con escala 0 (medido: el dump imprimio
    -- 'escala de la matriz 0'), asi que este modo colapsa el prop. No es un bug
    -- de este modo: es la misma escala 0, ahora visible porque no se descarta.
    if GetConVar( "ph_vm_draw" ):GetInt() == 2 then
        local off = Matrix()
        off:Translate( Vector( GetConVar( "ph_vm_x" ):GetFloat(),
                               GetConVar( "ph_vm_y" ):GetFloat(),
                               GetConVar( "ph_vm_z" ):GetFloat() ) )
        off:Rotate( Angle( GetConVar( "ph_vm_pitch" ):GetFloat(),
                           GetConVar( "ph_vm_yaw" ):GetFloat(),
                           GetConVar( "ph_vm_roll" ):GetFloat() ) )
        local s2 = GetConVar( "ph_vm_scale" ):GetFloat()
        if s2 ~= 1 then off:Scale( Vector( s2, s2, s2 ) ) end

        -- RONDA 3, EN JUEGO: este modo mando la camara volando lejos, flotando
        -- en el aire. Causa: se limpiaban los overrides con SetRenderOrigin()
        -- SIN argumento, que no es "ponerlo en cero" sino "no haya override" -
        -- entonces la entidad conservaba su posicion de mundo y PushModelMatrix
        -- la componia encima. Doble transformacion. Para dibujar dentro de una
        -- matriz empujada, la entidad tiene que estar en el ORIGEN, explicito.
        e:SetPos( vector_origin )
        e:SetAngles( angle_zero )
        e:SetRenderOrigin( vector_origin )
        e:SetRenderAngles( angle_zero )
        e:DisableMatrix( "RenderMultiply" )

        cam.PushModelMatrix( m * off )
            e:DrawModel()
        cam.PopModelMatrix()
        return
    end

    -- RONDA 2. En la ronda 1 esto eran SOLO las dos llamadas de render override,
    -- y la camara salia en la posicion correcta con la ORIENTACION DEL MUNDO:
    -- girando 180 grados se veia su cara opuesta. Causa: DrawModel() arma los
    -- huesos con la pose REAL de la entidad (SetPos/SetAngles), no con el
    -- override de render; para un modelo de un hueso, la malla entera cuelga de
    -- ese hueso, asi que la traslacion la corregia el override y la rotacion no.
    --
    -- El arreglo no es elegir entre los dos pares: es poner los cuatro y armar
    -- los huesos. Precedente leido, no supuesto - ARC9 dibuja los attachments
    -- sobre el viewmodel exactamente asi, en
    -- dev/other/Arc9 Base/lua/weapons/arc9_base/cl_drawmodel.lua:159-164.
    if GetConVar( "ph_vm_draw" ):GetBool() then
        e:SetPos( pos )
        e:SetAngles( ang )
    end
    e:SetRenderOrigin( pos )
    e:SetRenderAngles( ang )
    if GetConVar( "ph_vm_draw" ):GetBool() then
        e:SetupBones()
    end

    local s = GetConVar( "ph_vm_scale" ):GetFloat()
    if s ~= 1 then
        local sm = Matrix()
        sm:Scale( Vector( s, s, s ) )
        e:EnableMatrix( "RenderMultiply", sm )
    else
        e:DisableMatrix( "RenderMultiply" )
    end

    e:DrawModel()

    e:SetRenderOrigin()
    e:SetRenderAngles()
end

function SWEP:OnRemove()
    if IsValid( self.propEnt ) then self.propEnt:Remove() end
end

---------------------------------------------------------------------------
-- ph_vm_dump: el estado REAL, no el que este archivo cree tener
--
-- Reglas que sigue, y que costaron caro en otros bloques:
--   - imprime CON QUE esta midiendo (el modelo del vm que hay montado, no la
--     constante SWEP.ViewModel de arriba: si algo lo cambio, hay que verlo);
--   - nunca sale mudo: cada linea que puede faltar imprime su ausencia;
--   - no llama a PostDrawViewModel ni a applyHide. Un comando que ejerce la
--     misma llamada que audita mide la llamada, no el resultado;
--   - la resta la hace el comando: la distancia ancla-ojo sale ya calculada.
---------------------------------------------------------------------------
concommand.Add( "ph_vm_dump", function( ply )
    print( "---- ph_vm_dump ----" )

    -- CON QUE se esta midiendo, y que se lea de una. En la ronda 5 la planilla
    -- entera se corrio con el arma del NIVEL 0 en la mano creyendo medir el
    -- nivel 1: el dato estaba en esta linea desde la ronda 1 y no alcanzo con
    -- imprimirlo, porque compite con veinte lineas mas. Un "con que mido" que
    -- no se distingue del resto de la salida no cumple su funcion.
    local wep = ply:GetActiveWeapon()
    local cls = IsValid( wep ) and wep:GetClass() or "NINGUNA"
    print( "arma activa      : " .. cls )
    if cls == "phantasmagoria_camera_test" then
        print( "  >>> NIVEL 0 -- c_medkit prestado + la camara dibujada a mano." )
    elseif cls == "phantasmagoria_camera_vm" then
        print( "  >>> NIVEL 1 -- viewmodel compilado propio." )
    else
        print( "  >>> ninguna de las dos camaras. Nada de lo que sigue mide este prototipo." )
    end

    -- Y si el arma que se buscaba no aparece en el menu, hay que poder separar
    -- "saque la que no era" de "esa clase no existe". Son dos causas distintas
    -- y el sintoma es el mismo: mediste la otra.
    for _, c in ipairs( { "phantasmagoria_camera_test", "phantasmagoria_camera_vm" } ) do
        print( "  clase " .. c .. ": " .. ( weapons.Get( c ) and "registrada" or "NO EXISTE" ) )
    end

    local vm = ply:GetViewModel()
    if not IsValid( vm ) then
        print( "viewmodel        : NO HAY. Todo lo de abajo queda sin medir." )
        return
    end

    print( "viewmodel modelo : " .. tostring( vm:GetModel() ) )
    print( "viewmodel huesos : " .. vm:GetBoneCount() )

    local mats = vm:GetMaterials() or {}
    print( "materiales       : " .. ( #mats > 0 and table.concat( mats, "  " ) or "ninguno" ) )

    -- El c_medkit.mdl de Valve declara la textura 'healthKit01' con cdmaterials
    -- 'models\items\' (leido del binario en garrysmod_dir.vpk). Cualquier otra
    -- cosa significa que un addon monto su propio modelo en esa MISMA ruta y es
    -- ese el que estamos usando. Pasa de verdad: en la ronda 1 habia un mod que
    -- reemplaza el botiquin por el de FEAR, y el prototipo funcionaba igual
    -- porque ese mod conservo el esqueleto - lo cual es suerte, no un contrato.
    -- El aviso depende de QUE viewmodel esta montado, porque los dos niveles
    -- conviven y el mismo dato significa cosas distintas en cada uno. Sin esta
    -- rama, el nivel 1 disparaba "NO es el c_medkit de Valve" -- cierto y
    -- engañoso: claro que no lo es, es el nuestro.
    local vmModel = ( vm:GetModel() or "" ):lower()

    if vmModel:find( "vm_camera", 1, true ) then
        print( "  ^ viewmodel COMPILADO (nivel 1). Su malla es propia." )
        -- El unico dato que dice si $includemodel resolvio: el modelo propio
        -- trae UNA secuencia. Si hay una sola, las animaciones no llegaron.
        local n = vm:GetSequenceCount()
        if n <= 1 then
            print( "    !! $includemodel NO resolvio: " .. n .. " secuencia(s)." )
            print( "       Falta models/weapons/c_medkit.mdl. No va a haber draw ni holster." )
        else
            print( "    $includemodel resolvio: " .. n .. " secuencias, o sea las animaciones" )
            print( "    siguen viniendo de models/weapons/c_medkit.mdl, EN RUNTIME." )
        end
    elseif vmModel:find( "c_medkit", 1, true ) then
        local esValve = ( mats[1] or "" ):lower():find( "healthkit01", 1, true ) ~= nil
        if not esValve then
            print( "  ^ NO es el c_medkit de Valve: otro addon monto models/weapons/c_medkit.mdl." )
            print( "    Todo lo que el nivel 0 asume del modelo hay que releerlo de ESTE." )
        end
    end
    print( "submaterial 0    : '" .. tostring( vm:GetSubMaterial( 0 ) ) .. "'  (vacio = sin override)" )

    local hands = ply:GetHands()
    print( "hands            : " .. ( IsValid( hands ) and tostring( hands:GetModel() ) or "NO HAY (UseHands no monto manos)" ) )

    local n = vm:GetSequenceCount()
    local names = {}
    for i = 0, n - 1 do names[ #names + 1 ] = i .. ":" .. vm:GetSequenceName( i ) end
    print( "secuencias (" .. n .. ")  : " .. table.concat( names, "  " ) )
    print( "sonando ahora    : " .. vm:GetSequenceName( vm:GetSequence() ) .. "  cycle=" .. math.Round( vm:GetCycle(), 2 ) )

    local boneName = GetConVar( "ph_vm_bone" ):GetString()
    local b = vm:LookupBone( boneName )
    if not b then
        print( "ancla '" .. boneName .. "': NO EXISTE en este modelo." )
    else
        vm:SetupBones()
        local m = vm:GetBoneMatrix( b )
        if not m then
            print( "ancla '" .. boneName .. "': indice " .. b .. ", pero GetBoneMatrix devolvio nil." )
        else
            local pos = m:GetTranslation()
            local sc  = m:GetScale()
            print( "ancla            : '" .. boneName .. "' indice " .. b )
            print( "  a " .. math.Round( pos:Distance( ply:EyePos() ), 2 ) .. " u del ojo" )
            print( "  escala de la matriz " .. math.Round( sc.x, 2 ) .. " (0 = colapsado por ph_vm_hide 2)" )
        end
    end

    print( "ph_vm_hide       : " .. GetConVar( "ph_vm_hide" ):GetInt() .. "   (0 nada / 1 submaterial / 2 escala de hueso)" )
    print( "offset           : " .. GetConVar( "ph_vm_x" ):GetFloat() .. " / " .. GetConVar( "ph_vm_y" ):GetFloat() .. " / " .. GetConVar( "ph_vm_z" ):GetFloat()
        .. "   angulo " .. GetConVar( "ph_vm_pitch" ):GetFloat() .. " / " .. GetConVar( "ph_vm_yaw" ):GetFloat() .. " / " .. GetConVar( "ph_vm_roll" ):GetFloat()
        .. "   escala " .. GetConVar( "ph_vm_scale" ):GetFloat() )

    local prop = IsValid( wep ) and wep.propEnt
    print( "prop dibujado    : " .. ( IsValid( prop ) and tostring( prop:GetModel() ) or "todavia no se creo (mira el arma una vez)" ) )
    print( "ph_vm_draw       : " .. GetConVar( "ph_vm_draw" ):GetInt() .. "   (0 = dibujo de la ronda 1, sin SetPos/SetAngles)" )
    print( "--------------------" )
end )

---------------------------------------------------------------------------
-- ph_vm_anim: mide si la animacion CORRE, sin usar GetCycle
--
-- Existe porque en la ronda 1 GetCycle() devolvio 0 en las 40 muestras y en
-- los dos dumps separados por 15 s, mientras el viewmodel se veia animar. Un
-- valor que no se mueve mientras el fenomeno si se mueve no mide el fenomeno:
-- mide el instrumento. Esto mide el hueso, que es lo que la animacion desplaza.
--
-- Imprime la distancia recorrida por muestra. La resta la hace el comando: un
-- criterio que pida comparar tres decimales a ojo invita a un veredicto
-- inferido. La primera muestra imprime -1 para que no se confunda con "quieto".
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- ph_vm_ang: LA medicion de la ronda 3
--
-- Las rondas 1 y 2 dieron el mismo defecto con dos metodos de dibujo distintos
-- (ph_vm_draw 0 y 1), o sea el defecto no esta en como se aplica la pose. Las
-- dos causas que quedan vivas son incompatibles entre si y esto las separa:
--
--   A) el hueso NO rota con el jugador  -> 'dif' se mueve tanto como 'ojo'
--   B) el hueso rota y el prop no lo recibe -> 'dif' constante, 'prop' quieto
--
-- La resta la hace el comando y ya viene normalizada a -180..180: un criterio
-- que pida restar dos yaws a ojo, con el salto de 359 a 0 en el medio, produce
-- un veredicto inventado. GIRAR 180 GRADOS mientras corre, esa es la variable.
---------------------------------------------------------------------------
concommand.Add( "ph_vm_ang", function( ply )
    local wep = ply:GetActiveWeapon()
    if not IsValid( wep ) or wep:GetClass() ~= "phantasmagoria_camera_test" then
        print( "[ph_vm_ang] la camara de prueba no esta en la mano: no hay pose que leer." )
        return
    end

    print( "[ph_vm_ang] GIRA 180 GRADOS mientras corre. 25 muestras cada 0,2 s." )
    print( "  hueso = el yaw que el RENDER de ese frame uso; ojo = el del jugador;" )
    print( "  dif = hueso-ojo normalizada. Si 'dif' se mantiene, el prop acompana el giro." )

    timer.Create( "ph_vm_ang", 0.2, 25, function()
        if not IsValid( wep ) then return end

        -- Nunca imprimir el ultimo valor sin mirar cuando se escribio: si el
        -- render no corrio, ph_vm_ang estaria informando una pose vieja como si
        -- fuera de ahora, que es exactamente el error de la ronda 3.
        if not wep.dbgAt or CurTime() - wep.dbgAt > 0.5 then
            print( "  el render no esta corriendo (arma guardada o prop sin dibujar)" )
            return
        end

        local hy = wep.dbgAng.y
        local oy = ply:EyeAngles().y
        print( string.format( "  hueso %7.1f   ojo %7.1f   dif %7.1f", hy, oy, math.NormalizeAngle( hy - oy ) ) )
    end )
end )

---------------------------------------------------------------------------
-- ph_vm_save: la calibracion, en una linea lista para pegar
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- ph_vm_reset: volver a los defaults del CODIGO, no a los del cfg
--
-- Es el unico modo de ver lo que ve alguien que instala esto por primera vez.
-- Los convars estan archivados, asi que despues de una sesion de calibracion
-- la maquina propia ya no puede distinguir "el default es bueno" de "yo lo dejé
-- bueno a mano y quedo guardado". Sin esto, el default se publica sin probar.
---------------------------------------------------------------------------
concommand.Add( "ph_vm_reset", function()
    local n = { "x", "y", "z", "pitch", "yaw", "roll", "scale", "bone", "hide", "draw" }
    print( "[ph_vm_reset] volviendo a los defaults del codigo:" )
    for _, k in ipairs( n ) do
        local cv = GetConVar( "ph_vm_" .. k )
        local antes = cv:GetString()
        cv:Revert()
        print( string.format( "  ph_vm_%-6s %-26s (estaba en %s)", k, cv:GetString(), antes ) )
    end
end )

concommand.Add( "ph_vm_save", function()
    local n = { "x", "y", "z", "pitch", "yaw", "roll", "scale", "bone", "hide", "draw" }
    local out = {}
    for _, k in ipairs( n ) do
        out[ #out + 1 ] = "ph_vm_" .. k .. " " .. GetConVar( "ph_vm_" .. k ):GetString()
    end
    print( "[ph_vm_save] la pose de ahora, una linea por convar:" )
    print( "  " .. table.concat( out, " ; " ) )
end )

concommand.Add( "ph_vm_anim", function( ply )
    local vm = ply:GetViewModel()
    if not IsValid( vm ) then print( "[ph_vm_anim] no hay viewmodel." ) return end

    local b = vm:LookupBone( GetConVar( "ph_vm_bone" ):GetString() )
    if not b then print( "[ph_vm_anim] el hueso ancla no existe en " .. tostring( vm:GetModel() ) ) return end

    print( "[ph_vm_anim] 30 muestras cada 0,1 s sobre '" .. GetConVar( "ph_vm_bone" ):GetString()
        .. "' de " .. tostring( vm:GetModel() ) .. ". -1 = primera muestra." )

    local prev
    timer.Create( "ph_vm_anim", 0.1, 30, function()
        if not IsValid( vm ) then return end
        vm:SetupBones()
        local m = vm:GetBoneMatrix( b )
        if not m then print( "  matriz nil" ) return end
        local p = m:GetTranslation()
        print( "  " .. ( prev and math.Round( p:Distance( prev ), 3 ) or -1 )
            .. "   seq=" .. vm:GetSequenceName( vm:GetSequence() ) )
        prev = p
    end )
end )
