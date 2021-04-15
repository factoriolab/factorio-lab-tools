local gd = require("gd")

local dbglog, args, mods

local function apply_tint(ico, tint)
    -- [BOBS/ANGELS] handle different icon edge cases
    if tint.r ~= nil and tint.g ~= nil and tint.b ~= nil then
        local X, Y = ico:sizeXY()
        for y = 0, Y-1 do
            for x = 0, X-1 do
                local c = ico:getPixel(x, y)
                local a = ico:alpha(c)
                if a < 127 then
                    local r = math.floor(ico:red(c)   * tint.r)
                    local g = math.floor(ico:green(c) * tint.g)
                    local b = math.floor(ico:blue(c)  * tint.b)
                    c = ico:colorAllocateAlpha(r, g, b, a)
                    if c then
                        ico:setPixel(x, y, c)
                    end
                end
            end
        end
    end
end

local function rgbToHex(rgb)
    local hexadecimal = '#'

    for key, value in pairs(rgb) do
        local hex = ''

        while(value > 0)do
            local index = math.fmod(value, 16) + 1
            value = math.floor(value / 16)
            hex = string.sub('0123456789ABCDEF', index, index) .. hex			
        end

        if(string.len(hex) == 0)then
            hex = '00'

        elseif(string.len(hex) == 1)then
            hex = '0' .. hex
        end

        hexadecimal = hexadecimal .. hex
    end

    return hexadecimal
end

local function copy_icon(x, y, SZ, mult, icon, canvas)
    local dstX = x * SZ - SZ
    local dstY = y * SZ - SZ

    -- draw multi-layers images
    local layers = 0
    local dSZ = 32 -- base size
    local tSZ -- projected image size
    local iSZ -- image size fitting shifts
    local temp

    for _, v in ipairs(icon.path) do
        local size = v.size or 32
        if _ == 1 then
            if v.scale then
                dSZ = size * v.scale
            elseif v.mips == 1 then
                dSZ = size
            end
        end
        local scale = v.scale or 1.0
        local dstW = size * scale
        if not tSZ then
            tSZ = dstW
            iSZ = tSZ
        end
        -- adjust image size to fit all icons with shifts
        if v.shift then
            local off = v.shift[1]
            if off < 0 then off = off * -1 end
            local alt = v.shift[2]
            if alt < 0 then alt = alt * -1 end
            if alt > off then off = alt end
            local new = ((dstW / 2) + off) * 2
            if new > iSZ then
                iSZ = new
            end
        end
    end

    for _, v in ipairs(icon.path) do
        layers = layers + 1

        local png
        local path = v.icon:gsub("__(.+)__", mods)
        png = gd.createFromPng(path)
        png:saveAlpha(true)

        -- Convert image to true color
        local size = v.size or 32
        local png2 = gd.createTrueColor(size, size)
        png2:fill(0, 0, gd.TRANSPARENT)
        png2:saveAlpha(true)
        png2:copyResampled(png, 0, 0, 0, 0, size, size, size, size)
        png = png2

        -- apply tint
        if v.tint then
            apply_tint(png, v.tint)
        end

        local scale = v.scale or 1.0
        local mult = 1.0
        if v.scale then
            mult = tSZ / dSZ
        end
        scale = scale * mult
        local dstW = size * scale

        local dc = math.floor(iSZ * 0.5 * (1.0 - (dstW / iSZ)))

        -- shift scaled icon
        local vx, vy = 0, 0
        if v.shift then
            vx = v.shift[1] * mult
            vy = v.shift[2] * mult
        end
        local dx = math.floor(dc + vx)
        local dy = math.floor(dc + vy)

        if not temp then
            temp = gd.createTrueColor(iSZ, iSZ)
            temp:fill(0, 0, gd.TRANSPARENT)
            temp:saveAlpha(true)
        end

        temp:copyResampled(png, dx, dy, 0, 0, dstW, dstW, size, size)
    end

    canvas:copyResampled(temp, dstX, dstY, 0, 0, SZ, SZ, iSZ, iSZ)

    local tint = {}
    if canvas then
        -- Copy this icon to its own 1x1 canvas and get pixel color
        local pixel = gd.createTrueColor(1, 1)
        pixel:fill(0, 0, gd.TRANSPARENT)
        pixel:saveAlpha(true)
        pixel:copyResampled(temp, 0, 0, 0, 0, 1, 1, iSZ, iSZ)
        local p = pixel:getPixel(0, 0)
        tint = { pixel:red(p), pixel:green(p), pixel:blue(p) }
    end

    return dstX, dstY, layers, tint
end


local function generate_image(icons)
    local SZ = args.iconsize
    local image_w, image_h, idx, canvas, image_fn

    -- calculate size of icons
    local num = #icons
    image_w = math.ceil(num^0.5)
    if image_w < 2 then
        image_w = 2
    end
    image_h = math.ceil(num / image_w)
    if image_h < 2 then
        image_h = 2
    end

    dbglog(1, ("icon's canvas %sx%s (|xx| show number of layers)...\n"):format(image_w, image_h))

    if not args.noimage then
        canvas = gd.createTrueColor(image_w*SZ, image_h*SZ)
        canvas:fill(0, 0, gd.TRANSPARENT)
        canvas:saveAlpha(true)
    end

    local out = {}
    image_fn = ("%s%s.png"):format(args.version, args.suffix)

    for y = 1, image_h do
        dbglog(-1, ("row %3d |"):format(y))
        local icon
        for x = 1, image_w do
            idx, icon = next(icons, idx)
            if not icon then break end

            local dstX, dstY, layers, tint = copy_icon(x, y, SZ, 1, icon, canvas)

            local t = {
                id = icon.id,
                position = ("%dpx %dpx"):format(-dstX, -dstY),
                color = rgbToHex(tint)
            }
            table.insert(out, t)

            dbglog(-1, ("%2d|"):format(layers))
        end -- for x
        dbglog(-1, "\n")
        if not icon then break end
    end -- for y

    if canvas then
        image = canvas:png(image_fn)
    end

    return out
end

return function(opt)
    dbglog = opt.dbglog
    args = opt.args
    mods = opt.mods
    return { generate_image = generate_image, }
end
