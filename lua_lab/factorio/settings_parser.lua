local M = {}

local content = nil
local pos = 1


--[[ for Lua <5.3 ]]--

local function u8_m()
    local res = content:byte(pos, pos)
    pos = pos + 1
    return res
end

local function u16_m()
    local u1, u2 = content:byte(pos, pos+1)
    local res = u2 * 2^8 + u1
    pos = pos + 2
    return res
end

local function u32_m()
    local s1, s2, s3, s4 = content:byte(pos, pos+3)
    local res = s4 * 2^24 + s3 * 2^16 + s2 * 2^8 + s1
    pos = pos + 4
    return res
end

local function u32be_m()
    local s4, s3, s2, s1 = content:byte(pos, pos+3)
    local res = s4 * 2^24 + s3 * 2^16 + s2 * 2^8 + s1
    pos = pos + 4
    return res
end

local function s32_m()
    local res = u32_m()
    if res > 2147483647 then
        res = res - 4294967296
    end
    return res
end

local bit = bit or bit32
local function d_m()
    local ml, xh = u32_m(), u32_m()

    local mh = bit.extract(xh, 0, 20)
    local exp = bit.extract(xh, 20, 11) - 1023
    local sign = bit.extract(xh, 31, 1)
    if sign == 0 then sign = 1 else sign = -1 end
    local mul = 1
    local res = 1
    for i = 19, 0, -1 do
        mul = mul * 0.5
        res = bit.extract(mh, i) * mul + res
    end
    for i = 31, 0, -1 do
        mul = mul * 0.5
        res = bit.extract(ml, i) * mul + res
    end
    local f = 0.0
    if exp ~= -1023 then
        f = sign * res * 2^exp
    end
    return f
end

local function str_m()
    local res
    if 1 == u8_m() then
        res = ""
    else
        local len = u8_m()
        if 255 == len then
            len = s32_m(); print("len s32", len)
        end
        res = content:sub(pos, pos+len-1)
        pos = pos + len
    end
    return res
end


--[[ for Lua >=5.3 ]]--
local function u8_i()
    local res = string.unpack("B", content:sub(pos, pos))
    pos = pos + 1
    return res
end

local function u16_i()
    local res = string.unpack("H", content:sub(pos, pos+1))
    pos = pos + 2
    return res
end

local function s32_i()
    local res = string.unpack("I", content:sub(pos, pos+3))
    pos = pos + 4
    return res
end

local function d_i()
    local res = string.unpack("d", content:sub(pos, pos+7))
    pos = pos + 8
    return res
end

local function str_i()
    local res
    if 1 == u8_i() then
        res = ""
    else
        local len = u8_i()
        if 255 == len then
            len = s32_m()
            print("[CHECK] len 32", len)
        end
        res = content:sub(pos, pos+len-1)
        pos = pos + len
    end
    return res
end


--[[ now choice ]]--

local u8, u16, s32, d, str
if string.unpack then
    u8 = u8_i
    u16 = u16_i
    s32 = s32_i
    d = d_i
    str = str_i
else
    u8 = u8_m
    u16 = u16_m
    s32 = s32_m
    d = d_m
    str = str_m
end


--[[ main ]]--

local function parse_tree()
    local type1 = u8()
    local type2 = u8()
    local res
    if 0 == type1 then
        res = {}
    elseif 1 == type1 then
        res = u8() == 1 -- bool
    elseif 2 == type1 then
        res = d() -- double
    elseif 3 == type1 then
        res = str()
    elseif 4 == type1 then
        res = {}
        local len = s32()
        for i = 1, len do
print("[CHECK] int:", i, str())
            res[#res+1] = parse_tree()
        end
    elseif 5 == type1 then
        res = {}
        local len = s32()
        for i = 1, len do
            local key = str()
            res[key] = parse_tree()
        end
    else
        assert(false, "unknown type " .. type1)
    end
    return res
end

local function parse(data)
    content = data
    local version = {
        major = u16(),
        minor = u16(),
        patch = u16(),
        map   = u16(),
    }
    if (version.major == 0 and version.minor >= 17) or version.major >= 1 then
        u8()
    end
    
    local res = parse_tree()
    content = nil
    pos = 1
    return res
end

local function parse_file(fn, comment)
    local r = io.open(fn, "rb")
    local data
    if not r then
        data = {
            ["startup"] = {},
            ["runtime-global"] = {},
            ["runtime-per-user"] = {}
        }
    else
        data = r:read("*a")
        r:close()
        data = parse(data)
    end
    return data
end

M.parse = parse
M.parse_file = parse_file

return M
