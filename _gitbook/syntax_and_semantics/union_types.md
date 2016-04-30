# Union types

The type of a varaible or expression can consist of multiple types. This is called a union type. For example, when assigning to a same variable inside different [if](if.html) branches:

```crystal
if 1 + 2 == 3
  a = 1
else
  a = "hello"
end

a # : Int32 | String
```

At the end of the if, `a` will have the `Int32 | String` type, read "the union of Int32 and String". This union type is created automatically by the compiler. At runtime, `a` will of course be of one type only. This can be seen by invoking the `class` method:

```crystal
# The runtime type
a.class # => Int32
```

The compile-time type can be seen by using [typeof](typeof.html):

```crystal
# The compile-time type
typeof(a) # => Int32 | String
```

A union can consist of an arbitrary large number of types. When invoking a method on an expression whose type is a union type, all types in the union must respond to the method, otherwise a compile-time error is given. The type of the method call is the union type of the return types of those methods.

```crystal
# to_s is defined for Int32 and String, it returns String
a.to_s # => String

a + 1 # Error, because String#+(Int32) isn't defined
```
