--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Dimension.onServerRegistryResponse", true )							-- Начальная загрузка регистра ( table newRegistry, table newNameRegistry )
addEvent( "Dimension.onServerUpdateRegistry", true )							-- Обновление во время выполнения ( table newRegistry, table newNameRegistry )

--------------------------------------------------------------------------------
--<[ Модуль Dimension ]>--------------------------------------------------------
--------------------------------------------------------------------------------
Dimension = {
	registry = {};
	nameRegistry = {};
	
	init = function()
		addEventHandler( "Dimension.onServerUpdateRegistry", resourceRoot, Dimension.onServerUpdateRegistry )
		
		-- Загружаем список измерений из сервера
		addEventHandler( "Dimension.onServerRegistryResponse", resourceRoot, function( newRegistry, newNameRegistry )
			Dimension.onServerUpdateRegistry( newRegistry, newNameRegistry )
			Main.setModuleLoaded( "Dimension", 1 )
		end )
		triggerServerEvent( "Dimension.onClientRequestRegistry", resourceRoot )
	end;
	
	-- Получить ID измерения из MTA (например, для setElementDimension)
	-- > dimensionName string - название измерения
	-- > dimensionID number / nil - номер измерения (в соответствии с названием). Опционально (для измерений типа Global, без ID)
	-- = number dimensionIngameID
	get = function( dimensionName, dimensionID )
		if ( Dimension.nameRegistry[ dimensionName ] == nil ) then
			return nil
		else
			if ( dimensionID == nil or type( Dimension.nameRegistry[ dimensionName ] ) == "number" ) then
				return Dimension.nameRegistry[ dimensionName ]
			else
				return Dimension.nameRegistry[ dimensionName ][ dimensionID ]
			end
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Регистр измерений обновился
	-- TODO не обязательно передавать весь массив регистра, лостаточно передать только изменения
	onServerUpdateRegistry = function( newRegistry, newNameRegistry )
		Dimension.registry = newRegistry
		Dimension.nameRegistry = newNameRegistry
		--Debug.info( "Регистр измерений обновлен" )
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, Dimension.init )