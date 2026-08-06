--[[-------------------------------------------------------------------------
    Phantasmagoria - tabla Ouija: la rotura

    EL PROBLEMA QUE RESUELVE
    `ouija_broken.mdl` tiene las diez piezas de fractura ensambladas EN SU
    LUGAR, y por eso se ve como una tabla entera un poco destenida en vez de
    rota. No es un defecto del port: las piezas estan autoradas TOCANDOSE — su
    bounding box junto da 0.5914 x 0.3908 x 0.0183 m, identico al de la tabla
    intacta hasta el ultimo decimal, que fue justamente la verificacion de que
    el ensamblado quedo bien. Lo que las separa en el juego no es la geometria:
    al romperse, cada pieza recibe un Rigidbody y sale volando.

    Para eso estan los diez ouija_frag1..10.mdl, y esta tabla de offsets, que
    dice donde va cada uno para que juntos reconstruyan la tabla.

    DE DONDE SALEN LOS OFFSETS
    NO son el m_LocalPosition pelado: bl_export.py centra la geometria de cada
    pieza en su propio origen, asi que el offset util es
        (centro de la caja de la pieza en el espacio del padre) - (centro del conjunto)
    calculado sobre los GLB, y pasado a unidades Source con la escala de mundo
    de la tabla (0.0740792 en X/Z de Unity, 0.0815384 en Y) por 39.37.
    Los diez Z dan 0.000 porque la tabla es plana: eso es el control de que la
    conversion de ejes no se mezclo.

    ESTE ARCHIVO NO HACE NADA SOLO: define datos y helpers.
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

PHANTASMAGORIA.OUIJA_MODEL        = "models/phantasmagoria/ouija_board.mdl"
PHANTASMAGORIA.OUIJA_BROKEN_MODEL = "models/phantasmagoria/ouija_broken.mdl"
PHANTASMAGORIA.OUIJA_PLANCHETTE   = "models/phantasmagoria/ouija_planchette.mdl"

--[[
    Los diez fragmentos y su offset respecto del centro de la tabla, en
    unidades Source y en el espacio LOCAL de la tabla (hay que rotarlos por el
    angulo de la tabla antes de sumarlos a su posicion).
]]
PHANTASMAGORIA.OuijaFragments = {
    { model = "models/phantasmagoria/ouija_frag1.mdl",  offset = Vector(  8.382,  2.259, 0 ) },
    { model = "models/phantasmagoria/ouija_frag2.mdl",  offset = Vector(  4.881, -4.920, 0 ) },
    { model = "models/phantasmagoria/ouija_frag3.mdl",  offset = Vector( -5.055, -5.335, 0 ) },
    { model = "models/phantasmagoria/ouija_frag4.mdl",  offset = Vector(  3.762,  5.335, 0 ) },
    { model = "models/phantasmagoria/ouija_frag5.mdl",  offset = Vector( -8.627, -3.331, 0 ) },
    { model = "models/phantasmagoria/ouija_frag6.mdl",  offset = Vector(  2.726,  1.609, 0 ) },
    { model = "models/phantasmagoria/ouija_frag7.mdl",  offset = Vector(  8.627, -5.087, 0 ) },
    { model = "models/phantasmagoria/ouija_frag8.mdl",  offset = Vector(  5.295,  1.991, 0 ) },
    { model = "models/phantasmagoria/ouija_frag9.mdl",  offset = Vector( -6.870,  3.100, 0 ) },
    { model = "models/phantasmagoria/ouija_frag10.mdl", offset = Vector( -0.980, -3.832, 0 ) },
}

if SERVER then
    for _, f in ipairs( PHANTASMAGORIA.OuijaFragments ) do util.PrecacheModel( f.model ) end

    --[[
        Spawnea los diez fragmentos armando la tabla en `pos`/`ang`, y les da un
        empujon desde el centro.

        `fuerza` en unidades de impulso; 0 los deja quietos armados, que es el
        instante justo antes de romperse. Devuelve la lista de entidades.

        El offset se ROTA por `ang` antes de sumarse: guardado esta en el espacio
        local de la tabla. Sumarlo crudo arma la tabla siempre mirando al norte,
        que con la tabla derecha se ve bien y con la tabla girada se ve como si
        los pedazos estuvieran mal medidos.
    ]]
    function PHANTASMAGORIA.ShatterOuija( pos, ang, fuerza )
        ang = ang or Angle( 0, 0, 0 )
        fuerza = fuerza or 0
        -- OJO con el nombre: llamar `ents` a esta tabla TAPA la libreria `ents`
        -- de GMod y ents.Create() deja de existir dentro de la funcion.
        local piezas = {}
        for _, f in ipairs( PHANTASMAGORIA.OuijaFragments ) do
            -- Sin `continue`: GMod lo acepta pero luaparser (Lua estandar) no,
            -- y perder el chequeo de sintaxis fuera del juego cuesta mas que el
            -- idioma. Un if anidado hace lo mismo.
            local e = ents.Create( "prop_physics" )
            if IsValid( e ) then
                e:SetModel( f.model )
                local off = Vector( f.offset )
                off:Rotate( ang )
                e:SetPos( pos + off )
                e:SetAngles( ang )
                e:Spawn()
                e:Activate()
                local phys = e:GetPhysicsObject()
                if IsValid( phys ) and fuerza > 0 then
                    local dir = off:GetNormalized()
                    dir.z = 0.6
                    phys:ApplyForceCenter( dir * fuerza )
                end
                table.insert( piezas, e )
            end
        end
        return piezas
    end
end

if CLIENT then return end

-- phantasmagoria_ouija_romper [fuerza]
-- Rompe la tabla que se esta mirando: la borra y deja los diez pedazos.
concommand.Add( "phantasmagoria_ouija_romper", function( ply, _, args )
    local ent = ply:GetEyeTrace().Entity
    if not IsValid( ent ) then
        ply:PrintMessage( HUD_PRINTCONSOLE, "[ouija] no estas mirando nada\n" )
        return
    end
    local m = ent:GetModel() or ""
    if m ~= PHANTASMAGORIA.OUIJA_MODEL and m ~= PHANTASMAGORIA.OUIJA_BROKEN_MODEL then
        ply:PrintMessage( HUD_PRINTCONSOLE, "[ouija] eso no es la tabla: " .. m .. "\n" )
        return
    end
    local pos, ang = ent:GetPos(), ent:GetAngles()
    ent:Remove()
    local piezas = PHANTASMAGORIA.ShatterOuija( pos, ang, tonumber( args[ 1 ] ) or 300 )
    ply:PrintMessage( HUD_PRINTCONSOLE, "[ouija] " .. #piezas .. " fragmentos\n" )
end )
