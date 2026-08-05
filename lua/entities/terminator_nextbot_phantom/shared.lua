--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom

    LA PRIMERA ENTIDAD DEL PROYECTO. Su primer trabajo NO es ser un fantasma:
    es ser un INSTRUMENTO. Tiene que existir, aparecer en el spawnmenu,
    spawnear, caminar hacia algo, y -sobre todo- MOSTRAR DONDE ESTA.
    Todo lo demas viene despues de verla caminar una vez.

    LO QUE DELIBERADAMENTE NO TIENE, Y POR QUE:

      ENT.IsWraith                 un instrumento invisible no sirve para ver
                                   donde esta. Es un campo y se enciende solo
                                   cuando haya que ver el cloak, no antes.
      OnFirstRelationWithPlayer    el interruptor fantasma/cazador. Hoy el bot
                                   queda HOSTIL A PROPOSITO: el criterio de
                                   cierre es "camina hacia algo" y hace falta
                                   un algo. El interruptor va en esta funcion
                                   y NUNCA en DisableBehaviour (Diseno 3.1).
      SetupDataTables              la base no lo usa: networkea con slots
                                   hardcodeados y el Bool 0 ya es Crouching
                                   (Referencia 4.3, defecto D-6 de HIM).
      todo lo demas                maquina de estados, 30 tipos, rasgos,
                                   cordura, hunt, sonidos, eventos.

    Nada de esto se corrio en GMod antes de escribirlo. Si el juego contradice
    a los documentos, gana el juego.
---------------------------------------------------------------------------]]

AddCSLuaFile()
AddCSLuaFile( "client.lua" )

-- Referencia 3: terminator_nextbot_base NO tiene cerebro (cero BehaveUpdate,
-- cero BehaveStart, cero RunBehaviour en sus 10 archivos). El cerebro esta en
-- terminator_nextbot, y de ahi heredan las 11 subclases del addon y HIM.
ENT.Base = "terminator_nextbot"
DEFINE_BASECLASS( ENT.Base )

ENT.PrintName   = "Phantasmagoria Ghost"
ENT.Author      = "Phantasmagoria"
ENT.Purpose     = "El fantasma generico. Por ahora, un instrumento."

-- Los 30 tipos van a heredar estas dos por el arbol de bases: RegisterNPC las
-- resuelve con scripted_ents.GetMember, por eso difiere el registro a un
-- timer.Simple( 0 ) ( sh_terminator_registernpc.lua:29-39 ).
ENT.Category    = "Phantasmagoria"
ENT.SubCategory = "Fantasmas"

-- Son DOS listas distintas y conviene estar en las dos mientras esto sea un
-- instrumento:
--   ENT.Spawnable = true   -> pestana Entities, bajo ENT.Category
--   RegisterNPC            -> pestana NPCs, via list.Set( "NPC", ... )
-- Las subclases de la base ponen Spawnable = false justamente para NO estar
-- duplicadas; cuando existan los 30 tipos, este generico vuelve a false.
ENT.Spawnable = true

-- Marca para reconocerla desde afuera sin comparar nombres de clase. Las
-- subclases de Diseno 12.2 van a llamarse phantasmagoria_<tipo>, no
-- terminator_nextbot_*, asi que comparar clases va a envejecer mal.
ENT.IsPhantasmagoriaGhost = true

if terminator_Extras and terminator_Extras.RegisterNPC then
    terminator_Extras.RegisterNPC( "terminator_nextbot_phantom", ENT )

else
    -- Sin la base montada, ENT.Base tampoco resuelve y GMod va a tirar su
    -- propio error. Este aviso existe para que la causa se lea de una.
    ErrorNoHalt( "[Phantasmagoria] Falta la base 'Terminator NextBot' (StrawWagen). " ..
        "El fantasma no se registra ni se puede spawnear sin ella.\n" )

end

if CLIENT then
    include( "client.lua" )

elseif SERVER then
    include( "server.lua" )

end
