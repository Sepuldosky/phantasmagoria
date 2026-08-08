--[[-------------------------------------------------------------------------
    Phantasmagoria - masa y material de LOS 66 MODELOS PROPIOS de equipamiento

    GENERADO por dev/gen_eq_propdata.py a partir de los .mdl REALES de
    models/phantasmagoria/eq/. Los nombres salen del disco y no de la memoria:
    un inventario escrito a mano es indistinguible de uno completo hasta que
    rompe. Los NUMEROS si son a mano, y estan para que el autor los corrija.

    POR QUE EXISTE, Y MEDIDO ANTES DE ESCRIBIRLO: los 66 .phy de eq/ traen
    TODOS "mass" "1.5" y "surfaceprop" "metal" -- el default del .qc, sin
    ajustar. O sea que hoy la sal, las pastillas y el cuaderno de escritura
    pesan lo mismo y SUENAN A CHAPA. No es la tonelada del Prop Pack ( eso era
    un tercero ): es que nadie les puso todavia el numero.

    ARCHIVO APARTE Y NO ADENTRO DE prop_data.lua, a proposito: ese archivo
    tiene las entradas de los packs de TERCEROS y las va a retirar OTRA sesion
    cuando termine de reemplazar los modelos. Tocar el mismo archivo desde dos
    chats es como este taller ya perdio trabajo una vez. La division es por
    PROCEDENCIA -- lo nuestro aca, lo ajeno alla -- y en runtime se fusionan en
    un solo diccionario, asi que ApplyPropData sigue leyendo un solo lugar.

    ⚠ EL RE-ESCALADO QUE VIENE NO INVALIDA ESTOS NUMEROS, y conviene decirlo
    porque parece que si: el autor va a cambiarle el tamano a los modelos.
    La masa que Source calcula sola SI depende del volumen -- pero
    PhysObj:SetMass() la CLAVA. Esta tabla no se calibra contra el tamano: lo
    reemplaza. Un modelo al doble sigue pesando lo que diga esta linea.

    LOS CRITERIOS, en orden:
      1  si el objeto ya tenia masa decidida en prop_data.lua, se COPIA
      2  si no, el peso del objeto real, con el piso practico de 0,2 kg que
         ese mismo archivo documenta ( por debajo, un prop de Source sale
         volando con cualquier roce y tiembla apoyado )
      3  el surfaceprop es el material DOMINANTE: decide la friccion y a que
         suena al golpear. "metal" en los 66 es lo que hay que sacar.
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

-- Las 20 familias, con sus tiers. La masa es por FAMILIA y no por tier: un
-- tier II no es un objeto mas pesado, es uno mejor. Donde el sufijo cambia de
-- objeto ( el lapiz contra el cuaderno ), la linea lo dice.
PHANTASMAGORIA.PropDataEq = {

    -- crucifix -- copiado de prop_data.lua ( demit/crucifix )
    ["models/phantasmagoria/eq/crucifix_i.mdl"]                = { mass = 0.6, surfaceprop = "item" },
    ["models/phantasmagoria/eq/crucifix_ii.mdl"]               = { mass = 0.6, surfaceprop = "metal" },  -- CORRECCION DEL AUTOR ( r15b ): el tier II es metalico
    ["models/phantasmagoria/eq/crucifix_iii.mdl"]              = { mass = 0.6, surfaceprop = "metal" },  -- CORRECCION DEL AUTOR ( r15b ): el tier III es metalico

    -- dots -- proyector chico sobre base
    ["models/phantasmagoria/eq/dots_i.mdl"]                    = { mass = 0.9, surfaceprop = "item" },
    ["models/phantasmagoria/eq/dots_ii.mdl"]                   = { mass = 0.9, surfaceprop = "item" },
    ["models/phantasmagoria/eq/dots_iii.mdl"]                  = { mass = 0.9, surfaceprop = "item" },

    -- emf_reader -- copiado de prop_data.lua ( el K2 de kiwontatv )
    ["models/phantasmagoria/eq/emf_reader_i.mdl"]              = { mass = 0.5, surfaceprop = "item" },
    ["models/phantasmagoria/eq/emf_reader_ii.mdl"]             = { mass = 0.5, surfaceprop = "item" },
    ["models/phantasmagoria/eq/emf_reader_iii.mdl"]            = { mass = 0.5, surfaceprop = "item" },

    -- firelight -- vela / encendedor: liviano pero por encima del piso
    ["models/phantasmagoria/eq/firelight_i.mdl"]               = { mass = 0.3, surfaceprop = "item" },
    ["models/phantasmagoria/eq/firelight_ii.mdl"]              = { mass = 0.3, surfaceprop = "item" },
    ["models/phantasmagoria/eq/firelight_iii.mdl"]             = { mass = 0.3, surfaceprop = "item" },

    -- flashlight -- copiado de prop_data.lua ( demit/flashlight )
    ["models/phantasmagoria/eq/flashlight_i.mdl"]              = { mass = 0.9, surfaceprop = "item" },
    ["models/phantasmagoria/eq/flashlight_ii.mdl"]             = { mass = 0.9, surfaceprop = "item" },
    ["models/phantasmagoria/eq/flashlight_iii.mdl"]            = { mass = 0.9, surfaceprop = "item" },

    -- ghost_writing -- cuaderno; los lapices se pisan abajo
    ["models/phantasmagoria/eq/ghost_writing_i_closed.mdl"]    = { mass = 0.8, surfaceprop = "paper" },
    ["models/phantasmagoria/eq/ghost_writing_i_open.mdl"]      = { mass = 0.8, surfaceprop = "paper" },
    ["models/phantasmagoria/eq/ghost_writing_i_pencil.mdl"]    = { mass = 0.2, surfaceprop = "wood" },  -- es un lapiz, no el cuaderno
    ["models/phantasmagoria/eq/ghost_writing_ii_closed.mdl"]   = { mass = 0.8, surfaceprop = "paper" },
    ["models/phantasmagoria/eq/ghost_writing_ii_open.mdl"]     = { mass = 0.8, surfaceprop = "paper" },
    ["models/phantasmagoria/eq/ghost_writing_ii_pen.mdl"]      = { mass = 0.2, surfaceprop = "item" },  -- es una lapicera, no el cuaderno
    ["models/phantasmagoria/eq/ghost_writing_iii_book.mdl"]    = { mass = 0.8, surfaceprop = "paper" },
    ["models/phantasmagoria/eq/ghost_writing_iii_pen.mdl"]     = { mass = 0.2, surfaceprop = "item" },  -- es una lapicera, no el cuaderno

    -- head_mounted -- camara de cabeza, plastico chico
    ["models/phantasmagoria/eq/head_mounted_camera.mdl"]       = { mass = 0.4, surfaceprop = "item" },
    ["models/phantasmagoria/eq/head_mounted_ii.mdl"]           = { mass = 0.4, surfaceprop = "item" },
    ["models/phantasmagoria/eq/head_mounted_iii.mdl"]          = { mass = 0.4, surfaceprop = "item" },

    -- igniter -- copiado de prop_data.lua ( phas/eqp_lighter ): el piso
    ["models/phantasmagoria/eq/igniter_i.mdl"]                 = { mass = 0.2, surfaceprop = "item" },
    ["models/phantasmagoria/eq/igniter_ii.mdl"]                = { mass = 0.2, surfaceprop = "item" },
    ["models/phantasmagoria/eq/igniter_iii.mdl"]               = { mass = 0.2, surfaceprop = "item" },

    -- motion_sensor -- copiado de prop_data.lua ( demit/motion_sensor )
    ["models/phantasmagoria/eq/motion_sensor_i.mdl"]           = { mass = 0.4, surfaceprop = "item" },
    ["models/phantasmagoria/eq/motion_sensor_ii.mdl"]          = { mass = 0.4, surfaceprop = "item" },
    ["models/phantasmagoria/eq/motion_sensor_iii.mdl"]         = { mass = 0.4, surfaceprop = "item" },

    -- photo_camera -- camara de fotos de mano
    ["models/phantasmagoria/eq/photo_camera_i.mdl"]            = { mass = 0.7, surfaceprop = "item" },
    ["models/phantasmagoria/eq/photo_camera_ii.mdl"]           = { mass = 0.7, surfaceprop = "item" },
    ["models/phantasmagoria/eq/photo_camera_iii.mdl"]          = { mass = 0.7, surfaceprop = "item" },

    -- repellent -- manojo de ramas atado: suena a madera, no a chapa
    ["models/phantasmagoria/eq/repellent_i.mdl"]               = { mass = 0.2, surfaceprop = "wood" },
    ["models/phantasmagoria/eq/repellent_ii.mdl"]              = { mass = 0.2, surfaceprop = "wood" },
    ["models/phantasmagoria/eq/repellent_iii_hanging.mdl"]     = { mass = 0.2, surfaceprop = "wood" },
    ["models/phantasmagoria/eq/repellent_iii_wrapped.mdl"]     = { mass = 0.2, surfaceprop = "wood" },

    -- salt -- copiado de prop_data.lua ( demit/salt )
    ["models/phantasmagoria/eq/salt_i.mdl"]                    = { mass = 0.3, surfaceprop = "sand" },
    ["models/phantasmagoria/eq/salt_ii.mdl"]                   = { mass = 0.3, surfaceprop = "sand" },
    ["models/phantasmagoria/eq/salt_iii.mdl"]                  = { mass = 0.3, surfaceprop = "sand" },

    -- sanity_medication -- copiado de prop_data.lua ( phas/eqp_sanity_pills )
    ["models/phantasmagoria/eq/sanity_medication_i.mdl"]       = { mass = 0.2, surfaceprop = "item" },
    ["models/phantasmagoria/eq/sanity_medication_ii.mdl"]      = { mass = 0.2, surfaceprop = "item" },
    ["models/phantasmagoria/eq/sanity_medication_iii.mdl"]     = { mass = 0.2, surfaceprop = "item" },

    -- sound_recorder -- grabadora de mano
    ["models/phantasmagoria/eq/sound_recorder_i.mdl"]          = { mass = 0.3, surfaceprop = "item" },
    ["models/phantasmagoria/eq/sound_recorder_ii.mdl"]         = { mass = 0.3, surfaceprop = "item" },
    ["models/phantasmagoria/eq/sound_recorder_iii.mdl"]        = { mass = 0.3, surfaceprop = "item" },

    -- sound_sensor -- sensor con base, del tamano del motion
    ["models/phantasmagoria/eq/sound_sensor_i.mdl"]            = { mass = 0.5, surfaceprop = "item" },
    ["models/phantasmagoria/eq/sound_sensor_ii.mdl"]           = { mass = 0.5, surfaceprop = "item" },
    ["models/phantasmagoria/eq/sound_sensor_iii.mdl"]          = { mass = 0.5, surfaceprop = "item" },

    -- spiritbox -- copiado de prop_data.lua ( demit/spiritbox )
    ["models/phantasmagoria/eq/spiritbox_i.mdl"]               = { mass = 0.6, surfaceprop = "item" },
    ["models/phantasmagoria/eq/spiritbox_ii.mdl"]              = { mass = 0.6, surfaceprop = "item" },
    ["models/phantasmagoria/eq/spiritbox_iii.mdl"]             = { mass = 0.6, surfaceprop = "item" },

    -- thermometer -- copiado de prop_data.lua ( demit/ther_m )
    ["models/phantasmagoria/eq/thermometer_i.mdl"]             = { mass = 0.8, surfaceprop = "item" },
    ["models/phantasmagoria/eq/thermometer_ii.mdl"]            = { mass = 0.8, surfaceprop = "item" },
    ["models/phantasmagoria/eq/thermometer_iii.mdl"]           = { mass = 0.8, surfaceprop = "item" },

    -- tripod -- el UNICO que si es metal de verdad, y el mas pesado
    ["models/phantasmagoria/eq/tripod_i.mdl"]                  = { mass = 2.0, surfaceprop = "metal" },
    ["models/phantasmagoria/eq/tripod_ii.mdl"]                 = { mass = 2.0, surfaceprop = "metal" },
    ["models/phantasmagoria/eq/tripod_iii.mdl"]                = { mass = 2.0, surfaceprop = "metal" },

    -- uv_light -- copiado de prop_data.lua ( demit/uv_torch )
    ["models/phantasmagoria/eq/uv_light_i.mdl"]                = { mass = 0.3, surfaceprop = "item" },
    ["models/phantasmagoria/eq/uv_light_ii.mdl"]               = { mass = 0.3, surfaceprop = "item" },
    ["models/phantasmagoria/eq/uv_light_iii.mdl"]              = { mass = 0.3, surfaceprop = "item" },

    -- video_camera -- camara de video con bateria
    ["models/phantasmagoria/eq/video_camera_i.mdl"]            = { mass = 1.2, surfaceprop = "item" },
    ["models/phantasmagoria/eq/video_camera_ii.mdl"]           = { mass = 1.2, surfaceprop = "item" },
    ["models/phantasmagoria/eq/video_camera_iii.mdl"]          = { mass = 1.2, surfaceprop = "item" },
}

---------------------------------------------------------------------------
-- La fusion, que GRITA en vez de pisar
---------------------------------------------------------------------------
-- Hoy no hay solape posible -- las rutas son models/phantasmagoria/eq/ contra
-- models/phas/ y models/phasmophobia/demit/ --, pero la otra sesion esta
-- editando esa tabla ahora mismo. Si algun dia una ruta cae en las dos, el
-- que gana tiene que ser una decision y no el orden de carga.
PHANTASMAGORIA.PropData = PHANTASMAGORIA.PropData or {}

for ruta, data in pairs( PHANTASMAGORIA.PropDataEq ) do
    if PHANTASMAGORIA.PropData[ ruta ] then
        ErrorNoHalt( "[Phantasmagoria] la ruta " .. ruta .. " esta en prop_data.lua Y en " ..
            "prop_data_eq.lua. Gana la de eq ( la nuestra ), pero eso es una colision " ..
            "y hay que sacar una de las dos.\n" )

    end

    PHANTASMAGORIA.PropData[ ruta ] = data

end

return PHANTASMAGORIA.PropDataEq
