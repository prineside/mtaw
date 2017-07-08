--[[
	Отвечает за использование текущей активной вещи быстрого доступа
	Тесно взаимодействует с Inventory, но вынесен в отдельный модуль для чистоты
--]]
--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "ItemUsage.onServerCancelUsage", true )								-- Сервер отменил использование вещи ()

--------------------------------------------------------------------------------
--<[ Модуль ItemUsage ]>--------------------------------------------------------
--------------------------------------------------------------------------------
ItemUsage = {
	cfg = {
		foodConsumingTime = 4000;
		herbDisruptionTime = 6000;
	};

	event = nil;		-- DelayedEvent текущего использования вещи (если вещь используется с задержкой)

	init = function()
		addEventHandler( "Main.onClientLoad", resourceRoot, ItemUsage.onClientLoad )
	end;
	
	onClientLoad = function()
		Debug.info( "ItemUsage запущен" )
		
		-- Убираем атаку на ЛКМ, если игрок не целится с ПКМ
		local fireDisabled = false -- Вызвано ли Control.disable
		addEventHandler( "onClientPreRender", root, function()
			if ( getControlState( "aim_weapon" ) ) then
				-- Целится
				if ( fireDisabled ) then
					Control.cancelDisabling( "fire", "ItemUsage" )
					fireDisabled = false
				end
			else
				-- Не целится
				if ( not fireDisabled ) then
					Control.disable( "fire", "ItemUsage" )
					fireDisabled = true
				end
			end
		end )
					
		-- Использование текущей вещи на ЛКМ
		bindKey( "mouse1", "down", function()
			-- Если инвентарь не активен, ЛКМ - использование вещи
			if ( not Inventory.isActive ) then
				-- Инвентарь не активен
				if ( not getControlState( "aim_weapon" ) ) then
					-- Не целится из оружия
					ItemUsage.start()
				end
			end
		end )
		
		bindKey( "mouse1", "up", function()
			ItemUsage.stop()
		end )
		
		-- При переключении текущего слота быстрого доступа, отменяем использование (если есть)
		addEventHandler( "Inventory.onActiveSlotChanged", resourceRoot, function()
			ItemUsage.stop()
		end )
		
		addEventHandler( "ItemUsage.onServerCancelUsage", resourceRoot, ItemUsage.stop )
	end;
	
	-- Начало использования вещи (по умолчанию ПКМ при неактивном инвентаре)
	-- Возвращает true при успешном начале использования вещи (можно использовать для отключения Control)
	-- = bool successfullStart, table errorMessages
	start = function()
		local used = false
		local errors = {}
			
		if ( ItemUsage.event ~= nil and ItemUsage.event.status ~= "stoped" ) then
			-- Еще не завершено использование прошлого события
			table.insert( errors, "Еще не закончилось предыдущее использование" )
			
			return false, errors
		end
		 
		if ( Inventory.getActiveFastSlotItemStack() ~= nil ) then
			-- Есть вещь в слоту, получаем данные о вещи в активном слоту
			local itemStack = Inventory.getActiveFastSlotItemStack()
			local item = itemStack:getItem()
			
			if ( item:hasTag( "food" ) ) then			
				-- Еда - употребление с анимацией ------------------------------					
				local event = DelayedEvent( ItemUsage.cfg.foodConsumingTime )
				ItemUsage.event = event
				
				event:onStart( function( event ) 
					if ( not isPedInVehicle( localPlayer ) ) then 
						Control.disableAll( "ItemUsage.item" ) 
					end
					triggerServerEvent( "ItemUsage.onStart", resourceRoot, Inventory.activeFastSlot )
				end )
				
				event:onProcess( function( event ) 
					GUI.sendJS( "Inventory.setItemUsageProgress", "fast", Inventory.activeFastSlot, event.progress * 100 )
				end )
				
				event:onStop( function( event, isSuccess ) 
					Control.cancelDisablingAll( "ItemUsage.item" )
					
					if ( isSuccess ) then
						local removedItem = itemStack:clone()
						removedItem:setCount( 1 )
						Inventory.containers.fast:removeItemFromSlot( Inventory.activeFastSlot, removedItem )
					end
					
					triggerServerEvent( "ItemUsage.onStop", resourceRoot, Inventory.activeFastSlot, isSuccess )
					GUI.sendJS( "Inventory.removeItemUsageProgress" )
				end )
				
				event:start()
				
				used = true
			end
			
			if ( item:hasTag( "tool" ) ) then
				-- Инструмент --------------------------------------------------
				if ( item:hasTag( "herbDisruptor" ) ) then
					-- Срывает Herb --------------------------------------------
					if ( Herb.targetedHerb ~= nil ) then
						-- Смотрит на растение
						local disruptionTime = ItemUsage.cfg.herbDisruptionTime * item:getParam( "herbDisruptSpeed" )
						local event = DelayedEvent( disruptionTime )
						
						local herbID = Herb.targetedHerb
						
						ItemUsage.event = event
						
						event:onStart( function( event ) 
							Control.disableAll( "ItemUsage.item" )
							triggerServerEvent( "ItemUsage.onStart", resourceRoot, Inventory.activeFastSlot, {
								herbID = herbID;
							} )
						end )
						
						event:onProcess( function( event ) 
							if ( herbID ~= Herb.targetedHerb ) then
								-- Перестал целиться на куст
								event:stop()
							else
								GUI.sendJS( "Inventory.setItemUsageProgress", "fast", Inventory.activeFastSlot, event.progress * 100 )
								Crosshair.setLabelProgress( event.progress * 100 )
							end
						end )
						
						event:onStop( function( event, isSuccess ) 
							Control.cancelDisablingAll( "ItemUsage.item" )
							
							if ( isSuccess ) then
								-- Убираем куст
								Herb.forceRendering = true
								Herb.herbs.class[ herbID ] = 0
								Crosshair.removeLabelProgress()
								Crosshair.removeLabel()
							end
							
							triggerServerEvent( "ItemUsage.onStop", resourceRoot, Inventory.activeFastSlot, isSuccess, {
								herbID = herbID;
							} )
							
							GUI.sendJS( "Inventory.removeItemUsageProgress" )
						end )
						
						event:start()
				
						used = true
					end
				end
			end
		else
			-- В слоту нет вещи
			table.insert( errors, "В слоту нет вещи" )
			
			return false, errors
		end
		
		return used, errors
	end;
	
	-- Отпустил ПКМ (перестал использовать вещь)
	-- = void
	stop = function()
		if ( ItemUsage.event ~= nil and ItemUsage.event.status ~= "stoped" ) then
			-- Событие есть, отменяем
			ItemUsage.event:stop()
			ItemUsage.event = nil
		end
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, ItemUsage.init )