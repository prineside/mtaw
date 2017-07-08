--------------------------------------------------------------------------------
--<[ Модуль Popup ]>------------------------------------------------------------
--------------------------------------------------------------------------------
Popup = {
	init = function()
		
	end;
	
	-- Показать всплывающую подсказку
	-- > playerElement player - игрок, которому нужно показать подсказку
	-- > message string - сообщение подсказки
	-- > messageType string / nil - тип подсказки: info, warning, error, success (по умолчанию info)
	-- > icon string / nil - название значка из FontAwesome (по умолчанию зависит от типа сообщения)
	-- > delay number / nil - время (мс), которое будет видна подсказка (по умолчанию 5000)
	-- = void
	show = function( playerElement, message, messageType, icon, delay )
		triggerClientEvent( playerElement, "Popup.onServerShowPopup", resourceRoot, message, messageType, icon, delay )
	end;
};
addEventHandler( "onResourceStart", resourceRoot, Popup.init )