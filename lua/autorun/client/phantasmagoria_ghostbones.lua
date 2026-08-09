--[[
	Medir los huesos del fantasma DEL LADO DEL CLIENTE.

	    ph_ghost_bones      largos de hueso de TODO lo que lleve puesto el modelo

	POR QUE DE CLIENTE, Y NO EN ph_ghost_ragdoll / ph_ghost_anim

	El comando de servidor midio los mismos cinco pares y devolvio EXACTAMENTE
	los mismos numeros en el cuadro 0 y a los 0,5 s -- 11.69 y 11.69 -- mientras
	el ciclo avanzaba de 0 a 0,42. Una caminata mueve esos huesos; que no se
	movieran ni un milesimo no era "no se estira", era que el servidor NO estaba
	evaluando la animacion. Lo que leia era la tabla de huesos estatica, ya
	fusionada con la de m_anm.mdl por el $includemodel. `Entity:SetupBones` es
	de cliente por lo mismo.

	⚠ EL MECANISMO QUE ESTO MIDE CAMBIO, Y EL ENCABEZADO VIEJO DESCRIBIA UNO
	ABANDONADO. Decia que hacia falta el cliente porque "la capa de proporciones
	es una animacion autoplay": ese truco ( subtract + autoplay ) se probo,
	compilo y midio 0/5, y se tiro. El mecanismo de hoy es otro -- nuestras
	secuencias se llaman IGUAL que las de m_anm ( walk_all, run_all_01, ... ) y
	el engine descarta la prestada homonima al resolver el $includemodel.

	El instrumento sigue siendo de cliente, pero por un motivo distinto y que
	conviene tener escrito: con el mecanismo nuevo el largo de hueso depende de
	QUE SECUENCIA se este reproduciendo -- las animaciones de HL2 son de
	rotacion pura, asi que todo hueso que la animacion no traslada toma su
	reposo del modelo DUENO de esa animacion. O sea que esto no mide "el
	modelo": mide el modelo EN LA SECUENCIA QUE ESTE VIVA, y por eso la
	secuencia viva se imprime al lado de los numeros y no como adorno.

	EL CRITERIO

	Los largos que declara el .mdl compilado son 6.70 / 6.09 / 9.72 / 9.61 /
	3.47. La tabla que impone m_anm es 11.69 / 11.48 / 17.85 / 16.53 / 3.59.
	Son dos juegos de numeros bien separados, asi que no hay que interpretar:
	el que salga dice cual gano.
]]

-- {padre, hijo, largo que declara el .mdl, largo que impone m_anm}
local PARES = {
	{ "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", 6.70, 11.69 },
	{ "ValveBiped.Bip01_L_Forearm",  "ValveBiped.Bip01_L_Hand",    6.09, 11.48 },
	{ "ValveBiped.Bip01_L_Thigh",    "ValveBiped.Bip01_L_Calf",    9.72, 17.85 },
	{ "ValveBiped.Bip01_L_Calf",     "ValveBiped.Bip01_L_Foot",    9.61, 16.53 },
	{ "ValveBiped.Bip01_Neck1",      "ValveBiped.Bip01_Head1",     3.47,  3.59 },
}

--[[
	⚠ ESTE COMANDO NO VEIA AL NEXTBOT, Y ERA EL CHECK QUE LA RONDA 16 EXISTIA
	PARA CORRER. Buscaba por una LISTA BLANCA DE CLASES -- prop_dynamic,
	prop_ragdoll, prop_physics -- que eran las tres formas en que el fantasma se
	spawneaba cuando esto se escribio. Cuando el sujeto paso a ser
	`terminator_nextbot_phantom` la busqueda quedo mirando un banco de pruebas
	vacio, y contesto «no hay ningun ghost_girl spawneado», que se lee como
	NO HAY NADA cuando lo que pasaba era NO MIRO AHI. La fila 05 quedo sin
	correr y nadie midio un hueso sobre el bot.

	El arreglo no es agregar la clase del bot a la lista -- eso vuelve a romperse
	con los 30 tipos de Diseno 12.2, que se van a llamar phantasmagoria_<tipo>.
	El sujeto se define por lo unico que lo hace sujeto: LLEVAR PUESTO EL MODELO.
	Asi que la lista blanca se da vuelta y pasa a ser una lista NEGRA de la unica
	clase que hay que sacar, con el motivo al lado.

	Y cuando no encuentra nada, DICE DONDE MIRO y que descarto. Un instrumento
	que puede salir vacio tiene que hacer que el vacio sea una medicion.
]]

-- Los seguidores del ragdoll. No tienen nuestros huesos y llenaban la consola
-- con quince bloques de "hueso ausente" que tapaban la unica lectura que
-- importaba. Es la UNICA exclusion, y por eso esta nombrada y no implicita.
local CLASES_EXCLUIDAS = {
	[ "phys_bone_follower" ] = "seguidor de fisica del ragdoll, no tiene los huesos del modelo",
}

--[[
	LOS DOS CAMINOS DE LECTURA, Y SE CORREN LOS DOS A PROPOSITO.

	El sondeo de ph_ghost_costura ( abajo en este mismo archivo ) midio que sobre
	un ClientsideModel `GetBonePosition` devuelve algo que NO SE MUEVE aunque los
	huesos esten armados -- no nil, no error: quieto -- y que `GetBoneMatrix`
	sobre la misma entidad y en la misma llamada si. Sobre entidades replicadas
	del servidor `GetBonePosition` si anduvo ( 5/5 en la ronda 2 ).

	Sobre un NEXTBOT no lo midio nadie. Asi que no se elige uno: se leen los dos
	y se imprimen los dos cuando difieren. Elegir sin medir es el error que este
	arco ya pago cuatro veces, y aca el modo de falla es especialmente feo -- una
	lectura congelada en la pose de reposo devolveria numeros PLAUSIBLES.
]]
local function leerPar( e, ia, ib )
	local ma, mb = e:GetBoneMatrix( ia ), e:GetBoneMatrix( ib )
	local dMat = ( ma and mb ) and ma:GetTranslation():Distance( mb:GetTranslation() ) or nil

	local pa, pb = e:GetBonePosition( ia ), e:GetBonePosition( ib )
	local dPos = ( pa and pb ) and pa:Distance( pb ) or nil

	return dMat, dPos
end

local function cmd()
	-- Cualquier variante de ghost_girl, no un nombre exacto: el control sin
	-- $includemodel se llama ghost_girl_noinc.mdl y hay que medir los dos EN LA
	-- MISMA CORRIDA para que la comparacion valga.
	local encontrados, descartados = {}, {}

	--[[
		⚠ `e:GetModel()` NO DEVUELVE nil SOBRE UNA ENTIDAD SIN MODELO: NO DEVUELVE
		NADA. Y `tostring()` con cero argumentos no da "nil", da
		    bad argument #1 to 'tostring' (value expected)
		que es lo que revento este comando en la corrida de la r17 -- sobre la
		PRIMERA entidad sin modelo del mapa, o sea antes de mirar un solo fantasma.

		La diferencia entre `nil` y "cero valores" no se ve escribiendo la linea:
		`tostring( x() )` con x devolviendo nil anda, y con x devolviendo nada
		revienta. Guardarlo en un local iguala los dos casos, porque un local sin
		valor asignado ES nil.

		*Y es el mismo defecto que este comando existia para arreglar, una capa mas
		abajo: en la r16 el instrumento no veia al sujeto porque miraba otras
		clases; en la r17 no lo veia porque se caia antes de llegar.* Dos rondas
		seguidas sin que nadie mida un hueso sobre el bot.
	]]
	for _, e in ipairs( ents.GetAll() ) do
		local mdl = IsValid( e ) and e:GetModel() or nil

		if isstring( mdl ) and string.find( mdl, "ghost_girl", 1, true ) then
			local cls = e:GetClass()

			if CLASES_EXCLUIDAS[ cls ] then
				descartados[ cls ] = ( descartados[ cls ] or 0 ) + 1

			else
				encontrados[ #encontrados + 1 ] = e

			end
		end
	end

	if #encontrados == 0 then
		-- EL VACIO COMO MEDICION: que se busco, entre cuantas, y que se saco.
		print( "[ph_bones] NO HAY NINGUNA ENTIDAD con 'ghost_girl' en el modelo, de las " ..
			#ents.GetAll() .. " que existen en el cliente." )
		print( "[ph_bones] Se busca por MODELO y no por clase, asi que esto alcanza al NextBot, " ..
			"a los props y al ragdoll por igual." )

		local hubo = false
		for cls, n in pairs( descartados ) do
			hubo = true
			print( "[ph_bones]   ( se descartaron " .. n .. " x " .. cls .. ": " ..
				CLASES_EXCLUIDAS[ cls ] .. " )" )
		end
		if hubo then
			print( "[ph_bones] O sea que el modelo SI esta en el mapa, pero solo en entidades " ..
				"excluidas. Eso no es 'no hay nada'." )
		end

		print( "[ph_bones] Spawnear el NextBot, o correr ph_ghost_anim / ph_ghost_ragdoll." )
		return
	end

	print( "[ph_bones] " .. #encontrados .. " entidad(es) con el modelo." )

	for _, e in ipairs( encontrados ) do
		if IsValid( e ) then
			-- De cliente SI existe, y es lo que fuerza a que la pose este
			-- evaluada. Sin esto se lee la pose del cuadro anterior o la de
			-- reposo, que devuelve numeros creibles sin haber medido la pose.
			e:SetupBones()

			local seq = e:GetSequence()
			print( string.format( "[ph_bones] --- %s  [%s]  modelo %s ---",
				tostring( e ), e:GetClass(), tostring( e:GetModel() ) ) )
			-- LA SECUENCIA VIVA NO ES CONTEXTO, ES PARTE DE LA MEDICION: con el
			-- mecanismo de reemplazo por nombre, el largo de hueso depende de que
			-- animacion se este reproduciendo. Un 17,85 durante una secuencia
			-- PRESTADA es el comportamiento esperado, no el defecto.
			print( string.format( "[ph_bones]     seq %d (%s)   ciclo %.3f",
				seq, tostring( e:GetSequenceName( seq ) ), e:GetCycle() ) )

			local propio, ajeno, difieren = 0, 0, 0

			for _, par in ipairs( PARES ) do
				local ia, ib = e:LookupBone( par[ 1 ] ), e:LookupBone( par[ 2 ] )
				local etiqueta = par[ 1 ]:sub( 17 ) .. "->" .. par[ 2 ]:sub( 17 )

				if not ia or not ib then
					print( string.format( "[ph_bones]   %-24s hueso ausente", etiqueta ) )

				else
					local dMat, dPos = leerPar( e, ia, ib )

					if not dMat and not dPos then
						print( string.format( "[ph_bones]   %-24s LAS DOS LECTURAS DIERON NIL " ..
							"-- no es 'no se estira', es que no se leyo", etiqueta ) )

					else
						-- El veredicto se toma con GetBoneMatrix, que es el que el
						-- sondeo demostro que sigue la pose. GetBonePosition va al
						-- lado como control: si los dos coinciden, la duda se cerro
						-- en esta corrida y sobre ESTA clase de entidad.
						local d = dMat or dPos
						local dp, da = math.abs( d - par[ 3 ] ), math.abs( d - par[ 4 ] )
						local quien
						if dp < da then quien = "NUESTRO" propio = propio + 1
						else quien = "m_anm"  ajeno = ajeno + 1 end

						local nota = ""
						if dMat and dPos and math.abs( dMat - dPos ) > 0.05 then
							difieren = difieren + 1
							nota = string.format( "   [GetBonePosition dio %.2f -- DIFIERE]", dPos )

						elseif not dMat then
							nota = "   [GetBoneMatrix dio nil; el numero es de GetBonePosition]"

						elseif not dPos then
							nota = "   [GetBonePosition dio nil]"

						end

						print( string.format(
							"[ph_bones]   %-24s %6.2f   (.mdl %5.2f / m_anm %5.2f)  -> %s%s",
							etiqueta, d, par[ 3 ], par[ 4 ], quien, nota ) )
					end
				end
			end

			print( string.format( "[ph_bones]   VEREDICTO: %d/%d se parecen a NUESTRO esqueleto  %s",
				propio, #PARES,
				propio == #PARES and "-> el modelo usa SUS proporciones"
				or ( ajeno == #PARES and "-> ESTIRADO: esta tomando el esqueleto de m_anm"
				     or "-> mezcla; hay que mirar hueso por hueso" ) ) )

			if difieren > 0 then
				print( "[ph_bones]   ⚠ " .. difieren .. " par(es) leyeron distinto por los dos " ..
					"caminos. Uno de los dos NO esta siguiendo la pose, y sobre esta clase " ..
					"de entidad no estaba medido cual." )
			end
		end
	end
end

concommand.Add( "ph_ghost_bones", cmd,
	nil, "Mide los largos de hueso del fantasma, del lado del CLIENTE." )

--------------------------------------------------------- la pose T, del lado que la dibuja

--[[
	ph_ghost_land   -- muestrea 3 s y dice si el CLIENTE se quedo sin animacion

	POR QUE DE CLIENTE, Y POR QUE ES OTRA MEDICION Y NO LA MISMA.

	`phantasmagoria_ghost_landwatch` muestrea el mismo instante en el SERVIDOR.
	Los dos son necesarios y no son redundantes: la pose T es lo que se DIBUJA, y
	quien dibuja es el cliente. Un servidor con `run_all_01` puesta y un cliente
	sin secuencia se ven, desde el servidor, exactamente igual que todo bien --
	y ese modo de falla ya se cobro un arco entero en este proyecto ( el hook de
	arranque que no dispara en el realm cliente y sobrevivio dos arranques por no
	tener instrumento ahi ).

	Y encaja con lo que reporto el autor: *"algo parecido he notado en otros
	player models que cuando saltan y caen quedan en posicion T o la animacion
	queda desfasada"*. "Desfasado" es una palabra sobre el cliente.

	QUE MIDE, y los tres estados se separan porque se arreglan en lugares
	distintos:

	  SIN SECUENCIA    GetSequence() < 0 o nombre vacio -> se dibuja el esqueleto
	                   de reposo. ESTA es la pose T.
	  CICLO CONGELADO  hay secuencia y el ciclo no se mueve. Se ve como una
	                   estatua en una pose real, no en la T.
	  SANO             el ciclo avanza.

	⚠ NO ESPERA EL ATERRIZAJE: muestrea desde que se corre. Es a proposito --
	engancharlo a un evento de caida en el cliente seria un tercer mecanismo sin
	medir, y el trato es simple: se corre el comando y despues se lo tira con el
	physgun. La ventana de 3 s cubre el tramite.
]]

local MUESTRAS_LAND, PASO_LAND = 60, 0.05

local function cmd_land()
	-- El mismo criterio de sujeto que ph_ghost_bones: por MODELO, no por clase.
	local sujeto
	for _, e in ipairs( ents.GetAll() ) do
		local mdl = IsValid( e ) and e:GetModel() or nil

		if isstring( mdl ) and string.find( mdl, "ghost_girl", 1, true )
			and not CLASES_EXCLUIDAS[ e:GetClass() ] then
			sujeto = e
			break
		end
	end

	if not sujeto then
		print( "[ph_land] SIN CORRER: no hay ninguna entidad con 'ghost_girl' en el modelo, " ..
			"de las " .. #ents.GetAll() .. " que existen en el cliente." )
		return
	end

	print( string.format( "[ph_land] %s  [%s]   muestreando %.1f s cada %.2f s.",
		tostring( sujeto ), sujeto:GetClass(), MUESTRAS_LAND * PASO_LAND, PASO_LAND ) )
	print( "[ph_land] AHORA: levantalo con el physgun y soltalo desde alto. Al terminar imprime solo." )

	local n, previo = 0, nil
	local sinSeq, congelados, sanas, nils = 0, 0, 0, 0
	local vistas, ordenVistas = {}, {}
	local primerDefecto = nil

	timer.Create( "ph_ghost_land", PASO_LAND, MUESTRAS_LAND, function()
		if not IsValid( sujeto ) then
			timer.Remove( "ph_ghost_land" )
			print( "[ph_land] el sujeto dejo de ser valido a las " .. n .. " muestras. " ..
				"Lo que sigue es sobre las que SI se tomaron." )
			return
		end

		n = n + 1

		local seq = sujeto:GetSequence()

		-- ⚠ El nombre se guarda en un LOCAL antes de tostring: el mismo defecto
		-- que revento este archivo en la r17 vive en cualquier getter que pueda
		-- devolver CERO valores en vez de nil.
		local nombre = isnumber( seq ) and seq >= 0 and sujeto:GetSequenceName( seq ) or nil
		nombre = isstring( nombre ) and nombre or ""

		local ciclo = sujeto:GetCycle()

		if not isnumber( ciclo ) then
			nils = nils + 1

		elseif not isnumber( seq ) or seq < 0 or nombre == "" then
			sinSeq = sinSeq + 1
			primerDefecto = primerDefecto or string.format(
				"a los %.2f s: SIN SECUENCIA ( seq %s ) -- pose de referencia",
				n * PASO_LAND, tostring( seq ) )

		else
			if not vistas[ nombre ] then
				vistas[ nombre ] = true
				ordenVistas[ #ordenVistas + 1 ] = nombre
			end

			local avanza = previo == nil or math.abs( ciclo - previo ) > 0.0005

			if avanza then
				sanas = sanas + 1

			else
				congelados = congelados + 1
				primerDefecto = primerDefecto or string.format(
					"a los %.2f s: CICLO CONGELADO en %s ( ciclo %.3f )",
					n * PASO_LAND, nombre, ciclo )
			end

			previo = ciclo
		end

		if n < MUESTRAS_LAND then return end

		print( string.format( "[ph_land] %d muestras: %d sanas, %d SIN SECUENCIA, %d con el " ..
			"ciclo congelado, %d sin lectura.", n, sanas, sinSeq, congelados, nils ) )
		print( "[ph_land] secuencias vistas: " ..
			( #ordenVistas > 0 and table.concat( ordenVistas, ", " ) or "NINGUNA" ) )

		if primerDefecto then
			print( "[ph_land]   primer defecto  " .. primerDefecto )
		end

		-- EL VEREDICTO RESTA LO QUE NO SE PUDO MEDIR. Un `nils` alto no es un
		-- verde: es una ventana que no midio, y contarla como sana es el defecto
		-- que este proyecto ya arreglo dos veces en dos archivos distintos.
		if nils >= n then
			print( "[ph_land] >> SIN CORRER: ninguna muestra devolvio un ciclo. No se midio " ..
				"nada; esto NO dice que el cliente este bien." )

		elseif sinSeq > 0 then
			print( "[ph_land] >> LA POSE T ES DEL CLIENTE: " .. sinSeq .. " muestra(s) sin " ..
				"secuencia. El servidor puede tener la actividad puesta igual -- comparar " ..
				"con phantasmagoria_ghost_actlog_dump." )

		elseif congelados > 0 then
			print( "[ph_land] >> NO ES LA POSE T, es una ANIMACION DETENIDA: " .. congelados ..
				" muestra(s) con el ciclo quieto sobre una secuencia real. Se arregla en otro " ..
				"lado que una actividad que falta." )

		else
			print( "[ph_land] >> el cliente tuvo secuencia y ciclo vivo en las " .. sanas ..
				" muestras. Si la T se vio DENTRO de esta ventana, no fue por esto." )
			print( "[ph_land] >> ⚠ y si no se llego a tirar el bot dentro de la ventana, esto " ..
				"es SIN CORRER y no un descarte." )
		end
	end )
end

concommand.Add( "ph_ghost_land", cmd_land, nil,
	"Muestrea 3 s la animacion del fantasma EN EL CLIENTE. Correrlo y despues tirarlo con el physgun." )

--------------------------------------------------------- el cuerpo dibujado

--[[
	ph_ghost_facing   -- ¿hacia donde apunta el CUERPO mientras se mueve?

	⚠ POR QUE HACE FALTA OTRO INSTRUMENTO: LOS METADATOS NO SON LA POSE.

	La r19 dejó esto, con el bot corriendo de frente:

	    MEDIDO  move_x +1.00  move_y +0.00  -> celda N
	    MARCHA  vel 280 u/s   adelante +1.00  derecha +0.00  -> celda N
	    >> CONCUERDAN: 0.0 grados

	...y el autor mandó la foto: **sigue corriendo de lado**. Y en la fila de al
	lado, los dos realms informaron secuencia viva y ciclo avanzando mientras él
	veía la pose T. O sea que TODO lo que este bloque venía midiendo son
	metadatos de la animación —qué actividad, qué secuencia, qué celda de la
	mezcla— y ninguno de ellos es **la pose que se dibuja**.

	*Un instrumento que mide los metadatos de una animación puede dar verde en
	los dos realms mientras la pantalla dibuja otra cosa. La pose hay que medirla
	en los HUESOS.*

	LO QUE MIDE, y las tres son geométricas y sin convención:

	  eje de CADERAS vs MARCHA        corriendo de frente tiene que dar ~90°.
	                                  Si da ~0° o ~180°, el cuerpo va de costado
	                                  y eso ya no es una impresión.
	  ORIENTACION de la entidad
	    vs MARCHA                     ~0° con facewalk puesto.
	  eje de CADERAS vs ORIENTACION   ~90°. Si ésta se rompe y la anterior no,
	                                  el cuerpo DIBUJADO está girado respecto de
	                                  su propia entidad — o sea el modelo, no la IA.

	Las tres juntas nombran al culpable; una sola no.

	⚠ LA MARCHA SE MIDE POR DIFERENCIA DE POSICION y no con `GetVelocity()`: del
	lado del cliente, la velocidad de un NextBot es lo que el motor haya
	interpolado, y acá justamente se está auditando si el cliente y el servidor
	dicen lo mismo. Una posición se puede ver en la pantalla; una velocidad
	networkeada no.

	⚠ Y NO SE DERIVA EL "FRENTE" DEL CUERPO A PARTIR DE LAS CADERAS. Eso pedría
	una convención sobre qué lado del eje es el frente, y este arco ya pagó tres
	suposiciones de ese tipo. Perpendicular-vs-paralelo es un hecho físico sobre
	correr de frente y no necesita saber para qué lado se mira.
]]

--[[
	LA POSE DE REFERENCIA, MEDIDA — no recordada.

	Salen de componer la cadena de huesos del PRIMER cuadro de
	`creepygirl_ref.smd`, que es literalmente el archivo que studiomdl usa como
	pose de reposo del modelo (`$body studioprop "creepygirl_ref.smd"`). O sea
	que son los números que se dibujan cuando NO hay animación, que es lo que el
	autor llama "pose T".

	    brazo izq ( hombro -> mano ) a  46.5°  de la vertical
	    manos separadas              25.23 u
	    eje de caderas ( R - L )     (-7.468, -0.081, 0)  -> sobre el eje X

	Una idle real mantiene las manos MUCHO más juntas, así que la separación es
	el discriminante barato. Se imprimen los dos y el comando no elige por el
	lector: dice el valor de reposo al lado del medido.

	⚠ Y LA TERCERA LÍNEA ES UN HALLAZGO QUE ESTA MEDICIÓN DESTAPÓ, no un dato de
	contexto. En la pose de REPOSO las caderas van sobre **X**, o sea PARALELAS
	al frente de la entidad; en cualquier pose animada van sobre Y, o sea
	perpendiculares. Se comprobó que **`m_anm.mdl` —el ValveBiped canónico de
	HL2MP— tiene exactamente lo mismo** (180,0° contra nuestros 179,4°): no es un
	defecto de nuestro rig, es la convención, y las animaciones son las que
	giran el cuerpo a su sitio.

	La consecuencia es la que importa: **un cuerpo dibujado en la pose de reposo
	se ve girado 90° Y en pose T al mismo tiempo.** Los dos síntomas que el autor
	viene reportando por separado —«corre de lado» y «queda en T»— pueden ser
	**un solo defecto**, y este comando es el que puede decirlo, porque mide las
	dos cosas en la misma muestra. (No sería la primera vez en este arco: la r17
	ya juntó otros dos que se habían reportado como distintos.)
]]
local REPOSO_BRAZO, REPOSO_MANOS = 46.5, 25.23

local MUESTRAS_FACING, PASO_FACING = 50, 0.05

local function horiz( v )
	return Vector( v.x, v.y, 0 )
end

--- Angulo en grados entre dos vectores horizontales. nil si alguno es corto.
local function angHoriz( a, b )
	local la, lb = a:Length2D(), b:Length2D()
	if la < 0.01 or lb < 0.01 then return nil end

	local cos = ( a.x * b.x + a.y * b.y ) / ( la * lb )

	return math.deg( math.acos( math.Clamp( cos, -1, 1 ) ) )
end

--[[
	⚠ EL SUJETO ES EL NEXTBOT, Y LA r20 MIDIO UN CADAVER.

	La version anterior tomaba **la primera** entidad con `ghost_girl` en el
	modelo. Las cuatro corridas de la r20 informaron
	`Entity [388][prop_ragdoll]`: un fantasma muerto que quedo tirado en el mapa,
	con el mismo modelo y un `EntIndex` mas bajo que el bot vivo. Tres filas de la
	planilla se llenaron con la pose de un cadaver.

	`ph_ghost_bones` no tiene el problema porque **mide todas** las que encuentra
	--y por eso su salida de la r20 muestra las DOS, el ragdoll y el NextBot, una
	debajo de la otra-- pero este comando muestrea en el tiempo y no puede
	perseguir a varias: tiene que ELEGIR, y entonces tiene que elegir bien y
	**decir a quien descarto**.

	El criterio no es la clase del bot ( eso vuelve a romperse con los 30 tipos
	del Diseno 12.2 ): es tener `loco`, que es lo que hace que una entidad se
	MUEVA por si misma. Un ragdoll no lo tiene y un NextBot si, se llame como se
	llame.

	*Y lo unico que dejo verlo fue que el comando imprimiera con QUE esta
	midiendo. Un instrumento que no nombra a su sujeto no tiene forma de estar
	equivocado en voz alta.*
]]
local function elegirSujeto()
	local candidatos, descartados = {}, {}

	for _, e in ipairs( ents.GetAll() ) do
		local mdl = IsValid( e ) and e:GetModel() or nil

		if isstring( mdl ) and string.find( mdl, "ghost_girl", 1, true )
			and not CLASES_EXCLUIDAS[ e:GetClass() ] then
			candidatos[ #candidatos + 1 ] = e

		end
	end

	-- El que se mueve solo gana. `loco` es del servidor, pero la entidad
	-- replicada del NextBot igual responde a `GetClass`; se prueban los dos
	-- caminos y se dice cual eligio.
	local elegido, motivo
	for _, e in ipairs( candidatos ) do
		local esBot = e.loco ~= nil or string.find( tostring( e ), "NextBot", 1, true ) ~= nil

		if esBot and not elegido then
			elegido, motivo = e, "es el que se mueve solo ( NextBot )"

		elseif elegido ~= e then
			descartados[ #descartados + 1 ] = tostring( e ) .. " [" .. e:GetClass() .. "]"

		end
	end

	-- Sin NextBot se mide lo que haya, PERO diciendolo: un ragdoll es un sujeto
	-- legitimo para otra pregunta y no para esta.
	if not elegido and candidatos[ 1 ] then
		elegido = candidatos[ 1 ]
		motivo = "⚠ NO HAY NINGUN NEXTBOT: esto es " .. elegido:GetClass() ..
			", y su pose no dice nada sobre como corre el bot"

	end

	return elegido, motivo, descartados, #candidatos
end

local function cmd_facing()
	local sujeto, motivo, descartados, nCand = elegirSujeto()

	if not sujeto then
		print( "[ph_facing] SIN CORRER: no hay ninguna entidad con 'ghost_girl' en el modelo, " ..
			"de las " .. #ents.GetAll() .. " que existen en el cliente." )
		return
	end

	print( "[ph_facing] sujeto: " .. tostring( sujeto ) .. " [" .. sujeto:GetClass() .. "]  -- " ..
		motivo .. "   ( " .. nCand .. " candidata(s) con el modelo )" )

	for _, d in ipairs( descartados ) do
		print( "[ph_facing]   descartada: " .. d )

	end

	local HUESOS = { "ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_R_Thigh",
	                 "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Hand",
	                 "ValveBiped.Bip01_R_Hand" }
	local id = {}
	for _, n in ipairs( HUESOS ) do
		local b = sujeto:LookupBone( n )

		if not b then
			-- Un hueso ausente NO se rodea: sin él la medición no existe, y
			-- seguir con los que sí están daría un número que parece uno bueno.
			print( "[ph_facing] SIN CORRER: al modelo le falta el hueso " .. n ..
				". Sin ese hueso no hay eje de caderas ni brazo que medir." )
			return
		end
		id[ n ] = b
	end

	print( string.format( "[ph_facing] %s  [%s]   muestreando %.1f s cada %.2f s.",
		tostring( sujeto ), sujeto:GetClass(), MUESTRAS_FACING * PASO_FACING, PASO_FACING ) )
	print( "[ph_facing] AHORA: que camine o corra. Las filas que comparan contra la MARCHA " ..
		"necesitan que se mueva." )

	local n, prevPos = 0, nil
	local movidas, sumaCadMar, peorCadMar = 0, 0, nil
	local sumaEntMar, peorEntMar = 0, nil
	local sumaCadEnt, peorCadEnt, nCadEnt = 0, nil, 0
	local brazoMax, manosMax = nil, nil
	local sinLectura = 0

	timer.Create( "ph_ghost_facing", PASO_FACING, MUESTRAS_FACING, function()
		if not IsValid( sujeto ) then
			timer.Remove( "ph_ghost_facing" )
			print( "[ph_facing] el sujeto dejo de ser valido a las " .. n .. " muestras." )
			return
		end

		n = n + 1

		-- La pose hay que forzarla a evaluar en CADA muestra: sin esto se leen
		-- los huesos del cuadro anterior, que es una medición vieja con cara de
		-- nueva. (Lo mismo que ya costó una ronda en ph_ghost_costura.)
		sujeto:InvalidateBoneCache()
		sujeto:SetupBones()

		local mL = sujeto:GetBoneMatrix( id[ "ValveBiped.Bip01_L_Thigh" ] )
		local mR = sujeto:GetBoneMatrix( id[ "ValveBiped.Bip01_R_Thigh" ] )
		local mA = sujeto:GetBoneMatrix( id[ "ValveBiped.Bip01_L_UpperArm" ] )
		local mLH = sujeto:GetBoneMatrix( id[ "ValveBiped.Bip01_L_Hand" ] )
		local mRH = sujeto:GetBoneMatrix( id[ "ValveBiped.Bip01_R_Hand" ] )

		--[[
			⚠ UNA MATRIZ QUE EXISTE Y DEVUELVE CERO NO ES UNA LECTURA, Y LA r20
			IMPRIMIO CUATRO FILAS DE NUMEROS SACADOS DE ESO.

			Sobre el `prop_ragdoll` que midio por error, las cinco matrices
			existian y **las cinco devolvieron la misma traduccion** ( se vio en
			`ph_ghost_bones`: los cuatro pares dieron `0.00` ). O sea vectores
			nulos. Y un vector nulo no da un error: da

			    manos separadas   0.00 u
			    brazo             90.0 gr   ( acos(0) -- justo el valor "en T" )
			    caderas           -1.0 gr   ( mi centinela, impreso en una
			                                  columna de grados como si fuera uno )

			tres numeros con cara de medicion. *Un dato ausente que llega como cero
			es peor que uno que llega como nil: el nil se ve, el cero se promedia.*

			El piso no es arbitrario: la cadera del modelo mide 7,47 u de lado a
			lado y el brazo 12,4, medidos del `.smd` de reposo. Cualquier cosa por
			debajo de 1 u es geometria imposible para este esqueleto.
		]]
		local nulo = false
		if mL and mR then
			local d = mL:GetTranslation():Distance( mR:GetTranslation() )
			nulo = d < 1
		end

		if not ( mL and mR and mA and mLH and mRH ) or nulo then
			sinLectura = sinLectura + 1

		else
			local pL, pR = mL:GetTranslation(), mR:GetTranslation()
			local caderas = horiz( pR - pL )
			local frente = sujeto:GetAngles():Forward()

			local pos = sujeto:GetPos()
			local marcha = prevPos and horiz( pos - prevPos ) or nil
			prevPos = pos

			-- El brazo y las manos, que son la pose T medida en geometria.
			local pA, pLH, pRH = mA:GetTranslation(), mLH:GetTranslation(), mRH:GetTranslation()
			local brazo = pLH - pA
			-- `* -1` y no `-v`: la negacion unaria de un Vector depende de que la
			-- metatabla traiga `__unm`, y eso no esta garantizado en todo lo que
			-- ejecuta este archivo. Multiplicar por -1 es la misma cuenta y no
			-- depende de un metametodo.
			local abajo = sujeto:GetAngles():Up() * -1
			local cosB = brazo:GetNormalized():Dot( abajo:GetNormalized() )
			local angB = math.deg( math.acos( math.Clamp( cosB, -1, 1 ) ) )
			local manos = pLH:Distance( pRH )

			if not brazoMax or angB > brazoMax then brazoMax = angB end
			if not manosMax or manos > manosMax then manosMax = manos end

			local cadEnt = angHoriz( caderas, frente )
			if cadEnt then
				nCadEnt = nCadEnt + 1
				sumaCadEnt = sumaCadEnt + cadEnt
				-- "Peor" es el que MAS se aleja de los 90 esperados.
				if not peorCadEnt or math.abs( cadEnt - 90 ) > math.abs( peorCadEnt - 90 ) then
					peorCadEnt = cadEnt
				end
			end

			-- 0,4 u por muestra a 0,05 s son 8 u/s: por debajo de eso el delta es
			-- ruido de interpolacion y no marcha.
			if marcha and marcha:Length2D() > 0.4 then
				local a1 = angHoriz( caderas, marcha )
				local a2 = angHoriz( frente, marcha )

				if a1 and a2 then
					movidas = movidas + 1
					sumaCadMar = sumaCadMar + a1
					sumaEntMar = sumaEntMar + a2

					if not peorCadMar or math.abs( a1 - 90 ) > math.abs( peorCadMar - 90 ) then
						peorCadMar = a1
					end
					if not peorEntMar or a2 > peorEntMar then peorEntMar = a2 end
				end
			end
		end

		if n < MUESTRAS_FACING then return end

		print( string.format( "[ph_facing] %d muestras: %d con el bot en marcha, %d sin lectura " ..
			"de hueso.", n, movidas, sinLectura ) )

		-- ⚠ EL UMBRAL ES **CUALQUIERA**, no "todas". Una ventana con la mitad de
		-- las muestras sin leer no promedia nada util, y la r20 mostro que el
		-- caso degenerado no viene solo: viene con numeros plausibles al lado.
		if sinLectura > 0 then
			print( "[ph_facing] >> SIN CORRER: " .. sinLectura .. " de " .. n .. " muestras no " ..
				"dieron una pose leible ( matriz ausente, o los huesos de cadera a menos de 1 u " ..
				"uno del otro, que es geometria imposible )." )
			print( "[ph_facing] >> No se emite ningun numero: un vector nulo da acos(0) = 90 " ..
				"grados, que es exactamente el valor SANO. Ese verde ya se imprimio una vez." )
			return
		end

		-- LA POSE, que se mide siempre (no necesita que camine). Los `or -1` de
		-- antes eran centinelas impresos en columnas de grados y de unidades: con
		-- la guarda de arriba no pueden llegar, y si llegaran ahora es un bug.
		print( string.format( "[ph_facing]   brazo izq, MAXIMO de la ventana  %5.1f gr de la " ..
			"vertical   ( la pose de reposo del .smd da %.1f )", brazoMax, REPOSO_BRAZO ) )
		print( string.format( "[ph_facing]   manos, separacion MAXIMA         %5.2f u" ..
			"                 ( la pose de reposo da %.2f )", manosMax, REPOSO_MANOS ) )

		local pareceReposo = manosMax > REPOSO_MANOS * 0.9
		if pareceReposo then
			print( "[ph_facing]   >> ⚠ LAS MANOS LLEGARON A LA SEPARACION DE LA POSE DE REPOSO. " ..
				"Eso es la pose T MEDIDA, no una impresion." )
		end

		if nCadEnt == 0 then
			print( "[ph_facing] >> SIN CORRER: no se pudo medir el eje de caderas contra la " ..
				"orientacion en ninguna muestra." )
			return
		end

		local mediaCadEnt = sumaCadEnt / nCadEnt
		print( string.format( "[ph_facing]   caderas vs ORIENTACION   media %5.1f gr   peor %5.1f " ..
			"gr   ( esperado 90 animado / 180 en reposo )", mediaCadEnt, peorCadEnt ) )

		local cadEntMal = nCadEnt > 0 and math.abs( mediaCadEnt - 90 ) > 30

		--[[
			⚠ LA FIRMA DE LA POSE DE REPOSO, Y VA ANTES QUE TODO LO DEMAS.

			Caderas PARALELAS al frente ( ~0 o ~180 en vez de 90 ) mas las manos a
			la separacion del reposo son, las dos juntas, el cuerpo dibujado sin
			animacion encima -- que se ve girado 90 grados Y en pose T a la vez.

			Va aca arriba, ANTES de la guarda de `movidas`, porque **esta firma no
			necesita que el bot camine**: se lee de la pose sola. Estaba abajo y la
			ventana con el bot quieto -- que es justo cuando el autor lo mira con
			el physgun en la mano -- salia por el `return` de arriba sin decirlo.
		]]
		if cadEntMal and pareceReposo then
			print( "[ph_facing] >> ⭐ EL CUERPO ESTA DIBUJADO EN LA POSE DE REPOSO. Las caderas van " ..
				"PARALELAS al frente ( reposo ) en vez de perpendiculares ( animado ), y las manos " ..
				"estan a la separacion del reposo." )
			print( "[ph_facing] >> Eso es 'corre de lado' y 'queda en T' AL MISMO TIEMPO, y es UN " ..
				"solo defecto: no hay animacion aplicandose sobre el cuerpo." )
			return

		end

		if movidas == 0 then
			print( "[ph_facing] >> SIN CORRER las dos filas de la MARCHA: el bot no se movio en " ..
				"toda la ventana. La pose si se midio; la orientacion contra el andar no." )
			return
		end

		local cadMar, entMar = sumaCadMar / movidas, sumaEntMar / movidas
		print( string.format( "[ph_facing]   caderas vs MARCHA        media %5.1f gr   peor %5.1f " ..
			"gr   ( esperado 90 )", cadMar, peorCadMar ) )
		print( string.format( "[ph_facing]   orientacion vs MARCHA    media %5.1f gr   peor %5.1f " ..
			"gr   ( esperado 0 )", entMar, peorEntMar ) )

		-- EL VEREDICTO NOMBRA, y para eso están las tres. Los cortes son anchos a
		-- propósito: lo que separa "de frente" de "de costado" son 90 grados, no
		-- 10, y un corte fino sólo agregaría zona gris donde no hay duda.
		local cadMarMal = math.abs( cadMar - 90 ) > 30
		local entMarMal = entMar > 30

		if not cadMarMal and not cadEntMal and not entMarMal then
			print( "[ph_facing] >> el cuerpo va de frente: caderas perpendiculares a la marcha y " ..
				"a la orientacion, y la entidad avanza hacia donde mira." )
			print( "[ph_facing] >> Si en esta ventana se vio correr de lado, NO es la orientacion " ..
				"del cuerpo: hay que buscar en la MALLA ( skin ) o en cómo se dibuja." )

		elseif cadMarMal and cadEntMal and not entMarMal then
			print( "[ph_facing] >> ⚠ EL CUERPO DIBUJADO ESTA GIRADO RESPECTO DE SU PROPIA ENTIDAD. " ..
				"La entidad avanza hacia donde mira, y el cuerpo no la acompana: es el MODELO " ..
				"o la animacion, no la IA." )

		elseif cadMarMal and not cadEntMal then
			print( "[ph_facing] >> ⚠ LA ENTIDAD SE MUEVE DE COSTADO. El cuerpo esta bien puesto " ..
				"sobre su entidad; la que va de lado es la entidad: eso es la IA / el pathing, " ..
				"y la animacion correcta seria una lateral." )

		else
			print( "[ph_facing] >> ⚠ MEZCLA: caderas-marcha " .. math.Round( cadMar ) ..
				", caderas-orientacion " .. math.Round( nCadEnt > 0 and sumaCadEnt / nCadEnt or -1 ) ..
				", orientacion-marcha " .. math.Round( entMar ) ..
				". Anotar los tres: la combinacion es la que nombra al culpable." )

		end
	end )
end

concommand.Add( "ph_ghost_facing", cmd_facing, nil,
	"Mide, EN LOS HUESOS, hacia donde apunta el cuerpo del fantasma mientras se mueve." )

--------------------------------------------------------- quien contesta m_anm

--[[
	ph_ghost_anm   -- QUE archivo esta sirviendo `models/m_anm.mdl`

	⚠ EL DATO QUE ABRE ESTO ESTUVO IMPRESO TRES RONDAS Y NADIE LO COMPARO.

	`phantasmagoria_ghost_acts` informa las secuencias visibles, que con el
	`$includemodel` resuelto son las nuestras MAS las del m_anm que el motor
	sirva. Los tres valores medidos:

	    r18   2171
	    r19   1725      <- 446 menos
	    r20   1725

	La fila de la r19 pedia literalmente `secuencias visibles: 2171` en su
	criterio, salio 1725, y se marco PASA porque la otra mitad de la linea
	--el 8/8-- estaba bien. *Un criterio con dos condiciones se cumple a medias y
	se lee como cumplido.*

	Y 446 secuencias de diferencia no es ruido: es OTRO archivo. Hay al menos dos
	`models/m_anm.mdl` en el arbol, medidos fuera del juego:

	    HL2, con el que se portaron las animaciones   1563 secuencias, 56 huesos
	    WOS DynaBase                                     1 secuencia,  60 huesos

	El de WOS pesa 24 KB, declara una sola secuencia llamada
	`a_dynamic_wiltos_enabled` y tiene **cuatro huesos mas**. El nuestro declara
	43. Ninguna suma da 2171 ni 1725, asi que el que gana es un TERCERO --
	seguramente el de un juego montado-- y **cambio entre la r18 y la r19**.

	El autor lo dijo primero, y desde el juego: *«el terminator usa las
	animaciones del playermodel, porque tengo animaciones de counter-strike del
	mod WOS que permite cambiar las animaciones del jugador»*.

	Esto no adivina: pide el modelo al motor y lo mide. La identidad se lee en
	runtime, no se recuerda -- un numero esperado escrito a mano envejece, y en
	este arco ya hizo anunciar un problema de montaje que no existia.
]]

local ANM = "models/m_anm.mdl"

local function huella( mdl )
	if not file.Exists( mdl, "GAME" ) then
		return nil, "file.Exists dice que no esta montado"
	end

	-- Un ClientsideModel es la unica forma de preguntarle al motor por las
	-- secuencias de un modelo que no tiene entidad. Y ojo: con una ruta no
	-- montada NO falla, devuelve el modelo de ERROR -- por eso la ruta se
	-- comprueba antes y el resultado se contrasta con el nombre que devuelve.
	local e = ClientsideModel( mdl, RENDERGROUP_OPAQUE )
	if not IsValid( e ) then return nil, "ClientsideModel no lo pudo crear" end

	e:SetNoDraw( true )

	local out = {
		modelo = tostring( e:GetModel() ),
		seqs = e:GetSequenceCount(),
		huesos = e:GetBoneCount(),
		poses = e:GetNumPoseParameters(),
		primera = tostring( e:GetSequenceName( 0 ) ),
	}

	-- Los nombres de las primeras secuencias son lo que delata de que juego es.
	local nombres = {}
	for i = 0, math.min( 5, out.seqs - 1 ) do
		nombres[ #nombres + 1 ] = tostring( e:GetSequenceName( i ) )
	end
	out.nombres = nombres

	e:Remove()

	return out
end

local function cmd_anm()
	print( "[ph_anm] QUIEN contesta " .. ANM .. ", medido en runtime." )

	local anm, err = huella( ANM )
	if not anm then
		print( "[ph_anm] >> " .. ANM .. " NO SE PUDO MEDIR: " .. err )
		print( "[ph_anm] >> Si no esta montado, nuestro $includemodel no resuelve y el fantasma " ..
			"solo tiene sus 43 secuencias propias." )
		return
	end

	print( string.format( "[ph_anm]   %-42s %5d secuencias   %d huesos   %d pose params",
		anm.modelo, anm.seqs, anm.huesos, anm.poses ) )
	print( "[ph_anm]     primeras: " .. table.concat( anm.nombres, ", " ) )

	-- ⚠ EL DISCRIMINANTE ES EL NOMBRE DE LA PRIMERA SECUENCIA, no el conteo. El
	-- de WOS declara UNA sola y se llama `a_dynamic_wiltos_enabled`: eso no se
	-- confunde con nada, y no depende de que addons haya montados hoy.
	if string.find( anm.primera, "wiltos", 1, true ) or string.find( anm.primera, "dynamic", 1, true ) then
		print( "[ph_anm] >> ⚠ EL QUE GANA ES EL DE WOS DYNABASE ( '" .. anm.primera .. "' ). " ..
			"Nuestras animaciones se portaron contra el m_anm de HL2, que declara 1563 " ..
			"secuencias y 56 huesos; este declara " .. anm.seqs .. " y " .. anm.huesos .. "." )
		print( "[ph_anm] >> Dos addons montando la MISMA ruta. El $includemodel resuelve contra " ..
			"este, y el merge del esqueleto es POR NOMBRE DE HUESO." )

	elseif anm.huesos ~= 56 then
		print( "[ph_anm] >> ⚠ NO ES EL m_anm CONTRA EL QUE SE PORTO: ese tiene 56 huesos y este " ..
			"tiene " .. anm.huesos .. ". Es otro archivo en la misma ruta." )

	else
		print( "[ph_anm] >> los 56 huesos coinciden con el m_anm de HL2, el que se uso para " ..
			"portar las 39 animaciones." )

	end

	-- Y el fantasma al lado, que es donde se ve la suma.
	local sujeto = elegirSujeto()
	if not sujeto then
		print( "[ph_anm]   ( sin fantasma en el mapa no se puede ver la SUMA; spawnear uno )" )
		return
	end

	local total = sujeto:GetSequenceCount()
	print( string.format( "[ph_anm]   el fantasma declara %d secuencias visibles", total ) )
	print( string.format( "[ph_anm]     43 propias + %d de %s = %d",
		anm.seqs, anm.modelo, 43 + anm.seqs ) )

	-- LA RESTA SE HACE ACA. Un criterio que exige restar a mano invita a un
	-- veredicto inferido, y ademas esta resta es la que nadie hizo tres rondas.
	if total ~= 43 + anm.seqs then
		print( string.format( "[ph_anm] >> ⚠ LA SUMA NO CIERRA: el fantasma ve %d y el m_anm que " ..
			"mide este comando aporta %d. Sobran %d.", total, anm.seqs, total - 43 - anm.seqs ) )
		print( "[ph_anm] >> O sea que hay MAS de un modelo aportando secuencias, o el que se " ..
			"midio aca no es el que el fantasma resolvio al compilar/montar." )

	else
		print( "[ph_anm] >> la suma cierra: el fantasma esta viendo exactamente este m_anm." )

	end

	print( "[ph_anm]   ( medido fuera del juego: HL2 1563 seq / 56 huesos · WOS 1 seq / 60 " ..
		"huesos · nuestro 43 )" )
end

concommand.Add( "ph_ghost_anm", cmd_anm, nil,
	"Mide QUE archivo esta sirviendo models/m_anm.mdl y si la suma de secuencias cierra." )

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
