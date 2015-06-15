# Instance variables type inference

Did you notice that in all of the previous examples we never said the types of a `Person`'s `@name` and `@age`? This is because the compiler inferred them for us.

When we wrote:

```ruby
class Person
  getter name

  def initialize(@name)
    @age = 0
  end
end

john = Person.new "John"
john.name #=> "John"
john.name.length #=> 4
```

Since we invoked `Person.new` with a `String` argument, the compiler makes `@name` be a `String` too.

If we had invoked `Person.new` with another type, `@name` would have taken a different type:

```ruby
one = Person.new 1
one.name #=> 1
one.name + 2 #=> 3
```

If you compile the previous programs with the `hierarchy` command, the compiler will show you a hierarchy graph with the types it inferred. In the first case:

```
- class Object
  |
  +- class Reference
     |
     +- class Person
            @name : String
            @age  : Int32
```

In the second case:

```
- class Object
  |
  +- class Reference
     |
     +- class Person
            @name : Int32
            @age  : Int32
```

What happens if we create two different people, one with a `String` and one with an `Int32`? Let's try it:

```ruby
john = Person.new "John"
one = Person.new 1
```

Invoking the compiler with the `hierarchy` command we get:

```
- class Object
  |
  +- class Reference
     |
     +- class Person
            @name : (String | Int32)
            @age  : Int32
```

We can see that now `@name` has a type `(String | Int32)`, which is read as a *union* of `String` and `Int32`. The compiler made `@name` have all types assigned to it.

In this case, the compiler will consider any usage of `@name` as always being either a `String` or an `Int32` and will give a compile time error if a method is not found for *both* types:

```ruby
john = Person.new "John"
one = Person.new 1

# Error: undefined method 'length' for Int32
john.name.length

# Error: no overload matches 'String#+' with types Int32
john.name + 3
```

The compiler will even give an error if you first use a variable assuming it has a type and later you change that type:

```ruby
john = Person.new "John"
john.name.length
one = Person.new 1
```

Gives this compile-time error:

```
Error in foo.cr:14: instantiating 'Person:Class#new(Int32)'

one = Person.new 1
             ^~~

instantiating 'Person#initialize(Int32)'

in foo.cr:12: undefined method 'length' for Int32

john.name.length
          ^~~~~~
```

That is, the compiler does global type inference and tells you whenever you make a mistake in the usage of a class or method. You can go ahead and put a type restriction like `def initialize(@name : String)`, but that makes the code a bit more verbose and also less generic: everything will work just fine if you create `Person` instance with types that have the same *interface* as a `String`, as long as you use a `Person`'s name like if it were a `String`.

If you do want to have different `Person` types, one with `@name` being an `Int32` and one with `@name` being a `String`, you must use [generics](generics.html).

## Nilable instance variables

If an instance variable is not assigned in all of the `initialize` defined in a class, it will be considered as also having the type `Nil`:

```ruby
class Person
  getter name

  def initialize(@name)
    @age = 0
  end

  def address
    @address
  end

  def address=(@address)
  end
end

john = Person.new "John"
john.address = "Argentina"
```

The hierarchy graph now shows:

```
- class Object
  |
  +- class Reference
     |
     +- class Person
            @name : String
            @age : Int32
            @address : String?
```

You can see `@address` is `String?`, which is a short form notation of `String | Nil`. This means that the following gives a compile time error:

```ruby
# Error: undefined method 'length' for Nil
john.address.length
```

To deal with `Nil`, and generally with union types, you have several options: use an [if var](if_var.html), [if var.is_a?](if_varis_a.html), [case](case.html) and [is_a?](is_a.html).

## Catch-all initialization

Instance variables can also be initialized outside `initialize` methods:

```ruby
class Person
  @age = 0

  def initialize(@name)
  end
end
```

This will initialize `@age` to zero in every constructor. This is useful to avoid duplication, but also to avoid the `Nil` type when reopening a class and adding instance variables to it.

## Specifying the types of instance variables

In certain cases you want to tell the compiler to fix the type of an instance variable. You can do this with `::`:

```ruby
class Person
  @age :: Int32

  def initialize(@name)
    @age = 0
  end
end
```

In this case, if we assign something that's not an `Int32` to `@age`, a compile-time error will be issued at the assignment location.

Note that you still have to initialize the instance variables, either with a catch-all initializer or within an `initialize` method: there are no "default" values for types.
