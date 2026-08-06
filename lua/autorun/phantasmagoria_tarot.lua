--[[-------------------------------------------------------------------------
    Phantasmagoria - cartas de tarot: el mapa de bodygroups

    PARA QUE SIRVE
    `tarot_cards.mdl` tiene UN bodygroup ("card") con DIEZ opciones. El indice
    de cada opcion es el argumento de SetBodygroup( 0, N ), y sin este archivo
    ese indice es un numero sin significado: no hay forma de saber cual es La
    Torre sin spawnearlas todas y mirarlas.

    DE DONDE SALE EL ORDEN
    Del orden de los `studio` en compile/src/tarot_cards.qc, que a su vez es el
    numero de la malla del juego (Tarot_Card_0 .. Tarot_Card_9). Los nombres se
    leyeron RENDERIZANDO las diez cartas y mirando la etiqueta impresa en cada
    una, no de una lista de internet: las diez mallas tienen la misma geometria
    y se diferencian solo por las UV, asi que el nombre esta en el atlas.

    LO QUE ESTE ARCHIVO NO SABE
    El EFECTO de cada carta. Se busco en el texto autoritativo del juego
    (`localisation`, 2388 IDs): la unica entrada es Journal2_TarotCards_Desc y
    dice "ten random cards that all have different paranormal properties", sin
    enumerarlos. Los efectos son conocimiento del juego que hay que traer de
    otro lado, y ponerlos aca inventados seria peor que no tenerlos.

    ESTE ARCHIVO NO HACE NADA SOLO: define datos y helpers, no engancha nada.
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

PHANTASMAGORIA.TAROT_MODEL = "models/phantasmagoria/tarot_cards.mdl"
PHANTASMAGORIA.TAROT_BACK_MODEL = "models/phantasmagoria/tarot_dud.mdl"

-- El bodygroup se busca POR NOMBRE, igual que el submaterial del espejo: el
-- modelo tiene uno solo y hoy es el 0, pero cablear el 0 se rompe en silencio
-- si alguna vez se le agrega otro bodygroup antes.
PHANTASMAGORIA.TAROT_BODYGROUP_NAME = "card"

--[[
    indice -> nombre. Base CERO, igual que SetBodygroup.
]]
PHANTASMAGORIA.TarotCards = {
    [0] = "The Fool",
    [1] = "The Wheel of Fortune",
    [2] = "The Tower",
    [3] = "The Devil",
    [4] = "Death",
    [5] = "The Hermit",
    [6] = "The Moon",
    [7] = "The Sun",
    [8] = "The High Priestess",
    [9] = "The Hanged Man",
}

-- nombre -> indice, armado del anterior para que no puedan divergir.
PHANTASMAGORIA.TarotIndex = {}
for i, n in pairs( PHANTASMAGORIA.TarotCards ) do
    PHANTASMAGORIA.TarotIndex[ n ] = i
end

--[[
    El indice del bodygroup "card" en ESTA entidad, o nil.
]]
function PHANTASMAGORIA.FindTarotBodygroup( ent )
    if not IsValid( ent ) then return nil end
    for i = 0, ent:GetNumBodyGroups() - 1 do
        if ent:GetBodygroupName( i ) == PHANTASMAGORIA.TAROT_BODYGROUP_NAME then
            return i
        end
    end
    return nil
end

--[[
    Pone una carta por NOMBRE. Devuelve false si el nombre no existe, en vez de
    poner el 0 por defecto: una carta equivocada se ve igual de bien que la
    correcta y no habria como notarlo.
]]
function PHANTASMAGORIA.SetTarotCard( ent, nombre )
    local idx = PHANTASMAGORIA.TarotIndex[ nombre ]
    if not idx then return false end
    local bg = PHANTASMAGORIA.FindTarotBodygroup( ent )
    if not bg then return false end
    ent:SetBodygroup( bg, idx )
    return true, idx
end

function PHANTASMAGORIA.GetTarotCard( ent )
    local bg = PHANTASMAGORIA.FindTarotBodygroup( ent )
    if not bg then return nil end
    local i = ent:GetBodygroup( bg )
    return PHANTASMAGORIA.TarotCards[ i ], i
end

if CLIENT then
    -- phantasmagoria_tarot            -> lista el mapa completo
    -- phantasmagoria_tarot <N|nombre> -> la pone en la carta que se mira
    concommand.Add( "phantasmagoria_tarot", function( ply, _, args )
        if not args[ 1 ] then
            print( "[tarot] bodygroups de " .. PHANTASMAGORIA.TAROT_MODEL )
            for i = 0, 9 do
                print( string.format( "   SetBodygroup(0, %d)  =  %s", i, PHANTASMAGORIA.TarotCards[ i ] ) )
            end
            print( "[tarot] el dorso del mazo es otro modelo: " .. PHANTASMAGORIA.TAROT_BACK_MODEL )
            return
        end
        local ent = ply:GetEyeTrace().Entity
        if not IsValid( ent ) then print( "[tarot] no estas mirando nada" ) return end
        local arg = table.concat( args, " " )
        local n = tonumber( arg )
        local ok, idx
        if n then
            local bg = PHANTASMAGORIA.FindTarotBodygroup( ent )
            if bg then ent:SetBodygroup( bg, n ) ok, idx = true, n end
        else
            ok, idx = PHANTASMAGORIA.SetTarotCard( ent, arg )
        end
        if ok then
            print( string.format( "[tarot] %d = %s", idx, PHANTASMAGORIA.TarotCards[ idx ] or "?" ) )
        else
            print( "[tarot] no se pudo: o la entidad no es el mazo, o el nombre no existe" )
        end
    end )
end
