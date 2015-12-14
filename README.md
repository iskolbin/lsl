# lsl
Lua stream library

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

## Additional in-place table functions
* sort( table[, cmp=lessthan] )
* reverse( table )
* shuffle( table[, random=math.random] )
* copy( table )
* indexof( table, v[, cmp=nil] )
* keyof( table, v )
* copy( array )
* tcopy( table )

## String operators
* sl'~' -- unary minus ( negation )
* sl'+', sl'-', sl'/', sl'%', sl'^', sl'\*', sl'#', .. -- same as Lua
* sl'//' -- integer division (floor( a/b ))
* sl'++', sl'\--' -- increment/decrement
* sl'and', sl'or', sl'not' -- logical operators
* sl'<', sl'<=', sl'>', sl'>=', sl'==', sl'~=' -- comparsion operators same as Lua

## String predicates
* sl'nil?', sl'number?', sl'boolean?', sl'string?', sl'function?', sl'table?', sl'userdata?', sl'thread?' -- type predicates
* sl'integer?' -- integer predicate: floor( a ) == a

## String special equal symbols
* sl'\_' -- wild symbol
* sl'...' -- rest symbol

## String lambdas
* sl( string )
