--[[-------------------------------------------------------------------------
    Phantasmagoria - terminator_nextbot_phantom

    LA PRIMERA ENTIDAD DEL PROYECTO. Su primer trabajo NO es ser un fantasma:
    es ser un INSTRUMENTO. Tiene que existir, aparecer en el spawnmenu,
    spawnear, caminar hacia algo, y -sobre todo- MOSTRAR DONDE ESTA.
    Todo lo demas viene despues de verla caminar una vez.

    YA NO ES SOLO UN INSTRUMENTO: tiene el primer comportamiento propio, el
    interruptor fantasma/cazador ( server.lua ). Fuera del hunt no ataca a
    nadie; dentro, si. El gatillo es MANUAL y PROVISORIO -- el concommand
    phantasmagoria_hunt -- porque la cordura, que es la que deberia dispararlo
    (Diseno 4 y 19), todavia no existe.

    LO QUE DELIBERADAMENTE NO TIENE, Y POR QUE:

      ENT.IsWraith                 ⚠ Y AHORA ES PERMANENTE, no un "todavia no".
                                   La invisibilidad existe ( Diseno 20 ①,
                                   server_cloak.lua ) y es PROPIA. El cloak de
                                   la base acopla el invisible a la NO-SOLIDEZ
                                   en dos lugares -- su material se salta si el
                                   bot es solido ( wraithcloaking.lua:99 ) y su
                                   unhide escribe SetSolidMask sin consultar la
                                   bandera ( :172-173 ) --, y la solidez de este
                                   fantasma tiene un dueno unico que es
                                   server_doors.lua. Detalle en Diseno 20.1-20.2
                                   y en el encabezado de server_cloak.lua.
      SetupDataTables              la base no lo usa: networkea con slots
                                   hardcodeados y el Bool 0 ya es Crouching
                                   (Referencia 4.3, defecto D-6 de HIM). El
                                   estado del hunt viaja por SetNWBool, que es
                                   otro sistema y no colisiona.
      todo lo demas                maquina de estados, 30 tipos, rasgos,
                                   cordura, sonidos, eventos.

    Y OJO CON DISENO 3.1: nombra a OnFirstRelationWithPlayer como el
    interruptor, y NO lo es. La relacion es un cache que se escribe una sola
    vez, y encima MakeFeud la reescribe a D_HT de un balazo. El interruptor de
    verdad es ShouldBeEnemy; el detalle esta en server.lua con archivo y linea.

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

---------------------------------------------------------------------------
-- ⚠ EL CADAVER DE UN FANTASMA INVISIBLE, Y VA ACA PORQUE TIENE QUE SER SHARED
---------------------------------------------------------------------------
-- Diseno 20 ①. Desde server_cloak.lua el fantasma anda con EF_NODRAW puesto
-- fuera del hunt, y la base crea el ragdoll ANTES de limpiar nada
-- ( damageandhealth.lua:804 BecomeRagdoll, y recien :826 el SetNoDraw sobre el
-- bot ). Si BecomeRagdoll hereda la bandera -- NO esta medido --, un fantasma
-- que muere invisible deja un cadaver invisible.
--
-- El stub de la base esta COMENTADO ( damageandhealth.lua:943-947 ), asi que no
-- hay a quien encadenar, y su propio comentario dice por que va compartido:
-- *"make sure you add this shared, this is called for client ragdolls too"* --
-- cl_ragdolldeaths.lua:8 la llama desde el hook CreateClientsideRagdoll, que es
-- del cliente. Declarada solo en el servidor, esa mitad quedaria descubierta.
--
-- server_cloak.lua la PISA en el servidor con una version que ademas mide si la
-- herencia ocurrio. Esta es la de cliente, y hace lo minimo.
function ENT:AdditionalRagdollDeathEffects( ragdoll )
    if not IsValid( ragdoll ) then return end

    ragdoll:SetNoDraw( false )
    ragdoll:DrawShadow( true )

end

if CLIENT then
    include( "client.lua" )

elseif SERVER then
    include( "server.lua" )

end
