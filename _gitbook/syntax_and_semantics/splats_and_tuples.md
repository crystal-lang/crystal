# Splats and tuples

A method can receive a variable number of arguments by using a *splat* (`*`), which can appear only once and in any position:

```ruby
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

```ruby
# elements is Tuple(Int32, Int32, Int32)
sum 1, 2, 3

# elements is Tuple(Int32, Int32, Int32, Float64)
sum 1, 2, 3, 4.5
```
