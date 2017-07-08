--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Lobby.onClientRequestDimension", true ) 										-- Клиент запросил ID измерения лобби ()

--------------------------------------------------------------------------------
--<[ Модуль Lobby ]>------------------------------------------------------------
--------------------------------------------------------------------------------
Lobby = {
	dimension = nil;

	init = function()
		addEventHandler( "Main.onServerLoad", root, Lobby.onServerLoad )
		addEventHandler( "Lobby.onClientRequestDimension", resourceRoot, Lobby.onClientRequestDimension )
		
		Main.setModuleLoaded( "Lobby", 1 )
	end;
	
	onServerLoad = function()
		Lobby.dimension = Dimension.register( "Lobby" )
	end;
	
	-- Клиент запросил ID измерения лобби
	onClientRequestDimension = function()
		triggerClientEvent( client, "Lobby.onDimensionRequest", resourceRoot, Lobby.dimension )
	end;
};
addEventHandler( "onResourceStart", resourceRoot, Lobby.init )