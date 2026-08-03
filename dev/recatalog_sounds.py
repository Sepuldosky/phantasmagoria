# -*- coding: utf-8 -*-
"""Recataloga el arbol de sonido con las identificaciones del autor (2026-08-03).

Continuacion de organize_sounds.py. Aquel mapeo SOLO renombro lo que el nombre
original justificaba sin adivinar, y dejo 46 archivos en _sin_identificar/.
El autor los escucho y los describio uno por uno; esto los mueve, y ademas
corrige lo que estaba mal catalogado en la primera pasada.

Idempotente: si un origen no existe, se saltea (no falla).
"""
import os, shutil, sys

ROOT = r"d:\Documentos\Materia universidad\Personal\Corpus\VSCode\phantasmagoria\sound\phantasmagoria"
UNK = "_sin_identificar"

# ---------------------------------------------------------------------------
# 1. Los 46 de _sin_identificar/, segun lo que el autor dice que se oye.
# ---------------------------------------------------------------------------

# Las 22 palabras del Spirit Box. El autor: "es literal al nombre, adult.ogg es
# decir 'adult'", voz masculina. Van PLANAS: agruparlas por tema (edad /
# parentesco / lugar / amenaza) seria mi categorizacion, no su medicion. El
# nombre de archivo ES la palabra, asi que el Lua puede agrupar cuando decida.
SPIRITBOX = [
    "adult", "baby", "child", "kid", "young", "old",
    "dad", "mum", "son", "daughter",
    "away", "behind", "close", "far", "here",
    "attack", "hate", "hurt", "kill", "die", "death",
    "next",
]

MOVES = [(UNK + "/" + w + ".ogg", "equipment/spiritbox_response/" + w + ".ogg")
         for w in SPIRITBOX] + [

    # -- equipo del jugador -------------------------------------------------
    # "beep que se escucha cuando un fantasma o ghosthunter pasa por un sensor
    #  de movimiento" -> el motion sensor, que ya tiene modelo en el arbol.
    (UNK + "/beep.ogg",                 "equipment/motion_sensor_beep.ogg"),

    # -- el fantasma --------------------------------------------------------
    # "el sonido que hace el fantasma mientras esta de caceria, como que
    #  expulsa saliva constantemente junto con el aire de los pulmones".
    (UNK + "/clicker_idle_26.ogg",      "ghost/hunt/breath_1.ogg"),

    # "ambos son cuando el fantasma se te acerca y te come la cordura".
    # ghost_1 suena mas femenino, ghost_2 mas grave: el indice ES la voz, y
    # mantenerlo igual entre carpetas es lo que hace que UN fantasma suene a UN
    # fantasma. La carpeta sigue siendo la accion, como en todo el arbol.
    (UNK + "/ghost_1_light_attack.ogg", "ghost/scare_light/voice_1.ogg"),
    (UNK + "/ghost_2_light_attack.ogg", "ghost/scare_light/voice_2.ogg"),
    # "un soplido intenso y largo como enojado" - la voz 1 NO tiene equivalente.
    (UNK + "/ghost_2_strong_attack.ogg", "ghost/scare_strong/voice_2.ogg"),
    # "suenan como que le pegaras un punetazo al fantasma en el estomago".
    (UNK + "/ghost_1_damaged.ogg",      "ghost/hurt/voice_1.ogg"),
    (UNK + "/ghost_2_damaged.ogg",      "ghost/hurt/voice_2.ogg"),
    # "canto fantasmagorico... suena con la cajita musical o cuando el fantasma
    #  hace un evento de aparicion, donde camina demostrandose".
    (UNK + "/manhumming.ogg",           "ghost/humming/male.ogg"),
    (UNK + "/womanhumming.ogg",         "ghost/humming/female.ogg"),

    # -- el jugador ---------------------------------------------------------
    # "el loop que suena cuando estas muerto en el juego y te mueves como un
    #  fantasma mas". Candidato para la otra dimension.
    (UNK + "/deathzoneloop.ogg",        "player/dead_loop.ogg"),

    # -- mundo --------------------------------------------------------------
    # "sonido ambiental tipo humming al estar en el interior de la casa".
    (UNK + "/maintoneloop.ogg",         "ambience/house_tone_loop.ogg"),
    # "sonido metalico de movimiento, probablemente una puerta": 1 se acerca,
    # 2 se aleja. El "probablemente" es del autor y queda anotado.
    (UNK + "/metalwhine1.ogg",          "door/metal_whine_1.ogg"),
    (UNK + "/metalwhine2.ogg",          "door/metal_whine_2.ogg"),
    # "una cuerda de guitarra, probablemente tocada por el fantasma".
    (UNK + "/guitarsound.ogg",          "prop/guitar_string.ogg"),
    # "risa pequena y tenue... el sonido de los peluches que hay en la
    #  habitacion del bebe de la primera casa".
    (UNK + "/bearlaugh.ogg",            "prop/teddy_laugh.ogg"),

    # -- interfaz -----------------------------------------------------------
    # "es literal el sonido de apagado". Hermano de button_toggle_1.
    (UNK + "/butto_on_off_2.ogg",       "ui/button_toggle_2.ogg"),

    # -- la voz del encargado ------------------------------------------------
    # "una voz britanica del ayudante de la compania de cazafantasmas, da
    #  informacion util sobre el caso al llegar al lugar". Mismo hablante que
    #  arrival / welcome_back / lobby / menu_intro, que estaban en ui/.
    (UNK + "/hint_aggressive_ghost.ogg",     "voice/hint_aggressive_ghost.ogg"),
    (UNK + "/hint_friendly_ghost.ogg",       "voice/hint_friendly_ghost.ogg"),
    (UNK + "/hint_friendly_ghost_2.ogg",     "voice/hint_friendly_ghost_2.ogg"),
    (UNK + "/hint_non_friendly_ghost_1.ogg", "voice/hint_non_friendly_ghost_1.ogg"),
    (UNK + "/hint_non_friendly_ghost_2.ogg", "voice/hint_non_friendly_ghost_2.ogg"),
    (UNK + "/hint_none.ogg",                 "voice/hint_none.ogg"),
    (UNK + "/hint_none_2.ogg",               "voice/hint_none_2.ogg"),
    (UNK + "/hint_none_3.ogg",               "voice/hint_none_3.ogg"),
]

# ---------------------------------------------------------------------------
# 2. Correcciones sobre lo que la primera pasada ya habia mapeado.
# ---------------------------------------------------------------------------

# 2.a  ghost/footstep/ -> el autor los reconoce como pasos DEL JUGADOR.
#      Medido antes de mover: NO son los mismos archivos que carpet_1..8
#      (16 hashes distintos, y el null-test da corr 0,32-0,80, dentro del ruido
#      de los controles cruzados: no es una copia con ganancia). Pero las
#      duraciones emparejan una a una (delta 2-11 ms en 7 de 8) y este set esta
#      ~10 dB mas fuerte (media -17..-25 dB vs -27..-35 dB): misma superficie,
#      mezcla fuerte. Por eso "carpet_loud" y no "carpet_9..16": juntarlos en un
#      solo pool haria saltar 13 dB entre pisada y pisada.
MOVES += [("ghost/footstep/carpet_%d.ogg" % i,
           "player/footstep/carpet_loud_%d.ogg" % i) for i in range(1, 9)]

# 2.b  "remote_click -> boton remoto de un control, probablemente apagan una
#      tv". Es un trasto de la casa, no interfaz: se va con tv_on/tv_off.
MOVES += [("ui/remote_click.ogg", "prop/tv_remote.ogg")]

# 2.c  ui/ eran dos cosas mezcladas: clicks de interfaz y las lineas habladas
#      del encargado. Las lineas se van a voice/ con los 8 hint.
MOVES += [("ui/%s.ogg" % n, "voice/%s.ogg" % n) for n in [
    "arrival_1", "arrival_2",
    "lobby_found_players_1", "lobby_found_players_2",
    "lobby_no_players_1", "lobby_no_players_2",
    "menu_intro",
    "welcome_back_1", "welcome_back_2", "welcome_back_3",
]]


def main():
    moved = skipped = 0
    collisions = []

    for src_rel, dst_rel in MOVES:
        src = os.path.join(ROOT, src_rel.replace("/", os.sep))
        dst = os.path.join(ROOT, dst_rel.replace("/", os.sep))
        if not os.path.exists(src):
            skipped += 1
            continue
        if os.path.exists(dst):
            collisions.append((src_rel, dst_rel))
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.move(src, dst)
        moved += 1
        print("  %-42s -> %s" % (src_rel, dst_rel))

    if collisions:
        print("\nCOLISIONES (no se toco nada):")
        for a, b in collisions:
            print("   %s -> %s YA EXISTE" % (a, b))

    # carpetas que quedan vacias
    for rel in (UNK, "ghost/footstep"):
        d = os.path.join(ROOT, rel.replace("/", os.sep))
        if os.path.isdir(d):
            rest = [f for f in os.listdir(d) if f != "about.txt"]
            if not rest:
                shutil.rmtree(d)
                print("\nVACIADA Y BORRADA: %s/" % rel)
            else:
                print("\nNO VACIA, se deja: %s/ -> %s" % (rel, rest))

    print("\nmovidos: %d   salteados (ya movidos): %d   colisiones: %d"
          % (moved, skipped, len(collisions)))
    return 1 if collisions else 0


sys.exit(main())
