--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Account.onPlayerLogIn", false )										-- Игрок вошел в аккаунт ( player playerElement, number accountID )
addEvent( "Account.onPlayerLogOut", false )										-- Игрок вышел из аккаунта ( player playerElement, number accountID )

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Account.onClientLogInAttempt", true )								-- Попытка войти на сервер ( string login, string password )
addEvent( "Account.onClientLogOutAttempt", true )								-- Попытка выйти из сервера ()

--------------------------------------------------------------------------------
--<[ Модуль Account ]>----------------------------------------------------------
--------------------------------------------------------------------------------
Account = {
	idInstances = {};				-- ID аккаунта => данные аккаунта (+idInstances[id].playerElement)
	accountPermissions = {};		-- ID аккаунта => права 
	accountPermissionsKeys = {};	-- ID аккаунта => таблица с ключами прав
	
	idByPlayerElement = {};			-- playerElement => ID аккаунта
	
	init = function()
		addEventHandler( "Main.onServerLoad", root, Account.onServerLoad )
		
		addEventHandler( "onPlayerJoin", root, Account.onPlayerJoin )
		addEventHandler( "onPlayerQuit", root, Account.onPlayerQuit )
		addEventHandler( "Main.onClientLoad", root, Account.onClientLoad )
		
		addEventHandler( "Account.onClientLogInAttempt", root, Account.onClientLogInAttempt )
		addEventHandler( "Account.onClientLogOutAttempt", root, Account.onClientLogOutAttempt )
		
		Main.setModuleLoaded( "Account", 1 )
	end;
	
	onServerLoad = function()
		
	end;
	
	----------------------------------------------------------------------------
	
	-- Возвращает true, если игрок вошел в аккаунт
	-- > playerElement player
	-- = bool isLogined
	isLogined = function( playerElement )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		
		return ( Account.idByPlayerElement[ playerElement ] ~= nil )
	end;
	
	-- Есть ли игрок с таким ID аккаунта на сервере
	-- > accountID number
	-- = bool accountIdLogined
	isAccountIdLogined = function( accountID )
		return Account.idInstances[ accountID ] ~= nil
	end;
	
	-- Установить аккаунт игроку (авторизация игрока). Возвращает false, если аккаунт не существует
	-- > playerElement player
	-- > accountID number - ID аккаунта сети Prineside
	-- = bool loginResult
	setLoggedIn = function( playerElement, accountID )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( accountID, "accountID", "number" ) then return nil end
		
		if ( Account.isLogined( playerElement ) ) then
			Account.destroyAuthData( playerElement, true )
		end
		
		local accountData = Account.getDataFromDB( accountID )
		if ( accountData ~= nil ) then
			if ( Account.idInstances[ accountData.id ] ~= nil ) then
				Debug.error( "Account " .. accountID .. " already logged in" )
			
				return false
			end
			
			setPlayerName( playerElement, accountData.login )
		
			local accountPermissions = Account.getPermissionsFromDB( accountID )
		
			accountData.playerElement = playerElement
			Account.idByPlayerElement[ playerElement ] = accountData.id
			Account.idInstances[ accountData.id ] = accountData
			Account.accountPermissions[ accountData.id ] = accountPermissions
			Account.accountPermissionsKeys[ accountData.id ] = {}
			
			for k, v in pairs( accountPermissions ) do
				Account.accountPermissionsKeys[ accountData.id ][ v ] = true
			end
			
			triggerEvent( "Account.onPlayerLogIn", resourceRoot, playerElement, accountID )
			Account.updateClientData( playerElement )
			
			-- Сохранение сессии
			DB.syncQuery( "DELETE FROM mtaw.session WHERE ip = '" .. getPlayerIP( playerElement ) .. "' AND serial = '" .. getPlayerSerial( playerElement ) .. "';" )
			DB.syncQuery( "INSERT INTO mtaw.session (account, login, ip, serial, date) VALUES (" .. accountID .. ", '" .. DB.escapeString( accountData.login ) .. "', '" .. getPlayerIP( playerElement ) .. "', '" .. getPlayerSerial( playerElement ) .. "', " .. Time.getServerTimestamp() .. ");" )
			
			return true
		else
			Debug.error( "Account " .. accountID .. " not exists" )
			
			return false
		end
	end;
	
	-- Имеет ли игрок право (если не вошел, не имеет ни одного). Возвращает true, если игрок вошел в аккаунт и аккаунт имеет указанное право
	-- > playerElement player
	-- > perm string - алиас права из таблицы permission
	-- = bool hasPermission
	hasPermission = function( playerElement, perm )
		if ( Account.isLogined( playerElement ) ) then
			if ( perm == "none" ) then
				return true
			else
				return Account.accountPermissionsKeys[ Account.idByPlayerElement[ playerElement ] ][ perm ] ~= nil
			end
		else
			return false
		end
	end;
	
	-- Получить данные аккаунта игрока. Если key не указан, возвращает таблицу со всеми данными. Если игрок не вошел или таких данных нет, возвращает nil
	-- > playerElement player
	-- > key string / nil - название данных (например, login). Если не указано, возвращает таблицу со всеми данными
	-- = string / table / nil accountData
	getData = function( playerElement, key )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( key, "key", { "string", "nil" } ) then return nil end
		
		if ( not Account.isLogined( playerElement ) ) then
			return nil
		else
			if ( key == nil ) then
				return Account.idInstances[ Account.idByPlayerElement[ playerElement ] ]
			else
				return Account.idInstances[ Account.idByPlayerElement[ playerElement ] ][ key ]
			end
		end
	end;
	
	-- Получить все данные аккаунта по ID из базы или nil, если такого аккаунта нет
	-- > accountID number
	-- = table / nil accountData
	getDataFromDB = function( accountID )
		if not validVar( accountID, "accountID", "number" ) then return nil end
		
		local isSuccess, result = DB.syncQuery( "SELECT * FROM mtaw.accounts WHERE id = " .. tonumber( accountID ) )
		
		if ( not isSuccess ) then return nil end
		
		if ( result[1] ~= nil ) then
			local data = {}
			for k, v in pairs( result[1] ) do
				data[ k ] = v
			end
		
			return data
		else
			return nil
		end
	end;
	
	-- Получить права аккаунта по ID из базы
	-- > accountID number
	-- = table accountPermissions
	getPermissionsFromDB = function( accountID )
		if not validVar( accountID, "accountID", "number" ) then return nil end
		
		local isSuccess, result = DB.syncQuery( "SELECT permission FROM mtaw.account_permission WHERE account = " .. accountID )
		
		if ( not isSuccess ) then return nil end
		
		if ( result[1] ~= nil ) then
			local data = {}
			
			for k, v in pairs( result ) do
				table.insert( data, v.permission )
			end
		
			return data
		else
			return {}
		end
	end;
	
	-- Удалить данные об аутентификации и сделать игрока гостем
	-- > playerElement player
	-- > destroySession bool / nil - удалить сессию (игрок не войдет автоматически при входе), по умолчанию false
	-- = void
	destroyAuthData = function( playerElement, destroySession )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		
		if ( destroySession == nil ) then destroySession = false end
		
		if ( Account.isLogined( playerElement ) ) then
			local accountID = Account.idByPlayerElement[ playerElement ]
			Account.idInstances[ accountID ] = nil
			Account.idByPlayerElement[ playerElement ] = nil
			triggerEvent( "Account.onPlayerLogOut", resourceRoot, playerElement, accountID )
			
			if ( destroySession ) then
				Account.removeLoginSession( playerElement )
			end
			
			Account.updateClientData( playerElement )
			
			setPlayerName( playerElement, "Mystery-ID-" .. tostring( Playerid.getID( playerElement ) ) )
		
			Account.unload( playerElement )	-- Сохраняем и выгружаем из памяти
		end
	end;
	
	-- Выгрузить данные об аккаунте и освободить память. Возвращает false, если игрок не входил в аккаунт
	-- Ничего не сохраняется в базу!
	-- > playerElement player
	-- = bool isUnloaded
	unload = function( playerElement )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		
		if ( Account.isLogined( playerElement ) ) then
			-- Вошел в аккаунт
			Account.idInstances[ Account.idByPlayerElement[ playerElement ] ] = nil
			Account.accountPermissions[ Account.idByPlayerElement[ playerElement ] ] = nil
			Account.accountPermissionsKeys[ Account.idByPlayerElement[ playerElement ] ] = nil
			Account.idByPlayerElement[ playerElement ] = nil
			
			return true
		else
			return false
		end
	end;
	
	-- Получить ID аккаунта игрока или nil
	-- > playerElement player
	-- = number / nil accountID
	getAccountID = function( playerElement )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		
		if ( Account.isLogined( playerElement ) ) then
			return Account.idByPlayerElement[ playerElement ]
		else
			return nil
		end
	end;
	
	-- Получить права аккаунта (таблица)
	-- > playerElement player
	-- = table / nil accountPermissions
	getPermissions = function( playerElement )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		
		if ( Account.isLogined ) then
			return Account.accountPermissions[ Account.idByPlayerElement[ playerElement ] ]
		else
			return nil
		end
	end;
	
	-- Обновить все данные об аккаунте на клиенте (данные аккаунта и права)
	-- > playerElement player
	-- = void
	updateClientData = function( playerElement )
		triggerClientEvent( playerElement, "Account.onServerUpdateData", resourceRoot, Account.getData( playerElement ), Account.getPermissions( playerElement ) )
	end;
	
	-- Проверка логина и пароля на правильность. Возвращает false и ошибку или true и ID аккаунта
	-- > login string
	-- > password string
	-- = bool isValid, string / number accountIdOrError
	isValidCredentials = function( login, password )
		local isSuccess, result = DB.syncQuery( "SELECT id, hash, blowfish FROM mtaw.accounts WHERE login LIKE '" .. DB.escapeString( login ) .. "'" )
		
		if ( not isSuccess ) then return nil end
		
		if ( result[1] ~= nil ) then
			local hash = md5( string.lower( md5( password ) ) .. result[1].blowfish )
			Debug.info( hash .. " " .. result[1].hash )
			if ( string.upper( result[1].hash ) ==  hash ) then
				return true, result[1].id
			else
				return false, "Неправильный пароль"
			end
		else
			return false, "Аккаунт не найден"
		end
	end;
	
	-- Получить сессию входа (по IP и серийному номеру)
	-- > playerElement player
	-- = table / nil sessionData
	getLoginSession = function( playerElement )
		local isSuccess, result = DB.syncQuery( "SELECT * FROM mtaw.session WHERE ip = '" .. getPlayerIP( playerElement ) .. "' AND serial = '" .. getPlayerSerial( playerElement ) .. "';" )
		
		if ( not isSuccess ) then return nil end
		
		if ( result[1] ~= nil ) then
			local data = {}
			for k, v in pairs( result[1] ) do
				data[ k ] = v
			end
		
			return data
		else
			return nil
		end
	end;
	
	-- Удалить сессию входа
	-- > playerElement player
	-- = void
	removeLoginSession = function( playerElement )
		DB.syncQuery( "DELETE FROM mtaw.session WHERE ip = '" .. getPlayerIP( playerElement ) .. "' AND serial = '" .. getPlayerSerial( playerElement ) .. "';" )
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Игрок вошел на сервер
	onPlayerJoin = function()
		-- Убираем никнейм
		setPlayerName( source, "Mystery-ID-" .. Playerid.getID( source ) )
		
		-- Скрываем неймтег
		setPlayerNametagShowing( source, false )
	end;
	
	-- Игрок вышел из сервера
	onPlayerQuit = function()
		-- Удаляем данные аккаунта, но не удаляем сессию
		Account.destroyAuthData( source, false )
	end;
	
	-- Клиент загрузился
	onClientLoad = function( loadedClient )
		-- Проверяем сессию входа. Продолжаем ее или показываем форму входа (за это отвечает клиент)
		local loginSession = Account.getLoginSession( loadedClient )
		if ( loginSession ~= nil ) then
			-- Есть сессия, возможно, будет автоматический вход
			if ( not Account.isAccountIdLogined( loginSession.account ) ) then
				-- Автоматический вход
				Popup.show( loadedClient, "Вы автоматически вошли в аккаунт " .. loginSession.login, "success" )
				Account.setLoggedIn( loadedClient, loginSession.account )
			else
				-- Игрок с таким логином уже вошел на сервер, вход отменен
				Popup.show( loadedClient, "Игрок с логином " .. loginSession.login .. " уже вошел на сервер, автоматический вход отменен", "warning" )
			end
		end
	end;
	
	-- Игрок client сделал попытку войти в аккаунт
	onClientLogInAttempt = function( login, password )
		Debug.info( "Client " .. tostring( login ) .. " made attempt to log in with password " .. password )
		
		if ( not Account.isLogined( client ) ) then
			local isValid, accountIDorError = Account.isValidCredentials( login, password )
			if ( isValid ) then
				local accountID = accountIDorError
				local accountData = Account.getDataFromDB( accountID )
				if ( accountData.tester == 1 ) then
					if ( not Account.isAccountIdLogined( accountID ) ) then
						Popup.show( client, "Вы вошли в аккаунт " .. login, "success" )
						Account.setLoggedIn( client, accountID )
					else
						Popup.show( client, "Игрок с таким логином уже играет на сервере", "error" )
					end
				else
					Popup.show( client, "У вас нет доступа на ЗБТ", "error" )
				end
			else
				Popup.show( client, accountIDorError, "error" )
			end
		else
			Popup.show( client, "Вы уже вошли в аккаунт", "error" )
		end
	end;
	
	-- Игрок client сделал попытку выйти из аккаунта
	onClientLogOutAttempt = function()
		if ( Account.isLogined( client ) ) then
			Account.destroyAuthData( client, true )
			Popup.show( client, "Вы вышли из сервера", "success" )
		else
			Popup.show( client, "Вы еще не вошли в аккаунт", "error" )
		end
	end;
};
addEventHandler( "onResourceStart", resourceRoot, Account.init )