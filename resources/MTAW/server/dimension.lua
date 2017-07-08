--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Dimension.onClientRequestRegistry", true )							-- Клиент запросил регистр измерений ()

--------------------------------------------------------------------------------
--<[ Модуль Dimension ]>--------------------------------------------------------
--------------------------------------------------------------------------------
Dimension = {
	registry = {};
	nameRegistry = {};
	
	topIndex = 1;
	
	init = function()
		Main.setModuleLoaded( "Dimension", 1 )
		
		addEventHandler( "Dimension.onClientRequestRegistry", resourceRoot, Dimension.onClientRequestRegistry )
	end;
	
	-- Зарегистрировать измерение
	-- > dimensionName string - название измерения (например, "Global", "Lobby")
	-- > dimensionID mixed / nil - идентификатор измерения в рамках dimensionName, опционально (если не указан, регистрируется только по имени)
	-- = number ingameDimensionID
	register = function( dimensionName, dimensionID )
		local id = Dimension.topIndex
		
		if ( Dimension.nameRegistry[ dimensionName ] == nil ) then
			if ( dimensionID == nil ) then
				Dimension.nameRegistry[ dimensionName ] = id
			else
				Dimension.nameRegistry[ dimensionName ] = {}
				Dimension.nameRegistry[ dimensionName ][ dimensionID ] = id
			end
		else
			if ( dimensionID == nil ) then
				Debug.error( "Dimension " .. dimensionName .. " is already registered" )
					
				return nil
			else
				if ( Dimension.nameRegistry[ dimensionName ][ dimensionID ] == nil ) then
					Dimension.nameRegistry[ dimensionName ][ dimensionID ] = id
				else
					Debug.error( "Dimension " .. dimensionName .. ":" .. dimensionID .. " is already registered" )
					
					return nil
				end
			end
		end
		
		Dimension.registry[ id ] = { name = dimensionName; id = dimensionID; }
		
		Dimension.topIndex = Dimension.topIndex + 1
		
		Debug.info( "Registered dimension " .. id .. " for " .. dimensionName .. ":" .. tostring( dimensionID ) )
		
		-- Обновляем на клиентах
		for _, playerElement in pairs( Main.getLoadedPlayers() ) do
			triggerClientEvent( playerElement, "Dimension.onServerUpdateRegistry", resourceRoot, Dimension.registry, Dimension.nameRegistry )
		end
		
		return id
	end;
	
	-- Получить ID измерения или nil, если оно не существует
	-- > dimensionName string - название измерения
	-- > dimensionID mixed / nil - идентификатор измерения в рамках dimensionName (опционально, если измерение было зарегистрировано без идентификатора)
	-- = number / nil ingameDImensionID
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
	
	-- Клиент запросил регирстр измерений
	onClientRequestRegistry = function()
		triggerClientEvent( client, "Dimension.onServerRegistryResponse", resourceRoot, Dimension.registry, Dimension.nameRegistry )
	end;
};
addEventHandler( "onResourceStart", resourceRoot, Dimension.init )