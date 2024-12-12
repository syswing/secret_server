-- @dependency apis.lua
-- @dependency uiapis.lua
local GLOBAL = _G
-- GLOBAL -- not resolvable...
function SetSpeed(n)
    if type(n) == "number" and n >= 0 and n < 100 then
        TheSim:SetTimeScale(n)
    else
        CONSOLE.err("invalid speed", n)
    end
end
--[[
    inst: entity
    critera: table{
        tag = ""||OR({""}),
        prefab=""||OR({""}),
        fn=function(inst) return true end,
    }
    radius: number
    ShouldIncludeInst: boolean

    return:table{
        [inst,]
        ...
    }
]]
function RegisterTag(criteria)
    if type(criteria.tag) == "string" then criteria.tag = {criteria.tag} end
    local rtag = TheSim:RegisterFindTags(criteria.must, criteria.cant, criteria.tag)
    return rtag
end
function SearchItems(inst, criteria, radius, ShouldIncludeInst)
    if inst ~= nil then
        if not radius then radius = 5 end
        local x, y, z = 0, 0, 0
        if inst.Transform then
            x, y, z = inst.Transform:GetWorldPosition()
        elseif inst.x then
            x, y, z = inst.x, inst.y, inst.z
        elseif #inst == 3 then
            x, y, z = unpack(inst)
        end
        local ents = {}
        if criteria.rtag then
            ents = TheSim:FindEntities_Registered(x, y, z, radius, criteria.rtag)
        else
            local musttags, canttags = criteria.must, criteria.cant
            local mustoneoftags = type(criteria.tag) == "string" and {criteria.tag} or criteria.tag
            ents = TheSim:FindEntities(x, y, z, radius, musttags, canttags, mustoneoftags)
        end
        return FilterArray(ents, function(v)
            if ShouldIncludeInst or v ~= inst then return MatchCriteria(v, criteria, inst) end
            return false
        end)
    end
    return {}
end

-- Client-side&Server-side ReSkin Function
-- Usage:
--[[Client
    SetSkin(inst,{
        name="skin_name",
        build="build_name",
        bank="bank_name",
        client=client_override[3]{"flag_name","build_name","override_build_name"},
        symbol=symbol_override[3]{"symbol_name","override_build_name","override_symbol_name"},
        skinsymbol=skinsymbol_override[3]{"symbol_name","override_build_name","override_symbol_name",?},
        flag=client_build_flag[3]{"flag_name","build_name","override_build_name"},
    })
    e.g.
    OverrideItemSkinSymbol("flower", skin_build, "flower", inst.GUID, "abigail_attack_fx"
]]
--[[Server
    SetSkin(inst,{
        ...(same as Client),
        name="skin_name",
        mode="skin_mode",
    })
]]
function SetSkin(inst, conf, override)
    if not inst then CONSOLE.err("[SkinAPI:SetSkin]", "inst is nil") end
    local anim = inst.AnimState
    if not anim then CONSOLE.err("[SkinAPI:SetSkin]", "inst.AnimState is nil") end
    local build_name = conf.build or inst.AnimState:GetBuild() or nil
    local bank_name = conf.bank
    local client_override = conf.client
    local symbol_override = conf.symbol
    local skinsymbol_override = conf.skinsymbol
    local skin_name = conf.name
    local skin_mode = conf.mode
    local is_server = inst.components ~= nil and inst.components.skinner ~= nil
    local client_build_flag = conf.flag
    -- local print_info = CONSOLE.make("SkinAPI")
    local print_info = CONSOLE.mute
    if override == nil then override = false end
    if skin_name ~= nil then
        inst.skinname = skin_name
        if is_server then
            print_info("set skin name=", skin_name)
            inst.components.skinner:SetSkinName(skin_name)
        end
    end
    if skin_mode ~= nil then
        if is_server then
            print_info("set skin mode=", skin_mode)
            inst.components.skinner:SetSkinMode(skin_mode)
        end
    end
    if client_build_flag then anim:SetClientSideBuildOverrideFlag(unpack(client_build_flag)) end
    if build_name then
        if override then
            anim:AddOverrideBuild(build_name)
        else
            anim:SetBuild(build_name)
        end
    end
    if bank_name then
        print_info("set bank name=", bank_name)
        anim:SetBank(bank_name)
    end
    if client_override then
        print_info("set client override=", client_override[1], client_override[2], client_override[3])
        if type(symbol_override) ~= "table" or #client_override < 2 then
            print_info("[SkinAPI:SetSkin]", "client_override is invalid")
        else
            if not client_override[3] then client_override[3] = client_override[1] end
            anim:SetClientsideBuildOverride(client_override[1], client_override[2], client_override[3])
        end
    end
    if symbol_override then
        if type(symbol_override) ~= "table" then
            print_info("wrong type of symbol")
        else
            if (#symbol_override) == 3 then
                if not symbol_override[2] then symbol_override[2] = build_name end
                print_info("set symbol override=", symbol_override[1], symbol_override[2], symbol_override[3])
                anim:OverrideSymbol(symbol_override[1], symbol_override[2], symbol_override[3])
            elseif (#symbol_override) == 2 then
                if not symbol_override[2] then symbol_override[2] = build_name end
                print_info("set symbol override=", symbol_override[1], symbol_override[2])
                anim:OverrideSymbol(symbol_override[1], symbol_override[2], symbol_override[1])
            else
                print_info("clear symbol override=", symbol_override[1])
                anim:ClearOverrideSymbol(symbol_override[1])
            end
        end
    end
    if skinsymbol_override then
        print_info("set itemskinsymbol override=", skinsymbol_override[1], skinsymbol_override[2],
            skinsymbol_override[3])
        anim:OverrideItemSkinSymbol(skinsymbol_override[1], skinsymbol_override[2] or anim:GetItemSkinBuild(),
            skinsymbol_override[1], inst.GUID, skinsymbol_override[3])
    end
end
function ReName(name, rename)
    STRINGS.NAMES[name] = rename
end

function ReRecipe(name, description)
    STRINGS.RECIPE_DESC[name] = description
end
local _memo = nil
local function GetMemoMap()
    local e, v, up = UPVALUE.fetch(resolvefilepath, "memoizedFilePaths")
    if _memo ~= v then _memo = v end
    return _memo
end
function ChangeBuild(build_name, filepath)
    -- if not _memo then
    if not GetMemoMap() then
        CONSOLE.err("[SkinAPI:ChangeBuild]", "memoizedFilePaths is nil")
        return
    end
    -- end
    if _memo[build_name] ~= filepath .. build_name then
        _memo[build_name] = nil
        _memo[build_name] = softresolvefilepath(build_name, true, filepath)
    end
    return _memo[build_name]
end
local rules = TUNING.IMAGEREPLACERULES or {}
function InstallImageReplacement()
    if TUNING.IMAGEREPLACERULES ~= rules then
        TUNING.IMAGEREPLACERULES = rules
        local Image = require('widgets/image')
        local SetTexture = Image.SetTexture
        local function SetTexture_new(self, atlas, tex, ...)
            local replace = rules[atlas] and rules[atlas][tex]
            if not replace then
                return SetTexture(self, atlas, tex, ...)
            else
                SetTexture(self, replace[1], replace[2], ...)
            end
        end

        Image.SetTexture = SetTexture_new
    end
end
function ReplaceImage(atlas1, texture1, atlas2, texture2, nooverride)
    rules[atlas1] = rules[atlas1] or {}
    if nooverride and rules[atlas1][texture1] then return end
    if not atlas2 then CONSOLE.err("ReplaceImage: no atlas2 given", atlas1, texture1, atlas2, texture2, nooverride) end
    rules[atlas1][texture1] = {atlas2, texture2 or texture1}
end
--[[
    Usage:
    NewAnimState{
        old=AnimState,
        XXXfns={}
        add=insert a function into the table,
    }
    This is a memory costly function, so it should be used only when necessary.
]]
-- do not work now, maybe I've broken something.
function GetNewAnimState(anim)
    local new = {
        old = anim,
        add = function(self, name, fn)
            if not rawget(self, name .. "fns") then self[name .. "fns"] = {} end
            table.insert(self[name .. "fns"], fn)
        end,
        -- predefined fns
        --[[
            Pre-Defined New AnimState Fns(self,...)
                if there be any newfn(self,{...},ret) that returns non-nil values, then override old fn
                else run old fn
            each fn can modify param and return value successviely.
                return true if modified and does not want other fns to run
                else return false
                default nil is interpreted as false
            especially, if there is indeed a return value, any fn should run the function itself and return it
        ]]
        SetBuildfns = {},
        OverrideSymbolfns = {},
        OverrideItemSkinSymbolfns = {},
        --[[
        SetBuild=function(self,...)
            local ret=nil
            for i,v in ipairs(self.setbuildfns) do
                ret=v(self,{...},ret)
            end
            if not ret then
                ret=self.old.SetBuild(self.old,...)
            end
            return ret
        end
        ]]
        Make = function(self, name)
            return function(...)
                local param = {...}
                local ret = nil
                for i, v in ipairs(name .. "fns") do ret = v(self, param, ret) end
                if not ret then ret = self.old[name](self.old, unpack(param)) end
                return ret
            end
        end
        --[[
        OverrideSymbol = function(self, a, b, c, ...)
            if b == "hat_football" then
                return self.old.OverrideSymbol(self.old, a, "demon_footballhat", c, ...)
            else
                return self.old.OverrideSymbol(self.old, a, b, c, ...)
            end
        end
        ]]
    }
    setmetatable(new, {
        __index = function(t, k)
            if k == "old" then return t.old end
            local newfns = t[k .. "fns"]
            if newfns then return t:Make(k) end
            local fn = t.old[k]
            if not fn then
                CONSOLE.err("try to access non-exists function:", k)
                return
            end
            return function(self, ...)
                return fn(t.old, ...)
            end
        end
    })
    return new
end

function HackAnimState(inst)
    local old = safefetch(inst, "AnimState")
    if not old then return nil end
    if type(old) == "table" then return old end
    if type(old) == "userdata" then
        local new = GetNewAnimState(old)
        return new
    end
    return nil
end
function ReturnAnimState(inst)
    local old = safefetch(inst, "AnimState")
    if not old then return nil end
    local anims = old.old
    if anims then inst.AnimState = anims end
    setmetatable(old, AnimState)
end

function MakeFollowAnim(inst, leader, symbol, x, y, z)
    if not inst then
        CONSOLE.err("[SkinAPI:MakeFollowAnim]", "usage: inst,leader,symbol,x:right,y:down,z:front")
        return
    end
    if not symbol then
        CONSOLE.err("[SkinAPI:MakeFollowAnim]", "symbol is nil")
        return
    end
    x = x or 0 -- left/right
    y = y or 0 -- down/up
    z = z or 0 -- front/back
    inst.entity:AddFollower()
    -- buggy
    -- inst.entity:SetParent(leader.entity)
    inst.Follower:FollowSymbol(leader.GUID, symbol, x, y, z)
end

function SetSkinOnPrefab(prefab, conf, override)
    AddPrefabPostInit(prefab, function(inst)
        SetSkin(inst, conf, override)
    end)
end

function SearchEnemies(inst, radius)
    return SearchItems(inst, {
        fn = function(ent)
            if not ent:HasTag("_combat") then return false end
            local h = safefetch(ent, "components", "health")
            local c = safefetch(ent, "components", "combat")
            if h and not h:IsDead() then return c and c:TargetIs(inst) end
            return false
        end
    }, radius, false)
end

--[[
    Note: You can't change the return value because Klei uses this as a heartbeat signal between lua and c.
]] --
local _hacked_skinownership = false
local _hacked_skinownership_list = {}
local _hacked_skinownership_item_list = {}
local function HackSkinCheck(self, skin, ...)
    local fn = _hacked_skinownership_list[skin]
    if not fn then return false, nil, nil end
    return true, fn, {inv = self, skin = skin, userid = nil, params = {...}}
end

local function HackSkinCheckClient(self, userid, skin, ...)
    local fn = _hacked_skinownership_list[skin]
    if not fn then return false, nil, nil end
    return true, fn, {inv = self, skin = skin, userid = userid, params = {...}}
end

function HackSkinOwnership(item, skins, newfn)
    if newfn then if skins then for _, v in pairs(skins) do _hacked_skinownership_list[v] = newfn end end end
    if item then
        if not _hacked_skinownership_item_list[item] then _hacked_skinownership_item_list[item] = {} end
        for _, v in ipairs(skins) do table.insert(_hacked_skinownership_item_list[item], v) end
    end
    if _hacked_skinownership then return end
    _hacked_skinownership = true
    local check_ownership = InventoryProxy.CheckOwnership
    InventoryProxy.CheckOwnership = function(self, skin, ...)
        local found, fn, param = HackSkinCheck(self, skin, ...)
        if found then return fn(param) end
        return check_ownership(self, skin, ...)
    end

    local check_client_ownership = InventoryProxy.CheckClientOwnership
    InventoryProxy.CheckClientOwnership = function(self, userid, skin, ...)
        local found, fn, param = HackSkinCheckClient(self, userid, skin, ...)
        if found then return fn(param) end
        return check_client_ownership(self, userid, skin, ...)
    end

    local check_ownershipGLOBALet_latest = InventoryProxy.CheckOwnershipGetLatest
    InventoryProxy.CheckOwnershipGetLatest = function(self, skin, ...)
        local found, fn, param = HackSkinCheck(self, skin, TheNet:GetUserID(), ...)
        if found then return fn(param) end
        return check_ownershipGLOBALet_latest(self, skin, ...)
    end
end

-- skin_id is a c level id that is generated by skin_name and session_id, so we cannot deduce that from lua level
-- so it is wise to make a fake one :)
local function generate_skin_id(skin_name)
    if type(skin_name) == "string" then
        local session_id = safefetch(TheWorld, "meta", "session_identifier") or math.random()
        return math.abs(hash(skin_name) - hash(tostring(session_id)))
    end
end

function SetSkinPrefab(inst, skin)
    inst.skin_id = generate_skin_id(skin or inst.skin_name or inst.prefab)
end

function GetBuildName(inst)
    if not inst then return "" end
    -- test results in unreliable skin names, so use anim state only
    -- local names = {inst.skin_name, inst:GetSkinBuild(), inst.AnimState:GetBuild()}
    local names = {inst.AnimState:GetBuild()}
    for i, name in pairs(names) do if name and name ~= "" then return name end end
    return ""
end

function GetReplica(inst, name, fnname)
    local a = safefetch(inst, "replica", name)
    if fnname then
        if a and a[fnname] then
            return a
        else
            return nil
        end
    else
        return a
    end
end

function GetComponent(inst, name, fnname)
    local a = safefetch(inst, "components", name)
    if fnname then
        if a and a[fnname] then
            return a
        else
            return nil
        end
    else
        return a
    end
end

function GetReplicaOrComponent(inst, name, fnname)
    local a = GetReplica(inst, name, fnname)
    local b = GetComponent(inst, name, fnname)
    return a or b
end

function IsMoving(inst)
    -- basically this is enough
    if inst:HasTag("moving") then return true end
    if inst.sg then if inst.sg:HasStateTag("moving") then return true end end
    if inst:HasTag("idle") then return false end
    return false
end
function IsBusy(inst, starttime, timeout)
    if inst._busy then return true end
    if inst.sg then if inst.sg:HasStateTag("moving") then return true end end
    if inst:HasOneOfTags({"moving"}) then return true end
    if inst:HasTag("idle") then return false end
    local pc = inst.components.playercontroller
    if pc then
        if pc:IsDoingOrWorking() then
            return true
        elseif pc.classified ~= nil and pc.classified.pausepredictionframes:value() > 0 then
            return true
        end
    end
    if starttime and timeout then if timeout < (GetTime() - starttime) then return false end end
    return false
end
-- event handler, in javascript style
-- entity:ListenForEvent(inst,event,fn,source)
-- source is not used here, don't use source param
local _eventlandlers = {}
function AddEventListener(inst, event, fn, ...)
    if not (inst and inst.ListenForEvent) then return end
    if event == nil then return end
    if fn == nil then return end
    local isstring = type(fn) == "string"
    local _fn = fn
    local wrapped = function(...)
        return inst[_fn](...)
    end
    if isstring then fn = wrapped end
    if select("#", ...) > 0 then
        local args = {...}
        local handler = function(...)
            local args2 = {...}
            local params = {}
            for k, v in pairs(args) do table.insert(params, v) end
            for k, v in pairs(args2) do table.insert(params, v) end
            fn(unpack(params))
        end
        table.insert(_eventlandlers, {handler, inst.GUID, event, _fn, {...}})
        inst:ListenForEvent(event, handler)
    else
        table.insert(_eventlandlers, {fn, inst.GUID, event, _fn})
        inst:ListenForEvent(event, fn)
    end
end
function RemoveEventListener(inst, event, fn)
    if not (inst and inst.RemoveEventCallback) then
        CONSOLE.mute(inst, "has no listener")
        return
    end
    if event == nil then return end
    for i, v in ipairs(_eventlandlers) do
        if v[1] and v[2] == inst.GUID and v[3] == event and (not fn or v[4] == fn) then
            inst:RemoveEventCallback(event, v[1])
            _eventlandlers[i] = {}
        end
    end
end

function CreateEvent(inst, event)
    if not (inst and inst.PushEvent) then return end
    inst:PushEvent(event)
end
function AllocateNetString(name, guid, ondirtyfn)
    if not ondirtyfn then
        local names = string.split(name, ".")
        ondirtyfn = "on" .. names[#names] .. "dirty"
    end
    if type(ondirtyfn) ~= "string" then
        CONSOLE.err("ondirtyfn is not string")
        return false
    end
    if type(guid) == "table" then guid = safeget(guid, "GUID") end
    if type(guid) ~= "number" then
        CONSOLE.err("AllocateNetVariable", name, "did not provide GUID")
        return false
    end
    return net_string(name, guid, ondirtyfn)
end
function AllocateNetEntity(name, guid, ondirtyfn)
    if not ondirtyfn then
        local names = string.split(name, ".")
        ondirtyfn = "on" .. names[#names] .. "dirty"
    end
    if type(ondirtyfn) ~= "string" then
        CONSOLE.err("ondirtyfn is not string")
        return false
    end
    if type(guid) == "table" then if safeget(guid, "GUID") then guid = safeget(guid, "GUID") end end
    if type(guid) ~= "number" then
        CONSOLE.err("AllocateNetEntity", name, "did not provide GUID")
        return false
    end
    return net_entity(name, guid, ondirtyfn)
end
function IntToLog2(int)
    local ret = 0
    repeat
        int = int / 2
        ret = ret + 1
    until int <= 1
    return ret
end
function AllocateNetVariable(name, length, guid, ondirtyfn)
    local var = nil
    if not ondirtyfn then
        local names = string.split(name, ".")
        ondirtyfn = "on" .. names[#names] .. "dirty"
    end
    if type(ondirtyfn) ~= "string" then
        CONSOLE.err("ondirtyfn is not string")
        return false
    end
    if not length then length = 8 end
    if length < 1 then length = 1 end
    if length > 32 then
        CONSOLE.err("Too long for AllocateNetVariable, did you mean log2?")
        return false
    end
    if type(guid) == "table" then guid = safeget(guid, "GUID") end
    if type(guid) ~= "number" then
        CONSOLE.err("AllocateNetVariable", name, "did not provide GUID")
        return false
    end
    local nets = {net_bool, 0, net_tinybyte, 0, 0, net_smallbyte, 0, net_byte, 0, 0, 0, 0, 0, 0, 0, net_ushortint}
    --[[net_int 32-bit signed integer 范围 [-2147483647..2147483647]
    net_uint 32-bit unsigned integer 范围 [0..4294967295]
    net_float 32-bit float
    net_hash 32-bit hash of the string assigned
    net_string variable length string
    net_entity entity instance
    net_bytearray array of 8-bit unsigned integers max size = 31
    net_smallbytearray
作者：LongFei
链接：https://zhuanlan.zhihu.com/p/570375494
来源：知乎]]
    if length == 32 then
        var = net_uint
    else
        local i = length
        repeat
            var = nets[i]
            i = i + 1
        until var ~= 0
    end
    return var(name, guid, ondirtyfn)
end
function GetPrefabFn(inst)
    if type(inst) == "table" then inst = inst.prefab end
    if type(inst) ~= "string" then
        CONSOLE.err("GetPrefabFn:inst=", inst)
        return
    end
    if _G.Prefabs[inst] then return _G.Prefabs[inst].fn end
end
function RegisterInventoryItemAtlas2(xml, img)
    if type(xml) ~= "string" or type(img) ~= "string" then return false end
    if string.sub(xml, -3) ~= "xml" then xml = xml .. ".xml" end
    if string.sub(img, -3) ~= "tex" then img = img .. ".tex" end
    local realpath = softresolvefilepath(xml)
    if not realpath and not string.find(xml, "images/", 1, true) then
        realpath = realpath or softresolvefilepath("images/" .. xml)
    end
    if realpath then
        if RegisterInventoryItemAtlas then
        RegisterInventoryItemAtlas(realpath, img)
        RegisterInventoryItemAtlas(realpath, hash(img))
        end
    else
        CONSOLE.err("RegisterInventoryItemAtlas2 failed to find", xml)
        return false
    end
    return true
end
function RegInvImage(...)
    local args = {...}
    if #args == 1 then
        if type(args[1]) == "table" then
            if #args[1] > 0 then
                if type(args[1][1]) == "table" then
                    -- {{xml,image}}
                    for i, v in ipairs(args[1]) do
                        if not RegisterInventoryItemAtlas2(v[1], v[2]) then
                            CONSOLE.err("RegInvImage Failed at", table.tostring(args[1]))
                        end
                    end
                elseif type(args[1][1]) == "string" then
                    -- {imgs}
                    -- assume xml name is equivalent to image name
                    for i, v in ipairs(args[1]) do
                        if not RegisterInventoryItemAtlas2(v, v) then
                            CONSOLE.err("RegInvImage Failed at", v)
                        end
                    end
                end
            elseif next(args[1]) then
                -- {xml=img}
                for k, v in pairs(args[1]) do
                    if type(v) == "table" and #v > 0 then
                        -- {xml={img,img}}
                        for i, v2 in ipairs(v) do
                            if not RegisterInventoryItemAtlas2(k, v2) then
                                CONSOLE.err("RegInvImage Failed at", table.tostring(k), table.tostring(v2))
                            end
                        end
                    elseif type(v) == "string" then
                        if not RegisterInventoryItemAtlas2(k, v) then
                            CONSOLE.err("RegInvImage Failed at", table.tostring(k), table.tostring(v))
                        end
                    else
                        CONSOLE.err("RegInvImage failed at", table.tostring(args[1]))
                    end
                end
            end
        elseif type(args[1]) == "string" then
            -- xmlfilepath
            -- require SLAXML
            if not SLAXML then
                CONSOLE.err("SLAXML is required to read from xml file", args[1])
                return
            end
            if not string.sub(args[1], -3) == "xml" then args[1] = args[1] .. ".xml" end
            local filepath = resolvefilepath_soft(args[1])
            if not filepath then
                CONSOLE.err("RegInvImage assumes", args[1], "as a xml file path, but can't find it anywhere")
            else
                local images = {}
                local file = io.open(filepath, "r")
                local parser = SLAXML:parser({
                    attribute = function(name, value)
                        if name == "name" then table.insert(images, value) end
                    end
                })
                parser:parse(file:read("*a"))
                file:close()
                for _, image in ipairs(images) do
                    RegisterInventoryItemAtlas(filepath, image)
                    RegisterInventoryItemAtlas(filepath, hash(image))
                end
            end
        end
    elseif #args == 2 then
        if type(args[1]) == "string" and type(args[2]) == "string" then
            -- xml,img
            if not RegisterInventoryItemAtlas2(...) then
                CONSOLE.err("RegInvImage failed at", table.tostring(args))
            end
        elseif type(args[1]) == "string" and type(args[2]) == "table" then
            -- xml, {imgs}
            if #args[2] > 0 and type(args[2][1]) == "string" then
                for i, v in ipairs(args[2]) do
                    if not RegisterInventoryItemAtlas2(args[1], v) then
                        CONSOLE.err("RegInvImage failed at", table.tostring(args))
                    end
                end
            end
        else
            CONSOLE.err("RegInvImage failed at", table.tostring(args))
        end
    elseif #args == 3 then
        -- dir,xml,img
        if type(args[1]) == "string" and type(args[2]) == "string" then
            return RegInvImage(args[1] .. args[2], args[3])
        else
            CONSOLE.err("RegInvImage failed at", table.tostring(args))
        end
    end
end
function RegAssets(xml, t)
    if type(xml) ~= "string" then return false end
    table.insert(Assets, MakeAsset("ATLAS", xml))
    table.insert(Assets, MakeAsset("ATLAS_BUILD", xml))
    if type(t) == "table" then
        for i, v in ipairs(t) do table.insert(Assets, MakeAsset("INV_IMAGE", v)) end
    else
        table.insert(Assets, MakeAsset("INV_IMAGE", t))
    end
end