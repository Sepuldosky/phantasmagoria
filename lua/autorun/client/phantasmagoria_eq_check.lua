--[[-------------------------------------------------------------------------
    Phantasmagoria - VERIFICACION EN JUEGO del lote de equipamiento

    GENERADO por dev/phastools/eqpcheck_gen.py a partir del arbol INSTALADO.
    No editar a mano: las listas son el inventario real de
    phantasmagoria/models/phantasmagoria/eq y su carpeta de materiales, y si se tipean
    a mano pueden quedar mas cortas que el arbol sin que nada lo note.

    QUE MIDE, Y QUE NO
    Mide que el motor encuentre y acepte lo que se instalo. NO mide que se vea
    bien: eso lo contesta mirar, y va en los checks visuales de la planilla.

    CADA BARRIDO LLEVA SU CONTROL NEGATIVO
    Un barrido que devuelve "65/65 OK" no distingue "estan todos" de
    "la funcion dice que si siempre". Por eso cada comando corre ademas una
    ruta deliberadamente inexistente y publica su resultado. Si el control
    negativo no falla, el resultado del barrido NO VALE y el check va SIN
    CORRER, no PASA.

    TRAMPAS DE GMOD QUE ESTE ARCHIVO ESQUIVA A PROPOSITO
      - PrintMessage(HUD_PRINTCONSOLE) tiene techo de 255 bytes y NO trunca:
        DESCARTA la linea entera. Aca se usa MsgN, que no lo tiene.
      - IMaterial:GetString() sobre una clave que el material NO define devuelve
        CERO VALORES, no nil, y tostring() revienta con "value expected". Se
        envuelve en select("#", ...) antes de tocarlo.
      - `local ents` taparia la libreria ents de GMod. Ningun local se llama asi.
---------------------------------------------------------------------------]]

if not CLIENT then return end

local MODELOS = {
  "crucifix_i",
  "crucifix_ii",
  "crucifix_iii",
  "dots_i",
  "dots_ii",
  "dots_iii",
  "emf_reader_i",
  "emf_reader_ii",
  "emf_reader_iii",
  "firelight_i",
  "firelight_ii",
  "firelight_iii",
  "flashlight_i",
  "flashlight_ii",
  "flashlight_iii",
  "ghost_writing_i_closed",
  "ghost_writing_i_open",
  "ghost_writing_i_pencil",
  "ghost_writing_ii_closed",
  "ghost_writing_ii_open",
  "ghost_writing_ii_pen",
  "ghost_writing_iii_book",
  "ghost_writing_iii_pen",
  "head_mounted_camera",
  "head_mounted_ii",
  "head_mounted_iii",
  "igniter_i",
  "igniter_ii",
  "igniter_iii",
  "motion_sensor_i",
  "motion_sensor_ii",
  "motion_sensor_iii",
  "photo_camera_i",
  "photo_camera_ii",
  "photo_camera_iii",
  "repellent_i",
  "repellent_ii",
  "repellent_iii",
  "salt_i",
  "salt_ii",
  "salt_iii",
  "sanity_medication_i",
  "sanity_medication_ii",
  "sanity_medication_iii",
  "sound_recorder_i",
  "sound_recorder_ii",
  "sound_recorder_iii",
  "sound_sensor_i",
  "sound_sensor_ii",
  "sound_sensor_iii",
  "spiritbox_i",
  "spiritbox_ii",
  "spiritbox_iii",
  "thermometer_i",
  "thermometer_ii",
  "thermometer_iii",
  "tripod_i",
  "tripod_ii",
  "tripod_iii",
  "uv_light_i",
  "uv_light_ii",
  "uv_light_iii",
  "video_camera_i",
  "video_camera_ii",
  "video_camera_iii",
}

local MATERIALES = {
  "crucifix_i_0",
  "crucifix_i_1",
  "crucifix_i_2",
  "crucifix_ii_0",
  "crucifix_ii_1",
  "crucifix_ii_2",
  "crucifix_ii_3",
  "crucifix_iii_0",
  "crucifix_iii_1",
  "crucifix_iii_2",
  "crucifix_iii_3",
  "dots_i_0",
  "dots_i_1",
  "dots_ii_0",
  "dots_ii_1",
  "dots_iii_0",
  "dots_iii_1",
  "dots_iii_2",
  "emf_reader_i_0",
  "emf_reader_i_1",
  "emf_reader_i_2",
  "emf_reader_i_3",
  "emf_reader_ii_0",
  "emf_reader_iii_0",
  "firelight_i_0",
  "firelight_i_1",
  "firelight_i_2",
  "firelight_ii_0",
  "firelight_ii_1",
  "firelight_ii_2",
  "firelight_iii_0",
  "firelight_iii_1",
  "firelight_iii_2",
  "firelight_iii_3",
  "firelight_iii_4",
  "firelight_iii_5",
  "firelight_iii_6",
  "firelight_iii_7",
  "firelight_iii_8",
  "flashlight_i_0",
  "flashlight_i_1",
  "flashlight_i_2",
  "flashlight_i_3",
  "flashlight_ii_0",
  "flashlight_ii_1",
  "flashlight_iii_0",
  "flashlight_iii_1",
  "ghost_writing_i_0",
  "ghost_writing_i_1",
  "ghost_writing_i_2",
  "ghost_writing_i_3",
  "ghost_writing_i_open_w1",
  "ghost_writing_i_open_w2",
  "ghost_writing_i_open_w3",
  "ghost_writing_ii_0",
  "ghost_writing_ii_1",
  "ghost_writing_ii_2",
  "ghost_writing_ii_3",
  "ghost_writing_ii_open_w1",
  "ghost_writing_ii_open_w2",
  "ghost_writing_ii_open_w3",
  "ghost_writing_ii_open_w4",
  "ghost_writing_ii_open_w5",
  "ghost_writing_ii_open_w6",
  "ghost_writing_ii_open_w7",
  "ghost_writing_iii_0",
  "ghost_writing_iii_1",
  "ghost_writing_iii_2",
  "ghost_writing_iii_3",
  "ghost_writing_iii_book_w1",
  "ghost_writing_iii_book_w2",
  "ghost_writing_iii_book_w3",
  "head_mounted_camera_0",
  "head_mounted_camera_1",
  "head_mounted_camera_2",
  "head_mounted_ii_0",
  "head_mounted_ii_1",
  "head_mounted_ii_2",
  "head_mounted_ii_3",
  "head_mounted_iii_0",
  "head_mounted_iii_1",
  "head_mounted_iii_2",
  "head_mounted_iii_3",
  "igniter_i_0",
  "igniter_i_1",
  "igniter_i_2",
  "igniter_i_3",
  "igniter_i_4",
  "igniter_i_5",
  "igniter_ii_0",
  "igniter_ii_1",
  "igniter_ii_2",
  "igniter_ii_3",
  "igniter_iii_0",
  "igniter_iii_1",
  "igniter_iii_2",
  "igniter_iii_3",
  "igniter_iii_4",
  "igniter_iii_5",
  "igniter_iii_6",
  "motion_sensor_i_0",
  "motion_sensor_i_1",
  "motion_sensor_i_2",
  "motion_sensor_ii_0",
  "motion_sensor_ii_1",
  "motion_sensor_ii_2",
  "motion_sensor_iii_0",
  "motion_sensor_iii_1",
  "motion_sensor_iii_2",
  "motion_sensor_iii_3",
  "photo_camera_i_0",
  "photo_camera_i_1",
  "photo_camera_i_2",
  "photo_camera_i_3",
  "photo_camera_i_4",
  "photo_camera_ii_0",
  "photo_camera_ii_1",
  "photo_camera_ii_2",
  "photo_camera_iii_0",
  "photo_camera_iii_1",
  "photo_camera_iii_2",
  "photo_camera_iii_3",
  "repellent_i_0",
  "repellent_i_1",
  "repellent_ii_0",
  "repellent_ii_1",
  "repellent_iii_0",
  "repellent_iii_1",
  "repellent_iii_2",
  "repellent_iii_3",
  "salt_i_0",
  "salt_ii_0",
  "salt_ii_1",
  "salt_ii_2",
  "salt_ii_3",
  "salt_ii_4",
  "salt_iii_0",
  "salt_iii_1",
  "salt_iii_2",
  "salt_iii_3",
  "salt_iii_4",
  "salt_iii_5",
  "salt_iii_6",
  "salt_iii_7",
  "sanity_medication_i_0",
  "sanity_medication_i_1",
  "sanity_medication_i_2",
  "sanity_medication_ii_0",
  "sanity_medication_ii_1",
  "sanity_medication_ii_2",
  "sanity_medication_ii_3",
  "sanity_medication_iii_0",
  "sanity_medication_iii_1",
  "sound_recorder_i_0",
  "sound_recorder_i_1",
  "sound_recorder_i_10",
  "sound_recorder_i_11",
  "sound_recorder_i_12",
  "sound_recorder_i_13",
  "sound_recorder_i_14",
  "sound_recorder_i_15",
  "sound_recorder_i_16",
  "sound_recorder_i_2",
  "sound_recorder_i_3",
  "sound_recorder_i_4",
  "sound_recorder_i_5",
  "sound_recorder_i_6",
  "sound_recorder_i_7",
  "sound_recorder_i_8",
  "sound_recorder_i_9",
  "sound_recorder_ii_0",
  "sound_recorder_ii_1",
  "sound_recorder_ii_2",
  "sound_recorder_iii_0",
  "sound_recorder_iii_1",
  "sound_recorder_iii_2",
  "sound_recorder_iii_3",
  "sound_recorder_iii_4",
  "sound_recorder_iii_5",
  "sound_recorder_iii_6",
  "sound_sensor_i_0",
  "sound_sensor_i_1",
  "sound_sensor_i_2",
  "sound_sensor_i_3",
  "sound_sensor_ii_0",
  "sound_sensor_ii_1",
  "sound_sensor_ii_2",
  "sound_sensor_ii_3",
  "sound_sensor_ii_4",
  "sound_sensor_iii_0",
  "sound_sensor_iii_1",
  "sound_sensor_iii_10",
  "sound_sensor_iii_11",
  "sound_sensor_iii_12",
  "sound_sensor_iii_13",
  "sound_sensor_iii_14",
  "sound_sensor_iii_15",
  "sound_sensor_iii_16",
  "sound_sensor_iii_17",
  "sound_sensor_iii_18",
  "sound_sensor_iii_2",
  "sound_sensor_iii_3",
  "sound_sensor_iii_4",
  "sound_sensor_iii_5",
  "sound_sensor_iii_6",
  "sound_sensor_iii_7",
  "sound_sensor_iii_8",
  "sound_sensor_iii_9",
  "spiritbox_i_0",
  "spiritbox_i_1",
  "spiritbox_i_2",
  "spiritbox_i_3",
  "spiritbox_i_4",
  "spiritbox_i_5",
  "spiritbox_i_6",
  "spiritbox_ii_0",
  "spiritbox_iii_0",
  "thermometer_i_0",
  "thermometer_i_1",
  "thermometer_i_2",
  "thermometer_ii_0",
  "thermometer_iii_0",
  "tripod_i_0",
  "tripod_i_1",
  "tripod_i_10",
  "tripod_i_11",
  "tripod_i_12",
  "tripod_i_13",
  "tripod_i_2",
  "tripod_i_3",
  "tripod_i_4",
  "tripod_i_5",
  "tripod_i_6",
  "tripod_i_7",
  "tripod_i_8",
  "tripod_i_9",
  "tripod_ii_0",
  "tripod_ii_1",
  "tripod_ii_10",
  "tripod_ii_11",
  "tripod_ii_12",
  "tripod_ii_13",
  "tripod_ii_14",
  "tripod_ii_15",
  "tripod_ii_16",
  "tripod_ii_2",
  "tripod_ii_3",
  "tripod_ii_4",
  "tripod_ii_5",
  "tripod_ii_6",
  "tripod_ii_7",
  "tripod_ii_8",
  "tripod_ii_9",
  "tripod_iii_0",
  "tripod_iii_1",
  "tripod_iii_10",
  "tripod_iii_11",
  "tripod_iii_12",
  "tripod_iii_13",
  "tripod_iii_14",
  "tripod_iii_15",
  "tripod_iii_16",
  "tripod_iii_17",
  "tripod_iii_18",
  "tripod_iii_19",
  "tripod_iii_2",
  "tripod_iii_20",
  "tripod_iii_3",
  "tripod_iii_4",
  "tripod_iii_5",
  "tripod_iii_6",
  "tripod_iii_7",
  "tripod_iii_8",
  "tripod_iii_9",
  "uv_light_i_0",
  "uv_light_ii_0",
  "uv_light_ii_1",
  "uv_light_iii_0",
  "uv_light_iii_1",
  "video_camera_i_0",
  "video_camera_i_1",
  "video_camera_i_2",
  "video_camera_i_3",
  "video_camera_ii_0",
  "video_camera_ii_1",
  "video_camera_ii_2",
  "video_camera_ii_3",
  "video_camera_iii_0",
  "video_camera_iii_1",
  "video_camera_iii_2",
  "video_camera_iii_3",
}

-- Los que no tienen textura en Unity y quedaron con _white: pantallas
-- (Camera Render / Animated Screen / Screen), vidrios y liquidos (Lighter
-- Liquid, Sanity Bottle Liquid, Thermo level 1 Liquid, Glowstick Liquid,
-- Camcorder Glass, Lantern 3b Glass) y llamas.
local BLANCOS = {
  "crucifix_i_2",
  "crucifix_ii_3",
  "crucifix_iii_3",
  "dots_i_1",
  "firelight_i_2",
  "firelight_ii_2",
  "firelight_iii_6",
  "ghost_writing_i_3",
  "head_mounted_camera_2",
  "igniter_i_5",
  "igniter_ii_1",
  "igniter_ii_3",
  "igniter_iii_6",
  "motion_sensor_i_2",
  "motion_sensor_ii_2",
  "photo_camera_i_4",
  "photo_camera_ii_1",
  "photo_camera_ii_2",
  "photo_camera_iii_1",
  "photo_camera_iii_2",
  "sanity_medication_i_2",
  "thermometer_i_2",
  "uv_light_ii_1",
  "video_camera_i_3",
  "video_camera_ii_3",
  "video_camera_iii_3",
}

-- Tamano mayor esperado, en unidades Source, MEDIDO por el lado de Unity
-- (dev/phastools/eqpsize.py, ruta de vertices del GLB). No sale del .mdl.
-- Se eligen los extremos del lote a proposito: si el lector devolviera una
-- constante, dos objetos que difieren varias veces en tamano lo delatan.
local ESCALA = {
  { "eqp_igniter_iii", 2.97 },
  { "eqp_repellent_ii", 8.44 },
  { "eqp_tripod_ii", 41.49 },
}

-- rutas que NO existen: el control negativo de cada barrido
local MODELO_FALSO = "models/phantasmagoria/eq/no_existe_este_modelo.mdl"
local MATERIAL_FALSO = "models/phantasmagoria/eq/no_existe_este_material"

-- Un modelo de cada pack de terceros ya montado. Si alguno de estos dejara de
-- resolver, dos addons estan pisando la misma ruta.
local TERCEROS = {
  { "phas",      "models/phas/eqp_spirit_box.mdl" },
  { "kiwontatv", "models/kiwontatv/ghost_busters/emf_reader_k2.mdl" },
  { "propio",    "models/phantasmagoria/paramic3.mdl" },
}

local function linea(...)
  MsgN(...)
end

-- GetString sobre una clave ausente devuelve CERO VALORES. Esto lo convierte
-- en nil sin reventar, que es lo que uno creia que hacia de entrada.
local function clave(mat, k)
  local n = select("#", mat:GetString(k))
  if n == 0 then return nil end
  return (mat:GetString(k))
end

concommand.Add("ph_eq_modelos", function()
  linea("=== eq: MODELOS (" .. #MODELOS .. " esperados)")
  local ok, malos = 0, {}
  for _, m in ipairs(MODELOS) do
    local ruta = "models/phantasmagoria/eq/" .. m .. ".mdl"
    if util.IsValidModel(ruta) then
      ok = ok + 1
    else
      malos[#malos + 1] = m
    end
  end
  linea(("  validos: %d de %d"):format(ok, #MODELOS))
  for _, m in ipairs(malos) do linea("    NO VALIDO: " .. m) end
  local ctrl = util.IsValidModel(MODELO_FALSO)
  linea("  CONTROL NEGATIVO (" .. MODELO_FALSO .. "): " ..
        (ctrl and "DEVOLVIO TRUE -> el barrido NO MIDE NADA" or "false, correcto"))
end)

concommand.Add("ph_eq_materiales", function()
  linea("=== eq: MATERIALES (" .. #MATERIALES .. " esperados)")
  local ok, malos = 0, {}
  for _, m in ipairs(MATERIALES) do
    local mat = Material("models/phantasmagoria/eq/" .. m)
    if mat and not mat:IsError() then
      ok = ok + 1
    else
      malos[#malos + 1] = m
    end
  end
  linea(("  resuelven: %d de %d"):format(ok, #MATERIALES))
  for _, m in ipairs(malos) do linea("    DAMERO DE ERROR: " .. m) end
  local cm = Material(MATERIAL_FALSO)
  local ctrl = cm and cm:IsError()
  linea("  CONTROL NEGATIVO (" .. MATERIAL_FALSO .. "): " ..
        (ctrl and "IsError()=true, correcto" or
         "IsError()=false -> el barrido NO MIDE NADA"))
end)

concommand.Add("ph_eq_blancos", function()
  linea("=== eq: los " .. #BLANCOS .. " sin textura en Unity")
  linea("  (pantallas / vidrios y liquidos / llamas: su contenido NO es una textura)")
  for _, m in ipairs(BLANCOS) do
    local mat = Material("models/phantasmagoria/eq/" .. m)
    local bt = clave(mat, "$basetexture") or "(no declara)"
    local c2 = clave(mat, "$color2") or "(sin $color2)"
    linea(("  %-34s base=%-28s color2=%s"):format(m, bt, c2))
  end
end)

concommand.Add("ph_eq_rutas", function()
  linea("=== eq: DE DONDE sale cada archivo")
  linea("  Un error en juego que contradice al codigo suele ser dos addons")
  linea("  montando la misma ruta. Esto imprime el tamano del archivo que el")
  linea("  motor ENTREGA, que es el unico que importa.")
  local muestra = { MODELOS[1], MODELOS[math.floor(#MODELOS / 2)], MODELOS[#MODELOS] }
  for _, m in ipairs(muestra) do
    local ruta = "models/phantasmagoria/eq/" .. m .. ".mdl"
    linea(("  %-46s %s bytes"):format(ruta, tostring(file.Size(ruta, "GAME"))))
  end
  linea("  --- packs de terceros (tienen que seguir resolviendo) ---")
  for _, t in ipairs(TERCEROS) do
    linea(("  %-10s %-52s %s bytes"):format(t[1], t[2], tostring(file.Size(t[2], "GAME"))))
  end
  linea("  --- un VMT leido como ARCHIVO, que dice CUAL monto el juego ---")
  local vmt = file.Read("materials/models/phantasmagoria/eq/" .. MATERIALES[1] .. ".vmt", "GAME")
  linea("  " .. MATERIALES[1] .. ".vmt:")
  if vmt then
    for l in string.gmatch(vmt, "[^\r\n]+") do linea("    " .. l) end
  else
    linea("    NO SE PUDO LEER -> no esta montado donde el .mdl lo busca")
  end
end)

concommand.Add("ph_eq_escala", function(ply)
  linea("=== eq: ESCALA en juego, contra el valor medido del lado de Unity")
  linea("  El .mdl y el valor esperado salen de DOS rutas distintas: el esperado")
  linea("  se midio del GLB + la cadena TRS, sin pasar por Blender ni studiomdl.")
  for _, e in ipairs(ESCALA) do
    local ruta = "models/phantasmagoria/eq/" .. e[1] .. ".mdl"
    local mn, mx = Vector(), Vector()
    local ent = ClientsideModel(ruta)
    if not IsValid(ent) then
      linea(("  %-30s NO SE PUDO CREAR -> SIN CORRER"):format(e[1]))
    else
      mn, mx = ent:GetModelBounds()
      ent:Remove()
      local d = mx - mn
      local dims = { math.abs(d.x), math.abs(d.y), math.abs(d.z) }
      table.sort(dims, function(a, b) return a > b end)
      local err = 100 * (dims[1] - e[2]) / e[2]
      linea(("  %-30s mayor=%6.2f u   esperado=%6.2f u   error=%+6.1f %%  %s"):format(
        e[1], dims[1], e[2], err, (math.abs(err) <= 5 and "OK" or "FUERA DE BANDA")))
    end
  end
  linea("  Los tres tienen que dar numeros DISTINTOS entre si: si dieran el")
  linea("  mismo, el lector devuelve una constante y no mide el modelo.")
end)

concommand.Add("ph_eq_todo", function(ply)
  RunConsoleCommand("ph_eq_rutas")
  RunConsoleCommand("ph_eq_modelos")
  RunConsoleCommand("ph_eq_materiales")
  RunConsoleCommand("ph_eq_escala")
end)

linea("[phantasmagoria] eqp_check cargado: ph_eq_todo | _rutas | _modelos | " ..
      "_materiales | _blancos | _escala  (" .. #MODELOS .. " modelos, " ..
      #MATERIALES .. " materiales, " .. #BLANCOS .. " con blanco)")
