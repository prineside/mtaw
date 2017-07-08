--[[
	Отвечает за окружение - погоду, время, цвет неба и прочее
	При спавне персонажа включается, при деспавне выключается
	Не изменять погоду и прочее, когда Environment.isEnabled (можно disable)
--]]

--------------------------------------------------------------------------------
--<[ Модуль Environment ]>------------------------------------------------------
--------------------------------------------------------------------------------
Environment = {
	isEnabled = false;

	init = function()
		addEventHandler( "Character.onCharacterChange", resourceRoot, Environment.onCharacterChange, false, "high" )
		
		--[[ Отрисовка освещения
			Обычно с 6:00 до 7:00 линейно 0=>1, с 20:00 до 21:00 линейно 1=>0
		local lightLevel = {}	-- 1 - 1440
		local lastLightLevel = -1
		addEventHandler( "onClientRender", root, function()
			local x, y, z = getElementPosition( localPlayer )
			local hit, hitX, hitY, hitZ, hitElement, normalX, normalY, normalZ, material,lighting = processLineOfSight( x, y + 2, z, x, y + 2, z - 3, true, false, false, true, true )
		
			local h, m = getTime()
			local idx = h * 60 + m
			
			lightLevel[ idx ] = lighting
			
			local coeff = 1000 / 1440
			
			for i = 1, 1440 do
				if ( lightLevel[ i ] ~= nil ) then
					local v = lightLevel[ i ] * 100
					dxDrawRectangle( 12 + i * coeff, 500 - v, 1, v, 0xFF44AAFF, true )
				end
			end
			
			for i = 1,23 do
				dxDrawText( tostring( i ) .. ":00", i * 60 * coeff, 380 )
				dxDrawRectangle( 12 + i * 60 * coeff, 400, 1, 100, 0xFFFFFFFF, true )
			end
			
			dxDrawText( string.format( "Lighting: %0.3f, time: %02d:%02d", lighting, h, m ), 5, 600 )
		end	)
		--]]
	end;
	
	-- Включить синхронизацию окружения (погоды и прочего)
	-- = void
	enable = function()
		Environment.isEnabled = true
		
		-- Применение текущих настроек
		setFogDistance( CFG.graphics.fogDistance )
		setFarClipDistance( CFG.graphics.farClipDistance )
		resetSkyGradient()
		resetSunColor()
	end;
	
	-- Отключить синхронизацию окружения. Полезно, если нужно установить свою погоду, цвет неба и прочее
	-- = void
	disable = function()
		Environment.isEnabled = false
	end;
	
	-- Возвращает текущую яркость от 0 до 1 
	-- 0 - самая глубокая ночь, 1 - самый яркий день
	-- = number lightIntensity
	getDayLightIntensity = function()
		local h, m = getTime()
		if ( h == 6 ) then
			-- 6-7 утра
			return m / 60
		elseif ( h == 20 ) then
			-- 20-21 вечера
			return 1 - ( m / 60 )
		elseif ( h > 6 and h < 21 ) then
			-- День (7 утра - 20 вечера)
			return 1
		else
			-- Ночь (21 вечера - 6 утра)
			return 0
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Изменился текущий персонаж игрока
	onCharacterChange = function()
		-- Когда есть персонаж, окружение работает
		if ( not Character.isSelected() ) then
			Environment.disable()
		else
			Environment.enable()
		end
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, Environment.init )