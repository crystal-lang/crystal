# to_unsafe

If a type defines a `to_unsafe` method, when passing it to C the value returned by this method will be passed. For example:

```ruby
lib C
  fun exit(status : Int32) : NoReturn
end

class IntWrapper
  def initialize(@value)
  end

  def to_unsafe
    @value
  end
end

wrapper = IntWrapper.new(1)
C.exit(wrapper) # wrapper is not an Int32, but its to_unsafe
                # method is, so wrapper.to_unsafe
                # is passed instead
```

This is very useful for defining wrappers of C types without having to explicitly transform them to their wrapped values.

For example, the `String` class implements `to_unsafe` to return `UInt8*`:

```ruby
lib C
  fun printf(format : UInt8*, ...) : Int32
end

a = 1
b = 2
C.printf "%d + %d = %d\n", a, b, a + b
```
