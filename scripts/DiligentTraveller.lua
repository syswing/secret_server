local COLOURS = {
  locally = {255, 255, 255, 1},
  foreign = {141, 241, 158, 1},
  near = {128, 142, 151, 1},
  unnamed = {255, 255, 0, 1}
}
for k, v in pairs(COLOURS) do COLOURS[k] = {rgba(unpack(v))} end
if not STRINGS.DILIGENTTRAVELLER then
  local lang = GetLanguageName()
  if lang == "chinese" then
      STRINGS.DILIGENTTRAVELLER = {RENAME = "改名"}
  else
      STRINGS.DILIGENTTRAVELLER = {RENAME = "rename"}
  end
  STRINGS.DILIGENTTRAVELLER.TELEPORT = STRINGS.ACTIONS.TRAVEL
end
local Widget = require "widgets/widget"
local TEMPLATES = require "widgets/redux/templates"
local UIAnim = require "widgets/uianim"
local Image = require "widgets/image"
local Text = require "widgets/text"
local TextEdit = require "widgets/textedit"
---------------------------------------------------------
-- insert logic for controller because it cannot gain focus
local Screen = require "widgets/screen"
local isscreen = GetConfig("screen") or "false" == "true"
local Base = isscreen and Screen or Widget
---------------------------------------------------------
local pause = GetConfig("pause") or "false" == "true"
DiligentTraveller = Class(Base, function(self, owner)
  Base._ctor(self, "DiligentTraveller")
  if not owner then CONSOLE.err("no owner specified") end
  local root = safefetch(owner, "_parent", "HUD", "controls", "containerroot")
  if not root then
      CONSOLE.warn("no owner HUD", owner)
      self:Hide()
  else
      root:AddChild(self)
      self:MoveToBack()
  end
  self.isopen = true
  self:SetScaleMode(SCALEMODE_PROPORTIONAL)
  self:SetVAnchor(ANCHOR_MIDDLE)
  self:SetHAnchor(ANCHOR_MIDDLE)
  if self.SetHAlign then
  self:SetVAlign(ANCHOR_MIDDLE)
  self:SetHAlign(ANCHOR_MIDDLE)
  end
  self.owner = owner
  self.portals = {}
  self.bgtex = "scoreboard_frame.tex"
  self.bgatlas = "images/scoreboard.xml"
  self.bgimagew = 680
  self.bgimageh = 1024
  self.fontheight = 30
  self.lineheight = 50
  self.minx = 130
  self.miny = 200
  local sx, sy = thescreen.getScreenSize()
  self.maxx = sx - self.minx
  self.maxy = sy - self.miny
  self.bgtargetw = 300
  self.bgtargeth = self.bgimageh / self.bgimagew * self.bgtargetw
  self.padding = 30
  self.offsetx = 0
  self.offsety = self.bgtargeth / 2
  self.listoffset = -2
  self.bgimage = self:AddChild(Image(self.bgatlas, self.bgtex))
  self.bgimage.inst.UITransform:SetRotation(90)
  self.bgimage:MoveToBack()
  self.bganim = self:AddChild(UIAnim())
  self.bganim:GetAnimState():AnimateWhilePaused(true)
  self.scrolist = self:AddChild(TEMPLATES.ScrollingGrid(self.portals, {
      context = {},
      widget_width = self.bgtargetw - self.padding * 2,
      widget_height = self.lineheight,
      num_visible_rows = 8,
      num_columns = 1,
      item_ctor_fn = function(...)
          return self:CreateScrolist(...)
      end,
      apply_fn = function(...)
          return self:ApplyDataToWidget(...)
      end,
      scrollbar_offset = 10,
      scrollbar_height_offset = -60,
      peek_percent = 0,
      allow_bottom_empty_row = true
  }))
  self.scrolist:SetPosition(0, self.listoffset, 0)
  self:ReplaceScrollbar()
  local scale = self.bgtargetw / self.bgimagew
  self.bgimage:SetScale(scale)
  scale = TheFrontEnd:GetHUDScale()
  self:SetScale(scale)
  self.inst:ListenForEvent("refreshhudsize", function(hud, scale)
      self:SetScale(scale)
      local sx, sy = thescreen.getScreenSize()
      self.maxx = sx - self.minx
      self.maxy = sy - self.miny
  end)
  self:Close()
  self.blockcamera = true -- custom block signal
  self.focus_forward = self.scrolist
  HackCameraControl()
  exposeToGlobal("dtw", self)
  if isscreen then
      -- hack to prevent from PopScreen
      self.OnDestroy = function()
      end
  end
end)
function DiligentTraveller:Remove()
  self:Kill()
end
function DiligentTraveller:ReplaceScrollbar()
  local s = self.scrolist
  -- use old texture
  local atlas = "images/ui.xml"
  local upimage = "arrow_scrollbar_up.tex"
  local downimage = "arrow_scrollbar_down.tex"
  local lineimage = "scrollbarline.tex"
  local boximage = "scrollbarbox.tex"
  s.up_button:SetTextures(atlas, upimage)
  s.down_button:SetTextures(atlas, downimage)
  s.position_marker:SetTextures(atlas, boximage)
  s.scroll_bar_line:SetTexture(atlas, lineimage)
  s.up_button:SetScale(1)
  s.down_button:SetScale(1)
  s.scroll_bar_line:SetScale(1)
  s.position_marker:SetScale(1)
  -- it is very bad that SetTextures actually does not respond instantly. So we need to call Image:SetTexture
  s.up_button.image:SetTexture(atlas, upimage)
  s.down_button.image:SetTexture(atlas, downimage)
  s.position_marker.image:SetTexture(atlas, boximage)
end
function DiligentTraveller:CreateScrolist(context, index)
  local widget = Widget("widget-" .. index)

  widget:SetOnGainFocus(function()
      self.scrolist:OnWidgetFocus(widget)
  end)

  local dest = widget:AddChild(self:ListItem())
  widget.destitem = dest
  widget.focus_forward = dest

  return widget
end
local actions = {
  {
      name = "TELEPORT",
      fn = function(x)
          return not x.foreign and not x.near and not x.myself and IsClient()
      end,
      action = function(self, x)
          c_teleport(x.x, 0, x.z, self.owner and self.owner._parent or ThePlayer)
      end,
      control = {"RMB"}
  },
  {
      name = "RENAME",
      fn = function(x)
          return x.near
      end,
      action = function(self, x)
          return self:EraseName(x.index)
      end,
      control = {"RMB"}
  },
  {
      name = "TRAVEL",
      fn = function(x)
          return not x.near
      end,
      action = function(self, x)
          return self:Travel(x.index)
      end,
      control = {"LMB"}
  }
}
function DiligentTraveller:ActionPicker(info)
  local ret = {}
  local res = {}
  for i, action in ipairs(actions) do
      if action.fn(info) then
          for _, c in ipairs(action.control) do
              if ret[c] then
                  res[ret[c]] = nil
              else
                  ret[c] = action.name
                  res[action.name] = action
              end
          end
      end
  end
  return res
end
function DiligentTraveller:AttachTo(portal)
  if not portal then return end
  local x, y, z = thescreen.getscreen(portal)
  if not thescreen.isvalid(x, y, z) then return end
  if not self.parent then
      local root = safefetch(self.owner, "_parent", "HUD", "controls", "containerroot")
      if not root then
          CONSOLE.warn("no owner HUD", self.owner)
          self:Hide()
      else
          root:AddChild(self)
          self:MoveToBack()
      end
  end
  local offx, offy = x + self.offsetx, y + self.offsety
  offx = math.clamp(offx, self.minx, self.maxx)
  offy = math.clamp(offy, self.miny, self.maxy)
  --self:SetPosition(offx, offy, 0)--removed in substitute by center alignment
end
function DiligentTraveller:Open(doer)
  if self.isopen then
      self:SetFocus()
      return
  end
  -- self:AttachTo(self.owner)
  if TheWorld and TheWorld.PortalManager then self:LoadData(TheWorld.PortalManager.info) end
  self.bganim:GetAnimState():Resume()
  self:Show()
  self.isopen = true
  if isscreen then TheFrontEnd:PushScreen(self) end
  self:SetFocus()
  if pause then SetAutopaused(true) end
end
function DiligentTraveller:Close()
  if not self.isopen then return end
  self:Hide()
  self.bganim:GetAnimState():Pause()
  self.isopen = false
  if isscreen then TheFrontEnd:PopScreen(self) end
  if pause then SetAutopaused(false) end
end
local radius = GetConfig("radius") or 10
function DiligentTraveller:IsNear(x1, z1, x2, z2)
  return math.abs(x1 - x2) + math.abs(z1 - z2) < radius
end
function DiligentTraveller:LoadData(allportals)
  if type(allportals) ~= "table" then return end
  local player = self.owner and self.owner._parent or ThePlayer
  local x, y, z = 0, 0, 0
  if VerifyInst(player) then x, y, z = player:GetPosition():Get() end
  local portals = {}
  for i, data in ipairs(allportals) do
      if data then
          local info = {}
          info.index = i
          info.guid = data.guid
          info.worldid = data.worldid
          info.foreign = not not data.worldid
          info.x = data.x
          info.z = data.z
          info.name = data.text
          info.near = not info.foreign and self:IsNear(data.x, data.z, x, z)
          table.insert(portals, info)
      end
  end
  self.portals = portals
  self:RefreshData()
end
function DiligentTraveller:RefreshData()
  local data = {}
  table.ifilter(self.portals, function(v)
      table.insert(data, {index = v.index, info = v})
  end)
  self.scrolist:SetItemsData(data)
end
function DiligentTraveller:ListItem()
  local dest = Widget("destination")

  local item_width, item_height = self.bgtargetw - self.padding * 2, self.lineheight
  dest.backing = dest:AddChild(TEMPLATES.ListItemBackground(item_width, item_height, function()
  end))
  dest.backing.move_on_click = true
  dest.backing:SetOnGainFocus(function()
      local actions = dest._actions or self:ActionPicker(dest.info)
      if next(actions) then
          dest.cached = dest.named:GetString()
          for k, v in pairs(actions) do
              if table.has(v.control, "RMB") then
                  dest.named:SetString((STRINGS.RMB or "") .. (STRINGS.DILIGENTTRAVELLER[v.name] or ""))
              end
          end
      end
  end)
  dest.backing:SetOnLoseFocus(function()
      if dest.cached then dest.named:SetString(dest.cached) end
  end)
  local function LMB()
      local actions = dest._actions or self:ActionPicker(dest.info)
      if next(actions) then
          for k, v in pairs(actions) do if table.has(v.control, "LMB") then v.action(self, dest.info) end end
      end
  end
  local RMB = function()
      local actions = dest._actions or self:ActionPicker(dest.info)
      if next(actions) then
          for k, v in pairs(actions) do if table.has(v.control, "RMB") then v.action(self, dest.info) end end
      end
  end
  AddClickHandler(dest.backing, LMB)
  AddClickHandler(dest.backing, RMB, true)

  dest.named = dest:AddChild(Text(BODYTEXTFONT, self.fontheight))
  dest.named:SetPosition(0, 0, 0)
  dest.named:SetVAlign(ANCHOR_MIDDLE)
  dest.named:SetHAlign(ANCHOR_MIDDLE)
  dest.named:SetRegionSize(self.bgtargetw - self.padding * 2, self.lineheight)
  function dest:SetInfo(info)
      if not info then return false end
      dest.cached = nil
      dest.info = info

      if info.name and info.name ~= "" then
          dest.named:SetString(info.name)
          dest.named:SetColour(unpack(COLOURS.locally))
      else
          local fmt = "%.0f,%0.f"
          local pivot = string.format(fmt, info.x, info.z)
          local text = "(" .. pivot .. ")"
          dest.named:SetString(text)
          dest.named:SetColour(unpack(COLOURS.unnamed))
      end
      if info.near then dest.named:SetColour(unpack(COLOURS.near)) end
      if info.foreign then dest.named:SetColour(unpack(COLOURS.foreign)) end
  end
  dest.focus_forward = dest.backing
  local oldOnControl = dest.backing.OnControl
  function dest.backing:OnControl(control, down, ...)
      if not down and self.focus then
          if control == CONTROL_ACCEPT then
              LMB()
              return true
          elseif control == CONTROL_MENU_MISC_1 or control == CONTROL_MENU_MISC_2 then
              RMB() -- for controller
              return true
          end
      end
      return oldOnControl(self, control, down, ...)
  end
  return dest
end
if isscreen then
  function DiligentTraveller:OnControl(control, down)
      if DiligentTraveller._base.OnControl(self, control, down) then return true end
      if down then return end
      --CONSOLE.log("DiligentTraveller OnControl", control, down)
      if control == CONTROL_CANCEL or control == CONTROL_PAUSE then
          self:Close()
      end
      return true
  end
end
function DiligentTraveller:EraseName(index)
  local guid = self.portals[index].guid
  if guid and TheWorld and TheWorld.PortalManager then TheWorld.PortalManager:EraseName(guid) end
end
function DiligentTraveller:ApplyDataToWidget(context, widget, data, index)
  widget.data = data
  widget.destitem:Hide()
  if not data then
      widget.focus_forward = nil
      return
  end

  widget.focus_forward = widget.destitem
  widget.destitem:Show()

  local dest = widget.destitem

  dest:SetInfo(data.info)
end
function DiligentTraveller:Travel(index)
  if not self.isopen then return end
  -- prevent self teleport
  local target = self.portals[index]
  if not target then return end
  if target.near then return end
  self.recenttarget = target
  self:Hide()
  -- CONSOLE.log("travel to " .. index, target.guid)
  if TheWorld and TheWorld.PortalManager then
      TheWorld.PortalManager:Teleport(nil, ThePlayer, target.guid, target.worldid)
  end
end
return DiligentTraveller
