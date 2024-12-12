-- DILIGENT DESERTER
--[[
    debug utils
]] --
local mymodname = "Diligent Deserter"
local MYMODNAME = "TeleportTower"
local test = (not GetIsWorkshop()) or (GetConfig("debug") or "false")
local log = function(...)
end
local err = function(...)
    return CONSOLE.prt(CONSOLE.tag(mymodname), ...)
end
local warn = function(...)
    return CONSOLE.prt(CONSOLE.tag(mymodname), ...)
end
local lang = GetConfig("language") or "zh"
if test then log = CONSOLE.log end
--[[
    global definition
]]
utils.mod("scripts/DiligentTraveller.lua")
local ISSERVER = IsServer()
local ISCLIENT = IsClient()
local HASHUD = HasHUD()
local INITIALEMPTYTABLE = "{ }"
--[[
    public class
]]
-- This is our server manager for multiportal support
-- It supports multiple portals being open concurrently
-- It supports cross-world teleportation
-- It does not support player summoning
-- Also supports sand stone's getting all portals utils
local PortalManager = {
    portals = {}, -- guid dict
    portalscount = 0,
    activeportals = {}, -- guid dict
    foreignportals = {}, -- {worldid={guid={...}}}
    player_to_portal = {}, -- guid to guid
    activecount = 0,
    inst = nil,
    savekey = "AllPortals",
    saver = MakeNonVolatileSaver(MYMODNAME)
}
function PortalManager:Init(world)
    self.inst = world
    if world.PortalManager then return end
    world.PortalManager = self
    self:AttachNetVar()
    AddEventListener(world, "ms_registertownportal", function(_, ...)
        self:Register(...)
    end)
    AddEventListener(world, "activateportal", function(_, ...)
        self:Activate(...)
    end)
    AddEventListener(world, "townportaldeactivated", function(_, ...)
        self:Deactivate(...)
    end)
    AddEventListener(world, "shardconnected", function(_, ...)
        self:SendDataToOtherWorld(...)
    end)
    AddEventListener(world, "sharddisconnected", function(_, worldid)
        self.foreignportals[worldid] = nil
    end)
    self:Load()
    self:PushEvent()
end
function PortalManager:PushEvent()
    self.inst:PushEvent("portalmanagerconnected")
end
function PortalManager:Register(inst)
    if inst.prefab ~= "townportal" then
        -- it is sandstone!
        return
    end
    local guid = inst.GUID
    if not self.portals[guid] then self.portalscount = self.portalscount + 1 end
    self.portals[guid] = inst
    AddEventListener(inst, "onremove", self.Unregister, self)
end
function PortalManager:Unregister(inst)
    local guid = inst.GUID
    if self.portals[guid] then
        self.portalscount = self.portalscount - 1 
        self.portals[guid] = nil
    end
    self:Deactivate(inst)
end
function PortalManager:Activate(inst, player)
    if not VerifyInst(inst) then return end
    local guid = inst.GUID
    if not self.activeportals[guid] then
        self.activecount = self.activecount + 1
        for k, v in pairs(self.portals) do if k ~= guid then v:PushEvent("activateotherportal") end end
        self.activeportals[guid] = inst
        if VerifyInst(player) then self.player_to_portal[player.GUID] = guid end
    end
end
function PortalManager:Deactivate(inst)
    if not VerifyInst(inst) then return end
    local guid = inst.GUID
    if not self.activeportals[guid] then return end
    self.activecount = self.activecount - 1
    self.activeportals[guid] = nil
    if self.activecount == 0 then for k, v in pairs(self.portals) do v:PushEvent("allportalsunlinked") end end
end
function PortalManager:GetName(inst)
    if inst and inst:IsValid() and inst.components.writeable then return inst.components.writeable:GetText() end
    return nil
end
function PortalManager:IsPortalAvailable(guid, worldid)
    if worldid then
        if theshard.isavailable(worldid) then return true end
        return false
    else
        if ISSERVER then
            return VerifyInst(Ents[guid])
        else
            return true
        end
    end
end
function PortalManager:Encode(forrpc, israw, localonly)
    local data = {}
    for guid, portal in pairs(self.portals) do
        if self:IsPortalAvailable(guid) then
            local x, y, z = portal:GetPosition():Get()
            local info = {
                x = x,
                -- y = y,
                z = z,
                text = self:GetName(portal),
                guid = guid
            }
            if forrpc then info.guid = guid end
            table.insert(data, info)
        else
            warn("Invalid portal found: ", guid, portal)
        end
    end
    if forrpc and not localonly then
        for i, v in pairs(self.foreignportals) do
            if self:IsPortalAvailable(nil, i) then
                for guid, v2 in pairs(v) do
                    table.insert(data, {worldid = i, x = v2.x, z = v2.z, guid = guid, text = v2.text})
                end
            end
        end
    end
    --[[
        Sort Method:
        1. Name(Letter By Letter)
        2. Other World(Last)
        --3. GUID
    ]]
    table.sort(data, function(a, b)
        -- log(table.tostring(a, 0, 1), table.tostring(b, 0, 1))
        local valid_comp = a and b
        if not valid_comp then return a ~= nil end
        local foreign_comp = (a.worldid == nil) ~= (b.worldid == nil)
        if foreign_comp then return not a.worldid end
        local name_comp = a.text and b.text
        if name_comp then
            return a.text < b.text
        else
            return a.x < b.x
        end
        -- return a.guid < b.guid
    end)
    if not forrpc then
        -- remove unnecessary GUID
        table.ifilter(data, function(v)
            if not v.worldid then v.guid = nil end
        end)
    end
    return israw and data or json.encode(data)
end
function PortalManager:Decode(data, fromrpc)
    local savedportals = type(data) == 'table' and data or json.decode(data)
    if not savedportals then return nil end
    if fromrpc then return savedportals end
    -- we just need x and z axis to target a portal. y axis is unused.
    local xzindex = {}
    for i, v in ipairs(savedportals) do
        if v.x then
            if not xzindex[v.x] then xzindex[v.x] = {} end
            if v.z then xzindex[v.x][v.z] = v.text end
        end
    end
    local meta = {
        __index = function(self, x)
            return {}
        end
    }
    setmetatable(xzindex, meta)
    return xzindex
end
function PortalManager:GetPortalForPlayer(inst)
    local player = inst or ThePlayer
    if not VerifyInst(player) then return nil end
    local cached = self.player_to_portal[player.GUID]
    if cached then
        cached = Ents[cached]
        if VerifyInst(cached) and cached.components.channelable.channeler == player then return cached end
    end
    local ents = SearchItems(player, {prefab = "townportal"}, 20)
    local ret = nil
    local mindistance = math.huge
    for i, v in ipairs(ents) do
        local a1 = true or v.AnimState:IsCurrentAnimation("idle_on_loop")
        local a2 = true or v.AnimState:IsCurrentAnimation("turn_on")
        if a1 or a2 then
            local dist = player:GetDistanceSqToInst(v)
            if dist < mindistance then
                mindistance = dist
                ret = v
            end
        end
    end
    return ret
end
function PortalManager:Teleport(portal, player, guid, worldid)
    log("PortalManager:Teleport", portal, player, guid, worldid)
    if not portal then portal = self:GetPortalForPlayer(player) end
    if not portal then
        warn("PortalManager:Teleport cannot get portal")
        return false
    end
    -- decide where to teleport
    if not worldid then
        if self.portals[guid] then return self:TeleportToThisWorld(portal, player, guid) end
    else
        if self:IsPortalAvailable(nil, worldid) then
            local foreigns = self.foreignportals[worldid]
            if foreigns then
                local foreignportal = foreigns[guid]
                if foreignportal then
                    return self:TeleportToOtherWorld(portal, player, guid, worldid, foreignportal.x, foreignportal.z)
                end
            end
        else
            warn("PortalManager:World", worldid, " Unavailable at the moment")
        end
    end
    warn("PortalManager:Teleport to invalid target", Ents[guid])
    return false
end
function PortalManager:TeleportToThisWorld(portal, player, guid)
    local target = Ents[guid]
    if not VerifyInst(target) then
        warn("PortalManager:Teleport get invalid target", portal, player, guid, target)
        return false
    end
    portal.components.teleporter:SetEnabled(true)
    portal.components.teleporter:MigrationTarget()
    portal.components.teleporter:Target(target)
    player.sg:GoToState("entertownportal", {teleporter = portal})
    return true
end
function PortalManager:TeleportToOtherWorld(portal, player, guid, worldid, x, z)
    if x and z then
        --[[
            TheWorld:PushEvent("ms_playerdespawnandmigrate", {
                player = player,
                -- portalid = guid,
                x = x,
                y = 0,
            z = z,
            worldid = tostring(worldid)
        })
        ]]
        portal.components.teleporter:SetEnabled(true)
        portal.components.teleporter:Target()
        portal.components.teleporter:MigrationTarget(tostring(worldid), x, 0, z)
        player.sg:GoToState("entertownportal", {teleporter = portal})
        return true
    else
        return false
    end
end
function PortalManager:Save()
    if ISCLIENT then return end
    if not self.saver.loaded then self:Load() end
    local data = self:Encode()
    local data_hash = hash(data)
    local diff = data_hash ~= self.cached_data_hash
    if diff then
        self.cached_data = data
        self.cached_data_hash = data_hash
        self.saver:set(self.savekey, data)
        self.saver:save()
    end
end
function PortalManager:Load()
    if ISCLIENT then return end
    if self.saver.loaded then return end
    self.saver:load(function(data)
        local index = self:Decode(data)
        if not index then return end
        for _, portal in pairs(index) do
            local x, y, z = portal:GetPosition():Get()
            local newname = index[x][z]
            if newname then
                local oldname = self:GetName(portal)
                if not oldname or oldname == "" then
                    local writer = ThePlayer or AllPlayers[1]
                    if writer then
                        portal.components.writeable:Write(writer, newname)
                    else
                        -- direct set
                        portal.components.writeable:SetText(newname)
                    end
                end
            end
        end
    end)
end
function PortalManager:Sync(force)
    -- broadcast to all players, because the net var is in TheWorld
    self.info = self:Encode(true, true)
    local data = self:Encode(true)
    local data_hash = hash(data)
    local diff = self.data_rpc_hash ~= data_hash
    if diff then
        self.data_rpc_hash = data_hash
        self.data_rpc = data
    end
    if diff or force then
        local var = safefetch(self, "inst", "net", "_allportals")
        if var then
            if force then var:set_local(data) end
            var:set(data)
        else
            warn(
                "TheWorld.net._allportals is missing, this probably happens when the game starts, otherwise this must be a a bug")
        end
        -- send to other world by the way
        self:SendDataToOtherWorld()
        -- save by the way
        self:Save()
    end
end
function PortalManager:AttachNetVar(trytimes)
    self.attaching = true
    local net = safefetch(self, "inst", "net")
    if not net then
        if not trytimes then trytimes = 1 end
        if trytimes < 60 then
            timer.tick(self.AttachNetVar, trytimes * 1.5, self, trytimes * 1.5)
        else
            self.attaching = false
        end
        return
    end
    if net._allportals then return end
    net._allportals = net_string(net.GUID, "_allportals", "allportalsdirty")
    net._allportals:set(INITIALEMPTYTABLE)
    AddEventListener(net, "allportalsdirty", self.RefreshPortalData, self)
    AddEventListener(net, "onremove", function()
        self.inst = nil
    end)
    self.attaching = false
    if ISCLIENT then self:Sync(true) end
end
function PortalManager:GetWorlds()
    -- ShardConnected[world_id] = { ready = true, tags = tags, world = world_data }
    -- we only care about worldid
    return theshard.getshardlist()
end
function PortalManager:SendDataToOtherWorld(which)
    local worlds = which and {which} or self:GetWorlds()
    local text = self:Encode(true, false, true)
    SendModRPCToShard(GetShardModRPC(modname, "SyncWorldData"), worlds, text)
end
function PortalManager:SyncOtherWorld(worldid, data)
    local foreignportals = json.decode(data)
    if not self.foreignportals[worldid] then self.foreignportals[worldid] = {} end
    for i, v in ipairs(foreignportals) do
        v.worldid = worldid
        self.foreignportals[worldid][v.guid] = v
    end
    self:Sync()
end
function PortalManager:EraseName(guid)
    local ent = Ents[guid or ""]
    if not VerifyInst(ent) then return end
    local wr = safefetch(ent, "components", "writeable")
    if not wr then return end
    wr:SetText()
end
function PortalManager:UseStone(guid, player)
    log("Server Usestone")
    player = player or ThePlayer
    if not VerifyInst(player) then return end
    if player:HasTag("playerghost") then return end -- ghost cannot teleport
    local ent = Ents[guid]
    if not VerifyInst(ent) then return end
    local cost = 1
    local hasstone, amount = player.replica.inventory:Has("townportaltalisman", cost, true)
    log(hasstone, amount)
    if not hasstone then return end
    -- log("Can use stone")
    return self:DoStoneTeleport(ent, player)
end
function PortalManager:GetOneStone(player)
    local criteria = {prefab = "townportaltalisman"}
    local inv = player.components.inventory or player.replica.inventory
    if inv.activeitem then if MatchCriteria(inv.activeitem, criteria) then return inv.activeitem end end
    if inv.itemslots then for k, v in pairs(inv.itemslots) do if MatchCriteria(v, criteria) then return v end end end
    if inv.equipslots then for k, v in pairs(inv.equipslots) do if MatchCriteria(v, criteria) then return v end end end
    if inv.opencontainers then
        for k2, v2 in pairs(inv.opencontainers) do
            local items = k2.components.container:GetAllItems()
            for k, v in pairs(items) do if MatchCriteria(v, criteria) then return v end end
        end
    end
    local overflow = inv:GetOverflowContainer()
    if overflow then for k, v in pairs(overflow:GetAllItems()) do if MatchCriteria(v, criteria) then return v end end end
end
function PortalManager:DoStoneTeleport(target, player)
    local inst = self:GetOneStone(player)
    inst.components.teleporter:Target(target)
    if player.sg then player.sg:GoToState("entertownportal", {teleporter = inst}) end
    timer.tick(function()
        if VerifyInst(inst) then
            if inst.components.teleporter.targetTeleporter == target then
                inst.components.teleporter:Target(nil)
            end
        end
        if player.components.playercontroller ~= nil then
            player.components.playercontroller:EnableMapControls(true)
        end
    end, 2)
end
-- This is our client manager
PortalManagerClient = {portals = {}, activeportals = {}, info = {}, world = nil}
function PortalManagerClient:Init(world)
    self.inst = world
    world.PortalManager = self
    self:AttachNetVar()
    self:Sync(true)
    self:PushEvent()
end
function PortalManagerClient:RefreshPortalData()
    log("RefreshPortalData")
    local var = self.inst.net._allportals
    local data = json.decode(var:value())
    if data then
        self.info = data
        log(table.tostring(self.info, 1, 0))
    end
end
function PortalManagerClient:EraseName(guid)
    SendModRPC(modname, "erase", guid)
end
function PortalManagerClient:Teleport(portal, player, guid, worldid)
    if ISSERVER then return PortalManager:Teleport(portal, player, guid, worldid) end
    SendModRPC(modname, "teleport", guid, worldid)
end
function PortalManagerClient:Sync(force)
    if ISSERVER then return PortalManager:Sync(force) end
    -- sometimes it fails to sync, so help a bit
    local netvar = safefetch(self, "inst", "net", "_allportals")
    if netvar then
        --[[
        local text = netvar:value()
        if text == INITIALEMPTYTABLE then
            force = true
        end
        ]]
    else
        warn("TheWorld.net._allportals is missing in client")
        if not self.attaching then self:AttachNetVar() end
        return
    end
    SendModRPC(modname, "SyncPortalData", force)
end
function PortalManagerClient:UseStone(guid)
    if not guid then return end
    if not VerifyPlayer() then return end
    if ISSERVER then return PortalManager:UseStone(guid) end
    log("Send Use Stone RPC")
    local inst = ThePlayer
    if inst.components.playercontroller ~= nil then inst.components.playercontroller:EnableMapControls(false) end
    SendModRPC(modname, "UseStone", guid)
    timer.itick(inst, function()
        if inst.components.playercontroller ~= nil then inst.components.playercontroller:EnableMapControls(true) end
    end, 2)
end
InheritClass(PortalManagerClient, PortalManager)
--[[
    Private function
]]
local function OnEntityWake(inst)
    if inst.playingsound and not (inst:IsAsleep() or inst.SoundEmitter:PlayingSound("active")) then
        inst.SoundEmitter:PlaySound("dontstarve/common/together/town_portal/talisman_active", "active")
    end
end
local function OnOtherPortalActivated(inst)
    log("other portal", inst, inst.components.channelable:IsChanneling(), inst.components.channelable.enabled,
        inst.components.channelable.channeler)
    if not inst.playingsound then
        inst.AnimState:PlayAnimation("turn_on")
        inst.AnimState:PushAnimation("idle_on_loop")
        inst.playingsound = true
        OnEntityWake(inst)
    end
end

local function OnAllPortalsUnlinked(inst)
    if inst.playingsound then
        inst.playingsound = nil
        inst.SoundEmitter:KillSound("active")
        inst.AnimState:PlayAnimation("turn_off")
        inst.AnimState:PushAnimation("idle_off")
    end
end
-- hack townportal
local function HackPortal(inst)
    Teleporter:Init(inst)
end
-- add writable
local function AddWritable()
    local writeables = require("writeables")
    local _1, kinds, _3 = UPVALUE.get(writeables.makescreen, "kinds")
    if not kinds then
        warn("cannot get writables.kinds")
        return
    end
    kinds.townportal = {
        prompt = lang == "zh" and "命名传送塔" or "Name Portal",
        animbank = "ui_board_5x3",
        animbuild = "ui_board_5x3",
        menuoffset = Vector3(6, -70, 0),
        cancelbtn = {text = STRINGS.BEEFALONAMING.MENU.CANCEL, cb = nil, control = CONTROL_CANCEL},
        acceptbtn = {text = STRINGS.BEEFALONAMING.MENU.ACCEPT, cb = nil, control = CONTROL_ACCEPT}
    }
end
local function AddManagerToWorld(world)
    PortalManager:Init(world)
end
local function WaitForTownportalRegistry(com)
    local inst = com.inst
    if inst then inst:DoTaskInTime(0, AddManagerToWorld) end
end
-- teleporter(server controlled)
Teleporter = {_oldlistener = nil}
function Teleporter:RemoveOldListener()
    local inst = self.inst
    if not self._oldlistener then
        local _1, oldOnLinkTownPortals, _3 = UPVALUE.fetch(ThePrefab[inst.prefab].fn, "OnLinkTownPortals")
        self._oldlistener = oldOnLinkTownPortals
    end
    local old = self._oldlistener
    if old then
        inst:RemoveEventCallback("linktownportals", old)
    else
        warn("failed to remove old link event")
    end
end
function Teleporter:CacheRegister(times)
    if TheWorld then
        if TheWorld.PortalManager then
            TheWorld.PortalManager:Register(self.inst)
        else
            TheWorld:ListenForEvent("portalmanagerconnected", function()
                TheWorld.PortalManager:Register(self.inst)
            end)
        end
    else
        if times > 0 then
            timer.itick(self.inst, function()
                self:CacheRegister(times - 1)
            end, 1)
        end
    end
end
function Teleporter:Init(inst)
    local t = {inst = inst}
    InheritClass(t, Teleporter)
    if not inst.Teleporter then
        inst.name = BeDiligent(inst.name)
        inst.Teleporter = t
        AddEventListener(inst, "onremove", function()
            t.inst = nil
        end)
        t:CacheRegister(10)
        if ISSERVER then
            t:RemoveOldListener()
            inst:ListenForEvent("activateotherportal", OnOtherPortalActivated)
            inst:ListenForEvent("allportalsunlinked", OnAllPortalsUnlinked)
            if not inst.components.writeable then inst:AddComponent("writeable") end
            t:ModifySideEffect()
            local ch = inst.components.channelable
            local startfn = ch.onchannelingfn
            local stopfn = ch.onstopchannelingfn
            ch:SetChannelingFn(function(...)
                startfn(...)
                t:OnChanneling(...)
            end, function(...)
                stopfn(...)
                t:OnStopChanneling(...)
            end)
        end
    end
end
-- side effect modify
local function StartSoundLoop(inst)
    if not inst.playingsound then
        inst.playingsound = true
        OnEntityWake(inst)
    end
end
local teleportdrain = GetConfig("sanity_teleport") or "false" == "true"
local channeldrain = GetConfig("sanity_channel")  or "true" == "true"
local touchdrain = GetConfig("sanity_touch") or "true" == "true"
local function OnStartChanneling(inst, channeler)
    inst.AnimState:PlayAnimation("turn_on")
    inst.AnimState:PushAnimation("idle_on_loop")
    StartSoundLoop(inst)
    TheWorld:PushEvent("townportalactivated", inst)

    inst.MiniMapEntity:SetIcon("townportalactive.png")
    inst.MiniMapEntity:SetPriority(20)

    if inst.icon ~= nil then
        inst.icon.MiniMapEntity:SetIcon("townportalactive.png")
        inst.icon.MiniMapEntity:SetPriority(20)
        inst.icon.MiniMapEntity:SetDrawOverFogOfWar(true)
    end

    inst.channeler = channeler.components.sanity ~= nil and channeler or nil
    if inst.channeler ~= nil then
        if touchdrain then inst.channeler.components.sanity:DoDelta(-TUNING.SANITY_MED) end
        if channeldrain then
            inst.channeler.components.sanity.externalmodifiers:SetModifier(inst, -TUNING.DAPPERNESS_SUPERHUGE)
        end
    end
end
function Teleporter:ModifySideEffect()
    -- remove sanity drain
    self.inst.components.teleporter.onActivate = function(inst, doer)
        if doer:HasTag("player") then
            if doer.components.talker ~= nil then doer.components.talker:ShutUp() end
            if doer.components.sanity ~= nil and teleportdrain then
                doer.components.sanity:DoDelta(-TUNING.SANITY_HUGE)
            end
        end
        -- #TODO: find a better way to do this
        local tp = inst.components.teleporter
        if tp:GetTarget() then
            timer.itick(inst, function()
                tp:Target()
            end, 2)
        end
        if tp.migration_data then
            timer.itick(inst, function()
                tp:MigrationTarget()
            end, 2)
        end
    end
    if channeldrain == false or touchdrain == false then
        local OnStopChanneling = self.inst.components.channelable.onstopchannelingfn
        self.inst.components.channelable:SetChannelingFn(OnStartChanneling, OnStopChanneling)
    end
end
function Teleporter:OnChanneling(inst, player)
    local ch = inst.components.channelable
    log("OnChanneling", player, ch:IsChanneling(), ch.enabled)
    TheWorld:PushEvent("activateportal", inst, player)
    if player and player.player_classified then player.player_classified._portalopen:set(true) end
end
function Teleporter:OnStopChanneling(inst, abort)
    log("Server Stop Channeling")
    TheWorld:PushEvent("townportaldeactivated", inst)
    local player = inst.components.channelable.channeler
    if player and player.player_classified then player.player_classified._portalopen:set(false) end
end
-- upped to global function
function BeDiligent(name)
    local beDiligent = {Lazy = "Diligent", lazy = "diligent", ["懒人"] = "勤奋", ["懒惰"] = "勤奋"}
    if not name then name = STRINGS.NAMES.TOWNPORTAL end
    local Diligentize = string.gsub
    for lazy, diligent in pairs(beDiligent) do name = Diligentize(name, lazy, diligent) end
    return name
end
local function AddClientPortalManager()
    if ISSERVER then return end
    if not TheWorld then return end
    if TheWorld.PortalManager then return end
    PortalManagerClient:Init(TheWorld)
end
local function HackPlayerClassified(inst)
    if not inst._portalopen then
        inst._portalopen = net_bool(inst.GUID, "_portalopen", "portalopendirty")
        inst._portalopen:set_local(false)
    end
    if HASHUD then
        inst:ListenForEvent("portalopendirty", MakeNamed(inst, "ToggleWidget"))
        function inst:ToggleWidget()
            if not inst.DiligentTraveller then
                inst.DiligentTraveller = DiligentTraveller(inst)
                inst:ListenForEvent("onremove", function()
                    inst.DiligentTraveller:Remove()
                end)
            end
            local isopen = inst._portalopen:value()
            if isopen then
                if TheWorld and TheWorld.PortalManager then
                    TheWorld.PortalManager:Sync()
                    -- activate
                    inst.DiligentTraveller:AttachTo(TheWorld.PortalManager:GetPortalForPlayer())
                end
                inst.DiligentTraveller:Open()
            else
                inst.DiligentTraveller:Close()
            end
        end
    end
end
local function HackPlayerHUD(self)
    wrapperAfter(self, "SetMainCharacter", function()
        local hud = self.controls
        if hud then
            -- force sync
            if TheWorld and TheWorld.PortalManager then TheWorld.PortalManager:Sync(true) end
        end
        -- just in case gamepostinit fails
        AddClientPortalManager()
    end)
end
local function init()
    if not IsInGame() then return end
    if RegisterMod(MYMODNAME) then return end
    STRINGS.NAMES.TOWNPORTAL = BeDiligent()
    AddWritable()
    utils.prefab("townportal", HackPortal)
    utils.require("screens/playerhud", HackPlayerHUD)
    utils.com("townportalregistry", WaitForTownportalRegistry)
    utils.prefab("player_classified", HackPlayerClassified)
    utils.sim(AddClientPortalManager)
    AddModRPCHandler(modname, "SyncPortalData", function(player, force)
        if TheWorld and TheWorld.PortalManager then TheWorld.PortalManager:Sync(force) end
    end)
    AddModRPCHandler(modname, "UseStone", function(player, guid)
        if TheWorld and TheWorld.PortalManager then TheWorld.PortalManager:UseStone(guid, player) end
    end)
    AddModRPCHandler(modname, "teleport", function(player, guid, worldid)
        if TheWorld and TheWorld.PortalManager then
            local netvar = safefetch(player, undotted("player_classified._portalopen"))
            if netvar then
                TheWorld.PortalManager:Teleport(nil, player, guid, worldid)
            else
                if player.components.talker then
                    player.components.talker:Say(GetActionFailString(player, ""))
                end
            end
        end
    end)
    AddModRPCHandler(modname, "erase", function(player, guid)
        if TheWorld and TheWorld.PortalManager then TheWorld.PortalManager:EraseName(guid) end
    end)
    AddShardModRPCHandler(modname, "SyncWorldData", function(worldid, data)
        if TheWorld and TheWorld.PortalManager then TheWorld.PortalManager:SyncOtherWorld(worldid, data) end
    end)
    theshard.createevent()
end
init()
