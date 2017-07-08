--------------------------------------------------------------------------------
--<[ Модуль Chat ]>-------------------------------------------------------------
--------------------------------------------------------------------------------
Chat = {
	init = function()
		addEventHandler( "Main.onClientLoad", resourceRoot, Chat.onServerLoad )
	
		Main.setModuleLoaded( "Chat", 1 )
	end;
	
	onServerLoad = function()
		
	end;
	
	----------------------------------------------------------------------------
	
	-- Показать / скрыть чат (не путать с активным чатом)
	-- > playerElement player
	-- > isVisible bool - true, чтобы сделать чат видимым
	-- = void
	setVisible = function( playerElement, isVisible ) 
		triggerClientEvent( playerElement, "Chat.onServerSetVisible", resourceRoot, isVisible )
	end;
	
	-- Сделать чат активным (не путать с видимым)
	-- > playerElement player
	-- > isActive bool - true, чтобы активировать чат
	-- = void
	setActive = function( playerElement, isActive ) 
		triggerClientEvent( playerElement, "Chat.onServerSetActive", resourceRoot, isActive )
	end;
	
	-- Добавить сообщение в чат
	-- > playerElement player 
	-- > content string - текст сообщения
	-- > messageType string / nil - тип сообщения (state, normal, shout, whisper, warning, error, info, radio, success, broadcasst), по умолчанию info
	-- > info string / nil - доп. информация по сообщению
	-- > infoColor string / nil - цвет в HTML для доп. информации
	-- > contentColor string / nil - цвет основного сообщения в HTML
	-- > escapeHTML bool / nil - экранировать символы HTML (по умолчанию false)
	-- = void
	addMessage = function( playerElement, content, messageType, info, infoColor, contentColor, escapeHTML )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( content, "content", "string" ) then return nil end
		if not validVar( messageType, "messageType", { "string", "nil" } ) then return nil end
		if not validVar( info, "info", { "string", "number", "nil" } ) then return nil end
		if not validVar( infoColor, "infoColor", { "string", "nil" } ) then return nil end
		if not validVar( contentColor, "contentColor", { "string", "nil" } ) then return nil end
		if not validVar( escapeHTML, "escapeHTML", { "boolean", "nil" } ) then return nil end
		
		triggerClientEvent( playerElement, "Chat.onServerSentNewMessage", resourceRoot, content, messageType, info, infoColor, contentColor, escapeHTML )
	end;
	
	-- Отправить сообщение в чат всем игрокам
	-- > content string - текст сообщения
	-- > messageType string / nil - тип сообщения (state, normal, shout, whisper, warning, error, info, radio, success, broadcasst), по умолчанию info
	-- > info string / nil - доп. информация по сообщению
	-- > infoColor string / nil - цвет в HTML для доп. информации
	-- > contentColor string / nil - цвет основного сообщения в HTML
	-- > escapeHTML bool / nil - экранировать символы HTML (по умолчанию false)
	-- = void
	addMessageToAll = function( content, messageType, info, infoColor, contentColor, escapeHTML )
		triggerClientEvent( root, "Chat.onServerSentNewMessage", resourceRoot, content, messageType, info, infoColor, contentColor, escapeHTML )
	end;
};
addEventHandler( "onResourceStart", resourceRoot, Chat.init )