local containers = require "containers"
local params = containers.params

params.researchlab = {
  widget = {
    slotpos = {
      Vector3(0, 64 + 32 + 8 + 4, 0),
      Vector3(0, 32 + 4, 0),
      Vector3(0, -(32 + 4), 0),
      Vector3(0, -(64 + 32 + 8 + 4), 0)
    },
    slotbg = {
      {atlas = "images/hud.xml", image = "equip_slot.tex"}
    },
    animbank = "ui_cookpot_1x4",
    animbuild = "ui_cookpot_1x4",
    pos = Vector3(150, 0, 0),
    side_align_tip = 100,
    buttoninfo = {
      position = Vector3(0, -165, 0),
      text = "测试",
      fn = function(inst)
        print("测试按下按钮")
        print(inst)
      end
    }
  },
  type = "chest",
  itemtestfn = function(container, item, slot) -- 测试是否能放入科技
    print("测试")
    return not (item:HasTag("irreplaceable") or item:HasTag("bundle") or item:HasTag("nobundling"))
  end
}

AddPrefabPostInit(
  "researchlab",
  function(inst)
    inst:AddComponent("container")
    inst.components.container:WidgetSetup(inst.prefab)
  end
)

params.researchlab2 = {
  widget = {
    slotpos = {
      Vector3(0, 64 + 32 + 8 + 4, 0),
      Vector3(0, 32 + 4, 0),
      Vector3(0, -(32 + 4), 0),
      Vector3(0, -(64 + 32 + 8 + 4), 0)
    },
    slotbg = {
      {atlas = "images/hud.xml", image = "equip_slot_body.tex"}
    },
    animbank = "ui_cookpot_1x4",
    animbuild = "ui_cookpot_1x4",
    pos = Vector3(150, 0, 0),
    side_align_tip = 100,
    buttoninfo = {
      position = Vector3(0, -165, 0),
      text = "测试",
      fn = function(inst)
        print("测试按下按钮")
        print(inst)
      end
    }
  },
  type = "chest",
  itemtestfn = function(container, item, slot) -- 测试是否能放入科技
    print("测试")
    return not (item:HasTag("irreplaceable") or item:HasTag("bundle") or item:HasTag("nobundling"))
  end
}

AddPrefabPostInit(
  "researchlab2",
  function(inst)
    inst:AddComponent("container")
    inst.components.container:WidgetSetup(inst.prefab)
  end
)

params.researchlab4 = {
  widget = {
    slotpos = {
      Vector3(0, 64 + 32 + 8 + 4, 0),
      Vector3(0, 32 + 4, 0),
      Vector3(0, -(32 + 4), 0),
      Vector3(0, -(64 + 32 + 8 + 4), 0)
    },
    slotbg = {
      {atlas = "images/hud.xml", image = "equip_slot_head.tex"}
    },
    animbank = "ui_cookpot_1x4",
    animbuild = "ui_cookpot_1x4",
    pos = Vector3(150, 0, 0),
    side_align_tip = 100,
    buttoninfo = {
      position = Vector3(0, -165, 0),
      text = "测试",
      fn = function(inst)
        print("测试按下按钮")
        print(inst)
      end
    }
  },
  type = "chest",
  itemtestfn = function(container, item, slot) -- 测试是否能放入科技
    print("测试")
    return not (item:HasTag("irreplaceable") or item:HasTag("bundle") or item:HasTag("nobundling"))
  end
}


AddPrefabPostInit(
  "researchlab4",
  function(inst)
    inst:AddComponent("container")
    inst.components.container:WidgetSetup(inst.prefab)
  end
)
