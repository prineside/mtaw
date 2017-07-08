--[[
	Интерфейс для контейнеров
	Синхронизирует контейнеры с клиентами и отвечает за взаимодействие с ними
	
	Когда приходит событие о действии с контейнером, сновную работу делают общие 
	функции модуля, а обработчики события (внутренние функции вида onClient*)
	проводят лишь валидацию
--]]
--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Inventory.onActiveSlotChanged", false )								-- Изменился текущий активный слот быстрого доступа игрока ( player playerElement, number newSlotID, number / nil oldSlotID )

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Inventory.onClientSetActiveFastSlot", true )							-- Игрок изменил номер текущего активного слота быстрого доступа ( number newActiveFastSlotID )

addEvent( "Inventory.onClientDropDraggingStack", true )							-- Игрок выбросил вещи из стака, который тащит мышкой ( number dropedItemsCount )
addEvent( "Inventory.onClientDropContainerItem", true )							-- Игрок выбросил вещи из слота контейнера fast/character/inventory ( string containerType, number slotID, number dropedItemsCount )
addEvent( "Inventory.onClientMoveItemBetweenContainers", true )					-- Игрок переместил вещь между контейнерами ( string sourceContainerType, number sourceSlotID, string targetContainerType, number itemCount )
addEvent( "Inventory.onClientPutDragging", true )								-- Игрок положил вещь из dragging в слот или поменял их местами ( string containerType, number slotID, number itemCount, bool allowDraggingSwap )
addEvent( "Inventory.onClientPutDraggingAcrossSlots", true )					-- Игрок разложил вещи из dragging поравну в несколько слотов, возможно даже разных контейнеров. targetSlots - список слотов вида { containerType : { "fast", "container", ... }, slotID : { 5, 10, ... }, itemCount : { 1, 1, ... } } ( table targetSlots )
addEvent( "Inventory.onClientGrabDragging", true )								-- Игрок взял вещи из слота в dragging ( string containerType, number slotID, number itemCount )

--------------------------------------------------------------------------------
--<[ Модуль Inventory ]>--------------------------------------------------------
--------------------------------------------------------------------------------
Inventory = {
	containers = {}; 		-- Контейнеры ( playerElement => { containerType => Container } )
	draggingStack = {}; 	-- Вещь, которую сейчас тащит мышкой игрок ( playerElement => ItemStack / nil )
	
	activeFastSlot = {}; 	-- Текущий активный слот быстрого доступа ( playerElement => slotID )
	
	attachedActiveFastItemObject = {}; -- Прикрепленные к игрокам объекты с моделями вещей быстрого доступа (playerElement => objects)
	
	init = function()
		addEventHandler( "Character.onCharacterSpawn", resourceRoot, Inventory.onCharacterSpawn )
		addEventHandler( "Character.onCharacterDespawn", resourceRoot, Inventory.onCharacterDespawn )
		
		-- События взаимодействия игрока с инвентарем (в основном через GUI)
		addEventHandler( "Inventory.onClientDropDraggingStack", resourceRoot, Inventory.onClientDropDraggingStack )
		addEventHandler( "Inventory.onClientDropContainerItem", resourceRoot, Inventory.onClientDropContainerItem )
		addEventHandler( "Inventory.onClientMoveItemBetweenContainers", resourceRoot, Inventory.onClientMoveItemBetweenContainers )
		addEventHandler( "Inventory.onClientPutDragging", resourceRoot, Inventory.onClientPutDragging )
		addEventHandler( "Inventory.onClientPutDraggingAcrossSlots", resourceRoot, Inventory.onClientPutDraggingAcrossSlots )
		addEventHandler( "Inventory.onClientGrabDragging", resourceRoot, Inventory.onClientGrabDragging )
		
		addEventHandler( "Inventory.onClientSetActiveFastSlot", resourceRoot, Inventory.onClientSetActiveFastSlot )
	end;
	
	-- Загружен ли инвентарь игрока (чтобы предотвратить дюп и пропажу вещей, нужно проверять это)
	-- > playerElement player
	-- = bool isLoaded
	isLoaded = function( playerElement )
		return Inventory.containers[ playerElement ] ~= nil
	end;
	
	-- Сохранить инвентарь в базу
	-- > playerElement player
	-- = void
	save = function( playerElement )
		if ( Inventory.isLoaded( playerElement ) ) then
			-- Инвентарь был загружен
			local characterID = Character.getID( playerElement )
			
			-- Генерируем запрос на вставку
			local query = "INSERT INTO mtaw.inventory ( character_id, container_type, slot_id, class, params, count ) VALUES "
			local insertRows = {}
			
			for _, containerType in pairs( { "inventory", "character", "fast" } ) do
				for slotID, itemStack in pairs( Inventory.containers[ playerElement ][ containerType ]:getItems() ) do
					table.insert( insertRows, "(" .. characterID .. ", '" .. containerType .. "', " .. slotID .. ", '" .. itemStack:getItem():getClassName() .. "', '" .. DB.escapeString( jsonEncode( itemStack:getItem().params ) ) .. "', " .. itemStack:getCount() .. ")" )
				end
			end
			
			-- Удаляем старые вещи
			DB.syncQuery( "DELETE FROM mtaw.inventory WHERE character_id = " .. characterID .. ";" )
			
			if ( #insertRows ~= 0 ) then
				-- Если есть записи в инвентаре
				query = query .. table.concat( insertRows, "," ) .. ";"
				
				DB.syncQuery( query )
			end
			Debug.info( "Saved player inventory (" .. #insertRows .. " entries)" )
		else
			-- Инвентарь еще не загружен
			Debug.info( "Can't save inventory which is not loaded" )
		end
	end;
	
	-- Возвращает контейнер инвентаря игрока или nil, если инвентарь не загружен
	-- > playerElement player - игрок, чей контейнер необходимо получить
	-- = Container / nil inventoryContainer
	getInventoryContainer = function( playerElement )
		if ( Inventory.isLoaded( playerElement ) ) then
			return Inventory.containers[ playerElement ].inventory
		else
			Debug.error( "Inventory is not loaded" )
			return nil
		end
	end;
	
	-- Возвращает контейнер быстрого доступа игрока или nil, если инвентарь не загружен
	-- > playerElement player - игрок, чей контейнер необходимо получить
	-- = Container / nil fastContainer
	getFastContainer = function( playerElement )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
	
		if ( Inventory.isLoaded( playerElement ) ) then
			return Inventory.containers[ playerElement ].fast
		else
			Debug.error( "Inventory is not loaded for " .. tostring( playerElement ) )
			return nil
		end
	end;
	
	-- Добавить вещь в инвентарь игроку. Работает как Container:addItem, но пытается добавить вещь в fast или inventory (обертка для двух контейнеров)
	-- Возвращает стак вещей, который не влез в инвентарь, или nil, если аргументы введены неправильно / игрок еще не загрузил инвентарь
	-- > playerElement player - игрок, которому нужно добавить вещь
	-- > itemStack ItemStack - вещи, которые нужно добавить
	-- = ItemStack leftToAdd
	addItem = function( playerElement, itemStack )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validClass( itemStack, "itemStack", ItemStack ) then return nil end
		
		local leftToAdd = Inventory.getFastContainer( playerElement ):addItem( itemStack )
		
		if ( leftToAdd:isEmpty() ) then 
			-- Все влезло в быстрый доступ
			return leftToAdd 
		end
		
		leftToAdd = Inventory.getInventoryContainer( playerElement ):addItem( leftToAdd )
		
		return leftToAdd
	end;
	
	-- Установить draggingStack игрока
	-- Возвращает true, если произошли какие-то изменения (не возникло ошибок)
	-- > playerElement player - игрок, которому нужно установить draggingStack
	-- > itemStack ItemStack / nil - стак вещей, который нужно установить или nil
	-- = bool draggingStackSet
	setDraggingStack = function( playerElement, itemStack )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if ( itemStack ~= nil ) then
			if not validClass( itemStack, "itemStack", ItemStack ) then return nil end
		end
		
		if ( Inventory.isLoaded( playerElement ) ) then
			if ( itemStack ~= nil and itemStack:isEmpty() ) then
				-- Пустой стак - устанавливаем сразу nil
				itemStack = nil
			end
			
			Inventory.draggingStack[ playerElement ] = itemStack
			Inventory.sendDraggingStackToClient( playerElement )
			
			return true
		else
			Debug.error( "Inventory is not loaded yet, can't set dragging stack" )
			
			return false
		end
	end;
	
	-- Взять вещи из слота контейнера в draggingStack игрока
	-- Возвращает true, если произошли какие-то изменения (не возникло ошибок)
	-- > playerElement player - игрок, которому нужно установить вещь из слота в dragging
	-- > containerType string - тип контейнера, из которого нужно переместить вещь
	-- > slotID number - номер слота, из которого нужно взять вещь
	-- > itemCount number / nil - количество вещей, которое нужно взять. По умолчнаию - весь стак
	-- = bool isGrabbed
	grabDragging = function( playerElement, containerType, slotID, itemCount )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( containerType, "containerType", "string" ) then return nil end
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validVar( itemCount, "itemCount", { "number", "nil" } ) then return nil end
		
		if ( Inventory.isLoaded( playerElement ) ) then
			local container = Inventory.containers[ playerElement ][ containerType ]
			
			if ( container ) then
				-- Контейнер загружен
				local slotItemStack = container:getItem( slotID )
				
				if ( slotItemStack ~= nil ) then
					-- В слоту есть вещь
					if ( itemCount == nil ) then
						-- Кол-во не указано, устанавливаем размер стака
						itemCount = slotItemStack:getCount()
					else
						-- Кол-во указано, проверяем, хватает ли вещей
						if ( itemCount > slotItemStack:getCount() ) then
							-- Вещей не хватает
							Debug.info( "Not enough items to grab" )
							
							return false
						end
					end
					
					local draggingItemStack = slotItemStack:clone()
					draggingItemStack:setCount( itemCount )
					Inventory.setDraggingStack( playerElement, draggingItemStack )
					
					local newContainerStack = slotItemStack:clone()
					newContainerStack:setCount( slotItemStack:getCount() - itemCount )
					container:setItem( slotID, newContainerStack )
					
					return true
				else
					-- В слоту нет вещи
					Debug.info( "No item in slot " .. containerType .. ":" .. slotID )
				end
			else
				-- Контейнер не загружен или не существует
				Debug.info( "Container " .. containerType .. " not loaded" )
			end
		else
			Debug.info( "Inventory is not loaded yet, can't grab dragging stack" )
		end
		
		return false
	end;
	
	-- Положить вещи из dragging в слот контейнера
	-- Возвращает true, если произошли какие-то изменения (не возникло ошибок)
	-- > playerElement player - игрок, для которого применяется действие
	-- > containerType string - тип контейнера, в который ложится вещь из dragging (inventory/fast/character/external)
	-- > slotID number - номер слота, в который нужно положить вещь
	-- > itemCount number / nil - количество вещей, которое нужно положить. По умолчанию - все, что dragging
	-- > allowDraggingSwap bool / nil - разрешить менять местами dragging и вещь в слоту, если они разные или если слот забит полностью
	-- = bool draggingWasPut
	putDragging = function( playerElement, containerType, slotID, itemCount, allowDraggingSwap )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( containerType, "containerType", "string" ) then return nil end
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validVar( itemCount, "itemCount", { "number", "nil" } ) then return nil end
		
		if ( Inventory.isLoaded( playerElement ) ) then
			-- Инвентарь игрока загружен
			if ( Inventory.containers[ playerElement ][ containerType ] ~= nil ) then
				-- Контейнер существует
				local container = Inventory.containers[ playerElement ][ containerType ]
				if ( Inventory.draggingStack[ playerElement ] ~= nil ) then
					-- Что-то тащит
					local draggingStack = Inventory.draggingStack[ playerElement ]
					local stackToPut = draggingStack:clone()
					
					if ( itemCount == nil ) then
						-- Кол-во не указано - устанавливаем все вещи
						itemCount = draggingStack:getCount()
					else
						-- Кол-во указано, проверяем, хватает ли вещей
						if ( draggingStack:getCount() < itemCount ) then
							-- Не хватает
							Debug.info( "Not enough items to put" )
							
							return false
						end
					end
					
					stackToPut:setCount( itemCount )
					
					local leftToPut = container:addItemToSlot( slotID, stackToPut )
					
					-- Считаем кол-во вещей, которые были положены
					local putItemsCount = stackToPut:getCount() - leftToPut:getCount()
					
					if ( putItemsCount ~= 0 ) then
						-- Положилось хоть что-то - убираем из dragging
						Inventory.draggingStack[ playerElement ]:removeItems( putItemsCount )
						
						-- Обновляем dragging
						Inventory.setDraggingStack( playerElement, Inventory.draggingStack[ playerElement ] )
						
						return true
					elseif ( allowDraggingSwap ) then
						-- Ничего не положилось и разрешено менять местами dragging с вещью в слоту, пробуем положить вещь в слот
						if ( Inventory.draggingStack[ playerElement ]:getCount() == itemCount ) then
							-- Ложатся все вещи - обмен возможен (если бы вещей ложилось меньше, они бы требовали больше места, так как существовало бы 3 разных стака)
							local leftToSet = container:trySetItem( slotID, Inventory.draggingStack[ playerElement ] )
							if ( leftToSet:isEmpty() ) then
								-- Все вещи из dragging могут быть помещены в слот - меняем местами 
								local stackFromContainer = container:getItem( slotID )
								container:setItem( slotID, Inventory.draggingStack[ playerElement ] )
								
								-- Обновляем dragging
								Inventory.setDraggingStack( playerElement, stackFromContainer )
								
								return true
							end
						else
							-- Ложатся не все вещи - мало места для стаков
							Debug.info( "Can't swap a part of items " .. Inventory.draggingStack:getCount() .. " " .. itemCount )
						end
					end
				else
					Debug.info( "Nothing is dragging, nothing to put" )
				end
			else
				Debug.info( "Container " .. containerType .. " not exists, can't put" )
			end
		else
			Debug.info( "Inventory is not loaded yet, can't put dragging" )
		end
		
		return false
	end;
	
	-- Разложить вещи из dragging по слотам контейнеров
	-- Возвращает true, если произошли какие-то изменения (не возникло ошибок)
	-- Возвращает false, если в любой из указанных слотов не удалось положить хоть одну вещь или в dragging не хватило вещей, при этом никаких изменений не произойдет
	-- Разложенные вещи будут изъяты из dragging
	-- > playerElement player - игрок, которому нужно разложить вещи по слотам
	-- > targetSlots table - таблица, содержащая 3 таблицы с данными о слотах, в которые разлаживаются вещи. Имеет вид: { containerType : { "fast", "fast", ... }, slotID : { 1, 2, ... }, itemCount : { 1, 1, ... } }. Данные из каждой из 3-х таблиц берутся по порядку, индексы должны совпадать. Если хотя бы одна вещь не будет положена, не будет положено ничего, и функция вернет false
	-- = bool draggingWasPut
	putDraggingAcrossSlots = function( playerElement, targetSlots )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( targetSlots, "targetSlots", "table" ) then return nil end
		
		if ( Inventory.isLoaded( playerElement ) ) then
			-- Инвентарь уже загружен
			if ( Inventory.draggingStack[ playerElement ] ~= nil ) then
				-- Что-то есть в dragging
				local draggingStack = Inventory.draggingStack[ playerElement ]
				
				-- Проверяем, достаточно ли вещей в dragging для того, чтобы разложить по слотам
				local puttingItemSum = 0
				for idx, itemCount in pairs( targetSlots.itemCount ) do
					puttingItemSum = puttingItemSum + itemCount
				end
				if ( puttingItemSum > draggingStack:getCount() ) then
					-- Ложится в слоты вещей больше, чем в dragging
					Debug.info( "Not enough items to put - dragging " .. draggingStack:getCount() .. ", need " .. puttingItemSum )
					
					return false
				end
				
				-- Тестовый проход - пытаемся положить вещи
				for idx, containerType in pairs( targetSlots.containerType ) do
					local slotID = targetSlots.slotID[ idx ]
					local itemCount = targetSlots.itemCount[ idx ]
					
					if ( itemCount < 1 ) then
						Debug.info( "Setting item count below zero" )
					
						return false
					end
					
					local targetContainer = Inventory.containers[ playerElement ][ containerType ]
					if ( targetContainer ~= nil ) then
						-- Такой контейнер загружен
						local addingStack = draggingStack:clone()
						addingStack:setCount( itemCount )
						local leftToPut = targetContainer:tryAddItemToSlot( slotID, addingStack )
						
						if ( not leftToPut:isEmpty() ) then
							-- Не удалось положить все вещи в этот слот
							Debug.info( "Can't put " .. itemCount .. " items to slot " .. containerType .. ":" .. slotID )
							
							return false
						end
					else
						-- Такой контейнер не существует
						Debug.info( "Target container " .. containerType .. " not loaded" )
						
						return false
					end
				end
				
				-- Тест прошел успешно, добавляем вещи
				local putSummaryItemCount = 0 -- Сколько вещей из dragging было разложено по слотам
				
				for idx, containerType in pairs( targetSlots.containerType ) do
					local slotID = targetSlots.slotID[ idx ]
					local itemCount = targetSlots.itemCount[ idx ]
					
					local addingStack = draggingStack:clone()
					addingStack:setCount( itemCount )
					Inventory.containers[ playerElement ][ containerType ]:addItemToSlot( slotID, addingStack )
					
					putSummaryItemCount = putSummaryItemCount + itemCount
				end
				
				-- Обновляем dragging
				if ( draggingStack:getCount() - putSummaryItemCount ~= 0 ) then
					-- Вещи в dragging еще остались
					draggingStack:setCount( draggingStack:getCount() - putSummaryItemCount )
					Inventory.setDraggingStack( playerElement, draggingStack )
				else
					-- Разложили весь dragging
					Inventory.setDraggingStack( playerElement, nil )
				end
				
				return true
			else
				-- Dragging пуст, нечего ложить
				Debug.info( "Nothing dragging, nothing to put" )
			end
		else
			-- Инвентарь еще не загружен
			Debug.info( "Inventory is not loaded yet" )
		end
		
		return false
	end;
	
	-- Выбросить вещи из draggingStack игрока
	-- Перед игроком будет помещен дроп
	-- Возвращает true, если произошли какие-то изменения (не возникло ошибок)
	-- > playerElement player - игрок, которому нужно выбросить вещи из dragging
	-- > itemCount number / nil - кол-во вещей из dragging, которое нужно выбросить. По умолчанию - все вещи
	-- = bool draggingWasDropped
	dropDragging = function( playerElement, itemCount )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( itemCount, "itemCount", { "number", "nil" } ) then return nil end
		
		if ( Inventory.isLoaded( playerElement ) ) then
			-- Инвентарь игрока загружен
			if ( Inventory.draggingStack[ playerElement ] ~= nil ) then
				-- Игрок что-то тащит
				local draggingStack = Inventory.draggingStack[ playerElement ]
				
				if ( itemCount == nil ) then
					-- Кол-во не указано, устанавливаем все вещи
					itemCount = draggingStack:getCount()
				else
					-- Кол-во указано, проверяем, достаточно ли вещей в dragging
					if ( itemCount > draggingStack:getCount() ) then
						-- Вещей недостаточно
						Debug.info( "Not enough items to drop" )
						
						return false
					end
				end
				
				-- TODO создать дроп
				
				-- Обновление dragging
				local newDraggingStack = draggingStack:clone()
				newDraggingStack:setCount( draggingStack:getCount() - itemCount )
				
				Inventory.setDraggingStack( playerElement, newDraggingStack )
				
				return true
			else
				-- Игрок ничего не такщит
				Debug.info( "Nothing to drop from dragging" )
			end
		else
			-- Инвентарь игрока еще не загружен
			Debug.info( "Can't drop dragging - inventory is not loaded yet" )
		end
		
		return false
	end;
	
	-- Выбросить вещь из контейнера
	-- Перед игроком будет помещен дроп
	-- Возвращает true, если произошли какие-то изменения (не возникло ошибок)
	-- > playerElement player - игрок, которому надо выбросить вещь из контейнера
	-- > containerType string - тип контейнера (inventory/fast...)
	-- > slotID number - номер слота, из которого надо выбросить вещь
	-- > itemCount number / nil - количество вещей, которое нужно выбросить. По умолчанию все вещи в слоту
	-- = bool itemWasDropped
	dropContainerItem = function( playerElement, containerType, slotID, itemCount )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( containerType, "containerType", "string" ) then return nil end
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validVar( itemCount, "itemCount", { "number", "nil" } ) then return nil end
	
		if ( Inventory.isLoaded( playerElement ) ) then
			-- Инвентарь игрока загружен
			if ( Inventory.containers[ playerElement ][ containerType ] ~= nil ) then
				-- Контейнер загружен
				local container = Inventory.containers[ playerElement ][ containerType ]
				
				local slotItemStack = container:getItem( slotID )
				
				if ( slotItemStack ~= nil ) then
					-- В слоту есть вещь
					if ( itemCount == nil ) then
						-- Кол-во не указано, устанавливаем все вещи
						itemCount = slotItemStack:getCount()
					else
						-- Кол-во указано, проверяем, достаточно ли вещей
						if ( itemCount > slotItemStack:getCount() ) then
							-- Вещей недостаточно
							Debug.info( "Not enough items to drop" )
							
							return false
						end
					end
					
					-- TODO создать дроп
				
					-- Обновление слота
					local newSlotItemStack = slotItemStack:clone()
					newSlotItemStack:setCount( slotItemStack:getCount() - itemCount )
					
					container:setItem( slotID, newSlotItemStack )
					
					return true
				else
					-- В слоту нет вещи
					Debug.info( "Can't drop container item - slot " .. containerType .. ":" .. slotID .. " is empty" )
				end
			else
				-- Контейнер не загружен
				Debug.info( "Can't drop container item - container " .. containerType .. " is not loaded" )
			end
		else
			-- Инвентарь игрока еще не загружен
			Debug.info( "Can't drop container item - inventory is not loaded yet" )
		end
		
		return false
	end;
	
	-- Переместить вещь из слота одного контейнера в другой контейнер
	-- Слоты второго контейнера выбираются модулем Container
	-- Возвращает true, если произошли какие-то изменения (не возникло ошибок)
	-- > playerElement player - игрок, которому нужно переместить вещь
	-- > sourceContainerType string - тип контейнера, из которого нужно переместить вещь
	-- > sourceSlotID number - номер слота, из которого нужно переместить вещь
	-- > targetContainerType string - тип контейнера, в который надо переместить вещь
	-- > itemCount number / nil - количество вещей, которое нужно переместить, по умолчанию весь стак
	-- = bool itemsMoved
	moveItemBetweenContainers = function( playerElement, sourceContainerType, sourceSlotID, targetContainerType, itemCount )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( sourceContainerType, "sourceContainerType", "string" ) then return nil end
		if not validVar( sourceSlotID, "sourceSlotID", "number" ) then return nil end
		if not validVar( targetContainerType, "targetContainerType", "string" ) then return nil end
		if not validVar( itemCount, "itemCount", { "number", "nil" } ) then return nil end
		
		if ( Inventory.isLoaded( playerElement ) ) then
			-- Инвентарь уже загружен
			if ( Inventory.containers[ playerElement ][ sourceContainerType ] ~= nil ) then
				-- Контейнер-источник загружен
				local sourceContainer = Inventory.containers[ playerElement ][ sourceContainerType ]
				
				if ( Inventory.containers[ playerElement ][ targetContainerType ] ~= nil ) then
					-- Целевой контейнер загружен
					local targetContainer = Inventory.containers[ playerElement ][ targetContainerType ]
					
					local itemStack = sourceContainer:getItem( sourceSlotID )
				
					if ( itemStack ~= nil ) then
						-- Вещи в слоту источника есть, проверяем количество
						if ( itemCount == nil ) then
							-- Количество не указано - перемещаем все вещи
							itemCount = itemStack:getCount()
						else
							-- Кличество указано - проверяем, достаточно ли вещей
							if ( itemCount > itemStack:getCount() ) then
								-- Не хватает
								Debug.info( "Not enough items to move" )
								
								return false
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
							
							return true
						end
					else
						-- В контейнере-источнике нет вещей
						Debug.info( "No items in " .. sourceContainerType .. ":" .. sourceSlotID )
					end
				else
					-- Целевой контейнер не загружен
					Debug.info( "Target container " .. targetContainerType .. " is not loaded" )
				end
			else 
				-- Контейнер-источник не загружен
				Debug.info( "Source container " .. sourceContainerType .. " is not loaded" )
			end
		else
			-- Инвентарь еще не загружен
			Debug.info( "Can't move items - inventory is not loaded yet" )
		end
		
		return false
	end;
	
	-- Отправить объект контейнера на клиент (как правило, при инициализации или при взаимодействии с новым контейнером)
	-- > playerElement player - игрок, которому необходимо установить контейнер
	-- > containerType string - тип контейнера (inventory/fast/character/external)
	-- = void
	sendContainerToClient = function( playerElement, containerType )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( containerType, "containerType", "string" ) then return nil end
		
		if ( not Inventory.isLoaded( playerElement ) ) then
			Debug.error( "Can't send inventory - it's not loaded yet" )
			return nil
		end
		
		local containerData = nil
		if ( Inventory.containers[ playerElement ][ containerType ] ~= nil ) then
			containerData = Inventory.containers[ playerElement ][ containerType ]:serialize()
		end
		
		triggerClientEvent( playerElement, "Inventory.onServerSetContainer", resourceRoot, containerType, containerData )
	end;
	
	-- Отправить данные об одном слоту контейнера на клиент
	-- > playerElement player - игрок, которому необходимо установить контейнер
	-- > containerType string - тип контейнера (inventory/fast/character/external)
	-- > slotID number - номер слота, который необходимо обновить
	-- = void
	sendContainerSlotToClient = function( playerElement, containerType, slotID )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( containerType, "containerType", "string" ) then return nil end
		if not validVar( slotID, "slotID", "number" ) then return nil end
		
		if ( not Inventory.isLoaded( playerElement ) ) then
			Debug.error( "Can't send inventory slot - it's not loaded yet" )
			return nil
		end
		
		local slotData = false
		if ( Inventory.containers[ playerElement ][ containerType ] ~= nil ) then
			slotData = Inventory.containers[ playerElement ][ containerType ]:getItem( slotID )
			if ( slotData ~= nil ) then
				slotData = slotData:serialize()
			end
		end
		
		if ( slotData == false ) then
			-- Такого контейнера нет
			Debug.error( "Can't send inventory slot - container " .. containerType .. " not exists" )
			return nil
		end
		
		triggerClientEvent( playerElement, "Inventory.onServerSetContainerSlot", resourceRoot, containerType, slotID, slotData )
	end;
	
	-- Отправить данные о вещи, которую тащит игрок, на клиент (draggingStack)
	-- > playerElement player - игрок, которому нужно обновить данные о drarggingStack
	-- = void
	sendDraggingStackToClient = function( playerElement )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		
		if ( Inventory.isLoaded( playerElement ) ) then
			-- Инвентарь игрока загружен
			if ( Inventory.draggingStack[ playerElement ] ~= nil ) then
				triggerClientEvent( playerElement, "Inventory.onServerSetDragging", resourceRoot, Inventory.draggingStack[ playerElement ]:serialize() )
			else
				triggerClientEvent( playerElement, "Inventory.onServerSetDragging", resourceRoot, nil )
			end
		else
			-- Инвентарь игрока не загружен - очищаем dragging на клиенте
			triggerClientEvent( playerElement, "Inventory.onServerSetDragging", resourceRoot, nil )
		end
	end;
	
	-- Установить текущий активный слот быстрого доступа игрока
	-- > playerElement player
	-- > slotID number - номер слота быстрого доступа
	-- = void
	setActiveFastSlot = function( playerElement, slotID )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
		if not validVar( slotID, "slotID", "number" ) then return nil end
		
		if ( slotID < 1 or slotID > 5 ) then
			Debug.error( "Invalid fast slot ID " .. slotID )
		
			return nil
		end
		
		local lastSlotID = Inventory.activeFastSlot[ playerElement ]
		Inventory.activeFastSlot[ playerElement ] = slotID
		
		triggerEvent( "Inventory.onActiveSlotChanged", resourceRoot, playerElement, slotID, lastSlotID )
		
		Inventory.updateCharacterAttachedItems( playerElement ) -- TODO см. updateCharacterAttachedItems
	end;
	
	-- Возвращает ID текущего активного слота быстрого доступа игрока или nil, если инвентарь еще не загружен
	-- > playerElement player
	-- = number / nil activeFastSlotID
	getActiveFastSlot = function( playerElement )
		if not validVar( playerElement, "playerElement", "player" ) then return nil end
	
		if ( not Inventory.isLoaded( playerElement ) ) then return nil end
		
		return Inventory.activeFastSlot[ playerElement ]
	end;
	
	-- Получить стак вещей из текущего активного слота быстрого доступа или nil, если вещи в активном слоту нет
	-- > playerElement player
	-- = ItemStack / nil slotItemStack
	getActiveFastSlotItemStack = function( playerElement )
		local activeSlot = Inventory.getActiveFastSlot( playerElement )
		
		if ( activeSlot ~= nil ) then
			return Inventory.getFastContainer( playerElement ):getItem( activeSlot )
		end
	end;
	
	-- Обновить прикрепленные к игроку модели вещей быстрого доступа
	-- > playerElement player
	-- = void
	updateCharacterAttachedItems = function( playerElement )
		-- TODO перенести в отдельный модуль (InventoryAttachment или PlayerAttachment)
		if ( not Inventory.isLoaded( playerElement ) ) then return nil end
		
		local itemStack = Inventory.getActiveFastSlotItemStack( playerElement )
		
		if ( itemStack == nil ) then
			-- В активном слоту нет вещи, убираем прикрепленный объект
			if ( Inventory.attachedActiveFastItemObject[ playerElement ] ~= nil ) then
				-- Прикрепленная вещь есть, убираем
				destroyElement( Inventory.attachedActiveFastItemObject[ playerElement ] )
				Inventory.attachedActiveFastItemObject[ playerElement ] = nil
			end
		else
			-- В активном слоту есть вещь, сравниваем модели
			if ( Inventory.attachedActiveFastItemObject[ playerElement ] ~= nil ) then
				-- Прикрепленная вещь есть, сравниваем модели
				if ( getElementModel( Inventory.attachedActiveFastItemObject[ playerElement ] ) == itemStack:getItem():getModel() ) then
					-- Модели одинаковые, заменять не нужно
					return nil
				else
					-- Модели разные, убираем старую
					destroyElement( Inventory.attachedActiveFastItemObject[ playerElement ] )
					Inventory.attachedActiveFastItemObject[ playerElement ] = nil
				end
			end
			
			local modelID = itemStack:getItem():getModel()
					
			-- Прикрепляем к руке
			if ( ARR.boneAttachmentOffsets[ tostring( modelID ) ] ~= nil ) then
				-- Есть данные о позиции
				local attachOffset = ARR.boneAttachmentOffsets[ tostring( modelID ) ][ "12" ]
				
				if ( attachOffset ~= nil ) then
					-- Есть позиции прикрепления к руке
					
					-- Создаем новый объект
					local obj = createObject( modelID, 0, 0, 0 )

					setElementDimension( obj, getElementDimension( playerElement ) )
					setObjectScale( obj, attachOffset[1] )
					setElementCollisionsEnabled( obj, false )
					
					exports.BoneAttach:attachElementToBone( obj, playerElement, 12, attachOffset[2], attachOffset[3], attachOffset[4], attachOffset[5], attachOffset[6], attachOffset[7] )
			
					Inventory.attachedActiveFastItemObject[ playerElement ] = obj
				end
			else
				Debug.info( "Model " .. modelID .. " has no attachment offsets" )
			end
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Персонаж добавлен в игровой мир
	onCharacterSpawn = function( playerElement, characterID )
		if ( not Inventory.isLoaded( playerElement ) ) then
			-- Инвентарь еще не загружен (нужно проверять, так как spawn происходит не только при создании персонажа, но и при респане после смерти, при чем despawn не вызывается)
			-- Загружаем инвентарь игрока
			local query = "SELECT * FROM mtaw.inventory WHERE character_id = " .. characterID
			local isSuccess, result = DB.syncQuery( query )
			
			if ( not isSuccess ) then 
				return nil 
			end
			
			-- Создаем контейнеры
			local playerContainers = {
				fast = Container( 5 );
				inventory = Container( 20 );
				character = Container( 2 );
			}
		
			Inventory.containers[ playerElement ] = playerContainers
			
			-- Устанавливаем вещи
			for rowKey, row in pairs( result ) do
				local itemStack = ItemStack( Item( row.class, jsonDecode( row.params ) ), tonumber( row.count ) )
				
				if ( playerContainers[ row.container_type ] == nil ) then
					Debug.error( "Undefined inventory container type: " .. row.container_type )
				else
					playerContainers[ row.container_type ]:setItem( tonumber( row.slot_id ), itemStack )
				end
			end
			
			Debug.info( "Loaded inventory for " .. tostring( playerElement ) )
			
			Inventory.setActiveFastSlot( playerElement, 1 )
			
			-- Добавляем обработчики изменений в контейнерах
			for _, containerType in pairs( { "fast", "inventory", "character" } ) do
				local lContainerType = containerType
				Event.addHandler( "Container.onSlotDataChanged", playerContainers[ lContainerType ], function( slotID, oldSlotData )
					Inventory.onCharacterContainerSlotDataChanged( playerElement, lContainerType, slotID, oldSlotData )
				end )
			end
			
			-- Обновляем инвентарь на клиенте
			Inventory.sendContainerToClient( playerElement, "fast" )
			Inventory.sendContainerToClient( playerElement, "inventory" )
			Inventory.sendContainerToClient( playerElement, "character" )
		end;
	end;
	
	-- Персонаж убран из игрового мира
	onCharacterDespawn = function( playerElement, characterID )
		-- Сохраняем инвентарь
		Inventory.save( playerElement )
		
		-- Выгружаем из памяти
		Inventory.containers[ playerElement ] = nil
		
		-- Если была вещь в руках, убираем
		if ( Inventory.attachedActiveFastItemObject[ playerElement ] ~= nil ) then
			exports.BoneAttach:detachElementFromBone( Inventory.attachedActiveFastItemObject[ playerElement ] )
			
			destroyElement( Inventory.attachedActiveFastItemObject[ playerElement ] )
			Inventory.attachedActiveFastItemObject[ playerElement ] = nil
		end
	end;
	
	-- Изменены данные слота контейнера, который используется игроком
	onCharacterContainerSlotDataChanged = function( playerElement, containerType, slotID, oldSlotData )
		--Debug.info( tostring( playerElement ) .. " " .. containerType .. " slot " .. slotID .. " changed" )
		
		-- Отправляем обновленный слот на клиент
		Inventory.sendContainerSlotToClient( client, containerType, slotID )
		
		if ( containerType == "fast" and slotID == Inventory.getActiveFastSlot( playerElement ) ) then
			-- Изменилась вещь в активном слоту инвентаря игрока, вызываем событие изменения слота быстрого доступа
			Inventory.setActiveFastSlot( playerElement, slotID )
		end
	end;
	
	-- Игрок изменил текущий слот быстрого доступа
	onClientSetActiveFastSlot = function( newSlotID )
		if ( Inventory.getActiveFastSlot( client ) ~= newSlotID ) then
			Inventory.setActiveFastSlot( client, newSlotID )
		end
	end;
	
	-- Игрок сделал попытку выбросить вещи из стака, который сейчас тащит мышкой
	onClientDropDraggingStack = function( dropedItemsCount )
		if not validVar( dropedItemsCount, "dropedItemsCount", "number" ) then return nil end

		if ( not Inventory.dropDragging( client, dropedItemsCount ) ) then
			Inventory.sendDraggingStackToClient( client )
		end
	end;
	
	-- Игрок сделал попытку выбросить вещи из контейнера fast/character/inventory
	onClientDropContainerItem = function( containerType, slotID, itemCount )
		if not validVar( containerType, "containerType", "string" ) then return nil end
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validVar( itemCount, "itemCount", "number" ) then return nil end
		
		if ( not Inventory.dropContainerItem( client, containerType, slotID, itemCount ) ) then
			Inventory.sendContainerSlotToClient( client, containerType, slotID )
		end
	end;
	
	-- Игрок переместил вещь между контейнерами
	onClientMoveItemBetweenContainers = function( sourceContainerType, sourceSlotID, targetContainerType, itemCount ) 
		if not validVar( sourceContainerType, "sourceContainerType", "string" ) then return nil end
		if not validVar( sourceSlotID, "sourceSlotID", "number" ) then return nil end
		if not validVar( targetContainerType, "targetContainerType", "string" ) then return nil end
		if not validVar( itemCount, "itemCount", "number" ) then return nil end
		
		if ( not Inventory.moveItemBetweenContainers( client, sourceContainerType, sourceSlotID, targetContainerType, itemCount ) ) then
			Inventory.sendContainerSlotToClient( client, sourceContainerType, sourceSlotID )
			Inventory.sendContainerToClient( client, targetContainerType )
		end
	end;
	
	-- Игрок положил вещь из dragging в слот контейнера
	onClientPutDragging = function( containerType, slotID, itemCount, allowDraggingSwap ) 
		if not validVar( containerType, "containerType", "string" ) then return nil end
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validVar( itemCount, "itemCount", "number" ) then return nil end
		if not validVar( allowDraggingSwap, "allowDraggingSwap", "boolean" ) then return nil end
	
		if ( not Inventory.putDragging( client, containerType, slotID, itemCount, allowDraggingSwap ) ) then
			Inventory.sendDraggingStackToClient( client )
			Inventory.sendContainerSlotToClient( client, containerType, slotID )
		end
	end;
	
	-- Игрок разложил вещи из dragging в слоты контейнеров поравну
	onClientPutDraggingAcrossSlots = function( targetSlots )
		if not validVar( targetSlots, "targetSlots", "table" ) then return nil end
		
		if ( not Inventory.putDraggingAcrossSlots( client, targetSlots ) ) then
			-- Не удалось разложить вещи - отправляем контейнеры клиенту
			Inventory.sendDraggingStackToClient( client )
			
			local touchedContainers = {}
			for _, containerType in pairs( targetSlots.containerType ) do
				touchedContainers[ containerType ] = true
			end
			
			for containerType, _ in pairs( touchedContainers ) do
				Inventory.sendContainerToClient( client, containerType )
			end
		end
	end;
	
	-- Игрок взял вещи из слота в dragging
	onClientGrabDragging = function( containerType, slotID, itemCount ) 
		if not validVar( containerType, "containerType", "string" ) then return nil end
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validVar( itemCount, "itemCount", "number" ) then return nil end
		
		if ( not Inventory.grabDragging( client, containerType, slotID, itemCount ) ) then
			Inventory.sendDraggingStackToClient( client )
			Inventory.sendContainerSlotToClient( client, containerType, slotID )
		end
	end;
};
addEventHandler( "onResourceStart", resourceRoot, Inventory.init )