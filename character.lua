local Character = ItemSets:NewModule("Character", "AceEvent-3.0")
local iconButtons, itemList, equipButtons = {}, {}, {}
local canUseOH, hasTitansGrip, durabilityPattern, requiresPattern, requiresExactPattern, menuOpened, mouseTimeout
local MOUSE_TIMEOUT = 1.5

-- Should figure out a clean way to make this dynamic
local directions = {["AmmoSlot"] = "UP", ["MainHandSlot"] = "UP", ["SecondaryHandSlot"] = "UP", ["RangedSlot"] = "UP",
["HeadSlot"] = "RIGHT", ["NeckSlot"] = "RIGHT", ["ShoulderSlot"] = "RIGHT", ["ShirtSlot"] = "RIGHT", ["ChestSlot"] = "RIGHT", ["WristSlot"] = "RIGHT", ["BackSlot"] = "RIGHT",
["TabardSlot"] = "RIGHT",
["WaistSlot"] = "LEFT", ["LegsSlot"] = "LEFT", ["FeetSlot"] = "LEFT", ["HandsSlot"] = "LEFT", ["Finger0Slot"] = "LEFT", ["Finger1Slot"] = "LEFT", ["Trinket0Slot"] = "LEFT",
["Trinket1Slot"] = "LEFT"}

local equipLocations = {
	["AmmoSlot"] = "INVTYPE_AMMO",
	["HeadSlot"] = "INVTYPE_HEAD",
	["NeckSlot"] = "INVTYPE_NECK",
	["ShoulderSlot"] = "INVTYPE_SHOULDER",
	["ShirtSlot"] = "INVTYPE_BODY",
	["ChestSlot"] = {["INVTYPE_ROBE"] = true, ["INVTYPE_CHEST"] = true},
	["WaistSlot"] = "INVTYPE_WAIST",
	["LegsSlot"] = "INVTYPE_LEGS",
	["FeetSlot"] = "INVTYPE_FEET",
	["WristSlot"] = "INVTYPE_WRIST",
	["HandsSlot"] = "INVTYPE_HAND",
	["Finger0Slot"] = "INVTYPE_FINGER",
	["Finger1Slot"] = "INVTYPE_FINGER",
	["Trinket0Slot"] = "INVTYPE_TRINKET",
	["Trinket1Slot"] = "INVTYPE_TRINKET",
	["BackSlot"] = "INVTYPE_CLOAK",
	["MainHandSlot"] = {["INVTYPE_WEAPON"] = true, ["INVTYPE_2HWEAPON"] = true, ["INVTYPE_WEAPONMAINHAND"] = true},
	["SecondaryHandSlot"] = {["INVTYPE_WEAPON"] = true, ["INVTYPE_2HWEAPON"] = true, ["INVTYPE_WEAPONOFFHAND"] = true, ["INVTYPE_SHIELD"] = true, ["INVTYPE_HOLDABLE"] = true},
	["RangedSlot"] = {["INVTYPE_RANGED"] = true, ["INVTYPE_THROWN"] = true, ["INVTYPE_RANGEDRIGHT"] = true, ["INVTYPE_RELIC"] = true},
	["TabardSlot"] = "INVTYPE_TABARD",
}

function Character:OnInitialize()
	self.buttons = equipButtons
	
	-- Update item icons if the doll is opened
	local orig_PaperDollFrame_OnShow = PaperDollFrame:GetScript("OnShow")
	PaperDollFrame:SetScript("OnShow", function(...)
		if( orig_PaperDollFrame_OnShow ) then
			orig_PaperDollFrame_OnShow(...)
		end
		
		Character:UpdateQueuedItems()
	end)
	
	-- Adding the ^ means we only get the "Requires Inscription (425)" type of items, instead of specific
	-- enchants that are listed as "Socket Requires Blacksmithing (#)" and so on
	requiresPattern = string.gsub(string.gsub(ITEM_MIN_SKILL, "%%d", "([0-9]+)"), "%%s", "(.+)")
	requiresExactPattern = "^" .. requiresPattern
	durabilityPattern = string.gsub(DURABILITY_TEMPLATE, "%%d", "([0-9]+)")
	
	-- Setup menu to work with the character screen
	local function onEnter(self, ...)
		if( self.ISOnEnter ) then
			self.ISOnEnter(self, ...)
		end
		
		Character:CreateMenu(self.ISSlot, self, directions[self.ISSlot])
	end
	
	local function onLeave(self, ...)
		if( self.ISOnLeave ) then
			self.ISOnLeave(self, ...)
		end
		
		mouseTimeout = MOUSE_TIMEOUT
	end
	
	for slot, invID in pairs(ItemSets.equipSlots) do
		local frame = getglobal("Character" .. slot)
		frame.ISOnEnter = frame:GetScript("OnEnter")
		frame.ISOnLeave = frame:GetScript("OnLeave")
		frame.ISSlot = slot

		frame:SetScript("OnEnter", onEnter)
		frame:SetScript("OnLeave", onLeave)
	end
end

-- Item finding
-- Optimize this a bit later
function Character:IsWearable(bag, slot, equipSlot, weaponType)
	if( not ItemSets.tooltip ) then
		ItemSets.tooltip = CreateFrame("GameTooltip", "ItemSetsScanTooltip", UIParent, "GameTooltipTemplate")
		ItemSets.tooltip:SetOwner(UIParent, "ANCHOR_NONE")
	end
	
	-- Do specific checks for weapon types/skills/class
	if( equipSlot == "SecondaryHandSlot" ) then
		if( not canUseOH and ( weaponType == "INVTYPE_WEAPONOFFHAND" or weaponType == "INVTYPE_ONEHAND" ) ) then
			return false
		elseif( not hasTitansGrip and weaponType == "INVTYPE_2HWEAPON" ) then
			return false
		end
	end
	
	-- Tooltip scanning (UGHHHHH)
	ItemSets.tooltip:ClearLines()
	ItemSets.tooltip:SetBagItem(bag, slot)
	
	local id = 1
	while( true ) do
		-- Check the item type on the right side
		local rightText = getglobal("ItemSetsScanTooltipTextRight" .. id)
		if( rightText and rightText:GetText() ) then
			local r, g, b = rightText:GetTextColor()
			if( r >= 0.98 and g <= 0.15 and b <= 0.15 ) then
				return false
			end
		end
		
		-- Check rest
		local leftText = getglobal("ItemSetsScanTooltipTextLeft" .. id)
		if( leftText ) then
			local text = leftText:GetText()
			
			-- Filter out BoE or BoU automatically
			if( text and ( string.match(text, ITEM_BIND_ON_EQUIP) or string.match(text, ITEM_BIND_ON_USE) ) ) then
				return false
			
			-- Check profession requirement, or level, DON'T check "Enchant Requires Enchanting" type of patterns thought
			elseif( text and ( not string.match(text, requiresPattern) or string.match(text, requiresExactPattern) ) and not string.match(text, durabilityPattern) ) then
				local r, g, b = leftText:GetTextColor()
				if( r >= 0.98 and g <= 0.15 and b <= 0.15 ) then
					return false
				end
			end
		end
		
		id = id + 1
		
		-- Nothing else found, exit
		if( not rightText and not leftText ) then break end
	end
	
	return true
end

function Character:CheckEquipSkill()
	local class = select(2, UnitClass("player"))
	if( class == "ROGUE" or class == "HUNTER" or class == "DEATHKNIGHT" ) then
		canUseOH = true
	elseif( class == "WARRIOR" ) then
		canUseOH = true
		hasTitansGrip = (select(5, GetTalentInfo(2, 26)) > 0)
	elseif( class == "SHAMAN" ) then
		canUseOH = (select(5, GetTalentInfo(2, 18)) > 0)
	end
end

function Character:FindItems(equipSlot)
	self:CheckEquipSkill()
	
	for i=#(itemList), 1, -1 do table.remove(itemList, i) end
	local acceptable = equipLocations[equipSlot]
	local isTable = type(acceptable) == "table"	
	
	-- Scan inventory
	for bag=4, 0, -1 do
		if( ItemSets:IsContainer(bag) ) then
			for slot=1, GetContainerNumSlots(bag) do
				local link = GetContainerItemLink(bag, slot)
				if( link ) then
					-- Can this be nil?
					local weaponType = select(9, GetItemInfo(link))
					if( ( ( not isTable and acceptable == weaponType ) or ( isTable and acceptable[weaponType] ) ) and self:IsWearable(bag, slot, equipSlot, weaponType) ) then
						table.insert(itemList, link)
					end
				end
			end
		end
	end
	
	-- Scan bank
	if( self.isBankOpen ) then
		for _, bag in pairs(ItemSets.bankSlots) do
			if( ItemSets:IsContainer(bag) ) then
				for slot=1, GetContainerNumSlots(bag) do
					-- Can this be nil?
					local weaponType = select(9, GetItemInfo(link))
					if( ( ( not isTable and acceptable == weaponType ) or ( isTable and acceptable[weaponType] ) ) and self:IsWearable(bag, slot, equipSlot, weaponType) ) then
						table.insert(itemList, link)
					end
				end
			end
		end
	end
	
	return itemList
end

-- Fancy menus showing things
function Character:GetBackgroundTexture(slot)
	local invID, textureName, checkRelic = GetInventorySlotInfo(slot)
	if( checkRelic and UnitHasRelicSlot("player") ) then
		return "Interface\\Paperdoll\\UI-PaperDoll-Slot-Relic.blp"
	end
	
	return textureName
end

-- Tooltips
--/script ItemSets.modules.Character:CreateMenu("FeetSlot", CharacterFeetSlot, "RIGHT")
local mouseOverMenu
local function showTooltip(self)
	mouseTimeout = MOUSE_TIMEOUT
	mouseOverMenu = true
	
	if( self.itemLink == "" ) then
		return
	end
	
	local bag, slot = ItemSets:FindItem(ItemSets:GetBaseData(self.itemLink))
	
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetBagItem(bag, slot)
	GameTooltip:Show()
end

local function hideTooltip(self)
	mouseOverMenu = nil
	
	GameTooltip:Hide()
end

-- Equip a single item
local function equipItem(self)
	Character:HideMenu()
	ItemSets:EquipSingle(self.equipSlot, ItemSets:GetBaseData(self.itemLink))
end

-- Inventory changed, update menu
function Character:UNIT_INVENTORY_CHANGED(event, unit)
	if( unit ~= "player" and equipButtons[1]:IsVisible() ) then
		return
	end
	
	self:CreateMenu(equipButtons[1].equipSlot, equipButtons[1].parent, equipButtons[1].direction)
end

-- Create/update menu
function Character:HideMenu()
	for _, button in pairs(equipButtons) do
		button:Hide()
	end
end

function Character:CreateMenu(slot, parent, direction)
	local items = self:FindItems(slot)

	-- Insert the blank one that will act as the unequip button
	table.insert(items, "")
	
	-- Hide current buttons first
	self:HideMenu()

	-- Not enough buttons, creation time
	if( #(items) > #(equipButtons) ) then
		for i=#(equipButtons) + 1, #(items) do
			local button = CreateFrame("Button", "ItemSetsMenuButton" .. i, UIParent, "ItemButtonTemplate")
			button.texture = getglobal(button:GetName() .. "IconTexture")
			button.border = getglobal(button:GetName() .. "NormalTexture")
			button.border:SetHeight(54)
			button.border:SetWidth(54)
			
			button:SetWidth(32)
			button:SetHeight(32)
			button:SetClampedToScreen(true)
			button:SetScript("OnEnter", showTooltip)
			button:SetScript("OnLeave", hideTooltip)
			button:SetScript("OnClick", equipItem)
			button:Hide()
			
			table.insert(equipButtons, button)

			if( i == 1 ) then
				-- Check inventory while the menus visible
				button:SetScript("OnShow", function()
					Character:RegisterEvent("UNIT_INVENTORY_CHANGED")
				end)
				button:SetScript("OnHide", function()
					Character:UnregisterEvent("UNIT_INVENTORY_CHANGED")
				end)
				
				-- Check if we should hide the menu
				button:SetScript("OnUpdate", function(self, elapsed)
					-- After 2 seconds of not being inside the menu buttons, we hide it regardless
					if( mouseTimeout and not mouseOverMenu ) then
						mouseTimeout = mouseTimeout - elapsed
						
						if( mouseTimeout <= 0 and not MouseIsOver(self.parent) ) then
							mouseTimeout = nil
							Character:HideMenu()
						end
					end
				end)
			end
		end
	end
	
	-- Update buttons to the item list
	local usedButtons = 0
	for _, link in pairs(items) do
		usedButtons = usedButtons + 1
		
		local icon = select(10, GetItemInfo(link)) or self:GetBackgroundTexture(slot)
		local button = equipButtons[usedButtons]
				
		button:SetParent(parent)
		button:SetFrameStrata("HIGH")
		
		button.itemLink = link
		button.equipSlot = slot
		button.direction = direction
		button.parent = parent
		button.texture:SetTexture(icon)
		button:Show()
		
		if( direction == "RIGHT" ) then
			if( usedButtons > 1 ) then
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", equipButtons[usedButtons - 1], "TOPRIGHT", 1, 0)
			else
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", parent, "TOPRIGHT", 4, -1)
			end
		elseif( direction == "LEFT" ) then
			if( usedButtons > 1 ) then
				button:ClearAllPoints()
				button:SetPoint("TOPRIGHT", equipButtons[usedButtons - 1], "TOPLEFT", 0, 0)
			else
				button:ClearAllPoints()
				button:SetPoint("TOPRIGHT", parent, "TOPLEFT", -4, -2)
			end
		elseif( direction == "UP" ) then
			if( usedButtons > 1 ) then
				button:ClearAllPoints()
				button:SetPoint("BOTTOMLEFT", equipButtons[usedButtons - 1], "TOPLEFT", 0, 0)
			else
				button:ClearAllPoints()
				button:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 3, 4)
			end
		elseif( direction == "DOWN" ) then
			if( usedButtons > 1 ) then
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", equipButtons[usedButtons - 1], "BOTTOMLEFT", 0, 0)
			else
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 2, -4)
			end
		end
	end
end

-- Item icons for queued stuff
function Character:UpdateQueuedItems()
	if( not PaperDollFrame:IsVisible() ) then
		return
	end
	
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