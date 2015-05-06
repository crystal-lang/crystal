# finalize

If a class defines a `finalize` method, when an instance of that class is garbage-collected that method will be invoked:

```ruby
class Foo
  def finalize
    # Invoked when Foo is garbage-collected
    puts "Bye bye from #{self}!"
  end
end

# Prints "Bye bye ...!" for ever
loop do
  Foo.new
end
```

**Note:** the `finalize` method will only be invoked once the object has been fully initialized via the `initialize` method. If an exception is raised inside the `initialize` method, `finalize` won't be invoked. If your class defines a finalizer, be sure to catch any exceptions that might be raised in the `initialize` methods and free resources.
