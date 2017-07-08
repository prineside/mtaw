--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Model.onServerSentFiles", true )										-- Сервер прислал запрашиваемый файл модели ( string fileName, binary fileData )
addEvent( "Model.onModelListUpdate", true )										-- Сервер прислал список измененных моделей ( table modelList )
addEvent( "Model.onDownloadProgressUpdate", true )								-- Сервер прислал прогресс загрузки файлов ( table dowloadStatus )

--------------------------------------------------------------------------------
--<[ Модуль Model ]>------------------------------------------------------------
--------------------------------------------------------------------------------
Model = {
	teaKey = "qmQdsUy4RMrClVTa";
	
	models = {};		-- modelID => { dffHash, txdHash, colHash }
	
	_reloadQueue = {};	-- [] => modelID
	_reloadQueueKeys = {};	-- modelID => true, чтобы проверять, есть ли модель в очереди
	_lastQueueLoadedModelCount = 0;
	
	_waitingForModelDownload = false;	-- Ожидается загрузка файла от сервера
	
	init = function()
		addEventHandler( "Main.onClientLoad", root, Model.onClientLoad )
		
		addEventHandler( "Model.onModelListUpdate", root, Model.onModelListUpdate )
		addEventHandler( "Model.onServerSentFiles", root, Model.onServerSentFiles )
		addEventHandler( "Model.onDownloadProgressUpdate", root, Model.onDownloadProgressUpdate )
	end;
	
	onClientLoad = function()
		-- Запрос списка моделей из сервера
		triggerServerEvent( "Model.onClientRequestModelList", resourceRoot )
	end;
	
	-- Замена всех файлов модели
	_replaceModel = function( modelID )
		if not validVar( modelID, "modelID", "number" ) then return nil end
	
		local rawFileHandle, basedRaw
		
		-- col
		if ( fileExists( "client/data/model/" .. modelID .. ".col" ) ) then
			basedRaw = teaDecode( base64Encode( fileGetContents( "client/data/model/" .. modelID .. ".col" ) ), Model.teaKey )
			--rawFileHandle = fileCreate( "@client/data/raw." .. modelID .. ".col" )
			--fileWrite( rawFileHandle, base64Decode( basedRaw ) )
			--fileClose( rawFileHandle )
			
			--local col = engineLoadCOL( "@client/data/raw." .. modelID .. ".col" )
			local col = engineLoadCOL( base64Decode( basedRaw ) )
			engineReplaceCOL( col, modelID )
			--fileDelete( "@client/data/raw." .. modelID .. ".col" )
		end
		
		-- txd
		basedRaw = teaDecode( base64Encode( fileGetContents( "client/data/model/" .. modelID .. ".txd" ) ), Model.teaKey )
		--rawFileHandle = fileCreate( "@client/data/raw." .. modelID .. ".txd" )
		--fileWrite( rawFileHandle, base64Decode( basedRaw ) )
		--fileClose( rawFileHandle )
		
		--local txd = engineLoadTXD( "@client/data/raw." .. modelID .. ".txd" )
		local txd = engineLoadTXD( base64Decode( basedRaw ) )
		engineImportTXD( txd, modelID )
		--fileDelete( "@client/data/raw." .. modelID .. ".txd" )
		
		-- dff
		basedRaw = teaDecode( base64Encode( fileGetContents( "client/data/model/" .. modelID .. ".dff" ) ), Model.teaKey )
		--rawFileHandle = fileCreate( "@client/data/raw." .. modelID .. ".dff" )
		--fileWrite( rawFileHandle, base64Decode( basedRaw ) )
		--fileClose( rawFileHandle )
		
		--local dff = engineLoadDFF( "@client/data/raw." .. modelID .. ".dff" )
		local dff = engineLoadDFF( base64Decode( basedRaw ) )
		engineReplaceModel( dff, modelID )
		--fileDelete( "@client/data/raw." .. modelID .. ".dff" )
	end;
	
	-- Добавляет модель в очередь на перезагрузку из сервера
	-- После загрузки она будет сразу заменена
	-- Запускает обработку очереди, если обработка еще не запущена
	_addToReloadQueue = function( modelID )
		if ( Model._reloadQueueKeys[ modelID ] == nil ) then
			-- Еще нет в очереди, добавляем
			Model._reloadQueueKeys[ modelID ] = true
			Model._reloadQueue[ #Model._reloadQueue + 1 ] = modelID
			
			if ( not Model._waitingForModelDownload ) then
				-- Загрузка файлов не ожидается, следовательно, обработка очереди остановлена - запускаем
				Model._handleReloadQueue()
			end
		end
	end;
	
	-- Берет последнюю модель из очереди и запрашивает ее загрузку у сервера, если очередь не пуста
	_handleReloadQueue = function()
		if ( #Model._reloadQueue ~= 0 ) then
			local modelID = table.remove( Model._reloadQueue )
			Model._reloadQueueKeys[ modelID ] = nil
			
			-- Проверяем наличие файла 
			local needDownload = false
			if ( fileExists( "client/data/model/" .. modelID .. ".dff" ) ) then
				-- dff уже есть, сверяем хэш
				if ( hash( "md5", fileGetContents( "client/data/model/" .. modelID .. ".dff" ) ) ~= Model.models[ modelID ].dffHash ) then
					-- Хэш не совпал
					needDownload = true
				end
			else
				-- dff нет
				needDownload = true
			end
			
			if ( fileExists( "client/data/model/" .. modelID .. ".txd" ) ) then
				-- txd уже есть, сверяем хэш
				if ( hash( "md5", fileGetContents( "client/data/model/" .. modelID .. ".txd" ) ) ~= Model.models[ modelID ].txdHash ) then
					-- Хэш не совпал
					needDownload = true
				end
			else
				-- txd нет
				needDownload = true
			end
			
			if ( Model.models[ modelID ].colHash ~= nil ) then
				if ( fileExists( "client/data/model/" .. modelID .. ".col" ) ) then
					-- col уже есть, сверяем хэш
					if ( hash( "md5", fileGetContents( "client/data/model/" .. modelID .. ".col" ) ) ~= Model.models[ modelID ].colHash ) then
						-- Хэш не совпал
						needDownload = true
					end
				else
					-- col нет
					needDownload = true
				end
			end
			
			if ( needDownload ) then
				if ( not Model._waitingForModelDownload ) then
					-- Загрузка файлов не ожидается, следовательно, обработка очереди остановлена - запускаем
					Model._lastQueueLoadedModelCount = 0
					
					GUI.sendJS( "Model.setStatus", "Загрузка моделей" )
					GUI.sendJS( "Model.showLoading" )
				
					Model._waitingForModelDownload = true
				end
				
				triggerServerEvent( "Model.onClientRequestFiles", resourceRoot, modelID )
			else
				Model._replaceModel( modelID )
			end
		end 
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Сервер прислал новый список моделей
	onModelListUpdate = function( modelList )
		-- Проходимся по списку и добавляем в  очередь на загрузку все, что изменилось или не существует
		Debug.info( "onModelListUpdate", modelList, Model.models )
		
		for modelID, modelData in pairs( modelList ) do
			if ( Model.models[ modelID ] == nil or ( modelData.dffHash ~= Model.models[ modelID ].dffHash ) or ( modelData.txdHash ~= Model.models[ modelID ].txdHash ) or ( modelData.colHash ~= Model.models[ modelID ].colHash ) ) then
				-- Новая модель или файл был изменен
				Model.models[ modelID ] = {
					dffHash = modelData.dffHash;
					txdHash = modelData.txdHash;
					colHash = modelData.colHash;
				}
				
				Model._addToReloadQueue( modelID )
			end
		end
	end;
	
	-- Сервер прислал новый файл
	onServerSentFiles = function( modelID, encodedDFF, encodedTXD, encodedCOL )
		Model._waitingForModelDownload = false
		
		local handle 
		
		handle = fileCreate( "client/data/model/" .. modelID .. ".dff" )
		fileWrite( handle, encodedDFF ) 
		fileClose( handle )
		
		handle = fileCreate( "client/data/model/" .. modelID .. ".txd" )
		fileWrite( handle, encodedTXD ) 
		fileClose( handle )
		
		if ( encodedCOL ~= nil ) then
			handle = fileCreate( "client/data/model/" .. modelID .. ".col" )
			fileWrite( handle, encodedCOL ) 
			fileClose( handle )
		else
			if ( fileExists( "client/data/model/" .. modelID .. ".col" ) ) then
				fileDelete( "client/data/model/" .. modelID .. ".col" )
			end
		end
		
		Model._replaceModel( modelID )
		Model._lastQueueLoadedModelCount = Model._lastQueueLoadedModelCount + 1
		
		if ( #Model._reloadQueue == 0 ) then
			-- Конец очереди
			GUI.sendJS( "Model.hideLoading" )
		else
			-- Еще есть модели в очереди
			Model._handleReloadQueue()
		end
	end;
	
	onDownloadProgressUpdate = function( progress )
		Debug.info( progress )
		GUI.sendJS( "Model.setProgress", progress.percentComplete )
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Model.init )