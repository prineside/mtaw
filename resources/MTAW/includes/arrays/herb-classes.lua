-- Типы растений (Herbs)
--[[
	
--]]
ARR.herbClasses = {
	-- 1 - wheat --
	{
		name = "Пшеница";
		alias = "wheat";														-- Для удобства (превращение в Herb)
		disruptionTime = 10000;													-- Время сбора голыми руками
		disruptionToolType = { sickle = 1; };									-- Типы инструментов, которыми можно собрать растение
		growPhases = {															-- Фазы роста
			-- 1 - начальная фаза
			{																	-- Первая фаза (появляется сразу, а не вырастает через время)
				texture = "client/data/herb/wheat-s.png";						-- Файл текстуры, примененный к растению на этой фазе
				
				growTime = function()											-- Время роста до следующей фазы
					return 40000 + math.random( 0, 5000 )
				end;
				disruptionDrop = false;											-- Что выпадет из растения, если его сорвать (false - ничего)
			};
			-- 2 - узкий зеленый куст
			{
				texture = "client/data/herb/wheat-v.png";
				growTime = function()
					return 60000 + math.random( 0, 8000 )
				end;
				disruptionDrop = false;
			};
			-- 3 - широкий зеленый куст
			{
				texture = "client/data/herb/wheat-y.png";
				growTime = function()
					return 90000 + math.random( 0, 10000 )
				end;
				disruptionDrop = false;
			};
			-- 4 - желтый куст
			{
				texture = "client/data/herb/wheat-r.png";
				disruptionDrop = { 												-- Массив вещей, которые выпадут, если сорвать растение
					{ 
						class = "wheat";										-- Класс вещи
						params = {};											-- Параметры вещи
						count = 2;												-- Количество вещей (вариант с обычным числом, т.е. всегда выпадает 2 вещи)
					};
					{
						class = "sickle_iron";
						params = {};
						count = function( disruptionTool )						-- Количество выпадаемых вещей задается функцией. disruptionTool - nil (голые руки) или Item (только если disruptionToolType совпадает с params.herbDisruptType класса вещи)
							if ( math.random( 1, 63 ) == 1 ) then
								return 1
							else
								return 0
							end
						end;
					};
				};
			};
		};
	};
}