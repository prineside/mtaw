--------------------------------------------------------------------------------
--<[ Модуль GUI ]>--------------------------------------------------------------
--------------------------------------------------------------------------------
GUI = {
	screenSize = { x = 0; y = 0; };
	browser = nil;
	--guiBrowserElement = nil;
	overlay = nil;
	cursor = { x = 0; y = 0; };
	
	_guiSize = { width = 0; height = 0; scale = 1; };
	
	eventHandlers = {};
	toolTip = nil;
	
	guiKeyCodeToName = {};														-- Заполняется при инициализации, берет данные из ARR.guiKeyCodes
	
	init = function() 
		-- Инициализация массивов "код - название" для кнопок GUI
		GUI.guiKeyCodeToName = {
			codeToName = ARR.guiKeyCodes;
			nameToCode = {};
		};
		for c, n in pairs( ARR.guiKeyCodes ) do
			GUI.guiKeyCodeToName.nameToCode[ n ] = c
		end
		
		-- Создание браузера и загрузка GUI
		GUI.screenSize.x, GUI.screenSize.y = guiGetScreenSize()
		
		GUI.overlay = guiCreateStaticImage( 0, 0, GUI.screenSize.x, GUI.screenSize.y, "client/data/gui/img/transparent.png", false )
		
		--GUI.guiBrowserElement = guiCreateBrowser( 0, 0, GUI.screenSize.x, GUI.screenSize.y, true, true, false, GUI.overlay )
		--GUI.browser = guiGetBrowser( GUI.guiBrowserElement )
		GUI._guiSize.scale = CFG.graphics.guiScale
		
		if ( CFG.graphics.guiScale ~= 1 ) then
			GUI._guiSize.width, GUI._guiSize.height = GUI.screenSize.x / CFG.graphics.guiScale, GUI.screenSize.y / CFG.graphics.guiScale
			local aspect = GUI._guiSize.width / GUI._guiSize.height
			if ( GUI._guiSize.width < 960 ) then
				GUI._guiSize.width = 960
				GUI._guiSize.height = GUI._guiSize.width / aspect 
				GUI._guiSize.scale = GUI.screenSize.x / GUI._guiSize.width
			end
			GUI.browser = createBrowser( GUI._guiSize.width, GUI._guiSize.height, true, true )
		else
			GUI._guiSize.width, GUI._guiSize.height = GUI.screenSize.x, GUI.screenSize.y
			GUI.browser = createBrowser( GUI.screenSize.x, GUI.screenSize.y, true, true )
		end
		
		Main.setModuleLoaded( "GUI", 0.3 )
		
		addEventHandler( "onClientBrowserCreated", GUI.browser, function()
			Main.setModuleLoaded( "GUI", 0.6 )
			
			-- Автоматически включаем консоль, если отладка
			if ( DEBUG_MODE ) then
				local guiBrowserDevtoolsEnabled = true
				toggleBrowserDevTools( GUI.browser, guiBrowserDevtoolsEnabled )
			else
				local guiBrowserDevtoolsEnabled = false
			end
			
			bindKey( "f7", "down", function()
				guiBrowserDevtoolsEnabled = not guiBrowserDevtoolsEnabled
				toggleBrowserDevTools( GUI.browser, guiBrowserDevtoolsEnabled )
			end )
			
			bindKey( "f9", "down", function()
				guiSetVisible( GUI.overlay, not guiGetVisible( GUI.overlay ) )
			end )
		
			setBrowserAjaxHandler( GUI.browser, "client/data/gui/api.html", GUI.onBrowserEvent )
			
			loadBrowserURL( GUI.browser, "http://mta/local/client/data/gui/index.html" )
			addEventHandler( "onClientRender", root, GUI._renderBrowser )
			
			addEventHandler( "onClientMouseMove", getRootElement(), function( x, y )
				x = x / GUI._guiSize.scale
				y = y / GUI._guiSize.scale
			
				GUI.cursor.x = x
				GUI.cursor.y = y
				
				injectBrowserMouseMove( GUI.browser, x, y )
			end )
			
			addEventHandler( "onClientClick", root, function( button, state, absoluteX, absoluteY )
				if ( state == "down" ) then
					injectBrowserMouseDown( GUI.browser, button )
				else
					injectBrowserMouseUp( GUI.browser, button )
				end
			end )
			
			addEventHandler( "onClientMouseWheel", getRootElement(), function( upOrDown )
				injectBrowserMouseWheel( GUI.browser, 40 * upOrDown, 0 )
			end )
			 
			focusBrowser( GUI.browser )
			
			addEventHandler( "onClientBrowserDocumentReady", GUI.browser, function()
				Main.setModuleLoaded( "GUI", 1 )
			end )
		end )
		
		-- Если фокус убран из основного GUI, пишем в консоль
		addEventHandler( "onClientGUIBlur", GUI.browser, function()
			Debug.info( "Основной GUI потерял фокус, возвращаем" )
			setTimer( function()
				focusBrowser( GUI.browser )
			end, 50, 1 )
		end )
		
		-- Вызов Lua из браузера 
		GUI.addBrowserEventHandler( "GUI.RunLua", function( src )
			if ( DEBUG_MODE ) then
				return jsonEncode( pack( loadstring( src )() ) )
			end
		end )
	end;
	
	-- Вызывается каждый фрейм для отрисовки основного браузера
	_renderBrowser = function()
		dxDrawImage( 0, 0, GUI.screenSize.x, GUI.screenSize.y, GUI.browser, 0, 0, 0, tocolor(255,255,255,255), false )
	end;
	
	-- Отправить в основной браузер Javascript
	-- > functionName string - функция, которую необходимо выполнить
	-- > ... mixed - аргументы функции
	-- = void
	sendJS = function( functionName, ... )
		if ( GUI.browser == nil ) then
			-- Браузер еще не загружен
			outputDebugString( "Browser is not loaded yet, can't send JS. See console for passed data" )
			outputConsole( dumpvar( arg ) )
			return nil
		end
	
		js = functionName .. "("
		
		local argCount = #arg
		
		for i, v in ipairs( arg ) do
			local argType = type( v )
			if ( argType == "string" ) then
				js = js .. "'" .. addslashes( v ) .. "'"
			elseif ( argType == "boolean" ) then
				if ( v ) then js = js .. "true" else js = js .. "false" end
			elseif ( argType == "nil" ) then
				js = js .. "undefined"
			elseif ( argType == "table" ) then
				js = js .. jsonEncode( v )
			elseif ( argType == "number" ) then
				js = js .. v
			elseif ( argType == "function" ) then
				js = js .. "'" .. addslashes( tostring( v ) ) .. "'"
			elseif ( argType == "userdata" ) then
				js = js .. "'" .. addslashes( tostring( v ) ) .. "'"
			else
				outputDebugString( "Unknown type: " .. type( v ) )
			end
			
			argCount = argCount - 1;
			if ( argCount ~= 0 ) then
				js = js .. ","
			end
		end
		js = js .. ");"
		
		executeBrowserJavascript( GUI.browser, js ) 
	end;
	
	-- Добавить обработчик события браузера (вызванного через Main.sendEvent)
	-- Если обработчик возвращает не nil, остальные обработчики не вызываются (отправляется ответ в браузер)
	-- > eventName string - название события, которое будет вызвано в браузере через Main.sendEvent
	-- > handler function - функция, которая будет обрабатывать событие: handler( arg1, ... )
	-- = void
	addBrowserEventHandler = function( eventName, handler )
		if ( GUI.eventHandlers[ eventName ] == nil ) then
			GUI.eventHandlers[ eventName ] = {}
		end
		
		table.insert( GUI.eventHandlers[ eventName ], handler )
	end;
	
	-- Код кнопки в GUI -> название кнопки
	-- > keyCode string - код кнопки из GUI
	-- = string / nil keyName
	keyCodeToKeyName = function( keyCode )
		if not validVar( keyCode, "keyCode", "string" ) then return nil end
	
		return GUI.guiKeyCodeToName.codeToName[ keyCode ]
	end;
	
	-- Название кнопки -> код кнопки в GUI
	-- > keyName string
	-- = string / nil keyCode
	keyNameToKeyCode = function( keyName )
		if not validVar( keyName, "keyName", "string" ) then return nil end
		
		return GUI.guiKeyCodeToName.nameToCode[ keyName ]
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Пришло событие от браузера (обработчик ajax-запросов на http://mta/local/client/data/gui/index.html
	onBrowserEvent = function( get, post ) 
		local data = jsonDecode( urldecode( post.data ) )
		local eventName = data.event
		data.event = nil
		
		local newArgs = {}
		for k, v in orderedPairs( data ) do
			table.insert( newArgs, v )
		end
		
		if ( GUI.eventHandlers[ eventName ] ~= nil ) then
			for k, v in pairs( GUI.eventHandlers[ eventName ] ) do
				local returnValue = v( unpack( newArgs ) )
				if ( returnValue ~= nil ) then
					return tostring( returnValue )
				end
			end
		end
		
		return "No response"
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, GUI.init )