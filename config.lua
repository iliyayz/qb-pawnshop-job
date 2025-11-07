Config = {}

Config.Webhooks = {
    Sell     = "YOUR_WEBHOOK_URL_HERE",
    Exchange = "YOUR_WEBHOOK_URL_HERE",
    Stash    = "YOUR_WEBHOOK_URL_HERE"
}

Config.LogBrand = {
    name = "Pawnshop Logs",
    icon = "https://i.imgur.com/youricon.png" -- optional
}
-- Enable to print which inventory event fires (helps debug stash logs)
Config.InventoryDebug = false

-- Main shop menu target location
Config.PawnShopCoords = vector3(-786.23, -615.62, 30.26)

-- Separate on/off duty target location
Config.DutyCoords = vector3(-778.78, -608.58, 30.44)

-- Map blip settings
Config.Blip = {
    label  = "Personal Stash",
    sprite = 267,
    color  = 5,
    scale  = 0.8,
    display= 4
}

-- Custom display labels
Config.CustomLabels = {
    ["iron"]     = "iron",
    ["copper"]   = "copper",
    ["goldbar"]  = "goldbar",
    ["silver"]   = "silver",
    ["plastic"]  = "plastic",
    ["aluminum"] = "aluminum",
    ["steel"]    = "steel",
    ["phone"]    = "phone",
    ["tablet"]   = "tablet"
}

-- Sell list: item → price per unit
Config.SellItems = {
    ["iron"]     = 2,
    ["copper"]   = 2,
    ["goldbar"]  = 2,
    ["silver"]   = 2,
    ["plastic"]  = 2,
    ["aluminum"] = 2,
    ["steel"]    = 2
}

-- ✅ Multi‑output Exchange
-- Structure: input → list of outputs (each 1 input yields one of multiple outputs)
-- Example: 1x phone → 5 iron OR 3 copper OR 2 aluminum (player chooses)
Config.Exchange = {
    ["recyclablematerial"] = {
        { item = "iron",     yield = 1 },
        { item = "copper",   yield = 1 },
        { item = "aluminum", yield = 1 },
    },
    ["phone"] = {
        { item = "steel",    yield = 1 },
        { item = "plastic",  yield = 1 },
    },
    -- Optional: also provide exchange choices for raw materials:
    ["rolex"] = {
        { item = "goldbar",  yield = 1 },
        { item = "aluminum", yield = 1 },
    }
}

-- Stashes
Config.Stashes = {
    Job = {
        name   = "pawnshop_stash",     -- Shared among employees (when on duty)
        label  = "Job Stash",
        slots  = 100,
        weight = 250000,
    },
    Personal = {
        name   = "pawnshop_personal",  -- Final stash name becomes: name-citizenid
        label  = "Personal Stash",
        slots  = 100,
        weight = 150000,
    }
}
