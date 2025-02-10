-- 管理人物玛内
AddPlayerPostInit(
  function(inst)
    if not inst.components.cs_mane then
      inst:AddComponent("cs_mane")
    end
  end
)
TheSim:SetDebugPhysicsRenderEnabled(true)
-- ui添加入口
