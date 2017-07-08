--------------------------------------------------------------------------------
--<[ Модуль Animation ]>--------------------------------------------------------
--------------------------------------------------------------------------------
Animation = {
	init = function()
		addEventHandler( "Main.onServerLoad", resourceRoot, Animation.onServerLoad )
	end;
	
	onServerLoad = function()
		
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
	-- = void
	play = function( pedElement, block, anim, duration, formula, loop, mirrored, updatePosition, freeze )
		if not validVar( pedElement, "pedElement", { "player", "ped" } ) then return nil end
		if not validVar( block, "block", "string" ) then return nil end
		if not validVar( anim, "anim", "string" ) then return nil end
		if not validVar( duration, "duration", "number" ) then return nil end
		
		if not validVar( formula, "formula", { "string", "nil" } ) then return nil end
		if not validVar( loop, "loop", { "boolean", "nil" } ) then return nil end
		if not validVar( mirrored, "mirrored", { "boolean", "nil" } ) then return nil end
		if not validVar( updatePosition, "updatePosition", { "boolean", "nil" } ) then return nil end
		if not validVar( freeze, "freeze", { "boolean", "nil" } ) then return nil end
		
		if formula == nil then formula = "" end
		if loop == nil then loop = false end
		if mirrored == nil then mirrored = false end
		if updatePosition == nil then updatePosition = true end
		if freeze == nil then freeze = false end
		
		if ( string.find( formula, "!" ) ~= nil ) then
			Debug.error( "Animation formula can't contain character '!'" )
			return nil
		end
		
		local animationArgs = {}
		
		-- Искуственная задержка
		if ( DEBUG_MODE ) then
			table.insert( animationArgs, tostring( getTickCount() - 100 ) )
		else
			table.insert( animationArgs, tostring( getTickCount() ) )
		end
		
		table.insert( animationArgs, block )
		table.insert( animationArgs, anim )
		table.insert( animationArgs, tostring( duration ) )
		table.insert( animationArgs, formula )
		
		table.insert( animationArgs, loop and "1" or "0" )
		table.insert( animationArgs, mirrored and "1" or "0" )
		table.insert( animationArgs, updatePosition and "1" or "0" )
		table.insert( animationArgs, freeze and "1" or "0" )
		
		local animationString = table.concat( animationArgs, "!" )
		
		setElementData( pedElement, "Animation", animationString )
		
		--Debug.info( "Started animation: " .. animationString )
	end;
	
	-- Остановить проигрывание анимации
	-- > ped player / ped
	-- = void
	stop = function( ped )
		if ( getElementData( ped, "Animation" ) ~= false ) then
			setElementData( ped, "Animation", false )
			
			--Debug.info( "Stoped animation" )
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
}
addEventHandler( "onResourceStart", resourceRoot, Animation.init )