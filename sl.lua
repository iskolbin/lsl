-- Lua Stream Library
-- by Ilya Kolbin (iskolbin@gmail.com)
-- many ideas taken from Luafun library (see https://github.com/rtsisyk/luafun)
--
-- Common usage pattern is: sl.<generator>:<transform>:<transform>...:<fold>
-- For example: sl.iter{1,2,3,4,5}:map( sl'x+1' ):filter( sl'odd?' ):sum() -- evals to 3+5=8
-- 
-- Library functions is very efficient when used in LuaJIT.
-- In LuaJIT performance is close to handwritten low-level code with for loops and if-s.
-- In vanilla Lua performace is not so good, but reasonable. 
-- Main advantage is small memory overhead because collections are not copied on every transformation,
-- instead small stateful generators are created.
--
-- Addtionaly includes some useful functions for chained inplace array/table transorfmations.
--
-- For small functions its possible to use string lambdas like sl'x+2' or sl'x<1'.
-- There is some predefinied string functions like sl'+' or sl'>' or sl'even?'.
-- 
-- Simple yet powerful match function included for structural pattern matching.
-- Variables and wildcards are supported.
-- (for more powerful lib consider https://github.com/silentbicycle/tamale).
-- 
-- Minimal pretty-printing tostring with recursion handling is included for debugging reasons 
-- (for more powerful lib consider https://github.com/kikito/inspect.lua). 
--
-- Works with Lua 5.1 (and LuaJIT), 5.2, 5.3

local load, unpack = load or loadstring, table.unpack or unpack -- Lua 5.1 compatibility
local getmetatable, setmetatable, select, next, type, pairs, assert = getmetatable, setmetatable, select, next, type, pairs, assert

local Wild = {}
local Rest = {}
local Var = {}
local RestVar = {}

local function equal( itable1, itable2, matchtable )
	if itable1 == itable2 or itable2 == Wild or itable2 == Rest then
		return true
	elseif getmetatable( itable2 ) == Var then
		if not itable2[2] or itable2[2]( itable1 ) then
			if matchtable then
				matchtable[itable2[1]] = itable1
			end
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
					if v == Rest then
						return true
					elseif getmetatable( v ) == RestVar then
						local rest = {itable1[k]}
						for _, v_ in next, itable1, k do
							rest[#rest+1] = v_
						end
						if not v[2] or v[2]( rest ) then
							if matchtable then
								matchtable[v[1]] = rest
							end
							return true
						else
							return false
						end
					elseif itable1[k] == nil or not equal( itable1[k], v, matchtable ) then
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

local TableMt

local Table = {
	sort = function( iarray, cmp )
		table.sort( iarray, cmp )
		return iarray
	end,
 
	shuffle = function( iarray, rand_ )
		local rand = rand_ or math.random
		for i = #iarray, 1, -1 do
			local j = rand( i )
			iarray[j], iarray[i] = iarray[i], iarray[j]
		end
		return iarray
	end,
	
	reverse = function( iarray )
		local n = #iarray
		for i = 1, n/2 do
			iarray[i], iarray[n-i+1] = iarray[n-i+1], iarray[i]
		end
		return iarray
	end,

	indexof = function( iarray, v, cmp )
		if not cmp then
			for i = 1, #iarray do
				if iarray[i] == v then
					return i
				end
			end
		else
			if not type( cmp ) == 'function' then
				error('bad argument #2 to indexof ( function expected for binary search, or nil for linear search )' )
			end

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
	end,
	
	copy = function( itable )
		local otable = setmetatable( {}, TableMt )
		for k, v in pairs( itable ) do
			otable[k] = v
		end
		return otable
	end,

	keyof = function( itable, v_ )
		for k, v in pairs( itable ) do
			if v == v_ then
				return k
			end
		end
	end,
	
	concat = table.concat,
	unpack = table.unpack or unpack,
	setmetatable = function( itable, mt )
		setmetatable( itable, mt )
		return itable
	end,
}

local Generator = {
	apply = function( self, f, arg )
		self[#self+1] = f
		self[#self+1] = arg
		return self
	end,
	
	map = function( self, f_ )
		local function domap( f, ... )
			return true, f( ... )
		end

		return self:apply( domap, f_ )
	end,
	
	filter = function( self, p_ )
		local function dofilter( p, ... )
			if p( ... ) then
				return true, ...
			else
				return false
			end
		end

		return self:apply( dofilter, p_ )
	end,

	zip = function( self, from_ )
		local function dozip( from, k, v, ... )
			if from <= 1 then return true, {k, v, ...}
			elseif from <= 2 then return true, k, {v, ...}
			elseif from <= 3 then return true, k, v, {...}
			else
				local allargs = {...}
				allargs[from+1] = {select( from, ... )}
				allargs[from+2] = nil
				return true, unpack( allargs ) 
			end
		end

		return self:apply( dozip, from_ or 1 )
	end,

	swap = function( self )
		local function doswap( _, x, y, ... )
			return true, y, x, ...
		end

		return self:apply( doswap, false )
	end,

	dup = function( self )
		local function dodup( _, x, ... )
			return true, x, x, ...
		end

		return self:apply( dodup, false )
	end,

	unique = function( self )
		local function dounique( cache, k, ... )
			if not cache[k] then
				cache[k] = true
				return true, k, ...
			else
				return false
			end
		end
		
		return self:apply( dounique, {} )
	end,

	withindex = function( self, init, step )
		local function dowithindex( i, ... )
			local index = i[1]
			i[1] = index + i[2]
			return true, index, ...
		end

		return self:apply( dowithindex, {init or 1, step or 1} )
	end,

	take = function( self, n_ )
		local function dotake( n, ... )
			if n[1] < n[2] then
				n[1] = n[1] + 1
				return true, ...
			end
		end

		return self:apply( dotake, {0, n_} )
	end,

	takewhile = function( self, p_ )
		local function dotakewhile( p, ... )
			if p( ... ) then
				return true, ...
			end
		end

		return self:apply( dotakewhile, p_ )
	end,

	drop = function( self, n_ )
		local function dodrop( n, ... )
			if n[1] < n[2] then
				n[1] = n[1] + 1
				return false
			else
				return true, ...
			end
		end
	
		return self:apply( dodrop, {0,n_} )
	end,

	dropwhile = function( self, p_ )
		local function dodropwhile( p, ... )
			if p[2] and p[1]( ... ) then
				return false
			else
				p[2] = false
				return true, ...
			end
		end

		return self:apply( dodropwhile, {p_,true} )
	end,

	update = function( self, table_ )
		local function doupdate( table, k, v, ... )
			if table[k] then
				return true, k, table[k], ...
			else
				return true, k, v, ...
			end
		end

		return self:apply( doupdate, table_ )
	end,

	delete = function( self, table_ )
		local function dodelete( table, k, ... )
			if not table[k] then
				return true, k, ...
			else
				return false
			end
		end

		return self:apply( dodelete, table_ )
	end,

	each = function( self, f )
		local function doeach( status, ... )
			if status then
				f( ... )
				return doeach( self:next())
			elseif status == false then
				return doeach( self:next())
			end
		end
		
		return doeach( self:next())
	end,

	reduce = function( self, f, acc_ )
		local function doreduce( acc, status, ... )
			if status then
				return doreduce( f(acc, ...), self:next())
			elseif status == false then
				return doreduce( acc, self:next())
			else
				return acc
			end
		end
		
		return doreduce( acc_, self:next())
	end,

	totable = function( self )
		local function tablefold( acc, k, v )
			acc[k] = v
			return acc
		end

		return self:reduce( tablefold, setmetatable( {}, TableMt )) 
	end,
	
	toarray = function( self )
		local function arrayfold( acc, v )
			acc[#acc+1] = v
			return acc
		end

		return self:reduce( arrayfold, setmetatable( {}, TableMt ))
	end,

	sum = function( self, acc_ )
		local function dosum( acc, status, ... )
			if status then
				return dosum( acc + ..., self:next())
			elseif status == false then
				return dosum( acc, self:next())
			else
				return acc
			end
		end
		
		return dosum( acc_ or 0, self:next())
	end,

	count = function( self, p )
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
	end,

	next = function( self )
		return self[1]( self )
	end,
}

local GeneratorMt = {__index = Generator}

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

local function evalrangeargs( init_, limit_, step_ )
	local init, limit, step = init_, limit_, step_
	if not limit then init, limit = init > 0 and 1 or -1, init end
	if not step then step = init < limit and 1 or -1 end
	if (init <= limit and step > 0) or (init >= limit and step < 0) then
		return init, limit, step
	else
		error('bad initial variables for range')
	end
end

local function evalsubargs( table, init_, limit_, step_ )
	local len = #table
	local init, limit, step = init_ or 1, limit_ or len, step_
	if init < 0 then init = len + init + 1 end
	if limit < 0 then limit = len + init + 1 end
	if not step then step = init < limit and 1 or -1 end
	if (init <= limit and step > 0) or (init >= limit and step < 0) then
		return init, limit, step
	else
		error('bad initial variables for generator')
	end
end

local function tostring_( arg, saved_, ident_ )
	local t = type( arg )
	local saved, ident = saved_ or {n = 0, recursive = {}}, ident_ or 0
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
					ret[i] = tostring_( arg[i], saved, ident )
				end
				local tret = {}
				local nt = 0					
				for k, v in pairs(arg) do
					if not ret[k] then
						nt = nt + 1
						tret[nt] = (' '):rep(ident+1) .. tostring_( k, saved, ident + 1 ) .. ' => ' .. tostring_( v, saved, ident + 1 )
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

local Stream = {
	range = function( init_, limit_, step_ )
		local init, limit, step = evalrangeargs( init_, limit_, step_ )
		return setmetatable( {step > 0 and rangenext or rrangenext, init, limit, step}, GeneratorMt )
	end,

	iter = function( table, init_, limit_, step_ )
		local init, limit, step = evalsubargs( table, init_, limit_, step_ )
		return setmetatable( {step > 0 and iternext or riternext, table, init, limit, step}, GeneratorMt ) 
	end,
	
	ipairs = function( table, init_, limit_, step_ ) 
		local init, limit, step = evalsubargs( table, init_, limit_, step_ )
		return setmetatable( {step > 0 and ipairsnext or ripairsnext, table, init, limit, step}, GeneratorMt ) 
	end,
	
	pairs = function( table ) 
		return setmetatable( {pairsnext, table}, GeneratorMt )
	end,
	
	keys = function( table ) 
		return setmetatable( {keysnext, table}, GeneratorMt ) 
	end,
	
	values = function( table ) 
		return setmetatable( {valuesnext, table}, GeneratorMt )
	end,

	wrap = function( table )
		return setmetatable( table, TableMt )
	end,

	tostring = tostring_,

	equal = equal,
	match = function( a, b, ... )
		local acc = {}
		local result = equal( a, b, acc ) 
		if result then
			return setmetatable( acc, TableMt )
		else
			local n = select( '#', ... )
			for i = 1, n do
				acc = next( acc ) == nil and acc or {}
				result = equal( a, select( i, ... ), acc )
				if result then 
					return setmetatable( acc, TableMt )
				end
			end
			return result
		end
	end,
	var = function( str, p ) return setmetatable( {str, p}, Var ) end,
	restvar = function( str, p ) return setmetatable( {str, p}, RestVar ) end,
	_ = Wild,
	___ = Rest,

	ltall = function( a, b )
		local function lt( a_, b_ )
			return a_ < b_
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
	end,
}

Stream.X = Stream.var'X'
Stream.Y = Stream.var'Y'
Stream.Z = Stream.var'Z'
Stream.N = Stream.var( 'N', Operators['number?'] )
Stream.S = Stream.var( 'S', Operators['string?'] )
Stream.R = Stream.restvar'R'

local LambdaCache = setmetatable( {}, {__mode = 'kv'} )

local function lambda( _, k )
	local f = Operators[k] or LambdaCache[k]
	if not f then
		f = assert(load( 'return function(x,y,z,...) return ' .. k .. ' end' ))()
		LambdaCache[k] = f
	end
	return f
end

TableMt = { __index = Table }

setmetatable( Table, {__index = Stream} )

return setmetatable( Stream, {
	__call = lambda,
} )
