-- 升级组件
local MAX_LEVEL = 600
local START_LEVEL_EXP = 100
-- local 
local LevelSystem = Class(function(self,inst)
	self.inst = inst 
	self.current_exp = 0
	self.current_level = 0
end)

function LevelSystem:UpLevel()
	if(self.current_level < 600)
		return self.current_level++
	end
end

function LevelSystem:GetLevel()
	return self.current_level
end

function LevelSystem:GetExp()
	return self.current_exp
end

function LevelSystem:AddExp(exp)
	return self.current_exp += exp
end

function LevelSystem:OnUpdate(dt)

end


return LevelSystem