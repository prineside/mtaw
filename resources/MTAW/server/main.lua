--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Main.onClientLoad", true )											-- Клиент загрузил все свои ресурсы и может взаимодействовать с ними любым образом ()
addEvent( "Main.onServerLoad", false )											-- Сервер загрузил все свои ресурсы и может взаимодействовать с ними любым образом ()

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Main.onClientRequestReconnect", true )								-- 

--------------------------------------------------------------------------------
--<[ Модуль Main ]>-------------------------------------------------------------
--------------------------------------------------------------------------------
Main = {
	-- Список модулей, которые должны сообщить Main о своей инициализации, чтобы запустить все
	moduleLoadingStatus = { 
		Account = 0; Avatar = 0; Chunk = 0; DB = 0; Debug = 0; Dimension = 0; Lobby = 0; Model = 0; VehicleVinyl = 0;
	};
	moduleLoadingTimer = nil;
	
	loadedPlayerKeys = {}; 	-- Загруженные игроки (ключ - элемент игрока)
	loadedPlayers = {};		-- Загруженные игроки (индексированный массив)

	-- Точка входа в программу. Это единственное, что само по себе загружается, остальное обрабатывает события
	-- Ждет загрузки всех необходимых модулей, затем вызывает Main.onServerLoad
	init = function()
		addEventHandler( "Main.onServerLoad", root, Main.onServerLoad )
		
		-- Загрузка остальных модулей
		local modulesLoadingTargetCoeff = tableRealSize( Main.moduleLoadingStatus )
		local modulesLoadingStartTime = getTickCount()
		Main.moduleLoadingTimer = setTimer( function()
			if ( getTickCount() - modulesLoadingStartTime < 10000 ) then
				-- Прошло меньше 15 секунд с начала загрузки
				local totalCoeff = 0
				for moduleName, loadingCoeff in pairs( Main.moduleLoadingStatus ) do
					totalCoeff = totalCoeff + loadingCoeff
				end
				
				if ( totalCoeff == modulesLoadingTargetCoeff ) then
					-- Все модули загружены
					Debug.info( "All modules loaded" )
					killTimer( Main.moduleLoadingTimer )
					triggerEvent( "Main.onServerLoad", root )
				end
			else
				-- Прошло больше n секунд, сообщаем об ошибке
				for moduleName, loadingCoeff in pairs( Main.moduleLoadingStatus ) do
					if ( loadingCoeff < 1 ) then
						Debug.critical( "Module " .. moduleName .. " was loaded to " .. ( loadingCoeff * 100 ) .. "%" )		
					end
				end
				killTimer( Main.moduleLoadingTimer )
			end
		end, 50, 0 )
	end;
	
	-- Модули по мере своей загрузки должны сообщать о своей загрузке
	-- Эта функция должна вызываться после инициализации каждого модуля
	-- > moduleName string - название модуля, который загружается
	-- > coeff number / nil - коэффициент от 0 до 1 загрузки модуля (по умолчанию 1)
	-- = void
	setModuleLoaded = function( moduleName, coeff )
		coeff = ( coeff == nil ) and 1 or coeff
		
		if ( Main.moduleLoadingStatus[ moduleName ] ~= nil ) then
			Main.moduleLoadingStatus[ moduleName ] = coeff
		end
	end;
	
	-- Возвращает элементы игроков, которые полностью загрузили мод (Main.onClientLoad)
	-- = table loadedPlayerElements
	getLoadedPlayers = function()
		return Main.loadedPlayers
	end;
	
	reconnectPlayer = function( playerElement )
		redirectPlayer( playerElement, "", 0 )
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Сервер загрузил все модули
	onServerLoad = function()
		addEventHandler( "onResourceStop", resourceRoot, Main.onResourceStop )

		addEventHandler( "Main.onClientRequestReconnect", resourceRoot, Main.onClientRequestReconnect )
		
		addEventHandler( "Character.onCharacterDead", resourceRoot, Main.onCharacterDead )
		addEventHandler( "Objective.onCharacterCompletedObjective", resourceRoot, Main.onCharacterCompletedObjective )
		
		addEventHandler( "Main.onClientLoad", root, Main.onClientLoad )
		addEventHandler( "onPlayerQuit", root, Main.onPlayerQuit )
		
		-- Основная конфигурация
		if ( DEBUG_MODE ) then
			setFPSLimit( 90 )
		else
			setFPSLimit( 90 )
		end
		
		Dimension.register( "Global" )
	end;
	
	-- Игрок загрузился
	onClientLoad = function()
		local key = #Main.loadedPlayers + 1
		Main.loadedPlayerKeys[ client ] = key
		Main.loadedPlayers[ key ] = client
	end;
	
	-- Игрок вышел
	onPlayerQuit = function()
		table.remove( Main.loadedPlayers, Main.loadedPlayerKeys[ source ] )
		Main.loadedPlayerKeys[ source ] = nil
	end;
	
	-- Мод был остановлен
	onResourceStop = function()
		-- Сохраняем игроков
		local players = getElementsByType( "player" )
		for k, playerElement in pairs( players ) do
			-- Сохраняем его персонажей в базу, очищаем память 
			if ( Character.isSelected( playerElement ) ) then
				Character.despawn( playerElement )
			end
		
			Account.unload( playerElement )
		end
	end;
	
	-- Игрок умер (скриптовый, тот самый, который надо использовать)
	-- TODO придумать, что с этим делать. 
	onCharacterDead = function( playerElement, characterID )
		Debug.info( "Dead" )
		
		-- Пока что на спавне ближайшем
		local px, py, pz = getElementPosition( playerElement )
		local spawnAlias = Spawn.getNearestSpawnAlias( px, py, pz )
		local spawnInfo = Spawn.getSpawnInfo( spawnAlias )
		local characterID = Character.getData( playerElement, "id" )
		
		Character.setSatiety( playerElement, 100 )
		Character.setHealth( playerElement, 100 )
		Character.setDimension( playerElement, "Global" )
		Character.setPosition( playerElement, spawnInfo.x, spawnInfo.y, spawnInfo.z )
		
		--Character.spawn( playerElement, characterID )
	end;
	
	-- Игрок выполнил задание и получил опыт
	onCharacterCompletedObjective = function( characterID, objectiveAlias )
		Debug.info( "Character " .. characterID .. " completed an objective " .. objectiveAlias )
	end;
	
	-- Игрок запросил переподключение к серверу
	onClientRequestReconnect = function()
		Main.reconnectPlayer( client )
	end;
};
addEventHandler( "onResourceStart", resourceRoot, Main.init )