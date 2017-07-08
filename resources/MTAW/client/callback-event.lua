--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "CallbackEvent.onServerSentInterfaceElement", true )					-- Сервер прислал в ответ элемент интерфейса для общения ( element interfaceElement )
addEvent( "CallbackEvent.onEventResponse", true )								-- Ответ на клиентский CallbackEvent.trigger ( string hash, ... )

--------------------------------------------------------------------------------
--<[ Модуль CallbackEvent ]>----------------------------------------------------
--------------------------------------------------------------------------------
CallbackEvent = {
	queue = {};
	element = nil;		-- Элемент, через который будут посылаться события (получается у сервера во время инициализации)
	eventPointer = 1;	-- ID следующего события в очереди (инкремент)
	
	init = function()
		addEventHandler( "Main.onClientLoad", resourceRoot, CallbackEvent.onClientLoad )
		
		-- Получаем элемент, через который будем общаться с сервером
		Main.setModuleLoaded( "CallbackEvent", 0.5 )
		
		addEventHandler( "CallbackEvent.onServerSentInterfaceElement", resourceRoot, function( interfaceElement ) 
			CallbackEvent.element = interfaceElement
			
			-- Обрабатываем ответы сервера на наши запросы
			addEventHandler( "CallbackEvent.onEventResponse", interfaceElement, CallbackEvent.onServerResponse, false )
		
			Main.setModuleLoaded( "CallbackEvent", 1 )
		end )
		triggerServerEvent( "CallbackEvent.onClientRequestInterfaceElement", resourceRoot )
		
	end;
	
	onClientLoad = function()
		
	end;
	
	-- Вызвать событие на сервере (обрабатывается тоже через CallbackEvent)
	-- trigger( string eventName, mixed arg1, mixed arg2, ..., function callback )
	-- > eventName string - название события 
	-- > ... mixed - аргументы, передаваемые в событие
	-- > callback function - функция, которая будет вызвана после ответа на событие: callbackFunction( arg1, arg2... )
	-- = bool isTriggered
	trigger = function( ... )
		local eventName = nil
		local arguments = {}
		local callbackFunction = nil
		
		for i, v in ipairs( arg ) do
			local t = type( v )
			if ( eventName == nil ) then
				-- Название события еще не установлено
				if ( t == "string" ) then
					-- Первый аргумент - строка, устанавливаем названием события
					eventName = v
				else
					Debug.error( "Первый аргумент в CallbackEvent.triggerServer должен быть названием события, получено " .. t .. " " .. tostring( v ) )
					return false
				end
			else
				-- Название события установлено
				if ( t == "function" ) then
					-- Функция - используем как callback и завершаем проход по аргументам
					callbackFunction = v
					break
				else
					-- Не функция - добавляем в аргументы события
					table.insert( arguments, v )
				end
			end
		end
		
		if ( callbackFunction == nil ) then
			-- Не была передана callback-функция, вызывать событие нет смысла (без callback надо использовать обычное событие)
			Debug.error( "В аргументах функции CallbackEvent.triggerServer нет callback-функции" )
			return false
		else
			-- callback-функция есть, есть название события - записываем под уникальным хэшем в очередь событий
			local hash = tostring( CallbackEvent.eventPointer )
			CallbackEvent.eventPointer = CallbackEvent.eventPointer + 1
			
			CallbackEvent.queue[ hash ] = callbackFunction
			
			triggerServerEvent( "CallbackEvent.onClientRequest", CallbackEvent.element, hash, eventName, arguments )
			return true
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Сервер ответил на событие (hash, ...)
	onServerResponse = function( ... )
		local hash = table.remove( arg, 1 )
		
		Debug.info( type( hash ), hash )
		
		-- Вызываем функцию-обработчик
		CallbackEvent.queue[ hash ]( unpack( arg ) )
		
		-- Удаляем из очереди
		CallbackEvent.queue[ hash ] = nil
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, CallbackEvent.init )