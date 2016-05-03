# Generics

Generics allow to parameterize a type based on other type. Consider a Box type:

```crystal
class MyBox(T)
  def initialize(@value : T)
  end

  def value
    @value
  end
end

int_box = MyBox(Int32).new(1)
int_box.value # => 1 (Int32)

string_box = MyBox(String).new("hello")
string_box.value # => "hello" (String)

another_box = MyBox(String).new(1) # Error, Int32 doesn't match String
```

Generics are specially useful for implementing collection types. `Array`, `Hash`, `Set` are generic type. `Pointer` too.

More than one type argument is allowed:

```crystal
class MyDictionary(K, V)
end
```

Only single letter names are allowed as names of type arguments.

## Type variables inference

Type restrictions in a generic type's constructor are free variables when type arguments were not specified, and then are used to infer them. For example:

```crystal
MyBox.new(1)       # : MyBox(Int32)
MyBox.new("hello") # : MyBox(String)
```

In the above code we didn't have to specify the type arguments of `MyBox`, the compiler inferred them following this process:

* `MyBox.new(value)` delegates to `initialize(@value : T)`
* `T` doesn't exist, so it's used as a free var
* Because `MyBox` is actually `MyBox(T)`, and `T` is both a free variable and a type argument, `T` becomes the type of the passed value

In this way generic types are less tedious to work with.

## Generic structs and modules

Structs and modules can be generic too. When a module is generic you include it like this:

```crystal
module Moo(T)
  def t
    T
  end
end

class Foo(U)
  include Moo(U)

  def initialize(@value : U)
  end
end

foo = Foo.new(1)
foo.t # Int32
```

Note that in the above example `T` becomes `Int32` because `Foo.new(1)` makes `U` become `Int32`, which in turn makes `T` become `Int32` via the inclusion of the generic module.

## Generic types inheritance

Generic classes and structs can be inherited. When inheriting you can specify an instance of the generic type, or delegate type variables:

```crystal
class Parent(T)
end

class Int32Child < Parent(Int32)
end

class GenericChild(T) < Parent(T)
end
```
