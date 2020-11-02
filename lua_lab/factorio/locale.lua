local LANG
local LANGUAGES
local locale = {}
local translate, dbglog

local function init(l, m, log)
    dbglog = log
    LANG = l or "en" -- selected locale
    LANGUAGES = {"en"} -- fallback language
    if "en" ~= LANG then
        table.insert(LANGUAGES, 1, LANG)
    end

    local cfg_parser = require("factorio.cfg_parser")
    local lfs = require("lfs")

    for _, mod in ipairs(m) do
        local data_dir = mod.handle
        for _, lang in ipairs(LANGUAGES) do
            locale[lang] = locale[lang] or {}
            local path = ("%s/locale/%s"):format(data_dir, lang)
            for file in lfs.dir(path) do
                if ".." ~= file and ".." ~= file then
                    if ".cfg" == file:sub(-4) then
                        local fn = ("%s/%s"):format(path, file)
                        local res = cfg_parser.parse_file(fn, locale[lang], ";")
                        if not res then dbglog(0, "[WARN] parser failed on: ", fn, "\n") end
                    end
                end
            end
        end
    end
    return translate
end


local function get_loc_name(section, id, mute)
    --[[ locale[LANG][section][id] = {} ]]

    local function parse_section(lang)
        local loc
        if lang then
            for _, sect in ipairs(section) do
                local sec = lang[sect]
                if sec then
                    loc = sec[id]
                    if loc then
                        break
                    end
                end
            end
        end
        return loc
    end

    local lang = locale[LANGUAGES[1]]
    local loc = parse_section(lang)

    if not loc then -- fallback
        lang = locale[LANGUAGES[2]]
        loc = parse_section(lang)
    end

    if not (loc or mute) then
        local info = debug.getinfo(2) -- find caller
        dbglog(1, ("missed loc string: ...%s (called from %s():%d)\n"):format(id, info["name"], info.currentline))
        -- [BOBS/ANGELS] use recipe id to build name when we can't find one
        loc = ""
        for w in string.gmatch(id .. "-", "(%w+)-") do
            local cap = w:gsub("^%l", string.upper)
            if loc == "" then
                loc = cap
            else
                loc = loc .. " " .. cap
            end
        end
        dbglog(1, "using parsed id, result: " .. loc .. "\n")
    end

    return loc
end


function translate(entry, mute) -- old args: mod, section, id, dbg
    local section
    local loc_name = entry.localised_name
    if not loc_name then
        local add = ("%s-name"):format(entry.subgroup or entry.type)
        -- try to find in next sections
        section = { "entity-name", add, "item-name", "recipe-name", "equipment-name", "fluid-name" }
        loc_name = entry["name"]
    end

    if section then
        local loc = get_loc_name(section, loc_name, mute)

        -- try to find and replace __SECT__id__
        if loc then
            local temp = ""
            for part in string.gmatch(loc, "%g+") do
                if temp ~= "" then
                    temp = temp .. " "
                end
                local sect, name = part:match("__(.+)__(.+)__")
                if sect and name then
                    temp = temp .. get_loc_name({sect:lower() .. "-name"}, name, mute)
                end
            end

            if temp ~= "" then
                loc = temp
            end

            return loc
        end

        return loc
    end

    -- find parameters (_... __value___ ...)
    local function param_f(k)
        if type(loc_name[2]) == "number" then
            return loc_name[2]
        end
        local v = loc_name[2][k/1]
        if v then
            local sect, name = v:match("(.+)%.(.+)")
            loc = get_loc_name({sect}, name, mute)

            return loc
        end
    end

    local sect, name = loc_name[1]:match("(.+)%.(.+)")
    local loc = get_loc_name({sect}, name, mute)

    if not loc and type(loc_name) == "table" then
        for a, b in pairs(loc_name) do
            if type(b) == "table" then
                for _, c in pairs(b) do
                    sect, name = b[1]:match("(.+)%.(.+)")
                    loc = get_loc_name({sect}, name, mute)
                end
            end
        end
    end

    loc = loc and loc:gsub("__(%d+)__", param_f) or "#" .. name .. "#"

    return loc
end

return {
    init = init,
}
