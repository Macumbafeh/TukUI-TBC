--local parent, ns = ...
local parent = debugstack():match[[\AddOns\(.-)\]] -- parent part of the local parent, ns = ...
local global = GetAddOnMetadata(parent, 'X-oUF')
assert(global, 'X-oUF needs to be defined in the parent add-on.')
local oUF = _G[global]
--local oUF = ns.oUF 

local Update = function(self, event)
	local unit = self.unit
	if(UnitInRaid(unit) and UnitIsRaidOfficer(unit) and not UnitIsPartyLeader(unit)) then
		self.Assistant:Show()
	else
		self.Assistant:Hide()
	end
end

local Enable = function(self)
	local assistant = self.Assistant
	if(assistant) then
		self:RegisterEvent("PARTY_MEMBERS_CHANGED", assistant.Update or Update)

		if(assistant:IsObjectType"Texture" and not assistant:GetTexture()) then
			assistant:SetTexture[[Interface\GroupFrame\UI-Group-AssistantIcon]]
		end

		return true
	end
end

local Disable = function(self)
	local assistant = self.Assistant
	if(assistant) then
		self:UnregisterEvent("PARTY_MEMBERS_CHANGED", assistant.Update or Update)
	end
end

oUF:AddElement('Assistant', Update, Enable, Disable)
