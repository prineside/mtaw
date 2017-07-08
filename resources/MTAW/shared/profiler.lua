--[[
	Profiler
	Исследование производительности
--]]

--------------------------------------------------------------------------------
--<[ Модуль Profiler ]>---------------------------------------------------------
--------------------------------------------------------------------------------
Profiler = {
	init = function()
		Debug.info( "Profiler init" )
	end;
};
addEventHandler( "onResourceStart", resourceRoot, Profiler.init )
addEventHandler( "onClientResourceStart", resourceRoot, Profiler.init )