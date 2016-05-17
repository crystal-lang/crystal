# Splats and tuples

A method can receive a variable number of arguments by using a *splat* (`*`), which can appear only once and in any position:

```crystal
def sum(*elements)
  total = 0
  elements.each do |value|
    total += value
  end
  total
end

sum 1, 2, 3    #=> 6
sum 1, 2, 3, 4.5 #=> 10.5
```

The passed arguments become a [Tuple](http://crystal-lang.org/api/Tuple.html) in the method's body:

```crystal
# elements is Tuple(Int32, Int32, Int32)
sum 1, 2, 3

# elements is Tuple(Int32, Int32, Int32, Float64)
sum 1, 2, 3, 4.5
```

Arguments past the splat argument can only be passed as named arguments:

```crystal
def sum(*elements, initial = 0)
  total = initial
  elements.each do |value|
    total += value
  end
  total
end

sum 1, 2, 3 # => 6
sum 1, 2, 3, initial: 10 # => 16
```

Arguments past the splat method without a default value are required named arguments:

```crystal
def sum(*elements, initial)
  total = initial
  elements.each do |value|
    total += value
  end
  total
end

sum 1, 2, 3 # Error, missing argument: initial
sum 1, 2, 3, initial: 10 # => 16
```

Two methods with different required named arguments overload between each other:

```crystal
def foo(*elements, x)
  1
end

def foo(*elements, y)
  2
end

foo x: "something" # => 1
foo y: "something" # => 2
```

The splat argument can also be left unnamed, with the meaning "after this, named arguments follow":

```crystal
def foo(x, y, *, z)
end

foo 1, 2, 3    # Error, wrong number of arguments (given 3, expected 2)
foo 1, 2       # Error, missing argument: z
foo 1, 2, z: 3 # OK
```

## Splatting a tuple

A `Tuple` can be splat into a method call by using `*`:

```crystal
def foo(x, y)
  x + y
end

tuple = {1, 2}
foo *tuple # => 3
```

## Double splats and named tuples

A double splat (`**`) captures named arguments that were not matched by other arguments. The type of the argument is a `NamedTuple`:

```crystal
def foo(x, **other)
  # Return the captured named arguments as a NamedTuple
  other
end

foo 1, y: 2, z: 3    # => {y: 2, z: 3}
foo y: 2, x: 1, z: 3 # => {y: 2, z: 3}
```

## Double splatting a named tuple

A `NamedTuple` can be splat into a method call by using `**`:

```crystal
def foo(x, y)
  x - y
end

tuple = {y: 3, x: 10}
foo **tuple # => 7
```
