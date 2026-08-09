# -*- coding: utf-8 -*-
"""Verificador de sintaxis Lua para el taller de GMod.

DOS INSTRUMENTOS, PORQUE NINGUNO SOLO ALCANZA -- y eso esta MEDIDO:

  ( 1 ) luaparser, con `continue` neutralizado.
        Da FALSOS ROJOS sobre Lua de GMod: `continue` es extension de GMod y no
        de Lua 5.1. Ya estaba anotado en el taller.

  ( 2 ) un lexer propio que busca UN SOLO defecto: un salto de linea CRUDO
        adentro de un string corto.
        Existe porque luaparser da un FALSO VERDE sobre el, medido el 2026-08-09
        con este caso aislado:

            local x = f( "primera parte
            segunda parte" )

        luaparser: OK.  GMod: `unfinished string near '"primera parte'`.

        Y ese fue exactamente el defecto que llego al juego: un `\\n` mal
        escapado al pasar por shell -> Python -> Lua ( dos capas de escape )
        dejo un salto real adentro del string, el archivo entero no cargo, y el
        verificador habia dicho OK.

*Un verificador que solo da falsos rojos se descubre la primera vez que se usa.
Uno que da un falso VERDE se descubre en el juego, y mientras tanto acredita.*
"""

import re
import sys

from luaparser import ast

CONT = re.compile(r'\bcontinue\b')


def saltos_en_string(src):
    """Devuelve [(linea, fragmento)] por cada string corto con un salto crudo.

    Recorre a mano porque hay que distinguir cuatro contextos que el regex no
    separa: comentario de linea, comentario largo, string largo y string corto.
    """
    fallas = []
    i, n, linea = 0, len(src), 1

    while i < n:
        c = src[i]

        if c == '\n':
            linea += 1
            i += 1
            continue

        # comentario ( de linea o largo )
        if src.startswith('--', i):
            m = re.match(r'--\[(=*)\[', src[i:])
            if m:                                   # comentario largo
                cierre = ']' + m.group(1) + ']'
                j = src.find(cierre, i)
                j = n if j < 0 else j + len(cierre)
                linea += src.count('\n', i, j)
                i = j
            else:                                   # comentario de linea
                j = src.find('\n', i)
                i = n if j < 0 else j
            continue

        # string largo [[ ]] / [==[ ]==]  -- ESTOS SI pueden tener saltos
        m = re.match(r'\[(=*)\[', src[i:])
        if m:
            cierre = ']' + m.group(1) + ']'
            j = src.find(cierre, i)
            j = n if j < 0 else j + len(cierre)
            linea += src.count('\n', i, j)
            i = j
            continue

        # string corto -- ACA esta el defecto que buscamos
        if c in '"\'':
            comilla, arranco = c, linea
            j = i + 1
            while j < n:
                d = src[j]
                if d == '\\':
                    j += 2
                    continue
                if d == '\n':
                    frag = src[i:j].replace('\n', ' ')[:70]
                    fallas.append((arranco, frag))
                    break
                if d == comilla:
                    j += 1
                    break
                j += 1
            i = j
            continue

        i += 1

    return fallas


def check(path):
    src = open(path, encoding='utf-8').read()

    crudos = saltos_en_string(src)
    if crudos:
        det = '; '.join('linea %d: %s...' % (l, f) for l, f in crudos[:3])
        return False, 'FALLA  salto de linea CRUDO en %d string(s) cortos -- %s' % (len(crudos), det)

    n = len(CONT.findall(src))
    try:
        ast.parse(CONT.sub('__cont__ = 1', src))
    except Exception as e:
        return False, 'FALLA  %s: %s' % (type(e).__name__, str(e).replace('\n', ' | ')[:300])

    return True, 'OK   (%d `continue` neutralizados, 0 saltos crudos)' % n


if __name__ == '__main__':
    malos = 0
    for p in sys.argv[1:]:
        ok, msg = check(p)
        print(('  ' if ok else '! ') + msg + '   ' + p)
        if not ok:
            malos += 1
    sys.exit(1 if malos else 0)
