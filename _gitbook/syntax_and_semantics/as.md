# as

The `as` expression restricts the types of an expression. For example:

```ruby
if some_condition
  a = 1
else
  a = "hello"
end

# a :: Int32 | String
```

In the above code, `a` is a union of `Int32 | String`. If for some reason we are sure `a` is an `Int32` after the `if`, we can force the compiler to treat it like one:

```ruby
a_as_int = a as Int32
a_as_int.abs          # works, compiler knows that a_as_int is Int32
```

The `as` expression performs a runtime check: if `a` wasn't an `Int32`, an [exception](exception_handling.html) is raised.

The argument to the expression is a [type](type_grammar.html).

If it is impossible for a type to be restricted by another type, a compile-time error is issued:

```ruby
1 as String # Error
```

## Converting between pointer types

The `as` expression also allows to cast between pointer types:

```ruby
ptr = Pointer(Int32).malloc(1)
ptr as Int8*                    #:: Pointer(Int8)
```

In this case, no runtime checks are done: pointers are unsafe and this type of casting is usually only needed in C bindings and low-level code.

## Converting between pointer types and other types

Conversion between pointer types and Reference types is also possible:

```ruby
array = [1, 2, 3]

# object_id returns the address of an object in memory,
# so we create a pointer with that address
ptr = Pointer(Void).new(array.object_id)

# Now we cast that pointer to the same type, and
# we should get the same value
array2 = ptr as Array(Int32)
array2.same?(array) #=> true
```

No runtime checks are performed in these cases because, again, pointers are involved. The need for this cast is even more rare than the previous one, but allows to implement some core types (like String) in Crystal itself, and it also allows passing a Reference type to C functions by casting it to a void pointer.

## Usage for casting to a bigger type

The `as` expression can be used to cast an expression to a "bigger" type. For example:

```ruby
a = 1
b = a as Int32 | Float64
b #:: Int32 | Float64
```

The above might not seem to be useful, but it is when, for example, mapping an array of elements:

```ruby
ary = [1, 2, 3]

# We want to create an array 1, 2, 3 of Int32 | Float64
ary2 = ary.map { |x| x as Int32 | Float64 }

ary2 #:: Array(Int32 | Float64)
ary2 << 1.5 # OK
```

The `Array#map` method uses the block's type as the generic type for the Array. Without the `as` expression, the inferred type would have been `Int32` and we wouldn't have been able to add a `Float64` into it.

## Usage for when the compiler can't infer the type of a block

Sometimes the compiler can't infer the type of a block. For example:

```ruby
class Person
  def initialize(@name)
  end

  def name
    @name
  end
end

a = [] of Person
x = a.map { |f| f.name } # Error: can't infer block return type
```

The compiler needs the block's type for the generic type of the Array created by `Array#map`, but since `Person` was never instantiated, the compiler doesn't know the type of `@name`. In this cases you can help the compiler by using an `as` expression:

```ruby
a = [] of Person
x = a.map { |f| f.name as String } # OK
```

This error isn't very frequent, and is usually gone if a `Person` is instantiated before the map call:

```ruby
Person.new "John"

a = [] of Person
x = a.map { |f| f.name as String } # OK
```
