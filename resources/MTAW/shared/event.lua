--[[
	Система событий для таблиц, похожа на стандартную, за исключением:
	- вместо элементов используются объекты (таблицы)
	- соответственно иерархии нет, и события вызываютя только для одного объекта
	- события могут быть только серверные либо только клиентские, так как передать таблицу по сети нельзя
	- стандартные события не влияют на Event, и наоборот, Event не влияет на стандартные события
	Зачем: 
	- не нужно создавать элементы, если нужно ограничить область действия события. В стандартной системе нужно либо создавать элемент (боком вылазит лимит элементов и затраченные ресурсы на них), либо убивать производительность, проверяя при каждом событии в каждом обработчике с чем именно произошло событие (куча условий и длинные циклы)
	- стандартная система банально не позволяет вешать обработчики на объекты (таблицы), следственно, толкает на лимиты элементов и падение производительности
	Когда использовать:
	Всегда, если речь идет не об элементах (в случае с элементами стоит использовать стандартную систему) и не о синхронизации киента с сервером.
	
	Пример:
	Контейнер. Контейнер - это объект, который вызывает лишь одно событие об изменении вещи в слоту.Контейнерв могут быть тысячи (это ящики, багажники, бардачки, инвентари, слоты быстрого доступа, тумбочки, холодильники и сотни других вещей), следовательно 65535 элементов могут очень быстро разойтись только на них (а делать стример элементов слишком болезненно, а то и вовсе невозможно). Так как элементы использовать не получится, а вызывать событие сразу на весь мод очень глупо (так как вызовется абсолютно каждый обработчик всех контейнеров, и в каждом будет сверяться необходимый контейнер с тем, что был изменен), более логично было бы добавлять обработчиков только на этот контейнер, и при событии вызывать только их. Для этого используется кастомное событие с источником в виде таблиц.
	
	Второй пример:
	Произошла ошибка на стороне клиента, модуль Debug собирает информацию. Для этого он вызывает событие Debug.onCollectBugReportData с источником Debug (собой), которым собирает информацию из остальных модулей. В свою очередь каждый желающий модуль может добавить обработчик события Debug.onCollectBugReportData на Debug и установить данные через Event.setData. После вызова события модуль Debug получит все данные из Event.getData и отправит на сервер
--]]

--------------------------------------------------------------------------------
--<[ Модуль Event ]>------------------------------------------------------------
--------------------------------------------------------------------------------
Event = {
	_priorities = { "veryHigh", "high", "normal", "low", "veryLow" };			-- Приоритет обработчиков в порядке значимости
	
	_data = {};
	_wasCancelled = false;
	_stopedPropagation = false;
	
	handlers = {};			
	--[[
		eventName => { 
			eventSource => { 
				"veryLow" => {}
				"low" => {}
				"normal" => {}
				"high" => {}
				"veryHigh" => {
					eventHandler => true 
				}
			}
		}
	--]]
	
	-- Добавить обработчик события, которое вызывается на eventSource
	-- Аналог addEventHandler
	-- > eventName string - название события
	-- > eventSource table - источник события
	-- > handlerFunction function - функция, которая будет вызвана для обработки события
	-- > priority string / nil - приоритет вызова обработчика при событии (veryLow, low, normal, high, veryHigh), по умолчанию normal
	-- = void
	addHandler = function( eventName, eventSource, handlerFunction, priority )
		if not validVar( eventName, "eventName", "string" ) then return nil end
		if not validVar( eventSource, "eventSource", "table" ) then return nil end
		if not validVar( handlerFunction, "handlerFunction", "function" ) then return nil end
		if not validVar( priority, "priority", { "string", "nil" } ) then return nil end
		
		local priorityExists = false
		if ( priority == nil ) then
			priority = "normal"
			priorityExists = true
		else
			for _, p in pairs( Event._priorities ) do
				if ( priority == p ) then
					priorityExists = true
					break
				end
			end
		end
		
		if ( not priorityExists ) then
			Debug.error( "Priority \"" .. priority .. "\" not exists" )
			return nil
		end
		
		if ( Event.handlers[ eventName ] == nil ) then
			Event.handlers[ eventName ] = setmetatable( {}, { __mode = 'k' } )
			--Event.handlers[ eventName ] = {}
		end
		
		if ( Event.handlers[ eventName ][ eventSource ] == nil ) then
			local t = {}
			for _, p in pairs( Event._priorities ) do
				t[ p ] = {}
			end
			Event.handlers[ eventName ][ eventSource ] = t
		end
		
		--Debug.info( "Added event \"" .. eventName .. "\" handler for source " .. tostring( eventSource ) .. ", priority " .. priority .. " and function " .. tostring( handlerFunction ) )
		Event.handlers[ eventName ][ eventSource ][ priority ][ handlerFunction ] = true
	end;
	
	-- Убрать обработчик(и) события
	-- > eventName string - название события
	-- > eventSource table / nil - источник события. Если не указан, будут отменены все обработчики данного события для всех источников
	-- > handlerFunction function / nil - функция обработчика, которая будет отменена. Если не указана, будут отменены все обработчики с названием события (если указан источник, то только для этого источника)
	-- = void
	removeHandler = function( eventName, eventSource, handlerFunction )
		if not validVar( eventName, "eventName", "string" ) then return nil end
		if not validVar( eventSource, "eventSource", { "table", "nil" } ) then return nil end
		if not validVar( handlerFunction, "handlerFunction", { "function", "nil" } ) then return nil end
		
		if ( eventSource ~= nil ) then
			if ( handlerFunction ~= nil ) then
				-- eventName, eventSource, handlerFunction
				if ( Event.handlers[ eventName ] ~= nil ) then
					if ( Event.handlers[ eventName ][ eventSource ] ~= nil ) then
						for _, p in pairs( Event._priorities ) do
							if ( Event.handlers[ eventName ][ eventSource ][ p ][ handlerFunction ] ~= nil ) then
								Event.handlers[ eventName ][ eventSource ][ p ][ handlerFunction ] = nil
							end
						end
					end
				end
			else
				-- eventName, eventSource
				if ( Event.handlers[ eventName ] ~= nil ) then
					if ( Event.handlers[ eventName ][ eventSource ] ~= nil ) then
						Event.handlers[ eventName ][ eventSource ] = nil
					end
				end
			end
		else
			if ( handlerFunction ~= nil ) then
				-- eventName, handlerFunction
				if ( Event.handlers[ eventName ] ~= nil ) then
					for _, eps in pairs( Event.handlers[ eventName ] ) do
						for _, p in pairs( Event._priorities ) do
							if ( eps[ p ][ handlerFunction ] ~= nil ) then
								eps[ p ][ handlerFunction ] = nil
							end
						end
					end
				end
			else
				-- eventName
				if ( Event.handlers[ eventName ] ~= nil ) then
					Event.handlers[ eventName ] = nil
				end
			end
		end
	end;
	
	-- Возвращает таблицу обработчиков события в порядке их приоритетности (сначала выше), точно в том же, в котором они были бы вызваны
	-- Вернет nil, если на событии нет обработчиков или неверно указаны данные
	-- > eventName string - название события
	-- > eventSource table - источник события
	-- = table / nil eventHandlers
	getHandlers = function( eventName, eventSource )
		if not validVar( eventName, "eventName", "string" ) then return nil end
		if not validVar( eventSource, "eventSource", "table" ) then return nil end
		
		if ( Event.handlers[ eventName ] == nil ) then
			return nil
		else
			if ( Event.handlers[ eventName ][ eventSource ] == nil ) then
				return nil
			else
				local handlers = {}
				for _, p in pairs( Event._priorities ) do
					for handler, _ in pairs( Event.handlers[ eventName ][ eventSource ][ p ] ) do
						table.insert( handlers, handler )
					end
				end
				
				return handlers
			end
		end
	end;
	
	-- Вызвать событие. Возвращает false, если событие было отменено в каком-либо из обработчиков
	-- > eventName string - название события
	-- > eventSource table - источник события (как правило, объект)
	-- > ... mixed - аргументы, переданные в событие
	-- = bool wasNotCancelled
	trigger = function( eventName, eventSource, ... )
		if not validVar( eventName, "eventName", "string" ) then return nil end
		if not validVar( eventSource, "eventSource", "table" ) then return nil end
		
		Event._data = {}
		Event._wasCancelled = false
		Event._stopedPropagation = false
		
		local handlers = Event.getHandlers( eventName, eventSource )
		if ( handlers ~= nil ) then
			for _, handler in pairs( handlers ) do
				if ( Event._stopedPropagation ) then
					break
				else
					handler( ... )
				end
			end
		else
			--Debug.info( "Event " .. eventName .. " with source " .. tostring( eventSource ) .. " has no handlers" )
		end
		
		return not Event._wasCancelled
	end;
	
	-- Отменить текущее событие (вызывается в обработчиках событий)
	-- Событие не прекращает передаваться к другим обработчикам, но wasCanceled вернет true
	-- = void
	cancel = function()
		Event._wasCancelled = true
	end;
	
	-- Остановить распространение события на другие обработчики
	-- Может быть полезно, если событие отменяется в обработчиках с более высоким приоритетом, чтобы не делать лишнюю работу
	-- = void
	stopPropagation = function()
		Event._stopedPropagation = true
	end;
	
	-- Возвращает true, если последнее вызванное событие было отменено через Event.cancel
	-- Аналогичное значение возвращает Event.trigger
	-- = bool wasCancelled
	wasCancelled = function()
		return Event._wasCancelled
	end;
	
	-- Возвращает данные, установленные событию внутри обработчика через setData
	-- > key mixed / nil - ключ, использованный в setData. Если не указан (nil), возвращает таблицу со всеми установленными данными
	-- = table / mixed / nil value
	getData = function( key )
		if ( key == nil ) then
			return Event._data
		else
			return Event._data[ key ]
		end
	end;
	
	-- Устанавливает данные текущему событию, которые могут быть получены в других обработчиках или в скрипте-источнике события
	-- Используется внутри обработчиков событий
	-- > key mixed - ключ 
	-- > value mixed - значение
	-- = void
	setData = function( key, value )
		if ( key == nil ) then 
			Debug.error( "Key must be defined, nil given" )
			return nil 
		end
		
		Event._data[ key ] = value
	end;
}