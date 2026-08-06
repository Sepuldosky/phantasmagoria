--[[-------------------------------------------------------------------------
    Phantasmagoria - los monitores del camion

    QUE HACE
    Monta una pagina HTML como submaterial de la pantalla del modelo
    `models/phantasmagoria/trucktv.mdl`. La pagina tiene CUATRO layouts, uno por
    cada monitor del camion de Phasmophobia:

        sanity    "TEAM SANITY"      cordura por jugador + promedio
        activity  "TOTAL ACTIVITY"   actividad 0..10 de los ultimos 60 s
        sound     "SOUND SENSORS"    hasta 4 sensores, etiquetados por CUARTO
        map       el nombre del sitio, y el plano

    Cada prop lleva UN layout, igual que en el juego: el camion tiene los cuatro
    monitores colgados a la vez. Se pueden montar los cuatro en cuatro props.

    ESTE ARCHIVO NO HACE NADA SOLO. Define funciones y un concommand de prueba;
    no engancha ningun hook de dibujado ni toca ninguna entidad hasta que
    alguien lo llama.

    DE DONDE SALE CADA COSA

    Los titulos salen del TextAsset `localisation` del juego (64:3563), la misma
    tabla que usa Phasmophobia para su UI:

        Truck_TeamSanity      "Team Sanity"      Monitor_Strength   "Strength"
        Truck_AverageSanity   "Average"          Monitor_Time       "Time in seconds"
        Monitor_SoundSensors  "Sound Sensors"    Monitor_NoInput    "NO INPUT"
        Monitor_MotionSensors "Motion Sensors"   Monitor_EMFDetection "Total Activity"

    Los LAYOUTS salen de capturas del juego que trajo el autor. Todo lo que esta
    dibujado aca se ve en esas capturas; lo que no, no esta.

    Y una cosa que NO se pudo medir: **los colores de los jugadores**. Se
    buscaron en los assets y no estan — 22 GameObject `Player Colour` y ninguno
    de sus componentes tiene color serializado; `PlayerColor` es un MonoScript,
    o sea codigo compilado. El cero esta controlado (el buscador SI devolvio los
    22, asi que no es una falla del instrumento). Los cuatro tonos de mas abajo
    estan sacados A OJO de la captura y son aproximados.

    REGLAS DEL JUEGO QUE CAMBIAN LO QUE SE DIBUJA (de la wiki, no inventadas)

    - La cordura oscila +-2 % por jugador a proposito, para que se lea organica.
      Un valor quieto no es lo normal.
    - Un jugador que todavia no cargo aparece como "Loading..." con un GUION en
      vez del porcentaje. Uno MUERTO aparece con "?" . Uno que se fue del
      servidor desaparece de la lista.
    - En Nightmare e Insanity el monitor de cordura y el de actividad estan
      DANADOS y dan lecturas al azar. Es un estado distinto de "no hay datos".
    - La actividad va de 0 a 10 y el eje X es SEGUNDOS HACIA ATRAS: el 0 de la
      izquierda es AHORA. Durante una caceria vale siempre 10.
    - Los sensores de sonido se etiquetan con el CUARTO donde se pusieron, no
      con un numero, y el valor va en porcentaje (0,1 dB del microfono
      parabolico = 1 %).

    LO QUE NO HACE
    Nada de esto mide nada. Los valores salen de PHANTASMAGORIA.TruckData, que
    arranca VACIO — no en cero. Una lista vacia se dibuja como "SIN SENAL" (la
    cadena Monitor_NoInput del juego) y no se puede confundir con un sensor que
    anda y no detecta, que es justo lo que un cero convincente si haria.
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

--[[
    La RELACION DE ASPECTO no es cosmetica.

    Las UV de la pantalla de este modelo son EXACTAS en [0,1] (medido en el GLB:
    los 4 vertices del quad 'Glass' dan u 0.000000..1.000000, v igual), asi que
    la textura se estira sobre el rectangulo real de la pantalla. Ese rectangulo
    mide 1.2300 x 0.7119 m -> 1.7278 : 1 (bl_screen_orient.py sobre el slot 1).

    1024 / 1.7278 = 592.7, o sea 593. Con un RT cuadrado todo saldria achatado
    un 42 % y nada en la pagina indicaria que el problema es el RT.
]]
local W, H = 1024, 593

local MODEL   = "models/phantasmagoria/trucktv.mdl"
--[[
    El quinto, `cctv`, NO es un monitor colgante: es la pantalla grande apoyada
    sobre el mueble `CCTV_Unit` del camion. Se dibuja sobre el mismo modelo
    porque en el juego es la misma malla (`TV_Hanging` 65:1424 + el quad
    `Glass`; las CINCO pantallas del camion montan la misma, y lo que las
    diferencia es el Canvas que llevan adentro — censo del camion, seccion 10).

    Lo que si es distinto es el DIBUJO: los cuatro colgantes tienen fondo oscuro
    y cromo comun (marco, cabecera con titulo, marca arriba a la derecha) y el
    CCTV tiene fondo CLARO y NO tiene nada de ese cromo — arranca directo con
    las tres pestanas. Eso no es una eleccion de estilo: esta mirado en las
    capturas del autor (out/truck/ref/), y por eso el layout apaga el cromo.
]]
local LAYOUTS = { "sanity", "activity", "sound", "map", "cctv" }

--[[
    El sufijo con el que se busca el submaterial de la pantalla.

    Se busca POR NOMBRE y no por indice a proposito. El indice fijo ya fue un
    error una vez en este addon: SetSubMaterial(1) es la pantalla en el paramic
    2 y 3 y es el PLATO en el paramic 1, que no tiene pantalla — y no da error,
    se ve mal, que es peor. Aca el orden real del .mdl es

        trucktv: 0 = trucktv (cuerpo), 1 = trucktv_screen

    pero se busca igual, para que agregar una pieza al modelo no rompa esto en
    silencio.

    La funcion se define local A PROPOSITO en vez de reusar la del archivo de
    los paramic: depender del orden de carga de autorun para una funcion es una
    fragilidad que no se paga por ahorrar ocho lineas.
]]
local SCREEN_SUFFIX = "_screen"

local function findScreenSub( ent )
    if not IsValid( ent ) then return nil end
    local mats = ent:GetMaterials()
    if not istable( mats ) then return nil end
    for i, m in ipairs( mats ) do
        -- GetMaterials() es base 1 y SetSubMaterial base 0.
        if string.EndsWith( m, SCREEN_SUFFIX ) then return i - 1, m end
    end
    return nil
end

--[[-------------------------------------------------------------------------
    LOS DATOS

    Arrancan VACIOS. Que los llene es trabajo del mod; hoy no hay nada que mida
    cordura, sonido, movimiento ni actividad.

    Forma esperada:

      sanity.damaged            true en Nightmare/Insanity: lecturas al azar
      sanity.players            { { name, pct, color, state }, ... } hasta 4
                                state = "ok" | "loading" | "dead"
                                color = "#RRGGBB"; pct se ignora si no es "ok"

      activity.damaged          idem
      activity.strength         61 enteros 0..10. EL INDICE 1 ES AHORA (t=0) y
                                el 61 es hace 60 segundos.

      sound.sensors             { { room = "UTILITY", pct = 0..100 }, ... } hasta 4

      map.name                  nombre del sitio, va de titulo
      map.floor / map.floors    piso actual y cuantos hay
      map.players               { { x, y, ang, color } }  x,y en 0..1 del plano
      map.motion                { { x, y, ang, tripped } }
      map.sound                 { { x, y, r } }  r en fraccion del ancho

      cctv.tab                  "cctv" | "video" | "head"  (la pestana activa)
      cctv.live                 true si hay una camara transmitiendo. Con true
                                el visor queda VACIO y la imagen la compone Lua
      cctv.rec / cctv.nv        true si esta grabando / con vision nocturna
      cctv.cameras              { { name, selected }, ... } hasta 4 por pagina
      cctv.page / cctv.pages    pagina de la lista y cuantas hay

    EL VIDEO NO LO DIBUJA LA PAGINA, y el motivo es una limitacion real: en el
    juego la vista sale de una `UI Camera` de Unity que renderiza a la textura
    del Canvas; aca la pantalla ES un panel DHTML, y no hay forma de meter un
    RenderTarget de Source ADENTRO de una pagina web.

    La salida no es meter el video en la pagina: es NO componer en la pagina.
    `DrawTruckTV` ya dibuja el material del DHTML sobre un RenderTarget propio,
    asi que el feed de la camara se dibuja ENCIMA, en el rectangulo del visor —
    composicion en Source, que es donde el RT existe. El titulo y el timecode
    van despues del feed y por eso tampoco estan en la pagina.

    Quien llena todo esto es `phantasmagoria_trucktv_cctv.lua`.
---------------------------------------------------------------------------]]
local function emptyData()
    return {
        sanity   = { damaged = false, players = {} },
        activity = { damaged = false, strength = {} },
        sound    = { sensors = {} },
        map      = { name = "", floor = 1, floors = 1, players = {}, motion = {}, sound = {} },
        cctv     = { tab = "cctv", live = false, rec = false, nv = false,
                     cameras = {}, page = 1, pages = 1 },
    }
end

PHANTASMAGORIA.TruckData = emptyData()

--[[
    Los cuatro colores de jugador, SACADOS A OJO de la captura del autor.

    No estan medidos: ver la nota de arriba. Cada uno lleva su tono vivo (la
    parte llena de la barra) y su tono apagado (el resto), que en la captura es
    el mismo matiz mucho mas oscuro.
]]
PHANTASMAGORIA.TRUCK_PLAYER_COLORS = { "#b81832", "#6acb3e", "#2cbfc0", "#f02bdd" }

--[[-------------------------------------------------------------------------
    LA PAGINA

    Vive aca adentro y no en un archivo .html suelto por una razon concreta:
    la lista blanca de archivos de un .gma de Garry's Mod no incluye `.html`.
    Un archivo html en la carpeta del addon funciona mientras el addon este
    montado como carpeta (que es como esta hoy, por junction) y DESAPARECE al
    subirlo al Workshop, sin ningun error: la pantalla quedaria en blanco solo
    para los suscriptores. Metido en el .lua viaja siempre.

    Para verla en un navegador:
        python dev\phastools\trucktv_html.py           (la extrae a un .html)

    Decisiones de dibujo, y por que:
      - El cromo (marco, cabecera, la marca GH//OS.T arriba a la derecha) es
        comun a los cuatro monitores porque en el juego lo es.
      - Un eje por grafico, y la actividad va de 0 a 10 con el eje X en segundos
        HACIA ATRAS: el 0 de la izquierda es ahora. Dibujarlo al reves se ve
        perfectamente plausible y esta mal.
      - Los estados de un jugador (cargando / muerto) van con SIMBOLO Y PALABRA,
        no con color: en la pantalla del camion los colores ya estan tomados
        para identificar a cada jugador, asi que no pueden codificar otra cosa.
      - NO hay capa de hover ni tooltips. No es un olvido: esto es una textura
        sobre un prop, no hay puntero que la recorra. Todo lo que haga falta
        leer tiene que estar dibujado.

    Contrastes calculados contra el fondo del panel, no elegidos a ojo: el texto
    principal (#ffffff) da 18.4 : 1, el secundario (#9fb0b4) 8.0 : 1, la serie
    naranja (#e87a2e) 6.2 : 1 y el amarillo del sonido (#d8e88f) 12.8 : 1.
]]
local PAGE = [==[
<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
/* LA PALETTA SALE DE LAS CAPTURAS DEL JUEGO, no de un gusto.
   La primera version era casi negra (#080d0f) y las pantallas de verdad son un
   gris azulado DESATURADO y bastante mas claro. La consecuencia no era solo
   estetica: la cuadricula del grafico estaba dibujada con la densidad correcta
   y NO SE VEIA, porque #1d2f2c sobre un fondo casi negro no tiene contraste. O
   sea que el defecto "faltan las gradas" y el defecto "el fondo es negro" eran
   el mismo defecto, y arreglar uno solo no alcanzaba.
   Estos valores estan leidos A OJO de las fotos: es lo unico de este archivo
   que no esta medido, y las fotos vienen con bloom y aberracion cromatica del
   post del juego, asi que el numero exacto no se puede sacar de ahi. */
:root{
  --bg:#333e3c; --panel:#2d3836; --band:#404b47; --edge:#5c6965;
  --grid:#4d5a56;
  --ink:#ffffff; --ink2:#c3cfd0; --ink3:#8c9b9c;
  --frame:#ffffff; --mark:#e8eef0;
  --serie:#f2662c; --sound:#d8e88f; --warn:#f2c230;
  --plan:#9aa3a5; --plan-line:#222c2a;
  --win:#d0402f; --door:#3fbf5a; --motion:#e8892e;
  --btn:#26302e;

  /* LA PALETA DEL CCTV, que es la de otra pantalla y va aparte.
     Fondo CLARO y acento ambar, al reves que los cuatro colgantes. Leida a ojo
     de las capturas (out/truck/ref/), igual que la de arriba y con el mismo
     limite: las fotos traen bloom y aberracion cromatica del post del juego,
     asi que el valor exacto no sale de ahi.
     Los CONTRASTES si estan calculados, contra el fondo real de cada texto:
       texto oscuro en pestana activa   #1e2629 / #e8eef0  = 13.1 : 1
       texto claro en pestana inactiva  #dfe7e9 / #4a565b  =  6.0 : 1
       texto de boton                   #e6eef0 / #3f4d52  =  7.5 : 1
       ambar sobre el visor             #f5c518 / #101314  = 11.5 : 1
       SIN SEÑAL sobre la estatica      #c2ccce / #2a3236  =  8.0 : 1
       SELECTED sobre la grilla ambar   #f7d046 / #140c04  = 13.0 : 1 */
  --c-bg:#c9d3d5; --c-tab:#4a565b; --c-tab-on:#e8eef0; --c-tab-ink:#1e2629;
  --c-btn:#3f4d52; --c-btn-ink:#e6eef0; --c-ink:#1e2629;
  --c-feed:#101314; --c-static:#2a3236; --c-static-ink:#c2ccce;
  --c-amber:#f5c518; --c-amber2:#f7d046; --c-sel-bg:#140c04; --c-sel-line:#7a4a10;
  --c-edge:#8f9b9e; --c-rec:#e0342a;
}
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:1024px;height:593px;overflow:hidden}
body{
  background:var(--bg); color:var(--ink);
  font-family:"Bahnschrift","DIN Alternate",Corbel,"Segoe UI",Tahoma,sans-serif;
  font-size:16px;
}

/* ---------- cromo comun ---------- */
#frame{
  position:absolute; left:26px; top:22px; right:26px; bottom:22px;
  border:2px solid var(--frame); display:flex; flex-direction:column;
}
/* la barra vertical clara sobre el borde izquierdo, que en el juego sobresale
   del marco por arriba y por abajo */
#rail{position:absolute; left:-5px; top:22px; bottom:22px; width:8px; background:var(--frame)}
#head{
  height:58px; flex:0 0 58px; display:flex; align-items:center;
  padding:0 18px; gap:16px; background:var(--band);
}
#title{
  font-size:27px; font-weight:700; letter-spacing:.045em; text-transform:uppercase;
  white-space:nowrap; overflow:hidden; text-overflow:ellipsis;
}
#mark{
  margin-left:auto; font-size:13px; font-weight:700; letter-spacing:.02em;
  border-bottom:2px solid var(--mark); padding-bottom:1px; white-space:nowrap;
}
#mark i{font-style:normal; color:var(--mark)}
#panel{
  flex:1; margin:0 14px 14px; background:var(--panel); border:1px solid var(--edge);
  position:relative; overflow:hidden;
}

/* solo el layout activo se dibuja */
/* left/top/right/bottom EXPLICITOS y no `inset`: la forma corta es de
   Chrome 87+ y el CEF de Garry's Mod es mas viejo. Ahi la regla se descarta
   entera, el bloque queda sin estirar y TODO el contenido colapsa arriba a la
   izquierda en un rincon — que es exactamente como se vio en la primera pasada
   en juego, mientras en el navegador de escritorio salia perfecto. */
.screen{display:none; position:absolute; left:0; top:0; right:0; bottom:0; padding:16px}
body[data-layout="sanity"]   #s-sanity,
body[data-layout="activity"] #s-activity,
body[data-layout="sound"]    #s-sound,
body[data-layout="map"]      #s-map,
body[data-layout="cctv"]     #s-cctv{display:flex; flex-direction:column}

/* ---------- EL CCTV APAGA EL CROMO COMUN ----------
   Los cuatro colgantes comparten marco, cabecera y marca porque en el juego lo
   comparten. La pantalla del CCTV no tiene NADA de eso: empieza directo con
   las tres pestanas y llena el rectangulo entero. Y su fondo es CLARO, al
   reves que los otros cuatro. Las dos cosas estan mirandas en las capturas del
   autor, no elegidas.

   Se apaga con reglas y no con un HTML aparte para que el resto del archivo
   (montaje, cola de JS, puntero, RenderTarget) siga siendo uno solo. */
body[data-layout="cctv"] #head{display:none}
body[data-layout="cctv"] #rail{display:none}
body[data-layout="cctv"] #frame{left:0; top:0; right:0; bottom:0; border:0}
body[data-layout="cctv"] #panel{margin:0; border:0; background:var(--c-bg)}
body[data-layout="cctv"] .screen{padding:14px 16px}

/* SIN SENAL: no es un cero, es la ausencia de fuente */
.nosig{
  position:absolute; left:0; top:0; right:0; bottom:0;
  display:flex; flex-direction:column; align-items:center; justify-content:center;
  background:var(--panel);
}
.nosig b, .nosig span{display:block; margin:4px 0}
.nosig b{font-size:30px; letter-spacing:.26em; color:var(--warn); font-weight:700}
.nosig span{font-size:14px; letter-spacing:.06em; color:var(--ink3)}
/* DANADO no es lo mismo que sin senal: hay senal y no sirve */
.dmg b{color:var(--win)}

/* ---------- TEAM SANITY ---------- */
#avg{text-align:center; padding:6px 0 14px}
#avg .l{font-size:22px; font-weight:700; letter-spacing:.12em}
#avg .v{font-size:26px; font-weight:700; letter-spacing:.04em}
/* Las columnas y las filas las pone el JS segun cuantos jugadores hay: con uno
   la barra va sola y grande, con dos una a cada lado, con cuatro una en cada
   esquina. `grid-gap` ademas de `gap` porque el CEF viejo solo entiende el
   primero en grid. */
#players{flex:1; display:grid; gap:16px 22px; grid-gap:16px 22px;
         padding:0 20px 4px; min-height:0}
/* Arriba a la derecha y NO abajo: abajo se montaba encima del porcentaje de la
   ultima tarjeta, y un boton que tapa un dato es peor que no tener boton. */
#pager{
  position:absolute; right:18px; top:18px; font-size:14px; letter-spacing:.1em;
  color:var(--ink2); border:1px solid var(--edge); background:var(--btn); padding:5px 12px;
  cursor:pointer;
}
#pager:hover{color:var(--ink); border-color:var(--frame)}
.pc{border:2px solid var(--frame); display:flex; flex-direction:column; overflow:hidden}
/* En tarjeta ancha el estado va a la derecha del nombre; en tarjeta angosta
   (5 jugadores o mas) va DEBAJO, porque si no "JUGADOR 3" y "MUERTO" quedan
   pegados sin espacio y "Loading..." se sale del recuadro. Es una decision de
   ancho, asi que la toma el JS que ya sabe cuantas columnas puso. */
.pc .nm{
  flex:1; display:flex; align-items:center; padding:0 12px; min-width:0;
  font-size:17px; letter-spacing:.04em; color:var(--ink);
  overflow:hidden; background:var(--band);
}
.pc .nm .who{white-space:nowrap; overflow:hidden; text-overflow:ellipsis}
.pc.narrow .nm{flex-direction:column; align-items:flex-start; justify-content:center}
.pc.narrow .nm .who{font-size:15px; max-width:100%}
.pc.narrow .st{margin-left:0; margin-top:3px; font-size:12px}
.pc .bar{height:38px; flex:0 0 38px; position:relative}
.pc .bar .fill{position:absolute; left:0; top:0; bottom:0}
.pc .bar .v{
  position:absolute; right:10px; top:50%; transform:translateY(-50%);
  font-size:22px; font-weight:700; font-variant-numeric:tabular-nums;
}
/* cargando / muerto: el color ya identifica al jugador, asi que el estado se
   dice con palabra y simbolo */
.pc.off .nm{color:var(--ink3)}
.pc .st{font-size:15px; letter-spacing:.1em; color:var(--ink2); margin-left:auto}

/* ---------- TOTAL ACTIVITY ---------- */
#actwrap{flex:1; display:flex; min-height:0; padding:4px 10px 2px}
#actwrap svg{flex:1; width:100%; height:100%}
.gl{stroke:var(--grid); stroke-width:1}
.ax{stroke:var(--frame); stroke-width:2}
.tk{fill:var(--ink); font-size:13px}
.tt{fill:var(--ink); font-size:14px; letter-spacing:.14em; font-weight:700}
.ln{fill:none; stroke:var(--serie); stroke-width:2; stroke-linejoin:round; stroke-linecap:round}

/* ---------- SOUND SENSORS ---------- */
#sensors{flex:1; display:flex; flex-direction:column; justify-content:space-around;
         padding:22px 26px; min-height:0}
.sr{display:flex; flex-direction:column; gap:7px}
.sr .top{display:flex; align-items:center; gap:12px}
/* el recuadro con la flecha, que en el juego lleva cada renglon */
.sr .ic{
  flex:0 0 26px; width:26px; height:26px; border:2px solid var(--frame);
  display:flex; align-items:center; justify-content:center;
  font-size:16px; line-height:1; color:var(--frame);
}
.sr .rm{font-size:19px; font-weight:700; letter-spacing:.07em; text-transform:uppercase}
/* una ranura sin sensor no se esconde: se muestra apagada, como en el juego */
.sr.off .ic{border-color:var(--ink3); color:var(--ink3)}
.sr.off .rm, .sr.off .pv{color:var(--ink3)}
.sr .pv{margin-left:auto; font-size:19px; font-weight:700; font-variant-numeric:tabular-nums}
.sr .axis{position:relative; height:20px}
.sr .axis .line{position:absolute; left:0; right:0; bottom:0; height:2px; background:var(--frame)}
.sr .axis .t{position:absolute; bottom:0; width:2px; height:8px; background:var(--frame)}
.sr .axis .fill{position:absolute; left:0; bottom:2px; height:11px; background:var(--sound)}

/* ---------- SITE MAP ---------- */
#mapwrap{flex:1; position:relative; min-height:0; display:flex}
#mapwrap canvas{margin:auto; display:block}
/* EL ANCHO ES FIJO, Y NO ES UN DETALLE.
   Antes este bloque no tenia ancho: se lo daba su hijo mas ancho, que es la
   ETIQUETA. Y como los hijos van centrados, "PLANTA BAJA" y "SUBSUELO 2" miden
   distinto y **las flechas se corrian solas al cambiar de piso**. O sea que el
   boton se mudaba justo cuando lo acababas de apretar, que es el peor momento
   posible: apuntas, aciertas, y el siguiente click ya no cae donde estaba.
   Con ancho y alto fijos, la etiqueta puede decir cualquier cosa y los dos
   botones no se mueven nunca. */
#floors{
  position:absolute; left:10px; top:50%; transform:translateY(-50%);
  width:104px; display:flex; flex-direction:column; gap:8px; align-items:center;
}
/* las flechas de piso son lo unico clickeable de la pagina, igual que en el
   juego: "Two arrows can be found on the left side of the screen".
   Y son GRANDES a proposito: esto se apunta con la cabeza desde dos metros, no
   con un mouse a 20 cm. Un boton de 22 px es puntero de escritorio. */
#floors .fb{
  flex:0 0 auto; width:62px; height:46px;
  display:flex; align-items:center; justify-content:center;
  font-size:26px; color:var(--ink2); line-height:1; cursor:pointer;
  border:2px solid var(--edge); background:var(--btn);
}
#floors .fb.dis{color:#5a6763; border-color:#3b4643}
#floors .fb:hover:not(.dis){color:var(--ink); border-color:var(--frame)}
/* alto fijo y sin wrap: si la etiqueta se parte en dos lineas, empuja la
   flecha de abajo y volvemos al mismo problema por otra puerta */
#floors .lb{
  flex:0 0 42px; height:42px; width:100%; overflow:hidden;
  font-size:12px; color:var(--ink3); letter-spacing:.08em; text-align:center;
  white-space:nowrap;
}
#floors .lb b{display:block; font-size:15px; color:var(--ink2)}

/* ---------- CCTV CAMERAS ----------
   La disposicion sale de la captura frontal: tres pestanas arriba, el visor
   grande a la izquierda ocupando casi todo el alto, una columna de cuatro
   celdas a la derecha con una flecha arriba y otra abajo, y la botonera abajo
   a lo ancho del visor.

   Las PROPORCIONES son lectura de la captura, no medicion: la imagen llego
   pegada en el chat y no como archivo, asi que no se le paso ningun
   instrumento. Estan escritas en fracciones y no en pixeles para que ajustarlas
   contra una captura guardada sea cambiar un numero. */
#cctv-tabs{display:flex; gap:10px; flex:0 0 52px; height:52px}
.ctab{
  flex:1; display:flex; align-items:center; justify-content:center;
  background:var(--c-tab); color:#dfe7e9;
  font-size:24px; font-weight:700; letter-spacing:.05em; text-transform:uppercase;
  cursor:pointer; user-select:none;
}
/* La pestana activa se distingue por FONDO, que es como lo hace el juego. El
   color solo no alcanzaria: sobre una textura de prop, a distancia y con la luz
   del camion encima, un borde de 2 px no se ve. */
.ctab.on{background:var(--c-tab-on); color:var(--c-tab-ink)}
#cctv-body{flex:1; display:flex; gap:12px; padding-top:12px; min-height:0}
#cctv-left{flex:1; display:flex; flex-direction:column; min-width:0}
#cctv-view{
  flex:1; position:relative; background:var(--c-feed); overflow:hidden; min-height:0;
}
/* El titulo y el timecode NO estan en esta hoja: van sobre la imagen y los
   dibuja Lua despues de componer el feed. Si los dibujara la pagina, el feed
   —que se dibuja encima— los taparia. */
/* La botonera: REC y NV son un boton; PAN y ZOOM son un label con un boton de
   cada lado. Eso NO es una decision de diseno: es la estructura del Canvas del
   juego (`PAN Buttons` y `ZOOM Buttons` traen dos `Button` cada uno y
   `REC Button` / `NV Button` uno solo) y se confirmo mirando la captura. */
#cctv-bar{
  flex:0 0 56px; height:56px; display:flex; align-items:center; gap:14px;
  padding-top:12px;
}
#cctv-logo{
  flex:0 0 auto; font-size:11px; font-weight:700; letter-spacing:.12em;
  color:var(--c-ink); text-align:center; line-height:1.1;
}
#cctv-logo i{display:block; font-style:normal; font-size:20px}
/* GRABANDO: el logo parpadea en rojo. La animación la lleva el CSS y no un
   temporizador de JS a propósito — el parpadeo tiene que seguir aunque nadie
   redibuje, y un `setInterval` más para esto sería un tercer temporizador
   corriendo sobre una textura de prop. */
#cctv-logo.rec{color:var(--c-rec); animation:phblink 1s steps(1,end) infinite}
@keyframes phblink{0%,49%{opacity:1} 50%,100%{opacity:.15}}
.cbtn{
  background:var(--c-btn); color:var(--c-btn-ink); border:0;
  font-size:22px; font-weight:700; letter-spacing:.09em;
  padding:9px 26px; cursor:pointer; user-select:none; white-space:nowrap;
}
.cbtn.on{background:var(--c-amber); color:var(--c-sel-bg)}
.cgroup{display:flex; align-items:stretch; gap:6px}
.cgroup .arw{
  background:var(--c-btn); color:var(--c-btn-ink); border:0;
  display:flex; align-items:center; padding:0 14px; font-size:20px; cursor:pointer;
}
#cctv-list{
  flex:0 0 292px; display:flex; flex-direction:column; gap:8px; min-height:0;
}
.cpage{
  flex:0 0 40px; background:var(--c-btn); color:var(--c-btn-ink);
  display:flex; align-items:center; justify-content:center; font-size:20px;
  cursor:pointer; user-select:none;
}
.ccell{
  flex:1; position:relative; min-height:0; overflow:hidden;
  border:3px solid transparent; background:var(--c-static);
}
/* La celda seleccionada: borde ambar Y grilla ambar Y la palabra. El borde
   ambar sobre el fondo claro da 1.10 : 1 de contraste de luminancia — o sea
   que como UNICA senal no serviria. Por eso la palabra "SELECTED" no es
   decoracion: es la senal que se lee. Es la misma regla que ya vale para los
   estados de jugador de la pantalla de cordura. */
.ccell.sel{border-color:var(--c-amber); background:var(--c-sel-bg)}
.ccell .cname{
  position:absolute; left:8px; top:5px; font-size:19px; font-weight:700;
  letter-spacing:.05em; color:var(--c-static-ink); z-index:2;
}
.ccell.sel .cname{color:var(--c-amber)}
.ccell .cmid{
  position:absolute; left:0; top:0; right:0; bottom:0;
  display:flex; align-items:center; justify-content:center;
  font-size:20px; font-weight:700; letter-spacing:.14em; color:var(--c-static-ink);
}
.ccell.sel .cmid{color:var(--c-amber2)}
/* La grilla ambar de la celda seleccionada. Dos gradientes repetidos y no una
   imagen: no hay archivos que cargar dentro de esta pagina. */
.ccell.sel .grid{
  position:absolute; left:0; top:0; right:0; bottom:0;
  background-image:
    repeating-linear-gradient(0deg,  var(--c-sel-line) 0 1px, transparent 1px 15px),
    repeating-linear-gradient(90deg, var(--c-sel-line) 0 1px, transparent 1px 15px);
  opacity:.85;
}
/* La ESTATICA de una celda sin senal. En el juego las celdas vacias tienen
   ruido, no negro, y la diferencia importa: negro se lee como "apagado" y
   ruido se lee como "encendido y sin fuente", que es lo que significa. */
/* `image-rendering:pixelated` NO es cosmético acá: sin eso el navegador
   interpola al estirar el mosaico y la estática sale BORROSA, que se lee como
   una textura sucia y no como una señal perdida. Con el grano nítido se lee
   como ruido. (Chrome lo tiene desde la 41, así que el CEF 87 de GMod lo
   soporta; `crisp-edges` va de fallback para motores viejos.) */
.snow{image-rendering:crisp-edges; image-rendering:pixelated}
.ccell .snow{position:absolute; left:0; top:0; right:0; bottom:0; opacity:.55}
#cctv-view .snow{position:absolute; left:0; top:0; right:0; bottom:0; opacity:.5}
#cctv-view .cmid{
  position:absolute; left:0; top:0; right:0; bottom:0;
  display:flex; flex-direction:column; align-items:center; justify-content:center;
  color:var(--c-static-ink);
}
#cctv-view .cmid b{font-size:34px; letter-spacing:.24em; color:var(--c-amber)}
#cctv-view .cmid span{font-size:15px; letter-spacing:.06em; margin-top:8px}

/* ---------- el puntero, dibujado DENTRO de la pagina ----------
   No hay cursor del sistema sobre una textura: el unico puntero que existe es
   este, y por eso se dibuja aunque no se este apuntando a nada clickeable. Si
   no se dibujara, no habria forma de saber si el problema es la punteria o que
   el click no llega. */
#cursor{
  position:absolute; left:0; top:0; width:22px; height:22px; margin:-11px 0 0 -11px;
  pointer-events:none; display:none; z-index:99;
}
#cursor::before,#cursor::after{
  content:""; position:absolute; background:var(--frame); box-shadow:0 0 0 1px #000a;
}
#cursor::before{left:0; top:10px; width:22px; height:2px}
#cursor::after{left:10px; top:0; width:2px; height:22px}
#cursor.dn::before,#cursor.dn::after{background:var(--mark)}
</style></head><body data-layout="sanity">

<div id="frame">
  <div id="rail"></div>
  <div id="head">
    <div id="title">TEAM SANITY</div>
    <div id="mark">GH<i>//</i>OS.T</div>
  </div>
  <div id="panel">

    <div class="screen" id="s-sanity">
      <div id="avg"><div class="l">AVERAGE</div><div class="v" id="avgv">--</div></div>
      <div id="players"></div>
    </div>

    <div class="screen" id="s-activity"><div id="actwrap"></div></div>

    <div class="screen" id="s-sound"><div id="sensors"></div></div>

    <div class="screen" id="s-map">
      <div id="mapwrap"><canvas id="plan" width="740" height="420"></canvas></div>
      <div id="floors"></div>
    </div>

    <div class="screen" id="s-cctv">
      <div id="cctv-tabs"></div>
      <div id="cctv-body">
        <div id="cctv-left">
          <div id="cctv-view"></div>
          <div id="cctv-bar"></div>
        </div>
        <div id="cctv-list"></div>
      </div>
    </div>

  </div>
  <div id="cursor"></div>
</div>

<script>
"use strict";
var D = null, PLAN = null, LAYOUT = "sanity";

/* Los titulos salen del `localisation` del juego (IDs `Monitor_*` y `Truck_*`),
   que es el texto autoritativo — no una traduccion de memoria. El de `cctv` no
   se usa: esa pantalla no tiene cabecera. */
var TITLES = { sanity:"TEAM SANITY", activity:"TOTAL ACTIVITY", sound:"SOUND SENSORS", map:"SITE MAP", cctv:"" };

/* Los textos de la pantalla del CCTV, uno por uno con su ID del `localisation`
   del juego, en la columna `en` — que es la que pidio el autor despues de verlo
   en juego:

     Monitor_CctvCameras   CCTV CAMERAS      (es: CÁMARAS CCTV)
     Monitor_VideoCameras  VIDEO CAMERAS     (es: CÁMARAS DE VIDEO)
     Monitor_HeadCameras   HEAD CAMERAS      (es: CÁMARAS DE CABEZA)
     Monitor_Record        REC
     Monitor_Pan           PAN
     Monitor_NightVision   NV
     Monitor_Zoom          ZOOM
     Monitor_Selected      SELECTED          (es: SELECCIONADO)
     Monitor_NoInput       NO INPUT          (es: SIN SEÑAL)

   Las dos columnas estan al lado a proposito: el `localisation` trae los 29
   idiomas, asi que cambiar de idioma es cambiar de columna y NO retraducir.
   Los otros cuatro layouts siguen en espanol — son texto propio del mod y no
   cadenas del juego; esta pantalla replica una del juego y por eso va literal. */
var CCTV_TXT = {
  cctv:"CCTV CAMERAS", video:"VIDEO CAMERAS", head:"HEAD CAMERAS",
  rec:"REC", pan:"PAN", nv:"NV", zoom:"ZOOM",
  selected:"SELECTED", noinput:"NO INPUT"
};
var CCTV_TABS = ["cctv","video","head"];

function esc(s){ return String(s).replace(/[&<>]/g, function(c){
  return {"&":"&amp;","<":"&lt;",">":"&gt;"}[c]; }); }

function clamp(v, hi){ v = Number(v); if (!isFinite(v)) return 0;
  hi = hi || 100; return v < 0 ? 0 : (v > hi ? hi : v); }

/* "SIN SENAL" (Monitor_NoInput) para la AUSENCIA de fuente; "SENAL DANADA"
   para Nightmare/Insanity, donde SI hay lecturas y no sirven. Son dos estados
   distintos y confundirlos es confundir "no hay sensores" con "el monitor
   miente", que llevan a decisiones opuestas.

   El motivo va por esc() y por eso se escribe con caracteres UTF-8 de verdad y
   NO con entidades HTML: escapar una entidad la muestra literal en pantalla
   ("ning&uacute;n sensor..."). La pagina declara charset utf-8 y el .lua es
   utf-8, asi que la ñ viaja entera. */
function noSignal(hint, damaged){
  return '<div class="nosig' + (damaged ? ' dmg' : '') + '"><b>' +
    (damaged ? "SEÑAL DAÑADA" : "SIN SEÑAL") +
    '</b><span>' + esc(hint) + '</span></div>';
}

/* mezcla hacia negro, para el tramo apagado de la barra */
function dim(hex, f){
  var n = parseInt(String(hex).replace("#",""), 16);
  if (!isFinite(n)) return "#333";
  var r = (n>>16)&255, g = (n>>8)&255, b = n&255;
  return "rgb(" + Math.round(r*f) + "," + Math.round(g*f) + "," + Math.round(b*f) + ")";
}

/* ---------------- TEAM SANITY ----------------
   El reparto lo decide la CANTIDAD de jugadores, y las tarjetas llenan la
   pantalla: con uno la barra va sola y grande, con dos una a cada lado, con
   tres dos arriba y una abajo cruzada, con cuatro una en cada esquina. De 5 a 8
   se agrega una columna por par y la ultima fila se centra si queda impar.
   Arriba de 8 se pagina, porque ocho tarjetas ya es el limite en el que el
   nombre y el porcentaje siguen siendo legibles desde el otro lado del camion. */
var PAGE_MAX = 8;
var pagina = 0;

function gridFor(n){
  if (n <= 1) return { cols: 1, rows: 1 };
  if (n === 2) return { cols: 2, rows: 1 };
  if (n <= 4)  return { cols: 2, rows: 2 };
  if (n <= 6)  return { cols: 3, rows: 2 };
  return { cols: 4, rows: 2 };
}

function drawSanity(){
  var el = document.getElementById("s-sanity");
  var S = (D && D.sanity) || {}, todos = S.players || [];
  var grid = document.getElementById("players");
  var old = el.querySelector(".nosig");
  if (old) old.parentNode.removeChild(old);
  var vp = document.getElementById("pager");
  if (vp) vp.parentNode.removeChild(vp);

  if (S.damaged || !todos.length){
    document.getElementById("avgv").textContent = "--";
    grid.innerHTML = "";
    el.insertAdjacentHTML("beforeend",
      noSignal(S.damaged ? "monitor dañado: las lecturas son al azar"
                         : "nadie en la investigación", S.damaged));
    return;
  }

  /* El promedio es de TODOS los que tienen lectura, no sólo de la página que se
     está viendo: si dependiera de la página, cambiar de página cambiaría el
     promedio del equipo, que es un número que no debería moverse por mirar. */
  var sum = 0, cnt = 0;
  for (var i = 0; i < todos.length; i++)
    if ((todos[i].state || "ok") === "ok"){ sum += clamp(todos[i].pct); cnt++; }
  document.getElementById("avgv").textContent = cnt ? Math.round(sum/cnt) + "%" : "--";

  var paginas = Math.ceil(todos.length / PAGE_MAX);
  if (pagina >= paginas) pagina = 0;
  var ps = paginas > 1 ? todos.slice(pagina*PAGE_MAX, (pagina+1)*PAGE_MAX) : todos;

  var n = ps.length, g = gridFor(n);
  grid.style.gridTemplateColumns = "repeat(" + g.cols + ", 1fr)";
  grid.style.gridTemplateRows    = "repeat(" + g.rows + ", 1fr)";

  var enUltima = n - g.cols * (g.rows - 1);
  var primerDeUltima = g.cols * (g.rows - 1);
  var offset = Math.floor((g.cols - enUltima) / 2);

  var h = "";
  for (var j = 0; j < n; j++){
    var p = ps[j], st = p.state || "ok";
    var col = p.color || "#8a8a8a";
    var v = clamp(p.pct);
    var name = st === "loading" ? "Loading..." : (p.name || ("JUGADOR " + (j+1)));
    var valTxt = st === "ok" ? Math.round(v) + "%" : (st === "dead" ? "?" : "-");
    var w = st === "ok" ? v : 0;

    /* tres jugadores: el tercero cruza las dos columnas, que es como se lee
       mejor un impar chico. Los impares mas grandes centran la última fila. */
    var estilo = "";
    if (n === 3 && j === 2) estilo = "grid-column:1 / -1;";
    else if (g.rows > 1 && j === primerDeUltima && offset > 0)
      estilo = "grid-column-start:" + (offset + 1) + ";";

    h += '<div class="pc' + (st === "ok" ? "" : " off") +
         (g.cols >= 3 ? " narrow" : "") + '" style="' + estilo + '">' +
           '<div class="nm"><span class="who">' + esc(name) + '</span>' +
             (st === "dead" ? '<span class="st">&#9760; MUERTO</span>' : "") +
             (st === "loading" ? '<span class="st">&#8987; CARGANDO</span>' : "") +
           '</div>' +
           '<div class="bar" style="background:' + dim(col, 0.34) + '">' +
             '<div class="fill" style="width:' + w.toFixed(1) + '%;background:' + col + '"></div>' +
             '<div class="v">' + valTxt + '</div>' +
           '</div>' +
         '</div>';
  }
  grid.innerHTML = h;

  if (paginas > 1){
    el.insertAdjacentHTML("beforeend",
      '<div id="pager" data-pg="1">' + (pagina+1) + '/' + paginas + '  &#9654;</div>');
  }
}

/* ---------------- TOTAL ACTIVITY ----------------
   Eje X = SEGUNDOS HACIA ATRAS. El 0 de la izquierda es AHORA: el indice 1 del
   array es la lectura actual. Dibujarlo al reves queda plausible y esta mal.
   Eje Y = 0..10 enteros, que es el rango real del monitor.                  */
function drawActivity(){
  var el = document.getElementById("s-activity");
  var A = (D && D.activity) || {}, s = A.strength || [];

  if (A.damaged || !s.length){
    el.innerHTML = '<div id="actwrap"></div>' +
      noSignal(A.damaged ? "monitor dañado: las lecturas son al azar"
                         : "sin lecturas de actividad", A.damaged);
    return;
  }

  var w = 960, hh = 470, pl = 74, pr = 22, pt = 16, pb = 62;
  var iw = w - pl - pr, ih = hh - pt - pb;
  var N = 60;                                   // 0..60 segundos
  var x = function(t){ return pl + iw * t / N; };
  var y = function(v){ return pt + ih - ih * clamp(v, 10) / 10; };

  var g = "";
  for (var v = 0; v <= 10; v++){
    g += '<line class="gl" x1="' + pl + '" y1="' + y(v).toFixed(1) + '" x2="' + (w-pr) + '" y2="' + y(v).toFixed(1) + '"/>' +
         '<text class="tk" x="' + (pl-10) + '" y="' + (y(v)+5).toFixed(1) + '" text-anchor="end">' + v + '</text>';
  }
  for (var t = 0; t <= N; t += 2)
    g += '<line class="gl" x1="' + x(t).toFixed(1) + '" y1="' + pt + '" x2="' + x(t).toFixed(1) + '" y2="' + (pt+ih) + '"/>';
  for (var t2 = 0; t2 <= N; t2 += 10)
    g += '<text class="tk" x="' + x(t2).toFixed(1) + '" y="' + (pt+ih+22) + '" text-anchor="middle">' + t2 + '</text>';

  var d = "";
  for (var i = 0; i <= N; i++){
    var val = (i < s.length) ? s[i] : 0;
    d += (i ? "L" : "M") + x(i).toFixed(1) + " " + y(val).toFixed(1) + " ";
  }

  el.innerHTML = '<div id="actwrap"><svg viewBox="0 0 ' + w + ' ' + hh + '">' +
      g +
      '<line class="ax" x1="' + pl + '" y1="' + pt + '" x2="' + pl + '" y2="' + (pt+ih) + '"/>' +
      '<line class="ax" x1="' + pl + '" y1="' + (pt+ih) + '" x2="' + (w-pr) + '" y2="' + (pt+ih) + '"/>' +
      '<path class="ln" d="' + d + '"/>' +
      '<text class="tt" transform="translate(24,' + (pt+ih/2) + ') rotate(-90)" text-anchor="middle">STRENGTH</text>' +
      '<text class="tt" x="' + (pl+iw/2) + '" y="' + (hh-14) + '" text-anchor="middle">TIME IN SECONDS</text>' +
    '</svg></div>';
}

/* ---------------- SOUND SENSORS ----------------
   La etiqueta es el CUARTO donde se puso el sensor, no un numero: asi lo hace
   el juego, y es lo que vuelve util al monitor para ubicar al fantasma.     */
function drawSound(){
  var el = document.getElementById("s-sound");
  /* SIN SEÑAL es la ausencia de FUENTE, no la ausencia de sensores. Cero
     sensores colocados es un estado normal de la ronda y el juego lo muestra
     como cuatro OFFLINE; si eso dijera "sin señal", el arranque de cada partida
     se veria como una falla del monitor. */
  var Sd = (D && D.sound) || null;
  if (!Sd){
    el.innerHTML = '<div id="sensors"></div>' + noSignal("sin datos del monitor de sonido", false);
    return;
  }
  var ss = Sd.sensors || [];
  /* SIEMPRE LAS CUATRO RANURAS. El juego muestra los cuatro renglones fijos y
     pone OFFLINE en los que no tienen sensor puesto: la cantidad de sensores
     colocados es un dato del monitor, no algo que se deduzca de cuantas barras
     hay. Con las filas variables, dos sensores puestos y dos sensores rotos se
     veian igual. */
  var h = "";
  for (var i = 0; i < 4; i++){
    var s = ss[i], hay = !!s;
    var v = hay ? clamp(s.pct) : 0;
    var ticks = "";
    for (var t = 1; t < 10; t++) ticks += '<div class="t" style="left:' + (t*10) + '%"></div>';
    h += '<div class="sr' + (hay ? '' : ' off') + '">' +
           '<div class="top">' +
             '<div class="ic">&#8599;</div>' +
             '<div class="rm">' + (hay ? esc(s.room || ("SENSOR " + (i+1))) : "OFFLINE") + '</div>' +
             '<div class="pv">' + Math.round(v) + '%</div></div>' +
           '<div class="axis"><div class="line"></div>' + ticks +
             '<div class="fill" style="width:' + v.toFixed(1) + '%"></div></div>' +
         '</div>';
  }
  el.innerHTML = '<div id="sensors">' + h + '</div>';
}

/* ---------------- SITE MAP ----------------
   El plano llega UNA vez (PH.plan) y los que se mueven llegan por PH.set: si
   se remandara el plano en cada cuadro seria mandar decenas de miles de
   numeros 15 veces por segundo para dibujar lo mismo.                       */
function drawMap(){
  var el = document.getElementById("s-map");
  var M = (D && D.map) || {};
  var cv = document.getElementById("plan");
  var old = el.querySelector(".nosig");
  if (old) old.parentNode.removeChild(old);

  if (!PLAN || !PLAN.areas || !PLAN.areas.length){
    cv.style.display = "none";
    el.insertAdjacentHTML("beforeend",
      noSignal(PLAN && PLAN.reason ? PLAN.reason : "sin plano del sitio", false));
    document.getElementById("floors").innerHTML = "";
    return;
  }
  cv.style.display = "block";

  var g = cv.getContext("2d");
  var CW = cv.width, CH = cv.height;
  g.clearRect(0, 0, CW, CH);

  /* El plano llega normalizado a [0,1] con su propia relacion de aspecto;
     encajarlo sin deformar, o un cuarto cuadrado saldria rectangular. */
  var ar = PLAN.ar || 1;
  var pw = CW, ph = CW / ar;
  if (ph > CH){ ph = CH; pw = CH * ar; }
  var ox = (CW - pw) / 2, oy = (CH - ph) / 2;

  /* EL FOCO DEL ZOOM ES EL CENTRO DE MASA DE LAS AREAS DE ESTE PISO, pesado por
     superficie, y no el centro de la caja. La caja es GLOBAL a proposito (para
     que los pisos queden registrados entre si), asi que su centro puede caer en
     el medio del descampado: acercarse hacia ahi agranda el pasto. El centro de
     masa cae donde esta el grueso del nivel, que es el edificio.
     A VZ = 1 el foco no se usa y el encuadre queda exactamente como antes. */
  var cx = 0.5, cy = 0.5;
  if (VZ !== 1){
    var sw = 0, sx = 0, sy = 0;
    for (var k = 0; k < PLAN.areas.length; k++){
      var q = PLAN.areas[k], wg = q[2] * q[3];
      sw += wg; sx += (q[0] + q[2] / 2) * wg; sy += (q[1] + q[3] / 2) * wg;
    }
    if (sw > 0){ cx = sx / sw; cy = sy / sw; }
  }
  /* pw2/ph2 son el tamano DIBUJADO: todo lo que se mide en fraccion del plano
     (los radios de los sensores) tiene que usar estos y no pw, o el circulo se
     queda del tamano de antes mientras el plano crece. */
  var pw2 = pw * VZ, ph2 = ph * VZ;
  var X = function(u){ return ox + pw / 2 + (u - cx) * pw2; };
  var Y = function(v){ return oy + ph / 2 + (v - cy) * ph2; };

  /* Cada area se dibuja MEDIO PIXEL MAS GRANDE de cada lado, para que las
     areas contiguas se PISEN y se lean como una sola habitacion.

     La primera version hacia lo contrario —un hueco de 1 px alrededor de cada
     area, con la idea de que los huecos son las paredes— y el resultado era
     papel cuadriculado: el navmesh parte una habitacion abierta en decenas de
     cuadraditos, asi que ese hueco dibuja la grilla del navmesh y no las
     paredes. Las paredes de verdad ya son un hueco ANCHO (ninguna area las
     cruza), y ese hueco sobrevive al medio pixel de mas. */
  g.fillStyle = "#9aa3a5";
  for (var i = 0; i < PLAN.areas.length; i++){
    var a = PLAN.areas[i];
    g.fillRect(X(a[0]) - 0.5, Y(a[1]) - 0.5,
               Math.max(1, a[2] * pw2 + 1), Math.max(1, a[3] * ph2 + 1));
  }

  /* LAS PAREDES, ENCIMA DEL PISO.

     Van despues y no antes: el navmesh junta las habitaciones a traves de la
     puerta, asi que el piso caminable sale como una mancha continua y lo que
     hace falta es CORTARLA. Dibujadas debajo, las taparia el mismo piso que
     tienen que separar.

     Llegan como RLE (corridas alternadas abierto/solido, empezando por
     abierto) recorriendo la grilla por filas, y la fila 0 es el borde de arriba
     del plano — el servidor ya la emite con la Y invertida, igual que las
     areas, asi que aca no hay que dar vuelta nada. */
  var Wl = PLAN.walls;
  if (Wl && Wl.rle && Wl.w > 0 && Wl.h > 0){
    var cw = pw2 / Wl.w, chh = ph2 / Wl.h;
    g.fillStyle = "#1b2422";
    var celda = 0, solido = false;
    for (var r = 0; r < Wl.rle.length; r++){
      var n = Wl.rle[r];
      if (solido){
        for (var q = 0; q < n; q++){
          var ci = (celda + q) % Wl.w, cj = Math.floor((celda + q) / Wl.w);
          /* +1 en el tamano: sin eso quedan costuras de un pixel entre celdas
             contiguas y una pared llena se ve rayada */
          g.fillRect(X(ci / Wl.w), Y(cj / Wl.h), cw + 1, chh + 1);
        }
      }
      celda += n; solido = !solido;
    }
  }

  /* radio de los sensores de sonido: circulo ambar translucido, debajo de todo
     lo demas para que no tape */
  var sp = M.sound || [];
  for (var s = 0; s < sp.length; s++){
    var r = (sp[s].r || 0) * pw2;
    var gr = g.createRadialGradient(X(sp[s].x), Y(sp[s].y), 0, X(sp[s].x), Y(sp[s].y), Math.max(r, 1));
    gr.addColorStop(0, "rgba(232,150,50,0.45)");
    gr.addColorStop(1, "rgba(232,150,50,0.05)");
    g.fillStyle = gr;
    g.beginPath(); g.arc(X(sp[s].x), Y(sp[s].y), Math.max(r, 1), 0, 6.2832); g.fill();
  }

  /* sensores de movimiento: barra corta. Verde y parpadeando cuando dispara,
     pero ademas cambia de GROSOR, para que no dependa del color. */
  var mo = M.motion || [];
  for (var m = 0; m < mo.length; m++){
    var a2 = (mo[m].ang || 0) * Math.PI / 180;
    var len = 26, th = mo[m].tripped ? 6 : 3;
    g.save();
    g.translate(X(mo[m].x), Y(mo[m].y));
    g.rotate(a2);
    g.fillStyle = mo[m].tripped ? "#3fbf5a" : "#e8892e";
    g.fillRect(-len/2, -th/2, len, th);
    g.restore();
  }

  /* jugadores: punto de su color, con un cono tenue hacia donde miran */
  var pl2 = M.players || [];
  for (var p = 0; p < pl2.length; p++){
    var px = X(pl2[p].x), py = Y(pl2[p].y), aa = (pl2[p].ang || 0) * Math.PI / 180;
    g.save(); g.translate(px, py); g.rotate(aa);
    var cg = g.createRadialGradient(0, 0, 0, 0, 0, 34);
    cg.addColorStop(0, "rgba(255,255,255,0.30)");
    cg.addColorStop(1, "rgba(255,255,255,0)");
    g.fillStyle = cg;
    g.beginPath(); g.moveTo(0, 0); g.arc(0, 0, 34, -0.6, 0.6); g.closePath(); g.fill();
    g.restore();
    g.fillStyle = pl2[p].color || "#ffffff";
    g.beginPath(); g.arc(px, py, 5.5, 0, 6.2832); g.fill();
    g.strokeStyle = "#0a0f10"; g.lineWidth = 1.5; g.stroke();
  }

  /* Las flechas: sólo se dibujan si hay más de un piso, y la del extremo se
     ve DESHABILITADA en vez de desaparecer — en el juego tampoco "dan la
     vuelta" al llegar al último. Una flecha que desaparece se lee como un
     fallo de dibujo; una apagada dice "acá se termina". */
  var nf = M.floors || 1, cf = M.floor || 1, lb = M.label || 0;
  var nombre = lb === 0 ? "PLANTA BAJA" : (lb > 0 ? "PISO " + lb : "SUBSUELO " + (-lb));
  document.getElementById("floors").innerHTML = nf > 1
    ? '<div class="fb' + (cf >= nf ? ' dis' : '') + '" data-fl="1">&#9650;</div>' +
      '<div class="lb"><b>' + cf + '/' + nf + '</b>' + nombre + '</div>' +
      '<div class="fb' + (cf <= 1 ? ' dis' : '') + '" data-fl="-1">&#9660;</div>'
    : "";
}

/* ---------------- CCTV CAMERAS ----------------
   La quinta pantalla, y la única que no es un monitor colgante: es la grande
   apoyada sobre el mueble. Dibujo calcado de la captura frontal del autor
   (out/truck/ref/) y textos sacados del `localisation` del juego.           */

/* La estática, generada UNA vez por cuadro de animación y reusada. Se dibuja en
   un canvas y se pasa a data URI porque esta página no puede cargar archivos:
   no hay disco del que traerlos.

   DOS COSAS QUE LA PRIMERA VERSIÓN TENÍA MAL, y las dos las vio el autor en
   juego, no ningún chequeo:

   1. El grano era DEMASIADO CHICO. Con una celda de 16 px repetida, cada punto
      de ruido mide un píxel de página, y la página se ve como una textura sobre
      un prop a dos metros: el ruido se promedia a gris parejo y parece una
      superficie lisa. Ahora el grano se dibuja en una grilla chica y se ESTIRA
      (`background-size`), así que cada punto ocupa varios píxeles y se lee como
      ruido de verdad.
   2. Estaba QUIETO. Una estática inmóvil no se lee como "sin señal": se lee
      como una textura. Se anima rotando entre varios cuadros pregenerados.

   Los cuadros se generan una sola vez al arrancar y después sólo se cambia cuál
   se muestra: regenerar ruido 10 veces por segundo en CEF es caro y no hace
   falta para que se vea aleatorio. */
/* Tres números que se equilibran entre sí, y ninguno se puede mover solo:

     SNOW_PX * SNOW_ZOOM  = cada cuánto se REPITE el patrón. Con 24*3 = 72 px
                            el mosaico se repite diez veces a lo ancho del
                            visor y el ojo ve la repetición, no ruido.
     SNOW_ZOOM            = cuántos píxeles mide cada punto de grano.
     SNOW_N               = cuántos cuadros distintos rotan.

   64*3 = 192 px: el patrón entra ~3,5 veces en el visor, que ya no se lee como
   mosaico, y el grano sigue midiendo 3 px. El costo es el peso: cada cuadro es
   un PNG de ruido, que no comprime, así que subir SNOW_PX engorda la página. */
var SNOW_N = 6;
var SNOW_PX = 64;
var SNOW_ZOOM = 3;
var SNOW = (function(){
  var out = [];
  try {
    /* Ruido DETERMINISTA (un LCG con semilla fija) y no Math.random: así dos
       corridas dan la misma imagen y una diferencia en pantalla es un cambio
       de verdad y no el azar. */
    var s = 1234567;
    for (var f = 0; f < SNOW_N; f++){
      var c = document.createElement("canvas");
      c.width = SNOW_PX; c.height = SNOW_PX;
      var g = c.getContext("2d"), im = g.createImageData(SNOW_PX, SNOW_PX), d = im.data;
      for (var i = 0; i < d.length; i += 4){
        s = (s * 1103515245 + 12345) & 0x7fffffff;
        var v = 30 + ((s >> 16) & 0x9f);
        d[i] = d[i+1] = d[i+2] = v; d[i+3] = 255;
      }
      g.putImageData(im, 0, 0);
      out.push(c.toDataURL("image/png"));
    }
  } catch (e) { return []; }
  return out;
})();
var SNOW_I = 0;

function snowDiv(){
  /* Si el canvas falla, el fondo plano del CSS ya deja la celda gris: se pierde
     el ruido, no la celda. Un `return ""` acá no puede dejar un hueco. */
  if (!SNOW.length) return '<div class="snow"></div>';
  var px = SNOW_PX * SNOW_ZOOM;
  return '<div class="snow" style="background-image:url(' + SNOW[SNOW_I] +
         ');background-size:' + px + 'px ' + px + 'px"></div>';
}

/* La animación: cambia el cuadro en los divs que YA existen, sin volver a
   armar el HTML. Redibujar las cuatro celdas y el visor 12 veces por segundo
   para mover ruido sería tirar el trabajo de todo lo demás que hay en pantalla. */
setInterval(function(){
  if (LAYOUT !== "cctv" || !SNOW.length) return;
  SNOW_I = (SNOW_I + 1) % SNOW.length;
  var px = SNOW_PX * SNOW_ZOOM;
  var ns = document.querySelectorAll("#s-cctv .snow");
  for (var i = 0; i < ns.length; i++){
    ns[i].style.backgroundImage = "url(" + SNOW[SNOW_I] + ")";
    ns[i].style.backgroundSize = px + "px " + px + "px";
  }
}, 80);

function drawCctv(){
  var C = (D && D.cctv) || {};
  var tab = C.tab || "cctv";

  /* --- las tres pestañas --- */
  var h = "";
  for (var i = 0; i < CCTV_TABS.length; i++){
    var k = CCTV_TABS[i];
    h += '<div class="ctab' + (k === tab ? ' on' : '') + '" data-tab="' + k + '">' +
         esc(CCTV_TXT[k]) + '</div>';
  }
  document.getElementById("cctv-tabs").innerHTML = h;

  /* --- el visor ---
     EL VIDEO NO LO DIBUJA ESTA PÁGINA. La pantalla se compone en Lua sobre un
     RenderTarget: primero se dibuja esta página entera y después, encima, el RT
     de la cámara en el rectángulo de acá abajo. Por eso cuando hay señal el
     visor queda VACÍO — lo que se vea ahí lo pone Source.

     Sin señal sí dibuja: estática animada y NO INPUT, que es el estado que
     muestra el monitor del juego y el mismo texto (`Monitor_NoInput`) que usan
     los otros cuatro layouts.

     El título y el timecode TAMPOCO están acá aunque en el juego se vean sobre
     la imagen: los dibuja Lua después del feed, porque si los dibujara la
     página el feed los taparía. Un solo dueño por cosa. */
  document.getElementById("cctv-view").innerHTML = C.live ? "" :
    (snowDiv() +
     '<div class="cmid"><b>' + esc(CCTV_TXT.noinput) + '</b>' +
     '<span>no camera is feeding this screen</span></div>');

  /* El rectángulo del visor se MIDE y se manda; no se calcula del otro lado.
     Derivarlo en Lua de los paddings del CSS es exactamente el tipo de cuenta
     que sale mal sin quejarse: el feed aparecería corrido y se leería como un
     problema de la cámara. Acá lo dice el navegador, que es el que lo dibujó. */
  if (window.ph && typeof ph.viewrect === "function"){
    var r = document.getElementById("cctv-view").getBoundingClientRect();
    ph.viewrect(Math.round(r.left), Math.round(r.top),
                Math.round(r.width), Math.round(r.height));
  }

  /* --- la botonera ---
     REC y NV son un botón; PAN y ZOOM son un rótulo con un botón de cada lado.
     Sale de la estructura del Canvas del juego y está confirmado en la captura. */
  /* El rótulo del zoom va PELADO. La primera versión le pegaba el nivel
     ("ZOOM 0") y en el juego no hay ningún número ahí: el dato existe en
     `C.zoom` y no se dibuja, igual que en el original. Un número de más se ve
     perfectamente plausible, que es lo que lo hace difícil de detectar. */
  document.getElementById("cctv-bar").innerHTML =
    '<div id="cctv-logo"' + (C.rec ? ' class="rec"' : '') + '><i>&#9673;</i>CCTV</div>' +
    '<div class="cbtn' + (C.rec ? ' on' : '') + '" data-act="rec">' + esc(CCTV_TXT.rec) + '</div>' +
    '<div class="cgroup">' +
      '<div class="arw" data-act="pan-">&#9664;</div>' +
      '<div class="cbtn" data-act="pan">' + esc(CCTV_TXT.pan) + '</div>' +
      '<div class="arw" data-act="pan+">&#9654;</div>' +
    '</div>' +
    '<div class="cbtn' + (C.nv ? ' on' : '') + '" data-act="nv">' + esc(CCTV_TXT.nv) + '</div>' +
    '<div class="cgroup">' +
      '<div class="arw" data-act="zoom-">&#8722;</div>' +
      '<div class="cbtn" data-act="zoom">' + esc(CCTV_TXT.zoom) + '</div>' +
      '<div class="arw" data-act="zoom+">&#43;</div>' +
    '</div>';

  /* --- la lista ---
     SIEMPRE LAS CUATRO CELDAS, por lo mismo que los cuatro renglones del
     monitor de sonido: en el juego las ranuras vacías se dibujan con NO INPUT,
     así que la cantidad de cámaras puestas es un dato del monitor y no algo
     que se deduzca de cuántas celdas hay. Con celdas variables, "dos cámaras
     puestas" y "dos cámaras rotas" se verían igual. */
  var cams = C.cameras || [];
  var l = '<div class="cpage" data-act="page-">&#9650;</div>';
  for (var j = 0; j < 4; j++){
    var cam = cams[j], hay = !!cam, sel = hay && !!cam.selected;
    l += '<div class="ccell' + (sel ? ' sel' : '') + '" data-cam="' + j + '">';
    if (sel){
      /* Los chevrons son «<<» de los DOS lados. Está mirado en la captura, y
         es justo el detalle que un dibujo de memoria pone simétrico (»…«) y se
         ve igual de bien. */
      l += '<div class="grid"></div>' +
           '<div class="cname">' + esc(cam.name || "") + '</div>' +
           '<div class="cmid">&lt;&lt; ' + esc(CCTV_TXT.selected) + ' &lt;&lt;</div>';
    } else if (hay){
      l += snowDiv() + '<div class="cname">' + esc(cam.name || "") + '</div>';
    } else {
      l += snowDiv() + '<div class="cmid">' + esc(CCTV_TXT.noinput) + '</div>';
    }
    l += '</div>';
  }
  l += '<div class="cpage" data-act="page+">&#9660;</div>';
  document.getElementById("cctv-list").innerHTML = l;
}

/* ---------------- EL PUNTERO ----------------
   Lua manda dónde está apuntando el jugador, en píxeles de esta página, y si
   el botón está apretado. El click se sintetiza acá con elementFromPoint: no
   hay cursor del sistema sobre una textura de un prop, así que el navegador
   nunca va a generar el evento solo.

   El flanco importa: se dispara al PASAR de suelto a apretado, no mientras
   está apretado. Sin eso, mantener el botón medio segundo cambiaría treinta
   pisos.                                                                    */
var pDown = false;
function pointer(x, y, down){
  var c = document.getElementById("cursor");
  if (x < 0 || y < 0){ c.style.display = "none"; pDown = false; return; }
  c.style.display = "block";
  c.style.left = x + "px";
  c.style.top  = y + "px";
  c.className = down ? "dn" : "";

  if (down && !pDown){
    var el = document.elementFromPoint(x, y);
    /* `closest` sube por los padres: el click cae sobre el texto de adentro del
       boton, no sobre el boton. Sin esto, apuntarle justo a la flecha funciona
       y apuntarle al centro del boton no — que se lee como punteria y es
       arbol del DOM. */
    var fb = el && el.closest ? el.closest("[data-fl]") : null;
    var pg = el && el.closest ? el.closest("[data-pg]") : null;
    /* Los tres del CCTV: pestaña, celda de cámara y botón de la barra. */
    var tb = el && el.closest ? el.closest("[data-tab]") : null;
    var cm = el && el.closest ? el.closest("[data-cam]") : null;
    var ac = el && el.closest ? el.closest("[data-act]") : null;
    if (fb && fb.className.indexOf("dis") < 0 &&
        window.ph && typeof ph.floor === "function"){
      ph.floor(Number(fb.getAttribute("data-fl")));
    } else if (pg){
      /* La paginacion es presentacion pura y se resuelve aca: no hay ningun
         dato nuevo que pedirle a Lua, y un viaje de ida y vuelta por un cambio
         de pagina agrega un cuadro de retraso por nada. */
      pagina = pagina + 1;
      render();
    } else if (tb || cm || ac){
      /* Acá, al revés que la paginación de la cordura, NO se resuelve solo: qué
         cámara se ve, si graba o si prende la visión nocturna son estado del
         MOD, no de la página. Si la página lo cambiara sola, el dibujo diría
         una cosa y el mod otra — y el dibujo se vería perfectamente bien.
         Entonces se avisa y se espera el `PH.set` de vuelta. */
      if (window.ph && typeof ph.cctv === "function"){
        if (tb)      ph.cctv("tab", tb.getAttribute("data-tab"));
        else if (cm) ph.cctv("cam", cm.getAttribute("data-cam"));
        else         ph.cctv("act", ac.getAttribute("data-act"));
      }
    }
  }
  pDown = down;
}

/* ---------------- entrada desde Lua ---------------- */
function render(){
  document.body.setAttribute("data-layout", LAYOUT);
  var t = TITLES[LAYOUT] || "";
  if (LAYOUT === "map" && D && D.map && D.map.name) t = D.map.name;
  document.getElementById("title").textContent = t;

  if (LAYOUT === "sanity") drawSanity();
  else if (LAYOUT === "activity") drawActivity();
  else if (LAYOUT === "sound") drawSound();
  else if (LAYOUT === "map") drawMap();
  else if (LAYOUT === "cctv") drawCctv();
}

/* Zoom de la vista del mapa. 1 = entra el plano entero, que es lo que hace que
   una casa quede diminuta en un mapa con mucho descampado alrededor. */
var VZ = 1;

window.PH = {
  layout: function(name){ LAYOUT = String(name); render(); },
  pointer: pointer,
  mapview: function(z){
    z = Number(z);
    VZ = (z > 0) ? z : 1;
    if (LAYOUT === "map") render();
  },
  plan: function(j){
    try { PLAN = (typeof j === "string") ? JSON.parse(j) : j; } catch (e) { PLAN = null; }
    if (LAYOUT === "map") render();
  },
  set: function(j){
    try { D = (typeof j === "string") ? JSON.parse(j) : j; } catch (e) { return; }
    render();
  }
};

render();

/* EL AVISO DE ARRANQUE. Sin esto, Lua le habla al documento mientras CEF
   todavia lo esta parseando y sale `PH is not defined` — y peor: el layout
   queda en el que la pagina trae por defecto, asi que pedir otro monta la
   pantalla y muestra el equivocado, que se lee como "el comando no hace nada".
   Va al FINAL del script, cuando PH ya existe.

   Manda el user agent porque el CEF de Garry's Mod NO es el navegador de
   escritorio: hay CSS que anda en uno y no en el otro (`inset` costo una
   pasada), y adivinar la version es justo lo que hay que dejar de hacer. */
if (window.ph && typeof ph.ready === "function") ph.ready(navigator.userAgent);
</script></body></html>
]==]

--[[-------------------------------------------------------------------------
    UNA PANTALLA POR LAYOUT

    Cada layout tiene su propio panel DHTML, su RenderTarget y su material: en
    el juego los cuatro monitores estan colgados a la vez, asi que compartir uno
    solo obligaria a que todos los props mostraran lo mismo.

    El panel queda fuera de la pantalla y con SetPaintedManually(true): sigue
    actualizando su textura pero no se dibuja encima del HUD.

    GetHTMLMaterial() devuelve nil hasta que el panel pinto al menos una vez.
    Eso NO es un error, es el arranque; por eso se consulta cada vez en vez de
    guardarlo.
---------------------------------------------------------------------------]]
--[[
    CUAN CERCA SE VE EL PLANO.

    La caja de normalizacion es GLOBAL y eso no se toca: es lo que mantiene los
    pisos registrados entre si. Pero en un mapa con mucho exterior esa caja la
    llena el descampado y la casa queda del tamano de una estampilla. El zoom es
    de PRESENTACION y por eso vive en el cliente y no viaja por red: no cambia
    ningun dato del plano, solo cuanto se agranda al dibujarlo.
]]
local cvMapZoom = CreateClientConVar( "phantasmagoria_trucktv_mapzoom", "1", true, false,
    "Cuan cerca se ve el plano del sitio: 1 entra todo el mapa, 3 se acerca al edificio" )

local screens = {}

--[[
    Un literal de string de JavaScript, escapado.

    `util.TableToJSON` NO sirve para esto y fue el error que mato el primer
    arranque en juego: espera una TABLA, y con un string tira
    *bad argument #1 (table expected, got string)*. Es un error de TIPO en
    tiempo de ejecucion, asi que el chequeo de sintaxis lo pasa entero y releer
    el archivo no lo encuentra — ya le habia dado el visto bueno dos veces.

    Ahora hay un solo lugar donde se arma un string para meter en JS, y no
    admite el error: todo lo que no sea texto se convierte con tostring antes.
]]
local function jsStr( s )
    return '"' .. string.gsub( tostring( s ), '[%c"\\]', function( c )
        return string.format( "\\u%04X", string.byte( c ) )
    end ) .. '"'
end

--[[
    TODO el JavaScript pasa por aca, y se ENCOLA hasta que la pagina avise.

    `SetHTML` no es sincronico: CEF sigue parseando cuando la llamada vuelve, y
    el `RunJavascript` que venia justo despues corria contra un documento donde
    `PH` todavia no existia. Sintoma en juego:

        [HTML] Uncaught ReferenceError: PH is not defined

    y —lo peor— el layout quedaba en el que la pagina trae por defecto, asi que
    pedir `activity` o `sound` montaba la pantalla y mostraba `sanity`: se veia
    como "el comando no cambia nada" y no como un error de arranque.

    La pagina llama `ph.ready(userAgent)` al final de su script. Recien ahi se
    vacia la cola. Y manda el user agent porque **el CEF de Garry's Mod no es el
    Chrome de esta maquina**: hay CSS que anda en el navegador de escritorio y
    no ahi, y adivinar la version es justo lo que hizo perder la primera pasada.
]]
local function runJS( s, js )
    if s.ready then
        s.pnl:RunJavascript( js )
    else
        s.cola[ #s.cola + 1 ] = js
    end
end

local function ensureScreen( layout )
    local s = screens[ layout ]
    if s and IsValid( s.pnl ) then return s end

    local rtName = "phantasmagoria_trucktv_" .. layout

    local pnl = vgui.Create( "DHTML" )
    pnl:SetSize( W, H )
    pnl:SetPos( -W - 64, -H - 64 )     -- fuera de pantalla
    pnl:SetPaintedManually( true )
    pnl:SetMouseInputEnabled( false )
    pnl:SetKeyboardInputEnabled( false )

    s = { pnl = pnl, name = rtName, ready = false, cola = {} }
    screens[ layout ] = s

    -- Las funciones se publican ANTES de SetHTML: si se registraran despues, la
    -- pagina podria llamar `ph.ready` antes de que exista y el arranque quedaria
    -- colgado esperando un aviso que ya paso.
    --
    -- Es lo unico que la pagina puede llamar, a proposito: una pagina que puede
    -- llamar cualquier cosa es una pagina que puede romper cualquier cosa.
    pnl:AddFunction( "ph", "ready", function( ua )
        s.ready = true
        if not PHANTASMAGORIA.TruckTVUserAgent then
            PHANTASMAGORIA.TruckTVUserAgent = tostring( ua )
            MsgC( Color( 160, 190, 200 ), "[Phantasmagoria] navegador de la pantalla: " ..
                tostring( ua ) .. "\n" )
        end
        for _, js in ipairs( s.cola ) do pnl:RunJavascript( js ) end
        s.cola = {}
    end )

    -- Se indirecciona por PHANTASMAGORIA para no depender del orden de
    -- definicion: el que resuelve el cambio de piso se escribe mas abajo.
    pnl:AddFunction( "ph", "floor", function( delta )
        if PHANTASMAGORIA.TruckTVFloorDelta then
            PHANTASMAGORIA.TruckTVFloorDelta( layout, tonumber( delta ) or 0 )
        end
    end )

    --[[
        Los clicks de la pantalla del CCTV. Llegan como (que, valor):

            ("tab", "cctv"|"video"|"head")   la pestana
            ("cam", "0".."3")                una celda de la lista
            ("act", "rec"|"nv"|"pan-"|"pan+"|"zoom-"|"zoom+"|"page-"|"page+")

        Se avisa y NO se resuelve nada aca: que camara se ve o si esta grabando
        es estado del mod. Hoy no hay nada que lo lleve, asi que el gancho queda
        publicado y sin enganchar — que es lo mismo que hace `ph.floor` cuando
        no hay plano.

        El aviso sale UNA sola vez por sesion, no en cada click y no detras de
        un convar: sin ningun aviso, "el click no hace nada" no se distingue de
        "el click no llego", que son dos problemas en dos archivos distintos; y
        con aviso en cada click, apretar REC cinco veces llena la consola.
    ]]
    --[[
        El rectangulo del visor, en pixeles de la pagina. Lo MIDE el navegador
        con getBoundingClientRect y lo manda; no se deriva de los paddings del
        CSS en Lua. Una derivacion asi sale mal sin quejarse: el feed
        apareceria corrido unos pixeles y se leeria como un problema de la
        camara y no de la cuenta. Mismo motivo por el que el plano de la
        pantalla tactil se instrumento en vez de calcularse a ciegas.
    ]]
    pnl:AddFunction( "ph", "viewrect", function( x, y, w, h )
        s.view = { x = tonumber( x ) or 0, y = tonumber( y ) or 0,
                   w = tonumber( w ) or 0, h = tonumber( h ) or 0 }
    end )

    pnl:AddFunction( "ph", "cctv", function( que, valor )
        if PHANTASMAGORIA.TruckTVCctvInput then
            PHANTASMAGORIA.TruckTVCctvInput( layout, tostring( que ), tostring( valor ) )
            return
        end
        if not PHANTASMAGORIA.TruckTVCctvWarned then
            PHANTASMAGORIA.TruckTVCctvWarned = true
            MsgC( Color( 160, 190, 200 ), "[Phantasmagoria] CCTV: llego un click (" ..
                tostring( que ) .. " = " .. tostring( valor ) ..
                ") y no hay manejador. Define PHANTASMAGORIA.TruckTVCctvInput" ..
                "( layout, que, valor ) para atenderlo. No se vuelve a avisar.\n" )
        end
    end )

    pnl:SetHTML( PAGE )
    runJS( s, "PH.layout(" .. jsStr( layout ) .. ")" )
    runJS( s, string.format( "PH.mapview(%.3f)", math.max( cvMapZoom:GetFloat(), 0.05 ) ) )

    local rt  = GetRenderTarget( rtName, W, H )
    local mat = CreateMaterial( rtName .. "_mat", "UnlitGeneric", {
        ["$basetexture"] = rtName,

        -- $model 1 NO es opcional. Un material creado sin el, aplicado a un
        -- MODELO con SetSubMaterial, no da error, no da textura de error y
        -- simplemente NO SE DIBUJA: queda un agujero por el que se ve lo de
        -- atras. Costo una corrida entera en los paramic.
        ["$model"]       = "1",

        -- UnlitGeneric: una pantalla encendida tiene que verse encendida en un
        -- sotano. Ademas es el mismo shader que el .vmt del estado apagado,
        -- asi que montar y desmontar no cambia el sombreado.
        ["$nolod"]       = "1",
    } )
    mat:SetTexture( "$basetexture", rt )

    s.rt, s.mat = rt, mat
    return s
end

--[[
    Algunos modelos quedan con la V invertida respecto de la textura y el
    contenido sale cabeza abajo. Aca esta MEDIDO que no deberia pasar
    (bl_screen_orient.py sobre el slot 1: "+v . arriba = +1.000", la textura no
    esta rotada), pero eso se midio en Blender y el que dibuja es Source.

    Este convar existe para que la primera corrida en juego pueda CORREGIRLO sin
    recompilar el modelo, y para que la correccion sea una medicion y no una
    prueba a ciegas: se corre `phantasmagoria_trucktv test`, se mira de que lado
    quedo la esquina marcada, y recien ahi se toca esto.
]]
cvars.AddChangeCallback( "phantasmagoria_trucktv_mapzoom", function( _, _, nuevo )
    local s = screens[ "map" ]
    if s then
        runJS( s, string.format( "PH.mapview(%.3f)", math.max( tonumber( nuevo ) or 1, 0.05 ) ) )
    end
end, "phantasmagoria_trucktv_mapzoom" )

local cvFlipV = CreateClientConVar( "phantasmagoria_trucktv_flipv", "0", true, false,
    "Invierte la V de la pantalla de la TV del camion si el contenido sale cabeza abajo" )

--[[-------------------------------------------------------------------------
    Redibuja el RenderTarget de un layout desde la textura de su panel HTML.

    TRES FALLAS DISTINGUIBLES, a proposito:
      - la pantalla se ve a traves (agujero) -> el MATERIAL no dibuja: falta
        $model 1, o el nombre del "!" no coincide.
      - MAGENTA liso                         -> el RT se limpia y se monta bien,
        pero la textura del HTML no llego (el panel todavia no pinto, o la
        pagina no cargo).
      - contenido pero congelado             -> se monta y no se vuelve a
        dibujar.
    El magenta se elige justamente porque no aparece en ningun lado de la
    pagina: si se ve magenta, la respuesta ya esta.
---------------------------------------------------------------------------]]
function PHANTASMAGORIA.DrawTruckTV( layout )
    local s = ensureScreen( layout )

    s.pnl:UpdateHTMLTexture()
    local hm = s.pnl:GetHTMLMaterial()

    render.PushRenderTarget( s.rt, 0, 0, W, H )
        cam.Start2D()
            render.Clear( 40, 0, 40, 255 )
            if hm then
                -- La textura de un DHTML se redondea a la potencia de dos
                -- siguiente y el contenido queda arriba a la izquierda. Las UV
                -- se calculan del tamano REAL del material, no de una
                -- constante: 1024x593 hoy da un material de 1024x1024, pero eso
                -- es una consecuencia, no una garantia.
                local u = W / math.max( hm:Width(),  1 )
                local v = H / math.max( hm:Height(), 1 )
                surface.SetMaterial( hm )
                surface.SetDrawColor( 255, 255, 255, 255 )
                if cvFlipV:GetBool() then
                    surface.DrawTexturedRectUV( 0, 0, W, H, 0, v, u, 0 )
                else
                    surface.DrawTexturedRectUV( 0, 0, W, H, 0, 0, u, v )
                end
            end

            -- EL FEED VA ENCIMA DE LA PAGINA, no adentro. Un DHTML no puede
            -- contener un RenderTarget de Source, pero este RT si puede
            -- contener a los dos: primero la pagina, despues la imagen de la
            -- camara en el rectangulo que la propia pagina midio, y al final
            -- el titulo y el timecode — que van sobre la imagen, asi que
            -- tienen que dibujarse despues o el feed los taparia.
            if layout == "cctv" and PHANTASMAGORIA.DrawCctvFeed then
                PHANTASMAGORIA.DrawCctvFeed( s.view )
            end
        cam.End2D()
    render.PopRenderTarget()
end

-- Manda los datos a un layout. Se llama aparte del dibujado: la pagina
-- redibuja sola cuando recibe, y mandar a 60 Hz seria tirar trabajo.
function PHANTASMAGORIA.PushTruckTVData( layout )
    local s = ensureScreen( layout )
    runJS( s, "PH.set(" .. util.TableToJSON( PHANTASMAGORIA.TruckData ) .. ")" )
end

--[[-------------------------------------------------------------------------
    EL PLANO DEL SITIO — VIVE EN OTRO ARCHIVO, Y EN OTRO REALM

    **La biblioteca `navmesh` de Garry's Mod es SOLO DE SERVIDOR.** Estaba
    llamada desde aca, que es cliente, y moria con *attempted to index nil with
    key 'IsLoaded'* en la primera llamada. La pantalla se dibuja en el cliente,
    asi que el plano NO se puede armar donde se dibuja.

    El algoritmo y el transporte se mudaron a
    `lua/autorun/phantasmagoria_trucktv_plan.lua`, que es compartido: el
    servidor arma y cachea, el cliente pide y recibe comprimido y en pedazos.

    Aca queda solo lo que es de la pantalla: pedir el piso y mandarlo al HTML.
---------------------------------------------------------------------------]]
function PHANTASMAGORIA.PushSitePlan( layout, areas, ar, motivo, muros )
    local s = ensureScreen( layout )
    local payload = areas and { areas = areas, ar = ar or 1, walls = muros or nil }
                          or { areas = {}, reason = motivo or "sin plano del sitio" }
    runJS( s, "PH.plan(" .. util.TableToJSON( payload ) .. ")" )
end

--[[-------------------------------------------------------------------------
    LA PANTALLA COMO SUPERFICIE TACTIL — el truco de Doom 3

    Se puede, y no hace falta nada exotico: alcanza con cruzar el rayo de la
    mirada contra el PLANO de la pantalla en el espacio del modelo, y mandarle
    a la pagina el pixel que sale.

    POR QUE CONTRA EL PLANO Y NO CONTRA EL TRACE. El `.phy` de este prop es un
    casco convexo: choca contra el marco, contra el canto y contra el vidrio por
    igual, y su punto de impacto esta a una profundidad que depende de por donde
    entro el rayo. Cruzar contra el plano de la pantalla da el punto exacto y
    ademas no depende de la colision, que puede cambiar sin que nadie lo note.

    EL RECTANGULO, Y POR QUE LOS EJES NO SON LOS DEL SMD

    La primera version tomo los numeros del SMD y los dio por buenos. El SMD
    dice, y `dev/phastools/smd_rect.py` lo confirma vertice por vertice con
    residuo 0:

        ancho  X de -24.2131 a +24.2131     alto  Z de -14.0825 a +13.9441
        plano  Y = -0.8159                  normal (0,-1,0): el frente es -Y

    **Y en juego ese espacio no existe.** studiomdl ROTA el modelo 90 grados en
    Z al compilar. Medido en la cabecera del .mdl que carga el motor
    (hull_min/hull_max, offsets 104 y 116), comparado contra el SMD x $scale:

        SMD  x 48.98  y  2.47  z 28.62   ->   MDL  x  2.97  y 49.48  z 29.12

    o sea `mdl.x = -smd.y` y `mdl.y = +smd.x`. No es cosa de este modelo: pasa
    igual en ouija_board (SMD 23.28/15.39 -> MDL 15.89/23.74) y en los otros dos
    que se midieron. En espacio de MODELO, que es el que devuelve WorldToLocal:

        ancho  Y de -24.2131 a +24.2131    (+Y es +u: la derecha del que mira)
        alto   Z de -14.0825 a +13.9441    (+Z es arriba)
        plano  X = +0.8159                 (+X es el frente)

    DE DONDE SALE CADA SIGNO, que es lo unico que una derivacion no puede dar:

      - el frente en +X lo fija la MEDICION en juego. El casco de colision tiene
        la cara delantera en x = 1.2371 y cinco sondas corridas sobre CUATRO
        entidades distintas dieron 1.268 las cinco veces — 0.03 afuera, que es
        el margen de colision. Una coordenada que no se mueve cuando el jugador
        apunta a otra parte es la normal, y no hay otra lectura de esos datos.
      - la +u hacia +Y sale de que el que mira la pantalla la mira desde +X, o
        sea con la vista hacia -X; con Z arriba, su derecha es +Y. Y se confirma
        sola: si fuera al reves la pagina se veria ESPEJADA, y en las capturas
        en juego el titulo se lee normal.

    QUE SINTOMA DABA EL ERROR, porque no se parecia a su causa: el rayo cruzaba
    el plano y = -0.8159, que en el modelo real no es la pantalla sino un plano
    que la corta de canto. El punto de cruce se movia en X y en Z a la vez, asi
    que el puntero recorria la pantalla EN DIAGONAL a 45 grados en lugar de
    seguir la mirada, y segun donde estuviera el prop el mismo rayo daba "atras"
    en un monitor y "fuera" en otro.

    `phantasmagoria_trucktv_probe` sigue existiendo para verificarlo: apuntar a
    las cuatro esquinas tiene que dar 0,0 / 1024,0 / 0,593 / 1024,593.
---------------------------------------------------------------------------]]
local SCREEN = {
    x  =   0.8159,                      -- el plano; el frente es el lado +X
    y0 = -24.2131, y1 = 24.2131,        -- ancho  -> u
    z0 = -14.0825, z1 = 13.9441,        -- alto   -> v
}

--[[
    Devuelve el pixel de la pagina donde esta apuntando `ply` sobre `ent`, o nil.

    nil tiene tres motivos distintos y el segundo argumento los separa: el rayo
    va para el otro lado, cruza el plano fuera del rectangulo, o el prop esta
    mas lejos que el alcance.
]]
function PHANTASMAGORIA.ScreenPointer( ent, ply, maxDist )
    if not IsValid( ent ) or not IsValid( ply ) then return nil, "sin entidad" end

    local eye = ply:EyePos()
    if eye:DistToSqr( ent:GetPos() ) > ( maxDist or 120 ) ^ 2 then return nil, "lejos" end

    -- a espacio de modelo: el punto va con WorldToLocal, la DIRECCION no (se
    -- restan dos puntos, si no se le suma el origen de la entidad)
    local o = ent:WorldToLocal( eye )
    local d = ent:WorldToLocal( eye + ply:GetAimVector() * 64 ) - o
    if math.abs( d.x ) < 1e-6 then return nil, "paralelo" end

    -- El ojo tiene que estar del lado de la CARA. Sin esto se puede "tocar" la
    -- pantalla parado detras del prop, que es un click que atraviesa el mueble.
    if o.x <= SCREEN.x then return nil, "atras" end

    local t = ( SCREEN.x - o.x ) / d.x
    if t <= 0 then return nil, "atras" end

    local hy = o.y + d.y * t
    local hz = o.z + d.z * t
    if hy < SCREEN.y0 or hy > SCREEN.y1 or hz < SCREEN.z0 or hz > SCREEN.z1 then
        return nil, "fuera"
    end

    local u = ( hy - SCREEN.y0 ) / ( SCREEN.y1 - SCREEN.y0 )
    local v = ( hz - SCREEN.z0 ) / ( SCREEN.z1 - SCREEN.z0 )
    -- La V crece hacia ARRIBA y la Y de la pagina hacia abajo. Y si el dibujado
    -- esta invirtiendo la V, el puntero tiene que invertirse con el: si no, el
    -- convar arregla la imagen y desincroniza el click, que es peor que las dos
    -- cosas mal juntas porque una de las dos se ve bien.
    if cvFlipV:GetBool() then return u * W, v * H end
    return u * W, ( 1 - v ) * H
end

-- El "!" le dice a Source que el nombre es el de un material que ya esta en
-- memoria y no una ruta de disco.
function PHANTASMAGORIA.AttachTruckTV( ent, layout )
    if not IsValid( ent ) then return false end
    if ent:GetModel() ~= MODEL then return false end
    local idx = findScreenSub( ent )
    if not idx then return false end
    local s = ensureScreen( layout )
    ent:SetSubMaterial( idx, "!" .. s.name .. "_mat" )
    return true, idx
end

-- SetSubMaterial con el indice y SIN segundo argumento limpia el override.
function PHANTASMAGORIA.DetachTruckTV( ent )
    local idx = findScreenSub( ent )
    if not idx then return false end
    ent:SetSubMaterial( idx )
    return true
end

--[[-------------------------------------------------------------------------
    EL PATRON DE PRUEBA

    No es decorativo. Separa DOS variables que en juego se confunden:
    "el modelo/las UV estan bien" y "el HTML se esta dibujando". Este patron lo
    dibuja Lua directo sobre el RT, sin tocar el panel HTML, asi que si sale
    derecho y completo, cualquier problema que quede es de la pagina.

    Que tiene que verse:
      - las cuatro esquinas rotuladas, cada una en su lugar
      - el texto DERECHO (si sale espejado o cabeza abajo: convar flipv)
      - el circulo REDONDO (si sale ovalado, la relacion del RT no es la de la
        pantalla)
      - la cuadricula sin estirar
---------------------------------------------------------------------------]]
surface.CreateFont( "PhTruckTest", { font = "Roboto", size = 34, weight = 700 } )

function PHANTASMAGORIA.DrawTruckTVTest( layout )
    local s = ensureScreen( layout )
    render.PushRenderTarget( s.rt, 0, 0, W, H )
        cam.Start2D()
            render.Clear( 8, 13, 15, 255 )
            surface.SetDrawColor( 34, 49, 52 )
            for x = 0, W, 64 do surface.DrawRect( x, 0, 1, H ) end
            for y = 0, H, 64 do surface.DrawRect( 0, y, W, 1 ) end

            -- circulo: si sale ovalado, el RT no tiene la relacion de la pantalla
            draw.NoTexture()
            surface.SetDrawColor( 232, 122, 46 )
            local cx, cy, r = W * 0.5, H * 0.5, H * 0.34
            local px, py
            for i = 0, 64 do
                local a = math.rad( i * 360 / 64 )
                local nx, ny = cx + math.cos( a ) * r, cy + math.sin( a ) * r
                if px then surface.DrawLine( px, py, nx, ny ) end
                px, py = nx, ny
            end

            draw.SimpleText( "ARRIBA IZQ", "PhTruckTest", 14, 10, Color( 242, 194, 48 ) )
            draw.SimpleText( "ARRIBA DER", "PhTruckTest", W - 14, 10, Color( 242, 194, 48 ), TEXT_ALIGN_RIGHT )
            draw.SimpleText( "ABAJO IZQ",  "PhTruckTest", 14, H - 44, Color( 208, 64, 47 ) )
            draw.SimpleText( "ABAJO DER",  "PhTruckTest", W - 14, H - 44, Color( 208, 64, 47 ), TEXT_ALIGN_RIGHT )
            draw.SimpleText( W .. " x " .. H .. "   " .. string.format( "%.4f : 1", W / H ),
                "PhTruckTest", cx, cy, Color( 255, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
        cam.End2D()
    render.PopRenderTarget()
end

--[[-------------------------------------------------------------------------
    DATOS DE DEMOSTRACION

    Se MUEVEN a proposito. Una pantalla congelada con numeros plausibles no se
    distingue de una que quedo con la textura vieja, y esa confusion ya costo
    una corrida en este addon.

    La cordura respeta la regla del juego: oscila +-2 % sobre su valor real, que
    es lo que la hace ver organica. Y hay un jugador MUERTO y uno CARGANDO
    porque esos dos estados tienen dibujo propio y si no, no se prueban nunca.

    El plano y los jugadores del mapa salen del NAVMESH DE VERDAD del mapa que
    este cargado: es el unico de los cuatro monitores que puede mostrar algo
    real hoy.
---------------------------------------------------------------------------]]
--[[-------------------------------------------------------------------------
    LA CINTA DE ACTIVIDAD

    El gráfico NO es una función que se recalcula cada cuadro: es una **cinta**.
    Cada muestra es un segundo, la 1 es AHORA, y al pasar un segundo todo se
    corre un lugar y la más vieja se cae por el borde de los 60. Un evento que
    pasó deja su meseta y esa meseta **viaja hacia la derecha** mientras
    envejece.

    Esto vive acá y no adentro de la demo a propósito: cuando la entidad empiece
    a alimentar datos de verdad va a tener que correr la cinta igual, y dos
    implementaciones de la misma cinta es la forma de que una ande y la otra no.
    El productor sólo dice "el nivel de ahora es N"; el corrimiento lo hace esto.

    Qué se veía sin esto: la demo tenía las ventanas escritas en posiciones
    FIJAS ({0,11}, {31,50}, {54,60}) y sólo le variaba el nivel a la primera. O
    sea que los primeros diez segundos subían y bajaban en el lugar y el resto
    del gráfico era un dibujo. Se lee como "el monitor anda" porque algo se
    mueve, y es justo lo que no tiene que hacer.
---------------------------------------------------------------------------]]
local MUESTRAS = 61                     -- 0..60 segundos, una por segundo
local histAct, histT = {}, nil
for i = 1, MUESTRAS do histAct[ i ] = 0 end

function PHANTASMAGORIA.PushActivitySample( nivel, ahora )
    ahora = ahora or RealTime()
    nivel = math.Clamp( math.floor( tonumber( nivel ) or 0 ), 0, 10 )
    if not histT then histT = ahora end

    local pasos = math.floor( ahora - histT )
    if pasos >= MUESTRAS then
        -- Estuvo parado más que la ventana entera: no tiene sentido correr 400
        -- veces para tirar todo igual, y peor sería dejar historia vieja
        -- pegada a un tiempo que ya no existe.
        for i = 1, MUESTRAS do histAct[ i ] = nivel end
        histT = ahora
        return histAct
    end

    for _ = 1, pasos do
        table.remove( histAct, MUESTRAS )
        table.insert( histAct, 1, nivel )
    end
    histT = histT + pasos
    -- La muestra de AHORA se sigue corrigiendo hasta que cumple su segundo: si
    -- no, un pico que empieza y termina dentro del mismo segundo no existiría.
    histAct[ 1 ] = math.max( histAct[ 1 ], nivel )
    return histAct
end

local demoPlan, demoPlanReason, demoFloor
local demoNivel, demoHasta = 0, 0

local function demoData()
    local d = PHANTASMAGORIA.TruckData
    local t = CurTime()
    local C = PHANTASMAGORIA.TRUCK_PLAYER_COLORS

    local base = { 69, 63, 67, 85 }
    local st   = { "ok", "ok", "dead", "loading" }
    d.sanity.damaged = false
    d.sanity.players = {}
    for i = 1, 4 do
        d.sanity.players[ i ] = {
            name  = "JUGADOR " .. i,
            -- +-2 %: la oscilacion que el juego mete a proposito
            pct   = math.Clamp( base[ i ] + math.sin( t * 0.9 + i ) * 2, 0, 100 ),
            color = C[ i ],
            state = st[ i ],
        }
    end

    -- 61 muestras enteras 0..10; la 1 es AHORA.
    --
    -- MESETAS, no ruido. El monitor no muestra una senal continua: cada
    -- interaccion deja un tramo HORIZONTAL de su nivel durante la ventana en
    -- que estuvo activa (la wiki: una interaccion EMF 3 de hace 30 s aparece
    -- como una linea de fuerza 2 entre los segundos 11 y 30). Una demo con
    -- ruido senoidal ensena a leer mal el grafico.
    -- MESETAS, no ruido. El monitor no muestra una senal continua: cada
    -- interaccion deja un tramo HORIZONTAL de su nivel durante la ventana en
    -- que estuvo activa. La demo elige un nivel y lo SOSTIENE unos segundos; el
    -- corrimiento en el tiempo lo hace PushActivitySample, que es el mismo
    -- codigo que va a usar la entidad de verdad.
    d.activity.damaged = false
    if t >= demoHasta then
        demoHasta = t + 3 + math.random() * 7
        demoNivel = ( math.random() < 0.4 ) and 0 or math.random( 1, 5 )
    end
    d.activity.strength = PHANTASMAGORIA.PushActivitySample( demoNivel, t )

    d.sound.sensors = {
        { room = "UTILITY",       pct = 7 + math.abs( math.sin( t * 1.7 ) ) * 22 },
        { room = "LIVING ROOM",   pct = math.abs( math.sin( t * 0.8 ) ) * 64 },
        { room = "BOYS BEDROOM",  pct = math.abs( math.sin( t * 2.3 + 1 ) ) * 15 },
    }

    -- MAPA. El plano NO se arma aca: `navmesh` es SOLO DE SERVIDOR, asi que
    -- viaja por red y llega cuando llega. Mientras no este, demoPlan es nil y
    -- la pantalla dice SIN SEÑAL con su motivo — que es el estado correcto y no
    -- un intermedio disfrazado de dato.
    d.map.name   = string.upper( game.GetMap() )
    d.map.floors = demoPlan and demoPlan.floors or 1
    d.map.floor  = demoFloor or ( demoPlan and demoPlan.ground ) or 1
    -- Como se numeran: la planta baja es donde estaba el jugador al armar el
    -- plano. Lo de arriba es 1, 2...; lo de abajo, -1, -2 (subsuelo).
    d.map.label  = demoPlan and ( d.map.floor - demoPlan.ground ) or 0
    d.map.players, d.map.motion, d.map.sound = {}, {}, {}
    if demoPlan then
        local n = 0
        for _, ply in ipairs( player.GetAll() ) do
            n = n + 1
            local x, y = PHANTASMAGORIA.WorldToPlan( demoPlan, ply:GetPos() )
            d.map.players[ n ] = {
                x = x, y = y,
                -- en pantalla la Y crece hacia abajo, asi que el angulo se
                -- invierte respecto del yaw del mundo
                ang = -ply:EyeAngles().y - 90,
                color = C[ ( ( n - 1 ) % 4 ) + 1 ],
                -- un jugador que esta en OTRO piso se dibuja apagado y no se
                -- oculta: que no aparezca no distingue "esta en el subsuelo" de
                -- "se desconecto", y son cosas muy distintas en una partida.
                otro = PHANTASMAGORIA.FloorOf( demoPlan, ply:GetPos().z ) ~= d.map.floor,
            }
        end
        -- un sensor de cada tipo, sobre el jugador local, para que las dos
        -- capas del plano tengan algo que dibujar
        local me = LocalPlayer()
        if IsValid( me ) then
            local x, y = PHANTASMAGORIA.WorldToPlan( demoPlan, me:GetPos() )
            d.map.motion[ 1 ] = { x = x, y = y, ang = 0, tripped = math.sin( t * 2 ) > 0.4 }
            d.map.sound[ 1 ]  = { x = x, y = y, r = 0.16 }
        end
    end
end

--[[-------------------------------------------------------------------------
    Prueba manual. Apuntar a una TV y correr:

        phantasmagoria_trucktv sanity      cordura del equipo, con datos demo
        phantasmagoria_trucktv activity    actividad total
        phantasmagoria_trucktv sound       sensores de sonido
        phantasmagoria_trucktv map         el plano del sitio (navmesh REAL)
        phantasmagoria_trucktv <layout> vacio    el mismo, SIN datos
        phantasmagoria_trucktv <layout> danado   el mismo, en Nightmare/Insanity
        phantasmagoria_trucktv test        el patron de prueba
        phantasmagoria_trucktv off         devuelve la TV que estas mirando
        phantasmagoria_trucktv off todas   devuelve todas

    Se pueden montar los cuatro layouts en cuatro props distintos a la vez.
---------------------------------------------------------------------------]]
local mounted = {}      -- { { ent = ent, layout = "sanity" }, ... }
local drawing = false

-- Cambiar de piso: lo llama la pagina cuando el jugador clickea una flecha.
function PHANTASMAGORIA.TruckTVFloorDelta( layout, delta )
    if not demoPlan then return end
    local n = demoPlan.floors
    local nuevo = math.Clamp( ( demoFloor or demoPlan.ground ) + delta, 1, n )
    if nuevo == demoFloor then return end        -- ya estaba en el extremo
    demoFloor = nuevo
    -- El piso se PIDE: el servidor manda uno por vez y el cliente cachea, asi
    -- que volver a uno ya visto no vuelve a la red.
    PHANTASMAGORIA.RequestSitePlan( demoFloor, function( areas, plan, motivo )
        if plan then demoPlan = plan end
        PHANTASMAGORIA.PushSitePlan( layout, areas, plan and plan.ar, motivo, plan and plan.muros )
        MsgC( Color( 200, 220, 200 ), string.format(
            "[Phantasmagoria] piso %d/%d  (nivel %+d, z=%.1f)\n",
            demoFloor, n, demoFloor - demoPlan.ground,
            demoPlan.zs and demoPlan.zs[ demoFloor ] or 0 ) )
    end )
end

--[[
    El puntero y el click.

    El click es el MOUSE 1, y mientras se este apuntando a una pantalla el mouse
    1 y el mouse 2 no llegan al mundo: si llegaran, probar la pantalla seria
    pegarle una trompada al prop o meterle un tiro, que es lo que pasaba. Doom 3
    usaba el disparo sin bloquear nada porque ahi no habia nada mas que hacer
    con el gatillo. La tecla E sigue sirviendo de alternativa.

    Se manda POR CUADRO y no por evento: la pagina tiene que dibujar el puntero
    aunque no se clickee, o no habria forma de distinguir "no le estoy pegando"
    de "el click no llega".
]]
local cvTouch = CreateClientConVar( "phantasmagoria_trucktv_touch", "1", true, false,
    "Permite apuntar y clickear las pantallas de la TV del camion" )
local cvReach = CreateClientConVar( "phantasmagoria_trucktv_reach", "120", true, false,
    "A cuantas unidades se puede tocar la pantalla" )
local cvBlock = CreateClientConVar( "phantasmagoria_trucktv_block", "1", true, false,
    "Que hacer con el mouse mirando una pantalla: 0 nada, 1 bloquear salvo con herramienta, 2 bloquear siempre" )

--[[-------------------------------------------------------------------------
    BLOQUEAR EL MOUSE MIENTRAS SE USA LA PANTALLA

    Se hace en `CreateMove`, que corre ANTES de que el comando se empaquete y se
    mande: lo que se le borre ahi no lo ve la prediccion NI el servidor, asi que
    con un solo hook de cliente alcanza y no hace falta netcode. (Un cliente
    modificado podria disparar igual; en un addon de sandbox eso no le importa a
    nadie.)

    DOS DECISIONES QUE NO SON OBVIAS.

    1. LEER LA TECLA ANTES DE BORRARLA. Si se borra primero, `ply:KeyDown(
       IN_ATTACK )` pasa a dar false y el click de la pantalla se va junto con el
       disparo — el bloqueo funcionaria y la pantalla quedaria muerta, con las
       dos cosas explicandose una a la otra.

    2. CON HERRAMIENTA EN LA MANO NO SE BLOQUEA (modo 1, el de fabrica). El
       physgun y el toolgun disparan con mouse 1, asi que bloquear siempre
       significa que una TV a menos de 120 unidades no se puede mover ni
       configurar mas. El modo 2 existe para quien prefiera lo contrario.
---------------------------------------------------------------------------]]
local HERRAMIENTAS = {
    weapon_physgun   = true,
    gmod_tool        = true,
    weapon_physcannon = true,
}

local apuntando = false             -- lo escribe pushPointer, lo lee CreateMove
local apuntandoT = 0
local clickAtaque = false

--[[
    `apuntando` CADUCA. pushPointer solo corre mientras haya pantallas
    dibujandose; si se desmontan, o el dibujado se corta por cualquier motivo, el
    ultimo valor queda congelado. Congelado en `true` significa un mouse
    bloqueado para siempre sin nada en pantalla que lo explique — el peor estado
    posible, porque no se parece a este archivo. Con la caducidad, cualquier
    camino que deje de medir apaga el bloqueo solo.
]]
local function bloqueaAhora( ply )
    if not apuntando or RealTime() - apuntandoT > 0.2 then return false end
    local modo = cvBlock:GetInt()
    if modo <= 0 then return false end
    if modo == 1 then
        local w = ply:GetActiveWeapon()
        if IsValid( w ) and HERRAMIENTAS[ w:GetClass() ] then return false end
    end
    return true
end

hook.Add( "CreateMove", "phantasmagoria_trucktv_click", function( cmd )
    local ply = LocalPlayer()
    if not IsValid( ply ) or not cvTouch:GetBool() then
        clickAtaque = false
        return
    end
    if not bloqueaAhora( ply ) then
        clickAtaque = false
        return
    end
    clickAtaque = cmd:KeyDown( IN_ATTACK )      -- leer PRIMERO (ver arriba)
    cmd:RemoveKey( IN_ATTACK )
    cmd:RemoveKey( IN_ATTACK2 )
end )

local function pushPointer()
    local ply = LocalPlayer()
    if not IsValid( ply ) then return end
    local down = cvTouch:GetBool()
        and ( clickAtaque or ply:KeyDown( IN_USE ) ) or false
    local reach = cvReach:GetFloat()

    -- Una pantalla por vez: la de la que el jugador esta mirando mas de cerca.
    -- Las demas reciben (-1,-1), que es lo que apaga el puntero — si no, cuatro
    -- monitores mostrarian cuatro cruces a la vez.
    --
    -- OJO, y es la misma trampa que el tint del LED del paramic1: el puntero
    -- vive en el PANEL, que es uno por LAYOUT y no por entidad. Dos props con
    -- el MISMO layout a la vista comparten la cruz. Para independizarlos haria
    -- falta un panel por entidad, que es un CEF por prop.
    local mejor, mejorD
    for _, m in ipairs( mounted ) do
        if IsValid( m.ent ) and m.layout ~= "__test__" then
            local px, py = PHANTASMAGORIA.ScreenPointer( m.ent, ply, reach )
            if px then
                local d = ply:EyePos():DistToSqr( m.ent:GetPos() )
                if not mejorD or d < mejorD then mejor, mejorD = { m, px, py }, d end
            end
        end
    end
    apuntando, apuntandoT = mejor ~= nil, RealTime()

    for _, m in ipairs( mounted ) do
        if m.layout ~= "__test__" then
            local s = screens[ m.layout ]
            if s and IsValid( s.pnl ) then
                if mejor and mejor[ 1 ] == m then
                    runJS( s, string.format( "PH.pointer(%.1f,%.1f,%s)",
                        mejor[ 2 ], mejor[ 3 ], down and "true" or "false" ) )
                elseif s.hadPointer then
                    runJS( s, "PH.pointer(-1,-1,false)" )
                end
            end
        end
    end
    for lay, s in pairs( screens ) do
        s.hadPointer = ( mejor ~= nil and mejor[ 1 ].layout == lay )
    end
end

local function stopIfEmpty()
    if #mounted == 0 and drawing then
        hook.Remove( "PreDrawOpaqueRenderables", "phantasmagoria_trucktv" )
        drawing = false
    end
end

local function detachAll()
    for _, m in ipairs( mounted ) do
        if IsValid( m.ent ) then PHANTASMAGORIA.DetachTruckTV( m.ent ) end
    end
    mounted = {}
    stopIfEmpty()
end

local function detachOne( ent )
    for i = #mounted, 1, -1 do
        if mounted[ i ].ent == ent then
            if IsValid( ent ) then PHANTASMAGORIA.DetachTruckTV( ent ) end
            table.remove( mounted, i )
        end
    end
    stopIfEmpty()
end

local nextPush = 0

local function startDrawing()
    if drawing then return end
    drawing = true
    hook.Add( "PreDrawOpaqueRenderables", "phantasmagoria_trucktv", function()
        for i = #mounted, 1, -1 do
            if not IsValid( mounted[ i ].ent ) then table.remove( mounted, i ) end
        end
        if #mounted == 0 then stopIfEmpty() return end

        -- que layouts hay realmente en pantalla: no se redibuja un RT que
        -- ningun prop esta mostrando
        local activos, modo = {}, nil
        for _, m in ipairs( mounted ) do activos[ m.layout ] = true; modo = m.mode or modo end

        if activos[ "__test__" ] then
            for _, m in ipairs( mounted ) do
                if m.layout == "__test__" then PHANTASMAGORIA.DrawTruckTVTest( m.rtLayout ) end
            end
        end

        -- La pagina se redibuja sola cuando recibe datos: 15 Hz alcanza y
        -- sobra para una pantalla, y mandar JSON a 60 Hz es trabajo tirado.
        if CurTime() >= nextPush then
            nextPush = CurTime() + 1 / 15
            local anyDemo = false
            for _, m in ipairs( mounted ) do if m.mode == "demo" then anyDemo = true end end
            if anyDemo then demoData() end
            for _, m in ipairs( mounted ) do
                if m.layout ~= "__test__" then PHANTASMAGORIA.PushTruckTVData( m.layout ) end
            end
        end

        -- El puntero va ANTES de dibujar: si se mandara despues, el cuadro que
        -- se ve corresponde a la posicion del cuadro anterior y el cursor
        -- arrastra un frame — que sobre una pantalla chica y de lejos se lee
        -- como "el click cae corrido".
        if cvTouch:GetBool() then pushPointer() end

        for lay in pairs( activos ) do
            if lay ~= "__test__" then PHANTASMAGORIA.DrawTruckTV( lay ) end
        end
    end )
end

concommand.Add( "phantasmagoria_trucktv", function( _, _, args )
    local ply = LocalPlayer()
    if not IsValid( ply ) then return end

    local a1 = string.lower( args[ 1 ] or "sanity" )
    local a2 = string.lower( args[ 2 ] or "demo" )

    -- `phantasmagoria_trucktv demo` era el comando de antes de que hubiera
    -- cuatro layouts, y es lo que la mano escribe sola. Un MODO en la primera
    -- posicion se corre a la segunda en vez de rebotar con "layout
    -- desconocido": el usuario dijo algo valido, lo que cambio es la forma.
    local MODOS = { demo = true, vacio = true, danado = true }
    if MODOS[ a1 ] then a1, a2 = "sanity", a1 end

    if a1 == "off" then
        if a2 == "todas" then
            detachAll()
            MsgC( Color( 120, 235, 120 ), "[Phantasmagoria] Todas devueltas a los materiales del modelo.\n" )
            return
        end
        local ent = ply:GetEyeTrace().Entity
        if not IsValid( ent ) then
            MsgC( Color( 255, 120, 120 ), "[Phantasmagoria] No estas mirando ninguna entidad. Usa 'off todas'.\n" )
            return
        end
        detachOne( ent )
        MsgC( Color( 120, 235, 120 ), "[Phantasmagoria] Devuelta a los materiales del modelo.\n" )
        return
    end

    local ent = ply:GetEyeTrace().Entity
    if not IsValid( ent ) then
        MsgC( Color( 255, 120, 120 ), "[Phantasmagoria] No estas mirando ninguna entidad.\n" )
        return
    end

    -- Imprimir CON QUE se esta midiendo, no solo el resultado: si el modelo no
    -- es el que se cree, un "listo" a secas no lo distingue de un exito.
    local mdl  = ent:GetModel() or "?"
    local mats = ent:GetMaterials() or {}
    local idx  = findScreenSub( ent )
    MsgC( Color( 235, 235, 235 ), "[Phantasmagoria] modelo = " .. mdl .. "\n" )
    for i, m in ipairs( mats ) do
        MsgC( Color( 200, 200, 200 ), string.format( "   SetSubMaterial(%d) -> %s%s\n",
            i - 1, m, ( i - 1 ) == idx and "   <-- la pantalla" or "" ) )
    end

    if mdl ~= MODEL then
        MsgC( Color( 255, 120, 120 ), "[Phantasmagoria] Esto no es la TV del camion (" .. MODEL .. ").\n" )
        return
    end
    if not idx then
        MsgC( Color( 255, 120, 120 ), "[Phantasmagoria] Ninguno de los " .. #mats ..
            " material(es) termina en '" .. SCREEN_SUFFIX .. "'.\n" )
        return
    end

    local layout, mode = a1, a2
    if a1 == "test" then
        layout, mode = LAYOUTS[ 1 ], "test"
    elseif not table.HasValue( LAYOUTS, a1 ) then
        MsgC( Color( 255, 120, 120 ), "[Phantasmagoria] Layout desconocido '" .. a1 ..
            "'. Hay: " .. table.concat( LAYOUTS, ", " ) .. ", test, off.\n" )
        return
    end

    detachOne( ent )
    if not PHANTASMAGORIA.AttachTruckTV( ent, layout ) then
        MsgC( Color( 255, 120, 120 ), "[Phantasmagoria] No pude montar el RT.\n" )
        return
    end

    if mode == "vacio" then
        PHANTASMAGORIA.TruckData = emptyData()
    elseif mode == "danado" then
        PHANTASMAGORIA.TruckData = emptyData()
        PHANTASMAGORIA.TruckData.sanity.damaged   = true
        PHANTASMAGORIA.TruckData.activity.damaged = true
    end

    mounted[ #mounted + 1 ] = {
        ent = ent, layout = ( mode == "test" ) and "__test__" or layout,
        rtLayout = layout, mode = mode,
    }
    startDrawing()

    -- El plano se manda UNA vez por layout. Y se imprime lo que salio del
    -- navmesh: cuantas areas, cuantos pisos y si se recorto algo. Un plano
    -- recortado en silencio se ve como un mapa mas chico, que es plausible.
    if layout == "map" then
        -- El plano viaja por red y NO llega en esta misma llamada: hasta que
        -- llegue, la pantalla dice SIN SEÑAL. Que el comando no imprima el
        -- resultado del navmesh de inmediato es correcto — imprimirlo antes de
        -- tenerlo seria imprimir lo que se espera y no lo que paso.
        demoFloor = nil
        PHANTASMAGORIA.RequestSitePlan( 0, function( areas, plan, motivo )
            demoPlan, demoPlanReason = plan, motivo or false
            demoFloor = plan and plan.ground or nil
            PHANTASMAGORIA.PushSitePlan( layout, areas, plan and plan.ar, motivo, plan and plan.muros )
            if plan then
                -- piso por piso y no un total: la separacion es una heuristica
                -- sobre alturas, y un mapa de un nivel partido en cuatro se ve
                -- raro pero plausible. Sin el volcado no hay como notarlo.
                MsgC( Color( 200, 220, 200 ), string.format(
                    "   navmesh (del SERVIDOR): %d piso(s), relacion %.3f : 1, planta baja = piso %d%s\n",
                    plan.floors, plan.ar, plan.ground,
                    plan.recortadas > 0 and ( "  !! " .. plan.recortadas .. " areas RECORTADAS" ) or "" ) )
                for k = 1, plan.floors do
                    MsgC( Color( 180, 200, 180 ), string.format(
                        "      piso %d  z=%8.1f   nivel %+d%s\n",
                        k, plan.zs[ k ], k - plan.ground,
                        k == plan.floor and ( "   <- dibujado, " .. #areas .. " areas" ) or "" ) )
                end
                -- LAS PAREDES SE INFORMAN SIEMPRE, incluso cuando salen bien.
                -- "0 % solido" y "no llegaron las paredes" se ven IGUAL en
                -- pantalla — las dos dan un plano sin cortes — y se arreglan
                -- distinto: una es el mapa, la otra es el transporte.
                local mu = plan.muros
                if mu then
                    MsgC( mu.pct > 0 and Color( 180, 200, 180 ) or Color( 255, 180, 120 ),
                        string.format( "      paredes: grilla %dx%d, %.1f%% solido, %s, %.1f ms%s\n",
                            mu.w, mu.h, mu.pct, mu.modo, mu.ms,
                            mu.pct == 0 and "   !! ninguna: probar phantasmagoria_trucktv_walltrace 1" or "" ) )
                else
                    MsgC( Color( 255, 180, 120 ), "      paredes: NO llegaron\n" )
                end
            else
                MsgC( Color( 255, 180, 120 ), "   navmesh: " .. tostring( motivo ) .. "\n" )
            end
        end )
    end

    MsgC( Color( 120, 235, 120 ), "[Phantasmagoria] Montado en el submaterial " .. idx ..
        " (layout '" .. layout .. "', modo '" .. mode .. "', " .. W .. "x" .. H .. ", " ..
        string.format( "%.4f", W / H ) .. " : 1).\n" )
    MsgC( Color( 200, 200, 200 ),
        "   magenta liso = el RT anda y el HTML no llego | agujero = el material no dibuja\n" ..
        "   'phantasmagoria_trucktv off' para sacarlo de esta, 'off todas' para todas.\n" )
end, function( cmd, argStr )
    local out = {}
    for _, l in ipairs( LAYOUTS ) do out[ #out + 1 ] = cmd .. " " .. l end
    out[ #out + 1 ] = cmd .. " test"
    out[ #out + 1 ] = cmd .. " off"
    out[ #out + 1 ] = cmd .. " off todas"
    return out
end, "Monta uno de los cuatro monitores del camion en la TV que estas mirando (sanity|activity|sound|map [demo|vacio|danado] | test | off [todas])" )

--[[-------------------------------------------------------------------------
    CALIBRAR EL RECTANGULO DE LA PANTALLA

        phantasmagoria_trucktv_probe

    Apuntar a una esquina de la pantalla y correrlo. Imprime el punto en
    espacio de MODELO y el pixel de la pagina que sale de el.

    Existe porque los numeros de SCREEN salieron de un SMD cuyos ejes NO son los
    del modelo compilado, y eso ya paso una vez: studiomdl rota 90 grados en Z y
    el rectangulo quedo cruzando el plano equivocado. El sintoma no se parecia a
    la causa (el puntero iba en diagonal), asi que el comando ahora no imprime
    solo el pixel: imprime tambien el CONTROL de que el modelo sigue siendo el
    que se midio.

    Las cuatro esquinas tienen que dar, en pixeles, cerca de:
        arriba-izq   0, 0        arriba-der   1024, 0
        abajo-izq    0, 593      abajo-der    1024, 593
---------------------------------------------------------------------------]]
-- Cara delantera del casco de colision, medida en trucktv_phys.smd x $scale.
-- El trace tiene que pegar aca, no en el plano de la pantalla: el casco sale
-- 0.42 unidades por delante del vidrio. Si esto deja de coincidir, el modelo
-- que esta cargado no es el que se midio y TODO lo demas de este bloque miente.
local HULL_FRONT = 1.2371

concommand.Add( "phantasmagoria_trucktv_probe", function()
    local ply = LocalPlayer()
    if not IsValid( ply ) then return end
    local ent = ply:GetEyeTrace().Entity
    if not IsValid( ent ) then
        MsgC( Color( 255, 120, 120 ), "[Phantasmagoria] No estas mirando ninguna entidad.\n" )
        return
    end

    MsgC( Color( 235, 235, 235 ), "[Phantasmagoria] modelo = " .. ( ent:GetModel() or "?" ) .. "\n" )
    MsgC( Color( 200, 200, 200 ), string.format(
        "   rectangulo medido: plano X=%.4f   ancho Y %.4f..%.4f   alto Z %.4f..%.4f\n",
        SCREEN.x, SCREEN.y0, SCREEN.y1, SCREEN.z0, SCREEN.z1 ) )

    -- El impacto del trace choca contra el CASCO y no contra el plano, y por eso
    -- mismo sirve de control: su X tiene que ser la cara del casco.
    local lp = ent:WorldToLocal( ply:GetEyeTrace().HitPos )
    local dif = math.abs( lp.x - HULL_FRONT )
    MsgC( Color( 200, 200, 200 ), string.format(
        "   impacto del trace, en espacio de modelo: (%.3f, %.3f, %.3f)\n", lp.x, lp.y, lp.z ) )
    if dif <= 0.15 then
        MsgC( Color( 120, 235, 120 ), string.format(
            "   control OK: la X del impacto (%.3f) es la cara del casco (%.4f)\n",
            lp.x, HULL_FRONT ) )
    else
        MsgC( Color( 255, 120, 120 ), string.format(
            "   CONTROL FALLA: la X del impacto (%.3f) no es la cara del casco (%.4f, difiere %.3f).\n" ..
            "   O estas pegandole al canto o a la trasera, o el .mdl cargado no es el que se midio.\n",
            lp.x, HULL_FRONT, dif ) )
    end

    -- ScreenPointer devuelve (px, py) o (nil, motivo): cuando el primero es nil,
    -- el segundo YA es el motivo. Un solo lugar donde leerlo.
    local px, py = PHANTASMAGORIA.ScreenPointer( ent, ply, cvReach:GetFloat() )
    if px then
        MsgC( Color( 120, 235, 120 ), string.format(
            "   pixel de la pagina: %.1f, %.1f   (de %d x %d)\n", px, py, W, H ) )
    else
        MsgC( Color( 255, 180, 120 ), "   sin pixel: " .. tostring( py ) .. "\n" )
    end
end, nil, "Imprime a que pixel de la pantalla de la TV del camion estas apuntando" )

--[[-------------------------------------------------------------------------
    EL MISMO CALCULO, PERO EN VIVO

        phantasmagoria_trucktv_touchdebug [0|1]

    Un comando que imprime una vez contesta "donde pegue este disparo". No
    contesta "el puntero SIGUE a la mirada", que es la pregunta que quedo
    abierta cuando el puntero se movia en diagonal: con una sola muestra, un
    puntero que va a 45 grados y uno que va bien son dos numeros igual de
    plausibles. Hacen falta muchas muestras seguidas mientras se mueve el mouse,
    y eso es un HUD, no un print.

    Muestra los tres eslabones por separado — que entidad, donde cruza el rayo,
    que pixel sale — mas el estado del bloqueo del mouse. Si el puntero anda mal,
    esto dice CUAL de los tres se rompio en vez de dejarlo a la deduccion.
---------------------------------------------------------------------------]]
local function fmtNum( x ) return string.format( "%8.3f", x ) end

concommand.Add( "phantasmagoria_trucktv_touchdebug", function( _, _, args )
    local on = args[ 1 ] ~= "0"
    if not on then
        hook.Remove( "HUDPaint", "phantasmagoria_trucktv_dbg" )
        MsgC( Color( 200, 200, 200 ), "[Phantasmagoria] debug tactil apagado.\n" )
        return
    end

    hook.Add( "HUDPaint", "phantasmagoria_trucktv_dbg", function()
        local ply = LocalPlayer()
        if not IsValid( ply ) then return end

        local tr  = ply:GetEyeTrace()
        local ent = tr.Entity
        local L = {}
        L[ #L + 1 ] = { "entidad", IsValid( ent ) and tostring( ent ) or "ninguna" }
        L[ #L + 1 ] = { "modelo",  IsValid( ent ) and ( ent:GetModel() or "?" ) or "-" }

        if IsValid( ent ) and ent:GetModel() == MODEL then
            local lp = ent:WorldToLocal( tr.HitPos )
            L[ #L + 1 ] = { "impacto (modelo)", fmtNum( lp.x ) .. fmtNum( lp.y ) .. fmtNum( lp.z ) }
            L[ #L + 1 ] = { "cara del casco",
                string.format( "%.4f  %s", HULL_FRONT,
                    math.abs( lp.x - HULL_FRONT ) <= 0.15 and "OK" or "NO COINCIDE" ) }

            local o = ent:WorldToLocal( ply:EyePos() )
            L[ #L + 1 ] = { "ojo (modelo)", fmtNum( o.x ) .. fmtNum( o.y ) .. fmtNum( o.z ) }
            L[ #L + 1 ] = { "dist al prop",
                string.format( "%.1f  (alcance %.0f)",
                    ply:EyePos():Distance( ent:GetPos() ), cvReach:GetFloat() ) }

            local px, py = PHANTASMAGORIA.ScreenPointer( ent, ply, cvReach:GetFloat() )
            L[ #L + 1 ] = { "pixel", px and string.format( "%.1f , %.1f", px, py )
                                        or ( "SIN PIXEL: " .. tostring( py ) ) }
        end

        local w = IsValid( ply:GetActiveWeapon() ) and ply:GetActiveWeapon():GetClass() or "ninguna"
        L[ #L + 1 ] = { "arma", w }
        L[ #L + 1 ] = { "apuntando", tostring( apuntando ) ..
            ( RealTime() - apuntandoT > 0.2 and "  (CADUCADO)" or "" ) }
        L[ #L + 1 ] = { "bloqueo", string.format( "modo %d -> %s",
            cvBlock:GetInt(), bloqueaAhora( ply ) and "COMIENDO mouse1/mouse2" or "libre" ) }
        L[ #L + 1 ] = { "click", tostring( clickAtaque ) }

        surface.SetDrawColor( 0, 0, 0, 190 )
        surface.DrawRect( 12, 120, 470, 22 * #L + 16 )
        for i, par in ipairs( L ) do
            local y = 128 + ( i - 1 ) * 22
            draw.SimpleText( par[ 1 ], "DermaDefault", 22, y, Color( 150, 180, 185 ) )
            draw.SimpleText( par[ 2 ], "DermaDefault", 175, y, Color( 255, 255, 255 ) )
        end
    end )
    MsgC( Color( 120, 235, 120 ), "[Phantasmagoria] debug tactil encendido " ..
        "(apagar con: phantasmagoria_trucktv_touchdebug 0)\n" )
end, nil, "Muestra en vivo el calculo del puntero de la pantalla y el estado del bloqueo del mouse" )
