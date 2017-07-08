--[[
	Контейнер для вещей
	Что делает:
	- Хранит ItemStack в слотах
	- Позволяет установить или получить ItemStack из слота по его номеру
	- Позволяет искать вещи по классу вещей
	- Позволяет добавлять в контейнер вещи без указания слота
	- Вызывает события изменения вещей в слотах, которые можно отменить
	Что не делает:
	- Не отвечает за фильтр слотов
	- Не запрещает размещать любые вещи в слоты (только если события отменяют другие модули)
	- Никак не связан с инвентарем, GUI и прочими вещами
	
	TODO функции trySetItem и tryAddItemToSlot использовать внутри своих не-тестовых аналогов, вместо того, чтобы писать дважды
--]]

--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
-- Событие объекта: "Container.onSlotDataChanged"								-- Изменились данные слота. Если отменить событие, установка вещи не произойдет ( number slotID, ItemStack oldSlotData )

--------------------------------------------------------------------------------
--<[ Модуль Container ]>--------------------------------------------------------
--------------------------------------------------------------------------------
Container = {
	-- Конструктор Container(), возвращает объект контейнера или nil, если неправильно заданы аргументы
	-- > slotsCount number - количество слотов в контейнере
	-- = Container / nil container
	create = function( slotsCount )
		if not validVar( slotsCount, "slotsCount", "number" ) then return nil end
		
		local t = setmetatable( {}, Container )
		
		t.slotsCount = slotsCount
		t.items = {}
	
		return t
	end;
	
	-- Превращает строку, полученную через container:serialize() обратно в объект
	-- > serializedString string - строка, полученная через Container:serialize
	-- = Container container
	unserialize = function( serializedString )
		local data = jsonDecode( serializedString )
		
		local container = Container( data.slotsCount )
		
		if ( data.items ~= nil ) then
			local items = {}
			for slotID, serializedItemStack in pairs( data.items ) do
				items[ slotID ] = ItemStack.unserialize( serializedItemStack )
			end
			container:setItems( items )
		end
		
		if ( data.ruleString ~= nil ) then
			container:setRule( data.ruleString )
		end
		
		if ( data.maxStackSize ~= nil ) then
			container:setMaxStackSize( data.maxStackSize )
		end
		
		if ( data.slotRuleString ~= nil ) then
			for slotID, slotRule in pairs( data.slotRuleString ) do
				container:setSlotRule( slotID, slotRule )
			end
		end
		
		if ( data.slotMaxStackSize ~= nil ) then
			for slotID, slotMaxStackSize in pairs( data.slotMaxStackSize ) do
				container:setSlotMaxStackSize( slotID, slotMaxStackSize )
			end
		end
		
		return container
	end;
	
	----------------------------------------------------------------------------
	--<[ Объект ]>--------------------------------------------------------------
	----------------------------------------------------------------------------
	
	slotsCount = nil;		-- number
	items = {};				-- slotID -> ItemStack / nil
	
	ruleString = nil;		-- Правило размещения вещей во всех слотах контейнера
	slotRuleString = {};	-- slotID -> string
	
	maxStackSize = nil;		-- Максимальный размер стака вещей во всех слотах. Если nil, ограничение не применяется
	slotMaxStackSize = {};	-- slotID -> number / nil
	
	-- Создаются в setRule и setSlotRule
	_ruleFunction = nil;	-- function ( Item )
	_slotRuleFunction = {};	-- slotID -> function
	
	-- Выводит содержимое контейнера в консоль
	-- > self Container
	-- = void
	debugPrint = function( self )
		Debug.info( "=== Container" )
		Debug.info( "Slots count: " .. self.slotsCount )
		Debug.info( "Rule string: " .. tostring( self.ruleString ) )
		Debug.info( "Max stack size: " .. tostring( self.maxStackSize ) )
		Debug.info( "Slots: " )
		Debug.info( "#  | maxStack | rules |" )
		for slotID = 1, self.slotsCount do
			Debug.info( string.format( "%2s | %8s | %4s | %s", 
										slotID, 
											  self.slotMaxStackSize[ slotID ] and tostring( self.slotMaxStackSize[ slotID ] ) or "-", 
													self.slotRuleString[ slotID ] and "true" or "false",
														  self.items[ slotID ] and self.items[ slotID ]:getItem():getClassName() .. " x" .. self.items[ slotID ]:getCount() or "-"
			) )
		end
	end;
	
	-- Возвращает true, если такой слот существует в контейнере
	-- > self Container
	-- > slotID number - номер слота
	-- = bool slotExists
	slotExists = function( self, slotID )
		return slotID > 0 and slotID <= self.slotsCount
	end;
	
	-- Установить (перезаписать) правила в виде выражения lua для установки вещи в любой слот контейнера. Если правило при выполнении вернет false, вещь помещена не будет
	-- Чтобы запретить ложить любые вещи, достаточно установить правило "false" (функция работает как "return rule")
	-- Пример правила: "( item:hasTag( 'grindable' ) and not item:hasTag( 'food' ) ) or item:getQuality() ~= 1" или просто "item:getClass() == ItemClass.wheat"
	-- > self Container
	-- > globalRule string - сторока с условием, которое должно исполниться, чтобы вещь была помещена в слот. Получает на входе переменную Item "item" из ItemStack, который ложится
	-- = void
	setRule = function( self, globalRule )
		if not validVar( globalRule, "globalRule", "string" ) then return nil end
		
		self.ruleString = globalRule
		self._ruleFunction = loadstring( "return " .. globalRule )
	end;
	
	-- Установить (перезаписать) правила в виде выражения lua для установки вещи в слот. Если правило при выполнении вернет false, вещь помещена не будет
	-- Перезаписывает глобальное правило контейнера для указанного слота, установленное через setRule
	-- > self Container
	-- > slotID number - номер слота, для которого нужно установить правило
	-- > slotRule string - сторока с условием, которое должно исполниться, чтобы вещь была помещена в слот. Получает на входе переменную Item "item" из ItemStack, который ложится
	-- = void
	setSlotRule = function( self, slotID, slotRule )
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validVar( slotRules, "slotRules", "string" ) then return nil end
		
		if ( not self:slotExists( slotID ) ) then 
			Debug.error( "Slot " .. slotID .. " not exists" )
			return nil 
		end
		
		self.slotRuleString = slotRule
		self._slotRuleFunction = loadstring( "return " .. slotRule )
	end;
	
	-- Установить максимальный размер стека в люблм слоту (но не больше размера стака вещи). Например, если размер ItemStack 8, а в слоту размепр 1, будет положена только 1 вещь, и вернется 7.
	-- Если же maxStackSize равен 16, а максимальный размер itemStack 8, он по-прежнему останется 8
	-- > self Container 
	-- > maxStackSize number / nil - максимальный размер стака в любом слоту контейнера. По умолчанию ограничение на размер стака снимается (используется размер стака ItemStack)
	-- = void
	setMaxStackSize = function( self, maxStackSize )
		if not validVar( maxStackSize, "maxStackSize", { "number", "nil" } ) then return nil end
		
		if ( maxStackSize < 1 ) then
			Debug.error( "Can't set stack max size to " .. maxStackSize .. ". If you need to restrict setting any item, use setRule" )
			return nil
		end
		
		self.maxStackSize = maxStackSize
	end;
	
	-- Установить максимальный размер стека в указанном слоту (но не больше размера стака вещи).
	-- Перезаписывает глобальное ограничение контейнера (установленное через setMaxStackSize)
	-- > self Container 
	-- > slotID number - номер слота контейнера
	-- > maxStackSize number - максимальный размер стака в любом слоту контейнера, по умолчанию ограничение снимается (берется из глобального ограничения или размера ItemStack)
	-- = void
	setSlotMaxStackSize = function( self, slotID, maxStackSize )
		if not validVar( maxStackSize, "maxStackSize", "number" ) then return nil end
		if not validVar( slotID, "slotID", "number" ) then return nil end
		
		if ( maxStackSize < 1 ) then
			Debug.error( "Can't set stack max size to " .. maxStackSize .. ". If you need to restrict setting any item, use setRule" )
			return nil
		end
		
		if ( not self:slotExists( slotID ) ) then 
			Debug.error( "Slot " .. slotID .. " not exists" )
			return nil 
		end
		
		self.slotMaxStackSize[ slotID ] = maxStackSize
	end;
	
	-- Возвращает максимальный размер стака вещей, которые могут быть помещены в указанный слот
	-- Возвращает действительный лимит (с учетом размера itemStack и глобального ограничения контейнера), а не setSlotMaxStackSize
	-- > self Container
	-- > slotID number - номер слота
	-- > itemStack ItemStack / nil - стак вещей, которые теоретически вставляются в слот. При nil вернет ограничение без проверки размера стака itemStack
	-- = number maxStackSize
	getSlotMaxStackSize = function( self, slotID, itemStack )
		if not validVar( slotID, "slotID", "number" ) then return nil end
		
		if ( itemStack ~= nil ) then
			if not validClass( itemStack, "itemStack", ItemStack ) then return nil end
		end
		
		if ( itemStack ~= nil ) then
			-- С учетом itemStack
			local slotMaxStackSize = itemStack:getStackSize()
			if ( self.maxStackSize ~= nil and self.maxStackSize < slotMaxStackSize ) then
				-- Есть общее ограничение для всех слотов, и оно меньше размера стака вещи
				slotMaxStackSize = self.maxStackSize
			end
			if ( self.slotMaxStackSize[ slotID ] ~= nil and self.slotMaxStackSize[ slotID ] < itemStack:getStackSize() ) then
				-- Есть ограничение для этого слота, и оно меньше размера стака вещи - перезаписываем
				slotMaxStackSize = self.slotMaxStackSize[ slotID ]
			end
			
			return slotMaxStackSize
		else
			-- Без учета itemStack
			local slotMaxStackSize = ItemStack.MAX_SIZE
			if ( self.maxStackSize ~= nil ) then
				-- Есть общее ограничение для всех слотов
				slotMaxStackSize = self.maxStackSize
			end
			if ( self.slotMaxStackSize[ slotID ] ~= nil ) then
				-- Есть ограничение для этого слота, и оно меньше размера стака вещи - перезаписываем
				slotMaxStackSize = self.slotMaxStackSize[ slotID ]
			end
			
			return slotMaxStackSize
		end
	end;
	
	-- Возвращает true, если правилами контейнера и слота не запрещено вставлять вещь в этот слот
	-- > self Container
	-- > slotID number - номер слота
	-- > itemStack ItemStack - стак вещей, который будет проверен на соответствие условиям правил
	-- = bool isAllowed
	isItemAllowedInSlot = function( self, slotID, itemStack )
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validClass( itemStack, "itemStack", ItemStack ) then return nil end
		
		if ( not self:slotExists( slotID ) ) then 
			Debug.error( "Slot " .. slotID .. " not exists" )
			return nil 
		end
		
		local permitedBySlotRule = false
		if ( self._slotRuleFunction[ slotID ] ~= nil ) then
			-- Существует правило для слота
			local item = itemStack:getItem()
			if not ( self._slotRuleFunction[ slotID ]() ) then
				-- Правило слота не выполнилось
				return false
			end
			permitedBySlotRule = true
		end
		
		if ( not permitedBySlotRule ) then
			-- Правило слота не дало право размещать вещь и не запретила это делать, проверяем общее правило
			if ( self._ruleFunction ~= nil ) then
				-- Существует общее правило
				local item = itemStack:getItem()
				if not ( self._ruleFunction() ) then
					-- Общее правило не выполнилось
					return false
				end
			end
		end
		
		return true
	end;
	
	-- Возвращает вес всех вещей в контейнере
	-- > self Container
	-- = number containerWeight
	getWeight = function( self )
		local weight = 0
		
		for _, itemStack in pairs( self:getItems() ) do
			weight = weight + itemStack:getWeight()
		end
		
		return weight
	end;
	
	-- Сделать попытку положить вещи в слот. В действительности не изменяет содержимое контейнера, но возвращает в точности то же, что и setItem
	-- Полезно для того, чтобы узнать, можно ли положить вещь в слот прежде чем это делать
	-- > self Container
	-- > slotID number - номер слота
	-- > itemStack ItemStack - стак вещей, который пытаемся установить в слот
	-- = ItemStack itemsLeft
	trySetItem = function( self, slotID, itemStack )
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validClass( itemStack, "itemStack", ItemStack ) then return nil end
		
		if ( not self:slotExists( slotID ) ) then 
			Debug.error( "Slot " .. slotID .. " not exists" )
			return nil 
		end
		
		-- Проверяем, выполняются ли правила (правило слота важнее общего)
		if ( not self:isItemAllowedInSlot( slotID, itemStack ) ) then
			-- Запрещено ложить эту вещь в этот слот - возвращаем все в целосности и сохранности
			return leftToSet
		end
		
		-- Условия правил выполняются, размещаем вещь
		-- Ищем максимальный размер стека в этом слоту
		local slotMaxStackSize = self:getSlotMaxStackSize( slotID, itemStack )
		
		-- Считаем, что может быть положено
		local leftToSet = itemStack:clone()
		if ( leftToSet:getCount() > slotMaxStackSize ) then
			-- Все не влезет, ограничиваем до макс. размера стака
			leftToSet:setCount( leftToSet:getCount() - slotMaxStackSize )
		else
			-- Влезает все
			leftToSet:setCount( 0 )
		end
		
		return leftToSet
	end;
	
	-- Возвращает таблицу со всеми вещами в контейнере, где индексы - это номера слотов
	-- > self Container
	-- = table containerItemStacks
	getItems = function( self )
		return self.items
	end;
	
	-- Возвращает стак вещей из указанного слота или nil, если слот пустой
	-- > self Container
	-- > slotID number - номер слота
	-- = ItemStack / nil itemInSlot
	getItem = function( self, slotID )
		if not validVar( slotID, "slotID", "number" ) then return nil end
		
		if ( not self:slotExists( slotID ) ) then 
			Debug.error( "Slot " .. slotID .. " not exists" )
			return nil 
		end
		
		return self.items[ slotID ]
	end;
	
	-- Устанавливает вещь в указанный слот. Возвращает itemStack с количеством вещей, которое не удалось поместить в слот или nil, если неправильно указаны аргументы
	-- При правильном использовании всегда возвращает ItemStack. Если все вещи помещены, ItemStack:getCount() вернет 0
	-- > self Container
	-- > slotID number - номер слота в контейнере. Если такого слота нет, вызовает ошибку
	-- > itemStack ItemStack - стак вещей, который нужно положить в слот
	-- = ItemStack leftToSet
	setItem = function( self, slotID, itemStack ) 
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validClass( itemStack, "itemStack", ItemStack ) then return nil end
		
		--Debug.info( "setItem to slot " .. slotID .. " x" .. itemStack:getCount() )
		
		if ( itemStack:isEmpty() ) then
			-- Попытка положить пустой стак - очищаем слот
			self:clearSlot( slotID )
			
			return itemStack
		end
		
		local leftToAdd = self:trySetItem( slotID, itemStack )
		if ( leftToAdd:getCount() == itemStack:getCount() ) then
			-- Ничего не добавлено
			--Debug.info( "Try set item returned the same value" )
			
			return itemStack
		else
			-- Что-то добавлено
			local oldItemStack = self:getItem( slotID )
			self.items[ slotID ] = itemStack:clone()
			self.items[ slotID ]:setCount( itemStack:getCount() - leftToAdd:getCount() )
			
			-- Вызываем обработчики события, добавленные ранее через addChangesListener
			if ( not Event.trigger( "Container.onSlotDataChanged", self, slotID, oldItemStack ) ) then
				-- Событие отменили, возвращаем вещь назад
				local revertedItemStack = self.items[ slotID ]
				self.items[ slotID ] = oldItemStack
				Event.trigger( "Container.onSlotDataChanged", self, slotID, revertedItemStack )
				
				return itemStack
			end
			
			return leftToAdd
		end
	end;
	
	-- Установить все вещи внутри контейнера, при этом старые вещи полностью затираются
	-- Вещи, которые не поместились в контейнер, будут возвращены в виде такой же таблицы ( number slotID => ItemStack item )
	-- Если помещены все вещи, вернет пустую таблицу (можно использовать tableIsEmpty())
	-- > self Container
	-- > itemStacks table - таблица вида number slotID => ItemStack item
	-- = table itemsLeft
	setItems = function( self, itemStacks )
		if not validVar( itemStacks, "itemStacks", "table" ) then return nil end
		
		-- Очистка старых вещей
		self.items = {}
		
		-- Установка новых
		local itemsLeft = {}
		for slotID, itemStack in pairs( itemStacks ) do
			slotID = tonumber( slotID )
			
			local leftToSet = self:setItem( slotID, itemStack )
			if ( not leftToSet:isEmpty() ) then
				itemsLeft[ slotID ] = leftToSet
			end
		end
		
		return itemsLeft
	end;
	
	-- Очищает указанный слот
	-- > self Container
	-- > slotID number - номер слота, который нужно очистить
	-- = void
	clearSlot = function( self, slotID )
		if not validVar( slotID, "slotID", "number" ) then return nil end
		
		local oldItemStack = self:getItem( slotID )
		
		if ( oldItemStack ~= nil ) then
			-- Вещь в слоту была
			self.items[ slotID ] = nil
			
			-- Вызываем обработчики события, добавленные ранее через addChangesListener
			Event.trigger( "Container.onSlotDataChanged", self, slotID, oldItemStack )
		end
	end;
	
	-- Делает попытку прибавить вещи в слот вплоть до максимального размера стака в слоту и возвращает стак с вещами, которые не влезли. Не разбрасывает вещи по другим слотам
	-- Если вещь в слоту не такая, как в itemStack, добавлено ничего не будет
	-- Работает точно так же, как addItemToSlot, но не изменяет ничего
	-- > self Container
	-- > slotID number - номер слота
	-- > itemStack ItemStack - стак вещей, который добавляется к slotID
	-- = ItemStack leftToAdd
	tryAddItemToSlot = function( self, slotID, itemStack )
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validClass( itemStack, "itemStack", ItemStack ) then return nil end
		
		if ( not self:isItemAllowedInSlot( slotID, itemStack ) ) then
			-- Вещь устанавливать запрещено правилами, однозначно ничего не поместится
			return itemStack
		else
			-- Правилами не запрещено размещать вещь здесь, проверяем, что уже есть в слоту
			local itemStackInSlot = self:getItem( slotID )
			if ( itemStackInSlot == nil ) then
				-- Пустой слот - в слоту ничего нет
				local maxStackSize = self:getSlotMaxStackSize( slotID, itemStack )
				
				local addResultCount = 0	-- Кол-во вещей, которое в итоге будет в слоту
				
				if ( itemStack:getCount() > maxStackSize ) then
					-- Вставляется больше вещей, чем есть свободного места
					addResultCount = maxStackSize
				else
					-- Все вещи влезут в свободное место
					addResultCount = itemStack:getCount()
				end
				
				-- Возвращаем то, что осталось
				local leftToAdd = itemStack:clone()
				leftToAdd:setCount( itemStack:getCount() - addResultCount )
				
				return leftToAdd
			else
				-- В слоту есть какая-то вещь, проверяем, отличается она от вставляемой или нет
				if ( itemStackInSlot:getItem():isEqual( itemStack:getItem() ) ) then
					-- Вещь такая же, проверяем, есть ли свободное место
					local maxStackSize = self:getSlotMaxStackSize( slotID, itemStack )
					if ( itemStackInSlot:getCount() >= maxStackSize ) then
						-- Свободного места уже нет
						return itemStack
					else
						-- Свободное место еще есть, устанавливаем
						local freeSpaceLeft = maxStackSize - itemStackInSlot:getCount()
						local addedCount = 0
						
						if ( itemStack:getCount() > freeSpaceLeft ) then
							-- Вставляется больше вещей, чем есть свободного места
							addedCount = freeSpaceLeft
						else
							-- Все вещи влезут в свободное место
							addedCount = itemStack:getCount()
						end
						
						-- Возвращаем то, что осталось
						local leftToAdd = itemStack:clone()
						leftToAdd:setCount( itemStack:getCount() - addedCount )
						
						return leftToAdd
					end
				else
					-- Вещи отличаются - вставить невозможно
					return itemStack
				end
			end	
		end
	end;
	
	-- Прибавляет вещи в слот вплоть до максимального размера стака в слоту и возвращает стак с вещами, которые не влезли. Не разбрасывает вещи по другим слотам
	-- Если вещь в слоту не такая, как в itemStack, добавлено ничего не будет
	-- > self Container
	-- > slotID number - номер слота
	-- > itemStack ItemStack - стак вещей, который добавляется к slotID
	-- = ItemStack leftToAdd
	addItemToSlot = function( self, slotID, itemStack )
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validClass( itemStack, "itemStack", ItemStack ) then return nil end
		
		if ( not self:isItemAllowedInSlot( slotID, itemStack ) ) then
			-- Вещь устанавливать запрещено правилами, однозначно ничего не поместится
			return itemStack
		else
			-- Правилами не запрещено размещать вещь здесь, проверяем, что уже есть в слоту
			local itemStackInSlot = self:getItem( slotID )
			if ( itemStackInSlot == nil ) then
				-- Пустой слот - в слоту ничего нет
				local maxStackSize = self:getSlotMaxStackSize( slotID, itemStack )
				
				local addResultCount = 0	-- Кол-во вещей, которое в итоге будет в слоту
				
				if ( itemStack:getCount() > maxStackSize ) then
					-- Вставляется больше вещей, чем есть свободного места
					addResultCount = maxStackSize
				else
					-- Все вещи влезут в свободное место
					addResultCount = itemStack:getCount()
				end
				
				-- Устанавливаем вещь в слоту
				local newItemStack = itemStack:clone()
				newItemStack:setCount( addResultCount )
				
				self:setItem( slotID, newItemStack )	-- Всегда выполняется, так как мы проверили getSlotMaxStackSize и isItemAllowedInSlot
				
				-- Возвращаем то, что осталось
				local leftToAdd = itemStack:clone()
				leftToAdd:setCount( itemStack:getCount() - addResultCount )
				
				return leftToAdd
			else
				-- В слоту есть какая-то вещь, проверяем, отличается она от вставляемой или нет
				if ( itemStackInSlot:getItem():isEqual( itemStack:getItem() ) ) then
					-- Вещь такая же, проверяем, есть ли свободное место
					local maxStackSize = self:getSlotMaxStackSize( slotID, itemStack )
					if ( itemStackInSlot:getCount() >= maxStackSize ) then
						-- Свободного места уже нет
						return itemStack
					else
						-- Свободное место еще есть, устанавливаем
						local freeSpaceLeft = maxStackSize - itemStackInSlot:getCount()
						local addedCount = 0
						
						if ( itemStack:getCount() > freeSpaceLeft ) then
							-- Вставляется больше вещей, чем есть свободного места
							addedCount = freeSpaceLeft
						else
							-- Все вещи влезут в свободное место
							addedCount = itemStack:getCount()
						end
						
						-- Устанавливаем вещь в слоту
						local newItemStack = itemStackInSlot:clone()
						newItemStack:setCount( itemStackInSlot:getCount() + addedCount )
						self:setItem( slotID, newItemStack )
				
						-- Возвращаем то, что осталось
						local leftToAdd = itemStack:clone()
						leftToAdd:setCount( itemStack:getCount() - addedCount )
						
						return leftToAdd
					end
				else
					-- Вещи отличаются - вставить невозможно
					return itemStack
				end
			end	
		end
	end;
	
	-- Добавляет вещь в контейнер. Сначала вещь будет добавлена к существующим стакам такой же вещи, затем в пустые слоты
	-- Возвращает такой же стак, если ни одна вещь не была помещена в контейнер или nil, если произошла ошибка
	-- > self Container
	-- > itemStack ItemStack - стак вещей, который нужно добавить в инвентарь
	-- = ItemStack leftToAdd
	addItem = function( self, itemStack )
		if not validClass( itemStack, "itemStack", ItemStack ) then return nil end
		
		-- Ищем существующий стак с такой вещью
		for slotID, itemStackInSlot in pairs( self:getItems() ) do
			if ( itemStackInSlot:getItem():isEqual( itemStack:getItem() ) ) then
				-- Вещь в слоту такая же, пробуем вставить
				--Debug.info( "Item is the same as in slot " .. slotID )
				
				itemStack = self:addItemToSlot( slotID, itemStack )
				
				if ( itemStack:isEmpty() ) then
					-- Добавили все вещи
					return itemStack
				end
			end
		end
		
		--Debug.info( "There are no same items in slots" )
		
		-- Добавляем в свободные слоты
		for slotID = 1, self.slotsCount do
			if ( self.items[ slotID ] == nil ) then	-- self:isSlotEmpty
				-- Нашли пустой слот, добавляем в него вещь
				itemStack = self:addItemToSlot( slotID, itemStack )
				
				if ( itemStack:isEmpty() ) then
					-- Добавили все вещи
					return itemStack
				end
			end
		end
		
		-- Если что и не добавили, возвращаем
		return itemStack
	end;
	
	-- Убрать вещь из слота контейнера
	-- Возвращает стак вещей, который не удалось убрать из слота
	-- > self Container
	-- > slotID number - номер слота, из которого нужно убрать вещь
	-- > itemStack ItemStack - стак вещей, который нужно убрать (используется скорее для валидации). Количество вещей в стаке указывает количество вещей, которое нужно убрать
	-- = ItemStack leftToRemove
	removeItemFromSlot = function( self, slotID, itemStack )
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validClass( itemStack, "itemStack", ItemStack ) then return nil end
		
		local slotStack = self:getItem( slotID )
		
		if ( slotStack == nil ) then
			-- В слоту нет вещей, ничего не убрано
			return itemStack
		else
			-- В слоту есть вещи
			if ( slotStack:getItem():isEqual( itemStack:getItem() )  ) then
				-- Вещи одинаковые
				local itemsToRemove = itemStack:getCount()
				if ( slotStack:getCount() < itemsToRemove ) then
					itemsToRemove = slotStack:getCount()
				end
				
				local newStack = slotStack:clone()
				newStack:setCount( slotStack:getCount() - itemsToRemove )
				
				self:setItem( slotID, newStack )
				
				local leftToRemove = itemStack:clone()
				leftToRemove:setCount( slotStack:getCount() - newStack:getCount() )
				
				return leftToRemove
			else
				-- Вещи разные, ничего не убрано
				return itemStack
			end
		end
	end;
	
	-- Преобразует все данные контейнера в строку, которую можно передать по сети или сохранить
	-- Container.unserialize превращает строку обратно в объект
	-- > self Container
	-- = string serializedString
	serialize = function( self )

		local items = {}
		
		for slotID, itemStack in pairs( self:getItems() ) do
			items[ slotID ] = itemStack:serialize()
		end
		
		local slotRuleString = nil
		if ( not tableIsEmpty( self.slotRuleString ) ) then
			slotRuleString = self.slotRuleString
		end	
		
		local slotMaxStackSize = nil
		if ( not tableIsEmpty( self.slotMaxStackSize ) ) then
			slotMaxStackSize = self.slotMaxStackSize
		end	
		
		return jsonEncode( {
			slotsCount = self.slotsCount;
			ruleString = self.ruleString;
			slotRuleString = slotRuleString;
			maxStackSize = self.maxStackSize;
			slotMaxStackSize = slotMaxStackSize;
			
			items = items;
		} )
	end;
};
Container.__index = Container
setmetatable( Container, {
	__call = function ( cls, ... )
		return cls.create( ... )
	end;
	
	__tostring = function()
		return "Container"
	end;
} )