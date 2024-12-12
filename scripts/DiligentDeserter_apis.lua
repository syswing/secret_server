local version = "20240106"
-- get rid of any GLOBAL. prefix
local GLOBAL = _G or GLOBAL
local env = GLOBAL and GLOBAL.getfenv and GLOBAL.getfenv() or GLOBAL or {}
if env == GLOBAL then
  -- disable strict mode so that there is no crash
  if GLOBAL.getmetatable then
    GLOBAL.getmetatable(GLOBAL).__index = function(t, k)
      return GLOBAL.rawget(GLOBAL, k)
    end
  end
end
-- unpack hack for lua 5.1
local _unpack = unpack
local function unpack(t)
  local len = 0
  for k, v in pairs(t) do len = math.max(len, k) end
  return _unpack(t, 1, len)
end
safe_unpack = unpack
-- defined in utils.lua
if not table.has then table.has = table.contains end
if not table.removev then table.removev = RemoveByValue end
if not table.size then table.size = GetTableSize end
if not table.union then table.union = ArrayUnion end

if not table.mergeinto then
  table.mergeinto = function(table1, table2, copy, seen)
    seen = seen or {}
    if not table1 or not table2 then return end
    for key, value in pairs(table2) do
      if table1[key] == nil and copy then
        table1[key] = value
      else
        if type(value) == "table" then
          if type(table1[key]) ~= "table" then table1[key] = {} end
          if not seen[value] then
            seen[value] = true
            table.mergeinto(table1[key], value, copy, seen)
          end
        else
          table1[key] = value
        end
      end
    end
  end
end
if not table.shallowmergeinto then
  table.shallowmergeinto = function(table1, table2)
    if not table1 or not table2 then return end
    for key, value in pairs(table2) do table1[key] = value end
  end
end
local function GetKeyString(key)
  local keyType = type(key)
  if keyType == "table" or keyType == "function" then
    return tostring(key)
  elseif keyType == "userdata" then
    return "[c]" .. tostring(key)
  else
    return tostring(key)
  end
end

local function GetTableString(t, current_depth, max_depth, indent,
                              last_indent_string, blacklist)
  if not last_indent_string then last_indent_string = "" end
  local tail = last_indent_string
  for i = 1, indent do last_indent_string = last_indent_string .. "\t" end
  local head = "{\n"
  local str = ""
  if type(t) ~= "table" then return GetKeyString(t) end
  if current_depth >= max_depth then return "{...}" end
  str = ""
  for k, v in pairs(t) do
    if blacklist and table.has(blacklist, k) then
    elseif type(v) == "table" then
      str = str .. last_indent_string .. GetKeyString(k) .. "=" ..
              GetTableString(v, current_depth + 1, max_depth, indent,
                             last_indent_string, blacklist) .. "\n"
    else
      str = str .. last_indent_string .. GetKeyString(k) .. "=" ..
              GetKeyString(v) .. "\n"
    end
  end
  if str == "" then return "{}" end
  return head .. str .. tail .. "}"
end

if not table.tostring then
  table.tostring = function(t, indent, maxdepth, blacklist, maxlength)
    if not indent then indent = 0 end
    if not maxdepth then maxdepth = 1 end
    if not maxlength then maxlength = 4000 end
    local ret = GetTableString(t, 0, maxdepth, indent, "", blacklist)
    if string.len(ret) >= maxlength then ret = string.sub(1, maxlength) end
    return ret
  end
end
function safeset(obj, key, val)
  if obj == GLOBAL then
    rawset(GLOBAL, key, val)
  elseif obj ~= nil then
    obj[key] = val
  end
end

function safeget(obj, key, val)
  local res = nil
  -- use rawget on GLOBAL
  if obj == GLOBAL then
    res = rawget(obj, key)
    if val ~= nil and type(obj) == "table" and res == nil and key ~= nil then
      rawset(obj, key, val)
      res = obj[key]
    end
  elseif obj ~= nil then
    res = obj[key]
    if res == nil then res = rawget(obj, key) end
    if val ~= nil and res == nil and key ~= nil then
      -- rawset(obj, key, val)
      obj[key] = val
      res = obj[key]
    end
  end
  return res
end

function safefetch(obj, key, ...)
  if not key then return obj end
  local res = nil
  -- use rawget on GLOBAL
  if obj == GLOBAL then
    res = rawget(obj, key)
  elseif obj ~= nil then
    res = obj[key]
  end
  return safefetch(res, ...)
end

function undotted(text) return unpack(string.split(text, ".")) end

gettime = {
  real = function() return TheSim:GetRealTime() end,
  pertick = TheSim and TheSim:GetTickTime() or 1,
  tick = function() return TheSim:GetTick() end,
  time = function() return gettime.tick() * gettime.pertick end,
  timetable = function(time)
    local t = time or gettime.time()
    return {
      second = t % 60,
      minute = math.floor(t / 60) % 60,
      hour = math.floor(t / 3600) % 24
    }
  end,
  formatted = function(timetable, fmt)
    if not timetable then timetable = gettime.timetable() end
    return string.format(fmt or "[%02d:%02d:%02d]", timetable.hour,
                         timetable.minute, timetable.second)
  end,
  clock = os.clock,
  realtime = os.time
}
RegisteredMods = safeget(GLOBAL, "RegisteredMods", {})
RegisteredEntry = safeget(GLOBAL, "RegisteredEntry", {})
-- support 2 levels
function RegisterMod(name, modulename)
  if not RegisteredMods[name] then
    if modulename then
      RegisteredMods[name] = {modulename = true}
    else
      RegisteredMods[name] = true
    end
    return false
  end
  if not modulename then return true end
  if type(RegisteredMods[name]) == "boolean" then RegisteredMods[name] = {} end
  if not RegisteredMods[name][modulename] then
    RegisteredMods[name][modulename] = true
    return false
  end
  return true
end

function RegisterEntry(name, tblorfn)
  if type(tblorfn) ~= "function" and type(tblorfn) ~= "table" then
    CONSOLE.err("RegisterEntry: entry is", tblorfn, "with name", name)
  end
  if RegisteredEntry[name] then
    CONSOLE.err("Duplicate Entry for mod", name)
    return
  end
  RegisteredEntry[name] = tblorfn
end

function GetKleiId()
  -- KU_xxxxxxxx
  return TheNet:GetUserID()
end

modutils = {
  workshopprefix = "workshop-",
  isworkshop = function(name) return name:find(modutils.workshopprefix) end,
  translate = function(name)
    if type(name) == "table" then
      local ret = {}
      for k, v in pairs(name) do ret[k] = modutils.translate(v) end
      return ret
    end
    local anothername = modutils.workshopprefix .. name
    if modutils.isworkshop(name) then
      anothername = string.sub(name, string.len(modutils.workshopprefix))
    end
    return anothername
  end,
  subscribe = function(name) return TheSim:SubscribeToMod(name) end,
  has = function(name)
    return KnownModIndex:GetModInfo(name) or
             KnownModIndex:GetModInfo(modutils.translate(name))
  end,
  hasnames = function(name)
    local actualname = name
    for i, v in ipairs(name) do
      local actual = KnownModIndex:GetModActualName(v)
      if actual then
        actualname = actual
        break
      end
    end
    return modutils.has(actualname)
  end,
  enabled = function(name)
    return KnownModIndex:IsModEnabledAny(name) or
             KnownModIndex:IsModEnabledAny(modutils.translate(name))
  end
}
modutils.exists = modutils.has
local isworkshop = nil
function GetIsWorkshop()
  if isworkshop ~= nil then return isworkshop end
  local folder_name = MODROOT or folder_name or ""
  isworkshop = not not folder_name:find(modutils.workshopprefix)
  return isworkshop
end

function GetIsWegame()
  return not not (PLATFORM and type(PLATFORM) == "string" and
           string.gmatch(PLATFORM, "RAIL"))
end

-- console function
debugfile = nil
CONSOLE = {
  tag = function(type) return "[" .. type .. "]" end,
  prt = function(...)
    if CONSOLE.dumpping then CONSOLE.dump(...) end
    local str = catstring(...)
    if str:len() > 4000 then str = str:sub(1, 4000) end
    print(str)
    return CONSOLE
  end,
  log = function(...)
    CONSOLE.prt(CONSOLE.tag("log"), ...)
    return CONSOLE
  end,
  err = function(...)
    CONSOLE.prt(CONSOLE.tag("error"), ...)
    -- force print traceback information
    CONSOLE.trace(nil, 3)
    return CONSOLE
  end,
  warn = function(...)
    CONSOLE.prt(CONSOLE.tag("warning"), ...)
    return CONSOLE
  end,
  info = function(...)
    CONSOLE.prt(CONSOLE.tag("info"), ...)
    return CONSOLE
  end,
  tagged = function(tag, ...)
    CONSOLE.prt(CONSOLE.tag(tag), ...)
    return CONSOLE
  end,
  make = function(tag)
    return function(...)
      CONSOLE.tagged(tag, ...)
      return CONSOLE
    end
  end,
  mute = function(...)
    if CONSOLE.dumpping then CONSOLE.dump(...) end
    return CONSOLE
  end,
  enabledump = function(enable)
    if enable and not debugfile then
      debugfile = MakeFile(MODROOT .. "debug.txt")
      debugfile.lastdumped = -100
      debugfile.data = debugfile:read()
      debugfile:close()
      debugfile:open(MODROOT .. "debug.txt", "w")
      debugfile:write(debugfile.data)
    end
    CONSOLE.dumpping = not not enable
  end,
  cleardump = function()
    if not debugfile then debugfile = MakeFile(MODROOT .. "debug.txt") end
    debugfile:write("")
    debugfile:close()
  end,
  void = function() end,
  disableprint = function()
    CONSOLE.log = CONSOLE.void
    CONSOLE.info = CONSOLE.void
    CONSOLE.warn = CONSOLE.void
    CONSOLE.msg = CONSOLE.void
  end,
  line = function(...)
    local info = debug.getinfo(2, 'nl')
    CONSOLE.print(info.name or "(anonymous)", "@", info.currentline, ...)
    return CONSOLE
  end
}
CONSOLE.error = CONSOLE.err
CONSOLE.print = CONSOLE.prt
CONSOLE.msg = CONSOLE.info
-- timer, in javascript style
if not staticScheduler then rawset(GLOBAL, "staticScheduler", scheduler) end
function SetTimeout(fn, t, ...)
  if t == nil then t = 0.02 end
  local id = math.random()
  return scheduler:ExecutePeriodic(t, fn, 1, t, id, ...)
end

function StaticSetTimeout(fn, t, ...)
  if t == nil then t = 0.02 end
  local id = math.random()
  return staticScheduler:ExecutePeriodic(t, fn, 1, t, id, ...)
end

function SetInterval(fn, t, ...)
  return FullSetInterval(fn, t, nil, nil, nil, ...)
end

function StaticSetInterval(fn, t, ...)
  return FullStaticSetInterval(fn, t, nil, nil, nil, ...)
end

function FullSetInterval(fn, t, limit, delay, _id, ...)
  if t == nil then t = 100 end
  local id = _id or math.random()
  return scheduler:ExecutePeriodic(t, fn, limit, delay or 0, id, ...)
end

function FullStaticSetInterval(fn, t, limit, delay, _id, ...)
  if t == nil then t = 100 end
  local id = _id or math.random()
  return staticScheduler:ExecutePeriodic(t, fn, limit, delay or 0, id, ...)
end

function SetInstTimeout(inst, fn, t, ...)
  if t == nil then t = 0.02 end
  return inst:DoTaskInTime(t, fn, ...)
end

function SetInstInterval(inst, fn, t, ...)
  if t == nil then t = 100 end
  return inst:DoPeriodicTask(t, fn, ...)
end

function CreateDelay(fn, t) return function(...) timer.tick(fn, t, ...) end end

function ClearTask(task) return task:Cancel() end

-- shorthand
timer = {
  tick = SetTimeout,
  loop = SetInterval,
  itick = SetInstTimeout,
  iloop = SetInstInterval,
  clear = ClearTask,
  delay = SetTimeout,
  idelay = SetInstTimeout,
  delayed = CreateDelay
}
stimer = {tick = StaticSetTimeout, loop = StaticSetInterval}

-- server/client detection
function IsServer() return TheNet:GetIsServer() end

function IsClient() return TheNet:GetIsClient() end

function IsDedicated() return TheNet:IsDedicated() end

function IsMain() return not IsDedicated() and IsServer() end

function HasHUD() return not IsDedicated() end

function IsInGame() return IsServer() or IsClient() end

local memoizedFilePaths = nil
if not resolvefilepath_soft then
  resolvefilepath_soft = function(filepath)
    if not memoizedFilePaths then
      _1, memoizedFilePaths, _3 = UPVALUE.get(resolvefilepath,
                                              "memoizedFilePaths")
      if not memoizedFilePaths then return nil end
    end
    if memoizedFilePaths[filepath] then return memoizedFilePaths[filepath] end
    local path = softresolvefilepath(filepath)
    if path then memoizedFilePaths[filepath] = path end
    return path
  end
  rawset(GLOBAL, "resolvefilepath_soft", resolvefilepath_soft)
end
-- this one determines if world is loaded
IsReallyInGame = InGamePlay

-- check if the world is different from the Constant.
function specialGameModeDetector()
  local gameMode = TheNet:GetServerGameMode()
  return gameMode == "lavaarena" and "forge" or gameMode == "quagmire" and
           "gorge" or "normal"
end

function GetConfig(key, isClient, modname)
  -- remove annoying ch
  local ret = {}
  if type(key) == "table" then
    FilterArray(key, function(k) ret[k] = GetModConfigData(k, isClient) end)
    return ret
  end
  ret = GetModConfigData(key, isClient)
  if key == "language" and ret == "ch" then ret = "zh" end
  return ret
end

function GetClientConfig(key) return GetConfig(key, true) end

function MakeAsset(assettype, name, folder, format)
  assettype = string.upper(assettype)
  if not folder then
    folder = ""
    if assettype == "IMAGE" or assettype == "ATLAS" or assettype ==
      "ATLAS_BUILD" or assettype == "DYNAMIC_ATLAS" then
      folder = "images"
    elseif assettype == "MINIMAP_IMAGE" then
    elseif assettype == "PKGREF" or assettype == "DYNAMIC_ANIM" or assettype ==
      "DYNAMIC_ATLAS" then
      folder = "anim/dynamic"
    elseif assettype == "SOUND" or assettype == "SOUNDPACKAGE" or assettype ==
      "FILE" then
      folder = "sound"
    elseif assettype == "ANIM" then
      folder = "anim"
    elseif assettype == "SCRIPT" then
      folder = "scripts"
    elseif assettype == "SHADER" then
      folder = "shaders"
    end
  end
  if folder ~= "" and string.sub(folder, -1) ~= "/" then folder = folder .. "/" end
  if not format then
    format = nil
    if assettype == "SOUND" then
      format = "fsb"
    elseif assettype == "SOUNDPACKAGE" or assettype == "FILE" then
      format = "fev"
    elseif assettype == "ANIM" or assettype == "DYNAMIC_ANIM" then
      format = "zip"
    elseif assettype == "IMAGE" then
      format = "tex"
    elseif assettype == "MINIMAP_IMAGE" then
    elseif assettype == "ATLAS" or assettype == "DYNAMIC_ATLAS" or assettype ==
      "ATLAS_BUILD" then
      format = "xml"
    elseif assettype == "PKGREF" then
      format = "dyn"
    elseif assettype == "SCRIPT" then
      format = "lua"
    elseif assettype == "SHADER" then
      format = "ksh"
    end
  end
  if format then
    if string.sub(name, -string.len(format) - 1) ~= "." .. format then
      name = name .. "." .. format
    end
  end
  return Asset(assettype, folder .. name,
               assettype == "ATLAS_BUILD" and 256 or nil)
end

function MakeAssetTable(tbl)
  return MapDict(tbl, function(k, v) return MakeAsset(unpack(v)) end)
end

function AddPrefab(prefab)
  if not PrefabFiles then PrefabFiles = {} end
  table.insert(PrefabFiles, prefab)
end

function AddPrefabs(prefabs)
  if not PrefabFiles then PrefabFiles = {} end
  for i, v in ipairs(prefabs) do table.insert(PrefabFiles, v) end
end

-- RemapSoundEvent Function
function ReSound(original, replacement) RemapSoundEvent(original, replacement) end

-- modutils, some of them
utils = {
  prefab = AddPrefabPostInit,
  prefabs = function(prefabs, fn)
    for i, v in ipairs(prefabs) do AddPrefabPostInit(v, fn) end
  end,
  -- player = AddPlayerPostInit,
  -- from global positions mod
  _playerinits = {},
  _playeroninit = function(world, inst)
    if not inst then inst = world end
    for i, v in ipairs(utils._playerinits) do v[1](inst, unpack(v[2])) end
  end,
  player = function(fn, ...)
    if not fn then return end
    local args = {fn, {...}}
    table.insert(utils._playerinits, args)
    if #utils._playerinits == 1 then
      if IsClient() then
        AddPlayerPostInit(utils._playeroninit)
      else
        AddPrefabPostInit("world", function(inst)
          inst:ListenForEvent("ms_playerspawn", utils._playeroninit)
        end)
      end
    end
  end,
  theplayer = function(fn, ...)
    if not fn then return end
    local param = {...}
    utils.player(function(p)
      if not ThePlayer then
        p:ListenForEvent("playeractivated", function()
          if p == ThePlayer then fn(p, unpack(param)) end
        end)
        return
      end
      if p == ThePlayer then fn(p, unpack(param)) end
    end)
    if ThePlayer then fn(ThePlayer) end
  end,
  player_raw = AddPlayerPostInit,
  -- these two are very similar, just sim is before world post init
  -- if you want it client/server, use sim. if server only, use game.
  sim = AddSimPostInit,
  -- server only
  game = AddGamePostInit,
  class = AddClassPostConstruct,
  sghandler = AddStategraphActionHandler,
  sgstate = AddStategraphState,
  sgevent = AddStategraphEvent,
  sg = AddStategraphPostInit,
  com = AddComponentPostInit,
  comreplica = AddReplicableComponent,
  comclass = function(name, fn)
    AddClassPostConstruct("components/" .. name, fn)
  end,
  minimap = AddMinimapAtlas,
  prefabany = AddPrefabPostInitAny,
  recipeany = AddRecipePostInitAny,
  recipe = AddRecipePostInit,
  brain = AddBrainPostInit,
  resound = RemapSoundEvent,
  mod = function(mods, submods)
    if submods ~= nil then
      for i, v in pairs(submods) do utils.mod(mods .. v) end
      return
    end
    if type(mods) == "string" then mods = {mods} end
    for _, mod in ipairs(mods) do utils.onemod(mod) end
  end,
  onemod = function(name)
    local s = softresolvefilepath
    local realpath = s(name)
    local name2 = string.find(name, "scripts") and name or "scripts/" .. name
    realpath = realpath or s(MODROOT .. name2) or s(name2)
    local name3 = string.find(name2, "lua") and name2 or name2 .. ".lua"
    realpath = realpath or s(MODROOT .. name3) or s(name3)
    local name4 = string.find(name, "lua") and name or name .. ".lua"
    realpath = realpath or s(MODROOT .. name4) or s(name4)
    if realpath then
      return utils.loadmod(realpath)
    else
      print("Cannot not find " .. name)
      return nil
    end
  end,
  loadmod = function(path)
    local result = utils.load(path)
    if type(result) == "function" then
      print("loaded " .. path)
      setfenv(result, env)
      local rets = {pcall(result)}
      local success = rets[1]
      if not success then
        print("error running " .. path)
        print(unpack(rets))
        return nil
      else
        table.remove(rets, 1)
        return unpack(rets)
      end
    else
      print("error loading " .. path, result)
      return nil
    end
  end,
  up = function(environment, path, fn, genv)
    local nodes = {}
    if type(path) == "table" then
      nodes = path
    elseif type(path) == "string" then
      nodes = undotted(path)
    end
    local a, b, c = UPVALUE.fetch(environment, unpack(nodes))
    if a and b then
      UPVALUE.inject(a, c, fn, genv or getfenv(2) or env or GLOBAL)
    else
      CONSOLE.err("utils.up error: upvalue not found.", environment,
                  table.tostring(nodes), fn, genv)
    end
  end,
  prefabup = function(prefab, path, fn, genv)
    utils.sim(function()
      if GLOBAL.Prefabs and GLOBAL.Prefabs[prefab] then
        utils.up(GLOBAL.Prefabs[prefab].fn, path, fn, genv)
      else
        CONSOLE.err("utils.prefabup error: no such prefab as", prefab)
      end
    end)
  end,
  require = function(path, fn)
    if kleifileexists(table.concat({"scripts/", path, ".lua"}, "")) then
      if fn then
        return fn(require(path))
      else
        return require(path)
      end
    end
    return nil
  end,
  -- safe class
  klass = function(path, fn)
    if kleifileexists(table.concat({"scripts/", path, ".lua"}, "")) then
      if fn then
        return utils.class(path, fn)
      else
        return require(path)
      end
    end
  end,
  load = function(name)
    -- return dofile(name)
    return kleiloadlua(name)
  end,
  -- no cache
  rerequire = function(path)
    package.loaded[path] = nil
    return require(path)
  end,
  addrecipes = function(def, nomod)
    for name, data in pairs(def) do
      local ing = {}
      if not nomod then table.insert(def.filter, "MODS") end
      for i, v in pairs(data.ingredient) do
        table.insert(ing, Ingredient(i, v))
      end
      AddRecipe2(name, ing, def.tech, def.config, def.filter)
    end
  end
}
postinitutils = {
  prefab = function(name, fn)
    MapDict(GLOBAL.Ents, function(_, inst)
      if VerifyInst(inst) then if inst.prefab == name then fn(inst) end end
    end)
  end,
  tag = function(name, fn)
    MapDict(GLOBAL.Ents, function(_, inst)
      if VerifyInst(inst) then if inst:HasTag(name) then fn(inst) end end
    end)
  end,
  tags = function(names, fn)
    MapDict(GLOBAL.Ents, function(_, inst)
      if VerifyInst(inst) then if inst:HasTags(names) then fn(inst) end end
    end)
  end,
  theplayer = function(fn) if VerifyPlayer() then fn(ThePlayer) end end,
  com = function(name, fn)
    MapDict(GLOBAL.Ents, function(_, inst)
      if VerifyInst(inst) then
        if inst.components[name] then fn(inst.components[name]) end
      end
    end)
  end
}
-- create color for settint
function rgba(r, g, b, a) return r / 255, g / 255, b / 255, a end

-- create a userdata
_userdata = {}
local metauserdata = {
  __call = function(_, linked)
    local u = newproxy(true)
    if linked then
      local metatable = getmetatable(u)
      metatable.__index = linked
      metatable.__newindex = function(_, k, v) linked[k] = v end
    end
    return u
  end
}
setmetatable(_userdata, metauserdata)

function wrapper(inst, name, fn)
  local oldfn = inst[name]
  if not oldfn then
    CONSOLE.warn(inst, name, "doesn't have an old fn to wrap.")
    inst[name] = fn
    return
  end
  inst[name] = function(...)
    fn(...)
    return oldfn(...)
  end
end

function wrapperAfter(inst, name, fn)
  local oldfn = inst[name]
  if not oldfn then
    CONSOLE.warn(inst, name, "doesn't have an old fn to wrap after.")
    inst[name] = fn
    return
  end
  inst[name] = function(...)
    local ret = {oldfn(...)}
    fn(...)
    return unpack(ret)
  end
end

function wrapperSubstitute(inst, name, fn)
  local oldfn = inst[name]
  if not oldfn then
    CONSOLE.warn(inst, name, "doesn't have an old fn to wrap substitute.")
    inst[name] = fn
    return
  end
  inst[name] = function(...)
    local args = {...}
    local res = {oldfn(...)}
    return fn(args, res)
  end
end

function MakeWrapper(oldfn, fn)
  if not oldfn then return fn end
  return function(...)
    fn(...)
    return oldfn(...)
  end
end

function MakeWrapperAfter(oldfn, fn)
  if not oldfn then return fn end
  return function(...)
    local ret = {oldfn(...)}
    fn(...)
    return unpack(ret)
  end
end

function MakeWrapperSubstitute(oldfn, fn)
  if not oldfn then return function(...) return fn({...}, {}) end end
  return function(...)
    local args = {...}
    local res = {oldfn(...)}
    return fn(args, res)
  end
end

function exposeToGlobal(name, fn, override, force)
  assert((override ~= nil and force ~= nil) or
           (override == nil and force == nil),
         "better not use exposeToGlobal with params")
  if not force and GetIsWorkshop() then return end
  -- will fail because not declared
  if safefetch(GLOBAL, name) ~= nil and not override then
    -- CONSOLE.err(CONSOLE.tag("exposeToConsole"), name, "already exists on GLOBAL scope")
    return
  end
  if type(name) == "table" then
    for i, v in pairs(name) do GLOBAL.rawset(GLOBAL, i, v) end
  else
    GLOBAL.rawset(GLOBAL, name, fn)
  end
end

function expose(name, val, override, single)
  if type(name) == "table" and not single then
    for i, v in pairs(name) do expose(i, v, val, true) end
  else
    if not override then if GLOBAL.rawget(GLOBAL, name) then return end end
    return GLOBAL.rawset(GLOBAL, name, val)
  end
end

-- get language
-- there are many waisser to get language
function GetLanguageCode()
  local loc = env.locale or safefetch(LOC, "CurrentLocale", "code") or
                LanguageTranslator.defaultlang or ""
  local traditional = loc == "zht"
  -- replace wegame suffix
  if loc == "zhr" then loc = "zh" end
  return loc, traditional
end

local language = {
  en = "english",
  es = "spanish",
  ru = "russian",
  fr = "french",
  de = "german",
  it = "italian",
  ja = "japanese",
  ko = "korean",
  pt = "portuguese",
  pl = "polish",
  zh = "chinese"
}
language.zhr = language.zh
language.zht = language.zh
function GetLanguageName()
  local lang = GetLanguageCode()
  local traditional = lang == "zht"
  lang = language[lang] or lang
  return lang, traditional
end

function GetValue(obj, key)
  local up = 1
  local name, value = nil, nil
  while true do
    name, value = debug.getupvalue(obj, up)
    if not name then
      break
    elseif name == key then
      break
    else
      up = up + 1
    end
  end
  return name, value, up
end

function GetAllValue(obj)
  local up = 1
  local name, value = nil, nil
  local ret = {}
  while true do
    name, value = debug.getupvalue(obj, up)
    if not name then
      break
    else
      ret[name] = {value = value, up = up}
      up = up + 1
    end
  end
  return ret
end

function GetValueRecursive(obj, key, depth)
  local MAXDEPTH = 10
  if type(depth) ~= "number" then depth = 1 end
  if depth > MAXDEPTH then
    CONSOLE.err("GetValueRecursive: reached max depth", obj, key, depth)
    return nil, nil, nil
  end
  -- print("[get]", obj, key)
  local up = 1
  local name, value = nil, nil
  local temp_name, temp_value, temp_up = nil, nil, nil
  local ret = nil
  while true do
    name, value = debug.getupvalue(obj, up)
    -- print("[upvalue]", name, value, up)
    if name == nil then
      break
    elseif name == key then
      ret = value
      break
    elseif type(value) == "function" then
      temp_name, temp_value, temp_up = GetValueRecursive(value, key, depth + 1)
      if temp_value then
        obj = temp_name
        ret = temp_value
        up = temp_up
        break
      end
    end
    up = up + 1
  end
  return obj, ret, up
end

function GetLocalValueRecursive(key)
  local level = 3
  local maxlevel = 10
  local flag = true
  local index = 1
  while level <= maxlevel and flag do
    local name, value = debug.getlocal(level, index)
    if name == nil then
      if index == 1 then break end
      level = level + 1
      index = 1
    elseif name == key then
      return level, index, value
    else
      index = index + 1
    end
  end
  return nil, nil, nil
end

function GetValueSuccessive(obj, ...)
  local names = {...}
  if #names == 0 then return nil, nil, nil end
  local up = 1
  local name, value = nil, obj
  for _, key in ipairs(names) do
    if type(value) ~= "function" then
      CONSOLE.err("Upvalue", obj, key, "terminated before", key)
    end
    obj = value
    name, value, up = GetValue(value, key)
    -- print("[upvalue]", name, value, up)
    if not name then
      CONSOLE.err("Upvalue", key, "not found in", obj)
      return nil, nil, nil
    end
  end
  return obj, value, up
end

function MakeUpvalueEnv(fn, globalenv, localenv)
  if not globalenv then globalenv = env end
  if not localenv then localenv = fn end
  local ret = {env = globalenv}
  local metaret = {values = {}}
  metaret.__index = function(_, k)
    if metaret.values[k] == nil then
      local a, b, c = UPVALUE.get(localenv, k)
      if a and c then
        metaret.values[k] = {a, b, c}
      else
        metaret.values[k] = {}
      end
    end
    if metaret.values[k][1] ~= nil then return metaret.values[k][2] end
    return globalenv[k]
  end
  metaret.__newindex = function(_, k, v)
    if metaret.values[k] == nil then metaret:__index(k) end
    local info = metaret.values[k]
    if info[1] ~= nil then
      UPVALUE.set(info[1], info[3], v)
      metaret.value[k][2] = v
    else
      rawset(globalenv, k, v)
    end
  end
  setmetatable(ret, metaret)
  setfenv(fn, ret)
  return fn
end

-- end at nil, safe
function packstring(...)
  local n = select("#", ...)
  n = math.min(n, 10)
  local args = {...}
  local function safepack(args, n)
    local str = ""
    for i = 1, n do str = str .. tostring(args[i]) .. " " end
    return str
  end

  local success, str = pcall(safepack, args, n)
  if success and str then return str:sub(1, 4000) end
  print("error in packstring")
  return ""
end

-- concat all
function catstring(...)
  local args = {...}
  local strs = {}
  for k, v in pairs(args) do
    if v ~= nil then table.insert(strs, tostring(v)) end
  end
  return table.concat(strs, "")
end

UPVALUE = {
  get = function(obj, key)
    if type(obj) == "string" then obj = safeget(GLOBAL, obj) end
    if type(obj) ~= "function" then
      CONSOLE.err("UPVALUE.get:", obj, "is not a function")
      return nil, nil, nil
    end
    local upperfn, value, up = GetValueRecursive(obj, key)
    if value then
      return upperfn, value, up
    else
      CONSOLE.err(CONSOLE.tag("UPVALUE"), "key", key, "not found in", obj)
      return nil, nil, nil
    end
  end,
  fetch = function(obj, ...)
    if type(obj) == "string" then obj = safeget(GLOBAL, obj) end
    if type(obj) ~= "function" then
      CONSOLE.err("UPVALUE.fetch:", obj, "is not a function")
      return nil, nil, nil
    end
    local upperfn, value, up = GetValueSuccessive(obj, ...)
    if value then
      return upperfn, value, up
    else
      local keisser = {...}
      CONSOLE.err(CONSOLE.tag("UPVALUE"), "key", keisser[1], "not found",
                  packstring(obj, ...))
      return nil, nil, nil
    end
  end,
  set = function(fn, up, value)
    if type(fn) ~= "function" then
      CONSOLE.err(CONSOLE.tag("UPVALUE"), "value", value, "is not a function")
    end
    debug.setupvalue(fn, up, value)
  end,
  inject = function(fn, up, value, globalenv)
    if type(value) == "function" or type(value) == "table" then
      MakeUpvalueEnv(value, globalenv or env, fn)
    end
    debug.setupvalue(fn, up, value)
  end
}
--[[
    wtype:before|after|substitute|override
]]
function UpvalueWrapper(obj, key, newfn, wtype)
  local upperfn, oldfn, up = nil, nil, nil
  if type(key) == "string" then
    upperfn, oldfn, up = UPVALUE.get(obj, key)
  elseif type(key) == "table" and #key > 0 and type(key[1]) == "string" then
    upperfn, oldfn, up = UPVALUE.fetch(obj, unpack(key))
  end
  if not upperfn then return end
  if not wtype then wtype = "override" end
  if wtype == "before" then
    UPVALUE.set(upperfn, up, MakeWrapper(oldfn, newfn))
  elseif wtype == "after" then
    UPVALUE.set(upperfn, up, MakeWrapperAfter(oldfn, newfn))
  elseif wtype == "substitute" then
    UPVALUE.set(upperfn, up, MakeWrapperSubstitute(oldfn, newfn))
  elseif wtype == "override" then
    UPVALUE.set(upperfn, up, newfn)
  else
    CONSOLE.err(CONSOLE.tag("UPVALUE"), "wtype", wtype, "not supported")
  end
end

--[[
    level=0 debug.getinfo
          1 DBGPRINT
          2 the function that calls DBGPRINT, we begin at here
          3 stack[-1]
          ...
    fnname: you lose it via load/loadstring/pcall/xpcall and other C level functions because debug library doesn't try to get the symbol further than its current env
]]
function DBGPRINT(levelorfunction, ...)
  local level = levelorfunction
  local lua, c = "Lua", "C"
  local info = debug.getinfo(1)
  local cur = 2
  if type(levelorfunction) == "function" then
  else
    if (type(level) ~= "number") then level = tonumber(level) end
    if not level then
      level = 2
    elseif level < 2 then
      level = 2
    end
    repeat
      info = debug.getinfo(cur)
      local type = info.what
      if type ~= lua then cur = level + 2 end
      cur = cur + 1
    until cur >= level
    if cur ~= level then return end
  end
  local ismod = "../mods/"
  info = debug.getinfo(level)
  local defaultvalue = ""
  local type = info.what
  if type ~= lua and type ~= c then type = "LuaBinary" end
  local filename = info.source or defaultvalue
  if string.find(filename, ismod) then
    filename = "[mod]" .. string.sub(filename, string.len(ismod))
  end
  local fnname = info.name or defaultvalue
  local line = info.currentline ~= -1 and info.currentline or info.linedefined
  local from, to = info.linedefined, info.lastlinedefined
  local range = ""
  if from and to then range = catstring("[", from, "-", to, "]") end
  local str = catstring(filename, ":", line, "\n", type, " Function ", fnname,
                        range, "\n", ...)
  return str
end

function DBGTRACEBACK(level, fromlevel)
  local lua, c, bin = "Lua", "C", "Bin"
  local info = {}
  local cur = fromlevel or 2
  -- enough for traceback!
  if not level then level = 10 end
  if (type(level) ~= "number") then level = tonumber(level) end
  if level < fromlevel then level = fromlevel end
  local str = ""
  local defaultvalue = "???"
  local anonymous = "(anonymous)"
  local prev_filename = "???"
  local ismod = "../mods/"
  repeat
    info = debug.getinfo(cur)
    if not info then break end
    cur = cur + 1
    local ttype = info.what
    if ttype ~= lua and ttype ~= c then ttype = bin end
    local filename = info.source or defaultvalue
    if string.len(filename) > 60 then
      -- perhaps this is a chunk
      filename = string.sub(filename, 20) .. "..."
    end
    if string.sub(filename, 1, string.len(ismod)) == ismod then
      filename = "[mod]" .. string.sub(filename, string.len(ismod) + 1)
    end
    local from, to = info.linedefined, info.lastlinedefined
    local range = ""
    if from and to then range = catstring("[", from, "~", to, "]") end
    local display_filename = filename == prev_filename and "" or
                               catstring(filename, ":", "\n")
    prev_filename = filename
    local fnname = info.name or anonymous
    local line = info.currentline ~= -1 and info.currentline or info.linedefined
    local display_line = line and (":" .. line) or ""
    local display_type = ""
    if ttype == c or ttype == bin then display_type = "[x]" end
    local str1 = catstring(display_filename, display_type, fnname, display_line,
                           range, "\n")
    str = str .. str1
  until cur > level or ttype ~= lua
  return str
end

CONSOLE.dbg = function(...) CONSOLE.prt(DBGPRINT(...)) end
CONSOLE.debug = CONSOLE.dbg
CONSOLE.traceback = function(l, t)
  if type(l) ~= "number" then l = 10 end
  if type(t) ~= "number" then t = 2 end
  CONSOLE.prt(DBGTRACEBACK(l + 1, t + 1))
  return CONSOLE
end
CONSOLE.trace = CONSOLE.traceback
function LookUp(level, endlevel)
  local lua, c, bin = "Lua", "C", "Bin"
  local info = {}
  -- enough for traceback!
  if not endlevel then endlevel = 10 end
  local cur = level
  local ret = {}
  local defaultvalue = "???"
  local anonymous = ""
  repeat
    info = debug.getinfo(cur)
    if not info then break end
    cur = cur + 1
    local ttype = info.what
    if ttype ~= lua and ttype ~= c then ttype = bin end
    local filename = info.source or defaultvalue
    if string.len(filename) > 60 then
      -- perhaps this is a chunk
      filename = string.sub(filename, 20) .. "..."
    end
    local from, to = info.linedefined, info.lastlinedefined
    local fnname = info.name or anonymous
    local line = info.currentline ~= -1 and info.currentline or info.linedefined
    table.insert(ret, {
      source = filename,
      line = line,
      name = fnname,
      from = from,
      to = to,
      type = ttype
    })
  until cur > endlevel or ttype ~= lua
  return ret
end

function SequentialSearch(array, val)
  for i = 1, #array do if val == array[i] then return i end end
  return -1
end

function BinarySearch(array, val)
  local low = 1
  local high = #array
  while low <= high do
    local mid = math.floor((low + high) / 2)
    if array[mid] == val then
      return mid
    elseif array[mid] < val then
      low = mid + 1
    else
      high = mid - 1
    end
  end
  return -1
end

function FilterArray(array, filter)
  if type(array) ~= "table" then
    CONSOLE.err(array, "is not an array")
    return {}
  end
  local ret = {}
  for i, v in ipairs(array) do if filter(v) then table.insert(ret, v) end end
  return ret
end

if not table.filter then table.filter = FilterArray end
table.ifilter = FilterArray

function MapDict(dict, mapfn)
  if type(dict) ~= "table" then
    CONSOLE.err(dict, "is not a dict")
    return {}
  end
  local ret = {}
  for k, v in pairs(dict) do ret[k] = mapfn(k, v) end
  return ret
end

if not table.mapp then table.mapp = MapDict end

local function Merge(array, low, mid, high)
  local array3 = {}
  local i, j, k = low, mid + 1, low
  repeat
    if array[i] > array[j] then
      table.insert(array3, array[j])
      j = j + 1
    else
      table.insert(array3, array[i])
      i = i + 1
    end
  until i > mid or j > high
  if i < mid then
    repeat
      table.insert(array3, array[i])
      i = i + 1
    until i > mid
  elseif j < high then
    repeat
      table.insert(array3, array[j])
      j = j + 1
    until j > high
  end
  repeat
    array[k] = array3[k - low + 1]
    k = k + 1
  until k > high
end

local function SortArray(array, low, high)
  if low >= high then return end
  if low + 1 == high then
    if array[low] > array[high] then
      array[low], array[high] = array[high], array[low]
    end
    return
  end
  local mid = math.floor((low + high) / 2)
  SortArray(array, low, mid)
  SortArray(array, mid + 1, high)
  Merge(array, 1, mid, #array)
end

function _MergeSort(array) SortArray(array, 1, #array) end

function VerifyPlayer()
  local player = safefetch(GLOBAL, "ThePlayer", "entity")
  if not player then return false end
  if not player:IsValid() then return false end
  return true
end

function VerifyInst(inst) return inst and inst.entity and inst.entity:IsValid() end

function IsInteractive(inst)
  return VerifyInst(inst) and not inst:HasTag("INLIMBO")
end

_File = {
  resolve = function(self, name)
    local success, path = pcall(resolvefilepath, name)
    if success then self.name = path end
    return self.name
  end,
  open = function(self, name, op)
    if type(name) ~= 'string' then
      CONSOLE.err("invalid file name", name, op)
      return self
    end
    local function func()
      local myfile = io.open(name, op)
      if not myfile then return nil end
      self.file = myfile
      return myfile
    end

    self.name = name
    local flag, data = pcall(func)
    if not (flag and data) then
      CONSOLE.err("open file", name, "failed")
      self:close()
    end
    return self
  end,
  writestr = function(self, ...)
    local str = packstring(...)
    self:write(str)
    return self
  end,
  write = function(self, data)
    if not self.file then self:open(self.name, "w") end
    if not self.file then return end
    if data then self.data = self.data .. data end
    self.file:write(data)
    self:tryclose()
    return self
  end,
  read = function(self, name)
    if name == nil then name = self.name end
    if not self.file then self:open(name, "r") end
    if not self.file then return end
    local function func()
      local data = self.file:read("*a")
      self:tryclose()
      return data
    end

    local flag, data = pcall(func)
    if not (flag and data) then
      CONSOLE.err("read data error", flag, data)
      data = nil
    end
    return data
  end,
  decode = function(self, name, decoder)
    if name == nil then name = self.name end
    decoder = decoder or self.decoder
    local data = self:read(name)
    if not data then return nil end
    return decoder(data)
  end,
  encode = function(self, data, encoder)
    encoder = encoder or self.encoder
    if not data then return nil end
    local edata = encoder(data)
    return self:write(edata)
  end,
  tryclose = function(self)
    if not self.persist then self:close() end
    return self
  end,
  close = function(self)
    if self.file then
      self.file:close()
      self.file = nil
    end
    return self
  end,
  append = function(self, str)
    self.data = self.data .. str
    return self
  end
}
--[[
    op=r|w|a|r+|w+|a+,b
    unfortunately, a are not supported
]]
function MakeFile(name, op, ftype)
  local f = {file = nil, name = name, data = nil}
  if ftype == "json" then
    f.decoder = json.decode
    f.encoder = json.encode
  end
  setmetatable(f, {__index = _File})
  if name then
    f.persist = true
    f:open(name, op or "r")
  end
  return f
end

CONSOLE.dump = function(...)
  local t = gettime.time()
  local header = ""
  if t - debugfile.lastdumped > 1 then header = gettime.formatted() end
  if debugfile.lastdumped < 0 then
    debugfile:write("------------------------------------\n")
  end
  debugfile.lastdumped = t
  local str = header .. packstring(...) .. "\n"
  debugfile:writestr(str)
end

function EXPOSE(name, fname)
  if not fname then fname = name end
  local fn = safeget(env, fname)
  if not fn then return end
  exposeToGlobal(name, fn, false, true)
end

function FormatString(str, ...)
  if type(str) == "table" then str = str[math.random(#str) + 1] end
  if not str then return "" end
  if select("#", ...) > 0 then str = string.format(str, ...) end
  return str
end

function SendModRPC(name, fnname, ...)
  return SendModRPCToServer(GetModRPC(name or modname, fnname or ""), ...)
end

-- wrap an array so that it looks as if all elements can be seen as a total one.
-- note that it don't support number keisser
-- also if the first param passed is the array, the interpretation is that it is a class function
-- array.fn(...) array:fn(...) array[key]=value
-- but do not expect return value
function MakeBroadcast(tbl)
  if not tbl then tbl = {} end
  setmetatable(tbl, {
    __index = function(t, k)
      -- do not intefere with array
      if type(k) == "number" then
        return nil
      elseif type(k) == "nil" then
        return nil
      end
      local ret = {}
      setmetatable(ret, {
        __call = function(t, self, ...)
          if self == tbl then self = nil end
          for i, v in ipairs(tbl) do
            if v[k] then v[k](self or v, ...) end
          end
        end
      })
      return ret
    end,
    __newindex = function(t, k, v)
      if type(k) == "number" then
        return rawset(tbl, k, v)
      elseif type(k) == "nil" then
        CONSOLE.err("attempt to assign nil to array")
        return
      end
      for i, v in ipairs(tbl) do v[k] = v end
    end
  })
  return tbl
end

function MakeNamed(tbl, name) return function(...) return tbl[name](...) end end

function InheritClass(tbl, metatbl) setmetatable(tbl, {__index = metatbl}) end

---export local functions without any given context
-- however, you'd better use setfenv

local function exposeLocals()
  local ret = {}
  local function n()
    local i = 1
    while true do
      local name, fn = debug.getlocal(3, i)
      if name then
        print(name, fn)
        ret[name] = fn
        i = i + 1
      else
        return
      end
    end
  end
  n()
  return ret
end
function PreventMainLoaderCrash()
  if RegisterMod("PreventLoaderFromCrash") then return end
  local idx = 0
  for i, loader in ipairs(package.loaders) do
    if debug.getinfo(loader).source:find("main.lua") then
      idx = i
      break
    end
  end
  if idx > 0 then
    local loader = package.loaders[idx]
    package.loaders[idx] = function(...)
      local ret = {loader(...)}
      if type(ret[1]) == "string" and ret[1]:find("checked with custom loader") then
        ret = ret[1]
        ret = ret:gsub("(checked with custom loader)", ""):gsub("../mods/", "")
        ret = ret:sub(1, 4000) -- <=MAX_NUM_CHARS
        return ret
      end
      return unpack(ret)
    end
  end
end

-- purchaseutil
local msg =
  "\121\111\117\32\104\97\118\101\32\110\111\116\32\112\117\114\99\104\97\115\101\100\32\116\104\105\115\32\109\111\100\46"
function purchase_check(m, dur)
  m = m or msg
  local modinfo = KnownModIndex:GetModInfo(modname)
  if modinfo then
    local time = modinfo.version
    if type(time) == 'string' and time:len() > 7 then
      local year = tonumber(time:sub(1, 4))
      local month = tonumber(time:sub(5, 6))
      local day = tonumber(time:sub(7, 8))
      local date = os.time({year = year, month = month, day = day})
      local duration = dur or 30 * 7 * 24 * 60 * 60
      -- print(year, month, day)
      local now = os.time()
      if date > duration + now then
        c_announce(m)
        print(m)
        timer.tick(c_reset, 10)
      end
    end
  end
end
function imm_check() timer.tick(c_reset, 60 * 30) end
-- support any op
local dummyfn = function(_, ...) return _ end
local dummy = {
  __index = dummyfn,
  __newindex = function(_, k, v)
    if k ~= nil then
      rawset(_, k, v)
      return _
    else
      return _
    end
  end,
  __add = dummyfn,
  __sub = dummyfn,
  __div = dummyfn,
  __idiv = dummyfn,
  __unm = dummyfn,
  __mod = dummyfn,
  __pow = dummyfn,
  __band = dummyfn,
  __bor = dummyfn,
  __bxor = dummyfn,
  __bnot = dummyfn,
  __shl = dummyfn,
  __shr = dummyfn,
  __concat = dummyfn,
  __eq = function(_, other) return false end,
  __lt = function(_, other) return false end,
  __le = function(_, other) return false end,
  _tostring = function(_, other) return "" end,
  _tonumber = function(_, other) return 1 end,
  __len = function(_, other) return #_ end,
  __pairs = function(_, other)
    return function(_, k) -- 迭代函数
      local nextkey, nextvalue = next(_, k)
      return nextkey, nextvalue
    end
  end

}
function DBGPRINTLINE()
  local last = {"", ""}
  local function traceHandler(event, line)
    local info = debug.getinfo(2, "Sl")
    local str = catstring(info.short_src, ":", info.currentline)
    if str == last[1] then return end
    if str == last[2] then return end
    print(str)
    last[2] = last[1]
    last[1] = str
  end
  debug.sethook(traceHandler, "c")
end
function dynrequire(path)
  local t = {}
  setmetatable(t, {
    __index = function(_, k) return require(path)[k] end,
    __newindex = function(_, k, v) rawset(t, k, v) end
  })
  return t
end
-- prevent from Prefabs being replaced by ModWrangler
ThePrefab = safefetch(GLOBAL, "Prefabs")
local GLOBALVARIABLES = {"RegisteredMods", "RegisteredEntry"}
FilterArray(GLOBALVARIABLES, function(v) EXPOSE(v) end)
RegisterMod("apis", version)
