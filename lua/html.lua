local html = {
    body = {},
    style = {},
}

function html:add(...) table.insert(self.body, ...) end

function html:css(...) table.insert(self.style, ...) end

function html:init(version, sz, mult)
    self.body = {
([[
<!DOCTYPE html>
<html><head><meta charset="utf-8" /><title>Demo</title>
<link rel="stylesheet" href="./%s.css">
</head><body>
]]):format(version)
}
    local scale = sz / 32
    local w1 = 150
    local w2 = 40 * 10 * scale
    local w3 = 60 * 6 * scale
    local m1 = 4 * scale
    local m2 = 6 * scale
    self.style = {
([[
.demo_category { display: inline-block; vertical-align: top; padding: 0.5em; }
.demo_category table { border-spacing: 0px; border-collapse: collapse; border-style: hidden; }
.demo_category .demo_group { font-size: larger; font-weight: bold; width: %dpx; }
.demo_category .demo_subgroup { width: %dpx; }
.demo_category .demo_icons { width: %dpx; background-color: gray; font-size: 0; padding: 0; }
.demo_category .demo_cats { width: %dpx; background-color: gray; font-size: 0; padding: 0; }
.demo_category .demo_icon { display: inline-block; background-image: url("%s.png"); background-repeat: no-repeat; margin: %dpx; }
.demo_category .demo_cat_icon { display: inline-block; background-image: url("%s_cat.png"); background-repeat: no-repeat; margin: %dpx; }
]]):format(w1, w1, w2, w3, version, m1, version, m2)
}
end

return html
