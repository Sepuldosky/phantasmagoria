#!/usr/bin/env python3
"""Trae al arbol de sonido los clips ORIGINALES de Phasmophobia.

    python -u dev/import_phasmo_audio.py --dry-run     # que haria, sin tocar nada
    python -u dev/import_phasmo_audio.py               # copia y verifica

Los 265 que ya estaban salieron de un rip de terceros (phasmo-sounds-main),
reencodeados a ogg q4. Esto trae los del juego, sacados con
`dev/phastools/araudio.py` del propio Phasmophobia: son el Vorbis ORIGINAL, asi
que se copian tal cual — reencodear ya-comprimido solo pierde.

=============================================================================
POR QUE EL INDICE DE VOZ ES CONFIABLE
=============================================================================
El mod usa el indice del archivo como IDENTIDAD de voz (voice_1 mas femenina,
voice_2 mas grave), y mezclar los indices da un fantasma que suena a dos
fantasmas sin ningun error visible.

Que el `Ghost 1` del juego sea el `voice_1` del mod NO se supuso: se midio.
Los archivos que ya estaban en el arbol resultaron ser LOS MISMOS clips.

    mod ghost/scare_light/voice_1.ogg   4.049 s == Ghost 1 (light attack)   4.049
    mod ghost/scare_light/voice_2.ogg   2.351 s == Ghost 2 (light attack)   2.351
    mod ghost/scare_strong/voice_2.ogg  3.997 s == Ghost 2 (strong attack)  3.997
    mod ghost/hurt/voice_2.ogg          2.064 s == Ghost 2 (damaged)        2.064
    mod ghost/hurt/voice_1.ogg          1.959 s == Ghost 1 (damaged)        1.959

La ultima empataba en duracion con otros nueve clips del juego, asi que se
resolvio por CONTENIDO: correlacion de la envolvente de energia, que sobrevive
el reencode a q4. Dio +0.9990 contra `Ghost 1 (damaged)` y +0.3585 contra el
segundo mejor.

Y el sexo: el autor escucho `voice_1.ogg` y lo describio como el mas femenino
(about.txt). Ese archivo ES `Ghost 1`. Por eso `Female_*` -> voz 1 y `Male_*`
-> voz 2, y no al reves.

**Lo que NO se pudo medir:** el tono no sirve para clasificar estos clips.
`voice_probe.py` separa limpio donde hay canto (Male Singing 78 Hz vs Female
Singing 151 Hz) y NO separa en respiracion (Male 262-401 Hz vs Female 344-356)
ni en hunt. Los ataques del fantasma tienen 2-7 % de tramas sonoras. La
identidad de voz de arriba sale del apareo de archivos, no del tono.
"""

import argparse
import csv
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.join(os.path.dirname(HERE), "sound", "phantasmagoria")
DUMP = os.path.abspath(os.path.join(
    os.path.dirname(HERE), "..", "dev", "phastools", "out", "audio"))

# =============================================================================
# LA TABLA. (patron de nombre en el juego, carpeta destino, plantilla de nombre)
#
# El patron es una regex ANCLADA contra el m_Name del clip. `{n}` en la
# plantilla se reemplaza por el grupo 1 de la regex si existe.
# Nada se resuelve por adivinanza: si un patron no matchea nada, es un ERROR.
# =============================================================================
TABLA = [
    # -- el hueco que el rip de terceros dejo abierto -------------------------
    # about.txt: "scare_strong SOLO tiene voice_2. Un fantasma con voz 1 no
    # tiene ataque fuerte y hay que degradarlo a scare_light". Ya no.
    (r"Ghost 1 \(strong attack\)",   "ghost/scare_strong",     "voice_1.ogg"),

    # -- accion NUEVA: el fantasma muriendo, una por voz ----------------------
    (r"Ghost 1 \(death\)",           "ghost/death",            "voice_1.ogg"),
    (r"Ghost 2 \(death\)",           "ghost/death",            "voice_2.ogg"),

    # -- hunt: habia UN archivo de 2,6 s; el juego tiene loops de 21 a 65 s ---
    (r"Female_Ghost_Hunting_(\d)",   "ghost/hunt",             "voice_1_loop_{n}.ogg"),
    (r"Male_Ghost_Hunting_(\d)",     "ghost/hunt",             "voice_2_loop_{n}.ogg"),
    (r"Male whispering hunt",        "ghost/hunt",             "voice_2_whispering.ogg"),
    (r"Male grim hunt",              "ghost/hunt",             "voice_2_grim.ogg"),
    (r"Ghost F inhales",             "ghost/hunt",             "voice_1_inhales.ogg"),

    # -- humming: el tarareo de la cajita musical, que about.txt ya describia -
    (r"Music box singing female",    "ghost/humming",          "voice_1_musicbox.ogg"),
    (r"Music Box singing male",      "ghost/humming",          "voice_2_musicbox.ogg"),
    (r"Female Singing",              "ghost/humming",          "voice_1_singing.ogg"),
    (r"Male Singing",                "ghost/humming",          "voice_2_singing.ogg"),

    # -- respiracion (accion nueva) ------------------------------------------
    (r"Female Breathing (\d)",       "ghost/breathing",        "voice_1_{n}.ogg"),
    (r"Male Breathing (\d)",         "ghost/breathing",        "voice_2_{n}.ogg"),
    (r"Deogen_breathing",            "ghost/breathing",        "deogen.ogg"),

    # -- la Banshee: 20 gritos cortos + el largo ------------------------------
    (r"Paramic_Banshee_Screams_(\d+)", "ghost/banshee_scream", "scream_{n}.ogg"),
    (r"Female banshee screams",      "ghost/banshee_scream",   "long_voice_1.ogg"),
    (r"Banshee para sound",          "ghost/banshee_scream",   "para.ogg"),

    # -- ParaSound: lo que el microfono parabolico oye decir al fantasma ------
    #    El juego los prefija M_ y F_, que por la cadena de arriba son voz 2 y 1
    (r"ParaSound_F_(.+)",            "ghost/paranormal_voice", "voice_1_{n}.ogg"),
    (r"ParaSound_M_(.+)",            "ghost/paranormal_voice", "voice_2_{n}.ogg"),
    (r"Dead Voices",                 "ghost/paranormal_voice", "dead_voices.ogg"),
    (r"Whispering Voices",           "ghost/paranormal_voice", "whispering_voices.ogg"),

    # -- spirit box: las 11 palabras que el juego TIENE HOY, con sus tomas ----
    #    Ver la nota de about.txt: el nombre sigue empezando por la palabra.
    (r"(Adult|Baby|Child|Kid|Young|Old|Dad|Mum|Son|Daughter|Away|Behind|Close"
     r"|Far|Here|Attack|Hate|Hurt|Kill|Die|Death|Next) ?(\d+)",
     "equipment/spiritbox_response", None),  # nombre especial, ver resolver()

    # -- la radio creepy, para el prop de radio ------------------------------
    (r"Creepy radio music$",                     "prop/radio", "creepy_music.ogg"),
    (r"Creepy radio music then news",            "prop/radio", "creepy_music_news.ogg"),
    (r"Creepy radio music 1 slow down static",   "prop/radio", "creepy_music_slowdown.ogg"),
    (r"Creepy radio normal and old music",       "prop/radio", "creepy_music_old.ogg"),
    (r"Creepy Radio news montage",               "prop/radio", "creepy_news.ogg"),
    (r"Creepy_radio_montage",                    "prop/radio", "creepy_montage.ogg"),
    (r"H24_Radio_Ritual_LOOP",                   "prop/radio", "ritual_loop.ogg"),
    (r"Easter25_Radio_Ritual-Chanting_LOOP",     "prop/radio", "ritual_chanting_loop.ogg"),

    # `Radio Static Noise` NO va en prop/radio: el diseno (seccion 7.1) lo pone
    # en el banco de INTERFERENCIA del hunt, junto a EMF Sound y Walkie Talkie
    # Static. Va a equipment/, donde el consumidor lo va a buscar.
    (r"Radio Static Noise",                      "equipment",  "radio_static_long.ogg"),

    # `Walkie Talkie Static` NO se importa: equipment/walkie_static.ogg ya
    # existe (19,684 s contra 19,665 s del juego). Un segundo archivo casi
    # identico en el mismo pool solo agrega una repeticion. Ver ABIERTO #14.

    # -- la cajita musical: es una de las 7 POSESIONES MALDITAS (§4 del
    #    diseno), no un trasto de la casa. Por eso vive en cursed/, no en prop/.
    (r"Music box open",              "cursed/musicbox",        "open.ogg"),
    (r"Music box close",             "cursed/musicbox",        "close.ogg"),
    (r"Music box clash",             "cursed/musicbox",        "clash.ogg"),
    (r"SFX_CursedObject_MusicBox_Drop_B_?(\d+)", "cursed/musicbox", "drop_{n}.ogg"),

    # -- muerte del jugador ---------------------------------------------------
    (r"SFX_PlayerDeath_?(\d+)",      "player",                 "death_{n}.ogg"),
    (r"SFX_PlayerDeathHang_?(\d+)",  "player",                 "death_hang_{n}.ogg"),
    (r"Player_Death_Animation_(\d+)", "player",                "death_animation_{n}.ogg"),
    (r"SFX_Revive_?(\d+)",           "player",                 "revive_{n}.ogg"),

    # =========================================================================
    # EQUIPAMIENTO POR TIER
    #
    # El juego escribe el mismo item de hasta CUATRO formas: Spiritbox_T1_Off,
    # T2_SpiritboxOff, T3_SpiritbixOff (con typo) y "Spirit box drop". Por eso
    # cada tier tiene su propio patron en vez de una regex "inteligente": una
    # sola regex que cubriera las cuatro tambien cubriria cosas que no son.
    # =========================================================================

    (r"EMF_T1_On",                   "equipment/emf",          "t1_on.ogg"),
    (r"EMF_T1_Off",                  "equipment/emf",          "t1_off.ogg"),
    (r"EMF_T1_2-4",                  "equipment/emf",          "t1_levels_2_4.ogg"),
    (r"EMF_T2_On",                   "equipment/emf",          "t2_on.ogg"),
    (r"EMF_T2_Off",                  "equipment/emf",          "t2_off.ogg"),
    (r"EMF_T3_On",                   "equipment/emf",          "t3_on.ogg"),
    (r"EMF_T3_Off",                  "equipment/emf",          "t3_off.ogg"),
    (r"EMF_T3_3",                    "equipment/emf",          "t3_level_3.ogg"),
    (r"EMF_T1_5",                    "equipment/emf",          "t1_level_5.ogg"),
    (r"EMF_T3_5",                    "equipment/emf",          "t3_level_5.ogg"),
    (r"EMF_Reader_T3_LVL5_longbeepx3_LOOP", "equipment/emf",   "t3_level_5_loop.ogg"),
    (r"EMF_Sound",                   "equipment/emf",          "sound.ogg"),
    # Los tres sin tier SI entran: MEDIDO que son tomas distintas de las T1, no
    # duplicados. Null-test alineado y con ganancia ajustada: EMF ON vs
    # EMF_T1_On da -2,8 dB con un control de -0,5 (misma duracion exacta, y la
    # correlacion de envolvente decia 0,85 -- ver ABIERTO #15).
    (r"EMF ON",                      "equipment/emf",          "on.ogg"),
    (r"EMF OFF",                     "equipment/emf",          "off.ogg"),
    (r"EMF 5",                       "equipment/emf",          "level_5.ogg"),

    (r"Spiritbox_T1_On",             "equipment/spiritbox",    "t1_on.ogg"),
    (r"Spiritbox_T1_Off",            "equipment/spiritbox",    "t1_off.ogg"),
    (r"Spiritbox_T1_Noise_Loop",     "equipment/spiritbox",    "t1_noise_loop.ogg"),
    (r"T2_SpiritboxOn",              "equipment/spiritbox",    "t2_on.ogg"),
    (r"T2_SpiritboxOff",             "equipment/spiritbox",    "t2_off.ogg"),
    (r"T3_SpiritbixOn",              "equipment/spiritbox",    "t3_on.ogg"),   # sic: Spiritbix
    (r"T3_SpiritbixOff",             "equipment/spiritbox",    "t3_off.ogg"),  # sic
    (r"Spirit box drop ?(\d*)",      "equipment/spiritbox",    "t1_drop_{n}.ogg"),
    (r"Spirit box 3 drop ?(\d*)",    "equipment/spiritbox",    "t3_drop_{n}.ogg"),

    (r"T2_ThermometerRecordTemp",    "equipment/thermometer",  "t2_record.ogg"),

    (r"Equipment_Ghost_writing_book_CLOSE_0\d_Tier_(I{1,3})",
     "equipment/ghost_book",         "close_tier_{n}.ogg"),

    (r"DOTS_T1_On",                  "equipment/dots",         "t1_on.ogg"),
    (r"DOTS_T1_Off",                 "equipment/dots",         "t1_off.ogg"),
    (r"DOTS_T2_On_Loop",             "equipment/dots",         "t2_on_loop.ogg"),
    (r"DOTS_T3_Turn",                "equipment/dots",         "t3_turn.ogg"),

    (r"UV_Light_T3_On",              "equipment/uv",           "t3_on.ogg"),
    (r"UV_Light_T3_Off",             "equipment/uv",           "t3_off.ogg"),

    (r"T([123])_FlashlightTurnOn",   "equipment/flashlight",   "t{n}_on.ogg"),
    (r"T([123])_FlashlightTurnOff",  "equipment/flashlight",   "t{n}_off.ogg"),
    # `Flashlight 2 on/off` NO son los T2: corr -0,01 y otra duracion. Son otro
    # clip, entra con nombre propio.
    (r"Flashlight 2 on",             "equipment/flashlight",   "alt_on.ogg"),
    (r"Flashlight 2 off",            "equipment/flashlight",   "alt_off.ogg"),
    (r"Flashlight Click",            "equipment/flashlight",   "click.ogg"),
    (r"Lantern turn on",             "equipment/flashlight",   "lantern_on.ogg"),
    (r"Lantern off",                 "equipment/flashlight",   "lantern_off.ogg"),
    (r"Lantern drop (\d+)",          "equipment/flashlight",   "lantern_drop_{n}.ogg"),

    # `Salt place 1..6` NO son los mismos clips que T1_SaltUse_01..06, aunque
    # las seis duraciones emparejen una a una y la envolvente diera 0,86-0,99.
    # Null-test alineado: -6 a -8,5 dB, con control -0,0. Son OTRAS TOMAS de la
    # misma accion. Entran los doce.
    (r"T1_SaltUse_(\d+)",            "equipment/salt",         "t1_use_{n}.ogg"),
    (r"Salt place (\d+)",            "equipment/salt",         "place_{n}.ogg"),

    (r"T([123])_CrucifixBurn",       "equipment/crucifix",     "t{n}_burn.ogg"),
    (r"Crucifix Burn Start",         "equipment/crucifix",     "burn_start.ogg"),
    (r"Crucifix burn loop",          "equipment/crucifix",     "burn_loop.ogg"),
    (r"Crucifix Turn ?(\d*)",        "equipment/crucifix",     "turn_{n}.ogg"),

    (r"Incense burn (\d+)",          "equipment/smudge",       "incense_burn_{n}.ogg"),
    (r"Smudge drop (\d+)",           "equipment/smudge",       "drop_{n}.ogg"),
    (r"Smudge 2 drop ?(\d*)",        "equipment/smudge",       "alt_drop_{n}.ogg"),

    (r"T1_FirelightBlow",            "equipment/firelight",    "t1_blow.ogg"),
    (r"T1_FirelightWick",            "equipment/firelight",    "t1_wick.ogg"),
    # `Candle wick burn` NO se importa: es la MISMA TOMA que T1_FirelightWick
    # con otra mezcla -- null-test alineado -32,5 dB con ganancia 1,00 y control
    # -2,8. Es el unico caso de todo el barrido donde la sospecha sobrevivio al
    # instrumento bueno. `Candle light` si es otro clip.
    (r"Candle light",                "equipment/firelight",    "light.ogg"),
    (r"Candle Blow (\d+)",           "equipment/firelight",    "blow_{n}.ogg"),

    (r"T1_IgniterLightMatch",        "equipment/igniter",      "t1_match.ogg"),
    (r"T1_IgniterLightMatchQuick",   "equipment/igniter",      "t1_match_quick.ogg"),
    (r"T2_IgniterOn",                "equipment/igniter",      "t2_on.ogg"),
    (r"T3_IgniterLight",             "equipment/igniter",      "t3_light.ogg"),
    (r"T3_IgniterClose",             "equipment/igniter",      "t3_close.ogg"),

    (r"T1_SanityMedsDrinkMeds",      "equipment/sanity_meds",  "t1_drink.ogg"),
    (r"T2_SanityMedsTakePills",      "equipment/sanity_meds",  "t2_pills.ogg"),
    (r"T3_SanityMedsAdrenalineShot", "equipment/sanity_meds",  "t3_adrenaline.ogg"),

    (r"Photo_Camera_T1_Flip_Up",     "equipment/photo_camera", "t1_flip_up.ogg"),
    (r"T1_PhotoCameraTakePhoto",     "equipment/photo_camera", "t1_take_photo.ogg"),
    (r"Photo_Camera_T2_Take_Photo",  "equipment/photo_camera", "t2_take_photo.ogg"),
    (r"Photo_Camera_T3_Take_Photo",  "equipment/photo_camera", "t3_take_photo.ogg"),

    (r"T1_VideoCameraVideoCamera_On",  "equipment/video_camera", "t1_on.ogg"),
    (r"T1_VideoCameraVideoCamera_Off", "equipment/video_camera", "t1_off.ogg"),
    (r"T1_VideoCameraRecordStart",     "equipment/video_camera", "t1_record_start.ogg"),
    (r"T1_VideoCameraRecordSuccess",   "equipment/video_camera", "t1_record_success.ogg"),
    (r"T1_VideoCameraNightVisionOn",   "equipment/video_camera", "t1_nightvision_on.ogg"),
    (r"T1_VideoCameraNightVisionOff",  "equipment/video_camera", "t1_nightvision_off.ogg"),
    (r"Video_Camera_T2_On",            "equipment/video_camera", "t2_on.ogg"),
    (r"Video_Camera_T2_Off",           "equipment/video_camera", "t2_off.ogg"),
    (r"Video_Camera_T2_Record_Start",  "equipment/video_camera", "t2_record_start.ogg"),
    (r"Video_Camera_T2_Record_Success", "equipment/video_camera", "t2_record_success.ogg"),
    (r"T2_VideoCameraNightVision_On",  "equipment/video_camera", "t2_nightvision_on.ogg"),
    (r"T2_VideoCameraNightVision_Off", "equipment/video_camera", "t2_nightvision_off.ogg"),
    (r"Video_Camera_T3_On",            "equipment/video_camera", "t3_on.ogg"),
    (r"Video_Camera_T3_Off",           "equipment/video_camera", "t3_off.ogg"),
    (r"Video_Camera_T3_Record_Start",  "equipment/video_camera", "t3_record_start.ogg"),
    (r"T3_VideoCameraNightVisionOn",   "equipment/video_camera", "t3_nightvision_on.ogg"),
    (r"T3_VideoCameraNightVisionOff",  "equipment/video_camera", "t3_nightvision_off.ogg"),

    (r"T3_HeadMountedNightVision_On",  "equipment/head_mounted_cam", "t3_nightvision_on.ogg"),
    (r"T3_HeadMountedNightVision_Off", "equipment/head_mounted_cam", "t3_nightvision_off.ogg"),
    (r"HeadgearI_Disturbance_SeamlessLoop_Ghost_interference_17s",
     "equipment/head_mounted_cam",   "interference_loop.ogg"),

    # `Paramic On/Off` NO son los T3 (corr -0,08 y +0,29, y otra duracion).
    (r"Paramic On",                  "equipment/paramic",      "on.ogg"),
    (r"Paramic Off",                 "equipment/paramic",      "off.ogg"),
    (r"T3_ParabolicMicrophoneOn",    "equipment/paramic",      "t3_on.ogg"),
    (r"T3_ParabolicMicrophoneOff",   "equipment/paramic",      "t3_off.ogg"),
    (r"ParaMic 1 drop ?(\d*)",       "equipment/paramic",      "t1_drop_{n}.ogg"),

    (r"Equipment_Sound_Recorder_Tier_1_ON_(\d+)", "equipment/sound_recorder", "t1_on_{n}.ogg"),
    (r"Equipment_Sound_Recorder_Tier_2_ON_(\d+)", "equipment/sound_recorder", "t2_on_{n}.ogg"),
    (r"Equipment_Sound_Recorder_Tier_3_ON_(\d+)", "equipment/sound_recorder", "t3_on_{n}.ogg"),
    (r"SoundRecorderTier2_Booting",    "equipment/sound_recorder", "t2_booting.ogg"),
    (r"SoundRecorderTier2_Success",    "equipment/sound_recorder", "t2_success.ogg"),
    (r"SoundRecorderTier3_Booting",    "equipment/sound_recorder", "t3_booting.ogg"),
    (r"SoundRecorderTier3_Celebrating", "equipment/sound_recorder", "t3_celebrating.ogg"),
    (r"SoundRecorderTier3_Shutdown",   "equipment/sound_recorder", "t3_shutdown.ogg"),
    (r"SoundRecorderTier3_Warning_(\d+)", "equipment/sound_recorder", "t3_warning_{n}.ogg"),

    (r"Tripod drop (\d+)",           "equipment/tripod",       "drop_{n}.ogg"),
    (r"Tripod motor turn",           "equipment/tripod",       "motor_turn.ogg"),

    (r"Glowstick Snap",              "equipment/glowstick",    "snap.ogg"),
    (r"Glowstick shake",             "equipment/glowstick",    "shake.ogg"),

    (r"Equipment_Button_Press_T([12])_Single", "equipment/button", "t{n}_press.ogg"),

    (r"Journal Open ?(\d*)",         "equipment/journal",      "open_{n}.ogg"),
    (r"JournalWritingSound",         "equipment/journal",      "writing.ogg"),
    (r"Page_turn_?(\d+)",            "equipment/journal",      "page_turn_{n}.ogg"),

    # =========================================================================
    # LAS 7 POSESIONES MALDITAS. Las SIETE tienen sonido en el juego.
    # =========================================================================
    (r"Voodoo Pin (\d+)",            "cursed/voodoo",          "pin_{n}.ogg"),
    (r"Voodoo Pin Heart (\d+)",      "cursed/voodoo",          "pin_heart_{n}.ogg"),

    (r"Summoning Circle Poof",       "cursed/summoning_circle", "poof.ogg"),

    (r"Ouija break",                 "cursed/ouija",           "break.ogg"),
    (r"SFX_OuijaBoard_Break",        "cursed/ouija",           "break_alt.ogg"),

    (r"SFX_Mirror_Smash3",           "cursed/mirror",          "smash.ogg"),
    (r"SFX_Interactable_Mirror_Light_Hum",     "cursed/mirror", "light_hum.ogg"),
    (r"SFX_Interactable_Mirror_Light_On-(\d+)", "cursed/mirror", "light_on_{n}.ogg"),
    (r"SFX_Interactable_Mirror_Light_Off-(\d+)", "cursed/mirror", "light_off_{n}.ogg"),

    (r"Paw twitch (\d+)",            "cursed/monkey_paw",      "twitch_{n}.ogg"),
    (r"monkey paw thud (\d+)",       "cursed/monkey_paw",      "thud_{n}.ogg"),
    (r"SFX_Monkey-Paw_PropDrop_(\d+)", "cursed/monkey_paw",    "drop_{n}.ogg"),

    (r"Tarot draw (\d+)",            "cursed/tarot",           "draw_{n}.ogg"),
    (r"Diner_PCPlayer_Tarot_Deck_Prop_Drop_(\d+)", "cursed/tarot", "deck_drop_{n}.ogg"),

    # =========================================================================
    # LA VOZ DEL ENCARGADO (el britanico). CORREGIDO POR EL AUTOR 2026-08-03.
    #
    # `Cursed Voiceover 1..3` NO son los objetos malditos hablando: son el
    # ENCARGADO avisando que hay un objeto maldito en la casa, en la briefing
    # de llegada. Lo escucho el autor y transcribio las tres (ver about.txt).
    # Yo las habia puesto en cursed/ por el nombre -- el nombre decia de que
    # HABLAN, no QUIEN habla.
    # =========================================================================
    (r"Cursed Voiceover (\d+)",      "voice",                  "hint_cursed_object_{n}.ogg"),

    # Las `Arrival 1/2` del juego NO son las `arrival_1/2` del rip: 5,58 y 3,91 s
    # contra 8,72 y 6,26 s. Son otras grabaciones del mismo momento, no el mismo
    # archivo -- por eso entran con nombre propio en vez de pisar nada.
    (r"Arrival (\d+)",               "voice",                  "arrival_short_{n}.ogg"),
    (r"Good job ?(\d*)",             "voice",                  "good_job_{n}.ogg"),
    (r"Training Intro",              "voice",                  "training_intro.ogg"),
]

SPIRITBOX_PAT = re.compile(
    r"^(Adult|Baby|Child|Kid|Young|Old|Dad|Mum|Son|Daughter|Away|Behind|Close"
    r"|Far|Here|Attack|Hate|Hurt|Kill|Die|Death|Next) ?(\d+)$", re.I)


def slug(s):
    s = re.sub(r"[^A-Za-z0-9]+", "_", s).strip("_").lower()
    return re.sub(r"_+", "_", s)


def cargar_manifest():
    p = os.path.join(DUMP, "manifest.csv")
    if not os.path.exists(p):
        sys.exit(f"no existe {p}\ncorrer antes: python -u dev/phastools/araudio.py dump out\\audio")
    with open(p, encoding="utf-8") as f:
        return [r for r in csv.DictReader(f) if r["archivo"]]


def resolver(rows):
    """Devuelve [(origen_abs, destino_rel, nombre_juego, segundos)] y los errores."""
    plan, errores, vistos = [], [], {}
    for patron, carpeta, plantilla in TABLA:
        rx = re.compile("^" + patron + "$", re.I)
        hits = [r for r in rows if rx.match(r["name"].strip())]
        if not hits:
            errores.append(f"patron sin coincidencias: {patron!r}")
            continue
        for r in hits:
            nombre = r["name"].strip()
            if plantilla is None:  # spirit box
                m = SPIRITBOX_PAT.match(nombre)
                if not m:
                    errores.append(f"spiritbox no parsea: {nombre!r}")
                    continue
                destino = f"{m.group(1).lower()}_{int(m.group(2)):02d}.ogg"
            else:
                m = rx.match(nombre)
                g = m.group(1) if m.lastindex else ""
                # Un grupo VACIO es la primera toma sin numerar ("Crucifix Turn"
                # y "Crucifix Turn 2"): sin esto queda un "turn_.ogg".
                n = "01" if g == "" else (f"{int(g):02d}" if g.isdigit() else slug(g))
                destino = plantilla.replace("{n}", n)
            rel = f"{carpeta}/{destino}"
            if rel in vistos:
                errores.append(f"COLISION {rel}: {vistos[rel]!r} y {nombre!r}")
                continue
            vistos[rel] = nombre
            plan.append((os.path.join(DUMP, r["archivo"].replace("/", os.sep)),
                         rel, nombre, float(r["segundos"] or 0)))
    return plan, errores


def dur(p):
    o = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                        "-of", "default=nw=1:nk=1", p], capture_output=True, text=True)
    try:
        return float(o.stdout.strip())
    except ValueError:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-verify", action="store_true")
    a = ap.parse_args()

    rows = cargar_manifest()
    plan, errores = resolver(rows)

    if errores:
        print("ERRORES DE RESOLUCION (nada se copio):")
        for e in errores:
            print("  " + e)
        return 1

    porc = {}
    for _o, rel, _n, s in plan:
        c = rel.rsplit("/", 1)[0]
        porc.setdefault(c, [0, 0.0])
        porc[c][0] += 1
        porc[c][1] += s
    print(f"{len(plan)} clips a importar, {sum(v[1] for v in porc.values())/60:.1f} min de audio\n")
    for c, (n, s) in sorted(porc.items()):
        nuevo = "" if os.path.isdir(os.path.join(MOD, c.replace("/", os.sep))) else "   (CARPETA NUEVA)"
        print(f"  {n:4d}  {s/60:6.1f} min  {c}{nuevo}")

    if a.dry_run:
        print("\n--dry-run: no se copio nada. Detalle:")
        for _o, rel, nom, s in sorted(plan, key=lambda t: t[1]):
            print(f"    {rel:<52} <- {nom[:44]:<44} {s:6.2f}s")
        return 0

    print()
    copiados = 0
    for origen, rel, _nom, _s in plan:
        destino = os.path.join(MOD, rel.replace("/", os.sep))
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        shutil.copy2(origen, destino)
        copiados += 1
    print(f"copiados: {copiados}")

    if a.no_verify:
        return 0

    # Verificacion: el archivo existe, pesa, y su duracion REAL coincide con la
    # que Unity declara. Copiar es barato de hacer mal y caro de descubrir.
    print("\nverificando...")
    malos = []
    for _o, rel, nom, s in plan:
        p = os.path.join(MOD, rel.replace("/", os.sep))
        if not os.path.exists(p) or os.path.getsize(p) == 0:
            malos.append((rel, "no existe o vacio"))
            continue
        d = dur(p)
        if d is None:
            malos.append((rel, "no se puede leer la duracion"))
        elif s > 0 and abs(d - s) > 0.05:
            malos.append((rel, f"duracion {d:.3f}s != {s:.3f}s de {nom!r}"))
    if malos:
        print(f"FALLAS: {len(malos)}")
        for rel, why in malos[:20]:
            print(f"  {rel:<52} {why}")
        return 1
    print(f"OK: {len(plan)}/{len(plan)} existen y su duracion coincide con la del juego")
    return 0


if __name__ == "__main__":
    sys.exit(main())
