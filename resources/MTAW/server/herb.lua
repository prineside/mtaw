--[[
	- Места для высадки растений создаются заранее, чтобы не синхронизировать координаты при стриме
	- Растения могут быть размещены только в измерении Global
	- Дальность отрисовки устанавливается в CFG.graphics.herbDrawDistance и не превышает 300м 
	- Растения всегда синхронизированы с сервером
	
	Параметры каждого растения:
	- ID позиции	(20b)	// 1,048,576 мест для роста
	- ID класса		(8b)	// 256 разновидностей растений (0 - без растения)
	- Статус роста	(4b)	// 16 статусов роста
	bitLShift( placeID, 12 ) + bitLShift( classID, 4 ) + growPhase
	
	Статусы роста:
	0 - нет ничего
	1-15 - в зависимости от типа растения
	
	Пшеница:
	1 - расток (sprout)
	2 - сажанец (verdant)
	3 - молодое растение (young)
	4 - зрелое растение (ripe)
	
	Для декоративных (не синхронизированных автоматически) растений используется Ornamental
--]]
--------------------------------------------------------------------------------
--<[ Модуль Herb ]>-------------------------------------------------------------
--------------------------------------------------------------------------------
Herb = {
	aliasToID = {};			-- alias класса => ID класса (создается при инициализации)
	
	herbs = {
		class = {};			-- ID места => ID класса растения (или 0 (!!!), если ничего не посажено)
		growPhase = {};		-- ID места => статус роста (номер growPhases)
		nextPhase = {};		-- ID места => tickCount, после которого фаза роста растения увеличится на 1, или nil
		
		chunk = {};			-- ID места => ID чанка (обратное herbsByChunks), static
		touched = {};		-- ID места => true / false (true, если растение вырасло/было сорвано/посажено/что-то еще)
	};	
	
	herbsByChunks = {};		-- ID чанка => { placeID, placeID... }
	
	herbPlacesCount = nil;	-- Количество мест, в которых могут расти растения
	_maxGrowIterationTime = 5;	-- Время (мс), которое корутина может беспрерывно потратить раз в 50мс на обработку роста растений
	_maxClientUpdateIterationTime = 5;	-- Время (мс), которое корутина может беспрерывно потратить раз в 50мс на обработку роста растений
	
	init = function()
		Herb.herbPlacesCount = #ARR.herbPlaces.x
		
		addEventHandler( "Main.onServerLoad", root, Herb.onServerLoad )
		addEventHandler( "onResourceStop", resourceRoot, Herb.save )
		
		Debug.info( "Loaded " .. Herb.herbPlacesCount .. " herb places" )
	end;
	
	onServerLoad = function()
		-- Создаем массив herbClassAlias => herbClassID для удобства (чтобы не указывать типы растений в ID)
		for classID, classData in pairs( ARR.herbClasses ) do
			Herb.aliasToID[ classData.alias ] = classID
		end
		
		-- Инициализируем herbsByChunks
		Herb.herbsByChunks = Chunk.prepareArray()
		
		-- Инициируем массив растений
		for herbID = 1, Herb.herbPlacesCount do
			Herb.herbs.growPhase[ herbID ] = 0
			Herb.herbs.class[ herbID ] = 0
			
			local chunkID = Chunk.getID( ARR.herbPlaces.x[ herbID ], ARR.herbPlaces.y[ herbID ] )
			if ( chunkID == nil ) then
				Debug.error( "Herb place " .. herbID .. " is out of chunk stream box" )
			else
				Herb.herbs.chunk[ herbID ] = chunkID
				table.insert( Herb.herbsByChunks[ chunkID ], herbID )
			end
		end
		
		-- Загружаем данные о посаженных растениях
		if ( fileExists( "server/data/herb/herbs.dat" ) ) then
			-- Из файла
			local data = fileGetContents( "server/data/herb/herbs.dat" )
			local items = explode( ",", data )
			
			local herbID, herbClass, growPhase
			
			for _, herbData in pairs( items ) do
				herbID = bitAnd( bitRShift( herbData, 12 ), 0xFFFFF )
				herbClass = bitAnd( bitRShift( herbData, 4 ), 0xFF )
				growPhase = bitAnd( herbData, 0xF )
				
				Herb.set( herbID, herbClass, growPhase )
			end
		else
			-- Генерируем
			for herbID = 1, Herb.herbPlacesCount do
				Herb.set( herbID, 1, 1 )
			end
		end
		
		-- Обрабатываем рост растений
		local growHandlerCoroutine = coroutine.create( Herb._growHandlerCoroutine )
		setTimer( function()
			coroutine.resume( growHandlerCoroutine, getTickCount() )
		end, 50, 0 )
		
		-- При стриме чанков игроками, отправляем сразу весь чанк
		addEventHandler( "Chunk.onStreamIn", resourceRoot, Herb.onPlayerStreamInChunk )
		
		-- Обрабатываем стриминг игроков
		local clientUpdaterCoroutine = coroutine.create( Herb._clientUpdaterCoroutine )
		setTimer( function()
			coroutine.resume( clientUpdaterCoroutine, getTickCount() )
		end, 50, 0 )
		
		-- Периодически сохраняем растения
		setTimer( Herb.save, 5 * 60 * 1000, 0 )
		
		-- Автоматически высаживаем растения (на время теста)
		setTimer( function()
			for herbID, herbClassID in pairs( Herb.herbs.class ) do
				if ( herbClassID == 0 ) then
					Herb.set( herbID, 1, 1 )
				end
			end
		end, 1000 * 60 * 5, 0 )
		
		Debug.info( "Herb loaded" )
	end;
	
	-- Сохраняет данные о растениях в файл, чтобы позже можно было загрузить их заново
	-- = void
	save = function()
		local packed = {}
		for herbID, herbClassID in pairs( Herb.herbs.class ) do
			packed[ #packed + 1 ] = bitLShift( herbID, 12 ) + bitLShift( herbClassID, 4 ) + Herb.herbs.growPhase[ herbID ]
		end
		
		local s = table.concat( packed, "," )
		if ( s:len() > 0 ) then
			local f = fileCreate( "server/data/herb/herbs.dat" )
			fileWrite( f, s )
			fileClose( f )
		else
			Debug.error( "Can't save herb database" )
		end
	end;
	
	-- Возвращает true, если такое место для растения существует
	-- > herbID number
	-- = bool exists
	exists = function( herbID )
		return Herb.herbs.class[ herbID ] ~= nil
	end;
	
	-- Возвращает информацию о растении
	-- > herbID number
	-- = number herbClassID, number growPhase, number nextPhaseTickCount, number chunkID
	getInfo = function( herbID )
		if not validVar( herbID, "herbID", "number" ) then return nil end
		
		if ( Herb.herbs.class[ herbID ] ~= nil ) then
			return Herb.herbs.class[ herbID ], Herb.herbs.growPhase[ herbID ], Herb.herbs.nextPhase[ herbID ], Herb.herbs.chunk[ herbID ]
		else
			-- Растение не существует
			return nil
		end
	end;
	
	-- Возвращает позицию растения
	-- > herbID number
	-- = number x, number y, number z
	getPos = function( herbID )
		return ARR.herbPlaces.x[ herbID ], ARR.herbPlaces.y[ herbID ], ARR.herbPlaces.z[ herbID ]
	end;
	
	-- Установить растение
	-- Устанавливает следующий tickCount новой фазы роста (если текущая не последняя) и отмечает растение измененным (добавляет в очередь на синхронизацию)
	-- > herbID number - номер места роста растения
	-- > classID number / nil (или 0) - класс растения или nil (0), если нужно убрать растение
	-- > growPhase number - номер фазы роста растения (1-15). Если растения до этого не было, будет установлена первая фаза. Если фаза больше, чем максимальная фаза класса, будет установлена максимальная (т.е. фаза 15 всегда создаст полностью зрелое растение)
	-- > growPhaseTicks number / nil - если указано, будет считаться, что растение уже провело growPhaseTicks мс. в этой фазе роста
	-- = void
	set = function( herbID, classID, growPhase, growPhaseTicks )
		if ( Herb.herbs.class[ herbID ] == nil ) then
			Debug.error( "Herb place " .. tostring( herbID ) .. " not exists" )
			
			return nil
		end

		if ( classID == nil or classID == 0 ) then
			-- Убираем растение
			Herb.herbs.class[ herbID ] = 0
			Herb.herbs.growPhase[ herbID ] = 0
			Herb.herbs.nextPhase[ herbID ] = nil
		else
			-- Устанавливаем растение
			if ( ARR.herbClasses[ classID ] == nil ) then
				Debug.error( "Herb class " .. tostring( classID ) .. " not exists" )
			
				return nil
			end
			
			if ( growPhase < 1 or growPhase > 15 ) then
				Debug.error( "Herb grow phase " .. tostring( growPhase ) .. " is out of bounds" )
			
				return nil
			end
			
			if ( growPhaseTicks == nil or growPhaseTicks < 0 ) then
				growPhaseTicks = 0
			end
			
			if ( growPhase > #ARR.herbClasses[ classID ].growPhases ) then
				growPhase = #ARR.herbClasses[ classID ].growPhases
			end
			
			Herb.herbs.class[ herbID ] = classID
			Herb.herbs.growPhase[ herbID ] = growPhase
			
			if ( ARR.herbClasses[ classID ].growPhases[ growPhase ].growTime == nil ) then
				Herb.herbs.nextPhase[ herbID ] = nil
			else
				Herb.herbs.nextPhase[ herbID ] = getTickCount() + ( ARR.herbClasses[ classID ].growPhases[ growPhase ].growTime() - growPhaseTicks )
			end
		end
		
		Herb.herbs.touched[ herbID ] = true
	end;
	
	-- Отправить игроку информацию о целом чанке
	-- > playerElement player
	-- > chunkID number - номер чанка, который нужно отправить игроку
	-- = void
	updateClientChunk = function( playerElement, chunkID )
		if ( #Herb.herbsByChunks[ chunkID ] ~= nil ) then
			-- В этом чанке есть растения
			Herb.updateClientHerbs( playerElement, Herb.herbsByChunks[ chunkID ] )
		end
	end;
	
	-- Отправить игроку информацию об указанных местах роста
	-- > playerElement player
	-- > herbPlacesArray table - массив номеров мест роста { placeID, placeID, ... }
	-- = void
	updateClientHerbs = function( playerElement, herbPlacesArray )
		local packedPlaces = {}
		for _, herbID in pairs( herbPlacesArray ) do
			packedPlaces[ #packedPlaces + 1 ] = bitLShift( herbID, 12 ) + bitLShift( Herb.herbs.class[ herbID ], 4 ) + Herb.herbs.growPhase[ herbID ]
		end 
		
		triggerClientEvent( playerElement, "Herb.onHerbsUpdate", resourceRoot, packedPlaces )
	end;
	
	-- Отвечает за обработку роста растений
	-- iterTick - tickCount начала итерации
	_growHandlerCoroutine = function( iterTick )
		while ( true ) do
		
			for herbID = 1, Herb.herbPlacesCount do
				if ( Herb.herbs.nextPhase[ herbID ] ~= nil and Herb.herbs.nextPhase[ herbID ] < iterTick ) then
					-- Выросло
					Herb.set( herbID, Herb.herbs.class[ herbID ], Herb.herbs.growPhase[ herbID ] + 1, iterTick - Herb.herbs.nextPhase[ herbID ] )
					--Debug.info( iterTick )
				end
			
				if ( herbID % 200 == 0 ) then
					if ( getTickCount() - iterTick > Herb._maxGrowIterationTime ) then
						iterTick = coroutine.yield()
					end
				end
			end
			
			iterTick = coroutine.yield()
		end
	end;
	
	-- Отвечает за синхронизацию измененных растений с клиентами
	-- Сначала при изменении растение отмечается как touched
	-- Затем корутина проходит по всем растениям, собирает по чанкам растения,
	-- которые были изменены, и отправляет игрокам, у которых эти чанки загружены
	_clientUpdaterCoroutine = function( iterTick )
		while ( true ) do
			local touchedHerbs = {}
			
			-- Собираем все растения, которые были имзенены
			for herbID = 1, Herb.herbPlacesCount do
				if ( Herb.herbs.touched[ herbID ] == true ) then
					touchedHerbs[ #touchedHerbs + 1 ] = herbID
					Herb.herbs.touched[ herbID ] = false
				end
			end
			
			iterTick = coroutine.yield()
			
			if ( #touchedHerbs ~= 0 ) then
				-- Хоть одно растение изменилось
				--Debug.info( #touchedHerbs )
				
				-- Разбиваем их по чанкам и сразу пакуем для отправки
				local touchedByChunks = {}
				for _, herbID in pairs( touchedHerbs ) do
					if ( touchedByChunks[ Herb.herbs.chunk[ herbID ] ] == nil ) then
						touchedByChunks[ Herb.herbs.chunk[ herbID ] ] = {}
					end
					
					table.insert( touchedByChunks[ Herb.herbs.chunk[ herbID ] ], bitLShift( herbID, 12 ) + bitLShift( Herb.herbs.class[ herbID ], 4 ) + Herb.herbs.growPhase[ herbID ] )
				end
				
				iterTick = coroutine.yield()
				
				-- Отправляем игрокам, которые застримили чанки
				for _, playerElement in pairs( Main.loadedPlayers ) do
					if ( Chunk.streamedInChunks[ playerElement ] ~= nil ) then
						-- У игрока загружены чанки
						local dataForPlayer = {}
						
						for stremaedChunkID in pairs( Chunk.streamedInChunks[ playerElement ] ) do
							if ( touchedByChunks[ stremaedChunkID ] ~= nil ) then
								-- Игрок стримит чанк, в котором изменены растения
								for _, herbData in pairs( touchedByChunks[ stremaedChunkID ] ) do
									dataForPlayer[ #dataForPlayer + 1 ] = herbData
								end
							end
						end
						
						if ( #dataForPlayer ~= 0 ) then
							-- Есть что отправлять игроку
							triggerClientEvent( playerElement, "Herb.onHerbsUpdate", resourceRoot, dataForPlayer )
						end
						
						if ( getTickCount() - iterTick > Herb._maxClientUpdateIterationTime ) then
							iterTick = coroutine.yield()
						end
					end
				end
				
				iterTick = coroutine.yield()
			end
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Игрок застримил какой-то чанк
	onPlayerStreamInChunk = function( playerElement, chunkID )
		--Debug.info( "Player streamed in chunk " .. chunkID .. " " .. dumpvar( Chunk.chunks[ chunkID ] ) )
		if ( getElementType( playerElement ) == "player" ) then
			if ( #Herb.herbsByChunks[ chunkID ] ~= 0 ) then
				-- В этом чанке есть растения
				Herb.updateClientChunk( playerElement, chunkID )
			end
		end
	end;
};
addEventHandler( "onResourceStart", resourceRoot, Herb.init )