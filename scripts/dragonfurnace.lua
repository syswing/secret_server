AddPrefab("dragonfurnace_projectile")

AddEffect("dragonflyfurnace_smoke_fx",
{
	bank = "lavaarena_creature_teleport_smoke_fx",
	build = "lavaarena_creature_teleport_smoke_fx",
	anim = function() return "smoke_" .. math.random(2) end,
	fn = function(inst)
		local scale = inst.AnimState:IsCurrentAnimation("smoke_1") and 0.75 or 0.65
		inst.AnimState:SetScale(scale, scale)
	end,
})

function AllContainers.dragonflyfurnace.widget.buttoninfo.fn(inst, doer)
	if inst.components.container ~= nil then
		for i, v in ipairs(inst.components.container:GetOpeners()) do
			if v ~= doer then
				inst.components.container:Close(v)
			end
		end
		inst.components.container:Close(doer)
	elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
		SendRPCToServer(RPC.DoWidgetButtonAction, nil, inst)
	end
end

AllContainers.dragonflyfurnace.widget.buttoninfo.text = STRINGS.ACTIONS.LIGHT

AddComponentAction("USEITEM", "cookable", function(inst, doer, target, actions, right)
	if right and target:HasTag("cooker") and target:HasTag("furnace") then
		RemoveByValue(actions, ACTIONS.COOK)
	end
end)

--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
if not TheNet:GetIsServer() then return end --\\\\\\\\\\\\\\\\\\\\\\\\\\\\
--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

AddPrefab("fireover")

TUNING.DRAGONFURNACE_VOMIT_DELAY = 0.5

if AnimState.GetBloomEffectHandle ~= nil then
	Tykvesh.Error("GetBloomEffectHandle already exists!")
else
	local _bloomeffecthandles = setmetatable({}, { __mode = "k" })

	Tykvesh.Parallel(AnimState, "SetBloomEffectHandle", function(self, bloom)
		_bloomeffecthandles[self] = bloom
	end)

	Tykvesh.Parallel(AnimState, "ClearBloomEffectHandle", function(self)
		_bloomeffecthandles[self] = nil
	end)

	function AnimState:GetBloomEffectHandle()
		return _bloomeffecthandles[self]
	end
end

local function OnOpen(inst)
	inst:RemoveComponent("cooker")

	inst._lightrad = inst.Light:GetRadius()
	inst.Light:SetRadius(0.85)
	inst.AnimState:PlayAnimation("idle", true)
	inst.SoundEmitter:KillSound("loop")
	inst.SoundEmitter:PlaySound("dontstarve/common/fireOut")
	inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/vomitrumble", "rumble", 0.75)
end

local function DropLoot(inst, loot, target)
	local hasloot, hasproduct, pt

	for item, fn in pairs(loot) do
		if type(fn) == "function" and item:IsValid() then
			pcall(fn)
		end
	end

	for item in pairs(loot) do
		if item:IsValid() then
			hasloot = true
			if not item:HasTag("ashes") then
				hasproduct = true
				break
			end
		end
	end

	if hasloot then
		if hasproduct and inst ~= target and target:IsValid() then
			pt = target:GetPosition()
		else
			pt = inst:GetPosition() + Vector3FromTheta(math.random() * PI2, 3)
		end
		SpawnPrefab("dragonflyfurnace_projectile"):LaunchProjectile(loot, pt, inst, target)
	end
end

local function AddHiddenChild(inst, child, target)
	if target ~= nil then
		child.Network:SetClassifiedTarget(target)
	end
	if inst ~= child.parent then
		inst:AddChild(child)
	end
	if not child:IsInLimbo() then
		child:ForceOutOfLimbo()
		child:RemoveFromScene()
	end
end

local function OnClose(inst, doer)
	local loot = {}

	for slot, item in pairs(inst.components.container.slots) do
		inst.components.container:RemoveItemBySlot(slot)

		local product, vomitfn
		local pcallqueue = {}

		if item.components.cookable ~= nil then
			product = FunctionOrValue(item.components.cookable.product, item, inst, doer)
			if item.components.cookable.oncooked ~= nil then
				table.insert(pcallqueue, function() item.components.cookable.oncooked(item, inst, doer) end)
			end
		elseif item.components.temperature == nil and not item:HasTag("indestructible") then
			if item.components.explosive == nil then
				product = item:HasTag("charcoalsource") and "charcoal" or "ash"
			end
			if item.components.burnable ~= nil then
				item.components.burnable.burning = true
				table.insert(pcallqueue, function() item:PushEvent("onignite", { doer = doer }) end)
				if item.components.burnable.onignite ~= nil then
					table.insert(pcallqueue, function() item.components.burnable.onignite(item, inst, doer) end)
				end
				if item.components.burnable.onburnt ~= DefaultBurntFn then
					vomitfn = function() item.components.burnable:LongUpdate(0) end
				end
			end
		end

		product = product and SpawnPrefab(product)
		if product ~= nil then
			if product.components.perishable ~= nil and item.components.perishable ~= nil and not item:HasTag("smallcreature") then
				product.components.perishable:SetPercent(1 - (1 - item.components.perishable:GetPercent()) * 0.5)
			end
			if product.components.stackable ~= nil and item.components.stackable ~= nil then
				local stacksize = item.components.stackable:StackSize() * product.components.stackable:StackSize()
				product.components.stackable:SetStackSize(stacksize)
			end
		end

		if next(pcallqueue) ~= nil then
			item:DoTaskInTime(0, function(item)
				for i, fn in ipairs(pcallqueue) do
					if not (pcall(fn) and item:IsValid()) then
						break
					end
				end
			end)
			if vomitfn == nil and product ~= nil then
				item:DoTaskInTime(TUNING.DRAGONFURNACE_VOMIT_DELAY, item.Remove)
			end
			AddHiddenChild(inst, item, doer)
		elseif vomitfn ~= nil then
			AddHiddenChild(inst, item, doer)
		elseif product ~= nil then
			item:Remove()
		end

		local item = product or item
		if item.components.inventoryitem ~= nil then
			item.components.inventoryitem:InheritMoisture(0, false)
		end
		if item.components.temperature ~= nil then
			item.components.temperature:SetTemperature(item.components.temperature:GetMax())
		end
		AddHiddenChild(inst, item)

		loot[item] = vomitfn or false
	end
	inst.components.container.canbeopened = false

	if inst.components.cooker == nil then
		inst:AddComponent("cooker")
	end
	if inst._lightrad ~= nil then
		inst.Light:SetRadius(inst._lightrad)
	end
	inst.SoundEmitter:KillSound("rumble")
	inst.SoundEmitter:PlaySound("dontstarve/common/together/dragonfly_furnace/fire_LP", "loop")

	if next(loot) == nil then
		inst.AnimState:PlayAnimation("hi_pre")
		inst.AnimState:PushAnimation("hi")
		inst.SoundEmitter:PlaySound("dontstarve/common/together/dragonfly_furnace/light")
	else
		inst.AnimState:PlayAnimation("incinerate")
		inst.AnimState:PushAnimation("hi")
		inst.SoundEmitter:PlaySound("qol1/dragonfly_furnace/incinerate")
		inst:DoTaskInTime(TUNING.DRAGONFURNACE_VOMIT_DELAY, DropLoot, loot, doer)
	end
end

local function OnAnimOver(inst)
	inst.components.container.canbeopened = true
end

local function GetStatus(inst, observer)
	return not inst.components.container:IsOpen() and "HIGH" or nil
end

local function GetHeat(inst, observer)
	return not inst.components.container:IsOpen() and inst.components.heater.heat or 0
end

local function OnLoad(inst, data)
	inst.components.container:DropEverything()
end

AddPrefabPostInit("dragonflyfurnace", function(inst)
	inst:AddTag("furnace")
	inst:RemoveComponent("incinerator")

	inst.components.container.onopenfn = OnOpen
	inst.components.container.onclosefn = OnClose

	inst.components.inspectable.getstatus = GetStatus
	inst.components.heater.heatfn = GetHeat

	inst:ListenForEvent("animover", OnAnimOver)
	Tykvesh.Parallel(inst, "OnLoad", OnLoad)
end)

--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

local CHARCOAL_SOURCES = { "log", "livinglog", "driftwood_log" }

local function MakeCharcoalSource(inst)
	inst:AddTag("charcoalsource")
end

for index, prefab in ipairs(CHARCOAL_SOURCES) do
	AddPrefabPostInit(prefab, MakeCharcoalSource)
end

AddPrefabPostInit("winter_food4", function(inst)
	inst:AddTag("indestructible")
end)