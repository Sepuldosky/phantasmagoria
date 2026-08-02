# -*- coding: utf-8 -*-
import json, re, io, os

SRC = os.path.join(os.path.dirname(__file__), "g2.json")
OUT = r"d:\Documentos\Materia universidad\Personal\Corpus\VSCode\phantasmagoria\lua\phantasmagoria\ghost_types.lua"

d = json.load(io.open(SRC, encoding="utf-8"))
ghosts = d["ghosts"]

def clean(s):
    s = re.sub(r"<[^>]+>", "", str(s))
    s = s.replace("\u2013", "-").replace("\u2014", "-").replace("\u2019", "'")
    s = s.replace("\u201c", '"').replace("\u201d", '"').replace("\u00a0", " ")
    # fuera emojis y todo lo no-ASCII: el archivo lo lee GMod, no un navegador
    s = "".join(c if ord(c) < 128 else " " for c in s)
    return " ".join(s.split()).strip()

def wrap(s, width=94):
    """Corta por PALABRAS, no a la mitad de una."""
    out, cur = [], ""
    for word in s.split():
        if cur and len(cur) + 1 + len(word) > width:
            out.append(cur); cur = word
        else:
            cur = (cur + " " + word).strip()
    if cur:
        out.append(cur)
    return out

def lua_str(s):
    return '"' + clean(s).replace("\\", "\\\\").replace('"', '\\"') + '"'

def key(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")

EVI = {
    "EMF 5": "emf5", "DOTs": "dots", "Ultraviolet": "uv", "Freezing": "freezing",
    "Ghost Orbs": "orbs", "Writing": "writing", "Spirit Box": "spiritbox",
}

BASE = 1.7  # m/s del Spirit: la unidad de referencia para los multiplicadores

lines = []
w = lines.append
w("--[[-------------------------------------------------------------------------")
w("    Phantasmagoria - Tabla de los 30 tipos de fantasma")
w("")
w("    GENERADO AUTOMATICAMENTE. No editar a mano: regenerar con dev/gen_types.py")
w("    Fuente: zero-network.net/phasmophobia/data/ghosts.json (el backend del")
w("            cheat sheet de tybayn). Datos del juego, no inventados.")
w("")
w("    speed.* son MULTIPLICADORES de la carrera del jugador, no m/s absolutos.")
w("    Se calculan como (m/s del juego) / 1.7, donde 1.7 m/s es el Spirit.")
w("    Con Better Movement en run=280, un Spirit corre a 280 u/s.")
w("    Ver PHANTOM_Phasmophobia_Diseno.md seccion 1.1.")
w("")
w("    hunt.threshold es el % de cordura por debajo del cual el tipo puede cazar.")
w("---------------------------------------------------------------------------]]")
w("")
w("PHANTASMAGORIA = PHANTASMAGORIA or {}")
w("PHANTASMAGORIA.Types = {}")
w("")
w("local T = PHANTASMAGORIA.Types")
w("")

for g in sorted(ghosts, key=lambda x: x["ghost"]):
    k = key(g["ghost"])
    mn, mx, alt = g["min_speed"], g["max_speed"], g["alt_speed"]
    w("T[ %-14s ] = {" % lua_str(k))
    w("    name      = %s," % lua_str(g["name"]))
    w("    evidence  = { %s }," % ", ".join(lua_str(EVI.get(e, key(e))) for e in g["evidence"]))

    # velocidad
    w("    speed = {")
    w("        base      = %.3f,   -- %.2f m/s" % (mn / BASE, mn))
    if mx is not None:
        tag = "rango continuo" if g["speed_is_range"] else "alterna entre los dos"
        w("        top       = %.3f,   -- %.2f m/s (%s)" % (mx / BASE, mx, tag))
        w("        isRange   = %s," % ("true" if g["speed_is_range"] else "false"))
    if alt is not None:
        w("        alt       = %.3f,   -- %.2f m/s" % (alt / BASE, alt))
    w("        losSpeedUp = %s,  -- acelera con linea de vista" % ("true" if g["has_los"] else "false"))
    w("    },")

    # hunt
    hs = g["hunt_sanity"]
    lo, hi = g["hunt_sanity_low"], g["hunt_sanity_high"]
    w("    hunt = {")
    w("        threshold = %s," % (hs.replace("%", "") if "%" in str(hs) else str(hs)))
    if lo != hs or hi != hs:
        w("        thresholdLow  = %s," % str(lo).replace("%", ""))
        w("        thresholdHigh = %s," % str(hi).replace("%", ""))
    w("    },")

    # notas del juego -> texto, para que el implementador sepa que rasgo hace falta
    notes = []
    for sec in ("abilities", "behaviors", "tells"):
        for it in (g["wiki"].get(sec) or []):
            t = clean(it.get("data", it) if isinstance(it, dict) else it)
            if t:
                notes.append(t)
    if notes:
        w("    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):")
        for n in notes[:8]:
            for j, chunk in enumerate(wrap(n)):
                w("    --   %s%s" % ("" if j == 0 else "  ", chunk))
    w("}")
    w("")

w("-- Indice estable para UI y para el sorteo")
w("PHANTASMAGORIA.TypeOrder = {")
for g in sorted(ghosts, key=lambda x: x["ghost"]):
    w("    %s," % lua_str(key(g["ghost"])))
w("}")
w("")
w("return PHANTASMAGORIA.Types")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
io.open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
print("escrito:", OUT)
print("tipos:", len(ghosts), "| lineas:", len(lines))
