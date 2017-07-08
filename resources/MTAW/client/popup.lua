--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Popup.onServerShowPopup", true )										-- Сервер показал popup ( string message, string / nil messageType, string / nil icon, number / nil delay )

--------------------------------------------------------------------------------
--<[ Модуль Popup ]>------------------------------------------------------------
--------------------------------------------------------------------------------
Popup = {
	init = function()
		addEventHandler( "Popup.onServerShowPopup", resourceRoot, Popup.onServerShowPopup )
		
		Main.setModuleLoaded( "Popup", 1 )
	end;
	
	-- Показать всплывающую подсказку
	-- > message string - текст подсказки
	-- > messageType string / nil - тип подсказки (по умолчанию info)
	-- > icon string / nil - значок возле подсказки (FontAwesome)
	-- > delay number / nil - время видимости окошка в мс. (по умолчанию 5000)
	-- = void
	show = function( message, messageType, icon, delay )
		GUI.sendJS( "Popup.show", message, messageType, icon, tonumber( delay ) )
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Сервер показал popup
	onServerShowPopup = function( message, messageType, icon, delay )
		Popup.show( message, messageType, icon, delay )
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Popup.init )