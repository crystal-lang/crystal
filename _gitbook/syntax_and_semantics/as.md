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
ptr as Int8                    #:: Pointer(Int8)
```

In this case, no runtime checks are done: pointers are unsafe and this type of casting is usually only needed in C bindings and low-level code.

## Converting between pointer types and other types

Conversion between pointer types and Reference types is also possible:

```ruby
ptr = Pointer(UInt8).malloc(10)
str = ptr as String             #:: String

str as Pointer(Int32)           #:: Pointer(Int32)
```

No runtime checks are performed in these cases because, again, pointers are involved. The need for this cast is even more rare than the previous one, but allows to implement some core types (like String) in Crystal itself, and it also allows passing a Reference type to C functions by casting it to a void pointer.
