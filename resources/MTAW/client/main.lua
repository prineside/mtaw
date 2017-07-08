if ( DEBUG_MODE ) then
	-- Настройки отладки
	DebugCfg = {
		openSettings = not true;
		skipLobby = true;														-- Не показывать лобби, сразу входить в игру
		openInventory = not true; 												-- Сразу открывать инвентарь
	}
end

--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Main.onClientLoad", true )											-- Загружены все модули клиента, и их можно использовать ()

--------------------------------------------------------------------------------
--<[ Модуль Main ]>-------------------------------------------------------------
--------------------------------------------------------------------------------
Main = {
	fpsLimit = 45; -- Не больше 50

	-- Список модулей, которые должны сообщить Main о своей инициализации, чтобы запустить все
	moduleLoadingStatus = { 
		Account = 0; CallbackEvent = 0; Character = 0; Chat = 0; Chunk = 0; Configuration = 0; Control = 0; Debug = 0; DelayedEvent = 0; Dimension = 0; GUI = 0; Herb = 0; Lobby = 0; Objective = 0; Popup = 0; Time = 0; VehicleVinyl = 0; WebBrowser = 0;
	};
	moduleLoadingTimer = nil;

	-- Точка входа в программу. Это единственное, что само по себе загружается, остальное обрабатывает события
	-- Ждет загрузки всех необходимых модулей, затем вызывает Main.onClientLoad
	init = function()
		-- Обработчики событий
		addEventHandler( "Main.onClientLoad", resourceRoot, Main.onClientLoad )
		
		-- Debug
		if ( DEBUG_MODE ) then
			outputDebugString( "==== Debug mode ====" )
			setDevelopmentMode( true, true )
		end
		
		setDevelopmentMode( true, true )
		
		-- Ожидание загрузки остальных модулей
		local screenX, screenY = guiGetScreenSize()
		local loadingPercentLabel = guiCreateLabel( screenX / 2 - 150, screenY / 2 - 15, 300, 30, "Загрузка: 0%", false )
		guiLabelSetHorizontalAlign( loadingPercentLabel, "center" )
		guiLabelSetVerticalAlign( loadingPercentLabel, "center" )
		
		local loadingLineWrap = guiCreateStaticImage( screenX / 2 - 50, screenY / 2 + 15, 100, 1, "client/data/gui/img/modules-loading-line-wrap.png", false, nil )
		local loadingLine = guiCreateStaticImage( 0, 0, 0, 1, "client/data/gui/img/modules-loading-line.png", false, loadingLineWrap )
		
		local modulesLoadingTargetCoeff = tableRealSize( Main.moduleLoadingStatus )
		local modulesLoadingStartTime = getTickCount()
		local modulesLoadTimeout = 45
		Main.moduleLoadingTimer = setTimer( function()
			if ( getTickCount() - modulesLoadingStartTime < modulesLoadTimeout * 1000 ) then
				-- Прошло меньше 30 секунд с начала загрузки
				local totalCoeff = 0
				for moduleName, loadingCoeff in pairs( Main.moduleLoadingStatus ) do
					totalCoeff = totalCoeff + loadingCoeff
				end
				
				if ( totalCoeff ~= modulesLoadingTargetCoeff ) then
					guiSetText( loadingPercentLabel, "Загрузка: " .. math.floor( totalCoeff / modulesLoadingTargetCoeff * 100 ) .. "%" )
					guiSetSize( loadingLine, totalCoeff / modulesLoadingTargetCoeff * 100, 1, false )
				else
					-- Все модули загружены
					Debug.info( "Все модули загружены" )
					destroyElement( loadingPercentLabel )
					destroyElement( loadingLine )
					destroyElement( loadingLineWrap )
					killTimer( Main.moduleLoadingTimer )
					triggerEvent( "Main.onClientLoad", root )
					triggerServerEvent( "Main.onClientLoad", root, localPlayer )
				end
			else
				-- Прошло больше modulesLoadTimeout секунд, сообщаем об ошибке
				for moduleName, loadingCoeff in pairs( Main.moduleLoadingStatus ) do
					if ( loadingCoeff < 1 ) then
						outputDebugString( "Модуль " .. moduleName .. " был загружен до " .. ( loadingCoeff * 100 ) .. "% за " .. modulesLoadTimeout .. " секунд", 1 )
						guiSetText( loadingPercentLabel, "Ошибка загрузки модуля " .. moduleName )		
						outputChatBox( "Во время загрузки клиента произошла ошибка", 255, 50, 50 )
						outputChatBox( "Модуль " .. moduleName .. " был загружен до " .. ( loadingCoeff * 100 ) .. "% за " .. modulesLoadTimeout .. " секунд", 255, 255, 255 )
						outputChatBox( "Отчет об ошибке отправлен на сервер", 255, 255, 255 )
						outputChatBox( "Попробуйте подключиться заново", 127, 255, 127 )
					end
				end
				killTimer( Main.moduleLoadingTimer )
			end
		end, 50, 0 )
	end;
	
	-- Модули по мере своей загрузки должны сообщать о своей загрузке
	-- Эта функция должна вызываться после инициализации каждого модуля
	-- > moduleName string - название модуля (регистр имеет значение)
	-- > coeff number / nil - прогресс загрузки (от 0 до 1, по умолчанию 1)
	-- = void
	setModuleLoaded = function( moduleName, coeff )
		coeff = ( coeff == nil ) and 1 or coeff
		
		if ( Main.moduleLoadingStatus[ moduleName ] ~= nil ) then
			Main.moduleLoadingStatus[ moduleName ] = coeff
		end
	end;
	
	-- Переподключить игрока к серверу
	reconnect = function()
		triggerServerEvent( "Main.onClientRequestReconnect", resourceRoot )
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	-- Когда все необходимые модули загружены
	onClientLoad = function()
		-- Основная конфигурация
		fadeCamera( true )
		setPlayerHudComponentVisible( "all", false )
		Control.disable( "chatbox", "Main" )
		Control.disable( "radar", "Main" )
		Control.disable( "next_weapon", "Main" )
		Control.disable( "previous_weapon", "Main" )
		showChat( false )
		setFPSLimit( Main.fpsLimit )
		
		-- Настройка горячих клавиш
		bindKey( "f6", "down", Chat.toggleActive )
		
		Chat.addMessage( "Все модули клиента загружены" )
		
		-- Отладка
		---- Выводим в лог все события
		--[[
		addDebugHook( "preEvent", function( sourceResource, eventName, eventSource, eventClient, luaFilename, luaLineNumber, ... ) 
			local expl = explode( ".", eventName )
			if ( #expl ~= 1 and expl[ 1 ] ~= "Time" and expl[ 1 ] ~= "Popup" and expl[ 1 ] ~= "Chat" ) then
				Debug.coloredInfo( "#4CAF50", eventName, luaFilename, luaLineNumber, arg )
			end
		end )
		--]]
		
		---- Автоматически открываем инвентарь, если DebugCfg.openInventory
		addEventHandler( "Character.onCharacterChange", resourceRoot, function()
			if ( Character.isSelected() ) then
				if ( DEBUG_MODE and DebugCfg.openInventory ) then
					Inventory.setActive( true )
				end
			end
		end )
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Main.init )