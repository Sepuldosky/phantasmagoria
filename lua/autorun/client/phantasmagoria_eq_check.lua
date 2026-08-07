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
    Un barrido que devuelve "66/66 OK" no distingue "estan todos" de
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
  "repellent_iii_hanging",
  "repellent_iii_wrapped",
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
  { "igniter_iii", 2.97 },
  { "motion_sensor_iii", 7.20 },
  { "tripod_ii", 41.49 },
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
  linea("  DOS lecturas, porque NO contestan lo mismo:")
  linea("    file.Exists       el motor ENTREGA el archivo. Es el criterio.")
  linea("    util.IsValidModel NO contesta por la validez. MEDIDO: dio false en")
  linea("                      los 66 mientras esos modelos spawneaban bien")
  linea("                      (ronda 2), y despues DOS corridas seguidas de")
  linea("                      este mismo comando dieron 57 y 66 sin que")
  linea("                      cambiara un byte en disco (ronda 2b). Un lector")
  linea("                      de validez no cambia de respuesta ahi. Se publica")
  linea("                      al lado, con un control POSITIVO: si el modelo")
  linea("                      del jugador -que seguro esta cargado- tambien")
  linea("                      diera false, el lector estaria clavado en false.")
  local hay, cargados, faltan, nocargados = 0, 0, {}, {}
  for _, m in ipairs(MODELOS) do
    local ruta = "models/phantasmagoria/eq/" .. m .. ".mdl"
    if file.Exists(ruta, "GAME") then hay = hay + 1 else faltan[#faltan + 1] = m end
    if util.IsValidModel(ruta) then
      cargados = cargados + 1
    else
      nocargados[#nocargados + 1] = m
    end
  end
  linea(("  ENTREGA (file.Exists) : %d de %d"):format(hay, #MODELOS))
  for _, m in ipairs(faltan) do linea("    NO LO ENTREGA: " .. m) end
  linea(("  CARGA (IsValidModel)  : %d de %d"):format(cargados, #MODELOS))
  if #nocargados > 0 and #nocargados <= 8 then
    for _, m in ipairs(nocargados) do linea("    sin cargar: " .. m) end
  end

  -- Un control negativo SOLO detecta el lector clavado en TRUE. El de la ronda
  -- 2 dijo "false, correcto" con el barrido entero en cero: para el otro lado
  -- hace falta un control POSITIVO, o sea una ruta que TIENE que dar true.
  local ctrl = util.IsValidModel(MODELO_FALSO)
  linea("  CONTROL NEGATIVO (" .. MODELO_FALSO .. "):")
  linea("    " .. (ctrl and "DEVOLVIO TRUE -> el barrido NO MIDE NADA" or "false, correcto"))
  local yo = IsValid(LocalPlayer()) and LocalPlayer():GetModel() or nil
  if not yo then
    linea("  CONTROL POSITIVO: no hay LocalPlayer -> SIN CONTROL, el barrido no vale")
  else
    local pos = util.IsValidModel(yo)
    linea("  CONTROL POSITIVO (" .. yo .. "):")
    linea("    " .. (pos and "true, correcto -> el lector SI discrimina"
                    or "DIO FALSE sobre el modelo del propio jugador -> clavado en false"))
    linea("    Si el positivo da true y los nuestros false, lo que falta es la")
    linea("    CARGA: volver a correr esto DESPUES de spawnear uno y comparar.")
  end
  -- Los DOS lados del file.Exists, por lo mismo: la ruta falsa ataja al lector
  -- clavado en true, y las rutas que SI existen -de otros addons ya montados,
  -- que no son de este lote- atajan al clavado en false. Con un solo lado, un
  -- "0 de 66" y un "66 de 66" se leen los dos como correctos.
  linea("  CONTROL NEGATIVO file.Exists (" .. MODELO_FALSO .. "):")
  linea("    " .. (file.Exists(MODELO_FALSO, "GAME") and "TRUE -> NO MIDE NADA"
                  or "false, correcto"))
  local nvivos = 0
  for _, t in ipairs(TERCEROS) do
    if file.Exists(t[2], "GAME") then nvivos = nvivos + 1 end
  end
  linea(("  CONTROL POSITIVO file.Exists (%d rutas montadas que NO son de este lote): %d"):format(
    #TERCEROS, nvivos))
  linea("    " .. (nvivos > 0 and "al menos una da true -> el lector SI discrimina"
                  or "NINGUNA da true -> el lector esta clavado en false, NO MIDE NADA"))

  -- EXPERIMENTO: que dispara la transicion false -> true.
  --
  -- EL SUJETO TIENE QUE SER UNO QUE HOY DE false. La primera version tomaba
  -- MODELOS[1] a secas y en la ronda 2b salio "antes=true despues=true" sobre
  -- crucifix_i, que ya estaba cargado: un experimento cuyo sujeto YA CUMPLE el
  -- resultado no puede mostrar ninguna transicion.
  local sujeto = nocargados[1]
  if not sujeto then
    linea("  EXPERIMENTO: los " .. #MODELOS .. " ya dan true -> no hay sujeto sin")
    linea("    cargar. NO APLICA en esta corrida; para tenerlo, correrlo apenas")
    linea("    arranca GMod, antes de spawnear nada del lote.")
  elseif not util.PrecacheModel then
    linea("  EXPERIMENTO: util.PrecacheModel no existe en este realm -> sin medir")
  else
    local uno = "models/phantasmagoria/eq/" .. sujeto .. ".mdl"
    local antes = util.IsValidModel(uno)
    util.PrecacheModel(uno)
    local despues = util.IsValidModel(uno)
    linea(("  EXPERIMENTO precache (%s, elegido por dar false): antes=%s  despues=%s"):format(
      sujeto, tostring(antes), tostring(despues)))
    linea("    false->true : lo que dispara la transicion es el PRECACHE.")
    linea("    false->false: el precache de cliente no alcanza -- la transicion")
    linea("                  la dispara otra cosa (spawnear, o la propia")
    linea("                  consulta). No confirmada != refutada.")
  end
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

-- Tamano mayor de la MALLA de un modelo, leido de la geometria que el cliente
-- carga. Devuelve (mayor, n_vertices) o nil.
--
-- POR QUE NO `ent:GetModelBounds()`: ese devuelve hull_min/hull_max del header
-- del .mdl, que es el bbox del HULL DE COLISION y no el de la malla. Medido en
-- la ronda 2: dio 3.40 / 8.34 / 41.99 donde el .vvd mide 2.965 / 7.863 / 41.49
-- -- casi media unidad de mas en los tres, con tamanos que van de 3 a 42 u.
-- El esperado se midio del lado de Unity y es la MALLA: comparar contra el
-- hull era comparar dos cosas distintas, y los +14 % no eran del modelo.
local function mayor_de_la_malla(ruta)
  local ms = util.GetModelMeshes(ruta)
  if not ms or #ms == 0 then return nil, 0 end
  local lo = { 1e9, 1e9, 1e9 }
  local hi = { -1e9, -1e9, -1e9 }
  local n = 0
  for _, m in ipairs(ms) do
    local vs = m.triangles or m.verticies
    if vs then
      for _, v in ipairs(vs) do
        local p = v.pos
        if p then
          n = n + 1
          if p.x < lo[1] then lo[1] = p.x end
          if p.y < lo[2] then lo[2] = p.y end
          if p.z < lo[3] then lo[3] = p.z end
          if p.x > hi[1] then hi[1] = p.x end
          if p.y > hi[2] then hi[2] = p.y end
          if p.z > hi[3] then hi[3] = p.z end
        end
      end
    end
  end
  -- Un cero se lee igual que "el modelo mide cero": si no se leyo un solo
  -- vertice, esto NO devuelve un numero.
  if n == 0 then return nil, 0 end
  local dims = { hi[1] - lo[1], hi[2] - lo[2], hi[3] - lo[3] }
  table.sort(dims, function(a, b) return a > b end)
  return dims[1], n
end

concommand.Add("ph_eq_escala", function(ply)
  linea("=== eq: ESCALA en juego, contra el valor medido del lado de Unity")
  linea("  El esperado y lo leido salen de DOS rutas distintas: el esperado se")
  linea("  midio del GLB + la cadena TRS, sin Blender ni studiomdl. Y es el")
  linea("  tamano de la MALLA, asi que aca se lee la malla (util.GetModelMeshes)")
  linea("  y no el bbox: GetModelBounds da el HULL DE COLISION, que es MAS")
  linea("  GRANDE y no por una cantidad fija -- medido en juego, +0.30 u en el")
  linea("  sensor de movimiento y +0.43 / +0.50 en los otros dos, sobre objetos")
  linea("  de 3 a 42 u. Se imprime al lado para que la diferencia se vea.")
  for _, e in ipairs(ESCALA) do
    local ruta = "models/phantasmagoria/eq/" .. e[1] .. ".mdl"
    local malla, nv = mayor_de_la_malla(ruta)
    if not malla then
      linea(("  %-22s SIN MALLA (util.GetModelMeshes no devolvio vertices) -> SIN CORRER"):format(e[1]))
    else
      local hull = 0
      local ent = ClientsideModel(ruta)
      if IsValid(ent) then
        local mn, mx = ent:GetModelBounds()
        ent:Remove()
        local hd = { math.abs(mx.x - mn.x), math.abs(mx.y - mn.y), math.abs(mx.z - mn.z) }
        table.sort(hd, function(a, b) return a > b end)
        hull = hd[1]
      end
      local err = 100 * (malla - e[2]) / e[2]
      linea(("  %-22s malla=%6.2f u  esperado=%6.2f u  error=%+6.1f %%  %-13s (hull=%6.2f u, %d verts)"):format(
        e[1], malla, e[2], err, (math.abs(err) <= 5 and "OK" or "FUERA DE BANDA"), hull, nv))
    end
  end
  -- El control negativo del LECTOR NUEVO: la misma funcion sobre una ruta que
  -- no existe tiene que devolver nada. Si devolviera un numero, los tres de
  -- arriba podrian ser ese mismo numero.
  local falso = mayor_de_la_malla(MODELO_FALSO)
  linea("  CONTROL NEGATIVO (" .. MODELO_FALSO .. "):")
  linea("    " .. (falso and ("DEVOLVIO " .. falso .. " -> el lector NO MIDE NADA")
                  or "sin malla, correcto"))
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
