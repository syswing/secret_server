local a = require "widgets/widget"
local b = require "widgets/text"
local c = require "widgets/imagebutton"
local function d(e, f)
    local g = TUNING.MWP.WORLDS[e]
    local h = tonumber(g.galleryful)
    f = f or 0
    local i = h > 0 and string.format("%s/%s", f, h) or tostring(f)
    return g.desc or g.name or STRINGS.MWP.WORLD .. e, i, g.is_cave == true, g.note
end
local j = {
    regular = {
        "images/picker_images.xml",
        "picker_item_back_regular.tex",
        "picker_item_back_regular_hover.tex",
        "picker_item_back_disabled.tex",
        "picker_item_back_regular_down.tex",
        "picker_item_back_regular_hover.tex"
    },
    cave = {
        "images/picker_images.xml",
        "picker_item_back_cave.tex",
        "picker_item_back_cave_hover.tex",
        "picker_item_back_disabled.tex",
        "picker_item_back_cave_down.tex",
        "picker_item_back_cave_hover.tex"
    }
}
local function k(l, m)
    local n = j[m]
    if not n then
        return
    end
    l:SetTextures(unpack(n))
    l:SetScale(0.68)
end
local o =
    Class(
    a,
    function(self, e, f)
        a._ctor(self, "WorldItem")
        self.wid = e
        self.btn = self:AddChild(c())
        self.btn.SetStyle = k
        self.btn:SetStyle("regular")
        self.focus_forward = self.btn
        self.btn:SetOnClick(
            function()
                SendModRPCToServer(MOD_RPC["multiworldpicker"]["worldpickermigrateRPC"], self.wid)
                ThePlayer.HUD:CloseWorldPickerScreen()
            end
        )
        self.desc = self.btn:AddChild(b(NEWFONT_OUTLINE, 30))
        self.desc:SetVAlign(ANCHOR_MIDDLE)
        self.desc:SetColour(UICOLOURS.WHITE)
        self.desc:SetPosition(0, 10, 0)
        self.online = self.btn:AddChild(b(NEWFONT_OUTLINE, 26))
        self.online:SetVAlign(ANCHOR_MIDDLE)
        self.online:SetColour(UICOLOURS.WHITE)
        self.online:SetPosition(0, -66, 0)
        self:SetWorld(e, f)
        if e == "placeholder" then
            self.btn:Hide()
        end
        self.inst:ListenForEvent(
            "mwp_online_count_changed",
            function(p, q)
                self:UpdateOnline(q.wid, q.count)
            end,
            ThePlayer
        )
    end
)
function o:SetWorld(e, f)
    local r, s, t, u = d(e, f)
    self.wid = e
    self.desc:SetString(r)
    self.online:SetString(s)
    self.btn:SetStyle(t and "cave" or "regular")
    if type(u) == "string" and #u > 0 then
        self.btn:SetHoverText(u, {offset_y = 80, font_size = 18})
    else
        self.btn:ClearHoverText()
    end
end
function o:UpdateOnline(e, f)
    if e == self.wid then
        local v, s = d(e, f)
        self.online:SetString(s)
    end
end
return o
