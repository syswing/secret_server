-- 升级组件
local MAX_LEVEL = 600
local START_LEVEL_EXP = 450
local LEVEL_INCREASE = 150

local LevelSystem =
  Class(
  function(self, inst)
    self.inst = inst
    self.current_exp = 0
    self.current_level = 0
    self.start_level_exp = START_LEVEL_EXP -- level up exp
    self.max_level = MAX_LEVEL -- max

    local playerName = inst:GetDisplayName()
    local label = inst.entity:AddLabel()

    inst:ListenForEvent(
      "oneat",
      function(inst, data)
        local food = data.food
        if (food.components.perishable) then
          local foodExp =
            food.components.edible.hungervalue + food.components.edible.healthvalue + food.components.edible.sanityvalue
          self:AddExp(math.floor(foodExp < 0 and 0 or foodExp))
        end
      end
    )
    inst:ListenForEvent(
      "killed",
      function(inst, data)
        if (data.victim.components) then
          print('killed:'..data.victim.components.health.maxhealth)
          self:AddExp(math.floor(data.victim.components.health.maxhealth))
        end
      end
    )
  end,
  nil,
  {}
)

function LevelSystem:UpLevel()
  local targetLevel = self:GetLevelWithExp(self.current_exp)
  if (targetLevel > self.max_level) then
    targetLevel = self.max_level
  end
  if (targetLevel - self.current_level == 0) then
    return
  end
  self.inst.Label:SetFont(DEFAULTFONT)
  self.inst.Label:SetWorldOffset(0, .2, 0)
  self.inst.Label:SetColour(1, 0.5, 0, 1)
  self.inst.Label:SetFontSize(14)
  self.inst.Label:SetText(
    "人物升级：" ..
      tostring(self.current_level) ..
        "->" ..
          targetLevel ..
            "\n" ..
              "总经验：" ..
                tostring(self.current_exp) ..
                  "\n" ..
                    "饱腹值：" ..
                      tostring(self.inst.components.hunger.max) ..
                        "->" ..
                          self.inst.components.hunger.max + 1 * (targetLevel - self.current_level) ..
                            "\n" ..
                              "生命值：" ..
                                tostring(self.inst.components.health.maxhealth) ..
                                  "->" .. self.inst.components.health.maxhealth + 1 * (targetLevel - self.current_level)
  )
  self.inst.components.health.maxhealth = self.inst.components.health.maxhealth + 1 * (targetLevel - self.current_level)
  self.inst.components.health:ForceUpdateHUD(true)
  self.inst.components.hunger.max = self.inst.components.hunger.max + 1 * (targetLevel - self.current_level)
  self.current_level = targetLevel
  self.inst.Label:Enable(true)
  self.inst.SoundEmitter:PlaySound("dontstarve/characters/wx78/levelup")
  TheWorld:DoTaskInTime(
    10,
    function()
      self.inst.Label:Enable(false)
    end
  )
end

-- 根据总经验返回当前等级
function LevelSystem:GetLevelWithExp(exp)
  local a = LEVEL_INCREASE
  local a1 = START_LEVEL_EXP
  local Sn = exp or 0
  local b = 2 * a1 - a
  local c = -2 * Sn

  local discriminant = b ^ 2 - 4 * a * c
  if discriminant < 0 then
    return nil -- 无解
  else
    local sqrt_discriminant = math.sqrt(discriminant)
    local n1 = (-b + sqrt_discriminant) / (2 * a)
    local n2 = (-b - sqrt_discriminant) / (2 * a)
    return math.floor(n1)
  end
end

function LevelSystem:GetLevel()
  return self.current_level
end

function LevelSystem:GetExp()
  return self.current_exp
end

function LevelSystem:AddExp(exp)
  self.current_exp = self.current_exp + exp
  self.inst.Label:SetFont(DEFAULTFONT)
  self.inst.Label:SetWorldOffset(0, 2, 0)
  
  self.inst.Label:SetColour(1, 0.5, 0, 1)
  self.inst.Label:SetFontSize(14)
  local targetLevel = self:GetLevelWithExp(self.current_exp)
  if (targetLevel > self.current_level) then
    self:UpLevel()
  end
  local s_target = START_LEVEL_EXP + (targetLevel) * LEVEL_INCREASE
  local current_level_exp = self.current_exp - targetLevel / 2 * (START_LEVEL_EXP + s_target)  
  print('击杀信息：'..targetLevel..'/'..self.current_exp..'/'..START_LEVEL_EXP..'/'..s_target) -- 23/49028/450/3900	
  self.inst.Label:SetText("经验增加：" .. exp .. "\n" .. "升级经验：" .. current_level_exp .. "/" .. s_target)
  self.inst.Label:Enable(true)
  TheWorld:DoTaskInTime(
    10,
    function()
      self.inst.Label:Enable(false)
    end
  )
end

function LevelSystem:DecreaseExp(exp)
  self.current_exp = self.current_exp - exp < 0 and 0 or self.current_exp - exp
end

function LevelSystem:Reset()
  self.current_exp = 0
  self.current_level = 0
end

function LevelSystem:OnSave()
  return {
    current_exp = self.current_exp,
    current_level = self.current_level
  }
end

function LevelSystem:OnLoad(onSaveData)
  if onSaveData.current_exp then
    self.current_exp = onSaveData.current_exp
  end
  if onSaveData.current_level then
    self.current_level = onSaveData.current_level
  end
  self.inst.components.health.maxhealth = self.inst.components.health.maxhealth + onSaveData.current_level
  self.inst.components.hunger.max = self.inst.components.hunger.max + onSaveData.current_level
end

return LevelSystem
