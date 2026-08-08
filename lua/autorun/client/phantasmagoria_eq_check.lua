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
  "uv_light_ii_0_on",
  "uv_light_ii_1",
  "uv_light_ii_1_on",
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
  "ghost_writing_i_3",
  "igniter_i_5",
  "igniter_ii_1",
  "igniter_ii_3",
  "igniter_iii_6",
  "motion_sensor_i_2",
  "motion_sensor_ii_2",
  "photo_camera_i_4",
}

-- Tamano mayor esperado, en unidades Source, MEDIDO por el lado de Unity
-- (dev/phastools/eqpsize.py, ruta de vertices del GLB). No sale del .mdl.
-- Se eligen los extremos del lote a proposito: si el lector devolviera una
-- constante, dos objetos que difieren varias veces en tamano lo delatan.
local ESCALA = {
  { "igniter_iii", 3.42 },
  { "motion_sensor_iii", 8.28 },
  { "tripod_ii", 47.71 },
}

-- Los que esta ronda paso a `$translucent 1`: { slot, % opaco predicho, material,
-- modelo }. La lista sale de out/eqp_audit/transp_plan.json y esta filtrada
-- contra la tabla de texturas de los .mdl COMPILADOS: un VMT que ningun modelo
-- nombra no se puede mirar en juego, y ponerlo aca haria buscar algo que no
-- existe. (Hay 23 VMT asi en el lote, restos del renumerado de bodygroups.)
local TRANSLUCIDOS = {
  { "ghost_writing_ii_2", 88, "Biro", "ghost_writing_ii_pen" },
  { "video_camera_i_2", 82, "Camcorder 1 Glass", "video_camera_i" },
  { "video_camera_ii_2", 48, "Camcorder Glass", "video_camera_ii" },
  { "dots_iii_2", 72, "DOTS 3 Glass", "dots_iii" },
  { "emf_reader_i_3", 56, "EMF 1 Glass", "emf_reader_i" },
  { "flashlight_iii_1", 76, "Flashlight 3 Glass", "flashlight_iii" },
  { "flashlight_i_3", 47, "Flashlight Glass", "flashlight_i" },
  { "head_mounted_ii_2", 44, "HeadFlashlight Glass", "head_mounted_ii" },
  { "firelight_iii_7", 73, "Lantern 3b Glass", "firelight_iii" },
  { "uv_light_iii_1", 77, "Large UV Flashlight Gl", "uv_light_iii" },
  { "igniter_ii_2", 72, "Lighter 1", "igniter_ii" },
  { "motion_sensor_iii_2", 51, "Motion Sensor 3 glass", "motion_sensor_iii" },
  { "motion_sensor_i_1", 70, "Motion Sensor Glass", "motion_sensor_i" },
  { "photo_camera_iii_3", 73, "Photo Cam 3 Glass", "photo_camera_iii" },
  { "photo_camera_i_3", 44, "Polaroid Glass", "photo_camera_i" },
  { "salt_iii_3", 53, "Salt 3 Glass", "salt_iii" },
  { "sanity_medication_i_0", 95, "Sanity Meds 1", "sanity_medication_i" },
  { "sanity_medication_iii_0", 97, "Sanity Meds 3", "sanity_medication_iii" },
  { "sanity_medication_ii_0", 68, "Sanity Pills Transp", "sanity_medication_ii" },
  { "sound_recorder_i_13", 9, "SoundRecorderTier1_Equ", "sound_recorder_i" },
  { "sound_recorder_i_5", 94, "SoundRecorderTier1_Equ", "sound_recorder_i" },
  { "sound_recorder_ii_1", 15, "SoundRecorderTier2_Equ", "sound_recorder_ii" },
  { "spiritbox_i_5", 99, "Spiritbox 1 Glass", "spiritbox_i" },
  { "flashlight_ii_1", 35, "Strong Flashlight Glas", "flashlight_ii" },
  { "thermometer_i_1", 21, "Thermo level 1 glass", "thermometer_i" },
}

-- Los modelos que MEZCLAN opaco con translucido y llevan `$mostlyopaque`.
local MOSTLYOPAQUE = {
  "dots_iii",
  "emf_reader_i",
  "firelight_iii",
  "flashlight_i",
  "flashlight_ii",
  "flashlight_iii",
  "head_mounted_ii",
  "igniter_ii",
  "motion_sensor_i",
  "motion_sensor_iii",
  "photo_camera_i",
  "photo_camera_iii",
  "salt_iii",
  "sanity_medication_i",
  "sanity_medication_ii",
  "sanity_medication_iii",
  "sound_recorder_i",
  "sound_recorder_ii",
  "spiritbox_i",
  "thermometer_i",
  "uv_light_iii",
  "video_camera_i",
  "video_camera_ii",
}

-- El control de los tres barridos de transparencia: { modelo, uno de sus
-- materiales }. Es un modelo que esta ronda NO toco y que no tiene ninguna
-- pieza translucida. Tiene que dar flags SIN el bit 3, grupo de render 7 y un
-- VMT que no declara `$translucent`. Si diera lo mismo que los tocados, los
-- tres barridos estan midiendo una constante.
-- --- ronda 5 ---------------------------------------------------------------
-- Los que EMITEN: { slot, material, .mdl }. El criterio es el keyword
-- `_EMISSION` del material de Unity Y que el mapa tenga contenido, no el mapa
-- solo: hay 36 piezas con la mascara horneada y el material apagado.
local EMITEN = {
  { "crucifix_i_0", "Crucifix I Broken", "crucifix_i" },
  { "crucifix_ii_1", "Crucifix Broken 1", "crucifix_ii" },
  { "crucifix_ii_2", "Crucifix Broken 2", "crucifix_ii" },
  { "crucifix_iii_0", "Crucifix 3 Broken 1", "crucifix_iii" },
  { "crucifix_iii_2", "Cruc 3 Broken 2", "crucifix_iii" },
  { "emf_reader_ii_0", "EMF reader", "emf_reader_ii" },
  { "flashlight_ii_0", "Strong Flashlight", "flashlight_ii" },
  { "flashlight_ii_1", "Strong Flashlight Glass", "flashlight_ii" },
  { "motion_sensor_i_0", "Motion Sensor", "motion_sensor_i" },
  { "motion_sensor_iii_0", "Motion Sensor 3", "motion_sensor_iii" },
  { "motion_sensor_iii_1", "Motion Sensor 3", "motion_sensor_iii" },
  { "repellent_ii_1", "Burn Disc", "repellent_ii" },
  { "sound_recorder_ii_0", "SoundRecorderTier2_Equip", "sound_recorder_ii" },
  { "sound_recorder_iii_0", "SoundRecorderTier3_Equip", "sound_recorder_iii" },
  { "sound_recorder_iii_1", "SoundRecorderTier3_Equip", "sound_recorder_iii" },
  { "sound_recorder_iii_2", "SoundRecorderTier3_Equip", "sound_recorder_iii" },
  { "sound_sensor_iii_0", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_1", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_10", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_11", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_12", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_13", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_14", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_15", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_16", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_17", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_18", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_2", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_3", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_4", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_5", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_6", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_7", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_8", "Sound Sensor 3", "sound_sensor_iii" },
  { "sound_sensor_iii_9", "Sound Sensor 3", "sound_sensor_iii" },
  { "spiritbox_i_0", "Spiritbox 1", "spiritbox_i" },
  { "spiritbox_i_1", "Spiritbox 1", "spiritbox_i" },
  { "spiritbox_i_2", "Spiritbox 1", "spiritbox_i" },
  { "spiritbox_i_3", "Spiritbox 1", "spiritbox_i" },
  { "spiritbox_i_4", "Spiritbox 1", "spiritbox_i" },
  { "spiritbox_i_5", "Spiritbox 1 Glass", "spiritbox_i" },
  { "spiritbox_i_6", "Spiritbox 1", "spiritbox_i" },
  { "spiritbox_iii_0", "Spiritbox Level 3", "spiritbox_iii" },
  { "uv_light_ii_0", "Glowstick", "uv_light_ii" },
  { "uv_light_iii_0", "Large UV Flashlight", "uv_light_iii" },
}

-- Emiten Y son translucidos: el alfa del $basetexture ya lleva la opacidad de
-- la ronda 4, asi que la mascara va en una textura aparte.
local EMIS_MASK = {
  "flashlight_ii_1",
  "motion_sensor_i_0",
  "motion_sensor_iii_0",
  "motion_sensor_iii_1",
  "spiritbox_i_0",
  "spiritbox_i_1",
  "spiritbox_i_2",
  "spiritbox_i_3",
  "spiritbox_i_4",
  "spiritbox_i_5",
  "spiritbox_i_6",
  "spiritbox_iii_0",
  "uv_light_ii_0",
}

-- CONTROL POSITIVO del criterio: tienen la mascara horneada en la textura y el
-- keyword APAGADO. Con el criterio viejo se habrian encendido; tienen que
-- seguir SIN declarar $selfillum.
local NO_EMITEN_CONTROL = {
  "crucifix_i_1",
  "crucifix_ii_0",
  "crucifix_iii_1",
  "dots_i_0",
  "dots_ii_0",
  "dots_ii_1",
}

-- Los que salieron del piso `_white` con textura propia: { slot, textura, clase }
local PLANOS = {
  { "firelight_iii_6", "firelight_iii_6_flat", "llama" },
  { "head_mounted_camera_2", "head_mounted_camera_2_flat", "vidrio" },
  { "photo_camera_ii_1", "photo_camera_ii_1_flat", "pantalla" },
  { "photo_camera_ii_2", "photo_camera_ii_2_flat", "pantalla" },
  { "photo_camera_iii_1", "photo_camera_iii_1_flat", "pantalla" },
  { "photo_camera_iii_2", "photo_camera_iii_2_flat", "pantalla" },
  { "sanity_medication_i_2", "sanity_medication_i_2_flat", "liquido" },
  { "thermometer_i_2", "thermometer_i_2_flat", "liquido" },
  { "uv_light_ii_1", "uv_light_ii_1_flat", "liquido" },
  { "video_camera_i_3", "video_camera_i_3_flat", "pantalla" },
  { "video_camera_ii_3", "video_camera_ii_3_flat", "pantalla" },
  { "video_camera_iii_3", "video_camera_iii_3_flat", "pantalla" },
}

-- Los dos que quedan en el piso A PROPOSITO, y por que:
--   photo_camera_i_4  la foto de la polaroid: _BaseColor blanco con alfa 1,0
--   igniter_ii_1      el shader del combustible no publica color utilizable
local SIN_PARCHE = {
  "igniter_ii_1",
  "photo_camera_i_4",
}

-- VMT que apuntan a _white y que NINGUN .mdl nombra: no dibujan nada.
local HUERFANOS_BLANCO = {
  "crucifix_i_2",
  "crucifix_ii_3",
  "crucifix_iii_3",
  "dots_i_1",
  "firelight_i_2",
  "firelight_ii_2",
  "ghost_writing_i_3",
  "igniter_i_5",
  "igniter_ii_3",
  "igniter_iii_6",
  "motion_sensor_i_2",
  "motion_sensor_ii_2",
}

-- Las piezas cuya isla UV caia en el fondo del atlas: { slot, .mdl }
local SAL = {
  { "salt_iii_0", "salt_iii" },
  { "salt_iii_1", "salt_iii" },
  { "salt_iii_2", "salt_iii" },
  { "salt_iii_6", "salt_iii" },
}

-- Lo que se PRENDE y por eso vive en un skin: { .mdl, familias, nombres }.
-- La fila 0 es el DEFAULT y tiene que estar APAGADA.
local SKINS = {
  { "uv_light_ii", 2, "apagado/encendido" },
}
local SKINS_SLOT0 = {
  { "uv_light_ii", "uv_light_ii_0" },
}

local OPACO_CONTROL = { "video_camera_iii", "video_camera_iii_0" }

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

-- ------------------------------------------------------------ TRANSPARENCIAS
--
-- El `flags` del studiohdr_t vive en el offset 152 del .mdl. El bit 3 (valor 8)
-- es TRANSLUCENT_TWOPASS, que es lo que pone `$mostlyopaque` en el .qc. Se lee
-- del ARCHIVO QUE EL MOTOR ENTREGA, no del que hay en el repo: si otro addon
-- montara la misma ruta, esto lo ve y el codigo fuente no.
local function flags_de(slug)
  local f = file.Open("models/phantasmagoria/eq/" .. slug .. ".mdl", "rb", "GAME")
  if not f then return nil end
  f:Seek(152)
  local v = f:ReadLong()
  f:Close()
  return v
end

-- El VMT leido como ARCHIVO. Es la unica via que dice a la vez que la clave
-- esta declarada y CUAL archivo monto el juego. Preguntarselo al IMaterial no
-- sirve para esto: `$alpha` leido de un material devuelve la modulacion en
-- reposo que escribe el motor, no lo que dice el .vmt (referencia §28).
local function vmt_declara(slot, clave_txt)
  local t = file.Read("materials/models/phantasmagoria/eq/" .. slot .. ".vmt", "GAME")
  if not t then return nil end
  return string.find(t, clave_txt, 1, true) ~= nil
end

concommand.Add("ph_eq_transp", function()
  linea("=== eq: TRANSPARENCIAS -- " .. #TRANSLUCIDOS .. " piezas en " ..
        #MOSTLYOPAQUE .. " modelos")
  linea("  Que se declare NO es que se vea. Lo que se ve se juzga mirando; esto")
  linea("  mide que el motor este montando la declaracion correcta.")

  linea("  --- 1. los .vmt que el motor entrega declaran $translucent ---")
  local si, no, ilegible = 0, {}, {}
  for _, r in ipairs(TRANSLUCIDOS) do
    local d = vmt_declara(r[1], '"$translucent" 1')
    if d == nil then ilegible[#ilegible + 1] = r[1]
    elseif d then si = si + 1
    else no[#no + 1] = r[1] end
  end
  linea(("    declaran: %d de %d   no declaran: %d   ilegibles: %d"):format(
    si, #TRANSLUCIDOS, #no, #ilegible))
  for _, m in ipairs(no) do linea("      NO DECLARA: " .. m) end
  for _, m in ipairs(ilegible) do linea("      NO SE PUDO LEER: " .. m) end

  -- Los DOS controles. Uno solo no alcanza: un lector clavado en `true` lo
  -- ataja el negativo, y uno clavado en `false` lo ataja el positivo. En la
  -- ronda 2 los dos barridos tenian solo el negativo y los dos lo pasaron
  -- estando clavados en false.
  local cn = vmt_declara("no_existe_este_material", '"$translucent" 1')
  linea("    CONTROL NEGATIVO (vmt inexistente): " ..
        (cn == nil and "no se pudo leer, correcto"
         or "DEVOLVIO " .. tostring(cn) .. " -> el lector NO MIDE NADA"))
  local cp = vmt_declara(OPACO_CONTROL[2], '"$translucent" 1')
  linea("    CONTROL POSITIVO (" .. OPACO_CONTROL[2] .. ", opaco y sin tocar): " ..
        (cp == false and "no declara, correcto"
         or cp == nil and "NO SE PUDO LEER -> el barrido NO MIDE NADA"
         or "DIO true -> el lector no discrimina, dice que si a todo"))

  linea("  --- 2. flags del .mdl: bit 3 = TRANSLUCENT_TWOPASS ($mostlyopaque) ---")
  local con, sinbit = 0, {}
  for _, slug in ipairs(MOSTLYOPAQUE) do
    local v = flags_de(slug)
    if v and bit.band(v, 8) ~= 0 then con = con + 1
    else sinbit[#sinbit + 1] = slug .. "=" .. tostring(v) end
  end
  linea(("    con el bit puesto: %d de %d"):format(con, #MOSTLYOPAQUE))
  for _, s in ipairs(sinbit) do linea("      SIN EL BIT: " .. s) end
  local fo = flags_de(OPACO_CONTROL[1])
  linea(("    CONTROL (%s, opaco y sin tocar): flags=%s -> %s"):format(
    OPACO_CONTROL[1], tostring(fo),
    fo == nil and "NO SE PUDO ABRIR EL .mdl -> el barrido NO MIDE NADA"
      or bit.band(fo, 8) == 0 and "sin el bit, correcto"
      or "TIENE EL BIT -> el lector no discrimina, o se toco lo que no correspondia"))
  if con == 0 and fo == nil then
    linea("    -> los " .. #MOSTLYOPAQUE .. " dieron nil igual que el control:")
    linea("       eso NO es '0 de 23 fallan', es que no se leyo un solo archivo.")
  end

  linea("  --- 3. GetRenderGroup(): 7=OPAQUE  9=BOTH ---")
  linea("    Medido en la ronda 4 del paramic: con los materiales opacos daba 7")
  linea("    y con $translucent 1 da 9. O sea que el motor decide el grupo")
  linea("    mirando los MATERIALES, y el numero SI discrimina.")
  local function grupo(slug)
    local ruta = "models/phantasmagoria/eq/" .. slug .. ".mdl"
    if not file.Exists(ruta, "GAME") then return nil, "no esta montado" end
    -- ClientsideModel con una ruta mala NO falla: devuelve el modelo de ERROR
    -- con un bbox creible. Por eso se comprueba el archivo antes Y se imprime
    -- el modelo que la entidad quedo teniendo.
    local e = ClientsideModel(ruta)
    if not IsValid(e) then return nil, "no se creo la entidad" end
    local g, m = e:GetRenderGroup(), e:GetModel()
    e:Remove()
    return g, m
  end
  for _, slug in ipairs(MOSTLYOPAQUE) do
    local g, m = grupo(slug)
    linea(("    %-24s grupo=%-6s %s"):format(slug, tostring(g), tostring(m)))
  end
  local g, m = grupo(OPACO_CONTROL[1])
  linea(("    CONTROL %-16s grupo=%-6s %s"):format(OPACO_CONTROL[1], tostring(g), tostring(m)))
  linea("    Si el control diera lo MISMO que los tocados, el numero no separa")
  linea("    nada en este lote y el check va SIN CORRER.")

  linea("  --- 4. que mirar, pieza por pieza (opacidad PREDICHA) ---")
  linea("    El % sale del alfa del albedo de Unity muestreado en las UV de esa")
  linea("    pieza, por `_BaseColor.a`. Es una PREDICCION, no una medicion en")
  linea("    juego: lo que la confirma o la desmiente es mirar.")
  for _, r in ipairs(TRANSLUCIDOS) do
    linea(("    %-24s %-22s %3d%% opaco   (%s)"):format(r[1], r[3], r[2], r[4]))
  end
end)

-- ---------------------------------------------------------------- ronda 5
-- Piezas que existen, compilan, resuelven su material y aun asi muestran lo
-- que no son. Tres causas distintas y una sola pasada.

concommand.Add("ph_eq_assets", function()
  linea("=== eq r5: EMISION, MATERIALES SIN TEXTURA Y EL AGUJERO DEL ATLAS")
  linea("  Todo lo de aca es DECLARACION: que el motor monte lo que se escribio.")
  linea("  Que se vea bien lo contestan los checks visuales de la planilla.")

  linea("  --- 1. $selfillum: " .. #EMITEN .. " piezas ---")
  linea("    Antes de esta ronda eran CERO de 291. La bandera se decidia")
  linea("    grepeando el stdout de prep_textures, y la cadena no se imprime.")
  -- Los que viven en un SKIN declaran el brillo en su `_on`, no en la base:
  -- el skin 0 tiene que NO declararlo (eso lo mide el bloque 4b). Preguntarle
  -- a la base daria "no declara" sobre un material perfecto.
  local en_skin = {}
  for _, r in ipairs(SKINS_SLOT0) do en_skin[r[2]] = true end
  local si, no, ileg = 0, {}, {}
  for _, r in ipairs(EMITEN) do
    local cual = en_skin[r[1]] and (r[1] .. "_on") or r[1]
    local d = vmt_declara(cual, '"$selfillum" 1')
    if d == nil then ileg[#ileg + 1] = cual
    elseif d then si = si + 1
    else no[#no + 1] = cual end
  end
  linea(("    declaran: %d de %d   no declaran: %d   ilegibles: %d"):format(
    si, #EMITEN, #no, #ileg))
  for _, m in ipairs(no) do linea("      NO DECLARA: " .. m) end
  for _, m in ipairs(ileg) do linea("      NO SE PUDO LEER: " .. m) end

  -- El control POSITIVO es lo que separa "arreglaron la fontaneria" de
  -- "arreglaron el criterio": estas piezas TIENEN la mascara horneada en la
  -- textura y el material la tiene APAGADA. Con el criterio viejo se habrian
  -- encendido. Si acá diera "declara", el parche encendio de mas.
  local demas = {}
  for _, s in ipairs(NO_EMITEN_CONTROL) do
    if vmt_declara(s, '"$selfillum" 1') then demas[#demas + 1] = s end
  end
  linea(("    CONTROL POSITIVO (%d con mascara horneada y _EMISSION APAGADO): %s"):format(
    #NO_EMITEN_CONTROL,
    #demas == 0 and "ninguno declara, correcto"
      or ("DECLARAN " .. #demas .. ": " .. table.concat(demas, " ") ..
          " -> se encendio de mas")))
  local cn = vmt_declara("no_existe_este_material", '"$selfillum" 1')
  linea("    CONTROL NEGATIVO (vmt inexistente): " ..
        (cn == nil and "no se pudo leer, correcto"
         or "DEVOLVIO " .. tostring(cn) .. " -> el lector NO MIDE NADA"))

  linea("  --- 2. los que emiten Y son translucidos: mascara APARTE ---")
  linea("    El alfa del $basetexture ya lleva la opacidad de la ronda 4, asi")
  linea("    que la mascara no puede ir ahi. Van con $selfillummask.")
  -- ⚠ EL NOMBRE OTRA VEZ NO SIRVE PARA PREGUNTAR. El dedupe de eqpinstall
  -- agrupa por CONTENIDO: siete de estas mascaras son el mismo binario, asi que
  -- las siete citan UN archivo y `<slot>_illum.vtf` no existe para seis de
  -- ellas. Preguntar por ese nombre da "no esta montado" sobre materiales
  -- perfectos -- es exactamente el mismo error que en el bloque 3, cometido dos
  -- veces en la misma ronda. Se lee la RUTA que el VMT declara.
  -- Y lo mismo que el bloque 1: si la pieza vive en un skin, su `$selfillummask`
  -- esta en el `_on` y no en la base. Son las DOS correcciones del mismo tipo
  -- en el mismo comando: preguntar por el nombre que uno escribio en vez de por
  -- el que el arbol quedo teniendo.
  local mok, mmal = 0, {}
  for _, s0 in ipairs(EMIS_MASK) do
    local s = en_skin[s0] and (s0 .. "_on") or s0
    local t = file.Read("materials/models/phantasmagoria/eq/" .. s .. ".vmt", "GAME")
    if t == nil then
      mmal[#mmal + 1] = s .. " (vmt ilegible)"
    else
      local ruta = string.match(t, '"%$selfillummask"%s+"([^"]+)"')
      if not ruta then mmal[#mmal + 1] = s .. " (no declara $selfillummask)"
      elseif not file.Exists("materials/" .. ruta .. ".vtf", "GAME") then
        mmal[#mmal + 1] = s .. " -> " .. ruta .. " NO ESTA MONTADO"
      else
        mok = mok + 1
        linea(("    %-24s -> %s"):format(s, ruta))
      end
    end
  end
  linea(("    declaran y su .vtf resuelve: %d de %d"):format(mok, #EMIS_MASK))
  for _, m in ipairs(mmal) do linea("      " .. m) end
  if #EMIS_MASK == 0 then
    linea("    (ninguno: no hubo choque entre emision y transparencia)")
  end

  linea("  --- 3. los que apuntaban a _white ---")
  linea("    Eran 26 en el inventario. " .. #HUERFANOS_BLANCO .. " son VMT que")
  linea("    NINGUN .mdl nombra: no dibujan nada. " .. #PLANOS .. " tienen ahora")
  linea("    textura propia y " .. #SIN_PARCHE .. " quedan declarados sin parche.")
  -- OJO CON EL NOMBRE: el dedupe de eqpinstall agrupa por CONTENIDO, y las
  -- siete pantallas son el mismo negro, asi que las siete terminan citando UN
  -- solo archivo (`photo_camera_ii_1_flat`). Preguntar por `<slot>_flat` daria
  -- "sigue en el piso" en seis que estan perfectas. Se pregunta por el SUFIJO.
  local bien, mal, ileg2 = 0, {}, 0
  for _, r in ipairs(PLANOS) do
    local t = file.Read("materials/models/phantasmagoria/eq/" .. r[1] .. ".vmt", "GAME")
    if not t then ileg2 = ileg2 + 1
    else
      local bt = string.match(t, '"%$basetexture"%s+"([^"]+)"') or ""
      if string.sub(bt, -5) == "_flat" then bien = bien + 1
      else mal[#mal + 1] = r[1] .. " -> " .. bt end
    end
  end
  linea(("    con $basetexture propio (termina en _flat): %d de %d   ilegibles: %d"):format(
    bien, #PLANOS, ileg2))
  for _, m in ipairs(mal) do linea("      SIGUE EN EL PISO: " .. m) end
  if ileg2 == #PLANOS then
    linea("    -> no se leyo ninguno: SIN CORRER.")
  end
  -- El DENOMINADOR va al lado del numerador. Sin el, "siguen 0" es
  -- indistinguible de "no se leyo un solo archivo", que es justo lo que pasa
  -- corriendo esto fuera de GMod: los dos se imprimen como un cero.
  local restan, leidos = 0, 0
  for _, m in ipairs(BLANCOS) do
    local t = file.Read("materials/models/phantasmagoria/eq/" .. m .. ".vmt", "GAME")
    if t then
      leidos = leidos + 1
      if string.find(t, "_white", 1, true) then restan = restan + 1 end
    end
  end
  linea(("    VMT que siguen apuntando a _white: %d  sobre %d LEIDOS de %d  "
        .. "(esperado: %d huerfanos + %d declarados)"):format(
    restan, leidos, #BLANCOS, #HUERFANOS_BLANCO, #SIN_PARCHE))
  if leidos == 0 then
    linea("    -> NO SE LEYO NINGUNO: ese 0 no es un resultado. SIN CORRER.")
  end
  -- CONTROL NEGATIVO del lector: si "_white" se encontrara en cualquier VMT,
  -- este numero seria 291 y se leeria igual de bien.
  local cw = file.Read("materials/models/phantasmagoria/eq/" .. PLANOS[1][1] ..
                       ".vmt", "GAME")
  linea("    CONTROL POSITIVO (" .. PLANOS[1][1] .. ", que se acaba de sacar del piso): " ..
        (cw == nil and "NO SE PUDO LEER -> el barrido NO MIDE NADA"
         or string.find(cw, "_white", 1, true) and "SIGUE con _white -> el parche no llego"
         or "ya no dice _white, correcto"))
  -- Y el del otro lado: uno de los que se dejaron en el piso A PROPOSITO tiene
  -- que SEGUIR diciendo _white. Sin este, un lector que nunca encuentra la
  -- cadena da "arreglados todos" y se lee igual de bien.
  local cs = SIN_PARCHE[1] and file.Read(
    "materials/models/phantasmagoria/eq/" .. SIN_PARCHE[1] .. ".vmt", "GAME")
  linea("    CONTROL NEGATIVO (" .. tostring(SIN_PARCHE[1]) ..
        ", declarado sin parche): " ..
        (cs == nil and "NO SE PUDO LEER -> el barrido NO MIDE NADA"
         or string.find(cs, "_white", 1, true) and "sigue con _white, correcto"
         or "YA NO dice _white -> se toco lo que no correspondia"))

  linea("  --- 4. el $bumpmap no puede ser el $basetexture ---")
  linea("    El dedupe agrupa por CONTENIDO. Si dos escrituras terminaran")
  linea("    produciendo el mismo binario, el mapa de normales y el albedo se")
  linea("    colapsan y el VMT declara el albedo como bumpmap: no rompe ninguna")
  linea("    referencia y se ve como un modelo mal iluminado. Paso de verdad")
  linea("    en la r5 y es el unico sintoma que lo delato.")
  local choque, conbump = {}, 0
  for _, m in ipairs(MATERIALES) do
    local t = file.Read("materials/models/phantasmagoria/eq/" .. m .. ".vmt", "GAME")
    if t then
      local bt = string.match(t, '"%$basetexture"%s+"([^"]+)"')
      local bm = string.match(t, '"%$bumpmap"%s+"([^"]+)"')
      if bt and bm then
        conbump = conbump + 1
        if string.lower(bt) == string.lower(bm) then choque[#choque + 1] = m end
      end
    end
  end
  linea(("    VMT donde $basetexture == $bumpmap: %d  sobre %d con las DOS claves leidas"):format(
    #choque, conbump))
  if conbump == 0 then
    linea("    -> NO SE LEYO NINGUN par: ese 0 no es un resultado. SIN CORRER.")
  elseif #choque > 0 then
    linea("    -> " .. table.concat(choque, " "))
  end

  linea("  --- 4b. lo que se PRENDE viene APAGADO ---")
  linea("    Un $selfillum escrito en el VMT no es un estado: no se puede apagar")
  linea("    sin cambiar de material. La fila 0 del $texturegroup es el default.")
  for _, r in ipairs(SKINS) do
    local f = file.Open("models/phantasmagoria/eq/" .. r[1] .. ".mdl", "rb", "GAME")
    local fam
    if f then f:Seek(224) fam = f:ReadLong() f:Close() end
    linea(("    %-24s numskinfamilies=%-4s esperado=%d  (%s)"):format(
      r[1], tostring(fam), r[2], r[3]))
  end
  local malskin = {}
  for _, r in ipairs(SKINS_SLOT0) do
    local t = file.Read("materials/models/phantasmagoria/eq/" .. r[2] .. ".vmt", "GAME")
    if t == nil then malskin[#malskin + 1] = r[2] .. " (ilegible)"
    elseif string.find(t, '"$selfillum"', 1, true) then
      malskin[#malskin + 1] = r[2] .. " DECLARA $selfillum en el skin 0"
    end
  end
  linea(("    el skin 0 NO declara $selfillum: %s"):format(
    #malskin == 0 and "correcto en los " .. #SKINS_SLOT0 or table.concat(malskin, " | ")))
  -- CONTROL POSITIVO: el `_on` SI tiene que declararlo. Sin este, un lector que
  -- nunca encuentra la cadena da "correcto" sobre los dos lados.
  local sinon = {}
  for _, r in ipairs(SKINS_SLOT0) do
    local t = file.Read("materials/models/phantasmagoria/eq/" .. r[2] .. "_on.vmt", "GAME")
    if t == nil or not string.find(t, '"$selfillum"', 1, true) then
      sinon[#sinon + 1] = r[2] .. "_on"
    end
  end
  linea(("    CONTROL POSITIVO, el _on SI declara: %s"):format(
    #sinon == 0 and "correcto" or ("NO en " .. table.concat(sinon, " "))))

  linea("  --- 5. donde mirar la sal ---")
  linea("    Las cuatro piezas de relleno indexaban el FONDO del atlas: (0,0,0)")
  linea("    plano, sd 0,00. Ahora llevan la textura de sal negra del propio")
  linea("    juego (media 34,7/31,2/32,6, con grano). El veredicto es mirar.")
  for _, r in ipairs(SAL) do
    linea(("    %-24s en el modelo %s"):format(r[1], r[2]))
  end
end)

-- ---------------------------------------------------------------- ronda 6
-- Los 8 aditivos del grabador y los bodygroups de LED (grabador I/III, EMF II).
--
-- Los 8 salian VertexLitGeneric OPACO y cinco con `$color2 [0 0 0]`, un valor
-- derivado de `_BaseColor` que NINGUNO de sus tres Shader Graphs declara. El
-- blend de verdad esta horneado en el pass: `Blend SrcAlpha One`.

local ADITIVOS = {
  { "sound_recorder_i_14" },
  { "sound_recorder_i_15" },
  { "sound_recorder_i_16" },
  { "sound_recorder_ii_2" },
  { "sound_recorder_iii_3" },
  { "sound_recorder_iii_4" },
  { "sound_recorder_iii_5" },
  { "sound_recorder_iii_6" },
}

local LEDS = {
  { "models/phantasmagoria/eq/emf_reader_ii.mdl", "studioprop=1 leds=6" },
  { "models/phantasmagoria/eq/sound_recorder_i.mdl", "studioprop=1 vu_izq=10 vu_der=10" },
  { "models/phantasmagoria/eq/sound_recorder_iii.mdl", "studioprop=1 vu_izq=3 vu_der=3" },
}

local LEDS_CONTROL = {
  { "models/phantasmagoria/eq/emf_reader_i.mdl" },
  { "models/phantasmagoria/eq/emf_reader_iii.mdl" },
  { "models/phantasmagoria/eq/sound_recorder_ii.mdl" },
}

concommand.Add("ph_eq_leds", function()
  linea("=== eq r6: ADITIVOS Y BODYGROUPS DE LED")

  linea("  --- 1. los " .. #ADITIVOS .. " VMT aditivos ---")
  linea("    `$additive` de Source es `One One`; Unity hornea `SrcAlpha One`.")
  linea("    Las dos coinciden porque el alfa de estas texturas es 255 CONSTANTE")
  linea("    (medido fuera de juego sobre los 8 albedos de origen).")
  local si, no, ileg = 0, {}, {}
  for _, r in ipairs(ADITIVOS) do
    local d = vmt_declara(r[1], '"$additive" 1')
    if d == nil then ileg[#ileg + 1] = r[1]
    elseif d then si = si + 1
    else no[#no + 1] = r[1] end
  end
  linea(("    declaran $additive: %d de %d   no: %d   ilegibles: %d"):format(
    si, #ADITIVOS, #no, #ileg))
  for _, m in ipairs(no) do linea("      NO DECLARA: " .. m) end
  for _, m in ipairs(ileg) do linea("      NO SE PUDO LEER: " .. m) end

  -- El defecto que se arreglo era un `$color2` negro. Preguntar solo por
  -- `$additive` no lo veria: un VMT puede tener las dos cosas.
  -- Con su DENOMINADOR: un cero sobre cero VMT leidos no es un cero, es un
  -- lector que no leyo nada -- y se imprime igual que el resultado perfecto.
  local con_color2, leidos_c2 = {}, 0
  for _, r in ipairs(ADITIVOS) do
    local d = vmt_declara(r[1], '"$color2"')
    if d ~= nil then
      leidos_c2 = leidos_c2 + 1
      if d then con_color2[#con_color2 + 1] = r[1] end
    end
  end
  if leidos_c2 == 0 then
    linea("    con $color2: SIN CORRER -- no se leyo un solo VMT")
  else
    linea(("    con $color2 (tiene que ser CERO): %d sobre %d LEIDOS%s"):format(
      #con_color2, leidos_c2,
      #con_color2 > 0 and "  -> " .. table.concat(con_color2, " ") or ""))
  end

  local cn = vmt_declara("no_existe_este_material", '"$additive" 1')
  linea("    CONTROL NEGATIVO (vmt inexistente): " ..
        (cn == nil and "no se pudo leer, correcto"
         or "DEVOLVIO " .. tostring(cn) .. " -> el lector NO MIDE NADA"))
  local cp = vmt_declara(OPACO_CONTROL[2], '"$additive" 1')
  linea("    CONTROL POSITIVO (" .. OPACO_CONTROL[2] .. ", opaco): " ..
        (cp == nil and "NO SE PUDO LEER -> el control no mide"
         or (cp and "DECLARA $additive -> se toco de mas" or "no declara, correcto")))

  linea("  --- 2. los bodygroups, leidos del modelo que el motor entrega ---")
  linea("    Que el .qc diga $bodygroup mide lo que escribimos. Esto pregunta")
  linea("    por el prop ya montado. DEFAULT = 0 = TODO APAGADO (pedido del autor).")
  local bien, mal, sinleer = 0, 0, 0
  for _, r in ipairs(LEDS) do
    local e = ClientsideModel(r[1])
    if not IsValid(e) then
      sinleer = sinleer + 1
      linea(("    %-28s NO SE PUDO CREAR EL PROP -> SIN CORRER"):format(r[1]))
    else
      local n = e:GetNumBodyGroups()
      local partes = {}
      for i = 0, n - 1 do
        partes[#partes + 1] = ("%s=%d"):format(e:GetBodygroupName(i),
                                               e:GetBodygroupCount(i))
      end
      local leido = table.concat(partes, " ")
      local ok = (leido == r[2])
      if ok then bien = bien + 1 else mal = mal + 1 end
      linea(("    %-28s %s"):format(r[1], leido))
      if not ok then
        linea(("        ESPERADO: %s   <- NO COINCIDE"):format(r[2]))
      end
      e:Remove()
    end
  end
  linea(("    coinciden: %d   no coinciden: %d   sin leer: %d"):format(
    bien, mal, sinleer))

  -- Sin este control, "todos tienen los suyos" lo cumple igual un lector que
  -- devuelve siempre lo que se le pregunta.
  linea("    CONTROL POSITIVO -- modelos que NO tienen que tener bodygroups:")
  for _, r in ipairs(LEDS_CONTROL) do
    local e = ClientsideModel(r[1])
    if not IsValid(e) then
      linea(("      %-28s NO SE PUDO CREAR -> el control NO MIDE"):format(r[1]))
    else
      local n = e:GetNumBodyGroups()
      local c = n > 0 and e:GetBodygroupCount(0) or -1
      linea(("      %-28s grupos=%d opciones0=%d  %s"):format(
        r[1], n, c, (n <= 1 and c <= 1) and "correcto" or "<- TIENE BODYGROUPS"))
      e:Remove()
    end
  end
end)

concommand.Add("ph_eq_todo", function(ply)
  RunConsoleCommand("ph_eq_rutas")
  RunConsoleCommand("ph_eq_modelos")
  RunConsoleCommand("ph_eq_materiales")
  RunConsoleCommand("ph_eq_escala")
end)

linea("[phantasmagoria] eqp_check cargado: ph_eq_todo | _rutas | _modelos | " ..
      "_materiales | _blancos | _escala | _transp | _assets | _leds  (" .. #MODELOS ..
      " modelos, " .. #MATERIALES .. " materiales, " .. #BLANCOS ..
      " con blanco, " .. #TRANSLUCIDOS .. " translucidos, " .. #EMITEN ..
      " emisivos, " .. #ADITIVOS .. " aditivos, " .. #LEDS ..
      " con bodygroups de LED)")
