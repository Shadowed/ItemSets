local Character = ItemSets:NewModule("Character", "AceEvent-3.0")
local iconButtons = {}
local canUseOH, hasTitansGrip, durabilityPattern, requiresPattern, requiresExactPattern, menuOpened, mouseTimeout, equipButtons, usedButtons
local MOUSE_TIMEOUT = 1

-- Should figure out a clean way to make this dynamic
local directions = {["AmmoSlot"] = "UP", ["MainHandSlot"] = "UP", ["SecondaryHandSlot"] = "UP", ["RangedSlot"] = "UP",
["HeadSlot"] = "RIGHT", ["NeckSlot"] = "RIGHT", ["ShoulderSlot"] = "RIGHT", ["ShirtSlot"] = "RIGHT", ["ChestSlot"] = "RIGHT", ["WristSlot"] = "RIGHT", ["BackSlot"] = "RIGHT",
["TabardSlot"] = "RIGHT",
["WaistSlot"] = "LEFT", ["LegsSlot"] = "LEFT", ["FeetSlot"] = "LEFT", ["HandsSlot"] = "LEFT", ["Finger0Slot"] = "LEFT", ["Finger1Slot"] = "LEFT", ["Trinket0Slot"] = "LEFT",
["Trinket1Slot"] = "LEFT"}

-- What item type can go into what slot
local equipLocations = {
	["AmmoSlot"] = "INVTYPE_AMMO", ["HeadSlot"] = "INVTYPE_HEAD", ["NeckSlot"] = "INVTYPE_NECK", ["ShoulderSlot"] = "INVTYPE_SHOULDER", ["ShirtSlot"] = "INVTYPE_BODY",
	["ChestSlot"] = {["INVTYPE_ROBE"] = true, ["INVTYPE_CHEST"] = true}, ["WaistSlot"] = "INVTYPE_WAIST", ["LegsSlot"] = "INVTYPE_LEGS", ["FeetSlot"] = "INVTYPE_FEET",
	["WristSlot"] = "INVTYPE_WRIST", ["HandsSlot"] = "INVTYPE_HAND", ["Finger0Slot"] = "INVTYPE_FINGER", ["Finger1Slot"] = "INVTYPE_FINGER", ["Trinket0Slot"] = "INVTYPE_TRINKET",
	["Trinket1Slot"] = "INVTYPE_TRINKET", ["BackSlot"] = "INVTYPE_CLOAK", ["MainHandSlot"] = {["INVTYPE_WEAPON"] = true, ["INVTYPE_2HWEAPON"] = true, ["INVTYPE_WEAPONMAINHAND"] = true},
	["SecondaryHandSlot"] = {["INVTYPE_WEAPON"] = true, ["INVTYPE_2HWEAPON"] = true, ["INVTYPE_WEAPONOFFHAND"] = true, ["INVTYPE_SHIELD"] = true, ["INVTYPE_HOLDABLE"] = true},
	["RangedSlot"] = {["INVTYPE_RANGED"] = true, ["INVTYPE_THROWN"] = true, ["INVTYPE_RANGEDRIGHT"] = true, ["INVTYPE_RELIC"] = true}, ["TabardSlot"] = "INVTYPE_TABARD",
}

function Character:OnInitialize()
	-- Register for queue update
	self:RegisterMessage("IS_UPDATE_QUEUED", "UpdateQueuedItems")

	
	-- Show little icons to indicate that we have something queued to equip
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
	
	-- Hook into the character selection screen
	local function equipItem(self)
		Character:HideMenu()
		ItemSets:EquipSingle(self.equipSlot, ItemSets:GetBaseData(self.itemLink))
	end

	local function onEnter(self, ...)
		if( self.ISOnEnter ) then
			self.ISOnEnter(self, ...)
		end
		
		Character:CreateMenu(self.ISSlot, self, directions[self.ISSlot], equipItem)
	end
	
	local function onLeave(self, ...)
		if( self.ISOnLeave ) then
			self.ISOnLeave(self, ...)
		end
		
		Character:ResetMouseTimeout()
	end

	for slot, invID in pairs(ItemSets.equipSlots) do
		local frame = getglobal("Character" .. slot)
		frame.ISOnEnter = frame:GetScript("OnEnter")
		frame.ISOnLeave = frame:GetScript("OnLeave")
		frame.ISSlot = slot

		frame:SetScript("OnEnter", onEnter)
		frame:SetScript("OnLeave", onLeave)
	end
	
	-- Now you're thinking with meta tables!
	equipButtons = setmetatable({}, {__index = function(t, k)
		local row = Character:CreateButton()
		rawset(t, k, row)

		return row
	end})
end

-- Tooltips
local mouseOverMenu
local function showTooltip(self)
	Character:ResetMouseTimeout()
	mouseOverMenu = true
	
	if( self.itemLink == "" ) then
		return
	end
	
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local bag, slot = ItemSets:FindItem(ItemSets:GetBaseData(self.itemLink))
	if( bag and slot ) then
		GameTooltip:SetBagItem(bag, slot)
	elseif( IsEquippedItem(self.itemLink) ) then
		local baseLink = ItemSets:GetBaseData(self.itemLink)
		for _, inventoryID in pairs(ItemSets.equipSlots) do
			if( ItemSets:GetBaseData(GetInventoryItemLink("player", inventoryID)) == baseLink ) then
				GameTooltip:SetInventoryItem("player", inventoryID)
				break
			end
		end
	end
	GameTooltip:Show()
end

local function hideTooltip(self)
	mouseOverMenu = nil
	
	GameTooltip:Hide()
end

-- Create new button
function Character:CreateButton()
	local id = #(equipButtons) + 1
	local button = CreateFrame("Button", "ItemSetsMenuButton" .. id, UIParent, "ItemButtonTemplate")
	button.texture = getglobal(button:GetName() .. "IconTexture")
	button.border = getglobal(button:GetName() .. "NormalTexture")
	button.border:SetHeight(54)
	button.border:SetWidth(54)
	
	button.highlight = button:GetHighlightTexture()

	button:SetWidth(32)
	button:SetHeight(32)
	button:SetClampedToScreen(true)
	button:SetScript("OnEnter", showTooltip)
	button:SetScript("OnLeave", hideTooltip)
	button:Hide()

	if( id == 1 ) then
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

				if( mouseTimeout <= 0 and not MouseIsOver(self:GetParent()) ) then
					mouseTimeout = nil
					Character:HideMenu()
				end
			end
		end)
	end
	
	return button
end

-- Setup a new menu button (obviously)
function Character:AddMenuButton(link, type, slot)
	usedButtons = usedButtons + 1
	
	local icon = select(10, GetItemInfo(link)) or self:GetBackgroundTexture(slot)
	local button = equipButtons[usedButtons]
	
	-- Banked, blue border
	if( type == "bank" ) then
		button.highlight:SetVertexColor(0.10, 0.10, 1.0, 1.0)
		button:LockHighlight()
	else
		button.highlight:SetVertexColor(1.0, 1.0, 1.0, 1.0)
	end
	
	button.itemLink = link
	button.texture:SetTexture(icon)
	button:ClearAllPoints()
	button:Show()
end

-- Item finding
-- Figure out how to optimize this a bit later
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

function Character:BuildItemMenu(equipSlot, checkEquipped)
	-- Check what we can wear
	local class = select(2, UnitClass("player"))
	if( class == "ROGUE" or class == "HUNTER" or class == "DEATHKNIGHT" ) then
		canUseOH = true
	elseif( class == "WARRIOR" ) then
		canUseOH = true
		hasTitansGrip = (select(5, GetTalentInfo(2, 26)) > 0)
	elseif( class == "SHAMAN" ) then
		canUseOH = (select(5, GetTalentInfo(2, 18)) > 0)
	end

	-- And figure out what item types we can wear
	local acceptable = equipLocations[equipSlot]
	local isTable = type(acceptable) == "table"	

	-- Reset our buttons
	self:HideMenu()
	
	-- Scan inventory
	for bag=4, 0, -1 do
		if( ItemSets:IsContainer(bag) ) then
			for slot=1, GetContainerNumSlots(bag) do
				local link = GetContainerItemLink(bag, slot)
				if( link ) then
					-- Can this be nil?
					local weaponType = select(9, GetItemInfo(link))
					if( ( ( not isTable and acceptable == weaponType ) or ( isTable and acceptable[weaponType] ) ) and self:IsWearable(bag, slot, equipSlot, weaponType) ) then
						self:AddMenuButton(link, "inventory", equipSlot)
					end
				end
			end
		end
	end
	
	-- Scan bank
	if( ItemSets.isBankOpen ) then
		for _, bag in pairs(ItemSets.bankSlots) do
			if( ItemSets:IsContainer(bag) ) then
				for slot=1, GetContainerNumSlots(bag) do
					local link = GetContainerItemLink(bag, slot)
					if( link ) then
						-- Can this be nil?
						local weaponType = select(9, GetItemInfo(link))
						if( ( ( not isTable and acceptable == weaponType ) or ( isTable and acceptable[weaponType] ) ) and self:IsWearable(bag, slot, equipSlot, weaponType) ) then
							self:AddMenuButton(link, "bank", equipSlot)
						end
					end
				end
			end
		end
	end
	
	-- Scan equipped items
	if( checkEquipped ) then
		-- Make less ugly later
		if( equipSlot == "Finger0Slot" or equipSlot == "Finger1Slot" ) then
			local link = GetInventoryItemLink("player", ItemSets.equipSlots.Finger0Slot)
			if( link ) then
				self:AddMenuButton(link, "equipped", equipSlot)
			end
			local link = GetInventoryItemLink("player", ItemSets.equipSlots.Finger1Slot)
			if( link ) then
				self:AddMenuButton(link, "equipped", equipSlot)
			end
		elseif( equipSlot == "Trinket0Slot" or equipSlot == "Trinket1Slot" ) then
			local link = GetInventoryItemLink("player", ItemSets.equipSlots.Trinket0Slot)
			if( link ) then
				self:AddMenuButton(link, "equipped", equipSlot)
			end
			local link = GetInventoryItemLink("player", ItemSets.equipSlots.Trinket1Slot)
			if( link ) then
				self:AddMenuButton(link, "equipped", equipSlot)
			end
		else
			local link = GetInventoryItemLink("player", ItemSets.equipSlots[equipSlot])
			if( link ) then
				self:AddMenuButton(link, "equipped", equipSlot)
			end
		end
	end
	
	-- Now the blank one
	self:AddMenuButton("", "unequip", equipSlot)
end

-- Fancy menus showing things
function Character:GetBackgroundTexture(slot)
	local invID, textureName, checkRelic = GetInventorySlotInfo(slot)
	if( checkRelic and UnitHasRelicSlot("player") ) then
		return "Interface\\Paperdoll\\UI-PaperDoll-Slot-Relic.blp"
	end
	
	return textureName
end

function Character:ResetMouseTimeout()
	mouseTimeout = MOUSE_TIMEOUT
end

-- Info on the menu currently up
local currentMenu = {}

-- Inventory changed, update menu
function Character:UNIT_INVENTORY_CHANGED(event, unit)
	if( unit ~= "player" and equipButtons[1]:IsVisible() ) then
		return
	end
	
	self:CreateMenu(currentMenu.equipSlot, currentMenu.parent, currentMenu.direction, currentMenu.onClick, currentMenu.checkEquipped)
end

-- Create/update menu
function Character:HideMenu()
	usedButtons = 0

	for _, button in pairs(equipButtons) do
		button:UnlockHighlight()
		button:Hide()
	end
end

function Character:CreateMenu(slot, parent, direction, onClick, checkEquipped)
	currentMenu.equipSlot = slot
	currentMenu.direction = direction
	currentMenu.parent = parent
	currentMenu.onClick = onClick
	currentMenu.checkEquipped = checkEquipped
	
	-- Build it
	self:BuildItemMenu(slot, checkEquipped)	

	-- Update buttons to the item list, numbers yoinked from ItemRack!
	local columns = (usedButtons >= 25 and 6) or (usedButtons >= 19 and 5) or (usedButtons >= 10 and 4) or (usedButtons >= 5 and 3)
	local lastColumn
	local inRow = 0

	-- Position it all, this needs to be smart and choose a new direction if it's going to hit the screen
	for id=1, usedButtons do
		-- Setup parenting type of things
		local button = equipButtons[id]
		button:SetParent(parent)
		button:SetFrameStrata("HIGH")
		button:SetScript("OnClick", onClick)
		button.equipSlot = slot

		-- Positioning!
		if( direction == "RIGHT" ) then
			if( id == 1 ) then
				button:SetPoint("TOPLEFT", parent, "TOPRIGHT", 4, -1)
			elseif( inRow == columns ) then
				button:SetPoint("TOPLEFT", lastColumn, "BOTTOMLEFT", 1, 0)
			else
				button:SetPoint("TOPLEFT", equipButtons[id - 1], "TOPRIGHT", 1, 0)
			end
		elseif( direction == "LEFT" ) then
			if( id == 1 ) then
				button:SetPoint("TOPRIGHT", parent, "TOPLEFT", -4, -2)
			elseif( inRow == columns ) then
				button:SetPoint("TOPRIGHT", lastColumn, "BOTTOMRIGHT", 0, 0)
			else
				button:SetPoint("TOPRIGHT", equipButtons[id - 1], "TOPLEFT", 0, 0)
			end		
		elseif( direction == "UP" ) then
			if( id == 1 ) then
				button:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 3, 4)
			elseif( inRow == columns ) then
				button:SetPoint("BOTTOMRIGHT", lastColumn, "BOTTOMLEFT", 0, 0)
			else
				button:SetPoint("BOTTOMLEFT", equipButtons[id - 1], "TOPLEFT", 0, 0)
			end
		elseif( direction == "DOWN" ) then
			if( id == 1 ) then
				button:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 2, -4)
			elseif( inRow == columns ) then
				button:SetPoint("BOTTOMRIGHT", lastColumn, "BOTTOMLEFT", 0, 0)
			else
				button:SetPoint("TOPLEFT", equipButtons[id - 1], "BOTTOMLEFT", 0, 0)
			end
		end

		if( id == 1 ) then
			inRow = inRow + 1
			lastColumn = button
		elseif( inRow == columns ) then
			inRow = 1
			lastColumn = button
		else
			inRow = inRow + 1
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