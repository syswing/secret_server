GLOBAL.setmetatable(
    env,
    {__index = function(a, b)
            return GLOBAL.rawget(GLOBAL, b)
        end}
)
local c = GLOBAL
local d = c.TheNet
local e = c.STRINGS
local f = c.TUNING
local g = c.Shard_IsWorldAvailable
local h = d:GetIsServer() or d:IsDedicated()
local i = d:GetIsClient()
Assets = {Asset("ATLAS", "images/picker_images.xml"), Asset("IMAGE", "images/picker_images.tex")}
modimport("scripts/strings_chs.lua")
if type(f.MWP) ~= "table" then
    f.MWP = {}
end
local function j(k)
    if type(k) ~= "table" then
        return {}
    end
    local l = {}
    for m, n in pairs(k) do
        if type(n) == "table" then
            local o = {}
            for p, q in pairs(n) do
                if type(q) ~= "table" and type(q) ~= "function" then
                    o[p] = q
                end
            end
            l[m] = o
        end
    end
    return l
end
local r = GetModConfigData("gift_toasts_offset")
local s = GetModConfigData("auto_balancing") == true
local t = GetModConfigData("force_population")
local u = GetModConfigData("no_bat") == true
local v = GetModConfigData("world_prompt") == true
local w = GetModConfigData("migration_postern") == true
local x = GetModConfigData("ignore_sinkholes") == true
local y = GetModConfigData("say_dest") == true
local z = GetModConfigData("open_button") == true
local A = GetModConfigData("name_button") == true
local B = GetModConfigData("always_show_ui") == true
local C = GetModConfigData("migrator_required") == true
local D = GetModConfigData("default_galleryful") or 0
local E = j(GetModConfigData("world_config"))
local F = {galleryful = D}
local G = 0
local H = {__index = F}
for m, n in pairs(E) do
    if type(n) == "table" then
        if n.invisible then
            G = G + 1
        end
        setmetatable(n, H)
    else
        E[m] = nil
    end
end
setmetatable(
    E,
    {__index = function(a, I)
            return F
        end}
)
E.invisible_count = G
f.MWP.WORLDS = E
local function J(K)
    if tonumber(K) == nil then
        K = TheShard:GetShardId()
    else
        K = tostring(K)
    end
    local L = E[K]
    return L.name or e.MWP.WORLD .. K
end
if i then
    local M = function(N)
        if type(N) == "table" then
            table.sort(
                N,
                function(O, P)
                    O = tonumber(O) or 0
                    P = tonumber(P) or 0
                    return O < P
                end
            )
        end
        return N
    end
    local function Q(R)
        if type(R) ~= "string" then
            return
        end
        local S = {}
        local T = {}
        local U = {}
        local V = {}
        for W, n in ipairs(R:split("|")) do
            local K, X = unpack(n:split())
            U[K] = X or 0
            table.insert(T, K)
            local Y = E[K]
            if type(Y.category) == "string" then
                local Z = V[Y.category] or {}
                table.insert(Z, K)
                V[Y.category] = Z
            end
        end
        S.counts = U
        S.worlds = M(T)
        if next(V) then
            for W, n in pairs(V) do
                M(n)
            end
            S.categories = V
        end
        return S
    end
    local function _(a0)
        local a1 = require(f.MWP.SCREEN or "screens/worldpanelscreen")
        function a0:OpenWorldPickerScreen(R)
            if self.pickworldscreen ~= nil then
                return self.pickworldscreen
            end
            self.pickworldscreen = a1(self.owner, Q(R))
            self:OpenScreenUnderPause(self.pickworldscreen)
            TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/craft_open")
            return self.pickworldscreen
        end
        function a0:CloseWorldPickerScreen()
            if self.pickworldscreen then
                self.pickworldscreen:Close()
                self.pickworldscreen = nil
            end
            SendModRPCToServer(GetModRPC("multiworldpicker", "worldpickervisibleRPC"))
        end
    end
    AddClassPostConstruct("screens/playerhud", _)
    local function a2(a3)
        local a4 = require "widgets/imagebutton"
        if A then
            a3.world_name = a3.topleft_root:AddChild(a4("images/ui.xml", "blank.tex"))
            a3.world_name:SetTextColour(233 / 255, 204 / 255, 148 / 255, 1)
            a3.world_name:SetTextFocusColour(1, 1, 1, 1)
            a3.world_name:SetFont(CHATFONT_OUTLINE)
            a3.world_name:SetDisabledFont(CHATFONT_OUTLINE)
            a3.world_name:SetTextDisabledColour(0.6, 0.6, 0.6, 1)
            a3.world_name:SetTextSize(26)
            a3.world_name:SetText(TheWorld.worldname or "??????", false, {-1, -1})
            a3.world_name.image:SetSize(a3.world_name.text:GetRegionSize())
            a3.world_name:SetPosition(90, -30, 0)
            a3.world_name:SetOnClick(
                function()
                    local a5 = GetTime()
                    if ThePlayer.world_name_just_say == nil or a5 - ThePlayer.world_name_just_say > 8 then
                        d:Say(e.MWP.I_AM_AT .. (TheWorld.worldname or "???"))
                        ThePlayer.world_name_just_say = a5
                    else
                        ThePlayer.components.talker:Say(e.MWP.HERE_IS .. (TheWorld.worldname or "???"))
                    end
                end
            )
            a3.world_name:SetHoverText(
                string.format("id: %s", TheWorld.worldid or "???"),
                {offset_y = -26, font_size = 16}
            )
        end
        if z then
            a3.black_hole =
                a3.topleft_root:AddChild(
                a4("images/picker_images.xml", "balck_hole.tex", nil, nil, nil, nil, {0.6, 0.6})
            )
            a3.black_hole:SetPosition(90, -80, 0)
            a3.black_hole:SetNormalScale(.5)
            a3.black_hole:SetFocusScale(.6)
            a3.black_hole:SetOnClick(
                function()
                    local a5 = GetTime()
                    if ThePlayer.blackhole_last_enable == nil or a5 - ThePlayer.blackhole_last_enable >= 2 then
                        SendModRPCToServer(GetModRPC("multiworldpicker", "worldpickervisibleRPC"), true)
                        ThePlayer.blackhole_last_enable = a5
                    else
                        ThePlayer.components.talker:Say(e.MWP.WHERE_TO_GO)
                    end
                end
            )
            a3.black_hole:SetHoverText(e.MWP.SELECT_WORLD, {offset_y = -36, font_size = 16})
        end
        if type(r) == "number" and r ~= 0 then
            local a6 = a3.toastlocations
            if a6 then
                local a7 = Vector3(r, 0, 0)
                for a8 = 1, #a6 do
                    a6[a8].pos = a6[a8].pos + a7
                end
            end
        end
    end
    AddClassPostConstruct("widgets/controls", a2)
end
AddClientModRPCHandler(
    "multiworldpicker",
    "showpicker",
    function(a9)
        local aa = ThePlayer
        local ab = aa and aa.HUD
        if ab ~= nil then
            if a9 == nil then
                ab:CloseWorldPickerScreen()
            else
                ab:OpenWorldPickerScreen(a9)
            end
        end
    end
)
AddClientModRPCHandler(
    "multiworldpicker",
    "syncplayercount",
    function(K, ac)
        local aa = ThePlayer
        if aa then
            aa:PushEvent("mwp_online_count_changed", {wid = K, count = ac})
            local ab = aa and aa.HUD
            if ab and ab.pickworldscreen and ab.pickworldscreen.world_data then
                ab.pickworldscreen.world_data.counts[K] = ac
            end
        end
    end
)
if A then
    local function ad(a0)
        TheWorld.worldid = a0._worldid:value()
        TheWorld.worldname = J(TheWorld.worldid)
    end
    local function ae(a0)
        local X = a0._playercount:value()
        TheWorld.playercount = X
        if ThePlayer and ThePlayer.HUD then
            local ab = ThePlayer.HUD
            if ab.controls and ab.controls.world_name then
                local af = TheWorld.worldid or 0
                local ag = tonumber(E[af].galleryful) or 0
                if ag > 0 then
                    X = X .. "/" .. ag
                end
                ab.controls.world_name:SetHoverText(
                    string.format("%s%s %s: %s", e.MWP.WORLD, af, e.MWP.PLAYER_COUNT, X)
                )
            end
        end
    end
    local ah = function(L, ac)
        local ai = L.net._playercount
        ai:set_local(ac)
        ai:set(ac)
    end
    local aj = function(a0)
        a0._worldid = net_string(a0.GUID, "mwp.worldid")
        a0._playercount = net_byte(a0.GUID, "mwp.playercount", "mwp.playercount.dirty")
        if TheWorld.ismastersim then
            local af = TheShard:GetShardId()
            a0._worldid:set_local(af)
            a0._worldid:set(af)
            TheWorld:ListenForEvent("ms_playercountchanged", ah)
        else
            a0:DoTaskInTime(0, ad)
            a0:ListenForEvent("mwp.playercount.dirty", ae)
        end
    end
    for W, ak in ipairs({"forest_network", "cave_network"}) do
        AddPrefabPostInit(ak, aj)
    end
end
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.MIGRATE, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.MIGRATE, "doshortaction"))
AddStategraphActionHandler("wilsonghost", ActionHandler(ACTIONS.MIGRATE, "haunt_pre"))
AddStategraphActionHandler("wilsonghost_client", ActionHandler(ACTIONS.MIGRATE, "haunt_pre"))
if w then
    AddComponentAction(
        "SCENE",
        "worldmigrator",
        function(a0, al, am, an)
            local ao = function()
                local a8 = 1
                while a8 <= #am do
                    if am[a8] == ACTIONS.MIGRATE then
                        table.remove(am, a8)
                        break
                    else
                        a8 = a8 + 1
                    end
                end
            end
            local ap = al:HasTag("playerghost")
            local aq = a0.prefab == "multiplayer_portal_moonrock_constr"
            local ar = a0:HasTag("resurrector")
            if ar and ap or aq and not ap then
                if an and not ap then
                    table.insert(am, ACTIONS.MIGRATE)
                else
                    ao()
                end
            end
        end
    )
    if h then
        local as = {"multiplayer_portal", "multiplayer_portal_moonrock_constr", "multiplayer_portal_moonrock"}
        local at = function(a0)
            a0:AddComponent("worldmigrator")
            a0.components.worldmigrator:SetID(0)
        end
        for W, n in ipairs(as) do
            AddPrefabPostInit(n, at)
        end
    end
end
if h then
    local function au(aa, av, ...)
        if aa.components and aa.components.talker then
            aa.components.talker:Say(av, ...)
        end
    end
    local function aw()
        local ax = {}
        local ay = TheWorld
        for W, n in ipairs(ay.ShardList) do
            local az = ay.ShardPlayerCounts[n] or 0
            if az > 0 then
                table.insert(ax, string.format("%s:%s", n, az))
            else
                table.insert(ax, n)
            end
        end
        return table.concat(ax, "|")
    end
    local function aA(aa, aB)
        local aC = aa.userid
        if aC == nil or aC == "" then
            return
        end
        aa._worldpickerportalid = aB or 0
        SendModRPCToClient(GetClientModRPC("multiworldpicker", "showpicker"), aC, aw())
    end
    local function aD(aa, aE, aF)
        local aG = {player = aa, worldid = aE}
        if type(aE) == "table" and aE.x and aE.z then
            aG.x = aE.x
            aG.y = aE.y or 0
            aG.z = aE.z
        else
            aG.portalid = tonumber(aF)
        end
        TheWorld:PushEvent("ms_playerdespawnandmigrate", aG)
    end
    local function aH(aa, aI, aJ, aK)
        if aa and aa.IsValid and aa:IsValid() then
            aI = tostring(aI)
            local aL = TheShard:GetShardId()
            if aL == aI then
                print("[MWP] migrate_to failed, trying to migrate to the same world", aI, aL, aJ)
                au(aa, e.MWP.WHERE_TO_GO)
            elseif g(aI) then
                if aK then
                    aa:DoTaskInTime(type(aK) == "number" and aK or 0, aD, aI, aJ)
                else
                    aD(aa, aI, aJ)
                end
            else
                print("[MWP] migrate_to failed, target world is not avaliable", aI)
                au(aa, e.MWP.WORLD_INVALID)
            end
        else
            print("!!![MWP] try_migrate_to failed, invalid player", aa, aI, aJ, aK)
        end
    end
    local aM = function(aa, aB)
        local aF = aa:GetPosition()
        local aN = TheSim:FindEntities(aF.x, aF.y, aF.z, 10, {"migrator"})
        for W, n in ipairs(aN) do
            local aO = n.components.worldmigrator
            if aO and (aB == true or aO:IsDestinationForPortal(nil, aB)) then
                return true, aO.id
            end
        end
    end
    AddModRPCHandler(
        "multiworldpicker",
        "worldpickervisibleRPC",
        function(aa, aP, ...)
            if aP and aa._worldpickerportalid == nil then
                local a5 = GetTime()
                if aa.mwp_last_show_wp ~= nil and a5 - aa.mwp_last_show_wp < 1 then
                    au(aa, e.MWP.WHERE_TO_GO)
                    return
                end
                local aB
                if C then
                    local aQ
                    aQ, aB = aM(aa, true)
                    if aQ ~= true then
                        au(aa, e.MWP.MIGRATOR_REQUIRED)
                        return
                    end
                end
                local aR = f.MWP.ShouldShowPicker
                if type(aR) == "function" and aR(aa, ...) ~= true then
                    return
                end
                if not B and (TheWorld.ShardList == nil or #TheWorld.ShardList < 2) then
                    print("[MWP] Cannot open world list panel without enough shards!", aa)
                    return
                end
                aA(aa, aB or 0)
                aa.mwp_last_show_wp = a5
            else
                aa._worldpickerportalid = nil
            end
        end
    )
    AddModRPCHandler(
        "multiworldpicker",
        "worldpickermigrateRPC",
        function(aa, aE, ...)
            local ay = TheWorld
            if ay == nil or ay.ShardPlayerCounts == nil then
                return
            end
            local aB = aa._worldpickerportalid
            if C and aM(aa, aB) ~= true then
                au(aa, e.MWP.MIGRATOR_REQUIRED)
                return
            end
            local aS = f.MWP.ShouldMigrate
            if type(aS) == "function" and aS(aa, aE, ...) ~= true then
                return
            end
            local aT = E[aE]
            local ac = ay.ShardPlayerCounts[aE]
            if aB and tonumber(aE) and ac then
                local ag = tonumber(aT.galleryful) or 0
                if ag > 0 and ac >= ag then
                    au(aa, e.MWP.WORLD_FULL)
                    return
                end
                local aK = 0.1
                if y then
                    aK = 1
                    au(aa, e.MWP.GOING_TO .. J(aE))
                end
                aH(aa, aE, aB, aK)
                return
            end
            au(aa, e.MWP.WORLD_INVALID)
        end
    )
    AddShardModRPCHandler(
        "multiworldpicker",
        "shardsyncplayercount",
        function(af, ac)
            local ay = TheWorld
            if ay then
                af = tostring(af)
                if ay.ShardPlayerCounts ~= nil then
                    ay.ShardPlayerCounts[af] = ac
                end
                local aU = {}
                for W, n in ipairs(AllPlayers) do
                    if n._worldpickerportalid and n.userid and n.userid ~= "" then
                        table.insert(aU, n.userid)
                    end
                end
                if #aU > 0 then
                    SendModRPCToClient(GetClientModRPC("multiworldpicker", "syncplayercount"), aU, af, ac)
                end
            end
        end
    )
    AddShardModRPCHandler(
        "multiworldpicker",
        "shardsyncplayercountALL",
        function(af, R)
            local ay = TheWorld
            if R and ay and not ay.ismastershard then
                local U = ay.ShardPlayerCounts
                if U ~= nil then
                    for W, n in ipairs(R:split("|")) do
                        local K, X = unpack(n:split())
                        X = tonumber(X) or 0
                        if K then
                            U[K] = X
                        end
                    end
                end
            end
        end
    )
    do
        local function aV(self, aW, aX)
            return self.receivedPortal == aX
        end
        local function aY(self, al, ...)
            if al == nil then
                return false
            end
            local ay = TheWorld
            if x and self.inst.prefab == "cave_entrance_open" then
                return self:_oldActivate(al, ...)
            end
            if not B then
                if ay.ShardList == nil or #ay.ShardList == 0 or #ay.ShardList + E.invisible_count < 2 then
                    return self:_oldActivate(al, ...)
                end
                if #ay.ShardList == 1 then
                    local aI = ay.ShardList[1]
                    if aI ~= nil and not E[aI].invisible then
                        aD(al, aI, self.id)
                    else
                        au(al, e.MWP.NOWHERE_TO_GO)
                    end
                    return true
                end
            end
            local a5 = GetTime()
            if al.mwp_last_show_wp == nil or a5 - al.mwp_last_show_wp >= 2 then
                al.mwp_last_show_wp = a5
                aA(al, self.id)
            else
                au(al, e.MWP.WHERE_TO_GO)
            end
            return true
        end
        AddComponentPostInit(
            "worldmigrator",
            function(aZ)
                aZ.IsDestinationForPortal = aV
                aZ._oldActivate = aZ.Activate
                aZ.Activate = aY
            end
        )
    end
    if s then
        local function a_(b0)
            local ag = tonumber(E[b0].galleryful)
            if ag < 1 then
                return true
            end
            local n = ag - (TheWorld.ShardPlayerCounts and tonumber(TheWorld.ShardPlayerCounts[b0]) or 0)
            return n > 0
        end
        local function b1()
            local b2 = TheWorld.ShardPlayerCounts
            if #AllPlayers > 1 and b2 then
                local b3 = TheShard:GetShardId()
                local af = b3
                for a8, n in ipairs(TheWorld.ShardList) do
                    if E[n].extra ~= true then
                        if b2[n] == 0 then
                            af = n
                            break
                        elseif b2[n] < b2[af] and a_(n) then
                            af = n
                        end
                    end
                end
                return af ~= b3 and af or nil
            end
            return nil
        end
        local b4 = c.SpawnNewPlayerOnServerFromSim
        c.SpawnNewPlayerOnServerFromSim = function(b5, ...)
            local aa = Ents[b5]
            if aa ~= nil then
                local aI = b1()
                if aI then
                    aH(aa, aI, nil, 0)
                end
            end
            b4(b5, ...)
        end
    end
    local b6 = function(ay, K)
        if not E[K].invisible then
            table.insert(ay.ShardList, K)
        else
            print("[MWP] this world is set to invisible:", K)
        end
    end
    local b7 = c.Shard_UpdateWorldState
    c.Shard_UpdateWorldState = function(b0, b8, b9, ba, ...)
        b7(b0, b8, b9, ba, ...)
        local ay = TheWorld
        if ay == nil then
            return
        end
        local bb = b8 == REMOTESHARDSTATE.READY
        local bc = c.ShardList or c.Shard_GetConnectedShards()
        if not bb or ay.ShardList == nil then
            ay.ShardList = {}
            for m, W in pairs(bc) do
                b6(ay, m)
            end
        else
            if table.contains(ay.ShardList, b0) then
                print("[MWP] the world was already added to TheWorld.ShardList:", b0)
            else
                b6(ay, b0)
            end
        end
        if ay.ShardPlayerCounts == nil then
            local U = {}
            U[TheShard:GetShardId()] = #AllPlayers
            for W, n in ipairs(ay.ShardList) do
                U[n] = 0
            end
            ay.ShardPlayerCounts = U
        else
            if bb then
                ay.ShardPlayerCounts[b0] = 0
            else
                ay.ShardPlayerCounts[b0] = nil
            end
        end
        if not bb and #ay.ShardList > 0 then
            for m, n in pairs(ShardPortals) do
                local aO = n.components.worldmigrator
                local bd = aO.linkedWorld
                if bd == nil or aO.auto == true or not bc[bd] then
                    c_reregisterportals()
                    break
                end
            end
        end
        if bb and ay.ismastershard then
            SendModRPCToShard(GetShardModRPC("multiworldpicker", "shardsyncplayercountALL"), b0, aw())
        end
    end
    if u then
        AddPrefabPostInit(
            "cave_entrance_open",
            function(a0)
                if a0.components.childspawner ~= nil then
                    a0.components.childspawner:SetMaxChildren(0)
                end
            end
        )
    end
    local function be(K)
        if TheWorld.ShardPlayerCounts then
            local af
            local bf = 1
            local bg
            for a8, n in ipairs(TheWorld.ShardList) do
                if n ~= K then
                    local L = E[n]
                    if L.extra ~= true then
                        local ac = TheWorld.ShardPlayerCounts[n]
                        if ac == 0 then
                            af = n
                            break
                        end
                        local bh = L.galleryful
                        if bh == 0 then
                            bg = n
                            bh = 12
                        end
                        local bi = TheWorld.ShardPlayerCounts[n] / bh
                        if bi < bf then
                            af = n
                            bf = bi
                        end
                    end
                end
            end
            return af or bg
        end
    end
    AddSimPostInit(
        function()
            local ay = TheWorld
            local function bj()
                local ac = #AllPlayers
                SendModRPCToShard(GetShardModRPC("multiworldpicker", "shardsyncplayercount"), nil, ac)
                ay.playercount = ac
                ay:PushEvent("ms_playercountchanged", ac)
            end
            ay:ListenForEvent("ms_playerspawn", bj)
            ay:ListenForEvent("ms_playerleft", bj)
            if v then
                local function bk(bl, aa)
                    if aa == nil or not aa:IsValid() then
                        return
                    end
                    aa:DoTaskInTime(1, au, e.MWP.HERE_IS .. J())
                end
                ay:ListenForEvent("ms_playerspawn", bk)
            end
            if t then
                ay:ListenForEvent(
                    "ms_playerspawn",
                    function(L, aa)
                        if aa.Network:IsServerAdmin() then
                            return
                        end
                        local K = TheShard:GetShardId()
                        local bm = #AllPlayers
                        local bh = type(t) == "number" and t or E[K].galleryful
                        if bh > 0 and bm > bh then
                            local bn = be(K)
                            if bn then
                                aa:DoTaskInTime(3.5, au, e.MWP.EXCEED_LIMIT_GOTO .. J(bn))
                                aH(aa, bn, nil, 5)
                            end
                        end
                    end
                )
            end
        end
    )
    c.mwp_shards = function()
        local bo
        for a8, n in ipairs(TheWorld.ShardList) do
            bo = E[n].name or e.MWP.WORLD .. n
            print(string.format("%d)\t%s\t%s", a8, n, bo))
        end
        print("Total Shards:", #TheWorld.ShardList)
    end
    c.mwp_counts = function()
        local ag, bo, L
        print("ShardPlayerCounts:")
        for m, n in pairs(TheWorld.ShardPlayerCounts) do
            L = E[m]
            ag = tonumber(L.galleryful)
            bo = L.name or e.MWP.WORLD .. m
            print(string.format("%d/%d\t%s\t[%s]", n, ag, bo, m))
        end
    end
    c.mwp_this = function()
        local af = TheShard:GetShardId()
        local L = E[af]
        local bo = L.name or e.MWP.WORLD .. af
        local ag = tonumber(L.galleryful)
        local ac = TheWorld.ShardPlayerCounts[af] or 0
        print(string.format("[%s] {@} (%d/%d) %s", af, ac, ag, bo))
    end
    c.mwp_list = function()
        local bp = {}
        local ag, bo, ac, bq, L
        for m, W in pairs(Shard_GetConnectedShards()) do
            L = E[m]
            ag = tonumber(L.galleryful)
            bo = L.name or e.MWP.WORLD .. m
            ac = TheWorld.ShardPlayerCounts[m] or 0
            if L.invisible then
                bq = "*"
            elseif L.extra then
                bq = "^"
            else
                bq = " "
            end
            table.insert(bp, {id = m, char = bq, count = ac, max = ag, name = bo})
        end
        local af = TheShard:GetShardId()
        L = E[af]
        bo = L.name or e.MWP.WORLD .. af
        ag = tonumber(L.galleryful)
        ac = TheWorld.ShardPlayerCounts[af] or 0
        table.insert(bp, {id = af, char = "@", count = ac, max = ag, name = bo})
        table.sort(
            bp,
            function(O, P)
                return tonumber(O.id) < tonumber(P.id)
            end
        )
        print("All Worlds:")
        for W, n in ipairs(bp) do
            print(string.format("[%s] {%s} (%d/%d) %s", n.id, n.char, n.count, n.max, n.name))
        end
        print("Total:", #bp)
    end
    c.mwp_migrate = function(aa, K, aF)
        if type(aa) == "string" or type(aa) == "number" then
            aa = UserToPlayer(aa)
        end
        if K == nil then
            K = 0
        end
        if type(aa) == "table" and type(K) == "number" then
            aD(aa, K, aF)
        end
    end
    c.mwp_getdest = function()
        return be(TheShard:GetShardId())
    end
else
    local br = function()
    end
    AddModRPCHandler("multiworldpicker", "worldpickervisibleRPC", br)
    AddModRPCHandler("multiworldpicker", "worldpickermigrateRPC", br)
    AddShardModRPCHandler("multiworldpicker", "shardsyncplayercount", br)
    AddShardModRPCHandler("multiworldpicker", "shardsyncplayercountALL", br)
end
