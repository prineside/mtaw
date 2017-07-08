-- Текстура кожи и одержа ped'ов и игроков
-- 0 - мужской скин, 1-300 - женские
-- Пока что только мужской

--<[ Модуль Skin ]>
Skin = {
	peds = {};
	textures = {};
	
	init = function()
		Main.setModuleLoaded( "Skin", 1 )
	end;
	
	getTexture = function( texturePath, cb )
		
	end;
	
	----------------------------------------------------------------------------
	
	setSkinColor = function( ped, skinColor )
	
	end;
	
	setFatLevel = function( ped, fatLevel )
	
	end;
	
	setMuscleLevel = function( ped, muscleLevel )
	
	end;
	
	----------------------------------------------------------------------------
	
	setHead = function( ped, model, texture )
	
	end;
	
	setHat = function( ped, model, texture )
	
	end;
	
	setGlasses = function( ped, model, texture )
	
	end;
	
	setNecklace = function( ped, model, texture )
	
	end;
	
	setShirt = function( ped, model, texture )
	
	end;
	
	setShoes = function( ped, model, texture )
	
	end;
	
	setTrousers = function( ped, model, texture )
	
	end;
	
	setWatch = function( ped, model, texture )
	
	end;
	
	-- index = 4-12
	setTattoo = function( ped, index, texture )
	
	end;
	
	-- Удалить все данные о скине и очистить память
	clear = function( ped )
	
	end;
};
addEventHandler( "onClientResourceStart", resourceRoot, Skin.init )