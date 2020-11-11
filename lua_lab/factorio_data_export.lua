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

-- assert("Car" == L(raw.car.car)) -- only for EN


--[[ prepare ]]----------------------------------------------------------------

local items_ptr = {}  -- таблица указателей на все предметы с параметром "stack_size"
local items_as_ingredient = { ["space-science-pack"] = true, ["rocket-part"] = true } -- имена предметов в ингридиентах
local items_as_product = { ["space-science-pack"] = true, ["rocket-part"] = true }    -- имена предметов в продуктах
-- local items_as_ingredient = { ["rocket-part"] = true } -- имена предметов в ингридиентах
-- local items_as_product = { ["rocket-part"] = true }    -- имена предметов в продуктах
local items_used = {}
local items_ready = {}         -- таблица указателей на предметы

local recipes_enabled = {}      -- имена рецептов включаемых технологиями
local recipes_ptr = {}          -- таблица указателей на задействованные рецепты
local recipes_disabled_ptr = {} -- таблица указателей на отключённые рецепты
local recipes_sorted = {}       -- таблица указателей на отсортированные рецепты
local recipes_extra = {
    {
        ["id"] = "steam",
        ["time"] = 1,
        ["in"] = { ["water"] = 60 },
        ["out"] = { ["steam"] = 60 },
        ["producers"] = { "boiler" },
    },
    {
        ["id"] = "rocket-part",
        ["time"] = 3,
        ["in"] = {["low-density-structure"] = 10, ["rocket-control-unit"] = 10, ["rocket-fuel"] = 10},
        ["producers"] = {"rocket-silo"}
    },
    {
        ["id"] = "space-science-pack",
        ["time"] = 40.33,
        ["in"] = {["rocket-part"] = 100, ["satellite"] = 1},
        ["out"] = {["space-science-pack"] = 1000},
        ["producers"] = {"rocket-silo"}
    }
    -- KRASTORIO 2
    -- ,
    -- {
    --     ["id"] = "space-research-data",
    --     ["time"] = 40.33,
    --     ["in"] = {["rocket-part"] = 100, ["satellite"] = 1},
    --     ["out"] = {["space-research-data"] = 1000},
    --     ["producers"] = {"rocket-silo"}
    -- }
}

local categories_used = {}

local icons = {}

local producers = {}    -- список категория = {машина, ...}

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
            if not p["amount"] then
                local min = p["amount_min"]
                local max = p["amount_max"]
                max = max < min and min or max
                p["amount"] = (max - min)
            end
            if p["probability"] then
                p["amount"] = p["amount"] * p["probability"]
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
        error(ptr.name .. " and " .. from.name .. " haven't icon(s)!")
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
    local product_count = #ptr[mode]["results"]

    if product_count > 1 then
        if nil == main_product or "" == main_product then
            --[[ use recipe data ]]--

            set_IconSpecification(ptr)

            assert(ptr["subgroup"], ptr["name"] .. ": recipe haven't subgroup!")
            --assert(ptr["order"], ptr["name"] .. ": recipe haven't order!")

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
    local order          = entry["order"] or entry.name --error("missed [\"" .. entry.name .. "\"][\"order\"]")
    local subgroup       = entry["subgroup"] or ("fluid" == entry.type and "fluid") or "other" --error("item have not subgroup")
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
        else
            print("$$$", entry.name)
        end
    end
end


--[[ icons ]]--------------------------


local function save_icon(entry)
    -- if entry.name ~= "fill-water-barrel" and entry.name ~= "sulfur-dioxide" and entry.name ~= "resource-refining"
    --     and entry.name ~= "angels-components" and entry.name ~= "bob-gems" and entry.name ~= "bobmodules" then
    --     return
    -- end
    local icon = { id = entry.name, path = {} }
    local ptr = entry.icon and {entry} or entry.icons
    if not ptr then
        ptr = entry.main_product_ptr.icons
        if not ptr then
            error(entry.name .. ", no icon(s) !!")
        end
    end
    local i_sz = entry.icon_size or 64
    for _, e in ipairs(ptr) do
        local t = {}
        t.icon = e.icon
        t.size = e.icon_size or i_sz
        t.mips = e.icon_mipmaps or 1
        t.tint = e.tint
        t.scale = e.scale -- may be nil
        t.shift = e.shift
        table.insert(icon.path, t)
    end
    table.insert(icons, icon)
end


--[[ level 1 ]]----------------------------------------------------------------

local function prepare()
    -- удаление всех "лишних" записей
    local to_clean = {
        "noise-layer", "noise-expression", "explosion", "optimized-particle",
        "corpse", "virtual-signal", "tile", "decorative", "optimized-decorative",
        "tutorial", "custom-input", "gui-style", "font", "utility-constants",
        "utility-sounds", "sprite", "god-controller", "editor-controller",
        "spectator-controller", "mouse-cursor", "ambient-sound", "wind-sound",
        "character-corpse", "character", "simple-entity","sticker", "shortcut",
        "trivial-smoke", "tree", "stream", "flying-text", "fire", "autoplace-control",
        "crash-site",
    }
    for i = 1, #to_clean do
        raw[to_clean[i]] = nil
    end

    -- создание таблицы указателей на все записи с параметром "stack_size"
    dbglog(1, "process all items...")
    local i, j = 0, 0
    for _, r in pairs(raw) do
        for _, v in pairs(r) do
--            if v.stack_size and not util.contain(v.flags, "hidden") then
            if v.stack_size then
                if "item" ~= v.type then
                    j = j + 1
                else
                    i = i + 1
                end
                items_ptr[v["name"]] = v
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
        local delivery_cannon = string.find(rcp.name, "^se%-delivery%-cannon%-pack%-");
        if delivery_cannon then
            skip = true
        end
        local delivery_weapon_cannon = string.find(rcp.name, "^se%-delivery%-cannon%-weapon%-pack%-");
        if delivery_weapon_cannon then
            skip = true
        end

        if (not (true == rcp.hidden))
        and (not (false == rcp.enabled) or recipes_enabled[name])
        and (not skip)
        then
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

    -- подсчёт предметов
    local c = 0
    for k, v in pairs(items_as_ingredient) do c = c + 1 end
    items_as_ingredient.count = c
    c = 0
    for k, v in pairs(items_as_product) do c = c + 1 end
    items_as_product.count = c
    dbglog(1, ("\tfound %d ingridients and %d products\n")
        :format(items_as_ingredient.count, items_as_product.count))

    -- заполнение таблицы отсортированными рецептами
    dbglog(1, "clear items...\n")
    for i = 1, #t do
        local s = t[i]
        table.insert(recipes_sorted, {ptr = s[1], subgroup = s[4], group = s[6]})

        save_icon(s[1]) -- значок в рецепте

        -- очистка списка используемых предметов
        local name = s[1]["name"]
        -- поиск по имени рецепта
        local ptr = get_item_ptr(name, nil, "3")
        if ptr then
            items_ready[name] = ptr
            items_as_ingredient[name] = nil
            items_as_product[name] = nil
        else
            -- TODO: поиск по продуктам рецепта???
        end
    end

    c = 0
    for k, v in pairs(items_as_ingredient) do
        if "count" ~= k then
            c = c + 1
            items_used[k] = true
        end
    end
    dbglog(2, "\t", c, " ingridients")

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
    dbglog(2, "\nother items: ")
    local s = {}
    for i = 1, #t do
        local ptr = t[i][1]
        table.insert(items_used, { t[i][1], t[i][4], t[i][6] })
        save_icon(ptr)
        table.insert(s, t[i][2])
    end
    dbglog(-2, table.concat(s, ", "), "\n")
end


local function make_items() -- for Factorio Lab
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
            t.stack = item.stack_size
            t.category = r.group
            t.row = calculate_row(r.group, r.subgroup)

            local belt = raw["transport-belt"][p.name]
            if belt then
                t.belt = belt and { speed = 480.0 * belt.speed }
            end

            local beacon = raw["beacon"][p.name]
            if beacon then
                local energy = beacon.energy_source.type
                local usage = beacon.energy_usage
                usage = util.convert_energy(usage) / 1000
                t.beacon = {
                    effectivity = beacon.distribution_effectivity,
                    range = beacon.supply_area_distance,
                    [energy] = usage,
                    modules = beacon.module_specification.module_slots
                }
            end

            local processed = false
            local mach = raw["mining-drill"][p.name]
            if mach then
                processed = true
                local energy = mach.energy_source.type
                local pollution = mach.energy_source.emissions_per_minute
                local usage = mach.energy_usage
                usage = util.convert_energy(usage) / 1000
                local drain = mach.energy_source.drain
                t.factory = {
                    speed = mach.mining_speed or 1.0,
                    modules = mach.module_specification
                    and mach.module_specification.module_slots
                    or 0,
                    [energy] = usage,
                    drain = drain,
                    pollution = pollution,
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
                    fluid = mach.fluid,
                }
                local energy = mach.energy_source and mach.energy_source.type
                if energy then
                    local pollution = mach.energy_source.emissions_per_minute
                    local usage = mach.energy_usage
                    usage = util.convert_energy(usage) / 1000
                    local drain
                    if "electric" == energy then
                        drain = mach.energy_source.drain
                        drain = drain and util.convert_energy(drain) or usage / 30.0
                    end
                    t.factory[energy] = usage
                    t.factory.drain = drain
                    t.factory.pollution = pollution
                end

                if mach.fluid then
                    local r = {}
                    r["id"] = mach.fluid
                    r["time"] = 1
                    r["producers"] = { mach.name }
                    table.insert(recipes_extra, r)
                end
            end
            mach = raw["furnace"][p.name]
            if mach then
                processed = true
                local energy = mach.energy_source.type
                local pollution = mach.energy_source.emissions_per_minute
                local usage = mach.energy_usage
                usage = util.convert_energy(usage) / 1000
                local drain
                if "electric" == energy then
                    drain = mach.energy_source.drain
                    drain = drain and util.convert_energy(drain) or usage / 30.0
                end
                t.factory = {
                    speed = mach.crafting_speed or 1.0,
                    modules = mach.module_specification
                    and mach.module_specification.module_slots
                    or 0,
                    [energy] = usage,
                    drain = drain,
                    pollution = pollution,
                }

                process_producers(mach)
            end
            mach = raw["assembling-machine"][p.name]
            if mach then
                processed = true
                local energy = mach.energy_source.type
                local pollution = mach.energy_source.emissions_per_minute
                local usage = mach.energy_usage
                usage = util.convert_energy(usage) / 1000
                local drain
                if "electric" == energy then
                    drain = mach.energy_source.drain
                    drain = drain and util.convert_energy(drain) or usage / 30.0
                end
                t.factory = {
                    speed = mach.crafting_speed or 1.0,
                    modules = mach.module_specification
                    and mach.module_specification.module_slots
                    or 0,
                    [energy] = usage,
                    drain = drain,
                    pollution = pollution,
                }

                process_producers(mach)
            end
            mach = raw["lab"][p.name]
            if mach then
                processed = true
                local energy = mach.energy_source.type
                local pollution = mach.energy_source.emissions_per_minute
                local usage = mach.energy_usage
                usage = util.convert_energy(usage) / 1000
                local drain
                if "electric" == energy then
                    drain = mach.energy_source.drain
                    drain = drain and util.convert_energy(drain) or usage / 30.0
                end
                t.factory = {
                    speed = mach.researching_speed or 1.0,
                    modules = mach.module_specification
                    and mach.module_specification.module_slots
                    or 0,
                    [energy] = usage,
                    drain = drain,
                    pollution = pollution,
                    research = true
                }
            end
            mach = raw["boiler"][p.name]
            if mach then
                processed = true
                local energy = mach.energy_source.type
                local pollution = mach.energy_source.emissions_per_minute
                local usage = mach.energy_consumption
                usage = util.convert_energy(usage) / 1000
                local drain
                if "electric" == energy then
                    drain = mach.energy_source.drain
                    drain = drain and util.convert_energy(drain) or usage / 30.0
                end
                t.factory = {
                    speed = 1.0,
                    modules = 0,
                    [energy] = usage,
                    drain = drain,
                    pollution = pollution,
                }
            end

            if "rocket-silo" == p.name then
                local mach = raw["rocket-silo"][p.name]
                if mach then
                    local energy = mach.energy_source.type
                    local pollution = mach.energy_source.emissions_per_minute
                    local usage = mach.energy_usage
                    usage = util.convert_energy(usage) / 1000
                    local drain
                    if "electric" == energy then
                        drain = mach.energy_source.drain
                        drain = drain and util.convert_energy(drain) or usage / 30.0
                    end
                    t.factory = {
                        speed = mach.crafting_speed or 1.0,
                        modules = mach.module_specification
                        and mach.module_specification.module_slots
                        or 0,
                        [energy] = usage,
                        drain = drain,
                        pollution = pollution,
                    }

                    process_producers(mach)
                end
            end

            if "module" == r.subgroup
            or (p["main_product_ptr"] and "module" == p["main_product_ptr"]["type"]) then
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
            end

            local fuel_value = p["main_product_ptr"] and p["main_product_ptr"]["fuel_value"]
            if fuel_value then
                local fuel = util.convert_energy(fuel_value) / 1000000.0 -- to MJ
                t.fuel = fuel
            end

            table.insert(out, t)
        end
    end

    -- now raw-recources, etc
    for i = 1, #items_used do
        local item = items_used[i]
        local p = item[1]
        local t = {}

        t.id = p.name
        t.name = L(p)
        t.stack = p.stack_size
        t.category = "other"
        t.subgroup = p.subgroup
        t.row = calculate_row("other", item[2])

        local fuel_value = p.fuel_value
        if fuel_value then
            local fuel = util.convert_energy(fuel_value) / 1000000.0 -- to MJ
            t.fuel = fuel
        end

        table.insert(out, t)
    end

    return out, limitation
end


local function make_recipes() -- for Factorio Lab
    local out = {}

    for i = 1, #recipes_sorted do
        local r = recipes_sorted[i].ptr
        local t = {}
        t.id = r.name

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
                if res[j].amount_min then
                    t["out"][res[j].name] = (res[j].amount_max + res[j].amount_min) / 2
                else
                    t["out"][res[j].name] = res[j].amount
                end
            end
        end

        if r.expensive ~= r.normal then
            t["expensive"] = {}
            local et = r.expensive.energy_required or 0.5
            if et ~= t.time then
                t["expensive"]["time"] = et
            end
            ings = r.expensive.ingredients
            for j = 1, #ings do
                if not t["expensive"]["in"] then
                    t["expensive"]["in"] = {}
                end
                local ing = ings[j]
                t["expensive"]["in"][ing.name] = ing.amount
            end
            res = r.expensive.results
            if #res > 1 or res[1].name ~= r.name or res[1].amount > 1 then
                t["expensive"]["out"] = {}
                for j = 1, #res do
                    t["expensive"]["out"][res[j].name] = res[j].amount
                end
            end
        end

        local cat = r.category
        if producers[cat] then
            t["producers"] = { table.unpack(producers[cat]) }
            table.insert(out, t)
        else
            dbglog(1, "failed to find producers for recipe: " .. r.name .. "\n")
        end
    end

    -- now raw-recources, etc
    for i = 1, #items_used do
        local item = items_used[i]

        local p = item[1]
        local res = raw["resource"][p.name]

        if res == nil then
            for _, e in pairs(raw["resource"]) do
                if e.minable then
                    if e.minable.result == p.name then
                        res = e
                        break;
                    end
                end
            end
        end

        if res then
            if "raw-resource" == item[2] or "raw-material" == item[2] then
                if item[2] == "raw-material" then
                    dbglog(1, "Processing raw material '" .. p.name .. "' as raw resource\n")
                end
                local t = {}
                t.id = p.name
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
                    dbglog(1, "failed to find producers for resouce: " .. p.name .. "\n")
                end
            elseif res.category ~= nil then
                local t = {}
                t.id = p.name
                t.mining = true
                t.time = res.minable.mining_time
                t.out =  { [p.name] = 10 };

                local cat = res.category
                if producers[cat] then
                    t["producers"] = { table.unpack(producers[cat]) }
                    table.insert(out, t)
                else
                    dbglog(1, "failed to find producers for resource: " .. p.name .. "\n")
                end
            end -- if res
        end -- if "raw-resource"
    end -- for i

    for _, e in pairs(recipes_extra) do
        table.insert(out, e)
    end

    return out
end

local function trim(items, recipes)
    for i=#items,1,-1 do
        local item = items[i]
        local found = false;
        for r, recipe in pairs(recipes) do
            if not recipe["out"] and recipe.id == item.id then
                found = true;
                break;
            elseif recipe["in"] and recipe["in"][item.id] then
                found = true;
                break;
            elseif recipe["out"] and recipe["out"][item.id] then
                found = true;
                break;
            elseif recipe["expensive"] and recipe["expensive"]["in"] and recipe["expensive"]["in"][item.id] then
                found = true;
                break;
            elseif recipe["expensive"] and recipe["expensive"]["out"] and recipe["expensive"]["out"][item.id] then
                found = true;
                break;
            end
        end
        if not found then
            table.remove(items, i);            
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
    -- save_icon(raw["recipe"]["lab"])
    -- save_icon(raw["recipe"]["iron-gear-wheel"])
    -- save_icon(raw["recipe"]["iron-plate"])
    -- save_icon(raw["recipe"]["transport-belt"])
    -- save_icon(raw["recipe"]["pipe"])
    -- save_icon(raw["recipe"]["cargo-wagon"])
    -- save_icon(raw["recipe"]["fluid-wagon"])
    -- save_icon(raw["recipe"]["assembling-machine-1"])
    -- save_icon(raw["recipe"]["electric-mining-drill"])
    -- save_icon(raw["recipe"]["substation"])
    -- save_icon(raw["fluid"]["steam"])
    -- save_icon(raw["recipe"]["inserter"])
    -- save_icon(raw["recipe"]["long-handed-inserter"])
    -- save_icon(raw["recipe"]["fast-inserter"])
    -- save_icon(raw["recipe"]["stack-inserter"])
    -- save_icon(raw["recipe"]["speed-module-3"])
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
