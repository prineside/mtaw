--------------------------------------------------------------------------------
--<[ Модуль DB ]>---------------------------------------------------------------
--------------------------------------------------------------------------------
DB = {
	handles = {};
	mainHandle = nil;

	init = function()
		local node = xmlLoadFile( "server/data/db-handles.xml" )
		local handlesCount = 0
		if node ~= false then
			local children = xmlNodeGetChildren ( node )
			for i, cnode in ipairs( children ) do
				local engine = xmlNodeGetAttribute( cnode, "engine" )
				local name = xmlNodeGetAttribute( cnode, "name" )
				local host = xmlNodeGetAttribute( cnode, "host" )
				local login = xmlNodeGetAttribute( cnode, "login" )
				local password = xmlNodeGetAttribute( cnode, "password" )
				local database = xmlNodeGetAttribute( cnode, "database" )
				
				local handle
				if ( engine == "mysql" ) then
					handle = dbConnect( engine, "dbname=" .. database .. ";host=" .. host, login, password )
				else
					handle = dbConnect( engine, host, login, password )
				end
				
				if handle then
					DB.handles[ name ] = handle
					if DB.mainHandle == nil then
						DB.mainHandle = DB.handles[ name ]
					end
					handlesCount = handlesCount + 1
					dbExec( handle, "SET NAMES utf8" )
				else
					Debug.critical( "Unable to connect to " .. name )
				end
			end
		end
		Debug.info( "DB: opened " .. handlesCount .. " handle(s)" )
		Main.setModuleLoaded( "DB" )
	end;
	
	-- Возвращает элемент подключения к базе данных
	-- > handleName string / nil - название подключения, по умолчанию - основное
	-- = element dbConnection
	getHandle = function( handleName )
		if not validVar( handleName, "handleName", { "string", "nil" } ) then return nil end
		
		if ( handleName ) then
			return DB.handles[ handleName ]
		else
			return DB.mainHandle
		end
	end;
	
	-- Экранировать символы для защиты от SQL-инъекций, для подальшего использования в запросах (вставлять между '')
	-- > str string - аргумент, который нужно экранировать
	-- = string escapedString
	escapeString = function( str )
		-- TODO заменить на dbPrepareString с версии 1.5.2
		if not validVar( str, "str", "string" ) then return nil end
	
		local replacements = { ["\\"] = "\\\\", ["'"] = "\\'" }
		return str:gsub( "['\"]", replacements )
	end;
	
	-- Выполнить асинхронный запрос
	-- > query string - строка запроса
	-- > handleName string / nil - название подключения
	-- > cb function - функция, которая будет вызвана, когда запрос будет выполнен: cb( queryHandle ) local result = dbPoll( queryHandle, 0 ) ... end
	-- = void
	query = function( query, handleName, cb )
		-- TODO сделать обертку для cb, чтобы не вызывать dbPoll везде
		local handle = DB.getHandle( handleName )
		
		if ( cb == nil ) then cb = void end
		
		dbQuery( cb, handle, query )
	end;
	
	-- Выполняет запрос синхронно (блокирует выполнение скриптов)
	-- > query string - строка запроса
	-- > handleName string nil - название подключения
	-- = bool isSuccess, table / nil result, number affectedRows | errorCode, number / string insertID | errorMessage
	syncQuery = function( query, handleName )
		local handle = DB.getHandle( handleName )
		local queryHandle = dbQuery( handle, query )
		
		if ( queryHandle ) then
			local result, num_affected_rows, last_insert_id = dbPoll( queryHandle, -1 )
			if result == false then
				local error_code, error_msg = num_affected_rows, last_insert_id
				Debug.error( "dbPoll failed. Error code: " .. tostring( error_code ) .. "  Error message: " .. tostring( error_msg ) )
				
				return false, nil, error_code, error_msg
			else
				return true, result, num_affected_rows, last_insert_id
			end
		else
			return false
		end
	end;
};
addEventHandler( "onResourceStart", resourceRoot, DB.init )