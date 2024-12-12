-- @dependency apis.lua
---@class saver
_saver = {
  set = function(self, key, value)
    if type(key) == "table" then
      for k, v in pairs(key) do
        if self.data[k] ~= v then
          self.dirty = true
          self.data[k] = v
        end
      end
    else
      if self.data[key] ~= value then
        self.dirty = true
        self.data[key] = value
      end
    end
    self:chargesave()
  end,
  chargesave = function(self)
    if self.dirty and self.autosaving then
      -- make a charged save
      self.charge:activate(self.name, self.rechargetime,
                           function() self:save() end)
    end
  end,
  autosave = function(self, enable)
    enable = not not enable
    if not VerifyPlayer() then
      local function onactivate(_TheWorld, _ThePlayer)
        if ThePlayer == _ThePlayer then
          self:autosave(enable)
          RemoveEventListener(TheWorld, "playeractivated", onactivate)
        end
      end
      AddEventListener(safefetch(GLOBAL, "TheWorld"), "playeractivated",
                       onactivate)
    end
    if self.autosaving == enable then return end
    self.autosaving = not self.autosaving
    local customname = "autosavingapi"
    if VerifyPlayer() then
      local p = ThePlayer
      local playerevents = {"playerdeactivated", customname}
      FilterArray(playerevents, function(event)
        if enable then
          AddEventListener(p, event, self.chargesave, self)
        else
          RemoveEventListener(p, event, self.chargesave, self)
        end
      end)
    end
    local events = {
      "entercharacterselect", "playerdeactivated", customname,
      "master_autosaverupdate", "ms_save"
    }
    local w = safefetch(GLOBAL, "TheWorld")
    FilterArray(events, function(event)
      if enable then
        AddEventListener(w, event, function() self:chargesave() end)
      else
        RemoveEventListener(w, event, function() self:chargesave() end)
      end
    end)
    local hud_saving = safefetch(ThePlayer, "HUD", "controls", "saving")
    if enable and hud_saving then
      if not hud_saving[customname] then
        hud_saving[customname] = true
        local old_StartSave = hud_saving.StartSave
        hud_saving.StartSave = function(...)
          TheWorld:PushEvent(customname)
          old_StartSave(...)
        end
      end
    end
  end,
  get = function(self, key) return self.data[key] end,
  save = function(self, force)
    if self.dirty or force then
      local str = json.encode(self.data)
      TheSim:SetPersistentString(self.name, str)
      self.dirty = false
    end
  end,
  load = function(self, callback)
    if callback then self.callback = callback end
    TheSim:GetPersistentString(self.name, function(...) self:onload(...) end)
  end,
  onload = function(self, success, data)
    if success then
      local _data = type(data) == "table" and data or json.decode(data)
      if _data then
        self.data = _data
        if self.callback then self.callback(_data) end
        self.loaded = true
      end
    end
  end,
  exist = function(self, key, callback)
    -- callback(isExist)
    TheSim:CheckPersistentStringExists(key, callback)
  end,
  erase = function(self, key)
    self:exist(key, function(success)
      if success then TheSim:ErasePersistentString(key) end
    end)
  end
}
---@return saver
function MakeSaver(name)
  local s = {
    data = {},
    name = name or ("random-saver-" .. tostring(math.random())),
    dirty = false,
    autosaving = false,
    charge = MakeRecharge(),
    loaded = false,
    rechargetime = 5
  }
  setmetatable(s, {__index = _saver})
  return s
end

_cooldown = {
  remove = function(self, name)
    if self.name[name] then self.name[name] = false end
    if self.timer[name] then
      timer.clear(self.timer[name])
      self.timer[name] = nil
    end
  end,
  activate = function(self, name, callback, time, after)
    if not name then return end
    if self.name[name] then return false end
    self.name[name] = true
    if callback then self.cb[name] = {callback, not not after} end
    self.timer[name] = timer.tick(function()
      self:call(name, false)
      self:remove(name)
      self:call(name, true)
    end, time or 1)
    return true
  end,
  call = function(self, name, isAfter)
    if self.cb[name] and self.cb[name][2] == isAfter then self.cb[name][1]() end
  end,
  overridecb = function(self, name, callback, after)
    self.cb[name] = {callback, after}
  end,
  -- #TODO: make this param function well
  appendcb = function(self, name, callback, isAfter)
    if self.name[name] and self.cb[name] then
      self.cb[name] = {MakeWrapper(self.cb[name], callback), self.cb[name][2]}
    else
      self.cb[name] = {callback, isAfter}
    end
  end
}
function MakeCooldown()
  local c = {name = {}, timer = {}, cb = {}}
  setmetatable(c, {__index = _cooldown})
  return c
end

_recharge = {
  activate = function(self, name, time, callback)
    if self.name[name] == nil then self.name[name] = 0 end
    if callback then self.cb[name] = callback end
    self.name[name] = self.name[name] + 1
    timer.tick(self.oncharged, time or 1, self, name)
  end,
  oncharged = function(self, name)
    self.name[name] = self.name[name] - 1
    if self.name[name] == 0 then self:call(name) end
  end,
  call = function(self, name) if self.cb[name] then self.cb[name]() end end
}
function MakeRecharge()
  local r = {name = {}, timer = {}, cb = {}}
  setmetatable(r, {__index = _recharge})
  return r
end
_counter = {
  count = 0,
  delta = 1,
  interval = 1,
  task = nil,
  callback = {},
  increase = function(self)
    self.count = self.count + self.delta
    self:call()
  end,
  call = function(self)
    for i, v in pairs(self.callback) do v[1](v[2] and unpack(v[2])) end
  end,
  set = function(self, value, delta)
    self.count = value
    if delta ~= nil then self.delta = delta end
    self:call()
  end,
  get = function(self) return self.count end,
  start = function(self)
    if self.task then return end
    self.task = timer.loop(self.increase, self.interval, self)
  end,
  stop = function(self)
    if not self.task then return end
    timer.clear(self.task)
    self.task = nil
  end,
  register = function(self, fn, ...) table.insert(self.callback, {fn, {...}}) end,
  unregister = function(self, fn)
    for i, v in ipairs(self.callback) do
      if v == fn then
        table.remove(self.callback, i)
        break
      end
    end
  end
}
function MakeCounter(value, delta, interval)
  local c = setmetatable({}, {__index = _counter})
  c.set(c, value, delta)
  c.interval = interval
  return c
end
local _nonvolatilesaver = {
  identical = "nonvolatile-",
  separate = "#$$",
  generatetext = function(self, key, val)
    return self.identical .. self.name .. key .. self.separate .. val
  end,
  getkeyval = function(self, text)
    local pos1, pos2 = string.find(text, self.separate)
    if pos1 and pos2 then
      local key = string.sub(text, 1, pos1 - 1)
      local val = string.sub(text, pos2 + 1)
      return key, val
    end
    return nil, nil
  end,
  save = function(self, force)
    if self.dirty or force and TheWorld then
      local t = TheWorld.components.timer
      if t then
        self:clearolddata(t)
        -- method1 deprecated
        -- for k, v in pairs(self.data) do
        --    local idtext = self:generatetext(k, v)
        --    t:StartTimer(idtext, 1, true)
        -- end
      end
      -- method2
      t = TheWorld.components.uniqueprefabids
      if t then
        self:clearolddata_u(t)
        for k, v in pairs(self.data) do
          local idtext = self:generatetext(k, v)
          t:GetNextID(idtext)
        end
      end
    end
  end,
  clearolddata = function(self, timer)
    local idhead = self.identical .. self.name
    local length = string.len(idhead)
    local data = timer.timers
    if data then
      for k, v in pairs(data) do
        if string.sub(k, 1, length) == idhead then timer:StopTimer(k) end
      end
    end
  end,
  clearolddata_u = function(self, uniqueprefabids)
    local idhead = self.identical .. self.name
    local length = string.len(idhead)
    local data = uniqueprefabids.topprefabids
    if data then
      for k, v in pairs(data) do
        if string.sub(k, 1, length) == idhead then data[k] = nil end
      end
    end
  end,
  realload = function(self, data)
    if type(data) ~= "table" then return end
    local idhead = self.identical .. self.name
    local length = string.len(idhead)
    for k, v in pairs(data) do
      if string.sub(k, 1, length) == idhead then
        local key, val = self:getkeyval(string.sub(k, length + 1))
        if key and key ~= "" then self.data[key] = val end
      end
    end
  end,
  load = function(self, callback)
    if callback then self.callback = callback end
    if TheWorld then
      -- method1 timer
      local t = TheWorld.components.timer
      if t and t.timers then self:realload(t.timers) end
      -- method2 uniqueid
      t = TheWorld.components.uniqueprefabids
      if t then self:realload(t.topprefabids) end
      self:onload(true, self.data)
    end
  end
}
setmetatable(_nonvolatilesaver, {__index = _saver})
function MakeNonVolatileSaver(name)
  local s = {
    data = {},
    name = name or ("random-nonvolatile-saver-" .. tostring(math.random())),
    dirty = false,
    autosaving = false,
    loaded = false,
    charge = MakeRecharge(),
    rechargetime = 5
  }
  setmetatable(s, {__index = _nonvolatilesaver})
  return s
end

_BaseTask = {
  name = "",
  enabled = false,
  interval = 0,
  duration = 0,
  callback = {},
  steps = {},
  current = 0,
  length = 0,
  looped = false
}
function _BaseTask:call(event, delay)
  for i, v in ipairs(self.callback[event][delay and 2 or 1]) do v(self, event) end
  timer.delay(self.call, self, event, true)
end
function _BaseTask:listen(event, fn, delayed)
  if not self.callback[event] then self.callback[event] = {{}, {}} end
  table.insert(self.callback[event][delayed and 2 or 1], fn)
end
function _BaseTask:unlisten(event, fn)
  if self.callback[event] then
    table.removev(self.callback[event][1], fn)
    table.removev(self.callback[event][2], fn)
  end
end

function _BaseTask:start()
  if not self.enabled then
    self.enabled = true
    self:call("start")
    self:dotask()
  end
end
function _BaseTask:stop()
  if self.enabled then
    self.enabled = false
    self:killtask()
    self:call("stop")
  end
end
function _BaseTask:dotask()
  if self.enabled then
    self:call("dotask")
    self:nextstep()
  end
end
function _BaseTask:nextstep()
  self:call("nextstep")
  if self:ended() then return self:stop() end
  return self:walk()
end
function _BaseTask:killtask() self:call("killtask") end
function _BaseTask:ended()
  self:call("ended")
  return true
end
function _BaseTask:walk()
  self:call("walk")
  return true
end
_ActionTask = {jobthread = nil, jobs = {}, timeout = 100000, waiting = false}
setmetatable(_ActionTask, {__index = _BaseTask})
function _ActionTask:dotask()
  if not self.jobthread then
    self.jobthread = StartThread(self.dojob, self.jobid, self)
  end
end
function _ActionTask:time() return GetTime() end
function _ActionTask:time(t) return GetTime() - t > self.timeout end
function _ActionTask:sleep(x)
  self:call("sleep")
  return Sleep(x)
end
function _ActionTask:dojob()
  -- this is a thread
  local t = self:time()
  self:call("jobstart")
  while #self.jobs > self.current do
    if self:ended() then break end
    if self:timeout(t) then break end
    self:donexttask()
  end
  self:call("jobend")
end
