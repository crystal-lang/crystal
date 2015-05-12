# Tuple

A [Tuple](http://crystal-lang.org/api/Tuple.html) is typically created with a tuple literal:

```ruby
tuple = {1, "hello", 'x'} # Tuple(Int32, String, Char)
tuple[0]                  #=> 1       (Int32)
tuple[1]                  #=> "hello" (String)
tuple[2]                  #=> 'x'     (Char)
```

To create an empty tuple use [Tuple.new](http://crystal-lang.org/api/Tuple.html#new%28%2Aargs%29-class-method).
