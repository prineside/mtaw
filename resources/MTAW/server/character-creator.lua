--------------------------------------------------------------------------------
--<[ Модуль CharacterCreator ]>-------------------------------------------------
--------------------------------------------------------------------------------
CharacterCreator = {
	init = function()
		addEventHandler( "Main.onServerLoad", root, CharacterCreator.onServerLoad )
	end;
	
	onServerLoad = function()
		-- Отправка клиенту статистики слотов позапросу
		CallbackEvent.addHandler( "CharacterCreator.getSlotStatistic", CharacterCreator.onClientRequestSlotStatistic )
		CallbackEvent.addHandler( "CharacterCreator.createAttempt", CharacterCreator.onClientCreateCharacterAttempt )
	end;
	
	-- Клиент запросил статистику слотов персонажей
	onClientRequestSlotStatistic = function( playerElement, eventHash )
		-- Отправляем статистику
		CallbackEvent.sendResponse( eventHash, Character.getSlotStatistic( playerElement ) )
	end;
	
	-- Клиент пытается создать нового персонажа
	onClientCreateCharacterAttempt = function( playerElement, eventHash, name, surname, gender, skinModel )
		Debug.info( name .. " " .. surname .. " " .. gender .. " " .. skinModel )
		
		local isSuccess, characterID = Character.create( playerElement, name, surname, gender, skinModel )
		
		-- Отправляем ответ (true, insertID || false, errorMessage)
		CallbackEvent.sendResponse( eventHash, isSuccess, errorMessage )
	end;
}
addEventHandler( "onResourceStart", resourceRoot, CharacterCreator.init )