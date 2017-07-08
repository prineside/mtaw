
--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "ItemUsage.onStart", true )											-- Игрок начал использовать вещь ( number fastSlotID, table / nil additionalData )
addEvent( "ItemUsage.onStop", true )											-- Игрок прекратил использовать вещь ( number fastSlotID, bool isSuccess, table / nil additionalData )

--------------------------------------------------------------------------------
--<[ Модуль ItemUsage ]>--------------------------------------------------------
--------------------------------------------------------------------------------
ItemUsage = {
	cfg = {
		foodConsumingTime = 4000;
		herbDisruptionTime = 3000;
	};
	
	_startTime = {};					-- Время начала использования вещи игроком { playerElement => tickCount }. Очищается, если игрок изменил активный слот быстрого доступа
	_startItemStack = {};				-- Стак вещей, который использовался последним
	_startAdditionalData = {};			-- Дополнительная информация, которая последней попадала в onStart
	
	init = function()
		addEventHandler( "Main.onServerLoad", resourceRoot, ItemUsage.onServerLoad )
	end;
	
	onServerLoad = function()
		-- Обрабатываем сообщения от клиента об использовании вещи быстрого доступа
		addEventHandler( "ItemUsage.onStart", resourceRoot, ItemUsage.onStart )
		addEventHandler( "ItemUsage.onStop", resourceRoot, ItemUsage.onStop )
		
		addEventHandler( "Inventory.onActiveSlotChanged", resourceRoot, ItemUsage.onInventoryActiveSlotChanged )
		
		Debug.info( "ItemUsage started" )
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Игрок начал использовать вещь быстрого доступа
	onStart = function( fastSlotID, additionalData )
		if not validVar( fastSlotID, "fastSlotID", "number" ) then return nil end
		if not validVar( additionalData, "additionalData", { "table", "nil" } ) then return nil end
	
		local playerElement = client

		if ( Inventory.isLoaded( playerElement ) and Inventory.getFastContainer( playerElement ):slotExists( fastSlotID ) ) then
			-- Инвентарь загружен, используется правильный слот быстрого доступа
			if ( Inventory.getActiveFastSlot( playerElement ) ~= fastSlotID ) then
				Inventory.setActiveFastSlot( playerElement, fastSlotID )
			end
			
			local itemStack = Inventory.getActiveFastSlotItemStack( playerElement )
			if ( itemStack ~= nil ) then
				-- Вещь есть
				ItemUsage._startTime[ playerElement ] = getTickCount()
				ItemUsage._startItemStack[ playerElement ] = itemStack:clone()
				ItemUsage._startAdditionalData[ playerElement ] = additionalData
				
				local item = itemStack:getItem()
				
				if ( item:hasTag( "food" ) ) then
					-- Еда - употребление с анимацией --------------------------
					Animation.play( playerElement, "FOOD", "EAT_Burger", ItemUsage.cfg.foodConsumingTime )
				end
				
				if ( item:hasTag( "tool" ) ) then
					-- Инструмент ----------------------------------------------
					if ( item:hasTag( "herbDisruptor" ) ) then
						-- Срывает Herb ----------------------------------------
						local herbID = additionalData.herbID
						if ( herbID ~= nil and Herb.exists( herbID ) ) then
							-- Растение существует
							local herbClass, growPhase = Herb.getInfo( herbID )
							
							if ( ARR.herbClasses[ herbClass ] == nil ) then
								Debug.info( "Herb class " .. tostring( herbClass ) .. " doesn't exist" )
								
								return nil
							end	
							
							local disruptionTypeFits = ARR.herbClasses[ herbClass ].disruptionToolType[ item:getParam( "herbDisruptType" ) ] ~= nil
							if ( disruptionTypeFits ) then
								-- Инструмент подходит для сбора этого растения
								local disruptionTime = ItemUsage.cfg.herbDisruptionTime * item:getParam( "herbDisruptSpeed" )
								
								-- BOM_Plant_In
								if ( disruptionTime < 1000 ) then
									Animation.play( playerElement, "BOMBER", "BOM_Plant_In", disruptionTime, "x0.9", false, true )
								else
									Animation.play( playerElement, "BOMBER", "BOM_Plant", disruptionTime * 1.9, nil, false, false )
								end
								
								local px, py = getElementPosition( playerElement )
								local hx, hy = Herb.getPos( herbID )
								local angleToHerb = getAngleBetweenPoints( px, py, hx, hy )
								
								setElementRotation( playerElement, 0, 0, angleToHerb, "default", true )
							end
						end
					end
				end
			end
		end
	end;
	
	-- Игрок перестал использовать вещь быстрого доступа
	-- _startItemStack используется, если событие было отменено и вещь в активном слоту могла измениться (используется в onInventoryActiveSlotChanged), при этом fastSlotID не учитывается
	-- Внимание! НЕ устанавливать никакие вещи, если isSuccess равен false!
	onStop = function( fastSlotID, isSuccess, additionalData, _startItemStack )
		if not validVar( fastSlotID, "fastSlotID", "number" ) then return nil end
		if not validVar( isSuccess, "isSuccess", "boolean" ) then return nil end
		if not validVar( additionalData, "additionalData", { "table", "nil" } ) then return nil end
		if not validVar( _startItemStack, "_startItemStack", { "table", "nil" } ) then return nil end
	
		local playerElement = client
		
		if ( ItemUsage._startTime[ playerElement ] ~= nil ) then
			-- Есть начало использования вещи
			local usageTime = getTickCount() - ItemUsage._startTime[ playerElement ]	-- Время (мс) с момента начала использования вещи
			ItemUsage._startTime[ playerElement ] = nil
			
			local fastContainer = Inventory.getFastContainer( playerElement )
			
			local itemStack
			
			if ( _startItemStack ~= nil ) then
				-- Стак передан напрямую (внутренний вызов)
				if ( isSuccess ) then
					-- Ошибка - не может быть успешным использованием
					Debug.error( "onStop can't be both success and with _startItemStack" )
					
					return nil
				end
				itemStack = _startItemStack
				Debug.info( "FB" )
			else
				-- Стак не передан - берем из активного слота БД
				itemStack = fastContainer:getItem( fastSlotID )
			end
			
			if ( itemStack ~= nil and not itemStack:isEmpty() ) then
				-- Есть вещь, которую использовали
				local item = itemStack:getItem()
				
				if ( item:hasTag( "food" ) ) then
					-- Еда - употребление с анимацией --------------------------
					Animation.stop( playerElement )
					
					if ( isSuccess ) then
						-- Успешное использование
						if ( usageTime < ItemUsage.cfg.foodConsumingTime * 0.75 ) then
							-- Использовано слишком быстро
							Debug.info( "Food consumed in " .. usageTime .. "ms while min time is " .. ItemUsage.cfg.foodConsumingTime )
							
							Inventory.sendContainerSlotToClient( playerElement, "fast", fastSlotID )
						else
							-- Время использования нормальное, добавляем сытость
							local newSatiety = Character.getSatiety( playerElement ) + item:getParam( "satietyRegen" )

							Character.setSatiety( playerElement, newSatiety )
							
							-- Удаляем вещь
							itemStack:removeItems( 1 )
							fastContainer:setItem( fastSlotID, itemStack )
						end
					end
				end
				
				if ( item:hasTag( "tool" ) ) then
					-- Инструмент ----------------------------------------------
					if ( item:hasTag( "herbDisruptor" ) ) then
						-- Срывает Herb ----------------------------------------
						if ( isSuccess ) then
							-- Успешное применение
							local herbID = additionalData.herbID
							if ( herbID ~= nil and Herb.exists( herbID ) ) then
								-- Растение существует
								local herbClass, growPhase = Herb.getInfo( herbID )
										
								local disruptionTypeFits = ARR.herbClasses[ herbClass ].disruptionToolType[ item:getParam( "herbDisruptType" ) ] ~= nil
								if ( disruptionTypeFits ) then
									-- Инструмент подходит для сбора этого растения
									local disruptionTime = ItemUsage.cfg.herbDisruptionTime * item:getParam( "herbDisruptSpeed" )
									
									if ( usageTime > disruptionTime * 0.75 ) then
										-- Нормальное время использования
										-- Добавляем сорванное растение
										local disruptionDrop = ARR.herbClasses[ herbClass ].growPhases[ growPhase ].disruptionDrop
										if ( disruptionDrop ) then
											-- Что-то выпадает
											for _, dropInfo in pairs( disruptionDrop ) do
												local params
												local count
												
												if ( type( dropInfo.params ) == "function" ) then
													params = dropInfo.params( item )
												else
													params = dropInfo.params
												end
												
												if ( type( dropInfo.count ) == "function" ) then
													count = dropInfo.count( item )
												else
													count = dropInfo.count
												end
												
												local newItem = Item( dropInfo.class, params )
												local newStack = ItemStack( newItem, count )
												
												local leftToAdd = Inventory.addItem( playerElement, newStack )
												if ( not leftToAdd:isEmpty() ) then
													-- Добавилось не все
													-- TODO создаем дроп
												end	
												
												-- Износ
												item:setParam( "timesUsed", item:getParam( "timesUsed" ) + 1 )
												Inventory.sendContainerSlotToClient( playerElement, "fast", fastSlotID )
											end
										end
										
										-- Убираем растение
										Herb.set( herbID, 0, 1 )
										
										-- Обновляем прогресс выполнения цели
										Objective.progress( Character.getID( playerElement ), "disruptHerbs" )
										
										-- Вызываем Evidence
										Evidence.trigger( playerElement, EvidenceType.disruptHerb, { 
											herbClass = herbClass;
										} )
									else
										-- Использовано слишком быстро
										Debug.info( "Tool used in " .. usageTime .. "ms while min time is " .. disruptionTime )
									end
								else
									-- Инструмент не подходит
									Debug.info( "Disruption tool type doesn't fit" )
								end
								
								-- Обновляем растение на клиенте
								Herb.updateClientHerbs( playerElement, { herbID } )
							else
								-- Неправильно указано растение
								Debug.info( "Invalid herb id: " .. tostring( herbID ) )
							end
						end
					end
					
					Animation.stop( playerElement )
				end
			end
		else
			-- Не было вызвано событие начала использования вещи или активный слот изменился - отменяем
			Debug.info( "No start tickCount, cancelling" )
		end
	end;
	
	-- Изменился активный слот быстрого доступа игрока
	-- Если слот не тот же, что и был, сбрасываем время начала использования
	onInventoryActiveSlotChanged = function( playerElement, newSlotID, oldSlotID )
		if ( newSlotID ~= oldSlotID and ItemUsage._startTime[ playerElement ] ~= nil ) then
			ItemUsage.onStop( oldSlotID, false, ItemUsage._startAdditionalData[ playerElement ], ItemUsage._startItemStack[ playerElement ] )
			ItemUsage._startTime[ playerElement ] = nil
		end
	end;
}
addEventHandler( "onResourceStart", resourceRoot, ItemUsage.init )