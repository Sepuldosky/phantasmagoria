--[[-------------------------------------------------------------------------
    Phantasmagoria - Tabla de los 30 tipos de fantasma

    GENERADO AUTOMATICAMENTE. No editar a mano: regenerar con dev/gen_types.py
    Fuente: zero-network.net/phasmophobia/data/ghosts.json (el backend del
            cheat sheet de tybayn). Datos del juego, no inventados.

    speed.* son MULTIPLICADORES de la carrera del jugador, no m/s absolutos.
    Se calculan como (m/s del juego) / 1.7, donde 1.7 m/s es el Spirit.
    Con Better Movement en run=280, un Spirit corre a 280 u/s.
    Ver PHANTOM_Phasmophobia_Diseno.md seccion 1.1.

    hunt.threshold es el % de cordura por debajo del cual el tipo puede cazar.
---------------------------------------------------------------------------]]

PHANTASMAGORIA = PHANTASMAGORIA or {}
PHANTASMAGORIA.Types = {}

local T = PHANTASMAGORIA.Types

T[ "aswang"       ] = {
    name      = "Aswang",
    evidence  = { "freezing", "writing", "dots" },
    speed = {
        base      = 0.900,   -- 1.53 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Will immediately end a hunt if the ghost enters an official hiding spot that a detected player
    --     is currently in
    --   If a hunt ends when the ghost enters the same official hiding spot as a player, the ghost will
    --     walk toward that player's current location at the start of the following hunt, even during the
    --     grace period
    --   Reaches max LOS speed in 8.667s instead of the standard 13s
}

T[ "banshee"      ] = {
    name      = "Banshee",
    evidence  = { "uv", "orbs", "dots" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
        thresholdLow  = 12,
        thresholdHigh = 87,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   66% chance to stalk/roam to its target (if inside) without leaving EMF (cannot stalk between
    --     floors except for single room basements)
    --   Prefers singing ghost events
    --   Will attempt to roam toward their target while in DOTS state
    --   Can only be female, ghost model and ghost name will reflect this
    --   33% chance to give 1 of 20 unique screams through the parabolic microphone / sound recorder.
    --     Examples:( 1 : | 2 : | 3: | 4 : )
    --   Hunts based on target's sanity instead of average sanity
    --   Will only pursue its target during a hunt (if the target is inside)
    --   Target loses 15% sanity if they touch the ghost during a singing ghost event (standard drain
    --     is 10%)
}

T[ "dayan"        ] = {
    name      = "Dayan",
    evidence  = { "emf5", "orbs", "spiritbox" },
    speed = {
        base      = 0.706,   -- 1.20 m/s
        top       = 1.324,   -- 2.25 m/s (alterna entre los dos)
        isRange   = false,
        alt       = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
        thresholdLow  = 45,
        thresholdHigh = 65,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Can only be female, ghost model and ghost name will reflect this
    --   Hunt speed and sanity are determined by player movement near the ghost
}

T[ "deildegast"   ] = {
    name      = "Deildegast",
    evidence  = { "emf5", "writing", "dots" },
    speed = {
        base      = 0.235,   -- 0.40 m/s
        top       = 1.765,   -- 3.00 m/s (rango continuo)
        isRange   = true,
        losSpeedUp = false,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Base speed returns to 3.0m/s after each hunt attempt, can reach a minimum speed of 0.4m/s if
    --     26+ items are moved
    --   Speed decreases by 0.1 m/s for each unique non-equipment item picked up or interacted with by
    --     players (alive or dead) since the end of the last hunt or hunt attempt (See Details)
}

T[ "demon"        ] = {
    name      = "Demon",
    evidence  = { "uv", "writing", "freezing" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 70,
        thresholdLow  = 70,
        thresholdHigh = 100,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Can hunt at any sanity
    --   Crucifix range is increased by 50% per tier (4.5m, 6m, 7.5m respectively)
    --   Can hunt 60s after being smudged instead of the standard 90s
    --   Can hunt 20s after the previous hunt has ended or ghost has used a crucifix instead of the
    --     standard 25s
}

T[ "deogen"       ] = {
    name      = "Deogen",
    evidence  = { "spiritbox", "writing", "dots" },
    speed = {
        base      = 0.235,   -- 0.40 m/s
        top       = 1.765,   -- 3.00 m/s (alterna entre los dos)
        isRange   = false,
        losSpeedUp = false,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 40,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Always has LOS of the player during hunts, meaning you cannot hide from a Deogen
    --   33% chance to give heavy breathing through spirit box when within 1m of the ghost
    --   Very fast hunt speed, but will slow down as it nears the targeted player
    --   Is more visible during hunts
}

T[ "gallu"        ] = {
    name      = "Gallu",
    evidence  = { "emf5", "uv", "spiritbox" },
    speed = {
        base      = 0.800,   -- 1.36 m/s
        top       = 1.150,   -- 1.96 m/s (alterna entre los dos)
        isRange   = false,
        alt       = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
        thresholdLow  = 40,
        thresholdHigh = 60,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Cycles through 3 states that change speed and other behaviors [Normal > Enraged > Weakened >
    --     ...] (See Details)
    --   Can hunt directly on top of a Tier 1 crucifix placed on the floor when enraged
    --   Average hunt sanity threshold is 50% in Normal State, 60% in Enraged State, and 40% in
    --     Weakened State
    --   Ghost speed is 1.7m/s in Normal State, 1.96m/s in Enraged State, and 1.36m/s in Weakened State
}

T[ "goryo"        ] = {
    name      = "Goryo",
    evidence  = { "emf5", "uv", "dots" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Cannot change favorite rooms
    --   Less likely to roam and cannot long roam, keeping it within its room more often
    --   Will enter DOTS state more frequently than other ghosts
    --   DOTS only appear on video camera and will not show if a player is in the same room (DOTS state
    --     can start outside of room and enter a player's room)
}

T[ "hantu"        ] = {
    name      = "Hantu",
    evidence  = { "uv", "orbs", "freezing" },
    speed = {
        base      = 0.824,   -- 1.40 m/s
        top       = 1.588,   -- 2.70 m/s (rango continuo)
        isRange   = true,
        losSpeedUp = false,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Will have visible freezing breath during hunts when the breaker is off/broken
    --   Cannot turn on the breaker
    --   More likely to turn off the breaker
    --   Is faster in colder rooms during hunts
}

T[ "jinn"         ] = {
    name      = "Jinn",
    evidence  = { "emf5", "uv", "freezing" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        top       = 1.471,   -- 2.50 m/s (alterna entre los dos)
        isRange   = false,
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   With the breaker on, can drop a nearby (within 3m or in the same room) player's sanity by 25%,
    --     with EMF 2 or EMF 5 at the breaker.
    --   With the breaker on, can drop a nearby (within 3m or in the same room) player's sanity by 25%,
    --     with EMF 2 at the breaker.
    --   The Jinn cannot directly turn off the breaker
    --   With the breaker on, the Jinn will speed up during a hunt if a player is in LOS and further
    --     than 3m away
}

T[ "kormos"       ] = {
    name      = "Kormos",
    evidence  = { "orbs", "spiritbox", "uv" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        top       = 1.300,   -- 2.21 m/s (alterna entre los dos)
        isRange   = false,
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
        thresholdLow  = 50,
        thresholdHigh = 70,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   LOS speed-up while travelling to the player's last detected location within 5m (detection
    --     based on movement)
    --   Will not do "Ghost Mist" nor "Chasing" ghost events
    --   Cannot see the player unless they are moving within 5m of the ghost
    --   Has additional detection ranges during hunts based on player movement (normal detection for
    --     voice and electronics) (See Details)
}

T[ "mare"         ] = {
    name      = "Mare",
    evidence  = { "spiritbox", "orbs", "writing" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 60,
        thresholdLow  = 40,
        thresholdHigh = 60,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Has a chance to immediately turn off a light switch (or lamp) that a player has turned on
    --     within 4m of the ghost
    --   Can use its ability during events, making it the only ghost that can interact with a switch
    --     during an event
    --   More likely to long roam when lights are on in its current room
    --   Prefers turning off lights and light bursting events
    --   Cannot turn on lights (including TVs and computers, excluding motion activated lights)
    --   Won't hunt until 40% average sanity when light switch in its current room is in the on
    --     position (regardless of breaker state), 60% average sanity if light switch is in the off
    --     position or if the lights are broken (regardless of light switch state)
    --   Only ghost that cannot flicker the lights with EMF 2 at the switch
}

T[ "moroi"        ] = {
    name      = "Moroi",
    evidence  = { "spiritbox", "writing", "freezing" },
    speed = {
        base      = 0.882,   -- 1.50 m/s
        top       = 1.324,   -- 2.25 m/s (rango continuo)
        isRange   = true,
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Faster when average sanity is lower, can reach a speed of 3.71 m/s when in continuous LOS
    --   Places a curse on player when the player hears: (1) any response on the spirit box, (2) a
    --     paranormal sound on the parabolic microphone, or (3) any recordable sound on the sound
    --     recorder (must be recorded). This causes sanity to passively drain twice as fast (even in a
    --     lit room)
    --   Places a curse on player when heard through parabolic microphone, curse drops sanity 2x as
    --     fast
    --   Incense blindness duration during hunts is increased from 5s to 7s
}

T[ "myling"       ] = {
    name      = "Myling",
    evidence  = { "emf5", "uv", "writing" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Footsteps and vocals cannot be heard more than 12m away during hunts (normal is 20m)
    --   Makes sounds through the parabolic microphone / sound recorder more frequently than other
    --     ghosts
}

T[ "obake"        ] = {
    name      = "Obake",
    evidence  = { "emf5", "uv", "orbs" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Can make fingerprints disappear twice as fast
    --   Special 6 fingered fingerprints (Open 'Guides' tab)
    --   Will change models for a single blink during hunts at least once per standard length hunt (See
    --     deeper explanation)
    --   Has a 25% chance to not leave ultraviolet evidence (including footprints)
    --   25% chance to miss a footstep during events
}

T[ "obambo"       ] = {
    name      = "Obambo",
    evidence  = { "writing", "uv", "dots" },
    speed = {
        base      = 0.850,   -- 1.45 m/s
        top       = 1.150,   -- 1.96 m/s (alterna entre los dos)
        isRange   = false,
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 65,
        thresholdLow  = 10,
        thresholdHigh = 65,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Will switch between a 'calm' state and 'aggressive' state every 2 minutes (timer starts
    --     halfway through 'calm' state upon opening front door)
    --   65% when aggressive, 10% when calm
    --   Faster when aggressive (1.96m/s), slower when calm (1.45m/s)
    --   Can change states during a hunt
    --   Hunt duration is decreased by 20% when started in an aggressive state
}

T[ "oni"          ] = {
    name      = "Oni",
    evidence  = { "emf5", "freezing", "dots" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   More active around multiple people
    --   More likely to appear as full ghost model during events
    --   Drains 20% sanity during events (instead of the standard 10%)
    --   Will not do "Ghost Mist" event
    --   Blinks more frequently during hunts, making them more visible
}

T[ "onryo"        ] = {
    name      = "Onryo",
    evidence  = { "spiritbox", "orbs", "freezing" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 60,
        thresholdLow  = 40,
        thresholdHigh = 100,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Flames act like crucifixes, will blow out a flame if it tries to hunt (within 4m). Ghost
    --     prioritizes flames over crucifixes when preventing hunts
    --   More likely to extinguish a flame, the more players that are dead
    --   Will attempt to hunt at any sanity after extinguishing 3+ flames since its last ability hunt
    --     attempt (See Details)
    --   Only ghost that can extinguish the same firelight twice within 20s
    --   Cannot light fire sources
}

T[ "phantom"      ] = {
    name      = "Phantom",
    evidence  = { "spiritbox", "uv", "dots" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Can roam toward a random player, leaving EMF 2 at the location where it wanders to (at head
    --     height)
    --   Can roam to a player that is outside of but still within 5m of the investigation area
    --   Will not appear in "Ghost" photos or "Ghost" videos (will still appear in "Translucent Ghost",
    --     "Shadow Ghost", "DOTS Ghost", and "Hunting Ghost" videos)
    --   Taking a photo or video of the ghost will cause the ghost to disappear (including DOTS state)
    --   Less visible during hunts
    --   Player will lose 0.5% sanity /s while in heartbeat range of the ghost during hunts and events
}

T[ "poltergeist"  ] = {
    name      = "Poltergeist",
    evidence  = { "spiritbox", "uv", "writing" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Poltergeist Explosion: will throw multiple objects at the same time, decreasing nearby player
    --     sanity by 2% per item thrown. There are 4 types of poltergeist throws (See examples)
    --   Only ghost that can throw an item while the ghost is in a lit room
    --   Has a higher chance to throw & interact with objects
    --   Can throw objects faster and further
    --   During hunts, Poltergeists will throw an item every 0.5s with an increased force
}

T[ "raiju"        ] = {
    name      = "Raiju",
    evidence  = { "emf5", "orbs", "dots" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        top       = 1.471,   -- 2.50 m/s (alterna entre los dos)
        isRange   = false,
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
        thresholdLow  = 50,
        thresholdHigh = 65,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   During events and hunts, causes electronic disturbance at a 15m range instead of 10m
    --   Increased speed while hunting when active electronics are within 6m, 8m, 10m on S, M, L maps
    --     respectively
    --   Can hunt at 65% when near active electronic equipment
    --   Has a louder heartbeat sound than other ghosts( Normal : | Raiju : )
}

T[ "revenant"     ] = {
    name      = "Revenant",
    evidence  = { "orbs", "writing", "freezing" },
    speed = {
        base      = 0.588,   -- 1.00 m/s
        top       = 1.765,   -- 3.00 m/s (alterna entre los dos)
        isRange   = false,
        losSpeedUp = false,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   During a hunt, a Revenant will be slow (1.0m/s) until it detects a player (voice, active
    --     electronic equipment, or LOS) where it will immediately speed up to 3.0m/s and remain at that
    --     speed until it reaches the players last known location where it will gradually slow back down
}

T[ "shade"        ] = {
    name      = "Shade",
    evidence  = { "emf5", "writing", "freezing" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 35,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Prefers shadow ghost model during events
    --   Will not hunt if in the same room as a player
    --   Will not do events in the same room as a player (but can start an event outside of the room
    --     and teleport to the player)
    --   Will not do interactions that result in EMF 2, EMF 3, or EMF 5 while in the same room as the
    --     player, including ghost writing, blowing out flames, and voodoo doll interactions (can step
    --     just outside of the room and interact with things in the room)
    --   Will not do interactions that result in EMF 2 or EMF 3 while in the same room as the player,
    --     including blowing out flames and voodoo doll interactions (can step just outside of the room
    --     and interact with things in the room)
    --   Chance for doing ghost events decreases the higher average sanity is above 50% (cannot do
    --     ghost events at 100% sanity)
    --   Will not blow out firelights while hunting if in the same room as the player (beware of actual
    --     or buggy room boundaries)
    --   Only ghost that can appear as a shadow ghost model on summoning circle, music box, and monkey
    --     paw events
}

T[ "spirit"       ] = {
    name      = "Spirit",
    evidence  = { "emf5", "spiritbox", "writing" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Will wait 180s after being incensed before attempting to hunt again, instead of the standard
    --     90s
}

T[ "thaye"        ] = {
    name      = "Thaye",
    evidence  = { "orbs", "writing", "dots" },
    speed = {
        base      = 0.588,   -- 1.00 m/s
        top       = 1.618,   -- 2.75 m/s (rango continuo)
        isRange   = true,
        losSpeedUp = false,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 75,
        thresholdLow  = 15,
        thresholdHigh = 75,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Ghost will attempt to age every 1-2 minutes. If a player is in the same room when it attempts,
    --     it ages; otherwise, it waits 30s and attempts again
    --   More active when younger
    --   Age response on Ouija board increases as Thaye ages
    --   Only ghost that can have an age of 90+ on the Ouija Board
}

T[ "the_mimic"    ] = {
    name      = "The Mimic",
    evidence  = { "spiritbox", "uv", "freezing" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
        thresholdLow  = 10,
        thresholdHigh = 100,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Mimics a different ghost every 30 - 120 seconds, taking on all behaviors, tells, and abilities
    --     of that ghost (excluding evidence), leading to inconsistent behavior
    --   Will always show Ghost Orbs as an additional evidence, even on 0 evidence
}

T[ "the_twins"    ] = {
    name      = "The Twins",
    evidence  = { "emf5", "spiritbox", "freezing" },
    speed = {
        base      = 0.882,   -- 1.50 m/s
        top       = 1.118,   -- 1.90 m/s (alterna entre los dos)
        isRange   = false,
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Triggering motion sensors, stepping in salt, and spirit box responses only occur at its
    --     physical location
    --   Can do 2 interactions at the same time, one within its standard radius (2.12m, 4.24m on large
    --     maps) and the other within its extended radius (8.48m, 16.97m on large maps)
    --   Ghost speed during hunts will be either 1.5m/s or 1.9m/s
}

T[ "wraith"       ] = {
    name      = "Wraith",
    evidence  = { "emf5", "spiritbox", "dots" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Can teleport to a random player, leaving EMF 2 or EMF 5 at the their new location (at foot
    --     height). Walks back to their favorite room after teleporting.
    --   Can teleport to a random player, leaving EMF 2 at the their new location
    --   Will not touch nor interact with salt in any way
    --   Will not be slowed down by tier 3 salt during a hunt
}

T[ "yokai"        ] = {
    name      = "Yokai",
    evidence  = { "spiritbox", "orbs", "dots" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
        thresholdLow  = 50,
        thresholdHigh = 80,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Talking in the same room as a Yokai can cause it to hunt up to 80% average sanity
    --   More active when talking near it
    --   Voice/electronics detection distance is 2.5m and less during hunts
    --   Will start event at 2.5m from music box instead of standard 5m
    --   Ends music box event when the head of the ghost is 0.5m away from the music box instead of the
    --     standard 1m
}

T[ "yurei"        ] = {
    name      = "Yurei",
    evidence  = { "orbs", "freezing", "dots" },
    speed = {
        base      = 1.000,   -- 1.70 m/s
        losSpeedUp = true,  -- acelera con linea de vista
    },
    hunt = {
        threshold = 50,
    },
    -- Comportamiento del juego (de la fuente; guia lo que hay que implementar):
    --   Can shut a door and drop sanity of nearby players by 15% if a door is in the room
    --   Incensing the ghost will trap the ghost in its room for the duration of the incense effect
    --     (90s)
    --   Cannot give DOTS evidence while under the effects of an incense (90s)
    --   Only ghost that can close or interact with an exit door outside of a hunt/event
    --   Must fully open / shut a door when doing door interactions (outside of a hunt)
}

-- Indice estable para UI y para el sorteo
PHANTASMAGORIA.TypeOrder = {
    "aswang",
    "banshee",
    "dayan",
    "deildegast",
    "demon",
    "deogen",
    "gallu",
    "goryo",
    "hantu",
    "jinn",
    "kormos",
    "mare",
    "moroi",
    "myling",
    "obake",
    "obambo",
    "oni",
    "onryo",
    "phantom",
    "poltergeist",
    "raiju",
    "revenant",
    "shade",
    "spirit",
    "thaye",
    "the_mimic",
    "the_twins",
    "wraith",
    "yokai",
    "yurei",
}

return PHANTASMAGORIA.Types
