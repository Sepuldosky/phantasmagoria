"""
Cuenta a los que NO PASAN por la puerta de la cordura.

POR QUE EXISTE, Y POR QUE NO ALCANZA UN CHECK DEL HELPER
--------------------------------------------------------
La cordura de Diseno 19.8 tiene UNA puerta:

    PHANTASMAGORIA.DrainSanity( ply, pct, causa )
    PHANTASMAGORIA.RestoreSanity( ply, pct, causa )
    PHANTASMAGORIA.RegisterSanityRate( id, fn )

y un solo escritor del numero. Un control que mida LA PUERTA no descubre que
alguien no la llama: sabotear la funcion da rojo y un sitio que escriba la barra
por su cuenta deja la pasada entera en verde -- con el agravante de que ese verde
ACREDITA la centralizacion que no ocurrio ( catalogo nº 89 ).

*Cada vez que un cambio es "ahora todos pasan por X", el control de X no alcanza:
hace falta uno que cuente a los que NO pasan.* Y se hace sobre el TEXTO FUENTE,
no sobre el comportamiento, porque un escritor clandestino no produce ningun
sintoma -- produce una barra que baja y un desglose que no cierra.

LAS DOS MITADES, Y LAS DOS HACEN FALTA
--------------------------------------
  EXIGIR   que el unico escritor del numero sea el modulo de la cordura.
  PROHIBIR el patron viejo. `SetNW2Float` y `SetNWFloat` son DOS ALMACENES
           DISTINTOS del engine: un consumidor que lea `GetNWFloat` sobre el
           mismo nombre recibe 0 con la barra al 72 %, sin error. Exigir sin
           prohibir pasa si los dos conviven.

Uso:
    python dev/auditar_puerta_cordura.py            ( sobre lua/ )
    python dev/auditar_puerta_cordura.py --control  ( se auto-verifica )

Sale 0 si no hay clandestinos, 1 si los hay o si el arbol no tiene puerta.
"""
import re, sys, os, shutil, tempfile, pathlib

PUERTA = "autorun/phantasmagoria_sanity.lua"
NW     = "phantasmagoria_sanity"

# El nombre del campo de estado por jugador. Vive en el modulo y nadie mas lo
# tiene que tocar: el lector publico es PHANTASMAGORIA.GetSanity.
ESTADO = "phantom_San"

RE_NW2_ESCRIBE  = re.compile(r'SetNW2Float\s*\(\s*[^,)]*,?\s*["\']' + NW + r'["\']')
RE_NW2_NOMBRE   = re.compile(r'SetNW2Float\s*\(\s*NW\b')          # el modulo usa la constante
RE_FAMILIA_VIEJA = re.compile(r'(Set|Get)NWFloat\s*\(\s*["\']' + NW + r'["\']')
RE_ESTADO_ESCRIBE = re.compile(r'\.' + ESTADO + r'\s*(\.\w+\s*)*=(?!=)')
RE_ESTADO_TOCA    = re.compile(r'\.' + ESTADO + r'\b')

RE_PUERTA_USO = re.compile(
    r'PHANTASMAGORIA\.(DrainSanity|RestoreSanity|RegisterSanityRate|UseSanityMed|SetSanity|GetSanity)\s*\(')

# Clases de hallazgo. El --control declara CUANTOS de cada una inyecta, porque un
# arnes que solo pide "al menos una falla" se acredita el trabajo que no hizo
# ( catalogo nº 72 ).
CLANDESTINA   = "escritura clandestina"
FAMILIA_VIEJA = "familia NW vieja"


def sin_comentarios(linea):
    """Un valor citado adentro de un `--` es prosa, no codigo ( catalogo nº 69 )."""
    return re.sub(r'--.*$', '', linea)


def escanear(raiz):
    raiz = pathlib.Path(raiz)
    archivos = sorted(raiz.rglob("*.lua"))

    hallazgos = []          # ( clase, ruta, linea, texto )
    usuarios  = {}          # ruta -> cantidad de llamadas a la puerta
    puerta_vista = False
    escrituras_en_puerta = 0

    for f in archivos:
        rel = f.relative_to(raiz).as_posix()
        es_puerta = rel.endswith(PUERTA)
        if es_puerta:
            puerta_vista = True

        try:
            lineas = f.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue

        # ⚠ El bloque de comentario largo del encabezado nombra las funciones de
        # la puerta a proposito. Contarlas como llamadas inflaria el denominador
        # y haria ver como consumidores a los archivos que solo la DOCUMENTAN.
        en_bloque = False

        for n, cruda in enumerate(lineas, 1):
            if "--[[" in cruda:
                en_bloque = True
            if en_bloque:
                if "]]" in cruda:
                    en_bloque = False
                continue

            l = sin_comentarios(cruda)

            if RE_FAMILIA_VIEJA.search(l):
                hallazgos.append((FAMILIA_VIEJA, rel, n, cruda.strip()))

            escribe_nw     = bool(RE_NW2_ESCRIBE.search(l)) or bool(RE_NW2_NOMBRE.search(l))
            escribe_estado = bool(RE_ESTADO_ESCRIBE.search(l))

            if escribe_nw or escribe_estado:
                if es_puerta:
                    escrituras_en_puerta += 1
                else:
                    hallazgos.append((CLANDESTINA, rel, n, cruda.strip()))

            elif RE_ESTADO_TOCA.search(l) and not es_puerta:
                # Leer el estado interno no rompe el numero, pero salta la API y
                # envejece con ella. Se reporta y NO tiñe el veredicto.
                hallazgos.append(("lectura del estado interno ( aviso )", rel, n, cruda.strip()))

            for m in RE_PUERTA_USO.finditer(l):
                if es_puerta:
                    continue
                usuarios[rel] = usuarios.get(rel, 0) + 1

    return {
        "archivos": len(archivos),
        "hallazgos": hallazgos,
        "usuarios": usuarios,
        "puerta_vista": puerta_vista,
        "escrituras_en_puerta": escrituras_en_puerta,
    }


def graves(hallazgos):
    return [h for h in hallazgos if h[0] in (CLANDESTINA, FAMILIA_VIEJA)]


def informar(r, raiz):
    print(f"DENOMINADORES ( los tres, porque uno solo no dice nada ):")
    print(f"  archivos .lua barridos          {r['archivos']}")
    print(f"  escrituras del numero DENTRO de la puerta   {r['escrituras_en_puerta']}")
    print(f"  archivos que usan la API publica            {len(r['usuarios'])}")
    print()

    if not r["puerta_vista"]:
        # ⚠ Sin puerta no hay clandestinos, y un cero ahi seria un VERDE sobre un
        # arbol donde la cordura no existe. El caso peor de este instrumento es
        # justo ese, asi que tiene su propio rojo.
        print(f"!! NO SE ENCONTRO LA PUERTA ( .../{PUERTA} ) bajo {raiz}.")
        print("   Un cero de clandestinos sobre un arbol sin puerta es un falso verde.")
        return 1

    if r["usuarios"]:
        print("Usan la API publica:")
        for ruta, n in sorted(r["usuarios"].items()):
            print(f"  {n:>3} llamadas   {ruta}")
    else:
        print("Usan la API publica: NINGUNO todavia.")
        print("  Es lo esperado hasta B2: los ocho eventos de server_events.lua")
        print("  y las cinco manifestaciones de §22 son los llamadores declarados.")
    print()

    g = graves(r["hallazgos"])
    avisos = [h for h in r["hallazgos"] if h not in g]

    for clase, ruta, n, texto in g:
        print(f"!! {clase:<24} {ruta}:{n}")
        print(f"      {texto[:110]}")
    for clase, ruta, n, texto in avisos:
        print(f" · {clase:<24} {ruta}:{n}")
        print(f"      {texto[:110]}")

    print()
    print(f"ESCRITORES QUE NO PASAN POR LA PUERTA: {len(g)}")
    return 1 if g else 0


def control():
    """
    Se verifica a si mismo SOBRE UNA COPIA DEL ARBOL REAL, y no sobre una
    carpeta vacia: este barrido compara contra su entorno -- necesita la puerta
    presente para saber que un escritor esta afuera de ella -- y una sandbox le
    saca justo lo que lee ( catalogo nº 82 ).

    Declara CUANTOS defectos inyecta y de que clase, y falla si el numero no
    coincide: de mas o de menos. Un arnes que solo pide "al menos una falla" se
    acredita el trabajo que no hizo ( catalogo nº 72 ).
    """
    ESPERADAS = {CLANDESTINA: 2, FAMILIA_VIEJA: 1}

    aqui = pathlib.Path(__file__).resolve().parent.parent
    lua  = aqui / "lua"

    if not lua.is_dir():
        print(f"CONTROL: no encuentro {lua}")
        return 1

    # ( a ) el arbol LIMPIO tiene que dar cero
    limpio = escanear(lua)
    if not limpio["puerta_vista"]:
        print("CONTROL: el arbol real no tiene puerta -- el control no puede correr.")
        return 1
    if graves(limpio["hallazgos"]):
        print("CONTROL: el arbol REAL ya trae clandestinos; corregilos antes de controlar.")
        return 1

    # ( b ) el arbol SUCIO tiene que dar exactamente lo inyectado
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="cordura_ctl_"))
    try:
        copia = tmp / "lua"
        shutil.copytree(lua, copia)

        (copia / "zz_control_clandestino.lua").write_text(
            "-- inyectado por --control\n"
            'ply:SetNW2Float( "' + NW + '", 50 )\n'
            "ply.phantom_San.val = 10\n",
            encoding="utf-8")

        (copia / "zz_control_familia_vieja.lua").write_text(
            "-- inyectado por --control\n"
            'local v = ply:GetNWFloat( "' + NW + '" )\n',
            encoding="utf-8")

        sucio = escanear(copia)
        conteo = {}
        for clase, _, _, _ in graves(sucio["hallazgos"]):
            conteo[clase] = conteo.get(clase, 0) + 1

        print("CONTROL")
        print(f"  arbol limpio  -> {len(graves(limpio['hallazgos']))} clandestinos   ( se pedia 0 )")
        for clase, n in sorted(ESPERADAS.items()):
            visto = conteo.get(clase, 0)
            marca = "ok " if visto == n else "!! "
            print(f"  {marca}{clase:<24} inyectadas {n}, detectadas {visto}")

        sobrantes = {k: v for k, v in conteo.items() if k not in ESPERADAS}
        for clase, n in sorted(sobrantes.items()):
            print(f"  !! {clase:<24} NO se inyecto y se reportaron {n}")

        ok = (conteo == ESPERADAS) and not graves(limpio["hallazgos"])
        print()
        print("CONTROL:", "el instrumento DISCRIMINA" if ok
              else "EL INSTRUMENTO NO DISCRIMINA -- no uses su veredicto")
        return 0 if ok else 1

    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    if "--control" in sys.argv:
        sys.exit(control())

    raiz = next((a for a in sys.argv[1:] if not a.startswith("-")), "lua")
    sys.exit(informar(escanear(raiz), raiz))
