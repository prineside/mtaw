--------------------------------------------------------------------------------
--<[ Модуль ItemContainer ]>----------------------------------------------------
--------------------------------------------------------------------------------
ItemContainer = {
	instances = {};	-- instances[ type ][ id ] = ItemContainer

	-- Конструктор ItemContainer(), возвращает объект контейнера вещей или nil, если неправильно заданы аргументы
	-- > containerType string - название контейнера
	-- > containerID string / number - идентификатор контейнера в рамках типа
	-- > maxSize number - макс. количество слотов контейнера
	-- > slotsConfig table / nil - конфигурация слотов (фильтры вещей, которые могут быть размещены и подобное, см. описание модуля ItemContainer)
	-- > itemStacks table / nil - таблица, состоящая из ItemStack, которой будет наполнен контейнер
	-- = ItemContainer / nil itemContainer
	create = function( containerType, containerID, maxSize, slotsConfig, itemStacks )
		if not validVar( containerType, "containerType", "string" ) then return nil, "Wrong argument" end
		if not validVar( containerID, "containerID", { "number", "string" } ) then return nil, "Wrong argument" end
		if not validVar( maxSize, "maxSize", "number" ) then return nil, "Wrong argument" end
		if not validVar( slotsConfig, "slotsConfig", { "table", "nil" } ) then return nil, "Wrong argument" end
		if not validVar( itemStacks, "itemStacks", { "table", "nil" } ) then return nil, "Wrong argument" end
		
		if ( ItemContainer.getInstance( containerType, containerID ) ~= nil ) then
			-- Такой контейнер уже загружен
			return nil, "Container " .. containerType .. " " .. containerID .. " already exists"
		end
		
		if ( maxSize < 1 ) then
			-- Неправильный размер контейнера
			return nil, "Container size must be >=1"
		end
		
		if ( slotsConfig == nil ) then
			slotsConfig = {}
		else
			-- Валидация slotsConfig
			for slotID, slotCfg in pairs( slotsConfig ) do
				if ( slotID > maxSize ) then
					-- ID слота превышает размер контейнера
					return nil, "Wrong slotsConfig - slot " .. slotID .. " is above maxSize " .. slotID
				else
					-- TODO
				end
			end
		end
		
		if ( itemStacks == nil ) then
			itemStacks = {}
		else
			-- Валидация itemStacks
			for slotID, slotItemStack in pairs( itemStacks ) do
				if ( slotID > maxSize ) then
					-- ID слота превышает размер контейнера
					return nil, "Wrong itemStacks - slot " .. slotID .. " is above maxSize " .. slotID
				else
					-- ID слота в допустимых пределах
					if ( not validClass( slotItemStack, "slotItemStack", ItemStack, true ) ) then
						return nil, "Wrong itemStacks - item at slot " .. slotID .. " is not ItemStack"
					end
				end
			end
		end
		
		local t = setmetatable( {}, ItemContainer )
		
		t.type = containerType
		t.id = containerID
		t.maxSize = maxSize
		t.slotsConfig = slotsConfig
		t.itemStacks = itemStacks
		
		if ( ItemContainer.instances[ containerType ] == nil ) then
			ItemContainer.instances[ containerType ] = {}
		end
		
		ItemContainer.instances[ containerType ][ containerID ] = t
		
		return t
	end;
	
	-- Возвращает существуюзий экземпляр объекта или nil, если он еще не создан
	-- > containerType string - тип контейнера
	-- > containerID string / number - идентификатор контейнера в рамках типа
	-- = ItemContainer / nil itemContainer
	getInstance = function( containerType, containerID )
		if not validVar( containerType, "containerType", "string" ) then return nil end
		if not validVar( containerID, "containerID", { "number", "string" } ) then return nil end
		
		if ( ItemContainer.instances[ containerType ] == nil ) then
			return nil
		else
			return ItemContainer.instances[ containerType ][ containerID ]
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Объект ]>--------------------------------------------------------------
	----------------------------------------------------------------------------
	
	type = nil;
	id = nil;
	maxSize = nil;
	slotsConfig = {};
	itemStacks = {};
	
	-- Положить вещь в слот. Возвращает таблицу с данными вида { success = bool, count = number (кол-во положенных вещей), reason = string }
	-- > slotType string - тип контейнера (inventory/fast...)
	-- > slotID number - номер слота контейнера
	-- > item Item - вещь, которую нужно положить
	-- > count number - количество вещей, которое нужно положить
	-- = table putStatus
	putItems = function( slotType, slotID, item, count )
		-- TODO - фильтры слотов. Если не подходит:
		-- return { success : false, reason : "Фильтр" };
		--Debug.info( item )
		
		local currentItemStack = Inventory.getItems( slotType, slotID )
		
		if ( currentItemStack == nil ) then
			-- Если слот пустой, ложим количество не больше стака
			local itemStackSize = item:getStackSize()
			if ( itemStackSize < count ) then
				count = itemStackSize
			end
			
			local newItemStack = ItemStack( item, count )
			
			Inventory.setItem( slotType, slotID, newItemStack )
			
			return {
				success = true;
				count = count;
			}
		else
			-- Слот не пустой - проверяем, одинаковые ли предметы item и currentItemStack
			if ( item:isEqual( currentItemStack:getItem() ) ) then
				-- Объекты вещей, без учета количества, одинаковые
				if ( currentItemStack:getFreeSpace() == 0 ) then
					-- Этот слот забит (макс. кол-во вещей по стаку), отмена
					return { 
						success = false; 
						reason = "Полный стак: " .. currentItemStack:getStackSize();
					}
				else
					-- В стаке есть место
					if ( currentItemStack:getCount() + count > currentItemStack:getStackSize() ) then
						-- Все вещи не влезут в стак, пихаем то, что влезет
						count = currentItemStack:getFreeSpace()
					end
					
					local setSuccess, setError = currentItemStack:setCount( currentItemStack:getCount() + count )
					
					if ( setSuccess ) then
						-- Вещи установились в стак
						return { 
							success = true;
							count = count;
						}
					else
						-- Ошибка установки вещей
						return { 
							success = false;
							reason = setError;
						}
					end
				end
			else
				-- Объекты вещей разные
				return { 
					success = false;
					reason = "Разные вещи";
				}
			end
		end
	end;
	
	-- Убрать вещь из слота. Если count не указан, убираются все вещи
	removeItem = function( slotType, slotID, count )
		if not validVar( slotType, "slotType", "string" ) then return nil end
		if not validVar( slotID, "slotID", "number" ) then return nil end
		if not validVar( count, "count", { "number", "nil" } ) then return nil end
	
		if ( count == nil ) then
			Inventory.setItem( slotType, slotID, nil )
		else
			local slotData = Inventory.getItem( slotType, slotID )
			if ( slotData ) then
				slotData.count = slotData.count - count
				if ( slotData.count <= 0 ) then
					Inventory.setItem( slotType, slotID, nil )
				else
					Inventory.setItem( slotType, slotID, slotData )
				end
			end
		end
	end;
	
	-- Выгрузить экземпляр из памяти
	-- > self ItemContainer
	-- = void
	destroy = function( self )
		ItemContainer.instances[ self.type ][ self.id ] = nil
	end;
};
ItemContainer.__index = ItemContainer
setmetatable( ItemContainer, {
	__call = function ( cls, ... )
		return cls.create( ... )
	end;
	
	__tostring = function()
		return "ItemContainer"
	end;
} )