# Value

`Value` is the base class of the primitive types (`Nil`, `Bool`, `Char`, integers and floats), `Symbol`, `Pointer`, `Tuple`, `StaticArray` and all structs.

As the name suggest, a `Value` is passed by value: when you pass it to methods ot return it from methods, a copy of the value is actually passed. This is not important for `nil`, bools, integers, floats, symbols, pointers and tuples, because they are immutable, but with mutable structs or with static arrays you have to be careful:

```ruby
struct Point
  property x
  property y

  def initialize(@x, @y)
  end
end

def change_x(point, x)
  point.x = x
end

point = Point.new 1, 2
change_x point, 10
point.x #=> 1
```

It's always better to try to make your structs immutable, as their usage will be easier to understand.
