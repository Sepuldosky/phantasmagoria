--[[
	Manipular los huesos de un prop desde la consola, sin pelear con el widget.

	    ph_bones                  lista los huesos del prop al que estas apuntando
	    ph_bone <i> <p> <y> <r>   rota el hueso i
	    ph_bones_reset            deja todo como estaba

	POR QUE EXISTE

	El widget de "editar huesos" del menu de contexto CICLA de modo haciendo
	click sobre el MISMO hueso: 1er click mover, 2do ROTAR, 3ro escalar. Mover
	un hueso de una malla con skin arrastra vertices, o sea que estira -- y el
	primer click siempre cae en ese modo. Ademas la opcion del menu desaparece
	si ya hay un widget puesto sobre esa entidad.

	Y escribir el comando a mano en la consola tampoco sale gratis: la consola
	de GMod NO ejecuta Lua pegado tal cual (hace falta `lua_run_cl`), cada linea
	es un chunk aparte -- asi que un `local` no sobrevive a la siguiente --, y
	un nombre de hueso CON ESPACIO adentro ("Music_Box_Lid Mesh") es justo lo
	que el tokenizador de la consola puede partir en dos.

	Por eso esto toma el hueso por INDICE y no por nombre. `ph_bones` imprime la
	lista con sus indices.

	OJO CON EL REALM: las manipulaciones de hueso hechas desde el cliente se ven
	SOLO en tu pantalla. Alcanza para verificar que el modelo dobla bien, que es
	para lo que existe esto; para que las vea todo el mundo hay que hacerlo del
	lado del servidor.
]]

local function apuntado()
	local e = LocalPlayer():GetEyeTrace().Entity
	if not IsValid(e) then
		print("[ph_bones] no estas apuntando a ninguna entidad")
		return nil
	end
	-- Un modelo sin huesos devuelve 1 (el hueso raiz implicito) o 0. Distinguir
	-- "no tiene huesos" de "no lo encontre" importa: son dos problemas
	-- distintos y el mensaje generico los confunde.
	if e:GetBoneCount() <= 1 then
		print(string.format("[ph_bones] %s tiene %d hueso(s): no hay nada que manipular",
			e:GetModel() or "?", e:GetBoneCount()))
		return nil
	end
	return e
end

concommand.Add("ph_bones", function()
	local e = apuntado()
	if not e then return end
	print(string.format("[ph_bones] %s  clase=%s  %d huesos",
		e:GetModel() or "?", e:GetClass(), e:GetBoneCount()))
	for i = 0, e:GetBoneCount() - 1 do
		local a = e:GetManipulateBoneAngles(i)
		local extra = ""
		if a and (a.p ~= 0 or a.y ~= 0 or a.r ~= 0) then
			extra = string.format("   <- rotado (%g, %g, %g)", a.p, a.y, a.r)
		end
		print(string.format("   %2d  %s%s", i, e:GetBoneName(i) or "?", extra))
	end
end)

concommand.Add("ph_bone", function(_, _, args)
	local e = apuntado()
	if not e then return end
	local i = tonumber(args[1])
	if not i then
		print("[ph_bone] uso: ph_bone <indice> <pitch> <yaw> <roll>   (ph_bones lista los indices)")
		return
	end
	-- El rango se chequea ACA. Sin esto, un indice de mas llega al motor como
	-- un error de argumento que se lee como si el comando no existiera.
	if i < 0 or i >= e:GetBoneCount() then
		print(string.format("[ph_bone] el hueso %d no existe: hay %d (0 a %d)",
			i, e:GetBoneCount(), e:GetBoneCount() - 1))
		return
	end
	local ang = Angle(tonumber(args[2]) or 0, tonumber(args[3]) or 0, tonumber(args[4]) or 0)
	e:ManipulateBoneAngles(i, ang)
	print(string.format("[ph_bone] %s (%d) -> (%g, %g, %g)",
		e:GetBoneName(i) or "?", i, ang.p, ang.y, ang.r))
end)

concommand.Add("ph_bones_reset", function()
	local e = apuntado()
	if not e then return end
	for i = 0, e:GetBoneCount() - 1 do
		e:ManipulateBoneAngles(i, Angle(0, 0, 0))
	end
	print(string.format("[ph_bones_reset] %d huesos a cero", e:GetBoneCount()))
end)
