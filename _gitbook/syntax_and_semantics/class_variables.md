# Class variables

Class variables are associated to classes instead of instances. They are prefixed with two "at" signs (`@@`). For example:

```ruby
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

If a class variable is read before it is assigned a value, it will include the `Nil` type:

```ruby
class Counter
  def self.increment
    @@instances += 1
  end
end

Counter.increment # Error: undefined method '+' for Nil
```

Class variables are always associated to a single type and are not inherited:

```ruby
class Parent
  @@counter = 0
end

class Child < Parent
  def self.counter
    @@counter
  end
end

Child.counter #=> nil
```

Class variables can also be associated to modules and structs. Like above, they are not inherited by including types.
