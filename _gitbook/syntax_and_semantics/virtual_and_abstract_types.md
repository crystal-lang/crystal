# Virtual and abstract types

When a variable's type combines different types under the same class hierarchy, its type becomes a **virtual type**. This applies to every class except for `Reference`. An example:

```ruby
class Animal
end

class Dog < Animal
  def talk
    "Woof!"
  end
end

class Cat < Animal
  def talk
    "Miau"
  end
end

class Person
  getter pet

  def initialize(@name, @pet)
  end
end

john = Person.new "John", Dog.new
peter = Person.new "Peter", Cat.new
```

If you compile the above program with the `hierarchy` command you will see this for `Person`:

```
- class Object
  |
  +- class Reference
     |
     +- class Person
            @name : String
            @pet : Animal+
```

You can see that `@pet` is `Animal+`. The `+` means it's a virtual type: because a `Dog` and a `Cat` were assigned to `@pet`, instead of having the type be `Dog | Cat` the compiler simplified it to `Animal+`, meaning "any class that inhertis from `Animal`, including `Animal`".

The compiler will always do this for classes under the same hierarchy: it will find the first superclass that's not `Reference` from which all types inherit from. If it can't find one, the type union remains.

The real reason the compiler does this is to be able to compile programs faster by not creating all kinds of different similar unions, also making the generated code smaller in size. But, on the other hand, it makes sense: classes under the same hierarchy should behave in a similar way.

Note that virtual types only apply to classes, never to structs.

Lets make John's pet talk:

```ruby
john.pet.talk # Error: undefined method 'talk' for Animal
```

We get an error because the compiler now treats `@pet` as an `Animal+`, which includes `Animal`. And since it can't find a `talk` method on it, it errors.

What the compiler doesn't know is that for us, `Animal` will never be instantiated as it doesn't make sense to instantiate one. We have a way to tell the compiler so by marking the class as `abstract`:

```ruby
abstract class Animal
end
```

Now the code compiles:

```ruby
john.pet.talk #=> "Woof!"
```

Marking a class as abstract will also prevent us from creating an instance of it:

```ruby
Animal.new # Error: can't instantiate abstract class Animal
```

To make it more explicit that an `Animal` must define a `talk` method, we can add it to `Animal` as an abstract method:

```ruby
abstract class Animal
  # Makes this animal talk
  abstract def talk
end
```

Abstract methods can also be defined in modules.
