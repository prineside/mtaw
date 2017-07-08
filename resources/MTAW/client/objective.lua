--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Objective.onServerUpdateAllObjectives", true )						-- Пришло состояние всех целей ( table objectives )
addEvent( "Objective.onServerUpdateObjective", true )							-- Сервер обновил одну цель ( string objectiveAlias, number total, number current, bool skipTotalUpdate )
addEvent( "Objective.onServerResponseTypes", true )								-- Ответ на Objective.onClientRequestObjectiveTypes ( table objectiveTypes )

--------------------------------------------------------------------------------
--<[ Модуль Objective ]>--------------------------------------------------------
--------------------------------------------------------------------------------
Objective = {
	objectiveTypes = nil;

	init = function()
		-- Запрашиваем у сервера типы целей
		Main.setModuleLoaded( "Objective", 0.25 )
		addEventHandler( "Objective.onServerResponseTypes", resourceRoot, function( objectiveTypes )
			-- Сервер прислал типы целей
			--Debug.info( "Сервер прислал типы целей", objectiveTypes )
			Objective.objectiveTypes = objectiveTypes
			Main.setModuleLoaded( "Objective", 1 )
		end )
		triggerServerEvent( "Objective.onClientRequestObjectiveTypes", resourceRoot )
		
		-- Сервер обновил состояние какой-то цели
		addEventHandler( "Objective.onServerUpdateObjective", resourceRoot, Objective.onServerUpdateObjective )
		
		-- Сервер прислал состояние всех целей
		addEventHandler( "Objective.onServerUpdateAllObjectives", resourceRoot, Objective.onServerUpdateAllObjectives )
		
		addEventHandler( "Main.onClientLoad", resourceRoot, Objective.onClientLoad )
	end;
	
	onClientLoad = function()
		-- Обновляем шаблон списка целей в инвентаре
		GUI.sendJS( "Objective.setObjectiveTypes", Objective.objectiveTypes )
	end;
	
	-- Обновить глобальное состояние (полосу уровня) внизу списка целей
	-- = void
	updateGuiTotalStatus = function()
		if ( Character.isSelected() ) then
			local levelInfo = Character.getLevelInfo( Character.data.experience )
					
			GUI.sendJS( "Objective.setTotalStatus", levelInfo.level, levelInfo.levelExp, levelInfo.nextLevelExp )
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Обновился статус цели
	onServerUpdateObjective = function( objectiveAlias, total, current, skipTotalUpdate )
		--Debug.info( "Обновлено состояние цели ", objectiveAlias, total, current )
		GUI.sendJS( "Objective.setObjectiveStatus", objectiveAlias, current, Objective.objectiveTypes[ objectiveAlias ].amount, total )
		
		if ( skipTotalUpdate ~= true ) then
			-- Обновляем состояние уровня
			Objective.updateGuiTotalStatus();
		end
	end;
	
	-- Сервер прислал статусы всех целей
	onServerUpdateAllObjectives = function( objectives )
		--Debug.info( "Обновлено состояние всех целей", objectives )
		for objectiveAlias, objectiveInfo in pairs( objectives ) do
			Objective.onServerUpdateObjective( objectiveAlias, objectiveInfo.total, objectiveInfo.current, true ) -- true - не обновлять глобальный статус
		end
		
		-- Обновляем состояние уровня
		Objective.updateGuiTotalStatus();
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, Objective.init )