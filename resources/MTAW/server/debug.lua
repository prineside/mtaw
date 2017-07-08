--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Debug.onClientBugreport", true )										-- Клиент отправил сообщение об ошибке ( table data )

--------------------------------------------------------------------------------
--<[ Модуль Debug ]>------------------------------------------------------------
--------------------------------------------------------------------------------
Debug = {
	serverStartTime = getTickCount();
	traceback = nil;
	
	monthNames = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
	
	startupPrintQueue = {};		-- Сообщения за первых 2 секунды загрузки сервера, которые будут напечатаны чуть позже (чтобы попало в логи)
	
	init = function()
		addEventHandler( "Debug.onClientBugreport", resourceRoot, Debug.onClientBugreport )

		local t = getRealTime()
		local bcpPath = string.format( "server/data/debug-bugreports/server_%02d.%02d.%04d.txt", t.monthday, t.month + 1, 1900 + t.year )
		
		if ( not fileExists( bcpPath ) ) then
			if ( fileExists( "debug.log" ) ) then
				fileCopy( "debug.log", bcpPath, true )
				fileDelete( "debug.log" )
			end
		end
		
		Main.setModuleLoaded( "Debug", 1 )
	end;
	
	-- Выводит в лог сервера строку с отметкой tag, используется в Debug.info, Debug.warn и подобных
	-- > tag string - метка строки в логе
	-- > str string - строка, которую нужно вывести в лог
	-- = void
	print = function( tag, str )

		local formated = "[" .. tag .. "] " .. tostring( str )
		local ptr = 1
		while ptr < #formated do
			outputServerLog( string.sub( formated, ptr, ptr + 2048 ) )
			ptr = ptr + 2048
		end
			
		if ( tag == "E" or tag == "W" or tag == "C" ) then
			local hdl
			if ( fileExists( "debug.log" ) ) then
				hdl = fileOpen( "debug.log" )
			else
				hdl = fileCreate( "debug.log" )
			end
			
			fileSetPos( hdl, fileGetSize( hdl ) )
			local t = getRealTime()
			fileWrite( hdl, string.format( "%s %02d | %02d:%02d:%02d [%s] %s \n", Debug.monthNames[ t.month + 1 ], t.monthday, t.hour, t.minute, t.second, tag, tostring( str ) ) )
			fileClose( hdl )
		end
	end;
	
	-- Вывести в лог информационное сообщение
	-- > message string
	-- = void
	info = function( message )
		if ( tostring( message ) == nil ) then
			Debug.print( "[I] [Has no tostring() method]" )
		else
			Debug.print( "I", message )
		end
	
		return nil
	end;
	
	-- Вывести в лог предупреждение
	-- > message string
	-- = void
	warning = function( message )
		Debug.print( "I", message )
		return nil
	end;
	
	-- Вывести в лог сообщение об ошибке, а также стек вызовов
	-- > message string
	-- = void
	error = function( message )
		Debug.print( "E", message )
		Debug.print( "E", debug.traceback() )
		if ( Debug.traceback ) then
			Debug.print( "E", Debug.traceback )
			Debug.traceback = nil
		end
		return nil
	end;
	
	-- Вывести в лог сообщение о критической ошибке и стек вызовов, кикнуть всех игроков из сервера и аварийно завершить работу
	-- > message string
	-- = void
	critical = function( message )
		Debug.print( "C", message )
		Debug.print( "C", debug.traceback() )
		if ( Debug.traceback ) then
			Debug.print( "C", Debug.traceback )
			Debug.traceback = nil
		end
		
		for id, player in ipairs( getElementsByType("player") ) do
			kickPlayer( player, "Critical system error" )
		end
		setTimer( function() shutdown( "Critical error, see server.log" ) end, 8000, 1 )
		return nil
	end;
	
	-- Вывести в лог информацию об объекте (распечатывает в удобном виде структуру таблиц)
	-- > v mixed
	-- = void
	print_r = function( v )
		Debug.print( "P",  type( v ) .. " " .. tostring( v ) )
		Debug.print( "P",  dumpvar( v ) )
	end;
	
	-- Установить дополнительный traceback (на случай, если идет отладка асинхронного кода)
	-- > v table
	-- = void
	setTraceback = function( v )
		Debug.traceback = v
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Клиент прислал отчет об ошибке
	onClientBugreport = function( data )
		if not validVar( data, "data", "table" ) then return nil end
		
		local playerElement = client
		if ( playerElement ) then
			if ( not data.callbackTraceback ) then data.callbackTraceback = "nil" end
			
			local reportTime = getRealTime()
			local reportHash = decimalToHex( reportTime.timestamp )
			local reportFingerprint = string.sub( hash( "md5", data.traceback .. data.callbackTraceback ), 1, 8 )
			
			local hdl = fileCreate ( "server/data/debug-bugreports/" .. reportFingerprint .. "_" .. reportHash .. ".txt" )
			
			fileWrite( hdl, string.format( 	"%s,%i,%s,%s,%s\r\n", reportFingerprint, reportTime.timestamp, reportHash, data.level, tostring( data.message ) ) )
			fileWrite( hdl, 				"\n" )
			fileWrite( hdl, 				"+------------------------------------------------------------------------------+\r\n" )
			fileWrite( hdl, 				"|                     Multi Theft Auto: World, mta-w.com                       |\r\n" )
			fileWrite( hdl, 				"|                     Copyright Prineside, prineside.com                       |\r\n" )
			fileWrite( hdl, 				"+------------------------------------------------------------------------------+\r\n" )
			fileWrite( hdl, 				"|                   Сообщение об ошибке на стороне клиента                     |\r\n" )
			fileWrite( hdl, 				"+------------------------------------------------------------------------------+\r\n" )
			fileWrite( hdl, 				"\r\n" )
			fileWrite( hdl, 				"--- Общие сведения -------------------------------------------------------------\r\n" )
			fileWrite( hdl, string.format( 	"    Хэш-номер отчета              : %s\r\n", reportHash ) )
			fileWrite( hdl, string.format( 	"    Отпечаток ошибки              : %s\r\n", reportFingerprint ) )
			fileWrite( hdl, string.format( 	"    Дата                          : %02d.%02d.%04d\r\n", reportTime.monthday, reportTime.month + 1, reportTime.year + 1900 ) )
			fileWrite( hdl, string.format( 	"    Время                         : %02d:%02d:%02d\r\n", reportTime.hour, reportTime.minute, reportTime.second ) )
			fileWrite( hdl, string.format( 	"    Клиентское время              : %02d:%02d:%02d\r\n", data.time.hour, data.time.minute, data.time.second ) )
			fileWrite( hdl, string.format( 	"    Номер ошибки за сеанс игры    : %i\r\n", 1 ) ) -- TODO
			fileWrite( hdl, string.format( 	"    Версия клиента                : %s\r\n", getPlayerVersion( playerElement ) ) )
			fileWrite( hdl, 				"\r\n" )
			fileWrite( hdl, 				"--- Ошибка ---------------------------------------------------------------------\r\n" )
			fileWrite( hdl, string.format( 	"    Файл                          : %s\r\n", tostring( data.file ) ) )
			fileWrite( hdl, string.format( 	"    Строка                        : %s\r\n", tostring( data.line ) ) )
			fileWrite( hdl, string.format( 	"    Уровень ошибки                : %s\r\n", tostring( data.level ) ) )
			fileWrite( hdl, string.format( 	"    Сообщение                     : %s\r\n", tostring( data.message ) ) )
			fileWrite( hdl, 				"\r\n" )
			fileWrite( hdl, 				"--- Стек вызовов ---------------------------------------------------------------\r\n" )
			fileWrite( hdl, 				data.traceback .. "\r\n" )
			fileWrite( hdl, 				"Callback traceback:\r\n" )
			fileWrite( hdl, 				data.callbackTraceback .. "\r\n" )
			fileWrite( hdl, 				"\r\n" )
			fileWrite( hdl, 				"--- Дополнительные данные ------------------------------------------------------\r\n" )
			fileWrite( hdl, 				dumpvar( data.additional ) )
			fileWrite( hdl, 				"\r\n" )
			fileWrite( hdl, 				"--- Информация от клиента ------------------------------------------------------\r\n" )
			fileWrite( hdl, string.format( 	"    Пинг                          : %i\r\n", data.clientDebug.ping ) )
			fileWrite( hdl, string.format( 	"    Заморожен                     : %s\r\n", data.clientDebug.frozen ) )
			fileWrite( hdl, string.format( 	"    В воде                        : %s\r\n", data.clientDebug.inWater ) )
			fileWrite( hdl, string.format( 	"    На экране                     : %s\r\n", data.clientDebug.onScreen ) )
			fileWrite( hdl, string.format( 	"    В стриме                      : %s\r\n", data.clientDebug.streamed ) )
			fileWrite( hdl, string.format( 	"    Ждет загрузку объектов        : %s\r\n", data.clientDebug.waitingLoad ) )
			fileWrite( hdl, string.format( 	"    Позиция игрока                : %0.2f, %0.2f, %0.2f\r\n", data.clientDebug.x, data.clientDebug.y, data.clientDebug.z ) )
			fileWrite( hdl, string.format( 	"    Угол поворота игрока          : %0.2f\r\n", data.clientDebug.angle ) )
			fileWrite( hdl, string.format( 	"    Измерение                     : %i\r\n", data.clientDebug.dimension ) )
			fileWrite( hdl, string.format( 	"    Интерьер                      : %i\r\n", data.clientDebug.interior ) )
			fileWrite( hdl, string.format( 	"    Здоровье                      : %0.2f\r\n", data.clientDebug.health ) )
			fileWrite( hdl, string.format( 	"    Игровое время                 : %02d:%02d\r\n", data.clientDebug.ingameH, data.clientDebug.ingameM ) )
			fileWrite( hdl, string.format( 	"    Интерьер камеры               : %i\r\n", data.clientDebug.camInterior ) )
			fileWrite( hdl, string.format( 	"    Измерение камеры              : %i\r\n", data.clientDebug.camDimension ) )
			fileWrite( hdl, string.format( 	"    Видео\n" ) )
			fileWrite( hdl, string.format( 	"      |- Режим тестирования       : %s\r\n", data.clientDebug.dxStatus.TestMode ) )
			fileWrite( hdl, string.format( 	"      |- Название видеокарты      : %s\r\n", data.clientDebug.dxStatus.VideoCardName ) )
			fileWrite( hdl, string.format( 	"      |- Объем видеопамяти        : %0.2f Mb\r\n", data.clientDebug.dxStatus.VideoMemoryFreeForMTA ) )
			fileWrite( hdl, string.format( 	"      '- Занято видеопамяти\r\n" ) )
			fileWrite( hdl, string.format( 	"         |- Шрифты                : %0.2f Mb\r\n", data.clientDebug.dxStatus.VideoMemoryUsedByFonts ) )
			fileWrite( hdl, string.format( 	"         |- Текстуры              : %0.2f Mb\r\n", data.clientDebug.dxStatus.VideoMemoryUsedByTextures ) )
			fileWrite( hdl, string.format( 	"         '- Области отрисовки     : %0.2f Mb\r\n", data.clientDebug.dxStatus.VideoMemoryUsedByRenderTargets ) )
			fileWrite( hdl, string.format( 	"    Сеть\r\n" ) )
		for k, v in pairs( data.clientDebug.netstats ) do
			fileWrite( hdl, string.format( 	"        %s : %s\r\n", k, v ) )
		end
			fileWrite( hdl, 				"\r\n" )
			fileClose( hdl )
			
			Debug.info( "Got bug report from client (#" .. reportHash .. " @" .. reportFingerprint ..")" )
		end
	end;
}
addEventHandler( "onResourceStart", resourceRoot, Debug.init )