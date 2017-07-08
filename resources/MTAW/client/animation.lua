--[[
	duration - время, за которое в formula будет передан статус выполнения от 0 до 1
	formula - функция рассчета позиции анимации. Если не указан, будет ленейная зависимость. Является ключем к _formulas
	loop - будет ли анимация повторяться заново до тех пор, пока ее явно не остановят
	mirrored (только с loop = true) - каждая вторая итерация будет работать обратно (0..1, 1..0, 0..1, ... по умолчанию 0..1, 0..1, ...)
	updatePosition - будет ли анимация изменять позицию педа (например, в анимации ходьбы)
	freeze - не очищать анимацию игроку по ее завершению (анимация останется на 100%), не дает никакого эффекта если loop == true. Если установлен в true, анимацию надо останавливать вручную
	startingDuration - анимация начнется с начальным значением этой продолжительности (т.е. не 0%) (используется для компенсации задержки с сервером). Значение меньше 0 и больше duration (если loop == false ) анимацию не запустят (так как она уже закончилась)
--]]

--------------------------------------------------------------------------------
--<[ Общие события ]>-----------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--<[ Внутренние события ]>------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--<[ Модуль Animation ]>--------------------------------------------------------
--------------------------------------------------------------------------------
Animation = {
	_formulas = {
		["x0.9"] = function( x, i ) return x * 0.9 end;
		["x0.8"] = function( x, i ) return x * 0.8 end;
		["x0.75"] = function( x, i ) return x * 0.75 end;
		["x0.5"] = function( x, i ) return x * 0.5 end;
	};

	peds = {};																	-- Текущие анимации в процессе. ped => данные об анимации

	init = function()
		addEventHandler( "Main.onClientLoad", resourceRoot, Animation.onClientLoad )
	end;
	
	onClientLoad = function()
		-- Прием данных об анимации из сервера
		addEventHandler( "onClientElementDataChange", root, Animation.onElementDataChange )
		addEventHandler( "onClientElementStreamIn", root, Animation.onElementStreamIn )
		addEventHandler( "onClientElementStreamOut", root, Animation.onClientElementStreamOut )
		
		-- Обработка
		addEventHandler( "onClientPreRender", root, Animation.onClientPreRender )
	end;
	
	----
	
	-- Играет ли анимация в данный момент
	-- > pedElement ped/player - игрок или пед, которого проверяем
	-- = bool isPlaying
	isPlaying = function( pedElement )
		return Animation.peds[ pedElement ] ~= nil
	end;
	
	-- Проиграть анимацию на игроке или педе
	-- > pedElement ped/player - игрок или пед, который будет проигрывать анимацию
	-- > block string - блок анимации (txd), из которого будет взята анимация
	-- > anim string - название анимации внутри блока
	-- > duration number - продолжительность (мс) анимации
	-- > formula string / nil - формула, по которой вычисляется текущий кадр анимации (пример: return 1 - math.pow( x - 1, 2 ))
	-- > loop bool / nil - должна ли анимация бесконечно повторяться до тех пор, пока ее явно не остановят
	-- > mirrored bool / nil - должна ли каждая 2-я итерация начинаться с конца (если loop == true). Если mirrored == false, анимация будет проигрываться у 2 раза дольше (сначала от 0 до 1, потом от 1 до 0)
	-- > updatePosition bool / nil - будет ли обновляться позиция педа или игрока в соответствии с анимацией
	-- > freeze bool / nil - не очищать анимацию игроку по ее завершению (анимация останется на 100%), не дает никакого эффекта если loop == true. Если установлен в true, анимацию надо останавливать вручную
	-- > timeOffset number / nil - начать проигрывание анимации с этого времени (>=0, <= duration)
	-- = void
	play = function( pedElement, block, anim, duration, formula, loop, mirrored, updatePosition, freeze, timeOffset )
		if not validVar( pedElement, "pedElement", { "player", "ped" } ) then return nil end
		if not validVar( block, "block", "string" ) then return nil end
		if not validVar( anim, "anim", "string" ) then return nil end
		if not validVar( duration, "duration", "number" ) then return nil end
		
		if not validVar( formula, "formula", { "string", "nil" } ) then return nil end
		if not validVar( loop, "loop", { "boolean", "nil" } ) then return nil end
		if not validVar( mirrored, "mirrored", { "boolean", "nil" } ) then return nil end
		if not validVar( updatePosition, "updatePosition", { "boolean", "nil" } ) then return nil end
		if not validVar( freeze, "freeze", { "boolean", "nil" } ) then return nil end
		if not validVar( timeOffset, "timeOffset", { "number", "nil" } ) then return nil end
		
		if loop == nil then loop = false end
		if mirrored == nil then mirrored = false end
		if updatePosition == nil then updatePosition = true end
		if freeze == nil then freeze = false end
		if timeOffset == nil or timeOffset < 0 then timeOffset = 0 end
		
		local data = {}
		
		data.clientStartTick = getTickCount()
		data.block = block
		data.anim = anim
		data.duration = duration
		data.formula = formula
		data.loop = loop
		data.mirrored = mirrored
		data.updatePosition = updatePosition
		data.freeze = freeze
		data.timeOffset = timeOffset
		
		Animation.peds[ pedElement ] = data
		
		setPedAnimation( pedElement, block, anim, -1, false, updatePosition, true, false )
	end;
	
	-- Остановить анимацию. Если freeze установлен в true, пед останется в том же положении (на последнем кадре)
	-- > pedElement ped / player
	-- > freeze bool / nil - остановить анимацию на последнем пригранном кадре
	-- = void
	stop = function( pedElement, freeze )
		if freeze == nil then freeze = false end
		
		if ( Animation.isPlaying( pedElement ) ) then
			if ( not freeze ) then
				setPedAnimation( pedElement )
			end
			Animation.peds[ pedElement ] = nil
		end
	end;
	
	-- Обработать element data "Animation" (внутреннее использование)
	_handleElementData = function( pedElement )
		local animationString = getElementData( source, "Animation" )
		
		if ( animationString == false ) then
			-- Animation не установлено - остановить анимацию
			if ( Animation.isPlaying( source ) ) then
				Animation.stop( source )
			end
		else
			-- Animation установлено - проигрывать анимацию
			local args = explode( "!", animationString )
			
			local serverStartTick = tonumber( args[ 1 ] )
			local timeOffset = Time.getServerTickCount() - serverStartTick
			local block = args[ 2 ]
			local anim = args[ 3 ]
			local duration = tonumber( args[ 4 ] )
			local formula 
			
			if ( args[ 5 ]:len() == 0 ) then
				formula = nil 
			else
				formula = args[ 5 ]
				if ( Animation._formulas[ formula ] == nil ) then
					Debug.error( "Formula " .. tostring( formula ) .. " not found" )
					formula = nil
				end
			end
			
			local loop = ( args[ 6 ] == "1" )
			local mirrored = ( args[ 7 ] == "1" )
			local updatePosition = ( args[ 8 ] == "1" )
			local freeze = ( args[ 9 ] == "1" )
			
			Animation.play( pedElement, block, anim, duration, formula, loop, mirrored, updatePosition, freeze, timeOffset )
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Обработка анимации
	onClientPreRender = function()
		for pedElement, data in pairs( Animation.peds ) do
			local running = true
			
			local animatedTime = getTickCount() - data.clientStartTick
			
			-- Компенсация задержки (чтобы не начиналось резко среди анимации, на время задержки скорость x2)
			if ( data.timeOffset ~= 0 ) then
				if ( animatedTime < data.timeOffset ) then
					-- Еще не прошло время задержки
					animatedTime = animatedTime * 2
				else
					-- Прошло время задержки
					animatedTime = animatedTime + data.timeOffset
				end
			end
			
			if ( animatedTime >= data.duration ) then
				-- Анимация выполняется больше, чем продолжительность
				if ( not data.loop ) then
					-- Выполняется один раз
					if ( data.mirrored ) then
						-- Туда и обратно (duration x2)
						if ( data.duration * 2 < animatedTime ) then
							-- Выполняется дольше, чем duration x2, останавливаем
							Animation.stop( pedElement )
							running = false
						end
					else
						-- Не зеркальная анимация и выполняется один раз - останавливаем
						if ( data.freeze ) then
							-- Оставляем последний кадр
							Animation.stop( pedElement, true )
						else
							-- Очищаем анимацию
							Animation.stop( pedElement )
						end
						running = false
					end
				end
			end
			
			if ( running ) then
				-- Еще не остановили
				local iteration = math.ceil( animatedTime / data.duration )
				local iterationTime = animatedTime % data.duration
				local mainProgress = iterationTime / data.duration
				
				
				if ( data.mirrored and iteration % 2 == 0 ) then
					-- Парная итерация, идет обратно
					mainProgress = 1 - mainProgress
				end
				
				-- Формула
				if ( data.formula ~= nil ) then
					mainProgress = Animation._formulas[ data.formula ]( mainProgress, iteration )
				end
				
				-- Debug.info( "Time: " .. animatedTime, "Progress: " .. mainProgress, "Iteration: " .. iteration, "Iteration time: " .. iterationTime )
				
				if ( getPedAnimation( pedElement ) == false ) then
					setPedAnimation( pedElement, data.block, data.anim, -1, false, data.updatePosition, true, false )
				end
				setPedAnimationProgress( pedElement, data.anim, mainProgress )
			end
		end
	end;
	
	-- Изменились данные какого-то элемента
	onElementDataChange = function( dataName, oldValue )
		if ( dataName == "Animation" ) then
			-- Данные относятся к анимации
			Animation._handleElementData( source )
		end		
	end;
	
	-- Какой-то элемент попал в зону стрима
	onElementStreamIn = function()
		if ( getElementData( source, "Animation" ) ~= false ) then
			-- Есть какие-то данные об анимации
			Animation._handleElementData( source )
		end
	end;
	
	-- Какой-то элемент вышел из стрима
	onClientElementStreamOut = function()
		-- Если на элементе проигрывается анимация, останавливаем
		if ( Animation.isPlaying( source ) ) then
			Animation.stop( source )
		end
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, Animation.init )