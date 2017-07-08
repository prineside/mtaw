--[[ 
	Классы вещей
	itemClass = {
		классВещи = {
			descr 						string 		| f( item )					- Описание
			descrHTML  			nil | 	string 		| f( item )					- Описание в HTML. При nil берется descr
			icon  				nil |	string 		| f( item )					- Файл значка в инвентаре. Если nil, тогда используется название класса
			model  						number 		| f( item )					- Номер модели для дропа
			name 						string 		| f( item )					- Название вещи
			quality				nil	|	number		| f( item )					- Текущее качество (от 0 до 1). Если nil, качество не отображается.
			stack				nil |	number		| f( item )					- Макс. размер стека. Если nil, тогда 1
			tags  				nil | 	table 		| f( item )					- Таблица с тегами { tag = 1, otherTag = 1 }
			texture  			nil | 	texture 	| f( item )					- Текстура для дропа или nil, чтобы не менять	
			params				nil |	table		| f( item )					- Таблица с параметрами, которые будут расширены параметрами отдельной вещи
			guiStats			nil | 	table		| f( item )					- Таблица с данными для GUI { ["Урон"] => { "string", "10.7 hp" }, ["Прочность"] => { "progress", 64, 256 } }
			
			getAdminChestItems	nil | 				| f()						- Таблица с вещами (Item), которые будут добавлены в админ-ящик или nil, чтобы класс вещей не появлялся в ящике
		}
	}
	
	Теги (и их параметры)
		tool ( timesUsed ) 														- Инструмент (ПКМ начинает использование инструмента, если цель подходит)
			herbDisruptor ( herbDisruptType, herbDisruptSpeed ) 				- Позволяет быстрее срывать растения (напр. пшеницу). Type - тип инструмента
		food ( satietyRegen )													- Еда (ПКМ начинает употребление еды)
		grindable ( grindTime, grindResult )									- Может быть перемолото на что-то еще. grindTime - время (мс), необходимое для перемола единицы вещи, grindResult - таблица { class = "класс вещи", params = table, count = number }
		meleeWeapon ( damage )													- Холодное оружие
--]]
ItemClass = {
	-- wheat - необработанная пшеница
	wheat = {
		name = "Пшеница";
		descr = "Необработанная пшеница, прямо из поля. Подлежит дальнейшей очистке для получения зерна пшеницы.";
		model = 5375;
		stack = 64;
		weight = 0.1;
		tags = { grindable = 1; };
		
		params = {
			-- grindable
			grindTime = 5000;
			grindResult = {
				class = "flour";
				params = {};
				count = 1;
			};
		};
		
		getAdminChestItems = function()
			return {
				Item( "wheat", {} )
			}
		end;
	};
	
	-- хлеб 
	bread = {
		name = "Пшеничный хлеб";
		descr = "Выпекается из пшеничной муки, можно съесть";
		model = 5844;
		stack = 8;
		weight = 0.5;
		tags = { food = 1; };
		
		params = {
			-- food
			satietyRegen = 25
		};
		
		guiStats = function( item )
			return {
				-- food
				["Сытость"] = 		{ "string", 		"+" .. item:getParam( "satietyRegen" ) .. "%" };
			}
		end;
		
		getAdminChestItems = function()
			return {
				Item( "bread", {} )
			}
		end;
	};
	
	-- яблоко 
	apple = {
		name = "Яблоко";
		descr = "Красное, спелое, съедобное, не напрягает видеокарту";
		model = 5374;
		stack = 8;
		weight = 0.25;
		tags = { food = 1; };
		
		params = { 
			-- food
			satietyRegen = 10;
		};
		
		guiStats = function( item )
			return {
				-- food
				["Сытость"] = 		{ "string", 		"+" .. item:getParam( "satietyRegen" ) .. "%" };
			}
		end;
		
		getAdminChestItems = function()
			return {
				Item( "apple", {} )
			}
		end;
	};
	
	-- железный серп
	sickle_iron = {
		name = "Железный серп";
		descr = "Позволяет быстро срезать небольшие растения (например, пшеницу)";
		model = 5373;
		stack = 1;
		weight = 0.5;
		tags = { tool = 1; herbDisruptor = 1; meleeWeapon = 1; };
		
		params = {
			-- tool
			timesUsed = 0;
			
			-- herbDisruptor
			herbDisruptType = "sickle";
			herbDisruptSpeed = function( item )
				local q = item:getQuality()
				if ( q > 0.75 ) then
					return 0.25
				else
					return 0.25 + ( ( 0.75 - item:getQuality() ) * 0.5 )
				end
			end;
			
			-- meleeWeapon
			damage = 5;
		};
		
		quality = function( item )
			local quality = 1 - ( item:getParam( "timesUsed" ) / 256 )	-- n использования
			
			if quality > 0 then
				return quality 
			else
				return 0
			end
		end;
		
		guiStats = function( item )
			return {
				-- meleeWeapon
				["Тип инструмента"] = 		{ "string", 		"Сбор растений (серп)" };
				["Скорость работы"] = 		{ "string", 		"x" .. ( math.floor( 1 / item:getParam( "herbDisruptSpeed" ) * 10 ) / 10 ) };
				["Урон (ближний бой)"] = 	{ "string", 		item:getParam( "damage" ) .. " hp" };
				["Состояние"] = 			{ "progress", 		item:getQuality() * 256, 256 };
			}
		end;
		
		getAdminChestItems = function()
			return {
				Item( "sickle_iron", {} );
				Item( "sickle_iron", { timesUsed = 256; } );
			}
		end;
	};
};