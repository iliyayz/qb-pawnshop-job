local QBCore = exports['qb-core']:GetCoreObject()

----------------------------------------------------------------
-- Discord Logging (3 webhooks + Steam HEX in all logs)
----------------------------------------------------------------
local function getSteamHex(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1,6) == "steam:" then return id end
    end
    return "steam:unknown"
end

local function sendDiscord(webhook, title, description, color, fields)
    if type(webhook) ~= "string" or webhook == "" then return end
    local embed = {{
        title = title,
        description = description,
        color = color or 3447003,
        fields = fields or {},
        footer = {
            text = (Config.LogBrand and Config.LogBrand.name) or "Logs",
            icon_url = (Config.LogBrand and Config.LogBrand.icon) or nil
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }}
    PerformHttpRequest(webhook, function() end, "POST",
        json.encode({ username = "Pawnshop Logger", embeds = embed }),
        { ["Content-Type"] = "application/json" })
end

local function logSell(src, itemName, amount, total)
    local Player = QBCore.Functions.GetPlayer(src); if not Player then return end
    local ped = GetPlayerName(src) or ("["..src.."]")
    local cid = Player.PlayerData.citizenid
    local steam = getSteamHex(src)
    local label = (QBCore.Shared.Items[itemName] and QBCore.Shared.Items[itemName].label) or itemName
    sendDiscord(Config.Webhooks.Sell,
        "Pawnshop • Sell",
        ("**%s** (`%s` | %s) sold **%dx %s** for **$%d**."):format(ped, cid, steam, amount, label, total),
        5763719)
end

local function logExchange(src, inputName, amount, outputName, outQty)
    local Player = QBCore.Functions.GetPlayer(src); if not Player then return end
    local ped = GetPlayerName(src) or ("["..src.."]")
    local cid = Player.PlayerData.citizenid
    local steam = getSteamHex(src)
    local inLabel  = (QBCore.Shared.Items[inputName]  and QBCore.Shared.Items[inputName].label)  or inputName
    local outLabel = (QBCore.Shared.Items[outputName] and QBCore.Shared.Items[outputName].label) or outputName
    sendDiscord(Config.Webhooks.Exchange,
        "Pawnshop • Exchange",
        ("**%s** (`%s` | %s) exchanged **%dx %s** → **%dx %s**."):format(ped, cid, steam, amount, inLabel, outQty, outLabel),
        3447003)
end

local function logStashMove(src, action, stashId, itemName, amount)
    local Player = QBCore.Functions.GetPlayer(src)
    local ped = GetPlayerName(src) or ("["..(src or "N/A").."]")
    local cid = Player and Player.PlayerData.citizenid or "Unknown"
    local steam = getSteamHex(src)
    local label = (itemName and QBCore.Shared.Items[itemName] and QBCore.Shared.Items[itemName].label) or itemName or "unknown_item"
    local color = (action == "PUT") and 15844367 or 15158332
    sendDiscord(Config.Webhooks.Stash,
        ("Pawnshop • Stash %s"):format(action),
        ("**%s** (`%s` | %s) %s **%dx %s** %s **%s**.")
            :format(ped, cid, steam,
                    action == "PUT" and "put" or "took",
                    tonumber(amount) or 1, label,
                    action == "PUT" and "into" or "from",
                    stashId),
        color)
end

---------------------------------
-- Duty Toggle
---------------------------------
RegisterNetEvent("qb-pawnshop:server:toggleDuty", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.job.name ~= "pawnshop" then return end
    local newState = not Player.PlayerData.job.onduty
    Player.Functions.SetJobDuty(newState)
    TriggerClientEvent('QBCore:Notify', src, newState and "You are now on duty." or "You are now off duty.", "success")
end)

---------------------------------
-- Exchange (multi-output)
---------------------------------
RegisterNetEvent("qb-pawnshop:server:exchangeChoice", function(inputName, outputName, amount)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.job.name ~= "pawnshop" or Player.PlayerData.job.onduty ~= true then return end

    amount = tonumber(amount) or 1
    if amount < 1 then return end

    local recipeList = Config.Exchange[inputName]
    if not recipeList then
        TriggerClientEvent('QBCore:Notify', src, "This item cannot be exchanged.", "error")
        return
    end

    local yield
    for _, o in ipairs(recipeList) do
        if o.item == outputName then yield = o.yield or 1 break end
    end
    if not yield then
        TriggerClientEvent('QBCore:Notify', src, "Invalid output selection.", "error")
        return
    end

    local have = Player.Functions.GetItemByName(inputName)
    if not have or (have.amount or 0) < amount then
        TriggerClientEvent('QBCore:Notify', src, "Not enough input items.", "error")
        return
    end

    if not Player.Functions.RemoveItem(inputName, amount) then
        TriggerClientEvent('QBCore:Notify', src, "Item removal failed.", "error")
        return
    end

    local outQty = amount * yield
    Player.Functions.AddItem(outputName, outQty)
    TriggerClientEvent('QBCore:Notify', src,
        ("Exchanged %dx %s → %dx %s"):format(
            amount,
            (QBCore.Shared.Items[inputName] and QBCore.Shared.Items[inputName].label or inputName),
            outQty,
            (QBCore.Shared.Items[outputName] and QBCore.Shared.Items[outputName].label or outputName)
        ), "success")
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[outputName] or {label = outputName}, "add")

    logExchange(src, inputName, amount, outputName, outQty)
end)

---------------------------------
-- Sell (full payout)
---------------------------------
RegisterNetEvent("qb-pawnshop:server:sell", function(itemName, amount)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.job.name ~= "pawnshop" or Player.PlayerData.job.onduty ~= true then return end

    amount = tonumber(amount) or 1
    if amount < 1 then return end

    local price = Config.SellItems[itemName]
    if not price then
        TriggerClientEvent('QBCore:Notify', src, "This item cannot be sold.", "error")
        return
    end

    local have = Player.Functions.GetItemByName(itemName)
    if not have or (have.amount or 0) < amount then
        TriggerClientEvent('QBCore:Notify', src, "Not enough items.", "error")
        return
    end

    if not Player.Functions.RemoveItem(itemName, amount) then
        TriggerClientEvent('QBCore:Notify', src, "Item removal failed.", "error")
        return
    end

    local total = price * amount
    Player.Functions.AddMoney("cash", total)
    TriggerClientEvent('QBCore:Notify', src,
        ("Sold %dx %s for $%d"):format(
            amount,
            (QBCore.Shared.Items[itemName] and QBCore.Shared.Items[itemName].label or itemName),
            total
        ), "success")

    logSell(src, itemName, amount, total)
end)

---------------------------------
-- Stashes (open via qb-inventory rework export)
---------------------------------
RegisterNetEvent("qb-pawnshop:server:openJobStash", function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.job.name ~= "pawnshop" or Player.PlayerData.job.onduty ~= true then return end

    exports['qb-inventory']:OpenInventory(src, Config.Stashes.Job.name, {
        maxweight = Config.Stashes.Job.weight,
        slots     = Config.Stashes.Job.slots,
        label     = Config.Stashes.Job.label
    })
end)

RegisterNetEvent("qb-pawnshop:server:openPersonalStash", function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.job.name ~= "pawnshop" or Player.PlayerData.job.onduty ~= true then return end

    local id = ("%s-%s"):format(Config.Stashes.Personal.name, Player.PlayerData.citizenid) -- change to cid if your core uses cid
    exports['qb-inventory']:OpenInventory(src, id, {
        maxweight = Config.Stashes.Personal.weight,
        slots     = Config.Stashes.Personal.slots,
        label     = Config.Stashes.Personal.label
    })
end)

----------------------------------------------------------------
-- UNIVERSAL STASH LOGGING (supports multiple qb-inventory forks)
----------------------------------------------------------------
local INVENTORY_DEBUG = Config.InventoryDebug == true

local function debugPrint(tag, ...)
    if INVENTORY_DEBUG then
        print(("[Pawnshop][DEBUG][%s]"):format(tag), ...)
    end
end

local function isInvType(v, prefix) return type(v)=="string" and v:sub(1,#prefix)==prefix end
local function stripPrefix(v, prefix) return v:gsub("^"..prefix, "") end

local function isPawnshopStash(stashId)
    return stashId and (
        stashId:find(Config.Stashes.Job.name, 1, true) or
        stashId:find(Config.Stashes.Personal.name, 1, true)
    )
end

-- 1) Classic: SetInventoryData
AddEventHandler("inventory:server:SetInventoryData", function(fromInv, toInv, fromSlot, toSlot, fromType, toType, count, item)
    local src = source
    debugPrint("SetInventoryData", fromInv, "->", toInv, "count:", count, "item:", type(item)=="table" and item.name or item)
    local itemName = (type(item)=="table" and item.name) or item
    if isInvType(fromInv, "player-") and isInvType(toInv, "stash-") then
        local stashId = stripPrefix(toInv, "stash-")
        if isPawnshopStash(stashId) then logStashMove(src, "PUT", stashId, itemName, count) end
    elseif isInvType(fromInv, "stash-") and isInvType(toInv, "player-") then
        local stashId = stripPrefix(fromInv, "stash-")
        if isPawnshopStash(stashId) then logStashMove(src, "TAKE", stashId, itemName, count) end
    end
end)

-- 2) Reworks: MoveItem / SwapItems with payload table
AddEventHandler("inventory:server:MoveItem", function(data)
    local src = source
    if not data then return end
    debugPrint("MoveItem", json.encode(data))
    local fromInv = data.fromInventory
    local toInv   = data.toInventory
    local item    = (data.item and data.item.name) or data.item
    local count   = data.count or (data.amount or data.qty)
    if isInvType(fromInv, "player-") and isInvType(toInv, "stash-") then
        local stashId = stripPrefix(toInv, "stash-")
        if isPawnshopStash(stashId) then logStashMove(src, "PUT", stashId, item, count) end
    elseif isInvType(fromInv, "stash-") and isInvType(toInv, "player-") then
        local stashId = stripPrefix(fromInv, "stash-")
        if isPawnshopStash(stashId) then logStashMove(src, "TAKE", stashId, item, count) end
    end
end)

AddEventHandler("inventory:server:SwapItems", function(data)
    local src = source
    if not data then return end
    debugPrint("SwapItems", json.encode(data))
    local fromInv = data.fromInventory
    local toInv   = data.toInventory
    local item    = (data.item and data.item.name) or data.item
    local count   = data.count or (data.amount or data.qty)
    if isInvType(fromInv, "player-") and isInvType(toInv, "stash-") then
        local stashId = stripPrefix(toInv, "stash-")
        if isPawnshopStash(stashId) then logStashMove(src, "PUT", stashId, item, count) end
    elseif isInvType(fromInv, "stash-") and isInvType(toInv, "player-") then
        local stashId = stripPrefix(fromInv, "stash-")
        if isPawnshopStash(stashId) then logStashMove(src, "TAKE", stashId, item, count) end
    end
end)

-- 3) Fallback: SaveInventory after changes (summary log)
AddEventHandler("inventory:server:SaveInventory", function(invType, invId, inventory)
    if invType ~= "stash" then return end
    local src = source
    if not src or not isPawnshopStash(invId) then return end
    debugPrint("SaveInventory", invType, invId, ("items:%s"):format(inventory and #inventory or 0))
    local total = 0
    for _, v in pairs(inventory or {}) do total = total + (v.amount or 1) end
    local Player = QBCore.Functions.GetPlayer(src)
    local ped = GetPlayerName(src) or ("["..src.."]")
    local cid = Player and Player.PlayerData.citizenid or "Unknown"
    local steam = getSteamHex(src)
    sendDiscord(Config.Webhooks.Stash,
        "Pawnshop • Stash Update",
        ("**%s** (`%s` | %s) modified **%s**. Total items now: **%d**")
            :format(ped, cid, steam, invId, total),
        9807270)
end)
