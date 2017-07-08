--------------------------------------------------------------------------------
--<[ Модуль GameGUI ]>----------------------------------------------------------
--------------------------------------------------------------------------------
GameGUI = {
	isVisible = false;
	
	init = function()
		addEventHandler( "Character.onCharacterChange", resourceRoot, GameGUI.onCharacterChange )
		addEventHandler( "Character.onDataChange", resourceRoot, GameGUI.onCharacterDataChange )
	end;
	
	-- Отобразить игровое GUI (здоровье, карта и т.д.)
	-- = void
	show = function()
		GUI.sendJS( "GUI.setVisible", true )
	end;
	
	-- Спрятать игровое GUI (например, автоматически вызывается при выходе в лобби, чтобы не мешало)
	-- = void
	hide = function()
		GUI.sendJS( "GUI.setVisible", false )
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Изменился текущий персонаж игрока
	onCharacterChange = function()
		-- GUI видно, когда персонаж в игре
		if ( not Character.isSelected() ) then
			GameGUI.hide()
		else
			GameGUI.show()
		end
	end;
	
	-- Изменились какие-то данные персонажа
	onCharacterDataChange = function( data )
		-- Обновлем показатели на GUI
		if ( data.health ~= nil ) then
			GUI.sendJS( "GUI.setHealth", data.health )
		end
		
		if ( data.money ~= nil ) then
			GUI.sendJS( "GUI.setMoney", data.money )
		end
		
		if ( data.satiety ~= nil ) then
			GUI.sendJS( "GUI.setSatiety", data.satiety )
		end
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, GameGUI.init )