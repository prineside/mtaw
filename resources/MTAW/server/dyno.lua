addEvent( "Dyno.onClientRequestDyno", true )

--------------------------------------------------------------------------------
--<[ Модуль Dyno ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
Dyno = {
	init = function()
		addEventHandler( "Main.onServerLoad", resourceRoot, Dyno.onServerLoad )
		addEventHandler( "Dyno.onClientRequestDyno", resourceRoot, Dyno.onClientRequestDyno )
	end;
	
	onServerLoad = function()
		-- Создаем трек
		local h = 200
		for x = 1000, 15900, 91.2 do
			local o = createObject( 5703, x, 1000, h )
			setElementDimension( o, Dimension.get( "Global" ) )
			
			h = h - 0.02
		end
		
		Debug.info( "Dyno loaded" )
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	onClientRequestDyno = function()
		local playerElement = client
		
		local veh = getPedOccupiedVehicle( playerElement )
		
		if ( veh ~= nil ) then
			setElementPosition( veh, 1000, 1000, 201 )
			setElementRotation( veh, 0, 0, 270 )
			
			triggerClientEvent( playerElement, "Dyno.onServerPreparedDyno", resourceRoot )
		end
	end;
};
addEventHandler( "onResourceStart", resourceRoot, Dyno.init )