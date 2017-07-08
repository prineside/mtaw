--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Herb.onPlayerStartTargeting", false )								-- Игрок начал смотреть на растение ( number herbPlaceID )
addEvent( "Herb.onPlayerStopTargeting", false )									-- Игрок перестал смотреть на растение ( number herbPlaceID )
addEvent( "Herb.onPlayerStartInteracting", false )								-- Игрок начал взаимодействовать с растением ( number herbPlaceID )
addEvent( "Herb.onPlayerStopInteracting", false )								-- Игрок перестал взаимодействовать с растением ( number herbPlaceID )

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Herb.onHerbsUpdate", true )											-- Сервер прислал данные об обновленных растениях ( table herbsData )

--------------------------------------------------------------------------------
--<[ Модуль Herb ]>-------------------------------------------------------------
--------------------------------------------------------------------------------
Herb = {
	herbs = {			-- Статус растений (синхронизируется с сервером)
		growPhase = {};		-- ID места => статус роста
		class = {};			-- ID места => ID класса растения
		
		raycastTarget = {};	-- ID места => элемент для рейкаста (на стороне клиента, стримится)
		face = {};			-- ID места => позиция, в которую смотрит куст (tx1, ty1, tx2, ty2)	static
	};
	herbPlacesCount = nil;	-- Количество мест
	
	textures = {};			-- Текстуры растений в зависимости от класса и этапа роста, наполняется при инициализации { classID => { txtPhase1, txtPhase2, ... } }
	
	herbsByChunks = {};		-- ID чанка => { ID места, ID места ... }
	
	targetedHerb = nil;		-- ID места или nil. Растение, на которое целится игрок
	forceRendering = false;	-- Если true, в следующем кадре будут отрисованы текущие растения (корутина завершит итерацию без прерываний, поэтому кадр может отрисовываться немного дольше)
	
	_targetedHerbToRender = nil;	-- ID места или nil. Растение, на которое целится игрок. Отличается от предыдущего тем, что сохраняется до генерации новых данных для отрисовки (чтобы избежать пропадания растения)
	_targetingStartTick = nil;	-- tickCount когда начали смотреть на растение
	
	_herbsToRender = {};	-- Генерируется корутиной, содержит список растений для отрисовки. { material = {}, color = {}, x1 = {}, x2 = {}, y1 = {}, y2 = {}, z1 = {}, z2 = {}, width = {}, tx = {}, ty = {}, tz = {} }
	_herbRenderingColor = { 255, 255, 255, 255 };	-- ARGB Цвет каждого отрисованного растения (меняется на более темный ночью)
	
	-- Генерируются при старте и изменении настроек графики
	_drawingDistance = nil;				-- Дальность отрисовки растений 	
	_drawingDistanceFadeStart = nil;	-- Расстояние, на котором растения становятся прозрачнее
	_detailedDrawingDistance = nil;		-- Дальность отрисовки растений детально
	
	-- То же самое, но в квадрате (чтобы убрать корень в формуле дистанции)
	_drawingDistanceSQR = nil;
	_drawingDistanceFadeStartSQR = nil;
	_detailedDrawingDistanceSQR = nil;
	
	_testTexture = nil;					-- Текстура на время теста (в будущем будет браться из HerbClass)
	_testScale = 1.75;					-- Размер растения на время теста
	
	init = function()
		Herb.herbPlacesCount = #ARR.herbPlaces.x
		
		Main.setModuleLoaded( "Herb", 1 )
		
		addEventHandler( "Main.onClientLoad", root, Herb.onClientLoad )
	end;
	
	onClientLoad = function()
		-- Загружаем текстуры растений
		for classID, classData in pairs( ARR.herbClasses ) do
			Herb.textures[ classID ] = {}
			for phaseID, phaseData in pairs( classData.growPhases ) do
				Herb.textures[ classID ][ phaseID ] = dxCreateTexture( phaseData.texture, "argb", true, "clamp" );
			end
		end
	
		-- Инициализируем herbsByChunks
		Herb.herbsByChunks = Chunk.prepareArray()
		
		-- Инициируем массив растений и заполняем herbsByChunks
		for herbID = 1, Herb.herbPlacesCount do
			Herb.herbs.growPhase[ herbID ] = 0
			Herb.herbs.class[ herbID ] = 0
			
			Herb.herbs.raycastTarget[ herbID ] = false
			
			local angle = math.random( 0, 89 )
			local x, y = ARR.herbPlaces.x[ herbID ], ARR.herbPlaces.y[ herbID ]
			local tx1, ty1 = getCoordsByAngleFromPoint( x, y, angle, 1 )
			local tx2, ty2 = getCoordsByAngleFromPoint( x, y, angle + 90, 1 )
			Herb.herbs.face[ herbID ] = {
				tx1, ty1, tx2, ty2
			}
			
			local chunkID = Chunk.getID( x, y )
			
			table.insert( Herb.herbsByChunks[ chunkID ], herbID )
		end
		
		-- Загружаем дальность прорисовки из настроек
		Herb.setDrawingDistance( CFG.graphics.herbDrawDistance )
	
		-- Прослушиваем изменение настройки
		addEventHandler( "Settings.onSettingChanged", resourceRoot, function( categoryName, itemName, oldValue, newValue )
			if ( categoryName == "graphics" and itemName == "herbDrawDistance" ) then
				Herb.setDrawingDistance( newValue )
			end
		end )
	
		-- Запускаем корутину, которая генерирует массив для отрисовки и raycastTargetы
		local renderDataGeneratorCoroutine = coroutine.create( Herb._generateRenderData )
		local ets = {}
		local etp = 1
		addEventHandler( "onClientPreRender", root, function()
			-- coroutine.resume( renderDataGeneratorCoroutine, getTickCount() )
			-- Debug
			local _st = getTickCount()
			coroutine.resume( renderDataGeneratorCoroutine, getTickCount() )
			local et = getTickCount() - _st
			ets[ etp ] = et
			etp = etp + 1
			if ( etp == 46 ) then
				etp = 1
				
				local avg = 0
				for i = 1, 45 do
					avg = avg + ets[ i ]
				end
				avg = avg / 45
				
				Debug.debugData.herbAvgCorIterTime = math.floor( avg * 100 ) / 100
			end
		end )
		
		-- Отрисовываем растения
		addEventHandler( "onClientRender", root, Herb.onClientRender )
		
		-- Слушаем сервер на предмет изменения данных о растениях
		addEventHandler( "Herb.onHerbsUpdate", resourceRoot, Herb.onServerUpdateHerbs )
		
		-- Обрабатываем прицел игрока на растении
		addEventHandler( "Herb.onPlayerStartTargeting", resourceRoot, function( herbID )
			-- Начал смотреть на растение
			Herb.targetedHerb = herbID
			Herb._targetedHerbToRender = herbID
			Herb._targetingStartTick = getTickCount()
			
			Herb._handleCrosshairLabel()
		end, false, "high+9001" )
		
		addEventHandler( "Herb.onPlayerStopTargeting", resourceRoot, function( herbID )
			-- Перестал смотреть на растение
			Herb.targetedHerb = nil
				
			Crosshair.removeLabel()
		end, false, "high+9001" )
		
		addEventHandler( "Inventory.onActiveSlotChanged", resourceRoot, function()
			-- Изменился активный слот инвентаря - меняем label в зависимости от того, выбран herbDisruptor или нет
			Herb._handleCrosshairLabel()
		end, false )
	end;
	
	-- Обновить текст подсказки Crosshair в зависимости от targetedHerb и других факторов
	_handleCrosshairLabel = function()
		if ( Herb.targetedHerb ~= nil ) then
			local herbClass = Herb.herbs.class[ Herb.targetedHerb ]
					
			if ( herbClass ~= 0 ) then
				-- Растение есть
				local activeStack = Inventory.getActiveFastSlotItemStack()
				if ( activeStack == nil or not activeStack:getItem():hasTag( 'herbDisruptor' ) ) then
					-- Вещи нет или это не herbDisruptor
					Crosshair.setLabel( "Нет инструмента", "Необходим серп", nil, false, "NO" )
					-- Crosshair.removeLabel()
				else
					-- Вещь есть и это herbDisruptor
					Crosshair.setLabel( "Срезать", ARR.herbClasses[ herbClass ].name, nil, true, "LMB" )
				end
			end
		end
	end;
	
	-- Установить максимальную дальность отрисовки растений
	-- > drawingDistance number - расстояние (минимум 30)
	-- = void
	setDrawingDistance = function( drawingDistance )
		if not validVar( drawingDistance, "drawingDistance", "number" ) then return nil end
	
		Herb._drawingDistance = drawingDistance
		Herb._drawingDistanceFadeStart = drawingDistance * 0.5
		Herb._detailedDrawingDistance = drawingDistance * 0.1
		
		if ( Herb._detailedDrawingDistance < 15 ) then
			Herb._detailedDrawingDistance = 15
		elseif ( Herb._detailedDrawingDistance > 30 ) then
			Herb._detailedDrawingDistance = 30
		end	
		
		Herb._drawingDistanceSQR = Herb._drawingDistance * Herb._drawingDistance
		Herb._drawingDistanceFadeStartSQR = Herb._drawingDistanceFadeStart * Herb._drawingDistanceFadeStart
		Herb._detailedDrawingDistanceSQR = Herb._detailedDrawingDistance * Herb._detailedDrawingDistance
	end;
	
	-- Корутина, которая генерирует данные для отрисовки
	_generateRenderData = function( iterTick )
		while ( true ) do
			local yieldCount = 0
			
			local camX, camY, camZ = getCameraMatrix()
			local plrX, plrY, plrZ = getElementPosition( localPlayer )
			
			local r, g, b, a = Herb._herbRenderingColor[ 1 ], Herb._herbRenderingColor[ 2 ], Herb._herbRenderingColor[ 3 ], Herb._herbRenderingColor[ 4 ]
			local scale = Herb._testScale
			
			local lightIntensity = Environment.getDayLightIntensity() * 0.55 + 0.25
			r = r * lightIntensity
			g = g * lightIntensity
			b = b * lightIntensity
			local opaqueColor = tocolor( r, g, b, a )
			
			local renderData = {
				material = {};
				x1 = {};
				x2 = {};
				y1 = {};
				y2 = {};
				z1 = {};
				z2 = {};
				width = {};
				ty = {};
				tx = {};
				tz = {};
				color = {};
			}
			
			local idx = 1
			
			local pdX, pdY, pdZ
			
			local iter = 0
			
			local streamedInChunks = tableCopy( Chunk.streamedInChunks )
			
			for chunkID in pairs( streamedInChunks ) do
				for _, herbID in pairs( Herb.herbsByChunks[ chunkID ] ) do
					if ( Herb.herbs.class[ herbID ] ~= 0 ) then
						-- Есть растение
						local isHovered = Herb.targetedHerb == herbID	-- true, если выделено
		
						iter = iter + 1
						
						local bx = ARR.herbPlaces.x[ herbID ]
						local by = ARR.herbPlaces.y[ herbID ]
						local bz = ARR.herbPlaces.z[ herbID ]
						
						local raycastTarget = Herb.herbs.raycastTarget[ herbID ]
						
						--local distanceToCamera = getDistanceBetweenPoints3D( bx, by, bz, camX, camY, camZ )
						pdX, pdY, pdZ = bx - camX, by - camY, bz - camZ
						local distanceToCamera = pdX * pdX + pdY * pdY + pdZ * pdZ
						
						--local distanceToPlayer = getDistanceBetweenPoints3D( bx, by, bz, plrX, plrY, plrZ )
						pdX, pdY, pdZ = bx - plrX, by - plrY, bz - plrZ
						local distanceToPlayer = pdX * pdX + pdY * pdY + pdZ * pdZ
						
						if ( distanceToCamera < Herb._drawingDistanceSQR ) then		
							-- В радиусе видимости
							if ( getScreenFromWorldPosition( bx, by, bz + scale, 0.3, true ) ~= false ) then
								-- Видим на экране
								if ( Herb.herbs.class[ herbID ] == nil ) then
									Debug.error( "Class is not defined for herb " .. herbID  )
									
									return nil
								end
								
								if ( Herb.textures[ Herb.herbs.class[ herbID ] ] == nil ) then
									Debug.error( "Texture for herb class " .. Herb.herbs.class[ herbID ] .. " not loaded" )
									
									return nil
								end
								
								
								if ( not isHovered ) then
									-- Обычное растение (не выделено). Выделенное растение будет обрабатываться в onClientRender
									local texture = Herb.textures[ Herb.herbs.class[ herbID ] ][ Herb.herbs.growPhase[ herbID ] ]
									
									if ( distanceToCamera < Herb._detailedDrawingDistanceSQR ) then
										-- Детально
										local tx1, ty1 = Herb.herbs.face[ herbID ][ 1 ], Herb.herbs.face[ herbID ][ 2 ]
										local tx2, ty2 = Herb.herbs.face[ herbID ][ 3 ], Herb.herbs.face[ herbID ][ 4 ]
										
										-- Смотрит на +y
										renderData.material[ idx ] = texture
										renderData.x1[ idx ] = bx
										renderData.x2[ idx ] = bx
										renderData.y1[ idx ] = by
										renderData.y2[ idx ] = by
										renderData.z1[ idx ] = bz + scale
										renderData.z2[ idx ] = bz
										renderData.width[ idx ] = scale
										renderData.tx[ idx ] = tx1
										renderData.ty[ idx ] = ty1
										renderData.tz[ idx ] = bz
										renderData.color[ idx ] = opaqueColor
										
										idx = idx + 1
										
										-- Смотрит на +x
										renderData.material[ idx ] = texture
										renderData.x1[ idx ] = bx + 0.001
										renderData.x2[ idx ] = bx + 0.001
										renderData.y1[ idx ] = by
										renderData.y2[ idx ] = by
										renderData.z1[ idx ] = bz + scale
										renderData.z2[ idx ] = bz
										renderData.width[ idx ] = scale
										renderData.tx[ idx ] = tx2
										renderData.ty[ idx ] = ty2
										renderData.tz[ idx ] = bz
										renderData.color[ idx ] = opaqueColor
										
										idx = idx + 1
										
										-- Колизия для CrosshairTarget
										if ( distanceToPlayer < 5 ) then
											-- Рядом - создаем колизию
											if ( raycastTarget == false ) then
												raycastTarget = RaycastTarget.create( "sphere", "medium", bx, by, bz, Dimension.get( "Global" ) )
												Herb.herbs.raycastTarget[ herbID ] = raycastTarget
												
												addEventHandler( "CrosshairTarget.onTargetingStart", raycastTarget, function()
													triggerEvent( "Herb.onPlayerStartTargeting", resourceRoot, herbID )
												end )
												
												addEventHandler( "CrosshairTarget.onTargetingStop", raycastTarget, function()
													triggerEvent( "Herb.onPlayerStopTargeting", resourceRoot, Herb.targetedHerb )
												end )
												
												addEventHandler( "CrosshairTarget.onInteractionStart", raycastTarget, function()
													triggerEvent( "Herb.onPlayerStartInteracting", resourceRoot, herbID )
												end )
												
												addEventHandler( "CrosshairTarget.onInteractionStop", raycastTarget, function()
													triggerEvent( "Herb.onPlayerStopInteracting", resourceRoot, Herb.targetedHerb )
												end )
											end
										else
											-- Слишком далеко
											if ( raycastTarget ~= false ) then
												RaycastTarget.destroy( raycastTarget )
												Herb.herbs.raycastTarget[ herbID ] = false
											end
										end
									else
										-- Не детальный
										local alpha = 255
										if ( distanceToCamera > Herb._drawingDistanceFadeStartSQR ) then
											alpha = alpha - ( distanceToCamera - Herb._drawingDistanceFadeStartSQR ) / ( Herb._drawingDistanceSQR - Herb._drawingDistanceFadeStartSQR ) * 255
										end
										
										renderData.material[ idx ] = texture
										renderData.x1[ idx ] = bx
										renderData.x2[ idx ] = bx
										renderData.y1[ idx ] = by
										renderData.y2[ idx ] = by
										renderData.z1[ idx ] = bz + scale
										renderData.z2[ idx ] = bz
										renderData.width[ idx ] = scale
										renderData.color[ idx ] = bitAnd( opaqueColor, 0xFFFFFF ) + bitLShift( alpha, 24 )
										
										idx = idx + 1
										
										-- Убираем колизию
										if ( raycastTarget ~= false ) then
											RaycastTarget.destroy( raycastTarget )
											Herb.herbs.raycastTarget[ herbID ] = false
										end
									end
								end
							else
								-- Не видно на экране
								
								-- Убираем колизию
								if ( raycastTarget ~= false ) then
									RaycastTarget.destroy( raycastTarget )
									Herb.herbs.raycastTarget[ herbID ] = false
								end
							end
						else
							-- Вне радиуса видимости
								
							-- Убираем колизию
							if ( raycastTarget ~= false ) then
								RaycastTarget.destroy( raycastTarget )
								Herb.herbs.raycastTarget[ herbID ] = false
							end
						end
							
						if ( not Herb.forceRendering and getTickCount() - iterTick > 2 ) then
							-- Выполняется больше 2мс
							yieldCount = yieldCount + 1
							
							iterTick = coroutine.yield()
						end
					else
						-- Растения нет
					end
				end
			end
		
			if ( Herb.targetedHerb == nil ) then
				-- Убираем отрисовку выделения растения
				Herb._targetedHerbToRender = nil
			end
			
			-- Передаем данные на отрисовку
			Herb._herbsToRender = renderData
			
			--Debug.debugData.herbRenderBakeYields = yieldCount
			--Debug.debugData.herbGeneratorIterations = iter
			
			Herb.forceRendering = false
			
			iterTick = coroutine.yield()
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Отрисовка одного кадра
	onClientRender = function()
		-- Рисуем растения
		if ( Herb._herbsToRender.material ~= nil ) then
			local maxIdx = #Herb._herbsToRender.material
			
			Debug.debugData.herbPartsRendered = maxIdx
			
			if ( maxIdx ~= 0 ) then
				-- Есть растения для отрисовки
				local d = Herb._herbsToRender
				for idx = 1, maxIdx do
					dxDrawMaterialLine3D( d.x1[ idx ], d.y1[ idx ], d.z1[ idx ], d.x2[ idx ], d.y2[ idx ], d.z2[ idx ], d.material[ idx ], d.width[ idx ], d.color[ idx ], d.tx[ idx ], d.ty[ idx ], d.tz[ idx ] )
				end
			end
		end
		
		-- Рисуем выделенное растение, если оно есть
		if ( Herb._targetedHerbToRender ~= nil ) then
			-- Выделено какое-то место для растения
			local herbID = Herb._targetedHerbToRender
			
			local herbClass = Herb.herbs.class[ herbID ]
			if ( herbClass ~= 0 ) then
				-- Есть растение
				local x, y, z = ARR.herbPlaces.x[ herbID ], ARR.herbPlaces.y[ herbID ], ARR.herbPlaces.z[ herbID ]
				
				local tx1, ty1 = Herb.herbs.face[ herbID ][ 1 ], Herb.herbs.face[ herbID ][ 2 ]
				local tx2, ty2 = Herb.herbs.face[ herbID ][ 3 ], Herb.herbs.face[ herbID ][ 4 ]
				
				local lightIntensity = Environment.getDayLightIntensity() * 0.55 + 0.25
				local c = Herb._herbRenderingColor[ 1 ] * lightIntensity
				
				local phase = math.sin( ( getTickCount() - Herb._targetingStartTick ) / 100 )
				c = math.floor( c + ( 255 - c ) * ( ( phase + 1 ) / 2 ) )
				
				local color = tocolor( c, c, c, 255 )
				
				dxDrawMaterialLine3D( x, y, z + Herb._testScale, x, y, z, Herb.textures[ herbClass ][ Herb.herbs.growPhase[ herbID ] ], Herb._testScale, color, tx1, ty1, 0 )
				dxDrawMaterialLine3D( x + 0.001, y + 0.001, z + Herb._testScale, x, y, z, Herb.textures[ herbClass ][ Herb.herbs.growPhase[ herbID ] ], Herb._testScale, color, tx2, ty2, 0 )
			end
		end
	end;
	
	-- Сервер прислал данные о растениях
	onServerUpdateHerbs = function( herbsData )
		--Debug.info( "Новые данные о растениях:", herbsData )
		
		local herbID, herbClass, growPhase
		
		for _, herbData in pairs( herbsData ) do
			herbID = bitAnd( bitRShift( herbData, 12 ), 0xFFFFF )
			herbClass = bitAnd( bitRShift( herbData, 4 ), 0xFF )
			growPhase = bitAnd( herbData, 0xF )
			
			Herb.herbs.class[ herbID ] = herbClass
			Herb.herbs.growPhase[ herbID ] = growPhase
			
			if ( Herb.targetedHerb == herbID ) then
				-- На это растение смотрит игрок
				Herb._handleCrosshairLabel()
			end
		end
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Herb.init )