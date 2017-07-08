--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--<[ Модуль LoginForm ]>--------------------------------------------------------
--------------------------------------------------------------------------------
LoginForm = {
	isVisible = false;

	cameraFly = { active = false; };
	soundEnabled = false;
	
	init = function()
		addEventHandler( "Main.onClientLoad", resourceRoot, LoginForm.onClientLoad )
		
		-- При входе / выходе из аккаунта показывать форму входа
		addEventHandler( "Account.onPlayerLogIn", resourceRoot, LoginForm.onPlayerLogIn )
		addEventHandler( "Account.onPlayerLogOut", resourceRoot, LoginForm.onPlayerLogOut )
		
		-- Запрещаем отключение курсора на Esc, когда форма входа активна
		addEventHandler( "Cursor.onHiddenByEsc", resourceRoot, function()
			if ( LoginForm.isVisible ) then
				cancelEvent()
			end
		end )
		
		addEventHandler( "onClientRender", root, LoginForm.onClientRender )
	end;
	
	onClientLoad = function()
		
		---- Ответы GUI
		GUI.addBrowserEventHandler( "LoginForm.setSoundEnabled", LoginForm.onGuiSetSoundEnabled )
		GUI.addBrowserEventHandler( "LoginForm.formSubmit", LoginForm.onGuiFormSubmit )
		
		GUI.sendJS( "LoginForm.setSoundEnabled", CFG.sound.loginFormMusic )
	end;
	
	-- Показать форму входа (автоматически показывается при входе на сервер и выходе из аккаунта)
	-- = void
	show = function()
		LoginForm.isVisible = true
		GUI.sendJS( "LoginForm.setVisible", true )
		Cursor.show( "LoginForm" )
		Crosshair.disable( "LoginForm" )
	end;
	
	-- Спрятать форму входа (автоматически вызывается при входе в аккаунт)
	-- = void
	hide = function()
		LoginForm.isVisible = false
		GUI.sendJS( "LoginForm.setVisible", false )
		Cursor.hide( "LoginForm" )
		Crosshair.cancelDisabling( "LoginForm" )
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Игрок вошел в аккаунт
	onPlayerLogIn = function( accountData )
		-- Прячем форму входа - она уже не нужна
		LoginForm.hide()
	end;	
	
	-- Игрок вышел из аккаунта
	onPlayerLogOut = function( loggedOutAccountData )
		-- Показываем форму входа, так как больше показывать нечего
		LoginForm.show()
	end;	
	
	-- Рендер одного кадра - обработка полета камеры и музыки
	onClientRender = function()
		-- Если видна форма входа, заставляем камеру летать вокруг штата
		if ( LoginForm.isVisible ) then
			-- Форма входа видна
			if ( not LoginForm.cameraFly.active ) then
				-- Камера еще не летает, ставим ее в начальное положение
				setTime( 5, 0 )
				setMinuteDuration( 300 )
				setWeather ( 6 )
				setFogDistance( 20 )
				setRainLevel( 0 )
				resetSunSize()
				resetSunColor()
				setOcclusionsEnabled( false )
				resetSkyGradient()
		
				LoginForm.cameraFly = {
					active = true;
					startTickDelta = getTickCount() % 720000 - 90000;
					sound = LoginForm.cameraFly.sound ~= nil and LoginForm.cameraFly.sound or playSound( "client/data/account/login-form-background.mp3", false );
					soundVolume = LoginForm.cameraFly.soundVolume ~= nil and LoginForm.cameraFly.soundVolume or 0;
				};
			end
			
			if ( LoginForm.cameraFly.soundVolume ~= 1 ) then
				LoginForm.cameraFly.soundVolume = LoginForm.cameraFly.soundVolume + 0.01
				if ( LoginForm.cameraFly.soundVolume > 1 ) then LoginForm.cameraFly.soundVolume = 1 end
				
				if ( isElement( LoginForm.cameraFly.sound ) ) then
					if ( LoginForm.soundEnabled ) then
						setSoundVolume( LoginForm.cameraFly.sound, LoginForm.cameraFly.soundVolume )
					else
						setSoundVolume( LoginForm.cameraFly.sound, 0 )
					end
				end
			end
			
			local angle = normalizeAngleRad( math.rad( ( ( getTickCount() - LoginForm.cameraFly.startTickDelta ) % 720000 ) / 2000 ) ) -- / 2000
			local x, y, z
			local farClipDistance = 2000
			
			local d = 2200 -- 2200
			if ( math.sin( angle ) < 0 ) then
				x = math.abs( math.sin( angle ) ) * d
			else
				x = -math.sin( angle ) * d
			end
			y = d * math.cos( angle )
			
			if ( x < 0 and y < 0 ) then
				-- Где-то около Чилиад
				local progress = ( 0.5 - math.abs( ( angle - ( math.pi / 2 ) ) / math.pi * 2 - 0.5 ) ) * 2
				local ea = getEasingValue( progress, "InOutQuad" )
				
				z = 150 + ( 500 * ea )
				farClipDistance = farClipDistance + ( 2000 * ea )
			else
				z = 150
			end
			setCameraMatrix( x, y, z, 0, 0, 0 )
			
			setFarClipDistance( farClipDistance )
		else
			-- Форма входа не видна
			if ( LoginForm.cameraFly.active ) then
				-- Полет камеры еще активен - останавливаем
				LoginForm.cameraFly.active = false
			end
			
			if ( LoginForm.cameraFly.sound ~= nil ) then
				-- Элемент звука есть, убавляем громкость
				if ( LoginForm.cameraFly.soundVolume ~= 0 ) then
					-- Еще не затих
					LoginForm.cameraFly.soundVolume = LoginForm.cameraFly.soundVolume - 0.01
					if ( LoginForm.cameraFly.soundVolume < 0 ) then LoginForm.cameraFly.soundVolume = 0 end
					
					if ( isElement( LoginForm.cameraFly.sound ) ) then
						if ( LoginForm.soundEnabled ) then
							setSoundVolume( LoginForm.cameraFly.sound, LoginForm.cameraFly.soundVolume )
						else
							setSoundVolume( LoginForm.cameraFly.sound, 0 )
						end
					end
				else
					-- Звук перестал звучать, удаляем его
					destroyElement( LoginForm.cameraFly.sound )
					LoginForm.cameraFly.sound = nil
					LoginForm.cameraFly.soundVolume = nil
				end
			end
		end
	end;
	
	-- Игрок включил / выключил музыку через GUI
	onGuiSetSoundEnabled = function( isEnabled )
		Configuration.setValue( "sound", "loginFormMusic", isEnabled )
		Configuration.save()
		
		LoginForm.soundEnabled = isEnabled
		if ( LoginForm.cameraFly.sound ~= nil ) then
			if ( isEnabled ) then
				setSoundVolume( LoginForm.cameraFly.sound, LoginForm.cameraFly.soundVolume )
			else
				setSoundVolume( LoginForm.cameraFly.sound, 0 )
			end
		end
	end;
	
	-- Игрок отправил форму входа через GUI
	onGuiFormSubmit = function( login, password )
		-- Валидация данных
		if ( string.len( login ) > 32 ) then
			Popup.show( "Слишком длинный логин", "error" )
		else
			if ( string.len( password ) > 128 ) then
				Popup.show( "Слишком длинный пароль", "error" )
			else
				if ( not Account.isLogined() ) then
					-- Еще не вошел - сообщаем серверу, что хотим войти в аккаунт
					Account.sendLoginAttempt( login, password )
				else
					-- Еще не вошли в аккаунт
					Debug.error( "Вы уже вошли на сервер" )
				end
			end
		end
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, LoginForm.init )