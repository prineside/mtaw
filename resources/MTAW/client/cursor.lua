--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Cursor.onHiddenByEsc", false )										-- Клиент отключил курсор через Esc ( string hideFor )

--------------------------------------------------------------------------------
--<[ Модуль Cursor ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
Cursor = {
	active = false;
	usedBy = {};

	init = function()
		-- Esc
		addEventHandler( "onClientKey", root, function( button, press ) 
			if ( Cursor.active and button == "escape" and press ) then
				if ( Cursor.hide( "all", true ) ) then
					cancelEvent()
				end
			end
		end )
	end;
	
	-- Спрятать курсор
	-- > hideFor string - причина (чаще название модуля) для которой нужно спрятать курсор (только если по этой причине курсор показан). Причина та же, что и была указана в show. Если указано "all", курсор прячется для всех причин. По умолчанию "all"
	-- > hiddenByEsc bool / nil - внутренний аргумент, не использовать
	-- = bool isHidden
	hide = function( hideFor, hiddenByEsc )
		if ( hideFor == nil ) then hideFor = "all" end
		if ( hiddenByEsc == nil ) then hiddenByEsc = false end
		
		if ( Cursor.active ) then
			if ( hideFor == "all" ) then
				-- Прячем все, что использует курсор
				for k, v in pairs( Cursor.usedBy ) do
					if ( hiddenByEsc ) then
						if ( not triggerEvent( "Cursor.onHiddenByEsc", resourceRoot, k ) ) then
							-- Модуль не захотел прятать курсор на Esc
							return false
						end
					end
					
					Cursor.usedBy[ k ] = nil
				end
			else
				-- Курсор спрятан для одного ресурса, удаляем его из usedBy
				-- Если осталось еще что-то, что требует курсор, не прячем его
				if ( Cursor.usedBy[ hideFor ] ~= nil ) then
					if ( hiddenByEsc ) then
						if ( not triggerEvent( "Cursor.onHiddenByEsc", resourceRoot, hideFor ) ) then
							-- Модуль не захотел прятать курсор на Esc
							return false
						end
					end
					
					Cursor.usedBy[ hideFor ] = nil
				end
			end
			
			if ( tableRealSize( Cursor.usedBy ) == 0 ) then
				Cursor.active = false
				
				guiSetInputEnabled( false )
				showCursor( false )
			end
			
			return true
		else 
			return false
		end
	end;
	
	-- Показать курсор
	-- > showFor string - причина (чаще название модуля), по которой нужно показать курсор. Точно та же причина должна использоваться в hide, чтобы спрятать курсор
	-- > x number / nil - координата X экрана, в которой необходимо показать курсор. Если nil, курсор будет установлен в центр экрана
	-- > y number / nil - координата Y экрана, в которой необходимо показать курсор. Если x == nil, курсор будет установлен в центр экрана
	-- = void
	show = function( showFor, x, y )
		if not validVar( showFor, "showFor", "string" ) then return nil end
		if ( x == nil ) then 
			local screenX, screenY = guiGetScreenSize()
			x = screenX / 2
			y = screenY / 2
		end
		
		if ( Cursor.usedBy[ showFor ] ~= nil ) then
			return nil
		end
		
		Cursor.usedBy[ showFor ] = true
		
		showCursor( true )
		--guiSetInputEnabled( true )
		
		if ( not Cursor.active ) then
			-- Установка курсора, если перед этим не был виден
			setCursorPosition( x, y )
		end
		
		Cursor.active = true
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, Cursor.init )