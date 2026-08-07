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
