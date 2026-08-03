--[[-------------------------------------------------------------------------
    Phantasmagoria - pantalla dinamica del microfono parabolico (tier 3)

    QUE HACE
    Dibuja en un RenderTarget y lo monta como submaterial de la pantalla del
    modelo paramic3, para que muestre algo vivo en vez de la textura pintada.

    ESTE ARCHIVO NO HACE NADA SOLO. Define una funcion y un concommand de
    prueba; no engancha ningun hook de dibujado ni toca ninguna entidad hasta
    que alguien lo llama. Es deliberado: mientras no se llame, el modelo se ve
    exactamente igual que antes de partirlo en submateriales.

    POR QUE SE PUEDE HACER
    El .mdl trae TRES materiales, porque el SMD sale partido en tres grupos
    (ver dev/phastools/compile/src/paramic3.qc). El corte de la pantalla no se
    eligio a ojo: sale del mapa de emision del juego, que es un rectangulo
    solido de 245x391 texeles, y las 3 caras elegidas cubren el 99.3 % de el.

    EL INDICE, MEDIDO Y NO SUPUESTO
    SetSubMaterial usa indices que arrancan en 0, en el orden en que los
    materiales estan guardados en el .mdl — orden que lo fija studiomdl, no el
    SMD ni la linea de comandos con que se exporto. Leido del binario compilado:

        0 -> paramic3          (cuerpo)
        1 -> paramic3_screen   (pantalla)   <-- este
        2 -> paramic3_glass    (plato parabolico)

    Ojo con el desfasaje de uno: Entity:GetMaterials() devuelve una tabla de
    Lua, que empieza en 1. La pantalla es GetMaterials()[2] y SetSubMaterial(1).
    Se comprueba en juego con el check 02 de dev/checks/paramic-tiers-r1.html.
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

-- Indice del submaterial de la pantalla. NO cambiar sin volver a leer el orden
-- del .mdl: si se recompila el modelo con los grupos en otro orden, esto queda
-- apuntando al cuerpo y el sintoma es que se pinta el prop entero.
PHANTASMAGORIA.PARAMIC_SCREEN_INDEX = 1

local RT_NAME  = "phantasmagoria_paramic_screen"
local RT_SIZE  = 256

local rt, mat

--[[
    El RT y el material se crean UNA vez y se reusan. GetRenderTarget ya
    devuelve el existente si el nombre coincide, pero CreateMaterial no: cada
    llamada con el mismo nombre devuelve el mismo objeto sin recrearlo, asi que
    igual conviene no llamarlo en cada frame.
]]
local function ensure()
    if rt then return end
    rt = GetRenderTarget( RT_NAME, RT_SIZE, RT_SIZE )
    mat = CreateMaterial( RT_NAME .. "_mat", "UnlitGeneric", {
        ["$basetexture"] = RT_NAME,
        -- Sin esto el RT se ve afectado por la luz del mundo y una pantalla
        -- apagada y una encendida quedan iguales en un sotano.
        ["$vertexcolor"] = "1",
        ["$vertexalpha"] = "0",
        ["$nolod"]       = "1",
    } )
    mat:SetTexture( "$basetexture", rt )
end

--[[-------------------------------------------------------------------------
    Redibuja el contenido de la pantalla.

    `drawFn` recibe (w, h) y dibuja con las funciones normales de `surface` /
    `draw`. Si no se pasa ninguna, dibuja un patron de prueba que se mueve, que
    es lo unico que distingue "el RT esta montado" de "el RT esta montado y
    ademas se esta actualizando": una imagen fija podria ser la textura vieja.
---------------------------------------------------------------------------]]
function PHANTASMAGORIA.DrawParamicScreen( drawFn )
    ensure()

    render.PushRenderTarget( rt )
        cam.Start2D()
            render.Clear( 6, 14, 8, 255 )

            if drawFn then
                drawFn( RT_SIZE, RT_SIZE )
            else
                -- Patron de prueba: barra que barre + reloj. Si esto no se
                -- mueve, el RT no se esta redibujando.
                surface.SetDrawColor( 40, 220, 90, 255 )
                local y = ( CurTime() * 60 ) % RT_SIZE
                surface.DrawRect( 0, y, RT_SIZE, 3 )

                draw.SimpleText( "PARABOLIC MIC", "DermaLarge", RT_SIZE * .5, 40,
                    Color( 120, 255, 160 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
                draw.SimpleText( string.format( "%.1f", CurTime() % 1000 ), "DermaLarge",
                    RT_SIZE * .5, RT_SIZE * .5, Color( 200, 255, 210 ),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
            end
        cam.End2D()
    render.PopRenderTarget()
end

--[[-------------------------------------------------------------------------
    Monta el RT en la pantalla de `ent`.

    El "!" del prefijo le dice a Source que el nombre es el de un material ya
    creado en memoria y no una ruta de archivo. Sin el, busca un .vmt en disco,
    no lo encuentra, y el resultado es la textura de error.
---------------------------------------------------------------------------]]
function PHANTASMAGORIA.AttachParamicScreen( ent )
    if not IsValid( ent ) then return false end
    ensure()
    ent:SetSubMaterial( PHANTASMAGORIA.PARAMIC_SCREEN_INDEX, "!" .. RT_NAME .. "_mat" )
    return true
end

-- Devolver la pantalla a la textura pintada del modelo: SetSubMaterial con el
-- indice y SIN segundo argumento limpia el override.
function PHANTASMAGORIA.DetachParamicScreen( ent )
    if not IsValid( ent ) then return false end
    ent:SetSubMaterial( PHANTASMAGORIA.PARAMIC_SCREEN_INDEX )
    return true
end

--[[-------------------------------------------------------------------------
    Prueba manual. Apuntar a un paramic3 spawneado y correr:

        phantasmagoria_paramic_rt

    Vuelve a correrlo apuntando al mismo prop para sacarlo.

    Engancha el redibujado a PreDrawOpaqueRenderables, que corre una vez por
    frame ANTES de dibujar el mundo: dibujar dentro de un RT mientras se esta
    dibujando la escena deja el render target de la escena cambiado a la mitad.
---------------------------------------------------------------------------]]
local attached = nil

concommand.Add( "phantasmagoria_paramic_rt", function()
    local ply = LocalPlayer()
    if not IsValid( ply ) then return end

    local ent = ply:GetEyeTrace().Entity
    if not IsValid( ent ) then
        MsgC( Color( 255, 120, 120 ), "[Phantasmagoria] No estas mirando ninguna entidad.\n" )
        return
    end

    if attached == ent then
        PHANTASMAGORIA.DetachParamicScreen( ent )
        hook.Remove( "PreDrawOpaqueRenderables", "phantasmagoria_paramic_rt" )
        attached = nil
        MsgC( Color( 120, 235, 120 ), "[Phantasmagoria] Pantalla devuelta a la textura del modelo.\n" )
        return
    end

    -- Imprimir CON QUE se esta midiendo, no solo el resultado: si el modelo no
    -- es el que se cree, un "listo" a secas no lo distingue de un exito.
    local mats = ent:GetMaterials() or {}
    MsgC( Color( 235, 235, 235 ), "[Phantasmagoria] modelo = " .. tostring( ent:GetModel() ) .. "\n" )
    for i, m in ipairs( mats ) do
        MsgC( Color( 200, 200, 200 ), string.format(
            "   SetSubMaterial(%d) -> %s%s\n", i - 1, m,
            ( i - 1 ) == PHANTASMAGORIA.PARAMIC_SCREEN_INDEX and "   <-- la pantalla" or "" ) )
    end

    if #mats <= PHANTASMAGORIA.PARAMIC_SCREEN_INDEX then
        MsgC( Color( 255, 120, 120 ),
            "[Phantasmagoria] Este modelo tiene " .. #mats .. " material(es): no esta partido. " ..
            "Es el .mdl viejo, o el corte no se compilo.\n" )
        return
    end

    PHANTASMAGORIA.AttachParamicScreen( ent )
    attached = ent
    hook.Add( "PreDrawOpaqueRenderables", "phantasmagoria_paramic_rt", function()
        if not IsValid( attached ) then
            hook.Remove( "PreDrawOpaqueRenderables", "phantasmagoria_paramic_rt" )
            attached = nil
            return
        end
        PHANTASMAGORIA.DrawParamicScreen()
    end )

    MsgC( Color( 120, 235, 120 ), "[Phantasmagoria] RT montado en el submaterial " ..
        PHANTASMAGORIA.PARAMIC_SCREEN_INDEX .. ". Volve a correrlo apuntando al mismo prop para sacarlo.\n" )
end, nil, "Monta un RenderTarget de prueba en la pantalla del paramic3 que estas mirando" )
