# Class variables

Class variables are associated to classes instead of instances. They are prefixed with two "at" signs (`@@`). For example:

```crystal
class Counter
  @@instances = 0

  def initialize
    @@instances += 1
  end

  def self.instances
    @@instances
  end
end

Counter.instances #=> 0
Counter.new
Counter.new
Counter.new
Counter.instances #=> 3
```

Class variables can be read and written from class methods or instance methods.

Their type is inferred using the [global type inference algorithm](type_inference.html).

If a class variable is assigned at the class level, like in the example above, that initialization happens as soon as the program starts, before "main" code:

```crystal
# This assignment happens before the initialization of Foo's @@value
ENV["HOME"] = "."

class Foo
  @@value = ENV["HOME"]

  def self.value
    @@value
  end
end

Foo.value # probably not "."
```

In those cases the best thing is to lazily initialize the class variable:

```crystal
ENV["HOME"] = "."

class Foo
  def self.value
    @@value ||= ENV["HOME"]
  end
end

Foo.value # "."
```

Class variables are always associated to a single type and are not inherited:

```crystal
class Parent
  @@counter = 0
end

class Child < Parent
  def self.counter
    # Error, can't infer the type of class variable
    # '@@counter' of Child
    @@counter
  end
end
```

Class variables can also be associated to modules and structs. Like above, they are not inherited by including types.
