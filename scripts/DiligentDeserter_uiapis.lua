-- @dependency apis.lua
local GLOBAL = _G
-- SCENE		using an object in the world
-- USEITEM		using an inventory item on an object in the world
-- POINT		using an inventory item on a point in the world
-- EQUIPPED		using an equiped item on yourself or a target object in the world
-- INVENTORY	using an inventory item
-- CLICK        left click on anything to walk to or interact with
-- SELF         using an inventory item itself (usually a container)
function DoRPCAction(action, item, target, actiontype, doer, pos, ent, id)
  if not doer then doer = ThePlayer end
  if not VerifyInst(doer) then return end
  local act = type(action) == "string" and ACTIONS[action or ""] or action
  if not act then
    CONSOLE.err("DoRPCAction: no action given")
    return
  end
  if not actiontype then actiontype = "SCENE" end
  local rpc = nil
  local distance = act == ACTIONS.CASTAOE and target ~= nil and
                     target.components.aoetargeting ~= nil and
                     target.components.aoetargeting:GetRange() or nil
  actiontype = string.upper(actiontype)
  if actiontype == "SCENE" then
    if not item then
      actiontype = "CLICK"
    else
      rpc = RPC.ControllerUseItemOnSceneFromInvTile
    end
  elseif actiontype == "INVENTORY" then
    rpc = RPC.UseItemFromInvTile
  elseif actiontype == "SELF" then
    rpc = RPC.ControllerUseItemOnSelfFromInvTile
  elseif actiontype == "USEITEM" then
    rpc = RPC.ControllerUseItemOnItemFromInvTile
  elseif actiontype == "POINT" then
    if not item then
      actiontype = "CLICK"
    else
      rpc = RPC.ControllerUseItemOnPoint
    end
  elseif actiontype == "EQUIPPED" then
    rpc = RPC.ControllerUseItemOnSelfFromInvTile
  end
  if actiontype == "CLICK" then
    -- function(player, action, x, z, target, isreleased, controlmods, noforce, mod_name, platform, platform_relative)
    rpc = act.rmb and RPC.RightClick or RPC.LeftClick
  elseif actiontype == "LEFTCLICK" then
    actiontype = "CLICK"
    rpc = RPC.LeftClick
  elseif actiontype == "RIGHTCLICK" then
    actiontype = "CLICK"
    rpc = RPC.RightClick
  end
  if actiontype == "CLICK" then
    pos = pos or (target and thescreen.xyz2v(thescreen.getworld(target))) or
            (item and thescreen.xyz2v(thescreen.getworld(item)))
  end
  -- CONSOLE.log("RPC Action:", act, "Action Type:", actiontype, "item:", item, "target/useitem:", target, "pos:", pos,
  --    "distance:", distance, "doer:", doer, "ent:", ent, "id:", id)
  if not rpc then
    CONSOLE.err("unsupported type", actiontype)
    return
  end
  -- self, doer, target, action, invobject, pos, recipe, distance, forced, rotation)
  local buffact = act
  if not buffact:is_a(BufferedAction) then
    buffact = BufferedAction(doer, target, act, item, pos, nil, distance, nil,
                             nil)
  else
    pos = pos or (item and item:GetPosition()) or
            (target and target:GetPosition()) or (doer:GetPosition())
    -- this is actually a buffact
    act = buffact.action or act.action or act
    buffact.pos = buffact.pos or pos ~= nil and DynamicPosition(pos) or nil
  end
  local ismousereleased = true
  local rotation = 0
  local canforce = act.canforce
  local cmode = nil -- CONTROL_FORCE_INSPECT,CONTROL_FORCE_ATTACK,CONTROL_FORCE_TRADE,CONTROL_FORCE_STACK,
  if IsClient() then
    local function cb()
      if rpc == RPC.RightClick then
        SendRPCToServer(rpc, act.code, buffact.pos.local_pt.x,
                        buffact.pos.local_pt.z, target, rotation,
                        ismousereleased, cmode, canforce,
                        buffact.action.mod_name, buffact.pos.walkable_platform,
                        buffact.pos.walkable_platform ~= nil)
      elseif rpc == RPC.LeftClick then
        -- CONSOLE.log(rpc, act.code, buffact.pos.local_pt.x, buffact.pos.local_pt.z, target, ismousereleased,
        --     cmode, canforce, buffact.action.mod_name, buffact.pos.walkable_platform,
        --    buffact.pos.walkable_platform ~= nil, ent, id)
        SendRPCToServer(rpc, act.code, buffact.pos.local_pt.x,
                        buffact.pos.local_pt.z, target, ismousereleased, cmode,
                        canforce, buffact.action.mod_name,
                        buffact.pos.walkable_platform,
                        buffact.pos.walkable_platform ~= nil, ent, id)
      else
        SendRPCToServer(rpc, act.code, item, target) -- broken with equipped
      end
    end

    if ThePlayer.components.locomotor then
      buffact.preview_cb = cb
    else
      cb()
    end
  end
  local pc = ThePlayer.components.playercontroller
  if pc then pc:DoAction(buffact) end
end

local function ServerUseItemFromInv(inv, actiontype, item, target)
  if actiontype == "SCENE" then
    inv:ControllerUseItemOnSceneFromInvTile(item, target)
  elseif actiontype == "INVENTORY" then
    if not target then
      CONSOLE.err("UseItemFromInventory: target is", target)
      return
    end
    inv:ControllerUseItemOnItemFromInvTile(target, item)
  elseif actiontype == "USEITEM" then
    inv:UseItemFromInvTile(item)
  elseif actiontype == "POINT" then
    CONSOLE.info("current function does not support POINT type yet.")
  elseif actiontype == "SELF" then
    inv:ControllerUseItemOnSelfFromInvTile(item)
  else
    CONSOLE.err("unsupported type", actiontype)
    return false
  end
  return true
end
local function ClientUseItemFromInv(inv, actiontype, item, target)
  -- patched SCENE, official API doesn't support target param.
  if actiontype == "SCENE" then
    -- inv:ControllerUseItemOnSceneFromInvTile(item @invalid[, target])
    local buffact = nil
    local pc = ThePlayer.components.playercontroller
    if target then
      buffact = pc:GetItemUseAction(item, target)
    elseif item.replica.equippable ~= nil and
      item.replica.equippable:IsEquipped() then
      buffact = pc:GetItemSelfAction(item)
      -- elseif item.replica.inventoryitem ~= nil and not item.replica.inventoryitem:IsGrandOwner(inst._parent) then
      -- V2C: This is now invalid as playercontroller will now send this
      --     case to the proper call to move items between controllers.
    else
      buffact = pc:GetItemUseAction(item)
    end
    if buffact then
      pc:RemoteControllerUseItemOnSceneFromInvTile(buffact, item)
    else
      CONSOLE.err("no valid action found for item", item, "target", target)
      return false
    end
  elseif actiontype == "INVENTORY" then
    if not target then
      CONSOLE.err("UseItemFromInventory: target is", target)
      return false
    end
    inv:ControllerUseItemOnItemFromInvTile(target, item)
  elseif actiontype == "USEITEM" then
    inv:UseItemFromInvTile(item)
  elseif actiontype == "POINT" then
    CONSOLE.info("current function does not support POINT type yet.")
  elseif actiontype == "SELF" then
    inv:ControllerUseItemOnSelfFromInvTile(item)
  else
    CONSOLE.err("unsupported type", actiontype)
    return false
  end
  return true
end
-- shorthand for useitem
function UseItem(item) return UseItemFromInventory("USEITEM", item) end

function UseItemFromInventory(actiontype, item, target)
  actiontype = string.upper(actiontype)
  if not actiontype then actiontype = "USEITEM" end
  if type(actiontype) ~= "string" then
    CONSOLE.err("UseItemFromInventory: type is not string", "type is",
                actiontype)
    return false
  end
  if not item then
    CONSOLE.err("UseItemFromInventory: item is", item)
    return false
  end
  local inv = safefetch(ThePlayer, "components", "inventory")
  if inv then return ServerUseItemFromInv(inv, actiontype, item, target) end
  inv = safefetch(ThePlayer, "replica", "inventory")
  if inv then return ClientUseItemFromInv(inv, actiontype, item, target) end
  CONSOLE.err("UseItemFromInventory: inventory is nil")
  return false
end

function DoAttack(target, forced, guy)
  local guy = guy or ThePlayer
  local self = safefetch(guy, "components", "playercontroller")
  if not self then return false end
  if target == nil then
    -- Still need to let the server know our attack button is down
    if not self.ismastersim and self.locomotor == nil and
      self.remote_controls[CONTROL_ATTACK] == nil then
      self:RemoteAttackButton()
    end
    return true -- no target
  end

  if self.ismastersim then
    self.locomotor:PushAction(BufferedAction(self.inst, target, ACTIONS.ATTACK),
                              true)
  elseif self.locomotor == nil then
    self:RemoteAttackButton(target, forced)
  elseif self:CanLocomote() then
    local buffaction = BufferedAction(self.inst, target, ACTIONS.ATTACK)
    buffaction.preview_cb = function()
      self:RemoteAttackButton(target, forced)
    end
    self.locomotor:PreviewAction(buffaction, true)
  else
    return false
  end
end

--- func MatchCriteria
---@param item table
---@param criteria table {prefab,must,cant,tag,fn}
---@param inst any
---@return boolean
function MatchCriteria(item, criteria, inst)
  if not criteria then return true end
  if criteria.prefab then
    if type(criteria.prefab) == "string" then
      if item.prefab ~= criteria.prefab then return false end
    elseif type(criteria.prefab) == "table" then
      if not table.contains(criteria.prefab, item.prefab) then return false end
    else
      CONSOLE.err("MatchCriteria: Unsupported prefab type", criteria.prefab)
    end
  end
  if criteria.tag then
    if type(criteria.tag) == "string" then
      if not item:HasTag(criteria.tag) then return false end
    elseif type(criteria.tag) == "table" then
      if not item:HasOneOfTags(criteria.tag) then return false end
    else
      CONSOLE.err("MatchCriteria: Unsupported tag type", criteria.tag)
    end
  end
  if criteria.must then
    for i, v in ipairs(criteria.must) do
      if not item:HasTag(v) then return false end
    end
  end
  if criteria.cant then
    if item:HasOneOfTags(criteria.cant) then return false end
  end
  if criteria.fn and not criteria.fn(item, inst) then return false end
  return true
end

function GetItemsFromInventoryByCriteria(inv, criteria)
  local ret = {}
  if not inv then return ret end
  if not criteria then return ret end
  MapDict(inv, function(k, v)
    if v and MatchCriteria(v, criteria) then table.insert(ret, v) end
  end)
  return ret
end

function GetNumberOfItemsFromInventoryByCriteria(inv, criteria)
  local ret = {}
  if not inv then return ret end
  if not criteria then return ret end
  MapDict(inv, function(k, v)
    if v and MatchCriteria(v, criteria) then table.insert(ret, k) end
  end)
  return ret
end

local function SafeGetContainer(inst)
  if not inst then return nil end
  if inst.replica.container then return inst.replica.container:GetItems() end
  if inst.components.container then return inst.components.container.slots end
  return nil
end

function GetSelectedItemsFromInventory(inv, criteria)
  if inv and inv.GetItems then
  else
    CONSOLE.err("GetItemFromInventory:inv is", inv)
    return {}
  end
  if not criteria then
    CONSOLE.err("GetItemFromInventory:criteria is", criteria)
    return {}
  end
  if type(criteria) == "string" then criteria = {prefab = criteria} end
  local emptytable = {}
  local equipitems = {}
  local packitems = {}
  local items = inv:GetItems() or emptytable
  local equips = inv:GetEquips() or emptytable
  MapDict(equips, function(k, v) table.insert(equipitems, v) end)
  MapDict(equipitems, function(_, backpack)
    local thispack = SafeGetContainer(backpack)
    if thispack then packitems[backpack.GUID or math.random()] = thispack end
  end)
  local invs = packitems
  invs.equipitems = equipitems
  invs.items = items
  if inv.activeitem then invs.activeitems = {inv.activeitem} end
  if inv.GetActiveItem then invs.activeitems = {inv:GetActiveItem()} end
  -- local overflow=inv:GetOverflowContainer()
  -- =body
  local opencontainers = inv:GetOpenContainers() or emptytable
  MapDict(opencontainers, function(chest, _)
    local container = SafeGetContainer(chest)
    if container then invs[chest.GUID or math.random()] = container end
  end)
  local set = {}
  local mapping = {}
  MapDict(invs, function(_, pack)
    if pack then
      local selecteditems = GetItemsFromInventoryByCriteria(pack, criteria)
      MapDict(selecteditems,
              function(__, item) mapping[item.GUID or math.random()] = item end)
    end
  end)
  MapDict(mapping, function(_, item) table.insert(set, item) end)
  return set
end

function GetNumberOfSelectedItemsFromInventory(inv, criteria)
  if inv and inv.GetItems then
  else
    CONSOLE.err("GetItemFromInventory:inv is", inv)
    return {}
  end
  if not criteria then
    CONSOLE.err("GetItemFromInventory:criteria is", criteria)
    return {}
  end
  if type(criteria) == "string" then criteria = {prefab = criteria} end
  local emptytable = {}
  local equipitems = {}
  local packitems = {}
  local items = inv:GetItems() or emptytable
  local equips = inv:GetEquips() or emptytable
  MapDict(equips, function(k, v) table.insert(equipitems, v) end)
  MapDict(equipitems, function(_, backpack)
    local thispack = SafeGetContainer(backpack)
    if thispack then packitems[backpack.GUID or math.random()] = thispack end
  end)
  local invs = packitems
  invs.equipitems = equipitems
  invs.items = items
  if inv.activeitem then invs.activeitems = {inv.activeitem} end
  if inv.GetActiveItem then invs.activeitems = {inv:GetActiveItem()} end
  -- local overflow=inv:GetOverflowContainer()
  -- =body
  local opencontainers = inv:GetOpenContainers() or emptytable
  MapDict(opencontainers, function(chest, _)
    local container = SafeGetContainer(chest)
    if container then invs[chest.GUID or math.random()] = container end
  end)
  local ret = {}
  MapDict(invs, function(k, v)
    if v then ret[k] = GetNumberOfItemsFromInventoryByCriteria(v, criteria) end
  end)
  return ret
end

function PlayerTalkText(text)
  local talker = safefetch(ThePlayer, "components", "talker")
  if not talker then return end
  talker:Say(text)
end

function PlayerTalk(str, ...) PlayerTalkText(FormatString(str, ...)) end

function LocalSay(name, text, color_param, icons)
  local color = color_param or {rgba(255, 98, 71, 1)}
  if #color ~= 4 then
    CONSOLE.err("LocalSay: color parameter must be 4.")
    return false
  end
  local function getname(inst)
    return
      inst and (inst.name or inst.GetDisplayName and inst:GetDisplayName()) or
        "???"
  end
  if not name then name = getname(ThePlayer) end
  local guid, userid, name, prefab, message, colour, whisper, isemote,
        user_vanity = -1, -1, name, nil, text, color, false, false,
                      type(icons) == "string" and {icons} or icons
  Networking_Say(guid, userid, name, prefab, message, colour, whisper, isemote,
                 user_vanity)
end

--[[
    announce_type=default|resurrect|rollback|death|joinGLOBALame|leaveGLOBALamekicked_fromGLOBALame|banned_fromGLOBALame
]]
function NetAnnounce(message, color_param, announce_type)
  if not announce_type then announce_type = "default" end
  return Networking_Announcement(message, color_param, announce_type)
end

--[[
    These announce functions are local.
    If you want to announce to everyone, use TheNet:Announce(message,?,?,type)(server),TheNet:Say(message)(client) instead.
]]
announce = {
  say = LocalSay,
  announce = NetAnnounce,
  system = Networking_SystemMessage,
  death = function(message, color_param)
    NetAnnounce(message, color_param, "death")
  end,
  resurrect = function(message, color_param)
    NetAnnounce(message, color_param, "resurrect")
  end,
  rollback = function(message, color_param)
    NetAnnounce(message, color_param, "rollback")
  end,
  join = function(message, color_param)
    NetAnnounce(message, color_param, "join_Game")
  end,
  leave = function(message, color_param)
    NetAnnounce(message, color_param, "leave_game")
  end,
  kicked = function(message, color_param)
    NetAnnounce(message, color_param, "kicked_from_game")
  end,
  banned = function(message, color_param)
    NetAnnounce(message, color_param, "banned_from_game")
  end
}
CONSOLE.talk = PlayerTalkText
function GetActiveScreen()
  local TheFrontEnd = safefetch(GLOBAL, "TheFrontEnd")
  if safefetch(TheFrontEnd, "GetActiveScreen") then
    return safefetch(TheFrontEnd:GetActiveScreen(), "name") or ""
  else
    return ""
  end
end

function IsNotGameScreen()
  if not VerifyPlayer() then return false end
  local h = ThePlayer.HUD
  if not h then return false end
  local activeScreen = GetActiveScreen()
  return not activeScreen:find("HUD") or h.writeablescreen ~= nil or
           (h.IsCraftingOpen and h:IsCraftingOpen()) or
           (h.IsGroomerScreenOpen and h:IsGroomerScreenOpen()) or
           (h.IsPlayerAvatarPopUpOpen and h:IsPlayerAvatarPopUpOpen())
end

function GetModKeys(keys)
  if type(keys) == "number" then return TheInput:IsControlPressed(keys) end
  local ret = {}
  if not keys then return ret end
  for k, v in pairs(keys) do ret[v] = TheInput:IsControlPressed(v) end
  return ret
end

-- One Of
function HasModKeys(keys, tbl)
  if not keys then return false end
  if type(keys) == "number" then keys = {keys} end
  if type(keys) ~= "table" then
    CONSOLE.err("HasModKeys: keys=", keys)
    return false
  end
  for k, v in pairs(keys) do
    if TheInput:IsControlPressed(v) then return true end
    if tbl and tbl[v] == 0 then return true end
  end
  return false
end

function AddClickHandler(self, fn, right)
  if not self then
    CONSOLE.err("AddClickHandler: self is nil")
    return
  end
  if not fn then
    CONSOLE.err("AddClickHandler: fn is nil")
    return
  end
  local old = self.OnMouseButton
  local btn = right and MOUSEBUTTON_RIGHT or MOUSEBUTTON_LEFT
  local new = function(inst, button, down, x, y)
    if down or btn ~= button then return end
    fn(inst, button, down, x, y)
  end
  self.OnMouseButton = MakeWrapper(old, new)
end

-- button=left|right|middle
function AddMouseHandler(_button, fn, _down)
  if _down == nil then _down = false end
  if not _button then
    CONSOLE.err("AddMouseHandler: Invalid button:", _button)
    _button = MOUSEBUTTON_LEFT
  end
  local is_dst = TheSim:GetGameID() == "DST"
  if is_dst then
    return TheInput:AddMouseButtonHandler(
             function(button, down, x, y, ...)
        if _down ~= down then return end
        if button ~= _button then return end
        if IsNotGameScreen() then return end
        fn(button, down, x, y, ...)
      end)
  else
    return TheInput:AddMouseButtonHandler(_button, _down, function()
      -- #FIXME
    end)
  end
end
function RemoveMouseHandler(handler)
  return TheInput.onmousebutton:RemoveHandler(handler)
end

local _keyhandlers = {}
local function _KeyHandler(key, down, ...)
  if IsNotGameScreen() then return end
  for i, v in ipairs(_keyhandlers[key][down]) do if v then v(...) end end
end
function AddKeyHandler(key, func, down)
  if not func then
    CONSOLE.err("AddKeyHandler: func is nil")
    return
  end
  if type(key) ~= "number" then
    CONSOLE.err("AddKeyHandler: key is not number")
    return
  end
  if _keyhandlers[key] == nil then
    _keyhandlers[key] = {{}, {}}
    _keyhandlers.down = TheInput:AddKeyDownHandler(key, function(...)
      return _KeyHandler(key, 1, ...)
    end)
    _keyhandlers.up = TheInput:AddKeyUpHandler(key, function(...)
      return _KeyHandler(key, 2, ...)
    end)
  end
  table.insert(_keyhandlers[key][down and 1 or 2], func)
end
function RemoveKeyHandler(key, func, down)
  if _keyhandlers[key] then
    table.removev(_keyhandlers[key][down and 1 or 2], func)
  end
end

function AddDirectKeyHandler(key, fn, down)
  local htype = "AddKeyDownHandler"
  if not down then htype = "AddKeyUpHandler" end
  return TheInput[htype](TheInput, key, fn)
end
function RemoveDirectKeyHandler(handler, down)
  TheInput[down and "onkeydown" or "onkeyup"]:RemoveHandler(handler)
end

function AddDirectMouseHandler(button, fn, down)
  return TheInput:AddMouseButtonHandler(function(_button, _down, x, y, ...)
    if _down ~= down then return end
    if button ~= _button then return end
    fn(button, down, x, y, ...)
  end)
end
RemoveDirectMouseHandler = RemoveMouseHandler
--[[
    mouse=0left|1right,
    type param=0start|1change|2stop
]]
function AddDragHandler(self, startfn, changefn, stopfn)
  if not self.pos then self.pos = self:GetPosition() end
  if not self.draghandlers then
    self.draghandlers = {start = {}, change = {}, stop = {}}
    local old = self.OnMouseButton
    local new = function(inst, button, down, x, y)
      if self.disabledrag then return end
      if down then
        self.dragging = true
        self.startpos = self.startpos or TheInput:GetScreenPosition()
        for i, v in ipairs(self.draghandlers.start) do
          v(inst, button, down, x, y, 0)
        end
      else
        self.dragging = false
        for i, v in ipairs(self.draghandlers.stop) do
          v(inst, button, down, x, y, 2)
        end
        self.pos = self:GetPosition()
        self.startpos = nil
      end
    end
    self.OnMouseButton = MakeWrapper(old, new)
    self.followhandler = TheInput:AddMoveHandler(function(x, y)
      if not self.dragging then return end
      if self.disabledrag then return end
      local pos = x
      if type(x) == "number" then pos = Vector3(x, y, 0) end
      self.dragpos = pos
      for i, v in ipairs(self.draghandlers.change) do v(self, pos, 1) end
    end)
  end
  if startfn then table.insert(self.draghandlers.start, startfn) end
  if changefn then table.insert(self.draghandlers.change, changefn) end
  if stopfn then table.insert(self.draghandlers.stop, stopfn) end
end

--[[
    onwheel(self,isForward)
    event:onwheel
    CONTROL_SCROLLFWD:
    31 true
    31 false
    CONTROL_SCROLLBACK:
    32 true
    32 false
    ]]
local appname = "_camera_zoom_blocked"
local keyname = "blockcamera"
local function PlayerControllerPostInit(PlayerController)
  if PlayerController[appname] then return end
  PlayerController[appname] = true
  local old = PlayerController.DoCameraControl
  function PlayerController:DoCameraControl(...)
    if not TheCamera:CanControl() then return false end
    if TheInput:IsControlPressed(CONTROL_ZOOM_IN) or
      TheInput:IsControlPressed(CONTROL_ZOOM_OUT) then
      local element = theinput.gethud()
      if element then
        if self.inst.HUD ~= nil then
          if not element.parent then
            element = element.widget or element
          end
          local maxdepth = 100
          while element and maxdepth > 0 do
            -- CONSOLE.log("check block zoom", element, element[keyname])
            if element[keyname] == true then
              return false
            elseif element[keyname] == false then
              return old(self, ...)
            end
            element = element.parent
            maxdepth = maxdepth - 1
          end
        end
      end
    end
    return old(self, ...)
  end
end
function HackCameraControl()
  if HasHUD() then
    if RegisterMod("CameraZoomBlock") then return end
    utils.com("playercontroller", PlayerControllerPostInit)
    postinitutils.com("playercontroller", PlayerControllerPostInit)
  end
end

function AddWheelHandler(self, onwheel)
  local old = self.OnControl
  local new = function(self, control, down)
    if down then
      local isForward = control == CONTROL_SCROLLFWD
      local isBackward = control == CONTROL_SCROLLBACK
      if isForward or isBackward then
        onwheel(self, isForward)
        return true
      end
    end
  end
  self.OnControl = MakeWrapper(old, new)
  HackCameraControl()
end

function AddHoverHandler(self, onenter, onleave)
  local oldenter = self.OnGainFocus
  local oldleave = self.OnLoseFocus
  self.OnGainFocus = MakeWrapper(oldenter, onenter)
  self.OnLoseFocus = MakeWrapper(oldleave, onleave)
end

-- Do not call this from multithread
-- if fn(node,depth) returns true, then WalkNode will not walk into its children
function WalkNode(node, fn, maxdepth, depth)
  if node._iswalking then return end
  if not node then return end
  if not maxdepth then maxdepth = 10 end
  if not depth then depth = 0 end
  if depth > maxdepth then return end
  if not fn then return end
  if not fn(node, nil, depth) then
    if type(node) == "table" then
      node._iswalking = true
      for k, v in pairs(node) do
        if type(v) == "table" then
          WalkNode(v, fn, maxdepth, depth + 1)
        else
          fn(k, v, depth)
        end
      end
      node._iswalking = nil
    end
  end
end

theinput = {
  gethud = function() return TheInput:GetHUDEntityUnderMouse() end,
  getworld = function() return TheInput:GetWorldEntityUnderMouse() end,
  getworldpos = function() return TheInput:GetWorldPosition() end,
  lookhud = function(w)
    w = w or theinput.gethud()
    if w.widget ~= nil then w = w.widget end
    local names = {}
    while w do
      table.insert(names, tostring(w))
      w = w.parent
    end
    return names
  end,
  printhud = function(w)
    local names = theinput.lookhud(w)
    CONSOLE.log(table.concat(names, ","))
    return names
  end,
  debugdumphud = function(w)
    w = w or theinput.gethud()
    if w.widget ~= nil then w = w.widget end
    local names = {}
    while w do
      local key = nil
      if w.parent then
        for k, v in pairs(w.parent) do
          if v == w then
            key = k
            break
          end
        end
        if not key then key = "[one of children]" end
      end
      table.insert(names, {w, key})
      w = w.parent
    end
    return names
  end,
  gethuddelay = function(name, delay)
    if not name then name = math.random(0, 100) end
    name = "a" .. tostring(name)
    stimer.tick(function()
      if theinput.getmouse() then rawset(GLOBAL, name, theinput.getmouse()) end
    end, delay or 0.1)
    return name
  end,
  getanim = function(w) return w:GetAnimState() end,
  dbg = function(inst) if inst then SetDebugEntity(inst) end end,
  getw = function(name)
    if not name then name = math.random(0, 100) end
    name = "w" .. tostring(name)
    timer.tick(function()
      if theinput.getmouse() then rawset(GLOBAL, name, theinput.getmouse()) end
    end, 1)
    return name
  end,
  -- output=the one that is hovered upon, nearby ones within 1 radius
  getmouse = function()
    local self = TheInput
    local hasMouse = self.mouse_enabled
    if not hasMouse then return end
    local all = self.entitiesundermouse or
                  TheSim:GetEntitiesAtScreenPoint(TheSim:GetPosition()) or {}
    local hover = self.hoverinst
    if hover and hover.entity:IsValid() and hover.entity:IsVisible() then
    else
      hover = nil
    end
    return hover, all
  end,
  getundermouse = function()
    local self = TheInput
    local hover = self.hoverinst or self.entitiesundermouse and
                    self.entitiesundermouse[1]
    if hover and hover.entity:IsValid() and hover.entity:IsVisible() then
    else
      hover = nil
    end
    return hover
  end,
  getroot = function(w)
    if w.entity then w = w.entity end
    while w:GetParent() do w = w:GetParent() end
    return w
  end
}
thescreen = {
  -- input=x,y[,z]
  -- output=true|false
  isValid = function(x, y, z)
    if z == false then return false end
    if type(x) == "table" then
      return x.x and (x.x ~= 0 or x.y ~= 0 or (x.z and x.z ~= 0))
    end
    return x and (x ~= 0 or y ~= 0 or (z and z ~= 0))
  end,
  canConvert = function(x, y, z)
    return type(x) == "number" and type(y) == "number" and
             (not z or type(z) == "number")
  end,
  -- input=nil
  -- output=minimap
  hasMap = function()
    if thescreen.minimap then return thescreen.minimap end
    thescreen.minimap = safefetch(_G, "TheWorld", "minimap", "MiniMap")
    return thescreen.minimap
  end,
  getScreenSize = function() return TheSim:GetScreenSize() end,
  -- input=nil
  -- output=x,y
  getmouse = function() return TheSim:GetPosition() end,
  -- input=vector
  -- output=x,y,z
  v2xyz = function(pos) return pos:Get() end,
  -- input=x,y,z
  -- output=vector
  xyz2v = function(x, y, z) return Vector3(x or 0, y or 0, z or 0) end,
  -- input=x,y,z
  -- output=x,y
  world2screen = function(x, y, z)
    if type(x) == "table" then x, y, z = thescreen.v2xyz(x) end
    if not thescreen.canConvert(x, y, z) then
      CONSOLE.err("Can't convert world position to screen:", x, y, z)
      return 0, 0, 0
    end
    return TheSim:GetScreenPos(x, y, z)
  end,
  -- input=x,y
  -- output=x,y,z|nil,nil,nil
  screen2world = function(x, y)
    if not thescreen.canConvert(x, y) then
      CONSOLE.err("Can't convert screen position to world:", x, y)
      return 0, 0, 0
    end
    return TheSim:ProjectScreenPos(x, y)
  end,
  -- input=entity|widget
  -- output=x,y
  getscreen = function(widget)
    if not widget then
      CONSOLE.err("widget is", widget)
      return 0, 0, false
    end
    local x, y, valid = 0, 0, true
    if widget.AnimState then
      x, y =
        TheSim:GetScreenPos(widget.AnimState:GetSymbolPosition("", 0, 0, 0))
      valid = true
    end
    if x == 0 and y == 0 and widget.Transform then
      x, y = TheSim:GetScreenPos(widget.Transform:GetWorldPosition())
      valid = true
    end
    if x == 0 and y == 0 and widget.GetPosition then
      x = widget:GetPosition()
      if type(x) == "number" then
        x, y = widget:GetPosition()
      elseif type(x) == "table" then
        x, y = widget:GetPosition():Get()
      else
        valid = false
      end
    end
    if x == 0 and y == 0 and widget.x then
      x, y = widget.x, widget.y
      valid = true
    end
    return x, y, valid
  end,
  getworld = function(widget)
    if not widget then
      CONSOLE.err("widget is", widget)
      return 0, 0, 0
    end
    local x, y, z = 0, 0, 0
    if widget.Transform then
      x, y, z = widget.Transform:GetWorldPosition()
    elseif widget.AnimState then
      x, y, z = widget.AnimState:GetSymbolPosition("", 0, 0, 0)
    elseif widget.GetPosition then
      x, y, z = widget:GetPosition():Get()
    elseif widget.x then
      x, y, z = widget.x, widget.y, widget.z
    end
    return x, y, z
  end,
  -- input=x,y
  -- output=x,y,z
  map2world = function(x, y)
    if not thescreen.canConvert(x, y) then
      CONSOLE.err("Can't convert map position to world:", x, y)
      return 0, 0, 0
    end
    if thescreen.hasMap() then
      return thescreen.minimap:MapPosToWorldPos(x, y, 0)
    end
    return 0, 0, 0
  end,
  -- input=x,y,z
  -- output=x,y
  world2map = function(x, y, z)
    if not thescreen.canConvert(x, y, z) then
      CONSOLE.err("Can't convert world position to map:", x, y, z)
      return 0, 0
    end
    if thescreen.hasMap() then
      return thescreen.minimap:WorldPosToMapPos(x, z, 0)
    end
    return 0, 0
  end,
  mouse2world = function() return thescreen.screen2world(thescreen.getmouse()) end,
  mouse2map = function() return thescreen.screen2map(thescreen.getmouse()) end,
  mouse2world2map = function()
    return thescreen.world2map(thescreen.mouse2world())
  end,
  mouse2map2world = function()
    return thescreen.map2world(thescreen.mouse2map())
  end,
  -- shorthand for mouse2world2map2screen
  mouse2screen = function()
    return thescreen.map2screen(thescreen.mouse2world2map())
  end,
  -- input=x,y
  -- output=x,y
  screen2map = function(x, y)
    local screen_width, screen_height = thescreen.getScreenSize()
    local map_x = x / screen_width * 2 - 1
    local map_y = y / screen_height * 2 - 1
    return map_x, map_y
  end,
  screen2map2world = function(x, y)
    return thescreen.map2world(thescreen.screen2map(x, y))
  end,
  -- input=x,y
  -- output=x,y
  map2screen = function(x, y)
    local screen_width, screen_height = thescreen.getScreenSize()
    local screen_x = (x + 1) * screen_width / 2
    local screen_y = (y + 1) * screen_height / 2
    return screen_x, screen_y
  end
}
thescreen.isvalid = thescreen.isValid
thescreen.IsValid = thescreen.isValid
function MovementPrediction(enable, toggle)
  if not ThePlayer then return end
  local pc = ThePlayer.components.playercontroller
  local current = toggle and (not Profile:GetMovementPredictionEnabled()) or
                    enable
  current = not not current
  if pc:CanLocomote() then
    pc.locomotor:Stop()
  else
    pc:RemoteStopWalking()
  end
  ThePlayer:EnableMovementPrediction(current)
  Profile:SetMovementPredictionEnabled(current)
end

theshard = {
  id = nil,
  _oldupdateworldstate = nil,
  _worldeventpusher = function(worldid, ready)
    if TheWorld then
      TheWorld:PushEvent(
        REMOTESHARDSTATE.READY == ready and "shardconnected" or
          "sharddisconnected", worldid)
    end
  end,
  _listeners = {},
  _listener = function(...)
    for i, v in ipairs(theshard._listeners) do
      -- world_id, state, tags, world_data
      v(...)
    end
  end,
  getid = function()
    if theshard.id == nil then theshard.id = TheShard:GetShardId() end
    return theshard.id
  end,
  getshard = function() return Shard_GetConnectedShards() end,
  getshardlist = function()
    local shards = theshard.getshard()
    return table.getkeys(shards)
  end,
  isavailable = function(id) return Shard_IsWorldAvailable(tostring(id)) end,
  isself = function(id) return id == theshard.getid() end,
  notself = function(id) return not theshard.isself(id) end,
  listen = function(fn)
    table.insert(theshard._listeners, fn)
    if not theshard._oldupdateworldstate then
      theshard._oldupdateworldstate = Shard_UpdateWorldState
      wrapperAfter(_G, "Shard_UpdateWorldState", theshard._listener)
    end
  end,
  unlisten = function(fn) table.removev(theshard._listeners, fn) end,
  createevent = function() theshard.listen(theshard._worldeventpusher) end
}

function GetContainersInsideInv(inv)
  local ctns = {}
  if not inv then return ctns end
  local c = inv.classified
  if not c then return ctns end
  for i, v in pairs(c:GetItems()) do
    local container = v.replica.container
    if container then table.insert(ctns, v) end
  end
  for i, v in pairs(c:GetEquips()) do
    local container = v.replica.container
    if container then table.insert(ctns, v) end
  end
  return ctns
end
function GetItemsIncludingThoseInsideContainersFromInv(inv)
  local ret = {}
  if not inv then return ret end
  local shallowitems = GetSelectedItemsFromInventory(inv, {})
  local containers = GetContainersInsideInv(inv)
  ConcatArrays(ret, shallowitems)
  for i, v in ipairs(containers) do
    local items = v.replica.container:GetItems()
    ConcatArrays(ret, items)
  end
  return ret
end
