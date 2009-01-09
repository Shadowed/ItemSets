local Config = ItemSets:NewModule("Config")



SLASH_ITEMSETS1 = "/is"
SLASH_ITEMSETS2 = "/itemsets"
SLASH_ITEMSETS3 = "/itemset"
SlashCmdList["ITEMSETS"] = function(msg)
	msg = msg or ""
	
	local cmd, arg1 = string.split(" ", msg, 2)
	cmd = string.lower(cmd or "")
	arg1 = string.lower(arg1 or "")
	
	local self = ItemSets
	
end
