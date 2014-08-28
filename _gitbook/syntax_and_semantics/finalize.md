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
