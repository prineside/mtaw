--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "TempAppleTree.onDisruptAppleStart", true )							-- Начал срывать яблоко ( element treeElement, number appleIndex )
addEvent( "TempAppleTree.onDisruptAppleStop", true )							-- Перестал срывать яблоко ( bool isSuccess, element treeElement, number appleIndex )

--------------------------------------------------------------------------------
--<[ Модуль TempAppleTree ]>----------------------------------------------------
--------------------------------------------------------------------------------
TempAppleTree = {
	appleGrowDelay = 5000;
	appleGrowChance = 0.1;
	maxApplesPerTree = 18;
	trees = {};
	
	lastAppleDisruptionTick = {};												-- playerElement => последний tick, когда сорвал яблоко (защита от читерства)
	
	init = function()
		addEventHandler( "Main.onServerLoad", resourceRoot, TempAppleTree.onServerLoad )
	end;
	
	onServerLoad = function()
		TempAppleTree.createTree( -51.75, -10.37, 2.12 )
		TempAppleTree.createTree( -47.1, -20.09, 2.12, 0, 0, 180 )
		TempAppleTree.createTree( -46.2, -12.84, 2.12, 0, 0, 240 )
		
		setTimer( TempAppleTree._appleGrowHandler, TempAppleTree.appleGrowDelay, 0 )
		
		addEventHandler( "TempAppleTree.onDisruptAppleStart", resourceRoot, TempAppleTree.onDisruptAppleStart )
		addEventHandler( "TempAppleTree.onDisruptAppleStop", resourceRoot, TempAppleTree.onDisruptAppleStop )
		
		if ( DEBUG_MODE ) then
			for i = 1,15 do TempAppleTree._appleGrowHandler() end
		end
	end;
	
	-- Создать яблоню
	-- > x number
	-- > y number
	-- > z number
	-- > rx number / nil
	-- > ry number / nil
	-- > rz number / nil
	-- = void
	createTree = function( x, y, z, rx, ry, rz )
		-- Создаем дерево с ID модели 892
		local treeElement = createObject( 892, x, y, z, rx, ry, rz )
		setElementData( treeElement, "_tat", "nnnnnnnnnnnnnnnnnn" )
		
		setElementDimension( treeElement, Dimension.get( "Global" ) )
		setElementDoubleSided( treeElement, true )
		
		TempAppleTree.trees[ treeElement ] = {
			apples = {},
			appleCount = 0
		}
	end;
	
	-- Обновить данные элемента дерева (синхронизация с клиентами)
	-- > treeElement object - элемент дерева
	-- = void
	updateTree = function( treeElement )
		if ( TempAppleTree.trees[ treeElement ] ~= nil ) then
			local chars = {}
			for i = 1, TempAppleTree.maxApplesPerTree do
				if ( TempAppleTree.trees[ treeElement ].apples[ i ] == nil ) then
					table.insert( chars, "n" )
				else
					table.insert( chars, "y" )
				end
			end
			
			setElementData( treeElement, "_tat", table.concat( chars ) )
		end
	end;
	
	-- Выполнить итерацию роста яблок
	_appleGrowHandler = function()
		for treeElement, treeData in pairs( TempAppleTree.trees ) do
			if ( treeData.appleCount ~= TempAppleTree.maxApplesPerTree and math.random() < TempAppleTree.appleGrowChance ) then
				-- Дерево не заполнено яблоками и выпал шанс
				local appleIndex = math.random( 1, TempAppleTree.maxApplesPerTree )
				if ( treeData.apples[ appleIndex ] == nil ) then
					-- Яблока еще нет, создаем
					treeData.apples[ appleIndex ] = true
					treeData.appleCount = treeData.appleCount + 1
					TempAppleTree.updateTree( treeElement )
				end
			end
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Игрок начал срывать яблоко
	onDisruptAppleStart = function( treeElement, appleIndex )
		-- Поворачиваем игрока к яблоку и устанавливаем анимацию
		local playerElement = client

		local px, py = getElementPosition( playerElement )
		
		local appleX, appleY, appleZ = getPositionFromElementOffset( treeElement, ARR.treeFruitOffsets.apple[ appleIndex ][ 1 ], ARR.treeFruitOffsets.apple[ appleIndex ][ 2 ], ARR.treeFruitOffsets.apple[ appleIndex ][ 3 ] )
		local angleToApple = getAngleBetweenPoints( px, py, appleX, appleY )
		
		setElementRotation( playerElement, 0, 0, angleToApple, "default", true )
		
		-- TODO установить как-то время срывания одного яблока (хард-код не подходит), предположительно после внедрения навыков фермера
		Animation.play( playerElement, "CASINO", "Slot_Plyr", 2000, nil, false, false )
	end;
	
	-- Игрок перестал срывать яблоко
	onDisruptAppleStop = function( isSuccess, treeElement, appleIndex )
		if not validVar( isSuccess, "isSuccess", "boolean" ) then return nil end
		if not validVar( treeElement, "treeElement", "element" ) then return nil end
		if not validVar( appleIndex, "appleIndex", "number" ) then return nil end
		
		if ( isSuccess ) then
			-- Проверяем, есть ли яблоко, которое он сорвал
			if ( TempAppleTree.trees[ treeElement ] == nil ) then
				-- Это не дерево?...
				Debug.info( "Can't disrupt an aple not from a tree" )
				return nil
			end
			if ( TempAppleTree.trees[ treeElement ].apples[ appleIndex ] == nil ) then
				-- Такого яблока нет
				Debug.info( "There's no apple with idx " .. appleIndex )
				return nil
			end
			
			-- Проверяем, не слишком ли часто он срывает яблоки
			if ( TempAppleTree.lastAppleDisruptionTick[ client ] ~= nil ) then
				-- Уже срывал яблоки
				if ( getTickCount() - TempAppleTree.lastAppleDisruptionTick[ client ] < 1500 ) then
					Debug.info( "Too small disruption interval: " .. ( getTickCount() - TempAppleTree.lastAppleDisruptionTick[ client ] ) )
					return nil
				end
			end
			TempAppleTree.lastAppleDisruptionTick[ client ] = getTickCount()
			
			-- Добавляем яблоко в инвентарь и срываем с дерева
			local leftToAdd = Inventory.addItem( client, ItemStack( Item.create( "apple" ), 1 ) )
			
			if ( leftToAdd:isEmpty() ) then
				-- Добавлено в инвентарь
				TempAppleTree.trees[ treeElement ].apples[ appleIndex ] = nil
				TempAppleTree.trees[ treeElement ].appleCount = TempAppleTree.trees[ treeElement ].appleCount - 1
				TempAppleTree.updateTree( treeElement )
				
				-- Даем опыт
				Objective.progress( Character.getID( client ), "disruptFruits" )
			else
				Popup.show( client, "Недостаточно места в инвентаре", "warning" )
				Debug.info( "No space in inv" )
			end
		end
		
		Animation.stop( client )
	end;
}
addEventHandler( "onResourceStart", resourceRoot, TempAppleTree.init )