-- Устанавливает гравитацию транспортного средства игрока так, чтобы можно было ездить по любым поверхностям

--------------------------------------------------------------------------------
--<[ Модуль FunGravityVehicle ]>------------------------------------------------
--------------------------------------------------------------------------------
FunGravityVehicle = {
	raycastDistance = 3.0;
	gravityChangeSpeed = 2.5;
	currentGravity = { 0, 0, -1 };
	targetGravity = { 0, 0, -1 };
	
	lastProcessTick = getTickCount();
	
	init = function()
		addEventHandler( "onClientPreRender", root, FunGravityVehicle._process )
	end;
	
	_process = function()
		local veh = getPedOccupiedVehicle( localPlayer )
		if ( veh ~= false ) then 
			local vx, vy, vz = getElementPosition( veh )
			local tx, ty, tz = getPositionFromElementOffset( veh, 0, 0, -FunGravityVehicle.raycastDistance )
			
			local hit, hitX, hitY, hitZ, hitElement, normX, normY, normZ = processLineOfSight( vx, vy, vz, tx, ty, tz, true, true, false, true, true, true, false, true, veh, true, true )
			
			if ( hit ) then
				FunGravityVehicle.targetGravity = { -normX, -normY, -normZ }
			else
				FunGravityVehicle.targetGravity = { 0, 0, -1 }
			end
			
			-- Плавное изменение гравитации
			local cg = FunGravityVehicle.currentGravity
			local tg = FunGravityVehicle.targetGravity
			
			for i=1,3 do
				if ( cg[i] ~= tg[i] ) then
					local delta = ( getTickCount() - FunGravityVehicle.lastProcessTick ) / 1000 * FunGravityVehicle.gravityChangeSpeed
					
					if ( tg[i] > cg[i] ) then
						cg[i] = cg[i] + delta
						if ( cg[i] >= tg[i] ) then
							cg[i] = tg[i]
						end
					else
						cg[i] = cg[i] - delta
						if ( cg[i] <= tg[i] ) then
							cg[i] = tg[i]
						end
					end
				end
			end
			
			setVehicleGravity( veh, cg[1], cg[2], cg[3] )
			
			FunGravityVehicle.lastProcessTick = getTickCount()
		end
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, FunGravityVehicle.init )