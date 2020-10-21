local M = {}

local function parse(content, lang, comment)
    comment = comment or "#"
    local ptr = lang
    for line in content:gmatch("[^\r\n]+") do
        local first = line:sub(1, 1)
        if comment == first then
--        goto ::skip::
        elseif "[" == first then
            local section = line:match("%[(.+)%]")
            lang[section] = lang[section] or {}
            ptr = lang[section]
        else
            local k, v = line:match("([^=%s]+)=([^=]*)")
            if k and v then
                ptr[k] = v
            else
                --print("#[" .. line .. "]#")
            end
        end
--        ::skip::
    end
end

local function parse_file(fn, lang, comment)
    local r = io.open(fn, "rb")
    if not r then
        print("[ERR] file no found: " .. fn)
        return false
    else
        local content = r:read("*a")
        r:close()
        parse(content, lang, comment)
    end
    return true
end

M.parse = parse
M.parse_file = parse_file

return M
