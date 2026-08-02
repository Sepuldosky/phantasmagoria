--[[-------------------------------------------------------------------------
    Phantasmagoria - Detector de addons duplicados

    Phantasmagoria incluye los assets de tres addons del Workshop (ver
    docs/CREDITOS.md). Si el jugador ademas esta suscrito a alguno de ellos,
    los dos montan exactamente las mismas rutas y GMod elige UNO solo, sin
    decir cual. El sintoma es horrible de diagnosticar: modelos que no
    aparecen, texturas moradas, o -peor- todo funciona y un dia deja de
    funcionar tras una actualizacion del otro addon.

    ESTE ARCHIVO SOLO AVISA. No desmonta, no borra, no bloquea nada.
    Bloquear el addon de otro por despecho esta mal, y ya se vio como termina.
    El jugador decide: se desuscribe, o convive con el aviso y lo silencia.
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

-- Los addons cuyos assets ya vienen incluidos aca.
-- wsid tal cual aparece en la URL del Workshop.
PHANTASMAGORIA.BundledAddons = {
    ["2266583399"] = { name = "K2 Meter | EMF Reader",           paths = { "models/kiwontatv/ghost_busters/emf_reader_k2.mdl" } },
    ["2646265027"] = { name = "Phasmophobia Equipment Props Pack", paths = { "models/phas/eqp_spirit_box.mdl" } },
    ["2639082015"] = { name = "Phasmophobia Prop Pack",           paths = { "models/phasmophobia/demit/spiritbox.mdl" } },
}

local shown = false

local function findDuplicates()
    local hits = {}

    -- engine.GetAddons() lista los addons del Workshop montados en ESTE realm.
    -- Puede no existir en algun contexto raro (dedicado sin workshop): guardar.
    if not engine or not engine.GetAddons then return hits end

    local ok, addons = pcall( engine.GetAddons )
    if not ok or not istable( addons ) then return hits end

    for _, addon in ipairs( addons ) do
        local known = PHANTASMAGORIA.BundledAddons[ tostring( addon.wsid ) ]
        if known and addon.mounted then
            table.insert( hits, {
                wsid  = addon.wsid,
                title = addon.title or known.name,
                known = known,
            } )
        end
    end

    return hits
end

local function report( hits, printer )
    printer( "" )
    printer( "======================================================================" )
    printer( "  PHANTASMAGORIA - addons duplicados detectados (" .. #hits .. ")" )
    printer( "======================================================================" )
    printer( "" )
    printer( "  Estos addons montan las MISMAS rutas que Phantasmagoria, que ya" )
    printer( "  incluye sus assets. Con los dos montados, GMod carga uno solo y" )
    printer( "  no avisa cual:" )
    printer( "" )

    for _, hit in ipairs( hits ) do
        printer( "    - " .. hit.title )
        printer( "      https://steamcommunity.com/sharedfiles/filedetails/?id=" .. hit.wsid )
    end

    printer( "" )
    printer( "  Recomendado: desuscribirse de ellos. Phantasmagoria trae todo lo" )
    printer( "  que necesita y les da credito en docs/CREDITOS.md." )
    printer( "" )
    printer( "  Esto es solo un aviso: no se bloqueo ni se desmonto nada." )
    printer( "  Para silenciarlo: phantasmagoria_assetcheck 0" )
    printer( "======================================================================" )
    printer( "" )
end

if CLIENT then
    CreateClientConVar( "phantasmagoria_assetcheck", "1", true, false,
        "Avisar si hay addons del Workshop que duplican los assets de Phantasmagoria" )

    local function check()
        if shown then return end
        if not GetConVar( "phantasmagoria_assetcheck" ):GetBool() then return end

        local hits = findDuplicates()
        if #hits <= 0 then return end
        shown = true

        report( hits, function( line ) MsgC( Color( 255, 180, 60 ), line .. "\n" ) end )

        -- Y un aviso corto en el chat, porque nadie mira la consola.
        chat.AddText(
            Color( 255, 180, 60 ), "[Phantasmagoria] ",
            Color( 235, 235, 235 ), "Tenes ",
            Color( 255, 120, 120 ), tostring( #hits ),
            Color( 235, 235, 235 ), " addon(s) del Workshop que duplican los assets de este mod. " ..
                "Mira la consola: conviene desuscribirse."
        )
    end

    -- InitPostEntity puede llegar antes de que el chat exista; el timer lo cubre.
    hook.Add( "InitPostEntity", "phantasmagoria_assetcheck", function()
        timer.Simple( 8, check )
    end )
end

if SERVER then
    -- En el servidor el aviso es para el que lo administra: si el server monta
    -- los mismos addons, todos los clientes los descargan al pedo.
    hook.Add( "InitPostEntity", "phantasmagoria_assetcheck", function()
        timer.Simple( 2, function()
            local hits = findDuplicates()
            if #hits <= 0 then return end
            report( hits, function( line ) MsgC( Color( 255, 180, 60 ), line .. "\n" ) end )
        end )
    end )
end

--[[-------------------------------------------------------------------------
    Comando manual, en los dos realms. Sirve para confirmar un diagnostico
    sin reiniciar: si alguien reporta modelos morados, esto lo responde.
---------------------------------------------------------------------------]]
concommand.Add( "phantasmagoria_assetcheck_now", function()
    local hits = findDuplicates()
    if #hits <= 0 then
        MsgC( Color( 120, 235, 120 ), "[Phantasmagoria] Sin duplicados. Los assets salen de este addon.\n" )
        return
    end
    report( hits, function( line ) MsgC( Color( 255, 180, 60 ), line .. "\n" ) end )
end, nil, "Revisa si hay addons del Workshop duplicando los assets de Phantasmagoria" )
