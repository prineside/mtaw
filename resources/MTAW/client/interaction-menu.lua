--------------------------------------------------------------------------------
--<[ Модуль InteractionMenu ]>--------------------------------------------------
--------------------------------------------------------------------------------
InteractionMenu = {
	isVisible = false;
	showTick = getTickCount();		-- tickCount, когда меню было показано
	
	handlers = {};					-- Текущие обработчики пунктов меню ("function: 22E91048" => function() ... end)
	
	init = function()
		addEventHandler( "Main.onClientLoad", resourceRoot, InteractionMenu.onClientLoad )
	end;
	
	onClientLoad = function()
		-- Игрок выключил курсор на Esc, прячем меню
		addEventHandler( "Cursor.onHiddenByEsc", resourceRoot, function()
			if ( InteractionMenu.isVisible ) then
				InteractionMenu.hide()
			end
		end )
		
		-- Игрок нажал на E, когда меню открыто - скрываем
		bindKey( "e", "down", function()
			if ( InteractionMenu.isVisible and getTickCount() - InteractionMenu.showTick > 20 ) then
				InteractionMenu.hide()
			end
		end )
		
		-- Игрок открыт инвентарь - скрываем меню
		addEventHandler( "Inventory.onSetActive", resourceRoot, function()
			if ( InteractionMenu.isVisible and getTickCount() - InteractionMenu.showTick > 20 ) then
				InteractionMenu.hide()
			end
		end )
		
		GUI.addBrowserEventHandler( "InteractionMenu.click", function( clickedFunctionAlias ) 
			Debug.info( "Нажали на кнопку с функцией:", clickedFunctionAlias )
			InteractionMenu.handlers[ clickedFunctionAlias ]()
		end )
	end;
	
	-- Показать меню взаимодействия
	-- > title string - заголовок меню
	-- > description string - описание под заголовком
	-- > menuItems table - пункты меню - таблица вида: {  { icon = "money"; title = "Передать деньги"; handler = function() ... end }, ... }
	-- > iconContents string / nil - HTML значка в заголовке меню (например: "<i class='fa fa-home'></i>" или изображение аватарки)
	-- = void
	show = function( title, description, menuItems, iconContents )
		if ( not InteractionMenu.isVisible ) then
			-- Включаем курсор
			local screenX, screenY = guiGetScreenSize()
			Cursor.show( "InteractionMenu", screenX * 0.53 + 110, screenY * 0.4 + 53 )
			Crosshair.disable( "InteractionMenu" )
			
			-- Показываем меню в GUI
			GUI.sendJS( "InteractionMenu.show", title, description, menuItems, iconContents )
			
			-- Создаем массив "алиас функции" => функция (для обработки событий из GUI)
			for k, item in pairs( menuItems ) do
				InteractionMenu.handlers[ tostring( item.handler ) ] = item.handler
			end
			
			InteractionMenu.isVisible = true
			InteractionMenu.showTick = getTickCount()
		else
			-- Меню уже показано
		end
	end;
	
	-- Спрятать меню
	-- = void
	hide = function()
		GUI.sendJS( "InteractionMenu.hide" )
		Cursor.hide( "InteractionMenu" )
		Crosshair.cancelDisabling( "InteractionMenu" )
		InteractionMenu.isVisible = false
		
		InteractionMenu.handlers = {}
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, InteractionMenu.init )