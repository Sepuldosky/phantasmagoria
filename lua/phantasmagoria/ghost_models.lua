--[[-------------------------------------------------------------------------
    Phantasmagoria - LOS MODELOS DE FANTASMA PORTADOS, Y SUS LARGOS DE HUESO

    UNA sola tabla para los tres consumidores que hasta el 2026-08-10 tenian
    "ghost_girl" y el numero 9.72 escritos a mano:

        lua/entities/terminator_nextbot_phantom/server.lua   ( la lista del bot )
        lua/autorun/server/phantasmagoria_ghostmodel.lua     ( ph_ghost_* )
        lua/autorun/client/phantasmagoria_ghostbones.lua     ( ph_bones/land/facing )

    ⚠ POR QUE ESTO NO ES UN DETALLE DE ORDEN. Los tres instrumentos buscaban su
    sujeto con `string.find( mdl, "ghost_girl" )`. Con el Ghost_Male o la
    OldCrone spawneados contestaban «NO HAY NINGUNA ENTIDAD con 'ghost_girl'» --
    o sea SIN CORRER-- sobre un fantasma que estaba ahi adelante. Y el 9.72 es
    el muslo DE LA NENA: sobre el Male ( 20.45 ) la fila habria dado rojo sobre
    un modelo sano.

    ---------------------------------------------------------------------------
    DE DONDE SALEN LOS NUMEROS
    ---------------------------------------------------------------------------
    De la tabla de huesos del `.mdl` COMPILADO, leida con
    `dev/phastools/mdl2smd.py read_bones` sobre la copia MONTADA ( la que abre
    el motor, no la que escupe studiomdl ). La distancia de un hueso a su padre
    es el LARGO del hueso y no depende de la pose, asi que sirve para decidir si
    el modelo esta usando SU esqueleto o el prestado de `m_anm.mdl`.

    `prestado` es el mismo para los tres: es m_anm, o sea el ciudadano de HL2.

    ⚠ Y ESO ES LO UNICO QUE ACREDITA. `ph_bones` NO despeja una deformacion:
    daria los mismos numeros con el fantasma doblado en dos. Costo casi una
    ronda leerlo al reves ( §20.1 del handoff ).

    ---------------------------------------------------------------------------
    ⚠ NO TODOS LOS PARES PUEDEN FALLAR, Y HAY QUE CONTAR LOS QUE SI
    ---------------------------------------------------------------------------
    El criterio original decia «son dos juegos de numeros bien separados, asi
    que no hay que interpretar». Es cierto EN LA NENA Y NO EN GENERAL. Medida la
    separacion |nuestro - prestado| / prestado sobre los tres modelos:

        par                      nena      Male      OldCrone
        L_UpperArm->L_Forearm     43 %      19 %      28 %
        L_Forearm->L_Hand         47 %    → 3 % ←     8 %  ←
        L_Thigh->L_Calf           46 %      15 %      28 %
        L_Calf->L_Foot            42 %      11 %      10 %
        Neck1->Head1            → 3 % ←     39 %      29 %

    O sea que CADA MODELO tiene un par que no discrimina, y en la nena es el
    cuello: 3.47 contra 3.59, doce centesimas de unidad. **El «5/5» del arco de
    la nena eran 4 pares utiles y uno que no podia fallar.**

    Por eso `MinimaSeparacion` y `ParesUtiles()`: el instrumento cuenta sobre
    los que discriminan y dice cuantos son. Un par por debajo del umbral se
    imprime igual, con su marca, porque su numero sigue siendo informacion --
    lo que no puede es sumar al veredicto. ( Catalogo de controles, entrada 25:
    *un valor de control que coincide con el esperado no distingue nada, y hay
    que contar los que si.* )
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}

-- Debajo de esta separacion relativa, un par NO puede distinguir nuestro
-- esqueleto del prestado y no suma al veredicto.
PHANTASMAGORIA.MinimaSeparacion = 0.10

-- Los cinco pares, en el orden en que los imprimen los instrumentos. El largo
-- que impone m_anm es propiedad del PAR y no del modelo.
PHANTASMAGORIA.ParesHueso = {
	{ "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", prestado = 11.69 },
	{ "ValveBiped.Bip01_L_Forearm",  "ValveBiped.Bip01_L_Hand",    prestado = 11.48 },
	{ "ValveBiped.Bip01_L_Thigh",    "ValveBiped.Bip01_L_Calf",    prestado = 17.85 },
	{ "ValveBiped.Bip01_L_Calf",     "ValveBiped.Bip01_L_Foot",    prestado = 16.53 },
	{ "ValveBiped.Bip01_Neck1",      "ValveBiped.Bip01_Head1",     prestado =  3.59 },
}

-- ⚠ El orden de `nuestro` es el de ParesHueso y no se puede reordenar uno sin
-- el otro. Los cinco numeros de cada fila salieron de su .mdl montado el
-- 2026-08-10; si un modelo se recompila con otra geometria hay que volver a
-- medirlos ( dev/phastools: mdl2smd.read_bones ).
--
-- `masa` es la SUMA DE LOS SOLIDOS que quedo en el .phy, no el `$mass` del .qci,
-- y no son lo mismo: studiomdl reparte por volumen pero no baja de 1 kg por
-- solido, asi que en un modelo chico la masa del archivo es MAYOR que la
-- pedida ( la nena pide 30.73 y el archivo tiene 36.58; el Male pide 56.17 y
-- tiene 58.04 ). El numero que se compara en juego es el del archivo.
-- `volumen` es la suma de los solidos del MISMO .phy. Va al lado de la masa
-- porque es lo que SEPARA las causas cuando la masa no da: el motor no
-- recalcula la masa pero el volumen sale del archivo, asi que un volumen que no
-- es el nuestro dice que el motor esta sirviendo OTRA colision. Estaba clavado
-- en 2278.19 --el de la nena-- adentro del instrumento, o sea que sobre el Male
-- y la OldCrone la linea de diagnostico mentia por un factor de 2 y de 28.
-- ⚠ Y el de la OldCrone es una DECISION, no una medicion derivada: su ragdoll
-- da 9.64x el volumen del ciudadano porque el casco convexo de su habito
-- encierra aire de los tobillos al pecho, asi que la densidad de Valve daria
-- 867 kg. Se le puso $mass 50 a mano y el archivo quedo en 54.02.
-- ---------------------------------------------------------------------------
-- `reposoBrazo` y `reposoManos`: LA POSE DE REPOSO DE CADA UNO
-- ---------------------------------------------------------------------------
-- `reposoBrazo` es el angulo del brazo izquierdo ( hombro -> mano ) contra la
-- VERTICAL y `reposoManos` la separacion entre las dos manos, las dos en el
-- primer cuadro del `_ref.smd`, que es la pose que studiomdl usa de reposo.
-- Salen de `dev/phastools/ghostbrazo_off.py`, que compone la cadena de huesos
-- del SMD igual que el motor.
--
-- ⚠ POR QUE ESTAN ACA Y NO EN EL INSTRUMENTO. `ph_ghost_facing` los tenia
-- clavados como `REPOSO_BRAZO, REPOSO_MANOS = 46.5, 25.23` -- los de la NENA --
-- y los imprimia para cualquier modelo. Uno de los dos no es decorativo: la
-- linea `⭐ EL CUERPO ESTA DIBUJADO EN LA POSE DE REPOSO` se dispara con
-- `manosMax > reposoManos * 0.9`, y el Male tiene las manos a 43,49 u en su
-- PROPIO reposo. Con el umbral de la nena ( 22,7 ) esa alarma se prende sola
-- sobre un Male sano: *un control que fabrica el sintoma que busca*, y encima
-- sobre los dos modelos que estan por probarse por primera vez.
--
-- El 46,5 que estaba escrito es este mismo 46,53 redondeado; los tres numeros
-- se recalcularon de una sola corrida para que salgan del mismo camino.
--
--     modelo            brazo vs vertical   manos separadas
--     ghost_girl              46,53 gr           25,23 u
--     ghost_male              56,56 gr           43,49 u
--     ghost_oldcrone          53,85 gr           36,91 u
--
-- ⚠ Y NO SON UN VEREDICTO. Un reposo mas abierto no es un defecto: es como esta
-- autorado el asset. Sirven para que la comparacion sea contra el cuerpo que se
-- esta mirando.
-- ---------------------------------------------------------------------------
-- `voz`: EL SEXO DEL MODELO, QUE ES LO QUE LO ATA AL CATALOGO DE SONIDO
-- ---------------------------------------------------------------------------
-- 1 = femenina · 2 = grave. NO es un numero libre: es el INDICE DEL ARCHIVO en
-- sound/phantasmagoria/ghost/, donde el catalogo trae `voice_1_*` / `voice_2_*`,
-- `breathing_1_*` / `breathing_2_*` y `humming_1_*` / `humming_2_*`. O sea que
-- el 1 y el 2 no los elegimos: los trae el asset ( about.txt ).
--
-- ⚠ POR QUE VIVE ACA Y NO EN `MODEL_CANDIDATES`. El sexo es propio del MODELO,
-- igual que `altura`, `masa` y `reposoBrazo`, y este archivo es la unica casa de
-- eso. La lista del bot es OTRA cosa -- es que candidatos puede usar el NextBot,
-- y ahi entran modelos ajenos que no tienen ficha. Escribirlo alla seria la
-- segunda casa que la r6 acaba de borrar para `altura`, con otra ropa.
--
-- ⚠ Y NO MANDA SOBRE EL TIPO. La prioridad es tipo > modelo > sorteo: si el tipo
-- fija la voz -- Banshee y Dayan, que la fuente marca "Can only be female" --
-- manda el tipo. Este campo solo decide cuando el tipo no dice nada, que son 28
-- de los 30. Al reves, un Banshee con el cuerpo del Male hablaria con voz grave,
-- que es exactamente lo que la fuente prohibe.
--
--     ghost_girl      1   femenina
--     ghost_oldcrone  1   femenina
--     ghost_male      2   grave
--
-- ⚠ LA NENA Y LA VIEJA COMPARTEN BANCO, Y ES UNA DECISION DEL AUTOR ( 2026-08-17 ),
-- no un cabo suelto. El catalogo tiene DOS voces y no tres, asi que una nena de
-- 44,94 u y una anciana de 68,98 u suenan igual. Se pregunto y la respuesta fue
-- que asi es en Phasmophobia: la voz no se diferencia por edad -- el unico tipo
-- que envejece es Thaye y lo demuestra con sus ACCIONES. No se le inventa un
-- tercer banco al catalogo ni se le mete un pitch.
PHANTASMAGORIA.GhostModels = {
	{
		mdl     = "models/phantasmagoria/ghost_girl.mdl",
		voz     = 1,   -- femenina ( ver el bloque de arriba )
		nombre  = "Ghost_Girl_1",
		etiqueta = "la nena",
		altura  = 44.94,
		nuestro = { 6.70, 6.09, 9.72, 9.61, 3.47 },
		masa    = 36.58,
		volumen = 2278.19,
		reposoBrazo = 46.53,
		reposoManos = 25.23,
	},
	{
		mdl     = "models/phantasmagoria/ghost_male.mdl",
		voz     = 2,   -- grave ( ver el bloque de arriba )
		nombre  = "Ghost_Male",
		etiqueta = "el hombre adulto",
		altura  = 72.29,
		nuestro = { 9.43, 11.15, 20.45, 18.31, 2.18 },
		masa    = 58.04,
		volumen = 4170.73,
		reposoBrazo = 56.56,
		reposoManos = 43.49,
	},
	{
		mdl     = "models/phantasmagoria/ghost_oldcrone.mdl",
		voz     = 1,   -- femenina ( ver el bloque de arriba )
		nombre  = "Ghost_OldCrone",
		etiqueta = "la vieja",
		altura  = 68.98,
		nuestro = { 8.44, 10.58, 12.77, 18.18, 4.62 },
		masa    = 54.02,
		volumen = 64424.50,
		reposoBrazo = 53.85,
		reposoManos = 36.91,
	},
}

-- Indice por ruta, para que un consumidor no tenga que recorrer la lista.
PHANTASMAGORIA.GhostModelPorRuta = {}

for _, m in ipairs( PHANTASMAGORIA.GhostModels ) do
	PHANTASMAGORIA.GhostModelPorRuta[ m.mdl ] = m

end

--[[
	EsGhostModel( mdl ) -> ficha o nil

	El criterio de sujeto. ⚠ NO es `string.find( mdl, "ghost_girl" )`: eso
	quedaba mirando un banco vacio en cuanto el fantasma era otro. Y tampoco es
	la CLASE, que se rompe con los 30 tipos del diseno 12.2.

	Acepta las variantes de instrumento ( `_noinc`, `_seam` ) porque el A/B las
	necesita EN LA MISMA CORRIDA, y devuelve la ficha del modelo base para que
	los largos esperados sean los mismos -- que es justamente el punto del A/B.
]]
function PHANTASMAGORIA.EsGhostModel( mdl )
	if not isstring( mdl ) then return nil end

	local ficha = PHANTASMAGORIA.GhostModelPorRuta[ mdl ]
	if ficha then return ficha end

	-- variantes: models/phantasmagoria/ghost_girl_noinc.mdl -> ghost_girl
	for ruta, f in pairs( PHANTASMAGORIA.GhostModelPorRuta ) do
		local base = string.sub( ruta, 1, -5 )   -- sin ".mdl"

		if string.sub( mdl, 1, #base + 1 ) == base .. "_" then return f end

	end

	return nil

end

--[[
	VozDelModelo( mdl ) -> 1, 2 o nil

	El sexo del cuerpo, para el que decide la voz. Devuelve nil --y no un
	default-- en los TRES casos en que no hay dato: modelo ajeno ( sin ficha ),
	ficha sin `voz`, y `mdl` que no es una cadena. Los tres significan lo mismo
	para el consumidor: *este modelo no declara sexo*, y de ahi se cae al sorteo.

	⚠ NO SE DEVUELVE UN 1 POR DEFECTO, y no es una precaucion abstracta: un
	default plausible en el lugar de un dato faltante hace que un cadaver de HL2
	--o un modelo del taller al que se le olvido el campo-- hable siempre con voz
	de mujer, y eso se ve exactamente igual que un mecanismo andando. Con nil, el
	sorteo de siempre se hace cargo y el reporte puede decir POR QUE.

	Se valida el valor y no solo su presencia: un `voz = 3` --el error de tipeo
	natural el dia que alguien crea que hay un tercer banco-- indexaria `VOZ[3]`
	en server_events.lua, que no existe, y el sintoma seria un fantasma MUDO. El
	catalogo tiene dos ( sound/phantasmagoria/about.txt ) y esta guarda es donde
	ese hecho se hace cumplir.
]]
function PHANTASMAGORIA.VozDelModelo( mdl )
	local ficha = PHANTASMAGORIA.EsGhostModel( mdl )
	local voz   = ficha and ficha.voz

	if voz == 1 or voz == 2 then return voz end

	return nil

end

--[[
	ParesUtiles( ficha ) -> lista de indices que SI discriminan, y cuantos son.

	Se calcula, no se escribe: si manana se recompila un modelo y su antebrazo
	se acerca al del ciudadano, el par sale solo del veredicto en vez de seguir
	sumando un verde que no puede fallar.
]]
function PHANTASMAGORIA.ParesUtiles( ficha )
	local utiles, n = {}, 0

	for k, par in ipairs( PHANTASMAGORIA.ParesHueso ) do
		local nuestro = ficha and ficha.nuestro and ficha.nuestro[ k ]

		if nuestro then
			local sep = math.abs( nuestro - par.prestado ) / par.prestado

			if sep >= PHANTASMAGORIA.MinimaSeparacion then
				n = n + 1
				utiles[ k ] = sep

			end
		end
	end

	return utiles, n

end
