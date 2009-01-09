--[[ 
	Item Sets, Mayen (Horde) from Icecrown (US) PvE
]]

ItemSets = LibStub("AceAddon-3.0"):NewAddon("ItemSets", "AceEvent-3.0")

local L = ItemSetLocals
local equipSlots = {"HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", 
"TabardSlot", "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", 
"Finger1Slot", "Trinket0Slot", "Trinket1Slot", "SecondaryHandSlot", "MainHandSlot", "RangedSlot", "AmmoSlot"}
local badTGWeaponType = {["Polearms"] = true, ["Staves"] = true, ["Fishing Poles"] = true}
local combatSwappable = {[0] = true, [16] = true, [17] = true, [18] = true}
local equipIDs, badItems, equipOrder, checkOnClear, lockedSlots = {}, {}, {}, {}, {}
local isBankOpen, playerClass, queuedSet

-- Bag0-3Slot

function ItemSets:OnInitialize()
	self.defaults = {
		profile = {
			sets = {}
		},
	}

	self.db = LibStub:GetLibrary("AceDB-3.0"):New("ItemSetsDB", self.defaults)
	
	-- Only call ITEM_LOCK_CHANGED every 0.25 seconds
	self:RegisterEvent("ITEM_LOCK_CHANGED", function()
		if( checkLock ) then
			ItemSets.timeElapsed = 0
			ItemSets.frame:Show()
		end
	end)
	
	-- Don't rely on BankFrame in case they customized it
	self:RegisterEvent("BANKFRAME_CLOSED", function() isBankOpen = nil end)
	self:RegisterEvent("BANKFRAME_OPENED", function() isBankOpen = true end)
	
	playerClass = select(2, UnitClass("player"))
	
	-- Do name -> id for slots
	for _, name in pairs(equipSlots) do
		table.insert(equipIDs, (GetInventorySlotInfo(name)))
		table.insert(equipOrder, (GetInventorySlotInfo(name)))
	end
end

function ItemSets:IsSpecialGem(link)
	if( not self.tooltip ) then
		self.tooltip = CreateFrame("GameTooltip", "ItemSetsGemTooltip", UIParent, "GameTooltipTemplate")
		self.tooltip:SetOwner(UIParent, "ANCHOR_NONE")
	end
	
	self.tooltip:ClearLines()
	self.tooltip:SetHyperlink(link)
	
	if( self.tooltip:NumLines() == 0 ) then
		return nil
	end

	-- Pre-WoTLK gems (Right now) we can only have one gem of this item link
	local equipType = getglobal("ItemSetsGemTooltipTextLeft3"):GetText()
	if( equipType == L["Unique-Equipped"] ) then
		return "unique", 1
	end
	
	-- Jewelers gems, max of X total don't go by links. (Maybe it should be by type? Going with jewelers type for now.)
	local type, max = string.match(equipType, L["Unique Equipped: (.+) %(([0-9]+)%)"])
	if( type and max ) then
		return "jewelers", max
	end
	
	return nil
end

-- NOTE: This will need to do a delay, due to the fact that trying to go from a 1H/Shield -> 2H won't work
-- you have to unequip the Shield, then swap the 1H/2H.
-- Check if we can swap the item in combat
-- Check if it's in one slot but should be in another, eg, in ring #1 but needs to be in ring #2
function ItemSets:Equip(name)
	local set = self.db.profile.sets[name]
	if( not set ) then
		self:Print(string.format(L["Cannot find any sets named \"%s\"."], name))
		return
	-- Remove this eventually, to just overwrite the old equip with the new (maybe?)
	elseif( swapPending ) then
		self:Print(string.format(L["Cannot equip set \"%s\", equip for set \"%s\" still pending"], name, swapPending))
		return
	end
	
	--swapPending = name
	self:ResetLocks()
	
	-- Check what the class can use
	local hasTitansGrip, canUseOH
	if( playerClass == "WARRIOR" ) then
		canUseOH = true
		hasTitansGrip = (select(5, GetTalentInfo(2, 26)) > 0)
	elseif( playerClass == "ROGUE" or playerClass == "HUNTER" or playerClass == "DEATHKNIGHT" ) then
		canUseOH = true
	end
	
	-- Reset our equip order to default
	for k, v in pairs(equipIDs) do equipOrder[k] = v end
		
	-- If the player has the Titan's Grip talent, and there MH is an invalid TG weapon we must swap the MH first, then the OH
	if( hasTitansGrip and badTGWeaponType[select(7, GetItemInfo(GetInventoryItemLink("player", 16)))] ) then
		equipOrder[17] = 16
		equipOrder[18] = 17
	end
	
	-- If we're in combat, only let us swap certain items (Ranged, MH, Ammo)
	if( InCombatLockdown() ) then
		for i=#(equipOrder), 1, -1 do
			if( not combatSwappable[equipOrder[i]] ) then
				table.remove(equipOrder, i)
			end
		end
	end
	
	-- Go through and do a quick check before running actual thingys
	for i=#(equipOrder), 1, -1 do
		local inventoryID = equipOrder[i]
		local inventoryLink = GetInventoryItemLink("player", inventoryID)
		local link = set[inventoryID]
		
		-- Item already equipped, so we can remove it from the list
		if( self:GetBaseData(inventoryLink) == link ) then
			table.remove(equipOrder, i)
		
		-- Check if it has a prismatic gem, and we should unequip the item fully
		elseif( inventoryLink ) then
			for i=1, 3 do
				local gemLink = select(2, GetItemGem(inventoryLink, i))
				if( gemLink and self:IsSpecialGem(gemLink) ) then
					local freeBag, freeSlot = self:FindEmptyInventorySlot()
					if( not freeBag or not freeSlot ) then
						self:Print(L["Cannot perform swap, you have no space in your bags left."])
						break
					end
					
					self:LockSlot(freeBag, freeSlot)
					
					PickupInventoryItem(inventoryID)
					PickupContainerItem(freeBag, freeSlot)
					
					-- If we know the location of item we're going to equip it, then will put ours there
					-- after we're done, otherwise we set it to be compacted.
					local bag, slot = self:FindItem(link)
					if( bag and slot ) then
						checkOnClear[inventoryLink] = bag .. ":" .. slot
						
						-- Also lock it up
						self:LockSlot(bag, slot)
					else
						checkOnClear[inventoryLink] = true
					end
					
					checkLock = true
					break
				end
			end
		end
	end
	
	-- Equip it all
	for _, inventoryID in pairs(equipOrder) do
		local link = set[inventoryID]
		local bag, slot, type = self:FindItem(link)
		
		if( bag and slot ) then
			PickupContainerItem(bag, slot)
			EquipCursorItem(inventoryID)
			
			-- Do we really need this?
			if( select(1, GetCursorInfo()) == "item" ) then
				local freeBag, freeSlot = self:FindEmptyInventorySlot()
				if( not freeBag or not freeSlot ) then
					self:Print(L["Cannot perform swap, you have no space in your bags left."])
					break
				end

				self:LockSlot(freeBag, freeSlot)
				PickupContainerItem(freeBag, freeSlot)
			end
		
		-- Nothing supposed to be here, swap it to inventory
		elseif( link == "" ) then
			PickupInventoryItem(inventoryID)

			if( select(1, GetCursorInfo()) == "item" ) then
				local freeBag, freeSlot = self:FindEmptyInventorySlot()
				if( not freeBag or not freeSlot ) then
					self:Print(L["Cannot perform swap, you have no space in your bags left."])
					break
				end

				self:LockSlot(freeBag, freeSlot)
				PickupContainerItem(freeBag, freeSlot)
			end
		-- Couldn't find item in bags
		elseif( link and link ~= "" ) then
			print(inventoryID, link or "nil")
			local validLink = select(2, GetItemInfo(string.format("item:%s", link)))
			table.insert(badItems, validLink or "<bad link>")
		end
	end
		
	-- Unable to equip some items
	if( #(badItems) > 0 ) then
		local items = table.concat(badItems, " ")
		self:Print(string.format(L["Unable to equip the following items for the set \"%s\": %s"], name, items))

		for i=#(badItems), 1, -1 do table.remove(badItems, i) end
	end
end

-- Throttle our ITEM_LOCK_CHANGED calls
ItemSets.frame = CreateFrame("Frame")
ItemSets.frame.timeElapsed = 0
ItemSets.frame:Hide()
ItemSets.frame:SetScript("OnUpdate", function(self, elapsed)
	self.timeElapsed = self.timeElapsed + elapsed

	if( self.timeElapsed >= 0.25 ) then
		ItemSets:ITEM_LOCK_CHANGED()

		self.timeElapsed = 0
		self:Hide()
	end
end)

-- Now we can check if we need to move any items around
function ItemSets:ITEM_LOCK_CHANGED()
	if( checkLock ) then
		local total = 0
		
		for link, info in pairs(checkOnClear) do
			local bag, slot, location = self:FindItem(self:GetBaseData(link))
			if( location == "inventory" ) then
				total = total - 1
				checkOnClear[link] = nil
				
				-- If it's a boolean, find a spare slot, if it's not, use the one provided
				local freeBag, freeSlot
				if( type(info) == "boolean" ) then
					freeBag, freeSlot = self:FindEmptyInventorySlot()
				else
					freeBag, freeSlot = string.split(":", info)
				end
				
				-- Find it!
				if( freeBag and freeSlot ) then
					self:LockSlot(freeBag, freeSlot)
					self:UnlockSlot(bag, slot)
					
					PickupContainerItem(bag, slot)
					PickupContainerItem(freeBag, freeSlot)
				end
			end

			total = total + 1
		end
		
		if( total == 0 ) then
			checkLock = nil
		end
	end
end

-- Strips out the random junk from the link, all we want is the id/misc meta data
function ItemSets:GetBaseData(link)
	if( not link ) then return "" end
	return string.match(link, "|Hitem:(.-)|h")
end

function ItemSets:IsContainer(bagID)
	return bagID == 0 or bagID == -1 or GetItemFamily(GetInventoryItemLink("player", bagID)) == 0
end

-- Find an item
function ItemSets:FindItem(baseID)
	if( not baseID or baseID == "" ) then
		return nil, nil, nil
	end
	
	for bag=4, 0, -1 do
		if( self:IsContainer(bag) ) then
			for slot=1, GetContainerNumSlots(bag) do
				if( self:GetBaseData(GetContainerItemLink(bag, slot)) == baseID ) then
					return bag, slot, "inventory"
				end
			end
		end
	end
	
	-- Can't find it, and bank is open so check there
	if( isBankOpen ) then
		for _, bag in pairs(bankSlots) do
			if( self:IsContainer(bag) ) then
				for slot=1, GetContainerNumSlots(bag) do
					if( self:GetBaseData(GetContainerItemLink(bag, slot)) == baseID ) then
						return bag, slot, "bank"
					end
				end
			end
		end
	end
	
	return nil, nil, nil
end

-- Find out where we can place something, if we can.
function ItemSets:FindEmptyInventorySlot()
	-- We do 4 -> 0 so that it places it in our last bag first instead of backpack
	-- mostly, cause I'm picky as fuck
	for bag=4, 0, -1 do
		if( self:IsContainer(bag)  ) then
			for slot=1, GetContainerNumSlots(bag) do
				if( not GetContainerItemLink(bag, slot) and not self:IsLocked(bag, slot) ) then
					return bag, slot
				end
			end
		end
	end
	
	return nil, nil
end

local bankSlots = {11, 10, 9, 8, 7, 6, 5, -1}
function ItemSets:FindEmptyBankSlot()
	for _, bag in pairs(bankSlots) do
		if( self:IsContainer(bag)  ) then
			for slot=1, GetContainerNumSlots(bag) do
				if( not GetContainerItemLink(bag, slot) and not self:IsLocked(bag, slot) ) then
					return bag, slot
				end
			end
		end
	end
	
	return nil, nil
end	

-- Managing if a slot is locked or not
function ItemSets:IsLocked(bag, slot)
	return lockedSlots[bag .. slot]
end

function ItemSets:LockSlot(bag, slot)
	lockedSlots[bag .. slot] = true
end

function ItemSets:UnlockSlot(bag, slot)
	lockedSlots[bag .. slot] = nil
end

-- Reset locks
function ItemSets:ResetLocks()
	for k in pairs(lockedSlots) do
		lockedSlots[k] = nil
	end
end

-- Debug
function ItemSets:Save(name)
	local set = self.db.profile.sets[name] or {}
	for id in pairs(set) do set[id] = nil end
	
	for _, id in pairs(equipIDs) do
		local link = GetInventoryItemLink("player", id)
		if( link ) then
			set[id] = self:GetBaseData(link)
		else
			set[id] = ""
		end
	end
	
	
	self.db.profile.sets[name] = set
end

function ItemSets:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ItemSets|r: " .. msg)
end