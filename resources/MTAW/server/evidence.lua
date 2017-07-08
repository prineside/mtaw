--[[
	Evidence - доказательство
--]]

--------------------------------------------------------------------------------
--<[ Модуль Evidence ]>---------------------------------------------------------
--------------------------------------------------------------------------------
Evidence = {
	init = function()
		addEventHandler( "Main.onServerLoad", resourceRoot, Evidence.onServerLoad )
	end;
	
	onServerLoad = function()
		-- Создаем тестовых ботов
		local avatars = nil
		
		if ( fileExists( "server/data/test-evidence-avatars.json" ) ) then
			avatars = fromJSON( fileGetContents( "server/data/test-evidence-avatars.json" ) )
		end
		
		if ( avatars == nil or type( avatars ) ~= "table" ) then
			avatars = {}
			
			for i = 1, 200 do
				avatars[ i ] = Avatar.generateAvatarAlias()
			end
			
			local h = fileCreate( "server/data/test-evidence-avatars.json" )
			fileWrite( h, toJSON( avatars ) )
			fileClose( h )
		end
		
		for i = 1, 200 do
			local ped = createPed( 1, math.random( -100, 100 ), math.random( -100, 100 ), 3 )
			setElementDimension( ped, Dimension.get( "Global" ) )
			--
			Avatar.setPedAvatar( ped, avatars[ ( i - 1 ) % #avatars + 1 ] )
			
			setTimer( function()
				setTimer( function()
					-- Собирает пшеницу
					Evidence.trigger( ped, EvidenceType.disruptHerb, {
						herbClass = 1;
					} )
					
					-- Иногда выбрасывает что-то (ложит в машину, не важно)
					if ( math.random() < 0.5 ) then
						Evidence.trigger( ped, EvidenceType.dropItem, {
							itemClass = "wheat";
						} )
					end
				end, math.random( 9000, 10000 ), 0 )
			end, math.random( 50, 10000 ), 1 )
			--]]
		end
	end;
	
	-- Сообщить о происшествии
	-- > playerCausedBy player
	-- > evidenceType table - из EvidenceType, например EvidenceType.herbDisruption
	-- > evidenceData mixed
	-- = void
	trigger = function( playerCausedBy, evidenceType, evidenceData )
		if not validVar( playerCausedBy, "playerCausedBy", { "player", "ped" } ) then return nil end
		if not validVar( evidenceType, "evidenceType", "table" ) then return nil end
	
		-- Превращаем в строку
		local data = {}
		for _, key in pairs( evidenceType.data ) do
			data[ #data + 1 ] = evidenceData[ key ]
		end
		data = table.concat( data, "|" )
		
		if ( Chunk.streamedInChunks[ playerCausedBy ] ~= nil ) then
			-- Стример уже обработал этого игрока
			for chunkID in pairs( Chunk.streamedInChunks[ playerCausedBy ] ) do
				for playerElement in pairs( Chunk.getPlayersInChunk( chunkID ) ) do
					triggerClientEvent( playerElement, "Evidence.onEvent", resourceRoot, playerCausedBy, evidenceType.id, data )
				end
			end
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------

};
addEventHandler( "onResourceStart", resourceRoot, Evidence.init )