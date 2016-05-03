# Default values

A method can specify default values for the last arguments:

```crystal
class Person
  def become_older(by = 1)
    @age += by
  end
end

john = Person.new "John"
john.age #=> 0

john.become_older
john.age #=> 1

john.become_older 2
john.age #=> 3
```

# Named arguments

All arguments can also be specified, in addition to their position, by their name. For example:

```crystal
john.become_older by: 5
```

When there are many arguments, the order of the names in the invocation don't matter, as long as all required arguments are covered:

```crystal
def some_method(x, y = 1, z = 2, w = 3)
  # do something...
end

some_method 10                   # x: 10, y: 1, z: 2, w: 3
some_method 10, z: 10            # x: 10, y: 1, z: 10, w: 3
some_method 10, w: 1, y: 2, z: 3 # x: 10, y: 2, z: 3, w: 1
some_method y: 10, x: 20         # x: 20, y: 10, z: 2, w: 3

some_method y: 10                # Error, missing arugment: x
```

When a method specified a splat (explained in the next section), named arguments can't be used. The reason is that understanding how arguments are matched becomes very difficult: positional arguments are easier to reason about in this case.
