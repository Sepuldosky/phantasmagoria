--[[
	Probar EN JUEGO las secuencias de un modelo portado.

	    ph_seqs                   lista las secuencias del prop apuntado
	    ph_seq <nombre|indice>    le pone una al prop apuntado
	    ph_anim <modelo> [seq]    spawnea un prop_dynamic y le pone la secuencia
	    ph_anim_clear             borra lo que spawneo ph_anim

	POR QUE ES DEL LADO DEL SERVIDOR, y no como ph_bones

	`phantasmagoria_bones.lua` es de cliente a proposito: manipular un hueso es
	un efecto visual y alcanza con verlo en la propia pantalla. Una SECUENCIA no:
	la avanza el servidor y se replica, asi que un comando de cliente pondria la
	secuencia en una entidad que el servidor sigue considerando en la suya. Se
	veria mal y el motivo no estaria a la vista.

	Y POR QUE prop_dynamic Y NO prop_physics

	El `gm_spawn` del menu crea un `prop_physics`, que es fisica y NO avanza
	animacion. Con el modelo bien y la secuencia bien, el prop se queda quieto
	-- que se lee igual que "la animacion no se exporto". `prop_dynamic` es la
	clase que si la avanza.

	LO QUE NO SE DA POR SENTADO

	Que el servidor avance el ciclo solo. En vez de suponerlo, `ph_anim` lee el
	ciclo a los 0.5 s y AVISA si no se movio, con el comando para forzarlo a
	mano. Un prop quieto y un prop sin animacion se ven igual; el numero los
	separa.
]]

local spawneados = {}
local manuales = {}
local fases = {}       -- desfasaje por entidad, para que no marchen todos juntos

local function apuntado(ply)
	-- Desde la consola del servidor no hay jugador. Sin este caso el comando
	-- revienta con un error de indexar nil, que se lee como si el comando no
	-- existiera.
	if not IsValid(ply) then
		print("[ph_anim] este comando necesita un jugador que apunte (no sirve desde la consola del servidor)")
		return nil
	end
	local e = ply:GetEyeTrace().Entity
	if not IsValid(e) then
		print("[ph_anim] no estas apuntando a ninguna entidad")
		return nil
	end
	return e
end

local function listar(e)
	local n = e:GetSequenceCount()
	print(string.format("[ph_seqs] %s  clase=%s  %d secuencia(s)  actual=%d ciclo=%.3f",
		e:GetModel() or "?", e:GetClass(), n, e:GetSequence(), e:GetCycle()))
	for i = 0, n - 1 do
		print(string.format("   %2d  %s%s", i, e:GetSequenceName(i) or "?",
			i == e:GetSequence() and "   <- actual" or ""))
	end
end

concommand.Add("ph_seqs", function(ply)
	local e = apuntado(ply)
	if e then listar(e) end
end)

-- Poner una secuencia por NOMBRE o por INDICE. LookupSequence devuelve -1 (no
-- nil) cuando el nombre no existe, y ResetSequence(-1) no falla: deja el prop
-- como estaba. O sea que un nombre mal escrito se ve exactamente igual que una
-- animacion que no se exporto -- por eso se chequea aca y se dice cual es.
local function ponerSeq(e, arg)
	local i = tonumber(arg)
	if not i then
		i = e:LookupSequence(arg)
		if not i or i < 0 then
			print(string.format("[ph_seq] %s no tiene ninguna secuencia %q (ph_seqs las lista)",
				e:GetModel() or "?", arg))
			return false
		end
	end
	if i < 0 or i >= e:GetSequenceCount() then
		print(string.format("[ph_seq] la secuencia %d no existe: hay %d (0 a %d)",
			i, e:GetSequenceCount(), e:GetSequenceCount() - 1))
		return false
	end
	e:ResetSequence(i)
	e:SetPlaybackRate(1)
	e:SetCycle(0)
	print(string.format("[ph_seq] %s -> %d %q", e:GetModel() or "?", i, e:GetSequenceName(i) or "?"))
	return true
end

concommand.Add("ph_seq", function(ply, _, args)
	local e = apuntado(ply)
	if not e then return end
	if not args[1] then
		listar(e)
		return
	end
	ponerSeq(e, args[1])
end)

-- El ciclo se lee dos veces separadas en el tiempo. Es la unica forma de
-- distinguir "la animacion no avanza" de "la animacion no existe": las dos se
-- ven como un prop quieto.
local function medirAvance(e, i)
	if not IsValid(e) then return end
	local antes = e:GetCycle()
	timer.Simple(0.5, function()
		if not IsValid(e) then return end
		local ahora = e:GetCycle()
		if math.abs(ahora - antes) < 1e-4 then
			-- Se reporta la MEDICION primero y despues se arregla, en ese orden.
			-- Prender el avance manual sin decir que el servidor no animo
			-- taparia el unico dato que dice si la keyvalue DefaultAnim
			-- funciono: el comando andaria igual y no se sabria por que.
			print(string.format("[ph_anim] el ciclo NO avanzo en 0.5 s (%.3f): el servidor no esta"
				.. " animando este prop -- prendo el avance manual (ph_anim_drive %d para apagarlo)",
				ahora, i))
			manuales[e] = true
		else
			print(string.format("[ph_anim] el ciclo avanzo %.3f -> %.3f en 0.5 s: esta animando",
				antes, ahora))
		end
	end)
end

concommand.Add("ph_anim", function(ply, _, args)
	if not IsValid(ply) then
		print("[ph_anim] este comando necesita un jugador (no sirve desde la consola del servidor)")
		return
	end
	local mdl = args[1]
	if not mdl then
		print("[ph_anim] uso: ph_anim <modelo> [secuencia]   ej: ph_anim phantasmagoria/monkeypaw twitch")
		return
	end
	if not string.find(mdl, "%.mdl$") then mdl = "models/" .. mdl .. ".mdl" end
	if not util.IsValidModel(mdl) then
		print(string.format("[ph_anim] %q no es un modelo cargado. Si el archivo esta"
			.. " en el addon, el motor no lo vio: mirar la ruta.", mdl))
		return
	end

	local e = ents.Create("prop_dynamic")
	if not IsValid(e) then
		print("[ph_anim] ents.Create devolvio invalido")
		return
	end
	e:SetModel(mdl)
	e:SetPos(ply:GetPos() + ply:GetAimVector() * 60 + Vector(0, 0, 40))
	e:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
	-- MEDIDO EN JUEGO: un prop_dynamic creado desde Lua con ResetSequence NO
	-- avanza el ciclo. Se quedo en 0.000 a los 0.5 s, siete veces seguidas.
	--
	-- HIPOTESIS, no medida todavia: en el SDK, `CDynamicProp` instala su
	-- `AnimThink` -- el que llama a StudioFrameAdvance -- dentro de
	-- `PropSetAnim`, y a `PropSetAnim` solo lo llama el Spawn cuando encuentra
	-- la keyvalue `DefaultAnim`. Sin ella el prop tendria la secuencia puesta y
	-- ningun think que la haga correr. Por eso esto va ANTES de Spawn().
	--
	-- Queda como hipotesis a proposito: lo que la confirma o la refuta es la
	-- lectura del ciclo a los 0.5 s, que ya esta abajo y no cambia. Si sigue
	-- sin avanzar, la keyvalue no era el motivo y el avance manual la tapa.
	--
	-- Y va el NOMBRE, no lo que se tipeo: `ph_anim <modelo> 1` es valido para
	-- ponerSeq (indice) y `DefaultAnim` no entiende un indice. Resolverlo aca
	-- evita que el mismo comando funcione de una forma y no de la otra.
	local nombreSeq = args[2]
	if nombreSeq then
		local i = tonumber(nombreSeq)
		if i then nombreSeq = e:GetSequenceName(i) end
		if nombreSeq then e:SetKeyValue("DefaultAnim", nombreSeq) end
	end
	e:Spawn()
	spawneados[#spawneados + 1] = e
	fases[e] = #spawneados * 0.17

	local n = e:GetSequenceCount()
	print(string.format("[ph_anim] #%d %s spawneado con %d secuencia(s)",
		#spawneados, mdl, n))
	if args[2] then
		if not ponerSeq(e, args[2]) then return end
	else
		listar(e)
		return
	end
	medirAvance(e, #spawneados)
end)

-- Avanzar el ciclo a mano. Existe porque la alternativa a "el servidor no lo
-- anima" no puede ser quedarse sin saber si la animacion esta bien.
concommand.Add("ph_anim_drive", function(ply, _, args)
	local e, cual
	if args[1] then
		-- SIN CAIDA AL APUNTADO, y es una CORRECCION. Antes decia
		--     local e = i and spawneados[i] or apuntado(ply)
		-- asi que un indice inexistente se iba en silencio a la entidad que el
		-- jugador estuviera mirando, y el mensaje imprimia el MODELO -- que es
		-- el mismo -- en vez del indice. En el log del autor eso se ve como
		-- `ph_anim_drive 2/3/4` prendiendo y apagando alternadamente un unico
		-- prop, sin nada que delatara que las cuatro llamadas eran a lo mismo.
		-- Un respaldo que redirige el SUJETO de la operacion tiene que decirlo
		-- o no existir; este no tenia por que existir.
		local i = tonumber(args[1])
		if not i then
			print("[ph_anim_drive] uso: ph_anim_drive [indice]   sin indice usa el prop apuntado")
			return
		end
		e = spawneados[i]
		if not IsValid(e) then
			print(string.format("[ph_anim_drive] no hay prop #%d: ph_anim spawneo %d",
				i, #spawneados))
			return
		end
		cual = "#" .. i
	else
		e = apuntado(ply)
		if not e then return end
		cual = "el apuntado"
	end

	manuales[e] = not manuales[e] or nil
	print(string.format("[ph_anim_drive] %s (%s): avance manual %s",
		cual, e:GetModel() or "?", manuales[e] and "ENCENDIDO" or "apagado"))
end)

hook.Add("Think", "phantasmagoria_anim_drive", function()
	for e, on in pairs(manuales) do
		if not IsValid(e) then
			manuales[e] = nil
		elseif on then
			-- 46 frames a 60 fps = 0.7666 s de vuelta. La duracion real la sabe
			-- el motor, asi que se le pregunta en vez de cablearla.
			--
			-- El desfasaje por entidad NO es cosmetico: con `CurTime() % dur`
			-- pelado, varios props quedan en la misma fase exacta y se mueven
			-- como uno solo. Eso se lee como que la animacion esta sincronizada
			-- con algo, que es una conclusion sobre el motor sacada de un
			-- detalle de este hook.
			local dur = e:SequenceDuration()
			if dur and dur > 0 then
				e:SetCycle(((CurTime() + (fases[e] or 0)) % dur) / dur)
			end
		end
	end
end)

concommand.Add("ph_anim_clear", function()
	local n = 0
	for _, e in ipairs(spawneados) do
		if IsValid(e) then e:Remove() n = n + 1 end
	end
	spawneados, manuales, fases = {}, {}, {}
	print(string.format("[ph_anim_clear] %d prop(s) borrados", n))
end)
