--------------------------------------------------------------------------------
--<[ Модуль Item ]>-------------------------------------------------------------
--------------------------------------------------------------------------------
Item = {
	-- Конструктор Item()
	-- Возвращает nil, если такой класс не найден
	-- > class string - класс предмета (ключ из таблицы ItemClass)
	-- > params table/nil - параметры вещи
	-- = Item / nil itemObject
	create = function( class, params )
		if not validVar( class, "class", "string" ) then return nil end
		if not validVar( params, "params", { "nil", "table" } ) then return nil end
		
		if ( params == nil ) then
			params = {}
		end
		
		local t = setmetatable( {}, Item )
		
		if ( ItemClass[ class ] == nil ) then
			Debug.error( "No class named '" .. class .. "' found" )
			
			return nil
		else
			t.className = class
			t.class = ItemClass[ class ]
			t.params = params
		
			return t
		end
	end;
	
	-- Возвращает объект вещи из строки, ранее полученой из item:serialize()
	-- > serializedString string - строка, полученная через item:serialize
	-- = Item / nil item
	unserialize = function( serializedString )
		local t = jsonDecode( serializedString )
		
		return Item( t.class, t.params )
	end;
	
	----------------------------------------------------------------------------
	--<[ Объект ]>--------------------------------------------------------------
	----------------------------------------------------------------------------
	
	className = nil;
	class = nil;
	params = {};
	
	-- Скопировать вещь (создать новый экземпляр). Например, если вещь раскладывается в разные слоты
	-- > self Item
	-- = Item clonedItem
	clone = function( self )
		return Item( self.className, self.params )
	end;
	
	-- Возвращает объект класса вещи (ItemClass.*)
	-- > self Item
	-- = ItemClass itemClass
	getClass = function( self )
		return self.class
	end;
	
	-- Возвращает название класса вещи (ключ из ItemClass)
	-- > self Item
	-- = string className
	getClassName = function( self )
		return self.className
	end;
	
	-- Возвращает true, если вещи имеют одинаковый класс и параметры
	-- > self Item
	-- > toItem Item - вещь, с которой нужно сравнить
	-- = bool isEqual
	isEqual = function( self, toItem )
		if not validClass( toItem, "toItem", Item ) then return false end
		
		if ( self.className ~= toItem.className ) then 
			-- Разные классы
			return false 
		end
		
		return equals( self.params, toItem.params )
	end;
	
	-- Возвращает параметр (класс -> вещь) или nil, если такого параметра у вещи нет
	-- > self Item
	-- > name string - название параметра
	-- = mixed / nil paramValue
	getParam = function( self, name )
		if ( self.params[ name ] == nil ) then
			if ( self.class.params == nil ) then
				-- У класса нет параметров
				return nil
			elseif ( type( self.class.params ) == "table" ) then
				-- В классе указана таблица
				if ( type( self.class.params[ name ] ) == "function" ) then
					-- Параметр - функция
					return self.class.params[ name ]( self )
				else
					-- Параметр - не функция, возвращаем напрямую
					return self.class.params[ name ]
				end
			else
				-- class.params может быть только nil или таблицей (функция может быть установлена только для отдельного параметра)
				Debug.error( "ItemClass." .. self.className .. ".params must be nil or function, " .. type( self.class.params ) .. " given" )
				return nil
			end
		else
			return self.params[ name ]
		end
	end;
	
	-- Установить параметр вещи
	-- > self Item
	-- > name string - название параметра
	-- > value mixed / nil - значение параметра
	-- = void
	setParam = function( self, name, value )
		self.params[ name ] = value
	end;
	
	-- Получить описание вещи (не HTML)
	-- > self Item
	-- = string description
	getDescr = function( self )
		if ( type( self.class.descr ) == "function" ) then
			return self.class.descr( self )
		else
			return self.class.descr
		end
	end;
	
	-- Получить описание вещи в HTML
	-- > self Item
	-- = string descriptionHTML
	getDescrHTML = function( self )
		if ( self.class.descrHTML == nil ) then
			return self:getDescr()
		elseif ( type( self.class.descrHTML ) == "function" ) then
			return self.class.descr( self )
		else
			return self.class.descr
		end
	end;
	
	-- Получить название файла значка вещи (из client/data/item/icon/). Если у вещи не указан значок (в itemClass), возвращается название класса
	-- > self Item
	-- = string iconName
	getIcon = function( self )
		if ( self.class.icon == nil ) then
			return self.className
		elseif ( type( self.class.icon ) == "function" ) then
			return self.class.icon( self )
		else
			return self.class.icon
		end
	end;
	
	-- Возвращает ID модели вещи
	-- > self Item
	-- = number modelID
	getModel = function( self )
		if ( type( self.class.model ) == "function" ) then
			return self.class.model( self )
		else
			return self.class.model
		end
	end;
	
	-- Возвращает название вещи
	-- > self Item
	-- = string itemName
	getName = function( self )
		if ( type( self.class.name ) == "function" ) then
			return self.class.name( self )
		else
			return self.class.name
		end
	end;
	
	-- Возвращает качество вещи (от 0 до 1) или nil, если вещь не имеет качества
	-- > self Item
	-- = number / nil itemQuality
	getQuality = function( self )
		if ( self.class.quality == nil ) then
			return nil
		elseif ( type( self.class.quality ) == "function" ) then
			return self.class.quality( self )
		else
			return self.class.quality
		end
	end;
	
	-- Возвращает максимальное количество таких вещей в одном стаке
	-- > self Item
	-- = number stackSize
	getStackSize = function( self )
		if ( self.class.stack == nil ) then
			return 1
		elseif ( type( self.class.stack ) == "function" ) then
			return self.class.stack( self )
		else
			return self.class.stack
		end
	end;
	
	-- Возвращает таблицу тегов вещи, где названия тегов явзяются ключами: { tool = 1; food = 1;... }
	-- > self Item
	-- = table itemTags
	getTags = function( self )
		if ( self.class.tags == nil ) then
			return {}
		elseif ( type( self.class.tags ) == "function" ) then
			return self.class.tags( self )
		else
			return self.class.tags
		end
	end;
	
	-- Возвращает true, если вещь имеет указанный тег
	-- > self Item
	-- > tag string
	-- = bool hasTag
	hasTag = function( self, tag )
		if ( self.class.tags == nil ) then
			return false
		elseif ( type( self.class.tags ) == "function" ) then
			return self.class.tags( self )[ tag ] ~= nil
		else
			return self.class.tags[ tag ] ~= nil
		end
	end;
	
	-- Возвращает текстуру, которая будет применена на дроп вещи, или nil
	-- > self Item
	-- = texture / nil dropTexture
	getTexture = function( self )
		-- TODO это клиентская функция
		-- Стоит перенести ItemClass в отдельный модуль (см. includes/item-classes.lua)
		if ( self.class.texture == nil ) then
			return nil
		elseif ( type( self.class.texture ) == "function" ) then
			return self.class.texture( self )
		else
			return self.class.texture
		end
	end;
	
	-- Возвращает таблицу с данными, которые будут отображены в информации слота GUI
	-- { ["Урон"] => { "string", "10.7 hp" }, ["Прочность"] => { "progress", 64, 256 } }
	-- Доступные типы статистики: string, progress
	-- > self Item
	-- = table / nil guiStatsTable
	getGuiStats = function( self )
		if ( self.class.guiStats == nil ) then
			return nil
		elseif ( type( self.class.guiStats ) == "function" ) then
			return self.class.guiStats( self )
		else
			return self.class.guiStats
		end
	end;
	
	-- Возвращает вес единицы вещи
	-- > self Item
	-- = number itemWeight
	getWeight = function( self )
		if ( type( self.class.weight ) == "function" ) then
			return self.class.weight( self )
		else
			return self.class.weight
		end
	end;
	
	-- Превращает объект в строку, пригодную для отправки по сети и сохранения в базу или файл. Item.unserialize восстанавливает объект из строки
	-- > self Item
	-- = string serializedString
	serialize = function( self )
		return jsonEncode( {
			class = self.className;
			params = self.params;
		} )
	end;
};
Item.__index = Item
setmetatable( Item, {
	__call = function ( cls, ... )
		return cls.create( ... )
	end;
	
	__tostring = function()
		return "Item"
	end;
} )