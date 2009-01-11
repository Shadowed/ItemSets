local Character = ItemSets:NewModule("Character", "AceEvent-3.0")
local iconButtons = {}

function Character:OnInitialize()
	self.buttons = iconButtons
end

function Character:UpdateQueuedItems()
	for name, slotID in pairs(ItemSets.equipSlots) do
		local item = ItemSets.db.profile.queued[slotID]
		local equipped = ItemSets:GetBaseData(GetInventoryItemLink("player", slotID))
		local icon
		
		-- Item isn't equipped but it's queued
		if( item and item ~= "" and equipped ~= item ) then
			icon = select(10, GetItemInfo(item))
		-- Unequipping, and something is in this slot
		elseif( equipped ~= "" and item == "" ) then
			icon = "Interface\\Icons\\INV_Misc_QuestionMark"
		end
		
		if( icon ) then
			local button = iconButtons[slotID]
			if( not button ) then
				local parent = getglobal("Character" .. name)
				
				iconButtons[slotID] = CreateFrame("Frame", "ItemSetsIcon" .. name, parent, "ItemButtonTemplate")
				button = iconButtons[slotID]
				
				button.texture = getglobal(button:GetName() .. "IconTexture")
				button:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
				button:SetHeight(18)
				button:SetWidth(18)
			end
			
			button.texture:SetTexture(icon)
			button:Show()
			
		elseif( iconButtons[slotID] ) then
			iconButtons[slotID]:Hide()
		end
	end
end

function Character:EquipQueued()
	self:UpdateQueuedItems()
end

function Character:ResetQueued()
	self:UpdateQueuedItems()
end