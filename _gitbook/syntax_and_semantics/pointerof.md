# pointerof

The `pointerof` expression returns a [Pointer](http://crystal-lang.org/api/Pointer.html) that points to the contents of a variable or instance variable.

An example with a variable:

```crystal
a = 1

ptr = pointerof(a)
ptr.value = 2

a #=> 2
```

An example with an instance variable:

```crystal
class Point
  def initialize(@x, @y)
  end

  def x
    @x
  end

  def x_ptr
    pointerof(@x)
  end
end

point = Point.new 1, 2

ptr = point.x_ptr
ptr.value = 10

point.x #=> 10
```

Because `pointerof` involves pointers, it is considered [unsafe](unsafe.html).

