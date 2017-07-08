--[[
	Винилы на транспортных средствах
--]]

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "VehicleVinyl.onClientRequestFile", true )							-- Клиент запрашивает загрузку файла ( string vinylID )
addEvent( "VehicleVinyl.onClientRequestVinylList", true )

--------------------------------------------------------------------------------
--<[ Модуль VehicleVinyl ]>-----------------------------------------------------
--------------------------------------------------------------------------------
VehicleVinyl = {
	categories = {};		-- categoryID => {}
	vinyls = {};			-- vinylID => {  }
	
	_vinylFiles = {};		-- vinylID => fileContents
	
	init = function()
		-- Загружаем из базы категории и типы винилов
		local isSuccess, result = DB.syncQuery( "SELECT * FROM mtaw.vinyl_category" )
		
		if ( not isSuccess ) then 
			Debug.critical( "Unable to load vinyl categories" )
			
			return nil 
		end
		
		local vinylCategories = {}
		local loadedVinylCategoryCount = 0
		for _, row in pairs( result ) do
			vinylCategories[ row.id ] = row.name
			loadedVinylCategoryCount = loadedVinylCategoryCount + 1
		end
		
		VehicleVinyl.categories = vinylCategories
		
		isSuccess, result = DB.syncQuery( "SELECT * FROM mtaw.vinyl" )
		
		if ( not isSuccess ) then 
			Debug.critical( "Unable to load vinyl categories" )
			
			return nil 
		end
		
		local vinyls = {}
		local loadedVinylCount = 0
		for _, row in pairs( result ) do
			local colorable = true
			if ( row.colorable ~= 1 ) then
				colorable = false
			end
			
			-- Проверяем наличие файла
			if ( not fileExists( "server/data/vinyl/" .. row.id .. ".png" ) ) then
				Debug.critical( "Unable to load vinyl " .. row.id .. " - file doesn't exist" )
			
				return nil 
			end	
			
			-- Загружаем файл в оперативную память
			VehicleVinyl._vinylFiles[ row.id ] = fileGetContents( "server/data/vinyl/" .. row.id .. ".png" )
			
			vinyls[ row.id ] = {
				--name = row.name;
				category = row.category;
				width = row.width;
				height = row.height;
				colorable = colorable;
				fileHash = hash( "md5", fileGetContents( "server/data/vinyl/" .. row.id .. ".png" ) ):sub( 1, 8 )
			}
			
			loadedVinylCount = loadedVinylCount + 1
		end
		
		VehicleVinyl.vinyls = vinyls
		
		Debug.info( "Loaded " .. loadedVinylCategoryCount .. " vinyl categories and " .. loadedVinylCount .. " vinyls" )
		
		Main.setModuleLoaded( "VehicleVinyl", 1 )
		
		-- Периодически проверяем, не появилось ли новых винилов
		-- TODO
		
		addEventHandler( "Main.onServerLoad", resourceRoot, VehicleVinyl.onServerLoad )
	end;
	
	onServerLoad = function()
		addEventHandler( "VehicleVinyl.onClientRequestVinylList", resourceRoot, VehicleVinyl.onClientRequestVinylList )
		addEventHandler( "VehicleVinyl.onClientRequestFile", resourceRoot, VehicleVinyl.onClientRequestFile )
		
		-- Test
		Command.add( "vinyl", "none", "<ID варианта>", "Применить винил к текущему транспорту", function( playerElement, cmd, variant )
			if ( variant == nil ) then
				Chat.addMessage( playerElement, "/vinyl <ID варианта>" )
				Chat.addMessage( playerElement, "  0 - убрать винил" )
				Chat.addMessage( playerElement, "  1 - Infernus[411] - разноцветная бабочка" )
				Chat.addMessage( playerElement, "  2 - Infernus[411] - черная бабочка" )
				Chat.addMessage( playerElement, "  3 - Savanna[567] - огонь возле колеса" )
			
				return nil
			end
			
			variant = tonumber( variant )
			
			local veh = getPedOccupiedVehicle( client )
			if ( veh ~= false ) then
				local vinyls = nil

				if ( variant == 1 ) then
					-- Бабочка
					vinyls = {
						{ 
							id = 1;	--бабочка
							x = 826;
							y = 1395;
							w = 907;
							h = 272;
							a = 0;
							c = 0xFFFFCC00;
							m = 1;
						},
						{ 
							id = 5;	--Sparco
							x = 0;
							y = 1792;
							w = 512;
							h = 256;
							a = 0;
							c = 0xFFFF0000;
							m = 0;
						},
						{ 
							id = 4;	--Alpine
							x = 512;
							y = 1792;
							w = 512;
							h = 256;
							a = 0;
							c = 0xFF00FF00;
							m = 0;
						},
						{ 
							id = 3;	--NOS
							x = 1024;
							y = 1792;
							w = 512;
							h = 256;
							a = 0;
							c = 0xFF0000FF;
							m = 0;
						},
						{ 
							id = 6;	--Formula drift
							x = 1536;
							y = 1792;
							w = 512;
							h = 256;
							a = 0;
							c = 0xFF0077FF;
							m = 0;
						}
					}
				elseif ( variant == 2 ) then
					-- Черная бабочка
					vinyls = {
						{ 
							id = 1;	--бабочка
							x = 826;
							y = 1395;
							w = 907;
							h = 272;
							a = 0;
							c = 0xFF000000;
							m = 1;
						},
						{ 
							id = 5;	--Sparco
							x = 0;
							y = 1792;
							w = 512;
							h = 256;
							a = 0;
							c = 0xFF000000;
							m = 0;
						},
						{ 
							id = 4;	--Alpine
							x = 512;
							y = 1792;
							w = 512;
							h = 256;
							a = 0;
							c = 0xFF000000;
							m = 0;
						},
						{ 
							id = 3;	--NOS
							x = 1024;
							y = 1792;
							w = 512;
							h = 256;
							a = 0;
							c = 0xFF000000;
							m = 0;
						},
						{ 
							id = 6;	--Formula drift
							x = 1536;
							y = 1792;
							w = 512;
							h = 256;
							a = 0;
							c = 0xFF000000;
							m = 0;
						}
					}
				elseif ( variant == 3 ) then
					-- Огонь 
					vinyls = {
						{ 
							id = 2;	--огонь
							x = 331;
							y = 1446;
							w = 702;
							h = 200;
							a = 0;
							c = 0xFFFF2200;
							m = 1;
						},
						{ 
							id = 5;	--Sparco
							x = 0;
							y = 1792;
							w = 512;
							h = 256;
							a = 0;
							c = 0xFF000000;
							m = 0;
						},
						{ 
							id = 4;	--Alpine
							x = 512;
							y = 1792;
							w = 512;
							h = 256;
							a = 0;
							c = 0xFF000000;
							m = 0;
						},
						{ 
							id = 3;	--NOS
							x = 1024;
							y = 1792;
							w = 512;
							h = 256;
							a = 0;
							c = 0xFF000000;
							m = 0;
						},
						{ 
							id = 6;	--Formula drift
							x = 1536;
							y = 1792;
							w = 512;
							h = 256;
							a = 0;
							c = 0xFF000000;
							m = 0;
						}
					}
				end
		
				VehicleVinyl.setVehicleVinyls( veh, vinyls )
				
				Chat.addMessage( client, "Винил обновлен" )
			end
		end )
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
	
	setVehicleVinyls = function( vehicle, vinyls )
		if not validVar( vehicle, "vehicle", "vehicle" ) then return nil end
		if not validVar( vinyls, "vinyls", { "table", "nil" } ) then return nil end

		if ( vinyls ~= nil ) then
			setElementData( vehicle, "VehicleVinyl", VehicleVinyl.serialize( vinyls ) )
		else
			setElementData( vehicle, "VehicleVinyl", false )
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	onClientRequestVinylList = function()
		triggerClientEvent( client, "VehicleVinyl.onServerResponseVinylList", resourceRoot, VehicleVinyl.categories, VehicleVinyl.vinyls )
	end;
	
	onClientRequestFile = function( vinylID )
		Debug.info( "onClientRequestFile" )
		if ( VehicleVinyl.vinyls[ vinylID ] ~= nil ) then
			triggerLatentClientEvent( client, "VehicleVinyl.onServerSentFile", 200000, false, resourceRoot, vinylID, VehicleVinyl._vinylFiles[ vinylID ] )
		else
			Debug.info( "Vinyl " .. vinylID .. " not found" )
		end
	end;
};
addEventHandler( "onResourceStart", resourceRoot, VehicleVinyl.init )