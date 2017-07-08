--[[
	Пример использования:
	local event = DelayedEvent( 2000, "onClientRender" )
	event:onStart( function( event ) ... end )
	event:onProcess( function( event ) ... end )
	event:onStop( function( event, isSuccess ) ... end )
	event:start()
	Debug.info( "Событие началось" )
	
	! Внимание !
	Не забываем, что событие должно быть создано заново перед каждым началом, т.е. нельзя одно событие запускать дважды
--]]

--------------------------------------------------------------------------------
--<[ Модуль DelayedEvent ]>-----------------------------------------------------
--------------------------------------------------------------------------------
DelayedEvent = {
	events = {};

	init = function()
		Main.setModuleLoaded( "DelayedEvent", 1 )
	end;
	
	-- Создает новый объект события с задержкой. Событие необходимо начать (event:start()), см. пример использования в файле модуля
	-- > executionTime number - время (мс) необходимое для выполнения события
	-- > interval number / string / nil - интервал вызова функции объекта "process". Число - таймер (мс), строка - название события (чаще всего onClientRender), по умолчанию "onClientRender"
	-- = DelayedEvent eventObject
	create = function( executionTime, interval )
		if not validVar( executionTime, "executionTime", "number" ) then return nil end
		if not validVar( interval, "interval", { "number", "string", "nil" } ) then return nil end
		
		if ( interval == nil ) then interval = "onClientRender" end
		
		if ( type( interval ) == "number" ) then
			if ( interval < 50 ) then
				Debug.error( "Интервал не может быть меньше 50мс" )
				return nil
			end
		end
		
		if ( executionTime < 50 ) then
			Debug.error( "Время выполнения не может быть меньше 50мс" )
			return nil
		end
		
		-- Создаем объект события
		local event = setmetatable( {}, DelayedEvent )
		local eventID = tostring( event )
		
		DelayedEvent.events[ eventID ] = event
		
		event.id = eventID
		event.status = "new"
		event.executionTime = executionTime
		event.interval = interval
		
		-- Очистка списков обработчиков
		event.processHandlers = {}
		event.stopHandlers = {}
		event.startHandlers = {}
		
		return event
	end;
	
	-- Instance ----------------------------------------------------------------
	
	id = nil;
	status = nil;
	interval = nil;
	processTimer = nil;
	processFunction = nil;
	
	processHandlers = {};
	stopHandlers = {};
	startHandlers = {};
	
	executionTime = nil;	-- Общее время выполнения
	startTick = nil;		-- Начало события
	progress = 0;			-- Прогресс выполнения события
	
	-- Начать событие
	-- > self DelayedEvent
	-- = void
	start = function( self )
		self.startTick = getTickCount()
		self.status = "running"
		
		-- Ставим таймер завершения события
		setTimer( function( eventID ) 
			local event = DelayedEvent.events[ eventID ]
			if ( event ~= nil ) then
				event:stop( true )
			else
				-- Debug.warn( "События с ID " .. eventID .. " не существует" )
			end
		end, self.executionTime, 1, self.id )
		
		-- Ставим таймер process
		if ( type( self.interval ) == "number" ) then
			-- Таймер
			self.processTimer = setTimer( function( eventID )
				local event = DelayedEvent.events[ eventID ]
				if ( event ~= nil ) then
					event:_process()
				else
					Debug.info( "D" )
				end
			end, self.interval, 0, self.id )
		else
			-- Событие
			self.processFunction = function()
				self:_process()
			end
			
			addEventHandler( self.interval, root, self.processFunction )
		end
		
		-- Вызываем обработчики onStart
		for f, _ in pairs( self.startHandlers ) do
			f( self )
		end
	end;
	
	-- Остановить событие
	-- > self DelayedEvent
	-- > isSuccess bool / nil - успешно ли выполнилось событие. По умолчанию false
	-- = void
	stop = function( self, isSuccess )
		if ( isSuccess == nil ) then isSuccess = false end
		
		--Debug.info( "Событие завершено", isSuccess )
		
		self.status = "stoped"
		
		if ( isSuccess ) then
			self.progress = 1
		end
		
		-- Убираем обработчик события
		if ( self.processTimer ~= nil ) then
			-- process вызывался по таймеру, убиваем его
			killTimer( self.processTimer )
		else
			-- process был обработчиком события
			removeEventHandler( self.interval, root, self.processFunction )
		end
		
		-- Вызываем обработчики остановки события
		for f, _ in pairs( self.stopHandlers ) do
			f( self, isSuccess )
		end
		
		-- Удаляем из списка событий
		DelayedEvent.events[ self.id ] = nil
	end;
	
	-- Забиндить функцию, которая вызывается вначале события
	-- event:onStart( function( event ) ... end )
	-- > self DelayedEvent
	-- > handlerFunction function - функция, которая будет вызвана вначале события: function( DelayedEvent delayedEvent ) ... end
	-- = void
	onStart = function( self, handlerFunction )
		self.startHandlers[ handlerFunction ] = true
	end;
	
	-- Забиндить функцию, которая вызывается переодически
	-- event:onProcess( function( event ) ... end )
	-- > self DelayedEvent
	-- > handlerFunction function - функция, которая будет вызвана с интервалом или при указанном при создании событием: function( DelayedEvent delayedEvent ) ... end
	-- = void
	onProcess = function( self, handlerFunction )
		self.processHandlers[ handlerFunction ] = true
	end;
	
	-- Забиндить функцию, которая вызывается по завершению события
	-- event:onStop( function( event, isSuccess ) ... end ), также если isSuccess, event.progress будет равно 1
	-- > self DelayedEvent
	-- > handlerFunction function - функция, которая будет вызвана по завершению события: function( DelayedEvent delayedEvent, bool isSuccess ) ... end
	onStop = function( self, handlerFunction )
		self.stopHandlers[ handlerFunction ] = true
	end;
	
	-- Вызывается при событии / по таймеру
	_process = function( self )
		self.progress = ( getTickCount() - self.startTick ) / self.executionTime
		if ( self.progress > 1 ) then
			self.progress = 1
		end
		
		for f, _ in pairs( self.processHandlers ) do
			f( self )
		end
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, DelayedEvent.init )

DelayedEvent.__index = DelayedEvent
setmetatable( DelayedEvent, {
	__call = function ( cls, ... )
		return cls.create( ... )
	end,
} )