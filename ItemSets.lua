--[[ 
	Item Sets, Mayen (Horde) from Icecrown (US) PvE
]]

ItemSets = LibStub("AceAddon-3.0"):NewAddon("ItemSets", "AceEvent-3.0")

local L = ItemSetLocals
local equipSlots = {["HeadSlot"] = -1, ["NeckSlot"] = -1, ["ShoulderSlot"] = -1, ["BackSlot"] = -1, ["ChestSlot"] = -1, ["ShirtSlot"] = -1, 
["TabardSlot"] = -1, ["WristSlot"] = -1, ["HandsSlot"] = -1, ["WaistSlot"] = -1, ["LegsSlot"] = -1, ["FeetSlot"] = -1, ["Finger0Slot"] = -1, 
["Finger1Slot"] = -1, ["Trinket0Slot"] = -1, ["Trinket1Slot"] = -1, ["SecondaryHandSlot"] = -1, ["MainHandSlot"] = -1, ["RangedSlot"] = -1, ["AmmoSlot"] = -1}
local badTGWeaponType = {["Polearms"] = true, ["Staves"] = true, ["Fishing Poles"] = true}
local combatSwappable = {[0] = true, [16] = true, [17] = true, [18] = true}
local bankSlots = {11, 10, 9, 8, 7, 6, 5, -1}
local equipIDs, badItems, equipOrder, checkOnClear, lockedSlots = {}, {}, {}, {}, {}
local playerClass, equipQueued

function ItemSets:OnInitialize()
	self.defaults = {
		profile = {
			queued = {},
			sets = {}
		},
	}

	self.db = LibStub:GetLibrary("AceDB-3.0"):New("ItemSetsDB", self.defaults)
	
	-- Throttle ITEM_LOCK_CHANGED calls
	self:RegisterEvent("ITEM_LOCK_CHANGED", function()
		if( checkLock ) then
			ItemSets.timeElapsed = 0
			ItemSets.frame:Show()
		end
	end)
	
	-- Don't rely on BankFrame in case they customized it
	self:RegisterEvent("BANKFRAME_CLOSED", function() ItemSets.isBankOpen = nil end)
	self:RegisterEvent("BANKFRAME_OPENED", function() ItemSets.isBankOpen = true end)
	
	-- Deal with set queues
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "CheckEquipQueue")
	self:RegisterEvent("PLAYER_UNGHOST", "CheckEquipQueue")
	
	playerClass = select(2, UnitClass("player"))
	
	self.equipSlots = equipSlots
	self.equipIDs = equipIDs
	self.bankSlots = bankSlots
	
	-- Do name -> id for slots
	for name in pairs(equipSlots) do
		local id = GetInventorySlotInfo(name)
		
		equipSlots[name] = id
		table.insert(equipIDs, id)
	end
end

-- Put a set from your inventory, into your bank
function ItemSets:PushSet(name)
	if( not self.isBankOpen ) then
		self:Print("Your bank must be open to perform this action.")
		return
	end
	
	local set = self.db.profile.sets[name]
	if( not set ) then
		self:Print(string.format(L["Cannot find any sets named \"%s\"."], name))
		return
	end
	
	-- Quick check, make sure we have enough free space
	local totalItems = 0
	for _, link in pairs(set) do
		local bag, slot, location = self:FindItem(link)
		if( ( bag and slot and location == "inventory" ) or IsEquippedItem(link) ) then
			totalItems = totalItems + 1
		end
	end
	
	-- Figure out how much space we have in our bank
	local freeSlots = 0
	for _, bag in pairs(bankSlots) do
		if( self:IsContainer(bag) ) then
			freeSlots = freeSlots + (GetContainerNumFreeSlots(bag))	
		end
	end
	
	-- Nope! :(
	if( totalItems == 0 ) then
		self:Print(string.format(L["Cannot push set \"%s\" from bank, nothing in there to get."], name))
		return
	elseif( freeSlots < totalItems ) then
		self:Print(string.format(L["Cannot perform push on set \"%s\", requires %d slots open, you only have %d available in your bank."], name, totalItems, freeSlots))
		return
	end
	
	-- Start pushing
	self:ResetLocks()

	for _, link in pairs(set) do
		if( IsEquippedItem(link) ) then
			for _, inventoryID in pairs(equipSlots) do
				if( self:GetBaseData(GetInventoryItemLink("player", inventoryID)) == link ) then
					local freeBag, freeSlot = self:FindEmptyBankSlot()
					self:LockSlot(freeBag, freeSlot)
					
					PickupInventoryItem(inventoryID)
					PickupContainerItem(freeBag, freeSlot)
					break
				end
			end
		else
			local bag, slot, location = self:FindItem(link)
			if( bag and slot and location == "inventory" ) then
				local freeBag, freeSlot = self:FindEmptyBankSlot()
				
				self:UnlockSlot(bag, slot)
				self:LockSlot(freeBag, freeSlot)

				PickupContainerItem(bag, slot)
				PickupContainerItem(freeBag, freeSlot)
			end
		end
	end
	
	self:Print(string.format(L["Pushed set \"%s\" into your bank."], name))
end
-- Bring a set from your bank, into your inventory
function ItemSets:PullSet(name)
	if( not self.isBankOpen ) then
		self:Print("Your bank must be open to perform this action.")
		return
	end
	
	local set = self.db.profile.sets[name]
	if( not set ) then
		self:Print(string.format(L["Cannot find any sets named \"%s\"."], name))
		return
	end
	
	-- Quick check, make sure we have enough free space
	local totalItems = 0
	for _, link in pairs(set) do
		
		local bag, slot, location = self:FindItem(link)
		if( bag and slot and location == "bank" ) then
			totalItems = totalItems + 1
		end
	end
	
	-- Figure out how much space we have in our bank
	local freeSlots = 0
	for bag=4, 0, -1 do
		if( self:IsContainer(bag) ) then
			freeSlots = freeSlots + (GetContainerNumFreeSlots(bag))
		end
	end
	
	-- Nope! :(
	if( totalItems == 0 ) then
		self:Print(string.format(L["Cannot pull set \"%s\" from bank, nothing in there to get."], name))
		return
	elseif( freeSlots < totalItems ) then
		self:Print(string.format(L["Cannot perform pull on set \"%s\", requires %d slots open, you only have %d available in your inventory."], name, totalItems, freeSlots))
		return
	end
	
	-- Start pulling
	self:ResetLocks()

	for _, link in pairs(set) do
		local bag, slot, location = self:FindItem(link)
		if( bag and slot and location == "bank" ) then
			local freeBag, freeSlot = self:FindEmptyInventorySlot()
			
			self:UnlockSlot(bag, slot)
			self:LockSlot(freeBag, freeSlot)

			PickupContainerItem(bag, slot)
			PickupContainerItem(freeBag, freeSlot)
		end
	end

	self:Print(string.format(L["Pulled set \"%s\" into your inventory."], name))
end

-- Any sort of unique gem in this link?
function ItemSets:IsSpecialGem(link)
	if( not self.tooltip ) then
		self.tooltip = CreateFrame("GameTooltip", "ItemSetsScanTooltip", UIParent, "GameTooltipTemplate")
		self.tooltip:SetOwner(UIParent, "ANCHOR_NONE")
	end
	
	self.tooltip:ClearLines()
	self.tooltip:SetHyperlink(link)
	
	if( self.tooltip:NumLines() == 0 ) then
		return nil
	end

	-- Pre-WoTLK gems (Right now) we can only have one gem of this item link
	local equipType = getglobal("ItemSetsScanTooltipTextLeft3"):GetText()
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

-- Left combat, or we're alive, check queue
local FEIGN_DEATH = GetSpellInfo(5384)
function ItemSets:IsDead()
	local id = 1
	while( true ) do
		local name = UnitBuff("player", id)
		if( not name ) then break end
		
		if( name == FEIGN_DEATH ) then
			return false
		end
		
		id = id + 1
	end
	
	return UnitIsDeadOrGhost("player")
end

function ItemSets:CheckEquipQueue()
	-- Do we really need to check combat?
	if( not self.db.profile.queued.active or InCombatLockdown() or self:IsDead() ) then
		return
	end
	
	-- Equip it
	self:Equip(self.db.profile.queued, "Queued")

	-- Queued set complete, reset it
	for k in pairs(self.db.profile.queued) do self.db.profile.queued[k] = nil end
	self.modules.Character:UpdateQueuedItems()
end

-- Equip a single item into a slot
function ItemSets:EquipSingle(equipSlot, link)
	local inventoryID = equipSlots[equipSlot]
	
	-- Make sure we can equip it right now
	if( self:IsDead() or InCombatLockdown() ) then
		-- If we don't have a queue active, reset it
		if( not self.db.profile.queued.active ) then
			for k in pairs(self.db.profile.queued) do self.db.profile.queued[k] = nil end
		end
		
		-- Set it as queued
		self.db.profile.queued.active = true
		self.db.profile.queued[inventoryID] = link
		
		-- Update queued icon
		self.modules.Character:UpdateQueuedItems()
		return
	end
	
	-- Unequipping
	if( link == "" ) then
		local freeBag, freeSlot = self:FindEmptyInventorySlot()
		self:LockSlot(freeBag, freeSlot)
		
		PickupInventoryItem(inventoryID)
		PickupContainerItem(freeBag, freeSlot)
		return
	end
	
	-- Equipping!
	local bag, slot = self:FindItem(link)
	if( not bag or not slot ) then
		return
	end
	
	PickupContainerItem(bag, slot)
	PickupInventoryItem(inventoryID)
end

-- NOTE: This will need to do a delay, due to the fact that trying to go from a 1H/Shield -> 2H won't work
-- you have to unequip the Shield, then swap the 1H/2H.
-- Check if we can swap the item in combat
-- Check if it's in one slot but should be in another, eg, in ring #1 but needs to be in ring #2
function ItemSets:EquipByName(name)
	local set = self.db.profile.sets[name]
	if( not set ) then
		self:Print(string.format(L["Cannot find any sets named \"%s\"."], name))
		return
	end
	
	self:Equip(self.db.profile.sets[name], name)
end

function ItemSets:Equip(set, name)
	self:ResetLocks()
	
	-- Check what the class can use
	local hasTitansGrip
	if( playerClass == "WARRIOR" ) then
		hasTitansGrip = (select(5, GetTalentInfo(2, 26)) > 0)
	end
	
	-- Reset our equip order to default
	for k, v in pairs(equipIDs) do equipOrder[k] = v end
		
	-- If the player has the Titan's Grip talent, and there MH is an invalid TG weapon we must swap the MH first, then the OH
	if( hasTitansGrip and badTGWeaponType[select(7, GetItemInfo(GetInventoryItemLink("player", 16)))] ) then
		equipOrder[17] = 16
		equipOrder[18] = 17
	end
	
	-- If we're in combat, only let us swap certain items (Ranged, MH, Ammo)
	local isDead = self:IsDead()
	if( InCombatLockdown() or isDead ) then
		for k in pairs(self.db.profile.queued) do self.db.profile.queued[k] = nil end
		
		for i=#(equipOrder), 1, -1 do
			local invID = equipOrder[i]
			if( not combatSwappable[invID] or isDead ) then
				
				self.db.profile.queued[invID] = set[invID]
				table.remove(equipOrder, i)
				
				-- If this set has an actual item thats supposed to be here, will set it to be equipped when combat drops
				if( set[invID] ) then
					self.db.profile.queued.active = true
				end
			end
		end
		
		if( self.db.profile.queued.active ) then
			self.db.profile.queued.helm = set.helm
			self.db.proifle.queued.cloak = set.cloak
		
			self.modules.Character:UpdateQueuedItems()
		end
	end
	
	-- Nothing we can equip while in combat, or dead.
	if( #(equipOrder) == 0 ) then
		return
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
		elseif( inventoryLink and link and link ~= "" ) then
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
			table.insert(badItems, (select(2, GetItemInfo(link))) or "<bad link>")
		end
	end
	
	-- Helm/Cloak shows
	ShowHelm(set.helm)
	ShowCloak(set.cloak)
			
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

	if( self.timeElapsed >= 0.50 ) then
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
	if( not link or link == "" ) then return "" end
	return string.match(link, "|H(.-)|h")
end

function ItemSets:IsContainer(bagID)
	return bagID == 0 or bagID == -1 or GetItemFamily(GetInventoryItemLink("player", ContainerIDToInventoryID(bagID))) == 0
end

-- Find an item
function ItemSets:FindItem(baseID)
	if( type(baseID) ~= "string" or baseID == "" ) then
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
	if( self.isBankOpen ) then
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

function ItemSets:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ItemSets|r: " .. msg)
end

function ItemSets:Echo(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg)
end
