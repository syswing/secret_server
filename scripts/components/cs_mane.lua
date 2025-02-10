-- 为人物添加经济系统
local Mane = Class(function(self,inst)
  self.mane = 0
end,nil,{})

function Mane:AddMane(mane)
  self.mane = self.mane + mane
end

function Mane:SetMane(mane)
  self.mane = mane
end

return Mane
