--[[
	Трафик, Кбит					IN		OUT
	bandwidth_reduction 			medium
	Стоит на месте					1.0		4.7
	Бежит							1.0		4.9
	Бежит и часто прыгает			1.0		6.5
	Целится из оружия				1.0		6.5
	Целится и часто жмет курок		1.0		8.7
	Очень быстро едет на NRG		3.0		9.3
	
	5кбит - трафик с 1 клиента
	
	250Мбит - полоса пропускания
	
	Трафик на сервер = кол-во клиентов * 5
	Трафик из сервера = ( ( кол-во клиентов - 1 ) * 5 ) * кол-во клиентов  // если все клиенты в одном месте
--]]

--------------------------------------------------------------------------------
--<[ Модуль Debug ]>------------------------------------------------------------
--------------------------------------------------------------------------------
Debug = {
	debugMonitorEnabled = false;
	debugMonitorLiteMode = false;

	fps = 0;
	screenSize = { width = 0; height = 0; };
	
	fpsGraphQueue = {};
	fpsGraphQueueTick = {};		-- tickCount, когда сделана запись в очередь
	fpsGraphIter = 0;
	fpsGraphMaxIter = 241;
	fpsGraphLastTick = 0;
	
	_fpsCheckTick = 0;
	_fpsCount = 0;
	
	_ping = 0;
	
	_bandwidthCheckTick = 0;
	_bandwidthLastIn = 0;
	_bandwidthLastOut = 0;
	_bandwidthIn = {};
	_bandwidthOut = {};
	_bandwidthPointer = 0;
	
	_errorsCount = 0;
	
	_debugScreenFont = nil;
	
	_peakMemoryUsage = 0;
	_collectGarbageEachFrameOnDebugScreen = false;
	
	traceback = nil;
	debugData = {};			-- Счетчики, которые будут выведены при отладке
	
	reportAdditional = {};	-- Дополнительные данные для баг-репорта
	
	---------------------------------------------------------------------------
	
	init = function()
		bindKey( "f3", "down", Debug.toggleMonitor )
		
		addEventHandler( "onClientRender", root, Debug._render )
		addEventHandler( "onClientRender", root, Debug._countFPS )
		addEventHandler( "onClientDebugMessage", root, Debug._onMTADebugMessage )
		
		setTimer( function()
			Debug._ping = getPlayerPing( localPlayer );
		end, 500, 0 )
		
		Debug.screenSize.width, Debug.screenSize.height = guiGetScreenSize() 
		
		Debug._debugScreenFont = dxCreateFont( "client/data/gui/fonts/roboto-mono-regular.ttf", 9, false, "proof" ) 
		
		Main.setModuleLoaded( "Debug", 1 )
	end;
	
	-- Установить traceback для отчета об ошибке (например, в асинхронных функциях или при обработке событий, когда стандартный трейс обрывается)
	-- > v table - traceback
	-- = void
	setTraceback = function( v )
		Debug.traceback = v
	end;
	
	-- Отправить в лог CEF
	-- > ... mixed - любые данные, которые необходимо вывести в лог
	-- = void
	log = function( ... )
		if ( arg[1] == Debug ) then return outputDebugString( "Debug.log must be called with '.'!" ) end

		local dbg = debug.getinfo( 2, "Sl" )
		dbg.source = string.sub( dbg.source, 7 )
		GUI.sendJS( "console.log", "%c" .. dbg.source .. ":" .. dbg.currentline, "color:#aaaaaa", unpack( arg ) )
	end;
	
	-- Отправить информационное сообщение в лог CEF
	-- > ... mixed - любые данные, которые необходимо вывести в лог
	-- = void
	info = function( ... )
		if ( arg[1] == Debug ) then return outputDebugString( "Debug.info must be called with '.'!" .. tostring( arg[2] ) ) end
		
		local dbg = debug.getinfo( 2, "Sl" )
		dbg.source = string.sub( dbg.source, 7 )
		GUI.sendJS( "console.info", "%c" .. dbg.source .. ":" .. dbg.currentline, "color:#0033dd; font-weight:bold", unpack( arg ) )
	end;
	
	-- Отправить информационное сообщение в лог CEF в другом цвете
	-- > infoHtmlColor string - цвет названия файла и строки (например, #f90)
	-- > ... mixed - любые данные, которые необходимо вывести в лог
	-- = void
	coloredInfo = function( infoHtmlColor, ... )
		if ( arg[1] == Debug ) then return outputDebugString( "Debug.info must be called with '.'!" .. tostring( arg[2] ) ) end
		
		local dbg = debug.getinfo( 2, "Sl" )
		dbg.source = string.sub( dbg.source, 7 )
		GUI.sendJS( "console.info", "%c" .. dbg.source .. ":" .. dbg.currentline, "color:" .. infoHtmlColor .. "; font-weight:bold", unpack( arg ) )
	end;
	
	-- Отправить сообщение о предупреждении
	-- > ... mixed - любые данные, которые необходимо вывести в лог
	-- = void
	warn = function( ... )
		if ( arg[1] == Debug ) then return outputDebugString( "Debug.warn must be called with '.'!" ) end

		local dbg = debug.getinfo( 2, "Sl" )
		dbg.source = string.sub( dbg.source, 7 )
		GUI.sendJS( "console.warn", "%c" .. dbg.source .. ":" .. dbg.currentline .. " %O", "color:#cc5500; font-weight:bold", Debug.getTraceback( 3 ), unpack( arg ) )
		
		Debug._errorsCount = Debug._errorsCount + 1
		
		Debug._bugreport( {
			level = "warning";
			message = arg;
		} )
		
		return nil
	end;
	
	-- Отправить сообщение об ошибке в лог CEF
	-- > ... mixed - любые данные, которые необходимо вывести в лог
	-- = void
	error = function( ... )
		if ( arg[1] == Debug ) then 
			Debug.info( "Debug.error must be called with '.'!", arg ) 
			return nil
		end
		
		local dbg = debug.getinfo( 2, "Sl" )
		dbg.source = string.sub( dbg.source, 7 )
		GUI.sendJS( "console.error", "%c" .. dbg.source .. ":" .. dbg.currentline .. " %O", "color:#880000; font-weight:bold", Debug.getTraceback( 3 ), unpack( arg ) )
		
		--GUI.sendJS( "console.error", debug.traceback() )
		
		Debug._errorsCount = Debug._errorsCount + 1
		
		Debug._bugreport( {
			message = tostring( arg[1] ) .. " " .. tostring( arg[2] );
			file = dbg.source;
			line = dbg.currentline;
			level = "error";
		} )
		
		return nil
	end;
	
	-- Вывести в консоль текущий стек вызовов
	-- = void
	printTraceback = function()
		local traceback = Debug.getTraceback( 3 )
	
		local dbg = debug.getinfo( 2, "Sl" )
		dbg.source = string.sub( dbg.source, 7 )
		GUI.sendJS( "console.info", "%c" .. dbg.source .. ":" .. dbg.currentline .. " %O", "color:#9C27B0; font-weight:bold", traceback )
	end;
	
	-- Переключить режим экрана отладки (выкл/вкл полный/вкл легкая версия)
	-- = void
	toggleMonitor = function()
		if ( Debug.debugMonitorEnabled ) then
			if ( Debug.debugMonitorLiteMode == false ) then
				Debug.debugMonitorLiteMode = true
			else
				Debug.debugMonitorEnabled = false
			end
		else
			Debug.debugMonitorEnabled = true
			Debug.debugMonitorLiteMode = false
			Debug._peakMemoryUsage = 0
		end
	end;
	
	-- Внутренняя функция, считает FPS
	_countFPS = function()
		local tick = getTickCount()
		Debug._fpsCount = Debug._fpsCount + 1
		if tick - Debug._fpsCheckTick > 1000 then
			Debug._fpsCheckTick = tick
			Debug.fps = Debug._fpsCount
			Debug._fpsCount = 0
		end
	end;
	
	-- Обработка внутренних ошибок клиента
	_onMTADebugMessage = function( message, level, file, line )
		local file = tostring( file )
		local line = tostring( line )
		
		if ( file ~= "nil" ) then
			file = string.sub( file, 6 )
		end
		
		if ( level == 1 ) then
			-- Error
			if ( GUI ~= nil ) then
				GUI.sendJS( "console.error", "%c" .. file .. ":" .. line .. " %O", "color:#880000; font-weight:bold", Debug.getTraceback( 3 ), message )
			else
				setTimer( function()
					GUI.sendJS( "console.error", "%c" .. file .. ":" .. line .. " %O", "color:#880000; font-weight:bold", Debug.getTraceback( 3 ), message )
				end, 2000, 1 )
			end
			
			Debug._bugreport( {
				message = message;
				file = file;
				line = line;
				level = "error";
			} )
		elseif ( level == 2 ) then
			-- Warning
			if ( GUI ~= nil ) then
				GUI.sendJS( "console.warn", "%c" .. file .. ":" .. line .. " %O", "color:#bb4400; font-weight:bold", Debug.getTraceback( 3 ), message )
			else
				setTimer( function()
					GUI.sendJS( "console.warn", "%c" .. file .. ":" .. line .. " %O", "color:#bb4400; font-weight:bold", Debug.getTraceback( 3 ), message )
				end, 2000, 1 )
			end
			
			Debug._bugreport( {
				message = message;
				file = file;
				line = line;
				level = "warning";
			} )
		elseif ( level == 3 ) then
			-- Info
			if ( GUI ~= nil ) then
				GUI.sendJS( "console.info", "%c" .. file .. ":" .. line, "color:#0033dd; font-weight:bold", message )
			else
				setTimer( function()
					GUI.sendJS( "console.info", "%c" .. file .. ":" .. line, "color:#0033dd; font-weight:bold", message )
				end, 2000, 1 )
			end
		end
	end;
	
	_lastBugreport = 0;
	
	-- Отправить сообщение об ошибке на сервер (вызываются внутри Debug.error и подобных)
	_bugreport = function( data )
		if ( Time.getClientTimestamp() - Debug._lastBugreport > 5 ) then
			Debug._lastBugreport = Time.getClientTimestamp()
			
			data.traceback = debug.traceback()
			data.callbackTraceback = Debug.traceback
			data.time = getRealTime()
			data.sessionErrorNumber = Debug._errorsCount
			
			-- Информация от клиента
			local x, y, z = getElementPosition( localPlayer )
			local _, _, angle = getElementRotation( localPlayer )
			local ingameH, ingameM = getTime();
			
			data.clientDebug = {
				frozen = isElementFrozen( localPlayer ) and 1 or 0;
				x = x;
				y = y;
				z = z;
				angle = angle;
				inWater = isElementInWater( localPlayer ) and 1 or 0;
				onScreen = isElementOnScreen( localPlayer ) and 1 or 0;
				streamed = isElementStreamedIn( localPlayer ) and 1 or 0;
				waitingLoad = isElementWaitingForGroundToLoad( localPlayer ) and 1 or 0;
				dimension = getElementDimension( localPlayer );
				health = getElementHealth( localPlayer );
				interior = getElementInterior( localPlayer );
				ping = Debug._ping;
				dxStatus = dxGetStatus();
				camInterior = getElementInterior( getCamera() );
				camDimension = getElementDimension( getCamera() );
				netstats = getNetworkStats();
				ingameH = ingameH;
				ingameM = ingameM;
			}
			
			-- Данные от разных методов
			data.modulesDebug = {
				[ "Debug.fps" ] = Debug.fps;
				[ "Debug.debugMonitorEnabled" ] = Debug.debugMonitorEnabled;
			}
			
			data.additional = Debug.reportAdditional
			
			triggerServerEvent( "Debug.onClientBugreport", resourceRoot, data )
			Debug.log( "Отчет об ошибке отправлен" )
		else
			Debug.log( "Очередь отчетов об ошибках переполнена, ожидание..." )
		end
	end;
	
	-- Получить сек вызовов, начиная с указанного уровня
	-- > level number / nil - уровень, с которого нужно выводить стек вызовов
	-- = table traceback
	getTraceback = function( level )
		if ( level == nil ) then level = 1 end
		
		local ret = {}
		while true do
			local info = debug.getinfo( level, "Sln" )
			if not info then break end
				
			local infoStr = string.sub( info.source, 7 ) .. ":" .. info.currentline
			if ( info.name == nil ) then
				infoStr = infoStr .. " (anonymous function)"
			else
				infoStr = infoStr .. " (" .. info.name .. ")"
			end
			table.insert( ret, infoStr )
			
			level = level + 1
		end
		
		return ret
	end;
	
	-- Debug monitor (F3) -----------------------------------------------------
	
	_render = function()
		-- Версия
		local versionString = "MTA:World " .. __MTAW_Version .. " B" .. __MTAW_Build .. " |"
		dxDrawText( versionString, Debug.screenSize.width - 88, Debug.screenSize.height - 14, nil, nil, 0x77FFFFFF, 1, "clear", "right", "top", false, false, false )
		
		-- Кол-во ошибок
		dxDrawText( "Error count: " .. tostring( Debug._errorsCount ), Debug.screenSize.width - 5, Debug.screenSize.height - 28, nil, nil, 0x77FFFFFF, 1, "clear", "right", "top", false, false, false )
		
		if ( Debug.debugMonitorEnabled ) then
			local lstTL = 0;
			local lstTR = 0;
			
			local dbgWrite = function( right, text )
				if ( right == 0 ) then
					if ( text ~= "" ) then
						dxDrawRectangle( 8, 10 + ( lstTL * 15 ), dxGetTextWidth( text, 1, Debug._debugScreenFont, false ) + 6, 15, 0x88000000, true )
						--[[
						dxDrawText ( text, 10, 11 + ( lstTL * 15 ), nil, nil, 0xFF000000, 1, Debug._debugScreenFont, "left", "top", false, false, true )
						dxDrawText ( text, 10, 9 + ( lstTL * 15 ), nil, nil, 0xFF000000, 1, Debug._debugScreenFont, "left", "top", false, false, true )
						dxDrawText ( text, 11, 10 + ( lstTL * 15 ), nil, nil, 0xFF000000, 1, Debug._debugScreenFont, "left", "top", false, false, true )
						dxDrawText ( text, 9, 10 + ( lstTL * 15 ), nil, nil, 0xFF000000, 1, Debug._debugScreenFont, "left", "top", false, false, true )
						--]]
						dxDrawText ( text, 10, 10 + ( lstTL * 15 ), nil, nil, 0xFFFFFFFF, 1, Debug._debugScreenFont, "left", "top", false, false, true )
					end
					lstTL = lstTL + 1
				else
					if ( text ~= "" ) then
						local strLength = dxGetTextWidth( text, 1, Debug._debugScreenFont, false )
						dxDrawRectangle( Debug.screenSize.width - strLength - 13, 11 + ( lstTR * 15 ), strLength + 6, 15, 0x88000000, true )
						--[[
						dxDrawText ( text, 10, 11 + ( lstTR * 15 ), Debug.screenSize.width - 10, nil, 0xFF000000, 1, Debug._debugScreenFont, "right", "top", false, false, true )
						dxDrawText ( text, 10, 9 + ( lstTR * 15 ), Debug.screenSize.width - 10, nil, 0xFF000000, 1, Debug._debugScreenFont, "right", "top", false, false, true )
						dxDrawText ( text, 11, 10 + ( lstTR * 15 ), Debug.screenSize.width - 11, nil, 0xFF000000, 1, Debug._debugScreenFont, "right", "top", false, false, true )
						dxDrawText ( text, 9, 10 + ( lstTR * 15 ), Debug.screenSize.width - 9, nil, 0xFF000000, 1, Debug._debugScreenFont, "right", "top", false, false, true )
						--]]
						dxDrawText ( text, 10, 10 + ( lstTR * 15 ), Debug.screenSize.width - 10, nil, 0xFFFFFFFF, 1, Debug._debugScreenFont, "right", "top", false, false, true )
					end
					lstTR = lstTR + 1
				end
			end
				
			if ( Debug.debugMonitorLiteMode ) then
				dbgWrite( 0, string.format( "%i fps, %ims ping", Debug.fps, Debug._ping ) )
			else
				
				local frozen = isElementFrozen( localPlayer ) and 1 or 0
				local x, y, z = getElementPosition( localPlayer )
				local _, _, angle = getElementRotation( localPlayer )
				local inWater = isElementInWater( localPlayer ) and 1 or 0
				local onScreen = isElementOnScreen( localPlayer ) and 1 or 0
				local streamed = isElementStreamedIn( localPlayer ) and 1 or 0
				local waitingLoad = isElementWaitingForGroundToLoad( localPlayer ) and 1 or 0
				local dimension = getElementDimension( localPlayer )
				local health = getElementHealth( localPlayer )
				local interior = getElementInterior( localPlayer )
				local ping = getPlayerPing( localPlayer )
				local dxStatus = dxGetStatus()
				local dxUsedFonts = dxStatus[ "VideoMemoryUsedByFonts" ]
				local dxUsedTextures = dxStatus[ "VideoMemoryUsedByTextures" ]
				local dxUsedRenderTargets = dxStatus[ "VideoMemoryUsedByRenderTargets" ]
				local netstats = getNetworkStats()
				local currentWeather, blendingWeather = getWeather()
				local vX, vY, vZ
				local vpX, vpY, vpZ
				if ( getPedOccupiedVehicle( localPlayer ) ) then
					vX, vY, vZ = getElementVelocity( getPedOccupiedVehicle( localPlayer ) )
					vpX, vpY, vpZ = getElementPosition( getPedOccupiedVehicle( localPlayer ) )
				else
					vX, vY, vZ = getElementVelocity( localPlayer )
				end
				local speed = math.sqrt( math.pow( vX, 2 ) + math.pow( vY, 2 ) + math.pow( vZ, 2 ) )
				
				---
				
				dbgWrite( 0, string.format( "MTA: World " .. __MTAW_Version .. " ( %i fps, %ims ping )", Debug.fps, ping ) )
				
				dbgWrite( 0, "" )
				dbgWrite( 0, "Time ---------------------------" )
				local gtasaH, gtasaM = getTime()
				local realTime = getRealTime()
				local ingameH, ingameM, ingameS = Time.getIngameTime()
				local ingameYear, ingameMonth, ingameMonthday = Time.getIngameDate()
				dbgWrite( 0, string.format( "GTA-SA: %02d:%02d", gtasaH, gtasaM ) )
				dbgWrite( 0, string.format( "Real:   %02d.%02d.%04d %02d:%02d:%02d", realTime.monthday, realTime.month + 1, realTime.year + 1900, realTime.hour, realTime.minute, realTime.second ) )
				
				if ( DEBUG_MODE ) then
					dbgWrite( 0, string.format( "Ingame: %02d.%02d.%04d %02d:%02d:%02d", ingameMonthday, ingameMonth, ingameYear, ingameH, ingameM, ingameS ) )
				end
				
				dbgWrite( 0, string.format( "Server delta tick: %4d, timestamp: %4d", Time.getServerTickDelta(), Time.getServerTimestampDelta() ) )
				-- dbgWrite( 0, string.format( "Server timestamp: %d, %d", Time.getServerTimestamp(), Time.getServerTickCount() ) )
				-- dbgWrite( 0, string.format( "Client timestamp: %d, %d", Time.getClientTimestamp(), Time.getClientTickCount() ) )
				
				dbgWrite( 0, "" )
				dbgWrite( 0, "Environment --------------------" )
				dbgWrite( 0, string.format( "Weather: %d, %s", currentWeather, blendingWeather and tostring( blendingWeather ) or "-" ) )
				dbgWrite( 0, string.format( "Light intensity: %0.2f", Environment.getDayLightIntensity() ) )
				
				dbgWrite( 0, "" )
				dbgWrite( 0, "Player -------------------------" )
				dbgWrite( 0, string.format( "Frozen: %d, in water: %d, streamed: %d, waiting load: %d", frozen, inWater, streamed, waitingLoad ) )
				dbgWrite( 0, string.format( "Interior: %d, Dimension: %d", interior, dimension ) )
				dbgWrite( 0, string.format( "Health: %d", health ) )

				dbgWrite( 0, "" )
				dbgWrite( 0, string.format( "X: %0.2f", x ) )
				dbgWrite( 0, string.format( "Y: %0.2f", y ) )
				dbgWrite( 0, string.format( "Z: %0.2f", z ) )
				dbgWrite( 0, string.format( "A: %0.2f", angle ) )
				
				if ( vpX ~= nil ) then
					dbgWrite( 0, string.format( "Vehicle X: %0.2f", vpX ) )
					dbgWrite( 0, string.format( "Vehicle Y: %0.2f", vpY ) )
					dbgWrite( 0, string.format( "Vehicle Z: %0.2f", vpZ ) )
				end
				
				dbgWrite( 0, "" )
				dbgWrite( 0, string.format( "Speed: %3.2f km/h", speed * 180 ) )
				
				local camera = getCamera()
				local x, y, z, tx, ty, tz, rol, fov = getCameraMatrix()
				local interior = getElementInterior( camera )
				local dimension = getElementDimension( camera )
				
				dbgWrite( 0, "" )
				dbgWrite( 0, "Camera -------------------------" )
				dbgWrite( 0, string.format( "Position: %-8s %-8s %-8s", number_format( x ), number_format( y ), number_format( z ) ) )
				dbgWrite( 0, string.format( "Target:   %-8s %-8s %-8s", number_format( tx ), number_format( ty ), number_format( tz ) ) )
				dbgWrite( 0, string.format( "ROL: %0.3f, FOV: %0.3f", rol, fov ) )
				dbgWrite( 0, string.format( "Interior: %d, dimension: %d", interior, dimension ) )
				
				---
				
				if ( Debug._collectGarbageEachFrameOnDebugScreen ) then
					collectgarbage()
				end
				
				local usedMemory = collectgarbage( "count" )
				if ( Debug._peakMemoryUsage < usedMemory ) then
					Debug._peakMemoryUsage = usedMemory
				end
				dbgWrite( 1, string.format( "%s Memory usage: %-12s kb", Debug._collectGarbageEachFrameOnDebugScreen and "[GC]" or "", number_format( usedMemory ) ) )
				dbgWrite( 1, string.format( "Peak: %-12s kb", number_format( Debug._peakMemoryUsage ) ) )
				
				dbgWrite( 1, "" )
				dbgWrite( 1, "-------------------------- Video" )
				dbgWrite( 1, dxStatus[ "VideoCardName" ] .. " ( " .. number_format( dxStatus[ "VideoCardRAM"] ) .. " Mb )" )
				dbgWrite( 1, string.format( "Test mode:   %-15s", dxStatus[ "TestMode" ] ) )
				dbgWrite( 1, string.format( "Free memory: %-12s Mb", number_format( dxStatus[ "VideoMemoryFreeForMTA" ] ) ) )
				dbgWrite( 1, string.format( "Used memory: %-12s Mb", number_format( dxUsedFonts + dxUsedTextures + dxUsedRenderTargets ) ) )
				dbgWrite( 1, string.format( "DX fonts: %i Mb, DX textures: %i Mb, DX render targets: %i Mb", dxUsedFonts, dxUsedTextures, dxUsedRenderTargets ) )
				
				local netstats = getNetworkStats()
				
				dbgWrite( 1, "" )
				dbgWrite( 1, "------------------------ Network" )
				dbgWrite( 1, string.format( "Packet loss: %s", number_format( netstats.packetlossTotal ) ) )
				dbgWrite( 1, string.format( "Bytes recieved: %s", number_format( netstats.bytesReceived ) ) )
				dbgWrite( 1, string.format( "Bytes sent: %s", number_format( netstats.bytesSent ) ) )
				dbgWrite( 1, string.format( "Packets recieved: %s", number_format( netstats.packetsReceived ) ) )
				dbgWrite( 1, string.format( "Packets sent: %s", number_format( netstats.packetsSent ) ) )
				
				-- Использование сети
				local bandwidthCount = 0
				
				local bandwidthInSum = 0
				local bandwidthOutSum = 0
				for i=1,20 do
					if ( Debug._bandwidthIn[ i ] ~= nil ) then
						bandwidthInSum = bandwidthInSum + Debug._bandwidthIn[ i ]
						bandwidthOutSum = bandwidthOutSum + Debug._bandwidthOut[ i ]
						bandwidthCount = bandwidthCount + 1
					end
				end
				bandwidthCount = bandwidthCount * 0.5 -- Так как проверка раз в 0.5с
				if ( bandwidthCount ~= 0 ) then 
					dbgWrite( 1, string.format( "Bandwidth, IN: %s Kbit/s, OUT: %s Kbit/s", number_format( bandwidthInSum / bandwidthCount / 128 ), number_format( bandwidthOutSum / bandwidthCount / 128 ) ) )
				else
					dbgWrite( 1, "Bandwidth: calculating..." )
				end
				
				if ( getTickCount() - Debug._bandwidthCheckTick > 499 ) then
					-- Секунду назад считали трафик, добавляем новую запись в массив
					if ( Debug._bandwidthLastIn ~= 0 ) then
						Debug._bandwidthIn[ Debug._bandwidthPointer ] = netstats.bytesReceived - Debug._bandwidthLastIn
					end
					Debug._bandwidthLastIn = netstats.bytesReceived
					
					if ( Debug._bandwidthLastOut ~= 0 ) then
						Debug._bandwidthOut[ Debug._bandwidthPointer ] = netstats.bytesSent - Debug._bandwidthLastOut
					end
					Debug._bandwidthLastOut = netstats.bytesSent
					
					Debug._bandwidthPointer = Debug._bandwidthPointer + 1
					if ( Debug._bandwidthPointer > 20 ) then
						Debug._bandwidthPointer = 1
					end
					Debug._bandwidthCheckTick = getTickCount()
				end
			end
			
			-- График FPS
			if ( not Debug.debugMonitorLiteMode ) then
				for i = 0, 10 do
					local top = Debug.screenSize.height - 8 - ( i * 10 )
					dxDrawRectangle( 8, top, Debug.fpsGraphMaxIter, 1, 0xFF000000, true )
					if ( i % 2 == 1 ) then
						dxDrawText( ( i * 10 ) .. "ms " .. math.floor( 1000 / ( i * 10 ) + 0.5 ) .. "fps", Debug.fpsGraphMaxIter + 12, top - 7, nil, nil, 0xFF000000, 1, Debug._debugScreenFont, nil, nil, nil, nil, true )
					end
				end
				for i = 0, Debug.fpsGraphMaxIter, 10 do
					dxDrawRectangle( 8 + ( i ), Debug.screenSize.height - 8 - 100, 1, 100, 0xFF000000, true )
				end
			end
			
			local currentTick = getTickCount()
			for i = 1, Debug.fpsGraphMaxIter do
				if ( Debug.fpsGraphQueue[ i ] ~= nil ) then
					local alpha = 255 - ( currentTick - Debug.fpsGraphQueueTick[ i ] ) / 24
					if ( alpha > 0 ) then
						--local color = bitOr( 0x00FF00, bitLShift( alpha, 24 ) )
						local color = tocolor( 0, 255, 0, alpha )
						dxDrawRectangle( 7 + i, Debug.screenSize.height - 7 - Debug.fpsGraphQueue[ i ], 1, Debug.fpsGraphQueue[ i ], color, true )
					end
				end
			end
			
			Debug.fpsGraphIter = Debug.fpsGraphIter + 1
			if ( Debug.fpsGraphIter > Debug.fpsGraphMaxIter ) then
				Debug.fpsGraphIter = 1
			end
			
			Debug.fpsGraphQueue[ Debug.fpsGraphIter ] = getTickCount() - Debug.fpsGraphLastTick
			Debug.fpsGraphQueueTick[ Debug.fpsGraphIter ] = getTickCount()
			Debug.fpsGraphLastTick = currentTick
			
			-- Другие данные
			dbgWrite( 0, "" )
			for k, v in pairs( Debug.debugData ) do
				dbgWrite( 0, string.format( "%-24s = %s", tostring( k ), tostring( v ) ) )
			end
		end
	end;
};

addEventHandler( "onClientResourceStart", resourceRoot, Debug.init )