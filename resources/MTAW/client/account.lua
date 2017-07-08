--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Account.onPlayerLogIn", false )										-- Игрок вошел в аккаунт (table accountData) 								
addEvent( "Account.onPlayerLogOut", false )										-- Игрок вышел из аккаунта (table loggedOutAccountData) 													
addEvent( "Account.onServerUpdateData", true ) 									-- Сервер обновил информацию о нашем клиенте - например, при входе или выходе (table/nil newData, table/nil newPermissions) 	 

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--<[ Модуль Account ]>----------------------------------------------------------
--------------------------------------------------------------------------------
Account = {
	data = nil;
	accountPermissions = nil;
	accountPermissionsKeys = nil;
	
	init = function()
		addEventHandler( "Main.onClientLoad", root, Account.onClientLoad )
		
		addEventHandler( "Account.onServerUpdateData", root, Account.onServerUpdateData )
		
		Main.setModuleLoaded( "Account", 1 )
	end;
	
	onClientLoad = function()
		LoginForm.show()
	end;
	
	----------------------------------------------------------------------------
	
	-- Отправить на сервер попытку входа
	-- > login string - логин аккаунта сети Prineside
	-- > password string - пароль от аккаунта в чистом виде
	-- = void
	sendLoginAttempt = function( login, password )
		if ( not Account.isLogined() ) then
			triggerServerEvent( "Account.onClientLogInAttempt", resourceRoot, login, password )
		end
	end;

	-- Вошел ли локальный игрок в аккаунт
	-- = bool isLogined
	isLogined = function()
		return ( Account.data ~= nil )
	end;
	
	-- Есть ли у игрока право perm
	-- Если права нет или игрок не вошел в аккаунт, возвращает false
	-- > perm string - алиас права (из таблицы mtaw.permission)
	-- = bool hasPermission
	hasPermission = function( perm )
		if ( Account.isLogined() ) then
			if ( perm == "none" ) then
				return true
			else
				return Account.accountPermissionsKeys[ perm ] ~= nil
			end
		else
			return false
		end
	end;
	
	-- Выйти из текущего аккаунта
	-- = void
	logOut = function()
		if ( Account.isLogined() ) then
			triggerServerEvent( "Account.onClientLogOutAttempt", resourceRoot )
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Сервер отправил новые данные об аккаунте
	onServerUpdateData = function( newData, newPermissions )
		local oldData = Account.data
		Account.data = newData
		Account.accountPermissions = newPermissions
		Account.accountPermissionsKeys = {}
		
		if ( newData == nil ) then
			triggerEvent( "Account.onPlayerLogOut", root, oldData )
		else
			for k, v in pairs( newPermissions ) do
				Account.accountPermissionsKeys[ v ] = true
			end
			triggerEvent( "Account.onPlayerLogIn", root, newData )
		end
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Account.init )