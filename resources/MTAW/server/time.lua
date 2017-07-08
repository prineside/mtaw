--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Time.onSync", true )	-- Клиент запрашивает синхронизацию ( number requestStartClientTick )

--------------------------------------------------------------------------------
--<[ Модуль Time ]>-------------------------------------------------------------
--------------------------------------------------------------------------------
Time = {
	startingYear = 2015;
	
	daysPerMonth = {
		{	n = { 	30, 29, 30, 30, 30, 30, 30, 30, 30, 30, 30, 31 		},		-- 1-3 реальный месяц 	(1 из 4 лет в игре)
			l = { 	31, 30, 31, 30, 30, 30, 31, 30, 30, 30, 30, 31 		}	},	--     (если год високосный)
		{			31, 29, 31, 30, 30, 30, 31, 30, 30, 31, 30, 31 		},		-- 4-6 					(2 игровой год)
		{			31, 29, 31, 31, 31, 31, 31, 31, 30, 31, 30, 31 		},		-- 7-9					(3 игровой год)
		{			31, 29, 31, 31, 31, 31, 31, 31, 30, 31, 30, 31		}		-- 10-12				(4 игровой год)
	};
	
	init = function()
		addEventHandler( "Time.onSync", resourceRoot, Time.onClientTimeSync )
	end;
	
	-- Узнать tickcount сервера (заглушка для клиентской функции)
	-- = number serverTimestamp
	getServerTimestamp = function()
		return getRealTime().timestamp
	end;
	
	-- Узнать tickcount клиента
	-- = number clientTimestamp
	getClientTimestamp = function()
		-- TODO
		Debug.error( "Not implemented yet" )
	end;
	
	-- Получить игровое время для указанного timestamp
	-- > timestamp number / nil - timestamp, для которого нужно узнать время. По умолчанию - текущий timestamp сервера
	-- = number ingameHours, number ingameMinutes, number ingameSeconds
	getIngameTime = function( timestamp )
		if not validVar( timestamp, "timestamp", { "number", "nil" } ) then return nil end
		
		local r = getRealTime( timestamp )
		local daySeconds = ( ( ( r.hour * 3600 ) + ( r.minute * 60 ) + r.second ) * 4 ) % ( 24 * 3600 )
		return math.floor( daySeconds / 3600 ), math.floor( ( daySeconds % 3600 ) / 60 ), daySeconds % 60
	end;
	
	-- Получить игровую дату для указанного timestamp
	-- > timestamp number / nil - timestamp, для которого нужно узнать дату. По умолчанию - текущий timestamp
	-- = number ingameYear, number ingameMonth, number ingameDay
	getIngameDate = function( timestamp )
		-- TODO протестировать (помнится, месяц возвращался на 1 меньше, но не помнится, где - может сдвинуть продолжительность месяцев)
		if not validVar( timestamp, "timestamp", { "number", "nil" } ) then return nil end
		
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
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Клиент запросил синхронизацию времени
	onClientTimeSync = function( requestStartClientTick )
		triggerClientEvent( client, "Time.onSync", resourceRoot, requestStartClientTick, getTickCount(), Time.getServerTimestamp() )
	end;
};
addEventHandler( "onResourceStart", resourceRoot, Time.init )