local contain = function(t, value)
    local res = false
    if t then
        for _, v in pairs(t) do
            if value == v then
                res = true
                break
            end
        end
    end
    return res
end

local sort_by = function(t, n1, n2, n3, n4, n5, n6)
    local function sort_by_func(a, b)
        if a[n1] < b[n1] then
            return true
        elseif n2 and a[n1] == b[n1] then
            if a[n2] < b[n2] then
                return true
            elseif n3 and a[n2] == b[n2] then
                if a[n3] < b[n3] then
                    return true
                elseif n4 and a[n3] == b[n3] then
                    if a[n4] < b[n4] then
                        return true
                    elseif n5 and a[n4] == b[n4] then
                        if a[n5] < b[n5] then
                            return true
                        elseif n6 and a[n5] == b[n5] then
                            return a[n6] < b[n6]
                        end
                    end
                end
            end
        end
        return false
    end
    table.sort(t, sort_by_func)
end

local eK = {
    [""]  = 1,
    ["k"] = 3,
    ["K"] = 3,
    ["M"] = 6,
    ["G"] = 9,
    ["T"] = 12,
    ["P"] = 15,
    ["E"] = 18,
    ["Z"] = 21,
    ["Y"] = 24,
}
local function convert_energy(e)
    if not e then
        return 0;
    end
    local num, mult = e:match("([0-9%.]+)([kKMGTPEZY]*)[WJ]")
    mult = eK[mult]
    return (num * 10^mult / 1000)
end

local function save_file(data, fn, mode)
    local str
    local data_type = type(data)
    if "table" == data_type then
        if "json" == mode then
            str = require("JSON"):encode_pretty(data)
        elseif "txt" == mode then
            str = table.concat(data)
        else
            str = require("serpent").dump(data, {
                    nocode = true, comment = false, sortkeys = false,
                    indent = "  ", maxlevel = nil, numformat="%g"})
        end
    elseif "string" == data_type then
        str = data
    else
        log(0, "can't save ", data_type, "\n")
    end
    if str then
        local w = assert(io.open(fn, "w+b"))
        w:write(str)
        w:close()
    end
end

return {
    contain = contain,
    sort_by = sort_by,
    convert_energy = convert_energy,
    save_file = save_file,
}
