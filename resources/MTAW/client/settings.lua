--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Settings.onSettingChanged", false )	-- Изменилась какая-то настройка ( categoryName, itemName, oldValue, newValue ). Чтобы запретить установку, вызывать cancelEvent

--------------------------------------------------------------------------------
--<[ Модуль Settings ]>---------------------------------------------------------
--------------------------------------------------------------------------------
Settings = {	
	isVisible = false;
	
	init = function()
		addEventHandler( "Main.onClientLoad", root, Settings.onClientLoad )
	end;
	
	onClientLoad = function()
		GUI.addBrowserEventHandler( "Settings.toggleVisible", Settings.toggleVisible )
		GUI.addBrowserEventHandler( "Settings.save", Settings._saveGuiConfig )
		
		-- Инициализация настроек - отправляем шаблон и настройки
		GUI.sendJS( "Settings.setTemplate", Configuration.template )
		Settings.sendToGUI();
		
		-- Debug - сразу открываем настройки
		--Settings.setVisible( true );
	end;
	
	-- Сделать меню настроек видимым
	-- > isVisible bool - true, чтобы показать меню настроек
	-- = void
	setVisible = function( isVisible )
		if not validVar( isVisible, "isVisible", "boolean" ) then return nil end
		
		if ( isVisible ) then
			-- Обновляем список настроек
			Settings.sendToGUI()
			
			-- Показываем меню настроек
			GUI.sendJS( "Settings.setVisible", true )
			Cursor.show( "Settings" )
			Crosshair.disable( "Settings" )
			
			Settings.isVisible = true
		else
			GUI.sendJS( "Settings.setVisible", false )
			Cursor.hide( "Settings" )
			Crosshair.cancelDisabling( "Settings" )
			
			Settings.isVisible = false
		end
	end;
	
	-- Показать / спрятать меню настроек
	-- = void
	toggleVisible = function()
		Settings.setVisible( not Settings.isVisible )
	end;
	
	-- Сохранить настройки, которые пришли из GUI
	_saveGuiConfig = function( guiCFG )
		Debug.info( "Сохраняем настройки:", guiCFG )
		
		local needRestart = false
		
		for categoryAlias, items in pairs( guiCFG ) do
			for itemAlias, itemValue in pairs( items ) do
				local oldValue = nil
				if ( CFG[ categoryAlias ][ itemAlias ] ~= itemValue ) then
					oldValue = CFG[ categoryAlias ][ itemAlias ]
				end
				Configuration.setValue( categoryAlias, itemAlias, itemValue )
				
				if ( oldValue ~= nil ) then
					if ( not triggerEvent( "Settings.onSettingChanged", resourceRoot, categoryAlias, itemAlias, oldValue, itemValue ) ) then
						-- Отменили действие
						Popup.show( "Установка настройки " .. categoryAlias .. " " .. categoryAlias .. " отменена" )
						Configuration.setValue( categoryAlias, itemAlias, oldValue )
					end
				end
				
				if ( Configuration.template[ categoryAlias ].items[ itemAlias ].needRestart ) then
					needRestart = true
				end
			end
		end
		Configuration.save();
		
		Popup.show( "Настройки сохранены", "success", "cogs" )
		
		if ( needRestart ) then
			-- TODO перенести на dialog
			Dialog.show( "Некоторые измененные настройки будут применены только после следующего входа на сервер. Переподключиться сейчас?", "question", {
				cancel = {
					text = "Нет",
					icon = "times",
					class = "button-float-left",
					handler = function() 
						Dialog.hide() 
					end
				},
				confirm = {
					text = "Переподключиться",
					icon = "check",
					class = "button-float-right",
					handler = function() 
						Dialog.hide() 
						Main.reconnect()
					end
				}
			} )
		end
	end;
	
	-- Отправить текущие настройки Configuration в GUI. Сбросит все несохраненные настройки на GUI
	-- = void
	sendToGUI = function()
		GUI.sendJS( "Settings.setConfiguration", CFG )
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, Settings.init )