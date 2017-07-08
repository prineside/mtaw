--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Time.onSync", true )													-- Сервер ответил на синхронизацию ( number requestSentTick, number serverTickCount, number serverTimestamp )

--------------------------------------------------------------------------------
--<[ Модуль Time ]>-------------------------------------------------------------
--------------------------------------------------------------------------------
Time = {
	isEnabled = false;			-- Если true, GTA-время будет синхронизировано с Ingame

	startingYear = 2015;
	
	daysPerMonth = {
		{	n = { 	30, 29, 30, 30, 30, 30, 30, 30, 30, 30, 30, 31 		},		-- 1-3 реальный месяц 	(1 из 4 лет в игре)
			l = { 	31, 30, 31, 30, 30, 30, 31, 30, 30, 30, 30, 31 		}	},	--     (если год високосный)
		{			31, 29, 31, 30, 30, 30, 31, 30, 30, 31, 30, 31 		},		-- 4-6 					(2 игровой год)
		{			31, 29, 31, 31, 31, 31, 31, 31, 30, 31, 30, 31 		},		-- 7-9					(3 игровой год)
		{			31, 29, 31, 31, 31, 31, 31, 31, 30, 31, 30, 31		}		-- 10-12				(4 игровой год)
	};
	
	initSync = false;			-- Было ли синхронизировано время хоть раз
	
	timeValidationInterval = 15000; -- Интервал синхронизации времени GTA с Ingame (вдруг MinuteDuration работает неточно)
	
	syncInterval = 3000;
	syncQueueSize = 5;			-- Количество последних синхронизаций, из которых будет взято среднее значение
	
	syncQueueTick = {};			-- Последних 3 синхронизации (используется среднее время)
	syncQueueTimestamp = {};
	syncQueuePointer = 1;
	syncDelay = {};				-- Время от запроса до получения ответа
	
	syncIteration = 0;			-- Текущий номер синхронизации
	
	_gstcdValue = 0;			-- tickCount
	_gstcdIter = -1;
	
	_gsttdValue = 0;			-- timestamp
	_gsttdIter = -1;
	
	init = function()
		-- Обработчики событий
		addEventHandler( "Main.onClientLoad", resourceRoot, Time.onClientLoad )
		addEventHandler( "Time.onSync", resourceRoot, Time.onServerSync )
		addEventHandler( "Character.onCharacterChange", resourceRoot, Time.onCharacterChange, false, "high" )
		
		Main.setModuleLoaded( "Time", 0.5 )
		
		-- Синхронизируем время с сервером
		setTimer( function() 
			triggerServerEvent( "Time.onSync", resourceRoot, Time.getClientTickCount() ) 
		end, Time.syncInterval, 0 )
		triggerServerEvent( "Time.onSync", resourceRoot, Time.getClientTickCount() )
		
		-- Периодически сверяем GTA-время с Ingame
		setTimer( Time._validateGTATime, Time.timeValidationInterval, 0 )
	end;
	
	onClientLoad = function()
		
	end;
	
	-- Включить синхронизацию Ingame-времени с временем GTA
	-- = void
	enable = function()
		Time.isEnabled = true
		
		Time.applyIngameTimeToGTA()
	end;
	
	-- Отключить синхронизацию времени GTA с Ingame и остановить время
	-- = void
	disable = function()
		Time.isEnabled = false
		
		setMinuteDuration( 1000 * 60 * 60 * 24 )
	end;
	
	-- Применить текущее Ingame-время к GTA и установить продолжительность минуты
	-- = void
	applyIngameTimeToGTA = function()
		local h, m, s = Time.getIngameTime()
		local curH, curM = getTime()
		
		if ( curH ~= h ) then
			-- Сначала грубо - если время совсем не соответствует
			-- TODO если время отличается больше чем на 4 минуты, установка h, m
		end
		
		-- Затем точно - задержка до 15 секунд 
		local syncH = h
		local syncM = m + 1
		if ( syncM == 60 ) then
			syncM = 0
			syncH = syncH + 1
			if ( syncH == 24 ) then
				syncH = 0
			end
		end
		
		setMinuteDuration( 1000 * 15 )
		
		local syncDelay = ( 60 - s ) * 250
		if ( syncDelay < 50 ) then
			-- Меньше чем через 50мс будет следующая минута
			setTime( h, m )
		else
			-- Следующая минута будет больше чем через 50мс
			setTimer( function()
				if ( Time.isEnabled ) then
					setTime( syncH, syncM )
				end
			end, syncDelay, 1 )
		end
	end;
	
	-- Получить разницу tickCount сервера и клиента
	-- = number tickDelta
	getServerTickDelta = function()
		if ( Time._gstcdIter == Time.syncIteration ) then
			-- Не было синхронизации с момента последнего вызова, отправляем кэш
			return Time._gstcdValue
		else
			local syncCount = 0
			local syncSum = 0
			
			for i = 1, Time.syncQueueSize do
				if ( Time.syncQueueTick[ i ] ~= nil ) then
					syncSum = syncSum + Time.syncQueueTick[ i ]
					syncCount = syncCount + 1
				else
					break
				end
			end
			
			local delta = math.ceil( syncCount ~= 0 and ( syncSum / syncCount ) or 0 )
			
			Time._gstcdIter = Time.syncIteration
			Time._gstcdValue = delta
			
			return delta
		end
	end;
	
	-- Получить разницу timestamp клиента и сервера
	-- = number timestampDelta
	getServerTimestampDelta = function()
		if ( Time._gsttdIter == Time.syncIteration ) then
			-- Не было синхронизации с момента последнего вызова, отправляем кэш
			return Time._gsttdValue
		else
			local syncCount = 0
			local syncSum = 0
			
			for i = 1, Time.syncQueueSize do
				if ( Time.syncQueueTimestamp[ i ] ~= nil ) then
					syncSum = syncSum + Time.syncQueueTimestamp[ i ]
					syncCount = syncCount + 1
				else
					break
				end
			end
			
			local delta = math.ceil( syncCount ~= 0 and ( syncSum / syncCount ) or 0 )
			
			Time._gsttdIter = Time.syncIteration
			Time._gsttdValue = delta
			
			return delta
		end
	end;
	
	-- Обертка для getTickCount(), возвращает текущий tickCount в мс. (чаще для тестов)
	-- = number clientTickCount
	getClientTickCount = function()
		return getTickCount()
		-- Тест - переводим tickCount на минуту вперед
		-- return getTickCount() + 60000
	end;
	
	-- Обертка для getRealTime().timestamp, возвращает текущий Unix timestamp (чаще для тестов)
	-- = number clientTimestamp
	getClientTimestamp = function()
		return getRealTime().timestamp
		-- Тест - переводим timestamp на минуту вперед
		-- return getRealTime().timestamp + 60
	end;
	
	-- Возвращает текущий tickcount сервера
	-- = number serverTimestamp
	getServerTimestamp = function()
		return Time.getClientTimestamp() - Time.getServerTimestampDelta()
	end;
	
	-- Возвращает текущий tickCount сервера
	-- = number serverTickCount
	getServerTickCount = function()
		return Time.getClientTickCount() - Time.getServerTickDelta()
	end;
	
	-- Получить текущее игровое время (если указан timestamp, узнать время, которое будет на сервере по реальному timestamp)
	-- > timestamp number / nil - метка времени, для которой нужно найти игровое время. По умолчанию - текущий timestamp сервера
	-- = number ingameHours, number ingameMinutes, number ingameSeconds
	getIngameTime = function( timestamp )
		if ( timestamp == nil ) then timestamp = Time.getServerTimestamp() end
		
		local r = getRealTime( timestamp )
		local daySeconds
		
		daySeconds = ( ( ( r.hour * 3600 ) + ( r.minute * 60 ) + r.second ) * 4 ) % ( 24 * 3600 )

		return math.floor( daySeconds / 3600 ), math.floor( ( daySeconds % 3600 ) / 60 ), daySeconds % 60
	end;
	
	-- Получить игровую дату (если указан timestamp, узнать дату, которая будет на сервере по реальному timestamp)
	-- > timestamp number / nil - метка времени, для которой нужно найти игровую дату. По умолчанию - текущий timestamp
	-- = number ingameYear, number ingameMonth, number ingameDay
	getIngameDate = function( timestamp )
		if not validVar( timestamp, "timestamp", { "number", "nil" } ) then return nil end
		
		if ( timestamp == nil ) then timestamp = Time.getServerTimestamp() end
		
		local curTime = getRealTime( timestamp )
		local curMonth = curTime.month + 1
		local curYear = curTime.year + 1900
		local isLeap = isLeapYear( curYear )
		
		local yearsLeft = curYear - Time.startingYear
		local monthLeft = curTime.month
		
		local ingameMonthDurabilities
		local realDaysFromStartOfIngameYear
		
		if ( curMonth >= 1 and curMonth <= 3 ) then
			if ( isLeap ) then
				ingameMonthDurabilities = Time.daysPerMonth[ 1 ].l
			else
				ingameMonthDurabilities = Time.daysPerMonth[ 1 ].n
			end
			realDaysFromStartOfIngameYear = curTime.yearday
		else
			local ingameNumberOfFourYears = math.ceil( curMonth / 3 )
			ingameMonthDurabilities = Time.daysPerMonth[ ingameNumberOfFourYears ]
			if ( ingameNumberOfFourYears == 2 ) then
				realDaysFromStartOfIngameYear = curTime.yearday - 90
			elseif ( ingameNumberOfFourYears == 3 ) then
				realDaysFromStartOfIngameYear = curTime.yearday - 90 - 91
			else
				realDaysFromStartOfIngameYear = curTime.yearday - 90 - 91 - 92
			end
			if ( isLeap ) then
				realDaysFromStartOfIngameYear = realDaysFromStartOfIngameYear - 1
			end
		end
		
		local curIngameYear = Time.startingYear + ( yearsLeft * 4 ) + math.floor( monthLeft / 4 )
		local ingameDaysPast = realDaysFromStartOfIngameYear * 4 + math.floor( curTime.hour / 6 )
		
		local curIngameMonth
		local curIngameMonthday
		
		local _daycount = 0
		
		for i = 1, 12 do
			if ( _daycount + ingameMonthDurabilities[ i ] > ingameDaysPast ) then
				curIngameMonth = i
				curIngameMonthday = ingameDaysPast - _daycount + 1
				break
			else
				_daycount = _daycount + ingameMonthDurabilities[ i ]
			end
		end
		
		return curIngameYear, curIngameMonth, curIngameMonthday
	end;
	
	-- Синхронизировать время Ingme и GTA, если Time.isEnabled
	_validateGTATime = function()
		if ( Time.isEnabled ) then
			Time.applyIngameTimeToGTA()
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Сервер прислал свой timestamp
	onServerSync = function( requestSentTick, serverTickCount, serverTimestamp )
		-- requestSentTick - tick на клиенте, когда был отправлен запрос
		-- serverTickCount - tick на сервере, когда он получил запрос
		-- пинг от клиента к серверу = ( getTickCount() - requestSentTick ) / 2
		-- следовательно, разница во времени: ( текущий клиент - полученный сервер ) + ping
		local serverTickDelta = ( Time.getClientTickCount() - serverTickCount ) - ( ( Time.getClientTickCount() - requestSentTick ) / 2 )
		Time.syncQueueTick[ Time.syncQueuePointer ] = serverTickDelta
		
		local serverTimestampDelta = Time.getClientTimestamp() - serverTimestamp
		Time.syncQueueTimestamp[ Time.syncQueuePointer ] = serverTimestampDelta
		
		Time.syncDelay[ Time.syncQueuePointer ] = Time.getClientTickCount() - requestSentTick
		
		Time.syncQueuePointer = Time.syncQueuePointer + 1
		if ( Time.syncQueuePointer > Time.syncQueueSize ) then
			Time.syncQueuePointer = 1
		end
		
		if ( not Time.initSync ) then
			-- Первая синхронизация
			Time.initSync = true
			Main.setModuleLoaded( "Time", 1 )
		end
		
		Time.syncIteration = Time.syncIteration + 1
	end;
	
	-- Изменился персонаж игрока
	onCharacterChange = function()
		-- Включаем синхронизацию, когда заспавнили персонаж, и выключаем, когда деспавнили
		if ( Character.isSelected() ) then
			Time.enable()
		else
			Time.disable()
		end
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, Time.init )