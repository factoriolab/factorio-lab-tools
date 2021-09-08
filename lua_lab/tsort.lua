local function visit(k, n, m, s)
    if m[k] == 0 then return 1 end
    if m[k] == 1 then return end
    m[k] = 0
    local f = n[k]
    for i=1, #f do
        if visit(f[i], n, m, s) then return 1 end
    end
    m[k] = 1
    s[#s+1] = k
end

local tsort = {}

tsort.__index = tsort

function tsort.new()
    return setmetatable({ n = {} }, tsort)
end

function tsort:add(...)
    local p = { ... }
    local c = #p
    if c == 0 then return self end
    if c == 1 then
        p = p[1]
        if type(p) == "table" then
            c = #p
        else
            p = { p }
        end
    end
    local n = self.n
    for i=1, c do
        local f = p[i]
        if n[f] == nil then n[f] = {} end
    end
    for i=2, c, 1 do
        local f = p[i]
        local t = p[i-1]
        local o = n[f]
        o[#o+1] = t
    end
    return self
end

function tsort:init(t)
    for k, v in pairs(t) do
        for _, vv in ipairs(v) do
            self:add(vv, k)
        end
    end
end

function tsort:sort()
    local n  = self.n
    local s = {} -- for result
    local m  = {}
    for k in pairs(n) do
        if m[k] == nil then
            if visit(k, n, m, s) then
                print('Circular Dependency!')
                print(k)
                print(n)
                print(m)
                print(s)
                return nil, "circular dependency!"
            end
        end
    end
    return s
end

-- Depth-first search
function tsort.topo_sort(link)
    local color = {} -- 0/1/2 - white/grey/black
    local stack = {}

    local function dfs(k)
        if 1 == color[k] then return true end
        if 2 == color[k] then return false end
        color[k] = 1 -- 0 == color[v]
        for _, v in pairs(link[k]) do
            if dfs(v) then return true end
        end
        table.insert(stack, k)
        color[k] = 2
        return false
    end

    for k, _ in pairs(link) do
        if dfs(k) then
            return false
        end
    end
    return true, stack
end

return tsort
