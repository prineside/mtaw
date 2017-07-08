--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Lobby.onDimensionRequest", true )									-- Сервер прислал ID измерения лобби при загрузке ( number dimensionID )
addEvent( "Lobby.onServerShowLobby", true )										-- Сервер открыл лобби ()
addEvent( "Lobby.onServerHideLobby", true )										-- Сервер спрятал лобби ()

--------------------------------------------------------------------------------
--<[ Модуль Lobby ]>------------------------------------------------------------
--------------------------------------------------------------------------------
Lobby = {
	--characterPreviewPedPosition = { x = 1481.40; y = -1790.28; z = 156.76; };
	characterPreviewPedPosition = { x = 1723.77; y = -1948.68; z = 14.12; };

	isVisible = false;
	
	dimension = nil;
	
	characterList = nil;
	characterPreviewPed = nil;
	selectedCharacterID = false;
	
	camera = {
		enabled = false;	-- Обрабатывается ли поворот мыши
		
			-- Обычный вид
			distance = 3.8;			-- Расстояние от персонажа (для 4:3. Широкоформат умножает дальность)
			height = 0.0;			-- Разница в высоте между персонажем и камерой
			heightLimitMin = -0.8;	-- Граница поворота по высоте
			heightLimitMax = 7;		-- Граница поворота по высоте
			speedY = 0.01;			-- Скорость поворота
			
			--[[ Вид на лицо 
			distance = 0.75;		-- Расстояние от персонажа
			height = 0.66;			-- Разница в высоте между персонажем и камерой
			heightLimitMin = -0.5;	-- Граница поворота по высоте
			heightLimitMax = 0.75;	-- Граница поворота по высоте
			speedY = 0.002;			-- Скорость поворота
			]]
			
		angle = 110;		-- Угол, с которого смотрит камера
		speedX = 0.2;		-- Скорость поворота
		
		startCursor = { x = 0; y = 0; };	-- Позиция курсора мыши в момент начала поворота
		startAngle = nil;					-- Угол в момент начала поворота
		currentHeightDelta = 1.2;				-- Текущая дельта по высоте
	};
	
	init = function()
		addEventHandler( "Main.onClientLoad", root, Lobby.onClientLoad )
		
		Main.setModuleLoaded( "Lobby", 0.5 )
		
		addEventHandler( "Lobby.onServerShowLobby", resourceRoot, Lobby.show )
		addEventHandler( "Lobby.onServerHideLobby", resourceRoot, Lobby.hide )
		
		addEventHandler( "Account.onPlayerLogIn", resourceRoot, Lobby.onPlayerLogIn )
		addEventHandler( "Account.onPlayerLogOut", resourceRoot, Lobby.onPlayerLogOut )
		
		addEventHandler( "Character.onCharacterChange", resourceRoot, Lobby.onCharacterChange )
		
		-- Запрещаем отключение курсора на Esc, когда лоби активен
		addEventHandler( "Cursor.onHiddenByEsc", resourceRoot, function()
			if ( Lobby.isVisible ) then
				cancelEvent()
			end
		end )
		
		-- Если обновятся данные о персонаже, обновляем их в списке
		addEventHandler( "Character.onDataChange", resourceRoot, function( data )
			if ( Character.data ~= nil ) then
				local characterID = Character.data.id
				if ( Lobby.characterList[ characterID ] ~= nil ) then
					for k, v in pairs( data ) do
						Lobby.characterList[ characterID ][ k ] = v
					end
				end
			end 
		end )
		
		-- Когда сервер пришлет номер измерения, считаем лобби загруженным
		-- TODO интеграция с Dimension
		addEventHandler( "Lobby.onDimensionRequest", resourceRoot, function( dimensionID )
			if ( Lobby.dimension == nil ) then
				Lobby.dimension = dimensionID;
				
				Main.setModuleLoaded( "Lobby", 1 )
			end
		end )
		
		-- Запрашиваем ID измерения
		triggerServerEvent( "Lobby.onClientRequestDimension", resourceRoot )
		
		-- Прокрутка камеры вокруг персонажа
		addEventHandler( "onClientClick", root, Lobby.onClientClick )
	end;
	
	onClientLoad = function()
		GUI.addBrowserEventHandler( "Lobby.logOut", Lobby.onLogOutRequest )
		GUI.addBrowserEventHandler( "Lobby.selectCharacter", Lobby.onCharacterSelected )
		GUI.addBrowserEventHandler( "Lobby.updateCharacterList", Lobby.updateCharacterList )
		GUI.addBrowserEventHandler( "Lobby.acceptCharacterSelection", Lobby.onAcceptCharacterSelection )
		GUI.addBrowserEventHandler( "Lobby.createCharacter", Lobby.onRequestCharacterCreationMenu )
		GUI.addBrowserEventHandler( "Lobby.cancelCharacterCreation", Lobby.onGuiCancelCharacterCreation )
		
		Lobby.characterPreviewPed = createPed( 0, Lobby.characterPreviewPedPosition.x, Lobby.characterPreviewPedPosition.y, Lobby.characterPreviewPedPosition.z, 90.0 )
		setElementDimension( Lobby.characterPreviewPed, Lobby.dimension )
	end;
	
	-- Показать лобби игрока 
	-- = void
	show = function()
		if ( not Lobby.isVisible ) then
			if ( Account.isLogined() ) then
				Lobby.isVisible = true
				
				GUI.sendJS( "Lobby.setVisible", true )
				Cursor.show( "Lobby" )
				Crosshair.disable( "Lobby" )
				
				GUI.sendJS( "GUI.setVisible", false )
				
				Inventory.setVisible( false )
				
				if ( Lobby.characterList == nil ) then
					Lobby.updateCharacterList()
				end
				
				-- Если персонаж был выбран, показываем заново (вдруг его данные обновились)
				Lobby.onCharacterSelected( Lobby.selectedCharacterID )
				
				setElementDimension( localPlayer, Lobby.dimension )
				
				-- Установка камеры в начальное положение
				Lobby.camera.startAngle = Lobby.camera.angle
				Lobby._handleCameraRotation()
				
				Chat.setVisible( false )
				
				-- Загружаем маппинг
				Mapping.load( "client/data/mapping/lobby.map", Lobby.dimension )
				--Mapping.load( "client/data/mapping/lobby.map" )
				
				-- Начальные параметры
				setFarClipDistance( 150 )
				setFogDistance( 1 )
				setTime( 21, 0 )
				setMinuteDuration( 20000000 )
				--setSunColor( 255, 255, 255, 255, 255, 255 )
				setSkyGradient( 0, 0, 0, 0, 0, 0 )
				--resetSkyGradient()
				--resetSunColor()
				setWeather( 0 )
				setWindVelocity( 0, 0, 0 )
				
				-- Запускаем жизнь лобби
				LiveLobby.start()
				
				if ( DEBUG_MODE and DebugCfg.openSettings ) then
					Settings.setVisible( true )
				end
			else
				Debug.info( "Вы еще не вошли в аккаунт" )
			end
		end
	end;

	-- Спрятать лобби
	-- = void
	hide = function()
		GUI.sendJS( "Lobby.setVisible", false )
		Cursor.hide( "Lobby" )
		Crosshair.cancelDisabling( "Lobby" )
			
		Lobby.isVisible = false
		
		-- Прячем панель настроек
		Settings.setVisible( false )
		
		-- Если показано меню создания персонажа, прячем
		if ( CharacterCreator.isVisible ) then
			CharacterCreator.hide()
		end	
		
		-- Останавливаем жизнь лобби
		LiveLobby.stop()
	end;
	
	-- Обновить информацию о персонажах игрока для отображения в лобби. Обращается к серверу за списком и обновляет GUI
	-- = void
	updateCharacterList = function()
		Character.getCharacters( function( characterList ) 
			-- Просчет уровня персонажей (для списка персонажей в лобби)
			for k, v in pairs( characterList ) do
				local levelInfo = Character.getLevelInfo( v.experience )
				characterList[ k ].level = levelInfo.level
				characterList[ k ].levelExp = levelInfo.levelExp
				characterList[ k ].nextLevelExp = levelInfo.nextLevelExp
				--Debug.info( levelInfo )
			end
			
			Lobby.characterList = characterList
			
			-- Прежде чем отправлять в GUI персонажей, убедимся, что аватарки сгенерированы
			for k, v in pairs( characterList ) do
				Avatar.getSmallAvatarTexture( v.avatar )
				Avatar.getNormalAvatarTexture( v.avatar )
			end
			
			-- Обновить в GUI список персонажей
			GUI.sendJS( "Lobby.setCharacters", characterList )
			
			--Debug.info( "Установлены персонажи в лобби: ", characterList )
			Popup.show( "Список персонажей обновлен", "info" )
		end )
	end;
	
	-- Обработка поворота камеры вокруг персонажа
	_handleCameraRotation = function()
		local screenX, screenY = guiGetScreenSize()
		local cx, cy = getCursorPosition()
		cx = cx * screenX
		cy = cy * screenY
		
		local deltaX = ( screenX / 2 - cx ) * Lobby.camera.speedX
		local deltaY = - ( screenY / 2 - cy ) * Lobby.camera.speedY
		Lobby.camera.angle = normalizeAngleDeg( Lobby.camera.startAngle + deltaX )
		Lobby.camera.currentHeightDelta = clamp( Lobby.camera.currentHeightDelta + deltaY, Lobby.camera.heightLimitMin, Lobby.camera.heightLimitMax )
		
		-- Поворот вокруг
		local cameraDistance = Lobby.camera.distance * ( screenX / screenY ) / 1.3333
		local px, py = getCoordsByAngleFromPoint( 0, 0, Lobby.camera.angle, cameraDistance )
		-- Высота
		local pz = Lobby.camera.currentHeightDelta
		
		local vectorMagnitude = math.sqrt( px * px + py * py + pz * pz )
		local coeff = cameraDistance / vectorMagnitude 
		px = px * coeff + Lobby.characterPreviewPedPosition.x
		py = py * coeff + Lobby.characterPreviewPedPosition.y
		pz = pz * coeff + Lobby.characterPreviewPedPosition.z + Lobby.camera.height
		
		--outputDebugString( pz .. " " .. vectorMagnitude )
		
		setCameraMatrix( px, py, pz, Lobby.characterPreviewPedPosition.x, Lobby.characterPreviewPedPosition.y, Lobby.characterPreviewPedPosition.z + Lobby.camera.height, 0, 70 )
		
		-- Установка курсора в центр экрана
		local screenX, screenY = guiGetScreenSize()
		Lobby.camera.startAngle = Lobby.camera.angle
        setCursorPosition( screenX / 2, screenY / 2 )
	end;
	
	-- Показать педа с предпросмотром скина выбраного персонажа или при создании нового
	-- > skinID number - ID модели скина
	-- > texture texture / nil - текстура, на которую будет заменена стандартная текстура скина
	-- = void
	setPreviewPed = function( skinID, texture )
		setElementModel( Lobby.characterPreviewPed, skinID )
		
		setElementPosition( Lobby.characterPreviewPed, Lobby.characterPreviewPedPosition.x, Lobby.characterPreviewPedPosition.y, Lobby.characterPreviewPedPosition.z )
		
		if ( texture ~= nil ) then
			-- TODO замена текстуры
		end
	end;
	
	-- Скрыть педа с предпросмотром скина
	-- = void
	hidePreviewPed = function()
		setElementPosition( Lobby.characterPreviewPed, 1732.2823, 1930.5439, 13.3563 )
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Клиент выбрал персонаж из списка GUI
	onCharacterSelected = function( characterID )
		if ( characterID == false ) then
			GUI.sendJS( "Lobby.setCharacterInfo", false )
			
			-- Скрываем персонаж
			Lobby.hidePreviewPed()
		else
			-- Отправляем данные в GUI
			local characterData = Lobby.characterList[ characterID ]
			local info = {}
			info.id = characterData.id
			info.name = characterData.name
			info.surname = characterData.surname
			info.money = characterData.money
			info.bank = characterData.bank
			
			info.health = characterData.health
			info.armor = characterData.armor
			info.satiety = characterData.satiety
			info.immunity = characterData.immunity
			info.energy = characterData.energy
			
			local levelInfo = Character.getLevelInfo( characterData.experience )
			info.level = levelInfo.level
			info.levelExp = levelInfo.levelExp
			info.nextLevelExp = levelInfo.nextLevelExp
			
			GUI.sendJS( "Lobby.setCharacterInfo", info )
			
			-- Показываем персонаж
			Lobby.setPreviewPed( characterData.skin )
		end
		Lobby.selectedCharacterID = characterID
		
		if ( DEBUG_MODE ) then
			-- Автоматически входим в игру
			if ( DebugCfg.skipLobby ) then
				if ( characterID ~= false ) then Character.requestCharacterSpawn( characterID ) end
			end
		end
	end;
	
	-- Игрок выбрал персонажа и сделал попытку войти в игру с ним
	onAcceptCharacterSelection = function( characterID )
		if not validVar( characterID, "characterID", { "number", "boolean" } ) then return nil end
		
		Debug.info( "Попытка входа с персонажем " .. tostring( characterID ) )
		if ( characterID == false ) then
			Popup.show( "Сначала выберите или создайте персонаж", "error" )
		else
			Character.requestCharacterSpawn( characterID )
		end
	end;
	
	-- Игрок нажал кнопку "Выход"
	onLogOutRequest = function()
		Account.logOut()
	end;
	
	onPlayerLogOut = function( oldAccountData )
		Lobby.hide()
	end;
	
	onPlayerLogIn = function( accountData )
		Lobby.show()
	end;
	
	onCharacterChange = function()
		if ( not Character.isSelected() ) then
			Lobby.show()
		else
			Lobby.hide()
		end
	end;
	
	onClientClick = function( button, state, absoluteX, absoluteY, worldX, worldY, worldZ, clickedElement )
		if ( Lobby.isVisible ) then
			--Debug.info( "Player click state:", state, ", clicked ped:", ( clickedElement == Lobby.characterPreviewPed ), " (" .. tostring( clickedElement ) .. " " .. tostring( Lobby.characterPreviewPed ) .. "), camera enabled:", Lobby.camera.enabled )
		end
		
		if ( Lobby.isVisible and state == "down" and clickedElement == Lobby.characterPreviewPed and not Lobby.camera.enabled ) then
			-- Лобби активно, игрок нажал кнопку мыши на персонаже
			  
			if ( Settings.isVisible ) then
				-- Если открыта панель настроек, отменяем прокрутку
				return nil
			end
			
			if ( Lobby.characterCreationMenuOpened ) then
				-- Если открыта панель настроек, отменяем прокрутку
				return nil
			end
			
			local screenX, screenY = guiGetScreenSize()
			local cx, cy = getCursorPosition()
			cx = cx * screenX
			cy = cy * screenY
			
			addEventHandler( "onClientRender", root, Lobby._handleCameraRotation )
			Lobby.camera.enabled = true
			Lobby.camera.startCursor.x = cx
			Lobby.camera.startCursor.y = cy
			setCursorPosition( screenX / 2, screenY / 2 )
			Lobby.camera.startAngle = Lobby.camera.angle
			
			setCursorAlpha( 0 )
		elseif ( state == "up" and Lobby.camera.enabled ) then
			-- Игрок отпустил кнопку
			removeEventHandler( "onClientRender", root, Lobby._handleCameraRotation )
			Lobby.camera.enabled = false
			
			setCursorPosition( Lobby.camera.startCursor.x, Lobby.camera.startCursor.y )
			setCursorAlpha( 255 )
		end
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Lobby.init )