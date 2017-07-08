--[[
	Отвечает за включение и отключение кнопок контроллера.
	Например, в зеленой зоне отключена кнопка стрельбы, а при использовании
	вещи кнопка огня сначала отключается, затем заново включается, тем самым
	перезаписывая действия зеленой зоны. Модуль не включит контроллер, если 
	осталась по крайней мере одна причина, по которой он должен быть выключен.
	
	Работает как Crosshair (по умолчанию все включено), позволяет использовать
	несколько причин выключения контроллера (чтобы один модуль случайно не
	включил контроллер, выключенный ранее другим модулем)
	
	Также по умолчанию игрок будет ходить, при нажатии Alt - бегать, при Space -
	быстро бежать.
--]]
--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Control.onControlDisabled", false )									-- Кнопку действия отключили ( string controlName )
addEvent( "Control.onControlEnabled", true )									-- Кнопку действия включили ( string controlName )

--------------------------------------------------------------------------------
--<[ Модуль Control ]>----------------------------------------------------------
--------------------------------------------------------------------------------
Control = {
	status = {};			-- string controlName => bool isEnabled
	disabledBy = {};		-- string controlName => table disableReasons { GreenZone = true, ItemUsage = true, ... }
	
	init = function()
		-- Инициализация массива названий контроллеров
		Control.status = {};
		Control.disabledBy = {};
		
		for _, controlName in pairs( { 
			-- on foot
			"fire", "next_weapon", "previous_weapon", "forwards", "backwards", "left", "right", "zoom_in", "zoom_out", "change_camera", "jump", "sprint", "look_behind", "crouch", "action", "walk", "aim_weapon", "conversation_yes", "conversation_no", "group_control_forwards", "group_control_back", "enter_exit", 
			-- in vehicle
			"vehicle_fire", "vehicle_secondary_fire", "vehicle_left", "vehicle_right", "steer_forward", "steer_back", "accelerate", "brake_reverse", "radio_next", "radio_previous", "radio_user_track_skip", "horn", "sub_mission", "handbrake", "vehicle_look_left", "vehicle_look_right", "vehicle_look_behind", "vehicle_mouse_look", "special_control_left", "special_control_right", "special_control_down", "special_control_up", "enter_exit", 
			-- mta
			"enter_passenger", "screenshot", "chatbox", "radar", "radar_zoom_in", "radar_zoom_out", "radar_move_north", "radar_move_south", "radar_move_east", "radar_move_west", "radar_attach"
		} ) do
			Control.status[ controlName ] = true
			Control.disabledBy[ controlName ] = {}
		end
		
		-- Debug
		local debuggingControlName = { "fire", "walk" }
		function setDebugData()
			local by = {}
			
			for _, controlName in pairs( debuggingControlName ) do
				for reason in pairs( Control.disabledBy[ controlName ] ) do
					table.insert( by, reason )
				end
				
				Debug.debugData[ "c_" .. controlName .. "_DisabledBy" ] = table.concat( by, ", " )
				Debug.debugData[ "c_" .. controlName .. "_State" ] = tostring( getControlState( controlName ) )
			end
		end
		
		setTimer( setDebugData, 100, 0 )
		
		Main.setModuleLoaded( "Control", 1 )
		
		-- Меняем местами бег и ходьбу
		local isRunning = false
		local isSprinting = false
		local lastSprintTick = 0
		
		local walkControlState = false
		
		addEventHandler( "onClientPreRender", root, function()
			if ( isSprinting ) then
				lastSprintTick = getTickCount()
			end
			
			if ( isRunning or getTickCount() - lastSprintTick < 1200 ) then
				-- Недавно спринтил или зажал кнопку бега
				if ( walkControlState ) then
					setControlState( "walk", false )
					walkControlState = false
				end
			else
				-- Не спринтил и не зажал кнопку бега
				if ( not walkControlState ) then
					setControlState( "walk", true )
					walkControlState = true
				end
			end
		end )
		Control.disable( "walk", "Control.walk" )
		
		bindKey( "walk", "both", function( key, state )
			isRunning = ( state == "down" )
		end )
		
		bindKey( "sprint", "both", function( key, state )
			isSprinting = ( state == "down" )
		end )
	end;
	
	-- Возвращает true, если контроллер отключен по какой-либо причине
	-- > controlName string - название контроллера (https://wiki.multitheftauto.com/wiki/Control_names)
	-- = bool isDisabled
	isDisabled = function( controlName )
		if not validVar( controlName, "controlName", "string" ) then return nil end
		
		if ( Control.disabledBy[ controlName ] == nil ) then
			Debug.error( "Контроллер " .. controlName .. " не существует" )
			
			return nil
		end
		
		for k in pairs( Control.disabledBy[ controlName ] ) do
			return true
		end
		
		return false
	end;
	
	-- Отключить контроллер
	-- > controlName string - название контроллера (https://wiki.multitheftauto.com/wiki/Control_names)
	-- > disabledBy string - причина (но чаще - название модуля), по которой контроллер отключается. Пример: "Chat". Это же значение используется в cancelDisabling для отмены отключения контроллера
	-- = void
	disable = function( controlName, disabledBy )
		if not validVar( controlName, "controlName", "string" ) then return nil end
		if not validVar( disabledBy, "disabledBy", "string" ) then return nil end
		
		if ( Control.disabledBy[ controlName ] == nil ) then
			Debug.error( "Контроллер " .. controlName .. " не существует" )
			
			return nil
		end
		
		if ( Control.disabledBy[ controlName ][ disabledBy ] == nil ) then
			-- Еще не был отменен этим модулем
			local wasDisabled = Control.isDisabled( controlName )
			
			Control.disabledBy[ controlName ][ disabledBy ] = true
			
			if ( not wasDisabled ) then
				-- Раньше был включен - сообщаем о выключении
				toggleControl( controlName, false )
				triggerEvent( "Control.onControlDisabled", resourceRoot, controlName )
			end
		end
	end;
	
	-- Отключить все контроллеры, эквивалентно вызову disable с каждым контроллером
	-- > disabledBy string - причина (но чаще - название модуля), по которой контроллер отключается. Пример: "Chat". Это же значение используется в cancelDisabling для отмены отключения контроллера
	-- = void
	disableAll = function( disabledBy )
		if not validVar( disabledBy, "disabledBy", "string" ) then return nil end
		
		for controlName, disableReasons in pairs( Control.disabledBy ) do
			if ( disableReasons[ disabledBy ] == nil ) then
				-- Еще не отменял контроллер по этой причине
				local wasDisabled = Control.isDisabled( controlName )
				
				Control.disabledBy[ controlName ][ disabledBy ] = true
				
				if ( not wasDisabled ) then
					-- Раньше был включен - сообщаем о выключении
					toggleControl( controlName, false )
					triggerEvent( "Control.onControlDisabled", resourceRoot, controlName )
				end
			end
		end
	end;
	
	-- Отменить отключение контроллера
	-- > controlName string - название контроллера (https://wiki.multitheftauto.com/wiki/Control_names)
	-- > disabledBy string - причина, по которой контроллер был отключен, и которая была использована в disable
	-- = void
	cancelDisabling = function( controlName, disabledBy )
		if not validVar( controlName, "controlName", "string" ) then return nil end
		if not validVar( disabledBy, "disabledBy", "string" ) then return nil end
		
		if ( Control.disabledBy[ controlName ] == nil ) then
			Debug.error( "Контроллер " .. controlName .. " не существует" )
			
			return nil
		end
		
		if ( Control.disabledBy[ controlName ][ disabledBy ] ~= nil ) then
			-- Этот модуль ранее отменял прицел, продолжаем
			Control.disabledBy[ controlName ][ disabledBy ] = nil
			
			if ( not Control.isDisabled( controlName ) ) then
				-- Больше никто не запрещает отображение прицела
				toggleControl( controlName, true )
				triggerEvent( "Control.onControlEnabled", resourceRoot, controlName )
			end
		end
	end;
	
	-- Отменить отключение всех контроллеров, которые были отключены по указанной причине. Отменяет действие всех disable и disableAll с указанной причиной
	-- > disabledBy string - причина, по которой контроллер был отключен, и которая была использована в disable
	-- = void
	cancelDisablingAll = function( disabledBy )
		if not validVar( disabledBy, "disabledBy", "string" ) then return nil end
	
		for controlName, disableReasons in pairs( Control.disabledBy ) do
			if ( disableReasons[ disabledBy ] ~= nil ) then
				-- По этой причине был отключен контроллер
				Control.disabledBy[ controlName ][ disabledBy ] = nil
				
				if ( not Control.isDisabled( controlName ) ) then
					-- Больше никто не запрещает отображение прицела
					toggleControl( controlName, true )
					triggerEvent( "Control.onControlEnabled", resourceRoot, controlName )
				end
			end
		end
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, Control.init )