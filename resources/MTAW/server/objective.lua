--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Objective.onCharacterCompletedObjective", false )					-- Игрок выполнил задание - например, собрал 100 яблок из 100 ( number characterID, string objectiveAlias )

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------
addEvent( "Objective.onClientRequestObjectiveTypes", true ) 					-- Клиент запросил список типов целей ()

--------------------------------------------------------------------------------
--<[ Модуль Objective ]>--------------------------------------------------------
--------------------------------------------------------------------------------
Objective = {
	objectiveTypes = {};	 	-- playOneHour => [ amount, experience, title, description, totalExpGiven ]
	
	characters = {};			-- characterID => [ playOneHour => [ total, current ], ... ]
	
	init = function()
		-- Загрузка типов целей
		local isSuccess, result = DB.syncQuery( "SELECT * FROM mtaw.objective_type WHERE enabled = 1" )
		
		if ( not isSuccess ) then return nil end
		
		Objective.objectiveTypes = {}
		
		local objectivesLoaded = 0
		for _, row in pairs( result ) do
			Objective.objectiveTypes[ row.alias ] = {
				title = row.title;
				description = row.description;
				amount = row.amount;
				experience = row.experience;
				totalExpGiven = row.total_exp_given;
			}
			objectivesLoaded = objectivesLoaded + 1
		end
		
		Debug.info( "Loaded " .. objectivesLoaded .. " objective types" )
		
		-- Обработка запросов типов целей от клиентов
		addEventHandler( "Objective.onClientRequestObjectiveTypes", resourceRoot, Objective.onClientRequestObjectiveTypes )
		
		-- Обработка создания и удаления персонажей
		addEventHandler( "Character.onCharacterSpawn", resourceRoot, Objective.onCharacterSpawn )
		addEventHandler( "Character.onCharacterDespawn", resourceRoot, Objective.onCharacterDespawn )
		
		-- Периодическое сохранение общей статистики целей
		setTimer( Objective.saveGlobal, 5 * 60 * 1000, 0 )
		
		-- Сохранение после выключения сервера
		addEventHandler( "onResourceStop", resourceRoot, Objective.saveGlobal )
	end;
	
	-- Добавить единицы в прогресс выполнения задания
	-- > characterID number
	-- > objectiveAlias string
	-- = void
	progress = function( characterID, objectiveAlias )
		-- TODO не только +1
		if ( Objective.characters[ characterID ] ~= nil and Objective.objectiveTypes[ objectiveAlias ] ~= nil ) then
			-- Персонаж загружен и такое задание есть
			Objective.characters[ characterID ][ objectiveAlias ].total = Objective.characters[ characterID ][ objectiveAlias ].total + 1
			Objective.characters[ characterID ][ objectiveAlias ].current = Objective.characters[ characterID ][ objectiveAlias ].current + 1
			if ( Objective.characters[ characterID ][ objectiveAlias ].current >= Objective.objectiveTypes[ objectiveAlias ].amount ) then
				-- Прошел amount, добавляем опыт
				Character.addExperience( Character.getPlayerElement( characterID ), Objective.objectiveTypes[ objectiveAlias ].experience )
				Objective.characters[ characterID ][ objectiveAlias ].current = 0
				Objective.characters[ characterID ][ objectiveAlias ].expGiven = Objective.characters[ characterID ][ objectiveAlias ].expGiven + Objective.objectiveTypes[ objectiveAlias ].experience
				triggerEvent( "Objective.onCharacterCompletedObjective", resourceRoot, characterID, objectiveAlias )
				
				Objective.objectiveTypes[ objectiveAlias ].totalExpGiven = Objective.objectiveTypes[ objectiveAlias ].totalExpGiven + Objective.objectiveTypes[ objectiveAlias ].experience
			end
			
			-- Обновляем на клиенте значение опыта
			triggerClientEvent( Character.getPlayerElement( characterID ), "Objective.onServerUpdateObjective", resourceRoot, objectiveAlias, Objective.characters[ characterID ][ objectiveAlias ].total, Objective.characters[ characterID ][ objectiveAlias ].current )
			
			-- Отмечаем цель как измененную
			Objective.characters[ characterID ][ objectiveAlias ].touched = true
		else
			Debug.info( "Character " .. tostring( characterID ) .. " hasn't loaded objectives" )
		end
	end;
	
	-- Сохранить данные о целях в базе
	-- > characterID number
	-- = void
	saveCharacter = function( characterID )
		if not validVar( characterID, "characterID", "number" ) then return nil end
	
		local characterObjectives = Objective.characters[ characterID ]
		
		if ( characterObjectives == nil ) then
			Debug.error( "Character " .. characterID .. " is not loaded, can't save" )
			return nil
		end
		
		local query = "INSERT INTO mtaw.objective (`type`, `character`, `current`, `total`, `exp_given`) VALUES "
		
		local valuesArray = {}
		for objectiveAlias, objectiveInfo in pairs( Objective.objectiveTypes ) do
			if ( characterObjectives[ objectiveAlias ].touched ) then
				-- Цель была обновлена, есть смысл добавлять в запрос
				table.insert( valuesArray, "('" .. objectiveAlias .. "', " .. characterID .. ", " .. characterObjectives[ objectiveAlias ].current .. ", " .. characterObjectives[ objectiveAlias ].total .. ", " .. characterObjectives[ objectiveAlias ].expGiven .. ")" )
				characterObjectives[ objectiveAlias ].touched = false
			end
		end
		
		if ( #valuesArray ~= 0 ) then
			-- Есть что обновлять
			query = query .. table.concat( valuesArray, "," ) .. " ON DUPLICATE KEY UPDATE `current`=VALUES(`current`), `total`=VALUES(`total`), `exp_given`=VALUES(`exp_given`);"
			
			--Debug.info( query )
			
			DB.syncQuery( query )
		end
		
		Debug.info( "Saved " .. characterID .. " objectives" )
	end;
	
	-- Сохранить глобальную статистику (total_exp_given и прочее)
	-- = void
	saveGlobal = function()
		local query = "INSERT INTO mtaw.objective_type (`alias`, `total_exp_given`) VALUES "
		local valuesArray = {}
		for objectiveAlias, objectiveInfo in pairs( Objective.objectiveTypes ) do
			table.insert( valuesArray, "('" .. objectiveAlias .. "', " .. objectiveInfo.totalExpGiven .. ")" )
		end
		query = query .. table.concat( valuesArray, "," ) .. " ON DUPLICATE KEY UPDATE `total_exp_given`=VALUES(`total_exp_given`);"

		DB.syncQuery( query )
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Персонаж появился в игре, загрузка целей
	onCharacterSpawn = function( playerElement, characterID )
		local isSuccess, result = DB.syncQuery( "SELECT * FROM mtaw.objective WHERE `character` = " .. characterID )
		
		if ( not isSuccess ) then return nil end
		
		local characterObjectives = {}
		for objectiveAlias, objectiveInfo in pairs( Objective.objectiveTypes ) do
			characterObjectives[ objectiveAlias ] = {
				total = 0;
				current = 0;
				expGiven = 0;
			}
		end
		
		for _, row in pairs( result ) do
			characterObjectives[ row.type ].total = row.total
			characterObjectives[ row.type ].current = row.current
			characterObjectives[ row.type ].expGiven = row.exp_given
			
			characterObjectives[ row.type ].touched = false
		end
		
		Objective.characters[ characterID ] = characterObjectives
		
		-- Отправка состояния на клиент
		triggerClientEvent( playerElement, "Objective.onServerUpdateAllObjectives", resourceRoot, characterObjectives )
		
		Debug.info( "Loaded character " .. characterID .. " objectives" )
	end;
	
	-- Персонаж вышел из игры, сохранение опыта и очистка памяти
	onCharacterDespawn = function( playerElement, characterID )
		Objective.saveCharacter( characterID )
		
		Objective.characters[ characterID ] = nil
		Debug.info( "Unloaded character " .. characterID .. " objectives" )
	end;
	
	-- Клиент запрашивает список типов целей
	onClientRequestObjectiveTypes = function()
		Debug.info( "Client requested objective types" )
		triggerClientEvent( client, "Objective.onServerResponseTypes", resourceRoot, Objective.objectiveTypes )
	end;
}
addEventHandler( "onResourceStart", resourceRoot, Objective.init )