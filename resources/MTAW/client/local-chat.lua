--[[
	Локальный чат
--]]

--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "LocalChat.onMessage", true )											-- Сервер прислал новое локальное сообщение ( string avatarAlias, string message, string loudness, number loudnessCoeff )

--------------------------------------------------------------------------------
--<[ Модуль LocalChat ]>--------------------------------------------------------
--------------------------------------------------------------------------------
LocalChat = {
	enabled = true;
	defaultLoudness = "normal";

	init = function()
		addEventHandler( "Main.onClientLoad", resourceRoot, LocalChat.onClientLoad )
	end;
	
	onClientLoad = function()
		addEventHandler( "Chat.onMessage", resourceRoot, LocalChat.onClientEnterChatMessage )
		
		addEventHandler( "LocalChat.onMessage", resourceRoot, LocalChat.onServerSentLocalChatMessage )
	end;
	
	-- Отправить сообщение в локальный чат
	-- > message string - текст сообщения
	-- > loudness string - тип сообщения (normal, whisper, shout), по умолчанию LocalChat.defaultLoudness
	-- = void
	say = function( message, loudness )
		if not validVar( message, "message", "string" ) then return nil end
		if not validVar( loudness, "loudness", { "string", "nil" } ) then return nil end
		
		if ( LocalChat.enabled ) then
			if ( loudness == nil ) then 
				loudness = LocalChat.defaultLoudness 
			end
			
			triggerServerEvent( "LocalChat.onClientSayAttempt", resourceRoot, message, loudness )
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------

	-- Клиент отправил сообщение в чат (f6 -> Enter)
	onClientEnterChatMessage = function( message )
		if ( LocalChat.enabled ) then
			LocalChat.say( message )
		end
	end;
	
	-- Сервер прислал сообщение локального чата
	onServerSentLocalChatMessage = function( avatarAlias, message, loudness, loudnessCoeff )
		-- TODO заменить аиасы аватарок изображениям и именами
		local b = 127 + 128 * loudnessCoeff
		local color = tocolor( b, b, b, 255 )
		Chat.addMessage( message, loudness, avatarAlias, false, color, true )
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, LocalChat.init )