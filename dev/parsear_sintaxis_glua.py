"""
Parsea de verdad la sintaxis de los .lua del addon.

POR QUE EXISTE, Y NO ES REDUNDANTE CON luacheck_gmod.py: aquel NO PARSEA. Mide
`continue` neutralizados y saltos crudos, y nada mas. El 2026-08-10 dio `OK`
sobre un archivo con un `if/else/end` desbalanceado -- o sea que un archivo que
GMod no habria podido cargar paso el unico control de sintaxis del repo.
Es la misma familia que el defecto del 2026-08-09: un salto de linea CRUDO adentro
de un string tiro ghost_flags.lua en juego y "el verificador de sintaxis habia
dicho OK".

Los dos se corren, y miden cosas distintas:
    python dev/luacheck_gmod.py $(rutas)     -> `continue` y saltos crudos
    python dev/parsear_sintaxis_glua.py lua  -> que el archivo COMPILE

⚠⚠ LA TRAMPA QUE ESTE SCRIPT EVITA, Y QUE COSTO UN FALSO ROJO:
GLua acepta `continue`; Lua estandar NO. Un parser de Lua sobre un archivo de
GMod tira `syntax error near 'end'` en la linea del `continue` -- un error REAL
del parser sobre codigo PERFECTAMENTE VALIDO en el motor de destino. La primera
corrida de esta idea reprobo server_doors.lua por eso, y lo desmintio el control
obvio: correrla sobre la version de HEAD, que "fallaba" igual. Por eso el
`continue` se neutraliza ANTES ( igual que hace luacheck_gmod.py ), y por eso
este script trae su propio control adentro: sin el, un verde no significa nada.

  --control   corre dos casos conocidos ( uno que compila y uno roto ) y verifica
              que el instrumento los distinga. Si no discrimina, aborta.
"""
import argparse
import os
import re
import sys

try:
    import lupa
except ImportError:
    print("! falta lupa:  pip install lupa")
    sys.exit(2)

# `continue` es la unica extension de GLua que rompe un parser de Lua estandar en
# la practica de este addon. `!=`, `&&`, `||` y `!` tambien existen en GLua pero
# este repo no los usa (verificado); si algun dia entran, se agregan aca y se
# suma un caso al --control, que es lo que hace que agregarlos sea seguro.
def neutraliza(src):
    return re.sub(r'(?<![\w.])continue(?![\w])', 'do end', src)


def compila(lua, src):
    try:
        lua.compile(neutraliza(src))
        return None
    except Exception as e:
        return str(e)


CTRL_OK = """
local t = {}
for i = 1, 10 do
    if i % 2 == 0 then continue end
    t[ #t + 1 ] = i
end
return t
"""

CTRL_ROTO = """
local t = {}
if true then
    t = 1
else
return t
"""


def control(lua):
    """El instrumento tiene que poder salir de las DOS maneras o no mide nada."""
    a = compila(lua, CTRL_OK)
    b = compila(lua, CTRL_ROTO)
    ok = (a is None) and (b is not None)
    print("CONTROL  valido-con-continue: %s   ·   roto-a-proposito: %s   -> %s"
          % ("compila" if a is None else "! REPROBADO",
             "detectado" if b is not None else "! NO detectado",
             "el instrumento DISCRIMINA" if ok else "!! NO DISCRIMINA"))
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("rutas", nargs="*", default=["lua"],
                    help="archivos o carpetas (default: lua)")
    ap.add_argument("--control", action="store_true",
                    help="solo corre el auto-control y sale")
    a = ap.parse_args()

    lua = lupa.LuaRuntime()

    if not control(lua):
        print("! el instrumento no distingue un archivo roto de uno sano. "
              "No se reporta nada: un verde de aca no significaria nada.")
        return 2
    if a.control:
        return 0

    archivos = []
    for r in (a.rutas or ["lua"]):
        if os.path.isfile(r):
            archivos.append(r)
        else:
            for root, _, fs in os.walk(r):
                archivos += [os.path.join(root, x) for x in sorted(fs) if x.endswith(".lua")]

    mal = 0
    for p in sorted(archivos):
        err = compila(lua, open(p, encoding="utf-8", errors="replace").read())
        if err:
            mal += 1
            print("! %s\n    %s" % (p, err[:220]))

    # DENOMINADOR SIEMPRE, incluido el 0: "no encontre archivos" y "los revise
    # todos y estan bien" no se pueden leer igual.
    print("PARSEO REAL: %d archivo(s) .lua, %d con error de sintaxis" % (len(archivos), mal))
    if not archivos:
        print("! CERO archivos. Eso es un problema de invocacion, no un verde.")
        return 2
    return 1 if mal else 0


if __name__ == "__main__":
    sys.exit(main())
