# lsl
Lua stream library
many ideas taken from Luafun library (see https://github.com/rtsisyk/luafun)

Common usage pattern is: 
```lua
sl.<generator>:<transform>:<transform>...:<fold>
```

For example: 
```lua
sl.iter{1,2,3,4,5}:map( sl'x+1' ):filter( sl'odd?' ):sum() -- evals to 3+5=8
```

Library functions is very efficient when used in LuaJIT.
In LuaJIT performance is close to handwritten low-level code with for loops and if-s.
In vanilla Lua performace is not so good, but reasonable. 
Main advantage is small memory overhead because collections are not copied on every transformation,
instead small stateful generators are created.

Addtionaly includes some useful functions for chained inplace array/table transorfmations.
For small functions its possible to use string lambdas like **sl'x+2'** or **sl'x<1'**.
There is some predefinied string functions like **sl'+'** or **sl'>'** or **sl'even?'**.

Simple yet powerful **match** function included for __structural pattern matching__.
Variables and wildcards are supported.
(for more powerful lib consider https://github.com/silentbicycle/tamale).
 
Minimal pretty-printing **tostring** with recursion handling is included for debugging reasons 
(for more powerful lib consider https://github.com/kikito/inspect.lua). 

Works with Lua 5.1 (and LuaJIT), 5.2, 5.3.

## Generators
* sl.range( init or limit[, limit=#array, step=1] )
* sl.iter( array[, init=1, limit=#array, step=1] )
* sl.ipairs( array[, init=1, limit=#array, step=1] )
* sl.pairs( table )
* sl.keys( table )
* sl.values( table )

## Transforms
* map( self, f )
* filter( self, p )
* unique( self )
* take( self, n )
* takewhile( self, p )
* drop( self, n )
* dropwhile( self, p )
* update( self, table )
* delete( self, table )
* dup( self )
* swap( self )
* zip( self, from )
* withindex( self[, init=1, step=1] )

## Folds
* reduce( self, f[, acc=0] )
* sum( self[, acc=0] )
* each( self, f )
* count( self[, p=alwaystrue] )
* totable( self )
* toarray( self )

## Special functions
* sl.wrap( table )
* sl.equal( a, b )
* sl.match( a, b[,...] )
* sl.tostring( x )
* sl.ltall( a, b ) -- comparsion of objects of **any** type

## Additional in-place table functions
* sort( table[, cmp=lessthan] )
* reverse( table )
* shuffle( table[, random=math.random] )
* copy( table )
* indexof( table, v[, cmp=nil] )
* keyof( table, v )
* copy( table/array )
* concat
* unpack
* setmetatable

## String operators
* sl'~' -- unary minus ( negation )
* sl'+', sl'-', sl'/', sl'%', sl'^', sl'\*', sl'#', sl'..' -- same as Lua
* sl'//' -- integer division (floor( a/b ))
* sl'++', sl'\--' -- increment/decrement
* sl'and', sl'or', sl'not' -- logical operators
* sl'<', sl'<=', sl'>', sl'>=', sl'==', sl'~=' -- comparsion operators same as Lua

## String predicates
* sl'nil?', sl'number?', sl'boolean?', sl'string?', sl'function?', sl'table?', sl'userdata?', sl'thread?' -- type predicates
* sl'integer?' -- integer predicate: floor( a ) == a

## Wild symbols for matching
* sl'\_' -- wild symbol
* sl'___' -- rest symbol

## Defining captures
* sl.var( name[, predicate] )
* sl.restvar( name[, predicate] )

## Build-in captures
* sl.X
* sl.Y
* sl.Z
* sl.R -- rest
* sl.N -- numbers only
* sl.S -- strings only
* sl.B -- booleans only

## String lambdas
* sl( string )

Example
```lua
print( sl.iter{1,2,3,4}:sum() ) -- 10
print( sl.iter{1,2,3,4}:map( sl'x+1' ):filter( sl'even?' ):toarray() -- {2,4}
```
