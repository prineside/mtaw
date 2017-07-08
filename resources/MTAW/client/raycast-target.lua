--[[
	RaycastTarget
	
	Цель для рейкастинга, в первую очередь используется для CrosshairTarget
	Представляет собой колизию, с которой не сталкиваются игроки и транспорт
	
	Рекомендуется использовать в стримере. Камера реагирует на колизии
--]]

--------------------------------------------------------------------------------
--<[ Модуль RaycastTarget ]>----------------------------------------------------
--------------------------------------------------------------------------------
-- TODO добавить корутину, которая будет отключать колизии новосозданным элементам
-- Потомм еще одну, которая будет отключать колизии существующих элементов с элементами, которые стримятся
RaycastTarget = {
	_modleIDs = {		-- ID моделей с колизиями
		sphere = {			-- Сферы
			small = 5371;		-- 0.25м
			medium = 5370;		-- 0.5м
			big = 5369;			-- 1.0м
		}
	};

	targets = {};		-- Массив существующих целей { element => bool status }. Статус true значит полностью готов, false - еще не обработан корутиной (еще не отключены колизии)
	_debugTargetElementColshape = {};		-- element -> colshape element во время дебага (чтобы было видно при showcol)
	
	init = function()
		addEventHandler( "onClientResourceStart", resourceRoot, RaycastTarget.onClientResourceStart )
	end;
	
	onClientResourceStart = function()
		
	end;
	
	-- Создать элемент-колизию, который реагирует только на raycast (processLineOfSight) и может быть использован в CrosshairTarget
	-- > shape string - форма колизии (см. _modleIDs)
	-- > size string - размер колизии (small / medium / big)
	-- > x number
	-- > y number
	-- > z number
	-- > dimension number - ID игрового измерения (полученный из Dimension.get)
	-- = element raycastTarget
	create = function( shape, size, x, y, z, dimension )
		if not validVar( shape, "shape", "string" ) then return nil end
		if not validVar( size, "size", "string" ) then return nil end
		if not validVar( x, "x", "number" ) then return nil end
		if not validVar( y, "y", "number" ) then return nil end
		if not validVar( z, "z", "number" ) then return nil end
		if not validVar( dimension, "dimension", "number" ) then return nil end
		
		if ( RaycastTarget._modleIDs[ shape ] == nil ) then
			Debug.error( "Форма " .. shape .. " не существует" )
			
			return nil
		end
		
		if ( RaycastTarget._modleIDs[ shape ][ size ] == nil ) then
			Debug.error( "Размер формы " .. shape .. " " .. size .. " не существует" )
			
			return nil
		end
		
		local element = createObject( RaycastTarget._modleIDs[ shape ][ size ], x, y, z )
		setElementDimension( element, dimension )
		setElementAlpha( element, 0 )
		
		if ( DEBUG_MODE ) then
			-- Колизия, которую будет видно в showcol
			local col = createColSphere( x, y, z, 0.5 )
			setElementDimension( col, dimension )
			RaycastTarget._debugTargetElementColshape[ element ] = col
		end
		
		RaycastTarget.targets[ element ] = false
		
		-- Для начала отключим колизии с самим игроком или его транспортом, корутина отключит колизии с остальными игроками
		setElementCollidableWith( element, localPlayer, false )
		if ( isPedInVehicle( localPlayer ) ) then
			setElementCollidableWith( element, getPedOccupiedVehicle( localPlayer ), false )
		end
		
		return element
	end;
	
	-- Удалить элемент колизии
	-- > raycastTargetElement element - элемент, ранее созданный через RaycastTarget.create
	-- = void
	destroy = function( raycastTargetElement )
		if not validVar( raycastTargetElement, "raycastTargetElement", "element" ) then return nil end
		
		if ( RaycastTarget.targets[ raycastTargetElement ] ~= nil ) then
			if ( DEBUG_MODE ) then
				destroyElement( RaycastTarget._debugTargetElementColshape[ raycastTargetElement ] )
			end
			destroyElement( raycastTargetElement )
		else
			Debug.info( "It is not a raycast target element" )
		end
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, RaycastTarget.init )