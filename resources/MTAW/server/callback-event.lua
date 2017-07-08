--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "CallbackEvent.onClientRequestInterfaceElement", true )				-- Клиент запросил интерфейс-элемент при инициализации ()
addEvent( "CallbackEvent.onClientRequest", true )								-- Клиент вызвал какое-то событие ( string hash, string eventName, table arguments )

--------------------------------------------------------------------------------
--<[ Модуль CallbackEvent ]>----------------------------------------------------
--------------------------------------------------------------------------------
CallbackEvent = {
	element = nil;

	eventHandlers = {};			-- Название события - функция-обработчик ( eventHash, arg1, arg2... )
	pendingResponse = {};		-- События, которые ждут ответ от сервера ( eventHash => client )
	
	init = function()
		addEventHandler( "Main.onServerLoad", resourceRoot, CallbackEvent.onServerLoad )
		
		-- Создаем элемент-интерфейс
		CallbackEvent.element = createElement( "CallbackEventInterface" )
		
		-- Обрабатываем запросы клиентов на элемент интерфейса
		addEventHandler( "CallbackEvent.onClientRequestInterfaceElement", resourceRoot, CallbackEvent.onClientRequestInterfaceElement )
		
		-- Обрабатываем события на элементе
		addEventHandler( "CallbackEvent.onClientRequest", CallbackEvent.element, CallbackEvent.onClientRequest, false )
	end;
	
	onServerLoad = function()
		-- Тестовый обработчик (CallbackEvent.test)
		CallbackEvent.addHandler( "CallbackEvent.test", function( playerElement, eventHash, testString )
			Debug.info( "Hash: " .. eventHash .. ", client says " .. tostring( testString ) )
			CallbackEvent.sendResponse( eventHash, "Hi there!" )
		end )
		
		-- Тестовый обработчик (CallbackEvent.delayedTest)
		CallbackEvent.addHandler( "CallbackEvent.delayedTest", function( playerElement, eventHash, testString )
			Debug.info( "Hash: " .. eventHash .. ", client says " .. tostring( testString ) )
			Debug.info( "Waiting 5s..." )
			setTimer( function()
				Debug.info( "Sending delayed response" )
				CallbackEvent.sendResponse( eventHash, "Hi there!" )
			end, 5000, 1 )
		end )
	end;
	
	-- Добавить обработчик события
	-- Ответ должен быть отправлен через CallbackEvent.sendResponse( eventHash, arg1, arg2... )
	-- Внимание! nil не передавать, так как unpack не может из таблицы его достать
	-- > eventName string
	-- > handlerFunction function - функция, которая будет вызвана с ответом на событие: handlerFunction( playerElement, eventHash, arg1, arg2... )
	-- = void
	addHandler = function( eventName, handlerFunction )
		-- TODO не передавать в handlerFunction хэш события
		if ( CallbackEvent.eventHandlers[ eventName ] ~= nil ) then
			-- Это событие уже обрабатывается
			Debug.error( "Callback event " .. eventName .. " handler already exists" )
		else
			-- Это событие еще не обрабатывается
			CallbackEvent.eventHandlers[ eventName ] = handlerFunction
		end
	end;
	
	-- Убрать обработчик события
	-- > eventName string
	-- = void
	removeHandler = function( eventName )
		CallbackEvent.eventHandlers[ eventName ] = nil
	end;
	
	-- Отправить ответ на клиент 
	-- Должно быть вызвано в обработчике, добавленом в addHandler (допускается асинхронный вызов)
	-- > eventHash string - хэш события, который передается в функцию-обработчик в addHandler
	-- > ... mixed - любые данные (кроме nil), передаваемые в ответ
	-- = void
	sendResponse = function( ... )
		-- TODO аргументы задать как ( eventHash, ... )
		local eventHash = nil
		
		-- Получаем первый аргумент как хеш события
		for k, v in ipairs( arg ) do
			if ( eventHash == nil and type( v ) == "string" ) then
				-- Первый аргумент - строка, считаем ее хэшем события
				eventHash = v
				break
			else
				Debug.error( "First argument passed to CallbackEvent.sendResponse must be an eventHash string, " .. type( v ) .. " given" )
				return nil
			end
		end
		
		-- Разрезаем хэш на строку элемента клиента и хэш события на клиенте
		local hashExpl = explode( ":", eventHash )
		if ( #hashExpl ~= 2 ) then
			-- Хэш имеет другой формат (не aaa:bbb)
			Debug.error( "Wrong event hash format: " .. eventHash )
			return nil
		end
		
		local clientEventHash = hashExpl[ 2 ]
		
		if ( CallbackEvent.pendingResponse[ eventHash ] ) then
			-- Такое событие есть
			if ( isElement( CallbackEvent.pendingResponse[ eventHash ] ) ) then
				-- Игрок еще существует
				
				 -- Убираем eventHash из аргументов
				table.remove( arg, 1 )
				
				-- Отправляем ответ клиенту
				triggerClientEvent( CallbackEvent.pendingResponse[ eventHash ], "CallbackEvent.onEventResponse", CallbackEvent.element, clientEventHash, unpack( arg ) )
				
				-- Убираем из очереди
				CallbackEvent.pendingResponse[ eventHash ] = nil
			else
				-- Игрок уже вышел / уже не элемент
				Debug.info( "Can't send response for event - client is not an element anymore" )
			end
		else
			-- Такого события нет
			Debug.error( "Can't send response - event hash " .. tostring( eventHash ) .. " not exists" )
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Клиент прислал событие, на которое мы должны ответить
	onClientRequest = function( hash, eventName, arguments )
		local playerElement = client
	
		-- hash - уникальный хэш на клиенте, но не на сервере. Создаем уникальный хэш
		local eventHash = tostring( playerElement ):sub( 11 ) .. ":" .. tostring( hash )
		
		if ( CallbackEvent.eventHandlers[ eventName ] ~= nil ) then
			-- Обработчик такого события есть
			
			-- Добавляем в очередь
			CallbackEvent.pendingResponse[ eventHash ] = playerElement
			
			-- Запускаем обработчик
			CallbackEvent.eventHandlers[ eventName ]( playerElement, eventHash, unpack( arguments ) )
		else
			-- Нет обработчика такого события
			Debug.error( "Event " .. eventName .. " has no handler" )
		end
	end;
	
	-- Клиент запросил элемент-интерфейс при инициализации
	onClientRequestInterfaceElement = function()
		triggerClientEvent( client, "CallbackEvent.onServerSentInterfaceElement", resourceRoot, CallbackEvent.element )
	end;
}
addEventHandler( "onResourceStart", resourceRoot, CallbackEvent.init )
