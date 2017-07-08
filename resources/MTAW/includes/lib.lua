--[[
	string					addslashes( string s )
	number					bigger( number val1, number val2 )
	number					charCount( string haystack, char/number needleChar )
	number					clamp( number val, number minVal, number maxVal )
	string					decimalToHex( string dec )
	string					dumpvar( mixed data, [ number maxDepth ] )
	boolean					equals( mixed val1, mixed val2 )
	table					explode( char delimiter, string source )
	string 					fileGetContents( string filePath )
	boolean 				filePutContents( string filePath, string content )
	table					fileReadLines( string filePath )
	number					getAngleBetweenPoints( number x1, number y1, number x2, number y2 )
	number number			getCoordsByAngleFromPoint( number x, number y, number angle, number distance )
	number					getDistanceBetweenPoints2D( number x1, number y1, number x2, number y2 )
	number					getDistanceBetweenPoints3D( number x1, number y1, number z1, number x2, number y2, number z2 )
	number number number	getPositionFromElementOffset( element element, number offX, number offY, number offZ )
	string					implode( string delimiter, table arr )
	boolean					isLeapYear( number year )
	string 					jsonEncode( mixed mixed )
	mixed					jsonDecode( string str )
	string 					ltrim( string str, [ table characters ] )
	number 					normalizeAngleDeg( number a )
	number 					normalizeAngleRad( number a )
	string					number_format( number amount, number decimal, [ string prefix, [ string neg_prefix ], [ string pos_prefix ] ] )
	key value				orderedPairs( table t )
	string					randomString( number length )
	number 					round( number val, [ number decimal ] )
	nil 					shuffle( table t )
	number					smaller( number val1, number val2 )
	[for iterator]			spairs( table, [ function( table, a, b ), которая должна вернуть равенство, например function( t, a, b ) return  t[b] < t[a] end ] )
	string					sql_escape_string( string s )
	table					tableCopy( table tab )
	table					tableEmpty( table t )
	bool					tableIsEmpty( table t )
	number					tableRealSize( table t )
	string					trim( string str, [ table characters ] )
	string					urldecode( string str )
	boolean					validClass( mixed var, string varName, table classTable, [ bool noerror ] )
	boolean					validVar( mixed var, string varName, table/string types, [ bool noerror ] )
--]]

function tableIsEmpty( t )
	return next( t ) == nil
end

local _randomStringChars = { 
	"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", 
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", 
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9" 
}
function randomString( length )
	if length < 1 then return nil end
	
	local array = {}
	for i = 1, length do
		array[i] = _randomStringChars[ math.random( 1, #_randomStringChars ) ]
	end
	
	return table.concat(array)
end

function spairs( t, order )
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function getAngleBetweenPoints( x1, y1, x2, y2 ) -- x1 y1 - позиция центральной точки (относительно которой ищем угол)
	local d1, d2
	d1 = x2 - x1
	d2 = y2 - y1
	if ( d1 <= 0 ) then
		return math.abs( math.deg( math.atan2( d1, d2 ) ) )
	else
		return 360.0 - math.deg( math.atan2( d1, d2 ) )
	end
end

function shuffle( t )
	local its = #t
	local j
	for i = its, 2, -1 do
		j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
end

function fileReadLines( filePath )
	local handle = fileOpen( filePath, true )
	local fileLines = {}
	local lineChars = {}
	
    while not fileIsEOF( handle ) do
		local character = fileRead( handle, 1 )
        local buffer = string.byte( character )
		
		if ( buffer == 10 ) then
			table.insert( fileLines, trim( table.concat( lineChars, "" ) ) )
			lineChars = {}
		else
			table.insert( lineChars, character )
		end
    end
	
	if ( lineChars.length ~= 0 ) then
		table.insert( fileLines, trim( table.concat( lineChars, "" ) ) )
	end
	
	return fileLines
end

-- Deep equals
function equals(v1, v2)
	if v1 == v2 then
	   return true
	end

	if type(v1) ~= type(v2) then
	   return false
	end
	
	if ( type( v1 ) == "table" ) then
		local isEqual = true
		
		for k, v in pairs( v1 ) do
			if ( v2[ k ] == nil ) then
				isEqual = false
				break
			else
				if ( not equals( v, v2[ k ] ) ) then
					isEqual = false
					break
				end
			end
		end
		
		return isEqual
	else
		return false
	end
end

function pack( ... )
	return { n = select("#", ...), ... }
end
	
function bigger( val1, val2 )
	return val1 > val2 and val1 or val2
end

function smaller( val1, val2 )
	return val1 < val2 and val1 or val2
end

function void()
	return nil
end;

function fileGetContents( filePath )
	if ( fileExists( filePath ) ) then
		local handle = fileOpen( filePath, true )
		local data = {}
		
		while not fileIsEOF( handle ) do
			table.insert( data, fileRead( handle, 512 ) )
		end
		
		fileClose( handle )
		
		return table.concat( data )
	else
		return nil
	end
end;

function filePutContents( filePath, content )
	local handle = fileCreate( filePath )
	fileWrite( handle, content )
	fileClose( handle )
	
	return true
end;

function isLeapYear( year )
	if ( year % 4 == 0 ) then
		if ( year % 100 == 0 ) then
			return ( year % 400 == 0 )
		else
			return true
		end
	else
		return false
	end	
end;

function ltrim( str, characters )
	local charset = {}
	if ( characters == nil ) then characters = { "\r", "\n", "\t", " " } end
	for k, v in pairs( characters ) do charset[ string.byte( v ) ] = true end
	
	local trimStart = 1
	for i = 1, #str do if ( charset[ string.byte( str, i ) ] == true ) then trimStart = i + 1 else break end end
	
	return string.sub( str, trimStart )
end;

function decimalToHex( dec )
    local B,K,out,I,D=16,"0123456789abcdef","",0
    while dec>0 do
        I=I+1
        dec,D=math.floor(dec/B),math.mod(dec,B)+1
        out=string.sub(K,D,D)..out
    end
	if ( out == "" ) then out = "0" end
	
    return out
end

function explode( delimiter, source )
	local t, ll
	t={}
	ll=0
	if ( #source == 1 ) then return { source } end
	while true do
		l = string.find( source, delimiter, ll, true )
		if ( l ~= nil ) then
			table.insert( t, string.sub( source, ll, l-1 ) )
			ll = l + 1
		else
			table.insert( t, string.sub( source, ll ) )
			break
		end
	end
	return t
end

function implode( delimiter, arr )
	return table.concat( arr, delimiter ) 
end

function normalizeAngleDeg( a )
	return ( ( a % 360 ) + 360 ) % 360;
end

function normalizeAngleRad( a )
	local pi2 = math.pi * 2
	return ( ( a % pi2 ) + pi2 ) % pi2;
end

function urldecode(str)
	str = string.gsub (str, "+", " ")
	str = string.gsub (str, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)
	str = string.gsub (str, "\r\n", "\n")
	return str
end

function validVar( var, varName, types, noerror )
	if ( type( varName ) ~= "string" ) then 
		return Debug.error( "varName must be a string" )
	end
	if ( type( types ) ~= "string" and type( types ) ~= "table" ) then 
		return Debug.error( "types must be a string or a table" )
	end
	
	if ( type( types ) == "string" ) then
		if ( types == "element" ) then
			if ( isElement( var ) ) then
				return true
			else
				if ( not noerror ) then 
					local msg = varName .. " must be " .. types .. ", "
					if ( isElement( var ) ) then
						msg = msg .. "element " .. getElementType( var )
					else
						msg = msg .. type( var )
					end
					Debug.error( msg .. " given" ) 
				end
				return false
			end
		else
			if ( type( var ) == types ) then
				return true
			else
				if ( isElement( var ) and getElementType( var ) == types ) then
					return true
				else
					if ( not noerror ) then 
						local msg = varName .. " must be " .. types .. ", "
						if ( isElement( var ) ) then
							msg = msg .. "element " .. getElementType( var )
						else
							msg = msg .. type( var )
						end
						Debug.error( msg .. " given" ) 
					end
					return false
				end
			end
		end
	else
		local found = false
		for k, v in pairs( types ) do
			if ( validVar( var, varName, v, true ) ) then
				found = true
				break
			end
		end
		if ( found ) then
			return true
		else
			if ( not noerror ) then
				local msg = varName .. " must be { "
				for k, v in pairs( types ) do
					msg = msg .. v .. " "
				end
				msg = msg .. "}, "
				if ( isElement( var ) ) then
					msg = msg .. "element " .. getElementType( var )
				else
					msg = msg .. type( var ) .. " " .. tostring( tostring( var ) )
				end
				Debug.error( msg .. " given" )
			end
			
			return false
		end
	end
end;

function validClass( var, varName, classTable, noerror )
	if ( type( varName ) ~= "string" ) then 
		return Debug.error( "varName must be a string" )
	end
	if ( type( classTable ) ~= "table" ) then 
		return Debug.error( "classTable must be a table" )
	end
	
	if ( type( var ) == "table" and getmetatable( var ) == classTable ) then
		return true
	else
		if ( not noerror ) then 
			local msg = varName .. " must be an instance of " .. tostring( classTable ) .. ", "
			if ( isElement( var ) ) then
				msg = msg .. "element " .. getElementType( var )
			else
				msg = msg .. type( var ) .. " " .. tostring( tostring( var ) )
			end
			Debug.error( msg .. " given" ) 
		end
		return false
	end
end;

function trim( str, characters )
	local charset = {}
	if ( characters == nil ) then characters = { "\r", "\n", "\t", " " } end
	for k, v in pairs( characters ) do charset[ string.byte( v ) ] = true end
	
	local trimStart = 1
	local trimEnd = #str
	
	for i = 1, #str do if ( charset[ string.byte( str, i ) ] == true ) then trimStart = i + 1 else break end end
	for i = #str, trimStart, -1 do if ( charset[ string.byte( str, i ) ] == true ) then trimEnd = i - 1 else break end end
	
	return string.sub( str, trimStart, trimEnd )
end;

function charCount( haystack, needleChar )
	if ( type( needleChar ) ~= "number" ) then needleChar = string.byte( needleChar ) end
	local c = 0
	for i=1, #haystack do
		if ( string.byte( haystack, i ) == needleChar ) then
			c = c + 1
		end
	end
	return c
end;

function tableCopy( tab, _rl ) -- recursive!
	if ( type( tab ) ~= "table" ) then 
		outputDebugString( "tableCopy - tab must be table, " .. type( tab ) .. " given", 1 )
		return nil 
	end
	
	if _rl == nil then _rl = 0 end
	
	if _rl == 10 then return "Deep recursion" end
	
    local ret = {}
    for key, value in pairs( tab ) do
        if ( type( value ) == "table" ) then ret[ key ] = tableCopy( value, _rl + 1 )
        else ret[ key ] = value end
    end
    return ret
end

function tableRealSize( t )
	if ( type( t ) == "table" ) then
		local c = 0
		for k, v in pairs( t ) do
			c = c + 1
		end
		return c
	end
end

function tableEmpty( t ) 
	for k, _ in pairs( t ) do
		t[ k ] = nil
	end
end

function comma_value( amount )
	local formatted = amount
	while true do  
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if ( k == 0 ) then break end
	end
	return formatted
end

function round( val, decimal )
	if ( decimal ~= nil ) then
		return math.floor( ( val * 10^decimal ) + 0.5 ) / ( 10^decimal )
	else
		return math.floor( val + 0.5 )
	end
end

function number_format( amount, decimal, prefix, neg_prefix, pos_prefix )
	if not validVar( amount, "amount", "number" ) then return nil end
	
	local str_amount, formatted, famount, remain

	if ( not decimal ) then
		if ( math.floor( amount ) ~= amount ) then
			decimal = 2
		else
			decimal = 0
		end
	end
	neg_prefix = neg_prefix or "-"
	pos_prefix = pos_prefix or ""

	famount = math.abs( round( amount, decimal ) )
	famount = math.floor( famount )

	remain = round( math.abs( amount ) - famount, decimal )

	formatted = comma_value( famount )

	if ( decimal > 0 ) then
		remain = string.sub( tostring( remain ),3 )
		formatted = formatted .. "." .. remain .. string.rep( "0", decimal - string.len( remain ) )
	end

	formatted = ( prefix or "" ) .. formatted 

	if ( amount < 0 ) then
		if ( neg_prefix == "()" ) then
			formatted = "(" .. formatted .. ")"
		else
			formatted = neg_prefix .. formatted 
		end
	else
		formatted = pos_prefix .. formatted 
	end

	return formatted
end

function getCoordsByAngleFromPoint( x, y, angle, distance )
	--[[
	local rx, ry
	local angleRad = math.rad( angle )
	if ( math.sin( angleRad ) < 0 ) then
 		rx = x + math.abs( math.sin( angleRad ) ) * distance
	else
		rx = x + ( 0 - math.sin( angleRad ) ) * distance
	end
  	ry = y + ( distance * math.cos( angleRad ) )
	
	return rx, ry
	--]]
	local angleRad = math.rad( angle )
	
	return x - math.sin( angleRad ) * distance, y + ( distance * math.cos( angleRad ) )
end;

function clamp( val, minVal, maxVal )
	if ( val < minVal ) then
		return minVal
	elseif ( val > maxVal ) then
		return maxVal
	else
		return val
	end
end;

function dumpvar(data,maxDepth)
	local tablecache = {}
	local buffer = ""
	local padder = "    "
	if ( not maxDepth ) then maxDepth = 8 end
 
	local function _dumpvar(d, depth)
		if ( depth == maxDepth ) then
			buffer = buffer.."[[Deeper....]]\n"
		else
			local t = type(d)
			local str = tostring(d)
			if (t == "table") then
				if (tablecache[str]) then
					-- table already dumped before, so we dont
					-- dump it again, just mention it
					buffer = buffer.."<"..str..">\n"
				else
					tablecache[str] = (tablecache[str] or 0) + 1
					buffer = buffer.."("..str..") {\n"
					for k, v in pairs(d) do
						buffer = buffer..string.rep(padder, depth+1).."["..tostring(k).."] => "
						_dumpvar(v, depth+1)
					end
					buffer = buffer..string.rep(padder, depth).."}\n"
				end
			elseif (t == "number") then
				buffer = buffer.."("..t..") "..str.."\n"
			else
				buffer = buffer.."("..t..") \""..str.."\"\n"
			end
		end
	end
	_dumpvar(data, 0)
	return buffer
end

function sql_escape_string( s )
	return string.gsub( s, "'", "''" )
end

-- Backslash-escape special characters:
function addslashes(s)
  s = string.gsub(s, "(['\"\\])", "\\%1")
  s = string.gsub(s, "\n", "")
	
  return (string.gsub(s, "%z", "\\0"))
end

-- Используется в jsonEncode
function _cleanCopyForJSON( tab )
	local ret = {}
	for key, value in pairs(tab) do
		if ( type( value ) == "table" ) then 
			ret[ key ] = _cleanCopyForJSON( value )
		elseif ( type( value ) == "userdata" ) then
			ret[ key ] = tostring( value ) 
		elseif ( type( value ) == "function" ) then
			ret[ key ] = tostring( value ) 
		else
			ret[ key ] = value
		end
	end
	return ret
end

function jsonEncode( mixed, fancy )
	if ( fancy == nil ) then fancy = false end

	local jsonString
	
	if ( type( mixed ) == "table" ) then
		jsonString = string.sub( toJSON( _cleanCopyForJSON( mixed ), true ), 2, -2 )
	elseif ( type( mixed ) == "userdata" ) then
		outputDebugString( "Невозможно преобразовать userdata в JSON", 1 )
		return nil
	end
	
	-- Делаем красивый вывод, если указано в аргументе
	if ( fancy ) then
		local fancyJsonString = {}
		local tabSize = 0
		local inStr = false
		
		local originalLen = string.len( jsonString )
		for ptr = 1, originalLen do
			local chr = jsonString:sub( ptr, ptr )
			if ( chr == "\"" ) then
				inStr = not inStr
			end
			
			if ( chr == "{" ) then
				table.insert( fancyJsonString, "{\n" )
				tabSize = tabSize + 1
				for i = 1, tabSize do
					table.insert( fancyJsonString, "\t" )
				end
			elseif ( chr == "}" ) then
				table.insert( fancyJsonString, "\n" )
				tabSize = tabSize - 1
				for i = 1, tabSize do
					table.insert( fancyJsonString, "\t" )
				end
				table.insert( fancyJsonString, "}" )
			elseif ( not inStr and chr == "," ) then
				table.insert( fancyJsonString, ",\n" )
				for i = 1, tabSize do
					table.insert( fancyJsonString, "\t" )
				end
			else
				table.insert( fancyJsonString, chr )
			end
		end
		
		return table.concat( fancyJsonString )
	else
		return jsonString
	end
end

function jsonDecode( str )
	if ( str == "[]" ) then return {} end
	
	return fromJSON( str )
end

function getPositionFromElementOffset( element, offX, offY, offZ )
    local m = getElementMatrix( element, false )  -- Get the matrix
    local x = offX * m[1][1] + offY * m[2][1] + offZ * m[3][1] + m[4][1]  -- Apply transform
    local y = offX * m[1][2] + offY * m[2][2] + offZ * m[3][2] + m[4][2]
    local z = offX * m[1][3] + offY * m[2][3] + offZ * m[3][3] + m[4][3]
    return x, y, z                               -- Return the transformed point
end

-- pairs для table, который проходит по ключам в порядке возростания (сортирует ключи перед выводом)
function __genOrderedIndex( t )
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex )
    return orderedIndex
end

function orderedNext(t, state)
    key = nil
    if state == nil then
        t.__orderedIndex = __genOrderedIndex( t )
        key = t.__orderedIndex[1]
    else
        for i = 1,table.getn(t.__orderedIndex) do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1]
            end
        end
    end

    if key then
        return key, t[key]
    end

    t.__orderedIndex = nil
    return
end

function orderedPairs( t ) -- основная таблица
    return orderedNext, t, nil
end