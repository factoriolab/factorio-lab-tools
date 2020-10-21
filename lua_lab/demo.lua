if not arg[1] then return end
--local ver = "0.18.36"
--local ver = "0.18.36_krastorio2"
--arg[1] = ver

local ver = arg[1]

local raw = dofile(ver..".lua")
local sz = raw.icons[1].size or 32

local html = dofile("factorio/html.lua")
html:init(ver, sz)

html:add(("<h1>%s</h1>\n"):format(ver))

local function ptr_from(t)
    local o = {}
    for i = 1, #t do
        local id = t[i].id
        o[id] = t[i]
    end
    return o
end

local itm = ptr_from(raw.items)
local cat = ptr_from(raw.categories)
local rcp = ptr_from(raw.recipes)
local ico = ptr_from(raw.icons)

for i = 1, #raw.icons do
    local id = ico[raw.icons[i].id].id
    local sz = ico[id].size
    html:css(
        (".%s { width: %dpx; height: %dpx; background-position: %s; }\n")
        :format(id, sz, sz, ico[id].position)
    )
end

html:add([[<ul class="tabs" role="tablist">]])

--local ptr = raw.items
local ptr = raw.recipes

local tab_fmt = [[
<li><input type="radio" name="tabs" id="tab%d" %s />
<label class="tabs_label" for="tab%d" role="tab" aria-selected="true" aria-controls="panel%d" tabindex="0">%s</label>
<div id="tab-content%d" class="tab-content demo_icons" role="tabpanel" aria-labelledby="%s" aria-hidden="false">%s</div></li>
]]
local icon_w_tooltip = [[
<label class="tooltip" title="%s"><div class="demo_icon %s"></div>
<input type="checkbox"><div class="tt_content">%s</div>
</label>
]]

for i = 1, #raw.categories do
    local cid = raw.categories[i].id
    local cname = raw.categories[i].name

    local row = 1
    local subgroup
    local t = {}

    table.insert(t, [[<table class="rows"><tr><td>]])

    for j = 1, #ptr do
        local r = ptr[j]
        local item = itm[r.id]

        if cid == item.category then
            if row ~= item.row then
                table.insert(t, "<br/>")
                row = item.row
            end

            if subgroup ~= item.subgroup then
                if subgroup then
                    table.insert(t, ([[</td><td class="subgroup">%s</td></tr><tr><td>]])
                        :format(subgroup))
                end
                subgroup = item.subgroup
            end

            -- tooltip content
            local tt = {}

            table.insert(tt, [[<table>]])

            table.insert(tt, ([[<tr><td>id: %s<br/>name: %s</td></tr>]]):format(r.id, item.name))

            table.insert(tt, ([[
<tr><td><div class="demo_icon time"></div>&nbsp;%g&nbsp;s]]):format(r.time))

            table.insert(tt, [[<tr><td>→&nbsp;]])
            for k, v in pairs(r["in"] or {}) do
                table.insert(tt, ([[
<div class="demo_icon %s" title="%s"></div>&nbsp;×%g&nbsp;]]):format(k, itm[k].name, v))
            end
            table.insert(tt, [[</td></tr>]])

            table.insert(tt, [[<tr><td>←&nbsp;]])
            if r["out"] then
                for k, v in pairs(r["out"]) do
                    table.insert(tt, ([[
<div class="demo_icon %s" title="%s"></div>&nbsp;×%g&nbsp;]]):format(k, itm[k].name, v))
                end
            else
                table.insert(tt, ([[
<div class="demo_icon %s" title="%s"></div>&nbsp;×%g&nbsp;]]):format(r.id, itm[r.id].name, 1))
            end
            table.insert(tt, [[</td></tr>]])

            table.insert(tt, [[<tr><td>⚙&nbsp;]])
            for k, v in ipairs(r["producers"] or {}) do
                table.insert(tt, ([[
<div class="demo_icon %s" title="%s"></div>&nbsp;]]):format(v, itm[v].name))
            end
            table.insert(tt, [[</td></tr>]])

            table.insert(tt, [[</table>]])

            -- icon with tooltip
            table.insert(t, icon_w_tooltip:format(item.name, r.id, table.concat(tt)))
        end
    end

    table.insert(t, ([[</td><td class="subgroup">%s</td></tr></table>]]):format(subgroup))

    local cat_content = ([[<div class="demo_icon %s" title="#%s
%s"></div>]]):format(cid, cid, cname)

    local content = table.concat(t)

    local checked = 3 == i and "checked" or ""
    local str = tab_fmt:format(i, checked, i, i, cat_content, i, cid, content)
    html:add(str)
end
html:add([[</ul>]])


local w = io.open(ver..".html", "w+b")
w:write(html:out())
w:close()

--[=[
local function generate_image(icons)
    local iconXY = {}

    local html = require("html")
    local SZ = iconsize
    html:init(version, SZ)

    -- calculate size of images
    local num = #icons
    local cat = 0

    for i = 1, #icons do
        local icon = icons[i]
        if "additional-icons" == icon.group
        and "categories" == icon.subgroup then
            num = num - 1
            cat = cat + 1
        end
    end

    -- calculate size of icons
    local image_w = math.ceil(num^0.5)
    if image_w < 2 then
        image_w = 2
    end
    local image_h = math.ceil(num / image_w)

    log(0, ("\nicon's canvas %sx%s (|xx| show number of layers)..."):format(image_w, image_h))

    local canvas
    if not args.noimage then
        canvas = gd.createTrueColor(image_w*SZ, image_h*SZ)
        canvas:fill(0, 0, gd.TRANSPARENT)
        canvas:saveAlpha(true)
    end

    local idx, old_g, old_s
    local row, col = 0, 0

    html:add([[<div class="demo_category"><table>]])

    for y = 1, image_h do
        log(1, ("row %3d |"):format(y))
        local icon
        for x = 1, image_w do
            idx, icon = next(icons, idx)

            while icon
            and "additional-icons" == icon.group
            and "categories" == icon.subgroup do
                idx, icon = next(icons, idx)
            end
            if not icon then break end

            if icon.group ~= old_g then
                row = 0
                col = 0
                if old_g then
                    html:add([[</td></tr></table></div>]])
                    html:add([[<div class="demo_category"><table>]])
                end
                old_g = icon.group
                html:add(([[<tr><td class="demo_group">%s</td></tr>]]):format(old_g))

            end
            if icon.subgroup ~= old_s then
                row = row + 1; --assert(row <= image_h, icon.subgroup .." "..row.." "..image_h)
                col = 0
                if old_s then
                    html:add([[</td></tr>]])
                end
                old_s = icon.subgroup
                html:add(([[<tr><td class="demo_subgroup">%d) %s</td><td class="demo_icons">]]):format(row, old_s))
            end
            html:add(([[<div class="demo_icon %s" title="#%s
%s"></div>]])
                :format(icon.id, icon.id, icon.name))

            if col >= 10 then
                row = row + 1; --assert(row <= image_h, icon.subgroup .." "..row.." "..image_h)
                col = 0
            end
            col = col + 1
            icon.row = row
            icon.col = col

            iconXY[icon.id] = {row, col}

            local dstX, dstY, layers = copy_icon(x, y, SZ, 1, icon, canvas)

            html:css((".%s { width: %dpx; height: %dpx; background-position: %dpx %dpx; }\n"):format(icon.id, SZ, SZ, -dstX, -dstY))

            log(1, ("%2d|"):format(layers))
        end -- for x
        log(1, "\n")
        if not icon then break end
    end -- for y
    html:add([[</td></tr></table></div>]])

    if canvas then
        canvas:png(version .. ".png")
    end


    -- calculate size of big icons
    image_w = math.ceil(cat^0.5)
    if image_w < 2 then
        image_w = 2
    end
    image_h = math.ceil(cat / image_w)

    log(0, ("\ncategory's canvas %sx%s (|xx| show number of layers)..."):format(image_w, image_h))

    SZ = iconsize * 1.5

    canvas = gd.createTrueColor(image_w*SZ, image_h*SZ)
    canvas:fill(0, 0, gd.TRANSPARENT)
    canvas:saveAlpha(true)

    idx, old_g, old_s = nil, nil, nil
    row, col = 1, 0
    html:add([[<div class="demo_category"><table>]])

    for y = 1, image_h do
        log(1, ("row %3d |"):format(y))
        local icon
        for x = 1, image_w do
            idx, icon = next(icons, idx)

            while icon
            and "categories" ~= icon.subgroup do
                idx, icon = next(icons, idx)
            end
            if not icon then break end
            if icon.group ~= old_g then
                row = 0
                if old_g then
                    html:add([[</td></tr></table></div>]])
                    html:add([[<div class="demo_category"><table>"]])
                end
                old_g = icon.group
                html:add(([[<tr><td class="demo_group">%s</td></tr>]]):format(old_g))
            end

            if icon.subgroup ~= old_s then
                row = row + 1; --assert(row <= image_h, icon.subgroup .." "..row.." "..image_h)
                col = 0
                if old_s then
                    html:add([[</td></tr>]])
                end
                old_s = icon.subgroup
                html:add(([[<tr><td class="demo_subgroup">%s</td><td class="demo_cats">]]):format(old_s))
            end

            html:add(([[<div class="demo_cat_icon %s" title="#%s
%s"></div>]]):format(icon.id, icon.id, icon.name))

            if col > 6 then
                row = row + 1; --assert(row <= image_h, icon.subgroup .." "..row.." "..image_h)
                col = 0
            end
            col = col + 1
            icon.row = row
            icon.col = col

            iconXY[icon.id] = {row, col}

            local dstX, dstY, layers = copy_icon(x, y, SZ, 2, icon, canvas)

            html:css((".%s { width: %dpx; height: %dpx; background-position: %dpx %dpx; }\n"):format(icon.id, SZ, SZ, -dstX, -dstY))

            log(1, ("%2d|"):format(layers))
        end -- for x
        log(1, "\n")
        if not icon then break end
    end -- for y
    html:add([[</td></tr></table></div>]])

    html:add("</body></html>\n")

    if canvas then
        canvas:png(version .. "_cat.png")
    end

    save_file(table.concat(html.style), version .. ".css")
    save_file(table.concat(html.body), version .. ".html")

    return iconXY
end
]=]
