return {
    ["shotgun_weapon"] = {
        id = "shotgun_weapon",
        name = "BULLFROG",
        class = "Weapon",
        spr_x = 336,
        spr_y = 208,
        description = "High spread shotgun.",
    },
    ["sniper_weapon"] = {
        id = "sniper_weapon",
        name = "SNAPPER",
        class = "Weapon",
        spr_x = 352,
        spr_y = 208,
        description = "Precise sniper rifle.",
    },
    ["burst_weapon"] = {
        id = "burst_weapon",
        name = "BEETLE",
        class = "Weapon",
        spr_x = 368,
        spr_y = 208,
        description = "Rapid burst SMG.",
    },


    ["rifle_turret_2"] = {
        id = "rifle_turret_2",
        name = "FOX Mk II",
        class = "Upgrade",
        description = "Higher range.",
        spr_x = 352,
        spr_y = 64,
        next = "rifle_turret_3"
    },
    ["rifle_turret_3"] = {
        id = "rifle_turret_3",
        name = "FOX Mk III",
        class = "Upgrade",
        description = "Improved feed mechanism.",
        spr_x = 384,
        spr_y = 64,
        next = "rifle_turret_4"
    },


    ["shotgun_turret_1"] = {
        id = "shotgun_turret_1",
        name = "SLUG Mk. I",
        class = "Turret",
        description = "Close-range shotgun.",
        spr_x = 416,
        spr_y = 64,
        next = "shotgun_turret_2"
    },
    ["shotgun_turret_2"] = {
        id = "shotgun_turret_2",
        name = "SLUG Mk. II",
        class = "Upgrade",
        description = "Faster reload.",
        spr_x = 448,
        spr_y = 64,
        next = "shotgun_turret_3"
    },
    ["shotgun_turret_3"] = {
        id = "rifle_turret_3",
        name = "SLUG Mk. III",
        class = "Upgrade",
        spr_x = 480,
        spr_y = 64,
        description = "Higher damage."
    },


    ["sniper_turret_1"] = {
        id = "sniper_turret_1",
        name = "VIPER Mk. I",
        class = "Turret",
        description = "High-velocity sniper.",
        spr_x = 320,
        spr_y = 96,
        next = "sniper_turret_2"
    },
    ["sniper_turret_2"] = {
        id = "sniper_turret_2",
        name = "VIPER Mk. I",
        class = "Turret",
        description = "Increased damage.",
        spr_x = 352,
        spr_y = 96,
        next = "sniper_turret_3"
    },
    ["sniper_turret_3"] = {
        id = "sniper_turret_3",
        name = "VIPER Mk. III",
        class = "Turret",
        spr_x = 384,
        spr_y = 96,
        description = "Increased sensor range."
    },


    ["ice_turret_1"] = {
        id = "ice_turret_1",
        name = "URSA Mk. I",
        class = "Turret",
        description = "Powerful blast chiller.",
        spr_x = 416,
        spr_y = 96,
        next = "ice_turret_2"
    },
    ["ice_turret_2"] = {
        id = "ice_turret_2",
        name = "URSA Mk. I",
        class = "Turret",
        description = "Increased area of effect.",
        spr_x = 448,
        spr_y = 96,
        next = "ice_turret_3"
    },
    ["ice_turret_3"] = {
        id = "ice_turret_3",
        name = "URSA Mk. I",
        spr_x = 480,
        spr_y = 96,
        class = "Turret",
        description = "Increased range."
    },

    ["sawblade_turret"] = {
        id = "sawblade_turret",
        name = "SHARK Mk. I",
        class = "Turret",
        description = "Fires deadly sawblades.",
        next = "sawblade_turret_2"
    },
    ["flamethrower_turret"] = {
        id = "flamethrower_turret",
        name = "KOMODO Mk. I",
        class = "Turret",
        description = "Imprecise flamethrower.",
        next = "flamethrower_turret_2"
    },
    ["tesla_turret"] = {
        id = "tesla_turret",
        name = "EEL Mk. I",
        class = "Turret",
        description = "Stuns with electricity.",
        next = "tesla_turret_2"
    },
    ["laser_turret"] = {
        id = "laser_turret",
        name = "KOMODO Mk. I",
        class = "Turret",
        description = "Continuous energy cannon.",
        next = "laser_turret_2"
    },
    ["frag_grenade"] = {
        id = "frag_grenade",
        name = "FRAG GRENADE",
        class = "Grenade",
        description = "Standard frag grenade.",
    },
    ["molotov"] = {
        id = "molotov",
        name = "MOLOTOV",
        class = "Grenade",
        description = "Spreads fiery alcohol.",
    },
    ["gravity"] = {
        id = "shotgun",
        name = "GRAVITY",
        class = "Grenade",
        description = "Draws in undead.",
    }
}