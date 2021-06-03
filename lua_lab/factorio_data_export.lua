--[[ init ]]-------------------------------------------------------------------
local opt = opt or error()
local args = opt.args
local mods = opt.mods
local dbglog = opt.dbglog
local raw = opt.raw
local tprint = opt.tprint

for _, v in ipairs(mods) do
    mods[v["name"]] = v.handle
end

local serpent = require("serpent")
local gd_image = require("factorio.gd_image")(opt)
local util = require("factorio.utils")
local L = require("factorio.locale").init(args.language, mods, dbglog)

--[[ prepare ]]----------------------------------------------------------------

local items_ptr = {}
local items_as_ingredient = {}
local items_as_product = {}
local items_used = {}
local items_ready = {}
local items_burnt = {}
local items_launch = {}

local recipes_enabled = {}
local recipes_ptr = {}
local recipes_disabled_ptr = {}
local recipes_sorted = {}
local recipes_extra = {}

local categories_used = {}
local icons = {}
local img_cache = {}
local copies = {}
local producers = {}
local silos = {}
local burners = {}
local launches = {}
local boilers = {}

--[[ level 4 ]]----------------------------------------------------------------

local function get_IconSpecification(ptr)
    local result
    if ptr.icons then
        result = ptr.icons
        for i = 1, #result do
            local icon = result[i]
            if nil == icon.icon_size then
                icon.icon_size = ptr.icon_size
            end
        end
    elseif ptr.icon then
        result = { [1] = {
                icon = ptr.icon,
                icon_size = ptr.icon_size,
                icon_mipmaps = ptr.icon_mipmaps,
            }}
    end

    return result
end


--[[ level 3 ]]----------------------------------------------------------------

local function set_IngredientPrototype(ptr)
    for j = 1, #ptr.ingredients do
        local p = ptr.ingredients[j]
        -- [PYANODONS] handle null ingredients
        if p then
            if not p["type"] then
                p["type"] = "item"
            end
            if p[1] then
                p["name"] = p[1]
                p["amount"] = p[2]
                p[1] = nil
                p[2] = nil
            end

            items_as_ingredient[p["name"]] = true
        end
    end
end


local function set_ProductPrototype(ptr)
    if ptr["results"] then
        for i = 1, #ptr["results"] do
            local p = ptr["results"][i]
            if not p["type"] then
                p["type"] = "item"
            end
            if p[1] then
                p["name"] = p[1]
                p["amount"] = p[2]
                p[1] = nil
                p[2] = nil
            end
            items_as_product[p["name"]] = true
        end
    elseif ptr["result"] then
        ptr["results"] = {}
        ptr["results"][1] = {
            ["type"] = "item",
            ["name"] = ptr["result"],
            ["amount"] = ptr["result_count"] or 1
        }

        items_as_product[ptr["result"]] = true

        ptr["result"] = nil
        ptr["result_count"] = nil
    else
        error(ptr["name"] .. ": no result(s)!")
    end
end


local function set_IconSpecification(ptr, from)
    local ico = get_IconSpecification(ptr)
    if not ico and from then
        ico = get_IconSpecification(from)
    end
    if not ico then
        print(debug.traceback())
        local from_name = (from and from.name) or "<nil>"
        error(ptr.name .. " and " .. from_name .. " has no icon(s)!")
    end

    ptr.icon = nil
    ptr.icon_size = nil
    ptr.icon_mipmaps = nil
    ptr.icons = ico
end


local function get_item_ptr(item_name, item_type, dbg)
    local item = items_ptr[item_name]
    if item then return item end

    -- поиск среди type="fluid"
    local ptr = raw["fluid"]
    item = ptr and ptr[item_name]
    if item then return item end

    if item_type then
        dbglog(3, (item_type or "nil"), ".", item_name, ": ptr not found! (" .. dbg .. ") ..\n")
    end
    return nil
end


local function get_entry_key(entry, key)
    local entry_key = entry[key]
    if not entry_key then
        if "subgroup" == key then
            if "fluid" == entry["type"] then
                entry_key = "fluid"
            else
                entry_key = "other"
            end
        end
    end
    return entry_key
end


--[[ level 2 ]]----------------------------------------------------------------

local function set_recipe_data(ptr, mode)
    set_IngredientPrototype(ptr[mode])
    set_ProductPrototype(ptr[mode])

    if nil == ptr[mode]["energy_required"] then
        ptr[mode]["energy_required"] = 0.5
    end
    if nil == ptr[mode]["enabled"] then
        ptr[mode]["enabled"] = true
    end
    if nil == ptr[mode]["hidden"] then
        ptr[mode]["hidden"] = false
    end

    local main_product = ptr["main_product"]
    if not main_product then
        main_product = ptr[mode]["main_product"]
    end
    if not main_product or main_product == "" then
        main_product = ptr[mode]["result"]
    end
    local product_count = #ptr[mode]["results"]

    if product_count > 1 then
        if nil == main_product or "" == main_product then
            --[[ use recipe data ]]--

            set_IconSpecification(ptr)

            assert(ptr["subgroup"], ptr["name"] .. ": recipe has no subgroup!")

            ptr["loc_name"] = L(ptr)
        else
            --[[ use main_product data ]]--

            -- TODO: unchecked branch
            local item
            local res = ptr[mode]["results"]
            for i = 1, #res do
                local p = res[i]
                if main_product == p["name"] then
                    local item_name = p["name"]
                    local item_type = p["type"]
                    item = get_item_ptr(item_name, item_type, "1")
                    ptr["main_product_ptr"] = item
                    break
                end
            end

            set_IconSpecification(item)

            ptr["subgroup"] = get_entry_key(item, "subgroup")
            ptr["order"] = item["order"]

            ptr["loc_name"] = L(item)
        end
    else -- product_count == 1
        if "" == main_product then
            --[[ use recipe data ]]--

            set_IconSpecification(ptr)

            assert(ptr["subgroup"], ptr["name"] .. ": recipe haven't subgroup!")
            assert(ptr["order"], ptr["name"] .. ": recipe haven't order!")

            local loc_name = L(ptr)
            ptr["loc_name"] = loc_name
        else
            --[[ use recipe or result data ]]--

            local res = ptr[mode]["results"][1]
            local item_name = res["name"]
            local item_type = res["type"]
            local item = get_item_ptr(item_name, item_type, "2")

            ptr["main_product_ptr"] = item

            set_IconSpecification(ptr, item)

            ptr["subgroup"] = ptr["subgroup"] or get_entry_key(item, "subgroup")
            ptr["order"] = ptr["order"] or item["order"]

            ptr["loc_name"] = L(ptr, true) or L(item)
        end
    end -- product_count > 1
end


local function get_order_sub_group(entry)
    local order          = entry["order"] or entry.name
    local subgroup       = entry["subgroup"] or ("fluid" == entry.type and "fluid") or "other"
    local subgroup_ptr   = raw["item-subgroup"][subgroup] or error("no subgroup")
    local subgroup_order = subgroup_ptr["order"] or error("no subgroup order")
    local group          = subgroup_ptr["group"] or error("subgroup have not group")
    local group_ptr      = raw["item-group"][group] or error("no group")
    local group_order    = group_ptr["order"] or error("no group order")
    return order, subgroup, subgroup_order, group, group_order
end


local _row, _col, _old_g, _old_s
local function calculate_row(gr, sb)
    if nil == gr or _old_g ~= gr then
        _old_g = gr
        _old_s = ""
        _row = 0
        _col = 0
    end
    if _old_s ~= sb then
        _old_s = sb
        _row = _row + 1
        _col = 0
    end
    if _col == 10 then
        _col = 0
        _row = _row + 1
    end
    _col = _col + 1
    return _row
end


--[[ icons ]]--------------------------


local function save_icon(entry, id)
    if not id then
        id = entry.name
    end
    local icon = { id = id, path = {} }
    local ptr = entry.icon and {entry} or entry.icons
    if not ptr then
        ptr = entry.main_product_ptr.icons
        if not ptr then
            error(id .. ", no icon(s) !!")
        end
    end
    local i_sz = entry.icon_size or 64
    local serialized = ""
    for _, e in ipairs(ptr) do
        local t = {}
        t.icon = e.icon
        t.size = e.icon_size or i_sz
        t.mips = e.icon_mipmaps or 1
        t.tint = e.tint
        t.scale = e.scale -- may be nil
        t.shift = e.shift
        if (e.tint) then
            serialized = string.format("%s,%s.%s.%s.%s.%s.%s.%s.%s", serialized, t.icon, t.size, t.mips, t.tint.r, t.tint.g, t.tint.b, t.scale, t.shift)
        else
            serialized = string.format("%s,%s.%s.%s.%s.%s", serialized, t.icon, t.size, t.mips, t.scale, t.shift)
        end
        table.insert(icon.path, t)
    end

    if entry.type == "recipe" then
        local item = items_ptr[id]
        if item then
            local icon2 = { id = id, path = {} }
            local ptr2 = item.icon and {item} or item.icons
            local i_sz2 = item.icon_size or 64
            local serialized2 = ""
            for _, e in ipairs(ptr2) do
                local t = {}
                t.icon = e.icon
                t.size = e.icon_size or i_sz2
                t.mips = e.icon_mipmaps or 1
                t.tint = e.tint
                t.scale = e.scale -- may be nil
                t.shift = e.shift
                if (e.tint) then
                    serialized2 = string.format("%s,%s.%s.%s.%s.%s.%s.%s.%s", serialized2, t.icon, t.size, t.mips, t.tint.r, t.tint.g, t.tint.b, t.scale, t.shift)
                else
                    serialized2 = string.format("%s,%s.%s.%s.%s.%s", serialized2, t.icon, t.size, t.mips, t.scale, t.shift)
                end
                table.insert(icon2.path, t)
            end

            if serialized ~= serialized2 then
                icon.id = icon.id .. "|recipe"
                if img_cache[serialized2] then
                    local ref = {
                        id = icon2.id,
                        ref = img_cache[serialized2]
                    }
                    table.insert(copies, ref)
                else
                    img_cache[serialized2] = icon2.id
                    table.insert(icons, icon2)
                end
            end
        end
    end
    
    if img_cache[serialized] then
        local ref = {
            id = icon.id,
            ref = img_cache[serialized]
        }
        table.insert(copies, ref)
    else
        img_cache[serialized] = icon.id
        table.insert(icons, icon)
    end
end


local function process_producers(entry, drill)
    if drill then
        local cats = entry.resource_categories or {"basic-solid"}
        for _, cat in ipairs(cats) do
            if not producers[cat] then
                producers[cat] = {}
            end
            table.insert(producers[cat], entry.name)
        end
    else
        local cats = entry.crafting_categories
        if cats then
            for i = 1, #cats do
                local cat = cats[i]
                if not producers[cat] then
                    producers[cat] = {}
                end
                table.insert(producers[cat], entry.name)
            end
        end
    end

    local type = (entry.energy_source and entry.energy_source.type) or "burner"
    local usage = entry.consumption
    if type == "burner" and usage then
        local cat = ((entry.energy_source and entry.energy_source.fuel_category) or (entry.burner and entry.burner.fuel_category)) or "chemical"
        if not burners[cat] then
            burners[cat] = {}
        end
        usage = util.convert_energy(usage) / 1000
        local b = {
            id = entry.name,
            usage = usage
        }
        table.insert(burners[cat], b)
    end
end


local function process_item(p, t, limitation)
    local belt = raw["transport-belt"][p.name]
    if belt then
        t.belt = belt and { speed = 480.0 * belt.speed }
    end

    local beacon = raw["beacon"][p.name]
    if beacon then
        local type = beacon.energy_source.type
        local category = beacon.energy_source.fuel_category
        local usage = beacon.energy_usage
        usage = util.convert_energy(usage) / 1000
        t.beacon = {
            effectivity = beacon.distribution_effectivity,
            range = beacon.supply_area_distance,
            type = type,
            category = category,
            usage = usage,
            modules = beacon.module_specification.module_slots
        }
    end
    
    local cargo_wagon = raw["cargo-wagon"][p.name]
    if cargo_wagon then
        t.cargoWagon = {
            size = cargo_wagon.inventory_size
        }
    end
    
    local fluid_wagon = raw["fluid-wagon"][p.name]
    if fluid_wagon then
        t.fluidWagon = {
            capacity = fluid_wagon.capacity
        }
    end

    local processed = false
    local mach = raw["mining-drill"][p.name]
    if mach then
        processed = true
        local type = mach.energy_source.type
        local category = mach.energy_source.fuel_category
        local pollution = mach.energy_source.emissions_per_minute
        local usage = mach.energy_usage
        usage = util.convert_energy(usage) / 1000
        local drain
        if "electric" == type and mach.energy_source.drain then
            drain = util.convert_energy(mach.energy_source.drain)
        end
        if "burner" == type and not category then
            category = "chemical"
        end
        t.factory = {
            speed = mach.mining_speed or 1.0,
            modules = mach.module_specification
            and mach.module_specification.module_slots
            or 0,
            usage = usage,
            drain = drain,
            pollution = pollution,
            type = type,
            category = category,
            mining = true
        }

        process_producers(mach, true)
    end
    mach = raw["offshore-pump"][p.name]
    if mach then
        processed = true
        t.factory = {
            speed = mach.pumping_speed * 60, -- pumping_speed per tick
            modules = mach.module_specification
            and mach.module_specification.module_slots
            or 0,
        }
        local type = mach.energy_source and mach.energy_source.type
        if type then
            local category = mach.energy_source.fuel_category
            local pollution = mach.energy_source.emissions_per_minute
            local usage = mach.energy_usage
            usage = util.convert_energy(usage) / 1000
            local drain
            if "electric" == type and mach.energy_source.drain then
                drain = util.convert_energy(mach.energy_source.drain)
            end
            if "burner" == type and not category then
                category = "chemical"
            end
            t.factory.type = type
            t.factory.usage = usage
            t.factory.category = category
            t.factory.drain = drain
            t.factory.pollution = pollution
        end

        if mach.fluid then
            local f = get_item_ptr(mach.fluid)
            local r = {
                id = mach.fluid,
                name = L(f),
                time = 1,
                producers = { mach.name }
            }
            table.insert(recipes_extra, r)
        end
    end
    mach = raw["furnace"][p.name]
    if mach then
        processed = true
        local type = mach.energy_source.type
        local category = mach.energy_source.fuel_category
        local pollution = mach.energy_source.emissions_per_minute
        local usage = mach.energy_usage
        usage = util.convert_energy(usage) / 1000
        local drain
        if "electric" == type and mach.energy_source.drain then
            drain = util.convert_energy(mach.energy_source.drain)
        end
        if "burner" == type and not category then
            category = "chemical"
        end
        t.factory = {
            speed = mach.crafting_speed or 1.0,
            modules = mach.module_specification
            and mach.module_specification.module_slots
            or 0,
            type = type,
            usage = usage,
            category = category,
            drain = drain,
            pollution = pollution,
        }

        process_producers(mach)
    end
    mach = raw["assembling-machine"][p.name]
    if mach then
        processed = true
        local type = mach.energy_source.type
        local category = mach.energy_source.fuel_category
        local pollution = mach.energy_source.emissions_per_minute
        local usage = mach.energy_usage
        usage = util.convert_energy(usage) / 1000
        local drain
        if "electric" == type and mach.energy_source.drain then
            drain = util.convert_energy(mach.energy_source.drain)
        end
        if "burner" == type and not category then
            category = "chemical"
        end
        t.factory = {
            speed = mach.crafting_speed or 1.0,
            modules = mach.module_specification
            and mach.module_specification.module_slots
            or 0,
            type = type,
            usage = usage,
            category = category,
            drain = drain,
            pollution = pollution,
        }

        process_producers(mach)
    end
    mach = raw["lab"][p.name]
    if mach then
        processed = true
        local type = mach.energy_source.type
        local category = mach.energy_source.fuel_category
        local pollution = mach.energy_source.emissions_per_minute
        local usage = mach.energy_usage
        usage = util.convert_energy(usage) / 1000
        local drain
        if "electric" == type and mach.energy_source.drain then
            drain = util.convert_energy(mach.energy_source.drain)
        end
        if "burner" == type and not category then
            category = "chemical"
        end
        t.factory = {
            speed = mach.researching_speed or 1.0,
            modules = mach.module_specification
            and mach.module_specification.module_slots
            or 0,
            type = type,
            usage = usage,
            category = category,
            drain = drain,
            pollution = pollution,
            research = true
        }
    end
    mach = raw["boiler"][p.name]
    if mach then
        processed = true
        local type = mach.energy_source.type
        local category = mach.energy_source.fuel_category
        local pollution = mach.energy_source.emissions_per_minute
        local usage = mach.energy_consumption
        usage = util.convert_energy(usage) / 1000
        local drain
        if "electric" == type and mach.energy_source.drain then
            drain = util.convert_energy(mach.energy_source.drain)
        end
        if "burner" == type and not category then
            category = "chemical"
        end
        local speed = 1.0
        if mach.target_temperature == 165 then
            speed = usage / 30
            table.insert(boilers, mach.name)
        end
        t.factory = {
            speed = speed,
            modules = 0,
            type = type,
            usage = usage,
            category = category,
            drain = drain,
            pollution = pollution,
        }
    end

    local mach = raw["rocket-silo"][p.name]
    if mach then
        local type = mach.energy_source.type
        local category = mach.energy_source.fuel_category
        local pollution = mach.energy_source.emissions_per_minute
        local usage = mach.energy_usage
        usage = util.convert_energy(usage) / 1000
        local drain
        if "electric" == type and mach.energy_source.drain then
            drain = util.convert_energy(mach.energy_source.drain)
        end
        if "burner" == type and not category then
            category = "chemical"
        end

        -- Calculate number of ticks for launch
        -- Based on https://github.com/ClaudeMetz/FactoryPlanner/blob/master/modfiles/data/handlers/generator_util.lua#L335
        local ticks = 2435 -- default to vanilla rocket silo value
        local rocket = mach.rocket_entity
        if rocket then
            local rocket_proto = raw["rocket-silo-rocket"][rocket]
                        
            local rocket_flight_threshold = 0.5  -- hardcoded in the game files
            local launch_steps = {
                lights_blinking_open = (1 / mach.light_blinking_speed) + 1,
                doors_opening = (1 / mach.door_opening_speed) + 1,
                doors_opened = (mach.rocket_rising_delay or 30) + 1,
                rocket_rising = (1 / rocket_proto.rising_speed) + 1,
                rocket_ready = 14,  -- estimate for satellite insertion delay
                launch_started = (mach.launch_wait_time or 120) + 1,
                engine_starting = (1 / rocket_proto.engine_starting_speed) + 1,
                -- This calculates a fractional amount of ticks. Also, math.log(x) calculates the natural logarithm
                rocket_flying = math.log(1 + rocket_flight_threshold * rocket_proto.flying_acceleration
                  / rocket_proto.flying_speed) / math.log(1 + rocket_proto.flying_acceleration),
                lights_blinking_close = (1 / mach.light_blinking_speed) + 1,
                doors_closing = (1 / mach.door_opening_speed) + 1
            }
        
            local total_ticks = 0
            for _, ticks_taken in pairs(launch_steps) do
                total_ticks = total_ticks + ticks_taken
            end
        
            ticks = math.floor(total_ticks + 0.5)
        end

        t.factory = {
            speed = mach.crafting_speed or 1.0,
            modules = mach.module_specification
            and mach.module_specification.module_slots
            or 0,
            type = type,
            usage = usage,
            category = category,
            drain = drain,
            pollution = pollution,
            silo = {
                parts = mach.rocket_parts_required,
                launch = ticks,
            }
        }

        process_producers(mach)

        table.insert(silos, { name = p.name, parts = mach.rocket_parts_required })
    end

    local mach = raw["reactor"][p.name]
    if mach then
        local usage = mach.consumption
        usage = util.convert_energy(usage) / 1000
        
        if mach.burner then
            t.factory = {
                speed = 1.0,
                modules = 0,
                type = "burner",
                category = mach.burner.fuel_category,
                usage = usage
            }
        else
            t.factory = {
                speed = 1.0,
                modules = 0,
                type = mach.energy_source.type,
                category = mach.energy_source.fuel_category,
                usage = usage
            }
        end

        process_producers(mach)
    end

    local mod = raw["module"][p.name]
    if mod then
        local effect = mod.effect

        local speed = effect.speed and effect.speed.bonus --or 0.0
        local productivity = effect.productivity and effect.productivity.bonus --or 0.0
        local consumption = effect.consumption and effect.consumption.bonus --or 0.0
        local pollution = effect.pollution and effect.pollution.bonus --or 0.0

        t.module = {
            productivity = productivity,
            speed = speed,
            consumption = consumption,
            pollution = pollution,
        }

        local limit = mod.limitation
        if limit then
            if not limitation["productivity-module"] then
                limitation["productivity-module"] = limit
            end
            t.module.limitation = "productivity-module"
        end
    end

    local main = p["main_product_ptr"]
    if not main then
        main = p
    end
    local fuel_value = main.fuel_value
    if fuel_value then
        local fuel = util.convert_energy(fuel_value) / 1000000.0 -- to MJ
        local category = main.fuel_category
        local result = main.burnt_result

        if category then
            t.fuel = {
                value = fuel,
                category = category,
                result = result
            }
    
            if result then
                local r = {
                    id = t.id,
                    result = result,
                    category = category
                }
                table.insert(items_burnt, r)
            end
        end
    end

    local launch_product = main.rocket_launch_product
    local launch_products = main.rocket_launch_products
    if launch_product or launch_products then
        local launch = { input = t.id, products = {} }
        if launch_product then
            local p = launch_product
            if p.name then
                local qty

                if p.amount_min then
                    qty = (p.amount_max + p.amount_min) / 2
                else
                    qty = p.amount
                end

                if p.probability then
                    qty = qty * p.probability
                end

                launch.product = p.name
                launch.products[p.name] = qty
            else
                launch.product = p[1]
                launch.products[p[1]] = p[2]
            end
        end
        if launch_products then
            for i = 1, #launch_products do
                local p = launch_products[i]
                if p.name then
                    local qty
    
                    if p.amount_min then
                        qty = (p.amount_max + p.amount_min) / 2
                    else
                        qty = p.amount
                    end
    
                    if p.probability then
                        qty = qty * p.probability
                    end
                    
                    launch.products[p.name] = (launch.products[p.name] or 0) + qty
                else
                    launch.products[p[1]] = (launch.products[p[1]] or 0) + p[2]
                end
            end
        end
        
        table.insert(items_launch, launch)
    end
end


--[[ level 1 ]]----------------------------------------------------------------

local function prepare()
    local to_clean = {
        "noise-layer", "noise-expression", "explosion", "optimized-particle",
        "corpse", "virtual-signal", "tile", "decorative", "optimized-decorative",
        "tutorial", "custom-input", "gui-style", "font", "utility-constants",
        "utility-sounds", "god-controller", "editor-controller",
        "spectator-controller", "mouse-cursor", "ambient-sound", "wind-sound",
        "character-corpse", "character", "simple-entity","sticker", "shortcut",
        "trivial-smoke", "tree", "stream", "flying-text", "fire", "autoplace-control",
        "crash-site", "projectile"
    }
    for i = 1, #to_clean do
        raw[to_clean[i]] = nil
    end

    dbglog(1, "process all items...\n")
    local i, j = 0, 0
    for _, r in pairs(raw) do
        for _, v in pairs(r) do
            if v.stack_size and v.type == "fluid" then
                dbglog(1, "Setting fluid stack size to nil: '", v.name, "'\n")
                v.stack_size = nil
            end

            if v.stack_size then
                if "item" ~= v.type then
                    j = j + 1
                else
                    i = i + 1
                end
                items_ptr[v["name"]] = v
            end

            if v.rocket_launch_product then
                items_as_ingredient[v.name] = true
                if v.rocket_launch_product.type == "item" then
                    items_as_product[v.rocket_launch_product.name] = true
                else
                    items_as_product[v.rocket_launch_product[1]] = true
                end
            end

            if v.burnt_result then
                items_as_product[v.burnt_result] = true
            end
        end
    end
    dbglog(-1, " found ", i, " with type=\"item\", ", j, " with other type\n")
end


local function process_technology()
    dbglog(1, "process technologies...")
    local c = 0
    for _, tech in pairs(raw["technology"]) do
        local eff = tech["effects"]
        if eff then
            for i = 1, #eff do
                local eff_i = eff[i]
                if "unlock-recipe" == eff_i["type"] then
                    c = c + 1
                    recipes_enabled[eff_i["recipe"]] = true
                end
            end
        end
    end
    dbglog(-1, " enabled ", c, " recipes\n")
end


local function process_recipes()
    dbglog(1, "process recipes...")
    local cne, cee, cd = 0, 0, 0 -- normal enabled, expensive enabled, disabled

    for name, rcp in pairs(raw["recipe"]) do
        local skip = false
        if args.factorio_lab_hacks and rcp.hide_from_player_crafting then
            skip = true
        end
        -- [BASE] ignore barrel emptying recipes to reduce circular recipes
        local empty = string.find(rcp.name, "^empty%-.+%-barrel$")
        if empty then
            skip = true
        end
        -- [SE] ignore SE delivery cannon recipes
        local delivery_cannon = string.find(rcp.name, "^se%-delivery%-cannon%-pack%-")
        if delivery_cannon then
            skip = true
        end
        local delivery_weapon_cannon = string.find(rcp.name, "^se%-delivery%-cannon%-weapon%-pack%-")
        if delivery_weapon_cannon then
            skip = true
        end
        -- [BA] ignore void recipes
        local void = string.find(rcp.name, "^void%-")
        if void then
            skip = true
        end
        -- [NLS] ignore unboxing recipes
        local unboxing = string.find(rcp.name, "^nullius%-unbox%-")
        if unboxing then
            skip = true
        end
        if rcp["results"] and #rcp["results"] == 0 then
            dbglog(1, "Skipping recipe '" .. rcp.name .. "' because it has no results.\n")
            skip = true
        end

        local silo_recipe = false
        for _, r in pairs(raw["rocket-silo"]) do
            if (r.fixed_recipe == rcp.name) then
                silo_recipe = true
            end
        end

        if (not (true == rcp.hidden) or silo_recipe) and (not (false == rcp.enabled) or recipes_enabled[name]) and (not skip) then
            if nil == rcp.category then
                rcp.category = "crafting"
            end

            -- find recipe data
            if not rcp["normal"] then
                rcp["normal"] = rcp -- ptr to main
            end
            set_recipe_data(rcp, "normal")
            cne = cne + 1

            if not rcp["expensive"] then
                rcp["expensive"] = rcp["normal"] -- ptr to normal
            else
                set_recipe_data(rcp, "expensive")
                cee = cee + 1
            end

            table.insert(recipes_ptr, rcp)
        else
            cd = cd + 1
            table.insert(recipes_disabled_ptr, rcp)
        end
    end

    dbglog(-1, (" found %d normal, %d expensive, %d hidden\n"):format(cne, cee, cd))

    dbglog(4, "\nhidden recipes: ")
    for k, v in ipairs(recipes_disabled_ptr) do
        dbglog(-4, v.name, ", ")
    end
    dbglog(-4, "\n")
end


local function sort_recipes()
    dbglog(1, "sort recipes...\n")
    local t = {}
    for i = 1, #recipes_ptr do
        local ptr = recipes_ptr[i]
        local ord, sgr, sgo, grp, gro = get_order_sub_group(ptr)
        table.insert(t, {ptr, ptr["name"], ord, sgr, sgo, grp, gro})

        categories_used[grp] = true
    end
    util.sort_by(t, 7, 6, 5, 4, 3, 2)

    local c = 0
    for k, v in pairs(items_as_ingredient) do c = c + 1 end
    items_as_ingredient.count = c
    c = 0
    for k, v in pairs(items_as_product) do c = c + 1 end
    items_as_product.count = c
    dbglog(1, ("\tfound %d ingredients and %d products\n")
        :format(items_as_ingredient.count, items_as_product.count))

    dbglog(1, "clear items...\n")
    for i = 1, #t do
        local s = t[i]
        table.insert(recipes_sorted, {ptr = s[1], subgroup = s[4], group = s[6]})

        save_icon(s[1])

        local name = s[1]["name"]

        local ptr = get_item_ptr(name, nil, "3")
        if ptr then
            items_ready[name] = ptr
            items_as_ingredient[name] = nil
            items_as_product[name] = nil
        else
            -- TODO
        end
    end

    c = 0
    for k, v in pairs(items_as_ingredient) do
        if "count" ~= k then
            c = c + 1
            items_used[k] = true
        end
    end
    dbglog(2, "\t", c, " ingredients")

    c = 0
    for k, v in pairs(items_as_product) do
        if "count" ~= k then
            c = c + 1
            items_used[k] = true
        end
    end
    dbglog(-2, " and ", c, " products left\n")

    categories_used["other"] = true -- manual add
    local cats = categories_used
    t = {}
    for c, _ in pairs(cats) do
        local gr = raw["item-group"][c]
        table.insert(t, {gr, gr.name, gr.order})
    end
    util.sort_by(t, 3, 2)

    categories_used = {}
    for i = 1, #t do
        local c = t[i][1]
        table.insert(categories_used, { id = c.name, name = L(c)})

        save_icon(c)
    end
end


local function sort_items()
    local t = {}
    for k, _ in pairs(items_used) do
        local item_ptr = get_item_ptr(k, nil, "4")
        if item_ptr ~= nil then
            local ord, sgr, sgo, grp, gro = get_order_sub_group(item_ptr)
            table.insert(t, {item_ptr, item_ptr["name"], ord, sgr, sgo, grp, gro})
        end
    end
    util.sort_by(t, 7, 6, 5, 4, 3, 2)

    items_used = {}
    dbglog(2, "other items: ")
    local s = {}
    for i = 1, #t do
        local ptr = t[i][1]
        table.insert(items_used, { t[i][1], t[i][4], t[i][6] })
        save_icon(ptr)
        table.insert(s, t[i][2])
    end
    dbglog(-2, table.concat(s, ", "), "\n")
end


local function make_items()
    local out = {}
    local limitation = {}
    calculate_row() -- reset

    for i = 1, #recipes_sorted do
        local r = recipes_sorted[i]
        local p = r.ptr
        local t = {}

        t.id = p.name
        t.name = p.loc_name

        local item = items_ready[p.name]
        if item then
            t.name = L(item)
            t.stack = item.stack_size
            t.category = r.group
            t.row = calculate_row(r.group, r.subgroup)

            process_item(p, t, limitation)

            table.insert(out, t)
        end
    end

    -- now raw-resources, etc
    for i = 1, #items_used do
        local item = items_used[i]
        local p = item[1]
        local t = {}

        if not p.localised_name then
            if raw["ammo-turret"][p.name] and raw["ammo-turret"][p.name].localised_name then
                p.localised_name = raw["ammo-turret"][p.name].localised_name
            end
            if p.localised_name then
                dbglog(1, "Found localised name for " .. p.name .. "\n")
            end
        end

        t.id = p.name
        t.name = L(p)
        t.stack = p.stack_size
        t.category = "other"
        t.subgroup = p.subgroup
        t.row = calculate_row("other", item[2])

        process_item(p, t, limitation)

        table.insert(out, t)
    end

    return out, limitation
end


local function make_launch_recipes(out, recipe)
    for a = 1, #recipe.producers do
        local producer = recipe.producers[a]
        for b = 1, #silos do
            local silo = silos[b]
            if silo.name == producer then
                for c = 1, #items_launch do
                    local item = items_launch[c]
                    -- process items_launch to build launch recipes
                    local id = item.input .. "-launch"
                    if item.product then
                        id = item.product
                        local fallback = false
                        for i = 1, #recipes_ptr do
                            local r = recipes_ptr[i]
                            if r.name == id then
                                fallback = true
                                break
                            end
                        end
                        
                        if not fallback then
                            for i = 1, #out do
                                local r = out[i]
                                if r.id == id then
                                    fallback = true
                                    break
                                end
                            end
                        end

                        if fallback then
                            id = item.input .. "-" .. recipe.id .. "-" .. producer
                            dbglog(1, "Found duplicate recipe id for launch product: '" .. item.product .. "', using unique id '" .. id .. "'\n")
                        end
                    end
                    local ptr = get_item_ptr(item.input)
                    if id ~= item.product then
                        save_icon(ptr, id)
                    end
                    local r = {
                        id = id,
                        name = L(ptr) .. ' launch',
                        ["in"] = {
                            [item.input] = 1
                        },
                        part = recipe.id,
                        out = item.products,
                        time = 40.6,
                        producers = { producer }
                    }

                    if recipe.out then
                        for n, q in pairs(recipe.out) do
                            r["in"][n] = q * silo.parts
                        end
                    else
                        r["in"][recipe.id] = silo.parts
                    end
                    
                    table.insert(out, r)
                end
            end
        end
    end
end


local function make_recipes()
    local out = {}

    for i = 1, #recipes_sorted do
        local r = recipes_sorted[i].ptr
        local t = {}
        t.id = r.name
        t.name = r.loc_name
        t.time = r.normal.energy_required or 0.5
        local ings = r.normal.ingredients
        for j = 1, #ings do
            local ing = ings[j]
            -- [PYANODONS] handle null ingredients
            if ing then
                if not t["in"] then
                    t["in"] = {}
                end
                t["in"][ing.name] = ing.amount
            end
        end

        local res = r.normal.results
        if #res > 1 or res[1].name ~= r.name
            or (res[1].amount ~= nil and res[1].amount > 1)
            or (res[1].amount_min ~= nil and res[1].amount_min > 0) then
            t["out"] = {}
            for j = 1, #res do
                local add
                if res[j].amount_min then
                    add = (res[j].amount_max + res[j].amount_min) / 2
                else
                    add = res[j].amount
                end
                if res[j].probability then
                    add = add * res[j].probability
                end
                if t["out"][res[j].name] then
                    t["out"][res[j].name] = t["out"][res[j].name] + add
                else
                    t["out"][res[j].name] = add
                end
            end
        end

        if r.expensive ~= r.normal then
            t.expensive = {}
            local et = r.expensive.energy_required or 0.5
            if et ~= t.time then
                t.expensive["time"] = et
            end
            ings = r.expensive.ingredients
            for j = 1, #ings do
                if not t.expensive["in"] then
                    t.expensive["in"] = {}
                end
                local ing = ings[j]
                t.expensive["in"][ing.name] = ing.amount
            end
            res = r.expensive.results
            if #res > 1 or res[1].name ~= r.name or res[1].amount > 1 then
                t.expensive.out = {}
                for j = 1, #res do
                    local add
                    if res[j].amount_min then
                        add = (res[j].amount_max + res[j].amount_min) / 2
                    else
                        add = res[j].amount
                    end
                    if res[j].probability then
                        add = add * res[j].probability
                    end
                    if t.expensive["out"][res[j].name] then
                        t.expensive["out"][res[j].name] = t.expensive["out"][res[j].name] + add
                    else
                        t.expensive["out"][res[j].name] = add
                    end
                end
            end
        end

        local cat = r.category
        if producers[cat] then
            t["producers"] = { table.unpack(producers[cat]) }
            table.insert(out, t)
            make_launch_recipes(out, t)
        else
            dbglog(1, "failed to find producers for recipe: " .. r.name .. "\n")
        end
    end

    -- now raw-resources, etc
    for i = 1, #items_used do
        local item = items_used[i]

        local p = item[1]
        local res = raw["resource"][p.name]

        if res == nil then
            for _, e in pairs(raw["resource"]) do
                if e.minable then
                    if e.minable.result == p.name then
                        res = e
                        break
                    end
                end
            end
        end

        if res then
            if res.category == "basic-fluid" or res.category == "water" then
                if res.category == "water" then
                    dbglog(1, "Processing water '" .. p.name .. "' as basic-fluid\n")
                end
                local t = {}
                t.id = p.name
                t.name = L(p)
                t.mining = true
                t.time = res.minable.mining_time
                t.out =  { [p.name] = 10 }

                local cat = res.category
                if producers[cat] then
                    t["producers"] = { table.unpack(producers[cat]) }
                    table.insert(out, t)
                else
                    dbglog(1, "failed to find producers for resource: " .. p.name .. "\n")
                end
            else
                if item[2] ~= "raw-resource" then
                    dbglog(1, "Processing " .. item[2] .. " '" .. p.name .. "' as raw resource\n")
                end
                local t = {}
                t.id = p.name
                t.name = L(p)
                t.mining = true

                local mine = res.minable
                if mine then
                    t.time = mine.mining_time
                    -- check for needed fluid
                    if mine.required_fluid then
                        local fluid = mine.required_fluid
                        local amount = mine.fluid_amount * 0.1 -- why 0.1???
                        t["in"] = { [fluid] = amount }
                    end
                end

                local cat = p.category or "basic-solid"
                if producers[cat] then
                    t["producers"] = { table.unpack(producers[cat]) }
                    table.insert(out, t)
                else
                    dbglog(1, "failed to find producers for resource: " .. p.name .. "\n")
                end
            end -- if res
        end -- if "raw-resource"
    end -- for i

    for i = 1, #items_burnt do
        local burnt = items_burnt[i]
        local cat = burnt.category
        if burners[cat] then
            local id = burnt.result
            for i = 1, #out do
                local r = out[i]
                if r.id == id then
                    id = burnt.id .. '-burn'
                    break
                end
            end
            local ptr = get_item_ptr(burnt.result)
            if id ~= burnt.result then
                save_icon(ptr, id)
            end
            local r = {
                id = id,
                name = L(ptr),
                time = 1,
                ["in"] = { [burnt.id] = 0 },
                ["out"] = { [burnt.result] = 0},
                producers = {}
            }
            for b = 1, #burners[cat] do
                local burner = burners[cat][b]
                table.insert(r.producers, burner.id)
            end
            table.insert(out, r)
        else
            dbglog(1, "failed to find burners for result: " .. burnt.id .. "\n")
        end
    end

    if #boilers > 0 then
        local steam = get_item_ptr("steam")
        local water = get_item_ptr("water")
        if steam and water then
            local e = {
                id = steam.name,
                name = L(steam),
                time = 1,
                ["in"] = { [water.name] = 1 },
                producers = boilers
            }

            for _, r in pairs(out) do
                if r.id == e.id then
                    e.id = e.id .. "-boil"
                    save_icon(steam, e.id)
                    e["out"] = { [steam.name] = 1 }
                    break
                end
            end

            table.insert(out, e)
        end
    end

    for _, e in pairs(recipes_extra) do
        for _, r in pairs(out) do
            if r.id == e.id then
                e.id = e.id .. "-" .. e.producers[1]
                local ptr = get_item_ptr(r.id)
                save_icon(ptr, e.id)
                break
            end
        end
        table.insert(out, e)
    end

    return out
end

local function trim(items, recipes)
    for i=#items,1,-1 do
        local item = items[i]
        local found = false
        for r, recipe in pairs(recipes) do
            if not recipe["out"] and recipe.id == item.id then
                found = true
                break
            elseif recipe["in"] and recipe["in"][item.id] then
                found = true
                break
            elseif recipe["out"] and recipe["out"][item.id] then
                found = true
                break
            elseif recipe["expensive"] and recipe["expensive"]["in"] and recipe["expensive"]["in"][item.id] then
                found = true
                break
            elseif recipe["expensive"] and recipe["expensive"]["out"] and recipe["expensive"]["out"][item.id] then
                found = true
                break
            end
        end
        if not found then
            table.remove(items, i)           
        end
    end
end

--[[ main ]]-------------------------------------------------------------------

local function main()
    prepare()

    process_technology()
    process_recipes()
    sort_recipes()
    sort_items()

    -- PRESET FOR RESEARCH DATA
    -- save_icon(raw["technology"]["artillery-shell-range-1"])
    -- save_icon(raw["technology"]["artillery-shell-speed-1"])
    -- save_icon(raw["technology"]["energy-weapons-damage-7"])
    -- save_icon(raw["technology"]["follower-robot-count-7"])
    -- save_icon(raw["technology"]["mining-productivity-4"])
    -- save_icon(raw["technology"]["physical-projectile-damage-7"])
    -- save_icon(raw["technology"]["refined-flammables-7"])
    -- save_icon(raw["technology"]["space-science-pack"])
    -- save_icon(raw["technology"]["stronger-explosives-7"])
    -- save_icon(raw["technology"]["worker-robots-speed-6"])

    -- PRESET FOR APP DATA
    -- save_icon(raw["recipe"]["pipe"])
    -- save_icon(raw["item-group"]["production"])
    -- save_icon(raw["recipe"]["inserter"])
    -- save_icon(raw["recipe"]["long-handed-inserter"])
    -- save_icon(raw["recipe"]["fast-inserter"])
    -- save_icon(raw["recipe"]["stack-inserter"])
    -- local icon, u
    -- u = raw["utility-sprites"]["default"]["slot_icon_module"]
    -- icon = {
    --     id = "module",
    --     path = {{ icon = u["filename"], size = u["width"], mips = 1, }},
    --     category = "gui",
    --     subgroup = "gui",
    --     group = "additional-icons",
    --     name = "Empty module icon",
    --     icon_size = 64,
    -- }
    -- table.insert(icons, icon)
    -- local icon, u
    -- u = raw["utility-sprites"]["default"]["clock"]
    -- icon = {
    --     id = "time",
    --     path = {{ icon = u["filename"], size = u["width"], mips = 1, }},
    --     category = "gui",
    --     subgroup = "gui",
    --     group = "additional-icons",
    --     name = "Clock icon",
    --     icon_size = 64,
    -- }
    -- table.insert(icons, icon)

    local i, l = make_items()
    local r = make_recipes()
    trim(i, r)

    local ic = gd_image.generate_image(icons)
    dbglog(1, string.format("processing %s duplicate icons...\n", #copies))
    for k, v in ipairs(copies) do
        local ref
        for _, u in ipairs(ic) do
            if u.id == v.ref then
                ref = u
                break
            end
        end
        local t = {
            id = v.id,
            position = ref.position,
            color = ref.color
        }
        table.insert(ic, t)
    end

    local out = {}
    out.categories = categories_used or {}
    out.items = i or {}
    out.recipes = r or {}
    out.icons = ic or {}
    out.limitations = l or {}

    if args.export then
        util.save_file(out, args.version .. args.suffix .. ".json", "json")
    else
        util.save_file(out, args.version .. args.suffix .. ".lua")
    end
end

main()
