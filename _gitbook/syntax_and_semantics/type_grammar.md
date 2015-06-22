# Type grammar

When:

* specifying [type restrictions](type_restrictions.html)
* specifying [type arguments](generics.html)
* [declaring variables](declare_var.html)
* declaring [aliases](alias.html)
* declaring [typedefs](type.html)
* the argument of an [is_a?](is_a.html) pseudo-call
* the argument of an [as](as.html) expression
* the argument of a [sizeof](sizeof.html) expression
* the argument of an [instance_sizeof](instance_sizeof.html) expression
* a method's [return type](return_types.html)

a convenient syntax is provided for some common types. These are especially useful when writing [C bindings](c_bindings/index.html), but can be used in any of the above locations.

## Paths and generics

Regular types and generics can be used:

```ruby
Int32
My::Nested::Type
Array(String)
```

## Union

```ruby
alias Int32OrString = Int32 | String
```

The pipe (`|`) in types creates a union type. `Int32 | String` is read "Int32 or String". In regular code, `Int32 | String` means invoking the method `|` on `Int32` with `String` as an argument.

## Nilable

```ruby
alias Int32OrNil = Int32?
```

is the same as:

```ruby
alias Int32OrNil = Int32 | ::Nil
```

In regular code, `Int32?` is a syntax error.

## Pointer

```ruby
alias Int32Ptr = Int32*
```

is the same as:

```ruby
alias Int32 = Pointer(Int32)
```

In regular code, `Int32*` means invoking the `*` method on `Int32`.

## StaticArray

```ruby
alias Int32_8 = Int32[8]
```

is the same as:

```ruby
alias Int32_8 = StaticArray(Int32, 8)
```

In regular code, `Int32[8]` means invoking the `[]` method on `Int32` with `8` as an argument.

## Tuple

```ruby
alias Int32StringTuple = {Int32, String}
```

is the same as:

```ruby
alias Int32StringTuple = Tuple(Int32, String)
```

In regular code, `{Int32, String}` is a tuple instance containing `Int32` and `String` as its elements. This is different than the above tuple **type**.

## Proc

```ruby
alias Int32ToString = Int32 -> String
```

is the same as:

```ruby
alias Int32ToString = Proc(Int32, String)
```

To specify a Proc without arguments:

```ruby
alias ProcThatReturnsInt32 = -> Int32
```

To specify multiple arguments:

```ruby
alias Int32AndCharToString = Int32, Char -> String
```

For nested procs (and any type, in general), you can use parentheses:

```ruby
alias ComplexProc = (Int32 -> Int32) -> String
```

In regular code `Int32 -> String` is a syntax error.

## self

`self` can be used in the type grammar to denote a `self` type. Refer to the [type restrictions](type_restrictions.html) section.

## class

`class` is used to refer to a class type, instead of an instance type.

For example:

```ruby
def foo(x : Int32)
  "instance"
end

def foo(x : Int32.class)
  "class"
end

foo 1     # "instance"
foo Int32 # "class"
```

`class` is also useful for creating arrays and collections of class type:

```ruby
class Parent
end

class Child1 < Parent
end

class Child2 < Parent
end

ary = [] of Parent.class
ary << Child1
ary << Child2
```

## Underscore

An underscore is allowed in type restrictions. It matches anything:

```ruby
# Same as not specifying a restriction, not very useful
def foo(x : _)
end

# A bit more useful: any two arguments Proc that returns an Int32:
def foo(x : _, _ -> Int32)
end
```

## typeof

`typeof` is allowed in the type grammar. It returns a union type of the type of the passed expressions:

```ruby
alias SameAsInt32 = typeof(1 + 2)
alias Int32OrString = typeof(1, "a")
```
