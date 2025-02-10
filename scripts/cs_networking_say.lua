
local offcial_networking_say = _G.Networking_Say
GLOBAL.Networking_Say = function(guid, userid, name, prefab, message, colour, whisper, isemote)
	local lower_msg = string.lower(message)
	local talker = Ents[guid]
	if(lower_msg == '#gift') then
		talker:PushEvent("ms_closepopups")
		talker:ShowPopUp(POPUPS.GIFTITEM, true)
		talker.components.giftreceiver:OnStartOpenGift()
		talker:PushEvent("ms_closepopups")
	end

	local words = {}
	for word in string.gmatch(message, "%S+") do
		table.insert(words, word) --分词
	end

	

	return offcial_networking_say(guid, userid, name, prefab, message, colour, whisper, isemote)
end
 