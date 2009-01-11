local Config = ItemSets:NewModule("Config")



SLASH_ITEMSETS1 = "/is"
SLASH_ITEMSETS2 = "/itemsets"
SLASH_ITEMSETS3 = "/itemset"
SlashCmdList["ITEMSETS"] = function(msg)
	msg = msg or ""
	
	local self = ItemSets
	local cmd, arg = string.split(" ", msg, 2)
	cmd = string.lower(cmd or "")

	if( cmd == "equip" ) then
		ItemSets:EquipByName(arg)
	end
end
