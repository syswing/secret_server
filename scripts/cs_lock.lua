--保存所有玩家的集合
local AllPlayers = {}
--保存当前获取到的玩家列表_非player集合
local AllClientPlayers = {}

-- 判断权限`
function CheckPermission(ownerlist, guest, isForer)
  -- 关闭权限验证且是玩家的行为则直接返回true 2020.02.19
  if permission_mode == false and guest:HasTag("player") then
    return true
  end
  -- 目标没有权限直接返回true
  if ownerlist == nil or ownerlist.master == nil then
    return true
  end
  local guestId = type(guest) == "string" and guest or (guest and guest.userid or nil)
  -- 主人为自己时直接返回true
  if
    guestId and
      (ownerlist.master == guestId or CheckFriend(ownerlist.master, guestId) or (isForer and ownerlist.forer == guestId))
   then
    return true
  end

  return false
end

-- 判断物品权限
function CheckItemPermission(player, target)
  -- 主机直接返回true
  -- if _G.TheWorld.ismastersim == false then
  --   return true
  -- end
  -- -- 玩家不存在或目标不存在直接返回true
  -- if player == nil or target == nil then
  --   return true
  -- end
  -- 管理员直接返回true
  -- if player.Network and player.Network:IsServerAdmin() then
  --   return true
  -- end
  if target.ownerList ~= nil and tablelength(target.ownerList) > 0 then
    --主人为自己时直接返回true
    if
      player.userid and
        (target.ownerlist.master == player.userid or CheckFriend(target.ownerlist.master, player.userid) or
          target.ownerlist.forer == player.userid)
     then
      return true
    end

    -- 有权限则返回true
    if CheckPermission(target.ownerlist, player, isForer) then
      return true
    end
  end

  return false
end

-- 检查是否为朋友
function CheckFriend(masterId, guestId)
  -- if type(master) == "string" then
  -- 	master = GetPlayerById(master)
  -- end
  -- return master and master.friends[guestId]
  if masterId == nil or guestId == nil then
    return false
  end

  -- _G.TheWorld.guard_authorization ~= nil and _G.TheWorld.guard_authorization[masterId] ~= nil
  --return _G.TheWorld.guard_authorization[masterId].friends and _G.TheWorld.guard_authorization[masterId].friends[guestId]
  return _G.TheWorld.guard_authorization ~= nil and _G.TheWorld.guard_authorization[masterId] ~= nil and
    _G.TheWorld.guard_authorization[masterId].friends and
    _G.TheWorld.guard_authorization[masterId].friends[guestId]
end

function hasPermission(player, target)
  -- -- 主机直接返回true
  -- if TheWorld.ismastersim == false then
  --   return true
  -- end
  -- -- 玩家不存在或目标不存在直接返回true
  -- if player == nil or target == nil then
  --   return true
  -- end
  -- -- 管理员直接返回true
  -- if player.Network and player.Network:IsServerAdmin() then
  --   return true
  -- end

  if target.ownerList ~= nil and tablelength(target.ownerList) > 0 then
    --主人为自己时直接返回true
    if
      player.userid and
        (target.ownerlist.master == player.userid or CheckFriend(target.ownerlist.master, player.userid) or
          target.ownerlist.forer == player.userid)
     then
      return true
    end
  end

  return false
end

--通过id获取玩家索引
function GetPlayerIndex(userid)
  RefreshPlayers()
  for n, p in pairs(AllPlayers) do
    if userid == p.userid then
      return n
    end
  end
  return ""
end

--防止玩家打开别人的容器
-- "minotaurchest" -- 大号华丽箱子
AddComponentPostInit(
  "container",
  function(Container, target)
    local offcial_open_container = Container.Open
    function Container:Open(player)
      if target.prefab == "cookpot" or target.prefab == "minotaurchest" then
        return offcial_open_container(self, player)
      elseif player:HasTag("player") and target.owner == player.userid then
        return offcial_open_container(self, player)
      else
        player.components.talker:Say("我需要权限才能打开！", 2.5)
      end
    end
  end
)

AddPlayerPostInit(
  function(player)
    if player.components.builder ~= nil then
      local offcial_build = player.components.builder.onBuild
      player.components.builder.onBuild = function(doer, prod)
        if offcial_build ~= nil then
          offcial_build(doer, prod)
        end
        if prod and (not prod.components.inventoryitem or prod.components.container) then
          if prod.components.named == nil and not prod:HasTag("player") then
            prod:AddComponent("named")
          end
          prod.components.named:SetName((prod.name or "") .. "\n" .. "所有者：" .. player.name)
          prod.owner = player.userid
          prod.ownerName = player.name
        end
      end
    end
  end
)

function RefreshPlayers()
  AllPlayers = {}
  AllClientPlayers = {}
  local isStandalone = TheNet:GetServerIsClientHosted()
  local clientObjs = TheNet:GetClientTable()
  if type(clientObjs) == "table" then
    local index = 1
    for i, v in ipairs(clientObjs) do
      if isStandalone or v.performance == nil then
        -- print(string.format("%s[%d] (%s) %s <%s>", v.admin and "*" or " ", index, v.userid, v.name, v.prefab))
        -- if _G.TheWorld.guard_authorization[v.userid] == nil then
        -- 	_G.TheWorld.guard_authorization[v.userid] = {}
        -- end
        -- _G.TheWorld.guard_authorization[v.userid].name = v.name

        AllPlayers[index] = AllPlayersForKeyUserID[v.userid]
        AllClientPlayers[index] = v
        index = index + 1
      end
    end
  end
end

AddPrefabPostInit(
  "world",
  function(inst)
    inst.cs_authorization = {}
    inst.OnSave = function(inst, data)
      if inst.cs_authorization then
        data.cs_authorization = inst.cs_authorization
      end
    end

    local offcial_OnLoad = inst.OnLoad
    inst.OnLoad = function(inst, data)
      if data.cs_authorization then
        inst.cs_authorization = data.cs_authorization
      end
    end
    
    inst:ListenForEvent(
      "ms_gd_playerjoined",
      function(inst, data)
        inst.cs_authorization[data.userid] = {}
      end
    )

    --监听玩家离开游戏(leave_game)
    inst:ListenForEvent(
      "ms_gd_playerleft",
      function(inst, data)
        inst.cs_authorization[data.userid] = nil
      end
    )
  end
)

AddPrefabPostInit(
  "shard_network",
  function(inst)
    inst:AddComponent("gd_shard_playerchange")
  end
)

-- local prefab = type(inst) == "string" and inst or inst.prefab

local container_permission = {
  "icebox",
  -- 冰箱
  "treasurechest",
  --木箱
  "saltbox",
  -- 盐盒
  "dragonflychest",
  -- 龙鳞宝箱
  "piggyback",
  -- 猪猪包
  "icepack",
  -- 保鲜背包
  "backpack",
  -- 背包
  "krampus_sack"
  -- 坎普斯背包
}

for k, v in pairs(container_permission) do
  local prefab = type(v) == "string" and v or v.prefab
  AddPrefabPostInit(
    prefab,
    function(inst)
      --
      local offcial_on_save = inst.OnSave
      inst.OnSave = function(inst, data)
        if offcial_on_save ~= nil then
          offcial_on_save(inst, data)
        end
        if inst.owner ~= nil and inst.ownerName then
          data.owner = inst.owner
          data.ownerName = inst.ownerName
        end
      end
      --
      local offcial_on_load = inst.OnLoad
      inst.OnLoad = function(inst, data)
        if offcial_on_load ~= nil then
          offcial_on_load(inst, data)
        end

        if data.owner ~= nil and data.ownerName then
          inst.owner = data.owner
          inst.ownerName = data.ownerName

          if inst.components.named == nil and not inst:HasTag("player") then
            inst:AddComponent("named")
          end
          inst.components.named:SetName((inst.name or "") .. "\n" .. "所有者：" .. data.ownerName)
        end
      end
      -- canlight
      if inst:HasTag("canlight") then
        inst.canlight = true
        inst:RemoveTag("canlight")
      end
      if inst:HasTag("nolight") then
        inst.nolight = true
      else
        inst:AddTag("nolight")
      end
    end
  )
end

AddComponentPostInit(
  "workable",
  function(workable)
    workable.offcial_WorkedBy_Internal = workable.WorkedBy_Internal
    workable.WorkedBy_Internal = function(self, worker, numworks, ...)
      local old_WorkedBy_Internal = self.offcial_WorkedBy_Internal
      local inst_prefab = self.inst.prefab
      local workaction = self.inst.components.workable:GetWorkAction()
      -- print('workable:'..workaction)
      if workaction ~= nil and workaction == GLOBAL.ACTIONS.HAMMER then
        if table.contains(container_permission, inst_prefab or "") and self.inst.owner ~= worker.userid then
          if worker:HasTag("player") then
            worker.components.talker:Say("我需要权限才能打开！", 2.5)
          end
          return
        else
          old_WorkedBy_Internal(self, worker, numworks, ...)
        end
      else
        old_WorkedBy_Internal(self, worker, numworks, ...)
      end
    end
  end
)

---防止炸药炸毁建筑---
AddComponentPostInit(
  "explosive",
  function(explosive, inst)
    inst.buildingdamage = 0
    explosive.CurrentOnBurnt = explosive.OnBurnt
    function explosive:OnBurnt()
      local x, y, z = inst.Transform:GetWorldPosition()
      local ents2 = _G.TheSim:FindEntities(x, y, z, 3)
      local nearbyStructure = false
      for k, v in ipairs(ents2) do
        if v.components.burnable ~= nil and not v.components.burnable:IsBurning() then
          if v:HasTag("structure") then
            nearbyStructure = true
          end
        end
      end
      --
      if nearbyStructure then --Make sure structures aren't lit on fire (indirectly) from explosives
        inst:RemoveTag("canlight")
      else
        inst:AddTag("canlight")
        explosive:CurrentOnBurnt()
      end
    end
  end
)

-- 火焰传播
local MakeSmallPropagator = GLOBAL.MakeSmallPropagator
GLOBAL.MakeSmallPropagator = function(inst, ...)
  local propagator = MakeSmallPropagator(inst, ...)
  if propagator then
    propagator.propagaterange = 0
  end
  return propagator
end
