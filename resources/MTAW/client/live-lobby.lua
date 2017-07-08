--------------------------------------------------------------------------------
--<[ Модуль LiveLobby ]>--------------------------------------------------------
--------------------------------------------------------------------------------
LiveLobby = {
	startTick = nil;
	trains = {
		near = {
			lastTimelineEvent = -1;
			x = 1965.20; y = -1943.89; z = 15.14;
			direction = true;
			head = nil;
			trailers = {};
			timeline = {
				{ -- Стоит несколько секунд за кадром (пауза)
					duration = 10 * 1000;
					startSpeed = 0.0;
					endSpeed = 0.0;
					easing = "Linear";
				};
				{ -- Прибывает (создан - приехал и остановился)
					duration = 20 * 1000;
					startSpeed = 0.8;
					endSpeed = 0.0;
					easing = "OutQuad";
				};
				{ -- Ждет (стоит на месте)
					duration = 15 * 1000;
					startSpeed = 0.0;
					endSpeed = 0.0;
					easing = "Linear";
				};
				{ -- Отбывает (тронулся и скрылся за углом)
					duration = 20 * 1000;
					startSpeed = 0.0;
					endSpeed = 0.7;
					easing = "InQuad";
				};
				{ -- Стоит несколько секунд за кадром (пауза)
					duration = 45 * 1000;
					startSpeed = 0.0;
					endSpeed = 0.0;
					easing = "Linear";
				};
			};
		},
		far = {
			lastTimelineEvent = -1;
			x = 1525.20; y = -1943.89; z = 15.14;
			direction = false;
			head = nil;
			trailers = {};
			timeline = {
				{ -- Стоит несколько секунд за кадром (пауза)
					duration = 55 * 1000;
					startSpeed = 0.0;
					endSpeed = 0.0;
					easing = "Linear";
				};
				{ -- Прибывает (создан - приехал и остановился)
					duration = 20 * 1000;
					startSpeed = 0.8;
					endSpeed = 0.0;
					easing = "OutQuad";
				};
				{ -- Ждет (стоит на месте)
					duration = 15 * 1000;
					startSpeed = 0.0;
					endSpeed = 0.0;
					easing = "Linear";
				};
				{ -- Отбывает (тронулся и скрылся за углом)
					duration = 20 * 1000;
					startSpeed = 0.0;
					endSpeed = 0.7;
					easing = "InQuad";
				};
			};
		}
	};
		
	init = function()
		addEventHandler( "Main.onClientLoad", resourceRoot, LiveLobby.onClientLoad )
	end;
	
	onClientLoad = function()
		
	end;
	
	-- Запустить ботов в лобби
	-- = void
	start = function()
		--Debug.info( 'Live lobby start' )
		
		--[[ ped
		local ped = createPed( 170, 1718.59, -1963.46, 14.12, 90.0 )
		setElementDimension( ped, Lobby.dimension )
		
		setPedAnalogControlState( ped, "forwards", 0.5 )
		setPedAnalogControlState( ped, "walk", 1 )
		--]]
		
		LiveLobby.startTick = getTickCount()
		
		LiveLobby.trains.near.lastTimelineEvent = -1
		LiveLobby.trains.far.lastTimelineEvent = -1
		
		addEventHandler( "onClientPreRender", root, LiveLobby._process )
	end;
	
	-- Вызывается в liveProcess
	_processTrain = function( timeDelta, trainData )
		-- Рассчитываем, какое сейчас событие из timeline происходит
		local timeline = trainData.timeline
		local totalDuration = 0
		for k, v in pairs( timeline ) do
			totalDuration = totalDuration + v.duration
		end
		
		local timelineDelta = timeDelta % totalDuration
		local checkedTime = 0
		
		local currentTimelineEvent = -1
		local eventProgress = 0
		
		for k, v in pairs( timeline ) do
			if ( timelineDelta < checkedTime + v.duration ) then
				eventProgress = 1 - ( checkedTime + v.duration - timelineDelta ) / v.duration
				currentTimelineEvent = k
				break
			end
			checkedTime = checkedTime + v.duration
		end
		
		-- Если номер события изменился (например, прошло по кругу)
		if ( trainData.lastTimelineEvent ~= currentTimelineEvent ) then
			-- Событие изменилось
			if ( currentTimelineEvent == 1 ) then
				-- Начало timeline, создаем поезд заново
				if ( trainData.head ~= nil ) then
					-- Удаляем старый поезд
					for k, v in pairs( trainData.trailers ) do
						destroyElement( v )
					end
					destroyElement( trainData.head )
					trainData.head = nil
					trainData.trailers = {}
				end
				
				-- Создаем поезд
				local train = createVehicle( 538, trainData.x, trainData.y, trainData.z )
				setElementDimension( train, Lobby.dimension )
				setTrainDirection( train, trainData.direction )
				
				local lastTrailer = train
				for i=1,4 do
					local trailer = createVehicle( 570, trainData.x, trainData.y, trainData.z )
					setElementDimension( trailer, Lobby.dimension )
					setTrainDirection( trailer, true )
					attachTrailerToVehicle( lastTrailer, trailer )
					lastTrailer = trailer
					table.insert( trainData.trailers, trailer )
				end
				
				trainData.head = train
			end	
			
			trainData.lastTimelineEvent = currentTimelineEvent
		end
		
		-- Устанавливаем скорость поезду
		local event = timeline[ currentTimelineEvent ] -- eventProgress
		local speed = interpolateBetween( event.startSpeed, 0, 0, event.endSpeed, 0, 0, eventProgress, event.easing )
				
		setTrainSpeed( trainData.head, trainData.direction and speed or -speed )
	end;
	
	-- Обработка движений в LiveLobby (вызывается при onClientPreRender)
	_process = function()
		local timeDelta = getTickCount() - LiveLobby.startTick
		
		LiveLobby._processTrain( timeDelta, LiveLobby.trains.near )
		LiveLobby._processTrain( timeDelta, LiveLobby.trains.far )
	end;
	
	-- Остановить живое лобби
	-- = void
	stop = function()
		--Debug.info( 'Live lobby stop' )
		
		-- Удаляем обработчик
		removeEventHandler( "onClientPreRender", root, LiveLobby._process )
		
		-- Удаляем поезда, если созданы
		if ( LiveLobby.trains.near.head ~= nil ) then
			destroyElement( LiveLobby.trains.near.head )
			LiveLobby.trains.near.head = nil
		end
		if ( LiveLobby.trains.far.head ~= nil ) then
			destroyElement( LiveLobby.trains.far.head )
			LiveLobby.trains.far.head = nil
		end
		for k, v in pairs( LiveLobby.trains.near.trailers ) do
			destroyElement( v )
		end
		LiveLobby.trains.near.trailers = {}
		for k, v in pairs( LiveLobby.trains.far.trailers ) do
			destroyElement( v )
		end
		LiveLobby.trains.far.trailers = {}
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, LiveLobby.init )