-- TODO переделать moveItems, возвращать вместо ошибки количество вещей, которые не перемещены
--------------------------------------------------------------------------------
--<[ Модуль ItemStack ]>--------------------------------------------------------
--------------------------------------------------------------------------------
ItemStack = {
	
	MAX_SIZE = 64;	-- Максимально возможный размер стака

	-- Конструктор ItemStack(), возвращает объект стака вещей или nil, если неправильно заданы аргументы
	-- > item Item - объект предмета
	-- > count number - количество предметов в стаке
	-- = ItemStack / nil itemStack
	create = function( item, count )
		if not validClass( item, "item", Item ) then return nil end
		if not validVar( count, "count", "number" ) then return nil end
		
		local t = setmetatable( {}, ItemStack )
		
		t.item = item
		t.count = count
	
		return t
	end;
	
	-- Создает и возвращает объект ItemStack из json-строки (созданной с помощью itemStack:serialize()) или nil, если не получилось создать объект
	-- > serializedString string - json-строка, созданная при помощи itemStack:serialize()
	-- = ItemStack / nil itemStack
	unserialize = function( serializedString )
		if not validVar( serializedString, "serializedString", "string" ) then return nil end
	
		local t = jsonDecode( serializedString )
		
		return ItemStack( Item.unserialize( t.item ), t.count )
	end;
	
	----------------------------------------------------------------------------
	--<[ Объект ]>--------------------------------------------------------------
	----------------------------------------------------------------------------
	item = nil;
	count = nil;
	
	-- Создать копию стака
	-- > self ItemStack
	-- = ItemStack clonedItemStack
	clone = function( self )
		return ItemStack( self:getItem(), self:getCount() )
	end;
	
	-- Возвращает true, если в стаке нет вещей (getCount() == 0)
	-- > self ItemStack
	-- = bool stackIsEmty
	isEmpty = function( self )
		return self:getCount() == 0
	end;
	
	-- Получить объект вещи из стака
	-- > self ItemStack
	-- = Item itemInStack
	getItem = function( self )
		return self.item
	end;
	
	-- Получить количество вещей в стаке
	-- > self ItemStack
	-- = number itemCountInStack
	getCount = function( self )
		return self.count
	end;
	
	-- Установить количество вещей в стаке
	-- Разрешено устанавливать кол-во больше размера стака (например, для использования вне контейнеров: создать стак из 20 вещей (когда макс. размер 8) и добавить в контейнер - стак разобъется на 8, 8 и 4)
	-- Разрешено также устанавливать 0 вещей (для целостности), но стоит удалять такие стаки из контейнеров
	-- > self ItemStack
	-- > count number
	-- = bool isSuccess, string / nil errorMessage
	setCount = function( self, count )
		if not validVar( count, "count", "number" ) then return nil end
	
		if ( count >= 0 ) then
			self.count = count
			
			return self
		else
			Debug.error( "Setting " .. count .. " items to stack" )
			
			return nil
		end
	end;
	
	-- Получить количество свободного места в стаке, исходя из item:getStackSize
	-- > self ItemStack
	-- = number freeSpaceLeft
	getFreeSpace = function( self )
		return self.item:getStackSize() - self.count
	end;
	
	-- Получить максимальный размер стака, исходя из item:getStackSize
	-- > self ItemStack
	-- = number stackSize
	getStackSize = function( self )
		return self.item:getStackSize()
	end;
	
	-- Получить суммарный вес вещей в стаке
	-- > self ItemStack
	-- = number stackWeight
	getWeight = function( self )
		return self.count * self.item:getWeight()
	end;
	
	-- Добавить в стак вещи. Возвращает true, если вещи добавлены, в противном случае false и текст ошибки
	-- > self ItemStack
	-- > item Item - вещь, которую нужно добавить (только для валидации)
	-- > count number - количество вещей, которое нужно добавить (>=1)
	-- = bool isSuccess, string / nil errorMessage
	addItems = function( self, item, count )
		if not validClass( item, "item", Item ) then return false, "Wrong argument" end
		if not validVar( count, "count", "number" ) then return false, "Wrong argument" end
		
		if ( count < 1 ) then
			return false, "Count must be >= 1"
		elseif ( self:getFreeSpace() < count ) then
			return false, "Not enough space"
		elseif ( not self.item:isEqual( item ) ) then
			return false, "Different item passed"
		else
			self.count = self.count + count
			return true
		end
	end;
	
	-- Убрать вещи из стака. Возвращает true, если вещи убраны, в противном случае false и текст ошибки
	-- > self ItemStack
	-- > count number - количество вещей, которое нужно убрать (>=1)
	-- = bool isSuccess, string / nil errorMessage
	removeItems = function( self, count )
		if not validVar( count, "count", "number" ) then return false, "Wrong argument" end
		
		if ( count < 1 ) then
			return false, "Count must be >= 1"
		elseif ( self.count < count ) then
			return false, "Not enough items"
		else
			self.count = self.count - count
			
			return true
		end
	end;
	
	-- Переместить вещи в другой стак. Возвращает true, если вещи перемещены, в противном случае false и текст ошибки
	-- > self ItemStack
	-- > targetItemStack ItemStack - целевой объект ItemStack, куда нужно переместить вещи
	-- > count number - количество вещей, которое нужно переместить (>=1)
	-- = bool isSuccess, string / nil errorMessage
	moveItems = function( self, targetItemStack, count )
		if not validClass( targetItemStack, "targetItemStack", ItemStack ) then return false, "Wrong argument" end
		if not validVar( count, "count", "number" ) then return false, "Wrong argument" end
		
		if ( count < 1 ) then
			return false, "Count must be >= 1"
		elseif ( self.count < count ) then
			return false, "Not enough items"
		elseif ( not targetItemStack:getItem():isEqual( self.item ) ) then
			return false, "Different items"
		elseif ( targetItemStack:getFreeSpace() < count ) then
			return false, "Not enough space"
		else
			self:removeItems( count )
			targetItemStack:addItems( self.item, count )
			
			return true
		end
	end;
	
	-- Возвращает json-строку, пригодную для передачи по сети и сохранения в базу / файл. Может быть обратно превращена в объект через ItemStack.unserialize()
	-- > self ItemStack
	-- = string serializedString
	serialize = function( self )
		return jsonEncode( {
			item = self.item:serialize(),
			count = self.count
		} )
	end;
};
ItemStack.__index = ItemStack
setmetatable( ItemStack, {
	__call = function ( cls, ... )
		return cls.create( ... )
	end;
	
	__tostring = function()
		return "ItemStack"
	end;
} )