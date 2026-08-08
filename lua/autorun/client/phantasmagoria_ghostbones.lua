--[[
	Medir los huesos del fantasma DEL LADO DEL CLIENTE.

	    ph_ghost_bones      largos de hueso del ghost_girl que tengas spawneado

	POR QUE DE CLIENTE, Y NO EN ph_ghost_ragdoll / ph_ghost_anim

	El comando de servidor midio los mismos cinco pares y devolvio EXACTAMENTE
	los mismos numeros en el cuadro 0 y a los 0,5 s -- 11.69 y 11.69 -- mientras
	el ciclo avanzaba de 0 a 0,42. Una caminata mueve esos huesos; que no se
	movieran ni un milesimo no era "no se estira", era que el servidor NO estaba
	evaluando la animacion. Lo que leia era la tabla de huesos estatica, ya
	fusionada con la de m_anm.mdl por el $includemodel.

	Eso alcanzo para ENCONTRAR el problema (la tabla es la del ciudadano) y NO
	alcanza para ver si el arreglo funciono: la capa de proporciones es una
	animacion `autoplay`, y una animacion que el servidor no corre no se puede
	medir desde el servidor. `Entity:SetupBones` es de cliente por lo mismo.

	EL CRITERIO

	Los largos que declara el .mdl compilado son 6.70 / 6.09 / 9.72 / 9.61 /
	3.47. La tabla que impone m_anm es 11.69 / 11.48 / 17.85 / 16.53 / 3.59.
	Son dos juegos de numeros bien separados, asi que no hay que interpretar:
	el que salga dice cual gano.
]]

local MODELO = "models/phantasmagoria/ghost_girl.mdl"

-- {padre, hijo, largo que declara el .mdl, largo que impone m_anm}
local PARES = {
	{ "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", 6.70, 11.69 },
	{ "ValveBiped.Bip01_L_Forearm",  "ValveBiped.Bip01_L_Hand",    6.09, 11.48 },
	{ "ValveBiped.Bip01_L_Thigh",    "ValveBiped.Bip01_L_Calf",    9.72, 17.85 },
	{ "ValveBiped.Bip01_L_Calf",     "ValveBiped.Bip01_L_Foot",    9.61, 16.53 },
	{ "ValveBiped.Bip01_Neck1",      "ValveBiped.Bip01_Head1",     3.47,  3.59 },
}

local function cmd()
	-- Cualquier variante de ghost_girl, no un nombre exacto: el control sin
	-- $includemodel se llama ghost_girl_noinc.mdl y hay que medir los dos EN LA
	-- MISMA CORRIDA para que la comparacion valga.
	-- Y se filtran los `phys_bone_follower`: son los seguidores del ragdoll, no
	-- tienen nuestros huesos, y llenaban la consola con quince bloques de
	-- "hueso ausente" que tapaban la unica lectura que importaba.
	local encontrados = {}
	for _, e in ipairs( ents.GetAll() ) do
		local cls = IsValid( e ) and e:GetClass() or ""
		if ( cls == "prop_dynamic" or cls == "prop_ragdoll" or cls == "prop_physics" )
			and string.find( tostring( e:GetModel() ), "ghost_girl", 1, true ) then
			encontrados[ #encontrados + 1 ] = e
		end
	end
	if #encontrados == 0 then
		print( "[ph_bones] no hay ningun ghost_girl spawneado (prop_dynamic/ragdoll)." )
		print( "[ph_bones] correr antes ph_ghost_anim, ph_ghost_ragdoll o ph_ghost_control." )
		return
	end

	for _, e in ipairs( encontrados ) do
		if IsValid( e ) then
			print( "[ph_bones] modelo: " .. tostring( e:GetModel() ) )
			-- De cliente SI existe, y es lo que fuerza a que la pose este
			-- evaluada con todas sus capas -- incluida la de proporciones,
			-- que es `autoplay`.
			e:SetupBones()
			local seq = e:GetSequence()
			print( string.format( "[ph_bones] --- %s  [%s]  seq %d (%s)  ciclo %.3f ---",
				tostring( e ), e:GetClass(), seq,
				tostring( e:GetSequenceName( seq ) ), e:GetCycle() ) )

			local propio, ajeno = 0, 0
			for _, par in ipairs( PARES ) do
				local a, b = e:LookupBone( par[ 1 ] ), e:LookupBone( par[ 2 ] )
				if not a or not b then
					print( string.format( "[ph_bones]   %-24s hueso ausente",
						par[ 1 ]:sub( 17 ) .. "->" .. par[ 2 ]:sub( 17 ) ) )
				else
					local pa, pb = e:GetBonePosition( a ), e:GetBonePosition( b )
					local d = ( pa and pb ) and pa:Distance( pb ) or -1
					-- Cual de los dos candidatos esta mas cerca. No se
					-- interpreta un porcentaje: se dice a quien se parece.
					local dp, da = math.abs( d - par[ 3 ] ), math.abs( d - par[ 4 ] )
					local quien
					if dp < da then quien = "NUESTRO" propio = propio + 1
					else quien = "m_anm"  ajeno = ajeno + 1 end
					print( string.format(
						"[ph_bones]   %-24s %6.2f   (.mdl %5.2f / m_anm %5.2f)  -> %s",
						par[ 1 ]:sub( 17 ) .. "->" .. par[ 2 ]:sub( 17 ),
						d, par[ 3 ], par[ 4 ], quien ) )
				end
			end
			print( string.format( "[ph_bones]   VEREDICTO: %d/%d se parecen a NUESTRO esqueleto  %s",
				propio, #PARES,
				propio == #PARES and "-> la capa de proporciones ANDA"
				or ( ajeno == #PARES and "-> la capa NO entro: sigue el esqueleto de m_anm"
				     or "-> mezcla; hay que mirar hueso por hueso" ) ) )
		end
	end
end

concommand.Add( "ph_ghost_bones", cmd,
	nil, "Mide los largos de hueso del fantasma, del lado del CLIENTE." )

--------------------------------------------------------------- la costura

--[[
	ph_ghost_costura [secuencia]   -- por defecto walk_ours

	MIDE EL TAMBALEO, en vez de mirarlo. El sintoma que reporto el autor fue
	"la animacion se ve bien, pero en un punto tambalea hacia adelante": un
	tiron de UN cuadro cada 31, que es justo lo que un ojo puede no ver si no
	sabe cuando mirar -- y "no lo veo" no distingue *se arreglo* de *no lo
	estoy mirando bien*.

	QUE MIDE: barre el ciclo en 128 posiciones, y en cada una suma cuanto se
	movieron TODOS los huesos respecto de la posicion anterior. Una animacion
	sana da pasos parecidos entre si; un tiron es un paso enorme entre pasos
	chicos. El numero es paso MAXIMO / paso MEDIANO, y lo divide el comando:
	un criterio que exige dividir a mano invita a un veredicto inferido.

	La mediana y no el promedio, ni el maximo: el defecto mueve el maximo (es
	el tiron), asi que un umbral construido con el maximo se corre solo con el
	defecto adentro. Ya paso una vez en la herramienta de al lado.

	LOS DOS LADOS. Corre sobre los DOS modelos: el bueno y
	`ghost_girl_seam.mdl`, que es el MISMO modelo compilado a proposito con el
	decodificador roto de antes del 2026-08-07. Si el de control tampoco
	tambalea, el instrumento no ve el defecto y el verde del bueno no vale
	nada. Por eso el veredicto exige el par, no un valor suelto.
	Medido fuera del juego sobre los .mdl compilados, en grados por cuadro de
	la cadera: bueno max 0.47 / mediana 0.29; control max 17.96 / mediana 0.32.

	POR QUE ClientsideModel Y NO LO QUE HAYA SPAWNEADO: hace falta poner el
	ciclo a mano, y el ciclo de un prop_dynamic lo manda el servidor. Con un
	modelo de cliente la entidad es nuestra y el barrido es determinista --
	no depende del instante en que se corrio el comando.
	OJO: ClientsideModel con una ruta que no esta montada NO falla; devuelve
	el modelo de ERROR, que tiene bbox y huesos y se mide sin quejarse. Se
	comprueba pidiendole un hueso ValveBiped, que el modelo de ERROR no tiene.
]]

local MODELOS = {
	{ "models/phantasmagoria/ghost_girl.mdl",      "el bueno" },
	{ "models/phantasmagoria/ghost_girl_seam.mdl", "CONTROL NEGATIVO (roto a proposito)" },
}
local MUESTRAS = 128
-- Los cortes de la RAZON de la cadera. Medido sobre los dos .mdl compilados,
-- cuadro a cuadro:
--     walk   bueno 1.4   control   48.5
--     idle   bueno 0.0   control 2206.2
-- 8 y 20 dejan un orden de magnitud de margen del lado bueno y mas de dos del
-- lado roto. La franja entre los dos es ZONA GRIS y no un veredicto: si algo
-- cae ahi, el numero no alcanza y decide el A/B a ojo.
local CORTE_LISO, CORTE_TIRON = 8, 20

--[[
	LA PRIMERA VERSION DE ESTO NO MIDIO NADA, y su guarda lo dijo: «el barrido
	no movio un solo hueso». Yo habia elegido UN camino de acceso
	(ClientsideModel con SetNoDraw + SetSequence + GetBonePosition) sin poder
	probarlo -- `luaharness.py` devuelve nil en ClientsideModel a proposito --
	y lo escribi como si supiera cual anda.

	Ahora no elige: los PRUEBA. Son dos decisiones independientes y ninguna es
	obvia desde afuera del motor:

	  como se LEE el hueso : GetBoneMatrix (el documentado despues de
	                         SetupBones) o GetBonePosition
	  como se MONTA        : ResetSequence o SetSequence, y con SetNoDraw o sin
	                         el -- una entidad que el cliente no dibuja puede
	                         no llegar a armar sus huesos nunca

	El sondeo pone el ciclo en 0 y en 0.5 y mira cuanto se movio la pose. El
	que mueva algo gana; si no mueve ninguno, se dice y no se inventa un
	numero. Y se cuenta aparte cuantas lecturas volvieron NIL, porque
	«la pose esta congelada» y «la lectura no devolvio nada» son dos causas
	distintas con el MISMO sintoma -- que es el que ya se comio una ronda.
]]

local ACCESOS = {
	{ nombre = "GetBoneMatrix",
	  leer = function( e, b ) local m = e:GetBoneMatrix( b ) return m and m:GetTranslation() end },
	{ nombre = "GetBonePosition",
	  leer = function( e, b ) return e:GetBonePosition( b ) end },
}
local MONTAJES = {
	{ nombre = "ResetSequence+nodraw", reset = true,  nodraw = true  },
	{ nombre = "ResetSequence+dibuja", reset = true,  nodraw = false },
	{ nombre = "SetSequence+nodraw",   reset = false, nodraw = true  },
}

local function crear( mdl, seqName, montaje )
	-- La ruta VA ENTERA, con el `models/` adelante: file.Exists busca desde la
	-- raiz del search path. Y se usa file.Exists y no util.IsValidModel porque
	-- el segundo devuelve false en CLIENTE sobre modelos que el motor si sirve
	-- -- ya dio dos rojos falsos en el arco del equipamiento.
	if not file.Exists( mdl, "GAME" ) then
		-- Que falte el `_seam` es LO NORMAL fuera de un bloque abierto: se borra
		-- al cerrar, porque es un instrumento y no un asset. Se dice aca para
		-- que el rojo no se lea como una instalacion rota.
		return nil, "no esta montado (file.Exists dice que no)"
			.. ( string.find( mdl, "_seam", 1, true )
			     and " -- y el control negativo se BORRA al cerrar un bloque; "
			         .. "se rehace con python dev/phastools/_seamctl.py"
			     or "" )
	end
	local e = ClientsideModel( mdl, RENDERGROUP_OPAQUE )
	if not IsValid( e ) then return nil, "ClientsideModel no lo pudo crear" end
	-- Ponerlo donde esta el jugador: una entidad de cliente nace en el origen
	-- del mapa, que puede estar fuera del PVS -- y fuera del PVS el cliente
	-- tiene motivos para no armarle los huesos.
	local ply = LocalPlayer()
	if IsValid( ply ) then e:SetPos( ply:GetPos() ) end
	e:SetNoDraw( montaje.nodraw )

	-- La guarda del modelo de ERROR: no alcanza con que la entidad exista.
	if not e:LookupBone( "ValveBiped.Bip01_Pelvis" ) then
		local m = tostring( e:GetModel() )
		e:Remove()
		return nil, "salio sin huesos ValveBiped -- es el modelo de ERROR (" .. m .. ")"
	end
	local seq = e:LookupSequence( seqName )
	-- LookupSequence devuelve -1, no nil, cuando el nombre no existe.
	if not seq or seq < 0 then
		-- Y SE DICEN LAS QUE SI TIENE. Con `$includemodel` el modelo declara
		-- 2171 secuencias, casi todas de m_anm; las PROPIAS son las primeras,
		-- que son justo las que uno quiso escribir. Un «no la tiene» sin decir
		-- cuales hay deja al que lo lee adivinando el nombre.
		local hay = {}
		for i = 0, math.min( 5, e:GetSequenceCount() - 1 ) do
			hay[ #hay + 1 ] = tostring( e:GetSequenceName( i ) )
		end
		e:Remove()
		return nil, "no tiene la secuencia '" .. seqName .. "'; las primeras que "
			.. "declara son: " .. table.concat( hay, ", " )
	end
	if montaje.reset then e:ResetSequence( seq ) else e:SetSequence( seq ) end
	e:SetPlaybackRate( 0 )
	return e
end

local function posar( e, ciclo, acceso )
	e:SetCycle( ciclo )
	-- SIN ESTO EL BARRIDO NO BARRE: los huesos se cachean por cuadro, y las
	-- lecturas saldrian todas de la primera pose -- que se lee como «no
	-- tiembla», o sea el resultado que se esta buscando.
	e:InvalidateBoneCache()
	e:SetupBones()
	local out, nils = {}, 0
	for b = 0, e:GetBoneCount() - 1 do
		local p = acceso.leer( e, b )
		if p then out[ b ] = p else nils = nils + 1 end
	end
	-- LA ORIENTACION DE LA RAIZ, aparte. Ver `razonRaiz`.
	local raiz = e:LookupBone( "ValveBiped.Bip01_Pelvis" )
	local m = raiz and e:GetBoneMatrix( raiz )
	return out, nils, m and { m:GetForward(), m:GetRight(), m:GetUp() }
end

local function separacion( a, b )
	local d = 0
	for k, v in pairs( a ) do if b[ k ] then d = d + v:Distance( b[ k ] ) end end
	return d
end

--[[
	CUANTO GIRO LA RAIZ entre dos poses, en grados, sin pasar por Euler.

	POR QUE LA RAIZ Y NO LOS 53 HUESOS SUMADOS. La primera version sumaba el
	desplazamiento de todos los huesos, y en el `walk` NO SEPARA: el vaiven
	legitimo de las piernas es tan grande que ahoga el tiron de la cadera. Con
	los numeros del .mdl: sumando todo, la mediana del walk es 47-54 y el tiron
	159 -- razon 2.9, por debajo de cualquier corte util. Aislando la cadera,
	0,32 contra 17,96 -- razon 48,5. En el `idle` sumar andaba de casualidad,
	porque ahi no hay movimiento legitimo que ahogue nada (mediana 2,47).
	*Una metrica que promedia el sujeto con todo lo demas mide la escena, no el
	sujeto.* Y el sintoma reportado es del cuerpo entero ladeandose, o sea la
	raiz: no es una eleccion de conveniencia.

	Se compara la BASE (forward/right/up) y no los angulos de Euler: dos
	triples de Euler distintos pueden ser la misma rotacion, y ademas cruzan la
	frontera de +-180 y darian saltos que no existen. Esa confusion ya costo
	un diagnostico entero en la herramienta que genero estas animaciones.
]]
local function giroRaiz( a, b )
	if not a or not b then return nil end
	local t = 0
	for k = 1, 3 do
		t = t + math.deg( math.acos( math.Clamp( a[ k ]:Dot( b[ k ] ), -1, 1 ) ) )
	end
	return t / 3
end

--- Prueba las 6 combinaciones sobre un modelo y devuelve la que mueve la pose.
local function sondear( mdl, seqName )
	print( "[ph_costura] --- sondeo del camino de acceso (ciclo 0 contra 0.5) ---" )
	local mejor, midieron, ultimoErr = nil, 0, nil
	for _, m in ipairs( MONTAJES ) do
		for _, a in ipairs( ACCESOS ) do
			local e, err = crear( mdl, seqName, m )
			if not e then
				ultimoErr = err
				print( string.format( "[ph_costura]   %-22s %-16s NO SE PUDO: %s",
					m.nombre, a.nombre, err ) )
			else
				midieron = midieron + 1
				local p0, n0 = posar( e, 0, a )
				local p1, n1 = posar( e, 0.5, a )
				local d, nb = separacion( p0, p1 ), e:GetBoneCount()
				-- El GetBoneCount va ANTES del Remove. Estaba despues, y una
				-- entidad borrada no contesta: la linea que reporta el sondeo
				-- se habria caido justo cuando el sondeo tenia algo que decir.
				e:Remove()
				print( string.format( "[ph_costura]   %-22s %-16s movio %8.2f   nils %d/%d",
					m.nombre, a.nombre, d, math.max( n0, n1 ), nb ) )
				if d > 0.01 and not mejor then mejor = { montaje = m, acceso = a } end
			end
		end
	end
	if mejor then
		print( string.format( "[ph_costura]   -> gana %s + %s",
			mejor.montaje.nombre, mejor.acceso.nombre ) )
	elseif midieron == 0 then
		-- ESTAS DOS RAMAS ESTABAN JUNTAS Y ERA UN DEFECTO. Con `ph_ghost_costura
		-- walk` --el nombre real es `walk_ours`-- las seis combinaciones fallaron
		-- ANTES de medir, y el comando igual anunciaba «este camino no existe en
		-- este motor»: una guarda de arriba emitiendo un diagnostico sobre algo
		-- de abajo que nunca se probo. Un error se cuenta donde ocurre.
		print( "[ph_costura]   -> ninguna combinacion llego a MEDIR. No se probo el "
			.. "camino de acceso: la corrida se cayo antes, y esto NO dice nada "
			.. "sobre el motor." )
		print( "[ph_costura]      motivo: " .. tostring( ultimoErr ) )
	else
		print( "[ph_costura]   -> las " .. midieron .. " combinaciones midieron y "
			.. "NINGUNA movio la pose. Este camino no existe en este motor; "
			.. "el A/B a ojo (ph_ghost_ab) es el que decide." )
	end
	return mejor
end

local function medirCostura( mdl, seqName, combo )
	local e, err = crear( mdl, seqName, combo.montaje )
	if not e then return nil, err end

	local prev, prevM, pasos, giros, nils = nil, nil, {}, {}, 0
	for k = 0, MUESTRAS do
		local cur, n, base = posar( e, k / MUESTRAS, combo.acceso )
		nils = math.max( nils, n )
		if prev then
			pasos[ #pasos + 1 ] = separacion( cur, prev )
			local g = giroRaiz( base, prevM )
			if g then giros[ #giros + 1 ] = g end
		end
		prev, prevM = cur, base
	end
	local nb = e:GetBoneCount()
	e:Remove()
	if nils >= nb then
		return nil, "las " .. nils .. " lecturas de hueso volvieron NIL: no es que "
			.. "la pose este quieta, es que no se leyo"
	end
	if #giros == 0 then
		return nil, "no se pudo leer la orientacion de la raiz (Bip01_Pelvis)"
	end

	table.sort( pasos )
	table.sort( giros )
	local med, mx = pasos[ math.ceil( #pasos / 2 ) ], pasos[ #pasos ]
	-- Un barrido que no movio nada da 0/0 y hay que decirlo, no dividirlo:
	-- seria el unico caso que imprime "liso" sin haber medido una pose.
	if not mx or mx <= 0 then
		return nil, "el barrido no movio un solo hueso: la secuencia no se evaluo"
	end
	local gmed, gmx = giros[ math.ceil( #giros / 2 ) ], giros[ #giros ]
	-- El piso de 0,05 grados es para el hueso QUIETO: la cadera del idle bueno
	-- no se mueve nada, y 0/0 no es un numero. Con el piso da 0 -> LISO, que es
	-- la verdad, en vez de una division indefinida.
	return { max = mx, med = med, n = nb,
	         gmax = gmx, gmed = gmed, razon = gmx / ( gmed + 0.05 ) }
end

local function cmd_costura( _, _, args )
	local seqName = ( args and args[ 1 ] ) or "walk_ours"
	print( "[ph_costura] secuencia: " .. seqName .. "   " .. MUESTRAS .. " muestras del ciclo" )

	-- El sondeo va sobre EL BUENO. Si el camino de acceso no anda, el mensaje
	-- tiene que decir eso y no "el modelo no tiembla", que es el veredicto que
	-- se buscaba: un instrumento roto no puede devolver el resultado deseado.
	local combo = sondear( MODELOS[ 1 ][ 1 ], seqName )
	if not combo then
		print( "[ph_costura] >> SIN CORRER. Mirar el motivo que imprimio el sondeo: "
			.. "no es un resultado sobre el modelo." )
		return
	end

	local veredicto = {}
	for _, m in ipairs( MODELOS ) do
		local r, err = medirCostura( m[ 1 ], seqName, combo )
		if not r then
			print( string.format( "[ph_costura] %-46s NO SE PUDO MEDIR: %s", m[ 1 ], err ) )
			veredicto[ #veredicto + 1 ] = false
		else
			print( string.format( "[ph_costura] %-46s %s", m[ 1 ], m[ 2 ] ) )
			print( string.format( "[ph_costura]    CADERA: giro maximo %.3f  mediana %.3f"
				.. "  -> RAZON %.1f  %s", r.gmax, r.gmed, r.razon,
				r.razon < CORTE_LISO and "LISO"
				or ( r.razon > CORTE_TIRON and "TIRON" or "ZONA GRIS" ) ) )
			-- Se imprime al lado y NO decide: es la metrica vieja, la que suma
			-- los 53 huesos. En el walk no separaba (2.9 sobre el modelo roto).
			-- Queda para que se vea POR QUE se cambio, no como segundo veredicto.
			print( string.format( "[ph_costura]    (contexto, los %d huesos sumados: "
				.. "maximo %.2f  mediana %.2f  razon %.1f -- esta metrica NO separa "
				.. "en el walk)", r.n, r.max, r.med, r.max / math.max( r.med, 1e-6 ) ) )
			veredicto[ #veredicto + 1 ] = r.razon
		end
	end

	local bueno, control = veredicto[ 1 ], veredicto[ 2 ]
	if not bueno or not control then
		print( "[ph_costura] >> falta una de las dos lecturas: NO se emite veredicto." )
	elseif control < CORTE_TIRON then
		print( "[ph_costura] >> EL CONTROL NEGATIVO NO TIEMBLA (" .. string.format( "%.1f", control )
			.. "). El instrumento no ve el defecto que busca," )
		print( "[ph_costura] >> asi que el numero del bueno no prueba nada. Check SIN CORRER." )
	elseif bueno < CORTE_LISO then
		print( "[ph_costura] >> PASA: el bueno es liso (" .. string.format( "%.1f", bueno )
			.. ") y el control tiembla (" .. string.format( "%.1f", control ) .. ")." )
	else
		print( "[ph_costura] >> FALLA: el bueno tambien tiembla ("
			.. string.format( "%.1f", bueno ) .. "). El arreglo no entro en este .mdl." )
	end
end

concommand.Add( "ph_ghost_costura", cmd_costura, nil,
	"Mide el tambaleo del ciclo en el modelo bueno y en el de control. Arg: secuencia." )
