# Type restrictions

Type restrictions are type annotations put to method arguments to restrict the types accepted by that method.

```ruby
def add(x : Number, y : Number)
  x + y
end

# Ok
add 1, 2 # Ok

# Error: no overload matches 'add' with types Bool, Bool
add true, false
```

Note that if we had defined `add` without type restrictions, we would also have gotten a compile time error:

```ruby
def add(x, y)
  x + y
end

add true, false
```

The above code gives this compile error:

```
Error in foo.cr:6: instantiating 'add(Bool, Bool)'

add true, false
^~~

in foo.cr:2: undefined method '+' for Bool

  x + y
    ^
```

This is because when you invoke `add`, it is instantiated with the types of the arguments: every method invocation with a different type combination results in a different method instantiation.

The only difference is that the first error message is a little more clear, but both definitions are safe in that you will get a compile time error anyway. So, in general, it's preferable not to specify type restrictions and almost only use them to define different method overloads. This results in more generic, reusable code. For example, if we define a class that has a `+` method but isn't a `Number`, we can use the `add` method that doesn't have type restrictions, but we can't use the `add` method that has restrictions.

Refer to the [type grammar](type_grammar.html) for the notation used in type restrictions.

## self restriction

A special type restriction is `self`:

```ruby
class Person
  def ==(other : self)
    other.name == name
  end

  def ==(other)
    false
  end
end

john = Person.new "John"
another_john = Person.new "John"
peter = Person.new "Peter"

john == another_john #=> true
john == peter #=> false (names differ)
john == 1 #=> false (because 1 is not a Person)
```

In the previous example `self` is the same as writing `Person`. But, in general, `self` is the same as writing the type that will finally own that method, which, when modules are involved, becomes more useful.

As a side note, since `Person` inherits `Reference` the second definition of `==` is not needed, since it's already defined in `Reference`.

Note that `self` always represents a match against an instance type, even in class methods:

```ruby
class Person
  def self.compare(p1 : self, p2 : self)
    p1.name == p2.name
  end
end

john = Person.new "John"
peter = Person.new "Peter"

Person.compare(john, peter) # OK
```

You can use `self.class` to restrict to the Person type. The next section talks about the `.class` suffix in type restrictions.

## Classes as restrictions

Using, for example, `Int32` as a type restriction makes the method only accept instances of `Int32`:

```ruby
def foo(x : Int32)
end

foo 1       # OK
foo "hello" # Error
```

If you want a method to only accept the type Int32 (not instances of it), you use `.class`:

```ruby
def foo(x : Int32.class)
end

foo Int32  # OK
foo String # Error
```

The above is useful for providing overloads based on types, not instances:

```ruby
def foo(x : Int32.class)
  puts "Got Int32"
end

def foo(x : String.class)
  puts "Got String"
end

foo Int32  # prints "Got Int32"
foo String # prints "Got String"
```

## Type restrictions in splats

You can specify type restrictions in splats:

```ruby
def foo(*args : Int32)
end

def foo(*args : String)
end

foo 1, 2, 3       # OK, invokes first overload
foo "a", "b", "c" # OK, invokes second overload
foo 1, 2, "hello" # Error
foo()             # Error
```

When specifying a type, all elements in a tuple must match that type. Additionally, the empty-tuple doesn't match any of the above cases. If you want to support the empty-tuple case, add another overload:

```ruby
def foo
  # This is the empty-tuple case
end
```

## Free variables

If you use a single uppercase letter as a type restriction, the identifier becomes a free variable:

```ruby
def foo(x : T)
  T
end

foo(1)       #=> Int32
foo("hello") #=> String
```

That is, `T` becomes the type that was effectively used to instantiate the method.

A free variable can be used to extract the type parameter of a generic type within a type restriction:

```ruby
def foo(x : Array(T))
  T
end

foo([1, 2])   #=> Int32
foo([1, "a"]) #=> (Int32 | String)
```

To create a method that accepts a type name, rather than an instance of a type, append `.class` to a free variable in the type restriction:

```ruby
def foo(x : T.class)
  Array(T)
end

foo(Int32)  #=> Array(Int32)
foo(String) #=> Array(String)
```

## Free variables in constructors

Free variables allow type inference to be used when creating generic types. Refer to the [Generics](generics.html) section.

