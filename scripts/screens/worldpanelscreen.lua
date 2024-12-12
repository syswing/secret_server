local a = require "widgets/screen"
local b = require "widgets/text"
local c = require "widgets/imagebutton"
local d = require "widgets/image"
local e = require "widgets/grid"
local f = require "widgets/widget"
local g = require "widgets/redux/templates"
local h = require "widgets/worlditem"
local function i(j)
    if not j.isopen then
        return
    end
    j.owner.HUD:CloseWorldPickerScreen()
end
local k = function(l, m)
    local n = h("placeholder")
    n.btn:SetOnGainFocus(
        function()
            l.panel.items_grid:OnWidgetFocus(n)
        end
    )
    return n
end
local o = function(l, p, q, m)
    if q then
        p:SetWorld(q, l.counts[q])
        p.btn:Show()
    else
        p.btn:Hide()
    end
end
local function r(s, t, u)
    local v = #t
    local w, x, y = 140, 200, v > 5 and 5 or v
    if v <= 10 then
        local z = {}
        for A, B in ipairs(t) do
            table.insert(z, h(B, u[B]))
        end
        local C = e()
        C:FillGrid(y, w, x, z)
        C:SetPosition(-w * (y - 1) / 2, v > 5 and x / 2 or 0)
        return C
    end
    local C =
        g.ScrollingGrid(
        t,
        {
            scroll_context = {panel = s, counts = u},
            widget_width = w,
            widget_height = x,
            num_columns = y,
            num_visible_rows = 2,
            scissor_pad = w * 0.18,
            peek_percent = 0,
            scrollbar_height_offset = -50,
            allow_bottom_empty_row = true,
            item_ctor_fn = k,
            apply_fn = o
        }
    )
    C.up_button:SetTextures("images/quagmire_recipebook.xml", "quagmire_recipe_scroll_arrow_hover.tex")
    C.up_button:SetScale(0.5)
    C.down_button:SetTextures("images/quagmire_recipebook.xml", "quagmire_recipe_scroll_arrow_hover.tex")
    C.down_button:SetScale(-0.5)
    C.scroll_bar_line:SetTexture("images/quagmire_recipebook.xml", "quagmire_recipe_scroll_bar.tex")
    C.scroll_bar_line:SetScale(.8)
    C.position_marker:SetTextures("images/quagmire_recipebook.xml", "quagmire_recipe_scroll_handle.tex")
    C.position_marker.image:SetTexture("images/quagmire_recipebook.xml", "quagmire_recipe_scroll_handle.tex")
    C.position_marker:SetScale(.6)
    return C
end
local function D(E, m, t, F)
    local G =
        c("images/picker_images.xml", "menu_item_idle.tex", "menu_item_hover.tex", nil, nil, "menu_item_active.tex")
    G:SetNormalScale(0.7)
    G:SetFocusScale(0.7)
    G:SetFont(HEADERFONT)
    G:SetDisabledFont(HEADERFONT)
    G:SetTextColour(UICOLOURS.GOLD_CLICKABLE)
    G:SetTextFocusColour(UICOLOURS.WHITE)
    G:SetTextSelectedColour(UICOLOURS.GOLD_FOCUS)
    G:SetTextSize(22)
    G:SetText(F, true)
    G.text:SetRegionSize(200, 30)
    G.text:SetHAlign(ANCHOR_MIDDLE)
    G.text:SetPosition(6, 0, 0)
    G.text_shadow:SetRegionSize(200, 30)
    G.text_shadow:SetHAlign(ANCHOR_MIDDLE)
    G.text_shadow:SetPosition(5, -1, 0)
    G:SetOnClick(
        function()
            if E.last_selected then
                E.last_selected:Unselect()
            end
            E.last_selected = G
            G:Select()
            local s = E.panel
            s:KillAllChildren()
            s.items_grid = s:AddChild(r(s, t, E.world_data.counts))
            if TheInput:ControllerAttached() then
                s.items_grid:SetFocus()
            end
        end
    )
    G._tabindex = m - 1
    return {widget = G}
end
local function H(E)
    local I = {}
    local q = E.world_data
    local m = 1
    table.insert(I, D(E, m, q.worlds, STRINGS.MWP.ALL))
    if q.categories then
        for J, B in pairs(q.categories) do
            m = m + 1
            table.insert(I, D(E, m, B, J))
        end
    end
    return I
end
local K =
    Class(
    a,
    function(self, L, M)
        a._ctor(self, "WorldPanelScreen")
        self.owner = L
        self.isopen = true
        self.black = self:AddChild(c("images/global.xml", "square.tex"))
        self.black.image:SetVRegPoint(ANCHOR_MIDDLE)
        self.black.image:SetHRegPoint(ANCHOR_MIDDLE)
        self.black.image:SetVAnchor(ANCHOR_MIDDLE)
        self.black.image:SetHAnchor(ANCHOR_MIDDLE)
        self.black.image:SetScaleMode(SCALEMODE_FILLSCREEN)
        self.black.image:SetTint(0, 0, 0, 0.5)
        local function N()
            i(self)
        end
        self.black:SetOnClick(N)
        self.root = self:AddChild(g.ScreenRoot())
        local O = 14
        self.bg = self.root:AddChild(d("images/picker_images.xml", "picker_board.tex"))
        self.bg:SetScale(0.7)
        self.bg:SetPosition(O, 0, 0)
        self.world_data = M
        self.menu = self.root:AddChild(g.StandardMenu(H(self), 64, false, nil, true))
        self.menu:SetPosition(-448.5, -200, 0)
        self.last_selected = self.menu.items[1]
        self.last_selected:Select()
        self.panel = self.root:AddChild(f("WorldsList"))
        self.panel:SetPosition(O, -13)
        self.last_selected.onclick()
        self.title = self.root:AddChild(b(HEADERFONT, 28, STRINGS.MWP.SELECT_WORLD))
        self.title:SetColour(UICOLOURS.EGGSHELL)
        self.title:SetHAlign(ANCHOR_MIDDLE)
        self.title:SetPosition(O, 230, 0)
        self.closebtn =
            self.root:AddChild(
            c("images/picker_images.xml", "close_btn_idle.tex", "close_btn_hover.tex", nil, "close_btn_down.tex")
        )
        self.closebtn:SetScale(0.7)
        self.closebtn:SetPosition(422 + O, 212, 0)
        self.closebtn:SetOnClick(N)
        self.focus_forward = function()
            return self.panel.items_grid
        end
    end
)
function K:Close()
    if self.isopen then
        self.isopen = false
        TheFrontEnd:PopScreen(self)
    end
end
function K:OnControlTabs(P, Q)
    local R = self.menu.items
    local S = #R
    if S <= 1 then
        return
    end
    if P == CONTROL_OPEN_CRAFTING then
        local T = R[(self.last_selected._tabindex - 1) % S + 1]
        if not Q then
            T.onclick()
            return true
        end
    elseif P == CONTROL_OPEN_INVENTORY then
        local T = R[(self.last_selected._tabindex + 1) % S + 1]
        if not Q then
            T.onclick()
            return true
        end
    end
end
function K:OnControl(P, Q)
    if K._base.OnControl(self, P, Q) then
        return true
    end
    if not Q and (P == CONTROL_CANCEL or P == CONTROL_OPEN_DEBUG_CONSOLE) then
        i(self)
        return true
    end
    return self:OnControlTabs(P, Q)
end
function K:GetHelpText()
    local U = TheInput:GetControllerID()
    local V = {}
    if #self.menu.items > 1 then
        table.insert(
            V,
            TheInput:GetLocalizedControl(U, CONTROL_OPEN_CRAFTING) ..
                "/" .. TheInput:GetLocalizedControl(U, CONTROL_OPEN_INVENTORY) .. " " .. STRINGS.UI.HELP.CHANGE_TAB
        )
    end
    return table.concat(V, "  ")
end
return K
