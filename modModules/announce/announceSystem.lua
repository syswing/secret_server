local announce_list = {
	glommer = {
		death = function(inst) 
			TheNet:Announce ("〖 "..inst:GetDisplayName().." 〗被杀死了，可恶啊！")
		end,
		startfollowing = function(inst)
			TheNet:Announce("〖 "..inst:GetDisplayName().." 〗出现了，快去领回家")
		end
	},
	walrus = {
		death = function(inst) 
			TheNet:Announce("〖 "..inst:GetDisplayName().." 〗被【 "..data.attacker:GetDisplayName().." 】击杀")
		end,
	},
	spat = {
		death = function(inst) 
			TheNet:Announce("〖 "..inst:GetDisplayName().." 〗被【 "..data.attacker:GetDisplayName().." 】击杀")
		end,
	},
	beequeen = {
		death = function(inst) 
			TheNet:Announce("〖 "..inst:GetDisplayName().." 〗被【 "..data.attacker:GetDisplayName().." 】击杀")
		end
	},
	dragonfly = {
		death = function(inst) 
			TheNet:Announce("〖 "..inst:GetDisplayName().." 〗被【 "..data.attacker:GetDisplayName().." 】击杀")
		end
	}
}


