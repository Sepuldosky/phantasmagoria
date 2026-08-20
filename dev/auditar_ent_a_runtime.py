# -*- coding: utf-8 -*-
"""Busca lecturas del global `ENT` que ocurran a RUNTIME, con ENT ya en nil.

POR QUE EXISTE, Y NO LO CUBRE NINGUNO DE LOS OTROS TRES:

    parsear_sintaxis_glua.py   dice si el archivo COMPILA -- y este defecto compila
    luacheck_gmod.py           mide `continue` y saltos crudos
    auditar_returns_de_hooks.py mide el `return` de los hook.Add

El 2026-08-20 el autor corrio `phantasmagoria_ghost_cerebro` y le salio:

    server_hunt.lua:1217: attempt to index global 'ENT' (a nil value)
      1. unknown - server_hunt.lua:1217
       2. unknown - lua/includes/modules/concommand.lua:60

`ENT` **solo existe mientras el chunk del archivo de la entidad se esta
ejecutando**. Apenas termina, vuelve a ser nil. O sea que:

    ENT.InformRadius = 0                       <- ARRIBA, al cargar: vale
    if not isfunction( ENT.StartTask ) then     <- guarda al cargar: vale
    concommand.Add( "x", function()
        print( ENT.InformRadius )               <- corre DESPUES: revienta
    end )

**Las dos lecturas se escriben igual y una es valida y la otra es nil.** El
sintoma es peor que un error suelto: en aquella corrida el comando murio justo
despues de imprimir las perillas y se llevo puesto todo el bloque por fantasma
-- o sea la mitad del instrumento -- mientras la primera mitad se veia perfecta.

QUE MIRA: cualquier `ENT.` o `ENT[` que quede DENTRO de una funcion. Cuenta
`function` / `end` en vez de parsear, que alcanza para este codigo y no pide
lupa. Los strings y los comentarios ( de linea y de bloque ) se neutralizan
antes, porque `"ENT.MyClassTask"` adentro de un mensaje de error no es una
lectura.

⚠ SIN --control ESTE SCRIPT NO VALE NADA, y eso ya paso una vez: la primera
version de esta idea corrio sobre el addon, dio "ninguno", y **no marcaba la
linea que el juego habia reprobado esa misma tarde**. El contador de
profundidad no reconocia `AddCommand( "x", function( ply )` como apertura, asi
que el defecto vivia en profundidad 0 y quedaba absuelto. Un verde de un
detector que no encuentra el caso conocido no es un verde: es un instrumento
apagado. Por eso el control va ADENTRO y corre solo con --control.

    python dev/auditar_ent_a_runtime.py lua
    python dev/auditar_ent_a_runtime.py --control
"""
import argparse
import glob
import io
import os
import re
import sys

Q = chr(34)
BS = chr(92)
NL = chr(10)

RE_STR_D = re.compile(Q + "(?:[^" + Q + BS + BS + "]|" + BS + BS + ".)*" + Q)
RE_STR_S = re.compile("'(?:[^'" + BS + BS + "]|" + BS + BS + ".)*'")
RE_ENT = re.compile(r"(?<![\w.:])ENT[.\[]")
RE_TOK = re.compile(r"\b(function|if|for|while|do|end|elseif)\b")


def limpiar(src):
    """Neutraliza comentarios y strings conservando el numero de linea."""
    src = re.sub(r"--\[\[.*?\]\]", lambda m: NL * m.group(0).count(NL), src, flags=re.S)

    fuera = []
    for linea in src.split(NL):
        if linea.strip().startswith("--"):
            fuera.append("")
            continue

        linea = RE_STR_D.sub('""', linea)
        linea = RE_STR_S.sub("''", linea)
        fuera.append(linea.split("--")[0])

    return fuera


def escanear_texto(src):
    """Devuelve [( linea, codigo )] de las lecturas de ENT hechas dentro de una funcion."""
    hits = []
    prof_fn = 0
    pila = []

    for n, code in enumerate(limpiar(src), 1):
        # Las lecturas de ESTA linea se juzgan con la profundidad de ANTES de
        # abrirla: `ENT.X = function() ... end` en una sola linea es una
        # asignacion de nivel superior, no una lectura adentro de la funcion.
        if prof_fn > 0 and RE_ENT.search(code):
            hits.append((n, code.strip()[:110]))

        for tok in RE_TOK.findall(code):
            if tok == "elseif":
                continue

            if tok == "end":
                if pila and pila.pop() == "function":
                    prof_fn -= 1

            elif tok == "do" and pila and pila[-1] in ("for", "while"):
                continue  # el `do` de un for/while ya lo abrio el for/while

            else:
                pila.append(tok)
                if tok == "function":
                    prof_fn += 1

    return hits


def escanear(path):
    return escanear_texto(io.open(path, encoding="utf-8", errors="ignore").read())


# ---------------------------------------------------------------- el control --
# El SANO trae las tres formas legitimas y las tres tienen que salir absueltas:
# la asignacion de nivel superior, la guarda de carga, y el nombre adentro de un
# string. El ROTO es el defecto tal como el juego lo reprobo, envuelto en el
# mismo `AddCommand( "x", function( ply )` que la primera version no reconocia.
SANO = """
local INFORM_RADIUS = 0
ENT.InformRadius = INFORM_RADIUS
ENT.MyClassTask.Think = function( self, data ) return end
if not isfunction( ENT.StartTask ) then
    ErrorNoHalt( "ENT.StartTask no existe" )
end
for _, k in ipairs( FLAGS ) do
    if isfunction( ENT[ k ] ) then ErrorNoHalt( "pisado" ) end
end
PHANTASMAGORIA.AddCommand( "x", function( ply )
    say( "todo bien" )
end )
"""

ROTO = """
ENT.InformRadius = 0
PHANTASMAGORIA.AddCommand( "x", function( ply )
    say( "InformRadius = " .. tostring( ENT.InformRadius ) )
end )
"""


def control():
    sano = escanear_texto(SANO)
    roto = escanear_texto(ROTO)

    ok_sano = not sano
    ok_roto = len(roto) == 1

    print("CONTROL  sano ( 3 formas legitimas ): %s   %s"
          % ("absuelto" if ok_sano else "!! FALSO ROJO en %s" % [n for n, _ in sano],
             "" if ok_sano else "<-"))
    print("CONTROL  roto ( el defecto de la corrida del 2026-08-20 ): %s"
          % ("DETECTADO" if ok_roto else "!! NO LO VE -- el instrumento esta apagado"))

    if not (ok_sano and ok_roto):
        print(NL + ">> EL INSTRUMENTO NO DISCRIMINA. No se puede leer nada de lo que diga.")
        return False

    print(">> el instrumento DISCRIMINA")
    return True


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("rutas", nargs="*", help="archivos o carpetas .lua")
    ap.add_argument("--control", action="store_true",
                    help="corre los dos casos conocidos y verifica que el detector los separe")
    args = ap.parse_args()

    if not control():
        return 2

    if not args.rutas:
        return 0

    archivos = []
    for r in args.rutas:
        if os.path.isdir(r):
            archivos += glob.glob(os.path.join(r, "**", "*.lua"), recursive=True)
        else:
            archivos.append(r)

    print("")
    total = 0
    for p in sorted(archivos):
        for n, code in escanear(p):
            print("  %s:%d  %s" % (p.replace(BS, "/"), n, code))
            total += 1

    print("")
    print("DENOMINADOR: %d archivo(s) .lua" % len(archivos))
    print("ENT leido adentro de una funcion ( corre con ENT en nil ): %d" % total)

    if total:
        print(NL + ">> FALLA: cada uno de esos es un `attempt to index global 'ENT' (a nil value)` "
                   "esperando a que alguien corra esa funcion.")
        return 1

    print(">> LIMPIO: todas las lecturas de ENT ocurren mientras el archivo se carga.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
