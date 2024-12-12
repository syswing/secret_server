local assets =
{
	Asset("ANIM", "anim/firefighter_projectile.zip"),
}

local prefabs =
{
	"dragonflyfurnace_smoke_fx",
}

local function OnHit(inst)
	local pos = inst:GetPosition()
	local leftovers = {}
	local hascaught = false
	local target = inst.components.complexprojectile.owningweapon
	local canpickup = (target ~= nil and target:IsValid())
		and (target.components.inventory ~= nil and target.components.inventory:IsOpenedBy(target))
		and (target.sg:HasStateTag("idle") and target:IsNear(inst, 0.5))

	for slot, item in pairs(inst.components.inventory.itemslots) do
		if canpickup and not item:HasTag("ashes") then
			hascaught = true
			if not target.components.inventory:GiveItem(item, nil, pos) then
				table.insert(leftovers, item)
			end
		else
			table.insert(leftovers, item)
		end
	end

	for num, item in ipairs(leftovers) do
		inst.components.inventory:DropItem(item, true, true, pos)
		item.components.inventoryitem:DoDropPhysics(pos.x, -0.75, pos.z, true, num == 1 and 0.3 or 0.6)
		if item.components.bloomer == nil and item.AnimState:GetBloomEffectHandle() then
			item:AddComponent("bloomer")
			item.components.bloomer:PushBloom(item, item.AnimState:GetBloomEffectHandle(), -999)
		end
		SpawnPrefab("deerclops_laserhit"):SetTarget(item)
	end

	if hascaught then
		target:AddDebuff(inst.prefab, "fireover", 5 * FRAMES)
		target:PushEvent("burnt")
		target.sg:GoToState("item_hat")
		target.sg:AddStateTag("notalking")
	else
		if inst:IsOnPassablePoint() then
			SpawnPrefab("deerclops_laserscorch").Transform:SetPosition(pos.x, 0, pos.z)
		end
		if leftovers[1] ~= nil then
			leftovers[1]:SpawnChild("dragonflyfurnace_smoke_fx")
		end
	end

	inst:Remove()
end

local function LaunchProjectile(inst, loot, pt, source, target)
	for item in pairs(loot) do
		inst.components.inventory:GiveItem(item)
		while item.components.stackable ~= nil and item.components.stackable:IsFull() do
			local other = item.components.stackable:Get(item.components.stackable.maxsize)
			if other ~= item then
				inst.components.inventory:GiveItem(other)
			else
				break
			end
		end
	end

	local scale = Remap(inst.components.inventory:NumItems(), 1, 3, 1, 1.4)
	inst.AnimState:SetScale(scale, scale)
	inst.Transform:SetFromProxy(source.GUID)
	inst.components.complexprojectile:Launch(pt, source, target)
end

local function OnLoad(inst, data)
	inst.components.inventory:DropEverything()
	inst:DoTaskInTime(0, inst.Remove)
end

local function OnFireFXDirty(inst)
	local firefx = inst._firefx:value()
	firefx._light.Light:SetRadius(0.3)
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddPhysics()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst.Physics:SetMass(1)
	inst.Physics:SetFriction(0)
	inst.Physics:SetDamping(0)
	inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
	inst.Physics:ClearCollisionMask()
	inst.Physics:CollidesWith(COLLISION.GROUND)
	inst.Physics:SetCapsule(0, 0)
	inst.Physics:SetDontRemoveOnSleep(true)

	inst.AnimState:OverrideShade(0.15)
	inst.AnimState:SetLightOverride(0.4)
	inst.AnimState:SetAddColour(1, 0, 0, 1)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetBank("firefighter_projectile")
	inst.AnimState:SetBuild("firefighter_projectile")
	inst.AnimState:PlayAnimation("spin_loop", true)

	inst:AddTag("NOCLICK")
	inst:AddTag("projectile")

	inst._firefx = net_entity(inst.GUID, "dragonflyfurnace_projectile._firefx", "firefxdirty")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("firefxdirty", OnFireFXDirty)

		return inst
	end

	inst.firefx = inst:SpawnChild("torchfire_rag")
	inst.firefx.SoundEmitter:SetMute(true)
	inst.firefx._light.Light:SetRadius(0.3)
	inst._firefx:set(inst.firefx)

	inst:AddComponent("complexprojectile")
	inst.components.complexprojectile:SetHorizontalSpeed(6)
	inst.components.complexprojectile:SetGravity(-25)
	inst.components.complexprojectile:SetLaunchOffset(Point(0, 0.5))
	inst.components.complexprojectile:SetOnHit(OnHit)

	inst:AddComponent("inventory")

	inst.LaunchProjectile = LaunchProjectile
	inst.OnLoad = OnLoad

	return inst
end

return Prefab("dragonflyfurnace_projectile", fn, assets, prefabs)