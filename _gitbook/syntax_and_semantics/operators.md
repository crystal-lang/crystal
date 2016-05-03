# Operators

Operators like `+` and `-` are regular method calls. For example:

```crystal
a + b
```

is the same as:

```crystal
a.+(b)
```

You can define an operator for a type like this:

```crystal
struct Vector2
  getter x, y

  def initialize(@x : Int32, @y : Int32)
  end

  def +(other)
    Vector2.new(x + other.x, y + other.y)
  end
end

v1 = Vector2.new(1, 2)
v2 = Vector2.new(3, 4)
v1 + v2               #=> Vector2(@x=4, @y=6)
```

Next follows the full list of operators with their usual meaning.

## Unary operators

```crystal
+   # positive
-   # negative
!   # not
~   # bitwise complement
```

These are defined without arguments. For example

```crystal
struct Vector2
  def -
    Vector2.new(-x, -y)
  end
end

v1 = Vector2.new(1, 2)
-v1                    #=> Vector2(@x=-1, @y=-2)
```

**Note:** `!` (not) cannot be defined as a method (its meaning can't be changed).

## Binary operators

```crystal
+   # addition
-   # subtraction
*   # multiplication
/   # division
%   # modulo
&   # bitwise and
|   # bitwise or
^   # bitwise xor
**  # exponentiation
<<  # shift left, append
>>  # shift right
==  # equals
!=  # not equals
<   # less
<=  # less or equal
>   # greater
>=  # greater or equal
<=> # comparison
=== # case equality
```

## Indexing

```crystal
[]  # array index (raises on out of bounds)
[]? # array index (nil on out of bounds)
[]= # array index assignment
```

For example:

```crystal
class MyArray
  def [](index)
    # ...
  end

  def [](index1, index2, index3)
    # ...
  end

  def []=(index, value)
    # ...
  end
end

array = MyArray.new

array[1]       # invokes the first method
array[1, 2, 3] # invokes the second method
array[1] = 2   # invokes the third method

array.[](1)       # invokes the first method
array.[](1, 2, 3) # invokes the second method
array.[]=(1, 2)   # invokes the third method
```

## Meaning

One can assign any meaning to the operators, but the convention is to follow the above ones to avoid cryptic code, or code that behaves in an unexpected way.

