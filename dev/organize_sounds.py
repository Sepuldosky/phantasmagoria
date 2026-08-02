# -*- coding: utf-8 -*-
"""Organiza los .ogg de Phasmophobia en el arbol de Phantasmagoria.

Convencion Corpus: carpeta por accion, about.txt explicando cada una.
SOLO renombra lo que el nombre original justifica sin adivinar.
Todo lo ambiguo va a _sin_identificar/ y se lista para que el autor lo describa.
"""
import os, re, shutil, io

SRC = r"d:\Documentos\Materia universidad\Personal\Corpus\VSCode\dev\other\phantom\dev2\phasmo-sounds-ogg"
DST = r"d:\Documentos\Materia universidad\Personal\Corpus\VSCode\phantasmagoria\sound\phantasmagoria"

# (regex sobre el nombre original sin .ogg)  ->  (subcarpeta, plantilla)
# \1 \2 ... son los grupos capturados. "#" se reemplaza por el numero normalizado.
RULES = [
    # ---- pasos ----
    (r"^ghostfootstepcarpet(\d+)$",                 "ghost/footstep",  "carpet_#"),
    (r"^footstepcarpet(\d+)$",                      "player/footstep", "carpet_#"),
    (r"^footstep_asphalt_trainers_walk_slow_rr(\d+)_mono$", "player/footstep", "asphalt_#"),
    (r"^footstep_trainers_gravel_compact_walk_slow_rr(\d+)_mono$", "player/footstep", "gravel_#"),
    (r"^footstep_trainers_wood_boards_walk_rr(\d+)_mono$", "player/footstep", "wood_#"),
    (r"^footsteps_trainers_gravel_compact_walk_slow_x8_loop_mono$", "player/footstep", "gravel_loop"),
    (r"^stairs_footsteps?_?(\d+)$",                 "player/footstep", "stairs_#"),
    (r"^underneath_stairs_footsteps_(\d+)$",        "player/footstep", "stairs_under_#"),

    # ---- eventos fisicos ----
    (r"^throwing_(\d+)$",                           "event/throw",   "throw_#"),
    (r"^wood_impact_(\d+)$",                        "event/impact",  "wood_impact_#"),
    (r"^wood-(\d+)$",                               "event/impact",  "wood_#"),
    (r"^metal-pipe-(\d+)$",                         "event/impact",  "metal_pipe_#"),
    (r"^impact_metal_deep_smooth_mono$",            "event/impact",  "metal_deep"),
    (r"^impact_metal_pipe_hits_pipe_mono$",         "event/impact",  "metal_pipe_hit"),
    (r"^impact_metal_tank_stick_rr1_mono$",         "event/impact",  "metal_tank"),
    (r"^impact_stone_on_stone_04_subtle_mono$",     "event/impact",  "stone"),
    (r"^break_slow_stereo$",                        "event/impact",  "break_slow"),
    (r"^lightbulbsmashsfx$",                        "event/impact",  "lightbulb_smash"),

    # ---- crujidos y golpeteo ----
    (r"^creak_floorboard_(\d+)_sound_effect$",      "event/creak",   "floorboard_#"),
    (r"^boardwoodscraping$",                        "event/creak",   "board_scrape"),
    (r"^rope_squeak_sound$",                        "event/creak",   "rope_squeak"),
    (r"^squeak_metal_hinge_04_mono$",               "event/creak",   "metal_hinge"),
    (r"^foley_metal_fence_shake_very_subtle_mono$", "event/creak",   "fence_shake_1"),
    (r"^foley_metal_fence_shake_subtle_mono$",      "event/creak",   "fence_shake_2"),
    (r"^foley_metal_fence_shake_mono$",             "event/creak",   "fence_shake_3"),
    (r"^doorknocking$",                             "event/knock",   "door"),
    (r"^window_knocking_(\d+)$",                    "event/knock",   "window_#"),

    # ---- puertas ----
    (r"^door_close_(\d+)$",                         "door",          "close_#"),
    (r"^door_handle_open_(\d+)$",                   "door",          "handle_open_#"),
    (r"^door_indoor_wood_close_gentle_stereo$",     "door",          "close_gentle"),
    (r"^door_indoor_wood_close_stereo$",            "door",          "close_wood"),
    (r"^door_loop$",                                "door",          "move_loop"),
    (r"^celldoorclose_(\d+)$",                      "door",          "cell_close_#"),
    (r"^sliding_metal_door_loop$",                  "door",          "sliding_metal_loop"),

    # ---- muebles ----
    (r"^cabinet_close_(\d+)$",                      "furniture",     "cabinet_close_#"),
    (r"^cabinet_loop$",                             "furniture",     "cabinet_loop"),
    (r"^drawers_close_(\d+)$",                      "furniture",     "drawers_close_#"),
    (r"^drawers_loop$",                             "furniture",     "drawers_loop"),

    # ---- luces / electricidad ----
    (r"^lightswitch_(\d+)$",                        "light",         "switch_#"),
    (r"^light_humming$",                            "light",         "humming_loop"),

    # ---- equipamiento del jugador ----
    (r"^emf_sound$",                                "equipment",     "emf_beep"),
    (r"^evp_white_noise_loop$",                     "equipment",     "spiritbox_noise_loop"),
    (r"^radio_static_noise$",                       "equipment",     "radio_static"),
    (r"^walkie_talkie_on$",                         "equipment",     "walkie_on"),
    (r"^walkie_talkie_static$",                     "equipment",     "walkie_static"),
    (r"^flashlight_click$",                         "equipment",     "flashlight_click"),
    (r"^journal_open_(\d+)$",                       "equipment",     "journal_open_#"),
    (r"^journalwritingsound$",                      "equipment",     "journal_writing"),
    (r"^camerataken?$",                             "equipment",     "camera_take"),
    (r"^camera_dslr_button_off_02_mono$",           "equipment",     "camera_button"),
    (r"^crucifixburn$",                             "equipment",     "crucifix_burn"),
    (r"^lighter_click$",                            "equipment",     "lighter_click"),
    (r"^candle_blow_2$",                            "equipment",     "candle_blow"),
    (r"^pills_(\d+)$",                              "equipment",     "pills_#"),

    # ---- jugador ----
    (r"^heartbeat_loop_2$",                         "player",        "heartbeat_loop"),
    (r"^death_jumpscare_riser$",                    "player",        "death_riser"),
    (r"^player_dying_sfx$",                         "player",        "dying"),

    # ---- ambiente ----
    (r"^thunder_clap_rumble_(\d+)_stereo$",         "ambience",      "thunder_rumble_#"),
    (r"^thunderclap_([acd])$",                      "ambience",      "thunder_clap_\\1"),
    (r"^rain$",                                     "ambience",      "rain"),
    (r"^window_rain_audio$",                        "ambience",      "rain_window"),
    (r"^nights_ambience_neighborhood$",             "ambience",      "night_neighborhood"),
    (r"^ambience_forest_wind_14sec_loop_stereo$",   "ambience",      "forest_wind_loop"),
    (r"^dark_cinematic_horror_room_tone_2$",        "ambience",      "room_tone"),

    # ---- props de la casa ----
    (r"^tv_on$",                                    "prop",          "tv_on"),
    (r"^tv_off$",                                   "prop",          "tv_off"),
    (r"^tv_noise$",                                 "prop",          "tv_noise"),
    (r"^phonering$",                                "prop",          "phone_ring"),
    (r"^mobile_vibration$",                         "prop",          "phone_vibrate"),
    (r"^fridge_loop$",                              "prop",          "fridge_loop"),
    (r"^sink_loop$",                                "prop",          "sink_loop"),
    (r"^toilet_flush_model_01_mono$",               "prop",          "toilet_flush"),
    (r"^clock_ticking$",                            "prop",          "clock_tick"),
    (r"^ceilingfan$",                               "prop",          "ceiling_fan"),
    (r"^microwave_beep$",                           "prop",          "microwave_beep"),
    (r"^elevator_loop_short$",                      "prop",          "elevator_loop"),
    (r"^caralarm$",                                 "prop",          "car_alarm"),
    (r"^carlock$",                                  "prop",          "car_lock"),
    (r"^pianokey(\d+)$",                            "prop",          "piano_key_#"),
    (r"^key_(\d+)$",                                "prop",          "key_#"),
    (r"^key_pickup_(\d+)$",                         "prop",          "key_pickup_#"),
    (r"^key_lock_(\d+)$",                           "prop",          "key_lock_#"),
    (r"^key_unlock_(\d+)$",                         "prop",          "key_unlock_#"),

    # ---- interfaz / menu del juego (probablemente no se usen) ----
    (r"^truckexitsoundeffect$",                     "ui",            "truck_exit"),
    (r"^truckstopexitsoundeffect$",                 "ui",            "truck_stop_exit"),
    (r"^lobby_found_players_(\d+)$",                "ui",            "lobby_found_players_#"),
    (r"^lobby_no_players_(\d+)$",                   "ui",            "lobby_no_players_#"),
    (r"^welcome_back_(\d+)$",                       "ui",            "welcome_back_#"),
    (r"^main_menu_first_session_introduction$",     "ui",            "menu_intro"),
    (r"^arrival_(\d+)$",                            "ui",            "arrival_#"),
    (r"^button_click_1$",                           "ui",            "button_click"),
    (r"^button_on_off_1$",                          "ui",            "button_toggle_1"),
    (r"^remote_click$",                             "ui",            "remote_click"),
]

def main():
    files = sorted(f for f in os.listdir(SRC) if f.endswith(".ogg"))
    mapped, ambiguous = [], []

    for f in files:
        stem = f[:-4]
        hit = None
        for pat, folder, tmpl in RULES:
            m = re.match(pat, stem)
            if m:
                name = tmpl
                if "#" in name:
                    num = m.group(1)
                    name = name.replace("#", str(int(num)) if num.isdigit() else num)
                if "\\1" in name:
                    name = name.replace("\\1", m.group(1))
                hit = (folder, name + ".ogg")
                break
        if hit:
            mapped.append((f, hit[0], hit[1]))
        else:
            ambiguous.append(f)

    # copiar
    for src_name, folder, dst_name in mapped:
        d = os.path.join(DST, folder)
        os.makedirs(d, exist_ok=True)
        shutil.copy2(os.path.join(SRC, src_name), os.path.join(d, dst_name))

    d = os.path.join(DST, "_sin_identificar")
    os.makedirs(d, exist_ok=True)
    for f in ambiguous:
        shutil.copy2(os.path.join(SRC, f), os.path.join(d, f))

    print("MAPEADOS: %d" % len(mapped))
    print("AMBIGUOS: %d" % len(ambiguous))
    folders = {}
    for _, folder, _ in mapped:
        folders[folder] = folders.get(folder, 0) + 1
    for k in sorted(folders):
        print("   %-20s %3d" % (k, folders[k]))
    print("\n--- AMBIGUOS (van a _sin_identificar/) ---")
    for f in ambiguous:
        print("   ", f)

    io.open(os.path.join(os.path.dirname(__file__), "ambiguos.txt"), "w", encoding="utf-8").write(
        "\n".join(ambiguous))

main()
