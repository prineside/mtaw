--[[
	Evidence - доказательство
	Отвечает за запоминание игроками происшествий и предоставяет их по запросу
	
	Игроки, которых видит игрок, превращаются в уникальных сущностей, которые
	существуют до того момента, когда игрок перестанет их видеть.
	Как только игрок замечает другого игрока, он начинает собирать о нем информацию
	(постепенно проясняется аватарка, периодически сохраняется перемещение игрока).
	Все события, связанные с этим игроком, записываются на его сущность, и сохраняются
	когда игрок перестает его видеть
	
	События уточняют позицию игрока (если он не находится в радиусе 25м от точки 
	события)
	
	Система должна уметь применять следующие фильтры:
		[area IN AABB]
		[time FROM A TO B]
		[avatar LIKE XYZ]
		[eventType IS TYPE]
		
	
	Есть некие сеансы наблюдения (встречи) игроков, в которые записываются данные
	от начала встречи до выхода игрока из поля зрения. Во время сеанса аватарка
	наблюдаемого игрока постоянно проясняется.
	
	Все время указано в виде кол-ва секунд с timeStart для экономии места
	
	meetings = {
		meetID = {
			avatar = string,													-- nil, если игрока еще ни разу не видели за встречу. Вначале X77777777, где X - шаблон аватарки
			eventCount = number,
			area = { minX, maxX, minY, maxY },
			timeStart = number,
			lastTime = number,													-- время последнего обновления
			timeEnd = number,													-- если nil, встреча происходит сейчас
			remembered = bool, 													-- дольше остается в памяти, игрок отмечает встречу как важную
			
			eventTypeCount = {},												-- eventType => кол-во происшествий
			events = {
				eventData => { time, time, ... }								-- eventData - это тип события и данные сериализованные
			}, 
			positions = {
				x = {}, y = {}, z = {}, t = {}									-- позиция игрока, записывается если игрок отошел от предыдущей позиции на 25м (t - timestamp)
			},
			
			lastPosition = { x, y, z },
		}
	}
	
	Формат файла:
	
	I - version				(4b)
	I - meetingCount 		(4b)
	{
		I - sectionLength		(4b)
		
		I - meetID				(4b)
		c9 - avatar				(9b)
		I - eventCount			(4b)
		f - minX				(4b)
		f - maxX				(4b)
		f - minY				(4b)
		f - maxY				(4b)
		I - timeStart			(4b)
		I - timeEnd				(4b)
		b - remembered			(1b)
		
		I - eventTypeCountCount	(4b)
		for eventTypeCountCount:	(n x 4b)
			H - eventType			(2b)
			H - eventCount			(2b)
			
		I - eventCount			(4b)
		for eventCount:
		{
			I - sectionLength		(4b)
			
			s - eventData			(?b)
			I - eventTimeCount			(4b)
			for eventTimeCount:			(n x 2b)
				H - eventTime			(2b)
		}
			
		I - positionsCount		(4b)
		for positionsCount:			(n x 14b)
			f - x					(4b)
			f - y					(4b)
			f - z					(4b)
			H - t					(2b)
	}
--]]
addEvent( "Evidence.onEvent", true )

--------------------------------------------------------------------------------
--<[ Модуль Evidence ]>---------------------------------------------------------
--------------------------------------------------------------------------------
Evidence = {
	formatVersion = 3;

	_loadedCharacterID = nil;	-- ID персонажа, память которого загружена в данный момент
	
	meetings = {};				-- meetID => meetingData
	pedMeetID = {};				-- ped => meetID, используется для слежки за позицией и обнаружения аватарок
	
	_teaKey = "qO0MwV0w";		-- Смешивается с серийным номером клиента (getPlayerSerial)
	
	meetingListVisible = false;
	eventQueue = {};			-- Очередь событий, которые ожидают обработки корутиной
	
	evidenceTypeIdToAlias = {};	-- id типа происшествия => алиас, для обработки событий из сервера (чтобы не передавать алиас)
	
	_lastDatabaseSaveTime = 0;	-- Время последнего сохранения базы корутиной
	
	init = function()
		-- Создаем массив evidenceTypeID => evidenceTypeAlias
		for evidenceAlias, evidenceData in pairs( EvidenceType ) do
			Evidence.evidenceTypeIdToAlias[ evidenceData.id ] = evidenceAlias
		end
	
		addEventHandler( "Main.onClientLoad", resourceRoot, Evidence.onClientLoad )
	end;
	
	onClientLoad = function()
		addEventHandler( "onClientElementStreamIn", root, Evidence.onElementStreamIn )
		addEventHandler( "onClientElementStreamOut", root, Evidence.onElementStreamOut )
		
		addEventHandler( "Character.onCharacterChange", resourceRoot, Evidence.onCharacterChange )
		addEventHandler( "onClientResourceStop", resourceRoot, Evidence.onClientResourceStop )
		
		addEventHandler( "Evidence.onEvent", resourceRoot, Evidence.onEvent )
		
		-- Корутина - периодически сохраняем базу с помощью корутины
		local saveDatabaseHandler = coroutine.create( Evidence._saveDatabaseCoroutine )
		setTimer( function()
			if ( getRealTime().timestamp - Evidence._lastDatabaseSaveTime > 60 ) then
				-- Прошло больше 1 минуты
				coroutine.resume( saveDatabaseHandler, getTickCount() )
			end
		end, 50, 0 )
		
		-- Корутина - обработка видимости
		local visibilityHandler = coroutine.create( Evidence._handleVisibility )
		local visibilityHandlerTimer
		visibilityHandlerTimer = setTimer( function()
			local status = coroutine.resume( visibilityHandler, getTickCount() )
			if ( not status ) then
				killTimer( visibilityHandlerTimer )
			end
		end, 50, 0 )
		
		-- Корутина - очищение памяти от старых происшествий
		local cc = coroutine.create( Evidence._handleCleaningOldMeetings )
		setTimer( function()
			coroutine.resume( cc, getTickCount() )
		end, 20 * 1000, 0 )
		
		-- Корутина - обработка событий
		local eventQueueHandler = coroutine.create( Evidence._handleEventQueue )
		addEventHandler( "onClientPreRender", root, function()
			coroutine.resume( eventQueueHandler, getTickCount() )
		end )
		
		-- Игрок выключил курсор на Esc, скрываем список встреч
		addEventHandler( "Cursor.onHiddenByEsc", resourceRoot, function()
			if ( Evidence.meetingListVisible ) then
				Evidence.hideMeetingList()
			end
		end )
		
		bindKey( "p", "down", Evidence.toggleMeetingList )
	end;
	
	showMeetingList = function()
		Evidence.sendMeetingListToGUI()
		
		GUI.sendJS( "Evidence.showMeetingList" )
		
		Cursor.show( "Evidence.meetingList" )
		Crosshair.disable( "Evidence.meetingList" )
		
		-- Отключаем кнопки с биндами, чтобы не включалось что не надо когда вводим в чат сообщение
		guiSetInputEnabled( true )
		
		Evidence.meetingListVisible = true
	end;
	
	hideMeetingList = function()
		GUI.sendJS( "Evidence.hideMeetingList" )
		
		Cursor.hide( "Evidence.meetingList" )
		Crosshair.cancelDisabling( "Evidence.meetingList" )
		
		-- Заново включаем бинды
		guiSetInputEnabled( false )
		
		Evidence.meetingListVisible = false
	end;
	
	sendMeetingListToGUI = function()
		local meetings = {}
		
		for meetID, meetData in pairs( Evidence.meetings ) do
			if ( meetData.avatar ~= nil ) then
				-- Аватар хоть немного замечен
				Avatar.getSmallAvatarTexture( meetData.avatar )
				meetings[ meetID ] = {
					avatar = meetData.avatar;
					avatarFilePath = Avatar.getImagePath( meetData.avatar, "small" );
					eventCount = meetData.eventCount;
					eventTypeCount = meetData.eventTypeCount;
					area = meetData.area;
					timeStart = meetData.timeStart;
					lastTime = meetData.lastTime;
					timeEnd = meetData.timeEnd;
					remembered = meetData.remembered;
				}
			end	
		end	
		
		GUI.sendJS( "Evidence.setMeetings", meetings )
	end;
	
	toggleMeetingList = function()
		if ( Evidence.meetingListVisible ) then
			Evidence.hideMeetingList()
		else
			Evidence.showMeetingList()
		end
	end;
	
	databaseIsLoaded = function()
		return Evidence._loadedCharacterID ~= nil
	end;
	
	generateMeetID = function()
		--local meetID = randomString( 5 )
		local meetID = math.random( 1, 2147483647 )
		if ( Evidence.meetings[ meetID ] == nil ) then
			return meetID
		else
			return Evidence.generateMeetID()
		end
	end;
	
	-- Загружает базу доказательств из файла (если есть), или очищает в памяти базу (если нет)
	loadDatabase = function( characterID )
		if not validVar( characterID, "characterID", "number" ) then return nil end
		
		local _st = getTickCount()
	
		-- Очищаем базу в памяти
		Evidence.unloadDatabase()
		
		-- Загружаем базу из файла
		if ( fileExists( "@meetings/" .. characterID .. ".db" ) ) then
			-- binary
			local unpackEvent = function( eventBinaryData )
				local ptr = 1
				local eventData, eventTimeCount = struct.unpack( "<sI", eventBinaryData )
				ptr = ptr + eventData:len() + 1 + 4
				
				local eventTimes = {}
				for i = 1, eventTimeCount do
					eventTimes[ #eventTimes + 1 ] = struct.unpack( "<H", eventBinaryData:sub( ptr, ptr + 2 ) )
					ptr = ptr + 2
				end
				
				return eventData, eventTimes
			end
			
			local unpackMeeting = function( sectionBinaryData )
				local meetData = {}
				
				meetData.area = {}
				
				local ptr = 1
				
				local meetID, remembered
				meetID, meetData.avatar, meetData.eventCount, meetData.area.minX, meetData.area.maxX, meetData.area.minY, meetData.area.maxY, meetData.timeStart, meetData.lastTime, meetData.timeEnd, remembered = struct.unpack( "<Ic9IffffIIIb", sectionBinaryData:sub( ptr, ptr + 46 ) )
				ptr = ptr + 46
				
				if ( remembered == 1 ) then
					meetData.remembered = true
				else
					meetData.remembered = false
				end
				
				-- eventTypeCount
				local eventTypeCount = {}
				local eventTypeCountCount = struct.unpack( "<I", sectionBinaryData:sub( ptr, ptr + 4 ) )
				ptr = ptr + 4
				
				for i = 1, eventTypeCountCount do
					local eventType, eventCount = struct.unpack( "<HH", sectionBinaryData:sub( ptr, ptr + 4 ) )
					ptr = ptr + 4
					
					eventTypeCount[ eventType ] = eventCount
				end
				meetData.eventTypeCount = eventTypeCount
				
				-- events
				local events = {}
				local eventCount = struct.unpack( "<I", sectionBinaryData:sub( ptr, ptr + 4 ) )
				ptr = ptr + 4
				
				for i = 1, eventCount do
					local eventSectionLength = struct.unpack( "<I", sectionBinaryData:sub( ptr, ptr + 4 ) )
					ptr = ptr + 4
					
					local eventData, eventTimes = unpackEvent( sectionBinaryData:sub( ptr, ptr + eventSectionLength ) )
					ptr = ptr + eventSectionLength
					
					events[ eventData ] = eventTimes
				end
				meetData.events = events
				
				-- positions
				local positions = {
					x = {};
					y = {};
					z = {};
					t = {};
				}
				local positionsCount = struct.unpack( "<I", sectionBinaryData:sub( ptr, ptr + 4 ) )
				ptr = ptr + 4
				for i = 1, positionsCount do
					local x, y, z, t = struct.unpack( "<fffH", sectionBinaryData:sub( ptr, ptr + 14 ) )
					ptr = ptr + 14
					
					positions.x[ i ] = x
					positions.y[ i ] = y
					positions.z[ i ] = z
					positions.t[ i ] = t
				end
				meetData.positions = positions
				
				return meetID, meetData
			end
			
			Evidence.meetings = {}
			
			local fileData = fileGetContents( "@meetings/" .. characterID .. ".db" )
			if ( fileData == false or fileData == nil or fileData:len() < 8 ) then
				-- Неправильный формат файла (либо ключ шифрования другой, либо разные версии формата / не зашифрован)
				Debug.info( "Загрузка сведений отменена, так как файл (" .. characterID .. ".db) невозможно расшифровать" )
			else
				-- Формат правильный 
				local ptr = 1
				
				local version, meetingCount = struct.unpack( "<II", fileData:sub( ptr, ptr + 8 ) )
				ptr = ptr + 8
				
				if ( version == Evidence.formatVersion ) then
					for i = 1, meetingCount do
						local meetingSectionLength = struct.unpack( "<I", fileData:sub( ptr, ptr + 4 ) )
						ptr = ptr + 4
						
						local meetingEncoded = fileData:sub( ptr, ptr + meetingSectionLength )
						local meetID, meetData = unpackMeeting( base64Decode( teaDecode( meetingEncoded, Evidence._getEncryptionKey() ) ) )
						ptr = ptr + meetingSectionLength
						
						Evidence.meetings[ meetID ] = meetData
					end
				else
					-- Версия формата Evidence изменилась
					Debug.info( "Загрузка сведений отменена, так как версия формата файла " .. characterID .. ".db (" .. version .. ") отличается от необходимой (" .. Evidence.formatVersion .. ")" )
				end
			end
		end
		
		Debug.info( "Loaded database: ", Evidence.meetings, " in ", getTickCount() - _st, "ms." )
		
		Evidence._loadedCharacterID = characterID
	end;
	
	-- Выгружает базу из оперативной памяти
	unloadDatabase = function( save )
		if ( save ) then
			if ( Evidence.databaseIsLoaded() ) then
				for ped, meetID in pairs( Evidence.pedMeetID ) do
					Evidence.finishMeeting( ped )
				end
				
				Evidence.saveDatabase()
			end
		end 
		
		Evidence.meetings = {}
		Evidence.pedMeetID = {}
		Evidence.eventQueue = {}
		
		Evidence._loadedCharacterID = nil
	end;
	
	-- Начинает встречу с педом / игроком
	startMeeting = function( ped )
		local meetID = Evidence.generateMeetID()
		Evidence.pedMeetID[ ped ] = meetID
		
		local x, y, z = getElementPosition( ped )
		
		Evidence.meetings[ meetID ] = {
			avatar = nil;
			events = {};
			positions = {
				x = { x }; 
				y = { y }; 
				z = { z };
				t = { 0 };
			};
			eventCount = 0;
			eventTypeCount = {};
			area = { 
				minX = x; 
				maxX = x;
				minY = y;
				maxY = y;
			};
			timeStart = getRealTime().timestamp;
			lastTime = getRealTime().timestamp;
			timeEnd = nil;
			remembered = false;
			lastPosition = { x, y, z };
		}
		
		--Debug.info( "Начинаем встречу с ", ped, ", номер ", Evidence.pedMeetID[ ped ] )
	end;
	
	-- Заканчивает встречу с педом / игроком
	finishMeeting = function( ped )
		--Debug.info( "Заканчиваем встречу с ", ped, " номер ", Evidence.pedMeetID[ ped ] )
		if ( Evidence.databaseIsLoaded() ) then
			local meetID = Evidence.pedMeetID[ ped ]
			
			if ( Evidence.meetings[ meetID ].avatar == nil ) then
				-- Ни разу не увидел
				Evidence.meetings[ meetID ] = nil
			else
				Evidence.meetings[ meetID ].timeEnd = getRealTime().timestamp
				Evidence.meetings[ meetID ].lastPosition = nil
			end
		end
		
		Evidence.pedMeetID[ ped ] = nil
	end;
	
	-- Добавить событие во встречу
	addEvent = function( pedCausedBy, eventType, eventData )
		if ( not isElement( pedCausedBy ) or not isElementStreamedIn( pedCausedBy ) ) then
			return nil
		end
		
		if ( Evidence.pedMeetID[ pedCausedBy ] == nil ) then
			-- Встречи еще нет, создаем
			Evidence.startMeeting( pedCausedBy )
		end
		
		-- Добавляем событие во встречу
		local meetID = Evidence.pedMeetID[ pedCausedBy ]
		local eventKey = eventType .. "|" .. eventData
		
		if ( Evidence.meetings[ meetID ].events[ eventKey ] == nil ) then
			Evidence.meetings[ meetID ].events[ eventKey ] = {}
		end
		
		table.insert( Evidence.meetings[ meetID ].events[ eventKey ], getRealTime().timestamp - Evidence.meetings[ meetID ].timeStart )
		
		Evidence.meetings[ meetID ].lastTime = getRealTime().timestamp
		Evidence.meetings[ meetID ].eventCount = Evidence.meetings[ meetID ].eventCount + 1
		
		if ( Evidence.meetings[ meetID ].eventTypeCount[ eventType ] == nil ) then
			Evidence.meetings[ meetID ].eventTypeCount[ eventType ] = 0
		end
		
		Evidence.meetings[ meetID ].eventTypeCount[ eventType ] = Evidence.meetings[ meetID ].eventTypeCount[ eventType ] + 1
	end;
	
	-- Возвращает ключ, которым был зашифрован файл базы (16 символов)
	_getEncryptionKey = function()
		local serial = getPlayerSerial()
		local keyChars = {}
		local idx = 1
		for _, i in pairs( { 1, 32, 11, 9, 2, 4, 7, 29 } ) do
			keyChars[ #keyChars + 1 ] = serial:sub( i, i )
			keyChars[ #keyChars + 1 ] = Evidence._teaKey:sub( idx, idx )
			
			idx = idx + 1
		end
		
		return table.concat( keyChars )
	end;
	
	-- Обрабатывает заметность игроков (дорисовывает аватарки), периодически сохраняет позиции
	-- игроков, которые есть в стриме
	-- Игроки выбираются рандомно
	_handleVisibility = function( iterTick )
		local shuffledPeds
		local tx, ty, tz, dist
		local cx, cy, cz
		local yieldCount
		local handledCount
		local a
		local meetID 
		local meetData 
		local charID
		local posID
		
		while ( true ) do
			-- Случайным образом перемешиваем игроков
			shuffledPeds = {}
			
			for ped, meetID in pairs( Evidence.pedMeetID ) do
				shuffledPeds[ #shuffledPeds + 1 ] = ped
			end
			
			iterTick = coroutine.yield()
			
			shuffle( shuffledPeds )
			
			iterTick = coroutine.yield()
			
			-- Берем сколько успеем и обрабатываем
			cx, cy, cz = getCameraMatrix()
			
			yieldCount = 0
			handledCount = 0
			
			for _, ped in pairs( shuffledPeds ) do
				if ( Evidence.pedMeetID[ ped ] ~= nil and isElement( ped ) and isElementStreamedIn( ped ) ) then
					if ( isElementOnScreen( ped ) ) then
						tx, ty, tz = getElementPosition( ped )
						dist = getDistanceBetweenPoints3D( cx, cy, cz, tx, ty, tz )
						if ( dist < 150 ) then
							-- В радиусе 150м (запоминается)
							meetID = Evidence.pedMeetID[ ped ]
							
							if ( math.random() * 150 > dist ) then
								-- Открываем один сегмент аватарки
								a = Avatar.getAlias( ped )
								if ( a ) then
									-- Есть аватар
									meetData = Evidence.meetings[ meetID ]
									if ( meetData.avatar == nil ) then
										-- Еще не раскрыл аватарку, сохраняем только форму
										meetData.avatar = a:sub( 1, 1 ) .. "77777777"
									else
										-- Уже раскрыл аватарку, открываем один сегмент
										charID = math.random( 2, 9 )
										meetData.avatar = meetData.avatar:sub( 1, charID - 1 ) .. a:sub( charID, charID ) .. meetData.avatar:sub( charID + 1, 9 )
									end
								else
									--Debug.info( "У ", ped, "нет аватарки" )
								end
							end
							
							-- Запоминаем позицию, если отошел больше чем на 25м
							dist = getDistanceBetweenPoints3D( Evidence.meetings[ meetID ].lastPosition[ 1 ], Evidence.meetings[ meetID ].lastPosition[ 2 ], Evidence.meetings[ meetID ].lastPosition[ 3 ], tx, ty, tz )
							
							-- Debug Иммитируем перемещение бота 
							if ( math.random() < 0.1 ) then
								dist = 26
							end
							
							if ( dist > 25 ) then
								posID = #Evidence.meetings[ meetID ].positions.t + 1
								
								Evidence.meetings[ meetID ].positions.x[ posID ] = tx
								Evidence.meetings[ meetID ].positions.y[ posID ] = ty
								Evidence.meetings[ meetID ].positions.z[ posID ] = tz
								Evidence.meetings[ meetID ].positions.t[ posID ] = getRealTime().timestamp - Evidence.meetings[ meetID ].timeStart
								
								Evidence.meetings[ meetID ].lastPosition[ 1 ] = tx
								Evidence.meetings[ meetID ].lastPosition[ 2 ] = ty
								Evidence.meetings[ meetID ].lastPosition[ 3 ] = tz
								
								if ( Evidence.meetings[ meetID ].area.minX > tx ) then
									Evidence.meetings[ meetID ].area.minX = tx
								end
								
								if ( Evidence.meetings[ meetID ].area.maxX < tx ) then
									Evidence.meetings[ meetID ].area.maxX = tx
								end
								
								if ( Evidence.meetings[ meetID ].area.minY > ty ) then
									Evidence.meetings[ meetID ].area.minY = ty
								end
								
								if ( Evidence.meetings[ meetID ].area.maxY < ty ) then
									Evidence.meetings[ meetID ].area.maxY = ty
								end
							end
						end
					end
				end
				
				handledCount = handledCount + 1
				
				if ( getTickCount() - iterTick > 1 ) then
					yieldCount = yieldCount + 1
					Debug.info( yieldCount )
					
					if ( yieldCount == 3 ) then
						Debug.debugData.evidenceHandledTargets = handledCount
						break
					else
						iterTick = coroutine.yield()
					end
				end
			end
			
			Debug.debugData.evidenceHandledTargets = handledCount
			iterTick = coroutine.yield()
		end
	end;
	
	-- Удаляет из базы старые встречи
	_handleCleaningOldMeetings = function( iterTick )
		while ( true ) do
			for meetID, meetData in pairs( Evidence.meetings ) do
				local forgetTime = 60 * 60 * 24 * 2
				if ( meetData.remembered ) then
					forgetTime = 60 * 60 * 24 * 14
				end
				
				if ( getRealTime().timestamp - meetData.timeStart > forgetTime ) then
					-- Забываем
					Debug.info( "Забываем", meetID )
					Evidence.meetings[ meetID ] = nil
				end
				
				if ( getTickCount() - iterTick > 2 ) then
					iterTick = coroutine.yield()
				end
			end
		
			iterTick = coroutine.yield()
		end
	end;
	
	-- Обработка очереди событий
	_handleEventQueue = function( iterTick )
		while ( true ) do
			if ( #Evidence.eventQueue ~= 0 ) then
				-- В очереди есть события
				for i = #Evidence.eventQueue, 1, -1 do
					local eventData = Evidence.eventQueue[ #Evidence.eventQueue ]
					
					Evidence.addEvent( eventData[ 1 ], eventData[ 2 ], eventData[ 3 ] )
					Evidence.eventQueue[ #Evidence.eventQueue ] = nil
					
					if ( getTickCount() - iterTick > 2 ) then
						Debug.debugData.evidenceEventQueue = #Evidence.eventQueue
						iterTick = coroutine.yield()
						break
					end
				end
			end
			
			Debug.debugData.evidenceEventQueue = #Evidence.eventQueue
			iterTick = coroutine.yield()
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Экспорт базы ]>--------------------------------------------------------
	----------------------------------------------------------------------------
	
	_binaryPackEvent = function( eventKey, eventTimes )
		local eventData = {}
		
		eventData[ #eventData + 1 ] = struct.pack( "<s", eventKey )
		eventData[ #eventData + 1 ] = struct.pack( "<I", #eventTimes )
		
		local times = {}
		for _, t in pairs( eventTimes ) do
			times[ #times + 1 ] = struct.pack( "<H", t )
		end
		eventData[ #eventData + 1 ] = table.concat( times )
		
		return table.concat( eventData )
	end;
	
	_binaryPackMeeting = function( meetID, meetData )
		local meetingData = {}
		
		local remembered
		if ( meetData.remembered ) then
			remembered = 1
		else
			remembered = 0
		end
		
		meetingData[ #meetingData + 1 ] = struct.pack( "<Ic9IffffIIIb", meetID, meetData.avatar, meetData.eventCount, meetData.area.minX, meetData.area.maxX, meetData.area.minY, meetData.area.maxY, meetData.timeStart, meetData.lastTime, meetData.timeEnd, remembered )
		
		local itemCount, items
		local packed
		
		-- eventTypeCount
		itemCount = 0
		items = {}
		for eventType, eventTypeCount in pairs( meetData.eventTypeCount ) do
			itemCount = itemCount + 1
			
			items[ #items + 1 ] = struct.pack( "<HH", eventType, eventTypeCount )
		end
		
		meetingData[ #meetingData + 1 ] = struct.pack( "<I", itemCount )
		meetingData[ #meetingData + 1 ] = table.concat( items )
		
		-- events
		itemCount = 0
		items = {}
		
		if ( meetData.events == nil ) then
			Debug.error( "meetData.events is nil", meetData )
		end
		for eventData, eventTimes in pairs( meetData.events ) do
			itemCount = itemCount + 1
			
			packed = Evidence._binaryPackEvent( eventData, eventTimes )
			
			items[ #items + 1 ] = struct.pack( "<I", packed:len() )
			items[ #items + 1 ] = packed
		end
		
		meetingData[ #meetingData + 1 ] = struct.pack( "<I", itemCount )
		meetingData[ #meetingData + 1 ] = table.concat( items )
		
		-- positions
		itemCount = #meetData.positions.t
		items = {}
		for posID in pairs( meetData.positions.t ) do
			items[ #items + 1 ] = struct.pack( "<fffH", meetData.positions.x[ posID ], meetData.positions.y[ posID ], meetData.positions.z[ posID ], meetData.positions.t[ posID ] )
		end
		
		meetingData[ #meetingData + 1 ] = struct.pack( "<I", itemCount )
		meetingData[ #meetingData + 1 ] = table.concat( items )
		
		--
		
		return table.concat( meetingData )
	end;
	
	-- Сохраняет базу доказательств в файл
	saveDatabase = function()
		local _st = getTickCount()
		
		if ( Evidence._loadedCharacterID ~= nil ) then
			-- Заголовок (версия и кол-во встреч)
			local fileData = { 
				struct.pack( "<I", Evidence.formatVersion ),
				0				
			}
			local packed
			
			-- Встречи
			local encryptionKey = Evidence._getEncryptionKey()
			
			local meetingCount = 0
			for meetID, meetData in pairs( Evidence.meetings ) do
				if ( meetData.timeEnd ~= nil ) then
					packed = Evidence._binaryPackMeeting( meetID, meetData )
					packed = teaEncode( base64Encode( packed ), encryptionKey )
					fileData[ #fileData + 1 ] = struct.pack( "<I", packed:len() )
					fileData[ #fileData + 1 ] = packed
					
					meetingCount = meetingCount + 1
				end
			end
			
			-- Дописываем кол-во встреч в заранее зарезервированное место (байты 5-8)
			fileData[ 2 ] = struct.pack( "<I", meetingCount )
			
			-- Записываем в файл
			local handle = fileCreate( "@meetings/" .. Evidence._loadedCharacterID .. ".db" )
			--fileWrite( handle, teaEncode( base64Encode( table.concat( fileData ) ), Evidence._getEncryptionKey() ) )
			fileWrite( handle, table.concat( fileData ) )
			fileClose( handle )
		else
			Debug.error( "Невозможно сохранить базу доказательств - персонаж еще не загружен" )
		end
		
		Debug.info( "Saved database: ", Evidence.meetings, " in ", getTickCount() - _st, "ms." )
	end;
	
	-- Сохраняет базу доказательств "лениво", не вызывая лагов
	_saveDatabaseCoroutine = function( iterTick )
		while ( true ) do
			if ( Evidence._loadedCharacterID == nil ) then
				-- Не сохраняем ничего, если база не загружена
				coroutine.yield()
			end
			
			local saveStartTick = getTickCount()
			
			-- Копируем базу доказательств (только 1 уровень, ID встречи и таблицу встречи, нет необходимости копировать данные встречи)
			local meetings = {}
			for meetID, meetData in pairs( Evidence.meetings ) do
				meetings[ meetID ] = meetData
			end
			iterTick = coroutine.yield()
			
			-- Создаем таблицу с данными файла и записываем заголовок
			local fileData = { 
				struct.pack( "<I", Evidence.formatVersion ),
				0				
			}
			local packed
			
			-- Записываем встречи
			local encryptionKey = Evidence._getEncryptionKey()
			
			local meetingCount = 0
			for meetID, meetData in pairs( meetings ) do
				if ( meetData.timeEnd ~= nil ) then
					packed = Evidence._binaryPackMeeting( meetID, meetData )
					packed = teaEncode( base64Encode( packed ), encryptionKey )
					
					fileData[ #fileData + 1 ] = struct.pack( "<I", packed:len() )
					fileData[ #fileData + 1 ] = packed
					
					meetingCount = meetingCount + 1
					
					if ( getTickCount() - iterTick > 1 ) then
						iterTick = coroutine.yield()
					end
				end
			end
			
			-- Дописываем кол-во встреч в заранее зарезервированное место (байты 5-8)
			fileData[ 2 ] = struct.pack( "<I", meetingCount )
			
			-- Записываем в файл
			if ( Evidence._loadedCharacterID ~= nil ) then
				local handle = fileCreate( "@meetings/" .. Evidence._loadedCharacterID .. ".db" )
				local dataRaw = table.concat( fileData )
				fileWrite( handle, dataRaw )
				fileClose( handle )
				
				Debug.info( "База сохранена за " .. math.floor( ( getTickCount() - saveStartTick ) / 100 ) / 10 .. "s, размер базы:", dataRaw:len() / 1024, "kb" )
			end
			
			Evidence._lastDatabaseSaveTime = getRealTime().timestamp
			
			iterTick = coroutine.yield()
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	onEvent = function( pedCausedBy, eventType, eventData )
		if ( isElementStreamedIn( pedCausedBy ) ) then
			-- В стриме
			Evidence.eventQueue[ #Evidence.eventQueue + 1 ] = { pedCausedBy, eventType, eventData }
		else
			-- Вне стрима
			-- Debug.info( "Evidence is out of stream", timestamp, ticks, pedCausedBy, eventType, eventData )
		end
	end;
	
	-- Изменился персонаж - загружаем его память
	onCharacterChange = function()
		Evidence.unloadDatabase( true )
			
		if ( Character.isSelected() ) then
			Evidence.loadDatabase( Character.getSelectedCharacterID() )
		end
	end;
	
	-- Игрок вышел из игры
	onClientResourceStop = function()
		Evidence.unloadDatabase( true ) 
	end;
	
	-- Элемент застримился
	onElementStreamIn = function()
		-- Встреча создается при первом действии игрока / педа, не здесь
	end;
	
	onElementStreamOut = function()
		if ( Evidence.pedMeetID[ source ] ~= nil ) then
			-- Пед вышел из стрима - заканчиваем сессию
			Evidence.finishMeeting( source )
		end
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Evidence.init )