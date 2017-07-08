--[[
	Интерфейс GUI.showDialog и GUI.hideDialog
	Также позволяет узнать, открыт ли какой-то диалог, на стороне Lua (например, отключить поворот камеры в лобби, когда поверх персонажа показан диалог)
--]]

--<[ Модуль Dialog ]>
Dialog = {
	isVisible = false;
	
	_lastDialogButtons = {};

	init = function()
		addEventHandler( "Main.onClientLoad", resourceRoot, Dialog.onClientLoad )
	end;
	
	onClientLoad = function()
		GUI.addBrowserEventHandler( "Dialog.onDialogButtonPress", Dialog._onDialogButtonPress )
	end;
	
	-- Диалог с кнопками
	--[[ 
		buttons = {
			ok = {
				text = "Принять",
				icon = "check",
				class = "button-float-left",
				handler = function() Dialog.hide() end
			},
			{...}
		}
	--]]
	show = function( message, icon, buttons )
		if not validVar( message, "message", "string" ) then return nil end
		if not validVar( icon, "icon", { "string", "nil" } ) then return nil end
		if not validVar( buttons, "buttons", { "table", "nil" } ) then return nil end
		
		if ( icon == nil ) then
			icon = "false"
		end
		
		local guiButtonStrings = {}
		if ( buttons ~= nil ) then
			for buttonID, buttonData in pairs( buttons ) do
				if ( type( buttonID ) ~= "string" ) then
					Debug.error( "Ключи в таблице buttons должны быть строками" )
				
					return nil
				end
				
				if ( buttonData.class == nil ) then
					buttonData.class = ""
				end
				
				guiButtonStrings[ #guiButtonStrings + 1 ] = "<div class=\"button " .. buttonData.class .. "\" onClick=\"Main.sendEvent( 'Dialog.onDialogButtonPress', '" .. buttonID .. "' )\"><i class=\"fa fa-" .. buttonData.icon .. "\"></i>" .. buttonData.text .. "</div>";
			end
		end
		
		Dialog._lastDialogButtons = buttons
		
		GUI.sendJS( "GUI.showDialog", message, icon, table.concat( guiButtonStrings ) )
	end;
	
	
	-- Скрыть все диалоги
	hide = function()
		GUI.sendJS( "GUI.hideDialog" )
	end;
	
	_onDialogButtonPress = function( buttonID )
		Dialog._lastDialogButtons[ buttonID ].handler()
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Dialog.init )