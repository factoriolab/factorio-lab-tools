local html = {
    body = {},
    style = {},
}

function html:add(...) table.insert(self.body, ...) end
function html:css(...) table.insert(self.style, ...) end
local scale, w1, w2, w3, w4, m1, m2

function html:init(version, sz)
    scale = sz / 32
    w1 = 100
    w2 = (4 + 32 + 4) * 10 * scale
    w3 = (6 + 32 + 6) * 6 * scale
    w4 = math.floor(w2 / 3 * 2)
    m1 = 0 * scale
    m2 = 2 * scale

    self.style = {[1] = ([[
body { background-color: #fff; }
.tabs { position: relative; padding: 0; }
.tabs li { float: left; display: block; }
.tabs input[type="radio"] { position: absolute; top: -9999px; left: -9999px; }
.tabs .tabs_label { display: block; padding: 0.5em; background: #fff; cursor: pointer; }
.tabs .tabs_label:hover { background: #eee; }
.tabs [id^="tab"]:checked + label { padding-top: 0.7em; background: #ddd; }
.tabs [id^="tab"]:checked ~ [id^="tab-content"] { display: block; }
.tabs .tab-content { z-index: 2; display: none; /*width: %dpx;*/ position: absolute; left: 1em; }

.demo_icons { padding: 0; }
.demo_icon { display: inline-block; background-image: url("%s.png"); background-repeat: no-repeat; margin: %dpx; /*outline: 1px solid darkgrey;*/ }
.demo_icon:hover { outline: 3px solid grey; }
.demo_cat_icon { display: inline-block; background-image: url("%s.png"); background-repeat: no-repeat; margin: %dpx; }

.rows td { border-top: 1px solid black; }
.rows .subgroup { border-left: 1px solid black; }

.tooltip { position: relative; }
.tooltip .tt_content { visibility: hidden; position: absolute; width: %dpx; background: #f8f8f8; padding: 0.5em; top: 0; left: 0; z-index: 2; }
.tooltip input { display:none; }
.tooltip input:checked+.tt_content { visibility: visible; outline: 1px solid darkgrey; }

.tt_content table { width: %dpx; }
.tt_content td { border-bottom: 1px solid black; padding: 0.1em 0.2em; }
.tt_content .demo_icon { vertical-align: middle; }
]]):format(w2, version, m1, version, m2, w4, w4)
}

    self.body = {[1] = ([[
<!DOCTYPE html>
<html><head><meta charset="utf-8" /><title>%s</title>
<style>%%s</style>
</head><body>
]]):format(version)}
end

function html:out()
    self:add("</body></html>\n")
    self.body[1] = self.body[1]:format(table.concat(self.style))
    
    return table.concat(self.body)
end

return html
