--[[
	ScreenToUV
	Позволяет узнать координату UV-развертки элемента (педа, транспорта или объекта)
	через точку на экране (например, выбор с помощью мышки)
--]]

--------------------------------------------------------------------------------
--<[ Модуль ScreenToUV ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
ScreenToUV = {
	status = 0;							-- 0 - бездействуем, 1 - применяем шейдер и захватываем overlay, 2 - рисуем overlay и захватываем отрисованный uv 
	textureName = "*";
	targetElement = nil;
	screenX = 0;
	screenY = 0;
	callbackFunction = nil;
	
	_screenSize = { x = 0; y = 0; };
	
	_overlayScreenSource = nil;
	_mainScreenSource = nil;
	
	_gradientShader = nil;
	
	init = function()
		local sx, sy = guiGetScreenSize()
		ScreenToUV._screenSize = { x = sx; y = sy; }
		ScreenToUV._overlayScreenSource = dxCreateScreenSource( sx, sy )
		ScreenToUV._mainScreenSource = dxCreateScreenSource( sx, sy )
		
		if ( ScreenToUV._overlayScreenSource == false or ScreenToUV._mainScreenSource == false ) then
			Debug.error( "Невозможно создать screenSource" )
			return nil
		end
		
		ScreenToUV._gradientShader = Shader.create( "client/data/shaders/settxt-noshade.fx", 100, 300, true, "all" )
		local t = dxCreateTexture( "client/data/uv.png", "argb", false, "clamp" )
		dxSetShaderValue( ScreenToUV._gradientShader, "Tex0", t )
		
		Main.setModuleLoaded( "ScreenToUV", 1 )
		
		addEventHandler( "Main.onClientLoad", resourceRoot, ScreenToUV.onClientLoad )
	end;
	
	onClientLoad = function()
		Command.add( "uv", "none", "", "", function( cmd, x, y )
			if ( x == nil ) then 
				x = ScreenToUV._screenSize.x / 2
			else
				x = tonumber( x )
			end
			
			if ( y == nil ) then 
				y = ScreenToUV._screenSize.y / 2
			else
				y = tonumber( y )
			end
			
			
			local status = ScreenToUV.get( x, y, "vehiclegrunge256", nil, function( uvX, uvY )
				Chat.addMessage( tostring( uvX ) .. " " .. tostring( uvY ) )
			end )
			
			if ( not status ) then
				Chat.addMessage( "Модуль занят" )
			end
		end )
		
		-- Debug
		addEventHandler( "onClientRender", root, function()
			dxDrawImage( ScreenToUV._screenSize.x / 2, 0, ScreenToUV._screenSize.x, ScreenToUV._screenSize.y, ScreenToUV._mainScreenSource )
			
			dxDrawRectangle( ScreenToUV.screenX - 2, ScreenToUV.screenY - 2, 4, 4, 0xFF0000FF )
			dxDrawRectangle( ScreenToUV._screenSize.x / 2 + ( ScreenToUV.screenX - 2 ), ScreenToUV.screenY - 2, 4, 4, 0xFF0000FF )
		end, false, "low-1" )
	end;
	
	-- Возвращает UV-координаты в callbackFunction (на следующий фрейм после вызова): callbackFunction( x, y )
	-- Если позиция экрана находится за пределами необходимой UV-развертки, в callbackFunction не будут переданы аргументы
	-- Возвращает true, если функция будет выполнена, в противном случае false (если модуль занят получением предыдущего запроса)
	get = function( screenX, screenY, textureName, element, callbackFunction )
		if ( ScreenToUV.status == 0 ) then
			if not validVar( screenX, "screenX", "number" ) then return nil end
			if not validVar( screenY, "screenY", "number" ) then return nil end
			if not validVar( textureName, "textureName", "string" ) then return nil end
			if not validVar( element, "element", { "element", "nil" } ) then return nil end
			if not validVar( callbackFunction, "callbackFunction", "function" ) then return nil end
		
			ScreenToUV.screenX = screenX
			ScreenToUV.screenY = screenY
			ScreenToUV.targetElement = element
			ScreenToUV.textureName = textureName
			ScreenToUV.callbackFunction = callbackFunction
			
			ScreenToUV.status = 1
			
			setFogDistance( 200 )
			setSunColor( 0, 0, 0, 0, 0, 0 )
			setSkyGradient( 0, 0, 0, 0, 0, 0 )
			
			addEventHandler( "onClientRender", root, ScreenToUV._handle )
			
			return true
		else
			return false
		end
	end;
	
	_handle = function()
		if ( ScreenToUV.status == 1 ) then
			setFPSLimit( Main.fpsLimit * 2 )
			
			engineApplyShaderToWorldTexture( ScreenToUV._gradientShader, ScreenToUV.textureName, ScreenToUV.targetElement, true )
			dxUpdateScreenSource( ScreenToUV._overlayScreenSource, true )
			ScreenToUV.status = 2
		elseif ( ScreenToUV.status == 2 ) then
			setFPSLimit( Main.fpsLimit )
			dxUpdateScreenSource( ScreenToUV._mainScreenSource, true )
			engineRemoveShaderFromWorldTexture( ScreenToUV._gradientShader, "*" )
			
			dxDrawImage( 0, 0, ScreenToUV._screenSize.x, ScreenToUV._screenSize.y, ScreenToUV._overlayScreenSource )
			
			removeEventHandler( "onClientRender", root, ScreenToUV._handle )
			
			local pixels = dxGetTexturePixels( ScreenToUV._mainScreenSource, ScreenToUV.screenX, ScreenToUV.screenY, 1, 1 )
			local r, g, b = dxGetPixelColor( pixels, 0, 0 )
			
			Debug.info( r, g, b )
	
			if ( b == 0 ) then
				ScreenToUV.callbackFunction( r / 255, g / 255 )
			else
				ScreenToUV.callbackFunction( nil )
			end
			
			ScreenToUV.status = 0
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------

};
addEventHandler( "onClientResourceStart", resourceRoot, ScreenToUV.init )