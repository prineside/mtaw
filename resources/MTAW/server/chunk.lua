--[[
	Чанки - сервер
	
	Работает для педов и игроков
	
	Модуль позволяет разбить объекты в пространстве игрового мира на двухмерные чанки.
	При перемещении игроков модуль будет сообщать о чанках, которые попали или вышли
	из стрима, а также о чанках, на которых непосредственно находятся игроки.
	
	Размер чанка всегда одинаковый. 
	Дистанция стрима указывается в Chunk.streamDistance
	
	Другие модули могут использовать модуль для стриминга сущностей. Пример:
	1. Модуль создает копию массива чанков (пустую) через prepareArray
	2. Модуль создает сущности, получает номера их чанков через getID и использует их
	   как ключи к созданному в п.1 массиву, внося сущности в массив произвольным образом
	   (обычно используя идентификаторы сущностей в качестве ключей подмассива)
	3.1. Модуль реагирует на события для получения чанков в радиусе прорисовки и соответственно 
	   загружает / выгружает сущности
	3.2. Либо берет массив чанков в стриме (streamedInChunks)
--]]
--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Chunk.onStreamIn", false ) 			-- Игрок застримил чанк - чанк находится в квадрате с размерами, минимально необходимыми для того, чтобы охватить радиус прорисовки из настроек. Вызывается также при изменении настройки дальности прорисовки ( number streamedInChunk )
addEvent( "Chunk.onStreamOut", false ) 			-- Игрок перестал стримить чанк, см. обратное событие ( number streamedOutChunk )

--------------------------------------------------------------------------------
--<[ Модуль Chunk ]>------------------------------------------------------------
--------------------------------------------------------------------------------
Chunk = {
	size = 200;					-- Размер чанка, должен нацело делить maxX и minX
	streamOutTolerance = 50;	-- Расстояние (м) от радиуса прорисовки, при котором чанк выходит из стрима (при 0 чанк выходит из стрима, как только окажется полностью вне радиуса прорисовки)
	mapBoundaries = {
		minX = -16000;
		maxX = 16000;
		minY = -16000;
		maxY = 16000;
	};
	
	_maxStreamerIterationTime = 5;	-- Максимальное время (мс) из каждых 50мс, которое стример может обрабатывать чанки беспрерывно (до coroutine.yield)
	streamDistance = 300;		
	
	chunks = {};				-- { chunkID => { minX, minY, { ped => true, ... }, { playerElement => true, ... } }, ... }
	
	chunksInStreamBox = {};		-- Чанки в квадрате стрима (грубо) { chunkID, ... }
	streamedInChunks = {};		-- Чанки в радиусе стрима { playerElement => { chunkID => true } }
	
	_lastStreamPlayerPos = {};	-- Последняя позиция, в которой стример видел игрока { playerElement => { x, y } }
	_lastStreamPlayerChunk = {};-- Последний ID чанка, в которой был игрок { playerElement => chunkID }
	
	init = function()
		if ( 
			( Chunk.mapBoundaries.maxX / Chunk.size ) % 1 ~= 0 
			or ( Chunk.mapBoundaries.maxY / Chunk.size ) % 1 ~= 0 
			or ( Chunk.mapBoundaries.minX / Chunk.size ) % 1 ~= 0 
			or ( Chunk.mapBoundaries.minY / Chunk.size ) % 1 ~= 0 
		) then
			Debug.error( "Chunk size must divide min and max map boundaries without remainder" )
			
			return nil
		end
		
		-- Инициируем шаблон массива чанков и основной массив чанков
		local chunks = {}
		
		Chunk.countX = ( Chunk.mapBoundaries.maxX - Chunk.mapBoundaries.minX ) / Chunk.size
		Chunk.countY = ( Chunk.mapBoundaries.maxY - Chunk.mapBoundaries.minY ) / Chunk.size
		
		if ( Chunk.countX > 65535 ) then
			-- Не влезет в индекс X
			Debug.error( "Chunk X index (" .. Chunk.countX .. ") is out of the limit (65535), make sure ( maxX - minX ) / Chunk.size < 1<<16" )
		end
		
		if ( Chunk.countY > 65535 ) then
			-- Не влезет в индекс Y
			Debug.error( "Chunk Y index (" .. Chunk.countY .. ") is out of the limit (65535), make sure ( maxY - minY ) / Chunk.size < 1<<16" )
		end
		
		local chunkID
		local chunkCount = 0
		for x = Chunk.mapBoundaries.minX, Chunk.mapBoundaries.maxX - 1, Chunk.size do
			for y = Chunk.mapBoundaries.minY, Chunk.mapBoundaries.maxY - 1, Chunk.size do
				chunkID = bitLShift( math.floor( ( x - Chunk.mapBoundaries.minX ) / Chunk.size ), 16 ) + math.floor( ( y - Chunk.mapBoundaries.minX ) / Chunk.size ) -- Из Chunk.getID( x, y ) без проверок
				
				chunks[ chunkID ] = { x, y, {}, {} }
				
				chunkCount = chunkCount + 1
			end
		end
		
		Chunk.chunks = chunks
		
		addEventHandler( "Main.onServerLoad", resourceRoot, Chunk.onServerLoad )
		
		Debug.info( chunkCount .. " chunks loaded (" .. Chunk.countX .. " x " .. Chunk.countY .. ")" )
		
		Main.setModuleLoaded( "Chunk", 1 )
	end;
	
	onServerLoad = function()
		-- Запускаем корутину, которая занимается стримингом чанков
		local streamerCoroutine = coroutine.create( Chunk._streamerCoroutineFunction )
		setTimer( function()
			coroutine.resume( streamerCoroutine, getTickCount() )
		end, 50, 0 )
		
		addEventHandler( "onPlayerQuit", root, Chunk.onPlayerQuit )
	end;
	
	-- Стриминг чанков
	_streamerCoroutineFunction = function( iterTick )
		local pX, pY
		local minChunkX, minChunkY
		local box
		local minChunkX, minChunkY, maxChunkX, maxChunkY
		local dist
		local chunkID
		local chunksInBox
		local streamedInChunks
		local maxDist
		local chunkPlayerIn
		
		local peds = {}
		
		while ( true ) do
			--for _, ped in pairs( Main.loadedPlayers ) do
			-- Собираем игроков и педов в кучу
			peds = {}
			for _, ped in pairs( getElementsByType( "ped" ) ) do
				peds[ #peds + 1 ] = ped
			end
			
			for _, ped in pairs( Main.loadedPlayers ) do
				peds[ #peds + 1 ] = ped
			end
			
			-- Запускаем
			local iterCount = 0
			local pedCount = 0
			for _, ped in pairs( peds ) do
				if ( isElement( ped ) ) then
					pX, pY = getElementPosition( ped )
					
					if ( Chunk._lastStreamPlayerPos[ ped ] == nil ) then
						Chunk._lastStreamPlayerPos[ ped ] = { 0, 0 }
					end
					
					if ( Chunk.streamedInChunks[ ped ] == nil ) then
						Chunk.streamedInChunks[ ped ] = {}
					end
					
					if ( Chunk._lastStreamPlayerPos[ ped ][ 1 ] ~= pX or Chunk._lastStreamPlayerPos[ ped ][ 2 ] ~= pY ) then
						-- Позиция игрока изменилась
						Chunk._lastStreamPlayerPos[ ped ][ 1 ] = pX
						Chunk._lastStreamPlayerPos[ ped ][ 2 ] = pY
						
						-- Сначала получаем квадрат вокруг радиуса стрима и дистанцию к каждому чанку
						box = {
							minX = pX - Chunk.streamDistance - Chunk.size;
							minY = pY - Chunk.streamDistance - Chunk.size;
							maxX = pX + Chunk.streamDistance;
							maxY = pY + Chunk.streamDistance;
						}
						
						for k, v in pairs( box ) do
							if ( v >= Chunk.mapBoundaries.maxY ) then
								box[ k ] = Chunk.mapBoundaries.maxY - 1
							elseif ( v < Chunk.mapBoundaries.minY ) then
								box[ k ] = Chunk.mapBoundaries.minY
							end
						end
						
						minChunkX, minChunkY = Chunk.getBounds( Chunk.getID( box.minX, box.minY ) )
						_, _, maxChunkX, maxChunkY = Chunk.getBounds( Chunk.getID( box.maxX, box.maxY ) )
						
						chunksInBox = {}
						streamedInChunks = {}			-- chunkID => distance
						
						for x = minChunkX, maxChunkX, Chunk.size do
							for y = minChunkY, maxChunkY, Chunk.size do
								chunkID = Chunk.getID( x, y )
								
								if ( chunkID ~= nil ) then
									chunksInBox[ #chunksInBox + 1 ] = chunkID
								
									streamedInChunks[ chunkID ] = Chunk.getDistance( chunkID, pX, pY )
								end
							end
						end
						
						-- Убираем чанки, у которых дистанция от игрока больше Chunk.streamDistance + streamOutTolerance 
						maxDist = Chunk.streamOutTolerance + Chunk.streamDistance
						for chunkID, dist in pairs( streamedInChunks ) do
							if ( dist > maxDist ) then
								streamedInChunks[ chunkID ] = nil
							end
						end
						
						-- Убираем из стрима чанки, которые уже есть в стриме, но которых не будет сейчас
						for chunkID, dist in pairs( Chunk.streamedInChunks[ ped ] ) do
							if ( streamedInChunks[ chunkID ] == nil ) then
								-- Этого чанка не будет в стриме
								triggerEvent( "Chunk.onStreamOut", resourceRoot, ped, chunkID )
								Chunk.streamedInChunks[ ped ][ chunkID ] = nil
							end
						end
						
						-- Добавляем в стрим чанки, которых еще нет, и которые находятся в радиусе Chunk.streamDistance (без streamOutTolerance)
						for chunkID, dist in pairs( streamedInChunks ) do
							if ( Chunk.streamedInChunks[ ped ][ chunkID ] == nil ) then
								-- Этого чанка еще нет в стриме
								if ( dist < Chunk.streamDistance ) then
									-- Будет в стриме
									triggerEvent( "Chunk.onStreamIn", resourceRoot, ped, chunkID )
									Chunk.streamedInChunks[ ped ][ chunkID ] = true
								end
							end
						end
						
						-- Обновляем номер чанка, в котором находится игрок
						chunkPlayerIn = Chunk.getID( pX, pY )
						if ( Chunk._lastStreamPlayerChunk[ ped ] ~= chunkPlayerIn ) then
							-- Игрок в другом чанке
							if ( Chunk._lastStreamPlayerChunk[ ped ] ~= nil ) then
								-- Убираем из списка игроков старого чанка
								Chunk.chunks[ Chunk._lastStreamPlayerChunk[ ped ] ][ 3 ][ ped ] = nil
								Chunk.chunks[ Chunk._lastStreamPlayerChunk[ ped ] ][ 4 ][ ped ] = nil
							end
							
							-- Добавляем в список игроков нового чанка
							Chunk.chunks[ chunkPlayerIn ][ 3 ][ ped ] = true
							if ( Main.loadedPlayerKeys[ ped ] ~= nil ) then
								-- Игрок
								Chunk.chunks[ chunkPlayerIn ][ 4 ][ ped ] = true
							end
							
							Chunk._lastStreamPlayerChunk[ ped ] = chunkPlayerIn
						end
					end
					
					pedCount = pedCount + 1
					
					if ( getTickCount() - iterTick > Chunk._maxStreamerIterationTime ) then
						iterCount = iterCount + 1
						iterTick = coroutine.yield()
					end
				end
			end
			
			--Debug.info( "Chunk stat: " .. iterCount .. " iters, " .. pedCount .. " peds" )
			iterTick = coroutine.yield()
		end
	end;
	
	-- Возвращает дистанцию к чанку от точки (самая короткая дистанция к чанку)
	-- Возвращает 0, если точка находится в чанке
	-- > chunkID number
	-- > x number
	-- > y number
	-- = number distance
	getDistance = function( chunkID, x, y )
		if ( Chunk.chunks[ chunkID ] == nil ) then
			-- Чанк не существует
			return nil
		end
	
		local chunkMinX, chunkMinY, chunkMaxX, chunkMaxY = Chunk.getBounds( chunkID )
		
		local toX, toY
		
		if ( x < chunkMinX ) then
			-- Слева (-x) от чанка
			toX = chunkMinX
		elseif ( x < chunkMaxX ) then
			-- X в границах чанка
			toX = x
		else
			-- Справа (+x) от чанка
			toX = chunkMaxX
		end
		
		if ( y < chunkMinY ) then
			-- Снизу (-y) от чанка
			toY = chunkMinY
		elseif ( y < chunkMaxY ) then
			-- Y в границах чанка
			toY = y
		else
			-- Сверху (+y) от чанка
			toY = chunkMaxY
		end
		
		--dxDrawLine3D( toX, toY, 0, toX, toY, 100, 0xFF0000FF, 15 )
		local dX, dY = x - toX, y - toY
		return math.sqrt( dX * dX + dY * dY )
	end;
	
	-- Возвращает ID чанка, в котором находятся указанные координаты, или nil, если чанк не существует
	-- > x number
	-- > y number
	-- = number / nil chunkID
	getID = function( x, y )
		--[[
		local indexX = math.floor( ( x - Chunk.mapBoundaries.minX ) / Chunk.size )
		local indexY = math.floor( ( y - Chunk.mapBoundaries.minX ) / Chunk.size )
		
		local chunkID = bitLShift( indexX, 16 ) + indexY
		--]]
		
		local chunkID = bitLShift( math.floor( ( x - Chunk.mapBoundaries.minX ) / Chunk.size ), 16 ) + math.floor( ( y - Chunk.mapBoundaries.minX ) / Chunk.size )
		
		if ( Chunk.chunks[ chunkID ] ~= nil ) then
			return chunkID
		else
			return nil
		end
	end;
	
	-- Возвращает границы чанка
	-- > chunkID number - номер чанка
	-- = number minX, number minY, number maxX, number maxY
	getBounds = function( chunkID )
		if not validVar( chunkID, "chunkID", "number" ) then return nil end
	
		if ( Chunk.chunks[ chunkID ] == nil ) then
			-- Чанк не существует
			return nil
		end
		
		local minX = Chunk.chunks[ chunkID ][ 1 ]
		local minY = Chunk.chunks[ chunkID ][ 2 ]
		
		return minX, minY, minX + Chunk.size, minY + Chunk.size
	end;
	
	-- Возвращает таблицу с игроками, которые находятся в указанном чанке
	-- Игроки являются ключами таблицы
	-- > chunkID numner - номер чанка
	-- = table playersInChunk
	getPlayersInChunk = function( chunkID )
		if ( Chunk.chunks[ chunkID ] == nil ) then
			-- Чанк не существует
			return nil
		end
		
		return Chunk.chunks[ chunkID ][ 4 ]
	end;
	
	-- Возвращает таблицу с игроками и педами, которые находятся в указанном чанке
	-- Педы являются ключами таблицы
	-- > chunkID numner - номер чанка
	-- = table playersInChunk
	getPedsInChunk = function( chunkID )
		if ( Chunk.chunks[ chunkID ] == nil ) then
			-- Чанк не существует
			return nil
		end
		
		return Chunk.chunks[ chunkID ][ 3 ]
	end;
	
	-- Возвращает подготовленный массив с индексами - номерами чанков
	-- = table chunkArray
	prepareArray = function()
		local t = {}
		for chunkID in pairs( Chunk.chunks ) do
			t[ chunkID ] = {}
		end
		
		return t
	end;
	
	-- Игрок вышел из сервера
	onPlayerQuit = function()
		local chunkID = Chunk._lastStreamPlayerChunk[ source ]
		if ( chunkID ~= nil ) then
			Chunk.chunks[ chunkID ][ 3 ][ source ] = nil
			Chunk.chunks[ chunkID ][ 4 ][ source ] = nil
		end
	end;
}
addEventHandler( "onResourceStart", resourceRoot, Chunk.init )