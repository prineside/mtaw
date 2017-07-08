--------------------------------------------------------------------------------
--<[ Модуль GUIBlur ]>----------------------------------------------------------
--------------------------------------------------------------------------------
GUIBlur = {
	elements = {};
	
	init = function()
		exports.BlurBox:setBlurIntensity( 5 )
	end;
	
	-- Возвращает true, если такой Blur уже существует
	-- > id string - идентификатор blur
	-- = bool blurExists
	exists = function( id )
		return GUIBlur.elements[ id ] ~= nil
	end;
	
	-- Установить интенсивность размытия всех Blur
	-- > intensity number
	-- = void
	setIntensity = function( intensity )
		exports.BlurBox:setBlurIntensity( intensity )
	end;
	
	-- Добавить новый блок с размытием
	-- > blurID string - идентификатор, который будет также использован в remove
	-- > x number
	-- > y number
	-- > width number
	-- > height number
	-- > r number / nil - красный оттенок, по умолчанию 255
	-- > g number / nil - зеленый оттенок, по умолчанию 255
	-- > b number / nil - синий оттенок, по умолчанию 255
	-- > a number / nil - прозрачность, по умолчанию 255
	-- > postGUI bool / nil - отрисовывать поверх GUI
	-- = void
	add = function( blurID, x, y, width, height, r, g, b, a, postGUI )
		if not validVar( blurID, "blurID", "string" ) then return nil end
		if not validVar( x, "x", "number" ) then return nil end
		if not validVar( y, "y", "number" ) then return nil end
		if not validVar( width, "width", "number" ) then return nil end
		if not validVar( height, "height", "number" ) then return nil end
		if not validVar( r, "r", { "number", "nil" } ) then return nil end
		if not validVar( g, "g", { "number", "nil" } ) then return nil end
		if not validVar( b, "b", { "number", "nil" } ) then return nil end
		if not validVar( a, "a", { "number", "nil" } ) then return nil end
		if not validVar( postGUI, "postGUI", { "boolean", "nil" } ) then return nil end
	
		if ( r == nil ) then r = 255 end
		if ( g == nil ) then g = 255 end
		if ( b == nil ) then b = 255 end
		if ( a == nil ) then a = 255 end
		if ( postGUI == nil ) then postGUI = false end
		
		if ( GUIBlur.exists( blurID ) ) then
			GUIBlur.remove( blurID )
		end
		
		GUIBlur.elements[ blurID ] = exports.BlurBox:createBlurBox( x, y, width, height, r, g, b, a, postGUI )
	end;
	
	-- Удалить блок с размытием
	-- > blurID string - идентификатор, ранее использованный в add
	-- = void
	remove = function( blurID )
		if ( GUIBlur.elements[ blurID ] ~= nil ) then
			exports.BlurBox:destroyBlurBox( GUIBlur.elements[ blurID ] )
			GUIBlur.elements[ blurID ] = nil
		end
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, GUIBlur.init )