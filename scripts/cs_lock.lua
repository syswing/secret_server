--保存所有玩家的集合
local AllPlayers = {}
--保存当前获取到的玩家列表_非player集合
local AllClientPlayers = {}

-- 判断权限
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
AddComponentPostInit(
  "container",
  function(Container, target)
    local offcial_open_container = Container.Open
    function Container:Open(player)
      -- 有权限时直接处理
      print("----------doer--------")
      for k, v in pairs(getmetatable(player)) do
        print(k, v)
      end
      print("----------doer--------")
      if hasPermission(player, target) or target.prefab == "cookpot" then
        return offcial_open_container(self, player)
      elseif player:HasTag("player") then
        local doer_num = GetPlayerIndex(player.userid)
        local master = target.ownerList and GetPlayerById(target.ownerList.master) or nil
        if master ~= nil then
          -- 有所有者
          player.components.talker:Say("我需要权限才能打开！", 2.5)
        else
          -- 玩家不在线
          player.components.talker:Say("我需要权限才能打开！", 2.5)
        end
      end
    end
  end
)

-- 重写玩家建造方法
AddPlayerPostInit(
  function(player)
    if player.components.builder ~= nil then
      -- 建造新的物品，为每个建造的新物品都添加权限
      local old_onBuild = player.components.builder.onBuild
      player.components.builder.onBuild = function(doer, prod)
        testActPrint(nil, doer, prod, "OnBuild", "建造")
        local permission_state = _G.TheWorld.guard_authorization[doer.userid].permission_state

        if old_onBuild ~= nil then
          old_onBuild(doer, prod)
        end

        -- 仓库物品除了背包以外都不需要加Tag
        if
          prod and (not prod.components.inventoryitem or prod.components.container) and
            (permission_state == false or (near_no_permission and IsNearPublicEnt(doer.build_pos)))
         then
          SetOwnerName(prod, doer.userid, false)
        elseif prod and (not prod.components.inventoryitem or prod.components.container) then
          SetItemPermission(prod, doer)
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
        if test_mode then
          print(string.format("%s[%d] (%s) %s <%s>", v.admin and "*" or " ", index, v.userid, v.name, v.prefab))
        end
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
