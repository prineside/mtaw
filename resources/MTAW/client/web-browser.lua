--------------------------------------------------------------------------------
--<[ Модуль WebBrowser ]>-------------------------------------------------------
--------------------------------------------------------------------------------
WebBrowser = {
	browser = nil;

	init = function()
		Main.setModuleLoaded( "WebBrowser", 1 )
		
		addEventHandler( "Main.onClientLoad", resourceRoot, function()
			-- TODO
		end )
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, WebBrowser.init )