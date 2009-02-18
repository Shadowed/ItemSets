local Config = ItemSets:NewModule("Config")
local Character, lockedSet
local totalSets = 0
local MAX_SETS_SHOWN = 10
local equipButtons = {}
local directions = {["AmmoSlot"] = "DOWN", ["MainHandSlot"] = "DOWN", ["SecondaryHandSlot"] = "DOWN", ["RangedSlot"] = "DOWN",
["HeadSlot"] = "LEFT", ["NeckSlot"] = "LEFT", ["ShoulderSlot"] = "LEFT", ["ShirtSlot"] = "LEFT", ["ChestSlot"] = "LEFT", ["WristSlot"] = "LEFT", ["BackSlot"] = "LEFT", ["TabardSlot"] = "LEFT",
["WaistSlot"] = "RIGHT", ["LegsSlot"] = "RIGHT", ["FeetSlot"] = "RIGHT", ["HandsSlot"] = "RIGHT", ["Finger0Slot"] = "RIGHT", ["Finger1Slot"] = "RIGHT", ["Trinket0Slot"] = "RIGHT", ["Trinket1Slot"] = "RIGHT"}

local L = ItemSetLocals

function Config:OnInitialize()
	Character = ItemSets.modules.Character
end

local function fakeEquip(self)
	Character:HideMenu()
	
	local icon = select(10, GetItemInfo(self.itemLink)) or Character:GetBackgroundTexture(self.equipSlot)
	local button = equipButtons[self.equipSlot]
	button.itemLink = ItemSets:GetBaseData(self.itemLink) or ""
	button.texture:SetTexture(icon)
	button.isEnabled = true
	button.texture:SetAlpha(1.0)
end

local function showTooltip(self)
	-- Create menu if needed
	Character:CreateMenu(self.equipSlot, self, directions[self.equipSlot], fakeEquip, true)
	
	if( not self.itemLink or self.itemLink == "" ) then
		return
	end
		
	-- Clean later... somehow
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local bag, slot = ItemSets:FindItem(self.itemLink)
	if( bag and slot ) then
		GameTooltip:SetBagItem(bag, slot)
	elseif( IsEquippedItem(self.itemLink) ) then
		for _, inventoryID in pairs(ItemSets.equipSlots) do
			if( ItemSets:GetBaseData(GetInventoryItemLink("player", inventoryID)) == self.itemLink ) then
				GameTooltip:SetInventoryItem("player", inventoryID)
				break
			end
		end
	end
	
	GameTooltip:Show()
end

local function hideTooltip(self)
	Character:ResetMouseTimeout()
	GameTooltip:Hide()
end

local function toggleEnabled(self)
	self.isEnabled = not self.isEnabled
	self.itemLink = ""
	self.texture:SetAlpha(self.isEnabled and 1.0 or 0.25)
end

-- Create slot button
function Config:CreateButton(slot)
	local button = CreateFrame("Button", "ItemSetsOptionsButton" .. slot, self.frame, "ItemButtonTemplate")
	button.texture = getglobal(button:GetName() .. "IconTexture")
	button.equipSlot = slot
	button.itemLink = ""
	button.isEnabled = true
	
	button.highlight = button:GetHighlightTexture()
	
	button.texture:SetTexture(Character:GetBackgroundTexture(slot))
	button:SetScript("OnEnter", showTooltip)
	button:SetScript("OnLeave", hideTooltip)
	button:SetScript("OnClick", toggleEnabled)
	button:RegisterForClicks("LeftButtonUp")
	
	equipButtons[slot] = button
	return button
end

-- Set management
local function displaySet(name)
	local set = ItemSets.db.profile.sets[name]

	Config.frame.setFrame.showHelm:SetChecked(set.helm)
	Config.frame.setFrame.showCloak:SetChecked(set.cloak)

	for slot, inventoryID in pairs(ItemSets.equipSlots) do
		local button = equipButtons[slot]
		if( button ) then
			local link = set[inventoryID]
			local icon = Character:GetBackgroundTexture(slot)
			
			button:UnlockHighlight()
			
			-- Not managing this slot
			if( not link ) then
				button.isEnabled = false
				button.texture:SetAlpha(0.25)
				
			elseif( link ~= "" ) then
				button.isEnabled = true
				button.texture:SetAlpha(1.0)
				
				icon = select(10, GetItemInfo(link)) or icon
				
				-- If it's not equipped, red border
				if( not ItemSets:FindItem(link) and not IsEquippedItem(link) ) then
					button.highlight:SetVertexColor(1.0, 0.10, 0.10, 1.0)
					button:LockHighlight()
				else
					button.highlight:SetVertexColor(1.0, 1.0, 1.0, 1.0)
				end
			end

			button.itemLink = link
			button.texture:SetTexture(icon)
		end
	end
end

local function previewSet(self)
	if( not lockedSet ) then
		displaySet(self.name)
	end
end

local function selectSet(self)
	-- Newly locked, or unlocking?
	lockedSet = lockedSet ~= self.name and self.name or nil

	-- Reset status
	local setFrame = Config.frame.setFrame
	setFrame.saveSet:Disable()
	setFrame.deleteSet:Disable()
	setFrame.showHelm:Disable()
	setFrame.showCloak:Disable()
	setFrame.setName:GetScript("OnEditFocusLost")(setFrame.setName)

	for _, row in pairs(setFrame.rows) do
		if( row.name == lockedSet ) then
			setFrame.saveSet:Enable()
			setFrame.deleteSet:Enable()
			setFrame.showHelm:Enable()
			setFrame.showCloak:Enable()
			setFrame.setName:GetScript("OnEditFocusGained")(setFrame.setName)
			setFrame.setName:SetText(self.name)

			row:LockHighlight()
			displaySet(self.name)
		else
			row:UnlockHighlight()
		end
	end
end

local function saveLockedSet(self)
	local setFrame = Config.frame.setFrame
	
	-- Save helm/cloak visibility
	ItemSets.db.profile.sets[lockedSet].helm = setFrame.showHelm:GetChecked() and true or false
	ItemSets.db.profile.sets[lockedSet].cloak = setFrame.showCloak:GetChecked() and true or false
	
	-- Save items
	for slot, button in pairs(equipButtons) do
		ItemSets.db.profile.sets[lockedSet][ItemSets.equipSlots[slot]] = button.isEnabled and button.itemLink or nil
	end
end

local function deleteLockedSet(self)
	ItemSets.db.profile.sets[lockedSet] = nil
	Config:UpdateSetRows()

	lockedSet = nil
	selectSet(self)
end

local function createNewSet(self)
	self.name = string.trim(self:GetText() or "")
	self:SetText("")
	self:ClearFocus()
	
	if( self.name == "" ) then
		return	
	else
		for name in pairs(ItemSets.db.profile.sets) do
			if( string.lower(name) == string.lower(self.name) ) then
				ItemSets:Print(string.format(L["Cannot create set named \"%s\" one already exists with that name."], self.name))
				return
			end
		end
	end

	ItemSets.db.profile.sets[self.name] = {helm = true, cloak = true}
	for slot, inventoryID in pairs(ItemSets.equipSlots) do
		local link
		if( not lockedSet ) then
			link = ItemSets:GetBaseData((GetInventoryItemLink("player", inventoryID)))
		else
			link = ItemSets.db.profile.sets[lockedSet][inventoryID]
		end
		
		ItemSets.db.profile.sets[self.name][inventoryID] = link or ""
	end
	
	Config:UpdateSetRows()
	
	selectSet(self)
end

-- Toggle slots
local enabled = true
local function toggleEnabled(self)
	enabled = not enabled
	
	for _, button in pairs(equipButtons) do
		button.isEnabled = enabled
		button.texture:SetAlpha(button.isEnabled and 1.0 or 0.25)
	end
end

-- Push/pulling
local function pushSet(self)
	ItemSets:PushSet(self:GetParent().name)
end

local function pullSet(self)
	ItemSets:PullSet(self:GetParent().name)
end

local function showTextTooltip(self)
	if( not self.tooltip ) then
		return
	end
	
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(self.tooltip, 1.0, 1.0, 1.0, true)
	GameTooltip:Show()
end

local function sortSetList(a, b)
	return a.name < b.name
end

-- Update set rows
function Config:UpdateSetRows()
	for _, button in pairs(self.frame.setFrame.rows) do
		button:Hide()
	end
		
	-- Figure out how many we have quickly
	totalSets = 0
	for name in pairs(ItemSets.db.profile.sets) do
		totalSets = totalSets + 1
	end
	
	FauxScrollFrame_Update(self.frame.setFrame.scroll, totalSets, MAX_SETS_SHOWN - 1, 15)

	-- Show help text + exit, nadda to update
	if( totalSets == 0 ) then
		self.frame.setFrame.description:Show()
		return
	end

	-- Update rows
	self.frame.setFrame.description:Hide()

	totalSets = 0
	
	local offset = FauxScrollFrame_GetOffset(self.frame.setFrame.scroll)
	local usedRows = 0
	for name, items in pairs(ItemSets.db.profile.sets) do
		totalSets = totalSets + 1
		
		if( totalSets >= offset and usedRows < 10 ) then
			usedRows = usedRows + 1

			local row = self.frame.setFrame.rows[usedRows]
			if( not row ) then
				row = CreateFrame("Button", nil, self.frame.setFrame)
				row:SetHeight(15)
				row:SetWidth(80)
				row:SetHighlightFontObject(GameFontNormal)
				row:SetNormalFontObject(GameFontHighlight)
				row:SetScript("OnEnter", previewSet)
				row:SetScript("OnClick", selectSet)
				row:SetText("*")
				row:GetFontString():SetPoint("TOPLEFT", row)

				row.push = CreateFrame("Button", nil, row, "UIPanelButtonGrayTemplate")
				row.push:SetText(L["Push"])
				row.push:SetPoint("TOPRIGHT", row, "TOPRIGHT", 31, 0)
				row.push:SetHeight(15)
				row.push:SetWidth(34)
				row.push:SetScript("OnClick", pushSet)
				row.push:SetScript("OnEnter", showTextTooltip)
				row.push:SetScript("OnLeave", hideTooltip)
				row.push.tooltip = L["Pushes all the items from this set into your bank, from your inventory."]

				row.pull = CreateFrame("Button", nil, row, "UIPanelButtonGrayTemplate")
				row.pull:SetText(L["Pull"])
				row.pull:SetPoint("TOPLEFT", row.push, "TOPRIGHT", 2, 0)
				row.pull:SetHeight(15)
				row.pull:SetWidth(34)
				row.pull:SetScript("OnClick", pullSet)
				row.pull:SetScript("OnEnter", showTextTooltip)
				row.pull:SetScript("OnLeave", hideTooltip)
				row.pull.tooltip = L["Pulls all the items from this set into your inventory, from your bank."]
				self.frame.setFrame.rows[usedRows] = row
			end
			
			if( self.frame.setFrame.scroll:IsVisible() ) then
				row:SetWidth(80)
			else
				row:SetWidth(100)
			end

			row.name = name
			row:SetText(name)
			row:Show()
		end
	end
	
	-- Now sort it
	table.sort(self.frame.setFrame.rows, sortSetList)

	for id, row in pairs(self.frame.setFrame.rows) do
		if( id > 1 ) then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", self.frame.setFrame.rows[id - 1], "BOTTOMLEFT", 0, -8)
		else
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", self.frame.setFrame, "TOPLEFT", 2, -2)
		end
	end
end

-- Create configuration
function Config:Open()
	if( self.frame ) then 
		if( self.frame:IsVisible() ) then
			self.frame:Hide()
		else
			self.frame:Show()
		end
		return 
	end

	local infoBackdrop = {  
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
		tile = true,
		edgeSize = 1,
		tileSize = 5,
		insets = {left = 1, right = 1, top = 1, bottom = 1}}

	local frame = CreateFrame("Frame", "ItemSetsOptions", UIParent)
	frame:SetWidth(260)
	frame:SetHeight(330)
	frame:SetToplevel(true)
	frame:SetFrameStrata("HIGH")
	frame:SetBackdrop(infoBackdrop)
	frame:SetBackdropColor(0.0, 0.0, 0.0, 1.0)
	frame:SetBackdropBorderColor(0.65, 0.65, 0.65, 1.0)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetScript("OnShow", function()
		Config:UpdateSetRows()
	end)
	self.frame = frame
	
	if( ItemSets.db.profile.position ) then
		local scale = frame:GetEffectiveScale()

		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", ItemSets.db.profile.position.x / scale, ItemSets.db.profile.position.y / scale)
	end
	
	-- Title bar
	local titleFrame = CreateFrame("Frame", nil, frame)
	titleFrame:SetWidth(260)
	titleFrame:SetHeight(18)
	titleFrame:SetToplevel(true)
	titleFrame:SetFrameStrata("HIGH")
	titleFrame:SetBackdrop(infoBackdrop)
	titleFrame:SetBackdropColor(0.0, 0.0, 0.0, 1.0)
	titleFrame:SetBackdropBorderColor(0.65, 0.65, 0.65, 1.0)
	titleFrame:SetClampedToScreen(true)
	titleFrame:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)

	titleFrame.button = CreateFrame("Button", nil, titleFrame)
	titleFrame.button:SetHeight(18)
	titleFrame.button:SetWidth(240)
	titleFrame.button:SetPushedTextOffset(0, 0)
	titleFrame.button:SetNormalFontObject(GameFontHighlight)
	titleFrame.button:SetText(L["Item Sets"])
	titleFrame.button:GetFontString():SetPoint("CENTER", titleFrame.button, "CENTER", 10, 0)
	titleFrame.button:SetPoint("TOPLEFT", titleFrame, "TOPLEFT", 0, 0)
	titleFrame.button:SetScript("OnMouseUp", function(self)
		if( self.isMoving ) then
			local parent = ItemSetsOptions
			local scale = parent:GetEffectiveScale()

			self.isMoving = nil
			parent:StopMovingOrSizing()

			ItemSets.db.profile.position = {x = parent:GetLeft() * scale, y = parent:GetTop() * scale}
		end
	end)

	titleFrame.button:SetScript("OnMouseDown", function(self, mouse)
		local parent = ItemSetsOptions

		-- Start moving!
		if( parent:IsMovable() and mouse == "LeftButton" ) then
			self.isMoving = true
			parent:StartMoving()

		-- Reset position
		elseif( mouse == "RightButton" ) then
			parent:ClearAllPoints()
			parent:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

			ItemSets.db.profile.position = nil
		end
	end)

	titleFrame.close = CreateFrame("Button", nil, titleFrame, "UIPanelCloseButton")
	titleFrame.close:SetHeight(26)
	titleFrame.close:SetWidth(26)
	titleFrame.close:SetPoint("TOPRIGHT", 4, 4)
	titleFrame.close:SetScript("OnClick", function()
		HideUIPanel(ItemSetsOptions)
	end)
	
	self.frame.titleFrame = titleFrame
	
	-- Toggle listed items
	local toggle = CreateFrame("Button", nil, frame.titleFrame.button, "UIPanelButtonGrayTemplate")
	toggle:SetText("Toggle")
	toggle:SetPoint("TOPLEFT", frame.titleFrame, "TOPLEFT", 0, -1)
	toggle:SetFrameStrata("HIGH")
	toggle:SetHeight(16)
	toggle:SetWidth(55)
	toggle:SetScript("OnClick", toggleEnabled)
	toggle:SetScript("OnEnter", showTextTooltip)
	toggle:SetScript("OnLeave", hideTooltip)
	toggle.tooltip = L["Toggles all slots being enabled or disabled for management."]
	
	self.frame.titleFrame.toggle = toggle

	-- Special!
	table.insert(UISpecialFrames, "ItemSetsOptions")

	local leftSide = {"HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot"}
	local rightSide = {"HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot"}
	local bottomSide = {"MainHandSlot", "SecondaryHandSlot", "RangedSlot"}
	
	-- Add the ammo slot if they don't have a relic
	local bottomOffset = 72
	if( not UnitHasRelicSlot("player") ) then
		bottomOffset = 58
		table.insert(bottomSide, "AmmoSlot")
	end
	
	-- Create the left side
	local lastButton
	for id, slot in pairs(leftSide) do
		local button = self:CreateButton(slot)
		if( id > 1 ) then
			button:SetPoint("TOPLEFT",  lastButton, "BOTTOMLEFT", 0, -4)
		else
			button:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -2)
		end

		lastButton = button
	end

	-- Now the right
	for id, slot in pairs(rightSide) do
		local button = self:CreateButton(slot)
		if( id > 1 ) then
			button:SetPoint("TOPLEFT",  lastButton, "BOTTOMLEFT", 0, -4)
		else
			button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
		end

		lastButton = button
	end

	-- Now the bottom middle
	for id, slot in pairs(bottomSide) do
		local button = self:CreateButton(slot)
		if( id > 1 ) then
			button:SetPoint("TOPLEFT",  lastButton, "TOPRIGHT", 4, 0)
		else
			button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", bottomOffset, 4)
		end

		lastButton = button
	end
	
	-- Make the ammo button all pretty looking
	local ammoButton = equipButtons.AmmoSlot
	if( ammoButton ) then
		local ammoButton = ItemSetsOptionsButtonAmmoSlot
		ammoButton.border = ItemSetsOptionsButtonAmmoSlotNormalTexture

		ammoButton.border:SetWidth(42)
		ammoButton.border:SetHeight(42)
		ammoButton:SetHeight(24)
		ammoButton:SetWidth(24)

		ammoButton:ClearAllPoints()
		ammoButton:SetPoint("TOPLEFT", equipButtons.RangedSlot, "TOPRIGHT", 4, -7)
	end
	
	-- Create the set selecter
	frame.setFrame = CreateFrame("Frame", nil, frame)
	frame.setFrame:SetWidth(170)
	frame.setFrame:SetHeight(280)
	frame.setFrame:SetBackdrop(infoBackdrop)
	frame.setFrame:SetBackdropColor(0.0, 0.0, 0.0, 1.0)
	frame.setFrame:SetBackdropBorderColor(0.65, 0.65, 0.65, 1.0)
	frame.setFrame:SetClampedToScreen(true)
	frame.setFrame:SetPoint("CENTER", frame, "CENTER", 0, 20)
	frame.setFrame.rows = {}

	-- Stupid scroll bars
	local function updatePage()
		Config:UpdateSetRows()
	end
	
	local scroll = CreateFrame("ScrollFrame", frame:GetName() .. "ScrollBar", frame.setFrame, "FauxScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -2)
	scroll:SetPoint("BOTTOMRIGHT", -23, 50)
	scroll:SetScript("OnVerticalScroll", function(self, step) FauxScrollFrame_OnVerticalScroll(self, step, 15, updatePage) end)

	local child = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(child)
	child:SetHeight(2)
	child:SetWidth(2)
	
	frame.setFrame.scroll = scroll
	frame.setFrame.child = child
		
	-- Save/Delete/Show Cloak/Show Helm
	local saveSet = CreateFrame("Button", nil, frame.setFrame, "UIPanelButtonGrayTemplate")
	saveSet:SetText(L["Save"])
	saveSet:SetHeight(24)
	saveSet:SetWidth(50)
	saveSet:SetPoint("BOTTOMRIGHT", frame.setFrame, "BOTTOMRIGHT", -1, 2)
	saveSet:SetScript("OnClick", saveLockedSet)
	saveSet:Disable()

	frame.setFrame.saveSet = saveSet
	
	local deleteSet = CreateFrame("Button", nil, frame.setFrame, "UIPanelButtonGrayTemplate")
	deleteSet:SetText(L["Delete"])
	deleteSet:SetHeight(24)
	deleteSet:SetWidth(50)
	deleteSet:SetPoint("BOTTOMRIGHT", saveSet, "BOTTOMLEFT", 0, 0)
	deleteSet:SetScript("OnClick", deleteLockedSet)
	deleteSet:Disable()
	
	frame.setFrame.deleteSet = deleteSet

	local showHelm = CreateFrame("CheckButton", nil, frame.setFrame, "OptionsCheckButtonTemplate")
	showHelm:SetHeight(18)
	showHelm:SetWidth(18)
	showHelm:SetChecked(true)
	showHelm:SetPoint("BOTTOMLEFT", frame.setFrame, "BOTTOMLEFT", 0, 10)
	showHelm:SetScript("OnEnter", showTextTooltip)
	showHelm:SetScript("OnLeave", hideTooltip)
	showHelm:Disable()
	showHelm.tooltip = L["Show Helm"]

	showHelm.text = showHelm:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	showHelm.text:SetText(L["Helm"])
	showHelm.text:SetPoint("TOPLEFT", showHelm, "TOPRIGHT", -1, -3)
	
	frame.setFrame.showHelm = showHelm

	local showCloak = CreateFrame("CheckButton", nil, frame.setFrame, "OptionsCheckButtonTemplate")
	showCloak:SetHeight(18)
	showCloak:SetWidth(18)
	showCloak:SetChecked(true)
	showCloak:SetPoint("BOTTOMLEFT", frame.setFrame, "BOTTOMLEFT", 0, -2)
	showCloak:SetScript("OnEnter", showTextTooltip)
	showCloak:SetScript("OnLeave", hideTooltip)
	showCloak:Disable()
	showCloak.tooltip = L["Show Cloak"]

	showCloak.text = showCloak:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	showCloak.text:SetText(L["Cloak"])
	showCloak.text:SetPoint("TOPLEFT", showCloak, "TOPRIGHT", -1, -3)
	
	frame.setFrame.showCloak = showCloak
	
	-- Create new set
	local setName = CreateFrame("EditBox", "ItemSetsNewSetInput", frame.setFrame, "InputBoxTemplate")
	setName:SetHeight(19)
	setName:SetWidth(162)
	setName:SetAutoFocus(false)
	setName:ClearAllPoints()
	setName:SetPoint("BOTTOMLEFT", frame.setFrame, "BOTTOMLEFT", 6, 30)
	setName:SetScript("OnEnterPressed", createNewSet)
	setName:SetScript("OnEditFocusGained", function(self)
		self:SetText("")
		self:SetTextColor(1, 1, 1, 1)   
	end)

	setName:SetScript("OnEditFocusLost", function(self)
		if( string.trim(self:GetText()) == "" ) then
			self:SetText("New set name...")
			self:SetTextColor(0.90, 0.90, 0.90, 0.80)
		end
	end)
	setName:GetScript("OnEditFocusLost")(setName)
	
	frame.setFrame.setName = setName
	
	-- Descriptions
	frame.setFrame.description = frame.setFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	frame.setFrame.description:SetPoint("TOPLEFT", frame.setFrame, "TOPLEFT", 2, -2)
	frame.setFrame.description:SetText(L["You must type a set name in first in the text box below, and hit enter to create it.\n\nThen select it when it appears to make it editable."])
	frame.setFrame.description:SetMultilineIndent(false)
	frame.setFrame.description:SetJustifyH("LEFT")
	frame.setFrame.description:SetJustifyV("TOP")
	frame.setFrame.description:SetHeight(250)
	frame.setFrame.description:SetWidth(160)
	frame.setFrame.description:Hide()

	-- Initialize it
	self:UpdateSetRows()
	
	-- Select a default set
	local setName = ItemSets.db.profile.setName
	if( setName and ItemSets.db.profile.sets[setName] ) then
		frame.setFrame.name = setName
		selectSet(frame.setFrame)
	end
end

SLASH_ITEMSETS1 = "/is"
SLASH_ITEMSETS2 = "/itemsets"
SLASH_ITEMSETS3 = "/itemset"
SlashCmdList["ITEMSETS"] = function(msg)
	msg = msg or ""
	
	local self = ItemSets
	local cmd, arg = string.split(" ", msg, 2)
	cmd = string.lower(cmd or "")

	if( cmd == "equip" and arg ) then
		self:EquipByName(arg)
	elseif( cmd == "push" and arg ) then
		self:PushSet(arg)
	elseif( cmd == "pull" and arg ) then
		self:PullSet(arg)
	elseif( cmd == "ui" or cmd == "config" or cmd == "opt" ) then
		Config:Open()
	else
		self:Print(L["Slash commands"])
		self:Echo(L["/itemsets equip <name> - Equips a set by name."])
		self:Echo(L["/itemsets push <name> - Pushes a set from your inventory to your bank."])
		self:Echo(L["/itemsets pull <name> - Pulls a set from your bank to your inventory."])
		self:Echo(L["/itemsets ui - Opens the set interface."])
	end
end
