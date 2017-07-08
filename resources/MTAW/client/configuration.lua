
CFG = {}					-- Таблица со всеми значениями конфигурации

--------------------------------------------------------------------------------
--<[ Модуль Configuration ]>----------------------------------------------------
--------------------------------------------------------------------------------
Configuration = {			-- Сам модуль
	template = {};

	init = function()
		-- Загрузка шаблона настроек
		Configuration.template = {}
		
		local rootNode = xmlLoadFile( "client/data/configuration/template.xml" )
		
		local categories = xmlNodeGetChildren( rootNode )
		for _, categoryNode in pairs( categories ) do
			-- Категория
			local categoryAlias = xmlNodeGetName( categoryNode )
			Configuration.template[ categoryAlias ] = {
				name = xmlNodeGetAttribute( categoryNode, "name" );
				items = {};
			}
			
			local items = xmlNodeGetChildren( categoryNode )
			for _, itemNode in pairs( items ) do
				-- Элемент в категории
				local itemAlias = xmlNodeGetName( itemNode )
				
				local itemTemplate = {
					type = xmlNodeGetAttribute( itemNode, "type" );
					min = xmlNodeGetAttribute( itemNode, "min" );
					max = xmlNodeGetAttribute( itemNode, "max" );
					default = xmlNodeGetAttribute( itemNode, "default" );
					bestPerformance = xmlNodeGetAttribute( itemNode, "bestPerformance" );
					needRestart = xmlNodeGetAttribute( itemNode, "needRestart" );
				}
				
				if ( itemTemplate.needRestart == "true" or itemTemplate.needRestart == true ) then
					itemTemplate.needRestart = true
				else
					itemTemplate.needRestart = false
				end
				
				local isSetting = xmlNodeGetAttribute( itemNode, "setting" );
				if ( isSetting == false or isSetting == "true" ) then
					isSetting = true
				else
					isSetting = false
				end
				itemTemplate.setting = isSetting
				
				if ( itemTemplate.type == "float" ) then
					-- float precision
					local precision = xmlNodeGetAttribute( itemNode, "precision" );
					if ( precision == false ) then
						itemTemplate.precision = 3
					else
						itemTemplate.precision = tonumber( precision )
					end
				end
				
				-- Ищем название и описание
				local itemChildren = xmlNodeGetChildren( itemNode )
				for _, itemChildNode in pairs( itemChildren ) do
					local subNodeName = xmlNodeGetName( itemChildNode )
					if ( subNodeName == "name" or subNodeName == "description" ) then
						itemTemplate[ subNodeName ] = xmlNodeGetValue( itemChildNode )
					end
				end
				
				if ( itemTemplate.type == "int" or itemTemplate.type == "float" ) then
					-- int, float
					itemTemplate.min = tonumber( itemTemplate.min )
					itemTemplate.max = tonumber( itemTemplate.max )
					itemTemplate.default = tonumber( itemTemplate.default )
					
					-- Функция слайдера
					if ( xmlNodeGetAttribute( itemNode, "slider" ) ) then
						itemTemplate.sliderFunction = xmlNodeGetAttribute( itemNode, "slider" )
					end
				elseif ( itemTemplate.type == "bool" ) then
					-- bool
					if ( itemTemplate.default == "true" ) then
						itemTemplate.default = true
					else
						itemTemplate.default = false
					end
				elseif ( itemTemplate.type == "string" ) then
					-- Строка - проверяем, есть ли options
					local itemChildrenNodes = xmlNodeGetChildren( itemNode )
					for _, itemChildNode in pairs( itemChildrenNodes ) do
						if ( xmlNodeGetName( itemChildNode ) == "options" ) then
							-- Есть <options>
							itemTemplate.options = {}
							
							local optionsNode = itemChildNode
							local optionsChildNode = xmlNodeGetChildren( optionsNode )
							for _, optionNode in pairs( optionsChildNode ) do
								itemTemplate.options[ xmlNodeGetAttribute( optionNode, "value" ) ] = xmlNodeGetValue( optionNode )
							end
							
							break
						end
					end
				end
				
				Configuration.template[ categoryAlias ].items[ itemAlias ] = itemTemplate
			end
		end
		
		xmlUnloadFile( rootNode )
		
		-- Загрузка конфигурации
		Configuration.reload()
		
		Main.setModuleLoaded( "Configuration", 1 )
	end;
	
	-- Перезагрузить настройки из файла
	-- = void
	reload = function()
		CFG = {}
	
		-- Загрузка стандартных значений из файла шаблона
		local rootNode = xmlLoadFile( "client/data/configuration/template.xml" )
		
		local categories = xmlNodeGetChildren( rootNode )
		for _, categoryNode in pairs( categories ) do
			local categoryAlias = xmlNodeGetName( categoryNode )
			CFG[ categoryAlias ] = {}
			
			local items = xmlNodeGetChildren( categoryNode )
			for _, itemNode in pairs( items ) do
				local itemAlias = xmlNodeGetName( itemNode )
			
				Configuration.setValue( categoryAlias, itemAlias, xmlNodeGetAttribute( itemNode, "default" ) )
			end
		end
		
		xmlUnloadFile( rootNode )
		
		-- Загрузка пользовательских настроек
		if ( fileExists( "@client/data/configuration/user.json" ) ) then
			outputConsole( "User settings exist" )
			
			local userSettings = fromJSON( fileGetContents( "@client/data/configuration/user.json" ) )

			for categoryName, categoryItems in pairs( userSettings ) do
				if ( CFG[ categoryName ] ~= nil ) then
					for itemName, itemValue in pairs( categoryItems ) do
						if ( CFG[ categoryName ][ itemName ] ~= nil ) then
							Configuration.setValue( categoryName, itemName, itemValue )
						else
							outputConsole( categoryName .. "." .. itemName .. " not exists" )
						end
					end
				end
			end
		end
	end;
	
	-- Устанавливает значение конфигурации, принимая во внимание min и max, устанавливает default, если значение указано неверно
	-- > categoryAlias string
	-- > itemAlias string
	-- > value mixed
	-- = void
	setValue = function( categoryAlias, itemAlias, value )
		if ( Configuration.template[ categoryAlias ] ~= nil ) then
			local itemTemplate = Configuration.template[ categoryAlias ].items[ itemAlias ]
			
			if ( itemTemplate ~= nil ) then
				if ( itemTemplate.type == "bool" ) then
					if ( value == true or value == "true" ) then
						CFG[ categoryAlias ][ itemAlias ] = true
					elseif ( value == false or value == "false" ) then
						CFG[ categoryAlias ][ itemAlias ] = false
					end
				elseif ( itemTemplate.type == "int" or itemTemplate.type == "float" ) then
					local n = tonumber( value )
					if ( n ~= nil ) then
						if ( not ( n < itemTemplate.min or n > itemTemplate.max ) ) then
							CFG[ categoryAlias ][ itemAlias ] = n
						end
					end
				elseif ( itemTemplate.type == "string" ) then
					-- TODO проверка options (в template, тот, что список допустимых значений)
					CFG[ categoryAlias ][ itemAlias ] = value
				end
			end
		end
	end;
	
	-- Сохранить конфигурацию в файл
	-- = void
	save = function()
		local handle = fileCreate( "@client/data/configuration/user.json" )
		fileWrite( handle, jsonEncode( CFG ) )
		fileClose( handle )
	end;
	
	-- Восстановить стандартные значения
	-- = void
	restoreDefaults = function()
		for categoryAlias, categoryData in pairs( Configuration.template ) do
			CFG[ categoryAlias ] = {}
			for itemAlias, itemTemplate in pairs( categoryData ) do
				CFG[ categoryAlias ][ itemAlias ] = itemTemplate.default
			end
		end
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Configuration.init, false, "high+9999" )