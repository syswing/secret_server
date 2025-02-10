-- 常用mod移植
cs_lan_furance
-- 666155465 show me
-- 378160973 全局定位
-- 2861217966 传送塔传送
-- 1115709310 简单经济学
-- 631648169 击杀公告
-- 661253977 死亡不掉落
-- 1714227968 防熊锁
-- 世界地图创建系统
-- 怪物强化系统
-- 武器附魔系统 、装备融合系统 （核心）
-- 1.prefab 添加多功能工具
-- 2.1本第一格放置多功能工具 后面三个可融合工具胶囊
-- 3.二本第一格放置
-- 一本 工具融合 斧子 铲子 锤子 50级开启 提取工具胶囊 
-- 二本 护甲可融合背包 100级开启 
-- 魔法一本 武器可融合工具护符 200级开启
-- 魔法二本 武器融合武器 护甲融合护甲 250级开启
-- 1.给物品上框 2.改造1本科技 3.给工具附魔
-- for k, v in pairs(handlers) do
--   handlers[k] = nil
-- end
-- ThePlayer:PushEvent("ms_closepopups")
-- ThePlayer:ShowActions(false)
-- ThePlayer:ShowPopUp(POPUPS.GIFTITEM, true)
-- ThePlayer.components.giftreceiver:OpenNextGift()
-- if inst.components.giftreceiver ~= nil then
--     inst.components.giftreceiver:OnStartOpenGift()
-- end
-- theplayer.components.giftreceiver:OpenNextGift() 开礼物 需要二本
-- [00:06:21]: edible	table: 00000000B9A0F710	 食物属性
-- [00:06:21]: bait	table: 00000000B4CC7610	bait 组件使物品可以作为诱饵吸引生物
-- [00:06:21]: tradable	table: 00000000B4CC8650	交易
-- [00:06:21]: perishable	table: 00000000B4CC6490	perishable 组件用于控制物品的腐烂行为
-- [00:06:21]: hauntable	table: 00000000B4CC6940
-- [00:06:21]: floater	table: 00000000B9A03EB0
-- [00:06:21]: burnable	table: 00000000B4CC5680
-- [00:06:21]: inventoryitem	table: 00000000B4CC4960	inventoryitem 组件是用来控制物品在角色背包中的行为的。这个组件使物品可以被放入角色的背包
-- [00:06:21]: propagator	table: 00000000B4CC6E40
-- [00:06:21]: stackable	table: 00000000B4CC5E50
-- [00:06:21]: inspectable	table: 00000000B9A0EC70	检查
-- [00:06:21]: inventoryitemmoisture	table: 00000000B4CC4500	湿度
-- [00:07:26]: Could not find anim [death] in bank [ghost]
-- inst:AddComponent("tool")
-- 	if TUNING.XIANGRIKUI_CHOP then
-- 	inst.components.tool:SetAction(ACTIONS.CHOP) --可砍树
-- 	6

-- 	if TUNING.XIANGRIKUI_MINE then
-- 	inst.components.tool:SetAction(ACTIONS.MINE) --可挖矿
-- 	end

-- 	if TUNING.XIANGRIKUI_DIG then
-- 	inst.components.tool:SetAction(ACTIONS.DIG) --可铲子
-- 	end

-- 	if TUNING.XIANGRIKUI_NET then
-- 	inst.components.tool:SetAction(ACTIONS.NET) --可网兜
-- 	end

-- 	if TUNING.XIANGRIKUI_HAMMER then
-- 	inst.components.tool:SetAction(ACTIONS.HAMMER) --可锤子
-- 	end
-- function print_lua_table(lua_table, indent)
--     indent = indent or 0
--     for k, v in pairs(lua_table) do
--         if type(k) == "string" then
--             k = string.format("%q", k)
--         end
--         local szSuffix = ""
--         if type(v) == "table" then
--             szSuffix = "{"
--         end
--         local szPrefix = string.rep("	", indent)
--         formatting = szPrefix .. "[" .. tostring(k) .. "]" .. " = " .. szSuffix
--         if type(v) == "table" then
--             print(formatting)
--             print_lua_table(v, indent + 1)
--             print(szPrefix .. "},")
--         else
--             local szValue = ""
--             if type(v) == "string" then
--                 szValue = string.format("%q", v)
--             else
--                 szValue = tostring(v)
--             end
--             print(formatting .. szValue .. ",")
--         end
--     end
-- end


笔记

tex 和 xml 更新后 需重启游戏才会重新载入assets


-- print("OnBuild:")
-- for k, v in pairs(prod.components) do
--    print(k, v)
--  end
-- print("OnBuild:")
-- print("----------target--------")
-- for k, v in pairs(getmetatable(target)) do
--   print(k, v)
-- end
-- print("----------target--------")

-- print("OnBuild:"..tostring((prod and (not prod.components.inventoryitem or prod.components.container))))
--  for k, v in pairs(prod.components) do
--     print(k, v)
--   end
-- print("OnBuild:")