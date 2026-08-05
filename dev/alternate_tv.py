#!/usr/bin/env python3
"""
Prepara los rostros del Alternate para las pantallas (TV del camion y equipo).

    python dev/alternate_tv.py

QUE HACE
    Toma los seis PNG de 4096x4096 que trajo el autor y escribe versiones
    utilizables en `materials/phantasmagoria/alternate/`.

POR QUE NO SE USAN LOS ORIGINALES TAL CUAL — tres motivos MEDIDOS:

1. LA RUTA. Los originales llegaron a
   `sound/phantasmagoria/ghost/special/alternate/alternateTV/`, y la lista
   blanca del `.gma` solo admite `wav`/`mp3`/`ogg` bajo `sound/`. Los `.png`
   solo viven bajo `materials/`. Montado por junction anda; al empaquetar para
   el Workshop **desaparecen sin un solo error** — la misma trampa que el
   archivo de la TV documenta para los `.html`.

2. EL PESO. 4096x4096 RGBA son ~64 MB de VRAM cada uno descomprimido: los seis
   juntos ~400 MB, para dibujarse en una pantalla de 1024x593. A 1024 de alto
   el juego completo entra en ~19 MB y sigue sobrando resolucion para la TV.

3. EL ENCUADRE, y este es el que no se ve venir. Medido sobre el canal alfa
   (umbral 8, sobre 255):

       alternate_1..5     contenido en x 604..3174   -> centro en el 46,1 %
       alternate_appear   contenido en x 1296..3296  -> centro en el 56,1 %

   Los cinco rostros estan registrados entre si (sus bordes no se mueven mas
   de 8 px sobre 4096), pero `appear` esta corrido un 10 % del ancho respecto
   de ellos. Pegando los seis "centrados" tal cual, `appear` SALTA unos 100 px
   en una pantalla de 1024 — y se lee como un error de dibujo, no como que la
   imagen venia asi.

   Por eso el recorte NO es uno por imagen: los cinco de la secuencia se
   recortan con un bbox COMUN (si se recortara cada uno con el suyo, la cabeza
   temblaria entre cuadro y cuadro, que es peor que el margen que sobra), y
   `appear` con el suyo, que es otra cosa: no es el cuadro 0 de la secuencia,
   es la silueta sin forma tomada.

   Verticalmente no hace falta decidir nada: en los seis el contenido llega
   hasta y=4096, o sea el cuello YA esta al ras del borde de abajo. El anclado
   inferior que pide el diseno sale del propio asset.

LO QUE ENTREGA
    Seis PNG de 768x1024 con el rostro anclado ABAJO y centrado sobre su
    contenido. Dibujar los seis con la misma regla —pegados al borde inferior
    de la pantalla, centrados— los deja alineados entre si sin tablas de
    offsets por imagen.

    No se escribe `.vmt`: un PNG bajo `materials/` se puede levantar con
    `Material("phantasmagoria/alternate/alternate_1.png", "smooth")` para
    dibujarlo en 2D o en un RenderTarget, y tambien por
    `asset://garrysmod/materials/phantasmagoria/alternate/...` desde la pagina
    del DHTML. Ninguno de los dos caminos necesita material declarado.

    Los originales de 4096 quedan en `dev/alternate_src/` — fuera del arbol
    del addon, porque no los necesita nadie en tiempo de ejecucion y son 60 MB.

LO QUE ESTE SCRIPT NO CORRIGE, A PROPOSITO
    La cabeza de `alternate_appear` mide el **61 %** de las otras cinco: 333 px
    de ancho contra 543 a la misma altura del lienzo. No es un defecto de la
    derivacion —viene asi del original, que tiene proporcionalmente mas cuello
    y hombros— y en pantalla se lee como "esta mas lejos".

    Se deja asi porque es una decision de ARTE y no tecnica: si `appear` es el
    `plain base` (otra manifestacion, no el cuadro 0 de la secuencia) la
    diferencia es correcta. Si tiene que ser el mismo ente a la misma
    distancia, el arreglo es escalarlo por 543/333 = 1,63x anclado por la
    coronilla, dejando que los hombros se salgan por abajo — que es donde esta
    el borde de la pantalla, asi que no se pierde nada. Ver ALTERNATE.md §4.3.
"""

import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("hace falta Pillow:  pip install Pillow")

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)

ORIGEN  = os.path.join(RAIZ, "dev", "alternate_src")
DESTINO = os.path.join(RAIZ, "materials", "phantasmagoria", "alternate")

# La secuencia va junta; `appear` es otra cosa y va sola.
SECUENCIA = ["alternate_1", "alternate_2", "alternate_3", "alternate_4", "alternate_5"]
SUELTAS   = ["alternate_appear"]

# 1024 de alto porque la pantalla de la TV mide 593 px: sobra resolucion sin
# tener que reescalar hacia arriba nunca, y deja margen si alguna vez se dibuja
# a pantalla completa. 768 de ancho es el mas angosto que entra el recorte mas
# ancho (643 px) sin recortarlo.
ALTO_DESTINO  = 1024
ANCHO_LIENZO  = 768

# Sobre 255. Por debajo de esto el pixel es margen: el alfa de estos PNG no
# cae a cero limpio en los bordes, asi que `getbbox()` crudo devuelve el canvas
# entero y no sirve para recortar.
UMBRAL_ALFA = 8


def bbox_contenido(im):
    """bbox del contenido REAL, ignorando el alfa casi transparente del borde."""
    alfa = im.split()[3]
    return alfa.point(lambda x: 255 if x > UMBRAL_ALFA else 0).getbbox()


def union(cajas):
    return (min(c[0] for c in cajas), min(c[1] for c in cajas),
            max(c[2] for c in cajas), max(c[3] for c in cajas))


def procesar(nombres, caja, imgs):
    salidas = []
    ancho_c, alto_c = caja[2] - caja[0], caja[3] - caja[1]
    escala = ALTO_DESTINO / alto_c
    ancho_d = max(1, round(ancho_c * escala))

    if ancho_d > ANCHO_LIENZO:
        sys.exit("el recorte (%d px) no entra en el lienzo (%d px): subir ANCHO_LIENZO"
                 % (ancho_d, ANCHO_LIENZO))

    for nombre in nombres:
        im = imgs[nombre].crop(caja).resize((ancho_d, ALTO_DESTINO), Image.LANCZOS)
        lienzo = Image.new("RGBA", (ANCHO_LIENZO, ALTO_DESTINO), (0, 0, 0, 0))
        # centrado horizontal sobre el CONTENIDO, y pegado al borde de abajo
        lienzo.paste(im, ((ANCHO_LIENZO - ancho_d) // 2, 0))
        destino = os.path.join(DESTINO, nombre + ".png")
        lienzo.save(destino, "PNG", optimize=True)
        salidas.append((nombre, destino, ancho_d))
    return salidas


def main():
    if not os.path.isdir(ORIGEN):
        sys.exit("no existe %s — ahi van los seis PNG de 4096x4096" % ORIGEN)
    os.makedirs(DESTINO, exist_ok=True)

    todos = SECUENCIA + SUELTAS
    imgs, cajas = {}, {}
    for nombre in todos:
        ruta = os.path.join(ORIGEN, nombre + ".png")
        if not os.path.isfile(ruta):
            sys.exit("falta %s" % ruta)
        im = Image.open(ruta).convert("RGBA")
        imgs[nombre] = im
        cajas[nombre] = bbox_contenido(im)
        print("  leido  %-20s %dx%d  contenido x %d..%d"
              % (nombre, im.width, im.height, cajas[nombre][0], cajas[nombre][2]))

    # bbox COMUN para la secuencia: que los cinco compartan recorte es lo que
    # evita que la cabeza tiemble al pasar de cuadro.
    caja_sec = union([cajas[n] for n in SECUENCIA])
    print("\n  bbox comun de la secuencia: %s" % (caja_sec,))

    salidas = procesar(SECUENCIA, caja_sec, imgs)
    for nombre in SUELTAS:
        salidas += procesar([nombre], cajas[nombre], imgs)

    print("\n  escritos en materials/phantasmagoria/alternate/:")
    total = 0
    for nombre, ruta, ancho in salidas:
        kb = os.path.getsize(ruta) / 1024
        total += kb
        print("    %-20s %dx%d  contenido %d px de ancho  %7.1f KB"
              % (nombre + ".png", ANCHO_LIENZO, ALTO_DESTINO, ancho, kb))
    vram = len(salidas) * ANCHO_LIENZO * ALTO_DESTINO * 4 / 1048576
    print("\n  total en disco: %.1f MB   |   en VRAM sin comprimir: %.1f MB"
          % (total / 1024, vram))


if __name__ == "__main__":
    main()
