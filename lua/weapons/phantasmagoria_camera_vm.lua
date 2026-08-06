--[[-------------------------------------------------------------------------
    Phantasmagoria - Camara de fotos: NIVEL 1, viewmodel COMPILADO

    QUE CAMBIA RESPECTO DE phantasmagoria_camera_test (nivel 0)
    Todo lo que aquel hacia en runtime, este lo trae horneado en el modelo:

      nivel 0                              nivel 1
      ------------------------------------ ---------------------------------
      SWEP.ViewModel = c_medkit prestado   nuestro vm_camera.mdl
      la camara se dibuja a mano en        la camara ES parte del modelo
        PostDrawViewModel, cada frame
      un ClientsideModel que hay que       nada que crear ni limpiar
        crear, posicionar y limpiar
      la malla del botiquin se tapa con    no hay botiquin
        escala de hueso
      la pose vive en diez convars         la pose esta en la geometria
        (x 2 / y 5 / z -2, 0/180/180)

    Este archivo es CIENTO TREINTA lineas mas corto que el del nivel 0 y no
    tiene una sola cuenta de matrices. Todo eso lo hizo mdl2smd.py una vez.

    LO QUE **NO** RESUELVE, y conviene no creerse
    `$includemodel` NO copia las secuencias adentro: las resuelve en RUNTIME.
    Medido: c_arms_stalker.mdl declara $includemodel de c_arms_animations y su
    numseq es 1, no 9. O sea que este modelo SIGUE dependiendo de lo que haya
    montado en models/weapons/c_medkit.mdl -- que es exactamente el archivo que
    un addon del suscriptor puede pisar, y que en esta maquina YA pisa uno.
    Lo que se gano es la MALLA, no las animaciones.

    ESTE SWEP NO REEMPLAZA AL DEL NIVEL 0: convive con el. Los dos se spawnean
    y se comparan lado a lado, que es la unica forma de saber si el modelo
    compilado quedo igual que la pose calibrada o si la horneada corrio algo.
---------------------------------------------------------------------------]]

AddCSLuaFile()

SWEP.Base       = "weapon_base"
SWEP.PrintName  = "NIVEL 1 · camara (viewmodel compilado)"
SWEP.Author     = "Phantasmagoria"
SWEP.Purpose    = "Nivel 1: la camara vive dentro del viewmodel."
SWEP.Category   = "Phantasmagoria"

SWEP.Spawnable      = true
SWEP.AdminOnly      = false
SWEP.DrawAmmo       = false
SWEP.DrawCrosshair  = false

SWEP.ViewModel      = "models/phantasmagoria/vm_camera.mdl"
SWEP.WorldModel     = "models/phas/eqp_digital_camera.mdl"
SWEP.UseHands       = true
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

local SEQ_DRAW    = "anim_draw"
local SEQ_IDLE    = "anim_idle"
local SEQ_HOLSTER = "anim_holster"

-- anim_fire NO se usa: medido en juego, es la animacion de APLICAR un botiquin
-- (baja el objeto y lo sube), que no es el gesto de sacar una foto. Heredarla
-- porque viene gratis seria quedarse con el gesto equivocado.

function SWEP:PlaySeq( name )
    local ply = self:GetOwner()
    if not IsValid( ply ) then return end
    local vm = ply:GetViewModel()
    if not IsValid( vm ) then return end

    local seq = vm:LookupSequence( name )
    if not seq or seq < 0 then
        if not self.warned then
            self.warned = true
            -- Si esto salta, lo mas probable es que $includemodel no haya
            -- resuelto: el modelo propio solo trae 'idle'.
            print( "[phantasmagoria vm1] no existe '" .. name .. "' en " .. tostring( vm:GetModel() )
                .. " -- revisar que models/weapons/c_medkit.mdl este montado" )
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
    return true
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire( CurTime() + 1 )
end

function SWEP:SecondaryAttack()
end

function SWEP:Think()
    if self.IdleAt and CurTime() >= self.IdleAt then
        self.IdleAt = nil
        self:PlaySeq( SEQ_IDLE )
    end
end
