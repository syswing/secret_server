local cs_boss = {
  "minotaur",         --守护者1  12
  "deerclops",        --雪巨鹿2  8
  "bearger",          --比尔熊3  12
  "dragonfly",        --龙蜻蜓4  15
  "moose",            --鹿角鹅5  6
  "klaus",            --克劳斯6
  "toadstool",        --毒蟾蜍7
  "beequeen",         --蜂王后8
  "antlion",          --夏蚁狮9
  "malbatross",       --邪天翁10
}
for k,v in pairs(cs_boss) do
  AddPrefabPostInit(v, function (inst)
    inst:ListenForEvent(
      "death", 
      function(inst)
        inst:ListenForEvent("attacked", function (inst,data)
          if(data.attacker:HasTag("player")) then 
            TheNet:Announce("玩家:".. "【"..data.attacker:GetDisplayName().."】".."成功击杀〖"..inst:GetDisplayName().."〗")
          end
        end)
      end
    )
  end)
end

