# Pawn Shop Job (QBCore)

A simple **Pawn Shop** job/resource for FiveM built on **QBCore**. It adds:
- A main target to open the pawn shop menu (on duty only)
- A separate **On/Off Duty** target for employees
- **Selling** certain items for cash (server‑side prices)
- A **multi‑output Exchange** system (convert one item into a chosen material)
- Two stashes: **Job Stash** (shared while on duty) and **Personal Stash**
- Optional Discord logging for **Sales**, **Exchanges**, and **Stash** activity (via webhooks)

> ⚠️ This version is **fully English**. Non‑English comments/labels have been translated.
> ⚠️ Replace any `YOUR_WEBHOOK_URL_HERE` in `config.lua` with your **own** Discord webhook URLs.
> ⚠️ The original files you provided appear to have a few truncated sections. The code here mirrors your structure and comments one‑to‑one, but you may still need to complete any missing logic in your original `server.lua` if it was incomplete in the upload.

## Requirements

- `qb-core`
- `qb-target`
- `qb-inventory` (with stash support)
- `ox_lib`
- `oxmysql`

These are already listed under `dependencies` in `fxmanifest.lua`.

## Installation

1. Drop this folder into your `resources` (e.g. `resources/[jobs]/qb-pawnshop`).  
2. Ensure the resource after its dependencies in your `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure qb-core
   ensure qb-target
   ensure qb-inventory
   ensure qb-pawnshop
   ```
3. Configure `config.lua`:
   - **Webhook URLs:** Put your Discord webhooks into `Config.Webhooks.Sell`, `Exchange`, and `Stash` (or leave blank to disable).
   - **Locations:**
     - `Config.PawnShopCoords`: main shop menu target (vector3).
     - `Config.DutyCoords`: on/off duty target (vector3).
   - **Map Blip:** `Config.Blip` (label, sprite, color, scale, display).
   - **Labels:** `Config.CustomLabels` for custom display names.
   - **Sell Prices:** `Config.SellItems` → `itemName = price`.
   - **Exchange Recipes:** `Config.Exchange` → `inputItem = {{ item = "outItem", yield = N }, ...}}`.
   - **Stashes:** `Config.Stashes.Job` and `Config.Stashes.Personal` (name, label, slots, weight).

## Job / Permissions

- Job name is assumed to be **`pawnshop`**.
- Only players with job `pawnshop` **and** `onduty == true` can open the main pawn shop menu, sell, exchange, or open stashes.

## How it works

### Targets
- **Main Menu Target** (`Config.PawnShopCoords`): opens a menu for **Sell**, **Exchange**, and **Stashes**. Only visible while on duty.
- **Duty Target** (`Config.DutyCoords`): toggles **On/Off Duty** for job `pawnshop`.

### Selling
- Items and prices are set in `Config.SellItems` (server‑side).  
- Server validates on‑duty and inventory, removes items, and gives cash.  
- A Discord log is sent if `Config.Webhooks.Sell` is set.

### Exchange (Multi‑Output)
- Recipe format:
  ```lua
  Config.Exchange = {
      ["phone"] = {
          { item = "steel", yield = 1 },
          { item = "plastic", yield = 1 }
      },
      ["recyclablematerial"] = {
          { item = "iron", yield = 1 },
          { item = "copper", yield = 1 },
          { item = "aluminum", yield = 1 }
      }
  }
  ```
- Client asks which output the player wants; server validates and grants outputs.  
- A Discord log is sent if `Config.Webhooks.Exchange` is set.

### Stashes
- **Job Stash** (`Config.Stashes.Job`): shared between employees **when on duty**.
- **Personal Stash** (`Config.Stashes.Personal`): unique per employee (`name-citizenid`).  
- Stash activity can be logged to `Config.Webhooks.Stash` (the server listens to inventory events).

## Configuration Highlights

```lua
-- Map blip
Config.Blip = { label = "Pawn Shop", sprite = 267, color = 5, scale = 0.8, display = 4 }

-- Sell prices
Config.SellItems = {
    ["iron"] = 2, ["copper"] = 2, ["goldbar"] = 2, ["silver"] = 2,
    ["plastic"] = 2, ["aluminum"] = 2, ["steel"] = 2
}

-- Exchange (multi‑output)
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
    ["rolex"] = {
        { item = "goldbar",  yield = 1 },
        { item = "aluminum", yield = 1 },
    }
}
```

## Logging

Set your Discord webhooks in `Config.Webhooks`:
- `Sell` – when employees sell items
- `Exchange` – when items are exchanged
- `Stash` – when pawnshop stashes change

You can brand the embed with `Config.LogBrand` (`name`, optional `icon`).

## Notes

- This resource targets **Lua 5.4** and `fx_version 'cerulean'` per `fxmanifest.lua`.
- The uploaded `server.lua` in your archive looked partially truncated at points; if you see runtime errors, compare against your original source and fill any missing logic.
- If you use different item names or another inventory, update `Config.CustomLabels` and the relevant server events accordingly.

## Credits

- Original author: **iliyayz**
- English translation & README: **this commit**
