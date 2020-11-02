--[[ parse arguments ]]

local args
do
    local function parse_args()
        local argparse = require("argparse")

        if not arg[1] then arg[1] = "-h" end
        local script = arg[0]:match("[^\\/]+$")

        local parser = argparse()
        :name(script)
        :description("Data exporter for Factorio.")
        :epilog([[
* - not implemented
Home page: https://bitbucket.org/hhrhhr/factorio-tools-lua]])
        :usage_margin(8 + #script)

        parser:command("dump")
        :description("export data.raw from game and save it")

        parser:command("export")
        :description("export data.raw for Factorio Lab")

        parser:command("demo")
        :description("export data for demo page")

        parser:command("web")
        :description("* just start web server")

        parser:option("-g --gamedir")
        :description("game location")
        :default(".")

        parser:option("-m --moddir")
        :description("override mods location")
        :default(nil)

        parser:option("-s --iconsize")
        :description("icon size")
        :default("32")

        parser:option("-f --suffix")
        :description("a string that is added to the file name")
        :default("")

        parser:flag("-n --nomods")
        :description("disable mods")
        :default(false)

        parser:flag("-i --noimage")
        :description("disable image generation")
        :default(false)

        parser:option("-l --language")
        :description("select localization")
        :default("en")

        parser:flag("-c --clear")
        :description("clear unneded fields in data.raw")
        :default(false)

        parser:flag("--factorio_lab_hacks")
        :description("use special hacks for Factorio Lab")
        :default(false)

        parser:flag("-b --browse")
        :description("* open browser (only with 'calc' command)")
        :default(false)

        parser:flag("-v --verbose")
        :description("more verbose (try -vvv)")
        :count("0-3")
        :default(0)

        parser:flag("-d --debug")
        :description("* start mobdebug")
        :default(false)

        return parser:parse()
    end

    args = parse_args()
    args.gamedir = args.gamedir:gsub("\\", "/")
    args.iconsize = tonumber(args.iconsize)
    args.is_windows = package.config:sub(1, 1) ~= "/"
    args.verbose = args.verbose + 1
end


--[[ dbg ]]

local function unrequire(m)
    if "string" ~= type(m) then return end
    if _G[m] then _G[m] = nil end
    if package.loaded[m] then package.loaded[m] = nil end
    collectgarbage()
end
unrequire("argparse")

if args.debug then
    require("mobdebug").start()
end

local DBG = { "[INFO] ", "[NOTE] ", "[WARN] ", "[????]" }
local function dbglog(dbg, ...)
    if math.abs(dbg) <= args.verbose then
        if dbg < 0 then
            dbg = -dbg
        else
            io.write(DBG[dbg])
        end
        for _, v in ipairs({...}) do
            io.write(v or "!nil!")
        end
    end
end


local serpent = require("serpent")
local tprint = function(t, cmd)
    local s = {nocode = true, maxlevel = nil, comment = false, numformat = "%g"}
    local c
    if "l" == cmd then
        s.indent = nil
        c = "line"
    elseif "d" == cmd then
        s.indent = "  "
        c = "dump"
    else
        c = "block"
    end
    dbglog(1, serpent[c](t, s), "\n")
end


--[[ self require ]]

local getinfo0 = debug.getinfo
local _getinfo = function(t, f, w)
    local info = getinfo0(t+1, f, w)
    local src = info.source
    src = src:gsub(args.gamedir .. "/data/", "")
    src = src:gsub("core/", "__core__/")
    src = src:gsub("base/", "__base__/")
    info.source = src
    return info
end
local traceback = debug.traceback

local _require

local function set_env(old) -- called once
    local F = setmetatable({}, {__index=_ENV})

    F.debug = old.debug or { getinfo = _getinfo, traceback = traceback }
    F.require = _require
    F.unpack = unpack or table.unpack -- compat
    F.math.pow = math.pow or function(x, y) return x^y end -- compat
    F.log = old.log or function(...) print("[LOG]", ...) end

    F.settings = old.settings or {}
    F.defines = old.defines or require("factorio.defines")
    unrequire("factorio.defines")
    F.data = old.data
    F.mods = old.mods or {}
    F.serpent = serpent

    F.package = {loaded = {}}

    return F
end

_G.table_size = function (t)
    local count = 0
    for k,v in pairs(t) do
        count = count + 1
    end
    return count
end

local _F = { mods = { base = "1.0.0" } } -- shared env for every called mod
local _E

_require = function(m, skip, opt)
    if "string" ~= type(m) then
        error("[ERR] not string: " .. m)
    end
    
    local res = nil

    if opt then
        _E = opt
    end
    local name = _E.name

    -- // workaround for mod with self call (require("__modname__/...")
    local check = "__" .. name .. "__/"
    local a, b = m:find(check)
    if 1 == a then
        m = m:sub(b+1)
    end
    -- \\

    -- [PYANODONS] handle reference to stdlib
    local mod_dir = {}
    check = "__(.+)__/"
    local other = m:match(check)
    if other then
        name = other
        a, b = m:find(check)
        if 1 == a then
            m = m:sub(b+1)
            local ver = _F.mods[name]
            table.insert(mod_dir, ("%s/%s_%s/?.lua"):format(args.moddir, name, ver))
        end
    end

    local m_dot = m -- store value for loadfile()
    m = m:gsub("%.", "/")
    m = m:gsub("/lua$", "")

    local loaded = {
        m,
        ("__%s__/%s"):format(name, m),
        ("__core__/lualib/%s"):format(m),
    }

    -- [PYANODONS] handle reference to missing faketorio test library
    if m:find('^faketorio') then
        skip = true
    end

    table.insert(mod_dir, ("%s/?.lua"):format(_E.handle))
    if _E.prev then
        table.insert(mod_dir, ("%s/?.lua"):format(_E.prev))
    end
    table.insert(mod_dir, ("%s/data/core/lualib/?.lua"):format(args.gamedir))

    local cached
    for _, path in pairs(loaded) do
        cached = _F.package.loaded[path]
        if cached then
            dbglog(4, "(>c) ", path, "\n")
            break
        end
    end

    if cached then
        res = cached
    else
        local func, err
        for i, path in pairs(mod_dir) do
            local fullpath = path:gsub("?", m)
            func, err = loadfile(fullpath, "bt", _F)

            if err then -- try load with dots in path
                fullpath = path:gsub("?", m_dot)
                func, err = loadfile(fullpath, "bt", _F)
            end

            if func then
                local prev = _E.prev
                _E.prev = fullpath:match("(.+)/[^/]+") -- parent folder path

                -- [PYANODONS] manually map required defines and global functions
                if defines and _F.defines ~= defines then
                    _F.defines = defines
                end
                
                for i, f in pairs(_F) do
                    if not _G[i] then
                        _G[i] = _F[i]
                    end
                end

                res = func()
                _E.prev = prev -- restore value

                if skip then
                    -- manual call
                    dbglog(2, "\tloaded ", name, ".", m, "\n")
                else
                    -- internal call
                    local ret, dbg
                    if type(res) == "table" then
                        ret, dbg = "( t) ", 4
                    elseif res ~= nil then
                        ret, dbg = "( f) ", 4
                    else
                        res = true
                        ret, dbg = "( _) ", 4
                    end
                    local key
                    if 2 == i then
                        key = ("__core__/lualib/%s"):format(m)
                    else
                        key = ("__%s__/%s"):format(name, m)
                    end

                    dbglog(dbg, ret, key, "\n")
                    _F.package.loaded[key] = res
                end

                break
            else
                -- it's ok there
            end

            if func then break end
        end

        if not func then
            if skip then
                dbglog(3, "skip or not found: ", name, ".", m, "\n")
            else
                error("[ERR] not found " .. name.." -> "..m)
            end
        end
    end

    return res
end


--[[ check gamedir ]]

local lfs = require("lfs")

do
    local function generate_filename(fn)
        return ("%s/%s"):format(args.gamedir, fn)
    end

    local function find_file(fn)
        local res = "file" == lfs.attributes(fn, "mode")
        if not res then dbglog(1, "not found: ", fn, "\n") end
        return res
    end

    local ext = args.is_windows and ".exe" or ""
    local bin = generate_filename(("bin/x64/factorio%s"):format(ext))
    if not find_file(bin) then return end

    local cfg = generate_filename("config-path.cfg")
    if not find_file(cfg) then return end

--[[ load game settings, find moddir ]]
    local cfg_parser = require("factorio.cfg_parser")
    unrequire("factorio.cfg_parser")
    local config = {}
    cfg_parser.parse_file(cfg, config)

    if not args.moddir then
        local moddir
        if config["use-system-read-write-data-directories"] == "true" then
            if args.is_windows then
                local appdata = os.getenv("APPDATA"):gsub("\\", "/")
                moddir = ("%s/%s"):format(appdata, "Factorio/mods")
            else
                moddir = "~/.factorio/mods"
            end
        else
            moddir = ("%s/%s"):format(args.gamedir, "mods")
        end

        local check = ("%s/mod-list.json"):format(moddir)
        if find_file(check) then
            args.moddir = moddir
        end
    end
end
unrequire("lfs")

dbglog(2, "args = ", serpent.block(args, {comment = false}), "\n") --; tprint(args, "b")


--[[ load mod settings ]]

do
    local settings_parser = require("factorio.settings_parser")
    _F.settings = settings_parser.parse_file(args.moddir .. "/mod-settings.dat")
    unrequire("factorio.settings_parser")
end

dbglog(1, "mods settins loaded\n")


--[[ get mod load order ]]

local zip = require("zip")
local json = require("JSON")

local load_order = {["base"] = {"core"}}
do
    local function read_and_close(fn)
        local r = assert(io.open(fn, "rb"))
        local data = r:read("*a")
        r:close()
        return data
    end

    local function zip_read_and_close(zfn, fn)
        local z = zip.open(zfn)
        local r = z:open(fn)
        local data = r:read("*a")
        r:close()
        z:close()
        return data
    end

    local function zip_read_not_close(zfn, fn)
        local z = zip.open(zfn)
        local r = z:open(fn)
        local data = r:read("*a")
        r:close()
        return z, data
    end


    -- TODO: add version check
    local function mod_needed(name, pfx, mod, cond, ver)
        if load_order[name] then
            if "!" == pfx then
                assert(false, "incompatibility: " .. name)
            end
        else
            if "!" ~= pfx and "(?)" ~= pfx and "?" ~= pfx then
                assert(false, "\n\n[ERR] missed '" .. (name or "!nil!") .. "' required by '" .. mod .. "'\n")
            else
                return false
            end
        end
        return true
    end

    local path = ("%s/mod-list.json"):format(args.moddir)
    local data = read_and_close(path)
    local t = json:decode(data)
    for i = 1, #t.mods do
        local mod = t.mods[i]
        if mod.enabled and "base" ~= mod.name then
            load_order[mod.name] = {}
        end
    end

    -- manual add
    path = ("%s/data/base/info.json"):format(args.gamedir)
    data = read_and_close(path)
    local j = json:decode(data)
    args.version = j.version
    local mods_used = {
        ["core"] = {
            ["name"] = "core",
            ["type"] = "dir",
            ["ver"] = j.version,
            ["handle"] = ("%s/data/core"):format(args.gamedir)
        },
        ["base"] = {
            ["name"] = "base",
            ["type"] = "dir",
            ["ver"] = j.version,
            ["handle"] = ("%s/data/base"):format(args.gamedir)
        }}
    if not args.nomods then
        for f in lfs.dir(args.moddir) do
            local mod, ver, ext = f:match("([%a -_]+)_([%d%.]+%d+)[%.]*(.*)")
            if mod and load_order[mod] then
                if "" == ext then
                    ext = "dir"
                elseif "zip" ~= ext then
                    ext = nil
                end
                -- zip have a low priority
                if ext and (not mods_used[mod]) or (mods_used[mod] and "dir" == ext) then

                    local mpath = ("%s/%s"):format(args.moddir, f)
                    local used, data = {}
                    if "dir" == ext then
                        local path = ("%s/info.json"):format(mpath)
                        data = read_and_close(path)
                        used["handle"] = mpath

                    elseif "zip" == ext then
                        local path = ("%s/info.json"):format(f:sub(1, -5))
                        local zhandle
                        zhandle, data = zip_read_not_close(mpath, path)
                        used["handle"] = zhandle
                    end

                    local j = json:decode(data)
                    assert(j.version == ver)
                    assert(j.name == mod)

                    local deps = j.dependencies
                    if not deps then deps = {("base >= %s"):format(mods_used["base"].ver)} end
                    for _, v in ipairs(deps) do
                        local pfx, name, cond, ver = v:match("([()!?]*)[ ]*([^%s]+)[%s]*([=<>]*)[ ]*(.*)")
                        if mod_needed(name, pfx, mod, cond, ver) then
                            table.insert(load_order[mod], name)
                        end
                    end

                    used["name"] = mod
                    used["type"] = ext
                    used["ver"] = ver

                    mods_used[mod] = used

                    _F.mods[mod] = ver
                end -- ext...
            end -- mod...
        end -- lfs.dir...
    end -- nomods

    -- run topological search
    local tsort = loadfile("tsort.lua")()
    local ts = tsort.new()
    ts:init(load_order)

    local order = ts:sort()

    dbglog(1, "mods load order received")
    dbglog(-2, ":\n\t", table.concat(order, " <- "))
    dbglog(-1, "\n")

    load_order = {}
    for i = 1, #order do
        table.insert(load_order, mods_used[order[i]])
    end
    mods_used = nil
end

dbglog(1, "load order applied\n")


--[[ core and data load ]]

if args.dump or args.export or args.demo then
    dbglog(1, "core and data load...\n")
    local data_order = {"data", "data-updates", "data-final-fixes"}
    local data_dir = ("%s/data"):format(args.gamedir)
    local opt = {["name"] = "core", ["type"] = "dir", ["handle"] = data_dir .. "/core"}

    -- init data.raw
    _F = set_env(_F)
    _require("dataloader", true, opt)

    -- run parser
    for j = 1, #data_order do
        local data = data_order[j]
        for i = 1, #load_order do
            local o = load_order[i]
            if (not args.nomods or o.name == "base" or o.name == "core") then
                o["prev"] = nil
                _require(data, true, o)
            end
        end
    end
end


--[[ dump ]]

if args.dump then
    dbglog(1, "saving data.raw...\n")

    if _F.data then
        local ptr = _F.data.raw

        if args.clear then -- clear unneeded fields
            local str = [[ambient-sound autoplace-control character character-corpse corpse
custom-input decorative editor-controller explosion flying-text font god-controller gui-style
highlight-box leaf-particle map-gen-presets map-settings mouse-cursor noise-expression noise-layer
optimized-decorative optimized-particle particle particle-source rail-remnants rocket-silo-rocket
rocket-silo-rocket-shadow shortcut smoke smoke-with-trigger spectator-controller speech-bubble
sprite sticker tile tile-effect trigger-target-type tutorial unit unit unit-spawner
utility-constants utility-sounds virtual-signal wind-sound]]
            for s in str:gmatch("[a-z_-]+") do
                ptr[s] = nil
            end
            -- clear more
            str = [[activity_led_light activity_led_light_offsets activity_led_sprites
and_symbol_sprites animation animations attack_parameters attacking_animation
attacking_muzzle_animation_shift autoplace back_light base_picture burnt_patch_pictures
cannon_barrel_pictures cannon_barrel_recoil_shiftings cannon_base_pictures
circuit_connector_sprites circuit_wire_connection_point circuit_wire_connection_points
close_sound collision_box colors connection_sprites damaged_trigger_effect destroy_action
divide_symbol_sprites drawing_box drawing_boxes dying_sound dying_trigger_effect
ending_attack_animation ending_attack_muzzle_animation_shift energy_glow_animation
enough_fuel_indicator_picture equal_symbol_sprites fluid_animation fluid_box
fluid_wagon_connector_graphics folded_animation folded_muzzle_animation_shift
folding_animation folding_muzzle_animation_shift folding_sound front_light glass_pictures
greater_or_equal_symbol_sprites greater_symbol_sprites heat_glow_sprites
horizontal_animation horizontal_rail_animation_right horizontal_rail_base idle in_motion
initial_action input_connection_points input_fluid_box input_fluid_patch_shadow_animations
input_fluid_patch_shadow_sprites input_fluid_patch_sprites
input_fluid_patch_window_base_sprites input_fluid_patch_window_flow_sprites
input_fluid_patch_window_sprites instruments integration integration_patch
left_shift_symbol_sprites less_or_equal_symbol_sprites less_symbol_sprites light light1
light2 minus_symbol_sprites modulo_symbol_sprites multiply_symbol_sprites muzzle_animation
not_enough_fuel_indicator_picture not_equal_symbol_sprites open_sound or_symbol_sprites
orientations output_connection_points output_fluid_box particle picture pictures
plus_symbol_sprites power_symbol_sprites prepared_alternative_animation
prepared_alternative_sound prepared_animation prepared_muzzle_animation_shift
prepared_sound preparing_animation preparing_muzzle_animation_shift preparing_sound
rail_overlay_animations resistances right_shift_symbol_sprites secondary_pictures
selection_box selection_box_offsets shadow shadow_animations shadow_idle shadow_in_motion
small_tree_fire_pictures smoke spine_animation sprite sprites stand_by_light
starting_attack_animation starting_attack_sound stop_trigger structure top_animations
track_particle_triggers turret_animation variations vehicle_impact_sound
vertical_animation vertical_rail_animation_left vertical_rail_animation_right
vertical_rail_base walking_sound wall_patch water_reflection wheels working_sound
xor_symbol_sprites]]
            local to_clear = {}
            for s in str:gmatch("[a-z_-]+") do
                to_clear[s] = true
            end

            for _, r in pairs(ptr) do
                for _, e in pairs(r) do
                    for k, v in pairs(e) do
                        if to_clear[k] then
                            e[k] = nil
                        end
                    end
                end
            end
        end -- if args.clear

        local raw = serpent.block(ptr, {
                nocode = true, comment = false, sortkeys = false,
                indent = "  ", maxlevel = nil, numformat="%g"})

        local fn = ("_data.raw.%s%s.lua"):format(args.version, args.suffix)
        local w = assert(io.open(fn, "w+b"))
        w:write(raw, "\n")
        w:close()
    end
end

if args.export or args.demo then
    dbglog(1, "exporting data.raw...\n")
    local raw = _F.data.raw

    local _E = setmetatable({}, {__index=_ENV})
    _E.opt = {raw = raw, args = args, mods = load_order, dbglog = dbglog, tprint = tprint}
    local res, err = loadfile("factorio_data_export.lua", "bt", _E)
    if res then
        res, err = pcall(res)
    end
    if not res then
        error(err)
    end
end


-- close all zip handles
for i = 1, #load_order do
    local o = load_order[i]
    if "zip" == o.type then
        o.handle:close()
    end
end

dbglog(1, "\nall done\n")
