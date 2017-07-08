--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Command.onServerSentCommands", true )								-- Сервер прислал информацию о серверных командах ( table serverCommands )

--------------------------------------------------------------------------------
--<[ Модуль Command ]>----------------------------------------------------------
--------------------------------------------------------------------------------
Command = {
	commands = {};
	
	init = function()
		-- Получение списка команд из сервера (когда вошел в аккаунт)
		addEventHandler( "Account.onPlayerLogIn", resourceRoot, function()
			triggerServerEvent( "Command.onClientRequestServerCommands", resourceRoot )
		end )
		
		-- Обрабатываем команды из чата
		addEventHandler( "Chat.onCommand", resourceRoot, Command.onChatCommand )
		
		-- Сервер прислал команды
		addEventHandler( "Command.onServerSentCommands", resourceRoot, function( serverCommands )
			--Debug.info( "Сервер прислал информацию о командах", serverCommands )
			for cmd, cmdData in pairs( serverCommands ) do
				if ( Command.exists( cmd ) ) then
					-- Команда уже существует (не выводим ошибку, так как может вызываться несколько раз при входах)
					-- Debug.error( "Команда " .. cmd .. " уже существует (сервер)" )
				else
					-- Команда еще не существует
					local data = {}
					
					data.type = "server"
					data.syntax = cmdData.syntax
					data.description = cmdData.description
					data.permissions = cmdData.permissions
					
					Command.commands[ cmd ] = data
				end
			end
		end )
	end;
	
	-- Существует ли команда
	-- > cmd string
	-- = bool commandExists
	exists = function( cmd ) 
		return ( Command.commands[ cmd ] ~= nil )
	end;
	
	-- Добавить команду
	-- > cmd string
	-- > perm string - необходимые алиасы прав через запятую
	-- > syntax string - синтаксис команды, например: "playerid, itemClass, count [, params]"
	-- > descr string - описание команды (и аргументов, если необходимо)
	-- > handler function - функция, которая будет вызвана при вводе команды: handler( commandName, arg1, arg2, ... )
	-- = void
	add = function( cmd, perm, syntax, descr, handler )
		if not validVar( cmd, "cmd", "string" ) then return nil end
		if not validVar( perm, "perm", "string" ) then return nil end
		if not validVar( syntax, "syntax", "string" ) then return nil end
		if not validVar( descr, "descr", "string" ) then return nil end
		if not validVar( handler, "handler", "function" ) then return nil end
	
		if ( Command.exists( cmd ) ) then
			-- Команда уже существует
			Debug.error( "Команда " .. cmd .. " уже существует" )
		else
			-- Команда еще не существует
			local data = {}
			local permArr
			if ( perm:len() == 0 ) then
				permArr = { "none" }
			else
				permArr = explode( ",", perm )
				for k, v in pairs( permArr ) do
					permArr[ k ] = trim( v )
				end
			end
			
			data.type = "client"
			data.permissions = permArr
			data.syntax = syntax
			data.description = descr
			data.handler = handler
			
			Command.commands[ cmd ] = data
			
			addCommandHandler( cmd, Command.onCommand )
		end
	end;
	
	-- Вызвать команду
	-- > cmd string - название команды
	-- > args string - аргументы команды через пробел (точно так же, как при вводе в чат)
	-- = void
	execute = function( cmd, args )
		local explArgs = explode( " ", args )
		
		Command.onCommand( cmd, unpack( explArgs ) )
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Вызвана какая-то команда, проверка прав и вызов обработчика
	onCommand = function( ... )
		local cmd = arg[ 1 ]
		
		if ( not Command.exists( cmd ) ) then
			Chat.addMessage( "Команда " .. cmd .. " не найдена", "warning" )
		else
			-- Проверка прав
			for k, v in pairs( Command.commands[ cmd ].permissions ) do
				if ( not Account.hasPermission( v ) ) then
					Chat.addMessage( "У вас нет прав на команду " .. cmd, "error" )
					return nil
				end
			end 
			
			-- Запуск
			if ( Command.commands[ cmd ].type == "client" ) then
				Debug.reportAdditional.lastCommand = {
					cmd = cmd;
					args = arg;
				}
				
				for k, v in pairs( arg ) do
					if ( v == "" ) then
						arg[ k ] = nil
					end
				end
				
				Command.commands[ cmd ].handler( unpack( arg ) )
			else
				table.remove( arg, 1 )
				triggerServerEvent( "Command.onClientExecuteServerCommand", resourceRoot, cmd, unpack( arg ) )
			end
		end
	end;
	
	onChatCommand = function( cmdName, cmdArgString )
		Command.execute( cmdName, cmdArgString )
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Command.init )

addEventHandler( "Main.onClientLoad", resourceRoot, function()
	Command.add( "help", "none", "[]", "Показать меню помощи по игре и списка команд", 
		function( cmd )
			Chat.addMessage( "Меню стравки еще не разработано", "success" )
		end 
	)
	
	Command.add( "lobby", "none", "-", "Выйти в лобби", 
		function( playerElement, cmd )
			if ( Character.isSelected( playerElement ) ) then
				-- Просто убираем персонаж - клиент сам сообразит, что текущий персонаж убран, и покажет лобби
				Character.requestCharacterDespawn()
			else
				Popup.show( playerElement, "Сначала выберите персонаж", "error" )
			end
		end 
	)

	Command.add( "logout", "none", "[]", "Выход из аккаунта", 
		function( cmd, someString )
			Account.logOut()
		end 
	)

	Command.add( "bench", "none", "[]", "Benchmark", 
		function( cmd )
			local x1, y1, z1, x2, y2, z2 = math.random() * 123, math.random() * 456, math.random() * 789, math.random() * -912, math.random() * 3321, math.random() * 14999
			local r
			
			local _st = getTickCount()
			for i = 1, 100000 do
				r = getDistanceBetweenPoints3D( x1, y1, z1, x2, y2, z2 )
			end
			Chat.addMessage( tostring( getTickCount() - _st ) )
			
			_st = getTickCount()
			for i = 1, 100000 do
				r = math.sqrt( ( x1 - x2 ) * ( x1 - x2 ) + ( y1 - y2 ) * ( y1 - y2 ) + ( z1 - z2 ) * ( z1 - z2 ) )
			end
			Chat.addMessage( tostring( getTickCount() - _st ) )
			
			_st = getTickCount()
			local a, b, c
			for i = 1, 100000 do
				a, b, c = ( x1 - x2 ), ( y1 - y2 ), ( z1 - z2 )
				r = math.sqrt(  a * a + b * b + c * c )
			end
			Chat.addMessage( tostring( getTickCount() - _st ) )
		end 
	)
	
	Command.add( "callback-event-test", "none", "[]", "Тест событий с ответом", 
		function( cmd, someString )
			CallbackEvent.trigger( "CallbackEvent.test", someString, function( response ) 
				Chat.addMessage( "Ответ от сервера:" .. tostring( response ), "success" )
			end )
		end 
	)
	
	Command.add( "callback-event-delayed-test", "none", "[]", "Тест событий с ответом (задержка 5с)", 
		function( cmd, someString )
			CallbackEvent.trigger( "CallbackEvent.delayedTest", someString, function( response ) 
				Chat.addMessage( "Ответ от сервера:" .. tostring( response ), "success" )
			end )
		end 
	)

	Command.add( "coords", "none", "[Не вычислять z по карте]", "Записать в буфер обмена текущую позицию", 
		function( cmd, skipZmap )
			local x, y, z = getElementPosition( localPlayer )
			if ( skipZmap ~= "1" and skipZmap ~= "true" ) then
				local hit, _, _, hz = processLineOfSight( x, y, z, x, y, z - 600.0 )
				if hit then z = hz end
			end
			
			local posString = string.format( "%0.4f, %0.4f, %0.4f", x, y, z )
			setClipboard( posString )
			Chat.addMessage( "Позиция сохранена в буфер обмена (" .. posString .. ")", "success" )
		end 
	)

	Command.add( "test_debug", "none", "[]", "Тестирование Debug", 
		function( cmd )
			Debug.info( "Info" )
			Debug.log( "Log" )
			Debug.warn( "Warn" )
			Debug.error( "Error" )
			
			Chat.addMessage( "В консоль отладки выведены тестовые сообщения", "success" )
		end 
	)
	
	Command.add( "settime", "none", "<Часы> [Минуты]", "Установить время", 
		function( cmd, h, m )
			if ( h == nil or tonumber( h ) < 0 or tonumber( h ) > 23 ) then
				Chat.addMessage( "Часы не указаны или имеют неправильный формат (1-23)", "error" )
				return nil
			end
			
			h = tonumber( h )
			
			if ( m == nil or tonumber( m ) < 0 or tonumber( m ) > 59 ) then
				m = 0
			end
			
			setTime( h, m )
			setMinuteDuration( 20 )
			Time.disable()
			
			Chat.addMessage( "Время установлено в " .. h .. ":" .. m, "success" )
		end 
	)
	
	Command.add( "setweather", "none", "<ID>", "Установить погоду", 
		function( cmd, w )
			if ( w == nil ) then
				w = 0
			end
			
			w = tonumber( w )
			setWeather( w )
			
			Chat.addMessage( "Погода установлена в " .. w, "success" )
		end 
	)

	Command.add( "test-model", "none", "[ID модели]", "Тестирование модели объекта", 
		function( cmd, modelID )
			local x, y, z = getElementPosition( localPlayer )
			
			local o = createObject( tonumber( modelID ), x + 0.5, y, z )
			setElementDimension( o, getElementDimension( localPlayer ) )
			setElementDoubleSided( o, true )
			
			Chat.addMessage( "Объект создан", "success" )
		end 
	)

	Command.add( "test-tree", "none", "[ID модели]", "Тестирование модели объекта", 
		function( cmd, modelID )
			local x, y, z = getElementPosition( localPlayer )
			
			local o = createObject( tonumber( modelID ), x + 0.5, y, z - 0.5 )
			setElementDimension( o, getElementDimension( localPlayer ) )
			setElementDoubleSided( o, true )
			
			Chat.addMessage( "Объект создан", "success" )
		end 
	)

	Command.add( "vehicle-upgrade", "none", "[ID улучшения]", "Добавить улучшение на текущий транспорт", 
		function( cmd, modelID )
			local veh = getPedOccupiedVehicle( localPlayer )
			if ( veh ~= nil ) then 
				local status = addVehicleUpgrade( veh, tonumber( modelID ) )
			
				Chat.addMessage( "Статус установки улучшения " .. modelID .. ": " .. tostring( status ), "success" )
			else
				Chat.addMessage( "Необходимо быть в транспорте", "error" )
			end
		end 
	)

	Command.add( "walkstyle", "none", "[ID типа анимаций]", "Установить стиль ходьбы", 
		function( cmd, styleID )
			-- https://wiki.multitheftauto.com/wiki/SetPedWalkingStyle
			if ( styleID ~= nil ) then 
				styleID = tonumber( styleID )
			else
				styleID = 0
			end
			
			setPedWalkingStyle( localPlayer, styleID )
			Chat.addMessage( "Стиль ходьбы:" .. styleID )
		end 
	)

	Command.add( "badb", "none", "[Тип поведения]", "Вызвать ошибку на стороне клиента (для отладки отчетов об ошибках)", 
		function( cmd, behaviourName )
			local availableBehaviours = {
				indexNil = "Обратиться к индексу значения nil";
				defaultError = "Стандартная ошибка";
			}
			
			if ( availableBehaviours[ behaviourName ] == nil ) then
				Debug.info( "Доступные типы поведения:", availableBehaviours )
			else
				if ( behaviourName == "indexNil" ) then
					NotExistant.notExists()
				elseif ( behaviourName == "defaultError" ) then
					Debug.error( "Тестовая ошибка" )
				else
					Chat.addMessage( "Не найдено: " .. behaviourName )
				end
				
				Chat.addMessage( "Выполнено: " .. behaviourName )
			end
		end 
	)

	Command.add( "delayed-event", "none", "[Время выполнения] [Интервал / Событие]", "Тестировать события с задержкой", 
		function( cmd, executionTime, interval )
			local executionTime = tonumber( executionTime )
			local intervalNumber = tonumber( interval )
			
			if ( executionTime == nil ) then
				Chat.addMessage( "Время выполнения должно быть числом", "error" )
			else
				if ( intervalNumber == nil ) then
					-- Интервал - не число
					if ( interval == nil or interval:len() == 0 ) then
						Chat.addMessage( "Интервалом может быть число (>=50) или название события", "error" )
						return nil
					end
				else
					-- Интервал - число
					if ( intervalNumber < 50 ) then
						Chat.addMessage( "Интервал не может быть меньше 50", "error" )
						return nil
					end
					
					interval = intervalNumber
				end
				
				local event = DelayedEvent( executionTime, interval )
				if ( event == nil ) then
					Chat.addMessage( "Событие не может быть начато", "error" )
				else
					event:onProcess( function( e )
						Debug.info( math.floor( e.progress * 100 ) .. "%" )
					end )
					event:onStop( function( e, isSuccess )
						Chat.addMessage( "Событие закончилось: " .. tostring( isSuccess ) )
					end )
					event:start()
					Chat.addMessage( "Событие началось" )
				end
			end
			
		end 
	)

	Command.add( "graph", "none", "[]", "Отображение графа пешеходов", 
		-- TODO https://wiki.multitheftauto.com/wiki/FetchRemote
		-- Обновлять map.json через сервер. Да и вообще вынести в отдельный модуль
		function( cmd )
			local nodes = jsonDecode( fileGetContents( "client/data/map.json" ) )
			
			--Debug.info( nodes )
			
			addEventHandler( "onClientRender", root, function() 
				local drawnLinks = {}
				
				local x, y = getElementPosition( localPlayer )
				
				for nodeID, v in pairs( nodes ) do
					if ( getDistanceBetweenPoints2D( x, y, v[ 1 ], v[ 2 ] ) < 100 ) then
						if ( v[ 4 ] == nil ) then
							-- Высота еще не получена, получаем
							local hit, _, _, hitZ = processLineOfSight( v[ 1 ], v[ 2 ], 600, v[ 1 ], v[ 2 ], -100, true, false, false, true, true, false )
							if ( hit ) then
								v[ 4 ] = hitZ + 0.5
							else
								v[ 4 ] = 10
							end
							nodes[ nodeID ][ 4 ] = v[ 4 ]
						end
						
						for nghb, _ in pairs( v[ 3 ] ) do
							if ( drawnLinks[ bigger( nodeID, nghb ) .. "," .. smaller( nodeID, nghb ) ] == nil ) then
								-- Еще не нарисовали
								drawnLinks[ bigger( nodeID, nghb ) .. "," .. smaller( nodeID, nghb ) ] = true
								
								if ( nodes[ nghb ][ 4 ] ~= nil ) then
									dxDrawLine3D( v[ 1 ], v[ 2 ], v[ 4 ], nodes[ nghb ][ 1 ], nodes[ nghb ][ 2 ], nodes[ nghb ][ 4 ] )
								end
							end
						end
					end
				end
			end )
			
			Chat.addMessage( "Граф отображается", "success" )
		end 
	)

end )