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
-- ⚠ Y el de la OldCrone es una DECISION, no una medicion derivada: su ragdoll
-- da 9.64x el volumen del ciudadano porque el casco convexo de su habito
-- encierra aire de los tobillos al pecho, asi que la densidad de Valve daria
-- 867 kg. Se le puso $mass 50 a mano y el archivo quedo en 54.02.
PHANTASMAGORIA.GhostModels = {
	{
		mdl     = "models/phantasmagoria/ghost_girl.mdl",
		nombre  = "Ghost_Girl_1",
		etiqueta = "la nena",
		altura  = 44.94,
		nuestro = { 6.70, 6.09, 9.72, 9.61, 3.47 },
		masa    = 36.58,
	},
	{
		mdl     = "models/phantasmagoria/ghost_male.mdl",
		nombre  = "Ghost_Male",
		etiqueta = "el hombre adulto",
		altura  = 72.29,
		nuestro = { 9.43, 11.15, 20.45, 18.31, 2.18 },
		masa    = 58.04,
	},
	{
		mdl     = "models/phantasmagoria/ghost_oldcrone.mdl",
		nombre  = "Ghost_OldCrone",
		etiqueta = "la vieja",
		altura  = 68.98,
		nuestro = { 8.44, 10.58, 12.77, 18.18, 4.62 },
		masa    = 54.02,
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
