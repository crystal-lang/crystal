# Union types

The type of a variable or expression can consist of multiple types. This is called a union type. For example, when assigning to a same variable inside different [if](if.html) branches:

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

## Union types rules

In the general case, when two types `T1` and `T2` are combined, the result is a union `T1 | T2`. However, there are a few cases where the resulting type is a different type.

### Union of classes and structs under the same hierarchy

If `T1` and `T2` are under the same hierarchy, and their nearest common ancestor `Parent` is not `Reference`, `Struct`, `Int`, `Float` nor `Value`, the resulting type is `Parent+`. This is called a virtual type, which basically means the compiler will now see the type as being `Parent` or any of its subtypes.

For example:

```crystal
class Foo
end

class Bar < Foo
end

class Baz < Foo
end

bar = Bar.new
baz = Baz.new

# Here foo's type will be Bar | Baz,
# but because both Bar and Baz inherit from Foo,
# the resulting type is Foo+
foo = rand < 0.5 ? bar : baz
typeof(foo) # => Foo+
```

### Union of tuples of the same size

The union of two tuples of the same size results in a tuple type that has the union of the types in each position.

For example:

```crystal
t1 = {1, "hi"}   # Tuple(Int32, String)
t2 = {true, nil} # Tuple(Bool, Nil)

t3 = rand < 0.5 ? t1 : t2
typeof(t3) # Tuple(Int32 | Bool, String | Nil)
```

### Union of named tuples with the same keys

The union of two named tuples with the same keys (regardless of their order) results in a named tuple type that has the union of the types in each key. The order of the keys will be the ones from the tuple on the left hand side.

For example:

```crystal
t1 = {x: 1, y: "hi"}   # Tuple(x: Int32, y: String)
t2 = {y: true, x: nil} # Tuple(y: Bool, x: Nil)

t3 = rand < 0.5 ? t1 : t2
typeof(t3) # NamedTuple(x: Int32 | Nil, y: String | Bool)
```
