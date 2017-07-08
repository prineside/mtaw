--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Inventory.onSetActive", false )										-- Инвентарь установлен активным ( bool isActive )
addEvent( "Inventory.onActiveSlotChanged", false )								-- Изменен активный слот быстрого доступа ( number newSlotID, number oldSlotID )

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Inventory.onServerSetContainer", true )								-- Сервер отправил новые данные контейнера ( string containerType, string / nil serializedContainer )
addEvent( "Inventory.onServerSetContainerSlot", true )							-- Сервер отправил новые данные одного слота контейнера ( string containerType, number slotID, string / nil serializedItemStack )
addEvent( "Inventory.onServerSetDragging", true )								-- Сервер отправил новые данные о draggingStack ( string / nil serializedItemStack )

--------------------------------------------------------------------------------
--<[ События GUI ]>-------------------------------------------------------------
--------------------------------------------------------------------------------
-- Inventory.onMousedownSlot ( string mouseKeyName, string slotType, string slotID, table holdingKeys, number top, number left ) -- если нажал кнопку мыши на слоту и еще не отпустил
-- Inventory.onMouseup ( string mouseKeyName, table holdingKeys, number top, number left ) -- если отпустил кнопку мыши
-- Inventory.onSlotHover ( string slotType, string slotID ) -- если навел на слот инвентаря
-- Inventory.onClickOutsideInventory ( string mouseKeyName, table holdingKeys, number top, number left )
-- Inventory.onKeyPress ( string pressedKey, table holdingKeys, string slotType, string slotID, number top, number left )

--------------------------------------------------------------------------------
--<[ Модуль Inventory ]>--------------------------------------------------------
--------------------------------------------------------------------------------
Inventory = {
	draggingStack = nil;														-- Стак предметов, которые сейчас тащит игрок
	
	containers = {
		fast = nil;			-- Быстрый доступ
		inventory = nil;	-- Основной инвентарь
		character = nil;	-- Персонаж
		external = nil;		-- Внешний контейнер (с которым игрок сейчас взаимодействует)
	};
	
	activeFastSlot = 1;			-- Текущий активный слот из быстрого доступа (1-5)
	
	isActive = false;
	isVisible = false;
	
	dragPutMousedownKeyName = nil;	-- Название кнопки (LMB...), на которую зажал игрок при раскладывании dragging по слотам
	dragPutMouseWalkedOver = false;	-- Список слотов, по которым игрок прошелся курсором с зажатой кнопкой (разложение стака по нескольким слотам)
	
	init = function()
		addEventHandler( "Character.onCharacterChange", resourceRoot, Inventory.onCharacterChange, false, "high" )
		addEventHandler( "Inventory.onServerSetContainer", resourceRoot, Inventory.onServerSetContainer, false )
		addEventHandler( "Inventory.onServerSetContainerSlot", resourceRoot, Inventory.onServerSetContainerSlot, false )
		addEventHandler( "Inventory.onServerSetDragging", resourceRoot, Inventory.onServerSetDragging, false )
		
		-- Действия в GUI
		GUI.addBrowserEventHandler( "Inventory.onMousedownSlot", Inventory.onMousedownSlot )
		GUI.addBrowserEventHandler( "Inventory.onMouseup", Inventory.onMouseup )
		GUI.addBrowserEventHandler( "Inventory.onSlotHover", Inventory.onSlotHover )
		GUI.addBrowserEventHandler( "Inventory.onClickOutsideInventory", Inventory.onClickOutsideInventory )
		GUI.addBrowserEventHandler( "Inventory.onKeyPress", Inventory.onKeyPress )
		
		-- Игрок выключил курсор на Esc, прячем инвентарь
		addEventHandler( "Cursor.onHiddenByEsc", resourceRoot, function()
			if ( Inventory.isActive ) then
				Inventory.setActive( false )
			end
		end )
		
		-- Включение на tab
		bindKey( "tab", "down", Inventory.toggleActive )
		
		-- Переключение активного слота быстрого доступа
		bindKey( "mouse_wheel_down", "down", function() 
			if ( not Cursor.active ) then
				-- При активном курсоре скролл работает в GUI и не переключает активный слот
				if ( not getControlState( "aim_weapon" ) ) then
					-- При прицеливании не переключает
					local newSlot = Inventory.activeFastSlot + 1
					if ( newSlot == 6 ) then
						newSlot = 1
					end
					Inventory.setActiveFastSlot( newSlot )
				end
			end
		end )
		bindKey( "mouse_wheel_up", "down", function() 
			if ( not Cursor.active ) then
				-- При активном курсоре скролл работает в GUI и не переключает активный слот
				if ( not getControlState( "aim_weapon" ) ) then
					-- При прицеливании не переключает
					local newSlot = Inventory.activeFastSlot - 1
					if ( newSlot == 0 ) then
						newSlot = 5
					end
					Inventory.setActiveFastSlot( newSlot )
				end
			end
		end )
		
		-- Цифры
		for i = 1, 5 do
			bindKey( tostring( i ), "down", function() 
				if ( not Cursor.active ) then 
					Inventory.setActiveFastSlot( i ) 
				end 
			end )
		end
		
		Main.setModuleLoaded( "Inventory", 1 )
	end;
	
	-- GUI.sendJS( "InventorySlot.create", "inventory", i )

	-- Сделать инвентарь видимым (показывать панель быстрого доступа)
	-- > setVisible bool / nil - по умолчанию true
	-- = void
	setVisible = function( setVisible )
		if setVisible == nil then setVisible = true end
		
		if ( Inventory.isActive ) then
			Inventory.setActive( false )
		end
		
		GUI.sendJS( "Inventory.setVisible", setVisible )
		
		Inventory.isVisible = setVisible
		
		if ( setVisible ) then
			-- Устанавливаем начальный активный слот быстрого доступа
			Inventory.setActiveFastSlot( Inventory.activeFastSlot )
		end
	end;
	
	-- Сделать инвентарь активным (включить курсор и показать основной инвентарь с меню)
	-- > setActive bool / nil - по умолчанию true
	-- = void
	setActive = function( setActive )
		if setActive == nil then setActive = true end
		
		if ( setActive == true and not Character.isSelected() ) then
			-- Не выбрал персонаж, но открывает инвентарь - отмена
			return nil
		end
		
		-- Невозможно активировать, когда инвентарь не видно
		if ( not Inventory.isVisible ) then
			Debug.info( "Инвентарь нельзя сделать активным, так как он еще не виден" )
			return nil
		end
		
		if ( setActive ) then
			GUI.sendJS( "Inventory.setActive", true )
			Cursor.show( "Inventory" )
			Crosshair.disable( "Inventory" )
		else
			GUI.sendJS( "Inventory.setActive", false )
			Cursor.hide( "Inventory" )
			Crosshair.cancelDisabling( "Inventory" )
			
			-- Выбрасываем то, что игрок тащит мышкой, если оно есть
			if ( Inventory.draggingStack ~= nil ) then
				Inventory.dropDragging()
			end
		end
		
		Inventory.isActive = setActive
		
		triggerEvent( "Inventory.onSetActive", resourceRoot, setActive )
	end;
	
	-- Активировать / деактивировать инвентарь (см. setActive)
	-- = void
	toggleActive = function()
		Inventory.setActive( not Inventory.isActive )
	end;
	
	-- Возрвращает максимальный вес инвентаря, который может переносить игрок
	-- = number maxWeight
	getMaxWeight = function()
		return 30;
	end;
	
	-- Получить вес всех вещей в инвентаре и в быстром доступе
	-- = number totalInventoryWeight
	getWeight = function()
		local totalWeight = 0
		
		for containerType, container in pairs( Inventory.containers ) do
			totalWeight = totalWeight + container:getWeight()
		end
		
		if ( Inventory.draggingStack ~= nil ) then
			totalWeight = totalWeight + Inventory.draggingStack:getWeight()
		end
		
		return totalWeight
	end;
	
	-- Получить стак вещей из текущего активного слота быстрого доступа или nil, если вещи в активном слоту нет
	-- = ItemStack / nil slotItemStack
	getActiveFastSlotItemStack = function()
		if ( Inventory.containers.fast == nil ) then
			-- Еще не загружено
			return nil
		end
		
		return Inventory.containers.fast:getItem( Inventory.activeFastSlot )
	end;
	
	-- Установить стак вещей в dragging
	-- > draggingItemStack ItemStack / nil - вещи, которые перетаскиваются. Если nil, вещь убирается из перетаскивания
	-- = void
	setDraggingStack = function( draggingItemStack )
		if ( draggingItemStack ~= nil ) then
			if not validClass( draggingItemStack, "draggingItemStack", ItemStack ) then return nil end
		end
		
		if ( draggingItemStack == nil or draggingItemStack:isEmpty() ) then
			draggingItemStack = nil
		end
		
		Inventory.draggingStack = draggingItemStack
		
		Inventory.updateGUIContainer( "dragging" )
	end;
	
	-- Превращает объект вещи в массив для передачи в GUI
	-- > itemStack ItemStack
	-- = table guiItemStack
	_itemStackToGuiArray = function( itemStack )
		if not validClass( itemStack, "itemStack", ItemStack ) then return nil end 
	
		-- Сделать из вещи массив для передачи в браузер (так как некоторые параметры могут быть функциями)
		local params = {}
		
		for k, v in pairs( itemStack:getItem().params ) do
			params[ k ] = itemStack:getItem():getParam( k )
		end
		
		return {
			icon = itemStack:getItem():getIcon();
			name = itemStack:getItem():getName();
			descr = itemStack:getItem():getDescr();
			quality = itemStack:getItem():getQuality();
			stats = itemStack:getItem():getGuiStats();
			
			params = params;
			count = itemStack:getCount();
		}
	end;
	
	-- Обновление вещей на GUI
	-- > containerType string / nil - часть GUI, которую надо обновить (inventory/fast/character/external/all...). По умолчанию all
	-- > slotID number / nil - номер слота, который надо обновить. Если не указан, обновляются все слоты 
	-- = void
	updateGUIContainer = function( containerType, slotID )
		if not validVar( containerType, "containerType", { "string", "nil" } ) then return nil end
		if not validVar( slotID, "slotID", { "number", "nil" } ) then return nil end
	
		if ( containerType == nil ) then 
			containerType = "all" 
		end
	
		--Debug.info( "Обновление GUI инвентаря", Inventory )
		local data;
		
		if ( containerType == "inventory" or containerType == "all" ) then
			-- Инвентарь
			if ( slotID == nil ) then
				-- Все слоты
				data = {}
				for k, itemStack in pairs( Inventory.containers.inventory:getItems() ) do
					data[ tostring( k ) ] = Inventory._itemStackToGuiArray( itemStack )
				end
				GUI.sendJS( "Inventory.setContainerItems", "inventory", data )
			else
				-- Один слот
				if ( Inventory.containers.inventory:slotExists( slotID ) ) then
					-- Слот существует
					local itemStack = Inventory.containers.inventory:getItem( slotID )
					if ( itemStack ~= nil ) then
						GUI.sendJS( "Inventory.setContainerItem", containerType, slotID, Inventory._itemStackToGuiArray( itemStack ) )
					else
						GUI.sendJS( "Inventory.setContainerItem", containerType, slotID, false )
					end
				else
					-- Такого слота нет
					Debug.error( "Невозможно обновить GUI инвентаря - контейнер " .. containerType .. " не имеет слота " .. slotID )
				end
			end
		end
		
		if ( containerType == "fast" or containerType == "all" ) then
			-- Быстрый доступ
			if ( slotID == nil ) then
				-- Все слоты
				data = {}
				for k, itemStack in pairs( Inventory.containers.fast:getItems() ) do
					data[ tostring( k ) ] = Inventory._itemStackToGuiArray( itemStack )
				end
				GUI.sendJS( "Inventory.setContainerItems", "fast", data )
			else
				-- Один слот
				if ( Inventory.containers.fast:slotExists( slotID ) ) then
					-- Слот существует
					local itemStack = Inventory.containers.fast:getItem( slotID )
					if ( itemStack ~= nil ) then
						GUI.sendJS( "Inventory.setContainerItem", containerType, slotID, Inventory._itemStackToGuiArray( itemStack ) )
					else
						GUI.sendJS( "Inventory.setContainerItem", containerType, slotID, false )
					end
				else
					-- Такого слота нет
					Debug.error( "Невозможно обновить GUI инвентаря - контейнер " .. containerType .. " не имеет слота " .. slotID )
				end
			end
		end
		
		if ( containerType == "external" or containerType == "all" ) then
			-- Внешний контейнер
			if ( Inventory.containers.external ~= nil ) then
				-- Внешний контейнер загружен
				if ( slotID == nil ) then
					-- Все слоты
					data = {}
					for k, itemStack in pairs( Inventory.containers.external:getItems() ) do
						data[ tostring( k ) ] = Inventory._itemStackToGuiArray( itemStack )
					end
					GUI.sendJS( "Inventory.setContainerItems", "external", data )
				else
					-- Один слот
					if ( Inventory.containers.external:slotExists( slotID ) ) then
						-- Слот существует
						local itemStack = Inventory.containers.external:getItem( slotID )
						if ( itemStack ~= nil ) then
							GUI.sendJS( "Inventory.setContainerItem", containerType, slotID, Inventory._itemStackToGuiArray( itemStack ) )
						else
							GUI.sendJS( "Inventory.setContainerItem", containerType, slotID, false )
						end
					else
						-- Такого слота нет
						Debug.error( "Невозможно обновить GUI инвентаря - контейнер " .. containerType .. " не имеет слота " .. slotID )
					end
				end
			end
		end
		
		if ( containerType == "dragging" or containerType == "all" ) then
			-- Dragging
			if ( Inventory.draggingStack ~= nil ) then
				GUI.sendJS( "Inventory.setDragging", Inventory._itemStackToGuiArray( Inventory.draggingStack ) )
			else
				GUI.sendJS( "Inventory.setDragging", nil )
			end
		end
		
		Inventory.updateGUIWeight()
	end;
	
	-- Обновить отображенный вес инвентаря в GUI
	-- = void
	updateGUIWeight = function()
		GUI.sendJS( "Inventory.setWeight", Inventory.getWeight(), Inventory.getMaxWeight() )
	end;
	
	-- Установка текущего активного слота быстрого доступа
	-- > slotID number - номер слота быстрого доступа, который нужно сделать активным
	-- = void
	setActiveFastSlot = function( slotID )
		if not validVar( slotID, "slotID", "number" ) then return nil end
		
		if ( slotID < 1 or slotID > 5 ) then
			Debug.error( "Неверно указан слот", slotID )
			return nil
		end
		
		if ( Inventory.containers.fast == nil ) then
			-- Быстрый доступ еще не загружен
			return nil
		end
		
		local oldSlot = Inventory.activeFastSlot
		Inventory.activeFastSlot = slotID
		
		GUI.sendJS( "Inventory.setActiveFastSlot", slotID )
		
		-- Отправляем на сервер информацию о том, что слот изменен. Сервер установит прикрепленный к руке объект
		triggerServerEvent( "Inventory.onClientSetActiveFastSlot", resourceRoot, slotID )
		
		-- Вызываем событие об изменении активного слота
		triggerEvent( "Inventory.onActiveSlotChanged", resourceRoot, slotID, oldSlot )
	end;
	
	-- Выбросить вещи из стака, который перетаскивается курсором мыщи
	-- > itemCount number / nil - количество вещей, которое необходимо выбросить. Если не указано, будут выброшены все вещи 
	-- = void
	dropDragging = function( itemCount )
		if not validVar( itemCount, "itemCount", { "number", "nil" } ) then return nil end
		
		if ( Inventory.draggingStack ~= nil ) then
			-- Есть вещи в draggingStack
			if ( itemCount == nil ) then
				-- Количество не указано - выбрасываем все вещи
				itemCount = Inventory.draggingStack:getCount()
			else
				-- Количество указано - проверяем, достаточно ли вещей в стаке
				if ( Inventory.draggingStack:getCount() < itemCount ) then
					-- В стаке меньше вещей, чем указано
					itemCount = Inventory.draggingStack:getCount()
				end
			end
			
			if ( itemCount < 1 ) then
				-- Выбрасывается 0 или меньше вещей - ошибка
				Debug.info( "Ошибка: из draggingStack выбрасывается " .. itemCount .. " вещей" )
			else
				-- Выбрасывается 1 или больше - продолжаем
				-- Отправляем информацию о событии на сервер
				triggerServerEvent( "Inventory.onClientDropDraggingStack", resourceRoot, itemCount )
				
				-- Обновляем стак на клиенте
				Inventory.draggingStack:removeItems( itemCount )
				
				if ( Inventory.draggingStack:isEmpty() ) then
					-- Стак пустой - убираем
					Inventory.setDraggingStack( nil )
				else
					-- Стак не пустой - обновляем на GUI
					Inventory.setDraggingStack( Inventory.draggingStack )
				end
				
				Inventory.updateGUIWeight()
			end
		end
	end;
	
	-- Взять вещи из слота в dragging
	-- Не берет ничего, если в dragging уже что-то есть
	-- > containerType string - тип конейнера, из которого нужно взять вешь
	-- > slotID number - номер слота, из которого нужно взять вещь
	-- > itemCount number / nil - количество вещей, которое нужно взять. По умолчанию весь стак
	-- = void
	grabDragging = function( containerType, slotID, itemCount )
		if not validVar( containerType, "containerType", "string" ) then return nil end
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validVar( itemCount, "itemCount", { "number", "nil" } ) then return nil end
		
		if ( Inventory.draggingStack ~= nil ) then
			-- Уже что-то тащит
			Debug.info( "В dragging уже есть вещи, невозможно взять" )
			
			return nil
		end
		
		if ( Inventory.containers[ containerType ] ~= nil ) then
			-- Контейнер загружен
			local container = Inventory.containers[ containerType ]
			local slotItemStack = container:getItem( slotID )
			
			if ( slotItemStack ~= nil ) then
				-- В соту есть какая-то вещь
				if ( itemCount == nil ) then
					-- Количество не указано - берем все вещи
					itemCount = slotItemStack:getCount()
				else
					-- Количество указано - проверяем, достаточно ли вещей
					if ( slotItemStack:getCount() < itemCount ) then
						-- Вещей недостаточно
						itemCount = slotItemStack:getCount()
					end
				end
				
				-- Устанавливаем dragging
				local draggingStack = slotItemStack:clone()
				draggingStack:setCount( itemCount )
				Inventory.setDraggingStack( stackToGrab )
				
				-- Устанавливаем вещь в контейнере
				local newContainerItem = slotItemStack:clone()
				newContainerItem:setCount( slotItemStack:getCount() - itemCount )
				container:setItem( slotID, newContainerItem )
				
				-- Сообщаем серверу о действии
				triggerServerEvent( "Inventory.onClientGrabDragging", resourceRoot, containerType, slotID, itemCount )
			end
		else
			-- Контейнер еще не загружен
			Debug.info( "Нельзя взять в dragging - контейнер " .. containerType .. " еще не загружен" )
		end
	end;
	
	-- Положить вещь из draggingStack в слот
	-- > containerType string - тип контейнера, в который будет помещена вещь
	-- > slotID number - номер слота, в который будет помещена вещь
	-- > itemCount number / nil - количество вещей, которое должно быть помещено. По умолчанию - все вещи из dragging
	-- > allowDraggingSwap bool / nil - разрешить менять местами вещь из dragging и из слота, если вещи разные или в слоту полный стак. По умолчанию false
	-- = void
	putDragging = function( containerType, slotID, itemCount, allowDraggingSwap )
		if not validVar( containerType, "containerType", "string" ) then return nil end
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validVar( itemCount, "itemCount", { "number", "nil" } ) then return nil end
		if not validVar( allowDraggingSwap, "allowDraggingSwap", { "boolean", "nil" } ) then return nil end
		
		if ( allowDraggingSwap == nil ) then
			allowDraggingSwap = false
		end
		
		if ( Inventory.draggingStack ~= nil ) then
			-- Что-то тащат
			local container = Inventory.containers[ containerType ]
			if ( container == nil ) then
				-- Такого контейнера нет
				Debug.error( "Inventory.putDragging вызван с типом инвентаря \"" .. containerType .. "\", который не загружен" )
				return nil
			end
			
			-- Делаем попытку положить вещь из dragging в этот слот
			local stackToPut = Inventory.draggingStack:clone()
			
			if ( itemCount ~= nil ) then
				-- Количество указано - проверяем, достаточно ли вещей
				if ( itemCount > stackToPut:getCount() ) then
					itemCount = stackToPut:getCount()
				end
				
				stackToPut:setCount( itemCount )
			else
				-- Количество не указано - устанавливаем все вещи
				itemCount = stackToPut:getCount()
			end
			
			local leftItems = container:addItemToSlot( slotID, stackToPut )
			
			-- Считаем кол-во вещей, которые были положены
			local putItemsCount = stackToPut:getCount() - leftItems:getCount()
			
			if ( putItemsCount ~= 0 ) then
				-- Положиось хоть что-то - убираем из dragging
				Inventory.draggingStack:removeItems( putItemsCount )
				
				-- Обновляем dragging и контейнер
				Inventory.setDraggingStack( Inventory.draggingStack )
				--Inventory.updateGUIContainer( slotType, slotID ) -- уже обновилось выше в container:addItemToSlot
				
				-- Сообщаем серверу о действии
				triggerServerEvent( "Inventory.onClientPutDragging", resourceRoot, containerType, slotID, itemCount, allowDraggingSwap )
			elseif ( allowDraggingSwap ) then
				-- Ничего не положилось и разрешено менять местами dragging с вещью в слоту, пробуем положить вещь в слот
				if ( Inventory.draggingStack:getCount() == itemCount ) then
					-- Ложатся все вещи - обмен возможен (если бы вещей ложилось меньше, они бы требовали больше места, так как существовало бы 3 разных стака)
					Debug.info( "Обмен" )
					local leftToSet = container:trySetItem( slotID, Inventory.draggingStack )
					if ( leftToSet:isEmpty() ) then
						-- Все вещи из dragging могут быть помещены в слот - меняем местами 
						local stackFromContainer = container:getItem( slotID )
						container:setItem( slotID, Inventory.draggingStack )
						
						-- Обновляем dragging
						Inventory.setDraggingStack( stackFromContainer )
						
						-- Сообщаем серверу о действии
						triggerServerEvent( "Inventory.onClientPutDragging", resourceRoot, containerType, slotID, itemCount, allowDraggingSwap )
					end
				else
					-- Ложатся не все вещи - мало места для стаков
					Debug.info( "Нельзя обменять часть вещей из dragging со слотом ", Inventory.draggingStack:getCount(), itemCount )
				end
			end
		end
	end;
	
	-- Выбросить вещь из слота контейнера (разрешены только fast/inventory/character)
	-- > containerType string - тип контейнера (fast/character/inventory)
	-- > slotID number - номер слота, из которого нужно выбросить вещь
	-- > itemCount number / nil - количество вещей, которое нужно выбросить. По умолчанию - все вещи из слота
	-- = void
	dropContainerItem = function( containerType, slotID, itemCount )
		if not validVar( containerType, "containerType", "string" ) then return nil end
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validVar( itemCount, "itemCount", { "number", "nil" } ) then return nil end
		
		if ( not ( containerType == "inventory" or containerType == "fast" or containerType == "character" ) ) then
			-- Попытка выбросить вещь не из инвентаря
			Debug.error( "Запрещено выбрасывать вещи из контейнера " .. containerType )
			
			return nil
		end
		
		local container = Inventory.containers[ containerType ]
		if ( container == nil ) then
			-- Контейнер еще не загружен
			Debug.error( "Контейнер " .. containerType .. " не загружен" )
			
			return nil
		end
		
		if ( container:slotExists( slotID ) ) then
			-- Слот существует
			local itemStack = container:getItem( slotID )
			
			if ( itemStack ~= nil ) then
				-- Вещь в слоту есть
				if ( itemCount == nil ) then
					-- Кол-во выбрасываемых вещей не указано, устанавливаем все вещи
					itemCount = itemStack:getCount()
				else
					-- Кол-во выбрасываемых вещей указано, проверяем, хватает ли в стаке вещей
					if ( itemStack:getCount() < itemCount ) then
						itemCount = itemStack:getCount()
					end
				end
				
				if ( itemCount > 0 ) then
					-- Выбрасывается нормальное количество вещей
					
					-- Отправляем информацию о событии на сервер
					triggerServerEvent( "Inventory.onClientDropContainerItem", resourceRoot, containerType, slotID, itemCount )
					
					-- Обновляем стак на клиенте
					itemStack:removeItems( itemCount )
					
					if ( itemStack:isEmpty() ) then
						-- Стак пустой - убираем
						container:clearSlot( slotID )
					else
						-- Стак не пустой - обновляем
						container:setItem( slotID, itemStack )
					end
					
					Inventory.updateGUIWeight()
				else
					-- Выбрасывается вещей <=0
					Debug.error( "Выбрасывается вещей " .. itemCount )
					
					return nil
				end
			end
		else
			-- Слот не существует
			Debug.error( "Контейнер " .. containerType .. " не имеет слота " .. slotID )
			
			return nil
		end
	end;
	
	-- Переместить вещь из одного контейнера в другой
	-- Целевые слоты выбираются автоматически в Container, так само на сервере
	-- > sourceContainerType string - тип контейнера, из которого перемещается вещь
	-- > sourceSlotID number - номер слота, из которого перемещается вещь
	-- > targetContainerType string - тип контейнера, в который перемещается вещь
	-- > itemCount number / nil - количество вещей, которое перемещается. По умолчанию - все вещи в слоту
	-- = void
	moveItemBetweenContainers = function( sourceContainerType, sourceSlotID, targetContainerType, itemCount )
		if not validVar( sourceContainerType, "sourceContainerType", "string" ) then return nil end
		if not validVar( sourceSlotID, "sourceSlotID", "number" ) then return nil end
		if not validVar( targetContainerType, "targetContainerType", "string" ) then return nil end
		if not validVar( itemCount, "itemCount", { "number", "nil" } ) then return nil end
		
		local sourceContainer = Inventory.containers[ sourceContainerType ]
		local targetContainer = Inventory.containers[ targetContainerType ]
		if ( targetContainer ~= nil ) then
			-- Целевой контейнер загружен
			if ( sourceContainer ~= nil ) then
				-- Контейнер-источник загружен
				local itemStack = sourceContainer:getItem( sourceSlotID )
				
				if ( itemStack ~= nil ) then
					-- Вещи в слоту источника есть, проверяем количество
					if ( itemCount == nil ) then
						-- Количество не указано - перемещаем все вещи
						itemCount = itemStack:getCount()
					else
						-- Кличество указано - проверяем, достаточно ли вещей
						if ( itemCount > itemStack:getCount() ) then
							itemCount = itemStack:getCount()
						end
					end	
					
					local movingStack = itemStack:clone()
					movingStack:setCount( itemCount )
					
					local leftToAdd = targetContainer:addItem( movingStack )
					
					if ( leftToAdd:getCount() ~= movingStack:getCount() ) then
						-- Переместили хоть что-то, обновляем контейнер-источник
						local newSourceItem = itemStack:clone()
						newSourceItem:setCount( itemStack:getCount() - ( movingStack:getCount() - leftToAdd:getCount() ) )
						
						sourceContainer:setItem( sourceSlotID, newSourceItem )
						
						-- Отправляем информацию о событии на сервер
						triggerServerEvent( "Inventory.onClientMoveItemBetweenContainers", resourceRoot, sourceContainerType, sourceSlotID, targetContainerType, itemCount )
					end
				end
			else
				-- Контейнер-источник не загружен
				Debug.info( "moveItemBetweenContainers - контейнер-источник " .. sourceContainerType .. " не загружен" )
			end
		else
			-- Целевой контейнер не загружен
			Debug.info( "moveItemBetweenContainers - целевой контейнер " .. targetContainerType .. " не загружен" )
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Убран / заспавнен персонаж
	onCharacterChange = function()
		-- Показываем / скрываем инвентарь
		if ( Character.isSelected() ) then
			Inventory.setVisible( true )
		else
			Inventory.setVisible( false )
		end
	end;
	
	-- Сервер установил содержимое draggingStack
	onServerSetDragging = function( serializedItemStack )
		if ( serializedItemStack == nil ) then
			-- Убрать dragging
			Inventory.setDraggingStack( nil )
		else
			-- Установить с так в dragging
			Inventory.setDraggingStack( ItemStack.unserialize( serializedItemStack ) )
		end
	end;
	
	-- Сервер прислал конфигурацию контейнера
	onServerSetContainer = function( containerType, serializedString )
		Debug.info( "Новая конфигурация контейнера:", jsonDecode( serializedString ), serializedString )
		
		if ( serializedString == nil ) then
			-- Контейнер был выгружен (не должно быть на клиенте), удаляем из GUI
			GUI.sendJS( "Inventory.setContainer", containerType, false )
			
			Inventory.containers[ containerType ] = nil
		else
			-- Контейнер был загружен
			local container = Container.unserialize( serializedString )
			Inventory.containers[ containerType ] = container
			
			GUI.sendJS( "Inventory.setContainer", containerType, container.slotsCount )
			
			-- Устанавливаем вещи в контейнере
			local containerItemsForGUI = {}
			for slotID, itemStack in pairs( container:getItems() ) do
				containerItemsForGUI[ tostring( slotID ) ] = Inventory._itemStackToGuiArray( itemStack )
			end
			GUI.sendJS( "Inventory.setContainerItems", containerType, containerItemsForGUI )
			
			-- Добавляем обработчики изменений в контейнере
			Event.addHandler( "Container.onSlotDataChanged", container, function( slotID, oldSlotData )
				--Debug.info( "Container.onSlotDataChanged" )
				Inventory.onSlotDataChanged( containerType, slotID, oldSlotData )
			end )
			
			Inventory.setActiveFastSlot( Inventory.activeFastSlot )
		end
			
		Inventory.updateGUIWeight()
	end;
	
	-- Сервер прислал содержимое одного слота контейнера
	onServerSetContainerSlot = function( containerType, slotID, serializedString )
		if ( serializedString ~= nil ) then
			--Debug.info( "Новые данные слота " .. slotID .. ":", jsonDecode( serializedString ), serializedString )
		else
			--Debug.info( "Новые данные слота " .. slotID .. ": nil" )
		end
		
		local container = Inventory.containers[ containerType ]
		
		if ( container == nil ) then
			-- Такого контейнера нет
			Debug.error( "Сервер прислал содержимое слота " .. containerType .. ":" .. slotID .. ", но такой контейнер не загружен" )
			
			return nil
		end
		
		if ( serializedString ~= nil ) then
			-- В слоту какая-то вещь - устанавливаем
			container:setItem( slotID, ItemStack.unserialize( serializedString ) )
		else
			-- В слоту нет вещи - удаляем
			container:clearSlot( slotID )
		end
		
		--container:debugPrint()
		Inventory.updateGUIWeight()
	end;
	
	-- Изменились данные слота контейнера
	onSlotDataChanged = function( containerType, slotID, oldSlotData )
		-- Обновляем GUI
		local container = Inventory.containers[ containerType ]
		
		if ( container == nil ) then
			-- Такого контейнера нет
			Debug.error( "Изменилось содержимое контейнера " .. containerType .. ":" .. slotID .. ", но такой контейнер не загружен" )
			
			return nil
		end
		
		local itemGuiData = container:getItem( slotID )
		if ( itemGuiData == nil ) then
			-- В слоту нет вещи
			itemGuiData = false
		else
			-- В слоту есть вещь
			itemGuiData = Inventory._itemStackToGuiArray( itemGuiData )
		end
		
		GUI.sendJS( "Inventory.setContainerItem", containerType, slotID, itemGuiData )
	end;
	
	-- Нажал на слот в инвентаре (событие GUI)
	onMousedownSlot = function( mouseKeyName, slotType, slotID, holdingKeys, top, left )
		if ( mouseKeyName == "MMB" ) then
			-- СКМ на слоту - ничего не делаем
			return nil
		end
		
		if ( Inventory.isActive ) then
			-- Инвентарь активен
			local container = Inventory.containers[ slotType ]
			if ( container == nil ) then
				-- Такого контейнера нет
				Debug.error( "Inventory.onMousedownSlot вызван с типом инвентаря \"" .. slotType .. "\", который не загружен" )
				return nil
			end
			
			local slotStack = container:getItem( slotID )
			
			if ( holdingKeys[ GUI.keyNameToKeyCode( 'shift' ) ] ) then
				-- Защали shift - перемещаем вещь между контейнерами, если она есть
				if ( slotStack ~= nil ) then
					-- В слоту есть вещь - перемещаем вещь между контейнерами
					local targetContainerType = nil
						
					if ( slotType == "fast" ) then
						-- Из слота быстрого доступа в основной инвентарь
						targetContainerType = "inventory"
					elseif ( slotType == "inventory" ) then
						-- Из основного инвентаря
						if ( Inventory.containers.external == nil ) then
							-- В слоты быстрого доступа
							targetContainerType = "fast"
						else
							-- Во внешний контейнер
							targetContainerType = "external"
						end
					end
					
					if ( targetContainerType ~= nil ) then
						-- Целевой контейнер найден - пытаемся переместить в него все вещи из стака
						if ( mouseKeyName == "LMB" ) then
							-- ЛКМ - все вещи
							Inventory.moveItemBetweenContainers( slotType, slotID, targetContainerType )
						elseif ( mouseKeyName == "RMB" ) then
							-- ПКМ - одну вещь
							Inventory.moveItemBetweenContainers( slotType, slotID, targetContainerType, 1 )
						end
					end
				end
			else
				-- Не зажали shift - обычное взаимодействие
				if ( Inventory.draggingStack ~= nil ) then
					-- Уже что-то тащим - добавляем в список слотов, на которые разлаживаются вещи, первый слот
					Inventory.dragPutMousedownKeyName = mouseKeyName
					Inventory.dragPutMouseWalkedOver = {}
					
					table.insert( Inventory.dragPutMouseWalkedOver, { 
						containerType = slotType;
						slotID = slotID;
					} )
				else
					-- Еще ничего не тащит
					if ( slotStack ~= nil ) then
						-- В слоту что-то было, делаем попытку взять вещь из сота в dragging
						if ( mouseKeyName == "RMB" ) then
							-- ПКМ - берем только половину
							Inventory.grabDragging( slotType, slotID, math.ceil( slotStack:getCount() / 2 ) )
						else
							-- Берем все
							Inventory.grabDragging( slotType, slotID )
						end
					end
				end
			end
		end
	end;
	
	-- Навел на слот инвентаря
	onSlotHover = function( containerType, slotID )
		if ( Inventory.dragPutMouseWalkedOver ~= false ) then
			-- mousedown в силе - значит, есть dragging stack, и вещи пытаются разложить по нескольким слотам
			local draggingStack = Inventory.draggingStack
			if ( draggingStack == nil ) then
				-- Уже ничего не тащится (возможно, сервер сбросил) - отменяем все
				Debug.info( "Уже ничего не тащим" )
				Inventory.dragPutMouseWalkedOver = false
				
				return nil
			end
			
			-- Проверяем, наводили ли на этот слот уже
			for _, walkedOver in pairs( Inventory.dragPutMouseWalkedOver ) do
				if ( walkedOver.containerType == containerType and walkedOver.slotID == slotID ) then
					-- На этот слот уже наводили с момента последнего mousedown, ничего не делаем
					return nil
				end
			end
			
			-- Добавляем слот в список слотов, по которым прошелся игрок
			table.insert( Inventory.dragPutMouseWalkedOver, { 
				containerType = containerType;
				slotID = slotID;
			} )
			
			-- Раскладываем вещи по слотам на GUI (сам контейнер не трогаем)
			local mouseKeyName = Inventory.dragPutMousedownKeyName
			local availableSlots = draggingStack:getCount()	-- Макс. кол-во слотов, в которое можно разложить стак (минимум 1 вещь на слот)
			
			-- Ищем слоты, в которые можно положить хотя бы одну вещь
			local validSlots = {} -- { containerType, containerID, freeSpace }
			for _, walkedOver in pairs( Inventory.dragPutMouseWalkedOver ) do
				local container = Inventory.containers[ walkedOver.containerType ]
				local leftToAdd = container:tryAddItemToSlot( walkedOver.slotID, draggingStack )
				if ( leftToAdd:getCount() ~= draggingStack:getCount() ) then
					-- Положилось хоть что-то
					availableSlots = availableSlots - 1
					table.insert( validSlots, { walkedOver.containerType, walkedOver.slotID, draggingStack:getCount() - leftToAdd:getCount() } )
					if ( availableSlots == 0 ) then
						-- Больше слотов нет, прекращаем цикл
						break
					end
				end
			end
			
			-- Узнаем, по сколько вещей ложить в каждый слот
			local itemsPerSlot
			if ( mouseKeyName == "LMB" ) then
				itemsPerSlot = math.floor( draggingStack:getCount() / #validSlots )
			elseif ( mouseKeyName == "RMB" ) then
				itemsPerSlot = 1
			else
				return nil
			end
			
			-- Устанавливаем (только визуально) вещи в слотах
			local totalAddedCount = 0
			for _, walkedOver in pairs( validSlots ) do
				local containerType = walkedOver[ 1 ]
				local slotID = walkedOver[ 2 ]
				local maxItems = walkedOver[ 3 ]
				
				local addedCount = itemsPerSlot
				if ( addedCount > maxItems ) then
					-- Недостаточно места, чтобы поместить как в другие слоты - устанавливаем оставшееся свободное место
					addedCount = maxItems
				end
				
				totalAddedCount = totalAddedCount + addedCount
				local newCount = 0
				if ( Inventory.containers[ containerType ]:getItem( slotID ) ~= nil ) then
					newCount = Inventory.containers[ containerType ]:getItem( slotID ):getCount()
				end
				newCount = newCount + addedCount
				
				-- Обновляем слот на GUI
				local pseudoStack = draggingStack:clone()
				pseudoStack:setCount( newCount )
				GUI.sendJS( "Inventory.setContainerItem", containerType, slotID, Inventory._itemStackToGuiArray( pseudoStack ) )
				GUI.sendJS( "InventorySlot.addClass", containerType, slotID, "put-walked-over" )
			end
				
			-- Обновляем (визуально) dragging на GUI
			local pseudoDraggingStack = draggingStack:clone()
			pseudoDraggingStack:setCount( draggingStack:getCount() - totalAddedCount )
			GUI.sendJS( "Inventory.setDragging", Inventory._itemStackToGuiArray( pseudoDraggingStack ) )
		end
	end;
	
	-- Отпустил кнопку мыши
	onMouseup = function( mouseKeyName, holdingKeys, top, left )
		if ( Inventory.dragPutMouseWalkedOver == false ) then
			-- Не было события onmousedown
			return nil
		end
		
		if ( Inventory.isActive ) then
			-- Инвентарь активен
			if ( #Inventory.dragPutMouseWalkedOver == 1 ) then
				-- Нажал и отпустил на одном слоту, при этом есть dragging stack
				local containerType = Inventory.dragPutMouseWalkedOver[ 1 ].containerType
				local slotID = Inventory.dragPutMouseWalkedOver[ 1 ].slotID
				
				if ( mouseKeyName == "RMB" ) then
					-- Пытаемся положить 1 вещь
					Inventory.putDragging( containerType, slotID, 1, true )
				else
					-- Пытаемся положить весь стак
					Inventory.putDragging( containerType, slotID, nil, true )
				end
			else
				-- Нажал на одном слоту и протащил по нескольким слотам
				local draggingStack = Inventory.draggingStack
				if ( draggingStack == nil ) then
					-- Уже ничего не тащится (возможно, сервер сбросил) - отменяем все
					Debug.info( "Уже ничего не тащим" )
					
					Inventory.dragPutMouseWalkedOver = false
					GUI.sendJS( "InventorySlot.removeClassOfAll", "put-walked-over" )
					
					Inventory.updateGUIContainer( "all" )
					
					return nil
				end
			
				local availableSlots = draggingStack:getCount()	-- Макс. кол-во слотов, в которое можно разложить стак (минимум 1 вещь на слот)
				
				-- Ищем слоты, в которые можно положить хотя бы одну вещь
				local validSlots = {} -- { containerType, containerID, freeSpace }
				for _, walkedOver in pairs( Inventory.dragPutMouseWalkedOver ) do
					local container = Inventory.containers[ walkedOver.containerType ]
					local leftToAdd = container:tryAddItemToSlot( walkedOver.slotID, draggingStack )
					if ( leftToAdd:getCount() ~= draggingStack:getCount() ) then
						-- Положилось хоть что-то
						availableSlots = availableSlots - 1
						
						table.insert( validSlots, { 
							containerType = walkedOver.containerType;
							slotID = walkedOver.slotID; 
							maxItems = draggingStack:getCount() - leftToAdd:getCount(); 
						} )
						
						if ( availableSlots == 0 ) then
							-- Больше слотов нет, прекращаем цикл
							break
						end
					end
				end
				
				-- Узнаем, по сколько вещей ложить в каждый слот
				local itemsPerSlot
				if ( mouseKeyName == "LMB" ) then
					itemsPerSlot = math.floor( draggingStack:getCount() / #validSlots )
				elseif ( mouseKeyName == "RMB" ) then
					itemsPerSlot = 1
				else
					return nil
				end
			
				-- Устанавливаем вещи в слотах
				local totalAddedCount = 0
				for k, walkedOver in pairs( validSlots ) do
					local addedCount = itemsPerSlot
					if ( addedCount > walkedOver.maxItems ) then
						-- Недостаточно места, чтобы поместить как в другие слоты - устанавливаем оставшееся свободное место
						addedCount = walkedOver.maxItems
					end
					
					totalAddedCount = totalAddedCount + addedCount
					local newCount = 0
					if ( Inventory.containers[ walkedOver.containerType ]:getItem( walkedOver.slotID ) ~= nil ) then
						newCount = Inventory.containers[ walkedOver.containerType ]:getItem( walkedOver.slotID ):getCount()
					end
					newCount = newCount + addedCount
					
					-- Сохраняем обратно в массив (для отправки на сервер)
					validSlots[ k ].addedCount = addedCount
					
					-- Обновляем слот контейнера
					local newStack = draggingStack:clone()
					newStack:setCount( newCount )
					Inventory.containers[ walkedOver.containerType ]:setItem( walkedOver.slotID, newStack )
				end
					
				-- Обновляем dragging
				local newDraggingStack = draggingStack:clone()
				newDraggingStack:setCount( draggingStack:getCount() - totalAddedCount )
				Inventory.setDraggingStack( newDraggingStack )
				
				-- Отправляем на сервер данные о действии
				local putSlotsData = {
					containerType = {};
					slotID = {};
					itemCount = {};
				}
				for k, walkedOver in pairs( validSlots ) do
					table.insert( putSlotsData.containerType, walkedOver.containerType )
					table.insert( putSlotsData.slotID, walkedOver.slotID )
					table.insert( putSlotsData.itemCount, walkedOver.addedCount )
				end
				
				triggerServerEvent( "Inventory.onClientPutDraggingAcrossSlots", resourceRoot, putSlotsData )
			end
		end
		
		Inventory.dragPutMouseWalkedOver = false
		
		GUI.sendJS( "InventorySlot.removeClassOfAll", "put-walked-over" )
	end;
	
	-- Нажал за рамками инвентаря (событие GUI)
	onClickOutsideInventory = function( mouseKeyName, holdingKeys, top, left )
		--Debug.info( "onClickOutsideInventory", mouseKeyName, holdingKeys, top, left )
		
		if ( Inventory.isActive ) then
			-- Инвентарь активен
			if ( Inventory.draggingStack ~= nil ) then
				-- Что-то тащит
				local dropedStack = Inventory.draggingStack:clone()
				
				if ( mouseKeyName == "RMB" ) then
					-- ПКМ - выбрасываем одну вещь из стака
					Inventory.dropDragging( 1 )
				elseif ( mouseKeyName == "LMB" ) then
					-- Выбрасываем все вещи
					Inventory.dropDragging()
				end
			end
		end
	end;
	
	-- Нажал на кнопку клавиатуры (событие GUI)
	onKeyPress = function( pressedKey, holdingKeys, slotType, slotID, insideInventory, top, left )
		--Debug.info( "onKeyPress", pressedKey, holdingKeys, slotType, slotID, insideInventory, top, left )
		pressedKey = tostring( pressedKey )
		
		if ( Inventory.isActive ) then
			-- Инвентарь активен
			if ( pressedKey == GUI.keyNameToKeyCode( 'q' ) ) then
				-- Нажал на Q
				if ( slotType == "character" or slotType == "fast" or slotType == "inventory" ) then
					-- При этом навел мышку на слот инвентаря (не внешнего), выбрасываем вещи
					if ( holdingKeys[ GUI.keyNameToKeyCode( 'ctrl' ) ] ) then
						-- Зажат Ctrl - выбрасываем все вещи
						Inventory.dropContainerItem( slotType, slotID )
					else
						-- Выбрасываем одну вещь из слота
						Inventory.dropContainerItem( slotType, slotID, 1 )
					end
				end
			end
		end
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Inventory.init )