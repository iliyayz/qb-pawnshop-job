local QBCore = exports['qb-core']:GetCoreObject()

-- MAIN shop target (menu) – only when ON DUTY
CreateThread(function()
    exports['qb-target']:AddBoxZone("PawnShop_Main", Config.PawnShopCoords, 2.0, 2.0, {
        name = "PawnShop_Main",
        heading = 0,
        debugPoly = false,
        minZ = Config.PawnShopCoords.z - 1,
        maxZ = Config.PawnShopCoords.z + 1,
    }, {
        options = {
            {
                type  = "client",
                event = "qb-pawnshop:client:openMenu",
                icon  = "fa-solid fa-coins",
                label = "Pawn Shop Menu",
                canInteract = function()
                    local p = QBCore.Functions.GetPlayerData()
                    local j = p and p.job
                    return j and j.name == "pawnshop" and j.onduty == true
                end
            }
        },
        distance = 2.0
    })
end)

-- Separate ON/OFF duty target – available to all pawnshop employees
CreateThread(function()
    local c = Config.DutyCoords
    exports['qb-target']:AddBoxZone("PawnShop_Duty", c, 1.6, 1.6, {
        name = "PawnShop_Duty",
        heading = 0,
        debugPoly = false,
        minZ = c.z - 1,
        maxZ = c.z + 1,
    }, {
        options = {
            {
                type  = "client",
                event = "qb-pawnshop:client:toggleDuty",
                icon  = "fa-solid fa-user-check",
                label = "Toggle Duty",
                canInteract = function()
                    local p = QBCore.Functions.GetPlayerData()
                    local j = p and p.job
                    return j and j.name == "pawnshop"
                end
            }
        },
        distance = 2.0
    })
end)

-- Map blip
CreateThread(function()
    local c = Config.PawnShopCoords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipDisplay(blip, Config.Blip.display)
    SetBlipScale(blip,   Config.Blip.scale)
    SetBlipColour(blip,  Config.Blip.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Config.Blip.label)
    EndTextCommandSetBlipName(blip)
end)

-- Main Menu (ON DUTY only)  — Boss Menu removed
RegisterNetEvent("qb-pawnshop:client:openMenu", function()
    local p = QBCore.Functions.GetPlayerData()
    if not p or not p.job or p.job.name ~= "pawnshop" or p.job.onduty ~= true then
        QBCore.Functions.Notify("You must be on duty.", "error", 5000)
        return
    end

    local options = {
        {
            title = "Exchange Items",
            description = "Pick input item and the material output",
            icon = "fa-solid fa-recycle",
            event = "qb-pawnshop:client:exchange"
        },
        {
            title = "Sell Materials",
            description = "Sell raw materials from your inventory",
            icon = "fa-solid fa-dollar-sign",
            event = "qb-pawnshop:client:sell"
        },
        {
            title = "Job Stash (Shared)",
            description = "Shared stash for all employees",
            icon = "fas fa-warehouse",
            event = "qb-pawnshop:client:openJobStash"
        },
        {
            title = "Personal Stash (Private)",
            description = "Only you can access your personal stash",
            icon = "fas fa-lock",
            event = "qb-pawnshop:client:openPersonalStash"
        }
    }

    lib.registerContext({ id = 'pawnshop_menu', title = 'Pawn Shop', options = options })
    lib.showContext('pawnshop_menu')
end)

-- Duty toggle
RegisterNetEvent("qb-pawnshop:client:toggleDuty", function()
    local p = QBCore.Functions.GetPlayerData()
    if p and p.job and p.job.name == "pawnshop" then
        TriggerServerEvent("qb-pawnshop:server:toggleDuty")
    end
end)

-- SELL – from inventory + Config.SellItems
RegisterNetEvent("qb-pawnshop:client:sell", function()
    local p = QBCore.Functions.GetPlayerData()
    if not p or not p.job or p.job.name ~= "pawnshop" or p.job.onduty ~= true then
        QBCore.Functions.Notify("You must be on duty.", "error", 5000)
        return
    end

    local inv = p.items or {}
    local options = {}

    for _, it in ipairs(inv) do
        local price = Config.SellItems[it.name]
        local label = Config.CustomLabels[it.name]
        if price and label then
            options[#options+1] = {
                title = ("%s | $%d"):format(label, price),
                description = ("You have: %d"):format(it.amount or 0),
                icon = "fa-solid fa-sack-dollar",
                event = "qb-pawnshop:client:sellItem",
                args  = { itemname = it.name, label = label, have = it.amount or 0 }
            }
        end
    end

    if #options == 0 then
        QBCore.Functions.Notify("You have no items to sell.", "error", 5000)
        return
    end

    lib.registerContext({ id = 'pawnshop_sell_menu', title = 'Sell Materials', options = options })
    lib.showContext('pawnshop_sell_menu')
end)

RegisterNetEvent("qb-pawnshop:client:sellItem", function(data)
    if (data.have or 0) < 1 then
        QBCore.Functions.Notify("You don't have any of this item.", "error", 4000)
        return
    end
    local input = lib.inputDialog(("Sell %s"):format(data.label), {
        { type = "number", label = "Quantity", default = 1, min = 1, max = data.have }
    })
    if input and input[1] then
        TriggerServerEvent("qb-pawnshop:server:sell", data.itemname, tonumber(input[1]) or 1)
    end
end)

-- EXCHANGE – Step 1: list inputs from Config.Exchange that player has
RegisterNetEvent("qb-pawnshop:client:exchange", function()
    local p = QBCore.Functions.GetPlayerData()
    if not p or not p.job or p.job.name ~= "pawnshop" or p.job.onduty ~= true then
        QBCore.Functions.Notify("You must be on duty.", "error", 5000)
        return
    end

    local inv = p.items or {}
    local haveMap = {}
    for _, it in ipairs(inv) do
        haveMap[it.name] = (haveMap[it.name] or 0) + (it.amount or 0)
    end

    local options = {}
    for inputName, outputs in pairs(Config.Exchange) do
        local have = haveMap[inputName] or 0
        if have > 0 then
            local label = Config.CustomLabels[inputName] or inputName
            local outNames = {}
            for _, o in ipairs(outputs) do
                outNames[#outNames+1] = (Config.CustomLabels[o.item] or o.item)..(" (x%d)"):format(o.yield or 1)
            end
            options[#options+1] = {
                title = ("%s | You have: %d"):format(label, have),
                description = ("Possible outputs: %s"):format(table.concat(outNames, ", ")),
                icon = "fa-solid fa-recycle",
                event = "qb-pawnshop:client:exchangeSelect",
                args = { input = inputName, have = have }
            }
        end
    end

    if #options == 0 then
        QBCore.Functions.Notify("No convertible items in your inventory.", "error", 5000)
        return
    end

    lib.registerContext({ id = 'pawnshop_exchange_menu', title = 'Exchange Items', options = options })
    lib.showContext('pawnshop_exchange_menu')
end)

-- EXCHANGE – Step 2: choose output + amount
RegisterNetEvent("qb-pawnshop:client:exchangeSelect", function(data)
    local inputName = data.input
    local have      = data.have or 0
    local outputs   = Config.Exchange[inputName]
    if not outputs then return end

    local selectOpts = {}
    for _, o in ipairs(outputs) do
        local lab = Config.CustomLabels[o.item] or o.item
        selectOpts[#selectOpts+1] = { value = o.item, label = ("%s (x%d)"):format(lab, o.yield or 1) }
    end

    local dlg = lib.inputDialog(("Exchange %s"):format(Config.CustomLabels[inputName] or inputName), {
        { type = "select", label = "Choose output material", options = selectOpts, required = true },
        { type = "number", label = "Input quantity", default = 1, min = 1, max = have }
    })
    if not dlg then return end

    local outItem = dlg[1]
    local amount  = tonumber(dlg[2]) or 1
    TriggerServerEvent("qb-pawnshop:server:exchangeChoice", inputName, outItem, amount)
end)

-- STASH (server opens via qb-inventory export)
RegisterNetEvent("qb-pawnshop:client:openJobStash", function()
    local p = QBCore.Functions.GetPlayerData()
    if p and p.job and p.job.name == "pawnshop" and p.job.onduty == true then
        TriggerServerEvent("qb-pawnshop:server:openJobStash")
    else
        QBCore.Functions.Notify("You must be on duty.", "error", 5000)
    end
end)

RegisterNetEvent("qb-pawnshop:client:openPersonalStash", function()
    local p = QBCore.Functions.GetPlayerData()
    if p and p.job and p.job.name == "pawnshop" and p.job.onduty == true then
        TriggerServerEvent("qb-pawnshop:server:openPersonalStash")
    else
        QBCore.Functions.Notify("You must be on duty.", "error", 5000)
    end
end)
