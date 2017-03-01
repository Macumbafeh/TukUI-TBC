-- local parent, ns = ...
--local oUF = ns.oUF

local parent = debugstack():match[[\AddOns\(.-)\]] -- parent part of the local parent, ns = ...
local global = GetAddOnMetadata(parent, 'X-oUF')
assert(global, 'X-oUF needs to be defined in the parent add-on.')
local oUF = _G[global]


local VISIBLE = 1
local HIDDEN = 0

local getPlayerAuraDuration = function(isBuff, key, providedRank)
	local duration
	for i = 1, 40 do
		local name, rank, time
		name, rank = GetPlayerBuffName(i)
		--ChatFrame1:AddMessage(tostring(rank))
		if not name then
			break
		end
		if name == key and providedRank == rank then
			buffKeyIndex = GetPlayerBuff(i)
			duration = GetPlayerBuffTimeLeft(buffKeyIndex)
			break
		end
	end
	-- ChatFrame1:AddMessage(tostring(duration) .. ' - returned playerbuff duration')
	return duration
end

--  name, rank, iconTexture, count, duration, timeLeft =  UnitBuff(unit, buffIndex[, castable]);
--  name, rank, iconTexture, count, debuffType, duration, timeLeft  =  UnitDebuff(unitID, debuffIndex [, removable]);
-- 	name, rank, texture, count, dtype, duration, timeLeft, caster, isStealable, shouldConsolidate, spellID = UnitAura(unit, index, filter)
local UnitAura = function(unit, index, filter)
	-- Skal merges så den kan returnerer et korrekt format som kan forståes af wotlk koden	
	-- ChatFrame1:AddMessage('oUF-Auras-Costum-UnitAura: ' .. unit .. ', index: ' .. tostring(index) .. ', filter: ' .. tostring(filter))
	if(filter == 'HELPFUL') then
		local name, rank, texture, count, duration,timeleft = UnitBuff(unit,index)
		if(unit == 'player' or UnitIsPlayer(unit)) then
			if(timeleft == nil) then
				timeleft = getPlayerAuraDuration(true,name,rank)				
				-- ChatFrame1:AddMessage(tostring(timeleft))
			end		
		end
		-- ChatFrame1:AddMessage('name: ' .. tostring(name) .. ', duartion: ' .. tostring(duartion) .. ', timeleft: ' .. tostring(timeleft) .. ', unit: ' .. tostring(unit))
		return name, rank, texture, count, nil, duration, timeleft, nil, nil, nil, nil
	elseif filter == 'HARMFUL' then
		local name, rank, texture, count, dtype, duration, timeleft = UnitDebuff(unit,index)
		if(unit == 'player' or UnitIsPlayer(unit)) then
			if(timeleft == nil) then
				timeleft = getPlayerAuraDuration(true,name,rank)
			end
		end
		-- ChatFrame1:AddMessage('name: ' .. tostring(name) .. ', duartion: ' .. tostring(duartion) .. ', timeleft: ' .. tostring(timeleft) .. ', unit: ' .. tostring(unit))
		return name, rank, texture, count, dtype, duration, timeleft, nil, nil, nil, nil
	end
	return false
end

local GetUnitAuraPlayerBuffID = function(filter, id)
	local Uname, Urank = UnitAura('player',id,filter)
	local buffName, buffRank
	local res
	for i=1,40 do
		buffName, buffRank = GetPlayerBuffName(i)
		if not Uname then
			break;
		end
		if Uname == buffName and Urank == buffRank then
			res = i;
			break;
		end		
	end
	--ChatFrame1:AddMessage('Was searching for: ' .. Uname .. ', found: ' .. buffName)
	return res;
end

local UpdateTooltip = function(self)
	--GameTooltip:SetUnitAura(self.parent:GetParent().unit, self:GetID(), self.filter)
	local unit = self.parent:GetParent().unit
	if tostring(self.filter) == 'HELPFUL' then
		if(unit == 'player' or UnitName("Player") == UnitName(unit) ) then
			--ChatFrame1:AddMessage(unit)
			local pID = GetUnitAuraPlayerBuffID('HELPFUL',self:GetID())
			GameTooltip:SetPlayerBuff(pID)
		else
			GameTooltip:SetUnitBuff(unit, self:GetID(), self.filter)
		end
	else
		if(unit == 'player' or UnitName("Player") == UnitName(unit)) then
			local pID = GetUnitAuraPlayerBuffID('HARMFUL',self:GetID())
			GameTooltip:SetPlayerBuff(pID)
		else
			GameTooltip:SetUnitDebuff(unit, self:GetID(), self.filter)
		end		
	end	
end

local OnEnter = function(self)
	if(not self:IsVisible()) then return end

	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
	self:UpdateTooltip()
end

local OnLeave = function()
	GameTooltip:Hide()
end

-- We don't really need to validate much here as the filter should prevent us
-- from doing something we shouldn't.
local OnClick = function(self)
	--ChatFrame1:AddMessage(tostring(self:GetID()) .. ' -' .. tostring( GetPlayerBuff(self:GetID(), self.filter) ))
	CancelPlayerBuff(GetUnitAuraPlayerBuffID('HELPFUL',self:GetID()))
end

local createAuraIcon = function(icons, index)
	--ChatFrame1:AddMessage('CREATE AURA ICON, oUF-base-Element')
	local button = CreateFrame("Button", nil, icons)
	button:EnableMouse(true)
	button:RegisterForClicks'RightButtonUp'

	button:SetWidth(icons.size or 16)
	button:SetHeight(icons.size or 16)

	local cd = CreateFrame("Cooldown", nil, button)
	cd:SetAllPoints(button)

	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetAllPoints(button)

	local count = button:CreateFontString(nil, "OVERLAY")
	count:SetFontObject(NumberFontNormal)
	count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 0)

	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetTexture"Interface\\Buttons\\UI-Debuff-Overlays"
	overlay:SetAllPoints(button)
	overlay:SetTexCoord(.296875, .5703125, 0, .515625)
	button.overlay = overlay

	local stealable = button:CreateTexture(nil, 'OVERLAY')
	stealable:SetTexture[[Interface\TargetingFrame\UI-TargetingFrame-Stealable]]
	stealable:SetPoint('TOPLEFT', -3, 3)
	stealable:SetPoint('BOTTOMRIGHT', 3, -3)
	stealable:SetBlendMode'ADD'
	button.stealable = stealable

	button.UpdateTooltip= UpdateTooltip
	button:SetScript("OnEnter", OnEnter)
	button:SetScript("OnLeave", OnLeave)

	local unit = icons:GetParent().unit
	if(unit == 'player') then
		button:SetScript('OnClick', OnClick)
	end

	table.insert(icons, button)

	button.parent = icons
	button.icon = icon
	button.count = count
	button.cd = cd

	if(icons.PostCreateIcon) then icons:PostCreateIcon(button) end

	return button
end

local customFilter = function(icons, unit, icon, name, rank, texture, count, dtype, duration, timeLeft, caster)
	local isPlayer	

	if caster == 'player' then
		isPlayer = true
	end

	if((icons.onlyShowPlayer and isPlayer) or (not icons.onlyShowPlayer and name)) then
		icon.isPlayer = isPlayer
		icon.owner = caster
		return true
	end
end

local updateIcon = function(unit, icons, index, offset, filter, isDebuff, max)
	local name, rank, texture, count, dtype, duration, timeLeft, caster, isStealable, shouldConsolidate, spellID = UnitAura(unit, index, filter)	
	if(name) then				
		local icon = icons[index + offset]
		if(not icon) then
			icon = (icons.CreateIcon or createAuraIcon) (icons, index)
		end

		--local show = (icons.CustomFilter or customFilter) (icons, unit, icon, name, rank, texture, count, dtype, duration, timeLeft, caster, isStealable, shouldConsolidate, spellID)
		local show = (icons.CustomFilter or customFilter) (icons, unit, icon, name, rank, texture, count, dtype, duration, timeLeft)
		if(show) then			
			-- We might want to consider delaying the creation of an actual cooldown
			-- object to this point, but I think that will just make things needlessly
			-- complicated.
			local cd = icon.cd
			--ChatFrame1:AddMessage('icon.cd: ' .. tostring(cd) .. ', icons.disableCooldown: ' .. tostring(icons.disableCooldown) .. ', duration: ' .. tostring(duration))
			if(cd and not icons.disableCooldown) then				
				-- ChatFrame1:AddMessage('updateIcon: ' .. unit .. ' - ' .. index .. ' - ' .. tostring(duration))
				if(timeleft and timleft > 0) then					
					local finishTime = GetTime() + timeLeft
					--ChatFrame1:AddMessage(tostring(finishTime) .. ' - ' .. tostring(duration))
					icon.duration = timeleft;
					cd:SetCooldown(finishTime - duration, duration)					
				else
					cd:Hide()
				end
			end

			if((isDebuff and icons.showDebuffType) or (not isDebuff and icons.showBuffType) or icons.showType) then
				local color = DebuffTypeColor[dtype] or DebuffTypeColor.none

				icon.overlay:SetVertexColor(color.r, color.g, color.b)
				icon.overlay:Show()
			else
				icon.overlay:Hide()
			end

			-- XXX: Avoid popping errors on layouts without icon.stealable.
			if(icon.stealable) then
				local stealable = not isDebuff and isStealable
				if(stealable and icons.showStealableBuffs and not UnitIsUnit('player', unit)) then
					icon.stealable:Show()
				else
					icon.stealable:Hide()
				end
			end

			icon.icon:SetTexture(texture)
			icon.count:SetText((count > 1 and count))

			icon.filter = filter
			--icon.debuff = isDebuff
			icon.debuff = tostring(filter) == 'HARMFUL'

			icon:SetID(index)
			icon:Show()

			if(icons.PostUpdateIcon) then
				icons:PostUpdateIcon(unit, icon, index, offset)
			end

			return VISIBLE
		else
			-- Hide the icon in-case we are in the middle of the stack.
			icon:Hide()

			return HIDDEN
		end
	end
end

local SetPosition = function(icons, x)
	if(icons and x > 0) then
		local col = 0
		local row = 0
		local gap = icons.gap
		local sizex = (icons.size or 16) + (icons['spacing-x'] or icons.spacing or 0)
		local sizey = (icons.size or 16) + (icons['spacing-y'] or icons.spacing or 0)
		local anchor = icons.initialAnchor or "BOTTOMLEFT"
		local growthx = (icons["growth-x"] == "LEFT" and -1) or 1
		local growthy = (icons["growth-y"] == "DOWN" and -1) or 1
		local cols = math.floor(icons:GetWidth() / sizex + .5)
		local rows = math.floor(icons:GetHeight() / sizey + .5)

		for i = 1, #icons do
			local button = icons[i]
			if(button and button:IsShown()) then
				if(gap and button.debuff) then
					if(col > 0) then
						col = col + 1
					end

					gap = false
				end

				if(col >= cols) then
					col = 0
					row = row + 1
				end
				button:ClearAllPoints()
				button:SetPoint(anchor, icons, anchor, col * sizex * growthx, row * sizey * growthy)

				col = col + 1
			elseif(not button) then
				break
			end
		end
	end
end

local filterIcons = function(unit, icons, filter, limit, isDebuff, offset, dontHide)
	--ChatFrame1:AddMessage('oUF-Auras-filterIcons: ' .. unit .. ' - ' .. tostring(isDebuff))
	if(not offset) then offset = 0 end
	local index = 1
	local visible = 0
	while(visible < limit) do	
		--ChatFrame1:AddMessage("oUF-Auras-filterIcons: call to update")	
		local result = updateIcon(unit, icons, index, offset, filter, isDebuff)
		if(not result) then
			break
		elseif(result == VISIBLE) then
			visible = visible + 1
		end
		index = index + 1
	end

	if(not dontHide) then
		for i = offset + index, #icons do
			icons[i]:Hide()
		end
	end

	return visible, index - 1
end

local Update = function(self, event, unit)	
	--ChatFrame1:AddMessage('Update: ' .. tostring(event) .. ', unit: ' .. tostring(unit) .. ', self.unit: ' .. tostring(self.unit))
	if(self.unit ~= unit) then return end	
	local auras = self.Auras
	if(auras) then
		--ChatFrame1:AddMessage('Attempt to setup auras-oUF auras')
		if(auras.PreUpdate) then auras:PreUpdate(unit) end

		local numBuffs = auras.numBuffs or 32
		local numDebuffs = auras.numDebuffs or 40
		local max = numBuffs + numDebuffs

		--local visibleBuffs, offset = filterIcons(unit, auras, auras.buffFilter or auras.filter or 'HELPFUL', numBuffs, nil,  0, true)
		local visibleBuffs, offset = filterIcons(unit, auras, 'HELPFUL', numBuffs, nil,  0, true)
		auras.visibleBuffs = visibleBuffs

		--auras.visibleDebuffs = filterIcons(unit, auras, auras.debuffFilter or auras.filter or 'HARMFUL', numDebuffs,true,  offset)
		auras.visibleDebuffs = filterIcons(unit, auras, 'HARMFUL', numDebuffs,true,  offset)
		auras.visibleAuras = auras.visibleBuffs + auras.visibleDebuffs

		if(auras.PreSetPosition) then auras:PreSetPosition(max) end
		(auras.SetPosition or SetPosition) (auras, max)

		if(auras.PostUpdate) then auras:PostUpdate(unit) end
	end

	local buffs = self.Buffs
	if(buffs) then
		--ChatFrame1:AddMessage('Attempt to setup oUF-Auras, buffs')
		if(buffs.PreUpdate) then buffs:PreUpdate(unit) end

		local numBuffs = buffs.num or 32
		--buffs.visibleBuffs = filterIcons(unit, buffs, buffs.filter or 'HELPFUL', numBuffs)
		buffs.visibleBuffs = filterIcons(unit, buffs,'HELPFUL', numBuffs)

		if(buffs.PreSetPosition) then buffs:PreSetPosition(numBuffs) end
		(buffs.SetPosition or SetPosition) (buffs, numBuffs)

		if(buffs.PostUpdate) then buffs:PostUpdate(unit) end
	end

	local debuffs = self.Debuffs
	if(debuffs) then
		if(debuffs.PreUpdate) then debuffs:PreUpdate(unit) end

		local numDebuffs = debuffs.num or 40
		--debuffs.visibleDebuffs = filterIcons(unit, debuffs, debuffs.filter or 'HARMFUL', numDebuffs, true)
		debuffs.visibleDebuffs = filterIcons(unit, debuffs,'HARMFUL', numDebuffs, true)

		if(debuffs.PreSetPosition) then debuffs:PreSetPosition(numDebuffs) end
		(debuffs.SetPosition or SetPosition) (debuffs, numDebuffs)

		if(debuffs.PostUpdate) then debuffs:PostUpdate(unit) end
	end
end
--self, timestamp,event,surceGUID,sourceName,sourceFlags,destGUID,destName,destFlags,spellID
local UpdateFromCombatLog = function(self, event, timestamp, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellID)		
	if eventType == "SPELL_AURA_REFRESH" then
		if destName == UnitName(self.unit) then
			--ChatFrame1:AddMessage('COMBATLOG: timestamp: ' .. tostring(timestamp) .. ', eventType: ' .. tostring(eventType) .. ', sourceGUID: ' .. tostring(sourceGUID) .. ', sourceFlags: ' .. tostring(sourceFlags) .. ', destGUID: ' .. tostring(destGUID) .. ', destName: ' .. tostring(destName) .. ', destFlags: ' .. tostring(destFlags) .. ', spellID: ' .. tostring(spellID))
			Update(self,eventType,self.unit)
		end
	end
end

local Enable = function(self)
	if(self.Buffs or self.Debuffs or self.Auras) then
		self:RegisterEvent("UNIT_AURA", Update)
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED",UpdateFromCombatLog)
		return true
	end
end

local Disable = function(self)
	if(self.Buffs or self.Debuffs or self.Auras) then
		self:UnregisterEvent("UNIT_AURA", Update)
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED",UpdateFromCombatLog)
	end
end
oUF:AddElement('Aura', Update, Enable, Disable)