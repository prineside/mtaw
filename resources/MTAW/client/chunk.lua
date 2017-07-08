--[[
	Чанки
	
	Модуль позволяет разбить объекты в пространстве игрового мира на двухмерные чанки.
	При перемещении игрока модуль будет сообщать о чанках, которые попали или вышли
	из стрима, а также о чанках, на которых непосредственно находится игрок.
	
	Размер чанка всегда одинаковый. 
	Радиус стрима равен Chunk.streamDistance (зависит от CFG.graphics.farClipDistance)
	
	Другие модули могут использовать модуль для стриминга сущностей. Пример:
	1. Модуль создает копию массива чанков (пустую) через prepareArray
	2. Модуль создает сущности, получает номера их чанков через getID и использует их
	   как ключи к созданному в п.1 массиву, внося сущности в массив произвольным образом
	   (обычно используя идентификаторы сущностей в качестве ключей подмассива)
	3. Модуль реагирует на события для получения чанков в радиусе прорисовки и соответственно 
	   загружает / выгружает сущности
	   
	Формат chunkID: 16 бит - индекс по X, 16 бит - индекс по Y  
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
	streamOutTolerance = 20;	-- Расстояние (м) от радиуса прорисовки, при котором чанк выходит из стрима (при 0 чанк выходит из стрима, как только окажется полностью вне радиуса прорисовки)
	mapBoundaries = {
		minX = -16000;
		maxX = 16000;
		minY = -16000;
		maxY = 16000;
	};
	
	streamDistance = 300;		
	
	arrayTemplate = nil; 		-- Массив с шаблоном, который будет копироваться в prepareArray. Генерируется при инициализации
	chunks = {};				-- { chunkID => { minX, minY }, ... }
	
	chunksInStreamBox = {};		-- Чанки в квадрате стрима (грубо) { chunkID, ... }
	streamedInChunks = {};		-- Чанки в радиусе стрима { chunkID => true }
	
	_lastStreamPlayerPos = {};	-- Последняя позиция, в которой стример видел игрока
	
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
		local arrayTemplate = {}
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
				
				arrayTemplate[ chunkID ] = {}
				chunks[ chunkID ] = { x, y }
				
				chunkCount = chunkCount + 1
			end
		end
		
		Chunk.arrayTemplate = arrayTemplate
		Chunk.chunks = chunks
		
		addEventHandler( "Main.onClientLoad", resourceRoot, Chunk.onClientLoad )
		
		outputDebugString( chunkCount .. " chunks loaded (" .. Chunk.countX .. " x " .. Chunk.countY .. ")" )
		Main.setModuleLoaded( "Chunk", 1 )
		
		--[[ Debug - отрисовка чанков
		addEventHandler( "onClientRender", root, function()
			local camX, camY, camZ = getElementPosition( localPlayer )
			
			camZ = 5
			
			-- Box
			for _, chunkID in pairs( Chunk.chunksInStreamBox ) do
				local minX, minY, maxX, maxY = Chunk.getBounds( chunkID )
				
				for z = -5, 5, 1 do
					dxDrawLine3D( minX, minY, z + camZ, maxX, minY, z + camZ, 0x88FF0000, 5 )
					dxDrawLine3D( minX, minY, z + camZ, minX, maxY, z + camZ, 0x88FF0000, 5 )
					dxDrawLine3D( maxX, maxY, z + camZ, minX, maxY, z + camZ, 0x88FF0000, 5 )
					dxDrawLine3D( maxX, maxY, z + camZ, maxX, minY, z + camZ, 0x88FF0000, 5 )
				end
			end
			
			-- Stream radius
			local lastX, lastY = nil, nil
			for a = 0, 360, 15 do
				local x, y = getCoordsByAngleFromPoint( camX, camY, a, Chunk.streamDistance )
				if ( lastX ~= nil ) then
					for z = -5, 5, 1 do
						dxDrawLine3D( lastX, lastY, z + camZ, x, y, z + camZ, 0x8800FF00, 5 )
					end
				end
				
				lastX, lastY = x, y
			end
			
			-- Streamed in
			for chunkID in pairs( Chunk.streamedInChunks ) do
				local minX, minY, maxX, maxY = Chunk.getBounds( chunkID )
				
				for z = -5, 5, 1 do
					dxDrawLine3D( minX, minY, z + camZ, maxX, minY, z + camZ, 0xFFFFFF00, 5 )
					dxDrawLine3D( minX, minY, z + camZ, minX, maxY, z + camZ, 0xFFFFFF00, 5 )
					dxDrawLine3D( maxX, maxY, z + camZ, minX, maxY, z + camZ, 0xFFFFFF00, 5 )
					dxDrawLine3D( maxX, maxY, z + camZ, maxX, minY, z + camZ, 0xFFFFFF00, 5 )
				end
			end
		end )
		--]]
	end;
	
	onClientLoad = function()
		-- Установим дальность прорисовки
		Chunk.streamDistance = CFG.graphics.farClipDistance;
		
		-- Прослушиваем изменение настройки дальности прорисовки
		addEventHandler( "Settings.onSettingChanged", resourceRoot, function( categoryName, itemName, oldValue, newValue )
			if ( categoryName == "graphics" and itemName == "farClipDistance" ) then
				Chunk.streamDistance = newValue
			end
		end )
		
		-- Запускаем корутину, которая занимается стримингом чанков
		local streamerCoroutine = coroutine.create( Chunk._streamerCoroutineFunction )
		addEventHandler( "onClientRender", root, function()
			coroutine.resume( streamerCoroutine, getTickCount() )
		end )
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
		
		while ( true ) do
			pX, pY = getElementPosition( localPlayer )
			
			if ( Chunk._lastStreamPlayerPos[ 1 ] ~= pX or Chunk._lastStreamPlayerPos[ 2 ] ~= pY ) then
				-- Позиция игрока изменилась
				Chunk._lastStreamPlayerPos[ 1 ] = pX
				Chunk._lastStreamPlayerPos[ 2 ] = pY
				
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
				
				Chunk.chunksInStreamBox = chunksInBox
				
				-- Убираем чанки, у которых дистанция от игрока больше Chunk.streamDistance + streamOutTolerance 
				maxDist = Chunk.streamOutTolerance + Chunk.streamDistance
				for chunkID, dist in pairs( streamedInChunks ) do
					if ( dist > maxDist ) then
						streamedInChunks[ chunkID ] = nil
					end
				end
				
				-- Убираем из стрима чанки, которые уже есть в стриме, но которых не будет сейчас
				for chunkID, dist in pairs( Chunk.streamedInChunks ) do
					if ( streamedInChunks[ chunkID ] == nil ) then
						-- Этого чанка не будет в стриме
						triggerEvent( "Chunk.onStreamOut", resourceRoot, chunkID )
						Chunk.streamedInChunks[ chunkID ] = nil
					end
				end
				
				-- Добавляем в стрим чанки, которых еще нет, и которые находятся в радиусе Chunk.streamDistance (без streamOutTolerance)
				for chunkID, dist in pairs( streamedInChunks ) do
					if ( Chunk.streamedInChunks[ chunkID ] == nil ) then
						-- Этого чанка еще нет в стриме
						if ( dist < Chunk.streamDistance ) then
							-- Будет в стриме
							triggerEvent( "Chunk.onStreamIn", resourceRoot, chunkID )
							Chunk.streamedInChunks[ chunkID ] = true
						end
					end
				end
			end
			
			Debug.debugData.chunkStreamerFrameTime = getTickCount() - iterTick
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
	
	-- Возвращает подготовленный массив с индексами - номерами чанков
	-- = table chunkArray
	prepareArray = function()
		return tableCopy( Chunk.arrayTemplate )
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, Chunk.init )