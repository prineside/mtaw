--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Character.onCharacterSpawn", false )									-- Персонаж заспавнен ( player playerElement, number characterID )
addEvent( "Character.onCharacterDespawn", false )								-- Персонаж деспавнен - выбран другой персноаж, игрок вышел в лобби или вышел из сервера ( player playerElement, number characterID )
addEvent( "Character.onCharacterDead", false )									-- Персонаж умер - здоровье установлено в 0 ( player playerElement, number characterID )

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Character.onClientRequestCharacters", true )							-- Клиент запросил список своих персонажей ( string requestID )
addEvent( "Character.onClientRequestCharacterSpawn", true )						-- Клиент запрашивает спавн персонажа в игру ( number characterID )
addEvent( "Character.onClientRequestCharacterDespawn", true )					-- Клиент запрашивает деспавн персонажа из игры ()

--------------------------------------------------------------------------------
--<[ Модуль Character ]>--------------------------------------------------------
--------------------------------------------------------------------------------
Character = {
	-- TODO перенести в объект персонажа
	satietyReductionInterval = 6500;
	satietyReductionValue = 0.1;
	
	playTimeExperienceAddInterval = 15000; -- 15 секунд (1 игровая минута) - интервал добавления 1ед в Objective.playOneHour
	
	zeroSatietyDamage = 1.0;
	
	despawnedPlayerPos = { x = 1732.2823; y = -1930.5439; z = 13.3563; };
	
	characters = {};			-- Информация о персонажах по игрокам (playerElement => characters array)
	currentCharacters = {};		-- ID текущего персонажа (playerElement => characterID)
	currentByID = {};			-- Элемент игрока по текущему ID персонажа
	
	init = function()
		addEventHandler( "Main.onServerLoad", root, Character.onServerLoad )
	
		Main.setModuleLoaded( "Character", 1 )
	end;
	
	onServerLoad = function()
		addEventHandler( "Character.onClientRequestCharacters", resourceRoot, Character.onClientRequestCharacters )
		addEventHandler( "Character.onClientRequestCharacterSpawn", resourceRoot, Character.onClientRequestCharacterSpawn )
		addEventHandler( "Character.onClientRequestCharacterDespawn", resourceRoot, Character.onClientRequestCharacterDespawn )
		addEventHandler( "Account.onPlayerLogOut", resourceRoot, Character.onPlayerLogOut )
		
		-- Запускаем таймер обработки голода
		setTimer( Character._handleSatietyTimer, Character.satietyReductionInterval, 0 )
		
		-- Добавляем опыт за время игры
		setTimer( Character._handlePlayTimeExperience, Character.playTimeExperienceAddInterval, 0 )
	end;
	
	----------------------------------------------------------------------------
	
	-- Заспавнить персонаж (установить текущим персонажем игрока). Возвращает false, если персонаж не принадлежит этому игроку или не вошел в аккаунт
	-- > playerElement player
	-- > characterID number
	-- = bool spawnResult
	spawn = function( playerElement, characterID )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( characterID, "characterID", "number" ) then return nil end
	
		if ( not Account.isLogined( playerElement ) ) then
			-- Еще не вошел в аккаунт
			Debug.error( "Player didn't loged in into account to spwn character " .. characterID )
			return false
		end
		
		local characterData = Character.getPlayerCharacters( playerElement )[ characterID ]
		if ( characterData == nil ) then
			-- Такого персонажа нет у игрока
			Debug.error( "Player hasn't character " .. characterID )
			return false
		else
			-- Персонаж принадлежит игроку
			Debug.info( "Current character set: " .. characterID )
			Character.currentCharacters[ playerElement ] = characterID
			Character.currentByID[ characterID ] = playerElement
				
			if ( characterData.health ~= 0 ) then
				-- У игрока есть здоровье
				local dim = Dimension.get( characterData.dimension_name, characterData.dimension_id )
				
				spawnPlayer( playerElement, characterData.x, characterData.y, characterData.z, characterData.angle, characterData.skin, 0, dim )
				
				setElementHealth( playerElement, characterData.health )
				fadeCamera( playerElement, true )
				setCameraTarget( playerElement, playerElement )
				
				-- Установка данных на клиента
				triggerClientEvent( playerElement, "Character.onServerSetCurrentCharacter", resourceRoot, characterData )
				
				-- Вызов события "персонаж заспавнен"
				triggerEvent( "Character.onCharacterSpawn", resourceRoot, playerElement, characterID )
			else
				-- У игрока здоровье на 0
				Debug.info( "Character health is zero, making him dead and respawning" )
				triggerEvent( "Character.onCharacterDead", resourceRoot, playerElement, characterID )
			end
			
			return true
		end
	end;
	
	-- Убрать (деспавнить) текущего персонажа
	-- > playerElement player
	-- = void
	despawn = function( playerElement )
		if ( Character.currentCharacters[ playerElement ] ~= nil ) then
			-- Персонаж был заспавнен, убираем его
			local characterID = Character.currentCharacters[ playerElement ]
			triggerEvent( "Character.onCharacterDespawn", resourceRoot, playerElement, characterID )
			
			Character.save( playerElement )
			Character.currentByID[ characterID ] = nil
			Character.currentCharacters[ playerElement ] = nil
			Debug.info( "Curent character set to nil" )
			--[[
				Игрок никуда не перемещается (так как попадает либо в лобби, либо выходит)
			setTimer( function()
				setElementPosition( playerElement, Character.despawnedPlayerPos.x, Character.despawnedPlayerPos.y, Character.despawnedPlayerPos.z )
			end, 200, 1 )
			--]]
		
			setElementDimension( playerElement, Dimension.get( "Lobby" ) )
			setElementPosition( playerElement, Character.despawnedPlayerPos.x, Character.despawnedPlayerPos.y, Character.despawnedPlayerPos.z )
			
			-- Установка данных на клиента
			triggerClientEvent( playerElement, "Character.onServerSetCurrentCharacter", resourceRoot, nil )
		end
	end;
	
	-- Возвращает true, есл игрок выбрал персонаж (у игрока есть заспавненный персонаж)
	-- > playerElement player
	-- = bool characterIsSelected
	isSelected = function( playerElement )
		return Character.currentCharacters[ playerElement ] ~= nil
	end;
	
	-- Получить ID текущего персонажа игрока или nil, если персонаж не выбран
	-- > playerElement player
	-- = number / nil characterID
	getID = function( playerElement )
		if ( Character.isSelected( playerElement ) ) then
			return Character.currentCharacters[ playerElement ]
		else
			return nil
		end
	end;

	-- Получить playerElement по ID текущего персонажа или nil, если игрока с таким ID персонажа нет в игре
	-- > characterID number
	-- = player / nil characterOwner
	getPlayerElement = function( characterID )
		return Character.currentByID[ characterID ]
	end;
	
	-- Получить данные о текущем персонаже (например, health). Если key не указан, возвращаются все данные в виде таблицы. Если игрок не выбрал персонаж, возвращает nil
	-- > playerElement player
	-- > key string / nil - если указан nil, будет возвращена таблица со всеми данными
	-- = mixed / table/ nil characterData
	getData = function( playerElement, key )
		if ( Character.isSelected( playerElement ) ) then
			if ( key == nil ) then
				return Character.characters[ playerElement ][ Character.currentCharacters[ playerElement ] ]
			else
				return Character.characters[ playerElement ][ Character.currentCharacters[ playerElement ] ][ key ]
			end
		else
			return nil
		end
	end;
	
	-- Установить данные текущего персонажа
	-- > playerElement player
	-- > key string
	-- > value mixed
	-- = void
	setData = function( playerElement, key, value )
		if not validVar( key, "key", "string" ) then return nil end
		if not validVar( value, "value", { "string", "number" } ) then return nil end
	
		if ( Character.currentCharacters[ playerElement ] ~= nil ) then
			Character.characters[ playerElement ][ Character.currentCharacters[ playerElement ] ][ key ] = value
		else
			return nil
		end
	end;
	
	-- Сохранить текущие данные персонажа в базу
	-- > playerElement player
	-- = void
	save = function( playerElement )
		-- TODO (с флажком 'changed') - создать таблицу ключей измененных полей
		Debug.info( "Saving player character", playerElement )
		if ( Character.isSelected( playerElement ) ) then
			-- Позиция
			local x, y, z = getElementPosition( playerElement )
			Character.setData( playerElement, "x", x )
			Character.setData( playerElement, "y", y )
			Character.setData( playerElement, "z", z )
			
			local _, _, angle = getElementRotation( playerElement )
			Character.setData( playerElement, "angle", angle )
			
			-- Сохранение
			local q = "\
				UPDATE mtaw.character \
				SET \
					x = " .. x .. ", \
					y = " .. y .. ", \
					z = " .. z .. ", \
					angle = " .. angle .. ", \
					health = " .. Character.getHealth( playerElement ) .. ", \
					satiety = " .. Character.getSatiety( playerElement ) .. ", \
					skin = " .. Character.getData( playerElement, "skin" ) .. ", \
					experience = " .. Character.getData( playerElement, "experience" ) .. " \
				WHERE id = " .. Character.getData( playerElement, "id" );
				
			DB.syncQuery( q )
		else
			Debug.info( "Player didn't select a character" )
		end
	end;
	
	-- Возвращает имя персонажа, очищенное от запрещенных символов
	-- > name string - неочищенное имя
	-- = string validName
	filterCharacterName = function( name )
		local ret = ""
		for i = 1, utfLen( name ) do
			local chr = utfSub( name, i, i )
			local chrCode = utfCode( chr )
			if ( 
				( chrCode >= 1040 and chrCode <= 1103 ) -- а-Я
				or ( chrCode == 1025 or chrCode == 1105 ) -- ё Ё
				--or ( chrCode >= 65 and chrCode <= 90 ) -- A-Z
				--or ( chrCode >= 97 and chrCode <= 122 ) -- a-z
				--or chrCode == 1108 -- є
				--or chrCode == 1110 -- і
				--or chrCode == 1111 -- ї
				or chrCode == 45 -- -
				or chrCode == 32 -- пробел
			) then ret = ret .. utfChar( chrCode ) end
		end
		return ret
	end;
	
	-- Прверка валидности имени и фамилии персонажа
	-- > str string - имя или фамилия персонажа
	-- = bool isValid
	isNameValid = function( str )
		if ( utfLen( str ) < 2 or utfLen( str ) >= 24 ) then
			return false
		end
		
		return Character.filterCharacterName( str ) == str
	end;
	
	-- Создать нового персонажа. Возвращает true и ID Нового персонажа или false и текст ошибки
	-- > playerElement player - игрок, для которого будет создан персонаж
	-- > name string - имя персонажа
	-- > surname string - фамилия персонажа
	-- > gender string - пол персонажа (male/female)
	-- > skin number - ID модели скина персонажа
	-- > avatar string / nil - аватарка персонажа, по умолчанию генерируется случайная
	-- = bool isCreated, number / string characterIdOrError
	create = function( playerElement, name, surname, gender, skin, avatar )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( name, "name", "string" ) then return nil end
		if not validVar( surname, "surname", "string" ) then return nil end
		if not validVar( gender, "gender", "string" ) then return nil end
		if not validVar( skin, "number", "string" ) then return nil end
		if not validVar( avatar, "avatar", { "string", "nil" } ) then return nil end
		
		if ( Account.isLogined( playerElement ) ) then
			-- Игрок вошел в аккаунт
			local accountID = Account.getData( playerElement, "id" )
			local slotStatistic = Character.getSlotStatistic( playerElement )
			if ( slotStatistic.total > slotStatistic.used ) then
				-- Есть свободные слоты для персонажей
				-- Валидация
				if ( gender ~= "male" and gender ~= "female" ) then
					-- Неверно указан пол
					return false, "Неверно указан пол"
				end
				
				if ( not Character.isNameValid( name ) ) then
					return false, "Неверный формат имени"
				end
				
				if ( not Character.isNameValid( surname ) ) then
					return false, "Неверный формат фамилии"
				end
				
				if ( ARR.characterCreatorSkins[ gender ][ tostring( skin ) ] == nil ) then
					return false, "Невозможно выбрать скин " .. skin
				end
				
				if ( avatar == nil ) then
					-- Генерация алиаса аватарки
					avatar = Avatar.generateAvatarAlias()
				end
				
				-- Запись в базу нового персонажа и обновления списка персонажей на клиенте
				local spawnAlias = Spawn.getNearestSpawnAlias( 0, 0, 0 )
				local spawnData = Spawn.getSpawnInfo( spawnAlias )
				local angle = 0
				
				local q = "\
					INSERT INTO mtaw.character ( account, x, y, z, angle, name, surname, gender, created, avatar, skin ) VALUES (\
						" .. accountID .. ",\
						" .. spawnData.x .. ",\
						" .. spawnData.y .. ",\
						" .. spawnData.z .. ",\
						" .. angle .. ",\
						'" .. sql_escape_string( name ) .. "',\
						'" .. sql_escape_string( surname ) .. "',\
						'" .. sql_escape_string( gender ) .. "',\
						" .. Time.getServerTimestamp() .. ",\
						'" .. sql_escape_string( avatar ) .. "',\
						" .. skin .. "\
					)\
				"
					
				local isSuccess, result, num_affected_rows, last_insert_id = DB.syncQuery( q )
				
				if ( not isSuccess ) then return nil end
				
				Debug.info( tostring( result ) .. " " .. tostring( num_affected_rows ) .. " " .. tostring( last_insert_id ) )
				
				if ( result ) then
					local isSuccess, newCharacterResult = DB.syncQuery( "SELECT * FROM mtaw.character WHERE id = " .. last_insert_id )
				
					if ( not isSuccess ) then return nil end
				
					for k, v in pairs( newCharacterResult ) do
						local data = {}
						for kk, vv in pairs( v ) do
							data[ kk ] = vv
						end
						Character.characters[ playerElement ][ data.id ] = data
					end
					
					return true, last_insert_id
				else
					return false, "Ошибка при создании записи в базе данных"
				end
			else
				return false, "Нет свободных слотов для создания персонажа"
			end
		else
			return false, "Необходимо войти в аккаунт"
		end
	end;
	
	setPosition = function( playerElement, x, y, z )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( x, "x", "number" ) then return nil end
		if not validVar( y, "y", "number" ) then return nil end
		if not validVar( z, "z", "number" ) then return nil end
		
		local characterID = Character.currentCharacters[ playerElement ]
		if ( characterID ~= nil ) then
			Character.characters[ playerElement ][ characterID ].x = x
			Character.characters[ playerElement ][ characterID ].y = y
			Character.characters[ playerElement ][ characterID ].z = z
			
			setElementPosition( playerElement, x, y, z )
		else
			Debug.error( "Character is not selected" )
		end
	end;
	
	setDimension = function( playerElement, dimensionName, dimensionID )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( dimensionName, "dimensionName", "string" ) then return nil end
		if not validVar( dimensionID, "dimensionID", { "number", "nil" } ) then return nil end
		
		local characterID = Character.currentCharacters[ playerElement ]
		
		if ( characterID ~= nil ) then
			if ( dimensionID == nil ) then dimensionID = 0 end	-- Номер измерения не указан - значит, он не имеет значения
			
			Character.setData( playerElement, "dimension_name", dimensionName )
			Character.setData( playerElement, "dimension_id", dimensionID )
			
			setElementDimension( playerElement, Dimension.get( dimensionName, dimensionID ) )
		else
			Debug.error( "Character is not selected" )
		end
	end;
	
	-- Возвращает текущую сытость персонажа (0-100) или nil, если персонаж не выбран
	-- > playerElement player
	-- = number / nil characterSatiety
	getSatiety = function( playerElement )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		
		if ( Character.currentCharacters[ playerElement ] ~= nil ) then
			return Character.getData( playerElement, "satiety" )
		else
			return nil
		end
	end;
	
	-- Установить сытость персонажа (0-100). Возвращает false, если персонаж не выбран
	-- Если указана сытость <0, установит 0. Если больше 100, установит 100
	-- > playerElement player
	-- > satiety number
	-- = bool isSet
	setSatiety = function( playerElement, satiety )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( satiety, "satiety", "number" ) then return nil end
		
		if ( Character.currentCharacters[ playerElement ] ~= nil ) then
			if ( satiety < 0 ) then
				satiety = 0
			elseif ( satiety > 100 ) then
				satiety = 100
			end
			
			if ( Character.getData( playerElement, "satiety" ) ~= satiety ) then
				Character.setData( playerElement, "satiety", satiety )
				
				Character.updateClientData( playerElement, { 
					["satiety"] = satiety; 
				} )
			end
			
			return true
		else
			Debug.info( "Character is not selected!" )
			return false
		end
	end;
	
	-- Возвращает текущее здоровье персонажа (0-100) или nil, если персонаж не выбран
	-- > playerElement player
	-- = number characterHealth
	getHealth = function( playerElement )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		
		if ( Character.currentCharacters[ playerElement ] ~= nil ) then
			return Character.getData( playerElement, "health" )
		else
			return nil
		end
	end;
	
	-- Установить текущее здоровье персонажа (0-100), возвращает false, если персонаж не выбран
	-- > playerElement player
	-- > health number
	-- = bool isSet
	setHealth = function( playerElement, health )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( health, "health", "number" ) then return nil end
		
		if ( Character.currentCharacters[ playerElement ] ~= nil ) then
			if ( health < 0 ) then
				health = 0
			elseif ( health > 100 ) then
				health = 100
			end
			
			if ( Character.getData( playerElement, "health" ) ~= health ) then
				Character.setData( playerElement, "health", health )
				
				if ( health == 0 ) then
					-- Умер
					triggerEvent( "Character.onCharacterDead", resourceRoot, playerElement, Character.getData( playerElement, "id" ) )
				else
					-- Еще не умер
					Character.updateClientData( playerElement, { 
						["health"] = health; 
					} )
				end
			end
			
			return true
		else
			Debug.info( "Character is not selected!" )
			return false
		end
	end;
	
	-- Возвращает текущую сумму наличных денег персонажа (>=0) или nil, если персонаж не выбран
	-- > playerElement player
	-- = number / nil characterMoney
	getMoney = function( playerElement )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		
		if ( Character.currentCharacters[ playerElement ] ~= nil ) then
			return Character.getData( playerElement, "money" )
		else
			return nil
		end
	end;
	
	-- Установить текущую сумму наличных персонажу (>=0), возвращает false, если персонаж не выбран
	-- > playerElement player
	-- > money naumber
	-- = bool isSet
	setMoney = function( playerElement, money )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( money, "money", "number" ) then return nil end
		
		if ( Character.currentCharacters[ playerElement ] ~= nil ) then
			Character.setData( playerElement, "money", money )
			Character.updateClientData( playerElement, { 
				["money"] = money; 
			} )
			return true
		else
			Debug.info( "Character is not selected!" )
			return false
		end
	end;
	
	-- Возвращает суммарный опыт персонажа (>=0) или nil, если персонаж не выбран
	-- > playerElement player
	-- = number experience / nil
	getExperience = function( playerElement )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		
		if ( Character.currentCharacters[ playerElement ] ~= nil ) then
			return Character.getData( playerElement, "experience" )
		else
			return nil
		end
	end;
	
	-- Установить суммарный опыт персонажа (>=0), возвращает nil, если персонаж не выбран
	-- > playerElement player
	-- > experience number
	-- = bool isSet
	setExperience = function( playerElement, experience )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( experience, "experience", "number" ) then return nil end
		
		if ( Character.currentCharacters[ playerElement ] ~= nil ) then
			Character.setData( playerElement, "experience", experience )
			Character.updateClientData( playerElement, { 
				["experience"] = experience; 
			} )
			return true
		else
			Debug.info( "Character is not selected!" )
			return false
		end
	end;
	
	-- Добавить к суммарному опыту персонажа (>0)
	-- > playerElement player
	-- > addedExperience number
	-- = void
	addExperience = function( playerElement, addedExperience )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( addedExperience, "addedExperience", "number" ) then return nil end
		
		if ( addedExperience < 1 ) then
			Debug.error( "Invalid experience amount: " .. addedExperience )
			return nil
		end
		
		Character.setExperience( playerElement, Character.getData( playerElement, "experience" ) + addedExperience )
	end;
	
	-- Обновить данные о персонаже на стороне клиента - отправляет все данные на клиент
	-- > playerElement player
	-- > newData table - таблица с данными персонажа, которые нужно установить на клиенте
	-- = void
	updateClientData = function( playerElement, newData )
		if not validVar( newData, "newData", "table" ) then return nil end
		
		triggerClientEvent( playerElement, "Character.onServerUpdateCharacterData", resourceRoot, newData )
	end;
	
	-- Возвращает таблицу всех персонажей игрока или nil, если не вошел в аккаунт
	-- > playerElement player
	-- = table / nil playerCharacters
	getPlayerCharacters = function( playerElement )
		if ( Account.isLogined( playerElement ) ) then
			if ( Character.characters[ playerElement ] == nil ) then
				local isSuccess, result = DB.syncQuery( "SELECT * FROM mtaw.character WHERE account = " .. Account.getAccountID( playerElement ) )
				
				if ( not isSuccess ) then return nil end
				
				Character.characters[ playerElement ] = {}
				for k, v in pairs( result ) do
					local data = {}
					for kk, vv in pairs( v ) do
						data[ kk ] = vv
					end
					Character.characters[ playerElement ][ data.id ] = data
				end
			end
			
			return Character.characters[ playerElement ]
		else
			return nil
		end
	end;
	
	-- Возвращает количество занятых и всего слотов под персонажи игрока или nil, если не вошел в аккаунт
	-- > playerElement player
	-- = table / nil slotStatistic
	getSlotStatistic = function( playerElement )
		if ( Account.isLogined( playerElement ) ) then
			local playerCharacters = Character.getPlayerCharacters( playerElement )
			
			local totalExp = 0
			local usedSlots = 0
			for characterID, characterData in pairs( playerCharacters ) do
				totalExp = totalExp + characterData.experience
				usedSlots = usedSlots + 1
			end
			
			local availableSlots = 0
			local nextSlotExp = 0
			local prevSlotExp = 0
			for k, v in pairs( ARR.characterSlotsByTotalExp ) do
				if ( totalExp >= v[ 1 ] ) then
					availableSlots = v[ 2 ]
				else
					if ( k ~= 0 ) then
						prevSlotExp = ARR.characterSlotsByTotalExp[ k - 1 ][ 1 ]
					end
					
					nextSlotExp = v[ 1 ]
					break
				end
			end
			
			return {
				total = availableSlots;
				used = usedSlots;
				totalExp = totalExp;
				prevSlotExp = prevSlotExp;
				nextSlotExp = nextSlotExp;
			}
		else
			return nil
		end
	end;
	
	-- Получить информацию о текущем уровне и оставшемся опыте для перехода на следующий уровень
	-- > totalExperience number
	-- = table levelInfo
	getLevelInfo = function( totalExperience )
		if not validVar( totalExperience, "experience", "number" ) then return nil end
		
		local level, levelExp, nextLevelExp
		local expSum = 0
		for k, v in pairs( ARR.expByLevel ) do
			level = k
			
			if ( expSum + v > totalExperience ) then
				levelExp = totalExperience - expSum
				nextLevelExp = v
				break
			end
			expSum = expSum + v
		end
		
		local ret = {}
		
		ret.level = level
		ret.levelExp = levelExp
		ret.nextLevelExp = nextLevelExp
		
		return ret
	end;
	
	-- Обработка уменьшения сытости
	_handleSatietyTimer = function()
		local players = getElementsByType( "player" )
		for _, playerElement in pairs( players ) do
			if ( Character.isSelected( playerElement ) ) then
				Character.setSatiety( playerElement, Character.getData( playerElement, "satiety" ) - Character.satietyReductionValue )
				
				if ( Character.getData( playerElement, "satiety" ) == 0 ) then
					-- Сытость на нуле
					Character.setHealth( playerElement, Character.getHealth( playerElement ) - Character.zeroSatietyDamage )
				end
			end
		end
	end;
	
	-- Добавление 1 очка в Objective.playOneHour всем заспавненным персонажам
	_handlePlayTimeExperience = function()
		local players = getElementsByType( "player" )
		for _, playerElement in pairs( players ) do
			if ( Character.isSelected( playerElement ) ) then
				Objective.progress( Character.getID( playerElement ), "playOneHour" )
			end
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------

	-- Клиент запросил список своих персонажей
	onClientRequestCharacters = function( requestID )
		local characterList = Character.getPlayerCharacters( client )
		triggerClientEvent( client, "Character.onServerSentCharacters", resourceRoot, characterList, requestID )
	end;
	
	-- Клиент запросил спавн персонажа
	onClientRequestCharacterSpawn = function( characterID )
		Character.spawn( client, characterID )
	end;
	
	-- Клиент запросил деспавн персонажа
	onClientRequestCharacterDespawn = function()
		Character.despawn( client )
	end;
	
	-- Клиент вышел из аккаунта
	onPlayerLogOut = function( playerElement )
		-- Так как персонажи не могут существовать без аккаунтов, деспавним персонаж
		if ( Character.isSelected( playerElement ) ) then
			-- Перенести в Character
			Character.despawn( playerElement )
		end
	end;
};
addEventHandler( "onResourceStart", resourceRoot, Character.init )