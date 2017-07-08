--[[
	Profiler
	Исследование производительности
--]]

--------------------------------------------------------------------------------
--<[ Модуль Profiler ]>---------------------------------------------------------
--------------------------------------------------------------------------------
Profiler = {
	--enabled = false;			-- Если false, модуль полностью отключен // Использовать команду /profiler
	profileNative = true;		-- Если true, будет замеряться также время работы и кол-во вызовов функций MTA
	perFrame = true;			-- Добавляет в отчет график времени рендеринга и функции, вызванные между отрисовками

	reportGenerationInterval = 20;	-- Интервал генерации отчетов (с)
	flushAfterGeneration = true;	-- Очищать статистику после генерации отчета (будет выведена статистика только с момента последнего отчета). Если отключить при perFrame, сожрет много памяти и отчет будет огромным
	
	excludeFiles = {			-- Исключенные из отладки файлы
		--[
		["@MTAW\\client\\debug.lua"] = true;
		["@MTAW\\client\\profiler.lua"] = true;
		["@MTAW\\client\\herb.lua"] = true;
		["debug.lua"] = true;
		["profiler.lua"] = true;
		["herb.lua"] = true;
		--]]
	};
	
	-- Формат ключей:
	-- Функции MTA | N:ResourceName:FilePath:LineNumber:FunctionName
	-- Функции Lua | L:FilePath:LineDefined:FunctionName
	executionTime = {};
	callCount = {};
	shortestCall = {};
	longestCall = {};
	
	currentCalls = {};			-- tickCount начала вызова
	
	-- perFrame
	frameCallCount = {};		-- key => кол-во вызовов за последний фрейм
	frameExecutionTime = {};	-- key => время, затраченное на ф-цию за последний фрейм
	
	frameLongestCall = {};
	frameShortestCall = {};
	
	frames = {};				-- Массив фреймов [] => { frameTime = время (мс) с момента последнего фрейма, callCount => {}, executionTime => {}, longestCall => {}, shortestCall => {} }
	lastFrameTick = 0;			-- getTickCount последнего фрейма
	
	init = function()
		addEventHandler( "Main.onClientLoad", resourceRoot, Profiler.onClientLoad )
	end;
	
	onClientLoad = function()
		Command.add( "profiler", "none", "", "Включить / отключить профилирование кода", function()
			if ( Profiler.profileNative ) then
				local nativePreHookFunciton = function( sourceResource, functionName, isAllowedByACL, luaFilename, luaLineNumber, ... )
					if ( Profiler.excludeFiles[ luaFilename ] ~= nil ) then return nil end
					
					local key = table.concat( { "N", getResourceName(sourceResource), luaFilename, luaLineNumber, functionName }, ":" )
					Profiler.currentCalls[ key ] = getTickCount()
				end
				addDebugHook( "preFunction", nativePreHookFunciton )
				
				local nativePostHookFunciton = function( sourceResource, functionName, isAllowedByACL, luaFilename, luaLineNumber, ... )
					if ( Profiler.excludeFiles[ luaFilename ] ~= nil ) then return nil end
					
					local key = table.concat( { "N", getResourceName(sourceResource), luaFilename, luaLineNumber, functionName }, ":" )

					if ( Profiler.currentCalls[ key ] ~= nil ) then
						-- Общий callCount
						if ( Profiler.callCount[ key ] == nil ) then
							Profiler.callCount[ key ] = 1
						else
							Profiler.callCount[ key ] = Profiler.callCount[ key ] + 1
						end
						
						-- Время выполнения
						local spentTime = getTickCount() - Profiler.currentCalls[ key ]
						
						-- Общее время
						if ( Profiler.executionTime[ key ] == nil ) then
							Profiler.executionTime[ key ] = spentTime
							Profiler.shortestCall[ key ] = spentTime
							Profiler.longestCall[ key ] = spentTime
						else
							Profiler.executionTime[ key ] = Profiler.executionTime[ key ] + spentTime
							if ( Profiler.shortestCall[ key ] > spentTime ) then
								Profiler.shortestCall[ key ] = spentTime
							end
							if ( Profiler.longestCall[ key ] < spentTime ) then
								Profiler.longestCall[ key ] = spentTime
							end
						end
						
						if ( Profiler.perFrame ) then
							-- callCount за фрейм
							if ( Profiler.frameCallCount[ key ] == nil ) then
								Profiler.frameCallCount[ key ] = 1
							else
								Profiler.frameCallCount[ key ] = Profiler.frameCallCount[ key ] + 1
							end
							
							-- Время за фрейм
							if ( Profiler.frameExecutionTime[ key ] == nil ) then
								Profiler.frameExecutionTime[ key ] = spentTime
								Profiler.frameShortestCall[ key ] = spentTime
								Profiler.frameLongestCall[ key ] = spentTime
							else
								Profiler.frameExecutionTime[ key ] = Profiler.frameExecutionTime[ key ] + spentTime
								if ( Profiler.frameShortestCall[ key ] > spentTime ) then
									Profiler.frameShortestCall[ key ] = spentTime
								end
								if ( Profiler.frameLongestCall[ key ] < spentTime ) then
									Profiler.frameLongestCall[ key ] = spentTime
								end
							end
						end
					end
				end
				addDebugHook( "postFunction", nativePostHookFunciton )
			end
			
			local luaHookFunction = function( hookType )
				local data = debug.getinfo( 2, "Sfln" )
				if ( data.currentline ~= -1 ) then
					if ( Profiler.excludeFiles[ data.source ] ~= nil ) then return nil end
					
					if ( data.source == "?" ) then
						local oldName = data.name
						data = debug.getinfo( 3, "Sfln" )
						data.source = "[U]" .. data.source
						if ( data.name == nil ) then 
							data.name = "[D]" .. oldName
						end
					end
					local key = table.concat( { "L", tostring( data.source ), tostring( data.linedefined ), tostring( data.name ) }, ":" )
					if ( hookType == "call" ) then
						Profiler.currentCalls[ key ] = getTickCount()
					else
						if ( Profiler.currentCalls[ key ] ~= nil ) then
							-- Общее кол-во вызовов
							if ( Profiler.callCount[ key ] == nil ) then
								Profiler.callCount[ key ] = 1
							else
								Profiler.callCount[ key ] = Profiler.callCount[ key ] + 1
							end
							
							-- Затраченное время
							local spentTime = getTickCount() - Profiler.currentCalls[ key ]
							
							-- Общее затраченное время
							if ( Profiler.executionTime[ key ] == nil ) then
								Profiler.executionTime[ key ] = spentTime
								Profiler.shortestCall[ key ] = spentTime
								Profiler.longestCall[ key ] = spentTime
							else
								Profiler.executionTime[ key ] = Profiler.executionTime[ key ] + spentTime
								if ( Profiler.shortestCall[ key ] > spentTime ) then
									Profiler.shortestCall[ key ] = spentTime
								end
								if ( Profiler.longestCall[ key ] < spentTime ) then
									Profiler.longestCall[ key ] = spentTime
								end
							end
							
							if ( Profiler.perFrame ) then
								-- callCount за фрейм
								if ( Profiler.frameCallCount[ key ] == nil ) then
									Profiler.frameCallCount[ key ] = 1
								else
									Profiler.frameCallCount[ key ] = Profiler.frameCallCount[ key ] + 1
								end
								
								-- Время за фрейм
								if ( Profiler.frameExecutionTime[ key ] == nil ) then
									Profiler.frameExecutionTime[ key ] = spentTime
									Profiler.frameShortestCall[ key ] = spentTime
									Profiler.frameLongestCall[ key ] = spentTime
								else
									Profiler.frameExecutionTime[ key ] = Profiler.frameExecutionTime[ key ] + spentTime
									if ( Profiler.frameShortestCall[ key ] > spentTime ) then
										Profiler.frameShortestCall[ key ] = spentTime
									end
									if ( Profiler.frameLongestCall[ key ] < spentTime ) then
										Profiler.frameLongestCall[ key ] = spentTime
									end
								end
							end
						end
					end
				end
			end
			
			debug.sethook( luaHookFunction, "cr" )
			
			setTimer( function()
				Profiler.flush()
				setTimer( Profiler.generateReport, Profiler.reportGenerationInterval * 1000, 0 )
			end, 10*1000, 1 )
			
			if ( Profiler.perFrame ) then
				addEventHandler( "onClientRender", root, Profiler.onClientRender )
			end
		end )
	end;
	
	-- Сбросить данные профилирования
	-- = void
	flush = function()
		Profiler.executionTime = {}
		Profiler.callCount = {}
		Profiler.shortestCall = {}
		Profiler.longestCall = {}
		Profiler.currentCalls = {}
		
		Profiler.frameCallCount = {}
		Profiler.frameExecutionTime = {}
		Profiler.frameLongestCall = {}
		Profiler.frameShortestCall = {}
		
		Profiler.frames = {}
		
		Debug.info( "Profiler flushed" )
	end;
	
	-- Сгенерировать отчет и записать в файл
	-- = void
	generateReport = function()
		local h = fileCreate( "profile-data.js" )
		local data = {
			executionTime = Profiler.executionTime;	-- Время (мс), затраченное на выполнение ф-ции в сумме
			callCount = Profiler.callCount;			-- Кол-во вызовов функции. executionTime / callCount = avgExecutionTime
			shortestCall = Profiler.shortestCall;	-- Время (мс), минимально затраченное на выполнение функции
			longestCall = Profiler.longestCall;		-- Время (мс), максимально затраченное на выполнение функции
		}
		
		if ( Profiler.perFrame ) then
			data.frames = Profiler.frames;			-- Номер фрейма => 
		end
		
		fileWrite( h, 'var profileData = ' )
		fileWrite( h, jsonEncode( data ) )
		fileClose( h )
		
		Debug.info( "Profiler report generated" )
		
		if ( Profiler.flushAfterGeneration ) then
			Profiler.flush()
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Отрисовка одного фрейма (включен perFrame)
	onClientRender = function()
		table.insert( Profiler.frames, {
			frameTime = getTickCount() - Profiler.lastFrameTick;
			callCount = Profiler.frameCallCount;
			executionTime = Profiler.frameExecutionTime;
			longestCall = Profiler.frameLongestCall;
			shortestCall = Profiler.frameShortestCall;
		} );
		
		Profiler.frameCallCount = {}
		Profiler.frameExecutionTime = {}
		Profiler.frameLongestCall = {}
		Profiler.frameShortestCall = {}
		
		Profiler.lastFrameTick = getTickCount()
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Profiler.init )