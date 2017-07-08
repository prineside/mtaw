--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Model.onClientRequestModelList", true )								-- Клиент запрашивает список моделей ()
addEvent( "Model.onClientRequestFiles", true )									-- Клиент запрашивает загрузку файлов модели ( number modelID )

--------------------------------------------------------------------------------
--<[ Модуль Model ]>------------------------------------------------------------
--------------------------------------------------------------------------------
Model = {
	teaKey = "qmQdsUy4RMrClVTa";
	
	files = {};			-- fileHash => encodedFileContents
	models = {};		-- modelID => { date, dffHash, txdHash, colHash, dffSize, colSize, txdSize }
	
	_lastLoadedModelDate = 0;
	
	init = function()
		-- Загружаем файлы в память
		local isSuccess, result = DB.syncQuery( "SELECT * FROM mtaw.model" )
		
		if ( not isSuccess ) then 
			Debug.critical( "Unable to load Model from database" )
		
			return nil 
		end
		
		Model.models = {}
		
		local modelsLoaded = Model._updateModels( result )
		
		Main.setModuleLoaded( "Model", 1 )
		Debug.info( "Loaded models: " .. modelsLoaded )
		
		-- Периодически проверяем базу на предмет изменений моделей
		setTimer( Model._listenToDatabaseChanges, 10000, 0 )
		
		-- Обработка запросов клиента
		addEventHandler( "Model.onClientRequestModelList", resourceRoot, Model.onClientRequestModelList )
		addEventHandler( "Model.onClientRequestFiles", resourceRoot, Model.onClientRequestFiles )
	end;
	
	-- Получает из базы все модели, которые были изменены (date больше, чем самая последняя загруженная модель)
	_listenToDatabaseChanges = function()
		DB.query( "SELECT * FROM mtaw.model WHERE date > " .. Model._lastLoadedModelDate, nil, function( queryHandle ) 
			local result = dbPoll( queryHandle, 0 )
			
			if ( #result ~= 0 ) then
				-- Изменения в базе
				Model._updateModels( result )
				Model.updateClientModelList()
			end
		end )
	end;
	
	-- Обновить информацию о моделях (используется при инициализации модуля и при изменении данных в таблице БД)
	_updateModels = function( dbQueryResult )
		local dffHash, txdHash, colHash, dffSize, colSize, txdSize, fileHandle, fileContents
		
		local loadedModels = 0
		
		for _, row in pairs( dbQueryResult ) do
			if ( fileExists( "client/data/model/" .. row.model .. ".dff" ) and fileExists( "client/data/model/" .. row.model .. ".txd" ) ) then
				-- dff
				fileHandle = fileOpen( "client/data/model/" .. row.model .. ".dff", true )
				
				dffSize = fileGetSize( fileHandle )
				fileContents = base64Decode( teaEncode( base64Encode( fileRead( fileHandle, dffSize ) ), Model.teaKey ) )
				dffHash = hash( "md5", fileContents )
				Model.files[ dffHash ] = fileContents
				
				fileClose( fileHandle )
				
				-- txd
				fileHandle = fileOpen( "client/data/model/" .. row.model .. ".txd", true )
				
				txdSize = fileGetSize( fileHandle )
				fileContents = base64Decode( teaEncode( base64Encode( fileRead( fileHandle, txdSize ) ), Model.teaKey ) )
				txdHash = hash( "md5", fileContents )
				Model.files[ txdHash ] = fileContents
				
				fileClose( fileHandle )
			
				-- col
				if ( fileExists( "client/data/model/" .. row.model .. ".col" ) ) then
					fileHandle = fileOpen( "client/data/model/" .. row.model .. ".col", true )
					
					colSize = fileGetSize( fileHandle )
					fileContents = base64Decode( teaEncode( base64Encode( fileRead( fileHandle, colSize ) ), Model.teaKey ) )
					colHash = hash( "md5", fileContents )
					Model.files[ colHash ] = fileContents
					
					fileClose( fileHandle )
				else
					colHash = nil;
					colSize = nil;
				end
			
				Model.models[ row.model ] = {
					date = row.date;
					dffHash = dffHash;
					txdHash = txdHash;
					colHash = colHash;
					dffSize = dffSize;
					colSize = colSize;
					txdSize = txdSize;
				}
				
				if ( row.date > Model._lastLoadedModelDate ) then
					Model._lastLoadedModelDate = row.date
				end
				
				loadedModels = loadedModels + 1
			else
				Debug.error( "Model " .. row.model .. " has no dff or txd file" )
			end
		end
		
		return loadedModels
	end;
	
	updateClientModelList = function( playerElement )
		if not validVar( playerElement, "playerElement", { "player", "nil" } ) then return nil end
		
		if ( playerElement == nil ) then
			triggerClientEvent( "Model.onModelListUpdate", resourceRoot, Model.models )
		else
			triggerClientEvent( playerElement, "Model.onModelListUpdate", resourceRoot, Model.models )
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Клиент запросил список моделей для замены (при инициализации)
	onClientRequestModelList = function()
		Debug.info( "Client requested model list" )
		Model.updateClientModelList( client )
	end;
	
	-- Клиент запросил файлы
	onClientRequestFiles = function( modelID )
		Debug.info( "onClientRequestModelFiles " .. modelID )
		
		local playerElement = client
		
		if ( Model.models[ modelID ].colHash == nil ) then
			triggerLatentClientEvent( playerElement, "Model.onServerSentFiles", 100000, false, resourceRoot, modelID, Model.files[ Model.models[ modelID ].dffHash ], Model.files[ Model.models[ modelID ].txdHash ] )
		else
			triggerLatentClientEvent( playerElement, "Model.onServerSentFiles", 100000, false, resourceRoot, modelID, Model.files[ Model.models[ modelID ].dffHash ], Model.files[ Model.models[ modelID ].txdHash ], Model.files[ Model.models[ modelID ].colHash ] )
		end
		
		-- Отрисовка прогресса загрузки файлов
		local eventHandle = getLatentEventHandles( playerElement )[ #getLatentEventHandles( playerElement ) ]
		local progressUpdateTimer
		
		local updateDownloadProgress = function()
			local status = getLatentEventStatus( playerElement, eventHandle )
			if ( not status ) then
				killTimer( progressUpdateTimer )
			else
				triggerClientEvent( playerElement, "Model.onDownloadProgressUpdate", resourceRoot, status )
			end
		end
		progressUpdateTimer = setTimer( updateDownloadProgress, 250, 0 )
	end;
}
addEventHandler( "onResourceStart", resourceRoot, Model.init )