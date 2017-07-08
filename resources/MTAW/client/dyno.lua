--[[
	Dyno
	Замер характеристик транспортных средств
	
	Дорога: 5703
	x += 91.2
--]]
addEvent( "Dyno.onServerPreparedDyno", true )

--------------------------------------------------------------------------------
--<[ Модуль Dyno ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
Dyno = {
	vehicle = nil;
	
	valueFormat = {
		["dragCoeff"] = 4,
		["numberOfGears"] = 0, 
		["maxVelocity"] = 1, 
		["engineAcceleration"] = 4, 
		["engineInertia"] = 2, 
		["driveType"] = "s",
		["mass"] = 0, 
		["turnMass"] = 0,
		["tractionMultiplier"] = 4, 
		["tractionLoss"] = 4, 
		["tractionBias"] = 4,
		["brakeDeceleration"] = 4, 
		["brakeBias"] = 4,
		["percentSubmerged"] = 1,
		["steeringLock"] = 1, 
		["suspensionForceLevel"] = 4, 
		["suspensionDamping"] = 4, 
		["suspensionHighSpeedDamping"] = 4, 
		["suspensionUpperLimit"] = 4, 
		["suspensionLowerLimit"] = 4, 
		["suspensionFrontRearBias"] = 4, 
		["suspensionAntiDiveMultiplier"] = 4 
	};
	
	listedKeys = {
		"[Performance]",
		"dragCoeff",
		"numberOfGears",
		"maxVelocity",
		"engineAcceleration",
		"engineInertia",
		"driveType",
		
		"[Mass]",
		"mass",
		"turnMass",
		
		"[Traction]",
		"tractionMultiplier",
		"tractionLoss",
		"tractionBias",
		
		"[Brakes]",
		"brakeDeceleration",
		"brakeBias",
		
		"[Suspension]",
		"percentSubmerged",
		"steeringLock",
		"suspensionForceLevel",
		"suspensionDamping",
		"suspensionHighSpeedDamping",
		"suspensionUpperLimit",
		"suspensionLowerLimit",
		"suspensionFrontRearBias",
		"suspensionAntiDiveMultiplier"
	};
	
	debugLine = {
		width = 412;
		height = 18;
		
		left = 0;
		top = 0;
		current = 0;
	};
	
	colors = {
		0xAA00FF00, 0xAAFF0000, 0xAA44AAFF, 0xAAFFFF00
	};
	
	currentDynoColor = 0;
	dyno = {
		isRunning = false;
		lastGear = 1;
		startTick = nil;
		log = {};				-- [] => ms, type, value
		gearUpSpeed = {};		-- gear => speed
		hundredKmphTime = 0;	-- ms
		maxSpeed = 0;			-- заодно и lastSpeed
		endTick = nil;			-- заодно и время достижения maxSpeed
		speed = {};				-- [] => { tick, speed }
		
		quarterTime = nil;		-- 402.336 m
		quarterSpeed = nil;		
	};
	dynoHandling = nil;			-- handling при dyno
	
	dynos = {};					-- [] => { dyno, color, handling }
	
	listedKeysCount = nil;

	init = function()
		addEventHandler( "Main.onClientLoad", resourceRoot, Dyno.onClientLoad )
	end;
	
	onClientLoad = function()
		
		Dyno.listedKeysCount = #Dyno.listedKeys
		
		addEventHandler( "onClientPlayerVehicleEnter", localPlayer, Dyno.onClientPlayerVehicleEnter )
		addEventHandler( "onClientPlayerVehicleExit", localPlayer, Dyno.onClientPlayerVehicleExit )
		addEventHandler( "Dyno.onServerPreparedDyno", resourceRoot, Dyno.onServerPreparedDyno )
		
		Command.add( "dyno", "none", "<command>", "/dyno prepare телепортирует на трек, /dyno start начинает тест", function( cmd, action )
			if ( action == "p" or action == "prepare" ) then
				Chat.addMessage( "Подготовка Dyno-теста..." )
				Dyno.prepare()
			elseif ( action == "s" or action == "start" ) then
				Chat.addMessage( "Запуск Dyno-теста..." )
				Dyno.start()
			elseif ( action == "f" or action == "finish" ) then
				Dyno.stop()
			elseif ( action == "r" or action == "reset" ) then
				Dyno.dynos = {}
			else
				Chat.addMessage( "Использование:" )
				Chat.addMessage( " /dyno p[repare] - подготовить тест (перед стартом)" )
				Chat.addMessage( " /dyno s[tart] - начать тест (сначала необходимо prepare)" )
				Chat.addMessage( " /dyno f[inish] - закончить тест" )
				Chat.addMessage( " /dyno r[eset] - сбросить существующие графики" )
			end
		end )
	end;
	
	-- Подготовить тест Дино
	prepare = function()
		Debug.info( "Supra 1997 TS - 109mph (176 km/h), 13.1s, 320 hp, 3417 lbs (1550 kg)" )
		Debug.info( "By elapsed time:", Dyno.getHorsepowerET( 1550, 13.1 ) )
		Debug.info( "By trap spped:  ", Dyno.getHorsepowerTS( 1550, 176 ) )
		
		Debug.info( "Fastest (~3000 hp, 1400 kg) by trap spped:  ", Dyno.getHorsepowerTS( 1400, 386 ) )
		Debug.info( "Fastest (~3000 hp, 1400 kg) by elapsed time:", Dyno.getHorsepowerET( 1400, 6.05 ) )
		
		triggerServerEvent( "Dyno.onClientRequestDyno", resourceRoot, ghostModel, ghostHandling )
	end;
	
	-- Запустить тест Дино
	start = function()
		if ( not Dyno.dyno.isRunning ) then
			setControlState( "accelerate", true )
			--Control.disableAll( "Dyno" )
			
			Dyno.dyno.isRunning = true
			Dyno.dyno.lastGear = 1
			Dyno.dyno.log = {}
			Dyno.dyno.gearUpSpeed = {}
			Dyno.dyno.hundredKmphTime = 0
			Dyno.dyno.maxSpeed = -1
			Dyno.dyno.maxSpeedTime = 0
			Dyno.dyno.isRunning = true
			Dyno.dyno.startTick = getTickCount()
			Dyno.dyno.endTick = nil
			Dyno.dyno.lastSpeedSaveTime = 0
			Dyno.dyno.speed = {}
			Dyno.dyno.quarterTime = nil
			Dyno.dyno.quarterSpeed = nil
			
			Dyno.dynos[ #Dyno.dynos % #Dyno.colors + 1 ] = nil
			Dyno.currentDynoColor = Dyno.colors[ #Dyno.dynos % #Dyno.colors + 1 ];
			
			addEventHandler( "onClientRender", root, Dyno._processDyno )
		else
			Chat.addMessage( "Тест уже запущен, введите /dyno f, чтобы остановить" )
		end		
	end;
	
	-- Остановить тест Дино
	stop = function()
		--Control.cancelDisablingAll( "Dyno" )
		setControlState( "accelerate", false )
			
		Chat.addMessage( "Тест завершен" )
		Dyno.dyno.isRunning = false
		Dyno.dyno.endTick = getTickCount()
		
		Dyno.dynos[ ( #Dyno.dynos ) % 4 + 1 ] = {
			dyno = tableCopy( Dyno.dyno );
			color = Dyno.currentDynoColor;
			handling = getVehicleHandling( Dyno.vehicle );
		}
		
		removeEventHandler( "onClientRender", root, Dyno._processDyno )
	end;
	
	_processDyno = function()
		local testTime = getTickCount() - Dyno.dyno.startTick
	
		local vX, vY, vZ = getElementVelocity( Dyno.vehicle )
		local speed = math.sqrt( math.pow( vX, 2 ) + math.pow( vY, 2 ) + math.pow( vZ, 2 ) ) * 180
		
		if ( speed <= Dyno.dyno.maxSpeed and speed > 5 and Dyno.dyno.quarterTime ~= nil ) then
			Dyno.stop()
		else
			
			local gear = getVehicleCurrentGear( Dyno.vehicle )
			if ( gear < 1 ) then gear = 1 end
			
			if ( Dyno.dyno.lastGear ~= gear ) then
				Dyno.dyno.log[ #Dyno.dyno.log + 1 ] = {
					testTime,
					"gear",
					gear
				}
				Dyno.dyno.gearUpSpeed[ gear ] = speed
				
				Dyno.dyno.lastGear = gear
			end
			
			if ( Dyno.dyno.maxSpeed < 100 and speed >= 100 ) then
				Dyno.dyno.hundredKmphTime = testTime
			end
			
			local posX = getElementPosition( Dyno.vehicle )
			local dist = posX - 1000
			
			if ( Dyno.dyno.quarterTime == nil and dist > 402.336 ) then
				Dyno.dyno.quarterTime = testTime
				Dyno.dyno.quarterSpeed = speed
			end
			
			Dyno.dyno.speed[ #Dyno.dyno.speed + 1 ] = {
				testTime,
				speed
			}
			
			Dyno.dyno.maxSpeed = speed
		end
	end;
	
	-- Возвращает кол-во лошадиных сил по методу Elapsed Time (время прохождения четверти мили)
	-- > weight number - вес машины (кг)
	-- > number elapsedTime - время прохождения четверти мили (c)
	getHorsepowerET = function( weight, elapsedTime )
		-- weight / math.pow( elapsedTime / 5.825, 3 )
		-- weight in lbs
		-- elapsedTime in s
		elapsedTime = elapsedTime / 5.825
		return ( weight * 2.20462 ) / ( elapsedTime * elapsedTime * elapsedTime )
	end;
	
	-- Возвращает кол-во лошадиных сил по методу Trap-Speed (скорость на финише четверти мили)
	-- > weight number - вес машины (кг)
	-- > number speed - скорость машины на финише четверти мили (км/ч)
	getHorsepowerTS = function( weight, speed )
		-- weight * math.pow( speed / 234, 3 )
		-- weight in lbs
		-- speed in mph
		return ( weight * 2.20462 ) * math.pow( ( speed * 0.621371 ) / 234, 3 )
	end;
	
	_renderDebugLine = function( str, align )
		if ( align == nil ) then align = "right" end
		
		dxDrawText( str, Dyno.debugLine.left, Dyno.debugLine.top + ( Dyno.debugLine.current * Dyno.debugLine.height ), Dyno.debugLine.left + Dyno.debugLine.width, nil, 0xFFCCCCCC, 1, Debug._debugScreenFont, align, nil, false, false, true, true )
		Dyno.debugLine.current = Dyno.debugLine.current + 1
	end;
	
	_renderDynoGraph = function( gx, gy, width, data, color )
		local height = 500
		local maxDuration = 30000
		local tickWidth = width / maxDuration
		
		local lastT = 0
		local lastS = 0
		for _, speedData in pairs( data.speed ) do
			local t = speedData[ 1 ]
			local s = speedData[ 2 ]
			
			if ( t < maxDuration ) then
				local sx = gx + ( lastT * tickWidth )
				local ex = gx + ( t * tickWidth )
				local sy = gy + ( height - lastS )
				local ey = gy + ( height - s )
				
				dxDrawLine( sx, sy, ex, ey, color )
			end
			
			lastT = t
			lastS = s
		end
		
		local sx = gx + ( lastT * tickWidth )
		local ex = gx + width
		local sy = gy + ( height - lastS )
		local ey = sy
				
		dxDrawLine( sx, sy, ex, ey, color )
	end;
	
	_renderDynoStats = function( gx, gy, data, color, weight )
		local line = 0
		local lineHeight = 18
		
		dxDrawText( number_format( data.hundredKmphTime / 1000, 2 ) .. " s", gx, gy + line * lineHeight, nil, nil, color, 1, Debug._debugScreenFont )
		line = line + 1
		
		dxDrawText( number_format( data.maxSpeed, 2 ) .. " km/h", gx, gy + line * lineHeight, nil, nil, color, 1, Debug._debugScreenFont )
		line = line + 1
		
		if ( data.endTick ~= nil ) then
			dxDrawText( number_format( ( data.endTick - data.startTick ) / 1000, 2 ) .. " s", gx, gy + line * lineHeight, nil, nil, color, 1, Debug._debugScreenFont )
		end
		line = line + 1
		
		if ( data.quarterSpeed ~= nil ) then
			dxDrawText( number_format( data.quarterSpeed, 2 ) .. " km/h", gx, gy + line * lineHeight, nil, nil, color, 1, Debug._debugScreenFont )
		end
		line = line + 1
		
		if ( data.quarterSpeed ~= nil ) then
			dxDrawText( number_format( data.quarterTime / 1000, 2 ) .. " s", gx, gy + line * lineHeight, nil, nil, color, 1, Debug._debugScreenFont )
		end
		line = line + 1
		
		if ( data.endTick ~= nil ) then
			local etHP = math.floor( Dyno.getHorsepowerET( weight, data.quarterTime / 1000 ) )
			local tsHP = math.floor( Dyno.getHorsepowerTS( weight, data.quarterSpeed ) )
			
			dxDrawText( etHP .. " / " .. tsHP, gx, gy + line * lineHeight, nil, nil, color, 1, Debug._debugScreenFont )
		end
		line = line + 1
		
	end;
	
	_render = function()
		if ( not Debug.debugMonitorEnabled or not Debug.debugMonitorLiteMode ) then
			return nil
		end
		
		-- GUI.screenSize.x / 2 GUI.screenSize.y
		local handling = getVehicleHandling( Dyno.vehicle )
		local originalHandling = getOriginalHandling( getElementModel( Dyno.vehicle ) )
		
		local linesCount = Dyno.listedKeysCount + 7
		
		Dyno.debugLine.current = 0
		Dyno.debugLine.top = GUI.screenSize.y - ( Dyno.debugLine.height * linesCount ) - 16
		Dyno.debugLine.left = GUI.screenSize.x - 406
		
		local str = ""
		local val = ""
		
		dxDrawRectangle( Dyno.debugLine.left, Dyno.debugLine.top, Dyno.debugLine.width - 12, linesCount * Dyno.debugLine.height, 0x88000000 )
		
		for _, key in pairs( Dyno.listedKeys ) do
			if ( key:sub( 1, 1 ) == "[" ) then
				Dyno._renderDebugLine( "#44AAFF" .. key, "center" )
			else
				local digits = Dyno.valueFormat[ key ]
				
				if ( digits ~= "s" ) then
					val = number_format( handling[ key ], digits )
				else
					val = tostring( handling[ key ] )
				end
				
				str = string.format( "%28s #FFFFFF%-28s|", key, val )
				
				Dyno._renderDebugLine( str )
			end
		end
		
		Dyno._renderDebugLine( "-------------------------------------------------------- |" )
		
		-- gear
		local gear = getVehicleCurrentGear( Dyno.vehicle )
		Dyno._renderDebugLine( string.format( "%28s #FFFFFF%-28s|", "Current gear", tostring( gear ) ) )
		
		-- turn velocity
		local tvx, tvy, tvz = getVehicleTurnVelocity( Dyno.vehicle )
		Dyno._renderDebugLine( string.format( "%28s #FFFFFF%-28s|", "Turn velocity", string.format( "%-6s %-6s %-6s", number_format( tvx, 4, nil, nil, " " ), number_format( tvy, 4, nil, nil, " " ), number_format( tvz, 4, nil, nil, " " ) ) ) )
		
		-- velocity
		local vX, vY, vZ = getElementVelocity( Dyno.vehicle )
		local speed = math.sqrt( math.pow( vX, 2 ) + math.pow( vY, 2 ) + math.pow( vZ, 2 ) )
		Dyno._renderDebugLine( string.format( "%28s #FFFFFF%-28s|", "Speed", number_format( speed * 180, 2 ) .. " km/h" ) )
		
		Dyno._renderDebugLine( "-------------------------------------------------------- |" )
		
		Dyno._renderDebugLine( "#FFFFFFEnter #44AAFF/dyno p#FFFFFF to prepare and #44AAFF/dyno s#FFFFFF to start test", "center" )
		Dyno._renderDebugLine( "#FFFFFFPress #00AA00B #FFFFFFto open Handling Editor", "center" )
		
		------------------------------------------------------------------------
		
		if ( #Dyno.dynos ~= 0 or Dyno.dyno.isRunning ) then
			dxDrawRectangle( 7, Dyno.debugLine.top, 570, 520, 0x88000000 )
			dxDrawRectangle( 7, Dyno.debugLine.top, 570, 130, 0x88000000 )
			
			for speed = 0, 350, 25 do
				local y = Dyno.debugLine.top + 10 + 500 - speed
				dxDrawLine( 47, y, 37 + 520, y, 0x77777777 )
				
				dxDrawText( tostring( speed ), 17, y - 7, nil, nil, 0xFFFFFFFF, 1, Debug._debugScreenFont )
			end
			
			-- Лейблы
			local line = 0
			local lineHeight = 18
			local gy = Dyno.debugLine.top + 10
			local gx = 17
			
			dxDrawText( "0-100 km/h:", gx, gy + line * lineHeight, nil, nil, color, 1, Debug._debugScreenFont )
			line = line + 1
			
			dxDrawText( "Max. speed:", gx, gy + line * lineHeight, nil, nil, color, 1, Debug._debugScreenFont )
			line = line + 1
			
			dxDrawText( "Max. speed time:", gx, gy + line * lineHeight, nil, nil, color, 1, Debug._debugScreenFont )
			line = line + 1
			
			dxDrawText( "Quarter speed:", gx, gy + line * lineHeight, nil, nil, color, 1, Debug._debugScreenFont )
			line = line + 1
			
			dxDrawText( "Quarter time:", gx, gy + line * lineHeight, nil, nil, color, 1, Debug._debugScreenFont )
			line = line + 1
			
			dxDrawText( "Power (et,ts):", gx, gy + line * lineHeight, nil, nil, color, 1, Debug._debugScreenFont )
			line = line + 1
			
			-- Данные
			local dynoIdx = 0
			for _, d in pairs( Dyno.dynos ) do
				Dyno._renderDynoGraph( 47, Dyno.debugLine.top + 10, 500, d.dyno, d.color )
				Dyno._renderDynoStats( 147 + ( dynoIdx * 100 ), gy, d.dyno, d.color, d.handling.mass )
				
				dynoIdx = dynoIdx + 1
			end
			
			if ( Dyno.dyno.isRunning ) then
				Dyno._renderDynoGraph( 47, Dyno.debugLine.top + 10, 500, Dyno.dyno, Dyno.currentDynoColor )
				Dyno._renderDynoStats( 147 + ( dynoIdx * 100 ), gy, Dyno.dyno, Dyno.currentDynoColor, 1 )
			end
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	onClientPlayerVehicleEnter = function()
		Dyno.vehicle = getPedOccupiedVehicle( localPlayer )
		
		addEventHandler( "onClientRender", root, Dyno._render )
	end;
	
	onClientPlayerVehicleExit = function()
		Dyno.vehicle = nil
		
		removeEventHandler( "onClientRender", root, Dyno._render )
	end;
	
	-- Машины размещены на трек Dyno
	onServerPreparedDyno = function()
		Chat.addMessage( "Dyno-тест подготовлен" )
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Dyno.init )