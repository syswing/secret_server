
-- 多层世界选择
modimport "entries/world_split/modmain.lua"                       
-- 等级系统
modimport "scripts/cs_init_level.lua"															
-- 玩家说话模块  -- 后期需制作活跃检测
modimport "scripts/cs_networking_say.lua"                         
-- 公告系统
modimport "scripts/cs_announce.lua"                               
-- 懒人火炉
modimport "scripts/cs_lan_furance.lua"													  
-- 物品展示信息
modimport "scripts/cs_widgets_hoverer.lua"                        
-- 科学机器重写
modimport "scripts/cs_researchlab.lua"                        
modimport "scripts/cs_showme.lua"
-- 传送塔传送
modimport("scripts/DiligentDeserter_apis.lua") 
utils.mod({"DiligentDeserter_uiapis.lua", "DiligentDeserter_moduleapis.lua", "DiligentDeserter_entityapis.lua", "DiligentDeserter.lua"})
-- 死亡不掉落
modimport("scripts/cs_dontdrop.lua") 
-- 权限

modimport("scripts/cs_lock.lua") 
