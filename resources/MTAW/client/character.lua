--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Character.onCharacterChange", false )		-- Изменился персонаж игрока ()
addEvent( "Character.onDataChange", false )				-- Изменились данные персонажа. Таблица newData имеет вид key => value со всеми полями, которые были изменены ( table newData )

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Character.onServerSetCurrentCharacter", true )	-- Установлен новый текущий персонаж ( table / nil characterData )
addEvent( "Character.onServerSentCharacters", true )	-- Сервер отправил список персонажей по запросу getCharacters ( table / nil accountCharacters )
addEvent( "Character.onServerUpdateCharacterData", true )	-- Пришли новые данные о текущем персонаже, newData имеет вид key => value. Внутреннее событие перед вызовом общего Character.onDataChange ( table newData )

--------------------------------------------------------------------------------
--<[ Модуль Character ]>--------------------------------------------------------
--------------------------------------------------------------------------------
Character = {
	data = nil;	-- Данные текущего персонажа или nil
	
	characterListRequests = {};
	
	init = function()
		addEventHandler( "Main.onClientLoad", root, Character.onClientLoad )
	
		Main.setModuleLoaded( "Character", 1 )
	end;
	
	onClientLoad = function()
		addEventHandler( "Character.onServerSentCharacters", resourceRoot, Character.onServerSentCharacters )
		addEventHandler( "Character.onServerSetCurrentCharacter", resourceRoot, Character.onServerSetCurrentCharacter )
		addEventHandler( "Character.onServerUpdateCharacterData", resourceRoot, Character.onServerUpdateCharacterData )
		
		-- При стриме игроков добавляем взаимодействие с ними
		addEventHandler( "onClientElementStreamIn", root, Character.onElementStreamIn )
		addEventHandler( "onClientElementStreamOut", root, Character.onElementStreamOut )
	end;
	
	----------------------------------------------------------------------------
	
	-- Запросить у сервера данные о доступных персонажах
	-- > cb function - callback-функция, которая будет вызвана после получения: cb( table / nil characterList )
	-- = void
	getCharacters = function( cb )
		local id = #Character.characterListRequests + 1
		Character.characterListRequests[ id ] = cb
		
		triggerServerEvent( "Character.onClientRequestCharacters", resourceRoot, id )
	end;
	
	-- Выбрал ли игрок персонажа (есть ли текущий персонаж)
	-- = bool isSelected
	isSelected = function()
		return ( Character.data ~= nil )
	end;
	
	-- Возвращает ID текущего активного персонажа или nil, если персонаж не выбран
	-- = number / nil characterID
	getSelectedCharacterID = function()
		if ( Character.isSelected() ) then
			return Character.data.id
		else
			return nil
		end
	end;
	
	-- Попробовать заспавнить текущего персонажа
	-- > characterID number - отправить запрос об изменении текущего активного персонажа
	-- = void
	requestCharacterSpawn = function( characterID )
		if not validVar( characterID, "characterID", "number" ) then return nil end
		
		triggerServerEvent( "Character.onClientRequestCharacterSpawn", resourceRoot, characterID )
	end;
	
	-- Запросить деспавн персонажа (откроется лобби, так как персонажа не будет в игре)
	-- = void
	requestCharacterDespawn = function()
		if ( Character.isSelected() ) then
			triggerServerEvent( "Character.onClientRequestCharacterDespawn", resourceRoot )
		end	
	end;
	
	-- Получить информацию о текущем уровне и оставшемся опыте для перехода на следующий уровень. Возвращает таблицу вида { level = number; levelExp = number; nextLevelExp = number; }
	-- > totalExperience number - общий опыт персонажа
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
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Пришел список персонажей по запросу getCharacters
	-- > characterList table / nil - таблица вида characterID => [ character data ] или nil, если не вошел в аккаунт
	onServerSentCharacters = function( characterList, requestID )
		Character.characterListRequests[ requestID ]( characterList )
		Character.characterListRequests[ requestID ] = nil
	end;
	
	-- Установлен новый текущий персонаж (или nil)
	onServerSetCurrentCharacter = function( characterData )
		Debug.info( "Установлен новый текущий песонаж:", characterData )
		Character.data = characterData
		triggerEvent( "Character.onCharacterChange", resourceRoot )
		if ( characterData ~= nil ) then
			triggerEvent( "Character.onDataChange", resourceRoot, characterData )
		end
	end;
	
	-- Сервер присалал новые данные по персонажу
	onServerUpdateCharacterData = function( data )
		--Debug.info( "Обновлены данные о персонаже: ", data )
		
		for k, v in pairs( data ) do
			Character.data[ k ] = v
		end
		
		triggerEvent( "Character.onDataChange", resourceRoot, data )
	end;
	
	-- Элемент попал в зону стрима
	onElementStreamIn = function()
		if ( getElementType( source ) == "player" or getElementType( source ) == "ped" ) then
			-- Это игрок
			local playerElement = source
			
			-- Добавляем взаимодействие с ним
			addEventHandler( "CrosshairTarget.onTargetingStart", playerElement, function()
				-- Игрок смотрит на другого игрока
				local assignedToAvatarName = Avatar.getNameByPlayerElement( playerElement )
				if ( assignedToAvatarName == nil ) then
					Crosshair.setLabel( "Игрок", "Неизвестный", nil, true )
				else
					Crosshair.setLabel( "Игрок", assignedToAvatarName, nil, true )
				end
				CrosshairTarget.highlightElement( playerElement )
			end )
			
			addEventHandler( "CrosshairTarget.onTargetingStop", playerElement, function()
				-- Игрок перестал смотреть на другого игрока
				Crosshair.removeLabel()
				CrosshairTarget.highlightElement( nil )
			end )
			
			-- Обработка действия - открыть меню взаимодействия
			addEventHandler( "CrosshairTarget.onInteractionStart", playerElement, function()
				-- Игрок взаимодействует с игроком (нажали E)
				local assignedToAvatarName = Avatar.getNameByPlayerElement( playerElement )
				if ( assignedToAvatarName == nil ) then
					assignedToAvatarName = "Неизвестный"
				end
				
				InteractionMenu.show( "Игрок", assignedToAvatarName, {
					{ 
						icon = "money";
						title = "Передать деньги";
						handler = function()
							Debug.info( "Игрок передает другому игроку деньги" )
							InteractionMenu.hide()
						end;
					},
					{
						icon = "font";
						title = "Изменить имя";
						handler = function()
							Debug.info( "Игрок изменяет имя другого игрока" )
							InteractionMenu.hide()
						end;
					},
					{
						icon = "ban";
						title = "Сообщить о нарушении";
						handler = function()
							Debug.info( "Игрок сообщает о нарушении от другого игрока" )
							InteractionMenu.hide()
						end;
					}
				}, "<img src='" .. Avatar.getImagePath( Avatar.getAlias( playerElement ), "small" ) .. "' class='avatar'>" )
			end )
			
		end
	end;
	
	-- Элемент вышел из зоны стрима
	onElementStreamOut = function()
	
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Character.init )