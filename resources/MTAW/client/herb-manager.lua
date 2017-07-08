--[[
	Генератор групп Herb и точек растений
	Работает напрямую с ARR.herbPlaces и ARR.herbGroups, создает новые файлы сгенерированных массивов:
		/MTAW/herb-groups.lua
		/MTAW/herb-places.lua
--]]
--------------------------------------------------------------------------------
--<[ Модуль HerbManager ]>------------------------------------------------------
--------------------------------------------------------------------------------
HerbManager = {
	enabled = false;
	
	groups = {};	-- Копия ARR.herbGroups
	places = {};	-- Копия ARR.herbPlaces по группам { groupID => { x = {}, y = {}, z = {} }, ... }
	
	colshapes = {};	-- GroupID => colshape
	
	_newColshapePoints = {};
	
	_herbPlacesFilePrefix = "-- Места, в которых может расти что-то\n-- ARR.herbPlaces.x[ herbPlaceID ] ...\n-- g - ID группы, в которой находится точка\n";
	_herbGroupsFilePrefix = "-- Группы, в которых растут Herbs\n--[[\nname - имя группы\ncolshapePolygonPoints - массив точек, по которым будет создан полигон колизии\nminX, minY, maxX, maxY - AABB в котором содержится группа (для рейкастов)\nherbInterval - интервал размещения растений по умолчанию (в действительности может быть другим), используется в FarmGenerator если явно не указан\n--]]\n";
	
	init = function()
		if ( HerbManager.enabled ) then
			-- Делаем копию массивов, с которыми будем работать
			HerbManager.groups = tableCopy( ARR.herbGroups )
			for placeID, groupID in pairs( ARR.herbPlaces.g ) do
				if ( HerbManager.places[ groupID ] == nil ) then
					HerbManager.places[ groupID ] = {
						x = {};
						y = {};
						z = {};
					}
				end
				table.insert( HerbManager.places[ groupID ].x, ARR.herbPlaces.x[ placeID ] )
				table.insert( HerbManager.places[ groupID ].y, ARR.herbPlaces.y[ placeID ] )
				table.insert( HerbManager.places[ groupID ].z, ARR.herbPlaces.z[ placeID ] )
			end
			
			addEventHandler( "Main.onClientLoad", resourceRoot, HerbManager.onClientLoad )
		end
	end;
	
	onClientLoad = function() 
		-- Генерируем колшейпы и растения
		HerbManager.regenerateAll()
		
		-- Отрисовываем растения
		addEventHandler( "onClientRender", root, function()
			local totalRendered = 0
			for groupID, d in pairs( HerbManager.places ) do
				local placesInGroup = #d.x
				for placeID = 1, placesInGroup do
					dxDrawLine3D( d.x[ placeID ], d.y[ placeID ], d.z[ placeID ], d.x[ placeID ], d.y[ placeID ], d.z[ placeID ] + 2, 0xAA00FFFF, 2, false )
					totalRendered = totalRendered + 1
				end
			end
			
			dxDrawText( "Rendered " .. totalRendered, 660, 380 )
		end )
		
		-- Выводим список групп
		addEventHandler( "onClientRender", root, function()
			local y = 400
			for groupID, v in pairs( HerbManager.groups ) do
				dxDrawText( groupID .. " " .. v.name, 660, y )
				y = y + 20
			end
		end )
		
		-- Показываем подсказки по командам
		addEventHandler( "onClientRender", root, function()
			dxDrawText( "/hm-csc - collshape clear", 100, 400 )
			dxDrawText( "/hm-cg <name> - create group", 100, 420 )
			dxDrawText( "/hm-e - export", 100, 440 )
			dxDrawText( "/hm-r <groupID> <interval> - regenerate group", 100, 460 )
		end )
		
		-- Создаем команды
		Command.add( "hm-csc", "none", "-", "Очистить массив текущих точек создаваемого полигона колизии для группы растений", 
			function( cmd )
				HerbManager._newColshapePoints = {}
				
				Chat.addMessage( "Массив точек колизии очищен" )
			end 
		)
		Command.add( "hm-cg", "none", "<name>", "Создать группу растений", 
			function( cmd, name )
				local id = HerbManager.createGroup( name, HerbManager._newColshapePoints )
				Chat.addMessage( "Создана группа " .. id )
			end 
		)
		Command.add( "hm-r", "none", "-", "", 
			function( cmd, groupID, interval )
				HerbManager.regenerateGroup( tonumber( groupID ), true, tonumber( interval ) )
				Chat.addMessage( "Сгенерирована группа " .. groupID )
			end 
		)
		Command.add( "hm-e", "none", "-", "", 
			function( cmd )
				HerbManager.export()
				Chat.addMessage( "Экспортировано" )
			end 
		)
	end;
	
	-- Создает новую группу точек растений
	-- > name string - название группы
	-- > colshapePoints table - массив точек полигона колизии
	-- > herbInterval number / nil - интервал генерации растений, по умолчанию 1
	-- = number groupID
	createGroup = function( name, colshapePoints, herbInterval )
		if not validVar( name, "name", "string" ) then return nil end
		if not validVar( colshapePoints, "colshapePoints", "table" ) then return nil end
		if not validVar( herbInterval, "herbInterval", { "number", "nil" } ) then return nil end
		
		if ( herbInterval == nil ) then 
			herbInterval = 1
		end
		
		local groupID = #HerbManager.groups + 1
		
		local groupData = {}
		
		local minX = 30000
		local minY = 30000
		local maxX = -30000
		local maxY = -30000
		
		for k, v in ipairs( colshapePoints ) do
			if ( k % 2 == 0 ) then
				-- y
				if ( v < minY ) then
					minY = v
				end
				
				if ( v > maxY ) then
					maxY = v
				end
			else
				-- x
				if ( v < minX ) then
					minX = v
				end
				
				if ( v > maxX ) then
					maxX = v
				end
			end
		end
		
		local centerX = ( maxX + minX ) / 2
		local centerY = ( maxY + minY ) / 2
		
		groupData.name = name
		groupData.colshapePolygonPoints = colshapePoints
		groupData.minX = minX
		groupData.minY = minY
		groupData.maxX = maxX
		groupData.maxY = maxY
		groupData.centerX = centerX
		groupData.centerY = centerY
		groupData.herbInterval = herbInterval
		
		HerbManager.groups[ groupID ] = groupData
		
		return groupID
	end;
	
	-- Создает или заново генерирует колшейпы полей, а также заново генерирует точки для растений с указанным интервалом
	-- > regeneratePlaces bool / nil - если установлен в true, точки растений внутри группы будут перегенерированы, по умолчанию false
	-- > herbInterval number / nil - интервал, с которым будут сгенерированы новые точки (только если regeneratePlaces установлен в true). По умолчанию - значение из ARR.herbGroups
	-- = void
	regenerateAll = function( regeneratePlaces, herbInterval )
		if not validVar( regeneratePlaces, "regeneratePlaces", { "bool", "nil" } ) then return nil end
		if not validVar( herbInterval, "herbInterval", { "number", "nil" } ) then return nil end
		
		for groupID in pairs( HerbManager.groups ) do
			HerbManager.regenerateGroup( groupID, regeneratePlaces, herbInterval )
		end	
	end;
	
	-- Создает или заново генерирует колшейпы полей или указанного поля, а также заново генерирует точки для растений с указанным интервалом
	-- > herbGroupID number - ID группы растений, который надо заново генерировать
	-- > regeneratePlaces bool / nil - если установлен в true, точки растений внутри группы будут перегенерированы, по умолчанию false
	-- > herbInterval number / nil - интервал, с которым будут сгенерированы новые точки (только если regeneratePlaces установлен в true). По умолчанию - значение из ARR.herbGroups
	-- = void
	regenerateGroup = function( herbGroupID, regeneratePlaces, herbInterval )
		if not validVar( herbGroupID, "herbGroupID", "number" ) then return nil end
		if not validVar( regeneratePlaces, "regeneratePlaces", { "boolean", "nil" } ) then return nil end
		if not validVar( herbInterval, "herbInterval", { "number", "nil" } ) then return nil end
		
		if ( regeneratePlaces == nil ) then
			regeneratePlaces = false
		end
		
		if ( HerbManager.groups[ herbGroupID ] ~= nil ) then
			if ( HerbManager.colshapes[ herbGroupID ] ~= nil ) then
				destroyElement( HerbManager.colshapes[ herbGroupID ] )
			end
			
			HerbManager.colshapes[ herbGroupID ] = createColPolygon( HerbManager.groups[ herbGroupID ].centerX, HerbManager.groups[ herbGroupID ].centerY, unpack( HerbManager.groups[ herbGroupID ].colshapePolygonPoints ) )
			
			if ( regeneratePlaces ) then
				if ( herbInterval == nil ) then
					herbInterval = HerbManager.groups[ herbGroupID ].herbInterval
				end
				
				HerbManager.places[ herbGroupID ] = {
					x = {};
					y = {};
					z = {};
				};
				
				local e = createObject( 5639, 0, 0, 0 )
				
				for x = HerbManager.groups[ herbGroupID ].minX, HerbManager.groups[ herbGroupID ].maxX, herbInterval do
					for y = HerbManager.groups[ herbGroupID ].minY, HerbManager.groups[ herbGroupID ].maxY, herbInterval do
						local bx = x - ( herbInterval / 8 ) + math.random() * ( herbInterval / 4 )
						bx = bx + ( herbInterval / 2 * math.sin( y / 2 ) )
						local by = y - ( herbInterval / 8 ) + math.random() * ( herbInterval / 4 )
						by = by + ( herbInterval / 2 * math.sin( x / 2 ) )
						
						setElementPosition( e, bx, by, 0 )
						
						if ( isElementWithinColShape( e, HerbManager.colshapes[ herbGroupID ] ) ) then
							local hit, _, _, bz = processLineOfSight( bx, by, 100, bx, by, -20, true, false, false, false, true, true, true, false, localPlayer )
							if ( not hit ) then
								Chat.addMessage( "Невозможно сгенерировать группу " .. herbGroupID .. ", рейкаст слишком далеко" )
								return nil
							end
							
							table.insert( HerbManager.places[ herbGroupID ].x, bx )
							table.insert( HerbManager.places[ herbGroupID ].y, by )
							table.insert( HerbManager.places[ herbGroupID ].z, bz )
						end
					end
				end
				
				destroyElement( e )
				
				Debug.info( HerbManager.places[ herbGroupID ] )
				Chat.addMessage( "Сгенерированы точки растений группы " .. herbGroupID )
			end
		else
			Debug.error( "Группа " .. herbGroupID .. " не найдена" )
		end
	end;
	
	-- Экспортирует группы и точки растений в файлы herb-groups.lua и herb-places.lua в корне клиента
	-- = void
	export = function()
		local f = fileCreate( "herb-places.lua" )
		
		fileWrite( f, HerbManager._herbPlacesFilePrefix )
		
		local tX = {}
		local tY = {}
		local tZ = {}
		local tG = {}
		
		for groupID, d in pairs( HerbManager.places ) do
			for placeID = 1, #d.x do
				local k = #tX + 1
				tX[ k ] = string.format( "%0.2f", d.x[ placeID ] )
				tY[ k ] = string.format( "%0.2f", d.y[ placeID ] )
				tZ[ k ] = string.format( "%0.2f", d.z[ placeID ] )
				tG[ k ] = groupID
			end
		end
		
		fileWrite( f, "ARR.herbPlaces = {\n" )
		fileWrite( f, "	x = { " .. table.concat( tX, "," ) .. " };\n" )
		fileWrite( f, "	y = { " .. table.concat( tY, "," ) .. " };\n" )
		fileWrite( f, "	z = { " .. table.concat( tZ, "," ) .. " };\n" )
		fileWrite( f, "	g = { " .. table.concat( tG, "," ) .. " };\n" )
		fileWrite( f, "};\n" )
		
		fileClose( f )
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, HerbManager.init )