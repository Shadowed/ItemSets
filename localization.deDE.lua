if( GetLocale() ~= "deDE" ) then
	return;
end

ItemSetLocals = setmetatable( {
}, { __index = ItemSetLocals } );