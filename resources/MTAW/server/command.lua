--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Command.onClientExecuteServerCommand", true )						-- Клиент пытается выполнить команду на сервере ( string commandName, mixed ... )
addEvent( "Command.onClientRequestServerCommands", true )						-- Клиент запрашивает список серверных команд при инициализации ()

--------------------------------------------------------------------------------
--<[ Модуль Command ]>----------------------------------------------------------
--------------------------------------------------------------------------------
Command = {
	commands = {};
	
	init = function()
		addEventHandler( "Command.onClientExecuteServerCommand", resourceRoot, Command.onClientExecuteServerCommand )
		addEventHandler( "Command.onClientRequestServerCommands", resourceRoot, Command.onClientRequestServerCommands )
	end;
	
	-- Возвращает true, если серверная команда существует
	-- > cmd string - имя команды
	-- = bool commandExists
	exists = function( cmd ) 
		return ( Command.commands[ cmd ] ~= nil )
	end;
	
	-- Добавить команду, которую можно будет позже вызывать
	-- > cmd string - название команды
	-- > perm string - необходимые права через запятую, например: "none" или "ban,kick"
	-- > syntax string - синтаксис команды (например, "<Модель> [Вариант 1] [Вариант 2]")
	-- > descr string - описание команды
	-- > handler function - функция, которая будет вызвана при вводе команды: handler( player / nil playerElement, string commandName, mixed arg1, mixed arg2... )
	-- = void
	add = function( cmd, perm, syntax, descr, handler )
		if not validVar( cmd, "cmd", "string" ) then return nil end
		if not validVar( perm, "perm", "string" ) then return nil end
		if not validVar( syntax, "syntax", "string" ) then return nil end
		if not validVar( descr, "descr", "string" ) then return nil end
		if not validVar( handler, "handler", "function" ) then return nil end
	
		if ( Command.exists( cmd ) ) then
			-- Команда уже существует
			Debug.error( "Команда " .. cmd .. " уже существует" )
		else
			-- Команда еще не существует
			local data = {}
			local permArr
			if ( perm:len() == 0 ) then
				permArr = { "none" }
			else
				permArr = explode( ",", perm )
				for k, v in pairs( permArr ) do
					permArr[ k ] = trim( v )
				end
			end
			
			data.type = "server"
			data.permissions = permArr
			data.syntax = syntax
			data.description = descr
			data.handler = handler
			
			Command.commands[ cmd ] = data
			
			--addCommandHandler( cmd, Command.onCommand ) -- Клиент сам отправляет событие
		end
	end;
	
	-- Вызвать команду, точно так же, как при вводе команды в консоль, только playerElement будет nil
	-- > cmd string - название команды
	-- > args string - агрументы команды через запятую
	-- = void
	execute = function( cmd, args )
		local explArgs = explode( " ", args )
		Command.onCommand( cmd, unpack( explArgs ) )
	end;

	-- Вызвать команду на клиенте
	-- > playerElement player - игрок, на чьем клиенте необходимо вызвать команду
	-- > cmd string - имя команды
	-- > args string - агрументы команды через запятую
	-- = void
	executeClient = function( playerElement, cmd, args )
		triggerClientEvent( playerElement, "Command.serverExecuteClientCommand", resourceRoot, cmd, args )
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Вызвана какая-то команда, проверка прав и вызов обработчика
	onCommand = function( playerElement, ... )
		if not validVar( playerElement, "playerElement", { "player", "nil" } ) then return nil end
		
		-- TODO переделать аргументы на ( playerElement, commandName, ... )
		local cmd = arg[ 1 ]
		
		if ( not Command.exists( cmd ) ) then
			if ( playerElement ~= nil ) then
				Chat.addMessage( playerElement, "Команда " .. cmd .. " не найдена", "warning" )
			else
				Debug.error( "Command " .. cmd .. " not found" )
			end
		else
			-- Проверка прав
			if ( playerElement ~= nil ) then
				for k, v in pairs( Command.commands[ cmd ].permissions ) do
					if ( not Account.hasPermission( playerElement, v ) ) then
						Chat.addMessage( playerElement, "У вас нет прав на команду " .. cmd, "error" )
						return nil
					end
				end 
			end
			
			for k, v in pairs( arg ) do
				if ( v == "" ) then
					arg[ k ] = nil
				end
			end
			
			-- Запуск
			Command.commands[ cmd ].handler( playerElement, unpack( arg ) )
		end
	end;
	
	-- Клиент запросил список команд сервера
	onClientRequestServerCommands = function()
		if ( Account.isLogined( client ) ) then
			-- Клиент вошел на сервер
			local commandInfo = {}
			for cmd, cmdData in pairs( Command.commands ) do
				-- Проверка прав
				for k, v in pairs( cmdData.permissions ) do
					if ( Account.hasPermission( client, v ) ) then
						commandInfo[ cmd ] = {
							syntax = cmdData.syntax;
							description = cmdData.description;
							permissions = cmdData.permissions;
						};
					end
				end 
			end
			
			triggerClientEvent( client, "Command.onServerSentCommands", resourceRoot, commandInfo )
		end
	end;
	
	-- Клиент запрашивает выполнение серверной команды
	onClientExecuteServerCommand = function( ... )
		Command.onCommand( client, unpack( arg ) )
	end;
};
addEventHandler( "onResourceStart", resourceRoot, Command.init )

Command.add( "bc", "none", "<Сообщение>", "Отправить сообщение всем игрокам", 
	function( playerElement, cmd, msg )
		Chat.addMessageToAll( msg )
	end 
)

Command.add( "damage", "none", "<Урон>", "Нанести урон или вылечить себя", 
	function( playerElement, cmd, damage )
		Character.setHealth( playerElement, -tonumber( damage ) + Character.getHealth( playerElement ) )
	end 
)

Command.add( "veh", "none", "<Модель> [Вариант 1] [Вариант 2]", "Создать временное транспортное средство", 
	function( playerElement, cmd, model, variant1, variant2 )
		local x, y, z = getElementPosition( playerElement )
		local _, _, rz = getElementRotation( playerElement )
		
		outputDebugString( "'" .. tostring( playerElement ) .. "' '" .. tostring( cmd ) .. "' '" .. tostring( model ) .. "' '" .. tostring( variant1 ) .. "' '" .. tostring( variant2 ) .. "'" )
		
		x, y = getCoordsByAngleFromPoint( x, y, rz, 1.5 )
		
		local veh = createVehicle( tonumber( model ), x, y, z + 0.5, 0, 0, rz - 90, Account.getData( playerElement, "login" ), false, variant1, variant2 )
		if ( veh ~= false ) then
			setElementDimension( veh, getElementDimension( playerElement ) )
			setVehicleDamageProof( veh, true )
			
			Chat.addMessage( playerElement, "Создано временное транспортное средство с моделью " .. model .. " (вариация " .. tostring( variant1 ) .. " " .. tostring( variant2 ) .. ")" )
		else
			Chat.addMessage( playerElement, "Не удалось создать транспортное средство", "error" )
		end
	end 
)

Command.add( "handling", "none", "<Параметр> [Значение]", "Установить параметр handling.cfg для текущего транспортного средства", 
	function( playerElement, cmd, property, value )
		local veh = getPedOccupiedVehicle ( playerElement )
		if ( veh == false ) then
			Chat.addMessage( playerElement, "Необходимо находиться в транспортном средстве", "error" )
		else
			setVehicleHandling( veh, property, value )
			local hdl = getVehicleHandling( veh ) 
			Chat.addMessage( playerElement, "Параметр " .. tostring( property ) .. " установлен в " .. tostring( hdl[ property ] ) )
		end
	end 
)

Command.add( "pedstat", "none", "<Параметр> [Значение]", "Установить статистику персонажа (SetPedStat)", 
	function( playerElement, cmd, property, value )
		setPedStat( playerElement, tonumber( property ), value )
		local st = getPedStat( playerElement, tonumber( property ) ) 
		Chat.addMessage( playerElement, "Параметр " .. tostring( property ) .. " установлен в " .. tostring( st ) )
	end 
)

Command.add( "addmoney", "none", "<Количество денег>", "Добавить себе деньги", 
	function( playerElement, cmd, value )
		Character.setMoney( playerElement, Character.getMoney( playerElement ) + value )
		
		Chat.addMessage( playerElement, "Вы добавили себе $" .. value )
	end 
)

Command.add( "giveitem", "none", "<ID игрока> <Класс вещи> <Параметры (JSON)> <Количество>", "Добавить игроку вещь", 
	function( playerElement, cmd, playerID, itemClass, itemParams, count )
		local item = Item( itemClass, jsonDecode( itemParams ) )
		local leftToAdd = Inventory.addItem( playerElement, ItemStack( item, tonumber( count ) ) )
		
		if ( leftToAdd:isEmpty() ) then
			Chat.addMessage( playerElement, "Вы добавили себе все вещи" )
		else
			Chat.addMessage( playerElement, leftToAdd:getCount() .. " вещей не поместилось в инвентарь", "error" )
		end
		
		Debug.info( "Inventory" )
		Inventory.getInventoryContainer( playerElement ):debugPrint()
		
		Debug.info( "Fast" )
		Inventory.getFastContainer( playerElement ):debugPrint()
	end 
)

Command.add( "suicide", "none", "[]", "Убить своего персонажа", 
	function( playerElement, cmd )
		Character.setHealth( playerElement, 0 )
	end 
)

Command.add( "tfc", "none", "[]", "Включить/выключить режим свободной камеры", 
	function( playerElement, cmd )
		Debug.info( getElementData( playerElement, "Command.tfc_enabled" ) )
		local isEnabled = not getElementData( playerElement, "Command.tfc_enabled" )
		setElementData( playerElement, "Command.tfc_enabled", isEnabled )
		
		if ( isEnabled ) then
			local x, y, z = getCameraMatrix( playerElement )
			exports.Freecam:setPlayerFreecamEnabled( playerElement, x, y, z, false )
			toggleAllControls( playerElement, false, true, true )
			-- TODO
			
			local px, py, pz = getElementPosition( playerElement )
			setElementData( playerElement, "Command.tfc_p_x", px )
			setElementData( playerElement, "Command.tfc_p_y", py )
			setElementData( playerElement, "Command.tfc_p_z", pz )
			
			Chat.addMessage( playerElement, "ON", "info", "Свободная камера", "white", "#4CAF50", false )
		else
			exports.Freecam:setPlayerFreecamDisabled( playerElement, false )
			Chat.addMessage( playerElement, "OFF", "info", "Свободная камера", "white", "#F44336", false )
			toggleAllControls( playerElement, true, true, true )
	
			setCameraTarget( playerElement )
			
			local px, py, pz = getElementData( playerElement, "Command.tfc_p_x" ), getElementData( playerElement, "Command.tfc_p_y" ), getElementData( playerElement, "Command.tfc_p_z" )
			setElementPosition( playerElement, px, py, pz )
		end
	end 
)

Command.add( "weapon", "none", "<ID оружия>", "Добавить своему персонажу оружие", 
	function( playerElement, cmd, weaponid )
		Debug.info( "W: " .. tostring( weaponid ) )
		if ( weaponid == nil ) then
			local categoryColor = "#bb4444"
			local contentColor = "#ffffff"
			local infoColor = "#44aaff"
			
			Chat.addMessage( playerElement, "Slot 0: No Weapon", nil, nil, categoryColor, categoryColor )
			Chat.addMessage( playerElement, "Brass Knuckles", nil, 	1, infoColor, contentColor )
			
			Chat.addMessage( playerElement, "Slot 1: Melee", nil, nil, categoryColor, categoryColor )
			Chat.addMessage( playerElement, "Golf Club", nil, 	2, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Nightstick", nil, 	3, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Knife", nil, 	4, infoColor, contentColor )
			Chat.addMessage( playerElement, "Baseball Bat", nil, 	5, infoColor, contentColor )
			Chat.addMessage( playerElement, "Shovel", nil, 	6, infoColor, contentColor )
			Chat.addMessage( playerElement, "Pool Cue", nil, 	7, infoColor, contentColor )
			Chat.addMessage( playerElement, "Katana", nil, 	8, infoColor, contentColor )
			Chat.addMessage( playerElement, "Chainsaw", nil, 	9, infoColor, contentColor )
			
			Chat.addMessage( playerElement, "Slot 2: Handguns", nil, nil, categoryColor, categoryColor )
			Chat.addMessage( playerElement, "Pistol", nil, 22, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Silenced Pistol", nil, 23, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Desert Eagle", nil, 24, infoColor, contentColor )	
			
			Chat.addMessage( playerElement, "Slot 3: Shotguns", nil, nil, categoryColor, categoryColor )
			Chat.addMessage( playerElement, "Shotgun", nil, 25, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Sawn-Off Shotgun", nil, 26, infoColor, contentColor )	
			Chat.addMessage( playerElement, "SPAZ-12 Combat Shotgun", nil, 27, infoColor, contentColor )	
			
			Chat.addMessage( playerElement, "Slot 4: Sub-Machine Guns", nil, nil, categoryColor, categoryColor )
			Chat.addMessage( playerElement, "Uzi", nil, 28, infoColor, contentColor )	
			Chat.addMessage( playerElement, "MP5", nil, 29, infoColor, contentColor )
			Chat.addMessage( playerElement, "TEC-9", nil, 32, infoColor, contentColor )	
			
			Chat.addMessage( playerElement, "Slot 5: Assault Rifles", nil, nil, categoryColor, categoryColor )
			Chat.addMessage( playerElement, "AK-47", nil, 30, infoColor, contentColor )	
			Chat.addMessage( playerElement, "M4", nil, 31, infoColor, contentColor )	
			
			Chat.addMessage( playerElement, "Slot 6: Rifles", nil, nil, categoryColor, categoryColor )
			Chat.addMessage( playerElement, "Country Rifle", nil, 33, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Sniper Rifle", nil, 34, infoColor, contentColor )	
			
			Chat.addMessage( playerElement, "Slot 7: Heavy Weapons", nil, nil, categoryColor, categoryColor )
			Chat.addMessage( playerElement, "Rocket Launcher", nil, 35, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Heat-Seeking RPG", nil, 36, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Flamethrower", nil, 37, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Minigun", nil, 38, infoColor, contentColor )	
			
			Chat.addMessage( playerElement, "Slot 8: Projectiles", nil, nil, categoryColor, categoryColor )
			Chat.addMessage( playerElement, "Grenade", nil, 16, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Tear Gas", nil, 17, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Molotov Cocktails", nil, 18, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Satchel Charges", nil, 39, infoColor, contentColor )	
			
			Chat.addMessage( playerElement, "Slot 9: Special 1", nil, nil, categoryColor, categoryColor )
			Chat.addMessage( playerElement, "Spraycan", nil, 41, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Fire Extinguisher", nil, 42, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Camera", nil, 43, infoColor, contentColor )	
			
			Chat.addMessage( playerElement, "Slot 10: Gifts/Other", nil, nil, categoryColor, categoryColor )
			Chat.addMessage( playerElement, "Long Purple Dildo", nil, 10, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Short tan Dildo", nil, 11, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Vibrator", nil, 12, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Flowers", nil, 14, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Cane", nil, 15, infoColor, contentColor )	
			
			Chat.addMessage( playerElement, "Slot 11: Special 2", nil, nil, categoryColor, categoryColor )
			Chat.addMessage( playerElement, "Night-Vision Goggles", nil, 44, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Infrared Goggles", nil, 45, infoColor, contentColor )	
			Chat.addMessage( playerElement, "Parachute", nil, 46, infoColor, contentColor )	
			
			Chat.addMessage( playerElement, "Slot 12: Satchel Detonator", nil, nil, categoryColor, categoryColor )
			Chat.addMessage( playerElement, "Satchel Detonator", nil, 40, infoColor, contentColor )	
		else
			giveWeapon( playerElement, tonumber( weaponid ), 3000, true )
		
			Chat.addMessage( playerElement, "Оружие добавлено" )
		end
	end 
)

-- Редактирование attachments (BoneAttach)
Command.add( "att_set", "none", "<bone> <scale> <x> <y> <z> <rx> <ry> <rz>", "Прикрепить модель объекта к кости игрока", 
	function( playerElement, cmd, bone, scale, x, y, z, rx, ry, rz )
		
	end 
)

Command.add( "vehcolor", "none", "<r1> <g1> <b1> [r2] [g2] [b2]", "Установить цвет транспортного средства", 
	function( playerElement, cmd, r1, g1, b1, r2, g2, b2 )
		local veh = getPedOccupiedVehicle( playerElement )
		
		if ( veh ~= nil ) then
			if ( r1 ~= nil ) then r1 = tonumber( r1 ) end
			if ( g1 ~= nil ) then g1 = tonumber( g1 ) end
			if ( b1 ~= nil ) then b1 = tonumber( b1 ) end
			if ( r2 ~= nil ) then r2 = tonumber( r2 ) end
			if ( g2 ~= nil ) then g2 = tonumber( g2 ) end
			if ( b2 ~= nil ) then b2 = tonumber( b2 ) end
			
			setVehicleColor( veh, r1, g1, b1, r2, g2, b2 )
			
			Chat.addMessage( playerElement, "Установлен цвет: " .. tostring( r1 ) .. " " .. tostring( g1 ) .. " " .. tostring( b1 ) .. " : " .. tostring( r2 ) .. " " .. tostring( g2 ) .. " " .. tostring( b2 ) )
		else
			Chat.addMessage( playerElement, "Необходимо находиться в транспортном средстве" )
		end
	end 
)

Command.add( "vehdmg", "none", "<true/false>", "Установить транспортное средство неубиваемым", 
	function( playerElement, cmd, isDamageProof )
		local veh = getPedOccupiedVehicle( playerElement )
		
		if ( isDamageProof == "true" ) then
			isDamageProof = true
		else
			isDamageProof = false
		end
		
		if ( veh ~= nil ) then
			setVehicleDamageProof( veh, isDamageProof )
			
			Chat.addMessage( playerElement, "Транспорт нельзя разбить: " .. tostring( isDamageProof ) )
		else
			Chat.addMessage( playerElement, "Необходимо находиться в транспортном средстве" )
		end
	end 
)