--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "CrosshairTarget.onTargetingStart", false )							-- Игрок начал смотреть на элемент. Вызывается на элементе, на который смотрят ( number hitX, number hitY, number hitZ )
addEvent( "CrosshairTarget.onTargetHitPointChange", false )						-- Переместил прицел по текущему элементу. Вызывается на элементе, на который смотрят  ( number hitX, number hitY, number hitZ )
addEvent( "CrosshairTarget.onTargetingStop", false )							-- Игрок перестал смотреть на элемент. Вызывается на элементе, на который смотрели перед этим ()
addEvent( "CrosshairTarget.onInteractionStart", false )							-- Игрок нажал на E, когда смотрел на элемент. Вызывается на элементе, с которым взаимодействуют ()
addEvent( "CrosshairTarget.onInteractionStop", false )							-- Игрок отпустил E, перестал смотреть на элемент или элемент был удален. Вызывается на элементе, с которым взаимодействуют ()

--[[
	TODO
	Добавить обработчики взаимодействия с элементом на кнопку E. 
	При обработке события onTargetingStart другие скрипты могут сами включать подсветку и устанавливать подписи для прицела.
	
	Переделать алгоритм (текущий плох тем, что много рейкастов, и между рейкастами есть пробелы, куда попадают мелкие элементы)
	
--]]

--------------------------------------------------------------------------------
--<[ Модуль CrosshairTarget ]>--------------------------------------------------
--------------------------------------------------------------------------------
CrosshairTarget = {
	enabled = false;
	
	actionRadius = 2.5;			
	rayCastRadius = 15;
	
	highlightShader = nil;			
	normalVehicleShader = nil;			
	normalBuildingShader = nil;			
	highlightedElement = nil;			-- Элемент, который выделен мигающим шейдером
	
	targetElement = nil;				-- Элемент, на который смотрит игрок
	targetElementHitPoint = {};			-- Точка, на которую смотрит игрок
	nowInteracting = false;				-- Взаимодействует ли игрок с элементом сейчас (через E)
	
	raycastMask = { 
		{ x = 0, y = 0 },
		{ x = 9, y = 9 },
		{ x = 9, y = -9 },
		{ x = -9, y = 9 },
		{ x = -9, y = -9 },
		{ x = 0, y = 18 },
		{ x = 0, y = -18 },
		{ x = 18, y = 0 },
		{ x = -18, y = 0 },
		-- { x = 15, y = 22 },
	};
	
	init = function()
		-- Инициализация шейдеров
		CrosshairTarget.highlightShader = Shader.create( "client/data/shaders/outline-back.fx", 3, 50, true, "all" )
		CrosshairTarget.normalVehicleShader = Shader.create( "client/data/shaders/outline-normal-vehicle.fx", 4, 50, true, "all" )
		CrosshairTarget.normalBuildingShader = Shader.create( "client/data/shaders/outline-normal-building.fx", 4, 50, true, "all" )
		
		-- Обработчики событий
		addEventHandler( "onClientRender", root, CrosshairTarget.onClientRender )
		addEventHandler( "Character.onCharacterChange", root, CrosshairTarget.onCharacterChange )
		
		-- Если элемент, на который 
		addEventHandler( "onClientElementDestroy", root, CrosshairTarget.onElementDestroy )
		
		-- Бинд на кнопку E
		-- TODO взаимодействие может быть и через другие кнопки - придумать, как лучше это сделать
		-- Возможно, лучше вызывать onInteractionStart с каждой нажатой кнопкой, и добавить возможность отменить событие (только как-то наоборот, типа event.isHandled = true, а если в конце не true, считать, что взаимодействие не произошло)
		bindKey( "e", "down", function()
			if ( CrosshairTarget.targetElement ~= nil ) then
				-- Смотрит на какой-то элемент
				if ( not CrosshairTarget.nowInteracting ) then
					-- Еще не взаимодействует с элементом
					triggerEvent( "CrosshairTarget.onInteractionStart", CrosshairTarget.targetElement )
					CrosshairTarget.nowInteracting = true
				else
					Debug.info( "Уже идет взаимодействие" )
				end
			end
		end )
		
		bindKey( "e", "up", function()
			CrosshairTarget.stopInteraction( true )
		end )
	end;
	
	-- Включить модуль CrosshairTarget (будут вызываться события и обнаруживаться элемент взаимодействия)
	-- = void
	enable = function()
		CrosshairTarget.enabled = true
	end;

	-- Выключить модуль - события не будут вызываться
	-- = void
	disable = function()
		CrosshairTarget.enabled = false
	end;
	
	-- Добавить мигающий шейдер элементу (при этом уберется шейдер из предыдущего элемента)
	-- Предполагается использование в обработчике CrosshairTarget.onTargetingStart совместно с Crosshair.setLabel для элементов, с которыми можно взаимодействовать
	-- > element element - элемент, на который нужно добавить шейдер (пед, игрок, объект или транспортное средство)
	-- > textureName string / nil - название текстуры элемента, на которую будет размещен шейдер
	-- = void
	highlightElement = function( element, textureName )
		if ( textureName == nil ) then textureName = "*" end
	
		-- Убираем шейдер из старого элемента
		if ( CrosshairTarget.highlightedElement ~= nil ) then
			local elementType = getElementType( CrosshairTarget.highlightedElement )
			
			engineRemoveShaderFromWorldTexture( CrosshairTarget.highlightShader, "*", CrosshairTarget.highlightedElement )
			if ( elementType == "vehicle" ) then
				engineRemoveShaderFromWorldTexture( CrosshairTarget.normalVehicleShader, "*", CrosshairTarget.highlightedElement )
			else
				engineRemoveShaderFromWorldTexture( CrosshairTarget.normalBuildingShader, "*", CrosshairTarget.highlightedElement )
			end
			
			CrosshairTarget.highlightedElement = nil
		end
		
		if ( element ~= nil ) then
			-- Добавляем шейдер
			local elementType = getElementType( element )
			
			engineApplyShaderToWorldTexture( CrosshairTarget.highlightShader, textureName, element, true )
			if ( elementType == "vehicle" ) then
				engineApplyShaderToWorldTexture( CrosshairTarget.normalVehicleShader, textureName, element, true )
			else
				engineApplyShaderToWorldTexture( CrosshairTarget.normalBuildingShader, textureName, element, true )
			end
			
			CrosshairTarget.highlightedElement = element
		end
	end;
	
	-- Закончить взаимодействие с элементом. withEvent не использовать (вызывается только внутренне)
	-- > withEvent string / nil - для внутреннего использования, не указывать
	-- = void
	stopInteraction = function( withEvent )
		if withEvent == nil then withEvent = false end
		
		if ( CrosshairTarget.nowInteracting ) then
			if ( CrosshairTarget.targetElement ~= nil ) then
				if ( withEvent ) then
					triggerEvent( "CrosshairTarget.onInteractionStop", CrosshairTarget.targetElement )
				end
			else
				Debug.warn( "Невозможно отменить взаимодействие - элемент уже зачищен" )
			end
		end
		
		CrosshairTarget.nowInteracting = false
	end;
	
	-- Внутрення функция, устанавливает элемент, на который смотрит игрок
	_setCurrentTarget = function( targetedElement, hitX, hitY, hitZ )
		if not validVar( element, "element", { "nil", "element" } ) then return nil end
		
		if ( targetedElement ~= CrosshairTarget.targetElement ) then
			-- Смотрим на новый элемент
			if ( CrosshairTarget.targetElement ~= nil ) then
				-- Перед этим смотрели на элемент
				if ( CrosshairTarget.nowInteracting ) then
					-- И взаимодействовали. Отменяем взаимодействие
					CrosshairTarget.stopInteraction( true )
				end
				triggerEvent( "CrosshairTarget.onTargetingStop", CrosshairTarget.targetElement )
			end
			
			if ( targetedElement ~= nil ) then
				-- Сейчас смотрим на элемент
				triggerEvent( "CrosshairTarget.onTargetingStart", targetedElement, hitX, hitY, hitZ )
			end
		else
			-- Смотрим на тот же элемент
			triggerEvent( "CrosshairTarget.onTargetHitPointChange", targetedElement, hitX, hitY, hitZ )
		end
		
		CrosshairTarget.targetElement = targetedElement
		CrosshairTarget.targetElementHitPoint.x = hitX
		CrosshairTarget.targetElementHitPoint.y = hitY
		CrosshairTarget.targetElementHitPoint.z = hitZ
		
		--[[
		if ( DEBUG_MODE ) then
			CrosshairTarget.highlightElement( targetedElement )
		end
		--]]
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	_lastRenderHandled = 0;
	onClientRender = function()
		-- TODO оптимизировать
		if ( CrosshairTarget.enabled and not isPedInVehicle( localPlayer ) ) then
			-- Модуль включен, игрок не в транспорте
			if ( getControlState( "aim_weapon" ) ) then
				-- Игрок целится из оружия
				local currWP = getPedWeapon( localPlayer )
				if ( currWP == 34 or currWP == 43 ) then
					-- Оружие с прицелом по центру, отмена
					if ( CrosshairTarget.targetElement ~= nil ) then
						CrosshairTarget._setCurrentTarget( nil )
					end
					return nil
				end
			end
			
			local t = getTickCount()
			
			local sx, sy = math.floor( GUI.screenSize.x * 0.5303 + 0.5 ), math.floor( GUI.screenSize.y * 0.4032 + 0.5 )
			
			if ( t - CrosshairTarget._lastRenderHandled > CFG.misc.crosshairTargetRaycastInterval ) then
				CrosshairTarget._lastRenderHandled = t
				
				local camPosX, camPosY, camPosZ = getCameraMatrix()
				local plrX, plrY, plrZ = getElementPosition( localPlayer )
				
				-- Сначала строго по прицелу
				local tx, ty, tz = getWorldFromScreenPosition( sx, sy, CrosshairTarget.rayCastRadius )
				local hit, x, y, z, elementHit = processLineOfSight( camPosX, camPosY, camPosZ, tx, ty, tz, false, true, true, true, false, false, true, false, localPlayer, false, false )

				if ( hit and elementHit ~= nil ) then
					if ( getDistanceBetweenPoints3D( x, y, z, plrX, plrY, plrZ ) < CrosshairTarget.actionRadius ) then -- Если игрок может дотянуться до предмета
						if ( CrosshairTarget.targetElementHitPoint.x ~= x or CrosshairTarget.targetElementHitPoint.y ~= y or CrosshairTarget.targetElementHitPoint.z ~= z ) then
							CrosshairTarget._setCurrentTarget( elementHit, x, y, z )
						end
				
						return nil
					end
				end
				
				
				-- Затем несколько лучей для большего радиуса
				--local stepCnt = 1
				for _, rayCastShift in pairs( CrosshairTarget.raycastMask ) do
					local dotX, dotY = sx + rayCastShift.x, sy + rayCastShift.y
					
					--dxDrawText( tostring( stepCnt ), dotX - 10, dotY - 10, dotX + 10, dotY + 10, nil, 0.5, "default", "center", "center" )
					--stepCnt = stepCnt + 1
					
					local tx, ty, tz = getWorldFromScreenPosition( dotX, dotY, CrosshairTarget.rayCastRadius )
					local hit, x, y, z, elementHit = processLineOfSight( camPosX, camPosY, camPosZ, tx, ty, tz, false, true, true, true, false, false, true, false, localPlayer, false, false )

					if ( hit and elementHit ~= nil ) then
						if ( getDistanceBetweenPoints3D( x, y, z, plrX, plrY, plrZ ) < CrosshairTarget.actionRadius ) then -- Если игрок может дотянуться до предмета
							-- Если изменилась точка удара raycast, вызываем функцию заново
							if ( CrosshairTarget.targetElementHitPoint.x ~= x or CrosshairTarget.targetElementHitPoint.y ~= y or CrosshairTarget.targetElementHitPoint.z ~= z ) then
								CrosshairTarget._setCurrentTarget( elementHit, x, y, z )
							end
			
							return nil
						end
					end
				end
				
				-- Если так ничего и не нашли
				if ( CrosshairTarget.targetElement ~= nil ) then
					CrosshairTarget._setCurrentTarget( nil )
				end
			end
			
			
		else
			-- Курсор не активен
			
			-- Если смотрел на какой-то предмет
			if ( CrosshairTarget.targetElement ~= nil ) then
				CrosshairTarget._setCurrentTarget( nil )
			end
		end
	end;
	
	-- Какой-то элемент был удален
	onElementDestroy = function()
		if ( CrosshairTarget.targetElement == source ) then
			-- Удалили текущий элемент
			if ( CrosshairTarget.nowInteracting ) then
				CrosshairTarget.stopInteraction( true )
			end
			CrosshairTarget._setCurrentTarget( nil )
		end
	end;
	
	onCharacterChange = function()
		if ( Character.isSelected() ) then
			CrosshairTarget.enable()
		else
			CrosshairTarget.disable()
		end
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, CrosshairTarget.init )