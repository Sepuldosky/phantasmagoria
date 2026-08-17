"""
Audita TODOS los hook.Add de un arbol .lua: por cada uno, extrae el cuerpo del
callback y reporta si hay un `return <valor>` (no un `return` pelado).

Un `return <valor>` desde un hook ABORTA la cadena y se saltea la funcion del
gamemode (hook.lua, `Call`). En algunos hooks eso es la semantica querida
(ShouldCollide, PlayerCanPickup*); en otros es un defecto.

El script NO decide cual es cual -- clasifica el hook por su lista y deja el
juicio escrito al lado. Imprime el DENOMINADOR.
"""
import re, sys, pathlib

# hooks donde devolver un valor es la semantica INTENCIONAL del hook
RETORNO_ES_LA_API = {
    "ShouldCollide", "PlayerCanPickupItem", "PlayerCanPickupWeapon",
    "PlayerSpawnProp", "PlayerSpawnSENT", "PlayerSpawnNPC", "PlayerSpawnEffect",
    "PlayerSpawnRagdoll", "PlayerSpawnVehicle", "PlayerSpawnSWEP", "PlayerGiveSWEP",
    "CanPlayerSuicide", "PlayerDeathThink", "GravGunPickupAllowed",
    "PhysgunPickup", "OnPhysgunPickup", "CanTool", "CanProperty", "CanEditVariable",
    "PlayerNoClip", "PlayerUse", "PlayerSwitchWeapon", "AllowPlayerPickup",
    "TerminatorBlockUse", "GetFallDamage", "EntityTakeDamage", "ScalePlayerDamage",
    "PlayerShouldTaunt", "SetupMove", "CreateMove", "StartCommand",
}
# hooks donde devolver un valor DEJA SIN CORRER a la funcion del gamemode
# y/o a los demas addons, sin ninguna ganancia
RETORNO_ES_DEFECTO = {
    "PlayerSpawn", "PlayerInitialSpawn", "PlayerLoadout", "PlayerSetModel",
    "InitPostEntity", "Initialize", "Think", "HUDPaint", "OnEntityCreated",
    "EntityRemoved", "PlayerSpawnedProp", "PlayerDisconnected", "PostCleanupMap",
    "PreDrawOpaqueRenderables", "PostDrawTranslucentRenderables", "PreRender",
    "PhysgunDrop", "PlayerDeath",
    # KeyPress NO tiene semantica de retorno: `hook.Call` aborta la cadena con
    # cualquier valor, asi que un `return true` desde aca se lleva puestos a los
    # hooks de mas abajo en la fila -- y de `E` cuelgan abrir puertas, agarrar
    # props y entrar a vehiculos, en este addon y en los de terceros. Se agrego al
    # escribir el +USE del bloque 2026-08-17: sin la entrada, ese hook caia en
    # "revisar" y el auditor no podia NOMBRAR el defecto que existe para detectar.
    "KeyPress", "KeyRelease",
}

RE_HOOK = re.compile(r'hook\.Add\s*\(\s*"([A-Za-z_0-9]+)"\s*,')
# `return` seguido de algo que no sea `end`, comentario o fin de linea
RE_RET_VAL = re.compile(r'(?<![\w.])return[ \t]+(?!end\b)(?!--)(\S)')

def cuerpo(lineas, i):
    """Desde la linea del hook.Add, junta hasta cerrar el parentesis de apertura."""
    prof, buf, arranco = 0, [], False
    for n in range(i, min(i + 400, len(lineas))):
        l = lineas[n]
        buf.append((n + 1, l))
        sin_str = re.sub(r'"[^"]*"|\'[^\']*\'', '""', l)
        sin_str = re.sub(r'--.*$', '', sin_str)
        for ch in sin_str:
            if ch == '(':
                prof += 1; arranco = True
            elif ch == ')':
                prof -= 1
        if arranco and prof <= 0:
            return buf
    return buf

raiz = pathlib.Path(sys.argv[1])
archivos = sorted(raiz.rglob("*.lua"))
total = sospechosos = 0
filas = []

for f in archivos:
    lineas = f.read_text(encoding="utf-8", errors="replace").splitlines()
    for i, l in enumerate(lineas):
        m = RE_HOOK.search(l)
        if not m:
            continue
        total += 1
        evento = m.group(1)
        cuerpo_l = cuerpo(lineas, i)
        # el callback nombrado (hook.Add(ev, id, fn)) no tiene cuerpo inline:
        # se marca aparte porque su return no se ve desde aca
        inline = any("function" in t for _, t in cuerpo_l)
        rets = [(n, t.strip()) for n, t in cuerpo_l[1:] if RE_RET_VAL.search(t)]
        if not inline:
            filas.append((str(f), i + 1, evento, "CALLBACK NOMBRADO — el return no se ve aca", ""))
            sospechosos += 1
        elif rets:
            clase = ("api" if evento in RETORNO_ES_LA_API
                     else "DEFECTO" if evento in RETORNO_ES_DEFECTO
                     else "revisar")
            if clase != "api":
                sospechosos += 1
            filas.append((str(f), i + 1, evento, clase,
                          "; ".join(f":{n} {t[:60]}" for n, t in rets[:3])))

print(f"DENOMINADOR: {len(archivos)} archivos .lua, {total} hook.Add\n")
print(f"{'evento':<32} {'clase':<9} sitio")
print("-" * 118)
for f, n, ev, clase, det in sorted(filas, key=lambda r: (r[3] != "DEFECTO", r[2])):
    marca = "!" if clase in ("DEFECTO", "revisar") or clase.startswith("CALLBACK") else " "
    print(f"{marca} {ev:<30} {clase:<9} {f}:{n}")
    if det:
        print(f"      {det}")
print("-" * 118)
print(f"hook.Add con return de valor donde NO es la API del hook, o sin cuerpo visible: {sospechosos} de {total}")
