local sl = require'sl'

local function assertq( a, b )
	if not sl.equal( a, b ) then
		print('FAIL')
		print( sl.tostring( a ) )
		print('NOT EQUAL TO')
		print( sl.tostring( b ))
		assert( nil )
	end
end

assert( not sl.equal( {1,2,3,4,5,6}, {1,2,3,sl._,8,9} ), 'equal function is broken!')
assertq( 1, 1 )
assertq( {1,2}, {1,2} )
assertq( {1,2,x = 1}, {1,2,x = 1} )
assertq( {1,2,3,4}, {1,2,sl._,4} )
assertq( {1,2,3,4,5,6}, {1,2,3,sl.___} )
assertq( {1,2,3,4,5,6}, {1,2,3,sl._,5,sl._} )
assertq( {1,2,3,4,5,6,7}, {1,2,sl._,4,5,sl.___} )

assertq( sl.range(10):toarray(), {1,2,3,4,5,6,7,8,9,10} )
assertq( sl.range(2,10):toarray(), {2,3,4,5,6,7,8,9,10} )
assertq( sl.range(3,10,3):toarray(), {3,6,9} )
assertq( sl.range(5,1):toarray(), {5,4,3,2,1} )
assertq( sl.range(10,1,-3):toarray(),{10,7,4,1} )
assertq( sl.range(-5):toarray(), {-1,-2,-3,-4,-5} )

assertq( sl.iter{2,4,6,8,10}:toarray(), {2,4,6,8,10} )
assertq( sl.iter{2,4,6,8,10}:map(sl'x+1'):toarray(), {3,5,7,9,11} )
assertq( sl.iter{2,4,6,8,10}:filter(sl'x<10'):toarray(), {2,4,6,8} )
assertq( sl.iter{1,2,3,4,5,6,7,8,9,10}:filter(sl'even?'):toarray(), {2,4,6,8,10} )
assertq( sl.iter{1,2,3,4,5,6,7}:map(sl'x^2'):filter(sl'odd?'):toarray(), {1,9,25,49} )
assertq( sl.iter{1,2,3,4,5,6,7}:reduce( sl'*', 1 ), 1*2*3*4*5*6*7 )
assertq( sl.iter{1,2,3,4,5,6,7}:sum(), 1+2+3+4+5+6+7 )
assertq( sl.iter{1,1,1,1,2,2,4,4,3,3,6,6}:unique():toarray(), {1,2,4,3,6} )
assertq( sl.iter{2,4,6,8}:withindex():zip():toarray(), {{1,2},{2,4},{3,6},{4,8}} )
assertq( sl.iter{2,4,6,8}:withindex(-1):zip():toarray(), {{-1,2},{0,4},{1,6},{2,8}} )
assertq( sl.iter{2,4,6,8}:withindex(2,0.5):zip():toarray(), {{2,2},{2.5,4},{3,6},{3.5,8}} )
assertq( sl.iter{0,1,3,6,1}:withindex():zip():toarray(), sl.ipairs{0,1,3,6,1}:zip():toarray())
assertq( sl.iter{2,3,4,5,6,7,8}:take(3):toarray(), {2,3,4} )
assertq( sl.iter{2,3,4,5,6,7,8,5,6,7}:takewhile( sl'x~=5' ):toarray(), {2,3,4} )
assertq( sl.iter{2,3,4,5,6,7,8,5,6,7}:takewhile( sl'x<=6' ):toarray(), {2,3,4,5,6} )
assertq( sl.iter{2,4,6,8}:drop(2):toarray(), {6,8} )
assertq( sl.iter{2,4,6,8,2,4,6,8}:dropwhile( sl'even?' ):toarray(), {} )
assertq( sl.iter{2,4,6,8,2,4,6,8,1,2,3,4}:dropwhile( sl'even?' ):toarray(), {1,2,3,4} )
assertq( sl.iter{2,4,6,8}:delete{[4] = true}:toarray(), {2,6,8} )
assertq( sl.iter{2,4,6,8}:dup():update{[4] = 3, [8] = 1}:swap():toarray(), {2,3,6,1} )
assertq( select( 2, sl.iter{42,3,4,6}:next()), 42 )
assertq( sl.iter{1,3,6,1,3,4,9}:toarray():sort(), {1,1,3,3,4,6,9} )
assertq( sl.iter{1,2,3,4,5}:toarray():reverse(), {5,4,3,2,1} )
assertq( sl.iter{1,9,2,8,3,6,4}:toarray():indexof( 8 ), 4 )
assertq( sl.iter{1,9,2,8,3,6,4}:toarray():sort(sl'<'):indexof( 8 ), 6 )
assertq( sl.iter{1,8,2,8,3,6,4}:toarray():sort(sl'>'):indexof( 8, sl'>' ), 2 )
assertq( sl.iter{1,2,3,4}:swap():swap():sum(), 10 )
assertq( sl.iter({2,4,6,8},2):toarray(), {4,6,8} )
assertq( sl.iter({2,4,6,8},-2):toarray(),{6,8} )
assertq( sl.iter({2,4,6,8,10},1,5,2):toarray(),{2,6,10})
assertq( sl.iter({2,4,6,8,10},-1,1):toarray(),{10,8,6,4,2})
assertq( sl.iter({2,4,5,6},-1):toarray(),{6})
assertq( sl.iter({2,4,6,8,2},2,-1,2):toarray(),{4,8})
assertq( sl.iter{2,3,4,6,9}:count(sl'even?'), 3 )
assertq( sl.iter{2,3,4,5,7}:count(), 5 )
assertq( sl.pairs{x = 3, y = 55, z =23}:count(), 3 )
assertq( sl.pairs{x = 3, y = 55, z =23}:swap():count(sl'x==55'), 1 )
assertq( select(2, sl.iter{7,2,3,4,5}:next()), 7 )

assertq( sl.pairs{x = 22, y = 12}:update{x = 3, y = 4, z = 8}:totable(), {x = 3, y = 4})
assertq( sl.pairs{x = 1, y = 2}:update{x = 4}:totable(), {x = 4, y = 2} )
assertq( sl.pairs{x = 22, y = 12, z = 14}:delete{y = true}:totable(), {x =22, z = 14} )
assertq( sl.pairs{x = 22, z = 14}:delete{y = true}:totable(), {x =22, z = 14} )

local s = 0
sl.iter{1,4,3,2,1,6}:each( function( v ) s = s + v end )
assertq( s, 17 )

assertq( sl.ipairs{2,4,6,8}:zip():toarray(), {{1,2},{2,4},{3,6},{4,8}} )
assertq( sl.ipairs{2,4,6,8}:swap():toarray(), {2,4,6,8} )
--sl.pairs{ x = 3, y = 1, z = 12}:swap():each(print)

assertq( sl.pairs{ x = 3, y = 1, z = 12}:swap():sum(), 16 )
assertq( sl.keys{x = 3, y = 1, z = 12, a = 3, b = 4, c = 9}:toarray():sort(), {'a','b','c','x','y','z'} )
assertq( sl.values{x = 3, y = 1, z = 12, a = 3, b = 4, c = 9}:toarray():sort(), {1,3,3,4,9,12} )
assertq( sl.values{ x= 3, y = 4, z = 3}:swap():swap():sum(), 10 )
assertq( sl.pairs{x = 3, y = 1, z = 12}:totable(), {x = 3, y = 1, z =12 } )
assertq( sl.pairs{[3] = 1, [5] = 6, [2] = 2}:sum(), 10 )

assertq( sl.pairs{x = 3, y = 1, z = 12}:filter( sl'y~=1' ):zip():toarray():sort( sl'x[2]>y[2]' ), {{'z',12},{'x',3}} )

assertq( sl.wrap{1,2,3,4,5}:copy(), {1,2,3,4,5} )

local x = {1,2,3,4}
assert( sl.wrap( x ):copy() ~= x )

local t = {x = 5, y = 2, 1, 2 }
assert( sl.wrap( t ):copy() ~= t )

assertq( sl.wrap( t ):copy(), {x = 5, y = 2, 1, 2 } )
assertq( sl.wrap( t ):keyof( 5 ), 'x' )

print('shuffle')
sl.wrap{1,2,3,4,5,6,7,8}:shuffle(math.random):iter():each(print)

assertq( sl.match({1,2,3,4}, {1,2,sl._,4}), {} )
assertq( sl.match({1,2,3,4}, {1,5,3,sl._}), false )
assertq( sl.match({1,2,3,4}, {1,2,3,sl.var'X'}), {X = 4} )
assertq( sl.match({1,2,3,4}, {1,2,sl.restvar'X'}), {X={3,4}} )

assertq( sl.match({1,2,3,4,5}, {1,2,sl.X,sl.___}), {X=3} )

assertq( sl.match({1,2,3,4,5},
	{2,4,5,7},
	{6,1,sl.___},
	{1,sl.Y,2},
	{1,2,sl._,sl.Z,5,sl.___},
	{1,2,3,4,5}), {Z = 4} )

assertq( sl.wrap{1,'x',5,6,{1}}:sort( sl.ltall ), {1,5,6,'x',{1}} ) 

local N = 30

local factorial = sl.dispatch()

factorial:def( {1}, function( _ )
	return 1
end)

factorial:def( {2}, function( _ )
	return 2*factorial(1)
end)

factorial:def( {sl.N}, function( n )
	return n * factorial( n - 1 )
end)

local t1

t1 = os.clock()
print( factorial( N ))
print( 'Predicate dispatch:', os.clock() - t1 )

local function factTailRec( n, acc )
	if n <= 1 then
		return acc
	else
		return factTailRec( n-1, acc*n )
	end
end

t1 = os.clock()
print( factTailRec( N, 1 ))
print( 'Tail recursive:', os.clock() - t1 )

local function factDirect( n )
	if n <= 1 then
		return 1
	else
		local acc = 1
		for i = 2, n do
			acc = acc * i
		end
		return acc
	end
end

t1 = os.clock()
print( factDirect( N ))
print( 'Direct:', os.clock() - t1 )

print('all passed')
