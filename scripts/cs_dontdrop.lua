local _G = GLOBAL
local R_diao = GetModConfigData("rendiao") or 0
local B_diao = GetModConfigData("baodiao") or 0
local amu_diao = GetModConfigData("amudiao") or false
local zhuang_bei = GetModConfigData("zbdiao") or false
local modnillots = GetModConfigData("nillots") or 1
local R_d = R_diao - 3
local B_d = B_diao - 5
if R_d < 0 then R_d = 0 end if B_d < 0 then B_d = 0 end

AddComponentPostInit("inventory", function(Inventory, inst)
	Inventory.oldDropEverythingFn = Inventory.DropEverything
	function Inventory:PlayerSiWang(ondeath) 
		if zhuang_bei then
			for k, v in pairs(self.equipslots) do
				if not v:HasTag("backpack") then
					self:DropItem(v, true, true)
				end
			end
		end
	end

	function Inventory:DropEverything(ondeath, keepequip)
		if not inst:HasTag("player") or inst:HasTag("player") and not inst.components.health  --不是玩家或玩家有血则掉落全部物品
		    or inst:HasTag("player") and inst.components.health and inst.components.health.currenthealth > 0 then --兼容换人
			return Inventory:oldDropEverythingFn(ondeath, keepequip)
		else
			return Inventory:PlayerSiWang(ondeath)
		end
	end
end)