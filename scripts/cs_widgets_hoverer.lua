
Assets = {
	Asset("ATLAS", "images/nineslice_bg_normal.xml"),
	Asset("IMAGE", "images/nineslice_bg_normal.tex")
}

local NineSlice = require "widgets/nineslice"
local MARGIN = 2 --边距
local MARGIN_OUT = 10 --到屏幕边缘的距离

local function GetSourceString(inst)
	local prefab = _G.Prefabs[inst.prefab]
	if prefab then
			local info = debug.getinfo(prefab.fn, "S")
			return info.source
	end
	return ""
end

local function GetBuild(inst)
	local strnn = ""
	local str = inst.entity:GetDebugString()

	if not str then
		return nil
	end
	local bank, build, anim = str:match("bank: (.+) build: (.+) anim: .+:(.+) Frame")

	if bank ~= nil and build ~= nil then
		strnn = strnn .. "动画: anim/" .. bank .. ".zip"
		strnn = strnn .. "\n" .. "贴图: anim/" .. build .. ".zip"
		if inst.AnimState then
			strnn = strnn .. "\nFacing: " .. tostring(inst.AnimState:GetCurrentFacing())
		end
	end
	return strnn
end
local function GetHovererVertex(self)
	local top, right, left, bottom = 0, 0, 0, 0
	if self.text.shown then
		local w1, h1 = self.text:GetRegionSize()
		local pos1 = self.text:GetPosition()
		top = h1 / 2 + pos1.y
		bottom = pos1.y - h1 / 2
		right = pos1.x + w1 / 2
		left = pos1.x - w1 / 2
	end
	if self.secondarytext.shown then
		local w2, h2 = self.secondarytext:GetRegionSize()
		local pos2 = self.secondarytext:GetPosition()
		top = math.max(top, h2 / 2 + pos2.y)
		bottom = math.min(bottom, pos2.y - h2 / 2)
		right = math.max(right, pos2.x + w2 / 2)
		left = math.min(left, pos2.x - w2 / 2)
	end

	return top, right, left, bottom
end

AddClassPostConstruct(
	"widgets/hoverer",
	function(self)
		local offcial_set_string = self.text.SetString
		self.text.SetString = function(text, str)
			local target = TheInput:GetHUDEntityUnderMouse()
			if target ~= nil then
				target = target.widget ~= nil and target.widget.parent ~= nil and target.widget.parent.item
			else
				target = TheInput:GetWorldEntityUnderMouse()
			end
			-- for k, v in pairs(target) do
			-- 	print('SetString'..'k:'..k..'v:'..v)
			-- end
			-- print_lua_table(target,3)
			if target and target.entity ~= nil then
				if target.prefab ~= nil then
					str = str .. "\nPrefab名:" .. target.prefab
				end
				local build = GetBuild(target)
				if build ~= nil then
					str = str .. "\n" .. build
				end
				str = str .. "\n文件路径:" .. GetSourceString(target)
			end
			return offcial_set_string(text, str)
		end

		self.UpdateBG = function(self)
			if (self.text.shown or self.secondarytext.shown) then
				local top, right, left, bottom = GetHovererVertex(self)
				local pos = {x = (left + right) / 2, y = (top + bottom) / 2}
				local w = right - left + MARGIN * 2
				local h = top - bottom + MARGIN * 2
				self.bg:SetSize(w, h)
				self.bg:SetPosition(pos.x, pos.y)
				self.bg:Show()
			else
				self.bg:Hide()
			end
		end

		self.UpdatePosition = function(self, x, y)
			local scale = self:GetScale()
			local scr_w, scr_h = TheSim:GetScreenSize()
			local top, right, left, bottom = GetHovererVertex(self)
			self:SetPosition(
				math.clamp(x, (math.abs(left) + MARGIN_OUT) * scale.x, scr_w - (right + MARGIN_OUT) * scale.x),
				math.clamp(y, (math.abs(bottom) + MARGIN_OUT) * scale.y, scr_h - (top + MARGIN_OUT) * scale.y)
			)
		end

		local offcial_on_update = self.OnUpdate
		self.OnUpdate = function(self)
			offcial_on_update(self)
			self:UpdateBG()
		end

		self.bg = self:AddChild(NineSlice("images/nineslice_bg_normal.xml"))
		self.text:SetSize(20)
		self.secondarytext:SetSize(20)
		self.bg:MoveToBack()
		self:UpdateBG()
	end
)
