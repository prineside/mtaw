--[[
	Синхронизирует позицию и вектор поворота камеры игроков
--]]
--------------------------------------------------------------------------------
--<[ Модуль Camera ]>-----------------------------------------------------------
--------------------------------------------------------------------------------
Camera = {
	_lastMatrixData = nil;
	_lastMatrixDataChanged = getTickCount();
	_lastDeltaZ = nil;
	
	init = function()
		addEventHandler( "onClientElementDataChange", root, Camera.onElementDataChanged )
		
		setTimer( Camera._syncCameraWithServer, 200, 0 )
	end;
	
	-- Отправляет на сервер данные о матрице камеры
	_syncCameraWithServer = function()
		local x, y, z, tx, ty, tz = getCameraMatrix()
		if ( not x ) then return nil end
		
		dx = tx - x
		dy = ty - y
		dz = tz - z

		matrixData = string.format( "%0.2f|%0.2f|%0.2f|%0.4f|%0.4f|%0.4f", x, y, z, dx, dy, dz )
		
		if ( Camera._lastDeltaZ ~= dz ) then
			-- Изменилась матрица
			Camera._lastMatrixDataChanged = getTickCount()
			Camera._lastMatrixData = matrixData
			Camera._lastDeltaZ = dz
		else
			-- Матрица не изменилась
			if ( getTickCount() - Camera._lastMatrixDataChanged > 100 ) then
				-- Длительное время не менялась матрица, отправляем на сервер
				triggerServerEvent( "Camera.onClientSync", resourceRoot, matrixData )
			end
		end
	end;
	
	----------------------------------------------------------------------------
	--<[ Обработчики событий ]>-------------------------------------------------
	----------------------------------------------------------------------------
	
	-- Изменились данные какого-то элемента - возможно, это вектор камеры
	onElementDataChanged = function( dataName, oldValue )
		if ( dataName == "_cm" ) then
			local d = getElementData( source, "_cm" )
			if ( d ) then
				local e = explode( "|", d )
				
				local x = tonumber( e[ 1 ] )
				local y = tonumber( e[ 2 ] )
				local z = tonumber( e[ 3 ] )
				local vx = tonumber( e[ 4 ] )
				local vy = tonumber( e[ 5 ] )
				local vz = tonumber( e[ 6 ] )
				
				local tx, ty, tz = x + vx * 1000, y + vy * 1000, z + vz * 1000
				setPedAimTarget( source, tx, ty, tz )
				setPedLookAt( source, tx, ty, tz, -1, 0 )
			end
		end
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Camera.init )