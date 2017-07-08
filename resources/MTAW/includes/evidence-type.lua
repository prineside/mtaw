--[[ 
	Типы происшествий (доказательств)
--]]
EvidenceType = {
	disruptHerb = {
		id = 1;
		data = {
			"herbClass"
		};
	};
	
	dropItem = {
		id = 2;
		data = {
			"itemClass"
		};
	};
	
	getInVehicle = {
		id = 3;
		data = {
			"numberPlate", "seat"
		};
	};
	
	getOutOfVehicle = {
		id = 4;
		data = {
			"numberPlate", "seat"
		};
	};
};