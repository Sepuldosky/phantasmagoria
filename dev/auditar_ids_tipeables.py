"""
Ningun id de causa de la cordura puede llevar un caracter que la CONSOLA parta.

POR QUE EXISTE
--------------
La r2 dejo la fila 04 en ROJO y la causa no estaba en el codigo que la fila
media. Los ocho ids de evento se habian escrito `evento:sound`, y el
tokenizador de comandos de Source ( CCommand::Tokenize, tier1 ) parte la linea
con un break set que incluye

    { } ( ) ' :

y esos caracteres salen como TOKENS PROPIOS. Asi que

    phantasmagoria_cordura_drenar 10 evento:sound

no llega como dos argumentos sino como cuatro -- "10", "evento", ":", "sound" --
y el andamio, que leia el segundo, drenaba contra una causa llamada "evento".
No hubo error de Lua, ni de red, ni de permisos: el string se partio ANTES de
que el addon lo viera, y el sintoma aparecio dos capas mas abajo disfrazado de
"el string de causa no llega". El renglon correcto quedaba en cero -- o sea que
la fila que probaba la forma PLANA no podia salir verde ni una sola vez.

Es el pariente de la truncada a 255 de la consola de Source: el transporte le
come algo al texto sin avisar y el receptor es acusado del defecto.

POR QUE NO ALCANZA CON HABERLOS RENOMBRADO
-------------------------------------------
Un check que verifique "los ocho llevan guion bajo" sale verde por construccion
el dia que se escribe y no cubre a la causa numero 20 ( catalogo nº 42 ). Lo que
se verifica aca es la PROPIEDAD sobre TODAS las causas declaradas, asi que una
causa de B2 escrita con dos puntos vuelve a encender el rojo.

Y no reemplaza al control de arranque que vive en el modulo: este barre el TEXTO
FUENTE y corre sin juego; el otro corre en el realm donde el defecto muerde.

Uso:
    python dev/auditar_ids_tipeables.py            ( sobre lua/ )
    python dev/auditar_ids_tipeables.py --control  ( se auto-verifica )

Sale 0 si todos los ids se pueden tipear, 1 si alguno no -- o si el barrido no
encontro la tabla, que es el otro modo de dar un verde vacio.
"""
import re, sys, os, shutil, tempfile, pathlib

MODULO = "autorun/phantasmagoria_sanity.lua"

# El break set de CCommand::Tokenize, mas los que rompen la LINEA antes de que el
# tokenizador la vea: `;` separa comandos, `"` abre comilla, el espacio separa
# argumentos, el tab idem.
ROMPEN = ['{', '}', '(', ')', "'", ':', ';', '"', ' ', '\t']

RE_ID = re.compile(r'\{\s*id\s*=\s*"([^"]*)"')


def escanear(raiz):
    """Devuelve ( ids, rotos ). `ids` vacio NO es un verde: es un barrido ciego."""
    ruta = None

    for p in pathlib.Path(raiz).rglob("*.lua"):
        if str(p).replace("\\", "/").endswith(MODULO):
            ruta = p
            break

    if ruta is None:
        return None, None

    txt = ruta.read_text(encoding="utf-8", errors="replace")

    # Solo la tabla CAUSAS: `{ id = ... }` aparece en otras tablas del addon y
    # contarlas todas volveria el numero incomparable entre corridas.
    m = re.search(r'local CAUSAS = \{(.*?)\n\}', txt, re.S)
    if not m:
        return None, None

    ids = RE_ID.findall(m.group(1))
    rotos = [i for i in ids if any(c in i for c in ROMPEN)]

    return ids, rotos


def informar(ids, rotos, raiz):
    print()
    print("IDS DE CAUSA QUE LA CONSOLA TIENE QUE PODER TIPEAR   ( arbol: %s )" % raiz)
    print()

    if ids is None:
        print("  ! NO SE ENCONTRO la tabla CAUSAS en %s" % MODULO)
        print("    Un barrido que no encuentra su sujeto no es un verde: es un cero sin denominador.")
        return 1

    print("  causas declaradas   %d" % len(ids))
    print("  con caracter roto   %d" % len(rotos))
    print()

    if rotos:
        for i in rotos:
            cuales = " ".join(repr(c) for c in ROMPEN if c in i)
            print("  ! %-22s lleva %s" % (i, cuales))

        print()
        print("IDS INALCANZABLES DESDE LA CONSOLA: %d" % len(rotos))
        print("  El andamio no los puede nombrar y su renglon del desglose no se puede ejercer.")
        return 1

    print("IDS INALCANZABLES DESDE LA CONSOLA: 0")
    return 0


def control():
    """Inyecta 1 defecto sobre una COPIA del arbol real y exige detectarlo.

    Sobre el arbol real y no sobre una sandbox: una sandbox le sacaria justo lo
    que el barrido lee ( catalogo nº 82 ).
    """
    raiz = pathlib.Path("lua")
    if not raiz.is_dir():
        print("! no hay lua/ para copiar")
        return 1

    ids, rotos = escanear(raiz)

    if ids is None:
        print("! el arbol limpio no tiene tabla CAUSAS legible: el control no puede correr")
        return 1

    print("CONTROL")
    print("  arbol limpio  -> %d ids rotos de %d   ( se pedia 0 )" % (len(rotos), len(ids)))

    if rotos:
        print("  ! el arbol real ya tiene ids rotos: arreglarlos antes de correr el control")
        return 1

    tmp = pathlib.Path(tempfile.mkdtemp(prefix="ids_tipeables_"))
    dst = tmp / "lua"
    shutil.copytree(raiz, dst)

    mod = dst / MODULO
    txt = mod.read_text(encoding="utf-8", errors="replace")

    # El defecto ES el de la r2, tal cual: un id con dos puntos.
    viejo = '{ id = "evento_sound",'
    if viejo not in txt:
        print("  ! no se pudo inyectar: cambio el texto de anclaje")
        shutil.rmtree(tmp, ignore_errors=True)
        return 1

    txt = txt.replace(viejo, '{ id = "evento:sound",', 1)
    mod.write_text(txt, encoding="utf-8")

    _, rotos2 = escanear(dst)
    ok = rotos2 is not None and len(rotos2) == 1

    print("  %s dos puntos en un id     inyectados 1, detectados %s"
          % ("ok" if ok else "!!", "?" if rotos2 is None else len(rotos2)))

    shutil.rmtree(tmp, ignore_errors=True)

    print()
    print("CONTROL: el instrumento %s" % ("DISCRIMINA" if ok else "NO DISCRIMINA"))
    return 0 if ok else 1


if __name__ == "__main__":
    if "--control" in sys.argv:
        sys.exit(control())

    raiz = next((a for a in sys.argv[1:] if not a.startswith("-")), "lua")
    ids, rotos = escanear(raiz)
    sys.exit(informar(ids, rotos, raiz))
