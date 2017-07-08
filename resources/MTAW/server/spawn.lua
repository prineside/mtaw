-- Точки респавна

--------------------------------------------------------------------------------
--<[ Модуль Spawn ]>------------------------------------------------------------
--------------------------------------------------------------------------------
Spawn = {
	locations = {};

	init = function()
		addEventHandler( "Main.onServerLoad", root, Spawn.onServerLoad )
	
		Main.setModuleLoaded( "Spawn", 1 )
	end;
	
	onServerLoad = function()
		-- Получаем массив спавнов
		local isSuccess, result = DB.syncQuery( "SELECT * FROM mtaw.spawn" )
	
		if ( not isSuccess ) then return nil end
		
		Spawn.locations = {}
		local cnt = 0
		for k, v in pairs( result ) do
			Spawn.locations[ v.alias ] = {
				alias = v.alias;
				name = v.name;
				areaBoudaries = {
					minX = v.area_minx;
					minY = v.area_miny;
					maxX = v.area_maxx;
					maxY = v.area_maxy;
				};
				area = createColRectangle( v.area_minx, v.area_miny, v.area_maxx - v.area_minx, v.area_maxy - v.area_miny );
				x = v.x;
				y = v.y;
				z = v.z;
				weight = v.weight;
				comfort = v.comfort;
				cleanliness = v.cleanliness;
				charging = v.charging;
				opened = v.opened;
			}
			cnt = cnt + 1
		end
		
		Debug.info( "Loaded " .. cnt .. " spawn locations" )
	end;
	
	----------------------------------------------------------------------------

	-- Получить самую ближнюю точку респавна игрока (например, куда будет идти бот при выходе)
	-- > px number - координата X, возле которой искать ближайший спавн
	-- > py number - координата Y, возле которой искать ближайший спавн
	-- > pz number - координата Z, возле которой искать ближайший спавн
	-- = string spawnAlias
	getNearestSpawnAlias = function( px, py, pz )
		local availableSpawns = {}
	
		-- Ищем все открытые спавны
		for k, v in pairs( Spawn.locations ) do
			if ( v.opened == 1 ) then
				availableSpawns[ k ] = v
			end
		end
		
		-- Ищем те, к которым игрок имеет доступ (TODO)
		
		-- Выбираем самый ближний и качественный
		local nearestDistance = 65535
		local nearestID = nil
		
		for k, v in pairs( availableSpawns ) do
			local d = getDistanceBetweenPoints2D( px, py, v.x, v.y ) / v.weight
			
			if ( d < nearestDistance ) then
				nearestDistance = d
				nearestID = k
			end
		end
		
		Debug.info( "Nearest spawn: " .. nearestID .. ", " .. nearestDistance )
		
		return nearestID
	end;
	
	-- Получить информацию о спавне по его алиасу. Возвращает таблицу вида { alias = string, name = string, x = number, y = number ... }, см. Spawn.onServerLoad
	-- > spawnAlias string
	-- = table / nil spawnInfo
	getSpawnInfo = function( spawnAlias )
		return Spawn.locations[ spawnAlias ]
	end;
	
	-- Возвращает alias спавна, на котором стоит игрок, или nil
	-- > playerElement player / ped
	-- = string / nil spawnAlias
	getSpawnPlayerStandingOn = function( playerElement )
		local px, py, pz = getElementPosition( playerElement )
		
		for k, v in pairs( Spawn.locations ) do
			if ( px > v.areaBoudaries.minX and px < v.areaBoudaries.maxX and py > v.areaBoudaries.minY and py < v.areaBoudaries.maxY ) then
				return k
			end
		end
		
		return nil
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------

};
addEventHandler( "onResourceStart", resourceRoot, Spawn.init )