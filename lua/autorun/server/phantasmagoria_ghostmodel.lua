--[[
	Probar EN JUEGO el primer fantasma con esqueleto ValveBiped y ragdoll.

	    ph_ghost_ragdoll     spawnea el ragdoll y MIDE solidos, masas y huesos
	    ph_ghost_anim [seq]  spawnea animado y MIDE si el $includemodel entro
	    ph_ghost_clear       borra lo que spawnearon los dos

	QUE MIDE CADA UNO, Y POR QUE ESO Y NO MIRARLO

	Las cuatro cosas que pueden salir mal en este modelo COMPILAN LIMPIO y no
	dan error en juego. Cada una tiene aca el numero que la separa de su
	sintoma:

	  - el ragdoll quedo como UNA sola piedra con forma de nena, en vez de 15
	    solidos articulados. Se ve como un cuerpo rigido que cae de una pieza,
	    que a ojo se confunde con "un ragdoll duro". El numero es
	    GetPhysicsObjectCount(): tiene que dar 15, no 1.

	  - los $jointconstrain nombraron huesos que el modelo no tiene y se
	    ignoraron en silencio. El ragdoll existe pero se dobla para cualquier
	    lado. No se puede medir el limite desde Lua, pero si el hueso: si
	    LookupBone() encuentra los 15, ningun constrain apunto al vacio.

	  - el $includemodel no entro (basta un "models/" de mas en la ruta, que es
	    lo que paso la primera vez). El modelo se ve perfecto y no se mueve.
	    El numero es GetSequenceCount(): con m_anm son ~465, sin el 1.

	  - la masa quedo en el default de studiomdl. Un ragdoll de 15 kg y uno de
	    30 caen parecido y no se distinguen a ojo. El numero es la suma de
	    GetMass() de los 15 solidos.

	OJO CON LA CONSOLA: PrintMessage( HUD_PRINTCONSOLE ) tiene techo de 255
	bytes y NO trunca, DESCARTA la linea entera. Por eso todo sale por print()
	del servidor y en lineas cortas.
]]

--[[
	CUAL DE LOS TRES SE SPAWNEA. Hasta el 2026-08-10 esto era una constante con
	la nena adentro, y con ella la masa esperada y los cinco largos de hueso:
	los tres comandos de este archivo solo sabian medir un modelo.

	La convar elige, y el DEFAULT ES LA NENA a proposito -- es la unica de las
	tres con una pasada en juego cerrada, asi que una corrida vieja de la
	planilla sigue midiendo lo mismo que medía. Con un valor que no este en el
	registro se avisa y se cae a la nena, en vez de spawnear nil.
]]
local cvModelo = CreateConVar( "ph_ghost_modelo", "ghost_girl", FCVAR_ARCHIVE,
	"Cual de los fantasmas portados spawnean los comandos ph_ghost_* " ..
	"( ghost_girl, ghost_male, ghost_oldcrone )" )

local function ficha()
	local corto = cvModelo:GetString()
	local ruta = "models/phantasmagoria/" .. corto .. ".mdl"
	local f = PHANTASMAGORIA.GhostModelPorRuta[ ruta ]

	if not f then
		print( "[ph_ghost] ph_ghost_modelo = " .. tostring( corto ) ..
			" no esta en ghost_models.lua; se usa ghost_girl." )
		return PHANTASMAGORIA.GhostModelPorRuta[ "models/phantasmagoria/ghost_girl.mdl" ]
	end

	return f
end

-- Los 15 huesos del ragdoll, que son los del ciudadano de HL2. Escritos aca
-- para que el chequeo sea INDEPENDIENTE del .qci que los genero: si los dos
-- salieran de la misma fuente, esto no podria ver que esa fuente esta mal.
local HUESOS_RAGDOLL = {
	"ValveBiped.Bip01_Pelvis",
	"ValveBiped.Bip01_Spine2",
	"ValveBiped.Bip01_Head1",
	"ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand",
	"ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand",
	"ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_L_Foot",
	"ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Foot",
}

-- Lo que el .phy compilado dice que tiene que dar. Sale de phyread.py sobre el
-- .phy YA COMPILADO, no del QC: es el archivo que el motor va a leer.
local SOLIDOS_ESPERADOS = 15
-- OJO: NO son los 30,73 que pide el $mass del .qci. studiomdl reparte la masa
-- por volumen pero no baja de 1 kg por solido, y este fantasma mide 1,14 m:
-- 10 de sus 15 solidos caen abajo del piso y suben a 1,0. El ciudadano de HL2
-- no tiene ni uno --su solido mas chico da 1,019 kg-- asi que el efecto no se
-- ve en el modelo del que salieron los numeros. Este valor sale de la cuenta
-- que hace smdragdoll.py, no de mirar el .phy compilado.
-- ⚠ ERA UNA CONSTANTE CON EL NUMERO DE LA NENA. Sale del registro, que trae la
-- masa REAL del .phy de cada modelo ( 36.58 / 58.04 / 54.02 ), no el $mass del
-- .qci: studiomdl no baja de 1 kg por solido y los dos numeros difieren.
local function masaEsperada()
	return ficha().masa or 0
end

local spawneados = {}

local function agregar( e )
	spawneados[ #spawneados + 1 ] = e
	return e
end

local function donde( ply )
	if IsValid( ply ) then
		local tr = ply:GetEyeTrace()
		return tr.HitPos + tr.HitNormal * 8
	end
	-- Desde la consola del servidor no hay jugador. Sin este caso el comando
	-- revienta indexando nil, que se lee como si el comando no existiera.
	return Vector( 0, 0, 64 )
end

local function existe()
	local m = ficha().mdl
	if util.IsValidModel( m ) then return true end
	print( "[ph_ghost] " .. m .. " NO esta montado." )
	print( "[ph_ghost] el addon no tiene el modelo, o el .mdl no compilo." )
	return false
end

--------------------------------------------------------------------- ragdoll

local function cmd_ragdoll( ply )
	if not existe() then return end

	local e = agregar( ents.Create( "prop_ragdoll" ) )
	e:SetModel( ficha().mdl )
	e:SetPos( donde( ply ) )
	e:Spawn()
	e:Activate()

	local n = e:GetPhysicsObjectCount()
	print( "[ph_ghost] ---- RAGDOLL ----" )

	-- QUE ARCHIVO ESTA VIENDO GMOD. La corrida 2 devolvio los solidos en el
	-- orden de models/player/corpse1.phy y con volumen 6788, cuando el .phy
	-- que hay en disco tiene otro orden y volumen 2278. O sea que el motor NO
	-- estaba leyendo nuestro archivo -- y con la masa sola eso era
	-- indistinguible de "la masa esta mal". file.Size resuelve por el orden de
	-- montaje, asi que dice cual gana, no cual escribi yo.
	print( "[ph_ghost] modelo de la entidad : " .. tostring( e:GetModel() ) )
	local base = string.sub( ficha().mdl, 1, -5 )
	for _, f in ipairs( { base .. ".mdl", base .. ".phy" } ) do
		print( string.format( "[ph_ghost] %s  %s bytes", f,
			tostring( file.Size( f, "GAME" ) ) ) )
	end
	-- SIN el tamano "en disco" escrito a mano. Lo tuve hardcodeado con el valor
	-- de una compilacion vieja y me hizo anunciar un problema de montaje que no
	-- existia: el numero no coincidia porque el numero estaba viejo, no porque
	-- GMod leyera otro archivo. Un valor esperado que no se vuelve a medir
	-- envejece y miente igual que una medicion mal hecha.

	-- LA MEDICION AHORA VA DOS VECES, y esa es la que decide.
	-- Este fantasma tiene nombres ValveBiped, o sea que cualquier addon que se
	-- enganche de esos nombres lo adopta: artagdoll, por ejemplo, tiene una
	-- tabla de masas indexada por "ValveBiped.Bip01_*" y se la escribe a
	-- cualquier ragdoll que los tenga. Si los numeros CAMBIAN entre el instante
	-- del Spawn y medio segundo despues, lo que hay es un tercero escribiendo
	-- encima -- y eso no se puede distinguir de "el .phy esta mal" con una sola
	-- lectura.
	local function foto( ent )
		local m, v, n2 = 0, 0, ent:GetPhysicsObjectCount()
		for i = 0, n2 - 1 do
			local p = ent:GetPhysicsObjectNum( i )
			if IsValid( p ) then
				m = m + p:GetMass()
				v = v + ( p:GetVolume() or 0 )
			end
		end
		return m, v
	end
	local m0, v0 = foto( e )
	print( string.format( "[ph_ghost] AL SPAWNEAR   masa %.2f  volumen %.2f", m0, v0 ) )
	timer.Simple( 0.5, function()
		if not IsValid( e ) then return end
		local m1, v1 = foto( e )
		print( string.format( "[ph_ghost] A LOS 0.5 s   masa %.2f  volumen %.2f", m1, v1 ) )
		if math.abs( m1 - m0 ) > 0.01 or math.abs( v1 - v0 ) > 0.01 then
			print( "[ph_ghost] >> CAMBIARON: hay un TERCERO escribiendo sobre el ragdoll." )
			print( "[ph_ghost] >> Probar de nuevo con artagdoll y zippy gore desactivados." )
		else
			print( "[ph_ghost] >> no cambiaron: lo que se lee es lo que trae el .phy." )
		end
	end )
	print( string.format( "[ph_ghost] solidos: %d  (esperado %d)  %s",
		n, SOLIDOS_ESPERADOS,
		n == SOLIDOS_ESPERADOS and "OK" or "FALLA" ) )
	if n <= 1 then
		print( "[ph_ghost] con 1 solido el .phy no trae $collisionjoints:" )
		print( "[ph_ghost] es un cuerpo rigido, no un ragdoll." )
	end

	local total = 0
	for i = 0, n - 1 do
		local p = e:GetPhysicsObjectNum( i )
		if IsValid( p ) then total = total + p:GetMass() end
	end
	print( string.format( "[ph_ghost] masa total: %.2f kg  (esperado %.2f)  %s",
		total, masaEsperada(),
		math.abs( total - masaEsperada() ) < 0.5 and "OK" or "FALLA" ) )

	-- Si la masa total no da, el total no dice DONDE. La corrida 1 dio 85,19
	-- contra los 36,57 que tiene el .phy, y con un solo numero no se puede
	-- saber si el motor ignoro las masas del archivo, si las escalo, o si el
	-- juego cargo OTRO archivo. El VOLUMEN lo separa: sale del mismo .phy y el
	-- motor no lo recalcula, asi que si los volumenes coinciden con los del
	-- archivo, es el archivo correcto y lo que cambia es solo la masa.
	if math.abs( total - masaEsperada() ) >= 0.5 then
		print( "[ph_ghost] --- desglose (masa y volumen por solido) ---" )
		local vt = 0
		for i = 0, n - 1 do
			local p = e:GetPhysicsObjectNum( i )
			if IsValid( p ) then
				local b = e:TranslatePhysBoneToBone( i )
				local v = p:GetVolume() or -1
				vt = vt + ( v > 0 and v or 0 )
				print( string.format( "[ph_ghost]   %2d %-30s masa %7.3f  vol %9.2f",
					i, tostring( e:GetBoneName( b ) ), p:GetMass(), v ) )
			end
		end
		-- ⚠ EL 2278.19 ESTABA CLAVADO Y ES EL DE LA NENA. Sobre el Male
		-- (4170.73) y la OldCrone (64424.50) esta linea --que es LA QUE
		-- SEPARA las causas-- comparaba contra el archivo de otro modelo.
		local vEsp = ficha().volumen or 0
		print( string.format(
			"[ph_ghost]   volumen total %.2f  (nuestro .phy dice %.2f)  %s",
			vt, vEsp,
			math.abs( vt - vEsp ) < 1 and "COINCIDE: es nuestra colision"
			or "NO COINCIDE: el motor esta sirviendo OTRA colision" ) )

		-- EL TERCERO. Si el ciudadano de HL2 devuelve los MISMOS numeros que
		-- el fantasma, el motor esta sirviendo la misma colision para los dos
		-- y el problema es de montaje, no del archivo que compilamos. Si
		-- devuelve los suyos, entonces los numeros del fantasma son de verdad
		-- suyos y lo que hay que revisar es otra cosa.
		local c = ents.Create( "prop_ragdoll" )
		c:SetModel( "models/player/corpse1.mdl" )
		c:SetPos( e:GetPos() + Vector( 0, 48, 0 ) )
		c:Spawn()
		agregar( c )
		local cn, cv = c:GetPhysicsObjectCount(), 0
		for i = 0, cn - 1 do
			local p = c:GetPhysicsObjectNum( i )
			if IsValid( p ) then cv = cv + ( p:GetVolume() or 0 ) end
		end
		print( string.format(
			"[ph_ghost]   CONTROL corpse1.mdl: %d solidos, volumen %.2f  (su .phy dice 6664.74)",
			cn, cv ) )
		print( "[ph_ghost]   si este volumen es IGUAL al del fantasma, el motor sirve la misma colision" )
	end

	-- Los huesos que los $jointconstrain nombran tienen que existir. Un
	-- constrain sobre un hueso ausente se ignora sin avisar.
	local faltan = {}
	for _, h in ipairs( HUESOS_RAGDOLL ) do
		if not e:LookupBone( h ) then faltan[ #faltan + 1 ] = h end
	end
	print( string.format( "[ph_ghost] huesos de ragdoll presentes: %d/%d  %s",
		#HUESOS_RAGDOLL - #faltan, #HUESOS_RAGDOLL,
		#faltan == 0 and "OK" or "FALLA" ) )
	for _, h in ipairs( faltan ) do print( "[ph_ghost]   falta " .. h ) end

	-- Un ragdoll que nace dormido no cae, y eso se lee igual que uno trabado.
	local p = e:GetPhysicsObjectNum( 0 )
	if IsValid( p ) then
		p:Wake()
		print( "[ph_ghost] solido 0 despertado; tiene que caer y doblarse." )
	end
end

------------------------------------------------------------------- animacion

local function cmd_anim( ply, _, args )
	if not existe() then return end
	-- menu_walk y NO walk_all. Medido en m_anm.mdl: `walk_all` mezcla NUEVE
	-- animaciones gobernadas por los pose parameters move_x/move_y, asi que sin
	-- ellos se queda en el centro de la mezcla -- que es estar parado. El ciclo
	-- avanza igual y LookupSequence lo encuentra, o sea que los tres numeros
	-- del check dan OK mientras el modelo no se mueve. `menu_walk` es UNA sola
	-- animacion y no depende de ningun pose parameter.
	local seq = args[ 1 ] or "menu_walk"

	local e = agregar( ents.Create( "prop_dynamic" ) )
	e:SetModel( ficha().mdl )
	e:SetPos( donde( ply ) )
	-- La keyvalue DefaultAnim es lo que hace que CDynamicProp instale su
	-- AnimThink: sin ella el servidor no avanza el ciclo. Ya costo una ronda.
	e:SetKeyValue( "DefaultAnim", seq )
	e:Spawn()
	e:Activate()

	local n = e:GetSequenceCount()
	print( "[ph_ghost] ---- ANIMACION ----" )
	print( string.format( "[ph_ghost] secuencias: %d  %s", n,
		n > 100 and "OK ($includemodel entro)" or "FALLA (m_anm no entro)" ) )

	local i = e:LookupSequence( seq )
	print( string.format( "[ph_ghost] LookupSequence(%q) = %s  %s",
		seq, tostring( i ), ( i and i >= 0 ) and "OK" or "FALLA" ) )
	if not i or i < 0 then return end

	-- ESTIRA O NO ESTIRA -- LOS PARES SON PADRE E HIJO DIRECTO.
	--
	-- La version anterior media Pelvis->Head1, Pelvis->L_Foot y
	-- L_UpperArm->L_Hand y declaraba que eso era invariante. NO LO ES: esas
	-- tres distancias cruzan articulaciones, y en una caminata el codo, la
	-- rodilla y la columna se doblan, asi que las tres TIENEN que achicarse.
	-- Dieron x0.657, x0.671 y x0.547 y el check anuncio "SE ESTIRA 45 %"
	-- sobre una pose flexionada perfectamente normal. Lo invariante bajo una
	-- rotacion es la distancia de un hueso a su PADRE DIRECTO: eso es el largo
	-- del hueso y ninguna rotacion lo cambia.
	--
	-- Que la animacion es de rotacion pura esta medido en m_anm.mdl: de los 53
	-- huesos de `menu_walk`, los 53 traen rotacion y UNO SOLO trae posicion
	-- (el Pelvis, que es la raiz y lleva el desplazamiento del paso).
	-- El tercer numero es el largo que declara el .mdl COMPILADO, leido con
	-- mdl2smd.read_bones. Es la segunda referencia y la que decide de verdad:
	-- comparar cuadro0 contra 0.5 s dice si algo escala DURANTE la animacion,
	-- pero si el modelo ya entra escalado los dos cuadros coinciden y el check
	-- no ve nada. Contra el archivo si se ve.
	-- Para dimensionar: el ciudadano de HL2 tiene el brazo de ~11 u y la nena
	-- de 6.70, o sea que un valor citizen aca salta a la vista.
	-- ⚠ ERAN LOS CINCO LARGOS DE LA NENA, ESCRITOS ACA. Salen del registro
	-- ( lua/phantasmagoria/ghost_models.lua ) porque son distintos por modelo:
	-- el muslo mide 9.72 en la nena, 20.45 en el Male y 12.77 en la OldCrone.
	local f = ficha()
	local PARES = {}

	for k, par in ipairs( PHANTASMAGORIA.ParesHueso ) do
		PARES[ k ] = { par[ 1 ], par[ 2 ], f.nuestro[ k ] }

	end
	local function distancias( ent )
		-- SIN SetupBones() ni InvalidateBoneCache(): las dos son de CLIENTE y
		-- en servidor salen nil. Llamarlas tira un error por medicion y no
		-- aporta nada; GetBonePosition contesta igual.
		local out = {}
		for k, par in ipairs( PARES ) do
			local a, b = ent:LookupBone( par[ 1 ] ), ent:LookupBone( par[ 2 ] )
			if a and b then
				local pa = ent:GetBonePosition( a )
				local pb = ent:GetBonePosition( b )
				out[ k ] = ( pa and pb ) and pa:Distance( pb ) or -1
			else
				out[ k ] = -1
			end
		end
		return out
	end

	-- EL REPOSO SE MIDE PRIMERO, Y DESPUES SE PONE LA SECUENCIA.
	-- Al reves --que es como estaba-- el ResetSequence del reposo pisaba a la
	-- secuencia pedida y el prop se quedaba en `idle`: el comando dejaba de
	-- hacer lo unico que tenia que hacer, y eso se leyo en juego como "el
	-- modelo no se anima".
	local d0 = distancias( e )

	e:ResetSequence( i )
	e:SetCycle( 0 )
	e:SetPlaybackRate( 1 )

	-- Una secuencia de mezcla sin pose parameters se ve QUIETA. Se ponen los de
	-- movimiento hacia adelante y se avisa cuales tiene el modelo, para que
	-- "no se mueve" no se lea como "el retargeting esta mal".
	local np = e:GetNumPoseParameters()
	local nombres = {}
	for k = 0, np - 1 do nombres[ #nombres + 1 ] = e:GetPoseParameterName( k ) end
	print( string.format( "[ph_ghost] pose parameters: %d  (%s)", np,
		table.concat( nombres, ", " ) ) )
	e:SetPoseParameter( "move_x", 1 )
	e:SetPoseParameter( "move_y", 0 )
	print( "[ph_ghost] move_x=1 puesto (walk_all mezcla 9 animaciones; menu_walk es una sola)." )
	timer.Simple( 0.5, function()
		if not IsValid( e ) then return end
		local c = e:GetCycle()
		print( string.format( "[ph_ghost] ciclo a los 0.5 s: %.3f  %s", c,
			c > 0.001 and "OK (avanza)" or "FALLA (no avanza)" ) )

		local d1 = distancias( e )
		local peor, malos = 0, 0
		print( "[ph_ghost] --- LARGO DE HUESO (padre -> hijo directo) ---" )
		for k, par in ipairs( PARES ) do
			local etiqueta = par[ 1 ]:sub( 17 ) .. "->" .. par[ 2 ]:sub( 17 )
			if d0[ k ] <= 0 or d1[ k ] <= 0 then
				print( string.format( "[ph_ghost] %-26s SIN LEER (hueso ausente)", etiqueta ) )
				malos = malos + 1
			else
				local rel = d1[ k ] / d0[ k ]
				peor = math.max( peor, math.abs( rel - 1 ) )
				-- Las dos lecturas son de la MISMA animacion en dos cuadros
				-- distintos, no "reposo" contra "animado": el largo de un
				-- hueso no depende de la pose, asi que comparar dos cuadros
				-- cualesquiera ya contesta si algo escala.
				local esperado = par[ 3 ]
				local vs = esperado and string.format( "  .mdl %5.2f  x%.2f",
					esperado, d1[ k ] / esperado ) or ""
				print( string.format( "[ph_ghost] %-26s cuadro0 %6.2f  0.5s %6.2f  x%.3f%s",
					etiqueta, d0[ k ], d1[ k ], rel, vs ) )
				if esperado then
					peor = math.max( peor, math.abs( d1[ k ] / esperado - 1 ) )
				end
			end
		end
		if malos > 0 then
			print( "[ph_ghost] >> faltan lecturas: el veredicto no se emite." )
		elseif peor < 0.02 then
			print( "[ph_ghost] >> NO se estira: los largos de hueso se conservan." )
			print( "[ph_ghost] >> Lo que se ve raro es la POSE, no el tamano del modelo." )
		else
			print( string.format( "[ph_ghost] >> SE ESTIRA hasta un %.0f %%. Un largo de hueso "
				.. "NO cambia con una rotacion.", peor * 100 ) )
		end
	end )
end

--------------------------------------------------------------------- limpiar

local function cmd_clear()
	local n = 0
	for _, e in ipairs( spawneados ) do
		if IsValid( e ) then e:Remove() n = n + 1 end
	end
	spawneados = {}
	print( "[ph_ghost] borradas " .. n .. " entidades." )
end

--------------------------------------------------------------------- comandos

-- Una ConVar y un ConCommand no pueden compartir nombre, y el que queda
-- inalcanzable es el COMANDO, en silencio. Ya paso en este addon y costo una
-- ronda entera de mediciones que no midieron nada.
local function agregarComando( nombre, fn, ayuda )
	if ConVarExists( nombre ) then
		ErrorNoHalt( "[ph_ghost] COLISION: '" .. nombre .. "' ya existe como CONVAR; " ..
			"el comando homonimo queda inalcanzable. Renombrar uno de los dos.\n" )
		return false
	end
	concommand.Add( nombre, fn, nil, ayuda )
	return true
end

-- EL CONTROL QUE AISLA UNA SOLA VARIABLE.
-- ghost_girl_noinc.mdl sale de la MISMA malla, el MISMO esqueleto y el MISMO
-- SMD que ghost_girl.mdl; lo unico que le falta es el `$includemodel` (y la
-- capa de proporciones). Los dos .mdl declaran L_Thigh->L_Calf = 9.72.
-- Si en juego el normal mide 17.85 y este 9.72, el que cambia la tabla de
-- huesos es el $includemodel y no hay mas que discutir. Si los DOS miden
-- 17.85, el culpable es otro y toda la teoria se cae.
local function cmd_control( ply )
	local m = "models/phantasmagoria/ghost_girl_noinc.mdl"
	if not util.IsValidModel( m ) then
		print( "[ph_ghost] " .. m .. " no esta montado." )
		return
	end
	local e = agregar( ents.Create( "prop_dynamic" ) )
	e:SetModel( m )
	e:SetPos( donde( ply ) + Vector( 0, 40, 0 ) )
	e:Spawn()
	e:Activate()
	print( "[ph_ghost] control spawneado: " .. m )
	print( string.format( "[ph_ghost] secuencias: %d  (sin $includemodel tiene que ser 1)",
		e:GetSequenceCount() ) )
	print( "[ph_ghost] ahora correr ph_ghost_bones: mide los dos juntos." )
end

--------------------------------------------------- el A/B CIEGO de la costura

--[[
	ph_ghost_ab [secuencia]   spawnea los dos y NO dice cual es cual
	ph_ghost_ab_revelar       recien ahi lo dice

	El sintoma que hay que juzgar es visual --"en un punto tambalea hacia
	adelante"-- y el juez es una persona que ya sabe que uno de los dos esta
	arreglado. Si el comando imprime cual es cual antes de mirar, lo que se
	mide deja de ser el modelo.

	`ghost_girl_seam.mdl` sale de la MISMA malla, el MISMO esqueleto y el MISMO
	.phy que el bueno: lo unico distinto son las dos secuencias, decodificadas
	a proposito con el lector roto de antes del 2026-08-07 (el que leia un
	short de mas en la rama de repeticion de la RLE). Los .vvd de los dos
	difieren en 4 bytes, que son el checksum.

	POR QUE HACE FALTA EL DE CONTROL: "no lo veo tambalear" no distingue *se
	arreglo* de *no lo estoy mirando bien*. Si el de control tampoco tambalea,
	el ojo no ve el defecto y el verde del otro no vale.
]]

local AB_MAPA = nil

local function cmd_ab( ply, _, args )
	local seq = args[ 1 ] or "walk_ours"
	local BUENO   = "models/phantasmagoria/ghost_girl.mdl"
	local CONTROL = "models/phantasmagoria/ghost_girl_seam.mdl"
	for _, m in ipairs( { BUENO, CONTROL } ) do
		-- La ruta va entera. util.IsValidModel no sirve de guarda: devuelve
		-- false sobre modelos que el motor si sirve.
		if not file.Exists( m, "GAME" ) then
			print( "[ph_ghost_ab] falta " .. m )
			-- EL CONTROL NEGATIVO NO ESTA, Y ESO ES LO NORMAL. Se borro al
			-- cerrar la ronda 2 (7/7): es un instrumento, no un asset, y no lo
			-- tiene que agarrar ningun NextBot. Sin decirlo, este mensaje se
			-- lee como una instalacion rota.
			print( "[ph_ghost_ab] ghost_girl_seam.mdl se BORRA al cerrar un bloque. "
				.. "Si hace falta otra vez: python dev/phastools/_seamctl.py y "
				.. "copiar los 5 archivos a models/phantasmagoria/." )
			return
		end
	end

	-- EL SORTEO. Sin esto el comando le dice al juez la respuesta.
	local invertir = math.random() < 0.5
	local izq = invertir and CONTROL or BUENO
	local der = invertir and BUENO or CONTROL
	AB_MAPA = { A = izq, B = der }

	local base = donde( ply )
	for etiqueta, datos in pairs( { A = { izq, -45 }, B = { der, 45 } } ) do
		local e = agregar( ents.Create( "prop_dynamic" ) )
		e:SetModel( datos[ 1 ] )
		e:SetPos( base + Vector( 0, datos[ 2 ], 0 ) )
		-- DefaultAnim es lo que instala el AnimThink de CDynamicProp; sin ella
		-- el servidor no avanza el ciclo y los dos se ven quietos, que es el
		-- unico resultado que este check no puede interpretar.
		e:SetKeyValue( "DefaultAnim", seq )
		e:Spawn()
		e:Activate()
		local i = e:LookupSequence( seq )
		print( string.format( "[ph_ghost_ab] %s en Y%+d   secuencias %d   "
			.. "LookupSequence(%q) = %s", etiqueta, datos[ 2 ],
			e:GetSequenceCount(), seq, tostring( i ) ) )
		if not i or i < 0 then
			print( "[ph_ghost_ab] >> ese modelo no tiene la secuencia: el A/B no vale." )
		end
	end
	print( "[ph_ghost_ab] A y B spawneados. NO se dice cual es cual." )
	print( "[ph_ghost_ab] Mirar 5 vueltas enteras de cada uno y decidir cual "
		.. "da un tiron hacia adelante." )
	print( "[ph_ghost_ab] Despues: ph_ghost_ab_revelar" )
end

local function cmd_ab_revelar()
	if not AB_MAPA then
		print( "[ph_ghost_ab] no hay ningun A/B corrido en esta sesion." )
		return
	end
	print( "[ph_ghost_ab] A (Y-45) = " .. AB_MAPA.A )
	print( "[ph_ghost_ab] B (Y+45) = " .. AB_MAPA.B )
	print( "[ph_ghost_ab] el que tiene que tambalear es ghost_girl_SEAM." )
end

agregarComando( "ph_ghost_ab", cmd_ab,
	"A/B ciego del tambaleo: spawnea el bueno y el de control sin decir cual es cual." )
agregarComando( "ph_ghost_ab_revelar", cmd_ab_revelar,
	"Dice cual era A y cual era B. Recien despues de mirar." )

agregarComando( "ph_ghost_control", cmd_control,
	"Spawnea el mismo modelo SIN $includemodel, para comparar." )
agregarComando( "ph_ghost_ragdoll", cmd_ragdoll,
	"Spawnea el ragdoll del fantasma y mide solidos, masa y huesos." )
agregarComando( "ph_ghost_anim", cmd_anim,
	"Spawnea el fantasma animado. Argumento: nombre de secuencia (walk_all por defecto)." )
agregarComando( "ph_ghost_clear", cmd_clear,
	"Borra lo que spawnearon ph_ghost_ragdoll y ph_ghost_anim." )
