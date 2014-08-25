# Default and named arguments

A method can specify default values for the last arguments:

```ruby
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

To specify the values of arguments that have default values you can also use their names in the invocation:

```ruby
john.become_older by: 5
```

When the method has many default arguments the order of the names in the invocation doesn't matter, and some names can be ommited:

```ruby
def some_method(x, y = 1, z = 2, w = 3)
  # do something...
end

some_method 10 # x = 10, y = 1, z = 2, w = 3
some_method 10, z: 10 # x = 10, y = 1, z = 10, w = 3
some_method 10, w: 1, y: 2, z: 3 # x = 10, y = 2, z = 3, w = 1
```

Note that in the above example you can't use `x`'s name, as it doesn't have a default value.

In this way, default arguments and named arguments are related to each other: when you specify default arguments you are also allowing the caller to use their names. Be wise and choose good names.
