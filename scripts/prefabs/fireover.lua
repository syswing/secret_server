local function PushFireOverlay(inst, target)
	if target.components.health ~= nil then
		target.components.health:DoFireDamage(0, nil, true)
	end
end

local function OnAttached(inst, target, symbol, offset, time)
	if not inst.components.timer:TimerExists("fireover") then
		inst.components.timer:StartTimer("fireover", time or 1)
	end
	inst:DoPeriodicTask(0, PushFireOverlay, nil, target)
	PushFireOverlay(inst, target)
end

local function OnExtended(inst, target, symbol, offset, time)
	inst.components.timer:SetTimeLeft("fireover", time or 1)
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()

	inst:AddTag("CLASSIFIED")

	inst:AddComponent("debuff")
	inst.components.debuff:SetAttachedFn(OnAttached)
	inst.components.debuff:SetExtendedFn(OnExtended)
	inst.components.debuff:SetDetachedFn(inst.Remove)

	inst:AddComponent("timer")
	inst:ListenForEvent("timerdone", inst.Remove)

	inst.persists = false

	return inst
end

return Prefab("fireover", fn)