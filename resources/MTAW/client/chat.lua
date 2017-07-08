--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Chat.onMessage", false ) 											-- Игрок отправил в чат сообщение ( string message )
addEvent( "Chat.onCommand", false ) 											-- Игрок отправил в чат команду - сообщение вида "/..." ( string command, table args )

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Chat.onServerSetActive", true )										-- Сервер сделал чат активным ( bool isActive )
addEvent( "Chat.onServerSetVisible", true )										-- Сервер сделал чат видимым ( bool isVisible )
addEvent( "Chat.onServerSentNewMessage", true )									-- Пришло новое сообщение от сервера ( string content, string / nil messageType, string / nil info, string / nil infoColor, string / nil contentColor )

--------------------------------------------------------------------------------
--<[ Модуль Chat ]>-------------------------------------------------------------
--------------------------------------------------------------------------------
Chat = {
	isActive = false;
	isVisible = false;
	
	init = function()
		addEventHandler( "Main.onClientLoad", resourceRoot, Chat.onClientLoad )
		addEventHandler( "Chat.onServerSetActive", resourceRoot, Chat.onServerSetActive )
		addEventHandler( "Chat.onServerSetVisible", resourceRoot, Chat.onServerSetVisible )
		addEventHandler( "Character.onCharacterChange", resourceRoot, Chat.onCharacterChange )
	
		-- Игрок выключил курсор на Esc, делаем чат неактивным
		addEventHandler( "Cursor.onHiddenByEsc", resourceRoot, function()
			if ( Chat.isActive ) then
				Chat.setActive( false )
			end
		end )
		
		Main.setModuleLoaded( "Chat", 1 )
	end;
	
	onClientLoad = function()
		GUI.addBrowserEventHandler( 'Chat.onChatSubmit', Chat.onChatSubmit )
		addEventHandler( "Chat.onServerSentNewMessage", resourceRoot, Chat.onServerSentNewMessage )
	end;
	
	-- Сделать чат видимым (не путать с активным)
	-- > setVisible bool - true, чтобы показать чат, false чтобы спрятать
	-- = void
	setVisible = function( setVisible )
		if setVisible == nil then setVisible = true end
		
		if ( Chat.isActive ) then
			Chat.setActive( false )
		end
		
		GUI.sendJS( "Chat.setVisible", setVisible )
		
		Chat.isVisible = setVisible
	end;
	
	-- Сделать чат активным (не путать с видимым)
	-- > setActive bool - true, чтобы показать поле ввода в чат и включить курсор
	-- = void
	setActive = function( setActive )
		if setActive == nil then setActive = true end
		
		if ( not Account.isLogined() or not Character.isSelected() ) then
			Debug.info( "Сначала выберите персонаж" )
			return nil
		end
		
		-- Невозможно активировать, когда чат не видно
		if ( not Chat.isVisible ) then
			return nil
		end
		
		focusBrowser( GUI.browser ) -- Фикс: после разворачивания игры фокус браузера теряется и $.focus не работает
		
		if ( setActive ) then
			GUI.sendJS( "Chat.setActive", true )
			Cursor.show( "Chat" )
			Crosshair.disable( "Chat" )
			
			-- Отключаем кнопки с биндами, чтобы не включалось что не надо когда вводим в чат сообщение
			guiSetInputEnabled( true )
		else
			GUI.sendJS( "Chat.setActive", false )
			Cursor.hide( "Chat" )
			Crosshair.cancelDisabling( "Chat" )
			
			-- Заново включаем бинды
			guiSetInputEnabled( false )
		end
		
		Chat.isActive = setActive
	end;
	
	-- Активировать / деактивировать чат (не путать со скрытым / видимым чатом)
	-- = void
	toggleActive = function()
		Chat.setActive( not Chat.isActive )
	end;
	
	-- Добавить сообщение в чат
	-- > content string - текст сообщения. Можно использовать HTML, если escapeHTML не равен true
	-- > messageType string / nil - тип сообщения (state, normal, shout, whisper, warning, error, info, radio, success, broadcasst), по умолчанию info
	-- > info string / nil - доп. информация по сообщению (слева от основного текста)
	-- > infoColor string / nil - цвет доп. информации
	-- > contentColor string / nil - цвет сообщения
	-- > escapeHTML bool / nil - экранировать ли теги HTML (по умолчанию false)
	-- = void
	addMessage = function( content, messageType, info, infoColor, contentColor, escapeHTML )
		if messageType == nil then messageType = "info" end
		if info == nil then info = "" end
		
		GUI.sendJS( "Chat.addMessage", messageType, info, content, infoColor, contentColor, escapeHTML )
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	onServerSetActive = function( isActive )
		Chat.setActive( isActive )
	end;
	
	onServerSetVisible = function( isVisible )
		Chat.setVisible( isVisible )
	end;
	
	onCharacterChange = function()
		if ( Character.isSelected() ) then
			Chat.setVisible( true )
		else
			Chat.setVisible( false )
		end
	end;
	
	onServerSentNewMessage = function( content, messageType, info, infoColor, contentColor )
		Chat.addMessage( content, messageType, info, infoColor, contentColor )
	end;
	
	-- Игрок отправил в чат что-то
	onChatSubmit = function( message )
		if ( message:sub( 1, 1 ) == "/" ) then
			-- Команда
			message = message:sub( 2 )
			
			local things = explode( " ", message )
			cmd = things[ 1 ]
			
			local args = message:sub( cmd:len() + 2 )
			triggerEvent( "Chat.onCommand", resourceRoot, cmd, args )
		else
			-- Сообщение
			if ( message:len() ~= 0 ) then
				triggerEvent( "Chat.onMessage", resourceRoot, message )
			end
		end
		
		-- Деактивация чата
		Chat.setActive( false )
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Chat.init )