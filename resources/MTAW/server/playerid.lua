--------------------------------------------------------------------------------
--<[ Модуль Playerid ]>---------------------------------------------------------
--------------------------------------------------------------------------------
Playerid = {
	playerElement = {};		-- id => playerElement
	id = {};				-- playerElement => id
	
	maxPlayers = nil;

	init = function()
		Playerid.maxPlayers = getMaxPlayers()
		
		addEventHandler( "onPlayerJoin", root, Playerid.onPlayerJoin, true, "high+9001" )
		addEventHandler( "onPlayerQuit", root, Playerid.onPlayerQuit, true, "low-9001" )
	end;	
	
	--   Получить игрока с указанным ID
	--   Не вызывать в onPlayerConnect!
	-- > id number - playerid игрока
	-- = player / nil playerElement
	getPlayer = function( id )
		return Playerid.playerElement[ id ]
	end;
	
	--   Получить ID указанного игрока
	--   Не вызывать в onPlayerConnect!
	-- > playerElement player
	-- = number playerid
	getID = function( playerElement )
		return Playerid.id[ playerElement ]
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	onPlayerJoin = function()
		for i = 1, Playerid.maxPlayers do
			if ( Playerid.playerElement[ i ] == nil ) then
				Playerid.playerElement[ i ] = source
				Playerid.id[ source ] = i
				setElementData( source, "playerid", i, true )
				Debug.info( "Set playerid: " .. i )
				return nil
			end
		end
		
		Debug.error( "No slot for player" )
		kickPlayer( source, "Server is full" )
	end;
	
	onPlayerQuit = function( quitType, reason, responsibleElement )
		if ( Playerid.id[ source ] ~= nil ) then
			Playerid.playerElement[ Playerid.id[ source ] ] = nil
			Playerid.id[ source ] = nil
		end
	end;
}
addEventHandler( "onResourceStart", resourceRoot, Playerid.init )