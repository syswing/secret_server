local Text = require "widgets/text"
local Widget = require "widgets/widget"

AddPlayerPostInit(
  function(inst)
    if not inst.components.current_exp then
      inst:AddComponent("cs_level")
    end
  end
)
