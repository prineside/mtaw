--------------------------------------------------------------------------------
--<[ Модуль Mapping ]>----------------------------------------------------------
--------------------------------------------------------------------------------
Mapping = {
	loadedMaps = {};
	elementsWithoutDimension = {};
	lastPlayerDimension = nil;
	
	init = function()
		setTimer( Mapping._dimensionChangeListener, 250, 0 )
	end;
	
	-- Загрузить маппинг из файла mapPath
	-- > mapPath string - путь к файлу маппинга (.map)
	-- > dimension number / nil - измерение, в котором будет видно маппинг. Если не указан (nil), маппинг будет виден во всех измерениях
	-- = void
	load = function( mapPath, dimension )
		if not validVar( mapPath, "mapPath", "string" ) then return nil end
		if not validVar( dimension, "dimension", { "number", "nil" } ) then return nil end
		
		if ( Mapping.loadedMaps[ mapPath ] ~= nil ) then
			-- Карта уже загружена, перезагружаем
			Mapping.unload( mapPath )
		end
		
		if ( fileExists( mapPath ) ) then
			local mapElements = {}
		
			local rootNode = xmlLoadFile( mapPath )
			local elementNodes = xmlNodeGetChildren( rootNode )
			
			for _, elementNode in pairs( elementNodes ) do
				local elementName = xmlNodeGetName( elementNode )
				if ( elementName == "object" ) then
					-- object
					local id = xmlNodeGetAttribute( elementNode, "id" )
					local breakable = xmlNodeGetAttribute( elementNode, "breakable" )
					local collisions = xmlNodeGetAttribute( elementNode, "collisions" )
					local alpha = xmlNodeGetAttribute( elementNode, "alpha" )
					local model = xmlNodeGetAttribute( elementNode, "model" )
					local doublesided = xmlNodeGetAttribute( elementNode, "doublesided" )
					local scale = xmlNodeGetAttribute( elementNode, "scale" )
					local posX = xmlNodeGetAttribute( elementNode, "posX" )
					local posY = xmlNodeGetAttribute( elementNode, "posY" )
					local posZ = xmlNodeGetAttribute( elementNode, "posZ" )
					local rotX = xmlNodeGetAttribute( elementNode, "rotX" )
					local rotY = xmlNodeGetAttribute( elementNode, "rotY" )
					local rotZ = xmlNodeGetAttribute( elementNode, "rotZ" )
					
					-- IsLowLod - false?
					local object = createObject( tonumber( model ), tonumber( posX ), tonumber( posY ), tonumber( posZ ), tonumber( rotX ), tonumber( rotY ), tonumber( rotZ ), false )
					mapElements[ object ] = true
					
					if ( dimension == nil ) then
						if ( Mapping.lastPlayerDimension ~= nil ) then
							setElementDimension( object, Mapping.lastPlayerDimension )
						end
						
						Mapping.elementsWithoutDimension[ object ] = true
					else
						setElementDimension( object, dimension )
					end
					
					if ( id ~= false ) then
						setElementID( object, id )
					end
					if ( breakable ~= false ) then
						if ( breakable == "true" ) then
							setObjectBreakable( object, true )
						else
							setObjectBreakable( object, false )
						end
					end
					if ( collisions ~= false ) then
						if ( collisions == "true" ) then
							setElementCollisionsEnabled( object, true )
						else
							setElementCollisionsEnabled( object, false )
						end
					end
					if ( alpha ~= false and alpha ~= "255" ) then
						alpha = tonumber( alpha )
						setElementAlpha( object, alpha )
					end
					if ( scale ~= false ) then
						setObjectScale( object, tonumber( scale ) )
					end
					if ( doublesided ~= false ) then
						if ( doublesided == "true" ) then
							setElementDoubleSided( object, true )
						else
							setElementDoubleSided( object, false )
						end
					end
				end
			end
			
			Mapping.loadedMaps[ mapPath ] = mapElements
			--Debug.info( "Загружен маппинг:", mapPath )
		else
			Debug.error( "Файл маппинга не существует:", mapPath )
		end	
	end;
	
	-- Убрать маппинг, загруженный из указанного файла
	-- > mapPath string - путь к файлу маппинга, который был ранее загружен
	-- = void
	unload = function( mapPath )
		if not validVar( mapPath, "mapPath", "string" ) then return nil end
		
		if ( Mapping.loadedMaps[ mapPath ] ~= nil ) then
			-- Карта загружена, выгружаем
			for object, _ in pairs( Mapping.loadedMaps[ mapPath ] ) do
				Mapping.elementsWithoutDimension[ object ] = nil
				destroyElement( object )
			end
			
			Mapping.loadedMaps[ mapPath ] = nil
		end
	end;
	
	-- Проверяет, в каком сейчас измерении игрок и устанавливает то же измерение всем объектам, которые не имеют явно указанного измерения
	_dimensionChangeListener = function()
		local playerDimension = getElementDimension( localPlayer )
		if ( playerDimension ~= Mapping.lastPlayerDimension ) then
			for e, _ in pairs( Mapping.elementsWithoutDimension ) do
				setElementDimension( e, playerDimension )
			end
		
			Mapping.lastPlayerDimension = playerDimension
		end
	end;
}
addEventHandler( "onClientResourceStart", resourceRoot, Mapping.init )