--------------------------------------------------------------------------------
--<[ Модуль TempAppleTree ]>----------------------------------------------------
--------------------------------------------------------------------------------
TempAppleTree = {
	trees = {};		-- Индекс яблока => Элемент яблока
	
	init = function()
		addEventHandler( "Main.onClientLoad", resourceRoot, TempAppleTree.onClientLoad )
	end;
	
	onClientLoad = function()
		addEventHandler( "onClientElementStreamIn", root, TempAppleTree.onElementStreamIn )
		addEventHandler( "onClientElementStreamOut", root, TempAppleTree.onElementStreamOut )
		addEventHandler( "onClientElementDataChange", root, TempAppleTree.onElementDataChange )
	end;
	
	-- Обновить яблоки на дереве (создает или удаляет яблоки в соответствии с данными элемента дерева).
	-- Используется внутренне, при стриме деревьев и изменении их данных
	_updateTree = function( treeElement )
		local treeData = getElementData( treeElement, "_tat" )
		if ( TempAppleTree.trees[ treeElement ] ~= nil and treeData ~= false ) then
			-- Получаем данные о яблоках из строки
			for i = 1, #treeData do
				local c = treeData:sub( i, i )
				if ( c == "y" ) then
					-- Яблоко должно быть
					if ( TempAppleTree.trees[ treeElement ][ i ] == nil ) then
						-- Но его еще нет, создаем
						local appleX, appleY, appleZ = getPositionFromElementOffset( treeElement, ARR.treeFruitOffsets.apple[ i ][ 1 ], ARR.treeFruitOffsets.apple[ i ][ 2 ], ARR.treeFruitOffsets.apple[ i ][ 3 ] )
						local appleElement = createObject( 5374, appleX, appleY, appleZ )
						setElementDimension( appleElement, Dimension.get( "Global" ) )
						
						TempAppleTree.trees[ treeElement ][ i ] = appleElement
						
						-- Выделение текущего яблока
						local appleIndex = i
						
						addEventHandler( "CrosshairTarget.onTargetingStart", appleElement, function()
							-- Игрок смотрит на яблоко
							Crosshair.setLabel( "Сорвать", "Яблоко", nil, true )
							CrosshairTarget.highlightElement( appleElement )
						end )
						
						addEventHandler( "CrosshairTarget.onTargetingStop", appleElement, function()
							-- Игрок перестал смотреть на яблоко
							Crosshair.removeLabel()
							CrosshairTarget.highlightElement( nil )
						end )
						
						-- Обработка действия - сорвать яблоко
						
						local event = nil
						
						addEventHandler( "CrosshairTarget.onInteractionStart", appleElement, function()
							-- Игрок использует яблоко (нажали E)
							event = DelayedEvent( 2000, "onClientRender" )
							
							event:onStart( function( event ) 
								--Debug.info( "Яблоко START" )
								Control.disableAll( "TempAppleTree" )
								triggerServerEvent( "TempAppleTree.onDisruptAppleStart", resourceRoot, treeElement, appleIndex )
							end )
							
							event:onProcess( function( event ) 
								--Debug.info( "Яблоко PROCESS" )
								
								Crosshair.setLabelProgress( event.progress * 100 )
							end )
							
							event:onStop( function( event, isSuccess )
								--Debug.info( "Яблоко STOP" )
								
								Control.cancelDisablingAll( "TempAppleTree" )
								triggerServerEvent( "TempAppleTree.onDisruptAppleStop", resourceRoot, isSuccess, treeElement, appleIndex )
								Crosshair.removeLabelProgress()
								CrosshairTarget.stopInteraction()
							end )
						
							event:start()
						end )
						
						addEventHandler( "CrosshairTarget.onInteractionStop", appleElement, function()
							-- Игрок перестал срывать яблоко (отпустили E)
							event:stop()
						end )
						
					end
				else
					-- Яблока не должно быть
					if ( TempAppleTree.trees[ treeElement ][ i ] ~= nil ) then
						-- Но оно есть, удаляем
						destroyElement( TempAppleTree.trees[ treeElement ][ i ] )
						TempAppleTree.trees[ treeElement ][ i ] = nil
					end
				end
			end
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	onElementStreamIn = function()
		-- Застримили какой-то элемент
		if ( getElementType( source ) == "object" ) then
			local treeData = getElementData( source, "_tat" )
			if ( treeData ~= nil ) then
				-- Это дерево, добавляем в массив и обновляем яблоки
				TempAppleTree.trees[ source ] = {}
				TempAppleTree._updateTree( source )
			end
		end
	end;
	
	onElementStreamOut = function()
		if ( TempAppleTree.trees[ source ] ~= nil ) then
			-- Это дерево, удаляем яблоки 
			for appleIndex, appleElement in pairs( TempAppleTree.trees[ source ] ) do
				destroyElement( appleElement )
			end
			TempAppleTree.trees[ source ] = nil
		end
	end;
	
	onElementDataChange = function( dataName, oldValue )
		if ( dataName == "_tat" ) then
			-- Обновились данные дерева
			TempAppleTree._updateTree( source )
		end
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, TempAppleTree.init )