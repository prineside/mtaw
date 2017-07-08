-- TODO выгружать старые текстуры аватарок из памяти (жрут понемногу видеопамять)
--[[
	avatarAlias = txxxxxxxx, где t - номер шаблона (hex), 8x - цвета сегментов
--]]
--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Avatar.onServerResponseAvatarNames", true )			-- Сервер ответил на запрос списка имен аватарок ( characterID, avatarNames )

--------------------------------------------------------------------------------
--<[ Модуль Avatar ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
Avatar = {
	template = nil;					-- Спрайт со всеми шаблонами
	smallTemplate = nil;					-- // --
	
	avatars = {};					-- avatarAlias => texture
	smallAvatars = {};				-- // --
	
	_renderData = nil;				-- таблица - генерируется в coroutine, используется в onClientRender
	_renderDataGeneratorCoroutine = nil; -- coroutine, генерирующая _renderData
	_renderDataGeneratorCoroutineTimeout = 2;	-- Таймаут (мс) корутины, генерирующей данные для рендеринга
	
	-- Настройки генератора
	generatorColorIndices = {  													-- символ из alias => цвет
		["0"] = 0xF55146;	-- красный
		["1"] = 0xFEB164;	-- оранжевый
		["2"] = 0xFEFD64;	-- желтый
		["3"] = 0x65FE64;	-- зеленый
		["4"] = 0x4BDCFC;	-- голубой
		["5"] = 0x6462FE;	-- синий
		["6"] = 0xC168FA;	-- фиолетовый
		["7"] = 0x000000;	-- серый (неизвестный)
	};
	generatorSegmentColors = {													-- цвет из шаблона => номер сегмента
		0xF55146,			-- красный
		0xFEB164,			-- оранжевый
		0xFEFD64,			-- желтый
		0x65FE64,			-- зеленый
		0x4BDCFC,			-- голубой
		0x6462FE,			-- синий
		0xC168FA,			-- фиолетовый
		0x808080			-- серый
	};
	generatorAvatarSize = 64;
	generatorSmallAvatarSize = 32;
	
	generatorTemplateColorPadding = 13;											-- Количество пикселей с каждой стороны шаблона, в которых нет цветов (где нечего заменять)
	generatorSmallTemplateColorPadding = 6;										-- // --
	
	renderingAvatar = nil;			-- test
	
	avatarNames = {};			-- Имена, которые назначил игрок аватаркам (avatarAlias => name)
	
	nameDrawDistance = 20;		-- Максимальная дальность отрисовки имени аватарок (-10% на плавное исчезновение имени)
	nameDrawFadeStart = 0.8;	-- Расстояние (коэфициент nameDrawDistance) на котором имя начинает ставать прозрачным
	
	avatarDrawDistance = 60;	-- Максимальная дальность отрисовки аватарок (-10% на плавное исчезновение аватарки)
	avatarDrawFadeStart = 0.8;	-- Расстояние (коэфициент avatarDrawDistance) на котором аватар начинает ставать прозрачным
	
	streamedPedAvatars = {};	-- ped персонаж в стриме => texture текстура аватарки
	
	init = function()
		-- Загружаем текстуру шаблонов аватарок
		Avatar.template = dxCreateTexture( "client/data/avatar/template.png" )
		Avatar.smallTemplate = dxCreateTexture( "client/data/avatar/template-small.png" )
		
		addEventHandler( "onClientRender", root, function()
			if ( Avatar.renderingAvatar ~= nil ) then
				dxDrawImage( 0, 240, Avatar.generatorAvatarSize, Avatar.generatorAvatarSize, Avatar.renderingAvatar )
			end
		end )
		
		addEventHandler( "Main.onClientLoad", resourceRoot, Avatar.onClientLoad )
		
		-- Когда был выбран персонаж, запрашиваем из сервера имена аватарок
		addEventHandler( "Character.onCharacterChange", resourceRoot, Avatar.onCharacterChange )
		
		-- Сервер прислал список имен аватарок текущего персонажа
		addEventHandler( "Avatar.onServerResponseAvatarNames", resourceRoot, Avatar.onServerResponseAvatarNames )
		
		-- При стриме игроков начинаем отрисовывать их аватарки над головой
		addEventHandler( "onClientElementStreamIn", root, Avatar.onElementStreamIn )
		addEventHandler( "onClientElementStreamOut", root, Avatar.onElementStreamOut )
		
		-- Генерируем данные для отрисовки ( processLineOfSight, дистанция и порядок отрисовки )
		Avatar._renderDataGeneratorCoroutine = coroutine.create( Avatar._prepareRenderDataCoroutineFunction )
		
		-- Отрисовываем аватарки
		local drawAvatarCoroutineFunction
		local ets = {}
		local etp = 1
		drawAvatarCoroutineFunction = function()
			--
			local status = coroutine.resume( Avatar._renderDataGeneratorCoroutine, getTickCount() )
			if ( not status ) then
				removeEventHandler( "onClientRender", root, drawAvatarCoroutineFunction )
			end
			--]]
			
			--[[ Debug
			local _st = getTickCount()
			coroutine.resume( Avatar._renderDataGeneratorCoroutine, getTickCount() )
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
				
				Debug.debugData.avatarAvgCorIterTime = math.floor( avg * 100 ) / 100
			end
			--]]
		end
		addEventHandler( "onClientRender", root, drawAvatarCoroutineFunction )
		addEventHandler( "onClientRender", root, Avatar.onClientRender )
	end;
	
	onClientLoad = function()
		Command.add( "test-avatar", "none", "[]", "Тест генерации аватарок", function( cmd )
			local iterCount = 100
			local _st = getTickCount()
			for j = 1, iterCount do
				local avatarAlias = decimalToHex( math.random( 0, 13 ) )
				
				for i = 1,8 do
					avatarAlias = avatarAlias .. decimalToHex( math.random( 0, 6 ) )
				end
				Avatar.renderingAvatar = Avatar.getNormalAvatarTexture( avatarAlias )
			end
			
			Chat.addMessage( ( getTickCount() - _st ) .. "ms - сгенерировано " .. iterCount .. " аватарок, последняя: " .. tostring( Avatar.renderingAvatar ), "success" )
		end )
	end;
	
	-- Получить назначенное имя по алиасу аватарки или nil
	-- > avatarAlias string
	-- = string / nil characterName
	getNameByAlias = function( avatarAlias )
		return Avatar.avatarNames[ avatarAlias ]
	end;
	
	-- Получить назначенное имя по элементу игрока или nil
	-- > playerElement player
	-- = string / nil characterName
	getNameByPlayerElement = function( playerElement )
		return Avatar.avatarNames[ getElementData( playerElement, "Avatar.alias" ) ]
	end;
	
	-- Возвращает путь к изображению аватарки (относительно index.html), не проверяя существования файла
	-- > avatarAlias string
	-- > size string / nil - размер аватарки (normal / small), по умолчанию normal
	-- = string avatarFilePath
	getImagePath = function( avatarAlias, size )
		local templateCharacter = avatarAlias:sub( 1, 1 )
		local segmentCharacters = avatarAlias:sub( 2 )
			
		if ( size == nil or size == "normal" ) then
			if ( not fileExists( "client/data/avatar/textures/" .. templateCharacter .. "/" .. segmentCharacters .. ".png" ) ) then
				Avatar.getNormalAvatarTexture( avatarAlias )
			end
			
			return "../avatar/textures/" .. templateCharacter .. "/" .. segmentCharacters .. ".png"
		else
			if ( not fileExists( "client/data/avatar/textures_small/" .. templateCharacter .. "/" .. segmentCharacters .. ".png" ) ) then
				Avatar.getSmallAvatarTexture( avatarAlias )
			end
			
			return "../avatar/textures_small/" .. templateCharacter .. "/" .. segmentCharacters .. ".png"
		end
	end;
	
	-- Возвращает alias аватарки игрока или false
	-- > playerElement player
	-- = string avatarAlias
	getAlias = function( playerElement )
		return getElementData( playerElement, "Avatar.alias" )
	end;
	
	-- Получить текстуру аватарки (или сгенерировать), в нормальном размере (64)
	-- > avatarAlias string - строка в формате tcccccccc
	-- = texture avatarTexture
	getNormalAvatarTexture = function( avatarAlias )
		if not validVar( avatarAlias, "avatarAlias", "string" ) then return nil end
		
		if ( Avatar.avatars[ avatarAlias ] == nil ) then
			-- Текстура еще не загружена, ищем файл
			local templateCharacter = avatarAlias:sub( 1, 1 )
			local segmentCharacters = avatarAlias:sub( 2 )
			if ( fileExists( "client/data/avatar/textures/" .. templateCharacter .. "/" .. segmentCharacters .. ".png" ) ) then
				-- Текстура уже сгенерирована, загружаем из файла
				Avatar.avatars[ avatarAlias ] = dxCreateTexture( "client/data/avatar/textures/" .. templateCharacter .. "/" .. segmentCharacters .. ".png" )
			else
				-- Текстура еще не сгенерирована, генерируем
				local avatarTexture = Avatar.generateAvatar( avatarAlias, "normal" )
				local pixels = dxGetTexturePixels( avatarTexture, 0, 0, Avatar.generatorAvatarSize, Avatar.generatorAvatarSize )
				
				local h = fileCreate( "client/data/avatar/textures/" .. templateCharacter .. "/" .. segmentCharacters .. ".png" )
				fileWrite( h, dxConvertPixels( pixels, "png" ) )
				fileClose( h )
				
				Avatar.avatars[ avatarAlias ] = avatarTexture
			end
		end
		
		return Avatar.avatars[ avatarAlias ]
	end;
	
	-- Получить текстуру аватарки (или сгенерировать), в маленьком размере (32) без темного фона
	-- > avatarAlias string - строка в формате tcccccccc
	-- = texture avatarTexture
	getSmallAvatarTexture = function( avatarAlias )
		if ( Avatar.smallAvatars[ avatarAlias ] == nil ) then
			-- Текстура еще не загружена, ищем файл
			local templateCharacter = avatarAlias:sub( 1, 1 )
			local segmentCharacters = avatarAlias:sub( 2 )
			if ( fileExists( "client/data/avatar/textures_small/" .. templateCharacter .. "/" .. segmentCharacters .. ".png" ) ) then
				-- Текстура уже сгенерирована, загружаем из файла
				Avatar.smallAvatars[ avatarAlias ] = dxCreateTexture( "client/data/avatar/textures_small/" .. templateCharacter .. "/" .. segmentCharacters .. ".png" )
			else
				-- Текстура еще не сгенерирована, генерируем
				local avatarTexture = Avatar.generateAvatar( avatarAlias, "small" )
				local pixels = dxGetTexturePixels( avatarTexture, 0, 0, Avatar.generatorSmallAvatarSize, Avatar.generatorSmallAvatarSize )
				
				local h = fileCreate( "client/data/avatar/textures_small/" .. templateCharacter .. "/" .. segmentCharacters .. ".png" )
				fileWrite( h, dxConvertPixels( pixels, "png" ) )
				fileClose( h )
				
				Avatar.smallAvatars[ avatarAlias ] = avatarTexture
			end
		end
		
		return Avatar.smallAvatars[ avatarAlias ]
	end;
	
	-- Возвращает текстуру аватарки, созданную заново
	-- > avatarAlias string
	-- > size string / nil - small (32) или normal (64), по умолчанию normal
	-- = texture avatarTexture
	generateAvatar = function( avatarAlias, size )
		if not validVar( avatarAlias, "avatarAlias", "string" ) then return nil end
		
		if ( avatarAlias:len() ~= 9 ) then
			Debug.error( "Длина алиаса не равна 9 символов:", avatarAlias )
			return nil
		end
	
		if ( size == nil ) then size = "normal" end
		
		-- Генерируем таблицу преобразования индексного цвета в цвет аватарки
		local colorReplacements = {}											-- цвет на шаблоне => будущий цвет аватарки
		
		for aliasPointer = 2, 9 do
			local aliasChar = avatarAlias:sub( aliasPointer, aliasPointer )
			colorReplacements[ Avatar.generatorSegmentColors[ aliasPointer - 1 ] ] = Avatar.generatorColorIndices[ aliasChar ]
		end
		
		if ( size == "small" ) then
			-- Малый размер
			-- Получаем текстуру шаблона
			local templateNumber = avatarAlias:sub( 1, 1 )
			local templatePixels = dxGetTexturePixels( Avatar.smallTemplate, 0, tonumber( templateNumber, 16 ) * Avatar.generatorSmallAvatarSize, Avatar.generatorSmallAvatarSize, Avatar.generatorSmallAvatarSize )
			
			if ( templatePixels == false ) then
				Debug.error( "Не получилось взять пиксели для малой аватарки", avatarAlias, Avatar.smallTemplate, templateNumber )
				return nil
			end
			
			-- Заменяем цвета
			local minIdx = Avatar.generatorSmallTemplateColorPadding
			local maxIdx = Avatar.generatorSmallAvatarSize - 1 - Avatar.generatorSmallTemplateColorPadding
			for x = minIdx, maxIdx do
				for y = minIdx, maxIdx do
					local r, g, b, a = dxGetPixelColor( templatePixels, x, y )
					local rgb = 0 
					rgb = bitReplace( rgb, r, 16, 8 )
					rgb = bitReplace( rgb, g, 8, 8 )
					rgb = bitReplace( rgb, b, 0, 8 )
					
					if ( colorReplacements[ rgb ] ~= nil ) then
						--Debug.warn( decimalToHex( rgb ) .. " Exists" )
						local targetRgb = colorReplacements[ rgb ]
						local tr = bitExtract( targetRgb, 16, 8 )
						local tg = bitExtract( targetRgb, 8, 8 )
						local tb = bitExtract( targetRgb, 0, 8 )
						dxSetPixelColor( templatePixels, x, y, tr, tg, tb )
					end
				end
			end
			
			-- Возвращаем текстуру
			return dxCreateTexture( templatePixels, "argb", true, "clamp" )
		elseif ( size == "normal" ) then
			-- Обычный размер
			-- Получаем текстуру шаблона
			local templateNumber = avatarAlias:sub( 1, 1 )
			local templatePixels = dxGetTexturePixels( Avatar.template, 0, tonumber( templateNumber, 16 ) * Avatar.generatorAvatarSize, Avatar.generatorAvatarSize, Avatar.generatorAvatarSize )
			
			if ( templatePixels == false ) then
				Debug.error( "Не получилось взять пиксели", avatarAlias, Avatar.template, templateNumber )
				return nil
			end
			
			-- Заменяем цвета
			local minIdx = Avatar.generatorTemplateColorPadding
			local maxIdx = Avatar.generatorAvatarSize - 1 - Avatar.generatorTemplateColorPadding
			for x = minIdx, maxIdx do
				for y = minIdx, maxIdx do
					local r, g, b, a = dxGetPixelColor( templatePixels, x, y )
					local rgb = 0 
					rgb = bitReplace( rgb, r, 16, 8 )
					rgb = bitReplace( rgb, g, 8, 8 )
					rgb = bitReplace( rgb, b, 0, 8 )
					
					if ( colorReplacements[ rgb ] ~= nil ) then
						--Debug.warn( decimalToHex( rgb ) .. " Exists" )
						local targetRgb = colorReplacements[ rgb ]
						local tr = bitExtract( targetRgb, 16, 8 )
						local tg = bitExtract( targetRgb, 8, 8 )
						local tb = bitExtract( targetRgb, 0, 8 )
						dxSetPixelColor( templatePixels, x, y, tr, tg, tb )
					end
				end
			end
			
			-- Возвращаем текстуру
			return dxCreateTexture( templatePixels, "argb", true, "clamp" )
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Подготовка данных для отрисовки
	-- Вычисляет дистанцию, порядок и проверяет LOS
	-- Вызывается через coroutine
	_prepareRenderDataCoroutineFunction = function( iterStartTick )
		while ( true ) do
			local camX, camY, camZ = getCameraMatrix()
			
			-- Сортируем педов (сначала рисуем дальних, потом ближних)
			local distToPed = {}
			for ped, avatarAlias in pairs( Avatar.streamedPedAvatars ) do
				local pedX, pedY, pedZ = getPedBonePosition( ped, 8 )
				local dist = getDistanceBetweenPoints2D( camX, camY, pedX, pedY )
				
				if ( dist < Avatar.avatarDrawDistance ) then
					-- Игрок в радиусе видимости
					local hit, _, _, _, hitElement = processLineOfSight( camX, camY, camZ, pedX, pedY, pedZ, true, true, true, true, true, false, false, false, nil )
					
					if ( not hit or hitElement == ped ) then
						-- Ничто не мешает увидеть игрока или педа
						if ( distToPed[ dist ] == nil ) then
							distToPed[ dist ] = ped
						else
							-- Если точно на таком же расстоянии уже есть пед, подбираем новое
							local newDist = dist + 0.0005
							while ( distToPed[ newDist ] ~= nil ) do
								newDist = newDist + 0.0005
							end
							distToPed[ newDist ] = ped
						end
					end
				end
				
				if ( getTickCount() - iterStartTick > Avatar._renderDataGeneratorCoroutineTimeout ) then
					-- Прошло больше Nмс с момента запуска корутины, отдаем управление
					iterStartTick = coroutine.yield()
				end
			end
			
			local keys = {}
			for k in pairs( distToPed ) do keys[ #keys + 1 ] = k end
			table.sort( keys, function( a, b ) return a > b end )
			
			Avatar._renderData = {
				sortedDist = keys;
				distToPed = distToPed;
			}
			
			iterStartTick = coroutine.yield()
		end
	end;
	
	-- Отрисовка аватарок
	onClientRender = function()
		if ( Avatar._renderData == nil ) then 
			return nil	-- Данные для отрисовки еще не сгенерировались
		end
	
		local colorByBrightness = 255 * CFG.gameplay.avatarBrightness
						
		-- Отрисовка аватарок над головой у педов и игроков, от самых дальних до ближних
		local camX, camY, camZ = getCameraMatrix()
		
		local sortedDist = Avatar._renderData.sortedDist
		local distToPed = Avatar._renderData.distToPed
		
		local drawnAvatarCount = 0
		
		for _, dist in ipairs( sortedDist ) do
			local ped = distToPed[ dist ]
			if ( isElement( ped ) and Avatar.streamedPedAvatars[ ped ] ~= nil ) then
				local avatarAlias = Avatar.streamedPedAvatars[ ped ]
				local avatarTexture = Avatar.getNormalAvatarTexture( avatarAlias )
				local pedX, pedY, pedZ = getPedBonePosition( ped, 8 )
				
				if ( pedZ ~= nil ) then
					local screenX, screenY = getScreenFromWorldPosition( pedX, pedY, pedZ + 0.6, 0, false )
					
					if ( screenX ~= false ) then
						-- На экране
						local size = math.floor( 512 / dist )
						
						if ( size > 64 ) then 
							size = 64 
							screenX = math.floor( screenX + 0.5 )
							screenY = math.floor( screenY + 0.5 )
						end
						
						local avatarX = screenX - ( size / 2 )
						local avatarY = screenY - ( size / 2 )
						
						local color
						if ( dist > Avatar.avatarDrawDistance * Avatar.avatarDrawFadeStart ) then
							-- Дистанция больше, чем 90% макс. дальности отрисовки, добавляем прозрачность
							local alpha = 1 - ( ( dist - Avatar.avatarDrawDistance * Avatar.avatarDrawFadeStart ) / ( Avatar.avatarDrawDistance * ( 1 - Avatar.avatarDrawFadeStart ) ) )
							color = tocolor( colorByBrightness, colorByBrightness, colorByBrightness, alpha * 255 )
						else
							-- Дистанция <90% дальности
							color = tocolor( colorByBrightness, colorByBrightness, colorByBrightness, 255 )
						end
						
						if ( CFG.gameplay.showNamedAvatars or ( Avatar.avatarNames[ avatarAlias ] == nil ) ) then
							-- Настройка "отображать аватарки игроков с именем"
							dxDrawImage( avatarX, avatarY, size, size, avatarTexture, 0, 0, 0, color )
						end
						
						-- Рисуем имя, если игрок подписал аватарку
						if ( dist < Avatar.nameDrawDistance and Avatar.avatarNames[ avatarAlias ] ~= nil ) then
							-- У игрока эта аватарка подписана
							--local fontScale = size / 64
							--if ( fontScale > 1 ) then fontScale = 1 end
							local fontScale = 1
							local subPixel = false
							local fontFamily = "default-bold"
							
							local textWidth = dxGetTextWidth( Avatar.avatarNames[ avatarAlias ], fontScale, fontFamily )
							local textX = screenX - textWidth / 2 
							
							local textY
							if ( not CFG.gameplay.showNamedAvatars ) then
								-- Аватарка не видна - приподнимем имя
								textY = screenY + size * 0.1
							else
								-- Аватарка видна
								textY = screenY + size * 0.37
							end
							
							local textColor, outlineColor
							if ( dist > Avatar.nameDrawDistance * Avatar.nameDrawFadeStart ) then
								local alpha = 1 - ( ( dist - Avatar.nameDrawDistance * Avatar.nameDrawFadeStart ) / ( Avatar.nameDrawDistance * ( 1 - Avatar.nameDrawFadeStart ) ) )
								textColor = tocolor( 255, 255, 255, alpha * 255 )
								outlineColor = tocolor( 0, 0, 0, alpha * 255 )
							else
								textColor = tocolor( 255, 255, 255, 255 )
								outlineColor = tocolor( 0, 0, 0, 255 )
							end
							
							local outline = 2
							dxDrawText( Avatar.avatarNames[ avatarAlias ], textX-outline, textY, nil, nil, outlineColor, fontScale, fontFamily, "left", "top", false, false, false, false, subPixel )
							dxDrawText( Avatar.avatarNames[ avatarAlias ], textX+outline, textY, nil, nil, outlineColor, fontScale, fontFamily, "left", "top", false, false, false, false, subPixel )
							dxDrawText( Avatar.avatarNames[ avatarAlias ], textX, textY-outline, nil, nil, outlineColor, fontScale, fontFamily, "left", "top", false, false, false, false, subPixel )
							dxDrawText( Avatar.avatarNames[ avatarAlias ], textX, textY+outline, nil, nil, outlineColor, fontScale, fontFamily, "left", "top", false, false, false, false, subPixel )
							dxDrawText( Avatar.avatarNames[ avatarAlias ], textX-outline, textY-outline, nil, nil, outlineColor, fontScale, fontFamily, "left", "top", false, false, false, false, subPixel )
							dxDrawText( Avatar.avatarNames[ avatarAlias ], textX-outline, textY+outline, nil, nil, outlineColor, fontScale, fontFamily, "left", "top", false, false, false, false, subPixel )
							dxDrawText( Avatar.avatarNames[ avatarAlias ], textX+outline, textY+outline, nil, nil, outlineColor, fontScale, fontFamily, "left", "top", false, false, false, false, subPixel )
							dxDrawText( Avatar.avatarNames[ avatarAlias ], textX+outline, textY-outline, nil, nil, outlineColor, fontScale, fontFamily, "left", "top", false, false, false, false, subPixel )
							
							dxDrawText( Avatar.avatarNames[ avatarAlias ], textX, textY, nil, nil, textColor, fontScale, fontFamily, "left", "top", false, false, false, false, subPixel )
						end
						
						drawnAvatarCount = drawnAvatarCount + 1
					end
				end
				
			else
				Debug.info( ped, " is not an element in distToPed[ dist ], dist is ", dist )
			end
		end
		
		Debug.debugData.avatarsRendered = drawnAvatarCount
	end;
	
	-- Персонаж игрока изменился
	onCharacterChange = function()
		-- Загружаем список имен аватарок для текущего персонажа
		if ( Character.isSelected() ) then
			-- Персонаж выбран, запрашиваем список имен аватарок для него
			-- TODO кэш
			triggerServerEvent( "Avatar.onClientRequestAvatarNames", resourceRoot )
		else
			-- Персонаж не выбран, очищаем список имен
			Avatar.avatarNames = {}
		end
	end;
	
	-- Сервер прислал список имен аватарок для персонажа characterID
	onServerResponseAvatarNames = function( characterID, avatarNames )
		Debug.info( "Сервер прислал список имен аватарок", characterID, avatarNames )
		Avatar.avatarNames = avatarNames
	end;
	
	-- В стрим попал какой-то элемент
	onElementStreamIn = function()
		if ( getElementType( source ) == "ped" or getElementType( source ) == "player" ) then
			if ( source == localPlayer ) then
				return nil
			end
			
			-- Если это игрок или пед, узнаем, есть ли у него аватарка
			local avatarAlias = getElementData( source, "Avatar.alias" )
			if ( avatarAlias == false ) then
				-- Аватарка не установлена
				Avatar.streamedPedAvatars[ source ] = nil
			else
				-- Аватарка установлена, добавляем в масив для отрисовки
				Avatar.streamedPedAvatars[ source ] = avatarAlias
			end
		end
	end;
	
	-- Из стрима ушел какой-то элемент
	onElementStreamOut = function()
		if ( getElementType( source ) == "ped" or getElementType( source ) == "player" ) then
			-- Если это игрок или пед, удаляем из массива
			Avatar.streamedPedAvatars[ source ] = nil
		end
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, Avatar.init )