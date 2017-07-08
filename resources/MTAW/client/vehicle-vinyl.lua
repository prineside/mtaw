--[[
	Винилы на транспортных средствах
	- Загружает необходимые винилы из сервера
	- Генерирует текстуры машин (налаживает винилы друг на друга) 
	- С помощью шейдера налаживает текстуру винилов на машину
	- Динамически загружает и выгружает из памяти текстуры, так само применяет
	  и снимает шейдеры при стриминге транспорта
	  
	Текстура генерируется из ряда винилов. Каждый винил содержит данные:
	(позиция, размер и центр поворота указаны в диапазоне 0..2048 относительно
	 размера текстуры)
	- ID винила (int)
	- x (int)
	- y (int)
	- width (int)
	- height (int)
	- угол (int)
	- цвет (int в hex)
	- зеркальный (0 или 1)
	1785|250|1420|128|64|90|FFFFFF|1,412|9|25|18|345|568|FF0000|0,
	
	{
		id
		x
		y
		w (width)
		h (height)
		c (color)
		m (mirrored)
	}
	
	Отдельный винил имеет характеристики:
	- ширина (px)
	- высота (px)
	- может менять цвет (для деколей может, для цветных винилов - нет)
	
	Каждое транспортное средство имеет характеристики:
	- начальная точка (в ней будет центр нового винила в начале редактирования)
	
	TODO Процесс генерации текстуры:
	Каждое транспортное средство с текстурой имеет статус:
	- Без текстуры
	- Текстура низкого качества
	- Текстура высокого качества
	
	Сначала создается текстура очень низкого качества (128x128) как временная замена основной.
	Процесс создания и применения текстуры низкого качества происходит в отдельной корутине:
	- Очищается smallRenderTarget (128x128)
	- На smallRenderTarget наносятся винилы (р)
	- Если статус еще не "текстура высокого качества", smallRenderTarget передается шейдеру (временная замена основной текстуре), статус меняется на "текстура низкого качества"
	
	Так как dxCreateTexture при 2048x2048 жрет около 500мс времени, кэшировать текстуры
	в файл нельзя. Так само нельзя устанавливать пиксели сразу всей текстуры.
	Процесс генерации текстуры в корутине. (р) значит, что процесс может быть 
	разбит с помощью yield 
	
	- Очищается renderTarget
	- На renderTarget наносятся винилы (р)
	- Извлекаются пиксели из renderTarget (р)
	- Создается основная текстура
	- В основную текстуру частями записываются пиксели (р)
	- Основная текстура передается шейдеру, статус меняется на "текстура высокого качества"
--]]

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "VehicleVinyl.onServerSentFile", true )								-- Сервер прислал запрашиваемый файл винила ( number vinylID, binary fileData )
addEvent( "VehicleVinyl.onServerResponseVinylList", true )						-- ( table categories, table vinyls )

--------------------------------------------------------------------------------
--<[ Модуль VehicleVinyl ]>-----------------------------------------------------
--------------------------------------------------------------------------------
VehicleVinyl = {
	version = 2;
	
	categories = {};			-- categoryID => categoryName
	vinyls = {};				-- vinylID => vinylData
	
	_vinylLoadingQueue = {};	-- vinylID => true - винилы, которые ожидают загрузки из сервера
	_pendingForFile = false;	-- true, если ожидается получение файла от сервера
	_vehicleSetVinylsQueue = {};-- vehicle => { vinyls => { vinylID => true }, vinylCount = number } - очередь применения винилов (которым не хватает файлов)
	
	sourceResolution = 2048;
	decalSectionHeight = 256;
	resolution = nil;			-- CFG.graphics.vehicleVinylResolution

	_generatorRenderTarget = nil;
	
	_vehicleShaders = {};		-- vehicle => vinylShader
	_vehicleTextures = {};		-- vehicle => texture (перед удалением шейдера нужно удалить текстуру)
	
	_textureStatus = {};		-- vehicle => status (nil/low/high)
	
	_lowResGenQueue = {};		-- [] => vehicle
	_lowResGenQueueKeys = {};	-- vehicle => true
	
	_highResGenQueue = {};		-- [] => vehicle
	_highResGenQueueKeys = {};	-- vehicle => true
	
	init = function()
		-- Устанавливаем разрешение из настроек
		if ( CFG.graphics.vehicleVinylResolution == "medium" ) then
			VehicleVinyl.resolution = 1024
		elseif ( CFG.graphics.vehicleVinylResolution == "high" ) then
			VehicleVinyl.resolution = 2048
		elseif ( CFG.graphics.vehicleVinylResolution == "low" ) then
			VehicleVinyl.resolution = 512
		elseif ( CFG.graphics.vehicleVinylResolution == "verylow" ) then
			VehicleVinyl.resolution = 256
		else
			Debug.error( "Unknown resolution: " .. tostring( CFG.graphics.vehicleVinylResolution ) )
		end
		
		-- Создаем renderTarget, на котором будут отрисовываться текстуры винилов
		VehicleVinyl._generatorRenderTarget = dxCreateRenderTarget( VehicleVinyl.resolution, VehicleVinyl.resolution, true )
		
		-- Периодически изменяем параетр освещенности в шейдерах
		--[[
		setTimer( function()
			local lightLevel = 0.25 + Environment.getDayLightIntensity() * 0.5
			for _, vehicleShader in pairs( VehicleVinyl._vehicleShaders ) do
				dxSetShaderValue( vehicleShader, "lightLevel", lightLevel )
			end
		end, 2000, 0 )
		--]]
		
		addEventHandler( "Main.onClientLoad", resourceRoot, VehicleVinyl.onClientLoad )
		
		Main.setModuleLoaded( "VehicleVinyl", 1 )
	end;
	
	onClientLoad = function()
		-- Запрашиваем у сервера список винилов и категорий
		triggerServerEvent( "VehicleVinyl.onClientRequestVinylList", resourceRoot )
			
		addEventHandler( "VehicleVinyl.onServerResponseVinylList", resourceRoot, function( categories, vinyls ) 
			-- Сервер прислал список винилов
			VehicleVinyl.categories = categories
			
			VehicleVinyl._addExistingVinyls( vinyls )
		end )
		
		-- Обрабатываем загрузку файлов
		addEventHandler( "VehicleVinyl.onServerSentFile", resourceRoot, VehicleVinyl.onServerSentFile )
		
		-- Обрабатываем стриминг винилов машин
		addEventHandler( "onClientElementStreamIn", root, VehicleVinyl.onElementStreamIn )
		addEventHandler( "onClientElementStreamOut", root, VehicleVinyl.onElementStreamOut )
		addEventHandler( "onClientElementDataChange", root, VehicleVinyl.onElementDataChange )
		
		--[[
		-- Тест определения точки на UV
		-- 1. Делаем снимок экрана и применяем шейдер градиента
		-- 2. Рисуем снимок поверх обычной сцены, тем временем делаем второй снимок сцены (с градиентом)
		local sx, sy = guiGetScreenSize()
		local ss1 = dxCreateScreenSource( sx, sy )
		local ss2 = dxCreateScreenSource( sx, sy )
		
		local s = Shader.create( "client/data/shaders/settxt-noshade.fx", 100, 300, true, "vehicle" )
		local t = dxCreateTexture( "client/data/vinyl/uv.png", nil, false )
		dxSetShaderValue( s, "Tex0", t )
		
		local capture = false
		
		Command.add( "ss", "none", "", "", function( playerElement, cmd )
			if ( capture == 1 ) then
				capture = 3
			else
				capture = 1
			end
		end )
		
		addEventHandler( "onClientRender", root, function()
			if ( capture == 1 ) then
				setFPSLimit( Main.fpsLimit * 2 )
				
				engineApplyShaderToWorldTexture( s, "vehiclegrunge256", nil, true )
				dxUpdateScreenSource( ss1, true )
				capture = 2
			elseif ( capture == 2 ) then
				setFPSLimit( Main.fpsLimit * 2 )
				dxUpdateScreenSource( ss2, true )
				engineRemoveShaderFromWorldTexture( s, "*" )
				
				dxDrawImage( 0, 0, sx, sy, ss1 )
				
				capture = 1
			elseif ( capture == 3 ) then
				setFPSLimit( Main.fpsLimit )
				
				capture = false
			end
			
			dxDrawImage( 0, 200, sx / 2, sy / 2, ss2 )
		end )
		--]]
	end;
	
	_lowResTextureGenerator = function( iterTick )
	
	end;
	
	_highResTextureGenerator = function( iterTick )
	
	end;
	
	-- Возвращает строку, в которую запакована конфигурация всех винилов
	-- > vinylListTable table - список винилов
	-- = string serializedVinyls
	serialize = function( vinylListTable )
		if not validVar( vinylListTable, "vinylListTable", "table" ) then return nil end
		
		local vinyls = {}
		for _, vinylData in pairs( vinylListTable ) do
			vinyls[ #vinyls + 1 ] = table.concat( {
				vinylData.id, vinylData.x, vinylData.y, vinylData.w, vinylData.h, vinylData.a, decimalToHex( vinylData.c ), vinylData.m
			}, "|" )
		end
		
		return table.concat( vinyls, "," )
	end;
	
	-- Преобразует строку в массив конфигурации винилов
	unserialize = function( serializedString )
		if not validVar( serializedString, "serializedString", "string" ) then return nil end
		
		local vinyls = {}
		local vinylStrings = explode( ",", serializedString )
		for _, vinylString in pairs( vinylStrings ) do
			local expl = explode( "|", vinylString )
			
			vinyls[ #vinyls + 1 ] = {
				id = tonumber( expl[ 1 ] );
				x = tonumber( expl[ 2 ] );
				y = tonumber( expl[ 3 ] );
				w = tonumber( expl[ 4 ] );
				h = tonumber( expl[ 5 ] );
				a = tonumber( expl[ 6 ] );
				c = tonumber( expl[ 7 ], 16 );
				m = tonumber( expl[ 8 ] );
			}
		end
		
		return vinyls
	end;
	
	-- Устанавливает винилы транспортному средству
	-- > vehicle vehicle
	-- > vinyls table / nil - список винилов и их параметров (индексированный) или nil, чтобы убрать текстуру
	-- = void
	setVehicleVinyls = function( vehicle, vinyls )
		if not validVar( vehicle, "vehicle", "vehicle" ) then return nil end
		if not validVar( vinyls, "vinyls", { "table", "nil" } ) then return nil end
		
		if ( VehicleVinyl._vehicleShaders[ vehicle ] ~= nil ) then
			-- Удаляем старый шейдер
			engineRemoveShaderFromWorldTexture( VehicleVinyl._vehicleShaders[ vehicle ], "*" )
			destroyElement( VehicleVinyl._vehicleShaders[ vehicle ] )
			destroyElement( VehicleVinyl._vehicleTextures[ vehicle ] )
			
			VehicleVinyl._vehicleShaders[ vehicle ] = nil
			VehicleVinyl._vehicleTextures[ vehicle ] = nil
		end
		
		if ( vinyls ~= nil ) then
			-- Проверяем, все ли необходимые винилы загружены
			local needToLoad = {}
			local needToLoadCount = 0
			for _, vinylData in pairs( vinyls ) do
				if ( VehicleVinyl._vinylLoadingQueue[ vinylData.id ] ~= nil ) then
					-- Текстура еще не загружена
					Debug.info( "Винил " .. vinylData.id .. " еще не загружен, откладываем применение винилов" )
					
					needToLoad[ vinylData.id ] = true
					needToLoadCount = needToLoadCount + 1
				end
			end
			
			if ( needToLoadCount ~= 0 ) then
				-- Не хватает текстур
				VehicleVinyl._vehicleSetVinylsQueue[ vehicle ] = {
					vinyls = needToLoad;
					vinylCount = needToLoadCount;
				}
				
				return nil
			end
			
			-- Генерируем и применяем текстуру
			VehicleVinyl._vehicleTextures[ vehicle ] = VehicleVinyl._getVinylTexture( vinyls )
			VehicleVinyl._vehicleShaders[ vehicle ] = Shader.create( "client/data/shaders/vinyl.fx", 1, 300, true, "vehicle" )
			dxSetShaderValue( VehicleVinyl._vehicleShaders[ vehicle ], "Tex0", VehicleVinyl._vehicleTextures[ vehicle ] )
			engineApplyShaderToWorldTexture( VehicleVinyl._vehicleShaders[ vehicle ], "vinyl*", vehicle, false )
			--engineApplyShaderToWorldTexture( VehicleVinyl._vehicleShaders[ vehicle ], "decal", vehicle, false )
		end
	end;
	
	-- Генерирует и возвращает текстуру, скомпонированную из винилов в очередности переданной таблицы
	-- Если какой-то из винилов не был еще загружен
	-- vinyls: { { id, x, y, w, h, a, ax, ay, color }, ... }
	-- > vinuls table - список винилов и их параметров (индексированный)
	-- = texture / nil vinylTexture
	_getVinylTexture = function( vinyls )
		local _st = getTickCount()
		
		local fileHash = hash( "md5", VehicleVinyl.serialize( vinyls ) ):sub( 1, 16 )
		local fileName = "client/data/vinyl/baked/" .. fileHash .. "_" .. VehicleVinyl.resolution .. "_" .. VehicleVinyl.version .. ".png"
		
		local t
		--if ( fileExists( fileName ) ) then
		--	t = dxCreateTexture( fileName, "dxt5", false )
		--else
			dxSetRenderTarget( VehicleVinyl._generatorRenderTarget, true )

			local coeff = VehicleVinyl.resolution / VehicleVinyl.sourceResolution
			local allTexturesExist = true
			for _, data in pairs( vinyls ) do
				if ( fileExists( "client/data/vinyl/" .. data.id .. ".png" ) ) then
					dxDrawImage( data.x * coeff, data.y * coeff, data.w * coeff, data.h * coeff, "client/data/vinyl/" .. data.id .. ".png", data.a, 0, 0, data.c )
					
					if ( data.m == 1 ) then
						local mainHeight = VehicleVinyl.sourceResolution - VehicleVinyl.decalSectionHeight
						if ( data.y > mainHeight / 2 ) then
							-- Нижняя часть развертки (нормальное положение
							dxDrawImage( data.x * coeff, ( mainHeight - data.y ) * coeff, data.w * coeff, ( -data.h ) * coeff, "client/data/vinyl/" .. data.id .. ".png", data.a, 0, 0, data.c )
						else
							-- Верхняя часть развертки (перевернутое)
							Debug.info( "Зеркальная текстура может нахордиться только в нижней части развертки" )
						end
					end
				else
					if ( VehicleVinyl._vinylLoadingQueue[ data.id ] == nil ) then
						dxSetRenderTarget()
						Debug.error( "Винил " .. tostring( data.id ) .. " не существует" )
						
						return nil
					else
						allTexturesExist = false
						break
					end
				end
			end
			
			dxSetRenderTarget()
			
			if ( not allTexturesExist ) then
				return nil
			end
			
			--t = VehicleVinyl._generatorRenderTarget
			t = dxCreateTexture( VehicleVinyl.resolution, VehicleVinyl.resolution, "dxt5", "clamp" )
			
			local pixels = dxGetTexturePixels( VehicleVinyl._generatorRenderTarget )
			
			dxSetTexturePixels( t, pixels )
			
			--[[
			local h = fileCreate( fileName )
			fileWrite( h, dxConvertPixels( pixels, "png" ) )
			fileClose( h )
			
			t = dxCreateTexture( pixels, "dxt5" ) -- 0.84 - 1.0
			--]]
		--end
		
		Debug.info( getTickCount() - _st, "ms" )
		
		return t
	end;
	
	-- Добавить новые винилы в список существующих
	-- Функция добавит винилы в общий массив и, при необходимости, в очередь загрузки
	-- table vinyls - массив винилов ( vinylID => vinylData )
	-- = void
	_addExistingVinyls = function( vinyls )
		for vinylID, vinylData in pairs( vinyls ) do
			if ( not fileExists( "client/data/vinyl/" .. vinylID .. ".png" ) or hash( "md5", fileGetContents( "client/data/vinyl/" .. vinylID .. ".png" ) ):sub( 1, 8 ) ~= vinylData.fileHash ) then
				VehicleVinyl._vinylLoadingQueue[ vinylID ] = true
				VehicleVinyl._handleLoadingQueue()
			end
		
			VehicleVinyl.vinyls[ vinylID ] = vinylData
		end
	end;
	
	-- Берет первый элемент из очереди на загрузку и запрашивает у сервера, затем извлекает его из массива
	_handleLoadingQueue = function()
		Debug.info( "_handleLoadingQueue" )
		if ( VehicleVinyl._pendingForFile == false ) then
			Debug.info( "_handleLoadingQueue OK" )
			local vinylID = nil
			for v in pairs( VehicleVinyl._vinylLoadingQueue ) do
				vinylID = v
				break
			end
			
			if ( vinylID ~= nil ) then
				triggerServerEvent( "VehicleVinyl.onClientRequestFile", resourceRoot, vinylID )
				VehicleVinyl._vinylLoadingQueue[ vinylID ] = nil
				
				VehicleVinyl._pendingForFile = true
				
				Debug.info( "_handleLoadingQueue sent event" )
			end
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Сервер прислал файл винила
	onServerSentFile = function( vinylID, fileData )
		Debug.info( "onServerSentFile" )
		
		VehicleVinyl._pendingForFile = false
		
		local h = fileCreate( "client/data/vinyl/" .. vinylID .. ".png" )
		fileWrite( h, fileData )
		fileClose( h )
		
		-- TODO обработка очереди замен винилов
		Debug.info( "Загружен винил: " .. vinylID )
		
		VehicleVinyl._handleLoadingQueue()
	end;
	
	onElementStreamIn = function()
		if ( getElementType( source ) == "vehicle" ) then
			local px, py, pz = getElementPosition( localPlayer )
			local vx, vy, vz = getElementPosition( source )
			local d = getDistanceBetweenPoints3D( px, py, pz, vx, vy, vz )
			
			local vinylString = getElementData( source, "VehicleVinyl" )
			if ( vinylString == false ) then
				VehicleVinyl.setVehicleVinyls( source, nil )
			else
				VehicleVinyl.setVehicleVinyls( source, VehicleVinyl.unserialize( vinylString ) )
			end
		end
	end;
	
	onElementStreamOut = function()
		if ( getElementType( source ) == "vehicle" ) then
			local px, py, pz = getElementPosition( localPlayer )
			local vx, vy, vz = getElementPosition( source )
			local d = getDistanceBetweenPoints3D( px, py, pz, vx, vy, vz )
			
			VehicleVinyl.setVehicleVinyls( source, nil )
		end
	end;
	
	onElementDataChange = function( dataName, oldValue )
		if ( dataName == "VehicleVinyl" and getElementType( source ) == "vehicle" ) then

			local vinylString = getElementData( source, "VehicleVinyl" )
			if ( vinylString == false ) then
				VehicleVinyl.setVehicleVinyls( source, nil )
			else
				VehicleVinyl.setVehicleVinyls( source, VehicleVinyl.unserialize( vinylString ) )
			end
		end
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, VehicleVinyl.init )