--------------------------------------------------------------------------------
--<[ Модуль CharacterCreator ]>-------------------------------------------------
--------------------------------------------------------------------------------
CharacterCreator = {
	isVisible = false;
	
	init = function()
		addEventHandler( "Main.onClientLoad", root, CharacterCreator.onClientLoad )
	end;
	
	onClientLoad = function()
		GUI.addBrowserEventHandler( "CharacterCreator.show", CharacterCreator.show )
		GUI.addBrowserEventHandler( "CharacterCreator.hide", CharacterCreator.hide )
		GUI.addBrowserEventHandler( "CharacterCreator.toggle", CharacterCreator.toggle )
		GUI.addBrowserEventHandler( "CharacterCreator.setPreviewSkin", CharacterCreator.onGuiSetPreviewSkin )
		GUI.addBrowserEventHandler( "CharacterCreator.createCharacter", CharacterCreator.onCharacterCreateAttempt )
	end;
	
	-- Показать меню создания нового персонажа
	-- = void
	show = function()
		-- Запрашиваем статитику слотов персонажей
		CallbackEvent.trigger( "CharacterCreator.getSlotStatistic", function( slotStatistic ) 
			-- Скрываем персонаж, который был выбран в лобби
			GUI.sendJS( "Lobby.selectCharacter", false )
			
			-- Показываем меню
			GUI.sendJS( "CharacterCreator.setAvailableSkins", ARR.characterCreatorSkins )
			GUI.sendJS( "CharacterCreator.setSlotStatistic", slotStatistic )
			GUI.sendJS( "CharacterCreator.setVisible", true )
			
			Cursor.show( "CharacterCreator" )
			Crosshair.disable( "CharacterCreator" )
			
			CharacterCreator.isVisible = true
		end )
	end;
	
	-- Спрятать меню создания нового персонажа
	-- = void
	hide = function()
		-- Скрываем меню
		GUI.sendJS( "CharacterCreator.setVisible", false )
		Cursor.hide( "CharacterCreator" )
		Crosshair.cancelDisabling( "CharacterCreator" )
		
		-- Скрываем превью
		Lobby.hidePreviewPed()
		
		CharacterCreator.isVisible = false
	end;
	
	-- Спрятать / показать меню нового персонажа
	-- = void
	toggle = function()
		if ( CharacterCreator.isVisible ) then
			CharacterCreator.hide()
		else
			CharacterCreator.show()
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- GUI запросил установку превью скина
	onGuiSetPreviewSkin = function( skinModel ) 
		Lobby.setPreviewPed( tonumber( skinModel ) )
	end;
	
	-- Игрок пытается создать персонаж
	onCharacterCreateAttempt = function( name, surname, gender, skinModel )
		CallbackEvent.trigger( "CharacterCreator.createAttempt", name, surname, gender, skinModel, function( isSuccess, errorMessage ) 
			-- Сервер прислал инфо о том, создался персонаж или нет
			if ( isSuccess ) then
				-- Персонаж был создан
				Lobby.updateCharacterList()
				CharacterCreator.hide()
			else
				-- Ошибка создания персонажа
				Popup.show( errorMessage, "error" )
			end
		end )
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, CharacterCreator.init )