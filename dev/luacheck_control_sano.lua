-- CONTROL POSITIVO: todo esto es Lua 5.1 valido y el detector NO tiene que
-- reprobarlo. Cubre los cuatro contextos que el lexer separa a mano.

local escapado = f( "primera parte\nsegunda parte" )

local largo = [[
un string LARGO con saltos de linea adentro, que es perfectamente legal
y que un detector ingenuo confundiria con el defecto
]]

local largoIgual = [==[
otro string largo, con el separador de signos igual
]==]

-- un comentario de linea con una "comilla suelta que no cierra

--[[
    un comentario LARGO con una "comilla suelta
    y con 'otra distinta
]]

local conComilla = "con \" una comilla escapada adentro"
local simple     = 'con \' una comilla simple escapada'
local barra      = "termina en barra escapada \\"
local vacio      = ""

return { escapado, largo, largoIgual, conComilla, simple, barra, vacio }
