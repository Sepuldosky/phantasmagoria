--[[-------------------------------------------------------------------------
    Phantasmagoria - Datos fisicos de los props de equipamiento

    POR QUE EXISTE ESTE ARCHIVO
    Los tres packs del Workshop traen masas incompatibles entre si. Medido
    leyendo el bloque KeyValues del .phy de cada modelo:

      phas/eqp_crucifix.phy        "mass" "1.0"     -> totalmass 0.61 kg
      phasmophobia/demit/crucifix   "mass" "1000.0"  -> totalmass 1000 kg

    El Equipment Pack deja mass=1.0 y le deja el calculo a Source (masa =
    volumen x densidad del surfaceprop). El Prop Pack clava el numero a mano:
    medidos los 13 .phy, son SEIS en 1000 (camera_open, crucifix, cursed_book,
    cursed_book_open, emf, uv_torch) y SIETE en 100 (flashlight, motion_sensor,
    salt, salt_b, salt_step, spiritbox, ther_m). El mismo crucifijo pesa 0,6 kg
    en uno y una tonelada en el otro: con 1000 kg no se puede levantar con la
    mano, solo con physgun; con 100 kg tampoco.

    (Este header decia "clavo 1000 en TODOS sus props" y el comentario de la
    tabla, mas abajo, decia "100 o 1000": el archivo se contradecia a si mismo.
    Corregido 2026-08-02 midiendo los 13. La tabla no cambia: fija una masa
    objetivo por modelo, no una correccion uniforme.)

    NO se parchean los .phy: son assets de terceros. La masa se fija en
    runtime con PhysObj:SetMass(), que es reversible y no modifica nada.

    Las masas de abajo son de JUGABILIDAD, no de realismo estricto. Un
    encendedor real pesa 25 g, pero un prop de 0,025 kg en Source sale
    volando con cualquier roce y tiembla apoyado. El piso practico es ~0,2 kg.
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

--[[
    mass        kg. nil = respetar la del modelo (ya es correcta)
    surfaceprop nil = respetar la del modelo
    Las rutas son las reales de montaje, sin la extension.
]]
PHANTASMAGORIA.PropData = {

    -- ============ kiwontatv/ : el K2 ============
    ["models/kiwontatv/ghost_busters/emf_reader_k2.mdl"] = {
        mass = 0.5, surfaceprop = "item",
        skinLevels = 6,   -- SetSkin(0..5) = lectura EMF, acumulativo. Ver docs/EQUIPAMIENTO.md
    },

    -- ============ phas/ : Equipment Props Pack ============
    -- Sus masas ya son razonables; solo se corrigen las que molestan en juego.
    ["models/phas/eqp_lighter.mdl"]      = { mass = 0.2 },  -- venia 0,025: temblaba apoyado
    ["models/phas/eqp_sanity_pills.mdl"] = { mass = 0.2 },  -- venia 0,1
    ["models/phas/eqp_glowstick.mdl"]    = { mass = 0.2, skinLit = 1 }, -- skin 1 = encendida
    ["models/phas/eqp_ghost_book_open.mdl"] = { skinVariants = 7 },     -- 0..6, escritura del fantasma

    -- ============ phasmophobia/demit/ : Prop Pack ============
    -- TODOS venian en 100 o 1000 kg. Se alinean con su equivalente de phas/.
    ["models/phasmophobia/demit/crucifix.mdl"]         = { mass = 0.6, surfaceprop = "item" },
    ["models/phasmophobia/demit/emf.mdl"]              = { mass = 0.5, surfaceprop = "item" },
    ["models/phasmophobia/demit/spiritbox.mdl"]        = { mass = 0.6, surfaceprop = "item" },
    ["models/phasmophobia/demit/ther_m.mdl"]           = { mass = 0.8, surfaceprop = "item" },
    ["models/phasmophobia/demit/uv_torch.mdl"]         = { mass = 0.3, surfaceprop = "item" },
    ["models/phasmophobia/demit/flashlight.mdl"]       = { mass = 0.9, surfaceprop = "item" },
    ["models/phasmophobia/demit/camera_open.mdl"]      = { mass = 3.4, surfaceprop = "item" },
    ["models/phasmophobia/demit/cursed_book.mdl"]      = { mass = 3.4, surfaceprop = "paper" },
    ["models/phasmophobia/demit/cursed_book_open.mdl"] = {
        mass = 7.2, surfaceprop = "paper",
        -- OJO: 8 familias de skin, no 7. La octava (book_cursed_demit) es la
        -- firma del autor del pack: NO entra en el sorteo de escritura.
        skinVariants = 7,
    },
    -- Los cuatro exclusivos de este pack:
    ["models/phasmophobia/demit/motion_sensor.mdl"] = { mass = 0.4, surfaceprop = "item" },
    ["models/phasmophobia/demit/salt.mdl"]          = { mass = 0.3, surfaceprop = "sand" },
    ["models/phasmophobia/demit/salt_b.mdl"]        = { mass = 0.3, surfaceprop = "sand" },
    ["models/phasmophobia/demit/salt_step.mdl"]     = { mass = 0.2, surfaceprop = "sand" },
}

--[[-------------------------------------------------------------------------
    Aplica los datos fisicos a una entidad ya spawneada.
    Llamar desde el Initialize de cada prop, DESPUES de SetModel/PhysicsInit.

    Devuelve true si aplico algo, false si el modelo no esta en la tabla.
---------------------------------------------------------------------------]]
function PHANTASMAGORIA.ApplyPropData( ent )
    if not IsValid( ent ) then return false end

    local data = PHANTASMAGORIA.PropData[ string.lower( ent:GetModel() or "" ) ]
    if not data then return false end

    local phys = ent:GetPhysicsObject()
    if not IsValid( phys ) then return false end

    if data.mass then
        phys:SetMass( data.mass )
    end

    -- PhysObj:SetMaterial cambia el material FISICO (el surfaceprop): decide
    -- friccion, elasticidad y a que suena el objeto al golpear. Es lo que hace
    -- que el crucifijo del Prop Pack deje de sonar a chapa ("metal").
    if data.surfaceprop then
        phys:SetMaterial( data.surfaceprop )
    end

    -- Un objeto dormido conserva el estado viejo hasta que algo lo toca.
    phys:Wake()

    return true
end

--[[-------------------------------------------------------------------------
    Red de seguridad para props spawneados por fuera de nuestras entidades
    (el menu Q de sandbox, un duplicator, otro addon).

    Sin esto, un jugador que saque el crucifijo del Prop Pack desde el spawnmenu
    se lleva la tonelada. Con esto, cualquier prop de la tabla queda corregido
    venga de donde venga.
---------------------------------------------------------------------------]]
--
-- ⚠ Y DICE EL ANTES Y EL DESPUES, que se agrego el 2026-08-08 al ir a
-- verificarlo en juego por primera vez. Este hook se escribio hace rondas y
-- NUNCA CORRIO -- nadie cargaba esta carpeta -- y al escribir la fila del check
-- aparecio que no habia forma de medirlo: "el crucifijo se levanta" es una
-- impresion, y con la tonelada puesta tampoco se levantaba de una manera muy
-- distinta a estar trabado contra algo. Con el par de numeros la fila es binaria
-- y ademas se puede negar: si la linea no sale, el hook no corrio; si sale con
-- `1000 -> 1000`, corrio y no corrigio; si sale con `0.6 -> 0.6`, el prop no era
-- el pesado y la fila midio otro modelo.
--
-- El print vive ACA y no adentro de ApplyPropData a proposito: esta es la red de
-- seguridad del spawnmenu, que se usa de a un prop. ApplyPropData la van a
-- llamar las entidades de equipo desde su Initialize, y ahi una linea por prop
-- seria ruido.
if SERVER then
    hook.Add( "PlayerSpawnedProp", "phantasmagoria_propmass", function( ply, model, ent )
        timer.Simple( 0, function()
            if not IsValid( ent ) then return end

            local phys  = ent:GetPhysicsObject()
            local antes = IsValid( phys ) and phys:GetMass() or nil

            if not PHANTASMAGORIA.ApplyPropData( ent ) then return end

            local despues = IsValid( ent:GetPhysicsObject() ) and ent:GetPhysicsObject():GetMass() or nil

            MsgC( Color( 190, 120, 255 ), "[Phantasmagoria] ", color_white,
                "masa corregida: ", tostring( ent:GetModel() ), "   ",
                antes and string.format( "%.2f", antes ) or "?", " kg -> ",
                despues and string.format( "%.2f", despues ) or "?", " kg\n" )
        end )
    end )
end

return PHANTASMAGORIA.PropData
