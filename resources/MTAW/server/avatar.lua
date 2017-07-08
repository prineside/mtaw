--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Avatar.onClientRequestAvatarNames", true )							-- Клиент запрашивает его список имен аватарок - как правило, после выбора персонажа ()

--------------------------------------------------------------------------------
--<[ Модуль Avatar ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
Avatar = {
	templateCount = 14;
	segmentCount = 8;
	colorCount = 7;			-- Без учета серого цвета
	
	--[[ 
		Статистика использования цветов по шаблонам. 
		<номер шаблона> => [
			cnt => <количество использований шаблона>,
			segments => [
				<0 (индекс сегмента)> => 
					<0 (цвет)> => <Количество>,
					<1 (цвет)> => <Количество>
				<1 (индекс сегмента)> =>
					...
			]
		] 
	--]]
	
	pedAvatars = {};		-- { ped => avatarAlias }
	aliasStatistic = {};
	
	avatarNames = {};		-- Имена, которые игроки дали аватаркам (characterID => [ avatarAlias => name ])

	init = function()
		addEventHandler( "Main.onServerLoad", resourceRoot, Avatar.onServerLoad )
	
		-- Инициализируем шаблон статистики алиасов
		for templateNumber = 0, Avatar.templateCount-1 do
			-- Сегменты
			local segments = {}
			for segmentIndex = 0, Avatar.segmentCount-1 do
				-- Цвета сегментов
				local colors = {}
				for colorIndex = 0, Avatar.colorCount-1 do
					colors[ decimalToHex( colorIndex ) ] = 0
				end
				
				segments[ decimalToHex( segmentIndex ) ] = colors
			end
			
			Avatar.aliasStatistic[ decimalToHex( templateNumber ) ] = {
				cnt = 0;
				segments = segments;
			}
		end
		
		-- Загружаем alias_statistic.json, если есть, и пишем статистику поверх шаблона
		if ( fileExists( "server/data/avatar/alias_statistic.json" ) ) then
			-- alias_statistic.json существует, берем статистику
			local statisticsJson = fileGetContents( "server/data/avatar/alias_statistic.json" )
			local savedStatistic = jsonDecode( statisticsJson )
			if ( savedStatistic ~= nil ) then
				-- Валидный json, загружаем статистику
				for templateNumber, templateData in pairs( savedStatistic ) do
					Avatar.aliasStatistic[ templateNumber ].cnt = templateData.cnt
					for segmentIndex, segmentColors in pairs( templateData.segments ) do
						for colorIndex, colorCount in pairs( segmentColors ) do
							Avatar.aliasStatistic[ templateNumber ].segments[ segmentIndex ][ colorIndex ] = colorCount
						end
					end
				end
			end
		end
		
		-- Раз в 5 минут сохраняем статистику генерации алиасов
		setTimer( Avatar._saveAliasStatistic, 5 * 60 * 1000, 0 )
		
		-- И при остановке сервера
		addEventHandler( "onResourceStop", resourceRoot, Avatar._saveAliasStatistic )
		
		addEventHandler( "Avatar.onClientRequestAvatarNames", resourceRoot, Avatar.onClientRequestAvatarNames )
		
		Main.setModuleLoaded( "Avatar", 1 )
	end;
	
	onServerLoad = function()
		for i = 1, 9 do
			-- Терри Гудкайнд
			local testPed = createPed( 46, 0, i * 2, 3 )
			setElementDimension( testPed, Dimension.get( "Global" ) )
			Avatar.setPedAvatar( testPed, "5" .. i .. "3611462" )
			
			-- Джейн Кортес
			local testPed = createPed( 56, 2, i * 2, 3 )
			setElementDimension( testPed, Dimension.get( "Global" ) )
			Avatar.setPedAvatar( testPed, "24606" .. i .. "334" )
			
			-- Мария Кернер
			local testPed = createPed( 76, 4, i * 2, 3 )
			setElementDimension( testPed, Dimension.get( "Global" ) )
			Avatar.setPedAvatar( testPed, "a4" .. i .. "065563" )
			
			-- Неизвестно
			local testPed = createPed( 122, 6, i * 2, 3 ) 
			setElementDimension( testPed, Dimension.get( "Global" ) )
			Avatar.setPedAvatar( testPed, "a477" .. i .. "3277" )
		end
		
		--[[ Скинов дохрена
		local pedsCreated = 0
		for i = 0, 312 do
			local testPed = createPed( i, 8 + ( i % 30 ), math.floor( i / 30 ), 3 )
			if ( testPed ) then
				pedsCreated = pedsCreated + 1
				setElementDimension( testPed, Dimension.get( "Global" ) )
			end
		end
			
		Debug.info( "Created " .. pedsCreated .. " peds" )
		--]]
		
		addEventHandler( "Character.onCharacterSpawn", resourceRoot, Avatar.onCharacterSpawn )
		addEventHandler( "Character.onCharacterDespawn", resourceRoot, Avatar.onCharacterDespawn )
	end;
	
	-- Сгенерировать алиас для аватарки (новому персонажу)
	-- Сгенерированный алиас считается использованным, поэтому его безотговорочно надо использовать
	-- = string avatarAlias
	generateAvatarAlias = function()
		-- Ищем шаблоны, которые использовали реже всего
		local lessUsedTemplates = nil
		local lessUsedTemplateCnt = nil
		for templateNumber, templateData in pairs( Avatar.aliasStatistic ) do
			if ( lessUsedTemplateCnt == nil or templateData.cnt < lessUsedTemplateCnt ) then
				-- Еще не установлено минимальное число использований или шаблон использовали реже предыдущих
				lessUsedTemplateCnt = templateData.cnt
				lessUsedTemplates = {}
				table.insert( lessUsedTemplates, templateNumber )
			elseif ( templateData.cnt == lessUsedTemplateCnt ) then
				-- Шаблон использовали столько же раз, сколько и минимально используемый шаблон
				table.insert( lessUsedTemplates, templateNumber )
			end
		end
		
		-- Выбираем случайный шаблон из самых редких
		local generatedTemplateNumber = lessUsedTemplates[ math.random( 1, #lessUsedTemplates ) ]
		Avatar.aliasStatistic[ generatedTemplateNumber ].cnt = Avatar.aliasStatistic[ generatedTemplateNumber ].cnt + 1
		
		-- Генерируем цвета
		local generated = generatedTemplateNumber
		local generatedColors = {}
		local segmentsStatistic = Avatar.aliasStatistic[ generatedTemplateNumber ].segments
		
		for segmentIndex = 0, Avatar.segmentCount-1 do
			segmentIndex = tostring( segmentIndex )
			-- Ищем цвет сегментов, которые использовались реже всего
			local lessUsedColors = nil
			local lessUsedColorCount = nil
			for colorIndex, colorUsedCnt in pairs( segmentsStatistic[ segmentIndex ] ) do
				if ( lessUsedColorCount == nil or colorUsedCnt < lessUsedColorCount ) then
					-- Еще не установлено минимальное число использований или цвет использовали реже предыдущих
					lessUsedColorCount = colorUsedCnt
					lessUsedColors = {}
					table.insert( lessUsedColors, colorIndex )
				elseif ( colorUsedCnt == lessUsedColorCount ) then
					-- Цвет использовали столько же раз, сколько и минимально используемый цвет
					table.insert( lessUsedColors, colorIndex )
				end
			end
			
			-- Выбираем случайный цвет из самых редких
			local generatedColor = lessUsedColors[ math.random( 1, #lessUsedColors ) ]
			Avatar.aliasStatistic[ generatedTemplateNumber ].segments[ segmentIndex ][ generatedColor ] = Avatar.aliasStatistic[ generatedTemplateNumber ].segments[ segmentIndex ][ generatedColor ] + 1
			generated = generated .. generatedColor
		end
		
		return generated
	end;
	
	-- Сохранить статистику использования символов в аватарках (чтобы генерировать всегда случайные аватарки)
	_saveAliasStatistic = function()
		filePutContents( "server/data/avatar/alias_statistic.json", jsonEncode( Avatar.aliasStatistic, true ) )
	end;
	
	-- Установить аватарку над головой игрока
	-- Скрытые сегменты имеют цвет 7 (серый)
	-- > ped ped - пед или игрок, которому нужно установить аватарку
	-- > avatarAlias string / nil - алиас аватарки или nil, чтобы убрать аватарку
	-- = void
	setPedAvatar = function( ped, avatarAlias )
		if not validVar( ped, "ped", { "ped", "player" } ) then return nil end
		if not validVar( avatarAlias, "avatarAlias", { "string", "nil" } ) then return nil end
	
		if ( avatarAlias == nil ) then avatarAlias = false end
	
		setElementData( ped, "Avatar.alias", avatarAlias )
		
		Avatar.pedAvatars[ ped ] = avatarAlias
	end;
	
	-- Получить алиас аватарки педа или игрока
	-- Возвращает nil, если аватарка не установлена
	getPedAvatar = function( ped )
		return Avatar.pedAvatars[ ped ]
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Клиент запрашивает список имен, которые он назначил аватаркам
	onClientRequestAvatarNames = function()
		local playerElement = client
		
		local characterID = Character.getID( playerElement )
		if ( characterID ~= nil ) then
			-- Клиент уже выбрал персонаж, отправляем список имен аватарок
			if ( Avatar.avatarNames[ characterID ] ~= nil ) then
				-- Список уже загружен в память, отправляем клиенту
				triggerClientEvent( playerElement, "Avatar.onServerResponseAvatarNames", resourceRoot, characterID, Avatar.avatarNames[ characterID ] )
			else
				-- Список еще не загружен, обращаемся к базе
				local characterAvatarNames = {}
				local q = "\
					SELECT avatar, name \
					FROM mtaw.avatar_names \
					WHERE `character` = " .. tonumber( characterID ) .. ";"
					
				local isSuccess, result = DB.syncQuery( q )
				
				if ( not isSuccess ) then return nil end
				
				for _, row in pairs( result ) do
					characterAvatarNames[ row.avatar ] = row.name
				end
				
				Avatar.avatarNames[ characterID ] = characterAvatarNames
				
				triggerClientEvent( playerElement, "Avatar.onServerResponseAvatarNames", resourceRoot, characterID, characterAvatarNames )
			end
			Debug.info( "Avatar name list sent to client" )
		else
			-- Клиент еще не выбрал персонаж
			Debug.info( "Avatar name list can't be sent because player didn't select the character" )
		end
	end;
	
	-- Заспавнен персонаж игрока
	onCharacterSpawn = function( playerElement, characterID )
		-- Устанавливаем акатарку
		local avatarAlias = Character.getData( playerElement, "avatar" )
		
		Avatar.setPedAvatar( playerElement, avatarAlias )
	end;
	
	-- Персонаж игрока убран
	onCharacterDespawn = function( playerElement, characterID )
		-- Убираем акатарку
		Avatar.setPedAvatar( playerElement, nil )
	end;
}
addEventHandler( "onResourceStart", resourceRoot, Avatar.init )