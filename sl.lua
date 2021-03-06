-- Lua Stream Library
-- by Ilya Kolbin (iskolbin@gmail.com)

local loadstring, unpack = loadstring or load, unpack or table.unpack -- Lua 5.1 compatibility
local getmetatable, setmetatable, select, next, type, pairs, assert = getmetatable, setmetatable, select, next, type, pairs, assert

local Wild = {}
local Rest = {}
local Var = {}
local RestVar = {}
local TableMt
local GeneratorMt
local PredicateDispatchMt

local function equal( itable1, itable2 )
	if itable1 == itable2 or itable2 == Wild or itable2 == Rest then
		return true
	elseif getmetatable( itable2 ) == Var then
		return not itable2[2] or itable2[2]( itable1 )
	else
		local t1, t2 = type( itable1 ), type( itable2 )
		if t1 == t2 and t1 == 'table' then
			local k1, k2 = next( itable1 ), next( itable2 )

			while k1 ~= nil and k2 ~= nil do
				k1, k2 = next( itable1, k1 ), next( itable2, k2 )
			end

			local last2 = itable2[#itable2]
			if (k1 == nil and k2 == nil) or last2 == Rest or getmetatable( last2 ) == RestVar then
				for k, v in pairs( itable2 ) do
					local v1 = itable1[k]
					if v1 ~= v then
						if v == Rest then
							return true
						elseif getmetatable( v ) == RestVar then
							if v[2] then
								local rest = {v1}
								for _, v_ in next, itable1, k do
									rest[#rest+1] = v_
								end
								return v[2]( rest )
							else
								return true
							end
						elseif itable1[k] == nil or not equal( v1, v ) then
							return false
						end
					end
				end
				return true
			else
				return false
			end
		else
			return false
		end
	end
end

local function match( itable1, itable2, matchtable )
	if itable1 == itable2 or itable2 == Wild or itable2 == Rest then
		return true
	elseif getmetatable( itable2 ) == Var then
		if not itable2[2] or itable2[2]( itable1 ) then
			matchtable[itable2[1]] = itable1
			return true
		else
			return false
		end
	else
		local t1, t2 = type( itable1 ), type( itable2 )
		if t1 == t2 and t1 == 'table' then
			local n1 = 0; for _, _ in pairs( itable1 ) do n1 = n1 + 1 end
			local n2 = 0; for _, _ in pairs( itable2 ) do n2 = n2 + 1 end
			local last2 = itable2[#itable2]
			local mt2 = getmetatable( last2 )
			if n1 == n2 or last2 == Rest or mt2 == RestVar then
				for k, v in pairs( itable2 ) do
					local v1 = itable1[k]
					if v == Rest then
						return true
					elseif getmetatable( v ) == RestVar then
						local rest = {v1}
						for _, v_ in next, itable1, k do
							rest[#rest+1] = v_
						end
						if not v[2] or v[2]( rest ) then
							matchtable[v[1]] = rest
							return true
						else
							return false
						end
					elseif itable1[k] == nil or not match( v1, v, matchtable ) then
						return false
					end
				end
				return true
			else
				return false
			end
		else
			return false
		end
	end
end

local Table = {}

function Table.sort( iarray, cmp )
	table.sort( iarray, cmp )
	return iarray
end
 
function Table.shuffle( iarray, rand )
	rand = rand or math.random
	for i = #iarray, 1, -1 do
		local j = rand( i )
		iarray[j], iarray[i] = iarray[i], iarray[j]
	end
	return iarray
end
	
function Table.reverse( iarray )
	local n = #iarray
	for i = 1, n/2 do
		iarray[i], iarray[n-i+1] = iarray[n-i+1], iarray[i]
	end
	return iarray
end

function Table.indexof( iarray, v, cmp )
	if not cmp then
		for i = 1, #iarray do
			if iarray[i] == v then
				return i
			end
		end
	else
		assert( type( cmp ) == 'function', 'bad argument #2 to indexof ( function expected for binary search, or nil for linear search )' )

		local init, limit = 1, #iarray
		local floor = math.floor
		while init <= limit do
			local mid = floor( 0.5*(init+limit))
			local v_ = iarray[mid]
			if v == v_ then return mid
			elseif cmp( v, v_ ) then limit = mid - 1
			else init = mid + 1
			end
		end
	end
end
	
function Table.keyof( itable, u )
	for k, v in pairs( itable ) do
		if v == u then
			return k
		end
	end
end

function Table.copy( itable )
	local otable = setmetatable( {}, TableMt )
	for k, v in pairs( itable ) do
		otable[k] = v
	end
	return otable
end

	
Table.concat = table.concat

Table.unpack = table.unpack or unpack

Table.setmetatable = setmetatable

local Generator = {}

function Generator.apply( self, f, arg )
	self[#self+1] = f
	self[#self+1] = arg
	return self
end
	
function Generator.map( self, f )
	local function domap( g, ... )
		return true, g( ... )
	end

	return self:apply( domap, f )
end
	
function Generator.filter( self, p )
	local function dofilter( pred, ... )
		if pred( ... ) then
			return true, ...
		else
			return false
		end
	end

	return self:apply( dofilter, p )
end

function Generator.zip( self, from )
	local function dozip( frm, k, v, ... )
		if frm <= 1 then return true, {k, v, ...}
		elseif frm <= 2 then return true, k, {v, ...}
		elseif frm <= 3 then return true, k, v, {...}
		else
			local allargs = {...}
			allargs[frm+1] = {select( frm, ... )}
			allargs[frm+2] = nil
			return true, unpack( allargs ) 
		end
	end

	return self:apply( dozip, from or 1 )
end

function Generator.swap( self )
	local function doswap( _, x, y, ... )
		return true, y, x, ...
	end

	return self:apply( doswap, false )
end

function Generator.dup( self )
	local function dodup( _, x, ... )
		return true, x, x, ...
	end

	return self:apply( dodup, false )
end

function Generator.unique( self )
	local function dounique( cache, k, ... )
		if not cache[k] then
			cache[k] = true
			return true, k, ...
		else
			return false
		end
	end

	return self:apply( dounique, {} )
end

function Generator.withindex( self, init, step )
	local function dowithindex( i, ... )
		local index = i[1]
		i[1] = index + i[2]
		return true, index, ...
	end

	return self:apply( dowithindex, {init or 1, step or 1} )
end

function Generator.take( self, n )
	local function dotake( m, ... )
		if m[1] < m[2] then
			m[1] = m[1] + 1
			return true, ...
		end
	end

	return self:apply( dotake, {0, n} )
end

function Generator.takewhile( self, p )
	local function dotakewhile( pred, ... )
		if pred( ... ) then
			return true, ...
		end
	end

	return self:apply( dotakewhile, p )
end

function Generator.drop( self, n )
	local function dodrop( m, ... )
		if m[1] < m[2] then
			m[1] = m[1] + 1
			return false
		else
			return true, ...
		end
	end

	return self:apply( dodrop, {0,n} )
end

function Generator.dropwhile( self, p )
	local function dodropwhile( pred, ... )
		if pred[2] and pred[1]( ... ) then
			return false
		else
			pred[2] = false
			return true, ...
		end
	end

	return self:apply( dodropwhile, {p,true} )
end

function Generator.update( self, itable )
	local function doupdate( tbl, k, v, ... )
		if tbl[k] then
			return true, k, tbl[k], ...
		else
			return true, k, v, ...
		end
	end

	return self:apply( doupdate, itable )
end

function Generator.delete( self, itable )
	local function dodelete( tbl, k, ... )
		if not tbl[k] then
			return true, k, ...
		else
			return false
		end
	end

	return self:apply( dodelete, itable )
end

function Generator.each( self, f )
	local function doeach( status, ... )
		if status then
			f( ... )
			return doeach( self:next())
		elseif status == false then
			return doeach( self:next())
		end
	end

	return doeach( self:next())
end

function Generator.reduce( self, f, acc )
	local function doreduce( accum, status, ... )
		if status then
			return doreduce( f(accum, ...), self:next())
		elseif status == false then
			return doreduce( accum, self:next())
		else
			return accum
		end
	end

	return doreduce( acc, self:next())
end

function Generator.totable( self )
	local function tablefold( acc, k, v )
		acc[k] = v
		return acc
	end

	return self:reduce( tablefold, setmetatable( {}, TableMt )) 
end
	
function Generator.toarray( self )
	local function arrayfold( acc, v )
		acc[#acc+1] = v
		return acc
	end

	return self:reduce( arrayfold, setmetatable( {}, TableMt ))
end

function Generator.sum( self, acc )
	local function dosum( accum, status, ... )
		if status then
			return dosum( accum + ..., self:next())
		elseif status == false then
			return dosum( accum, self:next())
		else
			return accum
		end
	end

	return dosum( acc or 0, self:next())
end

function Generator.count( self, p )
	local function docount( acc, status, ... )
		if status == nil then
			return acc
		elseif status and (p == nil or p(...)) then
			return docount( acc + 1, self:next())
		else
			return docount( acc, self:next())
		end
	end

	return docount( 0, self:next())
end

function Generator.next( self )
	return self[1]( self )
end


local function reccall( self, i, status, ... )
	if status then
		if self[i] then
			return reccall( self, i+2, self[i]( self[i+1], ... ))
		else
			return status, ...
		end
	else
		return status
	end
end

local function iternext( self )
	local index = self[3]
	local value = self[2][index]
	if value ~= nil and index <= self[4] then
		self[3] = index + self[5]
		return reccall( self, 6, true, value ) 
	end
end

local function ipairsnext( self )
	local index = self[3]
	local value = self[2][index]
	if value ~= nil and index <= self[4] then
		self[3] = index + self[5]
		return reccall( self, 6, true, index, value ) 
	end
end

local function riternext( self )
	local index = self[3]
	local value = self[2][index]
	if value ~= nil and index >= self[4] then
		self[3] = index + self[5]
		return reccall( self, 6, true, value ) 
	end
end

local function ripairsnext( self )
	local index = self[3]
	local value = self[2][index]
	if value ~= nil and index >= self[4] then
		self[3] = index + self[5]
		return reccall( self, 6, true, index, value ) 
	end
end

local function pairsnext( self )
	local key, value = next( self[2], self.k )
	if key ~= nil then
		self.k = key
		return reccall( self, 3, true, key, value )
	end
end

local function keysnext( self )
	local key, _ = next( self[2], self.k )
	if key ~= nil then
		self.k = key
		return reccall( self, 3, true, key )
	end
end

local function valuesnext( self )
	local key, value = next( self[2], self.k )
	if key ~= nil then
		self.k = key
		return reccall( self, 3, true, value )
	end
end

local function rangenext( self )
	local index = self[2]
	if index <= self[3] then
		self[2] = index + self[4]
		return reccall( self, 5, true, index )
	end
end

local function rrangenext( self )
	local index = self[2]
	if index >= self[3] then
		self[2] = index + self[4]
		return reccall( self, 5, true, index )
	end
end

local Operators = {
	['~'] = function( a ) return -a end,
	['+'] = function( a, b ) return a + b end,
	['-'] = function( a, b ) return a - b end,
	['*'] = function( a, b ) return a * b end,
	['/'] = function( a, b ) return a / b end,
	['%'] = function( a, b ) return a % b end,
	['^'] = function( a, b ) return a ^ b end,
	['//'] = function( a, b ) return math.floor( a / b ) end,
	['++'] = function( a ) return a + 1 end,
	['--'] = function( a ) return a - 1 end,
	['and'] = function( a, b ) return a and b end,
	['or'] = function( a, b ) return a or b end,
	['not'] = function( a ) return not a end,
	['#'] = function( a ) return #a end,
	['..'] = function( a, b ) return a .. b end,
	['<'] = function( a, b ) return a < b end,
	['<='] = function( a, b ) return a <= b end,
	['=='] = function( a, b ) return a == b end,
	['~='] = function( a, b ) return a ~= b end,
	['>'] = function( a, b ) return a > b end,
	['>='] = function( a, b ) return a >= b end,
	['nil?'] = function( a ) return a == nil end,
	['zero?'] = function( a ) return a == 0 end,
	['positive?'] = function( a ) return a > 0 end,
	['negative?'] = function( a ) return a < 0 end,
	['even?'] = function( a ) return a % 2 == 0 end,
	['odd?'] = function( a ) return a % 2 ~= 0 end,
	['number?'] = function( a ) return type( a ) == 'number' end,
	['integer?'] = function( a ) return type( a ) == 'number' and math.floor( a ) == a end,
	['boolean?'] = function( a ) return type( a ) == 'boolean' end,
	['string?'] = function( a ) return type( a ) == 'string' end,
	['function?'] = function( a ) return type( a ) == 'function' end,
	['table?'] = function( a ) return type( a ) == 'table' end,
	['userdata?'] = function( a ) return type( a ) == 'userdata' end,
	['thread?'] = function( a ) return type( a ) == 'thread' end,
	['id?'] = function( a ) return type( a ) == 'string' and a:match('^[%a_][%w_]*') ~= nil end,
	['empty?'] = function( a ) return next( a ) == nil end,
}

local function evalrangeargs( init, limit, step )
	if not limit then init, limit = init > 0 and 1 or -1, init end
	if not step then step = init < limit and 1 or -1 end
	if (init <= limit and step > 0) or (init >= limit and step < 0) then
		return init, limit, step
	else
		error('bad initial variables for range')
	end
end

local function evalsubargs( table, init, limit, step )
	local len = #table
	init, limit = init or 1, limit or len
	if init < 0 then init = len + init + 1 end
	if limit < 0 then limit = len + init + 1 end
	if not step then step = init < limit and 1 or -1 end
	if (init <= limit and step > 0) or (init >= limit and step < 0) then
		return init, limit, step
	else
		error('bad initial variables for generator')
	end
end

local function tostringx( arg, saved, ident )
	local t = type( arg )
	saved, ident = saved or {n = 0, recursive = {}}, ident or 0
	if t == 'nil' or t == 'boolean' or t == 'number' or t == 'function' or t == 'userdata' or t == 'thread' then
		return tostring( arg )
	elseif t == 'string' then
		return ('%q'):format( arg )
	else
		if saved[arg] then
			saved.recursive[arg] = true
			return '<table rec:' .. saved[arg] .. '>'
		else
			saved.n = saved.n + 1
			saved[arg] = saved.n
			local mt = getmetatable( arg )
			if mt ~= nil and mt.__tostring then
				return mt.__tostring( arg )
			else
				local ret = {}
				local na = #arg
				for i = 1, na do
					ret[i] = tostringx( arg[i], saved, ident )
				end
				local tret = {}
				local nt = 0					
				for k, v in pairs(arg) do
					if not ret[k] then
						nt = nt + 1
						tret[nt] = (' '):rep(ident+1) .. tostringx( k, saved, ident + 1 ) .. ' => ' .. tostringx( v, saved, ident + 1 )
					end
				end
				local retc = table.concat( ret, ',' )
				local tretc = table.concat( tret, ',\n' )
				if tretc ~= '' then
					tretc = '\n' .. tretc
				end
				return '{' .. retc .. ( retc ~= '' and tretc ~= '' and ',' or '') .. tretc .. (saved.recursive[arg] and (' <' .. saved[arg] .. '>}') or '}' )
			end
		end
	end
end

local Stream = {}

function Stream.range( init, limit, step )
	init, limit, step = evalrangeargs( init, limit, step )
	return setmetatable( {step > 0 and rangenext or rrangenext, init, limit, step}, GeneratorMt )
end

function Stream.iter( table, init, limit, step )
	init, limit, step = evalsubargs( table, init, limit, step )
	return setmetatable( {step > 0 and iternext or riternext, table, init, limit, step}, GeneratorMt ) 
end

function Stream.ipairs( table, init, limit, step ) 
	init, limit, step = evalsubargs( table, init, limit, step )
	return setmetatable( {step > 0 and ipairsnext or ripairsnext, table, init, limit, step}, GeneratorMt ) 
end

function Stream.pairs( table ) 
	return setmetatable( {pairsnext, table}, GeneratorMt )
end

function Stream.keys ( table ) 
	return setmetatable( {keysnext, table}, GeneratorMt ) 
end

function Stream.values( table ) 
	return setmetatable( {valuesnext, table}, GeneratorMt )
end

function Stream.wrap( table )
	return setmetatable( table, TableMt )
end

Stream.tostring = tostringx

Stream.equal = equal

function Stream.match( a, b, ... )
	local acc = {}
	local result = match( a, b, acc ) 
	if result then
		return setmetatable( acc, TableMt )
	else
		local n = select( '#', ... )
		for i = 1, n do
			acc = next( acc ) == nil and acc or {}
			result = match( a, select( i, ... ), acc )
			if result then 
				return setmetatable( acc, TableMt )
			end
		end
		return result
	end
end

function Stream.var( str, p ) 
	return setmetatable( {str, p}, Var ) 
end

function Stream.restvar( str, p ) 
	return setmetatable( {str, p}, RestVar ) 
end

function Stream.ltall( a, b )
	local function lt( x, y )
		return x < y
	end

	local ok, res = pcall( lt, a, b )
	if ok then
		return res
	else
		local t1, t2 = type( a ), type( b )
		if t1 ~= t2 then
			return t1 < t2
		else
			return tostring( a ) < tostring( b )
		end
	end
end

Stream._ = Wild
Stream.___ = Rest
Stream.X = Stream.var'X'
Stream.Y = Stream.var'Y'
Stream.Z = Stream.var'Z'
Stream.N = Stream.var( 'N', Operators['number?'] )
Stream.S = Stream.var( 'S', Operators['string?'] )
Stream.B = Stream.var( 'B', Operators['boolean?'] )
Stream.R = Stream.restvar'R'

local LambdaCache = setmetatable( {}, {__mode = 'kv'} )

local function lambda( _, k )
	local f = Operators[k] or LambdaCache[k]
	if not f then
		f = assert(loadstring( 'return function(x,y,z,...) return ' .. k .. ' end' ))()
		LambdaCache[k] = f
	end
	return f
end

local PredicateDispatchFunctions = {}

function Stream.dispatch( name )
	return PredicateDispatchFunctions[name] or setmetatable( {}, PredicateDispatchMt )
end

local PredicateDispatch = {}

function PredicateDispatch.def( self, predicates, func, meta )
	local fs = PredicateDispatchFunctions[self]
	if not fs then
		PredicateDispatchFunctions[self] = {{predicates,func,meta or false}}
	else
		local n = #fs
		for i = 1, n do
			if equal( predicates, fs[i] ) then
				if meta and meta.override then
					fs[i] = {predicates,func,meta or false}
					return self
				else
					error( 'Override ' .. tostringx( self ) .. ' with same predicates ' .. tostringx( predicates ))
				end
			end
			
			if meta then
				if meta.before and equal( predicates, meta.before ) then
					table.insert( PredicateDispatchFunctions[self], i, {predicates,func,meta or false} )
					return self
				end

				if meta.after and equal( predicates, meta.after ) then
					table.insert( PredicateDispatchFunctions[self], i+1, {predicates,func,meta or false} )
					return self
				end
			end
		end
		
		fs[n+1] = {predicates,func,meta}
	end
	return self
end

local function callPredicateDispatch( self, ... )
	local fs = PredicateDispatchFunctions[self]
	for i = 1, #fs do
		local f = fs[i]
		if equal( {...}, f[1] ) then
			return f[2]( ... )
		end
	end
	error( 'No appropriate function implementation found!' .. '\nFunc:' .. tostringx( self ) .. '\nArgs:' .. tostringx(...) )
end

PredicateDispatchMt = {
	__index = PredicateDispatch, 
	__call = callPredicateDispatch
}

GeneratorMt = {__index = Generator}
TableMt = { __index = Table }

setmetatable( Table, {__index = Stream} )

return setmetatable( Stream, {
	__call = lambda,
} )
