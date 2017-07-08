--[[
	Локальный чат
--]]

--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "LocalChat.onClientSayAttempt", true )								-- Клиент отправил сообщение в локальынй чат ( string message, string loudness )

--------------------------------------------------------------------------------
--<[ Модуль LocalChat ]>--------------------------------------------------------
--------------------------------------------------------------------------------
LocalChat = {
	init = function()
		addEventHandler( "Main.onServerLoad", resourceRoot, LocalChat.onServerLoad )
	end;
	
	onServerLoad = function()
		addEventHandler( "LocalChat.onClientSayAttempt", resourceRoot, LocalChat.onClientSayAttempt )
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Клиент сделал попытку сказать что-то в локальный чат
	onClientSayAttempt = function( message, loudness )
		if not validVar( message, "message", "string" ) then return nil end
		if not validVar( loudness, "loudness", "string" ) then return nil end
		
		local playerElement = client
		local px, py, pz = getElementPosition( playerElement )
		local pdim = getElementDimension( playerElement )
		local avatarAlias = Avatar.getPedAvatar( playerElement )
		
		local tx, ty, tz, tdim, dist, loudnessCoeff
		
		local maxRadius
		if ( loudness == "whisper" ) then
			maxRadius = 5
		elseif ( loudness == "shout" ) then
			maxRadius = 80
		else
			loudness = "normal"
			maxRadius = 25
		end
		
		-- Находим всех игроков в радиусе вокруг игрока
		local streamedChunks = Chunk.streamedInChunks[ playerElement ]
		for chunkID in pairs( streamedChunks ) do
			local playersInChunk = Chunk.getPlayersInChunk( chunkID )
			
			for otherPlayer in pairs( playersInChunk ) do
				tx, ty, tz = getElementPosition( otherPlayer )
				tdim = getElementDimension( otherPlayer )
				
				if ( tdim == pdim ) then
					dist = getDistanceBetweenPoints3D( tx, ty, tz, px, py, pz )
					if ( dist < maxRadius ) then
						loudnessCoeff = ( maxRadius - dist ) / maxRadius
						
						triggerClientEvent( otherPlayer, "LocalChat.onMessage", resourceRoot, avatarAlias, message, loudness, loudnessCoeff )
					end
				end
			end
		end
	end;
};
addEventHandler( "onResourceStart", resourceRoot, LocalChat.init )