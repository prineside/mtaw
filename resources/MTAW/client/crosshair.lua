-- Работает как Cursor, только наоборот
-- Виден всегда, если ни один модуль не отключил его (disable)

--------------------------------------------------------------------------------
--<[ Модуль Crosshair ]>--------------------------------------------------------
--------------------------------------------------------------------------------
Crosshair = {
	isVisible = true;
	disabledBy = {};
	
	init = function()
		addEventHandler( "Main.onClientLoad", root, Crosshair.onClientLoad )
	end;
	
	onClientLoad = function()
		-- Инициализация (создание) прицела
		GUI.sendJS( "Crosshair.enable" )
	
		-- Начальная загрузка формы прицела
		Crosshair.setShape( CFG.gameplay.crosshairShape )
		
		-- Обработка
		addEventHandler( "onClientRender", root, Crosshair.onClientRender )
		
		-- Если изменилась настройка формы прицела, обновляем
		addEventHandler( "Settings.onSettingChanged", resourceRoot, function( categoryName, itemName, oldValue, newValue )
			if ( categoryName == "gameplay" and itemName == "crosshairShape" ) then
				Crosshair.setShape( newValue )
			end
		end );
	end;
	
	-- Отключить отображение прицела
	-- > disabledBy string - причина (но чаще - название модуля), по которой прицел отключается. Пример: "Chat". Это же значение используется в cancelDisabling для отмены отключения прицела
	-- = void
	disable = function( disabledBy )
		if ( Crosshair.disabledBy[ disabledBy ] == nil ) then
			-- Еще не был отменен этим модулем
			Crosshair.disabledBy[ disabledBy ] = true
			
			if ( Crosshair.isVisible ) then
				GUI.sendJS( "Crosshair.setVisible", false )
				Crosshair.isVisible = false;
			end
		end
	end;
	
	-- Отменить отключение прицела
	-- > disabledBy string - причина, по которой прицел был отключен, и которая была использована в disable
	-- = void
	cancelDisabling = function( disabledBy )
		if ( Crosshair.disabledBy[ disabledBy ] ~= nil ) then
			-- Этот модуль ранее отменял прицел, продолжаем
			Crosshair.disabledBy[ disabledBy ] = nil
			
			if ( tableRealSize( Crosshair.disabledBy ) == 0 ) then
				-- Больше никто не запрещает отображение прицела
				GUI.sendJS( "Crosshair.setVisible", true )
				Crosshair.isVisible = true;
			end
		end
	end;
	
	-- Установить подсказку возле прицела
	-- > labelText string - текст подсказки
	-- > labelDescription string - описание (находится под текстом и используется для уточнения)
	-- > labelColor string / nil - цвет подсказки
	-- > showActionKey bool / nil - если true, слева от подсказки будет показана кнопка действия actionKey
	-- > actionKey string / nil - кнопка действия. Например, "E" или "RMB" (правая кнопка мыши). По умолчанию E
	-- = void
	setLabel = function( labelText, labelDescription, labelColor, showActionKey, actionKey )
		if labelColor == nil then labelColor = false end
		
		GUI.sendJS( "Crosshair.setLabel", labelText, labelDescription, labelColor, showActionKey, actionKey )
	end;
	
	-- Спрятать подсказку возле прицела
	-- = void
	removeLabel = function()
		GUI.sendJS( "Crosshair.removeLabel" )
	end;
	
	-- Показать прогресс действия (в процентах). Слева направо цвет текста label будет меняться
	-- > progress number - прогресс действия (от 0 до 100)
	-- > color string / nil - цвет, которым будет заполняться label (по умолчанию зеленый, #4CAF50)
	-- = void
	setLabelProgress = function( progress, color )
		GUI.sendJS( "Crosshair.setLabelProgress", progress, color )
	end;
	
	-- Убрать прогресс действия с подсказки
	-- = void
	removeLabelProgress = function()
		GUI.sendJS( "Crosshair.removeLabelProgress" )
	end;
	
	-- Установить форму прицела
	-- > shape string - форма прицела (по умолчанию: "circle")
	-- = void
	setShape = function( shape )
		--Debug.info( "Установлена форма прицела:", shape )
		-- TODO 
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	onClientRender = function()
		-- Не показываем прицел, если игрок целится из оружия
		if ( getControlState( "aim_weapon" ) ) then
			Crosshair.disable( "AimingWeapon" )
		else
			Crosshair.cancelDisabling( "AimingWeapon" )
		end
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, Crosshair.init )