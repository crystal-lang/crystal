# new, initialize and allocate

You create an instance of a class by invoking `new` on that class:

```
person = Person.new
```

Here, `person` is an instance of `Person`.

We can't do much with `person`, so lets add some concepts to it. A `Person` has a name and an age. In the "Everything is an object" section we said that an object has a type and responds to some methods, which is the only way to interact with objects, so we'll need a `name` and `age` methods. We will store this information in instance variables, which are always prefixed with an *at* (`@`) character. We also want a Person to come to existence with a name of our choice and an age of zero. We code the "come to existence" part with a special `initialize` method, which is normally called a *constructor*:

```ruby
class Person
  def initialize(name)
    @name = name
    @age = 0
  end

  def name
    @name
  end

  def age
    @age
  end
end
```

Now we can create people like this:

```ruby
john = Person.new "John"
peter = Person.new "Peter"

john.name #=> "John"
john.age #=> 0

peter.name #=> "Peter"
```

Note that we create a `Person` with `new` but we defined the initialization in an `initialize` method, not in a `new` method. Why is this so?

The answer is that when we defined an `initialize` method Crystal defined a `new` method for us, like this:

```ruby
class Person
  def self.new(name)
    instance = Person.allocate
    instance.initialize(name)
    instance
  end
 end
```

First, note the `self.new` notation. This means that the method belongs to the **class** `Person`, not to particular instances of that class. This is why we can do `Person.new`.

Second, `allocate` is a low-level class method that creates an uninitialized object of the given type. It basically allocates the necessary memory for it. Then `initialize` is invoked on it and then you get the instance. You generally never invoke `allocate`, as it is [unsafe](unsafe.html), but that's the reason why `new` and `initialize` are related.

