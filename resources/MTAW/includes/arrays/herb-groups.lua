-- Группы, в которых растут Herbs
--[[
	name - имя группы
	colshapePolygonPoints - массив точек, по которым будет создан полигон колизии
	minX, minY, maxX, maxY - AABB в котором содержится группа (для рейкастов)
	herbInterval - интервал размещения растений по умолчанию (в действительности может быть другим), используется в FarmGenerator если явно не указан
--]]
ARR.herbGroups = {
	-- 1 --
	{
		name = "Юго-запад Blueberry";
		colshapePolygonPoints = { -230.6205, 103.7228, -244.1080, 78.4407, -264.4731, 17.1020, -273.7693, -18.5044, -278.0028, -39.7959, -277.0237, -54.6032, -267.5380, -67.7393, -240.1999, -80.2981, -209.4575, -85.6979, -181.3048, -84.0003, -168.5245, -61.1902, -121.1846, 59.5874, -142.9913, 70.0879, -200.4069, 92.6661 };
		minX = -280;
		minY = -87;
		maxX = -120;
		maxY = 105;
		centerX = -230;
		centerY = 103;
		herbInterval = 1;
	};
	-- 2 --
	{
		name = "Северо-запад Blueberry";
		colshapePolygonPoints = { -99.7580, 150.3669, -117.2960, 95.1018, -141.8857, 101.4360, -186.7770, 119.5226, -216.6105, 141.9657, -202.6325, 177.0847, -183.7753, 176.6900 };
		minX = -218;
		minY = 94;
		maxX = -98;
		maxY = 179;
		centerX = -99;
		centerY = 150;
		herbInterval = 1;
	};
	-- 3 --
	{
		name = "Юго-восток Blueberry";
		colshapePolygonPoints = { -50.4663, -108.5783, -45.0040, -87.7043, -29.0669, -37.0507, -11.1481, 2.4041, 18.5887, -30.5645, 28.7618, -44.0904, 43.5422, -68.3991, 55.6080, -97.3806, 44.6540, -115.4444, 27.1381, -121.3265, -21.4548, -114.0402 };
		minX = -51;
		minY = -122;
		maxX = 56;
		maxY = 3;
		centerX = -50;
		centerY = -108;
		herbInterval = 1;
	};
	-- 4 --
	{
		name = "Северо-восток Blueberry";
		colshapePolygonPoints = { 8.7723, 36.4598, 8.7723, 36.4598, 18.6202, 66.4862, 35.1501, 60.5932, 80.5498, 26.2556, 77.2665, -15.4477, 71.3821, -48.1232, 40.3049, -7.6298, 23.0436, 10.8636 };
		minX = 7;
		minY = -50;
		maxX = 82;
		maxY = 68;
		centerX = 8;
		centerY = 36;
		herbInterval = 1;
	};
}